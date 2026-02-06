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
            
            Tab(role: .search) {
                SearchView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .environment(\.showSettings, $showSettings)
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
