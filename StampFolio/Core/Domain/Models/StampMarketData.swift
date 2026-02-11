//
//  MarketData.swift
//  StampFolio
//
//  Market data associated with a Bitcoin Stamp
//

import Foundation

/// Market data for a stamp (floor price, holder count, etc.)
struct StampMarketData: Codable, Hashable, Sendable {
    
    // MARK: - Properties
    
    /// Floor price in BTC
    let floorPriceBTC: Decimal?
    
    /// Number of unique holders
    let holderCount: Int?
    
    /// 24-hour trading volume in BTC
    let volume24hBTC: Decimal?
    
    /// Data quality score (0-100)
    let dataQualityScore: Int
    
    /// Number of active dispensers/listings
    let openDispensersCount: Int?
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case floorPriceBTC = "floor_price_btc"
        case holderCount = "holder_count"
        case volume24hBTC = "volume_24h_btc"
        case dataQualityScore = "data_quality_score"
        case openDispensersCount = "open_dispensers_count"
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

extension StampMarketData {
    
    /// Sample market data for previews
    static let sample = StampMarketData(
        floorPriceBTC: Decimal(string: "0.00001234"),
        holderCount: 42,
        volume24hBTC: Decimal(string: "0.001"),
        dataQualityScore: 85,
        openDispensersCount: 3
    )
}
