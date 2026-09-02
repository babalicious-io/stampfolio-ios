//
//  SearchView.swift
//  StampFolio
//
//  Dedicated search view for filtering stamps
//

import SwiftUI
import SwiftData

/// Full-screen search view for stamps
struct SearchView: View {
    
    // MARK: - Environment
    
    @Environment(StampViewModel.self) private var viewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.appColorScheme) private var appColorScheme
    @Query(sort: \WalletConfig.addedDate, order: .reverse) private var wallets: [WalletConfig]
    
    // MARK: - State
    
    @FocusState private var isSearchFieldFocused: Bool
    @AppStorage("showWalletIcons") private var showWalletIcons = false
    @State private var fullscreenAsset: StampDisplay?
    @State private var detailAsset: StampDisplay?
    
    // MARK: - Body
    
    var body: some View {
        @Bindable var viewModel = viewModel
        
        NavigationStack {
            Group {
                if viewModel.searchText.isEmpty && !viewModel.hasActiveFilters {
                    searchEmptyState
                } else if viewModel.filteredAssets.isEmpty {
                    noResultsView
                } else {
                    searchResults
                }
            }
            .tint(appColorScheme.primary)
        }
        .searchable(text: $viewModel.searchText, prompt: "Search")
        .fullScreenCover(item: $fullscreenAsset) { displayAsset in
            if let index = viewModel.filteredAssets.firstIndex(where: { $0.id == displayAsset.id }) {
                StampAssetFullscreenView(
                    assets: viewModel.filteredAssets.map(\.asset),
                    initialIndex: index
                )
            }
        }
        .sheet(item: $detailAsset) { displayAsset in
            StampAssetDetailView(displayAsset: displayAsset, viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
    }
    
    // MARK: - Search Empty State
    
    private var searchEmptyState: some View {
        ContentUnavailableView {
            Label {
                Text("Search")
                    .foregroundStyle(appColorScheme.primary)
            } icon: {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(appColorScheme.secondary)
            }
        } description: {
            Text("Search by stamp or ordinals number, CPID, txHash, creator or genesis addy, or artist name.")
        }
    }
    
    // MARK: - No Results
    
    private var noResultsView: some View {
        ContentUnavailableView {
            Label {
                Text("No Results")
                    .foregroundStyle(appColorScheme.primary)
            } icon: {
                Image(systemName: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle" : "magnifyingglass")
                    .foregroundStyle(appColorScheme.secondary)
            }
        } description: {
            if !viewModel.searchText.isEmpty && viewModel.hasActiveFilters {
                Text("No stamps match '\(viewModel.searchText)' with the active filters")
            } else if !viewModel.searchText.isEmpty {
                Text("No stamps match '\(viewModel.searchText)'")
            } else if viewModel.hasActiveFilters {
                Text("No stamps match the active filters")
            }
        }
    }
    
    // MARK: - Search Results
    
    private var searchResults: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredAssets) { displayAsset in
                    StampAssetRowView(
                        displayAsset: displayAsset,
                        onTap: {
                            detailAsset = displayAsset
                        },
                        onLongPress: {
                            fullscreenAsset = displayAsset
                        }
                    )
                }
            }
            .padding()
        }
    }
    
}

// MARK: - Preview

#Preview {
    SearchView()
        .environment(StampViewModel())
        .modelContainer(for: WalletConfig.self, inMemory: true)
}
