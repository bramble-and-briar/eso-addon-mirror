-- ESO Adventurer Suite
-- Copyright (c) 2026 HoZayyBadazz. All Rights Reserved.
-- Proprietary source. Unauthorized redistribution, republication, rebranding,
-- or public distribution of modified/derivative versions is prohibited.
-- Private personal-use modifications are permitted. See LICENSE.txt.

local EPC = ESOProgressionCoach
EPC.Combat = EPC.Combat or {}
local C = EPC.Combat

local function nowMs()
    if type(GetFrameTimeMilliseconds) == "function" then
        local ok, value = pcall(GetFrameTimeMilliseconds)
        if ok then return tonumber(value) or 0 end
    end
    return 0
end

local function nowSeconds()
    if type(GetFrameTimeSeconds) == "function" then
        local ok, value = pcall(GetFrameTimeSeconds)
        if ok then return tonumber(value) or 0 end
    end
    return nowMs() / 1000
end

local function readPlayerPower(powerType)
    if powerType == nil or type(GetUnitPower) ~= "function" then return 0, 0 end
    local ok, current, maximum = pcall(GetUnitPower, "player", powerType)
    if not ok then return 0, 0 end
    return tonumber(current) or 0, tonumber(maximum) or 0
end

local function safeNumber(value, fallback)
    value = tonumber(value)
    if value == nil then return fallback or 0 end
    return value
end

local function isCriticalDamageResult(result)
    return (ACTION_RESULT_CRITICAL_DAMAGE ~= nil and result == ACTION_RESULT_CRITICAL_DAMAGE)
        or (ACTION_RESULT_DOT_TICK_CRITICAL ~= nil and result == ACTION_RESULT_DOT_TICK_CRITICAL)
end

local function isBlockedDamageResult(result)
    return (ACTION_RESULT_BLOCKED_DAMAGE ~= nil and result == ACTION_RESULT_BLOCKED_DAMAGE)
        or (ACTION_RESULT_BLOCKED ~= nil and result == ACTION_RESULT_BLOCKED)
end

local function isDotResult(result)
    return (ACTION_RESULT_DOT_TICK ~= nil and result == ACTION_RESULT_DOT_TICK)
        or (ACTION_RESULT_DOT_TICK_CRITICAL ~= nil and result == ACTION_RESULT_DOT_TICK_CRITICAL)
end

local function isCriticalHealResult(result)
    return (ACTION_RESULT_CRITICAL_HEAL ~= nil and result == ACTION_RESULT_CRITICAL_HEAL)
        or (ACTION_RESULT_HOT_TICK_CRITICAL ~= nil and result == ACTION_RESULT_HOT_TICK_CRITICAL)
end

local function playerName()
    if type(GetUnitName) == "function" then
        local ok, value = pcall(GetUnitName, "player")
        if ok and value and value ~= "" then
            if type(zo_strformat) == "function" then value = zo_strformat("<<1>>", value) end
            return tostring(value):gsub("%^%a+", "")
        end
    end
    return "You"
end

local function normalizedName(name)
    name = tostring(name or "")
    if name == "" then return nil end
    if type(zo_strformat) == "function" then
        local ok, value = pcall(zo_strformat, "<<1>>", name)
        if ok and value and value ~= "" then name = value end
    end
    name = name:gsub("%^%a+", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return nil end
    return name
end


local function nameKey(name)
    name = normalizedName(name)
    return name and string.lower(name) or nil
end

-- Build a small actor roster once at fight start.  It lets the recorder
-- distinguish group players from their visible companions without scanning the
-- group on every combat event. ESO exposes local companions as their own combat
-- unit type; group companion attribution falls back to the companion unit tags
-- that are currently visible to the client.
local BuildActorRosterImplArch
function C:BuildActorRoster(...)
    return BuildActorRosterImplArch(self, ...)
end
BuildActorRosterImplArch = function(self)
    local roster = { players = {}, companions = {}, selfName = playerName() }
    roster.players[nameKey(roster.selfName) or "you"] = roster.selfName

    local function addPlayer(unitTag)
        if not unitTag or unitTag == "" then return end
        if type(DoesUnitExist) == "function" then
            local ok, exists = pcall(DoesUnitExist, unitTag)
            if ok and not exists then return end
        end
        local name = nil
        if unitTag and type(GetUnitName) == "function" then
            local ok, value = pcall(GetUnitName, unitTag)
            if ok then name = normalizedName(value) end
        end
        if not name then return end
        roster.players[nameKey(name)] = name

        if type(GetCompanionUnitTagByGroupUnitTag) == "function" then
            local ok, companionTag = pcall(GetCompanionUnitTagByGroupUnitTag, unitTag)
            if ok and companionTag and companionTag ~= "" then
                local exists = true
                if type(DoesUnitExist) == "function" then
                    local okExists, value = pcall(DoesUnitExist, companionTag)
                    exists = okExists and value == true
                end
                if exists and type(GetUnitName) == "function" then
                    local okName, companionName = pcall(GetUnitName, companionTag)
                    companionName = okName and normalizedName(companionName) or nil
                    if companionName then
                        roster.companions[nameKey(companionName)] = { name = companionName, owner = name }
                    end
                end
            end
        end
    end

    local groupSize = 0
    if type(GetGroupSize) == "function" then
        local ok, value = pcall(GetGroupSize)
        if ok then groupSize = math.max(0, tonumber(value) or 0) end
    end
    for index = 1, groupSize do
        local unitTag = nil
        if type(GetGroupUnitTagByIndex) == "function" then
            local ok, value = pcall(GetGroupUnitTagByIndex, index)
            if ok then unitTag = value end
        end
        if not unitTag or unitTag == "" then unitTag = "group" .. tostring(index) end
        addPlayer(unitTag)
    end

    if type(DoesUnitExist) == "function" and type(GetUnitName) == "function" then
        local okExists, exists = pcall(DoesUnitExist, "companion")
        if okExists and exists then
            local okName, companionName = pcall(GetUnitName, "companion")
            companionName = okName and normalizedName(companionName) or nil
            if companionName then
                roster.localCompanionName = companionName
                roster.companions[nameKey(companionName)] = { name = companionName, owner = roster.selfName }
            end
        end
    end
    return roster
end

function C:ResolveCombatActor(sourceName, sourceType, sourceUnitId)
    local source = normalizedName(sourceName) or "Unknown"
    local key = nameKey(source)
    local roster = self.current and self.current.actorRoster or nil
    local selfName = roster and roster.selfName or playerName()

    if COMBAT_UNIT_TYPE_PLAYER ~= nil and sourceType == COMBAT_UNIT_TYPE_PLAYER then
        return { kind = "PLAYER", name = selfName, owner = selfName, isSelf = true, sourceUnitId = safeNumber(sourceUnitId, 0) }
    end
    if COMBAT_UNIT_TYPE_PLAYER_COMPANION ~= nil and sourceType == COMBAT_UNIT_TYPE_PLAYER_COMPANION then
        local companion = roster and key and roster.companions[key] or nil
        return { kind = "COMPANION", name = companion and companion.name or (roster and roster.localCompanionName) or source, owner = selfName, isSelf = false, ownedBySelf = true, sourceUnitId = safeNumber(sourceUnitId, 0) }
    end
    if COMBAT_UNIT_TYPE_PLAYER_PET ~= nil and sourceType == COMBAT_UNIT_TYPE_PLAYER_PET then
        -- Some older clients reported the local companion through the pet type.
        local companion = roster and key and roster.companions[key] or nil
        if companion and companion.owner == selfName then
            return { kind = "COMPANION", name = companion.name, owner = selfName, isSelf = false, ownedBySelf = true, sourceUnitId = safeNumber(sourceUnitId, 0) }
        end
        return { kind = "PET", name = source, owner = selfName, isSelf = false, ownedBySelf = true, sourceUnitId = safeNumber(sourceUnitId, 0) }
    end
    if COMBAT_UNIT_TYPE_GROUP ~= nil and sourceType == COMBAT_UNIT_TYPE_GROUP then
        local companion = roster and key and roster.companions[key] or nil
        if companion then
            return { kind = "COMPANION", name = companion.name, owner = companion.owner, isSelf = false, sourceUnitId = safeNumber(sourceUnitId, 0) }
        end
        local groupPlayer = roster and key and roster.players[key] or nil
        if groupPlayer then
            return { kind = "PLAYER", name = groupPlayer, owner = groupPlayer, isSelf = groupPlayer == selfName, sourceUnitId = safeNumber(sourceUnitId, 0) }
        end
        -- ESO can expose a grouped player's summon without enough ownership
        -- information to identify which player owns it. Keep the summon visible
        -- instead of falsely assigning it to a teammate.
        return { kind = "SUMMON", name = source, owner = nil, isSelf = false, sourceUnitId = safeNumber(sourceUnitId, 0) }
    end

    local companion = roster and key and roster.companions[key] or nil
    if companion then
        return { kind = "COMPANION", name = companion.name, owner = companion.owner, isSelf = false, ownedBySelf = companion.owner == selfName, sourceUnitId = safeNumber(sourceUnitId, 0) }
    end
    local groupPlayer = roster and key and roster.players[key] or nil
    if groupPlayer then
        return { kind = "PLAYER", name = groupPlayer, owner = groupPlayer, isSelf = groupPlayer == selfName, sourceUnitId = safeNumber(sourceUnitId, 0) }
    end
    return { kind = "OTHER", name = source, owner = nil, isSelf = false, sourceUnitId = safeNumber(sourceUnitId, 0) }
end

function C:GetOrCreateActor(actor)
    if not self.current or type(actor) ~= "table" then return nil end
    local actors = self.current.actors
    if type(actors) ~= "table" then actors = {} self.current.actors = actors end
    local id = safeNumber(actor.sourceUnitId, 0)
    local key = table.concat({ tostring(actor.kind or "OTHER"), tostring(actor.owner or ""), id > 0 and tostring(id) or tostring(nameKey(actor.name) or actor.name or "unknown") }, "|")
    local row = actors[key]
    if not row then
        row = {
            name = actor.name or "Unknown", kind = actor.kind or "OTHER", owner = actor.owner,
            sourceUnitId = id, isSelf = actor.isSelf == true, ownedBySelf = actor.ownedBySelf == true,
            damage = 0, healing = 0, hits = 0, criticalHits = 0, healEvents = 0, criticalHeals = 0, abilities = {},
        }
        actors[key] = row
    end
    return row
end

function C:BuildActorList(fight, duration)
    local rows = {}
    duration = math.max(0.1, safeNumber(duration, 0.1))
    for _, actor in pairs(type(fight) == "table" and fight.actors or {}) do
        if type(actor) == "table" and (safeNumber(actor.damage, 0) > 0 or safeNumber(actor.healing, 0) > 0) then
            rows[#rows + 1] = {
                name = actor.name or "Unknown", kind = actor.kind or "OTHER", owner = actor.owner or "",
                damage = safeNumber(actor.damage, 0), healing = safeNumber(actor.healing, 0),
                dps = safeNumber(actor.damage, 0) / duration, hps = safeNumber(actor.healing, 0) / duration,
                hits = safeNumber(actor.hits, 0), criticalHits = safeNumber(actor.criticalHits, 0),
                critPercent = safeNumber(actor.hits, 0) > 0 and (safeNumber(actor.criticalHits, 0) / safeNumber(actor.hits, 0) * 100) or 0,
                isSelf = actor.isSelf == true, ownedBySelf = actor.ownedBySelf == true,
            }
        end
    end
    table.sort(rows, function(a, b)
        local ak = (a.kind == "PLAYER" and 1) or (a.kind == "COMPANION" and 2) or (a.kind == "PET" and 3) or 4
        local bk = (b.kind == "PLAYER" and 1) or (b.kind == "COMPANION" and 2) or (b.kind == "PET" and 3) or 4
        if ak ~= bk then return ak < bk end
        if a.damage == b.damage then return a.healing > b.healing end
        return a.damage > b.damage
    end)
    return rows
end

local function weightedAverage(sum, weight, fallback)
    weight = safeNumber(weight, 0)
    if weight > 0 then return safeNumber(sum, 0) / weight end
    return fallback
end

local ReadCombatStatsSnapshotImplArch

function C:ReadCombatStatsSnapshot(...)

    return ReadCombatStatsSnapshotImplArch(self, ...)

end

ReadCombatStatsSnapshotImplArch = function(self, force)
    local frames = EPC.UnitFrames
    if frames and type(frames.GetCombatStatsSnapshot) == "function" then
        local ok, snapshot = pcall(frames.GetCombatStatsSnapshot, frames, force == true)
        if ok and type(snapshot) == "table" then return snapshot end
    end
    return nil
end

local AccumulateCombatStatsImplArch

function C:AccumulateCombatStats(...)

    return AccumulateCombatStatsImplArch(self, ...)

end

AccumulateCombatStatsImplArch = function(self, eventKind, value, result)
    local fight = self.current
    if not fight then return end
    local snapshot = self:ReadCombatStatsSnapshot(false)
    if type(snapshot) ~= "table" then return end

    local tracking = fight.statTracking
    if type(tracking) ~= "table" then
        tracking = { samples = 0 }
        fight.statTracking = tracking
    end
    tracking.samples = safeNumber(tracking.samples, 0) + 1
    tracking.last = snapshot
    value = math.max(1, safeNumber(value, 1))

    if eventKind == "DAMAGE" then
        tracking.damageWeight = safeNumber(tracking.damageWeight, 0) + value
        tracking.penetrationSum = safeNumber(tracking.penetrationSum, 0) + safeNumber(snapshot.penetration, 0) * value
        tracking.outputWeight = safeNumber(tracking.outputWeight, 0) + value
        tracking.powerSum = safeNumber(tracking.powerSum, 0) + safeNumber(snapshot.power, 0) * value
        if snapshot.criticalChance ~= nil then
            tracking.criticalChanceWeight = safeNumber(tracking.criticalChanceWeight, 0) + value
            tracking.criticalChanceSum = safeNumber(tracking.criticalChanceSum, 0) + safeNumber(snapshot.criticalChance, 0) * value
        end
        if isCriticalDamageResult(result) and snapshot.criticalDamage ~= nil then
            tracking.criticalDamageWeight = safeNumber(tracking.criticalDamageWeight, 0) + value
            tracking.criticalDamageSum = safeNumber(tracking.criticalDamageSum, 0) + safeNumber(snapshot.criticalDamage, 0) * value
        end
    elseif eventKind == "HEAL" then
        tracking.outputWeight = safeNumber(tracking.outputWeight, 0) + value
        tracking.powerSum = safeNumber(tracking.powerSum, 0) + safeNumber(snapshot.power, 0) * value
        if snapshot.criticalChance ~= nil then
            tracking.criticalChanceWeight = safeNumber(tracking.criticalChanceWeight, 0) + value
            tracking.criticalChanceSum = safeNumber(tracking.criticalChanceSum, 0) + safeNumber(snapshot.criticalChance, 0) * value
        end
    elseif eventKind == "INCOMING_DAMAGE" then
        tracking.defenseWeight = safeNumber(tracking.defenseWeight, 0) + value
        tracking.spellResistanceSum = safeNumber(tracking.spellResistanceSum, 0) + safeNumber(snapshot.spellResistance, 0) * value
        tracking.physicalResistanceSum = safeNumber(tracking.physicalResistanceSum, 0) + safeNumber(snapshot.physicalResistance, 0) * value
    end
end

function C:BuildEffectiveCombatStats(fight)
    fight = fight or self.current
    local tracking = fight and fight.statTracking
    local last = type(tracking) == "table" and tracking.last or nil
    if type(last) ~= "table" then last = self:ReadCombatStatsSnapshot(false) or {} end
    if type(tracking) ~= "table" then
        return {
            penetration = safeNumber(last.penetration, 0), power = safeNumber(last.power, 0),
            spellResistance = safeNumber(last.spellResistance, 0), physicalResistance = safeNumber(last.physicalResistance, 0),
            criticalChance = last.criticalChance, criticalDamage = last.criticalDamage, samples = 0,
        }
    end

    return {
        penetration = weightedAverage(tracking.penetrationSum, tracking.damageWeight, safeNumber(last.penetration, 0)),
        power = weightedAverage(tracking.powerSum, tracking.outputWeight, safeNumber(last.power, 0)),
        spellResistance = weightedAverage(tracking.spellResistanceSum, tracking.defenseWeight, safeNumber(last.spellResistance, 0)),
        physicalResistance = weightedAverage(tracking.physicalResistanceSum, tracking.defenseWeight, safeNumber(last.physicalResistance, 0)),
        criticalChance = weightedAverage(tracking.criticalChanceSum, tracking.criticalChanceWeight, last.criticalChance),
        criticalDamage = weightedAverage(tracking.criticalDamageSum, tracking.criticalDamageWeight, last.criticalDamage),
        samples = safeNumber(tracking.samples, 0),
    }
end

function C:InitializeResourceTracking(fight)
    if type(fight) ~= "table" then return end
    local magicka, magickaMax = readPlayerPower(POWERTYPE_MAGICKA)
    local stamina, staminaMax = readPlayerPower(POWERTYPE_STAMINA)
    fight.resources = {
        MAGICKA = { last = magicka, maximum = magickaMax, spent = 0, gained = 0 },
        STAMINA = { last = stamina, maximum = staminaMax, spent = 0, gained = 0 },
    }
end

function C:OnPowerUpdate(resourceKey, current, maximum)
    if not self.inCombat or not self.current then return end
    local resources = self.current.resources
    local row = type(resources) == "table" and resources[resourceKey] or nil
    if type(row) ~= "table" then return end
    current = safeNumber(current, row.last or 0)
    maximum = safeNumber(maximum, row.maximum or 0)
    local previous = safeNumber(row.last, current)
    local delta = current - previous
    if delta < 0 then row.spent = safeNumber(row.spent, 0) - delta
    elseif delta > 0 then row.gained = safeNumber(row.gained, 0) + delta end
    row.last = current
    row.maximum = maximum
end

function C:BuildResourceStats(fight, duration)
    local resources = type(fight) == "table" and fight.resources or nil
    duration = math.max(0.1, safeNumber(duration, 0.1))
    local function row(key)
        local source = type(resources) == "table" and resources[key] or nil
        if type(source) ~= "table" then return { spent = 0, gained = 0, spentPerSecond = 0, gainedPerSecond = 0 } end
        local spent, gained = safeNumber(source.spent, 0), safeNumber(source.gained, 0)
        return {
            spent = spent, gained = gained,
            spentPerSecond = spent / duration, gainedPerSecond = gained / duration,
            ending = safeNumber(source.last, 0), maximum = safeNumber(source.maximum, 0),
        }
    end
    return { magicka = row("MAGICKA"), stamina = row("STAMINA") }
end

function C:InitializeEffectTracking(fight)
    if type(fight) ~= "table" then return end
    fight.effects = {}
    local count = type(GetNumBuffs) == "function" and safeNumber(GetNumBuffs("player"), 0) or 0
    local stamp = nowSeconds()
    if type(GetUnitBuffInfo) ~= "function" then return end
    for index = 1, count do
        local ok, name, beginTime, endTime, _, stackCount, icon, _, effectType, _, _, abilityId = pcall(GetUnitBuffInfo, "player", index)
        if ok and name and name ~= "" then
            local key = safeNumber(abilityId, 0) > 0 and tostring(abilityId) or tostring(name)
            fight.effects[key] = {
                name = normalizedName(name) or tostring(name), icon = tostring(icon or ""), abilityId = safeNumber(abilityId, 0),
                debuff = BUFF_EFFECT_TYPE_DEBUFF ~= nil and effectType == BUFF_EFFECT_TYPE_DEBUFF,
                stacks = safeNumber(stackCount, 0), maxStacks = safeNumber(stackCount, 0),
                uptime = 0, activeSince = stamp, lastEndTime = safeNumber(endTime, 0),
            }
        end
    end
end

function C:OnEffectChanged(changeType, effectName, unitTag, beginTime, endTime, stackCount, iconName, effectType, abilityId)
    if not self.inCombat or not self.current then return end
    if unitTag and unitTag ~= "" and unitTag ~= "player" then return end
    local name = normalizedName(effectName) or tostring(effectName or "")
    if name == "" and safeNumber(abilityId, 0) <= 0 then return end
    local key = safeNumber(abilityId, 0) > 0 and tostring(abilityId) or name
    local effects = self.current.effects
    if type(effects) ~= "table" then effects = {} self.current.effects = effects end
    local row = effects[key]
    if type(row) ~= "table" then
        row = {
            name = name ~= "" and name or "Effect", icon = tostring(iconName or ""), abilityId = safeNumber(abilityId, 0),
            debuff = BUFF_EFFECT_TYPE_DEBUFF ~= nil and effectType == BUFF_EFFECT_TYPE_DEBUFF,
            stacks = 0, maxStacks = 0, uptime = 0, activeSince = nil, lastEndTime = 0,
        }
        effects[key] = row
    end
    if name ~= "" then row.name = name end
    if iconName and iconName ~= "" then row.icon = tostring(iconName) end
    row.debuff = BUFF_EFFECT_TYPE_DEBUFF ~= nil and effectType == BUFF_EFFECT_TYPE_DEBUFF
    row.stacks = safeNumber(stackCount, row.stacks or 0)
    row.maxStacks = math.max(safeNumber(row.maxStacks, 0), row.stacks)
    row.lastEndTime = safeNumber(endTime, row.lastEndTime or 0)

    local stamp = nowSeconds()
    if (EFFECT_RESULT_GAINED ~= nil and changeType == EFFECT_RESULT_GAINED)
        or (EFFECT_RESULT_UPDATED ~= nil and changeType == EFFECT_RESULT_UPDATED)
        or (EFFECT_RESULT_FULL_REFRESH ~= nil and changeType == EFFECT_RESULT_FULL_REFRESH)
        or (EFFECT_RESULT_TRANSFER ~= nil and changeType == EFFECT_RESULT_TRANSFER) then
        if not row.activeSince then row.activeSince = math.max(stamp, safeNumber(beginTime, stamp)) end
    elseif EFFECT_RESULT_FADED ~= nil and changeType == EFFECT_RESULT_FADED then
        if row.activeSince then
            row.uptime = safeNumber(row.uptime, 0) + math.max(0, stamp - safeNumber(row.activeSince, stamp))
            row.activeSince = nil
        end
    end
end

function C:BuildEffectList(fight, duration)
    local rows = {}
    local stamp = nowSeconds()
    duration = math.max(0.1, safeNumber(duration, 0.1))
    for _, data in pairs(type(fight) == "table" and fight.effects or {}) do
        if type(data) == "table" then
            local uptime = safeNumber(data.uptime, 0)
            if data.activeSince then uptime = uptime + math.max(0, stamp - safeNumber(data.activeSince, stamp)) end
            uptime = math.min(duration, uptime)
            rows[#rows + 1] = {
                name = data.name or "Effect", icon = data.icon or "", abilityId = safeNumber(data.abilityId, 0),
                debuff = data.debuff == true, stacks = safeNumber(data.maxStacks, data.stacks or 0),
                uptime = uptime, uptimePercent = duration > 0 and (uptime / duration * 100) or 0,
            }
        end
    end
    table.sort(rows, function(a, b)
        if a.debuff ~= b.debuff then return a.debuff == true end
        if a.uptimePercent == b.uptimePercent then return tostring(a.name) < tostring(b.name) end
        return a.uptimePercent > b.uptimePercent
    end)
    while #rows > 30 do table.remove(rows) end
    return rows
end

function C:BuildIncomingSourceList(fight, duration)
    local rows = {}
    duration = math.max(0.1, safeNumber(duration, 0.1))
    for _, data in pairs(type(fight) == "table" and fight.incomingSources or {}) do
        if type(data) == "table" and safeNumber(data.damage, 0) > 0 then
            rows[#rows + 1] = {
                name = data.name or "Incoming", source = data.source or "Unknown", abilityId = safeNumber(data.abilityId, 0),
                damage = safeNumber(data.damage, 0), dps = safeNumber(data.damage, 0) / duration,
                hits = safeNumber(data.hits, 0), maxHit = safeNumber(data.maxHit, 0),
            }
        end
    end
    table.sort(rows, function(a, b) return a.damage > b.damage end)
    return rows
end

function C:Initialize()
    self.inCombat = false
    self.current = nil
    self.lastFight = nil
    if EPC.saved then EPC.saved.combatPersonalBests = EPC.saved.combatPersonalBests or {} end
end

function C:GetPersonalBest(role)
    role = role or (EPC.Role and EPC.Role:GetRole()) or "DAMAGE"
    local b = EPC.saved and EPC.saved.combatPersonalBests or {}
    local row = b[role] or {}
    if role == "HEALER" then return safeNumber(row.hps, 0) end
    if role == "TANK" then return safeNumber(row.blockPercent, 0) end
    return safeNumber(row.dps, 0)
end

function C:UpdatePersonalBest(fight)
    if not EPC.saved or not fight then return end
    EPC.saved.combatPersonalBests = EPC.saved.combatPersonalBests or {}
    local role = EPC.Role and EPC.Role:GetRole() or "DAMAGE"
    local row = EPC.saved.combatPersonalBests[role] or {}
    row.dps = math.max(safeNumber(row.dps, 0), safeNumber(fight.dps, 0))
    row.hps = math.max(safeNumber(row.hps, 0), safeNumber(fight.hps, 0))
    row.blockPercent = math.max(safeNumber(row.blockPercent, 0), safeNumber(fight.blockPercent, 0))
    row.bestDuration = math.max(safeNumber(row.bestDuration, 0), safeNumber(fight.duration, 0))
    EPC.saved.combatPersonalBests[role] = row
end

local BeginFightImplArch

function C:BeginFight(...)

    return BeginFightImplArch(self, ...)

end

BeginFightImplArch = function(self)
    self.inCombat = true
    self.current = {
        startedAt = nowMs(), totalDamage = 0, directDamage = 0, dotDamage = 0, petDamage = 0, companionDamage = 0,
        petHealing = 0, companionHealing = 0,
        hits = 0, criticalHits = 0, totalHealing = 0, healEvents = 0, criticalHeals = 0,
        incomingDamage = 0, incomingHits = 0, blockedHits = 0, incomingSources = {},
        abilities = {}, targets = {}, group = {}, actors = {}, actorRoster = nil,
        statTracking = { samples = 0, last = self:ReadCombatStatsSnapshot(true) },
    }
    self.current.actorRoster = self:BuildActorRoster()
    self:InitializeResourceTracking(self.current)
    self:InitializeEffectTracking(self.current)
end

function C:GetOrCreateContributor(name, isSelf)
    if not self.current then return nil end
    name = isSelf and playerName() or normalizedName(name)
    if not name then return nil end
    local key = string.lower(name)
    local contributor = self.current.group[key]
    if not contributor then
        contributor = { name = name, damage = 0, healing = 0, hits = 0, criticalHits = 0, healEvents = 0, criticalHeals = 0, isSelf = isSelf == true }
        self.current.group[key] = contributor
    elseif isSelf then
        contributor.isSelf = true
        contributor.name = playerName()
    end
    return contributor
end

local OnCombatEventImplArch

function C:OnCombatEvent(...)

    return OnCombatEventImplArch(self, ...)

end

OnCombatEventImplArch = function(self, eventKind, result, abilityName, sourceName, sourceType, targetName, targetType, hitValue, abilityId, sourceUnitId)
    if not self.inCombat or not self.current then return end

    local value = math.max(0, safeNumber(hitValue, 0))
    if value <= 0 then return end

    if eventKind == "INCOMING_DAMAGE" then
        self.current.incomingDamage = self.current.incomingDamage + value
        self.current.incomingHits = self.current.incomingHits + 1
        if isBlockedDamageResult(result) then self.current.blockedHits = self.current.blockedHits + 1 end
        self:AccumulateCombatStats(eventKind, value, result)
        local source = normalizedName(sourceName) or "Unknown"
        local ability = normalizedName(abilityName) or "Incoming Damage"
        local sourceKey = safeNumber(abilityId, 0) > 0 and tostring(abilityId) or (string.lower(source) .. "|" .. string.lower(ability))
        local row = self.current.incomingSources[sourceKey]
        if type(row) ~= "table" then
            row = { name = ability, source = source, abilityId = safeNumber(abilityId, 0), damage = 0, hits = 0, maxHit = 0 }
            self.current.incomingSources[sourceKey] = row
        end
        row.damage = safeNumber(row.damage, 0) + value
        row.hits = safeNumber(row.hits, 0) + 1
        row.maxHit = math.max(safeNumber(row.maxHit, 0), value)
        return
    end

    local damageEvent = eventKind == "DAMAGE"
    local healEvent = eventKind == "HEAL"
    if not damageEvent and not healEvent then return end

    local actorInfo = self:ResolveCombatActor(sourceName, sourceType, sourceUnitId)
    local actor = self:GetOrCreateActor(actorInfo)
    if actor then
        if damageEvent then
            actor.damage = safeNumber(actor.damage, 0) + value
            actor.hits = safeNumber(actor.hits, 0) + 1
            if isCriticalDamageResult(result) then actor.criticalHits = safeNumber(actor.criticalHits, 0) + 1 end
        else
            actor.healing = safeNumber(actor.healing, 0) + value
            actor.healEvents = safeNumber(actor.healEvents, 0) + 1
            if isCriticalHealResult(result) then actor.criticalHeals = safeNumber(actor.criticalHeals, 0) + 1 end
        end
    end

    -- Group contribution is rolled up to the owning player when ESO exposes
    -- that relationship. Unowned grouped summons remain visible in Actors but
    -- are never guessed onto a teammate.
    local owner = actorInfo and actorInfo.owner or nil
    local contributor = owner and self:GetOrCreateContributor(owner, owner == playerName()) or nil
    if contributor then
        if damageEvent then
            contributor.damage = safeNumber(contributor.damage, 0) + value
            contributor.hits = safeNumber(contributor.hits, 0) + 1
            if isCriticalDamageResult(result) then contributor.criticalHits = safeNumber(contributor.criticalHits, 0) + 1 end
        else
            contributor.healing = safeNumber(contributor.healing, 0) + value
            contributor.healEvents = safeNumber(contributor.healEvents, 0) + 1
            if isCriticalHealResult(result) then contributor.criticalHeals = safeNumber(contributor.criticalHeals, 0) + 1 end
        end
    end

    local fight = self.current
    local kind = actorInfo and actorInfo.kind or "OTHER"
    local ownedBySelf = actorInfo and (actorInfo.ownedBySelf == true or actorInfo.isSelf == true)
    if not ownedBySelf then return end

    -- Personal DPS/HPS is PLAYER-only. Pets and companions are tracked as
    -- separate child actors and exposed through combined totals.
    if kind == "PLAYER" then
        self:AccumulateCombatStats(eventKind, value, result)
        if damageEvent then
            fight.totalDamage = fight.totalDamage + value
            fight.hits = fight.hits + 1
            if isCriticalDamageResult(result) then fight.criticalHits = fight.criticalHits + 1 end
            if isDotResult(result) then fight.dotDamage = fight.dotDamage + value else fight.directDamage = fight.directDamage + value end
            local key = safeNumber(abilityId, 0) > 0 and tostring(abilityId) or tostring(abilityName or "Unknown")
            local ability = fight.abilities[key] or {
                name = abilityName and abilityName ~= "" and abilityName or "Unknown",
                abilityId = safeNumber(abilityId, 0), damage = 0, hits = 0,
                criticalHits = 0, maxHit = 0,
            }
            ability.damage = ability.damage + value
            ability.hits = ability.hits + 1
            if isCriticalDamageResult(result) then ability.criticalHits = (ability.criticalHits or 0) + 1 end
            ability.maxHit = math.max(ability.maxHit or 0, value)
            fight.abilities[key] = ability
            if targetName and targetName ~= "" then
                local targetKey = tostring(targetName)
                local target = fight.targets[targetKey]
                if type(target) ~= "table" then target = { name = targetKey, damage = 0, hits = 0, criticalHits = 0 } end
                target.damage = (target.damage or 0) + value
                target.hits = (target.hits or 0) + 1
                if isCriticalDamageResult(result) then target.criticalHits = (target.criticalHits or 0) + 1 end
                fight.targets[targetKey] = target
            end
        else
            fight.totalHealing = fight.totalHealing + value
            fight.healEvents = fight.healEvents + 1
            if isCriticalHealResult(result) then fight.criticalHeals = fight.criticalHeals + 1 end
        end
    elseif kind == "COMPANION" then
        if damageEvent then fight.companionDamage = safeNumber(fight.companionDamage, 0) + value
        else fight.companionHealing = safeNumber(fight.companionHealing, 0) + value end
    elseif kind == "PET" then
        if damageEvent then fight.petDamage = safeNumber(fight.petDamage, 0) + value
        else fight.petHealing = safeNumber(fight.petHealing, 0) + value end
    end
end

function C:BuildContributorList(fight, duration)
    local contributors = {}
    for _, data in pairs(fight.group or {}) do
        if (data.damage or 0) > 0 or (data.healing or 0) > 0 then
            contributors[#contributors + 1] = {
                name = data.name or "Unknown", damage = data.damage or 0, healing = data.healing or 0,
                dps = (data.damage or 0) / duration, hps = (data.healing or 0) / duration,
                critPercent = (data.hits or 0) > 0 and ((data.criticalHits or 0) / data.hits * 100) or 0,
                isSelf = data.isSelf == true,
            }
        end
    end
    table.sort(contributors, function(a, b)
        if a.damage == b.damage then return a.healing > b.healing end
        return a.damage > b.damage
    end)
    return contributors
end

function C:BuildTargetList(fight, duration)
    local targets = {}
    for name, data in pairs(fight.targets or {}) do
        if type(data) == "table" then
            targets[#targets + 1] = {
                name = data.name or name or "Unknown",
                damage = data.damage or 0,
                dps = (data.damage or 0) / duration,
                hits = data.hits or 0,
                criticalHits = data.criticalHits or 0,
                critPercent = (data.hits or 0) > 0 and ((data.criticalHits or 0) / data.hits * 100) or 0,
            }
        else
            targets[#targets + 1] = { name = tostring(name or "Unknown"), damage = 0, dps = 0, hits = 0, criticalHits = 0, critPercent = 0 }
        end
    end
    table.sort(targets, function(a, b) return (a.damage or 0) > (b.damage or 0) end)
    return targets
end

function C:GetLiveSummary()
    local fight = self.current
    if not fight then return nil end
    local duration = math.max(0.1, (nowMs() - safeNumber(fight.startedAt, nowMs())) / 1000)
    return {
        active = true, duration = duration, dps = fight.totalDamage / duration, totalDamage = fight.totalDamage,
        petDamage = fight.petDamage or 0, petDps = (fight.petDamage or 0) / duration,
        companionDamage = fight.companionDamage or 0, companionDps = (fight.companionDamage or 0) / duration,
        combinedDamage = (fight.totalDamage or 0) + (fight.petDamage or 0) + (fight.companionDamage or 0),
        combinedDps = ((fight.totalDamage or 0) + (fight.petDamage or 0) + (fight.companionDamage or 0)) / duration,
        hits = fight.hits or 0, criticalHits = fight.criticalHits or 0,
        hps = fight.totalHealing / duration, totalHealing = fight.totalHealing,
        petHealing = fight.petHealing or 0, companionHealing = fight.companionHealing or 0,
        combinedHealing = (fight.totalHealing or 0) + (fight.petHealing or 0) + (fight.companionHealing or 0),
        healEvents = fight.healEvents or 0, criticalHeals = fight.criticalHeals or 0,
        criticalEventPercent = fight.hits > 0 and (fight.criticalHits / fight.hits * 100) or 0,
        criticalHealPercent = fight.healEvents > 0 and (fight.criticalHeals / fight.healEvents * 100) or 0,
        incomingDamage = fight.incomingDamage or 0, dtps = (fight.incomingDamage or 0) / duration,
        incomingHits = fight.incomingHits or 0, blockedHits = fight.blockedHits or 0,
        blockPercent = (fight.incomingHits or 0) > 0 and ((fight.blockedHits or 0) / fight.incomingHits * 100) or 0,
        role = EPC.Role and EPC.Role:GetRole() or "DAMAGE",
    }
end

function C:GetHUDSummary()
    local live = self:GetLiveSummary()
    if live then return live end
    local last = self.lastFight
    if not last then return nil end
    if nowMs() - safeNumber(last.finishedAt, 0) > 10000 then return nil end
    return {
        active = false, duration = last.duration or 0, dps = last.dps or 0, totalDamage = last.totalDamage or 0,
        petDamage = last.petDamage or 0, petDps = last.petDps or 0, companionDamage = last.companionDamage or 0, companionDps = last.companionDps or 0,
        combinedDamage = last.combinedDamage or ((last.totalDamage or 0) + (last.petDamage or 0) + (last.companionDamage or 0)),
        combinedDps = last.combinedDps or 0,
        hits = last.hits or 0, criticalHits = last.criticalHits or 0,
        hps = last.hps or 0, totalHealing = last.totalHealing or 0, petHealing = last.petHealing or 0, companionHealing = last.companionHealing or 0,
        combinedHealing = last.combinedHealing or ((last.totalHealing or 0) + (last.petHealing or 0) + (last.companionHealing or 0)),
        healEvents = last.healEvents or 0, criticalHeals = last.criticalHeals or 0,
        criticalEventPercent = last.criticalEventPercent or 0, criticalHealPercent = last.criticalHealPercent or 0,
        incomingDamage = last.incomingDamage or 0, dtps = last.dtps or 0, incomingHits = last.incomingHits or 0, blockedHits = last.blockedHits or 0,
        blockPercent = last.blockPercent or 0, role = EPC.Role and EPC.Role:GetRole() or "DAMAGE"
    }
end

local GetDisplayFightImplArch

function C:GetDisplayFight(...)

    return GetDisplayFightImplArch(self, ...)

end

GetDisplayFightImplArch = function(self)
    local fight = self.current
    if not fight then return self.lastFight end
    local duration = math.max(0.1, (nowMs() - safeNumber(fight.startedAt, nowMs())) / 1000)
    local abilities = {}
    for _, data in pairs(fight.abilities or {}) do
        abilities[#abilities + 1] = {
            name = data.name, abilityId = data.abilityId or 0,
            damage = data.damage or 0, hits = data.hits or 0,
            criticalHits = data.criticalHits or 0, maxHit = data.maxHit or 0,
        }
    end
    table.sort(abilities, function(a, b) return (a.damage or 0) > (b.damage or 0) end)
    local targets = self:BuildTargetList(fight, duration)
    local targetCount = #targets
    return {
        live = true, duration = duration, totalDamage = fight.totalDamage, dps = fight.totalDamage / duration,
        directDamage = fight.directDamage, dotDamage = fight.dotDamage, dotPercent = fight.totalDamage > 0 and (fight.dotDamage / fight.totalDamage * 100) or 0,
        petDamage = fight.petDamage or 0, petDps = (fight.petDamage or 0) / duration,
        companionDamage = fight.companionDamage or 0, companionDps = (fight.companionDamage or 0) / duration,
        combinedDamage = (fight.totalDamage or 0) + (fight.petDamage or 0) + (fight.companionDamage or 0),
        combinedDps = ((fight.totalDamage or 0) + (fight.petDamage or 0) + (fight.companionDamage or 0)) / duration,
        petPercent = ((fight.totalDamage or 0) + (fight.petDamage or 0) + (fight.companionDamage or 0)) > 0 and ((fight.petDamage or 0) / ((fight.totalDamage or 0) + (fight.petDamage or 0) + (fight.companionDamage or 0)) * 100) or 0,
        companionPercent = ((fight.totalDamage or 0) + (fight.petDamage or 0) + (fight.companionDamage or 0)) > 0 and ((fight.companionDamage or 0) / ((fight.totalDamage or 0) + (fight.petDamage or 0) + (fight.companionDamage or 0)) * 100) or 0,
        hits = fight.hits, criticalHits = fight.criticalHits, criticalEventPercent = fight.hits > 0 and (fight.criticalHits / fight.hits * 100) or 0,
        totalHealing = fight.totalHealing, hps = fight.totalHealing / duration, petHealing = fight.petHealing or 0, companionHealing = fight.companionHealing or 0,
        combinedHealing = (fight.totalHealing or 0) + (fight.petHealing or 0) + (fight.companionHealing or 0),
        healEvents = fight.healEvents, criticalHeals = fight.criticalHeals,
        criticalHealPercent = fight.healEvents > 0 and (fight.criticalHeals / fight.healEvents * 100) or 0,
        incomingDamage = fight.incomingDamage or 0, dtps = (fight.incomingDamage or 0) / duration,
        incomingHits = fight.incomingHits or 0, blockedHits = fight.blockedHits or 0, blockPercent = (fight.incomingHits or 0) > 0 and ((fight.blockedHits or 0) / fight.incomingHits * 100) or 0,
        targetCount = targetCount, targets = targets, abilities = abilities, contributors = self:BuildContributorList(fight, duration), actors = self:BuildActorList(fight, duration),
        combatStats = self:BuildEffectiveCombatStats(fight),
        resources = self:BuildResourceStats(fight, duration), effects = self:BuildEffectList(fight, duration),
        incomingSources = self:BuildIncomingSourceList(fight, duration),
    }
end

local EndFightImplArch

function C:EndFight(...)

    return EndFightImplArch(self, ...)

end

EndFightImplArch = function(self)
    if not self.current then self.inCombat = false return end
    local fight = self.current
    self.current = nil
    self.inCombat = false
    local finishedAt = nowMs()
    local duration = math.max(0.1, (finishedAt - safeNumber(fight.startedAt, finishedAt)) / 1000)
    if fight.totalDamage <= 0 and fight.totalHealing <= 0 and (fight.petDamage or 0) <= 0 and (fight.companionDamage or 0) <= 0
        and (fight.petHealing or 0) <= 0 and (fight.companionHealing or 0) <= 0 and (fight.incomingDamage or 0) <= 0 then return end

    local abilities = {}
    for _, data in pairs(fight.abilities) do abilities[#abilities + 1] = data end
    table.sort(abilities, function(a, b) return (a.damage or 0) > (b.damage or 0) end)
    local targets = self:BuildTargetList(fight, duration)
    local targetCount = #targets

    self.lastFight = {
        finishedAt = finishedAt, duration = duration, totalDamage = fight.totalDamage, dps = fight.totalDamage / duration,
        directDamage = fight.directDamage, dotDamage = fight.dotDamage, dotPercent = fight.totalDamage > 0 and (fight.dotDamage / fight.totalDamage * 100) or 0,
        petDamage = fight.petDamage or 0, petDps = (fight.petDamage or 0) / duration,
        companionDamage = fight.companionDamage or 0, companionDps = (fight.companionDamage or 0) / duration,
        combinedDamage = (fight.totalDamage or 0) + (fight.petDamage or 0) + (fight.companionDamage or 0),
        combinedDps = ((fight.totalDamage or 0) + (fight.petDamage or 0) + (fight.companionDamage or 0)) / duration,
        petPercent = ((fight.totalDamage or 0) + (fight.petDamage or 0) + (fight.companionDamage or 0)) > 0 and ((fight.petDamage or 0) / ((fight.totalDamage or 0) + (fight.petDamage or 0) + (fight.companionDamage or 0)) * 100) or 0,
        companionPercent = ((fight.totalDamage or 0) + (fight.petDamage or 0) + (fight.companionDamage or 0)) > 0 and ((fight.companionDamage or 0) / ((fight.totalDamage or 0) + (fight.petDamage or 0) + (fight.companionDamage or 0)) * 100) or 0,
        hits = fight.hits, criticalHits = fight.criticalHits, criticalEventPercent = fight.hits > 0 and (fight.criticalHits / fight.hits * 100) or 0,
        totalHealing = fight.totalHealing, hps = fight.totalHealing / duration, petHealing = fight.petHealing or 0, companionHealing = fight.companionHealing or 0,
        combinedHealing = (fight.totalHealing or 0) + (fight.petHealing or 0) + (fight.companionHealing or 0),
        healEvents = fight.healEvents, criticalHeals = fight.criticalHeals,
        criticalHealPercent = fight.healEvents > 0 and (fight.criticalHeals / fight.healEvents * 100) or 0,
        incomingDamage = fight.incomingDamage or 0, dtps = (fight.incomingDamage or 0) / duration,
        incomingHits = fight.incomingHits or 0, blockedHits = fight.blockedHits or 0, blockPercent = (fight.incomingHits or 0) > 0 and ((fight.blockedHits or 0) / fight.incomingHits * 100) or 0,
        targetCount = targetCount, targets = targets, abilities = abilities, contributors = self:BuildContributorList(fight, duration), actors = self:BuildActorList(fight, duration),
        combatStats = self:BuildEffectiveCombatStats(fight),
        resources = self:BuildResourceStats(fight, duration), effects = self:BuildEffectList(fight, duration),
        incomingSources = self:BuildIncomingSourceList(fight, duration),
    }
    self:UpdatePersonalBest(self.lastFight)
    if EPC.BossMechanicsAssistant and type(EPC.BossMechanicsAssistant.AttachFightData) == "function" then
        pcall(EPC.BossMechanicsAssistant.AttachFightData, EPC.BossMechanicsAssistant, self.lastFight)
    end
    if EPC.GameModeReport and type(EPC.GameModeReport.OnFightEnded) == "function" then
        pcall(EPC.GameModeReport.OnFightEnded, EPC.GameModeReport, self.lastFight)
    end
    EPC:RequestRefresh("combat-finished")
end

local OnCombatStateImplArch

function C:OnCombatState(...)

    return OnCombatStateImplArch(self, ...)

end

OnCombatStateImplArch = function(self, inCombat)
    if inCombat then
        if not self.inCombat then self:BeginFight() end
    elseif self.inCombat then
        self:EndFight()
    end
end

function C:GetLastFight() return self.lastFight end

function C:ResetLastFight()
    self.lastFight = nil
    EPC:RequestRefresh("combat-reset")
    if EPC.UI and EPC.UI.UpdateCombatHUD then EPC.UI:UpdateCombatHUD(nil) end
end


-- BEGIN ABSORBED: HighDensityCombatPerformanceFix.lua
-- ESO Adventurer Suite
-- v0.29.511 - high-density combat performance guard.
-- Large pulls, Infinite Archive waves and PvP can generate enormous combat-event
-- volume. Keep exact event totals, but reuse expensive character-stat snapshots
-- for a short window instead of recomputing them for every individual hit/heal.

local EPC = ESOProgressionCoach
if not EPC or not EPC.Combat then return end

local C = EPC.Combat
local CACHE_MS = 200

local function nowMs()
    if type(GetFrameTimeMilliseconds) == "function" then
        local ok, value = pcall(GetFrameTimeMilliseconds)
        if ok then return tonumber(value) or 0 end
    end
    if type(GetGameTimeMilliseconds) == "function" then
        local ok, value = pcall(GetGameTimeMilliseconds)
        if ok then return tonumber(value) or 0 end
    end
    return 0
end

if type(C.ReadCombatStatsSnapshot) == "function" and not C._easDensitySnapshotGuard029511 then
    C._easDensitySnapshotGuard029511 = true
    local baseRead = ReadCombatStatsSnapshotImplArch

    ReadCombatStatsSnapshotImplArch = function(self, force)
        if force == true then
            self._easDensitySnapshot029511 = nil
            self._easDensitySnapshotAt029511 = 0
            local snapshot = baseRead(self, true)
            if type(snapshot) == "table" then
                self._easDensitySnapshot029511 = snapshot
                self._easDensitySnapshotAt029511 = nowMs()
            end
            return snapshot
        end

        local stamp = nowMs()
        local cached = self._easDensitySnapshot029511
        local cachedAt = tonumber(self._easDensitySnapshotAt029511) or 0
        if type(cached) == "table" and stamp >= cachedAt and (stamp - cachedAt) < CACHE_MS then
            return cached
        end

        local snapshot = baseRead(self, false)
        if type(snapshot) == "table" then
            self._easDensitySnapshot029511 = snapshot
            self._easDensitySnapshotAt029511 = stamp
        end
        return snapshot
    end
end

local function resetSnapshot(self)
    self._easDensitySnapshot029511 = nil
    self._easDensitySnapshotAt029511 = 0
end

if type(C.BeginFight) == "function" and not C._easDensityBeginWrapped029511 then
    C._easDensityBeginWrapped029511 = true
    local baseBegin = BeginFightImplArch
    BeginFightImplArch = function(self, ...)
        resetSnapshot(self)
        return baseBegin(self, ...)
    end
end

if type(C.EndFight) == "function" and not C._easDensityEndWrapped029511 then
    C._easDensityEndWrapped029511 = true
    local baseEnd = EndFightImplArch
    EndFightImplArch = function(self, ...)
        local result = baseEnd(self, ...)
        resetSnapshot(self)
        return result
    end
end

-- Avoid redundant refresh storms from modules that request the same global Suite
-- refresh repeatedly inside one dense combat frame. Requests are still delivered;
-- identical reasons inside 50 ms are coalesced into one call.
if type(EPC.RequestRefresh) == "function" and not EPC._easDensityRefreshGuard029511 then
    EPC._easDensityRefreshGuard029511 = true
    local baseRequestRefresh = EPC.RequestRefresh
    local lastReason, lastAt = nil, 0

    function EPC:RequestRefresh(reason, ...)
        local stamp = nowMs()
        local key = tostring(reason or "")
        if key ~= "" and key == lastReason and stamp >= lastAt and (stamp - lastAt) < 50 then
            return
        end
        lastReason, lastAt = key, stamp
        return baseRequestRefresh(self, reason, ...)
    end
end

-- END ABSORBED: HighDensityCombatPerformanceFix.lua


-- BEGIN ABSORBED: CombatEndPerformanceFix.lua
-- ESO Adventurer Suite
-- v0.29.565 - combat-end / killing-blow frame performance fix.
-- ESO commonly leaves combat immediately after the final enemy dies. The base
-- Combat:EndFight() performs report sorting/aggregation and downstream report
-- callbacks synchronously, which can hitch the exact frame the enemy dies.
-- Defer that finalization until the player has remained out of combat briefly.

local EPC = ESOProgressionCoach
if not EPC or not EPC.Combat then return end

local C = EPC.Combat
local DEFER_MS = 650
local generation = 0

local function playerInCombat()
    if type(IsUnitInCombat) ~= "function" then return C.inCombat == true end
    local ok, value = pcall(IsUnitInCombat, "player")
    return ok and value == true
end

if type(C.OnCombatState) == "function" and type(C.EndFight) == "function" and not C._easCombatEndDeferred029565 then
    C._easCombatEndDeferred029565 = true

    local baseOnCombatState = OnCombatStateImplArch
    local baseEndFight = EndFightImplArch

    -- Guard the original OnCombatState from invoking EndFight synchronously.
    -- BeginFight remains native/base behavior so combat starts immediately.
    OnCombatStateImplArch = function(self, inCombat)
        generation = generation + 1
        local myGeneration = generation

        if inCombat == true then
            self._easPendingCombatEnd029565 = false
            if not self.inCombat then
                return baseOnCombatState(self, true)
            end
            return
        end

        if not self.inCombat or not self.current then
            self.inCombat = false
            return
        end

        -- Keep the active fight object intact during the short grace window so
        -- combat that resumes immediately continues the same encounter instead
        -- of finalizing/restarting between closely spaced enemies.
        self._easPendingCombatEnd029565 = true

        local function finalizeIfStillIdle()
            if myGeneration ~= generation then return end
            if not self._easPendingCombatEnd029565 then return end
            if playerInCombat() then return end
            self._easPendingCombatEnd029565 = false
            baseEndFight(self)
        end

        if type(zo_callLater) == "function" then
            zo_callLater(finalizeIfStillIdle, DEFER_MS)
        elseif EVENT_MANAGER then
            local key = (EPC.name or "ESOAdventurerSuite") .. "_CombatEnd029565"
            EPC.Runtime:UnregisterUpdate("Combat", "CombatEnd")
            EPC.Runtime:RegisterUpdate("Combat", "CombatEnd", DEFER_MS, function()
                EPC.Runtime:UnregisterUpdate("Combat", "CombatEnd")
                finalizeIfStillIdle()
            end)
        else
            finalizeIfStillIdle()
        end
    end
end

-- END ABSORBED: CombatEndPerformanceFix.lua


-- BEGIN ABSORBED: TrialCombatRecorderPerformanceFix.lua
-- ESO Adventurer Suite
-- v0.29.624 - scalar-only dense-trial combat recorder.
-- Trial combat is gameplay-first: while an 8+ player group is in combat, keep
-- only exact headline totals needed by the HUD/report and stop building detailed
-- combat analytics on the live event path. Detailed ability/target/group/actor
-- tables are intentionally omitted for dense trial fights to protect frame time.

local EPC = ESOProgressionCoach
if not EPC or not EPC.Combat then return end

local C = EPC.Combat
local EM = EVENT_MANAGER
local NAME = (EPC.name or "ESOAdventurerSuite") .. "_TrialRecorderPerf029624"
local state = { groupSize = 0, inCombat = false }

local function nowMs()
    if type(GetFrameTimeMilliseconds) == "function" then
        local ok, value = pcall(GetFrameTimeMilliseconds)
        if ok then return tonumber(value) or 0 end
    end
    if type(GetGameTimeMilliseconds) == "function" then
        local ok, value = pcall(GetGameTimeMilliseconds)
        if ok then return tonumber(value) or 0 end
    end
    return 0
end

local function safeNumber(value, fallback)
    local n = tonumber(value)
    if n == nil then return tonumber(fallback) or 0 end
    return n
end

local function refreshGroupSize()
    if type(GetGroupSize) == "function" then
        local ok, value = pcall(GetGroupSize)
        state.groupSize = ok and math.max(0, tonumber(value) or 0) or 0
    else
        state.groupSize = 0
    end
end

local function refreshCombatState()
    if type(IsUnitInCombat) == "function" then
        local ok, value = pcall(IsUnitInCombat, "player")
        state.inCombat = ok and value == true
    else
        state.inCombat = C.inCombat == true
    end
end

local function denseCombat(self)
    return state.groupSize >= 8
        and state.inCombat == true
        and self ~= nil
        and self.inCombat == true
        and type(self.current) == "table"
end

local function cleanUnitName(value)
    value = tostring(value or "")
    if value == "" then return "You" end
    if type(zo_strformat) == "function" then
        local ok, formatted = pcall(zo_strformat, "<<1>>", value)
        if ok and formatted and formatted ~= "" then value = formatted end
    end
    value = value:gsub("%^%a+", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return value ~= "" and value or "You"
end

local function playerName()
    if type(GetUnitName) == "function" then
        local ok, value = pcall(GetUnitName, "player")
        if ok and value and value ~= "" then return cleanUnitName(value) end
    end
    return "You"
end

local function criticalDamage(result)
    return (ACTION_RESULT_CRITICAL_DAMAGE ~= nil and result == ACTION_RESULT_CRITICAL_DAMAGE)
        or (ACTION_RESULT_DOT_TICK_CRITICAL ~= nil and result == ACTION_RESULT_DOT_TICK_CRITICAL)
end

local function criticalHeal(result)
    return (ACTION_RESULT_CRITICAL_HEAL ~= nil and result == ACTION_RESULT_CRITICAL_HEAL)
        or (ACTION_RESULT_HOT_TICK_CRITICAL ~= nil and result == ACTION_RESULT_HOT_TICK_CRITICAL)
end

local function blockedDamage(result)
    return (ACTION_RESULT_BLOCKED_DAMAGE ~= nil and result == ACTION_RESULT_BLOCKED_DAMAGE)
        or (ACTION_RESULT_BLOCKED ~= nil and result == ACTION_RESULT_BLOCKED)
end

local function dotDamage(result)
    return (ACTION_RESULT_DOT_TICK ~= nil and result == ACTION_RESULT_DOT_TICK)
        or (ACTION_RESULT_DOT_TICK_CRITICAL ~= nil and result == ACTION_RESULT_DOT_TICK_CRITICAL)
end

refreshGroupSize()
refreshCombatState()

if EM then
    if EVENT_GROUP_UPDATE then EPC.Runtime:RegisterEvent("Combat", "TrialGroup", EVENT_GROUP_UPDATE, refreshGroupSize) end
    if EVENT_GROUP_MEMBER_JOINED then EPC.Runtime:RegisterEvent("Combat", "TrialJoin", EVENT_GROUP_MEMBER_JOINED, refreshGroupSize) end
    if EVENT_GROUP_MEMBER_LEFT then EPC.Runtime:RegisterEvent("Combat", "TrialLeft", EVENT_GROUP_MEMBER_LEFT, refreshGroupSize) end
    if EVENT_PLAYER_ACTIVATED then
        EPC.Runtime:RegisterEvent("Combat", "TrialActivated", EVENT_PLAYER_ACTIVATED, function()
            refreshGroupSize()
            refreshCombatState()
        end)
    end
    if EVENT_PLAYER_COMBAT_STATE then
        EPC.Runtime:RegisterEvent("Combat", "TrialCombat", EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
            state.inCombat = inCombat == true
            if not state.inCombat then refreshGroupSize() end
        end)
    end
end

-- Do not build/scan a 12-player actor roster on the combat-start frame in a
-- trial. Dense mode only needs the local identity for headline player totals.
if type(C.BuildActorRoster) == "function" and not C._easTrialRosterPerf029624 then
    C._easTrialRosterPerf029624 = true
    local baseBuildActorRoster = BuildActorRosterImplArch
    BuildActorRosterImplArch = function(self, ...)
        if state.groupSize >= 8 then
            local name = playerName()
            return { players = { [string.lower(name)] = name }, companions = {}, selfName = name }
        end
        return baseBuildActorRoster(self, ...)
    end
end

-- Mark dense fights and keep only one cached player name. The base BeginFight
-- still creates the normal fight object so every downstream report API remains
-- compatible after combat ends.
if type(C.BeginFight) == "function" and not C._easTrialBeginPerf029624 then
    C._easTrialBeginPerf029624 = true
    local baseBeginFight = BeginFightImplArch
    BeginFightImplArch = function(self, ...)
        local result = baseBeginFight(self, ...)
        if type(self.current) == "table" and state.groupSize >= 8 then
            self.current._easTrialPerformance029624 = true
            self.current._easTrialSelfName029624 = playerName()
            -- Dense trial reports intentionally do not collect live detail tables.
            self.current.abilities = {}
            self.current.targets = {}
            self.current.group = {}
            self.current.actors = {}
            self.current.incomingSources = {}
        end
        return result
    end
end

-- A start-of-fight stat snapshot already exists in Combat:BeginFight(). During
-- dense combat do not query character stats again on every hit/heal/incoming hit.
if type(C.AccumulateCombatStats) == "function" and not C._easTrialStatsPerf029624 then
    C._easTrialStatsPerf029624 = true
    local baseAccumulateCombatStats = AccumulateCombatStatsImplArch
    AccumulateCombatStatsImplArch = function(self, eventKind, value, result, ...)
        if denseCombat(self) then return end
        return baseAccumulateCombatStats(self, eventKind, value, result, ...)
    end
end

-- Dense trial hot path: scalar math only. Core's late performance guard also
-- removes GROUP source subscriptions, so this normally receives only the local
-- player, local pet/companion, and incoming-to-player streams.
if type(C.OnCombatEvent) == "function" and not C._easTrialEventPerf029624 then
    C._easTrialEventPerf029624 = true
    local baseOnCombatEvent = OnCombatEventImplArch

    OnCombatEventImplArch = function(self, eventKind, result, abilityName, sourceName, sourceType, targetName, targetType, hitValue, abilityId, sourceUnitId, ...)
        if not denseCombat(self) then
            return baseOnCombatEvent(self, eventKind, result, abilityName, sourceName, sourceType, targetName, targetType, hitValue, abilityId, sourceUnitId, ...)
        end

        local fight = self.current
        local value = tonumber(hitValue) or 0
        if value <= 0 then return end

        if eventKind == "INCOMING_DAMAGE" then
            fight.incomingDamage = (tonumber(fight.incomingDamage) or 0) + value
            fight.incomingHits = (tonumber(fight.incomingHits) or 0) + 1
            if blockedDamage(result) then fight.blockedHits = (tonumber(fight.blockedHits) or 0) + 1 end
            return
        end

        local isDamage = eventKind == "DAMAGE"
        local isHeal = eventKind == "HEAL"
        if not isDamage and not isHeal then return end

        local playerType = rawget(_G, "COMBAT_UNIT_TYPE_PLAYER")
        local petType = rawget(_G, "COMBAT_UNIT_TYPE_PLAYER_PET")
        local companionType = rawget(_G, "COMBAT_UNIT_TYPE_PLAYER_COMPANION")

        if companionType ~= nil and sourceType == companionType then
            if isDamage then fight.companionDamage = (tonumber(fight.companionDamage) or 0) + value
            else fight.companionHealing = (tonumber(fight.companionHealing) or 0) + value end
            return
        end

        if petType ~= nil and sourceType == petType then
            if isDamage then fight.petDamage = (tonumber(fight.petDamage) or 0) + value
            else fight.petHealing = (tonumber(fight.petHealing) or 0) + value end
            return
        end

        -- Core registers the local player's own stream as COMBAT_UNIT_TYPE_PLAYER.
        -- Never do name normalization/ownership lookup on the dense hot path.
        if playerType == nil or sourceType ~= playerType then return end

        if isDamage then
            fight.totalDamage = (tonumber(fight.totalDamage) or 0) + value
            fight.hits = (tonumber(fight.hits) or 0) + 1
            if criticalDamage(result) then fight.criticalHits = (tonumber(fight.criticalHits) or 0) + 1 end
            if dotDamage(result) then
                fight.dotDamage = (tonumber(fight.dotDamage) or 0) + value
            else
                fight.directDamage = (tonumber(fight.directDamage) or 0) + value
            end
        else
            fight.totalHealing = (tonumber(fight.totalHealing) or 0) + value
            fight.healEvents = (tonumber(fight.healEvents) or 0) + 1
            if criticalHeal(result) then fight.criticalHeals = (tonumber(fight.criticalHeals) or 0) + 1 end
        end
    end
end

-- While dense combat is active, never build/sort the detailed live report. The
-- compact scalar snapshot is enough for any HUD consumer that explicitly asks.
if type(C.GetDisplayFight) == "function" and not C._easTrialDisplayPerf029624 then
    C._easTrialDisplayPerf029624 = true
    local baseGetDisplayFight = GetDisplayFightImplArch
    GetDisplayFightImplArch = function(self, ...)
        if not denseCombat(self) then return baseGetDisplayFight(self, ...) end
        local fight = self.current
        local summary = self:GetLiveSummary() or {}
        local duration = math.max(0.1, safeNumber(summary.duration, 0.1))
        return {
            live = true,
            trialPerformanceMode = true,
            duration = duration,
            totalDamage = safeNumber(fight.totalDamage, 0), dps = safeNumber(summary.dps, 0),
            directDamage = safeNumber(fight.directDamage, 0), dotDamage = safeNumber(fight.dotDamage, 0),
            dotPercent = safeNumber(fight.totalDamage, 0) > 0 and (safeNumber(fight.dotDamage, 0) / safeNumber(fight.totalDamage, 1) * 100) or 0,
            petDamage = safeNumber(fight.petDamage, 0), petDps = safeNumber(summary.petDps, 0),
            companionDamage = safeNumber(fight.companionDamage, 0), companionDps = safeNumber(summary.companionDps, 0),
            combinedDamage = safeNumber(summary.combinedDamage, 0), combinedDps = safeNumber(summary.combinedDps, 0),
            hits = safeNumber(fight.hits, 0), criticalHits = safeNumber(fight.criticalHits, 0),
            criticalEventPercent = safeNumber(summary.criticalEventPercent, 0),
            totalHealing = safeNumber(fight.totalHealing, 0), hps = safeNumber(summary.hps, 0),
            petHealing = safeNumber(fight.petHealing, 0), companionHealing = safeNumber(fight.companionHealing, 0),
            combinedHealing = safeNumber(summary.combinedHealing, 0),
            healEvents = safeNumber(fight.healEvents, 0), criticalHeals = safeNumber(fight.criticalHeals, 0),
            criticalHealPercent = safeNumber(summary.criticalHealPercent, 0),
            incomingDamage = safeNumber(fight.incomingDamage, 0), dtps = safeNumber(summary.dtps, 0),
            incomingHits = safeNumber(fight.incomingHits, 0), blockedHits = safeNumber(fight.blockedHits, 0),
            blockPercent = safeNumber(summary.blockPercent, 0),
            targetCount = 0,
            targets = {}, abilities = {}, contributors = {}, actors = {}, effects = {}, incomingSources = {},
            combatStats = type(fight.statTracking) == "table" and (fight.statTracking.last or {}) or {},
            resources = type(self.BuildResourceStats) == "function" and self:BuildResourceStats(fight, duration) or {},
        }
    end
end

-- Game Combat is a post-fight analysis window. During an active dense trial,
-- freeze it completely even if it was left open. The normal combat-end refresh
-- repopulates it once gameplay pressure is gone.
local R = EPC.GameModeReport
if type(R) == "table" and type(R.Refresh) == "function" and not R._easTrialRefreshPerf029624 then
    R._easTrialRefreshPerf029624 = true
    local baseReportRefresh = R.Refresh
    function R:Refresh(...)
        if state.groupSize >= 8 and state.inCombat then return end
        return baseReportRefresh(self, ...)
    end
end

-- END ABSORBED: TrialCombatRecorderPerformanceFix.lua
