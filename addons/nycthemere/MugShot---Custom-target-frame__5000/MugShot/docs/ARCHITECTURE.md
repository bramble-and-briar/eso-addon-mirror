# MugShot — Architecture

## Overview

```text
MugShot/
├── Constants.lua             Addon-wide constants, colors & logger setup
├── Defaults.lua              SavedVariables default values
├── Localisation.lua          Bilingual localization dictionary (fr / en)
├── Settings.lua              SavedVariables load/merge/persist (MugShotSV)
├── Main.lua                  Bootstrap, lifecycle management & two-word slash commands
├── Data/
│   └── Portraits.lua         Boss, dummy, race and alliance portrait mappings
├── Core/
│   ├── TargetState.lua       Canonical runtime state (generation, exists, identity, vitals, effects)
│   ├── TargetPolicy.lua      Display-gate logic (ShouldDisplay with trial filter)
│   ├── Presentation.lua      State → display-table transformation (pure Lua, lowercase m/k)
│   └── TargetController.lua  Orchestrator; coordinates state, adapter, policy, view & bridge
├── ESO/
│   ├── EsoAdapter.lua        Thin wrapper around raw ESO API calls (identity, vitals, shield, effects, IsInTrial)
│   ├── EventBindings.lua     EVENT_MANAGER subscriptions and dynamic effect ticker
│   └── NativeFrameBridge.lua Reversible suppression of ZO_TargetUnitFramereticleover
├── UI/
│   ├── Style.lua             Central style constants, fonts, dimensions and color tables
│   └── TargetFrameView.lua   UI control construction, scene fragments & drag-and-drop
├── docs/
│   ├── ARCHITECTURE.md       ← this file
│   ├── API_NOTES.md          ESO API reference and findings
│   └── TEST_PLAN.md          Testing strategy and scenarios
└── tests/
    ├── run.lua               Combined test runner (12 suites, 399 assertions)
    ├── EsoMock.lua           Headless ESO API & UI hierarchy mock
    ├── preview.py            Cross-platform Python launcher for Love2D UI Preview
    └── preview/
        ├── conf.lua          Love2D window & engine configuration
        ├── main.lua          Dynamic UI preview runner & live file-watcher (hot-reload)
        ├── LayoutSolver.lua  ESO anchor & dimension constraint solver
        └── README.md         Preview documentation, hotkeys & controls
```

---

## Data Flow

```text
ESO Events (RETICLE_TARGET_CHANGED / POWER_UPDATE / ATTRIBUTE_VISUAL / EFFECT_CHANGED / PLAYER_ACTIVATED)
  │
  ▼
EventBindings  ──────────────────────────────────────────┐
  │                                                      │
  ▼                                                      │
TargetController.RefreshTarget()                         │
  ├─ state:ResetForTargetChange()   (increments gen)     │
  ├─ DoesUnitExist("reticleover")                        │
  │   └─ false → view:SetVisible(false)                  │
  │              nativeBridge:SetReplacementActive(false)│
  │              eventBindings:StopEffectTimer()         │
  │                                                      │
  └─ true → adapter:ReadIdentity()                       │
            adapter:ReadVitals()                         │
            adapter:ReadShield()                         │
            adapter:ReadEffects()                        │
            TargetPolicy.ShouldDisplay(state, s, trial)  │
            Presentation.BuildIdentity()                 │
            Presentation.BuildVitals()                   │
            Presentation.BuildEffects()                  │
            view:SetIdentity()                           │
            view:SetVitals()                             │
            view:SetEffects()                            │
            view:SetVisible(true)                        │
            nativeBridge:SetReplacementActive(true)      │
            eventBindings:CheckEffectTimer()             │
                                                         │
TargetController.RefreshVitals(cur, max, eff)  ◄─────────┤
  ├─ guard: state.exists == false → return               │
  ├─ state.vitals update                                 │
  └─ Presentation.BuildVitals() → view:SetVitals()       │
                                                         │
TargetController.RefreshShield(shield)        ◄──────────┤
  ├─ guard: state.exists == false → return               │
  ├─ state.vitals.shield update                          │
  └─ Presentation.BuildVitals() → view:SetVitals()       │
                                                         │
TargetController.RefreshEffects()              ◄─────────┘
  ├─ guard: state.exists == false → return
  ├─ adapter:ReadEffects() → state.effects update
  └─ Presentation.BuildEffects() → view:SetEffects()
```

---

## Generation Fence

`TargetState.generation` is incremented on every `ResetForTargetChange()`. Any callback that captures a generation value and fires asynchronously compares its captured generation to the current one and bails out if they differ. This prevents stale callbacks from overwriting the UI after a target change.

---

## Module Contracts

| Module              | Input                             | Output / Side-effect                                                     |
|---------------------|-----------------------------------|--------------------------------------------------------------------------|
| `TargetState`       | Mutated by controller             | Exposes `generation`, `exists`, `identity`, `vitals`, `effects`          |
| `TargetPolicy`      | `(state, settings, isInTrial)`    | `bool` — determines whether the frame should render                      |
| `Presentation`      | `(state, settings)`               | Pure display tables with formatted texts (`2.1m/3m`, `[3.6k]`)           |
| `EsoAdapter`        | `unitTag`                         | Safe extraction of identity, power, shield values, active buffs, and raid detection (`IsInTrial`) |
| `EventBindings`     | `controller`                      | Manages event subscriptions, zone changes, and periodic 250 ms effect timer |
| `NativeFrameBridge` | `active`                          | Safely hides or restores `ZO_TargetUnitFramereticleover`                 |
| `TargetFrameView`   | Presentation tables               | Renders status bar, shield overlay, portrait box, badges, and buff icons |
| `Settings`          | SavedVariables table              | Loads, merges with `Defaults`, and persists layout changes               |
| `Localisation`      | Client language                   | Supplies translated strings for chat, UI labels, and diagnostic output   |
| `TargetController`  | All of the above                  | Central orchestrator containing zero direct ESO UI code                  |

---

## Drag & Position Persistence

1. Repositioning mode is entered via `/mugshot move`.
2. The game camera is set to UI mode (`SetGameCameraUIMode(true)`), displaying the mouse cursor.
3. The frame displays a live **WYSIWYG** representation of the player's character with a glowing cyan border (`0.2, 0.8, 1.0, 1.0`): live health updates, live damage shields, live buffs/debuffs, and real-time 250ms countdown timers.
4. Controls inside the frame handle `OnMouseDown` (`frame:StartMoving()`) and `OnMouseUp` (`frame:StopMovingOrResizing()`).
5. On mouse release, the primary anchor (`frame:GetAnchor(0)`) is captured and persisted to `MugShotSV`.
6. Retyping `/mugshot move` locks the frame, restores normal camera mode, and switches back to live targeting.

---

## Scene Integration & Instant Resolution

The frame is attached to both `HUD_SCENE` and `HUD_UI_SCENE` via `ZO_SimpleSceneFragment:New(frame)` (instantaneous visibility, zero fade-in animation lag).
A conditional visibility check (`fragment:SetConditional(...)`) ensures the frame remains visible when entering chat mode (pressing `Enter`), inventory, or menus where HUD UI fragments are active, while hiding automatically when the reticle target is lost.
On target acquisition, `SetVisible(true)` immediately sets `frame:SetHidden(false)` on the current frame, ensuring zero-latency rendering.

---

## Native Frame Suppression & Anti-Flicker (`NativeFrameBridge`)

To eliminate the 1-frame visual flash/artifact of the base game target frame (`ZO_TargetUnitFramereticleover`):
1. **Pre-Hook Interception**: `NativeFrameBridge:Start()` installs a `ZO_PreHook` on `ZO_TargetUnitFramereticleover.SetHidden`. Any call from ESO's native UI engine attempting to unhide the frame (`SetHidden(false)`) while MugShot is active is intercepted and blocked (`return true`).
2. **Persistent Suppression**: The native frame is suppressed (`SetReplacementActive(true)`) throughout MugShot's entire lifecycle and is never unhidden when reticle target is cleared (`_ClearTarget()`).
3. **Double Guard (Alpha 0)**: In addition to `SetHidden(true)`, the native frame's alpha is set to 0 to prevent any hardware drawing artifact.
4. **Lifecycle Restoration**: The native frame is cleanly restored to normal operation only when MugShot is explicitly disabled (`Stop()` or `/mugshot toggle off`).

---

## Slash Commands (Keyword & Action)

MugShot uses a clean **two-word command structure** (`/mugshot <action>`) designed for in-game auto-completion:
- When `LibSlashCommander` is installed, typing `/mugshot ` opens a native in-game dropdown list with all subcommands, descriptions, and auto-completion.
- When `LibSlashCommander` is absent, standard `SLASH_COMMANDS["/mugshot"]` dispatches actions cleanly with zero overhead.

| Keyword | Action / Parameters | Description |
|:---|:---|:---|
| `/mugshot` | *(empty)* or `help` | Print localized command reference and syntax in chat |
| `/mugshot` | `toggle` `[on\|off]` | Toggle addon enabled / disabled |
| `/mugshot` | `move` | Toggle frame repositioning mode (unlocks frame, enables cursor & dummy preview) |
| `/mugshot` | `reset` | Reset position to default (TOPLEFT 100, 200) and unlock for moving |
| `/mugshot` | `trial` `[on\|off]` | Filter: only display enemies in 12-man Trials / Raids (suppresses friendly reticle clutter) |
| `/mugshot` | `hodor` | Toggle custom HodorReflexes / LibCustomIcons avatars on/off (fallback to class icon) |

---

## Portrait & Avatar Resolution

When a player (self in move mode, or targeted player) is displayed:
1. **Custom Avatar**: If `useHodorIcons` is enabled (default: `true`), MugShot queries `LibCustomIcons` (`GetStatic` / `GetAnimated`) or `HodorReflexes.util.GetUserIcon` / `HodorReflexes.users` for the unit's `@displayName`. If found, the custom texture and sprite atlas coordinates (`portraitCoords`) are applied.
2. **Class Icon Fallback**: If no custom icon exists, or if `useHodorIcons` is toggled off (`/mugshot hodor`), MugShot seamlessly falls back to the native gamepad class icon (`/esoui/art/icons/class/gamepad/gp_class_<class>.dds`).
3. **Monsters / NPCs**: Specific portraits (rockgrove bosses, dummies, trials) or monster defaults are displayed.

---

## High-Performance Architecture & Design Patterns

MugShot employs advanced Lua 5.1 & ESO UI design patterns to achieve maximum frame rates and zero garbage collection spikes in 12-man raid combat:

1. **Pattern Poids-Mouche (Flyweight) & String Interning**:
   - `Presentation.TIMER_STRINGS` [1..120] and `Presentation.STACK_STRINGS` [1..50] store pre-allocated static string instances.
   - Counting down timers and rendering stacks retrieves strings via $O(1)$ integer lookups without allocating or hashing new strings in Lua memory.
2. **Buffer Réutilisable Zero-GC (Zero-Allocation Tick)**:
   - `Presentation.BuildEffects(state, settings, outBuffer)` accepts an optional pre-allocated buffer array (`TargetController._effectsBuffer`).
   - During the periodic 250ms effect update ticker, sub-tables (`{ icon, timerText, stackText }`) are mutated in-place rather than instantiated anew, dropping memory allocations to **0 bytes per tick**.
3. **Dirty Flags (Cache de frontière C++ UI)**:
   - In `TargetFrameView`, every effect slot tracks its previous visual state (`_lastIcon`, `_lastTimerText`, `_lastStackText`, `_lastHidden`).
   - Container layout resizing (`SetDimensions`) is guarded by `_lastNumRows`.
   - The expensive C++ UI layout and texture pipeline is only invoked when visual values actually change, eliminating ~75% of redundant C++ bridge crossings.
4. **Local Upvalues (Code65536 / Baertram Pattern)**:
   - High-frequency modules localize core Lua and ESO functions (`math.ceil`, `math.floor`, `math.max`, `table.insert`, `GetGameTimeSeconds`) into local upvalues.
   - Bytecode execution uses single `OP_GETUPVAL` register indexing rather than dual global table hash lookups (`GETGLOBAL` + `GETTABLE`).
5. **Pattern Strategy (Politiques de Ciblage Extensibles)**:
   - `TargetPolicy` decomposes display logic into modular, interchangeable strategies (`BaseLivingTargetStrategy`, `TrialEnemyOnlyStrategy`).
   - New policies can be registered at runtime via `TargetPolicy.RegisterStrategy(fn)` without modifying existing source code (SOLID Open/Closed Principle).

---

## Buff & Debuff Processing (`castByPlayer` Filtering)

In 12-man Trials and Raids, boss targets routinely accumulate 40+ buffs and debuffs from the entire raid group (Major Breach, Minor Vulnerability, and 11 other players' DoTs). Displaying all effects causes severe visual clutter and conceals the player's own active damage-over-time abilities.

To solve this efficiently and naturally:
1. **Single-Pass Extraction Filtering**: `EsoAdapter:ReadEffects(unitTag, onlyPlayerCast)` inspects the 13th return value of `GetUnitBuffInfo` (`castByPlayer`). For target units (`reticleover`), it defaults to filtering `castByPlayer == true`.
2. **High Memory & GC Efficiency**: Debuffs applied by other raid members are discarded during iteration **before** any table allocation occurs (`{ name = ..., ... }`). This reduces Lua memory allocation and GC pressure by ~90% during high-frequency combat events (`EVENT_EFFECT_CHANGED`).
3. **No Artificial Capping**: Unlike naive approaches that truncate buffs with arbitrary caps (e.g. 20), MugShot relies on player-cast filtering. A single player typically maintains 3–6 DoTs on a target; all are displayed clearly. `Presentation.BuildEffects` performs no arbitrary truncation, and `TargetFrameView` dynamically allocates slot controls as needed.
4. **Move Mode / Self Buffs**: When querying `player` (e.g. in `/mugshot move`), `onlyPlayerCast` defaults to `false` to display all active buffs on the player character.
