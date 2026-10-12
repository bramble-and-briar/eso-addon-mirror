-- 12-player trials.
-- Trial bosses have too many mechanics for the pop-up card: keep `everyone`
-- to the one or two mechanics that wipe the group, and use the tank/healer/dps
-- lines for each role's job. Hard mode notes live at the bottom of each trial.
--
-- A trial only shows in the menu once it has at least one boss, so a trial
-- without boss entries yet is invisible in-game.

local addDungeon = PullCardData.addDungeon
local addBoss = PullCardData.addBoss
local addShared = PullCardData.addShared
local setHM = PullCardData.setHardMode
local addCombo = PullCardData.addCombo

-- =============================================================================
-- Craglorn trials
-- Boss names/order, hard mode triggers: UESP. Achievements: esodecoded.com.
-- Mechanics: from player experience (to be filled in).
-- =============================================================================

-- Aetherian Archive ----------------------------------------------------------
addDungeon("Aetherian Archive", "trial", { group = "Craglorn" })
local AA = "Aetherian Archive"

addBoss("Lightning Storm Atronach", AA, "Lightning Storm Atronach", {"Storm Atronach"},
    "Storm atronach in the middle of a room with 5 outer pads. Agree pad names first (e.g. front, back, left, right, top right).",
    "STORM: Every 10-15 seconds he raises his hands and calls a storm that ticks harder every second. "
        .. "RUN to the pad with the yellow LIGHT beam and stay inside until the storm ends. Don't finish your rotation first; if you're late, you die.\n\n"
        .. "SHOCKWAVE: After each storm, go back to the middle. He channels a growing ground burst followed by small fast ground AoEs: "
        .. "damage shield or BLOCK.\n\n"
        .. "PUNCHES: Slow, heavy punches at whoever has aggro. They can one-shot a DPS.",
    "Hold him still in the middle, facing away. BLOCK the punches and never drop taunt.",
    "Get to the light with the group; heal everyone back up after each storm and through the shockwave.",
    "Run to the light the moment he raises his hands. Shield or block the shockwave.",
    "[Storm Atro] Hands up = RUN to the light pad. Block the shockwave.")

addBoss("Foundation Stone Atronach", AA, "Foundation Stone Atronach", {"Stone Atronach"},
    "Stack-and-burn stone atronach with adds in pairs. Awkward hitbox: highlight the boss to keep taunt.",
    "ADDS: A Chain Spinner and a Nullifier spawn in pairs, all fight. Kill Chain Spinners first (stuns, AoE). "
        .. "Nullifiers heal: interrupt them. Don't let pairs pile up; a weak group should stop and kill adds first.\n\n"
        .. "ROCKS (75% and below): When he crouches into a ball, rocks fly at players. SPREAD OUT and BLOCK until he stands up, then stack again.\n\n"
        .. "GROUND POUND: He pounds the ground 5 times; stay out of his face.",
    "Main tank: turn him 90 degrees away from the group. Off tank: pull adds onto the boss (move out of the Nullifier's range so it follows).",
    "Focus the group through ground pounds and rock phases.",
    "Stack out of his face. Chain Spinners > boss > Nullifiers (interrupt heals). Spread and block on rocks.",
    "[Stone Atro] Kill Chain Spinners; crouch = spread + block.")

addBoss("Varlariel", AA, "Varlariel", {},
    "The pug killer. Wispmother who splits into ghosts at the pillars.",
    "DON'T STACK: everyone in a big circle with their own space. AoEs pop under players; two on one person kills.\n\n"
        .. "SPLIT: She splits into ghosts at the pillars (3 the first time, one more each split, up to 6). "
        .. "When the split ends she explodes, harder for each ghost still alive. "
        .. "Assign 2 people per pillar (skip the orange mushroom one), kill your ghost, come back.\n\n"
        .. "EXPLOSION: If a ghost is left, BLOCK or shield the explosion. With Minor Maim on her, one ghost is survivable.\n\n"
        .. "MAGIC BOLTS: Fired at whoever has aggro (ghosts too). Two on a DPS kills them.",
    "Keep her facing you with taunt and Minor Maim. Off tank: taunt the ghosts so their bolts stay off the group.",
    "Heal through the AoEs; players spread out can't share damage. Expect the explosion.",
    "Go to your pillar, kill your ghost fast, help others, then come back and block the explosion.",
    "[Varlariel] DON'T stack. 2 per pillar, kill ghosts, block the boom.")

addBoss("The Mage", AA, "The Mage", {"Celestial Mage", "Mage"},
    "Final boss. Formation wins this fight: tank in front at arm's length, group BEHIND her, with a 10m gap.",
    "CHAIN LIGHTNING: She only zaps what's in front of her (180 degrees). Stay behind the line through her middle and NEVER cross it. "
        .. "Keep a 10m+ gap between tank and group so the zap has no one to chain to.\n\n"
        .. "AXES: \"I cannot control my armory\" = purple axes spawn. Tank grabs them; BLOCK their heavy attack or you get knocked down and killed.\n\n"
        .. "REFLECTIONS: A fast-spreading AoE then a burst marks a reflection of her. Get out, then KILL IT FAST (room-wide DoT). "
        .. "On the tank's side, use range.\n\n"
        .. "MINES and BLACK HOLES: Avoid them. If the tank moves, the group moves the opposite way to keep the formation.\n\n"
        .. "EXECUTE (~15%): She knocks the group down 3 times, then a slow nova closes in and damage ramps up. "
        .. "Kill all reflections BEFORE pushing her to 15%. Then it's a DPS race: stagger group buffs and ultimates.",
    "Taunt from arm's length (e.g. Pierce Armor range). Collect the axes without running through the group; an off tank can split them.",
    "Stagger shields and ultimates in the execute. Heal through mines, reflections and black holes.",
    "Stay behind her and never cross the line. Switch to reflections immediately. Save burst for the execute.",
    "[Mage] Behind her, 10m gap, never cross the line. Kill reflections. Tank takes axes.")

-- Hel Ra Citadel -------------------------------------------------------------
addDungeon("Hel Ra Citadel", "trial", { group = "Craglorn" })
local HRC = "Hel Ra Citadel"

PullCardData.addGuide(HRC, "Trash: Priority Targets",
    "FLAME SHAPERS (HIGH priority): When they raise their staff they rain fire on the group. INTERRUPT within 2-3 seconds; "
        .. "everyone, not just the tank. Most players can't take more than 2-3 hits.\n\n"
        .. "DESTROYERS: Cleave plus a cone knockdown. Tank turns them away; BLOCK the cone if it comes your way.\n\n"
        .. "GARGOYLES: Tank turns them away; everyone else stays BEHIND. Their breath turns you to stone (break free). "
        .. "After every SECOND breath they slam the ground in a big circle: GET OUT or die.\n\n"
        .. "WAR PRIESTS (lowest priority): Snare and knockdown heavies. Tank holds them; they die to AoE. Block if one hits you.")

PullCardData.addGuide(HRC, "The Warrior: Hard Mode Plan",
    "Destroy the statues in the room before the Warrior's chamber to start hard mode.\n\n"
        .. "STONED: He turns a random player to stone. If that player uses a synergy they EXPLODE and kill everyone near them, "
        .. "so agree on NO SYNERGIES for the whole fight. To free them: stack on them and let his shield throw break them out "
        .. "(everyone else steps out of the throw), or move away so they can break free.\n\n"
        .. "GARGOYLE STATUES: Statues around the room wake up over time. His shield throw one-shots them while they're still stone. "
        .. "Tank stands with their back to a statue; the group lines up 10m+ behind the tank in a PERFECT straight line, so the throw can only go that way. "
        .. "Line up across two statues to kill two per throw, then move to the next pair. One person out of line sends the throw off-angle. "
        .. "Don't let him land in the blue circle. Missed statues wake up and fight like normal gargoyles.\n\n"
        .. "EXECUTE (35%): Call spots Left / Middle / Right in a close semi-circle. Too stacked and Starfall kills you; too spread and he jumps the furthest. "
        .. "If someone is stoned they call their spot, and everyone else there moves away so they can break free.")

addBoss("Ra Kotu", HRC, "Ra Kotu", {"Kotu"},
    "Big air atronach with a huge hitbox. Spread in a semi-circle behind him; you don't need to hug him to melee.",
    "DON'T STACK: Wind AoEs land on random players. Stand still and take heals (or kite out if heals are low); stacking doubles them.\n\n"
        .. "SWORDS: He hugs himself, then bursts swords in all directions. Block (or interrupt it if you're fast).\n\n"
        .. "SPIN (30% and below): A fast-spreading AoE from his body, then he SPINS with his swords. Back out to the edge; anyone inside dies. "
        .. "Melee still reaches from the edge.\n\n"
        .. "ADDS: 3 at the start; follow the trash rules (turn destroyers away).",
    "Turn him away from the group and BLOCK his heavy attack. Off tank holds the 3 adds beside him, facing away.",
    "Heal the wind AoE targets; the group is spread so watch everyone.",
    "Semi-circle behind him, spread out. Back off for the spin under 30%.",
    "[Ra Kotu] Spread, don't stack. Under 30%: back out of the spin.")

addBoss("Yokeda Rok'dun", HRC, "Yokeda Rok'dun", {"Rokdun", "Rok'dun"},
    "Ranged boss with Welwar adds. Hold the adds with the boss or to one side; your choice.",
    "WELWARS: More spawn through the fight; the tank holds them. When they enrage they're low health: kill them if the tank struggles. "
        .. "NEVER stand directly behind a Welwar: its kick can one-shot.\n\n"
        .. "FLAMES: A flame shot bursts into 4 lines on the ground. Stand in the gaps or heal through.\n\n"
        .. "REPOSITION: Every ~30 seconds he moves to a new spot; follow him. If a Welwar dies he runs to revive it, so time your ultimates.",
    "Hold the Welwars at all times (about 4 is manageable). Follow him when he repositions and restack.",
    "The flame lines are the main group damage; heal through them.",
    "Follow him when he moves; don't waste ultimates right before he runs. Never stand behind a Welwar.",
    "[Rok'dun] Tank holds Welwars; never stand behind one. Follow when he moves.")

addBoss("Yokeda Kai", HRC, "Yokeda Kai", {"Kai"},
    "Mage boss who splits into 4. Spread out; assign one DPS to each of the 4 positions (count left to right: 1, 2, 3, 4).",
    "SPLIT: She splits into 4; 3 are fakes and immune. Whoever has the real one calls its number. "
        .. "Watch YOUR one: if it raises its staff (flame channel), INTERRUPT it immediately or the group gets wiped.\n\n"
        .. "PULSAR: A fast-spreading AoE under the boss or adds, then a huge explosion. BLOCK at full health. "
        .. "DO NOT DODGE ROLL: it still counts as a hit and one-shots you.\n\n"
        .. "METEORS: Random players get stunned, then a fire circle. Don't roll: BLOCK and walk out while blocking.",
    "Taunt the boss and adds for aggro and debuffs.",
    "Keep everyone topped up before the pulsar: blocking at full health survives, low health doesn't.",
    "Watch your assigned add and interrupt its channel. Block the pulsar, never roll it.",
    "[Kai] Interrupt your add's channel. BLOCK the pulsar, don't roll.")

addBoss("The Warrior", HRC, "The Warrior", {"Celestial Warrior", "Warrior"},
    "Final boss and a brutal tank check. Tank holds him in the middle facing away; group stacks in a tight STRAIGHT LINE.",
    "SHIELD THROW: He faces a random player and throws his shield (a long strip AoE) that comes back. Get out, then back into the line.\n\n"
        .. "CUTS and CLEAVE: A multi-hit flurry and a hard frontal cleave, both aimed at the tank. Anyone else in front dies.\n\n"
        .. "JUMP: He jumps on the furthest player. Stay close in the line and it never happens.\n\n"
        .. "CIRCLES: Yellow = heal, blue = damage boost; both buff enemies too. Keep him OUT of them, especially blue. "
        .. "At 85% and 70% he smashes their statues: gather in the middle and dodge his jump.\n\n"
        .. "ADDS: 2 destroyers + 2 flame shapers. Interrupt the flame shapers.\n\n"
        .. "EXECUTE (35%): Starfall blows up the room and kills all adds. Now SPREAD in a semi-circle. "
        .. "Sword up = repeated hits on everyone: block and shield (he heals while channeling, so DPS hard after). "
        .. "Energy Wave replaces the shield throw (avoid it or die), followed by a cleave at the tank.",
    "BLOCK the cuts and heavy attack, keep him facing away and out of the circles. Heavy attack for resources when the shield goes elsewhere. "
        .. "Off tank: destroyers on the boss; pull flame shapers in by taunting from range and backing off.",
    "Keep everyone topped up in execute; Starfall hits the whole group repeatedly.",
    "Straight line, never in front. Interrupt flame shapers. In execute: spread, block Starfall, dodge the wave.",
    "[Warrior] Straight line, out of shield throw. Execute: spread + block.")

-- Sanctum Ophidia ------------------------------------------------------------
addDungeon("Sanctum Ophidia", "trial", { group = "Craglorn" })
local SO = "Sanctum Ophidia"

PullCardData.addGuide(SO, "Trash: Priority Targets",
    "OVERCHARGERS (HIGHEST priority): Kill on sight. They put a big lightning AoE ON a random player for ~10 seconds, "
        .. "plus lightning bolts at them. That AoE moves with you: stand still or step away from the group and block; never run through people. "
        .. "Overchargers run to the Shaman's TOTEM: kill the totem (not the shaman) to keep them in place.\n\n"
        .. "TROLLS (second priority): Step out of the ground pound. Boulder at a random player: DODGE ROLL (blocking still knocks you down). "
        .. "Small poison ball: dodge it, or you carry a spreading poison AoE. Stand aside; touching others spreads it to them.\n\n"
        .. "ARCHERS: Orange light = snipe wind-up: INTERRUPT it. Avoid the arrow spray.\n\n"
        .. "WAR PRIESTS (lowest priority): Tank holds them; they die to AoE. Block if one hits you.")

PullCardData.addGuide(SO, "The Serpent: Adds & Totems",
    "LAMIAS: Two spawn from the left corner at the start. Off tank grabs them immediately and keeps them to one side ALL fight. "
        .. "Don't kill them: they explode and one-shot anyone nearby. Interrupt their scream, block their heavy. "
        .. "Careful heavy attacking them: they block, and that knocks you off balance.\n\n"
        .. "MANTIKORAS: One rises from a blood pool after the 2nd poison phase, another after the 4th. Either the off tank parks them with the Lamias "
        .. "far from the group (bottom left corner up the stairs, out of stomp range), or the main tank brings them in and the group kills them. "
        .. "They have a heavy (tank blocks) and a huge stomp: EVERYONE BLOCK or die.\n\n"
        .. "BLUE TOTEMS put magicka bombs on players. Destroy them to stop bombs until a new one spawns (advanced: move the boss onto it).\n\n"
        .. "PULL TOTEMS drag a player to them: dodge roll mid-pull to break it, or roll away to break the snare. Can be killed.\n\n"
        .. "POISON TOTEMS (green, beamed to the boss) buff his poison phases.\n\n"
        .. "The orb explosion after every 5th poison phase wipes all Lamias, Mantikoras and totems; the fight restarts from scratch.")

addBoss("Possessed Mantikora", SO, "Possessed Mantikora", {},
    "First boss. Group in a spread semi-circle behind her; 2+ ranged players loosely stacked well back to catch the spears.",
    "POPCORN: A growing AoE under you pops 3 times. Run BACKWARDS out of the group until all 3 have gone off.\n\n"
        .. "STOMP: A room-wide AoE: everyone BLOCK. Then a huge bleed: heal to full to clear it.\n\n"
        .. "PORTAL: When you hear the Serpent's voice, SPREAD. 1 tank + 1-3 DPS jump in the portal and kill the Serpent's reflection within 1:45 "
        .. "(tank: block its heavy, don't spin it). No popcorn upstairs while it lives: BURN the boss.\n\n"
        .. "SPEARS: After the portal she throws spears at the furthest players: ranged block, then step out. Keep them at the back.\n\n"
        .. "ENRAGE: At low health she glows red. Kill her.",
    "DON'T OVERTAUNT: taunt no more than every 7-10 seconds or she rampages. Face her away, BLOCK the heavy, nobody else in front (cleave one-shots).",
    "Heal everyone to full after each stomp; full health clears the bleed.",
    "Spread behind her. Popcorn = run backwards. Block the stomp. Burn during the portal.",
    "[Mantikora] Don't overtaunt. Popcorn = run back. Block stomp. Burn during portal.")

addBoss("Stonebreaker", SO, "Stonebreaker", {},
    "Troll guarding the bridge, like the Troll King but much harder hitting. Circle around him, never in front.",
    "GROUND SLAM: Big AoE: BLOCK.\n\n"
        .. "GROUND POUND: He punches the floor 3 times, sending lines at the tank; sometimes behind him too. EVERYONE BLOCK or risk a one-shot.\n\n"
        .. "POISON BALL: Dodge it; if it hits, stand aside so you don't spread it.\n\n"
        .. "OVERCHARGERS: 1 at 75%, 2 at 50%, 3 at 25%. Kill each set before the next. Kill the Shaman's totem so they stay put.\n\n"
        .. "ENRAGE (~20%): He glows red; an unblocked slam is now death.",
    "Turn him away from the group. Hold the archer and war priest he brings next to him.",
    "Damage shields and mitigation help a lot here; the group takes heavy damage.",
    "Block slams and pounds. Overchargers first, every time.",
    "[Stonebreaker] BLOCK slams/pounds. Kill overchargers at 75/50/25.")

addBoss("Ozara", SO, "Ozara", {},
    "Low health but a lot going on. Tank holds her near the closed door on the right as you enter (not too close); group in a spread semi-circle behind.",
    "PINS: Hands up = players get pinned and can't free themselves. Run over, use the synergy to free them, then back to your spot. "
        .. "Up to 4 pins at once. If pinned, emote rather than spamming chat (tanks/healers: call it).\n\n"
        .. "OVERCHARGER: Comes from that door and respawns each time it dies. Focus it; each spawn is your ultimate window.\n\n"
        .. "TOTEM: Kill the Shaman's TOTEM (it never respawns) so the overcharger stays at the door. DON'T kill the Shaman: he respawns with a new totem.\n\n"
        .. "ADDS: Endless small adds respawn; ignore or cleave them.",
    "Block her heavy (it knocks you down). Off tank: hold the troll, archer and war priest nearby or in a corner; leave the overcharger to the group.",
    "Watch pinned players, especially tanks and healers.",
    "Free pinned players fast. Overcharger on sight. One DPS kills the totem at the start.",
    "[Ozara] Free pins. Kill the TOTEM, not the Shaman. Overcharger on sight.")

addBoss("The Serpent", SO, "The Serpent", {"Serpent", "Celestial Serpent"},
    "Final boss. Main tank holds him still facing away; group stacks on the circular pad BEHIND him, never in front.",
    "CLEAVE: A huge, wide arc that can wipe the group. Only the tank in front.\n\n"
        .. "POISON PHASE: He teleports to the middle of the pad and crouches; the room fills with poison for ~10 seconds. Stay stacked for heals.\n\n"
        .. "MAGICKA BOMB: You glow blue and hum: EMPTY your magicka bar (to ~10%) before it goes off, or you die.\n\n"
        .. "ORBS (after every 5th poison phase and at execute): Pink shards scatter: everyone grabs ONE (tank's is where they stand; "
        .. "assign left/right in advance). No bubble = dead. The explosion resets all adds and totems.\n\n"
        .. "ADDS and TOTEMS: Lamias, Mantikoras, pull and bomb totems. Plan: 'The Serpent: Adds & Totems' in the menu.",
    "Hold him still facing away and BLOCK his heavy and cleave. Off tank: grab the 2 Lamias at once and keep them to one side all fight.",
    "Spam heals in the poison phase; the group is stacked for you. Off tank can shield if far away.",
    "Stack behind him. Dump magicka on a bomb. Grab your OWN orb.",
    "[Serpent] Stack behind. Bomb = empty magicka. One orb each, don't steal the tank's.")

-- =============================================================================
-- Maw of Lorkhaj (Thieves Guild)
-- =============================================================================
local MOL = "Maw of Lorkhaj"
addDungeon(MOL, "trial", { group = "Thieves Guild" })

PullCardData.addGuide(MOL, "Twins: How the Colors Work",
    "TEAMS: Split into two teams of 6 (1 tank, 1 healer, 4 DPS each). Each team gets a head color (yellow or blue).\n\n"
        .. "COLOR RULES: Never touch a player with the OTHER color (you both explode). Always hit the boss of the OPPOSITE color to your head "
        .. "(same color = only 10% damage). Once colors are out, the tanks swap bosses so each team faces the right one.\n\n"
        .. "ORIGINALS: Each tank must remember the boss they taunted FIRST. That's their 'original'.\n\n"
        .. "ADDS: 10 seconds after colors, each side gets adds: 1, then 2, 3, up to 4 as the bosses lose health. Kill them at all costs before the next phase. "
        .. "Yellow adds: interrupt the beam (Radiant Oppression), purge Reflective Light. Blue adds: ranged, throw orbs; face them away from the yellow team.\n\n"
        .. "CONVERSION: The bosses pray and 3 players per side (not tanks) get a color under their feet: SWAP sides fast, clockwise.\n\n"
        .. "SWITCH OR STAY: The bosses teleport to opposite sides. Boss near you is the OPPOSITE color to your head = STAY. SAME color = SWITCH sides, clockwise.\n\n"
        .. "ORIGINALS PHASE (tanks): Next the room explodes and colors are wiped; everyone gets the color of the boss they're closest to. "
        .. "Before colors return, each tank RUNS to their original boss, gets its color, then taunts the opposite boss again. "
        .. "Pro tip: taunt the wrong boss before running, so it follows you over.\n\n"
        .. "Then it repeats: adds, conversion, switch or stay, originals.\n\n"
        .. "EXECUTE: Keep both bosses at similar health. When ONE dies, colors disappear and 4 more adds spawn; you have 20 seconds to kill the other boss "
        .. "or he explodes in the middle. Kill the yellow adds first.")

PullCardData.addGuide(MOL, "Rakkhat: Pad by Pad",
    "The tank moves him clockwise one gold pad each time he jumps HIGH. What each pad brings:\n\n"
        .. "- Pads 2, 4, 6, 8: a HULK. Focus it, interrupt its AoE stun, tanks swap it after 2 smashes. "
        .. "Get him into execute by pad 8, or you go to Lunar with a hulk alive; kill it first.\n"
        .. "- Pads 2-3: BOMBS. A spreading circle under a player stuns them when it pops and kills anyone it touches. "
        .. "Stay put if your formation leaves room, or walk it out of the group. Block or heal the orbs it releases.\n"
        .. "- Pads 3, 5, 7: RUNNERS go out the back (see 'Runners & Curses').\n"
        .. "- Pad 5: TETHERS. Blue balls attach to players; popcorn shots come from the middle pad, so keep away from it. "
        .. "Kite the tethers off, or stack mitigation and heals and tank them.\n"
        .. "- Pad 7: BOOM BALLS. Big spheres on random players: step away until they pop, then come back.\n"
        .. "- After pad 8: LUNAR PHASE (see its row). The next lap adds a Dreadstalker every pad.\n\n"
        .. "EXECUTE (~12%): He teleports to the middle and all pads turn blue. Orbs appear on pads 1 to 8 IN ORDER: each one picked up "
        .. "lowers his resistances but curses the picker (step off the pad fast; don't grab one if you're already cursed). "
        .. "Reach the 8th orb without killing him = wipe. Stay between pads 1-4 for heals; bombs, orbs and tethers keep coming.")

PullCardData.addGuide(MOL, "Rakkhat: Runners & Curses",
    "RUNNERS (pads 3, 5 and 7): Shadows of 6 Void Callers appear on the middle pad. 2-3 assigned runners go out the back gate "
        .. "(left, middle and right arches, two Void Callers each). Activate the floor synergies to reveal them and kill them; "
        .. "each kill removes a shadow in the main room. All 6 dead = runners come back and cleanse on one of the 4 cleanse pads. "
        .. "Fail and the shadows drag the whole group under: WIPE.\n"
        .. "Out back: dodge the blue orbs (they kill fast), watch the gap jumps, and kill Void Assassins fast (they hit hard and snare, so don't jump right after).\n\n"
        .. "BLUE CURSES: Going through the gate or touching a blue pad curses you: less healing received and blue hits can one-shot you. "
        .. "Touch a blue pad while cursed and you die. Save cleanse pads for the runners.\n\n"
        .. "HARD MODE CURSES: Cursed players fire blue orbs at anyone close, so keep your distance. NO cleanse pads in hard mode. "
        .. "Tip: assign 2 resurrectors; runners die on the edge of a blue pad near the group and get rezzed clean for the next run.")

PullCardData.addGuide(MOL, "Rakkhat: Lunar Phase",
    "After pad 8 (if he's not in execute): every DPS goes to THEIR pad (1-8), but don't step on until it turns GOLD. "
        .. "All curses are removed. Tanks and healers stand in the middle.\n\n"
        .. "Each pad gets an add. You can only kill it while a BEAM from the middle is on it. Block your add's heavy or it knocks you off the pad (death).\n\n"
        .. "BEAMS (synergies from the middle, in order, calling targets out loud):\n"
        .. "- Tank 1: pads 1, 2, 3\n"
        .. "- Tank 2: pads 4, 5, 6\n"
        .. "- Healer 1: pads 7, 8, then anything left\n"
        .. "- Healer 2: heals only, NO synergy skills (they interfere with beams)\n\n"
        .. "WHO HITS WHAT (by your pad):\n"
        .. "- Pad 1: 1, 2, then 8\n- Pad 2: 1, 2, then 3\n- Pad 3: 4, 2, then 3\n- Pad 4: 4, 5, then 3\n"
        .. "- Pad 5: 4, 5, then 6\n- Pad 6: 7, 5, then 6\n- Pad 7: 7, 8, then 6\n- Pad 8: 1, 8, then 7\n\n"
        .. "Don't leave your pad until Rakkhat lands. Adds left alive run around one-shotting people. "
        .. "After lunar the pads reset and a new lap starts, now with a Dreadstalker every pad.")

addBoss("Zhaj'hassa the Forgotten", MOL, "Zhaj'hassa the Forgotten", {"Zhaj'hassa", "Zhajhassa"},
    "First boss, on a soft timer: deaths cost time, and running out of pillars is a wipe. 6 cleanse pads; assign 2 people to each.",
    "SPREAD: Two semi-circles (melee in front, ranged behind), 2-3m apart, never stacked.\n\n"
        .. "CURSES: He curses 3 players: go to YOUR pad, cleanse, come back. Pads take 25 seconds to return. "
        .. "Tanks and healers get pads first. Don't touch others while cursed: it spreads. No pad free = keep fighting and take the death.\n\n"
        .. "PILLARS: He hammers random players to raise pillars (stay close so they stay close). When he PRAYS, hide behind ANY pillar or get one-shot. "
        .. "Each round has one fewer pillar (5, 4, 3, 2, 1). At zero pillars, kill him before he finishes praying or it's a WIPE.\n\n"
        .. "CATS (80/60/40/20%): 4 cats attack random players. Tanks pull them under the boss (they can be CC'd); AoE and ultimates.\n\n"
        .. "SHIELD (70% and 30%): He shields; a bursting AoE grows under each player, faster the longer the shield lasts. "
        .. "Close in, no overlapping circles, burn the shield. Good time for Nova or Permafrost.",
    "Hold him in the middle or near your pad. If you're cursed, the off tank takes him while you cleanse; don't drag him around.",
    "Healers get pad priority. Heal through the shield phases.",
    "Your own space, your own pad. Burn the shield fast. Nobody dies = you never reach zero pillars.",
    "[Zhaj'hassa] Spread. Cursed = your pad. Prays = hide behind a pillar.")

addShared({"Vashai", "S'kinrai"}, MOL, "Vashai & S'kinrai (Twins)", {"Twins", "Skinrai"},
    "The twins: two teams of 6, one per boss, each with a head color. Full rules: 'Twins: How the Colors Work' in the menu.",
    "COLORS: Never touch someone with the other head color (you both explode). Hit the boss of the OPPOSITE color to your head.\n\n"
        .. "ADDS: Kill them every phase, at all costs. Interrupt yellow beams; purge Reflective Light.\n\n"
        .. "CONVERSION: Color under your feet = SWAP sides fast, clockwise.\n\n"
        .. "SWITCH OR STAY: Boss near you is the opposite color = STAY; same color = SWITCH, clockwise.\n\n"
        .. "EXECUTE: Keep both bosses at similar health. When one dies you have 20 seconds to kill the other.",
    "Remember your ORIGINAL boss (first one you taunted). On the color wipe, run back to it before colors return, then taunt the opposite one. "
        .. "S'kinrai (yellow): block cleaves, interrupt his beam. Vashai (blue): he drops bubbles; walk him along the wall from bubble to bubble.",
    "Purge Reflective Light. Watch players pinned by yellow beams.",
    "Hit the opposite color. Adds first. Swap fast on conversion.",
    "[Twins] Never touch the other color. Hit opposite color. Adds first. Swap clockwise.")

addBoss("Rakkhat", MOL, "Rakkhat", {"Rakkhat, Fang of Lorkhaj"},
    "Final boss across 8 pads around a middle pad. Each DPS is assigned a pad 1-8 for lunar phase. Only the main tank ever stands on GOLD pads; nobody touches BLUE pads.",
    "JUMP: He jumps and heavy attacks the tank with a big knockback: EVERYONE in range BLOCK, or you get thrown onto a blue pad.\n\n"
        .. "MACHINE GUN: Magic barrage at the tank; nobody else in front.\n\n"
        .. "METEORS: \"A storm approaches\" = assigned kiters at the back run off in different directions so the meteors land behind them.\n\n"
        .. "HULKS (pads 2/4/6/8): Focus them down and INTERRUPT their stun. Off tank swaps after 2 smashes (a 3rd kills).\n\n"
        .. "PAD BY PAD (bombs, tethers, boom balls, runners) and LUNAR: see the menu rows.\n\n"
        .. "EXECUTE (~12%): Grab the orbs on pads 1-8 IN ORDER (not if cursed) to lower his resistances. 8th orb without a kill = wipe.",
    "Stay on the gold pad (it protects you). When he jumps HIGH, move to the next gold pad clockwise. Block the machine gun; break free after he lands on you.",
    "Heavy heals on the tank during the machine gun. Heal through bombs, tethers and execute.",
    "Know your pad number. Block his jump. Focus hulks. Grab execute orbs in order.",
    "[Rakkhat] BLOCK the jump. Never touch blue pads. Focus hulks. Execute: orbs in order.")

-- =============================================================================
-- Halls of Fabrication (Morrowind)
-- =============================================================================
local HOF = "Halls of Fabrication"
addDungeon(HOF, "trial", { group = "Morrowind" })

PullCardData.addGuide(HOF, "Committee: The 70/40/27% Plan",
    "SETUP: Two teams (1 tank, 1 healer, 4 DPS each), one on the Reactor, one on the Reducer. The Reclaimer stays in the middle and never moves; "
        .. "both teams hit it. Start with all three close and burn them together until they try to beam to each other, then the tanks drag "
        .. "the Reactor and Reducer to opposite sides (near the door is fine).\n\n"
        .. "THE PLAN: At 69% they all go invulnerable. You want all three to hit it at the same time.\n"
        .. "- Get each boss to ~71% and STOP damage. Even them out (Reclaimer last, once the other two are under ~72%).\n"
        .. "- Bring all three into the middle and push them over 69% together. Linked while invulnerable, their beams STUN them.\n"
        .. "- Dump everything (AoE, ultimates) while they're stunned. When they stand up, split them again.\n"
        .. "- Repeat at ~41% (for 39%) and ~27% (for 25%).\n\n"
        .. "BELOW 25%: Never bring them back together. Kill the Reclaimer FIRST (ends the bombers), then the other two one at a time.\n\n"
        .. "There's no enrage: once you can do one phase cleanly, the rest is the same.")

PullCardData.addGuide(HOF, "Assembly General: Phases",
    "POSITIONS: Tank in front. Group sits up on the ledge UNDER the flame arm. Either an off tank takes the spinning blade arm, "
        .. "or the main tank eats it while the off tank handles adds.\n\n"
        .. "ADDS: In pairs at 90/87%, 70/67%, 50/47%, 30/27%, then every 2 minutes. Off tank controls them; group stacks around the corner "
        .. "to kill them. Not ready to push (ultimates, rezzes)? Hold and kill another wave; take as long as you need. "
        .. "At 3% before each recharge his arm falls off: STOP damage and clear the adds first.\n\n"
        .. "MISSILES: More when you're far away (around the corner). Block if you're getting low.\n\n"
        .. "RECHARGE (85/65/45%): He walks to the middle, regains his flamethrower and REFLECTS all damage, so nobody hits him. "
        .. "Stand together in the middle of the floor (poison leaks through the grills at the edges). Kill 2 of the 4 terminals "
        .. "(each one left makes his big hit stronger): the one near you, then run past him to another. Then out-heal the spinners, meteors and missiles: "
        .. "big shields and healing ultimates. Don't block spinners (it drains stamina). When he stands, everyone but the tank goes back up on the flame-arm side.\n\n"
        .. "EXECUTE (25%): He moves to the middle platform with 4 tracks. DPS stand in pairs at the end of each track; tanks and healers take a corner each. "
        .. "Meteors hit 4 players over and over; under 10% they hit 4 more (outside players plus each pair). DPS: stand still and rotate. "
        .. "Tanks and healers: stagger Novas, barriers, Permafrost and shields. It's a survival check, not a DPS check.")

PullCardData.addGuide(HOF, "Pinnacle: Upstairs Team",
    "WHEN: Divayth calls that the fabricants are powering up, about every 90 seconds after each phase ends.\n\n"
        .. "WHO: 4 assigned players each take one of the 4 outer platforms and use the synergy to go up.\n\n"
        .. "UP THERE: Kill the 4 Dwemer Spheres, together, one at a time. One of you gets a lightning beam: stand so the beam passes through "
        .. "the sphere (between it and the hole) to break its shield. Bring your own heals and shields.\n\n"
        .. "CONSOLES: Each player goes back to their spot; count 3-2-1 and press the console synergies TOGETHER (close is fine). "
        .. "Steam shows who has pressed. Then jump back down through the shielded holes.\n\n"
        .. "TIMER: 60 seconds or meteors wipe the group downstairs. Never jump down early: you'll splat.")

addShared({"Hunter-Killer Positrox", "Hunter-Killer Negatrix"}, HOF, "Hunter-Killer Positrox & Negatrix", {"Positrox", "Negatrix", "Hunter-Killer"},
    "Two identical bosses, each held by its own tank on opposite sides of the room; group stacked in the middle. A tank-heavy fight.",
    "TAKE AIM (TOP PRIORITY): The Dwemer Spheres snipe: a hit one-shots. EVERYONE interrupts, not one assigned person.\n\n"
        .. "POISON INJECTION: Spheres put a deadly DoT on players. Cleanse it fast (Purify / purge).\n\n"
        .. "SPHERE SHIELDS: Spheres can't be hurt while shielded. The tanks briefly bring both bosses together so their beam passes through "
        .. "the sphere, then split FAST. The longer they're linked, the closer to an enrage wipe.\n\n"
        .. "TAIL WHIP: Lightning balls roll across the floor behind each boss. Find the gaps or BLOCK; two can cross, and the second kills.\n\n"
        .. "SCARABS (75/50/25%): Can't be taunted; AoE and ultimates. Never stand in ground lightning.\n\n"
        .. "EXECUTE: Bring BOTH low together. When one dies the other enrages: kill it right after.",
    "Keep your boss apart from the other one, except to break a sphere shield. Block the heavy and don't get too far away (it jumps on you). "
        .. "If you're pinned, call it.",
    "Purge or Purify the poison injections fast. Pinned tanks need help.",
    "Interrupt every Take Aim. Interrupt a boss pinning a tank. Ultimates on the scarabs.",
    "[Hunter-Killers] INTERRUPT snipes. Cleanse poison. Bosses apart, together only to break shields.",
    { challenges = { { name = "Kill Process", text = "Kill one Hunter-Killer while the other is still above 50% health, then the other." } } })

addBoss("Pinnacle Factotum", HOF, "Pinnacle Factotum", {"Pinnacle"},
    "No enrage: take as long as you need. New groups: tank him facing the far back corner (half the shade attacks then hit the wall).",
    "CHARGING UP: He channels and 4 players get a growing AoE. Just INTERRUPT him.\n\n"
        .. "CENTURION STEAM: A Centurion spawns about every minute. Its steam cones (front/back, then sides) stack a healing debuff: "
        .. "get OUT, it kills in 2-3 ticks. Kill it, or have the off tank take it aside.\n\n"
        .. "UPSTAIRS (about every 90s): 4 assigned players go up and kill the spheres within 60 seconds or it's a wipe. See 'Pinnacle: Upstairs Team'.\n\n"
        .. "SHADES (75% and below): He splits into 4 around the tank; the group stays well back.\n\n"
        .. "CONDUIT SHARDS (60% and below): Lightning shards drain resources. Kill them the moment they spawn.\n\n"
        .. "CHARGING CENTURION (40% and below): Kill it, or kite it wide around the room.",
    "Hold him still, facing away. SHADES: each ghost turns solid in turn; block FACING the solid one each time, or its sweep goes through you into the group.",
    "Heal through meteors and the staff splash; keep the upstairs team alive.",
    "Interrupt Charging Up. Out of the steam. Kill shards on sight.",
    "[Pinnacle] Interrupt the charge. Out of steam. Kill shards. Upstairs team ready.",
    { challenges = { { name = "Power House", text = "Never use generator energy to break a Refabricated Sphere's shield." } } })

addBoss("Archcustodian", HOF, "Archcustodian", {"Spider"},
    "The spider. You can only damage it while it's stunned: hit the switch on the wall to knock it down.",
    "SHIELD: When it stands back up it walks with a damage shield; touching it kills you. RUN. Each switch makes it faster.\n\n"
        .. "ADDS: Two spawn each time it stands up. Pull them away from the spider (near it they get a huge shield) and kill them. "
        .. "Don't drop taunt: they pull players to them and hit very hard. Keep them facing away (cleave). "
        .. "The two-hander reflects projectiles while shielded.\n\n"
        .. "STAY IN FRONT: Too far away or behind it and you get hit by lethal long-range attacks.\n\n"
        .. "SPINNING BLADES: Step out (pad centers are safe) or dodge roll through. Blocking still gives you the bleed.\n\n"
        .. "Tip: you don't have to hit the switch right away; kill the adds and build ultimates first.",
    "There's no taunting the spider; hold the adds facing away and keep them off it.",
    "Ground HoTs for the blade bleeds.",
    "Burn while it's down. Stay in front, never behind or too far.",
    "[Archcustodian] Switch = stun = burn. Shielded = RUN. Stay in front.",
    { challenges = { { name = "Arc-Custodian", text = "Use 6 or fewer Shock Pylons, never missing a chance to disable it." } } })

addShared({"Reactor", "Reclaimer", "Reducer"}, HOF, "The Refabrication Committee", {"Refabrication Committee", "Committee"},
    "The progress halter. Three bosses: Reclaimer stays in the middle; tanks keep the Reactor and Reducer apart. Plan: 'Committee: The 70/40/27% Plan'.",
    "BOMBERS: Slow adds walk to the Reclaimer; if they reach him they charge a player and explode (one-shot). KILL THEM before they arrive. "
        .. "Shields, blocking or Mist Form survive it.\n\n"
        .. "RECLAIMER: Never stand in his damage shield.\n\n"
        .. "REDUCER: Fire swings launch 3 fast fire AoEs. Watch your feet.\n\n"
        .. "REACTOR: Sword slam spawns claw AoEs that grab you. Stay out.\n\n"
        .. "PHASES: Bring all three to ~71/41/27%, then together into the middle so their beams stun them, and burn. Under 25%: Reclaimer first.",
    "Hold your boss apart from the others, block its heavy. AGGRO SWAP: when the bubbles show on you, tanks SWAP the Reactor and Reducer fast "
        .. "(10 stacks kills you).",
    "Each team's healer stays with their side. Big heals during the stun burn.",
    "Bombers first, always. Stop damage at ~71/41/27% to line them up.",
    "[Committee] Kill bombers. Tanks swap on bubbles. Line all 3 up at 71/41/27%.",
    { challenges = { { name = "Planned Obsolescence", text = "Never let the Reclaimer overcharge a Ruined Factotum." } } })

addBoss("Assembly General", HOF, "Assembly General", {"General"},
    "Long fight with no real DPS check. Survival wins. Tank in front; the group sits up on the ledge UNDER the flame arm.",
    "STOMP: He knocks the tank back. Get back in range fast: 3 double-stomps in a fight kill everyone.\n\n"
        .. "ADDS: Waves in pairs. Arm falls off before a recharge = STOP damage, clear adds.\n\n"
        .. "RECHARGE (85/65/45%): He REFLECTS all damage: STOP hitting him. Kill 2 of the 4 terminals; avoid the poison at the edges.\n\n"
        .. "FACSIMILES: Each death spawns a copy of that player's class. Kill it fast.\n\n"
        .. "EXECUTE (25%): DPS in pairs at the ends of the 4 tracks, tanks and healers in the corners. Survive the meteors.\n\n"
        .. "Full plan: 'Assembly General: Phases' in the menu.",
    "Stay in range after his stomp. Choose whether an off tank takes the spinning blade arm or you eat it.",
    "Survival is the whole fight. Stagger big heals and shields in recharge and execute.",
    "Stop damage during recharge (he reflects). Kill terminals. Pair up on a track for execute.",
    "[Assembly General] Recharge = STOP damage, kill 2 terminals. Execute: pairs on the tracks, survive.",
    { challenges = {
        { name = "Terminal Terminator", text = "Never let a Terminal complete its activation." },
        { name = "Environmentally Conscious", text = "No one dies to traps or hazards." },
    } })

PullCardData.setIntro(HOF,
    "- Hunter-Killers: one tank per boss, opposite sides. EVERYONE interrupts Take Aim (it one-shots). Bring Purify or purge.\n"
        .. "- Pinnacle Factotum: assign the 4-person upstairs team (60 second limit). Read 'Pinnacle: Upstairs Team'.\n"
        .. "- Committee: two teams of 6 on the Reactor and Reducer. Kill bombers. Read 'Committee: The 70/40/27% Plan'.\n"
        .. "- Assembly General: survival over DPS. STOP damage while he recharges.")

-- =============================================================================
-- Asylum Sanctorium (Clockwork City)
-- Modes: +0 = kill Llothis (left path) and Felms (right path) first, then Olms.
-- +1 = kill one, leave the other; +2 = go straight to Olms's gate.
-- Minis left alive JOIN the Olms fight (Llothis after the 90% jump, Felms after 75%):
-- their "Joins" combo cards pop when their health bar appears next to Olms.
-- =============================================================================
local AS = "Asylum Sanctorium"
addDungeon(AS, "trial", { group = "Clockwork City" })
local OLMS, LLOTHIS, FELMS = "Saint Olms the Just", "Saint Llothis the Pious", "Saint Felms the Bold"

addBoss(LLOTHIS, AS, "Saint Llothis the Pious", {"Llothis"},
    "Left path from the entrance. One tank on Llothis, one holding his 2 robot adds to the side; group in a CLOSE semi-circle behind him.",
    "POISON CONE: He targets one player (glowing green). THAT player stands completely STILL and blocks; everyone else gets away. "
        .. "Staying close to him keeps the cone's thin end small.\n\n"
        .. "CHANNEL: He raises his hand, bursts and knocks everyone back, then channels heavy poison. INTERRUPT it when you see the hand go up.\n\n"
        .. "TELEPORT: He jumps to one of 3 spots and leaves a nasty poison circle. Roll out and re-form on him.\n\n"
        .. "ROBOTS: The 2 adds enrage if left too long. Kill them when active (safe), or a strong tank holds them. Frontal attacks and a hover stomp one-shot DPS.",
    "Main: keep him facing away, block his charged poison shot. Off tank: hold both robots to the side, facing away.",
    "Heal the cone target; heal through the post-channel damage if the interrupt is late.",
    "Interrupt the channel. Cone on you = stand still and block. Kill robots when they're up.",
    "[Llothis] Cone on you = STAND STILL + block. Interrupt the hand-raise.",
    { challenges = { { name = "Imperfect Attendance", text = "Defeat Llothis without dismantling his Imperfect Attendants." } } })

addBoss(FELMS, AS, "Saint Felms the Bold", {"Felms"},
    "Right path. Tank holds him back to the wall in the middle; group HARD STACKED in the center. 3 kiters on the edges (left, middle, right).",
    "BIG BOOM: He throws 2 orbs at the group. Stay HARD stacked so they land together, SPRINT out before they land, then come straight back IN. "
        .. "Whoever wanders off drags the boom onto others.\n\n"
        .. "TELEPORT: He jumps to a kiter and drops a big DoT + Minor Maim circle (1 kiter from 100%, 2 from 75%, 3 from 50%). "
        .. "Kiter: block or roll, step to a new spot; go back once he jumps again. Keeps the circles out of the group.\n\n"
        .. "SHADOWS: 2 at a time, stronger as his health drops (deadly under 25%). Stack them on him and KILL THEM FIRST. "
        .. "Whirlwind: step out or BLOCK.",
    "Back to the wall, hold him still. Off tank can be the middle kiter.",
    "Heal the kiters and the group after each boom.",
    "Out on the boom, back in right away. Shadows before the boss.",
    "[Felms] Hard stack, sprint out on boom, back IN. Kill shadows. Kiters bait jumps.",
    { challenges = { { name = "Placid Projections", text = "Defeat Felms without letting either Pneuma Projection enrage." } } })

addBoss(OLMS, AS, "Saint Olms the Just", {"Olms"},
    "The robot chicken. Tank holds him to one side facing away; group in a strict semi-circle behind. Kiters at the front and back. "
        .. "Know where the front (gate) and back (fence) safe spots are.",
    "PROTECTORS: Small Dwemer drones = TOP priority. While any are alive he's invulnerable (with minis up: 2 = mini immune, 3 = everything immune).\n\n"
        .. "FAN OUT: He flaps up into the air and you drop 4 lightning AoEs. Everyone walks straight BACKWARDS from the semi-circle, then comes back in. "
        .. "Don't cross anyone's path. Avoid his ground shots too.\n\n"
        .. "JUMP (91/76/51/26%): He jumps side to side. Group and back kiter run to the nearest safe spot (front or back) and BLOCK the quake.\n\n"
        .. "LIGHTNING CIRCLE: Every ~30s on the furthest player (a kiter). Step out at once: it drains health and resources. Mist Form helps.\n\n"
        .. "FIRE (25% and below): Left, right, then front or back of the room explode. Hold the semi-circle and step to the gap.\n\n"
        .. "Fire pot spiders: just keep DoTs down.",
    "Face him away; step sideways out of his steam breath (don't eat it). Block the heavy. Keep him from turning so you end up behind (tail whip).",
    "One healer behind the tank, one behind the group. Heal tank and fire DoTs.",
    "Protectors first, always. Fan out backwards. Block on the jumps.",
    "[Olms] Kill protectors. Fan out = walk backwards. Jumps = safe spot + block.")

addCombo({OLMS, LLOTHIS}, AS, "Llothis Joins (+1/+2)",
    "Llothis left alive joins Olms after the 90% jump: 10 million health, 3 minutes to sit him down before he enrages.",
    "PRIORITY: Protectors > Llothis > Olms.\n\n"
        .. "SIT HIM DOWN in under 3 minutes (low DPS check, but mechanics slow you). He stays down 45 seconds, then returns at full health.\n\n"
        .. "His mechanics come too: cone target STANDS STILL and blocks; INTERRUPT the channel; roll out of teleport poison.\n\n"
        .. "With Felms also up: kill them close together for 45 seconds of quiet.",
    "Off tank: stack Llothis on Olms so AoE hits both.",
    "Heal the cone target.",
    "Focus Llothis (after protectors). Interrupt his channel.",
    "[Llothis joins] Sit him down in 3 min. Interrupt channel. Protectors first.",
    { challenges = { { name = "Righteous Condemnation", text = "Defeat Olms and Llothis in the same battle." } } })

addCombo({OLMS, FELMS}, AS, "Felms Joins (+1/+2)",
    "Felms left alive joins Olms after the 75% jump: 10 million health, 3 minutes to sit him down before he enrages.",
    "PRIORITY: Protectors > Felms > Olms.\n\n"
        .. "SIT HIM DOWN in under 3 minutes. He stays down 45 seconds, then returns at full health.\n\n"
        .. "No shadows this time, but his TELEPORT drops the maim circle: back kiter takes it (block or roll). "
        .. "His BIG BOOM targets individuals: step out of it.\n\n"
        .. "With Llothis also up: kill them close together for 45 seconds of quiet.",
    "Off tank: stack Felms on Olms if you can.",
    "Watch the kiter after each teleport.",
    "Focus Felms (after protectors). Step out of the boom.",
    "[Felms joins] Sit him down in 3 min. Kiter takes the jump. Protectors first.",
    { challenges = {
        { name = "Executioners' Judgment", text = "Defeat Olms and Felms in the same battle." },
        { name = "Beatific Beatdown", text = "+2: kill all three together without Felms or Llothis enraging." },
    } })

PullCardData.setIntro(AS,
    "- PICK YOUR MODE: +0 = kill Llothis (left path) and Felms (right path) first. +1 = kill one, leave the other. "
        .. "+2 (hard mode) = skip both and go straight to Olms's gate.\n"
        .. "- Minis left alive JOIN Olms: Llothis after the 90% jump, Felms after 75%. A card pops when each joins.\n"
        .. "- Assign: Olms front and back kiters; Felms's 3 kiters (left, middle, right).\n"
        .. "- Always: Protectors first. Fan out = walk backwards. Never crowd each other.")

-- =============================================================================
-- Cloudrest (Summerset)
-- Minibosses: Siroria (fire), Relequen (lightning), Galenwe (ice), each with a
-- gryphon; final: Z'Maja. +1/+2/+3 = knights left alive JOIN the Z'Maja fight
-- (+3: 75/50/25%, +2: 65/35%, +1: 50%); "Joins" combo cards pop as they arrive.
-- VERIFY: whether health bars read "Shade of Siroria" or "Siroria" (both accepted),
-- and the gryphons' exact names.
-- =============================================================================
local CR = "Cloudrest"
addDungeon(CR, "trial", { group = "Summerset" })
local ZMAJA = { "Z'Maja", "Shade of Z'Maja" }
local SIRORIA = { "Shade of Siroria", "Siroria" }
local RELEQUEN = { "Shade of Relequen", "Relequen" }
local GALENWE = { "Shade of Galenwe", "Galenwe" }

PullCardData.addGuide(CR, "Portals (every fight)",
    "TEAMS: Pre-plan TWO portal teams of 3-4 (a healer is fine). Teams alternate: after a portal, that team gets a debuff and can't go down next time.\n\n"
        .. "DOWNSTAIRS: Break the crystals; some drop an orb. Each orb makes a spear appear UPSTAIRS; someone upstairs takes the synergy "
        .. "to send it down. Only THEN pick up the orb (too early = huge damage) and drop it in the spear. Do it 3 times, then the portal closes.\n\n"
        .. "Downstairs damage is oblivion: shields don't work, bring your own heals. Adds come up while you're down there, more the longer you take. "
        .. "A failed portal releases many giant Yaghra: usually a wipe.\n\n"
        .. "Z'MAJA'S PORTAL: More crystals, some fake. A Shade of Z'Maja is downstairs: the TANK goes in first and taunts her, or she one-shots people. "
        .. "When the big spreading boom comes, take the wind synergy up to a ledge, then come back down before the ledge explodes. "
        .. "Success = Yaghra come up (kill them). Failure = everyone dies.\n\n"
        .. "Tip: with 3 tanks, one stays on Z'Maja, one kites darkness and adds, and the spare alternates going down.")

-- Shared by all three knight fights.
local KNIGHT_COMMON = "\n\nGRYPHON: Hit the gryphon unless it's in the air (then the knight). Find gaps in its fanning burst AoEs; stay out of its front cone and slam.\n\n"
    .. "PORTAL: Your assigned team goes down (see 'Portals (every fight)').\n\n"
    .. "EXECUTE: Get BOTH low before killing either; a lone survivor spawns rooting creepers that keep growing."

addShared({"Shade of Siroria", "Siroria", "Shade of Silaeda", "Silaeda"}, CR, "Siroria & Silaeda", {"Siroria"},
    "Fire knight and gryphon. Two tanks: knight on one side, gryphon on the other (together they enrage). She teleports a lot.",
    "HUG ME: A spreading yellow circle on one player kills them unless 3+ players STACK on them. Stand still and let the group come to you.\n\n"
        .. "STANDARD: She drops a Dragonknight Standard: stay out (tank, drag her out of it).\n\n"
        .. "LEAP (~50%): Dragon leaps (avoid or block the landing), then 3 slow fire tornadoes. A couple of ticks kill." .. KNIGHT_COMMON,
    "Knight tank: block heavies, keep her out of her standard. Gryphon tank: block or roll its bleed hit.",
    "Heal the hug target's stack and the gryphon's bleed.",
    "Stack on the hug. Gryphon first unless airborne. Avoid tornadoes.",
    "[Siroria] Yellow circle = STACK 3+ on them. Out of her standard. Avoid tornadoes.",
    { challenges = { { name = "Valorous Combustion", text = "Every Roaring Flare is split between at least 6 players." } } })

addShared({"Shade of Relequen", "Relequen", "Shade of Belanaril", "Belanaril", "Shade of Velanaril", "Velanaril"}, CR, "Relequen & his gryphon", {"Relequen"},
    "Lightning knight and gryphon. Same setup: two tanks, kept apart.",
    "SWAP BARS: Big blue lightning beam on you = you're overcharged and zap everyone within ~20m. SWAP BARS and stay there until the debuff ends.\n\n"
        .. "LIGHTNING CHANNEL: Spreading lightning AoEs on everyone: just INTERRUPT him.\n\n"
        .. "STAFF FLIP: Shock sparks fly across the floor; step around them (stuns). Cone: block or roll." .. KNIGHT_COMMON,
    "Block his heavy (staff flip). Keep him away from the gryphon.",
    "Watch for players who didn't swap bars.",
    "Lightning on you = SWAP BARS. Interrupt the channel.",
    "[Relequen] Blue lightning on you = SWAP BARS. Interrupt channel.",
    { challenges = { { name = "Shocking Instinct", text = "No one is hit by Voltaic Overload or spreads Voltaic Current." } } })

addShared({"Shade of Galenwe", "Galenwe", "Shade of Falarielle", "Falarielle"}, CR, "Galenwe & Falarielle", {"Galenwe"},
    "Ice knight and gryphon. Same setup: two tanks, kept apart.",
    "HOARFROST: A small spinning wind hurts the group. Someone picks it up, holds it ~6 seconds, then drops it (synergy) outside the group. "
        .. "A DIFFERENT player picks it up next; 3 times per phase. Never take it into the portal.\n\n"
        .. "METEORS: 3 players targeted: SPREAD to empty space and BLOCK until it lands." .. KNIGHT_COMMON,
    "Block heavies; keep him away from the gryphon.",
    "Heal the hoarfrost carrier.",
    "Take your turn with the hoarfrost. Spread on meteors.",
    "[Galenwe] Hoarfrost: pick up, drop outside, next person. Spread for meteors.",
    { challenges = { { name = "The Mystic's Ice", text = "Have Galenwe's shade destroy 20 roaming Hoarfrost cyclones with Spiked Ice." } } })

addBoss("Z'Maja", CR, "Z'Maja", {"Zmaja"},
    "Final boss; she teleports constantly. What matters is which way she FACES: always away from the group. Group flanks, never in her sight.",
    "ORBS: Groups of 3 orbs float toward her, all fight. TOP PRIORITY: kill them before they burst into stunning mini-orbs; never touch them.\n\n"
        .. "DEATH SHADOWS: When someone dies, KILL THEIR SHADOW FIRST, then rez. Rezzing first one-shots you.\n\n"
        .. "DARKNESS: The 2 furthest players get a chasing dark AoE. Kite it in a circle, away from the group (ideally an off tank and a far healer).\n\n"
        .. "PIZZA (below 60%): Cone AoEs from the middle portal pull you down (or up). Get out.\n\n"
        .. "PORTAL: Tank goes down first and taunts the shade (see 'Portals (every fight)').\n\n"
        .. "CREEPERS (40% and below): Rooting adds, now as important as orbs.\n\n"
        .. "EXECUTE: The Shade of Z'Maja comes through the portal at full health: a new fight. Split on either side of her tail. "
        .. "MARKED BANE hits 6 players at a time (health to ~50%, healing done cut): heal each other to full to clear it.",
    "Long-range taunt on the way to each teleport; hug the edge so she faces you and away from the group. Block or shield her orb blast.",
    "Marked Bane is a healer check: big AoE heals, burst, stacked Echoing Vigor. Heal to 100% to clear it.",
    "Orbs before anything. Flank her. Kill shadows before rezzing.",
    "[Z'Maja] Kill orbs first. Face her away. Kill shadow THEN rez. Out of pizza.",
    { challenges = { { name = "One Core, No More", text = "Each player picks up and destroys only one Malevolent Core." } } })

-- Knights left alive join Z'Maja (+1/+2/+3). Their own mechanics stay for the
-- whole fight; once killed they stay dead.
addCombo({ZMAJA, SIRORIA}, CR, "Siroria Joins (+1/+2/+3)",
    "Siroria arrives (+3: 75%, +2: 65% or 35%, +1: 50%). Only the knight is a target, not her gryphon.",
    "Simplest: take her AWAY from Z'Maja, kill her, come back. She stays dead.\n\n"
        .. "HUG ME stays all fight: yellow circle = 3+ STACK on them. In execute you get TWO: keep the group in two halves so they don't overlap.",
    "Off tank: pull her away from Z'Maja.", "Heal the hug stacks.", "Burn her away from Z'Maja. Stack on the hug.",
    "[Siroria joins] Take her away and kill her. Hug = stack 3+.")

addCombo({ZMAJA, RELEQUEN}, CR, "Relequen Joins (+1/+2/+3)",
    "Relequen arrives (+3: 50%, +2: 65% or 35%, +1: 50%). Only the knight is a target.",
    "Take him away from Z'Maja and kill him; he stays dead.\n\n"
        .. "SWAP BARS stays all fight: blue lightning on you = swap and stay. Interrupt his channel. Two halves in execute.",
    "Off tank: pull him away from Z'Maja.", "Watch for missed bar swaps.", "Burn him away from Z'Maja. Lightning = swap bars.",
    "[Relequen joins] Take him away and kill him. Lightning = SWAP BARS.")

addCombo({ZMAJA, GALENWE}, CR, "Galenwe Joins (+1/+2/+3)",
    "Galenwe arrives (+3: 25%, +2: 65% or 35%, +1: 50%). Only the knight is a target.",
    "Take him away from Z'Maja and kill him; he stays dead.\n\n"
        .. "HOARFROST stays all fight: pick up, drop outside the group, next person. In execute there are TWO: keep the group in two halves.",
    "Off tank: pull him away from Z'Maja.", "Heal the hoarfrost carriers.", "Burn him away from Z'Maja. Take your hoarfrost turn.",
    "[Galenwe joins] Take him away and kill him. Hoarfrost turns.",
    { challenges = { { name = "A Sload and Her Shadow", text = "+1: defeat Z'Maja with one Welkynar shade by her side." },
                     { name = "Three's Deadly Company", text = "+2: defeat Z'Maja with two Welkynar shades by her side." } } })

PullCardData.setIntro(CR,
    "- PICK YOUR MODE: kill knights first for +0; any knight left alive joins Z'Maja (+1/+2/+3). Joining knights get their own card when they arrive.\n"
        .. "- ASSIGN two portal teams of 3-4; they alternate. On Z'Maja the tank goes down first.\n"
        .. "- Relequen: blue lightning on you = SWAP BARS. Siroria: yellow circle = STACK 3+ on them.\n"
        .. "- Z'Maja: kill orbs first, and kill a dead player's shadow BEFORE rezzing them.")

-- =============================================================================
-- Sunspire (Elsweyr) - framework; boss mechanics to be added.
-- Bosses: Lokkestiiz (frost), Yolnahkriin (fire), Nahviintaas (final).
-- Hard mode: extinguish each dragon's offering braziers; Nahviintaas's hard mode
-- opens after the other two are beaten on hard mode.
-- =============================================================================
local SS = "Sunspire"
addDungeon(SS, "trial", { group = "Elsweyr" })

-- "Before you start" cards: pop on zoning in, for trials with walkthrough rows.
PullCardData.setIntro(HRC,
    "- TRASH: Interrupt Flame Shapers the moment they raise their staff (everyone, not just the tank). Stay behind gargoyles and get out after their 2nd breath.\n"
        .. "- Yokeda Kai: assign one DPS to each of the 4 positions; interrupt your add. BLOCK the pulsar, never dodge roll it.\n"
        .. "- The Warrior: stack in a straight line. Hard mode = NO SYNERGIES all fight; read 'The Warrior: Hard Mode Plan' first.")

PullCardData.setIntro(SO,
    "- TRASH: Overchargers die first, always; kill the Shaman's totem, not the Shaman. Dodge troll boulders; poisoned players stand aside.\n"
        .. "- Mantikora: don't overtaunt; popcorn = run backwards; block the stomp.\n"
        .. "- Ozara: free pinned players; kill the totem, never the Shaman.\n"
        .. "- The Serpent: assign who goes left/right for orbs, and plan Lamias, Mantikoras and totems (see 'The Serpent: Adds & Totems').")

PullCardData.setIntro(MOL,
    "- Zhaj'hassa: assign 2 people per cleanse pad (6 pads); tanks and healers cleanse first.\n"
        .. "- Twins: split into two teams of 6 (1 tank, 1 healer, 4 DPS). Tanks: remember your ORIGINAL boss. Read 'Twins: How the Colors Work'.\n"
        .. "- Rakkhat: assign every DPS a pad 1-8, 2-3 runners and 2-3 meteor kiters. Assign lunar beamers (Tank 1: pads 1-3, Tank 2: 4-6, Healer 1: 7-8). "
        .. "Read 'Rakkhat: Lunar Phase' and 'Runners & Curses'.")

-- Hard modes (final boss only). Applied once the boss entries exist; until then
-- these are no-ops.
setHM("Aetherian Archive", "The Mage",
    "Smash the three blue Aetherial Orbs on the pedestals at the teleport pad before the fight. Adds:\n"
        .. "- METEORS land on players: BLOCK or get stunned.\n"
        .. "- STORM ATRONACHS keep coming: kill them fast (tank can hold 2-3 near the boss, but keep the gap). "
        .. "At low health they spam lightning AoE, so execute them quickly.",
    "Aetherian Archive Difficult Mode")
setHM("Hel Ra Citadel", "The Warrior",
    "Destroy the statues before his chamber. NO SYNERGIES all fight (a stoned player's synergy kills the group). "
        .. "Aim his shield throw at the gargoyle statues. Full plan: 'The Warrior: Hard Mode Plan' in the menu.",
    "Hel Ra Citadel Difficult Mode")
setHM("Sanctum Ophidia", "The Serpent",
    "Burn the two Sacred Banners on either side of the staircase before the fight. Adds WORLD SHAPER: "
        .. "a green ball grows above his raised hand. NOBODY MOVES yet; stay close. The moment it LEAVES his hand, everyone sprints away; "
        .. "come back after it lands. Run early and you drag it onto others; run late and you die.",
    "Sanctum Ophidia Difficult Mode")
setHM(MOL, "Rakkhat",
    "Empower him at the lunar shrines. Meteors hit MUCH harder (kite them). An ASSASSIN spawns for every 2 Void Callers killed: "
        .. "kill it fast, BLOCK its spin. No cleanse pads; cursed players hit anyone near them.",
    "Maw of Lorkhaj Difficult Mode")
setHM(HOF, "Assembly General",
    "Reset the circuit breaker before the fight. More health and a couple more adds; otherwise the same fight.",
    "Mechanic's Machinations")

-- Hard modes for the trials still waiting on mechanics: these apply automatically
-- once the boss entries above exist (until then they do nothing).
setHM(AS, "Saint Olms the Just",
    "+2: engage Olms with BOTH Llothis and Felms alive (go straight to his gate) and kill all three in the same fight. "
        .. "Olms's own mechanics don't change; watch for the 'Joins' cards.",
    "Asylum Sanctorium Vanquisher")
setHM(CR, "Z'Maja",
    "+1 / +2 / +3: leave Siroria, Relequen and/or Galenwe alive and they join Z'Maja (+3: 75/50/25%, +2: 65/35%, +1: 50%). "
        .. "Take each away and kill it; they stay dead. +3 = all three.",
    "More the Merrier")
setHM(SS, "Lokkestiiz",
    "Extinguish his offering braziers before the fight (Nahviintaas flies down to help him).",
    "Stormchaser")
setHM(SS, "Yolnahkriin",
    "Extinguish his offering braziers before the fight (Nahviintaas flies down to help him).",
    "Stoking the Fire")
setHM(SS, "Nahviintaas",
    "Only available after beating Lokkestiiz and Yolnahkriin on hard mode: extinguish his braziers too.",
    nil) -- its achievement shares the name "Sunspire Vanquisher" with the normal one, so no status shown
