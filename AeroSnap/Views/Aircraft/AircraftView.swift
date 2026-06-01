import SwiftUI

/// TCDS detail + cross-link to "ADs that apply to this aircraft".
/// (The old standalone Aircraft tab was folded into Search's TCDS mode
/// 2026-05-31; these detail views still ship as they're the navigation
/// destinations from Search results.)

struct TCDSDetailView: View {
    let tcds: TCDSummary

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

                Divider()
                Text("Find ADs that apply").font(.caption.bold().smallCaps())
                    .foregroundStyle(.secondary)
                NavigationLink {
                    ADsForTCDSView(tcds: tcds)
                } label: {
                    Label("View applicable ADs", systemImage: "exclamationmark.triangle")
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

    var body: some View {
        List(ads) { ad in
            NavigationLink(value: SearchHit.ad(ad)) {
                ADRow(summary: ad)
            }
        }
        .navigationTitle("ADs · \(tcds.tcdsNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let firstModel = tcds.models.split(separator: ",").first {
                let needle = firstModel.trimmingCharacters(in: .whitespaces)
                ads = await AeroRepository.shared.searchADByMakeModel(needle)
            }
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
