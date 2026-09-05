//
//  CounterpartyAssetDetailView.swift
//  StampFolio
//
//  Detail sheet showing full information for a Counterparty asset
//

import SwiftUI

/// Sheet displaying detailed metadata for a single Counterparty asset
struct CounterpartyAssetDetailView: View {

    // MARK: - Properties

    let displayAsset: CounterpartyDisplay
    let viewModel: CounterpartyViewModel

    // Get current asset from viewModel (updates when detail data is fetched)
    private var currentDisplayAsset: CounterpartyDisplay {
        viewModel.assets.first(where: { $0.id == displayAsset.id }) ?? displayAsset
    }

    private var asset: CounterpartyAsset { currentDisplayAsset.asset }

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.appColorScheme) private var appColorScheme

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                Section {
                    identificationSection
                }

                Section {
                    assetImageHeader
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section {
                    holdingContent
                }

                Section {
                    statusContent
                }

                if showsMarketSection {
                    Section {
                        marketContent
                    }
                }

                if showsChainSection {
                    Section {
                        chainContent
                    }
                }

                if let description = asset.description, !description.isEmpty {
                    Section {
                        descriptionContent(description)
                    }
                }

                Section {
                    explorerLinkButton
                }
            }
            .listSectionSpacing(16)
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
        }
        .tint(.primary)
        .task {
            await viewModel.fetchMarketDataIfNeeded(for: displayAsset)
        }
    }

    // MARK: - Identification Section

    private var identificationSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(asset.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)

                if asset.isSubasset {
                    Text(asset.asset)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            Spacer()

            Text("counterparty")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(appColorScheme.primary.opacity(0.8))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }

    // MARK: - Asset Image Header

    private var assetImageHeader: some View {
        Color.clear
            .aspectRatio(5 / 7, contentMode: .fit)
            .overlay {
                GeometryReader { geometry in
                    CounterpartyAssetImageView(asset: asset, size: geometry.size)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
            .padding(.vertical, 8)
    }

    // MARK: - Holding Content

    @ViewBuilder
    private var holdingContent: some View {
        if let issuer = asset.issuer {
            MetadataRow(
                label: "Issuer",
                value: issuer.truncatedAddress(prefixLength: 8, suffixLength: 8),
                fullValue: issuer
            )
        }

        if let owner = asset.owner, owner != asset.issuer {
            MetadataRow(
                label: "Owner",
                value: owner.truncatedAddress(prefixLength: 8, suffixLength: 8),
                fullValue: owner
            )
        }

        MetadataRow(label: "Supply", value: asset.formattedSupply)

        MetadataRow(label: "Balance", value: currentDisplayAsset.formattedDetailBalance)
    }

    // MARK: - Status

    @ViewBuilder
    private var statusContent: some View {
        MetadataRow(label: "Locked", value: yesNo(asset.locked))
        MetadataRow(label: "Divisible", value: yesNo(asset.divisible))
    }

    // MARK: - Market Content

    private var showsMarketSection: Bool {
        if currentDisplayAsset.isLoadingMarketData { return true }
        guard let marketData = asset.marketData else { return false }
        return marketData.holderCount != nil
            || marketData.formattedFloorPrice != nil
            || (marketData.openDispensersCount ?? 0) > 0
    }

    @ViewBuilder
    private var marketContent: some View {
        if let marketData = asset.marketData {
            if let holderCount = marketData.holderCount {
                MetadataRow(label: "Holders", value: "\(holderCount)")
            }
            if let dispensers = marketData.openDispensersCount, dispensers > 0 {
                MetadataRow(label: "Listings", value: "\(dispensers)")
            }
            if let floorPrice = marketData.formattedFloorPrice {
                MetadataRow(label: "Price", value: floorPrice)
            }
        } else if currentDisplayAsset.isLoadingMarketData {
            MetadataLoadingRow()
        }
    }

    // MARK: - Chain Content

    private var showsChainSection: Bool {
        asset.firstIssuanceDate != nil
            || asset.firstIssuanceBlockIndex != nil
            || asset.firstIssuanceTxHash != nil
    }

    @ViewBuilder
    private var chainContent: some View {
        if let date = asset.firstIssuanceDate {
            MetadataRow(
                label: "Issued",
                value: date.formatted(date: .abbreviated, time: .shortened)
            )
        }

        if let reissuedDate = asset.lastIssuanceDate,
           asset.lastIssuanceBlockTime != asset.firstIssuanceBlockTime {
            MetadataRow(
                label: "Reissued",
                value: reissuedDate.formatted(date: .abbreviated, time: .shortened)
            )
        }

        if let blockIndex = asset.firstIssuanceBlockIndex {
            MetadataRow(label: "Block", value: "#\(blockIndex)")
        }

        if let txHash = asset.firstIssuanceTxHash, !txHash.isEmpty {
            MetadataRow(
                label: "Tx Hash",
                value: txHash.prefix(8) + "..." + txHash.suffix(8),
                fullValue: txHash
            )
        }
    }

    // MARK: - Description Content

    private func descriptionContent(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.callout)
                .fontWeight(.light)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(description)
                .font(.callout)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Explorer Link Button

    private var explorerLinkButton: some View {
        Button {
            if let url = asset.explorerURL {
                openURL(url)
            }
        } label: {
            HStack {
                Text("View on Horizon Market")
                    .fontWeight(.medium)

                Image(systemName: "arrow.up.right.square")
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular.tint(appColorScheme.primary).interactive(), in: .capsule)
        }
        .tint(.secondary)
        .accessibilityLabel("View asset on Horizon Market")
        .accessibilityHint("Opens Safari to the asset page on Horizon Market")
    }

    // MARK: - Helpers

    private func yesNo(_ value: Bool) -> String {
        value ? "Yes" : "No"
    }
}

// MARK: - Preview

#Preview {
    CounterpartyAssetDetailView(
        displayAsset: CounterpartyDisplay(asset: .sample, balance: 31_000_000, divisible: true),
        viewModel: CounterpartyViewModel()
    )
    .presentationDetents([.medium, .large])
}
