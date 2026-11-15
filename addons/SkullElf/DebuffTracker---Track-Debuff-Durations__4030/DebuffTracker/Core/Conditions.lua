-- Condition rules: "if <property> <operator> <value> then <action>". Rules are evaluated per state
-- every tick, in order; later rules win when they set the same thing. One-shot actions (sound,
-- screen alert) fire when a rule starts matching for a state, not every tick while it matches.

local DT = DebuffTracker
local Cond = DT.Conditions
local C = DT.Const
local U = DT.Util

local PROP_KIND = {}
for _, p in ipairs(C.CONDITION_PROPS) do PROP_KIND[p[1]] = p[3] end

local PERMANENT = 99999

local function Prop(prop, s, now, ctx)
    if prop == "remaining" then
        if not s.active then return 0 end
        if s.expire and s.expire > 0 then return math.max(0, s.expire - now) end
        return PERMANENT
    elseif prop == "elapsed" then
        return (s.start and s.start > 0) and math.max(0, now - s.start) or 0
    elseif prop == "progress" then
        if s.pct then return s.pct end
        if not s.active then return 0 end
        if (s.duration or 0) > 0 then return U.Clamp((s.expire - now) / s.duration * 100, 0, 100) end
        return 100
    elseif prop == "penTarget" or prop == "penMissing" or prop == "penOver" or prop == "critTarget" then
        -- against this entry's enemy when it has a tag the game can read (boss1, reticleover), else your target
        local tag = s.unitTag
        if not (tag and (tag == "reticleover" or tag:sub(1, 4) == "boss")) then tag = "reticleover" end
        if prop == "critTarget" then return (DT.Stats.Value("critTarget", now, tag)) end
        local pen, cap = DT.Stats.Value("penTarget", now, tag)
        if prop == "penTarget" then return pen end
        if prop == "penOver" then return math.max(0, pen - cap) end
        return math.max(0, cap - pen)
    elseif prop == "potionCooldown" then return DT.Quickslot.Cooldown()
    elseif prop == "leftAfterPotion" then
        -- this entry's time left minus the potion cooldown: what's left of the buff when the potion can be drunk
        -- (Comp's Pot Swapper: at or under its threshold -> select the buff's potion)
        return Prop("remaining", s, now, ctx) - DT.Quickslot.Cooldown()
    elseif prop == "stacks" then return s.stacks or 0
    elseif prop == "active" then return s.active == true
    elseif prop == "isTarget" then return s.isTarget == true
    elseif prop == "isBoss" then return s.isBoss == true
    elseif prop == "mine" then return s.mine == true
    elseif prop == "onBar" then return ""        -- (tested by membership in Cond.Test)
    elseif prop == "isMe" then
        local tag = s.unitTag
        return tag == "player" or (tag ~= nil and type(AreUnitsEqual) == "function" and AreUnitsEqual(tag, "player")) or false
    elseif prop == "inRange" then
        -- the game's group support range (heals / buffs reach): BuffTheGroup dims members out of it
        local tag = s.unitTag
        if not tag then return true end
        if tag == "player" then return true end
        if type(IsUnitInGroupSupportRange) ~= "function" then return true end
        return IsUnitInGroupSupportRange(tag) == true
    elseif prop == "value" then return s.value or 0
    elseif prop == "pct" then return s.pct or 0
    elseif prop == "inCombat" then
        -- a combat-state entry knows it exactly (no grace); otherwise the tracker's combat state
        if s.inCombat ~= nil then return s.inCombat end
        return ctx.inCombat == true
    elseif prop == "unitName" then return U.Lower(s.unitName or "")
    elseif prop == "name" then return U.Lower(s.name or "")
    elseif prop == "phase" then return s.phase or (s.active and 1 or 0)
    elseif prop == "onCooldown" then return s.cooldown == true
    elseif prop == "buffUp" then
        if s.phase ~= nil then return s.phase == 1 end
        return s.active == true and not s.cooldown
    elseif prop == "sinceReady" then
        if s.ready and s.readyAt then return math.max(0, now - s.readyAt) end
        return PERMANENT
    elseif prop == "expired" then return s.expired == true
    elseif prop == "sinceEnd" then return s.expired and math.max(0, now - (s.endedAt or now)) or 0
    elseif prop == "role" then return Cond.UnitRole(s)
    elseif prop == "distance" then return Cond.UnitDistance(s)
    elseif prop == "healthPct" then return Cond.UnitHealth(s)
    elseif prop == "tickProgress" then
        if s.fillUp and (s.duration or 0) > 0 then return U.Clamp((now - s.start) / s.duration * 100, 0, 100) end
        return 0
    elseif prop == "sinceTick" then
        if s.gainAt then return math.max(0, now - s.gainAt) end
        return PERMANENT
    elseif prop == "tickRegen" then
        if s.regen then return s.regen end
        return DT.Ticks.Regen(s.tickRes or "stamina")
    elseif prop == "dodgeFatigue" then return DT.Ticks.Fatigue()
    elseif prop == "gcdKind" then return s.gcdKind or ""
    elseif prop == "gcdCasting" then return s.gcdCasting == true
    end
    return nil
end

-- The unit tag an entry is about: tagged scopes carry it; an enemy entry is only addressable
-- when it's your current target.
local function TagOf(s)
    if s.unitTag then return s.unitTag end
    if s.isTarget and DoesUnitExist("reticleover") then return "reticleover" end
    return nil
end

local ROLE_NAMES
function Cond.UnitRole(s)
    local tag = TagOf(s)
    if not tag or type(GetGroupMemberSelectedRole) ~= "function" then return "" end
    if not ROLE_NAMES then
        ROLE_NAMES = {}
        if LFG_ROLE_TANK then ROLE_NAMES[LFG_ROLE_TANK] = "tank" end
        if LFG_ROLE_HEAL then ROLE_NAMES[LFG_ROLE_HEAL] = "healer" end
        if LFG_ROLE_DPS then ROLE_NAMES[LFG_ROLE_DPS] = "dps" end
    end
    return ROLE_NAMES[GetGroupMemberSelectedRole(tag)] or ""
end

-- metres between you and an ally (the game gives positions for allies only); nil when unknown
function Cond.UnitDistance(s)
    local tag = TagOf(s)
    if not tag or type(GetUnitRawWorldPosition) ~= "function" then return nil end
    local z1, x1, y1, w1 = GetUnitRawWorldPosition("player")
    local z2, x2, y2, w2 = GetUnitRawWorldPosition(tag)
    if not z2 or z1 ~= z2 or (x2 == 0 and y2 == 0 and w2 == 0) then return nil end
    return math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2 + (w1 - w2) ^ 2) / 100
end

function Cond.UnitHealth(s)
    local tag = TagOf(s)
    if not tag then return nil end
    local cur, max = GetUnitPower(tag, POWERTYPE_HEALTH)
    if not max or max <= 0 then return nil end
    return cur / max * 100
end

local function ToBool(v)
    if type(v) == "boolean" then return v end
    if type(v) == "number" then return v ~= 0 end
    v = U.Lower(U.Trim(v))
    return v == "true" or v == "yes" or v == "1"
end

local function TestOne(rule, s, now, ctx)
    local kind = PROP_KIND[rule.prop]
    if rule.prop == "onBar" then
        -- StaggerTracker greys the icon until Stone Giant turns into its projectile (133027) on the bar;
        -- each value (ID or name) is checked on both bars, several separated by commas: any of them
        local found = false
        for part in tostring(rule.value or ""):gmatch("[^,]+") do
            if DT.Load.IsOnBar(part) then found = true; break end
        end
        if rule.op == "~=" then return not found end
        return found
    end
    local v = Prop(rule.prop, s, now, ctx)
    if v == nil then return false end
    if kind == "bool" then
        local want = ToBool(rule.value)
        if rule.op == "~=" then return v ~= want end
        return v == want
    elseif kind == "text" then
        local needle = U.Lower(U.Trim(rule.value))
        local found = needle == "" or v:find(needle, 1, true) ~= nil
        if rule.op == "~=" then return not found end
        return found
    end
    local target = tonumber(rule.value)
    if not target then return false end
    local f = DT.Triggers.COMPARE[rule.op]
    return f and f(v, target) or false
end

-- a rule can have a second test that must hold too ("and": rule.also = { prop, op, value }), e.g. Miat's
-- "about to tick" colour only while there's no regen: "Progress to the next tick > 75 and Regen per tick = 0"
function Cond.Test(rule, s, now, ctx)
    if not TestOne(rule, s, now, ctx) then return false end
    local also = rule.also
    if type(also) == "table" and also.prop then return TestOne(also, s, now, ctx) end
    return true
end

-- does a rule read this property (in its test or its "and")?
function Cond.Uses(rule, prop)
    return rule.prop == prop or (type(rule.also) == "table" and rule.also.prop == prop)
end

------------------------------------------------------------------------------
-- One-shot bookkeeping: entered[trackerId][ruleIndex .. "|" .. stateKey] = tick seen
------------------------------------------------------------------------------

local entered = {}
local tickId = 0

function Cond.BeginTick()
    tickId = tickId + 1
end

function Cond.EndTracker(trackerId)
    local e = entered[trackerId]
    if not e then return end
    for k, seen in pairs(e) do
        if seen ~= tickId then e[k] = nil end
    end
end

function Cond.Reset(trackerId)
    if trackerId then entered[trackerId] = nil else entered = {} end
end

local function FireOnce(tracker, ruleIndex, rule, s, now)
    local e = entered[tracker.id]
    if not e then e = {}; entered[tracker.id] = e end
    local key = ruleIndex .. "|" .. s.key
    local first = e[key] == nil
    e[key] = tickId
    if not first then return end
    if rule.action == "sound" then
        local name = type(rule.arg) == "string" and rule.arg or ""
        if SOUNDS and SOUNDS[name] then PlaySound(SOUNDS[name]) end
    elseif rule.action == "alert" then
        local template = type(rule.arg) == "string" and rule.arg or "{name}"
        local text = U.SafeCall("alert text of " .. tracker.name, U.FormatTemplate, template, s, now, tracker.display.timeFormat)
        DT.Announcer.Show(text or template, s.icon)
    end
end

-- Returns the look for a state: nil if no rule matched, else a table with any of
-- color, textColor, glow, pulse, hide, scale. `silent` = don't fire one-shot actions (test mode).
function Cond.Evaluate(tracker, s, now, ctx, silent)
    local rules = tracker.conditions
    if #rules == 0 then return nil end
    local look
    for i, rule in ipairs(rules) do
        if not rule.disabled and Cond.Test(rule, s, now, ctx) then
            look = look or {}
            local a = rule.action
            if a == "color" or a == "textColor" or a == "glow" or a == "timerColor" or a == "stackColor" then
                look[a] = type(rule.arg) == "table" and rule.arg or C.RED
            elseif a == "pulse" then
                look.pulse = true
            elseif a == "hide" then
                look.hide = true
            elseif a == "scale" then
                look.scale = (tonumber(rule.arg) or 100) / 100
            elseif a == "proc" then
                look.proc = true
            elseif a == "grey" then
                look.grey = true
            elseif a == "alpha" then
                look.alpha = U.Clamp((tonumber(rule.arg) or 100) / 100, 0, 1)
            elseif a == "background" then
                look.background = type(rule.arg) == "table" and rule.arg or C.RED
            elseif a == "quickslot" then
                -- every update while it matches (the last matching rule wins); not in sample data / the editor
                if not silent then DT.Quickslot.Want(rule.arg) end
            elseif not silent then
                FireOnce(tracker, i, rule, s, now)
            end
        end
    end
    return look
end
