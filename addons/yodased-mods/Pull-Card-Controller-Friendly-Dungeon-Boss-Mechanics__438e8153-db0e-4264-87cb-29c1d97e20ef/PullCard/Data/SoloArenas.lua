-- Solo arenas, by round. Each card pops when the player enters the round's
-- area (subzone name, confirmed in-game for Maelstrom round 1).

local addDungeon = PullCardData.addDungeon
local addRound = PullCardData.addRound

-- Maelstrom Arena
addDungeon("Maelstrom Arena", "solo", { group = "Orsinium", zoneId = 677 })

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