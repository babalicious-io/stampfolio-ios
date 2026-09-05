//
//  CounterpartyAsset.swift
//  StampFolio
//
//  Domain model representing a Counterparty asset
//

import Foundation

/// Represents a Counterparty asset from the Counterparty Core API (`GET /v2/assets/{asset}`)
struct CounterpartyAsset: Identifiable, Codable, Hashable, Sendable {

    // MARK: - Properties

    /// Short asset name (e.g. "XCP", "A95428956980101314")
    let asset: String

    /// Human-readable long name for numeric/sub assets (nil for named assets)
    let assetLongname: String?

    /// Current issuer address (nil for XCP)
    let issuer: String?

    /// Current owner address (nil for XCP)
    let owner: String?

    /// Whether the asset supports fractional quantities
    let divisible: Bool

    /// Whether issuance has been permanently locked
    let locked: Bool

    /// Total supply in the asset's smallest unit
    let supply: Int64

    /// Total supply, already divisibility-adjusted, as a decimal string
    let supplyNormalized: String

    /// Free-text asset description (sometimes a URL to a JSON manifest with icon/traits)
    let description: String?

    /// MIME type recorded for the asset's description/content, if any
    let mimeType: String?

    /// Block time of the first issuance (Unix seconds)
    let firstIssuanceBlockTime: Int?

    /// Block time of the most recent issuance (Unix seconds)
    let lastIssuanceBlockTime: Int?

    /// Block index of the first issuance
    let firstIssuanceBlockIndex: Int?

    /// Transaction hash of the first issuance, fetched on-demand from `/issuances`
    var firstIssuanceTxHash: String?

    /// Market-style data (holder count, open dispensers, floor price) fetched on-demand
    var marketData: CounterpartyAssetMarketData?

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case asset
        case assetLongname = "asset_longname"
        case issuer
        case owner
        case divisible
        case locked
        case supply
        case supplyNormalized = "supply_normalized"
        case description
        case mimeType = "mime_type"
        case firstIssuanceBlockTime = "first_issuance_block_time"
        case lastIssuanceBlockTime = "last_issuance_block_time"
        case firstIssuanceBlockIndex = "first_issuance_block_index"
    }

    // MARK: - Initialization

    init(
        asset: String,
        assetLongname: String?,
        issuer: String?,
        owner: String?,
        divisible: Bool,
        locked: Bool,
        supply: Int64,
        supplyNormalized: String,
        description: String?,
        mimeType: String?,
        firstIssuanceBlockTime: Int?,
        lastIssuanceBlockTime: Int?,
        firstIssuanceBlockIndex: Int? = nil,
        firstIssuanceTxHash: String? = nil,
        marketData: CounterpartyAssetMarketData? = nil
    ) {
        self.asset = asset
        self.assetLongname = assetLongname
        self.issuer = issuer
        self.owner = owner
        self.divisible = divisible
        self.locked = locked
        self.supply = supply
        self.supplyNormalized = supplyNormalized
        self.description = description
        self.mimeType = mimeType
        self.firstIssuanceBlockTime = firstIssuanceBlockTime
        self.lastIssuanceBlockTime = lastIssuanceBlockTime
        self.firstIssuanceBlockIndex = firstIssuanceBlockIndex
        self.firstIssuanceTxHash = firstIssuanceTxHash
        self.marketData = marketData
    }

    /// Custom decoder (marketData is fetched separately, not part of the `/assets/{asset}` payload)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.asset = try container.decode(String.self, forKey: .asset)
        self.assetLongname = try container.decodeIfPresent(String.self, forKey: .assetLongname)
        self.issuer = try container.decodeIfPresent(String.self, forKey: .issuer)
        self.owner = try container.decodeIfPresent(String.self, forKey: .owner)
        self.divisible = try container.decode(Bool.self, forKey: .divisible)
        self.locked = try container.decode(Bool.self, forKey: .locked)
        self.supply = try container.decode(Int64.self, forKey: .supply)
        self.supplyNormalized = try container.decode(String.self, forKey: .supplyNormalized)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
        self.firstIssuanceBlockTime = try container.decodeIfPresent(Int.self, forKey: .firstIssuanceBlockTime)
        self.lastIssuanceBlockTime = try container.decodeIfPresent(Int.self, forKey: .lastIssuanceBlockTime)
        self.firstIssuanceBlockIndex = try container.decodeIfPresent(Int.self, forKey: .firstIssuanceBlockIndex)
        self.firstIssuanceTxHash = nil
        self.marketData = nil
    }

    // MARK: - Computed Properties

    /// Identifiable conformance - uses the short asset name
    var id: String { asset }

    /// The display name for this asset (falls back to the short name)
    var displayName: String {
        assetLongname ?? asset
    }

    /// Whether this is a numeric sub-asset (e.g. "A95428956980101314.SUBASSET")
    var isSubasset: Bool {
        assetLongname != nil
    }

    /// Whether this is a numeric asset (auto-generated "A..." name rather than a chosen name)
    var isNumericAsset: Bool {
        asset.hasPrefix("A") && asset.dropFirst().allSatisfy { $0.isNumber }
    }

    /// Whether the description looks like a URL to a JSON manifest (common convention for token icons/art)
    var descriptionIsURL: Bool {
        guard let description = description else { return false }
        return description.hasPrefix("http://") || description.hasPrefix("https://")
    }

    /// Date of the first issuance, if known
    var firstIssuanceDate: Date? {
        firstIssuanceBlockTime.map { Date(timeIntervalSince1970: TimeInterval($0)) }
    }

    /// Date of the most recent issuance, if known
    var lastIssuanceDate: Date? {
        lastIssuanceBlockTime.map { Date(timeIntervalSince1970: TimeInterval($0)) }
    }

    /// Formatted total supply, removing unnecessary decimals
    var formattedSupply: String {
        guard let value = Double(supplyNormalized) else { return supplyNormalized }
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%g", value)
    }

    /// Whole-token supply for edition filters (1 vs many). Uses normalized supply so divisible assets compare correctly.
    var editionCount: Double {
        Double(supplyNormalized) ?? 0
    }

    /// URL to the asset's page on Horizon Market
    var explorerURL: URL? {
        let name = displayName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? asset
        return URL(string: "https://horizon.market/assets/\(name)")
    }
}

// MARK: - Sample Data

extension CounterpartyAsset {

    /// Sample asset for previews and testing
    static let sample = CounterpartyAsset(
        asset: "XCPIANS",
        assetLongname: nil,
        issuer: "1GG5F8DrvQ5TAcroB5WQPjCUxPXzZxEhp4",
        owner: "1GG5F8DrvQ5TAcroB5WQPjCUxPXzZxEhp4",
        divisible: true,
        locked: false,
        supply: 3_100_000_000_000_000,
        supplyNormalized: "31000000.00000000",
        description: "https://xcp.fun/XCPIANS.json",
        mimeType: "text/plain",
        firstIssuanceBlockTime: 1_700_000_000,
        lastIssuanceBlockTime: 1_700_000_000,
        firstIssuanceBlockIndex: 390_000,
        firstIssuanceTxHash: "e94be2793462692ca8fea3a54dd90ff4b18735196a2bc426382c11959533c8ca",
        marketData: CounterpartyAssetMarketData(
            holderCount: 128,
            openDispensersCount: 2,
            floorPriceBTC: Decimal(string: "0.00000012")
        )
    )
}
