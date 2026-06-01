import SwiftUI

struct SearchView: View {
    @State private var vm = SearchViewModel()
    @FocusState private var isSearchFocused: Bool
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                logoHeader

                SearchBar(text: $vm.query,
                          prompt: vm.mode.placeholder,
                          isFocused: $isSearchFocused)
                    .padding(.horizontal)
                    .padding(.bottom, 12)

                // 6 modes don't fit in a SwiftUI segmented Picker (it clips
                // rather than scrolls). Use horizontally-scrolling capsule
                // chips instead — mirrors the iOS Mail filter chips pattern.
                modeChips
                    .padding(.bottom, 8)

                // TCDS sub-filter (Aircraft / Engine / Propeller / All) —
                // only relevant when SearchMode == .tcds.
                if vm.mode == .tcds {
                    tcdsCategoryChips
                        .padding(.bottom, 8)
                        .transition(.opacity)
                }

                resultList
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(themeManager.palette?.background ?? Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: SearchHit.self) { hit in
                // User tapped a result → commit current query to history.
                // onAppear fires once per push; dedup in the manager keeps
                // the list clean across re-mounts.
                Group {
                    switch hit {
                    case .ad(let s):   ADDetailView(adNumber: s.adNumber)
                    case .far(let s):  FARDetailView(section: s)
                    case .tcds(let t): TCDSDetailView(tcds: t)
                    case .ac(let a):   ACDetailView(entry: a)
                    }
                }
                .onAppear { vm.commitToHistory() }
            }
        }
        .task { await vm.loadTCDSBrowse() }
        .onChange(of: vm.query) { _, _ in vm.runSearch() }
    }

    private var modeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchMode.allCases) { m in
                    chip(
                        label: m.rawValue,
                        isSelected: vm.mode == m,
                        prominent: true
                    ) {
                        vm.mode = m
                        vm.onModeChange()
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var tcdsCategoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TCDSCategory.allCases) { cat in
                    chip(
                        label: cat.rawValue,
                        isSelected: vm.tcdsCategory == cat,
                        prominent: false
                    ) {
                        vm.tcdsCategory = cat
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    /// Capsule chip used by both mode + TCDS category strips.
    /// `prominent: true` uses accentColor fill; `false` uses a softer
    /// tint so the sub-filter doesn't compete visually with the mode chips.
    @ViewBuilder
    private func chip(label: String, isSelected: Bool,
                      prominent: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.selection()
        } label: {
            Text(label)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(chipBackground(isSelected: isSelected,
                                          prominent: prominent),
                            in: Capsule())
                .foregroundStyle(chipForeground(isSelected: isSelected,
                                                prominent: prominent))
        }
        .buttonStyle(.plain)
    }

    private func chipBackground(isSelected: Bool, prominent: Bool) -> AnyShapeStyle {
        if isSelected {
            return prominent
                ? AnyShapeStyle(Color.accentColor)
                : AnyShapeStyle(Color.accentColor.opacity(0.18))
        }
        return AnyShapeStyle(Color(.secondarySystemFill))
    }

    private func chipForeground(isSelected: Bool, prominent: Bool) -> Color {
        if isSelected {
            return prominent ? .white : .accentColor
        }
        return .primary
    }

    private var logoHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "airplane.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(height: 28)
                .foregroundStyle(themeManager.outerForegroundColor ?? themeManager.tint)
            Text("Aero Snap")
                .font(.largeTitle.bold())
        }
        .foregroundStyle(themeManager.outerForegroundStyle)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var resultList: some View {
        let trimmed = vm.query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            // Empty-query state — TCDS mode → catalog browse, all other
            // modes → recent searches above the contextual hint.
            if vm.mode == .tcds {
                tcdsBrowse
            } else {
                emptyStateWithHistory
            }
        } else if vm.isLoading && vm.hits.isEmpty {
            VStack { Spacer(); ProgressView(); Spacer() }
        } else if vm.hits.isEmpty {
            ContentUnavailableView.search(text: vm.query)
        } else if vm.mode == .all {
            sectionedAllResults
        } else {
            flatResults
        }
    }

    private var emptyStateWithHistory: some View {
        VStack(spacing: 16) {
            SearchHistorySection { q in vm.adoptHistory(q) }
                .padding(.top, 4)
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text(vm.mode.emptyStateHint)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - TCDS browse (mode = .tcds, empty query)
    private var tcdsBrowse: some View {
        let filtered = vm.applyTCDSCategory(vm.tcdsBrowse)
        return Group {
            if filtered.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "airplane.circle")
                        .font(.system(size: 44))
                        .foregroundStyle(.tertiary)
                    Text("No \(vm.tcdsCategory.rawValue.lowercased()) TCDS in current dataset.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List(filtered) { t in
                    NavigationLink(value: SearchHit.tcds(t)) {
                        TCDSRow(tcds: t)
                    }
                    .themedRowBackground()
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    // MARK: - Flat results (single-mode)
    @ViewBuilder
    private var flatResults: some View {
        let tcdsFiltered: [SearchHit] = {
            guard vm.mode == .tcds, vm.tcdsCategory != .all else { return vm.hits }
            return vm.hits.filter { hit in
                if case .tcds(let t) = hit { return t.category == vm.tcdsCategory.dbValue }
                return true
            }
        }()
        let isADMode = vm.mode == .adNumber || vm.mode == .makeModel
                    || vm.mode == .ataChapter
        let effectiveHits: [SearchHit] = {
            guard isADMode else { return tcdsFiltered }
            let ads = tcdsFiltered.compactMap {
                if case .ad(let s) = $0 { s } else { nil }
            }
            return vm.applyADSort(ads).map(SearchHit.ad)
        }()

        VStack(spacing: 0) {
            if isADMode && !effectiveHits.isEmpty {
                HStack {
                    Text("\(effectiveHits.count) result\(effectiveHits.count == 1 ? "" : "s")")
                        .font(.caption.smallCaps())
                        .foregroundStyle(.secondary)
                    Spacer()
                    sortMenu
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }
            List(effectiveHits) { hit in
                NavigationLink(value: hit) {
                    rowView(hit)
                }
                .themedRowBackground()
            }
            .listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    /// Sort menu shared by the All-mode AD section header + flat-list
    /// header in AD modes.
    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $vm.adSort) {
                ForEach(ADSortOrder.allCases) { order in
                    Label(order.rawValue, systemImage: order.symbolName).tag(order)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: vm.adSort.symbolName)
                    .font(.caption2)
                Text("Sort")
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(.secondarySystemFill), in: Capsule())
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Sectioned results (mode = .all)
    private var sectionedAllResults: some View {
        List {
            let adsRaw = vm.hits.compactMap { if case .ad(let x)   = $0 { x } else { nil } }
            let ads   = vm.applyADSort(adsRaw)
            let fars  = vm.hits.compactMap { if case .far(let x)  = $0 { x } else { nil } }
            let tcds  = vm.hits.compactMap { if case .tcds(let x) = $0 { x } else { nil } }
            let acs   = vm.hits.compactMap { if case .ac(let x)   = $0 { x } else { nil } }

            if !ads.isEmpty {
                Section {
                    ForEach(ads) { s in
                        NavigationLink(value: SearchHit.ad(s)) { ADRow(summary: s) }
                            .themedRowBackground()
                    }
                } header: {
                    HStack {
                        Text("Airworthiness Directives (\(ads.count))")
                        Spacer()
                        sortMenu
                    }
                }
            }
            if !fars.isEmpty {
                Section("14 CFR (\(fars.count))") {
                    ForEach(fars) { s in
                        NavigationLink(value: SearchHit.far(s)) { FARRow(section: s) }
                            .themedRowBackground()
                    }
                }
            }
            if !tcds.isEmpty {
                Section("Type Certificates (\(tcds.count))") {
                    ForEach(tcds) { t in
                        NavigationLink(value: SearchHit.tcds(t)) { TCDSRow(tcds: t) }
                            .themedRowBackground()
                    }
                }
            }
            if !acs.isEmpty {
                Section("Advisory Circulars (\(acs.count))") {
                    ForEach(acs) { a in
                        NavigationLink(value: SearchHit.ac(a)) { ACRow(entry: a) }
                            .themedRowBackground()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private func rowView(_ hit: SearchHit) -> some View {
        switch hit {
        case .ad(let s):   ADRow(summary: s)
        case .far(let s):  FARRow(section: s)
        case .tcds(let t): TCDSRow(tcds: t)
        case .ac(let a):   ACRow(entry: a)
        }
    }
}

struct TCDSRow: View {
    let tcds: TCDSummary
    @AppStorage("copyFormat") private var copyFormatRaw: String = CopyFormat.withTitle.rawValue
    private var copyFormat: CopyFormat {
        CopyFormat(rawValue: copyFormatRaw) ?? .withTitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(tcds.tcdsNumber).font(.headline.monospaced())
                Spacer()
                Text(tcds.category).font(.caption2).foregroundStyle(.secondary)
            }
            Text(tcds.manufacturer).font(.subheadline)
            Text(tcds.models).font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                let t = AeroCopier.copy(tcds, format: copyFormat)
                CopyToast.shared.show(t)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .tint(.blue)
        }
        .contextMenu {
            Button {
                let t = AeroCopier.copy(tcds, format: .short)
                CopyToast.shared.show(t)
            } label: { Label("Copy TCDS number", systemImage: "number") }
            Button {
                let t = AeroCopier.copy(tcds, format: .withTitle)
                CopyToast.shared.show(t)
            } label: { Label("Copy TCDS + manufacturer", systemImage: "text.line.first.and.arrowtriangle.forward") }
        }
    }
}

#Preview {
    SearchView()
}
