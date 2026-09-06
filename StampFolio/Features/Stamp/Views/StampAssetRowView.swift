//
//  StampAssetRowView.swift
//  StampFolio
//
//  Row view displaying a stamp in list mode
//

import SwiftUI
import SwiftData

/// Row view displaying a stamp in the collection list
struct StampAssetRowView: View {
    
    // MARK: - Properties
    
    let displayAsset: StampDisplay
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    // Convenience accessor
    private var asset: StampAsset { displayAsset.asset }
    
    // MARK: - Environment
    
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \WalletConfig.addedDate) private var wallets: [WalletConfig]
    
    // MARK: - State
    
    @AppStorage("showWalletIcons") private var showWalletIcons = false
    @State private var isPressed = false
    
    // MARK: - Body
    
    var body: some View {
        rowContent
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
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
    
    // MARK: - Row Content
    
    private var rowContent: some View {
        ViewThatFits(in: .horizontal) {
            wideRow
            compactRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(6)
    }

    private var wideRow: some View {
        HStack(alignment: .center, spacing: 24) {
            previewImage
            marketColumn
                .fixedSize(horizontal: true, vertical: false)
            identityColumn(showsFloorPrice: false)
                .frame(
                    minWidth: AssetRowMetrics.wideIdentityMinWidth,
                    maxWidth: AssetRowMetrics.wideIdentityMaxWidth
                )
        }
    }

    private var compactRow: some View {
        HStack(alignment: .center, spacing: 24) {
            previewImage
            identityColumn(showsFloorPrice: true)
        }
    }

    private var previewImage: some View {
        StampAssetImageView(asset: asset, size: AssetRowMetrics.stampPreviewSize, reusesWebView: true)
            .clipShape(RoundedRectangle(cornerRadius: AssetRowMetrics.previewCornerRadius))
    }

    private var marketColumn: some View {
        AssetMarketMetricsColumn(
            holdersText: formattedHolderCount,
            listingsCount: listingsCount,
            floorPriceText: formattedFloorPrice
        )
    }

    @ViewBuilder
    private func identityColumn(showsFloorPrice: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                Text("#\(asset.stampId)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Spacer(minLength: 4)
                
                AssetBalancePill(text: displayAsset.formattedBalance)
            }
            
            HStack(alignment: .center, spacing: 8) {
                Text(artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                Spacer(minLength: 4)
                
                if showsWalletIcon {
                    walletIcon
                }
            }
            
            HStack(alignment: .center, spacing: 8) {
                AssetStatusIconsView(
                    isLocked: asset.isLocked,
                    isDivisible: asset.divisible,
                    isKeyburned: asset.isKeyburned
                )
                
                Spacer(minLength: 4)
                
                if showsFloorPrice, let formattedFloorPrice {
                    AssetFloorPricePill(text: formattedFloorPrice)
                }
            }
        }
    }
    
    // MARK: - Artist Name
    
    private var artistName: String {
        if let creatorName = asset.creatorName {
            return creatorName
        } else {
            return asset.creatorAddy.truncatedAddress(length: 6)
        }
    }
    
    // MARK: - Market Data
    
    private var formattedFloorPrice: String? {
        displayAsset.marketData?.formattedFloorPrice
            ?? asset.marketData?.formattedFloorPrice
    }

    private var formattedHolderCount: String? {
        displayAsset.marketData?.formattedHolderCount
            ?? asset.marketData?.formattedHolderCount
    }

    private var listingsCount: Int? {
        displayAsset.marketData?.openDispensersCount
            ?? asset.marketData?.openDispensersCount
    }
    
    private var showsWalletIcon: Bool {
        showWalletIcons && displayAsset.walletAddress != nil
    }
    
    // MARK: - Accessibility
    
    private var accessibilityDescription: String {
        var parts = [
            "Stamp \(asset.stampId)",
            artistName,
            "Balance: \(displayAsset.formattedBalance)",
            asset.isLocked ? "Locked" : "Unlocked"
        ]
        if asset.divisible { parts.append("Divisible") }
        if asset.isKeyburned { parts.append("Keyburn") }
        if let formattedHolderCount {
            parts.append(formattedHolderCount)
        }
        if let listingsCount, listingsCount > 0 {
            parts.append("\(listingsCount) listing\(listingsCount == 1 ? "" : "s")")
        }
        if let formattedFloorPrice {
            parts.append("Floor price: \(formattedFloorPrice)")
        }
        return parts.joined(separator: ", ")
    }
    
    // MARK: - Wallet Icon
    
    private var walletIcon: some View {
        WalletIndicatorView(
            walletAddress: displayAsset.walletAddress,
            wallets: wallets,
            style: .circleBackground,
            accessibilityHint: "Shows which wallet owns this stamp"
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        StampAssetRowView(
            displayAsset: StampDisplay(from: StampAsset.sample),
            onTap: {},
            onLongPress: {}
        )
        
        StampAssetRowView(
            displayAsset: StampDisplay(from: StampAsset.samples[1]),
            onTap: {},
            onLongPress: {}
        )
        
        StampAssetRowView(
            displayAsset: StampDisplay(from: StampAsset.samples[2]),
            onTap: {},
            onLongPress: {}
        )
    }
    .padding()
}
