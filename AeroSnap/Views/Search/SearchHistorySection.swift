import SwiftUI

/// Shown in the empty-query state when the user has prior searches.
/// Chips re-run the search on tap; long-press deletes a single entry.
/// "Clear all" wipes the list.
struct SearchHistorySection: View {
    @State private var history = SearchHistoryManager.shared
    let onSelect: (String) -> Void

    var body: some View {
        if !history.queries.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Recent searches")
                        .font(.caption.weight(.semibold).smallCaps())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        history.clear()
                        Haptics.impact(.light)
                    } label: {
                        Text("Clear")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(history.queries, id: \.self) { q in
                            chip(for: q)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func chip(for q: String) -> some View {
        Button {
            onSelect(q)
            Haptics.selection()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption2)
                Text(q)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color(.secondarySystemFill), in: Capsule())
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                history.remove(q)
            } label: {
                Label("Remove", systemImage: "xmark")
            }
        }
    }
}
