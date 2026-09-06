//
//  StampAssetPixelView.swift
//  StampFolio
//
//  Renders pixel-based stamp images (jpg, png, webp, gif)
//

import SwiftUI
import Kingfisher

/// View for rendering pixel-based stamp images
struct StampAssetPixelView: View {
    
    // MARK: - Properties
    
    let stamp: StampAsset
    let geometry: CGSize
    let onFailure: () -> Void
    
    // MARK: - Environment
    
    @Environment(\.appColorScheme) private var appColorScheme
    @Environment(\.displayScale) private var displayScale
    
    /// User preference: animated GIF previews or static downsampled thumbnails
    @AppStorage("performancePreview") private var performancePreview = true
    
    // MARK: - Body
    
    var body: some View {
        if stamp.isGIF && performancePreview {
            // Animated GIF - no downsampling to preserve animation frames
            KFAnimatedImage(stamp.imageURL)
                .placeholder {
                    loadingView
                }
                .protocolCache(ProtocolImageCache.stamps)
                .loadDiskFileSynchronously()
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
            // Static images (jpg, png, webp) or GIFs with animated previews off
            // Downsampled 200px thumbnail for grid/row; full-res original also cached on disk
            KFImage(stamp.imageURL)
                .placeholder {
                    loadingView
                }
                .protocolCache(ProtocolImageCache.stamps)
                .loadDiskFileSynchronously()
                .setProcessor(DownsamplingImageProcessor(size: CollectionImageThumbnail.size))
                .scaleFactor(displayScale)
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
