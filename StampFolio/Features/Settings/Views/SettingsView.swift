//
//  SettingsView.swift
//  StampFolio
//
//  Settings screen with theme toggle and wallet management
//

import SwiftUI
import SwiftData

/// Settings view with theme toggle and wallet management
struct SettingsView: View {
    
    // MARK: - Environment
    
    @Environment(SettingsViewModel.self) private var viewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Wallet.addedDate, order: .reverse) private var wallets: [Wallet]
    
    // MARK: - State
    
    @AppStorage("isDarkMode") private var isDarkMode = true
    @State private var editingWallet: Wallet?
    
    // MARK: - Body
    
    var body: some View {
        @Bindable var viewModel = viewModel
        
        NavigationStack {
            List {
                // Theme Section
                Section {
                    themeToggle
                } header: {
                    Text("Appearance")
                }
                
                // Wallets Section
                Section {
                    if wallets.isEmpty {
                        emptyWalletsRow
                    } else {
                        ForEach(wallets) { wallet in
                            WalletRow(wallet: wallet)
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        editingWallet = wallet
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteWallet(wallet)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    
                    addWalletButton
                } header: {
                    Text("Wallets")
                } footer: {
                    Text("Add Bitcoin wallets to view your stamp collection. Supports all address formats.")
                }
                
                // About Section
                Section {
                    aboutRow
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Close settings")
                }
            }
            .sheet(isPresented: $viewModel.showAddWallet) {
                AddWalletView()
            }
            .sheet(item: $editingWallet) { wallet in
                EditWalletView(wallet: wallet)
            }
            .alert("Notice", isPresented: $viewModel.showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                if let message = viewModel.alertMessage {
                    Text(message)
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
    
    // MARK: - Theme Toggle
    
    private var themeToggle: some View {
        Toggle(isOn: $isDarkMode) {
            HStack(spacing: isDarkMode ? 12 : 8) {
                Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                    .foregroundStyle(.purple)
                Text(isDarkMode ? "Dark Mode" : "Light Mode")
            }
        }
        .tint(.purple)
        .accessibilityLabel(isDarkMode ? "Dark mode toggle" : "Light mode toggle")
        .accessibilityValue(isDarkMode ? "On" : "Off")
        .accessibilityHint("Double tap to toggle theme")
    }
    
    // MARK: - Empty Wallets Row
    
    private var emptyWalletsRow: some View {
        HStack {
            Image(systemName: "wallet.pass")
                .foregroundStyle(.secondary)
            Text("No wallets added")
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Add Wallet Button
    
    private var addWalletButton: some View {
        Button {
            viewModel.showAddWallet = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.purple)
                Text("Add Wallet")
            }
        }
        .accessibilityLabel("Add wallet")
        .accessibilityHint("Opens a form to add a new Bitcoin wallet")
    }
    
    // MARK: - About Row
    
    private var aboutRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("StampFolio")
                    .font(.headline)
                Spacer()
                Text("v1.0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text("A portfolio viewer for Bitcoin Stamps")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Link(destination: URL(string: "https://stampchain.io")!) {
                HStack {
                    Text("Powered by Stampchain.io")
                        .font(.caption)
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption2)
                }
                .foregroundStyle(.purple)
            }
            .accessibilityLabel("Visit Stampchain.io")
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Actions
    
    private func deleteWallet(_ wallet: Wallet) {
        viewModel.deleteWallet(wallet, context: modelContext)
    }
}

// MARK: - Wallet Row

struct WalletRow: View {
    let wallet: Wallet
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(wallet.displayName)
                    .font(.body)
                
                Spacer()
                
                Text(wallet.addressType.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.purple)
            }
            
            Text(wallet.address.truncatedAddress(prefixLength: 8, suffixLength: 8))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Wallet \(wallet.displayName)")
        .accessibilityValue("\(wallet.cachedStampCount ?? 0) stamps")
    }
}

// MARK: - Edit Wallet View

/// View for editing a wallet's name/label
struct EditWalletView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let wallet: Wallet
    
    // MARK: - State
    
    @State private var walletName: String = ""
    @FocusState private var isNameFocused: Bool
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Wallet Name (Optional)", text: $walletName)
                        .textInputAutocapitalization(.words)
                        .focused($isNameFocused)
                        .accessibilityLabel("Wallet name")
                        .accessibilityHint("Enter a custom name for this wallet")
                } header: {
                    Text("Wallet Name")
                } footer: {
                    Text("Give this wallet a custom name to easily identify it. Leave empty to use the truncated address.")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Address")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(wallet.address)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    
                    HStack {
                        Text("Type")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text(wallet.addressType.rawValue)
                            .font(.caption)
                            .foregroundStyle(.purple)
                    }
                } header: {
                    Text("Wallet Details")
                }
            }
            .navigationTitle("Edit Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveWalletName()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                walletName = wallet.label ?? ""
                isNameFocused = true
            }
        }
    }
    
    // MARK: - Actions
    
    private func saveWalletName() {
        // Update wallet label (empty string becomes nil)
        wallet.label = walletName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : walletName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            // Handle error silently for now
            print("Failed to save wallet name: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(SettingsViewModel())
        .modelContainer(for: Wallet.self, inMemory: true)
}
