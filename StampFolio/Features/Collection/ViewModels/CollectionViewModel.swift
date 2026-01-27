//
//  CollectionViewModel.swift
//  StampFolio
//
//  ViewModel for the Collection screen
//

import Foundation
import SwiftData
import Observation

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
        
        // Sort by stamp number (newest first)
        stamps = uniqueStamps.sorted { $0.id > $1.id }
        
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
