-- The preset library: ready-made trackers (and multi-tracker packs) for common jobs. Each preset
-- builds fresh tracker data; packs keep their internal anchors (the profile remaps ids on add).

local DT = DebuffTracker
local Pr = DT.Presets
local L = DT.L
local U = DT.Util

local ID = {
    MAJOR_BREACH = 62787, MINOR_BREACH = 68588, MAJOR_VULN = 122389, MINOR_VULN = 81519,
    CRUSHER = 17906, MINOR_BRITTLE = 145975, OFF_BALANCE = 62988, OFF_BALANCE_IMMUNITY = 134599,
    TAUNT = 38541, TAUNT_IMMUNITY = 52788, STAGGER = 134340, ALKOSH = 75753, ZEN = 126597,
    MARTIAL_KNOWLEDGE = 127070, CATALYST_FIRE = 142610, CATALYST_FROST = 142652, CATALYST_SHOCK = 142653,
    MINOR_LIFESTEAL = 80020, MINOR_MAGICKASTEAL = 39100,
}
Pr.ID = ID

local CORE_DEBUFFS = { ID.MAJOR_BREACH, ID.MINOR_BREACH, ID.MAJOR_VULN, ID.MINOR_VULN, ID.CRUSHER, ID.MINOR_BRITTLE, ID.OFF_BALANCE }

local RED = { 0.886, 0.294, 0.290, 1 }
local GOLD = { 1, 0.88, 0.5, 1 }

local function DebuffBoard()
    return {
        id = "p_board", name = L("Raid debuff board"),
        trigger = { type = "effect", abilityIds = CORE_DEBUFFS, scope = "enemies", effectType = "debuff" },
        display = { type = "bars", style = "clean", width = 260, height = 22, showRowIcon = true,
                    labelFormat = "{name} - {unit}", sort = "expiry", maxShown = 12 },
        conditions = {
            { prop = "remaining", op = "<=", value = 3, action = "color", arg = RED },
        },
        load = { combat = "in" },
    }
end

local function BossChecklist()
    return {
        id = "p_check", name = L("Boss debuff checklist"),
        trigger = { type = "effect", abilityIds = CORE_DEBUFFS, scope = "boss", mode = "always", perAbility = true },
        display = { type = "icons", style = "clean", iconSize = 36, columns = 7, showHeader = true,
                    title = L("Boss debuffs"), showUptime = false },
        conditions = {
            { prop = "active", op = "==", value = "true", action = "glow", arg = { 0.114, 0.62, 0.459, 1 } },
            { prop = "remaining", op = "<=", value = 3, action = "glow", arg = RED },
            { prop = "active", op = "==", value = "false", action = "pulse" },
        },
        load = { combat = "in", bossOnly = true },
    }
end

local function MissingBreachAlert()
    return {
        id = "p_alert", name = L("Major Breach missing alert"),
        trigger = { type = "effect", abilityIds = { ID.MAJOR_BREACH }, scope = "boss", mode = "missing" },
        display = { type = "alert", iconSize = 48, alertFormat = L("{name} missing!"), textColor = GOLD },
        conditions = {
            { prop = "active", op = "==", value = "false", action = "sound", arg = "GENERAL_ALERT_ERROR" },
        },
        load = { combat = "in", bossOnly = true },
        position = { x = -150, y = -260 },
    }
end

-- Character stats as number tiles (Meter display). One tracker per value, so each has its own colour rules
-- (Meterskull colours spell and physical resist by their own thresholds); a module's second value is
-- attached to the right of (or below) its first. Used by the Library preset and the Meterskull import.
Pr.METER_MODULES = {
    -- key = Meterskull's module name; stats = { {stat, levels key (Meterskull), default rules}, ... }
    -- (penetration / crit damage vs. your target: red below the cap, green at it, blue over it -- built into the Meter)
    { key = "penskull", name = L("Penetration"), on = true, stats = { { "penTarget", "penetration" } } },
    { key = "powerskull", name = L("Power"), on = true, stats = { { "weaponDamage", "power" } } },
    { key = "critskull", name = L("Criticals"), on = true,
      stats = { { "critChance", "critChance" },
                { "critTarget", "critDamage" } } },
    { key = "armorskull", name = L("Resistances"), on = true, stats = { { "spellResist", "spell" }, { "physResist", "physical" } } },
    { key = "hybridarmorskull", name = L("Lowest resistance"), stats = { { "lowestResist", "lowestResist" } } },
    { key = "critresiskull", name = L("Critical resistance"), stacked = true,
      stats = { { "critResist", "critResist" }, { "critResistPct", "critResist" } } },
    { key = "healthskull", name = L("Health recovery"), stats = { { "healthRegen", "recovery" } } },
    { key = "magskull", name = L("Magicka recovery"), stats = { { "magickaRegen", "recovery" } } },
    { key = "stamskull", name = L("Stamina recovery"), stats = { { "staminaRegen", "recovery" } } },
}

-- the trackers of one module: { first, second... }; rules(i) = the colour rules of value i (nil = the defaults)
function Pr.MeterTrackers(m, rules)
    local out = {}
    for i, st in ipairs(m.stats) do
        local name = #m.stats > 1 and (m.name .. " - " .. DT.Const.STAT_CAPTIONS[st[1]]) or m.name
        local t = {
            id = "p_meter_" .. m.key .. "_" .. i, name = name, enabled = m.on == true,
            trigger = { type = "stat", stat = st[1] },
            display = { type = "meter", showHeader = false, meterWidth = 118, meterHeight = 48 },
            conditions = U.Copy((rules and rules(i, st)) or st[3] or {}),
        }
        if i > 1 then
            t.position = { anchorTo = out[1].id, anchorSide = m.stacked and "below" or "right", gap = 2 }
        end
        out[#out + 1] = t
    end
    return out
end

-- A resource tick tracker (Trigger "Resource tick", after Miat's Ticks Tracker): a slim bar that fills up toward your
-- next regen tick, the % on its right and "+amount" in the bar for a moment after each tick. Colours by rules:
--   regen    -> the bar colour                              (DT green)
--   dodge fatigue 1..max -> from `fatigueMin` to `fatigueMax` (stamina only, as Miat does)
--   no regen (blocking, sprinting...) -> `zero`; and about to tick with no regen -> `pre1` past `t1` %, `pre2` past `t2` %
-- o = { res, width, height, regen, zero, pre1, pre2, t1, t2, fatigue (bool), fatigueMax, fatigueMin, fatigueMaxColor,
--       showFull, showPct, showGain, sound (name or nil), pulse, background }; everything optional.
local function Lerp(a, b, f)
    local function L1(x, y) return math.floor((x + (y - x) * f) * 1000 + 0.5) / 1000 end     -- (3 decimals: short exports)
    return { L1(a[1], b[1]), L1(a[2], b[2]), L1(a[3], b[3]), L1(a[4] or 1, b[4] or 1) }
end
function Pr.TickTracker(o)
    o = o or {}
    local res = o.res or "stamina"
    local rules = {}
    if o.fatigue ~= false and res == "stamina" then
        local n = math.max(1, math.floor(o.fatigueMax or 5))
        local lo, hi = o.fatigueMin or { 1, 0.85, 0.3, 1 }, o.fatigueMaxColor or { 0.95, 0.35, 0.2, 1 }
        for i = 1, n do
            rules[#rules + 1] = { prop = "dodgeFatigue", op = ">=", value = i, action = "color", arg = Lerp(lo, hi, n > 1 and (i - 1) / (n - 1) or 1) }
        end
    end
    -- (later rules win: no regen beats fatigue, as in Miat)
    rules[#rules + 1] = { prop = "tickRegen", op = "==", value = 0, action = "color", arg = U.Copy(o.zero or RED) }
    rules[#rules + 1] = { prop = "tickProgress", op = ">", value = o.t1 or 75, action = "color", arg = U.Copy(o.pre1 or { 1, 0.85, 0.3, 1 }),
        also = { prop = "tickRegen", op = "==", value = 0 } }
    rules[#rules + 1] = { prop = "tickProgress", op = ">", value = o.t2 or 85, action = "color", arg = U.Copy(o.pre2 or { 0.95, 0.6, 0.2, 1 }),
        also = { prop = "tickRegen", op = "==", value = 0 } }
    if o.pulse then rules[#rules + 1] = { prop = "sinceTick", op = "<", value = 0.3, action = "pulse" } end
    if o.sound then rules[#rules + 1] = { prop = "sinceTick", op = "<", value = 0.5, action = "sound", arg = o.sound } end
    local label = o.showGain == false and "" or "{gain}"
    return {
        name = L("Resource tick") .. " - " .. DT.Const.Label(DT.Const.TICK_POWER_TYPES, res),
        trigger = { type = "tick", powerType = res, tickShowFull = o.showFull == true },
        display = { type = "bars", style = "clean", showHeader = false, width = o.width or 160, height = o.height or 16,
                    colorMode = "solid", colorSolid = U.Copy(o.regen or { 0.114, 0.620, 0.459, 1 }),
                    labelFormat = label, showTimer = o.showPct ~= false, showRowIcon = false, blink = false,
                    background = U.Copy(o.background or { 0.055, 0.067, 0.082, 0.82 }) },
        conditions = rules,
    }
end

-- The global cooldown bar (Trigger "Global cooldown"): DebuffTracker's own -- a slim bar, the skill's icon on the left,
-- its name in the bar, the time on the right, the ping window as a bright end; colours and sounds by rules.
function Pr.GcdBar()
    return {
        name = L("Global cooldown"),
        trigger = { type = "gcd" },
        display = { type = "bars", style = "clean", showHeader = false, width = 260, height = 22, showRowIcon = true,
                    colorMode = "solid", colorSolid = { 0.40, 0.65, 0.95, 1 }, labelFormat = "{name}", blink = false,
                    zoneColor = { 1, 0.88, 0.5, 0.5 } },
        conditions = {
            -- violet while casting / channeling (Metronome "change colour on channeled"), gold on heavies,
            -- green for the last 0.1 s (Global Cooldown Monitor's light-attack cue)
            { prop = "gcdCasting", op = "==", value = "true", action = "color", arg = { 0.62, 0.45, 0.95, 1 } },
            { prop = "gcdKind", op = "==", value = "heavy", action = "color", arg = { 0.937, 0.624, 0.153, 1 } },
            { prop = "remaining", op = "<=", value = 0.1, action = "color", arg = { 0.25, 0.80, 0.45, 1 } },
        },
        position = { x = -130, y = 180 },
    }
end

-- Group frames (5.23.0): DebuffTracker's own -- slim health bars in the tracker look, coloured by role, the class icon
-- at the left, shields / trauma / can't be healed on the bar, dead and offline members greyed, far ones faded, the
-- game's group menu on right-click. Near the top left of the screen, where group frames usually are.
function Pr.GroupFrames(o)
    o = o or {}
    local sw = (GuiRoot and GuiRoot.GetWidth and GuiRoot:GetWidth()) or 1920
    local sh = (GuiRoot and GuiRoot.GetHeight and GuiRoot:GetHeight()) or 1080
    return {
        name = L("Group frames"),
        trigger = { type = "group", groupSort = "role", groupNames = o.names or "character", groupCompanions = o.companions ~= false,
                    groupSolo = o.solo == true },
        display = { type = "frames", style = "clean", showHeader = false, width = o.width or 230, height = o.height or 30,
                    barRows = o.perColumn or 12, spacing = o.spacing or 2, labelFormat = "{unit}",
                    -- just the frames over the game: no dark panel round them (Yarden: "I hate the black background")
                    trackColor = { 0, 0, 0, 0.55 }, background = { 0, 0, 0, 0 },
                    frameClassIcon = o.classIcon ~= false, frameLeader = true, frameRangeAlpha = o.rangeAlpha or 0.4,
                    hideGameFrames = o.hideGame ~= false, fontSize = o.fontSize or 0, highlightTarget = false, blink = false,
                    tankColor = o.tank, healerColor = o.healer, dpsColor = o.dps, companionColor = o.companion,
                    shieldColor = o.shield, traumaColor = o.trauma, noHealColor = o.noHeal },
        position = { x = math.floor((o.left or 50) - sw / 2), y = math.floor((o.top or 120) - sh / 2) },
    }
end

-- The weave strip (Trigger "Weaving"): the last 10 skills you cast as DebuffTracker tiles -- the skill, its border in
-- the colour of how it went, the time lost in the strip along the bottom, the light attack's letter in the corner -- and
-- the fight's average above them. Nothing round them. In combat and for 10 s after, under the middle of the screen.
function Pr.WeaveStrip(o)
    o = o or {}
    local slots = o.slots or 10
    local w = o.size or 40
    local sw = (GuiRoot and GuiRoot.GetWidth and GuiRoot:GetWidth()) or 1920
    local sh = (GuiRoot and GuiRoot.GetHeight and GuiRoot:GetHeight()) or 1080
    local t = {
        name = L("Weave strip"),
        trigger = { type = "weave", weaveLatency = o.latency == true, weaveConfirm = o.confirm == true,
                    weaveTextMissed = o.textMissed, weaveTextVanished = o.textVanished, weaveTextQueued = o.textQueued,
                    weaveTextBashed = o.textBashed },
        -- just the tiles over the game: no header, no panel (Yarden: a dark box hides the background, and the player
        -- knows what the strip is)
        display = { type = "weave", style = "clean", showHeader = false, background = { 0, 0, 0, 0 }, iconSize = w, columns = slots,
                    weaveRows = o.rows or 1, spacing = 3, weaveIcons = o.icons ~= false, weaveAverage = o.average ~= false,
                    showUptime = false, blink = false, fontFace = "BOLD_FONT", fontEffect = "thick-outline" },
        load = { combat = o.always and "any" or "in", combatLinger = o.always and 0 or (o.linger or 10),
                 zoneTypes = o.homes and { house = true } or {} },
    }
    local p = o.palette
    if p then
        -- (the letters take the slow colour: some palettes' "no light attack" colour is black -- unreadable as text)
        t.display.weaveGoodColor, t.display.weaveOkColor, t.display.weaveSlowColor, t.display.weaveMissColor = p[1], p[2], p[3], p[3]
    end
    -- a frame around the whole strip (WeaveDelays' "Frame color" / "frame thickness")
    if o.border then t.display.windowEdge, t.display.windowEdgeSize = o.border, o.borderSize or 1 end
    if o.left and o.top then
        t.position = { x = math.floor(o.left - sw / 2), y = math.floor(o.top - sh / 2) }
    else
        local width = slots * (w + 3)
        t.position = { x = -math.floor(width / 2), y = 160 }
    end
    return t
end

Pr.LIST = {
    {
        key = "weave", category = L("Me"), name = L("Weave strip (light attack weaving)"), icon = nil,
        description = L("How well you weave light attacks between skills: your last 10 skills; under each, a thin line that grows with the time lost (green on time, gold a little late, red late) and the ms -- a green 0 when it's clean -- or a red letter when the light attack didn't make it (M not pressed, X pressed but it vanished -- cast too fast, Q queued but it never landed); a blue B on the icon for a bash-weave. The fight's average in a tile at the end. In combat and 10 s after. /dt weave hides / shows it; /dt weave reset clears it. Replaces WeaveDelays (/dt weavedelays imports its settings)."),
        build = function() return { Pr.WeaveStrip() } end,
    },
    {
        key = "groupframes", category = L("Group frames"), name = L("Group frames"), icon = nil,
        description = L("Your group as DebuffTracker frames: tanks, healers, then damage dealers, coloured by role, with the class icon, the leader's mark, the health on the right, damage shields, trauma and \"can't be healed\" on the bar. Dead, being resurrected and offline members say so; members out of support range fade. Hover for details, right-click for the group menu (whisper, jump to, promote, kick). Hides the game's group frames while they show (Display tab). Add other trackers to them with \"On group frames\"."),
        build = function() return { Pr.GroupFrames() } end,
    },
    {
        key = "framescourage", category = L("Group frames"), name = L("On group frames: missing Major Courage"), icon = nil,
        description = L("A Major Courage icon beside every member's group frame who doesn't have it. Needs the Group frames tracker. Matches by name (English client)."),
        build = function()
            return { {
                name = L("Courage on group frames"),
                trigger = { type = "effect", names = { "major courage" }, scope = "group", mode = "missing", effectType = "buff" },
                display = { type = "onframes", frameShow = "icons", frameSpot = "right", showTimer = false, maxShown = 1 },
                load = { combat = "in" },
            } }
        end,
    },
    {
        key = "framespa", category = L("Group frames"), name = L("On group frames: Powerful Assault time left"), icon = 61771,
        description = L("A thin bar along the bottom of each member's group frame, running out with their Powerful Assault. Needs the Group frames tracker. Change the buff on the Trigger tab. Matches by name (English client)."),
        build = function()
            return { {
                name = L("Powerful Assault on group frames"),
                trigger = { type = "effect", names = { "powerful assault" }, scope = "group", mode = "present", effectType = "buff" },
                display = { type = "onframes", frameShow = "bar", frameSpot = "bottom", frameBarSize = 3, colorMode = "solid",
                            colorSolid = { 0.95, 0.70, 0.25, 1 }, blink = false },
            } }
        end,
    },
    {
        key = "combatstate", category = L("Me"), name = L("Combat indicator (Combat / No Combat)"), icon = nil,
        description = L("\"No Combat\" in green under your crosshair, \"Combat\" in red while you're fighting -- straight from the game's combat state. Change the words on the Trigger tab; add {elapsed} to the text to see how long the fight has lasted, or a rule \"I'm in combat = yes\" with a sound."),
        build = function()
            return { {
                name = L("Combat indicator"),
                trigger = { type = "combatState" },
                display = { type = "text", showHeader = false, textFormat = "{name}", textCenter = true, width = 200, height = 26,
                            fontFace = "BOLD_FONT", fontSize = 22, fontEffect = "thick-outline",
                            background = { 0, 0, 0, 0 } },     -- just the text (HangryGinger)
                conditions = {
                    { prop = "inCombat", op = "==", value = "false", action = "textColor", arg = { 0.40, 0.88, 0.48, 1 } },
                    { prop = "inCombat", op = "==", value = "true", action = "textColor", arg = { 0.96, 0.42, 0.38, 1 } },
                },
                position = { x = -100, y = 40 },
            } }
        end,
    },
    {
        key = "gcd", category = L("Me"), name = L("Global cooldown bar"), icon = nil,
        description = L("One bar for every global cooldown: the skill you just used with its icon, casts and channels for their whole length, heavy attacks, roll dodges. The bright end is your ping -- press the next skill or light attack when the bar reaches it. Channels and casts in violet, heavy attacks in gold, green for the last 0.1 s (your light attack). Metronome tick / tock sounds on the Trigger tab. Replaces Combat Metronome, GCD Bar and Global Cooldown Monitor."),
        build = function() return { Pr.GcdBar() } end,
    },
    {
        key = "ticks", category = L("Me"), name = L("Resource tick (stamina)"), icon = nil,
        description = L("A slim bar that fills up toward your next stamina regen tick (every 2 s) with \"+amount\" when it lands -- so you know whether to wait a moment before a dodge or a block. Gold to orange with dodge fatigue, red while you don't regenerate (blocking, sprinting), orange-gold just before a tick with no regen. Pick magicka or health on the Trigger tab. Replaces Miat's Ticks Tracker (/dt miat imports its settings)."),
        build = function() return { Pr.TickTracker({ res = "stamina" }) } end,
    },
    {
        key = "potswap", category = L("Me"), name = L("Potion swapper (template)"), icon = nil,
        description = L("Like Comp's Pot Swapper: shows a buff of yours and picks the potion on your quickslot wheel -- slot 4 when the buff will have 15 s or less left by the time your potion is ready (or it's down), slot 3 otherwise. Put your buff in the list (Trigger tab) and your slots in the two rules (Conditions tab). After you change the quickslot yourself it waits 3 s."),
        build = function()
            return { {
                name = L("Potion swapper"),
                trigger = { type = "effect", abilityIds = { 61708 }, scope = "player", mode = "always", effectType = "buff" },
                display = { type = "icons", iconSize = 40, showHeader = false },
                conditions = {
                    { prop = "leftAfterPotion", op = "<=", value = 15, action = "quickslot", arg = 4 },
                    { prop = "leftAfterPotion", op = ">", value = 15, action = "quickslot", arg = 3 },
                },
            } }
        end,
    },
    {
        key = "meters", category = L("Me"), name = L("Character stats (number tiles)"), icon = nil,
        description = L("Your penetration (with your target's debuffs), power, crit chance and crit damage, and resistances as number tiles that roll to every new value. Also added, switched off: lowest resistance, critical resistance and the three recoveries -- turn them on in the list. Replaces Meterskull (/dt meterskull imports its settings)."),
        build = function()
            -- a column on the right of the screen, each at its own place (switched-off ones too, so turning one
            -- on doesn't stack it on another)
            local list, y = {}, -260
            for _, m in ipairs(Pr.METER_MODULES) do
                local ts = Pr.MeterTrackers(m)
                ts[1].position = { x = 480, y = y }
                y = y + (m.stacked and 2 * 48 + 2 or 48) + 8
                for _, t in ipairs(ts) do list[#list + 1] = t end
            end
            return list
        end,
    },
    {
        key = "raidpack", category = L("Packs"), name = L("Raid support pack"),
        icon = ID.MAJOR_BREACH,
        description = L("Debuff board for every enemy, a boss checklist that lights up what's applied, and a big alert when Major Breach is missing on the boss."),
        build = function()
            local board, check, alert = DebuffBoard(), BossChecklist(), MissingBreachAlert()
            check.position = { anchorTo = "p_board", anchorSide = "below", gap = 8 }
            return { board, check, alert }
        end,
    },
    {
        key = "board", category = L("Enemies"), name = L("Raid debuff board"), icon = ID.MINOR_BREACH,
        description = L("One window with every core raid debuff on every enemy: icon, name, enemy, timer. Turns red under 3 seconds."),
        build = function() return { DebuffBoard() } end,
    },
    {
        key = "checklist", category = L("Bosses"), name = L("Boss debuff checklist"), icon = ID.CRUSHER,
        description = L("One icon per debuff on the boss: lit with a timer when applied, grey and pulsing when missing."),
        build = function() return { BossChecklist() } end,
    },
    {
        key = "breachalert", category = L("Bosses"), name = L("Major Breach missing alert"), icon = ID.MAJOR_BREACH,
        description = L("Big centered alert plus a sound when the boss doesn't have Major Breach during a fight."),
        build = function() return { MissingBreachAlert() } end,
    },
    {
        key = "breachmissingadds", category = L("Enemies"), name = L("Enemies missing Major Breach"), icon = ID.MAJOR_BREACH,
        description = L("Every enemy you or your group are fighting that doesn't have Major Breach, by name. Great for trash and public dungeons. Your target is highlighted."),
        build = function()
            return { {
                name = L("Missing Major Breach"),
                trigger = { type = "effect", abilityIds = { ID.MAJOR_BREACH }, scope = "enemies", mode = "missing" },
                display = { type = "bars", width = 200, labelFormat = "{unit}", showTimer = false, maxShown = 8, title = L("No Major Breach") },
                conditions = { { prop = "isTarget", op = "==", value = "true", action = "glow", arg = GOLD } },
                load = { combat = "in" },
            } }
        end,
    },
    {
        key = "offbalance", category = L("Enemies"), name = L("Off Balance cycle (per enemy)"), icon = ID.OFF_BALANCE,
        description = L("One bar per enemy you're fighting: Off Balance timer, then the immunity timer (grey), then green \"ready\" until it's applied again."),
        build = function()
            return { {
                name = L("Off Balance"),
                trigger = { type = "effect", abilityIds = { ID.OFF_BALANCE, ID.OFF_BALANCE_IMMUNITY }, scope = "enemies", mode = "cycle" },
                display = { type = "bars", width = 260, labelFormat = "{unit}: {name}", showRowIcon = true, sort = "unit",
                            desaturateInactive = false, colorMode = "solid", colorSolid = { 0.85, 0.65, 0.25, 1 } },
                conditions = {
                    { prop = "phase", op = "==", value = 2, action = "color", arg = { 0.45, 0.45, 0.48, 1 } },
                    { prop = "phase", op = "==", value = 0, action = "color", arg = { 0.25, 0.75, 0.45, 1 } },
                },
                load = { combat = "in" },
            } }
        end,
    },
    {
        key = "taunt", category = L("Tank"), name = L("Taunt tracker"), icon = ID.TAUNT,
        description = L("Works like Untaunted: your taunt and taunt immunity on every enemy, pulsing red under 3 seconds. A taunt that ended or that another tank took stays on its row a few seconds, and an enemy that dies is removed at once."),
        build = function()
            -- the same tracker the Untaunted import makes from Untaunted's defaults (Systems/Migration.lua)
            local t = DT.Migration.UntauntedTracker(nil)
            t.name = L("Taunts")
            t.display.showHeader, t.display.showUptime = true, true
            t.conditions[#t.conditions + 1] = { prop = "remaining", op = "<=", value = 3, action = "color", arg = RED }
            t.conditions[#t.conditions + 1] = { prop = "remaining", op = "<=", value = 3, action = "pulse" }
            t.load.roles = { tank = true }
            return { t }
        end,
    },
    {
        key = "stagger", category = L("Tank"), name = L("Heat Shock (Magma Fist, StaggerTracker)"), icon = ID.STAGGER,
        description = L("Dragonknight: your Heat Shock (Magma Fist, which was Stone Giant before Update 49) on one icon -- its time and stacks, the frame red / orange / yellow / green for 0-3 stacks. Your target's first, else the newest. In combat, with Magma Fist on a bar."),
        build = function()
            -- the same tracker the StaggerTracker import makes (Systems/Migration.lua)
            return { DT.Migration.StaggerTracker(nil) }
        end,
    },
    {
        key = "zenkosh", category = L("Enemies"), name = L("Zenkosh (Z'en + Alkosh)"), icon = ID.ZEN,
        description = L("Two bar trackers: Touch of Z'en on every enemy (shown while you wear Z'en's Redress), and Alkosh's Line-Breaker right below it (shown while you wear Roar of Alkosh). They move together."),
        build = function()
            -- each shows only while ITS set is worn (full bonus), independently of the other
            local function Bars(id, name, effect, set)
                return {
                    id = id, name = name,
                    trigger = { type = "effect", abilityIds = { effect }, scope = "enemies" },
                    display = { type = "bars", width = 240, height = 22, showRowIcon = true, labelFormat = "{unit}",
                        sort = "expiry", maxShown = 12, showStacks = true },
                    load = { combat = "in", setId = set, setFull = true },
                }
            end
            local zen = Bars("p_zen", L("Z'en"), ID.ZEN, 455)            -- Z'en's Redress
            -- Touch of Z'en's strength = your DoTs on the enemy (up to 5%). The game always reports 0
            -- stacks for it (in-game log; Combat Metrics only special-cases it so the 0-stack uptime is
            -- recorded), so the DoTs are counted, like Cooldowns does -- shown from x0 to x5
            zen.trigger.stacksFrom, zen.trigger.stacksMax = "mydots", 5
            local alkosh = Bars("p_alkosh", L("Alkosh"), ID.ALKOSH, 232)   -- Roar of Alkosh
            alkosh.position = { anchorTo = "p_zen", anchorSide = "below", gap = 6 }
            return { zen, alkosh }
        end,
    },
    {
        key = "catalyst", category = L("Enemies"), name = L("Elemental Catalyst"), icon = ID.CATALYST_FIRE,
        description = L("Fire, frost and shock Catalyst stacks on the boss as a checklist."),
        build = function()
            return { {
                name = L("Elemental Catalyst"),
                trigger = { type = "effect", abilityIds = { ID.CATALYST_FIRE, ID.CATALYST_FROST, ID.CATALYST_SHOCK },
                            scope = "boss", mode = "always", perAbility = true },
                display = { type = "icons", iconSize = 34, columns = 3 },
                load = { combat = "in", bossOnly = true },
            } }
        end,
    },
    {
        key = "mybuffs", category = L("Me"), name = L("My major buffs (checklist)"), icon = nil,
        description = L("Major Brutality, Sorcery, Prophecy, Savagery, Resolve and Courage on you: lit when up, grey when missing. Matches by name (English client)."),
        build = function()
            return { {
                name = L("My buffs"),
                trigger = { type = "effect", names = { "major brutality", "major sorcery", "major prophecy",
                                                        "major savagery", "major resolve", "major courage" },
                            scope = "player", mode = "always", perAbility = true, effectType = "buff" },
                display = { type = "icons", iconSize = 32, columns = 6, showHeader = false },
            } }
        end,
    },
    {
        key = "pentarget", category = L("Enemies"), name = L("My penetration vs. my target"), icon = 61743,
        description = L("Your penetration plus what the debuffs on your target add (Breach, Crusher, Alkosh...), against the 18200 cap: red while you're short, green when capped. The bar text lists the debuffs."),
        build = function()
            return { {
                name = L("Penetration"),
                trigger = { type = "stat", stat = "penTarget" },
                display = { type = "bars", width = 260, labelFormat = "{value} / {max}", colorMode = "solid", colorSolid = { 0.25, 0.75, 0.45, 1 } },
                conditions = { { prop = "penMissing", op = ">", value = 0, action = "color", arg = { 0.886, 0.294, 0.290, 1 } } },
                load = { combat = "in" },
            } }
        end,
    },
    {
        key = "toggles", category = L("Me"), name = L("My toggles on / off (Overload, werewolf)"), icon = nil,
        description = L("Power Overload and werewolf form: green frame while on, grey while off. Add your own toggle skills by name (part of the name is enough)."),
        build = function()
            return { {
                name = L("Toggles"),
                trigger = { type = "toggle", names = { "overload", "werewolf" }, mode = "always" },
                display = { type = "icons", iconSize = 40, columns = 4, showHeader = false, sort = "fixed", sortChosen = true },
                conditions = {
                    { prop = "active", op = "==", value = "true", action = "glow", arg = { 0.25, 0.75, 0.45, 1 } },
                },
            } }
        end,
    },
    {
        key = "groupcourage", category = L("Group"), name = L("Who is missing Major Courage"), icon = nil,
        description = L("Lists group members who don't have Major Courage right now. Matches by name (English client)."),
        build = function()
            return { {
                name = L("Missing Major Courage"),
                trigger = { type = "effect", names = { "major courage" }, scope = "group", mode = "missing", effectType = "buff" },
                display = { type = "bars", width = 200, labelFormat = "{unit}", showTimer = false },
                load = { group = "raid", combat = "in" },
            } }
        end,
    },
    {
        key = "groupbuff", category = L("Group"), name = L("Group buff board (BuffTheGroup)"), icon = 61771,
        description = L("Every group member stays listed (role, account name): coloured with the time left while they have Powerful Assault, grey when they don't. Change the buff on the Trigger tab. In group dungeons, arenas and trials."),
        build = function()
            -- the same tracker the BuffTheGroup import makes from its defaults (Systems/Migration.lua)
            local t = DT.Migration.BTGTracker(nil, 1)
            t.name = L("Group: Powerful Assault")
            t.display.title = ""
            return { t }
        end,
    },
    {
        key = "courageheads", category = L("Above heads"), name = L("Missing Major Courage, above heads"), icon = nil,
        description = L("An icon floats over every group member without Major Courage, so you see who to buff. Allies only. Matches by name (English client)."),
        build = function()
            return { {
                name = L("Courage above heads"),
                trigger = { type = "effect", names = { "major courage" }, scope = "group", mode = "missing", effectType = "buff" },
                display = { type = "heads", iconSize = 36, showTimer = false, maxShown = 1 },
                load = { combat = "in" },
            } }
        end,
    },
    {
        key = "resolveheads", category = L("Above heads"), name = L("Missing Major Resolve, above heads"), icon = nil,
        description = L("For tanks and healers: who is missing Major Resolve, shown over their heads. Allies only."),
        build = function()
            return { {
                name = L("Resolve above heads"),
                trigger = { type = "effect", names = { "major resolve" }, scope = "group", mode = "missing", effectType = "buff" },
                display = { type = "heads", iconSize = 32, showTimer = false, maxShown = 1 },
                load = { combat = "in" },
            } }
        end,
    },
    {
        key = "mybuffsheads", category = L("Above heads"), name = L("My buffs on allies, above heads (template)"), icon = nil,
        description = L("Timers over allies for buffs or heals YOU cast on them. Add your skills on the Trigger tab."),
        build = function()
            return { {
                name = L("My buffs on allies"),
                trigger = { type = "effect", scope = "group", source = "me", effectType = "buff", mode = "present" },
                display = { type = "heads", iconSize = 32, showTimer = true, maxShown = 3 },
                conditions = { { prop = "remaining", op = "<=", value = 3, action = "pulse" } },
            } }
        end,
    },
    {
        key = "targethealth", category = L("Resources"), name = L("Target health"), icon = nil,
        description = L("Your target's health as a bar with percent. Turns red in execute range (under 25%)."),
        build = function()
            return { {
                name = L("Target health"),
                trigger = { type = "resource", unit = "target", powerType = "health" },
                display = { type = "bars", width = 260, height = 24, labelFormat = "{unit}", colorMode = "solid",
                            colorSolid = { 0.75, 0.2, 0.2, 1 }, showHeader = false },
                conditions = { { prop = "pct", op = "<=", value = 25, action = "pulse" } },
            } }
        end,
    },
    {
        key = "targethpcrosshair", category = L("Resources"), name = L("Target health % by the crosshair"), icon = nil,
        description = L("Just a number next to your crosshair: the health % of whatever you're looking at. Turns red in execute range (25% and below). Move it with /dt move."),
        build = function()
            return { {
                name = L("Target HP %"),
                trigger = { type = "resource", unit = "target", powerType = "health" },
                display = { type = "text", textFormat = "{pct}", showHeader = false, width = 80, height = 28,
                            fontFace = "BOLD_FONT", fontSize = 22, fontEffect = "thick-outline", background = { 0, 0, 0, 0 } },
                conditions = { { prop = "pct", op = "<=", value = 25, action = "textColor", arg = { 1, 0.25, 0.25, 1 } } },
                position = { x = 60, y = -14 },
            } }
        end,
    },
    {
        key = "bosshealth", category = L("Resources"), name = L("Boss health bars"), icon = nil,
        description = L("Health of every boss with percent, sorted by name."),
        build = function()
            return { {
                name = L("Bosses"),
                trigger = { type = "resource", unit = "boss", powerType = "health" },
                display = { type = "bars", width = 260, height = 22, labelFormat = "{unit}", colorMode = "solid",
                            colorSolid = { 0.65, 0.18, 0.18, 1 }, sort = "unit" },
            } }
        end,
    },
    {
        key = "ultimate", category = L("Resources"), name = L("Ultimate ready alert"), icon = nil,
        description = L("A big alert and sound the moment your ultimate is full, during combat."),
        build = function()
            return { {
                name = L("Ultimate ready"),
                trigger = { type = "resource", unit = "player", powerType = "ultimate", thresholdOp = ">=", threshold = 100 },
                display = { type = "alert", iconSize = 40, alertFormat = L("Ultimate ready!"), showTimer = false, textColor = GOLD },
                conditions = { { prop = "pct", op = ">=", value = 100, action = "sound", arg = "ABILITY_ULTIMATE_READY" } },
                load = { combat = "in" },
            } }
        end,
    },
    {
        key = "proc", category = L("Timers"), name = L("Proc cooldown timer (template)"), icon = nil,
        description = L("Starts a timer whenever an ability fires: its active part (green), then its cooldown (red), then 'Ready' (glowing). Use \"Fill from the proc catalogue\" on the Trigger tab, or add the ability ID and timings yourself."),
        build = function()
            return { {
                name = L("Proc cooldown"),
                trigger = { type = "combat", combatSource = "me", duration = 10, cooldown = 20, showReady = true },
                display = { type = "icons", iconSize = 44, iconLabelFormat = "{name}" },
                conditions = {
                    { prop = "active", op = "==", value = "false", action = "glow", arg = { 0.114, 0.62, 0.459, 1 } },
                    -- green while the proc's buff is up, red during its cooldown (Tony's favourite rule)
                    { prop = "phase", op = "==", value = 2, action = "color", arg = { 0.886, 0.294, 0.290, 1 } },
                    { prop = "buffUp", op = "==", value = "true", action = "color", arg = { 0.251, 0.749, 0.451, 1 } },
                },
            } }
        end,
    },
    {
        key = "sulxansoul", category = L("Timers"), name = L("Sul-Xan's soul spawned"), icon = 157738,
        description = L("While you wear Sul-Xan's Torment: when an enemy you killed leaves a soul, an icon counts down how long it stays (pick it up for the buff), with a sound and a screen alert."),
        build = function()
            return { {
                name = L("Sul-Xan soul"),
                trigger = { type = "combat", abilityIds = { 157738 }, combatSource = "me", combatResult = "gained",
                    duration = 6.6, durationFromHit = true, minInterval = 0.2, restartOnRefresh = true },
                display = { type = "icons", iconSize = 48, iconLabelFormat = "", showHeader = false },
                conditions = {
                    { prop = "phase", op = "==", value = 1, action = "alert", arg = L("Soul spawned!") },
                    { prop = "phase", op = "==", value = 1, action = "sound", arg = "NEW_NOTIFICATION" },
                    { prop = "remaining", op = "<=", value = 2, action = "pulse" },
                },
                load = { setNames = { "Sul-Xan's Torment" } },
            } }
        end,
    },
    {
        key = "myprocs", category = L("Timers"), name = L("My procs (Cooldowns replacement)"), icon = 61459,
        description = L("Every proc you have, automatically: set procs when the full set is worn, monster sets, mythics and stacking sets (about 100 sets are known by set ID; LibSets adds the rest) -- plus the synergies, class passives and champion skills you tick on the Trigger tab. Active time, cooldown (greyed) and ready. Resource sets (Bahsei's Mania, Coral Riptide) show your resource as a gauge with their current bonus; Martial Knowledge shows your stamina (it only procs under 50%), Pearls of Ehlnofey counts its procs and shows your main resource; Roaring Opportunist shows the Major Slayer you'd give right now and how many players have it. A sound plays when a proc is ready again (change or remove it under Conditions; \"Step = 1\" plays one on every proc)."),
        build = function()
            return { {
                name = L("My procs"),
                trigger = { type = "procs" },
                display = { type = "icons", iconSize = 48, columns = 8, showHeader = false, iconLabelFormat = "" },
                load = { hideDead = true },
                conditions = { { prop = "sinceReady", op = "<", value = 1, action = "sound", arg = "SKILL_LINE_ADDED" } },
            } }
        end,
    },
    {
        key = "myprocsexoy", category = L("Timers"), name = L("My procs (ExoY's ProcSet Timer style)"), icon = 61459,
        description = L("Your procs like ExoY's ProcSet Timer: buff time from the game, then the cooldown; the frame and the time green while active, red on cooldown; mythic stacks green at their most; Touch of Z'en counted on the boss when there is one."),
        build = function()
            -- the same tracker the ExoY import makes from its defaults (Systems/Migration.lua)
            local list = DT.Migration.ConvertExoY(nil)
            local t = list[1]
            t.fromExoY = nil
            t.name = L("My procs (ExoY)")
            return { t }
        end,
    },
}

function Pr.Get(key)
    for _, p in ipairs(Pr.LIST) do if p.key == key then return p end end
end

function Pr.Add(key)
    local p = Pr.Get(key)
    if not p then return nil end
    return DT.Profiles.AddTrackers(p.build())
end
