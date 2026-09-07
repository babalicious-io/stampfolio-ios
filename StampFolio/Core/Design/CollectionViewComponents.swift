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

/// Adaptive grid columns from available width, not device type or orientation.
/// Compact width uses a smaller tile minimum; regular width (iPad, Split View,
/// Plus/Max landscape) uses a larger one. `GridItem.adaptive` then fits as many
/// columns as the container allows, capped at 300pt so tiles do not grow huge.
func gridColumns(viewMode: ViewMode, horizontalSizeClass: UserInterfaceSizeClass?) -> [GridItem] {
    if viewMode == .list {
        return [GridItem(.flexible(), spacing: 16)]
    }

    let isRegularWidth = horizontalSizeClass == .regular
    let isCompactWidth = !isRegularWidth
    let minSize: CGFloat
    if isRegularWidth {
        minSize = viewMode == .denseGrid ? 130 : 180
    } else if isCompactWidth {
        minSize = viewMode == .denseGrid ? 110 : 170
    } else {
        minSize = viewMode == .denseGrid ? 110 : 170
    }

    return [GridItem(.adaptive(minimum: minSize, maximum: 300), spacing: 16)]
}

// MARK: - Asset Row Metrics

/// Shared Kingfisher downsample size for collection grid/row thumbnails (Stamps and Counterparty).
/// Overlay Static GIF prefetch should use this same size so processed cache keys match display.
enum CollectionImageThumbnail {
    static let size = CGSize(width: 200, height: 200)
}

/// Shared list-row sizing for Stamp and Counterparty previews and status glyphs
enum AssetRowMetrics {
    static let previewHeight: CGFloat = 72
    static let previewCornerRadius: CGFloat = 12
    static let stampPreviewSize = CGSize(width: previewHeight, height: previewHeight)
    /// Portrait trading-card ratio used by Counterparty tiles (width / height = 5 / 7)
    static let counterpartyPreviewSize = CGSize(
        width: previewHeight * 5 / 7,
        height: previewHeight
    )
    static let statusIconSize: CGFloat = 12
    /// Reserved width so ViewThatFits does not flop while market pills are still loading
    static let marketColumnMinWidth: CGFloat = 110
    /// Identity column bounds used only in the wide row candidate so long names
    /// cannot inflate ideal width, and portrait width typically stays compact.
    static let wideIdentityMinWidth: CGFloat = 180
    static let wideIdentityMaxWidth: CGFloat = 240
}

// MARK: - Asset Balance Pill

/// Compact balance chip used in the top-trailing corner of list rows
struct AssetBalancePill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(uiColor: .systemBackground).opacity(0.85))
            )
            .accessibilityLabel("Balance: \(text)")
    }
}

// MARK: - Asset Floor Price Pill

/// Orange floor-price chip; omit from the row when there is no price
struct AssetFloorPricePill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.orange)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(uiColor: .systemBackground).opacity(0.85))
            )
            .accessibilityLabel("Floor price: \(text)")
    }
}

// MARK: - Asset Holders Pill

/// Muted holder-count chip used in the wide list-row market column
struct AssetHoldersPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(uiColor: .systemBackground).opacity(0.85))
            )
            .accessibilityLabel(text)
    }
}

// MARK: - Asset Listings Pill

/// Open-dispenser count chip; omit from the row when the count is nil or zero
struct AssetListingsPill: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(uiColor: .systemBackground).opacity(0.85))
            )
            .accessibilityLabel("\(count) listing\(count == 1 ? "" : "s")")
    }
}

// MARK: - Asset Market Metrics Column

/// Center column shown by ViewThatFits when the list row is wide enough:
/// holders, listings, and floor price stacked to match the identity stack.
struct AssetMarketMetricsColumn: View {
    var holdersText: String?
    var listingsCount: Int?
    var floorPriceText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let holdersText {
                AssetHoldersPill(text: holdersText)
            }

            if let listingsCount, listingsCount > 0 {
                AssetListingsPill(count: listingsCount)
            }

            if let floorPriceText {
                AssetFloorPricePill(text: floorPriceText)
            }
        }
        .frame(minWidth: AssetRowMetrics.marketColumnMinWidth, alignment: .leading)
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

// MARK: - Fullscreen original reveal

/// Top-trailing control on immersive viewers. Visible when Static HTML Preview is on
/// and the current stamp is HTML or SVG. Toggles the cached snapshot versus live WebKit.
struct FullscreenOriginalRevealButton: View {
    @Binding var showOriginal: Bool

    var body: some View {
        Button {
            showOriginal.toggle()
        } label: {
            Image(systemName: showOriginal ? "eye.slash.fill" : "eye.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showOriginal ? "Show static HTML preview" : "Show original HTML")
        .accessibilityHint("Double tap to switch between the cached snapshot and live HTML")
        .padding(.top, 52)
        .padding(.trailing, 16)
    }
}
