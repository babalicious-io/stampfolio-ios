//
//  CounterpartyViewModel.swift
//  StampFolio
//
//  ViewModel for the Counterparty screen
//

import Foundation
import SwiftData
import Observation

/// Sorting options for the Counterparty asset list
enum CounterpartySortOption: String, CaseIterable, Codable {
    case nameAscending = "name_asc"
    case nameDescending = "name_desc"
    case balanceAscending = "balance_asc"
    case balanceDescending = "balance_desc"
    case walletAscending = "wallet_asc"
    case walletDescending = "wallet_desc"

    var displayName: String {
        switch self {
        case .nameAscending: return "Name (ascending)"
        case .nameDescending: return "Name (descending)"
        case .balanceAscending: return "Balance (ascending)"
        case .balanceDescending: return "Balance (descending)"
        case .walletAscending: return "Wallet (ascending)"
        case .walletDescending: return "Wallet (descending)"
        }
    }
}

/// ViewModel managing Counterparty asset holdings state and data fetching
@Observable
final class CounterpartyViewModel {

    // MARK: - Properties

    /// All non-Stamp Counterparty assets from all wallets, with display information
    private(set) var assets: [CounterpartyDisplay] = []

    /// Loading state
    private(set) var isLoading: Bool = false

    /// Error message (if any)
    private(set) var errorMessage: String?

    /// Currently selected asset for the detail sheet
    var selectedAsset: CounterpartyDisplay?

    /// Current sort option
    var currentSortOption: CounterpartySortOption = .balanceDescending

    /// Search text for filtering assets
    var searchText: String = ""

    /// Filter state: Active divisibility filters ("divisible" or "non_divisible")
    var activeDivisibleFilters: Set<String> = []

    /// Filter state: Active lock-status filters ("locked" or "unlocked")
    var activeLockedFilters: Set<String> = []

    /// Filter state: Active asset-type filters ("named" or "numeric")
    var activeAssetTypeFilters: Set<String> = []

    /// On-demand asset detail cache (memory-only, cleared on app close/wallet delete)
    private var detailCache: [String: CounterpartyAsset] = [:]

    // MARK: - Computed Properties

    /// Check if any filters are active
    var hasActiveFilters: Bool {
        !activeDivisibleFilters.isEmpty || !activeLockedFilters.isEmpty || !activeAssetTypeFilters.isEmpty
    }

    /// Filtered assets based on search text and active filters
    var filteredAssets: [CounterpartyDisplay] {
        var result = assets

        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            result = result.filter { display in
                let asset = display.asset

                if asset.asset.lowercased().contains(searchLower) {
                    return true
                }
                if let longname = asset.assetLongname, longname.lowercased().contains(searchLower) {
                    return true
                }
                if let issuer = asset.issuer, issuer.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                return false
            }
        }

        if !activeDivisibleFilters.isEmpty {
            result = result.filter { display in
                let key = display.asset.divisible ? "divisible" : "non_divisible"
                return activeDivisibleFilters.contains(key)
            }
        }

        if !activeLockedFilters.isEmpty {
            result = result.filter { display in
                let key = display.asset.locked ? "locked" : "unlocked"
                return activeLockedFilters.contains(key)
            }
        }

        if !activeAssetTypeFilters.isEmpty {
            result = result.filter { display in
                let key = display.asset.isNumericAsset ? "numeric" : "named"
                return activeAssetTypeFilters.contains(key)
            }
        }

        return result
    }

    /// Check if there are assets to display
    var hasAssets: Bool {
        !assets.isEmpty
    }

    /// Check if we should show empty state
    var showEmptyState: Bool {
        !isLoading && assets.isEmpty && errorMessage == nil
    }

    /// Check if we should show error state
    var showError: Bool {
        !isLoading && errorMessage != nil
    }

    // MARK: - Private Properties

    private let apiClient = CounterpartyAPIClient()

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Fetch Counterparty asset balances for all wallets.
    /// - Parameters:
    ///   - wallets: Array of wallet addresses to fetch balances for
    ///   - excludingCPIDs: Asset names already shown as Bitcoin Stamps elsewhere in the app;
    ///     these are filtered out so the same asset isn't listed twice
    ///   - forceRefresh: When true, bypasses cache and fetches from network
    @MainActor
    func fetchAssetsMetadata(
        for wallets: [WalletConfig],
        excludingCPIDs: Set<String> = [],
        forceRefresh: Bool = false
    ) async {
        guard !wallets.isEmpty else {
            assets = []
            return
        }

        isLoading = assets.isEmpty
        errorMessage = nil

        var allBalances: [CounterpartyAssetBalance] = []
        var fetchErrors: [String] = []

        await withTaskGroup(of: Result<[CounterpartyAssetBalance], Error>.self) { group in
            for wallet in wallets {
                group.addTask {
                    do {
                        let balances = try await self.apiClient.fetchBalances(for: wallet.address, forceRefresh: forceRefresh)
                        return .success(balances)
                    } catch {
                        return .failure(error)
                    }
                }
            }

            for await result in group {
                switch result {
                case .success(let balances):
                    allBalances.append(contentsOf: balances)
                case .failure(let error):
                    fetchErrors.append(error.localizedDescription)
                }
            }
        }

        // Exclude assets already displayed as Bitcoin Stamps (CPID overlap)
        let nonStampBalances = allBalances.filter { !excludingCPIDs.contains($0.asset) }

        // Deduplicate by asset name (same asset held in multiple wallets shows the first-seen entry)
        var seen = Set<String>()
        let uniqueBalances = nonStampBalances.filter { balance in
            if seen.contains(balance.asset) {
                return false
            }
            seen.insert(balance.asset)
            return true
        }

        let displayAssets = uniqueBalances.map { CounterpartyDisplay(from: $0) }
        assets = sortedAssets(displayAssets, by: currentSortOption, wallets: wallets)

        if assets.isEmpty && !fetchErrors.isEmpty {
            errorMessage = "Unable to load Counterparty assets: \(fetchErrors.first ?? "Unknown error")"
        }

        isLoading = false
    }

    /// Clear all assets and errors
    func clear() {
        assets = []
        errorMessage = nil
        selectedAsset = nil
    }

    /// Toggle a divisibility filter ("divisible" or "non_divisible")
    func toggleDivisibleFilter(_ value: String) {
        if activeDivisibleFilters.contains(value) {
            activeDivisibleFilters.remove(value)
        } else {
            activeDivisibleFilters.insert(value)
        }
    }

    /// Toggle a lock-status filter ("locked" or "unlocked")
    func toggleLockedFilter(_ value: String) {
        if activeLockedFilters.contains(value) {
            activeLockedFilters.remove(value)
        } else {
            activeLockedFilters.insert(value)
        }
    }

    /// Toggle an asset-type filter ("named" or "numeric")
    func toggleAssetTypeFilter(_ value: String) {
        if activeAssetTypeFilters.contains(value) {
            activeAssetTypeFilters.remove(value)
        } else {
            activeAssetTypeFilters.insert(value)
        }
    }

    /// Sort assets by the given option
    /// - Parameters:
    ///   - option: The sort option to apply
    ///   - wallets: Array of wallets for mapping wallet addresses to display names
    func sortAssets(by option: CounterpartySortOption, wallets: [WalletConfig]) {
        currentSortOption = option
        assets = sortedAssets(assets, by: option, wallets: wallets)
    }

    // MARK: - Detail Fetching

    /// Fetch on-demand detail (supply, holders, floor price) for a single asset if not already cached
    @MainActor
    func fetchAssetDetailIfNeeded(for displayAsset: CounterpartyDisplay) async {
        let assetName = displayAsset.asset.asset

        guard detailCache[assetName] == nil, !displayAsset.isLoadingDetail else {
            return
        }

        if let index = assets.firstIndex(where: { $0.id == displayAsset.id }) {
            assets[index].isLoadingDetail = true
        }

        do {
            let detail = try await apiClient.fetchAssetDetail(assetName)
            detailCache[assetName] = detail

            if let index = assets.firstIndex(where: { $0.id == displayAsset.id }) {
                let old = assets[index]
                assets[index] = CounterpartyDisplay(
                    asset: detail,
                    balance: old.balance,
                    divisible: detail.divisible,
                    walletAddress: old.walletAddress,
                    isLoadingDetail: false
                )
            }
        } catch {
            if let index = assets.firstIndex(where: { $0.id == displayAsset.id }) {
                assets[index].isLoadingDetail = false
            }
        }
    }

    /// Clear the on-demand asset detail cache (call on app close or wallet deletion)
    @MainActor
    func clearDetailCache() {
        detailCache.removeAll()

        for index in assets.indices {
            assets[index].isLoadingDetail = false
        }
    }

    // MARK: - Private Methods

    private func sortedAssets(
        _ assets: [CounterpartyDisplay],
        by option: CounterpartySortOption,
        wallets: [WalletConfig]
    ) -> [CounterpartyDisplay] {
        switch option {
        case .nameAscending:
            return assets.sorted { $0.asset.displayName.localizedCaseInsensitiveCompare($1.asset.displayName) == .orderedAscending }

        case .nameDescending:
            return assets.sorted { $0.asset.displayName.localizedCaseInsensitiveCompare($1.asset.displayName) == .orderedDescending }

        case .balanceAscending:
            return assets.sorted { $0.balance < $1.balance }

        case .balanceDescending:
            return assets.sorted { $0.balance > $1.balance }

        case .walletAscending:
            return assets.sorted { walletDisplayName(for: $0.walletAddress, in: wallets).localizedCaseInsensitiveCompare(walletDisplayName(for: $1.walletAddress, in: wallets)) == .orderedAscending }

        case .walletDescending:
            return assets.sorted { walletDisplayName(for: $0.walletAddress, in: wallets).localizedCaseInsensitiveCompare(walletDisplayName(for: $1.walletAddress, in: wallets)) == .orderedDescending }
        }
    }

    private func walletDisplayName(for address: String?, in wallets: [WalletConfig]) -> String {
        guard let address = address else { return "" }

        if let wallet = wallets.first(where: { $0.address == address }) {
            return wallet.displayName
        }

        return address
    }
}
