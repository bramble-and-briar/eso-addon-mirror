-- DLC and chapter 4-player dungeons, in release order.
-- Group each dungeon under its DLC with opts.group; it is shown in the menu label.
-- Dungeon hard modes are final-boss only: put them on that boss's `extra.hardmode`.
-- Source: UESP dungeon pages. Lines marked VERIFY are lower-confidence.

local addDungeon = PullCardData.addDungeon
local addBoss = PullCardData.addBoss
local addShared = PullCardData.addShared

-- =============================================================================
-- Imperial City
-- =============================================================================

-- Imperial City Prison
addDungeon("Imperial City Prison", "dlc", { group = "Imperial City" })
addBoss("Overfiend", "Imperial City Prison", "Overfiend", {},
    "Daedric brute whose summons speed up as he loses health; a Harvester joins at 50%.",
    "Cleave the summons, interrupt Consuming Energy, and stay out of his flurry cone.",
    "Hold Overfiend and the Harvester together, facing away from the group.",
    "Add pressure ramps up late in the fight.",
    "AoE the summons; burn the Harvester fast with ultimates.",
    "[Overfiend] Cleave adds; interrupt; burn Harvester at 50%.")

addBoss("Ibomez the Flesh Sculptor", "Imperial City Prison", "Ibomez the Flesh Sculptor", {"Ibomez"},
    "Xivilai surgeon with an acid pool, flesh atronachs and the Tenderize execute.",
    "When someone is stunned by Tenderize, INTERRUPT his charged swing or they die. Stay out of the acid pool.",
    "Face Ibomez away; bash/interrupt the Tenderize swing if no one else does.",
    "The Tenderize target needs heals and an interrupt fast.",
    "Throw flesh grenades at inmates; kill atronachs at 75/50/25% before they enrage.",
    "[Ibomez] INTERRUPT Tenderize swing; kill atronachs; avoid acid pool.")

addBoss("Gravelight Sentry", "Imperial City Prison", "Gravelight Sentry", {"Sentry"},
    "Watcher on an island surrounded by poison water.",
    "Stay out of the water and behind the boss (gaze beams). Killing all three perimeter necromancers enrages it.",
    "Block the shockwave so nobody gets knocked into the water.",
    "Water and enrage stuns make rezzes hard; keep people alive.",
    "Interrupt necromancer channels; burn the boss before the enrage.",
    "[Gravelight] Avoid water/gaze; interrupt necros; don't trigger enrage early.")

addBoss("Flesh Abomination", "Imperial City Prison", "Flesh Abomination", {"Abomination"},
    "Flesh colossus with hoarvor adds, poison wells and a hoarvor explosion phase.",
    "Kill hoarvors fast. On the slam, hug the walls away from the exploding hoarvors' red circles.",
    "Block Poison Well; don't let the cleave hit the group.",
    "Heavy poison ticks during the explosion phase.",
    "Swap to hoarvors whenever they spawn.",
    "[Abomination] Kill hoarvors; wall-hug on slam; avoid poison rings.")

addShared({"Lord-Warden's Council", "Lord-Warden's Templar", "Lord-Warden's Necromancer", "Lord-Warden's Knight"},
    "Imperial City Prison", "Lord-Warden's Council", {"Council"},
    "Four-Xivkyn council; each one that dies leaves an untargetable shade.",
    "Interrupt the Templar's heals. Damage stops while the Necromancer's totems make them immune.",
    "Group the council; pull them off the Knight's standard.",
    "Steady group damage while several are alive.",
    "Interrupt heals; burst between totem phases.",
    "[Council] Interrupt heals; burst between immunity totems.")
-- VERIFY: council member NPC names as shown on the boss bar.

addBoss("Lord Warden Dusk", "Imperial City Prison", "Lord Warden Dusk", {"Lord Warden", "Dusk"},
    "Final boss with shadow orbs, portals and the lethal Darklight Burst.",
    "When he casts Darklight Burst, EVERYONE drops through a portal and uses Brace for Impact (max 2 per portal). Don't waste portals. Block the meteor in the shade phase.",
    "Hold him away from portals; stay with the group during the shade phase.",
    "Tethers and shades put steady pressure on the group.",
    "On Veteran only 2 shades are damageable at a time; burn them, then the boss.",
    "[Dusk] Darklight Burst = portal + Brace (2 per portal); block meteor.",
    {
        hardmode = "Destroy the Warden's Tome before the fight. Dusk hits much harder: portal timing has to be clean.",
        challenges = {
            { name = "Lord Warden's Retaliation", text = "Defeat Lord Warden Dusk on Veteran Hard Mode." },
        },
    })

-- White-Gold Tower
addDungeon("White-Gold Tower", "dlc", { group = "Imperial City" })
addBoss("The Adjudicator", "White-Gold Tower", "The Adjudicator", {"Adjudicator"},
    "Harvester whose killed adds power pillars that shoot the group.",
    "Avoid ground AoE. Coldharbour Justice cages the farthest player in fire; they lockpick out.",
    "Keep the boss steady; group the noble adds.",
    "Pillar bolts ramp up the longer the fight goes.",
    "Burn the boss; don't stall on adds.",
    "[Adjudicator] Avoid AoE; lockpick out of cage; don't stall.")

addShared({"Cordius Pontifio", "Micella Carlinus", "Otho Numida"},
    "White-Gold Tower", "The Elite Guard", {"Elite Guard"},
    "Three-person guard: Micella (tank), Cordius (damage), Otho (healer).",
    "Kill order: Micella, Cordius, Otho. Interrupt Otho's heal channel; avoid fire lines.",
    "Pull Micella away from the other two to break her empower buff.",
    "Cordius's AoEs and fire lines stack up.",
    "Micella first, then Cordius, then Otho; interrupt heals.",
    "[Elite Guard] Kill Micella > Cordius > Otho; interrupt Otho.")

addBoss("The Planar Inhibitor", "White-Gold Tower", "The Planar Inhibitor", {"Planar Inhibitor", "Inhibitor"},
    "Taunt-immune cold-flame atronach; a DPS race with portals and dive attacks.",
    "Get out of Magma Diver red circles. Players marked with Moth Vision destroy the portals.",
    "Atronach can't be taunted: interact with the pinion to hold its attention.",
    "Stacking Heat Stroke on the pinion player; big group hits after blue flames.",
    "Burst during Omega Burnout (boss stunned, vulnerable).",
    "[Inhibitor] Avoid dives; Moth Vision kills portals; burst in Burnout.")
-- VERIFY: pinion / Moth Vision details.

addBoss("Molag Kena", "White-Gold Tower", "Molag Kena", {"Kena"},
    "Final mage with a rotating lightning wall and edge-of-tower death zone.",
    "Never touch the Storm Wall or the cold-fire edge (instant death). Block knockbacks. Get out of the circle when Lightning Aspects die. Kill the storm atronach fast.",
    "Keep her near the center (not in the wall); block Storm Surge.",
    "Knockbacks get stronger each Aspect phase; watch people near edges.",
    "Kill aspects at 66/33% then step out; two walls from 20%.",
    "[Kena] Avoid wall + edge; block knockback; out when aspects die.",
    {
        hardmode = "Read the Obelisk Tome before the fight. Kena hits much harder; knockbacks into the edge become the main killer.",
        challenges = {
            { name = "Ire of the Storm", text = "Defeat Molag Kena on Veteran Hard Mode." },
        },
    })

-- =============================================================================
-- Shadows of the Hist
-- =============================================================================

-- Cradle of Shadows
addDungeon("Cradle of Shadows", "dlc", { group = "Shadows of the Hist" })
addBoss("Sithera", "Cradle of Shadows", "Sithera", {},
    "Spider daedra fought around braziers.",
    "Stay in brazier light: darkness hurts and she takes little damage there. At 66/33% she snuffs braziers; move to a lit one.",
    "Keep Sithera inside the light.",
    "Darkness damage builds fast on anyone outside.",
    "Kill spider adds; damage only in the light.",
    "[Sithera] Stay in the light; move when braziers go out.")

addBoss("Khephidaen", "Cradle of Shadows", "Khephidaen", {},
    "Spiderkith mage who puts out braziers and summons wraiths.",
    "Relight braziers (synergy) to stop beetle spawns. Dodge Voice of the Spinner's big red circle and its waves. Interrupt her teleport cast.",
    "Face her away and block Tide of Darkness.",
    "Beetles and darkness stack damage if braziers stay out.",
    "Slot an interrupt; kill wraiths.",
    "[Khephidaen] Relight braziers; dodge big red circle; interrupt teleport.")

addBoss("Votary of Velidreth", "Cradle of Shadows", "Votary of Velidreth", {"Votary"},
    "Giant spider with broodlings and a pull-in burst.",
    "Spread for venom pools. When Webspinner's Wrath pulls everyone in, dodge-roll OUT immediately.",
    "Keep the boss away from the pools.",
    "Watch the pull-in burst.",
    "Kill broodlings immediately.",
    "[Votary] Spread venom; roll out after the pull-in.")

addBoss("Dranos Velador", "Cradle of Shadows", "Dranos Velador", {"Dranos"},
    "Dunmer assassin with shade phases at 66/33%.",
    "Kill the four shades and grab all essences to stun him. Interrupt Gloom Wraiths. DODGE Blade Weaver (blocking still hurts). Late fight, hug the room edges.",
    "Pull the shades onto Dranos to skip the phase faster.",
    "Orb explosions and Blade Weaver spike the group.",
    "Kill shades fast; interrupt wraiths.",
    "[Dranos] Kill 4 shades, collect essence; dodge Blade Weaver.",
    {
        challenges = {
            { text = "Kill Dranos without killing any of the Shades." },
        },
    })

addBoss("Velidreth", "Cradle of Shadows", "Velidreth", {},
    "Final boss: steals ultimate, splits the group into a dark maze, and Shadow Sense spikes.",
    "Shadow Sense: stand still on your white circle, then dodge out of the red ones. In the maze, get back to the arena fast; use atronach light to see.",
    "Hold Velidreth; stop rez interrupts from catching the group.",
    "Big burst after AoE phases; colored balls drain resources.",
    "Don't sit on full ultimate; she pulls and eats it.",
    "[Velidreth] Shadow Sense: stand, then roll; get out of the maze fast.",
    {
        hardmode = "Burn the webs on the Altar of Adoration. +600k health, the idol rains AoEs all fight, and three of four catacomb exits are closed.",
    })

-- Ruins of Mazzatun
addDungeon("Ruins of Mazzatun", "dlc", { group = "Shadows of the Hist" })
addBoss("Zatzu", "Ruins of Mazzatun", "Zatzu", {},
    "Miniboss who throws boulders at everyone.",
    "Block Barrage of Stone to avoid knockdown; stay out of her leap circle.",
    "Hold Zatzu steady.",
    "Light damage.",
    "Burn it.",
    "[Zatzu] Block boulders; avoid leap.")

addBoss("Mighty Chudan", "Ruins of Mazzatun", "Mighty Chudan", {"Chudan"},
    "Haj Mota that charges a targeted player.",
    "When a Shellbinder spawns and Chudan targets you, stand so his Bog Rush hits the Shellbinder instead. Block Mucous Spray.",
    "Hold position; let targeted players line up the charge.",
    "Shellbinder lightning ramps if they live.",
    "Kill Shellbinders fast.",
    "[Chudan] Bait charge into Shellbinder; kill Shellbinders.",
    {
        challenges = {
            { name = "Haj Mota Matador", text = "No one gets hit by Bog Rush." },
        },
    })

addBoss("Xal-Nur the Slaver", "Ruins of Mazzatun", "Xal-Nur the Slaver", {"Xal-Nur", "Xal Nur"},
    "Wamasu slaver who goes invulnerable at 75/50/25% for spice phases.",
    "Spice phase: pick up spice from the green AoE, carry it to the geyser and cleanse. Block-step into Monstrous Blitz.",
    "Control the adds during invulnerable phases.",
    "Keep the spice runner alive.",
    "Clear adds while the runner cleanses.",
    "[Xal-Nur] Spice to geyser; control adds.",
    {
        challenges = {
            { name = "Obedience Training", text = "Don't release any wamasu (don't kill the Wranglers)." },
            { name = "Clean Freak", text = "Only one player cleanses spice." },
        },
    })

addBoss("Tree-Minder Na-Kesh", "Ruins of Mazzatun", "Tree-Minder Na-Kesh", {"Na-Kesh", "Na Kesh"},
    "Final boss with phantom bosses, a hallucination totem and a vine execute.",
    "Kill Siphoning Totems fast. Hallucinating player destroys the REAL totem (others: guide them). At 25%, stand in gaps between the vine cones.",
    "Pull Na-Kesh toward the real totem to guide the hallucinating player.",
    "Totem phase is the danger window.",
    "Burn the phantoms (Chudan at 75%, Xal-Nur at 50%).",
    "[Na-Kesh] Kill totems; find real totem; dodge vine cones at 25%.",
    {
        hardmode = "Destroy Na-Kesh's Notes on the Amber Plasm. More adds, no reveal synergy for the totem, empowered Stoneshapers. Kill adds before phantoms.",
        challenges = {
            { name = "Tree-Minder's Mania", text = "Defeat Na-Kesh on Veteran Hard Mode." },
            { name = "Blind Luck", text = "No one uses the Reveal synergy." },
            { name = "Sticky Situation Savvy", text = "No one is hit by Blistering Amber." },
        },
    })

-- =============================================================================
-- Horns of the Reach
-- =============================================================================

-- Bloodroot Forge
addDungeon("Bloodroot Forge", "dlc", { group = "Horns of the Reach" })
addBoss("Mathgamain", "Bloodroot Forge", "Mathgamain", {},
    "Nirnblooded bear with animal adds and stranglers.",
    "Stay out of the red lunge cone. Kill stranglers (poison AoEs) first.",
    "Face Mathgamain away from the group.",
    "Add damage stacks if they live.",
    "Stranglers first, then adds, then bear.",
    "[Mathgamain] Avoid lunge; kill stranglers first.")

addBoss("Caillaoife", "Bloodroot Forge", "Caillaoife", {},
    "Hagraven with fire/frost swaps, a stun cone and shield phases.",
    "At 75/50/25% she shields: stay OUT of the dome and kill adds. Avoid the Wave of Earth stun cone.",
    "Face her away; grab bears first.",
    "Alternating flame and frost damage.",
    "Bears are priority; AoE the rest.",
    "[Caillaoife] Stay out of shield dome; kill bears first.")

addBoss("Stoneheart", "Bloodroot Forge", "Stoneheart", {},
    "Reachman mage who summons stone atronachs.",
    "Roll out of Fire Bloom roots. Below 20% all atronachs wake: burn the boss right away.",
    "Pick up atronachs as they spawn.",
    "Atronach damage grows over time.",
    "Kill atronachs quickly; save burst for under 20%.",
    "[Stoneheart] Kill atronachs; burn boss under 20%.")

addBoss("Galchobhar", "Bloodroot Forge", "Galchobhar", {},
    "Minotaur with lava, volcanoes and a lethal ring.",
    "Scorched Earth: jump onto a rock, ONE player per rock. Don't fall in lava. Avoid Wake of Fire lines.",
    "Block Mantle Breaker; stand on the volcano and block it.",
    "Lava and fire waves put steady pressure on the group.",
    "Kill fire shalks quickly.",
    "[Galchobhar] Scorched Earth = 1 per rock; tank blocks volcano.")

addShared({"Gherig Bullblood", "Attendant of Blood", "Attendant of Flame"},
    "Bloodroot Forge", "Gherig Bullblood & Attendants", {"Gherig", "Bullblood"},
    "Minotaur with two healer/caster attendants.",
    "Interrupt the Attendant of Blood's heals. When Burnt Offering chains players, someone unchained interrupts the Attendant of Flame.",
    "Hold Gherig, block Uppercut; pull enemies apart to stop Quenching Blood.",
    "Burnt Offering and Pyrocasm spike.",
    "Interrupt, then focus attendants.",
    "[Gherig] Interrupt Blood's heals and Flame's Burnt Offering.")

addBoss("Earthgore Amalgam", "Bloodroot Forge", "Earthgore Amalgam", {"Amalgam"},
    "Iron atronach that splits into clones while lava slowly fills the arena.",
    "Keep moving for falling debris. Use the Flameslake Cauldron synergy to clear lava. Clones at 75/50%: kill small, then medium, then the big one.",
    "Block Anvil Cracker.",
    "Debris and stomps get heavier over time.",
    "Pace is everything: lava covers the arena if the fight drags.",
    "[Amalgam] Keep moving; clear lava; clones small > medium > big.",
    {
        hardmode = "Read the Scroll of Glorious Battle. More health and damage, and no Cauldron synergy: kill everything before lava covers the arena.",
        challenges = {
            { name = "Tempered Tantrum", text = "Defeat Earthgore Amalgam on Veteran Hard Mode." },
        },
    })

-- Falkreath Hold
addDungeon("Falkreath Hold", "dlc", { group = "Horns of the Reach" })
addBoss("Morrigh Bullblood", "Falkreath Hold", "Morrigh Bullblood", {"Morrigh"},
    "Minotaur miniboss with siege fire and a poison cone.",
    "Avoid siege red circles (or stand in her shield). Interrupt her health potion. Avoid the poison cone.",
    "Don't let her hit you from behind (+20% damage).",
    "Siege fire spikes.",
    "Interrupt the potion.",
    "[Morrigh] Avoid siege fire; interrupt potion.")

addBoss("Siege Mammoth", "Falkreath Hold", "Siege Mammoth", {"Mammoth"},
    "Mammoth with charges, tusk sweeps and a stomp at 50%.",
    "Block or dodge the tusk sweep; block the 50% stomp.",
    "Face it into a wall so charges don't knock people around.",
    "Stomp damage at 50%.",
    "Stay behind.",
    "[Mammoth] Face into wall; block stomp at 50%.",
    {
        challenges = {
            { name = "Wild and Woolly", text = "No one is stunned, staggered or knocked back." },
        },
    })

addBoss("Cernunnon", "Falkreath Hold", "Cernunnon", {},
    "Bone colossus; necromancers' bodies must be carried to graves.",
    "Stay inside the soul barrier in the middle. Carry dead necromancers to graves before they rise. Avoid meteors.",
    "Hold the boss in the center; collect wraiths.",
    "He raises the necromancers at 50%.",
    "Kill necromancers, then carry bodies.",
    "[Cernunnon] Stay in barrier; carry bodies to graves.",
    {
        challenges = {
            { name = "Oathbreaker", text = "Banish all three necromancers' souls within 5 seconds of each other." },
        },
    })

addBoss("Deathlord Bjarfrud Skjoralmor", "Falkreath Hold", "Deathlord Bjarfrud Skjoralmor", {"Bjarfrud", "Skjoralmor"},
    "Draugr lord who powers up from uncleansed corpses.",
    "Cleanse draugr corpses at the urns or Deathlord's Fury gets lethal. Roll out of roots; avoid the breath cone.",
    "Face away from the group; group draugr adds.",
    "Fury bolts scale with corpses left.",
    "Kill draugr, then cleanse.",
    "[Bjarfrud] Cleanse corpses at urns; avoid breath.",
    {
        challenges = {
            { name = "Epic Undertaking", text = "Cleanse 15 corpses within 5 seconds." },
        },
    })

addBoss("Domihaus the Bloody-Horned", "Falkreath Hold", "Domihaus the Bloody-Horned", {"Domihaus"},
    "Final minotaur with a ring of fire, atronachs and lethal shouts.",
    "At 70/50/30/10% he shouts: HIDE BEHIND A PILLAR or die. Stay inside the fire ring.",
    "Keep atronachs away from the boss.",
    "Pillar eruptions and atronachs keep pressure up.",
    "Kill atronachs at 80/60/40/20%; protect the pillars.",
    "[Domihaus] Shout = hide behind pillar; kill atronachs.",
    {
        hardmode = "Sound the Warhorn before the fight: two pillars are destroyed, and under 20% he gains a damage shield and alternates shouts with adds.",
        challenges = {
            { name = "Column Caretaker", text = "Keep 2+ pillars standing." },
            { name = "Endure the Elements", text = "Keep one of each atronach alive during the final phase." },
        },
    })

-- Challenge Banner hard modes: final boss only in Castle Thorn and The Cauldron,
-- every boss from Stone Garden / Black Drake Villa on.
local BANNER_HM = "Raise the Challenge Banner (Veteran): more health and damage, plus extra mechanics."

-- =============================================================================
-- Dragon Bones
-- =============================================================================

-- Fang Lair
addDungeon("Fang Lair", "dlc", { group = "Dragon Bones" })
addBoss("Lizabet Charnis", "Fang Lair", "Lizabet Charnis", {"Lizabet"},
    "Necromancer miniboss with skeletal adds.",
    "Stack and cleave the adds; avoid her ground AoE.",
    "Group the adds on her.",
    "Add pressure.",
    "Cleave everything.",
    "[Lizabet] Stack adds; cleave.")

addShared({"Cadaverous Menagerie", "Cadaverous Bear", "Cadaverous Guar", "Cadaverous Senche-Tiger"},
    "Fang Lair", "Cadaverous Menagerie", {"Menagerie"},
    "Skeletal bear, guar and senche that combine into one beast.",
    "Get out of Death Grip quickly; avoid the volatile fungi.",
    "Hold the animals together, facing away.",
    "Death Grip targets need fast heals.",
    "Cleave the animals evenly.",
    "[Menagerie] Escape Death Grip; avoid fungi.",
    {
        challenges = {
            { name = "Obedience Maiming", text = "No one is killed by Death Grip." },
            { name = "Fungi Free", text = "No one takes Volatile Fungi damage." },
        },
    })
-- VERIFY: individual animal NPC names.

addBoss("Caluurion", "Fang Lair", "Caluurion", {},
    "Lich who powers elemental relics around the room.",
    "Shut down the relics with the matching elemental Bonefiends. Avoid elemental ground AoE.",
    "Hold Caluurion away from the relics.",
    "Elemental damage spikes while relics are active.",
    "Kill Bonefiends at the right relic.",
    "[Caluurion] Match Bonefiend element to relic.",
    {
        challenges = {
            { name = "Elementary Anatomy", text = "Use the correct elemental Bonefiend for each relic." },
        },
    })

addShared({"Ulfnor", "Sabina Cedus"}, "Fang Lair", "Ulfnor & Sabina Cedus", {"Sabina"},
    "Skeletal warrior with a ghost ally who haunts players.",
    "Avoid Sabina's Haunting Spectre; stay out of Ulfnor's heavy cleaves.",
    "Hold Ulfnor facing away.",
    "Haunted players need help.",
    "Focus Ulfnor; deal with Sabina when she's active.",
    "[Ulfnor] Avoid spectre; face away.",
    {
        challenges = {
            { name = "Nonplussed", text = "No one is affected by Haunting Spectre." },
        },
    })

addShared({"Thurvokun", "Orryn the Black"}, "Fang Lair", "Thurvokun & Orryn the Black", {"Orryn"},
    "Final fight: a necromancer and his reanimated dragon.",
    "Avoid plague breath and scarab acid. Destroy Animus Crystals before they power the dragon.",
    "Keep Thurvokun's breath pointed away from the group.",
    "Plague and acid damage pile up.",
    "Destroy crystals, then burn.",
    "[Thurvokun] Avoid breath/acid; break crystals.",
    {
        hardmode = "Read Orryn's incantation notes before the fight. Wraith thralls chase players: dodge them.",
        challenges = {
            { name = "Minimal Animosity", text = "Destroy at most one crystal before the merge." },
            { name = "Starved Scarabs", text = "No one is hit by scarab acid." },
            { name = "Cold Pursuit", text = "Dodge the wraith thralls after reading the notes." },
        },
    })

-- Scalecaller Peak
addDungeon("Scalecaller Peak", "dlc", { group = "Dragon Bones" })
addShared({"Orzun the Foul-Smelling", "Rinaerus the Rancid"}, "Scalecaller Peak", "Orzun & Rinaerus", {"Orzun", "Rinaerus"},
    "Toxic ogre pair.",
    "Avoid toxic pools and Terrorizing Tremor.",
    "Hold both and stack them.",
    "Poison ticks build up.",
    "Cleave both together.",
    "[Orzun] Avoid tremor and pools; cleave both.",
    {
        challenges = {
            { name = "Tremor Trouble", text = "No deaths from Terrorizing Tremor." },
        },
    })

addBoss("Doylemish Ironheart", "Scalecaller Peak", "Doylemish Ironheart", {"Doylemish"},
    "Gargoyle with a petrifying gaze.",
    "Break line of sight with Stony Gaze to avoid petrification.",
    "Face him away from the group.",
    "Petrified players are sitting ducks.",
    "Burn while he's busy.",
    "[Doylemish] Avoid Stony Gaze.",
    {
        challenges = {
            { name = "Stony Situation", text = "No one is petrified by Stony Gaze." },
        },
    })

addBoss("Matriarch Aldis", "Scalecaller Peak", "Matriarch Aldis", {"Aldis"},
    "Infected giant in an arena with damaging water.",
    "Stay out of the water.",
    "Hold her on dry ground.",
    "Water damage stacks fast.",
    "Stay dry and burn.",
    "[Aldis] Stay out of the water.",
    {
        challenges = {
            { name = "Watch Your Step", text = "No one takes water damage." },
        },
    })

addBoss("Plague Concocter Mortieu", "Scalecaller Peak", "Plague Concocter Mortieu", {"Mortieu"},
    "Cultist who stacks infection debuffs.",
    "Manage your infections; cleanse stacks before they overlap.",
    "Hold Mortieu steady.",
    "Watch stacked infections.",
    "Burn before infections stack up.",
    "[Mortieu] Manage infections; burn.",
    {
        challenges = {
            { name = "Doctor's Orders", text = "Defeat him with all four players carrying two infections each." },
        },
    })

addBoss("Zaan the Scalecaller", "Scalecaller Peak", "Zaan the Scalecaller", {"Zaan"},
    "Final dragon priest with a shield knockback and Pestilent Breath.",
    "Block or avoid the shield knockback. Avoid / block the breath beam.",
    "Hold Zaan; block the knockback.",
    "Breath ticks are heavy.",
    "Keep uptime around the beam.",
    "[Zaan] Block knockback; avoid breath beam.",
    {
        hardmode = "Read Zaan's Ritual Scroll before the fight.",
        challenges = {
            { name = "Breaker of Spells", text = "Defeat Zaan on Veteran Hard Mode." },
            { name = "Stand Your Ground", text = "No one is knocked back." },
            { name = "Daedric Deflector", text = "Alternate all three ways of avoiding the breath." },
        },
    })

-- =============================================================================
-- Wolfhunter
-- =============================================================================

-- March of Sacrifices
addDungeon("March of Sacrifices", "dlc", { group = "Wolfhunter" })
addShared({"Wyress Rangifer", "Wyress Strigidae", "Wyress Ursus"}, "March of Sacrifices", "The Wyress Sisters", {"Wyress"},
    "Three witches whose auras buff each other when close.",
    "Keep the sisters SEPARATED. Interrupt Strigidae's Snipe and Ursus's heavy attacks.",
    "Pull the sisters apart.",
    "Snipes hit hard if not interrupted.",
    "Interrupt; focus one sister at a time.",
    "[Wyress] Keep sisters apart; interrupt snipe.",
    {
        challenges = {
            { name = "Stalwart Sisterhood", text = "The sisters never buff each other with auras." },
        },
    })

addBoss("Aghaedh of the Solstice", "March of Sacrifices", "Aghaedh of the Solstice", {"Aghaedh"},
    "Seasonal boss with Lurchers and colored orbs.",
    "Kill Lurchers and pick up the matching orbs. On Wild Shot, stand in the correct Sapling AoE.",
    "Hold Aghaedh steady.",
    "Wild Shot hurts if you're in the wrong spot.",
    "Kill Lurchers quickly.",
    "[Aghaedh] Collect orbs; stand in the right sapling.",
    {
        challenges = {
            { name = "Seasonal Slaying", text = "Kill all Lurchers within their primary season." },
        },
    })

addBoss("Dagrund the Bulky", "March of Sacrifices", "Dagrund the Bulky", {"Dagrund"},
    "Ogre who switches between adds and himself.",
    "Dodge Upheaval. Swap between the adds and the boss.",
    "Collect adds.",
    "Upheaval damage.",
    "Swap targets as adds spawn.",
    "[Dagrund] Dodge Upheaval; swap to adds.",
    {
        challenges = {
            { name = "Light on Your Feet", text = "Always dodge Upheaval." },
        },
    })

addBoss("Tarcyr", "March of Sacrifices", "Tarcyr", {},
    "Hunter who stealths and hunts the group.",
    "Use the three wisp synergies to break his stealth. Avoid phantom indriks.",
    "Pick him back up after stealth.",
    "Damage spikes during hunting phases.",
    "Burst when he's revealed.",
    "[Tarcyr] Wisp synergies break stealth; avoid indriks.",
    {
        challenges = {
            { name = "Mist Walker", text = "The indrik never teleports anyone." },
        },
    })

addBoss("Balorgh", "March of Sacrifices", "Balorgh", {},
    "Final werewolf behemoth; water vs. islands.",
    "Poison attack: get IN the water. Lightning attack: get OUT onto an island. Fog phase: kite him through the blue pillar.",
    "Kite through the blue pillar during fog.",
    "Wrong-spot damage is lethal.",
    "Follow the water/island swaps; keep uptime.",
    "[Balorgh] Poison = water, lightning = island; blue pillar in fog.",
    {
        hardmode = "Desecrate the Moon Hunter Pack banner before the fight: Balorgh enters a murderous rage.",
        challenges = {
            { name = "Hircine's Champion", text = "Defeat Balorgh on Veteran Hard Mode." },
        },
    })

-- Moon Hunter Keep
addDungeon("Moon Hunter Keep", "dlc", { group = "Wolfhunter" })
addBoss("Jailer Melitus", "Moon Hunter Keep", "Jailer Melitus", {"Melitus"},
    "Jailer with an instant-kill stun and enraging adds.",
    "INTERRUPT the stun execute. Stay out of blood AoEs (they slow you). Kill adds before they enrage.",
    "Hold Melitus; interrupt if needed.",
    "Execute target needs help.",
    "Kill adds quickly.",
    "[Melitus] Interrupt execute; avoid blood.")

addBoss("Hedge Maze Guardian", "Moon Hunter Keep", "Hedge Maze Guardian", {},
    "Spriggan with a hedge maze and healing adds.",
    "Don't go into the maze alone: stranglers kill isolated players. Destroy the healing spriggans. Break roots fast.",
    "Hold the guardian.",
    "Root snares tick constantly.",
    "Kill healing spriggans in the maze as a group.",
    "[Hedge Maze] Kill healers in pairs; never alone in maze.")

addBoss("Mylenne Moon-Caller", "Moon Hunter Keep", "Mylenne Moon-Caller", {"Mylenne"},
    "Werewolf caller who pins and kills players.",
    "When she pounces and PINS someone, interrupt immediately or they die. Kill shock wardens before they enrage her.",
    "Interrupt the pounce if you can.",
    "Dire wolf slows stack.",
    "Kill wardens; interrupt pounce.",
    "[Mylenne] Interrupt pinning pounce; kill wardens.")

addBoss("Archivist Ernarde", "Moon Hunter Keep", "Archivist Ernarde", {"Ernarde"},
    "Archivist with crushing bubbles and a seal puzzle.",
    "Burst the Crushing Bubble before it kills the trapped player. Puzzle phase: stand on the correct colored seal or die.",
    "Hold the boss away from seals.",
    "Lightning targets can't share damage.",
    "Burst bubbles fast.",
    "[Ernarde] Burst bubbles; stand on the right seal.")

addShared({"Vykosa the Ascendant", "Ary", "Zel"}, "Moon Hunter Keep", "Vykosa the Ascendant", {"Vykosa"},
    "Final werewolf with two wolf pets and an add phase.",
    "Under 20% her wolves break free: burn fast. Don't leave corpses: she eats them to heal.",
    "Hold Vykosa; pick up werewolf adds.",
    "Execute phase is the danger window.",
    "Save burst for under 20%.",
    "[Vykosa] Burn under 20%; don't let her eat corpses.",
    {
        hardmode = "Read the Scroll of Glorious Battle: about +1.5M health, double werewolves, stranglers at 80%, shock wardens at 60%, and Ernarde's shade with a puzzle at 30%.",
        challenges = {
            { name = "The Alpha Predator", text = "Defeat Vykosa on Veteran Hard Mode." },
            { name = "Strangling Cowardice", text = "Hard mode: kill 7 stranglers and never cower the wolves." },
        },
    })

-- =============================================================================
-- Wrathstone
-- =============================================================================

-- Depths of Malatar
addDungeon("Depths of Malatar", "dlc", { group = "Wrathstone" })
addBoss("The Scavenging Maw", "Depths of Malatar", "The Scavenging Maw", {"Scavenging Maw", "Maw"},
    "Creature that feeds on soldiers and attacks from shadow forms.",
    "Avoid its shadow forms; keep it from feeding.",
    "Hold it away from soldier corpses.",
    "Shadow attacks spike.",
    "Burn it.",
    "[Maw] Avoid shadow forms; stop feeding.",
    {
        challenges = {
            { name = "Hide and Seek", text = "Don't break the proboscis; avoid shadow forms." },
        },
    })

addBoss("The Weeping Woman", "Depths of Malatar", "The Weeping Woman", {"Weeping Woman"},
    "Nereid who freezes the arena.",
    "Avoid Glaciation.",
    "Hold her steady.",
    "Frost damage builds.",
    "Burn her.",
    "[Weeping Woman] Avoid Glaciation.",
    {
        challenges = {
            { name = "Skating the Ice", text = "No one is hit by Glaciation." },
        },
    })

addBoss("Dark Orb", "Depths of Malatar", "Dark Orb", {},
    "Orb that commands colored Auroran adds.",
    "Kill the Auroran adds; avoid magic AoE.",
    "Group the Aurorans.",
    "Magic damage spikes.",
    "Clear adds, then the orb.",
    "[Dark Orb] Clear Aurorans; avoid AoE.",
    {
        challenges = {
            { name = "Color Blind", text = "Don't destroy the colored orbs." },
        },
    })

addBoss("King Narilmor", "Depths of Malatar", "King Narilmor", {"Narilmor"},
    "Immortal king tied into a deadlock with Quintus and Tharayya.",
    "Follow the deadlock mechanic; avoid his heavy attacks.",
    "Hold Narilmor facing away.",
    "Steady damage.",
    "Burn when he's mortal.",
    "[Narilmor] Work the deadlock; face away.",
    {
        challenges = {
            { name = "Soul Mates", text = "Don't let Quintus win the deadlock." },
        },
    })
-- VERIFY: deadlock mechanic details.

addBoss("Symphony of Blades", "Depths of Malatar", "Symphony of Blades", {"Symphony"},
    "Final sentinel with an Auroran Phalanx and ice pillars.",
    "Block / avoid the phalanx crossing. Use meteors to break ice pillars.",
    "Hold the boss; block the phalanx.",
    "Phalanx charges hit hard.",
    "Burn between phalanx crossings.",
    "[Symphony] Avoid phalanx; break ice pillars.",
    {
        hardmode = "Burn the Dictates of the Lady of Light papers before the fight.",
        challenges = {
            { name = "Throwing Shade", text = "Defeat Symphony of Blades on Veteran Hard Mode." },
            { name = "Out of Formation", text = "Block the phalanx crossing." },
            { name = "Ice Breaker", text = "Destroy 5 ice pillars with meteors." },
        },
    })

-- Frostvault
addDungeon("Frostvault", "dlc", { group = "Wrathstone" })
addBoss("Icestalker", "Frostvault", "Icestalker", {},
    "Frost troll miniboss with frenzied uppercuts.",
    "Block the uppercuts; stay out of his front.",
    "Face him away; block Frenzied Pummeling.",
    "Light damage.",
    "Burn it.",
    "[Icestalker] Block uppercuts.")

addBoss("Warlord Tzogvin", "Frostvault", "Warlord Tzogvin", {"Tzogvin"},
    "Riekling chief with charges and banners.",
    "Dodge Reckless Charges. Destroy his banners.",
    "Hold him; watch charges.",
    "Charges hurt.",
    "Destroy banners.",
    "[Tzogvin] Dodge charges; destroy banners.",
    {
        challenges = {
            { name = "Running the Right Angles", text = "Dodge every charge." },
            { name = "Three Sheets to the Wind", text = "Destroy all three banners." },
        },
    })

addBoss("Vault Protector", "Frostvault", "Vault Protector", {"Protector"},
    "Dwarven centurion with searing rays and volatile spheres.",
    "Avoid the searing rays. Detonate volatile spheres near constructs, not the group.",
    "Hold it facing away.",
    "Ray damage is heavy.",
    "Use spheres on constructs.",
    "[Protector] Avoid rays; spheres on constructs.",
    {
        challenges = {
            { name = "Collateral Damage", text = "Detonate 20 constructs with spheres." },
        },
    })

addShared({"Rizzuk Bonechill", "Avalanche"}, "Frostvault", "Rizzuk Bonechill & Avalanche", {"Rizzuk"},
    "Riekling mage with a frost atronach.",
    "Free players trapped in Glacial Prison.",
    "Hold Avalanche away from the group.",
    "Prisoned players need heals.",
    "Burn Rizzuk.",
    "[Rizzuk] Free Glacial Prison targets.",
    {
        challenges = {
            { name = "Cold Potato", text = "Everyone gets hit by Glacial Prison at least once." },
        },
    })

addBoss("The Stonekeeper", "Frostvault", "The Stonekeeper", {"Stonekeeper"},
    "Final colossus with Extermination Protocol and a platform knock-off.",
    "Shut down Extermination Protocol using the skeevatons. Don't get knocked off the platform.",
    "Hold it in the middle; block knockbacks.",
    "Protocol damage ramps.",
    "Control skeevatons; burn.",
    "[Stonekeeper] Use skeevatons to stop Protocol; stay on platform.",
    {
        hardmode = "Press the Veracity Verifier before the fight: adds extra skeevaton phases.",
        challenges = {
            { name = "Vault Cracker", text = "Defeat the Stonekeeper on Veteran Hard Mode." },
            { name = "Rat Race", text = "Shut down Extermination Protocol within 35 seconds." },
        },
    })

-- =============================================================================
-- Scalebreaker
-- =============================================================================

-- Lair of Maarselok
addDungeon("Lair of Maarselok", "dlc", { group = "Scalebreaker" })
addBoss("Selene", "Lair of Maarselok", "Selene", {},
    "Corrupted Selene fires poison bolts.",
    "Dodge the poison bolts.",
    "Hold her steady.",
    "Bolt damage.",
    "Burn her.",
    "[Selene] Dodge poison bolts.",
    {
        challenges = {
            { name = "Duck and Weave", text = "No one takes poison bolt damage." },
        },
    })

addBoss("Azureblight Cancroid", "Lair of Maarselok", "Azureblight Cancroid", {"Cancroid"},
    "Blighted crab with corrupted seeds.",
    "Cleanse and pick up the corrupted seeds.",
    "Hold it away from seeds.",
    "Blight damage.",
    "Cleanse seeds, then burn.",
    "[Cancroid] Cleanse and grab seeds.",
    {
        challenges = {
            { name = "Crop Rotation", text = "Each player picks up a cleansed seed." },
        },
    })

addBoss("Maarselok", "Lair of Maarselok", "Maarselok", {},
    "The dragon: strafes in flight, then fights from his perch and roost with Lurchers and scourge seeds.",
    "Get out of the Blightbreath Strafe path. Manage Lurchers. Cleanse scourge seeds; Selene helps with wards.",
    "Hold Maarselok; pick up Lurchers.",
    "Strafe and blight damage hit the whole group.",
    "Burn the dragon; cleanse seeds.",
    "[Maarselok] Avoid strafe; manage Lurchers; cleanse seeds.",
    {
        hardmode = "Smash the Azureblight Seed near the final arena: Selene turns hostile instead of helping.",
        challenges = {
            { name = "Eyes to the Sky", text = "No one is hit by the strafe." },
            { name = "Scourge Purger", text = "Cleanse all seeds without Selene using her wards." },
        },
    })

-- Moongrave Fane
addDungeon("Moongrave Fane", "dlc", { group = "Scalebreaker" })
addBoss("Risen Ruins", "Moongrave Fane", "Risen Ruins", {},
    "Stone construct with ground attacks.",
    "Watch your positioning and avoid ground attacks.",
    "Face it away.",
    "Ground attack damage.",
    "Burn it.",
    "[Risen Ruins] Avoid ground attacks.",
    {
        challenges = {
            { name = "Bloodless Kill", text = "Don't use the Sangiin Sacrifice synergy." },
        },
    })

addBoss("Dro'zakar", "Moongrave Fane", "Dro'zakar", {"Drozakar"},
    "Vampire khajiit who drains health.",
    "Interrupt his consumption, or smash the Hemo Helot he's feeding on.",
    "Hold him; interrupt.",
    "Drain damage.",
    "Interrupt; burn.",
    "[Dro'zakar] Interrupt consumption.",
    {
        challenges = {
            { name = "Bloody Kill", text = "Smash a Hemo Helot while he's consuming it." },
        },
    })

addBoss("Kujo Kethba", "Moongrave Fane", "Kujo Kethba", {"Kujo"},
    "Fire boss with geysers and a flaming gargoyle.",
    "Block the geysers; stay out of the gargoyle's fire.",
    "Hold Kujo.",
    "Fire area denial.",
    "Burn.",
    "[Kujo] Block geysers; avoid fire.",
    {
        challenges = {
            { name = "Cubed", text = "Block three geysers within 3 seconds of each other." },
        },
    })

addShared({"Nisaazda", "Grundwulf"}, "Moongrave Fane", "Grundwulf & Nisaazda", {},
    "Final fight: Nisaazda links her health to Grundwulf, then Grundwulf is empowered by dragon blood.",
    "Stop Blood Ties: focus damage. In Grundwulf's phase, work the sliding-stone puzzle.",
    "Hold both; separate them if needed.",
    "Empowered Grundwulf hits much harder.",
    "Focus-fire to stop Blood Ties.",
    "[Grundwulf] Focus fire; do the stone puzzle.",
    {
        hardmode = "Use the Sangiin Hemo Helot during the fight: Grundwulf is empowered by dragon blood.",
        challenges = {
            { name = "Failed Transfusion", text = "Don't let Nisaazda use Blood Ties." },
            { name = "Shared Experience", text = "Each player moves the stone at most once." },
        },
    })

-- =============================================================================
-- Harrowstorm
-- =============================================================================

-- Icereach
addDungeon("Icereach", "dlc", { group = "Harrowstorm" })
addShared({"Kjarg the Tuskscraper", "Sister Gohlla"}, "Icereach", "Kjarg the Tuskscraper", {"Kjarg"},
    "Tusked boss with a witch that summons frost atronachs.",
    "Kill frost atronachs before they fully form.",
    "Hold Kjarg; pick up atronachs.",
    "Atronach damage adds up.",
    "Kill atronachs early.",
    "[Kjarg] Kill frost atronachs before they form.",
    {
        challenges = {
            { name = "Frozen Finish", text = "Defeat him with 3+ fully formed frost atronachs alive." },
        },
    })

addShared({"Sister Skelga", "Sister Hiti"}, "Icereach", "Sister Skelga & Sister Hiti", {"Skelga", "Hiti"},
    "Two witches with strangler ice spit.",
    "Avoid the strangler projectiles.",
    "Hold both sisters.",
    "Ice spit hits hard.",
    "Kill stranglers; focus one sister.",
    "[Sisters] Avoid strangler spit.",
    {
        challenges = {
            { name = "Spit Take", text = "No one is hit by strangler projectiles." },
        },
    })

addShared({"Vearogh the Shambler", "Sister Bani"}, "Icereach", "Vearogh the Shambler", {"Vearogh"},
    "Shambler with a witch who opens rift wraiths.",
    "Kill or control rift wraiths from the portals.",
    "Hold Vearogh; collect wraiths.",
    "Wraith damage.",
    "Clear wraiths.",
    "[Vearogh] Handle rift wraiths.",
    {
        challenges = {
            { name = "An Open Invocation", text = "Defeat without killing any Rift Wraiths." },
        },
    })

addShared({"Stormborn Revenant", "Sister Maefyn"}, "Icereach", "Stormborn Revenant", {"Revenant"},
    "Revenant with a witch summoning storm atronachs.",
    "Kill storm atronachs quickly.",
    "Hold the revenant.",
    "Shock damage.",
    "Kill atronachs fast.",
    "[Revenant] Kill storm atronachs.",
    {
        challenges = {
            { name = "Lightning Strikes Thrice", text = "Kill 3 storm atronachs with 3 seconds or less between kills." },
        },
    })

addBoss("Mother Ciannait", "Icereach", "Mother Ciannait", {"Ciannait"},
    "Final witch, supported by all four sisters.",
    "INTERRUPT the channeled spell. Coordinate interrupts across the group.",
    "Hold Ciannait; interrupt.",
    "Channel damage is lethal if not interrupted.",
    "Interrupt, then burn.",
    "[Ciannait] Interrupt the channel!",
    {
        hardmode = "Burn the sacred wicker totem before the fight.",
    })

-- Unhallowed Grave
addDungeon("Unhallowed Grave", "dlc", { group = "Harrowstorm" })
addBoss("Hakgrym the Howler", "Unhallowed Grave", "Hakgrym the Howler", {"Hakgrym"},
    "Werewolf behemoth healed by flesh abominations.",
    "Kill or control the Flesh Abominations that heal him.",
    "Hold Hakgrym; collect abominations.",
    "Behemoth melee.",
    "Burn through heals.",
    "[Hakgrym] Deal with healing abominations.",
    {
        challenges = {
            { name = "Relentless Dogcatcher", text = "Defeat him without destroying any Flesh Abominations." },
        },
    })

addBoss("Keeper of the Kiln", "Unhallowed Grave", "Keeper of the Kiln", {"Keeper"},
    "Symbol puzzle boss.",
    "Choose the correct symbol; wrong guesses damage the group.",
    "Hold the boss.",
    "Wrong-symbol damage.",
    "Burn.",
    "[Kiln] Pick the right symbol.",
    {
        challenges = {
            { name = "Ceramic Panic", text = "Defeat without ever revealing the correct symbol." },
        },
    })

addBoss("Eternal Aegis", "Unhallowed Grave", "Eternal Aegis", {"Aegis"},
    "Ring of Blades blocks attacks; lesser aegises explode.",
    "Handle Lesser Aegises before they explode.",
    "Hold the boss.",
    "Explosions spike.",
    "Kill lesser aegises.",
    "[Aegis] Stop lesser aegis explosions.",
    {
        challenges = {
            { name = "Shattered Shields", text = "Prevent Ring of Blades from blocking." },
        },
    })

addBoss("Ondagore the Mad", "Unhallowed Grave", "Ondagore the Mad", {"Ondagore"},
    "Summons Menders that heal him.",
    "Kill the Menders.",
    "Hold Ondagore; group Menders.",
    "Add pressure.",
    "Menders first.",
    "[Ondagore] Kill Menders.",
    {
        challenges = {
            { name = "Mender Wrender", text = "Kill all Menders within 5 seconds of each other." },
        },
    })

addShared({"Kjalnar Tombskald", "Tzirzhalir"}, "Unhallowed Grave", "Kjalnar Tombskald", {"Kjalnar"},
    "Final fight: a skald and his skeletal dragon; imbued skeletons empower in circles.",
    "Stop imbued skeletons from reaching their circles.",
    "Hold Kjalnar; intercept skeletons.",
    "Empowered damage ramps.",
    "Kill skeletons before the circles.",
    "[Kjalnar] Stop skeletons reaching circles.",
    {
        hardmode = "Destroy the Skull Totem before the fight.",
        challenges = {
            { name = "Skull Smasher", text = "Defeat Kjalnar on Veteran Hard Mode." },
            { name = "Skeletal Shutout", text = "No skeleton reaches a circle." },
        },
    })

-- =============================================================================
-- Stonethorn
-- =============================================================================

-- Castle Thorn
addDungeon("Castle Thorn", "dlc", { group = "Stonethorn" })
addBoss("Dread Tindulra", "Castle Thorn", "Dread Tindulra", {"Tindulra"},
    "Fire boss with death hound broodlings at 75%.",
    "Avoid the fire; handle the broodlings.",
    "Hold Tindulra; group broodlings.",
    "Fire damage.",
    "Kill broodlings.",
    "[Tindulra] Avoid fire; kill broodlings.",
    { challenges = { { name = "Hound Pound", text = "Kill broodlings 15+ meters apart." } } })

addBoss("Blood Twilight", "Castle Thorn", "Blood Twilight", {},
    "Vampire with Dark Barrage and a teleport slam.",
    "Avoid Dark Barrage. Shadow Strike teleports and slams hard: block it.",
    "Hold her; block the slam.",
    "Shadow Strike spikes.",
    "Burn.",
    "[Blood Twilight] Block Shadow Strike; avoid barrage.")

addBoss("Vaduroth", "Castle Thorn", "Vaduroth", {},
    "Storm boss with Crow's Feast and an explosive pull.",
    "Get out of Crow's Feast. Discard pulls targets and makes them explode: move away from the group.",
    "Hold Vaduroth.",
    "Crow's Feast ticks heavily.",
    "Burn.",
    "[Vaduroth] Out of Crow's Feast; Discard targets move away.",
    { challenges = { { name = "Four by Four", text = "Each player bursts a corpse with the sickle." } } })

addBoss("Talfyg", "Castle Thorn", "Talfyg", {},
    "Blood mage with heavy swipes and AoE magic.",
    "Avoid Cross Swipe and the Annihilate/Disintegrate AoEs.",
    "Face him away; block swipes.",
    "Blood magic AoE.",
    "Burn.",
    "[Talfyg] Avoid swipes and blood AoE.",
    { challenges = { { name = "Let Sleeping Gargoyles Lie", text = "Don't kill the large Frozen Gargoyles." } } })

addBoss("Lady Thorn", "Castle Thorn", "Lady Thorn", {},
    "Final vampire with batswarm and scatter phases.",
    "Batswarm: get to the SAFE ZONE. Scatter: she's invulnerable; use the synergies to bring her back.",
    "Hold Lady Thorn.",
    "Batswarm is lethal outside the safe zone.",
    "Burst after scatter.",
    "[Lady Thorn] Batswarm = safe zone; scatter = synergies.",
    { hardmode = BANNER_HM .. " A Blood Guardian joins the swarm.", challenges = { { name = "Taking Turns", text = "Every player uses the synergy each phase." } } })

-- Stone Garden
addDungeon("Stone Garden", "dlc", { group = "Stonethorn" })
addBoss("Exarch Kraglen", "Stone Garden", "Exarch Kraglen", {"Kraglen"},
    "Exarch with resource-draining rage and a lethal stomp.",
    "INTERRUPT Blood Rage. Avoid the Fault Line stomp (one-shots on Veteran).",
    "Hold Kraglen; interrupt.",
    "Fault Line is lethal.",
    "Interrupt; burn.",
    "[Kraglen] Interrupt Blood Rage; avoid Fault Line.",
    { hardmode = BANNER_HM })

addBoss("Stone Behemoth", "Stone Garden", "Stone Behemoth", {"Behemoth"},
    "Behemoth that needs lightning generator strikes to progress.",
    "Use the Lightning Generator on the boss. Avoid Volatile Gloomspores.",
    "Hold it near the generator.",
    "Spore damage.",
    "Burn between generator strikes.",
    "[Behemoth] Use generator; avoid spores.",
    { hardmode = BANNER_HM })

addBoss("Arkasis the Mad Alchemist", "Stone Garden", "Arkasis the Mad Alchemist", {"Arkasis"},
    "Final alchemist with shock emitters and spore husks.",
    "Dislodge Shock Emitters before they explode. Kill Stone Husks before they release spores.",
    "Hold Arkasis.",
    "Emitter explosions are big.",
    "Emitters first, then husks.",
    "[Arkasis] Dislodge emitters; stop spores.",
    { hardmode = BANNER_HM, challenges = { { name = "Spore Stomper", text = "Prevent spore release." } } })

-- =============================================================================
-- Flames of Ambition
-- =============================================================================

-- Black Drake Villa
addDungeon("Black Drake Villa", "dlc", { group = "Flames of Ambition" })
addBoss("Kinras Ironeye", "Black Drake Villa", "Kinras Ironeye", {"Kinras"},
    "Fighter buffed by blazing salamanders.",
    "Stop the salamanders from buffing him; avoid melee spikes.",
    "Hold Kinras; block.",
    "Melee spikes.",
    "Kill salamanders.",
    "[Kinras] Stop salamander buffs.",
    { hardmode = BANNER_HM, challenges = { { name = "Amphibians Arrested", text = "Salamanders never cast their damage buff." } } })

addBoss("Captain Geminus", "Black Drake Villa", "Captain Geminus", {"Geminus"},
    "Captain with Seismic Tremor ground attacks.",
    "Avoid Seismic Tremor.",
    "Hold Geminus.",
    "Tremor damage.",
    "Burn.",
    "[Geminus] Avoid Seismic Tremor.",
    { hardmode = BANNER_HM, challenges = { { name = "Shake It Up", text = "No one is hit by Seismic Tremor." } } })

addBoss("Pyroturge Encratis", "Black Drake Villa", "Pyroturge Encratis", {"Encratis"},
    "Fire mage with a Firestorm eye.",
    "Avoid the fire; use the geysers to hit the Firestorm eye.",
    "Hold Encratis.",
    "Fire damage environment.",
    "Burn; use geysers.",
    "[Encratis] Avoid fire; geyser the eye.",
    { hardmode = BANNER_HM, challenges = { { name = "Bullseye!", text = "Fire the geyser into the Firestorm eye 5 times." } } })

addBoss("Sentinel Aksalaz", "Black Drake Villa", "Sentinel Aksalaz", {"Aksalaz"},
    "Sentinel with time and ice effects.",
    "Avoid ice attacks.",
    "Hold Aksalaz.",
    "Ice damage.",
    "Burn.",
    "[Aksalaz] Avoid ice attacks.",
    { hardmode = BANNER_HM })
-- VERIFY: Aksalaz mechanics (thin source).

-- The Cauldron
addDungeon("The Cauldron", "dlc", { group = "Flames of Ambition" })
addBoss("Oxblood the Depraved", "The Cauldron", "Oxblood the Depraved", {"Oxblood"},
    "Ogrim healed by Gore Globs.",
    "Kill or block Gore Globs before they heal him; avoid his consume attack.",
    "Hold Oxblood.",
    "Consume attacks.",
    "Kill globs.",
    "[Oxblood] Stop Gore Glob heals.",
    { challenges = { { name = "Glob Security", text = "Defeat without killing any Gore Globs." } } })

addBoss("Taskmaster Viccia", "The Cauldron", "Taskmaster Viccia", {"Viccia"},
    "Xivilai with snares and traps.",
    "Don't trigger the traps; break snares.",
    "Hold Viccia.",
    "Trap damage.",
    "Burn.",
    "[Viccia] Avoid traps.",
    { challenges = { { name = "Can't Catch Me!", text = "No one triggers a trap." } } })

addBoss("Molten Guardian", "The Cauldron", "Molten Guardian", {},
    "Iron atronach with constant Magmatic Eruption.",
    "Avoid eruptions; interrupt when possible.",
    "Hold it.",
    "Eruption ticks.",
    "Burn.",
    "[Molten Guardian] Avoid eruptions.")

addBoss("Baron Zaudrus", "The Cauldron", "Baron Zaudrus", {"Zaudrus"},
    "Final havocrel on a ring arena with ash vents.",
    "Avoid Ash Vent Disintegration.",
    "Hold Zaudrus on the ring.",
    "Ash vent damage.",
    "Burn.",
    "[Zaudrus] Avoid Ash Vent Disintegration.",
    { hardmode = BANNER_HM, challenges = { { name = "Hold It Together", text = "No deaths to Ash Vent Disintegration." } } })
-- VERIFY: the Free Lyranth power-module gauntlet isn't added (unclear if it shows a boss bar).

-- =============================================================================
-- Waking Flame
-- =============================================================================

-- The Dread Cellar
addDungeon("The Dread Cellar", "dlc", { group = "Waking Flame" })
addBoss("Scorion Broodlord", "The Dread Cellar", "Scorion Broodlord", {"Broodlord", "Scorion"},
    "Broodlord with exploding agonymium stones and xivilai adds.",
    "Avoid agonymium stone explosions; kill xivilai adds.",
    "Hold the Broodlord; collect adds.",
    "Explosion bursts.",
    "Kill adds.",
    "[Broodlord] Avoid stone explosions; kill adds.",
    { hardmode = BANNER_HM })

addBoss("Cyronin Artellian", "The Dread Cellar", "Cyronin Artellian", {"Cyronin"},
    "Necromancer with Dread Surge hazards and restless dead.",
    "Avoid Dread Surge; handle the restless dead.",
    "Hold Cyronin; collect dead.",
    "Ground hazard damage.",
    "Cleave adds.",
    "[Cyronin] Avoid Dread Surge; cleave dead.",
    { hardmode = BANNER_HM })

addBoss("Magma Incarnate", "The Dread Cellar", "Magma Incarnate", {},
    "Final magma boss with Unstable Blitz and eternal flames.",
    "Avoid Unstable Blitz; stay out of the eternal flames.",
    "Hold it out of the fire.",
    "Flame area grows.",
    "Burn.",
    "[Magma Incarnate] Avoid Blitz and flames.",
    { hardmode = BANNER_HM })

-- Red Petal Bastion
addDungeon("Red Petal Bastion", "dlc", { group = "Waking Flame" })
addBoss("Rogerain the Sly", "Red Petal Bastion", "Rogerain the Sly", {"Rogerain"},
    "Summoner with arena hazards.",
    "Handle summoned adds; avoid arena hazards.",
    "Hold Rogerain; group adds.",
    "Hazard damage.",
    "Cleave adds.",
    "[Rogerain] Manage summons; avoid hazards.",
    { hardmode = BANNER_HM })

addShared({"Eliam Merick", "Ihudir", "Liramindrel"}, "Red Petal Bastion", "The Artifact Bearers", {"Artifact Bearers"},
    "Three-boss fight with environmental traps.",
    "Avoid traps; focus one bearer at a time.",
    "Hold the bearers.",
    "Combined damage.",
    "Focus targets.",
    "[Bearers] Avoid traps; focus one.",
    { hardmode = BANNER_HM })

addBoss("Prior Thierric Sarazen", "Red Petal Bastion", "Prior Thierric Sarazen", {"Sarazen", "Thierric"},
    "Final prior with duplicates and rockslide rushes.",
    "Avoid rockslide rushes from the duplicates.",
    "Hold the prior.",
    "Rush damage.",
    "Burn.",
    "[Sarazen] Avoid duplicate rushes.",
    { hardmode = BANNER_HM, challenges = { { name = "Stampede Shuffle", text = "Avoid every rockslide rush." } } })

-- =============================================================================
-- Ascending Tide
-- =============================================================================

-- Coral Aerie
addDungeon("Coral Aerie", "dlc", { group = "Ascending Tide" })
addBoss("Maligalig", "Coral Aerie", "Maligalig", {},
    "Yaghra monstrosity with Storm Front and a whirlpool.",
    "Clear Storm Front quickly; avoid the whirlpool pull.",
    "Hold Maligalig.",
    "Storm damage.",
    "Burn.",
    "[Maligalig] Clear Storm Front; avoid whirlpool.",
    { hardmode = BANNER_HM, challenges = { { name = "Pressure Front", text = "Clear Storm Front in under 5 seconds." } } })

addBoss("Sarydil", "Coral Aerie", "Sarydil", {},
    "Altmer rogue with a squad; pillars in the room.",
    "Handle the squad; protect the pillars.",
    "Hold Sarydil; group squad.",
    "Squad damage.",
    "Focus squad, then Sarydil.",
    "[Sarydil] Handle squad; protect pillars.",
    { hardmode = BANNER_HM, challenges = { { name = "Summerset Preservation Society", text = "No pillars break." } } })

addShared({"Varallion", "Iliata", "Mafremare", "Ofallo", "Kargaeda"}, "Coral Aerie", "Varallion", {},
    "Final Ascendant Order leader with four trained gryphons.",
    "Destroy Sea Orbs as they spawn; watch gryphon attacks.",
    "Hold Varallion.",
    "Gryphon damage.",
    "Kill Sea Orbs.",
    "[Varallion] Destroy Sea Orbs.",
    { hardmode = BANNER_HM, challenges = { { name = "Splash Fighter Supreme", text = "Destroy 2+ Sea Orbs within 5 seconds." } } })

-- Shipwright's Regret
addDungeon("Shipwright's Regret", "dlc", { group = "Ascending Tide" })
addBoss("Foreman Bradiggan", "Shipwright's Regret", "Foreman Bradiggan", {"Bradiggan"},
    "Wraith whose ghosts rise from corner gravestones.",
    "Kill the ghost adds from the gravestones.",
    "Hold Bradiggan.",
    "Ghost damage.",
    "Kill ghosts.",
    "[Bradiggan] Kill gravestone ghosts.",
    { hardmode = BANNER_HM })

addBoss("Nazaray", "Shipwright's Regret", "Nazaray", {},
    "Spriggan with Locust Rain and Liquidate.",
    "Avoid Locust Rain and Liquidate.",
    "Hold Nazaray.",
    "Heavy damage.",
    "Burn.",
    "[Nazaray] Avoid Locust Rain / Liquidate.",
    { hardmode = BANNER_HM })

addBoss("Captain Numirril", "Shipwright's Regret", "Captain Numirril", {"Numirril"},
    "Final Maormer captain; Drenched stacks and Bilepools.",
    "Manage Drenched stacks. Bilepools fill the arena: burn him before it's covered.",
    "Hold Numirril out of pools.",
    "Drenched stacks.",
    "DPS check.",
    "[Numirril] Manage Drenched; burn before pools.",
    { hardmode = BANNER_HM })

-- =============================================================================
-- Lost Depths
-- =============================================================================

-- Earthen Root Enclave
addDungeon("Earthen Root Enclave", "dlc", { group = "Lost Depths" })
addBoss("Corruption of Stone", "Earthen Root Enclave", "Corruption of Stone", {},
    "Turns players to stone; stone atronachs each stage.",
    "Don't get petrified; kill the stone atronachs.",
    "Hold the boss.",
    "Petrified players are vulnerable.",
    "Kill atronachs.",
    "[Corruption of Stone] Avoid petrify; kill atronachs.",
    { hardmode = BANNER_HM, challenges = { { name = "Vivified Warrior", text = "No one is turned to stone." } } })

addBoss("Corruption of Root", "Earthen Root Enclave", "Corruption of Root", {},
    "Root Infection spreads if several players are hit at once.",
    "SPREAD OUT so Root Infection doesn't spread.",
    "Hold the boss.",
    "Infection spreads damage.",
    "Spread; burn.",
    "[Corruption of Root] Spread out for Root Infection.",
    { hardmode = BANNER_HM, challenges = { { name = "Contagion Contained", text = "No simultaneous Root Infection hits." } } })

addBoss("Archdruid Devyric", "Earthen Root Enclave", "Archdruid Devyric", {"Devyric"},
    "Final archdruid; Malicious Mauling charges break Earth Pillars.",
    "Avoid his charges; watch the pillars.",
    "Hold Devyric.",
    "Charge damage.",
    "Burn.",
    "[Devyric] Avoid charges.",
    { hardmode = BANNER_HM, challenges = { { name = "Demolition Delegation", text = "He breaks 3+ pillars in one charge at you." } } })

-- Graven Deep
addDungeon("Graven Deep", "dlc", { group = "Lost Depths" })
addBoss("The Euphotic Gatekeeper", "Graven Deep", "The Euphotic Gatekeeper", {"Euphotic Gatekeeper", "Gatekeeper"},
    "Gatekeeper with pangrit pits and leaps from rocks.",
    "Destroy the pangrit pits; avoid leaps.",
    "Hold the Gatekeeper.",
    "Leap damage.",
    "Burn.",
    "[Gatekeeper] Destroy pits; avoid leaps.",
    { hardmode = BANNER_HM })

addBoss("Varzunon", "Graven Deep", "Varzunon", {},
    "Necromancer whose skeleton sacrifices grow into a bone colossus.",
    "Kill skeletal sacrifices before they evolve.",
    "Hold Varzunon.",
    "Colossus damage.",
    "Kill skeletons early.",
    "[Varzunon] Kill sacrifices before they evolve.",
    { hardmode = BANNER_HM })

addBoss("Zelvraak the Unbreathing", "Graven Deep", "Zelvraak the Unbreathing", {"Zelvraak"},
    "Final boss with sea orb rotations and fractured soul adds.",
    "Rotate Sea Orbs between players; kill fractured soul adds.",
    "Hold Zelvraak.",
    "Orb damage.",
    "Kill adds; rotate orbs.",
    "[Zelvraak] Rotate Sea Orbs; kill souls.",
    { hardmode = BANNER_HM, challenges = { { name = "Share and Share Alike", text = "Rotate the Sea Orbs." } } })

-- =============================================================================
-- Scribes of Fate
-- =============================================================================

-- Scrivener's Hall
addDungeon("Scrivener's Hall", "dlc", { group = "Scribes of Fate" })
addBoss("Riftmaster Naqri", "Scrivener's Hall", "Riftmaster Naqri", {"Naqri"},
    "Riftmaster with codex and rift attacks.",
    "Avoid rift AoEs.",
    "Hold Naqri.",
    "Rift damage.",
    "Burn.",
    "[Naqri] Avoid rifts.",
    { hardmode = BANNER_HM })

addBoss("Ozezan the Inferno", "Scrivener's Hall", "Ozezan the Inferno", {"Ozezan"},
    "Fire boss with Firestorm.",
    "Avoid Firestorm.",
    "Hold Ozezan.",
    "Fire damage.",
    "Burn.",
    "[Ozezan] Avoid Firestorm.",
    { hardmode = BANNER_HM, challenges = { { name = "Too Hot to Trot", text = "No one takes Firestorm damage." } } })

addShared({"Valinna", "Lamikhai"}, "Scrivener's Hall", "Valinna & Lamikhai", {},
    "Final fight: Valinna and Lamikhai with immolation traps and summons.",
    "Avoid the immolation traps and web attacks; handle summons.",
    "Hold both.",
    "Trap damage.",
    "Focus targets; clear summons.",
    "[Valinna] Avoid traps; handle summons.",
    { hardmode = BANNER_HM, challenges = { { name = "Unburnt Footwork", text = "Avoid all trap damage." } } })
-- VERIFY: whether Lamikhai is fought separately before Valinna.

-- Bal Sunnar
addDungeon("Bal Sunnar", "dlc", { group = "Scribes of Fate" })
addBoss("Kovan Giryon", "Bal Sunnar", "Kovan Giryon", {"Kovan"},
    "Summons enemies pulled from time; temporal orbs.",
    "Handle the time-pulled adds; avoid temporal orbs.",
    "Hold Kovan; collect adds.",
    "Orb damage.",
    "Cleave adds.",
    "[Kovan] Handle adds; avoid orbs.",
    { hardmode = BANNER_HM })

addBoss("Roksa the Warped", "Bal Sunnar", "Roksa the Warped", {"Roksa"},
    "Optional boss with Darklight Ray.",
    "When Darklight Ray targets you, interrupt it.",
    "Hold Roksa.",
    "Ray damage.",
    "Interrupt rays.",
    "[Roksa] Interrupt Darklight Ray.",
    { hardmode = BANNER_HM, challenges = { { name = "One for Each of You", text = "Each player interrupts their own Darklight Ray." } } })

addBoss("Matriarch Lladi Telvanni", "Bal Sunnar", "Matriarch Lladi Telvanni", {"Lladi", "Matriarch Lladi"},
    "Final matriarch; Infectious Vomit spreads; Time Shards freeze adds.",
    "Don't spread Infectious Vomit to others. Use Time Shards to freeze adds.",
    "Hold Lladi.",
    "Vomit spreads damage.",
    "Freeze adds; burn.",
    "[Lladi] Don't spread vomit; freeze adds.",
    { hardmode = BANNER_HM })

-- =============================================================================
-- Scions of Ithelia
-- =============================================================================

-- Bedlam Veil
addDungeon("Bedlam Veil", "dlc", { group = "Scions of Ithelia" })
addBoss("Shattered Champion", "Bedlam Veil", "Shattered Champion", {"Champion"},
    "Crystal atronach that shatters into glass shards.",
    "Manage the glass fragment adds.",
    "Hold the Champion.",
    "Shard damage.",
    "Kill fragments.",
    "[Champion] Manage glass fragments.",
    { hardmode = BANNER_HM })

addBoss("Darkshard", "Bedlam Veil", "Darkshard", {},
    "Mind terror that enrages over time.",
    "Solve the obelisk puzzles to stun it and clear the enrage.",
    "Hold Darkshard.",
    "Enrage damage ramps.",
    "Burn during stuns.",
    "[Darkshard] Solve obelisks to stun.",
    { hardmode = BANNER_HM })

addBoss("The Blind", "Bedlam Veil", "The Blind", {"Blind"},
    "Final cult leader with siege and glass remnant phases.",
    "Avoid siege hazards; handle glass remnants.",
    "Hold The Blind.",
    "Siege damage.",
    "Burn.",
    "[The Blind] Avoid siege; handle remnants.",
    { hardmode = BANNER_HM })

-- Oathsworn Pit
addDungeon("Oathsworn Pit", "dlc", { group = "Scions of Ithelia" })
addShared({"Packmaster Rethelros", "Malthil"}, "Oathsworn Pit", "Packmaster Rethelros", {"Rethelros"},
    "Packmaster and his wolf empower each other when close.",
    "Keep the packmaster and wolf SEPARATED. Destroy the Protective Totem.",
    "Pull them apart.",
    "Empowered damage.",
    "Kill the totem.",
    "[Rethelros] Separate boss and wolf; kill totem.",
    { hardmode = BANNER_HM })

addShared({"Anthelmir", "Anthelmir's Construct"}, "Oathsworn Pit", "Anthelmir", {},
    "Boss and construct; pitch barrels in the arena.",
    "Detonate Kindle Pitch Barrels on the construct; avoid its axe.",
    "Hold the construct.",
    "Axe damage.",
    "Use barrels.",
    "[Anthelmir] Barrels on construct; avoid axe.",
    { hardmode = BANNER_HM })

addShared({"Aradros the Awakened", "Faenalir", "Maerolor", "Nilborwen"}, "Oathsworn Pit", "Aradros the Awakened", {"Aradros"},
    "Final boss with elemental elites.",
    "Handle the elemental adds; avoid fire attacks.",
    "Hold Aradros.",
    "Fire damage.",
    "Kill elites.",
    "[Aradros] Handle elites; avoid fire.",
    { hardmode = BANNER_HM .. " All three elites appear at once." })

-- =============================================================================
-- Fallen Banners
-- =============================================================================

-- Exiled Redoubt
addDungeon("Exiled Redoubt", "dlc", { group = "Fallen Banners" })
addBoss("Executioner Jerensi", "Exiled Redoubt", "Executioner Jerensi", {"Jerensi"},
    "Executioner who places spike traps.",
    "Avoid the spike traps.",
    "Hold Jerensi.",
    "Trap damage.",
    "Burn.",
    "[Jerensi] Avoid spike traps.",
    { hardmode = BANNER_HM })

addBoss("Prime Sorcerer Vandorallen", "Exiled Redoubt", "Prime Sorcerer Vandorallen", {"Vandorallen"},
    "Sorcerer with iron atronach spiders and Storm Spear.",
    "Kill spiders; avoid Storm Spear.",
    "Hold Vandorallen.",
    "Storm damage.",
    "Kill spiders.",
    "[Vandorallen] Kill spiders; avoid Storm Spear.",
    { hardmode = BANNER_HM })

addBoss("Squall of Retribution", "Exiled Redoubt", "Squall of Retribution", {"Squall"},
    "Final elemental with fire/ice/shock orbs.",
    "Handle elemental orbs; watch phase changes.",
    "Hold the Squall.",
    "Elemental damage.",
    "Burn.",
    "[Squall] Handle elemental orbs.",
    { hardmode = BANNER_HM })

-- Lep Seclusa
addDungeon("Lep Seclusa", "dlc", { group = "Fallen Banners" })
addBoss("Garvin the Tracker", "Lep Seclusa", "Garvin the Tracker", {"Garvin"},
    "Tracker with traps and dunerippers.",
    "Avoid traps; kill the Monstrous Dunerippers.",
    "Hold Garvin; collect dunerippers.",
    "Duneripper damage.",
    "Kill dunerippers.",
    "[Garvin] Avoid traps; kill dunerippers.",
    { hardmode = BANNER_HM })

addBoss("Noriwen", "Lep Seclusa", "Noriwen", {},
    "Fights alongside gryphon bombers and Alcunar on a platform.",
    "Avoid Fire Line Blasts from gryphon bombers.",
    "Hold Noriwen.",
    "Fire line damage.",
    "Burn.",
    "[Noriwen] Avoid fire lines.",
    { hardmode = BANNER_HM })

addBoss("Orpheon the Tactician", "Lep Seclusa", "Orpheon the Tactician", {"Orpheon"},
    "Final tactician with darkness phases and Arcane Void.",
    "BLOCK Arcane Void. Handle enshrouding dark phases.",
    "Hold Orpheon; block.",
    "Void damage.",
    "Burn.",
    "[Orpheon] Block Arcane Void.",
    { hardmode = BANNER_HM })

-- =============================================================================
-- Feast of Shadows
-- =============================================================================

-- Black Gem Foundry
addDungeon("Black Gem Foundry", "dlc", { group = "Feast of Shadows" })
addBoss("Quarrymaster Saldezaar", "Black Gem Foundry", "Quarrymaster Saldezaar", {"Saldezaar"},
    "Quarrymaster with falling debris and soul gem clusters.",
    "Avoid falling debris; destroy soul gem clusters.",
    "Hold Saldezaar.",
    "Debris damage.",
    "Break clusters.",
    "[Saldezaar] Avoid debris; break clusters.",
    { hardmode = BANNER_HM })

addBoss("Black Gem Monstrosity", "Black Gem Foundry", "Black Gem Monstrosity", {"Monstrosity"},
    "Monstrosity with Soul Focus and gem shards.",
    "Avoid Soul Focus; kill Black Gem Shards.",
    "Hold it.",
    "Soul Focus damage.",
    "Kill shards.",
    "[Monstrosity] Avoid Soul Focus; kill shards.",
    { hardmode = BANNER_HM })

addBoss("High Soulbinder Vykand", "Black Gem Foundry", "High Soulbinder Vykand", {"Vykand"},
    "Final soulbinder; refracted souls grow into dangerous essences.",
    "Deal with refracted souls before they metastasize. Mind your positioning.",
    "Hold Vykand.",
    "Soul damage.",
    "Kill souls early.",
    "[Vykand] Kill refracted souls early.",
    { hardmode = BANNER_HM })

-- Naj-Caldeesh
addDungeon("Naj-Caldeesh", "dlc", { group = "Feast of Shadows" })
addBoss("Poxito", "Naj-Caldeesh", "Poxito", {},
    "Bone-armored boss with possessing specters.",
    "Strip Bone Armor with the saw blade; avoid specter possession.",
    "Hold Poxito.",
    "Possessed players.",
    "Burn when armor is down.",
    "[Poxito] Saw blade the armor; avoid specters.",
    { hardmode = BANNER_HM, challenges = { { name = "Total Self-Control", text = "No one is possessed." } } })

addBoss("Voskrona Stonehulk", "Naj-Caldeesh", "Voskrona Stonehulk", {"Stonehulk", "Voskrona"},
    "Stonehulk with a Fatal Pool, guardians and flamerocks.",
    "Avoid the Fatal Pool; kill Voskrona Guardians and Flamerocks.",
    "Keep it out of the Fatal Pool.",
    "Add damage.",
    "Kill guardians and flamerocks.",
    "[Stonehulk] Avoid pool; kill adds.",
    { hardmode = BANNER_HM, challenges = { { name = "Parched Stonework", text = "Keep the boss out of the Fatal Pool." } } })
-- VERIFY: exact boss bar name.

addShared({"Talen-Lah", "Bar-Sakka"}, "Naj-Caldeesh", "Talen-Lah & Bar-Sakka", {"Talen Lah", "Bar Sakka"},
    "Final co-fight; Bone Rot and boulder strikes.",
    "Manage Bone Rot; avoid Bar-Sakka's boulders.",
    "Hold both.",
    "Bone Rot damage.",
    "Burn.",
    "[Talen-Lah] Manage Bone Rot; avoid boulders.",
    { hardmode = BANNER_HM })
