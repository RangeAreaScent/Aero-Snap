import SwiftUI

/// Lightweight in-app toast that briefly confirms a copy action. Lives at
/// the top of any screen via `.overlay(CopyToastOverlay(), alignment: .top)`.
@MainActor
@Observable
final class CopyToast {
    static let shared = CopyToast()
    private(set) var message: String?
    private var hideTask: Task<Void, Never>?

    private init() {}

    func show(_ text: String) {
        message = text
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            if Task.isCancelled { return }
            self?.message = nil
        }
    }
}

struct CopyToastOverlay: View {
    @State private var toast = CopyToast.shared

    var body: some View {
        VStack {
            if let msg = toast.message {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.doc.fill")
                    Text("Copied")
                        .font(.subheadline.weight(.semibold))
                    if !msg.isEmpty {
                        Text(msg)
                            .font(.subheadline)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.22), value: toast.message)
    }
}
