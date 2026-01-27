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
    
    /// All stamps from all wallets
    private(set) var stamps: [Stamp] = []
    
    /// Loading state
    private(set) var isLoading: Bool = false
    
    /// Error message (if any)
    private(set) var errorMessage: String?
    
    /// Currently selected stamp for detail view
    var selectedStamp: Stamp?
    
    /// Stamp for metadata popup
    var metadataStamp: Stamp?
    
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
        
        var allStamps: [Stamp] = []
        var fetchErrors: [String] = []
        
        // Fetch stamps for each wallet concurrently
        await withTaskGroup(of: Result<[Stamp], Error>.self) { group in
            for wallet in wallets {
                group.addTask {
                    do {
                        let walletStamps = try await self.apiClient.fetchStampsByWallet(wallet.address)
                        return .success(walletStamps)
                    } catch {
                        return .failure(error)
                    }
                }
            }
            
            for await result in group {
                switch result {
                case .success(let stamps):
                    allStamps.append(contentsOf: stamps)
                case .failure(let error):
                    fetchErrors.append(error.localizedDescription)
                }
            }
        }
        
        // Remove duplicates (same stamp might be in multiple wallets)
        let uniqueStamps = Array(Set(allStamps))
        
        // Sort by stamp number (newest first)
        stamps = uniqueStamps.sorted { $0.id > $1.id }
        
        // Set error if all fetches failed
        if stamps.isEmpty && !fetchErrors.isEmpty {
            errorMessage = "Unable to load stamps. Please check your connection."
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
