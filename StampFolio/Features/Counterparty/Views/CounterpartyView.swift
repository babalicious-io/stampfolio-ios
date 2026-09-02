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
    @Environment(\.appColorScheme) private var appColorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \WalletConfig.addedDate, order: .reverse) private var wallets: [WalletConfig]

    // MARK: - State

    @State private var showAddWallet = false
    @State private var showOfflineBanner = false
    @State private var showSlideshow = false
    @State private var detailAsset: CounterpartyDisplay?
    @State private var fullscreenAsset: CounterpartyDisplay?
    @AppStorage("showWalletIcons") private var showWalletIcons = false
    @AppStorage("counterpartyViewMode") private var viewMode: ViewMode = .normalGrid

    // MARK: - Computed Properties

    /// Asset names (CPIDs) already shown as Bitcoin Stamps, so they aren't duplicated here
    private var stampCPIDs: Set<String> {
        Set(stampViewModel.assets.map { $0.asset.counterpartyId })
    }

    private var hasActiveSort: Bool {
        viewModel.currentSortOption != .balanceDescending
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

    /// Dynamic grid columns using native adaptive sizing with device awareness, mirroring `StampView`
    private var columns: [GridItem] {
        gridColumns(viewMode: viewMode, horizontalSizeClass: horizontalSizeClass)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            mainContent
                .toolbar {
                    viewModeToolbarItem
                    ToolbarSpacer(.fixed, placement: .topBarLeading)
                    slideshowToolbarItem
                    filterAndSortGroupToolbarItem
                    SettingsToolbarItem()
                }
        }
        .task {
            await loadData()
        }
        .onChange(of: wallets.count) { oldCount, newCount in
            if newCount < oldCount {
                Task {
                    await viewModel.fetchAssetsMetadata(for: wallets, excludingCPIDs: stampCPIDs)
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
        .fullScreenCover(isPresented: $showSlideshow) {
            CounterpartyAssetFullscreenView(
                assets: viewModel.filteredAssets.map(\.asset),
                initialIndex: 0,
                isSlideshow: true
            )
        }
    }

    // MARK: - Data Loading

    /// Ensure Stamps are loaded first (so CPID exclusion is accurate), then fetch Counterparty assets
    private func loadData() async {
        if stampViewModel.assets.isEmpty && !stampViewModel.isLoading {
            await stampViewModel.fetchAssetsMetadata(for: wallets)
        }
        if viewModel.assets.isEmpty && !viewModel.isLoading {
            await viewModel.fetchAssetsMetadata(for: wallets, excludingCPIDs: stampCPIDs)
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
        if viewModel.isLoading && viewModel.assets.isEmpty {
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

    private var slideshowToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                guard !viewModel.filteredAssets.isEmpty else { return }
                showSlideshow = true
            } label: {
                Image(systemName: "play.square.stack")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start slideshow")
            .accessibilityHint("Play through all Counterparty assets automatically")
        }
    }

    private var filterAndSortGroupToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            ControlGroup {
                Menu {
                    Section("TYPE") {
                        Toggle("Named", isOn: Binding(
                            get: { viewModel.activeAssetTypeFilters.contains("named") },
                            set: { _ in viewModel.toggleAssetTypeFilter("named") }
                        ))

                        Toggle("Numeric", isOn: Binding(
                            get: { viewModel.activeAssetTypeFilters.contains("numeric") },
                            set: { _ in viewModel.toggleAssetTypeFilter("numeric") }
                        ))
                    }

                    Section("DIVISIBILITY") {
                        Toggle("Divisible", isOn: Binding(
                            get: { viewModel.activeDivisibleFilters.contains("divisible") },
                            set: { _ in viewModel.toggleDivisibleFilter("divisible") }
                        ))

                        Toggle("Non-divisible", isOn: Binding(
                            get: { viewModel.activeDivisibleFilters.contains("non_divisible") },
                            set: { _ in viewModel.toggleDivisibleFilter("non_divisible") }
                        ))
                    }

                    Section("LOCK STATUS") {
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
                .accessibilityHint("Filter assets by type, divisibility, or lock status")

                Menu {
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
        .environment(NetworkMonitor())
        .modelContainer(for: WalletConfig.self, inMemory: true)
}
