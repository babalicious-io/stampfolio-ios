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
                    
                    // Section 2: Creator & Market Data
                    creatorAndMarketSection
                    
                    // Section 3: File Information
                    fileInformationSection
                    
                    // Section 4: Blockchain Information
                    blockchainInformationSection
                    
                    // View on Stampchain Button
                    stampchainLinkButton
                        .padding(.top, 4)
                }
                .padding()
            }
            .background(Color(.secondarySystemGroupedBackground))
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
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stamp.formattedNumber)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    
                    Text(stamp.cpid)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                
                Spacer()
                
                // Stamp type badge
                Text(stamp.ident ?? "STAMP")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(appColorScheme.primary)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Section 2: Creator & Market Data
    
    private var creatorAndMarketSection: some View {
        VStack(spacing: 0) {
            // Creator name (if available)
            if let creatorName = stamp.creatorName {
                MetadataRow(label: "Creator", value: creatorName)
                Divider().padding(.leading)
            }
            
            // Creator address
            MetadataRow(
                label: "Address",
                value: stamp.creatorAddy.truncatedAddress(prefixLength: 6, suffixLength: 6),
                fullValue: stamp.creatorAddy,
                isMonospace: true
            )
            Divider().padding(.leading)
            
            // Editions
            MetadataRow(label: "Editions", value: "\(stamp.supply)")
            
            // Market Data
            if let marketData = stamp.marketData {
                if let holders = marketData.formattedHolderCount {
                    Divider().padding(.leading)
                    MetadataRow(label: "Holders", value: holders)
                }
                
                if let floorPrice = marketData.formattedFloorPrice {
                    Divider().padding(.leading)
                    MetadataRow(label: "Floor Price", value: floorPrice)
                }
                
                if let dispensers = marketData.openDispensersCount, dispensers > 0 {
                    Divider().padding(.leading)
                    MetadataRow(label: "Active Listings", value: "\(dispensers)")
                }
            }
        }
        .padding(.vertical, 4)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Section 3: File Information
    
    private var fileInformationSection: some View {
        VStack(spacing: 0) {
            if let mimetype = stamp.stampMimetype {
                MetadataRow(label: "File Type", value: mimetype)
            }
            
            if let formattedSize = stamp.formattedFileSize {
                if stamp.stampMimetype != nil {
                    Divider().padding(.leading)
                }
                MetadataRow(label: "File Size", value: formattedSize)
            }
        }
        .padding(.vertical, 4)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Section 4: Blockchain Information
    
    private var blockchainInformationSection: some View {
        VStack(spacing: 0) {
            // Date
            if let blockTime = stamp.blockTime {
                MetadataRow(
                    label: "Created",
                    value: blockTime.formatted(date: .abbreviated, time: .shortened)
                )
                Divider().padding(.leading)
            }
            
            // Block height
            if let blockIndex = stamp.blockIndex {
                MetadataRow(label: "Block", value: "#\(blockIndex)")
                Divider().padding(.leading)
            }
            
            // Tx Hash
            MetadataRow(
                label: "Tx Hash",
                value: stamp.txHash.truncatedAddress(prefixLength: 8, suffixLength: 8),
                fullValue: stamp.txHash,
                isMonospace: true
            )
        }
        .padding(.vertical, 4)
        .background(Color(.systemBackground))
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
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular.tint(appColorScheme.primary).interactive(), in: .capsule)
        }
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
        HStack(alignment: .center) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(isMonospace ? .footnote : .subheadline)
                .fontDesign(isMonospace ? .monospaced : .default)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
            
            // Copy button for values with full value
            if let fullValue = fullValue {
                Button {
                    UIPasteboard.general.string = fullValue
                    showCopied = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showCopied = false
                    }
                } label: {
                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(showCopied ? .green : .secondary)
                        .font(.caption)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(fullValue ?? value)")
    }
}

// MARK: - Preview

#Preview {
    StampMetadataPopup(stamp: .sample)
        .presentationDetents([.medium, .large])
        .presentationBackground(.ultraThinMaterial)
}
