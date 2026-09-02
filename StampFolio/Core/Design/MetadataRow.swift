//
//  MetadataRow.swift
//  StampFolio
//
//  Shared metadata display row used by asset detail sheets (Stamp, Counterparty, Ordinals)
//

import SwiftUI

/// Individual row in the metadata display, with an optional copy-to-clipboard button
/// when a `fullValue` (e.g. an untruncated address/hash) differs from the shown `value`
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

// MARK: - Metadata Loading Row

/// Placeholder row shown in place of on-demand market data while it's still loading
struct MetadataLoadingRow: View {
    var label: String = "Market Data"

    var body: some View {
        HStack {
            Text(label)
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
