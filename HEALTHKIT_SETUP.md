# HealthKit Setup Guide for PulseTempo

This guide walks you through configuring HealthKit for the PulseTempo app.

## Files Created

✅ **Services/HealthKitManager.swift** - Manages HealthKit authorization and configuration
✅ **Services/HeartRateService.swift** - Monitors live heart rate during workouts
✅ **PulseTempo.entitlements** - HealthKit entitlements file

## Required Xcode Configuration

### 1. Add HealthKit Capability

1. Open `PulseTempo.xcodeproj` in Xcode
2. Select the **PulseTempo** target
3. Go to the **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **HealthKit**

### 2. Add Privacy Usage Description

1. Select the **PulseTempo** target
2. Go to the **Info** tab
3. Add the following key-value pair:
   - **Key:** `Privacy - Health Share Usage Description` (or `NSHealthShareUsageDescription`)
   - **Value:** `PulseTempo needs access to your heart rate data to match music to your workout intensity.`

Alternatively, if you have an Info.plist file, add this:

```xml
<key>NSHealthShareUsageDescription</key>
<string>PulseTempo needs access to your heart rate data to match music to your workout intensity.</string>
```

### 3. Link the Entitlements File

1. Select the **PulseTempo** target
2. Go to the **Signing & Capabilities** tab
3. Verify that the entitlements file path is set to `PulseTempo/PulseTempo.entitlements`
4. If not, set it manually in **Build Settings** → **Code Signing Entitlements**

### 4. Add HealthKit Framework (if needed)

The HealthKit framework should be automatically linked, but if you encounter build errors:

1. Select the **PulseTempo** target
2. Go to **General** → **Frameworks, Libraries, and Embedded Content**
3. Click **+** and add `HealthKit.framework`

## Usage Example

### Request Authorization

```swift
import SwiftUI

struct OnboardingView: View {
    @State private var authorizationStatus: String = "Not Requested"
    
    var body: some View {
        VStack {
            Text("HealthKit Authorization")
                .font(.title)
            
            Text(authorizationStatus)
                .padding()
            
            Button("Request Authorization") {
                HealthKitManager.shared.requestAuthorization { success, error in
                    if success {
                        authorizationStatus = "Authorized"
                    } else {
                        authorizationStatus = "Denied: \(error?.localizedDescription ?? "Unknown error")"
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
```

### Monitor Heart Rate

```swift
import SwiftUI

struct WorkoutView: View {
    @StateObject private var heartRateService = HeartRateService()
    
    var body: some View {
        VStack {
            Text("\(heartRateService.currentHeartRate)")
                .font(.system(size: 72, weight: .bold))
            
            Text("BPM")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if heartRateService.isMonitoring {
                Button("Stop Monitoring") {
                    heartRateService.stopMonitoring()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Start Monitoring") {
                    heartRateService.startMonitoring { result in
                        switch result {
                        case .success:
                            print("Heart rate monitoring started")
                        case .failure(let error):
                            print("Failed to start monitoring: \(error)")
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
```

## Testing

### Simulator Testing

The iOS Simulator doesn't support HealthKit data. You'll need to:

1. Use the `simulateHeartRate(bpm:)` method for testing in the simulator
2. Test on a real device paired with an Apple Watch for actual heart rate data

### Real Device Testing

1. Ensure your iPhone is paired with an Apple Watch
2. Open the Health app and verify heart rate data is being collected
3. Run the app on your iPhone
4. Start a workout session
5. The app should receive live heart rate updates from your Apple Watch

## Architecture Overview

### HealthKitManager
- Singleton instance for managing HealthKit authorization
- Checks if HealthKit is available on the device
- Requests authorization for heart rate data
- Provides access to the HKHealthStore

### HeartRateService
- ObservableObject for SwiftUI integration
- Manages HKWorkoutSession for workout tracking
- Uses HKAnchoredObjectQuery for real-time heart rate streaming
- Publishes current heart rate to SwiftUI views
- Handles errors and monitoring state

## Next Steps

1. **Integrate with RunSessionViewModel** - Connect HeartRateService to your existing view model
2. **Add Onboarding Flow** - Create a proper onboarding flow to request permissions
3. **Handle Edge Cases** - Add proper error handling for missing Apple Watch, denied permissions, etc.
4. **Background Modes** - Configure background modes if you want the app to continue monitoring in the background

## Troubleshooting

### "HealthKit is not available"
- HealthKit is only available on physical iOS devices, not the simulator
- Use the debug `simulateHeartRate()` method for simulator testing

### "Authorization Denied"
- The user needs to grant permission in Settings → Privacy → Health → PulseTempo
- Guide users to enable permissions if they initially denied them

### "No heart rate data"
- Ensure the Apple Watch is paired and connected
- Verify the user has heart rate data in the Health app
- Check that the Apple Watch is worn correctly

### Build Errors
- Ensure HealthKit capability is added in Xcode
- Verify the entitlements file is linked correctly
- Check that the privacy usage description is added

## Resources

- [Apple HealthKit Documentation](https://developer.apple.com/documentation/healthkit)
- [HKWorkoutSession Guide](https://developer.apple.com/documentation/healthkit/hkworkoutsession)
- [Heart Rate Monitoring](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/1615177-heartrate)
