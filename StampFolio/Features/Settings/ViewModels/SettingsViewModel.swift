//
//  SettingsViewModel.swift
//  StampFolio
//
//  ViewModel for the Settings screen
//

import Foundation
import SwiftData
import Observation

/// ViewModel managing settings state and wallet operations
@Observable
final class SettingsViewModel {
    
    // MARK: - Properties
    
    /// Current wallet being added (for validation flow)
    var walletAddressInput: String = ""
    
    /// Validation error message (if any)
    var validationError: String?
    
    /// Loading state for wallet validation
    var isValidating: Bool = false
    
    /// Whether add wallet sheet is presented
    var showAddWallet: Bool = false
    
    /// Whether QR scanner sheet is presented
    var showQRScanner: Bool = false
    
    /// Alert message to display
    var alertMessage: String?
    
    /// Whether to show alert
    var showAlert: Bool = false

    /// Add-wallet Asset Overview counts. Ordinals stays 0 until that tab ships.
    var ordinalsCount = 0
    var counterpartyCount = 0
    var stampCount = 0
    
    // MARK: - Private Properties
    
    private let addressValidator = BitcoinAddressValidator()
    private let stampAPI = StampchainAPIClient()
    private let counterpartyAPI = CounterpartyAPIClient()
    private var overviewTask: Task<Void, Never>?
    private var overviewGeneration = 0
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Public Methods
    
    /// Validate locally and save a wallet. Asset loading happens after the add sheet dismisses.
    /// - Returns: The saved wallet, or `nil` when validation or save failed
    @MainActor
    func addWallet(address: String, label: String? = nil, colorName: String = WalletColor.gray.rawValue, context: ModelContext) -> WalletConfig? {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard addressValidator.isValid(trimmedAddress) else {
            validationError = "Invalid Bitcoin address format"
            return nil
        }
        
        let descriptor = FetchDescriptor<WalletConfig>(
            predicate: #Predicate { $0.address == trimmedAddress }
        )
        
        do {
            let existingWallets = try context.fetch(descriptor)
            if !existingWallets.isEmpty {
                validationError = "This wallet has already been added"
                return nil
            }
        } catch {
            validationError = "Error checking existing wallets"
            return nil
        }
        
        isValidating = true
        validationError = nil
        
        let wallet = WalletConfig(address: trimmedAddress, label: label, colorName: colorName)
        context.insert(wallet)
        
        do {
            try context.save()
            walletAddressInput = ""
            showAddWallet = false
            isValidating = false
            resetAssetOverview()
            return wallet
        } catch {
            validationError = "Failed to save wallet"
            isValidating = false
            return nil
        }
    }
    
    /// Warn after load if the new wallet has no Stamps and no Counterparty assets
    func notifyIfWalletEmpty(stampCount: Int, counterpartyCount: Int) {
        guard stampCount == 0 && counterpartyCount == 0 else { return }
        alertMessage = "This wallet doesn't appear to have any stamps or Counterparty assets yet. It has been added anyway."
        showAlert = true
    }
    
    /// Handle QR code scan result
    /// - Parameter result: The scanned string
    func handleQRScan(_ result: String) {
        // Extract Bitcoin address from QR code
        // QR codes may be in format "bitcoin:address" or just the address
        var address = result
        
        if result.lowercased().hasPrefix("bitcoin:") {
            address = String(result.dropFirst(8))
            // Remove any query parameters
            if let queryIndex = address.firstIndex(of: "?") {
                address = String(address[..<queryIndex])
            }
        }
        
        walletAddressInput = address
        showQRScanner = false
        showAddWallet = true
    }
    
    /// Delete a wallet
    /// - Parameters:
    ///   - wallet: The wallet to delete
    ///   - context: SwiftData model context
    ///   - stampViewModel: Stamp view model to clear market data cache
    ///   - counterpartyViewModel: Counterparty view model to clear asset detail cache
    func deleteWallet(
        _ wallet: WalletConfig,
        context: ModelContext,
        stampViewModel: StampViewModel? = nil,
        counterpartyViewModel: CounterpartyViewModel? = nil
    ) {
        context.delete(wallet)
        
        // Clear caches when wallet is deleted (on main actor)
        if let viewModel = stampViewModel {
            Task { @MainActor in
                viewModel.clearMarketDataCache()
            }
        }
        if let viewModel = counterpartyViewModel {
            Task { @MainActor in
                viewModel.clearMarketDataCache()
            }
        }
        
        do {
            try context.save()
        } catch {
            alertMessage = "Failed to delete wallet"
            showAlert = true
        }
    }
    
    /// Reset validation state
    func resetValidation() {
        validationError = nil
        isValidating = false
        resetAssetOverview()
    }

    /// Debounced lookup for the Add Wallet Asset Overview. Invalid addresses reset to 0.
    @MainActor
    func addressInputDidChange(_ address: String) {
        overviewTask?.cancel()
        overviewGeneration += 1
        ordinalsCount = 0
        counterpartyCount = 0
        stampCount = 0

        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard addressValidator.isValid(trimmed) else { return }

        let generation = overviewGeneration
        overviewTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, generation == self.overviewGeneration else { return }
            await self.loadAssetOverview(for: trimmed, generation: generation)
        }
    }

    func overviewCount(for protocolType: ProtocolType) -> Int {
        switch protocolType {
        case .ordinals: return ordinalsCount
        case .counterparty: return counterpartyCount
        case .stamps: return stampCount
        }
    }

    // MARK: - Asset Overview

    @MainActor
    private func resetAssetOverview() {
        overviewTask?.cancel()
        overviewGeneration += 1
        ordinalsCount = 0
        counterpartyCount = 0
        stampCount = 0
    }

    @MainActor
    private func loadAssetOverview(for address: String, generation: Int) async {
        ordinalsCount = 0
        counterpartyCount = 0
        stampCount = 0

        var stampCPIDs = Set<String>()
        do {
            let stamps = try await stampAPI.fetchStampsByWallet(address)
            guard generation == overviewGeneration else { return }
            stampCPIDs = Set(stamps.map(\.counterpartyId))
            await tickStampCount(to: stamps.count, generation: generation)
        } catch {
            guard generation == overviewGeneration else { return }
        }

        guard generation == overviewGeneration else { return }

        do {
            var cursor: Int?
            for _ in 0..<20 {
                guard generation == overviewGeneration else { return }
                let page = try await counterpartyAPI.fetchBalancePage(for: address, cursor: cursor)
                let added = page.balances.filter { !Self.matchesStampCPID($0, stampCPIDs: stampCPIDs) }.count
                guard generation == overviewGeneration else { return }
                if added > 0 {
                    counterpartyCount += added
                }
                guard let nextCursor = page.nextCursor else { break }
                cursor = nextCursor
            }
        } catch {
            return
        }
    }

    @MainActor
    private func tickStampCount(to target: Int, generation: Int) async {
        guard target > 0 else { return }
        let steps = min(target, 24)
        let stepSize = max(1, target / steps)
        var shown = 0
        while shown < target {
            guard generation == overviewGeneration else { return }
            shown = min(shown + stepSize, target)
            stampCount = shown
            if shown < target {
                try? await Task.sleep(for: .milliseconds(25))
            }
        }
    }

    private static func matchesStampCPID(_ balance: CounterpartyAssetBalance, stampCPIDs: Set<String>) -> Bool {
        if stampCPIDs.contains(balance.asset) { return true }
        if let longname = balance.assetLongname, stampCPIDs.contains(longname) { return true }
        return false
    }
}
