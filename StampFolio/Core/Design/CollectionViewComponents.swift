//
//  CollectionViewComponents.swift
//  StampFolio
//
//  Shared collection-view chrome reused by Stamp, Counterparty, and Ordinals:
//  the settings toolbar button, offline banner, loading state, and grid column sizing.
//

import SwiftUI

// MARK: - Settings Toolbar Item

/// Toolbar button that opens the Settings sheet via `\.showSettingsBinding`.
/// Reads the binding from the environment, so it takes no parameters.
struct SettingsToolbarItem: ToolbarContent {
    @Environment(\.showSettingsBinding) private var showSettings

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showSettings.wrappedValue = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
            .accessibilityHint("Open app settings")
        }
    }
}

// MARK: - Offline Banner

/// Banner shown at the top of a collection scroll view when the device is offline
struct OfflineBannerView: View {
    @Environment(\.appColorScheme) private var appColorScheme

    var body: some View {
        HStack {
            Image(systemName: "wifi.slash")
            Text("You're offline. Showing cached content.")
        }
        .font(.caption)
        .foregroundStyle(.primary)
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .glassEffect(.regular.tint(appColorScheme.primary).interactive(), in: .rect(cornerRadius: 8))
        .padding()
    }
}

// MARK: - Loading View

/// Centered progress indicator shown while a collection's first fetch is in flight
struct CollectionLoadingView: View {
    @Environment(\.appColorScheme) private var appColorScheme

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1)
                .tint(appColorScheme.primary)
        }
    }
}

// MARK: - Grid Columns

/// Dynamic grid columns using native adaptive sizing with device awareness.
/// iPhone: 2 columns (normal) / 3 columns (dense). iPad: 3-4 columns (normal) / 4-5 columns (dense).
func gridColumns(viewMode: ViewMode, horizontalSizeClass: UserInterfaceSizeClass?) -> [GridItem] {
    if viewMode == .list {
        return [GridItem(.flexible(), spacing: 16)]
    }

    let isIPad = horizontalSizeClass == .regular
    let minSize: CGFloat
    if isIPad {
        minSize = viewMode == .denseGrid ? 130 : 180
    } else {
        minSize = viewMode == .denseGrid ? 110 : 170
    }

    return [GridItem(.adaptive(minimum: minSize, maximum: 300), spacing: 16)]
}
