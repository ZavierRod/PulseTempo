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
    
    // PARAMETERS
    // Tracks to use for the workout session
    let tracks: [Track]
    
    // ENVIRONMENT
    // @Environment allows access to system-wide values
    // dismiss is used to close/pop the current view
    @Environment(\.dismiss) private var dismiss
    
    // STATE MANAGEMENT
    // @State is a property wrapper for local state that the View owns
    // When @State changes, SwiftUI automatically re-renders the View
    //
    // Python/React analogy:
    // Like React's useState hook or Vue's reactive data
    // When you change these values, the UI automatically updates
    //
    // "private" means only this View can modify these values
    @State private var bpm: Int = 152           // Current heart rate (beats per minute)
    @State private var timer: Timer?            // Timer for simulating heart rate changes
    @State private var runSessionVM: RunSessionViewModel?  // Initialized in onAppear with tracks
    
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
                        .symbolEffect(.pulse, value: bpm)            // Animate when bpm changes
                    
                    // BPM NUMBER DISPLAY
                    // \(bpm) is string interpolation (like f"{bpm}" in Python)
                    Text("\(bpm)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))  // Large, bold, rounded font
                        .foregroundColor(.primary)                   // Primary color (adapts to light/dark mode)
                    
                    // "BPM" LABEL
                    Text("BPM")
                        .font(.headline)                             // Predefined headline style
                        .foregroundColor(.secondary)                 // Secondary color (lighter gray)
                    
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
                .padding(.top, 40)  // Add 40 points of space above this section
                
                // ═══════════════════════════════════════════════════════════
                // SONG CARD SECTION
                // ═══════════════════════════════════════════════════════════
                VStack(spacing: 16) {
                    
                    // ALBUM COVER ART (Placeholder)
                    // Creates a rounded square with a music icon
                    RoundedRectangle(cornerRadius: 12)              // Rounded corners with 12pt radius
                        .fill(Color.gray.opacity(0.3))              // Semi-transparent gray fill
                        .frame(width: 120, height: 120)             // 120x120 points square
                        .overlay(                                   // Add content on top
                            Image(systemName: "music.note")         // Music note icon
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        )
                    
                    // SONG INFORMATION
                    VStack(spacing: 4) {
                        // SONG TITLE
                        // Uses optional chaining and nil coalescing
                        // runSessionVM.currentTrack?.title tries to get title
                        // If currentTrack is nil, the whole expression becomes nil
                        // ?? "—" provides a default value if nil
                        //
                        // Python equivalent:
                        // title = self.run_session_vm.current_track.title if self.run_session_vm.current_track else "—"
                        Text(runSessionVM?.currentTrack?.title ?? "—")
                            .font(.title2)                          // Large title font
                            .fontWeight(.bold)                      // Bold text
                            .foregroundColor(.primary)              // Primary text color
                        
                        // ARTIST NAME
                        Text(runSessionVM?.currentTrack?.artist ?? "")
                            .font(.subheadline)                     // Smaller font
                            .foregroundColor(.secondary)            // Secondary (gray) color
                    }
                    
                    // PROGRESS BAR
                    VStack(spacing: 8) {
                        // Progress indicator showing song position
                        // value: 0.3 means 30% complete (0.0 to 1.0 range)
                        ProgressView(value: 0.3)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))  // Blue bar style
                            .scaleEffect(y: 2)                      // Make it 2x taller
                        
                        // TIME LABELS (current time and total duration)
                        // HStack arranges items horizontally (left to right)
                        // Like CSS: display: flex; flex-direction: row;
                        HStack {
                            Text("1:23")                            // Current time
                                .font(.caption)                     // Small font
                                .foregroundColor(.secondary)
                            Spacer()                                // Pushes items to edges
                            Text("3:45")                            // Total duration
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 4)                        // Small horizontal padding
                    
                    // HELPER TEXT
                    // Explains what the app is doing
                    Text("Matching songs between 148–158 BPM to your heart rate.")
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
                            runSessionVM?.skipToPreviousTrack()
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                        
                        // PLAY/PAUSE BUTTON (Center, larger)
                        Button(action: {
                            // Call the ViewModel method to toggle play/pause
                            runSessionVM?.togglePlayPause()
                        }) {
                            // TERNARY OPERATOR (condition ? true_value : false_value)
                            // Like Python: "pause.fill" if self.is_playing else "play.fill"
                            Image(systemName: runSessionVM?.isPlaying == true ? "pause.fill" : "play.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)       // Fixed size
                                .background(Circle().fill(Color.blue))  // Blue circular background
                        }
                        
                        // NEXT BUTTON
                        Button(action: {
                            // Skip to next track, passing current heart rate for matching
                            runSessionVM?.skipToNextTrack(approximateHeartRate: bpm)
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
            // BACK BUTTON OVERLAY (layered inside ZStack)
            // ═══════════════════════════════════════════════════════════
            VStack {
                HStack {
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
                }
                .padding(.leading, 20)
                .padding(.top, 50)  // Account for safe area
                
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
            // Initialize RunSessionViewModel with tracks
            runSessionVM = RunSessionViewModel(tracks: tracks)
            
            // Auto-start the run session
            runSessionVM?.startRun()
            
            startHeartRateSimulation()  // Start simulating heart rate changes
        }
        // .onDisappear - called when view leaves screen
        // Like React's cleanup function or componentWillUnmount
        //
        // Python analogy:
        // Like __exit__ in a context manager or a cleanup/teardown method
        .onDisappear {
            timer?.invalidate()  // Stop the timer (? safely unwraps Optional)
        }
    }
    
    // ═══════════════════════════════════════════════════════════
    // HELPER METHOD: startHeartRateSimulation
    private func startHeartRateSimulation() {
        // Invalidate any existing timer before starting a new one
        timer?.invalidate()

        // Simulate heart rate changes around the current bpm
        // Updates once per second with a small random delta, clamped to a sensible range
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let delta = Int.random(in: -3...3)
            let updated = self.bpm + delta
            // Clamp between 120 and 180 bpm to keep values realistic for a run
            self.bpm = min(max(updated, 120), 180)
        }
    }
}
