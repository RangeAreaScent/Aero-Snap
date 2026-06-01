import SwiftUI
import SwiftData

/// Collections — two kinds:
///   • **Aircraft**: tail-number-keyed, auto-matched ADs (spec §4-3)
///   • **Folder**:   generic grouping, manually added items (ICD-Snap pattern)
struct CollectionsView: View {
    @Environment(AircraftCollectionManager.self) private var manager
    @Query(sort: \AircraftCollection.name) private var collections: [AircraftCollection]
    @State private var showingNew = false

    var body: some View {
        NavigationStack {
            Group {
                if collections.isEmpty {
                    ContentUnavailableView(
                        "No collections yet",
                        systemImage: "folder.badge.plus",
                        description: Text("Tap + to add an aircraft (auto-matches ADs by model) or a generic folder.")
                    )
                } else {
                    List(collections) { c in
                        NavigationLink(value: c) {
                            collectionRow(c)
                        }
                        .themedRowBackground()
                    }
                    .themedListBackground()
                }
            }
            .navigationTitle("Collections")
            .navigationDestination(for: AircraftCollection.self) {
                AircraftCollectionDetail(collection: $0)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNew = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNew) {
                NewCollectionSheet(isPresented: $showingNew)
            }
        }
    }

    @ViewBuilder
    private func collectionRow(_ c: AircraftCollection) -> some View {
        HStack(spacing: 12) {
            CollectionIcon(raw: c.icon, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(c.name).font(.headline)
                switch c.kind {
                case .aircraft:
                    if let model = c.model {
                        Text(model).font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("No model set").font(.caption).foregroundStyle(.tertiary)
                    }
                case .folder:
                    Text("\(c.items.count) item\(c.items.count == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Create sheet

private struct NewCollectionSheet: View {
    @Environment(AircraftCollectionManager.self) private var manager
    @Binding var isPresented: Bool

    @State private var kind: CollectionKind = .aircraft
    @State private var name = ""
    @State private var model = ""
    @State private var notes = ""
    @State private var icon: String = CollectionKind.aircraft.defaultIcon
    @State private var modelSuggestions: [String] = []
    @State private var suggestionTask: Task<Void, Never>?

    var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(CollectionKind.allCases, id: \.self) { k in
                            Label(k.displayName, systemImage: k.iconName).tag(k)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: kind) { old, new in
                        // Switch the default icon when the user changes type,
                        // unless they've already picked a custom one.
                        if icon == old.defaultIcon { icon = new.defaultIcon }
                    }
                } footer: {
                    Text(kindFooter).font(.caption)
                }

                // Name + model/notes — primary inputs, kept up top so the
                // tall icon grid below doesn't push them off-screen.
                switch kind {
                case .aircraft:
                    Section("Aircraft") {
                        TextField("Tail number (e.g. N123AB)", text: $name)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        TextField("Model (e.g. Cessna 172)", text: $model)
                            .autocorrectionDisabled()
                            .onChange(of: model) { _, new in
                                refreshSuggestions(for: new)
                            }
                    }
                    if !modelSuggestions.isEmpty {
                        Section {
                            ForEach(modelSuggestions, id: \.self) { suggestion in
                                Button {
                                    model = suggestion
                                    modelSuggestions = []
                                    Haptics.selection()
                                } label: {
                                    HStack {
                                        Image(systemName: "airplane")
                                            .foregroundStyle(.secondary)
                                        Text(suggestion)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Image(systemName: "arrow.up.left")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text("Suggestions")
                        } footer: {
                            Text("Models found in the AD applicability matrix. Tap to fill.")
                                .font(.caption)
                        }
                    }
                case .folder:
                    Section("Folder") {
                        TextField("Name (e.g. 100-hour checklist ADs)", text: $name)
                        TextField("Notes (optional)", text: $notes, axis: .vertical)
                            .lineLimit(2...4)
                    }
                }

                // Icon preview + picker — visual customization, optional,
                // so it goes last after the required fields.
                Section("Icon") {
                    HStack(spacing: 12) {
                        CollectionIcon(raw: icon, size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(trimmedName.isEmpty ? namePlaceholder : trimmedName)
                                .font(.headline)
                                .foregroundStyle(trimmedName.isEmpty ? .secondary : .primary)
                            Text(kind.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    CollectionIconPicker(selection: $icon)
                }
            }
            .navigationTitle("New Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { create() }
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private var namePlaceholder: String {
        switch kind {
        case .aircraft: return "N123AB"
        case .folder:   return "Folder name"
        }
    }

    private var kindFooter: String {
        switch kind {
        case .aircraft:
            return "Auto-matches Airworthiness Directives that apply to this aircraft's model."
        case .folder:
            return "Add Airworthiness Directives manually from the AD detail screen."
        }
    }

    private func refreshSuggestions(for prefix: String) {
        suggestionTask?.cancel()
        let q = prefix.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else {
            modelSuggestions = []
            return
        }
        suggestionTask = Task {
            let results = await AeroRepository.shared.modelSuggestions(for: q)
            if Task.isCancelled { return }
            modelSuggestions = results
        }
    }

    private func create() {
        let m = model.trimmingCharacters(in: .whitespaces)
        let n = notes.trimmingCharacters(in: .whitespaces)
        manager.create(
            name: trimmedName,
            kind: kind,
            icon: icon,
            model: kind == .aircraft && !m.isEmpty ? m : nil,
            notes: kind == .folder && !n.isEmpty ? n : nil
        )
        isPresented = false
    }
}

// MARK: - Collection detail

struct AircraftCollectionDetail: View {
    let collection: AircraftCollection
    @Environment(AircraftCollectionManager.self) private var manager

    var body: some View {
        Group {
            switch collection.kind {
            case .aircraft: AircraftDetailBody(collection: collection)
            case .folder:   FolderDetailBody(collection: collection)
            }
        }
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: SearchHit.self) { hit in
            switch hit {
            case .ad(let s):   ADDetailView(adNumber: s.adNumber)
            case .far(let s):  FARDetailView(section: s)
            case .tcds(let t): TCDSDetailView(tcds: t)
            case .ac(let a):   ACDetailView(entry: a)
            }
        }
    }
}

private struct AircraftDetailBody: View {
    let collection: AircraftCollection
    @State private var ads: [ADSummary] = []

    var body: some View {
        List {
            Section("Aircraft") {
                LabeledContent("Tail number", value: collection.name)
                if let model = collection.model {
                    LabeledContent("Model", value: model)
                } else {
                    Text("No model set").foregroundStyle(.secondary)
                }
            }
            Section("Applicable ADs (\(ads.count))") {
                if collection.model == nil {
                    Text("Set this aircraft's model to auto-match ADs.")
                        .font(.caption).foregroundStyle(.secondary)
                } else if ads.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("No matches in current dataset", systemImage: "info.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("The current dataset covers recent ADs (2023+). Older or general-aviation models like \(collection.model ?? "") may not appear until the full corpus extract lands.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    ForEach(ads) { ad in
                        NavigationLink(value: SearchHit.ad(ad)) {
                            ADRow(summary: ad)
                        }
                    }
                }
            }
        }
        .task {
            if let model = collection.model {
                ads = await AeroRepository.shared.searchADByMakeModel(model)
            }
        }
    }
}

private struct FolderDetailBody: View {
    let collection: AircraftCollection
    @Environment(AircraftCollectionManager.self) private var manager
    @State private var items: [(item: AircraftCollectionItem, summary: ADSummary?)] = []

    var body: some View {
        List {
            if let notes = collection.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes).font(.callout)
                }
            }
            Section("ADs (\(collection.items.count))") {
                if collection.items.isEmpty {
                    Text("Empty folder.\nOpen an AD and tap the folder icon to add it here.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(items, id: \.item.adNumber) { pair in
                        if let summary = pair.summary {
                            NavigationLink(value: SearchHit.ad(summary)) {
                                ADRow(summary: summary)
                            }
                        } else {
                            Text(pair.item.adNumber)
                                .font(.subheadline.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { offsets in
                        for i in offsets { manager.removeItem(items[i].item) }
                    }
                }
            }
        }
        .toolbar {
            if !items.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    let safeName = collection.name.replacingOccurrences(of: " ", with: "-")
                    Menu {
                        ShareLink(
                            item: Exporter.tempFile(
                                named: "aero-snap-\(safeName).csv",
                                content: Exporter.csv(folder: collection, items: items)
                            ),
                            preview: SharePreview("\(collection.name) (CSV)",
                                                  image: Image(systemName: "tablecells"))
                        ) {
                            Label("Export as CSV", systemImage: "tablecells")
                        }
                        ShareLink(
                            item: Exporter.tempFile(
                                named: "aero-snap-\(safeName).pdf",
                                data: Exporter.pdf(
                                    title: "Aero Snap — \(collection.name)",
                                    plainText: Exporter.plainText(folder: collection, items: items)
                                )
                            ),
                            preview: SharePreview("\(collection.name) (PDF)",
                                                  image: Image(systemName: "doc.richtext"))
                        ) {
                            Label("Export as PDF", systemImage: "doc.richtext")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .task { await loadItems() }
    }

    private func loadItems() async {
        var out: [(AircraftCollectionItem, ADSummary?)] = []
        for it in collection.items {
            let d = await AeroRepository.shared.ad(byNumber: it.adNumber)
            out.append((it, d?.summary))
        }
        items = out
    }
}
