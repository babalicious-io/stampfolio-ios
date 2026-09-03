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
    
    // MARK: - State
    
    @State private var currentIndex: Int
    @AppStorage("slideshowInterval") private var slideshowInterval = 5
    @State private var gestureState = ZoomPanNavigationState()
    
    // MARK: - Computed Properties
    
    private var currentAsset: StampAsset {
        assets[currentIndex]
    }
    
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
                    StampAssetFullscreenContent(asset: currentAsset)
                        .scaleEffect(gestureState.scale)
                        .offset(gestureState.offset)
                        .offset(y: gestureState.dragOffset.height)
                        .offset(x: gestureState.horizontalDragOffset.width)
                        .opacity(1.0 - Double(abs(gestureState.dragOffset.height)) / 500.0)
                    
                    // Invisible overlay to capture gestures (especially for GIFs)
                    Color.clear
                        .contentShape(Rectangle())
                }
                .gesture(gestureState.magnificationGesture())
                .gesture(unifiedDragGesture)
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.3)) {
                        gestureState.toggleZoom()
                    }
                }
            }
        }
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
        .statusBarHidden(true)
        .task(id: isSlideshow ? currentIndex : -1) {
            guard isSlideshow, assets.count > 1 else { return }
            try? await Task.sleep(for: .seconds(slideshowInterval))
            guard !Task.isCancelled else { return }
            navigateToNextSlideshow()
        }
        .accessibilityAddTraits(.isImage)
        .accessibilityLabel("\(currentAsset.formattedStampId), \(currentIndex + 1) of \(assets.count)")
        .accessibilityHint("Swipe left for next, right for previous, down to close, double tap to zoom")
    }
    
    // MARK: - Gestures
    
    // Unified drag gesture - handles pan when zoomed, navigation and dismiss when not zoomed
    private var unifiedDragGesture: some Gesture {
        gestureState.dragGesture(
            onNavigateNext: navigateToNext,
            onNavigatePrevious: navigateToPrevious,
            onDismiss: { dismiss() }
        )
    }
    
    // MARK: - Navigation Methods
    
    private func navigateToNext() {
        guard currentIndex < assets.count - 1 else {
            withAnimation(.spring(response: 0.3)) {
                gestureState.horizontalDragOffset = .zero
            }
            return
        }
        
        withAnimation(.spring(response: 0.3)) {
            currentIndex += 1
            gestureState.horizontalDragOffset = .zero
            gestureState.resetZoom()
        }
    }
    
    private func navigateToPrevious() {
        guard currentIndex > 0 else {
            withAnimation(.spring(response: 0.3)) {
                gestureState.horizontalDragOffset = .zero
            }
            return
        }
        
        withAnimation(.spring(response: 0.3)) {
            currentIndex -= 1
            gestureState.horizontalDragOffset = .zero
            gestureState.resetZoom()
        }
    }
    
    private func navigateToNextSlideshow() {
        withAnimation(.spring(response: 0.3)) {
            currentIndex = currentIndex < assets.count - 1 ? currentIndex + 1 : 0
            gestureState.horizontalDragOffset = .zero
            gestureState.resetZoom()
        }
    }
}

// MARK: - Stamp Fullscreen Content

/// Renders a stamp's media for immersive fullscreen (shared by browsing and slideshow)
struct StampAssetFullscreenContent: View {
    let asset: StampAsset

    @Environment(\.appColorScheme) private var appColorScheme

    var body: some View {
        Group {
            if asset.isText {
                TextContentView(url: asset.imageURL)
            } else if asset.isAudio {
                AudioContentView(url: asset.imageURL)
            } else if asset.isVideo {
                VideoContentView(url: asset.imageURL)
            } else if asset.isSVG || asset.isHTML {
                WebContentView(url: asset.imageURL)
            } else if asset.isGIF {
                KFAnimatedImage(asset.imageURL)
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
                KFImage(asset.imageURL)
                    .placeholder {
                        ProgressView()
                            .tint(appColorScheme.primary)
                    }
                    .loadDiskFileSynchronously()
                    .retry(maxCount: 3)
                    .cacheOriginalImage()
                    .diskCacheExpiration(.never)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
