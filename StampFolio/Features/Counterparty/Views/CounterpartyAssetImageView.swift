//
//  CounterpartyAssetImageView.swift
//  StampFolio
//
//  Renders a Counterparty asset's resolved artwork, falling back to a placeholder icon
//

import SwiftUI
import Kingfisher

/// Renders a Counterparty asset's artwork when one can be resolved from its `description`
/// field, falling back to the standard placeholder icon when the asset has no artwork or the
/// image fails to load.
struct CounterpartyAssetImageView: View {

    // MARK: - Properties

    let asset: CounterpartyAsset
    var size: CGSize = CGSize(width: 200, height: 200)

    // MARK: - Environment

    @Environment(\.appColorScheme) private var appColorScheme

    // MARK: - State

    @State private var resolvedImageURL: URL?
    @State private var imageLoadFailed = false

    // MARK: - Body

    var body: some View {
        Group {
            if let resolvedImageURL, !imageLoadFailed {
                KFImage(resolvedImageURL)
                    .placeholder { placeholderIcon }
                    .loadDiskFileSynchronously()
                    .setProcessor(DownsamplingImageProcessor(size: size))
                    .scaleFactor(UIScreen.main.scale)
                    .retry(maxCount: 2, interval: .seconds(1))
                    .fade(duration: 0.25)
                    .cacheOriginalImage()
                    .onFailure { _ in
                        imageLoadFailed = true
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                placeholderIcon
            }
        }
        .task(id: asset.id) {
            await resolveImageIfNeeded()
        }
    }

    // MARK: - Placeholder Icon

    private var placeholderIcon: some View {
        ZStack {
            appColorScheme.primary.opacity(0.15)

            Image(systemName: asset.isNumericAsset ? "number" : "xmark.triangle.circle.square.fill")
                .font(.system(size: min(size.width, size.height) * 0.35, weight: .semibold))
                .foregroundStyle(appColorScheme.primary)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Image Resolution

    private func resolveImageIfNeeded() async {
        guard asset.descriptionIsURL else { return }
        imageLoadFailed = false
        resolvedImageURL = await CounterpartyAssetImageResolver.shared.resolveImageURL(for: asset)
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 16) {
        CounterpartyAssetImageView(asset: .sample, size: CGSize(width: 48, height: 48))
            .frame(width: 48, height: 48)
            .clipShape(Circle())

        CounterpartyAssetImageView(asset: .sample, size: CGSize(width: 120, height: 120))
            .frame(width: 120, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    .padding()
}
