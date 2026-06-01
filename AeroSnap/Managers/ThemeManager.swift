import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    var current: AppTheme {
        didSet {
            UserDefaults.standard.set(current.rawValue, forKey: Self.storageKey)
        }
    }

    private static let storageKey = "appTheme"

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey) ?? ""
        self.current = AppTheme(rawValue: stored) ?? .system
    }

    var palette: ThemePalette? { current.palette }

    var tint: Color { palette?.accent ?? .accentColor }

    var preferredColorScheme: ColorScheme? {
        switch current {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        default:      current.isDarkPalette ? .dark : .light
        }
    }

    /// Premium selections are silently ignored when not unlocked.
    @discardableResult
    func select(_ theme: AppTheme, unlocked: Bool) -> Bool {
        if theme.isPremium && !unlocked { return false }
        current = theme
        return true
    }

    // MARK: Card content text styles (rows + detail screens)

    var cardPrimaryStyle: AnyShapeStyle {
        palette.map { AnyShapeStyle($0.cardText) }
            ?? AnyShapeStyle(HierarchicalShapeStyle.primary)
    }
    var cardSecondaryStyle: AnyShapeStyle {
        palette.map { AnyShapeStyle($0.cardTextSecondary) }
            ?? AnyShapeStyle(HierarchicalShapeStyle.secondary)
    }
    var cardTertiaryStyle: AnyShapeStyle {
        palette.map { AnyShapeStyle($0.cardTextTertiary) }
            ?? AnyShapeStyle(HierarchicalShapeStyle.tertiary)
    }

    // MARK: Outer-background foreground (title, logo, search bar text)

    var outerForegroundColor: Color? { palette?.outerForeground }
    var outerForegroundStyle: AnyShapeStyle {
        palette.map { AnyShapeStyle($0.outerForeground) }
            ?? AnyShapeStyle(HierarchicalShapeStyle.primary)
    }
}
