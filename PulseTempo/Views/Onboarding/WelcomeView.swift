//
//  WelcomeView.swift
//  inSync
//
//  Created by Zavier Rodrigues on 11/5/25.
//

import SwiftUI

/// Welcome screen - first screen in onboarding flow
/// Introduces the app concept and value proposition
struct WelcomeView: View {
    
    // MARK: - Properties
    
    /// Callback when user taps "Get Started"
    var onGetStarted: () -> Void
    
    // MARK: - State
    
    @State private var currentFeatureIndex = 0
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // White-to-black gradient background (inSync theme)
            GradientBackground()
            
            VStack(spacing: 0) {
                Spacer()
                
                // App Logo
                InSyncLogo(size: .large)
                    // .padding(.bottom, 20)
                    .offset(x: 10)
                
                // Tagline
                Text("Music That Moves With You")
                    .font(.bebasNeue(size: 20))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.bottom, 60)
                
                // Feature Cards
                VStack(spacing: 20) {
                    FeatureCard(
                        icon: "heart.circle.fill",
                        title: "Heart Rate Sync",
                        description: "Music automatically matches your workout intensity",
                        color: .pink
                    )
                    
                    FeatureCard(
                        icon: "music.note.list",
                        title: "Smart Playlists",
                        description: "Your Apple Music library, perfectly timed",
                        color: .purple
                    )
                    
                    FeatureCard(
                        icon: "figure.run",
                        title: "Adaptive Tempo",
                        description: "Tracks change as your heart rate changes",
                        color: .blue
                    )
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Get Started Button
                Button(action: onGetStarted) {
                    HStack {
                        Text("Get Started")
                            .font(.bebasNeueBody)
                        Image(systemName: "arrow.right")
                            .font(.bebasNeueSubheadline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [Color.pink, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: Color.pink.opacity(0.4), radius: 15, x: 0, y: 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Feature Card Component

/// Reusable card component for displaying app features
struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.bebasNeue(size: 24))
                    .foregroundColor(color)
            }
            
            // Text Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.bebasNeueBodySmall)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.bebasNeueCaption)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

#if DEBUG
struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView {
            print("Get Started tapped")
        }
    }
}
#endif
