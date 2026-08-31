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
    @Environment(CollectionViewModel.self) private var collectionViewModel
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(\.showSettingsBinding) private var showSettings
    @Environment(\.appColorScheme) private var appColorScheme
    @Query(sort: \WalletConfig.addedDate, order: .reverse) private var wallets: [WalletConfig]

    // MARK: - State

    @State private var showAddWallet = false
    @State private var showOfflineBanner = false

    // MARK: - Computed Properties

    /// Asset names (CPIDs) already shown as Bitcoin Stamps, so they aren't duplicated here
    private var stampCPIDs: Set<String> {
        Set(collectionViewModel.stamps.map { $0.stamp.counterpartyId })
    }

    private var hasActiveSort: Bool {
        viewModel.currentSortOption != .balanceDescending
    }

    // MARK: - Body

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            mainContent
                .navigationTitle("Counterparty")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $viewModel.searchText, prompt: "Search assets")
                .toolbar {
                    sortToolbarItem
                    settingsToolbarItem
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
        .sheet(item: $viewModel.selectedAsset) { displayAsset in
            CounterpartyAssetDetailView(displayAsset: displayAsset, viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAddWallet) {
            AddWalletView()
                .environment(SettingsViewModel())
        }
    }

    // MARK: - Data Loading

    /// Ensure Stamps are loaded first (so CPID exclusion is accurate), then fetch Counterparty assets
    private func loadData() async {
        if collectionViewModel.stamps.isEmpty {
            await collectionViewModel.fetchStampsMetadata(for: wallets)
        }
        if viewModel.assets.isEmpty {
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
            loadingView
        } else if viewModel.showError {
            errorView
        } else if viewModel.assets.isEmpty {
            noAssetsView
        } else if !viewModel.searchText.isEmpty && viewModel.filteredAssets.isEmpty {
            noSearchResultsView
        } else {
            assetsList
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1)
                .tint(appColorScheme.primary)
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

    // MARK: - No Search Results View

    private var noSearchResultsView: some View {
        ContentUnavailableView.search(text: viewModel.searchText)
    }

    // MARK: - Assets List

    private var assetsList: some View {
        ScrollView {
            if showOfflineBanner {
                offlineBanner
            }

            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredAssets) { displayAsset in
                    CounterpartyAssetRowView(
                        displayAsset: displayAsset,
                        onTap: {
                            viewModel.selectedAsset = displayAsset
                        }
                    )
                }
            }
            .padding()
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
        .glassEffect(.regular.tint(appColorScheme.primary).interactive(), in: .rect(cornerRadius: 8))
        .padding()
    }

    // MARK: - Toolbar Items

    private var sortToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
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
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 18))
                    .foregroundStyle(hasActiveSort ? appColorScheme.primary : Color.primary)
            }
            .accessibilityLabel("Sort assets")
            .accessibilityHint("Choose how to sort your Counterparty assets")
        }
    }

    private var settingsToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showSettings.wrappedValue = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
            .accessibilityHint("Open app settings")
        }
    }
}

// MARK: - Preview

#Preview {
    CounterpartyView()
        .environment(CounterpartyViewModel())
        .environment(CollectionViewModel())
        .environment(NetworkMonitor())
        .modelContainer(for: WalletConfig.self, inMemory: true)
}
