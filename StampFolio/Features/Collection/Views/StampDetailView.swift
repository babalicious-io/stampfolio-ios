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
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark background for immersive viewing
                Color.black
                    .ignoresSafeArea()
                
                // Content based on type
                contentView
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(magnificationGesture)
                    .gesture(dragGesture)
                    .onTapGesture(count: 2) {
                        // Double tap to reset zoom
                        withAnimation(.spring(response: 0.3)) {
                            scale = 1.0
                            offset = .zero
                        }
                    }
                    .onTapGesture(count: 1) {
                        // Single tap to dismiss
                        dismiss()
                    }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .accessibilityAddTraits(.isImage)
        .accessibilityLabel(stamp.formattedNumber)
        .accessibilityHint("Double tap to zoom, tap to close")
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        if stamp.isSVG || stamp.isHTML {
            // WebView for SVG/HTML content
            WebContentView(url: stamp.imageURL)
        } else {
            // Kingfisher for images (including GIF)
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
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Only allow dragging when zoomed in
                guard scale > 1.0 else { return }
                
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { value in
                lastOffset = offset
                
                // Reset offset if zoomed back to 1.0
                if scale <= 1.0 {
                    withAnimation(.spring(response: 0.3)) {
                        offset = .zero
                        lastOffset = .zero
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
