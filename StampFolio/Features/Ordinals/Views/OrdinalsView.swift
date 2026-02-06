//
//  OrdinalsView.swift
//  StampFolio
//
//  Ordinals collection view
//

import SwiftUI

/// View for displaying Ordinals
struct OrdinalsView: View {
    
    // MARK: - Environment
    
    @Environment(\.showSettingsBinding) private var showSettings
    @Environment(\.showSearchBinding) private var showSearch
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Ordinals")
                    .font(.title2)
            }
            .navigationTitle("Ordinals")
            .toolbar {
                searchToolbarItem
                settingsToolbarItem
            }
        }
    }
    
    // MARK: - Toolbar Items
    
    private var searchToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showSearch.wrappedValue = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
            }
            .accessibilityLabel("Search")
            .accessibilityHint("Search for stamps")
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
    OrdinalsView()
}
