import Testing
@testable import AeroSnap

/// PoC sanity tests. Verifies the bundled SQLite resolves and the
/// repository returns real rows. Per playbook §11 "Local dev
/// conventions", run with:
///   xcodebuild test -scheme AeroSnap \
///     -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
@Suite("AeroRepository smoke")
struct AeroRepositorySmokeTests {

    @Test func findsFamousFARSection() async {
        // 14 CFR § 43.13 is the canonical maintenance "performance rules" cite.
        let hits = await AeroRepository.shared.searchFAR("43.13")
        #expect(hits.contains(where: { $0.sectionNumber == "43.13" }))
    }

    @Test func findsBoeing737ADs() async {
        let hits = await AeroRepository.shared.searchADByMakeModel("Boeing 737-800")
        #expect(!hits.isEmpty)
    }

    @Test func ftsFindsCorrosionADs() async {
        let hits = await AeroRepository.shared.searchADBodyFTS("corrosion")
        #expect(!hits.isEmpty)
    }

    @Test func tcdsSeedHasCessna172() async {
        let all = await AeroRepository.shared.allTCDS(category: "Aircraft")
        #expect(all.contains(where: { $0.tcdsNumber == "3A12" }))
    }

    /// Closes the 5-search-modes coverage gap — AD# prefix lookup is
    /// the only search mode the original suite didn't exercise.
    @Test func adNumberPrefixSearchFindsRecentADs() async {
        let hits = await AeroRepository.shared.searchADByNumber(prefix: "2024-")
        #expect(!hits.isEmpty)
    }

    /// Regression guard for ATA chapter filter — chapter 32 (landing
    /// gear) is broadly populated across manufacturers.
    @Test func ataChapterFilterReturnsLandingGearADs() async {
        let hits = await AeroRepository.shared.searchADByATA("32")
        #expect(!hits.isEmpty)
    }

    /// Smoke test for the batch-2 TCDS additions (2026-06-01) — if
    /// the curation pipeline ever silently drops these, this fails.
    @Test func tcdsBatch2HasCommonGAEntries() async {
        let all = await AeroRepository.shared.allTCDS(category: "Aircraft")
        let numbers = Set(all.map(\.tcdsNumber))
        #expect(numbers.contains("A37CE"))   // Cessna 208 Caravan
        #expect(numbers.contains("2A3"))     // Mooney M20 family
        #expect(numbers.contains("A00009CH")) // Cirrus SR20/SR22
    }
}
