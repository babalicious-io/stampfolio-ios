//
//  OrdinalsView.swift
//  StampFolio
//
//  Ordinals collection view
//

import SwiftUI
import SwiftData

/// View for displaying Ordinals
struct OrdinalsView: View {
    
    // MARK: - Environment
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.showSettingsBinding) private var showSettings
    @Environment(\.showSearchBinding) private var showSearch
    @Query(sort: [SortDescriptor(\Wallet.addedDate, order: .reverse)]) private var wallets: [Wallet]
    
    // MARK: - State
    
    @State private var showAddWallet = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Ordinals")
                    .font(.title2)
            }
            .emptyWalletOverlay(walletCount: wallets.count, showAddWallet: $showAddWallet)
            .navigationTitle("Ordinals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Show search button only on iPad (regular)
                if horizontalSizeClass == .regular {
                    searchToolbarItem
                }
                
                settingsToolbarItem
            }
        }
        .sheet(isPresented: $showAddWallet) {
            AddWalletView()
        }
    }
    
    // MARK: - Toolbar Items
    
    private var searchToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showSearch.wrappedValue = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
            }
            .accessibilityLabel("Search")
            .accessibilityHint("Search for ordinals")
        }
    }
    
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
    OrdinalsView()
        .modelContainer(for: Wallet.self, inMemory: true)
}
