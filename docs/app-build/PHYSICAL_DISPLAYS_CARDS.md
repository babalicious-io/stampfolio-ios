# Physical Displays for Trading-Card / Counterparty Art

Research for DIY hardware frames that show Counterparty card artwork at roughly trading-card proportions. Covers color LCD/TFT panels only (no e-ink). Vendors surveyed: **Waveshare**, **Raspberry Pi (official)**, **Pimoroni**, **M5Stack**, **Makerfabs (MaTouch)**.

Prices are indicative EU retail incl. VAT where listed; stock and shipping vary by retailer.

---

## Context: Counterparty Art vs. Physical Cards

| Reference | Value |
|-----------|-------|
| Counterparty “full” card art (Rare Pepe, Dank, etc.) | **400×560 px** (5:7) |
| pepe.wtf `small/` thumbnails | 240×336 px (still 5:7) |
| Physical trading card (Pokémon / MTG) | **63.5 × 88.9 mm** (2.5″ × 3.5″) |
| StampFolio tile ratio | 5:7 with `.fit` letterboxing |

**Census note:** 98% of Rare Pepe full-archive images are exactly 400×560. Horizon/API thumbnails are often downscaled; prefer `full/` URLs when building a frame pipeline.

---

## Reality Check

| Finding | Detail |
|---------|--------|
| Exact 5:7 panel | **None found** off-the-shelf in small DIY sizes |
| Closest pixel ratio | **3:4** (480×640, 768×1024) — ~5% wider than 5:7 |
| Closest physical width | **Raspberry Pi Touch Display 2 (5″)** — 62.1 mm vs 63.5 mm card width |
| Every option | Letterbox 400×560 art; use a 3D-printed bezel to mask bezels |

### Ratio vs. Target (5:7 = 0.714)

| Ratio | Example resolutions | Aspect (H÷W) | vs 5:7 |
|-------|---------------------|---------------|--------|
| **3:4 (best)** | 480×640, 768×1024 | 0.75 | +5% wider |
| 2:3 | 320×480 | 0.667 | narrower |
| 3:5 | 480×800 | 0.60 | taller / narrower |
| 9:16 | 720×1280, 540×960 | 0.5625 | phone portrait |
| 1:1 | 720×720, 480×480 | 1.0 | square |
| 4:3 landscape | 800×480 | rotate → 3:5 | wrong default orientation |

---

## Ranked Picks (Color LCD Only)

| Rank | Product | Why |
|------|---------|-----|
| **1** | **Waveshare 2.8″ 480×640** (HDMI or DSI) | Best **pixel ratio** (3:4); color, touch, 60 Hz |
| **2** | **Raspberry Pi Touch Display 2 (5″)** | Best **physical width** (62.1 mm); official Pi OS support |
| **3** | **Waveshare 8″ 768×1024 HDMI** | Same 3:4 ratio at large “slab” scale |
| **4** | **MaTouch ESP32-S3 3.5″ ILI9488** | Best **standalone ESP32** color option; ~card-sized board |
| **5** | **M5Stack Tab5** | Most polished ESP32 large portrait kit; 9:16 ratio |
| **6** | **Pimoroni HyperPixel 4** | Fine Pi HAT; 3:5 ratio is worse than Waveshare 480×640 |

---

## Waveshare (Raspberry Pi + HDMI)

Widest portrait LCD range. Grouped by fit for card-frame use.

### Tier A — Best Ratio Match (3:4)

| Product | SKU | Res | Interface | Active area | Touch | EU price | Notes |
|---------|-----|-----|-----------|-------------|-------|----------|-------|
| **2.8″ HDMI LCD (H)** | WS-21316 | 480×640 | HDMI + USB-C | ~43×57 mm | Capacitive | €49–53 | [OpenELAB](https://openelab.io/products/waveshare-2-8inch-hdmi-ips), [Welectron](https://www.welectron.com/Waveshare-21316-28inch-HDMI-LCD-H) |
| **2.8″ DPI LCD** | WS-18628 | 480×640 | GPIO DPI666 + I2C | 66×48 mm module | Capacitive | €32–37 | [Welectron](https://www.welectron.com/Waveshare-18628-28inch-DPI-LCD_1), [Botland](https://botland.de/raspberry-pi-anzeigen/18532-kapazitiver-ips-lcd-touchscreen-28-480x640px-dpi-gpio-fur-raspberry-pi-waveshare-18628-5904422371210.html) |
| **2.8″ DSI LCD** | WS-22028 | 480×640 | DSI | — | Capacitive | ~€35–45 | Frees GPIO vs DPI; Pi-only |
| **8″ 768×1024 LCD** | WS-27026 | 768×1024 | HDMI + USB-C | 122.7×163.4 mm | 10-pt cap. | €86–90 | [Elty](https://elty.pl/en_US/p/Display-8-IPS-7681024-HDMI-with-Touch-Panel/3933), [Eckstein](https://eckstein-shop.de/WaveShare-8inch-Capacitive-Touch-Display-768x1024-HDMI-IPS-10-Point-Touch-EN) |
| **9.7″ 768×1024 LCD** | — | 768×1024 | HDMI | larger | Capacitive | ~€100+ | Same 3:4 family |

**Best Waveshare pick for card ratio:** 2.8″ 480×640 — HDMI for flexibility, DSI for clean Pi stack, DPI for lowest cost.

### Tier B — Common Portrait, Worse Ratio (3:5)

| Product | SKU | Res | Interface | Active area | EU price |
|---------|-----|-----|-----------|-------------|----------|
| **3.5″ 480×800 LCD** | WS-24037 | 480×800 | HDMI + USB-C | 45.4×75.8 mm | €49 ([Welectron](https://www.welectron.com/Waveshare-24037-35inch-480x800-LCD_1)) |
| **4″ DPI LCD (B)** | WS-18370 | 480×800 | GPIO DPI | — | ~€40–50 |
| **4 / 4.3″ DSI TOUCH-A** | WS-34354 | 480×800 | DSI | 86.4×51.8 mm (4″) | €33 ([OpenELAB](https://openelab.io/products/waveshare-inch-dsi-capacitive-touch)) |
| **4″ DSI LCD** | — | 480×800 | DSI | — | varies |
| **3.2″ HDMI LCD (H)** | — | 480×800 | HDMI | — | display only, no touch |

### Tier C — Square / Special (Not Card-Shaped)

| Product | Res | Ratio | Interface | Use case |
|---------|-----|-------|-----------|----------|
| **4″ DSI LCD (C)** / **4-DSI-TOUCH-C** | 720×720 | 1:1 | DSI | Square UI |
| **3.4″ 800×800 LCD** | 800×800 | 1:1 | HDMI | Square / round projects |

### Waveshare Interface Notes

| Interface | Pros | Cons |
|-----------|------|------|
| **HDMI** | Pi-agnostic, GPIO free, 60 Hz color, PC/Jetson compatible | Higher cost |
| **DSI** | Clean stack, GPIO free, good Pi 5 OS support | Pi-only |
| **DPI** | Low cost, high refresh | Uses most GPIO pins, Pi-only, `config.txt` overlays |

Portrait is **default** on 480×640 and 480×800 panels. Docs: [2.8″ HDMI wiki](https://www.waveshare.com/wiki/2.8inch_HDMI_LCD_(H)), [4-DSI-TOUCH-A](https://docs.waveshare.com/4-DSI-TOUCH-A).

---

## Raspberry Pi (Official)

All **color IPS TFT**, DSI + GPIO power. No HDMI in this product line.

| Product | SKU | Size | Resolution | Ratio | Active area | EU price | Pi compat |
|---------|-----|------|------------|-------|-------------|----------|-----------|
| **Touch Display 2 — 5″** | SC1975 | 5″ | 720×1280 | 9:16 | **62.1×110.4 mm** | €36–44 | Pi 1B+ → Pi 5 (not Zero) |
| **Touch Display 2 — 7″** | SC1635 | 7″ | 720×1280 | 9:16 | 86.9×154.6 mm | €55–68 | same |
| **Touch Display 2 — 10″** | new 2026 | 10″ | 1200×1920 | 9:16 | 135×217 mm | ~€75–80 | **Pi 5 / CM only** (4-lane DSI) |
| Touch Display (original) | — | 7″ | 800×480 | landscape | — | legacy | avoid for portrait cards |

### EU Retailers (5″)

| Retailer | Price | Link |
|----------|-------|------|
| Kiwi Electronics | €36.49 | [kiwi-electronics.com](https://www.kiwi-electronics.com/en/raspberry-pi-touch-display-2-5-inch-20517) |
| BuyZero | €42.00 | [buyzero.de](https://buyzero.de/products/raspberry-pi-touch-display-2-5-portrait) |
| Welectron | €43.90 | [welectron.com](https://www.welectron.com/Official-Raspberry-Pi-Touch-Display-2-5-Portrait) |
| Reichelt | €44.30 | [reichelt.de](https://www.reichelt.de/de/de/shop/produkt/raspberry_pi_shield_-_display_lcd-touch_5_720x1280_pixel-407188) |

**Why consider the 5″:** Width almost matches a real card; ratio is phone-tall so art gets heavy pillarboxing.

**Mounting:** [Pimoroni Pibow Frame](https://learn.pimoroni.com/article/assembling-pibow-frame) for desk/shelf portrait stand.

**Docs:** [Touch Display 2 about](https://github.com/raspberrypi/documentation/blob/master/documentation/asciidoc/accessories/touch-display-2/about.adoc), [Pi announcement (5″)](https://www.raspberrypi.com/news/a-new-5-variant-of-raspberry-pi-touch-display-2/).

---

## Pimoroni

Color lineup is smaller, mostly DPI/SPI HATs. Nothing beats Waveshare 480×640 for ratio.

| Product | SKU | Size | Resolution | Ratio (portrait) | Active area | Interface | EU price |
|---------|-----|------|------------|------------------|-------------|-----------|----------|
| **HyperPixel 4.0** (rect) | PIM369 | 4″ | 800×480 → 480×800 | 3:5 | 51.8×86.4 mm | DPI (uses almost all GPIO) | €54–64 |
| **HyperPixel 4.0 Square** | PIM470 | 4″ | 720×720 | 1:1 | 72×72 mm | DPI | €70–75 |
| **HyperPixel 2.1 Round** | PIM579 | 2.1″ | 480×480 | round | 53.3×53.3 mm | DPI | ~€50+ |
| **Display HAT Mini** | PIM589 | 2″ | 320×240 | 4:3 | 40.8×30.6 mm | SPI | ~€18 |

### EU Retailers

| Product | Retailer | Price | Link |
|---------|----------|-------|------|
| HyperPixel 4 Touch | Kiwi | €53.99 | [kiwi-electronics.com](https://www.kiwi-electronics.com/en/hyperpixel-4-0-hi-res-touch-display-for-raspberry-pi-4382) |
| HyperPixel 4 Touch | Welectron | €63.90 | [welectron.com](https://www.welectron.com/Pimoroni-PIM369-HyperPixel-40-Display-for-Raspberry-Pi-Touch) |
| HyperPixel 4 Square Touch | BerryBase | €74.90 | [berrybase.de](https://www.berrybase.de/en/hyperpixel-4.0-square-high-resolution-display-for-raspberry-pi-touch) |
| Display HAT Mini | Pimoroni | £15.75 | [shop.pimoroni.com](https://shop.pimoroni.com/products/display-hat-mini) |

**HyperPixel 4 setup (Bookworm+):** add to `/boot/firmware/config.txt`:

```
dtoverlay=vc4-kms-dpi-hyperpixel4
```

Disable I2C on GPIO if it conflicts. Rotation via Pi OS Screen Configuration.

**Verdict:** HyperPixel 4 rect is 3:5, not 3:4 — **Waveshare 2.8″ 480×640 is a better ratio match** for the same “small color frame” idea.

---

## M5Stack (ESP32, Color LCD Only)

No 5:7 panel. Most units are small or square; **Tab5** is the only large portrait color option.

| Product | MCU | Display | Resolution | Ratio | Touch | EU price | Notes |
|---------|-----|---------|------------|-------|-------|----------|-------|
| **Tab5** | ESP32-P4 + C6 | 5″ IPS | 1280×720 (720×1280 portrait) | 9:16 | Capacitive | ~€60–80 | MIPI-DSI, camera, battery; [Reichelt](https://www.reichelt.de/de/de/shop/produkt/m5stack_tab5_iot_entwickler-kit_mit_akku_esp32-p4_-415282) |
| **Cardputer / Cardputer-Adv** | ESP32-S3 | 1.14″ TFT | 240×135 | ~16:9 | No | ~€35–50 | Card-*sized device*, not card-ratio screen |
| **StickC Plus SE** | ESP32-PICO | 1.14″ TFT | 135×240 | 9:16 | No | ~€15–25 | Too small |
| **M5Dial** | ESP32-S3 | 1.28″ round | 240×240 | 1:1 | Capacitive | ~€40–50 | Knob / dial UI |
| **Core2** | ESP32 | 2″ IPS | 320×240 | 4:3 | Capacitive | varies | Dev kit |
| **CoreS3 / CoreS3 Lite** | ESP32-S3 | 2″ IPS | 320×240 | 4:3 | Capacitive | €50–90 | Dev kit + camera |

**Tab5 specs:** 5″ 1280×720 IPS, GT911 touch, SC2356 camera, Wi-Fi 6 (via ESP32-C6), 16 MB flash, 32 MB PSRAM, battery. Portrait-native panel per [M5 docs](https://docs.m5stack.com/en/core/Tab5).

**Verdict:** For a color card frame, only **Tab5** is seriously sized (shares Pi Touch 2’s 9:16 ratio). Core2 / Dial / Cardputer are wrong shape or too small.

---

## Makerfabs / MaTouch (ESP32-S3, Color TFT)

Broadest ESP32 color range. No 5:7; several useful portrait options.

| Product | Display | Resolution | Ratio (portrait) | Board size | Touch | Makerfabs | EU est. |
|---------|---------|------------|------------------|------------|-------|-----------|---------|
| **S3 Parallel 3.5″ ILI9488** | 3.5″ TFT | 320×480 | 2:3 | **66×84.3 mm** | Cap. | $29.90 | [Semaf AT €50](https://electronics.semaf.at/matouch-esp32-s3-parallel-tft-mit-touch-35-ili9488) |
| **S3 SPI 3.5″ ILI9488** | 3.5″ TFT | 320×480 | 2:3 | 66×84.3 mm | Cap. | $29.90 | ~€35–50 ship |
| **S3 Parallel 4.0″ ST7701** | 4″ IPS | 480×480 | 1:1 | — | Cap. | $31.90 | Photo-frame class |
| **S3 Rotary 2.1″ ST7701** | 2.1″ IPS | 480×480 | 1:1 round | — | Cap. + encoder | $38.80 | Smart knob |
| **S3 Parallel 4.3″** | 4.3″ IPS | 800×480 | landscape | — | Cap. | $34.90 | Landscape panel |
| **S3 Parallel 5″** | 5″ IPS | 800×480 | landscape | — | Cap. | ~$40+ | Landscape |
| **S3 Parallel 7″** | 7″ | 1024×600 | landscape | — | Cap. | varies | Dashboard |
| **AI S3 2.8″ ST7789V** | 2.8″ TFT | 320×240 | 4:3 | — | Cap. + camera | ~$25+ | Small |
| **S3 Parallel 2.8″** | 2.8″ | 320×240 | 4:3 | — | Cap. | ~$25+ | Small |

**3.5″ ILI9488 highlights:** ESP32-S3-WROOM-1-N16R8, 16 MB flash, 8 MB PSRAM, Wi-Fi + BLE 5.0, 16-bit parallel (or SPI variant), FT6236 touch, microSD, dual USB-C.

**Family overview:** [makerfabs.com/matouch-family](https://www.makerfabs.com/matouch-family)

**Verdict:** **3.5″ ILI9488** is the most card-like ESP32 all-in-one (board ~66×84 mm). Ratio 2:3 is closer than 9:16 but still not 5:7. Limited EU stock — often ship from Makerfabs or importers.

---

## Build Notes

### Software / Art Pipeline

1. Fetch or cache **400×560** (or collection-native size) artwork.
2. Scale with **letterboxing** (same as StampFolio `aspectRatio(5/7, contentMode: .fit)`).
3. Prefer pepe.wtf `full/` over `small/` when the API returns thumbnails.
4. On Pi: fullscreen kiosk (e.g. Chromium, pygame, or custom app).
5. On ESP32: LVGL / SquareLine with MaTouch; Tab5 has more headroom for animations.

### Hardware

1. **Bezel:** 3D-printed frame to mask panel bezels and mimic a graded slab.
2. **Pi + Waveshare HDMI:** Pi Zero 2 W or Pi 4/5 + 2.8″ HDMI — minimal wiring.
3. **Pi + official DSI:** Touch Display 2 5″ + Pibow Frame — best plug-and-play official stack.
4. **ESP32:** MaTouch 3.5″ for compact WiFi frame; Tab5 for premium all-in-one.
5. **Power:** HDMI panels often need USB for touch + HDMI for video; budget 2 A USB supply.

### Avoid for Card Frames

| Product | Reason |
|---------|--------|
| HyperPixel Square / Round | Wrong aspect |
| M5Dial, Display HAT Mini, Core2 | Too small or square |
| 480×800 / 9:16 panels | Worse letterboxing than 3:4 |
| Original Pi Touch Display (7″ 800×480) | Landscape-native |

---

## Quick BOM Examples

### Budget Pi Frame (best ratio)

| Part | Est. EU |
|------|---------|
| Raspberry Pi Zero 2 W | €15–20 |
| Waveshare 2.8″ HDMI 480×640 | €50 |
| microSD + 5 V 2.5 A supply | €15 |
| 3D-printed bezel | — |
| **Total** | **~€80** |

### Official Pi Frame (best width)

| Part | Est. EU |
|------|---------|
| Raspberry Pi 4/5 | €45–80 |
| Pi Touch Display 2 (5″) SC1975 | €37–44 |
| Pimoroni Pibow Frame (optional) | €10 |
| **Total** | **~€90–130** |

### Standalone ESP32 Frame

| Part | Est. EU |
|------|---------|
| MaTouch ESP32-S3 3.5″ Parallel ILI9488 | €35–50 |
| 3.7 V LiPo (optional) | €10 |
| 3D-printed bezel | — |
| **Total** | **~€45–60** |

---

## Related StampFolio Docs

- Counterparty image resolver and tile aspect ratio: `StampFolio/Features/Counterparty/`
- Caching resolved artwork URLs: [CACHING.md](./CACHING.md)
- Counterparty API notes: [COUNTERPARTY-API.md](./COUNTERPARTY-API.md)

---

## Revision History

| Date | Notes |
|------|-------|
| 2026-03-19 | Initial research: Waveshare, Pimoroni, Raspberry Pi, M5Stack, Makerfabs; color LCD only |
