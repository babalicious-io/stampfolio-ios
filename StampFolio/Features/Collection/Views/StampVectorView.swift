//
//  StampVectorView.swift
//  StampFolio
//
//  Renders vector-based stamp content (HTML, SVG)
//

import SwiftUI
import WebKit

/// View for rendering vector-based stamp content using WKWebView
struct StampVectorView: UIViewRepresentable {
    
    // MARK: - Properties
    
    let url: URL?
    let onFailure: () -> Void
    
    // MARK: - UIViewRepresentable
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onFailure: onFailure)
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
    
    // MARK: - Coordinator
    
    class Coordinator {
        var currentURL: URL?
        var currentTask: Task<Void, Never>?
        let onFailure: () -> Void
        
        init(onFailure: @escaping () -> Void) {
            self.onFailure = onFailure
        }
        
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
