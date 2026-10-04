# LibZoneTemp — Changelog

Full version history for LibZoneTemp. See README.md for current features, installation, and usage.

---

## What's New in 2.3.19

- **Added the 42 real zones LibZone 9.01 has that this library didn't.**
  Neither table had any entry above zoneId 1584. LibZone's GitHub history
  shows 6 of them are genuinely new since July (Update 51 / Season One:
  The Nowhere Vault 1533, Voyage on the Abecean Sea 1570, the second
  instances of March of Sacrifices 1592 and Moon Hunter Keep 1593,
  Sheogorad Chateau 1609, Grotto of Desires 1610). The other 36 were
  already in LibZone by April 2026 (Solstice/Worm Cult zones, the Night
  Market, Shivering Isles, Daggerfall, the Thieves Guild storyline
  locations, several houses) but had never been added here.
- **Every value copies an existing entry**, named in each line's comment
  ("basis: ..."), as reviewed and approved by the author - e.g. Solstice
  sub-zones copy Solstice or its delves, Night Market dungeons copy
  Fargrave's, Sheogorad Chateau copies Amaya Lake Lodge, Grotto of
  Desires copies Pantherfang Chapel. Weather profiles were added only
  for Night Market (copies Fargrave), Daggerfall (copies Glenumbra) and
  the second March of Sacrifices (copies 1055); everything else
  inherits as before.
- **The Nowhere Vault (1533 and 1583) is deliberately neutral**: the
  magic of the Vault protects the player from the elements. Air is 25°C
  so that, after `INTERIOR_MODIFIER` (-3), it settles on 22°C -
  Frostfall's neutral point, inside RND's 10-25°C comfort band. Water is
  22°C. The reduced indoor time-of-day swing still moves it by roughly
  -1.5/+0.9°C, so it's neutral on average, not to the decimal. It is
  also only 22°C when the player is treated as indoors (LibInteriorDetection
  1.3.7+ marks it interior); without LibInteriorDetection, the fallback
  delve/dungeon check may not flag it and it would read 25°C.
- **Manifest APIVersion bumped to `101051 101052`** (Update 51 /
  Season One is live; LibZone 9.01 also lists 101052).
- **Fixed two wrong dependency links in the README.** LibZone pointed at
  `info1496` and LibClockTST at `info2360`; neither is those libraries'
  ESOUI page. They now point to
  https://www.esoui.com/downloads/info2171-LibZone.html and
  https://www.esoui.com/downloads/info2533-LibClockTST.html, both
  confirmed against the live ESOUI listings. The LibAddonMenu-2.0 link
  (`info7`) was already correct.
- **Linked the optional LibInteriorDetection dependency** too:
  https://www.esoui.com/downloads/info4816-LibInteriorDetection.html.
- **Dev placeholder zoneIds** (EngVerify, Pregame, ZTestBarbershop,
  ZWicksTest, the two "Not Used/REUSE?" slots, RTeaser1, U44 Monster VO)
  remain intentionally omitted.
- **What wasn't verified**: none of the new values were measured in-game.
  Several locations' exact parent zone is unconfirmed (Birien Manor,
  Hidden Library, Rols Boron's Warehouse assumed near Daggerfall; A
  Battle at Sea assumed on the Abecean Sea, per author). UESP lists ~17
  rooms inside the Nowhere Vault; if they share a zoneId, per-room values
  would need a map-based lookup, which this library doesn't have.

---

## What's New in 2.3.18

- **Reverted the version floor added to `## OptionalDependsOn: LibInteriorDetection`
  in 2.3.17** (back to no version, just the bare name). A follow-up
  moderator comment clarified that `OptionalDependsOn` does not support
  `>=` version syntax at all - only `DependsOn` does, since a missing
  *hard* dependency is what actually stops an addon from loading, which
  is what the version check exists to guard against. An optional
  dependency doesn't block loading either way, so a version check on it
  isn't just unsupported syntax, it's not a meaningful concept there.
- **This was likely a real functional bug, not just a style issue**:
  `LibInteriorDetection>=28` was almost certainly being read as a
  literal dependency name (i.e. "look for an addon literally called
  `LibInteriorDetection>=28`"), which would never match the real
  `LibInteriorDetection` addon - meaning the optional-dependency
  detection may have been silently failing to recognize
  `LibInteriorDetection` as installed at all, even when it genuinely was.
- **This also resolves the tension flagged in 2.3.17's own entry below**:
  that entry raised a concern that adding the floor might reopen a
  previously-solved blocking-risk tradeoff. It turns out the original
  no-floors-on-optional-dependencies precedent was correct all along;
  2.3.17's floor was the actual mistake, not a justified reversal of it.

---

## What's New in 2.3.17

- **Added a version floor to the `## OptionalDependsOn: LibInteriorDetection`
  entry** (now `>=28`), in response to an ESOUI moderator complaint on a
  sibling addon stating that version checks are mandatory for
  `OptionalDependsOn` too, not just hard `DependsOn`.
- **Worth flagging directly**: this reopens a tradeoff this project
  previously decided the other way on purpose, for a different addon
  (Realistic Needs and Diseases) - version floors were deliberately
  *removed* from its `OptionalDependsOn` entries specifically because a
  floor can cause the whole addon to fail to load if the optional
  dependency is present but below that floor, which defeats the point of
  it being optional rather than required. The moderator's written rule
  says to add the floor regardless, so it's been added here to comply -
  but if a stale-but-present LibInteriorDetection install is ever
  reported as blocking LibZoneTemp from loading entirely (rather than
  just gracefully falling back to the pre-LibInteriorDetection interior
  detection), that specific failure mode is the reason, and removing
  this floor again would be the fix, written policy or not.

---

## What's New in 2.3.16

- **Interior detection now prefers LibInteriorDetection when installed.**
  Previously, `lib.GetCurrentTemperature()` determined `isInterior` solely
  via `LibZone:GetCurrentZoneAndGroupStatus()` (true only for delves,
  public dungeons, group dungeons, and trials) - meaning ordinary
  buildings, player houses, and any other real interior got no
  interior treatment at all (no `INTERIOR_MODIFIER`, no shielding from
  weather/time-of-day). If `LibInteriorDetection` is installed, its live,
  general-purpose `IsPlayerIndoors()` check is used instead, covering
  those cases too. If it isn't installed, or its state hasn't been
  established yet, behavior is unchanged - falls back to the original
  LibZone-based delve/dungeon/trial check.
- **Added `LibInteriorDetection` as a new `## OptionalDependsOn`** - not a
  hard requirement, since other addons may depend on `LibZoneTemp`
  without wanting to also require `LibInteriorDetection`. No version
  floor, matching this project's established convention for optional
  dependencies (a stale floor could block loading of an otherwise-
  optional library).
- Updated the `isInterior` parameter documentation on
  `GetBaseTemperatureForZone`/`CalculateTemperature` to reflect the
  broader definition.
- No changes to `INTERIOR_MODIFIER`, the weather/time-of-day shielding
  logic itself, or any other calculation - only what feeds the
  `isInterior` boolean into them.

---

## What's New in 2.3.15

- Manifest `## APIVersion` updated to `101050 101051`, covering the newly
  released 101051 alongside the previous 101050.

---

## What's New in 2.3.14

- **Updated the AI-assistance notice**, in both this README and the
  manifest `## Description`, to reflect that the library has now been
  reviewed and tested in-game by the author for functionality —
  previously it stated the opposite (not yet independently validated).

---

## What's New in 2.3.13

- **Reworked zone storage to be keyed by real zoneId directly, with no
  runtime library lookup involved at all.** Previously, `LibZoneTemp`'s
  three climate tables were authored by English zone *name* and converted
  to zoneId once at load via `LibZone:GetAllZoneData()`. They're now
  authored directly with the zoneId as the table key — `LibZone` is no
  longer used for zone-name resolution anywhere, at load or at runtime.
  Every zoneId was cross-checked against LibZone's own public-domain
  zoneId/name data file (not fabricated or guessed — see "Design Notes"
  below for the exact source and how to re-verify against a newer one).
  Two zones from the old name-keyed tables didn't resolve during that
  cross-check: `"Morrowind"` turned out to be a duplicate alias of
  Vvardenfell's own zoneId, not a separate zone, and was dropped;
  `"Amenos"` has no confirmed zoneId yet and is called out in a comment
  as pending rather than guessed at.
- **The settings-panel zone picker no longer uses `LibZone` either.** It
  now enumerates zones directly via ESO's native `GetNumZones()` /
  `GetZoneId(zoneIndex)` / `GetZoneNameById(zoneId)`, which are already
  confirmed API calls this library uses elsewhere. A pleasant side effect:
  the picker's zone names now display in the player's own client
  language automatically, rather than always in English.
- Updated "Design Notes" and added "Client Language Support" (see above)
  to describe the new architecture accurately.

---

## What's New in 2.3.12

- **SavedVariables are now server-dependent.** `ZO_SavedVars:NewAccountWide`
  previously passed `nil` for the namespace argument, so EU, NA, and PTS all
  read and wrote the *same* account-wide save table — logging into a
  different server would silently overwrite another server's zone
  temperature overrides. Now namespaced by `GetWorldName()`
  (`"EU Megaserver"` / `"NA Megaserver"` / `"PTS"`), so each server keeps its
  own overrides. **One-time effect of this fix:** any overrides set before
  this version will appear to have been "reset" the first time you load
  each server after updating — they're still in the SavedVariables file
  under the old shared location, just no longer read from there. Re-set them
  once per server going forward.
- **Removed the dead `if not LibZone then return end` / `if not LAM then
  return end` guards.** Both `LibZone` and `LibAddonMenu-2.0` are hard
  `## DependsOn` requirements, so ESO will not load this addon at all if
  either is missing — the guards could never actually fire and were pure
  noise.
- **`BuildZoneIdMaps()` now always resolves against LibZone's English ("en")
  table specifically**, rather than falling back to "any available
  language" if `"en"` were ever absent. LibZone ships an `"en"` table on
  every client language, so the fallback branch was both unreachable and,
  had it ever been reached, would have silently broken every zone lookup
  for non-English clients (our source tables are authored in English; the
  old code's language-guessing meant a non-English fallback table's names
  wouldn't match anything in the source tables at all).
- **Unresolved zone names are no longer silent.** If any authored zone name
  in the source tables doesn't resolve to a zoneId via LibZone (a
  punctuation/apostrophe mismatch, or a zone LibZone doesn't carry), that
  previously degraded silently to `DEFAULT_TEMP` with no indication anything
  was wrong. `BuildZoneIdMaps()` now prints a one-time warning listing every
  unresolved name, so this class of bug is actually visible instead of
  looking like "just a wrong number."
- **Corrected a factual error in "Design Notes" below** ("why names and not
  integer IDs") — it had zoneId and zoneIndex backwards. See the corrected
  entry.
- Added the [Client Language Support](#client-language-support) section
  above, clearly stating which client languages this library covers and why.

---

## What's New in 2.3.11

- **Fixed the settings panel's author field**, which was still the literal
  placeholder text `"YourName"` — never actually updated even after the
  `## Author` manifest field itself was corrected. Also bumped the internal
  `LIB_VERSION` guard (previously stale at `12`) to match the manifest
  `## AddOnVersion`, since the panel's displayed version reads directly
  from that constant.

---

## What's New in 2.3.10

- **Standardized the author credit** to `@Kreksar5 and Claude.ai` in the
  `## Author` manifest field and this README's byline, and named Claude.ai
  specifically (rather than generic "AI assistance") in the manifest
  description and the AI-assistance disclosure above, matching the crediting
  convention used across this addon's companion libraries.

---

## What's New in 2.3.9

- **Fixed zone temperature overrides not applying to delves, dungeons, and
  trials.** Interior zones have no climate-table entry of their own and
  inherit their base temperature from their overland parent zone; the
  override lookup only ever checked the *parent's* ID, so an override set
  on the interior zone itself (as offered in the settings dropdown) was
  saved but silently never read back. The override lookup now checks the
  player's exact current zone first, before falling back to the climate
  zone used for the base-temperature table.
- **Added a live "Currently Active Overrides" list** to the settings panel,
  showing every zone with an override currently set, in both °C and °F.
- **Added a Celsius/Fahrenheit reference chart** to the override section's
  description, with a short note on the kind of zone each range typically
  represents, to help you pick a sensible override value.

---

## What's New in 2.3.8

- **Corrected the `## Author` manifest field**, which was still the literal
  placeholder text "YourName" — never actually filled in. Fixed to the real
  author.
- **Added the required AI-assistance disclosure** to the manifest description
  and this README, per ESOUI's addon release rules.
- **Added a version floor (`>=1`) to the `LibClockTST` dependency**, which
  previously had none.

---

## What's New in 2.3.7

- **Full API audit against the official ESOUI API 101050 documentation.**
  Every function call, method call, and constant referenced across the
  library was cross-checked against the API doc and, where the doc didn't
  cover it (third-party libraries), against the live ESOUI source. No
  invalid or deprecated API usage found — the `LibZone`/`LibClockTST` calls
  (`GetAllZoneData`, `GetCurrentZoneIds`, `GetCurrentZoneAndGroupStatus`,
  `Instance`, `GetTime`, `RegisterForTime`) are all legitimate calls into
  those libraries and correctly used. No code changes required.

---

## What's New in 2.3.6

- **Corrected `LibAddonMenu-2.0` dependency floor**: was mistakenly bumped to
  `>=45` in 2.3.5, but LibAddonMenu's own manifest documentation shows `43`
  as the latest available version, not `45`. Fixed to `>=43`. The 2.3.5 entry
  below has also been corrected to reflect the right number.

---

## What's New in 2.3.5

ESOUI release-rules compliance pass — no zone-data changes.

- **`## APIVersion` updated** from the stale `101040` to `101049 101050` (current Live/PTS).
- **`LibAddonMenu-2.0` dependency floor bumped** from `>=30` to `>=43`, matching the version cited as current in LibAddonMenu's own manifest documentation.
- **Fixed a version-string mismatch**: this README's header said `2.3.0` while the manifest's `## Version` already said `2.3.4` — now synced.
- **Fixed a duplicate/mislabeled changelog section** (see below — the second "What's New in 2.3.0" entry has been relabeled `2.3.1`, since it describes a separate, later correction pass).
- **Reviewed for global variable leaks** — none found; the library already follows the single-global-table pattern (`LibZoneTemp = LibZoneTemp or {}` / `local lib = LibZoneTemp`).
- **Reviewed against "what addons cannot do"** — none found. This library only reads zone/time/weather state to compute a number; it doesn't touch any restricted behavior.

---

## What's New in 2.3.0

Version 2.3.0 is the second UESP-verified correction pass, covering the remaining **405 zones** (rows 301–705). **38 corrections** were applied.

### Key Correction Themes

**Solstice (tropical island) zones** — all Solstice locations introduced in Seasons of the Worm Cult were assigned incorrect cold-zone temperatures. Solstice is a tropical island south of Murkmire (~32 °C); affected zones corrected include Tarnur Mine (−8 °C → 30 °C), Li-Xal Pass (4 °C → 28 °C), Vosgah Shrine (4 °C → 30 °C), and Vale of Revelry (20 °C → 28 °C).

**Nordic barrow/crypt zone mis-assignments** — Shroud Hearth Barrow, Taarengrav Barrow, and Nimalten Barrow were all in **The Rift** (6 °C), not the arctic; corrected from −8 °C → 4 °C each. Wittestadr Crypts and Trolhetta Cave are in **Eastmarch** (−2 °C), not arctic.

**Clockwork City** — Slag Town Outlaws Refuge reassigned from 4 °C → 22 °C (mechanically regulated Brass Fortress environment).

**Cyrodiil/Stormhaven/Deshaan** — Underpall Cave (Cyrodiil, 14 °C), Pariah Catacombs (Stormhaven, 10 °C), Reservoir of Souls (Deshaan, 15 °C) all corrected from −8 °C.

**Fargrave/Mirrormoor** — Shattered Mirror Isle (20 °C → 36 °C) and Loom of the Untraveled Road (15 °C → 32 °C) correctly placed in Ithelia's hot Oblivion realm.

**Western Skyrim interior calibration** — Proudspire Manor, Solitude Outlaws Refuge, Snowmelt Suite, and Tzinghalis's Tower all adjusted downward to reflect WS = −10 °C with appropriate interior insulation offsets.

---

## What's New in 2.3.1

Version 2.3.1 is the third UESP-verified correction pass (rows 301–400). **16 zone entries** were corrected after cross-referencing confirmed locations against UESP.

### Notable Fixes
- **Kingscrest Cavern**: NE Cyrodiil cave (was 36°C → 15°C; not Bangkorai)
- **Kushalit Sanctuary**: N Vvardenfell/Red Mountain slopes (note corrected to Vvardenfell)
- **Lipsand Tarn**: Colovian Highlands Ayleid ruin in NW Cyrodiil (was 4°C → 14°C; not a mountain tarn)
- **Lucky Cat Landing**: Senchal player house in S Elsweyr (was 22°C → 28°C)
- **Nighthollow Keep**: Blackreach: Arkthzand Cavern deep interior (was 8°C → −4°C)
- **Nikolvara's Kennel**: Wrothgar cave SW of Orsinium (was 5°C → −5°C)
- **Obsidian Scar**: Rivenspire volcanic cave (was 28°C → 18°C; geothermally warm but still Rivenspire)
- **Odious Chapel**: Shadowfen (Stillrise Village chapel, was 12°C → 28°C)
- **Old Coin Fort**: N tip of Amenos tropical island (was 16°C → 24°C)
- **Maelstrom Arena**: Pocket realm of Fa-Nuit-Hen (was 10°C → 20°C; not cold Wrothgar)

---

## What's New in 2.2.0

Version 2.2.0 is a UESP-verified correction pass. **48 zone entries** from the v2.1.0 expansion have been corrected after cross-referencing each zone's confirmed location against UESP wiki sources.

### Corrections Summary
The primary error pattern was zones assigned to the wrong parent region entirely, producing temperatures that were wildly off — most commonly cold-zone values (−8 °C) applied to locations in Bangkorai, Greenshade, Summerset, Southern Elsweyr, or Amenos, and vice versa. Notable individual fixes include:

- **Coldrock Diggings**: Alik'r Desert mine (was −8 °C → 36 °C)
- **Forsaken Citadel**: Southern Elsweyr (was 4 °C → 28 °C)
- **Ghost Haven Bay**: Amenos tropical cove (was 8 °C → 24 °C)
- **Halls of the Highmane**: Southern Elsweyr Khajiiti ruin (was 8 °C → 26 °C)
- **Hildune's Secret Refuge**: Rivenspire cave (was 32 °C → 6 °C)
- **Istirus Outpost / Arena**: West Weald/Cyrodiil battleground, not Reaper's March (was 35 °C → 18 °C)
- **Destruction's Solace**: Deadlands capital fortress (was 40 °C → 50 °C)
- All 48 corrections include matching water temperature updates.

---

## What's New in 2.1.0

Version 2.1.0 is a UESP-verified data expansion. The zone database has grown from ~317 entries to over **1,000 named zones**, adding **705 new entries** sourced directly from the UESP wiki and covering the full breadth of ESO's explorable areas.

### New Coverage
- **Delves, trials, arenas, and public dungeons** across all chapters and DLC
- **Instanced interiors**: manors, Outlaws Refuges, city districts, crypts, and tombs
- **Daedric and Oblivion sub-realms**: Colored Rooms, Spiral Skein, Hunting Grounds, and more
- **Aquatic zones**: Abecean Sea and other ocean/coastal surfaces
- **Player housing areas** with climate appropriate to their region
- Air temperatures derived from lore-accurate UESP climate descriptions
- Water temperatures for all new entries

All new entries include a descriptive comment drawn from UESP source notes.

---

## What's New in 2.0.0

Version 2.0.0 is a major data expansion. The zone temperature tables now cover **all overland zones plus hundreds of named sub-zones**, including:

### New Overland / Chapter Zones
- **West Weald** (19 °C) — southwestern Cyrodiil woodlands and rolling hills
- **Bleakrock Isle** (−8 °C) — frozen starter island in the Sea of Ghosts
- **Bal Foyen** (20 °C) — warm coastal Morrowind delta
- **Stros M'Kai** (34 °C) — arid sun-baked Hammerfell island
- **Betnikh** (15 °C) — temperate Orc island off Glenumbra
- **Khenarthi's Roost** (30 °C) — warm tropical Khajiit island
- **Blackreach: Arkthzand Cavern** (−5 °C) — cold underground Dwemer Blackreach beneath The Reach

### Fire / Lava Sub-Zones
These zones receive **explicit high temperatures** rather than inheriting from their parent, because they contain active lava, dragon fire, Oblivion portals, or extreme geothermal activity:

| Zone | °C | Notes |
|---|---|---|
| City of Ash II | 55 | Deepest Mehrunes Dagon Oblivion plane |
| The Path of Cinders | 53 | Lava-bordered Deadlands path |
| Tormented Spire Summit | 54 | Summit of most active Stonefalls volcanic vent |
| The Deadlands: Testing Grounds | 52 | Deadlands sub-region |
| Burning Gyre Keep | 52 | Deadlands fortification |
| City of Ash I | 50 | Mehrunes Dagon Oblivion plane |
| Bloodroot Forge | 48 | Hircine's ancient forge; lava channels in The Reach |
| The Cauldron | 44 | Deep underground Blackwood forge dungeon |
| Blessed Crucible | 44 | Rift arena over a volcanic vent |
| Ashalmawia | 42 | Vvardenfell Daedric shrine on volcanic vent |
| Sunspire | 42 | Northern Elsweyr dragon trial; desert sun + dragon fire |
| Dragonhold | 46 | Southern Elsweyr dragon lair; volcanic peak |
| Khaj Rawlith | 30 | Ancient underground Anequine temple in hot Reaper's March; warm, stuffy, dark-fire corruption |

### Ice / Frozen Sub-Zones
These zones receive **explicit low temperatures** below their parent zone:

| Zone | °C | Notes |
|---|---|---|
| Icereach | −16 | Frigid isle in the Sea of Ghosts; polar cold |
| Frostvault | −14 | Dwarven vault buried in a thawing glacier |
| Ice-Heart's Lair | −14 | Frozen bandit cave in high Wrothgar peaks |
| Kyne's Aegis | −12 | Offshore Norse sea fortress trial; freezing winds |
| Frostbreak Fortress | −12 | Frost-covered Orc fortress in Wrothgar |
| Frozen Coast | −12 | Western Skyrim coastal; sea ice and blizzards |
| Direfrost Keep | −10 | Ancient Nord ice fortress; permafrosted interior |
| The Frigid Grotto | −10 | Eastmarch; frost atronachs throughout |
| Stone Garden | −8 | Underground frozen lycanthrope lab under Skyrim |
| Bleakridge Barrow | −8 | Frozen Nord barrow in Western Skyrim |
| Icehammer's Vault | −8 | Sealed ice vault in Eastmarch |
| Chillwind Depths | −8 | Underground frozen depths in Western Skyrim |
| Coldwind's Den | −8 | High mountain den in Wrothgar; extreme cold |
| Greymoor Keep | −8 | Half-buried in Western Skyrim's frozen earth |
| Scalecaller Peak | −6 | Icy Wrothgar mountain summit with dragon |
| Castle Thorn | −6 | Vampire stronghold in Western Skyrim |
| Labyrinthian | −6 | Ancient ruins; deeply cold |
| The Chill Hollow | −6 | Ice-filled Eastmarch hollow cave |

### Underground / Dungeon Coverage
Hundreds of delves, public dungeons, group dungeons, and trials across all zones now have explicit entries rather than falling back to the overland default. Key examples:

- **Fungal Grotto I & II** (24 °C) — warm, damp sea cavern in Stonefalls
- **Darkshade Caverns I & II** (20–22 °C) — geothermal kwama mine
- **Ruins of Mazzatun** (28 °C) — hot, humid Hist-tree complex in Black Marsh
- **Cloudrest** (14 °C) — Summerset trial near the summit of Eton Nir; cold at altitude
- **Halls of Fabrication** (24 °C) — Vvardenfell trial; heat from fabricant manufacturing
- **All Vvardenfell egg mines and Dwemer ruins** (30–34 °C) — geothermal Morrowind underground
- **All Clockwork City sub-zones** (20–22 °C) — temperature-controlled mechanical realm

### Water Temperature Expansion
All newly added zones also include specific **water temperatures**, from −1 °C (Frostvault glacier meltwater, Icereach polar water) to 60 °C (Deadlands and City of Ash II).

### Weather Profile Expansion
Newly added zones include weather profiles:
- **Icereach**: 5% rain / 80% snow — constant blizzard conditions
- **Kyne's Aegis**: 10% rain / 70% snow
- **Bleakrock Isle**: 15% rain / 60% snow
- **Scalecaller Peak**: 5% rain / 70% snow
- **Frozen Coast**: 10% rain / 60% snow
- All underground, Oblivion, and enclosed zones: 0% rain / 0% snow
