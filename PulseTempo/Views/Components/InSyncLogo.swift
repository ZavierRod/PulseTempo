//
//  InSyncLogo.swift
//  inSync
//
//  Created by Zavier Rodrigues on 2/6/26.
//

import SwiftUI

/// inSync logo component with heart and heartbeat line
/// Based on the brand logo: heart icon above a heartbeat ECG line
struct InSyncLogo: View {
    var size: LogoSize = .medium
    var showText: Bool = true
    
    enum LogoSize {
        case small, medium, large
        
        var heartSize: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 24
            case .large: return 36
            }
        }
        
        var lineWidth: CGFloat {
            switch self {
            case .small: return 80
            case .medium: return 150
            case .large: return 220
            }
        }
        
        var lineHeight: CGFloat {
            switch self {
            case .small: return 20
            case .medium: return 40
            case .large: return 60
            }
        }
        
        var textSize: CGFloat {
            switch self {
            case .small: return 20
            case .medium: return 36
            case .large: return 48
            }
        }
        
        var strokeWidth: CGFloat {
            switch self {
            case .small: return 1.5
            case .medium: return 2.5
            case .large: return 3.5
            }
        }
    }
    
    var body: some View {
        VStack(spacing: size == .small ? 4 : 8) {
            ZStack {
                // Text "inSync" with subtle gray color (matching logo)
                if showText {
                    Text("inSync")
                        .font(.system(size: size.textSize, weight: .bold, design: .rounded))
                        .foregroundColor(Color(white: 0.75).opacity(0.6))
                }
                
                // Heartbeat line overlay
                HeartbeatLine(size: size)
                    .offset(y: size == .large ? 10 : size == .medium ? 6 : 4)
            }
            
            // Small heart icon positioned at top-left
            .overlay(alignment: .topLeading) {
                Image(systemName: "heart.fill")
                    .font(.system(size: size.heartSize))
                    .foregroundColor(.red)
                    .offset(x: -size.heartSize * 0.3, y: -size.heartSize * 0.8)
            }
        }
    }
}

/// Custom heartbeat/ECG line shape
struct HeartbeatLine: View {
    let size: InSyncLogo.LogoSize
    
    var body: some View {
        Path { path in
            let width = size.lineWidth
            let height = size.lineHeight
            let midY = height / 2
            
            // Start from left
            path.move(to: CGPoint(x: 0, y: midY))
            
            // Flat line to first spike
            path.addLine(to: CGPoint(x: width * 0.35, y: midY))
            
            // Small dip down
            path.addLine(to: CGPoint(x: width * 0.38, y: midY + height * 0.1))
            
            // Sharp spike up
            path.addLine(to: CGPoint(x: width * 0.45, y: midY - height * 0.45))
            
            // Sharp spike down
            path.addLine(to: CGPoint(x: width * 0.52, y: midY + height * 0.35))
            
            // Return to baseline with small bump
            path.addLine(to: CGPoint(x: width * 0.58, y: midY - height * 0.1))
            
            // Continue flat to end
            path.addLine(to: CGPoint(x: width, y: midY))
        }
        .stroke(Color.red, style: StrokeStyle(lineWidth: size.strokeWidth, lineCap: .round, lineJoin: .round))
        .frame(width: size.lineWidth, height: size.lineHeight)
    }
}

/// Compact logo version (just heart + heartbeat, no text)
struct InSyncLogoCompact: View {
    var size: CGFloat = 40
    
    var body: some View {
        ZStack {
            // Heartbeat line
            Path { path in
                let width = size * 2
                let height = size * 0.6
                let midY = height / 2
                
                path.move(to: CGPoint(x: 0, y: midY))
                path.addLine(to: CGPoint(x: width * 0.3, y: midY))
                path.addLine(to: CGPoint(x: width * 0.35, y: midY + height * 0.1))
                path.addLine(to: CGPoint(x: width * 0.45, y: midY - height * 0.5))
                path.addLine(to: CGPoint(x: width * 0.55, y: midY + height * 0.4))
                path.addLine(to: CGPoint(x: width * 0.62, y: midY - height * 0.1))
                path.addLine(to: CGPoint(x: width, y: midY))
            }
            .stroke(Color.red, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            .frame(width: size * 2, height: size * 0.6)
        }
        .overlay(alignment: .topLeading) {
            Image(systemName: "heart.fill")
                .font(.system(size: size * 0.4))
                .foregroundColor(.red)
                .offset(x: -size * 0.1, y: -size * 0.35)
        }
    }
}

#Preview("Medium") {
    ZStack {
        GradientBackground()
        InSyncLogo(size: .medium)
    }
}

#Preview("Large") {
    ZStack {
        GradientBackground()
        InSyncLogo(size: .large)
    }
}

#Preview("Small") {
    ZStack {
        GradientBackground()
        InSyncLogo(size: .small)
    }
}

#Preview("Compact") {
    ZStack {
        GradientBackground()
        InSyncLogoCompact(size: 50)
    }
}
