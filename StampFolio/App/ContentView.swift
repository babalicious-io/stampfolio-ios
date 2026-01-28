//
//  ContentView.swift
//  StampFolio
//
//  Created with Cursor AI
//

import SwiftUI

/// Main content view displaying the collection.
struct ContentView: View {
    
    // MARK: - Body
    
    var body: some View {
        CollectionView()
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environment(SettingsViewModel())
        .environment(CollectionViewModel())
        .environment(NetworkMonitor())
}
