//
//  Typography.swift
//  StampFolio
//
//  Text styles with Dynamic Type support
//

import SwiftUI

// MARK: - Typography Styles

extension Font {
    
    // MARK: - Display
    
    /// Large title for stamp numbers in detail view
    static let stampTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    
    // MARK: - Headlines
    
    /// Section headers
    static let sectionHeader = Font.system(.headline, design: .default, weight: .semibold)
    
    /// Card title (stamp number on cards)
    static let cardTitle = Font.system(.subheadline, design: .rounded, weight: .medium)
    
    // MARK: - Body
    
    /// Primary body text
    static let bodyPrimary = Font.system(.body, design: .default, weight: .regular)
    
    /// Secondary body text
    static let bodySecondary = Font.system(.callout, design: .default, weight: .regular)
    
    // MARK: - Monospace (for addresses, hashes)
    
    /// Bitcoin addresses and transaction hashes
    static let monospace = Font.system(.footnote, design: .monospaced, weight: .regular)
    
    /// Smaller monospace for compact displays
    static let monospaceSm = Font.system(.caption, design: .monospaced, weight: .regular)
    
    // MARK: - Metadata
    
    /// Metadata labels in popups
    static let metadataLabel = Font.system(.caption, design: .default, weight: .semibold)
    
    /// Metadata values in popups
    static let metadataValue = Font.system(.caption, design: .default, weight: .regular)
}

// MARK: - Text Style Modifiers

extension View {
    
    /// Apply primary text styling with appropriate color
    /// - Parameter colorScheme: Current color scheme
    func primaryTextStyle(for colorScheme: ColorScheme) -> some View {
        self
            .font(.bodyPrimary)
            .foregroundStyle(Color.primaryText(for: colorScheme))
    }
    
    /// Apply secondary text styling with appropriate color
    /// - Parameter colorScheme: Current color scheme
    func secondaryTextStyle(for colorScheme: ColorScheme) -> some View {
        self
            .font(.bodySecondary)
            .foregroundStyle(Color.secondaryText(for: colorScheme))
    }
    
    /// Apply monospace text styling for addresses
    /// - Parameter colorScheme: Current color scheme
    func addressTextStyle(for colorScheme: ColorScheme) -> some View {
        self
            .font(.monospace)
            .foregroundStyle(Color.secondaryText(for: colorScheme))
    }
    
    /// Apply card title styling
    /// - Parameter colorScheme: Current color scheme
    func cardTitleStyle(for colorScheme: ColorScheme) -> some View {
        self
            .font(.cardTitle)
            .foregroundStyle(Color.primaryText(for: colorScheme))
    }
}

// MARK: - Text Truncation Helper

extension String {
    
    /// Truncate a Bitcoin address for display (e.g., "bc1q...jmv4")
    /// - Parameter length: Number of characters to show on each end (default: 4)
    func truncatedAddress(length: Int = 4) -> String {
        guard self.count > (length * 2 + 3) else { return self }
        let prefix = self.prefix(length)
        let suffix = self.suffix(length)
        return "\(prefix)...\(suffix)"
    }
    
    /// Truncate a hash for display
    func truncatedHash(length: Int = 8) -> String {
        guard self.count > length else { return self }
        return String(self.prefix(length)) + "..."
    }
}
