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
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Ordinals")
                    .font(.title2)
            }
            .navigationTitle("Ordinals")
            .toolbar {
                settingsToolbarItem
            }
        }
    }
    
    // MARK: - Toolbar Items
    
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
