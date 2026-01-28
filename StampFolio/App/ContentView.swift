//
//  ContentView.swift
//  StampFolio
//
//  Created with Cursor AI
//

import SwiftUI

/// Main content view with tab navigation.
/// Displays Collections and Settings tabs.
struct ContentView: View {
    
    // MARK: - State
    
    @State private var selectedTab: Tab = .collection
    
    // MARK: - Types
    
    enum Tab: Hashable {
        case collection
        case settings
    }
    
    // MARK: - Body
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CollectionView()
                .tabItem {
                    Label("Collection", systemImage: "square.grid.2x2")
                }
                .tag(Tab.collection)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(Tab.settings)
        }
        .tint(.purple)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environment(SettingsViewModel())
        .environment(CollectionViewModel())
        .environment(NetworkMonitor())
}
