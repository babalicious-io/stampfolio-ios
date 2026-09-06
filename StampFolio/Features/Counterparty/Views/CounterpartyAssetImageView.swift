//
//  CounterpartyAssetImageView.swift
//  StampFolio
//
//  Renders a Counterparty asset's resolved artwork, falling back to a placeholder icon
//

import SwiftUI
import Kingfisher

/// Decode size for collection vs immersive Counterparty artwork.
/// Layout `size` is independent (letterboxed `.fit` in the view frame).
enum CounterpartyArtworkDisplayMode {
    /// 200pt downsample + original on disk (grid, row)
    case thumbnail
    /// Full original decode (detail, fullscreen)
    case original
}

/// Renders a Counterparty asset's artwork when one can be resolved from its `description`
/// field, falling back to the standard placeholder icon when the asset has no artwork or the
/// image fails to load.
struct CounterpartyAssetImageView: View {

    // MARK: - Properties

    let asset: CounterpartyAsset
    var size: CGSize = CollectionImageThumbnail.size
    var displayMode: CounterpartyArtworkDisplayMode = .thumbnail

    // MARK: - Environment

    @Environment(\.appColorScheme) private var appColorScheme
    @Environment(\.displayScale) private var displayScale

    /// User preference: animated GIF previews or static downsampled thumbnails
    @AppStorage("performancePreview") private var performancePreview = true

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

                    artwork(for: resolvedImageURL)
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

    // MARK: - Artwork

    @ViewBuilder
    private func artwork(for url: URL) -> some View {
        if shouldAnimateGIF(url) {
            KFAnimatedImage(url)
                .placeholder { placeholderIcon }
                .protocolCache(ProtocolImageCache.counterparty)
                .loadDiskFileSynchronously()
                .cacheOriginalImage()
                .diskCacheExpiration(.never)
                .onFailure { _ in
                    imageLoadFailed = true
                }
                .aspectRatio(contentMode: .fit)
                .frame(width: size.width, height: size.height)
        } else if displayMode == .thumbnail {
            KFImage(url)
                .placeholder { placeholderIcon }
                .protocolCache(ProtocolImageCache.counterparty)
                .loadDiskFileSynchronously()
                .setProcessor(DownsamplingImageProcessor(size: CollectionImageThumbnail.size))
                .scaleFactor(displayScale)
                .retry(maxCount: 2, interval: .seconds(1))
                .fade(duration: 0.25)
                .cacheOriginalImage()
                .diskCacheExpiration(.never)
                .onFailure { _ in
                    imageLoadFailed = true
                }
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
        } else {
            KFImage(url)
                .placeholder { placeholderIcon }
                .protocolCache(ProtocolImageCache.counterparty)
                .loadDiskFileSynchronously()
                .retry(maxCount: 3, interval: .seconds(1))
                .fade(duration: 0.25)
                .cacheOriginalImage()
                .diskCacheExpiration(.never)
                .onFailure { _ in
                    imageLoadFailed = true
                }
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
        }
    }

    /// Animate when the URL is a `.gif` file and either this is original (detail) or animated previews are on.
    /// Horizon proxy URLs often have no extension and stay on static `KFImage`.
    private func shouldAnimateGIF(_ url: URL) -> Bool {
        guard CounterpartyArtworkURL.isGIF(url) else { return false }
        return displayMode == .original || performancePreview
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
/// `size` must be the canvas in points — `KFImage` collapses to 0×0 without it.
struct CounterpartyAssetFullscreenContent: View {
    let asset: CounterpartyAsset
    let size: CGSize

    @State private var resolvedImageURL: URL?
    @State private var imageLoadFailed = false

    var body: some View {
        Group {
            if let resolvedImageURL, !imageLoadFailed {
                if CounterpartyArtworkURL.isGIF(resolvedImageURL) {
                    KFAnimatedImage(resolvedImageURL)
                        .placeholder { placeholderIcon }
                        .protocolCache(ProtocolImageCache.counterparty)
                        .loadDiskFileSynchronously()
                        .cacheOriginalImage()
                        .diskCacheExpiration(.never)
                        .onFailure { _ in
                            imageLoadFailed = true
                        }
                        .aspectRatio(contentMode: .fit)
                } else {
                    KFImage(resolvedImageURL)
                        .placeholder { placeholderIcon }
                        .protocolCache(ProtocolImageCache.counterparty)
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
                }
            } else {
                placeholderIcon
            }
        }
        .frame(width: size.width, height: size.height)
        .task(id: asset.id) {
            await resolveImageIfNeeded()
        }
    }

    private var placeholderIcon: some View {
        Image(systemName: asset.isNumericAsset ? "number" : "xmark.triangle.circle.square.fill")
            .font(.system(size: 80, weight: .semibold))
            .foregroundStyle(.white.opacity(0.55))
    }

    private func resolveImageIfNeeded() async {
        imageLoadFailed = false
        resolvedImageURL = await CounterpartyAssetImageResolver.shared.resolveImageURL(for: asset)
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 16) {
        CounterpartyAssetImageView(asset: .sample, size: AssetRowMetrics.counterpartyPreviewSize)
            .frame(
                width: AssetRowMetrics.counterpartyPreviewSize.width,
                height: AssetRowMetrics.counterpartyPreviewSize.height
            )
            .clipShape(RoundedRectangle(cornerRadius: AssetRowMetrics.previewCornerRadius))

        CounterpartyAssetImageView(asset: .sample, size: CGSize(width: 120, height: 120))
            .frame(width: 120, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    .padding()
}
