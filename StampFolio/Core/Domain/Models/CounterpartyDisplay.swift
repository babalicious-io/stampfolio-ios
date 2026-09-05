//
//  CounterpartyDisplay.swift
//  StampFolio
//
//  Model for displaying Counterparty assets with balance information
//

import Foundation

/// Wrapper for displaying a Counterparty asset alongside the user's balance information
struct CounterpartyDisplay: Identifiable {

    // MARK: - Properties

    let asset: CounterpartyAsset
    let balance: Double
    let divisible: Bool
    let walletAddress: String?

    // Loading state for on-demand market data (holders, dispensers, floor price)
    var isLoadingMarketData: Bool = false

    // MARK: - Computed Properties

    var id: String { asset.id }

    var holderCount: Int? {
        asset.marketData?.holderCount
    }

    var floorPrice: Decimal? {
        asset.marketData?.floorPriceBTC
    }

    /// Formatted balance, removing unnecessary decimals
    var formattedBalance: String {
        if balance.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", balance)
        }
        return String(format: "%g", balance)
    }

    /// Detail-sheet balance: grouping separators and 8 decimals when divisible
    var formattedDetailBalance: String {
        AssetQuantityFormat.string(from: balance, divisible: divisible)
    }

    // MARK: - Initialization

    /// Memberwise initializer
    init(
        asset: CounterpartyAsset,
        balance: Double,
        divisible: Bool,
        walletAddress: String? = nil,
        isLoadingMarketData: Bool = false
    ) {
        self.asset = asset
        self.balance = balance
        self.divisible = divisible
        self.walletAddress = walletAddress
        self.isLoadingMarketData = isLoadingMarketData
    }

    /// Create from a `CounterpartyAssetBalance` (API response row)
    init(from balance: CounterpartyAssetBalance) {
        self.asset = CounterpartyAsset(
            asset: balance.asset,
            assetLongname: balance.assetLongname,
            issuer: balance.assetInfo?.issuer,
            owner: balance.assetInfo?.owner,
            divisible: balance.assetInfo?.divisible ?? false,
            locked: balance.assetInfo?.locked ?? false,
            supply: balance.assetInfo?.supply ?? 0,
            supplyNormalized: Self.normalizedSupply(from: balance.assetInfo),
            description: balance.assetInfo?.description,
            mimeType: nil,
            firstIssuanceBlockTime: nil,
            lastIssuanceBlockTime: nil
        )
        self.balance = balance.balance
        self.divisible = balance.assetInfo?.divisible ?? false
        self.walletAddress = balance.address
    }

    /// Prefer API-normalized supply; fall back to converting raw supply by divisibility.
    private static func normalizedSupply(from info: CounterpartyAssetInfo?) -> String {
        if let normalized = info?.supplyNormalized, !normalized.isEmpty {
            return normalized
        }
        guard let supply = info?.supply else { return "0" }
        if info?.divisible == true {
            return String(Double(supply) / 100_000_000.0)
        }
        return String(supply)
    }

    /// Whether this asset matches a free-text search query
    func matchesSearch(_ query: String) -> Bool {
        let asset = self.asset
        if asset.asset.localizedCaseInsensitiveContains(query) { return true }
        if asset.displayName.localizedCaseInsensitiveContains(query) { return true }
        if let longname = asset.assetLongname, longname.localizedCaseInsensitiveContains(query) { return true }
        if let issuer = asset.issuer, issuer.localizedCaseInsensitiveContains(query) { return true }
        if let owner = asset.owner, owner.localizedCaseInsensitiveContains(query) { return true }
        return false
    }
}
