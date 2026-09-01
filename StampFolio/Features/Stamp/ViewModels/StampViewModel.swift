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

/// Sort categories for toggle behavior
enum SortCategory {
    case stamp
    case artist
    case balance
    case wallet
}

/// Sorting options for stamp collection
enum SortOption: String, CaseIterable, Codable {
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
    
    /// All stamps from all wallets with display information
    private(set) var stamps: [StampDisplay] = []
    
    /// Loading state
    private(set) var isLoading: Bool = false
    
    /// Error message (if any)
    private(set) var errorMessage: String?
    
    /// Currently selected stamp for detail view
    var selectedStamp: StampDisplay?
    
    /// Stamp for metadata popup
    var metadataStamp: StampDisplay?
    
    /// Whether refresh is in progress
    private(set) var isRefreshing: Bool = false
    
    /// Current sort option
    var currentSortOption: SortOption = .stampDescending
    
    /// Search text for filtering stamps
    var searchText: String = ""
    
    /// Filter state: Active ident filters (e.g., "STAMP", "POSH")
    var activeIdentFilters: Set<String> = []
    
    /// Filter state: Active file format filters (e.g., "jpg", "png", "gif", "webp", "avif", "svg", "html", "text", "mp3")
    var activeFileFormatFilters: Set<String> = []
    
    /// Filter state: Active edition filters ("single" or "multiple")
    var activeEditionFilters: Set<String> = []
    
    /// Market data cache (memory-only, cleared on app close/wallet delete)
    private var marketDataCache: [Int: StampAssetMarketData] = [:]
    
    // MARK: - Computed Properties
    
    /// Check if any filters are active
    var hasActiveFilters: Bool {
        !activeIdentFilters.isEmpty || !activeFileFormatFilters.isEmpty || !activeEditionFilters.isEmpty
    }
    
    /// Filtered stamps based on search text and filters
    var filteredStamps: [StampDisplay] {
        var result = stamps
        
        // Apply search filter
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            result = result.filter { display in
                let asset = display.asset
                
                // Search by stamp ID
                if "\(asset.id)".contains(searchLower) {
                    return true
                }
                
                // Search by CPID
                if asset.counterpartyId.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                
                // Search by transaction hash
                if asset.txHash.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                
                // Search by creator address
                if asset.creatorAddy.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                
                // Search by creator name
                if let creatorName = asset.creatorName,
                   creatorName.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                
                return false
            }
        }
        
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
        
        return result
    }
    
    /// Image prefetch progress (completed, total)
    private(set) var fetchStampsProgress: (completed: Int, total: Int)?
    
    // MARK: - Private Properties
    
    private let apiClient = StampchainAPIClient()
    private var imagePrefetcher: ImagePrefetcher?
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Public Methods
    
    /// Fetch stamp metadata for all wallets, then prefetch images
    /// - Parameters:
    ///   - wallets: Array of wallet addresses to fetch stamps for
    ///   - forceStampsRefresh: When true, bypasses cache and fetches from network
    @MainActor
    func fetchStampsMetadata(for wallets: [WalletConfig], forceStampsRefresh: Bool = false) async {
        guard !wallets.isEmpty else {
            stamps = []
            return
        }
        
        isLoading = stamps.isEmpty
        errorMessage = nil
        
        var allStamps: [StampDisplay] = []
        var fetchErrors: [String] = []
        
        // Fetch stamps for each wallet concurrently
        await withTaskGroup(of: Result<[StampDisplay], Error>.self) { group in
            for wallet in wallets {
                group.addTask {
                    do {
                        let walletBalances = try await self.apiClient.fetchStampsByWallet(wallet.address, forceStampsRefresh: forceStampsRefresh)
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
        stamps = sortedStamps(uniqueStamps, by: currentSortOption, wallets: wallets)
        
        print("✅ Loaded \(stamps.count) unique stamps")
        
        // Set error if all fetches failed
        if stamps.isEmpty && !fetchErrors.isEmpty {
            errorMessage = "Unable to load stamps: \(fetchErrors.first ?? "Unknown error")"
            print("❌ Error message: \(errorMessage ?? "")")
        }
        
        isLoading = false
        
        // Prefetch all stamp images in background
        if !stamps.isEmpty {
            fetchStampsImages()
        }
    }
    
    /// Fetch metadata for a single stamp (used by per-wallet refresh)
    /// - Parameters:
    ///   - wallet: The wallet to fetch stamps for
    ///   - allWallets: All wallets for dedup and sorting context
    ///   - forceStampsRefresh: When true, bypasses cache and fetches from network
    @MainActor
    func fetchStampMetadata(for wallet: WalletConfig, allWallets: [WalletConfig], forceStampsRefresh: Bool = false) async {
        isRefreshing = true
        errorMessage = nil
        
        do {
            let walletBalances = try await apiClient.fetchStampsByWallet(wallet.address, forceStampsRefresh: forceStampsRefresh)
            let newDisplayAssets = walletBalances.map { StampDisplay(from: $0) }
            
            // Remove existing stamps from this wallet, then add fresh ones
            var updatedStamps = stamps.filter { $0.walletAddress != wallet.address }
            updatedStamps.append(contentsOf: newDisplayAssets)
            
            // Deduplicate
            var seen = Set<Int>()
            let uniqueStamps = updatedStamps.filter { stamp in
                if seen.contains(stamp.id) { return false }
                seen.insert(stamp.id)
                return true
            }
            
            stamps = sortedStamps(uniqueStamps, by: currentSortOption, wallets: allWallets)
            
            print("✅ Refreshed wallet \(wallet.displayName): \(newDisplayAssets.count) stamps")
            
            // Prefetch images for the refreshed stamps
            if !newDisplayAssets.isEmpty {
                fetchStampsImages()
            }
        } catch {
            print("❌ Refresh error for \(wallet.displayName): \(error.localizedDescription)")
            errorMessage = "Failed to refresh \(wallet.displayName): \(error.localizedDescription)"
        }
        
        isRefreshing = false
    }
    
    /// Prefetch all stamp images in background
    /// Pixel stamps use Kingfisher ImagePrefetcher, vector/text use URLSession
    func fetchStampsImages() {
        // Cancel any existing prefetch
        imagePrefetcher?.stop()
        
        // Separate URLs by stamp type
        var pixelURLs: [URL] = []
        var vectorURLs: [URL] = []  // HTML/SVG - need viewport injection
        var textURLs: [URL] = []    // Plain text - cache as-is
        
        for display in stamps {
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
        
        fetchStampsProgress = (completed: 0, total: totalCount)
        var completedCount = 0
        
        // Prefetch pixel stamps with Kingfisher
        if !pixelURLs.isEmpty {
            let prefetcher = ImagePrefetcher(
                urls: pixelURLs,
                options: [
                    .cacheOriginalImage,
                    .diskCacheExpiration(.never)
                ],
                progressBlock: { [weak self] skippedResources, failedResources, completedResources in
                    let pixelCompleted = skippedResources.count + failedResources.count + completedResources.count
                    Task { @MainActor in
                        completedCount = pixelCompleted
                        self?.fetchStampsProgress = (completed: completedCount, total: totalCount)
                    }
                },
                completionHandler: { [weak self] skippedResources, failedResources, completedResources in
                    print("✅ Pixel prefetch done: \(completedResources.count) completed, \(skippedResources.count) cached, \(failedResources.count) failed")
                    Task { @MainActor in
                        if contentURLCount == 0 {
                            self?.fetchStampsProgress = nil
                        }
                    }
                }
            )
            imagePrefetcher = prefetcher
            prefetcher.start()
        }
        
        // Prefetch vector/text stamps into StampContentCache
        if contentURLCount > 0 {
            Task.detached(priority: .utility) {
                let cache = StampContentCache.shared
                let viewportMeta = "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no\">"
                
                await withTaskGroup(of: Void.self) { group in
                    // Vector stamps (HTML/SVG) - fetch, inject viewport, cache
                    for url in vectorURLs {
                        group.addTask {
                            // Skip if already cached
                            guard await !cache.contains(url) else { return }
                            
                            do {
                                let (data, _) = try await URLSession.shared.data(from: url)
                                guard var htmlString = String(data: data, encoding: .utf8) else { return }
                                
                                // Inject viewport (same logic as StampAssetVectorView)
                                if !htmlString.contains("name=\"viewport\"") && !htmlString.contains("name='viewport'") {
                                    if let headRange = htmlString.range(of: "<head>", options: .caseInsensitive) {
                                        htmlString.insert(contentsOf: viewportMeta, at: headRange.upperBound)
                                    } else if let htmlRange = htmlString.range(of: "<html", options: .caseInsensitive) {
                                        if let closeRange = htmlString[htmlRange.upperBound...].range(of: ">") {
                                            htmlString.insert(contentsOf: "<head>\(viewportMeta)</head>", at: closeRange.upperBound)
                                        }
                                    } else {
                                        htmlString = viewportMeta + htmlString
                                    }
                                }
                                
                                await cache.write(htmlString, for: url)
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
        }
    }
    
    /// Clear all stamps and errors
    func clear() {
        stamps = []
        errorMessage = nil
        selectedStamp = nil
        metadataStamp = nil
    }
    
    /// Sort stamps by the given option
    /// - Parameters:
    ///   - option: The sort option to apply
    ///   - wallets: Array of wallets for mapping wallet addresses to display names
    func sortStamps(by option: SortOption, wallets: [WalletConfig]) {
        currentSortOption = option
        stamps = sortedStamps(stamps, by: option, wallets: wallets)
    }
    
    /// Toggle sort for a specific category (Stamp, Artist, Balance, WalletConfig)
    /// - Parameter wallets: Array of wallets for mapping wallet addresses to display names
    func toggleSort(for category: SortCategory, wallets: [WalletConfig]) {
        let newOption: SortOption
        
        switch category {
        case .stamp:
            newOption = currentSortOption == .stampAscending ? .stampDescending : .stampAscending
        case .artist:
            newOption = currentSortOption == .artistAscending ? .artistDescending : .artistAscending
        case .balance:
            newOption = currentSortOption == .balanceAscending ? .balanceDescending : .balanceAscending
        case .wallet:
            newOption = currentSortOption == .walletAscending ? .walletDescending : .walletAscending
        }
        
        sortStamps(by: newOption, wallets: wallets)
    }
    
    // MARK: - Filter Methods
    
    /// Toggle an ident filter (e.g., "STAMP", "POSH")
    /// - Parameter ident: The ident type to toggle
    func toggleIdentFilter(_ ident: String) {
        if activeIdentFilters.contains(ident) {
            activeIdentFilters.remove(ident)
        } else {
            activeIdentFilters.insert(ident)
        }
    }
    
    /// Toggle a file format filter (e.g., "jpg", "png", "gif", "webp", "avif", "svg", "html", "text", "mp3")
    /// - Parameter format: The format key to toggle
    func toggleFileFormatFilter(_ format: String) {
        if activeFileFormatFilters.contains(format) {
            activeFileFormatFilters.remove(format)
        } else {
            activeFileFormatFilters.insert(format)
        }
    }
    
    /// Toggle an edition filter ("single" or "multiple")
    /// - Parameter edition: The edition type to toggle
    func toggleEditionFilter(_ edition: String) {
        if activeEditionFilters.contains(edition) {
            activeEditionFilters.remove(edition)
        } else {
            activeEditionFilters.insert(edition)
        }
    }
    
    /// Returns sorted stamps based on the given option
    /// - Parameters:
    ///   - stamps: The stamps to sort
    ///   - option: The sort option to apply
    ///   - wallets: Array of wallets for mapping wallet addresses to display names
    /// - Returns: Sorted array of stamps
    private func sortedStamps(_ stamps: [StampDisplay], by option: SortOption, wallets: [WalletConfig]) -> [StampDisplay] {
        switch option {
        case .stampAscending:
            return stamps.sorted { $0.id < $1.id }
            
        case .stampDescending:
            return stamps.sorted { $0.id > $1.id }
            
        case .artistAscending:
            return stamps.sorted { stamp1, stamp2 in
                let artist1 = stamp1.asset.creatorName ?? stamp1.asset.creatorAddy
                let artist2 = stamp2.asset.creatorName ?? stamp2.asset.creatorAddy
                return artist1.localizedCaseInsensitiveCompare(artist2) == .orderedAscending
            }
            
        case .artistDescending:
            return stamps.sorted { stamp1, stamp2 in
                let artist1 = stamp1.asset.creatorName ?? stamp1.asset.creatorAddy
                let artist2 = stamp2.asset.creatorName ?? stamp2.asset.creatorAddy
                return artist1.localizedCaseInsensitiveCompare(artist2) == .orderedDescending
            }
            
        case .balanceAscending:
            return stamps.sorted { ($0.balance ?? 0) < ($1.balance ?? 0) }
            
        case .balanceDescending:
            return stamps.sorted { ($0.balance ?? 0) > ($1.balance ?? 0) }
            
        case .walletAscending:
            return stamps.sorted { stamp1, stamp2 in
                let wallet1Name = walletDisplayName(for: stamp1.walletAddress, in: wallets)
                let wallet2Name = walletDisplayName(for: stamp2.walletAddress, in: wallets)
                return wallet1Name.localizedCaseInsensitiveCompare(wallet2Name) == .orderedAscending
            }
            
        case .walletDescending:
            return stamps.sorted { stamp1, stamp2 in
                let wallet1Name = walletDisplayName(for: stamp1.walletAddress, in: wallets)
                let wallet2Name = walletDisplayName(for: stamp2.walletAddress, in: wallets)
                return wallet1Name.localizedCaseInsensitiveCompare(wallet2Name) == .orderedDescending
            }
        }
    }
    
    /// Get display name for a wallet address
    /// - Parameters:
    ///   - address: The wallet address
    ///   - wallets: Array of wallets to search
    /// - Returns: Display name or address
    private func walletDisplayName(for address: String?, in wallets: [WalletConfig]) -> String {
        guard let address = address else { return "" }
        
        if let wallet = wallets.first(where: { $0.address == address }) {
            return wallet.displayName
        }
        
        return address
    }
    
    /// Check if there are stamps to display
    var hasStamps: Bool {
        !stamps.isEmpty
    }
    
    /// Check if we should show empty state
    var showEmptyState: Bool {
        !isLoading && stamps.isEmpty && errorMessage == nil
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
        if let index = stamps.firstIndex(where: { $0.id == displayAsset.id }) {
            stamps[index].isLoadingMarketData = true
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
            if let index = stamps.firstIndex(where: { $0.id == displayAsset.id }) {
                let oldDisplay = stamps[index]
                stamps[index] = StampDisplay(
                    asset: stampData,
                    balance: oldDisplay.balance,
                    divisible: stampData.divisible,
                    walletAddress: oldDisplay.walletAddress
                )
                stamps[index].marketData = marketData
                stamps[index].isLoadingMarketData = false
            }
        } catch {
            print("❌ Failed to fetch market data for stamp \(stampId): \(error)")
            
            // Mark as not loading on error
            if let index = stamps.firstIndex(where: { $0.id == displayAsset.id }) {
                stamps[index].isLoadingMarketData = false
            }
        }
    }
    
    /// Fetch market data for multiple stamps concurrently
    @MainActor
    func fetchMarketDataForVisibleStamps(_ visibleStamps: [StampDisplay]) async {
        // Filter stamps that need market data
        let stampsToFetch = visibleStamps.filter { 
            marketDataCache[$0.asset.stampId] == nil && !$0.isLoadingMarketData
        }
        
        guard !stampsToFetch.isEmpty else { return }
        
        // Mark all as loading
        for displayAsset in stampsToFetch {
            if let index = stamps.firstIndex(where: { $0.id == displayAsset.id }) {
                stamps[index].isLoadingMarketData = true
            }
        }
        
        // Fetch concurrently
        await withTaskGroup(of: (Int, StampAsset?).self) { group in
            for displayAsset in stampsToFetch {
                group.addTask {
                    do {
                        let stampData = try await self.apiClient.fetchStamp(displayAsset.asset.stampId)
                        return (displayAsset.asset.stampId, stampData)
                    } catch {
                        print("❌ Failed to fetch market data for stamp \(displayAsset.asset.stampId): \(error)")
                        return (displayAsset.asset.stampId, nil)
                    }
                }
            }
            
            // Collect all results on main actor
            for await (stampId, stampData) in group {
                if let stampData = stampData {
                    // Update cache
                    if let marketData = stampData.marketData {
                        marketDataCache[stampId] = marketData
                    }
                    
                    // Update display stamps on main actor - replace entire StampDisplay with updated stamp
                    if let index = stamps.firstIndex(where: { $0.asset.stampId == stampId }) {
                        let oldDisplay = stamps[index]
                        stamps[index] = StampDisplay(
                            asset: stampData,
                            balance: oldDisplay.balance,
                            divisible: stampData.divisible,
                            walletAddress: oldDisplay.walletAddress
                        )
                        stamps[index].marketData = stampData.marketData
                        stamps[index].isLoadingMarketData = false
                    }
                } else {
                    // Mark as not loading on error
                    if let index = stamps.firstIndex(where: { $0.asset.stampId == stampId }) {
                        stamps[index].isLoadingMarketData = false
                    }
                }
            }
        }
    }
    
    /// Clear market data cache (call on app close or wallet deletion)
    @MainActor
    func clearMarketDataCache() {
        marketDataCache.removeAll()
        
        // Clear market data from display stamps
        for index in stamps.indices {
            stamps[index].marketData = nil
            stamps[index].isLoadingMarketData = false
        }
    }
}
