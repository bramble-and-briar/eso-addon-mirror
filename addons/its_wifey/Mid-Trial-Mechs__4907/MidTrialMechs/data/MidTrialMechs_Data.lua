MidTrialMechs = MidTrialMechs or {}
local MTM = MidTrialMechs

MTM.trialOrder = {
    "Aetherian Archive",
    "Asylum Sanctorium",
    "Cloudrest",
    "Dreadsail Reef",
    "Halls of Fabrication",
    "Hel Ra Citadel",
    "Kyne's Aegis",
    "Lucent Citadel",
    "Maw of Lorkhaj",
    "Ossein Cage",
    "Rockgrove",
    "Sanctum Ophidia",
    "Sanity's Edge",
    "Sunspire",
}

local function placeholders(order)
    local bosses = {}
    for _, boss in ipairs(order) do
        bosses[boss] = { "Mechanics not added yet. Edit this text and SAVE EDIT when ready." }
    end
    return { order = order, bosses = bosses }
end

MTM.trials = {
    ["Aetherian Archive"] = placeholders({
        "Lightning Storm Atronach", "Foundation Stone Atronach", "Varlariel", "The Mage",
    }),
    ["Hel Ra Citadel"] = placeholders({
        "Ra Kotu", "Yokeda Rok'dun", "Yokeda Kai", "The Warrior",
    }),
    ["Sanctum Ophidia"] = placeholders({
        "Possessed Mantikora", "Stonebreaker", "Ozara", "The Serpent",
    }),
    ["Maw of Lorkhaj"] = placeholders({
        "Zhaj'hassa the Forgotten", "Vashai & S'kinrai", "Rakkhat",
    }),
    ["Halls of Fabrication"] = placeholders({
        "Hunter-Killer Negatrix & Positrox", "Pinnacle Factotum", "Archcustodian", "Refabrication Committee", "Assembly General",
    }),
    ["Asylum Sanctorium"] = placeholders({
        "Saint Felms the Bold", "Saint Llothis the Pious", "Saint Olms the Just",
    }),
    ["Cloudrest"] = placeholders({
        "Galenwe", "Relequen", "Siroria", "Z'Maja",
    }),
    ["Sunspire"] = placeholders({
        "Lokkestiiz", "Yolnahkriin", "Nahviintaas",
    }),
    ["Kyne's Aegis"] = placeholders({
        "Yandir the Butcher", "Captain Vrol", "Lord Falgravn",
    }),
    ["Rockgrove"] = placeholders({
        "Oaxiltso", "Flame-Herald Bahsei", "Xalvakka",
    }),
    ["Dreadsail Reef"] = placeholders({
        "Lylanar & Turlassil", "Reef Guardian", "Taleria the Tideborn",
    }),
    ["Sanity's Edge"] = placeholders({
        "Exarchanic Yaseyla", "Archwizard Twelvane", "Ansuul the Tormentor",
    }),
    ["Lucent Citadel"] = {
        order = {
            "Count Ryelaz & Zilyesset",
            "Cavot Agnan",
            "Orphic Shattered Shard",
            "Arcane Knot / Xoryn",
        },
        bosses = {
            ["Count Ryelaz & Zilyesset"] = {
                "Split evenly. DARK/Ryelaz: block Gloomy Impact; gold glow -> skeleton to break shield. LIGHT/Zilyesset: red glow -> bug to break shield. Adds can't be taunted. SIDE SWAP: 3 pads activate; use mirror to find correct pad and get on QUICKLY. If unsure, follow group. Both sides do pads together.",
            },
            ["Cavot Agnan"] = {
                "Stay out of his large AOE. If you get Darkness, take it to a floating crystal at the edge of the room. Atro spawns -> kill it.",
            },
            ["Orphic Shattered Shard"] = {
                "Main mech = MIRRORS. Each DPS has N/S/E/W/NE/NW/SE/SW. Mirrors must be OPPOSITE the color of the boss/add we're fighting. First swap is at pull; more swaps happen during fight. After EVERY swap return MIDDLE for heals - bad DOT. E+W appear at 90%; N+S at 60%. Ignore Xoryn.",
            },
            ["Arcane Knot / Xoryn"] = {
                "KNOT: someone carries it at all times. Vet: 60 sec carry, then 3 min cooldown; next person grabs it. If carrier dies, grab it QUICKLY. Wipe during Knot run = restart run. Knot continues during Xoryn. LINES: stand still; don't cross another player's line. CURRENT: pass to another DPS - NOT Knot carrier or tanks.",
            },
        },
    },
    ["Ossein Cage"] = placeholders({
        "Shapers of Flesh", "Jynorah & Skorkhif", "Overfiend Kazpian",
    }),
}


-- Authored mechanics imported from Wifey's working SavedVariables on 2026-09-27.
-- Encounters not listed here keep their placeholder/default text.
local authored = {
    ["Aetherian Archive"] = {
        ["The Mage"] = "STACK behind boss. Tanks handle Axes. Avoid ground AOEs. Kill Reflection when called. EXECUTE: stack tight, burn boss and stay in heals.",
        ["Foundation Stone Atronach"] = "Stay behind boss. Avoid frontal attacks/AOEs. Kill adds and stay stacked for heals.",
        ["Varlariel"] = "When CLONES spawn around the room, DPS kill clones QUICKLY. Return to middle. Any clones left alive empower the incoming group explosion.",
        ["Lightning Storm Atronach"] = "Stay stacked on boss. When a SAFE PAD lights up, move to it QUICKLY for Lightning Storm. Block the large expanding AOE from boss. Return to boss after storm.",
    },
    ["Hel Ra Citadel"] = {
        ["Yokeda Rok'dun"] = "Kill/cleave Welwas. Avoid fire AOEs. DO NOT stand directly behind Welwas. Stay with group and burn boss/adds as called.",
        ["Ra Kotu"] = "STACK behind boss. Avoid ground AOEs. When boss spins, Do NOT STAND IN IT. Do not run around the room.",
        ["The Warrior"] = "STACK behind boss. BLOCK heavy attacks and avoid ground AOEs. MECH>Starfall, at 35%. He raises his sword, then Starfall puts repeated AOE hits on the players for roughly 4–5 seconds. Do not overlap each other's Starfall AOEs. BLOCK-SELF HEAL IF POSSIBLE.",
        ["Yokeda Kai"] = "Boss splits into copies. Find the BOSS, the copies will have a solid health bar. INTERRUPT dangerous fire channels. Stay stacked with group for heals. Do not stand in AOE or drop them in group.",
    },
    ["Dreadsail Reef"] = {
        ["Taleria the Tideborn"] = "DELUGE: White bubbles on you = get fully in WATER before explosion—DON'T JUMP IN. GET OUT fast; fish kill. MAELSTROM: STACK with group/healers. TORNADO WALL: rotate around room WITH GROUP>follow OFF TANK. SIRENS: BREAK FREE & KILL. PORTALS 50/35/20%: assigned DPS cross bridge, kill Channeler & portal back. BEHEMOTH: Large AOE>AVOID SLAM.",
        ["Lylanar & Turlassil"] = "FIRE boss = fight inside ICE dome. ICE boss = fight inside FIRE dome. NEVER let FIRE/ICE domes touch. ATRO = stop boss & kill FIRST. Jump phase > DPS grab dome OPPOSITE boss & BASH boss. Don't grab too early—dome has a cooldown. SPLIT PHASE: help healers hold/swap dome. BRAND: Will be on your feet; pair with OPPOSITE color OUTSIDE domes.",
        ["Reef Guardian"] = "STATIC stacks: go into CLEAR zone, let stacks clear, then COME BACK OUT—do not stay there. REEF HEART: when called, jump down CENTER hole. Rocks have SHAPES on them; correct one will be GLOWING. Synergize with it. KILL REEF HEART. Use water spout to return. You get a debuff after returning—DO NOT go down again until it expires.",
    },
    ["Halls of Fabrication"] = {
        ["Hunter-Killer Negatrix & Positrox"] = "TAKE AIM: INTERRUPT spheres immediately—missed interrupt is a one shot (can roll dodge it IF you see it) POISON = HEALERS CLEANSE/PURGE ASAP. Keep bosses EVEN—DO NOT burn one down early. Once one boss dies, the other ENRAGES, so get both low before killing either.",
        ["Pinnacle Factotum"] = "UPSTAIRS: 4 assigned DPS take 1 portal each. GROUP UP. One gets LIGHTNING BEAM—aim beam through Sphere to drop its shield; ALL kill it. Move together & repeat x4. Return to 1 CONSOLE each & SYNERGIZE together on countdown, then portal down. 60 SEC TIMER—BE FAST. If someone dies, backup needs to go ASAP.",
        ["Refabrication Committee"] = "SPLIT LEFT/RIGHT — STAY WITH YOUR GROUP. KEEP BOSSES EVEN. BOMBERS = KILL ASAP before they reach middle. FIRE = DODGE/PURGE. HANDS = GET OUT/BREAK FREE. At 69/39/19% WAIT FOR CALL — bosses come together to STUN, then separate again. DON'T TOUCH MIDDLE BOSS SHIELD. EXECUTE: avoid exploding adds + BURN.",
    },
    ["Ossein Cage"] = {
        ["Jynorah & Skorkhif"] = "RED/BLUE: stay with your assigned side. CURSE: stay with matching group; don't cross colors. Healers turn to heal opposite sides curses. SURGE on you: kite it away. Keep boss HP close. TITANIC CLASH: go up using PAD when called-follow your tank; kill your adds. Return (jump down) to your side after Clash. Watch ground AOEs/fire waves.",
        ["Shapers of Flesh"] = "CHANNELER: priority—kill to drop Shaper shield. BLOBS/FLESHSPAWN: KILL FAST; don't let 2 merge or they make another Abom. HARVESTER: avoid fire wave. Kill Shaper → portal opens. PORTAL TEAM: go in, kill Channeler; kill the add with white beam to reset/clear Carrion stacks. Outside: kill adds/blobs. Repeat for each Shaper.",
        ["Overfiend Kazpian"] = "PORTAL: enter with group & kill Channeler/adds. Cross bridge TOGETHER—it collapses, short timer. BOMBS: random players, take OUT of group. BLUE AOE: STACK with other BLUE players! CHAINS: 2 tethered—spread until GREEN, run tether through giant sword to break. Minis: focus called target/shades & INTERRUPT. Stay stacked unless mechanic says move.",
    },
    ["Lucent Citadel"] = {
        ["Cavot Agnan"] = "Stay out of his large AOE (RADIANCE) occurs every 30 seconds for 6 seconds. If you get Darkness, take it to a floating crystal at the edge of the room. Atro spawns -> kill it.",
        ["Orphic Shattered Shard"] = "Main mech = MIRRORS. Each DPS has N/S/E/W/NE/NW/SE/SW. Mirrors must be OPPOSITE the color of the boss/add we're fighting. First swap is at pull; more swaps happen during fight. After EVERY swap return MIDDLE for heals - bad DOT. E+W appear at 90%; N+S at 60%. Ignore Xoryn.",
        ["Count Ryelaz & Zilyesset"] = "Split evenly. RYELAZ: spread & BLOCK Gloomy Impact. GOLD glow = stand near skeleton 1-2 sec to break shield. ZILYESSET: RED glow = stand near bug 1-2 sec to break shield. SIDE SWAP: 3 pads activate; use mirror to find correct pad & get on QUICK. Unsure? Follow group. Both sides do pads together. BOSSES must die within 10-15 sec or they RESPAWN.",
    },
    ["Kyne's Aegis"] = {
        ["Lord Falgravn"] = "Instability: AOE on you—take out. Mini: dodge fist; BLOCK charge. 90/80%: line from LIT pillar to boss; repeat all 4. At 70%: floor breaks—split 3 Knights evenly. BUBBLE: kill to free player. BLOOD LINES: BLOCK. BARBED WIRE: DON'T MOVE; kill blobs before center. At 35%: drop—STACK behind boss, stay in heals & BURN. Follow Torturer calls.",
        ["Yandir the Butcher"] = "Stay behind boss. FOCUS Sea Adder/Gryphon when called. KILL TOTEMS. POISON TOTEM: DO NOT SPREAD. Stand still, Healers PURGE. STONE TOTEM: BLOCK or BREAK FREE if petrified. Below 50%, boss jumps to tank—follow calls and keep burning.",
        ["Captain Vrol"] = "Stay with group; avoid ICE AOE. (Conduit)-HARPOON: Gets on player furthest from boss, kill it QUICKLY—tethers KILL if left up. INTERRUPT Apothecary. BOAT: ONE assigned player takes portal & kills Conjurer to stop adds, happens every 45 seconds. Below 50%: Spread slightly, BLOCK METEORS, stay in heals & burn boss.",
    },
    ["Maw of Lorkhaj"] = {
        ["Rakkhat"] = "STACK with group. BOMB: circle under you = take it out, explode, return. BLUE ORB tether = move away until gone. NEVER step on blue/gold pads. BACKYARD: if assigned, portal in, use Eyes of Jode at BLUE-FLAME BOWLS to reveal & kill Void Callers; portal back & cleanse on SMALL glowing corner pad. LUNAR: go to assigned pad & kill add. Center Kill Boss",
        ["Vashai & S'kinrai"] = "Group splits LIGHT/DARK. >attack OPPOSITE color. NEVER TOUCH OPPOSITE-COLORED PLAYERS - YOU WILL EXPLODE THE GROUP. COLOR CHANGE: (3 players each side) if your color changes, ROTATE CLOCKWISE to the other group side. PRAYER: If the boss praying has same color as you-- ALL ROTATE CLOCKWISE. If the praying boss is OPPOSITE--STAY",
        ["Zhaj'hassa the Forgotten"] = "STACK on boss. Kill/cleave Panthers. CURSE: go to your assigned cleanse pad. TANK + HEALERS get priority over DPS. When boss raises sword, HIDE BEHIND A PILLAR. During shield phase, burn shield QUICKLY.",
    },
}

for trialName, bosses in pairs(authored) do
    local trial = MTM.trials[trialName]
    if trial then
        for bossName, mechanicText in pairs(bosses) do
            trial.bosses[bossName] = { mechanicText }
        end
    end
end


-- Authored mechanics imported from Wifey's SavedVariables on 2026-10-02.
-- These are shipped defaults; RESET returns to these values.
local savedAuthored = {
    ["Sunspire"] = {
        ["Yolnahkriin"] = "FIRE GROUPS: stay with your assigned LEFT/RIGHT group — DON'T SWAP SIDES after fire hits. BIG HEALS. At 75/50/25% FLIGHT: dragon flies — GET TO OUTER RING FAST; MIDDLE = DEATH. After fire clears, KILL IRON SERVANTS FAST. Kill FLAME ATROS. DRAGON: stay with your group just off center; STAY OUT OF BREATH.",
        ["Lokkestiiz"] = "ICE TOMB (3 total): assigned DPS GET IN TOMB FAST or it explodes/wipes group. Has a cooldown. Healer must HEAL TOMB TO FULL to free them. 80/50/20% FLIGHT: stack at EXIT + KILL STORM ATROS FIRST; their shock AoEs kill ICE ATROS. ICE BEAM: SPREAD + BLOCK. DRAGON: stack just to the side, NEVER CENTER OF BOSS.",
        ["Nahviintaas"] = "90/70/50% PORTALS: 3 assigned DPS go DOWN (Left,Mid,Right) — KILL ETERNAL SERVANT; INTERRUPT HIS CHANNEL. PLAYER PINNED = UNPIN FAST. PORTAL TEAM FAILS = WIPE. 80/60/40% FLIGHT: KILL ADDS FAST, then HIDE BEHIND STATUE for explosion.  33% METEORS: TAKE/DROP OUT OF GROUP.",
    },
    ["Rockgrove"] = {
        ["Oaxiltso"] = "NOXIOUS SLUDGE: screen turns green/poisoned = RUN TO A WATER POOL + CLEANSE. Used pool turns green temporarily — DON'T USE USED GREEN POOL. CHARGE: Oaxiltso charges FARTHEST PLAYER — stay with group unless cleansing. HAVOCREL ADD: keep away from boss + KILL. METEORS: avoid/block — getting hit by both can kill you.",
        ["Flame-Herald Bahsei"] = "CURSE: glowing BLUE? GET AWAY FROM GROUP, go to edge until it explodes, then return — DON'T HIT OTHER PLAYERS. FLESH ABOMINATION = STOP HITTING BOSS, KILL ABOMINATION; leaves permanent AoE. 50% BEHEMOTHS = KILL, MOVE OUT OF DEATH EXPLOSION. 25% PRIME METEOR = DROP EVERYTHING + KILL METEOR ASAP OR FULL WIPE. ",
        ["Xalvakka"] = "WRAITHS = KILL BEFORE THEY REACH BOSS. PURGE SOUL: synergy on you = DROP BLOB OUT OF GROUP. 70% + 40%: RUN UPSTAIRS WITH GROUP before lava fills room; stay together through fire. BOSS SPLITS INTO 3: get close — transparent = FAKE; FIND REAL + BREAK SHIELD. Kill adds. TOP FLOOR: DON'T FALL IN MIDDLE + AVOID METEORS/FIRE.",
    },
    ["Sanity's Edge"] = {
        ["Ansuul the Tormentor"] = "90/70/50/30% MANIC PHOBIA: usually TANK gets ported — KILL ESSENCE MANIFESTATION FAST. Ported player STAY AWAY FROM BOSS UNTIL ADD DIES or you get one-shot. 80/60/40% MAZE: follow safe path + avoid AoEs. PORTAL = 1 TANK + 3 DPS; WAIT FOR CALL. Kill Vanton + return. 20%: 3 ANSUUL COPIES — BURN ALL 3 TO 0.",
        ["Exarchanic Yaseyla"] = "WAMASU + ARCHERS: STOP BOSS + KILL ADDS. WAMASU CHARGE = GET OUT OF PATH. TRUE SHOT = INTERRUPT. FROST BOMB: TAKE OUT OF GROUP — stacking freezes other players; HEAL FROZEN PLAYER TO FULL FAST. 60/35% PORTALS: KILL WRATHS FIRST — ARCHERS TAKE DAMAGE AFTER WRATHS DIE.",
        ["Archwizard Twelvane"] = "TWELVANE: following lightning fields = KITE THEM AWAY FROM GROUP. When she dies, LOOK ABOVE YOUR HEAD — LION/GRYPHON/WAMASU. RUN TO MATCHING SYMBOL/ROOM FAST OR DIE. Inside, WATCH crystals raise/light up then HIT THEM IN SAME ORDER. -ONLY ONE PERSON!! CHIMERA: SPREAD FOR LIGHTNING. INFERNO: fire drops on everyone — MOVE + DON'T STACK FIRE POOLS",
    },
    ["Halls of Fabrication"] = {
        ["Archcustodian"] = "BOSS IS IMMUNE WHILE WALKING — DO NOT TOUCH SHIELD, IT KILLS YOU. Follow group to next pylon. When boss crosses SHOCK LINE + FALLS DOWN = BURN BOSS/ULT. Each stun makes it move FASTER. Between stuns KILL ADDS + KEEP THEM AWAY FROM SHIELD. Stay near group/boss — too far away = deadly SHOCK ATTACK.",
        ["Assembly General"] = "BURN BOSS + KILL ADDS. 85/65/45% REPAIR: boss goes middle + reflects damage — STOP ATTACKING, GET OFF PLATFORM. Follow group on tracks, DON'T STEP IN POISON. KILL TERMINALS when called. 25% EXECUTE: boss goes middle — GO TO ASSIGNED SPOT, STACK/STAY STILL. Meteors hit repeatedly — BIG HEALS/SHIELDS + BURN",
    },
    ["Cloudrest"] = {
        ["Z'Maja"] = "STAY BEHIND Z'MAJA — NEVER IN FRONT. KITE: targets FARTHEST PLAYER — assigned kite stays farthest and takes AoEs away from group. PORTAL: WAIT FOR TANK/CALL. CREEPERS + ORBS = KILL ASAP. If a player dies: kill player's SHADOW BEFORE REZ. EXECUTE: kill SHADE. MARKED BANE = HEAL AFFECTED PLAYERS TO 100%",
        ["Relequen"] = "VOLTAIC OVERLOAD: warning = GET READY. When BLUE LIGHTNING/huge AoE appears on you, SWAP BARS IMMEDIATELY + STAY ON THAT BAR ~10 SEC or you'll zap/kill group. INTERRUPT RELEQUEN when he channels lightning. SAME BOSS/GRYPHON/PORTAL MECHS.",
        ["Siroria"] = "FIRE COMET/HUG: Yellow circle on you = DO NOT RUN AWAY. STAY STILL + GROUP STACK ON YOU. Need at least 3 PLAYERS IN CIRCLE to survive hit. FIRE/STANDARD AoEs — GET OUT. Around 50% Siroria starts leaping — MOVE OUT OF LANDING AoE. SAME BOSS/GRYPHON/PORTAL MECHS.",
        ["Galenwe"] = "HOARFROST: Got ice? When synergy appears, DROP OUT OF GROUP. Next player PICK IT UP FAST; pass through 3 players.  GRYPHON: stay BEHIND, avoid cone/AoEs; DPS BIRD when down, GALENWE when bird flies. PORTAL: assigned group DOWN; break crystals. Upstairs SEND SPEARS; downstairs carry 3 CORES TO SPEARS. KILL BOSS/BIRD CLOSE TOGETHER.",
    },
    ["Ossein Cage"] = {
        ["Overfiend Kazpian"] = "PORTAL: enter with group & kill Channeler/adds. Cross bridge TOGETHER—it collapses, short timer. BOMBS: random players, take OUT of group. BLUE AOE: STACK with other BLUE players! CHAINS: 2 tethered—spread until GREEN, run tether through giant sword to break. Minis: focus called target/shades & INTERRUPT. Stay stacked unless mechanic says move.",
    },
    ["Sanctum Ophidia"] = {
        ["Ozara"] = "PINS: Ozara pins players to ground — YOU CANNOT FREE YOURSELF. If someone near you is pinned, RUN TO THEM + USE REMOVE BOLT SYNERGY ASAP. SPREAD/LOOSE STACK so pins don't overlap. OVERCHARGERS = KILL ASAP and move out of lightning AoEs. TANK/HEALER PINNED = PRIORITY FREE.",
        ["Stonebreaker"] = "STAY BEHIND BOSS + SPREAD OUT. GROUND SLAM/POUND = BLOCK — shockwaves can ONE-SHOT. POISON ON YOU = STAY AWAY FROM OTHERS; DON'T SPREAD IT. OVERCHARGERS: KILL ASAP — spawn at 75/50/25%. If lightning AoE is on you, MOVE AWAY FROM GROUP. At low health boss ENRAGES — BLOCK EVERYTHING.",
        ["The Serpent"] = "STACK BEHIND SERPENT — NEVER IN FRONT. POISON PHASE: stay stacked + HEAL THROUGH IT; KILL ADDS FAST. TOTEMS: kill ones tethered to boss. PULL TOTEM: DODGE ROLL to break pull/snare. MAG BOMB/BLUE GLOW: DUMP MAGICKA FAST TO <10% OR DIE. PINK ORBS/BUBBLES: EVERYONE GRAB ONE FAST OR YOU DIE — DON'T STEAL TANK'S. Return to stack + BURN.",
        ["Possessed Mantikora"] = "POPCORN: circles under you = RUN/DODGE BACK AWAY FROM GROUP — Tosses you in air. 3= DEATH. BIG SLAM >BLOCK, then heal to FULL to clear bleed. POISON SPEARS: target FARTHEST PLAYERS — BLOCK HIT + MOVE OUT, keep pools away from group. BLACK HOLE: if pulled in, KILL SERPENT SHADE FAST; avoid its front. STAY BEHIND MANTIKORA.",
    },
    ["Asylum Sanctorium"] = {
        ["Saint Llothis the Pious"] = "LLOTHIS: CONE target STAND STILL + BLOCK — everyone else GET OUT of cone. INTERRUPT Oppressive Bolts ASAP. He teleports and leaves poison behind — MOVE OUT. Kill adds quickly before they enrage. Stay behind boss when possible; don't drag cone through group.",
        ["Saint Felms the Bold"] = "TELEPORT STRIKES the FURTHEST PLAYER, leaving a nasty lingering SHRAPNEL STORM AoE; his number of consecutive jumps INCREASES AS HIS HEALTH DROPS. MANIFEST WRATH targets players with AoEs that need to be MOVED/SPREAD OUT OF. His PNEUMA PROJECTION ADDS need to DIE QUICKLY BEFORE THEY ENRAGE, and they become MORE DANGEROUS IN EXECUTE.",
        ["Saint Olms the Just"] = "GUST OF STEAM — 90/75/50/25%: Olms jumps/slams 4 TIMES — GET TO ENTRANCE OR EXIT. STORM THE HEAVENS — SPREAD OUT, kite backward in a line so lightning AoEs don't hit you/others. PROTECTOR SPHERE on Olms = BOSS IMMUNE — KILL SPHERES. 25% TRIAL BY FIRE: huge fire AoEs LEFT/MIDDLE/RIGHT — DON'T STAND WHERE THEY OVERLAP. STACK FOR HEALS/PURGE.",
    },
}

for trialName, bosses in pairs(savedAuthored) do
    local trial = MTM.trials[trialName]
    if trial then
        for bossName, mechanicText in pairs(bosses) do
            trial.bosses[bossName] = { mechanicText }
        end
    end
end

function MTM:GetDefaultText(trialName, bossName)
    local trial = self.trials[trialName]
    local lines = trial and trial.bosses[bossName]
    if not lines then return "" end
    local out = {}
    for _, line in ipairs(lines) do out[#out + 1] = "• " .. line end
    return table.concat(out, "\n")
end
