import SwiftUI

struct PremiumUnlockSheet: View {
    @Environment(PurchaseManager.self) private var purchaseManager
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.yellow, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            Image(systemName: "airplane")
                                .font(.system(size: 36))
                                .foregroundStyle(.white)
                        }

                        Text("Support Aero Snap")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Unlock these perks and keep the app independent:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    VStack(spacing: 0) {
                        BenefitRow(
                            icon: "paintpalette.fill",
                            iconColor: .purple,
                            title: "All Premium Themes",
                            subtitle: "Sky Blue, Peach Pink, Deep Charcoal, Blueberry"
                        )
                        Divider().padding(.leading, 52)
                        BenefitRow(
                            icon: "square.on.circle",
                            iconColor: .blue,
                            title: "All Premium App Icons",
                            subtitle: "Alternate icons handcrafted for the cockpit"
                        )
                    }
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12))

                    Divider()

                    Text("One-time purchase · No subscription · Yours forever")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        Task {
                            let ok = await purchaseManager.purchase()
                            if ok {
                                Haptics.notification(.success)
                                dismiss()
                            }
                        }
                    } label: {
                        Text("Buy me a coffee ☕ · \(purchaseManager.priceDisplay)")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .cornerRadius(14)
                    .disabled(purchaseManager.product == nil || purchaseManager.isWorking)

                    Button {
                        Task {
                            _ = await purchaseManager.restore()
                        }
                    } label: {
                        Text("Restore Purchase")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    if let error = purchaseManager.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .navigationTitle("Unlock Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Maybe Later", role: .cancel) { dismiss() }
                }
            }
        }
        .tint(themeManager.tint)
        .presentationDetents([.medium])
    }
}

private struct BenefitRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
