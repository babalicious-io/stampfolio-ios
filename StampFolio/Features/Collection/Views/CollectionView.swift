//
//  CollectionView.swift
//  StampFolio
//
//  Main collection view displaying stamps in a grid
//

import SwiftUI
import SwiftData

/// View mode for displaying stamps
enum ViewMode: String, Codable {
    case normalGrid = "normal_grid"
    case denseGrid = "dense_grid"
    case list = "list"
}

/// Main collection view showing stamps from all wallets
struct CollectionView: View {
    
    // MARK: - Environment
    
    @Environment(CollectionViewModel.self) private var viewModel
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.showSettings) private var showSettings
    @Query(sort: \Wallet.addedDate, order: .reverse) private var wallets: [Wallet]
    
    // MARK: - State
    
    @State private var showOfflineBanner = false
    @State private var viewSize: CGSize = .zero
    @AppStorage("showWalletIcons") private var showWalletIcons = false
    @AppStorage("viewMode") private var viewMode: ViewMode = .normalGrid
    
    // MARK: - Layout
    
    /// Dynamic grid columns using native adaptive sizing with device awareness
    /// iPhone: 2 columns (normal) / 3 columns (dense)
    /// iPad: 3-4 columns (normal) / 4-5 columns (dense)
    private var columns: [GridItem] {
        // List mode uses single flexible column
        if viewMode == .list {
            return [GridItem(.flexible(), spacing: 16)]
        }
        
        // Simple device detection for optimal column counts
        let isIPad = horizontalSizeClass == .regular
        
        // Set minimums that achieve desired column counts while remaining adaptive
        let minSize: CGFloat
        if isIPad {
            minSize = viewMode == .denseGrid ? 130 : 180  // iPad: 4-5 columns dense, 3-4 normal
        } else {
            minSize = viewMode == .denseGrid ? 110 : 170  // iPhone: 3 columns dense, 2 normal
        }
        
        return [GridItem(.adaptive(minimum: minSize, maximum: 300), spacing: 16)]
    }
    
    // MARK: - Computed Properties
    
    /// Check if any sort is active (not the default descending stamp sort)
    private var hasActiveSort: Bool {
        viewModel.currentSortOption != .stampDescending
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            mainContent
                .toolbar {
                    viewModeToolbarItem
                    filterAndSortGroupToolbarItem
                    settingsToolbarItem
                }
        }
        .task {
            await viewModel.fetchStamps(for: wallets)
        }
        .refreshable {
            await viewModel.refreshStamps(for: wallets)
        }
        .onChange(of: wallets.count) { _, _ in
            Task {
                await viewModel.fetchStamps(for: wallets)
            }
        }
        .onChange(of: networkMonitor.isConnected) { _, isConnected in
            showOfflineBanner = !isConnected
        }
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
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
                
                content
            }
            .onAppear {
                viewSize = geometry.size
            }
            .onChange(of: geometry.size) { _, newSize in
                viewSize = newSize
            }
        }
    }
    
    // MARK: - Toolbar Items
    
    private var viewModeToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Picker("View Mode", selection: $viewMode) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 20))
                    .tag(ViewMode.normalGrid)
                    .accessibilityLabel("Normal grid")
                
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 20))
                    .tag(ViewMode.denseGrid)
                    .accessibilityLabel("Dense grid")
                
                Image(systemName: "rectangle.grid.1x3.fill")
                    .font(.system(size: 20))
                    .tag(ViewMode.list)
                    .accessibilityLabel("List view")
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .accessibilityLabel("View mode control")
            .accessibilityValue(viewMode == .list ? "List view" : viewMode == .denseGrid ? "Dense grid layout" : "Normal grid layout")
        }
    }
    
    private var filterAndSortGroupToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            ControlGroup {
                // Filter Menu (using Section with headers for semantic grouping)
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
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18))
                        .foregroundStyle(viewModel.hasActiveFilters ? Color.purple : Color.primary)
                }
                .accessibilityLabel("Filter stamps")
                .accessibilityHint("Filter stamps by type, format, or edition count")
                
                // Sort Menu (using Section for semantic grouping)
                Menu {
                    Section {
                        Toggle("Stamp # - asc", isOn: Binding(
                            get: { viewModel.currentSortOption == .stampAscending },
                            set: { _ in viewModel.sortStamps(by: .stampAscending, wallets: wallets) }
                        ))
                        
                        Toggle("Stamp # - desc", isOn: Binding(
                            get: { viewModel.currentSortOption == .stampDescending },
                            set: { _ in viewModel.sortStamps(by: .stampDescending, wallets: wallets) }
                        ))
                    }
                    
                    Section {
                        Toggle("Artist - asc", isOn: Binding(
                            get: { viewModel.currentSortOption == .artistAscending },
                            set: { _ in viewModel.sortStamps(by: .artistAscending, wallets: wallets) }
                        ))
                        
                        Toggle("Artist - desc", isOn: Binding(
                            get: { viewModel.currentSortOption == .artistDescending },
                            set: { _ in viewModel.sortStamps(by: .artistDescending, wallets: wallets) }
                        ))
                    }
                    
                    Section {
                        Toggle("Balance - asc", isOn: Binding(
                            get: { viewModel.currentSortOption == .balanceAscending },
                            set: { _ in viewModel.sortStamps(by: .balanceAscending, wallets: wallets) }
                        ))
                        
                        Toggle("Balance - desc", isOn: Binding(
                            get: { viewModel.currentSortOption == .balanceDescending },
                            set: { _ in viewModel.sortStamps(by: .balanceDescending, wallets: wallets) }
                        ))
                    }
                    
                    if showWalletIcons {
                        Section {
                            Toggle("Wallet - asc", isOn: Binding(
                                get: { viewModel.currentSortOption == .walletAscending },
                                set: { _ in viewModel.sortStamps(by: .walletAscending, wallets: wallets) }
                            ))
                            
                            Toggle("Wallet - desc", isOn: Binding(
                                get: { viewModel.currentSortOption == .walletDescending },
                                set: { _ in viewModel.sortStamps(by: .walletDescending, wallets: wallets) }
                            ))
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 20))
                        .foregroundStyle(hasActiveSort ? Color.purple : Color.primary)
                }
                .accessibilityLabel("Sort stamps")
                .accessibilityHint("Choose how to sort your stamp collection")
            }
        }
    }
    
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
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        if wallets.isEmpty {
            emptyWalletsView
        } else if viewModel.isLoading && viewModel.stamps.isEmpty {
            loadingView
        } else if viewModel.showError {
            errorView
        } else if viewModel.stamps.isEmpty {
            noStampsView
        } else if (!viewModel.searchText.isEmpty || viewModel.hasActiveFilters) && viewModel.filteredStamps.isEmpty {
            noSearchResultsView
        } else {
            stampsGrid
        }
    }
    
    
    // MARK: - Empty Wallets View
    
    private var emptyWalletsView: some View {
        ContentUnavailableView {
            Label("No Wallets Added", systemImage: "wallet.bifold")
        } description: {
            Text("Add a Bitcoin wallet to view your stamp collection.\nTap the Settings tab below to get started.")
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1)
                .tint(.purple)
        }
    }
    
    // MARK: - Error View
    
    private var errorView: some View {
        ContentUnavailableView {
            Label("Unable to Load Stamps", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        } description: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        } actions: {
            Button("Try Again") {
                Task {
                    await viewModel.refreshStamps(for: wallets)
                }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Retry loading stamps")
        }
    }
    
    // MARK: - No Stamps View
    
    private var noStampsView: some View {
        ContentUnavailableView(
            "No Stamps Found",
            systemImage: "photo.on.rectangle.angled",
            description: Text("Your wallets don't contain any Stamps")
        )
    }
    
    // MARK: - No Search Results View
    
    private var noSearchResultsView: some View {
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
    
    // MARK: - Stamps Grid
    
    private var stampsGrid: some View {
        ScrollView {
            // Offline banner
            if showOfflineBanner {
                offlineBanner
            }
            
            if viewMode == .list {
                // List view mode
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
            } else {
                // Grid view modes
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.filteredStamps) { displayStamp in
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
    
    // MARK: - Offline Banner
    
    private var offlineBanner: some View {
        HStack {
            Image(systemName: "wifi.slash")
            Text("You're offline. Showing cached content.")
        }
        .font(.caption)
        .foregroundStyle(.primary)
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .glassEffect(.regular.tint(.orange).interactive(), in: .rect(cornerRadius: 8))
        .padding()
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
    CollectionView()
        .environment(CollectionViewModel())
        .environment(NetworkMonitor())
        .modelContainer(for: Wallet.self, inMemory: true)
}
