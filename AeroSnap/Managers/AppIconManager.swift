import Foundation
import UIKit
import Observation

/// Every available app icon in the bundle. `rawValue` matches the
/// `.appiconset` name in Assets.xcassets, which is also what
/// `UIApplication.setAlternateIconName(_:)` expects. The primary
/// icon is identified by `alternateIconName == nil`.
enum AppIcon: String, CaseIterable, Identifiable {
    case `default`     = "AppIcon"
    case skyBlue       = "AppIconSkyBlue"
    case peachPink     = "AppIconPeachPink"
    case deepCharcoal  = "AppIconDeepCharcoal"
    case blueberry     = "AppIconBlueberry"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .default:      "System Blue"
        case .skyBlue:      "Sky Blue"
        case .peachPink:    "Peach Pink"
        case .deepCharcoal: "Deep Charcoal"
        case .blueberry:    "Blueberry"
        }
    }

    /// `nil` is what `setAlternateIconName` expects for the primary icon.
    var alternateIconName: String? {
        self == .default ? nil : rawValue
    }

    /// Premium icons are gated behind the supporter purchase, same
    /// as the matching theme. The free `default` icon always works.
    var isPremium: Bool {
        self != .default
    }

    /// The matching premium `AppTheme` (if any) — useful for showing
    /// the icon picker next to the theme picker and visually pairing
    /// them. The default icon doesn't pair with a theme.
    var matchingTheme: AppTheme? {
        switch self {
        case .default:      nil
        case .skyBlue:      .skyBlue
        case .peachPink:    .peachPink
        case .deepCharcoal: .deepCharcoal
        case .blueberry:    .blueberry
        }
    }
}

@MainActor
@Observable
final class AppIconManager {
    static let shared = AppIconManager()

    /// Mirrors `UIApplication.alternateIconName` so @Observable can
    /// drive picker UI without each tap forcing a re-fetch.
    private(set) var currentIcon: AppIcon

    private init() {
        let name = UIApplication.shared.alternateIconName
        self.currentIcon = AppIcon.allCases.first {
            $0.alternateIconName == name
        } ?? .default
    }

    var supportsAlternateIcons: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    /// Switches the home-screen icon. Silent no-op if the device
    /// doesn't support alternates, or if the requested icon is
    /// premium and the user hasn't unlocked premium.
    ///
    /// `setAlternateIconName` triggers a non-suppressible iOS
    /// system alert ("… would like to change your app's icon.").
    /// That's mandated by Apple — we can't hide it.
    @discardableResult
    func setIcon(_ icon: AppIcon, unlocked: Bool) async -> Bool {
        guard UIApplication.shared.supportsAlternateIcons else { return false }
        guard !icon.isPremium || unlocked else { return false }
        do {
            try await UIApplication.shared.setAlternateIconName(icon.alternateIconName)
            currentIcon = icon
            return true
        } catch {
            print("AppIconManager.setIcon: \(error)")
            return false
        }
    }
}
