//
//  HealthKitPermissionView.swift
//  inSync
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
        ZStack {
            // White-to-black gradient background (inSync theme)
            GradientBackground()
            
            VStack(spacing: 24) {
                header

                VStack(alignment: .leading, spacing: 16) {
                    Text("Connect to Apple Health")
                        .font(.bebasNeueMedium)
                        .foregroundColor(.white)

                    Text("inSync adapts every playlist to your workout intensity. To do that, we need permission to read your heart-rate data from Apple Health. We only read; we never write or store your health data outside your device.")
                        .font(.bebasNeueSubheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                statusView

                Spacer()

                if let errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Something went wrong")
                            .font(.bebasNeueSubheadline)
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .font(.bebasNeueCaption)
                            .foregroundColor(.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(spacing: 12) {
                    Button(action: requestAuthorization) {
                        HStack {
                            if isRequesting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }

                            Text(primaryButtonTitle)
                                .font(.bebasNeueBody)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: isRequesting ? [Color.gray] : [Color.pink, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: Color.pink.opacity(0.4), radius: 15, x: 0, y: 8)
                    }
                    .disabled(isRequesting)

                    if shouldShowOpenSettings {
                        Button(action: openSettings) {
                            Text("Open Settings")
                                .font(.bebasNeueSubheadline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }

                    if let onSkip {
                        Button("Skip for now", action: onSkip)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .padding(24)
        }
        .onAppear(perform: refreshAuthorizationStatus)
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.bebasNeueSubheadline)
                        .foregroundColor(.white)
                }
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.pink, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                    .shadow(color: Color.pink.opacity(0.5), radius: 15, x: 0, y: 8)
                
                Image(systemName: "heart.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }

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
                .font(.bebasNeueSubheadline)
                .foregroundColor(.white)

            HStack(spacing: 12) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)

                Text(statusDescription)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
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
