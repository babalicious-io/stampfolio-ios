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
            .navigationTitle("Search")
            .toolbar {
                filterToolbarItem
            }
        }
        .searchable(text: Binding(
            get: { viewModel.searchText },
            set: { viewModel.searchText = $0 }
        ), prompt: "Search stamps...")
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
            Label("Search Stamps", systemImage: "magnifyingglass")
        } description: {
            Text("Search by stamp number, artist, or title")
        }
    }
    
    // MARK: - No Results
    
    private var noResultsView: some View {
        ContentUnavailableView {
            Label("No Results", systemImage: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle" : "magnifyingglass")
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
    
    // MARK: - Toolbar Items
    
    private var filterToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Section("STAMP TYPE") {
                    Toggle("Classic", isOn: Binding(
                        get: { viewModel.activeIdentFilters.contains("STAMP") },
                        set: { _ in viewModel.toggleIdentFilter("STAMP") }
                    ))
                    
                    Toggle("Posh", isOn: Binding(
                        get: { viewModel.activeIdentFilters.contains("POSH") },
                        set: { _ in viewModel.toggleIdentFilter("POSH") }
                    ))
                }
                
                Section("FILE TYPE") {
                    Toggle("Pixel", isOn: Binding(
                        get: { viewModel.activeFileFormatFilters.contains("pixel") },
                        set: { _ in viewModel.toggleFileFormatFilter("pixel") }
                    ))
                    
                    Toggle("Vector", isOn: Binding(
                        get: { viewModel.activeFileFormatFilters.contains("vector") },
                        set: { _ in viewModel.toggleFileFormatFilter("vector") }
                    ))
                }
                
                Section("EDITIONS") {
                    Toggle("Single", isOn: Binding(
                        get: { viewModel.activeEditionFilters.contains("single") },
                        set: { _ in viewModel.toggleEditionFilter("single") }
                    ))
                    
                    Toggle("Multiple", isOn: Binding(
                        get: { viewModel.activeEditionFilters.contains("multiple") },
                        set: { _ in viewModel.toggleEditionFilter("multiple") }
                    ))
                }
                
                if showWalletIcons {
                    Section("WALLET") {
                        // Future: Add wallet-specific filters
                    }
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18))
                    .foregroundStyle(viewModel.hasActiveFilters ? Color.purple : Color.primary)
            }
            .accessibilityLabel("Filter stamps")
            .accessibilityHint("Filter stamps by type, format, or edition count")
        }
    }
}

// MARK: - Bindable Extension for Optional Binding

extension Bindable where Value: AnyObject {
    subscript<T>(dynamicMember keyPath: ReferenceWritableKeyPath<Value, T?>) -> Binding<T?> {
        Binding(
            get: { self.wrappedValue[keyPath: keyPath] },
            set: { self.wrappedValue[keyPath: keyPath] = $0 }
        )
    }
}

// MARK: - Preview

#Preview {
    SearchView()
        .environment(CollectionViewModel())
        .modelContainer(for: Wallet.self, inMemory: true)
}
