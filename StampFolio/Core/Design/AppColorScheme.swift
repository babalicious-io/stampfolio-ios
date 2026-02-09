//
//  AppColorScheme.swift
//  StampFolio
//
//  User-selectable app-wide color schemes
//

import SwiftUI

/// App-wide color scheme options that replace the default orange accent color
enum AppColorScheme: String, CaseIterable, Identifiable, Codable {
    case satoshiOrange
    case kevinPurple
    case pepeGreen
    
    var id: Self { self }
    
    var displayName: String {
        switch self {
        case .satoshiOrange: return "Satoshi Orange"
        case .kevinPurple: return "Kevin Purple"
        case .pepeGreen: return "Pepe Green"
        }
    }
    
    var primaryColor: Color {
        switch self {
        case .satoshiOrange:
            return .orange
        case .kevinPurple:
            return Color(red: 0.58, green: 0.4, blue: 0.8)
        case .pepeGreen:
            return Color(red: 0.5, green: 0.8, blue: 0.4)
        }
    }
    
    var secondaryColor: Color {
        primaryColor.opacity(0.7)
    }
    
    /// Gradient from bottom-left (primary) to top-right (secondary)
    var gradient: LinearGradient {
        LinearGradient(
            colors: [primaryColor, secondaryColor],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    }
}

// MARK: - Environment Key

private struct AppColorSchemeKey: EnvironmentKey {
    static let defaultValue: AppColorScheme = .satoshiOrange
}

extension EnvironmentValues {
    var appColorScheme: AppColorScheme {
        get { self[AppColorSchemeKey.self] }
        set { self[AppColorSchemeKey.self] = newValue }
    }
}
