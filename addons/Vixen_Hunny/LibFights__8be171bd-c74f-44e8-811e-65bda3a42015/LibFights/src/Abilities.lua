--[[
    LibFights - Abilities
    Ability info (name, icon / UI graphic, description, durations, cast info, cost,
    range, radius...), ability-ID index, on-demand ability-ID scanner and searching.

    None of this registers combat events; it only queries the game API on demand.
]]

local LF = LibFights
local Util = LF.Util
local Abilities = {}
LF.Abilities = Abilities

local Try = Util.Try
local slower, sfind = string.lower, string.find

local cache = {}          -- abilityId -> info table
local index = {}          -- abilityId -> lower-case name (search index)
local indexCount = 0

-- ---------------------------------------------------------------------------
-- Existence / basic info
-- ---------------------------------------------------------------------------
function Abilities.Exists(abilityId)
    abilityId = tonumber(abilityId)
    if not abilityId or abilityId <= 0 then return false end
    if type(DoesAbilityExist) == "function" then
        return DoesAbilityExist(abilityId) and true or false
    end
    local n = GetAbilityName(abilityId)
    return n ~= nil and n ~= ""
end

function Abilities.Index(abilityId, name)
    if not abilityId or not name or name == "" then return end
    if not index[abilityId] then indexCount = indexCount + 1 end
    index[abilityId] = slower(name)
end

function Abilities.GetName(abilityId)
    local info = Abilities.GetInfo(abilityId)
    return info and info.name or ""
end

function Abilities.GetIcon(abilityId)
    local info = Abilities.GetInfo(abilityId)
    return info and info.icon or ""
end

function Abilities.GetIconMarkup(abilityId, size)
    return Util.IconMarkup(Abilities.GetIcon(abilityId), size or 24)
end

-- Full info table (cached). Every optional API is wrapped so API changes never error.
function Abilities.GetInfo(abilityId, forceRefresh)
    abilityId = tonumber(abilityId)
    if not abilityId then return nil end
    local c = cache[abilityId]
    if c and not forceRefresh then return c end
    if not Abilities.Exists(abilityId) then return nil end

    local info = { id = abilityId }
    info.rawName = GetAbilityName(abilityId) or ""
    info.name = Util.CleanAbilityName(info.rawName)
    info.icon = GetAbilityIcon(abilityId) or ""
    info.iconMarkup = Util.IconMarkup(info.icon, 24)
    info.description = Try(GetAbilityDescription, abilityId) or ""
    info.descriptionHeader = Try(GetAbilityDescriptionHeader, abilityId) or ""
    info.durationMs = Try(GetAbilityDuration, abilityId) or 0

    local isChanneled, castTime, channelTime = Try(GetAbilityCastInfo, abilityId)
    info.isChanneled = isChanneled and true or false
    info.castTimeMs = castTime or 0
    info.channelTimeMs = channelTime or 0

    local minRange, maxRange = Try(GetAbilityRange, abilityId)
    info.minRange, info.maxRange = minRange or 0, maxRange or 0
    info.radius = Try(GetAbilityRadius, abilityId) or 0
    info.angleDistance = Try(GetAbilityAngleDistance, abilityId) or 0
    info.targetDescription = Try(GetAbilityTargetDescription, abilityId) or ""
    info.isPassive = Try(IsAbilityPassive, abilityId) and true or false
    info.isPermanent = Try(IsAbilityPermanent, abilityId) and true or false

    -- Cost: newer API uses GetAbilityBaseCostInfo, older GetAbilityCost
    local cost, mechanic, perTick = Try(GetAbilityBaseCostInfo, abilityId)
    if cost == nil then cost, mechanic = Try(GetAbilityCost, abilityId) end
    info.cost = cost or 0
    info.costMechanic = mechanic
    info.costIsPerTick = perTick and true or false

    cache[abilityId] = info
    Abilities.Index(abilityId, info.name)
    return info
end

function Abilities.ClearCache()
    cache = {}
end

function Abilities.GetCachedCount()
    return Util.Count(cache)
end

-- ---------------------------------------------------------------------------
-- Search
-- ---------------------------------------------------------------------------
-- text: name fragment or numeric id. Returns array of info tables.
function Abilities.Search(text, maxResults)
    maxResults = maxResults or 50
    local results = {}
    text = Util.Trim(text or "")
    if text == "" then return results end

    local asNumber = tonumber(text)
    if asNumber then
        local info = Abilities.GetInfo(asNumber)
        if info then results[1] = info end
        return results
    end

    local needle = slower(text)
    -- make sure everything we've cached is in the index
    for id, info in pairs(cache) do
        if not index[id] then Abilities.Index(id, info.name) end
    end
    local ids = {}
    for id, lname in pairs(index) do
        if sfind(lname, needle, 1, true) then ids[#ids + 1] = id end
    end
    table.sort(ids, function(a, b)
        local la, lb = index[a], index[b]
        local ea, eb = la == needle, lb == needle
        if ea ~= eb then return ea end
        if #la ~= #lb then return #la < #lb end
        return a < b
    end)
    for i = 1, math.min(#ids, maxResults) do
        local info = Abilities.GetInfo(ids[i])
        if info then results[#results + 1] = info end
    end
    return results
end

function Abilities.GetIndexCount()
    return indexCount
end

function Abilities.GetKnownAbilityIds()
    local ids = {}
    for id in pairs(index) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end

-- ---------------------------------------------------------------------------
-- Ability-ID scanner (on demand, spread over frames so it never hitches)
-- ---------------------------------------------------------------------------
local SCAN_NS = "LibFights_AbilityScan"
local scan = { running = false }

local function FinishScan()
    EVENT_MANAGER:UnregisterForUpdate(SCAN_NS)
    scan.running = false
    scan.endMs = Util.Now()
    local p = Abilities.GetScanProgress()
    LF.FireCallback(LF.EVENTS.SCAN_DONE, p)
    if scan.onDone then Try(scan.onDone, p) end
end

local function ScanStep()
    if not scan.running then return end
    local last = math.min(scan.nextId + scan.perFrame - 1, scan.toId)
    local exists = DoesAbilityExist
    for id = scan.nextId, last do
        if (not exists) or exists(id) then
            local n = GetAbilityName(id)
            if n and n ~= "" then
                Abilities.Index(id, Util.CleanAbilityName(n))
                scan.found = scan.found + 1
            end
        end
    end
    scan.nextId = last + 1
    if scan.nextId - scan.lastReport >= scan.reportEvery then
        scan.lastReport = scan.nextId
        local p = Abilities.GetScanProgress()
        LF.FireCallback(LF.EVENTS.SCAN_PROGRESS, p)
        if scan.onProgress then Try(scan.onProgress, p) end
    end
    if scan.nextId > scan.toId then FinishScan() end
end

-- opts: fromId (1), toId (260000), perFrame (1500 PC / 600 console), onProgress(p), onDone(p)
function Abilities.StartScan(opts)
    if scan.running then return false, "scan already running" end
    opts = opts or {}
    scan.running = true
    scan.fromId = opts.fromId or 1
    scan.toId = opts.toId or 260000
    scan.nextId = scan.fromId
    scan.perFrame = opts.perFrame or (LF.isConsole and 600 or 1500)
    scan.found = 0
    scan.startMs = Util.Now()
    scan.endMs = nil
    scan.reportEvery = opts.reportEvery or 10000
    scan.lastReport = scan.fromId
    scan.onProgress = opts.onProgress
    scan.onDone = opts.onDone
    EVENT_MANAGER:RegisterForUpdate(SCAN_NS, 0, ScanStep)
    return true
end

function Abilities.StopScan()
    if not scan.running then return false end
    FinishScan()
    return true
end

function Abilities.IsScanRunning()
    return scan.running
end

function Abilities.GetScanProgress()
    if not scan.fromId then return { running = false, found = 0, pct = 0, indexed = indexCount } end
    local span = math.max(1, scan.toId - scan.fromId + 1)
    local done = math.min(span, (scan.nextId or scan.fromId) - scan.fromId)
    return {
        running = scan.running, fromId = scan.fromId, toId = scan.toId, nextId = scan.nextId,
        found = scan.found, pct = done / span, indexed = indexCount,
        elapsedMs = (scan.endMs or Util.Now()) - (scan.startMs or Util.Now()),
    }
end

-- ---------------------------------------------------------------------------
-- The player's own skills (every skill line, morphs, passives)
-- ---------------------------------------------------------------------------
-- includeUnpurchased: also list skills you have not bought yet
function Abilities.GetPlayerSkillAbilities(includeUnpurchased)
    local list = {}
    local numTypes = Try(GetNumSkillTypes) or 0
    for skillType = 1, numTypes do
        local numLines = Try(GetNumSkillLines, skillType) or 0
        for lineIndex = 1, numLines do
            local lineId = Try(GetSkillLineId, skillType, lineIndex)
            local lineName = (lineId and Try(GetSkillLineNameById, lineId)) or Try(GetSkillLineInfo, skillType, lineIndex) or ""
            lineName = Util.Fmt(lineName)
            local numAbilities = Try(GetNumSkillAbilities, skillType, lineIndex) or 0
            for abilityIndex = 1, numAbilities do
                local name, icon, earnedRank, passive, ultimate, purchased, progressionIndex, rank = Try(GetSkillAbilityInfo, skillType, lineIndex, abilityIndex)
                if name and (purchased or includeUnpurchased) then
                    local abilityId = Try(GetSkillAbilityId, skillType, lineIndex, abilityIndex, false)
                    if abilityId and abilityId > 0 then
                        local entry = {
                            abilityId = abilityId, name = Util.CleanAbilityName(name), icon = icon,
                            passive = passive and true or false, ultimate = ultimate and true or false,
                            purchased = purchased and true or false, rank = rank, earnedRank = earnedRank,
                            progressionIndex = progressionIndex,
                            skillType = skillType, skillLineIndex = lineIndex, skillLineId = lineId, skillLine = lineName,
                        }
                        list[#list + 1] = entry
                        Abilities.Index(abilityId, entry.name)
                    end
                end
            end
        end
    end
    return list
end

-- Indexes the player's skills so they are searchable without a full ID scan.
function Abilities.IndexPlayerSkills()
    local list = Abilities.GetPlayerSkillAbilities(true)
    return #list
end
