//
//  ContentView.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 11/4/25.
//

import SwiftUI  // Apple's declarative UI framework

// VIEW STRUCT: ActiveRunView
// This is a SwiftUI View - the UI component that displays the running screen
// "View" protocol means it must have a "body" property that returns UI
//
// Python/FastAPI analogy:
// Think of this like a Jinja2 template or a React component
// It describes WHAT to show, and SwiftUI figures out HOW to render it
//
// Key difference from imperative UI (like UIKit):
// - Declarative: You describe the desired state, framework handles updates
// - Imperative: You manually update UI elements (like button.setText("Play"))
struct ActiveRunView: View {
    
    // ENVIRONMENT
    // @Environment allows access to system-wide values
    // dismiss is used to close/pop the current view
    @Environment(\.dismiss) private var dismiss
    
    // STATE MANAGEMENT
    // @StateObject is used for ObservableObject classes that the View owns
    // When any @Published property changes, SwiftUI automatically re-renders
    @StateObject private var runSessionVM: RunSessionViewModel
    
    // HEART BEAT ANIMATION STATE
    // These control the heart icon pulsing at your actual heart rate
    @State private var heartBeat = false           // Toggles to trigger animation
    @State private var beatTimer: Timer? = nil     // Timer that fires at heart rate interval
    
    /// The workout mode for this session
    private let runMode: RunMode
    
    // INITIALIZER
    // Create the ViewModel with tracks and run mode when the view is created
    init(tracks: [Track], runMode: RunMode = .steadyTempo) {
        self.runMode = runMode
        // _runSessionVM accesses the underlying StateObject wrapper
        _runSessionVM = StateObject(wrappedValue: RunSessionViewModel(tracks: tracks, runMode: runMode))
    }
    
    // COMPUTED PROPERTIES
    
    /// Calculate song progress as a value from 0.0 to 1.0
    private var songProgress: Double {
        guard let track = runSessionVM.currentTrack,
              track.durationSeconds > 0 else {
            return 0.0
        }
        let progress = runSessionVM.currentPlaybackTime / Double(track.durationSeconds)
        return min(max(progress, 0.0), 1.0)  // Clamp between 0 and 1
    }
    
    /// Format time interval as "M:SS" string
    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return "\(minutes):\(String(format: "%02d", secs))"
    }
    
    // ═══════════════════════════════════════════════════════════
    // HEART BEAT TIMER FUNCTIONS
    // ═══════════════════════════════════════════════════════════
    
    /// Start a timer that pulses the heart icon at the given heart rate (BPM)
    /// - Parameter heartRate: The current heart rate in beats per minute
    ///
    /// How it works:
    /// 1. Calculate interval: 60 seconds / BPM = seconds between beats
    ///    Example: 120 BPM → 60/120 = 0.5 seconds per beat
    /// 2. Create a repeating Timer that fires at this interval
    /// 3. Each time the timer fires, toggle heartBeat to trigger animation
    private func startHeartBeatTimer(for heartRate: Int) {
        // Stop any existing timer first (prevent multiple timers)
        stopHeartBeatTimer()
        
        // Guard against invalid heart rates (avoid division by zero)
        guard heartRate > 0 else {
            return
        }
        
        // Calculate the interval between beats
        // 60 BPM = 1 beat per second (interval = 1.0)
        // 120 BPM = 2 beats per second (interval = 0.5)
        // 180 BPM = 3 beats per second (interval = 0.33)
        let interval = 60.0 / Double(heartRate)
        
        // Create a repeating timer on the main thread (required for UI updates)
        // Timer.scheduledTimer creates and starts a timer automatically
        beatTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            // Toggle heartBeat to trigger the scale animation
            // true → false → true → false ... creates the pulsing effect
            heartBeat.toggle()
        }
    }
    
    /// Stop and clean up the heart beat timer
    /// Called when view disappears or when heart rate changes (before creating new timer)
    private func stopHeartBeatTimer() {
        beatTimer?.invalidate()  // Stop the timer from firing
        beatTimer = nil          // Release the timer object
    }
    
    // BODY PROPERTY (Required by View protocol)
    // This computed property returns the UI layout
    // "some View" means it returns something that conforms to View protocol
    // SwiftUI calls this whenever it needs to render/update the UI
    //
    // Python/FastAPI analogy:
    // Like a Jinja2 template render function or a React component's render()
    var body: some View {
        // ZSTACK - Layered Stack (Z-axis)
        // Stacks views on top of each other (like CSS z-index)
        // First item is at the back, last item is at the front
        //
        // Python/HTML analogy:
        // Like layering <div> elements with position: absolute
        ZStack {
            
            // BACKGROUND GRADIENT
            // Creates a smooth color transition from top-left to bottom-right
            LinearGradient(
                gradient: Gradient(colors: [
                    // RGB colors (values from 0.0 to 1.0)
                    Color(red: 0.95, green: 0.97, blue: 1.0),  // Light blue-white
                    Color(red: 0.90, green: 0.95, blue: 1.0)   // Slightly darker blue
                ]),
                startPoint: .topLeading,      // Start from top-left corner
                endPoint: .bottomTrailing     // End at bottom-right corner
            )
            .ignoresSafeArea()  // Extend gradient beyond safe area (under notch, etc.)
            
            // VSTACK - Vertical Stack
            // Arranges child views vertically (top to bottom)
            // spacing: 30 adds 30 points of space between each child
            //
            // Python/HTML analogy:
            // Like a <div> with display: flex; flex-direction: column; gap: 30px;
            VStack(spacing: 30) {
                
                // ═══════════════════════════════════════════════════════════
                // HEART RATE SECTION
                // ═══════════════════════════════════════════════════════════
                // Nested VStack for the heart rate display area
                VStack(spacing: 12) {
                    
                    // HEART ICON
                    // SF Symbols is Apple's icon system (like Font Awesome)
                    // "systemName" refers to a built-in icon name
                    Image(systemName: "heart.fill")
                        // MODIFIERS - methods that modify the view
                        // Each .modifier() returns a new modified view
                        // They chain together (like method chaining in Python/pandas)
                        .font(.system(size: 40))                    // Set icon size
                        .foregroundColor(.red)                       // Make it red
                        // HEART RATE-SYNCED ANIMATION
                        // Scale up when heartBeat is true, normal size when false
                        // This creates a "lub-dub" pulsing effect at your actual heart rate
                        .scaleEffect(heartBeat ? 1.3 : 1.0)
                        .opacity(heartBeat ? 1.0 : 0.7)              // Brighter on beat, dimmer between
                        .animation(.easeInOut(duration: 0.15), value: heartBeat)
                    
                    // BPM NUMBER DISPLAY
                    // \(bpm) is string interpolation (like f"{bpm}" in Python)
                    if runSessionVM.currentHeartRate > 0 {
                    Text("\(runSessionVM.currentHeartRate)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))  // Large, bold, rounded font
                        .foregroundColor(.primary)                   // Primary color (adapts to light/dark mode)
                                            
                    // "BPM" LABEL
                    Text("BPM")
                        .font(.headline)                             // Predefined headline style
                        .foregroundColor(.secondary)                 // Secondary color (lighter gray)
                    } else {
                    Text("Fetching Heart Rate Data...")
                        .font(.system(size: 18, weight: .bold, design: .rounded))  // Large, bold, rounded font
                        .foregroundColor(.primary)                   // Primary color (adapts to light/dark mode)
                           .phaseAnimator([false, true]) { content, phase in
                                content.opacity(phase ? 1 : 0.4)
                            } animation: { _ in
                                .easeInOut(duration: 0.8)
                            }
                    }

                    
                    // CADENCE DISPLAY (only shown when cadence > 0, i.e., from Apple Watch)
                    if runSessionVM.currentCadence > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.run")
                                .foregroundColor(.cyan)
                            Text("\(runSessionVM.currentCadence) SPM")
                                .font(.headline)
                                .foregroundColor(.cyan)
                        }
                        .padding(.top, 4)
                    } else {
                        Text("Fetching Cadence Data...")
                        .font(.system(size: 18, weight: .bold, design: .rounded))  // Large, bold, rounded font
                        .foregroundColor(.primary)                   // Primary color (adapts to light/dark mode)
                           .phaseAnimator([false, true]) { content, phase in
                                content.opacity(phase ? 1 : 0.4)
                            } animation: { _ in
                                .easeInOut(duration: 0.8)
                            }
                    }
                    
                    // "TEMPO ZONE" PILL
                    // This creates a rounded pill-shaped badge
                    Text("Tempo Zone")
                        .font(.subheadline)                          // Smaller font
                        .fontWeight(.medium)                         // Medium weight
                        .padding(.horizontal, 16)                    // 16 points padding left/right
                        .padding(.vertical, 6)                       // 6 points padding top/bottom
                        .background(Capsule().fill(Color.blue.opacity(0.2)))  // Rounded background
                        .foregroundColor(.blue)                      // Blue text
                }
                .padding(.top, 80)  // Add space above to clear Dynamic Island and nav buttons
                
                // ═══════════════════════════════════════════════════════════
                // SONG CARD SECTION
                // ═══════════════════════════════════════════════════════════
                VStack(spacing: 16) {
                    
                    // ALBUM COVER ART
                    // Display actual artwork if available, otherwise show placeholder
                    if let artworkURL = runSessionVM.currentTrack?.artworkURL {
                        AsyncImage(url: artworkURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure(_):
                                // Fallback to placeholder on error
                                Image(systemName: "music.note")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            case .empty:
                                // Loading state
                                ProgressView()
                            @unknown default:
                                Image(systemName: "music.note")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    } else {
                        // Placeholder when no artwork
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 140, height: 140)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    // SONG INFORMATION
                    VStack(spacing: 4) {
                        // SONG TITLE with BPM
                        HStack(spacing: 8) {
                            Text(runSessionVM.currentTrack?.title ?? "—")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .layoutPriority(-1)  // Yields space to BPM badge
                            
                            // BPM Badge - always visible
                            if let bpm = runSessionVM.currentTrack?.bpm {
                                Text("\(bpm) BPM")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.blue.opacity(0.2)))
                                    .foregroundColor(.blue)
                                    .fixedSize()  // Prevents badge from shrinking
                            }
                        }
                        
                        // ARTIST NAME
                        Text(runSessionVM.currentTrack?.artist ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // PROGRESS BAR
                    VStack(spacing: 8) {
                        // Progress indicator showing song position
                        // value: progress from 0.0 to 1.0 based on playback time
                        ProgressView(value: songProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))  // Blue bar style
                            .scaleEffect(y: 2)                      // Make it 2x taller
                        
                        // TIME LABELS (current time and total duration)
                        // HStack arranges items horizontally (left to right)
                        // Like CSS: display: flex; flex-direction: row;
                        HStack {
                            Text(formatTime(runSessionVM.currentPlaybackTime ?? 0))  // Current time
                                .font(.caption)                     // Small font
                                .foregroundColor(.secondary)
                            Spacer()                                // Pushes items to edges
                            Text(formatTime(Double(runSessionVM.currentTrack?.durationSeconds ?? 0)))  // Total duration
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 4)                        // Small horizontal padding
                    
                    // HELPER TEXT
                    // Explains what the app is doing - dynamically based on mode
                    Text(runMode == .cadenceMatching
                         ? "Matching songs to your running cadence (\(runSessionVM.currentCadence) SPM)."
                         : "Matching songs to your heart rate (\(runSessionVM.currentHeartRate) BPM).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)            // Center-align text
                        .padding(.horizontal, 16)
                    
                    // ═══════════════════════════════════════════════════════════
                    // PLAYBACK CONTROLS
                    // ═══════════════════════════════════════════════════════════
                    HStack(spacing: 24) {
                        
                        // PREVIOUS BUTTON
                        // Button takes two parameters:
                        // 1. action: closure (like a lambda in Python) that runs when tapped
                        // 2. label: closure that returns the button's appearance
                        Button(action: {
                            runSessionVM.skipToPreviousTrack()
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                        
                        // PLAY/PAUSE BUTTON (Center, larger)
                        Button(action: {
                            // Call the ViewModel method to toggle play/pause
                            runSessionVM.togglePlayPause()
                        }) {
                            // TERNARY OPERATOR (condition ? true_value : false_value)
                            // Like Python: "pause.fill" if self.is_playing else "play.fill"
                            Image(systemName: runSessionVM.isPlaying == true ? "pause.fill" : "play.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)       // Fixed size
                                .background(Circle().fill(Color.blue))  // Blue circular background
                        }
                        
                        // NEXT BUTTON
                        Button(action: {
                            // Skip to next track, passing current heart rate for matching
                            runSessionVM.skipToNextTrack(approximateHeartRate: runSessionVM.currentHeartRate)
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.top, 8)
                }
                // CARD STYLING
                // These modifiers apply to the entire song card VStack above
                .padding(24)                                        // Internal padding
                .background(                                        // Background with shadow
                    RoundedRectangle(cornerRadius: 20)              // Rounded rectangle shape
                        .fill(Color.white.opacity(0.8))             // Semi-transparent white
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)  // Subtle shadow
                )
                .padding(.horizontal, 20)                           // External horizontal padding
                
                // SPACER
                // Pushes content above and below apart (fills available space)
                // Like CSS: flex-grow: 1
                Spacer()
                
                // ═══════════════════════════════════════════════════════════
                // BOTTOM PILL - "Next track queued"
                // ═══════════════════════════════════════════════════════════
                HStack {
                    Image(systemName: "sparkles")                   // Sparkle icon
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text("Next track queued")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()                                        // Push gear icon to right
                    
                    // SETTINGS BUTTON
                    Button(action: {}) {                            // Empty action for now
                        Image(systemName: "gear")                   // Gear icon
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color.white.opacity(0.8)))  // Pill-shaped background
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            
            // ═══════════════════════════════════════════════════════════
            // NAV BUTTONS OVERLAY (layered inside ZStack)
            // ═══════════════════════════════════════════════════════════
            VStack {
                HStack {
                    // HOME BUTTON (left side)
                    Button(action: {
                        dismiss()  // Navigate back to HomeView
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Home")
                                .font(.system(size: 17))
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.9))
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        )
                    }
                    
                    Spacer()
                    
                    // FINISH WORKOUT BUTTON (right side)
                    Button(action: {
                        runSessionVM.finishRun()
                    }) {
                        HStack(spacing: 4) {
                            Text("Finish")
                                .font(.system(size: 17))
                            Image(systemName: "flag.checkered")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.green)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.9))
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)  // Account for safe area
                
                Spacer()
            }
        }
        // ═══════════════════════════════════════════════════════════
        // VIEW LIFECYCLE METHODS
        // ═══════════════════════════════════════════════════════════
        // .onAppear - called when view appears on screen
        // Like React's useEffect(() => {}, []) or componentDidMount
        //
        // Python/FastAPI analogy:
        // Like a startup event handler or __enter__ in a context manager
        .onAppear {
            // Auto-start the run session
            runSessionVM.startRun()
            // Start heart beat timer if we already have a heart rate
            startHeartBeatTimer(for: runSessionVM.currentHeartRate)
        }
        // .onDisappear - called when view leaves screen
        // Like React's cleanup function or componentWillUnmount
        //
        // Python analogy:
        // Like __exit__ in a context manager or a cleanup/teardown method
        .onDisappear {
            // Only clean up if we're not showing the summary (view disappears during summary transition)
            if !runSessionVM.showingSummary {
                runSessionVM.stopRun()  // Clean up when leaving
            }
            stopHeartBeatTimer()    // Clean up timer
        }
        // ═══════════════════════════════════════════════════════════
        // HEART RATE CHANGE OBSERVER
        // ═══════════════════════════════════════════════════════════
        // .onChange watches a value and runs code when it changes
        // Like Python's property setter or a React useEffect with dependencies
        .onChange(of: runSessionVM.currentHeartRate) { oldValue, newValue in
            // Restart the timer with the new heart rate interval
            startHeartBeatTimer(for: newValue)
        }
        // ═══════════════════════════════════════════════════════════
        // WORKOUT SUMMARY OVERLAY
        // ═══════════════════════════════════════════════════════════
        .fullScreenCover(isPresented: $runSessionVM.showingSummary) {
            WorkoutSummaryView(
                elapsedTime: runSessionVM.elapsedTime,
                averageHeartRate: runSessionVM.averageHeartRate,
                maxHeartRate: runSessionVM.maxHeartRate,
                tracksPlayed: runSessionVM.tracksPlayed.count,
                onDismiss: {
                    runSessionVM.dismissSummary()  // This sends to watch
                    dismiss()
                }
            )
        }
        // ═══════════════════════════════════════════════════════════
        // WATCH-TRIGGERED DISMISSAL
        // When watch dismisses summary, this will navigate back to home
        // ═══════════════════════════════════════════════════════════
        .onChange(of: runSessionVM.shouldDismissEntireView) { shouldDismiss in
            if shouldDismiss {
                runSessionVM.shouldDismissEntireView = false  // Reset for next time
                dismiss()
            }
        }
    }
    
}

// MARK: - Workout Summary View

/// Shows workout statistics after finishing
struct WorkoutSummaryView: View {
    let elapsedTime: TimeInterval
    let averageHeartRate: Int
    let maxHeartRate: Int
    let tracksPlayed: Int
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.95, green: 0.97, blue: 1.0),
                    Color(red: 0.90, green: 0.95, blue: 1.0)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Workout Complete!")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                .padding(.top, 60)
                
                // Stats Card
                VStack(spacing: 20) {
                    // Duration
                    StatRow(
                        icon: "clock.fill",
                        iconColor: .blue,
                        label: "Duration",
                        value: formatDuration(elapsedTime)
                    )
                    
                    Divider()
                    
                    // Average Heart Rate
                    StatRow(
                        icon: "heart.fill",
                        iconColor: .red,
                        label: "Avg Heart Rate",
                        value: "\(averageHeartRate) BPM"
                    )
                    
                    Divider()
                    
                    // Max Heart Rate
                    StatRow(
                        icon: "heart.fill",
                        iconColor: .orange,
                        label: "Max Heart Rate",
                        value: "\(maxHeartRate) BPM"
                    )
                    
                    Divider()
                    
                    // Tracks Played
                    StatRow(
                        icon: "music.note.list",
                        iconColor: .purple,
                        label: "Tracks Played",
                        value: "\(tracksPlayed)"
                    )
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                )
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Done Button
                Button(action: onDismiss) {
                    HStack {
                        Image(systemName: "house.fill")
                        Text("Done")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.green)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

/// A single row in the stats display
struct StatRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 32)
            
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
}
