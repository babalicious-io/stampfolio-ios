//
//  StampVectorSnapshotPrefetcher.swift
//  StampFolio
//
//  Serial offscreen WKWebView that rasterizes HTML/SVG stamps into
//  StampVectorSnapshotCache after StampContentCache has the source.
//

import UIKit
import WebKit

/// One 1000×1000pt WKWebView, off-screen in the key window, processing URLs one at a time.
@MainActor
final class StampVectorSnapshotPrefetcher: NSObject, WKNavigationDelegate {

    // MARK: - Singleton

    static let shared = StampVectorSnapshotPrefetcher()

    // MARK: - Properties

    private let webView: WKWebView
    private let hostView: UIView
    private var queue: [URL] = []
    private var queued = Set<URL>()
    private var isRunning = false
    private var generation = 0
    private var navigationWaiter: CheckedContinuation<Void, Never>?
    private var navigationID = 0
    private var currentURL: URL?
    private var windowWaitAttempts = 0
    private var waitContinuations: [UUID: CheckedContinuation<Void, Never>] = [:]
    private var waitersByURL: [URL: [UUID]] = [:]

    // MARK: - Initialization

    private override init() {
        let pointSize = StampVectorSnapshotImage.capturePointSize
        let hostView = UIView(
            frame: CGRect(
                x: -pointSize.width - 40,
                y: -pointSize.height - 40,
                width: pointSize.width,
                height: pointSize.height
            )
        )
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(
            frame: CGRect(origin: .zero, size: pointSize),
            configuration: config
        )
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isUserInteractionEnabled = false
        self.webView = webView
        self.hostView = hostView
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

    /// Enqueue `urls` and wait until each has a snapshot, failed, or was skipped. Failures still count.
    func enqueueAndWait(_ urls: [URL], onProgress: @escaping (Int) -> Void) async {
        guard !urls.isEmpty else { return }
        var finished = 0
        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask { @MainActor in
                    await self.waitUntilFinished(for: url)
                    finished += 1
                    onProgress(finished)
                }
            }
        }
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
        resumeAllWaiters()
    }

    /// Wait until this URL is stored, skipped, or the prefetcher is cancelled.
    private func waitUntilFinished(for url: URL) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let id = UUID()
            waitContinuations[id] = continuation
            waitersByURL[url, default: []].append(id)
            Task { @MainActor in
                let appearance = self.currentAppearance
                if await StampVectorSnapshotCache.shared.contains(url, appearance: appearance) {
                    self.finishWaiters(for: url)
                    return
                }
                self.enqueue([url])
            }
        }
    }

    private func finishWaiters(for url: URL) {
        let ids = waitersByURL.removeValue(forKey: url) ?? []
        for id in ids {
            waitContinuations.removeValue(forKey: id)?.resume()
        }
    }

    private func resumeAllWaiters() {
        let pending = waitContinuations
        waitContinuations.removeAll()
        waitersByURL.removeAll()
        pending.values.forEach { $0.resume() }
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
                finishWaiters(for: url)
                continue
            }

            guard let html = await StampContentCache.shared.read(for: url) else {
                finishWaiters(for: url)
                continue
            }

            attachHostIfNeeded()
            guard hostView.window != nil else {
                windowWaitAttempts += 1
                if windowWaitAttempts < 25 {
                    if !queued.contains(url) {
                        queued.insert(url)
                        queue.insert(url, at: 0)
                    }
                    try? await Task.sleep(for: .milliseconds(200))
                } else if !queued.contains(url) {
                    // No window to render into. Stop blocking the download overlay on this stamp.
                    finishWaiters(for: url)
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
                finishWaiters(for: url)
                continue
            }

            guard let thumbnail = await StampVectorSnapshotImage.captureSquareThumbnail(from: webView) else {
                finishWaiters(for: url)
                continue
            }
            guard gen == generation, currentURL == url else { continue }

            await StampVectorSnapshotCache.shared.write(thumbnail, for: url, appearance: appearance)
            finishWaiters(for: url)
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
