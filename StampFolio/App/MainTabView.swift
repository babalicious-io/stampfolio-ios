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
    @State private var protocolOrder: [ProtocolType] = []
    
    // MARK: - Body
    
    var body: some View {
        TabView {
            ForEach(protocolOrder) { protocolType in
                if shouldShowProtocol(protocolType) {
                    protocolTab(for: protocolType)
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
        .onAppear {
            loadProtocolOrder()
        }
    }
    
    // MARK: - Helper Methods
    
    @ViewBuilder
    private func protocolTab(for protocolType: ProtocolType) -> some View {
        switch protocolType {
        case .stamps:
            Tab("Stamps", systemImage: protocolType.icon) {
                CollectionView()
            }
        case .ordinals:
            Tab("Ordinals", systemImage: protocolType.icon) {
                OrdinalsView()
            }
        case .counterparty:
            Tab("Counterparty", systemImage: protocolType.icon) {
                CounterpartyView()
            }
        }
    }
    
    private func shouldShowProtocol(_ protocolType: ProtocolType) -> Bool {
        switch protocolType {
        case .stamps: return showStamps
        case .ordinals: return showOrdinals
        case .counterparty: return showCounterparty
        }
    }
    
    private func loadProtocolOrder() {
        if let data = UserDefaults.standard.data(forKey: "protocolOrder"),
           let decoded = try? JSONDecoder().decode([ProtocolType].self, from: data) {
            protocolOrder = decoded
        } else {
            // Default order
            protocolOrder = [.stamps, .ordinals, .counterparty]
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
