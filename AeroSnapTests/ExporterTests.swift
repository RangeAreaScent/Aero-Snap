import Testing
import Foundation
@testable import AeroSnap

/// Pure-function tests for the Exporter module. No SQLite or
/// SwiftData dependency — fed handcrafted fixture rows so they
/// stay fast and survive any data-pipeline changes.
@Suite("Exporter")
struct ExporterTests {

    // MARK: - CSV quoting (RFC 4180)

    @Test func quoteLeavesPlainStringsUntouched() {
        #expect(Exporter.quote("plain") == "plain")
        #expect(Exporter.quote("AD 2024-17-05") == "AD 2024-17-05")
    }

    @Test func quoteWrapsFieldsContainingComma() {
        #expect(Exporter.quote("a,b") == "\"a,b\"")
    }

    @Test func quoteWrapsFieldsContainingNewline() {
        let actual = Exporter.quote("a\nb")
        #expect(actual.first == "\"" && actual.last == "\"")
        #expect(actual.contains("a\nb"))
    }

    @Test func quoteWrapsFieldsContainingCarriageReturn() {
        // CSV is line-oriented so even a bare \r must be quoted to
        // survive round-trip through a parser. Check structure, not
        // exact string equality — the diagnostic renderer otherwise
        // truncates at the embedded line break and the failure looks
        // confusing.
        let actual = Exporter.quote("a\rb")
        #expect(actual.first == "\"" && actual.last == "\"")
        #expect(actual.count == 5)  // ", a, \r, b, "
    }

    @Test func quoteDoublesEmbeddedDoubleQuotes() {
        // RFC 4180: embedded " becomes "" inside a quoted field.
        #expect(Exporter.quote("he said \"hi\"") == "\"he said \"\"hi\"\"\"")
    }

    // MARK: - CSV row composition

    @Test func favoritesCSVHasHeaderAndCRLF() {
        let csv = Exporter.csv(favoriteADs: [Self.sampleAD])
        let lines = csv.components(separatedBy: "\r\n")
        // Header + 1 data row + trailing empty line from final \r\n.
        #expect(lines.count == 3)
        #expect(lines[0] == "AD Number,Title,Effective Date,ATA Chapter,Emergency,Summary")
        #expect(lines[1].hasPrefix("2024-17-05,"))
        #expect(lines[2].isEmpty)
    }

    @Test func favoritesCSVEscapesTitlesWithCommas() {
        let withComma = ADSummary(
            adNumber: "2024-99-01",
            adYear: 2024,
            title: "Boeing 737, 757, and 767 corrosion",
            effectiveDate: "2024-12-01",
            ataChapter: "53",
            isEmergency: false,
            summary: "Multi-type AD with commas in title."
        )
        let csv = Exporter.csv(favoriteADs: [withComma])
        #expect(csv.contains("\"Boeing 737, 757, and 767 corrosion\""))
    }

    // MARK: - Plain-text pagination feed (PDF source)

    @Test func plainTextFavoritesContainsHeaderAndRows() {
        let text = Exporter.plainText(favoriteADs: [Self.sampleAD])
        let lines = text.components(separatedBy: "\n")
        #expect(lines[0].contains("AD Number"))
        #expect(lines[0].contains("Title"))
        #expect(lines[1].allSatisfy { $0 == "-" })   // separator line
        #expect(lines[2].contains("2024-17-05"))
        #expect(lines[2].contains("Boeing 737-800"))
    }

    // MARK: - PDF generation

    @Test func pdfRendererReturnsNonEmptyPDFData() {
        let data = Exporter.pdf(
            title: "Test Doc",
            plainText: Exporter.plainText(favoriteADs: [Self.sampleAD])
        )
        // PDF magic header — first 4 bytes are "%PDF".
        let magic = Array(data.prefix(4))
        #expect(magic == [0x25, 0x50, 0x44, 0x46])
        #expect(data.count > 1000)  // even an empty page is ~1 KB
    }

    @Test func pdfHandlesLargeInputByPaginating() {
        // Feed enough text that the layout must spill onto a second
        // page (US Letter @ 72 DPI body area fits roughly 60 lines
        // of 9.5pt monospace).
        let manyADs = (0..<300).map { i in
            ADSummary(
                adNumber: "2024-99-\(String(format: "%02d", i % 99 + 1))",
                adYear: 2024,
                title: "Fixture AD \(i)",
                effectiveDate: "2024-12-01",
                ataChapter: "32",
                isEmergency: false,
                summary: "Generated."
            )
        }
        let data = Exporter.pdf(
            title: "Large",
            plainText: Exporter.plainText(favoriteADs: manyADs)
        )
        // Don't decode the PDF — just sanity-check it didn't truncate
        // to a one-page minimum. Multi-page PDFs are reliably > 3 KB
        // when paginating 9.5pt mono text on US Letter.
        #expect(data.count > 3000)
    }

    // MARK: - Fixtures

    private static let sampleAD = ADSummary(
        adNumber: "2024-17-05",
        adYear: 2024,
        title: "Boeing 737-800 nacelle fan-blade inspection",
        effectiveDate: "2024-09-01",
        ataChapter: "72",
        isEmergency: false,
        summary: "Inspect fan blades for cracks."
    )
}
