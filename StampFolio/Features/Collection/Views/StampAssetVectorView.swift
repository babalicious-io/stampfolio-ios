//
//  StampAssetVectorView.swift
//  StampFolio
//
//  Renders vector-based stamp content (HTML, SVG)
//

import SwiftUI
import WebKit

/// SwiftUI wrapper that overlays a loading spinner on the WKWebView
/// until the HTML content finishes rendering.
struct StampAssetVectorView: View {
    
    let url: URL?
    let onFailure: () -> Void
    
    @State private var isLoading = true
    @Environment(\.appColorScheme) private var appColorScheme
    
    var body: some View {
        ZStack {
            StampVectorWebView(
                url: url,
                isLoading: $isLoading,
                onFailure: onFailure
            )
            
            if isLoading {
                ProgressView()
                    .tint(appColorScheme.primary)
            }
        }
    }
}

// MARK: - UIViewRepresentable

/// Internal WKWebView representable with navigation delegate for load tracking.
private struct StampVectorWebView: UIViewRepresentable {
    
    let url: URL?
    @Binding var isLoading: Bool
    let onFailure: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, onFailure: onFailure)
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
        webView.navigationDelegate = context.coordinator
        
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
        
        // Show spinner while loading new content
        isLoading = true
        
        // Fetch HTML, inject viewport, then load
        context.coordinator.loadWithViewport(webView: webView, url: url)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var currentURL: URL?
        var currentTask: Task<Void, Never>?
        @Binding var isLoading: Bool
        let onFailure: () -> Void
        
        init(isLoading: Binding<Bool>, onFailure: @escaping () -> Void) {
            self._isLoading = isLoading
            self.onFailure = onFailure
        }
        
        // MARK: - WKNavigationDelegate
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }
        
        // MARK: - Content Loading
        
        @MainActor
        func loadWithViewport(webView: WKWebView, url: URL) {
            // Cancel any previous fetch to prevent race conditions
            currentTask?.cancel()
            
            currentTask = Task {
                // Check disk cache first (processed HTML with viewport already injected)
                if let cachedHTML = await StampContentCache.shared.read(for: url) {
                    guard !Task.isCancelled, currentURL == url else { return }
                    webView.loadHTMLString(cachedHTML, baseURL: url)
                    return
                }
                
                // Cache miss - fetch from network, process, cache, then load
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
                    
                    // Cache the processed HTML for next time
                    await StampContentCache.shared.write(htmlString, for: url)
                    
                    // Final check before loading
                    guard !Task.isCancelled, currentURL == url else { return }
                    webView.loadHTMLString(htmlString, baseURL: url)
                } catch {
                    // Call failure callback on error
                    guard !Task.isCancelled, currentURL == url else { return }
                    print("Vector content load failed: \(error.localizedDescription)")
                    onFailure()
                    
                    // Still attempt direct load as fallback
                    webView.load(URLRequest(url: url))
                }
            }
        }
    }
}
