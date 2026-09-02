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
            .accessibilityLabel("\(asset.displayName), Balance: \(displayAsset.formattedBalance)")
            .accessibilityHint("Tap for details, hold for fullscreen")
            .accessibilityAddTraits(.isButton)
    }

    // MARK: - Row Content

    private var rowContent: some View {
        HStack(spacing: 16) {
            assetIcon
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(asset.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(issuerLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                badgesRow
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(displayAsset.formattedBalance)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                if showWalletIcons, displayAsset.walletAddress != nil {
                    walletIcon
                }
            }
        }
        .padding(12)
    }

    // MARK: - Asset Icon

    private var assetIcon: some View {
        CounterpartyAssetImageView(asset: asset, size: CGSize(width: 48, height: 48))
            .clipShape(Circle())
    }

    // MARK: - Issuer Label

    private var issuerLabel: String {
        if let issuer = asset.issuer {
            return "Issued by \(issuer.truncatedAddress(prefixLength: 6, suffixLength: 6))"
        }
        return asset.asset == "XCP" ? "Counterparty protocol currency" : "No issuer"
    }

    // MARK: - Badges

    private var badgesRow: some View {
        HStack(spacing: 6) {
            if asset.locked {
                badge(text: "Locked", systemImage: "lock.fill")
            }
            if asset.divisible {
                badge(text: "Divisible", systemImage: "divide")
            }
        }
    }

    private func badge(text: String, systemImage: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: systemImage)
                .font(.system(size: 8))
            Text(text)
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(Color(uiColor: .systemBackground).opacity(0.6))
        )
    }

    // MARK: - Wallet Icon

    private var walletIcon: some View {
        let wallet = wallets.first { $0.address == displayAsset.walletAddress }
        let walletColor = wallet?.walletColor.color ?? .gray

        return Image(systemName: "wallet.bifold.fill")
            .font(.caption2)
            .foregroundStyle(walletColor)
            .accessibilityLabel("Wallet indicator")
            .accessibilityHint("Shows which wallet holds this asset")
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
