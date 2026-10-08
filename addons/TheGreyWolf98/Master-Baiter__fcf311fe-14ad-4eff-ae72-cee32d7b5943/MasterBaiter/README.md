# MasterBaiter 1.0.1 — Xbox fishing suite
By @TheGreyWolf98

**Right bait. Right time. Reel it in.**

MasterBaiter selects suitable fishing bait, alerts you when it is time to reel in, lists the rare fish you still need, and marks known fishing locations on the main map.

## 1.0.1 fix

Fishing map pins now build in small batches after a short delay. Pending work is cancelled on map changes, loading and disabling pins, reducing the loading-time CPU burst reported on Xbox. Pins may take a moment to fill in.

## What's new

- A current-zone rare-fish checklist with specific fish names, grouped by water type.
- An optional HUD below the compass: Off, Fishing only, or Always.
- A 10-second zone-arrival reminder when a zone has missing rare fish.
- A setting to include caught fish on the HUD; the full checklist always includes them.
- Fishing-location pins with different fish icons for each water type.
- Hide a water type's pins when its collection is complete, or show every known spot.
- Adjustable pin size, 16–40.
- A “MasterBaiter fishing spots” checkbox in the controller's main-map filters.

The fishing reference covers 46 zone-ID mappings and 4,357 coordinate records across 106 map tiles. These are known locations, not live reports of active holes. Coverage varies by map; unmapped locations can still exist.

## Start here

1. Install/update MasterBaiter through your normal console addon process, then reload the game UI.
2. Turn off Rare Fish Tracker's overlay and Fishing Map's pins so you can distinguish MasterBaiter's displays. Also disable competing automatic-bait selection and bite alerts, including those in NQOL.
3. Type `/mb` to open MasterBaiter. Existing sound and bait preferences are retained.
4. The default HUD mode is Fishing only, with the 10-second arrival reminder enabled and caught fish hidden. Turn the HUD Off to disable both displays.
5. Port to a zone with missing fish. Its collection should appear under the compass for about 10 seconds, then fade away.
6. Look at a fishing hole. The fishing-only HUD should appear, remain through the cast, and disappear when you stop targeting/fishing.
7. Open the main map. Look for fishing pins and the “MasterBaiter fishing spots” filter.
8. Use the Rare fish tab, or `/mb fish`, to view the complete current-zone checklist.

## Commands and controller buttons

- `/mb` or `/masterbaiter`: settings window.
- `/mb fish`: current-zone fish checklist.
- `/mb help`: instructions.
- `/mbhud`: temporarily hide or restore the collection HUD, including the arrival reminder. It does not mute the bite alert or change your saved HUD mode.
- `/mb debug`: enable mechanics diagnostics and open the log.

D-pad selects settings; A changes them. LB/RB switches Settings, Bait, Help, Debug and Rare fish tabs. LT/RT changes pages. X previews the selected sound and large bite image. Y refreshes. B closes.

## Rare-fish progress

Progress comes from the game's **account achievements**, shared between characters. It is not a new personal fishing history. Previously caught achievement fish therefore appear immediately, and new catches update the HUD automatically. Both Solstice achievement collections are included. Wrothgar's additional special fishing achievement is listed separately from the ordinary water types.

The HUD tracks your character's location even while you browse a different zone on the map. No collection is displayed for an unsupported zone, and completed zones do not trigger an arrival reminder. The collection HUD hides during combat and appears only in the gameplay HUD scenes.

## Bait and bite alerts

Aim at a named hole until its fishing prompt appears. Suitable bait is selected from available stock; an already suitable selection is kept.

| Water | Suitable bait |
| --- | --- |
| Ocean / Saltwater | Worms or Chub |
| Lake | Guts or Minnows |
| River | Insect Parts or Shad |
| Foul | Crawlers or Fish Roe |

Simple Bait fallback is optional and off by default. Unknown water names or missing stock keep the current bait. Automatic bait matching currently supports English names.

Cast and reel in yourself. The bite alert plays the selected game sound and briefly shows the large red fish image. Both are independently adjustable. Available duel sounds are included in the sound choices. Bait selection, bite alerts, the rare-fish HUD and map pins have been tested in game on Xbox.

## Map behaviour

Pins show observed fishing locations. A pin does not guarantee that a hole is currently spawned or available. With “Show spots for completed water types” Off, completed water types are hidden according to the mapped zone's account achievement progress. Unknown collection data keeps pins visible. Solstice's west and east pins use their respective achievement progress.

Turn pins on/off in MasterBaiter's Settings or the controller map filters. Avoid enabling a second fishing-pin addon at the same time if you do not want duplicate markers.

## References and credits

Game API and native HUD/map interfaces: [ESOUI source](https://github.com/esoui/esoui).

Numerical achievement/item references and fish grouping were checked against [Rare Fish Tracker](https://www.esoui.com/downloads/info665-RareFishTracker.html), maintained by katkat42 and votan. Observed fishing coordinates were researched from [Map Pins](https://www.esoui.com/downloads/info1881-MapPins.html), by Hoft and art1ink, including updates credited to Gamer_sa22. Credit also goes to the fishing-location contributors acknowledged by those projects, including Votan and the House Tertia project.

MasterBaiter's implementation is independent. Those addons' implementation code, menus and artwork are not bundled. Water-type map icons are game assets; the large bite image is MasterBaiter's own asset. No external addon library is required.
