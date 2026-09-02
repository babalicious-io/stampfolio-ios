//
//  ViewMode.swift
//  StampFolio
//
//  Shared grid/list display mode for collection views (Stamp, Counterparty, Ordinals)
//

import Foundation

/// View mode for displaying asset collections
enum ViewMode: String, Codable {
    case normalGrid = "normal_grid"
    case denseGrid = "dense_grid"
    case list = "list"
}
