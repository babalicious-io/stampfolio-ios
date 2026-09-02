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
    case ordinals = "Ordinals"
    case counterparty = "Counterparty"
    
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

    /// Default tab order when the user hasn't customized it
    static let defaultOrder: [ProtocolType] = [.ordinals, .counterparty, .stamps]

    /// Persisted protocol tab order, falling back to `defaultOrder`
    static func loadSavedOrder() -> [ProtocolType] {
        if let data = UserDefaults.standard.data(forKey: "protocolOrder"),
           let decoded = try? JSONDecoder().decode([ProtocolType].self, from: data) {
            return decoded
        }
        return defaultOrder
    }
}
