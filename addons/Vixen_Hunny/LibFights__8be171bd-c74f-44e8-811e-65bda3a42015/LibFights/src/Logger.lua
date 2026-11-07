--[[
    LibFights - Logger
    ------------------------------------------------------------------------
    The ONLY place combat events are registered.  Nothing here runs until
    Start_Logging() is called; Stop_Logging() unregisters everything.

    Events used while logging:
      EVENT_COMBAT_EVENT               damage, healing, shields, avoids, CC, deaths, power
      EVENT_EFFECT_CHANGED             buffs on you, debuffs on bosses / your target
      EVENT_POWER_UPDATE               your resources, boss health (time-to-kill model)
      EVENT_PLAYER_COMBAT_STATE        fight start / end
      EVENT_UNIT_DEATH_STATE_CHANGED   deaths (with death recap)
      EVENT_ACTION_SLOT_ABILITY_USED   casts, light/heavy attacks, weaving, APM
      EVENT_ACTIVE_WEAPON_PAIR_CHANGED bar swaps / bar uptime
      EVENT_INVENTORY_SINGLE_SLOT_UPDATE gear swaps mid fight
      EVENT_PLAYER_ACTIVATED           zone change ends the current fight
      EVENT_UNIT_ATTRIBUTE_VISUAL_*    shield bar on you (shields applied / peak / expired)
]]

local LF = LibFights
local Util, Const = LF.Util, LF.Const
local Logger = {}
LF.Logger = Logger

local EM = EVENT_MANAGER
local NS = "LibFights_Log"
local TICK_NS = "LibFights_LogTick"
local GetGameTimeMilliseconds = GetGameTimeMilliseconds

local CATEGORY = Const.CATEGORY
local CRIT, TICK = Const.CRIT_RESULTS, Const.TICK_RESULTS
local DIR = LF.Fight.DIR

local state = {
    logging = false,
    fight = nil,
    nextId = 1,
    registered = {},
    recap = nil,
    opts = {},
    lastEffect = {},
}
Logger._state = state
LF.fights = LF.fights or {}

local function S()
    local s = LF.GetSettings()
    local o = state.opts
    if o and next(o) then
        -- per-call overrides passed to Start_Logging(options)
        return setmetatable({}, { __index = function(_, k) local v = o[k]; if v ~= nil then return v end return s[k] end })
    end
    return s
end
local settingsView = nil
local function Settings()
    return settingsView or S()
end

-- ---------------------------------------------------------------------------
-- Registration helpers
-- ---------------------------------------------------------------------------
local function Register(suffix, event, fn, ...)
    local ns = NS .. suffix
    EM:RegisterForEvent(ns, event, fn)
    if select("#", ...) > 0 then
        EM:AddFilterForEvent(ns, event, ...)
    end
    state.registered[#state.registered + 1] = { ns = ns, event = event }
end

local function UnregisterAll()
    for _, r in ipairs(state.registered) do
        EM:UnregisterForEvent(r.ns, r.event)
    end
    state.registered = {}
    EM:UnregisterForUpdate(TICK_NS)
end

-- ---------------------------------------------------------------------------
-- Fight lifecycle
-- ---------------------------------------------------------------------------
local Tick -- forward

local function SnapshotBosses(f)
    for i = 1, Const.MAX_BOSSES do
        local tag = "boss" .. i
        if DoesUnitExist(tag) then
            local name = Util.CleanName(GetUnitName(tag))
            f:MarkBoss(name)
        end
    end
end

local function SeedPlayerBuffs(f, now)
    for i = 1, (GetNumBuffs("player") or 0) do
        local buffName, _, _, _, stackCount, iconFilename, _, effectType, _, _, abilityId, _, castByPlayer = GetUnitBuffInfo("player", i)
        if buffName and abilityId then
            local srcType = castByPlayer and Const.UT_PLAYER or Const.UT_OTHER
            f:RecordEffect("player", Const.EFFECT_GAINED, abilityId, buffName, 0, GetUnitName("player"), stackCount, iconFilename, effectType, srcType, now)
        end
    end
end

local function BeginFight(now)
    now = now or GetGameTimeMilliseconds()
    local s = Settings()
    local f = LF.Fight.New(state.nextId)
    state.nextId = state.nextId + 1
    if LF.sv then LF.sv.nextFightId = state.nextId end
    f.startMs = now
    f.lastEventMs = now
    f.lastCombatMs = now
    if s.rawEvents then f.events = Util.NewRing(s.rawEventCap or 20000) end
    f.build = LF.Build.Read(s.buildDetail)
    LF.Stats.BeginTracking(f)
    LF.Sets.BeginTracking(f)
    LF.Procs.BeginTracking(f)
    SnapshotBosses(f)
    SeedPlayerBuffs(f, now)
    f:RecordBarSwap(Util.Try(GetActiveWeaponPairInfo) or Const.WEAPON_PAIR_MAIN, now)
    for _, pt in ipairs({ Const.POWER_HEALTH, Const.POWER_MAGICKA, Const.POWER_STAMINA, Const.POWER_ULTIMATE }) do
        if pt then
            local cur, max, effMax = GetUnitPower("player", pt)
            f:RecordPower(pt, cur or 0, effMax or max or 0, now)
        end
    end
    if s.modelsEnabled then LF.Models.ResetFightTransient() end
    state.fight = f
    EM:RegisterForUpdate(TICK_NS, math.max(200, s.statSampleMs or 1000), Tick)
    LF.Debug("Fight %d started", f.id)
    LF.FireCallback(LF.EVENTS.FIGHT_STARTED, f)
    return f
end

local function EndFight(reason)
    local f = state.fight
    if not f then return nil end
    state.fight = nil
    EM:UnregisterForUpdate(TICK_NS)
    local s = Settings()
    local endMs = math.max(f.lastCombatMs or f.startMs, f.lastEventMs or f.startMs)
    if reason == "stopped" or reason == "split" then endMs = GetGameTimeMilliseconds() end
    f.endReason = reason
    f:Finish(endMs)
    LF.Stats.FinishTracking(f)
    LF.Procs.FinishTracking(f)
    LF.Sets.FinishTracking(f)
    f.models = s.modelsEnabled and LF.Models.GetReport() or nil
    f.summary = f:GetSummary()

    local T = f.totals
    local meaningful = (T.damageOut + T.healOut + T.damageIn + T.shieldAbsorbedIn + (T.groupShieldAbsorbed or 0)) > 0
    if not meaningful or f:GetDurationSec() < (s.minFightSeconds or 2) then
        LF.Debug("Fight %d discarded (%s)", f.id, reason or "?")
        return nil
    end

    local list = LF.fights
    list[#list + 1] = f
    local cap = s.maxFightsInMemory or 25
    while #list > cap do table.remove(list, 1) end

    if s.saveFights and LF.Storage then LF.Storage.SaveFight(f) end
    if s.modelsEnabled and s.persistModels then LF.Models.Save() end
    if s.printFightSummary and LF.Report then LF.PrintLines(LF.Report.FightSummaryLines(f)) end
    LF.Debug("Fight %d ended (%s)", f.id, reason or "?")
    LF.FireCallback(LF.EVENTS.FIGHT_ENDED, f, reason)
    return f
end

local function EnsureFight(now)
    return state.fight or BeginFight(now)
end

local function AnyGroupMemberInCombat()
    if not IsUnitGrouped("player") then return false end
    for i = 1, (GetGroupSize() or 0) do
        local tag = GetGroupUnitTagByIndex(i)
        if tag and IsUnitOnline(tag) and IsUnitInCombat(tag) then return true end
    end
    return false
end

Tick = function()
    local f = state.fight
    if not f then EM:UnregisterForUpdate(TICK_NS) return end
    local s = Settings()
    local now = GetGameTimeMilliseconds()
    local snap = LF.Stats.Sample(f)
    LF.FireCallback(LF.EVENTS.STATS_SAMPLE, f, snap)
    SnapshotBosses(f)

    if s.modelsEnabled then
        -- feed each completed second (timeline bucket) into the DPS forecaster exactly once
        local sec = math.floor((now - f.startMs) / 1000)
        local fed = f._lastFedSecond or 0
        for i = fed + 1, sec do
            local b = f.timeline[i]
            LF.Models.ObserveDPS(b and b.dOut or 0)
        end
        if sec > fed then f._lastFedSecond = sec end
    end

    -- end of combat?
    local idleMs = now - (f.lastCombatMs or f.startMs)
    if not IsUnitInCombat("player") and idleMs >= (s.combatEndGraceMs or 3000) then
        if not (s.groupMode and AnyGroupMemberInCombat()) then
            EndFight("combatEnd")
        end
    elseif idleMs >= (s.fightTimeoutMs or 120000) then
        EndFight("timeout")
    end
end

-- ---------------------------------------------------------------------------
-- Combat events
-- ---------------------------------------------------------------------------
local STARTS_FIGHT_OUT = { damage = true, shield = true, cc = true }
local STARTS_FIGHT_IN = { damage = true, shield = true, avoid = true, cc = true }
local INCOMING_ALSO = { damage = true, heal = true, shield = true }

local function FireCombat(f, dir, cat, result, abilityId, hit, overflow, srcId, tgtId, damageType)
    if LF.listenerCount[LF.EVENTS.COMBAT_EVENT] then
        LF.FireCallback(LF.EVENTS.COMBAT_EVENT, f, dir, cat, result, abilityId, hit, overflow, srcId, tgtId, damageType)
    end
end

local function HandleOutgoing(result, abilityName, graphic, slotType, sourceName, sourceType, targetName, targetType, hit, powerType, damageType, sourceUnitId, targetUnitId, abilityId, overflow)
    local cat = CATEGORY[result] or "other"
    local now = GetGameTimeMilliseconds()
    local f = state.fight
    if not f then
        if not STARTS_FIGHT_OUT[cat] then return end
        if cat == "damage" and hit <= 0 then return end
        f = BeginFight(now)
    end
    hit, overflow = hit or 0, overflow or 0
    f:NoteUnit(sourceUnitId, sourceName, sourceType)
    f:NoteUnit(targetUnitId, targetName, targetType)

    local selfTarget = Const.IsPlayerOrPet(targetType)
    f:RecordOutgoing(cat, result, abilityId, abilityName, graphic, slotType, targetUnitId, hit, overflow, damageType, powerType, now)
    if selfTarget and INCOMING_ALSO[cat] then
        f:RecordIncoming(cat, result, abilityId, abilityName, graphic, slotType, sourceUnitId, hit, overflow, damageType, powerType, now, true)
    end

    local s = Settings()
    if f.events then
        f.events:Push({ now, selfTarget and DIR.SELF or DIR.OUT, result, abilityId, hit, overflow, sourceUnitId, targetUnitId, damageType, powerType, slotType })
    end
    if cat == "damage" or cat == "heal" then
        LF.Procs.ObserveCombat(f, cat, result, abilityId, abilityName, slotType, hit, now)
        if cat == "damage" and s.modelsEnabled and not selfTarget then
            LF.Models.ObserveOutgoing(abilityId, result, hit, damageType, f:GetUnitName(targetUnitId), targetType, CRIT[result] or false, TICK[result] or false)
        end
    end
    FireCombat(f, selfTarget and DIR.SELF or DIR.OUT, cat, result, abilityId, hit, overflow, sourceUnitId, targetUnitId, damageType)
end

local function HandleIncoming(result, abilityName, graphic, slotType, sourceName, sourceType, targetName, targetType, hit, powerType, damageType, sourceUnitId, targetUnitId, abilityId, overflow)
    local cat = CATEGORY[result] or "other"
    local now = GetGameTimeMilliseconds()
    local f = state.fight
    if not f then
        if not STARTS_FIGHT_IN[cat] then return end
        if cat == "damage" and hit <= 0 then return end
        f = BeginFight(now)
    end
    hit, overflow = hit or 0, overflow or 0
    f:NoteUnit(sourceUnitId, sourceName, sourceType)
    f:NoteUnit(targetUnitId, targetName, targetType)
    f:RecordIncoming(cat, result, abilityId, abilityName, graphic, slotType, sourceUnitId, hit, overflow, damageType, powerType, now, false)

    if state.recap and (cat == "damage" or cat == "heal" or cat == "shield") then
        state.recap:Push({ now, result, abilityId, hit, overflow, sourceUnitId, damageType })
    end
    if f.events then
        f.events:Push({ now, DIR.IN, result, abilityId, hit, overflow, sourceUnitId, targetUnitId, damageType, powerType, slotType })
    end
    if cat == "damage" and Settings().modelsEnabled then
        LF.Models.ObserveIncoming(abilityId, result, hit, damageType, f:GetUnitName(sourceUnitId), CRIT[result] or false)
    end
    FireCombat(f, DIR.IN, cat, result, abilityId, hit, overflow, sourceUnitId, targetUnitId, damageType)
end

local function HandleGroup(result, abilityName, sourceName, sourceType, targetName, targetType, hit, sourceUnitId, targetUnitId, abilityId)
    local f = state.fight
    if not f then return end
    local cat = CATEGORY[result]
    if cat ~= "damage" and cat ~= "heal" then return end
    local now = GetGameTimeMilliseconds()
    f:NoteUnit(sourceUnitId, sourceName, sourceType)
    f:NoteUnit(targetUnitId, targetName, targetType)
    f:RecordGroup(cat, result, abilityId, abilityName, sourceUnitId, hit or 0, now)
    if f.events then
        f.events:Push({ now, DIR.GROUP, result, abilityId, hit or 0, 0, sourceUnitId, targetUnitId, 0, 0, 0 })
    end
end

-- Player-only mode: two filtered registrations (+ pet), no double counting.
local function OnCombatOut(_, result, isError, abilityName, graphic, slotType, sourceName, sourceType, targetName, targetType, hit, powerType, damageType, _, sourceUnitId, targetUnitId, abilityId, overflow)
    if isError then return end
    HandleOutgoing(result, abilityName, graphic, slotType, sourceName, sourceType, targetName, targetType, hit, powerType, damageType, sourceUnitId, targetUnitId, abilityId, overflow)
end

local function OnCombatIn(_, result, isError, abilityName, graphic, slotType, sourceName, sourceType, targetName, targetType, hit, powerType, damageType, _, sourceUnitId, targetUnitId, abilityId, overflow)
    if isError then return end
    if Const.IsPlayerOrPet(sourceType) then return end -- already handled as outgoing
    HandleIncoming(result, abilityName, graphic, slotType, sourceName, sourceType, targetName, targetType, hit, powerType, damageType, sourceUnitId, targetUnitId, abilityId, overflow)
end

-- Group mode: one unfiltered registration, routed by unit type.
local function OnCombatAll(_, result, isError, abilityName, graphic, slotType, sourceName, sourceType, targetName, targetType, hit, powerType, damageType, _, sourceUnitId, targetUnitId, abilityId, overflow)
    if isError then return end
    if Const.IsPlayerOrPet(sourceType) then
        HandleOutgoing(result, abilityName, graphic, slotType, sourceName, sourceType, targetName, targetType, hit, powerType, damageType, sourceUnitId, targetUnitId, abilityId, overflow)
    elseif targetType == Const.UT_PLAYER then
        HandleIncoming(result, abilityName, graphic, slotType, sourceName, sourceType, targetName, targetType, hit, powerType, damageType, sourceUnitId, targetUnitId, abilityId, overflow)
    elseif sourceType == Const.UT_GROUP or (Const.UT_COMPANION and sourceType == Const.UT_COMPANION) then
        HandleGroup(result, abilityName, sourceName, sourceType, targetName, targetType, hit, sourceUnitId, targetUnitId, abilityId)
    elseif targetType == Const.UT_GROUP and CATEGORY[result] == "shield" then
        -- an enemy hit a shield on another group member
        local f = state.fight
        if f and (hit or 0) > 0 then
            local now = GetGameTimeMilliseconds()
            f:NoteUnit(sourceUnitId, sourceName, sourceType)
            f:NoteUnit(targetUnitId, targetName, targetType)
            f:RecordGroupShield(targetUnitId, hit, now)
            if f.events then
                f.events:Push({ now, DIR.GROUP, result, abilityId, hit, 0, sourceUnitId, targetUnitId, damageType or 0, 0, 0 })
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Shield bar on you
-- ---------------------------------------------------------------------------
local function IsShieldVisual(visual)
    return Const.VISUAL_SHIELD ~= nil and visual == Const.VISUAL_SHIELD
end

local function OnShieldAdded(_, unitTag, visual, _, _, _, value)
    local f = state.fight
    if not f or not IsShieldVisual(visual) then return end
    f:RecordShieldValue("added", 0, value or 0, GetGameTimeMilliseconds())
end

local function OnShieldUpdated(_, unitTag, visual, _, _, _, oldValue, newValue)
    local f = state.fight
    if not f or not IsShieldVisual(visual) then return end
    f:RecordShieldValue("updated", oldValue or 0, newValue or 0, GetGameTimeMilliseconds())
end

local function OnShieldRemoved(_, unitTag, visual, _, _, _, value)
    local f = state.fight
    if not f or not IsShieldVisual(visual) then return end
    f:RecordShieldValue("removed", value or 0, 0, GetGameTimeMilliseconds())
end

-- ---------------------------------------------------------------------------
-- Effects
-- ---------------------------------------------------------------------------
local function HandleEffect(scope, changeType, effectName, unitTag, stackCount, iconName, effectType, unitName, unitId, abilityId, sourceType)
    local f = state.fight
    if not f then return end
    local now = GetGameTimeMilliseconds()
    if scope == "target" then
        -- the same unit can be reticleover AND bossN -> drop duplicates
        local key = tostring(unitId) .. ":" .. tostring(abilityId) .. ":" .. tostring(changeType)
        if state.lastEffect[key] == now then return end
        state.lastEffect[key] = now
        state.lastEffectCount = (state.lastEffectCount or 0) + 1
        if state.lastEffectCount > 512 then state.lastEffect, state.lastEffectCount = {}, 0 end
    end
    f:RecordEffect(scope, changeType, abilityId, effectName, unitId, unitName, stackCount, iconName, effectType, sourceType, now)
    LF.Procs.ObserveEffect(f, scope, changeType, abilityId, effectName, iconName, sourceType, now)
    if LF.listenerCount[LF.EVENTS.EFFECT_CHANGED] then
        LF.FireCallback(LF.EVENTS.EFFECT_CHANGED, f, scope, changeType, abilityId, effectName, unitId, stackCount)
    end
end

local function OnEffectPlayer(_, changeType, _, effectName, unitTag, _, _, stackCount, iconName, _, effectType, _, _, unitName, unitId, abilityId, sourceType)
    HandleEffect("player", changeType, effectName, unitTag, stackCount, iconName, effectType, unitName, unitId, abilityId, sourceType)
end

local function OnEffectTarget(_, changeType, _, effectName, unitTag, _, _, stackCount, iconName, _, effectType, _, _, unitName, unitId, abilityId, sourceType)
    HandleEffect("target", changeType, effectName, unitTag, stackCount, iconName, effectType, unitName, unitId, abilityId, sourceType)
end

-- ---------------------------------------------------------------------------
-- Power / health
-- ---------------------------------------------------------------------------
local function OnPowerPlayer(_, unitTag, _, powerType, value, maxValue, effectiveMax)
    local f = state.fight
    if not f then return end
    f:RecordPower(powerType, value, effectiveMax or maxValue, GetGameTimeMilliseconds())
end

local function OnPowerBoss(_, unitTag, _, powerType, value, maxValue, effectiveMax)
    local f = state.fight
    if not f or powerType ~= Const.POWER_HEALTH then return end
    local now = GetGameTimeMilliseconds()
    local name = Util.CleanName(GetUnitName(unitTag))
    local maxH = effectiveMax or maxValue
    f:RecordBossHealth(unitTag, name, value, maxH, now)
    if Settings().modelsEnabled then
        LF.Models.ObserveUnitHealth(unitTag, name, value, maxH, (now - f.startMs) / 1000)
    end
end

-- ---------------------------------------------------------------------------
-- Combat state / deaths / casts / bars / gear / zone
-- ---------------------------------------------------------------------------
local function OnCombatState(_, inCombat)
    if inCombat then
        local f = EnsureFight(GetGameTimeMilliseconds())
        f.lastCombatMs = GetGameTimeMilliseconds()
    end
    -- leaving combat is handled by Tick (grace period)
end

local function OnDeathState(_, unitTag, isDead)
    if not isDead then return end
    local f = state.fight
    if not f then return end
    local now = GetGameTimeMilliseconds()
    local recap = nil
    if unitTag == "player" and state.recap then
        recap = {}
        for _, r in ipairs(state.recap:ToArray()) do
            recap[#recap + 1] = {
                tMs = r[1] - f.startMs, result = r[2], resultName = Const.GetResultName(r[2]), abilityId = r[3],
                abilityName = LF.Abilities.GetName(r[3]), hit = r[4], overflow = r[5],
                source = f:GetUnitName(r[6]), damageType = r[7],
            }
        end
        state.recap:Clear()
    end
    local d = f:RecordDeath(unitTag, GetUnitName(unitTag), now, recap)
    LF.FireCallback(LF.EVENTS.DEATH, f, d)
end

local function OnSlotUsed(_, slotIndex)
    local f = state.fight
    if not f then return end
    local abilityId = Util.Try(GetSlotBoundId, slotIndex)
    local kind = f:RecordCast(slotIndex, abilityId, GetGameTimeMilliseconds())
    if LF.listenerCount[LF.EVENTS.CAST] then
        LF.FireCallback(LF.EVENTS.CAST, f, slotIndex, abilityId, kind)
    end
end

local function OnWeaponPair(_, activePair)
    local f = state.fight
    if not f then return end
    f:RecordBarSwap(activePair, GetGameTimeMilliseconds())
    LF.FireCallback(LF.EVENTS.BAR_SWAP, f, activePair)
end

local function OnGearChanged(_, bagId, slotIndex)
    local f = state.fight
    if f then f:RecordGearChange(slotIndex, GetGameTimeMilliseconds()) end
    LF.FireCallback(LF.EVENTS.GEAR_CHANGED, f, slotIndex)
end

local function OnPlayerActivated()
    if state.fight then EndFight("zone") end
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------
--[[
    Start_Logging(options)
    options (all optional, override saved settings for this session):
      rawEvents, rawEventCap, groupMode, trackTargetEffects, trackPower, trackCasts,
      statSampleMs, combatEndGraceMs, minFightSeconds, modelsEnabled, saveFights, buildDetail
    returns true on success, false + reason otherwise.
]]
function Logger.Start(options)
    if state.logging then return false, "already logging" end
    state.opts = type(options) == "table" and Util.ShallowCopy(options) or {}
    settingsView = nil
    settingsView = S()
    local s = Settings()

    if LF.sv and LF.sv.nextFightId then state.nextId = math.max(state.nextId, LF.sv.nextFightId) end
    state.recap = Util.NewRing(s.deathRecapSize or 20)
    state.lastEffect = {}

    -- combat events
    if s.groupMode then
        Register("CombatAll", EVENT_COMBAT_EVENT, OnCombatAll, REGISTER_FILTER_IS_ERROR, false)
    else
        Register("CombatOutPlayer", EVENT_COMBAT_EVENT, OnCombatOut, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, Const.UT_PLAYER, REGISTER_FILTER_IS_ERROR, false)
        if Const.UT_PET then
            Register("CombatOutPet", EVENT_COMBAT_EVENT, OnCombatOut, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, Const.UT_PET, REGISTER_FILTER_IS_ERROR, false)
        end
        Register("CombatIn", EVENT_COMBAT_EVENT, OnCombatIn, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, Const.UT_PLAYER, REGISTER_FILTER_IS_ERROR, false)
    end

    -- effects
    Register("EffectPlayer", EVENT_EFFECT_CHANGED, OnEffectPlayer, REGISTER_FILTER_UNIT_TAG, "player")
    if s.trackTargetEffects then
        Register("EffectBoss", EVENT_EFFECT_CHANGED, OnEffectTarget, REGISTER_FILTER_UNIT_TAG_PREFIX, "boss")
        Register("EffectReticle", EVENT_EFFECT_CHANGED, OnEffectTarget, REGISTER_FILTER_UNIT_TAG, "reticleover")
    end

    -- power
    if s.trackPower then
        Register("PowerPlayer", EVENT_POWER_UPDATE, OnPowerPlayer, REGISTER_FILTER_UNIT_TAG, "player")
    end
    if Const.POWER_HEALTH then
        Register("PowerBoss", EVENT_POWER_UPDATE, OnPowerBoss, REGISTER_FILTER_UNIT_TAG_PREFIX, "boss", REGISTER_FILTER_POWER_TYPE, Const.POWER_HEALTH)
    end

    -- state, deaths, casts, bars, gear, zone
    Register("CombatState", EVENT_PLAYER_COMBAT_STATE, OnCombatState)
    Register("DeathPlayer", EVENT_UNIT_DEATH_STATE_CHANGED, OnDeathState, REGISTER_FILTER_UNIT_TAG, "player")
    Register("DeathBoss", EVENT_UNIT_DEATH_STATE_CHANGED, OnDeathState, REGISTER_FILTER_UNIT_TAG_PREFIX, "boss")
    if s.groupMode then
        Register("DeathGroup", EVENT_UNIT_DEATH_STATE_CHANGED, OnDeathState, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
    end
    if s.trackCasts then
        Register("SlotUsed", EVENT_ACTION_SLOT_ABILITY_USED, OnSlotUsed)
    end
    Register("WeaponPair", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, OnWeaponPair)
    Register("Gear", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnGearChanged, REGISTER_FILTER_BAG_ID, BAG_WORN)
    Register("Activated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    -- shield bar on you
    if Const.VISUAL_SHIELD and EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED then
        Register("ShieldAdded", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, OnShieldAdded, REGISTER_FILTER_UNIT_TAG, "player")
        Register("ShieldUpdated", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, OnShieldUpdated, REGISTER_FILTER_UNIT_TAG, "player")
        Register("ShieldRemoved", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, OnShieldRemoved, REGISTER_FILTER_UNIT_TAG, "player")
    end

    state.logging = true
    if IsUnitInCombat("player") then BeginFight() end
    LF.Print("Logging started.")
    LF.FireCallback(LF.EVENTS.LOGGING_STARTED, state.opts)
    return true
end

function Logger.Stop()
    if not state.logging then return false, "not logging" end
    local f = EndFight("stopped")
    UnregisterAll()
    state.logging = false
    state.recap = nil
    state.opts = {}
    settingsView = nil
    LF.Print("Logging stopped.")
    LF.FireCallback(LF.EVENTS.LOGGING_STOPPED)
    return true, f
end

function Logger.IsLogging() return state.logging end
function Logger.GetCurrentFight() return state.fight end
function Logger.GetFights() return LF.fights end

function Logger.GetLastFight()
    return state.fight or LF.fights[#LF.fights]
end

function Logger.GetLastFinishedFight()
    return LF.fights[#LF.fights]
end

function Logger.GetFight(id)
    for i = #LF.fights, 1, -1 do
        if LF.fights[i].id == id then return LF.fights[i] end
    end
    if state.fight and state.fight.id == id then return state.fight end
    if LF.Storage then return LF.Storage.GetSavedFight(id) end
    return nil
end

-- Ends the current fight and immediately starts a new one (e.g. boss phases)
function Logger.SplitFight()
    if not state.logging then return false end
    EndFight("split")
    BeginFight()
    return true
end

function Logger.EndCurrentFight()
    if not state.fight then return false end
    return EndFight("manual") ~= nil
end

function Logger.ClearFights()
    LF.fights = {}
end

function Logger.GetRegisteredEvents()
    local out = {}
    for _, r in ipairs(state.registered) do out[#out + 1] = r.ns end
    return out
end

-- Global entry points (requested names) -------------------------------------
function Start_Logging(options) return Logger.Start(options) end
function Stop_Logging() return Logger.Stop() end
function Is_Logging() return Logger.IsLogging() end

LF.Start_Logging = Start_Logging
LF.Stop_Logging = Stop_Logging
LF.Is_Logging = Is_Logging
LF.StartLogging = Start_Logging
LF.StopLogging = Stop_Logging
LF.IsLogging = Is_Logging
LF.GetCurrentFight = Logger.GetCurrentFight
LF.GetLastFight = Logger.GetLastFight
LF.GetFights = Logger.GetFights
LF.GetFight = Logger.GetFight
LF.SplitFight = Logger.SplitFight
