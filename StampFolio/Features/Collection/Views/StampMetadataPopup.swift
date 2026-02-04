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
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Stamp Number Header
                    headerSection
                    
                    Divider()
                    
                    // Metadata Grid
                    metadataSection
                    
                    Divider()
                    
                    // View on Stampchain Button
                    stampchainLinkButton
                }
                .padding()
            }
            .navigationTitle("Stamp Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(stamp.formattedNumber)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                if let creatorName = stamp.creatorName {
                    Text("by \(creatorName)")
                        .font(.subheadline)
                        .foregroundStyle(.purple)
                }
            }
            
            Spacer()
            
            // Stamp type badge
            Text(stamp.ident ?? "STAMP")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.8))
                .clipShape(Capsule())
        }
    }
    
    // MARK: - Metadata Section
    
    private var metadataSection: some View {
        VStack(spacing: 16) {
            // CPID
            MetadataRow(
                label: "CPID",
                value: stamp.cpid,
                isMonospace: true
            )
            
            // Creator
            MetadataRow(
                label: "Creator",
                value: stamp.creator.truncatedAddress(prefixLength: 6, suffixLength: 6),
                fullValue: stamp.creator,
                isMonospace: true
            )
            
            // Editions
            MetadataRow(
                label: "Editions",
                value: "\(stamp.supply)"
            )
            
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
            
            // Block (optional - not in balance endpoint)
            if let blockIndex = stamp.blockIndex {
                MetadataRow(
                    label: "Block",
                    value: "#\(blockIndex)"
                )
            }
            
            // Date (optional - not in balance endpoint)
            if let blockTime = stamp.blockTime {
                MetadataRow(
                    label: "Created",
                    value: blockTime.formatted(date: .abbreviated, time: .shortened)
                )
            }
            
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
                        label: "Active Listings",
                        value: "\(dispensers)"
                    )
                }
            }
        }
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
            .glassEffect(.regular.interactive(), in: .capsule)
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
        .presentationDetents([.medium])
        .presentationBackground(.ultraThinMaterial)
}
