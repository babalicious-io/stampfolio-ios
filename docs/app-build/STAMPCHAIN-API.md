# Stampchain API Reference

Complete reference for Bitcoin Stamps API endpoints and stamp types.

## Base URL

```
https://stampchain.io/api/v2
```

## Stamp Identification & Type

### API `ident` Field Values

The `ident` field in the API response indicates the technical stamp type:

| `ident` Value | Description |
|--------------|-------------|
| `"STAMP"` | Classic Bitcoin Stamps (most stamps) |
| `"SRC-721"` | Recursive/composable NFT collections |

**Note:** SRC-20 and SRC-101 are separate protocols with their own database tables and API endpoints. They are NOT stored in the stamps table.

### Other SRC Protocols

The Bitcoin Stamps ecosystem includes additional protocols that use separate storage:

| Protocol | Description | Storage |
|----------|-------------|---------|
| **SRC-20** | Fungible token standard (similar to BRC-20) | Separate `SRC20` tables |
| **SRC-101** | Domain name service (DNS) for Bitcoin | Separate `SRC101` tables |

These protocols have their own API endpoints and are not queryable via the stamps `ident` field.

### Stamp Types

| Type | Stamp Numbers | CPID Type | `ident` Field | Total Count |
|------|--------------|-----------|---------------|-------------|
| **Classic** | Non-negative (>= 0) | Numeric or Named | "STAMP" | ~26,000 |
| **Cursed** | Negative | Numeric OR Named | "STAMP" | ~1,800 |
| **Posh** | Negative | Named only | "STAMP" | ~300 (subset of cursed) |

### Filtering by Type

The API supports filtering stamps using query parameters:

```bash
GET /stamps?type=classic    # Returns ~26,000 non-negative stamps (including 0)
GET /stamps?type=cursed     # Returns ~1,800 negative stamps (numeric AND named CPIDs)
GET /stamps?type=posh       # Returns ~300 negative stamps (ONLY named CPIDs - subset of cursed)
GET /stamps?ident=SRC-721   # Returns SRC-721 recursive stamps
```

**Note:** The API does not return a `type` field in stamp objects. The `type` parameter is only for filtering queries.

## API Endpoints

### Get All Stamps

```
GET /stamps
```

**Query Parameters:**
- `page` (integer): Page number (default: 1)
- `limit` (integer): Results per page (max: 100, default: 50)
- `type` (string): Filter by stamp type (`classic`, `cursed`, `posh`)
- `ident` (string): Filter by ident type (`STAMP`, `SRC-721`, etc.)
- `sort_order` (string): `ASC` or `DESC` (default: `DESC`)

**Examples:**
```
GET /stamps?page=1&limit=50&type=classic    # Get classic stamps
GET /stamps?page=1&limit=50&type=cursed     # Get cursed stamps (all negative - numeric AND named)
GET /stamps?page=1&limit=50&type=posh       # Get POSH stamps (negative with named CPIDs only)
GET /stamps?page=1&limit=50&ident=SRC-721   # Get SRC-721 recursive stamps
```

**Response:**
```json
{
  "data": [
    {
      "stamp": 1384305,
      "block_index": 933837,
      "cpid": "A888354448084788958",
      "creator": "bc1qkqqre5xuqk60xtt93j297zgg7t6x0ul7gwjmv4",
      "creator_name": null,
      "divisible": 0,
      "keyburn": null,
      "locked": 1,
      "stamp_url": "https://stampchain.io/stamps/...",
      "stamp_mimetype": "image/png",
      "supply": 1,
      "block_time": "2026-01-26T11:23:22.000Z",
      "tx_hash": "e94be2793462692ca8fea3a54dd90ff4b18735196a2bc426382c11959533c8ca",
      "tx_index": 1402626,
      "ident": "STAMP",
      "stamp_hash": "qwBYVca0xjvGuIzbv7hF",
      "file_hash": "31196b4818052ab599d1115bcbf4cba2",
      "file_size_bytes": 198,
      "market_data": { ... }
    }
  ],
  "last_block": 935954,
  "metadata": {
    "btcPrice": 68854.24,
    "cacheStatus": "unknown",
    "source": "cached"
  },
  "page": 1,
  "limit": 50,
  "totalPages": 0,
  "total": 25974
}
```

### Get Single Stamp Details

```
GET /stamps/{stamp_number}
```

**Example:**
```
GET /stamps/-11
GET /stamps/1384305
```

**Response:**
```json
{
  "last_block": 936029,
  "data": {
    "stamp": {
      "stamp": -11,
      "block_index": 782488,
      "cpid": "A2256256256256256256",
      "creator": "1GPon5BBwZJBSvGbj3b973TQ1XMXgDbPwt",
      "creator_name": "netidx",
      "divisible": false,
      "ident": "STAMP",
      "stamp_url": "https://stampchain.io/stamps/...",
      "stamp_mimetype": "text/plain",
      "supply": 256,
      "market_data": { ... }
    }
  }
}
```

### Get Stamps by Wallet Address

```
GET /stamps/balance/{bitcoin_address}
```

**Example:**
```
GET /stamps/balance/1GPon5BBwZJBSvGbj3b973TQ1XMXgDbPwt
```

This is the endpoint used by StampFolio to fetch user's stamp collection.

**Query Parameters (optional):**
- `type` (string): Filter by stamp type (`classic`, `cursed`, `posh`)

**Note:** While the API supports `?type=` filtering, using it can result in duplicate stamps since POSH is a subset of cursed. See StampFolio Implementation section below for the recommended approach.

## StampFolio Implementation

StampFolio uses a simplified approach to stamp type classification that avoids duplicates and provides a single source of truth:

### Implementation Strategy

1. **Single API Call**: Fetches all stamps from `/stamps/balance/{address}` without type filters
   ```swift
   GET /stamps/balance/{address}  // No ?type= parameter
   ```

2. **Local Type Computation**: Determines type client-side based on stamp characteristics:
   ```swift
   if stamp >= 0:
       type = "classic"
   else if stamp < 0 && cpid starts with "A" + only numbers:
       type = "cursed"
   else if stamp < 0 && cpid is named:
       type = "posh"
   ```

3. **Why This Approach?**
   - **Avoids Duplicates**: Using `?type=cursed` and `?type=posh` filters returns overlapping results (POSH is subset of cursed)
   - **Single Source of Truth**: Each stamp gets exactly one type assignment
   - **Simpler**: One API call instead of three separate filtered calls
   - **Efficient**: No need to deduplicate results or decide which type "wins"

### Type Classification Rules

| Stamp Number | CPID Pattern | Example CPID | Assigned Type |
|-------------|--------------|--------------|---------------|
| Non-negative (>= 0) | Any | `A888354448084788958` | `classic` |
| Negative (<0) | `A` + numbers only | `A2256256256256256256` | `cursed` |
| Negative (<0) | Named (vanity) | `USDSTAMP`, `PEPE` | `posh` |

### Code Location

- **Type Assignment Logic**: `StampAsset.resolvedStampType(stampId:counterpartyId:)` (used by `StampAsset` and `StampAssetBalance` decoders)
- **Filtering**: `StampViewModel.swift` - filters by assigned `stampType` property

## Database Schema Reference

Complete database schema: https://raw.githubusercontent.com/stampchain-io/btc_stamps/refs/heads/dev/indexer/table_schema.sql

### Key Fields in `StampTableV4`

```sql
CREATE TABLE IF NOT EXISTS `StampTableV4` (
  `stamp` int NOT NULL,                    -- Stamp number (can be negative)
  `cpid` varchar(25) DEFAULT NULL,         -- Counterparty ID
  `creator` varchar(62) COLLATE utf8mb4_bin,
  `divisible` tinyint(1) DEFAULT NULL,
  `locked` tinyint(1) DEFAULT NULL,
  `stamp_mimetype` varchar(24) DEFAULT NULL,
  `stamp_url` varchar(106) DEFAULT NULL,
  `supply` bigint unsigned DEFAULT NULL,
  `block_time` datetime NULL DEFAULT NULL,
  `tx_hash` varchar(64) NOT NULL,
  `ident` varchar(7) DEFAULT NULL,         -- "STAMP", "SRC-721", etc.
  `stamp_hash` varchar(255) DEFAULT NULL,
  `is_btc_stamp` tinyint(1) DEFAULT NULL,
  `file_size_bytes` int DEFAULT NULL,
  PRIMARY KEY (`stamp`),
  INDEX `ident_index` (`ident`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

## Testing & Verification

### Test Stamps

| Stamp Number | CPID | CPID Type | `ident` Field | Type Filter |
|-------------|------|-----------|---------------|-------------|
| #1 | A6876... | Numeric | "STAMP" | `?type=classic` |
| #1384305 | A888354448084788958 | Numeric | "STAMP" | `?type=classic` |
| #-11 | A2256256256256256256 | Numeric (A+numbers) | "STAMP" | `?type=cursed` |
| #-398 | USDSTAMP | Named (vanity) | "STAMP" | `?type=cursed` or `?type=posh` |
| #1383564 | A863311966656466479 | Numeric | "SRC-721" | `?ident=SRC-721` |

### Verify API Responses

```bash
# Test classic stamp
curl "https://stampchain.io/api/v2/stamps/1"

# Test cursed stamp
curl "https://stampchain.io/api/v2/stamps/-11"

# Test POSH stamp  
curl "https://stampchain.io/api/v2/stamps/-398"

# Test SRC-721
curl "https://stampchain.io/api/v2/stamps/1383564"
```

## Notes

1. **API Filtering**: 
   - `?type=classic` - Returns ~26,000 non-negative stamps (including 0)
   - `?type=cursed` - Returns ~1,800 negative stamps (both numeric AND named CPIDs)
   - `?type=posh` - Returns ~300 negative stamps (ONLY named CPIDs - subset of cursed)
   - `?ident=SRC-721` - Returns SRC-721 recursive stamps
   - The API does NOT return a `type` field in responses

2. **POSH is a Subset**: POSH stamps are cursed stamps with named CPIDs. All POSH stamps are cursed, but not all cursed stamps are POSH.

3. **CPID Types**: 
   - **Numeric CPID**: Starts with "A" + numbers (e.g., "A2256256256256256256") - Free to create
   - **Named CPID**: Vanity asset name (e.g., "USDSTAMP", "PEPE") - Costs 0.5 XCP to create

## Verification

All endpoints and data documented here have been verified with actual API calls on 2026-02-10.

See [API-VERIFICATION-RESULTS.md](./API-VERIFICATION-RESULTS.md) for detailed testing methodology and results.

## References

- [Stampchain Explorer](https://stampchain.io)
- [API Documentation](https://stampchain.io/docs)
- [Database Schema](https://raw.githubusercontent.com/stampchain-io/btc_stamps/refs/heads/dev/indexer/table_schema.sql)
- [Bitcoin Stamps Documentation](https://bitcoinstamps.xyz/en/)
- [Indexer Repository](https://github.com/stampchain-io/btc_stamps)
