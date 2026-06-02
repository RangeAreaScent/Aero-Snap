import SwiftUI

/// TCDS detail + cross-link to "ADs that apply to this aircraft".
/// (The old standalone Aircraft tab was folded into Search's TCDS mode
/// 2026-05-31; these detail views still ship as they're the navigation
/// destinations from Search results.)

struct TCDSDetailView: View {
    let tcds: TCDSummary

    /// Decode the `specifications` JSON blob into ordered key/value
    /// pairs for display. Returns an empty array on parse failure
    /// (treat as if no specs were provided).
    private var specs: [(label: String, value: String)] {
        guard let data = tcds.specifications.data(using: .utf8),
              let raw = try? JSONSerialization.jsonObject(with: data),
              let dict = raw as? [String: Any]
        else {
            return []
        }
        // Stable display order: known keys first, then anything else
        // alphabetically. Curators add new keys ad-hoc so this can't
        // be exhaustive — unknown keys still render, just at the end.
        let preferredOrder = [
            "common_name", "family",
            "engine", "engine_options",
            "category", "notable",
            "seats", "mtow_lbs",
        ]
        let prettyLabel: [String: String] = [
            "common_name":    "Common name",
            "family":         "Family",
            "engine":         "Engine",
            "engine_options": "Engine options",
            "category":       "Airworthiness category",
            "notable":        "Notable",
            "seats":          "Seats",
            "mtow_lbs":       "MTOW (lbs)",
        ]
        var ordered: [(String, String)] = []
        var seen = Set<String>()
        for key in preferredOrder {
            if let value = dict[key] {
                ordered.append((prettyLabel[key] ?? key,
                                "\(value)"))
                seen.insert(key)
            }
        }
        for key in dict.keys.sorted() where !seen.contains(key) {
            ordered.append((key.replacingOccurrences(of: "_", with: " ").capitalized,
                            "\(dict[key]!)"))
        }
        return ordered
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(tcds.manufacturer).font(.title3.bold())
                Text("TCDS \(tcds.tcdsNumber) · \(tcds.category)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                if let d = tcds.issueDate {
                    Text("Issued " + d)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Divider()
                Text("Models").font(.caption.bold().smallCaps())
                    .foregroundStyle(.secondary)
                Text(tcds.models)
                    .font(.callout)
                    .textSelection(.enabled)

                if !specs.isEmpty {
                    Divider()
                    Text("Specifications").font(.caption.bold().smallCaps())
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(specs, id: \.label) { row in
                            HStack(alignment: .firstTextBaseline) {
                                Text(row.label)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 130, alignment: .leading)
                                Text(row.value)
                                    .font(.caption)
                                    .textSelection(.enabled)
                                Spacer()
                            }
                        }
                    }
                }

                Divider()
                Text("Find ADs that apply").font(.caption.bold().smallCaps())
                    .foregroundStyle(.secondary)
                NavigationLink {
                    ADsForTCDSView(tcds: tcds)
                } label: {
                    Label("View applicable ADs",
                          systemImage: "arrow.triangle.branch")
                }
            }
            .padding()
        }
        .navigationTitle(tcds.tcdsNumber)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(CopyToastOverlay(), alignment: .top)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        let t = AeroCopier.copy(tcds, format: .short)
                        CopyToast.shared.show(t)
                    } label: { Label("TCDS number", systemImage: "number") }
                    Button {
                        let t = AeroCopier.copy(tcds, format: .withTitle)
                        CopyToast.shared.show(t)
                    } label: { Label("TCDS + manufacturer", systemImage: "text.line.first.and.arrowtriangle.forward") }
                    Button {
                        let t = AeroCopier.copyFullDetail(tcds)
                        CopyToast.shared.show(String(t.split(separator: "\n").first ?? ""))
                    } label: { Label("Full detail", systemImage: "doc.text") }
                } label: {
                    Image(systemName: "doc.on.doc")
                }
            }
        }
    }
}

struct ADsForTCDSView: View {
    let tcds: TCDSummary
    @State private var ads: [ADSummary] = []
    @State private var loaded = false

    /// Query needle = "<manufacturer> <first model>". Joining both
    /// gives the applicability JOIN's token-AND matcher both signals
    /// to filter on, vs the old "first model only" approach which
    /// over-matched for short model strings like Beech 35 → "35".
    private var queryNeedle: String {
        let firstModel = tcds.models
            .split(separator: ",")
            .first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        // Manufacturer often has corporate suffixes ("Cessna Aircraft
        // Company") that don't appear in applicability rows. Take the
        // first word as a proxy — "Cessna", "Piper", "Boeing", etc.
        let mfrShort = tcds.manufacturer
            .split(separator: " ")
            .first.map(String.init) ?? tcds.manufacturer
        return "\(mfrShort) \(firstModel)"
    }

    var body: some View {
        Group {
            if !loaded {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if ads.isEmpty {
                ContentUnavailableView {
                    Label("No matching ADs", systemImage: "checkmark.shield")
                } description: {
                    Text("No AD in the bundled corpus references \(tcds.manufacturer) \(tcds.models.split(separator: ",").first ?? "").")
                } actions: {
                    Text("Searched: \(queryNeedle.lowercased())")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                }
            } else {
                List(ads) { ad in
                    NavigationLink(value: SearchHit.ad(ad)) {
                        ADRow(summary: ad)
                    }
                }
            }
        }
        .navigationTitle(ads.isEmpty ? "ADs · \(tcds.tcdsNumber)"
                                     : "ADs · \(tcds.tcdsNumber) (\(ads.count))")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Generous limit — the "ADs for this aircraft" view is
            // curated for one type, not a search result page.
            ads = await AeroRepository.shared.searchADByMakeModel(
                queryNeedle, limit: 500
            )
            loaded = true
        }
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
