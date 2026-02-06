//
//  GradientBackground.swift
//  inSync
//
//  Created by Zavier Rodrigues on 2/5/26.
//

import SwiftUI

/// Reusable animated gradient background - white/gray fading to black (inSync theme)
struct GradientBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            colors: [
                Color(white: 0.85),
                Color(white: 0.6),
                Color(white: 0.3),
                Color.black
            ],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                animateGradient = true
            }
        }
    }
}

/// Variant with accent color tint at top (like workout mode)
struct AccentGradientBackground: View {
    var accentColor: Color = .gray
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                accentColor.opacity(0.8),
                accentColor.opacity(0.4),
                Color.black
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

#Preview("Default") {
    GradientBackground()
}

#Preview("Accent") {
    AccentGradientBackground(accentColor: .red)
}
