-- Tamriel Progress Map: live combination-fragment view.
-- No fragment total is hard-coded; every group is derived from the current API.

RaccoonFragmentData = RaccoonFragmentData or {}
local RFD = RaccoonFragmentData

RFD.VERSION = "1.0.0"
RFD._summaryCache = nil

local function PositiveNumber(value)
    value = tonumber(value)
    return value and value > 0 and value or nil
end

local function IsUnlocked(collectibleId)
    if not collectibleId or type(_G.IsCollectibleUnlocked) ~= "function" then return false end
    return _G.IsCollectibleUnlocked(collectibleId) == true
end

local function GetCollectiblePresentation(collectibleId)
    if type(_G.GetCollectibleInfo) ~= "function" then
        return tostring(collectibleId or "?"), ""
    end
    local name, _, icon = _G.GetCollectibleInfo(collectibleId)
    return tostring(name or collectibleId or "?"), tostring(icon or "")
end

function RFD:InvalidateCache()
    self._summaryCache = nil
end

local function ReadAllComponentIds(combinationId)
    local ids = {}
    if type(_G.GetCombinationNumCollectibleComponents) ~= "function"
        or type(_G.GetCombinationCollectibleComponentId) ~= "function" then
        return ids
    end
    local total = math.max(0, tonumber(_G.GetCombinationNumCollectibleComponents(combinationId)) or 0)
    local seenComponentIds = {}
    for index = 1, total do
        local collectibleId = PositiveNumber(_G.GetCombinationCollectibleComponentId(combinationId, index))
        if collectibleId and not seenComponentIds[collectibleId] then
            seenComponentIds[collectibleId] = true
            ids[#ids + 1] = collectibleId
        end
    end
    table.sort(ids)
    return ids
end

local function ReadNonFragmentComponents(combinationId)
    local ids = {}
    if type(_G.GetCombinationNumNonFragmentCollectibleComponents) ~= "function"
        or type(_G.GetCombinationNonFragmentComponentCollectibleIds) ~= "function" then
        return ids
    end
    local expected = math.max(0, tonumber(_G.GetCombinationNumNonFragmentCollectibleComponents(combinationId)) or 0)
    -- The API returns its IDs as multiple values. Capture a generous bounded set;
    -- the documented count determines how many values are accepted.
    local returned = { _G.GetCombinationNonFragmentComponentCollectibleIds(combinationId) }
    local seen = {}
    for index = 1, math.min(expected, #returned) do
        local collectibleId = PositiveNumber(returned[index])
        if collectibleId and not seen[collectibleId] then
            seen[collectibleId] = true
            ids[#ids + 1] = collectibleId
        end
    end
    return ids
end

local function ReadOutputs(combinationId)
    local ids = {}
    if type(_G.GetCombinationNumUnlockedCollectibles) ~= "function"
        or type(_G.GetCombinationUnlockedCollectibleId) ~= "function" then
        return ids
    end
    local total = math.max(0, tonumber(_G.GetCombinationNumUnlockedCollectibles(combinationId)) or 0)
    local seen = {}
    for index = 1, total do
        local collectibleId = PositiveNumber(_G.GetCombinationUnlockedCollectibleId(combinationId, index))
        if collectibleId and not seen[collectibleId] then
            seen[collectibleId] = true
            ids[#ids + 1] = collectibleId
        end
    end
    return ids
end

local function BuildGroup(combinationId)
    local allComponentIds = ReadAllComponentIds(combinationId)
    local nonFragmentComponents = ReadNonFragmentComponents(combinationId)
    local outputIds = ReadOutputs(combinationId)
    local nonFragmentIdSet, seenFragmentIds, fragmentIds = {}, {}, {}
    for _, collectibleId in ipairs(nonFragmentComponents) do nonFragmentIdSet[collectibleId] = true end
    for _, collectibleId in ipairs(allComponentIds) do
        if not nonFragmentIdSet[collectibleId] and not seenFragmentIds[collectibleId] then
            seenFragmentIds[collectibleId] = true
            fragmentIds[#fragmentIds + 1] = collectibleId
        end
    end
    local unlockedFragments, unlockedNonFragments, outputsUnlocked = 0, 0, 0
    local missingFragmentIds = {}
    for _, collectibleId in ipairs(fragmentIds) do
        if IsUnlocked(collectibleId) then
            unlockedFragments = unlockedFragments + 1
        else
            missingFragmentIds[#missingFragmentIds + 1] = collectibleId
        end
    end
    for _, collectibleId in ipairs(nonFragmentComponents) do
        if IsUnlocked(collectibleId) then unlockedNonFragments = unlockedNonFragments + 1 end
    end
    for _, collectibleId in ipairs(outputIds) do
        if IsUnlocked(collectibleId) then outputsUnlocked = outputsUnlocked + 1 end
    end

    local totalFragments = #fragmentIds
    local outputsTotal = #outputIds
    local requiredComponentsReady = unlockedNonFragments == #nonFragmentComponents
    local state = "missing"
    if outputsTotal > 0 and outputsUnlocked == outputsTotal then
        state = "complete"
    elseif outputsUnlocked > 0 then
        state = "partial_output"
    elseif totalFragments > 0 and unlockedFragments == totalFragments and requiredComponentsReady then
        state = "ready"
    elseif unlockedFragments > 0 or unlockedNonFragments > 0 then
        state = "in_progress"
    end

    -- combinationId is a definition ID, not guaranteed to be a collectible ID.
    -- The first unlocked-by-combination collectible is the stable presentation
    -- target; keep the combination ID only as a defensive fallback.
    local name, icon = GetCollectiblePresentation(outputIds[1] or combinationId)
    local historyReliable = not (outputsUnlocked > 0 and unlockedFragments < totalFragments)
    return {
        combinationId = combinationId,
        name = name,
        icon = icon,
        fragmentIds = fragmentIds,
        unlockedFragments = unlockedFragments,
        totalFragments = totalFragments,
        missingFragments = #missingFragmentIds,
        missingFragmentIds = missingFragmentIds,
        nonFragmentComponents = nonFragmentComponents,
        unlockedNonFragmentComponents = unlockedNonFragments,
        outputIds = outputIds,
        outputsUnlocked = outputsUnlocked,
        outputsTotal = outputsTotal,
        state = state,
        historyReliable = historyReliable,
    }
end

function RFD:GetSummary(forceRefresh)
    if self._summaryCache and not forceRefresh then return self._summaryCache end
    local summary = {
        unlocked = 0,
        total = 0,
        completedCombinations = 0,
        totalCombinations = 0,
        historyReliable = true,
        groups = {},
        apiAvailable = false,
    }
    if type(_G.GetTotalCollectiblesByCategoryType) ~= "function"
        or type(_G.GetCollectibleIdFromType) ~= "function"
        or type(_G.GetCollectibleReferenceId) ~= "function" then
        self._summaryCache = summary
        return summary
    end
    local categoryType = _G.COLLECTIBLE_CATEGORY_TYPE_COMBINATION_FRAGMENT
    if type(categoryType) ~= "number" then
        self._summaryCache = summary
        return summary
    end
    summary.apiAvailable = true
    local fragmentCount = math.max(0, tonumber(_G.GetTotalCollectiblesByCategoryType(categoryType)) or 0)
    local seenFragmentIds, seenCombinationIds = {}, {}
    local combinationIds = {}
    for index = 1, fragmentCount do
        local fragmentId = PositiveNumber(_G.GetCollectibleIdFromType(categoryType, index))
        if fragmentId and not seenFragmentIds[fragmentId] then
            seenFragmentIds[fragmentId] = true
            local combinationId = PositiveNumber(_G.GetCollectibleReferenceId(fragmentId))
            if combinationId and not seenCombinationIds[combinationId] then
                seenCombinationIds[combinationId] = true
                combinationIds[#combinationIds + 1] = combinationId
            end
        end
    end
    table.sort(combinationIds)

    for _, combinationId in ipairs(combinationIds) do
        local group = BuildGroup(combinationId)
        summary.groups[#summary.groups + 1] = group
        summary.unlocked = summary.unlocked + group.unlockedFragments
        summary.total = summary.total + group.totalFragments
        if group.state == "complete" then summary.completedCombinations = summary.completedCombinations + 1 end
        if not group.historyReliable then summary.historyReliable = false end
    end
    summary.totalCombinations = #summary.groups
    table.sort(summary.groups, function(a, b)
        if a.state == b.state then return string.lower(a.name) < string.lower(b.name) end
        local order = { ready = 1, in_progress = 2, partial_output = 3, missing = 4, complete = 5 }
        return (order[a.state] or 9) < (order[b.state] or 9)
    end)
    self._summaryCache = summary
    return summary
end

