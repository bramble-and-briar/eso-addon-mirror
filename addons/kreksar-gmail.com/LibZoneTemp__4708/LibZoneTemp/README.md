[size=6][b]LibZoneTemp[/b][/size]
[i]by @Kreksar5 and Claude.ai[/i]

[color=orange][b]AI-ASSISTED ADDON.[/b][/color] Written with Claude.ai. This library has been reviewed and tested in-game by the author for functionality.

A library for [i]The Elder Scrolls Online[/i] that calculates ambient temperatures for all overland zones and hundreds of sub-zones (delves, dungeons, trials, starter zones, and Daedric realms) based on lore-accurate climate data, the current in-game time of day (via LibClockTST), weather probability, and whether the player is swimming.

For the full version history, see the Change Log tab, or CHANGELOG.md included in the download.

[size=5][b]Overview[/b][/size]

LibZoneTemp provides a single, consistent source for ambient temperature data across ESO zones. It is intended to be consumed by other addons that want to display, react to, or simulate temperature-driven gameplay — such as weather mods, survival systems, immersion HUDs, or RP tools.

All internal calculations are performed in [b]Celsius[/b]. Fahrenheit conversion is available for display purposes via [code]lib.FormatTemperature()[/code] and the user-facing settings panel.

[size=5][b]Client Language Support[/b][/size]

LibZoneTemp's temperature lookups are keyed entirely by real, language-independent [b]zoneId[/b] — never by zone name, and never resolved from one at runtime (see Design Notes below for how the tables were verified). Because of that, temperature lookups themselves work identically regardless of the client's display language.

The only place a zone [i]name[/i] is shown to the player is display text: the settings-panel zone picker, and the zoneName returned by [code]lib.GetCurrentTemperature()[/code]. Both come directly from ESO's own native [code]GetZoneNameById(zoneId)[/code] function — not from any third-party library — so they're automatically in whatever language the client itself is running, with the same coverage as the base game (every officially supported client language: en, de, fr, ru, es, zh, ja).

[size=5][b]Features[/b][/size]

[list]
[*][b]Lore-accurate base temperatures[/b] for every overland zone and hundreds of sub-zones through Solstice (2025) and the Season One zones (2026)
[*][b]Explicit overrides for fire/lava zones[/b] — City of Ash, Deadlands, Tormented Spire, Bloodroot Forge, The Cauldron, and more
[*][b]Explicit overrides for ice/frozen zones[/b] — Icereach, Frostvault, Direfrost Keep, Kyne's Aegis, and more
[*][b]Time-of-day modifiers[/b] using the in-game Tamriel clock (dawn, day, dusk, night)
[*][b]Climate/weather modifiers[/b] derived from zone lore
[*][b]Water temperature[/b] when the player is swimming (IsUnitSwimming)
[*][b]Interior/dungeon penalty[/b] — interior spaces are shielded from weather and see reduced diurnal swing; many now have their own explicit temperatures. Interior detection prefers [b]LibInteriorDetection[/b] when installed (covers ordinary buildings and player houses, not just delves/dungeons/trials), falling back to LibZone's delve/dungeon/trial status otherwise
[*][b]Parent zone inheritance[/b] — unlisted child zones fall back to their parent's climate data
[*][b]Per-zone user overrides[/b] via the LibAddonMenu-2.0 settings panel
[*][b]Celsius / Fahrenheit toggle[/b] in settings
[*][b]Live updates[/b] via LibClockTST subscription and EVENT_PLAYER_ACTIVATED
[*][b]Debug slash command[/b] /ztemp for on-demand snapshots
[/list]

[size=5][b]Dependencies[/b][/size]

Please install the newest available version of each:

[list]
[*][url=https://www.esoui.com/downloads/info2171-LibZone.html][b]LibZone[/b][/url] — reports the player's current zoneId/parentZoneId and delve/dungeon/trial status; not used for zone names
[*][url=https://www.esoui.com/downloads/info7-LibAddonMenu.html][b]LibAddonMenu-2.0[/b][/url] — settings panel UI
[*][url=https://www.esoui.com/downloads/info2533-LibClockTST.html][b]LibClockTST[/b][/url] — in-game lore time (hour/minute) for time-of-day modifiers
[/list]

All three above must be installed and loaded for full functionality — LibZone, LibAddonMenu-2.0, and LibClockTST are all hard dependencies, so ESO will refuse to load LibZoneTemp at all if any is missing. The library degrades gracefully if LibClockTST's clock instance isn't ready yet (defaulting to noon).

[list]
[*][url=https://www.esoui.com/downloads/info4816-LibInteriorDetection.html][b]LibInteriorDetection[/b][/url] — optional. If installed, its live indoor/outdoor detection is used for the interior penalty and weather/time shielding instead of the narrower delve/dungeon/trial-only fallback. Nothing breaks if it isn't installed.
[/list]

[size=5][b]Installation[/b][/size]

[list=1]
[*]Download and unzip LibZoneTemp into your addons folder:
[code]<ESO User Data>\live\AddOns\LibZoneTemp\[/code]
The folder should contain:
[code]LibZoneTemp/
├── LibZoneTemp.lua
├── LibZoneTemp.txt
├── CHANGELOG.md
└── README.md[/code]
[*]Ensure all dependencies (see above) are also installed — always use the newest available version of each.
[*]Launch ESO. LibZoneTemp will initialise automatically on the EVENT_ADD_ON_LOADED event.
[*]Optionally access settings via the in-game [b]Settings → Addons → LibZoneTemp Settings[/b] panel, or by typing [b]/libzonetemp[/b] in chat.
[/list]

[size=5][b]Public API[/b][/size]

[code]
-- Returns the current ambient temperature for the player's zone.
-- When the player is swimming, returns the zone's water temperature.
-- formattedString respects the user's unit preference ("23.4°C" / "74.1°F").
local tempC, zoneName, tempF, formatted = lib.GetCurrentTemperature()

-- Returns the base temperature for a given zone ID (before time/weather modifiers).
local baseTemp = lib.GetBaseTemperatureForZone(zoneId, isInterior)

-- Returns the full temperature for arbitrary input values. Always Celsius.
-- Pass isSwimming = true to get the zone's water temperature instead.
local temp = lib.CalculateTemperature(zoneId, isInterior, loreHour, isSwimming)

-- Converts and formats a Celsius value using the user's saved unit preference.
-- Safe to call before savedVars is loaded (falls back to Celsius).
local str = lib.FormatTemperature(celsius)
[/code]

[size=5][b]Slash Command[/b][/size]

Type [b]/ztemp[/b] in chat to print a debug snapshot:

[code]
[LibZoneTemp] Zone: City of Ash I
  Temperature : 50.0°C  (50.0°C / 122.0°F)
  Lore time   : 14:30
  Zone ID     : 176
  Swimming    : false
[/code]

[size=5][b]Settings Panel[/b][/size]

Access via [b]/libzonetemp[/b] or [b]Settings → Addons → LibZoneTemp Settings[/b]:

[list]
[*][b]Display in Fahrenheit[/b] — toggle between °C and °F display
[*][b]Zone Temperature Overrides[/b] — pick any zone from a dropdown and set a custom base temperature (°C). Set to 0 or blank to revert to the library default.
[/list]

[size=5][b]Zone Coverage[/b][/size]

[size=4][b]Overland Zones[/b] (all factions + DLC/Chapter through Solstice and Season One)[/size]
All 40+ overland zones have explicit base temperatures, weather profiles, and water temperatures.

[size=4][b]Sub-Zones with Explicit Temperatures[/b][/size]
Over 200 named sub-zones now have their own entries, overriding parent-zone inheritance where the environment is meaningfully different. These fall into three categories:

[b]Fire / Lava / Volcanic[/b] — zones containing active lava rivers, Oblivion fire planes, volcanic vents, or draconic flame. Temperatures range from 30°C (warm underground ruins near volcanic activity) to 60°C (deep Deadlands and City of Ash II).

[b]Ice / Frozen / Arctic[/b] — zones buried in glaciers, located on polar islands, or containing permafrost and frost atronachs. Temperatures range from −16°C (Icereach) to −2°C (March of Sacrifices).

[b]Neutral[/b] — The Nowhere Vault is deliberately climate-neutral (it settles at 22°C indoors): the magic of the Vault protects the player from the elements.

[b]Underground / Dungeons[/b] — most inherit from their parent zone via the existing fallback, but dungeons with notable microclimates (geothermal heat, deep cold, enclosed Daedric environments) have their own entry.

[size=4][b]Fallback Behaviour[/b][/size]
Any zone not found in the tables falls back to DEFAULT_TEMP (20°C) for air and DEFAULT_WATER_TEMP (16°C) for water. Sub-zones will first try their specific zoneId, then fall back to their parentZoneId, before reaching the global default.

[size=5][b]Temperature Model[/b][/size]

[code]
finalTemp = baseTemp
          + interiorModifier (−3°C, reduced weather/time swing indoors)
          + timeOfDayModifier (−5 to +3°C based on lore hour)
          + weatherModifier (rain: up to −4°C; snow: up to −6°C)
[/code]

Water temperature bypasses all modifiers — it returns the zone's static water value directly.

[size=5][b]Design Notes[/b][/size]

[b]Why is data keyed directly by zoneId, and how was it verified?[/b]
zoneId is the stable, language-independent identifier and does [b]not[/b] change between API updates; it's zoneIndex that ZOS is not guaranteed to keep stable across updates (see the [url=https://wiki.esoui.com/Zones]ESOUI Zones wiki[/url]). The three climate tables are authored directly with the zoneId as the table key — there's no separate name-keyed source table and no load-time conversion step; what's in the file is what gets read at runtime, and LibZone is not called for this at all.

Hand-authoring ~700 rows of lore/climate data directly against opaque zoneId integers isn't realistically reviewable or spot-checkable against UESP, so each line carries a trailing comment with the zone's English name — that name is what got cross-checked, at authoring time, against a real data source: LibZone's own public-domain zoneId/name file ([url=https://github.com/Baertram/LibZone/blob/master/LibZone/LibZone_Data.lua]LibZone_Data.lua[/url], the "en" table, dated 2026-06-08 / API101050). The name in the comment is never read at runtime — only the zoneId key is — so it can't affect behavior; it only exists so a human (or a future re-verification pass against a newer LibZone data file) can confirm the zoneId is right.

Two names from the prior name-keyed version didn't resolve during that cross-check: "Morrowind" turned out to share Vvardenfell's own zoneId rather than being a separate zone, and was dropped as redundant; "Amenos" has no confirmed zoneId in that data source and is listed in a comment as pending rather than guessed at — it currently has no effect and falls back to DEFAULT_TEMP / DEFAULT_WATER_TEMP like any other unlisted zone, same as it would if it had simply been forgotten.

To re-verify or refresh this data against a newer game update: pull the current LibZone_Data.lua from the link above, take its "en" table, and cross-check each zoneId comment in this file against it the same way.

[b]Why static weather and not live weather?[/b] The ESO addon API does not expose a function to read the current client-side weather state. Weather is entirely client-side and visual only. LibZoneTemp therefore uses a static probability table derived from zone lore.

[b]Why not cover every delve?[/b] Most delves inherit cleanly from their parent overland zone. Only delves with a meaningfully different microclimate (volcanic heat, glacial cold, Daedric environment) receive their own entry. This keeps the table maintainable while covering all cases where inheritance would produce a wrong result.

[size=5][b]For Addon Authors[/b][/size]

[code]
-- Minimal usage: get the current zone temperature
local temp, zoneName, tempF, formatted = LibZoneTemp.GetCurrentTemperature()
if temp then
    d("Current temperature in " .. zoneName .. ": " .. formatted)
end

-- Check if the player is in a hot zone (e.g. for survival gameplay)
local zoneId = LibZoneTemp._currentZoneId
local base = LibZoneTemp.GetBaseTemperatureForZone(zoneId, false)
if base >= 40 then
    -- Apply heat exhaustion debuff
end
[/code]

[size=5][b]Disclaimer[/b][/size]

This Add-on is not created by, affiliated with, or sponsored by ZeniMax Media Inc. or its affiliates. The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.
