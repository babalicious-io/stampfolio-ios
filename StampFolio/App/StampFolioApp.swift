//
//  StampFolioApp.swift
//  StampFolio
//
//  Created with Cursor AI
//

import SwiftUI
import SwiftData

/// Main entry point for the StampFolio application.
/// A portfolio viewer for Bitcoin Stamps on iPad and iPhone.
@main
struct StampFolioApp: App {
    
    // MARK: - State
    
    /// App-level Observable objects declared here to avoid re-initialization
    /// when SwiftUI rebuilds view hierarchy (iOS 17 @Observable best practice)
    @State private var settingsViewModel = SettingsViewModel()
    @State private var collectionViewModel = CollectionViewModel()
    @State private var networkMonitor = NetworkMonitor()
    
    /// Theme preference stored in UserDefaults
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    // MARK: - SwiftData
    
    /// Model container for SwiftData persistence
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Wallet.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settingsViewModel)
                .environment(collectionViewModel)
                .environment(networkMonitor)
                .preferredColorScheme(isDarkMode ? .dark : .light)
                .onAppear {
                    networkMonitor.start()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
