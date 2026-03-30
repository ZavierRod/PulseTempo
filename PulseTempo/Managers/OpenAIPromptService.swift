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
    
    /// Returns the most recent N scripts as a formatted string for the prompt
    private func recentScriptsContext(count: Int = 10) -> String {
        let recent = dialogueHistory.suffix(count)
        if recent.isEmpty { return "None yet — this is the first time you're speaking!" }
        return recent.enumerated().map { "\($0.offset + 1). \"\($0.element)\"" }.joined(separator: "\n")
    }
    
    /// Contacts OpenAI's extremely fast gpt-4o-mini model to generate a unique DJ script
    func generateDJScript(context: DJContext) async throws -> String {
        guard let apiKey = AppSecrets.value(for: .openAIAPIKey) else {
            throw AIServiceConfigurationError.missingValue(AppSecretKey.openAIAPIKey.rawValue)
        }

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Build the next-song instruction only for song transitions
        let nextSongInstruction: String
        if context.triggerReason == "song_transition", let nextTitle = context.nextSongTitle, let nextArtist = context.nextSongArtist {
            nextSongInstruction = "Next Song Queuing Up: \"\(nextTitle)\" by \(nextArtist). You SHOULD mention or tease this upcoming track."
        } else {
            nextSongInstruction = "Do NOT mention any upcoming or next song. Focus only on their current state and motivation."
        }
        
        let systemPrompt = """
        You are an energetic, extremely concise, highly motivating AI Radio DJ for a runner.
        You are interrupting their music mid-workout to give them a brief update.
        
        RULES:
        - Keep it strictly under 2 sentences. Max 25 words.
        - Be punchy, naturally conversational, and high-energy.
        - Do not sound like a robot.
        - Reference their current state if relevant (e.g., if their HR is too high, tell them to breathe).
        - CRITICAL: You MUST use completely different wording, sentence structures, and phrases each time. 
        - NEVER repeat or closely paraphrase any of your recent scripts listed below.
        - Vary your vocabulary, tone, and energy level. Sometimes be hype, sometimes be chill, sometimes be funny.
        - Do NOT start with the same opening word as any recent script.
        
        YOUR RECENT SCRIPTS (do NOT repeat these or say anything similar):
        \(recentScriptsContext())
        """
        
        let userPrompt = """
        Runner's Name: \(context.runnerName)
        Current Heart Rate: \(context.currentHeartRate) BPM
        Elapsed Workout Time: \(Int(context.elapsedTime / 60)) minutes
        Currently Playing: "\(context.currentSongTitle)" by \(context.currentSongArtist) (\(context.currentSongElapsed)s / \(context.currentSongDuration)s into the song)
        Trigger Reason: \(context.triggerReason)
        \(nextSongInstruction)
        
        Generate the 1-2 sentence DJ script to say to the runner right now. Use their name every once in a while to make it personal! Make it sound COMPLETELY DIFFERENT from your recent scripts above.
        """
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": 1.0,
            "max_tokens": 60
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            print("❌ [OpenAIPromptService] Failed HTTP request")
            throw URLError(.badServerResponse)
        }
        
        // Parse the JSON response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            
            // Clean up any stray quotes OpenAI might wrap the dialogue in
            let cleanScript = content.replacingOccurrences(of: "\"", with: "")
            
            // Record this script in the history cache
            recordScript(cleanScript)
            
            return cleanScript
        }
        
        throw URLError(.cannotParseResponse)
    }
}
