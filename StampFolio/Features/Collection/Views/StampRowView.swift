//
//  StampRowView.swift
//  StampFolio
//
//  Row view displaying a stamp in list mode
//

import SwiftUI
import Kingfisher
import WebKit
import SwiftData

/// Row view displaying a stamp in the collection list
struct StampRowView: View {
    
    // MARK: - Properties
    
    let displayStamp: DisplayStamp
    let onTap: () -> Void
    let onInfoTap: () -> Void
    
    // Convenience accessor
    private var stamp: Stamp { displayStamp.stamp }
    
    // MARK: - Environment
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appColorScheme) private var appColorScheme
    @Query(sort: \Wallet.addedDate) private var wallets: [Wallet]
    
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
            .onTapGesture {
                onTap()
            }
            .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
                isPressed = pressing
            }, perform: {})
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(stamp.formattedNumber), \(artistName), Balance: \(displayStamp.formattedQuantity)")
            .accessibilityHint("Double tap to view full screen")
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
                Text(stamp.formattedNumber)
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
            
            // Action buttons
            HStack(spacing: 8) {
                // Wallet icon (conditional)
                if showWalletIcons, displayStamp.walletAddress != nil {
                    walletIcon
                }
                
                // Info button
                Button {
                    onInfoTap()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stamp metadata")
                .accessibilityHint("Opens stamp metadata popup")
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
            // Use WebView for HTML and SVG content
            StampWebView(url: stamp.imageURL)
        } else if stamp.isText {
            // Plain text stamp - fetch and display text
            TextStampView(url: stamp.imageURL)
        } else if stamp.isAudio {
            // Audio stamp - gradient placeholder with waveform
            audioPlaceholderView
        } else if stamp.isVideo {
            // Video stamp - gradient placeholder with play icon
            videoPlaceholderView
        } else if stamp.isAnimated {
            // Use KFAnimatedImage for GIFs
            KFAnimatedImage(stamp.imageURL)
                .placeholder {
                    placeholderView
                }
                .cacheOriginalImage()
                .onFailure { error in
                    print("GIF load failed for \(stamp.id): \(error.localizedDescription)")
                    imageLoadFailed = true
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 64, height: 64)
                .clipped()
        } else {
            // Use KFImage for regular images (jpg, png, webp) + SRC-721/cursed stamps
            KFImage(stamp.imageURL)
                .placeholder {
                    placeholderView
                }
                .retry(maxCount: 3, interval: .seconds(1))
                .fade(duration: 0.3)
                .cacheOriginalImage()
                .onSuccess { _ in
                    imageLoadFailed = false
                }
                .onFailure { error in
                    print("Image load failed for \(stamp.id): \(error.localizedDescription)")
                    print("URL: \(stamp.stampUrl)")
                    imageLoadFailed = true
                }
                .resizable()
                .interpolation(.none) // Prevents pixelation for small/pixel art stamps
                .aspectRatio(contentMode: .fill)
                .frame(width: 64, height: 64)
                .clipped()
        }
    }
    
    // MARK: - Placeholder View
    
    private var placeholderView: some View {
        ZStack {
            Color(uiColor: .systemBackground)
            
            VStack(spacing: 4) {
                Image(systemName: "photo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                ProgressView()
                    .tint(appColorScheme.primary)
                    .scaleEffect(0.7)
            }
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
    
    // MARK: - Gradient Background
    
    private var gradientBackground: LinearGradient {
        LinearGradient.stampCardBackground(color: appColorScheme.primary)
    }
    
    // MARK: - Audio Placeholder View
    
    private var audioPlaceholderView: some View {
        ZStack {
            gradientBackground
            
            Image(systemName: "waveform")
                .font(.title3)
                .foregroundStyle(.white)
        }
    }
    
    // MARK: - Video Placeholder View
    
    private var videoPlaceholderView: some View {
        ZStack {
            gradientBackground
            
            Image(systemName: "play.fill")
                .font(.title3)
                .foregroundStyle(.white)
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
        StampRowView(
            displayStamp: DisplayStamp(from: .sample),
            onTap: {},
            onInfoTap: {}
        )
        
        StampRowView(
            displayStamp: DisplayStamp(from: .samples[1]),
            onTap: {},
            onInfoTap: {}
        )
    }
    .padding()
}
