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
    
    let stamp: Stamp
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero
    
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
                contentView
                    .scaleEffect(scale)
                    .offset(offset)
                    .offset(y: dragOffset.height)
                    .opacity(1.0 - Double(abs(dragOffset.height)) / 500.0)
                    .gesture(magnificationGesture)
                    .gesture(combinedDragGesture)
                    .onTapGesture(count: 2) {
                        // Double tap to reset zoom
                        withAnimation(.spring(response: 0.3)) {
                            scale = 1.0
                            offset = .zero
                        }
                    }
                
                // Close button overlay (always visible)
                VStack {
                    HStack {
                        Spacer()
                        
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white.opacity(0.8))
                                .background(Color.black.opacity(0.3))
                                .clipShape(Circle())
                        }
                        .padding(.top, 50)
                        .padding(.trailing, 20)
                        .accessibilityLabel("Close")
                    }
                    
                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .accessibilityAddTraits(.isImage)
        .accessibilityLabel(stamp.formattedNumber)
        .accessibilityHint("Swipe down or tap X to close, double tap to zoom")
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        if stamp.isSVG || stamp.isHTML {
            // WebView for SVG/HTML content
            WebContentView(url: stamp.imageURL)
        } else if stamp.isAnimated {
            // KFAnimatedImage for animated GIFs
            KFAnimatedImage(stamp.imageURL)
                .placeholder {
                    ProgressView()
                        .tint(Color.stampchainPurple)
                }
                .cacheOriginalImage()
                .aspectRatio(contentMode: .fit)
        } else {
            // KFImage for static images
            KFImage(stamp.imageURL)
                .placeholder {
                    ProgressView()
                        .tint(Color.stampchainPurple)
                }
                .retry(maxCount: 3)
                .resizable()
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
                    // Dismiss drag when at normal scale
                    dragOffset = CGSize(width: 0, height: value.translation.height)
                }
            }
            .onEnded { value in
                if scale > 1.0 {
                    // Save pan offset
                    lastOffset = offset
                } else {
                    // Dismiss if dragged far enough
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
    StampDetailView(stamp: .sample)
}
