//
//  StampVectorWebViewPool.swift
//  StampFolio
//
//  Reuses WKWebView instances across collection view-mode changes so HTML/SVG
//  stamps do not reload when the grid/list tree is torn down.
//

import UIKit
import WebKit

/// Exclusive URL-keyed pool of collection WKWebViews.
/// Checked-out views stay alive; idle views survive the grid→list gap, then LRU-evict.
@MainActor
final class StampVectorWebViewPool {

    // MARK: - Nested Types

    final class Entry {
        let webView: WKWebView
        let isPooled: Bool
        var loadedURL: URL?

        init(webView: WKWebView, isPooled: Bool) {
            self.webView = webView
            self.isPooled = isPooled
        }
    }

    // MARK: - Singleton

    static let shared = StampVectorWebViewPool()

    // MARK: - Properties

    private var checkedOut: [URL: Entry] = [:]
    private var idle: [URL: Entry] = [:]
    private var idleOrder: [URL] = []
    private let idleLimit = 20
    private var memoryWarningObserver: NSObjectProtocol?

    // MARK: - Initialization

    private init() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                StampVectorWebViewPool.shared.drainIdle()
            }
        }
    }

    deinit {
        if let memoryWarningObserver {
            NotificationCenter.default.removeObserver(memoryWarningObserver)
        }
    }

    // MARK: - Factory

    static func makeWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        let backgroundColor = UIColor.systemBackground
        webView.backgroundColor = backgroundColor
        webView.scrollView.backgroundColor = backgroundColor
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false
        return webView
    }

    // MARK: - Checkout

    /// Returns a pooled view for `url`, or an unpooled view if that URL is already checked out.
    func checkout(url: URL) -> Entry {
        if checkedOut[url] != nil {
            return Entry(webView: Self.makeWebView(), isPooled: false)
        }

        if let idleEntry = idle.removeValue(forKey: url) {
            idleOrder.removeAll { $0 == url }
            checkedOut[url] = idleEntry
            return idleEntry
        }

        let entry = Entry(webView: Self.makeWebView(), isPooled: true)
        checkedOut[url] = entry
        return entry
    }

    /// Return a pooled entry to idle, or drop it when live HTML preview is off.
    func release(_ entry: Entry, url: URL) {
        guard entry.isPooled else { return }
        guard checkedOut[url] === entry else { return }
        checkedOut.removeValue(forKey: url)

        guard Self.isLiveHTMLPreviewEnabled else { return }

        idle[url] = entry
        idleOrder.removeAll { $0 == url }
        idleOrder.append(url)
        evictIdleIfNeeded()
    }

    func drainIdle() {
        idle.removeAll()
        idleOrder.removeAll()
    }

    // MARK: - Private

    private func evictIdleIfNeeded() {
        while idleOrder.count > idleLimit {
            let oldest = idleOrder.removeFirst()
            idle.removeValue(forKey: oldest)
        }
    }

    private static var isLiveHTMLPreviewEnabled: Bool {
        if UserDefaults.standard.object(forKey: "htmlPerformancePreview") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "htmlPerformancePreview")
    }
}
