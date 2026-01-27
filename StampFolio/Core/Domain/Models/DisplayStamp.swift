//
//  DisplayStamp.swift
//  StampFolio
//
//  Model for displaying stamps with balance information
//

import Foundation

/// Wrapper for displaying stamps with their balance information
struct DisplayStamp: Identifiable {
    let stamp: Stamp
    let balance: Double?
    let divisible: Int
    
    var id: Int { stamp.id }
    
    /// Formatted quantity for display
    var formattedQuantity: String {
        let quantity = balance ?? Double(stamp.supply)
        
        // If divisible, convert from satoshi-like units (100,000,000 = 1)
        if divisible == 1 {
            let actualAmount = quantity / 100_000_000.0
            // Remove decimals if it's a whole number
            if actualAmount.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f", actualAmount)
            } else {
                return String(format: "%g", actualAmount)
            }
        } else {
            // Non-divisible stamps - show as integer
            return String(format: "%.0f", quantity)
        }
    }
    
    /// Create from StampBalance
    init(from stampBalance: StampBalance) {
        self.stamp = Stamp(
            id: stampBalance.stamp,
            cpid: stampBalance.cpid,
            creator: stampBalance.creator,
            creatorName: stampBalance.creatorName,
            stampUrl: stampBalance.stampUrl,
            stampMimetype: stampBalance.stampMimetype,
            supply: stampBalance.supply ?? Int(stampBalance.balance),
            divisible: stampBalance.divisible,
            blockTime: nil,
            blockIndex: nil,
            txHash: stampBalance.txHash,
            ident: "STAMP",
            fileHash: nil,
            fileSizeBytes: nil,
            marketData: nil
        )
        self.balance = stampBalance.balance
        self.divisible = stampBalance.divisible
    }
    
    /// Create from Stamp (no balance info)
    init(from stamp: Stamp) {
        self.stamp = stamp
        self.balance = nil
        self.divisible = stamp.divisible
    }
}
