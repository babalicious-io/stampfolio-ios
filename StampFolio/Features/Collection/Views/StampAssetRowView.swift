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
    
    let displayStamp: StampDisplay
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    // Convenience accessor
    private var stamp: StampAsset { displayStamp.asset }
    
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
            .accessibilityLabel("\(stamp.formattedStampId), \(artistName), Balance: \(displayStamp.formattedQuantity)")
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
                Text(stamp.formattedStampId)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                // Artist/Creator
                Text(artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                // Edition balance
                Text("Balance: \(displayStamp.formattedQuantity)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Wallet icon (conditional)
            if showWalletIcons, displayStamp.walletAddress != nil {
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
        } else if stamp.isHTML || stamp.isSVG {
            // Vector: HTML/SVG via WebView
            StampAssetVectorView(url: stamp.imageURL, onFailure: { imageLoadFailed = true })
        } else if stamp.isText {
            // Text: Plain text content
            StampAssetTextView(url: stamp.imageURL, onFailure: { imageLoadFailed = true })
        } else if stamp.isLibrary, let label = stamp.libraryLabel {
            // Library: JS/CSS/GZIP files
            StampAssetLibraryView(label: label)
        } else if stamp.isAudio || stamp.isVideo {
            // Media: Audio/Video placeholders
            StampAssetMediaView(type: stamp.isAudio ? .audio : .video)
        } else {
            // Raster: Pixel images (jpg, png, webp, gif)
            StampAssetPixelView(stamp: stamp, geometry: CGSize(width: 64, height: 64), onFailure: { imageLoadFailed = true })
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
        if let creatorName = stamp.creatorName {
            return creatorName
        } else {
            return stamp.creatorAddy.truncatedAddress(length: 6)
        }
    }
    
    // MARK: - Wallet Icon
    
    private var walletIcon: some View {
        let wallet = wallets.first { $0.address == displayStamp.walletAddress }
        let walletColor = wallet?.walletColor.color ?? .gray
        
        return Image(systemName: "wallet.bifold.fill")
            .font(.caption)
            .fontWeight(.regular)
            .foregroundStyle(walletColor)
            .padding(8)
            .background(
                Circle()
                    .fill(Color(uiColor: .systemBackground).opacity(0.5))
            )
            .accessibilityLabel("Wallet indicator")
            .accessibilityHint("Shows which wallet owns this stamp")
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        StampAssetRowView(
            displayStamp: StampDisplay(from: StampAsset.sample),
            onTap: {},
            onLongPress: {}
        )
        
        StampAssetRowView(
            displayStamp: StampDisplay(from: StampAsset.samples[1]),
            onTap: {},
            onLongPress: {}
        )
    }
    .padding()
}
