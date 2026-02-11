# file_size_bytes API Investigation

Investigation into how many stamps have non-null `file_size_bytes` in the Stampchain API. Sample of 50+ stamps across types and list positions.

**Date:** 2026-02-11  
**API base:** `https://stampchain.io/api/v2`

---

## Summary

| Sample | With file_size_bytes | Without (null) | % with data |
|--------|----------------------|----------------|-------------|
| **50 stratified** (17 recent classic, 17 old classic, 16 cursed) | 29 | 21 | **58%** |
| Classic page 1 (50 stamps) | 50 | 0 | 100% |
| Classic page 2 (50 stamps) | 50 | 0 | 100% |
| Classic page 3 (50 stamps) | 12 | 38 | 24% |
| Classic page 4+ (50 per page) | 0 | 50 | 0% |
| Cursed (50 stamps) | ~13 | ~37 | ~26% |
| Posh (50 stamps) | ~12 | ~38 | ~24% |
| SRC-721 (20 stamps) | 3 | 17 | 15% |

**Conclusion:** `file_size_bytes` is **not** populated for most of the catalog. It is present mainly for **recently indexed classic stamps** (roughly the first ~100–120 items by default sort) and for **some** newer cursed/posh stamps. Older classic stamps and most SRC-721/cursed/posh return `null`.

---

## 50-Stamp Stratified Sample (Detailed)

### With file_size_bytes (29 stamps)

| Stamp ID | file_size_bytes |
|----------|-----------------|
| 1384305 | 198 |
| 1384304 | 184 |
| 1384303 | 211 |
| 1383563 | 1393 |
| 1383554 | 93 |
| 1374849 | 2747 |
| 1367898 | 386 |
| 1363926 | 1135 |
| 1363923 | 240 |
| 1359309 | 240 |
| 1313619 | 15311 |
| 1304118 | 361 |
| 1295281 | 425 |
| 1277539 | 395 |
| 1277504 | 579 |
| 1265676 | 62877 |
| 1263512 | 4108 |
| -1832 | 708 |
| -1831 | 716 |
| -1830 | 5495 |
| -1829 | 1842 |
| -1828 | 960 |
| -1827 | 0 |
| -1826 | 7287 |
| -1825 | 2729 |
| -1824 | 1088 |
| -1823 | 1465 |
| -1822 | 1197 |
| -1821 | 212 |

### Without file_size_bytes (21 stamps, null)

- **Classic (old):** #51346, #51332, #51315, #51314, #51313, #51312, #51311, #51310, #51309, #51308, #51307, #51306, #51270, #51269, #51268, #51267, #51266 (17 stamps)
- **Cursed:** #-1820, #-1819, #-1818, #-1817 (4 stamps)

---

## Findings by Type

### Classic (positive stamp IDs)

- **Page 1 (newest):** 50/50 have `file_size_bytes`.
- **Page 2:** 50/50 have `file_size_bytes`.
- **Page 3:** 12/50 have it (boundary region).
- **Page 4 and beyond:** 0/50 have it.
- **Interpretation:** The indexer appears to populate `file_size_bytes` only for recently processed stamps. Older classic stamps (majority of the ~26k) return `null`.

### Cursed / Posh (negative stamp IDs)

- Mixed: newer cursed/posh (e.g. -1821 to -1832) often have values; older ones (e.g. -1817 to -1820, -557, -483, etc.) are mostly `null`.
- Same pattern as classic: recent stamps have data, older do not.

### SRC-721

- 20 sampled: 3 with `file_size_bytes`, 17 null (~15% with data).

---

## Impact on StampFolio

1. **Metadata popup:** “File Size” row only shows when the API returns non-null `file_size_bytes`. For stamps like #759681 and #743242 (and most of the catalog), the API returns `null`, so the row correctly does not appear.
2. **No app bug:** The app decodes and displays `file_size_bytes` when present; absence is due to API data, not override by balance or missing decode.
3. **Expectation:** Most user stamps (older or mid-catalog) will not show file size; only the most recently indexed stamps will.

---

## Verification Commands

```bash
# Recent classic (expect non-null)
curl -s "https://stampchain.io/api/v2/stamps?limit=5&page=1" | jq '.data[].file_size_bytes'

# Old classic (expect null)
curl -s "https://stampchain.io/api/v2/stamps?limit=5&page=500" | jq '.data[].file_size_bytes'

# Single stamp (e.g. 759681 - null, 1384305 - 198)
curl -s "https://stampchain.io/api/v2/stamps/759681" | jq '.data.stamp.file_size_bytes'
curl -s "https://stampchain.io/api/v2/stamps/1384305" | jq '.data.stamp.file_size_bytes'
```
