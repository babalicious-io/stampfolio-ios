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
/// Counterparty assets don't carry an image URL directly — artwork (when it exists) is hosted
/// externally and referenced indirectly through the asset's `description` field, which is
/// sometimes a URL to a JSON manifest (`CounterpartyAssetManifest`) containing the real image
/// URL, and sometimes a direct link to the image itself.
///
/// Many of these `description` links date back to 2014-2016 (the original "Rare Pepe" era) and
/// their hosts have since died, moved, or gone HTTP-only. Marketplaces like Horizon Market and
/// pepe.wtf solve this by maintaining their own permanent, re-hosted archive of this artwork
/// (S3/Arweave) instead of depending on those fragile original hosts. Horizon Market exposes
/// this archive through a public, CORS-open JSON endpoint
/// (`https://horizon.market/api/tokens/counterparty/{asset}`), so this resolver tries the
/// on-chain `description` first (cheap, no third party involved, works for currently-alive
/// hosts) and falls back to Horizon's pre-resolved artwork when that fails or the description
/// isn't a URL at all. Most assets have no artwork anywhere, in which case this returns `nil`.
///
/// Resolved URLs (including "no artwork") are kept in memory and persisted under Caches so
/// cold launches skip Horizon and dead hosts. Settings wallet refresh passes `forceRefresh`
/// to re-resolve in case artwork was archived later.
actor CounterpartyAssetImageResolver {

    // MARK: - Singleton

    static let shared = CounterpartyAssetImageResolver()

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
        if asset.descriptionIsURL,
           let description = asset.description,
           let descriptionURL = URL(string: description),
           let resolved = await fetchImageURL(from: descriptionURL, forceRefresh: forceRefresh) {
            return resolved
        }

        // On-chain description missing, non-URL, or its host is dead/broken — try Horizon
        // Market's pre-resolved archive before giving up.
        return await fetchFromHorizonMarket(assetName: asset.displayName, forceRefresh: forceRefresh)
    }

    private func fetchImageURL(from descriptionURL: URL, forceRefresh: Bool) async -> URL? {
        do {
            let (data, response) = try await data(from: descriptionURL, forceRefresh: forceRefresh)

            if let manifest = try? decoder.decode(CounterpartyAssetManifest.self, from: data),
               let urlString = manifest.resolvedImageURLString,
               let resolvedURL = URL(string: urlString) {
                return resolvedURL
            }

            // Not a JSON manifest — if the description URL itself served image bytes,
            // treat it as a direct link to the artwork.
            if let mimeType = (response as? HTTPURLResponse)?.mimeType, mimeType.hasPrefix("image/") {
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
    private func fetchFromHorizonMarket(assetName: String, forceRefresh: Bool) async -> URL? {
        guard let encodedName = assetName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://horizon.market/api/tokens/counterparty/\(encodedName)") else {
            return nil
        }

        do {
            let (data, _) = try await data(from: url, forceRefresh: forceRefresh)
            let decoded = try decoder.decode(HorizonAssetResponse.self, from: data)
            let media = decoded.data.media

            guard !media.imageIsPlaceholder, media.kind == "image" else {
                return nil
            }

            guard let urlString = media.imageLargeURL ?? media.imageURL else {
                return nil
            }

            return URL(string: urlString)
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
        guard let data = try? Data(contentsOf: diskURL),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        // Empty string is the on-disk sentinel for "no artwork"
        return decoded.mapValues { $0.isEmpty ? nil : URL(string: $0) }
    }

    private func persistCache() {
        let payload: [String: String] = Dictionary(uniqueKeysWithValues: cache.map { key, url in
            (key, url?.absoluteString ?? "")
        })
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
    let kind: String
    let imageURL: String?
    let imageLargeURL: String?
    let imageIsPlaceholder: Bool

    enum CodingKeys: String, CodingKey {
        case kind
        case imageURL = "image_url"
        case imageLargeURL = "image_large_url"
        case imageIsPlaceholder = "image_is_placeholder"
    }
}
