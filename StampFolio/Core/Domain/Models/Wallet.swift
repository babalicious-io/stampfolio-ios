//
//  Wallet.swift
//  StampFolio
//
//  SwiftData model for persisting Bitcoin wallet addresses
//

import Foundation
import SwiftData

/// Represents a Bitcoin wallet address stored locally
@Model
final class Wallet {
    
    // MARK: - Properties
    
    /// Unique Bitcoin address (all formats supported)
    @Attribute(.unique)
    var address: String
    
    /// Date when the wallet was added
    var addedDate: Date
    
    /// Optional user-provided label for the wallet
    var label: String?
    
    /// Cached stamp count (updated on refresh)
    var cachedStampCount: Int?
    
    /// Last time stamps were fetched for this wallet
    var lastFetchDate: Date?
    
    // MARK: - Initialization
    
    init(address: String, label: String? = nil) {
        self.address = address
        self.addedDate = Date()
        self.label = label
        self.cachedStampCount = nil
        self.lastFetchDate = nil
    }
    
    // MARK: - Computed Properties
    
    /// Truncated address for display (e.g., "bc1qxy2k...fjhx0wlh")
    var truncatedAddress: String {
        address.truncatedAddress(prefixLength: 8, suffixLength: 8)
    }
    
    /// Display name - uses label if available, otherwise truncated address
    var displayName: String {
        label ?? truncatedAddress
    }
    
    /// Detected address type
    var addressType: BitcoinAddressType {
        BitcoinAddressType.detect(from: address)
    }
}

// MARK: - Bitcoin Address Type

/// Bitcoin address format types
enum BitcoinAddressType: String, CaseIterable {
    case legacy = "Legacy (P2PKH)"
    case segwitP2SH = "SegWit (P2SH)"
    case nativeSegwit = "Native SegWit (Bech32)"
    case taproot = "Taproot (Bech32m)"
    case unknown = "Unknown"
    
    /// Detect address type from a Bitcoin address string
    static func detect(from address: String) -> BitcoinAddressType {
        if address.hasPrefix("1") {
            return .legacy
        } else if address.hasPrefix("3") {
            return .segwitP2SH
        } else if address.lowercased().hasPrefix("bc1q") {
            return .nativeSegwit
        } else if address.lowercased().hasPrefix("bc1p") {
            return .taproot
        } else {
            return .unknown
        }
    }
}

// MARK: - String Extension for Truncation

extension String {
    
    /// Truncate a Bitcoin address for display (e.g., "bc1q...jmv4")
    func truncatedAddress(prefixLength: Int = 4, suffixLength: Int = 4) -> String {
        guard count > (prefixLength + suffixLength + 3) else { return self }
        let prefix = self.prefix(prefixLength)
        let suffix = self.suffix(suffixLength)
        return "\(prefix)...\(suffix)"
    }
}
