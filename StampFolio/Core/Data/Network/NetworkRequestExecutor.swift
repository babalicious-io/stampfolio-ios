//
//  NetworkRequestExecutor.swift
//  StampFolio
//
//  Shared URLSession configuration and request execution used by all API clients
//  (Stampchain, Counterparty). Composed rather than subclassed since API clients are actors.
//

import Foundation

/// Configures a caching `URLSession` and performs GET requests with unified HTTP status handling.
struct NetworkRequestExecutor {

    let session: URLSession

    /// - Parameters:
    ///   - cacheName: Unique disk cache path for this client (e.g. "stampchain_cache")
    ///   - memoryCapacityMB: In-memory cache size in megabytes
    ///   - diskCapacityMB: On-disk cache size in megabytes
    ///   - timeoutRequest: Per-request timeout in seconds
    ///   - timeoutResource: Per-resource (overall) timeout in seconds
    init(
        cacheName: String,
        memoryCapacityMB: Int,
        diskCapacityMB: Int,
        timeoutRequest: TimeInterval = 30,
        timeoutResource: TimeInterval = 60
    ) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutRequest
        config.timeoutIntervalForResource = timeoutResource
        config.waitsForConnectivity = true

        config.urlCache = URLCache(
            memoryCapacity: memoryCapacityMB * 1024 * 1024,
            diskCapacity: diskCapacityMB * 1024 * 1024,
            diskPath: cacheName
        )
        config.requestCachePolicy = .returnCacheDataElseLoad

        self.session = URLSession(configuration: config)
    }

    /// Perform a GET request, translating HTTP status codes into `NetworkError`
    /// - Parameters:
    ///   - url: The request URL
    ///   - forceRefresh: When true, bypasses the URL cache and reloads from network
    func perform(_ url: URL, forceRefresh: Bool = false) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if forceRefresh {
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
