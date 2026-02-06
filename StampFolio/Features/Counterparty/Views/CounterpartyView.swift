//
//  CounterpartyView.swift
//  StampFolio
//
//  Counterparty collection view
//

import SwiftUI

/// View for displaying Counterparty assets
struct CounterpartyView: View {
    
    // MARK: - Environment
    
    @Environment(\.showSettingsBinding) private var showSettings
    @Environment(\.showSearchBinding) private var showSearch
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Counterparty")
                    .font(.title2)
            }
            .navigationTitle("Counterparty")
            .toolbar {
                searchToolbarItem
                settingsToolbarItem
            }
        }
    }
    
    // MARK: - Toolbar Items
    
    private var searchToolbarItem: some ToolbarContent {
        Group {
            // Only show search button on iPad (regular size class)
            if horizontalSizeClass == .regular {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSearch.wrappedValue = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Search")
                    .accessibilityHint("Search for stamps")
                }
            }
        }
    }
    
    private var settingsToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showSettings.wrappedValue = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
            }
            .accessibilityLabel("Settings")
            .accessibilityHint("Open app settings")
        }
    }
}

// MARK: - Preview

#Preview {
    CounterpartyView()
}
