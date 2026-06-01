import SwiftUI

/// Aero-flavored icon picker. Emoji + SF Symbol suggestions in two
/// scrolled sections. Pattern lifted from ICD Snap's CollectionIconPicker.
struct CollectionIconPicker: View {
    @Binding var selection: String

    static let emojiSuggestions: [String] = [
        // Aviation / aircraft
        "✈️", "🛩️", "🛫", "🛬", "🚁", "🪂", "🛸", "🛰️",
        // Tools / maintenance
        "🔧", "🔨", "🛠️", "🧰", "⚙️", "🪛", "🔩", "⛓️",
        // Hazards / safety
        "⚠️", "🚧", "🛑", "🔥", "🧯", "⚡", "☢️", "☣️",
        // Fluids / energy
        "🛢️", "⛽", "🔋", "💨", "💧", "🌬️",
        // Documents / workflow
        "📋", "📝", "📁", "📂", "📊", "🗂️", "📅", "⏰",
        // Status / flags
        "✅", "❌", "⭐", "🚩", "🎯", "🔔",
    ]

    static let symbolSuggestions: [String] = [
        // Aviation
        "airplane", "airplane.circle.fill", "airplane.departure",
        "airplane.arrival", "helicopter", "paperplane.fill",
        // Mechanic / wrench / tool
        "wrench.adjustable.fill", "wrench.and.screwdriver.fill",
        "hammer.fill", "screwdriver.fill", "gear", "gearshape.2.fill",
        // Engine / fuel / power
        "engine.combustion.fill", "fuelpump.fill", "oilcan.fill",
        "battery.100", "bolt.fill", "powerplug.fill",
        // Hazards / status
        "exclamationmark.triangle.fill", "exclamationmark.octagon.fill",
        "shield.fill", "checkmark.seal.fill", "xmark.seal.fill",
        // Workflow
        "list.clipboard.fill", "doc.text.fill", "tag.fill",
        "folder.fill", "tray.full.fill",
        "calendar", "clock.fill", "alarm.fill",
        "flag.fill", "star.fill", "bookmark.fill",
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            section(title: "Emoji", items: Self.emojiSuggestions)
            section(title: "Symbols", items: Self.symbolSuggestions)
        }
    }

    @ViewBuilder
    private func section(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    iconCell(item)
                }
            }
        }
    }

    private func iconCell(_ value: String) -> some View {
        let isSelected = selection == value
        return Button {
            selection = value
            Haptics.selection()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.accentColor, lineWidth: 1.5)
                        }
                    }
                iconContent(value)
            }
            .frame(height: 40)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(value)
    }

    @ViewBuilder
    private func iconContent(_ value: String) -> some View {
        switch CollectionIconKind.from(value) {
        case .emoji(let glyph):
            Text(glyph).font(.system(size: 22))
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.tint)
        }
    }
}
