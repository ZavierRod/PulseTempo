//
//  HealthKitPermissionView.swift
//  PulseTempo
//
//  Created by OpenAI Assistant on 11/6/25.
//

import SwiftUI
import HealthKit
import UIKit

/// Onboarding step that requests HealthKit authorization for heart-rate access
struct HealthKitPermissionView: View {

    // MARK: - Callbacks

    /// Called when HealthKit authorization succeeds
    var onAuthorized: () -> Void

    /// Optional callback when the user wants to go back
    var onBack: (() -> Void)?

    /// Optional callback when the user chooses to skip
    var onSkip: (() -> Void)?

    private let healthKitManager: HealthKitManager

    init(
        healthKitManager: HealthKitManager = .shared,
        onAuthorized: @escaping () -> Void,
        onBack: (() -> Void)? = nil,
        onSkip: (() -> Void)? = nil
    ) {
        self.healthKitManager = healthKitManager
        self.onAuthorized = onAuthorized
        self.onBack = onBack
        self.onSkip = onSkip
    }

    // MARK: - State

    @State private var authorizationStatus: HKAuthorizationStatus = .notDetermined
    @State private var isRequesting = false
    @State private var errorMessage: String?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            header

            VStack(alignment: .leading, spacing: 16) {
                Text("Connect to Apple Health")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text("PulseTempo adapts every playlist to your workout intensity. To do that, we need permission to read your heart-rate data from Apple Health. We only read; we never write or store your health data outside your device.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            statusView

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
                Button(action: requestAuthorization) {
                    HStack {
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

            Image(systemName: "heart.fill")
                .font(.system(size: 28))
                .foregroundColor(.pink)

            Spacer()

            if onBack != nil {
                // Keep layout balanced
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
        case .sharingAuthorized:
            return "Continue"
        case .sharingDenied:
            return "Request Again"
        case .notDetermined:
            fallthrough
        @unknown default:
            return isRequesting ? "Requesting…" : "Allow Health Access"
        }
    }

    private var statusDescription: String {
        switch authorizationStatus {
        case .sharingAuthorized:
            return "Access granted"
        case .sharingDenied:
            return "Access denied"
        case .notDetermined:
            return "Not determined"
        @unknown default:
            return "Unknown status"
        }
    }

    private var statusColor: Color {
        switch authorizationStatus {
        case .sharingAuthorized:
            return .green
        case .sharingDenied:
            return .red
        case .notDetermined:
            return .yellow
        @unknown default:
            return .gray
        }
    }

    private var shouldShowOpenSettings: Bool {
        authorizationStatus == .sharingDenied
    }

    // MARK: - Actions

    private func refreshAuthorizationStatus() {
        authorizationStatus = healthKitManager.getAuthorizationStatus()
    }

    private func requestAuthorization() {
        if authorizationStatus == .sharingAuthorized {
            onAuthorized()
            return
        }

        isRequesting = true
        errorMessage = nil

        healthKitManager.requestAuthorization { success, error in
            isRequesting = false
            refreshAuthorizationStatus()

            if success {
                onAuthorized()
            } else {
                if let error {
                    errorMessage = error.localizedDescription
                } else {
                    errorMessage = "We couldn't verify access. Please try again."
                }
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct HealthKitPermissionView_Previews: PreviewProvider {
    static var previews: some View {
        HealthKitPermissionView(
            onAuthorized: {},
            onBack: {},
            onSkip: {}
        )
    }
}
#endif
