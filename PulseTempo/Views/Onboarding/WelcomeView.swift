//
//  WelcomeView.swift
//  PulseTempo
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
    @State private var animateGradient = false
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.2, green: 0.1, blue: 0.3),
                    Color(red: 0.1, green: 0.2, blue: 0.3)
                ],
                startPoint: animateGradient ? .topLeading : .bottomLeading,
                endPoint: animateGradient ? .bottomTrailing : .topTrailing
            )
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                    animateGradient = true
                }
            }
            
            VStack(spacing: 0) {
                Spacer()
                
                // App Icon/Logo
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.pink, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: Color.pink.opacity(0.5), radius: 20, x: 0, y: 10)
                    
                    Image(systemName: "heart.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                    
                    Image(systemName: "music.note")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                        .offset(x: 25, y: -25)
                }
                .padding(.bottom, 40)
                
                // App Name
                Text("PulseTempo")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 12)
                
                // Tagline
                Text("Music That Moves With You")
                    .font(.system(size: 20, weight: .medium))
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
                            .font(.system(size: 18, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
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
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }
            
            // Text Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14))
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
