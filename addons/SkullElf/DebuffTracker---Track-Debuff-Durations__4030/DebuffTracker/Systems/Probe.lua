-- "/dt tabtest": 30 seconds of facts about tab targeting and enemy positions, written to chat and to the
-- debug log (/dt log). Nothing runs until the command is typed, and everything is undone after 30 s.
--
-- Why (Sazane, 5.15.2): "when I have a tracker set to current target it should keep tracking if I have
-- something tab targeted". The game has no unit tag for the tab target: esoui only has
-- IsGameCameraPreferredTargetValid(), ClearGameCameraPreferredTarget() and
-- CycleGameCameraPreferredEnemyTarget() (bindings.xml, ingamescenemanager.lua); Bandits UI only remembers
-- the reticle target's NAME when the flag turns on. Before building on a guess, this records what the game
-- actually does:
--   1. does "reticleover" follow the tab target when you look away? (if yes, nothing to build)
--   2. does EVENT_RETICLE_TARGET_CHANGED fire when Tab picks / cycles a target?
--   3. right after Tab, is the reticle unit the tabbed one?
--   4. Sul-Xan floor marker: does GetUnitRawWorldPosition give an ENEMY's real position (reticleover,
--      boss1), or the player's (ZOS hides some positions)? And what does the soul event (157738) carry?

local DT = DebuffTracker
local U = DT.Util
local Probe = {}
DT.Probe = Probe

local NS = "DebuffTracker5_Probe"
local running, endsAt, last = false, 0, {}

local function Log(fmt, ...)
    local ok, msg = pcall(string.format, fmt, ...)
    msg = ok and msg or tostring(fmt)
    d("|c7FB2E5[DT tabtest]|r " .. msg)
    local log = U.debugLog
    if log then log[#log + 1] = string.format("%.2f tabtest %s", U.Now(), msg) end
end

local function Pos(tag)
    if type(GetUnitRawWorldPosition) ~= "function" or not DoesUnitExist(tag) then return nil end
    local zone, x, y, z = GetUnitRawWorldPosition(tag)
    return string.format("%s/%d/%d/%d", tostring(zone), x or 0, y or 0, z or 0)
end

-- the "target" unit: esoui's unit attribute visualizer has a "target" unit that follows
-- EVENT_TARGET_CHANGED for "player" (unitattributevisualizer.lua). Round 1 showed that event firing when
-- Tab picked an enemy, and "reticleover" NOT following the tab target. Is "target" the tab target?
local function TargetInfo()
    if not DoesUnitExist("target") then return "-" end
    local n = type(GetNumBuffs) == "function" and GetNumBuffs("target") or 0
    local names = {}
    for i = 1, math.min(n, 4) do names[#names + 1] = tostring((GetUnitBuffInfo("target", i))) end
    return string.format("%s dead=%s buffs=%d [%s]", tostring(GetUnitName("target")), tostring(IsUnitDead("target")), n,
        table.concat(names, ", "))
end

local function Snapshot(why)
    local valid = type(IsGameCameraPreferredTargetValid) == "function" and IsGameCameraPreferredTargetValid() or false
    local name = DoesUnitExist("reticleover") and GetUnitName("reticleover") or "-"
    -- positions only at events (round 1: the player's own changes every poll; an enemy's is hidden, 0/0/0/0)
    local line = string.format("tab=%s reticle=%s (id %s) target=%s", tostring(valid), name,
        tostring(DT.Units and DT.Units.reticleUnitId), TargetInfo())
    if why then
        line = line .. string.format(" pos me=%s reticle=%s target=%s boss1=%s", tostring(Pos("player")),
            tostring(Pos("reticleover")), tostring(Pos("target")), tostring(Pos("boss1")))
    end
    if why or line ~= last.line then
        Log("%s%s", why and (why .. ": ") or "", line)
        last.line = line
    end
end

local function Stop()
    if not running then return end
    running = false
    EVENT_MANAGER:UnregisterForUpdate(NS)
    EVENT_MANAGER:UnregisterForEvent(NS, EVENT_RETICLE_TARGET_CHANGED)
    EVENT_MANAGER:UnregisterForEvent(NS .. "Soul", EVENT_COMBAT_EVENT)
    if EVENT_TARGET_CHANGED then EVENT_MANAGER:UnregisterForEvent(NS, EVENT_TARGET_CHANGED) end
    EVENT_MANAGER:UnregisterForEvent(NS .. "Fx", EVENT_EFFECT_CHANGED)
    Log("done -- /dt log to copy everything")
end

function Probe.Start()
    if running then Stop(); return end
    running, endsAt, last = true, U.Now() + 30, {}
    Log("30 s: put a debuff on an enemy, Tab it, look away (at the sky), Tab again to another enemy, look at a third enemy. Wait a second between steps.")
    Snapshot("start")
    EVENT_MANAGER:RegisterForEvent(NS, EVENT_RETICLE_TARGET_CHANGED, function() Snapshot("reticle changed") end)
    -- The Tab key itself isn't hooked: the binding calls a game function that may be protected, and wrapping
    -- it could break Tab for the player. Its effects are what we log: the tab flag (polled), and these events.
    if EVENT_TARGET_CHANGED then
        EVENT_MANAGER:RegisterForEvent(NS, EVENT_TARGET_CHANGED, function(_, tag) Snapshot("target changed (" .. tostring(tag) .. ")") end)
    end
    -- do effect events arrive with the unit tag "target"? (then a tracker could follow it like reticleover)
    EVENT_MANAGER:RegisterForEvent(NS .. "Fx", EVENT_EFFECT_CHANGED,
        function(_, change, _, effectName, unitTag, _, _, _, _, _, _, _, _, unitName, unitId)
            Log("effect event on 'target': %s %s on %s(%s)", tostring(change), tostring(effectName), tostring(unitName), tostring(unitId))
        end)
    EVENT_MANAGER:AddFilterForEvent(NS .. "Fx", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "target")
    -- Sul-Xan's soul: what the event says, and where you / your target are at that moment
    EVENT_MANAGER:RegisterForEvent(NS .. "Soul", EVENT_COMBAT_EVENT,
        function(_, result, _, abilityName, _, _, sourceName, sourceType, targetName, targetType, hitValue, _, _, _, sourceUnitId, targetUnitId, abilityId)
            Log("soul event %s result=%s hit=%s source=%s(%s,%s) target=%s(%s,%s)", tostring(abilityId), tostring(result),
                tostring(hitValue), tostring(sourceName), tostring(sourceType), tostring(sourceUnitId), tostring(targetName),
                tostring(targetType), tostring(targetUnitId))
            Snapshot("at the soul event")
        end)
    EVENT_MANAGER:AddFilterForEvent(NS .. "Soul", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, 157738)
    EVENT_MANAGER:RegisterForUpdate(NS, 200, function()
        if U.Now() >= endsAt then Stop() else Snapshot() end
    end)
end

Probe.Stop = Stop

------------------------------------------------------------------------------
-- "/dt watch <ability ID>" (30 s): everything about one effect, to compare with what you see -- written to chat and
-- the debug log. HangryGinger (5.21.0): the Stagger icons stayed red / grey while StaggerTracker showed 3 stacks.
--   * every EVENT_EFFECT_CHANGED of that ID (any source): change, slot, unit tag / name / ID, stacks, times, source
--   * what DebuffTracker stored for it (enemy list: per enemy, mine / others, stacks, time left)
--   * your target's own buff list entry for it (stacks, cast by you)
--   * the trackers that look for it: what each shows (phase, stacks, time, target?) and "Ability on my bars"
--   * your action bars: each skill slot's ability and, for chaining skills, what it is now (on every change)
------------------------------------------------------------------------------
local W = { running = false }
local function WLog(fmt, ...)
    local ok, msg = pcall(string.format, fmt, ...)
    msg = ok and msg or tostring(fmt)
    d("|c7FB2E5[DT watch]|r " .. msg)
    local log = U.debugLog
    if log then log[#log + 1] = string.format("%.2f watch %s", U.Now(), msg) end
end

local function BarLine()
    local parts = {}
    for _, cat in ipairs({ HOTBAR_CATEGORY_PRIMARY or 0, HOTBAR_CATEGORY_BACKUP or 1 }) do
        for slot = 3, 8 do
            local id = GetSlotBoundId(slot, cat) or 0
            if id > 0 then
                local eff = type(GetEffectiveAbilityIdForAbilityOnHotbar) == "function" and GetEffectiveAbilityIdForAbilityOnHotbar(id, cat) or id
                parts[#parts + 1] = (eff and eff ~= id) and string.format("%d:%d=%d->%d", cat, slot, id, eff) or string.format("%d:%d=%d", cat, slot, id)
            end
        end
    end
    return table.concat(parts, " ")
end

local function TargetLine(id)
    if not DoesUnitExist("reticleover") then return "no target" end
    for i = 1, GetNumBuffs("reticleover") do
        local name, b, e, _, stacks, _, _, effectType, _, _, abilityId, _, byMe = GetUnitBuffInfo("reticleover", i)
        if abilityId == id then
            return string.format("target %s (unitId %s): %s stacks=%s left=%.1f byMe=%s type=%s", tostring(GetUnitName("reticleover")),
                tostring(DT.Units.reticleUnitId), tostring(name), tostring(stacks), (e or 0) - U.Now(), tostring(byMe), tostring(effectType))
        end
    end
    return string.format("target %s (unitId %s): not on it (reaction %s)", tostring(GetUnitName("reticleover")), tostring(DT.Units.reticleUnitId),
        tostring(GetUnitReaction("reticleover")))
end

local function StoreLine(id)
    local base = DT.Effects.BaseId(id)
    local parts = {}
    for unitId, effects in pairs(DT.Effects.store) do
        local e = effects[base]
        if e then
            parts[#parts + 1] = string.format("%s(%s) stacks=%s left=%.1f mine=%s my=%s", tostring(DT.Units.nameOf[unitId]), tostring(unitId),
                tostring(e.stacks), (e.finish or 0) - U.Now(), tostring(e.mine), tostring(e.my ~= nil))
        end
    end
    return #parts > 0 and table.concat(parts, "; ") or "nothing stored"
end

local function TrackersLine(id)
    local parts = {}
    for _, t in ipairs(DT.Profiles.ActiveTrackers()) do
        local uses = false
        for _, tt in ipairs(DT.Triggers.AllTriggers(t)) do
            for _, x in ipairs(tt.trigger.abilityIds or {}) do if x == id then uses = true end end
        end
        if uses then
            local d = DT.Displays.Get(t.id)
            local s = d and d.order[1] and d.order[1].state
            local ok, loaded = pcall(DT.Load.Check, t, DT.Load.Context())
            parts[#parts + 1] = string.format("[%s] %s loaded=%s shown=%s", t.name, t.enabled and "on" or "off", tostring(ok and loaded),
                s and string.format("%s phase=%s active=%s stacks=%s left=%.1f target=%s unit=%s", tostring(s.name), tostring(s.phase),
                    tostring(s.active), tostring(s.stacks), (s.expire or 0) - U.Now(), tostring(s.isTarget), tostring(s.unitName)) or "nothing")
        end
    end
    return #parts > 0 and table.concat(parts, " | ") or "no tracker uses it"
end

local function WStop()
    if not W.running then return end
    W.running = false
    EVENT_MANAGER:UnregisterForEvent(NS .. "Watch", EVENT_EFFECT_CHANGED)
    EVENT_MANAGER:UnregisterForUpdate(NS .. "Watch")
    for i = 1, 3 do EVENT_MANAGER:UnregisterForEvent(NS .. "WatchBar" .. i, ({ EVENT_ACTION_SLOT_UPDATED, EVENT_ACTION_SLOT_STATE_UPDATED, EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED })[i] or 0) end
    WLog("done -- /dt log to copy everything")
end

function Probe.Watch(id)
    id = tonumber(id)
    if W.running then WStop(); return end
    if not id then U.Print(DT.L("Usage: /dt watch <ability ID>  (e.g. /dt watch 134340 for Heat Shock)")); return end
    W.running, W.id, W.endsAt, W.last = true, id, U.Now() + 30, {}
    WLog("30 s watching %d (%s). Do what you normally do with it; the trackers' state is written every second and at every event.", id, tostring(GetAbilityName(id)))
    WLog("bars: %s", BarLine())
    EVENT_MANAGER:RegisterForEvent(NS .. "Watch", EVENT_EFFECT_CHANGED,
        function(_, change, slot, name, tag, b, e, stacks, _, _, effectType, _, _, unitName, unitId, abilityId, sourceType)
            WLog("EVENT change=%s slot=%s tag='%s' unit=%s(%s) stacks=%s begin=%.2f end=%.2f source=%s type=%s", tostring(change), tostring(slot),
                tostring(tag), tostring(unitName), tostring(unitId), tostring(stacks), tonumber(b) or 0, tonumber(e) or 0, tostring(sourceType), tostring(effectType))
            zo_callLater(function()
                if not W.running then return end
                WLog("  -> stored: %s", StoreLine(id))
                WLog("  -> %s", TrackersLine(id))
            end, 50)
        end)
    EVENT_MANAGER:AddFilterForEvent(NS .. "Watch", EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, id)
    local evs = { EVENT_ACTION_SLOT_UPDATED, EVENT_ACTION_SLOT_STATE_UPDATED, EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED }
    for i = 1, 3 do
        if evs[i] then
            EVENT_MANAGER:RegisterForEvent(NS .. "WatchBar" .. i, evs[i], function()
                local line = BarLine()
                if line ~= W.last.bars then W.last.bars = line; WLog("bars changed: %s", line) end
            end)
        end
    end
    EVENT_MANAGER:RegisterForUpdate(NS .. "Watch", 1000, function()
        if U.Now() >= W.endsAt then WStop(); return end
        local line = TargetLine(id) .. " || stored: " .. StoreLine(id) .. " || " .. TrackersLine(id)
            .. " || on bars 133027=" .. tostring(DT.Load.IsOnBar("133027"))
        if line ~= W.last.state then W.last.state = line; WLog("%s", line) end
    end)
end
