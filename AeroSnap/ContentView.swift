import SwiftUI

/// 5-tab IA decided 2026-05-31. Series shell standard is 4 tabs
/// (Search/Favorites/Collections/Settings); Aero adds **one domain
/// extension** — `FAR` — for the 14 CFR Part 39/43/65/91/121/135/145/147
/// browser, which mechanics open often enough to deserve its own tab.
/// TCDS (Aircraft) collapses into Search as a 6th search mode + browse
/// state; My Aircraft (tail-number folders) collapses into Collections.
struct ContentView: View {
    @State private var selection: AppTab = .search
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false

    var body: some View {
        TabView(selection: $selection) {
            Tab("Search", systemImage: "magnifyingglass", value: AppTab.search) {
                SearchView()
            }
            Tab("FAR", systemImage: "doc.text", value: AppTab.far) {
                FARView()
            }
            Tab("Favorites", systemImage: "star.fill", value: AppTab.favorites) {
                FavoritesView()
            }
            Tab("Collections", systemImage: "folder.fill", value: AppTab.collections) {
                CollectionsView()
            }
            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView()
            }
        }
        .onChange(of: selection) { _, _ in
            Haptics.impact(.light)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { hasSeenOnboarding = !$0 }
        )) {
            OnboardingView()
        }
    }
}

enum AppTab: Hashable {
    case search
    case far
    case favorites
    case collections
    case settings
}
