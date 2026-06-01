import SwiftUI
import SwiftData

struct ADDetailView: View {
    let adNumber: String

    @Environment(FavoriteManager.self) private var favorites
    @Environment(AircraftCollectionManager.self) private var collectionManager
    @Query(filter: #Predicate<AircraftCollection> { $0.kindRaw == "folder" },
           sort: \AircraftCollection.name) private var folders: [AircraftCollection]

    @AppStorage("copyFormat") private var copyFormatRaw: String = CopyFormat.withTitle.rawValue
    private var defaultCopyFormat: CopyFormat {
        CopyFormat(rawValue: copyFormatRaw) ?? .withTitle
    }

    @State private var detail: ADDetail?
    @State private var applicability: [ADApplicability] = []
    @State private var loaded = false
    @State private var showAddToCollection = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let d = detail {
                    header(d)
                    sectionDivider("Summary")
                    Text(d.summary.summary)
                        .font(.body)

                    if !applicability.isEmpty {
                        sectionDivider("Applies to (\(applicability.count))")
                        applicabilityList
                    }

                    if d.bodyDropped {
                        sectionDivider("Full text")
                        bodyDroppedNotice(d)
                    } else if !d.body.isEmpty {
                        sectionDivider("Full text")
                        Text(d.body)
                            .font(.callout)
                            .textSelection(.enabled)
                    }

                    sectionDivider("References")
                    referenceLinks(d)
                } else if loaded {
                    ContentUnavailableView("AD not found", systemImage: "questionmark.circle")
                } else {
                    ProgressView()
                }
            }
            .padding()
        }
        .navigationTitle("AD \(adNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(CopyToastOverlay(), alignment: .top)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    favorites.toggle(adNumber: adNumber)
                    Haptics.impact(.light)
                } label: {
                    Image(systemName: favorites.isFavorite(adNumber: adNumber) ? "star.fill" : "star")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if folders.isEmpty {
                        Text("No folders yet. Create one in Collections.")
                    } else {
                        ForEach(folders) { folder in
                            Button {
                                collectionManager.addItem(adNumber, to: folder)
                                Haptics.notification(.success)
                            } label: {
                                Label(folder.name, systemImage: "folder")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                copyMenu
            }
        }
        .task { await load() }
    }

    @ViewBuilder
    private var copyMenu: some View {
        Menu {
            if let s = detail?.summary {
                Button {
                    let text = AeroCopier.copy(s, format: .short)
                    CopyToast.shared.show(text)
                } label: { Label("AD number", systemImage: "number") }

                Button {
                    let text = AeroCopier.copy(s, format: .withTitle)
                    CopyToast.shared.show(text)
                } label: { Label("AD number + title", systemImage: "text.line.first.and.arrowtriangle.forward") }

                if let d = detail {
                    Button {
                        let text = AeroCopier.copyFullDetail(d, applicability: applicability)
                        // Show only the first line in the toast.
                        CopyToast.shared.show(String(text.split(separator: "\n").first ?? ""))
                    } label: { Label("Full detail", systemImage: "doc.text") }
                }
            }
        } label: {
            Image(systemName: "doc.on.doc")
        }
    }

    @ViewBuilder
    private func header(_ d: ADDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(d.summary.title)
                .font(.title3.bold())
            HStack(spacing: 12) {
                if let date = d.summary.effectiveDate {
                    Label(date, systemImage: "calendar")
                }
                if let ata = d.summary.ataChapter {
                    Label("ATA \(ata)", systemImage: "wrench.and.screwdriver")
                }
                if d.summary.isEmergency {
                    Label("Emergency AD", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let sb = d.supersededBy {
                Label("Superseded by AD \(sb)", systemImage: "arrow.forward.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if let s = d.supersedes {
                Label("Supersedes AD \(s)", systemImage: "arrow.backward.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let comp = d.complianceTime {
                Label(comp, systemImage: "clock.badge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var applicabilityList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(applicability, id: \.self) { a in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(a.manufacturer)
                        .font(.caption.bold())
                    Text(a.model)
                        .font(.caption.monospaced())
                    if let pt = a.partType {
                        Text("[\(pt)]")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let s = a.serialRangeStart, let e = a.serialRangeEnd {
                        Text("S/N \(s)–\(e)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func bodyDroppedNotice(_ d: ADDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Full body archived offline", systemImage: "tray.full")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text("This AD's full body text isn't bundled (15-year cutoff). "
                 + "Tap below to read the original on Federal Register.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let url = d.frURL {
                Link("Open on Federal Register", destination: url)
                    .font(.caption.bold())
            }
        }
    }

    @ViewBuilder
    private func referenceLinks(_ d: ADDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let url = d.frURL {
                Link(destination: url) {
                    Label("Federal Register entry", systemImage: "doc.text.magnifyingglass")
                }
            }
            if let url = d.pdfURL {
                Link(destination: url) {
                    Label("Official PDF", systemImage: "doc.richtext")
                }
            }
            if let amd = d.cfrAmendment {
                Text("Amendment 39-\(amd) (14 CFR Part 39)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
    }

    @ViewBuilder
    private func sectionDivider(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.bold().smallCaps())
            .foregroundStyle(.secondary)
            .padding(.top, 8)
    }

    private func load() async {
        async let d = AeroRepository.shared.ad(byNumber: adNumber)
        async let a = AeroRepository.shared.applicability(forAD: adNumber)
        self.detail = await d
        self.applicability = await a
        self.loaded = true
    }
}

struct FARDetailView: View {
    let section: FARSection
    @AppStorage("bluebookCitation") private var bluebookCitation: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(section.heading)
                    .font(.title3.bold())
                Text(displayCitation)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Divider()
                Text(section.body)
                    .font(.callout)
                    .textSelection(.enabled)
            }
            .padding()
        }
        .navigationTitle(displayCitation)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(CopyToastOverlay(), alignment: .top)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        let t = AeroCopier.copy(section, format: .short, bluebook: bluebookCitation)
                        CopyToast.shared.show(t)
                    } label: { Label("Citation only", systemImage: "text.alignleft") }

                    Button {
                        let t = AeroCopier.copy(section, format: .withTitle, bluebook: bluebookCitation)
                        CopyToast.shared.show(t)
                    } label: { Label("Citation + heading", systemImage: "text.line.first.and.arrowtriangle.forward") }

                    Button {
                        let t = AeroCopier.copyFullDetail(section, bluebook: bluebookCitation)
                        CopyToast.shared.show(String(t.split(separator: "\n").first ?? ""))
                    } label: { Label("Full section text", systemImage: "doc.text") }

                    Divider()

                    Button {
                        let other = AeroCopier.copy(section, format: .withTitle, bluebook: !bluebookCitation)
                        CopyToast.shared.show(other)
                    } label: {
                        Label(bluebookCitation ? "Plain style (one-off)" : "Bluebook style (one-off)",
                              systemImage: "arrow.left.arrow.right")
                    }
                } label: {
                    Image(systemName: "doc.on.doc")
                }
            }
        }
    }

    private var displayCitation: String {
        bluebookCitation ? AeroCopier.bluebookCitation(section) : section.citation
    }
}
