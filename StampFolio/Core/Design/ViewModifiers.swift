//
//  ViewModifiers.swift
//  StampFolio
//
//  Reusable custom view modifiers
//

import SwiftUI

// MARK: - Stampchain Background Modifier

/// Applies the Stampchain background
struct StampchainBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
            }
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
    
    /// Apply Stampchain background
    func stampchainBackground() -> some View {
        modifier(StampchainBackgroundModifier())
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

// MARK: - Reusable Gradients

extension LinearGradient {
    /// Standard stamp card background gradient - purple to orange with black center
    static let stampCardBackgroundGradient = LinearGradient(
        stops: [
            Gradient.Stop(color: .purple, location: 0),
            Gradient.Stop(color: .black, location: 0.2),
            Gradient.Stop(color: .black, location: 0.9),
            Gradient.Stop(color: .orange, location: 1)
        ],
        startPoint: .bottomLeading,
        endPoint: .topTrailing
    )
}
