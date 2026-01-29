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
    
    // MARK: - State
    
    @State private var walletName: String = ""
    @State private var selectedColor: WalletColor = .purple
    @FocusState private var isAddressFocused: Bool
    
    // MARK: - Body
    
    var body: some View {
        @Bindable var viewModel = viewModel
        
        NavigationStack {
            Form {
                // Wallet Name Section
                Section {
                    TextField("Wallet Name (Optional)", text: $walletName)
                        .textInputAutocapitalization(.words)
                        .accessibilityLabel("Wallet name")
                        .accessibilityHint("Enter a custom name for this wallet")
                } header: {
                    Text("Wallet Name")
                } footer: {
                    Text("Give this wallet a custom name to easily identify it. Leave empty to use the truncated address.")
                }
                
                // Wallet Color Section
                Section {
                    HStack(spacing: 16) {
                        ForEach(WalletColor.allCases) { color in
                            Button {
                                selectedColor = color
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(color.color)
                                        .frame(width: 40, height: 40)
                                    
                                    if selectedColor == color {
                                        Image(systemName: "checkmark")
                                            .font(.body)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .accessibilityLabel("\(color.displayName) color")
                            .accessibilityHint(selectedColor == color ? "Selected" : "Select this color")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } header: {
                    Text("Wallet Color")
                }
                
                // Address Input Section
                Section {
                    TextField("Bitcoin Address", text: $viewModel.walletAddressInput)
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
                                .foregroundStyle(.red)
                        }
                        
                        Text("Supports all Bitcoin address formats: Legacy (1...), P2SH (3...), SegWit (bc1q...), Taproot (bc1p...)")
                            .foregroundStyle(.secondary)
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
                        walletName = ""
                        selectedColor = .purple
                        viewModel.resetValidation()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        Task {
                            let trimmedName = walletName.trimmingCharacters(in: .whitespacesAndNewlines)
                            let label = trimmedName.isEmpty ? nil : trimmedName
                            await viewModel.addWallet(
                                address: viewModel.walletAddressInput,
                                label: label,
                                colorName: selectedColor.rawValue,
                                context: modelContext
                            )
                            if !viewModel.showAddWallet {
                                // Reset wallet name and color if successfully added
                                walletName = ""
                                selectedColor = .purple
                            }
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
                .foregroundStyle(.purple)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(addressType.rawValue)
                    .font(.body)
                
                Text(viewModel.walletAddressInput.truncatedAddress(prefixLength: 8, suffixLength: 8))
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    .tint(.purple)
                
                Text("Validating wallet...")
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            .padding(32)
            .glassEffect(in: .rect(cornerRadius: 24))
        }
    }
}

// MARK: - Preview

#Preview {
    AddWalletView()
        .environment(SettingsViewModel())
        .modelContainer(for: Wallet.self, inMemory: true)
}
