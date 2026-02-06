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
    @AppStorage("TabViewCustomization") private var customization: TabViewCustomization
    
    // MARK: - Body
    
    var body: some View {
        TabView {
            TabSection("Protocols") {
                ForEach(ProtocolType.allCases) { protocolType in
                    Tab(protocolType.rawValue, systemImage: protocolType.icon) {
                        viewForProtocol(protocolType)
                    }
                    .customizationID("Tab.\(protocolType.rawValue)")
                }
            }
            .customizationID("Tab.protocols")
            
            Tab(role: .search) {
                SearchView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewCustomization($customization)
        .tabBarMinimizeBehavior(.onScrollDown)
        .environment(\.showSettingsBinding, $showSettings)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
    
    // MARK: - Helper Methods
    
    @ViewBuilder
    private func viewForProtocol(_ protocolType: ProtocolType) -> some View {
        switch protocolType {
        case .stamps:
            CollectionView()
        case .ordinals:
            OrdinalsView()
        case .counterparty:
            CounterpartyView()
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
