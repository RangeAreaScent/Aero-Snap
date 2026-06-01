import Foundation
import SwiftData

@Model
final class FavoriteAD {
    @Attribute(.unique) var adNumber: String
    var savedAt: Date

    init(adNumber: String, savedAt: Date = .now) {
        self.adNumber = adNumber
        self.savedAt = savedAt
    }
}

enum CollectionKind: String, Codable, CaseIterable {
    case aircraft      // tail-number + model → auto-matched ADs
    case folder        // generic grouping → manually added items

    var displayName: String {
        switch self {
        case .aircraft: return "Aircraft"
        case .folder:   return "Folder"
        }
    }

    var iconName: String {
        switch self {
        case .aircraft: return "airplane"
        case .folder:   return "folder.fill"
        }
    }

    /// Default user-facing icon (emoji) when the user doesn't pick one.
    var defaultIcon: String {
        switch self {
        case .aircraft: return "✈️"
        case .folder:   return "📋"
        }
    }
}

@Model
final class AircraftCollection {
    @Attribute(.unique) var name: String
    var kindRaw: String                      // backing for CollectionKind
    var icon: String                         // emoji ("✈️") OR SF Symbol name ("airplane")
    var model: String?                       // aircraft kind: model
    var manufacturer: String?                // aircraft kind: manufacturer
    var notes: String?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \AircraftCollectionItem.collection)
    var items: [AircraftCollectionItem] = []

    var kind: CollectionKind {
        get { CollectionKind(rawValue: kindRaw) ?? .aircraft }
        set { kindRaw = newValue.rawValue }
    }

    init(name: String, kind: CollectionKind = .aircraft,
         icon: String? = nil,
         model: String? = nil, manufacturer: String? = nil,
         notes: String? = nil, createdAt: Date = .now) {
        self.name = name
        self.kindRaw = kind.rawValue
        self.icon = icon ?? kind.defaultIcon
        self.model = model
        self.manufacturer = manufacturer
        self.notes = notes
        self.createdAt = createdAt
    }
}

@Model
final class AircraftCollectionItem {
    var adNumber: String
    var complied: Bool
    var compliedAt: Date?
    var notes: String?
    var collection: AircraftCollection?

    init(adNumber: String, complied: Bool = false, compliedAt: Date? = nil,
         notes: String? = nil) {
        self.adNumber = adNumber
        self.complied = complied
        self.compliedAt = compliedAt
        self.notes = notes
    }
}

@Model
final class ADNote {
    var adNumber: String
    var body: String
    var updatedAt: Date

    init(adNumber: String, body: String, updatedAt: Date = .now) {
        self.adNumber = adNumber
        self.body = body
        self.updatedAt = updatedAt
    }
}
