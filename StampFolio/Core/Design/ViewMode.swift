//
//  ViewMode.swift
//  StampFolio
//
//  Shared grid/list display mode for collection views (Stamp, Counterparty, Ordinals)
//

import Foundation

/// View mode for displaying asset collections
enum ViewMode: String, Codable, CaseIterable, Identifiable {
    case normalGrid = "normal_grid"
    case denseGrid = "dense_grid"
    case list = "list"

    var id: String { rawValue }

    /// Shared AppStorage key so grid/list mode persists across protocol tabs
    static let storageKey = "collectionViewMode"

    /// Filled SF Symbol for the current layout (toolbar and selected menu row)
    var icon: String {
        switch self {
        case .normalGrid:
            return "square.grid.2x2.fill"
        case .denseGrid:
            return "square.grid.3x3.fill"
        case .list:
            return "rectangle.grid.1x3.fill"
        }
    }

    /// Outline SF Symbol for unselected menu rows
    var outlineIcon: String {
        switch self {
        case .normalGrid:
            return "square.grid.2x2"
        case .denseGrid:
            return "square.grid.3x3"
        case .list:
            return "rectangle.grid.1x3"
        }
    }

    /// Menu and accessibility title
    var title: String {
        switch self {
        case .normalGrid:
            return "Large Grid"
        case .denseGrid:
            return "Small Grid"
        case .list:
            return "Rows"
        }
    }

    var accessibilityValue: String { title }

    /// Next mode in the tap-to-cycle sequence: large grid → small grid → rows
    var next: ViewMode {
        switch self {
        case .normalGrid:
            return .denseGrid
        case .denseGrid:
            return .list
        case .list:
            return .normalGrid
        }
    }
}
