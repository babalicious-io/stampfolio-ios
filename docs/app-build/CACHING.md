# StampFolio Caching System

Overview of the multi-tier caching architecture used to deliver instant, offline-capable browsing. Bitcoin Stamps are immutable on-chain, so stamp content is cached permanently and never expires. Counterparty artwork is treated the same once resolved (Kingfisher disk never expires); resolved URL mappings persist across launches and are re-fetched only on a manual wallet refresh. Confirmed Counterparty supply is stored the same way (`Caches/counterparty_supply.json`) because verbose balances omit it.

## Architecture

StampFolio uses these caching layers:

```
┌──────────────────────────────────────────────────────────────────────────┐
│                             User Interface                               │
│  Stamp views          CounterpartyAssetImageView          Detail sheets  │
└──────┬────────────────────────────┬────────────────────────────┬─────────┘
       │                            │                            │
       ▼                            ▼                            ▼
┌──────────────┐         ┌─────────────────────┐         ┌──────────────┐
│  Kingfisher  │         │ Resolved URL map    │         │   URLCache   │
│  Memory      │         │ (CP artwork URLs)   │         │  Memory      │
│  (100 MB)    │         │ + supply JSON map   │         │              │
│  Disk        │         │ Caches/...json      │         │  Disk        │
│  (never)     │         └─────────────────────┘         │              │
└──────────────┘                                         └──────────────┘
  Stamp pixels +              description → image URL      API JSON
  CP artwork                  asset → confirmed supply     Stampchain +
                              (nil URL = no artwork)       Counterparty

┌────────────────────────────┐
│    StampContentCache       │
│  NSCache + disk files      │
│  HTML / SVG / Text stamps  │
└────────────────────────────┘
```

Counterparty holdings are image-only (no HTML/SVG/text viewer). `StampContentCache` is Stamps-only.

### Layer 1 -- URLCache (API Responses)

Caches raw JSON from Stampchain and Counterparty Core. Both clients share `NetworkRequestExecutor` with separate disk paths.

| Client | Memory | Disk | Disk path |
|--------|--------|------|-----------|
| Stampchain | 10 MB | 50 MB | `stampchain_cache` |
| Counterparty Core | 5 MB | 25 MB | `counterparty_cache` |
| CP manifests / Horizon | 5 MB | 20 MB | `counterparty_manifest_cache` |

| Property | Value |
|----------|-------|
| Default policy | `.returnCacheDataElseLoad` |
| Force refresh policy | `.reloadIgnoringLocalCacheData` |

The default policy serves cached API data whenever available, and only hits the network on a cache miss. Settings per-wallet **Refresh** (and collection **Try Again**) pass `forceRefresh: true`, which switches the request to `.reloadIgnoringLocalCacheData`.

```swift
func perform(_ url: URL, forceRefresh: Bool = false) async throws -> (Data, URLResponse) {
    var request = URLRequest(url: url)
    if forceRefresh {
        request.cachePolicy = .reloadIgnoringLocalCacheData
    }
    return try await session.data(for: request)
}
```

### Layer 2 -- Kingfisher (Pixel Images)

Handles raster image loading and caching for **Stamps** (JPEG, PNG, WebP, GIF) and **Counterparty artwork**. Configured at app startup in `StampFolioApp`.

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

Counterparty uses the same Kingfisher options on `CounterpartyAssetImageView` (`.cacheOriginalImage()`, `.diskCacheExpiration(.never)`, `.loadDiskFileSynchronously()`). Wallet refresh re-resolves artwork URLs and re-prefetches; it does **not** delete existing Kingfisher files. A new URL downloads; the same URL is a cache hit.

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

### Layer 4 -- Counterparty resolved artwork URLs

Counterparty assets do not include an image URL. `CounterpartyAssetImageResolver` maps asset name → artwork URL (or "none") from the on-chain `description` and, if needed, Horizon Market.

| Property | Value |
|----------|-------|
| Memory | `[String: URL?]` on the resolver actor (`nil` = no artwork) |
| Disk | `Caches/counterparty_resolved_urls.json` (empty string = no artwork) |
| Manifest HTTP cache | `counterparty_manifest_cache` URLCache |
| Expiration | Persists across launches; re-resolved only when `forceRefresh` is true |
| Artwork bytes | Kingfisher disk, never expire (same as Stamps) |

```
fetchAssetsMetadata / fetchAssetMetadata
       │
       ▼
fetchAssetsImages()  (not awaited)
       │
       ├── resolveImageURL (memory → JSON disk → network)
       │
       └── ImagePrefetcher (.cacheOriginalImage, .diskCacheExpiration(.never))
```

Full-collection loads cancel in-flight prefetch. Add-wallet and per-wallet refresh prefetch only that wallet's assets and do not cancel an existing full prefetch.

### Layer 4.5 -- Counterparty confirmed supply

Verbose `GET /addresses/{address}/balances` omits `supply` from nested `asset_info`. StampFolio does not treat that as 0 — the detail sheet shows **N/A** until supply is confirmed.

`CounterpartySupplyCache` stores confirmed supply (plus issuance timestamps) keyed by asset name after `GET /v2/assets/{asset}`.

| Property | Value |
|----------|-------|
| Memory | `[String: Entry]` on the cache actor |
| Disk | `Caches/counterparty_supply.json` |
| Source | `GET /v2/assets/{asset}?verbose=true` (via `fetchAsset`, not `fetchAssetDetail`) |
| Expiration | Persists across launches; not cleared on app background |
| Refetch | Cache miss after overlay; every listed asset when `forceRefresh` is true |
| Concurrency | 4 in-flight asset requests |

```
fetchAssetsMetadata / fetchAssetMetadata
       │
       ├── overlay in-memory hydrated supply
       ├── overlay CounterpartySupplyCache (instant on later launches)
       ├── assign assets (unknown supply displays as N/A)
       │
       ├── fetchAssetsImages()  (not awaited)
       └── hydrateSupplies()    (not awaited)
              │
              └── GET /assets/{asset}  (URLCache + JSON disk)
```

Full-collection loads cancel in-flight hydration. Add-wallet and per-wallet refresh hydrate only that wallet's assets. Opening a detail sheet also writes the supply cache via `fetchAssetDetail`.

Do **not** fold this into `detailCache` — that bag also holds holders/floor price and is cleared on background.

### Layer 5 -- SwiftData (Wallet Persistence)

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
User taps "+"        addWallet() saves         fetchAssetMetadata(new wallet)
in AddWalletView  -> Wallet to SwiftData  ->   sheet dismisses immediately
                                               fetch runs in background
                                                      │
                                    ┌─────────────────┴──────────────────┐
                                    ▼                                    ▼
                              Stamps for that wallet              Counterparty for that wallet
                              fetchStampsImages()                 fetchAssetsImages()
                              (new URLs only,                     resolve URLs + Kingfisher
                               does not cancel full prefetch)     (incremental)
                                                                  hydrateSupplies()
                                                                  overlay cache, then GET /assets
                                                                  (incremental, concurrency 4)
```

Fetching starts **on confirm**. Add Wallet dismisses as soon as the wallet is saved; collection loading shows on the tab if this is the first wallet.

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

Per-wallet refresh is a leading swipe on the wallet row in Settings:

```
Settings > Wallet row > Swipe from leading edge > "Refresh"
       │
       ▼
fetchAssetMetadata(wallet, forceRefresh: true)   // Stamps, then Counterparty
       │
       ├── API URLCache bypassed (.reloadIgnoringLocalCacheData)
       │
       ├── Stamps: merge list, fetchStampsImages() for that wallet only
       │         (Kingfisher skips URLs already on disk)
       │
       └── Counterparty: merge list, fetchAssetsImages(forceRefresh: true)
                 re-resolve artwork URLs (skip memory + JSON disk)
                 prefetch new/changed image URLs into Kingfisher
                 hydrateSupplies(forceRefresh: true) — refetch supply, rewrite JSON cache
```

Collection **Try Again** force-refreshes every wallet the same way. Kingfisher and `StampContentCache` are not cleared.

## Memory Management

| Resource | Limit | Eviction |
|----------|-------|----------|
| Kingfisher memory cache | 100 MB | LRU eviction by Kingfisher |
| Kingfisher disk cache | Unlimited | Never expires |
| StampContentCache NSCache | 50 entries | Auto-evicted by iOS under memory pressure |
| StampContentCache disk | Unlimited | Never expires |
| CP resolved URL map | One JSON file | Replaced on each resolve; bypassed on force refresh |
| CP confirmed supply map | One JSON file | Overlay on launch; rewritten after GET /assets; force refresh refetches |
| Stampchain URLCache memory/disk | 10 MB / 50 MB | Managed by system |
| Counterparty URLCache memory/disk | 5 MB / 25 MB | Managed by system |
| CP manifest URLCache memory/disk | 5 MB / 20 MB | Managed by system |
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
| `NetworkRequestExecutor.swift` | Shared URLCache session, cache-first policy, force refresh |
| `StampchainAPIClient.swift` | Stampchain cache path (10/50 MB) |
| `CounterpartyAPIClient.swift` | Counterparty cache path (5/25 MB) |
| `CounterpartyAssetImageResolver.swift` | Manifest URLCache, persisted asset→URL map, force re-resolve |
| `CounterpartySupplyCache.swift` | Persisted asset→supply map, overlay then GET /assets confirm |
| `StampFolioApp.swift` | Kingfisher memory cache limit (100 MB) |
| `StampViewModel.swift` | `fetchAssetsMetadata()`, `fetchStampsImages()` prefetch |
| `CounterpartyViewModel.swift` | `fetchAssetsMetadata()`, `fetchAssetsImages()` resolve + prefetch, `hydrateSupplies()` |
| `StampContentCache.swift` | Two-tier actor cache for HTML/SVG/text stamp content |
| `StampAssetPixelView.swift` | Downsampled thumbnails, sync disk load, animated preview toggle |
| `StampAssetFullscreenView.swift` | Full-resolution images, sync disk load |
| `StampAssetVectorView.swift` | WKWebView with StampContentCache read/write |
| `StampAssetTextView.swift` | Text content with StampContentCache read/write |
| `CounterpartyAssetImageView.swift` | KFImage never-expire disk cache, resolver-backed artwork |
| `AddWalletView.swift` | Save, dismiss, fetch only the new wallet |
| `StampView.swift` | Cache-first `.task`, deletion-only `.onChange` |
| `SettingsView.swift` | Per-wallet refresh swipe, performance preview toggle |
