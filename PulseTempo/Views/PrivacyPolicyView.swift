import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ZStack {
            GradientBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    policySection(
                        title: "What We Collect",
                        body: "PulseTempo can collect account details you provide, including your email address, username, and optional name. During workouts, the app can also collect heart rate, cadence, run timing, selected playlists, and track metadata needed to build your workout queue and save run history."
                    )

                    policySection(
                        title: "How We Use It",
                        body: "We use this information to authenticate your account, save workout history, match music to your workout intensity, and sync your session between iPhone, Apple Watch, and Live Activities."
                    )

                    policySection(
                        title: "Services We Rely On",
                        body: "PulseTempo uses Apple HealthKit for workout and heart rate access, Apple Music and MusicKit for playlist and playback features, and the PulseTempo backend to store account and run data. If AI DJ features are separately configured and enabled, related prompt or voice requests may be sent to OpenAI and ElevenLabs."
                    )

                    policySection(
                        title: "Your Controls",
                        body: "You can revoke Apple Music or Health permissions at any time in iOS Settings. You can also permanently delete your PulseTempo account and associated run history from Settings > Delete Account."
                    )

                    policySection(
                        title: "Data Retention",
                        body: "Account and run history data are kept until you delete your account. Playlist selections and BPM cache data may also remain locally on your device until you remove them or delete the app."
                    )
                }
                .padding(24)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PulseTempo Privacy Policy")
                .font(.bebasNeueMedium)
                .foregroundColor(.white)

            Text("Effective March 30, 2026")
                .font(.bebasNeueCaption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func policySection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.bebasNeueSubheadline)
                .foregroundColor(.white)

            Text(body)
                .font(.bebasNeueCaption)
                .foregroundColor(.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.1))
        )
    }
}

#if DEBUG
struct PrivacyPolicyView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PrivacyPolicyView()
        }
    }
}
#endif
