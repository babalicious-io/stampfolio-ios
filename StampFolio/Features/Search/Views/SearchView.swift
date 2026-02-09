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
    
    @Environment(CollectionViewModel.self) private var viewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.appColorScheme) private var appColorScheme
    @Query(sort: \Wallet.addedDate, order: .reverse) private var wallets: [Wallet]
    
    // MARK: - State
    
    @FocusState private var isSearchFieldFocused: Bool
    @AppStorage("showWalletIcons") private var showWalletIcons = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.searchText.isEmpty && !viewModel.hasActiveFilters {
                    searchEmptyState
                } else if viewModel.filteredStamps.isEmpty {
                    noResultsView
                } else {
                    searchResults
                }
            }
            .tint(appColorScheme.primary)
        }
        .searchable(text: Binding(
            get: { viewModel.searchText },
            set: { viewModel.searchText = $0 }
        ), prompt: "Search")
        .fullScreenCover(item: Bindable(viewModel).selectedStamp) { displayStamp in
            if let index = viewModel.stamps.firstIndex(where: { $0.id == displayStamp.id }) {
                StampDetailView(
                    stamps: viewModel.stamps.map(\.stamp),
                    initialIndex: index
                )
            }
        }
        .sheet(item: Bindable(viewModel).metadataStamp) { displayStamp in
            StampMetadataPopup(stamp: displayStamp.stamp)
                .presentationDetents([.medium])
                .presentationBackground(.ultraThinMaterial)
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
                ForEach(viewModel.filteredStamps) { displayStamp in
                    StampRowView(
                        displayStamp: displayStamp,
                        onTap: {
                            viewModel.selectedStamp = displayStamp
                        },
                        onInfoTap: {
                            viewModel.metadataStamp = displayStamp
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
        .environment(CollectionViewModel())
        .modelContainer(for: Wallet.self, inMemory: true)
}
