# Bureau of Acceptable Views

A lightweight camera addon for *The Elder Scrolls Online*. It gives you back
control over the third-person camera in situations where the game normally
takes it away, and layers a few optional cinematic touches on top. Dynamic FOV
and PvP mode are on out of the box; PvP mode remains completely inert outside
AvA worlds and Battlegrounds.

> **Compatibility:** API: LIVE 101050 / PTS 101051 · Requires:
> LibAddonMenu-2.0 (>= 43).

---

## What it does

The core feature is **free zoom in restricted states**. ESO locks the camera
to a fixed distance (or forces first person) in certain situations. This addon
lets you zoom freely between maximum zoom and first person in those states,
with optional persistence so your framing survives zone changes and relogs.

On top of that, several **optional** systems can shape the camera further:

- **Dynamic FOV** *(on by default)* - field of view follows your zoom distance.
- **Camera response profiles** - ESO-native, instant, responsive, or smooth
  transitions for Dynamic FOV, context presets, and shoulder movement.
- **Context presets** *(off by default)* - cinematic framing per gameplay state.
- **Over-the-shoulder swap** *(off by default)* - swing the camera to one side.
- **PvP mode** *(on by default)* - a dedicated manual zoom step and optional
  camera-shake suppression, without automatic framing or cinematic profiles.
- **Live offset nudge** - hold keybinds to slide the third-person camera
  horizontally or vertically, then recenter those two axes with one tap.

Every disabled optional system is fully inert. PvP mode registers no combat,
health, sprint, update, or profile observers at all.

---

## Features

### Free zoom in restricted states
- Zoom anywhere between max zoom and first person while the game would normally
  lock the camera.
- Configurable persistence: keep your zoom across zone changes and logins, or
  let it reset - your choice.
- Controller input safely falls back to the game's default camera handling, so
  nothing breaks if you play on a gamepad.

### Dynamic FOV *(optional, on by default)*
- Ties your third-person field of view to the current zoom distance: tighter
  when zoomed in, wider when zoomed out, smoothly interpolated in between.
- A lightweight 100 ms observer watches the public camera-distance setting while
  the feature is enabled, so controller zoom and native game camera changes stay
  synchronized too. FOV is recalculated only when the observed value changes.
- Your manual FOV is snapshotted and persisted before the first dynamic override,
  then restored when the feature is disabled - including after a `/reloadui`.

### Camera response
- One global response setting controls Dynamic FOV, context presets, and
  over-the-shoulder movement.
- **As in ESO** applies BAV values immediately and leaves the game's own camera
  smoothing setting untouched.
- **Instant** suppresses native smoothing and lands every BAV change in one frame.
- **Responsive** uses a short 90 ms fast-settling transition.
- **Smooth** uses a longer 300 ms cinematic ease-in/out transition.
- Emergency reset, load-screen recovery, siege safety, and live offset nudging
  remain immediate regardless of the selected profile.

### Live offset nudge
- Offset binds stay locked until you **remember one home pose** from the
  dedicated settings tab. Restore always returns to that pose; nudging never
  overwrites it.
- Hold keybinds to slide the third-person **horizontal** and **vertical**
  offsets in real time, the same axes CameraControl used to expose.
- Movement is continuous (units per second), not a slow once-per-tick step.
  A **nudge speed** slider in settings scales that rate from 50% to 200%.
- One **restore** bind (and a matching settings button) returns both axes to
  the remembered home. Zoom, FOV, and shoulder are left alone.
- An optional centred on-screen readout shows both offsets while you nudge,
  restore, remember, or delete the home pose, then hides after two seconds.
- Assign the binds under Controls -> Bureau of Acceptable Views. They do
  nothing until a home pose exists.
- If a context preset is active, the same delta is written into its restore
  snapshot so leaving combat or stealth does not rewind the framing you just
  set. Remembering home stores the player's real framing, not the cinematic
  overlay.

### Over-the-shoulder swap *(optional, off by default)*
- Swings the third-person camera over one shoulder for a focused, cinematic
  frame, and returns it to centre when it should.
- One **mode** selector chooses how it triggers:
  - **Auto** - swings automatically while you are in any state you pick (combat,
    stealth, mounted, swimming, sprint) and recentres when you leave them.
  - **Manual** - swings on demand via the `/bav shoulder` command
    (`left`/`right`/`center`, or no argument to toggle); the automatic behaviour
    is off in this mode.
- A **shoulder offset** slider sets how far the camera swings.
- While shoulder swap is on it takes over the shoulder from the stealth context
  preset, so the two never fight over the same setting - exactly one owns it.
- Your pre-swing shoulder is snapshotted and **persisted**, so a `/reloadui`,
  logout, or crash mid-swing hands your real framing back next session.

### Context presets *(optional, off by default)*
- Applies a fixed cinematic camera bundle for the state you are in - combat,
  werewolf, stealth, interaction (dialogue), mounted, swimming, or sprinting -
  and restores your own framing when you leave it.
- State changes follow the global camera-response profile. Each state also has
  an optional release delay; enabling one lets a rapid out-and-
  back collapse to a no-op instead of moving the camera twice.
- The interaction state is the exception: entering it is briefly delayed, so
  flicking through a merchant or quick quest turn-in never pecks the camera -
  only a conversation you actually stay in reframes the shot.
- Exactly one state is active at a time, resolved by priority
  (werewolf → combat → stealth → interaction → mounted → swimming → sprint), so
  states never fight each other.
- A single global **intensity** slider scales every bundle, and each state has
  its own style choice plus an individual **intensity** slider that scales that
  state on top of the global value (0% = no effect, 100% = full style strength).
- Your pre-preset camera is snapshotted the first time a preset takes over and
  **persisted**, so a `/reloadui`, logout, or crash while a preset is active
  hands your real camera back next session instead of baking the preset's
  offsets into your settings.
- Open the game's settings while a preset is active and your camera quietly
  reverts to your real values for editing, then the preset re-applies on top of
  your changes when you close it - so tweaking FOV or distance never fights the
  active preset or gets baked into your saved framing.
- An **emergency restore** button in the settings panel instantly returns the
  camera to your control if anything ever feels stuck.

### PvP mode *(optional, on by default)*
- Runs only in AvA worlds and Battlegrounds and applies no automatic camera
  profile.
- Uses a dedicated step for player-controlled mouse-wheel and gamepad zoom.
- Never changes zoom distance, FOV, shoulder position, or camera offsets on its
  own, so entering combat, taking damage, sprinting, and mounting cannot move the
  camera.
- Camera shake is suppressed by default to reduce distraction and motion
  discomfort. An opt-in leaves the player's shake setting unchanged.
- The original camera-shake value is persisted before suppression and restored
  when leaving PvP, disabling the mode, using `/bav reset`, or after `/reloadui`.
- Other optional systems remain governed by their own toggles; PvP mode itself
  does not enable, configure, or reapply them.

### Conflict resilience *(automatic safety net)*
- Because BAV hooks the game's own first-person toggle, another addon that
  drives that toggle can, in rare cases, fight it and make the view flicker
  between first and third person. BAV watches for that: if the view flips back
  and forth at a rate no human could produce, it **steps its own handling
  aside** (passes the toggle straight to the game) to break the loop.
- The backoff is fully **reversible** and touches none of your saved settings -
  it clears the moment you relog or use `/bav reset`.
- A related case: some game states (notably ZOS's reworked **werewolf**) take
  over the camera distance and **reject** BAV's writes. Combined with another
  addon measuring the camera by toggling first person twice in one frame, this
  used to leave the view stuck in first person - re-forced on every manual
  zoom-out. BAV no longer tries to recognize and unwind such toggle pairs by
  timing. Instead, in the states it manages, a toggle only records **where the
  camera should end up** and a single write on the next frame moves it there
  (see *Convergent toggle handling* below). A measurement addon's toggle-and-back
  pair cancels out to no net change on its own, with no dependence on frame
  timing, and a rejected write is retried a bounded number of times rather than
  leaving the view half-moved. A sustained run of rejected camera-distance
  writes are recorded in the debug log for troubleshooting.
- **Known interaction: camera-probing addons.** Some addons (notably *Miat's
  PvP* / PvpAlerts) measure the camera by toggling first person several times in
  a single frame. With older BAV builds this could briefly force or stick the
  view in first person. The convergent toggle handling above neutralizes it on
  BAV's side - the probe cancels out to no net change - so the two run together
  with no special configuration. If a view ever feels stuck, `/bav reset`
  returns control immediately. A proper upstream fix (the probe only firing when
  its result is actually needed) would remove the interaction at the source.

---

## Why it's built well

- **No surprises.** Context presets and over-the-shoulder swap stay off until
  you enable them. Dynamic FOV and PvP mode ship on; PvP mode applies no
  automatic framing and remains fully inert outside AvA/Battlegrounds.
- **One source of truth for engine I/O.** All camera reads and writes go
  through a single `CameraSettings` layer that handles the engine's value
  formatting and verifies every write by reading it back. A future client
  change needs fixing in exactly one place.
- **No FOV tug-of-war.** A dedicated `FovArbiter` makes field-of-view
  precedence explicit, so dynamic FOV and context presets can never overwrite
  each other depending on load order or timing - a preset hold cleanly overrides
  dynamic FOV.
- **One owner per contested setting.** Just as `FovArbiter` owns the FOV, shoulder
  swap takes sole ownership of the shoulder offset while it is on, so it and the
  stealth preset never write the same value out of turn.
- **One implementation per repeated pattern.** Where several modules grew the same
  mechanism, it lives in one place: `Ease` owns the self-tearing glide lifecycle for
  every animated value, `CameraResponse` owns duration, curve, and coordinated
  native-smoothing suspension,
  `OptionsWatch` owns the single settings-window subscription every feature suspends
  on, and `SprintWatch` owns the event-driven sprint detector every feature that
  cares about sprinting subscribes to. Each caller supplies only its payload, so
  a fix or a client change lands once, not in four near-identical copies.
  Zoom-in/out share one input handler, preset-state maps share normalization
  helpers, and horizontal/vertical holds share the same direction bookkeeping.
- **Convergent toggle handling.** In the states BAV manages, a first-person
  toggle does not write the camera on the spot. A dedicated `ZoomReconciler`
  records *where the camera should settle* and performs a single write on the
  next frame. This is correct by construction: another addon's toggle-and-back
  measurement pair cancels out to the same intent it started from, so the view
  never desyncs - and it does not matter whether those two toggles land in the
  same frame or not. There is no frame-timing guesswork to break in edge cases
  like the world map or a transformed state.
- **Nothing permanently on the per-frame path.** Work happens in response to
  state events, a coarse 100 ms distance observer while Dynamic FOV is enabled,
  or SprintWatch's event-driven settle confirmations. Only transient FOV and
  preset glides run every frame, and their updaters tear down when they land.
- **Recovers gracefully.** The pre-preset camera snapshot and the pre-swing
  shoulder are persisted, so an interrupted session never leaves cinematic
  offsets or a one-sided camera baked into your settings.
- **Plays nicely with others.** BAV shares the game's first-person toggle with
  any addon that uses it. The convergent handling above means the rapid
  toggle-and-back pairs other addons use to measure the camera cancel out
  cleanly, and if it ever detects a runaway view flicker it steps its own
  handling aside - a reversible safety net that needs no configuration and never
  blames another addon.
- **Localized** with English and Russian strings, and a clean LibAddonMenu
  settings panel.

---

## Architecture at a glance

The addon is split into layers with **one-way dependencies**: upper layers know
about lower ones, never the reverse. Two rules anchor the whole design - *only*
`CameraSettings` talks to the engine, and *only* `FovArbiter` decides who owns
the field of view. Everything else is a consumer of those two contracts.

```
            Settings.lua            UI + SavedVariables - wires everything
                 │ Configure(...)
  ┌──────────┬──────────────┬─────────────────┬───────────┬──────────────┐
  ▼          ▼              ▼                 ▼           ▼              ▼
DynamicFov ContextPresets ShoulderControl   PvpMode     OffsetNudge
  │          ▲              │ (owns shoulder) │ detector  (hold-to-nudge)
  │          └──────────────┴─────────────────┘ profile request
  └────┬──────┘
   FovArbiter            │  single owner of FOV precedence
        │                │
        ▼                ▼
    CameraSettings          the only verified engine I/O
        │
        ▼
   GetSetting / SetSetting  raw engine API
```

`DynamicFov` flows through `FovArbiter`, which lets a context-preset hold
override it cleanly. `ShoulderControl` is the single owner of the shoulder offset
whenever it is on, so `ContextPresets` cedes that one setting to it.

`Ease`, `OptionsWatch`, and `SprintWatch` sit *below* everything as shared leaf
primitives: the consumers call into them, they call back through payload
callbacks, and none depends on another feature module. `Ease` owns the
self-tearing updater behind every glide; `OptionsWatch` owns the one
settings-window subscription and the canonical open/closed state features
suspend on; `SprintWatch` owns the one event-driven sprint detector and the
canonical is-sprinting sample. Factoring the repeated mechanism into one place
is what keeps a fix or a client change a single edit.

---

## Module overview

| Module | Responsibility |
| --- | --- |
| `BureauOfAcceptableViews.lua` | Core: free-zoom logic, event wiring, saved-variable lifecycle, slash commands. |
| `CameraSettings.lua` | The single, verified access layer for every engine camera setting. |
| `ZoomReconciler.lua` | Single owner of where the camera settles after a BAV-handled first-person toggle; defers one coalesced write so probe pairs cancel out. |
| `SprintWatch.lua` | Shared event-driven sprint detector and the canonical is-sprinting sample every feature that needs sprinting subscribes to. |
| `Ease.lua` | Shared time-based easing primitive: one self-tearing updater lifecycle behind every glide (FOV smoothing and preset transition). |
| `CameraResponse.lua` | Global response profile: transition duration/curve plus shared ownership of ESO camera smoothing. |
| `OptionsWatch.lua` | Shared watcher for the settings window: one fragment subscription and the canonical open/closed state every feature suspends on. |
| `DynamicFov.lua` | Optional zoom-dependent field of view. |
| `FovArbiter.lua` | Single owner of third-person FOV precedence (dynamic FOV vs. preset holds). |
| `ContextPresets.lua` | State-driven cinematic bundles with snapshot/restore and persistence. |
| `ShoulderControl.lua` | Optional over-the-shoulder swap (auto-by-state or manual); single owner of the shoulder offset. |
| `PvpMode.lua` | Lightweight PvP world mode: selects a manual zoom step and safely suppresses/restores camera shake. |
| `OffsetNudge.lua` | Hold-to-nudge for horizontal and vertical offsets, recenter bind, and the short-lived on-screen readout. |
| `Settings.lua` | SavedVariables, defaults, and the LibAddonMenu panel. |

---

## How it works

A few small maps of the moving parts. None of this is required reading to *use*
the addon - it is here for the curious and for anyone reading the source.

### State priority - only one preset wins

Context presets never fight each other. At most **one** state is active at a
time, resolved top-down by priority and gated by each state's style choice:
the first state that is both physically active *and* set to a style other than
Off wins.

```
   physical state(s) active ──▶  resolve by priority  ──▶  one winner
                                 ┌───────────────────┐
   highest  │  werewolf    ─────▶│ first active state │
            │  combat      ─────▶│ with a non-Off     │
            │  stealth     ─────▶│ style wins; rest   │──▶ apply bundle
            │  interaction ─────▶│ are ignored        │
            │  mounted     ─────▶│                    │
            │  swimming    ─────▶│                    │──▶ none? → restore
   lowest   │  sprint      ─────▶│                    │      your framing
                                 └───────────────────┘
```

Werewolf deliberately outranks combat - a transformation should win even mid-fight.

### Dynamic FOV - zoom drives the lens

Dynamic FOV maps the current zoom distance to a field of view through
`FovArbiter`. A context-preset hold overrides it while active.

```
  zoom distance ─▶ DynamicFov ─▶ FovArbiter ─▶ FOV
                          │
                          └─ unless a preset hold owns FOV
```

### Over-the-shoulder - one owner for the shoulder

When shoulder swap is on it owns the shoulder offset outright. In **auto** mode it
swings while any chosen state is active and recentres when you leave them all; in
**manual** mode `/bav shoulder` drives it. Either way, `ContextPresets` cedes the
shoulder so the two never write it out of turn.

```
   mode = auto                              mode = manual
   ┌───────────────────────┐               ┌───────────────────────┐
   │ in a chosen state? ───▶│ swing to side │ /bav shoulder ───────▶│ swing / toggle
   │ left them all?    ───▶│ recentre      │ (left/right/center)    │
   └───────────────────────┘               └───────────────────────┘
        │ first swing: snapshot + persist your real shoulder ──▶ restored on
        │                                                        recentre / crash
        └─ ContextPresets.OwnsShoulder()? → stealth preset skips shoulder
```

### Snapshot & restore - surviving a crash

The first time a preset takes over, your real camera is snapshotted **and
persisted** to SavedVariables. So even a `/reloadui`, logout, or crash mid-preset
hands your genuine framing back next session - never the preset's offsets.

```
  preset takes over          session ends abruptly         next login
  ┌──────────────┐           ┌──────────────────┐          ┌──────────────┐
  │ snapshot live│           │ /reloadui · crash│          │ recover from │
  │ camera  ─────┼──persist──▶│ logout while a   │──saved──▶│ persisted    │
  │ to SavedVars │           │ preset is active │          │ snapshot,    │
  └──────────────┘           └──────────────────┘          │ then clear it│
        │                                                   └──────────────┘
        └─ back to default in-session ──▶ restore + clear ─────────┘
```

This breaks the drift cycle where a dirty (offset) camera would otherwise be
saved as the new baseline.

---

## Development checks

Run the focused regression checks from the addon directory with Lua 5.1:

```powershell
lua .\tests\regression.lua
```

The checks use ESO API stubs to cover zoom boundaries, failed reads/writes,
PvP zoom steps, deferred saving, preset-state normalization, and offset-key
hold/release behavior. They do not load into ESO or replace in-game checks of
camera rendering, reload recovery, and interactions with other addons.

