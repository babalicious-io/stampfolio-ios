//
//  CounterpartyAssetCardView.swift
//  StampFolio
//
//  Individual Counterparty asset card for the grid view
//

import SwiftUI
import SwiftData

/// Card view displaying a Counterparty asset in the holdings grid
struct CounterpartyAssetCardView: View {

    // MARK: - Properties

    let displayAsset: CounterpartyDisplay
    let onTap: () -> Void
    let onLongPress: () -> Void
    let viewMode: ViewMode

    private var asset: CounterpartyAsset { displayAsset.asset }

    // MARK: - Environment

    @Environment(\.appColorScheme) private var appColorScheme
    @Query(sort: \WalletConfig.addedDate) private var wallets: [WalletConfig]

    // MARK: - State

    @AppStorage("showWalletIcons") private var showWalletIcons = false
    @State private var isPressed = false

    // MARK: - Body

    var body: some View {
        cardContent
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()  // Show metadata sheet
            }
            .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
                isPressed = pressing
            }, perform: {
                onLongPress()  // Show fullscreen viewer
            })
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityDescription)
            .accessibilityHint("Tap for details, hold for fullscreen")
            .accessibilityAddTraits(.isButton)
    }

    // MARK: - Card Content

    private var cardContent: some View {
        GeometryReader { geometry in
            ZStack {
                CounterpartyAssetImageView(asset: asset, size: geometry.size)
                    .frame(width: geometry.size.width, height: geometry.size.height)

                // Overlay: asset name (top left), wallet icon (top right) and balance (bottom right)
                // Hidden in dense grid mode for cleaner appearance
                if viewMode != .denseGrid {
                    VStack {
                        HStack(alignment: .top) {
                            assetNamePill

                            Spacer()

                            if showWalletIcons, displayAsset.walletAddress != nil {
                                walletIcon
                            }
                        }
                        .padding(4)

                        Spacer()

                        HStack(alignment: .bottom) {
                            Spacer()

                            balancePill
                        }
                        .padding(4)
                    }
                }
            }
        }
        // Most Counterparty assets (unlike Stamps) use portrait "trading card" artwork rather
        // than square pixel art, so the tile itself is card-shaped; CounterpartyAssetImageView
        // still letterboxes anything that isn't exactly this ratio (e.g. square icons).
        .aspectRatio(5 / 7, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - Asset Name Pill

    private var assetNamePill: some View {
        Text(asset.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(uiColor: .systemBackground).opacity(0.85))
            )
            .accessibilityLabel(asset.displayName)
    }

    // MARK: - Balance Pill

    private var balancePill: some View {
        Text(displayAsset.formattedBalance)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(appColorScheme.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(uiColor: .systemBackground).opacity(0.85))
            )
            .accessibilityLabel("Balance: \(displayAsset.formattedBalance)")
    }

    // MARK: - Wallet Icon Pill

    private var walletIcon: some View {
        WalletIndicatorView(walletAddress: displayAsset.walletAddress, wallets: wallets, style: .pill)
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        var parts = [asset.displayName]
        if viewMode != .denseGrid {
            parts.append("Balance: \(displayAsset.formattedBalance)")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Preview

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
        CounterpartyAssetCardView(
            displayAsset: CounterpartyDisplay(asset: .sample, balance: 31_000_000, divisible: true),
            onTap: {},
            onLongPress: {},
            viewMode: .normalGrid
        )
        CounterpartyAssetCardView(
            displayAsset: CounterpartyDisplay(asset: .sample, balance: 31_000_000, divisible: true),
            onTap: {},
            onLongPress: {},
            viewMode: .normalGrid
        )
    }
    .padding()
}
