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
        HStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.body)
            
            TextField("Search stamps...", text: Binding(
                get: { viewModel.searchText },
                set: { viewModel.searchText = $0 }
            ))
            .textFieldStyle(.plain)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .focused($isSearchFieldFocused)
            
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .frame(width: 300, height: 44)
        .fixedSize(horizontal: false, vertical: true)
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
