//
//  StampAssetBalance.swift
//  StampFolio
//
//  Model for stamp balance data from wallet address queries
//

import Foundation

/// Represents a stamp balance from the balance endpoint
struct StampAssetBalance: Identifiable, Codable, Hashable, Sendable {
    
    // MARK: - Properties
    
    /// Stamp type - set based on which API endpoint returned it ("classic", "cursed", "posh")
    var stampType: String?
    
    /// Asset identifier type ("STAMP", "SRC-721", "SRC-101", etc.)
    let ident: String?
    
    /// Unique stamp number (primary identifier)
    let stampId: Int
    
    /// Counterparty ID
    let counterpartyId: String
    
    /// Creator's display name (if available)
    let creatorName: String?
    
    /// Creator's Bitcoin address
    let creatorAddy: String
    
    /// Total supply/editions
    let editionsSupply: Int?
    
    /// Total balance owned by the address (can be number or string in API)
    private let _editionsBalance: BalanceValue
    
    /// Whether the stamp is locked
    let locked: Int?
    
    /// Whether the stamp is divisible (0 = false, 1 = true)
    let divisible: Int

    /// Keyburn amount when present on the balance payload
    let keyburn: Int?
    
    /// MIME type of the stamp content (nullable in API)
    let fileType: String?
    
    /// Transaction hash
    let txHash: String
    
    /// URL to the stamp content/image
    let stampUrl: String
    
    /// Address owning the stamps
    let ownerAddy: String
    
    /// Quantity not bound to specific UTXOs (can be number or string in API)
    private let _unboundedQuantity: BalanceValue
    
    /// UTXOs containing stamps
    let utxos: [StampUTXO]
    
    // MARK: - Computed Properties
    
    var id: Int { stampId }
    
    /// Balance as Double
    var balance: Double {
        _editionsBalance.doubleValue
    }
    
    /// Unbounded quantity as Double
    var unboundedQuantity: Double {
        _unboundedQuantity.doubleValue
    }
    
    /// Whether the stamp is divisible (converts int to bool)
    var isDivisible: Bool {
        divisible == 1
    }
    
    /// Formatted quantity for display
    var formattedQuantity: String {
        // If divisible, convert from satoshi-like units (100,000,000 = 1)
        if isDivisible {
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
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case ident
        case stampId = "stamp"
        case counterpartyId = "cpid"
        case creatorName = "creator_name"
        case creatorAddy = "creator"
        case editionsSupply = "supply"
        case _editionsBalance = "balance"
        case locked
        case divisible
        case keyburn
        case fileType = "stamp_mimetype"        
        case txHash = "tx_hash"
        case stampUrl = "stamp_url"
        case ownerAddy = "address"
        case _unboundedQuantity = "unbound_quantity"
        case utxos
    }
    
    // MARK: - Custom Decoding
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // stampType will be set manually after decoding by API client
        self.stampType = nil
        
        ident = try container.decodeIfPresent(String.self, forKey: .ident)
        stampId = try container.decode(Int.self, forKey: .stampId)
        counterpartyId = try container.decode(String.self, forKey: .counterpartyId)
        creatorName = try container.decodeIfPresent(String.self, forKey: .creatorName)
        creatorAddy = try container.decode(String.self, forKey: .creatorAddy)
        editionsSupply = try container.decodeIfPresent(Int.self, forKey: .editionsSupply)
        _editionsBalance = try container.decode(BalanceValue.self, forKey: ._editionsBalance)
        locked = try container.decodeIfPresent(Int.self, forKey: .locked)
        divisible = try container.decode(Int.self, forKey: .divisible)
        keyburn = try container.decodeIfPresent(Int.self, forKey: .keyburn)
        fileType = try container.decodeIfPresent(String.self, forKey: .fileType)
        txHash = try container.decode(String.self, forKey: .txHash)
        stampUrl = try container.decode(String.self, forKey: .stampUrl)
        ownerAddy = try container.decode(String.self, forKey: .ownerAddy)
        _unboundedQuantity = try container.decode(BalanceValue.self, forKey: ._unboundedQuantity)
        utxos = try container.decode([StampUTXO].self, forKey: .utxos)
    }
}

/// Helper type to handle balance being either number or string
enum BalanceValue: Codable, Hashable {
    case number(Double)
    case string(String)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let doubleValue = try? container.decode(Double.self) {
            self = .number(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.typeMismatch(
                BalanceValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected Double or String"
                )
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .number(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        }
    }
    
    var doubleValue: Double {
        switch self {
        case .number(let value):
            return value
        case .string(let value):
            return Double(value) ?? 0
        }
    }
}

/// UTXO containing stamps
struct StampUTXO: Codable, Hashable, Sendable {
    let utxo: String
    private let _quantity: BalanceValue
    
    var quantity: Double {
        _quantity.doubleValue
    }
    
    enum CodingKeys: String, CodingKey {
        case utxo
        case _quantity = "quantity"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        utxo = try container.decode(String.self, forKey: .utxo)
        _quantity = try container.decode(BalanceValue.self, forKey: ._quantity)
    }
    
    init(utxo: String, quantity: Double) {
        self.utxo = utxo
        self._quantity = .number(quantity)
    }
}

// MARK: - Sample Data

// Sample data is removed since we can't easily create instances with the private _balance field
