//
//  StampCardView.swift
//  StampFolio
//
//  Individual stamp card for the collection grid
//

import SwiftUI
import SwiftData

/// Card view displaying a stamp in the collection grid
struct StampCardView: View {
    
    // MARK: - Properties
    
    let displayStamp: StampDataDisplay
    let onTap: () -> Void
    let onLongPress: () -> Void
    let viewMode: ViewMode
    
    // Convenience accessor
    private var stamp: StampData { displayStamp.stamp }
    
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
            .accessibilityLabel(stamp.formattedStampId)
            .accessibilityHint("Tap for details, hold for fullscreen")
            .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Stamp Content
    
    private var stampContent: some View {
        GeometryReader { geometry in
            ZStack {
                // Stamp image routing
                if imageLoadFailed {
                    failedImageView
                } else if stamp.isHTML || stamp.isSVG {
                    // Vector: HTML/SVG via WebView
                    StampVectorView(url: stamp.imageURL, onFailure: { imageLoadFailed = true })
                        .frame(width: geometry.size.width, height: geometry.size.width)
                } else if stamp.isText {
                    // Text: Plain text content
                    StampTextView(url: stamp.imageURL, onFailure: { imageLoadFailed = true })
                        .frame(width: geometry.size.width, height: geometry.size.width)
                } else if stamp.isLibrary, let label = stamp.libraryLabel {
                    // Library: JS/CSS/GZIP files
                    StampLibraryView(label: label)
                } else if stamp.isAudio || stamp.isVideo {
                    // Media: Audio/Video placeholders
                    StampMediaView(type: stamp.isAudio ? .audio : .video)
                } else {
                    // Raster: Pixel images (jpg, png, webp, gif)
                    StampPixelView(stamp: stamp, geometry: geometry.size, onFailure: { imageLoadFailed = true })
                }
                
                // Overlay: Stamp number (top left), wallet icon (top right) and Edition balance (bottom right)
                // Hidden in dense grid mode for cleaner appearance
                if viewMode != .denseGrid {
                    VStack {
                        HStack(alignment: .top) {
                            // Stamp number - top left
                            stampNumber
                            
                            Spacer()
                            
                            // Wallet icon - top right
                            if showWalletIcons, displayStamp.walletAddress != nil {
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
    
    // MARK: - Failed Image View
    
    private var failedImageView: some View {
        ZStack {
            Color(uiColor: .systemBackground)
            
            VStack(spacing: 8) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.title)
                    .foregroundStyle(appColorScheme.primary)
                
                Text("Failed to load")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Button {
                    imageLoadFailed = false
                } label: {
                    Text("Retry")
                        .font(.caption2)
                        .foregroundStyle(appColorScheme.primary)
                }
            }
        }
    }
    
    // MARK: - Stamp Number Pill
    
    private var stampNumber: some View {
        Text("#\(stamp.id)")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(uiColor: .systemBackground).opacity(0.85))
            )
            .accessibilityLabel("Stamp number \(stamp.id)")
    }
    
    // MARK: - Stamp Editions Pill
    
    private var stampEditions: some View {
        Text(displayStamp.formattedBalanceWithSupply)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(appColorScheme.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(uiColor: .systemBackground).opacity(0.85))
            )
            .accessibilityLabel("Balance: \(displayStamp.formattedBalanceWithSupply)")
    }
    
    // MARK: - Wallet Icon Pill
    
    private var walletIcon: some View {
        let wallet = wallets.first { $0.address == displayStamp.walletAddress }
        let walletColor = wallet?.walletColor.color ?? .gray
        
        return Image(systemName: "wallet.bifold.fill")
            .font(.caption)
            .fontWeight(.regular)
            .foregroundStyle(walletColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(uiColor: .systemBackground).opacity(0.85))
            )
            .accessibilityLabel("Wallet indicator")
    }
}

// MARK: - Preview

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
        StampCardView(
            displayStamp: StampDataDisplay(from: StampData.sample),
            onTap: {},
            onLongPress: {},
            viewMode: .normalGrid
        )
        
        StampCardView(
            displayStamp: StampDataDisplay(from: StampData.samples[1]),
            onTap: {},
            onLongPress: {},
            viewMode: .normalGrid
        )
    }
    .padding()
}
