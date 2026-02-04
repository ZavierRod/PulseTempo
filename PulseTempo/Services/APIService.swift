//
//  APIService.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 1/28/26.
//

import Foundation

// ═══════════════════════════════════════════════════════════
// API SERVICE
// ═══════════════════════════════════════════════════════════
// Centralized HTTP client for authenticated API requests
// Automatically injects auth tokens and handles token refresh
//
// Python/FastAPI analogy:
// Like a requests.Session configured with authentication
// Similar to httpx.Client with auth headers pre-configured

/// Errors that can occur during API requests
enum APIError: LocalizedError {
    case notAuthenticated
    case networkError(String)
    case serverError(Int, String)
    case decodingError(String)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You are not logged in"
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .decodingError(let message):
            return "Failed to parse response: \(message)"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

/// Run data structure for API requests
struct RunCreateRequest: Codable {
    let startTime: Date
    let endTime: Date
    let avgHeartRate: Int?
    let avgCadence: Int?
    let totalDistance: Float?
    
    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case avgHeartRate = "avg_heart_rate"
        case avgCadence = "avg_cadence"
        case totalDistance = "total_distance"
    }
}

/// Run data structure from API responses
struct RunResponse: Codable, Identifiable {
    let id: String
    let startTime: Date
    let endTime: Date
    let avgHeartRate: Int?
    let avgCadence: Int?
    let totalDistance: Float?
    
    enum CodingKeys: String, CodingKey {
        case id
        case startTime = "start_time"
        case endTime = "end_time"
        case avgHeartRate = "avg_heart_rate"
        case avgCadence = "avg_cadence"
        case totalDistance = "total_distance"
    }
    
    /// Duration in seconds
    var durationSeconds: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
    
    /// Duration in minutes
    var durationMinutes: Int {
        return Int(durationSeconds / 60)
    }
}

/// Centralized API client for authenticated requests
class APIService {
    
    // SINGLETON PATTERN
    static let shared = APIService()
    
    // MARK: - Private Properties
    
    private let keychainManager = KeychainManager.shared
    
    // Backend URL - Railway production server
    private let baseURL: String = "https://pulsetempo-production.up.railway.app"
    
    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    private init() {}
    
    // MARK: - Run History API
    
    /// Save a completed run to the backend
    /// - Parameters:
    ///   - startTime: When the run started
    ///   - endTime: When the run ended
    ///   - avgHeartRate: Average heart rate during run
    ///   - avgCadence: Average cadence during run
    ///   - totalDistance: Total distance in meters (optional)
    func saveRun(
        startTime: Date,
        endTime: Date,
        avgHeartRate: Int?,
        avgCadence: Int?,
        totalDistance: Float? = nil
    ) async throws -> RunResponse {
        let runData = RunCreateRequest(
            startTime: startTime,
            endTime: endTime,
            avgHeartRate: avgHeartRate,
            avgCadence: avgCadence,
            totalDistance: totalDistance
        )
        
        let data = try jsonEncoder.encode(runData)
        let response: RunResponse = try await post(endpoint: "/api/runs/", body: data)
        
        print("✅ [API] Run saved successfully (ID: \(response.id))")
        return response
    }
    
    /// Fetch run history for the current user
    /// - Parameters:
    ///   - skip: Number of runs to skip (for pagination)
    ///   - limit: Maximum number of runs to return
    func fetchRunHistory(skip: Int = 0, limit: Int = 100) async throws -> [RunResponse] {
        let runs: [RunResponse] = try await get(endpoint: "/api/runs/?skip=\(skip)&limit=\(limit)")
        print("📊 [API] Fetched \(runs.count) runs")
        return runs
    }
    
    // MARK: - Generic HTTP Methods
    
    /// Perform a GET request with authentication
    private func get<T: Decodable>(endpoint: String) async throws -> T {
        guard let token = keychainManager.getAccessToken() else {
            throw APIError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        return try await performRequest(request)
    }
    
    /// Perform a POST request with authentication
    private func post<T: Decodable>(endpoint: String, body: Data) async throws -> T {
        guard let token = keychainManager.getAccessToken() else {
            throw APIError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        
        return try await performRequest(request)
    }
    
    /// Perform the actual network request and handle response
    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError("Invalid response")
            }
            
            switch httpResponse.statusCode {
            case 200..<300:
                do {
                    let decoded = try jsonDecoder.decode(T.self, from: data)
                    return decoded
                } catch {
                    let responseBody = String(data: data, encoding: .utf8) ?? "Unknown"
                    print("⚠️ [API] Decoding error: \(error), Response: \(responseBody)")
                    throw APIError.decodingError(error.localizedDescription)
                }
                
            case 401:
                // Token expired - could implement refresh here
                throw APIError.notAuthenticated
                
            default:
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw APIError.serverError(httpResponse.statusCode, errorBody)
            }
            
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }
    }
}
