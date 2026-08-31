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
`owner`, `divisible`, `locked`), so no follow-up call is needed just to render the list.

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

Full detail for a single asset — supply, description, issuance dates, MIME type. Fetched
on-demand when the user opens the asset detail sheet (mirrors
`StampchainAPIClient.fetchStampDetails`).

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
CounterpartyAssetDisplay   (UI layer: asset + balance + wallet)
```

- `CounterpartyAPIClient` (`Core/Data/Network/`) — actor, own `URLCache` (disk path
  `counterparty_cache`, separate from Stampchain's `stampchain_cache`), reuses the shared
  `NetworkError` enum defined in `StampchainAPIClient.swift`.
- `CounterpartyViewModel` (`Features/Counterparty/ViewModels/`) — `@Observable`, fetches all
  wallets concurrently with `withTaskGroup`, exposes `assets`/`isLoading`/`errorMessage`/
  `searchText`/sort options, and lazily fetches per-asset detail (holders, floor price) only when
  the detail sheet opens, caching results in memory (cleared on wallet delete and on app
  background, same lifecycle as `CollectionViewModel.clearMarketDataCache()`).

## Key Design Decisions

### Excluding Bitcoin Stamps

A Bitcoin Stamp's `counterpartyId` (CPID) **is** a Counterparty asset — every stamp is backed by
one. To avoid listing the same asset twice (once under the Stamps tab, once under Counterparty),
`CounterpartyViewModel.fetchAssetsMetadata` accepts an `excludingCPIDs: Set<String>` parameter.
`CounterpartyView` computes this set from `CollectionViewModel.stamps` and, if Stamps haven't
loaded yet for the current wallets, proactively triggers that fetch first so the exclusion is
accurate regardless of which tab the user opens first.

### List-only UI (no image grid)

Unlike Stamps/Ordinals, most Counterparty assets have no associated artwork — they're fungible
tokens. The Counterparty tab uses a token-list layout (ticker, issuer, balance, divisible/locked
badges) rather than an image grid.

### Holdings view, not a DEX/marketplace view

`ProtocolType.counterparty.rawValue` is `"Marketplace"`, which could imply a DEX/order-book view
(`/orders`, `/dispensers` globally). This implementation ships the wallet-holdings view first
(matching the Stamps/Ordinals pattern), since `CounterpartyView` is wallet-scoped like the other
tabs. A future iteration could add order/dispenser browsing using the same `CounterpartyAPIClient`.

## Related Documents

- [STAMPCHAIN-API.md](STAMPCHAIN-API.md) — the equivalent reference for the Stamps tab
- [DOMAIN-MODELS.md](DOMAIN-MODELS.md) — the five-model architecture this mirrors
- [CACHING.md](CACHING.md) — caching layers across the app
