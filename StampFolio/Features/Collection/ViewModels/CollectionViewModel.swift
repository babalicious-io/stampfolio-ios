//
//  CollectionViewModel.swift
//  StampFolio
//
//  ViewModel for the Collection screen
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
final class CollectionViewModel {
    
    // MARK: - Properties
    
    /// All stamps from all wallets with display information
    private(set) var stamps: [DisplayStamp] = []
    
    /// Loading state
    private(set) var isLoading: Bool = false
    
    /// Error message (if any)
    private(set) var errorMessage: String?
    
    /// Currently selected stamp for detail view
    var selectedStamp: DisplayStamp?
    
    /// Stamp for metadata popup
    var metadataStamp: DisplayStamp?
    
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
    
    // MARK: - Computed Properties
    
    /// Check if any filters are active
    var hasActiveFilters: Bool {
        !activeIdentFilters.isEmpty || !activeFileFormatFilters.isEmpty || !activeEditionFilters.isEmpty
    }
    
    /// Filtered stamps based on search text and filters
    var filteredStamps: [DisplayStamp] {
        var result = stamps
        
        // Apply search filter
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            result = result.filter { displayStamp in
                let stamp = displayStamp.stamp
                
                // Search by stamp ID
                if "\(stamp.id)".contains(searchLower) {
                    return true
                }
                
                // Search by CPID
                if stamp.counterpartyId.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                
                // Search by transaction hash
                if stamp.txHash.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                
                // Search by creator address
                if stamp.creatorAddy.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                
                // Search by creator name
                if let creatorName = stamp.creatorName,
                   creatorName.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                
                return false
            }
        }
        
        // Apply ident filters
        if !activeIdentFilters.isEmpty {
            result = result.filter { displayStamp in
                let stampType = displayStamp.stamp.stampType
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
            
            result = result.filter { displayStamp in
                guard let mimetype = displayStamp.stamp.fileType?.lowercased() else { return false }
                guard let format = mimeToFormat[mimetype] else { return false }
                return activeFileFormatFilters.contains(format)
            }
        }
        
        // Apply edition filters
        if !activeEditionFilters.isEmpty {
            result = result.filter { displayStamp in
                let supply = displayStamp.stamp.editionSupply
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
    func fetchStampsMetadata(for wallets: [Wallet], forceStampsRefresh: Bool = false) async {
        guard !wallets.isEmpty else {
            stamps = []
            return
        }
        
        isLoading = stamps.isEmpty
        errorMessage = nil
        
        var allStamps: [DisplayStamp] = []
        var fetchErrors: [String] = []
        
        // Fetch stamps for each wallet concurrently
        await withTaskGroup(of: Result<[DisplayStamp], Error>.self) { group in
            for wallet in wallets {
                group.addTask {
                    do {
                        let walletBalances = try await self.apiClient.fetchStampsByWallet(wallet.address, forceStampsRefresh: forceStampsRefresh)
                        // Convert StampBalance to DisplayStamp
                        let displayStamps = walletBalances.map { DisplayStamp(from: $0) }
                        return .success(displayStamps)
                    } catch {
                        return .failure(error)
                    }
                }
            }
            
            for await result in group {
                switch result {
                case .success(let displayStamps):
                    allStamps.append(contentsOf: displayStamps)
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
    func fetchStampMetadata(for wallet: Wallet, allWallets: [Wallet], forceStampsRefresh: Bool = false) async {
        isRefreshing = true
        errorMessage = nil
        
        do {
            let walletBalances = try await apiClient.fetchStampsByWallet(wallet.address, forceStampsRefresh: forceStampsRefresh)
            let newDisplayStamps = walletBalances.map { DisplayStamp(from: $0) }
            
            // Remove existing stamps from this wallet, then add fresh ones
            var updatedStamps = stamps.filter { $0.walletAddress != wallet.address }
            updatedStamps.append(contentsOf: newDisplayStamps)
            
            // Deduplicate
            var seen = Set<Int>()
            let uniqueStamps = updatedStamps.filter { stamp in
                if seen.contains(stamp.id) { return false }
                seen.insert(stamp.id)
                return true
            }
            
            stamps = sortedStamps(uniqueStamps, by: currentSortOption, wallets: allWallets)
            
            print("✅ Refreshed wallet \(wallet.displayName): \(newDisplayStamps.count) stamps")
            
            // Prefetch images for the refreshed stamps
            if !newDisplayStamps.isEmpty {
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
        
        for displayStamp in stamps {
            let stamp = displayStamp.stamp
            guard let url = stamp.imageURL else { continue }
            
            if stamp.isHTML || stamp.isSVG {
                vectorURLs.append(url)
            } else if stamp.isText {
                textURLs.append(url)
            } else if stamp.isLibrary || stamp.isAudio || stamp.isVideo {
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
                                
                                // Inject viewport (same logic as StampVectorView)
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
    func sortStamps(by option: SortOption, wallets: [Wallet]) {
        currentSortOption = option
        stamps = sortedStamps(stamps, by: option, wallets: wallets)
    }
    
    /// Toggle sort for a specific category (Stamp, Artist, Balance, Wallet)
    /// - Parameter wallets: Array of wallets for mapping wallet addresses to display names
    func toggleSort(for category: SortCategory, wallets: [Wallet]) {
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
    private func sortedStamps(_ stamps: [DisplayStamp], by option: SortOption, wallets: [Wallet]) -> [DisplayStamp] {
        switch option {
        case .stampAscending:
            return stamps.sorted { $0.id < $1.id }
            
        case .stampDescending:
            return stamps.sorted { $0.id > $1.id }
            
        case .artistAscending:
            return stamps.sorted { stamp1, stamp2 in
                let artist1 = stamp1.stamp.creatorName ?? stamp1.stamp.creatorAddy
                let artist2 = stamp2.stamp.creatorName ?? stamp2.stamp.creatorAddy
                return artist1.localizedCaseInsensitiveCompare(artist2) == .orderedAscending
            }
            
        case .artistDescending:
            return stamps.sorted { stamp1, stamp2 in
                let artist1 = stamp1.stamp.creatorName ?? stamp1.stamp.creatorAddy
                let artist2 = stamp2.stamp.creatorName ?? stamp2.stamp.creatorAddy
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
    private func walletDisplayName(for address: String?, in wallets: [Wallet]) -> String {
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
}
