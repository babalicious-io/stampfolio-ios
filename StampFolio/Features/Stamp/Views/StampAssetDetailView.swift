//
//  StampAssetDetailView.swift
//  StampFolio
//
//  Metadata popup showing stamp details
//

import SwiftUI

/// Popup displaying stamp metadata details
struct StampAssetDetailView: View {

    // MARK: - Properties

    let displayAsset: StampDisplay
    let viewModel: StampViewModel

    // Get current stamp from viewModel (updates when market data fetched)
    private var currentDisplayAsset: StampDisplay {
        viewModel.assets.first(where: { $0.id == displayAsset.id }) ?? displayAsset
    }

    // Convenience accessor for the underlying stamp (always use current data)
    private var asset: StampAsset { currentDisplayAsset.asset }

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.appColorScheme) private var appColorScheme

    @State private var htmlTitle: String?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                Section {
                    stampIdentificationSection
                }

                Section {
                    stampImageHeader
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section {
                    identityContent
                }

                Section {
                    statusContent
                }

                Section {
                    fileInformationContent
                }

                if showsMarketSection {
                    Section {
                        marketContent
                    }
                }

                Section {
                    blockchainInformationContent
                }

                Section {
                    stampchainLinkButton
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
            async let market: Void = viewModel.fetchMarketDataIfNeeded(for: displayAsset)
            async let title: Void = loadHTMLTitleIfNeeded()
            _ = await (market, title)
        }
    }

    // MARK: - Header

    /// HTML title when present; otherwise named (posh) CPID; otherwise stamp number.
    private var headerTitle: String {
        if let htmlTitle { return htmlTitle }
        if asset.isPosh { return asset.counterpartyId }
        return "#\(asset.stampId)"
    }

    private var stampIdentificationSection: some View {
        HStack(alignment: .center) {
            Text(headerTitle)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)

            Spacer()

            Image(systemName: ProtocolType.stamps.icon)
                .font(.title2)
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(asset.stampType.capitalized) stamp")
        }
        .padding(.vertical, 4)
    }
        .padding(.vertical, 4)
    }

    // MARK: - Image

    private var stampImageHeader: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GeometryReader { geometry in
                    StampAssetImageView(asset: asset, size: geometry.size)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
            .padding(.vertical, 8)
    }

    // MARK: - Identity

    @ViewBuilder
    private var identityContent: some View {
        if let htmlTitle {
            MetadataRow(label: "Title", value: htmlTitle)
        }

        if asset.isPosh {
            MetadataRow(label: "Stamp", value: "#\(asset.stampId)")
        } else {
            MetadataRow(
                label: "CPID",
                value: asset.counterpartyId,
                fullValue: asset.counterpartyId,
                truncatesValue: true
            )
        }

        if let creatorName = asset.creatorName, !creatorName.isEmpty {
            MetadataRow(label: "Artist", value: creatorName)
            MetadataRow(
                label: "Addy",
                value: asset.creatorAddy.truncatedAddress(prefixLength: 8, suffixLength: 8),
                fullValue: asset.creatorAddy
            )
        } else {
            MetadataRow(
                label: "Creator",
                value: asset.creatorAddy.truncatedAddress(prefixLength: 8, suffixLength: 8),
                fullValue: asset.creatorAddy
            )
        }

        MetadataRow(label: "Editions", value: asset.formattedEditions)

        MetadataRow(label: "Balance", value: currentDisplayAsset.formattedDetailBalance)
    }

    // MARK: - Status

    @ViewBuilder
    private var statusContent: some View {
        MetadataRow(label: "Locked", value: yesNo(asset.isLocked))
        MetadataRow(label: "Keyburn", value: yesNo(asset.isKeyburned))
        MetadataRow(label: "Divisible", value: yesNo(asset.divisible))
    }

    // MARK: - File

    @ViewBuilder
    private var fileInformationContent: some View {
        MetadataRow(
            label: "File Type",
            value: asset.fileType.map { $0.isEmpty ? "N/A" : $0 } ?? "N/A"
        )
        MetadataRow(
            label: "File Size",
            value: (asset.fileSize.map { $0 > 0 } == true) ? (asset.formattedFileSize ?? "N/A") : "N/A"
        )
    }

    // MARK: - Market

    private var showsMarketSection: Bool {
        if currentDisplayAsset.isLoadingMarketData { return true }
        guard let marketData = currentDisplayAsset.marketData else { return false }
        return marketData.holderCount != nil
            || marketData.formattedFloorPrice != nil
            || (marketData.openDispensersCount ?? 0) > 0
    }

    @ViewBuilder
    private var marketContent: some View {
        if let marketData = currentDisplayAsset.marketData {
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

    // MARK: - Blockchain

    @ViewBuilder
    private var blockchainInformationContent: some View {
        if let blockTime = asset.blockTime {
            MetadataRow(
                label: "Date",
                value: blockTime.formatted(date: .abbreviated, time: .shortened)
            )
        }
        if let blockIndex = asset.blockIndex {
            MetadataRow(label: "Block", value: "#\(blockIndex)")
        }
        MetadataRow(
            label: "Tx Hash",
            value: asset.txHash.prefix(8) + "..." + asset.txHash.suffix(8),
            fullValue: asset.txHash
        )
    }

    // MARK: - Stampchain Link Button

    private var stampchainLinkButton: some View {
        Button {
            openURL(asset.stampchainURL)
        } label: {
            HStack {
                Text("View on Stampchain.io")
                    .fontWeight(.medium)

                Image(systemName: "arrow.up.right.square")
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular.tint(appColorScheme.primary).interactive(), in: .capsule)
        }
        .tint(.secondary)
        .accessibilityLabel("View stamp on Stampchain website")
        .accessibilityHint("Opens Safari to the stamp detail page")
    }

    // MARK: - Helpers

    private func yesNo(_ value: Bool) -> String {
        value ? "Yes" : "No"
    }

    /// Reads a cached HTML title, or fetches HTML, stores it, and persists the parsed title.
    private func loadHTMLTitleIfNeeded() async {
        guard asset.isHTML, let url = asset.imageURL else { return }
        let cache = StampContentCache.shared

        if let title = await cache.readTitle(for: url) {
            htmlTitle = title
            return
        }

        guard let html = await fetchHTML(from: url) else { return }
        await cache.write(html, for: url)
        htmlTitle = await cache.readTitle(for: url)
    }

    private func fetchHTML(from url: URL) async -> String? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}

// MARK: - Preview

#Preview {
    StampAssetDetailView(displayAsset: StampDisplay(from: StampAsset.sample), viewModel: StampViewModel())
        .presentationDetents([.medium, .large])
}
