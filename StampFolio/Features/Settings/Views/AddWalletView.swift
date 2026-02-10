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
    @Environment(CollectionViewModel.self) private var collectionViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appColorScheme) private var appColorScheme
    @Query(sort: \Wallet.addedDate, order: .reverse) private var wallets: [Wallet]
    
    // MARK: - State
    
    @AppStorage("isDarkMode") private var isDarkMode = true
    @State private var walletName: String = ""
    @State private var selectedColor: WalletColor = .gray
    @FocusState private var isAddressFocused: Bool
    
    // MARK: - Body
    
    var body: some View {
        @Bindable var viewModel = viewModel
        
        NavigationStack {
            Form {
                // Address Input Section
                Section {
                    HStack {
                        TextField("Bitcoin Address", text: $viewModel.walletAddressInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($isAddressFocused)
                            .tint(appColorScheme.primary)
                            .accessibilityLabel("Bitcoin wallet address")
                            .accessibilityHint("Enter a Bitcoin address starting with 1, 3, bc1q, or bc1p")
                        
                        Button {
                            viewModel.showQRScanner = true
                        } label: {
                            Image(systemName: "qrcode")
                                .foregroundStyle(appColorScheme.primary)
                                .font(.system(size: 22))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Scan QR code")
                        .accessibilityHint("Opens camera to scan a Bitcoin wallet QR code")
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Wallet Address")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        if let error = viewModel.validationError {
                            Text(error)
                                .foregroundStyle(.red)
                        }
                        
                        Text("Supports all Bitcoin address formats.")
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
                
                // Wallet Color Section
                Section {
                    HStack(spacing: 18) {
                        ForEach(WalletColor.allCases) { color in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedColor = color
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(color.color)
                                        .frame(width: 32, height: 32)
                                    
                                    if selectedColor == color {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11))
                                            .fontWeight(.semibold)
                                            .foregroundStyle(isDarkMode ? .black : .white)
                                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(color.displayName) color")
                            .accessibilityHint(selectedColor == color ? "Selected" : "Select this color")
                        }
                    }
                    .frame(maxWidth: .infinity)
                } header: {
                    Text("Wallet Color")
                }
                
                // Wallet Name Section
                Section {
                    TextField("Name (Optional)", text: $walletName)
                        .textInputAutocapitalization(.words)
                        .tint(appColorScheme.primary)
                        .accessibilityLabel("Wallet name")
                        .accessibilityHint("Enter a custom name for this wallet")
                } header: {
                    Text("Wallet Name")
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Add Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) {
                        viewModel.walletAddressInput = ""
                        walletName = ""
                        selectedColor = .gray
                        viewModel.resetValidation()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Cancel")
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            let trimmedName = walletName.trimmingCharacters(in: .whitespacesAndNewlines)
                            let label = trimmedName.isEmpty ? nil : trimmedName
                            await viewModel.addWallet(
                                address: viewModel.walletAddressInput,
                                label: label,
                                colorName: selectedColor.rawValue,
                                context: modelContext
                            )
                            // Check if wallet was successfully added (input cleared, no validation error)
                            if viewModel.walletAddressInput.isEmpty && viewModel.validationError == nil {
                                // Immediately fetch stamps metadata + images for all wallets
                                await collectionViewModel.fetchStampsMetadata(for: wallets)
                                
                                // Reset wallet name and color if successfully added
                                walletName = ""
                                selectedColor = .gray
                                dismiss()
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(appColorScheme.primary)
                    .disabled(viewModel.walletAddressInput.isEmpty || viewModel.isValidating)
                    .fontWeight(.semibold)
                    .accessibilityLabel("Add wallet")
                }
            }
            .overlay {
                if viewModel.isValidating {
                    validatingOverlay
                }
            }
            .onAppear {
                isAddressFocused = false
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
                .foregroundStyle(appColorScheme.primary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(addressType.rawValue)
                    .font(.body)
                
                Text(viewModel.walletAddressInput.truncatedAddress(prefixLength: 6, suffixLength: 6))
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
                    .tint(appColorScheme.primary)
                
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
        .environment(CollectionViewModel())
        .modelContainer(for: Wallet.self, inMemory: true)
}
