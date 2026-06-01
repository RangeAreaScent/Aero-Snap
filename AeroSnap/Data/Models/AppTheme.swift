import SwiftUI

/// Series-standard palette shape (playbook §7: same 7 themes, same hex
/// values across every Snap app). Ported from ICD Snap COLORWAYS.md.
struct ThemePalette: Sendable {
    let background: Color
    let searchBarBackground: Color
    let accent: Color
    let cardBackground: Color
    let cardText: Color
    let cardTextSecondary: Color
    let cardTextTertiary: Color
    let separator: Color
    /// Foreground color for content on the OUTER background (title, logo,
    /// search-bar text/icons) — chosen to contrast with `background`
    /// rather than `cardBackground`.
    let outerForeground: Color
}

enum AppTheme: String, CaseIterable, Identifiable, Codable, Sendable {
    // Free — no palette, system defaults
    case system
    case light
    case dark

    // Premium — light-toned (force .light scheme)
    case skyBlue
    case peachPink

    // Premium — dark-toned (force .dark scheme)
    case deepCharcoal
    case blueberry

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        case .skyBlue: "Sky Blue"
        case .peachPink: "Peach Pink"
        case .deepCharcoal: "Deep Charcoal"
        case .blueberry: "Blueberry"
        }
    }

    var isPremium: Bool {
        switch self {
        case .system, .light, .dark: false
        case .skyBlue, .peachPink, .deepCharcoal, .blueberry: true
        }
    }

    var isDarkPalette: Bool {
        switch self {
        case .deepCharcoal, .blueberry: true
        default: false
        }
    }

    /// `nil` for free themes — SwiftUI uses native materials/colors.
    var palette: ThemePalette? {
        switch self {
        case .system, .light, .dark:
            return nil

        case .skyBlue:
            return ThemePalette(
                background: Color(hex: "C9D3DE"),
                searchBarBackground: Color(hex: "A7B5C7"),
                accent: Color(hex: "A7B5C7"),
                cardBackground: Color(hex: "FFFFFF"),
                cardText: Color(hex: "1A1A1A"),
                cardTextSecondary: Color(hex: "5A5A5A"),
                cardTextTertiary: Color(hex: "8E8E8E"),
                separator: Color(hex: "C9D3DE"),
                outerForeground: Color.white
            )

        case .peachPink:
            return ThemePalette(
                background: Color(hex: "EAC3B7"),
                searchBarBackground: Color(hex: "D9A493"),
                accent: Color(hex: "D9A493"),
                cardBackground: Color(hex: "FFFFFF"),
                cardText: Color(hex: "1A1A1A"),
                cardTextSecondary: Color(hex: "5A5A5A"),
                cardTextTertiary: Color(hex: "8E8E8E"),
                separator: Color(hex: "EAC3B7"),
                outerForeground: Color.white
            )

        // Dark-toned: cardBackground is one step darker than the named tone
        // to compensate for iOS's ~5% vibrancy lift on .listRowBackground in
        // dark mode (rendered cards land near the named tone visually).
        case .deepCharcoal:
            return ThemePalette(
                background: Color(hex: "0A0808"),
                searchBarBackground: Color(hex: "2A2828"),
                accent: Color(hex: "E8B87A"),
                cardBackground: Color(hex: "1A1818"),
                cardText: Color(hex: "F5EDE0"),
                cardTextSecondary: Color(hex: "C8BFA8"),
                cardTextTertiary: Color(hex: "8C8470"),
                separator: Color(hex: "2A2828"),
                outerForeground: Color(hex: "F5EDE0")
            )
        case .blueberry:
            return ThemePalette(
                background: Color(hex: "141E2D"),
                searchBarBackground: Color(hex: "4A5F7F"),
                accent: Color(hex: "B8C9E0"),
                cardBackground: Color(hex: "2A3850"),
                cardText: Color(hex: "F5EDE0"),
                cardTextSecondary: Color(hex: "D0C9B8"),
                cardTextTertiary: Color(hex: "9E9685"),
                separator: Color(hex: "3F5168"),
                outerForeground: Color(hex: "F5EDE0")
            )
        }
    }
}
