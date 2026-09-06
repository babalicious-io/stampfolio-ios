//
//  StampAssetVectorView.swift
//  StampFolio
//
//  Renders vector-based stamp content (HTML, SVG)
//

import SwiftUI
import WebKit

/// Collection/detail preview for HTML and SVG stamps.
/// Shows a cached snapshot immediately; mounts a (pooled) WKWebView when live preview is on
/// or when no snapshot exists yet.
struct StampAssetVectorView: View {

    let url: URL?
    let onFailure: () -> Void
    var reusesWebView: Bool = false

    @AppStorage("htmlPerformancePreview") private var htmlPerformancePreview = true
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appColorScheme) private var appColorScheme

    @State private var snapshot: UIImage?
    @State private var isLoading = true
    @State private var didCheckCache = false

    private var appearance: StampVectorColorAppearance {
        colorScheme == .dark ? .dark : .light
    }

    /// Live WebKit, or a one-shot WebView to capture a missing snapshot.
    private var shouldMountWebView: Bool {
        guard didCheckCache else { return false }
        return htmlPerformancePreview || snapshot == nil
    }

    private var showLiveWebView: Bool {
        htmlPerformancePreview && !isLoading
    }

    var body: some View {
        ZStack {
            if let snapshot {
                Image(uiImage: snapshot)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFill()
            }

            if shouldMountWebView {
                StampVectorWebView(
                    url: url,
                    reusesWebView: reusesWebView,
                    appearance: appearance,
                    isLoading: $isLoading,
                    onFailure: onFailure,
                    onSnapshot: { image in
                        snapshot = image
                    }
                )
                .opacity(showLiveWebView || snapshot == nil ? 1 : 0)
            }

            if isLoading && snapshot == nil {
                ProgressView()
                    .tint(appColorScheme.primary)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showLiveWebView)
        .onChange(of: taskID) { _, _ in
            didCheckCache = false
            snapshot = nil
        }
        .task(id: taskID) {
            await loadCachedSnapshot()
            didCheckCache = true
        }
    }

    private var taskID: String {
        "\(url?.absoluteString ?? "")-\(appearance.rawValue)"
    }

    private func loadCachedSnapshot() async {
        guard let url else {
            isLoading = false
            return
        }
        if let cached = await StampVectorSnapshotCache.shared.read(for: url, appearance: appearance) {
            snapshot = cached
            isLoading = false
        }
    }
}

// MARK: - UIViewRepresentable

/// Internal WKWebView representable with navigation delegate for load tracking.
private struct StampVectorWebView: UIViewRepresentable {

    let url: URL?
    let reusesWebView: Bool
    let appearance: StampVectorColorAppearance
    @Binding var isLoading: Bool
    let onFailure: () -> Void
    let onSnapshot: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            appearance: appearance,
            isLoading: $isLoading,
            onFailure: onFailure,
            onSnapshot: onSnapshot
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let entry: StampVectorWebViewPool.Entry
        if reusesWebView, let url {
            entry = StampVectorWebViewPool.shared.checkout(url: url)
            if entry.isPooled {
                context.coordinator.poolKey = url
            }
        } else {
            entry = StampVectorWebViewPool.Entry(webView: StampVectorWebViewPool.makeWebView(), isPooled: false)
        }

        context.coordinator.entry = entry
        entry.webView.navigationDelegate = context.coordinator
        return entry.webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.appearance = appearance
        context.coordinator.onSnapshot = onSnapshot
        context.coordinator.onFailure = onFailure

        let backgroundColor = UIColor.systemBackground
        webView.backgroundColor = backgroundColor
        webView.scrollView.backgroundColor = backgroundColor
        webView.navigationDelegate = context.coordinator

        guard let url else { return }

        if context.coordinator.entry?.loadedURL == url {
            isLoading = false
            return
        }

        guard context.coordinator.currentURL != url else { return }
        context.coordinator.currentURL = url
        isLoading = true
        context.coordinator.loadWithViewport(webView: webView, url: url)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.navigationDelegate = nil
        coordinator.currentTask?.cancel()
        coordinator.snapshotTask?.cancel()
        guard let entry = coordinator.entry, let poolKey = coordinator.poolKey else { return }
        StampVectorWebViewPool.shared.release(entry, url: poolKey)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate {
        var currentURL: URL?
        var currentTask: Task<Void, Never>?
        var snapshotTask: Task<Void, Never>?
        var entry: StampVectorWebViewPool.Entry?
        var poolKey: URL?
        var appearance: StampVectorColorAppearance
        @Binding var isLoading: Bool
        var onFailure: () -> Void
        var onSnapshot: (UIImage) -> Void

        init(
            appearance: StampVectorColorAppearance,
            isLoading: Binding<Bool>,
            onFailure: @escaping () -> Void,
            onSnapshot: @escaping (UIImage) -> Void
        ) {
            self.appearance = appearance
            self._isLoading = isLoading
            self.onFailure = onFailure
            self.onSnapshot = onSnapshot
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            entry?.loadedURL = currentURL
            isLoading = false
            captureSnapshot(from: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }

        // MARK: - Snapshot

        @MainActor
        private func captureSnapshot(from webView: WKWebView) {
            snapshotTask?.cancel()
            let url = currentURL
            let capturedAppearance = appearance
            snapshotTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled, currentURL == url else { return }
                guard webView.bounds.width > 1, webView.bounds.height > 1 else { return }

                let raw: UIImage? = await withCheckedContinuation { continuation in
                    webView.takeSnapshot(with: nil) { image, _ in
                        continuation.resume(returning: image)
                    }
                }
                guard !Task.isCancelled, currentURL == url, let raw else { return }

                let downsampled = StampVectorSnapshotImage.downsampled(raw)
                onSnapshot(downsampled)
                if let url {
                    await StampVectorSnapshotCache.shared.write(downsampled, for: url, appearance: capturedAppearance)
                }
            }
        }

        // MARK: - Content Loading

        @MainActor
        func loadWithViewport(webView: WKWebView, url: URL) {
            currentTask?.cancel()

            currentTask = Task {
                if let cachedHTML = await StampContentCache.shared.read(for: url) {
                    guard !Task.isCancelled, currentURL == url else { return }
                    webView.loadHTMLString(cachedHTML, baseURL: url)
                    return
                }

                do {
                    let (data, _) = try await URLSession.shared.data(from: url)

                    guard !Task.isCancelled, currentURL == url else { return }

                    guard var htmlString = String(data: data, encoding: .utf8) else {
                        guard !Task.isCancelled, currentURL == url else { return }
                        webView.load(URLRequest(url: url))
                        return
                    }

                    let viewportMeta = "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no\">"

                    if !htmlString.contains("name=\"viewport\"") && !htmlString.contains("name='viewport'") {
                        if let headRange = htmlString.range(of: "<head>", options: .caseInsensitive) {
                            htmlString.insert(contentsOf: viewportMeta, at: headRange.upperBound)
                        } else if let htmlRange = htmlString.range(of: "<html", options: .caseInsensitive) {
                            if let closeRange = htmlString[htmlRange.upperBound...].range(of: ">") {
                                htmlString.insert(contentsOf: "<head>\(viewportMeta)</head>", at: closeRange.upperBound)
                            }
                        } else {
                            htmlString = viewportMeta + htmlString
                        }
                    }

                    await StampContentCache.shared.write(htmlString, for: url)

                    guard !Task.isCancelled, currentURL == url else { return }
                    webView.loadHTMLString(htmlString, baseURL: url)
                } catch {
                    guard !Task.isCancelled, currentURL == url else { return }
                    print("Vector content load failed: \(error.localizedDescription)")
                    onFailure()
                    webView.load(URLRequest(url: url))
                }
            }
        }
    }
}
