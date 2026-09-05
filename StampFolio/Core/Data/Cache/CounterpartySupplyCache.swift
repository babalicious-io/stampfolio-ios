//
//  CounterpartySupplyCache.swift
//  StampFolio
//
//  Persistent cache of confirmed Counterparty asset supply (and issuance timestamps).
//  Verbose balances omit supply, so StampFolio confirms it via GET /v2/assets/{asset}
//  and stores the result across launches.
//

import Foundation

/// Confirmed supply snapshots keyed by short asset name.
///
/// Memory + `Caches/counterparty_supply.json`. Not cleared on app background
/// (`detailCache` is). Bypassed for network refetch when `forceRefresh` is true;
/// cached values are still overlaid for instant display until the refetch lands.
actor CounterpartySupplyCache {

    // MARK: - Singleton

    static let shared = CounterpartySupplyCache()

    // MARK: - Nested Types

    struct Entry: Codable, Hashable, Sendable {
        let supply: Int64
        let supplyNormalized: String
        let locked: Bool
        let mimeType: String?
        let firstIssuanceBlockTime: Int?
        let lastIssuanceBlockTime: Int?
        let firstIssuanceBlockIndex: Int?

        init?(asset: CounterpartyAsset) {
            guard let supply = asset.supply,
                  let supplyNormalized = asset.supplyNormalized,
                  !supplyNormalized.isEmpty else {
                return nil
            }
            self.supply = supply
            self.supplyNormalized = supplyNormalized
            self.locked = asset.locked
            self.mimeType = asset.mimeType
            self.firstIssuanceBlockTime = asset.firstIssuanceBlockTime
            self.lastIssuanceBlockTime = asset.lastIssuanceBlockTime
            self.firstIssuanceBlockIndex = asset.firstIssuanceBlockIndex
        }

        func applied(to asset: CounterpartyAsset) -> CounterpartyAsset {
            asset.withConfirmedSupply(
                supply: supply,
                supplyNormalized: supplyNormalized,
                mimeType: mimeType,
                firstIssuanceBlockTime: firstIssuanceBlockTime,
                lastIssuanceBlockTime: lastIssuanceBlockTime,
                firstIssuanceBlockIndex: firstIssuanceBlockIndex
            )
        }
    }

    // MARK: - Properties

    private var cache: [String: Entry] = [:]
    private let diskURL: URL

    // MARK: - Initialization

    private init() {
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.diskURL = cachesDir.appendingPathComponent("counterparty_supply.json")
        self.cache = Self.loadCache(from: diskURL)
    }

    // MARK: - Public Methods

    func entry(for assetName: String) -> Entry? {
        cache[assetName]
    }

    func entries(for assetNames: [String]) -> [String: Entry] {
        Dictionary(uniqueKeysWithValues: assetNames.compactMap { name in
            cache[name].map { (name, $0) }
        })
    }

    func store(_ entry: Entry, for assetName: String, persist: Bool = true) {
        cache[assetName] = entry
        if persist {
            persistCache()
        }
    }

    func store(_ entries: [String: Entry]) {
        guard !entries.isEmpty else { return }
        for (name, entry) in entries {
            cache[name] = entry
        }
        persistCache()
    }

    func persist() {
        persistCache()
    }

    // MARK: - Private Methods

    private static func loadCache(from diskURL: URL) -> [String: Entry] {
        guard let data = try? Data(contentsOf: diskURL),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func persistCache() {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: diskURL, options: .atomic)
    }
}
