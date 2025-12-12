//
//  SettingsView.swift
//  PulseTempo
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
            List {
                // Wearable Device Section
                Section {
                    HStack {
                        Image(systemName: deviceManager.selectedDevice.iconName)
                            .foregroundColor(deviceManager.selectedDevice.color)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Heart Rate Device")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(deviceManager.selectedDevice.rawValue)
                                .font(.body)
                        }
                        
                        Spacer()
                        
                        Button("Change") {
                            showingDevicePicker = true
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 8)
                    
                    // Device Status
                    HStack {
                        Image(systemName: deviceManager.isDeviceConfigured() ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(deviceManager.isDeviceConfigured() ? .green : .orange)
                        
                        Text(deviceManager.getDeviceStatusMessage())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
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
                        
                        if showingSetupInstructions {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(deviceManager.selectedDevice.setupInstructions.enumerated()), id: \.offset){ index, instruction in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("\(index + 1).")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(instruction)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
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
                        }
                    }
                } header: {
                    Text("Wearable Device")
                } footer: {
                    Text("Select which device you'll use for heart rate monitoring during workouts. Expected latency: \(deviceManager.selectedDevice.expectedLatency)")
                }
                
                // BPM Matching Section (Placeholder for future settings)
                Section {
                    HStack {
                        Text("BPM Tolerance")
                        Spacer()
                        Text("±5 BPM")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Matching Algorithm")
                        Spacer()
                        Text("Smart")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("BPM Matching")
                } footer: {
                    Text("Configure how the app matches music to your heart rate")
                }
                
                // About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Privacy Policy") {
                        // TODO: Open privacy policy
                    }
                    
                    Button("Terms of Service") {
                        // TODO: Open terms
                    }
                } header: {
                    Text("About")
                }
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
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Text(device.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedDevice == device {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
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
