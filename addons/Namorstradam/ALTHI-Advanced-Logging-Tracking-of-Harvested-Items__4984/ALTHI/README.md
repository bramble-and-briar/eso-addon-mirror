# ALTHI – Advanced Logging & Tracking of Harvested Items

**Version 1.0.0 · ESO API 101051**  
**Authors: Althi & Roman (@namorstradam & @bakaroobanzai)**

AI disclosure: ALTHI was developed with OpenAI ChatGPT/Codex assistance for code, documentation and translation drafts. Roman directs development and tests the addon in ESO. This does not claim an independent human code audit.

## Your gathering session at a glance

Track resources and fishing in one shared session. See collected quantities, estimated gold value and gold per active session hour. Resources and Fishing have separate tabs; collecting switches the view automatically, and you can switch manually at any time.

- Resources include crafting materials, provisioning ingredients, selected creature loot and supported world-container finds. Item names, icons and quality colors come from ESO.
- Search and select materials in the Filter List, organized by crafting profession. Documented origins, native traits and material-passive guidance help identify materials.
- Only items acquired in the current session appear as rows. Existing inventory does not create session finds. Stock valuation includes an item type only after that session has acquired it.
- Pause/Resume and a confirmed Reset. Resume on a new find can be enabled or disabled in Settings or the clickable header status. With it disabled, new loot does not resume a paused session. Reset clears the current session, not the lifetime fishing statistics.
- Resize, scroll, sort columns, adjust column widths/transparency, or minimize the overview while tracking continues. The overview is hidden in ESO menus by default; this is configurable.
- Selected rare finds display their ESO icon/name near the upper center for three seconds, with gentle fading.

## Fishing

Fishing uses the same session timer and total value as resource gathering. Separate active fishing time is used for catches/hour and white filletable fish/hour. Fishing statistics have session and lifetime views, bait stock/consumption, filleted fish, Perfect Roe and observed roe yield.

Automatic bait selection is optional and applies to recognized water types. Casting and reeling remain manual. Filleting is player-started by button or optional keybinding; it processes eligible unlocked white fish sequentially and stops when interrupted. Rare/trophy fish are not eligible. Previously owned fish are not new catches. Ambiguous mixed processing batches are valued conservatively; see KNOWN_ISSUES.md.

Lifetime fishing data can be reset separately in Settings after confirmation.

## Prices

Gross unit-price priority: custom ALTHI price → Awesome Guild Store (AGS) → Tamriel Trade Centre (TTC) → Arkadius' Trade Tools (ATT) → Master Merchant (MM) → NPC base-value fallback. Enable the sources you use; none is required. AGS supplies your last own listing price, not a confirmed sale.

The optional guild-trader switch shows 93% of gross values throughout ALTHI, including custom prices and the NPC fallback. The 7% sale cut represents the estimated mail payout. The separately paid 1% listing fee is not deducted again. Original/custom price storage stays gross. Values are estimates, not guaranteed sale proceeds.

## Installation and updates

1. Extract the single `ALTHI` folder into ESO's `live/AddOns/` folder. The manifest should be `live/AddOns/ALTHI/ALTHI.txt`, without a second nested ALTHI folder.
2. For updates, keep your SavedVariables. With ESO closed, **copy** `live/SavedVariables/ALTHI.lua` to a backup location if desired; do not move or delete the original. The saved global table is named ALTHISavedVariables, but ESO's file is normally ALTHI.lua.
3. Enable ALTHI in the game. On first launch, choose your language in the English welcome screen and apply.
4. Use `/althi version` to confirm the installed version. Existing filters, prices, language preferences and session data are retained. Reloaded sessions return paused; offline time is not counted.

No mandatory library. Optional LibAddonMenu-2.0 provides integrated ESO settings; without it, ALTHI has standalone settings. Pricing addons are also optional and are not bundled.

## Commands and keys

| Command | Action |
| --- | --- |
| `/althi` or `/althi show` | Show the overview |
| `/althi home` | Return the overview to its default screen position |
| `/althi settings` | Open settings |
| `/althi catalog` | Open the Filter List |
| `/althi version` | Show addon/API and interface/client languages |
| `/althi debug` | Toggle local loot diagnostics |
| `/althi id <ID>` | Resolve a supported material ID and its selection status |
| `/althi testfund` | Preview the Kuta notification without adding a find |
| `/althi reset` | Reset the session after confirmation |
| `/althi help` | Show the command list |

Optional keys are listed under ESO Controls/Keybindings → ALTHI. No keys are assigned automatically. Existing bindings remain valid: Run now means Resume, Pause toggles Pause/Resume, and the former Stop action pauses the same session. Other actions show/hide the overview, open the Filter List, reset and start/stop filleting.

## Languages

Included in the main addon: German, English, French, Spanish, Russian, Simplified Chinese and Japanese. No language packs required. Choose an independent ALTHI language or Automatic (ESO language). DE/EN are maintained; the other five translations are drafts and corrections are welcome. Item names and native item tooltips follow the ESO client language. See LANGUAGES.md.

## Deutsch – Kurzstart

ALTHI verbindet Ressourcen und Angeln in einer gemeinsamen Sammelsession. Pause/Weiter und Reset steuern die Session. „Fortsetzen nach Fund“ kann oben oder in den Einstellungen umgeschaltet werden. Ausgeschaltet bleibt die Session bis zum manuellen Weiter pausiert. Angeldaten lassen sich zusätzlich als Gesamtstatistik ansehen; der Session-Reset löscht diese nicht.

Den Ordner ALTHI nach `live/AddOns/` entpacken. Bei Updates SavedVariables behalten; für eine Sicherung die Datei `live/SavedVariables/ALTHI.lua` **kopieren**, nicht verschieben. `/althi settings` öffnet die Einstellungen, `/althi catalog` die Filterliste und `/althi version` die Versionsausgabe. Alle sieben Sprachen sind enthalten. Namen und Icons der Gegenstände liefert ESO.

Credits and source references: AUTHORS.md, KATALOG_QUELLEN.md and MATERIALQUELLEN.md. Permissions: LICENSE.txt.
