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
                    .contentShape(Rectangle())

                VStack(spacing: 16) {
                    Text("Downloading Assets")
                        .font(.headline)

                    ProgressView(value: displayedProgress)
                        .tint(appColorScheme.primary)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: 280)
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
            }
            .allowsHitTesting(true)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Downloading Assets")
            .accessibilityValue(accessibilityProgress)
        }
    }

    /// Floor at 1% so the bar is visible before totals exist and while completed is still 0.
    private var displayedProgress: Double {
        guard coordinator.totalCount > 0 else { return 0.01 }
        let fraction = Double(coordinator.completedCount) / Double(coordinator.totalCount)
        return min(1, max(0.01, fraction))
    }

    private var accessibilityProgress: String {
        guard coordinator.totalCount > 0 else { return "1 percent" }
        return "\(coordinator.completedCount) of \(coordinator.totalCount)"
    }
}
