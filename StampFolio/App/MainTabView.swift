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
                    Label("Collection", systemImage: "photo.stack")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
            
            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
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
