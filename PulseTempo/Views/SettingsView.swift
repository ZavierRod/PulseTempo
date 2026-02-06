//
//  SettingsView.swift
//  inSync
//
//  Created by Antigravity on 12/12/24.
//

import SwiftUI

/// Settings screen for configuring app preferences including wearable device selection
struct SettingsView: View {
    // MARK: - Properties
    
    @StateObject private var deviceManager = WearableDeviceManager()
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var showingDevicePicker = false
    @State private var showingSetupInstructions = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                GradientBackground()
                
                List {
                    // Wearable Device Section
                    Section {
                        HStack {
                            Image(systemName: deviceManager.selectedDevice.iconName)
                                .foregroundColor(deviceManager.selectedDevice.color)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Heart Rate Device")
                                    .font(.bebasNeueSubheadline)
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Text(deviceManager.selectedDevice.rawValue)
                                    .font(.bebasNeueBody)
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            Button("Change") {
                                showingDevicePicker = true
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.white.opacity(0.1))
                        
                        // Device Status
                        HStack {
                            Image(systemName: deviceManager.isDeviceConfigured() ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundColor(deviceManager.isDeviceConfigured() ? .green : .orange)
                            
                            Text(deviceManager.getDeviceStatusMessage())
                                .font(.bebasNeueCaption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .listRowBackground(Color.white.opacity(0.1))
                        
                        // Setup Instructions for Garmin
                        if deviceManager.selectedDevice == .garminVenu3S {
                            Button(action: {
                                showingSetupInstructions.toggle()
                            }) {
                                HStack {
                                    Image(systemName: "info.circle")
                                    Text("Setup Instructions")
                                    Spacer()
                                    Image(systemName: showingSetupInstructions ? "chevron.up" : "chevron.down")
                                }
                            }
                            .foregroundColor(.blue)
                            .listRowBackground(Color.white.opacity(0.1))
                            
                            if showingSetupInstructions {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(Array(deviceManager.selectedDevice.setupInstructions.enumerated()), id: \.offset) { index, instruction in
                                        HStack(alignment: .top, spacing: 8) {
                                            Text("\(index + 1).")
                                                .font(.bebasNeueCaption)
                                                .foregroundColor(.secondary)
                                            Text(instruction)
                                                .font(.bebasNeueCaption)
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                    }
                                    
                                    if let appStoreURL = deviceManager.selectedDevice.externalAppStoreURL {
                                        Link(destination: appStoreURL) {
                                            HStack {
                                                Image(systemName: "arrow.down.circle.fill")
                                                Text("Download Garmin Connect")
                                            }
                                            .font(.caption.bold())
                                        }
                                        .padding(.top, 4)
                                    }
                                }
                                .padding(.vertical, 4)
                                .listRowBackground(Color.white.opacity(0.1))
                            }
                        }
                    } header: {
                        Text("Wearable Device")
                            .foregroundColor(.white.opacity(0.8))
                    } footer: {
                        Text("Select which device you'll use for heart rate monitoring during workouts. Expected latency: \(deviceManager.selectedDevice.expectedLatency)")
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    // BPM Matching Section (Placeholder for future settings)
                    Section {
                        HStack {
                            Text("BPM Tolerance")
                                .foregroundColor(.white)
                            Spacer()
                            Text("±5 BPM")
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .listRowBackground(Color.white.opacity(0.1))
                        
                        HStack {
                            Text("Matching Algorithm")
                            Spacer()
                            Text("Smart")
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .listRowBackground(Color.white.opacity(0.1))
                    } header: {
                        Text("BPM Matching")
                            .foregroundColor(.white.opacity(0.8))
                    } footer: {
                        Text("Configure how the app matches music to your heart rate")
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    // About Section
                    Section {
                        HStack {
                            Text("Version")
                                .foregroundColor(.white)
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .listRowBackground(Color.white.opacity(0.1))
                        
                        Button("Privacy Policy") {
                            // TODO: Open privacy policy
                        }
                        .listRowBackground(Color.white.opacity(0.1))
                        
                        Button("Terms of Service") {
                            // TODO: Open terms
                        }
                        .listRowBackground(Color.white.opacity(0.1))
                    } header: {
                        Text("About")
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingDevicePicker) {
            DevicePickerSheet(
                currentDevice: deviceManager.selectedDevice,
                onSelect: { device in
                    deviceManager.selectDevice(device)
                    showingDevicePicker = false
                }
            )
        }
    }
}

// MARK: - Device Picker Sheet

private struct DevicePickerSheet: View {
    let currentDevice: WearableDevice
    let onSelect: (WearableDevice) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDevice: WearableDevice
    
    init(currentDevice: WearableDevice, onSelect: @escaping (WearableDevice) -> Void) {
        self.currentDevice = currentDevice
        self.onSelect = onSelect
        _selectedDevice = State(initialValue: currentDevice)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                GradientBackground()
                
                List {
                    ForEach(WearableDevice.allCases) { device in
                        Button(action: {
                            selectedDevice = device
                        }) {
                            HStack {
                                Image(systemName: device.iconName)
                                    .foregroundColor(device.color)
                                    .frame(width: 30)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(device.rawValue)
                                        .font(.bebasNeueBody)
                                        .foregroundColor(.white)
                                    
                                    Text(device.description)
                                        .font(.bebasNeueCaption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                
                                Spacer()
                                
                                if selectedDevice == device {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.white.opacity(0.1))
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Select Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSelect(selectedDevice)
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedDevice == currentDevice)
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
#endif
