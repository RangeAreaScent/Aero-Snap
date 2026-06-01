import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "airplane.circle.fill")
                .resizable().scaledToFit()
                .frame(width: 120, height: 120)
                .foregroundStyle(.tint)
            Text("Aero Snap")
                .font(.largeTitle.bold())
            Text("Every AD, FAR, and TCDS — offline, on the hangar floor.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                Label("Search by AD #, Make/Model, ATA, or 14 CFR citation",
                      systemImage: "magnifyingglass")
                Label("Auto-match ADs to every tail number you maintain",
                      systemImage: "folder.fill")
                Label("100% offline. No ads. No subscription required.",
                      systemImage: "wifi.slash")
            }
            .font(.callout)
            .padding(.horizontal, 32)
            Spacer()
            Button {
                hasSeenOnboarding = true
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}
