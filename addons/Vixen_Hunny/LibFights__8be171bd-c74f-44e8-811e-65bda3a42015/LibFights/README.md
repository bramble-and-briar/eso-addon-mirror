# LibFights

An Elder Scrolls Online library that collects fight data, reads your build and makes predictions. It works on PC/Mac and on console (PS5/Xbox).

**Nothing gets logged until `Start_Logging()` is called.** Before that call the library registers no combat events. `Stop_Logging()` ends the current fight and unregisters every event again. Lookups that only read data work at any time: ability info, set info, build reading, search, stat snapshots.

## Install

Copy the `LibFights` folder into `Documents/Elder Scrolls Online/live/AddOns/`.

Optional dependencies:
- **LibAddonMenu-2.0**: the in-game test panel on PC.
- **LibHarvensAddonSettings**: the gamepad-friendly panel, used by default on console.
- **LibSets**: fills in any sets the game's collection API doesn't list.

If neither menu library is installed, everything still works through the Lua API and slash commands.

> Check `## APIVersion` in `LibFights.addon` against your client with `/script d(GetAPIVersion())` and update it if it differs.

## Quick test in game

1. Open Settings → Addons → **LibFights** and press **Start_Logging()**. You can also type `/libfights start`.
2. Hit a target dummy. Dummies are the calibration target for the resistance model.
3. Press **Refresh** or **Print everything**, or use `/libfights all`.
4. Use **Show predictions** for the model output, and the **Search**, **Ability id or name** and **Set id or name** boxes for lookups.

## Documentation and examples

- **[API Reference](API%20Reference.md)**: the full API reference in Markdown. Every function, what it returns (including the `false`/`nil` cases), every data structure, a quick start and 13 add-on examples.
- **[API.html](API.html)**: the same reference as a searchable page with Copy buttons on the examples. Open it in any browser.
- **[API.txt](API.txt)**: the same reference as plain text.
- **[LibFights-Examples](../LibFights-Examples/README.md)**: the 13 examples as ready-to-install add-on folders, one per example. The folder sits next to `LibFights`, not inside it: ESO loads add-ons nested up to three folders deep, so examples inside LibFights would run for everyone who installs the library.

[Add-on examples](API%20Reference.md#add-on-examples):

| Example | What it does |
|---|---|
| [Auto-logger](API%20Reference.md#auto-logger) | Starts logging in combat, prints the fight summary, stops again. Includes the manifest. |
| [Live DPS meter](API%20Reference.md#live-dps-meter) | Movable window with live DPS, HPS and SPS. |
| [Personal bests](API%20Reference.md#personal-bests) | Saves your best DPS per boss in SavedVariables. |
| [Top abilities with icons](API%20Reference.md#top-abilities-with-icons) | `/topdmg` and `/topheal`: top 5 abilities with icons, share and crit rate. |
| [Set and proc report](API%20Reference.md#set-and-proc-report) | Each set's damage share, uptime, procs per minute and proc cooldowns. |
| [Tank and shield report](API%20Reference.md#tank-and-shield-report) | Damage taken, mitigated and shielded, shield use, damage reduction, top attackers. |
| [Penetration check](API%20Reference.md#penetration-check) | `/pencheck`: target resistance and the penetration you're missing. |
| [Death recap](API%20Reference.md#death-recap) | The last 5 hits before you died. |
| [Build reader and change alert](API%20Reference.md#build-reader-and-change-alert) | `/mybuild`, plus what changed in your build between fights. |
| [Boss kill timer](API%20Reference.md#boss-kill-timer) | Warns when the boss has under 10 seconds left. |
| [Settings panel](API%20Reference.md#settings-panel) | LibAddonMenu on PC, LibHarvensAddonSettings on console. |
| [Search command](API%20Reference.md#search-command) | `/lfs`: search abilities, sets and fights. |
| [Big crit counter](API%20Reference.md#big-crit-counter) | Counts your crits over 20k with the event query. |

Slash commands only work on PC. On console, start and stop logging from a settings page like the Settings panel example.

## Files (one module per job)

| File | Responsibility |
|---|---|
| `Core.lua` | Namespace, platform detection, callbacks, printing |
| `Util.lua` | Formatting, safe API calls, ring buffer, table tools |
| `Constants.lua` | Action results, damage/unit/power types, equip slots, stats, game formulas |
| `Abilities.lua` | Ability info, icons, ID index, ID scanner, player skills, ability search |
| `Sets.lua` | Every set, set info/bonuses, equipped sets, set logging, set↔proc links |
| `Stats.lua` | Stat snapshots, derived stats, per-fight stat tracking |
| `Build.lua` | Build reader: character, gear, sets, bars, CP, mundus, buffs; build compare |
| `Models.lua` | Online ML models: resistance / DR / crit / incoming DR / TTK / DPS forecast |
| `Fight.lua` | Fight object, aggregation and all metrics |
| `Procs.lua` | Proc detection and tracking |
| `Logger.lua` | **Only** place events are registered; `Start_Logging` / `Stop_Logging` |
| `Search.lua` | Unified search, raw event queries, query builder, fight queries |
| `Storage.lua` | Settings defaults, SavedVariables, saved fights |
| `Report.lua` | Text output with icons, export line |
| `HUD.lua` | Optional live fight rundown window (tiles, boss/TTK, top abilities, fight log) |
| `Settings.lua` | LibAddonMenu / LibHarvensAddonSettings test panel |
| `Slash.lua` | `/libfights` commands |
| `Init.lua` | Loads saved data and builds the UI (does not start logging) |

## API

This is a short overview. The complete reference is **[API Reference.md](API%20Reference.md)**.

### Logging
```lua
Start_Logging(options?)   -- true | false, reason
Stop_Logging()            -- true, lastFight | false, reason
Is_Logging()
LibFights.SplitFight()             -- end current fight, start a new one
LibFights.Logger.EndCurrentFight()
LibFights.Logger.GetRegisteredEvents()
```
`options` overrides settings for that session only, for example `Start_Logging({ groupMode = true, rawEvents = false })`.
Keys: `rawEvents, rawEventCap, groupMode, trackTargetEffects, trackPower, trackCasts, statSampleMs, combatEndGraceMs, fightTimeoutMs, minFightSeconds, modelsEnabled, saveFights, buildDetail`.

### Reading fights
```lua
local f = LibFights.GetCurrentFight()   -- running fight or nil
local f = LibFights.GetLastFight()      -- running or most recent
LibFights.GetFights()                   -- in memory (this session)
LibFights.GetFight(id)                  -- memory, then SavedVariables
LibFights.GetSavedFights()

f:GetSummary()          -- every metric in one table (below)
f:GetDPS(active?) f:GetDPM() f:GetBossDPS()
f:GetHPS() f:GetHPM() f:GetRawHPS()
f:GetDTPS() f:GetDTPM() f:GetHTPS() f:GetHTPM()
f:GetMPS() f:GetMPM() f:GetTotalMitigated()
f:GetSPS() f:GetSPM() f:GetTotalShield()            -- shield absorbed on you
f:GetShieldGainedPS() f:GetShieldGainedPM() f:GetTotalShieldGained()  -- shield applied to you
f:GetGroupSPS() f:GetGroupSPM() f:GetGroupShieldTotal()  -- group mode: shields on other members
f.totals                -- raw totals
f:GetAbilityBreakdown(kind, sortBy, limit)  -- kind: damageOut|healOut|damageIn|healIn|shieldIn|shieldOut
f:GetTargets() f:GetSources() f:GetDamageTypes(incoming?)
f:GetTimeline(field)    -- per-second array; field: dOut|hOut|dIn|hIn|mit|oh|sIn|sGain
f:GetRollingRate(field, windowSec)
f:GetEffectUptimes("player"|"target", onlyMine?)
f:GetProcs() f:GetSets() f:GetCasts() f:GetPower(type?) f:GetDeaths()
f:GetBuild() f:GetStats() f:GetGroup()
f:GetEvents() f:DecodeEvent(ev) f:GetEventCount()
f:ToData(includeEvents)  /  LibFights.Fight.FromData(data)
```
`GetSummary()` fields include: `damage dps dpm activeDPS bossDamage bossDPS damageShielded dotShare overkill healing hps hpm rawHealing rawHPS overhealPct selfHealing damageTaken dtps dtpm healingTaken htps htpm mitigated mps mpm mitigatedShield mitigatedBlockEst mitigatedArmorEst mitigatedAvoidEst mitigationPct shield sps spm shieldHits shieldPctOfIncoming shieldGained shieldGainedPS shieldGainedPM shieldApplications shieldPeak shieldExpired shieldEfficiency groupShield groupSPS groupSPM hits crits critRate ticks avgHit maxHit maxHitAbility healCritRate maxHeal incomingCritRate blockedHits dodges misses immune casts skillCasts lightAttacks heavyAttacks ultimates apm skillsPerMinute weaves weaveRatio avgSkillGapMs barSwaps frontBarPct backBarPct killingBlows deaths interruptsOut interruptsIn ccOut ccIn powerGained procActivations numTargets numAbilities`.

Each ability row has `id name icon graphic damageType total pct dps dpm hits crits critRate avg avgNormal avgCrit min max ticks tickTotal directHits directTotal overflow results`.

**Mitigation:** shield absorption is exact. Block, armor and avoidance numbers are estimates: block uses the `blockMitigation` setting, armor uses your resistances (660 = 1%, 50% cap), and avoidance uses the average hit of the same enemy ability.

**Shields:** SPS / SPM / total count damage absorbed by shields on you, taken exactly from `ACTION_RESULT_DAMAGE_SHIELDED`. "Shield gained" comes from the game's shield bar on you (`EVENT_UNIT_ATTRIBUTE_VISUAL_*`), so it also counts shield that ran out unused (`shieldExpired`). In group mode, shields on other members are tracked per member. The game reports a shield hit with the attacker as the source, so shields you put on other players can't be credited to you.

### Abilities and IDs
```lua
LibFights.Abilities.GetInfo(id)        -- name icon iconMarkup description durationMs castTimeMs channelTimeMs
                                       -- isChanneled minRange maxRange radius cost costMechanic isPassive ...
LibFights.Abilities.GetName(id) / GetIcon(id) / GetIconMarkup(id, size) / Exists(id)
LibFights.Abilities.Search("name or id", max)
LibFights.Abilities.GetPlayerSkillAbilities(includeUnpurchased)
LibFights.Abilities.IndexPlayerSkills()
LibFights.Abilities.StartScan({ fromId, toId, perFrame, onProgress, onDone })  -- index every ability id
LibFights.Abilities.StopScan() / IsScanRunning() / GetScanProgress() / GetKnownAbilityIds()
```

### Sets
```lua
LibFights.Sets.GetAllSetIds()           -- every set id in the game
LibFights.Sets.GetSetInfo(setId)        -- name, type, maxEquipped, bonuses{numRequired, description, isPerfected}
LibFights.Sets.Search("name or id")
LibFights.Sets.GetEquippedSets()        -- equipped / perfected counts, active & inactive bonuses, slots
LibFights.Sets.SetLogAllSets(bool) / SetSetLogged(setId, bool) / IsSetLogged(setId) / GetLoggedSetIds()
LibFights.Sets.RegisterSetAbility(setId, abilityId)   -- link a proc id to a set (saved)
LibFights.Sets.GetSetForAbility(abilityId, name?)
```
In a fight, `f.sets[setId]` holds `damage healing hits activations activationsPerMinute uptimeMs uptimePct damageSharePct healingSharePct equipped maxEquipped fullBonus activeBonuses abilityIds`.

### Procs
Damage, healing and effects that don't come from your slotted skills are tracked as procs. Each one is linked to a set when the registry or a name match allows. A proc entry has `activations hits damage healing perMinute avgGapMs minGapMs estimatedCooldownMs uptimePct setId setName kind (set|candidate) external times`.

### Build
```lua
local b = LibFights.Build.Read("basic" | "full")
-- b.character, b.attributes, b.stats, b.gear[slot], b.armorCounts, b.sets, b.bars.front/back[slot],
-- b.champion.slotted, b.mundus, b.buffs, b.longBuffs, b.skills (full), b.signature
LibFights.Build.Compare(oldBuild, newBuild)
```
Each fight stores the build it started with in `f.build`.

### Stats
```lua
LibFights.Stats.GetSnapshot()   -- every GetPlayerStat + current/max resources + crit % + resist %
LibFights.Stats.GetStat(key) / GetArmorMitigation(damageType) / GetPenetrationFor(damageType)
LibFights.Stats.GetValuesAt(fight, ms)
```
In a fight, `f.stats` holds `start end min max avg samples` (samples record changes only).

### Models (predictions)
```lua
LibFights.Models.GetReport()
LibFights.Models.GetTargetEstimate("Target Name")
  -- predictedResistance(+Std), predictedDRPct, missingPenetration, relativeDamageTaken, status, samples
LibFights.Models.GetIncomingDR()        -- armorMitigationPct, otherDRPct, totalDRPct
LibFights.Models.GetCritEstimate(abilityId?)  -- critChance(+Std), critDamagePct
LibFights.Models.PredictHit(abilityId, targetName?)  -- nonCrit, crit, average, rmse
LibFights.Models.PredictIncomingHit(abilityId, damageType)
LibFights.Models.GetTTK("boss1")        -- seconds remaining, health fraction
LibFights.Models.GetDPSForecast(seconds)
LibFights.Models.PredictFightOutcome(fight)
LibFights.Models.Reset()
```
How the models work:
- **Per-ability regression (RLS).** Each ability's non-crit hits are fit against your max resources and weapon/spell damage.
- **Resistance and DR.** A reference model is trained only on dummies, which have 18,200 resistance (both are configurable). Comparing hits on other targets with that reference gives their mitigation and resistance. The estimates are smoothed with a Kalman filter.
- **Relative toughness.** Before any dummy data exists, targets are compared with the average target instead.
- **Crit.** Crit chance uses a Beta posterior. Crit damage is the ratio of the mean crit to the mean non-crit for the same ability.
- **Your incoming DR.** This is armor mitigation from your stats plus "other DR", measured against the least-mitigated hit seen from each enemy ability.
- **TTK.** Boss health over time is fit with a time-weighted linear regression.
- **DPS forecast.** Holt smoothing.

These are statistical estimates. Damage-taken debuffs such as Vulnerability show up as lower DR. Each estimate reports its sample count and spread so you can judge how much to trust it.

### Search
```lua
LibFights.Search("query", { limit = 50, fight = f })
--  free text + filters:  in:ability in:set in:fight in:effect in:proc in:target in:stat in:cast in:event
--                        id:12345   fight:7
LibFights.FindEvents(fight, { direction="out", category="damage", abilityId=..., abilityName=..., source=..., target=...,
                              result=..., damageType=..., crit=true, minHit=..., maxHit=..., fromMs=..., toMs=..., limit=..., newestFirst=true })
LibFights.NewQuery(f):Direction("out"):Category("damage"):Crit(true):MinHit(10000):Limit(20):Run()   -- also :Count() :Sum() :Max()
LibFights.QueryFights({ zone=..., title=..., target=..., character=..., minDurationSec=..., minDPS=..., minSPS=..., sinceTimestamp=... })
```
Each raw event is a compact array. Read it with the indexes in `LibFights.EVENT_FIELDS` (`TIME DIR RESULT ABILITY HIT OVERFLOW SOURCE TARGET DAMAGE_TYPE POWER_TYPE SLOT_TYPE`) or call `f:DecodeEvent(ev)`.

### Callbacks
```lua
LibFights.RegisterCallback(LibFights.EVENTS.FIGHT_ENDED, function(fight, reason) ... end)
```
`INITIALIZED LOGGING_STARTED LOGGING_STOPPED FIGHT_STARTED FIGHT_ENDED COMBAT_EVENT EFFECT_CHANGED PROC DEATH CAST BAR_SWAP STATS_SAMPLE GEAR_CHANGED SCAN_PROGRESS SCAN_DONE`

### Text output
`LibFights.Report.*Lines(...)` return arrays of chat-ready lines with icons, and `LibFights.Report.Export(f)` returns a single-line export.

## Slash commands (PC)
`/libfights start | stop | split | status | last | all | abilities | heals | taken | targets | procs | sets | buffs | debuffs | stats | power | build | models | export | hud | scan | search <q> | ability <id|name> | set <id|name>`

## Console notes
- `IsConsoleUI()` is detected automatically.
- The panel uses LibHarvensAddonSettings when it is installed and falls back to LibAddonMenu.
- The UI is built entirely in Lua (no XML) and the HUD is added to the HUD scenes, so it works with the gamepad UI.
- Console defaults are smaller because console SavedVariables have a tighter size budget: 5,000 raw events per fight, 3 saved fights, and raw events are never saved.
- The ability-ID scan runs fewer IDs per frame on console.
