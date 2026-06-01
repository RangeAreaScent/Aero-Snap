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
}
