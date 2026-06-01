import Foundation
import Observation
import SwiftData

/// Per-AD user notes (e.g. compliance interpretation, shop-specific
/// reminders). Notes are global to the AD — for tail-specific compliance
/// state see `AircraftCollectionItem.notes`.
@Observable
@MainActor
final class ADNoteManager {
    static let shared = ADNoteManager()
    private var context: ModelContext?

    private init() {}

    func setup(context: ModelContext) {
        self.context = context
    }

    func note(for adNumber: String) -> ADNote? {
        guard let context else { return nil }
        var d = FetchDescriptor<ADNote>(predicate: #Predicate { $0.adNumber == adNumber })
        d.fetchLimit = 1
        return try? context.fetch(d).first
    }

    func hasNote(for adNumber: String) -> Bool {
        note(for: adNumber)?.body.isEmpty == false
    }

    /// Save (insert or update). Empty/whitespace text deletes the note instead.
    func save(adNumber: String, body: String) {
        guard let context else { return }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            delete(adNumber: adNumber)
            return
        }
        if let existing = note(for: adNumber) {
            existing.body = trimmed
            existing.updatedAt = .now
        } else {
            context.insert(ADNote(adNumber: adNumber, body: trimmed))
        }
        try? context.save()
    }

    func delete(adNumber: String) {
        guard let context, let existing = note(for: adNumber) else { return }
        context.delete(existing)
        try? context.save()
    }
}
