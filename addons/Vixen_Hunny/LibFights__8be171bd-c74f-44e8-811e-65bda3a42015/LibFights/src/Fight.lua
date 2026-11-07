--[[
    LibFights - Fight object
    Holds every piece of data collected for one fight and computes metrics:
    DPS / DPM, HPS / HPM, damage-taken and healing-taken per second / minute,
    damage mitigated per second / minute, totals, crit rates, per ability, per target,
    per damage type, per second timeline, effect uptimes, procs, sets, casts, bar usage,
    resources, deaths and the optional raw event log.

    Fight objects are plain data + a metatable, so they can be saved to and restored
    from SavedVariables (Fight.FromData).
]]

local LF = LibFights
local Util, Const = LF.Util, LF.Const
local floor, max, min = math.floor, math.max, math.min

local Fight = {}
Fight.__index = Fight
LF.Fight = Fight

Fight.DIR = { OUT = 1, IN = 2, SELF = 3, GROUP = 4 }
Fight.DIR_NAME = { [1] = "out", [2] = "in", [3] = "self", [4] = "group" }

-- Raw event layout (compact arrays to keep memory and SavedVariables small)
LF.EVENT_FIELDS = {
    TIME = 1, DIR = 2, RESULT = 3, ABILITY = 4, HIT = 5, OVERFLOW = 6,
    SOURCE = 7, TARGET = 8, DAMAGE_TYPE = 9, POWER_TYPE = 10, SLOT_TYPE = 11,
}

local CRIT, TICK = Const.CRIT_RESULTS, Const.TICK_RESULTS
local R = Const.RESULT

local function S() return LF.GetSettings() end

local function NewTotals()
    return {
        -- outgoing damage
        damageOut = 0, damageOutNormal = 0, damageOutCrit = 0, damageOutDot = 0, damageOutDirect = 0,
        hitsOut = 0, critsOut = 0, ticksOut = 0, overkill = 0, damageOutShielded = 0, damageOutBlocked = 0,
        bossDamage = 0,
        -- outgoing healing
        healOut = 0, healOutNormal = 0, healOutCrit = 0, overheal = 0, healHitsOut = 0, healCritsOut = 0,
        healTicksOut = 0, selfHeal = 0,
        -- incoming
        damageIn = 0, hitsIn = 0, critsIn = 0, healIn = 0, overhealIn = 0, healHitsIn = 0,
        shieldAbsorbedIn = 0, shieldHitsIn = 0, blockedHitsIn = 0, blockedDamageIn = 0,
        -- shields on you (absorbed = exact from combat events; gained/peak from the shield bar)
        shieldGained = 0, shieldApplications = 0, shieldPeak = 0, shieldExpired = 0,
        -- group mode: damage absorbed by shields on other group members
        groupShieldAbsorbed = 0,
        -- mitigation (shield is exact, the rest are estimates)
        mitigatedShield = 0, mitigatedBlockEst = 0, mitigatedArmorEst = 0, mitigatedAvoidEst = 0,
        dodgesIn = 0, missesIn = 0, parriesIn = 0, immuneIn = 0, reflectsIn = 0, absorbsIn = 0, blockedFullIn = 0,
        -- misc
        avoidedOut = 0, interruptsOut = 0, interruptsIn = 0, ccOut = 0, ccIn = 0,
        killingBlows = 0, deaths = 0, powerGained = 0, powerDrained = 0,
    }
end

function Fight.New(id)
    local now = Util.Now()
    local f = setmetatable({}, Fight)
    f.id = id
    f.startMs = now
    f.endMs = nil
    f.lastEventMs = now
    f.lastCombatMs = now
    f.firstOutMs = nil
    f.lastOutMs = nil
    f.startTimestamp = GetTimeStamp()
    f.character = Util.Fmt(GetUnitName("player"))
    f.account = GetDisplayName()
    f.zoneName = Util.Fmt(GetUnitZone("player"))
    f.zoneId = Util.Try(GetZoneId, Util.Try(GetUnitZoneIndex, "player"))
    f.mapName = Util.Fmt(Util.Try(GetMapName) or "")
    f.totals = NewTotals()
    f.abilities = { damageOut = {}, healOut = {}, damageIn = {}, healIn = {}, shieldIn = {}, shieldOut = {} }
    f.targets = {}       -- unitId -> target aggregate
    f.sources = {}       -- unitId -> incoming source aggregate
    f.healTargets = {}   -- unitId -> healing
    f.healers = {}       -- unitId -> healing received
    f.units = {}         -- unitId -> { name, type }
    f.damageTypesOut = {}
    f.damageTypesIn = {}
    f.results = { out = {}, inc = {} }
    f.timeline = {}
    f.effects = { player = {}, target = {} }
    f.procs = {}
    f.sets = {}
    f.casts = { abilities = {}, server = {}, total = 0, light = 0, heavy = 0, skills = 0, ultimates = 0, other = 0, weaves = 0, skillGapSum = 0, skillGapCount = 0 }
    f.bars = { swaps = 0, frontMs = 0, backMs = 0 }
    f.power = {}
    f.deaths = {}
    f.cc = { out = {}, inc = {} }
    f.bosses = {}
    f.group = {}
    f.gearChanges = {}
    f.events = nil
    f.meta = { libVersion = LF.version, apiVersion = GetAPIVersion(), console = LF.isConsole }
    return f
end

-- Restores a fight from saved data
function Fight.FromData(data)
    if type(data) ~= "table" then return nil end
    setmetatable(data, Fight)
    if data.events and not getmetatable(data.events) then
        data.events = Util.RestoreRing(data.events)
    end
    return data
end

function Fight:ToData(includeEvents)
    local events = self.events
    if not includeEvents then self.events = nil end
    local data = Util.ToPlain(self)
    self.events = events
    if includeEvents and events and events.ToArray then
        data.events = events:ToArray()
    end
    return data
end

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------
function Fight:NoteUnit(unitId, name, unitType)
    if not unitId or unitId == 0 then return end
    local u = self.units[unitId]
    if not u then
        u = { name = Util.CleanName(name), type = unitType }
        self.units[unitId] = u
    elseif (u.name == "" or u.name == nil) and name and name ~= "" then
        u.name = Util.CleanName(name)
    end
    return u
end

function Fight:GetUnitName(unitId)
    local u = self.units[unitId]
    return u and u.name or ""
end

function Fight:_Agg(kind, abilityId, abilityName, graphic, slotType, damageType, powerType, now)
    local map = self.abilities[kind]
    local a = map[abilityId]
    if not a then
        local info = LF.Abilities.GetInfo(abilityId)
        local name = (abilityName and abilityName ~= "") and Util.CleanAbilityName(abilityName) or (info and info.name) or ("#" .. tostring(abilityId))
        a = {
            id = abilityId, name = name, icon = info and info.icon or "", graphic = graphic, slotType = slotType,
            damageType = damageType, powerType = powerType,
            total = 0, normalTotal = 0, critTotal = 0, hits = 0, crits = 0, ticks = 0, tickTotal = 0,
            directHits = 0, directTotal = 0, min = nil, max = 0, overflow = 0,
            firstMs = now, lastMs = now, results = {},
        }
        map[abilityId] = a
    end
    return a
end

local function AddAgg(a, value, isCrit, isTick, overflow, result, now)
    a.total = a.total + value
    a.hits = a.hits + 1
    if isCrit then
        a.crits = a.crits + 1
        a.critTotal = a.critTotal + value
    else
        a.normalTotal = a.normalTotal + value
    end
    if isTick then
        a.ticks = a.ticks + 1
        a.tickTotal = a.tickTotal + value
    else
        a.directHits = a.directHits + 1
        a.directTotal = a.directTotal + value
    end
    if value > a.max then a.max = value end
    if value > 0 and (a.min == nil or value < a.min) then a.min = value end
    a.overflow = a.overflow + (overflow or 0)
    a.results[result] = (a.results[result] or 0) + 1
    a.lastMs = now
end

function Fight:_Bucket(now)
    local sec = floor((now - self.startMs) / 1000) + 1
    if sec < 1 then sec = 1 end
    local b = self.timeline[sec]
    if not b then
        b = { dOut = 0, hOut = 0, dIn = 0, hIn = 0, mit = 0, oh = 0, sIn = 0, sGain = 0 }
        self.timeline[sec] = b
    end
    return b
end

function Fight:_Target(unitId, now)
    local t = self.targets[unitId]
    if not t then
        local u = self.units[unitId]
        local name = u and u.name or ""
        t = {
            unitId = unitId, name = name, unitType = u and u.type, damage = 0, hits = 0, crits = 0,
            firstMs = now, lastMs = now, killed = false, isBoss = self.bosses[name] and true or false, abilities = {},
        }
        self.targets[unitId] = t
    elseif t.name == "" then
        local u = self.units[unitId]
        if u and u.name ~= "" then
            t.name = u.name
            t.isBoss = self.bosses[u.name] and true or false
        end
    end
    return t
end

function Fight:_Source(unitId, now)
    local s = self.sources[unitId]
    if not s then
        local u = self.units[unitId]
        s = { unitId = unitId, name = u and u.name or "", unitType = u and u.type, damage = 0, hits = 0, crits = 0, firstMs = now, lastMs = now, abilities = {} }
        self.sources[unitId] = s
    end
    return s
end

function Fight:_PowerGain(powerType, abilityId, amount)
    local p = self.power[powerType]
    if not p then p = self:_Power(powerType) end
    p.gained = p.gained + amount
    p.gainedBy[abilityId] = (p.gainedBy[abilityId] or 0) + amount
end

function Fight:_Power(powerType)
    local p = { powerType = powerType, name = Const.GetPowerName(powerType), gained = 0, spent = 0, gainedBy = {}, min = nil, max = nil, sum = 0, n = 0, samples = {}, lastSampleMs = 0, last = nil, maxValue = 0, timeAtZeroMs = 0 }
    self.power[powerType] = p
    return p
end

function Fight:MarkBoss(name)
    if name and name ~= "" then self.bosses[name] = true end
    for _, t in pairs(self.targets) do
        if t.name == name then t.isBoss = true end
    end
end

-- ---------------------------------------------------------------------------
-- Recording (called by the logger)
-- ---------------------------------------------------------------------------
function Fight:RecordOutgoing(cat, result, abilityId, abilityName, graphic, slotType, targetUnitId, hit, overflow, damageType, powerType, now)
    local T = self.totals
    self.lastEventMs = now
    local ro = self.results.out
    ro[result] = (ro[result] or 0) + 1

    if cat == "damage" then
        local isCrit, isTick = CRIT[result] or false, TICK[result] or false
        T.damageOut = T.damageOut + hit
        T.hitsOut = T.hitsOut + 1
        if isCrit then T.critsOut = T.critsOut + 1; T.damageOutCrit = T.damageOutCrit + hit
        else T.damageOutNormal = T.damageOutNormal + hit end
        if isTick then T.ticksOut = T.ticksOut + 1; T.damageOutDot = T.damageOutDot + hit
        else T.damageOutDirect = T.damageOutDirect + hit end
        if result == R.BLOCKED_DAMAGE then T.damageOutBlocked = T.damageOutBlocked + hit end
        T.overkill = T.overkill + (overflow or 0)
        local a = self:_Agg("damageOut", abilityId, abilityName, graphic, slotType, damageType, powerType, now)
        AddAgg(a, hit, isCrit, isTick, overflow, result, now)
        local tgt = self:_Target(targetUnitId, now)
        tgt.damage = tgt.damage + hit
        tgt.hits = tgt.hits + 1
        if isCrit then tgt.crits = tgt.crits + 1 end
        tgt.lastMs = now
        tgt.abilities[abilityId] = (tgt.abilities[abilityId] or 0) + hit
        if tgt.isBoss then T.bossDamage = T.bossDamage + hit end
        self.damageTypesOut[damageType] = (self.damageTypesOut[damageType] or 0) + hit
        local b = self:_Bucket(now)
        b.dOut = b.dOut + hit
        if not self.firstOutMs then self.firstOutMs = now end
        self.lastOutMs = now
        self.lastCombatMs = now
    elseif cat == "heal" then
        local isCrit, isTick = CRIT[result] or false, TICK[result] or false
        T.healOut = T.healOut + hit
        T.overheal = T.overheal + (overflow or 0)
        T.healHitsOut = T.healHitsOut + 1
        if isCrit then T.healCritsOut = T.healCritsOut + 1; T.healOutCrit = T.healOutCrit + hit
        else T.healOutNormal = T.healOutNormal + hit end
        if isTick then T.healTicksOut = T.healTicksOut + 1 end
        local a = self:_Agg("healOut", abilityId, abilityName, graphic, slotType, damageType, powerType, now)
        AddAgg(a, hit, isCrit, isTick, overflow, result, now)
        self.healTargets[targetUnitId] = (self.healTargets[targetUnitId] or 0) + hit
        local b = self:_Bucket(now)
        b.hOut = b.hOut + hit
        b.oh = b.oh + (overflow or 0)
        if not self.firstOutMs then self.firstOutMs = now end
        self.lastOutMs = now
        if hit > 0 then self.lastCombatMs = now end
    elseif cat == "shield" then
        T.damageOutShielded = T.damageOutShielded + hit
        local a = self:_Agg("shieldOut", abilityId, abilityName, graphic, slotType, damageType, powerType, now)
        AddAgg(a, hit, false, false, 0, result, now)
        self.lastCombatMs = now
    elseif cat == "avoid" then
        T.avoidedOut = T.avoidedOut + 1
    elseif cat == "cc" then
        T.ccOut = T.ccOut + 1
        if result == R.INTERRUPT then T.interruptsOut = T.interruptsOut + 1 end
        self.cc.out[result] = (self.cc.out[result] or 0) + 1
    elseif cat == "death" then
        if result == R.KILLING_BLOW then
            T.killingBlows = T.killingBlows + 1
            local tgt = self.targets[targetUnitId]
            if tgt then tgt.killed = true; tgt.killedMs = now end
        end
    elseif cat == "power" then
        if result == R.POWER_ENERGIZE then
            T.powerGained = T.powerGained + hit
            self:_PowerGain(powerType, abilityId, hit)
        else
            T.powerDrained = T.powerDrained + hit
        end
    elseif cat == "cast" then
        self.casts.server[abilityId] = (self.casts.server[abilityId] or 0) + 1
    end
end

function Fight:RecordIncoming(cat, result, abilityId, abilityName, graphic, slotType, sourceUnitId, hit, overflow, damageType, powerType, now, isSelf)
    local T = self.totals
    self.lastEventMs = now
    local ri = self.results.inc
    ri[result] = (ri[result] or 0) + 1

    if cat == "damage" then
        local isCrit = CRIT[result] or false
        T.damageIn = T.damageIn + hit
        T.hitsIn = T.hitsIn + 1
        if isCrit then T.critsIn = T.critsIn + 1 end
        local a = self:_Agg("damageIn", abilityId, abilityName, graphic, slotType, damageType, powerType, now)
        AddAgg(a, hit, isCrit, TICK[result] or false, overflow, result, now)
        if not isSelf then
            local src = self:_Source(sourceUnitId, now)
            src.damage = src.damage + hit
            src.hits = src.hits + 1
            if isCrit then src.crits = src.crits + 1 end
            src.lastMs = now
            src.abilities[abilityId] = (src.abilities[abilityId] or 0) + hit
        end
        self.damageTypesIn[damageType] = (self.damageTypesIn[damageType] or 0) + hit
        local b = self:_Bucket(now)
        b.dIn = b.dIn + hit
        -- estimated armor mitigation
        local m = LF.Stats.GetArmorMitigation(damageType)
        if m > 0 and m < 1 then
            local mit = hit * m / (1 - m)
            T.mitigatedArmorEst = T.mitigatedArmorEst + mit
            b.mit = b.mit + mit
        end
        if result == R.BLOCKED_DAMAGE then
            T.blockedHitsIn = T.blockedHitsIn + 1
            T.blockedDamageIn = T.blockedDamageIn + hit
            local bm = Util.Clamp(S().blockMitigation or 0.5, 0, 0.95)
            local mit = hit * bm / (1 - bm)
            T.mitigatedBlockEst = T.mitigatedBlockEst + mit
            b.mit = b.mit + mit
        end
        self.lastCombatMs = now
    elseif cat == "heal" then
        local isCrit = CRIT[result] or false
        T.healIn = T.healIn + hit
        T.overhealIn = T.overhealIn + (overflow or 0)
        T.healHitsIn = T.healHitsIn + 1
        if isSelf then T.selfHeal = T.selfHeal + hit end
        local a = self:_Agg("healIn", abilityId, abilityName, graphic, slotType, damageType, powerType, now)
        AddAgg(a, hit, isCrit, TICK[result] or false, overflow, result, now)
        self.healers[sourceUnitId] = (self.healers[sourceUnitId] or 0) + hit
        local b = self:_Bucket(now)
        b.hIn = b.hIn + hit
    elseif cat == "shield" then
        T.shieldAbsorbedIn = T.shieldAbsorbedIn + hit
        T.shieldHitsIn = (T.shieldHitsIn or 0) + 1
        T.mitigatedShield = T.mitigatedShield + hit
        local a = self:_Agg("shieldIn", abilityId, abilityName, graphic, slotType, damageType, powerType, now)
        AddAgg(a, hit, false, false, 0, result, now)
        local b = self:_Bucket(now)
        b.mit = b.mit + hit
        b.sIn = (b.sIn or 0) + hit
        self.lastCombatMs = now
    elseif cat == "avoid" then
        if result == R.DODGED then T.dodgesIn = T.dodgesIn + 1
        elseif result == R.MISS then T.missesIn = T.missesIn + 1
        elseif result == R.PARRIED then T.parriesIn = T.parriesIn + 1
        elseif result == R.IMMUNE then T.immuneIn = T.immuneIn + 1
        elseif result == R.REFLECTED then T.reflectsIn = T.reflectsIn + 1
        elseif result == R.ABSORBED then T.absorbsIn = T.absorbsIn + 1
        elseif result == R.BLOCKED then T.blockedFullIn = T.blockedFullIn + 1 end
        -- estimate: average hit of the same enemy ability seen so far
        local a = self.abilities.damageIn[abilityId]
        local est = (a and a.hits > 0) and (a.total / a.hits) or 0
        if est > 0 then
            T.mitigatedAvoidEst = T.mitigatedAvoidEst + est
            local b = self:_Bucket(now)
            b.mit = b.mit + est
        end
        self.lastCombatMs = now
    elseif cat == "cc" then
        T.ccIn = T.ccIn + 1
        if result == R.INTERRUPT then T.interruptsIn = T.interruptsIn + 1 end
        self.cc.inc[result] = (self.cc.inc[result] or 0) + 1
    elseif cat == "power" then
        if result == R.POWER_ENERGIZE and not isSelf then
            T.powerGained = T.powerGained + hit
            self:_PowerGain(powerType, abilityId, hit)
        end
    end
end

-- group-mode outgoing damage / healing of other group members
function Fight:_GroupMember(unitId)
    local g = self.group[unitId]
    if not g then
        g = { unitId = unitId, name = self:GetUnitName(unitId), damage = 0, healing = 0, hits = 0, crits = 0, shieldAbsorbed = 0, abilities = {} }
        self.group[unitId] = g
    end
    if g.shieldAbsorbed == nil then g.shieldAbsorbed = 0 end
    return g
end

function Fight:RecordGroup(cat, result, abilityId, abilityName, sourceUnitId, hit, now)
    if cat ~= "damage" and cat ~= "heal" then return end
    local g = self:_GroupMember(sourceUnitId)
    if cat == "damage" then g.damage = g.damage + hit else g.healing = g.healing + hit end
    g.hits = g.hits + 1
    if CRIT[result] then g.crits = g.crits + 1 end
    local a = g.abilities[abilityId]
    if not a then a = { id = abilityId, name = abilityName, total = 0, hits = 0 }; g.abilities[abilityId] = a end
    a.total = a.total + hit
    a.hits = a.hits + 1
    self.lastEventMs = now
end

-- group mode: damage absorbed by a shield on another group member (the shield's caster is unknown)
function Fight:RecordGroupShield(targetUnitId, hit, now)
    local T = self.totals
    T.groupShieldAbsorbed = (T.groupShieldAbsorbed or 0) + hit
    local g = self:_GroupMember(targetUnitId)
    g.shieldAbsorbed = g.shieldAbsorbed + hit
    self.lastEventMs = now
end

-- Shield bar on you (ATTRIBUTE_VISUAL_POWER_SHIELDING).
-- kind: "added" | "updated" | "removed"; oldValue/newValue are the shield amounts before/after.
function Fight:RecordShieldValue(kind, oldValue, newValue, now)
    local T = self.totals
    oldValue, newValue = oldValue or 0, newValue or 0
    if kind == "added" then
        T.shieldApplications = (T.shieldApplications or 0) + 1
    end
    local gained = newValue - oldValue
    if kind ~= "removed" and gained > 0 then
        T.shieldGained = (T.shieldGained or 0) + gained
        local b = self:_Bucket(now)
        b.sGain = (b.sGain or 0) + gained
    end
    if kind == "removed" and oldValue > 0 then
        -- whatever was left when the shield bar disappeared ran out unused
        T.shieldExpired = (T.shieldExpired or 0) + oldValue
    end
    if newValue > (T.shieldPeak or 0) then T.shieldPeak = newValue end
    self.lastEventMs = now
end

-- scope: "player" or "target"
function Fight:RecordEffect(scope, changeType, abilityId, effectName, unitId, unitName, stackCount, iconName, effectType, sourceType, now)
    local list = self.effects[scope]
    local key = (scope == "player") and abilityId or (tostring(abilityId) .. ":" .. tostring(unitId))
    local e = list[key]
    if not e then
        e = {
            id = abilityId, name = Util.CleanAbilityName(effectName), icon = iconName or "", effectType = effectType,
            unitId = unitId, unitName = Util.CleanName(unitName), castByPlayer = Const.IsPlayerOrPet(sourceType),
            gains = 0, fades = 0, refreshes = 0, uptimeMs = 0, maxStacks = 0, stacks = 0, activeSince = nil,
        }
        list[key] = e
    end
    if Const.IsPlayerOrPet(sourceType) then e.castByPlayer = true end
    if changeType == Const.EFFECT_GAINED then
        e.gains = e.gains + 1
        if not e.activeSince then e.activeSince = now end
    elseif changeType == Const.EFFECT_UPDATED or changeType == Const.EFFECT_FULL_REFRESH then
        e.refreshes = e.refreshes + 1
        if not e.activeSince then e.activeSince = now end
    elseif changeType == Const.EFFECT_FADED then
        e.fades = e.fades + 1
        if e.activeSince then
            e.uptimeMs = e.uptimeMs + (now - e.activeSince)
            e.activeSince = nil
        end
    end
    e.stacks = stackCount or 0
    if e.stacks > e.maxStacks then e.maxStacks = e.stacks end
    self.lastEventMs = now
    return e
end

local POWER_SAMPLE_MS = 250
local MAX_POWER_SAMPLES = 1200

function Fight:RecordPower(powerType, value, maxValue, now)
    local p = self.power[powerType] or self:_Power(powerType)
    if p.last and value < p.last then p.spent = p.spent + (p.last - value) end
    if p.last == 0 and p.lastZeroMs then p.timeAtZeroMs = p.timeAtZeroMs + (now - p.lastZeroMs) end
    p.lastZeroMs = (value == 0) and now or nil
    p.last = value
    if p.min == nil or value < p.min then p.min = value end
    if p.max == nil or value > p.max then p.max = value end
    if maxValue and maxValue > p.maxValue then p.maxValue = maxValue end
    p.sum = p.sum + value
    p.n = p.n + 1
    if now - p.lastSampleMs >= POWER_SAMPLE_MS and #p.samples < MAX_POWER_SAMPLES then
        p.samples[#p.samples + 1] = { now - self.startMs, value, maxValue }
        p.lastSampleMs = now
    end
end

function Fight:RecordBossHealth(unitTag, name, current, maxHealth, now)
    local b = self.bossHealth and self.bossHealth[unitTag]
    self.bossHealth = self.bossHealth or {}
    if not b then
        b = { unitTag = unitTag, name = name, maxHealth = maxHealth, startHealth = current, samples = {}, lastSampleMs = 0 }
        self.bossHealth[unitTag] = b
    end
    b.current = current
    b.maxHealth = maxHealth
    if now - b.lastSampleMs >= 1000 and #b.samples < 1800 then
        b.samples[#b.samples + 1] = { now - self.startMs, current }
        b.lastSampleMs = now
    end
end

local LIGHT, HEAVY = Const.LIGHT_ATTACK_SLOT, Const.HEAVY_ATTACK_SLOT
local FIRST_SKILL, ULT = Const.FIRST_SKILL_SLOT, Const.ULTIMATE_SLOT

function Fight:RecordCast(slotIndex, abilityId, now)
    local c = self.casts
    local kind
    if slotIndex == LIGHT then kind = "light"
    elseif slotIndex == HEAVY then kind = "heavy"
    elseif slotIndex == ULT then kind = "ultimate"
    elseif slotIndex >= FIRST_SKILL and slotIndex < ULT then kind = "skill"
    else kind = "other" end

    c.total = c.total + 1
    if kind == "light" then c.light = c.light + 1; c.lastLightMs = now
    elseif kind == "heavy" then c.heavy = c.heavy + 1
    elseif kind == "ultimate" then c.ultimates = c.ultimates + 1
    elseif kind == "skill" then c.skills = c.skills + 1
    else c.other = c.other + 1 end

    if kind == "skill" or kind == "ultimate" then
        if c.lastLightMs and now - c.lastLightMs <= 1200 then
            c.weaves = c.weaves + 1
            c.lastLightMs = nil
        end
        if c.lastSkillMs then
            local gap = now - c.lastSkillMs
            if gap < 3000 then
                c.skillGapSum = c.skillGapSum + gap
                c.skillGapCount = c.skillGapCount + 1
            end
        end
        c.lastSkillMs = now
    end

    if abilityId and abilityId ~= 0 then
        local a = c.abilities[abilityId]
        if not a then
            local info = LF.Abilities.GetInfo(abilityId)
            a = { id = abilityId, name = info and info.name or "", icon = info and info.icon or "", kind = kind, count = 0, firstMs = now, lastMs = now }
            c.abilities[abilityId] = a
        end
        a.count = a.count + 1
        a.lastMs = now
    end
    return kind
end

function Fight:RecordBarSwap(activePair, now)
    local b = self.bars
    if b.current and b.since then
        local dt = now - b.since
        if b.current == Const.WEAPON_PAIR_BACKUP then b.backMs = b.backMs + dt else b.frontMs = b.frontMs + dt end
        if b.current ~= activePair then b.swaps = b.swaps + 1 end
    end
    b.current = activePair
    b.since = now
end

function Fight:RecordDeath(unitTag, unitName, now, recap)
    local d = { unitTag = unitTag, name = Util.CleanName(unitName), tMs = now - self.startMs, recap = recap }
    self.deaths[#self.deaths + 1] = d
    if unitTag == "player" then self.totals.deaths = self.totals.deaths + 1 end
    return d
end

function Fight:RecordGearChange(slotIndex, now)
    self.gearChanges[#self.gearChanges + 1] = { slot = slotIndex, slotName = Const.EQUIP_SLOT_NAME[slotIndex], tMs = now - self.startMs, link = GetItemLink(BAG_WORN, slotIndex) }
end

function Fight:PushEvent(ev)
    if self.events then self.events:Push(ev) end
end

-- ---------------------------------------------------------------------------
-- Finalisation
-- ---------------------------------------------------------------------------
function Fight:CloseOpenIntervals(now)
    for _, scope in pairs(self.effects) do
        for _, e in pairs(scope) do
            if e.activeSince then
                e.uptimeMs = e.uptimeMs + (now - e.activeSince)
                e.activeSince = nil
                e.activeAtEnd = true
            end
        end
    end
    local b = self.bars
    if b.current and b.since then
        local dt = now - b.since
        if b.current == Const.WEAPON_PAIR_BACKUP then b.backMs = b.backMs + dt else b.frontMs = b.frontMs + dt end
        b.since = nil
    end
end

function Fight:Finish(endMs)
    self.endMs = endMs or Util.Now()
    self:CloseOpenIntervals(self.endMs)
    self.summary = self:GetSummary()
end

function Fight:IsActive()
    return self.endMs == nil
end

-- ---------------------------------------------------------------------------
-- Metrics
-- ---------------------------------------------------------------------------
function Fight:GetDurationMs()
    local endMs = self.endMs or Util.Now()
    return max(1, endMs - self.startMs)
end

function Fight:GetDurationSec()
    return max(1, self:GetDurationMs() / 1000)
end

-- From your first to your last outgoing hit/heal
function Fight:GetActiveSec()
    if not self.firstOutMs then return self:GetDurationSec() end
    return max(1, ((self.lastOutMs or self.firstOutMs) - self.firstOutMs) / 1000)
end

local function Secs(self, useActive)
    return useActive and self:GetActiveSec() or self:GetDurationSec()
end

function Fight:GetTotalMitigated()
    local T = self.totals
    return T.mitigatedShield + T.mitigatedBlockEst + T.mitigatedArmorEst + T.mitigatedAvoidEst
end

function Fight:GetDPS(useActive) return self.totals.damageOut / Secs(self, useActive) end
function Fight:GetDPM(useActive) return self:GetDPS(useActive) * 60 end
function Fight:GetBossDPS(useActive) return self.totals.bossDamage / Secs(self, useActive) end
function Fight:GetHPS(useActive) return self.totals.healOut / Secs(self, useActive) end
function Fight:GetHPM(useActive) return self:GetHPS(useActive) * 60 end
function Fight:GetRawHPS(useActive) return (self.totals.healOut + self.totals.overheal) / Secs(self, useActive) end
function Fight:GetDTPS() return self.totals.damageIn / self:GetDurationSec() end
function Fight:GetDTPM() return self:GetDTPS() * 60 end
function Fight:GetHTPS() return self.totals.healIn / self:GetDurationSec() end
function Fight:GetHTPM() return self:GetHTPS() * 60 end
function Fight:GetMPS() return self:GetTotalMitigated() / self:GetDurationSec() end
function Fight:GetMPM() return self:GetMPS() * 60 end

-- Shields: damage absorbed by shields on you (exact)
function Fight:GetTotalShield() return self.totals.shieldAbsorbedIn or 0 end
function Fight:GetSPS() return self:GetTotalShield() / self:GetDurationSec() end
function Fight:GetSPM() return self:GetSPS() * 60 end
-- Shields applied to you (from the shield bar), including any that ran out unused
function Fight:GetTotalShieldGained() return self.totals.shieldGained or 0 end
function Fight:GetShieldGainedPS() return self:GetTotalShieldGained() / self:GetDurationSec() end
function Fight:GetShieldGainedPM() return self:GetShieldGainedPS() * 60 end
-- Group mode: damage absorbed by shields on other group members
function Fight:GetGroupShieldTotal() return self.totals.groupShieldAbsorbed or 0 end
function Fight:GetGroupSPS() return self:GetGroupShieldTotal() / self:GetDurationSec() end
function Fight:GetGroupSPM() return self:GetGroupSPS() * 60 end

function Fight:GetTitle()
    for name in pairs(self.bosses) do return name end
    local best, bestDmg = nil, -1
    for _, t in pairs(self.targets) do
        if t.damage > bestDmg then best, bestDmg = t.name, t.damage end
    end
    if best and best ~= "" then return best end
    return self.zoneName ~= "" and self.zoneName or ("Fight " .. tostring(self.id))
end

function Fight:GetMaxHit(kind)
    local best
    for _, a in pairs(self.abilities[kind or "damageOut"]) do
        if not best or a.max > best.max then best = a end
    end
    return best and best.max or 0, best
end

function Fight:GetSummary()
    local T = self.totals
    local dur, active = self:GetDurationSec(), self:GetActiveSec()
    local maxHit, maxHitAgg = self:GetMaxHit("damageOut")
    local maxHeal, maxHealAgg = self:GetMaxHit("healOut")
    local c = self.casts
    local castMinutes = max(1 / 60, active / 60)
    local barTotal = max(1, self.bars.frontMs + self.bars.backMs)
    local procActivations = 0
    for _, p in pairs(self.procs) do procActivations = procActivations + (p.activations or 0) end
    local mitigated = self:GetTotalMitigated()
    return {
        id = self.id, title = self:GetTitle(), zone = self.zoneName, zoneId = self.zoneId, character = self.character,
        startTimestamp = self.startTimestamp, durationMs = self:GetDurationMs(), durationSec = dur, activeSec = active,
        isActive = self:IsActive(),

        damage = T.damageOut, dps = T.damageOut / dur, dpm = T.damageOut / dur * 60, activeDPS = T.damageOut / active,
        bossDamage = T.bossDamage, bossDPS = T.bossDamage / dur, damageShielded = T.damageOutShielded,
        damageIncludingShields = T.damageOut + T.damageOutShielded,
        dotDamage = T.damageOutDot, directDamage = T.damageOutDirect, dotShare = Util.SafeDiv(T.damageOutDot, T.damageOut),
        overkill = T.overkill,

        healing = T.healOut, hps = T.healOut / dur, hpm = T.healOut / dur * 60, rawHealing = T.healOut + T.overheal,
        rawHPS = (T.healOut + T.overheal) / dur, overheal = T.overheal, overhealPct = Util.SafeDiv(T.overheal, T.healOut + T.overheal),
        selfHealing = T.selfHeal,

        damageTaken = T.damageIn, dtps = T.damageIn / dur, dtpm = T.damageIn / dur * 60,
        healingTaken = T.healIn, htps = T.healIn / dur, htpm = T.healIn / dur * 60,

        mitigated = mitigated, mps = mitigated / dur, mpm = mitigated / dur * 60,
        mitigatedShield = T.mitigatedShield, mitigatedBlockEst = T.mitigatedBlockEst,
        mitigatedArmorEst = T.mitigatedArmorEst, mitigatedAvoidEst = T.mitigatedAvoidEst,
        mitigationPct = Util.SafeDiv(mitigated, mitigated + T.damageIn),

        shield = T.shieldAbsorbedIn or 0, sps = (T.shieldAbsorbedIn or 0) / dur, spm = (T.shieldAbsorbedIn or 0) / dur * 60,
        shieldHits = T.shieldHitsIn or 0,
        shieldPctOfIncoming = Util.SafeDiv(T.shieldAbsorbedIn or 0, (T.shieldAbsorbedIn or 0) + T.damageIn),
        shieldGained = T.shieldGained or 0, shieldGainedPS = (T.shieldGained or 0) / dur,
        shieldGainedPM = (T.shieldGained or 0) / dur * 60, shieldApplications = T.shieldApplications or 0,
        shieldPeak = T.shieldPeak or 0, shieldExpired = T.shieldExpired or 0,
        shieldEfficiency = Util.SafeDiv(T.shieldAbsorbedIn or 0, T.shieldGained or 0),
        groupShield = T.groupShieldAbsorbed or 0, groupSPS = (T.groupShieldAbsorbed or 0) / dur,
        groupSPM = (T.groupShieldAbsorbed or 0) / dur * 60,

        hits = T.hitsOut, crits = T.critsOut, critRate = Util.SafeDiv(T.critsOut, T.hitsOut),
        ticks = T.ticksOut, avgHit = Util.SafeDiv(T.damageOut, T.hitsOut),
        maxHit = maxHit, maxHitAbilityId = maxHitAgg and maxHitAgg.id, maxHitAbility = maxHitAgg and maxHitAgg.name,
        healCritRate = Util.SafeDiv(T.healCritsOut, T.healHitsOut), maxHeal = maxHeal,
        maxHealAbility = maxHealAgg and maxHealAgg.name,
        incomingHits = T.hitsIn, incomingCritRate = Util.SafeDiv(T.critsIn, T.hitsIn),
        blockedHits = T.blockedHitsIn, dodges = T.dodgesIn, misses = T.missesIn, immune = T.immuneIn,

        casts = c.total, skillCasts = c.skills, lightAttacks = c.light, heavyAttacks = c.heavy, ultimates = c.ultimates,
        apm = c.total / castMinutes, skillsPerMinute = (c.skills + c.ultimates) / castMinutes, weaves = c.weaves,
        weaveRatio = Util.SafeDiv(c.weaves, c.skills + c.ultimates),
        avgSkillGapMs = Util.SafeDiv(c.skillGapSum, c.skillGapCount),
        barSwaps = self.bars.swaps, frontBarPct = self.bars.frontMs / barTotal, backBarPct = self.bars.backMs / barTotal,

        killingBlows = T.killingBlows, deaths = T.deaths, interruptsOut = T.interruptsOut, interruptsIn = T.interruptsIn,
        ccOut = T.ccOut, ccIn = T.ccIn, powerGained = T.powerGained,
        procActivations = procActivations,
        numTargets = Util.Count(self.targets), numAbilities = Util.Count(self.abilities.damageOut) + Util.Count(self.abilities.healOut),
    }
end

-- kind: damageOut | healOut | damageIn | healIn | shieldIn | shieldOut
-- sortBy: total (default) | hits | max | crits | dps
function Fight:GetAbilityBreakdown(kind, sortBy, limit)
    kind = kind or "damageOut"
    local map = self.abilities[kind] or {}
    local sum = 0
    for _, a in pairs(map) do sum = sum + a.total end
    local dur = self:GetDurationSec()
    local rows = {}
    for _, a in pairs(map) do
        rows[#rows + 1] = {
            id = a.id, name = a.name, icon = a.icon, graphic = a.graphic, damageType = a.damageType,
            total = a.total, pct = Util.SafeDiv(a.total, sum), dps = a.total / dur, dpm = a.total / dur * 60,
            hits = a.hits, crits = a.crits, critRate = Util.SafeDiv(a.crits, a.hits),
            avg = Util.SafeDiv(a.total, a.hits), avgNormal = Util.SafeDiv(a.normalTotal, a.hits - a.crits),
            avgCrit = Util.SafeDiv(a.critTotal, a.crits), min = a.min or 0, max = a.max,
            ticks = a.ticks, tickTotal = a.tickTotal, directHits = a.directHits, directTotal = a.directTotal,
            overflow = a.overflow, results = a.results,
        }
    end
    local key = sortBy or "total"
    table.sort(rows, function(x, y) return (x[key] or 0) > (y[key] or 0) end)
    if limit then for i = #rows, limit + 1, -1 do rows[i] = nil end end
    return rows
end

function Fight:GetTargets(limit)
    local rows = {}
    local dur = self:GetDurationSec()
    for _, t in pairs(self.targets) do
        rows[#rows + 1] = {
            unitId = t.unitId, name = t.name, damage = t.damage, hits = t.hits, crits = t.crits, isBoss = t.isBoss,
            killed = t.killed, dps = t.damage / dur, critRate = Util.SafeDiv(t.crits, t.hits),
            activeSec = max(1, (t.lastMs - t.firstMs) / 1000), pct = Util.SafeDiv(t.damage, self.totals.damageOut),
            abilities = t.abilities,
        }
    end
    table.sort(rows, function(a, b) return a.damage > b.damage end)
    if limit then for i = #rows, limit + 1, -1 do rows[i] = nil end end
    return rows
end

function Fight:GetSources(limit)
    local rows = {}
    for _, s in pairs(self.sources) do
        rows[#rows + 1] = { unitId = s.unitId, name = s.name, damage = s.damage, hits = s.hits, crits = s.crits, pct = Util.SafeDiv(s.damage, self.totals.damageIn), abilities = s.abilities }
    end
    table.sort(rows, function(a, b) return a.damage > b.damage end)
    if limit then for i = #rows, limit + 1, -1 do rows[i] = nil end end
    return rows
end

function Fight:GetDamageTypes(incoming)
    local map = incoming and self.damageTypesIn or self.damageTypesOut
    local total = incoming and self.totals.damageIn or self.totals.damageOut
    local rows = {}
    for dt, v in pairs(map) do
        rows[#rows + 1] = { damageType = dt, name = Const.GetDamageTypeName(dt), total = v, pct = Util.SafeDiv(v, total) }
    end
    table.sort(rows, function(a, b) return a.total > b.total end)
    return rows
end

-- field: dOut | hOut | dIn | hIn | mit | oh | sIn (shield absorbed on you) | sGain (shield applied to you)
-- returns dense array, one value per second
function Fight:GetTimeline(field)
    field = field or "dOut"
    local n = floor(self:GetDurationMs() / 1000) + 1
    local out = {}
    for i = 1, n do
        local b = self.timeline[i]
        out[i] = b and b[field] or 0
    end
    return out
end

-- rolling per-second rate over a window (e.g. 5s rolling DPS)
function Fight:GetRollingRate(field, windowSec)
    local tl = self:GetTimeline(field)
    windowSec = windowSec or 5
    local out, acc = {}, 0
    for i = 1, #tl do
        acc = acc + tl[i]
        if i > windowSec then acc = acc - tl[i - windowSec] end
        out[i] = acc / min(i, windowSec)
    end
    return out
end

function Fight:GetEffectUptimes(scope, onlyMine)
    scope = scope or "player"
    local durMs = self:GetDurationMs()
    local now = self.endMs or Util.Now()
    local byAbility = {}
    for _, e in pairs(self.effects[scope] or {}) do
        if not onlyMine or e.castByPlayer then
            local up = e.uptimeMs + (e.activeSince and (now - e.activeSince) or 0)
            local cur = byAbility[e.id]
            -- for target effects keep the unit with the best uptime (usually the boss)
            if not cur or up > cur.uptimeMs then
                byAbility[e.id] = {
                    id = e.id, name = e.name, icon = e.icon, effectType = e.effectType, castByPlayer = e.castByPlayer,
                    uptimeMs = up, uptimePct = Util.Clamp(up / durMs, 0, 1), gains = e.gains, refreshes = e.refreshes,
                    fades = e.fades, maxStacks = e.maxStacks, unitName = e.unitName,
                }
            end
        end
    end
    return Util.SortedValues(byAbility, "uptimeMs", true)
end

function Fight:GetProcs()
    return Util.SortedValues(self.procs, "activations", true)
end

function Fight:GetSets()
    return Util.SortedValues(self.sets, "damage", true)
end

function Fight:GetCasts()
    return self.casts, Util.SortedValues(self.casts.abilities, "count", true)
end

function Fight:GetPower(powerType)
    if powerType then return self.power[powerType] end
    return self.power
end

function Fight:GetDeaths() return self.deaths end
function Fight:GetBuild() return self.build end
function Fight:GetStats() return self.stats end
function Fight:GetGroup() return Util.SortedValues(self.group, "damage", true) end

-- Raw events as an array (oldest first). Empty if raw logging was disabled.
function Fight:GetEvents()
    local ev = self.events
    if not ev then return {} end
    if ev.ToArray then return ev:ToArray() end
    return ev
end

function Fight:GetEventCount()
    local ev = self.events
    if not ev then return 0 end
    if ev.Count then return ev:Count() end
    return #ev
end

-- Decodes one compact raw event into a readable table
function Fight:DecodeEvent(ev)
    local F = LF.EVENT_FIELDS
    local abilityId = ev[F.ABILITY]
    return {
        tMs = ev[F.TIME] - self.startMs, time = ev[F.TIME], direction = Fight.DIR_NAME[ev[F.DIR]],
        result = ev[F.RESULT], resultName = Const.GetResultName(ev[F.RESULT]),
        category = Const.GetResultCategory(ev[F.RESULT]), isCrit = CRIT[ev[F.RESULT]] or false,
        abilityId = abilityId, abilityName = LF.Abilities.GetName(abilityId), icon = LF.Abilities.GetIcon(abilityId),
        hit = ev[F.HIT], overflow = ev[F.OVERFLOW],
        sourceUnitId = ev[F.SOURCE], source = self:GetUnitName(ev[F.SOURCE]),
        targetUnitId = ev[F.TARGET], target = self:GetUnitName(ev[F.TARGET]),
        damageType = ev[F.DAMAGE_TYPE], damageTypeName = Const.GetDamageTypeName(ev[F.DAMAGE_TYPE]),
        powerType = ev[F.POWER_TYPE], slotType = ev[F.SLOT_TYPE],
    }
end
