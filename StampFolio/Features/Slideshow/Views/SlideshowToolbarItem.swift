//
//  SlideshowToolbarItem.swift
//  StampFolio
//
//  Toolbar control: tap starts the slideshow; long press configures protocols and interval
//

import SwiftUI
import SwiftData

/// Leading toolbar play button. Tap starts playback; long press opens protocol/interval
/// configuration. Presentation lives on the collection view via `playlist` — same as
/// long-press fullscreen — because a `fullScreenCover` attached to a toolbar `Menu`
/// does not get a screen-sized frame.
struct SlideshowToolbarItem: ToolbarContent {

    @Binding var playlist: SlideshowPlaylist?

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            SlideshowMenuButton(playlist: $playlist)
        }
    }
}

// MARK: - Menu Button

/// Protocol/interval picker. Tap (`primaryAction`) sets `playlist`; the parent presents the cover.
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
    @AppStorage("slideshowInterval") private var slideshowInterval = 5

    private static let slideshowIntervals = [3, 5, 7, 9, 10, 12, 15, 20, 25, 30, 45, 60, 90, 120]
    private static let selectedProtocolsKey = "slideshowSelectedProtocols"

    // MARK: - Computed Properties

    private var enabledProtocols: [ProtocolType] {
        protocolOrder.filter { isEnabled($0) }
    }

    /// Protocol toggles are redundant when Settings leaves only one protocol visible.
    private var showsProtocolPicker: Bool {
        enabledProtocols.count > 1
    }

    /// Slideshow inclusion set. When a single protocol is enabled in Settings, use it
    /// even if the user never saw (or toggled) the picker.
    private var protocolsForPlayback: Set<ProtocolType> {
        if enabledProtocols.count == 1, let only = enabledProtocols.first {
            return [only]
        }
        return selectedProtocols
    }

    // MARK: - Body

    var body: some View {
        Menu {
            if showsProtocolPicker {
                Section {
                    ForEach(enabledProtocols) { protocolType in
                        Toggle(protocolType.rawValue, isOn: binding(for: protocolType))
                            .menuActionDismissBehavior(.disabled)
                    }
                }
            }

            Section {
                Picker("Interval - \(slideshowInterval)s", selection: $slideshowInterval) {
                    ForEach(Self.slideshowIntervals, id: \.self) { secs in
                        Text("\(secs)s")
                            .tag(secs)
                    }
                }
                .pickerStyle(.menu)
                .menuActionDismissBehavior(.disabled)
            }
        } label: {
            Image(systemName: "play.square.stack")
                .font(.system(size: 18))
                .foregroundStyle(Color.primary)
        } primaryAction: {
            Task {
                await startSlideshow()
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start slideshow")
        .accessibilityHint(showsProtocolPicker
            ? "Tap to play. Long press to choose protocols and interval."
            : "Tap to play. Long press to choose interval.")
        .onAppear {
            protocolOrder = ProtocolType.loadSavedOrder()
            loadOrDefaultSelectedProtocols()
        }
        .onChange(of: showStamps) { _, isOn in
            handleSettingsToggle(.stamps, isOn: isOn)
        }
        .onChange(of: showOrdinals) { _, isOn in
            handleSettingsToggle(.ordinals, isOn: isOn)
        }
        .onChange(of: showCounterparty) { _, isOn in
            handleSettingsToggle(.counterparty, isOn: isOn)
        }
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
                    if selectedProtocols.isEmpty {
                        selectedProtocols.insert(fallbackProtocol(after: protocolType))
                    }
                }
                saveSelectedProtocols()
            }
        )
    }

    /// Next Settings-enabled protocol after `protocolType`, wrapping. Used when turning off
    /// the last selected protocol so the slideshow always has at least one source.
    private func fallbackProtocol(after protocolType: ProtocolType) -> ProtocolType {
        let options = enabledProtocols
        guard let index = options.firstIndex(of: protocolType), !options.isEmpty else {
            return options.first ?? protocolType
        }
        return options[(index + 1) % options.count]
    }

    private func refreshProtocolOrder() {
        protocolOrder = ProtocolType.loadSavedOrder()
        syncSelectedProtocolsWithEnabled()
        saveSelectedProtocols()
    }

    private func handleSettingsToggle(_ protocolType: ProtocolType, isOn: Bool) {
        refreshProtocolOrder()
        if isOn {
            selectedProtocols.insert(protocolType)
            saveSelectedProtocols()
        }
    }

    private func syncSelectedProtocolsWithEnabled() {
        if enabledProtocols.count == 1, let only = enabledProtocols.first {
            selectedProtocols = [only]
        } else {
            selectedProtocols = selectedProtocols.filter { isEnabled($0) }
            if selectedProtocols.isEmpty, let first = enabledProtocols.first {
                selectedProtocols = [first]
            }
        }
    }

    private func loadOrDefaultSelectedProtocols() {
        if UserDefaults.standard.object(forKey: Self.selectedProtocolsKey) == nil {
            selectedProtocols = Set(enabledProtocols)
            saveSelectedProtocols()
            return
        }

        if let data = UserDefaults.standard.data(forKey: Self.selectedProtocolsKey),
           let decoded = try? JSONDecoder().decode([ProtocolType].self, from: data) {
            selectedProtocols = Set(decoded)
            syncSelectedProtocolsWithEnabled()
            saveSelectedProtocols()
        } else {
            selectedProtocols = Set(enabledProtocols)
            saveSelectedProtocols()
        }
    }

    private func saveSelectedProtocols() {
        guard let data = try? JSONEncoder().encode(Array(selectedProtocols)) else { return }
        UserDefaults.standard.set(data, forKey: Self.selectedProtocolsKey)
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
        let needsStamps = protocolsForPlayback.contains(.stamps) || protocolsForPlayback.contains(.counterparty)
        let needsCounterparty = protocolsForPlayback.contains(.counterparty)

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
        for protocolType in enabledProtocols where protocolsForPlayback.contains(protocolType) {
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
