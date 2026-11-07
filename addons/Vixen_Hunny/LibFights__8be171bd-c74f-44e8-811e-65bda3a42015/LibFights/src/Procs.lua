--[[
    LibFights - Procs
    Detects and tracks proc activations while logging:
      * damage / heal from abilities that are NOT on your bars (set procs, passives,
        weapon/armor enchants, mythics, ...)
      * buffs gained on you and debuffs you apply that do not come from slotted skills
    Every proc is linked to an item set when possible (registry or name match).

    Per proc: activations, hits, damage, healing, procs/minute, average and minimum gap
    between activations (minimum gap = estimated internal cooldown), timestamps.
]]

local LF = LibFights
local Util, Const = LF.Util, LF.Const
local Procs = {}
LF.Procs = Procs

local function S() return LF.GetSettings() end
local MAX_TIMES = 120

function Procs.BeginTracking(fight)
    fight.procs = {}
    fight._procLast = {}
    fight._slottedIds, fight._slottedNames = LF.Build.GetSlottedLookup(fight.build)
end

local function IsWeaponAttack(slotType)
    return (Const.SLOT_TYPE_LIGHT and slotType == Const.SLOT_TYPE_LIGHT) or (Const.SLOT_TYPE_HEAVY and slotType == Const.SLOT_TYPE_HEAVY)
end

local function IsSlotted(fight, abilityId, name)
    if fight._slottedIds and fight._slottedIds[abilityId] then return true end
    if fight._slottedNames and name and name ~= "" and fight._slottedNames[Util.Lower(name)] then return true end
    return false
end

local function GetProc(fight, abilityId, name, icon, source)
    local p = fight.procs[abilityId]
    if not p then
        local info = LF.Abilities.GetInfo(abilityId)
        p = {
            id = abilityId, name = (name and name ~= "") and Util.CleanAbilityName(name) or (info and info.name) or ("#" .. abilityId),
            icon = (icon and icon ~= "") and icon or (info and info.icon) or "",
            kind = "candidate", setId = nil, setName = nil, sources = {},
            activations = 0, hits = 0, damage = 0, healing = 0,
            firstMs = nil, lastMs = nil, minGapMs = nil, gapSum = 0, gapCount = 0, times = {},
            external = false,
        }
        local setId = LF.Sets.GetSetForAbility(abilityId, p.name, fight)
        if setId then
            p.kind = "set"
            p.setId = setId
            p.setName = LF.Sets.GetSetName(setId)
        end
        fight.procs[abilityId] = p
    end
    p.sources[source] = true
    return p
end

local function Activate(fight, p, now)
    if p.lastMs then
        local gap = now - p.lastMs
        p.gapSum = p.gapSum + gap
        p.gapCount = p.gapCount + 1
        if not p.minGapMs or gap < p.minGapMs then p.minGapMs = gap end
    end
    if not p.firstMs then p.firstMs = now end
    p.lastMs = now
    p.activations = p.activations + 1
    if #p.times < MAX_TIMES then p.times[#p.times + 1] = now - fight.startMs end
    if p.setId then LF.Sets.Attribute(fight, p.id, p.name, "effect", 0, true) end
    LF.FireCallback(LF.EVENTS.PROC, fight, p)
end

-- Outgoing damage / heal
function Procs.ObserveCombat(fight, cat, result, abilityId, abilityName, slotType, hit, now)
    if cat ~= "damage" and cat ~= "heal" then return end
    if IsWeaponAttack(slotType) then return end
    -- set attribution happens for everything (even slotted skills that share a set name)
    LF.Sets.Attribute(fight, abilityId, abilityName, cat, hit, false)
    if IsSlotted(fight, abilityId, abilityName) then return end
    local p = GetProc(fight, abilityId, abilityName, nil, cat)
    p.hits = p.hits + 1
    if cat == "damage" then p.damage = p.damage + hit else p.healing = p.healing + hit end
    local last = fight._procLast[abilityId]
    if not last or (now - last) > (S().procMergeMs or 600) then
        Activate(fight, p, now)
    end
    fight._procLast[abilityId] = now
end

-- Effects: scope "player" (buffs on you) or "target" (debuffs on enemies)
function Procs.ObserveEffect(fight, scope, changeType, abilityId, effectName, iconName, sourceType, now)
    if changeType ~= Const.EFFECT_GAINED then return end
    local mine = Const.IsPlayerOrPet(sourceType)
    if scope == "target" and not mine then return end
    if IsSlotted(fight, abilityId, effectName) then return end
    local setId = LF.Sets.GetSetForAbility(abilityId, effectName, fight)
    -- buffs cast by other players only count when they belong to a set (e.g. group-support sets)
    if not mine and not setId then return end
    local p = GetProc(fight, abilityId, effectName, iconName, "effect")
    if not mine then p.external = true end
    local last = fight._procLast[abilityId]
    if not last or (now - last) > (S().procMergeMs or 600) then
        Activate(fight, p, now)
    end
    fight._procLast[abilityId] = now
end

function Procs.FinishTracking(fight)
    local minutes = math.max(1 / 60, fight:GetDurationSec() / 60)
    local uptimes = {}
    for _, e in ipairs(fight:GetEffectUptimes("player")) do uptimes[e.id] = e end
    for _, e in ipairs(fight:GetEffectUptimes("target", true)) do
        if not uptimes[e.id] or e.uptimeMs > uptimes[e.id].uptimeMs then uptimes[e.id] = e end
    end
    for _, p in pairs(fight.procs) do
        p.perMinute = p.activations / minutes
        p.avgGapMs = Util.SafeDiv(p.gapSum, p.gapCount)
        p.estimatedCooldownMs = (p.activations >= 3) and p.minGapMs or nil
        local u = uptimes[p.id]
        if u then p.uptimeMs = u.uptimeMs; p.uptimePct = u.uptimePct end
        p.damageSharePct = Util.SafeDiv(p.damage, fight.totals.damageOut)
        local list = {}
        for k in pairs(p.sources) do list[#list + 1] = k end
        p.sourceList = table.concat(list, ",")
    end
end
