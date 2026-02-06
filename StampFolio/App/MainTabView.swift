//
//  MainTabView.swift
//  StampFolio
//
//  Main tab view container for Collection and Settings
//

import SwiftUI

/// Main tab view with Collection and Settings tabs
struct MainTabView: View {
    
    // MARK: - Body
    
    var body: some View {
        TabView {
            CollectionView()
                .tabItem {
                    Label("Stamps", systemImage: "bitcoinsign.square.fill")
                }
            
            OrdinalsView()
                .tabItem {
                    Label("Ordinals", systemImage: "circle.hexagongrid.fill")
                }
            
            CounterpartyView()
                .tabItem {
                    Label("Counterparty", systemImage: "square.3.layers.3d")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
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
