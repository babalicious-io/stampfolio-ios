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

/// Square 200pt thumbnails from WKWebView snapshots (same size as pixel stamp previews).
enum StampVectorSnapshotImage {
    static let thumbnailSize = CGSize(width: 200, height: 200)

    /// Pause after `didFinish` so HTML/SVG animation can reach a representative frame.
    static let settleDuration: Duration = .seconds(5)

    /// Capture the largest centered square of the web view at `thumbnailSize`.
    static func snapshotConfiguration(for webView: WKWebView) -> WKSnapshotConfiguration {
        let config = WKSnapshotConfiguration()
        let bounds = webView.bounds
        let side = min(bounds.width, bounds.height)
        if side > 1 {
            config.rect = CGRect(
                x: (bounds.width - side) / 2,
                y: (bounds.height - side) / 2,
                width: side,
                height: side
            )
        }
        config.snapshotWidth = NSNumber(value: thumbnailSize.width)
        return config
    }

    /// Center-crops to 1:1, then scales to `pointSize` without stretching.
    static func squareThumbnail(_ image: UIImage, to pointSize: CGSize = thumbnailSize) -> UIImage {
        let cropped = centerCroppedSquare(image) ?? image
        let format = UIGraphicsImageRendererFormat()
        format.scale = cropped.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: pointSize, format: format)
        return renderer.image { _ in
            cropped.draw(in: CGRect(origin: .zero, size: pointSize))
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
        return squareThumbnail(raw)
    }

    private static func centerCroppedSquare(_ image: UIImage) -> UIImage? {
        let size = image.size
        let side = min(size.width, size.height)
        guard side > 0 else { return nil }
        let crop = CGRect(
            x: (size.width - side) / 2,
            y: (size.height - side) / 2,
            width: side,
            height: side
        )
        let scale = image.scale
        let pixelCrop = CGRect(
            x: crop.origin.x * scale,
            y: crop.origin.y * scale,
            width: crop.width * scale,
            height: crop.height * scale
        ).integral
        guard let cgImage = image.cgImage?.cropping(to: pixelCrop) else { return nil }
        return UIImage(cgImage: cgImage, scale: scale, orientation: image.imageOrientation)
    }
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
        "\(urlHash(for: url)).\(appearance.rawValue).1x1" as NSString
    }

    private func cacheFilePath(for url: URL, appearance: StampVectorColorAppearance) -> URL {
        cacheDirectory.appendingPathComponent("\(urlHash(for: url)).\(appearance.rawValue).1x1.png")
    }
}
