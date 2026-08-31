//
//  CounterpartyAssetImageResolver.swift
//  StampFolio
//
//  Resolves the real artwork URL for a Counterparty asset from its `description` field
//

import Foundation

/// Resolves a Counterparty asset's image URL.
///
/// Counterparty assets don't carry an image URL directly — artwork (when it exists) is hosted
/// externally and referenced indirectly through the asset's `description` field, which is
/// sometimes a URL to a JSON manifest (`CounterpartyAssetManifest`) containing the real image
/// URL, and sometimes a direct link to the image itself. Most assets have a plain-text or empty
/// description and simply have no artwork, in which case this resolver returns `nil` without
/// making any network request.
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
    }

    // MARK: - Public Methods

    /// Resolve the artwork URL for a Counterparty asset, if any.
    /// - Parameter asset: The asset to resolve artwork for
    /// - Returns: The resolved image URL, or `nil` when the asset has no artwork or resolution failed
    func resolveImageURL(for asset: CounterpartyAsset) async -> URL? {
        let assetName = asset.asset

        if let cached = cache[assetName] {
            return cached
        }

        if let existingTask = inFlightTasks[assetName] {
            return await existingTask.value
        }

        guard asset.descriptionIsURL,
              let description = asset.description,
              let descriptionURL = URL(string: description) else {
            cache.updateValue(nil, forKey: assetName)
            return nil
        }

        let task = Task<URL?, Never> { [weak self] in
            await self?.fetchImageURL(from: descriptionURL) ?? nil
        }
        inFlightTasks[assetName] = task

        let resolved = await task.value
        cache.updateValue(resolved, forKey: assetName)
        inFlightTasks[assetName] = nil
        return resolved
    }

    // MARK: - Private Methods

    private func fetchImageURL(from descriptionURL: URL) async -> URL? {
        do {
            let (data, response) = try await session.data(from: descriptionURL)

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
}
