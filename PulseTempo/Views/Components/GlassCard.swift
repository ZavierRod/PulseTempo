//
//  GlassCard.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 2/5/26.
//

import SwiftUI

/// ViewModifier for applying the "Glassmorphism" card style
struct GlassCardStyle: ViewModifier {
    var cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(0.1))
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
    }
}

extension View {
    /// Applies the standard app glass card styling
    func glassCardStyle(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassCardStyle(cornerRadius: cornerRadius))
    }
}

// Preview helper
struct GlassCard_Preview: View {
    var body: some View {
        ZStack {
            GradientBackground()
            
            VStack {
                Text("Glass Card")
                    .foregroundColor(.white)
                    .padding()
                    .glassCardStyle()
            }
        }
    }
}

#Preview {
    GlassCard_Preview()
}
