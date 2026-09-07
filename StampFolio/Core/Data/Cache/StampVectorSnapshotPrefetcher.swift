//
//  StampVectorSnapshotPrefetcher.swift
//  StampFolio
//
//  Off-screen WKWebViews that rasterize HTML/SVG stamps into
//  StampVectorSnapshotCache after StampContentCache has the source.
//

import UIKit
import WebKit

/// Up to five 1000×1000pt WKWebViews, off-screen in the key window, capturing in parallel.
@MainActor
final class StampVectorSnapshotPrefetcher {

    // MARK: - Nested Types

    /// One capture WebView plus its own navigation waiter. Delegate must be per-view.
    @MainActor
    private final class SnapshotSlot: NSObject, WKNavigationDelegate {
        let index: Int
        let webView: WKWebView
        let hostView: UIView
        var currentURL: URL?
        var isRunning = false
        private var navigationWaiter: CheckedContinuation<Void, Never>?
        private var navigationID = 0

        init(index: Int) {
            self.index = index
            let pointSize = StampVectorSnapshotImage.capturePointSize
            let gap: CGFloat = 8
            let hostView = UIView(
                frame: CGRect(
                    x: -pointSize.width - 40 - CGFloat(index) * (pointSize.width + gap),
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

        func waitForNavigation(isCurrentGeneration: @escaping () -> Bool) async {
            navigationID += 1
            let waitID = navigationID
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                navigationWaiter = continuation
                Task { @MainActor in
                    // Load timeout only — animation settle happens after this returns.
                    try? await Task.sleep(for: .seconds(5))
                    guard isCurrentGeneration(), self.navigationID == waitID else { return }
                    self.finishNavigationWait()
                }
            }
        }

        func finishNavigationWait() {
            navigationWaiter?.resume()
            navigationWaiter = nil
        }

        func stop() {
            currentURL = nil
            webView.stopLoading()
            finishNavigationWait()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            finishNavigationWait()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            finishNavigationWait()
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            finishNavigationWait()
        }
    }

    // MARK: - Singleton

    static let shared = StampVectorSnapshotPrefetcher()

    /// Concurrent off-screen captures. Settle sleeps overlap across slots.
    static let concurrency = 5

    // MARK: - Properties

    private let slots: [SnapshotSlot]
    private var queue: [URL] = []
    private var queued = Set<URL>()
    private var generation = 0
    private var windowWaitAttempts = 0
    private var waitContinuations: [UUID: CheckedContinuation<Void, Never>] = [:]
    private var waitersByURL: [URL: [UUID]] = [:]
    private var maxConcurrency = StampVectorSnapshotPrefetcher.concurrency
    private var memoryWarningObserver: NSObjectProtocol?

    // MARK: - Initialization

    private init() {
        slots = (0..<Self.concurrency).map { SnapshotSlot(index: $0) }
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                StampVectorSnapshotPrefetcher.shared.maxConcurrency = 1
            }
        }
    }

    deinit {
        if let memoryWarningObserver {
            NotificationCenter.default.removeObserver(memoryWarningObserver)
        }
    }

    // MARK: - Public Methods

    /// Append URLs to the snapshot queue. Duplicates already queued are skipped.
    func enqueue(_ urls: [URL]) {
        for url in urls where !queued.contains(url) {
            queued.insert(url)
            queue.append(url)
        }
        startWorkers()
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

    /// Drop the pending queue and abandon in-flight snapshots.
    func cancel() {
        generation += 1
        queue.removeAll()
        queued.removeAll()
        windowWaitAttempts = 0
        for slot in slots {
            slot.isRunning = false
            slot.stop()
        }
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

    // MARK: - Workers

    private func startWorkers() {
        attachHostsIfNeeded()
        for slot in slots where !slot.isRunning {
            guard slot.index < maxConcurrency else { continue }
            guard !queue.isEmpty else { return }
            slot.isRunning = true
            Task { await runWorker(slot) }
        }
    }

    private func runWorker(_ slot: SnapshotSlot) async {
        let gen = generation
        while gen == generation, slot.index < maxConcurrency {
            guard let url = dequeue() else { break }
            await capture(url, slot: slot, generation: gen)
        }
        slot.isRunning = false
        if queue.isEmpty {
            maxConcurrency = Self.concurrency
        } else if gen == generation {
            startWorkers()
        }
    }

    private func dequeue() -> URL? {
        guard !queue.isEmpty else { return nil }
        let url = queue.removeFirst()
        queued.remove(url)
        return url
    }

    private func requeue(_ url: URL) {
        guard !queued.contains(url) else { return }
        queued.insert(url)
        queue.insert(url, at: 0)
    }

    private func capture(_ url: URL, slot: SnapshotSlot, generation gen: Int) async {
        let appearance = currentAppearance
        if await StampVectorSnapshotCache.shared.contains(url, appearance: appearance) {
            finishWaiters(for: url)
            return
        }

        guard let html = await StampContentCache.shared.read(for: url) else {
            finishWaiters(for: url)
            return
        }

        attachHostsIfNeeded()
        guard slot.hostView.window != nil else {
            windowWaitAttempts += 1
            if windowWaitAttempts < 25 {
                requeue(url)
                try? await Task.sleep(for: .milliseconds(200))
            } else {
                finishWaiters(for: url)
            }
            return
        }
        windowWaitAttempts = 0

        slot.currentURL = url
        slot.webView.loadHTMLString(html, baseURL: url)
        await slot.waitForNavigation(isCurrentGeneration: { self.generation == gen })
        guard gen == generation, slot.currentURL == url else { return }

        try? await Task.sleep(for: StampVectorSnapshotImage.settleDuration)
        guard gen == generation, slot.currentURL == url else { return }

        if await StampVectorSnapshotCache.shared.contains(url, appearance: appearance) {
            finishWaiters(for: url)
            return
        }

        guard let thumbnail = await StampVectorSnapshotImage.captureSquareThumbnail(from: slot.webView) else {
            finishWaiters(for: url)
            return
        }
        guard gen == generation, slot.currentURL == url else { return }

        await StampVectorSnapshotCache.shared.write(thumbnail, for: url, appearance: appearance)
        finishWaiters(for: url)
        slot.currentURL = nil
    }

    // MARK: - Host window

    private func attachHostsIfNeeded() {
        guard let window = Self.keyWindow() else { return }
        for slot in slots where slot.hostView.superview == nil {
            window.addSubview(slot.hostView)
        }
    }

    private static func keyWindow() -> UIWindow? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        return windows.first(where: \.isKeyWindow) ?? windows.first
    }

    private var currentAppearance: StampVectorColorAppearance {
        let style = slots.first?.hostView.window?.traitCollection.userInterfaceStyle
            ?? UITraitCollection.current.userInterfaceStyle
        return style == .dark ? .dark : .light
    }
}
