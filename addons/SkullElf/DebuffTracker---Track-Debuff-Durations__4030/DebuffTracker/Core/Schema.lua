-- The tracker data model. A tracker is plain, serializable data; everything the addon does with it
-- is derived at runtime. Normalize() makes any tracker (old, imported, hand-edited) safe to use.

local DT = DebuffTracker
local S = DT.Schema
local U = DT.Util
local C = DT.Const

S.TRACKER_DEFAULTS = {
    id = "",
    name = "New tracker",
    enabled = true,
    iconOverride = "",          -- texture path or ability ID; "" = automatic

    trigger = {
        type = "effect",

        -- effect
        abilityIds = {},
        names = {},             -- lowercase effect names (match by name, any ID)
        scope = "enemies",
        source = "any",
        effectType = "any",
        mode = "present",
        perAbility = false,     -- one entry per listed ability (checklists)
        minStacks = 0,
        unitIndex = 0,          -- bosses / group: 0 = all, n = only boss n / group member n
        minDifficulty = 0,      -- all enemies, in trials: hide enemies below this difficulty (1 normal .. 4 deadly)
        linger = 0,             -- keep an entry for this many seconds after its effect ends ("expired")
        lingerEarly = false,    -- ...also when it ended early (removed, overwritten). An enemy that dies: gone at once
        lingerToDue = false,    -- ...an early end is kept until it WOULD have ended + linger (Untaunted)
        lingerUnit = false,     -- ...kept while the same enemy still has another entry of this tracker (Untaunted)
        stacksFrom = "effect",  -- "effect" (the game's stack count) | "mydots" (number of MY damage-over-time effects on the unit: Touch of Z'en)
        stacksMax = 0,          -- show at most this many stacks (0 = no limit)
        abilityIcons = {},      -- the player's own icon per listed ability: [ID as text / lowercase name] = ability ID or texture path
        variants = {},          -- the player's own variants per listed ability: [ID as text / lowercase name] = { ability IDs that count as it }
        noCopies = {},          -- listed IDs whose built-in variants are switched off (set of ID as text): only `variants` count
        unitRoles = {},         -- group: only members with these roles (set; empty = everyone) -- BuffTheGroup's "only DPS"
        cooldownAfter = 0,      -- cycle: after the effect, a cooldown of this many s (from when it started) before "ready"
        cooldownAfterId = 0,    -- ...or as long as this ability lasts in the game (GetAbilityDuration), BuffTheGroup's Pillager's Profit
        idleEntry = false,      -- nothing to show: keep one entry (the first ability; "ready" for a cycle)
        summary = false,        -- one entry instead: how many of the units have it (value / max / %), BuffTheGroup's minimal mode

        -- combat (ability timer)
        combatSource = "me",
        combatResult = "any",
        duration = 10,
        perTarget = false,
        restartOnRefresh = true,
        showReady = false,
        minInterval = 0.5,
        cooldown = 0,           -- seconds from the proc until it can happen again (0 = none)
        startOn = "combat",     -- "combat" (an action / proc event) | "effect" (a buff on me: its own time & stacks)
        cooldownIds = {},       -- abilities whose event carries the cooldown length (hit value, ms)
        endIds = {},            -- abilities that end the active part early
        count = false,          -- count procs (shown as stacks, per fight) instead of timing them
        durationFromHit = false, -- active part = the event's hit value in ms when it has one (else `duration`)

        -- my procs (built-in catalogue)
        procKindsOff = {},      -- gear kinds NOT shown ("set", "monsterSet", "artifact", "stackSet")
        procPicked = {},        -- synergies / passives / champion skills to show (catalogue keys)
        procHidden = {},        -- catalogue entries not to show here (e.g. moved to their own tracker)
        procOnly = {},          -- when set: show only these entries (a proc's "own tracker")
        procIcon = "set",       -- gear procs: "set" (the set's own icon, see Core/Procs.lua P.Icon) | "proc" (the proc's effect icon)
        procReady = true,       -- show procs that are ready (not active / on cooldown)
        procGameDurations = false, -- buff times from the game (GetAbilityDuration), like ExoY's ProcSet Timer
        procZenBoss = false,    -- Touch of Z'en: with exactly one boss, count your DoTs on it (ExoY's "focus on boss")

        -- resource
        unit = "player",
        powerType = "health",
        thresholdOp = "none",   -- "none" or an operator from C.OPERATORS
        threshold = 30,         -- percent
        -- stat (Core/Stats.lua)
        stat = "penTarget",
        statOp = "none",        -- show only when the value is <op> statValue
        statValue = 18200,
        statDecimals = -1,      -- decimals of the number (-1 = the stat's own: 66.1% crit chance, 4119 penetration)
        label = "",             -- Meter display: the caption above the number ("" = the stat's name)
        -- combat state (an indicator: am I in combat?)
        combatOnText = "Combat",
        combatOffText = "No Combat",
        -- resource tick (Core/Ticks.lua): powerType = the resource
        tickShowFull = false,   -- also shown while the resource is full (Miat's "always shown")
        -- global cooldown (Core/GlobalCooldown.lua; Combat Metronome's option names in brackets)
        gcdHeavy = true,        -- heavy attacks too [not "Don't show heavy attacks"]
        gcdCasts = true,        -- casts for their cast time (off: just the GCD -- GCD Monitor, GCD Bar)
        gcdChannels = true,     -- channels for their length (off: just the GCD -- GCD Bar)
        gcdOther = true,        -- cooldowns without a skill: dodge, synergy, item, companion... ["Track all GCDs"]
        gcdMountName = false,   -- mounting: "(nickname)" after it ["Show mount nickname"]
        gcdNames = "all",       -- name, icon and time on: "all" (every bar) | "timed" (casts / channels only) ["Display spell name for any ability"]
        gcdHeavyNames = true,   -- ...and on heavy attacks ["Show labels and icon"]
        gcdPing = true,         -- your ping as the end of the bar (the window to queue the next input) [not "Don't show ping"]
        gcdMaxPing = 150,       -- ms, the most of it shown ["Max latency"]
        gcdHeavyPing = true,    -- ...on heavy attacks too ["Display ping zone on heavy attacks"]
        gcdOtherPing = true,    -- ...on cooldowns without a skill ["Show ping zone for non ability GCD"]
        gcdAdjust = 0,          -- ms added to instant skills ["GCD adjust"]
        gcdCastAdjust = 0,      -- ms added to casts and channels ["Global ability cast adjust"; Metronome's default 25]
        gcdHeavyAdjust = 0,     -- ms added to heavy attacks ["Global heavy attack adjust"; default 25]
        gcdAbilityAdjust = {},  -- per skill: { { id = abilityId, ms = n }, ... } ["Ability adjusts"]
        gcdChannelExtra = 0,    -- ms after a channel over 1 s (Global Cooldown Monitor "Channel time delay": 100)
        gcdIdle = false,        -- keep an empty bar while nothing runs ["Show permanently"]
        -- the metronome ["Sound 'tick'" / "Sound 'tock'"]
        gcdTick = false,
        gcdTickSound = "Justice_PickpocketFailed",  -- a SOUNDS name, or a sound as Metronome stores it
        gcdTickAt = "start",    -- "start" (+ offset) | "mid" (+ offset) | "end" (gcdTickBeforeEnd ms before the end)
        gcdTickOffset = 200,    -- ms
        gcdTickBeforeEnd = 500, -- ms
        gcdTock = false,
        gcdTockSound = "Dialog_Decline",
        gcdTockOffset = 300,    -- ms after the ability's end (negative: before it)
        gcdTockForce = true,    -- a tock still due when the next ability starts plays anyway ["Force 'tock'"]
        gcdSoundHeavy = true,   -- [not "Don't play 'tick' on heavy attacks"]
        gcdSoundLong = true,    -- on abilities over 1 s too [not "No sound on long abilities"]
        gcdSoundOOC = false,    -- out of combat too ["Play sounds ooc"]
        gcdVolume = 5,          -- the sound is played this many times (louder) ["Volume of 'tick' and 'tock'"]
        calc = "none",          -- "none" | "missing" (value from missing %) | "divide" (% / divisor)
        calcScalar = 30,        -- missing: value at 100% missing...
        calcStart = 100,        -- ...counted from this %...
        calcCap = 50,           -- ...down to this % (no more below it)
        calcDiv = 2.8,          -- divide: shown value = % / this
        calcDecimals = 0,
    },

    display = {
        type = "bars",
        style = "clean",
        width = 220,
        height = 22,
        iconSize = 40,
        spacing = 3,
        columns = 6,
        timerOffsetX = 0,       -- icons: move the timer text (px) -- ExoY's indicator offset
        timerOffsetY = 0,
        barRows = 0,            -- bars: start a new column after this many (0 = one column) -- BuffTheGroup's 6 x 2
        grow = "down",
        maxShown = 10,          -- above heads: per person
        sort = "expiry",
        headSelf = false,       -- above heads: also above your own head

        showHeader = true,
        title = "",
        showUptime = true,
        showEmpty = false,      -- keep the window visible with no entries
        keepSlots = false,      -- a missing entry keeps its place (an empty gap) instead of the others moving up
        borderSize = 2,         -- thickness of the coloured border (target highlight, glow, state); 0 = no plain outline
        -- icons (Casual player Geldis, 5.21.16: "icon mode needed to be reworked")
        iconBg = { 0, 0, 0, 0.6 },  -- the square behind each icon (not the window's background)
        iconPadding = 2,        -- px between the icon's picture and its square / border
        -- % trimmed off each side of the picture (some icons have a dark rim drawn in); 0 = none. (5.21.19 trimmed 4%
        -- automatically at Icon padding 0 for a gap that turned out to be the padding itself -- Geldis: "Icon padding = 0
        -- solves this issue" -- so it's manual again.)
        iconTrim = 0,
        iconStackSize = 0,      -- the stack count's size (0 = from the icon size)
        iconStackPos = "bottomright", -- "bottomright" | "bottomleft" | "topright" | "topleft" | "top" | "bottom"
        rowBorder = false,      -- a border around every entry (bar / icon), Border colour, Border thickness
        borderColor = { 0, 0, 0, 1 },
        iconTint = { 1, 1, 1, 1 },  -- multiplies the icon's colours (darken a too-bright icon)
        procPercent = true,     -- proc cards: the resource % strip along the bottom
        procColorOk = { 0.36, 0.95, 0.45, 1 },    -- proc cards: full bonus / running / can proc
        procColorPart = { 1, 0.80, 0.30, 1 },     -- ...partial bonus, players count when low
        procColorBad = { 0.95, 0.30, 0.30, 1 },   -- ...can't proc (gauge above the line), wasted procs
        procColorInfo = { 0.45, 0.85, 1, 1 },     -- ...the buff-time number (Roaring)
        gameFrame = true,       -- proc icons: the game's ability frame around them
        procCards = true,
        timerTo = "part",       -- ability timers: "part" (active, then cooldown) | "ready" (the whole cooldown)       -- icons: resource gauge / bonus / buff time / allies on proc icons, frame shows the state

        showName = true,
        showTimer = true,
        showStacks = true,
        showRowIcon = false,
        highlightTarget = true,
        desaturateInactive = true,
        blink = true,
        blinkThreshold = 2,

        labelFormat = "{unit}",
        iconLabelFormat = "",
        textFormat = "{name} - {unit}  {time}",
        alertFormat = "{name}",
        timeFormat = "auto",

        texture = "DebuffTracker/icons/progressBar.dds",
        fontFace = "MEDIUM_FONT",
        fontSize = 0,           -- 0 = automatic from bar/icon size
        headerFontSize = 0,     -- the window title: 0 = the style's own; else this size in the tracker's font and outline
        fontEffect = "soft-shadow-thick",

        colorMode = "gradient",
        colorFull = { 0.114, 0.620, 0.459, 1 },
        colorMid = { 0.937, 0.624, 0.153, 1 },
        colorEnd = { 0.886, 0.294, 0.290, 1 },
        colorSolid = { 0.40, 0.65, 0.95, 1 },
        textColor = { 1, 1, 1, 1 },
        background = { 0.055, 0.067, 0.082, 0.82 },
        alpha = 1,
        barAlpha = 1,
        scale = 1,
        fillReverse = false,    -- bars empty toward the right edge (anchored right) instead of the left
        fillCenter = false,     -- bars empty toward the middle from both ends (Combat Metronome's "Center")
        labelPos = "left",      -- bars: the label "left" | "center" (in the bar) | "above" | "aboveCenter" (above the bar)
        timerColor = { 1, 1, 1, 1 },
        stackColor = { 1, 1, 1, 1 },
        separateTextColors = false, -- off: timer and stacks use textColor
        drawLevel = 0,          -- 0-10: higher draws above other trackers
        forceIcon = false,      -- use the tracker's icon (Text & colors > Icon) for every entry
        vertical = false,       -- bars as vertical columns (width = length, row height = thickness)
        iconTimer = "sweep",    -- icons: "sweep" (dark overlay) | "shrinkV" | "shrinkH" (the icon itself shrinks) | "none"
        cooldownColor = { 0.886, 0.294, 0.290, 1 }, -- ability timers: bar / timer colour during the cooldown
        cooldownDesaturate = true,  -- ...and the icon goes grey
        -- Meter (number tiles: character stats, a value from a rule...): one tile per entry
        meterWidth = 118,
        meterHeight = 48,
        meterAnim = "standard", -- the number rolls to its new value: "off" | "fast" | "standard" | "slow"
        meterAccent = true,     -- the coloured line along the tile's left edge (recoveries in their resource colour)
        meterGauge = true,      -- values with a cap (penetration, crit damage): the left line fills up toward the cap
        meterCapColors = true,  -- ...and the number is red below the cap, green at it, blue well over it (wasted)
        meterCaption = true,    -- the small caption above the number
        meterCaptionColor = { 0.95, 0.87, 0.64, 1 },
        meterCaptionSize = 0,   -- px; 0 = a third of the tile height
        textCenter = false,     -- Text display: centre the line (e.g. a combat indicator under the crosshair)
        -- bars: the dark strip behind each bar (Clean / Compact styles; Azu: "make the black background of the
        -- timers ... so you can see the arena floor a bit clearer" -- it was a fixed 40% black)
        trackColor = { 0, 0, 0, 0.4 },
        zoneColor = { 1, 0.88, 0.5, 0.45 },     -- bars: the end window (global cooldown: your ping, to queue the next input)
    },

    position = {
        x = 0,                  -- offset from screen center (positive = right/down)
        y = 0,
        anchorTo = "",          -- tracker id, "" = screen
        anchorSide = "below",
        gap = 4,
        -- along the edge it's attached to (HangryGinger: "lock my ultimate # display to my GCD bar ... couldn't really
        -- get it to be centered" -- it was always lined up on the left / top edge)
        anchorAlign = "start",  -- "start" (left / top edges lined up) | "center" | "end" (right / bottom edges)
        anchorShift = 0,        -- then moved this far along that edge (right / down = positive)
    },

    conditions = {},            -- { {prop, op, value, action, arg}, ... }

    load = {
        combat = "any",
        combatLinger = 0,       -- "only in combat": stay this many seconds after the fight (0 = the usual 3 s grace)
        zoneTypes = {},         -- set; empty = everywhere
        zoneIds = {},
        roles = {},             -- set; empty = any role
        classes = {},           -- set; empty = any class
        group = "any",
        bossOnly = false,
        trashOnly = false,      -- hidden while a boss is up ("trash fights"; the other half of bossOnly)
        hideDead = false,       -- hidden while you're dead (like Cooldowns)
        characters = {},        -- list of character names; empty = all
        setId = 0,              -- require a gear set...
        setPieces = 5,          -- ...with at least this many pieces equipped
        setBackbar = true,      -- count the other weapon bar's set pieces too
        setFull = false,        -- require the full set (its own piece count) instead of setPieces
        cpSkills = {},          -- only with one of these champion skills slotted (champion skill IDs)
        setNames = {},          -- only with one of these FULL sets worn (English names, any game language via LibSets)
        skills = {},            -- only with one of these slotted (ability IDs, either bar)
        skillNames = {},        -- ...or skills whose name contains one of these
        bossNames = {},         -- only when a boss's name contains one of these
        zoneNames = {},         -- only in zones whose name contains one of these
        werewolf = "any",       -- "any" | "only" (only in werewolf form) | "never" (hidden in werewolf form)
        never = {},             -- lists switched to "never when": set of zones / roles / classes / sets / cp / skills / bosses / characters
    },
}

S.CONDITION_DEFAULTS = { prop = "remaining", op = "<=", value = 3, action = "color", arg = { 0.886, 0.294, 0.290, 1 } }

local VALID = {
    triggerType = C.Values(C.TRIGGER_TYPES),
    scope = C.Values(C.SCOPES),
    source = C.Values(C.SOURCES),
    effectType = C.Values(C.EFFECT_TYPES),
    mode = C.Values(C.MODES),
    combatResult = C.Values(C.COMBAT_RESULTS),
    combatSource = C.Values(C.COMBAT_SOURCES),
    unit = C.Values(C.RESOURCE_UNITS),
    powerType = C.Values(C.POWER_TYPES),
    stat = C.Values(C.STATS),
    displayType = C.Values(C.DISPLAY_TYPES),
    style = C.Values(C.BAR_STYLES),
    grow = C.Values(C.GROW),
    sort = C.Values(C.SORTS),
    colorMode = C.Values(C.COLOR_MODES),
    timeFormat = C.Values(C.TIME_FORMATS),
    fontFace = C.Values(C.FONT_FACES),
    fontEffect = C.Values(C.FONT_EFFECTS),
    anchorSide = C.Values(C.ANCHOR_SIDES),
    anchorAlign = { start = true, center = true, ["end"] = true },
    iconStackPos = C.Values(C.ICON_STACK_POS),
    combatLoad = C.Values(C.COMBAT_LOAD),
    groupLoad = C.Values(C.GROUP_LOAD),
    prop = C.Values(C.CONDITION_PROPS),
    action = C.Values(C.CONDITION_ACTIONS),
}
VALID.procKind = { set = true, monsterSet = true, artifact = true, stackSet = true }
VALID.calc = { none = true, missing = true, divide = true }
VALID.op = { ["<"] = true, ["<="] = true, ["=="] = true, ["~="] = true, [">="] = true, [">"] = true }

local function Enum(value, valid, default)
    if valid[value] then return value end
    return default
end

local function Num(value, default, lo, hi)
    value = tonumber(value)
    if not value then return default end
    if lo and value < lo then value = lo end
    if hi and value > hi then value = hi end
    return value
end

-- "#RRGGBB" / "#RRGGBBAA" (hand-written or AI-written JSON) -> {r, g, b, a}
local function Hex(value)
    if type(value) ~= "string" then return nil end
    local h = value:match("^%s*#?(%x+)%s*$")
    if not h or (#h ~= 6 and #h ~= 8) then return nil end
    local c = {}
    for i = 1, #h, 2 do c[#c + 1] = tonumber(h:sub(i, i + 1), 16) / 255 end
    c[4] = c[4] or 1
    return c
end
S.Hex = Hex

local function Color(value, default)
    value = Hex(value) or value
    if type(value) ~= "table" then return U.Copy(default) end
    return {
        Num(value[1], default[1], 0, 1), Num(value[2], default[2], 0, 1),
        Num(value[3], default[3], 0, 1), Num(value[4], default[4] or 1, 0, 1),
    }
end

local function NumberList(list)
    local out, seen = {}, {}
    if type(list) == "table" then
        for _, v in ipairs(list) do
            local n = tonumber(v)
            if n and n > 0 and not seen[n] then seen[n] = true; out[#out + 1] = math.floor(n) end
        end
    end
    return out
end

local function StringList(list, lower)
    local out, seen = {}, {}
    if type(list) == "table" then
        for _, v in ipairs(list) do
            if type(v) == "string" then
                local s = U.Trim(v)
                if lower then s = U.Lower(s) end
                if s ~= "" and not seen[s] then seen[s] = true; out[#out + 1] = s end
            end
        end
    end
    return out
end

-- A set {key = true}. Also accepts a list ["trial", "dungeon"] / [6, 117] (hand-written or AI-written
-- JSON). `numeric`: keys are numbers (class IDs) -- JSON object keys arrive as strings ("6").
local function BoolSet(set, valid, numeric)
    local out = {}
    if type(set) == "table" then
        for k, v in pairs(set) do
            local key
            if v == true then key = k
            elseif type(k) == "number" and (type(v) == "string" or type(v) == "number") then key = v end
            if key ~= nil then
                if numeric then key = tonumber(key) or (type(key) == "string" and C.ClassId and C.ClassId(key)) or nil
                elseif type(key) == "string" then key = U.Lower(U.Trim(key)) end
                if key ~= nil and (not valid or valid[key]) then out[key] = true end
            end
        end
    end
    return out
end

local function NormalizeTrigger(tr)
    local dt = S.TRACKER_DEFAULTS.trigger
    U.ApplyDefaults(tr, dt)
    tr.type = Enum(tr.type, VALID.triggerType, dt.type)
    tr.abilityIds = NumberList(tr.abilityIds)
    tr.names = StringList(tr.names, true)
    tr.scope = Enum(tr.scope, VALID.scope, dt.scope)
    tr.source = Enum(tr.source, VALID.source, dt.source)
    tr.effectType = Enum(tr.effectType, VALID.effectType, dt.effectType)
    tr.mode = Enum(tr.mode, VALID.mode, dt.mode)
    tr.perAbility = tr.perAbility == true
    tr.unitIndex = math.floor(Num(tr.unitIndex, 0, 0, 12))
    tr.minDifficulty = math.floor(Num(tr.minDifficulty, 0, 0, 4))
    tr.linger = Num(tr.linger, 0, 0, 60)
    tr.lingerEarly = tr.lingerEarly == true
    tr.lingerToDue = tr.lingerToDue == true
    tr.lingerUnit = tr.lingerUnit == true
    tr.stacksFrom = tr.stacksFrom == "mydots" and "mydots" or "effect"
    tr.stacksMax = math.floor(Num(tr.stacksMax, 0, 0, 99))
    tr.unitRoles = BoolSet(tr.unitRoles, C.Values(C.ROLES))
    local icons = {}
    if type(tr.abilityIcons) == "table" then
        for k, v in pairs(tr.abilityIcons) do
            local key = U.Lower(U.Trim(tostring(k)))
            local val = U.Trim(tostring(v or ""))
            if key ~= "" and val ~= "" then icons[key] = val end
        end
    end
    tr.abilityIcons = icons
    -- own variants (Sazane, 5.14.2): other ability IDs that count as a listed ability
    local variants = {}
    if type(tr.variants) == "table" then
        for k, v in pairs(tr.variants) do
            local key = U.Lower(U.Trim(tostring(k)))
            local list = {}
            for _, id in ipairs(NumberList(type(v) == "table" and v or { v })) do
                if tostring(id) ~= key then list[#list + 1] = id end
            end
            if key ~= "" and #list > 0 then variants[key] = list end
        end
    end
    tr.variants = variants
    tr.noCopies = BoolSet(tr.noCopies)
    tr.cooldownAfter = Num(tr.cooldownAfter, 0, 0, 600)
    tr.cooldownAfterId = math.floor(Num(tr.cooldownAfterId, 0, 0, 9999999))
    tr.summary = tr.summary == true
    tr.idleEntry = tr.idleEntry == true
    tr.minStacks = Num(tr.minStacks, 0, 0, 999)
    tr.combatSource = Enum(tr.combatSource, VALID.combatSource, dt.combatSource)
    tr.combatResult = Enum(tr.combatResult, VALID.combatResult, dt.combatResult)
    tr.perTarget = tr.perTarget == true
    tr.restartOnRefresh = tr.restartOnRefresh ~= false
    tr.showReady = tr.showReady == true
    tr.minInterval = Num(tr.minInterval, dt.minInterval, 0, 60)
    tr.cooldown = Num(tr.cooldown, 0, 0, 3600)
    tr.startOn = tr.startOn == "effect" and "effect" or "combat"
    tr.cooldownIds = NumberList(tr.cooldownIds)
    tr.endIds = NumberList(tr.endIds)
    tr.count = tr.count == true
    tr.durationFromHit = tr.durationFromHit == true
    tr.duration = Num(tr.duration, dt.duration, 0, 3600)
    if tr.duration <= 0 and tr.cooldown <= 0 and tr.startOn == "combat" and not tr.count then tr.duration = dt.duration end
    local off = {}
    for _, k in ipairs(StringList(tr.procKindsOff, false)) do
        if VALID.procKind[k] then off[#off + 1] = k end
    end
    tr.procKindsOff = off
    tr.procPicked = StringList(tr.procPicked, false)
    tr.procHidden = StringList(tr.procHidden, false)
    tr.procOnly = StringList(tr.procOnly, false)
    tr.procIcon = tr.procIcon == "proc" and "proc" or "set"
    tr.procReady = tr.procReady ~= false
    tr.procGameDurations = tr.procGameDurations == true
    tr.procZenBoss = tr.procZenBoss == true
    tr.calc = Enum(tr.calc, VALID.calc, "none")
    tr.calcScalar = Num(tr.calcScalar, dt.calcScalar, 0, 100000)
    tr.calcStart = Num(tr.calcStart, dt.calcStart, 1, 100)
    tr.calcCap = Num(tr.calcCap, dt.calcCap, 0, 100)
    tr.calcDiv = Num(tr.calcDiv, dt.calcDiv, 0.01, 1000)
    tr.calcDecimals = math.floor(Num(tr.calcDecimals, 0, 0, 2))
    tr.unit = Enum(tr.unit, VALID.unit, dt.unit)
    tr.powerType = Enum(tr.powerType, VALID.powerType, dt.powerType)
    tr.thresholdOp = (tr.thresholdOp == "none" or VALID.op[tr.thresholdOp]) and tr.thresholdOp or "none"
    tr.threshold = Num(tr.threshold, dt.threshold, 0, 100)
    tr.stat = Enum(tr.stat, VALID.stat, dt.stat)
    tr.statOp = (tr.statOp == "none" or VALID.op[tr.statOp]) and tr.statOp or "none"
    tr.statValue = Num(tr.statValue, dt.statValue, 0, 1000000)
    tr.statDecimals = math.floor(Num(tr.statDecimals, -1, -1, 2))
    tr.label = type(tr.label) == "string" and tr.label or ""
    tr.combatOnText = type(tr.combatOnText) == "string" and tr.combatOnText or dt.combatOnText
    tr.combatOffText = type(tr.combatOffText) == "string" and tr.combatOffText or dt.combatOffText
    tr.tickShowFull = tr.tickShowFull == true
    for _, k in ipairs({ "gcdHeavy", "gcdCasts", "gcdChannels", "gcdOther", "gcdHeavyNames", "gcdPing", "gcdHeavyPing",
        "gcdOtherPing", "gcdTockForce", "gcdSoundHeavy", "gcdSoundLong" }) do tr[k] = tr[k] ~= false end
    for _, k in ipairs({ "gcdMountName", "gcdIdle", "gcdTick", "gcdTock", "gcdSoundOOC" }) do tr[k] = tr[k] == true end
    tr.gcdNames = (tr.gcdNames == "timed") and "timed" or "all"
    tr.gcdTickAt = (tr.gcdTickAt == "mid" or tr.gcdTickAt == "end") and tr.gcdTickAt or "start"
    tr.gcdMaxPing = math.floor(Num(tr.gcdMaxPing, dt.gcdMaxPing, 0, 1000))
    tr.gcdAdjust = math.floor(Num(tr.gcdAdjust, 0, -1000, 1000))
    tr.gcdCastAdjust = math.floor(Num(tr.gcdCastAdjust, 0, -1000, 1000))
    tr.gcdHeavyAdjust = math.floor(Num(tr.gcdHeavyAdjust, 0, -1000, 1000))
    tr.gcdChannelExtra = math.floor(Num(tr.gcdChannelExtra, 0, 0, 1000))
    tr.gcdTickOffset = math.floor(Num(tr.gcdTickOffset, dt.gcdTickOffset, -2000, 5000))
    tr.gcdTickBeforeEnd = math.floor(Num(tr.gcdTickBeforeEnd, dt.gcdTickBeforeEnd, 0, 5000))
    tr.gcdTockOffset = math.floor(Num(tr.gcdTockOffset, dt.gcdTockOffset, -2000, 5000))
    tr.gcdVolume = math.floor(Num(tr.gcdVolume, dt.gcdVolume, 1, 30))
    -- a sound as Combat Metronome stores it (the SOUNDS value) -> its SOUNDS name, so the editor's list shows it
    local function SoundName(v, d)
        v = type(v) == "string" and v or d
        if type(SOUNDS) == "table" and not SOUNDS[v] then
            for k, x in pairs(SOUNDS) do if x == v then return k end end
        end
        return v
    end
    tr.gcdTickSound = SoundName(tr.gcdTickSound, dt.gcdTickSound)
    tr.gcdTockSound = SoundName(tr.gcdTockSound, dt.gcdTockSound)
    local adj = {}
    for _, a in ipairs(type(tr.gcdAbilityAdjust) == "table" and tr.gcdAbilityAdjust or {}) do
        if type(a) == "table" and tonumber(a.id) and tonumber(a.id) > 0 then
            adj[#adj + 1] = { id = math.floor(tonumber(a.id)), ms = math.floor(Num(a.ms, 0, -1000, 3000)) }
        end
    end
    tr.gcdAbilityAdjust = adj
    -- (ultimate doesn't regenerate in ticks)
    if tr.type == "tick" and tr.powerType == "ultimate" then tr.powerType = "stamina" end
    return tr
end
S.NormalizeTrigger = NormalizeTrigger

-- Returns a sanitized copy-in-place of `t` (also returns it). Unknown enum values fall back to
-- defaults, numbers are clamped, lists de-duplicated; unknown extra keys are kept.
function S.Normalize(t)
    if type(t) ~= "table" then t = {} end
    for _, key in ipairs({ "trigger", "display", "position", "load", "conditions" }) do
        if t[key] ~= nil and type(t[key]) ~= "table" then t[key] = nil end
    end
    U.ApplyDefaults(t, S.TRACKER_DEFAULTS)
    local D = S.TRACKER_DEFAULTS
    if type(t.id) ~= "string" or t.id == "" then t.id = U.NewId("t") end
    t.name = (type(t.name) == "string" and U.Trim(t.name) ~= "") and t.name or D.name
    t.enabled = t.enabled ~= false
    if type(t.iconOverride) ~= "string" then t.iconOverride = tostring(t.iconOverride or "") end

    NormalizeTrigger(t.trigger)
    -- more triggers whose entries are shown in the same tracker (max 4 extra)
    local extras = {}
    if type(t.extraTriggers) == "table" then
        for _, x in ipairs(t.extraTriggers) do
            if type(x) == "table" and #extras < 4 then extras[#extras + 1] = NormalizeTrigger(x) end
        end
    end
    t.extraTriggers = extras

    local ds, dd = t.display, D.display
    ds.type = Enum(ds.type, VALID.displayType, dd.type)
    ds.style = Enum(ds.style, VALID.style, dd.style)
    ds.width = Num(ds.width, dd.width, 40, 1200)
    -- down to 1 px: a thin strip under the game's resource bar (Matthis, replacing Miat's Ticks Tracker: "wish i could set
    -- height less than 10"); text that doesn't fit sits centred on it (the text boxes keep the font's own line height)
    ds.height = Num(ds.height, dd.height, 1, 80)
    ds.iconSize = Num(ds.iconSize, dd.iconSize, 12, 200)
    ds.spacing = Num(ds.spacing, dd.spacing, 0, 40)
    ds.columns = math.floor(Num(ds.columns, dd.columns, 1, 30))
    ds.barRows = math.floor(Num(ds.barRows, 0, 0, 40))
    ds.timerOffsetX = math.floor(Num(ds.timerOffsetX, 0, -100, 100))
    ds.timerOffsetY = math.floor(Num(ds.timerOffsetY, 0, -100, 100))
    ds.grow = Enum(ds.grow, VALID.grow, dd.grow)
    ds.maxShown = math.floor(Num(ds.maxShown, dd.maxShown, 1, 60))
    ds.sort = Enum(ds.sort, VALID.sort, dd.sort)
    -- proc grids keep every icon in place unless a sort was picked on purpose
    if t.trigger.type == "procs" and ds.sort == "expiry" and not ds.sortChosen then ds.sort = "fixed" end
    -- ...and show every proc you have (10 hid procs past the tenth), unless a limit was set on purpose
    if t.trigger.type == "procs" and ds.maxShown == dd.maxShown and not ds.maxChosen then ds.maxShown = 40 end
    ds.timeFormat = Enum(ds.timeFormat, VALID.timeFormat, dd.timeFormat)
    ds.fontFace = Enum(ds.fontFace, VALID.fontFace, dd.fontFace)
    ds.fontSize = Num(ds.fontSize, 0, 0, 64)
    ds.headerFontSize = math.floor(Num(ds.headerFontSize, 0, 0, 48))
    ds.fontEffect = Enum(ds.fontEffect, VALID.fontEffect, dd.fontEffect)
    ds.colorMode = Enum(ds.colorMode, VALID.colorMode, dd.colorMode)
    for _, key in ipairs({ "colorFull", "colorMid", "colorEnd", "colorSolid", "textColor", "background" }) do
        ds[key] = Color(ds[key], dd[key])
    end
    ds.alpha = Num(ds.alpha, 1, 0, 1)
    ds.barAlpha = Num(ds.barAlpha, 1, 0, 1)
    ds.scale = Num(ds.scale, 1, 0.3, 4)
    ds.fillReverse = ds.fillReverse == true
    ds.fillCenter = ds.fillCenter == true
    ds.labelPos = (ds.labelPos == "center" or ds.labelPos == "above" or ds.labelPos == "aboveCenter") and ds.labelPos or "left"
    ds.timerColor = Color(ds.timerColor, dd.timerColor)
    ds.stackColor = Color(ds.stackColor, dd.stackColor)
    ds.separateTextColors = ds.separateTextColors == true
    ds.drawLevel = math.floor(Num(ds.drawLevel, 0, 0, 10))
    ds.forceIcon = ds.forceIcon == true
    ds.vertical = ds.vertical == true
    ds.iconTimer = (ds.iconTimer == "shrinkV" or ds.iconTimer == "shrinkH" or ds.iconTimer == "none") and ds.iconTimer or "sweep"
    ds.cooldownColor = Color(ds.cooldownColor, dd.cooldownColor)
    ds.cooldownDesaturate = ds.cooldownDesaturate ~= false
    ds.blinkThreshold = Num(ds.blinkThreshold, dd.blinkThreshold, 0, 60)
    ds.borderSize = math.floor(Num(ds.borderSize, dd.borderSize, 0, 12))
    ds.iconBg = Color(ds.iconBg, dd.iconBg)
    ds.iconPadding = math.floor(Num(ds.iconPadding, dd.iconPadding, 0, 12))
    -- (5.21.18 saved iconCrop, 0 = none, on every icon tracker: only a value someone set carries over)
    if (ds.iconTrim == nil or ds.iconTrim <= 0) and tonumber(ds.iconCrop) and tonumber(ds.iconCrop) > 0 then ds.iconTrim = ds.iconCrop end
    ds.iconCrop = nil
    ds.iconTrim = math.floor(Num(ds.iconTrim, 0, 0, 15))      -- (5.21.19's Auto, -1, becomes none)
    ds.iconStackSize = math.floor(Num(ds.iconStackSize, 0, 0, 48))
    ds.iconStackPos = Enum(ds.iconStackPos, VALID.iconStackPos, "bottomright")
    ds.gameFrame = ds.gameFrame ~= false
    ds.rowBorder = ds.rowBorder == true
    ds.procPercent = ds.procPercent ~= false
    for _, key in ipairs({ "borderColor", "iconTint", "procColorOk", "procColorPart", "procColorBad", "procColorInfo" }) do
        ds[key] = Color(ds[key], dd[key])
    end
    ds.timerTo = ds.timerTo == "ready" and "ready" or "part"
    ds.meterWidth = math.floor(Num(ds.meterWidth, dd.meterWidth, 40, 600))
    ds.meterHeight = math.floor(Num(ds.meterHeight, dd.meterHeight, 20, 200))
    ds.meterAnim = C.METER_ANIM_MS[ds.meterAnim] and ds.meterAnim or dd.meterAnim
    ds.meterAccent = ds.meterAccent ~= false
    ds.meterGauge = ds.meterGauge ~= false
    ds.meterCapColors = ds.meterCapColors ~= false
    ds.meterCaption = ds.meterCaption ~= false
    ds.meterCaptionSize = math.floor(Num(ds.meterCaptionSize, 0, 0, 40))
    ds.textCenter = ds.textCenter == true
    ds.meterCaptionColor = Color(ds.meterCaptionColor, dd.meterCaptionColor)
    ds.zoneColor = Color(ds.zoneColor, dd.zoneColor)
    ds.trackColor = Color(ds.trackColor, dd.trackColor)
    -- the first caption colour (5.17.0-5.17.3) was too dark to read on the tile: brighter, same transparency
    local mc = ds.meterCaptionColor
    if math.abs(mc[1] - 0.80) < 0.005 and math.abs(mc[2] - 0.72) < 0.005 and math.abs(mc[3] - 0.52) < 0.005 then
        ds.meterCaptionColor = { 0.95, 0.87, 0.64, mc[4] }
    end
    for _, key in ipairs({ "labelFormat", "iconLabelFormat", "textFormat", "alertFormat", "title", "texture" }) do
        if type(ds[key]) ~= "string" then ds[key] = dd[key] end
    end
    for _, key in ipairs({ "showHeader", "showUptime", "showEmpty", "showName", "showTimer", "showStacks",
                           "showRowIcon", "highlightTarget", "desaturateInactive", "blink", "headSelf", "keepSlots", "procCards" }) do
        ds[key] = ds[key] == true
    end

    local p = t.position
    p.x = Num(p.x, 0, -5000, 5000)
    p.y = Num(p.y, 0, -5000, 5000)
    p.anchorTo = type(p.anchorTo) == "string" and p.anchorTo or ""
    p.anchorSide = Enum(p.anchorSide, VALID.anchorSide, "below")
    p.gap = Num(p.gap, 4, -200, 200)
    p.anchorAlign = Enum(p.anchorAlign, VALID.anchorAlign, "start")
    p.anchorShift = Num(p.anchorShift, 0, -500, 500)

    local conds = {}
    if type(t.conditions) == "table" then
        for _, c in ipairs(t.conditions) do
            if type(c) == "table" then
                local n = U.ApplyDefaults(c, S.CONDITION_DEFAULTS)
                n.prop = Enum(n.prop, VALID.prop, "remaining")
                n.op = VALID.op[n.op] and n.op or "<="
                -- yes/no and text properties: only "=" / "not =" (an old "<=" there always meant "=")
                local pk = C.Find(C.CONDITION_PROPS, n.prop)
                if pk and pk[3] ~= "number" and n.op ~= "~=" then n.op = "==" end
                -- a second test ("and")
                if type(n.also) == "table" then
                    local a = n.also
                    a.prop = Enum(a.prop, VALID.prop, "remaining")
                    a.op = VALID.op[a.op] and a.op or "<="
                    local ak = C.Find(C.CONDITION_PROPS, a.prop)
                    if ak and ak[3] ~= "number" and a.op ~= "~=" then a.op = "==" end
                    if a.value == nil then a.value = "" end
                    n.also = { prop = a.prop, op = a.op, value = a.value }
                else
                    n.also = nil
                end
                -- switched off in the editor: kept, but ignored
                n.disabled = n.disabled == true or nil
                n.action = Enum(n.action, VALID.action, "color")
                local argKind = C.Find(C.CONDITION_ACTIONS, n.action)[3]
                if argKind == "color" then n.arg = Color(n.arg, S.CONDITION_DEFAULTS.arg) end
                conds[#conds + 1] = n
            end
        end
    end
    t.conditions = conds

    local ld = t.load
    ld.combat = Enum(ld.combat, VALID.combatLoad, "any")
    ld.combatLinger = Num(ld.combatLinger, 0, 0, 60)
    ld.zoneTypes = BoolSet(ld.zoneTypes, C.Values(C.ZONE_TYPES))
    ld.zoneIds = NumberList(ld.zoneIds)
    ld.roles = BoolSet(ld.roles, C.Values(C.ROLES))
    ld.classes = BoolSet(ld.classes, nil, true)
    ld.group = Enum(ld.group, VALID.groupLoad, "any")
    ld.bossOnly = ld.bossOnly == true
    ld.trashOnly = ld.trashOnly == true and not ld.bossOnly
    ld.hideDead = ld.hideDead == true
    ld.characters = StringList(ld.characters, false)
    ld.setId = math.floor(Num(ld.setId, 0, 0, 100000))
    ld.setPieces = math.floor(Num(ld.setPieces, 5, 1, 12))
    ld.setBackbar = ld.setBackbar ~= false
    ld.setFull = ld.setFull == true
    ld.cpSkills = NumberList(ld.cpSkills)
    ld.setNames = StringList(ld.setNames, false)
    ld.skills = NumberList(ld.skills)
    ld.skillNames = StringList(ld.skillNames, true)
    ld.bossNames = StringList(ld.bossNames, true)
    ld.zoneNames = StringList(ld.zoneNames, true)
    ld.werewolf = (ld.werewolf == "only" or ld.werewolf == "never") and ld.werewolf or "any"
    ld.never = BoolSet(ld.never, C.Values(C.LOAD_LIST_GROUPS))
    return t
end

-- Only what differs from the defaults (for "Export as JSON": short enough for a person or an AI
-- assistant to read). Importing the result gives the same tracker back (missing = default).
local function DeepEqual(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) == "number" then return math.abs(a - b) < 1e-6 end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not DeepEqual(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

local function Diff(value, default)
    local out = {}
    for k, v in pairs(value) do
        local d = default[k]
        if type(v) == "table" and type(d) == "table" and next(d) ~= nil and d[1] == nil then
            local sub = Diff(v, d)                         -- a section (trigger, display, load...)
            if next(sub) ~= nil then out[k] = sub end
        elseif d == nil or not DeepEqual(v, d) then
            out[k] = U.Copy(v)
        end
    end
    return out
end

function S.Compact(tracker)
    local D = S.TRACKER_DEFAULTS
    local out = Diff(tracker, D)
    out.name = tracker.name
    out.trigger = out.trigger or {}
    out.trigger.type = tracker.trigger.type
    if type(tracker.extraTriggers) == "table" then
        local extras = {}
        for i, x in ipairs(tracker.extraTriggers) do
            extras[i] = Diff(x, D.trigger)
            extras[i].type = x.type
        end
        out.extraTriggers = #extras > 0 and extras or nil
    end
    if type(tracker.conditions) == "table" then
        out.conditions = #tracker.conditions > 0 and U.Copy(tracker.conditions) or nil
    end
    return out
end

function S.NewTracker(overrides)
    local t = U.Copy(overrides or {})
    t.id = nil
    return S.Normalize(t)
end

-- Duplicate with a fresh id and a "(copy)" suffix.
function S.Clone(tracker)
    local t = U.Copy(tracker)
    t.id = U.NewId("t")
    t.fromCooldowns, t.fromUntaunted, t.fromBTG, t.fromStagger, t.fromExoY, t.fromMeterskull, t.fromMiat, t.fromGcd = nil, nil, nil, nil, nil, nil, nil, nil   -- a copy is yours: a new import must not replace it
    t.name = (tracker.name or "Tracker") .. " (copy)"
    t.position.anchorTo = ""
    return S.Normalize(t)
end

function S.NewCondition(overrides)
    return U.ApplyDefaults(U.Copy(overrides or {}), S.CONDITION_DEFAULTS)
end
