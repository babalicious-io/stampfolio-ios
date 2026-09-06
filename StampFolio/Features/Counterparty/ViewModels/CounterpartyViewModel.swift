//
//  CounterpartyViewModel.swift
//  StampFolio
//
//  ViewModel for the Counterparty screen
//

import Foundation
import SwiftData
import Observation
import Kingfisher

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

    /// Current sort option
    var currentSortOption: CounterpartySortOption = .balanceDescending

    /// Filter state: Active lock-status filters ("locked" or "unlocked")
    var activeLockedFilters: Set<String> = []

    /// Filter state: Active asset-type filters ("named" or "numeric")
    var activeAssetTypeFilters: Set<String> = []

    /// Filter state: Active edition filters ("single" or "multiple")
    var activeEditionFilters: Set<String> = []

    /// On-demand asset detail cache (memory-only, cleared on app close/wallet delete)
    private var detailCache: [String: CounterpartyAsset] = [:]

    /// Kingfisher prefetcher for a full-collection artwork warm
    private var imagePrefetcher: ImagePrefetcher?

    /// Prefetchers for add-wallet / per-wallet refresh; not cancelled by each other
    private var incrementalImagePrefetchers: [ImagePrefetcher] = []

    /// Full-collection supply hydration; cancelled when a new full fetch starts
    private var supplyHydrationTask: Task<Void, Never>?

    /// Max concurrent `GET /assets/{asset}` calls while confirming supply
    private static let supplyHydrationConcurrency = 4

    // MARK: - Computed Properties

    /// Check if any filters are active
    var hasActiveFilters: Bool {
        !activeLockedFilters.isEmpty
            || !activeAssetTypeFilters.isEmpty
            || !activeEditionFilters.isEmpty
    }

    /// Filtered assets based on active collection filters
    var filteredAssets: [CounterpartyDisplay] {
        var result = assets

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

        if !activeEditionFilters.isEmpty {
            result = result.filter { display in
                guard let supply = display.asset.editionCount else { return false }
                for edition in activeEditionFilters {
                    if edition == "single" && supply == 1 { return true }
                    if edition == "multiple" && supply > 1 { return true }
                }
                return false
            }
        }

        return result
    }

    /// Assets matching a free-text query (ignores collection-tab filters)
    func assets(matching query: String) -> [CounterpartyDisplay] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return assets.filter { $0.matchesSearch(trimmed) }
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

        let nonStampBalances = allBalances.filter { !Self.matchesStampCPID($0.asset, longname: $0.assetLongname, stampCPIDs: excludingCPIDs) }

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
        let withKnownSupply = await Self.assetsByApplyingKnownSupply(
            incoming: displayAssets,
            existing: assets
        )
        assets = sortedAssets(withKnownSupply, by: currentSortOption, wallets: wallets)
        applyStampExclusion(excludingCPIDs)

        if assets.isEmpty && !fetchErrors.isEmpty {
            errorMessage = "Unable to load Counterparty assets: \(fetchErrors.first ?? "Unknown error")"
        }

        isLoading = false

        if !assets.isEmpty {
            fetchAssetsImages(forceRefresh: forceRefresh, cancelExisting: true)
            hydrateSupplies(from: assets, forceRefresh: forceRefresh, cancelExisting: true)
        }
    }

    /// Show collection loading when the first wallet is added
    @MainActor
    func prepareToLoadNewWallet() {
        guard assets.isEmpty else { return }
        isLoading = true
        errorMessage = nil
    }

    /// Fetch Counterparty assets for a single wallet (add-wallet and per-wallet refresh)
    /// - Parameters:
    ///   - wallet: The wallet to fetch assets for
    ///   - allWallets: All wallets for dedup and sorting context
    ///   - excludingCPIDs: Asset names already shown as Bitcoin Stamps elsewhere in the app
    ///   - forceRefresh: When true, bypasses cache and fetches from network
    /// - Returns: Number of non-Stamp Counterparty assets returned for this wallet, or `nil` if the fetch failed
    @MainActor
    @discardableResult
    func fetchAssetMetadata(
        for wallet: WalletConfig,
        allWallets: [WalletConfig],
        excludingCPIDs: Set<String> = [],
        forceRefresh: Bool = false
    ) async -> Int? {
        let showLoading = assets.isEmpty
        if showLoading { isLoading = true }
        errorMessage = nil
        defer { if showLoading { isLoading = false } }

        do {
            let balances = try await apiClient.fetchBalances(for: wallet.address, forceRefresh: forceRefresh)
            let nonStampBalances = balances.filter { !Self.matchesStampCPID($0.asset, longname: $0.assetLongname, stampCPIDs: excludingCPIDs) }
            let newDisplayAssets = nonStampBalances.map { CounterpartyDisplay(from: $0) }
            let withKnownSupply = await Self.assetsByApplyingKnownSupply(
                incoming: newDisplayAssets,
                existing: assets
            )

            // Remove existing assets from this wallet, then add fresh ones
            var updatedAssets = assets.filter { $0.walletAddress != wallet.address }
            updatedAssets.append(contentsOf: withKnownSupply)

            // Deduplicate by asset name
            var seen = Set<String>()
            let uniqueAssets = updatedAssets.filter { display in
                if seen.contains(display.id) { return false }
                seen.insert(display.id)
                return true
            }

            assets = sortedAssets(uniqueAssets, by: currentSortOption, wallets: allWallets)
            applyStampExclusion(excludingCPIDs)

            let hydrateIDs = Set(withKnownSupply.map(\.id))
            let toHydrate = assets.filter { hydrateIDs.contains($0.id) }
            if !toHydrate.isEmpty {
                fetchAssetsImages(from: toHydrate, forceRefresh: forceRefresh, cancelExisting: false)
                hydrateSupplies(from: toHydrate, forceRefresh: forceRefresh, cancelExisting: false)
            }

            return toHydrate.count
        } catch {
            errorMessage = "Failed to refresh \(wallet.displayName): \(error.localizedDescription)"
            return nil
        }
    }

    /// Prefetch artwork for the full collection
    func fetchAssetsImages(forceRefresh: Bool = false, cancelExisting: Bool = true) {
        fetchAssetsImages(from: assets, forceRefresh: forceRefresh, cancelExisting: cancelExisting)
    }

    /// Resolve artwork URLs then prefetch images into Kingfisher (never-expire disk cache).
    /// Full-collection loads cancel in-flight prefetch; add-wallet / per-wallet refresh does not.
    func fetchAssetsImages(from displays: [CounterpartyDisplay], forceRefresh: Bool = false, cancelExisting: Bool = true) {
        if cancelExisting {
            imagePrefetcher?.stop()
            incrementalImagePrefetchers.forEach { $0.stop() }
            incrementalImagePrefetchers.removeAll()
        }

        let assetsToResolve = displays.map(\.asset)
        guard !assetsToResolve.isEmpty else { return }

        let incremental = !cancelExisting
        let shouldForceRefresh = forceRefresh
        Task { [weak self] in
            var urls: [URL] = []
            await withTaskGroup(of: URL?.self) { group in
                for asset in assetsToResolve {
                    group.addTask {
                        await CounterpartyAssetImageResolver.shared.resolveImageURL(for: asset, forceRefresh: shouldForceRefresh)
                    }
                }
                for await url in group {
                    if let url { urls.append(url) }
                }
            }
            await self?.startImagePrefetch(urls: urls, incremental: incremental)
        }
    }

    @MainActor
    private func startImagePrefetch(urls: [URL], incremental: Bool) {
        guard !urls.isEmpty else { return }

        print("📦 Prefetching \(urls.count) Counterparty artwork images")

        let prefetcher = ImagePrefetcher(
            urls: urls,
            options: ProtocolImageCache.options(for: ProtocolImageCache.counterparty),
            completionHandler: { skippedResources, failedResources, completedResources in
                print("✅ Counterparty artwork prefetch done: \(completedResources.count) completed, \(skippedResources.count) cached, \(failedResources.count) failed")
            }
        )

        if incremental {
            incrementalImagePrefetchers.append(prefetcher)
        } else {
            imagePrefetcher = prefetcher
        }
        prefetcher.start()
    }

    /// Clear all assets and errors
    func clear() {
        supplyHydrationTask?.cancel()
        supplyHydrationTask = nil
        assets = []
        errorMessage = nil
    }

    /// Drop already-loaded assets whose name or longname is a stamp CPID.
    /// Re-applies exclusion to the full collection after stamps finish loading or a wallet is added.
    func applyStampExclusion(_ stampCPIDs: Set<String>) {
        guard !stampCPIDs.isEmpty else { return }
        assets.removeAll { display in
            Self.matchesStampCPID(display.asset.asset, longname: display.asset.assetLongname, stampCPIDs: stampCPIDs)
        }
    }

    /// Toggle a lock-status filter ("locked" or "unlocked")
    func toggleLockedFilter(_ value: String) {
        activeLockedFilters.toggleMembership(of: value)
    }

    /// Toggle an asset-type filter ("named" or "numeric")
    func toggleAssetTypeFilter(_ value: String) {
        activeAssetTypeFilters.toggleMembership(of: value)
    }

    /// Toggle an edition filter ("single" or "multiple")
    func toggleEditionFilter(_ edition: String) {
        activeEditionFilters.toggleMembership(of: edition)
    }

    /// Sort assets by the given option
    /// - Parameters:
    ///   - option: The sort option to apply
    ///   - wallets: Array of wallets for mapping wallet addresses to display names
    func sortAssets(by option: CounterpartySortOption, wallets: [WalletConfig]) {
        currentSortOption = option
        assets = sortedAssets(assets, by: option, wallets: wallets)
    }

    // MARK: - Market Data Fetching

    /// Fetch on-demand market data (supply, holders, floor price) for a single asset if not already cached
    @MainActor
    func fetchMarketDataIfNeeded(for displayAsset: CounterpartyDisplay) async {
        let assetName = displayAsset.asset.asset

        guard detailCache[assetName] == nil, !displayAsset.isLoadingMarketData else {
            return
        }

        if let index = assets.firstIndex(where: { $0.id == displayAsset.id }) {
            assets[index].isLoadingMarketData = true
        }

        do {
            let detail = try await apiClient.fetchAssetDetail(assetName)
            detailCache[assetName] = detail
            if let entry = CounterpartySupplyCache.Entry(asset: detail) {
                await CounterpartySupplyCache.shared.store(entry, for: assetName)
            }

            if let index = assets.firstIndex(where: { $0.id == displayAsset.id }) {
                let old = assets[index]
                assets[index] = CounterpartyDisplay(
                    asset: detail,
                    balance: old.balance,
                    divisible: detail.divisible,
                    walletAddress: old.walletAddress,
                    isLoadingMarketData: false
                )
            }
        } catch {
            if let index = assets.firstIndex(where: { $0.id == displayAsset.id }) {
                assets[index].isLoadingMarketData = false
            }
        }
    }

    /// Clear the on-demand market data cache (call on app close or wallet deletion)
    @MainActor
    func clearMarketDataCache() {
        detailCache.removeAll()

        for index in assets.indices {
            assets[index].isLoadingMarketData = false
        }
    }

    // MARK: - Supply Hydration

    /// Overlay in-memory + disk-cached supply, then confirm remaining assets via `GET /assets/{asset}`.
    /// Full-collection loads cancel in-flight hydration; add-wallet / per-wallet refresh does not.
    @MainActor
    private func hydrateSupplies(
        from displays: [CounterpartyDisplay],
        forceRefresh: Bool,
        cancelExisting: Bool
    ) {
        let names: [String]
        if forceRefresh {
            names = displays.map(\.asset.asset)
        } else {
            names = displays.compactMap { $0.asset.hasConfirmedSupply ? nil : $0.asset.asset }
        }
        guard !names.isEmpty else { return }

        if cancelExisting {
            supplyHydrationTask?.cancel()
        }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.fetchAndApplySupplies(names: names, forceRefresh: forceRefresh)
        }
        if cancelExisting {
            supplyHydrationTask = task
        }
    }

    private func fetchAndApplySupplies(names: [String], forceRefresh: Bool) async {
        let client = apiClient
        var storedSincePersist = 0

        await withTaskGroup(of: (String, CounterpartyAsset)?.self) { group in
            var iterator = names.makeIterator()
            var inFlight = 0

            func enqueueNext() {
                while inFlight < Self.supplyHydrationConcurrency, let name = iterator.next() {
                    inFlight += 1
                    group.addTask {
                        do {
                            let detail = try await client.fetchAsset(name, forceRefresh: forceRefresh)
                            return (name, detail)
                        } catch {
                            return nil
                        }
                    }
                }
            }

            enqueueNext()
            for await result in group {
                inFlight -= 1
                if Task.isCancelled {
                    group.cancelAll()
                    break
                }
                if let (name, detail) = result {
                    await applyFetchedSupply(name: name, detail: detail)
                    storedSincePersist += 1
                    if storedSincePersist.isMultiple(of: 25) {
                        await CounterpartySupplyCache.shared.persist()
                    }
                }
                enqueueNext()
            }
        }

        await CounterpartySupplyCache.shared.persist()
    }

    @MainActor
    private func applyFetchedSupply(name: String, detail: CounterpartyAsset) async {
        if let entry = CounterpartySupplyCache.Entry(asset: detail) {
            await CounterpartySupplyCache.shared.store(entry, for: name, persist: false)
        }
        guard let index = assets.firstIndex(where: { $0.asset.asset == name }) else { return }
        let old = assets[index]
        assets[index] = old.with(asset: old.asset.replacingOnChainMetadata(with: detail))
    }

    /// Fill unknown supply from the current session, then from the persistent supply cache.
    private static func assetsByApplyingKnownSupply(
        incoming: [CounterpartyDisplay],
        existing: [CounterpartyDisplay]
    ) async -> [CounterpartyDisplay] {
        let preserved = preservingHydratedSupply(incoming: incoming, existing: existing)
        return await applyingCachedSupplies(preserved)
    }

    private static func preservingHydratedSupply(
        incoming: [CounterpartyDisplay],
        existing: [CounterpartyDisplay]
    ) -> [CounterpartyDisplay] {
        guard !existing.isEmpty else { return incoming }
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        return incoming.map { display in
            guard !display.asset.hasConfirmedSupply,
                  let existingDisplay = existingByID[display.id],
                  existingDisplay.asset.hasConfirmedSupply else {
                return display
            }
            return display.with(asset: display.asset.applyingSupplyMetadata(from: existingDisplay.asset))
        }
    }

    private static func applyingCachedSupplies(
        _ displays: [CounterpartyDisplay]
    ) async -> [CounterpartyDisplay] {
        let names = displays.compactMap { $0.asset.hasConfirmedSupply ? nil : $0.asset.asset }
        guard !names.isEmpty else { return displays }
        let cached = await CounterpartySupplyCache.shared.entries(for: names)
        guard !cached.isEmpty else { return displays }
        return displays.map { display in
            guard !display.asset.hasConfirmedSupply,
                  let entry = cached[display.asset.asset] else {
                return display
            }
            return display.with(asset: entry.applied(to: display.asset))
        }
    }

    // MARK: - Private Methods

    private static func matchesStampCPID(_ asset: String, longname: String?, stampCPIDs: Set<String>) -> Bool {
        if stampCPIDs.contains(asset) { return true }
        if let longname, stampCPIDs.contains(longname) { return true }
        return false
    }

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
            return assets.sorted { wallets.displayName(for: $0.walletAddress).localizedCaseInsensitiveCompare(wallets.displayName(for: $1.walletAddress)) == .orderedAscending }

        case .walletDescending:
            return assets.sorted { wallets.displayName(for: $0.walletAddress).localizedCaseInsensitiveCompare(wallets.displayName(for: $1.walletAddress)) == .orderedDescending }
        }
    }
}
