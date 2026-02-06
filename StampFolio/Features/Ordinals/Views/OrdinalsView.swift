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
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.showSettingsBinding) private var showSettings
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Ordinals")
                    .font(.title2)
            }
            .navigationTitle("Ordinals")
            .toolbar {
                // Show search button only on iPad (regular)
                if horizontalSizeClass == .regular {
                    searchToolbarItem
                }
                
                settingsToolbarItem
            }
        }
    }
    
    // MARK: - Toolbar Items
    
    private var searchToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink(destination: SearchView()) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
            }
            .accessibilityLabel("Search")
            .accessibilityHint("Search stamps")
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
