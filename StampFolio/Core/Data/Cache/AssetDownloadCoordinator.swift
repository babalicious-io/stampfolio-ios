//
//  AssetDownloadCoordinator.swift
//  StampFolio
//
//  App-level “Downloading Assets” overlay. Collection view models do not own the popup.
//

import Foundation
import Observation
import SwiftData

/// Newest-first visual assets that still need a collection preview cached.
@MainActor
protocol ProtocolDownloadSource: AnyObject {
    /// Cache up to `limit` newest visual previews. Stamps await pixel images and HTML/SVG
    /// snapshots. `onProgress` is `(completed, total)`.
    func prefetchPriorityDownloads(
        walletAddress: String?,
        limit: Int,
        onProgress: @escaping (Int, Int) -> Void
    ) async

    /// Continue caching after the overlay dismisses.
    func prefetchRemainderDownloads(walletAddress: String?, afterPriorityLimit: Int)

    func prefetchPriorityStaticGIFs(limit: Int, onProgress: @escaping (Int, Int) -> Void) async
    func prefetchRemainderStaticGIFs(afterPriorityLimit: Int)
}

/// Placeholder until Ordinals has a view model. Overlay must not wait on this protocol today.
@MainActor
final class OrdinalsDownloadSource: ProtocolDownloadSource {
    func prefetchPriorityDownloads(
        walletAddress: String?,
        limit: Int,
        onProgress: @escaping (Int, Int) -> Void
    ) async {
        onProgress(0, 0)
    }

    func prefetchRemainderDownloads(walletAddress: String?, afterPriorityLimit: Int) {}

    func prefetchPriorityStaticGIFs(limit: Int, onProgress: @escaping (Int, Int) -> Void) async {
        onProgress(0, 0)
    }

    func prefetchRemainderStaticGIFs(afterPriorityLimit: Int) {}
}

/// Shared overlay state for add-wallet and Static GIF. Presented from MainTabView and SettingsView.
@Observable
@MainActor
final class AssetDownloadCoordinator {

    static let priorityLimit = 20

    /// Compact “Downloading Assets” popup is visible
    private(set) var isPresented = false

    /// First-wallet path: Stamp and Counterparty grids stay hidden until the popup closes
    private(set) var withholdsCollections = false

    private(set) var completedCount = 0
    private(set) var totalCount = 0

    /// Collection `.task`, Search, and Slideshow must not start a full fetch while the overlay
    /// owns prefetch — that path calls `fetchStampsImages(cancelExisting: true)` and cancels
    /// snapshot waiters.
    var blocksCollectionFetch: Bool { isPresented }

    private var runID = 0
    private var protocolCompleted: [ProtocolType: Int] = [:]
    private var protocolTotals: [ProtocolType: Int] = [:]
    private let ordinalsSource = OrdinalsDownloadSource()

    // MARK: - Add Wallet

    /// Show the overlay, fetch the new wallet, wait for each enabled protocol’s newest 20 previews.
    func downloadAfterAddingWallet(
        wallet: WalletConfig,
        allWallets: [WalletConfig],
        isFirstWallet: Bool,
        stampViewModel: StampViewModel,
        counterpartyViewModel: CounterpartyViewModel,
        settingsViewModel: SettingsViewModel
    ) async {
        begin(withholdsCollections: isFirstWallet)
        let id = runID

        let stampCount = await stampViewModel.fetchAssetMetadata(
            for: wallet,
            allWallets: allWallets,
            startBackgroundWork: false
        )
        let stampCPIDs = stampViewModel.stampCPIDs
        let counterpartyCount = await counterpartyViewModel.fetchAssetMetadata(
            for: wallet,
            allWallets: allWallets,
            excludingCPIDs: stampCPIDs,
            startBackgroundWork: false
        )
        counterpartyViewModel.applyStampExclusion(stampCPIDs)
        if let stampCount, let counterpartyCount {
            settingsViewModel.notifyIfWalletEmpty(stampCount: stampCount, counterpartyCount: counterpartyCount)
        }

        guard id == runID else { return }

        if Self.isEnabled(.counterparty) {
            let newAssets = counterpartyViewModel.assets.filter { $0.walletAddress == wallet.address }
            await counterpartyViewModel.hydrateSuppliesAndWait(from: newAssets, wallets: allWallets)
        }

        guard id == runID else { return }

        await runPriorityGates(
            walletAddress: wallet.address,
            stampViewModel: stampViewModel,
            counterpartyViewModel: counterpartyViewModel
        )

        guard id == runID else { return }
        finish()

        if Self.isEnabled(.stamps) {
            stampViewModel.prefetchRemainderDownloads(
                walletAddress: wallet.address,
                afterPriorityLimit: Self.priorityLimit
            )
        }
        if Self.isEnabled(.counterparty) {
            counterpartyViewModel.prefetchRemainderDownloads(
                walletAddress: wallet.address,
                afterPriorityLimit: Self.priorityLimit
            )
        }
    }

    // MARK: - Static GIF

    /// Settings toggle: cache 20 newest static GIF thumbs per enabled protocol, then the rest.
    /// Loads collection metadata first when the user has never opened those tabs (default
    /// landing tab is Ordinals, so both view models can still be empty).
    func downloadStaticGIFPreviews(
        stampViewModel: StampViewModel,
        counterpartyViewModel: CounterpartyViewModel,
        wallets: [WalletConfig]
    ) async {
        guard !isPresented else { return }
        guard !wallets.isEmpty else { return }
        begin(withholdsCollections: false)
        let id = runID

        await loadMetadataIfNeeded(
            stampViewModel: stampViewModel,
            counterpartyViewModel: counterpartyViewModel,
            wallets: wallets
        )
        guard id == runID else { return }

        await withTaskGroup(of: Void.self) { group in
            if Self.isEnabled(.stamps) {
                group.addTask { @MainActor in
                    await stampViewModel.prefetchPriorityStaticGIFs(limit: Self.priorityLimit) { done, total in
                        self.updateProgress(for: .stamps, completed: done, total: total)
                    }
                }
            }
            if Self.isEnabled(.counterparty) {
                group.addTask { @MainActor in
                    await counterpartyViewModel.prefetchPriorityStaticGIFs(limit: Self.priorityLimit) { done, total in
                        self.updateProgress(for: .counterparty, completed: done, total: total)
                    }
                }
            }
            if Self.isEnabled(.ordinals) {
                group.addTask { @MainActor in
                    await self.ordinalsSource.prefetchPriorityStaticGIFs(limit: Self.priorityLimit) { done, total in
                        self.updateProgress(for: .ordinals, completed: done, total: total)
                    }
                }
            }
        }

        guard id == runID else { return }
        finish()

        if Self.isEnabled(.stamps) {
            stampViewModel.prefetchRemainderStaticGIFs(afterPriorityLimit: Self.priorityLimit)
        }
        if Self.isEnabled(.counterparty) {
            counterpartyViewModel.prefetchRemainderStaticGIFs(afterPriorityLimit: Self.priorityLimit)
        }
    }

    // MARK: - Private

    private func begin(withholdsCollections: Bool) {
        runID += 1
        protocolCompleted = [:]
        protocolTotals = [:]
        completedCount = 0
        totalCount = 0
        self.withholdsCollections = withholdsCollections
        isPresented = true
    }

    private func finish() {
        isPresented = false
        withholdsCollections = false
        completedCount = 0
        totalCount = 0
        protocolCompleted = [:]
        protocolTotals = [:]
    }

    /// Static GIF can be toggled before any collection tab has fetched. Stamp CPIDs are
    /// loaded first so Counterparty exclusion is complete.
    private func loadMetadataIfNeeded(
        stampViewModel: StampViewModel,
        counterpartyViewModel: CounterpartyViewModel,
        wallets: [WalletConfig]
    ) async {
        let needsStamps = Self.isEnabled(.stamps) || Self.isEnabled(.counterparty)
        if needsStamps, stampViewModel.assets.isEmpty {
            await stampViewModel.fetchAssetsMetadata(for: wallets)
        }
        guard Self.isEnabled(.counterparty), counterpartyViewModel.assets.isEmpty else { return }
        let stampCPIDs = stampViewModel.stampCPIDs
        await counterpartyViewModel.fetchAssetsMetadata(
            for: wallets,
            excludingCPIDs: stampCPIDs,
            startBackgroundWork: false
        )
        counterpartyViewModel.applyStampExclusion(stampCPIDs)
        await counterpartyViewModel.hydrateSuppliesAndWait(
            from: counterpartyViewModel.assets,
            wallets: wallets
        )
    }

    private func runPriorityGates(
        walletAddress: String,
        stampViewModel: StampViewModel,
        counterpartyViewModel: CounterpartyViewModel
    ) async {
        await withTaskGroup(of: Void.self) { group in
            if Self.isEnabled(.stamps) {
                group.addTask { @MainActor in
                    await stampViewModel.prefetchPriorityDownloads(
                        walletAddress: walletAddress,
                        limit: Self.priorityLimit
                    ) { done, total in
                        self.updateProgress(for: .stamps, completed: done, total: total)
                    }
                }
            }
            if Self.isEnabled(.counterparty) {
                group.addTask { @MainActor in
                    await counterpartyViewModel.prefetchPriorityDownloads(
                        walletAddress: walletAddress,
                        limit: Self.priorityLimit
                    ) { done, total in
                        self.updateProgress(for: .counterparty, completed: done, total: total)
                    }
                }
            }
            if Self.isEnabled(.ordinals) {
                group.addTask { @MainActor in
                    await self.ordinalsSource.prefetchPriorityDownloads(
                        walletAddress: walletAddress,
                        limit: Self.priorityLimit
                    ) { done, total in
                        self.updateProgress(for: .ordinals, completed: done, total: total)
                    }
                }
            }
        }
    }

    private func updateProgress(for protocolType: ProtocolType, completed: Int, total: Int) {
        protocolCompleted[protocolType] = completed
        protocolTotals[protocolType] = total
        completedCount = protocolCompleted.values.reduce(0, +)
        totalCount = protocolTotals.values.reduce(0, +)
    }

    /// `@AppStorage` defaults are true; `UserDefaults.bool` is false when the key is missing.
    private static func isEnabled(_ protocolType: ProtocolType) -> Bool {
        (UserDefaults.standard.object(forKey: protocolType.storageKey) as? Bool) ?? true
    }
}
