//
//  StampVectorSnapshotPrefetcher.swift
//  StampFolio
//
//  Serial offscreen WKWebView that rasterizes HTML/SVG stamps into
//  StampVectorSnapshotCache after StampContentCache has the source.
//

import UIKit
import WebKit

/// One 200pt WKWebView, off-screen in the key window, processing URLs one at a time.
@MainActor
final class StampVectorSnapshotPrefetcher: NSObject, WKNavigationDelegate {

    // MARK: - Singleton

    static let shared = StampVectorSnapshotPrefetcher()

    // MARK: - Properties

    private let webView: WKWebView
    private let hostView = UIView(frame: CGRect(x: -240, y: -240, width: 200, height: 200))
    private var queue: [URL] = []
    private var queued = Set<URL>()
    private var isRunning = false
    private var generation = 0
    private var navigationWaiter: CheckedContinuation<Void, Never>?
    private var navigationID = 0
    private var currentURL: URL?
    private var windowWaitAttempts = 0

    // MARK: - Initialization

    private override init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(
            frame: CGRect(origin: .zero, size: StampVectorSnapshotImage.thumbnailSize),
            configuration: config
        )
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false
        self.webView = webView
        super.init()
        webView.navigationDelegate = self

        hostView.isUserInteractionEnabled = false
        hostView.alpha = 0.01
        hostView.addSubview(webView)
        webView.frame = hostView.bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    // MARK: - Public Methods

    /// Append URLs to the snapshot queue. Duplicates already queued are skipped.
    func enqueue(_ urls: [URL]) {
        for url in urls where !queued.contains(url) {
            queued.insert(url)
            queue.append(url)
        }
        startIfNeeded()
    }

    /// Drop the pending queue and abandon the in-flight snapshot.
    func cancel() {
        generation += 1
        queue.removeAll()
        queued.removeAll()
        currentURL = nil
        windowWaitAttempts = 0
        webView.stopLoading()
        finishNavigationWait()
        isRunning = false
    }

    // MARK: - Queue

    private func startIfNeeded() {
        guard !isRunning else { return }
        isRunning = true
        Task { await processQueue() }
    }

    private func processQueue() async {
        let gen = generation
        attachHostIfNeeded()

        while !queue.isEmpty {
            guard gen == generation else { break }

            let url = queue.removeFirst()
            queued.remove(url)

            let appearance = currentAppearance
            if await StampVectorSnapshotCache.shared.contains(url, appearance: appearance) {
                continue
            }

            guard let html = await StampContentCache.shared.read(for: url) else {
                continue
            }

            attachHostIfNeeded()
            guard hostView.window != nil else {
                windowWaitAttempts += 1
                if windowWaitAttempts < 25, !queued.contains(url) {
                    queued.insert(url)
                    queue.insert(url, at: 0)
                    try? await Task.sleep(for: .milliseconds(200))
                }
                continue
            }
            windowWaitAttempts = 0

            currentURL = url
            webView.loadHTMLString(html, baseURL: url)
            await waitForNavigation(generation: gen)
            guard gen == generation, currentURL == url else { continue }

            try? await Task.sleep(for: StampVectorSnapshotImage.settleDuration)
            guard gen == generation, currentURL == url else { continue }

            if await StampVectorSnapshotCache.shared.contains(url, appearance: appearance) {
                continue
            }

            guard let thumbnail = await StampVectorSnapshotImage.captureSquareThumbnail(from: webView) else { continue }
            guard gen == generation, currentURL == url else { continue }

            await StampVectorSnapshotCache.shared.write(thumbnail, for: url, appearance: appearance)
        }

        isRunning = false
        if !queue.isEmpty, gen == generation {
            startIfNeeded()
        }
    }

    // MARK: - Navigation wait

    private func waitForNavigation(generation gen: Int) async {
        navigationID += 1
        let waitID = navigationID
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            navigationWaiter = continuation
            Task { @MainActor in
                // Load timeout only — animation settle happens after this returns.
                try? await Task.sleep(for: .seconds(5))
                guard self.generation == gen, self.navigationID == waitID else { return }
                self.finishNavigationWait()
            }
        }
    }

    private func finishNavigationWait() {
        navigationWaiter?.resume()
        navigationWaiter = nil
    }

    // MARK: - Host window

    private func attachHostIfNeeded() {
        guard hostView.superview == nil else { return }
        guard let window = Self.keyWindow() else { return }
        window.addSubview(hostView)
    }

    private static func keyWindow() -> UIWindow? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        return windows.first(where: \.isKeyWindow) ?? windows.first
    }

    private var currentAppearance: StampVectorColorAppearance {
        let style = hostView.window?.traitCollection.userInterfaceStyle
            ?? UITraitCollection.current.userInterfaceStyle
        return style == .dark ? .dark : .light
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finishNavigationWait()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finishNavigationWait()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finishNavigationWait()
    }
}
