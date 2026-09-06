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
    
    @Query(sort: \WalletConfig.addedDate, order: .reverse) private var wallets: [WalletConfig]
    
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
                SettingsToolbarItem()
            }
        }
        .sheet(isPresented: $showAddWallet) {
            AddWalletView()
                .environment(SettingsViewModel())
        }
    }
}

// MARK: - Preview

#Preview {
    OrdinalsView()
        .environment(StampViewModel())
        .environment(CounterpartyViewModel())
        .environment(AssetDownloadCoordinator())
        .modelContainer(for: WalletConfig.self, inMemory: true)
}
