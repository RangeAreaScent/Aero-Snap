import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 48)

                    appIconView

                    Spacer(minLength: 20)

                    Text("Aero Snap")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Spacer(minLength: 8)

                    Text("Every AD, FAR, and TCDS — offline, on the hangar floor.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Spacer(minLength: 48)

                    VStack(spacing: 20) {
                        FeatureRow(
                            symbolName: "magnifyingglass",
                            iconColor: .blue,
                            text: "Search by AD #, Make/Model, ATA chapter, or 14 CFR citation"
                        )
                        FeatureRow(
                            symbolName: "folder.fill",
                            iconColor: .teal,
                            text: "Auto-match ADs to every tail number you maintain"
                        )
                        FeatureRow(
                            symbolName: "book.fill",
                            iconColor: .orange,
                            text: "Full 14 CFR browser and TCDS catalog at your fingertips"
                        )
                        FeatureRow(
                            symbolName: "wifi.slash",
                            iconColor: .purple,
                            text: "100% offline. No ads, no subscriptions, no tracking"
                        )
                    }
                    .padding(.horizontal, 32)

                    Spacer(minLength: 32)

                    Text("Built for A&P mechanics, IAs, and aircraft owners. If Aero Snap saves you time in the hangar, consider supporting development — it keeps the app independent.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Spacer(minLength: 32)

                    Button {
                        hasSeenOnboarding = true
                    } label: {
                        Text("Get Started")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 40)
                }
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    private var appIconView: some View {
        Group {
            if let uiImage = UIImage.appIcon {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    )
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.accentColor)
                        .frame(width: 96, height: 96)
                    Image(systemName: "airplane")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

private struct FeatureRow: View {
    let symbolName: String
    let iconColor: Color
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: symbolName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}
