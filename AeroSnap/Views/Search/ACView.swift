import SwiftUI

struct ACRow: View {
    let entry: ACEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.acNumber)
                    .font(.headline.monospaced())
                Spacer()
                if let f = entry.relatedFAR {
                    Text(f).font(.caption2.monospaced()).foregroundStyle(.secondary)
                }
            }
            Text(entry.title)
                .font(.subheadline)
                .lineLimit(2)
            if let d = entry.issueDate {
                Text("Issued " + d)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button {
                _ = Pasteboard.copy(entry.acNumber)
                CopyToast.shared.show(entry.acNumber)
            } label: { Label("Copy AC number", systemImage: "number") }
            Button {
                _ = Pasteboard.copy("\(entry.acNumber) — \(entry.title)")
                CopyToast.shared.show("\(entry.acNumber) — \(entry.title)")
            } label: { Label("Copy AC + title", systemImage: "text.line.first.and.arrowtriangle.forward") }
        }
    }
}

struct ACDetailView: View {
    let entry: ACEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(entry.title)
                    .font(.title3.bold())
                HStack(spacing: 10) {
                    Text(entry.acNumber)
                        .font(.caption.monospaced())
                    if let d = entry.issueDate {
                        Label(d, systemImage: "calendar").font(.caption)
                    }
                    if let f = entry.relatedFAR {
                        Label(f, systemImage: "doc.text").font(.caption)
                    }
                }
                .foregroundStyle(.secondary)

                Divider()

                Label("Body PDF available on FAA.gov", systemImage: "doc.richtext")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text("Advisory Circular bodies are heavy PDFs (drawings, tables) that aren't bundled offline. Tap below to read the full text.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Link(destination: entry.pdfURL) {
                    Label("Open on FAA.gov", systemImage: "safari")
                        .font(.body.bold())
                }
                .padding(.top, 4)
            }
            .padding()
        }
        .navigationTitle(entry.acNumber)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(CopyToastOverlay(), alignment: .top)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        _ = Pasteboard.copy(entry.acNumber)
                        CopyToast.shared.show(entry.acNumber)
                    } label: { Label("AC number", systemImage: "number") }
                    Button {
                        _ = Pasteboard.copy("\(entry.acNumber) — \(entry.title)")
                        CopyToast.shared.show("\(entry.acNumber) — \(entry.title)")
                    } label: { Label("AC + title", systemImage: "text.line.first.and.arrowtriangle.forward") }
                    Button {
                        _ = Pasteboard.copy(entry.pdfURL.absoluteString)
                        CopyToast.shared.show("PDF link")
                    } label: { Label("PDF URL", systemImage: "link") }
                } label: {
                    Image(systemName: "doc.on.doc")
                }
            }
        }
    }
}
