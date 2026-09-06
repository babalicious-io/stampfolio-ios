//
//  CounterpartyView.swift
//  StampFolio
//
//  Counterparty asset holdings view
//

import SwiftUI
import SwiftData

/// View for displaying a wallet's Counterparty asset holdings (excluding assets already
/// shown as Bitcoin Stamps elsewhere in the app)
struct CounterpartyView: View {

    // MARK: - Environment

    @Environment(CounterpartyViewModel.self) private var viewModel
    @Environment(StampViewModel.self) private var stampViewModel
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(AssetDownloadCoordinator.self) private var downloadCoordinator
    @Environment(\.appColorScheme) private var appColorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \WalletConfig.addedDate, order: .reverse) private var wallets: [WalletConfig]

    // MARK: - State

    @State private var showAddWallet = false
    @State private var showOfflineBanner = false
    @State private var detailAsset: CounterpartyDisplay?
    @State private var fullscreenAsset: CounterpartyDisplay?
    @State private var slideshowPlaylist: SlideshowPlaylist?
    @AppStorage(ViewMode.storageKey) private var viewMode: ViewMode = .normalGrid

    // MARK: - Computed Properties

    /// Asset names (CPIDs) already shown as Bitcoin Stamps, so they aren't duplicated here
    private var stampCPIDs: Set<String> {
        stampViewModel.stampCPIDs
    }

    private var hasActiveSort: Bool {
        viewModel.currentSortOption != .dateDescending
    }

    /// Adaptive columns from available width (compact vs regular)
    private var columns: [GridItem] {
        gridColumns(viewMode: viewMode, horizontalSizeClass: horizontalSizeClass)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            mainContent
                .toolbar {
                    ViewModeToolbarItem(viewMode: $viewMode)
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
            await loadData()
        }
        .onChange(of: stampViewModel.stampCPIDs) { _, cpids in
            viewModel.applyStampExclusion(cpids)
        }
        .onChange(of: wallets.count) { oldCount, newCount in
            if newCount < oldCount {
                Task {
                    await viewModel.fetchAssetsMetadata(for: wallets, excludingCPIDs: stampViewModel.stampCPIDs)
                }
            }
        }
        .onChange(of: networkMonitor.isConnected) { _, isConnected in
            showOfflineBanner = !isConnected
        }
        .sheet(item: $detailAsset) { displayAsset in
            CounterpartyAssetDetailView(displayAsset: displayAsset, viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAddWallet) {
            AddWalletView()
                .environment(SettingsViewModel())
        }
        .fullScreenCover(item: $fullscreenAsset) { displayAsset in
            if let index = viewModel.filteredAssets.firstIndex(where: { $0.id == displayAsset.id }) {
                CounterpartyAssetFullscreenView(
                    assets: viewModel.filteredAssets.map(\.asset),
                    initialIndex: index
                )
            }
        }
    }

    // MARK: - Data Loading

    /// Wait for Stamps to finish loading so CPID exclusion is complete, then fetch Counterparty assets
    private func loadData() async {
        if stampViewModel.assets.isEmpty {
            await stampViewModel.fetchAssetsMetadata(for: wallets)
        }
        viewModel.applyStampExclusion(stampViewModel.stampCPIDs)
        if viewModel.assets.isEmpty && !viewModel.isLoading {
            await viewModel.fetchAssetsMetadata(for: wallets, excludingCPIDs: stampViewModel.stampCPIDs)
            viewModel.applyStampExclusion(stampViewModel.stampCPIDs)
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

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        // First wallet: hold the grid back so Stamps and Counterparty appear together
        // when the Downloading Assets popup closes.
        if downloadCoordinator.withholdsCollections || (viewModel.isLoading && viewModel.assets.isEmpty) {
            CollectionLoadingView()
        } else if viewModel.showError {
            errorView
        } else if viewModel.assets.isEmpty {
            noAssetsView
        } else if viewModel.hasActiveFilters && viewModel.filteredAssets.isEmpty {
            noFilterResultsView
        } else {
            assetsList
        }
    }

    // MARK: - Error View

    private var errorView: some View {
        ContentUnavailableView {
            Label("Unable to Load Assets", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        } description: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        } actions: {
            Button("Try Again") {
                Task {
                    await viewModel.fetchAssetsMetadata(for: wallets, excludingCPIDs: stampCPIDs, forceRefresh: true)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(appColorScheme.primary)
            .accessibilityLabel("Retry loading Counterparty assets")
        }
    }

    // MARK: - No Assets View

    private var noAssetsView: some View {
        ContentUnavailableView {
            Label {
                Text("No Counterparty Assets")
                    .foregroundStyle(appColorScheme.primary)
            } icon: {
                Image(systemName: "xmark.triangle.circle.square.fill")
                    .foregroundStyle(appColorScheme.secondary)
            }
        } description: {
            Text("Your wallets don't hold any other Counterparty assets")
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
            Text("No assets match the active filters")
        }
    }

    // MARK: - Assets List

    private var assetsList: some View {
        ScrollView {
            if showOfflineBanner {
                OfflineBannerView()
            }

            if viewMode == .list {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.filteredAssets) { displayAsset in
                        CounterpartyAssetRowView(
                            displayAsset: displayAsset,
                            onTap: {
                                detailAsset = displayAsset
                            },
                            onLongPress: {
                                fullscreenAsset = displayAsset
                            }
                        )
                        .onAppear {
                            Task {
                                await viewModel.fetchMarketDataIfNeeded(for: displayAsset)
                            }
                        }
                    }
                }
                .padding()
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.filteredAssets) { displayAsset in
                        CounterpartyAssetCardView(
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

    // MARK: - Toolbar Items

    private var filterAndSortGroupToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            ControlGroup {
                Menu {
                    Section("ASSET TYPE") {
                        Toggle("Named", isOn: Binding(
                            get: { viewModel.activeAssetTypeFilters.contains("named") },
                            set: { _ in viewModel.toggleAssetTypeFilter("named") }
                        ))

                        Toggle("Numeric", isOn: Binding(
                            get: { viewModel.activeAssetTypeFilters.contains("numeric") },
                            set: { _ in viewModel.toggleAssetTypeFilter("numeric") }
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

                    Section("EDITION STATUS") {
                        Toggle("Locked", isOn: Binding(
                            get: { viewModel.activeLockedFilters.contains("locked") },
                            set: { _ in viewModel.toggleLockedFilter("locked") }
                        ))

                        Toggle("Unlocked", isOn: Binding(
                            get: { viewModel.activeLockedFilters.contains("unlocked") },
                            set: { _ in viewModel.toggleLockedFilter("unlocked") }
                        ))
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18))
                        .foregroundStyle(viewModel.hasActiveFilters ? appColorScheme.primary : Color.primary)
                }
                .menuActionDismissBehavior(.disabled)
                .accessibilityLabel("Filter assets")
                .accessibilityHint("Filter assets by type, edition count, or edition status")

                Menu {
                    Section {
                        Toggle("Date - newest", isOn: Binding(
                            get: { viewModel.currentSortOption == .dateDescending },
                            set: { _ in viewModel.sortAssets(by: .dateDescending, wallets: wallets) }
                        ))

                        Toggle("Date - oldest", isOn: Binding(
                            get: { viewModel.currentSortOption == .dateAscending },
                            set: { _ in viewModel.sortAssets(by: .dateAscending, wallets: wallets) }
                        ))
                    }

                    Section {
                        Toggle("Name - asc", isOn: Binding(
                            get: { viewModel.currentSortOption == .nameAscending },
                            set: { _ in viewModel.sortAssets(by: .nameAscending, wallets: wallets) }
                        ))

                        Toggle("Name - desc", isOn: Binding(
                            get: { viewModel.currentSortOption == .nameDescending },
                            set: { _ in viewModel.sortAssets(by: .nameDescending, wallets: wallets) }
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

                    if wallets.count > 1 {
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
                .accessibilityLabel("Sort assets")
                .accessibilityHint("Choose how to sort your Counterparty assets")
            }
        }
    }

}

// MARK: - Preview

#Preview {
    CounterpartyView()
        .environment(CounterpartyViewModel())
        .environment(StampViewModel())
        .environment(SlideshowSelection())
        .environment(NetworkMonitor())
        .environment(AssetDownloadCoordinator())
        .modelContainer(for: WalletConfig.self, inMemory: true)
}
