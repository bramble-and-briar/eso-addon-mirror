-- -----------------------------------------------------------------------------
-- PCT - Tracking.lua
-- Event registration, cooldown tracking, and set enable/disable logic.
-- -----------------------------------------------------------------------------
PvPCooldownTracker = PvPCooldownTracker or {}
PvPCooldownTracker.Tracking = {}
PvPCooldownTracker.first_run = PvPCooldownTracker.first_run or {}

local Tracking = PvPCooldownTracker.Tracking
local PCT = PvPCooldownTracker

local EM = EVENT_MANAGER
local UPDATE_INTERVAL_MS = 100

local IGNORE_ABILITY_IDS = {
    [973]   = true,
    [15356] = true,
    [14890] = true,
    [55146] = true,
    [28549] = true,
    [29721] = true,
    [98294] = true,
    [69143] = true,
}

-- Critical results count as their non-critical counterpart when matching procs.
local RESULT_EQUIVALENT = {}
if ACTION_RESULT_CRITICAL_DAMAGE ~= nil then RESULT_EQUIVALENT[ACTION_RESULT_CRITICAL_DAMAGE] = ACTION_RESULT_DAMAGE end
if ACTION_RESULT_CRITICAL_HEAL ~= nil then RESULT_EQUIVALENT[ACTION_RESULT_CRITICAL_HEAL] = ACTION_RESULT_HEAL end
PvPCooldownTracker.Tracking.RESULT_EQUIVALENT = RESULT_EQUIVALENT
PvPCooldownTracker.Tracking.IGNORE_ABILITY_IDS = IGNORE_ABILITY_IDS

local SET_ALIASES = {
    ["Two-Fanged Snake"] = "Twice-Fanged Serpent",
}

-- -----------------------------------------------------------------------------
-- Helpers (delegate to shared state at runtime)
-- -----------------------------------------------------------------------------
local function GetSavedVars()
    if PCT.Settings and type(PCT.Settings.EnsureState) == "function" then
        return PCT.Settings.EnsureState()
    end
    return PCT.savedVars or {}
end

local function IsStateContainer(value)
    if type(PCT.IsStateContainer) == "function" then
        return PCT.IsStateContainer(value)
    end
    local t = type(value)
    return value ~= nil and (t == "table" or t == "userdata")
end

-- Normalize set.id (number or array) into a flat array for iteration.
local function GetAbilityIds(set)
    if type(set.id) == "table" then return set.id end
    return { set.id }
end

-- -----------------------------------------------------------------------------
-- Cooldown start
-- -----------------------------------------------------------------------------
local function StartCooldown(setKey)
    local set = PCT.Data.Sets[setKey]
    if not set then return end

    local savedVars = GetSavedVars()
    local savedSet  = savedVars.sets and savedVars.sets[setKey]
    if not savedSet then return end

    set.timeOfProc = GetGameTimeMilliseconds()
    if savedVars.lagCompensation then
        set.timeOfProc = set.timeOfProc + GetFrameDeltaTimeMilliseconds()
    end

    local delay = tonumber(set.procDelayMs) or 0
    if delay > 0 then
        set.timeOfProc = set.timeOfProc + delay
    end

    set.onCooldown  = true
    set.enabled     = true
    set.justProcced = true
    PCT.first_run[setKey] = true

    PCT.UI.PlaySound(savedSet.sounds.onProc)
    EM:RegisterForUpdate(
        PCT.name .. setKey .. "Count",
        UPDATE_INTERVAL_MS,
        function() PCT.UI.Update(setKey) end
    )
end

-- -----------------------------------------------------------------------------
-- Event callbacks
-- -----------------------------------------------------------------------------
local function OnCooldownUpdated(setKey, _, abilityId)
    local set = PCT.Data.Sets[setKey]
    if set.onCooldown then return end
    StartCooldown(setKey)
    PCT:Trace(1, "Cooldown proc for <<1>> (<<2>>)", setKey, abilityId)
end

local function OnCombatEvent(setKey, _, result, _, abilityName, _, _, _, _, _, _, _, _, _, _, _, _, abilityId)
    local set = PCT.Data.Sets[setKey]
    if result == ACTION_RESULT_ABILITY_ON_COOLDOWN then
        PCT:Trace(1, "<<1>> (<<2>>) on Cooldown", abilityName, abilityId)
        return
    end
    if not set then return end
    -- A critical hit/heal of the proc is still the proc.
    if result == set.result or (RESULT_EQUIVALENT[result] ~= nil and RESULT_EQUIVALENT[result] == set.result) then
        PCT:Trace(1, "Name: <<1>> ID: <<2>> with result <<3>> INFO", abilityName, abilityId, result)
        StartCooldown(setKey)
    end
end

local function OnCombatStateChanged(_, inCombat)
    PCT.isInCombat = inCombat
    PCT:Trace(2, "In Combat: <<1>>", tostring(inCombat))
    PCT.UI:SetCombatStateDisplay()
end

local function OnAlive()
    PCT.isDead = false
    PCT.UI:SetCombatStateDisplay()
end

local function OnDeath()
    PCT.isDead = true
    PCT.UI:SetCombatStateDisplay()
end

local function OnCombatEventUnfiltered(_, result, _, abilityName, _, _, _, _, _, _, _, _, _, _, _, _, abilityId)
    if IGNORE_ABILITY_IDS[abilityId] then return end
    PCT:Trace(1, "<<1>> (<<2>>) with result <<3>>", abilityName, abilityId, result)
end

-- Kept for debug use; enable via RegisterUnfiltered() by uncommenting below.
local function OnEffectChangedUnfiltered(_, changeType, _, effectName, _, _, _, _, iconName, _, _, _, _, _, _, abilityId)
    if IGNORE_ABILITY_IDS[abilityId] then return end
    PCT:Trace(1, "<<1>> (<<2>>) with change type <<3>> <<4>>", effectName, abilityId, changeType, iconName)
end

-- -----------------------------------------------------------------------------
-- Normalize "Perfect" / "Perfected" set names
-- -----------------------------------------------------------------------------
local function NormalizePerfectSetName(setKey)
    if not string.find(setKey, "Perfect", 1, true) then
        return setKey
    end
    for _, prefix in ipairs(PCT.Data.PerfectString) do
        local stripped, count = string.gsub(setKey, prefix, "")
        if count > 0 then
            PCT:Trace(1, "Found <<1>> version of <<2>>", prefix, stripped)
            return stripped
        end
    end
    return setKey
end

-- -----------------------------------------------------------------------------
-- Set-level event registration helpers
-- Extracted from EnableTrackingForSet to avoid duplicated loop code.
-- -----------------------------------------------------------------------------
local function RegisterSetEvents(setKey, set)
    local callback = (set.event == EVENT_ABILITY_COOLDOWN_UPDATED)
        and OnCooldownUpdated or OnCombatEvent
    for _, id in ipairs(GetAbilityIds(set)) do
        local eventName = PCT.name .. "_" .. id
        EM:RegisterForEvent(eventName, set.event, function(...) callback(setKey, ...) end)
        EM:AddFilterForEvent(eventName, set.event,
            REGISTER_FILTER_ABILITY_ID, id,
            REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    end
end

local function UnregisterSetEvents(setKey, set)
    EM:UnregisterForUpdate(PCT.name .. setKey .. "Count")
    for _, id in ipairs(GetAbilityIds(set)) do
        EM:UnregisterForEvent(PCT.name .. "_" .. id, set.event)
    end
end

-- -----------------------------------------------------------------------------
-- Public: global event management
-- -----------------------------------------------------------------------------
function PvPCooldownTracker.Tracking.RegisterUnfiltered()
    -- Uncomment for effect-change debugging:
    -- EM:RegisterForEvent(PCT.name .. "_UnfilteredEffect", EVENT_EFFECT_CHANGED, OnEffectChangedUnfiltered)
    -- EM:AddFilterForEvent(PCT.name .. "_UnfilteredEffect", EVENT_EFFECT_CHANGED, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

    EM:RegisterForEvent(PCT.name .. "_Unfiltered", EVENT_COMBAT_EVENT, OnCombatEventUnfiltered)
    EM:AddFilterForEvent(PCT.name .. "_Unfiltered", EVENT_COMBAT_EVENT,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    PCT:Trace(1, "Registered Unfiltered Events")
end

function PvPCooldownTracker.Tracking.UnregisterUnfiltered()
    EM:UnregisterForEvent(PCT.name .. "_Unfiltered", EVENT_COMBAT_EVENT)
    PCT:Trace(1, "Unregistered Unfiltered Events")
end

function PvPCooldownTracker.Tracking.RegisterEvents()
    local sv = GetSavedVars()
    EM:RegisterForEvent(PCT.name, EVENT_PLAYER_ALIVE, OnAlive)
    EM:RegisterForEvent(PCT.name, EVENT_PLAYER_DEAD, OnDeath)
    if not sv.showOutsideCombat then
        Tracking.RegisterCombatEvent()
    end
    PCT:Trace(2, "Registered Events")
end

function PvPCooldownTracker.Tracking.UnregisterEvents()
    EM:UnregisterForEvent(PCT.name, EVENT_PLAYER_ALIVE)
    EM:UnregisterForEvent(PCT.name, EVENT_PLAYER_DEAD)
    PCT:Trace(2, "Unregistered Events")
end

function PvPCooldownTracker.Tracking.RegisterCombatEvent()
    EM:RegisterForEvent(PCT.name .. "COMBAT", EVENT_PLAYER_COMBAT_STATE, OnCombatStateChanged)
    PCT:Trace(2, "Registered combat events")
end

function PvPCooldownTracker.Tracking.UnregisterCombatEvent()
    EM:UnregisterForEvent(PCT.name .. "COMBAT", EVENT_PLAYER_COMBAT_STATE)
    PCT:Trace(2, "Unregistered combat events")
end

-- -----------------------------------------------------------------------------
-- Public: enable/disable tracking for a specific set
-- -----------------------------------------------------------------------------
function PvPCooldownTracker.Tracking.EnableTrackingForSet(setKey, enabled)
    -- Exact catalog keys (e.g. player-added procs) win over name normalization.
    if not PCT.Data.Sets[setKey] then
        setKey = NormalizePerfectSetName(setKey)
        setKey = SET_ALIASES[setKey] or setKey
    end

    local set = PCT.Data.Sets[setKey]
    if not set then return end

    if enabled then
        -- Respect manual disable
        if PCT.character
            and IsStateContainer(PCT.character[set.procType])
            and PCT.character[set.procType][setKey] == false then
            PCT:Trace(1, "Force disabled <<1>>, skipping enable", setKey)
            return
        end

        PCT:Trace(1, "Enabling tracking for <<1>>", setKey)
        RegisterSetEvents(setKey, set)
        set.enabled = true
        PCT.UI.Draw(setKey)
    else
        -- Respect manual enable (don't auto-disable user-pinned sets)
        if set.procType == "set"
            and PCT.character
            and IsStateContainer(PCT.character[set.procType])
            and PCT.character[set.procType][setKey] == true then
            PCT:Trace(2, "Manual setting keeps <<1>> enabled", setKey)
            if not set.enabled then
                set.enabled = true
                PCT.UI.Draw(setKey)
            end
            return
        end

        if set.enabled then
            PCT:Trace(1, "Disabling tracking for: <<1>>", setKey)
            UnregisterSetEvents(setKey, set)
            set.enabled    = false
            set.onCooldown = false
        end
    end
end

-- -----------------------------------------------------------------------------
-- Public: fake a proc so the player can preview a tracker from the settings menu
-- -----------------------------------------------------------------------------
function PvPCooldownTracker.Tracking.TestProc(setKey)
    local set = PCT.Data.Sets[setKey]
    if not set or not set.enabled then return false end
    StartCooldown(setKey)
    return true
end

-- -----------------------------------------------------------------------------
-- Debug callback (used for raw EVENT_COMBAT_EVENT inspection)
-- -----------------------------------------------------------------------------
function PvPCooldownTracker:Debug(eventCode, result, isError, abilityName, abilityGraphic,
    abilityActionSlotType, sourceName, sourceType, targetName, targetType, HitValue,
    powerType, damageType, log, sourceUnitId, targetUnitId, abilityId)
    if not isError then
        d(string.format("Target Name: %s Ability ID: %d Ability Name: %s Result: %s Ability Graphic: %s",
            targetName, abilityId, abilityName, result, abilityGraphic))
    end
end
