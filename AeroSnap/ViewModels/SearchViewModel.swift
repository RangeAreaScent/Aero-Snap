import Foundation
import Observation

/// Six search modes (post-IA-restructure 2026-05-31).
/// `All` runs each scope in parallel and sections the results.
enum SearchMode: String, CaseIterable, Identifiable {
    case all            = "All"
    case adNumber       = "AD #"
    case makeModel      = "Make/Model"
    case ataChapter     = "ATA"
    case farCitation    = "14 CFR"
    case tcds           = "TCDS"
    case ac             = "AC"

    var id: String { rawValue }

    var placeholder: String {
        switch self {
        case .all:         return "Search ADs, 14 CFR, TCDS, AC — anything"
        case .adNumber:    return "e.g. 2024-17-05"
        case .makeModel:   return "e.g. Cessna 172, Boeing 737-800"
        case .ataChapter:  return "e.g. 32 (landing gear)"
        case .farCitation: return "e.g. 43.13, 91.417"
        case .tcds:        return "TCDS #, manufacturer, model"
        case .ac:          return "AC number or title — e.g. 43.13-1B"
        }
    }

    var emptyStateHint: String {
        switch self {
        case .all:         return "Type a manufacturer, AD number, 14 CFR section, or any keyword."
        case .adNumber:    return "Type an AD number — e.g. 2024-17 to see all 2024-week-17 ADs."
        case .makeModel:   return "Type a manufacturer + model — e.g. Boeing 737-800 or Cessna 172."
        case .ataChapter:  return "Type the 2-digit ATA chapter — 32 for landing gear, 72 for engines."
        case .farCitation: return "Type a 14 CFR section — 43.13, 91.417, 65.85."
        case .tcds:        return "Browse the type-certificate catalog below, or type to filter."
        case .ac:          return "Type an AC number (43.13-1B) or any title keyword. PDFs link out."
        }
    }
}

/// Heterogeneous search result so the list can render any entity type.
enum SearchHit: Identifiable, Hashable, Sendable {
    case ad(ADSummary)
    case far(FARSection)
    case tcds(TCDSummary)
    case ac(ACEntry)

    var id: String {
        switch self {
        case .ad(let s):   return "ad:" + s.adNumber
        case .far(let s):  return "far:" + s.id
        case .tcds(let s): return "tcds:" + s.tcdsNumber
        case .ac(let a):   return "ac:" + a.acNumber
        }
    }
}

/// Sort order for AD results. Applies in All-mode AD section and
/// dedicated AD modes (AD #, Make/Model, ATA, fullText). FAR / TCDS /
/// AC sections always keep their natural order (citation / mfg / ac#).
enum ADSortOrder: String, CaseIterable, Identifiable {
    case newestFirst        = "Newest first"
    case oldestFirst        = "Oldest first"
    case manufacturer       = "Manufacturer"
    case ataChapter         = "ATA chapter"

    var id: String { rawValue }
    var symbolName: String {
        switch self {
        case .newestFirst:  return "arrow.down.to.line"
        case .oldestFirst:  return "arrow.up.to.line"
        case .manufacturer: return "building.2"
        case .ataChapter:   return "number"
        }
    }
}

/// TCDS sub-filter shown only when SearchMode == .tcds. Mirrors the
/// category split that used to be the standalone Aircraft tab.
enum TCDSCategory: String, CaseIterable, Identifiable {
    case all       = "All"
    case aircraft  = "Aircraft"
    case engine    = "Engine"
    case propeller = "Propeller"
    var id: String { rawValue }

    /// Database column value; nil means "no filter".
    var dbValue: String? {
        self == .all ? nil : rawValue
    }
}

@Observable
@MainActor
final class SearchViewModel {
    var query: String = ""
    var mode: SearchMode = .all
    var hits: [SearchHit] = []
    var isLoading: Bool = false
    var adSort: ADSortOrder = .newestFirst

    /// TCDS-mode browse state — populated when mode is .tcds and query is
    /// empty so the user sees the full catalog instead of a blank screen.
    var tcdsBrowse: [TCDSummary] = []

    /// TCDS sub-filter (mirrors the old Aircraft-tab category Picker).
    var tcdsCategory: TCDSCategory = .all

    /// Suggestion chips shown when Make/Model search returns 0 results
    /// (typically a typo like "cesna" vs "Cessna"). Populated lazily on
    /// first need so the SQLite query only runs once per session.
    var topManufacturers: [String] = []

    private var pendingTask: Task<Void, Never>?

    func onModeChange() {
        if mode == .tcds {
            Task { await loadTCDSBrowse() }
        }
        runSearch()
    }

    /// Apply the current TCDS category filter to a TCDS list. Used for
    /// both the browse state and typed-query results.
    func applyTCDSCategory(_ list: [TCDSummary]) -> [TCDSummary] {
        guard let want = tcdsCategory.dbValue else { return list }
        return list.filter { $0.category == want }
    }

    /// Sort a slice of AD summaries by the user's chosen `adSort` order.
    /// Used at render time on either the All-mode AD section or the
    /// dedicated AD modes. `effectiveDate` is ISO 8601 so lexical
    /// compare matches chronological order.
    func applyADSort(_ ads: [ADSummary]) -> [ADSummary] {
        switch adSort {
        case .newestFirst:
            return ads.sorted { ($0.effectiveDate ?? "") > ($1.effectiveDate ?? "") }
        case .oldestFirst:
            return ads.sorted { ($0.effectiveDate ?? "") < ($1.effectiveDate ?? "") }
        case .manufacturer:
            // Manufacturer isn't on ADSummary — fall back to title which
            // typically reads "Airworthiness Directives; Boeing ...".
            return ads.sorted {
                ($0.title.lowercased(), $1.effectiveDate ?? "")
                    .0 < ($1.title.lowercased(), $0.effectiveDate ?? "").0
            }
        case .ataChapter:
            return ads.sorted {
                let a = $0.ataChapter ?? "ZZ"
                let b = $1.ataChapter ?? "ZZ"
                if a != b { return a < b }
                return ($0.effectiveDate ?? "") > ($1.effectiveDate ?? "")
            }
        }
    }

    func runSearch() {
        pendingTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            hits = []
            return
        }
        isLoading = true
        let mode = self.mode
        let q = trimmed
        pendingTask = Task { [weak self] in
            let results = await Self.fetch(mode: mode, query: q)
            if Task.isCancelled { return }
            self?.hits = results
            self?.isLoading = false
        }
    }

    func loadTCDSBrowse() async {
        if tcdsBrowse.isEmpty {
            tcdsBrowse = await AeroRepository.shared.allTCDS()
        }
    }

    func loadTopManufacturers() async {
        if topManufacturers.isEmpty {
            topManufacturers = await AeroRepository.shared.topManufacturers()
        }
    }

    /// Apply a suggestion-chip selection. Replaces the user's query with
    /// the chosen manufacturer name and re-runs the search.
    func adoptSuggestion(_ manufacturer: String) {
        query = manufacturer
        runSearch()
    }

    /// Apply a history-chip selection — same as adoptSuggestion.
    func adoptHistory(_ q: String) {
        query = q
        runSearch()
    }

    /// Record the current query in history. Called when the user actually
    /// taps a result (a strong signal of intent) so the history isn't
    /// polluted by partial keystrokes.
    func commitToHistory() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        SearchHistoryManager.shared.record(q)
    }

    private static func fetch(mode: SearchMode, query: String) async -> [SearchHit] {
        let repo = AeroRepository.shared
        switch mode {
        case .all:
            // Generous per-source limits — All mode is the "wide net".
            // Each AD scope gets 50 because dedup across three scopes
            // usually collapses to ~60-80 unique. Final section caps
            // are applied at render time for visual balance.
            async let adsByNumber = repo.searchADByNumber(prefix: query, limit: 50)
            async let adsByModel  = repo.searchADByMakeModel(query, limit: 50)
            async let adsFTS      = repo.searchADBodyFTS(query, limit: 50)
            async let fars        = repo.searchFAR(query, limit: 30)
            async let tcdsHits    = repo.searchTCDS(query, limit: 20)
            async let acHits      = repo.searchAC(query, limit: 20)

            // Dedup ADs by number across the three AD scopes.
            var seenAD = Set<String>()
            var ads: [ADSummary] = []
            for source in [await adsByNumber, await adsByModel, await adsFTS] {
                for s in source where seenAD.insert(s.adNumber).inserted {
                    ads.append(s)
                }
            }
            return ads.map(SearchHit.ad)
                 + (await fars).map(SearchHit.far)
                 + (await tcdsHits).map(SearchHit.tcds)
                 + (await acHits).map(SearchHit.ac)

        case .adNumber:
            return await repo.searchADByNumber(prefix: query).map(SearchHit.ad)
        case .makeModel:
            return await repo.searchADByMakeModel(query).map(SearchHit.ad)
        case .ataChapter:
            return await repo.searchADByATA(query).map(SearchHit.ad)
        case .farCitation:
            return await repo.searchFAR(query).map(SearchHit.far)
        case .tcds:
            return await repo.searchTCDS(query).map(SearchHit.tcds)
        case .ac:
            return await repo.searchAC(query).map(SearchHit.ac)
        }
    }
}
