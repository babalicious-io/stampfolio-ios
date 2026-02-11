# Data Fetching Strategy

## Overview

This document outlines the data fetching strategy for StampFolio, based on verified API behavior and constraints.

### Key Requirements

1. **Market Data Display**
   - Grid view: No market data needed
   - Row/List view: Show `holder_count` and `floor_price_btc`
   - Available on: iPhone (landscape mode) + iPad (all orientations)

2. **Cache Management**
   - Memory-only cache during active session
   - ✅ Clear cache on app close/termination
   - ✅ Clear cache on wallet deletion
   - ✅ Fresh data on every app launch

3. **Performance**
   - Fast initial load using balance endpoint
   - Lazy loading of market data (viewport-based)
   - Concurrent fetching of visible stamps

## API Verification Summary

### Balance Endpoint Limitations (CRITICAL)

**Finding**: The `/stamps/balance/{address}` endpoint returns a `market_data` structure but with **all values zeroed/null**.

| Field | Balance Endpoint | Individual Stamp Endpoint |
|-------|------------------|---------------------------|
| `holder_count` | Always 0 ❌ | Actual values ✅ |
| `open_dispensers_count` | Always 0 ❌ | Actual values ✅ |
| `floor_price_btc` | Always null ❌ | Actual values ✅ |
| `recent_sale_price_btc` | Always null ❌ | Actual values ✅ |

**Tested**: Stamps #1, #11, #420, #1000 (2026-02-11)

See `STAMPCHAIN-API-VERIFICATION.md` for complete test results.

### Endpoint Capabilities

| Endpoint | Purpose | Provides |
|----------|---------|----------|
| `/stamps/balance/{address}` | Wallet inventory | Stamp IDs, ownership, balances |
| `/stamps/{id}` | Complete stamp data | Full metadata + actual market data |

## Requirements

### Grid View (Current)
- Display stamp images in grid layout
- Show basic info (stamp number, balance)
- **No market data required**
- Available on: iPhone (portrait/landscape), iPad

### List/Row View (Planned)
- Display stamps in row layout with columns
- Show `holder_count` and `floor_price_btc` per stamp
- **Requires actual market data**
- Available on: iPhone (landscape mode), iPad (portrait/landscape)

## Rejected Solutions

### ❌ Solution 1: Decode Market Data from Balance Endpoint
**Reason**: Balance endpoint returns empty/zeroed market data values. Cannot be used for display.

### ❌ Solution 2: Background Batch Fetch All Stamps
**Reason**: User explicitly rejected. Unnecessary API load for stamps user may never view in detail.

## ✅ Proposed Solution: Smart Viewport-Based Loading

### Strategy Overview

Use a **two-tier data model** with **lazy market data fetching**:

1. **Initial Load**: Use balance endpoint (fast, lightweight)
   - Identifies which stamps user owns
   - Provides basic display data (image URLs, stamp numbers, balances)
   - Sufficient for grid view

2. **On-Demand Fetch**: Fetch individual stamp data as needed
   - Triggered when user switches to row view
   - Fetch only stamps currently visible in viewport
   - Cache fetched data to avoid re-fetching

### Implementation Details

#### Phase 1: Two-Tier Data Model

**Tier 1: `WalletBalanceData` (from balance endpoint)**
```swift
// Already have from initial wallet load
- stamp_id, tx_hash, cpid
- stamp_url, stamp_mimetype
- balance, supply, locked
- creator, creator_name
- market_data: nil/empty (ignored)
```

**Tier 2: `StampData` + `StampMarketData` (from individual stamp endpoint)**
```swift
// Fetched on-demand
StampData:
- All fields from WalletBalanceData
- Plus: file_size, block_time, block_index, keyburn

StampMarketData:
- floor_price_btc, recent_sale_price_btc
- holder_count, open_dispensers_count
- volume_24h/7d/30d_btc
- last_updated, data_quality_score
```

#### Phase 2: Viewport-Based Fetching

**When user switches to row view:**

1. **Determine Visible Range**
   ```swift
   // Get stamps currently visible on screen
   let visibleStamps = calculateVisibleStamps(scrollPosition, viewportHeight)
   ```

2. **Check Cache**
   ```swift
   // Filter out already-fetched stamps
   let stampsToFetch = visibleStamps.filter { 
       !marketDataCache.contains($0.stampId) 
   }
   ```

3. **Batch Fetch**
   ```swift
   // Fetch multiple stamps concurrently
   await fetchMarketData(for: stampsToFetch)
   ```

4. **Update on Scroll**
   ```swift
   // As user scrolls, fetch next visible stamps
   onScroll { newVisibleRange in
       fetchMarketDataForRange(newVisibleRange)
   }
   ```

#### Phase 3: Caching Strategy

**Memory Cache**
```swift
// In CollectionViewModel
@State private var marketDataCache: [Int: StampMarketData] = [:]

// Update when fetched
marketDataCache[stampId] = fetchedMarketData
```

**Cache Invalidation (REQUIRED)**

1. **On App Close/Termination**
   - Clear all cached market data
   - Ensures fresh data on next launch
   ```swift
   .onDisappear {
       marketDataCache.removeAll()
   }
   
   // Or in AppDelegate/SceneDelegate
   func sceneDidEnterBackground(_ scene: UIScene) {
       viewModel.clearMarketDataCache()
   }
   ```

2. **On Wallet Deletion**
   - Clear cache when user deletes a wallet
   - Prevents stale data from deleted wallets
   ```swift
   func deleteWallet(_ wallet: WalletConfig) {
       // Delete wallet
       modelContext.delete(wallet)
       
       // Clear market data cache
       marketDataCache.removeAll()
   }
   ```

3. **On Wallet Change**
   - Clear cache when switching between wallets
   - Ensures correct data for active wallet

**Why Memory-Only Cache**
- Fresh data on every app launch
- No stale market data persisted to disk
- Simple implementation
- Market data changes frequently (prices, holders, dispensers)

### Data Flow Diagram

```
User adds wallet address
        ↓
Fetch /stamps/balance/{address}
        ↓
Create [WalletBalanceData] → [StampDataDisplay]
        ↓
Display in Grid View ✅ (no market data needed)
        |
        ↓ (User switches to Row View - iPhone landscape or iPad)
        |
Get visible stamps in viewport
        ↓
Check marketDataCache
        ↓
Fetch missing: /stamps/{id} for each visible stamp
        ↓
Update StampDataDisplay with StampMarketData
        ↓
Display holders + floor price in Row View ✅
        |
        ↓ (User scrolls)
        |
Repeat for newly visible stamps
        |
        ↓ (User closes app OR deletes wallet)
        |
Clear marketDataCache
        ↓
Fresh data on next app launch ✅
```

## Implementation Steps

### Step 1: Update `StampDataDisplay` Model
Add optional `StampMarketData` property and loading states:

```swift
struct StampDataDisplay: Identifiable {
    // Existing properties from WalletBalanceData
    let stamp: StampData
    let balance: Double
    let ownerAddress: String
    
    // NEW: Optional market data (nil until fetched)
    var marketData: StampMarketData?
    var isLoadingMarketData: Bool = false
    
    // Computed properties for UI
    var holderCount: Int? {
        marketData?.holderCount
    }
    
    var floorPrice: Double? {
        marketData?.floorPriceBTC
    }
}
```

### Step 2: Add Market Data Fetching to ViewModel

```swift
// In CollectionViewModel
@State private var marketDataCache: [Int: StampMarketData] = [:]

func fetchMarketDataForVisibleStamps(_ visibleStamps: [StampDataDisplay]) async {
    // Filter stamps that need market data
    let stampsToFetch = visibleStamps.filter { 
        marketDataCache[$0.stamp.stampId] == nil 
    }
    
    // Mark as loading
    for stampDisplay in stampsToFetch {
        if let index = stamps.firstIndex(where: { $0.id == stampDisplay.id }) {
            stamps[index].isLoadingMarketData = true
        }
    }
    
    // Fetch concurrently
    await withTaskGroup(of: (Int, StampMarketData?).self) { group in
        for stampDisplay in stampsToFetch {
            group.addTask {
                let fullData = try? await apiClient.fetchStampDetails(stampDisplay.stamp.stampId)
                return (stampDisplay.stamp.stampId, fullData?.marketData)
            }
        }
        
        for await (stampId, marketData) in group {
            if let marketData = marketData {
                // Update cache
                marketDataCache[stampId] = marketData
                
                // Update display stamps
                if let index = stamps.firstIndex(where: { $0.stamp.stampId == stampId }) {
                    stamps[index].marketData = marketData
                    stamps[index].isLoadingMarketData = false
                }
            }
        }
    }
}
```

### Step 3: Update Row View with Viewport Detection

```swift
// In StampRowView or CollectionView
ScrollView {
    LazyVStack {
        ForEach(filteredStamps) { stampDisplay in
            StampRowView(displayStamp: stampDisplay)
                .onAppear {
                    // Fetch market data when row appears in list view
                    // Applies to: iPhone (landscape) + iPad (all orientations)
                    if viewModel.displayMode == .list {
                        Task {
                            await viewModel.fetchMarketDataIfNeeded(for: stampDisplay)
                        }
                    }
                }
        }
    }
}
```

### Step 4: Add API Client Method

```swift
// In StampchainAPIClient
func fetchStampDetails(_ stampId: Int) async throws -> StampDetailResponse {
    let url = "\(baseURL)/stamps/\(stampId)"
    // ... existing fetch implementation
    // Returns StampData with populated StampMarketData
}
```

### Step 5: Implement Cache Clearing

```swift
// In CollectionViewModel
func clearMarketDataCache() {
    marketDataCache.removeAll()
    
    // Clear market data from display stamps
    for index in stamps.indices {
        stamps[index].marketData = nil
        stamps[index].isLoadingMarketData = false
    }
}
```

```swift
// In SettingsViewModel - Update deleteWallet method
func deleteWallet(_ wallet: WalletConfig, viewModel: CollectionViewModel) {
    modelContext.delete(wallet)
    
    // Clear market data cache when wallet deleted
    viewModel.clearMarketDataCache()
    
    try? modelContext.save()
}
```

```swift
// In StampFolioApp or SceneDelegate
.onAppear {
    // Initial setup
}
.onDisappear {
    // Clear cache when app closes/enters background
    viewModel.clearMarketDataCache()
}

// OR in AppDelegate if using UIKit lifecycle
func sceneDidEnterBackground(_ scene: UIScene) {
    // Clear all cached market data
    NotificationCenter.default.post(name: .clearMarketDataCache, object: nil)
}

func sceneWillTerminate(_ scene: UIScene) {
    // Clear all cached market data
    NotificationCenter.default.post(name: .clearMarketDataCache, object: nil)
}
```

## Performance Considerations

### Initial Load (Balance Endpoint)
- **Fast**: Single API call per wallet
- **Lightweight**: Only basic stamp data
- **Sufficient**: For grid view display

### Row View (Individual Stamp Endpoints)
- **Lazy**: Only fetch visible stamps
- **Concurrent**: Fetch multiple stamps in parallel
- **Cached**: Avoid re-fetching on scroll back (during session)
- **Efficient**: ~5-10 stamps visible at once = 5-10 API calls
  - iPhone landscape: ~5-7 stamps visible
  - iPad: ~8-12 stamps visible

### Typical Collection Size
- Small wallets (< 50 stamps): Negligible overhead
- Medium wallets (50-200 stamps): Only fetch ~10-20 stamps if user scrolls through
- Large wallets (200+ stamps): User unlikely to view all in row view

## Trade-offs

### Pros
✅ Fast initial load (balance endpoint)
✅ No wasted API calls for stamps never viewed in detail
✅ Smooth user experience with progressive loading
✅ Efficient caching reduces redundant calls during session
✅ Works seamlessly for both grid and row views
✅ Fresh data on every app launch (no stale cache)
✅ Clean cache on wallet deletion

### Cons
⚠️ Slight delay when first switching to row view
⚠️ Requires loading indicators for market data
⚠️ Additional complexity in ViewModel
⚠️ Market data refetched on every app launch (by design)

### Mitigation
- Show loading skeleton/spinner in row view
- Prefetch market data for first ~10-20 stamps when switching to row view
- Cache aggressively during session to minimize repeated fetches
- Memory-only cache (cleared on app close) ensures fresh data

## Future Enhancements

1. **Prefetching**: Fetch market data for stamps just outside viewport (prefetch next 5-10 stamps)
2. **Intelligent Orientation Detection**: Detect landscape mode on iPhone to trigger row view automatically
3. **Background Refresh**: Update cached data periodically during active session
4. **Batch API**: If Stampchain API adds batch endpoint, use it for multiple stamps (e.g., `/stamps/batch?ids=1,11,420`)

**Explicitly NOT Planned**:
- ❌ Persistent cache to disk - Cache cleared on app close for fresh data by design

## Related Documents

- `DOMAIN-MODELS.md` - Data model architecture
- `STAMPCHAIN-API-VERIFICATION.md` - API testing results
- `STAMPCHAIN-API.md` - API documentation
- `CACHING.md` - Caching strategies

## Status

- [x] API verification complete (4 stamps tested)
- [x] Strategy documented
- [x] Cache clearing requirements defined
- [ ] Implementation pending user approval
- [ ] Step 1: Update StampDataDisplay
- [ ] Step 2: Add market data fetching to ViewModel
- [ ] Step 3: Update Row View with viewport detection (iPhone landscape + iPad)
- [ ] Step 4: Add API client method
- [ ] Step 5: Implement cache clearing (app close + wallet delete)
- [ ] Step 6: Test and optimize

## Implementation Priority

1. **High Priority**: Steps 1-4 (core functionality)
2. **High Priority**: Step 5 (cache clearing - required for fresh data)
3. **Medium Priority**: Prefetching and optimization
