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
    
    let stamp: Stamp
    let onTap: () -> Void
    let onInfoTap: () -> Void
    
    // MARK: - Environment
    
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - State
    
    @State private var isPressed = false
    @State private var imageLoadFailed = false
    
    // MARK: - Layout
    
    @ScaledMetric(relativeTo: .body) private var infoButtonSize: CGFloat = 24
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Stamp Image
            stampContent
            
            // Footer with stamp number and info button
            footer
        }
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
            if imageLoadFailed {
                failedImageView
            } else if stamp.isHTML || stamp.isSVG {
                // Use WebView for HTML and SVG content
                StampWebView(url: stamp.imageURL)
                    .frame(width: geometry.size.width, height: geometry.size.width)
            } else {
                // Use Kingfisher for regular images
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
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .clipped()
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    // MARK: - Placeholder View
    
    private var placeholderView: some View {
        ZStack {
            Color.stampchainBackground
            
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.title)
                    .foregroundStyle(Color.stampchainGrey)
                
                ProgressView()
                    .tint(Color.stampchainPurple)
            }
        }
    }
    
    // MARK: - Failed Image View
    
    private var failedImageView: some View {
        ZStack {
            Color.stampchainBackground
            
            VStack(spacing: 8) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.title)
                    .foregroundStyle(Color.stampchainOrange)
                
                Text("Failed to load")
                    .font(.caption2)
                    .foregroundStyle(Color.stampchainGrey)
                
                Button {
                    imageLoadFailed = false
                } label: {
                    Text("Retry")
                        .font(.caption2)
                        .foregroundStyle(Color.stampchainPurple)
                }
            }
        }
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack {
            // Stamp number
            Text(stamp.formattedNumber)
                .font(.cardTitle)
                .foregroundStyle(Color.primaryText(for: colorScheme))
                .lineLimit(1)
            
            Spacer()
            
            // Info button
            Button {
                onInfoTap()
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: infoButtonSize * 0.75))
                    .foregroundStyle(Color.stampchainPurple)
                    .frame(width: infoButtonSize, height: infoButtonSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show stamp details")
            .accessibilityHint("Opens stamp metadata popup")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.stampchainBackground.opacity(0.5))
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
        webView.backgroundColor = UIColor(Color.stampchainBackground)
        webView.scrollView.backgroundColor = UIColor(Color.stampchainBackground)
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false // Disable interaction in grid
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = url else { return }
        
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
            stamp: .sample,
            onTap: {},
            onInfoTap: {}
        )
        
        StampCardView(
            stamp: .samples[1],
            onTap: {},
            onInfoTap: {}
        )
    }
    .padding()
    .stampchainBackground()
}
