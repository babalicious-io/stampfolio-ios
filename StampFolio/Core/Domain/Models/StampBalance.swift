//
//  StampBalance.swift
//  StampFolio
//
//  Model for stamp balance data from wallet address queries
//

import Foundation

/// Represents a stamp balance from the balance endpoint
struct StampBalance: Identifiable, Codable, Hashable, Sendable {
    
    // MARK: - Properties
    
    /// Unique stamp number (primary identifier)
    let stamp: Int
    
    /// Transaction hash
    let txHash: String
    
    /// URL to the stamp content/image
    let stampUrl: String
    
    /// MIME type of the stamp content
    let stampMimetype: String
    
    /// Whether the stamp is divisible (0 = false, 1 = true)
    let divisible: Int
    
    /// Total supply/editions
    let supply: Int?
    
    /// Whether the stamp is locked
    let locked: Int?
    
    /// Creator's Bitcoin address
    let creator: String
    
    /// Creator's display name (if available)
    let creatorName: String?
    
    /// Total balance owned by the address
    let balance: Double
    
    /// Address owning the stamps
    let address: String
    
    /// Counterparty ID
    let cpid: String
    
    /// Quantity not bound to specific UTXOs
    let unboundedQuantity: Double
    
    /// UTXOs containing stamps
    let utxos: [StampUTXO]
    
    // MARK: - Computed Properties
    
    var id: Int { stamp }
    
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
    
    /// Convert to Stamp model for compatibility
    func toStamp() -> Stamp {
        Stamp(
            id: stamp,
            cpid: cpid,
            creator: creator,
            creatorName: creatorName,
            stampUrl: stampUrl,
            stampMimetype: stampMimetype,
            supply: supply ?? Int(balance),
            divisible: divisible,
            balance: balance,
            blockTime: nil,
            blockIndex: nil,
            txHash: txHash,
            ident: "STAMP",
            fileHash: nil,
            fileSizeBytes: nil,
            marketData: nil
        )
    }
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case stamp
        case txHash = "tx_hash"
        case stampUrl = "stamp_url"
        case stampMimetype = "stamp_mimetype"
        case divisible
        case supply
        case locked
        case creator
        case creatorName = "creator_name"
        case balance
        case address
        case cpid
        case unboundedQuantity = "unbounded_quantity"
        case utxos
    }
}

/// UTXO containing stamps
struct StampUTXO: Codable, Hashable, Sendable {
    let utxo: String
    let quantity: Double
}

// MARK: - Sample Data

extension StampBalance {
    /// Sample balance for previews
    static let sample = StampBalance(
        stamp: 1384303,
        txHash: "e94be2793462692ca8fea3a54dd90ff4b18735196a2bc426382c11959533c8ca",
        stampUrl: "https://stampchain.io/stamps/e94be2793462692ca8fea3a54dd90ff4b18735196a2bc426382c11959533c8ca.png",
        stampMimetype: "image/png",
        divisible: 0,
        supply: 1,
        locked: 0,
        creator: "bc1qkqqre5xuqk60xtt93j297zgg7t6x0ul7gwjmv4",
        creatorName: "babalicious",
        balance: 1,
        address: "1GotRejB6XsGgMsM79TvcypeanDJRJbMtg",
        cpid: "A888354448084788958",
        unboundedQuantity: 1,
        utxos: []
    )
    
    /// Sample balances for previews
    static let samples: [StampBalance] = [
        sample,
        StampBalance(
            stamp: 1384302,
            txHash: "def456",
            stampUrl: "https://stampchain.io/stamps/1384302.gif",
            stampMimetype: "image/gif",
            divisible: 0,
            supply: 42,
            locked: 0,
            creator: "bc1qabc123",
            creatorName: nil,
            balance: 111,
            address: "1GotRejB6XsGgMsM79TvcypeanDJRJbMtg",
            cpid: "A888354448084788957",
            unboundedQuantity: 111,
            utxos: []
        ),
        StampBalance(
            stamp: 74705,
            txHash: "test123",
            stampUrl: "https://stampchain.io/stamps/test.png",
            stampMimetype: "image/png",
            divisible: 1,
            supply: 1_000_000_000,
            locked: 0,
            creator: "bc1qtest",
            creatorName: nil,
            balance: 6_900_000_000,
            address: "1GotRejB6XsGgMsM79TvcypeanDJRJbMtg",
            cpid: "A888354448084788999",
            unboundedQuantity: 6_900_000_000,
            utxos: []
        )
    ]
}
