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
    @Environment(StampViewModel.self) private var stampViewModel
    @Environment(CounterpartyViewModel.self) private var counterpartyViewModel
    @Environment(AssetDownloadCoordinator.self) private var downloadCoordinator
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appColorScheme) private var appColorScheme
    @Query(sort: \WalletConfig.addedDate, order: .reverse) private var wallets: [WalletConfig]
    
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
                                .font(.system(size: 24))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Scan QR code")
                        .accessibilityHint("Opens camera to scan a Bitcoin wallet QR code")
                    }
                    .padding(.vertical, 2)
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
                
                // Asset Overview
                Section {
                    assetOverview
                } header: {
                    Text("Asset Overview")
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
                        addWallet()
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
            .onAppear {
                isAddressFocused = false
                viewModel.addressInputDidChange(viewModel.walletAddressInput)
            }
            .onChange(of: viewModel.walletAddressInput) { _, newValue in
                viewModel.addressInputDidChange(newValue)
            }
            .sheet(isPresented: $viewModel.showQRScanner) {
                QRScannerView { result in
                    viewModel.handleQRScan(result)
                }
            }
        }
    }
    
    // MARK: - Asset Overview
    
    private var assetOverview: some View {
        HStack(alignment: .top, spacing: 0) {
            overviewColumn(for: .ordinals)
            Spacer(minLength: 0)
            overviewColumn(for: .counterparty)
            Spacer(minLength: 0)
            overviewColumn(for: .stamps)
        }
        .animation(.snappy, value: viewModel.stampCount)
        .animation(.snappy, value: viewModel.counterpartyCount)
        .padding(.vertical, 4)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private func overviewColumn(for protocolType: ProtocolType) -> some View {
        let count = viewModel.overviewCount(for: protocolType)
        return VStack(spacing: 2) {
            Text(protocolType.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(count)")
                .font(.title2)
                .fontWeight(.semibold)
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(protocolType.rawValue) \(count)")
    }
    
    // MARK: - Add Wallet
    
    /// Save locally, dismiss immediately, then let the download overlay load only the new wallet
    private func addWallet() {
        let trimmedName = walletName.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = trimmedName.isEmpty ? nil : trimmedName
        
        guard let wallet = viewModel.addWallet(
            address: viewModel.walletAddressInput,
            label: label,
            colorName: selectedColor.rawValue,
            context: modelContext
        ) else { return }
        
        let allWallets = walletsIncluding(wallet)
        let isFirstWallet = allWallets.count == 1
        let stampVM = stampViewModel
        let counterpartyVM = counterpartyViewModel
        let settingsVM = viewModel
        let coordinator = downloadCoordinator
        
        // Show collection loading before the sheet goes away (first wallet only)
        stampVM.prepareToLoadNewWallet()
        counterpartyVM.prepareToLoadNewWallet()
        
        // Unstructured task survives dismissing this view. The coordinator shows the
        // Downloading Assets popup, fetches metadata, and waits for each enabled
        // protocol's newest 20 previews before the collections appear.
        Task { @MainActor in
            await coordinator.downloadAfterAddingWallet(
                wallet: wallet,
                allWallets: allWallets,
                isFirstWallet: isFirstWallet,
                stampViewModel: stampVM,
                counterpartyViewModel: counterpartyVM,
                settingsViewModel: settingsVM
            )
        }
        
        walletName = ""
        selectedColor = .gray
        dismiss()
    }
    
    /// `@Query` may not include the just-saved wallet yet; pass it explicitly for fetch/sort
    private func walletsIncluding(_ wallet: WalletConfig) -> [WalletConfig] {
        if wallets.contains(where: { $0.address == wallet.address }) {
            return wallets
        }
        return wallets + [wallet]
    }
}

// MARK: - Preview

#Preview {
    AddWalletView()
        .environment(SettingsViewModel())
        .environment(StampViewModel())
        .environment(CounterpartyViewModel())
        .environment(AssetDownloadCoordinator())
        .modelContainer(for: WalletConfig.self, inMemory: true)
}
