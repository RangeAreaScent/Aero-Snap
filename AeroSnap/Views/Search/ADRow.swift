import SwiftUI

struct ADRow: View {
    let summary: ADSummary
    @AppStorage("copyFormat") private var copyFormatRaw: String = CopyFormat.withTitle.rawValue
    private var copyFormat: CopyFormat {
        CopyFormat(rawValue: copyFormatRaw) ?? .withTitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("AD \(summary.adNumber)")
                    .font(.headline.monospaced())
                if summary.isEmergency {
                    Text("EAD")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.red.opacity(0.15))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                }
                Spacer()
                if let ata = summary.ataChapter {
                    Text("ATA \(ata)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            Text(summary.title)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)
            if let date = summary.effectiveDate {
                Text("Effective " + date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        // Swipe-from-leading for one-tap copy in the user's default format.
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                let t = AeroCopier.copy(summary, format: copyFormat)
                CopyToast.shared.show(t)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .tint(.blue)
        }
        // Long-press menu for format selection without leaving the list.
        .contextMenu {
            Button {
                let t = AeroCopier.copy(summary, format: .short)
                CopyToast.shared.show(t)
            } label: { Label("Copy AD number", systemImage: "number") }
            Button {
                let t = AeroCopier.copy(summary, format: .withTitle)
                CopyToast.shared.show(t)
            } label: { Label("Copy AD number + title", systemImage: "text.line.first.and.arrowtriangle.forward") }
        }
    }
}

struct FARRow: View {
    let section: FARSection
    @AppStorage("copyFormat") private var copyFormatRaw: String = CopyFormat.withTitle.rawValue
    @AppStorage("bluebookCitation") private var bluebookCitation: Bool = false
    private var copyFormat: CopyFormat {
        CopyFormat(rawValue: copyFormatRaw) ?? .withTitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(displayCitation)
                .font(.headline.monospaced())
            Text(section.heading)
                .font(.subheadline)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                let t = AeroCopier.copy(section, format: copyFormat, bluebook: bluebookCitation)
                CopyToast.shared.show(t)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .tint(.blue)
        }
        .contextMenu {
            Button {
                let t = AeroCopier.copy(section, format: .short, bluebook: bluebookCitation)
                CopyToast.shared.show(t)
            } label: { Label("Copy citation", systemImage: "text.alignleft") }
            Button {
                let t = AeroCopier.copy(section, format: .withTitle, bluebook: bluebookCitation)
                CopyToast.shared.show(t)
            } label: { Label("Copy citation + heading", systemImage: "text.line.first.and.arrowtriangle.forward") }
        }
    }

    private var displayCitation: String {
        bluebookCitation ? AeroCopier.bluebookCitation(section) : section.citation
    }
}
