# StampFolio Caching System

Overview of the multi-tier caching architecture used to deliver instant, offline-capable stamp browsing. Bitcoin Stamps are immutable on-chain, so all cached content is permanent and never expires.

## Architecture

StampFolio uses four caching layers, each serving a different content type:

```
┌─────────────────────────────────────────────────────────────┐
│                        User Interface                       │
│  StampAssetPixelView  StampAssetVectorView  StampAssetTextView  DetailView │
└──────┬──────────────┬─────────────────┬─────────────┬───────┘
       │              │                 │             │
       ▼              ▼                 ▼             ▼
┌──────────────┐ ┌────────────────────────────┐ ┌──────────────┐
│  Kingfisher  │ │    StampContentCache       │ │   URLCache   │
│              │ │  ┌────────┐ ┌───────────┐  │ │              │
│  Memory      │ │  │NSCache │ │ Disk files│  │ │  Memory      │
│  (100 MB)    │ │  │(50 max)│ │ (SHA-256) │  │ │  (10 MB)     │
│              │ │  └────┬───┘ └─────┬─────┘  │ │              │
│  Disk        │ │       └─────┬─────┘        │ │  Disk        │
│  (unlimited) │ │         Two-tier           │ │  (50 MB)     │
└──────────────┘ └────────────────────────────┘ └──────────────┘
  Pixel images     HTML / SVG / Text content     API responses
  (jpg,png,gif,    (viewport-injected HTML,      (stamp metadata
   webp)            plain text strings)           JSON from
                                                  Stampchain)
```

### Layer 1 -- URLCache (API Responses)

Caches raw JSON responses from the Stampchain API. Configured in `StampchainAPIClient`.

| Property | Value |
|----------|-------|
| Memory capacity | 10 MB |
| Disk capacity | 50 MB |
| Disk path | `stampchain_cache` |
| Default policy | `.returnCacheDataElseLoad` |
| Force refresh policy | `.reloadIgnoringLocalCacheData` |

```swift
// StampchainAPIClient.swift
let config = URLSessionConfiguration.default
config.urlCache = URLCache(
    memoryCapacity: 10 * 1024 * 1024,
    diskCapacity: 50 * 1024 * 1024,
    diskPath: "stampchain_cache"
)
config.requestCachePolicy = .returnCacheDataElseLoad
```

The `.returnCacheDataElseLoad` policy means the app serves cached API data whenever available, only hitting the network on a true cache miss. When the user triggers a manual refresh (per-wallet swipe in Settings), the policy switches to `.reloadIgnoringLocalCacheData` to bypass the cache.

```swift
// Force refresh bypasses URLCache
func performRequest(_ url: URL, forceStampsRefresh: Bool = false) async throws -> (Data, URLResponse) {
    var request = URLRequest(url: url)
    if forceStampsRefresh {
        request.cachePolicy = .reloadIgnoringLocalCacheData
    }
    return try await session.data(for: request)
}
```

### Layer 2 -- Kingfisher (Pixel Images)

Handles all raster image loading and caching: JPEG, PNG, WebP, GIF. Configured at app startup in `StampFolioApp`.

| Property | Value |
|----------|-------|
| Memory cache limit | 100 MB |
| Disk cache expiration | Never (`.diskCacheExpiration(.never)`) |
| Disk load | Synchronous (`.loadDiskFileSynchronously()`) |
| Downsampling | 200pt for grid/row thumbnails |
| Original caching | Always (`.cacheOriginalImage()`) |

```swift
// StampFolioApp.swift -- global configuration
ImageCache.default.memoryStorage.config.totalCostLimit = 100 * 1024 * 1024
```

#### Dual-Resolution Caching

Grid and row views use `DownsamplingImageProcessor` to decode images at 200x200pt, drastically reducing memory. The `.cacheOriginalImage()` modifier ensures the full-resolution original is also saved to disk for the detail view.

```swift
// StampAssetPixelView.swift -- grid/row (downsampled thumbnail)
KFImage(stamp.imageURL)
    .loadDiskFileSynchronously()
    .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 200, height: 200)))
    .scaleFactor(UIScreen.main.scale)
    .cacheOriginalImage()       // also saves full-res to disk
    .diskCacheExpiration(.never)

// StampAssetFullscreenView.swift -- fullscreen (full resolution)
KFImage(currentStamp.imageURL)
    .loadDiskFileSynchronously()
    .cacheOriginalImage()
    .diskCacheExpiration(.never)
```

**Memory impact**: A 2000x2000px stamp decoded at full resolution uses ~48 MB in RAM. With 200pt downsampling on a 3x screen, the decoded thumbnail uses ~1.4 MB -- a 97% reduction per visible image.

#### Animated GIF Handling

GIFs require special handling because `DownsamplingImageProcessor` strips animation frames. A user-configurable `performancePreview` setting (Settings > Performance) controls the behavior:

- **Animated Previews ON** (default): GIFs use `KFAnimatedImage` without downsampling to preserve animation
- **Animated Previews OFF**: GIFs fall through to `KFImage` with downsampling, rendering as static thumbnails

The detail view always plays animated GIFs at full resolution regardless of this setting.

#### Synchronous Disk Load

`.loadDiskFileSynchronously()` is applied to all Kingfisher calls. When an image is already in the disk cache, Kingfisher loads it on the calling thread instead of dispatching to a background queue. This eliminates the brief placeholder flash for cached stamps.

### Layer 3 -- StampContentCache (HTML/SVG/Text)

A custom two-tier actor-based cache for processed stamp content that `WKWebView` and `Text` views consume. Located in `StampContentCache.swift`.

| Property | Value |
|----------|-------|
| Memory tier | `NSCache<NSString, NSString>`, 50 entries max |
| Disk tier | Files in `Caches/stamp_content/`, keyed by SHA-256 hash of URL |
| Expiration | Never (stamps are immutable on-chain) |
| Thread safety | Swift `actor` isolation |

```swift
actor StampContentCache {
    static let shared = StampContentCache()

    private let memoryCache = NSCache<NSString, NSString>()  // Tier 1
    private let cacheDirectory: URL                           // Tier 2

    func read(for url: URL) -> String? {
        let key = cacheKey(for: url)
        // Fast path: in-memory
        if let cached = memoryCache.object(forKey: key) {
            return cached as String
        }
        // Slow path: disk -> promote to memory on hit
        if let content = try? String(contentsOf: cacheFilePath(for: url), encoding: .utf8) {
            memoryCache.setObject(content as NSString, forKey: key)
            return content
        }
        return nil
    }

    func write(_ content: String, for url: URL) {
        let key = cacheKey(for: url)
        memoryCache.setObject(content as NSString, forKey: key)
        try? content.write(to: cacheFilePath(for: url), atomically: true, encoding: .utf8)
    }
}
```

**Read path**: NSCache (memory) -> disk file -> network fallback
**Write path**: simultaneous write to NSCache + disk

The `NSCache` tier auto-evicts entries under iOS memory pressure with no manual intervention required.

#### HTML/SVG Viewport Injection

Vector stamps (HTML/SVG) fetched from the network have a `<meta viewport>` tag injected before caching. This pre-processing happens once during prefetch; subsequent loads serve the already-processed HTML directly to `WKWebView` via `loadHTMLString()`, avoiding both the network request and the string processing.

### Layer 4 -- SwiftData (Wallet Persistence)

Wallet addresses and metadata are persisted locally using SwiftData with `ModelContainer`. This is not a cache in the traditional sense but provides the persistent state that drives all cache operations.

```swift
// StampFolioApp.swift
var sharedModelContainer: ModelContainer = {
    let schema = Schema([Wallet.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    return try ModelContainer(for: schema, configurations: [config])
}()
```

## Data Flow

### Adding a New Wallet

```
User taps "+"        addWallet() saves         fetchStampsMetadata()       fetchStampsImages()
in AddWalletView  -> Wallet to SwiftData  ->   hits Stampchain API    ->   prefetches all content
                                               (cached by URLCache)       in background
                                                      │
                                    ┌─────────────────┼──────────────────┐
                                    ▼                  ▼                  ▼
                              Pixel URLs         Vector URLs         Text URLs
                              Kingfisher         URLSession +        URLSession +
                              ImagePrefetcher    viewport inject     StampContentCache
                              (.never expiry)    StampContentCache
```

Fetching is triggered **immediately** when the wallet is added (in `AddWalletView`). The sheet dismisses only after the fetch completes.

### Displaying a Stamp (Cache-First)

```
StampView .task
       │
       ▼
stamps.isEmpty? ──yes──> fetchStampsMetadata()
       │                        │
       no                       ▼
       │                 URLCache hit? ──yes──> decode JSON, display
       ▼                        │
  Display cached                no
  stamps array                  ▼
                         Network fetch -> URLCache stores -> decode -> display
                                                                        │
                                                                        ▼
                                                              fetchStampsImages() (background)
```

### Viewing a Stamp Image

```
StampAssetPixelView renders
       │
       ├── GIF + animated ON ──> KFAnimatedImage (full-res from Kingfisher cache)
       │
       └── Static / GIF OFF ──> KFImage + DownsamplingProcessor
                                       │
                                       ├── Kingfisher memory hit ──> instant display
                                       ├── Kingfisher disk hit ──> sync load, instant display
                                       └── Cache miss ──> network fetch, cache, display
```

### Viewing HTML/SVG Content

```
StampAssetVectorView renders
       │
       ▼
StampContentCache.read(url)
       │
       ├── NSCache hit ──> loadHTMLString() instantly
       │
       ├── Disk hit ──> promote to NSCache, loadHTMLString()
       │
       └── Cache miss ──> URLSession fetch
                              │
                              ▼
                         Inject viewport meta tag
                              │
                              ▼
                         StampContentCache.write()
                         (memory + disk)
                              │
                              ▼
                         loadHTMLString()
```

## Manual Refresh

Per-wallet refresh is available via a left swipe action in Settings:

```
Settings > Wallet row > Swipe right > "Refresh"
       │
       ▼
fetchStampMetadata(for: wallet, forceStampsRefresh: true)
       │
       ▼
URLCache bypassed (.reloadIgnoringLocalCacheData)
       │
       ▼
Fresh API data -> re-sort stamps -> fetchStampsImages() (re-prefetch)
```

## Memory Management

| Resource | Limit | Eviction |
|----------|-------|----------|
| Kingfisher memory cache | 100 MB | LRU eviction by Kingfisher |
| Kingfisher disk cache | Unlimited | Never expires |
| StampContentCache NSCache | 50 entries | Auto-evicted by iOS under memory pressure |
| StampContentCache disk | Unlimited | Never expires |
| URLCache memory | 10 MB | Managed by system |
| URLCache disk | 50 MB | Managed by system |
| Downsampled thumbnails | 200pt | Cached separately from originals |

Kingfisher automatically clears its memory cache on `UIApplication.didReceiveMemoryWarningNotification`. The `NSCache` in `StampContentCache` is also Apple-managed and auto-evicts under memory pressure. Disk caches persist across app launches.

## User Settings

| Setting | Key | Default | Effect |
|---------|-----|---------|--------|
| Animated Images | `performancePreview` | `true` | When off, GIFs render as static downsampled thumbnails in grids/lists |

Located in Settings > Performance.

## File Reference

| File | Role |
|------|------|
| `StampchainAPIClient.swift` | URLCache configuration, cache-first API policy, force refresh |
| `StampFolioApp.swift` | Kingfisher memory cache limit (100 MB) |
| `StampViewModel.swift` | `fetchStampsMetadata()`, `fetchStampsImages()` prefetch orchestration |
| `StampContentCache.swift` | Two-tier actor cache for HTML/SVG/text content |
| `StampAssetPixelView.swift` | Downsampled thumbnails, sync disk load, animated preview toggle |
| `StampAssetFullscreenView.swift` | Full-resolution images, sync disk load |
| `StampAssetVectorView.swift` | WKWebView with StampContentCache read/write |
| `StampAssetTextView.swift` | Text content with StampContentCache read/write |
| `AddWalletView.swift` | Immediate fetch trigger on wallet add |
| `StampView.swift` | Cache-first `.task`, deletion-only `.onChange` |
| `SettingsView.swift` | Per-wallet refresh swipe, performance preview toggle |
