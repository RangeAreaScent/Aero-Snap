import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class FavoriteManager {
    static let shared = FavoriteManager()
    private var context: ModelContext?

    private init() {}

    func setup(context: ModelContext) {
        self.context = context
    }

    func isFavorite(adNumber: String) -> Bool {
        guard let context else { return false }
        var d = FetchDescriptor<FavoriteAD>(predicate: #Predicate { $0.adNumber == adNumber })
        d.fetchLimit = 1
        return ((try? context.fetch(d).first) != nil)
    }

    func toggle(adNumber: String) {
        guard let context else { return }
        var d = FetchDescriptor<FavoriteAD>(predicate: #Predicate { $0.adNumber == adNumber })
        d.fetchLimit = 1
        if let existing = try? context.fetch(d).first {
            context.delete(existing)
        } else {
            context.insert(FavoriteAD(adNumber: adNumber))
        }
        try? context.save()
    }

    func allFavoriteADNumbers() -> [String] {
        guard let context else { return [] }
        let d = FetchDescriptor<FavoriteAD>(sortBy: [SortDescriptor(\.savedAt, order: .reverse)])
        return (try? context.fetch(d).map(\.adNumber)) ?? []
    }
}
