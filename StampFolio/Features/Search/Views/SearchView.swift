//
//  SearchView.swift
//  StampFolio
//
//  Unified search across enabled protocol collections
//

import SwiftUI
import SwiftData

/// Full-screen search view querying every enabled protocol
struct SearchView: View {

    // MARK: - Environment

    @Environment(StampViewModel.self) private var stampViewModel
    @Environment(CounterpartyViewModel.self) private var counterpartyViewModel
    @Environment(AssetDownloadCoordinator.self) private var downloadCoordinator
    @Environment(\.appColorScheme) private var appColorScheme
    @Query(sort: \WalletConfig.addedDate, order: .reverse) private var wallets: [WalletConfig]

    // MARK: - State

    @State private var searchText = ""
    @State private var protocolOrder: [ProtocolType] = ProtocolType.loadSavedOrder()
    @State private var stampDetailAsset: StampDisplay?
    @State private var stampFullscreenAsset: StampDisplay?
    @State private var counterpartyDetailAsset: CounterpartyDisplay?
    @State private var counterpartyFullscreenAsset: CounterpartyDisplay?

    @AppStorage("showStamps") private var showStamps = true
    @AppStorage("showOrdinals") private var showOrdinals = true
    @AppStorage("showCounterparty") private var showCounterparty = true

    // MARK: - Computed Properties

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasQuery: Bool {
        !trimmedQuery.isEmpty
    }

    private var enabledProtocols: [ProtocolType] {
        protocolOrder.filter { isEnabled($0) }
    }

    private var stampResults: [StampDisplay] {
        guard showStamps, hasQuery else { return [] }
        return stampViewModel.assets(matching: trimmedQuery)
    }

    private var counterpartyResults: [CounterpartyDisplay] {
        guard showCounterparty, hasQuery else { return [] }
        return counterpartyViewModel.assets(matching: trimmedQuery)
    }

    private var hasResults: Bool {
        !stampResults.isEmpty || !counterpartyResults.isEmpty
    }

    private var searchableProtocolNames: [String] {
        enabledProtocols.compactMap { protocolType in
            switch protocolType {
            case .stamps: return "Stamps"
            case .counterparty: return "Counterparty"
            case .ordinals: return nil
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if !hasQuery {
                    searchEmptyState
                } else if !hasResults {
                    noResultsView
                } else {
                    searchResults
                }
            }
            .tint(appColorScheme.primary)
        }
        .searchable(text: $searchText, prompt: "Search")
        .task {
            await loadDataIfNeeded()
        }
        .onChange(of: stampViewModel.stampCPIDs) { _, cpids in
            counterpartyViewModel.applyStampExclusion(cpids)
        }
        .onAppear {
            protocolOrder = ProtocolType.loadSavedOrder()
        }
        .onChange(of: showStamps) { _, _ in protocolOrder = ProtocolType.loadSavedOrder() }
        .onChange(of: showOrdinals) { _, _ in protocolOrder = ProtocolType.loadSavedOrder() }
        .onChange(of: showCounterparty) { _, _ in protocolOrder = ProtocolType.loadSavedOrder() }
        .onReceive(NotificationCenter.default.publisher(for: .protocolOrderDidChange)) { _ in
            protocolOrder = ProtocolType.loadSavedOrder()
        }
        .fullScreenCover(item: $stampFullscreenAsset) { displayAsset in
            if let index = stampResults.firstIndex(where: { $0.id == displayAsset.id }) {
                StampAssetFullscreenView(
                    assets: stampResults.map(\.asset),
                    initialIndex: index
                )
            }
        }
        .sheet(item: $stampDetailAsset) { displayAsset in
            StampAssetDetailView(displayAsset: displayAsset, viewModel: stampViewModel)
                .presentationDetents([.medium, .large])
        }
        .fullScreenCover(item: $counterpartyFullscreenAsset) { displayAsset in
            if let index = counterpartyResults.firstIndex(where: { $0.id == displayAsset.id }) {
                CounterpartyAssetFullscreenView(
                    assets: counterpartyResults.map(\.asset),
                    initialIndex: index
                )
            }
        }
        .sheet(item: $counterpartyDetailAsset) { displayAsset in
            CounterpartyAssetDetailView(displayAsset: displayAsset, viewModel: counterpartyViewModel)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Empty State

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
            Text(emptyStateDescription)
        }
    }

    private var emptyStateDescription: String {
        if searchableProtocolNames.isEmpty {
            if showOrdinals && enabledProtocols == [.ordinals] {
                return "Ordinals search isn't available yet."
            }
            return "Turn on a collection in Settings to search."
        }
        return "Search \(joinedList(searchableProtocolNames)) by stamp number, CPID, artist, asset name, issuer, or transaction hash."
    }

    // MARK: - No Results

    private var noResultsView: some View {
        ContentUnavailableView {
            Label {
                Text("No Results")
                    .foregroundStyle(appColorScheme.primary)
            } icon: {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(appColorScheme.secondary)
            }
        } description: {
            Text("No assets match '\(trimmedQuery)'")
        }
    }

    // MARK: - Results

    private var searchResults: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(enabledProtocols) { protocolType in
                    switch protocolType {
                    case .stamps:
                        if !stampResults.isEmpty {
                            protocolSection(protocolType) {
                                ForEach(stampResults) { displayAsset in
                                    StampAssetRowView(
                                        displayAsset: displayAsset,
                                        onTap: { stampDetailAsset = displayAsset },
                                        onLongPress: { stampFullscreenAsset = displayAsset }
                                    )
                                    .onAppear {
                                        Task {
                                            await stampViewModel.fetchMarketDataIfNeeded(for: displayAsset)
                                        }
                                    }
                                }
                            }
                        }
                    case .counterparty:
                        if !counterpartyResults.isEmpty {
                            protocolSection(protocolType) {
                                ForEach(counterpartyResults) { displayAsset in
                                    CounterpartyAssetRowView(
                                        displayAsset: displayAsset,
                                        onTap: { counterpartyDetailAsset = displayAsset },
                                        onLongPress: { counterpartyFullscreenAsset = displayAsset }
                                    )
                                    .onAppear {
                                        Task {
                                            await counterpartyViewModel.fetchMarketDataIfNeeded(for: displayAsset)
                                        }
                                    }
                                }
                            }
                        }
                    case .ordinals:
                        EmptyView()
                    }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func protocolSection<Content: View>(
        _ protocolType: ProtocolType,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(protocolType.rawValue, systemImage: protocolType.icon)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            content()
        }
    }

    // MARK: - Data Loading

    /// Load collection data if Search is opened before visiting a protocol tab.
    /// Always wait for an in-flight stamp fetch so Counterparty CPID exclusion is complete.
    /// Skip while the download overlay is running so a full fetch cannot cancel its prefetchers.
    private func loadDataIfNeeded() async {
        if showStamps || showCounterparty,
           stampViewModel.assets.isEmpty,
           !stampViewModel.isLoading,
           !downloadCoordinator.blocksCollectionFetch {
            await stampViewModel.fetchAssetsMetadata(for: wallets)
        }

        if showCounterparty {
            counterpartyViewModel.applyStampExclusion(stampViewModel.stampCPIDs)
            if counterpartyViewModel.assets.isEmpty,
               !counterpartyViewModel.isLoading,
               !downloadCoordinator.blocksCollectionFetch {
                await counterpartyViewModel.fetchAssetsMetadata(for: wallets, excludingCPIDs: stampViewModel.stampCPIDs)
                counterpartyViewModel.applyStampExclusion(stampViewModel.stampCPIDs)
            }
        }
    }

    private func isEnabled(_ protocolType: ProtocolType) -> Bool {
        switch protocolType {
        case .stamps: return showStamps
        case .ordinals: return showOrdinals
        case .counterparty: return showCounterparty
        }
    }

    private func joinedList(_ names: [String]) -> String {
        switch names.count {
        case 0: return ""
        case 1: return names[0]
        case 2: return "\(names[0]) and \(names[1])"
        default:
            return names.dropLast().joined(separator: ", ") + ", and \(names.last!)"
        }
    }
}

// MARK: - Preview

#Preview {
    SearchView()
        .environment(StampViewModel())
        .environment(CounterpartyViewModel())
        .environment(AssetDownloadCoordinator())
        .modelContainer(for: WalletConfig.self, inMemory: true)
}
