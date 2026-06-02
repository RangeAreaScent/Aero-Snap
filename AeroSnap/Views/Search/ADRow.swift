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
        // VoiceOver: "Airworthiness Directive 2024-17-05, emergency,
        // Boeing 737-800 nacelle fan-blade inspection, ATA 72, effective 2024-09-01"
        // beats the default which would read each of the 4-5 Text views
        // separately and stutter on "AD" / "EAD" abbreviations.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11yLabel)
        .accessibilityHint("Opens the AD detail view")
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

    private var a11yLabel: String {
        var parts: [String] = ["Airworthiness Directive \(summary.adNumber)"]
        if summary.isEmergency { parts.append("emergency") }
        parts.append(summary.title)
        if let ata = summary.ataChapter { parts.append("ATA chapter \(ata)") }
        if let date = summary.effectiveDate { parts.append("effective \(date)") }
        return parts.joined(separator: ", ")
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(displayCitation), \(section.heading)")
        .accessibilityHint("Opens the section text")
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
