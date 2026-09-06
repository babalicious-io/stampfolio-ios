//
//  DownloadingAssetsOverlay.swift
//  StampFolio
//
//  Compact glass “Downloading Assets” popup with a theme-tinted progress bar.
//

import SwiftUI

/// Presented on MainTabView (first wallet) and SettingsView (extra wallet / Static GIF).
struct DownloadingAssetsOverlay: View {

    @Environment(AssetDownloadCoordinator.self) private var coordinator
    @Environment(\.appColorScheme) private var appColorScheme

    var body: some View {
        if coordinator.isPresented {
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Text("Downloading Assets")
                        .font(.headline)

                    if coordinator.isDeterminate {
                        ProgressView(
                            value: Double(coordinator.completedCount),
                            total: Double(max(coordinator.totalCount, 1))
                        )
                        .tint(appColorScheme.primary)
                    } else {
                        ProgressView()
                            .tint(appColorScheme.primary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: 280)
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Downloading Assets")
            .accessibilityValue(accessibilityProgress)
        }
    }

    private var accessibilityProgress: String {
        guard coordinator.isDeterminate else { return "Loading" }
        return "\(coordinator.completedCount) of \(coordinator.totalCount)"
    }
}
