//
//  StampAssetCardView.swift
//  StampFolio
//
//  Individual stamp card for the collection grid
//

import SwiftUI
import SwiftData

/// Card view displaying a stamp in the collection grid
struct StampAssetCardView: View {
    
    // MARK: - Properties
    
    let displayAsset: StampDisplay
    let onTap: () -> Void
    let onLongPress: () -> Void
    let viewMode: ViewMode
    
    // Convenience accessor
    private var asset: StampAsset { displayAsset.asset }
    
    // MARK: - Environment
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appColorScheme) private var appColorScheme
    @Query(sort: \WalletConfig.addedDate) private var wallets: [WalletConfig]
    
    // MARK: - State
    
    @AppStorage("showWalletIcons") private var showWalletIcons = false
    @State private var isPressed = false
    
    // MARK: - Body
    
    var body: some View {
        stampContent
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()  // Show metadata sheet
            }
            .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
                isPressed = pressing
            }, perform: {
                onLongPress()  // Show detail view
            })
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityDescription)
            .accessibilityHint("Tap for details, hold for fullscreen")
            .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Stamp Content
    
    private var stampContent: some View {
        GeometryReader { geometry in
            ZStack {
                StampAssetImageView(asset: asset, size: geometry.size, reusesWebView: true)
                
                // Overlay: Stamp number (top left), wallet icon (top right) and Edition balance (bottom right)
                // Hidden in dense grid mode for cleaner appearance
                if viewMode != .denseGrid {
                    VStack {
                        HStack(alignment: .top) {
                            // Stamp number - top left
                            stampNumber
                            
                            Spacer()
                            
                            // Wallet icon - top right
                            if showWalletIcons, displayAsset.walletAddress != nil {
                                walletIcon
                            }
                        }
                        .padding(4)
                        
                        Spacer()
                        
                        HStack(alignment: .bottom) {
                            Spacer()
                            
                            // Edition balance - bottom right
                            stampEditions
                        }
                        .padding(4)
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
    
    // MARK: - Stamp Number Pill
    
    private var stampNumber: some View {
        Text("#\(asset.id)")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(uiColor: .systemBackground).opacity(0.85))
            )
            .accessibilityLabel("Stamp number \(asset.id)")
    }
    
    // MARK: - Stamp Editions Pill
    
    private var stampEditions: some View {
        Text(displayAsset.formattedBalanceWithSupply)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(appColorScheme.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(uiColor: .systemBackground).opacity(0.85))
            )
            .accessibilityLabel("Balance: \(displayAsset.formattedBalanceWithSupply)")
    }
    
    // MARK: - Wallet Icon Pill
    
    private var walletIcon: some View {
        WalletIndicatorView(walletAddress: displayAsset.walletAddress, wallets: wallets, style: .pill)
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        var parts = [asset.formattedStampId]
        if viewMode != .denseGrid {
            parts.append("Balance: \(displayAsset.formattedBalanceWithSupply)")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Preview

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
        StampAssetCardView(
            displayAsset: StampDisplay(from: StampAsset.sample),
            onTap: {},
            onLongPress: {},
            viewMode: .normalGrid
        )
        
        StampAssetCardView(
            displayAsset: StampDisplay(from: StampAsset.samples[1]),
            onTap: {},
            onLongPress: {},
            viewMode: .normalGrid
        )
    }
    .padding()
}
