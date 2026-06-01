import SwiftUI

/// Custom search bar mirroring ICD Snap's pattern (Views/Search/SearchBar.swift).
/// We avoid `.searchable(...)` so the logo header above the field stays
/// permanently visible — `.searchable` collapses the nav title on activation.
struct SearchBar: View {
    @Binding var text: String
    var prompt: String
    var isFocused: FocusState<Bool>.Binding

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(themeManager.outerForegroundColor ?? .secondary)
                .font(.system(size: 19, weight: .medium))

            TextField(prompt, text: $text, prompt: promptText)
                .focused(isFocused)
                .font(.system(size: 19))
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .foregroundStyle(themeManager.outerForegroundStyle)
                .tint(themeManager.outerForegroundColor ?? themeManager.tint)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(themeManager.outerForegroundColor ?? .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(barBackground, in: RoundedRectangle(cornerRadius: 14))
    }

    private var promptText: Text {
        if let color = themeManager.outerForegroundColor {
            return Text(prompt).foregroundColor(color.opacity(0.7))
        }
        return Text(prompt)
    }

    private var barBackground: AnyShapeStyle {
        if let palette = themeManager.palette {
            return AnyShapeStyle(palette.searchBarBackground)
        }
        return AnyShapeStyle(.regularMaterial)
    }
}
