//
//  ContentView.swift
//  StampFolio
//
//  Created with Cursor AI
//

import SwiftUI

/// Main content view displaying the tab view.
struct ContentView: View {
    
    // MARK: - Body
    
    var body: some View {
        MainTabView()
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environment(SettingsViewModel())
        .environment(CollectionViewModel())
        .environment(NetworkMonitor())
        .modelContainer(for: WalletConfig.self, inMemory: true)
}
