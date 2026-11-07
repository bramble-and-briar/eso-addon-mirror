--[[
    LibFights - Sets
    Every item set in the game (via the Item Set Collection API, plus LibSets when it is
    installed), set info and bonuses, equipped-set detection, per-set logging
    configuration, set <-> proc-ability association and per-fight set tracking.
]]

local LF = LibFights
local Util, Const = LF.Util, LF.Const
local Sets = {}
LF.Sets = Sets

local Try = Util.Try

local allSetIds = nil         -- array of setIds (lazy)
local setInfoCache = {}       -- setId -> info
local setLinkCache = {}       -- setId -> sample item link
local nameToSet = nil         -- normalized name -> setId (lazy)
local abilityToSet = {}       -- abilityId -> setId | false (cache of name matching)

local function S() return LF.GetSettings() end

-- ---------------------------------------------------------------------------
-- Enumerating every set
-- ---------------------------------------------------------------------------
function Sets.GetAllSetIds(forceRefresh)
    if allSetIds and not forceRefresh then return allSetIds end
    local seen, list = {}, {}
    -- 1) Item set collections (covers virtually every set in the game)
    if type(GetNextItemSetCollectionId) == "function" then
        local id = GetNextItemSetCollectionId()
        local guard = 0
        while id and id ~= 0 and guard < 5000 do
            if not seen[id] then seen[id] = true; list[#list + 1] = id end
            id = GetNextItemSetCollectionId(id)
            guard = guard + 1
        end
    end
    -- 2) LibSets (optional) fills any gaps
    if LibSets and type(LibSets.GetAllSetIds) == "function" then
        local t = Try(LibSets.GetAllSetIds)
        if type(t) == "table" then
            for k, v in pairs(t) do
                -- supports both { [setId] = true } and { setId, setId, ... }
                local id
                if v == true and type(k) == "number" then id = k
                elseif type(v) == "number" then id = v end
                if id and not seen[id] then seen[id] = true; list[#list + 1] = id end
            end
        end
    end
    table.sort(list)
    allSetIds = list
    nameToSet = nil
    return list
end

function Sets.GetSetName(setId)
    local name = Try(GetItemSetName, setId)
    if (not name or name == "") and LibSets and LibSets.GetSetName then
        name = Try(LibSets.GetSetName, setId)
    end
    return Util.Fmt(name or "")
end

-- An item link for one piece of the set (needed to read bonus text)
function Sets.GetSampleLink(setId)
    local cached = setLinkCache[setId]
    if cached ~= nil then return cached or nil end
    local link
    local numPieces = Try(GetNumItemSetCollectionPieces, setId) or 0
    for i = 1, numPieces do
        local pieceId = Try(GetItemSetCollectionPieceInfo, setId, i)
        if pieceId then
            link = Try(GetItemSetCollectionPieceItemLink, pieceId, LINK_STYLE_DEFAULT, ITEM_TRAIT_TYPE_NONE)
            if link and link ~= "" then break end
            link = nil
        end
    end
    if not link and LibSets and LibSets.GetSetFirstItemId then
        local itemId = Try(LibSets.GetSetFirstItemId, setId)
        if itemId then
            link = string.format("|H1:item:%d:364:50:0:0:0:0:0:0:0:0:0:0:0:0:1:0:0:0:10000:0|h|h", itemId)
        end
    end
    setLinkCache[setId] = link or false
    return link
end

-- Full info: name, type, pieces, max equipped, every bonus (with perfected flags)
function Sets.GetSetInfo(setId, forceRefresh)
    setId = tonumber(setId)
    if not setId then return nil end
    if setInfoCache[setId] and not forceRefresh then return setInfoCache[setId] end
    local name = Sets.GetSetName(setId)
    if name == "" then return nil end
    local info = { setId = setId, name = name, bonuses = {} }
    info.setType = Try(GetItemSetType, setId)
    info.setTypeName = (info.setType and Const.SET_TYPE_NAME[info.setType]) or "UNKNOWN"
    info.numCollectionPieces = Try(GetNumItemSetCollectionPieces, setId) or 0
    info.unperfectedSetId = Try(GetItemSetUnperfectedSetId, setId)
    if info.unperfectedSetId == 0 then info.unperfectedSetId = nil end
    local link = Sets.GetSampleLink(setId)
    info.sampleLink = link
    if link then
        local hasSet, _, numBonuses, _, maxEquipped = GetItemLinkSetInfo(link, false)
        if hasSet then
            info.numBonuses = numBonuses or 0
            info.maxEquipped = maxEquipped or 0
            for i = 1, info.numBonuses do
                local numRequired, description, isPerfected = GetItemLinkSetBonusInfo(link, false, i)
                info.bonuses[#info.bonuses + 1] = {
                    numRequired = numRequired, description = description or "", isPerfected = isPerfected and true or false,
                }
            end
        end
    end
    setInfoCache[setId] = info
    return info
end

local function BuildNameMap()
    -- GetAllSetIds() resets nameToSet on its first run, so fill a local map and assign it last
    local ids = Sets.GetAllSetIds()
    local map = {}
    for _, setId in ipairs(ids) do
        local n = Util.NormalizeName(Sets.GetSetName(setId))
        if n ~= "" and not map[n] then map[n] = setId end
    end
    nameToSet = map
    return map
end

function Sets.FindSetByName(name)
    if not nameToSet then BuildNameMap() end
    return nameToSet[Util.NormalizeName(name)]
end

-- text: name fragment or numeric setId
function Sets.Search(text, maxResults)
    maxResults = maxResults or 50
    local results = {}
    text = Util.Trim(text or "")
    if text == "" then return results end
    local asNumber = tonumber(text)
    if asNumber then
        local info = Sets.GetSetInfo(asNumber)
        if info then results[1] = info end
        return results
    end
    local needle = Util.Lower(text)
    for _, setId in ipairs(Sets.GetAllSetIds()) do
        local name = Sets.GetSetName(setId)
        if Util.Contains(name, needle) then
            results[#results + 1] = { setId = setId, name = name }
            if #results >= maxResults then break end
        end
    end
    for i = 1, #results do
        results[i] = Sets.GetSetInfo(results[i].setId) or results[i]
    end
    return results
end

-- ---------------------------------------------------------------------------
-- Equipped sets
-- ---------------------------------------------------------------------------
function Sets.GetEquippedSets()
    local result = {}
    local activePair = Try(GetActiveWeaponPairInfo) or Const.WEAPON_PAIR_MAIN
    for _, slot in ipairs(Const.EQUIP_SLOTS) do
        local link = GetItemLink(BAG_WORN, slot.id)
        if link and link ~= "" then
            local hasSet, setName, numBonuses, numEquipped, maxEquipped, setId, numPerfected = GetItemLinkSetInfo(link, true)
            if hasSet and setId then
                local e = result[setId]
                if not e then
                    e = {
                        setId = setId, name = Util.Fmt(setName), numBonuses = numBonuses or 0,
                        equipped = numEquipped or 0, perfected = numPerfected or 0, maxEquipped = maxEquipped or 0,
                        slots = {}, activeBonuses = {}, inactiveBonuses = {}, sampleLink = link,
                    }
                    for i = 1, e.numBonuses do
                        local numRequired, desc, isPerfected = GetItemLinkSetBonusInfo(link, true, i)
                        local have = isPerfected and (e.perfected or 0) or (e.equipped or 0)
                        local bonus = { numRequired = numRequired, description = desc or "", isPerfected = isPerfected and true or false }
                        if have >= (numRequired or 99) then
                            e.activeBonuses[#e.activeBonuses + 1] = bonus
                        else
                            e.inactiveBonuses[#e.inactiveBonuses + 1] = bonus
                        end
                    end
                    result[setId] = e
                end
                local onInactiveBar = slot.isWeapon and ((slot.isBackup and activePair == Const.WEAPON_PAIR_MAIN) or ((not slot.isBackup) and activePair == Const.WEAPON_PAIR_BACKUP))
                e.slots[#e.slots + 1] = { slot = slot.id, slotName = slot.name, inactiveBar = onInactiveBar and true or false }
            end
        end
    end
    for _, e in pairs(result) do
        e.fullBonus = e.maxEquipped > 0 and (e.equipped >= e.maxEquipped)
    end
    return result
end

-- ---------------------------------------------------------------------------
-- Logging configuration ("every set is loggable")
-- ---------------------------------------------------------------------------
function Sets.IsSetLogged(setId)
    local s = S()
    if s.logAllSets then return true end
    return s.loggedSets and s.loggedSets[setId] and true or false
end

function Sets.SetSetLogged(setId, enabled)
    local s = S()
    s.loggedSets = s.loggedSets or {}
    s.loggedSets[setId] = enabled and true or nil
end

function Sets.SetLogAllSets(enabled)
    S().logAllSets = enabled and true or false
end

function Sets.GetLoggedSetIds()
    local s = S()
    if s.logAllSets then return Sets.GetAllSetIds() end
    local list = {}
    for id in pairs(s.loggedSets or {}) do list[#list + 1] = id end
    table.sort(list)
    return list
end

-- ---------------------------------------------------------------------------
-- Set <-> ability association (proc ids)
-- ---------------------------------------------------------------------------
-- Manually register an ability id that belongs to a set (persisted in SavedVariables).
function Sets.RegisterSetAbility(setId, abilityId)
    local sv = LF.sv
    if sv then
        sv.setAbilityRegistry = sv.setAbilityRegistry or {}
        sv.setAbilityRegistry[abilityId] = setId
    end
    Sets._runtimeRegistry = Sets._runtimeRegistry or {}
    Sets._runtimeRegistry[abilityId] = setId
    abilityToSet[abilityId] = setId
end

function Sets.UnregisterSetAbility(abilityId)
    if LF.sv and LF.sv.setAbilityRegistry then LF.sv.setAbilityRegistry[abilityId] = nil end
    if Sets._runtimeRegistry then Sets._runtimeRegistry[abilityId] = nil end
    abilityToSet[abilityId] = nil
end

function Sets.GetRegisteredAbilities(setId)
    local out = {}
    local function scanReg(reg)
        for abilityId, sid in pairs(reg or {}) do
            if sid == setId then out[abilityId] = true end
        end
    end
    scanReg(LF.sv and LF.sv.setAbilityRegistry)
    scanReg(Sets._runtimeRegistry)
    local list = {}
    for id in pairs(out) do list[#list + 1] = id end
    table.sort(list)
    return list
end

-- Returns setId for an ability (registry first, then name matching), or nil.
-- fight (optional): its equipped sets are matched loosely (substring) first.
function Sets.GetSetForAbility(abilityId, abilityName, fight)
    local reg = (Sets._runtimeRegistry and Sets._runtimeRegistry[abilityId]) or (LF.sv and LF.sv.setAbilityRegistry and LF.sv.setAbilityRegistry[abilityId])
    if reg then return reg end

    if fight and fight.sets then
        fight._setMatch = fight._setMatch or {}
        local m = fight._setMatch[abilityId]
        if m ~= nil then return m or nil end
        local norm = Util.NormalizeName(abilityName ~= "" and abilityName or GetAbilityName(abilityId))
        if norm ~= "" then
            for setId, s in pairs(fight.sets) do
                local sn = s._norm or Util.NormalizeName(s.name)
                s._norm = sn
                if sn ~= "" and (norm == sn or (#sn >= 5 and norm:find(sn, 1, true))) then
                    fight._setMatch[abilityId] = setId
                    return setId
                end
            end
        end
        fight._setMatch[abilityId] = false
    end

    local cached = abilityToSet[abilityId]
    if cached ~= nil then return cached or nil end
    local name = abilityName
    if not name or name == "" then name = GetAbilityName(abilityId) end
    local setId = (name and name ~= "") and Sets.FindSetByName(name) or nil
    abilityToSet[abilityId] = setId or false
    return setId
end

-- ---------------------------------------------------------------------------
-- Per-fight set tracking (called by the logger only while logging)
-- ---------------------------------------------------------------------------
local function NewFightSet(setId, name)
    return {
        setId = setId, name = name, equippedInFight = false, equipped = 0, perfected = 0, maxEquipped = 0,
        fullBonus = false, activeBonuses = {}, damage = 0, healing = 0, hits = 0, activations = 0,
        abilities = {}, uptimeMs = 0, uptimePct = 0, damageSharePct = 0, healingSharePct = 0,
    }
end

function Sets.BeginTracking(fight)
    fight.sets = {}
    local equipped = (fight.build and fight.build.sets) or Sets.GetEquippedSets()
    for setId, e in pairs(equipped) do
        if Sets.IsSetLogged(setId) then
            local s = NewFightSet(setId, e.name)
            s.equippedInFight = true
            s.equipped, s.perfected, s.maxEquipped = e.equipped, e.perfected, e.maxEquipped
            s.fullBonus = e.fullBonus
            s.activeBonuses = e.activeBonuses
            fight.sets[setId] = s
        end
    end
end

-- cat: "damage" | "heal" | "effect"
function Sets.Attribute(fight, abilityId, abilityName, cat, amount, isActivation)
    if not fight.sets then return end
    local setId = Sets.GetSetForAbility(abilityId, abilityName, fight)
    if not setId or not Sets.IsSetLogged(setId) then return nil end
    local s = fight.sets[setId]
    if not s then
        s = NewFightSet(setId, Sets.GetSetName(setId))
        fight.sets[setId] = s
    end
    s.abilities[abilityId] = true
    if cat == "damage" then
        s.damage = s.damage + (amount or 0); s.hits = s.hits + 1
    elseif cat == "heal" then
        s.healing = s.healing + (amount or 0); s.hits = s.hits + 1
    end
    if isActivation then s.activations = s.activations + 1 end
    return setId
end

function Sets.FinishTracking(fight)
    if not fight.sets then return end
    local durMs = math.max(1, fight:GetDurationMs())
    local totalDamage = fight.totals.damageOut
    local totalHeal = fight.totals.healOut
    for _, s in pairs(fight.sets) do
        local best = 0
        for abilityId in pairs(s.abilities) do
            local e = fight.effects.player[abilityId]
            if e and e.uptimeMs > best then best = e.uptimeMs end
            for _, te in pairs(fight.effects.target) do
                if te.id == abilityId and te.uptimeMs > best then best = te.uptimeMs end
            end
        end
        s.uptimeMs = best
        s.uptimePct = best / durMs
        s.damageSharePct = Util.SafeDiv(s.damage, totalDamage)
        s.healingSharePct = Util.SafeDiv(s.healing, totalHeal)
        s.activationsPerMinute = s.activations / (durMs / 60000)
        local list = {}
        for id in pairs(s.abilities) do list[#list + 1] = id end
        s.abilityIds = list
    end
end
