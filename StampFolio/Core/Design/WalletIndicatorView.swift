//
//  WalletIndicatorView.swift
//  StampFolio
//
//  Wallet-color indicator icon shown on asset cards/rows (Stamp, Counterparty)
//

import SwiftUI

/// Small icon showing which wallet an asset belongs to, colored by the wallet's chosen color.
/// Supports the different presentation styles already used across card/row layouts.
struct WalletIndicatorView: View {

    /// Visual presentation of the indicator
    enum Style {
        /// Capsule background, used on grid cards
        case pill
        /// Circle background, used on Stamp and Counterparty row layouts
        case circleBackground
        /// No background
        case plain
    }

    let walletAddress: String?
    let wallets: [WalletConfig]
    var style: Style = .pill
    var accessibilityHint: String?

    private var walletColor: Color {
        wallets.first { $0.address == walletAddress }?.walletColor.color ?? .gray
    }

    var body: some View {
        Group {
            if let accessibilityHint {
                icon.accessibilityHint(accessibilityHint)
            } else {
                icon
            }
        }
        .accessibilityLabel("Wallet indicator")
    }

    @ViewBuilder
    private var icon: some View {
        switch style {
        case .pill:
            Image(systemName: "wallet.bifold.fill")
                .font(.caption)
                .fontWeight(.regular)
                .foregroundStyle(walletColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color(uiColor: .systemBackground).opacity(0.85))
                )

        case .circleBackground:
            Image(systemName: "wallet.bifold.fill")
                .font(.caption)
                .fontWeight(.regular)
                .foregroundStyle(walletColor)
                .padding(8)
                .background(
                    Circle()
                        .fill(Color(uiColor: .systemBackground).opacity(0.5))
                )

        case .plain:
            Image(systemName: "wallet.bifold.fill")
                .font(.caption2)
                .foregroundStyle(walletColor)
        }
    }
}
