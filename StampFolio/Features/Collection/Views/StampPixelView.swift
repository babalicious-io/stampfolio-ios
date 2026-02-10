//
//  StampPixelView.swift
//  StampFolio
//
//  Renders pixel-based stamp images (jpg, png, webp, gif)
//

import SwiftUI
import Kingfisher

/// View for rendering pixel-based stamp images
struct StampPixelView: View {
    
    // MARK: - Properties
    
    let stamp: Stamp
    let geometry: CGSize
    let onFailure: () -> Void
    
    // MARK: - Environment
    
    @Environment(\.appColorScheme) private var appColorScheme
    
    // MARK: - Body
    
    /// Downsampled thumbnail size for grid/row views (200pt).
    /// Kingfisher caches both this small decoded bitmap and the full-res original on disk.
    private static let thumbnailSize = CGSize(width: 200, height: 200)
    
    var body: some View {
        if stamp.isGIF {
            // Use KFAnimatedImage for GIFs - downsampled thumbnail + full-res cached on disk
            KFAnimatedImage(stamp.imageURL)
                .placeholder {
                    loadingView
                }
                .loadDiskFileSynchronously()
                .setProcessor(DownsamplingImageProcessor(size: Self.thumbnailSize))
                .scaleFactor(UIScreen.main.scale)
                .cacheOriginalImage()
                .diskCacheExpiration(.never)
                .onFailure { error in
                    print("GIF load failed for \(stamp.id): \(error.localizedDescription)")
                    onFailure()
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.width, height: geometry.width)
                .clipped()
        } else {
            // Use KFImage for regular images (jpg, png, webp) + SRC-721/cursed stamps
            // Downsampled 200px thumbnail for grid; full-res original also cached on disk
            KFImage(stamp.imageURL)
                .placeholder {
                    loadingView
                }
                .loadDiskFileSynchronously()
                .setProcessor(DownsamplingImageProcessor(size: Self.thumbnailSize))
                .scaleFactor(UIScreen.main.scale)
                .retry(maxCount: 3, interval: .seconds(1))
                .fade(duration: 0.3)
                .cacheOriginalImage()
                .diskCacheExpiration(.never)
                .onFailure { error in
                    print("Image load failed for \(stamp.id): \(error.localizedDescription)")
                    print("URL: \(stamp.stampUrl)")
                    onFailure()
                }
                .resizable()
                .interpolation(.none) // Prevents pixelation for small/pixel art stamps
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.width, height: geometry.width)
                .clipped()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        ProgressView()
            .tint(appColorScheme.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemBackground))
    }
}
