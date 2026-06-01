import SwiftUI

/// A collection's icon is stored as a single `String`. If it's plain
/// ASCII (letters/digits/`.`/`-`/`_`) we treat it as an SF Symbol name;
/// otherwise we render it as text (emoji glyph). Ported from ICD Snap's
/// `CollectionIconKind` so emoji and Symbol can mix without bumping the
/// SwiftData schema each time we add an icon.
enum CollectionIconKind {
    case emoji(String)
    case symbol(String)

    static func from(_ raw: String) -> CollectionIconKind {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .emoji("📋") }
        let isSymbol = trimmed.unicodeScalars.allSatisfy { scalar in
            let c = Character(scalar)
            return c.isASCII && (c.isLetter || c.isNumber || c == "." || c == "-" || c == "_")
        }
        return isSymbol ? .symbol(trimmed) : .emoji(trimmed)
    }
}

struct CollectionIcon: View {
    let raw: String
    var size: CGFloat = 44
    var background: Color? = nil

    var body: some View {
        let bg = background ?? Color(.tertiarySystemFill)
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .fill(bg)
            content
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var content: some View {
        switch CollectionIconKind.from(raw) {
        case .emoji(let value):
            Text(value).font(.system(size: size * 0.55))
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(.tint)
        }
    }
}
