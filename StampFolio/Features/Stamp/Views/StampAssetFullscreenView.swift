//
//  StampAssetFullscreenView.swift
//  StampFolio
//
//  Full-screen immersive stamp viewer (content only, no UI)
//

import SwiftUI
import Kingfisher
import WebKit
import AVKit
import AVFoundation

/// Full-screen stamp detail view for immersive viewing
struct StampAssetFullscreenView: View {
    
    // MARK: - Properties
    
    let assets: [StampAsset]
    let initialIndex: Int
    let isSlideshow: Bool
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appColorScheme) private var appColorScheme
    
    // MARK: - State
    
    @State private var currentIndex: Int
    @AppStorage("slideshowInterval") private var slideshowInterval = 5
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero
    @State private var horizontalDragOffset: CGSize = .zero
    
    // MARK: - Computed Properties
    
    private var currentAsset: StampAsset {
        assets[currentIndex]
    }
    
    private let swipeThreshold: CGFloat = 100
    
    // MARK: - Initialization
    
    init(assets: [StampAsset], initialIndex: Int, isSlideshow: Bool = false) {
        self.assets = assets
        self.initialIndex = initialIndex
        self.isSlideshow = isSlideshow
        _currentIndex = State(initialValue: initialIndex)
    }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark background for immersive viewing
                Color.black
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Tap background to dismiss
                        dismiss()
                    }
                
                // Content based on type
                ZStack {
                    contentView
                        .scaleEffect(scale)
                        .offset(offset)
                        .offset(y: dragOffset.height)
                        .offset(x: horizontalDragOffset.width)
                        .opacity(1.0 - Double(abs(dragOffset.height)) / 500.0)
                    
                    // Invisible overlay to capture gestures (especially for GIFs)
                    Color.clear
                        .contentShape(Rectangle())
                }
                .gesture(magnificationGesture)
                .gesture(unifiedDragGesture)
                .onTapGesture(count: 2) {
                    // Double tap to reset zoom
                    withAnimation(.spring(response: 0.3)) {
                        scale = 1.0
                        offset = .zero
                    }
                }
            }
        }
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
        .statusBarHidden(true)
        .task(id: isSlideshow ? currentIndex : -1) {
            guard isSlideshow, !assets.isEmpty else { return }
            try? await Task.sleep(for: .seconds(slideshowInterval))
            guard !Task.isCancelled else { return }
            navigateToNextSlideshow()
        }
        .accessibilityAddTraits(.isImage)
        .accessibilityLabel("\(currentAsset.formattedStampId), \(currentIndex + 1) of \(assets.count)")
        .accessibilityHint("Swipe left for next, right for previous, down to close, double tap to zoom")
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        if currentAsset.isText {
            // Plain text content
            TextContentView(url: currentAsset.imageURL)
        } else if currentAsset.isAudio {
            // Audio content
            AudioContentView(url: currentAsset.imageURL)
        } else if currentAsset.isVideo {
            // Video content
            VideoContentView(url: currentAsset.imageURL)
        } else if currentAsset.isSVG || currentAsset.isHTML {
            // WebView for SVG/HTML content
            WebContentView(url: currentAsset.imageURL)
        } else if currentAsset.isGIF {
            // KFAnimatedImage for animated GIFs - full resolution (no downsampling)
            KFAnimatedImage(currentAsset.imageURL)
                .placeholder {
                    ProgressView()
                        .tint(appColorScheme.primary)
                }
                .loadDiskFileSynchronously()
                .cacheOriginalImage()
                .diskCacheExpiration(.never)
                .aspectRatio(contentMode: .fit)
                .allowsHitTesting(false)
        } else {
            // KFImage for static images (jpg, png, webp) - full resolution (no downsampling)
            KFImage(currentAsset.imageURL)
                .placeholder {
                    ProgressView()
                        .tint(appColorScheme.primary)
                }
                .loadDiskFileSynchronously()
                .retry(maxCount: 3)
                .cacheOriginalImage()
                .diskCacheExpiration(.never)
                .resizable()
                .interpolation(.none) // Prevents pixelation for small/pixel art stamps
                .aspectRatio(contentMode: .fit)
        }
    }
    
    // MARK: - Gestures
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                scale = min(max(newScale, 1.0), 5.0)
            }
            .onEnded { _ in
                lastScale = scale
                
                // Reset if zoomed out too much
                if scale < 1.0 {
                    withAnimation(.spring(response: 0.3)) {
                        scale = 1.0
                        lastScale = 1.0
                    }
                }
            }
    }
    
    // Unified drag gesture - handles pan when zoomed, navigation and dismiss when not zoomed
    private var unifiedDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1.0 {
                    // Pan when zoomed in
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                } else {
                    // Determine drag direction when not zoomed
                    let horizontalAmount = abs(value.translation.width)
                    let verticalAmount = abs(value.translation.height)
                    
                    if horizontalAmount > verticalAmount {
                        // Horizontal drag - navigation
                        horizontalDragOffset = CGSize(width: value.translation.width, height: 0)
                        dragOffset = .zero
                    } else {
                        // Vertical drag - dismiss
                        dragOffset = CGSize(width: 0, height: value.translation.height)
                        horizontalDragOffset = .zero
                    }
                }
            }
            .onEnded { value in
                if scale > 1.0 {
                    // Save pan offset when zoomed
                    lastOffset = offset
                } else {
                    // Determine drag direction when not zoomed
                    let horizontalAmount = abs(value.translation.width)
                    let verticalAmount = abs(value.translation.height)
                    
                    if horizontalAmount > verticalAmount {
                        // Horizontal swipe - navigation
                        let swipeDistance = value.translation.width
                        let swipeVelocity = value.velocity.width
                        
                        // Swipe left (next stamp)
                        if swipeDistance < -swipeThreshold || swipeVelocity < -500 {
                            navigateToNext()
                        }
                        // Swipe right (previous stamp)
                        else if swipeDistance > swipeThreshold || swipeVelocity > 500 {
                            navigateToPrevious()
                        }
                        else {
                            // Snap back
                            withAnimation(.spring(response: 0.3)) {
                                horizontalDragOffset = .zero
                            }
                        }
                    } else {
                        // Vertical swipe - dismiss
                        if abs(value.translation.height) > 100 || abs(value.velocity.height) > 500 {
                            dismiss()
                        } else {
                            // Snap back
                            withAnimation(.spring(response: 0.3)) {
                                dragOffset = .zero
                            }
                        }
                    }
                }
            }
    }
    
    // MARK: - Navigation Methods
    
    private func navigateToNext() {
        guard currentIndex < assets.count - 1 else {
            withAnimation(.spring(response: 0.3)) {
                horizontalDragOffset = .zero
            }
            return
        }
        
        withAnimation(.spring(response: 0.3)) {
            currentIndex += 1
            horizontalDragOffset = .zero
            resetZoom()
        }
    }
    
    private func navigateToPrevious() {
        guard currentIndex > 0 else {
            withAnimation(.spring(response: 0.3)) {
                horizontalDragOffset = .zero
            }
            return
        }
        
        withAnimation(.spring(response: 0.3)) {
            currentIndex -= 1
            horizontalDragOffset = .zero
            resetZoom()
        }
    }
    
    private func navigateToNextSlideshow() {
        withAnimation(.spring(response: 0.3)) {
            currentIndex = currentIndex < assets.count - 1 ? currentIndex + 1 : 0
            horizontalDragOffset = .zero
            resetZoom()
        }
    }
    
    private func resetZoom() {
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
    }
}

// MARK: - Web Content View

/// WebView wrapper for SVG and HTML content with StampContentCache support
struct WebContentView: UIViewRepresentable {
    let url: URL?
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = url else { return }
        guard context.coordinator.currentURL != url else { return }
        context.coordinator.currentURL = url
        context.coordinator.loadContent(webView: webView, url: url)
    }
    
    class Coordinator {
        var currentURL: URL?
        var currentTask: Task<Void, Never>?
        
        @MainActor
        func loadContent(webView: WKWebView, url: URL) {
            currentTask?.cancel()
            
            currentTask = Task {
                // Check StampContentCache first (processed HTML with viewport)
                if let cachedHTML = await StampContentCache.shared.read(for: url) {
                    guard !Task.isCancelled, currentURL == url else { return }
                    webView.loadHTMLString(cachedHTML, baseURL: url)
                    return
                }
                
                // Cache miss - load directly from network
                guard !Task.isCancelled, currentURL == url else { return }
                webView.load(URLRequest(url: url))
            }
        }
    }
}

// MARK: - Text Content View

/// Centered, non-scrollable text content view
struct TextContentView: View {
    let url: URL?
    @State private var content: String = ""
    @State private var isLoading = true
    @Environment(\.appColorScheme) private var appColorScheme
    
    private var gradientBackground: LinearGradient {
        LinearGradient.fullscreenBackground(color: appColorScheme.primary)
    }
    
    var body: some View {
        ZStack {
            gradientBackground
            
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            } else {
                Text(content)
                    .font(.system(.body))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
        .task { await fetchContent() }
    }
    
    private func fetchContent() async {
        guard let url = url else {
            content = "No URL"
            isLoading = false
            return
        }
        
        // Check StampContentCache first
        if let cachedText = await StampContentCache.shared.read(for: url) {
            content = cachedText
            isLoading = false
            return
        }
        
        // Cache miss - fetch from network, cache, then display
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let text = String(data: data, encoding: .utf8) {
                await StampContentCache.shared.write(text, for: url)
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

// MARK: - Audio Content View

/// Audio player with waveform icon and play/pause button (no progress bar)
struct AudioContentView: View {
    let url: URL?
    @State private var isPlaying = false
    @State private var player: AVPlayer?
    @Environment(\.appColorScheme) private var appColorScheme
    
    private var gradientBackground: LinearGradient {
        LinearGradient.fullscreenBackground(color: appColorScheme.primary)
    }
    
    var body: some View {
        ZStack {
            gradientBackground
            
            VStack(spacing: 32) {
                Image(systemName: "waveform")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
                
                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.white)
                }
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
        }
    }
    
    private func setupPlayer() {
        guard let url = url else { return }
        player = AVPlayer(url: url)
        
        // Observe when playback ends
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { _ in
            isPlaying = false
            player?.seek(to: .zero)
        }
    }
    
    private func togglePlayback() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
}

// MARK: - Video Content View

/// Video player using AVKit
struct VideoContentView: View {
    let url: URL?
    @State private var player: AVPlayer?
    @Environment(\.appColorScheme) private var appColorScheme
    
    private var gradientBackground: LinearGradient {
        LinearGradient.fullscreenBackground(color: appColorScheme.primary)
    }
    
    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
            } else {
                // Gradient placeholder while loading
                gradientBackground
                
                Image(systemName: "play.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
            }
        }
        .onAppear {
            if let url = url {
                player = AVPlayer(url: url)
            }
        }
        .onDisappear {
            player?.pause()
        }
    }
}

// MARK: - Preview

#Preview {
    StampAssetFullscreenView(assets: [StampAsset.sample], initialIndex: 0)
}
