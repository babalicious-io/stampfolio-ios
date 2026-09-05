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
  `counterparty_manifest_cache`), resolves an asset's artwork URL from its `description` field
  (see "Resolving artwork from `description`" below) and decodes `CounterpartyAssetManifest`
  (`Core/Domain/Models/`) when the description points to a JSON manifest.
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
all, but some reference it indirectly through the `description` field, which is sometimes a URL
to an external JSON manifest (e.g. `description: "https://xcp.fun/XCPIANS.json"`) containing the
real image URL (`image`, or an `images: [{type, data}]` array), and occasionally a direct link to
the image itself.

`CounterpartyAssetImageResolver` (`Core/Data/Network/`) is an actor that resolves this indirection.
It tries the on-chain `description` first: fetches it once, tries to decode it as a
`CounterpartyAssetManifest`, and falls back to treating the `description` URL as a direct image
link if the response's MIME type is `image/*`. Results (including "no artwork") are cached in
memory and persisted to `Caches/counterparty_resolved_urls.json` so cold launches skip Horizon
and dead hosts. Settings wallet refresh passes `forceRefresh` to re-resolve from the network.

Many `description` links date back to Counterparty's 2014-2016 "Rare Pepe" era and their hosts
have since died, moved, or serve **plain HTTP only** (which iOS's App Transport Security blocks
by default — no ATS exception is added for this, see below). When the direct attempt fails, or
`description` isn't a URL at all, the resolver falls back to
[Horizon Market](https://horizon.market)'s public asset endpoint
(`GET https://horizon.market/api/tokens/counterparty/{asset}`, documented as part of their
[`horizon-market-client`](https://github.com/UnspendableLabs/Horizon-Market-Client) API surface,
served with `Access-Control-Allow-Origin: *`). Horizon (and pepe.wtf, which it shares an S3/Arweave
artwork archive with) maintains its own permanent, re-hosted copy of this artwork instead of
depending on the fragile original hosts, and proxies any HTTP-only sources over HTTPS
(`/api/asset-media/proxy?url=...`) — so this fallback recovers artwork for assets whose on-chain
`description` link is now dead, without StampFolio needing any ATS exceptions of its own. If
Horizon's own catalog has no real artwork either (`image_is_placeholder: true`), the resolver
caches `nil` — that asset genuinely has no recoverable artwork anywhere.

`CounterpartyAssetImageView` (`Features/Counterparty/Views/`) wraps this resolver and renders the
artwork with Kingfisher (`KFImage`, same downsampling/retry/fade/`.diskCacheExpiration(.never)`
pipeline as `StampAssetPixelView`), including `.interpolation(.none)` since many of these
manifests only ever had tiny (e.g. 48×48) icons that would otherwise blur when scaled up to
card/row size. It falls back to the existing placeholder icon when there's no artwork or the
load fails, and is shared by the row, card, detail, and slideshow views so each asset's image
is only resolved once. After balances load, `CounterpartyViewModel.fetchAssetsImages()` resolves
URLs in the background and prefetches successful artwork into Kingfisher.

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
