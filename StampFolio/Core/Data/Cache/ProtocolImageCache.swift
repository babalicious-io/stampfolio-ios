//
//  ProtocolImageCache.swift
//  StampFolio
//
//  Named Kingfisher caches per collection protocol (stamps vs Counterparty).
//

import Kingfisher
import UIKit

/// Named Kingfisher caches so tiny stamp files and large Counterparty artwork
/// do not share one memory LRU. Disk is unlimited and never expires.
///
/// Always set both `.targetCache` and `.originalCache` (see `options(for:)` /
/// `protocolCache(_:)`). Omitting `.originalCache` leaves originals on
/// `ImageCache.default`.
///
/// Ordinals will get its own named cache when that tab ships.
enum ProtocolImageCache {

    static let stamps = makeCache(name: "stamps", memoryBytes: 40 * 1024 * 1024)
    static let counterparty = makeCache(name: "counterparty", memoryBytes: 70 * 1024 * 1024)

    /// Touch both caches at launch so memory/disk limits apply before the first image load.
    static func warm() {
        _ = stamps
        _ = counterparty
    }

    /// Prefetch / retrieve options that keep processed and original bytes on `cache`.
    static func options(for cache: ImageCache) -> KingfisherOptionsInfo {
        [
            .targetCache(cache),
            .originalCache(cache),
            .cacheOriginalImage,
            .diskCacheExpiration(.never)
        ]
    }

    /// Same as `options(for:)` plus the 200pt downsampler used by collection grids.
    static func thumbnailOptions(for cache: ImageCache) -> KingfisherOptionsInfo {
        options(for: cache) + [
            .processor(DownsamplingImageProcessor(size: CollectionImageThumbnail.size)),
            .scaleFactor(UIScreen.main.scale)
        ]
    }

    /// Await a Kingfisher prefetch. Cache hits and failures both count toward `progress`.
    @MainActor
    static func prefetch(
        _ urls: [URL],
        options: KingfisherOptionsInfo,
        retain: (ImagePrefetcher) -> Void,
        progress: @escaping (Int) -> Void
    ) async {
        guard !urls.isEmpty else {
            progress(0)
            return
        }

        await withCheckedContinuation { continuation in
            let prefetcher = ImagePrefetcher(
                urls: urls,
                options: options,
                progressBlock: { skipped, failed, completed in
                    let done = skipped.count + failed.count + completed.count
                    Task { @MainActor in
                        progress(done)
                    }
                },
                completionHandler: { skipped, failed, completed in
                    let done = skipped.count + failed.count + completed.count
                    Task { @MainActor in
                        progress(done)
                        continuation.resume()
                    }
                }
            )
            retain(prefetcher)
            prefetcher.start()
        }
    }

    private static func makeCache(name: String, memoryBytes: Int) -> ImageCache {
        let cache = ImageCache(name: name)
        cache.memoryStorage.config.totalCostLimit = memoryBytes
        cache.diskStorage.config.sizeLimit = 0
        cache.diskStorage.config.expiration = .never
        return cache
    }
}

extension KFOptionSetter {
    /// Route processed and original images to a protocol cache, not `ImageCache.default`.
    func protocolCache(_ cache: ImageCache) -> Self {
        targetCache(cache).originalCache(cache)
    }
}
