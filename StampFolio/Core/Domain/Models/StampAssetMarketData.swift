//
//  StampAssetMarketData.swift
//  StampFolio
//
//  Market data associated with a Bitcoin Stamp
//

import Foundation

/// Market data for a stamp (floor price, holder count, etc.)
struct StampAssetMarketData: Codable, Hashable, Sendable {
    
    // MARK: - Properties
    
    /// Floor price in BTC
    let floorPriceBTC: Decimal?
    
    /// Number of unique holders
    let holderCount: Int?
    
    /// Number of active dispensers/listings
    let openDispensersCount: Int?
    
    // MARK: - Nested Dispensers Structure
    
    private struct Dispensers: Codable {
        let openCount: Int?
        
        enum CodingKeys: String, CodingKey {
            case openCount = "open_count"
        }
    }
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case floorPriceBTC = "floor_price_btc"
        case holderCount = "holder_count"
        case dispensers
    }
    
    // MARK: - Custom Decoding
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        floorPriceBTC = try container.decodeIfPresent(Decimal.self, forKey: .floorPriceBTC)
        holderCount = try container.decodeIfPresent(Int.self, forKey: .holderCount)
        
        // Decode nested dispensers.open_count
        if let dispensers = try container.decodeIfPresent(Dispensers.self, forKey: .dispensers) {
            openDispensersCount = dispensers.openCount
        } else {
            openDispensersCount = nil
        }
    }
    
    // MARK: - Custom Encoding
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(floorPriceBTC, forKey: .floorPriceBTC)
        try container.encodeIfPresent(holderCount, forKey: .holderCount)
        
        // Encode as nested dispensers structure
        if let count = openDispensersCount {
            let dispensers = Dispensers(openCount: count)
            try container.encode(dispensers, forKey: .dispensers)
        }
    }
    
    // MARK: - Memberwise Initializer
    
    init(
        floorPriceBTC: Decimal?,
        holderCount: Int?,
        openDispensersCount: Int?
    ) {
        self.floorPriceBTC = floorPriceBTC
        self.holderCount = holderCount
        self.openDispensersCount = openDispensersCount
    }
    
    // MARK: - Computed Properties
    
    /// Formatted floor price string
    var formattedFloorPrice: String? {
        guard let price = floorPriceBTC else { return nil }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 8
        formatter.minimumFractionDigits = 0
        
        if let formatted = formatter.string(from: price as NSDecimalNumber) {
            return "\(formatted) BTC"
        }
        return nil
    }
    
    /// Formatted holder count string
    var formattedHolderCount: String? {
        guard let count = holderCount else { return nil }
        return "\(count) holder\(count == 1 ? "" : "s")"
    }
    
    /// Whether there are active listings
    var hasActiveListings: Bool {
        guard let count = openDispensersCount else { return false }
        return count > 0
    }
}

// MARK: - Sample Data

extension StampAssetMarketData {
    
    /// Sample market data for previews
    static let sample = StampAssetMarketData(
        floorPriceBTC: Decimal(string: "0.00001234"),
        holderCount: 42,
        openDispensersCount: 3
    )
}
