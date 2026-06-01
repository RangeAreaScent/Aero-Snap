import SwiftUI
import SwiftData
import UIKit

@main
struct AeroSnapApp: App {
    let modelContainer: ModelContainer = Self.makeModelContainer()

    @State private var themeManager = ThemeManager.shared
    @State private var purchaseManager = PurchaseManager.shared

    init() {
        // Same rationale as ICDSnapApp: SwiftUI's interactive dismissal modifier
        // is unreliable when the SearchBar is a sibling of the List rather than
        // inside it. UIScrollView.appearance().keyboardDismissMode is the
        // behavior-only fallback that's safe for List rendering. See
        // ICDSnap/GOTCHAS.md (the canonical writeup).
        UIScrollView.appearance().keyboardDismissMode = .interactive
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(FavoriteManager.shared)
                .environment(AircraftCollectionManager.shared)
                .environment(themeManager)
                .environment(purchaseManager)
                .tint(themeManager.tint)
                .preferredColorScheme(themeManager.preferredColorScheme)
                .task {
                    FavoriteManager.shared.setup(context: modelContainer.mainContext)
                    AircraftCollectionManager.shared.setup(context: modelContainer.mainContext)
                    await purchaseManager.start()
                }
        }
        .modelContainer(modelContainer)
    }

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            FavoriteAD.self,
            AircraftCollection.self,
            AircraftCollectionItem.self,
            ADNote.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // Pre-release wipe fallback. Replace with VersionedSchema +
            // SchemaMigrationPlan before App Store submission.
            print("[AeroSnap] ModelContainer init failed, wiping store: \(error)")
            Self.wipeLocalStores()
            do {
                return try ModelContainer(for: schema, configurations: config)
            } catch {
                fatalError("Failed to initialize ModelContainer after wipe: \(error)")
            }
        }
    }

    private static func wipeLocalStores() {
        let fm = FileManager.default
        guard let appSupport = try? fm.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false
        ) else { return }
        guard let contents = try? fm.contentsOfDirectory(at: appSupport,
                                                         includingPropertiesForKeys: nil) else { return }
        for url in contents where url.lastPathComponent.contains(".store") {
            try? fm.removeItem(at: url)
        }
    }
}
