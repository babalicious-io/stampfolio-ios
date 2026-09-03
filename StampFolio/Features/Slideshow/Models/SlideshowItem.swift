//
//  SlideshowItem.swift
//  StampFolio
//
//  Mixed-protocol slide for the collection slideshow
//

import Foundation

/// A single slideshow page, wrapping a protocol-specific asset
enum SlideshowItem: Identifiable, Hashable {
    case stamp(StampAsset)
    case counterparty(CounterpartyAsset)

    var id: String {
        switch self {
        case .stamp(let asset):
            return "stamp-\(asset.stampId)"
        case .counterparty(let asset):
            return "counterparty-\(asset.id)"
        }
    }

    var accessibilityName: String {
        switch self {
        case .stamp(let asset):
            return asset.formattedStampId
        case .counterparty(let asset):
            return asset.displayName
        }
    }
}

/// A Play Now session. Identifiable so `fullScreenCover(item:)` can present from the
/// collection view (the same place long-press fullscreen is presented).
struct SlideshowPlaylist: Identifiable {
    let id: UUID
    let items: [SlideshowItem]

    init(items: [SlideshowItem]) {
        self.id = UUID()
        self.items = items
    }

    var stampAssets: [StampAsset] {
        items.compactMap { item in
            if case .stamp(let asset) = item { return asset }
            return nil
        }
    }

    var counterpartyAssets: [CounterpartyAsset] {
        items.compactMap { item in
            if case .counterparty(let asset) = item { return asset }
            return nil
        }
    }

    var isStampsOnly: Bool {
        !stampAssets.isEmpty && counterpartyAssets.isEmpty
    }

    var isCounterpartyOnly: Bool {
        !counterpartyAssets.isEmpty && stampAssets.isEmpty
    }
}
