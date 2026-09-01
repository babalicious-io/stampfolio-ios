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

    // Loading state for on-demand asset detail (holders, dispensers, floor price)
    var isLoadingDetail: Bool = false

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

    // MARK: - Initialization

    /// Memberwise initializer
    init(
        asset: CounterpartyAsset,
        balance: Double,
        divisible: Bool,
        walletAddress: String? = nil,
        isLoadingDetail: Bool = false
    ) {
        self.asset = asset
        self.balance = balance
        self.divisible = divisible
        self.walletAddress = walletAddress
        self.isLoadingDetail = isLoadingDetail
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
            supply: 0,
            supplyNormalized: "0",
            description: balance.assetInfo?.description,
            mimeType: nil,
            firstIssuanceBlockTime: nil,
            lastIssuanceBlockTime: nil
        )
        self.balance = balance.balance
        self.divisible = balance.assetInfo?.divisible ?? false
        self.walletAddress = balance.address
    }
}

// MARK: - Sample Data

extension CounterpartyDisplay {

    /// Sample display asset for previews
    static let sample = CounterpartyDisplay(
        asset: .sample,
        balance: 31_000_000,
        divisible: true,
        walletAddress: "bc1qkqqre5xuqk60xtt93j297zgg7t6x0ul7gwjmv4"
    )
}
