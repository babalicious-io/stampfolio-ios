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
