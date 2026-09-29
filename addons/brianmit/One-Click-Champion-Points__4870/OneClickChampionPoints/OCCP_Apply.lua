-- OCCP_Apply.lua
-- One-click Champion Point build application.
--
-- The player must first use ESO's normal Champion Point Redistribute/Clear Points
-- action so every tree has 0 pending points. OCCP then builds and validates a
-- normal Champion purchase request, using only the points the character has.
--
-- Allocation rules:
--   1) The four displayed slottable stars are prioritized at their live maximum.
--   2) The passive point recommendations shown by OCCP are then applied in the
--      exact order written in the build data.
--   3) If the character has additional CP left in a tree, the remaining points
--      are placed only into the already-listed passive recommendations, in the
--      same priority order, up to each star's live maximum.
--   4) No CP is invented and no tree can be driven below zero available points.

OCCP = OCCP or {}
local C = OCCP
local Apply = {}
C.Apply = Apply

Apply.busy = false
Apply.pendingBuildLabel = nil
Apply.nextAllowedTime = 0
Apply.cooldownSeconds = 31
Apply.SLOTTABLE_DEFAULT_POINTS = 50

local TREE_TYPE = {
    warfare = CHAMPION_DISCIPLINE_TYPE_COMBAT,
    fitness = CHAMPION_DISCIPLINE_TYPE_CONDITIONING,
    craft   = CHAMPION_DISCIPLINE_TYPE_WORLD,
}

local TREE_NAMES = { "warfare", "fitness", "craft" }

local ERROR_TEXT = {
    [CHAMPION_PURCHASE_SUCCESS] = "Success.",
    [CHAMPION_PURCHASE_ABILITY_CAP_EXCEEDED] = "Ability cap exceeded.",
    [CHAMPION_PURCHASE_ABILITY_LINE_LEVEL_NOT_MET] = "A Champion requirement was not met.",
    [CHAMPION_PURCHASE_ATTRIBUTE_CAP_EXCEEDED] = "Champion attribute cap exceeded.",
    [CHAMPION_PURCHASE_INVALID_ATTRIBUTE] = "An invalid Champion attribute was requested.",
    [CHAMPION_PURCHASE_CHAMPION_BAR_ILLEGAL_SLOT] = "Illegal Champion Bar slot.",
    [CHAMPION_PURCHASE_CHAMPION_BAR_NOT_CHAMPION_SKILL] = "A selected Champion Bar slot is not a Champion skill.",
    [CHAMPION_PURCHASE_CHAMPION_BAR_ON_COOLDOWN] = "Champion Bar changes are on cooldown.",
    [CHAMPION_PURCHASE_CHAMPION_BAR_SKILL_NOT_PURCHASED] = "A Champion Bar star was not purchased by this setup.",
    [CHAMPION_PURCHASE_CHAMPION_BAR_SKILL_NOT_SLOTTABLE] = "A selected star cannot be slotted.",
    [CHAMPION_PURCHASE_CHAMPION_BAR_WRONG_DISCIPLINE] = "A Champion Bar slot has the wrong discipline.",
    [CHAMPION_PURCHASE_CHAMPION_NOT_UNLOCKED] = "Champion Points are not available for this character.",
    [CHAMPION_PURCHASE_CP_DISABLED] = "Champion Points are currently disabled here.",
    [CHAMPION_PURCHASE_IN_COMBAT] = "You cannot change Champion Points while in combat.",
    [CHAMPION_PURCHASE_IN_NOCP_BATTLEGROUND] = "Champion Points are disabled in this Battleground.",
    [CHAMPION_PURCHASE_IN_NOCP_CAMPAIGN] = "Champion Points are disabled in this campaign.",
    [CHAMPION_PURCHASE_NOT_ENOUGH_POINTS] = "The profile needs more Champion Points than are available.",
    [CHAMPION_PURCHASE_RESPEC_FAILED] = "Redistribute failed. Enough gold for the fee? Then redistribute again.",
    [CHAMPION_PURCHASE_SKILL_NEEDS_REFUND] = "A Champion star must be refunded before this setup can be applied.",
    [CHAMPION_PURCHASE_SKILL_NOT_CONNECTED] = "A Champion star is not connected to an unlocked path.",
    [CHAMPION_PURCHASE_INTERNAL_ERROR] = "ESO returned an internal Champion Point error.",
    [CHAMPION_PURCHASE_INVALID_ABILITY] = "ESO rejected a Champion ability in the request.",
    [CHAMPION_PURCHASE_USING_LOADOUT] = "The Champion loadout system is currently in use.",
}

local function NormalizeName(name)
    if not name then return "" end
    name = string.lower(name)
    name = name:gsub("%s+", " ")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    return name
end

local function StripParenthetical(name)
    if not name then return "" end
    return (name:gsub("%s*%([^%)]*%)", ""))
end

local function ParsePassiveString(text)
    local result = {}
    if type(text) ~= "string" then return result end

    for token in string.gmatch(text, "[^,]+") do
        token = StripParenthetical(token)
        token = token:gsub("^%s+", ""):gsub("%s+$", "")

        local name, _, high = token:match("^(.-)%s+(%d+)%s*%-%s*(%d+)%s*$")
        if name and high then
            result[#result + 1] = { name = name, points = tonumber(high) }
        else
            local oneName, onePoints = token:match("^(.-)%s+(%d+)%s*$")
            if oneName and onePoints then
                result[#result + 1] = { name = oneName, points = tonumber(onePoints) }
            end
        end
    end

    return result
end

local function GetSkillIndex()
    local index = {
        byId = {},
        byDisciplineName = {},
        byType = {},
        disciplines = {},
    }

    for disciplineIndex = 1, GetNumChampionDisciplines() do
        local disciplineId = GetChampionDisciplineId(disciplineIndex)
        local disciplineType = GetChampionDisciplineType(disciplineId)
        local discipline = {
            index = disciplineIndex,
            id = disciplineId,
            type = disciplineType,
            skills = {},
        }
        index.disciplines[#index.disciplines + 1] = discipline
        index.byType[disciplineType] = discipline
        index.byDisciplineName[disciplineId] = {}

        for skillIndex = 1, GetNumChampionDisciplineSkills(disciplineIndex) do
            local skillId = GetChampionSkillId(disciplineIndex, skillIndex)
            local rawName = GetChampionSkillName(skillId)
            local data = {
                id = skillId,
                name = rawName,
                normName = NormalizeName(rawName),
                disciplineIndex = disciplineIndex,
                disciplineId = disciplineId,
                type = disciplineType,
                maxPoints = GetChampionSkillMaxPoints(skillId) or Apply.SLOTTABLE_DEFAULT_POINTS,
                isRoot = IsChampionSkillRootNode(skillId),
                links = {},
            }

            local linked = { GetChampionSkillLinkIds(skillId) }
            for _, linkedId in ipairs(linked) do
                if linkedId and linkedId ~= 0 then
                    data.links[#data.links + 1] = linkedId
                end
            end

            discipline.skills[#discipline.skills + 1] = data
            index.byId[skillId] = data
            if rawName and rawName ~= "" then
                index.byDisciplineName[disciplineId][data.normName] = skillId
            end
        end
    end

    return index
end

local function FindSkill(index, disciplineId, name)
    local clean = NormalizeName(StripParenthetical(name))
    local map = index.byDisciplineName[disciplineId]
    if not map then return nil end
    local skillId = map[clean]
    if not skillId and clean ~= "" then
        -- Tolerate small spelling slips in guide data (e.g. "Spirit Master" for
        -- "Spirit Mastery"): accept a live name that starts with the given one,
        -- but only when exactly one star matches.
        for liveName, id in pairs(map) do
            if liveName:sub(1, #clean) == clean then
                if skillId then return nil end
                skillId = id
            end
        end
    end
    return skillId and index.byId[skillId] or nil
end

-- Find a path from a root to the target while preferring already-invested nodes.
-- A newly-required node costs 1 for path selection; an already pending node costs 0.
-- This minimizes path overhead when several valid routes exist.
local function FindBestPathToTarget(index, targetId)
    local target = index.byId[targetId]
    if not target then return nil end

    local queue, distance, parent = {}, {}, {}
    for _, skill in ipairs(index.byType[target.type].skills) do
        if skill.isRoot then
            distance[skill.id] = (CHAMPION_DATA_MANAGER:GetChampionSkillData(skill.id):GetNumPendingPoints() > 0) and 0 or 1
            parent[skill.id] = false
            queue[#queue + 1] = skill.id
        end
    end

    while #queue > 0 do
        local bestIndex, bestId = 1, queue[1]
        for i = 2, #queue do
            local id = queue[i]
            if distance[id] < distance[bestId] then
                bestIndex, bestId = i, id
            end
        end
        table.remove(queue, bestIndex)

        if bestId == targetId then
            local path = {}
            local cur = targetId
            while cur do
                table.insert(path, 1, cur)
                cur = parent[cur]
            end
            return path
        end

        local current = index.byId[bestId]
        if current then
            for _, linkedId in ipairs(current.links) do
                local linked = index.byId[linkedId]
                if linked and linked.type == target.type then
                    local linkedData = CHAMPION_DATA_MANAGER:GetChampionSkillData(linkedId)
                    if linkedData then
                        local weight = linkedData:GetNumPendingPoints() > 0 and 0 or 1
                        local newDistance = distance[bestId] + weight
                        if distance[linkedId] == nil or newDistance < distance[linkedId] then
                            distance[linkedId] = newDistance
                            parent[linkedId] = bestId
                            queue[#queue + 1] = linkedId
                        end
                    end
                end
            end
        end
    end

    return nil
end

local function GetDisciplineDataByType(disciplineType)
    if not CHAMPION_DATA_MANAGER then return nil end
    return CHAMPION_DATA_MANAGER:FindChampionDisciplineDataByType(disciplineType)
end

local function GetTreeAvailable(treeName)
    local discipline = GetDisciplineDataByType(TREE_TYPE[treeName])
    if not discipline then return 0 end
    return zo_max(0, discipline:GetNumAvailablePoints())
end

local function GetSavedTreeTotal(treeName)
    local discipline = GetDisciplineDataByType(TREE_TYPE[treeName])
    if not discipline then return 0 end
    return zo_max(0, discipline:GetNumSavedPointsTotal())
end

local function AddTarget(targetsByTree, treeName, index, name, desiredPoints, slot, kind)
    local discipline = index.byType[TREE_TYPE[treeName]]
    if not discipline then
        return false, treeName .. ": " .. tostring(name) .. " (tree unavailable)"
    end

    local skill = FindSkill(index, discipline.id, name)
    if not skill then
        return false, treeName .. ": " .. tostring(name)
    end

    local requested = tonumber(desiredPoints) or skill.maxPoints
    local desired = zo_clamp(requested, 0, skill.maxPoints)
    if desired <= 0 then return true end

    local bucket = targetsByTree[treeName]
    local existing = bucket.byId[skill.id]
    if existing then
        existing.desired = zo_max(existing.desired, desired)
        if slot then
            existing.slot = slot
            existing.isSlot = true
            existing.kind = "slot"
        elseif existing.kind ~= "slot" then
            existing.kind = kind or existing.kind or "passive"
        end
    else
        local target = {
            id = skill.id,
            name = skill.name,
            desired = desired,
            maxPoints = skill.maxPoints,
            slot = slot,
            isSlot = slot ~= nil,
            kind = kind or (slot and "slot" or "passive"),
            order = #bucket.list + 1,
        }
        bucket.byId[skill.id] = target
        bucket.list[#bucket.list + 1] = target
    end

    return true
end

-- If a star from a setup can't go on the Champion bar in the live game (or no
-- longer exists), its bar slot goes to the next of these, in this order.
local FALLBACK_SLOTS = {
    warfare = { "Master-at-Arms", "Deadly Aim", "Wrathful Strikes", "Fighting Finesse", "Biting Aura", "Backstabber", "Thaumaturge", "Exploiter" },
    fitness = { "Boundless Vitality", "Fortified", "Rejuvenation", "Celerity", "Bastion", "Pain's Refuge", "Sustained by Suffering" },
    craft   = { "Steed's Blessing", "Gifted Rider", "War Mount", "Treasure Hunter", "Liquid Efficiency", "Master Gatherer", "Homemaker", "Reel Technique" },
}

local function IsSlottable(skillId)
    if CanChampionSkillTypeBeSlotted and GetChampionSkillType then
        return CanChampionSkillTypeBeSlotted(GetChampionSkillType(skillId)) == true
    end
    return true
end

-- The star list for this character's game: per tree, up to 4 slottable stars
-- (setup order first, fallbacks after), plus the setup stars that can't be
-- slotted (they still get points, as passives).
local function ResolveSlots(build, index)
    local result = {}
    for _, treeName in ipairs(TREE_NAMES) do
        local discipline = index.byType[TREE_TYPE[treeName]]
        local slots, extra, used = {}, {}, {}
        local wanted = build[treeName] or {}
        for i = 1, #wanted do
            local skill = discipline and FindSkill(index, discipline.id, wanted[i])
            if skill and IsSlottable(skill.id) and not used[skill.id] then
                slots[i] = skill
                used[skill.id] = true
            elseif skill then
                extra[#extra + 1] = skill
            end
        end
        -- fill the gaps, keeping each good star in its own position
        local fallbacks = FALLBACK_SLOTS[treeName]
        local nextFallback = 1
        for i = 1, zo_max(#wanted, 4) do
            if not slots[i] and i <= 4 then
                while nextFallback <= #fallbacks do
                    local skill = discipline and FindSkill(index, discipline.id, fallbacks[nextFallback])
                    nextFallback = nextFallback + 1
                    if skill and IsSlottable(skill.id) and not used[skill.id] then
                        slots[i] = skill
                        used[skill.id] = true
                        break
                    end
                end
            end
        end
        local list = {}
        for i = 1, 4 do
            if slots[i] then list[#list + 1] = slots[i] end
        end
        result[treeName] = { slots = list, extra = extra }
    end
    return result
end

-- Live index of Champion stars (static game data, built once).
local function GetCachedIndex()
    if not Apply._index or not next(Apply._index.byId) then
        Apply._index = GetSkillIndex()
    end
    return Apply._index
end

-- Star names to show in the window: exactly what Apply will slot.
function Apply.GetSlotNames(build)
    if not GetNumChampionDisciplines or GetNumChampionDisciplines() == 0 then return nil end
    local resolved = ResolveSlots(build, GetCachedIndex())
    local names = {}
    for _, treeName in ipairs(TREE_NAMES) do
        names[treeName] = {}
        for _, skill in ipairs(resolved[treeName].slots) do
            names[treeName][#names[treeName] + 1] = zo_strformat("<<1>>", skill.name)
        end
    end
    return names
end

local function BuildTargets(build, index)
    local targets = {
        warfare = { list = {}, byId = {} },
        fitness = { list = {}, byId = {} },
        craft   = { list = {}, byId = {} },
    }
    local slotNames = {}
    local missing = {}

    -- The four displayed slottables are kept first in the plan. Their requested
    -- point value is the live maximum for that Champion skill (usually 50).
    -- Stars that can't be slotted in the live game were swapped for the next
    -- best one by ResolveSlots; they still get their points, as passives.
    local resolved = ResolveSlots(build, index)
    for _, treeName in ipairs(TREE_NAMES) do
        slotNames[treeName] = {}
        for slotIndex, skill in ipairs(resolved[treeName].slots) do
            slotNames[treeName][slotIndex] = skill.name
            local ok, missingName = AddTarget(targets, treeName, index, skill.name,
                build.slottablePoints or nil, slotIndex, "slot")
            if not ok then missing[#missing + 1] = missingName end
        end
    end

    -- Passive recommendations remain exactly as written in OCCP_Data.lua.
    for _, treeName in ipairs(TREE_NAMES) do
        local entries = build.passives and build.passives[treeName]
        if type(entries) == "table" then
            for _, entry in ipairs(entries) do
                local ok, missingName = AddTarget(targets, treeName, index, entry.name, tonumber(entry.points) or 0, nil, "passive")
                if not ok then missing[#missing + 1] = missingName end
            end
        else
            for _, entry in ipairs(ParsePassiveString(entries)) do
                local ok, missingName = AddTarget(targets, treeName, index, entry.name, entry.points, nil, "passive")
                if not ok then missing[#missing + 1] = missingName end
            end
        end
    end

    -- Setup stars that can't be slotted get their points after the listed passives.
    for _, treeName in ipairs(TREE_NAMES) do
        for _, skill in ipairs(resolved[treeName].extra) do
            AddTarget(targets, treeName, index, skill.name, nil, nil, "passive")
        end
    end

    return targets, slotNames, missing
end

local function EnsureFullReset()
    if not CHAMPION_DATA_MANAGER then return false, "CHAMPION SYSTEM NOT READY" end

    -- In ESO's own Champion data manager, available points are based on
    -- saved total minus pending points. After a real Redistribute/Clear Points
    -- action, every skill's pending value must be 0.
    for _, disciplineData in CHAMPION_DATA_MANAGER:ChampionDisciplineDataIterator() do
        if disciplineData:GetOrCalculateNumPendingPoints() > 0 then
            return false, "REDISTRIBUTE ALL CHAMPION POINTS FIRST"
        end
    end

    return true
end

local function GetChampionBarSlots()
    local slots = { warfare = {}, fitness = {}, craft = {} }
    if not GetAssignableChampionBarStartAndEndSlots or not GetRequiredChampionDisciplineIdForSlot then
        return slots
    end

    local startSlot, endSlot = GetAssignableChampionBarStartAndEndSlots()
    for slotIndex = startSlot, endSlot do
        local disciplineId = GetRequiredChampionDisciplineIdForSlot(slotIndex, HOTBAR_CATEGORY_CHAMPION)
        local disciplineType = disciplineId and GetChampionDisciplineType(disciplineId)
        for treeName, treeType in pairs(TREE_TYPE) do
            if disciplineType == treeType then
                slots[treeName][#slots[treeName] + 1] = slotIndex
                break
            end
        end
    end
    return slots
end

local function SetTargetToDesired(disciplineData, target)
    local skillData = CHAMPION_DATA_MANAGER:GetChampionSkillData(target.id)
    if not skillData then
        return false, "Champion skill data disappeared for " .. tostring(target.name) .. "."
    end

    local current = skillData:GetNumPendingPoints()
    local pool = zo_max(0, disciplineData:GetNumAvailablePoints())
    local maxPossible = zo_min(target.maxPoints, current + pool)
    local desired = zo_clamp(target.desired, current, maxPossible)

    if desired > current then
        skillData:SetNumPendingPoints(desired)
    end

    return true
end

-- Fewest points that unlock a star. Some stars only unlock (and only let the
-- path continue past them) after more than 1 point, so 1 point is not always enough.
local minUnlockCache = {}
local function MinUnlockPoints(skillId, maxPoints)
    if minUnlockCache[skillId] then return minUnlockCache[skillId] end
    local need = 1
    if WouldChampionSkillNodeBeUnlocked then
        need = maxPoints or 1
        for points = 1, maxPoints or 1 do
            if WouldChampionSkillNodeBeUnlocked(skillId, points) then
                need = points
                break
            end
        end
    end
    minUnlockCache[skillId] = need
    return need
end

local function EnsureTargetPath(index, disciplineData, target)
    local path = FindBestPathToTarget(index, target.id)
    if not path then
        return false, "No connected Champion Point path was found for " .. tostring(target.name) .. "."
    end

    for _, pathId in ipairs(path) do
        local pathData = CHAMPION_DATA_MANAGER:GetChampionSkillData(pathId)
        if not pathData then
            return false, "Champion skill data disappeared while building the path to " .. tostring(target.name) .. "."
        end

        local skill = index.byId[pathId]
        local need = MinUnlockPoints(pathId, skill and skill.maxPoints)
        local current = pathData:GetNumPendingPoints()
        if current < need then
            local available = disciplineData:GetNumAvailablePoints()
            if available <= 0 then
                return true
            end
            pathData:SetNumPendingPoints(zo_min(need, current + available))
        end
    end

    return true
end

local function GetTreePendingPoints(treeName)
    local discipline = GetDisciplineDataByType(TREE_TYPE[treeName])
    if not discipline then return 0 end
    return zo_max(0, discipline:GetOrCalculateNumPendingPoints())
end

local function FillLeftoverPointsInBuild(treeName, disciplineData, targets)
    -- First fill passive nodes to their live maximums, in the same priority
    -- order as the profile.  This is the important fallback for characters whose
    -- CP pool is larger than the minimum recommendation.
    for _, target in ipairs(targets.list) do
        if target.kind == "passive" then
            local skillData = CHAMPION_DATA_MANAGER:GetChampionSkillData(target.id)
            if skillData then
                local available = zo_max(0, disciplineData:GetNumAvailablePoints())
                if available > 0 then
                    local current = skillData:GetNumPendingPoints()
                    local capacity = zo_max(0, target.maxPoints - current)
                    if capacity > 0 then
                        local pathOk, pathError = EnsureTargetPath(C.Apply._lastIndex, disciplineData, target)
                        if not pathOk then
                            return false, pathError
                        end
                        available = zo_max(0, disciplineData:GetNumAvailablePoints())
                        current = skillData:GetNumPendingPoints()
                        capacity = zo_max(0, target.maxPoints - current)
                        local add = zo_min(available, capacity)
                        if add > 0 then
                            skillData:SetNumPendingPoints(current + add)
                        end
                    end
                end
            end
        end
        if disciplineData:GetNumAvailablePoints() <= 0 then break end
    end

    -- If a profile still has spare points, use only the stars explicitly named
    -- by that profile.  This second pass includes slottables too, and therefore
    -- guarantees the tree consumes all available CP whenever one of the listed
    -- stars still has capacity.  It deliberately never invents a new star.
    local madeProgress = true
    while disciplineData:GetNumAvailablePoints() > 0 and madeProgress do
        madeProgress = false
        for _, target in ipairs(targets.list) do
            if disciplineData:GetNumAvailablePoints() <= 0 then break end
            local skillData = CHAMPION_DATA_MANAGER:GetChampionSkillData(target.id)
            if skillData then
                local current = skillData:GetNumPendingPoints()
                if current < target.maxPoints then
                    local pathOk, pathError = EnsureTargetPath(C.Apply._lastIndex, disciplineData, target)
                    if not pathOk then
                        return false, pathError
                    end
                    current = skillData:GetNumPendingPoints()
                    local available = zo_max(0, disciplineData:GetNumAvailablePoints())
                    local capacity = zo_max(0, target.maxPoints - current)
                    local add = zo_min(available, capacity)
                    if add > 0 then
                        skillData:SetNumPendingPoints(current + add)
                        madeProgress = true
                    end
                end
            end
        end
    end

    return true
end

-- Undo every pending change this addon made, back to the redistributed state
-- (every star 0), so a failed attempt never leaves points half-spent.
local function ClearPendingPlan(index)
    if not index or not CHAMPION_DATA_MANAGER then return end
    for skillId in pairs(index.byId) do
        local data = CHAMPION_DATA_MANAGER:GetChampionSkillData(skillId)
        if data and data:GetNumPendingPoints() > 0 then
            data:SetNumPendingPoints(0)
        end
    end
end

-- Name the first star ESO would refuse on the Champion bar, and why.
local function FindUnslottableStar(requestData)
    for _, skillId in pairs(requestData.slotMap) do
        local skill = requestData.index.byId[skillId]
        local name = skill and skill.name or tostring(skillId)
        if CanChampionSkillTypeBeSlotted and GetChampionSkillType
            and not CanChampionSkillTypeBeSlotted(GetChampionSkillType(skillId)) then
            return name .. " can't go on the Champion bar."
        end
        local data = CHAMPION_DATA_MANAGER:GetChampionSkillData(skillId)
        local points = data and data:GetNumPendingPoints() or 0
        if WouldChampionSkillNodeBeUnlocked and not WouldChampionSkillNodeBeUnlocked(skillId, points) then
            return string.format("%s is not unlocked (%d points, needs %d).", name, points,
                MinUnlockPoints(skillId, skill and skill.maxPoints))
        end
    end
    return nil
end

local function ApplyTargetPlan(build)
    local index = GetSkillIndex()
    C.Apply._lastIndex = index

    local targets, slotNames, missing = BuildTargets(build, index)
    -- A passive name the live game doesn't know (renamed in a patch) is simply
    -- skipped; the rest of the setup still applies. Noted in chat for the author.
    if #missing > 0 then
        d("|cFF9A4DOne Click CP:|r skipped unknown star(s): " .. table.concat(missing, ", "))
    end

    local slotIndicesByTree = GetChampionBarSlots()
    local finalSlotMap = {}
    local plan = {}

    for _, treeName in ipairs(TREE_NAMES) do
        local disciplineData = GetDisciplineDataByType(TREE_TYPE[treeName])
        if not disciplineData then
            return false, nil, treeName .. " Champion discipline is unavailable."
        end

        local entries = targets[treeName].list
        local plannedTargets = {}

        -- First apply the requested slottables and passive values in the order
        -- represented by the build, stopping exactly when the live pool runs out.
        for _, target in ipairs(entries) do
            if disciplineData:GetNumAvailablePoints() <= 0 then break end

            local pathOk, pathError = EnsureTargetPath(index, disciplineData, target)
            if not pathOk then
                return false, nil, pathError
            end

            local ok, targetError = SetTargetToDesired(disciplineData, target)
            if not ok then
                return false, nil, targetError
            end

            local actualData = CHAMPION_DATA_MANAGER:GetChampionSkillData(target.id)
            if actualData and actualData:GetNumPendingPoints() > 0 then
                plannedTargets[#plannedTargets + 1] = {
                    id = target.id,
                    name = target.name,
                    points = actualData:GetNumPendingPoints(),
                    isSlot = target.isSlot,
                    kind = target.kind,
                }
            end
        end

        -- Any remaining CP is placed only into the already-listed passive stars.
        local fillOk, fillError = FillLeftoverPointsInBuild(treeName, disciplineData, { list = entries })
        if not fillOk then
            return false, nil, fillError or ("Unable to place leftover " .. treeName .. " Champion Points into the listed build nodes.")
        end

        -- Refresh planned target point values after the leftover pass.
        local byId = {}
        for _, item in ipairs(plannedTargets) do byId[item.id] = item end
        for _, target in ipairs(entries) do
            local skillData = CHAMPION_DATA_MANAGER:GetChampionSkillData(target.id)
            if skillData and skillData:GetNumPendingPoints() > 0 then
                if byId[target.id] then
                    byId[target.id].points = skillData:GetNumPendingPoints()
                else
                    local item = {
                        id = target.id,
                        name = target.name,
                        points = skillData:GetNumPendingPoints(),
                        isSlot = target.isSlot,
                        kind = target.kind,
                    }
                    plannedTargets[#plannedTargets + 1] = item
                    byId[target.id] = item
                end
            end
        end

        local remainingAfterFill = zo_max(0, disciplineData:GetNumAvailablePoints())
        local totalForTree = disciplineData:GetNumSavedPointsTotal()
        local pendingForTree = disciplineData:GetOrCalculateNumPendingPoints()
        if pendingForTree < 0 or pendingForTree > totalForTree then
            return false, nil, treeName .. " produced an invalid Champion Point allocation. Nothing was sent."
        end

        plan[treeName] = plannedTargets

        -- Map the four displayed slottables to ESO's actual Champion Bar slots.
        -- A star the character can't unlock yet (not enough CP) is skipped instead
        -- of failing the whole purchase; it gets slotted by a later Apply.
        for _, target in ipairs(plannedTargets) do
            local unlocked = not WouldChampionSkillNodeBeUnlocked
                or WouldChampionSkillNodeBeUnlocked(target.id, target.points)
            if target.isSlot and unlocked then
                local wantedName = NormalizeName(target.name)
                for i, slotName in ipairs(slotNames[treeName]) do
                    if NormalizeName(StripParenthetical(slotName)) == wantedName and slotIndicesByTree[treeName][i] then
                        finalSlotMap[slotIndicesByTree[treeName][i]] = target.id
                        break
                    end
                end
            end
        end
    end

    -- Stars that could not go on the bar yet (named for the result message).
    local skipped = {}
    for _, treeName in ipairs(TREE_NAMES) do
        for i, slotName in ipairs(slotNames[treeName]) do
            local slotIndex = slotIndicesByTree[treeName][i]
            if slotIndex and not finalSlotMap[slotIndex] then
                skipped[#skipped + 1] = slotName
            end
        end
    end

    C.Apply._lastIndex = nil
    return true, {
        index = index,
        plan = plan,
        slotMap = finalSlotMap,
        skipped = skipped,
        treePending = {
            warfare = GetTreePendingPoints("warfare"),
            fitness = GetTreePendingPoints("fitness"),
            craft = GetTreePendingPoints("craft"),
        },
    }
end

function Apply.GetTreePointPools()
    return {
        warfare = {
            available = GetTreeAvailable("warfare"),
            total = GetSavedTreeTotal("warfare"),
        },
        fitness = {
            available = GetTreeAvailable("fitness"),
            total = GetSavedTreeTotal("fitness"),
        },
        craft = {
            available = GetTreeAvailable("craft"),
            total = GetSavedTreeTotal("craft"),
        },
    }
end

function Apply.GetTotalCP()
    local pools = Apply.GetTreePointPools()
    return pools.warfare.total + pools.fitness.total + pools.craft.total
end

function Apply.IsCurrentClass(selectedClassId)
    return selectedClassId ~= nil and GetUnitClassId("player") == selectedClassId
end

function Apply.GetState(selectedClassId)
    local now = GetFrameTimeSeconds and GetFrameTimeSeconds() or 0

    if Apply.busy then
        return false, "APPLYING…", false
    end
    if Apply.nextAllowedTime and now < Apply.nextAllowedTime then
        return false, string.format("WAIT %.0f SECONDS BEFORE APPLYING AGAIN", Apply.nextAllowedTime - now), false
    end
    if not Apply.IsCurrentClass(selectedClassId) then
        return false, "VIEW ONLY — SELECT YOUR CURRENT CLASS TO APPLY", false
    end
    if IsUnitInCombat("player") then
        return false, "LEAVE COMBAT BEFORE APPLYING", true
    end
    if not CHAMPION_DATA_MANAGER then
        return false, "CHAMPION SYSTEM NOT READY", true
    end
    if not PrepareChampionPurchaseRequest or not SendChampionPurchaseRequest
        or not AddSkillToChampionPurchaseRequest or not AddHotbarSlotToChampionPurchaseRequest then
        return false, "CHAMPION PURCHASE API NOT AVAILABLE", true
    end

    local reset, resetText = EnsureFullReset()
    if not reset then
        return false, resetText, true
    end

    local availability = GetChampionPurchaseAvailability and GetChampionPurchaseAvailability()
    if availability and availability ~= CHAMPION_PURCHASE_SUCCESS then
        return false, ERROR_TEXT[availability] or "CHAMPION POINT PURCHASE IS CURRENTLY UNAVAILABLE", true
    end

    return true, "READY — CLICK APPLY", true
end

function Apply.ApplyBuild(build, buildLabel)
    local ready, stateText = Apply.GetState(C.sv and C.sv.classId)
    if not ready then
        C.SetApplyStatus(stateText, false, stateText:find("VIEW ONLY", 1, true) == nil)
        return false
    end

    -- Redistributing costs gold in ESO. Check before touching anything, so the
    -- player gets a clear message instead of ESO's "respec failed".
    if CHAMPION_DATA_MANAGER:IsRespecNeeded() and GetChampionRespecCost then
        local cost = GetChampionRespecCost() or 0
        local gold = GetCurrentMoney and GetCurrentMoney() or cost
        if gold < cost then
            C.SetApplyStatus(string.format("Redistributing costs %s gold, you have %s.",
                ZO_CommaDelimitNumber(cost), ZO_CommaDelimitNumber(gold)), false, true)
            return false
        end
    end

    local ok, requestData, errorText = ApplyTargetPlan(build)
    if not ok then
        ClearPendingPlan(C.Apply._lastIndex)
        C.Apply._lastIndex = nil
        C.SetApplyStatus(errorText or "Unable to build Champion Point request.", false, true)
        return false
    end

    -- Check the 12 Champion bar stars before asking ESO, so a problem names the star.
    local badStar = FindUnslottableStar(requestData)
    if badStar then
        ClearPendingPlan(requestData.index)
        C.SetApplyStatus(badStar .. " Nothing was changed.", false, true)
        return false
    end

    -- Follow ESO's own purchase sequence: prepare the request, collect every
    -- pending star change, add the Champion Bar slots, validate, then send.
    local respecNeeded = CHAMPION_DATA_MANAGER:IsRespecNeeded()
    PrepareChampionPurchaseRequest(respecNeeded)
    CHAMPION_DATA_MANAGER:CollectUnsavedChanges()

    local startSlot, endSlot = 1, 12
    if GetAssignableChampionBarStartAndEndSlots then
        startSlot, endSlot = GetAssignableChampionBarStartAndEndSlots()
    end

    for slotIndex = startSlot, endSlot do
        local skillId = requestData.slotMap[slotIndex]
        if skillId then
            AddHotbarSlotToChampionPurchaseRequest(slotIndex, skillId)
        end
    end

    local expected = GetExpectedResultForChampionPurchaseRequest and GetExpectedResultForChampionPurchaseRequest() or CHAMPION_PURCHASE_INTERNAL_ERROR
    if expected ~= CHAMPION_PURCHASE_SUCCESS then
        ClearPendingPlan(requestData.index)
        C.SetApplyStatus((ERROR_TEXT[expected] or string.format("ESO rejected the Champion Point request (code %s).", tostring(expected)))
            .. " Nothing was changed.", false, true)
        return false
    end

    local availability = GetChampionPurchaseAvailability and GetChampionPurchaseAvailability() or CHAMPION_PURCHASE_INTERNAL_ERROR
    if availability ~= CHAMPION_PURCHASE_SUCCESS then
        ClearPendingPlan(requestData.index)
        C.SetApplyStatus(ERROR_TEXT[availability] or string.format("Champion Point purchase unavailable (code %s).", tostring(availability)), false, true)
        return false
    end

    Apply.busy = true
    Apply.pendingBuildLabel = buildLabel or "Selected build"
    Apply.pendingTreePlan = requestData.plan
    Apply.pendingTreeCounts = requestData.treePending
    Apply.pendingSkipped = requestData.skipped
    Apply.pendingIndex = requestData.index
    C.SetApplyStatus("APPLYING " .. string.upper(Apply.pendingBuildLabel) .. "…", true, false)

    SendChampionPurchaseRequest()
    return true
end

function Apply.OnPurchaseResult(result)
    if not Apply.busy then return end
    Apply.busy = false

    if result == CHAMPION_PURCHASE_SUCCESS then
        local now = GetFrameTimeSeconds and GetFrameTimeSeconds() or 0
        Apply.nextAllowedTime = now + Apply.cooldownSeconds
        local label = Apply.pendingBuildLabel or "Build"
        local skipped = Apply.pendingSkipped
        if skipped and #skipped > 0 then
            -- short enough for one line; the button already names the setup
            C.SetApplyStatus("Applied! Needs more CP: " .. table.concat(skipped, ", "), true, false)
        else
            C.SetApplyStatus(label .. " applied successfully.", true, false)
        end
        Apply.pendingSkipped = nil
    else
        if Apply.pendingIndex then ClearPendingPlan(Apply.pendingIndex) end
        C.SetApplyStatus(ERROR_TEXT[result] or string.format("ESO rejected the Champion Point request (code %s).", tostring(result)), false, true)
    end
    Apply.pendingIndex = nil

    Apply.pendingBuildLabel = nil
    Apply.pendingTreePlan = nil
    Apply.pendingTreeCounts = nil

    if C.RefreshApplyState then
        zo_callLater(C.RefreshApplyState, 250)
    end
end

-- /cpbis check: compare this character's saved Champion Points with a setup.
-- Returns chat lines. Changes nothing.
function Apply.CheckBuild(build, label)
    local lines = { "|cFF9A4DOne Click CP check:|r " .. (label or "setup") }
    if not CHAMPION_DATA_MANAGER then
        lines[#lines + 1] = "Champion system not ready yet."
        return lines
    end
    local index = GetSkillIndex()
    local targets, slotNames = BuildTargets(build, index)
    local barSlots = GetChampionBarSlots()
    local treeTitle = { warfare = "|c7FB2E5Warfare|r", fitness = "|cFF6B5AFitness|r", craft = "|c8FD17FCraft|r" }

    -- Champion bar: is each setup star slotted?
    local notSlotted = {}
    for _, treeName in ipairs(TREE_NAMES) do
        local slotted = {}
        for _, slotIndex in ipairs(barSlots[treeName]) do
            local id = GetSlotBoundId and GetSlotBoundId(slotIndex, HOTBAR_CATEGORY_CHAMPION)
            if id and id ~= 0 then slotted[id] = true end
        end
        for _, target in ipairs(targets[treeName].list) do
            if target.isSlot and not slotted[target.id] then
                notSlotted[#notSlotted + 1] = zo_strformat("<<1>>", target.name)
            end
        end
    end
    if #notSlotted == 0 then
        lines[#lines + 1] = "Champion bar: |c6FD36Fall setup stars slotted.|r"
    else
        lines[#lines + 1] = "Champion bar: not slotted: " .. table.concat(notSlotted, ", ")
    end

    -- Points per tree: stars below the setup's value, and unspent points.
    for _, treeName in ipairs(TREE_NAMES) do
        local list = targets[treeName].list
        local short, ok = {}, 0
        for _, target in ipairs(list) do
            local data = CHAMPION_DATA_MANAGER:GetChampionSkillData(target.id)
            local have = data and data:GetNumSavedPoints() or 0
            if have >= target.desired then
                ok = ok + 1
            else
                short[#short + 1] = string.format("%s %d/%d", zo_strformat("<<1>>", target.name), have, target.desired)
            end
        end
        local discipline = GetDisciplineDataByType(TREE_TYPE[treeName])
        local unspent = 0
        if discipline and discipline.GetNumSavedUnspentPoints then
            unspent = zo_max(0, discipline:GetNumSavedUnspentPoints() or 0)
        end
        local line = string.format("%s: %d/%d stars as in the setup", treeTitle[treeName], ok, #list)
        if unspent > 0 then line = line .. string.format(", %d points unspent", unspent) end
        if #short > 0 then line = line .. ". Short: " .. table.concat(short, ", ") end
        lines[#lines + 1] = line
    end
    lines[#lines + 1] = "Short stars are normal with fewer CP: the most important ones are filled first."
    return lines
end

function Apply.Initialize()
    EVENT_MANAGER:RegisterForEvent("OCCP_ChampionPurchase", EVENT_CHAMPION_PURCHASE_RESULT, function(_, result)
        Apply.OnPurchaseResult(result)
    end)
end
