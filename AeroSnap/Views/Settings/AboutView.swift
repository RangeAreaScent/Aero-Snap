import SwiftUI

struct AboutView: View {
    private let appVersion: String = {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }()

    var body: some View {
        List {
            Section {
                VStack(alignment: .center, spacing: 14) {
                    Image(systemName: "airplane.circle.fill")
                        .resizable().scaledToFit()
                        .frame(width: 84, height: 84)
                        .foregroundStyle(.tint)
                    Text("Aero Snap")
                        .font(.title2.bold())
                    Text("Version \(appVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .listRowBackground(Color.clear)
            }

            Section("What it does") {
                Text("Aero Snap is a 100% offline reference for FAA Airworthiness Directives, Type Certificate Data Sheets, 14 CFR maintenance regulations, and Advisory Circulars. Built for the hangar floor.")
                    .font(.callout)
            }

            Section("Data") {
                LabeledContent("Airworthiness Directives", value: "FAA + Federal Register")
                LabeledContent("Type Certificates", value: "FAA DRS")
                LabeledContent("14 CFR", value: "eCFR.gov")
                LabeledContent("Advisory Circulars", value: "FAA")
                LabeledContent("License", value: "Public domain")
                LabeledContent("Update cadence", value: "Quarterly")
            }

            Section("Privacy") {
                Text("Aero Snap collects no analytics, no telemetry, and makes no remote calls except StoreKit for the optional Supporter purchase. Your favorites and collections live on this device only.")
                    .font(.callout)
                Link(destination: privacyURL) {
                    Label("Privacy Policy", systemImage: "hand.raised.fill")
                }
            }

            Section("Credits") {
                Text("Part of the Snap Series. From the makers of ICD Snap and DOT Snap.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .themedListBackground()
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var privacyURL: URL {
        URL(string: "https://rangeareascent.github.io/Snap_Series/aerosnap/privacy/")!
    }
}
