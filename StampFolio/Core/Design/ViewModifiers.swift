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
    @Binding var showAddWallet: Bool
    @Environment(\.appColorScheme) private var appColorScheme
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    func body(content: Content) -> some View {
        if walletCount == 0 {
            ContentUnavailableView {
                Label {
                    Text("No Wallets Configured")
                        .foregroundStyle(appColorScheme.primary)
                } icon: {
                    Image(systemName: "wallet.bifold")
                        .foregroundStyle(appColorScheme.secondary)
                }
            } description: {
                Text("Add a Bitcoin wallet to view your digital art collections.")
            } actions: {
                Button {
                    showAddWallet = true
                } label: {
                    Text("Add Wallet")
                        .fontWeight(.semibold)
                        .foregroundStyle(isDarkMode ? Color.black : Color.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .glassEffect(.regular.tint(appColorScheme.primary).interactive(), in: .capsule)
                }
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
    func emptyWalletOverlay(walletCount: Int, showAddWallet: Binding<Bool>) -> some View {
        modifier(EmptyWalletViewModifier(walletCount: walletCount, showAddWallet: showAddWallet))
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
    /// Standard card-sized background gradient with custom accent color, used behind
    /// non-image content placeholders (e.g. text/audio/video stamps, missing-artwork icons)
    static func cardBackground(color: Color) -> LinearGradient {
        LinearGradient(
            stops: [
                Gradient.Stop(color: color, location: 0),
                Gradient.Stop(color: .black, location: 0.3),
                Gradient.Stop(color: .black, location: 0.8),
                Gradient.Stop(color: color, location: 1)
            ],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    }
    
    /// Fullscreen-sized background gradient with custom accent color, used behind
    /// non-image content placeholders (e.g. text/audio/video stamps, empty states)
    static func fullscreenBackground(color: Color) -> LinearGradient {
        LinearGradient(
            stops: [
                Gradient.Stop(color: color, location: 0),
                Gradient.Stop(color: .black, location: 0.2),
                Gradient.Stop(color: .black, location: 0.9),
                Gradient.Stop(color: color, location: 1)
            ],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    }
}
