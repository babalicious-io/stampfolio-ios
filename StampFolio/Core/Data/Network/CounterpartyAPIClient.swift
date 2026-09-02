//
//  CounterpartyAPIClient.swift
//  StampFolio
//
//  API client for the Counterparty Core v2 REST API
//

import Foundation

/// API client for interacting with the Counterparty Core API (`https://api.counterparty.io:4000/v2`)
///
/// Reuses `NetworkError` (defined in `NetworkError.swift`) for consistent error handling
/// across API clients.
actor CounterpartyAPIClient {

    // MARK: - Properties

    private let baseURL = "https://api.counterparty.io:4000/v2"
    private let executor = NetworkRequestExecutor(cacheName: "counterparty_cache", memoryCapacityMB: 5, diskCapacityMB: 25)
    private let decoder: JSONDecoder

    /// Maximum number of pages to follow when paginating a wallet's balances.
    /// Safety cap to avoid unbounded requests for addresses holding a very large number of assets.
    private let maxBalancePages = 20
    private let balancesPageSize = 100

    // MARK: - Initialization

    init() {
        self.decoder = JSONDecoder()
    }

    // MARK: - Public Methods

    /// Fetch all Counterparty asset balances held by a wallet address, following pagination.
    /// - Parameters:
    ///   - address: Bitcoin wallet address
    ///   - forceRefresh: When true, bypasses cache and fetches from network
    /// - Returns: Array of asset balances owned by the wallet
    func fetchBalances(for address: String, forceRefresh: Bool = false) async throws -> [CounterpartyAssetBalance] {
        var allBalances: [CounterpartyAssetBalance] = []
        var cursor: Int?

        for _ in 0..<maxBalancePages {
            var endpoint = "\(baseURL)/addresses/\(address)/balances?verbose=true&limit=\(balancesPageSize)"
            if let cursor {
                endpoint += "&cursor=\(cursor)"
            }

            guard let url = URL(string: endpoint) else {
                throw NetworkError.invalidURL
            }

            let (data, _) = try await executor.perform(url, forceRefresh: forceRefresh)
            let response = try decoder.decode(CounterpartyBalancesResponse.self, from: data)

            allBalances.append(contentsOf: response.result)

            guard let nextCursor = response.nextCursor, response.result.count == balancesPageSize else {
                break
            }
            cursor = nextCursor
        }

        return allBalances
    }

    /// Check whether a wallet address holds any Counterparty assets
    /// - Parameter address: Bitcoin wallet address
    /// - Returns: Whether the wallet has at least one asset balance
    func validateWalletHasCounterpartyAssets(_ address: String) async throws -> Bool {
        let balances = try await fetchBalances(for: address)
        return !balances.isEmpty
    }

    /// Fetch full detail for a single asset (supply, description, issuance dates)
    /// - Parameter asset: The asset name (e.g. "XCP", "A95428956980101314")
    /// - Returns: Asset detail without market data
    func fetchAsset(_ asset: String) async throws -> CounterpartyAsset {
        let endpoint = "\(baseURL)/assets/\(asset)?verbose=true"

        guard let url = URL(string: endpoint) else {
            throw NetworkError.invalidURL
        }

        let (data, _) = try await executor.perform(url)
        let response = try decoder.decode(CounterpartyAssetResponse.self, from: data)
        return response.result
    }

    /// Fetch on-demand market-style data for an asset: holder count, open dispensers count, and floor price.
    /// Never throws — individual sub-requests fail silently (their fields are nil) so a detail sheet
    /// can still show core asset info even if the market-data calls fail.
    /// - Parameter asset: The asset name
    /// - Returns: Market data (fields are nil if the corresponding request failed)
    func fetchAssetMarketData(_ asset: String) async -> CounterpartyAssetMarketData {
        async let holderCountTask: Int? = try? fetchResultCount(endpoint: "\(baseURL)/assets/\(asset)/holders?limit=1")
        async let dispensersTask: (count: Int, floorPrice: Decimal?)? = try? fetchOpenDispensers(asset)

        let holderCount = await holderCountTask
        let dispensers = await dispensersTask

        return CounterpartyAssetMarketData(
            holderCount: holderCount,
            openDispensersCount: dispensers?.count,
            floorPriceBTC: dispensers?.floorPrice
        )
    }

    /// Fetch combined asset detail + market data for the detail sheet
    /// (mirrors `StampchainAPIClient.fetchStamp`'s per-item detail fetch)
    /// - Parameter asset: The asset name
    /// - Returns: Asset detail with market data populated
    func fetchAssetDetail(_ asset: String) async throws -> CounterpartyAsset {
        async let assetTask = fetchAsset(asset)
        async let marketTask = fetchAssetMarketData(asset)

        var result = try await assetTask
        result.marketData = await marketTask
        return result
    }

    // MARK: - Private Methods

    /// Fetch just the `result_count` field from a paginated endpoint (used for holder/dispenser counts)
    private func fetchResultCount(endpoint: String) async throws -> Int {
        guard let url = URL(string: endpoint) else {
            throw NetworkError.invalidURL
        }

        let (data, _) = try await executor.perform(url)
        let response = try decoder.decode(CounterpartyCountResponse.self, from: data)
        return response.resultCount ?? 0
    }

    /// Fetch the count of open dispensers and the lowest `satoshirate` (BTC floor price) among them
    private func fetchOpenDispensers(_ asset: String) async throws -> (count: Int, floorPrice: Decimal?) {
        let endpoint = "\(baseURL)/assets/\(asset)/dispensers?status=open&limit=1&sort=satoshirate:asc&verbose=true"

        guard let url = URL(string: endpoint) else {
            throw NetworkError.invalidURL
        }

        let (data, _) = try await executor.perform(url)
        let response = try decoder.decode(CounterpartyDispensersResponse.self, from: data)
        let floorPrice = response.result.first.flatMap { Decimal(string: $0.satoshirateNormalized ?? "") }
        return (response.resultCount ?? response.result.count, floorPrice)
    }

}

// MARK: - API Response Models

/// Response wrapper for the address balances endpoint
private struct CounterpartyBalancesResponse: Decodable {
    let result: [CounterpartyAssetBalance]
    let nextCursor: Int?
    let resultCount: Int?

    enum CodingKeys: String, CodingKey {
        case result
        case nextCursor = "next_cursor"
        case resultCount = "result_count"
    }
}

/// Response wrapper for the single-asset detail endpoint
private struct CounterpartyAssetResponse: Decodable {
    let result: CounterpartyAsset
}

/// Lightweight response wrapper used when only `result_count` is needed.
/// Deliberately omits `result`/`next_cursor` since their types vary by endpoint
/// (e.g. `/holders` returns a string cursor like `"balances_100016"`).
private struct CounterpartyCountResponse: Decodable {
    let resultCount: Int?

    enum CodingKeys: String, CodingKey {
        case resultCount = "result_count"
    }
}

/// Response wrapper for the dispensers endpoint (only the fields needed for floor price)
private struct CounterpartyDispensersResponse: Decodable {
    let result: [CounterpartyDispenserSummary]
    let resultCount: Int?

    enum CodingKeys: String, CodingKey {
        case result
        case resultCount = "result_count"
    }
}

private struct CounterpartyDispenserSummary: Decodable {
    let satoshirateNormalized: String?

    enum CodingKeys: String, CodingKey {
        case satoshirateNormalized = "satoshirate_normalized"
    }
}
