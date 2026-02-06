//
//  SettingsPresentationKey.swift
//  StampFolio
//
//  Environment key for presenting Settings modal
//

import SwiftUI

/// Environment key for Settings presentation
private struct SettingsPresentationKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var showSettings: () -> Void {
        get { self[SettingsPresentationKey.self] }
        set { self[SettingsPresentationKey.self] = newValue }
    }
}
