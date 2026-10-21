# ARC_NetGraph
**Real-Time Network Telemetry & Framerate HUD for The Elder Scrolls Online**

**Author:** @arcsinan  
**Version:** 1.0.0  
**API Versions:** 101050, 101051  
**Required Dependency:** LibAddonMenu-2.0 (>= 43)  

---

## 🌟 Overview
`ARC_NetGraph` provides a sleek, lightweight, real-time overlay showing your round-trip server latency (**Ping**), packet arrival variance (**Jitter**), min/max latency spikes, and rendering framerate (**FPS**).

---

## 🚀 Key Features
* **Accurate RFC 3550 Jitter:** Computes packet arrival variance to detect micro-stutters and connection instability even when average ping appears stable.
* **Dynamic Health Color Coding:**
  * 🟢 **Green:** Excellent latency (< 70ms) & low jitter (< 6ms).
  * 🟡 **Yellow:** Moderate latency (70–130ms) & mild variance.
  * 🔴 **Red:** High latency (> 130ms) or severe ping spikes (> 15ms jitter).
* **3 Flexible Display Styles:**
  1. **Compact Bar (Single-Line):** Clean horizontal telemetry bar (`FPS: 144 • PING: 58ms (±2.5ms) • SPIKE: 52-78ms`).
  2. **Detailed Card (Grid):** Multi-row dashboard displaying separate lines for FPS, Server, Ping, Jitter, and Spike Range.
  3. **Minimalist (Badge):** Unobtrusive micro-badge (`144 FPS · 58 ms (±2ms)`).
* **Full Position & Interactivity Control:**
  * Freely drag anywhere on screen.
  * **Lock Window Position:** Makes the overlay click-through so combat clicks pass right through.
  * **UI Scale Slider:** Scale smoothly from 50% to 150%.
  * **Background Opacity:** From dark glassmorphism to 100% transparent/borderless.
* **Account-Wide & Megaserver Isolation:** SavedVariables store positions and settings per megaserver (EU / NA / PTS).

---

## ⌨️ Slash Commands
* `/netgraph` or `/ang` — Toggle the NetGraph overlay.
* `/anglock` — Quickly lock or unlock window dragging.
* `/angsettings` — Open the LibAddonMenu configuration panel.
* `/arcdonate` — Open in-game gold donation to developer `@arcsinan`.

---

## 📄 Legal
This Add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its affiliates. The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.
