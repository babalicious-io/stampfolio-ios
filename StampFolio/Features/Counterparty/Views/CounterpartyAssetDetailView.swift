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

    let displayAsset: CounterpartyAssetDisplay
    let viewModel: CounterpartyViewModel

    // Get current asset from viewModel (updates when detail data is fetched)
    private var currentDisplayAsset: CounterpartyAssetDisplay {
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
                    assetImageHeader
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section {
                    identificationSection
                }

                Section {
                    holdingContent
                }

                Section {
                    marketContent
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
            .navigationTitle("Asset Details")
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
            await viewModel.fetchAssetDetailIfNeeded(for: displayAsset)
        }
    }

    // MARK: - Asset Image Header

    private var assetImageHeader: some View {
        CounterpartyAssetImageView(asset: asset, size: CGSize(width: 400, height: 220))
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
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

            VStack(alignment: .trailing, spacing: 6) {
                if asset.locked {
                    Text("Locked")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(appColorScheme.primary.opacity(0.8))
                        .clipShape(Capsule())
                }

                Text(asset.divisible ? "Divisible" : "Non-divisible")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Holding Content

    @ViewBuilder
    private var holdingContent: some View {
        MetadataRow(label: "Balance", value: currentDisplayAsset.formattedBalance)

        MetadataRow(label: "Supply", value: asset.formattedSupply)

        if let issuer = asset.issuer {
            MetadataRow(
                label: "Issuer",
                value: issuer.truncatedAddress(prefixLength: 6, suffixLength: 6),
                fullValue: issuer
            )
        }

        if let owner = asset.owner, owner != asset.issuer {
            MetadataRow(
                label: "Owner",
                value: owner.truncatedAddress(prefixLength: 6, suffixLength: 6),
                fullValue: owner
            )
        }

        if let date = asset.firstIssuanceDate {
            MetadataRow(label: "Issued", value: date.formatted(date: .abbreviated, time: .omitted))
        }
    }

    // MARK: - Market Content

    @ViewBuilder
    private var marketContent: some View {
        if let marketData = asset.marketData {
            if let holders = marketData.formattedHolderCount {
                MetadataRow(label: "Holders", value: holders)
            }
            if let floorPrice = marketData.formattedFloorPrice {
                MetadataRow(label: "Floor Price", value: floorPrice)
            }
            if let dispensers = marketData.openDispensersCount, dispensers > 0 {
                MetadataRow(label: "Listings", value: "\(dispensers)")
            }
        } else if currentDisplayAsset.isLoadingDetail {
            HStack {
                Text("Market Data")
                    .font(.callout)
                    .fontWeight(.light)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .frame(width: 100, alignment: .leading)

                ProgressView()
                    .controlSize(.small)

                Spacer()
            }
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
                Text("View on XChain.io")
                    .fontWeight(.medium)

                Image(systemName: "arrow.up.right.square")
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular.tint(appColorScheme.primary).interactive(), in: .capsule)
        }
        .tint(.secondary)
        .accessibilityLabel("View asset on XChain.io")
        .accessibilityHint("Opens Safari to the asset detail page")
    }
}

// MARK: - Preview

#Preview {
    CounterpartyAssetDetailView(displayAsset: .sample, viewModel: CounterpartyViewModel())
        .presentationDetents([.medium, .large])
}
