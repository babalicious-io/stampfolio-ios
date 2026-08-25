# MicroPython Port Research: StampFolio → Pimoroni Presto

Research document for porting StampFolio stamp display capabilities to the **Pimoroni Presto** (sometimes referred to as “Hey Presto” in Pimoroni’s demo code). This is **not** a full iOS app port — it evaluates feasibility for a **desk companion / digital stamp frame** that shows Bitcoin Stamps from configured wallet addresses.

**Date:** 2026-08-25  
**Related:** [Stampchain API](./app-build/STAMPCHAIN-API.md) · [Domain Models](./app-build/DOMAIN-MODELS.md) · [Caching Strategy](./app-build/CACHING.md)

---

## Executive Summary

| Question | Answer |
|----------|--------|
| Is MicroPython suited? | **Yes** — Presto ships with MicroPython firmware, `presto`, PicoGraphics, PicoVector, and Wi-Fi helpers. |
| Can the processor handle the app? | **A focused stamp viewer, yes.** A faithful port of the full StampFolio iOS app, **no**. |
| Can we support all stamp file types (SVG, HTML, etc.)? | **Mostly, yes — with real on-device engines, not just a server proxy.** Further research (see [Deep Dive](#deep-dive--real-on-device-htmlcssjssvg-rendering) below) found that a small HTML/CSS layout engine (litehtml), a vector/SVG engine (ThorVG), and a JS engine (JerryScript) **all have working prior art on RP2040/RP2350-class hardware**. They can be built into Presto as native MicroPython C++ modules — the same pattern already used for `picographics`/`jpegdec`/`pngdec`. A server-side render proxy is still recommended as a fallback for the hardest cases (WebRTC, heavy modern CSS), but it is no longer the *only* path for SVG and interactive HTML. |

**Recommended product scope:** **StampFrame for Presto** — fetch stamps for one or more wallets from Stampchain, cache on microSD, display fullscreen with touch navigation and optional slideshow. Treat native SVG/HTML/JS rendering as an advanced, incremental capability layered on top of the core viewer — not a blocker for v1. Omit Ordinals, Counterparty, QR scanning, and rich audio/video playback.

---

## Pimoroni Presto — Hardware Specifications

| Category | Specification |
|----------|---------------|
| **Product** | Pimoroni Presto (PIM725 standalone / PIM765 starter kit) |
| **Dimensions** | ~110 × 92 × 80 mm (H × W × D, with stand) |
| **Microcontroller** | Raspberry Pi **RP2350B** (QFN-80, 48 usable GPIO) |
| **CPU** | Dual **Arm Cortex-M33** @ up to **150 MHz** (optional RISC-V Hazard3 cores — firmware-dependent) |
| **On-chip SRAM** | **520 KB** |
| **External PSRAM** | **8 MB** |
| **Flash** | **16 MB** QSPI flash (execute-in-place supported) |
| **Expandable storage** | **microSD** card slot |
| **Display** | **4″ square IPS LCD**, **480 × 480** pixels, capacitive touch overlay |
| **Wireless** | Raspberry Pi **RM2** module (Infineon **CYW43439**) — **Wi-Fi 4** (802.11 b/g/n), **Bluetooth 5.4** |
| **Ambient lighting** | **7× SK6812** (NeoPixel-compatible) RGB LEDs |
| **Audio** | **Piezo speaker** (alert tones / beeps — not hi-fi playback) |
| **USB** | **USB-C** (power + programming) |
| **Expansion** | **Qw/ST** (Qwiic / STEMMA QT) connector |
| **Debug** | 3-pin JST-SH (units manufactured after June 2025) |
| **Power** | USB-C, or **2-pin JST-PH** battery (**3.0–5.5 V**, no onboard LiPo charger) |
| **User controls** | Reset button, Boot button (usable as user button) |
| **Programming** | **MicroPython** (pre-installed) or **C/C++** (Pimoroni SDK boilerplate) |
| **Included software** | MicroPython firmware, app launcher, example apps (clock, photo frame, Wi-Fi demos) |

### Presto Software Stack (MicroPython)

| Module | Purpose |
|--------|---------|
| `presto` | Hardware abstraction — display, touch, Wi-Fi, ambient LEDs |
| `picographics` | Bitmap drawing, fonts, framebuffer |
| `picovector` | Vector paths, anti-aliased shapes, Alright Fonts (`.af`) — **not an SVG parser** |
| `jpegdec` | JPEG decode (BitBank JPEGDEC) |
| `pngdec` | PNG decode (BitBank PNGdec) — crop, scale, rotate |
| Wi-Fi helpers | Network connectivity via RM2 (e.g. EzWiFi in Pimoroni docs) |

### Display Modes

The `Presto()` constructor supports options that affect performance:

- `full_res=True` — native **480×480** (crisp, slower)
- `full_res=False` — lower internal resolution, upscaled (faster)
- `layers=1/2` — optional double-buffering via PicoGraphics layers
- `direct_to_fb=True` — draw directly to front buffer in full-res mode
- `ambient_light=True` — auto-sync rear RGB LEDs to screen content

Pimoroni’s photo-frame example recommends **pre-processing images** to **240×240** or **480×480**, **non-progressive JPEG**, because on-device resize of large images is slow.

---

## StampFolio iOS App — Relevant Context

StampFolio is a SwiftUI iOS app that displays Bitcoin Stamps from the [Stampchain API](https://stampchain.io/api/v2). For porting research, the critical subset is **stamp content rendering** and **wallet balance fetching**.

### Stamp content routing (iOS)

The iOS app routes stamps by `stamp_mimetype` (`fileType` in `StampData`):

| MIME type | iOS renderer | Endpoint |
|-----------|--------------|----------|
| `image/png`, `image/jpeg`, … | Kingfisher (`StampPixelView`) | `https://stampchain.io/s/{txHash}` |
| `image/gif` | KFAnimatedImage | `/s/{txHash}` |
| `image/webp`, `image/avif` | Kingfisher | `/s/{txHash}` |
| `image/svg+xml` | WKWebView (`StampVectorView`) | `/s/{txHash}` |
| `text/html` | WKWebView (`StampVectorView`) | `https://stampchain.io/content/{txHash}` |
| `text/plain` | Fetched text view | `/s/{txHash}` |
| `audio/*`, `video/*` | AVKit / placeholder | `/s/{txHash}` |
| `application/javascript`, `text/css`, `application/gzip` | Library badge (non-visual) | N/A |

See: `StampFolio/Core/Domain/Models/StampData.swift`, `StampFolio/Features/Collection/Views/StampCardView.swift`.

### Bitcoin Stamp payload constraints

| Format | Max payload | Notes |
|--------|-------------|-------|
| Classic (Base64 / OP_MULTISIG) | ~**7 KB** | Original pixel-art stamps (often 24×24) |
| OLGA (P2WSH binary) | ~**64 KB** (65,535 byte length prefix) | Larger artwork, 50% smaller tx size |

These limits mean stamp **downloads are tiny** compared to Presto’s **8 MB PSRAM** — memory is not the bottleneck; **decoding and rendering capability** is.

### iOS features outside Presto scope

The full app also includes:

- Multi-tab UI (Stamps, Ordinals, Counterparty, Search)
- SwiftData wallet persistence
- QR code wallet scanning (AVFoundation)
- Kingfisher image caching with downsampling
- Full-screen zoom/pan (`StampDetailView`)
- GIF animation toggle, market data, filters, settings

None of these map 1:1 to a 480×480 microcontroller display.

---

## Feasibility Assessment

### Is MicroPython suited?

**Yes.** Presto is designed for MicroPython:

- Firmware and launcher ship pre-installed
- Official Learn guide and examples (photo frame, clock, Wi-Fi)
- Built-in JPEG/PNG decoders integrated with the display stack
- Wi-Fi module supported in Pimoroni’s MicroPython builds

C/C++ via the Pimoroni SDK is an option for performance-critical paths later, but MicroPython is the correct starting point.

### Can the RP2350 handle “the app”?

**Partially — scoped to a stamp viewer.**

| Capability | Feasible? | Notes |
|------------|-----------|-------|
| HTTP GET to Stampchain API | ✅ | Wi-Fi + `urequests` / `aiohttp`-style patterns |
| JSON parsing (`ujson`) | ✅ | Balance responses are small |
| Download stamp bytes (≤64 KB) | ✅ | Fits easily in PSRAM |
| Decode PNG / JPEG | ✅ | Native `pngdec` / `jpegdec` |
| Display 480×480 with touch | ✅ | Core Presto use case |
| Cache stamps on microSD | ✅ | Mirror iOS `StampContentCache` concept |
| Slideshow / swipe navigation | ✅ | Photo-frame example is a template |
| Nearest-neighbor upscale (24×24 pixel art) | ✅ | Ideal for classic stamps |
| Animated GIF | ⚠️ | No built-in decoder; static frame or custom library |
| WebP / AVIF / BMP | ❌ on-device | Needs conversion |
| SVG rendering | ⚠️ advanced | PicoVector ≠ SVG loader, but a native **ThorVG**/NanoSVG module can parse+rasterize most non-text SVGs on-device (see deep dive) |
| HTML rendering | ⚠️ tiered, upgradable | Static HTML (no JS) on-device today; a native **litehtml** (+ JerryScript for `<script>`) module raises this ceiling substantially, with proxy as fallback |
| Audio / video playback | ❌ | Piezo only; no video decoder |
| QR wallet scanning | ❌ | No camera |
| Ordinals / Counterparty tabs | ❌ | Different protocols, heavy/browser content |
| Full SwiftUI grid with hundreds of thumbnails | ❌ | Single 480×480 screen — design for one stamp at a time |

**Performance notes from the community:** Presto can decode pre-sized JPEGs/PNGs well, but ** resizing large images on-device is slow**. A WiiM forum project noted needing an **external web service** to resize album art before display. The same pattern applies to non-native stamp formats.

---

## Stamp File Type Support Matrix

| Format | iOS | Presto native | Recommended approach |
|--------|-----|---------------|----------------------|
| **PNG** | ✅ Kingfisher | ✅ `pngdec` | Decode locally; scale to fit 480×480 |
| **JPEG** | ✅ Kingfisher | ✅ `jpegdec` | Decode locally; non-progressive preferred |
| **GIF** | ✅ animated | ⚠️ partial | Static first frame (v1); optional GIF library (v2) |
| **WebP** | ✅ | ❌ | Server/proxy → PNG or JPEG |
| **AVIF** | ✅ | ❌ | Server/proxy → PNG or JPEG |
| **BMP** | ✅ | ❌ | Server/proxy → PNG |
| **SVG** | ✅ WKWebView | ⚠️ partial (native) | On-device via ThorVG/NanoSVG module for most vector-only SVGs; server rasterize (resvg, cairosvg, etc.) as fallback for text-heavy/filtered SVGs |
| **HTML** | ✅ WKWebView | ⚠️ tiered (native) | On-device via litehtml (+ optional JerryScript for scripted canvas apps) for most layouts; server PNG snapshot as fallback for WebRTC/heavy-JS stamps |
| **text/plain** | ✅ | ✅ | Fetch + wrap text with PicoGraphics / PicoVector |
| **audio/** | ✅ AVKit | ❌ | Icon + stamp metadata only |
| **video/** | ✅ AVKit | ❌ | Icon + stamp metadata only |
| **JS / CSS / GZIP** | badge only | ❌ | Skip (not visual stamps) |
| **SRC-721** (recursive) | varies | ⚠️ | Depends on composed assets; often PNG/JPEG children |

### Can we support SVG and HTML?

**SVG:** PicoVector is not an SVG loader, but a dedicated, dependency-light **SVG parsing + rasterization engine (ThorVG or NanoSVG)** can be built into Presto's firmware as a native module and used for real on-device rendering of most vector-only SVGs — see the [deep dive](#deep-dive--real-on-device-htmlcssjssvg-rendering) below. Server rasterization remains the fallback for SVGs the engine can't fully handle (text elements, `<style>` blocks, filters).

**HTML:** your intuition is partly right. HTML stamps **are** stored on-chain as Base64 (classic) or binary (OLGA), but **Stampchain already decodes them** when you fetch over HTTP. The real question is **rendering HTML/CSS/JS without a full browser** — and further investigation found that a *small* browser-like stack (HTML/CSS layout engine + JS engine + a hand-built canvas/DOM shim) is more feasible on this hardware than initially assessed, though it is real engineering work, not a drop-in library. Details below.

---

## HTML Stamps — Base64, “Iframe”, and Workarounds

### How HTML stamps are actually stored and served

| Layer | Format | What you get |
|-------|--------|--------------|
| **On-chain / indexer DB** | Base64 string in `stamp_base64` (API field on `/stamps/{id}`) | Raw encoded payload |
| **HTTP `/s/{txHash}`** | Decoded UTF-8 HTML | Ready-to-parse markup (`Content-Type: text/html`) |
| **HTTP `/content/{txHash}`** | Same decoded HTML (iOS uses this for HTML stamps) | Used by StampFolio’s `StampVectorView` / `WKWebView` |

**You do not need to Base64-decode on Presto if you fetch from Stampchain** — the server has already done it. Base64 decode on-device is only needed if you read `stamp_base64` directly from the JSON API:

```python
import ubinascii
html = ubinascii.a2b_base64(stamp["stamp_base64"]).decode("utf-8")
```

Both classic (~7 KB) and OLGA (~64 KB) HTML payloads fit easily in Presto’s 8 MB PSRAM after decode.

### There is no iframe on Presto — but you can build the equivalent

iOS uses `WKWebView` as an isolated rendering surface (conceptually like an iframe). **Out of the box, Presto has no WebView, HTML engine, or JavaScript runtime** in MicroPython or C++ — the stock firmware ships PicoGraphics/PicoVector/`jpegdec`/`pngdec` only. A custom-built native module *can* add HTML layout (litehtml), SVG (ThorVG), and JS (JerryScript) support — see the [deep dive](#deep-dive--real-on-device-htmlcssjssvg-rendering) — but that is additional firmware engineering, not something the device does today.

What “iframe-like container” means in practice on Presto:

```
┌─────────────────────────────────────┐
│  Presto 480×480 framebuffer         │
│  ┌───────────────────────────────┐  │
│  │  "Viewport" — your render     │  │  ← You implement this in PicoGraphics
│  │  target for one stamp         │  │
│  └───────────────────────────────┘  │
│  Stamp # overlay, touch nav         │
└─────────────────────────────────────┘
```

You allocate a logical viewport and draw into it — but **you** must interpret the HTML, not load it into a browser.

### HTML stamps are not all “basic” — two tiers exist

Real examples from Stampchain (Aug 2026):

| Stamp | Size | Scripts | Feasible on Presto? |
|-------|------|---------|-------------------|
| #1462443 “Story of OLGA” | 1.2 KB | **0** — static HTML + CSS + `<img src="/s/CPID">` + text | **Yes** — on-device layout renderer (though note it uses `cqh` units, a modern-CSS gap even litehtml has — see deep dive) |
| #1465071 “STAMP·PAINT” | 28 KB | **1** — canvas drawing app | **Partial today** (static screenshot or server render); **the prime candidate for the native JerryScript + Canvas2D shim** in Phase 4a, since it's "just" canvas drawing calls with no WebRTC/WebSocket dependency |
| #1472320 “STAMPCAST” | 41 KB | **1 huge inline script** — WebRTC, WebSocket, Nostr, crypto | **No on-device, ever** — server rasterize only, regardless of engine investment (see deep dive) |

Many HTML stamps under 65 KB are **static compositions** (positioned divs, embedded images, styled text). Others are **full web apps** that require a browser and network services.

### Workaround 1 — On-device static HTML renderer (best for simple stamps)

For HTML with **no JavaScript** (or JS you intentionally ignore), implement a **minimal layout engine**:

1. Fetch decoded HTML from `https://stampchain.io/s/{txHash}`.
2. Parse a **supported subset**:
   - `<img class="s" src="/s/CPID" style="left:…%;top:…%;width:…%;height:…%">`
   - `<div class="s t" style="…font-size:…cqh;color:#…">text</div>`
   - Inline `background:#000` on `html,body`
3. For each `/s/CPID` reference → fetch child stamp → decode PNG/JPEG with `pngdec`/`jpegdec`.
4. Map percentage positions to 480×480 pixel coordinates.
5. Draw text with PicoGraphics or PicoVector (map `cqh` units approximately).
6. Cache the **composited result** as PNG on microSD.

This matches stamps like the OLGA story page, which is pure layout:

```html
<div id="c">
  <img class="s" src="/s/A492736669247841788" style="left:2.3%;top:12%;width:95.552%;height:56.492%">
  <div class="s t" style="left:3%;top:1.38%;...">The Story of OLGA</div>
  ...
</div>
```

No JS execution required — only recursive `/s/` fetches (same pattern Stampchain uses when serving HTML).

**Also handle without a browser:**

- `data:image/png;base64,...` in `<img src>` → decode Base64 locally, blit to framebuffer
- Plain text nodes → wrap and draw
- Basic colors from inline styles (`#RRGGBB`)

### Workaround 2 — Extract-and-blit (fast path)

Before building a full layout parser, scan decoded HTML for:

1. **`data:image/*;base64,`** — decode and display directly (common in small stamps).
2. **Single `<img src="/s/…">`** — fetch one child image, scale to 480×480.
3. **No visual elements found** — show placeholder with stamp number.

This covers a surprising number of simple HTML stamps with minimal code.

### Workaround 3 — Server-side render (JS-heavy stamps)

For stamps with `<script>` blocks (WebRTC, canvas animation, Nostr, etc.):

1. Presto detects `<script` in the HTML string (cheap scan).
2. Requests a **480×480 PNG snapshot** from a render proxy:
   - Headless Chromium / Playwright loads `https://stampchain.io/content/{txHash}`
   - Waits for render (or fixed timeout)
   - Returns PNG
3. Presto decodes PNG locally and caches on microSD.

This is the only viable path for interactive HTML like STAMPCAST. The stamp is ≤65 KB, but its **runtime requirements** (WebSocket, WebRTC, `window`, DOM) far exceed what an MCU can provide — size is not the limiting factor.

### Workaround 4 — Hybrid router (recommended)

```python
def render_html_stamp(tx_hash, html_bytes):
    html = html_bytes.decode("utf-8")

    if "<script" not in html.lower():
        return compose_static_html(html, viewport=480)  # Workaround 1/2

    png = fetch_render_proxy(tx_hash, size=480)         # Workaround 3
    if png:
        return decode_png(png)

    return draw_placeholder(stamp_id)                   # Fallback
```

```mermaid
flowchart TD
    fetch[Fetch /s/txHash or decode stamp_base64]
    classify{Contains script tag?}
    static[Static HTML composer]
    resolveImg[Resolve /s/ CPID refs]
    dataUri[Decode data:image base64]
    draw[Blit to 480x480 viewport]
    proxy[Server headless render]
    pngDec[jpegdec/pngdec]
    cache[Cache PNG on microSD]

    fetch --> classify
    classify -->|No| static
    static --> resolveImg
    static --> dataUri
    resolveImg --> draw
    dataUri --> draw
    draw --> cache
    classify -->|Yes| proxy
    proxy --> pngDec
    pngDec --> cache
```

### MicroPython vs C++ for HTML workarounds

| Approach | MicroPython | C++ |
|----------|-------------|-----|
| Base64 decode | `ubinascii.a2b_base64` | TinyBase64 / mbedtls |
| Static HTML subset parser | Practical in pure Python | Faster, same logic |
| Recursive `/s/` fetch + PNG blit | Good fit | Good fit |
| Embedded JS engine (JerryScript, etc.) | Not directly — JerryScript/litehtml/ThorVG are C/C++ libraries | **Required** — see [deep dive](#deep-dive--real-on-device-htmlcssjssvg-rendering); exposed to MicroPython as a native module |
| Real iframe/WebView | **Not available** | **Not available**, but a native litehtml+JerryScript+canvas-shim module gets meaningfully closer for a useful subset of stamps (see deep dive) |

**Recommendation:** implement Workaround 4 in MicroPython for v1. Treat native on-device rendering (litehtml/ThorVG/JerryScript as a compiled MicroPython C++ module) as a v2 "Tier 2" enhancement that slots into the same router — see the deep dive below for what's realistically achievable and what still requires the proxy.

### Summary: what you CAN do for HTML stamps

| Technique | Covers | On-device? |
|-----------|--------|------------|
| Fetch decoded HTML from Stampchain | All HTML stamps | Yes |
| Base64 decode from `stamp_base64` | All HTML stamps | Yes |
| Static layout composer (no JS) | Layout + img + text stamps | Yes |
| `data:image` Base64 extract | Many small stamps | Yes |
| Recursive `/s/` child fetch | SRC-style compositions | Yes |
| Full CSS/JS/DOM rendering | Interactive web apps | **Partial** — see deep dive; full compliance no |
| Iframe / WebView container | All HTML (like iOS) | **No** — build viewport manually, closer with native engine |
| Server PNG snapshot | JS-heavy stamps | Yes (with proxy) |

---

## Deep Dive — Real On-Device HTML/CSS/JS/SVG Rendering

This section replaces the earlier "no HTML/JS engine exists for this hardware class" assumption. Follow-up research found **working prior art** for each missing piece (HTML/CSS layout, vector/SVG rendering, JavaScript execution) specifically on RP2040/RP2350-class microcontrollers. None of it is Presto-specific or plug-and-play, but none of it needs to be invented from scratch either.

### The three missing engines, and what already runs on this class of hardware

| Need | Library | Evidence it works on RP2040/RP2350-class MCUs | License |
|------|---------|------------------------------------------------|---------|
| **HTML/CSS layout** | [litehtml](https://github.com/litehtml/litehtml) | Pure C++/STL + [gumbo-parser](https://codeberg.org/gumbo-parser/gumbo-parser) (dependency-free C99 HTML5 parser). Cross-compiled and run on **ESP32** (a comparable 32-bit MCU class) in the [`leopck/microbrowser`](https://github.com/leopck/microbrowser) project. Supports CSS2.1 fully, most of CSS3 including an actively-developed flexbox implementation; **grid layout and CSS custom properties (`var()`) are partial/branch-only** | BSD-3-Clause |
| **SVG parsing + rasterizing** | [ThorVG](https://github.com/thorvg/thorvg) (preferred) or [NanoSVG](https://github.com/memononen/nanosvg) (simpler fallback) | ThorVG: ~150–300 KB core, explicitly demonstrated running on **ESP32** microcontrollers, and is already the SVG/Lottie rendering backend inside **LVGL** (a GUI library commonly deployed on RP2040/RP2350 boards). NanoSVG: single C header, trivially portable, already informally used in embedded contexts, but parses a much smaller SVG subset | MIT (ThorVG) / zlib (NanoSVG) |
| **JavaScript execution** | [JerryScript](https://github.com/jerryscript-project/jerryscript) | Directly proven on **RP2040 *and* RP2350** by two independent open-source runtimes: **[Kaluma](https://kalumajs.org/)** ("runs minimally on microcontrollers with 300 KB ROM with 64 KB RAM") and **[mcujs](https://github.com/mcu-js/mcujs)**. Both ship on real Pico/Pico2 boards today, with REPL, modules, and a `graphics` module for driving SPI displays from JS | Apache-2.0 |

Presto's **16 MB flash, 520 KB SRAM, and 8 MB PSRAM** comfortably exceed what any of these three engines need individually — Kaluma's entire runtime fits in less RAM than a single 480×480 RGB565 framebuffer (450 KB) that Presto already allocates for the display.

### Why this changes the picture

The earlier assessment treated "no browser engine" as a hard wall. It's more accurate to say: **there is no finished browser engine for this hardware, but the three building blocks a browser engine is made of already run on it individually.** The Presto-specific work is *integration*, not invention:

1. **litehtml never draws anything itself.** It parses HTML/CSS and computes layout, then calls back into a `document_container` interface you implement — `draw_text`, `draw_background`, `draw_image`, `get_image_size`, etc. This is the *exact same shape* of integration Presto's own `picographics`, `jpegdec`, and `pngdec` MicroPython modules already do: a C/C++ library that needs someone to wire its output to the PicoGraphics framebuffer. `draw_image` calls forward to `jpegdec`/`pngdec` (raster `<img>`) or to ThorVG (inline/SVG `<img>`); `draw_text` calls forward to PicoVector's Alright Font renderer or a simple bitmap font.
2. **ThorVG/NanoSVG rasterize into a plain pixel buffer** — no different from the JPEG/PNG decoders Presto already ships; the output blits to PicoGraphics the same way.
3. **JerryScript needs a host to bind native functions into it** (`jerry_call_function`, etc.) — Kaluma's `graphics` module is a working example of exactly this pattern (JS `gc.drawRect(...)` → C draws to a display buffer). A Presto module would do the same, binding a small **Canvas2D-like API** (`fillRect`, `drawImage`, `getContext('2d')`) into JerryScript so `<script>` blocks that draw to `<canvas>` (like STAMP·PAINT) can genuinely execute instead of falling back to a screenshot.
4. **All three are C/C++ libraries**, so they integrate the same way the existing native decoders do: via MicroPython's [`USER_C_MODULES`](https://docs.micropython.org/en/latest/develop/cmodules.html) build mechanism, with a thin `extern "C"` wrapper exposing a Python-facing API (e.g. `import html_engine; html_engine.render(html_str, viewport)`).

### JerryScript heap sizing (using the 8 MB PSRAM)

By default JerryScript uses a small internal heap (default 512 KB, 16-bit compressed pointers) sized for devices with a few hundred KB of RAM total. Presto has room to be far more generous:

```
-DJERRY_SYSTEM_ALLOCATOR=ON   # delegate heap allocation to a custom allocator
-DJERRY_CPOINTER_32_BIT=ON    # required by the system allocator; supports >512KB heaps
```

With the system allocator enabled, the JerryScript heap can be backed by a block carved out of Presto's PSRAM (mapped at `0x11000000` on RP2350 via the QMI interface), giving scripts several MB to work with — vastly more headroom than any ≤64 KB HTML stamp's inline `<script>` will need. The tradeoff: PSRAM access is slower than on-chip SRAM (roughly 24 QSPI clock cycles of overhead per access), so heavy script execution will be noticeably slower than on a desktop — acceptable for a stamp viewer, not for anything latency-sensitive.

### What still has to be hand-built (the real engineering effort)

Wiring these three libraries together into something that renders real stamp HTML is genuine, unclaimed engineering work — there is no existing "litehtml + ThorVG + JerryScript" combined browser engine to adopt. Rough shape of the work, roughly ordered by effort:

| Component | Purpose | Relative effort |
|-----------|---------|------------------|
| `document_container` implementation | Bridges litehtml's layout output to PicoGraphics/PicoVector drawing calls, `jpegdec`/`pngdec` for raster `<img>`, ThorVG for SVG `<img>`/backgrounds | Moderate — mechanical but sizeable interface (~30 callback methods) |
| Font shim | `get_text_width`/`draw_text` backed by Alright Fonts (`.af`) or a simple bitmap font, since litehtml has zero built-in font/text rendering | Moderate |
| Canvas2D shim for JerryScript | Native-bound `CanvasRenderingContext2D`-subset (`fillRect`, `drawImage`, `arc`, `stroke`, pixel `getImageData`-lite) so canvas-drawing `<script>` stamps (e.g. STAMP·PAINT) can run for real | Moderate–High |
| Minimal DOM/event shim | `document.getElementById`, `addEventListener('pointerdown', …)`, `setTimeout`/`setInterval` bound into JerryScript (Kaluma/mcujs already demonstrate the event-loop pattern to reuse) | Moderate–High |
| Networking bridge | `fetch`/`XMLHttpRequest` → wrap Presto's existing HTTP client; a minimal `WebSocket` client is feasible (RFC 6455 framing over the same TCP socket, ~150 lines of C) if a script needs one | Low–Moderate |
| MicroPython native module glue | `USER_C_MODULES` CMake wiring + `extern "C"` wrapper, following the exact pattern of `picographics`/`jpegdec` | Low |

### What remains out of reach regardless of engine choice

- **WebRTC** (ICE/STUN/TURN negotiation, DTLS-SRTP, audio/video codec pipelines) — no embedded WebRTC stack targets RP2350-class hardware, and the codec/CPU requirements are far beyond a 150 MHz dual-core M33. Stamps like **STAMPCAST** remain server-proxy-only, permanently.
- **Full modern CSS** — litehtml's flexbox support is real but still maturing, and it does **not** reliably support CSS grid, container query units (`cqh`/`cqw`), `backdrop-filter`, or arbitrary `var()` custom-property chains. These are not exotic — the real-world stamp examples surveyed (§"HTML stamps are not all 'basic'") use `cqh` units and CSS variables even in their *simplest* tier. Expect **visual fidelity gaps** even for "no `<script>`" HTML stamps, not just for scripted ones.
- **True DOM/CSSOM compliance** — `querySelectorAll`, live NodeLists, CSSOM manipulation, and pixel-identical rendering vs. a real browser engine are not realistic goals; the DOM/canvas shim above is deliberately a small, purpose-built subset, not a WebKit clone.

### Revised routing recommendation

The hybrid router (Workaround 4) still applies, but the "native" branch's ceiling is now much higher than "layout composer with no JS":

```mermaid
flowchart TD
    fetch[Fetch decoded HTML / SVG bytes]
    tryNative[Try native engine: litehtml + ThorVG + JerryScript canvas shim]
    ok{Rendered without\nunsupported features?}
    cache[Cache PNG on microSD]
    proxy[Server headless-render proxy]
    pngDec[jpegdec/pngdec the proxy PNG]

    fetch --> tryNative
    tryNative --> ok
    ok -->|Yes| cache
    ok -->|No - grid/backdrop-filter/\nWebRTC/WebSocket/unknown API| proxy
    proxy --> pngDec
    pngDec --> cache
```

**Practical takeaway:** budget the native litehtml/ThorVG/JerryScript module as a distinct, optional v2 milestone (see Phase 4a below) rather than a v1 requirement. It meaningfully increases the share of stamps that render on-device without any network dependency, but the server-side proxy should remain in the architecture permanently as the fallback for the hardest 10–20% of interactive/WebRTC/modern-CSS stamps.

---

## Recommended Architecture: StampFrame for Presto

```
┌─────────────────────────────────────────────────────────────┐
│                     Pimoroni Presto                          │
│  ┌──────────┐   ┌─────────────┐   ┌──────────────────────┐  │
│  │  Touch   │   │  main.py    │   │  microSD cache       │  │
│  │  480×480 │◄──│  slideshow  │◄──│  /stamps/{txHash}.png│  │
│  └──────────┘   │  UI loop    │   │  /meta/{txHash}.json │  │
│                 └──────┬──────┘   └──────────────────────┘  │
│                        │                                     │
│         ┌──────────────┼──────────────┐                      │
│         ▼              ▼              ▼                      │
│    jpegdec/pngdec  PicoGraphics   Wi-Fi (RM2)               │
└────────────────────────┬────────────────────────────────────┘
                         │ HTTPS
                         ▼
              ┌──────────────────────┐
              │  stampchain.io       │
              │  /api/v2/stamps/     │
              │    balance/{address} │
              │  /s/{txHash}         │
              └──────────┬───────────┘
                         │ (SVG/HTML/WebP/AVIF only)
                         ▼
              ┌──────────────────────┐
              │  Optional raster     │
              │  proxy service       │
              │  GET /preview/{hash} │
              │  → 480×480 PNG       │
              └──────────────────────┘
```

### Core data flow

1. **Configure** wallet address(es) in `config.json` on the device (or via a one-time setup script over USB).
2. **Sync** — `GET https://stampchain.io/api/v2/stamps/balance/{address}`.
3. **Classify** each stamp by `stamp_mimetype` (same logic as `StampData.isImage`, `isSVG`, `isHTML`, etc.).
4. **Acquire content:**
   - PNG/JPEG → download from `/s/{txHash}`, decode locally.
   - text/plain → download, render wrapped text.
   - GIF → decode first frame (v1) or animate (v2+).
   - SVG/HTML/WebP/AVIF → fetch rasterized PNG from proxy; cache result.
5. **Display** fullscreen with stamp number overlay; swipe or tap edges for prev/next; optional timed slideshow.
6. **Cache** decoded PNGs and metadata on microSD to minimize API calls (see iOS [CACHING.md](./app-build/CACHING.md) for analogous strategy).

---

## Implementation Steps

### Phase 0 — Environment setup

1. Obtain Pimoroni Presto and a microSD card (included in starter kit).
2. Connect via USB-C; confirm the pre-installed MicroPython launcher runs.
3. Flash latest **“with-filesystem”** firmware from [pimoroni/presto releases](https://github.com/pimoroni/presto/releases) if needed.
4. Install [Thonny](https://thonny.org/) or use `mpremote` for file transfer.
5. Verify Wi-Fi connectivity using Pimoroni’s Wi-Fi examples.

### Phase 1 — Proof of concept (single stamp)

1. Hard-code one known PNG stamp `tx_hash`.
2. `urequests.get("https://stampchain.io/s/{txHash}")` → write bytes to `/sd/test.png` or RAM buffer.
3. Decode with `pngdec.PNG(display)` and `presto.update()`.
4. Confirm 480×480 display and acceptable decode time.

**Exit criteria:** One classic PNG stamp renders correctly from Stampchain.

### Phase 2 — Wallet sync and stamp list

1. Add `config.json` with one Bitcoin address.
2. Fetch balance JSON from Stampchain API.
3. Parse stamp list (`stamp`, `stamp_mimetype`, `tx_hash`, `stamp_url`).
4. Build an in-memory list sorted by stamp number.
5. Implement prev/next navigation via touch zones (photo-frame pattern).

**Exit criteria:** Swipe through all PNG/JPEG stamps in a wallet.

### Phase 3 — Format routing and caching

1. Port MIME classification from `StampData` (Python dict / functions).
2. Route PNG/JPEG to local decoder; text to text renderer.
3. Write cache layer on microSD:
   - Raw bytes: `/sd/cache/raw/{txHash}`
   - Rendered PNG: `/sd/cache/img/{txHash}.png`
   - Metadata sidecar: `/sd/cache/meta/{txHash}.json`
4. On sync, skip re-download if `file_hash` unchanged (when API provides it).

**Exit criteria:** Offline viewing of previously synced stamps; graceful handling of unsupported types.

### Phase 4 — HTML and non-native formats (SVG, WebP, AVIF)

1. **HTML router:** scan for `<script`; route static HTML to on-device composer, JS HTML to proxy.
2. **Static HTML composer:** parse positioned `<img src="/s/…">` and text `<div>` elements; resolve child stamps recursively; map `%` layout to 480×480; handle `data:image/*;base64,` inline.
3. **Render proxy** for JS-heavy HTML and for SVG/WebP/AVIF (headless browser or image conversion service).
4. Show placeholder icon + stamp number when proxy unavailable.

**Exit criteria:** Static HTML stamps (e.g. layout + text + embedded images) render on-device; JS-heavy stamps render via proxy; unsupported stamps show clear fallback UI.

### Phase 4a — Native rendering engine (advanced, optional v2)

This phase implements the [deep dive](#deep-dive--real-on-device-htmlcssjssvg-rendering) above. It is a firmware-level effort (C++, custom MicroPython build), separate from the Python application logic in the other phases, and should only be attempted once Phases 0–4 give a working, shippable baseline.

1. Build a custom Presto firmware image with `USER_C_MODULES` pointing at three new native modules (mirroring the existing `picographics`/`jpegdec`/`pngdec` integration pattern):
   - `svg_engine` — ThorVG (preferred) or NanoSVG, exposing `render(svg_bytes, width, height) -> framebuffer`.
   - `html_engine` — litehtml + gumbo-parser, with a `document_container` implementation that calls back into PicoGraphics/PicoVector, `jpegdec`/`pngdec`, and `svg_engine`.
   - `js_engine` — JerryScript (following Kaluma's/mcujs's integration approach), heap backed by PSRAM via `JERRY_SYSTEM_ALLOCATOR` + `JERRY_CPOINTER_32_BIT`.
2. Implement the Canvas2D shim and bind it into `js_engine` so `<canvas>`-drawing `<script>` blocks execute against a real framebuffer.
3. Implement the minimal DOM/event shim (`getElementById`, `addEventListener`, `setTimeout`/`setInterval`) and a `fetch`/`XMLHttpRequest` bridge onto Presto's existing HTTP client.
4. Wire `html_engine.render()` and `svg_engine.render()` into the Workaround 4 router as the first-attempt "native" branch, falling back to the server proxy when the engine reports an unsupported feature (grid layout, `backdrop-filter`, WebSocket/WebRTC usage, video/audio elements) or fails to parse.
5. Build a small regression suite of real Stampchain HTML/SVG stamps (across the three tiers identified above) to track native-render success rate over time, and to catch regressions as litehtml/ThorVG are updated.

**Exit criteria:** A measurable majority of non-WebRTC HTML/SVG stamps render natively on-device (no network round-trip beyond fetching the stamp itself); the proxy fallback rate and reasons are logged for future engine improvements.

### Phase 5 — Polish

1. Slideshow timer (configurable interval — mirror iOS `slideshowInterval`).
2. Ambient LED sync (`Presto(ambient_light=True)`).
3. Stamp number / edition overlay (mirror `StampCardView` pills, simplified).
4. Error states: no Wi-Fi, empty wallet, decode failure, retry.
5. Optional: multi-wallet rotation.

**Exit criteria:** Stable desk-frame experience suitable for daily use.

### Phase 6 — Out of scope (regardless of engine work)

- Ordinals and Counterparty protocol support
- QR wallet setup on-device
- Full GIF animation at 480×480
- Video/audio playback
- Market data and filtering UI
- SRC-20 / SRC-721 token management
- WebRTC-based stamps (e.g. STAMPCAST) — permanently proxy-only, regardless of on-device engine investment
- Pixel-identical rendering vs. a real browser for modern-CSS (grid, `backdrop-filter`, container queries) or heavily scripted stamps

---

## What Is Possible vs What Is Not

### Possible (recommended v1 scope)

- MicroPython app running natively on Presto
- Wi-Fi fetch from Stampchain API
- Wallet balance → stamp list for one or more addresses
- Fullscreen stamp display with touch navigation
- PNG and JPEG stamps (majority of classic pixel art)
- Plain text stamps
- microSD caching for offline viewing
- Slideshow mode
- Ambient RGB lighting tied to displayed stamp
- Nearest-neighbor upscale for small pixel-art stamps (24×24 → 480×480)
- Static preview for GIF stamps
- Static HTML stamps (layout + CSS + embedded `/s/` images, no JavaScript)
- HTML with inline `data:image/*;base64` payloads
- Graceful placeholders for unsupported types

### Possible with additional infrastructure

- SVG stamps rendered **natively on-device** via a compiled ThorVG/NanoSVG MicroPython module (Phase 4a); server-side rasterization remains the fallback for text/filter-heavy SVGs
- HTML stamps rendered **natively on-device** via a compiled litehtml (+ JerryScript canvas shim) MicroPython module (Phase 4a) for most layouts and simple canvas scripts; server-side headless-browser render → PNG remains the fallback for WebRTC/heavy-JS/modern-CSS stamps
- WebP / AVIF stamps (via server conversion)
- Animated GIF (custom MicroPython GIF decoder or pre-converted frame sequence on SD)

### Not possible (on Presto, regardless of engineering investment)

- WebRTC-based stamps (STAMPCAST-style) — no embedded WebRTC/media-codec stack targets this hardware class; permanently server-proxy-only
- Faithful, standards-compliant CSS grid, container query units (`cqh`/`cqw`), `backdrop-filter`, or full CSS custom-property cascades — litehtml supports CSS2.1 and a maturing flexbox subset, not these
- True DOM/CSSOM compliance (`querySelectorAll`, live NodeLists, full event model) — only a small hand-built DOM/event shim is realistic
- Pixel-identical rendering vs. a real WebKit/browser view
- Faithful 1:1 port of StampFolio iOS (SwiftUI, tabs, WebKit, AVKit)
- Native WebP / AVIF decode without adding large third-party libraries
- Video playback
- Rich audio playback (beyond piezo beeps)
- QR code scanning (no camera)
- Ordinals / Counterparty content requiring browser-grade rendering
- Displaying hundreds of stamp thumbnails simultaneously (wrong form factor — use one-at-a-time or tiny 2×2 grid at most)
- On-device resize of large progressive JPEGs at acceptable speed (pre-scale instead)

---

## MicroPython vs C++

| Aspect | MicroPython | C++ (Pimoroni SDK) |
|--------|-------------|---------------------|
| Time to first prototype | Fast | Slower |
| Wi-Fi / HTTP examples | Included | More boilerplate |
| JPEG/PNG decode | Built-in modules | Same underlying libraries |
| SVG/HTML/JS engines (litehtml/ThorVG/JerryScript) | Consumed as a compiled native module (`import html_engine`) | **Required to implement** — these are C/C++ libraries; MicroPython is the orchestration layer on top |
| GIF animation | Limited | Better performance potential |
| Maintenance | Easier for hobby deployment | Better for production firmware |

**Recommendation:** Prototype the app (Phases 0–5) in MicroPython. The native rendering engine (Phase 4a) is unavoidably a C++ effort — MicroPython's `USER_C_MODULES` mechanism is what makes it available to the Python app as a normal `import`, exactly like the existing `picographics`/`jpegdec`/`pngdec` modules.

---

## Key References

| Resource | URL |
|----------|-----|
| Pimoroni Presto product page | https://shop.pimoroni.com/products/presto |
| Presto GitHub (firmware + examples) | https://github.com/pimoroni/presto |
| Getting Started (Learn) | https://learn.pimoroni.com/article/getting-started-with-presto |
| Presto MicroPython API | https://github.com/pimoroni/presto/blob/main/docs/presto.md |
| PicoGraphics (JPEG/PNG) | https://github.com/pimoroni/pimoroni-pico/blob/main/micropython/modules/picographics/README.md |
| PicoVector | https://github.com/pimoroni/presto/blob/main/docs/picovector.md |
| Stampchain API | https://stampchain.io/docs#/ |
| StampFolio domain model | `./app-build/DOMAIN-MODELS.md` |
| Bitcoin Stamps FAQ (OLGA / file sizes) | https://stampchain.io/faq |
| MicroPython external C modules (`USER_C_MODULES`) | https://docs.micropython.org/en/latest/develop/cmodules.html |
| litehtml (HTML/CSS layout engine) | https://github.com/litehtml/litehtml |
| litehtml on ESP32 (`microbrowser`, WIP prior art) | https://github.com/leopck/microbrowser |
| gumbo-parser (HTML5 parser used by litehtml) | https://codeberg.org/gumbo-parser/gumbo-parser |
| ThorVG (embeddable vector/SVG/Lottie engine) | https://github.com/thorvg/thorvg |
| NanoSVG (single-header SVG parser/rasterizer) | https://github.com/memononen/nanosvg |
| JerryScript (embeddable ECMAScript engine) | https://github.com/jerryscript-project/jerryscript |
| Kaluma (JerryScript runtime for RP2040/RP2350) | https://kalumajs.org/ |
| mcujs (JerryScript runtime for RP2040/RP2350) | https://github.com/mcu-js/mcujs |
| RP2350 PSRAM memory mapping notes | https://forums.raspberrypi.com/viewtopic.php?t=375109 |

---

## Conclusion

**MicroPython on Pimoroni Presto is a good platform for a Bitcoin Stamp desk display**, not a full StampFolio port. The RP2350 has sufficient CPU, RAM, and storage for API calls, caching, and PNG/JPEG rendering at 480×480. Stamp payloads (≤64 KB) are well within device limits.

**SVG and HTML rendering is more achievable on-device than initially assessed.** The building blocks — a small HTML/CSS layout engine (litehtml), a vector/SVG engine (ThorVG/NanoSVG), and a JS engine (JerryScript) — all have **working prior art on RP2040/RP2350-class hardware** (ESP32 litehtml port, ThorVG on ESP32 and inside LVGL, JerryScript via Kaluma/mcujs on Pico/Pico2). None of this is plug-and-play for Presto specifically: bridging litehtml's `document_container` to PicoGraphics, adding a Canvas2D shim for JerryScript, and building a minimal DOM/event/networking layer is real, unclaimed engineering work (Phase 4a). But it is squarely the same *kind* of work as the native `picographics`/`jpegdec`/`pngdec` modules Presto already ships — not a fundamentally different undertaking.

**A server-side render proxy should stay in the architecture permanently regardless.** WebRTC-based stamps (STAMPCAST-style) and stamps depending on modern CSS features litehtml doesn't support (grid, `backdrop-filter`, container query units) are out of reach for any on-device engine on this hardware. The recommended router (Workaround 4 / Phase 4a) tries the native engine first and falls back to the proxy — so investing in the native engine reduces reliance on network infrastructure and proxy costs over time without ever fully eliminating the need for it.

**Next step:** Implement Phase 1 proof of concept — fetch and display a single PNG stamp from Stampchain on Presto hardware. Treat Phase 4a (native rendering engine) as a distinct, later milestone once the core viewer (Phases 0–5) is shipping.
