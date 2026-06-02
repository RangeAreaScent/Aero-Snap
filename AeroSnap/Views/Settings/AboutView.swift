import SwiftUI

struct AboutView: View {
    @State private var meta: [String: String] = [:]

    private let appVersion: String = {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }()

    var body: some View {
        List {
            heroSection
            whatItDoesSection
            disclaimerSection
            databaseSection
            sourcesSection
            privacySection
            creditsSection
            contactSection
        }
        .themedListBackground()
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            meta = await AeroRepository.shared.databaseMeta()
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        Section {
            VStack(spacing: 14) {
                hero
                Text("Aero Snap")
                    .font(.title2.bold())
                Text("Version \(appVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Every AD, FAR, and TCDS — offline, on the hangar floor.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder private var hero: some View {
        if let img = UIImage.appIcon {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                )
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(Color.accentColor)
                    .frame(width: 84, height: 84)
                Image(systemName: "airplane")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - What it does

    private var whatItDoesSection: some View {
        Section("What it does") {
            VStack(alignment: .leading, spacing: 10) {
                bullet("Search 9,400+ FAA Airworthiness Directives by AD number, Make/Model, ATA chapter, 14 CFR citation, or full text.")
                bullet("Browse all 1,000+ sections of 14 CFR (Parts 39, 43, 65, 91, 121, 135, 145, 147 and more).")
                bullet("Look up Type Certificate Data Sheets and cross-reference applicable ADs in one tap.")
                bullet("Maintain a folder per tail number with auto-matched ADs and your own compliance notes.")
                bullet("Export favorites and compliance lists to PDF or CSV.")
                bullet("Works fully offline. No account. No ads. No tracking.")
            }
            .font(.callout)
            .padding(.vertical, 2)
        }
    }

    // MARK: - Disclaimer / Terms

    private var disclaimerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                clause(
                    title: "Reference only — not the controlled document.",
                    body: "Aero Snap bundles a snapshot of public-domain FAA material for fast offline lookup. It is **not** an authoritative source. For any compliance decision, return-to-service signoff, or signed maintenance record, consult the official FAA document via the in-app \"Open on Federal Register\" or \"Official PDF\" link, or via drs.faa.gov."
                )
                clause(
                    title: "Not affiliated with the FAA.",
                    body: "Aero Snap is an independent reference app. The Federal Aviation Administration has not reviewed, endorsed, or approved this app. \"FAA\" and related marks belong to their respective owners; the bundled regulatory text is reproduced under public-domain status (17 U.S.C. § 105)."
                )
                clause(
                    title: "Use at your own risk; the operator is responsible for compliance.",
                    body: "Aero Snap is provided \"as is\" without warranty of any kind, express or implied. The user — pilot, mechanic, IA, owner, operator — is solely responsible for verifying applicability and compliance with all current ADs, FARs, TCDS, and other regulatory material against the official source before acting."
                )
                clause(
                    title: "Snapshots age. Verify currency.",
                    body: "The bundled dataset reflects the FAA corpus as of the build date shown above (\(meta["build_date"] ?? "—"), dataset \(meta["dataset_version"] ?? "—")). New ADs issued after this date are not present until the next app update. Always cross-check against drs.faa.gov for the latest revisions on safety-critical work."
                )
            }
            .padding(.vertical, 4)
        } header: {
            Text("Use & disclaimer")
        } footer: {
            Text("Reading the four clauses above takes about a minute. They exist so the app can ship — and so you stay compliant when you use it.")
                .font(.footnote)
        }
    }

    // MARK: - Database

    private var databaseSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Aero Snap ships with a self-contained SQLite snapshot of the FAA corpus. Every search, browse, and lookup runs against this local file — no network round-trip, no API key, no rate limit.")
                    .font(.callout)

                Divider()

                statRow("Airworthiness Directives", meta["count_airworthiness_directives"], detail: "Federal Register modern corpus")
                statRow("Applicability rows (AD ↔ Make/Model)", meta["count_ad_applicability"], detail: "Regex-parsed from each AD's applicability section")
                statRow("14 CFR sections", meta["count_far_sections"], detail: "Parts relevant to airworthiness, maintenance, ops")
                statRow("Type Certificate Data Sheets", meta["count_type_certificates"], detail: "Hand-curated commodity GA + transport types")
                statRow("Advisory Circulars (index)", meta["count_advisory_circulars"], detail: "Title + link; bodies open on FAA.gov")
                statRow("Body-dropped ADs", meta["count__body_dropped"], detail: "Older than 15 years — summary + URL retained")

                Divider()

                clauseInline(
                    title: "Why some old AD bodies are dropped",
                    body: "Full AD body text for ADs older than 15 years is excluded from the bundle to keep the app under the App Store size envelope. The summary, applicability, and \"Open on Federal Register\" link remain, so the AD is still findable and the full text is one tap away."
                )
                clauseInline(
                    title: "How TCDS coverage works",
                    body: "The FAA's TCDS catalog is ~3,000+ entries and the canonical source (drs.faa.gov) is behind authentication. Aero Snap ships a curated subset of the most-looked-up commodity GA and transport types. Curation grows with each release; entries not in the bundle still link out to the DRS landing page."
                )
                clauseInline(
                    title: "How often the bundle updates",
                    body: "Targeting one bundle refresh per release. For time-critical ADs in between releases, the in-app links open the live document on Federal Register."
                )

                Divider()

                LabeledContent("Schema version", value: meta["schema_version"] ?? "—")
                LabeledContent("Dataset version", value: meta["dataset_version"] ?? "—")
                LabeledContent("Built", value: meta["build_date"] ?? "—")
            }
            .padding(.vertical, 4)
        } header: {
            Text("Database")
        } footer: {
            Text("All four bundled datasets are works of the United States Federal Government and are in the public domain under 17 U.S.C. § 105.")
                .font(.footnote)
        }
    }

    // MARK: - Sources

    private var sourcesSection: some View {
        Section {
            sourceRow("Airworthiness Directives",
                      source: "Federal Register API",
                      url: URL(string: "https://www.federalregister.gov/")!)
            sourceRow("14 CFR — Federal Aviation Regulations",
                      source: "eCFR XML API",
                      url: URL(string: "https://www.ecfr.gov/")!)
            sourceRow("Type Certificate Data Sheets",
                      source: "FAA Dynamic Regulatory System",
                      url: URL(string: "https://drs.faa.gov/browse/TCDSMODEL")!)
            sourceRow("Advisory Circulars",
                      source: "FAA Advisory Circular index",
                      url: URL(string: "https://www.faa.gov/regulations_policies/advisory_circulars")!)
        } header: {
            Text("Data sources")
        } footer: {
            Text("Tap any source to open it in Safari.")
                .font(.footnote)
        }
    }

    // MARK: - Privacy

    private var privacySection: some View {
        Section("Privacy") {
            VStack(alignment: .leading, spacing: 8) {
                Text("No analytics. No tracking. No account. No ads. Favorites, folders, and notes live only on this device.")
                    .font(.callout)
                Text("The only outgoing network call is the optional StoreKit supporter purchase — and the \"Open on Federal Register\" / \"Official PDF\" links you tap yourself.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
            Link(destination: privacyURL) {
                Label("Full Privacy Policy", systemImage: "hand.raised.fill")
            }
        }
    }

    // MARK: - Credits

    private var creditsSection: some View {
        Section("Credits") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Part of the Snap Series — sibling apps include ICD Snap, DOT Snap, LOINC Snap, and others.")
                    .font(.callout)
                Text("Thanks to the FAA, the Office of the Federal Register, and the eCFR maintainers for keeping the source corpus freely accessible. Thanks also to the A&P community whose reference manuals (AC 43.13-1B / 2B, type-club docs) shaped the search ergonomics.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Contact

    private var contactSection: some View {
        Section("Contact") {
            Link(destination: URL(string: "mailto:dui0828@gmail.com")!) {
                Label("dui0828@gmail.com", systemImage: "envelope.fill")
            }
            Link(destination: URL(string: "https://github.com/RangeAreaScent/Aero-Snap")!) {
                Label("github.com/RangeAreaScent/Aero-Snap", systemImage: "chevron.left.forwardslash.chevron.right")
            }
        }
    }

    // MARK: - Helpers

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("•").foregroundStyle(.secondary)
            Text(text)
        }
    }

    private func clause(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.callout.weight(.semibold))
            Text(LocalizedStringKey(body))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func clauseInline(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(body)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func statRow(_ label: String, _ raw: String?, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(formatCount(raw))
                .font(.body.monospacedDigit().weight(.semibold))
                .foregroundStyle(.tint)
        }
    }

    private func sourceRow(_ label: String, source: String, url: URL) -> some View {
        Link(destination: url) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(source)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundStyle(.tint)
            }
        }
    }

    private func formatCount(_ raw: String?) -> String {
        guard let raw, let n = Int(raw) else { return "—" }
        return Self.numberFormatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    private var privacyURL: URL {
        URL(string: "https://rangeareascent.github.io/Snap_Series/aerosnap/privacy/")!
    }
}
