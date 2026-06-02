import SwiftUI

struct AppIconPickerSheet: View {
    @Environment(AppIconManager.self) private var iconManager
    @Environment(PurchaseManager.self) private var purchaseManager
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss
    @State private var showPremiumSheet = false

    private var freeIcons: [AppIcon] { AppIcon.allCases.filter { !$0.isPremium } }
    private var premiumIcons: [AppIcon] { AppIcon.allCases.filter { $0.isPremium } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(freeIcons) { iconRow($0) }
                } footer: {
                    Text("Changing the icon shows an iOS system alert. That's mandated by Apple — Aero Snap can't suppress it.")
                        .font(.footnote)
                }

                Section {
                    ForEach(premiumIcons) { iconRow($0) }
                } header: {
                    HStack {
                        Text("Premium")
                        Spacer()
                        if !purchaseManager.isUnlocked {
                            Label("Locked", systemImage: "lock.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    if !purchaseManager.isUnlocked {
                        Text("Support Aero Snap (\(purchaseManager.priceDisplay)) in Settings to unlock these icons.")
                            .font(.footnote)
                    }
                }
            }
            .themedListBackground()
            .navigationTitle("App Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPremiumSheet) {
                PremiumUnlockSheet()
                    .environment(purchaseManager)
                    .environment(themeManager)
            }
        }
    }

    private func iconRow(_ icon: AppIcon) -> some View {
        let isLocked = icon.isPremium && !purchaseManager.isUnlocked
        let isSelected = iconManager.currentIcon == icon
        // If the user's current theme matches this icon (e.g. they've
        // got Sky Blue theme on and this row is the Sky Blue icon),
        // surface that with a small chip — encourages the visual
        // pairing without forcing it.
        let matchesCurrentTheme = icon.matchingTheme.map { $0 == themeManager.current } ?? false
        return Button {
            if isLocked {
                showPremiumSheet = true
                Haptics.notification(.warning)
            } else {
                Task {
                    await iconManager.setIcon(icon, unlocked: purchaseManager.isUnlocked)
                    Haptics.selection()
                }
            }
        } label: {
            HStack(spacing: 14) {
                AppIconPreview(icon: icon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(icon.label)
                        .foregroundStyle(.primary)
                        .font(.body.weight(.medium))
                    if matchesCurrentTheme {
                        Label("Matches your theme", systemImage: "paintpalette.fill")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.tint)
                    } else if isLocked {
                        Text("Premium")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                } else if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .themedRowBackground()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11yLabel(icon: icon, isLocked: isLocked,
                                      isSelected: isSelected,
                                      matchesTheme: matchesCurrentTheme))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }

    private func a11yLabel(icon: AppIcon, isLocked: Bool,
                           isSelected: Bool, matchesTheme: Bool) -> String {
        var parts: [String] = [icon.label]
        if isSelected      { parts.append("currently selected") }
        if matchesTheme    { parts.append("matches your active theme") }
        if isLocked        { parts.append("premium, locked") }
        return parts.joined(separator: ", ")
    }
}

private struct AppIconPreview: View {
    let icon: AppIcon

    /// Appiconsets compile into Assets.car and aren't reachable via
    /// UIImage(named:), so we render a parallel image set named
    /// "<AppIcon-name>Preview" via tools/make_app_icon.py and load
    /// that instead (e.g. AppIconSkyBlue → AppIconSkyBluePreview).
    private var previewImage: UIImage? {
        UIImage(named: "\(icon.rawValue)Preview")
    }

    var body: some View {
        Group {
            if let img = previewImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.gray.opacity(0.2)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }
}
