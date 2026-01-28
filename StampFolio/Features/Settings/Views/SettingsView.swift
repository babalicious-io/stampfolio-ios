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
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Wallet.addedDate, order: .reverse) private var wallets: [Wallet]
    
    // MARK: - State
    
    @AppStorage("isDarkMode") private var isDarkMode = true
    
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
                        }
                        .onDelete(perform: deleteWallets)
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
            .sheet(isPresented: $viewModel.showAddWallet) {
                AddWalletView()
            }
            .alert("Notice", isPresented: $viewModel.showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                if let message = viewModel.alertMessage {
                    Text(message)
                }
            }
        }
    }
    
    // MARK: - Theme Toggle
    
    private var themeToggle: some View {
        Toggle(isOn: $isDarkMode) {
            HStack {
                Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                    .foregroundStyle(Color.brandLight)
                Text("Dark Mode")
            }
        }
        .tint(Color.brand)
        .accessibilityLabel("Dark mode toggle")
        .accessibilityValue(isDarkMode ? "On" : "Off")
        .accessibilityHint("Double tap to toggle dark mode")
    }
    
    // MARK: - Empty Wallets Row
    
    private var emptyWalletsRow: some View {
        HStack {
            Image(systemName: "wallet.pass")
                .foregroundStyle(Color.secondaryText(for: colorScheme))
            Text("No wallets added")
                .foregroundStyle(Color.secondaryText(for: colorScheme))
        }
    }
    
    // MARK: - Add Wallet Button
    
    private var addWalletButton: some View {
        Button {
            viewModel.showAddWallet = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Color.brand)
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
                    .foregroundStyle(Color.secondaryText(for: colorScheme))
            }
            
            Text("A portfolio viewer for Bitcoin Stamps")
                .font(.caption)
                .foregroundStyle(Color.secondaryText(for: colorScheme))
            
            Link(destination: URL(string: "https://stampchain.io")!) {
                HStack {
                    Text("Powered by Stampchain.io")
                        .font(.caption)
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption2)
                }
                .foregroundStyle(Color.brand)
            }
            .accessibilityLabel("Visit Stampchain.io")
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Actions
    
    private func deleteWallets(at offsets: IndexSet) {
        for index in offsets {
            viewModel.deleteWallet(wallets[index], context: modelContext)
        }
    }
}

// MARK: - Wallet Row

struct WalletRow: View {
    let wallet: Wallet
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(wallet.displayName)
                    .font(.body)
                
                Spacer()
                
                if let count = wallet.cachedStampCount {
                    Text("\(count) stamps")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText(for: colorScheme))
                }
            }
            
            Text(wallet.address)
                .font(.monospace)
                .foregroundStyle(Color.secondaryText(for: colorScheme))
                .lineLimit(1)
                .truncationMode(.middle)
            
            HStack {
                Text(wallet.addressType.rawValue)
                    .font(.caption2)
                    .foregroundStyle(Color.brand)
                
                Spacer()
                
                Text("Added \(wallet.addedDate, format: .relative(presentation: .named))")
                    .font(.caption2)
                    .foregroundStyle(Color.secondaryText(for: colorScheme))
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
