//
//  StampAssetImageView.swift
//  StampFolio
//
//  Shared stamp preview routing used by grid cards, list rows, and the details sheet
//

import SwiftUI

/// Renders a stamp's preview at a given size, routing HTML/SVG, text, library,
/// audio/video, and raster content to the existing specialized views.
struct StampAssetImageView: View {

    // MARK: - Properties

    let asset: StampAsset
    var size: CGSize = CGSize(width: 200, height: 200)
    /// When true, HTML/SVG WKWebViews are checked out of the collection pool.
    var reusesWebView: Bool = false

    // MARK: - Environment

    @Environment(\.appColorScheme) private var appColorScheme

    // MARK: - State

    @State private var imageLoadFailed = false

    // MARK: - Body

    var body: some View {
        Group {
            if imageLoadFailed {
                failedImageView
            } else if asset.isHTML || asset.isSVG {
                StampAssetVectorView(
                    url: asset.imageURL,
                    onFailure: { imageLoadFailed = true },
                    reusesWebView: reusesWebView
                )
            } else if asset.isText {
                StampAssetTextView(url: asset.imageURL, onFailure: { imageLoadFailed = true })
            } else if asset.isLibrary, let label = asset.libraryLabel {
                StampAssetLibraryView(label: label)
            } else if asset.isAudio || asset.isVideo {
                StampAssetMediaView(type: asset.isAudio ? .audio : .video)
            } else {
                StampAssetPixelView(
                    stamp: asset,
                    geometry: size,
                    onFailure: { imageLoadFailed = true }
                )
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    // MARK: - Failed Image View

    private var isCompact: Bool {
        min(size.width, size.height) < 100
    }

    private var failedImageView: some View {
        ZStack {
            Color(uiColor: .systemBackground)

            VStack(spacing: isCompact ? 4 : 8) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(isCompact ? .caption : .title)
                    .foregroundStyle(appColorScheme.primary)

                Text(isCompact ? "Failed" : "Failed to load")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if !isCompact {
                    Button {
                        imageLoadFailed = false
                    } label: {
                        Text("Retry")
                            .font(.caption2)
                            .foregroundStyle(appColorScheme.primary)
                    }
                }
            }
        }
    }
}
