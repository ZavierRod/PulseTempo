import Foundation
import Combine

class ElevenLabsService {
    static let shared = ElevenLabsService()

    // Choose a high-quality, energetic voice ID from ElevenLabs
    private let voiceId: String = "IKne3meq5aSn9XLyUdCD" // "Rachel" or any DJ-like voice ID
    
    private init() {}
    
    /// Generates speech audio data (MP3) from the provided text string using ElevenLabs
    func generateSpeech(for text: String) async throws -> Data {
        guard let apiKey = AppSecrets.value(for: .elevenLabsAPIKey) else {
            throw AIServiceConfigurationError.missingValue(AppSecretKey.elevenLabsAPIKey.rawValue)
        }

        guard let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceId)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        
        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_multilingual_v2",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpRes = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // Ensure successful generation
        if httpRes.statusCode != 200 {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown ElevenLabs Error"
            print("❌ [ElevenLabsService] API Error \(httpRes.statusCode): \(errorMsg)")
            throw URLError(.badServerResponse)
        }
        
        return data
    }
}
