//
//  ViewModifiers.swift
//  StampFolio
//
//  Reusable view modifiers using native iOS Materials with Stampchain styling
//

import SwiftUI

// MARK: - Glass Card Modifier

/// Applies a glassmorphism card effect using native iOS Materials
struct GlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .background {
                        // Subtle tint showing through Material
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.cardTint(for: colorScheme))
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(
                color: colorScheme == .dark 
                    ? Color.accent.opacity(0.15) 
                    : Color.black.opacity(0.1),
                radius: shadowRadius,
                y: shadowRadius / 2
            )
    }
}

// MARK: - Stampchain Background Modifier

/// Applies the Stampchain background
struct StampchainBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background {
                Color.adaptiveBackground(for: colorScheme)
                    .ignoresSafeArea()
            }
    }
}

// MARK: - Glass Button Modifier

/// Applies a glass button style
struct GlassButtonModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    
    let isPressed: Bool
    
    init(isPressed: Bool = false) {
        self.isPressed = isPressed
    }
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.thinMaterial)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                isPressed 
                                    ? Color.accent.opacity(0.2) 
                                    : Color.accent.opacity(0.1)
                            )
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accent.opacity(0.3), lineWidth: 1)
            }
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
}

// MARK: - Shimmer Effect Modifier (for loading states)

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.2),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            }
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 400
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    
    /// Apply glassmorphism card styling using native iOS Materials
    /// - Parameters:
    ///   - cornerRadius: Corner radius of the card (default: 16)
    ///   - shadowRadius: Shadow blur radius (default: 8)
    func glassCard(cornerRadius: CGFloat = 16, shadowRadius: CGFloat = 8) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, shadowRadius: shadowRadius))
    }
    
    /// Apply Stampchain background
    func stampchainBackground() -> some View {
        modifier(StampchainBackgroundModifier())
    }
    
    /// Apply glass button styling
    func glassButton(isPressed: Bool = false) -> some View {
        modifier(GlassButtonModifier(isPressed: isPressed))
    }
    
    /// Apply shimmer loading effect
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Scaled Metric for Accessibility

/// Scaled spacing values that adapt to Dynamic Type
struct ScaledSpacing {
    @ScaledMetric(relativeTo: .body) var small: CGFloat = 8
    @ScaledMetric(relativeTo: .body) var medium: CGFloat = 16
    @ScaledMetric(relativeTo: .body) var large: CGFloat = 24
    @ScaledMetric(relativeTo: .body) var extraLarge: CGFloat = 32
}
