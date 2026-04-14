import Foundation

/// Defines the current contextual state of the workout
struct DJContext {
    let runnerName: String
    let currentHeartRate: Int
    let elapsedTime: TimeInterval
    let currentSongTitle: String
    let currentSongArtist: String
    let currentSongElapsed: Int       // seconds into the current song
    let currentSongDuration: Int      // total song length in seconds
    let nextSongTitle: String?        // nil when we shouldn't mention the next song
    let nextSongArtist: String?       // nil when we shouldn't mention the next song
    let triggerReason: String         // e.g. "song_transition", "time_checkin", etc.
}

class OpenAIPromptService {
    static let shared = OpenAIPromptService()

    /// Rolling history of the last 50 DJ scripts (newest at end)
    private var dialogueHistory: [String] = []
    private let maxHistorySize = 50
    
    private init() {}
    
    /// Records a generated script into the rolling history cache
    private func recordScript(_ script: String) {
        dialogueHistory.append(script)
        if dialogueHistory.count > maxHistorySize {
            dialogueHistory.removeFirst()
        }
    }
    
    /// Requests a short AI DJ script from the authenticated PulseTempo backend.
    func generateDJScript(context: DJContext) async throws -> String {
        let request = DJScriptRequest(
            runnerName: context.runnerName,
            currentHeartRate: context.currentHeartRate,
            elapsedTimeSeconds: Int(context.elapsedTime),
            currentSongTitle: context.currentSongTitle,
            currentSongArtist: context.currentSongArtist,
            currentSongElapsedSeconds: context.currentSongElapsed,
            currentSongDurationSeconds: context.currentSongDuration,
            nextSongTitle: context.nextSongTitle,
            nextSongArtist: context.nextSongArtist,
            triggerReason: context.triggerReason,
            recentScripts: Array(dialogueHistory.suffix(10))
        )

        let response = try await APIService.shared.generateDJScript(request)
        let cleanScript = response.script.replacingOccurrences(of: "\"", with: "")
        recordScript(cleanScript)
        return cleanScript
    }
}
