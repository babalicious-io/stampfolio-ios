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
    
    // MARK: - Initialization
    
    init() {
        // Force traditional bottom tab bar on iPad instead of top segmented control.
        // Restores icon + text layout with Liquid Glass on iPadOS 26.
        // Ref: https://bendodson.com/weblog/2026/01/22/traditional-tab-bar-on-ipados-26/
        UserDefaults.standard.register(defaults: ["UseFloatingTabBar": false])
    }
    
    // MARK: - State
    
    /// App-level Observable objects declared here to avoid re-initialization
    /// when SwiftUI rebuilds view hierarchy (@Observable best practice)
    @State private var settingsViewModel = SettingsViewModel()
    @State private var stampViewModel = StampViewModel()
    @State private var counterpartyViewModel = CounterpartyViewModel()
    @State private var networkMonitor = NetworkMonitor()
    
    /// Theme preference stored in UserDefaults
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    /// Color scheme preference stored in UserDefaults
    @AppStorage("colorScheme") private var colorSchemeRawValue = AppColorScheme.satoshiOrange.rawValue
    
    /// Scene phase for monitoring app lifecycle
    @Environment(\.scenePhase) private var scenePhase
    
    // MARK: - SwiftData
    
    /// Model container for SwiftData persistence
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WalletConfig.self
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
                .environment(stampViewModel)
                .environment(counterpartyViewModel)
                .environment(networkMonitor)
                .environment(\.appColorScheme, colorScheme)
                .preferredColorScheme(isDarkMode ? .dark : .light)
                .onAppear {
                    networkMonitor.start()
                    
                    // Cap Kingfisher memory cache at 100 MB (disk cache unlimited)
                    ImageCache.default.memoryStorage.config.totalCostLimit = 100 * 1024 * 1024
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    // Clear market data cache when app enters background or terminates
                    // Ensures fresh data on next app launch
                    if newPhase == .background || newPhase == .inactive {
                        Task { @MainActor in
                            stampViewModel.clearMarketDataCache()
                            counterpartyViewModel.clearMarketDataCache()
                        }
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
