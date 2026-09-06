//
//  StampViewModel.swift
//  StampFolio
//
//  ViewModel for the Stamp screen
//

import Foundation
import SwiftData
import Observation
import Kingfisher

/// Sorting options for stamp collection
enum StampSortOption: String, CaseIterable, Codable {
    case dateDescending = "date_desc"
    case dateAscending = "date_asc"
    case stampAscending = "stamp_asc"
    case stampDescending = "stamp_desc"
    case artistAscending = "artist_asc"
    case artistDescending = "artist_desc"
    case balanceAscending = "balance_asc"
    case balanceDescending = "balance_desc"
    case walletAscending = "wallet_asc"
    case walletDescending = "wallet_desc"
    
    var displayName: String {
        switch self {
        case .dateDescending: return "Date (newest)"
        case .dateAscending: return "Date (oldest)"
        case .stampAscending: return "Stamp # (ascending)"
        case .stampDescending: return "Stamp # (descending)"
        case .artistAscending: return "Artist (ascending)"
        case .artistDescending: return "Artist (descending)"
        case .balanceAscending: return "Balance (ascending)"
        case .balanceDescending: return "Balance (descending)"
        case .walletAscending: return "Wallet (ascending)"
        case .walletDescending: return "Wallet (descending)"
        }
    }
}

/// ViewModel managing stamp collection state and data fetching
@Observable
final class StampViewModel {
    
    // MARK: - Properties
    
    /// All assets from all wallets with display information
    private(set) var assets: [StampDisplay] = []
    
    /// Loading state
    private(set) var isLoading: Bool = false
    
    /// Error message (if any)
    private(set) var errorMessage: String?
    
    /// Current sort option
    var currentSortOption: StampSortOption = .dateDescending
    
    /// Filter state: Active ident filters (e.g., "STAMP", "POSH")
    var activeIdentFilters: Set<String> = []
    
    /// Filter state: Active file format filters (e.g., "jpg", "png", "gif", "webp", "avif", "svg", "html", "text", "mp3")
    var activeFileFormatFilters: Set<String> = []
    
    /// Filter state: Active edition filters ("single" or "multiple")
    var activeEditionFilters: Set<String> = []

    /// Filter state: Active lock-status filters ("locked" or "unlocked")
    var activeLockedFilters: Set<String> = []
    
    /// Market data cache (memory-only, cleared on app close/wallet delete)
    private var marketDataCache: [Int: StampAssetMarketData] = [:]
    
    // MARK: - Computed Properties
    
    /// Check if any filters are active
    var hasActiveFilters: Bool {
        !activeIdentFilters.isEmpty
            || !activeFileFormatFilters.isEmpty
            || !activeEditionFilters.isEmpty
            || !activeLockedFilters.isEmpty
    }
    
    /// Filtered assets based on active collection filters
    var filteredAssets: [StampDisplay] {
        var result = assets
        
        // Apply ident filters
        if !activeIdentFilters.isEmpty {
            result = result.filter { display in
                let stampType = display.asset.stampType
                return activeIdentFilters.contains(stampType)
            }
        }
        
        // Apply file format filters (individual MIME type matching)
        if !activeFileFormatFilters.isEmpty {
            // Map MIME types to filter keys
            let mimeToFormat: [String: String] = [
                "image/jpeg": "jpg",
                "image/jpg": "jpg",
                "image/png": "png",
                "image/gif": "gif",
                "image/webp": "webp",
                "image/avif": "avif",
                "image/svg+xml": "svg",
                "text/html": "html",
                "text/plain": "text",
                "audio/mpeg": "mp3",
                "audio/mp3": "mp3",
            ]
            
            result = result.filter { display in
                guard let mimetype = display.asset.fileType?.lowercased() else { return false }
                guard let format = mimeToFormat[mimetype] else { return false }
                return activeFileFormatFilters.contains(format)
            }
        }
        
        // Apply edition filters
        if !activeEditionFilters.isEmpty {
            result = result.filter { display in
                let supply = display.asset.editionsSupply
                for edition in activeEditionFilters {
                    if edition == "single" && supply == 1 { return true }
                    if edition == "multiple" && supply > 1 { return true }
                }
                return false
            }
        }

        if !activeLockedFilters.isEmpty {
            result = result.filter { display in
                let key = display.asset.locked == true ? "locked" : "unlocked"
                return activeLockedFilters.contains(key)
            }
        }
        
        return result
    }

    /// Assets matching a free-text query (ignores collection-tab filters)
    func assets(matching query: String) -> [StampDisplay] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return assets.filter { $0.matchesSearch(trimmed) }
    }

    /// Counterparty asset names (CPIDs) for stamps already shown in the Stamps collection
    var stampCPIDs: Set<String> {
        Set(assets.map(\.asset.counterpartyId))
    }
    
    // MARK: - Private Properties
    
    private let apiClient = StampchainAPIClient()
    private var imagePrefetcher: ImagePrefetcher?
    private var incrementalImagePrefetchers: [ImagePrefetcher] = []
    private var isFetchingAllMetadata = false
    private var fetchAllWaiters: [CheckedContinuation<Void, Never>] = []
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Public Methods
    
    /// Fetch stamp metadata for all wallets, then prefetch images
    /// - Parameters:
    ///   - wallets: Array of wallet addresses to fetch stamps for
    ///   - forceRefresh: When true, bypasses cache and fetches from network
    @MainActor
    func fetchAssetsMetadata(for wallets: [WalletConfig], forceRefresh: Bool = false) async {
        if isFetchingAllMetadata {
            await withCheckedContinuation { continuation in
                fetchAllWaiters.append(continuation)
            }
            if !forceRefresh { return }
        }

        isFetchingAllMetadata = true
        defer {
            isFetchingAllMetadata = false
            let waiters = fetchAllWaiters
            fetchAllWaiters.removeAll()
            waiters.forEach { $0.resume() }
        }

        guard !wallets.isEmpty else {
            assets = []
            return
        }
        
        isLoading = assets.isEmpty
        errorMessage = nil
        
        var allStamps: [StampDisplay] = []
        var fetchErrors: [String] = []
        
        // Fetch stamps for each wallet concurrently
        await withTaskGroup(of: Result<[StampDisplay], Error>.self) { group in
            for wallet in wallets {
                group.addTask {
                    do {
                        let walletBalances = try await self.apiClient.fetchStampsByWallet(wallet.address, forceRefresh: forceRefresh)
                        // Convert StampAssetBalance to StampDisplay
                        let displayAssets = walletBalances.map { StampDisplay(from: $0) }
                        return .success(displayAssets)
                    } catch {
                        return .failure(error)
                    }
                }
            }
            
            for await result in group {
                switch result {
                case .success(let displayAssets):
                    allStamps.append(contentsOf: displayAssets)
                case .failure(let error):
                    let errorDetail = error.localizedDescription
                    print("❌ Fetch error: \(errorDetail)")
                    if let decodingError = error as? DecodingError {
                        print("❌ Decoding error details: \(decodingError)")
                    }
                    fetchErrors.append(errorDetail)
                }
            }
        }
        
        // Remove duplicates (same stamp might be in multiple wallets)
        // Use stamp ID for uniqueness
        var seen = Set<Int>()
        let uniqueStamps = allStamps.filter { stamp in
            if seen.contains(stamp.id) {
                return false
            }
            seen.insert(stamp.id)
            return true
        }
        
        // Apply current sort option
        assets = sortedAssets(uniqueStamps, by: currentSortOption, wallets: wallets)
        
        print("✅ Loaded \(assets.count) unique stamps")
        
        // Set error if all fetches failed
        if assets.isEmpty && !fetchErrors.isEmpty {
            errorMessage = "Unable to load stamps: \(fetchErrors.first ?? "Unknown error")"
            print("❌ Error message: \(errorMessage ?? "")")
        }
        
        isLoading = false
        
        // Prefetch all stamp images in background
        if !assets.isEmpty {
            fetchStampsImages()
        }
    }
    
    /// Show collection loading when the first wallet is added
    @MainActor
    func prepareToLoadNewWallet() {
        guard assets.isEmpty else { return }
        isLoading = true
        errorMessage = nil
    }
    
    /// Fetch metadata for a single wallet (add-wallet and per-wallet refresh)
    /// - Parameters:
    ///   - wallet: The wallet to fetch stamps for
    ///   - allWallets: All wallets for dedup and sorting context
    ///   - forceRefresh: When true, bypasses cache and fetches from network
    ///   - startBackgroundWork: When false, skip image prefetch so the download overlay can
    ///     run its own two-phase (newest 20, then remainder) cache
    /// - Returns: Number of stamps returned for this wallet, or `nil` if the fetch failed
    @MainActor
    @discardableResult
    func fetchAssetMetadata(
        for wallet: WalletConfig,
        allWallets: [WalletConfig],
        forceRefresh: Bool = false,
        startBackgroundWork: Bool = true
    ) async -> Int? {
        let showLoading = assets.isEmpty
        if showLoading { isLoading = true }
        errorMessage = nil
        defer { if showLoading { isLoading = false } }
        
        do {
            let walletBalances = try await apiClient.fetchStampsByWallet(wallet.address, forceRefresh: forceRefresh)
            let newDisplayAssets = walletBalances.map { StampDisplay(from: $0) }
            
            // Remove existing stamps from this wallet, then add fresh ones
            var updatedStamps = assets.filter { $0.walletAddress != wallet.address }
            updatedStamps.append(contentsOf: newDisplayAssets)
            
            // Deduplicate
            var seen = Set<Int>()
            let uniqueStamps = updatedStamps.filter { stamp in
                if seen.contains(stamp.id) { return false }
                seen.insert(stamp.id)
                return true
            }
            
            assets = sortedAssets(uniqueStamps, by: currentSortOption, wallets: allWallets)
            
            print("✅ Refreshed wallet \(wallet.displayName): \(newDisplayAssets.count) stamps")
            
            if startBackgroundWork, !newDisplayAssets.isEmpty {
                fetchStampsImages(from: newDisplayAssets, cancelExisting: false)
            }
            
            return newDisplayAssets.count
        } catch {
            print("❌ Refresh error for \(wallet.displayName): \(error.localizedDescription)")
            errorMessage = "Failed to refresh \(wallet.displayName): \(error.localizedDescription)"
            return nil
        }
    }
    
    /// Prefetch all stamp images in background
    /// Pixel stamps use Kingfisher ImagePrefetcher, vector/text use URLSession,
    /// then HTML/SVG snapshots via StampVectorSnapshotPrefetcher
    @MainActor
    func fetchStampsImages() {
        fetchStampsImages(from: assets, cancelExisting: true)
    }
    
    /// Prefetch stamp images for a subset of the collection
    /// - Parameters:
    ///   - displays: Stamps whose image URLs should be prefetched
    ///   - cancelExisting: When true, stop in-flight prefetch of the full collection
    @MainActor
    func fetchStampsImages(from displays: [StampDisplay], cancelExisting: Bool) {
        if cancelExisting {
            imagePrefetcher?.stop()
            incrementalImagePrefetchers.forEach { $0.stop() }
            incrementalImagePrefetchers.removeAll()
            StampVectorSnapshotPrefetcher.shared.cancel()
        }
        
        // Separate URLs by stamp type
        var pixelURLs: [URL] = []
        var vectorURLs: [URL] = []  // HTML/SVG - need viewport injection
        var textURLs: [URL] = []    // Plain text - cache as-is
        
        for display in displays {
            let asset = display.asset
            guard let url = asset.imageURL else { continue }
            
            if asset.isHTML || asset.isSVG {
                vectorURLs.append(url)
            } else if asset.isText {
                textURLs.append(url)
            } else if asset.isLibrary || asset.isAudio || asset.isVideo {
                // Skip library/audio/video - these are placeholders or not preloadable
                continue
            } else {
                // Pixel images (jpg, png, webp, gif)
                pixelURLs.append(url)
            }
        }
        
        let contentURLCount = vectorURLs.count + textURLs.count
        let totalCount = pixelURLs.count + contentURLCount
        guard totalCount > 0 else { return }
        
        print("📦 Prefetching \(pixelURLs.count) pixel + \(vectorURLs.count) vector + \(textURLs.count) text stamp images")
        
        // Prefetch pixel stamps with Kingfisher
        if !pixelURLs.isEmpty {
            let prefetcher = ImagePrefetcher(
                urls: pixelURLs,
                options: ProtocolImageCache.options(for: ProtocolImageCache.stamps),
                completionHandler: { skippedResources, failedResources, completedResources in
                    print("✅ Pixel prefetch done: \(completedResources.count) completed, \(skippedResources.count) cached, \(failedResources.count) failed")
                }
            )
            if cancelExisting {
                imagePrefetcher = prefetcher
            } else {
                incrementalImagePrefetchers.append(prefetcher)
            }
            prefetcher.start()
        }
        
        // Prefetch vector/text stamps into StampContentCache
        if contentURLCount > 0 {
            Task.detached(priority: .utility) {
                await Self.cacheStampContents(vectorURLs: vectorURLs, textURLs: textURLs)

                if !vectorURLs.isEmpty {
                    await StampVectorSnapshotPrefetcher.shared.enqueue(vectorURLs)
                }
            }
        }
    }
    
    // MARK: - Download Overlay
    
    /// Cache the newest `limit` visual previews (pixel images plus HTML/SVG snapshots) and
    /// return only once each one is cached, failed, or skipped.
    @MainActor
    func prefetchPriorityDownloads(
        walletAddress: String?,
        limit: Int,
        onProgress: @escaping (Int, Int) -> Void
    ) async {
        let priority = Array(newestVisualAssets(in: displays(forWallet: walletAddress)).prefix(limit))
        onProgress(0, priority.count)
        guard !priority.isEmpty else { return }
        
        var pixelURLs: [URL] = []
        var vectorURLs: [URL] = []
        for display in priority {
            guard let url = display.asset.imageURL else { continue }
            if display.asset.isHTML || display.asset.isSVG {
                vectorURLs.append(url)
            } else {
                pixelURLs.append(url)
            }
        }
        
        let total = priority.count
        var pixelDone = 0
        var vectorDone = 0
        let report = { @MainActor in
            onProgress(min(pixelDone + vectorDone, total), total)
        }
        
        await withTaskGroup(of: Void.self) { group in
            if !pixelURLs.isEmpty {
                group.addTask { @MainActor in
                    await ProtocolImageCache.prefetch(
                        pixelURLs,
                        options: ProtocolImageCache.options(for: ProtocolImageCache.stamps),
                        retain: { self.incrementalImagePrefetchers.append($0) },
                        progress: { done in
                            pixelDone = done
                            report()
                        }
                    )
                }
            }
            
            if !vectorURLs.isEmpty {
                group.addTask { @MainActor in
                    await Self.cacheStampContents(vectorURLs: vectorURLs, textURLs: [])
                    await StampVectorSnapshotPrefetcher.shared.enqueueAndWait(vectorURLs) { done in
                        vectorDone = done
                        report()
                    }
                }
            }
        }
        
        onProgress(total, total)
    }
    
    /// Keep caching everything the priority gate skipped: older visual assets, then text/audio/video.
    @MainActor
    func prefetchRemainderDownloads(walletAddress: String?, afterPriorityLimit: Int) {
        let source = displays(forWallet: walletAddress)
        let remainingVisual = Array(newestVisualAssets(in: source).dropFirst(afterPriorityLimit))
        let nonVisual = source.filter { !$0.asset.hasCollectionPreview }
        let remainder = remainingVisual + nonVisual
        guard !remainder.isEmpty else { return }
        fetchStampsImages(from: remainder, cancelExisting: false)
    }
    
    /// Static GIF toggle: cache the newest GIF thumbnails at the same size the grid decodes.
    @MainActor
    func prefetchPriorityStaticGIFs(limit: Int, onProgress: @escaping (Int, Int) -> Void) async {
        let urls = Array(newestGIFAssets().prefix(limit)).compactMap(\.asset.imageURL)
        onProgress(0, urls.count)
        guard !urls.isEmpty else { return }
        
        await ProtocolImageCache.prefetch(
            urls,
            options: ProtocolImageCache.thumbnailOptions(for: ProtocolImageCache.stamps),
            retain: { incrementalImagePrefetchers.append($0) },
            progress: { done in onProgress(done, urls.count) }
        )
        onProgress(urls.count, urls.count)
    }
    
    @MainActor
    func prefetchRemainderStaticGIFs(afterPriorityLimit: Int) {
        let urls = Array(newestGIFAssets().dropFirst(afterPriorityLimit)).compactMap(\.asset.imageURL)
        guard !urls.isEmpty else { return }
        
        let prefetcher = ImagePrefetcher(
            urls: urls,
            options: ProtocolImageCache.thumbnailOptions(for: ProtocolImageCache.stamps),
            completionHandler: { skippedResources, failedResources, completedResources in
                print("✅ Static GIF prefetch done: \(completedResources.count) completed, \(skippedResources.count) cached, \(failedResources.count) failed")
            }
        )
        incrementalImagePrefetchers.append(prefetcher)
        prefetcher.start()
    }
    
    private func displays(forWallet address: String?) -> [StampDisplay] {
        guard let address else { return assets }
        return assets.filter { $0.walletAddress == address }
    }
    
    /// Newest first by `blockTime`; stamps without one fall back to stamp number descending.
    private func newestVisualAssets(in displays: [StampDisplay]) -> [StampDisplay] {
        displays
            .filter { $0.asset.hasCollectionPreview && $0.asset.imageURL != nil }
            .sorted { Self.isNewer($0, than: $1) }
    }
    
    private func newestGIFAssets() -> [StampDisplay] {
        newestVisualAssets(in: assets).filter(\.asset.isGIF)
    }
    
    private static func isNewer(_ lhs: StampDisplay, than rhs: StampDisplay) -> Bool {
        switch (lhs.asset.blockTime, rhs.asset.blockTime) {
        case let (lhsDate?, rhsDate?):
            return lhsDate == rhsDate ? lhs.id > rhs.id : lhsDate > rhsDate
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        case (nil, nil):
            return lhs.id > rhs.id
        }
    }
    
    /// Fetch HTML/SVG (with viewport injected) and plain text into `StampContentCache`.
    private static func cacheStampContents(vectorURLs: [URL], textURLs: [URL]) async {
        let cache = StampContentCache.shared
        
        await withTaskGroup(of: Void.self) { group in
            // Vector stamps (HTML/SVG) - fetch, inject viewport, cache
            for url in vectorURLs {
                group.addTask {
                    guard await !cache.contains(url) else { return }
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        guard let htmlString = String(data: data, encoding: .utf8) else { return }
                        await cache.write(Self.htmlWithViewport(htmlString), for: url)
                    } catch {
                        print("⚠️ Vector prefetch failed for \(url): \(error.localizedDescription)")
                    }
                }
            }
            
            // Text stamps - fetch and cache as-is
            for url in textURLs {
                group.addTask {
                    guard await !cache.contains(url) else { return }
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        if let text = String(data: data, encoding: .utf8) {
                            await cache.write(text, for: url)
                        }
                    } catch {
                        print("⚠️ Text prefetch failed for \(url): \(error.localizedDescription)")
                    }
                }
            }
        }
        
        print("✅ Vector/text prefetch done: \(vectorURLs.count) vector + \(textURLs.count) text stamps cached")
    }
    
    private static func htmlWithViewport(_ html: String) -> String {
        let viewportMeta = "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no\">"
        guard !html.contains("name=\"viewport\""), !html.contains("name='viewport'") else {
            return html
        }
        
        var htmlString = html
        if let headRange = htmlString.range(of: "<head>", options: .caseInsensitive) {
            htmlString.insert(contentsOf: viewportMeta, at: headRange.upperBound)
        } else if let htmlRange = htmlString.range(of: "<html", options: .caseInsensitive),
                  let closeRange = htmlString[htmlRange.upperBound...].range(of: ">") {
            htmlString.insert(contentsOf: "<head>\(viewportMeta)</head>", at: closeRange.upperBound)
        } else {
            htmlString = viewportMeta + htmlString
        }
        return htmlString
    }
    
    /// Clear all assets and errors
    func clear() {
        assets = []
        errorMessage = nil
    }
    
    /// Sort assets by the given option
    /// - Parameters:
    ///   - option: The sort option to apply
    ///   - wallets: Array of wallets for mapping wallet addresses to display names
    func sortAssets(by option: StampSortOption, wallets: [WalletConfig]) {
        currentSortOption = option
        assets = sortedAssets(assets, by: option, wallets: wallets)
    }
    
    // MARK: - Filter Methods
    
    /// Toggle an ident filter (e.g., "STAMP", "POSH")
    /// - Parameter ident: The ident type to toggle
    func toggleIdentFilter(_ ident: String) {
        activeIdentFilters.toggleMembership(of: ident)
    }
    
    /// Toggle a file format filter (e.g., "jpg", "png", "gif", "webp", "avif", "svg", "html", "text", "mp3")
    /// - Parameter format: The format key to toggle
    func toggleFileFormatFilter(_ format: String) {
        activeFileFormatFilters.toggleMembership(of: format)
    }
    
    /// Toggle an edition filter ("single" or "multiple")
    /// - Parameter edition: The edition type to toggle
    func toggleEditionFilter(_ edition: String) {
        activeEditionFilters.toggleMembership(of: edition)
    }

    /// Toggle a lock-status filter ("locked" or "unlocked")
    func toggleLockedFilter(_ value: String) {
        activeLockedFilters.toggleMembership(of: value)
    }
    
    /// Returns sorted assets based on the given option
    /// - Parameters:
    ///   - assets: The assets to sort
    ///   - option: The sort option to apply
    ///   - wallets: Array of wallets for mapping wallet addresses to display names
    /// - Returns: Sorted array of assets
    private func sortedAssets(_ assets: [StampDisplay], by option: StampSortOption, wallets: [WalletConfig]) -> [StampDisplay] {
        switch option {
        case .dateDescending:
            return assets.sorted { Self.isNewer($0, than: $1) }
            
        case .dateAscending:
            return assets.sorted { Self.isNewer($1, than: $0) }
            
        case .stampAscending:
            return assets.sorted { $0.id < $1.id }
            
        case .stampDescending:
            return assets.sorted { $0.id > $1.id }
            
        case .artistAscending:
            return assets.sorted { asset1, asset2 in
                let artist1 = asset1.asset.creatorName ?? asset1.asset.creatorAddy
                let artist2 = asset2.asset.creatorName ?? asset2.asset.creatorAddy
                return artist1.localizedCaseInsensitiveCompare(artist2) == .orderedAscending
            }
            
        case .artistDescending:
            return assets.sorted { asset1, asset2 in
                let artist1 = asset1.asset.creatorName ?? asset1.asset.creatorAddy
                let artist2 = asset2.asset.creatorName ?? asset2.asset.creatorAddy
                return artist1.localizedCaseInsensitiveCompare(artist2) == .orderedDescending
            }
            
        case .balanceAscending:
            return assets.sorted { $0.balance < $1.balance }
            
        case .balanceDescending:
            return assets.sorted { $0.balance > $1.balance }
            
        case .walletAscending:
            return assets.sorted { asset1, asset2 in
                let wallet1Name = wallets.displayName(for: asset1.walletAddress)
                let wallet2Name = wallets.displayName(for: asset2.walletAddress)
                return wallet1Name.localizedCaseInsensitiveCompare(wallet2Name) == .orderedAscending
            }
            
        case .walletDescending:
            return assets.sorted { asset1, asset2 in
                let wallet1Name = wallets.displayName(for: asset1.walletAddress)
                let wallet2Name = wallets.displayName(for: asset2.walletAddress)
                return wallet1Name.localizedCaseInsensitiveCompare(wallet2Name) == .orderedDescending
            }
        }
    }
    
    /// Check if we should show error state
    var showError: Bool {
        !isLoading && errorMessage != nil
    }
    
    // MARK: - Market Data Fetching
    
    /// Fetch market data for a single stamp if not already cached
    @MainActor
    func fetchMarketDataIfNeeded(for displayAsset: StampDisplay) async {
        let stampId = displayAsset.asset.stampId
        
        // Skip if already cached or currently loading
        guard marketDataCache[stampId] == nil,
              !displayAsset.isLoadingMarketData else {
            return
        }
        
        // Mark as loading
        if let index = assets.firstIndex(where: { $0.id == displayAsset.id }) {
            assets[index].isLoadingMarketData = true
        }
        
        // Fetch individual stamp data
        do {
            let stampData = try await apiClient.fetchStamp(stampId)
            let marketData = stampData.marketData
            
            // Update cache
            if let marketData = marketData {
                marketDataCache[stampId] = marketData
            }
            
            // Update display stamp on main actor - replace entire StampDisplay with updated stamp
            if let index = assets.firstIndex(where: { $0.id == displayAsset.id }) {
                let oldDisplay = assets[index]
                assets[index] = StampDisplay(
                    asset: stampData,
                    balance: oldDisplay.balance,
                    divisible: stampData.divisible,
                    walletAddress: oldDisplay.walletAddress
                )
                assets[index].marketData = marketData
                assets[index].isLoadingMarketData = false
            }
        } catch {
            print("❌ Failed to fetch market data for stamp \(stampId): \(error)")
            
            // Mark as not loading on error
            if let index = assets.firstIndex(where: { $0.id == displayAsset.id }) {
                assets[index].isLoadingMarketData = false
            }
        }
    }
    
    /// Clear market data cache (call on app close or wallet deletion)
    @MainActor
    func clearMarketDataCache() {
        marketDataCache.removeAll()
        
        // Clear market data from display stamps
        for index in assets.indices {
            assets[index].marketData = nil
            assets[index].isLoadingMarketData = false
        }
    }
}

// MARK: - ProtocolDownloadSource

/// Declared in an extension so the `@MainActor` protocol does not isolate the whole view model.
extension StampViewModel: ProtocolDownloadSource {}
