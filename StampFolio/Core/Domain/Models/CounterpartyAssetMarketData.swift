//
//  CounterpartyAssetMarketData.swift
//  StampFolio
//
//  Market-style data associated with a Counterparty asset
//

import Foundation

/// Market-style data for a Counterparty asset (holder count, open dispensers, floor price)
struct CounterpartyAssetMarketData: Codable, Hashable, Sendable {

    /// Number of unique addresses currently holding this asset
    let holderCount: Int?

    /// Number of currently open dispensers (BTC-priced listings) for this asset
    let openDispensersCount: Int?

    /// Lowest price (in BTC per unit) among open dispensers, if any
    let floorPriceBTC: Decimal?

    // MARK: - Computed Properties

    /// Formatted holder count string
    var formattedHolderCount: String? {
        guard let count = holderCount else { return nil }
        return "\(count) holder\(count == 1 ? "" : "s")"
    }

    /// Whether there are active dispenser listings
    var hasActiveListings: Bool {
        guard let count = openDispensersCount else { return false }
        return count > 0
    }

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
}
