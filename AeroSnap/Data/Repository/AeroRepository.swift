import Foundation
import SQLite3

/// Read-only access to `aero_snap_v1.sqlite` (bundled).
///
/// Uses the SQLite3 C API via the Swift stdlib bridge. No third-party deps —
/// keeps the build matrix simple. (ICD Snap uses GRDB; Aero deliberately
/// stays dependency-light to keep iOS+desktop ports symmetric.)
///
/// All public entrypoints are `async`. The actor serializes statement
/// preparation; SQLite itself is opened in read-only mode so concurrent
/// reads are safe.
actor AeroRepository {
    static let shared = AeroRepository()

    private let db: OpaquePointer?

    private init() {
        self.db = Self.openBundledDatabase()
    }

    private static func openBundledDatabase() -> OpaquePointer? {
        guard let path = Bundle.main.path(forResource: "aero_snap_v1",
                                          ofType: "sqlite") else {
            assertionFailure("aero_snap_v1.sqlite is missing from the app bundle.")
            return nil
        }
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        let rc = sqlite3_open_v2(path, &handle, flags, nil)
        guard rc == SQLITE_OK else {
            assertionFailure("Failed to open aero db: \(rc)")
            return nil
        }
        return handle
    }

    // MARK: - Search modes (spec §4-1)

    func searchADByNumber(prefix raw: String, limit: Int = 50) async -> [ADSummary] {
        guard let db else { return [] }
        let prefix = raw.uppercased() + "%"
        let sql = """
            SELECT ad_number, ad_year, title, effective_date, ata_chapter,
                   is_emergency, summary
            FROM airworthiness_directives
            WHERE ad_number LIKE ?
            ORDER BY effective_date DESC
            LIMIT ?
            """
        return query(db: db, sql: sql, bind: { stmt in
            sqlite3_bind_text(stmt, 1, prefix, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 2, Int32(limit))
        }, map: Self.readADSummary)
    }

    func searchADByMakeModel(_ raw: String, limit: Int = 50) async -> [ADSummary] {
        guard let db else { return [] }
        // The applicability matrix stores manufacturer + model in separate
        // columns ("Cessna Aircraft Company" / "172"). A naive
        // `LIKE '%Cessna 172%'` against either column never matches.
        // Tokenize and require EACH token to appear in either column.
        // Aero-tokenizer also handles no-space typos like "cessna172".
        let tokens = raw.searchTokens()
        guard !tokens.isEmpty else { return [] }

        let clauses = Array(repeating: "(a.manufacturer LIKE ? OR a.model LIKE ?)",
                            count: tokens.count).joined(separator: " AND ")
        let sql = """
            SELECT DISTINCT ad.ad_number, ad.ad_year, ad.title,
                            ad.effective_date, ad.ata_chapter,
                            ad.is_emergency, ad.summary
            FROM ad_applicability a
            JOIN airworthiness_directives ad USING (ad_number)
            WHERE \(clauses)
            ORDER BY ad.effective_date DESC
            LIMIT ?
            """
        return query(db: db, sql: sql, bind: { stmt in
            var idx: Int32 = 1
            for token in tokens {
                let needle = "%" + token + "%"
                sqlite3_bind_text(stmt, idx, needle, -1, SQLITE_TRANSIENT); idx += 1
                sqlite3_bind_text(stmt, idx, needle, -1, SQLITE_TRANSIENT); idx += 1
            }
            sqlite3_bind_int(stmt, idx, Int32(limit))
        }, map: Self.readADSummary)
    }

    func searchADByATA(_ chapter: String, limit: Int = 50) async -> [ADSummary] {
        guard let db else { return [] }
        let sql = """
            SELECT ad_number, ad_year, title, effective_date, ata_chapter,
                   is_emergency, summary
            FROM airworthiness_directives
            WHERE ata_chapter = ?
            ORDER BY effective_date DESC
            LIMIT ?
            """
        return query(db: db, sql: sql, bind: { stmt in
            sqlite3_bind_text(stmt, 1, chapter, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 2, Int32(limit))
        }, map: Self.readADSummary)
    }

    func searchADBodyFTS(_ raw: String, limit: Int = 50) async -> [ADSummary] {
        guard let db else { return [] }
        let q = Self.makeFTSQuery(from: raw)
        guard !q.isEmpty else { return [] }
        let sql = """
            SELECT ad.ad_number, ad.ad_year, ad.title, ad.effective_date,
                   ad.ata_chapter, ad.is_emergency, ad.summary
            FROM ad_fts f
            JOIN airworthiness_directives ad ON f.rowid = ad.rowid
            WHERE ad_fts MATCH ?
            ORDER BY rank
            LIMIT ?
            """
        return query(db: db, sql: sql, bind: { stmt in
            sqlite3_bind_text(stmt, 1, q, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 2, Int32(limit))
        }, map: Self.readADSummary)
    }

    func searchFAR(_ raw: String, limit: Int = 50) async -> [FARSection] {
        guard let db else { return [] }
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if let _ = trimmed.firstIndex(of: ".") {
            // Looks like "43.13" — section lookup
            let sql = """
                SELECT id, part_number, section_number, subpart, heading, body,
                       citation, last_amended
                FROM far_sections
                WHERE section_number = ? OR section_number LIKE ?
                LIMIT ?
                """
            return query(db: db, sql: sql, bind: { stmt in
                sqlite3_bind_text(stmt, 1, trimmed, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 2, trimmed + "%", -1, SQLITE_TRANSIENT)
                sqlite3_bind_int(stmt, 3, Int32(limit))
            }, map: Self.readFARSection)
        } else {
            let q = Self.makeFTSQuery(from: raw)
            guard !q.isEmpty else { return [] }
            let sql = """
                SELECT s.id, s.part_number, s.section_number, s.subpart, s.heading,
                       s.body, s.citation, s.last_amended
                FROM far_fts f
                JOIN far_sections s ON f.rowid = s.rowid
                WHERE far_fts MATCH ?
                ORDER BY rank
                LIMIT ?
                """
            return query(db: db, sql: sql, bind: { stmt in
                sqlite3_bind_text(stmt, 1, q, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int(stmt, 2, Int32(limit))
            }, map: Self.readFARSection)
        }
    }

    // MARK: - Detail loaders

    func ad(byNumber adNumber: String) async -> ADDetail? {
        guard let db else { return nil }
        let sql = """
            SELECT ad_number, ad_year, title, effective_date, ata_chapter,
                   is_emergency, summary, body, cfr_amendment,
                   federal_register_id, compliance_time,
                   supersedes, superseded_by, pdf_url, fr_url
            FROM airworthiness_directives
            WHERE ad_number = ?
            LIMIT 1
            """
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        sqlite3_bind_text(stmt, 1, adNumber, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }

        let summary = ADSummary(
            adNumber: Self.column(stmt, 0) ?? "",
            adYear: Int(sqlite3_column_int(stmt, 1)),
            title: Self.column(stmt, 2) ?? "",
            effectiveDate: Self.column(stmt, 3),
            ataChapter: Self.column(stmt, 4),
            isEmergency: sqlite3_column_int(stmt, 5) != 0,
            summary: Self.column(stmt, 6) ?? ""
        )
        let body = Self.column(stmt, 7) ?? ""
        return ADDetail(
            summary: summary,
            body: body,
            bodyDropped: body.isEmpty,
            cfrAmendment: Self.column(stmt, 8),
            federalRegisterID: Self.column(stmt, 9),
            complianceTime: Self.column(stmt, 10),
            supersedes: Self.column(stmt, 11),
            supersededBy: Self.column(stmt, 12),
            pdfURL: (Self.column(stmt, 13)).flatMap(URL.init(string:)),
            frURL: (Self.column(stmt, 14)).flatMap(URL.init(string:))
        )
    }

    func applicability(forAD adNumber: String) async -> [ADApplicability] {
        guard let db else { return [] }
        let sql = """
            SELECT ad_number, manufacturer, model, model_series,
                   serial_range_start, serial_range_end, part_type, notes
            FROM ad_applicability
            WHERE ad_number = ?
            ORDER BY manufacturer, model
            """
        return query(db: db, sql: sql, bind: { stmt in
            sqlite3_bind_text(stmt, 1, adNumber, -1, SQLITE_TRANSIENT)
        }, map: { stmt in
            ADApplicability(
                adNumber: Self.column(stmt, 0) ?? "",
                manufacturer: Self.column(stmt, 1) ?? "",
                model: Self.column(stmt, 2) ?? "",
                modelSeries: Self.column(stmt, 3),
                serialRangeStart: Self.column(stmt, 4),
                serialRangeEnd: Self.column(stmt, 5),
                partType: Self.column(stmt, 6),
                notes: Self.column(stmt, 7)
            )
        })
    }

    func searchAC(_ raw: String, limit: Int = 50) async -> [ACEntry] {
        guard let db else { return [] }
        let tokens = raw.searchTokens()
        guard !tokens.isEmpty else { return [] }
        let clauses = Array(repeating:
            "(ac_number LIKE ? OR title LIKE ? OR related_far LIKE ?)",
            count: tokens.count
        ).joined(separator: " AND ")
        let sql = """
            SELECT ac_number, title, issue_date, related_far, pdf_url
            FROM advisory_circulars
            WHERE \(clauses)
            ORDER BY ac_number
            LIMIT ?
            """
        return query(db: db, sql: sql, bind: { stmt in
            var idx: Int32 = 1
            for token in tokens {
                let needle = "%" + token + "%"
                sqlite3_bind_text(stmt, idx, needle, -1, SQLITE_TRANSIENT); idx += 1
                sqlite3_bind_text(stmt, idx, needle, -1, SQLITE_TRANSIENT); idx += 1
                sqlite3_bind_text(stmt, idx, needle, -1, SQLITE_TRANSIENT); idx += 1
            }
            sqlite3_bind_int(stmt, idx, Int32(limit))
        }, map: { stmt in
            let pdf = Self.column(stmt, 4) ?? ""
            return ACEntry(
                acNumber: Self.column(stmt, 0) ?? "",
                title: Self.column(stmt, 1) ?? "",
                issueDate: Self.column(stmt, 2),
                relatedFAR: Self.column(stmt, 3),
                pdfURL: URL(string: pdf) ?? URL(string: "https://www.faa.gov")!
            )
        })
    }

    func searchTCDS(_ raw: String, limit: Int = 50) async -> [TCDSummary] {
        guard let db else { return [] }
        let tokens = raw.searchTokens()
        guard !tokens.isEmpty else { return [] }
        let clauses = Array(repeating:
            "(tcds_number LIKE ? OR manufacturer LIKE ? OR models LIKE ?)",
            count: tokens.count
        ).joined(separator: " AND ")
        let sql = """
            SELECT tcds_number, category, manufacturer, models, issue_date,
                   last_revision, specifications, pdf_url
            FROM type_certificates
            WHERE \(clauses)
            ORDER BY manufacturer, tcds_number
            LIMIT ?
            """
        return query(db: db, sql: sql, bind: { stmt in
            var idx: Int32 = 1
            for token in tokens {
                let needle = "%" + token + "%"
                sqlite3_bind_text(stmt, idx, needle, -1, SQLITE_TRANSIENT); idx += 1
                sqlite3_bind_text(stmt, idx, needle, -1, SQLITE_TRANSIENT); idx += 1
                sqlite3_bind_text(stmt, idx, needle, -1, SQLITE_TRANSIENT); idx += 1
            }
            sqlite3_bind_int(stmt, idx, Int32(limit))
        }, map: Self.readTCDS)
    }

    func allTCDS(category: String? = nil, limit: Int = 5000) async -> [TCDSummary] {
        guard let db else { return [] }
        let (sql, hasFilter) = category.map { _ in
            ("""
            SELECT tcds_number, category, manufacturer, models, issue_date,
                   last_revision, specifications, pdf_url
            FROM type_certificates
            WHERE category = ?
            ORDER BY manufacturer, tcds_number
            LIMIT ?
            """, true)
        } ?? ("""
            SELECT tcds_number, category, manufacturer, models, issue_date,
                   last_revision, specifications, pdf_url
            FROM type_certificates
            ORDER BY manufacturer, tcds_number
            LIMIT ?
            """, false)

        return query(db: db, sql: sql, bind: { stmt in
            if hasFilter, let cat = category {
                sqlite3_bind_text(stmt, 1, cat, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int(stmt, 2, Int32(limit))
            } else {
                sqlite3_bind_int(stmt, 1, Int32(limit))
            }
        }, map: Self.readTCDS)
    }

    /// "Manufacturer Model" suggestions for the New Collection sheet's
    /// model field. Pulls distinct mfg+model combos from the matrix that
    /// match the user's prefix (any token). Sorted by how many distinct
    /// ADs apply to that combo (popularity).
    func modelSuggestions(for raw: String, limit: Int = 6) async -> [String] {
        guard let db, !raw.isEmpty else { return [] }
        let tokens = raw.searchTokens()
        guard !tokens.isEmpty else { return [] }
        let clauses = Array(repeating:
            "(manufacturer LIKE ? OR model LIKE ?)",
            count: tokens.count
        ).joined(separator: " AND ")
        let sql = """
            SELECT manufacturer, model, COUNT(DISTINCT ad_number) AS n
            FROM ad_applicability
            WHERE manufacturer != 'UNKNOWN' AND \(clauses)
            GROUP BY manufacturer, model
            ORDER BY n DESC, manufacturer, model
            LIMIT ?
            """
        var out: [String] = []
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        var idx: Int32 = 1
        for token in tokens {
            let needle = "%" + token + "%"
            sqlite3_bind_text(stmt, idx, needle, -1, SQLITE_TRANSIENT); idx += 1
            sqlite3_bind_text(stmt, idx, needle, -1, SQLITE_TRANSIENT); idx += 1
        }
        sqlite3_bind_int(stmt, idx, Int32(limit))
        while sqlite3_step(stmt) == SQLITE_ROW {
            let mfg = Self.column(stmt, 0) ?? ""
            let model = Self.column(stmt, 1) ?? ""
            // Collapse the long official manufacturer name to the short
            // common form so suggestions read naturally: "Cessna Aircraft
            // Company / 172" → "Cessna 172".
            let shortMfg = Self.shortenManufacturer(mfg)
            out.append("\(shortMfg) \(model)")
        }
        return out
    }

    /// Heuristic manufacturer name shortener for suggestion display.
    private static func shortenManufacturer(_ raw: String) -> String {
        // First word usually carries the brand (Boeing / Cessna / Airbus / etc.)
        let first = raw.split(separator: " ", maxSplits: 1).first.map(String.init) ?? raw
        return first.trimmingCharacters(in: .punctuationCharacters)
    }

    /// Top N distinct manufacturers in the applicability matrix, ranked by
    /// number of distinct ADs. Used for "did you mean?" suggestions when
    /// the user's free-text Make/Model query returns zero hits (typically
    /// a typo — "cesna" vs "Cessna").
    func topManufacturers(limit: Int = 8) async -> [String] {
        guard let db else { return [] }
        let sql = """
            SELECT manufacturer, COUNT(DISTINCT ad_number) AS n
            FROM ad_applicability
            WHERE manufacturer != 'UNKNOWN'
            GROUP BY manufacturer
            ORDER BY n DESC
            LIMIT ?
            """
        var out: [String] = []
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        sqlite3_bind_int(stmt, 1, Int32(limit))
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let m = Self.column(stmt, 0) { out.append(m) }
        }
        return out
    }

    /// Pull the bundled SQLite's metadata table as a dictionary. Used by
    /// SettingsView to display the dataset build date + row counts without
    /// hardcoding them in Swift (so they stay accurate when the SQLite is
    /// rebuilt and dropped into the bundle).
    func databaseMeta() async -> [String: String] {
        guard let db else { return [:] }
        var out: [String: String] = [:]
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        let sql = "SELECT key, value FROM meta"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [:] }
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let k = Self.column(stmt, 0), let v = Self.column(stmt, 1) {
                out[k] = v
            }
        }
        return out
    }

    func allFARParts() async -> [String] {
        guard let db else { return [] }
        let sql = "SELECT DISTINCT part_number FROM far_sections ORDER BY CAST(part_number AS INTEGER)"
        var parts: [String] = []
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let p = Self.column(stmt, 0) { parts.append(p) }
        }
        return parts
    }

    func farSections(part: String) async -> [FARSection] {
        guard let db else { return [] }
        let sql = """
            SELECT id, part_number, section_number, subpart, heading, body,
                   citation, last_amended
            FROM far_sections
            WHERE part_number = ?
            ORDER BY CAST(REPLACE(section_number, '.', '') AS REAL)
            """
        return query(db: db, sql: sql, bind: { stmt in
            sqlite3_bind_text(stmt, 1, part, -1, SQLITE_TRANSIENT)
        }, map: Self.readFARSection)
    }

    // MARK: - Helpers

    private func query<T>(db: OpaquePointer, sql: String,
                          bind: (OpaquePointer?) -> Void,
                          map: (OpaquePointer?) -> T?) -> [T] {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }
        bind(stmt)
        var out: [T] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let item = map(stmt) { out.append(item) }
        }
        return out
    }

    private static func readADSummary(_ stmt: OpaquePointer?) -> ADSummary {
        ADSummary(
            adNumber: column(stmt, 0) ?? "",
            adYear: Int(sqlite3_column_int(stmt, 1)),
            title: column(stmt, 2) ?? "",
            effectiveDate: column(stmt, 3),
            ataChapter: column(stmt, 4),
            isEmergency: sqlite3_column_int(stmt, 5) != 0,
            summary: column(stmt, 6) ?? ""
        )
    }

    private static func readFARSection(_ stmt: OpaquePointer?) -> FARSection {
        FARSection(
            id: column(stmt, 0) ?? "",
            partNumber: column(stmt, 1) ?? "",
            sectionNumber: column(stmt, 2) ?? "",
            subpart: column(stmt, 3),
            heading: column(stmt, 4) ?? "",
            body: column(stmt, 5) ?? "",
            citation: column(stmt, 6) ?? "",
            lastAmended: column(stmt, 7)
        )
    }

    private static func readTCDS(_ stmt: OpaquePointer?) -> TCDSummary {
        TCDSummary(
            tcdsNumber: column(stmt, 0) ?? "",
            category: column(stmt, 1) ?? "",
            manufacturer: column(stmt, 2) ?? "",
            models: column(stmt, 3) ?? "",
            issueDate: column(stmt, 4),
            lastRevision: column(stmt, 5),
            specifications: column(stmt, 6) ?? "{}",
            pdfURL: column(stmt, 7).flatMap(URL.init(string:))
        )
    }

    private static func column(_ stmt: OpaquePointer?, _ idx: Int32) -> String? {
        guard let cstr = sqlite3_column_text(stmt, idx) else { return nil }
        return String(cString: cstr)
    }

    /// Sanitize free-text into an FTS5 MATCH query: drop quotes, tokens
    /// joined by AND so SQLite returns conjunctive hits (the natural
    /// "search for words" semantics). Uses the same Aero tokenizer as
    /// the LIKE searches so "cessna172" works in FTS too.
    private static func makeFTSQuery(from raw: String) -> String {
        let cleaned = raw
            .replacingOccurrences(of: "\"", with: " ")
            .replacingOccurrences(of: "'", with: " ")
        let tokens = cleaned.searchTokens()
        guard !tokens.isEmpty else { return "" }
        return tokens.map { "\"\($0)\"" }.joined(separator: " AND ")
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(
    OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self
)
