import SwiftUI

struct FARView: View {
    @State private var parts: [String] = []

    var body: some View {
        NavigationStack {
            List(parts, id: \.self) { p in
                NavigationLink(value: p) {
                    HStack {
                        Text("14 CFR Part \(p)")
                            .font(.headline)
                        Spacer()
                        Text(partLabel(p))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                .themedRowBackground()
            }
            .themedListBackground()
            .navigationTitle("14 CFR")
            .navigationDestination(for: String.self) { FARPartView(part: $0) }
            .task {
                self.parts = await AeroRepository.shared.allFARParts()
            }
        }
    }

    private func partLabel(_ p: String) -> String {
        switch p {
        case "39":  return "Airworthiness Directives"
        case "43":  return "Maintenance"
        case "65":  return "Airmen Certification"
        case "91":  return "General Operating Rules"
        case "121": return "Air Carriers"
        case "135": return "On-Demand Ops"
        case "145": return "Repair Stations"
        case "147": return "AMT Schools"
        default:    return ""
        }
    }
}

struct FARPartView: View {
    let part: String
    @State private var sections: [FARSection] = []

    var body: some View {
        List(sections) { s in
            NavigationLink(value: s) {
                FARRow(section: s)
            }
            .themedRowBackground()
        }
        .themedListBackground()
        .navigationTitle("Part \(part)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: FARSection.self) { FARDetailView(section: $0) }
        .task {
            self.sections = await AeroRepository.shared.farSections(part: part)
        }
    }
}
