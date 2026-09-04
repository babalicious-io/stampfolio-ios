//
//  CollectionViewComponents.swift
//  StampFolio
//
//  Shared collection-view chrome reused by Stamp, Counterparty, and Ordinals:
//  view-mode and settings toolbar buttons, offline banner, loading state, grid
//  column sizing, and list-row preview/status/balance components.
//

import SwiftUI

// MARK: - View Mode Toolbar Item

/// Leading toolbar control: tap cycles layouts; long press opens a menu to jump to one.
struct ViewModeToolbarItem: ToolbarContent {

    @Binding var viewMode: ViewMode

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            ViewModeMenuButton(viewMode: $viewMode)
        }
    }
}

private struct ViewModeMenuButton: View {

    @Binding var viewMode: ViewMode

    var body: some View {
        Menu {
            Section("VIEW") {
                ForEach(ViewMode.allCases) { mode in
                    Button {
                        viewMode = mode
                    } label: {
                        Label(mode.title, systemImage: mode == viewMode ? mode.icon : mode.outlineIcon)
                    }
                }
            }
        } label: {
            Image(systemName: viewMode.icon)
                .font(.system(size: 16))
                .foregroundStyle(.primary)
        } primaryAction: {
            viewMode = viewMode.next
        }
        .tint(.primary)
        .buttonStyle(.plain)
        .accessibilityLabel("View mode")
        .accessibilityValue(viewMode.accessibilityValue)
        .accessibilityHint("Tap to cycle through view modes. Long press to choose a view.")
    }
}

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

// MARK: - Asset Row Metrics

/// Shared list-row sizing for Stamp and Counterparty previews and status glyphs
enum AssetRowMetrics {
    static let previewHeight: CGFloat = 64
    static let previewCornerRadius: CGFloat = 12
    static let stampPreviewSize = CGSize(width: previewHeight, height: previewHeight)
    /// Portrait trading-card ratio used by Counterparty tiles (width / height = 5 / 7)
    static let counterpartyPreviewSize = CGSize(
        width: previewHeight * 5 / 7,
        height: previewHeight
    )
    /// Previous row badges used 8pt icons; status glyphs are 2pt larger
    static let statusIconSize: CGFloat = 10
}

// MARK: - Asset Balance Pill

/// Compact balance chip used in the top-trailing corner of list rows
struct AssetBalancePill: View {
    let text: String

    @Environment(\.appColorScheme) private var appColorScheme

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(appColorScheme.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(uiColor: .systemBackground).opacity(0.85))
            )
            .accessibilityLabel("Balance: \(text)")
    }
}

// MARK: - Asset Status Icons

/// Lock, optional divisible, and optional keyburn glyphs for list rows
struct AssetStatusIconsView: View {
    let isLocked: Bool
    let isDivisible: Bool
    var isKeyburned: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            statusIcon(
                systemName: isLocked ? "lock.fill" : "lock.open.fill",
                label: isLocked ? "Locked" : "Unlocked"
            )

            if isDivisible {
                statusIcon(systemName: "divide", label: "Divisible")
            }

            if isKeyburned {
                statusIcon(systemName: "flame.fill", label: "Keyburn")
            }
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

    private func statusIcon(systemName: String, label: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: AssetRowMetrics.statusIconSize))
            .accessibilityLabel(label)
    }
}
