-- ConsoleMetrics_Champion.lua
-- Champion point scanning: discipline buckets, slottable stars and the full
-- champion snapshot (fast CHAMPION_DATA_MANAGER path with an API-probe fallback).

local CM = ConsoleMetrics
local Build = ConsoleMetrics.Build
local SafeCallResults = Build.SafeCallResults


---------------------------------------------------------------------------
-- Discipline classification
---------------------------------------------------------------------------
local function ClassifyChampionDisciplineBucket(disciplineName, disciplineType)
    local lowerName = string.lower(tostring(disciplineName or ""))
    if string.find(lowerName, "war", 1, true) ~= nil then
        return "warfare"
    end
    if string.find(lowerName, "fit", 1, true) ~= nil then
        return "fitness"
    end
    if string.find(lowerName, "craft", 1, true) ~= nil then
        return "craft"
    end

    local combatType = type(CHAMPION_DISCIPLINE_TYPE_COMBAT) == "number" and CHAMPION_DISCIPLINE_TYPE_COMBAT or nil
    local conditioningType = type(CHAMPION_DISCIPLINE_TYPE_CONDITIONING) == "number" and CHAMPION_DISCIPLINE_TYPE_CONDITIONING or nil
    local worldType = type(CHAMPION_DISCIPLINE_TYPE_WORLD) == "number" and CHAMPION_DISCIPLINE_TYPE_WORLD or nil

    if type(disciplineType) == "number" then
        if combatType and disciplineType == combatType then
            return "warfare"
        end
        if conditioningType and disciplineType == conditioningType then
            return "fitness"
        end
        if worldType and disciplineType == worldType then
            return "craft"
        end

        -- Console PTS mapping seen on this client can be rotated compared to legacy assumptions.
        if disciplineType == 1 then
            return "fitness"
        end
        if disciplineType == 2 then
            return "craft"
        end
        if disciplineType == 3 then
            return "warfare"
        end
    end
    return nil
end

local function ChampionFirstNumber(results)
    if type(results) ~= "table" then
        return nil
    end

    for i = 1, #results do
        local value = tonumber(results[i])
        if value ~= nil then
            return value
        end
    end

    return nil
end

---------------------------------------------------------------------------
-- Slottable star scan (CHAMPION_DATA_MANAGER)
---------------------------------------------------------------------------
function ConsoleMetrics:BuildChampionSlottablesById()
    local cache = {}
    local meta = {
        disciplineCount = 0,
        skillCount = 0,
        slottableCount = 0,
        unknownCount = 0,
    }

    local allSkillStates = {}
    local slotsById = {}

    local g = type(_G) == "table" and _G or nil
    local cdm = g and g.CHAMPION_DATA_MANAGER or nil
    local hotbarCat = g and g.HOTBAR_CATEGORY_CHAMPION or nil

    if cdm == nil or type(cdm.disciplineDatas) ~= "table" then
        self.championSlottablesById = cache
        self.championSlottablesMeta = meta
        self.championAllSkillStates = allSkillStates
        self.championObservedSlotIds = slotsById
        return cache, meta
    end

    if type(GetSlotBoundId) == "function" and hotbarCat ~= nil then
        for slotIndex = 1, 12 do
            local ok, starId = pcall(GetSlotBoundId, slotIndex, hotbarCat)
            if ok and type(starId) == "number" and starId > 0 then
                slotsById[starId] = true
            end
        end
    end

    for _, discipline in pairs(cdm.disciplineDatas) do
        meta.disciplineCount = meta.disciplineCount + 1
        local disciplineId = discipline.disciplineId
        local disciplineNameResults = SafeCallResults(GetChampionDisciplineName, disciplineId)
        local disciplineName = (disciplineNameResults and disciplineNameResults[1])
            or string.format("Discipline %d", disciplineId)
        local disciplineType = ChampionFirstNumber(SafeCallResults(GetChampionDisciplineType, disciplineId))
        local bucketKey = ClassifyChampionDisciplineBucket(disciplineName, disciplineType)

        for _, star in pairs(discipline.championSkillDatas or {}) do
            local starId = star.championSkillId
            if starId then
                meta.skillCount = meta.skillCount + 1

                local starName = string.format("Star %d", starId)
                if type(GetChampionSkillName) == "function" then
                    local ok, name = pcall(GetChampionSkillName, starId)
                    if ok and type(name) == "string" and name ~= "" then
                        starName = name
                    end
                end

                local isSlottable = false
                if type(star.IsTypeSlottable) == "function" then
                    local ok, result = pcall(star.IsTypeSlottable, star)
                    isSlottable = ok and result == true
                end

                local skillState = {
                    skillId = starId,
                    name = starName,
                    disciplineId = disciplineId,
                    disciplineName = disciplineName,
                    bucketKey = bucketKey,
                    disciplineType = disciplineType,
                    abilityId = nil,
                    isSlottable = isSlottable,
                }
                allSkillStates[starId] = skillState

                if isSlottable then
                    cache[starId] = skillState
                    meta.slottableCount = meta.slottableCount + 1
                else
                    meta.unknownCount = meta.unknownCount + 1
                end
            end
        end
    end

    self.championSlottablesById = cache
    self.championSlottablesMeta = meta
    self.championAllSkillStates = allSkillStates
    self.championObservedSlotIds = slotsById
    return cache, meta
end

function ConsoleMetrics:DumpChampionSlottables()
    local cache, meta = self:BuildChampionSlottablesById()
    local entries = {}
    for _, entry in pairs(cache or {}) do
        entries[#entries + 1] = entry
    end

    local bucketOrder = {
        warfare = 1,
        fitness = 2,
        craft = 3,
    }

    table.sort(entries, function(a, b)
        local bucketA = bucketOrder[a.bucketKey or ""] or 99
        local bucketB = bucketOrder[b.bucketKey or ""] or 99
        if bucketA ~= bucketB then
            return bucketA < bucketB
        end
        if tostring(a.disciplineName or "") ~= tostring(b.disciplineName or "") then
            return tostring(a.disciplineName or "") < tostring(b.disciplineName or "")
        end
        if tostring(a.name or "") ~= tostring(b.name or "") then
            return tostring(a.name or "") < tostring(b.name or "")
        end
        return (a.skillId or 0) < (b.skillId or 0)
    end)

    self:Print(string.format(
        "Champion slottables: %d of %d skills scanned across %d disciplines (unknown=%d).",
        meta.slottableCount or 0,
        meta.skillCount or 0,
        meta.disciplineCount or 0,
        meta.unknownCount or 0
    ))

    local printer = type(d) == "function" and d or function(message)
        self:Print(message)
    end

    local function PrintEntry(entry, tag)
        printer(string.format(
            "|cFF6A00[CM-CP]|r [%s] id=%d abilityId=%s bucket=%s discipline=%s name=%s ability=%s",
            tag,
            entry.skillId or 0,
            tostring(entry.abilityId or 0),
            tostring(entry.bucketKey or "unknown"),
            tostring(entry.disciplineName or "Unknown"),
            tostring(entry.name or string.format("Skill %d", entry.skillId or 0)),
            tostring(entry.abilityName or "n/a")
        ))
    end

    if #entries > 0 then
        for i = 1, #entries do
            PrintEntry(entries[i], "slottable")
        end
        return
    end

    -- No confirmed slottables: emit raw observed slot IDs then all unknown skill states.
    local observedList = {}
    for slotId, _ in pairs(self.championObservedSlotIds or {}) do
        observedList[#observedList + 1] = tostring(slotId)
    end
    table.sort(observedList)
    if #observedList > 0 then
        self:Print("Observed (currently slotted) IDs: " .. table.concat(observedList, ", "))
    else
        self:Print("Slot probing found no IDs. Run /cm debugbuild to check slot API availability.")
    end

    local unknownEntries = {}
    for _, skillState in pairs(self.championAllSkillStates or {}) do
        unknownEntries[#unknownEntries + 1] = skillState
    end

    if #unknownEntries == 0 then
        self:Print("No skill states collected; Champion API may be unavailable.")
        return
    end

    table.sort(unknownEntries, function(a, b)
        local bucketA = bucketOrder[a.bucketKey or ""] or 99
        local bucketB = bucketOrder[b.bucketKey or ""] or 99
        if bucketA ~= bucketB then
            return bucketA < bucketB
        end
        if tostring(a.disciplineName or "") ~= tostring(b.disciplineName or "") then
            return tostring(a.disciplineName or "") < tostring(b.disciplineName or "")
        end
        if tostring(a.name or "") ~= tostring(b.name or "") then
            return tostring(a.name or "") < tostring(b.name or "")
        end
        return (a.skillId or 0) < (b.skillId or 0)
    end)

    self:Print(string.format("Dumping all %d unknown skills (slottable API unavailable):", #unknownEntries))
    for i = 1, #unknownEntries do
        PrintEntry(unknownEntries[i], "?")
    end
end

---------------------------------------------------------------------------
-- Champion snapshot
---------------------------------------------------------------------------
local function BuildChampionSnapshot()
    local snapshot = {
        totalPoints = nil,
        warfare = {},
        fitness = {},
        craft = {},
        available = false,
    }

    local totalResults = SafeCallResults(GetPlayerChampionPointsEarned)
    snapshot.totalPoints = tonumber(totalResults and totalResults[1]) or nil

    local g = type(_G) == "table" and _G or nil
    local cdm = g and g.CHAMPION_DATA_MANAGER or nil
    local hotbarCat = g and g.HOTBAR_CATEGORY_CHAMPION or nil

    -- Fast path: CHAMPION_DATA_MANAGER is the accurate console PTS source (same as LibCombat).
    if cdm ~= nil and type(cdm.disciplineDatas) == "table" then
        local slotsById = {}
        if type(GetSlotBoundId) == "function" and hotbarCat ~= nil then
            for slotIndex = 1, 12 do
                local ok, starId = pcall(GetSlotBoundId, slotIndex, hotbarCat)
                if ok and type(starId) == "number" and starId > 0 then
                    slotsById[starId] = true
                end
            end
        end

        local slotDebugInfo = {
            method = "CHAMPION_DATA_MANAGER",
            foundIds = slotsById,
            probes = {},
        }

        local disciplineCount = 0
        for _, discipline in pairs(cdm.disciplineDatas) do
            disciplineCount = disciplineCount + 1
            local disciplineId = discipline.disciplineId

            local disciplineNameResults = SafeCallResults(GetChampionDisciplineName, disciplineId)
            local disciplineName = (disciplineNameResults and disciplineNameResults[1])
                or string.format("Discipline %d", disciplineId)
            local disciplineType = ChampionFirstNumber(SafeCallResults(GetChampionDisciplineType, disciplineId))
            local bucketKey = ClassifyChampionDisciplineBucket(disciplineName, disciplineType)

            local totalPoints = 0
            if type(discipline.GetNumSavedSpentPoints) == "function" then
                local ok, pts = pcall(discipline.GetNumSavedSpentPoints, discipline)
                totalPoints = (ok and tonumber(pts)) or 0
            end

            local entry = {
                name = disciplineName,
                points = totalPoints,
                stars = {},
                slottedStars = {},
                debug = {
                    disciplineId = disciplineId,
                    disciplineType = disciplineType,
                    method = "CHAMPION_DATA_MANAGER",
                    skillPointProbes = {},
                },
            }

            local summedPoints = 0
            for _, star in pairs(discipline.championSkillDatas or {}) do
                local starId = star.championSkillId
                if starId then
                    local savedPoints = 0
                    if type(star.GetNumSavedPoints) == "function" then
                        local ok, pts = pcall(star.GetNumSavedPoints, star)
                        savedPoints = (ok and tonumber(pts)) or 0
                    end
                    if savedPoints > 0 then
                        summedPoints = summedPoints + savedPoints
                    end

                    if slotsById[starId] then
                        local starName = string.format("Star %d", starId)
                        if type(GetChampionSkillName) == "function" then
                            local ok, name = pcall(GetChampionSkillName, starId)
                            if ok and type(name) == "string" and name ~= "" then
                                starName = name
                            end
                        end
                        entry.stars[#entry.stars + 1] = starName
                        entry.slottedStars[#entry.slottedStars + 1] = { name = starName, skillId = starId }
                    end
                end
            end

            if summedPoints > 0 then
                entry.points = summedPoints
            end

            if bucketKey then
                snapshot[bucketKey][#snapshot[bucketKey] + 1] = entry
            end
        end

        snapshot.available = disciplineCount > 0
        snapshot._slotDebugInfo = slotDebugInfo
        return snapshot
    end

    -- Fallback: probe-based approach when CHAMPION_DATA_MANAGER is unavailable.
    local slottedIds = {}
    local slottedNames = {}

    local function NormalizeName(name)
        if type(name) ~= "string" then
            return nil
        end
        local normalized = string.lower(name)
        normalized = string.gsub(normalized, "|c%x%x%x%x%x%x", "")
        normalized = string.gsub(normalized, "|r", "")
        normalized = string.gsub(normalized, "[^%w%s]", " ")
        normalized = string.gsub(normalized, "%s+", " ")
        normalized = string.gsub(normalized, "^%s+", "")
        normalized = string.gsub(normalized, "%s+$", "")
        return normalized ~= "" and normalized or nil
    end

    local function AddSlottedName(name)
        local normalized = NormalizeName(name)
        if normalized then
            slottedNames[normalized] = true
        end
    end

    local function AddSlottedId(skillId)
        local sid = tonumber(skillId)
        if not sid or sid <= 0 then
            return
        end
        slottedIds[sid] = true
        if type(GetChampionSkillName) == "function" then
            local ok, name = pcall(GetChampionSkillName, sid)
            if ok then
                AddSlottedName(name)
            end
        end
        if type(GetAbilityName) == "function" then
            local ok, name = pcall(GetAbilityName, sid)
            if ok then
                AddSlottedName(name)
            end
        end
    end

    local function FirstNumber(results)
        if type(results) ~= "table" then
            return nil
        end
        for i = 1, #results do
            local value = tonumber(results[i])
            if value ~= nil then
                return value
            end
        end
        return nil
    end

    local function FirstPositiveNumber(results)
        if type(results) ~= "table" then
            return nil
        end
        for i = 1, #results do
            local value = tonumber(results[i])
            if value and value > 0 then
                return value
            end
        end
        return nil
    end

    local function ReadNumberFromFunctionNames(fnNames, ...)
        for i = 1, #fnNames do
            local fn = g and g[fnNames[i]]
            if type(fn) == "function" then
                local results = SafeCallResults(fn, ...)
                local value = FirstNumber(results)
                if value ~= nil then
                    return value
                end
            end
        end
        return nil
    end

    local unpackFn = table.unpack or unpack

    local function ReadMaxNumberFromFunctionNamesWithArgLists(fnNames, argLists)
        local best = nil
        for i = 1, #argLists do
            local value = ReadNumberFromFunctionNames(fnNames, unpackFn(argLists[i]))
            if value ~= nil and (best == nil or value > best) then
                best = value
            end
        end
        return best
    end

    local function CollectNumberProbeValues(fnNames, argLists)
        local values = {}
        for i = 1, #fnNames do
            local fn = g and g[fnNames[i]]
            if type(fn) == "function" then
                for j = 1, #argLists do
                    local value = FirstNumber(SafeCallResults(fn, unpackFn(argLists[j])))
                    if value ~= nil then
                        values[#values + 1] = string.format("%s(%s)=%s", fnNames[i], table.concat(argLists[j], ""), tostring(value))
                    end
                end
            end
        end
        return values
    end

    local function ReadBooleanFromFunctionNames(fnNames, ...)
        for i = 1, #fnNames do
            local fn = g and g[fnNames[i]]
            if type(fn) == "function" then
                local results = SafeCallResults(fn, ...)
                if type(results) == "table" and type(results[1]) == "boolean" then
                    return results[1]
                end
            end
        end
        return nil
    end

    local slotContentFns = {
        "GetChampionSkillSlotSkillId",
        "GetChampionSkillSlotAbilityId",
        "GetChampionSkillSlotId",
        "GetChampionSlottedSkillId",
        "GetChampionSkillInSlot",
        "GetChampionSkillIdInSlot",
        "GetSlottedChampionSkillId",
    }

    local numSlotsResults = SafeCallResults(GetNumChampionSkillSlots)
    local numSlots = tonumber(numSlotsResults and numSlotsResults[1]) or 12
    if numSlots <= 0 then
        numSlots = 12
    end
    local slotProbeMax = math.max(numSlots, 64)

    local slotDebugInfo = {
        numSlotsFunction = "GetNumChampionSkillSlots",
        numSlotsResult = FirstNumber(numSlotsResults),
        resolvedNumSlots = numSlots,
        probeMax = slotProbeMax,
        probes = {},
        foundIds = {},
    }

    for _, fnName in ipairs(slotContentFns) do
        local fn = g and g[fnName]
        if type(fn) == "function" then
            for slotIdx = 1, slotProbeMax do
                local result = FirstPositiveNumber(SafeCallResults(fn, slotIdx))
                if result then
                    slotDebugInfo.probes[#slotDebugInfo.probes + 1] = string.format("%s(%d)=%d", fnName, slotIdx, result)
                    slotDebugInfo.foundIds[result] = true
                    AddSlottedId(result)
                end
            end
            for slotIdx = 0, slotProbeMax do
                local result = FirstPositiveNumber(SafeCallResults(fn, slotIdx))
                if result then
                    slotDebugInfo.probes[#slotDebugInfo.probes + 1] = string.format("%s(%d)=%d", fnName, slotIdx, result)
                    slotDebugInfo.foundIds[result] = true
                    AddSlottedId(result)
                end
            end
        end
    end

    local abilityIdFns = {
        "GetChampionSkillAbilityId",
        "GetAbilityIdForChampionSkill",
        "GetChampionSkillProgressionAbilityId",
    }

    local function ResolveAbilityIdForSkill(skillId, disciplineArg, skillIndexArg)
        if not skillId then
            return nil
        end
        local abilityId = ReadNumberFromFunctionNames(abilityIdFns, skillId)
        if abilityId and abilityId > 0 then
            return abilityId
        end
        if disciplineArg ~= nil and skillIndexArg ~= nil then
            abilityId = ReadNumberFromFunctionNames(abilityIdFns, disciplineArg, skillIndexArg)
            if abilityId and abilityId > 0 then
                return abilityId
            end
        end
        return nil
    end

    local function IsSkillSlottedById(skillId, disciplineArg, skillIndexArg)
        if slottedIds[skillId] then
            return true
        end

        local mappedAbilityId = ResolveAbilityIdForSkill(skillId, disciplineArg, skillIndexArg)
        if mappedAbilityId and slottedIds[mappedAbilityId] then
            return true
        end

        local slottedCheckFns = {
            "IsChampionSkillSlotted",
            "IsSlottedChampionSkill",
            "IsChampionAbilitySlotted",
        }
        local isSlotted = ReadBooleanFromFunctionNames(slottedCheckFns, skillId)
        if isSlotted == true then
            return true
        end
        if disciplineArg ~= nil and skillIndexArg ~= nil then
            isSlotted = ReadBooleanFromFunctionNames(slottedCheckFns, disciplineArg, skillIndexArg)
            if isSlotted == true then
                return true
            end
        end
        if skillIndexArg ~= nil then
            isSlotted = ReadBooleanFromFunctionNames(slottedCheckFns, skillIndexArg)
            if isSlotted == true then
                return true
            end
        end
        if mappedAbilityId then
            isSlotted = ReadBooleanFromFunctionNames(slottedCheckFns, mappedAbilityId)
            if isSlotted == true then
                return true
            end
        end

        local normalized = nil
        if type(GetChampionSkillName) == "function" then
            local ok, skillName = pcall(GetChampionSkillName, skillId)
            normalized = ok and NormalizeName(skillName) or nil
            if normalized and slottedNames[normalized] then
                return true
            end
        end

        if mappedAbilityId and type(GetAbilityName) == "function" then
            local ok, abilityName = pcall(GetAbilityName, mappedAbilityId)
            normalized = ok and NormalizeName(abilityName) or nil
            if normalized and slottedNames[normalized] then
                return true
            end
        end

        if type(GetAbilityName) == "function" then
            local ok, abilityName = pcall(GetAbilityName, skillId)
            normalized = ok and NormalizeName(abilityName) or nil
            if normalized and slottedNames[normalized] then
                return true
            end
        end

        return false
    end

    local disciplineCountResults = SafeCallResults(GetNumChampionDisciplines)
    local disciplineCount = FirstNumber(disciplineCountResults) or 0
    if disciplineCount <= 0 then
        return snapshot
    end
    snapshot.available = true

    local disciplineIndices = {}
    for index = 1, disciplineCount do
        disciplineIndices[#disciplineIndices + 1] = index
    end
    for index = 0, math.max(0, disciplineCount - 1) do
        disciplineIndices[#disciplineIndices + 1] = index
    end

    local seenDisciplineIds = {}
    for _, index in ipairs(disciplineIndices) do
        local disciplineIdResults = SafeCallResults(GetChampionDisciplineId, index)
        local disciplineId = FirstPositiveNumber(disciplineIdResults)
        if not disciplineId and type(index) == "number" and index > 0 then
            disciplineId = index
        end
        if disciplineId and not seenDisciplineIds[disciplineId] then
            seenDisciplineIds[disciplineId] = true
            local disciplineNameResults = SafeCallResults(GetChampionDisciplineName, disciplineId)
            local disciplineName = disciplineNameResults and disciplineNameResults[1] or string.format("Discipline %d", disciplineId)
            local disciplineType = FirstNumber(SafeCallResults(GetChampionDisciplineType, disciplineId))
                or FirstNumber(SafeCallResults(GetChampionDisciplineType, index))
            local bucketKey = ClassifyChampionDisciplineBucket(disciplineName, disciplineType)

            local pointsFnNames = {
                "GetNumPointsSpentOnChampionDiscipline",
                "GetNumPointsSpentInChampionDiscipline",
                "GetNumSpentPointsOnChampionDiscipline",
                "GetNumSpentChampionPointsOnDiscipline",
            }
            local pointsArgs = {
                { disciplineId },
                { index },
            }
            if disciplineType ~= nil then
                pointsArgs[#pointsArgs + 1] = { disciplineType }
            end
            local entry = {
                name = disciplineName,
                points = ReadMaxNumberFromFunctionNamesWithArgLists(pointsFnNames, pointsArgs) or 0,
                stars = {},
                slottedStars = {},
                debug = {
                    disciplineId = disciplineId,
                    disciplineIndex = index,
                    disciplineType = disciplineType,
                    pointsProbes = CollectNumberProbeValues(pointsFnNames, pointsArgs),
                    skillPointProbes = {},
                },
            }

            local skillCount = 0
            local skillCountArgs = {
                { disciplineId },
                { index },
            }
            if disciplineType ~= nil then
                skillCountArgs[#skillCountArgs + 1] = { disciplineType }
            end
            for i = 1, #skillCountArgs do
                local count = FirstNumber(SafeCallResults(GetNumChampionDisciplineSkills, unpackFn(skillCountArgs[i])))
                if count and count > skillCount then
                    skillCount = count
                end
            end

            local skillIdFnNames = {
                "GetChampionSkillId",
                "GetChampionDisciplineSkillId",
                "GetChampionSkillIdByIndex",
                "GetChampionDisciplineSkillIdByIndex",
            }

            local function ResolveSkillId(skillIndex)
                local argLists = {
                    { disciplineId, skillIndex },
                    { index, skillIndex },
                }
                if disciplineType ~= nil then
                    argLists[#argLists + 1] = { disciplineType, skillIndex }
                end

                for i = 1, #skillIdFnNames do
                    local fn = g and g[skillIdFnNames[i]]
                    if type(fn) == "function" then
                        for j = 1, #argLists do
                            local skillId = FirstPositiveNumber(SafeCallResults(fn, unpackFn(argLists[j])))
                            if skillId then
                                return skillId
                            end
                        end
                    end
                end

                return nil
            end

            local seenSkillIds = {}
            local summedSkillPoints = 0
            local skillPointsFnNames = {
                "GetNumPointsSpentOnChampionSkill",
                "GetNumPointsSpentInChampionSkill",
                "GetNumSpentPointsOnChampionSkill",
                "GetNumSpentChampionPointsOnSkill",
                "GetChampionSkillCurrentPoints",
                "GetChampionSkillNumPoints",
            }
            local seenSkillProbeLogs = {}
            local function CollectSkill(skillId, skillIndex)
                if not skillId then
                    return
                end

                local skillState = seenSkillIds[skillId]
                if not skillState then
                    local skillNameResults = SafeCallResults(GetChampionSkillName, skillId)
                    skillState = {
                        name = skillNameResults and skillNameResults[1] or string.format("Skill %d", skillId),
                        points = 0,
                        slotted = false,
                    }
                    seenSkillIds[skillId] = skillState
                end

                local skillName = skillState.name

                local skillPointArgs = {
                    { skillId },
                    { disciplineId, skillId },
                    { index, skillId },
                }
                if skillIndex ~= nil then
                    skillPointArgs[#skillPointArgs + 1] = { disciplineId, skillIndex }
                    skillPointArgs[#skillPointArgs + 1] = { index, skillIndex }
                end
                if disciplineType ~= nil then
                    skillPointArgs[#skillPointArgs + 1] = { disciplineType, skillId }
                    if skillIndex ~= nil then
                        skillPointArgs[#skillPointArgs + 1] = { disciplineType, skillIndex }
                    end
                end

                local skillPoints = ReadMaxNumberFromFunctionNamesWithArgLists(skillPointsFnNames, skillPointArgs) or 0
                if skillPoints > skillState.points then
                    summedSkillPoints = summedSkillPoints - skillState.points + skillPoints
                    skillState.points = skillPoints
                end

                if entry.points <= 0 then
                    for i = 1, #skillPointsFnNames do
                        local fn = g and g[skillPointsFnNames[i]]
                        if type(fn) == "function" then
                            for j = 1, #skillPointArgs do
                                local value = FirstNumber(SafeCallResults(fn, unpackFn(skillPointArgs[j])))
                                if value ~= nil then
                                    local probeText = string.format(
                                        "%s(skill=%s:%s,args=%s)=%s",
                                        skillPointsFnNames[i],
                                        tostring(skillId),
                                        tostring(skillName),
                                        table.concat(skillPointArgs[j], ""),
                                        tostring(value)
                                    )
                                    if not seenSkillProbeLogs[probeText] then
                                        seenSkillProbeLogs[probeText] = true
                                        entry.debug.skillPointProbes[#entry.debug.skillPointProbes + 1] = probeText
                                    end
                                end
                            end
                        end
                    end
                end

                if not skillState.slotted and (IsSkillSlottedById(skillId, disciplineId, skillIndex) or IsSkillSlottedById(skillId, disciplineType, skillIndex)) then
                    skillState.slotted = true
                    entry.stars[#entry.stars + 1] = skillName
                    entry.slottedStars[#entry.slottedStars + 1] = { name = skillName, skillId = skillId }
                end
            end

            local skillProbeMax = math.max(skillCount + 8, 96)

            for skillIndex = 1, skillProbeMax do
                local skillId = ResolveSkillId(skillIndex)
                CollectSkill(skillId, skillIndex)
            end

            for skillIndex = 0, skillProbeMax do
                local skillId = ResolveSkillId(skillIndex)
                CollectSkill(skillId, skillIndex)
            end

            if summedSkillPoints > 0 then
                entry.points = summedSkillPoints
            end

            if bucketKey then
                snapshot[bucketKey][#snapshot[bucketKey] + 1] = entry
            end
        end
    end

    snapshot._slotDebugInfo = slotDebugInfo

    return snapshot
end

---------------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------------

ConsoleMetrics.Champion = {
    BuildChampionSnapshot = BuildChampionSnapshot,
    ChampionFirstNumber = ChampionFirstNumber,
    ClassifyChampionDisciplineBucket = ClassifyChampionDisciplineBucket,
}
