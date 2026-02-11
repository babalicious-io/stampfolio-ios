//
//  Stamp.swift
//  StampFolio
//
//  Domain model representing a Bitcoin Stamp (NFT/Art)
//

import Foundation

/// Represents a Bitcoin Stamp from the Stampchain.io API
struct StampData: Identifiable, Codable, Hashable, Sendable {
    
    // MARK: - Properties
    
    /// Stamp type - set based on which API endpoint returned it
    let stampType: String
    
    /// Asset identifier from ident field ("STAMP", "SRC-721", etc.)
    let assetId: String?

    /// Stamp number (e.g., 1384303 or -11)
    let stampId: Int
    
    /// Counterparty ID (e.g., "A888354448084788958")
    let counterpartyId: String
    
    /// Creator's Bitcoin address
    let creatorAddy: String
    
    /// Creator's display name (if available)
    let creatorName: String?

    /// Total supply/editions
    let editionsSupply: Int
    
    /// MIME type of the stamp content (e.g., "image/png", "image/gif")
    let fileType: String?

    /// Size of the stamp file in bytes
    let fileSize: Int?
    
    /// Whether the stamp is divisible (0 = false, 1 = true)
    let divisible: Int
    
    /// Whether the stamp is locked (0 = false, 1 = true)
    let locked: Int?
    
    /// Keyburn amount (optional)
    let keyburn: Int?
    
    /// Block timestamp when stamp was created (optional - not in balance endpoint)
    let blockTime: Date?
    
    /// Block index number (optional - not in balance endpoint)
    let blockIndex: Int?
    
    /// Bitcoin transaction hash
    let txHash: String
    
    /// Hash of the stamp content
    let fileHash: String?
    
    /// Market data (floor price, holder count, etc.)
    let marketData: StampMarketData?

    /// URL to the stamp content/image
    let stampUrl: String
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case assetId = "ident"
        case stampId = "stamp"
        case counterpartyId = "cpid"
        case creatorAddy = "creator"
        case creatorName = "creator_name"
        case editionsSupply = "supply"
        case fileType = "stamp_mimetype"
        case fileSize = "file_size_bytes"
        case divisible
        case locked
        case keyburn
        case blockTime = "block_time"
        case blockIndex = "block_index"
        case txHash = "tx_hash"
        case fileHash = "file_hash"
        case marketData = "market_data"
        case stampUrl = "stamp_url"
    }
    
    // MARK: - Initialization
    
    /// Memberwise initializer (required since we have custom decoder)
    init(
        stampType: String,
        assetId: String?,
        stampId: Int,
        counterpartyId: String,
        creatorAddy: String,
        creatorName: String?,
        editionsSupply: Int,
        fileType: String?,
        fileSize: Int?,
        divisible: Int,
        locked: Int?,
        keyburn: Int?,
        blockTime: Date?,
        blockIndex: Int?,
        txHash: String,
        fileHash: String?,
        marketData: StampMarketData?,
        stampUrl: String
    ) {
        self.stampType = stampType
        self.assetId = assetId
        self.stampId = stampId
        self.counterpartyId = counterpartyId
        self.creatorAddy = creatorAddy
        self.creatorName = creatorName
        self.editionsSupply = editionsSupply
        self.fileType = fileType
        self.fileSize = fileSize
        self.divisible = divisible
        self.locked = locked
        self.keyburn = keyburn
        self.blockTime = blockTime
        self.blockIndex = blockIndex
        self.txHash = txHash
        self.fileHash = fileHash
        self.marketData = marketData
        self.stampUrl = stampUrl
    }
    
    /// Custom decoder (stampType not in JSON, set to default)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // stampType will be set manually after decoding, default to "classic"
        self.stampType = "classic"
        
        self.assetId = try container.decodeIfPresent(String.self, forKey: .assetId)
        self.stampId = try container.decode(Int.self, forKey: .stampId)
        self.counterpartyId = try container.decode(String.self, forKey: .counterpartyId)
        self.creatorAddy = try container.decode(String.self, forKey: .creatorAddy)
        self.creatorName = try container.decodeIfPresent(String.self, forKey: .creatorName)
        self.editionsSupply = try container.decode(Int.self, forKey: .editionsSupply)
        self.fileType = try container.decodeIfPresent(String.self, forKey: .fileType)
        self.fileSize = try container.decodeIfPresent(Int.self, forKey: .fileSize)
        self.divisible = try container.decode(Int.self, forKey: .divisible)
        self.locked = try container.decodeIfPresent(Int.self, forKey: .locked)
        self.keyburn = try container.decodeIfPresent(Int.self, forKey: .keyburn)
        self.blockTime = try container.decodeIfPresent(Date.self, forKey: .blockTime)
        self.blockIndex = try container.decodeIfPresent(Int.self, forKey: .blockIndex)
        self.txHash = try container.decode(String.self, forKey: .txHash)
        self.fileHash = try container.decodeIfPresent(String.self, forKey: .fileHash)
        self.marketData = try container.decodeIfPresent(StampMarketData.self, forKey: .marketData)
        self.stampUrl = try container.decode(String.self, forKey: .stampUrl)
    }
    
    // MARK: - Computed Properties
    
    /// Identifiable conformance - uses stampId
    var id: Int { stampId }
    
    /// URL to the stamp detail page on Stampchain.io
    var stampchainURL: URL {
        URL(string: "https://stampchain.io/stamp/\(stampId)")!
    }

    /// URL for loading the stamp image
    /// Note: HTML stamps use /content/ endpoint which processes and makes them responsive,
    /// other stamps use /s/ endpoint with txHash for correct content-type headers
    var imageURL: URL? {
        // For HTML stamps, use the /content/ endpoint which processes recursive content
        // and makes HTML stamps display correctly (responsive, cleaned, etc.)
        if isHTML {
            return URL(string: "https://stampchain.io/content/\(txHash)")
        }
        
        // For all other stamps, use /s/ endpoint with txHash
        return URL(string: "https://stampchain.io/s/\(txHash)")
    }
    

    /// Formatted stamp ID (number)
    var formattedStampId: String {
        "STAMP #\(stampId)"
    }

    /// Formatted counterparty ID
    var formattedCounterpartyId: String {
        "CPID \(counterpartyId)"
    }
    
    /// Formatted file size
    var formattedFileSize: String? {
        guard let bytes = fileSize else { return nil }
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    /// Whether the stamp content is an image (jpg, png, webp, bmp, avif)
    var isImage: Bool {
        guard let mimetype = fileType?.lowercased() else { return true }
        return mimetype.hasPrefix("image/")
    }
    
    /// Whether the stamp content is (animated) GIF
    var isGIF: Bool {
        fileType?.lowercased() == "image/gif"
    }
    
    /// Whether the stamp content is SVG
    var isSVG: Bool {
        fileType?.lowercased() == "image/svg+xml"
    }
    
    /// Whether the stamp content is HTML
    var isHTML: Bool {
        fileType?.lowercased() == "text/html"
    }
    
    /// Whether the stamp content is plain text
    var isText: Bool {
        fileType?.lowercased() == "text/plain"
    }
    
    /// Whether the stamp content is audio
    var isAudio: Bool {
        guard let mimetype = fileType?.lowercased() else { return false }
        return mimetype.hasPrefix("audio/")
    }
    
    /// Whether the stamp content is video
    var isVideo: Bool {
        guard let mimetype = fileType?.lowercased() else { return false }
        return mimetype.hasPrefix("video/")
    }
    
    /// Whether the stamp content is JavaScript
    var isJavaScript: Bool {
        guard let mimetype = fileType?.lowercased() else { return false }
        return mimetype == "application/javascript" || mimetype == "text/javascript" || mimetype == "application/x-javascript"
    }
    
    /// Whether the stamp content is CSS
    var isCSS: Bool {
        fileType?.lowercased() == "text/css"
    }
    
    /// Whether the stamp content is GZIP compressed
    var isGZIP: Bool {
        guard let mimetype = fileType?.lowercased() else { return false }
        return mimetype == "application/gzip" || mimetype == "application/x-gzip"
    }
    
    /// Whether the stamp is a library file (JS, CSS, GZIP)
    var isLibrary: Bool {
        isJavaScript || isCSS || isGZIP
    }
    
    /// Library file type label for display
    var libraryLabel: String? {
        if isJavaScript { return "JS" }
        if isCSS { return "CSS" }
        if isGZIP { return "GZIP" }
        return nil
    }
    
    /// Whether the stamp is divisible (converts int to bool)
    var isDivisible: Bool {
        divisible == 1
    }
    
    /// Whether the stamp is locked (converts int to bool)
    var isLocked: Bool {
        locked == 1
    }
}

// MARK: - Sample Data

extension StampData {
    
    /// Sample stamp for previews and testing
    static let sample = StampData(
        stampType: "classic",
        assetId: "STAMP",
        stampId: 1384303,
        counterpartyId: "A888354448084788958",
        creatorAddy: "bc1qkqqre5xuqk60xtt93j297zgg7t6x0ul7gwjmv4",
        creatorName: "babalicious",
        editionsSupply: 1,
        fileType: "image/png",
        fileSize: 198,
        divisible: 0,
        locked: 1,
        keyburn: nil,
        blockTime: Date(),
        blockIndex: 933837,
        txHash: "e94be2793462692ca8fea3a54dd90ff4b18735196a2bc426382c11959533c8ca",
        fileHash: "sha256hash",
        marketData: StampMarketData.sample,
        stampUrl: "https://stampchain.io/stamps/e94be2793462692ca8fea3a54dd90ff4b18735196a2bc426382c11959533c8ca.png"
    )
    
    /// Array of sample stamps for previews
    static let samples: [StampData] = [
        sample,
        StampData(
            stampType: "cursed",
            assetId: "STAMP",
            stampId: -11,
            counterpartyId: "A2256256256256256256",
            creatorAddy: "1GPon5BBwZJBSvGbj3b973TQ1XMXgDbPwt",
            creatorName: "netidx",
            editionsSupply: 256,
            fileType: "text/plain",
            fileSize: nil,
            divisible: 0,
            locked: 1,
            keyburn: nil,
            blockTime: Date().addingTimeInterval(-86400),
            blockIndex: 782488,
            txHash: "9c76027eaa60e976e8b0c2cf5e25f2b5c3a8d3c01f88d6c5e3a8c0f2e6b4d1a3",
            fileHash: nil,
            marketData: nil,
            stampUrl: "https://stampchain.io/stamps/test.txt"
        ),
        StampData(
            stampType: "posh",
            assetId: "STAMP",
            stampId: -398,
            counterpartyId: "USDSTAMP",
            creatorAddy: "bc1qtest",
            creatorName: "posh_creator",
            editionsSupply: 1,
            fileType: "image/png",
            fileSize: 500,
            divisible: 0,
            locked: 0,
            keyburn: nil,
            blockTime: Date().addingTimeInterval(-172800),
            blockIndex: 933835,
            txHash: "test123",
            fileHash: nil,
            marketData: nil,
            stampUrl: "https://stampchain.io/stamps/test.png"
        )
    ]
}
