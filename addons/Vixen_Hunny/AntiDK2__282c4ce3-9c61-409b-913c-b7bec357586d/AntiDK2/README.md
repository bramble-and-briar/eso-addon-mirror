# Anti DK 2.0 (AntiDK2)

An Elder Scrolls Online add-on built for PvP (Cyrodiil/Battlegrounds/IC). It watches combat events
for a fixed set of **Dragonknight (DK)** abilities used against you and surfaces that information
as fast, readable on-screen cues — "AVOID", "ROLL NOW", stack counters, and a live Corrosive Armor
DoT tracker — so you can react to incoming DK pressure without parsing combat log text.

## At a glance

| | |
|---|---|
| **Title** | AntiDK2 |
| **Display name** | Anti DK 2.0 |
| **Author** | Vixen Hunny |
| **Add-on version** | 1.5 (`## AddOnVersion` in the manifest and `ADK.version` in code) |
| **API version** | 101049 |
| **Dependency** | [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html) |
| **Saved variables** | `AntiDK2_SavedVars` (per-character) |
| **Slash command** | `/antidk` (opens the settings panel) |

## What it tracks

AntiDK2 listens to `EVENT_COMBAT_EVENT` for the following abilities (by ability ID, see
[AntiDK2.lua](src/AntiDK2.lua)) and reacts only when they are used *by an enemy against the player*:

| Ability | Ability ID(s) | Behavior |
|---|---|---|
| **Corrosive Armor** | `17879` | Shows a center-screen popup while you are standing in the DoT, with a live `m:ss` in-range timer and a hit-count multiplier (`x1`–`x4`) per 1‑second window. Flashes red on a critical tick. |
| **Wing Buffet** | `21007` | Adds the attacking enemy to a live roster in the main panel with a per-enemy hit counter and a draining progress bar showing the ~4s stun/stagger window. |
| **Molten Whip** | `122658` / `20805` | Counts stacks (0–3) applied by each enemy DK and shows `EMPOWERED` once an enemy reaches 3 stacks (empowered whip ready). Stacks decay automatically after 12s of inactivity. |
| **Power Lash** | effect `34117` / hit `20824` | Tracks the enemy's Flame Lash stack count (starts at 5, counts down as they hit you) and flags `LASH READY` at 5 stacks. Decays after 15s of inactivity. |
| **Shattering Rocks** | `32678` | Fires an **AVOID → ROLL NOW** popup sequence (roll prompt appears ~0.7s later). |
| **Fossilize** | `32685` | Same AVOID → ROLL NOW popup sequence. |
| **Shifting Standard** (Dragonknight Standard) | `32958` | Shows a plain **AVOID** popup (no roll prompt). |

Each tracker can be independently enabled or disabled from the settings panel, and most state
(stacks, timers, active-enemy rosters) is automatically reset on player death.

## On-screen UI

AntiDK2 draws its own lightweight, backdrop-free, movable panels (no third-party UI library beyond
LibAddonMenu for settings):

- **Main panel** (`AntiDK2MainPanel`) — only shown while at least one tracked mechanic is active.
  Contains:
  - **Wings** section — up to 5 enemy rows with hit count and a draining status bar.
  - **Molten Whip** row — stack pips (`I I I`) and `EMPOWERED` state.
  - **Power Lash** row — stack pips and `LASH READY` state.
- **Corrosive Armor popup** (`AntiDK2CorrosivePanel`) — centered, large bold text: title, `IN
  RANGE`/`CRITICAL HIT` status, elapsed timer, and hit multiplier.
- **AVOID popup** (`AntiDK2StunPanel`) — up to 4 stacked slots cycling between the ability name +
  `AVOID` and, for roll-able mechanics, `ROLL NOW`.

All panels remember their position (via `OnMoveStop`), and font size/scale are configurable per
popup.

## Configuration (LibAddonMenu panel)

Open with `/antidk` or via **Settings → Add-ons → Anti DK 2.0**. Options are grouped as:

- **Tracking** — individual checkboxes to toggle each of the 7 trackers above.
- **Timing** — sliders for popup fade delays (Corrosive popup fade, AVOID popup duration) and the
  Wings combat timeout.
- **Appearance** — panel scale and font-size presets (`Small` / `Medium` / `Large` / `XLarge`) for
  the Corrosive and AVOID popups.
- **Test buttons** — trigger each popup with dummy data so you can preview and reposition them
  outside of combat.

All settings persist per-character in `AntiDK2_SavedVars`; defaults live in `ADK.defaults` in
[AntiDK2.lua](src/AntiDK2.lua).

## Project layout

```
AntiDK2.addon              Add-on manifest (metadata, load order, dependencies)
src/
  AntiDK2.lua               Namespace bootstrap: metadata, ability IDs, colour palette (ADK.Colorize),
                            fonts (ADK.Font / ADK.PresetFont), window registry (ADK.WINDOWS),
                            saved-var defaults (ADK.Get) and shared helpers (ADK.IsPlayer, ADK.Msg)
  Run.lua                   Entry point: EVENT_ADD_ON_LOADED handler, wires up UI + events
  Config/
    Settings.lua            LibAddonMenu-2.0 settings panel definition
  Combat/Events/            One module per tracked ability (combat-event listeners + state)
    Corrosive.lua
    DragonknightStandard.lua
    Fossilize.lua
    MoltenWhip.lua
    PowerLash.lua
    ShatteringRocks.lua
    Wings.lua
  UI/                       One module per on-screen panel/widget
    Popups.lua               Shared label/statusbar helpers + the main panel container
    Corrosive.lua             Corrosive Armor popup
    Stuns.lua                 Shared AVOID / ROLL NOW popup (used by 3 mechanics)
    Wings.lua                 Wing Buffet enemy roster rows
    MoltenStacks.lua          Molten Whip stack row
    PowerLashStacks.lua       Power Lash stack row
  Init/
    Run.lua                  Alternate/experimental bootstrap with per-step error isolation
                              (not referenced by AntiDK2.addon; kept for reference)
```

> **Note:** [src/Init/Run.lua](src/Init/Run.lua) is a hardened variant of [src/Run.lua](src/Run.lua)
> that wraps each init step (saved vars, UI, settings, events) in its own `pcall` so a single
> failure doesn't prevent the others from loading. It is not listed in [AntiDK2.addon](AntiDK2.addon)
> and is therefore currently unused at runtime.

## Installation

1. Copy this folder into your ESO `AddOns` directory, e.g.
   `Documents\Elder Scrolls Online\live\AddOns\AntiDK2\`.
2. Make sure [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html) is also
   installed (listed as a dependency in [AntiDK2.addon](AntiDK2.addon)).
3. Enable **Anti DK 2.0** from the in-game Add-Ons list.

## Make your own add-on

Use this project as a template for a small combat-reaction add-on of your own:

1. **Copy the skeleton.** Duplicate the folder, rename it, and update the `.addon` manifest
   (`## Title`, `## Description`, `## SavedVars`, `## DependsOn`, and the file list) to match.
2. **Define your namespace and IDs.** In your equivalent of [AntiDK2.lua](src/AntiDK2.lua), create a
   root table (`YourAddon = YourAddon or {}`), list the ability IDs you care about under an `IDS`
   table, and define `defaults` for anything you want saved per character via `ZO_SavedVars`.
3. **Add one combat-event module per mechanic**, mirroring [src/Combat/Events](src/Combat/Events):
   register an `EVENT_COMBAT_EVENT` handler, filter by `abilityId`/`result`/source-target identity,
   keep minimal local state, and expose `Register()`, `Unregister()`, and `Reset()`.
   - The [`EVENT_COMBAT_EVENT`](https://wiki.esoui.com/API#Combat) callback signature in these files
     is: `(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName,
     sourceType, targetName, targetType, hitValue, powerType, damageType, combatMechanic, sourceUnitId,
     targetUnitId, abilityId)`.
4. **Add one UI module per on-screen element**, mirroring [src/UI](src/UI): use the shared
   `ADK.UI.MakeLabel` / `ADK.UI.MakeStatusBar` helpers for consistent fonts/colors, create a
   `WINDOW_MANAGER:CreateTopLevelWindow` (or anchor into a shared container panel), and expose a
   `Show()`/`Refresh()` + `Hide()`/`Reset()` pair that your combat modules call into.
5. **Wire everything together in `Run.lua`**: register an `EVENT_ADD_ON_LOADED` handler that
   (a) loads saved vars with `ZO_SavedVars:NewCharacterIdSettings`, (b) builds all UI modules,
   (c) registers all combat-event modules, and (d) resets state on `EVENT_PLAYER_DEAD`. Wrap each
   step in `pcall` (see [src/Init/Run.lua](src/Init/Run.lua)) so one bad module doesn't break the
   rest.
6. **Expose user options** with a [LibAddonMenu-2.0](https://wiki.esoui.com/LibAddonMenu) panel
   (see [src/Config/Settings.lua](src/Config/Settings.lua)) — checkboxes to toggle each tracker,
   sliders for timing/appearance, and test buttons that call your `Show()` functions with dummy data.
7. **Test and iterate in-game**: use `/reloadui` after each change, trigger the test buttons from
   your settings panel to preview popups safely, and watch chat messages for errors raised during
   `EVENT_ADD_ON_LOADED`.
