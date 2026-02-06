//
//  MainTabView.swift
//  StampFolio
//
//  Main tab view container with pinned search
//

import SwiftUI

// MARK: - Environment Key

private struct ShowSettingsKey: EnvironmentKey {
    static let defaultValue = Binding<Bool>.constant(false)
}

extension EnvironmentValues {
    var showSettingsBinding: Binding<Bool> {
        get { self[ShowSettingsKey.self] }
        set { self[ShowSettingsKey.self] = newValue }
    }
}

// MARK: - Main Tab View

/// Main tab view with collection tabs and pinned search
struct MainTabView: View {
    
    // MARK: - State
    
    @State private var showSettings = false
    @AppStorage("showOrdinals") private var showOrdinals = true
    @AppStorage("showCounterparty") private var showCounterparty = true
    @AppStorage("showStamps") private var showStamps = true
    
    // MARK: - Body
    
    var body: some View {
        TabView {
            if showStamps {
                Tab("Stamps", systemImage: "bitcoinsign.square.fill") {
                    CollectionView()
                }
            }
            
            if showOrdinals {
                Tab("Ordinals", systemImage: "circle.hexagongrid.fill") {
                    OrdinalsView()
                }
            }
            
            if showCounterparty {
                Tab("Counterparty", systemImage: "square.3.layers.3d") {
                    CounterpartyView()
                }
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
