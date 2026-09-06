//
//  StampVectorSnapshotCache.swift
//  StampFolio
//
//  Disk + memory cache for rendered HTML/SVG collection previews.
//  Stamps are immutable on-chain so cached snapshots never expire.
//

import UIKit
import WebKit
import CryptoKit

/// Light/dark variant for snapshot keys. HTML uses `UIColor.systemBackground`,
/// so a light capture must not be shown in dark mode (and vice versa).
enum StampVectorColorAppearance: String, Sendable {
    case light
    case dark
}

/// Square collection thumbnails captured at 1000×1000px, then scaled to 200pt.
enum StampVectorSnapshotImage {
    static let thumbnailSize = CGSize(width: 200, height: 200)
    /// Offscreen WKWebView layout size (CSS viewport). Square so the full stamp is visible.
    static let captureLayoutSide: CGFloat = 1000
    /// Snapshot bitmap edge in device pixels before downscaling to `thumbnailSize`.
    static let capturePixelSide: CGFloat = 1000

    /// Pause after `didFinish` so HTML/SVG animation can reach a representative frame.
    static let settleDuration: Duration = .seconds(5)

    static var capturePointSize: CGSize {
        CGSize(width: captureLayoutSide, height: captureLayoutSide)
    }

    /// Full view from the top-left — never a centered crop (that clips the top of tall HTML).
    static func snapshotConfiguration(for webView: WKWebView) -> WKSnapshotConfiguration {
        let config = WKSnapshotConfiguration()
        let side = min(webView.bounds.width, webView.bounds.height)
        config.rect = CGRect(x: 0, y: 0, width: side, height: side)
        let scale = max(UIScreen.main.scale, 1)
        config.snapshotWidth = NSNumber(value: capturePixelSide / scale)
        return config
    }

    /// Fits the entire snapshot into a 200pt square (top-aligned if taller). Does not crop.
    static func displayThumbnail(_ image: UIImage, to pointSize: CGSize = thumbnailSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: pointSize, format: format)
        return renderer.image { _ in
            let src = image.size
            guard src.width > 0, src.height > 0 else { return }
            let fit = min(pointSize.width / src.width, pointSize.height / src.height)
            let drawSize = CGSize(width: src.width * fit, height: src.height * fit)
            let x = (pointSize.width - drawSize.width) / 2
            let y = src.height > src.width ? 0 : (pointSize.height - drawSize.height) / 2
            image.draw(in: CGRect(origin: CGPoint(x: x, y: y), size: drawSize))
        }
    }

    @MainActor
    static func captureSquareThumbnail(from webView: WKWebView) async -> UIImage? {
        guard min(webView.bounds.width, webView.bounds.height) > 1 else { return nil }
        let raw: UIImage? = await withCheckedContinuation { continuation in
            webView.takeSnapshot(with: snapshotConfiguration(for: webView)) { image, _ in
                continuation.resume(returning: image)
            }
        }
        guard let raw else { return nil }
        return displayThumbnail(raw)
    }
}

extension Notification.Name {
    static let stampVectorSnapshotDidStore = Notification.Name("stampVectorSnapshotDidStore")
}

/// Two-tier cache for HTML/SVG collection snapshots.
/// - Tier 1: In-memory NSCache (fast, auto-evicts under memory pressure)
/// - Tier 2: PNG files keyed by SHA256(URL) + color appearance (persistent, never expires)
actor StampVectorSnapshotCache {

    // MARK: - Singleton

    static let shared = StampVectorSnapshotCache()

    // MARK: - Properties

    private let cacheDirectory: URL
    private let memoryCache = NSCache<NSString, UIImage>()

    // MARK: - Initialization

    private init() {
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDir.appendingPathComponent("stamp_vector_snapshots", isDirectory: true)

        // Drop center-cropped / 200pt captures so 1000×1000px stills are rebuilt.
        let versionKey = "stampVectorSnapshotCacheVersion"
        let version = 3
        if UserDefaults.standard.integer(forKey: versionKey) != version {
            try? FileManager.default.removeItem(at: cacheDirectory)
            UserDefaults.standard.set(version, forKey: versionKey)
        }

        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        memoryCache.countLimit = 50
    }

    // MARK: - Public Methods

    /// Read a cached snapshot for a URL and appearance.
    func read(for url: URL, appearance: StampVectorColorAppearance) -> UIImage? {
        let key = cacheKey(for: url, appearance: appearance)

        if let cached = memoryCache.object(forKey: key) {
            return cached
        }

        let filePath = cacheFilePath(for: url, appearance: appearance)
        guard let data = try? Data(contentsOf: filePath),
              let image = UIImage(data: data) else {
            return nil
        }
        memoryCache.setObject(image, forKey: key)
        return image
    }

    /// Write a snapshot (already downsampled) to memory and disk.
    func write(_ image: UIImage, for url: URL, appearance: StampVectorColorAppearance) {
        let key = cacheKey(for: url, appearance: appearance)
        memoryCache.setObject(image, forKey: key)

        let filePath = cacheFilePath(for: url, appearance: appearance)
        if let data = image.pngData() {
            try? data.write(to: filePath, options: .atomic)
        }

        Task { @MainActor in
            NotificationCenter.default.post(
                name: .stampVectorSnapshotDidStore,
                object: nil,
                userInfo: ["url": url]
            )
        }
    }

    /// Whether a snapshot exists in memory or on disk.
    func contains(_ url: URL, appearance: StampVectorColorAppearance) -> Bool {
        let key = cacheKey(for: url, appearance: appearance)
        if memoryCache.object(forKey: key) != nil {
            return true
        }
        let filePath = cacheFilePath(for: url, appearance: appearance)
        return FileManager.default.fileExists(atPath: filePath.path)
    }

    /// Remove all cached snapshots (memory and disk).
    func clearAll() {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Private Methods

    private func urlHash(for url: URL) -> String {
        let hash = SHA256.hash(data: Data(url.absoluteString.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func cacheKey(for url: URL, appearance: StampVectorColorAppearance) -> NSString {
        "\(urlHash(for: url)).\(appearance.rawValue).1000px" as NSString
    }

    private func cacheFilePath(for url: URL, appearance: StampVectorColorAppearance) -> URL {
        cacheDirectory.appendingPathComponent("\(urlHash(for: url)).\(appearance.rawValue).1000px.png")
    }
}
