[size=6][b]Realistic Needs and Diseases[/b][/size]
[i]by @Kreksar5 and Claude.ai[/i] · License: MIT

Thematically inspired by [i]Realistic Needs and Diseases[/i], the well-known Skyrim mod — name and concept used as an homage, [b]not a port, and not affiliated with or endorsed by that mod's authors.[/b]

[color=orange][b]AI-ASSISTED ADDON.[/b][/color] Built with Claude.ai. This addon has been reviewed and tested in-game by the author for functionality. A small number of specific mechanics are still individually flagged in "Known Gaps" below where the underlying game data/behavior hasn't been independently re-confirmed since — those notes are narrower caveats about specific details, not a blanket disclaimer about the addon as a whole.

A from-scratch survival-needs and disease addon for ESO: hunger, thirst, and fatigue meters that decay naturally over time, accelerated (never slowed) by environmental temperature, plus 5 independently-trackable diseases cured by specific alchemy ingredients rather than potions.

This is an original implementation — not a patch or derivative of RolePlayNeeds (or anything else).

For the full version history, see the Change Log tab, or CHANGELOG.md included in the download.

[size=5][b]Dependencies[/b][/size]

Please install the newest available version of each:

[list]
[*][url=https://www.esoui.com/downloads/info7-LibAddonMenu.html][b]LibAddonMenu-2.0[/b][/url] — [b]Required.[/b] Settings panel.
[*][url=https://www.esoui.com/downloads/info1902-LibFoodDrinkBuff.html][b]LibFoodDrinkBuff[/b][/url] — [b]Required.[/b] Confirms food/drink consumption via its IsAbilityAFoodOrDrinkBuff(abilityId) method, used as a consumption-confirmation gate.
[*][url=https://www.esoui.com/downloads/info4710-Frostfall.html][b]Frostfall[/b][/url] — Optional. Preferred source for effective temperature (Frostfall:GetEffectiveTemp()).
[*][url=https://www.esoui.com/downloads/info4708-LibZoneTemp.html][b]LibZoneTemp[/b][/url] — Optional. Fallback temperature source if Frostfall isn't installed.
[/list]

[size=5][b]Credits[/b][/size]

[list]
[*][b]RolePlayNeeds — Tamriel Survival![/b] (the ESOUI addon) by [b]matheusbk2[/b]: two implementation details were confirmed by inspecting its actual published source (checked directly against the official v0.7 BETA release) — the bindings.xml/keybind naming convention (RPN_CHECK_NEEDS action name, RPN_CheckNeeds() handler — mirrored here as RND_CHECK_NEEDS / RealisticNeeds.CheckNeeds()), and the inventory-seed-on-login fix for reliable first-consumption detection (ForceInventoryScan() called from EVENT_PLAYER_ACTIVATED, seeding a lastInventoryState table before any inventory event can fire — this addon's equivalent is SeedLastSlotState()). No code was copied; this addon is an original implementation, not a port or derivative.
[*][b]No Interact[/b] by [b]Rhyono[/b]: the world-object "Sit" interaction detection (RETICLE:TryHandlingInteraction hook and the INTERACTIVE_WHEEL_MANAGER / formerly FISHING_MANAGER reassignment technique for catching interact keypresses) follows the same technique this addon uses to read reticle state and intercept interactions. No code was copied.
[/list]

[size=4][b]Overlay art credit[/b][/size]
The disease status-overlay images (Frostbite.dds, Heatstroke.dds, MagesBane.dds, FightersBane.dds, ThiefsBane.dds) were generated using AI text-to-image tools — [url=https://perchance.org/ai-text-to-image-generator]Perchance AI Text-to-Image Generator[/url] and Google's Gemini Image Creator — and edited/converted to the game's .dds format using Paint.NET. They are not hand-drawn or sourced from ESO's own art assets.

[size=4][b]Status icon art credit[/b][/size]
The status display icons (textures/icons/ — Hunger.dds, Thirst.dds, Fatigue.dds, Drunkenness.dds, Frostbite.dds, Heatstroke.dds, MagesBane.dds, FightersBane.dds, ThiefsBane.dds) were generated using AI image tools, including [url=https://perchance.org/ai-icon-generator]Perchance AI Icon Generator[/url], and converted to the game's .dds format. They are not hand-drawn or sourced from ESO's own art assets.

[size=5][b]Needs[/b][/size]

[list]
[*][b]Hunger[/b], [b]Thirst[/b], [b]Fatigue[/b], each 0–100. All decay/restore rates and warning thresholds are player-adjustable in Settings.
[*][b]Decay is always-on at a natural baseline rate[/b] (default: hunger empties in 4h, thirst in 3h, fatigue in 6h — all adjustable). Temperature never reduces decay below that baseline, it only ever accelerates it on top. Inside the comfort band (10°C–25°C), you get pure baseline decay. Outside it, the relevant meter(s) drain up to 2–2.5x faster.
[*]Hot environments → thirst accelerates. Cold environments → hunger and fatigue accelerate.
[*]Eating restores hunger (default +30, adjustable), drinking restores thirst (default +30, adjustable).
[*][b]Harvesting an alchemy water node in the wild also restores thirst directly[/b] (default +15, adjustable) via EVENT_LOOT_RECEIVED.
[*]Temperature source: Frostfall:GetEffectiveTemp() preferred, LibZoneTemp.GetCurrentTemperature() fallback, flat baseline otherwise.
[/list]

[size=4][b]How fatigue works (and how to recover)[/b][/size]

Fatigue decays on a flat time-based baseline like hunger and thirst, then gets accelerated by two independent factors — temperature and stamina exertion:

[list=1]
[*][b]Time-based baseline drain.[/b] Fatigue ticks down at a flat natural rate (default: empties over 6 hours of played time) every 5-second tick, identical in mechanism to hunger and thirst — only the rate differs.
[*][b]Temperature-accelerated, in both directions.[/b] Unlike hunger (cold-only) and thirst (hot-only), fatigue accelerates at [b]either[/b] temperature extreme — too cold or too hot tires you out faster, up to 2x the baseline rate, ramping over the same 20°C-beyond-comfort-band range as the other two meters.
[*][b]Stamina-exertion accelerated.[/b] Fatigue also drains faster the more stamina you spend (sprinting, attacking, blocking, dodging) — tracked via EVENT_POWER_UPDATE over each 5-second tick window, up to a separate multiplier on top of the temperature one. See Known Gaps below — this mechanic's parameter order and tuning constants aren't independently re-confirmed against a live client.
[*][b]Recovery[/b] — three mechanics, all gated on not moving and being out of combat: standing still for a few minutes (slow regen), sitting for about a minute (faster regen), or sleeping/meditating for a while (full restore). See "Fatigue Recovery" below.
[/list]

[size=5][b]Diseases[/b][/size]

5 independent diseases — any subset active simultaneously, each at its own severity tier (Mild / Moderate / Severe). Contraction chances are all player-adjustable in Settings.

[list]
[*][b]Frostbite[/b] — Sustained cold exposure (5 min) — cure trait: Protection — tint: Pale blue
[*][b]Heatstroke[/b] — Sustained hot exposure (5 min) — cure trait: Protection — tint: Warm orange
[*][b]Mage's Bane[/b] — Taking Magic/Fire/Cold/Shock damage (chance per hit) — cure trait: Restore Magicka — tint: Purple
[*][b]Fighter's Bane[/b] — Taking Physical damage (chance per hit) — cure trait: Restore Health — tint: Bruised red
[*][b]Thief's Bane[/b] — Taking Poison/Disease damage (chance per hit) — cure trait: Restore Stamina — tint: Sickly yellow-green
[/list]

[size=4][b]Two trigger mechanisms[/b][/size]

[b]Frostbite and Heatstroke[/b] use sustained exposure: once the player's effective temperature (Frostfall-preferred, LibZoneTemp-fallback) has sat outside the comfort band continuously for 5 minutes, the disease becomes possible and re-rolls every 60 seconds for as long as the exposure continues, until contracted or the player leaves the trigger range. Settings caps these 0–50% per roll.

[b]Mage's Bane, Fighter's Bane, and Thief's Bane[/b] are each rolled on a qualifying hit of real typed combat damage instead — no exposure timer. The game's own damage-type classification for the hit is checked against a lookup table (Magic/Fire/Cold/Shock → Mage's Bane, Physical → Fighter's Bane, Poison/Disease → Thief's Bane), not a name-keyword guess. Since combat damage can land far more often than the exposure re-roll interval, Settings caps these much lower: 0–10% per hit, in 0.5% steps.

[size=4][b]Curing: real ingredients, sourced from UESP[/b][/size]

Each disease is cured by raw alchemy [b]ingredients[/b] (never potions), and each disease has its own distinct trait with 3 tiers of real, UESP-verified ingredients (common → rare):

[list]
[*][b]Frostbite[/b] (Protection) — Mudcrab Chitin → Beetle Scuttle → Vile Coagulant or Powdered Mother of Pearl
[*][b]Heatstroke[/b] (Protection) — Mudcrab Chitin → Beetle Scuttle → Vile Coagulant or Powdered Mother of Pearl
[*][b]Mage's Bane[/b] (Restore Magicka) — Corn Flower → Lady's Smock → Vile Coagulant (Harrowstorms)
[*][b]Fighter's Bane[/b] (Restore Health) — Mountain Flower → Water Hyacinth → Crimson Nirnroot (Blackreach)
[*][b]Thief's Bane[/b] (Restore Stamina) — Blessed Thistle → Chaurus Egg → Dragon's Blood (Dragons)
[/list]

A tier-N ingredient cures that disease at severity ≤ N (a rare ingredient can overkill-cure a mild case; a common one can't touch a severe case). Every itemId has been filled in from an in-game scan, except Thief's Bane's tier-3 Dragon's Blood, which is still a UESP-sourced placeholder pending confirmation from a real scan.

[size=4][b]Care-cure: an alternative path for stronger afflictions[/b][/size]

Instead of needing the rare tier-matched ingredient outright, a Severe or Moderate case can also be cured gradually: eating the disease's tier-1 (cheapest) ingredient repeatedly while hunger, thirst, AND fatigue are all above a threshold (default 70/100, adjustable) builds "care-cure progress." Once enough doses accumulate (default 5, adjustable), the disease downgrades one severity tier — Severe → Moderate → Mild → cured — resetting progress each step. Check progress anytime with [b]/rnd checkneeds[/b].

[size=5][b]Status Window[/b][/size]

A Frostfall-style colored-text window — a draggable top-level window with a tooltip-style backdrop, four label+value+status rows (HUNGER/THIRST/FATIGUE/DRUNKENNESS), each showing a large number colored on a red→yellow→green ramp, plus the current band status message text (e.g. "I'm hungry.") underneath each number, colored the same as the number. A DISEASES section below lists each active disease's name, severity, and a text color matching that disease's overlay tint.

[list]
[*]Drunkenness's color ramp is inverted (high = red/bad, low = green/good) — the only row where that's the case.
[*]Drag the window anywhere — position persists across sessions, with a "Reset status window position" button in Settings if it ever ends up off-screen.
[*]Toggle the whole window on/off via the "Show needs status window" checkbox in Settings.
[*]The window resizes dynamically to fit however many diseases are currently active (0 to 5).
[/list]

[size=5][b]Settings Panel[/b][/size]

Everything below is adjustable without editing code:

[list]
[*]Temperature-coupling on/off, hours-to-empty for each meter, restore amounts for food/drink/harvest/coffee, warning thresholds, status bar visibility.
[*]Contraction chance per disease (the three combat-damage diseases — Mage's Bane, Fighter's Bane, Thief's Bane — capped lower than Frostbite/Heatstroke, reflecting how much more often a hit can land than an exposure re-roll).
[*]Care-cure "well cared for" threshold and doses-required.
[*]Per-category emote choice (dropdown, real account-aware enumeration — see Feedback System below) and an overall emote enable/disable toggle.
[*]Drunkenness gain-per-drink, threshold, unaided sober-up time, and resting sober-up multiplier.
[*]Fatigue recovery thresholds for all three resting mechanics.
[/list]

Debug/reset actions live in [b]/rnd debug[/b] — see Slash Commands below.

[size=5][b]Slash Commands[/b][/size]

All commands are unified under [b]/rnd[/b].

[list]
[*][b]/rnd checkneeds[/b] — Prints current hunger/thirst/fatigue/drunkenness, active temperature source, and each active disease's severity plus care-cure progress.
[*][b]/rnd debug[/b] (no args) — Prints the full list of debug subcommands below.
[/list]

[size=4][b]/rnd debug subcommands[/b][/size]

[list]
[*][b]/rnd debug checkneeds[/b] — Prints exact numeric hunger/thirst/fatigue/drunkenness/disease values and care-cure progress to chat. For a quick glance without numbers, use the bare /checkneeds command or its keybind instead.
[*][b]/rnd debug disease <1-5> <0-3>[/b] — Directly sets a disease's severity for testing, bypassing normal contraction rolls entirely. Index: 1=Frostbite, 2=Heatstroke, 3=Mage's Bane, 4=Fighter's Bane, 5=Thief's Bane. Severity 0 clears it.
[*][b]/rnd debug frostbiteTimer[/b] — Prints how long until Frostbite's next contraction roll (or whether you're even currently exposed).
[*][b]/rnd debug heatstrokeTimer[/b] — Same as frostbiteTimer, for Heatstroke.
[*][b]/rnd debug curedisease[/b] — Clears every active disease. Does not touch needs.
[*][b]/rnd debug resetneeds[/b] — Resets hunger/thirst/fatigue/drunkenness to full/sober. Does not touch diseases.
[*][b]/rnd debug emptyNeeds[/b] — Inverse of resetneeds — drops hunger/thirst/fatigue to 0 and drunkenness to 100 (its worst value), for quickly testing the recovery mechanics without waiting for real decay. Does not touch diseases.
[/list]

None of the debug subcommands run on their own; every one is opt-in.

[size=5][b]Feedback System[/b][/size]

Both the notification mechanism and the emote system are built the same way Frostfall builds theirs, just with different thresholds/categories/values.

[size=4][b]Notifications — ZO_Alert[/b][/size]

Notifications use ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, text) — the same call Frostfall uses for its own hot/cold messages.

[size=4][b]Status bands — 4 fixed bands per category, dividing 0-100 equally[/b][/size]

Each of hunger/thirst/fatigue/drunkenness has its own 4-band status message system, with every band transition (worsening or improving) firing its own notification. Bands are fixed quartiles of the 0-100 range.

[list]
[*]Band 1 (best): "I'm stuffed!" / "My thirst is quenched!" / "I'm well rested!" / "I'm completely sober."
[*]Band 2: "I could use a snack." / "I'm a bit thirsty." / "I could use a break." / "I'm-*hic*-a bit tipsy."
[*]Band 3: "I'm hungry." / "I need a drink." / "I'm tired, I should find a place to sleep." / "I'm-*hic*-nah' drunk, you-*hic*-you're drunk!"
[*]Band 4 (worst): "I'm starving!" / "I'm dehydrated!" / "I'm exhausted! I might pass out soon!" / "WOOOOOO! I-*hic*-cannaht-*hic*-feel ma facsh!"
[/list]

Bands 1-2 = value 50-100 (or 0-50 for drunkenness); bands 3-4 = the bottom half of badness. [b]Emotes only play at bands 3 and 4[/b] — bands 1-2 update the status window and fire notifications, but never trigger an emote.

[size=4][b]Emotes — real PLAYER_EMOTE_MANAGER enumeration[/b][/size]

Uses the same real, confirmed mechanism Frostfall uses: PLAYER_EMOTE_MANAGER:GetEmoteListForType(category) / :GetEmoteItemInfo(emoteId) to enumerate every emote the player actually owns (including personality-overridden variants), FindEmoteIdByDisplayName to resolve a default by name with a slash-name fallback, and GetEmoteIndex(emoteId) → PlayEmoteByIndex(index) to actually play it.

A dedicated, deterministic 20-second timer checks each category's band and plays its configured emote once it reaches band 3 or 4, gated on IsUnitInCombat, IsMounted, and IsAnyMajorUIOpen.

[list]
[*][b]Hunger[/b] — default: Angry — "Throw your arms to the side and snarl" — no audio
[*][b]Thirst[/b] — default: Breathless — "Hunch over with your hands on your knees and pant" — no audio
[*][b]Fatigue[/b] — default: Yawn — "Stretch your arms and yawn" — has audio
[*][b]Disease[/b] — default: Sickened — "Heave over and vomit" — no audio
[*][b]Drunkenness[/b] — default: Drunk — "Teeter and reel in a drunken stupor" — no audio
[/list]

Hunger and thirst have no literal match in ESO's emote list — closest thematic analogues, flagged honestly. Fatigue, disease, and drunkenness all have genuine exact matches.

⚠️ If you'd previously played an earlier version, your saved hunger emote choice may still be the old default (Headache) — the new default (Angry) only applies automatically on a fresh save. Reselect it in Settings if you want the new default.

Events that notify (chat + ZO_Alert): every band transition for hunger/thirst/fatigue/drunkenness, disease contraction/escalation, both cure paths. Harvest-restores-thirst, alcohol, and coffee messages stay chat-only deliberately (frequent actions; an alert every time would be noisy).

[size=5][b]Drunkenness[/b][/size]

Drinking an alcoholic beverage (detected by name keyword — mead, ale, wine, rum, rotmeth, sujamma, etc.) builds up drunkenness (default +15/drink, adjustable). Unlike hunger/thirst/fatigue, [b]high drunkenness is the bad state[/b], not low.

[list]
[*]Decays on its own over time (default: fully sober in ~2 hours unaided).
[*][b]Resting accelerates sobering up[/b] (default 4x faster) — any of the three fatigue-recovery mechanics (standing still, sitting, sleeping) also reduces drunkenness while active.
[*]The status window's color ramp is inverted for this row specifically (high = red/bad, low = green/good) — everywhere else, high = good.
[/list]

[size=5][b]Coffee[/b][/size]

Drinking coffee (detected by name keyword: coffee, joe, espresso) restores fatigue (+25 default, adjustable) in addition to the normal thirst restore every drink already gives.

[size=5][b]Fatigue Recovery[/b][/size]

Three mechanics, all gated on not moving and being out of combat:

[list=1]
[*][b]Standing still[/b] for several minutes (default 3, adjustable) → slow passive regen.
[*][b]Sitting[/b] (any /sit variant, /sitchair, or interacting with a real in-world chair/bench) for about a minute (default 60s, adjustable) → faster regen than just standing.
[*][b]Sleeping/meditating[/b] for a while (default 60s, adjustable) → full restore.
[/list]

All three also accelerate drunkenness decay while active.

For mechanic 3: /sleep, /sleep2, and /faint are real sleep-pose emotes. ESO has no literal "/meditate" emote — /pray and /kneelpray are used as the closest thematic stand-ins.

Detection works by hooking the relevant slash commands (preserving their original behavior, then tracking state alongside). Sitting is also detected when the player interacts with a real in-world object whose reticle prompt reads "Sit" (a placeable chair, a bench, etc.), via INTERACTIVE_WHEEL_MANAGER.StartInteraction — independent of and in addition to the /sit-family slash-command hooking.

There is no RND-specific /rnd sit or /rnd sleep command — both were removed once native command hooking and world-interaction detection were confirmed reliable enough to cover sitting/sleeping on their own. Just sit or sleep normally; RND detects it.

Entering rest mode via sitting or sleeping prints a chat-only confirmation ("You take a seat to rest." / "You settle in to sleep.") regardless of which detection path triggered it. It only fires on the actual transition into that pose, not on every re-trigger while already seated/sleeping.

[size=5][b]Known Gaps[/b][/size]

[list]
[*][b]Dragon's Blood (Thief's Bane tier 3)[/b] is the only remaining unconfirmed ingredient itemId.
[*]Some of Mage's Bane's damage-type triggers (Fire/Cold/Shock) are believed-real but individually unconfirmed against a live client — resolved defensively (skipped with a chat warning, not a crash, if any turn out wrong).
[*]EVENT_POWER_UPDATE's parameter order (the stamina-exertion mechanic feeding fatigue decay) is unverified against a live client.
[*]The exertion-reference constant (300 stamina/tick for max multiplier) and the emote interval range (5-25s) are both first-draft tuning values, not extensively playtested for balance.
[*]"/pray" and "/kneelpray" are thematic stand-ins for "meditate," which has no real ESO emote.
[*]Alcohol and coffee detection are both name-keyword heuristics — will miss any drink whose name doesn't contain a listed keyword; expand RN.ALCOHOL_KEYWORDS / RN.COFFEE_KEYWORDS in Data.lua as needed.
[/list]
