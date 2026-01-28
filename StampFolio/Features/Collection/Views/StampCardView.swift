//
//  StampCardView.swift
//  StampFolio
//
//  Individual stamp card for the collection grid
//

import SwiftUI
import Kingfisher
import WebKit

/// Card view displaying a stamp in the collection grid
struct StampCardView: View {
    
    // MARK: - Properties
    
    let displayStamp: DisplayStamp
    let onTap: () -> Void
    let onInfoTap: () -> Void
    
    // Convenience accessor
    private var stamp: Stamp { displayStamp.stamp }
    
    // MARK: - Environment
    
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - State
    
    @State private var isPressed = false
    @State private var imageLoadFailed = false
    
    // MARK: - Layout
    
    @ScaledMetric(relativeTo: .body) private var infoButtonSize: CGFloat = 24
    
    // MARK: - Body
    
    var body: some View {
        stampContent
            .glassCard(cornerRadius: 16, shadowRadius: 8)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .onTapGesture {
                onTap()
            }
            .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
                isPressed = pressing
            }, perform: {})
            .accessibilityElement(children: .combine)
            .accessibilityLabel(stamp.formattedNumber)
            .accessibilityHint("Double tap to view full screen")
            .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Stamp Content
    
    private var stampContent: some View {
        GeometryReader { geometry in
            ZStack {
                // Stamp image
                if imageLoadFailed {
                    failedImageView
                } else if stamp.isHTML || stamp.isSVG {
                    // Use WebView for HTML and SVG content
                    StampWebView(url: stamp.imageURL)
                        .frame(width: geometry.size.width, height: geometry.size.width)
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
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .clipped()
                } else {
                    // Use KFImage for regular images
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
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .clipped()
                }
                
                // Overlay: Edition count (bottom left) and Info button (bottom right)
                VStack {
                    Spacer()
                    
                    HStack(alignment: .bottom) {
                        // Edition count - bottom left
                        editionBadge
                        
                        Spacer()
                        
                        // Info button - bottom right
                        infoButton
                    }
                    .padding(12)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    // MARK: - Placeholder View
    
    private var placeholderView: some View {
        ZStack {
            Color(uiColor: .systemBackground)
            
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.title)
                    .foregroundStyle(.secondary)
                
                ProgressView()
                    .tint(.purple)
            }
        }
    }
    
    // MARK: - Failed Image View
    
    private var failedImageView: some View {
        ZStack {
            Color(uiColor: .systemBackground)
            
            VStack(spacing: 8) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.title)
                    .foregroundStyle(.orange)
                
                Text("Failed to load")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Button {
                    imageLoadFailed = false
                } label: {
                    Text("Retry")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                }
            }
        }
    }
    
    // MARK: - Edition Badge
    
    private var editionBadge: some View {
        Text(displayStamp.formattedQuantity)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Color(uiColor: .systemBackground).opacity(0.8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    // MARK: - Info Button
    
    private var infoButton: some View {
        Button {
            onInfoTap()
        } label: {
            Image(systemName: "info.circle.fill")
                .font(.system(size: infoButtonSize * 0.85))
                .foregroundStyle(
                    colorScheme == .dark 
                        ? Color.purple 
                        : Color.purple.opacity(0.85)
                )
                .background(
                    Circle()
                        .fill(Color(uiColor: .systemBackground).opacity(0.8))
                        .frame(width: infoButtonSize + 4, height: infoButtonSize + 4)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show stamp details")
        .accessibilityHint("Opens stamp metadata popup")
    }
}

// MARK: - Stamp WebView for HTML/SVG Content

struct StampWebView: UIViewRepresentable {
    let url: URL?
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        let backgroundColor = UIColor.systemBackground
        webView.backgroundColor = backgroundColor
        webView.scrollView.backgroundColor = backgroundColor
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false // Disable interaction in grid
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = url else { return }
        
        // Update background color for color scheme changes
        let backgroundColor = UIColor.systemBackground
        webView.backgroundColor = backgroundColor
        webView.scrollView.backgroundColor = backgroundColor
        
        // Only load if URL changed
        if webView.url != url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
}

// MARK: - Preview

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
        StampCardView(
            displayStamp: DisplayStamp(from: .sample),
            onTap: {},
            onInfoTap: {}
        )
        
        StampCardView(
            displayStamp: DisplayStamp(from: .samples[1]),
            onTap: {},
            onInfoTap: {}
        )
    }
    .padding()
    .stampchainBackground()
}
