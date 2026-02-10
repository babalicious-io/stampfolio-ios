//
//  StampContentCache.swift
//  StampFolio
//
//  Disk cache for processed stamp content (HTML with viewport injected, plain text)
//  Stamps are immutable on-chain so cached content never expires.
//

import Foundation
import CryptoKit

/// File-based cache for processed stamp content (HTML/SVG/text)
/// Keyed by URL, stores processed strings to disk so repeat loads
/// skip the network fetch and string processing entirely.
actor StampContentCache {
    
    // MARK: - Singleton
    
    static let shared = StampContentCache()
    
    // MARK: - Properties
    
    private let cacheDirectory: URL
    
    // MARK: - Initialization
    
    private init() {
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDir.appendingPathComponent("stamp_content", isDirectory: true)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Public Methods
    
    /// Read cached content for a URL
    /// - Parameter url: The stamp content URL
    /// - Returns: Cached string if available, nil otherwise
    func read(for url: URL) -> String? {
        let filePath = cacheFilePath(for: url)
        return try? String(contentsOf: filePath, encoding: .utf8)
    }
    
    /// Write processed content to cache
    /// - Parameters:
    ///   - content: The processed HTML/text string
    ///   - url: The stamp content URL (used as cache key)
    func write(_ content: String, for url: URL) {
        let filePath = cacheFilePath(for: url)
        try? content.write(to: filePath, atomically: true, encoding: .utf8)
    }
    
    /// Check if content is cached for a URL
    /// - Parameter url: The stamp content URL
    /// - Returns: True if cached content exists
    func contains(_ url: URL) -> Bool {
        let filePath = cacheFilePath(for: url)
        return FileManager.default.fileExists(atPath: filePath.path)
    }
    
    /// Remove all cached content
    func clearAll() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Private Methods
    
    /// Generate a file path for a URL using SHA256 hash
    private func cacheFilePath(for url: URL) -> URL {
        let hash = SHA256.hash(data: Data(url.absoluteString.utf8))
        let fileName = hash.compactMap { String(format: "%02x", $0) }.joined()
        return cacheDirectory.appendingPathComponent(fileName)
    }
}
