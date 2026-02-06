//
//  MainTabView.swift
//  StampFolio
//
//  Main tab view container with pinned search
//

import SwiftUI

/// Main tab view with collection tabs and pinned search
struct MainTabView: View {
    
    // MARK: - State
    
    @State private var showSettings = false
    
    // MARK: - Body
    
    var body: some View {
        TabView {
            Tab("Stamps", systemImage: "bitcoinsign.square.fill") {
                CollectionView()
            }
            
            Tab("Ordinals", systemImage: "circle.hexagongrid.fill") {
                OrdinalsView()
            }
            
            Tab("Counterparty", systemImage: "square.3.layers.3d") {
                CounterpartyView()
            }
            
            Tab(role: .search) {
                SearchView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .environment(\.showSettingsBinding, $showSettings)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .environment(CollectionViewModel())
        .environment(SettingsViewModel())
        .environment(NetworkMonitor())
        .modelContainer(for: Wallet.self, inMemory: true)
}
