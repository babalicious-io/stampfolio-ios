//
//  StampCardView.swift
//  StampFolio
//
//  Individual stamp card for the collection grid
//

import SwiftUI
import Kingfisher
import WebKit
import SwiftData

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
    @Query(sort: \Wallet.addedDate) private var wallets: [Wallet]
    
    // MARK: - State
    
    @AppStorage("showWalletIcons") private var showWalletIcons = false
    @State private var isPressed = false
    @State private var imageLoadFailed = false
    
    // MARK: - Body
    
    var body: some View {
        stampContent
            .glassEffect(in: .rect(cornerRadius: 24))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
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
                
                // Overlay: Wallet icon (top right), Stamp number (bottom left) and Edition balance (bottom right)
                VStack {
                    // Wallet icon - top right
                    if showWalletIcons, displayStamp.walletAddress != nil {
                        HStack {
                            Spacer()
                            walletIcon
                        }
                        .padding(12)
                    }
                    
                    Spacer()
                    
                    HStack(alignment: .bottom) {
                        // Stamp number - bottom left
                        stampNumber
                        
                        Spacer()
                        
                        // Edition balance - bottom right
                        stampEditions
                    }
                    .padding(12)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 24))
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
    
    // MARK: - Stamp Number Pill
    
    private var stampNumber: some View {
        Button {
            onInfoTap()
        } label: {
            Text("#\(stamp.id)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color(uiColor: .systemBackground).opacity(0.85))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stamp number \(stamp.id)")
        .accessibilityHint("Opens stamp metadata popup")
    }
    
    // MARK: - Stamp Editions Pill
    
    private var stampEditions: some View {
        Button {
            onInfoTap()
        } label: {
            Text(displayStamp.formattedQuantity)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color(uiColor: .systemBackground).opacity(0.85))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Editions: \(displayStamp.formattedQuantity)")
        .accessibilityHint("Opens stamp metadata popup")
    }
    
    // MARK: - Wallet Icon Pill
    
    private var walletIcon: some View {
        let wallet = wallets.first { $0.address == displayStamp.walletAddress }
        let walletColor = wallet?.walletColor.color ?? .gray
        
        return Button {
            onInfoTap()
        } label: {
            Image(systemName: "wallet.bifold.fill")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(walletColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color(uiColor: .systemBackground).opacity(0.85))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Wallet indicator")
        .accessibilityHint("Shows which wallet owns this stamp")
    }
}

// MARK: - Stamp WebView for HTML/SVG Content

struct StampWebView: UIViewRepresentable {
    let url: URL?
    
    // Shared process pool for all stamp WebViews - improves caching consistency
    // and reduces memory usage when displaying multiple HTML stamps
    private static let sharedProcessPool = WKProcessPool()
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.processPool = Self.sharedProcessPool
        
        // Use default persistent data store for caching (fonts, CSS, etc.)
        config.websiteDataStore = .default()
        
        // Only add viewport meta if one doesn't exist (many HTML stamps already have one)
        // This prevents duplicate viewport tags which can cause rendering issues
        let viewportScript = """
        if (!document.querySelector('meta[name="viewport"]')) {
            var meta = document.createElement('meta');
            meta.name = 'viewport';
            meta.content = 'width=device-width, initial-scale=1.0';
            document.getElementsByTagName('head')[0].appendChild(meta);
        }
        """
        let userScript = WKUserScript(
            source: viewportScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(userScript)
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        let backgroundColor = UIColor.systemBackground
        webView.backgroundColor = backgroundColor
        
        // Configure scrollView to prevent zoom/shrink behavior
        let scrollView = webView.scrollView
        scrollView.backgroundColor = backgroundColor
        scrollView.isScrollEnabled = false
        scrollView.bounces = false
        scrollView.bouncesZoom = false
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 1.0
        scrollView.zoomScale = 1.0
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = context.coordinator // Prevent zoom changes
        
        webView.isUserInteractionEnabled = false // Disable interaction in grid
        
        // Lock page zoom (iOS 14+)
        webView.pageZoom = 1.0
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = url else { return }
        
        // Update background color for color scheme changes
        let backgroundColor = UIColor.systemBackground
        webView.backgroundColor = backgroundColor
        webView.scrollView.backgroundColor = backgroundColor
        
        // Ensure zoom stays locked
        webView.scrollView.zoomScale = 1.0
        webView.pageZoom = 1.0
        
        // Track loaded URL in coordinator to prevent unnecessary reloads
        // webView.url can be nil or different during loading, causing race conditions
        if context.coordinator.loadedURL != url {
            context.coordinator.loadedURL = url
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
            webView.load(request)
        }
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var loadedURL: URL?
        
        // Prevent any zooming by returning nil
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return nil
        }
        
        // Force reset zoom if it changes
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            if scrollView.zoomScale != 1.0 {
                scrollView.zoomScale = 1.0
            }
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
