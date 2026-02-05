//
//  SearchPopoverView.swift
//  StampFolio
//
//  Compact search popover for filtering stamps
//

import SwiftUI

/// Compact search popover view
struct SearchPopoverView: View {
    
    // MARK: - Environment
    
    @Environment(CollectionViewModel.self) private var viewModel
    
    // MARK: - State
    
    @FocusState private var isSearchFieldFocused: Bool
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.callout)
            
            TextField("Search stamps...", text: Binding(
                get: { viewModel.searchText },
                set: { viewModel.searchText = $0 }
            ))
            .textFieldStyle(.plain)
            .font(.callout)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .focused($isSearchFieldFocused)
            
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(8)
        .frame(minWidth: 280)
        .onAppear {
            isSearchFieldFocused = true
        }
    }
    
}

// MARK: - Preview

#Preview {
    SearchPopoverView()
        .environment(CollectionViewModel())
}
