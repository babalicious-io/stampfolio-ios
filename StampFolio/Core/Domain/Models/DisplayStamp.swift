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
    let walletAddress: String?
    
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
    
    /// Formatted balance with total supply (e.g., "2/69")
    var formattedBalanceWithSupply: String {
        let userBalance = balance ?? 0.0
        let totalSupply = Double(stamp.supply)
        
        if divisible == 1 {
            // Convert from satoshi-like units (100,000,000 = 1)
            let actualBalance = userBalance / 100_000_000.0
            let actualSupply = totalSupply / 100_000_000.0
            
            // Format numbers, removing unnecessary decimals
            let balanceStr = formatNumber(actualBalance)
            let supplyStr = formatNumber(actualSupply)
            
            return "\(balanceStr)/\(supplyStr)"
        } else {
            // Non-divisible stamps - show as integers
            return "\(Int(userBalance))/\(Int(totalSupply))"
        }
    }
    
    // MARK: - Private Helpers
    
    /// Formats a number, removing trailing decimals if it's a whole number
    private func formatNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%g", value)
        }
    }
    
    /// Create from StampBalance
    init(from stampBalance: StampBalance) {
        self.stamp = Stamp(
            stampType: "STAMP",
            stampId: stampBalance.stamp,
            counterpartyId: stampBalance.cpid,
            creatorAddy: stampBalance.creatorAddy,
            creatorName: stampBalance.creatorName,
            supply: stampBalance.supply ?? Int(stampBalance.balance),
            stampMimetype: stampBalance.stampMimetype,
            fileSize: nil,
            divisible: stampBalance.divisible,
            blockTime: nil,
            blockIndex: nil,
            txHash: stampBalance.txHash,
            fileHash: nil,
            marketData: nil,
            stampUrl: stampBalance.stampUrl
        )
        self.balance = stampBalance.balance
        self.divisible = stampBalance.divisible
        self.walletAddress = stampBalance.address
    }
    
    /// Create from Stamp (no balance info)
    init(from stamp: Stamp) {
        self.stamp = stamp
        self.balance = nil
        self.divisible = stamp.divisible
        self.walletAddress = nil
    }
}
