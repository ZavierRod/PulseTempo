//
//  ContentView.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 11/4/25.
//

import SwiftUI

struct ActiveRunView: View {
    @State private var bpm: Int = 152
    @State private var timer: Timer?
    @StateObject private var runSessionVM = RunSessionViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.95, green: 0.97, blue: 1.0),
                        Color(red: 0.90, green: 0.95, blue: 1.0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Heart Rate Section
                    VStack(spacing: 12) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                            .symbolEffect(.pulse, value: bpm)
                        
                        Text("\(bpm)")
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("BPM")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Tempo Zone")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.blue.opacity(0.2)))
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 40)
                    
                    // Song Card
                    VStack(spacing: 16) {
                        // Cover Art
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            )
                        
                        // Song Info
                        VStack(spacing: 4) {
                            Text(runSessionVM.currentTrack?.title ?? "—")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text(runSessionVM.currentTrack?.artist ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // Progress Bar
                        VStack(spacing: 8) {
                            ProgressView(value: 0.3)
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                .scaleEffect(y: 2)
                            
                            HStack {
                                Text("1:23")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("3:45")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 4)
                        
                        // Helper Text
                        Text("Matching songs between 148–158 BPM to your heart rate.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                        
                        // Playback Controls
                        HStack(spacing: 24) {
                            Button(action: {
                                // TODO: Implement previous track logic
                                runSessionVM.skipToNextTrack(approximateHeartRate: bpm)
                            }) {
                                Image(systemName: "backward.fill")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                            }
                            
                            Button(action: {
                                runSessionVM.togglePlayPause()
                            }) {
                                Image(systemName: runSessionVM.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(Circle().fill(Color.blue))
                            }
                            
                            Button(action: {
                                runSessionVM.skipToNextTrack(approximateHeartRate: bpm)
                            }) {
                                Image(systemName: "forward.fill")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.8))
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                    )
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Next Track Queued Pill
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text("Next track queued")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: {}) {
                            Image(systemName: "gear")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.white.opacity(0.8)))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            startHeartRateSimulation()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startHeartRateSimulation() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            // Simulate heart rate variation within realistic running range
            let change = Int.random(in: -3...3)
            let newBPM = bpm + change
            
            // Keep BPM within safe exercise range
            if newBPM >= 90 && newBPM <= 180 {
                bpm = newBPM
            } else if newBPM < 90 {
                bpm = 90
            } else {
                bpm = 180
            }
        }
    }
}

#Preview {
    ActiveRunView()
}
