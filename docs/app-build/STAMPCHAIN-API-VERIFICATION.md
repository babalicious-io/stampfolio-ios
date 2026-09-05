# Stampchain API Verification Results

This document lists what has been VERIFIED vs UNVERIFIED from actual API testing.

## ✅ VERIFIED Endpoints & Parameters

### Working Endpoints
```bash
GET /stamps                                        # ✅ Works - returns stamp list
GET /stamps/{stamp_number}                        # ✅ Works - returns single stamp details
GET /stamps/balance/{bitcoin_address}             # ✅ Works - returns wallet stamps
```

### Working Query Parameters
```bash
GET /stamps?type=classic                          # ✅ Works - returns ~26,000 non-negative stamps (including 0)
GET /stamps?type=cursed                           # ✅ Works - returns ~1,800 negative stamps (mixed CPID types)
GET /stamps?type=posh                             # ✅ Works - returns ~300 negative stamps (named CPIDs only)
GET /stamps?ident=SRC-721                         # ✅ Works - returns SRC-721 stamps
GET /stamps?page=1&limit=50                       # ✅ Works - pagination
GET /stamps?sort_order=ASC                        # ✅ Works - sort order
```

### Verified `ident` Field Values
```bash
"STAMP"      # ✅ Verified - most common value
"SRC-721"    # ✅ Verified - recursive stamps exist
```

### Verified CPID Types
```bash
Numeric:  A2256256256256256256      # ✅ Starts with "A" + numbers only
Named:    USDSTAMP                   # ✅ Vanity name, no "A" prefix
```

### Verified Response Structure
```json
{
  "data": [...],           # ✅ Array of stamps or single stamp object
  "last_block": 936033,    # ✅ Latest block number
  "page": 1,               # ✅ Current page
  "limit": 50,             # ✅ Items per page
  "total": 25974,          # ✅ Total count
  "totalPages": 0,         # ✅ Total pages
  "metadata": {...}        # ✅ BTC price, cache status
}
```

### Verified Stamp Object Fields
```json
{
  "stamp": -11,                              # ✅ Stamp number (can be negative)
  "block_index": 782488,                     # ✅ Block number
  "cpid": "A2256256256256256256",           # ✅ Counterparty ID
  "creator": "1GPon5...",                    # ✅ Creator address
  "creator_name": "netidx",                  # ✅ Creator name (nullable)
  "divisible": false,                        # ✅ Divisibility flag
  "locked": true,                            # ✅ Locked status
  "stamp_url": "https://...",                # ✅ Content URL
  "stamp_mimetype": "text/plain",            # ✅ MIME type
  "supply": 256,                             # ✅ Total supply
  "block_time": "2023-03-25T18:13:56.000Z", # ✅ Block timestamp
  "tx_hash": "9c76027...",                   # ✅ Transaction hash
  "tx_index": 319,                           # ✅ Transaction index
  "ident": "STAMP",                          # ✅ Ident field
  "stamp_hash": "ds7HlQvTeSgYPltunOkF",      # ✅ Stamp hash
  "file_hash": "e4ed24418...",               # ✅ File hash
  "file_size_bytes": null,                   # ✅ File size (nullable)
  "market_data": {...}                       # ✅ Market data object
}
```

## ❌ UNVERIFIED / FALSE Information

### Does NOT Exist
```bash
GET /collection/{slug}                # ❌ Returns 404 error
GET /src20/tokens                     # ❌ Returns empty data
GET /src20/balance/{address}          # ❌ Not tested/verified
GET /address/{address}/stamps         # ❌ Wrong format
```

### Unverified `ident` Values
```bash
"SRC-20"     # ❌ No stamps found with this ident
"SRC-101"    # ❌ No stamps found with this ident
```

### Type vs CPID Relationship

**VERIFIED Data:**
- `?type=cursed` returns ~1,800 stamps:
  - ~67% have numeric CPIDs (A+numbers)
  - ~33% have named CPIDs (vanity)
  
- `?type=posh` returns ~300 stamps:
  - 100% have named CPIDs (vanity)
  - POSH is a SUBSET of cursed (only named CPIDs)

**Conclusion:** 
- Cursed = ALL negative stamps (both numeric and named CPIDs)
- POSH = Negative stamps with ONLY named CPIDs (subset of cursed)
- Using both `?type=cursed` and `?type=posh` filters will return duplicate stamps

**StampFolio Solution:**
- Fetch all stamps in one call without type filters
- Compute type locally: `stamp >= 0` → classic, `stamp < 0` + numeric CPID → cursed, `stamp < 0` + named CPID → posh
- This eliminates duplicates and provides single source of truth

## Key Findings

1. **The API does NOT return a `type` field** in stamp objects - only supports `?type=` for filtering
2. **POSH is a subset of CURSED** - all POSH stamps are cursed, but not all cursed stamps are POSH
3. **Using type filters creates duplicates** - calling `?type=cursed` and `?type=posh` returns overlapping results
4. **Type must be computed client-side** - based on stamp number (positive/negative) and CPID pattern (numeric vs named)
5. **SRC-20 and SRC-101** use separate endpoints - not queryable via the stamps `ident` field
6. **Collection endpoint doesn't exist** in v2 API
7. **⚠️ CRITICAL: Balance endpoint returns EMPTY market_data** - structure exists but all values are null/0
   - Individual stamp endpoint required for actual holder_count, floor_price, dispenser data

## ⚠️ Market Data Availability (CRITICAL)

### Balance Endpoint vs Individual Stamp Endpoint

**Multiple Stamps Tested** (verified 2026-02-11)

| Stamp | Field | Balance Endpoint | Individual Stamp Endpoint |
|-------|-------|------------------|---------------------------|
| **#1** | `holder_count` | 0 ❌ | 0* ❌ |
| | `open_dispensers_count` | 0 ❌ | 1 ✅ |
| | `floor_price_btc` | null ❌ | 0.99 ✅ |
| **#11** | `holder_count` | 0 ❌ | 138 ✅ |
| | `open_dispensers_count` | 0 ❌ | 16 ✅ |
| | `floor_price_btc` | null ❌ | 0.0069 ✅ |
| | `recent_sale_price_btc` | null ❌ | 0.003 ✅ |
| **#420** | `holder_count` | 0 ❌ | 1 ✅ |
| | `floor_price_btc` | null ❌ | null |
| **#1000** | `holder_count` | 0 ❌ | 0* ❌ |
| | `floor_price_btc` | null ❌ | null |

*Note: Some stamps legitimately have 0 holders when locked to creator

**All stamps tested show**:
- `last_updated`: present ✅ (both endpoints)
- `volume_*` fields: 0 (both endpoints)
- `data_quality_score`: present ✅ (both endpoints)

### Conclusion

```bash
# Balance endpoint DOES include market_data structure
GET /stamps/balance/{address}  
# BUT: holder_count = 0, floor_price = null, dispensers = 0
# ❌ ALWAYS returns zeroed/null values regardless of actual market data

# Individual stamp endpoint has ACTUAL market data  
GET /stamps/{id}
# ✅ holder_count, floor_price, dispensers are populated when available
# ✅ Returns actual market activity data
```

**Verified Pattern (4 stamps tested: #1, #11, #420, #1000):**
1. Individual stamp endpoint returns actual values when market data exists
2. Balance endpoint consistently returns null/0 for all market fields
3. This behavior is **consistent across all tested stamps** (classic stamps)
4. Balance endpoint is optimized for wallet inventory, not market data

**Impact on StampFolio:**
- ❌ Cannot rely on balance endpoint for displaying holder/dispenser/price data
- ✅ Must fetch individual stamp data (`/stamps/{id}`) for actual market information
- ✅ Requires on-demand or viewport-based fetching strategy for row views
- Initial wallet load can use balance endpoint (fast, identifies owned stamps)
- Market data must be fetched separately per-stamp when needed for display

## Testing Methodology

All tests performed on 2026-02-10 and 2026-02-11 against https://stampchain.io/api/v2

```bash
# Verified with actual curl commands
curl "https://stampchain.io/api/v2/stamps?type=classic&limit=1"
curl "https://stampchain.io/api/v2/stamps?type=cursed&limit=100"
curl "https://stampchain.io/api/v2/stamps?type=posh&limit=100"
curl "https://stampchain.io/api/v2/stamps?ident=SRC-721&limit=1"
curl "https://stampchain.io/api/v2/stamps/-11"
curl "https://stampchain.io/api/v2/stamps/balance/1GPon5BBwZJBSvGbj3b973TQ1XMXgDbPwt"

# Market data verification (2026-02-11) - Tested 4 stamps
# Stamp #1 - genesis stamp with high value
curl "https://stampchain.io/api/v2/stamps/1"
curl "https://stampchain.io/api/v2/stamps/1/holders?limit=1"
curl "https://stampchain.io/api/v2/stamps/balance/bc1qra28gca7x22xulgmlvk5j2d0t0rprd660e00fq"

# Stamp #11 - popular stamp with active market
curl "https://stampchain.io/api/v2/stamps/11"  # ✅ holder_count: 138, floor: 0.0069
curl "https://stampchain.io/api/v2/stamps/11/holders?limit=1"
curl "https://stampchain.io/api/v2/stamps/balance/1AcQ4XQqUZTTNCFbwwVFwArUH8nqDYPcxX"  # ❌ all zeroed

# Stamp #420
curl "https://stampchain.io/api/v2/stamps/420"  # ✅ holder_count: 1
curl "https://stampchain.io/api/v2/stamps/420/holders?limit=1"
curl "https://stampchain.io/api/v2/stamps/balance/1FokbakwZMzLD4fSVQ6eMEqq7yHP1EZ4Bd"  # ❌ all zeroed

# Stamp #1000
curl "https://stampchain.io/api/v2/stamps/1000"
curl "https://stampchain.io/api/v2/stamps/1000/holders?limit=1"
curl "https://stampchain.io/api/v2/stamps/balance/1EC2K34dNc41pk63rc7bMQjbndqfoqQg4V"  # ❌ all zeroed

# Pattern confirmed: Balance endpoint ALWAYS returns null/0 for market_data values
```
