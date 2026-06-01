import SwiftUI
import SwiftData

struct FavoritesView: View {
    @Environment(FavoriteManager.self) private var favorites
    @State private var ads: [ADSummary] = []

    var body: some View {
        NavigationStack {
            Group {
                if ads.isEmpty {
                    ContentUnavailableView(
                        "No favorites yet",
                        systemImage: "star",
                        description: Text("Tap the star on an AD detail to save it.")
                    )
                } else {
                    List(ads) { s in
                        NavigationLink(value: SearchHit.ad(s)) {
                            ADRow(summary: s)
                        }
                        .themedRowBackground()
                    }
                    .themedListBackground()
                }
            }
            .navigationTitle("Favorites")
            .navigationDestination(for: SearchHit.self) { hit in
                switch hit {
                case .ad(let s):   ADDetailView(adNumber: s.adNumber)
                case .far(let s):  FARDetailView(section: s)
                case .tcds(let t): TCDSDetailView(tcds: t)
                case .ac(let a):   ACDetailView(entry: a)
                }
            }
            .task { await refresh() }
        }
    }

    private func refresh() async {
        let nums = favorites.allFavoriteADNumbers()
        var out: [ADSummary] = []
        for n in nums {
            if let d = await AeroRepository.shared.ad(byNumber: n) {
                out.append(d.summary)
            }
        }
        self.ads = out
    }
}
