//
//  HealthKitManager.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 11/4/25.
//

import Foundation  // Basic Swift types
import HealthKit   // Apple's health data framework

// ═══════════════════════════════════════════════════════════
// HEALTHKIT MANAGER
// ═══════════════════════════════════════════════════════════
// Manages HealthKit authorization and configuration
// This is a SERVICE layer - handles communication with Apple's HealthKit
//
// Python/FastAPI analogy:
// Like a service class that wraps an external API client
// Similar to how you might create a DatabaseService or ExternalAPIClient

/// Manages HealthKit authorization and configuration
class HealthKitManager {
    
    // SINGLETON PATTERN
    // "static let shared" creates a single instance shared across the app
    // Only ONE HealthKitManager exists - accessed via HealthKitManager.shared
    //
    // Python equivalent:
    // class HealthKitManager:
    //     _instance = None
    //     
    //     @classmethod
    //     def shared(cls):
    //         if cls._instance is None:
    //             cls._instance = cls()
    //         return cls._instance
    //
    // Usage: HealthKitManager.shared.requestAuthorization(...)
    static let shared = HealthKitManager()
    
    // PRIVATE PROPERTIES
    // HKHealthStore is Apple's interface to health data
    // Like a database connection or API client in Python
    private let healthStore: HKHealthStore
    private let healthDataAvailable: () -> Bool
    
    // PRIVATE INITIALIZER
    // Prevents creating instances with HealthKitManager()
    // Forces use of the singleton: HealthKitManager.shared
    //
    // Python equivalent:
    // def __init__(self):
    //     # Make constructor private (not directly possible in Python)
    //     pass
    init(healthStore: HKHealthStore = HKHealthStore(), healthDataAvailable: @escaping () -> Bool = { HKHealthStore.isHealthDataAvailable() }) {
        self.healthStore = healthStore
        self.healthDataAvailable = healthDataAvailable
    }
    
    // COMPUTED PROPERTY: isHealthKitAvailable
    // Checks if HealthKit is available on this device
    // (iPads and some older devices don't support HealthKit)
    //
    // Python equivalent:
    // @property
    // def is_health_kit_available(self) -> bool:
    //     return HKHealthStore.is_health_data_available()
    /// Check if HealthKit is available on this device
    var isHealthKitAvailable: Bool {
        return healthDataAvailable()
    }
    
    // COMPUTED PROPERTY: typesToRead
    // Specifies which health data types we want permission to read
    // Returns a Set (like Python's set) of HealthKit data types
    //
    // Python equivalent:
    // @property
    // def types_to_read(self) -> Set[HKObjectType]:
    //     heart_rate_type = HKObjectType.quantity_type(identifier="heartRate")
    //     if not heart_rate_type:
    //         return set()
    //     workout_type = HKObjectType.workout_type()
    //     return {heart_rate_type, workout_type}
    /// The types of data we want to read from HealthKit
    private var typesToRead: Set<HKObjectType> {
        // GUARD with optional binding
        // Tries to get heart rate type, returns empty set if it fails
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return []
        }
        let workoutType = HKObjectType.workoutType()
        return [heartRateType, workoutType]  // Array literal becomes Set due to return type
    }
    
    // METHOD: requestAuthorization
    // Asks user for permission to access their health data
    //
    // COMPLETION HANDLER PATTERN
    // "completion" is a callback function (like a Python callback or async/await)
    // @escaping means the closure can be called AFTER this function returns
    // (Bool, Error?) -> Void means: takes Bool and optional Error, returns nothing
    //
    // Python equivalent:
    // def request_authorization(self, completion: Callable[[bool, Optional[Exception]], None]):
    //     if not self.is_health_kit_available:
    //         completion(False, HealthKitError.NOT_AVAILABLE)
    //         return
    //     
    //     def on_auth_complete(success, error):
    //         # Run on main thread
    //         completion(success, error)
    //     
    //     self.health_store.request_authorization(to_share=None, read=self.types_to_read, 
    //                                             callback=on_auth_complete)
    /// Request authorization to access HealthKit data
    /// - Parameter completion: Called with success status and optional error
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        // Early return if HealthKit not available
        guard isHealthKitAvailable else {
            completion(false, HealthKitError.notAvailable)
            return
        }
        
        // Request permission from user
        // toShare: nil means we don't want to WRITE data
        // read: typesToRead means we want to READ heart rate and workout data
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            // DISPATCH TO MAIN THREAD
            // UI updates must happen on main thread in iOS
            // DispatchQueue.main.async is like Python's asyncio.run_in_executor for main thread
            //
            // Python equivalent:
            // asyncio.create_task(run_on_main_thread(lambda: completion(success, error)))
            DispatchQueue.main.async {
                completion(success, error)  // Call the callback on main thread
            }
        }
    }
    
    // METHOD: getAuthorizationStatus
    // Checks if user has granted permission to read heart rate data
    //
    // Python equivalent:
    // def get_authorization_status(self) -> HKAuthorizationStatus:
    //     heart_rate_type = HKObjectType.quantity_type(identifier="heartRate")
    //     if not heart_rate_type:
    //         return HKAuthorizationStatus.NOT_DETERMINED
    //     return self.health_store.authorization_status(for_type=heart_rate_type)
    /// Check the authorization status for heart rate data
    /// - Returns: The authorization status
    func getAuthorizationStatus() -> HKAuthorizationStatus {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return .notDetermined  // Return "not determined" if we can't get the type
        }
        
        return healthStore.authorizationStatus(for: heartRateType)
    }
    
    // COMPUTED PROPERTY: store
    // Provides access to the underlying HKHealthStore
    // Allows other classes to perform HealthKit queries
    //
    // Python equivalent:
    // @property
    // def store(self) -> HKHealthStore:
    //     return self._health_store
    /// Get the HealthKit store instance
    var store: HKHealthStore {
        return healthStore
    }
}

// ═══════════════════════════════════════════════════════════
// ERROR TYPES
// ═══════════════════════════════════════════════════════════
// MARK: - Errors (MARK is just a comment for code organization in Xcode)

// CUSTOM ERROR ENUM
// Defines specific error types for HealthKit operations
// LocalizedError protocol provides user-friendly error messages
//
// Python equivalent:
// class HealthKitError(Exception):
//     NOT_AVAILABLE = "not_available"
//     AUTHORIZATION_DENIED = "authorization_denied"
//     DATA_NOT_AVAILABLE = "data_not_available"
//     QUERY_FAILED = "query_failed"
//     
//     def __init__(self, error_type):
//         self.error_type = error_type
//         super().__init__(self.get_description())
//     
//     def get_description(self):
//         descriptions = {
//             "not_available": "HealthKit is not available on this device",
//             ...
//         }
//         return descriptions.get(self.error_type)
enum HealthKitError: LocalizedError, Equatable {
    // ERROR CASES (the possible error types)
    case notAvailable           // HealthKit not supported on device
    case authorizationDenied    // User denied permission
    case dataNotAvailable       // No heart rate data available
    case queryFailed            // Query to HealthKit failed
    
    // COMPUTED PROPERTY: errorDescription
    // Provides human-readable error messages
    // Required by LocalizedError protocol
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .authorizationDenied:
            return "HealthKit authorization was denied"
        case .dataNotAvailable:
            return "Heart rate data is not available"
        case .queryFailed:
            return "Failed to query heart rate data"
        }
    }
}

