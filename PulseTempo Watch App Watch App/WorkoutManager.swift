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

/// Workout state for bidirectional sync
enum WorkoutSyncState {
    case idle                  // Ready to start
    case waitingForPhone       // Watch initiated, waiting for phone to confirm
    case pendingPhoneRequest   // Phone requested workout, waiting for user to confirm on watch
    case active                // Workout running
    case stopping              // Workout ending
}

/// Manages workout sessions and heart rate monitoring on Apple Watch
class WorkoutManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current heart rate in BPM
    @Published var heartRate: Double = 0
    
    /// Current running cadence in steps per minute (SPM)
    @Published var cadence: Double = 0
    
    /// Whether a workout is currently active
    @Published var isWorkoutActive: Bool = false
    
    /// Current sync state for bidirectional workout sync
    @Published var syncState: WorkoutSyncState = .idle
    
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
    
    // MARK: - Notification Observers
    
    private var phoneWorkoutRequestObserver: NSObjectProtocol?
    private var phoneCommandObserver: NSObjectProtocol?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        // Don't request authorization here - it blocks the UI
        // Authorization will be requested when starting workout
        
        // Listen for workout requests from iPhone
        setupNotificationObservers()
    }
    
    deinit {
        if let observer = phoneWorkoutRequestObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = phoneCommandObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    /// Setup notification observers for phone commands
    private func setupNotificationObservers() {
        // Listen for phone-initiated workout requests (phone-first flow)
        // NOTE: We do NOT auto-start - we show a pending state and wait for user confirmation
        phoneWorkoutRequestObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("PhoneWorkoutRequest"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            // Only accept if idle - set to pending state
            guard self.syncState == .idle else {
                print("⚠️ [Watch] Ignoring phone request - already in state: \(self.syncState)")
                return
            }
            
            // Set pending state - user must tap Start on watch to confirm
            print("📲 [Watch] Phone requested workout - waiting for user confirmation")
            self.syncState = .pendingPhoneRequest
        }
        
        // Listen for phone commands (watch-first flow: phone confirms our request)
        phoneCommandObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("PhoneCommand"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let action = notification.userInfo?["action"] as? String else { return }
            
            if action == "startWorkout" && self.syncState == .waitingForPhone {
                print("✅ [Watch] Phone confirmed - starting workout!")
                self.startWorkout(triggeredRemotely: true)
            }
        }
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
    
    /// Request workout start - enters waiting state if phone not reachable
    func requestWorkoutStart() {
        // Check if phone already requested workout (phone-first flow)
        if phoneConnectivityManager?.hasPendingPhoneWorkoutRequest() == true {
            print("✅ [Watch] Phone already requested - starting immediately")
            startWorkout(triggeredRemotely: true)
            return
        }
        
        // Watch-first flow: Check if phone is reachable
        if phoneConnectivityManager?.isPhoneReachable == true {
            // Phone is reachable - send request and wait for confirmation
            syncState = .waitingForPhone
            phoneConnectivityManager?.sendWorkoutRequest()
            print("⏳ [Watch] Waiting for phone to start workout...")
        } else {
            // Phone not reachable - show waiting state with instruction
            syncState = .waitingForPhone
            phoneConnectivityManager?.sendWorkoutRequestWithContext()
            print("⏳ [Watch] Phone not reachable, sent context. Waiting...")
        }
    }
    
    /// Cancel waiting state and return to idle
    func cancelWaiting() {
        syncState = .idle
        phoneConnectivityManager?.clearPendingWorkoutContext()
        print("❌ [Watch] Workout request cancelled")
    }
    
    /// Accept pending phone request and start workout
    /// Called when user taps Start after phone requested workout
    func acceptPhoneRequest() {
        guard syncState == .pendingPhoneRequest else {
            print("⚠️ [Watch] Cannot accept - not in pendingPhoneRequest state")
            return
        }
        
        print("✅ [Watch] User accepted phone request - starting workout")
        startWorkout(triggeredRemotely: true)
    }
    
    /// Decline pending phone request
    func declinePhoneRequest() {
        guard syncState == .pendingPhoneRequest else { return }
        
        syncState = .idle
        phoneConnectivityManager?.clearPendingWorkoutContext()
        print("❌ [Watch] User declined phone workout request")
    }
    
    /// Start a workout session (called directly or after phone confirms)
    func startWorkout(triggeredRemotely: Bool = false) {
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
                        self?.syncState = .active
                        self?.startTimer()
                        // ALWAYS send workout state to phone - this is crucial for sync
                        // Phone needs to know workout started (especially if phone initiated)
                        self?.phoneConnectivityManager?.sendWorkoutState(isActive: true)
                        print("✅ [Watch] Workout started successfully (remote: \(triggeredRemotely))")
                    } else {
                        self?.syncState = .idle
                        self?.errorMessage = "Failed to start workout: \(error?.localizedDescription ?? "Unknown")"
                        print("❌ [Watch] Failed to start workout: \(error?.localizedDescription ?? "Unknown")")
                    }
                }
            }
        } catch {
            syncState = .idle
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
        
        syncState = .stopping
        
        // End data collection
        workoutBuilder?.endCollection(withEnd: Date()) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isWorkoutActive = false
                self?.syncState = .idle
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
