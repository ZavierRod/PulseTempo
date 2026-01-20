//
//  HeartRateService.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 11/4/25.
//

import Foundation  // Basic Swift types
import HealthKit   // Apple's health data framework
import Combine     // Reactive programming framework

protocol HeartRateServiceProtocol: AnyObject {
    var currentHeartRatePublisher: AnyPublisher<Int, Never> { get }
    var currentCadencePublisher: AnyPublisher<Int, Never> { get }
    var errorPublisher: AnyPublisher<Error?, Never> { get }
    func startMonitoring(device: WearableDevice, useDemoMode: Bool, completion: @escaping (Result<Void, Error>) -> Void)
    func stopMonitoring()
}

// ═══════════════════════════════════════════════════════════
// HEART RATE SERVICE
// ═══════════════════════════════════════════════════════════
// Service for monitoring heart rate data during workouts
// This is the main service that reads live heart rate from Apple Watch/HealthKit
//
// Python/FastAPI analogy:
// Like a WebSocket service or streaming API client that continuously
// receives data and updates subscribers

/// Service for monitoring heart rate data during workouts
class HeartRateService: ObservableObject, HeartRateServiceProtocol {
    
    // ═══════════════════════════════════════════════════════════
    // PUBLISHED PROPERTIES (Observable State)
    // ═══════════════════════════════════════════════════════════
    // MARK: - Published Properties
    // These automatically notify UI when they change
    
    @Published var currentHeartRate: Int = 0    // Current BPM reading
    @Published var currentCadence: Int = 0      // Current cadence (SPM) from watch
    @Published var isMonitoring: Bool = false   // Is actively monitoring?
    @Published var error: Error?                // Any error that occurred
    @Published var isDemoMode: Bool = false     // Is using simulated heart rate?
    @Published var isUsingWatchConnectivity: Bool = false  // Is using Apple Watch via WatchConnectivity?
    @Published var selectedDevice: WearableDevice = .demoMode  // Which device is providing HR data

    var currentHeartRatePublisher: AnyPublisher<Int, Never> {
        $currentHeartRate.eraseToAnyPublisher()
    }
    
    var currentCadencePublisher: AnyPublisher<Int, Never> {
        $currentCadence.eraseToAnyPublisher()
    }

    var errorPublisher: AnyPublisher<Error?, Never> {
        $error.eraseToAnyPublisher()
    }
    
    // ═══════════════════════════════════════════════════════════
    // PRIVATE PROPERTIES
    // ═══════════════════════════════════════════════════════════
    // MARK: - Private Properties
    
    // Reference to the HealthKit manager singleton
    private let healthKitManager: HealthKitManager
    
    // Reference to Watch Connectivity manager for Apple Watch data
    private let watchConnectivityManager = WatchConnectivityManager.shared
    
    // HEALTHKIT WORKOUT OBJECTS
    // These manage the workout session and data collection
    //
    // Python analogy:
    // Like database session objects or API client connections
    private var workoutSession: HKWorkoutSession?        // Manages the workout session
    private var workoutBuilder: HKLiveWorkoutBuilder?    // Collects workout data
    private var heartRateQuery: HKAnchoredObjectQuery?   // Queries for heart rate updates
    
    // COMBINE FRAMEWORK
    // Set of cancellables for reactive subscriptions
    // Like RxPy subscriptions or asyncio tasks that need cleanup
    //
    // Python equivalent:
    // self.subscriptions = []  # List of subscription objects to cancel later
    private var cancellables = Set<AnyCancellable>()
    
    // DEMO MODE PROPERTIES
    // For simulating heart rate when Apple Watch is not available
    private var demoTimer: Timer?                    // Timer for updating simulated HR
    private var demoStartTime: Date?                 // When demo workout started
    private var demoWorkoutPhase: WorkoutPhase = .warmUp  // Current phase of simulated workout
    
    // ═══════════════════════════════════════════════════════════
    // INITIALIZATION
    // ═══════════════════════════════════════════════════════════
    // MARK: - Initialization
    
    // Empty initializer (no setup needed yet)
    // Python equivalent: def __init__(self): pass
    init(healthKitManager: HealthKitManager = .shared) {
        self.healthKitManager = healthKitManager
        // Check if we should default to demo mode
        // (e.g., if HealthKit is not available)
        isDemoMode = !healthKitManager.isHealthKitAvailable
    }
    
    // ═══════════════════════════════════════════════════════════
    // PUBLIC METHODS
    // ═══════════════════════════════════════════════════════════
    // MARK: - Public Methods
    
    // METHOD: startMonitoring
    // Starts monitoring heart rate from HealthKit
    //
    // RESULT TYPE
    // Result<Void, Error> is Swift's way of handling success/failure
    // Similar to Python's Result type or returning (data, error) tuple
    //
    // Python equivalent:
    // def start_monitoring(self, completion: Callable[[Result[None, Exception]], None]):
    //     if not self.health_kit_manager.is_health_kit_available:
    //         error = HealthKitError.NOT_AVAILABLE
    //         self.error = error
    //         completion(Err(error))
    //         return
    //     ...
    /// Start monitoring heart rate
    /// - Parameter device: The wearable device to use for monitoring (default: demo mode)
    /// - Parameter completion: Called when monitoring starts or fails
    /// - Parameter useDemoMode: Force demo mode even if HealthKit is available (default: false)
    func startMonitoring(device: WearableDevice = .demoMode, useDemoMode: Bool = false, completion: @escaping (Result<Void, Error>) -> Void) {
        // Store the selected device
        self.selectedDevice = device
        
        // If demo mode is requested, use simulation
        if useDemoMode || device == .demoMode {
            startDemoMode()
            completion(.success(()))
            return
        }
        
        // If Apple Watch is selected, use WatchConnectivity
        if device == .appleWatch {
            startWatchConnectivityMode()
            completion(.success(()))
            return
        }
        
        // For other devices or if HealthKit is unavailable, fallback to demo
        if !healthKitManager.isHealthKitAvailable {
            startDemoMode()
            completion(.success(()))
            return
        }
        // CHECK 1: Is HealthKit available?
        guard healthKitManager.isHealthKitAvailable else {
            let error = HealthKitError.notAvailable
            self.error = error
            completion(.failure(error))  // .failure is like Err() in Rust/Result pattern
            return
        }
        
        // CHECK 2: Do we have authorization?
        let authStatus = healthKitManager.getAuthorizationStatus()
        guard authStatus == .sharingAuthorized else {
            let error = HealthKitError.authorizationDenied
            self.error = error
            completion(.failure(error))
            return
        }
        
        // START WORKOUT SESSION
        // [weak self] prevents memory leaks (like weak references in Python)
        // Without it, the closure would strongly reference self, creating a retain cycle
        //
        // Python equivalent:
        // def on_session_started(result):
        //     if result.is_ok():
        //         self.start_heart_rate_query()  # Note: self is weakly referenced
        //         self.is_monitoring = True
        //         completion(Ok(None))
        //     else:
        //         self.error = result.error
        //         completion(Err(result.error))
        startWorkoutSession { [weak self] result in
            // SWITCH on Result type (like match in Python 3.10+)
            switch result {
            case .success:
                self?.startHeartRateQuery()      // ? safely unwraps weak reference
                self?.isMonitoring = true
                completion(.success(()))         // .success is like Ok() in Rust/Result
            case .failure(let error):            // Extract error from failure case
                self?.error = error
                completion(.failure(error))
            }
        }
    }
    
    // METHOD: stopMonitoring
    // Stops monitoring heart rate and cleans up resources
    //
    // Python equivalent:
    // def stop_monitoring(self):
    //     self.stop_heart_rate_query()
    //     self.end_workout_session()
    //     self.is_monitoring = False
    //     self.current_heart_rate = 0
    /// Stop monitoring heart rate
    func stopMonitoring() {
        // Stop demo mode if active
        if isDemoMode {
            stopDemoMode()
        } else if isUsingWatchConnectivity {
            // Stop WatchConnectivity mode
            stopWatchConnectivityMode()
        } else {
            // Stop real HealthKit monitoring
            stopHeartRateQuery()    // Stop the query
            endWorkoutSession()     // End the workout
        }
        
        isMonitoring = false    // Update state
        currentHeartRate = 0    // Reset heart rate
        currentCadence = 0      // Reset cadence
    }
    
    // ═══════════════════════════════════════════════════════════
    // PRIVATE METHODS - Workout Session Management
    // ═══════════════════════════════════════════════════════════
    // MARK: - Private Methods - Workout Session
    
    // METHOD: startWorkoutSession
    // Creates and starts a HealthKit workout session
    // This is required to get live heart rate data from Apple Watch
    //
    // Python equivalent:
    // def _start_workout_session(self, completion: Callable[[Result[None, Exception]], None]):
    //     configuration = HKWorkoutConfiguration()
    //     configuration.activity_type = ActivityType.RUNNING
    //     configuration.location_type = LocationType.OUTDOOR
    //     
    //     try:
    //         session = HKWorkoutSession(health_store=self.health_kit_manager.store, 
    //                                    configuration=configuration)
    //         ...
    //     except Exception as e:
    //         completion(Err(e))
    private func startWorkoutSession(completion: @escaping (Result<Void, Error>) -> Void) {
        // CONFIGURE WORKOUT
        // Tell HealthKit what kind of workout this is
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running     // Running workout
        configuration.locationType = .outdoor     // Outdoor (uses GPS)
        
        // TRY-CATCH (Error Handling)
        // "do-catch" is like Python's try-except
        do {
            // CREATE WORKOUT SESSION
            // This can throw an error, hence the "try" keyword
            let session = try HKWorkoutSession(healthStore: healthKitManager.store, 
                                               configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            
            // SET DATA SOURCE
            // Tells the builder to collect live data during the workout
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthKitManager.store,
                workoutConfiguration: configuration
            )
            
            // STORE REFERENCES
            self.workoutSession = session
            self.workoutBuilder = builder
            
            // START THE SESSION
            session.startActivity(with: Date())  // Start now
            
            // BEGIN DATA COLLECTION
            // Asynchronous call with completion handler
            builder.beginCollection(withStart: Date()) { success, error in
                if success {
                    completion(.success(()))
                } else {
                    // ?? provides default error if error is nil
                    completion(.failure(error ?? HealthKitError.queryFailed))
                }
            }
        } catch {
            // CATCH BLOCK (like Python's except)
            // "error" is automatically available in catch block
            completion(.failure(error))
        }
    }
    
    // METHOD: endWorkoutSession
    // Stops and cleans up the workout session
    //
    // Python equivalent:
    // def _end_workout_session(self):
    //     if not self.workout_session or not self.workout_builder:
    //         return
    //     
    //     self.workout_session.end()
    //     self.workout_builder.end_collection(end_date=datetime.now(), 
    //                                         callback=lambda: self.workout_builder.finish_workout())
    //     
    //     self.workout_session = None
    //     self.workout_builder = None
    private func endWorkoutSession() {
        // GUARD - early return if sessions don't exist
        guard let session = workoutSession, let builder = workoutBuilder else {
            return
        }
        
        // END THE SESSION
        session.end()
        
        // END DATA COLLECTION
        builder.endCollection(withEnd: Date()) { _, _ in
            // SAVE THE WORKOUT (Optional)
            // This saves the workout to HealthKit for history
            // The _ ignores parameters we don't need
            builder.finishWorkout { _, _ in
                // Workout saved successfully
            }
        }
        
        // CLEANUP - set to nil to release memory
        workoutSession = nil
        workoutBuilder = nil
    }
    
    // ═══════════════════════════════════════════════════════════
    // PRIVATE METHODS - Heart Rate Query
    // ═══════════════════════════════════════════════════════════
    // MARK: - Private Methods - Heart Rate Query
    
    // METHOD: startHeartRateQuery
    // Sets up a continuous query for heart rate updates
    // This is like subscribing to a WebSocket or event stream
    //
    // Python equivalent:
    // async def _start_heart_rate_query(self):
    //     heart_rate_type = HKObjectType.quantity_type(identifier="heartRate")
    //     if not heart_rate_type:
    //         self.error = HealthKitError.DATA_NOT_AVAILABLE
    //         return
    //     
    //     # Create a query that runs continuously
    //     query = HKAnchoredObjectQuery(
    //         type=heart_rate_type,
    //         predicate=...,
    //         initial_handler=self._process_heart_rate_samples,
    //         update_handler=self._process_heart_rate_samples
    //     )
    //     self.health_kit_manager.store.execute(query)
    private func startHeartRateQuery() {
        // GET HEART RATE TYPE
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            self.error = HealthKitError.dataNotAvailable
            return
        }
        
        // CREATE PREDICATE (Filter)
        // Only get samples from now onwards (not historical data)
        // Like SQL WHERE clause or Python filter condition
        let predicate = HKQuery.predicateForSamples(
            withStart: Date(),              // Start from now
            end: nil,                       // No end date (continuous)
            options: .strictStartDate       // Only samples after start date
        )
        
        // CREATE ANCHORED QUERY
        // HKAnchoredObjectQuery continuously monitors for new data
        // Like a database cursor or streaming query
        //
        // Parameters:
        // - type: what data to query (heart rate)
        // - predicate: filter conditions
        // - anchor: nil means start fresh (no previous query state)
        // - limit: HKObjectQueryNoLimit means get all matching samples
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, error in
            // INITIAL RESULTS HANDLER
            // Called once with existing data when query starts
            self?.processHeartRateSamples(samples, error: error)
        }
        
        // UPDATE HANDLER
        // Called whenever NEW heart rate data arrives
        // This is the "streaming" part - gets called repeatedly
        //
        // Python equivalent:
        // async for new_samples in heart_rate_stream:
        //     self._process_heart_rate_samples(new_samples)
        query.updateHandler = { [weak self] _, samples, _, _, error in
            self?.processHeartRateSamples(samples, error: error)
        }
        
        // EXECUTE THE QUERY
        heartRateQuery = query
        healthKitManager.store.execute(query)  // Start listening for updates
    }
    
    // METHOD: stopHeartRateQuery
    // Stops the continuous heart rate query
    //
    // Python equivalent:
    // def _stop_heart_rate_query(self):
    //     if self.heart_rate_query:
    //         self.health_kit_manager.store.stop(self.heart_rate_query)
    //         self.heart_rate_query = None
    private func stopHeartRateQuery() {
        if let query = heartRateQuery {
            healthKitManager.store.stop(query)  // Stop the query
            heartRateQuery = nil                // Clear reference
        }
    }
    
    // METHOD: processHeartRateSamples
    // Processes new heart rate data from HealthKit
    // Extracts the BPM value and updates the published property
    //
    // Python equivalent:
    // def _process_heart_rate_samples(self, samples: Optional[List[HKSample]], error: Optional[Exception]):
    //     if error:
    //         # Update on main thread
    //         asyncio.create_task(self._update_error_on_main_thread(error))
    //         return
    //     
    //     if not samples or not isinstance(samples, list):
    //         return
    //     
    //     heart_rate_samples = [s for s in samples if isinstance(s, HKQuantitySample)]
    //     if not heart_rate_samples:
    //         return
    //     
    //     latest_sample = heart_rate_samples[-1]
    //     heart_rate_unit = HKUnit.count().unit_divided_by(HKUnit.minute())
    //     heart_rate = int(latest_sample.quantity.double_value(for_unit=heart_rate_unit))
    //     
    //     # Update on main thread
    //     asyncio.create_task(self._update_heart_rate_on_main_thread(heart_rate))
    private func processHeartRateSamples(_ samples: [HKSample]?, error: Error?) {
        // CHECK FOR ERRORS
        guard error == nil else {
            // Update error on main thread (UI updates must be on main thread)
            DispatchQueue.main.async {
                self.error = error
            }
            return
        }
        
        // CAST AND EXTRACT SAMPLES
        // "as?" is a safe cast (returns nil if cast fails)
        // Like Python's isinstance() check
        //
        // Multiple conditions in guard with comma (all must be true)
        guard let heartRateSamples = samples as? [HKQuantitySample],
              let latestSample = heartRateSamples.last else {
            return
        }
        
        // EXTRACT BPM VALUE
        // Define the unit: count per minute (BPM)
        let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
        // Get the value in that unit
        let heartRate = latestSample.quantity.doubleValue(for: heartRateUnit)
        
        // UPDATE UI ON MAIN THREAD
        // All UI updates MUST happen on the main thread in iOS
        DispatchQueue.main.async {
            self.currentHeartRate = Int(heartRate)  // Convert to Int and update
            // This triggers UI update because currentHeartRate is @Published
        }
    }
    
    // ═══════════════════════════════════════════════════════════
    // DEMO MODE - Simulated Heart Rate
    // ═══════════════════════════════════════════════════════════
    // MARK: - Demo Mode
    
    /// Start demo mode with simulated heart rate
    /// Simulates a realistic workout with varying heart rate patterns
    ///
    /// Python equivalent:
    /// def start_demo_mode(self):
    ///     self.is_demo_mode = True
    ///     self.demo_start_time = datetime.now()
    ///     self.demo_workout_phase = WorkoutPhase.WARM_UP
    ///     self.is_monitoring = True
    ///     
    ///     # Start timer to update HR every 2 seconds
    ///     self.demo_timer = Timer.schedule_repeating(
    ///         interval=2.0,
    ///         callback=self._update_demo_heart_rate
    ///     )
    private func startDemoMode() {
        isDemoMode = true
        demoStartTime = Date()
        demoWorkoutPhase = .warmUp
        isMonitoring = true
        
        print("🚀 Starting demo mode heart rate simulation...")
        
        // Start timer to update heart rate every 2 seconds
        demoTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateDemoHeartRate()
        }
        
        // Set initial resting heart rate
        currentHeartRate = 65
        print("💓 Initial HR set to: \(currentHeartRate) BPM")
    }
    
    /// Stop demo mode and clean up
    private func stopDemoMode() {
        demoTimer?.invalidate()
        demoTimer = nil
        demoStartTime = nil
        isDemoMode = false
        demoWorkoutPhase = .warmUp
    }
    
    // ═══════════════════════════════════════════════════════════
    // WATCH CONNECTIVITY MODE - Real Apple Watch Data
    // ═══════════════════════════════════════════════════════════
    // MARK: - Watch Connectivity Mode
    
    /// Start receiving heart rate and cadence from Apple Watch via WatchConnectivity
    /// The watch app must be running a workout for data to flow
    private func startWatchConnectivityMode() {
        isUsingWatchConnectivity = true
        isMonitoring = true
        
        print("⌚ Starting WatchConnectivity mode - listening for Apple Watch data...")
        
        // Subscribe to heart rate updates from watch
        watchConnectivityManager.$heartRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] heartRate in
                guard let self = self, self.isUsingWatchConnectivity else { return }
                if heartRate > 0 {
                    self.currentHeartRate = Int(heartRate)
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to cadence updates from watch
        watchConnectivityManager.$cadence
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cadence in
                guard let self = self, self.isUsingWatchConnectivity else { return }
                self.currentCadence = Int(cadence)
            }
            .store(in: &cancellables)
        
        // Subscribe to workout state changes
        watchConnectivityManager.$isWatchWorkoutActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isActive in
                guard let self = self else { return }
                if !isActive && self.isUsingWatchConnectivity {
                    // Watch workout ended - reset values
                    self.currentHeartRate = 0
                    self.currentCadence = 0
                }
            }
            .store(in: &cancellables)
    }
    
    /// Stop WatchConnectivity mode and clean up subscriptions
    private func stopWatchConnectivityMode() {
        isUsingWatchConnectivity = false
        // Cancellables will be cleaned up, stopping the subscriptions
        cancellables.removeAll()
    }
    
    /// Update simulated heart rate based on workout phase
    /// Creates realistic heart rate patterns for different workout phases
    ///
    /// Python equivalent:
    /// def _update_demo_heart_rate(self):
    ///     elapsed = (datetime.now() - self.demo_start_time).total_seconds()
    ///     
    ///     # Determine workout phase based on elapsed time
    ///     if elapsed < 180:  # First 3 minutes
    ///         self.demo_workout_phase = WorkoutPhase.WARM_UP
    ///         base_hr = 100 + (elapsed / 180) * 30  # 100 -> 130
    ///     elif elapsed < 600:  # Next 7 minutes
    ///         self.demo_workout_phase = WorkoutPhase.STEADY
    ///         base_hr = 145 + random.randint(-5, 5)
    ///     # ... etc
    ///     
    ///     self.current_heart_rate = int(base_hr)
    func updateDemoHeartRate(elapsedOverride: TimeInterval? = nil) {
        if demoStartTime == nil && elapsedOverride != nil {
            demoStartTime = Date()
        }

        guard let startTime = demoStartTime else { return }

        // Calculate elapsed time in seconds
        let elapsed = elapsedOverride ?? Date().timeIntervalSince(startTime)
        
        // Determine workout phase and calculate heart rate
        // Designed for realistic manual testing: resting -> gradual build -> high intensity
        let baseHeartRate: Double
        
        switch elapsed {
        case 0..<30:  // 0-30 seconds: Resting/Starting
            demoWorkoutPhase = .warmUp
            // Stay around resting heart rate 62-68 BPM
            baseHeartRate = 65
            
        case 30..<90:  // 30s-1.5min: Beginning to move
            demoWorkoutPhase = .warmUp
            // Slowly increase from 65 to 85 BPM (like starting to walk/jog)
            let progress = (elapsed - 30) / 60
            baseHeartRate = 65 + (progress * 20)
            
        case 90..<180:  // 1.5-3 minutes: Light warm-up
            demoWorkoutPhase = .warmUp
            // Increase from 85 to 105 BPM
            let progress = (elapsed - 90) / 90
            baseHeartRate = 85 + (progress * 20)
            
        case 180..<300:  // 3-5 minutes: Building intensity
            demoWorkoutPhase = .steady
            // Increase from 105 to 125 BPM
            let progress = (elapsed - 180) / 120
            baseHeartRate = 105 + (progress * 20)
            
        case 300..<480:  // 5-8 minutes: Moderate effort
            demoWorkoutPhase = .steady
            // Increase from 125 to 140 BPM with some natural oscillation
            let progress = (elapsed - 300) / 180
            let oscillation = sin(elapsed / 20) * 3  // Natural breathing rhythm
            baseHeartRate = 125 + (progress * 15) + oscillation
            
        case 480..<600:  // 8-10 minutes: Pushing harder
            demoWorkoutPhase = .intense
            // Increase from 140 to 150 BPM
            let progress = (elapsed - 480) / 120
            let oscillation = sin(elapsed / 15) * 4
            baseHeartRate = 140 + (progress * 10) + oscillation
            
        case 600..<720:  // 10-12 minutes: High intensity
            demoWorkoutPhase = .intense
            // Peak around 150-160 BPM with natural variation
            let oscillation = sin(elapsed / 12) * 5
            baseHeartRate = 155 + oscillation
            
        case 720..<840:  // 12-14 minutes: Slight recovery
            demoWorkoutPhase = .recovery
            // Drop to 140-145 BPM (active recovery)
            let progress = (elapsed - 720) / 120
            baseHeartRate = 155 - (progress * 12)
            
        case 840..<960:  // 14-16 minutes: Push again
            demoWorkoutPhase = .intense
            // Back up to 150-155 BPM
            let progress = (elapsed - 840) / 120
            let oscillation = sin(elapsed / 10) * 4
            baseHeartRate = 143 + (progress * 12) + oscillation
            
        default:  // 16+ minutes: Maintain high intensity
            demoWorkoutPhase = .intense
            // Oscillate around 150 BPM
            let oscillation = sin(elapsed / 15) * 6
            baseHeartRate = 150 + oscillation
        }
        
        // Add natural micro-variations (like real heart rate)
        // Combines:
        // 1. Small random noise (±2 BPM)
        // 2. Occasional slightly larger jumps (simulates effort changes)
        let noise = Double.random(in: -2...2)
        let occasionalJump = Double.random(in: 0...1) < 0.1 ? Double.random(in: -4...4) : 0
        let finalHeartRate = Int(baseHeartRate + noise + occasionalJump)
        
        // Update on main thread
        DispatchQueue.main.async {
            self.currentHeartRate = max(55, min(180, finalHeartRate))  // Clamp to realistic range
            print("💓 Demo HR: \(self.currentHeartRate) BPM (elapsed: \(Int(elapsed))s, phase: \(self.demoWorkoutPhase))")
        }
    }

    /// Exposes the current demo workout phase for testing
    var currentDemoPhase: WorkoutPhase {
        demoWorkoutPhase
    }
    
    /// Manually set heart rate in demo mode
    /// Useful for testing specific BPM ranges
    ///
    /// - Parameter bpm: Target heart rate in beats per minute
    func setDemoHeartRate(_ bpm: Int) {
        guard isDemoMode else { return }
        currentHeartRate = max(60, min(200, bpm))  // Clamp to realistic range
    }
    
    // MARK: - Deinitialization
    
    /// Clean up resources when service is deallocated
    /// Ensures timers and queries are properly stopped to prevent memory issues
    deinit {
        stopMonitoring()
    }
}

// ═══════════════════════════════════════════════════════════
// WORKOUT PHASE ENUM
// ═══════════════════════════════════════════════════════════

/// Represents different phases of a workout for demo mode simulation
///
/// Python equivalent:
/// class WorkoutPhase(Enum):
///     WARM_UP = "warm_up"
///     STEADY = "steady"
///     INTENSE = "intense"
///     RECOVERY = "recovery"
///     COOL_DOWN = "cool_down"
enum WorkoutPhase {
    case warmUp      // Gradual increase in HR
    case steady      // Maintaining consistent HR
    case intense     // High intensity interval
    case recovery    // Active recovery
    case coolDown    // Gradual decrease in HR
    
    var displayName: String {
        switch self {
        case .warmUp: return "Warm Up"
        case .steady: return "Steady State"
        case .intense: return "Intense"
        case .recovery: return "Recovery"
        case .coolDown: return "Cool Down"
        }
    }
}

// ═══════════════════════════════════════════════════════════
// DEBUG/TESTING HELPERS
// ═══════════════════════════════════════════════════════════
// MARK: - Preview Helper

// CONDITIONAL COMPILATION
// #if DEBUG means this code only exists in debug builds (not production)
// Like Python's if __debug__: or environment-based feature flags
//
// Python equivalent:
// if __debug__:
//     class HeartRateServiceDebugExtension:
//         def simulate_heart_rate(self, bpm: int):
//             self.current_heart_rate = bpm
//             self.is_monitoring = True
#if DEBUG
// EXTENSION
// Extensions add functionality to existing types
// Like Python's monkey patching or mixins
//
// This adds a test method to HeartRateService only in debug builds
extension HeartRateService {
    /// Simulate heart rate for preview/testing purposes
    /// Allows testing the UI without real HealthKit data
    ///
    /// Python equivalent:
    /// def simulate_heart_rate(self, bpm: int):
    ///     """For testing only - simulates heart rate without HealthKit"""
    ///     self.current_heart_rate = bpm
    ///     self.is_monitoring = True
    func simulateHeartRate(bpm: Int) {
        currentHeartRate = bpm      // Set fake heart rate
        isMonitoring = true         // Mark as monitoring
    }
}
#endif
