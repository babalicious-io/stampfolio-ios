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
GET /stamps?type=classic                          # ✅ Works - returns ~26,000 positive stamps
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

## Key Findings

1. **The API does NOT return a `type` field** in stamp objects - only supports `?type=` for filtering
2. **POSH is a subset of CURSED** - all POSH stamps are cursed, but not all cursed stamps are POSH
3. **SRC-20 and SRC-101** may not use the stamps endpoint at all (separate protocol)
4. **Collection endpoint doesn't exist** in v2 API
5. **Both cursed and posh return the same stamps** in recent results - distinction may be historical

## Testing Methodology

All tests performed on 2026-02-10 against https://stampchain.io/api/v2

```bash
# Verified with actual curl commands
curl "https://stampchain.io/api/v2/stamps?type=classic&limit=1"
curl "https://stampchain.io/api/v2/stamps?type=cursed&limit=100"
curl "https://stampchain.io/api/v2/stamps?type=posh&limit=100"
curl "https://stampchain.io/api/v2/stamps?ident=SRC-721&limit=1"
curl "https://stampchain.io/api/v2/stamps/-11"
curl "https://stampchain.io/api/v2/stamps/balance/1GPon5BBwZJBSvGbj3b973TQ1XMXgDbPwt"
```
