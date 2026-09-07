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
│  stamps 40MB │         │ (CP artwork URLs)   │         │  Memory      │
│  CP 70MB     │         │ + supply JSON map   │         │              │
│  Disk never  │         │ Caches/...json      │         │  Disk        │
└──────────────┘         └─────────────────────┘         └──────────────┘
  ProtocolImageCache          description → image URL      API JSON
  (named, not default)        asset → confirmed supply     Stampchain +
                              (nil URL = no artwork)       Counterparty

┌────────────────────────────┐   ┌──────────────────────────────┐
│    StampContentCache       │   │ StampVectorSnapshotCache     │
│  NSCache + disk files      │   │ NSCache + PNG disk           │
│  HTML / SVG / Text stamps  │   │ HTML/SVG collection stills   │
└────────────────────────────┘   └──────────────────────────────┘
```

Counterparty holdings are image-only (no HTML/SVG/text viewer). `StampContentCache` and `StampVectorSnapshotCache` are Stamps-only.

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

Handles raster image loading and caching for **Stamps** (JPEG, PNG, WebP, GIF) and **Counterparty artwork**. Named caches in `ProtocolImageCache` — `ImageCache.default` is unused for protocol images. Warmed at launch in `StampFolioApp.init`.

| Property | Stamps | Counterparty |
|----------|--------|--------------|
| Cache name | `stamps` | `counterparty` |
| Memory | 40 MB | 70 MB |
| Disk | Unlimited, never expire | Unlimited, never expire |
| Disk load | Synchronous (`.loadDiskFileSynchronously()`) | Same |
| Downsampling | 200pt grid/row thumbnails | Same (`CollectionImageThumbnail.size`) |
| Original caching | Always (`.cacheOriginalImage()` + `.originalCache`) | Same |

Omitting `.originalCache` would keep full-size files on `ImageCache.default`. Views use `.protocolCache(_:)`; prefetchers use `ProtocolImageCache.options(for: ProtocolImageCache.stamps)` (or `.counterparty`). `thumbnailOptions(for:)` adds the 200pt downsampler for the Static GIF path, and `prefetch(_:options:retain:progress:)` wraps `ImagePrefetcher` in an awaitable call the download overlay uses to wait for its first 20 images.

Named disk folders are separate from the old default Kingfisher cache. Existing default files are **not** migrated — first launch after this change re-downloads artwork once.

```swift
enum ProtocolImageCache {
    static let stamps = makeCache(name: "stamps", memoryBytes: 40 * 1024 * 1024)
    static let counterparty = makeCache(name: "counterparty", memoryBytes: 70 * 1024 * 1024)
}
```

#### Dual-Resolution Caching

Grid and row views use `DownsamplingImageProcessor` at `CollectionImageThumbnail.size` (200pt), drastically reducing memory. The `.cacheOriginalImage()` modifier ensures the full-resolution original is also saved to disk for the detail view. Stamps (`StampAssetPixelView`) and Counterparty (`CounterpartyAssetImageView` thumbnail mode) share that size.

```swift
// StampAssetPixelView / CounterpartyAssetImageView thumbnail -- grid/row
KFImage(url)
    .protocolCache(ProtocolImageCache.stamps) // or .counterparty
    .loadDiskFileSynchronously()
    .setProcessor(DownsamplingImageProcessor(size: CollectionImageThumbnail.size))
    .scaleFactor(UIScreen.main.scale)
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

Counterparty uses the same dual-resolution Kingfisher pattern on one HD URL (CIP-25 / Horizon poster): grid/row `DownsamplingImageProcessor(CollectionImageThumbnail.size)` + `.cacheOriginalImage()`; detail and fullscreen decode the original. Bytes live in `ProtocolImageCache.counterparty`. GIF path extensions use `KFAnimatedImage` like Stamps; Horizon URLs without an extension stay static. Wallet refresh re-resolves artwork URLs and re-prefetches; it does **not** delete existing Kingfisher files. A new URL downloads; the same URL is a cache hit. HTTPS-only: HTTP description links are rejected and Horizon is tried instead.

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

Vector stamps (HTML/SVG) fetched from the network have a `<meta viewport>` tag injected before caching. This pre-processing happens once during prefetch. Collection cells do **not** treat `loadHTMLString()` as visually instant — WebKit still has to parse and paint. Collection previews use a rendered bitmap from `StampVectorSnapshotCache` (below). Fullscreen still loads HTML into `WKWebView`.

### Layer 3.5 -- StampVectorSnapshotCache (HTML/SVG collection stills)

A two-tier actor cache of HTML/SVG collection stills. Fullscreen and slideshow keep a live `WKWebView` and do not read this cache.

| Property | Value |
|----------|-------|
| Memory tier | `NSCache<NSString, UIImage>`, 50 entries max |
| Disk tier | PNG files in `Caches/stamp_vector_snapshots/` |
| Key | SHA-256 of URL + `light`/`dark` + `.1000px` |
| Expiration | Never |
| Capture | Offscreen 1000×1000pt WKWebView → 1000×1000px bitmap, scaled to 200pt (fit, no crop) |
| Capture delay | 5s after `didFinish` so HTML animation can settle |

Disk is wiped when `stampVectorSnapshotCacheVersion` increments (currently 3) so older center-cropped files are not reused.

`fetchStampsImages()` (first collection load, **add wallet**, per-wallet refresh) writes HTML into `StampContentCache`, then enqueues each vector URL on `StampVectorSnapshotPrefetcher` as soon as that HTML is ready. The prefetcher is one 1000×1000pt off-screen `WKWebView` (serial). Collection cells **display** those stills; they do not overwrite the cache. A notification refreshes visible cells when a snapshot is stored.

When **Animated HTML** is on, `StampVectorWebViewPool` reuses collection `WKWebView`s across view-mode changes (exclusive URL checkout, idle LRU ~20). Details use unpooled WebKit when live. Turning the toggle off drains idle views and shows snapshots only.

#### Animated HTML Handling

A user-configurable `htmlPerformancePreview` setting (Settings > Performance) controls collection/detail/fullscreen HTML/SVG:

- **Animated HTML OFF** (default): cached 200pt still from the 1000×1000px prefetch; no collection WebKit once the snapshot exists. Fullscreen shows that still, with an eye control to reveal live `WebContentView`.
- **Animated HTML ON**: snapshot placeholder, then a live (pooled in grid/list) `WKWebView`. Fullscreen is live with no eye control.

Fullscreen GIFs always use `KFAnimatedImage`, even when Static GIF is on in the collection.

### Layer 4 -- Counterparty resolved artwork URLs

Counterparty assets do not include an image URL. `CounterpartyAssetImageResolver` maps asset name → artwork URL (or "none") via CIP-25 classification (`CounterpartyArtworkURL`), HTTPS gateway rewrite, large-first JSON ranking, then Horizon posters (`image_large_url` even when `kind` is not `"image"`).

| Property | Value |
|----------|-------|
| Memory | `[String: URL?]` on the resolver actor (`nil` = no artwork) |
| Disk | `Caches/counterparty_resolved_urls.json` (`version: 2`, empty string = no artwork) |
| Manifest HTTP cache | `counterparty_manifest_cache` URLCache |
| Expiration | Persists across launches; re-resolved only when `forceRefresh` is true |
| Artwork bytes | Kingfisher disk, never expire (same dual-res as Stamps: 200pt grid, original fullscreen, one URL) |

Version 2 of the JSON map is not compatible with the unversioned pre-CIP-25 file (different ranking and no `ipfs:` / `ar://` rewrite). The old file is deleted on first launch after this change.

```
fetchAssetsMetadata / fetchAssetMetadata
       │
       ▼
fetchAssetsImages()  (not awaited)
       │
       ├── resolveImageURL (memory → JSON disk → network)
       │
       └── ImagePrefetcher (ProtocolImageCache.options(for: ProtocolImageCache.counterparty))
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
User taps "+"        addWallet() saves         AssetDownloadCoordinator
in AddWalletView  -> Wallet to SwiftData  ->   sheet dismisses immediately
                                               "Downloading Assets" popup
                                                      │
                                    ┌─────────────────┴──────────────────┐
                                    ▼                                    ▼
                              Stamps for that wallet              Counterparty for that wallet
                              fetchAssetMetadata               fetchAssetMetadata
                              (startBackgroundWork: false)     (startBackgroundWork: false)
                                    │                                    │
                                    │                          hydrateSuppliesAndWait()
                                    │                          (issuance dates before sorting)
                                    ▼                                    ▼
                              newest 20 previews                 newest 20 artwork URLs
                              (pixel + HTML snapshot)            (resolve, then Kingfisher)
                                    └─────────────────┬──────────────────┘
                                                      ▼
                                             popup closes, grids appear
                                             remainder keeps caching
```

Fetching starts **on confirm**. Add Wallet dismisses as soon as the wallet is saved, then the
shared overlay takes over. See [Download Overlay](#download-overlay) below.

### Download Overlay

`AssetDownloadCoordinator` (app-level `@Observable`, injected in `StampFolioApp`) owns the
**Downloading Assets** popup. Collection view models do not own it — they conform to
`ProtocolDownloadSource` and expose a two-phase cache:

| Phase | Method | Behavior |
|-------|--------|----------|
| Gate | `prefetchPriorityDownloads` | Awaits the newest `min(20, visualCount)` previews |
| Remainder | `prefetchRemainderDownloads` | Fire-and-forget for everything else |

- The bar is determinate from the first frame and starts at **1%** until gate totals exist (and
  while completed is still 0), so the fill is visible during metadata fetch instead of a spinner.
  Progress is the **sum** of each enabled protocol's gate (20 stamps + 15 CP art = 35). A protocol
  with no visual assets is instantly done, and failures still count so the popup cannot hang.
- Disabled protocols (`showStamps` / `showCounterparty` / `showOrdinals`) are skipped. Ordinals
  uses `OrdinalsDownloadSource`, a no-op that reports 0 until that tab ships.
- Presented on both [`MainTabView`](../../StampFolio/App/MainTabView.swift) and
  [`SettingsView`](../../StampFolio/Features/Settings/Views/SettingsView.swift), because Settings
  is a sheet above the tabs and the default tab order starts on Ordinals.
- **First wallet** sets `withholdsCollections`, so Stamps and Counterparty keep showing
  `CollectionLoadingView` and appear together when the popup closes. Extra wallets stay in
  Settings and leave the existing grids alone.
- **Cold start and per-wallet Refresh show no popup** — those keep the silent prefetch.
- Collection `.task`, Search, and Slideshow skip a full metadata fetch while the overlay is
  presented (`blocksCollectionFetch`) or a load is already in flight (`isLoading`). A competing
  `fetchAssetsMetadata` would cancel Kingfisher and HTML snapshot waiters and close the popup
  early. The dimmed overlay also eats taps so tabs cannot start that path by accident.

Newest-first ordering is why `block_time` (Stamps) and `first_issuance_block_time` (Counterparty)
are decoded up front. Counterparty verbose balances usually omit issuance time, so the coordinator
awaits `hydrateSuppliesAndWait` before picking the newest 20; artwork URLs are then resolved in
batches of 20 so a large collection is not fully resolved just to fill the gate. Both hydration
and that resolve walk are capped at 20 seconds; whatever arrived is used and the rest continues
after the popup closes. Assets with no artwork never block it. Background hydration re-sorts
once when it finishes so Date-newest is not stuck on name order.

Turning **Animated GIF** off runs the same overlay for GIF thumbnails, using
`ProtocolImageCache.thumbnailOptions` so the cached processed key matches what the grids request
(`DownsamplingImageProcessor(CollectionImageThumbnail.size)`). If collection tabs have never
been opened, metadata is fetched first so the GIF lists are not empty. Turning it back on shows
no popup.

### Ordinals hook

`OrdinalsDownloadSource` is a no-op `ProtocolDownloadSource` (`visualCount = 0`) so the overlay
does not wait on that tab today. When `OrdinalsViewModel` ships, replace the no-op — do not add a
second overlay or a third Settings path.

The view model must:

1. Conform to `ProtocolDownloadSource`.
2. Fetch inscription metadata for the new wallet (same add-wallet call the coordinator already
   makes for Stamps and Counterparty).
3. Decode a creation / inscription date and default the collection sort to newest-first.
4. `prefetchPriorityDownloads` — cache `min(20, visualCount)` newest previews (Kingfisher or the
   inscription renderer), await each result, count failures so the popup cannot hang.
5. `prefetchRemainderDownloads` — fire-and-forget everything the gate skipped.
6. `prefetchPriorityStaticGIFs` / `prefetchRemainderStaticGIFs` — newest GIF thumbs at
   `CollectionImageThumbnail.size` when Animated GIF is turned off.
7. Honor `showOrdinals`: the coordinator already skips disabled protocols via `UserDefaults`.

Give Ordinals its own `ProtocolImageCache` named cache (Stamps and Counterparty already do not
share one LRU). Overlay UI, Settings extra-wallet, and Static GIF entry points stay unchanged.

### Displaying a Stamp (Cache-First)

```
StampView .task
       │
       ▼
assets.isEmpty && !isLoading && !overlay?
       │
      yes──> fetchAssetsMetadata()
       │            │
       no           ▼
       │     URLCache hit? ──yes──> decode JSON, display
       ▼            │
  Display cached    no
  stamps array      ▼
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
       ├── Snapshot cache hit ──> show UIImage immediately
       │         │
       │         └── Animated HTML ON ──> attach pooled WKWebView (skip load if already painted)
       │
       └── Snapshot miss ──> WKWebView + spinner
                 │
                 ├── StampContentCache.read ──> loadHTMLString()
                 │         (NSCache / disk / network + viewport inject)
                 │
                 └── prefetch didFinish ──> wait 5s ──> 1000×1000px snapshot, scale to 200pt
```

`loadHTMLString()` is not visually instant. Instant collection display is the PNG snapshot (and a pooled WebView that already loaded that URL).

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

Collection **Try Again** force-refreshes every wallet the same way. Kingfisher, `StampContentCache`, and `StampVectorSnapshotCache` are not cleared.

## Memory Management

| Resource | Limit | Eviction |
|----------|-------|----------|
| Kingfisher stamps memory | 40 MB | LRU in `ProtocolImageCache.stamps` |
| Kingfisher Counterparty memory | 70 MB | LRU in `ProtocolImageCache.counterparty` |
| Kingfisher disk cache | Unlimited | Never expires (named folders, not `ImageCache.default`) |
| StampContentCache NSCache | 100 entries | Auto-evicted by iOS under memory pressure |
| StampContentCache disk | Unlimited | Never expires |
| StampVectorSnapshotCache NSCache | 50 entries | Auto-evicted by iOS under memory pressure |
| StampVectorSnapshotCache disk | Unlimited | Never expires |
| StampVectorWebViewPool idle | ~20 WKWebViews | LRU; drained on memory warning or Animated HTML off |
| CP resolved URL map | One JSON file | Replaced on each resolve; bypassed on force refresh |
| CP confirmed supply map | One JSON file | Overlay on launch; rewritten after GET /assets; force refresh refetches |
| Stampchain URLCache memory/disk | 10 MB / 50 MB | Managed by system |
| Counterparty URLCache memory/disk | 5 MB / 25 MB | Managed by system |
| CP manifest URLCache memory/disk | 5 MB / 20 MB | Managed by system |
| Downsampled thumbnails | 200pt | Cached separately from originals |

Kingfisher automatically clears its memory cache on `UIApplication.didReceiveMemoryWarningNotification`. The `NSCache` tiers in `StampContentCache` and `StampVectorSnapshotCache` are also Apple-managed and auto-evict under memory pressure. `StampVectorWebViewPool` drains idle WebViews on the same memory warning. Disk caches persist across app launches.

## User Settings

| Setting | Key | Default | Effect |
|---------|-----|---------|--------|
| Animated HTML | `htmlPerformancePreview` | `false` | When off (default), HTML/SVG stamps show a cached snapshot in grids, lists, details, and fullscreen. Turn on for live WebKit. Fullscreen eye reveals the original HTML. |
| Animated Images | `performancePreview` | `true` | When off, GIFs render as static frames in grids/lists only. Fullscreen GIFs always animate. Turning it off also caches the newest 20 GIF thumbs per protocol. |

Located in Settings > Performance.

## File Reference

| File | Role |
|------|------|
| `NetworkRequestExecutor.swift` | Shared URLCache session, cache-first policy, force refresh |
| `StampchainAPIClient.swift` | Stampchain cache path (10/50 MB) |
| `CounterpartyAPIClient.swift` | Counterparty cache path (5/25 MB) |
| `CounterpartyAssetImageResolver.swift` | Manifest URLCache, versioned asset→URL map, CIP-25 then Horizon, force re-resolve |
| `CounterpartyArtworkURL.swift` | CIP-25 classifier, `ipfs:` / `ar://` HTTPS rewrite, GIF extension check |
| `CounterpartySupplyCache.swift` | Persisted asset→supply map, overlay then GET /assets confirm |
| `ProtocolImageCache.swift` | Named stamps (40 MB) and Counterparty (70 MB) Kingfisher caches, awaitable prefetch |
| `AssetDownloadCoordinator.swift` | Downloading Assets popup state, per-protocol 20-image gate, `ProtocolDownloadSource` |
| `DownloadingAssetsOverlay.swift` | Glass popup with theme-tinted determinate progress bar |
| `StampFolioApp.swift` | `ProtocolImageCache.warm()` at launch, injects the download coordinator |
| `StampViewModel.swift` | `fetchAssetsMetadata()`, `fetchStampsImages()` prefetch, newest-first priority/remainder downloads |
| `CounterpartyViewModel.swift` | `fetchAssetsMetadata()`, `fetchAssetsImages()` resolve + prefetch, `hydrateSupplies()` / `hydrateSuppliesAndWait()` |
| `StampContentCache.swift` | Two-tier actor cache for HTML/SVG/text stamp content |
| `StampVectorSnapshotCache.swift` | Two-tier actor cache for 1000×1000px → 200pt HTML/SVG stills |
| `StampVectorSnapshotPrefetcher.swift` | Serial offscreen WKWebView snapshot prefetch after HTML cache |
| `StampVectorWebViewPool.swift` | Exclusive URL-keyed WKWebView reuse for collection cells |
| `StampAssetPixelView.swift` | Downsampled thumbnails, sync disk load, animated preview toggle |
| `StampAssetFullscreenView.swift` | Full-resolution images, sync disk load |
| `StampAssetVectorView.swift` | Snapshot-first HTML/SVG preview, pooled WKWebView when animated |
| `StampAssetTextView.swift` | Text content with StampContentCache read/write |
| `CounterpartyAssetImageView.swift` | Thumbnail 200pt vs original; KFAnimatedImage for `.gif`; resolver-backed artwork |
| `CollectionViewComponents.swift` | `CollectionImageThumbnail.size` (200pt); `FullscreenOriginalRevealButton` |
| `AddWalletView.swift` | Save, dismiss, hand the new wallet to the download coordinator |
| `StampView.swift` | Cache-first `.task` (skips while overlay / `isLoading`), deletion-only `.onChange` |
| `SearchView.swift` / `SlideshowToolbarItem.swift` | Same overlay/`isLoading` guard before a full fetch |
| `SettingsView.swift` | Per-wallet refresh swipe, GIF and HTML performance preview toggles, overlay host |
