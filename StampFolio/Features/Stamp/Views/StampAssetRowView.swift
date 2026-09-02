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
    @Environment(\.appColorScheme) private var appColorScheme
    @Query(sort: \WalletConfig.addedDate) private var wallets: [WalletConfig]
    
    // MARK: - State
    
    @AppStorage("showWalletIcons") private var showWalletIcons = false
    @State private var isPressed = false
    @State private var imageLoadFailed = false
    
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
            .accessibilityLabel("\(asset.formattedStampId), \(artistName), Balance: \(displayAsset.formattedBalance)")
            .accessibilityHint("Tap for details, hold for fullscreen")
            .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Row Content
    
    private var rowContent: some View {
        HStack(spacing: 16) {
            // Stamp image
            stampImage
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Stamp information
            VStack(alignment: .leading, spacing: 4) {
                // Stamp number
                Text(asset.formattedStampId)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                // Artist/Creator
                Text(artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                // Edition balance
                Text("Balance: \(displayAsset.formattedBalance)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Wallet icon (conditional)
            if showWalletIcons, displayAsset.walletAddress != nil {
                walletIcon
            }
        }
        .padding(12)
    }
    
    // MARK: - Stamp Image
    
    @ViewBuilder
    private var stampImage: some View {
        if imageLoadFailed {
            failedImageView
        } else if asset.isHTML || asset.isSVG {
            // Vector: HTML/SVG via WebView
            StampAssetVectorView(url: asset.imageURL, onFailure: { imageLoadFailed = true })
        } else if asset.isText {
            // Text: Plain text content
            StampAssetTextView(url: asset.imageURL, onFailure: { imageLoadFailed = true })
        } else if asset.isLibrary, let label = asset.libraryLabel {
            // Library: JS/CSS/GZIP files
            StampAssetLibraryView(label: label)
        } else if asset.isAudio || asset.isVideo {
            // Media: Audio/Video placeholders
            StampAssetMediaView(type: asset.isAudio ? .audio : .video)
        } else {
            // Raster: Pixel images (jpg, png, webp, gif)
            StampAssetPixelView(stamp: asset, geometry: CGSize(width: 64, height: 64), onFailure: { imageLoadFailed = true })
        }
    }
    
    // MARK: - Failed Image View
    
    private var failedImageView: some View {
        ZStack {
            Color(uiColor: .systemBackground)
            
            VStack(spacing: 4) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(appColorScheme.primary)
                
                Text("Failed")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
    }
    .padding()
}
