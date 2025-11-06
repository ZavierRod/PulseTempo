import SwiftUI
import HealthKit
import MusicKit

/// Coordinates the multi-step onboarding flow, guiding the user through
/// welcome messaging and permission prompts before entering the main app.
struct OnboardingCoordinator: View {

    /// Represents the current step in the onboarding experience.
    enum OnboardingStep {
        case welcome
        case healthKit
        case musicKit
    }

    // MARK: - Properties

    /// Callback fired when onboarding has completed and the user can enter the app.
    var onFinished: () -> Void

    // MARK: - State

    /// Tracks the current onboarding step that should be displayed to the user.
    @State private var currentStep: OnboardingStep = .welcome

    /// Most recent HealthKit authorization status.
    @State private var healthAuthorizationStatus: HKAuthorizationStatus = .notDetermined

    /// Most recent MusicKit authorization status.
    @State private var musicAuthorizationStatus: MusicAuthorization.Status = .notDetermined

    /// Prevents firing the completion handler multiple times.
    @State private var didFinishOnboarding = false

    // MARK: - Derived State

    /// Indicates whether HealthKit permissions have been granted.
    private var isHealthAuthorized: Bool {
        healthAuthorizationStatus == .sharingAuthorized
    }

    /// Indicates whether MusicKit permissions have been granted.
    private var isMusicAuthorized: Bool {
        musicAuthorizationStatus == .authorized
    }

    // MARK: - Body

    var body: some View {
        Group {
            switch currentStep {
            case .welcome:
                WelcomeView {
                    advanceFromWelcome()
                }

            case .healthKit:
                HealthKitPermissionView(
                    onAuthorized: {
                        healthAuthorizationStatus = .sharingAuthorized
                        advanceFromHealthKit()
                    },
                    onBack: {
                        currentStep = .welcome
                    },
                    onSkip: {
                        currentStep = .musicKit
                    }
                )

            case .musicKit:
                MusicKitPermissionView(
                    onAuthorized: {
                        musicAuthorizationStatus = .authorized
                        advanceFromMusicKit()
                    },
                    onBack: {
                        if isHealthAuthorized {
                            currentStep = .healthKit
                        } else {
                            currentStep = .welcome
                        }
                    },
                    onSkip: {
                        finishOnboarding()
                    }
                )
            }
        }
        .task {
            refreshAuthorizationStates()
        }
        .onChange(of: healthAuthorizationStatus) { _ in
            reevaluateFlow()
        }
        .onChange(of: musicAuthorizationStatus) { _ in
            reevaluateFlow()
        }
    }

    // MARK: - Flow Control

    /// Reads the current permission states and updates onboarding flow accordingly.
    private func refreshAuthorizationStates() {
        healthAuthorizationStatus = HealthKitManager.shared.getAuthorizationStatus()
        musicAuthorizationStatus = MusicKitManager.shared.authorizationStatus
        reevaluateFlow()
    }

    /// Determines whether additional onboarding steps are needed or if we can finish.
    private func reevaluateFlow() {
        if isHealthAuthorized && isMusicAuthorized {
            finishOnboarding()
            return
        }

        switch currentStep {
        case .welcome:
            // Stay on the welcome step until the user taps "Get Started".
            break
        case .healthKit:
            if isHealthAuthorized {
                currentStep = .musicKit
            }
        case .musicKit:
            if !isHealthAuthorized {
                currentStep = .healthKit
            }
        }
    }

    /// Advances from the welcome screen to the next required step, if any.
    private func advanceFromWelcome() {
        if !isHealthAuthorized {
            currentStep = .healthKit
        } else if !isMusicAuthorized {
            currentStep = .musicKit
        } else {
            finishOnboarding()
        }
    }

    /// Advances from the HealthKit step if authorization has been granted.
    private func advanceFromHealthKit() {
        guard isHealthAuthorized else {
            return
        }

        if isMusicAuthorized {
            finishOnboarding()
        } else {
            currentStep = .musicKit
        }
    }

    /// Advances from the MusicKit step if authorization has been granted.
    private func advanceFromMusicKit() {
        guard isMusicAuthorized else {
            return
        }

        finishOnboarding()
    }

    /// Sends the user into the main app experience by invoking `onFinished` once.
    private func finishOnboarding() {
        guard !didFinishOnboarding else { return }
        didFinishOnboarding = true
        onFinished()
    }

}
