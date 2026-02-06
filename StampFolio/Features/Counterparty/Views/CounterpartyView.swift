//
//  CounterpartyView.swift
//  StampFolio
//
//  Counterparty collection view
//

import SwiftUI
import SwiftData

/// View for displaying Counterparty assets
struct CounterpartyView: View {
    
    // MARK: - Environment
    
    @Environment(\.showSettingsBinding) private var showSettings
    @Query(sort: \Wallet.addedDate, order: .reverse) private var wallets: [Wallet]
    
    // MARK: - State
    
    @State private var showAddWallet = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Counterparty")
                    .font(.title2)
            }
            .emptyWalletOverlay(walletCount: wallets.count, showAddWallet: $showAddWallet)
            .navigationTitle("Counterparty")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                settingsToolbarItem
            }
        }
        .sheet(isPresented: $showAddWallet) {
            AddWalletView()
                .environment(SettingsViewModel())
        }
    }
    
    // MARK: - Toolbar Items
    
    private var settingsToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showSettings.wrappedValue = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Settings")
            .accessibilityHint("Open app settings")
        }
    }
}

// MARK: - Preview

#Preview {
    CounterpartyView()
        .modelContainer(for: Wallet.self, inMemory: true)
}
