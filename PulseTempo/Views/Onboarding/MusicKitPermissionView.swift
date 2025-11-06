//
//  MusicKitPermissionView.swift
//  PulseTempo
//
//  Created by OpenAI Assistant on 11/7/25.
//

import SwiftUI
import MusicKit
import UIKit

/// Onboarding step that requests Apple Music authorization from the user.
struct MusicKitPermissionView: View {

    // MARK: - Callbacks

    /// Called when MusicKit authorization succeeds.
    var onAuthorized: () -> Void

    /// Optional callback when the user wants to go back.
    var onBack: (() -> Void)?

    /// Optional callback when the user chooses to skip.
    var onSkip: (() -> Void)?

    // MARK: - State

    @State private var authorizationStatus: MusicAuthorization.Status
    @State private var isRequesting = false
    @State private var hasNotifiedAuthorized = false
    @State private var isCheckingSubscription = false
    @State private var hasSubscription: Bool?
    @State private var errorMessage: String?

    // MARK: - Initialization

    init(
        initialStatus: MusicAuthorization.Status = .notDetermined,
        onAuthorized: @escaping () -> Void,
        onBack: (() -> Void)? = nil,
        onSkip: (() -> Void)? = nil
    ) {
        self.onAuthorized = onAuthorized
        self.onBack = onBack
        self.onSkip = onSkip
        _authorizationStatus = State(initialValue: initialStatus)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            header

            VStack(alignment: .leading, spacing: 16) {
                Text("Connect Apple Music")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text("PulseTempo uses Apple Music to tailor playlists that match your workout intensity. Grant access so we can fetch songs, control playback, and keep the music flowing during every session.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            statusView

            if let guidanceText = guidanceText {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to continue")
                        .font(.system(size: 16, weight: .semibold))
                    Text(guidanceText)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            if let errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Something went wrong")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(spacing: 12) {
                Button(action: handlePrimaryAction) {
                    HStack(spacing: 12) {
                        if isRequesting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }

                        Text(primaryButtonTitle)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isRequesting ? Color.gray : Color.accentColor)
                    .cornerRadius(16)
                }
                .disabled(isRequesting)

                if shouldShowOpenSettings {
                    Button(action: openSettings) {
                        Text("Open Settings")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .buttonStyle(.bordered)
                }

                if shouldShowSubscriptionOffer {
                    Button(action: presentSubscriptionOffer) {
                        HStack(spacing: 8) {
                            if isCheckingSubscription {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            }

                            Text("Subscribe to Apple Music")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                    .disabled(isCheckingSubscription)
                }

                if let onSkip {
                    Button("Skip for now", action: onSkip)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .onAppear(perform: refreshAuthorizationStatus)
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                }
            }

            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 28))
                .foregroundColor(.accentColor)

            Spacer()

            if onBack != nil {
                Color.clear
                    .frame(width: 44, height: 44)
            }
        }
    }

    private var statusView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Authorization Status")
                .font(.system(size: 16, weight: .semibold))

            HStack(spacing: 12) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)

                Text(statusDescription)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Computed Properties

    private var primaryButtonTitle: String {
        switch authorizationStatus {
        case .authorized:
            return "Continue"
        case .notDetermined:
            fallthrough
        case .denied:
            fallthrough
        case .restricted:
            return isRequesting ? "Requesting…" : "Allow Apple Music Access"
        @unknown default:
            return isRequesting ? "Requesting…" : "Request Access"
        }
    }

    private var statusDescription: String {
        switch authorizationStatus {
        case .authorized:
            if let hasSubscription {
                return hasSubscription ? "Authorized with subscription" : "Authorized (subscription needed)"
            }
            return "Authorized"
        case .denied:
            return "Access denied"
        case .restricted:
            return "Access restricted"
        case .notDetermined:
            return "Not determined"
        @unknown default:
            return "Unknown status"
        }
    }

    private var statusColor: Color {
        switch authorizationStatus {
        case .authorized:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .yellow
        @unknown default:
            return .gray
        }
    }

    private var guidanceText: String? {
        switch authorizationStatus {
        case .denied:
            return "Apple Music access was denied. You can re-enable it at any time in Settings → Music → Apps → PulseTempo."
        case .restricted:
            return "This device has restrictions that prevent Apple Music access. Check Screen Time restrictions or contact your administrator."
        default:
            return nil
        }
    }

    private var shouldShowOpenSettings: Bool {
        switch authorizationStatus {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }

    private var shouldShowSubscriptionOffer: Bool {
        authorizationStatus == .authorized && hasSubscription == false
    }

    // MARK: - Actions

    private func handlePrimaryAction() {
        switch authorizationStatus {
        case .authorized:
            notifyAuthorizedIfNeeded()
        default:
            requestAuthorization()
        }
    }

    @MainActor
    private func refreshAuthorizationStatus() {
        let status = MusicKitManager.shared.authorizationStatus
        apply(status)
    }

    private func requestAuthorization() {
        guard !isRequesting else { return }

        isRequesting = true
        errorMessage = nil

        Task {
            await MusicKitManager.shared.requestAuthorization { status in
                Task { @MainActor in
                    isRequesting = false
                    apply(status)
                }
            }
        }
    }

    @MainActor
    private func apply(_ status: MusicAuthorization.Status) {
        authorizationStatus = status

        switch status {
        case .authorized:
            errorMessage = nil
            updateSubscriptionStatus()
            notifyAuthorizedIfNeeded()
        case .notDetermined, .denied, .restricted:
            errorMessage = nil
            hasSubscription = nil
            hasNotifiedAuthorized = false
            isCheckingSubscription = false
        @unknown default:
            errorMessage = nil
            hasSubscription = nil
            hasNotifiedAuthorized = false
            isCheckingSubscription = false
        }
    }

    private func updateSubscriptionStatus() {
        Task { @MainActor in
            guard authorizationStatus == .authorized else { return }

            isCheckingSubscription = true
            let subscribed = await MusicKitManager.shared.checkSubscriptionStatus()
            hasSubscription = subscribed
            isCheckingSubscription = false
        }
    }

    @MainActor
    private func notifyAuthorizedIfNeeded() {
        guard !hasNotifiedAuthorized else { return }
        hasNotifiedAuthorized = true
        onAuthorized()
    }

    @MainActor
    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    private func presentSubscriptionOffer() {
        Task { @MainActor in
            isCheckingSubscription = true
            MusicKitManager.shared.presentSubscriptionOffer()
            // After presenting the offer, optimistically assume the user may subscribe.
            isCheckingSubscription = false
            updateSubscriptionStatus()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct MusicKitPermissionView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MusicKitPermissionView(
                initialStatus: .notDetermined,
                onAuthorized: {},
                onBack: {},
                onSkip: {}
            )
            .previewDisplayName("Not Determined")

            MusicKitPermissionView(
                initialStatus: .denied,
                onAuthorized: {},
                onBack: {},
                onSkip: {}
            )
            .previewDisplayName("Denied")

            MusicKitPermissionView(
                initialStatus: .authorized,
                onAuthorized: {},
                onBack: {},
                onSkip: {}
            )
            .previewDisplayName("Authorized")
        }
    }
}
#endif
