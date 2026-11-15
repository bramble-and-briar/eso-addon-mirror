-- Enumerations (value + label pairs drive both validation and the editor's dropdowns), static game
-- data, and visual constants.

local DT = DebuffTracker
local C = DT.Const
local L = DT.L

-- Each option list: { {value, label}, ... }. C.Values(list) -> set for validation.
function C.Values(list)
    local s = {}
    for _, o in ipairs(list) do s[o[1]] = true end
    return s
end

function C.Label(list, value)
    for _, o in ipairs(list) do if o[1] == value then return o[2] end end
    return tostring(value)
end

------------------------------------------------------------------------------
-- Triggers
------------------------------------------------------------------------------

C.TRIGGER_TYPES = {
    { "effect", L("Buff / debuff") },
    { "combat", L("Ability timer") },
    { "procs", L("My procs") },
    { "resource", L("Resource") },
    { "toggle", L("Toggle on/off") },
    { "stat", L("Stat") },
    { "combatState", L("Combat state") },
    { "tick", L("Resource tick") },
    { "gcd", L("Global cooldown") },
}
-- resources that regenerate in ticks (Resource tick trigger)
C.TICK_POWER_TYPES = {
    { "stamina", L("Stamina") },
    { "magicka", L("Magicka") },
    { "health", L("Health") },
}

-- Load lists that can be switched from "only when" to "never when" (Load tab)
C.LOAD_LIST_GROUPS = {
    { "zones", L("Zones") }, { "roles", L("Roles") }, { "classes", L("Classes") }, { "sets", L("Sets") },
    { "cp", L("Champion skills") }, { "skills", L("Skills") }, { "bosses", L("Bosses") }, { "characters", L("Characters") },
}
C.LOAD_POLARITY = { { "only", L("Only when") }, { "never", L("Never when") } }
C.WEREWOLF_LOAD = { { "any", L("Any") }, { "only", L("Only as a werewolf") }, { "never", L("Never as a werewolf") } }

-- Stat trackers (Core/Stats.lua)
C.STATS = {
    { "penTarget", L("Penetration vs. my target") },
    { "critTarget", L("Critical damage vs. my target") },
    { "pen", L("Penetration (sheet)") },
    { "critDamage", L("Critical damage (sheet)") },
    { "weaponDamage", L("Weapon / spell damage (higher)") },
    { "critChance", L("Critical chance % (higher)") },
    { "physResist", L("Physical resistance") },
    { "spellResist", L("Spell resistance") },
    { "critResist", L("Critical resistance") },
    { "critResistPct", L("Critical resistance % (less crit damage taken)") },
    { "lowestResist", L("Lowest resistance (physical or spell)") },
    { "healthRegen", L("Health recovery (in combat)") },
    { "magickaRegen", L("Magicka recovery (in combat)") },
    { "staminaRegen", L("Stamina recovery (in combat)") },
    { "ultPerSecond", L("Ultimate gained per second (last 10 s)") },
}

-- Meter display: the caption shown above a stat's number (a trigger's own "Label" replaces it), and the
-- colour of the tile's accent line. Recoveries use the game's resource colours; the rest DebuffTracker gold.
C.STAT_CAPTIONS = {
    -- short tags: the number is what you read (Yarden: "too much text, too little size")
    penTarget = L("PEN"), critTarget = L("CRIT DMG"), pen = L("PEN"), critDamage = L("CRIT DMG"),
    weaponDamage = L("POWER"), critChance = L("CRIT"), physResist = L("PHYS RES"),
    spellResist = L("SPELL RES"), critResist = L("CRIT RES"), critResistPct = L("CRIT TAKEN"),
    lowestResist = L("LOWEST RES"), healthRegen = L("HP REGEN"), magickaRegen = L("MAG REGEN"),
    staminaRegen = L("STAM REGEN"), ultPerSecond = L("ULT / S"),
}
C.STAT_ACCENTS = {
    healthRegen = { 0.86, 0.33, 0.30, 1 }, magickaRegen = { 0.33, 0.58, 0.98, 1 }, staminaRegen = { 0.36, 0.78, 0.40, 1 },
}
C.METER_ANIMS = {
    { "off", L("Off") }, { "fast", L("Fast") }, { "standard", L("Standard") }, { "slow", L("Slow") },
}
C.METER_ANIM_MS = { off = 0, fast = 150, standard = 300, slow = 450 }

-- "Show" for toggles: both states, or only one of them
C.TOGGLE_MODES = {
    { "always", L("On and off") },
    { "present", L("Only while on") },
    { "missing", L("Only while off") },
}

C.SCOPES = {
    { "enemies", L("All enemies") },
    { "target", L("Current target") },
    { "boss", L("Bosses") },
    { "player", L("Me") },
    { "group", L("Group members") },
    { "companion", L("Companion") },
}
-- Scopes resolved by scanning a unit tag's buff list (vs. the enemy event store).
C.TAGGED_SCOPES = { target = true, boss = true, player = true, group = true, companion = true }

C.SOURCES = {
    { "any", L("Anyone") },
    { "me", L("Cast by me") },
    { "others", L("Cast by others") },
}

C.EFFECT_TYPES = {
    { "any", L("Buffs and debuffs") },
    { "buff", L("Buffs only") },
    { "debuff", L("Debuffs only") },
}

C.MODES = {
    { "present", L("Show while active") },
    { "missing", L("Show while missing") },
    { "always", L("Always show (checklist)") },
    { "cycle", L("Cycle per unit: first active, else ready") },
}

C.COMBAT_RESULTS = {
    { "any", L("Any hit or effect") },
    { "damage", L("Damage") },
    { "heal", L("Heal") },
    { "gained", L("Effect gained") },
    { "energize", L("Resource gained (energize)") },
    { "drain", L("Resource drained") },
    { "hit", L("Hit (damage or dodged)") },
    { "duration", L("Effect gained with its duration") },
    { "proc", L("Effect gained or a direct hit (like ExoY's)") },
}

C.START_ON = {
    { "combat", L("An action / proc") },
    { "effect", L("A buff on me") },
}

-- kinds of entries in the built-in proc catalogue (Data/Procs.lua)
C.PROC_KINDS = {
    { "set", L("Sets") },
    { "monsterSet", L("Monster sets") },
    { "artifact", L("Mythics") },
    { "stackSet", L("Stacking sets") },
    { "synergy", L("Synergies") },
    { "passive", L("Class passives") },
    { "champion", L("Champion skills") },
}
C.GEAR_PROC_KINDS = { set = true, monsterSet = true, artifact = true, stackSet = true }

C.CALC_MODES = {
    { "none", L("Show the %") },
    { "missing", L("Value from the missing %") },
    { "divide", L("% divided by a number") },
}

C.COMBAT_SOURCES = {
    { "me", L("My actions") },
    { "any", L("Anyone's actions") },
    { "onme", L("Actions on me") },
}

C.RESOURCE_UNITS = {
    { "player", L("Me") },
    { "target", L("Current target") },
    { "boss", L("Bosses") },
    { "group", L("Group members") },
}

C.POWER_TYPES = {
    { "health", L("Health") },
    { "magicka", L("Magicka") },
    { "stamina", L("Stamina") },
    { "ultimate", L("Ultimate") },
}

function C.PowerConstant(name)
    if name == "health" then return POWERTYPE_HEALTH end
    if name == "magicka" then return POWERTYPE_MAGICKA end
    if name == "stamina" then return POWERTYPE_STAMINA end
    if name == "ultimate" then return POWERTYPE_ULTIMATE end
    return POWERTYPE_HEALTH
end

------------------------------------------------------------------------------
-- Displays
------------------------------------------------------------------------------

C.DISPLAY_TYPES = {
    { "bars", L("Bars") },
    { "icons", L("Icons") },
    { "text", L("Text") },
    { "alert", L("Big alert") },
    { "heads", L("Above heads") },
    { "meter", L("Meter") },
}
-- "Above heads" needs a world position, which the game only gives for allies (never enemies).
C.HEAD_SCOPES = { group = true, player = true, companion = true }

C.ICON_TIMERS = {
    { "sweep", L("Dark sweep") },
    { "shrinkV", L("Icon empties downward") },
    { "shrinkH", L("Icon empties to the left") },
    { "none", L("None (just the number)") },
}

C.TIMER_TO = {
    { "part", L("Each part (buff, then cooldown)") },
    { "ready", L("Ready (the whole cooldown)") },
}

C.BAR_STYLES = {
    { "classic", L("Classic") },
    { "clean", L("Clean") },
    { "compact", L("Compact") },
}

C.GROW = {
    { "down", L("Down") },
    { "up", L("Up") },
    { "right", L("Right") },
    { "left", L("Left") },
}

C.SORTS = {
    { "fixed", L("Fixed (list order, not time)") },
    { "expiry", L("Expiring soonest") },
    { "expiryDesc", L("Expiring last") },
    { "order", L("Order applied") },
    { "name", L("Name") },
    { "unit", L("Unit name") },
    { "target", L("My target first (then the newest)") },
}

C.COLOR_MODES = {
    { "gradient", L("Gradient by time") },
    { "tiers", L("Three steps by time") },
    { "solid", L("Single color") },
}

C.TIME_FORMATS = {
    { "auto", L("Automatic") },
    { "tenths", L("Tenths (12.3)") },
    { "seconds", L("Seconds (12)") },
    { "mmss", L("Minutes (1:05)") },
}

C.FONT_FACES = {
    { "MEDIUM_FONT", L("Standard") },
    { "BOLD_FONT", L("Bold") },
    { "CHAT_FONT", L("Chat") },
    { "ANTIQUE_FONT", L("Antique") },
    { "HANDWRITTEN_FONT", L("Handwritten") },
    { "STONE_TABLET_FONT", L("Stone tablet") },
    -- the gamepad UI's faces (esoui fontstrings: FTN47 / FTN57 / FTN87; Casual player Geldis: "im missing gamepad fonts")
    { "GAMEPAD_LIGHT_FONT", L("Gamepad light") },
    { "GAMEPAD_MEDIUM_FONT", L("Gamepad") },
    { "GAMEPAD_BOLD_FONT", L("Gamepad bold") },
}

C.FONT_EFFECTS = {
    { "soft-shadow-thick", L("Soft shadow (thick)") },
    { "soft-shadow-thin", L("Soft shadow (thin)") },
    { "shadow", L("Shadow") },
    { "outline", L("Outline") },
    { "thick-outline", L("Thick outline") },
    { "none", L("None") },
}

C.ANCHOR_SIDES = {
    { "below", L("Below") },
    { "above", L("Above") },
    { "right", L("Right of") },
    { "left", L("Left of") },
}

C.BAR_TEXTURES = {
    { "DebuffTracker/icons/progressBar.dds", L("Flat") },
    { "DebuffTracker/icons/gradientProgressBar.dds", L("Shaded") },
    { "DebuffTracker/icons/gradientProgressBarFlipped.dds", L("Shaded (flipped)") },
    { "DebuffTracker/icons/gradientProgressBar2.dds", L("Soft") },
    { "DebuffTracker/icons/gradientProgressBar2Flipped.dds", L("Soft (flipped)") },
}

-- Effects whose stack number is shown at every value, 0 and 1 included. Touch of Z'en: the game
-- reports 0 stacks for it (in-game log); its strength is counted from your DoTs (stacksFrom
-- "mydots"), and x0 (no DoTs yet) / x1 are meaningful.
-- Effects players add by NAME (English): the ID whose icon stands for them -- every ID here is listed under
-- that name in LuiExtended's MajorMinor.lua; Major / Minor Courage and Minor Toughness are BuffTheGroup's.
-- Used for an entry's icon while the effect isn't on the unit (else the game's red "?" icon showed).
C.NAME_ICON_IDS = {
    ["major brutality"] = 61665, ["major sorcery"] = 61687, ["major prophecy"] = 61689, ["major savagery"] = 61667,
    ["major force"] = 61747, ["major berserk"] = 61745, ["major courage"] = 109966, ["major resolve"] = 61694,
    ["major heroism"] = 61709, ["major expedition"] = 61736, ["major evasion"] = 61716, ["major protection"] = 61722,
    ["major vitality"] = 61713, ["major mending"] = 61711, ["major endurance"] = 61705, ["major fortitude"] = 61698,
    ["major intellect"] = 61707, ["major slayer"] = 93109, ["major aegis"] = 93125, ["major breach"] = 61743,
    ["major maim"] = 61725, ["major defile"] = 61727, ["major vulnerability"] = 106754, ["major cowardice"] = 147643,
    ["major brittle"] = 145977, ["empower"] = 61737,
    ["minor brutality"] = 61662, ["minor sorcery"] = 61685, ["minor prophecy"] = 61691, ["minor savagery"] = 61666,
    ["minor force"] = 61746, ["minor berserk"] = 61744, ["minor courage"] = 147417, ["minor resolve"] = 61693,
    ["minor heroism"] = 61708, ["minor expedition"] = 61735, ["minor evasion"] = 61715, ["minor protection"] = 61721,
    ["minor vitality"] = 61549, ["minor mending"] = 61710, ["minor endurance"] = 61704, ["minor fortitude"] = 61697,
    ["minor intellect"] = 61706, ["minor toughness"] = 88490, ["minor slayer"] = 147226, ["minor aegis"] = 147225,
    ["minor breach"] = 61742, ["minor maim"] = 61723, ["minor defile"] = 61726, ["minor vulnerability"] = 61782,
    ["minor brittle"] = 145975, ["minor mangle"] = 61733, ["minor lifesteal"] = 80020, ["minor magickasteal"] = 39100,
    ["off balance"] = 62988, ["off balance immunity"] = 134599,
}

-- 1 stack is a real value too (shown): Touch of Z'en (0-5), Stagger (1-3, StaggerTracker shows every count)
C.ZERO_BASED_STACKS = { [126597] = true, [134336] = true, [134340] = true }

C.GOLD = { 0.953, 0.824, 0.478, 1 }
C.GOLD_DIM = { 0.54, 0.45, 0.27, 1 }
C.GOLD_BG = { 0.30, 0.25, 0.16, 1 }
C.TEAL = { 0.114, 0.620, 0.459, 1 }
C.AMBER = { 0.937, 0.624, 0.153, 1 }
C.RED = { 0.886, 0.294, 0.290, 1 }
C.PANEL_BG = { 0.055, 0.067, 0.082, 0.96 }
C.PANEL_EDGE = { 0.29, 0.32, 0.36, 1 }

C.DEFAULT_ICON = "/esoui/art/icons/icon_missing.dds"

------------------------------------------------------------------------------
-- Conditions
------------------------------------------------------------------------------

-- kind: "number" | "bool" | "text"
C.CONDITION_PROPS = {
    { "remaining", L("Time remaining (s)"), "number" },
    -- my stats against the enemy (Core/Stats.lua; the entry's enemy when it's a boss / my target, else my target)
    { "penTarget", L("My penetration vs. the enemy"), "number" },
    { "penMissing", L("Penetration missing to the cap (0 = capped)"), "number" },
    { "penOver", L("Penetration over the cap (wasted)"), "number" },
    { "potionCooldown", L("Potion cooldown left (s)"), "number" },
    { "leftAfterPotion", L("Time left when my potion is ready (s)"), "number" },
    { "critTarget", L("My critical damage vs. the enemy (%)"), "number" },
    { "elapsed", L("Time elapsed (s)"), "number" },
    { "progress", L("Time remaining (%)"), "number" },
    { "stacks", L("Stacks"), "number" },
    { "active", L("Is active (not missing)"), "bool" },
    { "isTarget", L("Is my current target"), "bool" },
    { "isBoss", L("Is a boss"), "bool" },
    { "mine", L("Cast by me"), "bool" },
    { "isMe", L("The unit is me (group / me)"), "bool" },
    { "inRange", L("Ally in support range (group)"), "bool" },
    { "onBar", L("Ability on my bars (ID or name; = is on, != isn't)"), "text" },
    { "value", L("Resource value"), "number" },
    { "pct", L("Resource %"), "number" },
    { "inCombat", L("I'm in combat"), "bool" },
    { "unitName", L("Unit name contains"), "text" },
    { "name", L("Effect name contains"), "text" },
    { "phase", L("Step (0 = ready, 1 = active / first ability, 2 = cooldown / second...)"), "number" },
    { "buffUp", L("Buff is up (ability timers, procs: the active part)"), "bool" },
    { "onCooldown", L("Is on cooldown (ability timers)"), "bool" },
    { "sinceReady", L("Seconds since it became ready (ability timers)"), "number" },
    { "expired", L("Just ended (kept after it ended)"), "bool" },
    { "sinceEnd", L("Seconds since it ended"), "number" },
    { "role", L("Unit role is (tank / healer / dps)"), "text" },
    { "distance", L("Distance to the unit (m, allies)"), "number" },
    { "healthPct", L("Unit health %"), "number" },
    -- resource ticks (Core/Ticks.lua)
    { "tickProgress", L("Progress to the next tick (%)"), "number" },
    { "sinceTick", L("Seconds since the last tick"), "number" },
    { "tickRegen", L("Regen per tick (0 = none, e.g. blocking)"), "number" },
    { "dodgeFatigue", L("Dodge fatigue stacks on me"), "number" },
    -- global cooldown (Core/GlobalCooldown.lua)
    { "gcdKind", L("Global cooldown: what (skill / cast / channel / heavy / dodge / other)"), "text" },
    { "gcdCasting", L("Global cooldown: still casting / channeling"), "bool" },
}

C.OPERATORS = {
    { "<", "<" }, { "<=", "<=" }, { "==", "=" }, { "~=", "!=" }, { ">=", ">=" }, { ">", ">" },
}
C.EQUALITY_OPERATORS = { { "==", "=" }, { "~=", "!=" } }

-- kind of argument: "color" | "none" | "sound" | "text" | "number"
C.CONDITION_ACTIONS = {
    { "color", L("Bar / icon color"), "color" },
    { "textColor", L("Text color"), "color" },
    { "timerColor", L("Timer text color"), "color" },
    { "stackColor", L("Stack text color"), "color" },
    { "glow", L("Glow border"), "color" },
    { "pulse", L("Pulse"), "none" },
    { "hide", L("Hide"), "none" },
    { "sound", L("Play sound (once)"), "sound" },
    { "alert", L("Screen alert (once)"), "text" },
    { "scale", L("Scale (icons %)"), "number" },
    { "proc", L("Proc highlight (animated)"), "none" },
    { "background", L("Entry background (behind the bar / icon)"), "color" },
    { "alpha", L("Transparency (% visible)"), "number" },
    { "grey", L("Grey icon"), "none" },
    { "quickslot", L("Select quickslot (1-8)"), "number" },
}

function C.Find(list, value)
    for _, o in ipairs(list) do if o[1] == value then return o end end
    return nil
end

------------------------------------------------------------------------------
-- Load conditions
------------------------------------------------------------------------------

C.COMBAT_LOAD = {
    { "any", L("Always") },
    { "in", L("Only in combat") },
    { "out", L("Only out of combat") },
}

C.ZONE_TYPES = {
    { "overland", L("Overland") },
    { "delve", L("Delves") },
    { "dungeon", L("Group dungeons") },
    { "trial", L("Trials") },
    { "pvp", L("PvP") },
    { "house", L("Houses") },
}

C.ROLES = {
    { "tank", L("Tank") },
    { "healer", L("Healer") },
    { "dps", L("Damage") },
}

C.ICON_STACK_POS = {
    { "bottomright", L("Bottom right") }, { "bottomleft", L("Bottom left") }, { "topright", L("Top right") },
    { "topleft", L("Top left") }, { "top", L("Top") }, { "bottom", L("Bottom") },
}

C.FIGHT_LOAD = {
    { "any", L("Any") },
    { "boss", L("Boss fights only") },
    { "trash", L("No boss (trash)") },
}

C.GROUP_LOAD = {
    { "any", L("Any") },
    { "solo", L("Solo") },
    { "group", L("In a group (2-4)") },
    { "raid", L("In a raid (5+)") },
    { "grouped", L("In any group (2+)") },
}

C.CLASSES = {
    { 1, "Dragonknight" }, { 2, "Sorcerer" }, { 3, "Nightblade" }, { 4, "Warden" },
    { 5, "Necromancer" }, { 6, "Templar" }, { 117, "Arcanist" },
}

-- class ID from an English class name ("Templar" -> 6); nil when unknown
function C.ClassId(name)
    name = tostring(name or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    for _, c in ipairs(C.CLASSES) do if c[2]:lower() == name then return c[1] end end
    return nil
end

-- Group dungeons and group arenas (Dragonstar Arena 635, Blackrose Prison 1082), from BuffTheGroup's
-- zone list: always "Group dungeons", also when the game reports no dungeon difficulty (the arenas).
C.GROUP_ZONES = {
    [11] = true, [22] = true, [31] = true, [38] = true, [63] = true, [64] = true, [126] = true, [130] = true, [131] = true, [144] = true,
    [146] = true, [148] = true, [176] = true, [283] = true, [380] = true, [449] = true, [678] = true, [681] = true, [688] = true, [843] = true,
    [848] = true, [930] = true, [931] = true, [932] = true, [933] = true, [934] = true, [935] = true, [936] = true, [973] = true, [974] = true,
    [1009] = true, [1010] = true, [1052] = true, [1055] = true, [1080] = true, [1081] = true, [1123] = true, [1122] = true, [1152] = true, [1153] = true,
    [1197] = true, [1201] = true, [1228] = true, [1229] = true, [1301] = true, [1302] = true, [1360] = true, [1361] = true, [1389] = true, [1390] = true,
    [635] = true, [1082] = true,
}

-- Known trial zones; IsPlayerInRaid() (when available) covers trials added later.
C.TRIAL_ZONES = {
    [636] = true, [638] = true, [639] = true, [725] = true, [975] = true, [1000] = true,
    [1051] = true, [1121] = true, [1196] = true, [1263] = true, [1344] = true, [1427] = true,
    [1478] = true, [1548] = true,
}

------------------------------------------------------------------------------
-- Ability copies: other ability IDs that apply the same effect (morphs/ranks/sources).
-- Listing the first ID in a tracker automatically matches all of its copies.
------------------------------------------------------------------------------

C.ABILITY_COPIES = {
    [81519]  = { 51434, 61782, 68359, 79715, 79717, 79720, 79723, 79726, 79843, 79844, 79845, 79846, 117025, 118613, 120030, 124803, 124804, 124806, 130155, 130168, 130173, 130809 }, -- Minor Vulnerability
    [80020]  = { 86304, 86305, 86307, 88565, 88575, 88606, 92653, 121634, 148043 }, -- Minor Lifesteal
    [68588]  = { 38688, 61742, 83031, 84358, 108825, 120019, 126685, 146908 }, -- Minor Breach
    [62988]  = { 62968, 39077, 130145, 130129, 130139, 45902, 25256, 34733, 34737, 23808, 20806, 34117, 125750, 131562, 45834, 137257, 137312, 120014 }, -- Off Balance
    [62787]  = { 28307, 33363, 34386, 36972, 36980, 40254, 48946, 53881, 61743, 62474, 62485, 62775, 78609, 85362, 91175, 91200, 100988, 108951, 111788, 117818, 118438, 120010 }, -- Major Breach
    [122389] = { 106754, 106755, 106758, 106760, 106762, 122177, 122397 }, -- Major Vulnerability
    [39100]  = { 26220, 26809, 88401, 88402, 88576, 125316, 148044 }, -- Minor Magickasteal
    [38541]  = { 38254 }, -- Taunt
    -- Alkosh: 75753 Line-Breaker (DebuffTracker 1.x, LibCombat), 76667 the penetration debuff (Combat
    -- Metrics, Pit's Zenkosh Tracker), 120018 its Target Dummy version (Combat Metrics)
    [75753]  = { 76667, 120018 }, -- Alkosh (Line-Breaker)
    [145975] = { 146697, 148977, 154272, 184986, 219247, 221492, 221725, 235871, 235890 }, -- Minor Brittle
}

------------------------------------------------------------------------------
-- Sounds: the game's SOUNDS table, sorted, for the sound picker.
------------------------------------------------------------------------------

local soundList
function C.SoundNames()
    if soundList then return soundList end
    soundList = {}
    if type(SOUNDS) == "table" then
        for name, value in pairs(SOUNDS) do
            if type(value) == "string" and value ~= "" then soundList[#soundList + 1] = name end
        end
    end
    table.sort(soundList)
    return soundList
end

-- A short list shown first in the picker; the full list follows.
C.FAVORITE_SOUNDS = {
    "DUEL_START", "CHAMPION_POINT_GAINED", "LEVEL_UP", "QUEST_COMPLETED", "GENERAL_ALERT_ERROR",
    "NEW_NOTIFICATION", "ABILITY_ULTIMATE_READY", "DEFAULT_CLICK", "RAID_TRIAL_FAILED",
    "TELVAR_MULTIPLIERUP", "BATTLEGROUND_COUNTDOWN_FINISH", "SKILL_LINE_ADDED", "STATS_PURCHASE",
}
