import Foundation
import ActivityKit

public struct PulseTempoWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties
        public var heartRate: Double
        public var elapsedTime: TimeInterval
        public var queuedSongTitle: String
        public var queuedArtistName: String
        public var queuedSongBPM: Int?  // Added BPM property
        // Raw compressed JPEG data for artwork, because Live Activities cannot easily load remote URLs asynchronously
        public var artworkData: Data?
        public var runModeIcon: String
        public var totalDuration: TimeInterval?
    }

    // Fixed non-changing properties
    public var workoutType: String
}
