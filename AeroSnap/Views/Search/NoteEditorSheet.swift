import SwiftUI

struct NoteEditorSheet: View {
    let adNumber: String
    let initialBody: String
    let onSave: (String) -> Void
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @FocusState private var editorFocused: Bool

    var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $text)
                    .focused($editorFocused)
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
            }
            .navigationTitle("Note · AD \(adNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(text)
                        dismiss()
                    }
                    .disabled(text == initialBody)
                }
                if let onDelete {
                    ToolbarItem(placement: .bottomBar) {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Label("Delete note", systemImage: "trash")
                        }
                    }
                }
            }
            .onAppear {
                text = initialBody
                editorFocused = true
            }
        }
        .presentationDetents([.medium, .large])
    }
}
