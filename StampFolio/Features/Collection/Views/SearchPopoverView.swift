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
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @FocusState private var isSearchFieldFocused: Bool
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("Search")
                .font(.headline)
                .foregroundStyle(.primary)
            
            // Search field
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search...", text: Binding(
                    get: { viewModel.searchText },
                    set: { viewModel.searchText = $0 }
                ))
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isSearchFieldFocused)
                .onSubmit {
                    if !viewModel.searchText.isEmpty {
                        dismiss()
                    }
                }
                
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(12)
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
            
            // Search hints
            VStack(alignment: .leading, spacing: 8) {
                Text("Search by:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                searchHintItem(icon: "number", text: "Stamp #")
                searchHintItem(icon: "barcode", text: "CPID")
                searchHintItem(icon: "link", text: "Transaction Hash")
                searchHintItem(icon: "person.fill", text: "Creator Address/Name")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Action buttons
            HStack(spacing: 12) {
                if !viewModel.searchText.isEmpty {
                    Button("Search") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                }
                
                Button(viewModel.searchText.isEmpty ? "Cancel" : "Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(width: 320)
        .onAppear {
            isSearchFieldFocused = true
        }
    }
    
    // MARK: - Search Hint Item
    
    private func searchHintItem(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.purple)
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    SearchPopoverView()
        .environment(CollectionViewModel())
}
