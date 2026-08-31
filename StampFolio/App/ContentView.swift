//
//  ContentView.swift
//  StampFolio
//
//  Created with Cursor AI
//

import SwiftUI

/// Main content view displaying the tab view.
struct ContentView: View {

    // MARK: - State

    @State private var showSplash = true

    // MARK: - Body

    var body: some View {
        ZStack {
            MainTabView()

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation(.easeIn(duration: 0.4)) {
                                showSplash = false
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environment(SettingsViewModel())
        .environment(CollectionViewModel())
        .environment(CounterpartyViewModel())
        .environment(NetworkMonitor())
        .modelContainer(for: WalletConfig.self, inMemory: true)
}
