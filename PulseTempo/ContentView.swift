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
    
    // @StateObject creates and owns an ObservableObject
    // Use @StateObject when THIS view creates the object
    // The object persists across view re-renders (won't be recreated)
    //
    // Python analogy:
    // Like creating an instance variable in __init__ that persists
    // self.run_session_vm = RunSessionViewModel()
    @StateObject private var runSessionVM = RunSessionViewModel()
    
    // BODY PROPERTY (Required by View protocol)
    // This computed property returns the UI layout
    // "some View" means it returns something that conforms to View protocol
    // SwiftUI calls this whenever it needs to render/update the UI
    //
    // Python/FastAPI analogy:
    // Like a Jinja2 template render function or a React component's render()
    var body: some View {
        // NAVIGATION STACK
        // Container that enables navigation between screens (like push/pop in UIKit)
        // For now, we only have one screen, but this allows future navigation
        //
        // Python/Web analogy:
        // Like a router in Flask/FastAPI or React Router
        NavigationStack {
            
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
                            Text(runSessionVM.currentTrack?.title ?? "—")
                                .font(.title2)                          // Large title font
                                .fontWeight(.bold)                      // Bold text
                                .foregroundColor(.primary)              // Primary text color
                            
                            // ARTIST NAME
                            Text(runSessionVM.currentTrack?.artist ?? "")
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
                                // TODO: Implement previous track logic
                                runSessionVM.skipToNextTrack(approximateHeartRate: bpm)
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
                                Image(systemName: runSessionVM.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)       // Fixed size
                                    .background(Circle().fill(Color.blue))  // Blue circular background
                            }
                            
                            // NEXT BUTTON
                            Button(action: {
                                // Skip to next track, passing current heart rate for matching
                                runSessionVM.skipToNextTrack(approximateHeartRate: bpm)
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
    // ═══════════════════════════════════════════════════════════
    // Simulates heart rate changes for demo purposes
    // In production, this would read from HealthKit
    //
    // Python equivalent:
    // def _start_heart_rate_simulation(self):
    //     def update_bpm():
    //         change = random.randint(-3, 3)
    //         new_bpm = self.bpm + change
    //         ...
    //     self.timer = schedule_repeating_task(1.5, update_bpm)
    private func startHeartRateSimulation() {
        // TIMER - schedules repeating code execution
        // Similar to Python's threading.Timer or asyncio.create_task with a loop
        //
        // Parameters:
        // - withTimeInterval: 1.5 seconds between executions
        // - repeats: true means run continuously (not just once)
        // - closure: { _ in ... } is the code to run (lambda in Python)
        //   The _ ignores the Timer parameter we don't need
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            // RANDOM HEART RATE VARIATION
            // Simulate realistic heart rate fluctuation during exercise
            
            // Generate random change between -3 and +3
            // Int.random(in: range) is like Python's random.randint(-3, 3)
            let change = Int.random(in: -3...3)
            let newBPM = bpm + change
            
            // BOUNDS CHECKING
            // Keep BPM within safe exercise range (90-180)
            if newBPM >= 90 && newBPM <= 180 {
                bpm = newBPM                    // Update if within range
            } else if newBPM < 90 {
                bpm = 90                        // Clamp to minimum
            } else {
                bpm = 180                       // Clamp to maximum
            }
            // Note: Changing @State variable (bpm) automatically triggers UI update!
        }
    }
}

// PREVIEW
// #Preview is a macro for Xcode's live preview feature
// Lets you see the UI while coding without running the full app
//
// Python analogy:
// Like a __main__ block for quick testing:
// if __name__ == "__main__":
//     view = ActiveRunView()
//     view.show()
#Preview {
    ActiveRunView()
}
