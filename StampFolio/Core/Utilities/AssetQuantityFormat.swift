//
//  AssetQuantityFormat.swift
//  StampFolio
//
//  Shared quantity formatting for stamp and Counterparty detail sheets
//

import Foundation

/// Formats asset quantities for display. Divisible assets use grouping separators
/// and 8 decimal places (the Counterparty protocol scale).
enum AssetQuantityFormat {

    /// Formats an already-normalized quantity (whole tokens, not satoshi-like units).
    static func string(from value: Double, divisible: Bool) -> String {
        string(from: NSDecimalNumber(value: value).decimalValue, divisible: divisible)
            ?? (divisible ? String(format: "%.8f", value) : String(format: "%.0f", value))
    }

    /// Formats a decimal string such as Counterparty `supply_normalized`.
    static func string(fromNormalized normalized: String, divisible: Bool) -> String {
        guard let decimal = Decimal(string: normalized) else { return normalized }
        return string(from: decimal, divisible: divisible) ?? normalized
    }

    /// Formats stamp raw units, converting satoshi-like values when the stamp is divisible.
    static func stamp(rawUnits: Double, divisible: Bool) -> String {
        let amount = divisible ? rawUnits / 100_000_000.0 : rawUnits
        return string(from: amount, divisible: divisible)
    }

    private static func string(from value: Decimal, divisible: Bool) -> String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        if divisible {
            formatter.usesGroupingSeparator = true
            formatter.minimumFractionDigits = 8
            formatter.maximumFractionDigits = 8
        } else {
            formatter.usesGroupingSeparator = false
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
        }
        return formatter.string(from: value as NSDecimalNumber)
    }
}
