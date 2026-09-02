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
final class WalletConfig {
    
    // MARK: - Properties
    
    /// Unique Bitcoin address (all formats supported)
    @Attribute(.unique)
    var address: String
    
    /// Date when the wallet was added
    var addedDate: Date
    
    /// Optional user-provided label for the wallet
    var label: String?
    
    /// User-selected color for the wallet icon (defaults to gray for existing wallets)
    var colorName: String?
    
    // MARK: - Initialization
    
    init(address: String, label: String? = nil, colorName: String? = WalletColor.gray.rawValue) {
        self.address = address
        self.addedDate = Date()
        self.label = label
        self.colorName = colorName
    }
    
    // MARK: - Computed Properties
    
    /// Truncated address for display (e.g., "bc1qxy2k...fjhx0wlh")
    var truncatedAddress: String {
        address.truncatedAddress(prefixLength: 6, suffixLength: 6)
    }
    
    /// Display name - uses label if available, otherwise truncated address
    var displayName: String {
        label ?? truncatedAddress
    }
    
    /// Detected address type
    var addressType: BitcoinAddressType {
        BitcoinAddressType.detect(from: address)
    }
    
    /// Wallet color with fallback to gray for existing wallets
    var walletColor: WalletColor {
        WalletColor.from(name: colorName ?? WalletColor.gray.rawValue)
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

// MARK: - Wallet Color

import SwiftUI

/// Predefined wallet colors using native SwiftUI colors (order: red → orange → yellow → green → blue → purple → gray)
enum WalletColor: String, CaseIterable, Identifiable, Equatable {
    case red
    case orange
    case yellow
    case green
    case blue
    case purple
    case gray
    
    var id: Self { self }
    
    var color: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .gray: return .gray
        }
    }
    
    var displayName: String {
        rawValue.capitalized
    }
    
    static func from(name: String) -> WalletColor {
        WalletColor.allCases.first { $0.rawValue == name } ?? .gray
    }
}

// MARK: - Wallet Display Name Lookup

extension Array where Element == WalletConfig {

    /// Display name for a wallet address, falling back to the raw address if the wallet
    /// isn't found (e.g. was deleted) and to an empty string if `address` is nil
    func displayName(for address: String?) -> String {
        guard let address else { return "" }
        return first(where: { $0.address == address })?.displayName ?? address
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
