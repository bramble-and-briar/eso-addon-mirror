-- Effect recorder: while running, logs every buff/debuff that appears on anyone around you and every
-- ability you use, with IDs and icons, so trackers can be created from what actually happened
-- ("Track this") instead of hunting for ability IDs.

local DT = DebuffTracker
local Rec = DT.Recorder
local U = DT.Util
local Units = DT.Units

local MAX_ENTRIES = 300
local DEDUP_WINDOW = 3

Rec.active = false
Rec.entries = {}        -- newest first
local index = {}        -- dedup key -> entry
Rec.listeners = {}

local function ScopeFromTag(tag)
    if not tag or tag == "" then return "enemies" end
    if tag == "player" then return "player" end
    if tag == "reticleover" then return "target" end
    if tag == "companion" then return "companion" end
    if tag:sub(1, 4) == "boss" then return "boss" end
    if tag:sub(1, 5) == "group" then return "group" end
    return "enemies"
end

local function Notify()
    for _, fn in ipairs(Rec.listeners) do fn() end
end

-- Readable names for combat results ("DAMAGE", "CRITICAL_DAMAGE", "HEAL"...), built once.
local resultNames
function Rec.ResultName(result)
    if not resultNames then
        resultNames = {}
        for k, v in pairs(_G) do
            if type(k) == "string" and type(v) == "number" and k:sub(1, 14) == "ACTION_RESULT_" then
                resultNames[v] = k:sub(15):gsub("_", " "):lower()
            end
        end
    end
    return resultNames[result] or tostring(result)
end

local function Add(kind, abilityId, name, icon, unitName, scope, source, effectType, duration, result, hitValue)
    local now = U.Now()
    local key = kind .. "|" .. abilityId .. "|" .. scope .. "|" .. source .. "|" .. tostring(result or "")
    local e = index[key]
    if e and now - e.last < DEDUP_WINDOW then
        e.count = e.count + 1
        e.last = now
        e.unitName = unitName ~= "" and unitName or e.unitName
        if hitValue then e.hitValue = hitValue end
        return
    end
    e = {
        kind = kind, abilityId = abilityId, name = U.CleanName(name ~= "" and name or GetAbilityName(abilityId)),
        icon = (icon and icon ~= "") and icon or GetAbilityIcon(abilityId), unitName = unitName or "",
        scope = scope, source = source, effectType = effectType, duration = duration or 0,
        result = result, hitValue = hitValue,
        count = 1, first = now, last = now,
    }
    index[key] = e
    table.insert(Rec.entries, 1, e)
    for i = #Rec.entries, MAX_ENTRIES + 1, -1 do
        local old = table.remove(Rec.entries, i)
        for k, v in pairs(index) do if v == old then index[k] = nil end end
    end
    Rec.dirty = true
end

function Rec.OnEffect(changeType, effectName, unitTag, beginTime, endTime, stackCount, iconName, effectType, unitName, unitId, abilityId, sourceType)
    if changeType == EFFECT_RESULT_FADED then return end
    local mine = sourceType == COMBAT_UNIT_TYPE_PLAYER or sourceType == COMBAT_UNIT_TYPE_PLAYER_PET
    local scope = ScopeFromTag(unitTag)
    if scope == "enemies" and Units.IsFriendlyTag(unitTag) then return end
    local duration = (endTime or 0) > (beginTime or 0) and (endTime - beginTime) or 0
    Add("effect", abilityId, effectName or "", iconName, U.CleanName(unitName or ""), scope, mine and "me" or "others", effectType, duration)
end

local function OnCast(_, result, isError, abilityName, _, _, _, _, targetName, _, hitValue, _, _, _, _, _, abilityId)
    if isError or not abilityId or abilityId == 0 then return end
    Add("cast", abilityId, abilityName or "", nil, U.CleanName(targetName or ""), "combat", "me", nil, 0, result, hitValue)
end

-- everything that hits / heals / affects you (who did it, how much)
local function OnIncoming(_, result, isError, abilityName, _, _, sourceName, sourceType, _, _, hitValue, _, _, _, _, _, abilityId)
    if isError or not abilityId or abilityId == 0 then return end
    if sourceType == COMBAT_UNIT_TYPE_PLAYER then return end   -- already logged as one of yours
    Add("incoming", abilityId, abilityName or "", nil, U.CleanName(sourceName or ""), "onme", "others", nil, 0, result, hitValue)
end

-- Snapshot of what is on a unit right now (like an effect viewer): your target, or you.
function Rec.Snapshot(tag)
    tag = tag or (DoesUnitExist("reticleover") and "reticleover" or "player")
    local scope = tag == "player" and "player" or "target"
    local unitName = DT.Units.NameForTag(tag)
    local n = 0
    for i = 1, GetNumBuffs(tag) do
        local name, startTime, endTime, _, _, icon, _, effectType, _, _, abilityId, _, castByPlayer = GetUnitBuffInfo(tag, i)
        if abilityId and abilityId > 0 then
            local duration = (endTime or 0) > (startTime or 0) and (endTime - startTime) or 0
            Add("effect", abilityId, name or "", icon, unitName, scope, castByPlayer and "me" or "others", effectType, duration)
            n = n + 1
        end
    end
    Notify()
    return n, unitName
end

function Rec.Start()
    if Rec.active then return end
    Rec.active = true
    EVENT_MANAGER:RegisterForEvent("DebuffTracker5_RecCast", EVENT_COMBAT_EVENT, OnCast)
    EVENT_MANAGER:AddFilterForEvent("DebuffTracker5_RecCast", EVENT_COMBAT_EVENT,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER, REGISTER_FILTER_IS_ERROR, false)
    EVENT_MANAGER:RegisterForEvent("DebuffTracker5_RecIn", EVENT_COMBAT_EVENT, OnIncoming)
    EVENT_MANAGER:AddFilterForEvent("DebuffTracker5_RecIn", EVENT_COMBAT_EVENT,
        REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER, REGISTER_FILTER_IS_ERROR, false)
    DT.Engine.Rebuild()   -- adds the unfiltered effect registration while recording
    EVENT_MANAGER:RegisterForUpdate("DebuffTracker5_RecNotify", 500, function()
        if Rec.dirty then Rec.dirty = false; Notify() end
    end)
end

function Rec.Stop()
    if not Rec.active then return end
    Rec.active = false
    EVENT_MANAGER:UnregisterForEvent("DebuffTracker5_RecCast", EVENT_COMBAT_EVENT)
    EVENT_MANAGER:UnregisterForEvent("DebuffTracker5_RecIn", EVENT_COMBAT_EVENT)
    EVENT_MANAGER:UnregisterForUpdate("DebuffTracker5_RecNotify")
    DT.Engine.Rebuild()
    Notify()
end

function Rec.Clear()
    Rec.entries, index = {}, {}
    Notify()
end

function Rec.Filtered(text, kindFilter)
    local needle = U.Lower(U.Trim(text or ""))
    local out = {}
    for _, e in ipairs(Rec.entries) do
        local okKind = kindFilter == nil or kindFilter == "all" or kindFilter == e.kind
            or (kindFilter == "mine" and e.source == "me")
        if okKind and (needle == "" or U.Lower(e.name):find(needle, 1, true) or tostring(e.abilityId):find(needle, 1, true)
            or U.Lower(e.unitName):find(needle, 1, true)) then
            out[#out + 1] = e
        end
    end
    return out
end

-- Tracker data for a recorded entry.
function Rec.TrackerFor(e)
    if e.kind == "incoming" then
        -- something that hit you: a timer that starts when it hits you
        return {
            name = e.name,
            trigger = { type = "combat", abilityIds = { e.abilityId }, combatSource = "onme", duration = 10, showReady = false },
            display = { type = "icons", iconSize = 40, iconLabelFormat = "{name}" },
        }
    end
    if e.kind == "cast" then
        return {
            name = e.name,
            trigger = { type = "combat", abilityIds = { e.abilityId }, combatSource = "me", duration = 10, showReady = true },
            display = { type = "icons", iconSize = 40, iconLabelFormat = "{name}" },
        }
    end
    local multi = e.scope == "enemies" or e.scope == "group"
    return {
        name = e.name,
        trigger = { type = "effect", abilityIds = { e.abilityId }, scope = e.scope,
                    source = e.source == "me" and "me" or "any" },
        display = multi and { type = "bars", labelFormat = "{unit}", showRowIcon = false }
                         or { type = "icons", iconSize = 40 },
    }
end
