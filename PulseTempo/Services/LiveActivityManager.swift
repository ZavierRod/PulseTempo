import Foundation
import ActivityKit
import SwiftUI

/// Manages the lifecycle of the Live Activity and Dynamic Island for active workouts.
class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    private var currentActivity: Activity<PulseTempoWidgetAttributes>?
    
    private init() {}
    
    /// Starts a new Live Activity when a workout begins.
    func startActivity(
        workoutType: String,
        heartRate: Double,
        elapsedTime: TimeInterval,
        queuedSongTitle: String,
        queuedArtistName: String,
        queuedSongBPM: Int?,
        artworkData: Data?,
        runModeIcon: String,
        totalDuration: TimeInterval? = nil
    ) {
        // End any existing activity first
        endActivity()
        
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ [LiveActivity] Activities are not enabled in Settings by the user.")
            return
        }
        
        let attributes = PulseTempoWidgetAttributes(workoutType: workoutType)
        let initialState = PulseTempoWidgetAttributes.ContentState(
            heartRate: heartRate,
            elapsedTime: elapsedTime,
            queuedSongTitle: queuedSongTitle,
            queuedArtistName: queuedArtistName,
            queuedSongBPM: queuedSongBPM,
            artworkData: artworkData,
            runModeIcon: runModeIcon,
            totalDuration: totalDuration
        )
        
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: initialState, staleDate: nil)
            )
            print("✅ [LiveActivity] Started successfully with ID: \(currentActivity?.id ?? "unknown")")
        } catch {
            print("❌ [LiveActivity] Failed to start: \(error.localizedDescription)")
        }
    }
    
    /// Updates the existing Live Activity with new data (e.g., HR change, new song).
    func updateActivity(
        heartRate: Double,
        elapsedTime: TimeInterval,
        queuedSongTitle: String,
        queuedArtistName: String,
        queuedSongBPM: Int?,
        artworkData: Data?,
        runModeIcon: String,
        totalDuration: TimeInterval? = nil
    ) {
        guard let activity = currentActivity else { return }
        
        let updatedState = PulseTempoWidgetAttributes.ContentState(
            heartRate: heartRate,
            elapsedTime: elapsedTime,
            queuedSongTitle: queuedSongTitle,
            queuedArtistName: queuedArtistName,
            queuedSongBPM: queuedSongBPM,
            artworkData: artworkData,
            runModeIcon: runModeIcon,
            totalDuration: totalDuration
        )
        
        Task {
            await activity.update(ActivityContent(state: updatedState, staleDate: nil))
        }
    }
    
    /// Ends the Live Activity when the workout completes or is discarded.
    func endActivity() {
        guard let activity = currentActivity else { return }
        
        Task {
            // Dismiss immediately rather than lingering on the lock screen
            await activity.end(nil, dismissalPolicy: .immediate)
            print("🛑 [LiveActivity] Ended successfully")
        }
        
        currentActivity = nil
    }
    
    // MARK: - Helper
    
    /// Compresses a UIImage to a small JPEG Data suitable for ActivityKit (must be < 4KB traditionally, though ActivityKit limits are slightly higher; smaller is safer for fast updates).
    static func compressArtwork(image: UIImage?) -> Data? {
        guard let image = image else { return nil }
        // Resize to a tiny thumbnail (e.g. 60x60) to keep the payload size minimal
        let targetSize = CGSize(width: 60, height: 60)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resizedImage.jpegData(compressionQuality: 0.5)
    }
}
