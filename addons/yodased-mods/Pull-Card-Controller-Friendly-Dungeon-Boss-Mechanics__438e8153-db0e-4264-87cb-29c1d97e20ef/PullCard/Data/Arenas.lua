-- 4-player group arenas, by round boss.
-- Solo arenas (Maelstrom, Vateshran Hollows) are NOT here: they need per-round
-- cards triggered by the round, not by a boss frame (not built yet).

local addDungeon = PullCardData.addDungeon
local addBoss = PullCardData.addBoss
local addShared = PullCardData.addShared

-- Dragonstar Arena
addDungeon("Dragonstar Arena", "arena", { group = "Imperial City" })
addBoss("Champion Marcauld", "Dragonstar Arena", "Round 1: Champion Marcauld", {"Marcauld"},
    "Fighters Guild round with spike traps.",
    "Stay off the spike traps. On Veteran, kill gladiators before their healing rings buff the enemies.",
    "Pull enemies out of healing rings.",
    "Trap damage ticks.",
    "Gladiators first on Veteran.",
    "[R1 Marcauld] Avoid spikes; pull out of heal rings.")

addShared({"Yavni Frost-Skin", "Katti Ice-Turner"}, "Dragonstar Arena", "Round 2: Yavni & Katti", {"Yavni", "Katti"},
    "The Frozen Ring: Biting Cold hurts anyone away from a fire.",
    "STAY NEAR A LIT FIRE. Keep the fires lit.",
    "Hold both bosses next to a fire.",
    "Biting Cold ramps fast away from fires.",
    "Fight near the fire.",
    "[R2 Frozen Ring] Stay by lit fires.")

addShared({"Nak'tah", "Shilia"}, "Dragonstar Arena", "Round 3: Nak'tah & Shilia", {"Naktah"},
    "The Marsh: poison clouds spawn and grow.",
    "Move away from the poison clouds; they grow over time, so finish fast.",
    "Drag enemies out of the clouds.",
    "Cloud damage escalates.",
    "Kill fast before clouds cover the arena.",
    "[R3 Marsh] Avoid growing poison clouds.")

addBoss("Earthen Heart Knight", "Dragonstar Arena", "Round 4: Earthen Heart Knight", {},
    "The Slave Pit: Dres Enslavers chain players.",
    "Interrupt the blue chain. Kill Enslavers.",
    "Hold the Knight.",
    "Chained players take extra damage.",
    "Enslavers first.",
    "[R4 Slave Pit] Interrupt chains; kill Enslavers.")

addBoss("Anal'a Tu'wha", "Dragonstar Arena", "Round 5: Anal'a Tu'wha", {"Anala Tuwha", "Anal'a"},
    "The Celestial Ring: Celestial Blast marks players.",
    "When marked, get to the highlighted constellation platform within 10 seconds or die.",
    "Hold the boss in the middle.",
    "Celestial Blast is lethal off-platform.",
    "Burn between blasts.",
    "[R5 Celestial] Marked = run to highlighted platform.")

addBoss("Pishna Longshot", "Dragonstar Arena", "Round 6: Pishna Longshot", {"Pishna"},
    "The Grove: corpses leave stacking damage zones; archers drain magicka.",
    "Don't stand on corpse zones. Kill enemies away from where the group fights.",
    "Move the fight off corpse zones.",
    "Stacks grow quickly.",
    "Kill archers.",
    "[R6 Grove] Stay off corpse zones; kill archers.")

addShared({"Shadow Knight", "Dark Mage"}, "Dragonstar Arena", "Round 7: Shadow Knight & Dark Mage", {},
    "The Circle of Rituals: daedric sacrifices turn into unkillable summons.",
    "Kill the Daedric Sacrifices before they transform. INTERRUPT the Dark Mage's full heal.",
    "Hold the Knight.",
    "Unkillable summons pile up if missed.",
    "Sacrifices first; interrupt heals.",
    "[R7 Rituals] Kill sacrifices; interrupt Mage heal.")

addBoss("Mavus Talnarith", "Dragonstar Arena", "Round 8: Mavus Talnarith", {"Mavus"},
    "The Steamworks: ice centurions freeze, fire centurions spin.",
    "Break free from freezes; stay away from fire centurion spins.",
    "Hold centurions away from the group.",
    "Spin AoEs are big.",
    "Kill centurions.",
    "[R8 Steamworks] Avoid fire spins; break freeze.")

addBoss("Vampire Lord Thisa", "Dragonstar Arena", "Round 9: Vampire Lord Thisa", {"Thisa"},
    "Crypts of the Lost: holes pull players underground; Devouring Swarm.",
    "If pulled underground, take the portal back. Avoid Devouring Swarm: it kills groups fast.",
    "Hold Thisa away from holes.",
    "Swarm damage is extreme.",
    "Burn Thisa.",
    "[R9 Crypts] Portal out of holes; avoid Swarm.")

addBoss("Hiath the Battlemaster", "Dragonstar Arena", "Round 10: Hiath the Battlemaster", {"Hiath"},
    "The Champion's Arena: fire circles follow players and stay on the ground.",
    "Drop fire circles away from the group, and rotate between the three islands as fire builds up.",
    "Move Hiath with the group between islands.",
    "Ground fire accumulates.",
    "Burn before the islands fill.",
    "[R10 Hiath] Drop fire away; rotate islands.",
    {
        challenges = {
            { name = "Dragonstar Arena Conqueror", text = "Complete all rounds on Veteran." },
        },
    })

-- Blackrose Prison
addDungeon("Blackrose Prison", "arena", { group = "Murkmire" })
addBoss("Battlemage Ennodius", "Blackrose Prison", "Battlemage Ennodius", {"Ennodius"},
    "Round 1 (and returns in Round 4): bound flame atronachs anchored on red sigils.",
    "Stay away from the red sigils' flame atronachs and their abilities.",
    "Hold Ennodius away from sigils.",
    "Atronach fire.",
    "Burn.",
    "[Ennodius] Avoid sigil atronachs.")

addBoss("Tames-the-Beast", "Blackrose Prison", "Tames-the-Beast", {"Tames"},
    "Round 2 (and returns in Round 4): invulnerable bull netches.",
    "Stay away from the netches (shock aura) and dodge their poison gas.",
    "Hold the boss away from netches.",
    "Shock and poison stack.",
    "Burn the boss; ignore netches.",
    "[Tames] Avoid netches and gas.")

addBoss("Lady Minara", "Blackrose Prison", "Lady Minara", {"Minara"},
    "Round 3 (and returns in Round 4): necromantic pools and a curse.",
    "Stay out of the pools, EXCEPT when cursed: then step into a pool to cleanse.",
    "Hold Minara off the pools.",
    "Pool damage is heavy.",
    "Burn.",
    "[Minara] Avoid pools; cursed = step in to cleanse.")

addBoss("Drakeeh the Unchained", "Blackrose Prison", "Round 5: Drakeeh the Unchained", {"Drakeeh"},
    "Final round: invulnerable spectral wraiths shoot bolts.",
    "Spirit Ignition: absorb the marked ghosts, then cleanse at a sigil.",
    "Hold Drakeeh.",
    "Wraith bolts add up.",
    "Burn Drakeeh.",
    "[R5 Drakeeh] Absorb marked ghosts; cleanse at sigil.",
    {
        challenges = {
            { name = "Unchained and Undying", text = "Complete Veteran with no deaths." },
            { name = "Gauntlet Gallop", text = "Complete Veteran in under 30 minutes." },
        },
    })
