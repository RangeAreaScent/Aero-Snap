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
                .environment(ADNoteManager.shared)
                .environment(themeManager)
                .environment(purchaseManager)
                .tint(themeManager.tint)
                .preferredColorScheme(themeManager.preferredColorScheme)
                .task {
                    FavoriteManager.shared.setup(context: modelContainer.mainContext)
                    AircraftCollectionManager.shared.setup(context: modelContainer.mainContext)
                    ADNoteManager.shared.setup(context: modelContainer.mainContext)
                    await purchaseManager.start()
                }
        }
        .modelContainer(modelContainer)
    }

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: AeroSnapSchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: AeroSnapMigrationPlan.self,
                configurations: config
            )
        } catch {
            // Migration plan failed — that's a real bug (the plan should
            // cover every shipped → current schema transition). Surface
            // it loudly so it can't slip past testflight.
            fatalError("ModelContainer init failed: \(error)")
        }
    }
}
