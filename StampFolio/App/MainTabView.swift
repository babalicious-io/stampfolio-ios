//
//  MainTabView.swift
//  StampFolio
//
//  Main tab view container with pinned search
//

import SwiftUI
import Combine

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
    @Environment(\.appColorScheme) private var appColorScheme
    
    // MARK: - Body
    
    var body: some View {
        TabView {
            orderedProtocolTabs
            
            Tab(role: .search) {
                SearchView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(appColorScheme.primary)
        .environment(\.showSettingsBinding, $showSettings)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            loadProtocolOrder()
        }
        .onChange(of: showStamps) { _, _ in loadProtocolOrder() }
        .onChange(of: showOrdinals) { _, _ in loadProtocolOrder() }
        .onChange(of: showCounterparty) { _, _ in loadProtocolOrder() }
        .onReceive(NotificationCenter.default.publisher(for: .protocolOrderDidChange)) { _ in
            loadProtocolOrder()
        }
    }
    
    // MARK: - Helper Methods
    
    /// Build tabs in user-defined order, showing only enabled protocols
    @TabContentBuilder<Never>
    private var orderedProtocolTabs: some TabContent<Never> {
        ForEach(protocolOrder.filter { shouldShowProtocol($0) }) { protocolType in
            Tab {
                viewForProtocol(protocolType)
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: protocolType.icon)
                        .font(.system(size: 20))
                    Text(protocolType.rawValue)
                }
            }
        }
    }
    
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
