//
//  StampFolioApp.swift
//  StampFolio
//
//  Created with Cursor AI
//

import SwiftUI
import SwiftData
import Kingfisher

/// Main entry point for the StampFolio application.
/// A portfolio viewer for Bitcoin Stamps on iPad and iPhone.
@main
struct StampFolioApp: App {
    
    // MARK: - State
    
    /// App-level Observable objects declared here to avoid re-initialization
    /// when SwiftUI rebuilds view hierarchy (@Observable best practice)
    @State private var settingsViewModel = SettingsViewModel()
    @State private var collectionViewModel = CollectionViewModel()
    @State private var networkMonitor = NetworkMonitor()
    
    /// Theme preference stored in UserDefaults
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    /// Color scheme preference stored in UserDefaults
    @AppStorage("colorScheme") private var colorSchemeRawValue = AppColorScheme.satoshiOrange.rawValue
    
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
            let colorScheme = AppColorScheme(rawValue: colorSchemeRawValue) ?? .satoshiOrange
            
            ContentView()
                .environment(settingsViewModel)
                .environment(collectionViewModel)
                .environment(networkMonitor)
                .environment(\.appColorScheme, colorScheme)
                .preferredColorScheme(isDarkMode ? .dark : .light)
                .onAppear {
                    networkMonitor.start()
                    
                    // Cap Kingfisher memory cache at 100 MB (disk cache unlimited)
                    ImageCache.default.memoryStorage.config.totalCostLimit = 100 * 1024 * 1024
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
