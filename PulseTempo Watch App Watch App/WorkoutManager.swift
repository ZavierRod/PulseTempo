//
//  WorkoutManager.swift
//  PulseTempo Watch App
//
//  Created on 1/19/26.
//
//  Manages workout sessions and heart rate monitoring on Apple Watch.
//  Runs HKWorkoutSession directly on the watch to get real-time heart rate data.
//

import Foundation
import HealthKit
import Combine

/// Manages workout sessions and heart rate monitoring on Apple Watch
class WorkoutManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current heart rate in BPM
    @Published var heartRate: Double = 0
    
    /// Current running cadence in steps per minute (SPM)
    @Published var cadence: Double = 0
    
    /// Whether a workout is currently active
    @Published var isWorkoutActive: Bool = false
    
    /// Workout duration in seconds
    @Published var elapsedSeconds: Int = 0
    
    /// Any error that occurred
    @Published var errorMessage: String?
    
    // MARK: - HealthKit Objects
    
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    
    // MARK: - Timer
    
    private var timer: Timer?
    private var workoutStartDate: Date?
    
    // MARK: - Cadence Tracking (Rolling Window)
    
    private var lastStepCount: Double = 0
    private var lastStepTime: Date?
    
    // MARK: - Connectivity
    
    /// Reference to phone connectivity manager for sending HR data
    /// Will be set in Step 3
    var phoneConnectivityManager: PhoneConnectivityManager?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        // Don't request authorization here - it blocks the UI
        // Authorization will be requested when starting workout
    }
    
    /// Call this when the view appears to prepare HealthKit
    func prepare() {
        requestAuthorization()
    }
    
    // MARK: - Authorization
    
    /// Request HealthKit authorization for heart rate and workout data
    func requestAuthorization() {
        // Types we want to read
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .runningStrideLength)!,
            HKObjectType.workoutType()
        ]
        
        // Types we want to write
        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.workoutType()
        ]
        
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { [weak self] success, error in
            if !success {
                DispatchQueue.main.async {
                    self?.errorMessage = "HealthKit authorization failed: \(error?.localizedDescription ?? "Unknown error")"
                }
            }
        }
    }
    
    // MARK: - Workout Control
    
    /// Start a workout session
    func startWorkout() {
        // Request authorization first if needed
        requestAuthorization()
        
        // Activate connectivity
        phoneConnectivityManager?.activate()
        
        // Reset state
        errorMessage = nil
        elapsedSeconds = 0
        heartRate = 0
        cadence = 0
        lastStepCount = 0
        lastStepTime = nil
        
        // Configure workout
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor
        
        do {
            // Create workout session
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            
            // Set delegates
            workoutSession?.delegate = self
            workoutBuilder?.delegate = self
            
            // Set data source for live workout data
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            
            // Start the session
            let startDate = Date()
            workoutStartDate = startDate
            workoutSession?.startActivity(with: startDate)
            
            // Begin collecting data
            workoutBuilder?.beginCollection(withStart: startDate) { [weak self] success, error in
                DispatchQueue.main.async {
                    if success {
                        self?.isWorkoutActive = true
                        self?.startTimer()
                        self?.phoneConnectivityManager?.sendWorkoutState(isActive: true)
                        print("✅ [Watch] Workout started successfully")
                    } else {
                        self?.errorMessage = "Failed to start workout: \(error?.localizedDescription ?? "Unknown")"
                        print("❌ [Watch] Failed to start workout: \(error?.localizedDescription ?? "Unknown")")
                    }
                }
            }
        } catch {
            errorMessage = "Failed to create workout session: \(error.localizedDescription)"
            print("❌ [Watch] Failed to create workout session: \(error.localizedDescription)")
        }
    }
    
    /// Stop the workout session
    func stopWorkout() {
        guard let session = workoutSession else { return }
        
        // Stop the timer
        stopTimer()
        
        // End the session
        session.end()
        
        // End data collection
        workoutBuilder?.endCollection(withEnd: Date()) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isWorkoutActive = false
                self?.phoneConnectivityManager?.sendWorkoutState(isActive: false)
                print("✅ [Watch] Workout stopped")
            }
            
            // Optionally save the workout
            self?.workoutBuilder?.finishWorkout { workout, error in
                if let workout = workout {
                    print("✅ [Watch] Workout saved: \(workout)")
                }
            }
        }
        
        // Clear references
        workoutSession = nil
        workoutBuilder = nil
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self, let startDate = self.workoutStartDate else { return }
            DispatchQueue.main.async {
                self.elapsedSeconds = Int(Date().timeIntervalSince(startDate))
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Formatting
    
    /// Format elapsed time as MM:SS
    var elapsedTimeString: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutManager: HKWorkoutSessionDelegate {
    
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {
        print("📱 [Watch] Workout state changed: \(fromState.rawValue) → \(toState.rawValue)")
        
        DispatchQueue.main.async {
            switch toState {
            case .running:
                self.isWorkoutActive = true
            case .ended, .stopped:
                self.isWorkoutActive = false
            default:
                break
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didFailWithError error: Error) {
        print("❌ [Watch] Workout session failed: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.errorMessage = error.localizedDescription
            self.isWorkoutActive = false
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Set<HKSampleType>) {
        
        // Process heart rate data
        if let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate),
           collectedTypes.contains(heartRateType) {
            if let statistics = workoutBuilder.statistics(for: heartRateType) {
                let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
                
                if let value = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit) {
                    DispatchQueue.main.async {
                        self.heartRate = value
                        print("💓 [Watch] Heart rate: \(Int(value)) BPM")
                        
                        // Send to iPhone (will be implemented in Step 3)
                        self.phoneConnectivityManager?.sendHeartRate(value, cadence: self.cadence)
                    }
                }
            }
        }
        
        // Process step count / cadence data using rolling window for real-time cadence
        if let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount),
           collectedTypes.contains(stepCountType) {
            if let statistics = workoutBuilder.statistics(for: stepCountType) {
                let stepUnit = HKUnit.count()
                
                if let sumQuantity = statistics.sumQuantity() {
                    let currentTotalSteps = sumQuantity.doubleValue(for: stepUnit)
                    let now = Date()
                    
                    // Calculate real-time cadence from step delta
                    if let lastTime = self.lastStepTime {
                        let timeDelta = now.timeIntervalSince(lastTime)
                        let stepDelta = currentTotalSteps - self.lastStepCount
                        
                        // Only update if we have a reasonable time window (> 1 second)
                        if timeDelta > 1.0 && stepDelta >= 0 {
                            // Convert to steps per minute
                            let instantCadence = (stepDelta / timeDelta) * 60.0
                            
                            DispatchQueue.main.async {
                                // Smooth the cadence slightly to reduce jitter
                                if self.cadence == 0 {
                                    self.cadence = instantCadence
                                } else {
                                    // Weighted average: 70% new, 30% old
                                    self.cadence = (instantCadence * 0.7) + (self.cadence * 0.3)
                                }
                            }
                        }
                    }
                    
                    // Update tracking values
                    self.lastStepCount = currentTotalSteps
                    self.lastStepTime = now
                }
            }
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }
}
