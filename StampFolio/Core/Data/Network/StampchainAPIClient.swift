//
//  StampchainAPIClient.swift
//  StampFolio
//
//  API client for Stampchain.io REST API
//

import Foundation

/// API client for interacting with the Stampchain.io API
actor StampchainAPIClient {
    
    // MARK: - Properties
    
    private let baseURL = "https://stampchain.io/api/v2"
    private let session: URLSession
    private let decoder: JSONDecoder
    
    // MARK: - Initialization
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        
        // Enable caching
        config.urlCache = URLCache(
            memoryCapacity: 10 * 1024 * 1024,  // 10 MB
            diskCapacity: 50 * 1024 * 1024,     // 50 MB
            diskPath: "stampchain_cache"
        )
        config.requestCachePolicy = .returnCacheDataElseLoad
        
        self.session = URLSession(configuration: config)
        
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try ISO8601 with fractional seconds
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }
    }
    
    // MARK: - Public Methods
    
    /// Fetch stamps owned by a wallet address
    /// - Parameters:
    ///   - address: Bitcoin wallet address
    ///   - forceStampsRefresh: When true, bypasses cache and fetches from network
    /// - Returns: Array of stamp balances owned by the wallet
    func fetchStampsByWallet(_ address: String, forceStampsRefresh: Bool = false) async throws -> [StampAssetBalance] {
        let endpoint = "\(baseURL)/stamps/balance/\(address)"
        
        guard let url = URL(string: endpoint) else {
            throw NetworkError.invalidURL
        }
        
        print("🌐 Fetching stamps from: \(endpoint)\(forceStampsRefresh ? " (force refresh)" : "")")
        
        let (data, _) = try await performRequest(url, forceStampsRefresh: forceStampsRefresh)
        
        print("✅ Received \(data.count) bytes")
        
        let apiResponse = try decoder.decode(WalletBalanceResponse.self, from: data)
        var stamps = apiResponse.data
        
        // Set stampType based on stampId and counterpartyId
        for i in stamps.indices {
            let stampId = stamps[i].stampId
            let counterpartyId = stamps[i].counterpartyId
            
            if stampId > 0 {
                // Positive stamps are classic
                stamps[i].stampType = "classic"
            } else {
                // Negative stamps: check if POSH (named CPID) or CURSED (numeric CPID)
                if counterpartyId.hasPrefix("A") && counterpartyId.dropFirst().allSatisfy({ $0.isNumber }) {
                    // Numeric CPID (A + numbers) = cursed
                    stamps[i].stampType = "cursed"
                } else {
                    // Named CPID = posh
                    stamps[i].stampType = "posh"
                }
            }
        }
        
        print("✅ Decoded \(stamps.count) stamps")
        let classicCount = stamps.filter { $0.stampType == "classic" }.count
        let cursedCount = stamps.filter { $0.stampType == "cursed" }.count
        let poshCount = stamps.filter { $0.stampType == "posh" }.count
        print("   - \(classicCount) classic, \(cursedCount) cursed, \(poshCount) posh")
        
        return stamps
    }
    
    /// Fetch details for a specific stamp
    /// - Parameter stampNumber: The stamp number/ID
    /// - Returns: StampAsset details (includes market data)
    func fetchStampDetails(_ stampNumber: Int) async throws -> StampAsset {
        let endpoint = "\(baseURL)/stamps/\(stampNumber)"
        
        guard let url = URL(string: endpoint) else {
            throw NetworkError.invalidURL
        }
        
        let (data, _) = try await performRequest(url)
        
        // Parse the response
        let apiResponse = try decoder.decode(StampDetailResponse.self, from: data)
        return apiResponse.data.stamp
    }
    
    /// Public method to fetch stamp with market data (alias for fetchStampDetails)
    /// - Parameter stampNumber: The stamp number/ID
    /// - Returns: Stamp data with market data
    func fetchStamp(_ stampNumber: Int) async throws -> StampAsset {
        return try await fetchStampDetails(stampNumber)
    }
    
    /// Validate that a wallet has stamps
    /// - Parameter address: Bitcoin wallet address
    /// - Returns: True if wallet has at least one stamp
    func validateWalletHasStamps(_ address: String) async throws -> Bool {
        let stamps = try await fetchStampsByWallet(address)
        return !stamps.isEmpty
    }
    
    /// Fetch stamps with pagination
    /// - Parameters:
    ///   - limit: Number of stamps per page
    ///   - page: Page number (0-indexed)
    /// - Returns: Array of stamps
    func fetchStamps(limit: Int = 50, page: Int = 0) async throws -> [StampAsset] {
        let endpoint = "\(baseURL)/stamps?limit=\(limit)&page=\(page)"
        
        guard let url = URL(string: endpoint) else {
            throw NetworkError.invalidURL
        }
        
        let (data, _) = try await performRequest(url)
        
        // Parse the response
        let apiResponse = try decoder.decode(StampsListResponse.self, from: data)
        return apiResponse.data
    }
    
    // MARK: - Private Methods
    
    private func performRequest(_ url: URL, forceStampsRefresh: Bool = false) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if forceStampsRefresh {
            request.cachePolicy = .reloadIgnoringLocalCacheData
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return (data, response)
        case 404:
            throw NetworkError.notFound
        case 429:
            throw NetworkError.rateLimited
        case 500...599:
            throw NetworkError.serverError(httpResponse.statusCode)
        default:
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
}

// MARK: - API Response Models

/// Response wrapper for wallet balance endpoint
private struct WalletBalanceResponse: Decodable {
    let data: [StampAssetBalance]
}

/// Response wrapper for stamp detail endpoint
private struct StampDetailResponse: Decodable {
    let lastBlock: Int
    let data: StampDetailData
    
    enum CodingKeys: String, CodingKey {
        case lastBlock = "last_block"
        case data
    }
}

/// Data wrapper for stamp detail (nested structure)
private struct StampDetailData: Decodable {
    let stamp: StampAsset
}

/// Response wrapper for stamps list endpoint
private struct StampsListResponse: Decodable {
    let data: [StampAsset]
    let lastBlock: Int?
    
    enum CodingKeys: String, CodingKey {
        case data
        case lastBlock = "last_block"
    }
}

// MARK: - Network Error

/// Network-related errors
enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case notFound
    case rateLimited
    case serverError(Int)
    case httpError(Int)
    case decodingError(Error)
    case noConnection
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Too many requests. Please try again later."
        case .serverError(let code):
            return "Server error (\(code))"
        case .httpError(let code):
            return "HTTP error (\(code))"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .noConnection:
            return "No internet connection"
        }
    }
}
