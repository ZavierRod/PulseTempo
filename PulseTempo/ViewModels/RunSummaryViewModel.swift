//
//  RunSummaryViewModel.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 11/5/25.
//

import Foundation
import SwiftUI
import Combine

/// View model for run summary screen
/// Displays post-run statistics and metrics
///
/// Python equivalent:
/// class RunSummaryViewModel:
///     def __init__(self, run_data: RunData):
///         self.run_data = run_data
///         self.duration = run_data.duration
///         self.average_hr = run_data.average_hr
///         self.max_hr = run_data.max_hr
///         self.tracks_played = run_data.tracks_played
final class RunSummaryViewModel: ObservableObject {
    
    // ═══════════════════════════════════════════════════════════
    // PUBLISHED PROPERTIES
    // ═══════════════════════════════════════════════════════════
    // MARK: - Published Properties
    
    /// Total duration of the run in seconds
    @Published var duration: TimeInterval
    
    /// Average heart rate during the run
    @Published var averageHeartRate: Int
    
    /// Maximum heart rate reached during the run
    @Published var maxHeartRate: Int
    
    /// Minimum heart rate during the run
    @Published var minHeartRate: Int
    
    /// List of tracks played during the run
    @Published var tracksPlayed: [Track]
    
    /// Run mode that was used
    @Published var runMode: RunMode
    
    /// Date when the run was completed
    @Published var completionDate: Date
    
    // ═══════════════════════════════════════════════════════════
    // COMPUTED PROPERTIES
    // ═══════════════════════════════════════════════════════════
    // MARK: - Computed Properties
    
    /// Formatted duration string (e.g., "25:30")
    ///
    /// Python equivalent:
    /// @property
    /// def formatted_duration(self) -> str:
    ///     minutes = int(self.duration // 60)
    ///     seconds = int(self.duration % 60)
    ///     return f"{minutes}:{seconds:02d}"
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Formatted completion date (e.g., "Nov 5, 2025 at 9:00 PM")
    var formattedCompletionDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: completionDate)
    }
    
    /// Heart rate range string (e.g., "120-165 BPM")
    var heartRateRange: String {
        return "\(minHeartRate)-\(maxHeartRate) BPM"
    }
    
    /// Total number of tracks played
    var trackCount: Int {
        return tracksPlayed.count
    }
    
    /// Average track BPM
    ///
    /// Python equivalent:
    /// @property
    /// def average_track_bpm(self) -> Optional[int]:
    ///     bpms = [t.bpm for t in self.tracks_played if t.bpm is not None]
    ///     if not bpms:
    ///         return None
    ///     return sum(bpms) // len(bpms)
    var averageTrackBPM: Int? {
        let bpms = tracksPlayed.compactMap { $0.bpm }
        guard !bpms.isEmpty else { return nil }
        return bpms.reduce(0, +) / bpms.count
    }
    
    // ═══════════════════════════════════════════════════════════
    // INITIALIZATION
    // ═══════════════════════════════════════════════════════════
    // MARK: - Initialization
    
    /// Initialize with run data
    ///
    /// - Parameters:
    ///   - duration: Total run duration in seconds
    ///   - averageHeartRate: Average HR during run
    ///   - maxHeartRate: Maximum HR during run
    ///   - minHeartRate: Minimum HR during run
    ///   - tracksPlayed: List of tracks played
    ///   - runMode: Run mode used
    ///   - completionDate: When the run was completed
    ///
    /// Python equivalent:
    /// def __init__(self, duration: float, average_heart_rate: int, 
    ///              max_heart_rate: int, min_heart_rate: int,
    ///              tracks_played: List[Track], run_mode: RunMode,
    ///              completion_date: datetime):
    ///     self.duration = duration
    ///     self.average_heart_rate = average_heart_rate
    ///     # ... etc
    init(
        duration: TimeInterval,
        averageHeartRate: Int,
        maxHeartRate: Int,
        minHeartRate: Int = 60,
        tracksPlayed: [Track],
        runMode: RunMode,
        completionDate: Date = Date()
    ) {
        self.duration = duration
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.minHeartRate = minHeartRate
        self.tracksPlayed = tracksPlayed
        self.runMode = runMode
        self.completionDate = completionDate
    }
    
    // ═══════════════════════════════════════════════════════════
    // PUBLIC METHODS
    // ═══════════════════════════════════════════════════════════
    // MARK: - Public Methods
    
    /// Get heart rate zone distribution
    /// Returns percentage of time spent in each HR zone
    ///
    /// - Returns: Dictionary mapping zone name to percentage
    ///
    /// Python equivalent:
    /// def get_hr_zone_distribution(self) -> Dict[str, float]:
    ///     # Simplified - would need actual HR samples for accurate calculation
    ///     zones = {
    ///         "Easy": 0.0,
    ///         "Moderate": 0.0,
    ///         "Hard": 0.0,
    ///         "Max": 0.0
    ///     }
    ///     # Calculate based on average HR
    ///     return zones
    func getHRZoneDistribution() -> [String: Double] {
        // Simplified calculation based on average HR
        // In a real app, you'd track HR samples over time
        
        let maxHR = 200.0  // Simplified max HR
        let avgPercentage = Double(averageHeartRate) / maxHR
        
        var zones: [String: Double] = [
            "Easy (60-70%)": 0.0,
            "Moderate (70-80%)": 0.0,
            "Hard (80-90%)": 0.0,
            "Max (90-100%)": 0.0
        ]
        
        // Distribute based on average
        if avgPercentage < 0.7 {
            zones["Easy (60-70%)"] = 100.0
        } else if avgPercentage < 0.8 {
            zones["Moderate (70-80%)"] = 100.0
        } else if avgPercentage < 0.9 {
            zones["Hard (80-90%)"] = 100.0
        } else {
            zones["Max (90-100%)"] = 100.0
        }
        
        return zones
    }
    
    /// Get summary statistics as a formatted string
    ///
    /// - Returns: Multi-line summary string
    ///
    /// Python equivalent:
    /// def get_summary_text(self) -> str:
    ///     return f"""
    ///     Duration: {self.formatted_duration}
    ///     Average HR: {self.average_heart_rate} BPM
    ///     Max HR: {self.max_heart_rate} BPM
    ///     Tracks Played: {len(self.tracks_played)}
    ///     """
    func getSummaryText() -> String {
        return """
        Duration: \(formattedDuration)
        Average HR: \(averageHeartRate) BPM
        Max HR: \(maxHeartRate) BPM
        HR Range: \(heartRateRange)
        Tracks Played: \(trackCount)
        Run Mode: \(runMode.displayName)
        Completed: \(formattedCompletionDate)
        """
    }
    
    /// Export run data as dictionary for saving/sharing
    ///
    /// - Returns: Dictionary representation of run data
    ///
    /// Python equivalent:
    /// def to_dict(self) -> Dict[str, Any]:
    ///     return {
    ///         "duration": self.duration,
    ///         "average_heart_rate": self.average_heart_rate,
    ///         "max_heart_rate": self.max_heart_rate,
    ///         "tracks_played": [t.to_dict() for t in self.tracks_played],
    ///         "run_mode": self.run_mode.value,
    ///         "completion_date": self.completion_date.isoformat()
    ///     }
    func toDictionary() -> [String: Any] {
        return [
            "duration": duration,
            "averageHeartRate": averageHeartRate,
            "maxHeartRate": maxHeartRate,
            "minHeartRate": minHeartRate,
            "trackCount": trackCount,
            "runMode": runMode.rawValue,
            "completionDate": completionDate.timeIntervalSince1970
        ]
    }
}

// ═══════════════════════════════════════════════════════════
// PREVIEW HELPER
// ═══════════════════════════════════════════════════════════
// MARK: - Preview Helper

#if DEBUG
extension RunSummaryViewModel {
    /// Create a sample view model for previews/testing
    ///
    /// Python equivalent:
    /// @classmethod
    /// def create_sample(cls) -> 'RunSummaryViewModel':
    ///     return cls(
    ///         duration=1530,  # 25:30
    ///         average_heart_rate=145,
    ///         max_heart_rate=165,
    ///         tracks_played=[...],
    ///         run_mode=RunMode.STEADY_TEMPO
    ///     )
    static var sample: RunSummaryViewModel {
        return RunSummaryViewModel(
            duration: 1530,  // 25 minutes 30 seconds
            averageHeartRate: 145,
            maxHeartRate: 165,
            minHeartRate: 120,
            tracksPlayed: [
                Track(id: "1", title: "Eye of the Tiger", artist: "Survivor", durationSeconds: 245, bpm: 109),
                Track(id: "2", title: "Stronger", artist: "Kanye West", durationSeconds: 312, bpm: 104),
                Track(id: "3", title: "Lose Yourself", artist: "Eminem", durationSeconds: 326, bpm: 171),
                Track(id: "4", title: "Can't Stop", artist: "Red Hot Chili Peppers", durationSeconds: 269, bpm: 126),
                Track(id: "5", title: "Till I Collapse", artist: "Eminem", durationSeconds: 297, bpm: 166)
            ],
            runMode: .steadyTempo,
            completionDate: Date()
        )
    }
}
#endif
