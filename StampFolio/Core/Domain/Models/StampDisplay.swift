//
//  StampDisplay.swift
//  StampFolio
//
//  Model for displaying stamps with balance information
//

import Foundation

/// Wrapper for displaying stamps with their balance information
struct StampDisplay: Identifiable {
    let asset: StampAsset
    let balance: Double
    let divisible: Bool
    let walletAddress: String?
    
    // Market data (fetched on-demand)
    var marketData: StampAssetMarketData?
    var isLoadingMarketData: Bool = false
    
    var id: Int { asset.id }
    
    // Computed properties for UI
    var holderCount: Int? {
        marketData?.holderCount
    }
    
    var floorPrice: Decimal? {
        marketData?.floorPriceBTC
    }
    
    /// Formatted balance for display
    var formattedBalance: String {
        // If divisible, convert from satoshi-like units (100,000,000 = 1)
        if divisible {
            let actualAmount = balance / 100_000_000.0
            // Remove decimals if it's a whole number
            if actualAmount.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f", actualAmount)
            } else {
                return String(format: "%g", actualAmount)
            }
        } else {
            // Non-divisible stamps - show as integer
            return String(format: "%.0f", balance)
        }
    }
    
    /// Formatted balance with total supply (e.g., "2/69")
    var formattedBalanceWithSupply: String {
        let userBalance = balance
        let totalSupply = Double(asset.editionsSupply)
        
        if divisible {
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
    
    /// Memberwise initializer
    init(
        asset: StampAsset,
        balance: Double,
        divisible: Bool,
        walletAddress: String? = nil,
        marketData: StampAssetMarketData? = nil,
        isLoadingMarketData: Bool = false
    ) {
        self.asset = asset
        self.balance = balance
        self.divisible = divisible
        self.walletAddress = walletAddress
        self.marketData = marketData
        self.isLoadingMarketData = isLoadingMarketData
    }
    
    /// Create from StampAssetBalance
    init(from walletBalance: StampAssetBalance) {
        self.asset = StampAsset(
            stampType: walletBalance.stampType ?? "classic",
            ident: walletBalance.ident,
            stampId: walletBalance.stampId,
            counterpartyId: walletBalance.counterpartyId,
            creatorAddy: walletBalance.creatorAddy,
            creatorName: walletBalance.creatorName,
            editionsSupply: walletBalance.editionsSupply ?? Int(walletBalance.balance),
            fileType: walletBalance.fileType,
            fileSize: nil,
            divisible: walletBalance.isDivisible,
            locked: walletBalance.locked.map { $0 == 1 },
            keyburn: nil,
            blockTime: nil,
            blockIndex: nil,
            txHash: walletBalance.txHash,
            fileHash: nil,
            marketData: nil,
            stampUrl: walletBalance.stampUrl
        )
        self.balance = walletBalance.balance
        self.divisible = walletBalance.isDivisible
        self.walletAddress = walletBalance.ownerAddy
    }
    
    /// Create from StampAsset (no balance info)
    init(from asset: StampAsset) {
        self.asset = asset
        self.balance = 0
        self.divisible = asset.divisible
        self.walletAddress = nil
    }
}
