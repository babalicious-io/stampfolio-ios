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
    
    let displayStamp: DisplayStamp
    
    // Convenience accessor for the underlying stamp
    private var stamp: Stamp { displayStamp.stamp }
    
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
            
            // Stamp type badge (stampType guaranteed non-nil by DisplayStamp)
            Text(stamp.stampType!)
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
        
        MetadataRow(label: "Editions", value: "\(stamp.supply)")
        
        // Show balance (user's balance vs total supply)
        MetadataRow(label: "Balance", value: displayStamp.formattedBalanceWithSupply)
        
        if let marketData = stamp.marketData {
            if let floorPrice = marketData.formattedFloorPrice {
                MetadataRow(label: "Floor Price", value: floorPrice)
            }
            if let holders = marketData.formattedHolderCount {
                MetadataRow(label: "Holders", value: holders)
            }
            if let dispensers = marketData.openDispensersCount, dispensers > 0 {
                MetadataRow(label: "Listings", value: "\(dispensers)")
            }
        }
    }
    
    // MARK: - Section 3: File Information
    
    @ViewBuilder
    private var fileInformationContent: some View {
        if let mimetype = stamp.stampMimetype {
            MetadataRow(label: "File Type", value: mimetype)
        }
        if let formattedSize = stamp.formattedFileSize {
            MetadataRow(label: "File Size", value: formattedSize)
        }
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
    StampMetadataPopup(displayStamp: DisplayStamp(from: .sample))
        .presentationDetents([.medium, .large])
}
