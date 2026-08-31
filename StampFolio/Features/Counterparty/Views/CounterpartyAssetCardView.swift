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

    let displayAsset: CounterpartyAssetDisplay
    let onTap: () -> Void
    let viewMode: ViewMode

    private var asset: CounterpartyAsset { displayAsset.asset }

    // MARK: - Environment

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
                onTap()
            }
            .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
                isPressed = pressing
            }, perform: {
                onTap()
            })
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(asset.displayName), Balance: \(displayAsset.formattedBalance)")
            .accessibilityHint("Tap for details")
            .accessibilityAddTraits(.isButton)
    }

    // MARK: - Card Content

    private var cardContent: some View {
        GeometryReader { geometry in
            ZStack {
                CounterpartyAssetImageView(asset: asset, size: geometry.size)
                    .frame(width: geometry.size.width, height: geometry.size.width)

                // Overlay: Wallet icon (top right), asset name (bottom left) and balance (bottom right)
                // Hidden in dense grid mode for cleaner appearance
                if viewMode != .denseGrid {
                    VStack {
                        if showWalletIcons, displayAsset.walletAddress != nil {
                            HStack {
                                Spacer()
                                walletIcon
                            }
                            .padding(8)
                        }

                        Spacer()

                        HStack(alignment: .bottom) {
                            assetNamePill

                            Spacer()

                            balancePill
                        }
                        .padding(8)
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
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
            .foregroundStyle(.primary)
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
        let wallet = wallets.first { $0.address == displayAsset.walletAddress }
        let walletColor = wallet?.walletColor.color ?? .gray

        return Image(systemName: "wallet.bifold.fill")
            .font(.caption)
            .fontWeight(.regular)
            .foregroundStyle(walletColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(uiColor: .systemBackground).opacity(0.85))
            )
            .accessibilityLabel("Wallet indicator")
    }
}

// MARK: - Preview

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
        CounterpartyAssetCardView(displayAsset: .sample, onTap: {}, viewMode: .normalGrid)
        CounterpartyAssetCardView(displayAsset: .sample, onTap: {}, viewMode: .normalGrid)
    }
    .padding()
}
