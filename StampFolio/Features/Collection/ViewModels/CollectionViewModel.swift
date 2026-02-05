//
//  CollectionViewModel.swift
//  StampFolio
//
//  ViewModel for the Collection screen
//

import Foundation
import SwiftData
import Observation

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
    case artistAZ = "artist_az"
    case artistZA = "artist_za"
    case balanceAscending = "balance_asc"
    case balanceDescending = "balance_desc"
    case walletAZ = "wallet_az"
    case walletZA = "wallet_za"
    
    var displayName: String {
        switch self {
        case .stampAscending: return "Stamp # (ascending)"
        case .stampDescending: return "Stamp # (descending)"
        case .artistAZ: return "Artist (A-Z)"
        case .artistZA: return "Artist (Z-A)"
        case .balanceAscending: return "Balance (ascending)"
        case .balanceDescending: return "Balance (descending)"
        case .walletAZ: return "Wallet (A-Z)"
        case .walletZA: return "Wallet (Z-A)"
        }
    }
    
    var iconName: String {
        switch self {
        case .stampAscending, .balanceAscending: return "arrow.up"
        case .stampDescending, .balanceDescending: return "arrow.down"
        case .artistAZ, .artistZA, .walletAZ, .walletZA: return ""
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
    
    /// Whether search is active
    var isSearching: Bool = false
    
    // MARK: - Computed Properties
    
    /// Filtered stamps based on search text
    var filteredStamps: [DisplayStamp] {
        guard !searchText.isEmpty else {
            return stamps
        }
        
        let searchLower = searchText.lowercased()
        
        return stamps.filter { displayStamp in
            let stamp = displayStamp.stamp
            
            // Search by stamp ID
            if "\(stamp.id)".contains(searchLower) {
                return true
            }
            
            // Search by CPID
            if stamp.cpid.localizedCaseInsensitiveContains(searchText) {
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
    
    // MARK: - Private Properties
    
    private let apiClient = StampchainAPIClient()
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Public Methods
    
    /// Fetch stamps for all wallets
    /// - Parameter wallets: Array of wallet addresses to fetch stamps for
    @MainActor
    func fetchStamps(for wallets: [Wallet]) async {
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
                        let walletBalances = try await self.apiClient.fetchStampsByWallet(wallet.address)
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
    }
    
    /// Refresh stamps (pull-to-refresh)
    /// - Parameter wallets: Array of wallet addresses to refresh
    @MainActor
    func refreshStamps(for wallets: [Wallet]) async {
        isRefreshing = true
        await fetchStamps(for: wallets)
        isRefreshing = false
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
            newOption = currentSortOption == .artistAZ ? .artistZA : .artistAZ
        case .balance:
            newOption = currentSortOption == .balanceAscending ? .balanceDescending : .balanceAscending
        case .wallet:
            newOption = currentSortOption == .walletAZ ? .walletZA : .walletAZ
        }
        
        sortStamps(by: newOption, wallets: wallets)
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
            
        case .artistAZ:
            return stamps.sorted { stamp1, stamp2 in
                let artist1 = stamp1.stamp.creatorName ?? stamp1.stamp.creatorAddy
                let artist2 = stamp2.stamp.creatorName ?? stamp2.stamp.creatorAddy
                return artist1.localizedCaseInsensitiveCompare(artist2) == .orderedAscending
            }
            
        case .artistZA:
            return stamps.sorted { stamp1, stamp2 in
                let artist1 = stamp1.stamp.creatorName ?? stamp1.stamp.creatorAddy
                let artist2 = stamp2.stamp.creatorName ?? stamp2.stamp.creatorAddy
                return artist1.localizedCaseInsensitiveCompare(artist2) == .orderedDescending
            }
            
        case .balanceAscending:
            return stamps.sorted { ($0.balance ?? 0) < ($1.balance ?? 0) }
            
        case .balanceDescending:
            return stamps.sorted { ($0.balance ?? 0) > ($1.balance ?? 0) }
            
        case .walletAZ:
            return stamps.sorted { stamp1, stamp2 in
                let wallet1Name = walletDisplayName(for: stamp1.walletAddress, in: wallets)
                let wallet2Name = walletDisplayName(for: stamp2.walletAddress, in: wallets)
                return wallet1Name.localizedCaseInsensitiveCompare(wallet2Name) == .orderedAscending
            }
            
        case .walletZA:
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
