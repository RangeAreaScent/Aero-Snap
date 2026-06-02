import SwiftUI

struct FARView: View {
    @State private var parts: [String] = []
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Group {
                if !loaded {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if parts.isEmpty {
                    ContentUnavailableView(
                        "14 CFR data missing",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("The bundled SQLite has no FAR sections. Rebuild the data pipeline (see HANDOFF.md).")
                    )
                } else {
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
                            // VoiceOver: "14 CFR Part 91, General Operating Rules"
                            // beats the default which would only read the Text
                            // and skip the secondary label.
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("14 CFR Part \(p), \(partLabel(p))")
                            .accessibilityHint("Browse sections in this Part")
                        }
                        .themedRowBackground()
                    }
                    .themedListBackground()
                }
            }
            .navigationTitle("14 CFR")
            .navigationDestination(for: String.self) { FARPartView(part: $0) }
            .task {
                self.parts = await AeroRepository.shared.allFARParts()
                self.loaded = true
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
    @State private var loaded = false

    var body: some View {
        Group {
            if !loaded {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if sections.isEmpty {
                ContentUnavailableView(
                    "No sections",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Part \(part) has no sections in the bundled corpus.")
                )
            } else {
                List(sections) { s in
                    NavigationLink(value: s) {
                        FARRow(section: s)
                    }
                    .themedRowBackground()
                }
                .themedListBackground()
            }
        }
        .navigationTitle("Part \(part)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: FARSection.self) { FARDetailView(section: $0) }
        .task {
            self.sections = await AeroRepository.shared.farSections(part: part)
            self.loaded = true
        }
    }
}
