//
//  StampMetadataPopup.swift
//  StampFolio
//
//  Metadata popup showing stamp details
//

import SwiftUI

/// Popup displaying stamp metadata details
struct StampMetadataPopup: View {
    
    // MARK: - Properties
    
    let displayStamp: StampDataDisplay
    let viewModel: CollectionViewModel
    
    // Get current stamp from viewModel (updates when market data fetched)
    private var currentDisplayStamp: StampDataDisplay {
        viewModel.stamps.first(where: { $0.id == displayStamp.id }) ?? displayStamp
    }
    
    // Convenience accessor for the underlying stamp (always use current data)
    private var stamp: StampData { currentDisplayStamp.stamp }
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.appColorScheme) private var appColorScheme
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            List {
                // Section 1: Stamp Identification
                Section {
                    stampIdentificationSection
                }
                
                // Section 2: Creator, Supply & Market Data
                Section {
                    creatorAndMarketContent
                }
                
                // Section 3: File Information
                Section {
                    fileInformationContent
                }
                
                // Section 4: Blockchain Information
                Section {
                    blockchainInformationContent
                }
                
                // View on Stampchain Button
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
            // Fetch market data when popup opens (if not already cached)
            await viewModel.fetchMarketDataIfNeeded(for: displayStamp)
        }
    }
    
    // MARK: - Section 1: Stamp Identification
    
    private var stampIdentificationSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                // STAMP label (light) + stampId number (semibold)
                Text("STAMP #\(Text("\(stamp.stampId)").fontWeight(.bold))")
                    .fontWeight(.light)
                    .font(.title2)
                    .foregroundStyle(.primary)
                
                // CPID label (light) + counterpartyId (semibold)
                Text("CPID \(Text(stamp.counterpartyId).fontWeight(.bold))")
                    .fontWeight(.light)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
            
            Spacer()
            
            // Stamp type badge
            Text(stamp.stampType)
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
    
    // MARK: - Section 2: Creator, Supply & Market Data
    
    @ViewBuilder
    private var creatorAndMarketContent: some View {
        if let creatorName = stamp.creatorName {
            MetadataRow(label: "Artist", value: creatorName)
        }
        
        MetadataRow(
            label: "Addy",
            value: stamp.creatorAddy.truncatedAddress(prefixLength: 6, suffixLength: 6),
            fullValue: stamp.creatorAddy
        )
        
        MetadataRow(label: "Editions", value: "\(stamp.editionsSupply)")
        
        // Show balance (user's balance vs total supply)
        MetadataRow(label: "Balance", value: displayStamp.formattedBalanceWithSupply)
        
        // Holders: always show (at least one holder); updates when market data loads
        MetadataRow(
            label: "Holders",
            value: currentDisplayStamp.marketData?.formattedHolderCount ?? "1 holder"
        )
        
        // Market data (fetched on-demand) - use currentDisplayStamp for updates
        if let marketData = currentDisplayStamp.marketData {
            if let floorPrice = marketData.formattedFloorPrice {
                MetadataRow(label: "Floor Price", value: floorPrice)
            }
            if let dispensers = marketData.openDispensersCount, dispensers > 0 {
                MetadataRow(label: "Listings", value: "\(dispensers)")
            }
        } else if currentDisplayStamp.isLoadingMarketData {
            // Show loading state
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
    
    // MARK: - Section 3: File Information
    
    @ViewBuilder
    private var fileInformationContent: some View {
        // File Type: always show (from balance); "N/A" when nil/empty
        MetadataRow(
            label: "File Type",
            value: stamp.fileType.map { $0.isEmpty ? "N/A" : $0 } ?? "N/A"
        )
        // File Size: always show; "N/A" when null/0, else formatted value (updates when stamp-by-id fetch completes)
        MetadataRow(
            label: "File Size",
            value: (stamp.fileSize.map { $0 > 0 } == true) ? (stamp.formattedFileSize ?? "N/A") : "N/A"
        )
    }
    
    // MARK: - Section 4: Blockchain Information
    
    @ViewBuilder
    private var blockchainInformationContent: some View {
        if let blockTime = stamp.blockTime {
            MetadataRow(
                label: "Date",
                value: blockTime.formatted(date: .abbreviated, time: .shortened)
            )
        }
        if let blockIndex = stamp.blockIndex {
            MetadataRow(label: "Block", value: "#\(blockIndex)")
        }
        MetadataRow(
            label: "Tx Hash",
            value: stamp.txHash.prefix(8) + "..." + stamp.txHash.suffix(8),
            fullValue: stamp.txHash
        )
    }
    
    // MARK: - Stampchain Link Button
    
    private var stampchainLinkButton: some View {
        Button {
            openURL(stamp.stampchainURL)
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
}

// MARK: - Metadata Row

/// Individual row in the metadata display
struct MetadataRow: View {
    let label: String
    let value: String
    var fullValue: String?
    
    @State private var showCopied = false
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.callout)
                .fontWeight(.light)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.callout)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
            
            Spacer()
            
            // Copy button for values with full value
            if let fullValue = fullValue {
                Button {
                    UIPasteboard.general.string = fullValue
                    showCopied = true
                    
                    // Hide "Copied" after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showCopied = false
                    }
                } label: {
                    if showCopied {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "doc.on.doc")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                .accessibilityLabel("Copy \(label)")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(fullValue ?? value)")
    }
}

// MARK: - Preview

#Preview {
    StampMetadataPopup(displayStamp: StampDataDisplay(from: StampData.sample), viewModel: CollectionViewModel())
        .presentationDetents([.medium, .large])
}
