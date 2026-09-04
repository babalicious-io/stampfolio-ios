//
//  CounterpartyAssetRowView.swift
//  StampFolio
//
//  Row view displaying a single Counterparty asset balance
//

import SwiftUI
import SwiftData

/// Row view displaying a Counterparty asset in the holdings list
struct CounterpartyAssetRowView: View {

    // MARK: - Properties

    let displayAsset: CounterpartyDisplay
    let onTap: () -> Void
    let onLongPress: () -> Void

    private var asset: CounterpartyAsset { displayAsset.asset }

    // MARK: - Environment

    @Query(sort: \WalletConfig.addedDate) private var wallets: [WalletConfig]

    // MARK: - State

    @AppStorage("showWalletIcons") private var showWalletIcons = false
    @State private var isPressed = false

    // MARK: - Body

    var body: some View {
        rowContent
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
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

    // MARK: - Row Content

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 16) {
            assetIcon
                .frame(
                    width: AssetRowMetrics.counterpartyPreviewSize.width,
                    height: AssetRowMetrics.counterpartyPreviewSize.height
                )
                .clipShape(RoundedRectangle(cornerRadius: AssetRowMetrics.previewCornerRadius))

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    Text(asset.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    AssetBalancePill(text: displayAsset.formattedBalance)
                }

                HStack(alignment: .center, spacing: 8) {
                    Text(issuerName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    if showsWalletIcon {
                        walletIcon
                    }
                }

                HStack(alignment: .center, spacing: 8) {
                    AssetStatusIconsView(
                        isLocked: asset.locked,
                        isDivisible: asset.divisible
                    )

                    Spacer(minLength: 4)

                    if let formattedFloorPrice {
                        AssetFloorPricePill(text: formattedFloorPrice)
                    }
                }
            }
        }
        .padding(6)
    }

    // MARK: - Asset Icon

    private var assetIcon: some View {
        CounterpartyAssetImageView(asset: asset, size: AssetRowMetrics.counterpartyPreviewSize)
    }

    // MARK: - Issuer Name

    private var issuerName: String {
        if let issuer = asset.issuer {
            return issuer.truncatedAddress(length: 6)
        }
        return asset.asset == "XCP" ? "Counterparty" : "No issuer"
    }

    // MARK: - Floor Price

    private var formattedFloorPrice: String? {
        asset.marketData?.formattedFloorPrice
    }

    private var showsWalletIcon: Bool {
        showWalletIcons && displayAsset.walletAddress != nil
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        var parts = [
            asset.displayName,
            issuerName,
            "Balance: \(displayAsset.formattedBalance)",
            asset.locked ? "Locked" : "Unlocked"
        ]
        if asset.divisible { parts.append("Divisible") }
        if let formattedFloorPrice {
            parts.append("Floor price: \(formattedFloorPrice)")
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Wallet Icon

    private var walletIcon: some View {
        WalletIndicatorView(
            walletAddress: displayAsset.walletAddress,
            wallets: wallets,
            style: .circleBackground,
            accessibilityHint: "Shows which wallet holds this asset"
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        CounterpartyAssetRowView(
            displayAsset: CounterpartyDisplay(asset: .sample, balance: 31_000_000, divisible: true),
            onTap: {},
            onLongPress: {}
        )
    }
    .padding()
}
