# Counterparty API Integration

Reference for the Counterparty Core v2 REST API endpoints used by the Counterparty tab, and the
design decisions behind how they're wired into StampFolio.

## Base URL

```
https://api.counterparty.io:4000/v2
```

Full API reference: [apidocs.counterparty.io](https://apidocs.counterparty.io/) (also mirrored at
[counterpartycore.docs.apiary.io](https://counterpartycore.docs.apiary.io/)).

All responses share a common envelope:

```json
{
  "result": <the actual payload>,
  "next_cursor": <cursor for the next page, type varies by endpoint>,
  "result_count": <total number of matching rows>
}
```

`next_cursor` is **not** always the same type — for `/addresses/{address}/balances` it's an
integer, but for `/assets/{asset}/holders` it's a composite string like `"balances_100016"`
(since holders combine multiple holding types). StampFolio only paginates the balances endpoint
(where the cursor is a plain `Int`); for holder/dispenser counts we only read `result_count` and
never decode `next_cursor` at all, sidestepping the type inconsistency.

## Endpoints Used

### `GET /addresses/{address}/balances?verbose=true&limit=100&cursor={cursor}`

Returns every asset balance held by a wallet address. This is the primary endpoint — analogous to
Stampchain's `/stamps/balance/{address}` — and is called once per configured wallet, paginated via
`cursor`/`next_cursor` until exhausted (capped at 20 pages / ~2,000 assets as a safety limit).

With `verbose=true`, each row includes a nested `asset_info` object (`description`, `issuer`,
`owner`, `divisible`, `locked`). **`supply` is not included.** StampFolio therefore shows
**N/A** for supply until `GET /assets/{asset}` confirms it, rather than defaulting missing
supply to 0.

```json
{
  "result": [
    {
      "address": "1CounterpartyXXXXXXXXXXXXXXXUWLpVr",
      "asset": "XCPIANS",
      "asset_longname": null,
      "quantity": 3100000000000000,
      "quantity_normalized": "31000000.00000000",
      "asset_info": {
        "description": "https://xcp.fun/XCPIANS.json",
        "issuer": "1GG5F8DrvQ5TAcroB5WQPjCUxPXzZxEhp4",
        "divisible": true,
        "locked": false,
        "owner": "1GG5F8DrvQ5TAcroB5WQPjCUxPXzZxEhp4"
      }
    }
  ],
  "next_cursor": 1868050,
  "result_count": 260
}
```

`quantity_normalized` is always a decimal **string**, already divisibility-adjusted (e.g. `"1"`
for a non-divisible asset, `"31000000.00000000"` for a divisible one) — unlike Stampchain's
balance endpoint, no manual `/ 100_000_000` math is needed.

### `GET /assets/{asset}?verbose=true`

Full detail for a single asset — supply, description, issuance dates, MIME type. Used in two
places:

- **Supply hydration** after balances load (wallet add, collection fetch, pull-to-refresh).
  `CounterpartyViewModel.hydrateSupplies` calls `fetchAsset` only (no holders/dispensers),
  limited to 4 concurrent requests, and writes `CounterpartySupplyCache`
  (`Caches/counterparty_supply.json`). Cached supply is overlaid on the next launch so the
  list does not flash N/A.
- **Detail sheet** via `fetchAssetDetail`, which also loads holders, dispensers, and the first
  issuance tx hash (mirrors `StampchainAPIClient.fetchStampDetails`). That write also updates
  the supply cache.

### `GET /assets/{asset}/holders?limit=1`

Only `result_count` is read from this call — it directly gives the total holder count without
needing to paginate through the full holder list.

### `GET /assets/{asset}/dispensers?status=open&limit=1&sort=satoshirate:asc&verbose=true`

Returns the single cheapest open dispenser (BTC-priced listing) for an asset. `result_count` gives
the open-listings count, and the first (and only) result's `satoshirate_normalized` field is used
as a "floor price in BTC", directly analogous to Stampchain's `floor_price_btc`.

## Domain Model Layer

Mirrors the Stamps architecture exactly:

```
CounterpartyAssetBalance   (raw API response row, Core/Domain/Models/)
        │ transform
        ▼
CounterpartyAsset + CounterpartyAssetMarketData   (canonical domain entity)
        │ wrap
        ▼
CounterpartyDisplay   (UI layer: asset + balance + wallet)
```

- `CounterpartyAPIClient` (`Core/Data/Network/`) — actor, own `URLCache` (disk path
  `counterparty_cache`, separate from Stampchain's `stampchain_cache`), reuses the shared
  `NetworkError` enum defined in `StampchainAPIClient.swift`.
- `CounterpartyAssetImageResolver` (`Core/Data/Network/`) — actor, own `URLCache` (disk path
  `counterparty_manifest_cache`), classifies `description` via `CounterpartyArtworkURL` (CIP-25),
  rewrites `ipfs:` / `ar://` to HTTPS gateways, decodes `CounterpartyAssetManifest` (large-first),
  and falls back to Horizon posters. Only `https://` raster URLs are returned.
- `CounterpartyArtworkURL` (`Core/Data/Network/`) — CIP-25 classifier and gateway rewrite used by
  the resolver and GIF path-extension checks in the image views.
- `CounterpartySupplyCache` (`Core/Data/Cache/`) — actor, memory + `Caches/counterparty_supply.json`,
  confirmed supply from `GET /assets/{asset}`. Overlay on list bind; hydrate remaining in
  the background after balances. Not cleared on app background (unlike `detailCache`).
- `CounterpartyViewModel` (`Features/Counterparty/ViewModels/`) — `@Observable`, fetches all
  wallets concurrently with `withTaskGroup`, exposes `assets`/`isLoading`/`errorMessage`/
  `searchText`/filter sets/sort options, hydrates supply after balances, and lazily fetches
  per-asset detail (holders, floor price) only when the detail sheet opens, caching that
  market payload in memory (cleared on wallet delete and on app background, same lifecycle
  as `StampViewModel.clearMarketDataCache()`).

## Key Design Decisions

### Excluding Bitcoin Stamps

A Bitcoin Stamp's `counterpartyId` (CPID) **is** a Counterparty asset — every stamp is backed by
one. To avoid listing the same asset twice (once under the Stamps tab, once under Counterparty),
`CounterpartyViewModel.fetchAssetsMetadata` / `fetchAssetMetadata` take an `excludingCPIDs`
set (stamp names plus `asset_longname` for subassets). Callers wait for `StampViewModel` to
finish loading — including an in-flight fetch — before building that set. After a wallet is
added or stamps later finish loading, `applyStampExclusion` re-filters the **full** in-memory
Counterparty list so a stamp leaked on an earlier fetch (empty CPID set) or from another wallet
is dropped without another network round-trip.

### Resolving artwork from `description`

Counterparty assets don't carry an image URL directly. Most fungible tokens have no artwork at
all. When they do, the on-chain `description` follows CIP-25 / TokenScan conventions rather than
always being a plain `https://` JSON URL.

`CounterpartyArtworkURL.classify` maps a description to:

| Description | Result |
|---|---|
| `imgur/FILE[;title]` | `https://i.imgur.com/FILE` (direct image) |
| `ipfs:CID` / `ipfs://CID[/path]` | `https://ipfs.io/ipfs/{CID[/path]}`, then fetch as JSON or image |
| `ar://TXID[/path]` | `https://arweave.net/{TXID[/path]}`, then fetch as JSON or image |
| HTTPS URL with gif/jpg/png/webp/avif | Direct image |
| HTTPS JSON (`url.json;sha256` hash suffix stripped) | Fetch, decode `CounterpartyAssetManifest` |
| HTTPS URL without an image extension | Fetch; use if JSON or raster `image/*` MIME |
| `stamp:`, `ord:`, YouTube/SoundCloud, plain text, `http://` | Skip (Horizon) |

Inner JSON image fields get the **same** gateway rewrite. Already-HTTPS Arweave (`https://….ar.io/…`)
and HTTPS IPFS gateways are left unchanged. Only `https://` URLs are returned — HTTP is never
handed to Kingfisher (no ATS exception). One gateway per protocol (`ipfs.io`, `arweave.net`);
failures and timeouts fall through to Horizon. TokenScan HTML is not scraped.

`CounterpartyAssetManifest` ranks artwork **large-first**: `image_large_hd` → `image_large` →
`images` type `hires` → `large` → `standard` → top-level `image` → `icon` → first `images[].data`.
CIP-25 `audio` / `video` / `html` fields are ignored. The resolver still returns **one** HD (or
poster) URL. Grid/row do not fetch a second small file.

When description resolution fails, the resolver falls back to
[Horizon Market](https://horizon.market)'s public asset endpoint
(`GET https://horizon.market/api/tokens/counterparty/{asset}`). Horizon proxies HTTP-only sources
over HTTPS. `media.kind == "image"` is **not** required — audio/video tokens still show
`image_large_url ?? image_url` posters. `image_is_placeholder: true` caches `nil`.

Results (including "no artwork") are cached in memory and persisted to
`Caches/counterparty_resolved_urls.json` (`version: 2`). Version 2 dropped pre-CIP-25 mappings
(old ranking, no gateway rewrite). Settings wallet refresh passes `forceRefresh` to re-resolve.

`CounterpartyAssetImageView` uses that single URL with the same dual-resolution Kingfisher pattern
as Stamps: grid/row downsample to `CollectionImageThumbnail.size` (200pt) and still
`.cacheOriginalImage()`; detail and `CounterpartyAssetFullscreenContent` decode the original (no
processor). Path-extension `.gif` URLs use `KFAnimatedImage` when Animated GIF is on (grid/row)
or always in detail/fullscreen. Horizon proxy URLs often have no extension and stay static
`KFImage`. Prefetch in `fetchAssetsImages()` still warms **originals** only.

### Full toolbar and grid parity with Stamps

The Counterparty tab (`CounterpartyView`) matches the Stamps tab's toolbar: view mode
(`CounterpartyAssetCardView` grid vs. `CounterpartyAssetRowView` list, stored under
`@AppStorage("counterpartyViewMode")`), a slideshow (`CounterpartyAssetFullscreenView`, a simpler
page-based viewer than `StampAssetFullscreenView` since Counterparty content is image-only), a filter menu
(`CounterpartyViewModel.activeDivisibleFilters`/`activeLockedFilters`/`activeAssetTypeFilters`),
sort, and settings.

### Holdings view, not a DEX/marketplace view

This implementation ships the wallet-holdings view first (matching the Stamps/Ordinals pattern),
since `CounterpartyView` is wallet-scoped like the other tabs. A future iteration could add
order/dispenser browsing using the same `CounterpartyAPIClient`.

## Related Documents

- [STAMPCHAIN-API.md](STAMPCHAIN-API.md) — the equivalent reference for the Stamps tab
- [DOMAIN-MODELS.md](DOMAIN-MODELS.md) — the five-model architecture this mirrors
- [CACHING.md](CACHING.md) — caching layers across the app
