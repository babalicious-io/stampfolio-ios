//
//  SettingsPresentationKey.swift
//  StampFolio
//
//  Environment key for presenting Settings modal
//

import SwiftUI

/// Environment key for Settings presentation
struct SettingsPresentationKey: EnvironmentKey {
    static let defaultValue = Binding<Bool>.constant(false)
}

extension EnvironmentValues {
    var showSettingsBinding: Binding<Bool> {
        get { self[SettingsPresentationKey.self] }
        set { self[SettingsPresentationKey.self] = newValue }
    }
}
