import Foundation

enum AppSecretKey: String {
    case openAIAPIKey = "OPENAI_API_KEY"
    case elevenLabsAPIKey = "ELEVENLABS_API_KEY"
}

enum AIServiceConfigurationError: LocalizedError {
    case missingValue(String)

    var errorDescription: String? {
        switch self {
        case .missingValue(let key):
            return "Missing required app secret: \(key). Configure it locally before using AI DJ features."
        }
    }
}

enum AppSecrets {
    static func value(for key: AppSecretKey) -> String? {
        if let envValue = ProcessInfo.processInfo.environment[key.rawValue]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !envValue.isEmpty {
            return envValue
        }

        if let plistValue = Bundle.main.object(forInfoDictionaryKey: key.rawValue) as? String {
            let trimmedValue = plistValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedValue.isEmpty {
                return trimmedValue
            }
        }

        return nil
    }
}
