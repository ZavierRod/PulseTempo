//
//  GradientBackground.swift
//  inSync
//
//  Created by Zavier Rodrigues on 2/5/26.
//

import SwiftUI

/// Reusable animated gradient background - white/gray fading to black (inSync theme)
struct GradientBackground: View {
    @State private var startPoint: UnitPoint = .topLeading
    @State private var endPoint: UnitPoint = .bottomTrailing
    
    var body: some View {
        LinearGradient(
            colors: [
                Color(white: 0.85),
                Color(white: 0.65),
                Color(white: 0.4),
                Color(white: 0.15),
                Color.black
            ],
            startPoint: startPoint,
            endPoint: endPoint
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true)) {
                startPoint = .topTrailing
                endPoint = .bottomLeading
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
