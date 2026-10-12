-- Solo arenas, by round. Each card pops when the player enters the round's
-- area (subzone name, confirmed in-game for Maelstrom round 1).

local addDungeon = PullCardData.addDungeon
local addRound = PullCardData.addRound

-- Maelstrom Arena
addDungeon("Maelstrom Arena", "solo", { group = "Orsinium", zoneId = 677 })
PullCardData.setNotes("Maelstrom Arena",
    "SIGILS: Each wave spawns new sigils. Walk over one to use it:\n"
        .. "- Power: more damage\n"
        .. "- Defense: take less damage\n"
        .. "- Healing: heals you\n"
        .. "- Haste: move faster\n"
        .. "They're your lifeline as a solo player. Grab Healing or Defense when you're in trouble, "
        .. "and save Power for minibosses and the round boss instead of trash.\n\n"
        .. "ROUNDS: Nine rounds, each ending in a boss, and each harder than the last. "
        .. "Kill priority targets (healers, ranged, summoners) before tunneling big enemies.")

-- =========================================================
-- ROUND 1 - VALE OF THE SURREAL
-- =========================================================
addRound("Maelstrom Arena", "Vale of the Surreal", "Round 1: Vale of the Surreal",
    "Basic Daedric waves ending with Maxus the Many. This round teaches movement and target priority.",
    "PRIORITY: Kill ranged enemies first. Avoid the roaming whirlwind because it snares you and adds a DoT. "
        .. "\n\nMAXUS: Stay out of the large black ground AoE and the pentagram root. Kill his copies immediately; "
        .. "if they reach him they merge back into Maxus and heal him. Keep moving when he teleports.",
    "[R1] Ranged first. Avoid whirlwind/black AoE. Kill Maxus copies before they heal him.")

-- =========================================================
-- ROUND 2 - SEHT'S BALCONY
-- =========================================================
addRound("Maelstrom Arena", "Seht's Balcony", "Round 2: Seht's Balcony",
    "Dwemer arena with moving blade traps and three Centurion Champions.",
    "BLADES: Every blade hit applies a stacking bleed. Avoid the blade tracks; use the side switches to stop them "
        .. "for roughly 10 seconds if stacks get dangerous. Never stand in the electrified center. "
        .. "\n\nPRIORITY: Dwarven Spheres first because their shock AoE can kill you; kill spiders before they enter "
        .. "their blue charge state and empower other enemies. "
        .. "\n\nBOSS: The three Centurions rotate between active and shielded states. Damage the active one, sidestep steam, "
        .. "avoid ground shots, and block/dodge the spinning melee attack.",
    "[R2] Avoid blades; switches clear bleed pressure. Spheres first. Only burn the active Centurion.")

-- =========================================================
-- ROUND 3 - DROME OF TOXIC SHOCK
-- =========================================================
addRound("Maelstrom Arena", "Drome of Toxic Shock", "Round 3: Drome of Toxic Shock",
    "Three islands surrounded by periodically electrified water, ending with the Lamia Queen.",
    "PRIORITY: Kill Stranglers whenever they appear. Their stacking snare makes the lightning and electrified water lethal. "
        .. "Stay on islands whenever possible and cross the water quickly. Avoid Lamia frontal screams. "
        .. "Interrupt snakes when they curl up to heal. "
        .. "\n\nBOSS: Lamia Queen spawns adds at about 75%, 50%, and 25%. Kill the adds instead of blindly tunneling her. "
        .. "Keep moving out of lightning strikes and do not fight in the water.",
    "[R3] STRANGLERS FIRST. Stay on islands. Boss adds at 75/50/25; kill them before continuing burn.")

-- =========================================================
-- ROUND 4 - SEHT'S FLYWHEEL
-- =========================================================
addRound("Maelstrom Arena", "Seht's Flywheel", "Round 4: Seht's Flywheel",
    "Dwemer and scavenger waves ending with the Control Guardian.",
    "PRIORITY: Kill healer mages, Dwarven Spheres, and outer-ring Sentries before they establish shock fields. "
        .. "Do not let multiple Sentries shield themselves at once. "
        .. "\n\nBOSS - LIGHTNING: Stay INSIDE the green safe circle under the Control Guardian and move with it. "
        .. "\n\nBOSS - FIRE: Get away from the Guardian while it stops and floods the area around itself with fire; "
        .. "use this time to clear adds. Return underneath it before lightning starts again.",
    "[R4] Healers/Spheres/Sentries first. Guardian: UNDER it for lightning; AWAY from it for fire.")

-- =========================================================
-- ROUND 5 - RINK OF FROZEN BLOOD
-- =========================================================
addRound("Maelstrom Arena", "Rink of Frozen Blood", "Round 5: Rink of Frozen Blood",
    "Three ice platforms, constant platform-breaking trolls, and Matriarch Runa. This boss is mechanic/health gated.",
    "TROLLS ARE TOP PRIORITY: A troll will run to a platform and start smashing it. Kill or interrupt it immediately. "
        .. "Do not allow trolls to remove platforms early. Stay out of the freezing water except for quick crossings. "
        .. "\n\nRUNA IS NOT A BLIND BURN: adds spawn around 90%, 60%, and 30%. She destroys platforms at roughly 75% and 45%. "
        .. "STOP DPS and clear adds/trolls before pushing each health threshold. When she turns red and moves to the center "
        .. "of a platform, LEAVE THAT PLATFORM -- she is about to destroy it. "
        .. "\n\nFINAL PLATFORM: once she reaches about 30%, clear/handle the add wave, then burn hard. You are now on a timer "
        .. "before she destroys the last platform. Never ignore a troll during the execute.",
    "[R5] TROLLS FIRST. Do NOT overburn Runa. Adds 90/60/30; platforms break 75/45. Last platform = burn.")

-- =========================================================
-- ROUND 6 - SPIRAL SHADOWS
-- =========================================================
addRound("Maelstrom Arena", "Spiral Shadows", "Round 6: Spiral Shadows",
    "Spider arena built around five obelisks. Managing the pillars correctly is more important than raw DPS.",
    "OBELISKS: Keep at least TWO uncovered. Kill a Hoarvor beside a webbed obelisk to clear it, or use its poison-grenade "
        .. "synergy on a webbed pillar. WEBSPINNERS ARE TOP PRIORITY because they re-web uncovered obelisks. "
        .. "When ALL FIVE obelisks are uncovered together they glow gold and STUN every enemy for about 10 seconds. "
        .. "Try to enter dangerous waves/boss with four uncovered so the next Hoarvor triggers the stun. "
        .. "\n\nSPIDER SWARM: Do NOT fight it. Run to the currently glowing GOLD obelisk; the swarm dies in its light. "
        .. "\n\nLIGHTNING: Keep moving when Call Lightning targets you; standing still gets you killed. "
        .. "\n\nPRIORITY ADDS: Webspinners first, then Spider Daedra/Enervator-type ranged threats. Spider Daedra spit stacks a severe snare, "
        .. "which can prevent you reaching the golden pillar or escaping lightning. "
        .. "\n\nBOSS: Champion of Atrocity continually enrages. The five-obelisk stun RESETS the enrage. Save the stun for the boss "
        .. "or a dangerous miniboss wave instead of wasting it on trash.",
    "[R6] Webspinners FIRST. Keep 2+ pillars clear. GOLD pillar = spider safe zone. ALL 5 clear = 10s stun + boss enrage reset.")

-- =========================================================
-- ROUND 7 - VAULT OF UMBRAGE
-- =========================================================
addRound("Maelstrom Arena", "Vault of Umbrage", "Round 7: Vault of Umbrage",
    "Poison flowers, lethal ranged enemies, Venomcallers, and the Argonian Behemoth.",
    "VENOMCALLER = ABSOLUTE FIRST PRIORITY. When one appears your screen turns green and it begins detonating every poison flower "
        .. "in the arena repeatedly. Drop what you are doing and kill it. "
        .. "\n\nFLOWERS: Stay away from them. If poisoned, immediately cleanse in a glowing pool. Pools are limited, so do not waste them. "
        .. "\n\nARCHERS / VENOMSHOTS: High priority. Their Focused Aim can one-shot you -- interrupt, block, or dodge when you glow red. "
        .. "Multiple archers spawning together can also delete you with simultaneous shots. "
        .. "\n\nBEHEMOTH: About 20 seconds into the fight, TWO Argonian Minders spawn. KILL ONE MINDER and KEEP THE OTHER ALIVE. "
        .. "The boss then begins Enraged Scream. Stand inside the surviving Minder's protective bubble for the entire scream. "
        .. "DO NOT INTERRUPT THE SCREAM unless the situation is already lost -- interrupting leaves the boss enraged. "
        .. "After the scream finishes, kill the surviving Minder. Repeat if another pair spawns. "
        .. "Be careful with AoE damage: accidentally killing both Minders means no safe zone and usually death.",
    "[R7] VENOMCALLER FIRST. Archers next. Poison = cleanse. Boss: kill ONE Minder, hide with the OTHER during scream. DO NOT interrupt.")

-- =========================================================
-- ROUND 8 - IGNEOUS CISTERN
-- =========================================================
addRound("Maelstrom Arena", "Igneous Cistern", "Round 8: Igneous Cistern",
    "Fire-heavy arena where Warding Stones make dangerous enemies and Valkyn Tephra immune.",
    "WARDING STONES: If an enemy has the blue immunity glow, stop attacking it and BREAK THE ACTIVE STONE first. "
        .. "\n\nLAVA: Keep moving out of eruption circles; getting hit stuns you. "
        .. "\n\nPRIORITY: Kill fire casters/healers and dangerous miniboss adds before tunneling larger targets. "
        .. "\n\nFLAME KNIGHT: Do not fight her inside her Standard. Block/dodge the chain and drag her out; she is stronger inside it. "
        .. "\n\nBOSS: All THREE Warding Stones activate. Break all three to stun Valkyn Tephra and make her vulnerable. "
        .. "Burn during the stun. The stones eventually reactivate, so repeat. Kill spawning Kyngald fire casters while waiting "
        .. "for the next vulnerability window.",
    "[R8] Blue immune enemy = BREAK STONE. Fire adds first. Boss: destroy all 3 stones -> stun -> BURN -> repeat.")

-- =========================================================
-- ROUND 9 - THEATER OF DESPAIR
-- =========================================================
addRound("Maelstrom Arena", "Theater of Despair", "Round 9: Theater of Despair",
    "Final arena. Priority targeting matters more here than almost anywhere else in Maelstrom.",
    "GOLDEN GHOSTS: Collect them yourself. Three gives Spectral Explosion, an arena-wide stun. Do NOT let enemies collect them. "
        .. "\n\nCREMATORIAL GUARDS: HIGH PRIORITY. Circle around them while burning them so their fire breath misses. "
        .. "\n\nRANGED / ARCHERS: Kill quickly when they spawn, especially when another dangerous enemy is already active. "
        .. "\n\nNARKYNAZ SUMMONERS: ABSOLUTE PRIORITY. They walk toward the center and channel a ritual. Kill them before they complete it "
        .. "or they summon a Bone Colossus. Ritual progress is cumulative between summoners. "
        .. "\n\nVORIAK PHASE 1: Dodge/block the large skull. INTERRUPT Necrotic Swarm immediately. Kill healer/Crematorial Guard instead "
        .. "of tunneling the boss. At about 70% he ports upstairs. "
        .. "\n\nPORTAL: Kill the glowing Clannfear ON the glowing platform to activate the portal. "
        .. "\n\nUPSTAIRS: Destroy all three crystals. Dodge/block skulls. Stay behind the moving wall when Voriak charges the knockback blast. "
        .. "Soul Churn damage increases the longer you stay upstairs; if overwhelmed, drop down and reset rather than dying. "
        .. "\n\nFINAL PHASE: Interrupt Necrotic Swarm, kill Narkynaz before they reach center, and COLLECT EVERY GOLDEN GHOST. "
        .. "When the third ghost gives Spectral Explosion, use it to stun Voriak and the Crematorial Guard, then execute the boss.",
    "[R9] Guards/ARCHERS dangerous. NARKYNAZ = kill NOW. 3 gold ghosts = stun. Voriak: interrupt -> Clannfear portal -> 3 crystals/wall -> ghosts + execute.",
    {
        challenges = {
            { name = "Maelstrom Arena: Perfect Run", text = "Complete Veteran in one attempt without dying or leaving." },
        },
    })

-- =========================================================
-- VATESHRAN HOLLOWS
-- =========================================================
-- Menu: Arena Overview, then each wing card with its bosses listed under it.
-- Wing cards pop on entering the wing; boss cards pop when the boss appears.
-- Sources: UESP, xynodegaming.com "All About Mechanics" guide; role orders from in-game experience.
-- VERIFY: wing area names (check Location Info in each wing).
local addBoss = PullCardData.addBoss
local addShared = PullCardData.addShared
local VH = "Vateshran Hollows"

addDungeon(VH, "solo", { group = "Markarth" })
PullCardData.dungeons[VH].listLabel = "Wings and bosses:"
PullCardData.setNotes(VH,
    "WINGS: Green = Hunter's Grotto, Red = The Brimstone Den, Blue = The Wounding. Do them in any order; "
        .. "enemies get stronger with each wing you finish. Champion's Circle (Maebroogha) opens after all three.\n\n"
        .. "WING ORDER MATTERS: it decides which secret bosses and resource bonuses you get. See 'Wing Order & Bonuses' below before you start.\n\n"
        .. "CHECKPOINTS: Beating a boss sets your respawn point in that wing.\n\n"
        .. "SIGILS: Sigils sit right in the middle of the paths and walking through one uses it. They help, but if you want "
        .. "'Strength from Within' (no sigils in combat) or 'The Vateshran's Chosen' (no sigils at all, under 45 min, no deaths), walk AROUND them.")

PullCardData.setIntro(VH,
    "- PICK YOUR WING ORDER NOW: it decides your bonuses. Magicka DPS: Green > Blue > Red. Stamina DPS: Blue > Red > Green. Tank: Red > Green > Blue.\n"
        .. "- Each wing hides a secret boss and an Essence, reachable with a tool from a wing done earlier. Look for hidden side paths and glowing Remnants (purple = Magicka).\n"
        .. "- The Wounding: after Zakuryn, Watchers on the portal path send you back to the start if they see you.\n"
        .. "- Going for 'Strength from Within'? Walk AROUND the sigils on the paths.")

PullCardData.addGuide(VH, "Wing Order & Bonuses",
    "HOW THE BONUSES WORK: Finishing a wing gives you a travel tool. Each tool opens hidden paths in ONE other wing, "
        .. "leading to that wing's secret boss and its Essence (a big max-resource bonus):\n"
        .. "- Green gives the Grappling Bow -> opens Blue's secrets: Xobutar + Essence of Mysticism (Magicka)\n"
        .. "- Red gives Brimstone Orbs -> opens Green's secrets: Leptfire Keeper + Essence of Endurance (Stamina)\n"
        .. "- Blue gives Wounding Portals -> opens Red's secrets: Mynar Metron + Essence of Fortitude (Health)\n"
        .. "So a wing's secrets only open if you did the right wing BEFORE it. Any order gets you two Essences at most.\n\n"
        .. "WHICH ORDER FOR YOUR ROLE:\n"
        .. "- Magicka DPS: Green -> Blue -> Red = Magicka + Health\n"
        .. "- Stamina DPS: Blue -> Red -> Green = Stamina + Health\n"
        .. "- Tank: Red -> Green -> Blue = Magicka + Stamina\n"
        .. "DPS want their main resource plus Health; they don't need the opposite resource. "
        .. "Tanks usually already have plenty of health and resistances, so they take both resources instead.\n\n"
        .. "ESSENCES: +5000 max to that resource, plus +1000 for each of its 5 Remnants (up to +10000). "
        .. "Remnants are glowing orbs tucked into hidden side areas (the Magicka ones are purple). "
        .. "Look off the main path once you have the right tool.\n\n"
        .. "SECRET BOSS REWARDS: Leptfire Keeper: grappling interrupts nearby enemies. Mynar Metron: heavy attacking fire orbs deals AoE damage. "
        .. "Xobutar: he follows you through portals and fights.")

-- Hunter's Grotto (Green) ---------------------------------------------------
addRound(VH, "Hunter's Grotto", "Hunter's Grotto (Green)",
    "Hircine's wing: Shade of the Grove, secret Leptfire Keeper, then Rahdgarak.",
    "SECRETS HERE: Leptfire Keeper, the Essence of Endurance (+Stamina) and its 5 Remnants are behind lava paths. "
        .. "You need Brimstone Orbs, so do The Brimstone Den (Red) before this wing.\n\n"
        .. "Interrupt Reach Channelers and spriggans; their channels are what kill you here.",
    "[Grotto] Interrupt channelers/spriggans. Leptfire needs Red done first.",
    { menuLabel = "HUNTER'S GROTTO (Green)" })

addBoss("Shade of the Grove", VH, "Shade of the Grove", {},
    "Three enemies sharing one health bar.",
    "Hit only the target that isn't immune. Interrupt the spriggan beam curse. Block or dodge heavy attacks and the cone spray; "
        .. "move out of the spreading stomp. Kill the wolves.\n\nEXECUTE: all three wake up at once.",
    nil, nil, nil,
    "[Shade] Hit the non-immune one; interrupt spriggan beam; all 3 wake at execute.",
    { menuLabel = "- Shade of the Grove" })

addBoss("Leptfire Keeper", VH, "Leptfire Keeper (secret)", {"Leptfire"},
    "Secret boss that jumps between platforms. Needs Brimstone Orbs (Red wing done first).",
    "Follow him with the grapple. Keep heals up through the flame spin. Block the spit/cleave cone to avoid knockback. "
        .. "Stay out of fire spray AoEs; block heavy attacks.\n\nREWARD: your grapples interrupt nearby enemies.",
    nil, nil, nil,
    "[Leptfire] Grapple after him; block cone; heal through spin.",
    { menuLabel = "- Leptfire Keeper (secret)" })

addBoss("Rahdgarak", VH, "Rahdgarak", {},
    "Wing boss on fire and frost platforms.",
    "Fight him on the platform OPPOSITE his current element buff. Interrupt all four platform mages. Block or dodge heavies; "
        .. "move out of his charge; block when he lands from his jump slam. Kill adds. Keep resources for CC breaks.",
    nil, nil, nil,
    "[Rahdgarak] Opposite-element platform; interrupt all 4 mages; block the slam.",
    { menuLabel = "- Rahdgarak" })

-- The Brimstone Den (Red) ---------------------------------------------------
addRound(VH, "The Brimstone Den", "The Brimstone Den (Red)",
    "Mehrunes Dagon's wing: Magma Queen, secret Mynar Metron, then The Pyrelord.",
    "SECRETS HERE: Mynar Metron, the Essence of Fortitude (+Health) and its 5 Remnants are reached through Wounding Portals. "
        .. "Do The Wounding (Blue) before this wing.\n\n"
        .. "Grab Brimstone Orbs for fire immunity before crossing lava.",
    "[Brimstone] Orbs before lava. Mynar needs Blue done first.",
    { menuLabel = "THE BRIMSTONE DEN (Red)" })

addBoss("Magma Queen", VH, "Magma Queen", {},
    "Mostly stationary boss; the adds are the real fight.",
    "Kill scamp portal adds first (7+ can spawn). Kill Iron Atronachs, then use their rocks on the geysers to stun the boss. "
        .. "Avoid fire lines. At low health fire walls appear: clear adds first.",
    nil, nil, nil,
    "[Magma Queen] Scamps first; atronach rocks -> geyser stun.",
    { menuLabel = "- Magma Queen" })

addBoss("Mynar Metron", VH, "Mynar Metron (secret)", {"Mynar"},
    "Secret boss in a lava arena. Needs Wounding Portals (Blue wing done first).",
    "Grab the firewalking buff to cross lava (it's on a timer). Dodge the random meteors from his lava spit channel; "
        .. "find the gaps in burst lava AoEs.\n\nREWARD: heavy attacking fire orbs deals AoE damage.",
    nil, nil, nil,
    "[Mynar] Firewalking buff for lava; dodge meteors.",
    { menuLabel = "- Mynar Metron (secret)" })

addBoss("The Pyrelord", VH, "The Pyrelord", {"Pyrelord"},
    "Repeating cycle: breath, spin, breath, floor stab.",
    "Get behind him for the frontal breath. Follow or stay ranged through the spin. Grab the protection orb when the floor turns to lava. "
        .. "Put out the three corner fires or he enrages. Colossi spawn around 70% and 30%: kill them.",
    nil, nil, nil,
    "[Pyrelord] Behind for breath; orb for lava floor; put out 3 corner fires.",
    { menuLabel = "- The Pyrelord" })

-- The Wounding (Blue) -------------------------------------------------------
addRound(VH, "The Wounding", "The Wounding (Blue)",
    "Molag Bal's wing: Zakuryn and the Flesh Abomination, secret Xobutar, then Iozuzzunth.",
    "SECRETS HERE: Xobutar, the Essence of Mysticism (+Magicka) and its 5 purple Remnants are up grapple points. "
        .. "You need the Grappling Bow, so do Hunter's Grotto (Green) before this wing.\n\n"
        .. "WATCHERS: After the Zakuryn & Flesh Abomination fight, you continue through a Wounding Portal path. "
        .. "Watchers patrol it, and if one spots you you're sent back to the start of the path. "
        .. "Wait out of their sight and slip past when they look away. You only have about 20 seconds to reach the end, so don't dawdle either.\n\n"
        .. "Wounding Portals take you upstairs on a timer: do the job and get out.",
    "[Wounding] Portals are timed. Xobutar needs Green done first.",
    { menuLabel = "THE WOUNDING (Blue)" })

addShared({"Zakuryn the Sculptor", "Flesh Abomination"}, VH, "Zakuryn & Flesh Abomination", {"Zakuryn"},
    "Two bosses: balance damage between them.",
    "If one dies first, the other enrages and heals past 50%. Interrupt Zakuryn's staff channel. "
        .. "When Zakuryn bubbles himself, stack them so the Abomination's ground smash breaks the shield and stuns both, then get out of the smash. "
        .. "Kill banekin; avoid lightning splashes and ground AoEs; restack after teleports.",
    nil, nil, nil,
    "[Zakuryn] Even damage on both; smash breaks his bubble; interrupt staff.",
    { menuLabel = "- Zakuryn & Flesh Abomination" })

addBoss("Xobutar of His Deep Graces", VH, "Xobutar (secret)", {"Xobutar"},
    "Secret boss with two gates of spirit adds. Needs the Grappling Bow (Green wing done first).",
    "Gate 1: keep moving off the lich crystals. Gate 2: kill the totems fast or he heals. "
        .. "After his pull-in, get out before the spreading AoE.\n\nREWARD: he follows you through portals and helps fight.",
    nil, nil, nil,
    "[Xobutar] Keep moving; kill totems; escape after the pull.",
    { menuLabel = "- Xobutar (secret)" })

addBoss("Iozuzzunth", VH, "Iozuzzunth", {},
    "Stationary boss: ignore him and handle eyes and Watchers.",
    "Kill each spawning eye first (it raises your damage taken); aim his fire wave at the eye. "
        .. "When Watchers appear, take the portal upstairs and kill them in time, dodging their spins. Avoid meteor AoEs.",
    nil, nil, nil,
    "[Iozuzzunth] Eyes first; portal up for Watchers.",
    { menuLabel = "- Iozuzzunth" })

-- Champion's Circle (final) -------------------------------------------------
addRound(VH, "Champion's Circle", "Champion's Circle (Maebroogha)",
    "Final arena after all three wings: Maebroogha the Void Lich. The adds are the fight, not the boss.",
    "PHASE 1: Kill void archers/mages fast. In her 'yoga pose' find the gaps in the circular AoEs. Step out of the frontal triangle; move when she teleports to you.\n\n"
        .. "SHADE WALL: A ring of linked shades walks to the center. Focus ONE shade and kill it to break out.\n\n"
        .. "AT 10%: Huge explosion. Grapple to one of three points (each usable once) to enter a void portal and fight a mini Zakuryn, Rahdgarak or Pyrelord. "
        .. "She heals meanwhile, and you come back with that portal's mechanic added. Repeat until all three portals are done.\n\n"
        .. "SHADE COLOSSI: Respawn at 90/70/50/30%; kill them.\n\n"
        .. "FINAL PHASE: No enrage; clear adds and finish her.",
    "[Maebroogha] Adds first; kill ONE shade in the wall; at 10% grapple into a portal x3.",
    {
        menuLabel = "CHAMPION'S CIRCLE (Maebroogha)",
        challenges = {
            { name = "Unbroken Vigor", text = "Complete Veteran without dying." },
            { name = "Strength from Within", text = "No sigil use during combat." },
        },
    })
