//
//  PulseTempoWidgetLiveActivity.swift
//  PulseTempoWidget
//
//  Created by Zavier Rodrigues on 3/2/26.
//

import ActivityKit
import WidgetKit
import SwiftUI


struct PulseTempoWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PulseTempoWidgetAttributes.self) { context in
            // Lock screen / Banner UI
            LockScreenLiveActivityView(state: context.state, attributes: context.attributes)
                .activityBackgroundTint(Color.black.opacity(0.8))
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("\(Int(context.state.heartRate))")
                            .font(.system(.title3, design: .rounded).bold())
                            .foregroundColor(.white)
                    }
                    .padding(.leading, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .foregroundColor(.cyan)
                        Text(formatDuration(context.state.elapsedTime))
                            .font(.system(.title3, design: .rounded).monospacedDigit())
                            .foregroundColor(.white)
                    }
                    .padding(.trailing, 8)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if let data = context.state.artworkData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 44, height: 44)
                                .cornerRadius(8)
                        } else {
                            Image("inSyncLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.85))
                                .cornerRadius(8)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Queued:")
                                .font(.system(.caption, design: .default).bold())
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text(context.state.queuedSongTitle)
                                .font(.system(.headline, design: .default).bold())
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            HStack(spacing: 6) {
                                Text(context.state.queuedArtistName)
                                    .font(.system(.subheadline))
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(1)
                                
                                if let bpm = context.state.queuedSongBPM {
                                    Text("• \(bpm) BPM")
                                        .font(.system(.caption, design: .rounded).bold())
                                        .foregroundColor(.teal)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill").foregroundColor(.red)
                    Text("\(Int(context.state.heartRate))")
                        .foregroundColor(.white)
                }
            } compactTrailing: {
                Image(systemName: "waveform")
                    .foregroundColor(.teal)
            } minimal: {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
            }
            .widgetURL(URL(string: "pulsetempo://activity"))
            .keylineTint(Color.red)
        }
    }
    
    private func formatDuration(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct LockScreenLiveActivityView: View {
    let state: PulseTempoWidgetAttributes.ContentState
    let attributes: PulseTempoWidgetAttributes
    
    var body: some View {
        HStack(spacing: 16) {
            // Artwork
            Image("inSyncLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 80)
            
            // Track Info
            VStack(alignment: .leading, spacing: 2) {
                Text("Queued: \(state.queuedSongTitle)")
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                
                HStack(spacing: 6) {
                    Text(state.queuedArtistName)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                    
                    if let bpm = state.queuedSongBPM {
                        Text("• \(bpm) BPM")
                            .font(.system(.caption, design: .rounded).bold())
                            .foregroundColor(.teal)
                    }
                }
            }
            
            Spacer()
            
            // Workout Stats
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 2) {
                    if let bpm = state.queuedSongBPM {
                        Text("\(bpm)")
                            .font(.system(.title3, design: .rounded).bold())
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2)
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                            .shadow(color: .black.opacity(0.5), radius: 2)
                    } else {
                        Image(systemName: "waveform")
                            .foregroundColor(.teal)
                            .font(.caption)
                            .shadow(color: .black.opacity(0.5), radius: 2)
                    }
                }
                
                Text(formatDuration(state.elapsedTime))
                    .font(.system(.subheadline, design: .rounded).monospacedDigit())
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.5), radius: 2)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color(white: 0.85),
                    Color(white: 0.65),
                    Color(white: 0.4),
                    Color(white: 0.15),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    private func formatDuration(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
