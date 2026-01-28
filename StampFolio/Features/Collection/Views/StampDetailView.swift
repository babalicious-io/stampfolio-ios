//
//  StampDetailView.swift
//  StampFolio
//
//  Full-screen immersive stamp viewer (content only, no UI)
//

import SwiftUI
import Kingfisher
import WebKit

/// Full-screen stamp detail view for immersive viewing
struct StampDetailView: View {
    
    // MARK: - Properties
    
    let stamps: [Stamp]
    let initialIndex: Int
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var currentIndex: Int
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero
    @State private var horizontalDragOffset: CGSize = .zero
    
    // MARK: - Computed Properties
    
    private var currentStamp: Stamp {
        stamps[currentIndex]
    }
    
    private let swipeThreshold: CGFloat = 100
    
    // MARK: - Initialization
    
    init(stamps: [Stamp], initialIndex: Int) {
        self.stamps = stamps
        self.initialIndex = initialIndex
        _currentIndex = State(initialValue: initialIndex)
    }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark background for immersive viewing
                Color.black
                    .ignoresSafeArea(.all, edges: .all)
                    .onTapGesture {
                        // Tap background to dismiss
                        dismiss()
                    }
                
                // Content based on type
                contentView
                    .scaleEffect(scale)
                    .offset(offset)
                    .offset(y: dragOffset.height)
                    .offset(x: horizontalDragOffset.width)
                    .opacity(1.0 - Double(abs(dragOffset.height)) / 500.0)
                    .gesture(magnificationGesture)
                    .gesture(combinedDragGesture)
                    .gesture(horizontalSwipeGesture)
                    .onTapGesture(count: 2) {
                        // Double tap to reset zoom
                        withAnimation(.spring(response: 0.3)) {
                            scale = 1.0
                            offset = .zero
                        }
                    }
            }
        }
        .ignoresSafeArea(.all, edges: .all)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .accessibilityAddTraits(.isImage)
        .accessibilityLabel("\(currentStamp.formattedNumber), \(currentIndex + 1) of \(stamps.count)")
        .accessibilityHint("Swipe left for next, right for previous, down to close, double tap to zoom")
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        if currentStamp.isSVG || currentStamp.isHTML {
            // WebView for SVG/HTML content
            WebContentView(url: currentStamp.imageURL)
        } else if currentStamp.isAnimated {
            // KFAnimatedImage for animated GIFs
            KFAnimatedImage(currentStamp.imageURL)
                .placeholder {
                    ProgressView()
                        .tint(.purple)
                }
                .cacheOriginalImage()
                .aspectRatio(contentMode: .fit)
        } else {
            // KFImage for static images
            KFImage(currentStamp.imageURL)
                .placeholder {
                    ProgressView()
                        .tint(.purple)
                }
                .retry(maxCount: 3)
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
    
    // Combined drag gesture - pans when zoomed, dismisses when at normal scale
    private var combinedDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1.0 {
                    // Pan when zoomed in
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                } else {
                    // Only vertical drag for dismiss
                    dragOffset = CGSize(width: 0, height: value.translation.height)
                }
            }
            .onEnded { value in
                if scale > 1.0 {
                    // Save pan offset
                    lastOffset = offset
                } else {
                    // Dismiss if dragged down far enough
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
    
    // Horizontal swipe gesture for navigation
    private var horizontalSwipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Only handle horizontal swipes when not zoomed
                if scale <= 1.0 {
                    horizontalDragOffset = CGSize(width: value.translation.width, height: 0)
                }
            }
            .onEnded { value in
                if scale <= 1.0 {
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
                }
            }
    }
    
    // MARK: - Navigation Methods
    
    private func navigateToNext() {
        guard currentIndex < stamps.count - 1 else {
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
    
    private func resetZoom() {
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
    }
}

// MARK: - Web Content View

/// WebView wrapper for SVG and HTML content
struct WebContentView: UIViewRepresentable {
    let url: URL?
    
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
        let request = URLRequest(url: url)
        webView.load(request)
    }
}

// MARK: - Preview

#Preview {
    StampDetailView(stamps: [.sample], initialIndex: 0)
}
