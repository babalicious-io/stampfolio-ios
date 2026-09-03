//
//  SlideshowToolbarItem.swift
//  StampFolio
//
//  Toolbar menu for choosing which protocols to include in a slideshow
//

import SwiftUI
import SwiftData

/// Leading toolbar play button that opens a Filter/Sort-style protocol picker.
/// Presentation lives on the collection view via `playlist` — same as long-press fullscreen —
/// because a `fullScreenCover` attached to a toolbar `Menu` does not get a screen-sized frame.
struct SlideshowToolbarItem: ToolbarContent {

    @Binding var playlist: SlideshowPlaylist?

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            SlideshowMenuButton(playlist: $playlist)
        }
    }
}

// MARK: - Menu Button

/// Protocol picker. Sets `playlist` on Play Now; the parent presents the cover.
private struct SlideshowMenuButton: View {

    // MARK: - Environment

    @Environment(StampViewModel.self) private var stampViewModel
    @Environment(CounterpartyViewModel.self) private var counterpartyViewModel
    @Query(sort: \WalletConfig.addedDate, order: .reverse) private var wallets: [WalletConfig]

    // MARK: - State

    @Binding var playlist: SlideshowPlaylist?
    @State private var selectedProtocols: Set<ProtocolType> = []
    @State private var protocolOrder: [ProtocolType] = ProtocolType.loadSavedOrder()

    @AppStorage("showStamps") private var showStamps = true
    @AppStorage("showOrdinals") private var showOrdinals = true
    @AppStorage("showCounterparty") private var showCounterparty = true

    // MARK: - Computed Properties

    private var enabledProtocols: [ProtocolType] {
        protocolOrder.filter { isEnabled($0) }
    }

    // MARK: - Body

    var body: some View {
        Menu {
            Section {
                ForEach(enabledProtocols) { protocolType in
                    Toggle(protocolType.rawValue, isOn: binding(for: protocolType))
                        .menuActionDismissBehavior(.disabled)
                }
            }

            Section {
                Button("Play Now", systemImage: "play.fill") {
                    Task {
                        await startSlideshow()
                    }
                }
            }
        } label: {
            Image(systemName: "play.square.stack")
                .font(.system(size: 18))
                .foregroundStyle(Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start slideshow")
        .accessibilityHint("Choose protocols, then tap Play Now")
        .onAppear {
            refreshProtocolOrder()
        }
        .onChange(of: showStamps) { _, _ in refreshProtocolOrder() }
        .onChange(of: showOrdinals) { _, _ in refreshProtocolOrder() }
        .onChange(of: showCounterparty) { _, _ in refreshProtocolOrder() }
        .onReceive(NotificationCenter.default.publisher(for: .protocolOrderDidChange)) { _ in
            refreshProtocolOrder()
        }
    }

    // MARK: - Bindings

    private func binding(for protocolType: ProtocolType) -> Binding<Bool> {
        Binding(
            get: { selectedProtocols.contains(protocolType) },
            set: { isOn in
                if isOn {
                    selectedProtocols.insert(protocolType)
                } else {
                    selectedProtocols.remove(protocolType)
                }
            }
        )
    }

    private func refreshProtocolOrder() {
        protocolOrder = ProtocolType.loadSavedOrder()
        selectedProtocols = selectedProtocols.filter { isEnabled($0) }
    }

    private func isEnabled(_ protocolType: ProtocolType) -> Bool {
        switch protocolType {
        case .stamps: return showStamps
        case .ordinals: return showOrdinals
        case .counterparty: return showCounterparty
        }
    }

    // MARK: - Playback

    @MainActor
    private func startSlideshow() async {
        await loadDataIfNeeded()
        let items = buildSlideshowItems()
        guard !items.isEmpty else { return }
        playlist = SlideshowPlaylist(items: items)
    }

    /// Fetch any selected protocol that hasn't been loaded yet (e.g. playing Counterparty from Stamps)
    private func loadDataIfNeeded() async {
        let needsStamps = selectedProtocols.contains(.stamps) || selectedProtocols.contains(.counterparty)
        let needsCounterparty = selectedProtocols.contains(.counterparty)

        if needsStamps, stampViewModel.assets.isEmpty, !stampViewModel.isLoading {
            await stampViewModel.fetchAssetsMetadata(for: wallets)
        }

        if needsCounterparty, counterpartyViewModel.assets.isEmpty, !counterpartyViewModel.isLoading {
            let stampCPIDs = Set(stampViewModel.assets.map { $0.asset.counterpartyId })
            await counterpartyViewModel.fetchAssetsMetadata(for: wallets, excludingCPIDs: stampCPIDs)
        }
    }

    private func buildSlideshowItems() -> [SlideshowItem] {
        var items: [SlideshowItem] = []
        for protocolType in enabledProtocols where selectedProtocols.contains(protocolType) {
            switch protocolType {
            case .stamps:
                items += stampViewModel.filteredAssets.map { .stamp($0.asset) }
            case .counterparty:
                items += counterpartyViewModel.filteredAssets.map { .counterparty($0.asset) }
            case .ordinals:
                break
            }
        }
        return items
    }
}
