//
//  WearableSelectionView.swift
//  inSync
//
//  Created by Antigravity on 12/12/24.
//

import SwiftUI

/// View for selecting which wearable device to use for heart rate monitoring
struct WearableSelectionView: View {
    // MARK: - Properties
    
    @StateObject private var deviceManager = WearableDeviceManager()
    
    /// Callback when user selects a device and continues
    let onDeviceSelected: (WearableDevice) -> Void
    
    /// Callback to go back to previous onboarding step
    let onBack: () -> Void
    
    /// Callback to skip this step
    let onSkip: () -> Void
    
    // MARK: - State
    
    @State private var selectedDevice: WearableDevice = .appleWatch
    @State private var showingSetupInstructions = false
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // White-to-black gradient background (inSync theme)
            GradientBackground()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.pink, Color.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .shadow(color: Color.pink.opacity(0.5), radius: 15, x: 0, y: 8)
                        
                        Image(systemName: "applewatch.watchface")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                    }
                    
                    Text("Choose Your Device")
                        .font(.bebasNeueLarge)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Select the wearable you'll use for heart rate monitoring during workouts")
                        .font(.bebasNeueBody)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 60)
                .padding(.bottom, 40)
                
                // Device Options
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(WearableDevice.allCases) { device in
                            DeviceOptionCard(
                                device: device,
                                isSelected: selectedDevice == device,
                                onSelect: {
                                    selectedDevice = device
                                    showingSetupInstructions = device.requiresExternalApp
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
                
                // Instructions (if Garmin selected)
                if selectedDevice.requiresExternalApp {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.cyan)
                            Text("Setup Required")
                                .font(.bebasNeueTitle)
                                .foregroundColor(.white)
                        }
                        
                        Text("Before continuing, you'll need to:")
                            .font(.bebasNeueCaption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        ForEach(Array(selectedDevice.setupInstructions.prefix(3).enumerated()), id: \.offset) { index, instruction in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(index + 1).")
                                    .font(.bebasNeueCaption)
                                    .foregroundColor(.white.opacity(0.7))
                                Text(instruction)
                                    .font(.bebasNeueCaption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        
                        if let appName = selectedDevice.externalAppName {
                            Button(action: {
                                if let url = selectedDevice.externalAppStoreURL {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text("Download \(appName)")
                                }
                                .font(.bebasNeueCaption)
                                .foregroundColor(.cyan)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                
                // Bottom Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        deviceManager.selectDevice(selectedDevice)
                        onDeviceSelected(selectedDevice)
                    }) {
                        Text("Continue")
                            .font(.bebasNeueTitle)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color.pink, Color.purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: Color.pink.opacity(0.4), radius: 15, x: 0, y: 8)
                    }
                    
                    HStack {
                        Button(action: onBack) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        Button(action: onSkip) {
                            Text("Skip")
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Device Option Card

private struct DeviceOptionCard: View {
    let device: WearableDevice
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(device.color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: device.iconName)
                        .font(.system(size: 22))
                        .foregroundColor(device.color)
                }
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.rawValue)
                        .font(.bebasNeueTitle)
                        .foregroundColor(.white)
                    
                    Text(device.description)
                        .font(.bebasNeueCaption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.bebasNeueCaptionSmall)
                        Text("Latency: \(device.expectedLatency)")
                            .font(.bebasNeueCaptionSmall)
                    }
                    .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                // Selection Indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.bebasNeueTitle)
                    .foregroundColor(isSelected ? .pink : .white.opacity(0.3))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.pink.opacity(0.2) : Color.white.opacity(0.1))
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.pink : Color.white.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#if DEBUG
struct WearableSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        WearableSelectionView(
            onDeviceSelected: { device in
                print("Selected: \(device)")
            },
            onBack: {
                print("Back tapped")
            },
            onSkip: {
                print("Skip tapped")
            }
        )
    }
}
#endif
