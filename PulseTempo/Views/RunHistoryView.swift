//
//  RunHistoryView.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 1/28/26.
//

import SwiftUI

/// View displaying list of all past workout sessions
struct RunHistoryView: View {
    
    // MARK: - Properties
    
    let runHistory: [WorkoutSummary]
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                GradientBackground()
                    .ignoresSafeArea()
                
                if runHistory.isEmpty {
                    emptyState
                } else {
                    runList
                }
            }
            .navigationTitle("Workout History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run")
                .font(.bebasNeueExtraLarge)
                .foregroundColor(.white.opacity(0.3))
            
            Text("No Workouts Yet")
                .font(.bebasNeueTitle)
                .foregroundColor(.white)
            
            Text("Complete your first workout to see it here.")
                .font(.bebasNeueSubheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private var runList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(runHistory) { workout in
                    RunHistoryCard(workout: workout)
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Run History Card

/// Card displaying a single workout summary
struct RunHistoryCard: View {
    let workout: WorkoutSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date header
            HStack {
                Text(workout.formattedDate)
                    .font(.bebasNeueSubheadline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(workout.formattedDuration)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Stats row
            HStack(spacing: 24) {
                // Heart Rate
                StatBadge(
                    icon: "heart.fill",
                    value: "\(workout.averageBPM)",
                    label: "BPM",
                    color: .pink
                )
                
                // Cadence
                StatBadge(
                    icon: "figure.run",
                    value: "\(workout.averageCadence)",
                    label: "SPM",
                    color: .blue
                )
                
                // Duration
                StatBadge(
                    icon: "clock.fill",
                    value: "\(workout.durationMinutes)",
                    label: "min",
                    color: .green
                )
                
                Spacer()
            }
        }
        .padding(16)
        .glassCardStyle()
    }
}

// MARK: - Stat Badge

/// Small badge showing an icon and value
struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.bebasNeueCaptionSmall)
                .foregroundColor(color)
            
            Text(value)
                .font(.bebasNeueCaption)
                .foregroundColor(.white)
            
            Text(label)
                .font(.bebasNeueCaptionSmall)
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

// MARK: - Preview

#if DEBUG
struct RunHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        RunHistoryView(runHistory: [
            WorkoutSummary(
                id: "1",
                date: Date(),
                durationMinutes: 32,
                averageBPM: 145,
                averageCadence: 165,
                songsPlayed: 8
            ),
            WorkoutSummary(
                id: "2",
                date: Date().addingTimeInterval(-86400),
                durationMinutes: 45,
                averageBPM: 138,
                averageCadence: 158,
                songsPlayed: 12
            ),
            WorkoutSummary(
                id: "3",
                date: Date().addingTimeInterval(-172800),
                durationMinutes: 28,
                averageBPM: 152,
                averageCadence: 170,
                songsPlayed: 6
            )
        ])
    }
}
#endif
