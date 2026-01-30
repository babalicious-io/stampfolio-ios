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
                } else if stamp.isText {
                    // Plain text stamp - fetch and display text
                    TextStampView(url: stamp.imageURL)
                        .frame(width: geometry.size.width, height: geometry.size.width)
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
                        .frame(width: geometry.size.width, height: geometry.size.width)
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
    
    // MARK: - Gradient Background
    
    private var gradientBackground: LinearGradient {
        LinearGradient.stampCardBackgroundGradient(for: colorScheme)
    }
    
    // MARK: - Audio Placeholder View
    
    private var audioPlaceholderView: some View {
        ZStack {
            gradientBackground
            
            Image(systemName: "waveform")
                .font(.system(size: 44))
                .foregroundStyle(.white)
        }
    }
    
    // MARK: - Video Placeholder View
    
    private var videoPlaceholderView: some View {
        ZStack {
            gradientBackground
            
            Image(systemName: "play.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white)
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
                .fontWeight(.regular)
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
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
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
        
        // Only load if URL changed and not already loading this URL
        guard context.coordinator.currentURL != url else { return }
        context.coordinator.currentURL = url
        
        // Fetch HTML, inject viewport, then load
        context.coordinator.loadWithViewport(webView: webView, url: url)
    }
    
    class Coordinator {
        var currentURL: URL?
        var currentTask: Task<Void, Never>?
        
        @MainActor
        func loadWithViewport(webView: WKWebView, url: URL) {
            // Cancel any previous fetch to prevent race conditions
            currentTask?.cancel()
            
            currentTask = Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    
                    // Verify URL still matches after async fetch (view may have been recycled)
                    guard !Task.isCancelled, currentURL == url else { return }
                    
                    guard var htmlString = String(data: data, encoding: .utf8) else {
                        // Fallback to direct load if not valid UTF-8
                        guard !Task.isCancelled, currentURL == url else { return }
                        webView.load(URLRequest(url: url))
                        return
                    }
                    
                    // Inject viewport meta tag at the beginning of the HTML
                    let viewportMeta = "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no\">"
                    
                    // Check if viewport already exists
                    if !htmlString.contains("name=\"viewport\"") && !htmlString.contains("name='viewport'") {
                        // Insert viewport after opening <head> tag, or at the very beginning
                        if let headRange = htmlString.range(of: "<head>", options: .caseInsensitive) {
                            htmlString.insert(contentsOf: viewportMeta, at: headRange.upperBound)
                        } else if let htmlRange = htmlString.range(of: "<html", options: .caseInsensitive) {
                            // Find the end of <html> tag and insert after
                            if let closeRange = htmlString[htmlRange.upperBound...].range(of: ">") {
                                htmlString.insert(contentsOf: "<head>\(viewportMeta)</head>", at: closeRange.upperBound)
                            }
                        } else {
                            // No proper HTML structure, prepend viewport
                            htmlString = viewportMeta + htmlString
                        }
                    }
                    
                    // Final check before loading
                    guard !Task.isCancelled, currentURL == url else { return }
                    webView.loadHTMLString(htmlString, baseURL: url)
                } catch {
                    // Fallback to direct load on error
                    guard !Task.isCancelled, currentURL == url else { return }
                    webView.load(URLRequest(url: url))
                }
            }
        }
    }
}

// MARK: - Text Stamp View

/// Text stamp view for grid - fetches and displays text content
struct TextStampView: View {
    let url: URL?
    @State private var content: String = ""
    @State private var isLoading = true
    @Environment(\.colorScheme) private var colorScheme
    
    private var gradientBackground: LinearGradient {
        LinearGradient.stampCardBackgroundGradient(for: colorScheme)
    }
    
    var body: some View {
        ZStack {
            gradientBackground
            
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                Text(content)
                    .font(.system(.caption2))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(8)
                    .padding(8)
            }
        }
        .task {
            await fetchContent()
        }
    }
    
    private func fetchContent() async {
        guard let url = url else {
            content = "No URL"
            isLoading = false
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let text = String(data: data, encoding: .utf8) {
                content = text
            } else {
                content = "Failed to decode"
            }
        } catch {
            content = "Failed to load"
        }
        
        isLoading = false
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
}
