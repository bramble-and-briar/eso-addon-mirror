# MugShot

A custom target frame with personalized portraits, buff and debuff tracking, and configurable display settings.

<!-- commits:start -->
<!-- ESOUI:start -->
## History

### 2026.10.31-101047 — Improve target tracking, refine effect layouts, and align default frame positioning.

#### Fixed

- Prevent the target frame from targeting the local player when enemies die in third-person view by checking AreUnitsEqual against "player";
- Clear dead targets promptly by aligning EVENT_UNIT_DEATH_STATE_CHANGED handling with native ZOS behavior and removing the ineffective C++ event filter;
- Prevent buff and debuff text clipping by positioning source multipliers at BOTTOMLEFT and stack counts at TOPRIGHT on the outer slot frame, with centered timers set to 13pt bold.

#### Added

- Add `/mugshot debuffs [on|off]` to toggle group and companion debuff tracking, enabled by default;
- Add a 350 ms target retention grace period during active combat to reduce frame flicker during dodges and rapid camera movements;
- Centralize UI and reaction colors in Constants.RGBA.

#### Improved

- Align the default frame position with the native ESO target frame anchor: TOP, GuiRoot, TOP, 0, 88;
- Reuse Defaults.position as the single source of truth for `/mugshot reset`;
- Recycle active buff and debuff parsing buffers to reduce garbage collection overhead;
- Decouple Move Mode from gameplay by registering player vitals listeners only while configuring the frame;
- Resolve tracked group debuff names dynamically through GetAbilityName(abilityId) to support the game client's language without manual translation tables.

#### Removed

- Remove the hardcoded multilingual dictionary for tracked group debuffs;
- Remove redundant API existence guards and duplicate event filter checks.

### 2026.10.30-101046 — Eliminate redundant API guards, leverage native event filters, and streamline namespace.

- Consolidate addon initialization into Defaults.lua and remove obsolete Namespace.lua;
- Cache MugShot namespace locally across all modules for optimized upvalue access;
- Utilize native EVENT_MANAGER filters for EVENT_ADD_ON_LOADED, power, and shield events;
- Remove redundant nil checks and pcall wrappers around standard ESO UI and engine APIs;
- Add AI disclosure notice and remove version constraints from OptionalDependsOn in manifest.

### 2026.10.29-101045 — Streamline effect filtering, optimize rendering, and eliminate target flicker.

- Filter effects by castByPlayer during extraction to remove raid clutter and avoid unnecessary allocations;
- Replace effect truncation with preallocated slots and dynamic row expansion;
- Reuse presentation buffers and share timer and stack strings to minimize garbage collection;
- Add UI dirty flags to skip redundant updates and layout recalculations;
- Cache frequently used Lua and ESO functions in local upvalues;
- Keep the native target frame suppressed during target changes and target loss;
- Replace fade transitions with immediate visibility updates;
- Refactor target policies into extensible strategies;
- Unify slash commands with optional LibSlashCommander autocompletion and native fallback;
- Use official ESO APIs for trial detection.

### 2026.10.28-101044 — Refactor portraits, improve frame layouts, and fix move-mode vitals.

- Resolve portrait icons dynamically through collectible and ability APIs using a unified mapping;
- Prevent reticleover target updates from overwriting player preview vitals in move mode (/mugshot move);
- Clear the target frame when the target dies (EVENT_UNIT_DEATH_STATE_CHANGED);
- Expand the health bar to full width when no portrait icon is displayed;
- Remove the 10-effect limit on buffs and debuffs, and format durations over 60 seconds in minutes or hours.

### 2026.10.26-101000 — Align addon manifest and metadata with ESOUI compliance guidelines.
<!-- ESOUI:end -->
### 2026-10-26 — Enhance UI layout and colors, add live move preview, Hodor icon support, and fix class portrait fallbacks.

### 2026-10-25 — Initial stable release.

<!-- commits:end -->
