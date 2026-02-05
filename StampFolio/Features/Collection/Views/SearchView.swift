//
//  SearchView.swift
//  StampFolio
//
//  Search interface for filtering stamps by stamp #, CPID, txHash, or creator
//

import SwiftUI
import SwiftData

/// Search view for filtering stamps
struct SearchView: View {
    
    // MARK: - Environment
    
    @Environment(CollectionViewModel.self) private var viewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // MARK: - State
    
    @State private var searchText = ""
    @AppStorage("viewMode") private var viewMode: ViewMode = .normalGrid
    @AppStorage("showWalletIcons") private var showWalletIcons = false
    @FocusState private var isSearchFieldFocused: Bool
    
    // MARK: - Layout
    
    /// Dynamic grid columns matching CollectionView
    private var columns: [GridItem] {
        if viewMode == .list {
            return [GridItem(.flexible(), spacing: 16)]
        }
        
        let isIPad = horizontalSizeClass == .regular
        let minSize: CGFloat
        if isIPad {
            minSize = viewMode == .denseGrid ? 130 : 180
        } else {
            minSize = viewMode == .denseGrid ? 110 : 170
        }
        
        return [GridItem(.adaptive(minimum: minSize, maximum: 300), spacing: 16)]
    }
    
    // MARK: - Filtered Results
    
    private var filteredStamps: [DisplayStamp] {
        guard !searchText.isEmpty else {
            return []
        }
        
        let searchLower = searchText.lowercased()
        
        return viewModel.stamps.filter { displayStamp in
            let stamp = displayStamp.stamp
            
            // Search by stamp ID
            if "\(stamp.id)".contains(searchLower) {
                return true
            }
            
            // Search by CPID
            if stamp.cpid.localizedCaseInsensitiveContains(searchText) {
                return true
            }
            
            // Search by transaction hash
            if stamp.txHash.localizedCaseInsensitiveContains(searchText) {
                return true
            }
            
            // Search by creator address
            if stamp.creatorAddy.localizedCaseInsensitiveContains(searchText) {
                return true
            }
            
            // Search by creator name
            if let creatorName = stamp.creatorName,
               creatorName.localizedCaseInsensitiveContains(searchText) {
                return true
            }
            
            return false
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search field
                searchField
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                
                Divider()
                
                // Results
                searchResults
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                isSearchFieldFocused = true
            }
        }
    }
    
    // MARK: - Search Field
    
    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search by stamp #, CPID, txHash, addy or artist", text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isSearchFieldFocused)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
    
    // MARK: - Search Results
    
    @ViewBuilder
    private var searchResults: some View {
        if searchText.isEmpty {
            searchPlaceholder
        } else if filteredStamps.isEmpty {
            noResultsView
        } else {
            resultsGrid
        }
    }
    
    // MARK: - Search Placeholder
    
    private var searchPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Search your stamps")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Search by:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                searchHintItem(icon: "number", text: "Stamp # (e.g., 1384303)")
                searchHintItem(icon: "barcode", text: "CPID (e.g., A888354...)")
                searchHintItem(icon: "link", text: "Transaction Hash")
                searchHintItem(icon: "person.fill", text: "Creator Address or Name")
            }
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
            .padding(.horizontal)
        }
        .frame(maxHeight: .infinity)
    }
    
    private func searchHintItem(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.purple)
                .frame(width: 20)
            
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - No Results View
    
    private var noResultsView: some View {
        ContentUnavailableView {
            Label("No Results", systemImage: "magnifyingglass")
        } description: {
            Text("No stamps match '\(searchText)'")
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Results Grid
    
    private var resultsGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(filteredStamps.count) result\(filteredStamps.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                if viewMode == .list {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredStamps) { displayStamp in
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
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredStamps) { displayStamp in
                            StampCardView(
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
    }
}

// MARK: - Preview

#Preview {
    SearchView()
        .environment(CollectionViewModel())
}
