import SwiftUI

struct ThemePickerSheet: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(PurchaseManager.self) private var purchaseManager
    @Environment(\.dismiss) private var dismiss

    private var freeThemes: [AppTheme] { AppTheme.allCases.filter { !$0.isPremium } }
    private var premiumThemes: [AppTheme] { AppTheme.allCases.filter { $0.isPremium } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(freeThemes) { themeRow($0) }
                } footer: {
                    Text("System follows your iOS appearance setting.")
                        .font(.footnote)
                }

                Section {
                    ForEach(premiumThemes) { themeRow($0) }
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
                        Text("Support Aero Snap (\(purchaseManager.priceDisplay)) in Settings to unlock these themes.")
                            .font(.footnote)
                    }
                }
            }
            .themedListBackground()
            .navigationTitle("Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func themeRow(_ theme: AppTheme) -> some View {
        let isLocked = theme.isPremium && !purchaseManager.isUnlocked
        let isSelected = themeManager.current == theme
        return Button {
            if isLocked {
                Haptics.notification(.warning)
            } else {
                themeManager.select(theme, unlocked: purchaseManager.isUnlocked)
                Haptics.selection()
            }
        } label: {
            HStack(spacing: 14) {
                ThemeSwatch(theme: theme)
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.label)
                        .foregroundStyle(.primary)
                        .font(.body.weight(.medium))
                    if isLocked {
                        Text("Premium")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                if isLocked {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                } else if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .font(.body.weight(.semibold))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .themedRowBackground()
    }
}

private struct ThemeSwatch: View {
    let theme: AppTheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(swatchBackground)
            switch theme {
            case .system:
                HStack(spacing: 0) {
                    Color(.systemBackground)
                    Color.black
                }
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            case .light, .dark:
                EmptyView()
            default:
                if let palette = theme.palette {
                    Circle()
                        .fill(palette.accent)
                        .frame(width: 14, height: 14)
                }
            }
        }
        .frame(width: 40, height: 40)
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
    }

    private var swatchBackground: Color {
        switch theme {
        case .light: Color.white
        case .dark:  Color.black
        default:     theme.palette?.background ?? Color(.secondarySystemBackground)
        }
    }
}
