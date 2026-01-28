//
//  Colors.swift
//  StampFolio
//
//  Simplified color system with private base colors and theme-aware functions
//

import SwiftUI

// MARK: - Color Palette

extension Color {
    
    // MARK: - Private Base Colors
    
    /// Private purple accent color
    private static let _accent = Color(hex: "#7f00ad")
    
    /// Private light purple accent color
    private static let _accentLight = Color(hex: "#BB00FF")
    
    /// Private dark mode background color
    private static let _background = Color(hex: "#0d0a0d")
    
    /// Private light mode background color
    private static let _backgroundLight = Color(hex: "#f9f2e9")
    
    /// Private surface color (for card tints)
    private static let _surface = Color(hex: "#d1cbc3")
    
    /// Private light mode primary text color
    private static let _textPrimary = Color(hex: "#585552")
    
    /// Private dark mode secondary text color
    private static let _textSecondary = Color(hex: "#a8a39d")
    
    /// Private light mode secondary text color
    private static let _textSecondaryLight = Color(hex: "#817e78")
    
    // MARK: - Public Accent Properties
    
    /// Primary brand color (purple) - consistent across themes
    static var accent: Color { _accent }
    
    /// Light purple for highlights and icons - consistent across themes
    static var accentLight: Color { _accentLight }
    
    // MARK: - Public Semantic Colors
    
    /// Success state (green)
    static let success = Color(hex: "#00ad00")
    
    /// Error state (red)
    static let error = Color(hex: "#ad0000")
    
    /// Warning state (orange)
    static let warning = Color(hex: "#ad5100")
    
    // MARK: - Public Theme-Aware Functions
    
    /// Primary text color - adapts to color scheme
    static func primaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? _backgroundLight : _textPrimary
    }
    
    /// Secondary text color - adapts to color scheme
    static func secondaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? _textSecondary : _textSecondaryLight
    }
    
    /// Background color - adapts to color scheme
    static func adaptiveBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? _background : _backgroundLight
    }
    
    /// Card background tint - adapts to color scheme
    static func cardTint(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? _accent.opacity(0.1) : _surface.opacity(0.3)
    }
}

// MARK: - Hex Color Initializer

extension Color {
    
    /// Initialize a Color from a hex string (e.g., "#FF0000" or "FF0000")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
