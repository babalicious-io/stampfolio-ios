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
    
    @Environment(\.showSettings) private var showSettings
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Counterparty")
                    .font(.title2)
            }
            .navigationTitle("Counterparty")
            .toolbar {
                settingsToolbarItem
            }
        }
    }
    
    // MARK: - Toolbar Items
    
    private var settingsToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showSettings()
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
