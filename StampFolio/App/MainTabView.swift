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
    
    /// Capture the real horizontal size class before overriding it on TabView.
    /// This lets us restore it on content views so grid columns etc. still use .regular on iPad.
    @Environment(\.horizontalSizeClass) private var actualSizeClass
    
    // MARK: - Body
    
    var body: some View {
        TabView {
            orderedProtocolTabs
            
            Tab(role: .search) {
                SearchView()
                    .environment(\.horizontalSizeClass, actualSizeClass)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        // Force compact size class on TabView → stacked layout (icon above text) for tab bar.
        // Combined with UseFloatingTabBar: false (in StampFolioApp.init), this gives
        // the full-width bottom tab bar with stacked icons matching iPhone layout.
        .environment(\.horizontalSizeClass, .compact)
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
            Tab(protocolType.rawValue, systemImage: protocolType.icon) {
                viewForProtocol(protocolType)
            }
        }
    }
    
    @ViewBuilder
    private func viewForProtocol(_ protocolType: ProtocolType) -> some View {
        switch protocolType {
        case .stamps:
            CollectionView()
                .environment(\.horizontalSizeClass, actualSizeClass)
        case .ordinals:
            OrdinalsView()
                .environment(\.horizontalSizeClass, actualSizeClass)
        case .counterparty:
            CounterpartyView()
                .environment(\.horizontalSizeClass, actualSizeClass)
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
