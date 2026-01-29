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
    @AppStorage("showWalletIcons") private var showWalletIcons = false
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
                                    .tint(.purple)
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
                }
                
                // Wallet Icons Section
                Section {
                    walletIconToggle
                } header: {
                    Text("Wallet Icons")
                } footer: {
                    Text("Show wallet icon with color on stamp cards")
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
            HStack(spacing: isDarkMode ? 14 : 8) {
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
    
    // MARK: - Wallet Icon Toggle
    
    private var walletIconToggle: some View {
        Toggle(isOn: $showWalletIcons) {
            HStack(spacing: 14) {
                Image(systemName: "wallet.bifold.fill")
                    .foregroundStyle(.purple)
                Text("Display Wallet Icon")
            }
        }
        .tint(.purple)
        .accessibilityLabel("Display wallet icon toggle")
        .accessibilityValue(showWalletIcons ? "On" : "Off")
        .accessibilityHint("Double tap to toggle wallet icon display on stamp cards")
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
                        .font(.caption)
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
    
    private var displayName: String {
        let name = wallet.displayName
        if name.count > 24 {
            let prefix = name.prefix(8)
            let suffix = name.suffix(8)
            return "\(prefix)...\(suffix)"
        }
        return name
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "wallet.bifold.fill")
                    .font(.body)
                    .foregroundStyle(wallet.walletColor.color)
                
                Text(displayName)
                    .font(.body)
                
                Spacer()
                
                Text(wallet.addressType.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.purple)
                    .opacity(0.7)
            }
            
            HStack {
                Text(wallet.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                if let count = wallet.cachedStampCount {
                    Text("\(count) stamps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Wallet \(wallet.displayName)")
        .accessibilityValue("\(wallet.cachedStampCount ?? 0) stamps")
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(SettingsViewModel())
        .modelContainer(for: Wallet.self, inMemory: true)
}
