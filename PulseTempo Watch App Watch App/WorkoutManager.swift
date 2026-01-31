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
    case paused                // Workout paused (time frozen, HR/cadence still live)
    case confirmingDiscard     // Showing discard confirmation
    case showingSummary        // Showing workout summary after finish
    case stopping              // Workout ending (saving to HealthKit)
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
    
    // MARK: - Summary Data (for finish screen)
    
    /// Average heart rate during workout
    @Published var averageHeartRate: Int = 0
    
    /// Average cadence during workout
    @Published var averageCadence: Int = 0
    
    // MARK: - Private Tracking for Averages
    
    private var heartRateSamples: [Double] = []
    private var cadenceSamples: [Double] = []
    
    // MARK: - Pause Tracking
    
    /// Total time paused (to subtract from elapsed time)
    private var totalPausedTime: TimeInterval = 0
    
    /// When the current pause started
    private var pauseStartTime: Date?
    
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
        
        // Listen for phone commands (workout control)
        phoneCommandObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("PhoneCommand"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let action = notification.userInfo?["action"] as? String else { return }
            
            self.handlePhoneCommand(action)
        }
    }
    
    /// Handle commands received from iPhone
    private func handlePhoneCommand(_ action: String) {
        print("📲 [Watch] Handling phone command: \(action)")
        
        switch action {
        case "startWorkout":
            // Phone confirmed our workout request
            if syncState == .waitingForPhone {
                print("✅ [Watch] Phone confirmed - starting workout!")
                startWorkout(triggeredRemotely: true)
            }
            
        case "pauseWorkout":
            // Phone requested pause
            if syncState == .active {
                pauseWorkout()
            }
            
        case "resumeWorkout":
            // Phone requested resume
            if syncState == .paused {
                resumeWorkout()
            }
            
        case "finishWorkout":
            // Phone requested finish (save workout)
            if syncState == .active || syncState == .paused {
                finishWorkout()
            }
            
        case "discardWorkout", "stopWorkout":
            // Phone requested discard (don't save)
            if syncState == .active || syncState == .paused || syncState == .confirmingDiscard {
                discardWorkout()
            }
            
        case "dismissSummary":
            // Phone dismissed summary
            if syncState == .showingSummary {
                dismissSummary(sendToPhone: false)  // Don't send back to phone
                print("🏠 [Watch] Synced summary dismiss from phone")
            }
            
        default:
            print("⚠️ [Watch] Unknown phone command: \(action)")
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
    
    /// Pause the workout session
    /// Time freezes but HR/cadence continue to update
    func pauseWorkout() {
        guard syncState == .active else { return }
        
        // Pause the HK session
        workoutSession?.pause()
        
        // Record when pause started
        pauseStartTime = Date()
        
        // Stop the timer (time frozen)
        stopTimer()
        
        syncState = .paused
        phoneConnectivityManager?.sendWorkoutState(isActive: true, isPaused: true)
        print("⏸ [Watch] Workout paused")
    }
    
    /// Resume the workout session
    func resumeWorkout() {
        guard syncState == .paused else { return }
        
        // Calculate how long we were paused and add to total
        if let pauseStart = pauseStartTime {
            totalPausedTime += Date().timeIntervalSince(pauseStart)
            pauseStartTime = nil
        }
        
        // Resume the HK session
        workoutSession?.resume()
        
        // Restart the timer
        startTimer()
        
        syncState = .active
        phoneConnectivityManager?.sendWorkoutState(isActive: true, isPaused: false)
        print("▶️ [Watch] Workout resumed")
    }
    
    /// Show discard confirmation
    func showDiscardConfirmation() {
        // If active, pause first
        if syncState == .active {
            workoutSession?.pause()
            stopTimer()
            if pauseStartTime == nil {
                pauseStartTime = Date()
            }
        }
        syncState = .confirmingDiscard
    }
    
    /// Cancel discard and return to paused state
    func cancelDiscard() {
        syncState = .paused
    }
    
    /// Finish the workout - save to HealthKit and show summary
    func finishWorkout() {
        guard let session = workoutSession else { return }
        
        // Stop the timer if still running
        stopTimer()
        
        // Calculate averages for summary
        calculateAverages()
        
        // End the HK session
        session.end()
        
        syncState = .stopping
        
        // Capture workoutBuilder before async to avoid race condition
        guard let builder = workoutBuilder else {
            // No builder, just show summary
            DispatchQueue.main.async {
                self.isWorkoutActive = false
                self.syncState = .showingSummary
                self.phoneConnectivityManager?.sendWorkoutState(isActive: false, isPaused: false)
            }
            workoutSession = nil
            return
        }
        
        // End data collection and save
        builder.endCollection(withEnd: Date()) { [weak self] success, error in
            // Save the workout to HealthKit
            builder.finishWorkout { workout, error in
                DispatchQueue.main.async {
                    self?.isWorkoutActive = false
                    self?.syncState = .showingSummary
                    // Send wasFinished: true to indicate workout was saved
                    self?.phoneConnectivityManager?.sendWorkoutState(isActive: false, isPaused: false, wasFinished: true)
                    
                    // Clear session references AFTER transitioning state
                    self?.workoutSession = nil
                    self?.workoutBuilder = nil
                    
                    if let workout = workout {
                        print("✅ [Watch] Workout finished and saved: \(workout)")
                    } else if let error = error {
                        print("⚠️ [Watch] Workout finished but save failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    /// Discard the workout - end without saving to HealthKit
    func discardWorkout() {
        guard let session = workoutSession else {
            // No session, just reset state
            resetToIdle()
            return
        }
        
        // Stop the timer
        stopTimer()
        
        // End the session without saving
        session.end()
        
        syncState = .stopping
        
        // Capture workoutBuilder before async to avoid race condition
        guard let builder = workoutBuilder else {
            // No builder, just reset
            resetToIdle()
            phoneConnectivityManager?.sendWorkoutState(isActive: false, isPaused: false)
            workoutSession = nil
            return
        }
        
        // End data collection but DON'T call finishWorkout (which saves)
        builder.endCollection(withEnd: Date()) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.resetToIdle()
                self?.phoneConnectivityManager?.sendWorkoutState(isActive: false, isPaused: false)
                
                // Clear references AFTER resetting state
                self?.workoutSession = nil
                self?.workoutBuilder = nil
                
                print("🗑 [Watch] Workout discarded (not saved)")
            }
        }
    }
    
    /// Reset to idle state and clear all data
    private func resetToIdle() {
        isWorkoutActive = false
        syncState = .idle
        elapsedSeconds = 0
        heartRate = 0
        cadence = 0
        averageHeartRate = 0
        averageCadence = 0
        heartRateSamples.removeAll()
        cadenceSamples.removeAll()
        totalPausedTime = 0
        pauseStartTime = nil
        workoutStartDate = nil
    }
    
    /// Return to idle from summary screen
    /// Dismiss summary and return to home
    /// - Parameter sendToPhone: Whether to send dismiss command to phone (default: true)
    func dismissSummary(sendToPhone: Bool = true) {
        resetToIdle()
        
        // Send to phone if requested
        if sendToPhone {
            phoneConnectivityManager?.sendDismissSummaryCommand()
        }
        
        print("🏠 [Watch] Summary dismissed")
    }
    
    /// Calculate average heart rate and cadence for summary
    private func calculateAverages() {
        if !heartRateSamples.isEmpty {
            averageHeartRate = Int(heartRateSamples.reduce(0, +) / Double(heartRateSamples.count))
        }
        if !cadenceSamples.isEmpty {
            averageCadence = Int(cadenceSamples.reduce(0, +) / Double(cadenceSamples.count))
        }
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self, let startDate = self.workoutStartDate else { return }
            DispatchQueue.main.async {
                // Subtract total paused time from elapsed time
                let totalElapsed = Date().timeIntervalSince(startDate)
                self.elapsedSeconds = Int(totalElapsed - self.totalPausedTime)
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
                        
                        // Record sample for average calculation (only when active, not paused)
                        if self.syncState == .active {
                            self.heartRateSamples.append(value)
                        }
                        
                        print("💓 [Watch] Heart rate: \(Int(value)) BPM")
                        
                        // Send to iPhone
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
                                
                                // Record sample for average calculation (only when active, not paused)
                                if self.syncState == .active && self.cadence > 0 {
                                    self.cadenceSamples.append(self.cadence)
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
