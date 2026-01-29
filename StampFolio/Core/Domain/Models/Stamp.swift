//
//  Stamp.swift
//  StampFolio
//
//  Domain model representing a Bitcoin Stamp (NFT/Art)
//

import Foundation

/// Represents a Bitcoin Stamp from the Stampchain.io API
struct Stamp: Identifiable, Codable, Hashable, Sendable {
    
    // MARK: - Properties
    
    /// Unique stamp number (primary identifier)
    let id: Int
    
    /// Counterparty ID (e.g., "A888354448084788958")
    let cpid: String
    
    /// Creator's Bitcoin address
    let creator: String
    
    /// Creator's display name (if available)
    let creatorName: String?
    
    /// URL to the stamp content/image
    let stampUrl: String
    
    /// MIME type of the stamp content (e.g., "image/png", "image/gif")
    let stampMimetype: String?
    
    /// Total supply/editions
    let supply: Int
    
    /// Whether the stamp is divisible (0 = false, 1 = true)
    let divisible: Int
    
    /// Block timestamp when stamp was created (optional - not in balance endpoint)
    let blockTime: Date?
    
    /// Block index number (optional - not in balance endpoint)
    let blockIndex: Int?
    
    /// Bitcoin transaction hash
    let txHash: String
    
    /// Stamp identifier type ("STAMP", "CURSED", etc.) - optional in balance endpoint
    let ident: String?
    
    /// Hash of the stamp content
    let fileHash: String?
    
    /// Size of the stamp file in bytes
    let fileSizeBytes: Int?
    
    /// Market data (floor price, holder count, etc.)
    let marketData: MarketData?
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case id = "stamp"
        case cpid
        case creator
        case creatorName = "creator_name"
        case stampUrl = "stamp_url"
        case stampMimetype = "stamp_mimetype"
        case supply
        case divisible
        case blockTime = "block_time"
        case blockIndex = "block_index"
        case txHash = "tx_hash"
        case ident
        case fileHash = "file_hash"
        case fileSizeBytes = "file_size_bytes"
        case marketData = "market_data"
    }
    
    // MARK: - Computed Properties
    
    /// URL to the stamp detail page on Stampchain.io
    var stampchainURL: URL {
        URL(string: "https://stampchain.io/stamp/\(id)")!
    }
    
    /// Display title - uses creator name if available, otherwise stamp number
    var displayTitle: String {
        creatorName ?? "Stamp #\(id)"
    }
    
    /// Formatted stamp number with prefix
    var formattedNumber: String {
        if let identType = ident {
            return "\(identType) #\(id)"
        }
        return "STAMP #\(id)"
    }
    
    /// URL for loading the stamp image
    /// Note: We use /s/ instead of /stamps/ because the /s/ endpoint
    /// returns correct content-type headers for all content types,
    /// while /stamps/ returns binary/octet-stream for HTML which breaks WKWebView
    var imageURL: URL? {
        let correctedUrl = stampUrl.replacingOccurrences(of: "/stamps/", with: "/s/")
        return URL(string: correctedUrl)
    }
    
    /// Human-readable file size
    var formattedFileSize: String? {
        guard let bytes = fileSizeBytes else { return nil }
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    /// Whether the stamp content is an image
    var isImage: Bool {
        guard let mimetype = stampMimetype?.lowercased() else { return true }
        return mimetype.hasPrefix("image/")
    }
    
    /// Whether the stamp content is animated (GIF)
    var isAnimated: Bool {
        stampMimetype?.lowercased() == "image/gif"
    }
    
    /// Whether the stamp content is SVG
    var isSVG: Bool {
        stampMimetype?.lowercased() == "image/svg+xml"
    }
    
    /// Whether the stamp content is HTML
    var isHTML: Bool {
        stampMimetype?.lowercased() == "text/html"
    }
    
    /// Whether the stamp is divisible (converts int to bool)
    var isDivisible: Bool {
        divisible == 1
    }
}

// MARK: - Sample Data

extension Stamp {
    
    /// Sample stamp for previews and testing
    static let sample = Stamp(
        id: 1384303,
        cpid: "A888354448084788958",
        creator: "bc1qkqqre5xuqk60xtt93j297zgg7t6x0ul7gwjmv4",
        creatorName: "babalicious",
        stampUrl: "https://stampchain.io/stamps/e94be2793462692ca8fea3a54dd90ff4b18735196a2bc426382c11959533c8ca.png",
        stampMimetype: "image/png",
        supply: 1,
        divisible: 0,
        blockTime: Date(),
        blockIndex: 933837,
        txHash: "e94be2793462692ca8fea3a54dd90ff4b18735196a2bc426382c11959533c8ca",
        ident: "STAMP",
        fileHash: "sha256hash",
        fileSizeBytes: 198,
        marketData: MarketData.sample
    )
    
    /// Array of sample stamps for previews
    static let samples: [Stamp] = [
        sample,
        Stamp(
            id: 1384302,
            cpid: "A888354448084788957",
            creator: "bc1qabc123def456",
            creatorName: nil,
            stampUrl: "https://stampchain.io/stamps/1384302.gif",
            stampMimetype: "image/gif",
            supply: 42,
            divisible: 0,
            blockTime: Date().addingTimeInterval(-86400),
            blockIndex: 933836,
            txHash: "def456abc789",
            ident: "STAMP",
            fileHash: nil,
            fileSizeBytes: 1024,
            marketData: nil
        ),
        Stamp(
            id: 74705,
            cpid: "A888354448084788999",
            creator: "bc1qtest",
            creatorName: "divisible_test",
            stampUrl: "https://stampchain.io/stamps/test.png",
            stampMimetype: "image/png",
            supply: 1_000_000_000,
            divisible: 1,
            blockTime: Date().addingTimeInterval(-172800),
            blockIndex: 933835,
            txHash: "test123",
            ident: "STAMP",
            fileHash: nil,
            fileSizeBytes: 500,
            marketData: nil
        )
    ]
}
