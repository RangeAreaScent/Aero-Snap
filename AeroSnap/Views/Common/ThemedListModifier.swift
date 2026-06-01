import SwiftUI

/// Applies the active theme's background color to a List and its rows.
/// No-op when no palette is active.
struct ThemedListBackground: ViewModifier {
    @Environment(ThemeManager.self) private var themeManager

    func body(content: Content) -> some View {
        if let palette = themeManager.palette {
            content
                .scrollContentBackground(.hidden)
                .background(palette.background)
        } else {
            content
        }
    }
}

/// Applies the active theme's card background + separator tint to a list row.
/// IMPORTANT: SwiftUI's listRow* modifiers don't propagate through `if let`
/// branches inside a ViewModifier body — wrap nil intentionally rather than
/// conditionally applying.
struct ThemedRowBackground: ViewModifier {
    @Environment(ThemeManager.self) private var themeManager

    func body(content: Content) -> some View {
        content
            .listRowBackground(themeManager.palette?.cardBackground)
            .listRowSeparatorTint(themeManager.palette?.separator)
    }
}

extension View {
    func themedListBackground() -> some View { modifier(ThemedListBackground()) }
    func themedRowBackground() -> some View  { modifier(ThemedRowBackground())  }
}
