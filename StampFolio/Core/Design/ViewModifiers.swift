//
//  ViewModifiers.swift
//  StampFolio
//
//  Reusable custom view modifiers
//

import SwiftUI


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

// MARK: - Empty Wallet State Modifier

struct EmptyWalletViewModifier: ViewModifier {
    let walletCount: Int
    
    func body(content: Content) -> some View {
        if walletCount == 0 {
            ContentUnavailableView {
                Label {
                    Text("No Wallets Added")
                        .foregroundStyle(.orange)
                } icon: {
                    Image(systemName: "wallet.bifold")
                        .foregroundStyle(.orange.secondary)
                }
            } description: {
                Text("Add a Bitcoin wallet to view your digital art collections.\nTap the Settings tab below to get started.")
            }
        } else {
            content
        }
    }
}

// MARK: - View Extensions

extension View {
    
    /// Apply shimmer loading effect
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
    
    /// Show empty wallet state when no wallets are added
    func emptyWalletOverlay(walletCount: Int) -> some View {
        modifier(EmptyWalletViewModifier(walletCount: walletCount))
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
    /// Standard stamp card background gradient - orange to orange with black center
    static let stampCardBackgroundGradient = LinearGradient(
        stops: [
            Gradient.Stop(color: .orange, location: 0),
            Gradient.Stop(color: .black, location: 0.3),
            Gradient.Stop(color: .black, location: 0.8),
            Gradient.Stop(color: .orange, location: 1)
        ],
        startPoint: .bottomLeading,
        endPoint: .topTrailing
    )
    
    /// Fullscreen background gradient - orange to orange with black center
    static let stampFullscreenBackgroundGradient = LinearGradient(
        stops: [
            Gradient.Stop(color: .orange, location: 0),
            Gradient.Stop(color: .black, location: 0.2),
            Gradient.Stop(color: .black, location: 0.9),
            Gradient.Stop(color: .orange, location: 1)
        ],
        startPoint: .bottomLeading,
        endPoint: .topTrailing
    )
}
