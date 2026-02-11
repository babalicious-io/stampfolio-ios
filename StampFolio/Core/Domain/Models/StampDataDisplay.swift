//
//  DisplayStamp.swift
//  StampFolio
//
//  Model for displaying stamps with balance information
//

import Foundation

/// Wrapper for displaying stamps with their balance information
struct StampDataDisplay: Identifiable {
    let stamp: StampData
    let balance: Double?
    let divisible: Int
    let walletAddress: String?
    
    // Market data (fetched on-demand)
    var marketData: StampMarketData?
    var isLoadingMarketData: Bool = false
    
    var id: Int { stamp.id }
    
    // Computed properties for UI
    var holderCount: Int? {
        marketData?.holderCount
    }
    
    var floorPrice: Decimal? {
        marketData?.floorPriceBTC
    }
    
    /// Formatted quantity for display
    var formattedQuantity: String {
        let quantity = balance ?? Double(stamp.editionsSupply)
        
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
        let totalSupply = Double(stamp.editionsSupply)
        
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
    
    /// Create from WalletBalanceData
    init(from walletBalance: WalletBalanceData) {
        self.stamp = StampData(
            stampType: walletBalance.stampType ?? "classic",
            assetId: walletBalance.assetId,
            stampId: walletBalance.stampId,
            counterpartyId: walletBalance.counterpartyId,
            creatorAddy: walletBalance.creatorAddy,
            creatorName: walletBalance.creatorName,
            editionsSupply: walletBalance.editionsSupply ?? Int(walletBalance.balance),
            fileType: walletBalance.fileType,
            fileSize: nil,
            divisible: walletBalance.divisible,
            locked: walletBalance.locked,
            keyburn: nil,
            blockTime: nil,
            blockIndex: nil,
            txHash: walletBalance.txHash,
            fileHash: nil,
            marketData: nil,
            stampUrl: walletBalance.stampUrl
        )
        self.balance = walletBalance.balance
        self.divisible = walletBalance.divisible
        self.walletAddress = walletBalance.ownerAddy
    }
    
    /// Create from StampData (no balance info)
    init(from stamp: StampData) {
        self.stamp = stamp
        self.balance = nil
        self.divisible = stamp.divisible
        self.walletAddress = nil
    }
}
