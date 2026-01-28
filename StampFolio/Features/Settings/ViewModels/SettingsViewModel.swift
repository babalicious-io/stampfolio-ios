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
    
    // MARK: - Private Properties
    
    private let addressValidator = BitcoinAddressValidator()
    private let apiClient = StampchainAPIClient()
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Public Methods
    
    /// Validate and add a wallet address
    /// - Parameters:
    ///   - address: The Bitcoin address to add
    ///   - label: Optional custom name for the wallet
    ///   - context: SwiftData model context
    @MainActor
    func addWallet(address: String, label: String? = nil, context: ModelContext) async {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Local validation first
        guard addressValidator.isValid(trimmedAddress) else {
            validationError = "Invalid Bitcoin address format"
            return
        }
        
        // Check if wallet already exists
        let descriptor = FetchDescriptor<Wallet>(
            predicate: #Predicate { $0.address == trimmedAddress }
        )
        
        do {
            let existingWallets = try context.fetch(descriptor)
            if !existingWallets.isEmpty {
                validationError = "This wallet has already been added"
                return
            }
        } catch {
            validationError = "Error checking existing wallets"
            return
        }
        
        isValidating = true
        validationError = nil
        
        // Verify wallet has stamps via API (optional enhancement)
        do {
            let hasStamps = try await apiClient.validateWalletHasStamps(trimmedAddress)
            
            if !hasStamps {
                // Still allow adding, but show a warning
                alertMessage = "This wallet doesn't appear to have any stamps yet. It has been added anyway."
                showAlert = true
            }
            
            // Create and save wallet
            let wallet = Wallet(address: trimmedAddress, label: label)
            context.insert(wallet)
            try context.save()
            
            // Reset input state
            walletAddressInput = ""
            showAddWallet = false
            
        } catch {
            // If API validation fails, still add the wallet
            let wallet = Wallet(address: trimmedAddress, label: label)
            context.insert(wallet)
            
            do {
                try context.save()
                walletAddressInput = ""
                showAddWallet = false
            } catch {
                validationError = "Failed to save wallet"
            }
        }
        
        isValidating = false
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
    func deleteWallet(_ wallet: Wallet, context: ModelContext) {
        context.delete(wallet)
        
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
    }
}
