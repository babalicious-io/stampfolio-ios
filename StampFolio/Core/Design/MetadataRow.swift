//
//  MetadataRow.swift
//  StampFolio
//
//  Shared metadata display row used by asset detail sheets (Stamp, Counterparty, Ordinals)
//

import SwiftUI

private enum MetadataRowLayout {
    /// Fixed label column.
    static let labelColumnWidth: CGFloat = 88
}

/// Individual row in the metadata display, with an optional copy-to-clipboard button
/// when a `fullValue` (e.g. an untruncated address/hash) differs from the shown `value`
struct MetadataRow: View {
    let label: String
    let value: String
    var fullValue: String?
    /// When true, the value is middle-truncated to at most 95% of the remaining row width
    var truncatesValue: Bool = false

    @State private var showCopied = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.callout)
                .fontWeight(.light)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .frame(width: MetadataRowLayout.labelColumnWidth, alignment: .leading)
                .layoutPriority(1)

            valueText

            if !truncatesValue {
                Spacer(minLength: 0)
            }

            if let fullValue {
                copyButton(fullValue: fullValue)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(fullValue ?? value)")
    }

    @ViewBuilder
    private var valueText: some View {
        if truncatesValue {
            truncatedValueText
        } else {
            Text(value)
                .font(.callout)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }

    /// Caps the value at 95% of the remaining row so the copy control stays visible.
    private var truncatedValueText: some View {
        Text(" ")
            .font(.callout)
            .fontWeight(.bold)
            .hidden()
            .frame(maxWidth: .infinity)
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    Text(value)
                        .font(.callout)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(width: geometry.size.width * 0.95, alignment: .leading)
                }
            }
    }

    private func copyButton(fullValue: String) -> some View {
        Button {
            UIPasteboard.general.string = fullValue
            showCopied = true

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
        .layoutPriority(1)
        .accessibilityLabel("Copy \(label)")
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
                .frame(width: MetadataRowLayout.labelColumnWidth, alignment: .leading)

            ProgressView()
                .controlSize(.small)

            Spacer()
        }
    }
}
