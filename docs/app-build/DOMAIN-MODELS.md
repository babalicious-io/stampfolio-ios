# Domain Models

This document provides an overview of the five core domain models in StampFolio and explains their relationships, responsibilities, and data flow.

## Overview

StampFolio uses a clear separation of concerns across five distinct domain models:

1. **WalletConfig** - Local wallet configuration
2. **WalletBalanceData** - API response data
3. **StampData** - Core domain entity
4. **StampMarketData** - Market information
5. **StampDataDisplay** - UI presentation layer

---

## Model Descriptions

### 1. WalletConfig

**File:** `Core/Domain/Models/WalletConfig.swift`

**Purpose:** Represents a Bitcoin wallet address configured by the user for local persistence.

**Key Characteristics:**
- Persisted locally using SwiftData
- User-configurable properties (address, label, color)
- No API data - purely configuration

**Properties:**
```swift
- id: UUID
- address: String           // Bitcoin address
- label: String?            // User-defined name
- colorName: String         // UI color identifier
- addedDate: Date          // When wallet was added
```

**Usage:**
- Users add wallets in Settings
- App fetches stamps for each configured wallet
- Wallets can be edited, deleted, and resynced

---

### 2. WalletBalanceData

**File:** `Core/Domain/Models/WalletBalanceData.swift`

**Purpose:** Direct representation of the API response from the Stampchain `/stamps/balance/{address}` endpoint.

**Key Characteristics:**
- API response model (implements `Codable`)
- Contains stamp information + user's balance for that stamp
- Includes custom `BalanceValue` enum to handle API's mixed types (Double or String)
- Temporary - transformed into `StampDataDisplay` for use in the app

**Properties:**
```swift
- assetId: String?          // API: "ident"
- stampId: Int              // API: "stamp" (positive/negative number)
- counterpartyId: String    // API: "cpid"
- balance: Double           // User's balance of this stamp
- divisible: Bool           // Whether stamp is divisible
- creatorAddy: String?      // Creator's address
- creatorName: String?      // Creator's name
- fileType: String?         // API: "stamp_mimetype"
- editionSupply: Int?       // API: "supply"
- stampUrl: String?         // Image URL
- txHash: String?           // Transaction hash
- address: String?          // Wallet address
- stampType: String?        // Computed: "classic", "cursed", "posh"
```

**Special Handling:**
- Custom decoder to handle `BalanceValue` (Double or String)
- `stampType` is computed by `StampchainAPIClient` based on:
  - `stampId > 0` → "classic"
  - `stampId < 0` + numeric CPID → "cursed"
  - `stampId < 0` + named CPID → "posh"

---

### 3. StampData

**File:** `Core/Domain/Models/StampData.swift`

**Purpose:** Core domain model representing a Bitcoin Stamp. This is the canonical representation used throughout the app.

**Key Characteristics:**
- Rich domain entity with computed properties
- Includes optional market data
- Provides utility methods (URL generation, file type checks)
- Used for both API responses and in-memory representation

**Properties:**
```swift
- stampType: String         // "classic", "cursed", "posh"
- assetId: String?          // Stamp identifier (e.g., "STAMP", "SRC-721")
- stampId: Int              // Stamp number (positive/negative)
- counterpartyId: String    // CPID
- creatorAddy: String?
- creatorName: String?
- editionSupply: Int
- fileType: String?
- fileSize: Int?
- divisible: Bool
- blockTime: Date?
- blockIndex: Int?
- txHash: String?
- fileHash: String?
- marketData: StampMarketData?  // Optional market info
- stampUrl: String?
```

**Computed Properties:**
```swift
- id: Int                   // Uses stampId as identifier
- stampchainURL: URL?       // Link to stampchain.io
- formattedStampId: String  // "#12345" or "#-398"
- formattedCounterpartyId: String
- isImage, isGIF, isSVG, isHTML, isText, isAudio, isVideo, etc.
```

**Usage:**
- Created from `WalletBalanceData` during API response processing
- Created from API `/stamps/{id}` endpoint for details
- Used throughout the app for business logic
- Contains sample data for previews

---

### 4. StampMarketData

**File:** `Core/Domain/Models/StampMarketData.swift`

**Purpose:** Contains market-related information for a stamp (pricing, ownership, etc.).

**Key Characteristics:**
- Embedded within `StampData` as optional property
- Separate concern from core stamp data
- Could be fetched independently from market APIs

**Properties:**
```swift
- floorPrice: Double?       // Floor price in BTC
- lastSalePrice: Double?    // Most recent sale price
- holderCount: Int?         // Number of holders
- totalSupply: Int?         // Total circulating supply
```

**Usage:**
- Currently optional in `StampData`
- Potential for future market data features
- Could be fetched from separate market APIs

---

### 5. StampDataDisplay

**File:** `Core/Domain/Models/StampDataDisplay.swift`

**Purpose:** UI-layer wrapper that combines stamp data with user-specific information (balance, wallet).

**Key Characteristics:**
- Presentation layer model
- Combines `StampData` with user's balance information
- Used exclusively by Views and ViewModels
- Not persisted or sent to APIs

**Properties:**
```swift
- stamp: StampData          // The core stamp data
- balance: Double           // User's balance (how many they own)
- divisible: Bool           // Whether fractional ownership is allowed
- walletAddress: String?    // Which wallet owns this stamp
```

**Initializers:**
```swift
init(from walletBalance: WalletBalanceData)  // From API response
init(from stamp: StampData)                  // From stamp only (balance = 0)
```

**Usage:**
- Created in `CollectionViewModel` from API responses
- Used by all collection views (grid, list, detail)
- Provides context-aware display (shows which wallet owns what)

---

## Data Flow

### 1. Initial Load Flow

```
User adds wallet address in Settings
         ↓
    WalletConfig saved to SwiftData
         ↓
CollectionViewModel fetches stamps for each wallet
         ↓
StampchainAPIClient calls /stamps/balance/{address}
         ↓
API returns JSON → decoded to [WalletBalanceData]
         ↓
StampchainAPIClient computes stampType for each item
         ↓
CollectionViewModel transforms to [StampDataDisplay]
         ↓
StampDataDisplay wraps StampData + balance info
         ↓
Views render stamps
```

### 2. Model Transformation Pipeline

```
┌─────────────────┐
│  WalletConfig   │  (Local persistence)
│  SwiftData      │
└────────┬────────┘
         │ Used to fetch
         ↓
┌─────────────────────┐
│ WalletBalanceData   │  (API Response)
│ From Stampchain API │
└────────┬────────────┘
         │ Transform
         ↓
┌─────────────────────┐
│   StampData         │  (Core Domain)
│   + StampMarketData │  (Optional)
└────────┬────────────┘
         │ Wrap
         ↓
┌─────────────────────┐
│  StampDataDisplay   │  (UI Layer)
│  stamp + balance    │
└─────────────────────┘
         │
         ↓
    Views render
```

### 3. Relationship Diagram

```
┌──────────────────────────────────────────────────────┐
│                     UI Layer                         │
│                                                      │
│  ┌────────────────────────────────────────────┐      │
│  │         StampDataDisplay                   │      │
│  │  ┌──────────────────────────────────┐      │      │
│  │  │        StampData                 │      │      │
│  │  │  ┌────────────────────────┐      │      │      │
│  │  │  │   StampMarketData      │      │      │      │
│  │  │  │   (optional)           │      │      │      │
│  │  │  └────────────────────────┘      │      │      │
│  │  └──────────────────────────────────┘      │      │
│  │  + balance                                 │      │
│  │  + walletAddress                           │      │
│  └────────────────────────────────────────────┘      │
└──────────────────────────────────────────────────────┘
                       ↑
                       │ Created from
                       │
┌──────────────────────────────────────────────────────┐
│                   API Layer                          │
│                                                      │
│  ┌────────────────────────────────────────────┐      │
│  │       WalletBalanceData                    │      │
│  │  (Direct API response model)               │      │
│  └────────────────────────────────────────────┘      │
└──────────────────────────────────────────────────────┘
                       ↑
                       │ Fetched using
                       │
┌──────────────────────────────────────────────────────┐
│                Persistence Layer                     │
│                                                      │
│  ┌────────────────────────────────────────────┐      │
│  │         WalletConfig                       │      │
│  │  (SwiftData - user's wallet addresses)     │      │
│  └────────────────────────────────────────────┘      │
└──────────────────────────────────────────────────────┘
```

---

## Key Design Decisions

### Why Separate Models?

1. **Single Responsibility Principle**
   - Each model has one clear purpose
   - Changes to API structure don't affect UI
   - Changes to UI don't affect core domain

2. **Type Safety**
   - `WalletBalanceData` handles API quirks (mixed types, null values)
   - `StampData` provides clean, validated domain model
   - `StampDataDisplay` ensures UI always has complete context

3. **Testability**
   - Models can be tested independently
   - Mock data at each layer
   - Clear boundaries for unit tests

4. **Flexibility**
   - API changes only affect `WalletBalanceData`
   - UI changes only affect `StampDataDisplay`
   - Core business logic in `StampData` remains stable

### Why WalletBalanceData Instead of Direct StampData?

The `/stamps/balance/{address}` endpoint returns data that:
- Mixes stamp metadata with user-specific balance info
- Has inconsistent types (e.g., `balance` can be Double or String)
- Includes wallet-specific fields not relevant to core stamp data

By having `WalletBalanceData` as an intermediary:
- We handle API-specific quirks in one place
- We can transform/compute values before domain model creation
- We keep `StampData` clean and API-agnostic

### Why StampDataDisplay Instead of Using StampData Directly?

Views need both:
- Stamp information (from `StampData`)
- User context (which wallet, how many they own)

`StampDataDisplay` combines these concerns for the presentation layer while keeping the core `StampData` model focused on stamp properties only.

### Why Compute stampType Instead of Using API Field?

The Stampchain API's `?type=` parameter is for filtering input, not a returned field. The API returns `type: null` for all stamps. Therefore:
- We fetch all stamps in one call (avoiding duplicates from overlapping filters)
- We compute type locally based on business rules:
  - Positive stamp numbers → "classic"
  - Negative + numeric CPID → "cursed"  
  - Negative + named CPID → "posh"

This gives us reliable, consistent type classification.

---

## Usage Examples

### Fetching and Displaying Stamps

```swift
// 1. Fetch from API
let walletBalances = try await apiClient.fetchStampsByWallet(address)
// Returns: [WalletBalanceData]

// 2. Transform to display models
let displayStamps = walletBalances.map { StampDataDisplay(from: $0) }
// Creates: [StampDataDisplay] with embedded StampData

// 3. Render in view
ForEach(displayStamps) { displayStamp in
    StampCardView(
        displayStamp: displayStamp,  // Has stamp + balance info
        onTap: { selectedStamp = displayStamp }
    )
}
```

### Accessing Data in Views

```swift
struct StampCardView: View {
    let displayStamp: StampDataDisplay
    
    var body: some View {
        VStack {
            // Access stamp data
            Text(displayStamp.stamp.formattedStampId)
            
            // Access balance info
            Text("Balance: \(displayStamp.balance)")
            
            // Access computed properties
            if displayStamp.stamp.isImage {
                StampImageView(url: displayStamp.stamp.stampUrl)
            }
            
            // Access market data if available
            if let marketData = displayStamp.stamp.marketData {
                Text("Floor: \(marketData.floorPrice ?? 0)")
            }
        }
    }
}
```

### Filtering by Stamp Type

```swift
// In CollectionViewModel
var filteredStamps: [StampDataDisplay] {
    stamps.filter { displayStamp in
        // Access computed stampType from core model
        activeIdentFilters.contains(displayStamp.stamp.stampType)
    }
}
```

---

## Model File Locations

```
StampFolio/Core/Domain/Models/
├── WalletConfig.swift          # Local persistence
├── WalletBalanceData.swift     # API response
├── StampData.swift             # Core domain
├── StampMarketData.swift       # Market info
└── StampDataDisplay.swift      # UI presentation
```

---

## Data Fetching Strategy

### API Constraints (Verified 2026-02-11)

**Critical Finding**: The `/stamps/balance/{address}` endpoint returns `market_data` structure but with **all values zeroed/null**.

This means:
- ✅ Balance endpoint: Fast, provides stamp inventory and basic data
- ❌ Balance endpoint: Cannot provide holder counts, floor prices, or dispenser data
- ✅ Individual stamp endpoint (`/stamps/{id}`): Required for actual market data

See `DATA-FETCHING-STRATEGY.md` for complete implementation plan.

### Two-Tier Loading Approach

**Tier 1: Initial Load (Balance Endpoint)**
- `WalletBalanceData` → Basic stamp information
- `StampDataDisplay` → UI presentation without market data
- Supports grid view (no market data needed)

**Tier 2: On-Demand (Individual Stamp Endpoint)**
- `StampData` + `StampMarketData` → Complete stamp details
- Fetched lazily when needed (row view, detail view)
- Viewport-based loading + caching

### Model Support for Lazy Loading

Each model supports this strategy:

1. **WalletBalanceData**: Lightweight API response for inventory
2. **StampData**: Complete stamp details (fetched on-demand)
3. **StampMarketData**: Actual market data (optional, fetched on-demand)
4. **StampDataDisplay**: Wrapper with optional `marketData` property
5. **WalletConfig**: Independent local configuration

## Future Considerations

### Potential Enhancements

1. **Additional Domain Models**
   - `Collection` - Group stamps by series/artist
   - `Transaction` - Track stamp transfers
   - `Favorite` - User-saved stamps

2. **Model Evolution**
   - Keep API models (WalletBalanceData) flexible
   - Keep domain models (StampData) stable
   - Version API responses if needed

3. **Performance Optimization**
   - ✅ Viewport-based loading (planned)
   - ✅ Market data caching (planned)
   - Prefetching for just-outside viewport
   - Persistent cache for market data

---

## Summary

The five-model architecture provides:
- **Clear separation** between API, domain, and presentation
- **Type safety** with Swift's strong typing
- **Flexibility** to evolve each layer independently
- **Maintainability** with single-responsibility models
- **Testability** with well-defined boundaries
- **Performance** through two-tier loading strategy

This architecture scales well as the app grows and requirements evolve.

## Related Documents

- `DATA-FETCHING-STRATEGY.md` - Complete data fetching implementation plan
- `STAMPCHAIN-API-VERIFICATION.md` - API behavior verification results
- `STAMPCHAIN-API.md` - API endpoint documentation
- `CACHING.md` - Caching strategies
