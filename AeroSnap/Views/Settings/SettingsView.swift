import SwiftUI

struct SettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(PurchaseManager.self) private var purchaseManager

    @AppStorage("hapticEnabled") private var hapticEnabled: Bool = true
    @AppStorage("copyFormat") private var copyFormatRaw: String = CopyFormat.withTitle.rawValue
    @AppStorage("bluebookCitation") private var bluebookCitation: Bool = false

    @State private var showThemePicker = false
    @State private var restoreResultMessage: String?
    @State private var meta: [String: String] = [:]

    private var copyFormat: Binding<CopyFormat> {
        Binding(
            get: { CopyFormat(rawValue: copyFormatRaw) ?? .withTitle },
            set: { copyFormatRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                appearanceSection
                copySection
                feedbackSection
                dataSection
                aboutSection
                supportSection
            }
            .themedListBackground()
            .navigationTitle("Settings")
            .task {
                meta = await AeroRepository.shared.databaseMeta()
            }
            .sheet(isPresented: $showThemePicker) {
                ThemePickerSheet()
            }
            .alert("Restore Purchase", isPresented: Binding(
                get: { restoreResultMessage != nil },
                set: { if !$0 { restoreResultMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(restoreResultMessage ?? "")
            }
        }
    }

    // MARK: - Appearance

    @ViewBuilder
    private var appearanceSection: some View {
        Section("Appearance") {
            Button {
                showThemePicker = true
            } label: {
                HStack {
                    Label("Theme", systemImage: "paintpalette")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(themeManager.current.label)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .themedRowBackground()
        }
    }

    // MARK: - Copy Format

    @ViewBuilder
    private var copySection: some View {
        Section {
            Picker("Default", selection: copyFormat) {
                ForEach(CopyFormat.allCases.filter { $0.isRowFormat }) { f in
                    Text(f.label).tag(f)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            .themedRowBackground()

            Toggle(isOn: $bluebookCitation) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bluebook 14 CFR citations")
                    Text("Legal style — “14 C.F.R. § 43.13”")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .themedRowBackground()
        } header: {
            Text("Copy Format")
        } footer: {
            Text(copyFormatExample)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var copyFormatExample: String {
        switch copyFormat.wrappedValue {
        case .short:      return "Example: AD 2024-10-18"
        case .withTitle:  return "Example: AD 2024-10-18 — Airworthiness Directives; Embraer S.A. Airplanes"
        case .fullDetail: return ""
        }
    }

    // MARK: - Feedback

    @ViewBuilder
    private var feedbackSection: some View {
        Section("Feedback") {
            Toggle("Haptic Feedback", isOn: $hapticEnabled)
                .themedRowBackground()
        }
    }

    // MARK: - Data

    @ViewBuilder
    private var dataSection: some View {
        Section("Data") {
            LabeledContent("Dataset", value: meta["dataset_version"] ?? "v1-poc")
                .themedRowBackground()
            LabeledContent("Build", value: meta["build_date"] ?? "—")
                .themedRowBackground()
            LabeledContent("Airworthiness Directives",
                           value: meta["count_airworthiness_directives"].flatMap(formatCount) ?? "—")
                .themedRowBackground()
            LabeledContent("14 CFR sections",
                           value: meta["count_far_sections"].flatMap(formatCount) ?? "—")
                .themedRowBackground()
            LabeledContent("TCDS",
                           value: meta["count_type_certificates"].flatMap(formatCount) ?? "—")
                .themedRowBackground()
            LabeledContent("Advisory Circulars",
                           value: meta["count_advisory_circulars"].flatMap(formatCount) ?? "—")
                .themedRowBackground()
            LabeledContent("AD ↔ Model rows",
                           value: meta["count_ad_applicability"].flatMap(formatCount) ?? "—")
                .themedRowBackground()
        }
    }

    private func formatCount(_ raw: String) -> String? {
        Int(raw).map { Self.numberFormatter.string(from: NSNumber(value: $0)) ?? "\($0)" }
    }

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    // MARK: - About

    @ViewBuilder
    private var aboutSection: some View {
        Section("About") {
            NavigationLink {
                AboutView()
            } label: {
                Label("About Aero Snap", systemImage: "info.circle")
            }
            .themedRowBackground()
        }
    }

    // MARK: - Support Developer

    @ViewBuilder
    private var supportSection: some View {
        if purchaseManager.isUnlocked {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text("🎉")
                        Text("Thank you for your support!")
                            .font(.headline)
                    }
                    Text("You've unlocked all premium themes.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Label("Aero Snap Supporter", systemImage: "heart.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(themeManager.tint, in: Capsule())
                }
                .padding(.vertical, 4)
                .themedRowBackground()

                Button {
                    Task { await runRestore() }
                } label: {
                    Label("Restore Purchase", systemImage: "arrow.clockwise")
                }
                .disabled(purchaseManager.isWorking)
                .themedRowBackground()
            }
        } else {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text("☕")
                        Text("Support Aero Snap")
                            .font(.headline)
                    }
                    Text("Aero Snap is free, ad-free, and always will be. If it saves you time in the hangar, consider buying me a coffee.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 6) {
                        Label("All premium themes", systemImage: "paintpalette.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Label("Future Pro features", systemImage: "sparkles")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                    .padding(.top, 2)
                }
                .padding(.vertical, 4)
                .themedRowBackground()

                Button {
                    Task { await runPurchase() }
                } label: {
                    HStack {
                        Label("Buy me a coffee", systemImage: "cup.and.saucer.fill")
                        Spacer()
                        Text(purchaseManager.priceDisplay)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(purchaseManager.product == nil || purchaseManager.isWorking)
                .themedRowBackground()

                Button {
                    Task { await runRestore() }
                } label: {
                    Label("Restore Purchase", systemImage: "arrow.clockwise")
                }
                .disabled(purchaseManager.isWorking)
                .themedRowBackground()

                if purchaseManager.product == nil {
                    Text("Purchases are not yet available in this build.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .themedRowBackground()
                }
            } footer: {
                if let error = purchaseManager.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func runPurchase() async {
        let ok = await purchaseManager.purchase()
        if ok {
            Haptics.notification(.success)
        }
    }

    private func runRestore() async {
        let ok = await purchaseManager.restore()
        restoreResultMessage = ok
            ? "Your purchase has been restored. All premium themes are unlocked."
            : "No previous purchase found on this Apple ID."
    }
}
