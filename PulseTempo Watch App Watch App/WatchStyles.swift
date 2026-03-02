//
//  WatchStyles.swift
//  PulseTempo Watch App
//
//  Shared styling components matching the iPhone app's visual language.
//  Adapted for the smaller watchOS display.
//

import SwiftUI

// MARK: - Gradient Background

struct WatchGradientBackground: View {
    var accentColor: Color?

    var body: some View {
        if let accent = accentColor {
            LinearGradient(
                colors: [
                    accent.opacity(0.7),
                    accent.opacity(0.3),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        } else {
            LinearGradient(
                colors: [
                    Color(white: 0.25),
                    Color(white: 0.10),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Glass Card Modifier

struct WatchGlassCard: ViewModifier {
    var cornerRadius: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
    }
}

extension View {
    func watchGlassCard(cornerRadius: CGFloat = 14) -> some View {
        modifier(WatchGlassCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Heart Rate Zone (Watch-local copy)

enum WatchHeartRateZone: String, CaseIterable {
    case rest
    case warmUp
    case fatBurn
    case cardio
    case peak
    case max

    var name: String {
        switch self {
        case .rest:    return "Rest"
        case .warmUp:  return "Warm Up"
        case .fatBurn: return "Fat Burn"
        case .cardio:  return "Cardio"
        case .peak:    return "Peak"
        case .max:     return "Maximum"
        }
    }

    var color: Color {
        switch self {
        case .rest:    return .gray
        case .warmUp:  return .blue
        case .fatBurn: return .green
        case .cardio:  return .yellow
        case .peak:    return .orange
        case .max:     return .red
        }
    }

    static func zone(for heartRate: Double) -> WatchHeartRateZone {
        switch Int(heartRate) {
        case ..<100:    return .rest
        case 100..<120: return .warmUp
        case 120..<140: return .fatBurn
        case 140..<160: return .cardio
        case 160..<180: return .peak
        default:        return .max
        }
    }
}

// MARK: - Styled Watch Button

struct WatchStyledButton: View {
    let title: String
    let icon: String
    var tintColor: Color = .white
    var fillColor: Color = Color.white.opacity(0.10)
    var isProminent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(isProminent ? .black : tintColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isProminent ? tintColor : fillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(tintColor.opacity(isProminent ? 0 : 0.25), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
