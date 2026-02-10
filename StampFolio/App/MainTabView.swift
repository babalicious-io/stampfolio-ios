//
//  MainTabView.swift
//  StampFolio
//
//  Main tab view container with pinned search
//

import SwiftUI
import UIKit
import Combine

// MARK: - Tab Bar Stacked Layout

/// Forces UITabBar to use stacked layout (icon above text) on iPad
/// by setting compact horizontal size class on the UITabBar view only.
/// This does NOT propagate to content views — only affects tab bar rendering.
/// Uses iOS 17+ `traitOverrides` API (WWDC23: "Unleash the UIKit trait system").
private struct TabBarStackedLayout: UIViewRepresentable {
    
    func makeUIView(context: Context) -> UIView {
        let finder = TabBarFinderView()
        finder.isHidden = true
        finder.isUserInteractionEnabled = false
        return finder
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    /// UIView subclass that walks the responder chain to find the UITabBar
    /// once inserted into the view hierarchy.
    private class TabBarFinderView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            
            // Walk responder chain to find UITabBarController
            var responder: UIResponder? = self
            while let next = responder?.next {
                if let tabBarController = next as? UITabBarController {
                    // Set compact size class on UITabBar view only (not content views).
                    // Forces stacked layout (icon above text) matching iPhone.
                    tabBarController.tabBar.traitOverrides.horizontalSizeClass = .compact
                    break
                }
                responder = next
            }
        }
    }
}

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
        .background(TabBarStackedLayout())
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
