import SwiftUI
import HealthKit
import MusicKit

/// Coordinates the multi-step onboarding flow, guiding the user through
/// welcome messaging and permission prompts before entering the main app.
struct OnboardingCoordinator: View {

    /// Represents the current step in the onboarding experience.
    enum OnboardingStep {
        case welcome
        case authentication  // NEW: Sign up or log in
        case wearableSelection
        case healthKit
        case musicKit
        case playlistSelection
    }

    // MARK: - Properties

    /// Callback fired when onboarding has completed and the user can enter the app.
    private let onFinished: () -> Void
    private let healthKitManager: HealthKitManager
    private let musicKitManager: MusicKitManager

    @Environment(\.scenePhase) private var scenePhase

    init(
        healthKitManager: HealthKitManager = .shared,
        musicKitManager: MusicKitManager = .shared,
        onFinished: @escaping () -> Void
    ) {
        self.healthKitManager = healthKitManager
        self.musicKitManager = musicKitManager
        self.onFinished = onFinished
    }

    // MARK: - State

    /// Tracks the current onboarding step that should be displayed to the user.
    @State private var currentStep: OnboardingStep = .welcome

    /// Most recent HealthKit authorization status.
    @State private var healthAuthorizationStatus: HKAuthorizationStatus = .notDetermined

    /// Most recent MusicKit authorization status.
    @State private var musicAuthorizationStatus: MusicAuthorization.Status = .notDetermined

    /// Prevents firing the completion handler multiple times.
    @State private var didFinishOnboarding = false
    
    /// Tracks whether user has selected playlists
    @State private var hasSelectedPlaylists = false
    
    /// Selected wearable device
    @State private var selectedWearableDevice: WearableDevice = .demoMode

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
            
            case .authentication:
                AuthenticationView(
                    onAuthenticated: {
                        advanceFromAuthentication()
                    },
                    onBack: {
                        currentStep = .welcome
                    }
                )
            
            case .wearableSelection:
                WearableSelectionView(
                    onDeviceSelected: { device in
                        selectedWearableDevice = device
                        advanceFromWearableSelection()
                    },
                    onBack: {
                        currentStep = .welcome
                    },
                    onSkip: {
                        selectedWearableDevice = .demoMode
                        currentStep = .healthKit
                    }
                )

            case .healthKit:
                HealthKitPermissionView(
                    healthKitManager: healthKitManager,
                    onAuthorized: {
                        healthAuthorizationStatus = .sharingAuthorized
                        advanceFromHealthKit()
                    },
                    onBack: {
                        currentStep = .wearableSelection
                    },
                    onSkip: {
                        currentStep = .musicKit
                    }
                )

            case .musicKit:
                MusicKitPermissionView(
                    initialStatus: musicAuthorizationStatus,
                    musicKitManager: musicKitManager,
                    onAuthorized: {
                        musicAuthorizationStatus = .authorized
                        advanceFromMusicKit()
                    },
                    onBack: {
                        if isHealthAuthorized {
                            currentStep = .healthKit
                        } else {
                            currentStep = .wearableSelection
                        }
                    },
                    onSkip: {
                        currentStep = .playlistSelection
                    }
                )
            
            case .playlistSelection:
                OnboardingPlaylistSelectionView(
                    onPlaylistsSelected: { tracks in
                        hasSelectedPlaylists = true
                        // TODO: Store selected tracks for the workout
                        print("✅ User selected \(tracks.count) tracks from playlists")
                        finishOnboarding()
                    },
                    onBack: {
                        currentStep = .musicKit
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
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else { return }
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
        healthAuthorizationStatus = healthKitManager.getAuthorizationStatus()
        musicAuthorizationStatus = musicKitManager.authorizationStatus
        reevaluateFlow()
    }

    /// Determines whether additional onboarding steps are needed or if we can finish.
    private func reevaluateFlow() {
        // Don't auto-advance if we're already past permissions
        if currentStep == .playlistSelection {
            return
        }
        
        if isHealthAuthorized && isMusicAuthorized {
            currentStep = .playlistSelection
            return
        }

        switch currentStep {
        case .welcome:
            // Stay on the welcome step until the user taps "Get Started".
            break
        case .authentication:
            // Stay on authentication until user signs in
            break
        case .wearableSelection:
            // Stay on wearable selection until user chooses a device
            break
        case .healthKit:
            if isHealthAuthorized {
                currentStep = .musicKit
            }
        case .musicKit:
            if !isHealthAuthorized {
                currentStep = .healthKit
            }
        case .playlistSelection:
            break
        }
    }

    /// Advances from the welcome screen to authentication.
    private func advanceFromWelcome() {
        currentStep = .authentication
    }
    
    /// Advances from authentication to wearable selection.
    private func advanceFromAuthentication() {
        currentStep = .wearableSelection
    }
    
    /// Advances from wearable selection to HealthKit permissions
    private func advanceFromWearableSelection() {
        if !isHealthAuthorized {
            currentStep = .healthKit
        } else if !isMusicAuthorized {
            currentStep = .musicKit
        } else {
            currentStep = .playlistSelection
        }
    }

    /// Advances from the HealthKit step if authorization has been granted.
    private func advanceFromHealthKit() {
        guard isHealthAuthorized else {
            return
        }

        if isMusicAuthorized {
            currentStep = .playlistSelection
        } else {
            currentStep = .musicKit
        }
    }

    /// Advances from the MusicKit step if authorization has been granted.
    private func advanceFromMusicKit() {
        guard isMusicAuthorized else {
            return
        }

        currentStep = .playlistSelection
    }

    /// Sends the user into the main app experience by invoking `onFinished` once.
    private func finishOnboarding() {
        guard !didFinishOnboarding else { return }
        didFinishOnboarding = true
        onFinished()
    }

}
