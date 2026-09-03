//
//  StampView.swift
//  StampFolio
//
//  Main collection view displaying stamps in a grid
//

import SwiftUI
import SwiftData

/// Main collection view showing stamps from all wallets
struct StampView: View {
    
    // MARK: - Environment
    
    @Environment(StampViewModel.self) private var viewModel
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.appColorScheme) private var appColorScheme
    @Query(sort: \WalletConfig.addedDate, order: .reverse) private var wallets: [WalletConfig]
    
    // MARK: - State
    
    @State private var showOfflineBanner = false
    @State private var showAddWallet = false
    @State private var fullscreenAsset: StampDisplay?
    @State private var detailAsset: StampDisplay?
    @State private var slideshowPlaylist: SlideshowPlaylist?
    @AppStorage("showWalletIcons") private var showWalletIcons = false
    @AppStorage("stampViewMode") private var viewMode: ViewMode = .normalGrid
    
    // MARK: - Layout
    
    /// Dynamic grid columns using native adaptive sizing with device awareness
    /// iPhone: 2 columns (normal) / 3 columns (dense)
    /// iPad: 3-4 columns (normal) / 4-5 columns (dense)
    private var columns: [GridItem] {
        gridColumns(viewMode: viewMode, horizontalSizeClass: horizontalSizeClass)
    }
    
    // MARK: - Computed Properties
    
    /// Check if any sort is active (not the default descending stamp sort)
    private var hasActiveSort: Bool {
        viewModel.currentSortOption != .stampDescending
    }
    
    /// Icon for the current view mode
    private var viewModeIcon: String {
        switch viewMode {
        case .normalGrid:
            return "square.grid.2x2.fill"
        case .denseGrid:
            return "square.grid.3x3.fill"
        case .list:
            return "rectangle.grid.1x3.fill"
        }
    }
    
    /// Cycle to the next view mode
    private func cycleViewMode() {
        switch viewMode {
        case .normalGrid:
            viewMode = .denseGrid
        case .denseGrid:
            viewMode = .list
        case .list:
            viewMode = .normalGrid
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            mainContent
                .toolbar {
                    viewModeToolbarItem
                    ToolbarSpacer(.fixed, placement: .topBarLeading)
                    SlideshowToolbarItem(playlist: $slideshowPlaylist)
                    filterAndSortGroupToolbarItem
                    SettingsToolbarItem()
                }
                .fullScreenCover(item: $slideshowPlaylist) { playlist in
                    SlideshowPlayer(playlist: playlist)
                }
        }
        .task {
            if viewModel.assets.isEmpty && !viewModel.isLoading {
                await viewModel.fetchAssetsMetadata(for: wallets)
            }
        }
        .onChange(of: wallets.count) { oldCount, newCount in
            // Only re-fetch on wallet deletion; additions are handled at the point of add wallet
            if newCount < oldCount {
                Task {
                    await viewModel.fetchAssetsMetadata(for: wallets)
                }
            }
        }
        .onChange(of: networkMonitor.isConnected) { _, isConnected in
            showOfflineBanner = !isConnected
        }
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
        .sheet(isPresented: $showAddWallet) {
            AddWalletView()
                .environment(SettingsViewModel())
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            
            content
        }
        .emptyWalletOverlay(walletCount: wallets.count, showAddWallet: $showAddWallet)
    }
    
    // MARK: - Toolbar Items
    
    private var viewModeToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                cycleViewMode()
            } label: {
                Image(systemName: viewModeIcon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.primary)
            }
            .accessibilityLabel("View mode")
            .accessibilityValue(viewMode == .list ? "List view" : viewMode == .denseGrid ? "Dense grid layout" : "Normal grid layout")
            .accessibilityHint("Tap to cycle through view modes")
        }
    }

    private var filterAndSortGroupToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            ControlGroup {
                // Filter Menu (using Section with headers for semantic grouping)
                Menu {
                    Section("STAMP TYPE") {
                        Toggle("Classic", isOn: Binding(
                            get: { viewModel.activeIdentFilters.contains("classic") },
                            set: { _ in viewModel.toggleIdentFilter("classic") }
                        ))
                        
                        Toggle("Cursed", isOn: Binding(
                            get: { viewModel.activeIdentFilters.contains("cursed") },
                            set: { _ in viewModel.toggleIdentFilter("cursed") }
                        ))
                        
                        Toggle("Posh", isOn: Binding(
                            get: { viewModel.activeIdentFilters.contains("posh") },
                            set: { _ in viewModel.toggleIdentFilter("posh") }
                        ))
                    }
                    
                    Section("FILE TYPE") {
                        Toggle("Jpg", isOn: Binding(
                            get: { viewModel.activeFileFormatFilters.contains("jpg") },
                            set: { _ in viewModel.toggleFileFormatFilter("jpg") }
                        ))
                        
                        Toggle("Png", isOn: Binding(
                            get: { viewModel.activeFileFormatFilters.contains("png") },
                            set: { _ in viewModel.toggleFileFormatFilter("png") }
                        ))
                        
                        Toggle("Gif", isOn: Binding(
                            get: { viewModel.activeFileFormatFilters.contains("gif") },
                            set: { _ in viewModel.toggleFileFormatFilter("gif") }
                        ))
                        
                        Toggle("WebP", isOn: Binding(
                            get: { viewModel.activeFileFormatFilters.contains("webp") },
                            set: { _ in viewModel.toggleFileFormatFilter("webp") }
                        ))
                        
                        Toggle("Avif", isOn: Binding(
                            get: { viewModel.activeFileFormatFilters.contains("avif") },
                            set: { _ in viewModel.toggleFileFormatFilter("avif") }
                        ))
                        
                        Toggle("Svg", isOn: Binding(
                            get: { viewModel.activeFileFormatFilters.contains("svg") },
                            set: { _ in viewModel.toggleFileFormatFilter("svg") }
                        ))
                        
                        Toggle("Html", isOn: Binding(
                            get: { viewModel.activeFileFormatFilters.contains("html") },
                            set: { _ in viewModel.toggleFileFormatFilter("html") }
                        ))
                        
                        Toggle("Text", isOn: Binding(
                            get: { viewModel.activeFileFormatFilters.contains("text") },
                            set: { _ in viewModel.toggleFileFormatFilter("text") }
                        ))
                        
                        Toggle("Mp3", isOn: Binding(
                            get: { viewModel.activeFileFormatFilters.contains("mp3") },
                            set: { _ in viewModel.toggleFileFormatFilter("mp3") }
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
                        .foregroundStyle(viewModel.hasActiveFilters ? appColorScheme.primary : Color.primary)
                }
                .menuActionDismissBehavior(.disabled)
                .accessibilityLabel("Filter stamps")
                .accessibilityHint("Filter stamps by type, format, or edition count")
                
                // Sort Menu (using Section for semantic grouping)
                Menu {
                    Section {
                        Toggle("Stamp # - asc", isOn: Binding(
                            get: { viewModel.currentSortOption == .stampAscending },
                            set: { _ in viewModel.sortAssets(by: .stampAscending, wallets: wallets) }
                        ))
                        
                        Toggle("Stamp # - desc", isOn: Binding(
                            get: { viewModel.currentSortOption == .stampDescending },
                            set: { _ in viewModel.sortAssets(by: .stampDescending, wallets: wallets) }
                        ))
                    }
                    
                    Section {
                        Toggle("Artist - asc", isOn: Binding(
                            get: { viewModel.currentSortOption == .artistAscending },
                            set: { _ in viewModel.sortAssets(by: .artistAscending, wallets: wallets) }
                        ))
                        
                        Toggle("Artist - desc", isOn: Binding(
                            get: { viewModel.currentSortOption == .artistDescending },
                            set: { _ in viewModel.sortAssets(by: .artistDescending, wallets: wallets) }
                        ))
                    }
                    
                    Section {
                        Toggle("Balance - asc", isOn: Binding(
                            get: { viewModel.currentSortOption == .balanceAscending },
                            set: { _ in viewModel.sortAssets(by: .balanceAscending, wallets: wallets) }
                        ))
                        
                        Toggle("Balance - desc", isOn: Binding(
                            get: { viewModel.currentSortOption == .balanceDescending },
                            set: { _ in viewModel.sortAssets(by: .balanceDescending, wallets: wallets) }
                        ))
                    }
                    
                    if showWalletIcons {
                        Section {
                            Toggle("Wallet - asc", isOn: Binding(
                                get: { viewModel.currentSortOption == .walletAscending },
                                set: { _ in viewModel.sortAssets(by: .walletAscending, wallets: wallets) }
                            ))
                            
                            Toggle("Wallet - desc", isOn: Binding(
                                get: { viewModel.currentSortOption == .walletDescending },
                                set: { _ in viewModel.sortAssets(by: .walletDescending, wallets: wallets) }
                            ))
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 20))
                        .foregroundStyle(hasActiveSort ? appColorScheme.primary : Color.primary)
                }
                .accessibilityLabel("Sort stamps")
                .accessibilityHint("Choose how to sort your stamp collection")
            }
        }
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.assets.isEmpty {
            CollectionLoadingView()
        } else if viewModel.showError {
            errorView
        } else if viewModel.assets.isEmpty {
            noStampsView
        } else if viewModel.hasActiveFilters && viewModel.filteredAssets.isEmpty {
            noFilterResultsView
        } else {
            stampsGrid
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
                    await viewModel.fetchAssetsMetadata(for: wallets, forceRefresh: true)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(appColorScheme.primary)
            .accessibilityLabel("Retry loading stamps")
        }
    }
    
    // MARK: - No Stamps View
    
    private var noStampsView: some View {
        ContentUnavailableView {
            Label {
                Text("No Stamps Found")
                    .foregroundStyle(appColorScheme.primary)
            } icon: {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundStyle(appColorScheme.secondary)
            }
        } description: {
            Text("Your wallets don't contain any Stamps")
        }
    }
    
    // MARK: - No Filter Results View
    
    private var noFilterResultsView: some View {
        ContentUnavailableView {
            Label {
                Text("No Results")
                    .foregroundStyle(appColorScheme.primary)
            } icon: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundStyle(appColorScheme.secondary)
            }
        } description: {
            Text("No stamps match the active filters")
        }
    }
    
    // MARK: - Stamps Grid
    
    private var stampsGrid: some View {
        ScrollView {
            // Offline banner
            if showOfflineBanner {
                OfflineBannerView()
            }
            
            if viewMode == .list {
                // List view mode
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
                        .onAppear {
                            // Fetch market data when row appears in list view
                            // Applies to: iPhone (landscape) + iPad (all orientations)
                            Task {
                                await viewModel.fetchMarketDataIfNeeded(for: displayAsset)
                            }
                        }
                    }
                }
                .padding()
            } else {
                // Grid view modes
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.filteredAssets) { displayAsset in
                        StampAssetCardView(
                            displayAsset: displayAsset,
                            onTap: {
                                detailAsset = displayAsset
                            },
                            onLongPress: {
                                fullscreenAsset = displayAsset
                            },
                            viewMode: viewMode
                        )
                    }
                }
                .padding()
            }
        }
    }
    
}

// MARK: - Preview

#Preview {
    StampView()
        .environment(StampViewModel())
        .environment(CounterpartyViewModel())
        .environment(NetworkMonitor())
        .modelContainer(for: WalletConfig.self, inMemory: true)
}
