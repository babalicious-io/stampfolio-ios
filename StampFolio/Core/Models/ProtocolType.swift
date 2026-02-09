//
//  ProtocolType.swift
//  StampFolio
//
//  Protocol type definition for tab management
//

import Foundation

extension Notification.Name {
    static let protocolOrderDidChange = Notification.Name("protocolOrderDidChange")
}

/// Protocol type for managing visible tabs and their order
enum ProtocolType: String, Identifiable, Codable, CaseIterable, Hashable {
    case stamps = "Stamps"
    case ordinals = "Tokens"
    case counterparty = "Marketplace"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .stamps: return "bitcoinsign.square.fill"
        case .ordinals: return "bitcoinsign.circle.fill"
        case .counterparty: return "xmark.triangle.circle.square.fill"
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
