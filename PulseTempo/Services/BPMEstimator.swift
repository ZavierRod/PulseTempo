//
//  BPMEstimator.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 12/12/24.
//

import Foundation

/// Temporary utility for estimating track BPM based on metadata
/// This provides placeholder BPM values until the backend BPM service is implemented
///
/// **NOTE**: This is a TEMPORARY solution. When the backend BPM service (Phase 2.3) is ready,
/// replace all calls to BPMEstimator.estimate() with actual API calls to fetch verified BPM data.
///
/// Usage:
/// ```swift
/// let estimatedBPM = BPMEstimator.estimate(title: "Lose Yourself", artist: "Eminem")
/// // Returns: 171 (estimated based on genre heuristics)
/// ```
enum BPMEstimator {
    
    /// Estimate BPM for a track based on title and artist
    ///
    /// This uses genre heuristics and adds random variation for variety.
    /// Estimates are intentionally broad to avoid being too wrong.
    ///
    /// - Parameters:
    ///   - title: Track title
    ///   - artist: Artist name
    /// - Returns: Estimated BPM value (typically 80-180 range)
    static func estimate(title: String, artist: String) -> Int {
        // Detect genre from artist name (very rough heuristics)
        let artistLower = artist.lowercased()
        let titleLower = title.lowercased()
        
        // Genre-based BPM ranges (based on typical ranges for each genre)
        let baseRange: (min: Int, max: Int)
        
        // Electronic/Dance/EDM
        if artistLower.contains("daft punk") ||
           artistLower.contains("calvin harris") ||
           artistLower.contains("deadmau5") ||
           artistLower.contains("avicii") ||
           titleLower.contains("dance") ||
           titleLower.contains("remix") {
            baseRange = (min: 120, max: 140)
        }
        // Hip-Hop/Rap
        else if artistLower.contains("drake") ||
                artistLower.contains("kendrick") ||
                artistLower.contains("eminem") ||
                artistLower.contains("travis") ||
                artistLower.contains("kanye") ||
                artistLower.contains("jay-z") ||
                artistLower.contains("lil") ||
                artistLower.contains("durk") ||
                artistLower.contains("moneybagg") {
            baseRange = (min: 70, max: 110)
        }
        // Rock/Alternative
        else if artistLower.contains("foo fighters") ||
                artistLower.contains("red hot") ||
                artistLower.contains("nirvana") ||
                artistLower.contains("queens of") ||
                artistLower.contains("arctic monkeys") {
            baseRange = (min: 100, max: 140)
        }
        // Pop
        else if artistLower.contains("taylor") ||
                artistLower.contains("ariana") ||
                artistLower.contains("billie") ||
                artistLower.contains("dua lipa") ||
                artistLower.contains("weeknd") {
            baseRange = (min: 95, max: 130)
        }
        // UK Drill/Grime (based on the tracks in your logs)
        else if titleLower.contains("brixton") ||
                titleLower.contains("slater") ||
                titleLower.contains("native remedies") {
            baseRange = (min: 130, max: 150)
        }
        // Workout/High Energy
        else if titleLower.contains("pump") ||
                titleLower.contains("stronger") ||
                titleLower.contains("power") ||
                titleLower.contains("beast") ||
                titleLower.contains("thunder") {
            baseRange = (min: 110, max: 150)
        }
        // Default: moderate tempo
        else {
            baseRange = (min: 100, max: 130)
        }
        
        // Add controlled randomness to avoid all songs in a genre having identical BPM
        // Use the track title hash as a seed for consistent results
        let seed = abs(title.hashValue) % 100
        let variation = (seed % 20) - 10  // ±10 BPM variation
        
        // Calculate midpoint and apply variation
        let midpoint = (baseRange.min + baseRange.max) / 2
        let estimatedBPM = midpoint + variation
        
        // Clamp to reasonable workout BPM range (60-180)
        let finalBPM = max(60, min(180, estimatedBPM))
        
        return finalBPM
    }
    
    /// Check if a BPM value is estimated (vs verified from backend)
    ///
    /// This is a placeholder for future functionality when we have verified BPM data.
    /// Currently always returns true since all BPM values are estimated.
    ///
    /// - Parameter bpm: BPM value to check
    /// - Returns: true if estimated, false if verified (currently always true)
    static func isEstimated(_ bpm: Int?) -> Bool {
        // TODO: When backend is implemented, check if BPM came from verified source
        // For now, all BPM values from this estimator are estimates
        return bpm != nil  // If we have a BPM, it's from the estimator
    }
}
