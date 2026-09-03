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
    @Environment(\.displayScale) private var displayScale

    // MARK: - State

    @State private var resolvedImageURL: URL?
    @State private var imageLoadFailed = false

    // MARK: - Body

    var body: some View {
        Group {
            if let resolvedImageURL, !imageLoadFailed {
                ZStack {
                    // Many Counterparty assets use "card" (portrait, e.g. 5:7) artwork rather than
                    // Stamps' square format, so the image is never cropped to fill the frame — this
                    // tint fills any letterboxing around it instead.
                    appColorScheme.primary.opacity(0.08)

                    KFImage(resolvedImageURL)
                        .placeholder { placeholderIcon }
                        .loadDiskFileSynchronously()
                        .setProcessor(DownsamplingImageProcessor(size: size))
                        .scaleFactor(displayScale)
                        .retry(maxCount: 2, interval: .seconds(1))
                        .fade(duration: 0.25)
                        .cacheOriginalImage()
                        .diskCacheExpiration(.never)
                        .onFailure { _ in
                            imageLoadFailed = true
                        }
                        .resizable()
                        .interpolation(.none) // Many manifests only have tiny (e.g. 48x48) icons; avoid blurring them when scaled up
                        .aspectRatio(contentMode: .fit)
                }
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
            LinearGradient.cardBackground(color: appColorScheme.primary)

            Image(systemName: asset.isNumericAsset ? "number" : "xmark.triangle.circle.square.fill")
                .font(.system(size: min(size.width, size.height) * 0.35, weight: .semibold))
                .foregroundStyle(appColorScheme.primary)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Image Resolution

    private func resolveImageIfNeeded() async {
        imageLoadFailed = false
        resolvedImageURL = await CounterpartyAssetImageResolver.shared.resolveImageURL(for: asset)
    }
}

// MARK: - Fullscreen Content

/// Full-bleed original artwork for immersive Counterparty viewing (slideshow and long-press).
/// Card/row rendering stays on `CounterpartyAssetImageView`, which downsamples to a target size.
struct CounterpartyAssetFullscreenContent: View {
    let asset: CounterpartyAsset

    @State private var resolvedImageURL: URL?
    @State private var imageLoadFailed = false

    var body: some View {
        Group {
            if let resolvedImageURL, !imageLoadFailed {
                KFImage(resolvedImageURL)
                    .placeholder { placeholderIcon }
                    .loadDiskFileSynchronously()
                    .retry(maxCount: 3)
                    .cacheOriginalImage()
                    .diskCacheExpiration(.never)
                    .onFailure { _ in
                        imageLoadFailed = true
                    }
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
            } else {
                placeholderIcon
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: asset.id) {
            await resolveImageIfNeeded()
        }
    }

    private var placeholderIcon: some View {
        Image(systemName: asset.isNumericAsset ? "number" : "xmark.triangle.circle.square.fill")
            .font(.system(size: 80, weight: .semibold))
            .foregroundStyle(.white.opacity(0.55))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func resolveImageIfNeeded() async {
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
