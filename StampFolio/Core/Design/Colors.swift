//
//  Colors.swift
//  StampFolio
//
//  Design tokens extracted from Stampchain.io tailwind.config.ts
//

import SwiftUI

// MARK: - Stampchain Color Palette

extension Color {
    
    // MARK: - Background & Border
    
    /// Primary background color: #0d0a0d (near-black)
    static let stampchainBackground = Color(hex: "#0d0a0d")
    
    /// Border color: #292626
    static let stampchainBorder = Color(hex: "#292626")
    
    // MARK: - Purple Scale
    
    /// Purple dark: #43005c
    static let stampchainPurpleDark = Color(hex: "#43005c")
    
    /// Purple semidark: #610085
    static let stampchainPurpleSemidark = Color(hex: "#610085")
    
    /// Purple default: #7f00ad
    static let stampchainPurple = Color(hex: "#7f00ad")
    
    /// Purple semilight: #9d00d6
    static let stampchainPurpleSemilight = Color(hex: "#9d00d6")
    
    /// Purple light: #BB00FF
    static let stampchainPurpleLight = Color(hex: "#BB00FF")
    
    // MARK: - Orange Scale
    
    /// Orange dark: #5c2b00
    static let stampchainOrangeDark = Color(hex: "#5c2b00")
    
    /// Orange semidark: #853e00
    static let stampchainOrangeSemidark = Color(hex: "#853e00")
    
    /// Orange default: #ad5100
    static let stampchainOrange = Color(hex: "#ad5100")
    
    /// Orange semilight: #d66400
    static let stampchainOrangeSemilight = Color(hex: "#d66400")
    
    /// Orange light: #ff7700
    static let stampchainOrangeLight = Color(hex: "#ff7700")
    
    // MARK: - Grey Scale
    
    /// Grey dark: #585552
    static let stampchainGreyDark = Color(hex: "#585552")
    
    /// Grey semidark: #817e78
    static let stampchainGreySemidark = Color(hex: "#817e78")
    
    /// Grey default: #a8a39d
    static let stampchainGrey = Color(hex: "#a8a39d")
    
    /// Grey semilight: #d1cbc3
    static let stampchainGreySemilight = Color(hex: "#d1cbc3")
    
    /// Grey light (cream): #f9f2e9
    static let stampchainGreyLight = Color(hex: "#f9f2e9")
    
    // MARK: - Semantic Colors
    
    /// Success green: #00ad00
    static let stampchainSuccess = Color(hex: "#00ad00")
    
    /// Error red: #ad0000
    static let stampchainError = Color(hex: "#ad0000")
    
    /// Warning (using orange): #ad5100
    static let stampchainWarning = Color(hex: "#ad5100")
    
    // MARK: - Theme-Aware Colors
    
    /// Primary text color - adapts to color scheme
    static func primaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? stampchainGreyLight : stampchainGreyDark
    }
    
    /// Secondary text color - adapts to color scheme
    static func secondaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? stampchainGrey : stampchainGreySemidark
    }
    
    /// Background color - adapts to color scheme
    static func adaptiveBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? stampchainBackground : stampchainGreyLight
    }
    
    /// Card background tint - adapts to color scheme
    static func cardTint(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? stampchainPurpleDark.opacity(0.1) : stampchainGreySemilight.opacity(0.3)
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

// MARK: - Gradients

extension LinearGradient {
    
    /// Stampchain purple gradient (dark to light)
    static let stampchainPurple = LinearGradient(
        colors: [
            Color.stampchainPurpleDark,
            Color.stampchainPurple,
            Color.stampchainPurpleLight
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Stampchain orange gradient (dark to light)
    static let stampchainOrange = LinearGradient(
        colors: [
            Color.stampchainOrangeDark,
            Color.stampchainOrange,
            Color.stampchainOrangeLight
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Launch screen / background gradient
    static let stampchainBackground = LinearGradient(
        colors: [
            Color.stampchainBackground,
            Color.stampchainPurpleDark.opacity(0.3)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}
