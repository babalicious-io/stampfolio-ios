//
//  AddWalletView.swift
//  StampFolio
//
//  Form for adding a new Bitcoin wallet
//

import SwiftUI
import SwiftData

/// View for adding a new Bitcoin wallet address
struct AddWalletView: View {
    
    // MARK: - Environment
    
    @Environment(SettingsViewModel.self) private var viewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - State
    
    @FocusState private var isAddressFocused: Bool
    
    // MARK: - Body
    
    var body: some View {
        @Bindable var viewModel = viewModel
        
        NavigationStack {
            Form {
                // Address Input Section
                Section {
                    TextField("Bitcoin Address", text: $viewModel.walletAddressInput)
                        .font(.monospace)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isAddressFocused)
                        .accessibilityLabel("Bitcoin wallet address")
                        .accessibilityHint("Enter a Bitcoin address starting with 1, 3, bc1q, or bc1p")
                    
                    // QR Scanner Button
                    Button {
                        viewModel.showQRScanner = true
                    } label: {
                        HStack {
                            Image(systemName: "qrcode.viewfinder")
                            Text("Scan QR Code")
                        }
                    }
                    .accessibilityLabel("Scan QR code")
                    .accessibilityHint("Opens camera to scan a Bitcoin wallet QR code")
                } header: {
                    Text("Wallet Address")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        if let error = viewModel.validationError {
                            Text(error)
                                .foregroundStyle(Color.error)
                        }
                        
                        Text("Supports all Bitcoin address formats: Legacy (1...), P2SH (3...), SegWit (bc1q...), Taproot (bc1p...)")
                            .foregroundStyle(Color.secondaryText(for: colorScheme))
                    }
                }
                
                // Address Type Preview
                if !viewModel.walletAddressInput.isEmpty {
                    Section {
                        addressTypePreview
                    } header: {
                        Text("Address Preview")
                    }
                }
            }
            .navigationTitle("Add Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        viewModel.walletAddressInput = ""
                        viewModel.resetValidation()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        Task {
                            await viewModel.addWallet(
                                address: viewModel.walletAddressInput,
                                context: modelContext
                            )
                        }
                    }
                    .disabled(viewModel.walletAddressInput.isEmpty || viewModel.isValidating)
                    .fontWeight(.semibold)
                }
            }
            .overlay {
                if viewModel.isValidating {
                    validatingOverlay
                }
            }
            .onAppear {
                isAddressFocused = true
            }
            .sheet(isPresented: $viewModel.showQRScanner) {
                QRScannerView { result in
                    viewModel.handleQRScan(result)
                }
            }
        }
    }
    
    // MARK: - Address Type Preview
    
    private var addressTypePreview: some View {
        let addressType = BitcoinAddressType.detect(from: viewModel.walletAddressInput)
        
        return HStack {
            Image(systemName: addressTypeIcon(for: addressType))
                .foregroundStyle(Color.brand)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(addressType.rawValue)
                    .font(.body)
                
                Text(viewModel.walletAddressInput.truncatedAddress(prefixLength: 8, suffixLength: 8))
                    .font(.monospaceSm)
                    .foregroundStyle(Color.secondaryText(for: colorScheme))
            }
        }
    }
    
    private func addressTypeIcon(for type: BitcoinAddressType) -> String {
        switch type {
        case .legacy:
            return "1.circle"
        case .segwitP2SH:
            return "3.circle"
        case .nativeSegwit:
            return "q.circle"
        case .taproot:
            return "p.circle"
        case .unknown:
            return "questionmark.circle"
        }
    }
    
    // MARK: - Validating Overlay
    
    private var validatingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(Color.brand)
                
                Text("Validating wallet...")
                    .font(.body)
                    .foregroundStyle(Color.primaryText(for: colorScheme))
            }
            .padding(32)
            .glassCard()
        }
    }
}

// MARK: - Preview

#Preview {
    AddWalletView()
        .environment(SettingsViewModel())
        .modelContainer(for: Wallet.self, inMemory: true)
}
