//
//  WearableSelectionView.swift
//  PulseTempo
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
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                
                Text("Choose Your Device")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Select the wearable you'll use for heart rate monitoring during workouts")
                    .font(.body)
                    .foregroundColor(.secondary)
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
                            .foregroundColor(.blue)
                        Text("Setup Required")
                            .font(.headline)
                    }
                    
                    Text("Before continuing, you'll need to:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(Array(selectedDevice.setupInstructions.prefix(3).enumerated()), id: \.offset) { index, instruction in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(instruction)
                                .font(.caption)
                                .foregroundColor(.secondary)
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
                            .font(.caption.bold())
                            .foregroundColor(.blue)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
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
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                
                HStack {
                    Button(action: onBack) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Button(action: onSkip) {
                        Text("Skip")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
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
                Image(systemName: device.iconName)
                    .font(.system(size: 30))
                    .foregroundColor(device.color)
                    .frame(width: 50, height: 50)
                    .background(device.color.opacity(0.1))
                    .cornerRadius(10)
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(device.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("Latency: \(device.expectedLatency)")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Selection Indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
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
