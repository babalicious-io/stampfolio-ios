//
//  SetExtensions.swift
//  StampFolio
//
//  Shared helpers for Set-backed filter state (Stamp, Counterparty, Ordinals ViewModels)
//

import Foundation

extension Set where Element == String {

    /// Insert `value` if not present, remove it if present — the common "toggle a filter" pattern
    mutating func toggleMembership(of value: String) {
        if contains(value) {
            remove(value)
        } else {
            insert(value)
        }
    }
}
