import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class AircraftCollectionManager {
    static let shared = AircraftCollectionManager()
    private var context: ModelContext?

    private init() {}

    func setup(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func create(name: String, kind: CollectionKind = .aircraft,
                icon: String? = nil,
                model: String? = nil, notes: String? = nil) -> AircraftCollection? {
        guard let context, !name.isEmpty else { return nil }
        let collection = AircraftCollection(name: name, kind: kind,
                                            icon: icon,
                                            model: model, notes: notes)
        context.insert(collection)
        try? context.save()
        return collection
    }

    func addItem(_ adNumber: String, to collection: AircraftCollection) {
        guard let context else { return }
        // Avoid duplicates within a folder.
        if collection.items.contains(where: { $0.adNumber == adNumber }) { return }
        let item = AircraftCollectionItem(adNumber: adNumber)
        item.collection = collection
        context.insert(item)
        try? context.save()
    }

    func removeItem(_ item: AircraftCollectionItem) {
        context?.delete(item)
        try? context?.save()
    }

    func setModel(_ collection: AircraftCollection, model: String) {
        collection.model = model
        try? context?.save()
    }

    func delete(_ collection: AircraftCollection) {
        context?.delete(collection)
        try? context?.save()
    }
}
