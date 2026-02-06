//
//  ProtocolType.swift
//  StampFolio
//
//  Protocol type definition for tab management
//

import Foundation

/// Protocol type for managing visible tabs and their order
enum ProtocolType: String, Identifiable, Codable, CaseIterable {
    case stamps = "Stamps"
    case ordinals = "Ordinals"
    case counterparty = "Counterparty"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .stamps: return "bitcoinsign.square.fill"
        case .ordinals: return "circle.hexagongrid.fill"
        case .counterparty: return "square.3.layers.3d"
        }
    }
    
    var storageKey: String {
        switch self {
        case .stamps: return "showStamps"
        case .ordinals: return "showOrdinals"
        case .counterparty: return "showCounterparty"
        }
    }
}
