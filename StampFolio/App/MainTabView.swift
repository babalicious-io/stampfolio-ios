//
//  MainTabView.swift
//  StampFolio
//
//  Main tab view container with pinned search
//

import SwiftUI

// MARK: - Environment Keys

private struct ShowSettingsKey: EnvironmentKey {
    static let defaultValue = Binding<Bool>.constant(false)
}

private struct ShowSearchKey: EnvironmentKey {
    static let defaultValue = Binding<Bool>.constant(false)
}

extension EnvironmentValues {
    var showSettingsBinding: Binding<Bool> {
        get { self[ShowSettingsKey.self] }
        set { self[ShowSettingsKey.self] = newValue }
    }
    
    var showSearchBinding: Binding<Bool> {
        get { self[ShowSearchKey.self] }
        set { self[ShowSearchKey.self] = newValue }
    }
}

// MARK: - Main Tab View

/// Main tab view with adaptive search (tab on iPhone, toolbar on iPad)
struct MainTabView: View {
    
    // MARK: - Environment
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // MARK: - State
    
    @State private var showSettings = false
    @State private var showSearch = false
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                // iPhone: Search as tab
                compactTabView
            } else {
                // iPad: Search as toolbar button
                regularTabView
            }
        }
        .environment(\.showSettingsBinding, $showSettings)
        .environment(\.showSearchBinding, $showSearch)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showSearch) {
            SearchView()
        }
    }
    
    // MARK: - Compact Layout (iPhone)
    
    private var compactTabView: some View {
        TabView {
            Tab("Stamps", systemImage: "bitcoinsign.square.fill") {
                CollectionView()
            }
            
            Tab("Ordinals", systemImage: "circle.hexagongrid.fill") {
                OrdinalsView()
            }
            
            Tab("Counterparty", systemImage: "square.3.layers.3d") {
                CounterpartyView()
            }
            
            Tab("Search", systemImage: "magnifyingglass") {
                SearchView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
    
    // MARK: - Regular Layout (iPad)
    
    private var regularTabView: some View {
        TabView {
            Tab("Stamps", systemImage: "bitcoinsign.square.fill") {
                CollectionView()
            }
            
            Tab("Ordinals", systemImage: "circle.hexagongrid.fill") {
                OrdinalsView()
            }
            
            Tab("Counterparty", systemImage: "square.3.layers.3d") {
                CounterpartyView()
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
