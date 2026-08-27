//
//  CounterpartyAssetBalance.swift
//  StampFolio
//
//  Model for a single asset balance row from the Counterparty API
//

import Foundation

/// Represents a single asset balance held by an address, as returned by
/// `GET /v2/addresses/{address}/balances`
struct CounterpartyAssetBalance: Identifiable, Codable, Hashable, Sendable {

    // MARK: - Properties

    /// The address holding this balance
    let address: String

    /// Asset name (e.g. "XCP", "A95428956980101314")
    let asset: String

    /// Human-readable long name for numeric/sub assets (nil for named assets)
    let assetLongname: String?

    /// Raw quantity in the asset's smallest unit
    let quantity: Int64

    /// Quantity already adjusted for divisibility, as a decimal string (e.g. "12.50000000" or "1")
    let quantityNormalized: String

    /// Nested asset metadata (present because requests are made with `verbose=true`)
    let assetInfo: CounterpartyAssetInfo?

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case address
        case asset
        case assetLongname = "asset_longname"
        case quantity
        case quantityNormalized = "quantity_normalized"
        case assetInfo = "asset_info"
    }

    // MARK: - Computed Properties

    var id: String { asset }

    /// Balance as a `Double`, already divisibility-adjusted
    var balance: Double {
        Double(quantityNormalized) ?? 0
    }

    /// The display name for this asset (falls back to the short name)
    var displayName: String {
        assetLongname ?? asset
    }
}

/// Nested asset metadata included on balance/holder responses when `verbose=true`
struct CounterpartyAssetInfo: Codable, Hashable, Sendable {

    /// Human-readable long name for numeric/sub assets
    let assetLongname: String?

    /// Free-text asset description (sometimes a URL to a JSON manifest with icon/traits)
    let description: String?

    /// Current issuer address (nil for XCP)
    let issuer: String?

    /// Whether the asset supports fractional quantities
    let divisible: Bool

    /// Whether issuance has been permanently locked
    let locked: Bool

    /// Current owner address (nil for XCP)
    let owner: String?

    enum CodingKeys: String, CodingKey {
        case assetLongname = "asset_longname"
        case description
        case issuer
        case divisible
        case locked
        case owner
    }
}

// MARK: - Sample Data

extension CounterpartyAssetBalance {

    /// Sample balance for previews and testing
    static let sample = CounterpartyAssetBalance(
        address: "bc1qkqqre5xuqk60xtt93j297zgg7t6x0ul7gwjmv4",
        asset: "XCPIANS",
        assetLongname: nil,
        quantity: 3_100_000_000_000_000,
        quantityNormalized: "31000000.00000000",
        assetInfo: CounterpartyAssetInfo(
            assetLongname: nil,
            description: "https://xcp.fun/XCPIANS.json",
            issuer: "1GG5F8DrvQ5TAcroB5WQPjCUxPXzZxEhp4",
            divisible: true,
            locked: false,
            owner: "1GG5F8DrvQ5TAcroB5WQPjCUxPXzZxEhp4"
        )
    )
}
