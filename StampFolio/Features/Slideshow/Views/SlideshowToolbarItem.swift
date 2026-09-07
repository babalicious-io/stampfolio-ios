//
//  SlideshowToolbarItem.swift
//  StampFolio
//
//  Toolbar control: tap starts the slideshow; long press configures protocols and interval
//

import SwiftUI
import SwiftData
import Observation

/// App-scoped slideshow protocol selection. Shared by every collection tab so toggles
/// stay in sync without relying on `onAppear` reloads from disk.
@Observable
@MainActor
final class SlideshowSelection {

    static let selectedProtocolsKey = "slideshowSelectedProtocols"

    var selectedProtocols: Set<ProtocolType> = []

    init() {
        loadOrDefault(enabled: Self.enabledProtocolsFromDefaults())
    }

    func loadOrDefault(enabled: [ProtocolType]) {
        if UserDefaults.standard.object(forKey: Self.selectedProtocolsKey) == nil {
            selectedProtocols = Set(enabled)
            save()
            return
        }

        if let data = UserDefaults.standard.data(forKey: Self.selectedProtocolsKey),
           let decoded = try? JSONDecoder().decode([ProtocolType].self, from: data) {
            selectedProtocols = Set(decoded)
            sync(enabled: enabled)
            save()
        } else {
            selectedProtocols = Set(enabled)
            save()
        }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(Array(selectedProtocols)) else { return }
        UserDefaults.standard.set(data, forKey: Self.selectedProtocolsKey)
    }

    func sync(enabled: [ProtocolType]) {
        if enabled.count == 1, let only = enabled.first {
            selectedProtocols = [only]
        } else {
            let enabledSet = Set(enabled)
            selectedProtocols = selectedProtocols.filter { enabledSet.contains($0) }
            if selectedProtocols.isEmpty, let first = enabled.first {
                selectedProtocols = [first]
            }
        }
    }

    func handleSettingsToggle(_ protocolType: ProtocolType, isOn: Bool, enabled: [ProtocolType]) {
        sync(enabled: enabled)
        if isOn {
            selectedProtocols.insert(protocolType)
        }
        save()
    }

    private static func enabledProtocolsFromDefaults() -> [ProtocolType] {
        ProtocolType.loadSavedOrder().filter { isEnabledFromDefaults($0) }
    }

    private static func isEnabledFromDefaults(_ protocolType: ProtocolType) -> Bool {
        switch protocolType {
        case .stamps:
            return UserDefaults.standard.object(forKey: "showStamps") as? Bool ?? true
        case .ordinals:
            return UserDefaults.standard.object(forKey: "showOrdinals") as? Bool ?? true
        case .counterparty:
            return UserDefaults.standard.object(forKey: "showCounterparty") as? Bool ?? true
        }
    }
}

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
    @Environment(AssetDownloadCoordinator.self) private var downloadCoordinator
    @Environment(SlideshowSelection.self) private var slideshowSelection
    @Query(sort: \WalletConfig.addedDate, order: .reverse) private var wallets: [WalletConfig]

    // MARK: - State

    @Binding var playlist: SlideshowPlaylist?
    @State private var protocolOrder: [ProtocolType] = ProtocolType.loadSavedOrder()

    @AppStorage("showStamps") private var showStamps = true
    @AppStorage("showOrdinals") private var showOrdinals = true
    @AppStorage("showCounterparty") private var showCounterparty = true
    @AppStorage("slideshowInterval") private var slideshowInterval = 5

    private static let slideshowIntervals = [3, 5, 7, 9, 10, 12, 15, 20, 25, 30, 45, 60, 90, 120]

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
        return slideshowSelection.selectedProtocols
    }

    // MARK: - Body

    var body: some View {
        Menu {
            if showsProtocolPicker {
                Section("PROTOCOL") {
                    ForEach(enabledProtocols) { protocolType in
                        Toggle(protocolType.rawValue, isOn: binding(for: protocolType))
                            .menuActionDismissBehavior(.disabled)
                    }
                }
            }

            Section("INTERVAL") {
                Picker("Interval", selection: $slideshowInterval) {
                    ForEach(Self.slideshowIntervals, id: \.self) { secs in
                        Text("\(secs)s")
                            .tag(secs)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
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
            slideshowSelection.sync(enabled: enabledProtocols)
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
            get: { slideshowSelection.selectedProtocols.contains(protocolType) },
            set: { isOn in
                if isOn {
                    slideshowSelection.selectedProtocols.insert(protocolType)
                } else {
                    slideshowSelection.selectedProtocols.remove(protocolType)
                    if slideshowSelection.selectedProtocols.isEmpty {
                        slideshowSelection.selectedProtocols.insert(fallbackProtocol(after: protocolType))
                    }
                }
                slideshowSelection.save()
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
        slideshowSelection.sync(enabled: enabledProtocols)
        slideshowSelection.save()
    }

    private func handleSettingsToggle(_ protocolType: ProtocolType, isOn: Bool) {
        protocolOrder = ProtocolType.loadSavedOrder()
        slideshowSelection.handleSettingsToggle(protocolType, isOn: isOn, enabled: enabledProtocols)
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

    /// Fetch any selected protocol that hasn't been loaded yet (e.g. playing Counterparty from Stamps).
    /// Skip while the download overlay is running so a full fetch cannot cancel its prefetchers.
    private func loadDataIfNeeded() async {
        let needsStamps = protocolsForPlayback.contains(.stamps) || protocolsForPlayback.contains(.counterparty)
        let needsCounterparty = protocolsForPlayback.contains(.counterparty)

        if needsStamps,
           stampViewModel.assets.isEmpty,
           !stampViewModel.isLoading,
           !downloadCoordinator.blocksCollectionFetch {
            await stampViewModel.fetchAssetsMetadata(for: wallets)
        }

        if needsCounterparty {
            counterpartyViewModel.applyStampExclusion(stampViewModel.stampCPIDs)
            if counterpartyViewModel.assets.isEmpty,
               !counterpartyViewModel.isLoading,
               !downloadCoordinator.blocksCollectionFetch {
                await counterpartyViewModel.fetchAssetsMetadata(for: wallets, excludingCPIDs: stampViewModel.stampCPIDs)
                counterpartyViewModel.applyStampExclusion(stampViewModel.stampCPIDs)
            }
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
