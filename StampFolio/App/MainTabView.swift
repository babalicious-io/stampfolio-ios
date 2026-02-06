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

/// Main tab view with collection tabs and adaptive search
struct MainTabView: View {
    
    // MARK: - Environment
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // MARK: - State
    
    @State private var showSettings = false
    @State private var showSearch = false
    
    // MARK: - Body
    
    var body: some View {
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
            
            // Show search tab only on iPhone (compact size class)
            if horizontalSizeClass == .compact {
                Tab(role: .search) {
                    SearchView()
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .environment(\.showSettingsBinding, $showSettings)
        .environment(\.showSearchBinding, $showSearch)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .fullScreenCover(isPresented: $showSearch) {
            NavigationStack {
                SearchView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                showSearch = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityLabel("Close")
                        }
                    }
            }
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
