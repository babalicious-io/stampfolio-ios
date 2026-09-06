//
//  CounterpartyAssetImageResolver.swift
//  StampFolio
//
//  Resolves the real artwork URL for a Counterparty asset from its `description` field,
//  falling back to Horizon Market's public asset API when that fails
//

import Foundation

/// Resolves a Counterparty asset's image URL.
///
/// Artwork is not on the asset record. The on-chain `description` is classified as CIP-25
/// (imgur shorthand, `ipfs:` / `ar://`, HTTPS JSON or raster URL). Native schemes are rewritten
/// to HTTPS gateways (`ipfs.io`, `arweave.net`). Only `https://` raster URLs are returned so
/// ATS cannot black-hole an HTTP "success".
///
/// When description resolution fails (HTTP-only host, gateway timeout, `stamp:` / `ord:`,
/// plain text), Horizon Market's archive is tried next. Horizon posters are used even when
/// `media.kind` is not `"image"` (audio/video still show a still). Placeholder Horizon art is skipped.
///
/// Resolved URLs (including "no artwork") are kept in memory and persisted under Caches.
/// Cache version 2 dropped pre-CIP-25 mappings so large-first / gateway URLs replace old picks.
/// Settings wallet refresh passes `forceRefresh` to re-resolve in case artwork was archived later.
actor CounterpartyAssetImageResolver {

    // MARK: - Singleton

    static let shared = CounterpartyAssetImageResolver()

    // MARK: - Nested Types

    /// On-disk map. `version` is bumped when resolution rules change so stale URLs are not reused.
    private struct DiskCache: Codable {
        var version: Int
        var urls: [String: String]
        static let currentVersion = 2
    }

    // MARK: - Properties

    /// In-memory cache of resolved image URLs, keyed by asset name. A `nil` value means the
    /// asset was already checked and has no resolvable artwork (avoids re-fetching each time
    /// a row/card for that asset reappears on screen).
    private var cache: [String: URL?] = [:]

    /// In-flight resolution tasks, keyed by asset name, so concurrent requests for the same
    /// asset (e.g. the row and a prefetch) share a single network fetch.
    private var inFlightTasks: [String: Task<URL?, Never>] = [:]

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let diskURL: URL

    // MARK: - Initialization

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = true
        config.urlCache = URLCache(
            memoryCapacity: 5 * 1024 * 1024,
            diskCapacity: 20 * 1024 * 1024,
            diskPath: "counterparty_manifest_cache"
        )
        config.requestCachePolicy = .returnCacheDataElseLoad

        self.session = URLSession(configuration: config)

        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.diskURL = cachesDir.appendingPathComponent("counterparty_resolved_urls.json")
        self.cache = Self.loadCache(from: diskURL)
    }

    // MARK: - Public Methods

    /// Resolve the artwork URL for a Counterparty asset, if any.
    /// - Parameters:
    ///   - asset: The asset to resolve artwork for
    ///   - forceRefresh: When true, skip memory/disk and re-resolve from the network
    /// - Returns: The resolved image URL, or `nil` when the asset has no artwork or resolution failed
    func resolveImageURL(for asset: CounterpartyAsset, forceRefresh: Bool = false) async -> URL? {
        let assetName = asset.asset

        if forceRefresh {
            cache.removeValue(forKey: assetName)
        } else if let cached = cache[assetName] {
            return cached
        }

        if let existingTask = inFlightTasks[assetName] {
            return await existingTask.value
        }

        let task = Task<URL?, Never> { [weak self] in
            await self?.resolve(asset: asset, forceRefresh: forceRefresh) ?? nil
        }
        inFlightTasks[assetName] = task

        let resolved = await task.value
        cache.updateValue(resolved, forKey: assetName)
        inFlightTasks[assetName] = nil
        persistCache()
        return resolved
    }

    // MARK: - Private Methods

    private func resolve(asset: CounterpartyAsset, forceRefresh: Bool) async -> URL? {
        if let description = asset.description {
            switch CounterpartyArtworkURL.classify(description) {
            case .directImage(let url):
                return url
            case .fetch(let url):
                if let resolved = await fetchImageURL(from: url, forceRefresh: forceRefresh) {
                    return resolved
                }
            case .skip:
                break
            }
        }

        return await fetchFromHorizonMarket(assetName: asset.displayName, forceRefresh: forceRefresh)
    }

    private func fetchImageURL(from descriptionURL: URL, forceRefresh: Bool) async -> URL? {
        do {
            let (data, response) = try await data(from: descriptionURL, forceRefresh: forceRefresh)

            if let manifest = try? decoder.decode(CounterpartyAssetManifest.self, from: data),
               let urlString = manifest.resolvedImageURLString,
               let resolvedURL = CounterpartyArtworkURL.httpsURL(from: urlString) {
                return resolvedURL
            }

            if let mimeType = (response as? HTTPURLResponse)?.mimeType,
               CounterpartyArtworkURL.isRasterMIME(mimeType),
               descriptionURL.scheme?.lowercased() == "https" {
                return descriptionURL
            }

            return nil
        } catch {
            return nil
        }
    }

    /// Queries Horizon Market's public asset endpoint for artwork it has already resolved
    /// (and, for HTTP-only sources, proxied over HTTPS) for the given asset. Returns `nil`
    /// when Horizon doesn't recognize the asset or only has a generic placeholder for it.
    /// Audio/video tokens still use poster URLs (`image_large_url` / `image_url`).
    private func fetchFromHorizonMarket(assetName: String, forceRefresh: Bool) async -> URL? {
        guard let encodedName = assetName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://horizon.market/api/tokens/counterparty/\(encodedName)") else {
            return nil
        }

        do {
            let (data, _) = try await data(from: url, forceRefresh: forceRefresh)
            let decoded = try decoder.decode(HorizonAssetResponse.self, from: data)
            let media = decoded.data.media

            guard !media.imageIsPlaceholder else {
                return nil
            }

            guard let urlString = media.imageLargeURL ?? media.imageURL,
                  let httpsURL = CounterpartyArtworkURL.httpsURL(from: urlString) else {
                return nil
            }

            return httpsURL
        } catch {
            return nil
        }
    }

    private func data(from url: URL, forceRefresh: Bool) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        if forceRefresh {
            request.cachePolicy = .reloadIgnoringLocalCacheData
        }
        return try await session.data(for: request)
    }

    private static func loadCache(from diskURL: URL) -> [String: URL?] {
        guard let data = try? Data(contentsOf: diskURL) else { return [:] }

        if let payload = try? JSONDecoder().decode(DiskCache.self, from: data),
           payload.version == DiskCache.currentVersion {
            return payload.urls.mapValues { $0.isEmpty ? nil : URL(string: $0) }
        }

        // Unversioned pre-CIP-25 map used different ranking and no gateway rewrite — drop it.
        try? FileManager.default.removeItem(at: diskURL)
        return [:]
    }

    private func persistCache() {
        let payload = DiskCache(
            version: DiskCache.currentVersion,
            urls: Dictionary(uniqueKeysWithValues: cache.map { key, url in
                (key, url?.absoluteString ?? "")
            })
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: diskURL, options: .atomic)
    }
}

// MARK: - Horizon Market API Response

/// Minimal decodable shape for `GET https://horizon.market/api/tokens/counterparty/{asset}`.
/// Only the fields needed to resolve artwork are modeled here.
private struct HorizonAssetResponse: Decodable {
    let data: HorizonAssetData
}

private struct HorizonAssetData: Decodable {
    let media: HorizonAssetMedia
}

private struct HorizonAssetMedia: Decodable {
    let imageURL: String?
    let imageLargeURL: String?
    let imageIsPlaceholder: Bool

    enum CodingKeys: String, CodingKey {
        case imageURL = "image_url"
        case imageLargeURL = "image_large_url"
        case imageIsPlaceholder = "image_is_placeholder"
    }
}
