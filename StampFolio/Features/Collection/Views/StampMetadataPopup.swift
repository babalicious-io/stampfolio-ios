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
    
    let stamp: Stamp
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.appColorScheme) private var appColorScheme
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Section 1: Stamp Identification
                    stampIdentificationSection
                    
                    // Section 2: Creator, Supply & Market Data
                    creatorAndMarketSection
                    
                    // Section 3: File Information
                    fileInformationSection
                    
                    // Section 4: Blockchain Information
                    blockchainInformationSection
                    
                    // View on Stampchain Button
                    stampchainLinkButton
                }
                .padding()
            }
            .navigationTitle("Stamp Details")
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
    }
    
    // MARK: - Section 1: Stamp Identification
    
    private var stampIdentificationSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(stamp.formattedStampId)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Text(stamp.formattedCounterpartyId)
                    .font(.footnote)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            
            Spacer()
            
            // Stamp type badge
            Text(stamp.ident ?? "STAMP")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(appColorScheme.primary.opacity(0.8))
                .clipShape(Capsule())
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Section 2: Creator, Supply & Market Data
    
    private var creatorAndMarketSection: some View {
        VStack(spacing: 12) {
            // Creator name (if available)
            if let creatorName = stamp.creatorName {
                MetadataRow(
                    label: "Creator",
                    value: creatorName
                )
            }
            
            // Creator address
            MetadataRow(
                label: "Address",
                value: stamp.creatorAddy.truncatedAddress(prefixLength: 6, suffixLength: 6),
                fullValue: stamp.creatorAddy,
                isMonospace: true
            )
            
            // Editions
            MetadataRow(
                label: "Editions",
                value: "\(stamp.supply)"
            )
            
            // Market Data (if available)
            if let marketData = stamp.marketData {
                if let floorPrice = marketData.formattedFloorPrice {
                    MetadataRow(
                        label: "Floor Price",
                        value: floorPrice
                    )
                }
                
                if let holders = marketData.formattedHolderCount {
                    MetadataRow(
                        label: "Holders",
                        value: holders
                    )
                }
                
                if let dispensers = marketData.openDispensersCount, dispensers > 0 {
                    MetadataRow(
                        label: "Listings",
                        value: "\(dispensers)"
                    )
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Section 3: File Information
    
    private var fileInformationSection: some View {
        VStack(spacing: 12) {
            // File Type
            if let mimetype = stamp.stampMimetype {
                MetadataRow(
                    label: "File Type",
                    value: mimetype
                )
            }
            
            // File Size
            if let formattedSize = stamp.formattedFileSize {
                MetadataRow(
                    label: "File Size",
                    value: formattedSize
                )
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Section 4: Blockchain Information
    
    private var blockchainInformationSection: some View {
        VStack(spacing: 12) {
            // Date (optional)
            if let blockTime = stamp.blockTime {
                MetadataRow(
                    label: "Date",
                    value: blockTime.formatted(date: .abbreviated, time: .shortened)
                )
            }
            
            // Block Height (optional)
            if let blockIndex = stamp.blockIndex {
                MetadataRow(
                    label: "Block",
                    value: "#\(blockIndex)"
                )
            }
            
            // Transaction Hash
            MetadataRow(
                label: "Tx Hash",
                value: stamp.txHash.prefix(8) + "..." + stamp.txHash.suffix(8),
                fullValue: stamp.txHash,
                isMonospace: true
            )
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
    var isMonospace: Bool = false
    
    @State private var showCopied = false
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(isMonospace ? .footnote : .caption)
                .fontDesign(isMonospace ? .monospaced : .default)
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
    StampMetadataPopup(stamp: .sample)
        .presentationDetents([.medium, .large])
}
