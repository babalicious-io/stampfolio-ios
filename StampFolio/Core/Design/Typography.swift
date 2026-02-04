//
//  Typography.swift
//  StampFolio
//
//  Text utilities for Bitcoin addresses and hashes
//

import SwiftUI

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
    func truncatedHash(length: Int = 6) -> String {
        guard self.count > length else { return self }
        return String(self.prefix(length)) + "..."
    }
}
