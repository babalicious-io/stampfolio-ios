//
//  StampContentCache.swift
//  StampFolio
//
//  Disk cache for processed stamp content (HTML with viewport injected, plain text)
//  Stamps are immutable on-chain so cached content never expires.
//

import Foundation
import CryptoKit

/// Two-tier cache for processed stamp content (HTML/SVG/text) and parsed HTML titles.
/// - Tier 1: In-memory NSCache (fast, auto-evicts under memory pressure)
/// - Tier 2: Disk files keyed by SHA256 hash of URL (persistent, never expires)
///
/// Keyed by URL, stores processed strings so repeat loads
/// skip the network fetch and string processing entirely.
actor StampContentCache {
    
    // MARK: - Singleton
    
    static let shared = StampContentCache()
    
    // MARK: - Properties
    
    private let cacheDirectory: URL
    
    /// In-memory cache for recently accessed content.
    /// NSCache auto-evicts entries under memory pressure (Apple-managed).
    private let memoryCache = NSCache<NSString, NSString>()
    
    // MARK: - Initialization
    
    private init() {
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDir.appendingPathComponent("stamp_content", isDirectory: true)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Limit in-memory cache to 100 entries (HTML/text plus title sidecars)
        memoryCache.countLimit = 100
    }
    
    // MARK: - Public Methods
    
    /// Read cached content for a URL
    /// Checks in-memory cache first (fast path), then falls back to disk (slow path).
    /// - Parameter url: The stamp content URL
    /// - Returns: Cached string if available, nil otherwise
    func read(for url: URL) -> String? {
        let key = cacheKey(for: url)
        
        // Fast path: in-memory
        if let cached = memoryCache.object(forKey: key) {
            return cached as String
        }
        
        // Slow path: disk -> promote to memory on hit
        let filePath = cacheFilePath(for: url)
        if let content = try? String(contentsOf: filePath, encoding: .utf8) {
            memoryCache.setObject(content as NSString, forKey: key)
            return content
        }
        
        return nil
    }
    
    /// Write processed content to cache (both memory and disk)
    /// - Parameters:
    ///   - content: The processed HTML/text string
    ///   - url: The stamp content URL (used as cache key)
    func write(_ content: String, for url: URL) {
        let key = cacheKey(for: url)
        memoryCache.setObject(content as NSString, forKey: key)
        
        let filePath = cacheFilePath(for: url)
        try? content.write(to: filePath, atomically: true, encoding: .utf8)

        persistTitle(HTMLMetadataParser.title(from: content), for: url)
    }

    /// Cached HTML document title, if one has been parsed.
    /// Parses from cached HTML when a title sidecar is missing (older cache entries).
    /// Empty titles are stored so HTML without a title is not re-parsed.
    func readTitle(for url: URL) -> String? {
        if let stored = storedTitle(for: url) {
            return stored.isEmpty ? nil : stored
        }

        guard let html = read(for: url) else { return nil }
        let title = HTMLMetadataParser.title(from: html)
        persistTitle(title, for: url)
        return title
    }
    
    /// Check if content is cached for a URL (checks memory first, then disk)
    /// - Parameter url: The stamp content URL
    /// - Returns: True if cached content exists
    func contains(_ url: URL) -> Bool {
        let key = cacheKey(for: url)
        if memoryCache.object(forKey: key) != nil {
            return true
        }
        let filePath = cacheFilePath(for: url)
        return FileManager.default.fileExists(atPath: filePath.path)
    }
    
    /// Remove all cached content (both memory and disk)
    func clearAll() {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Private Methods
    
    /// Generate a cache key string from a URL using SHA256 hash
    private func cacheKey(for url: URL) -> NSString {
        let hash = SHA256.hash(data: Data(url.absoluteString.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined() as NSString
    }
    
    /// Generate a file path for a URL using the cache key
    private func cacheFilePath(for url: URL) -> URL {
        let fileName = cacheKey(for: url) as String
        return cacheDirectory.appendingPathComponent(fileName)
    }

    private func titleCacheKey(for url: URL) -> NSString {
        "\(cacheKey(for: url) as String).title" as NSString
    }

    private func titleFilePath(for url: URL) -> URL {
        cacheDirectory.appendingPathComponent("\(cacheKey(for: url) as String).title")
    }

    /// Returns the stored title string (empty means parsed, no title). Nil means not stored yet.
    private func storedTitle(for url: URL) -> String? {
        let key = titleCacheKey(for: url)
        if let cached = memoryCache.object(forKey: key) {
            return cached as String
        }

        let filePath = titleFilePath(for: url)
        guard FileManager.default.fileExists(atPath: filePath.path) else { return nil }

        let content = (try? String(contentsOf: filePath, encoding: .utf8)) ?? ""
        memoryCache.setObject(content as NSString, forKey: key)
        return content
    }

    private func persistTitle(_ title: String?, for url: URL) {
        let stored = title ?? ""
        let key = titleCacheKey(for: url)
        memoryCache.setObject(stored as NSString, forKey: key)
        try? stored.write(to: titleFilePath(for: url), atomically: true, encoding: .utf8)
    }
}
