//
//  GradientBackground.swift
//  inSync
//
//  Created by Zavier Rodrigues on 2/5/26.
//

import SwiftUI

/// Reusable gradient background - white/gray fading to black (inSync theme)
struct GradientBackground: View {
    var topColor: Color = Color(white: 0.85)
    var middleColor: Color = Color(white: 0.5)
    var bottomColor: Color = Color.black
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                topColor,
                middleColor,
                bottomColor
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
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
