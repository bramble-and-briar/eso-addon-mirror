-- High Achiever: works out where you are and which achievements belong there.
-- Sources: the Zone Guide's own achievement links for the zone, achievement categories
-- named after the place, and achievements whose name or description names the place.

local HA = ESOC_HighAchiever
local Place = {}
HA.Place = Place

local cache, dirty = nil, true

function Place.MarkDirty()
    dirty = true
end

local ZONE_GUIDE_TYPES = {
    "ZONE_COMPLETION_TYPE_FEATURED_ACHIEVEMENTS", "ZONE_COMPLETION_TYPE_PUBLIC_DUNGEONS",
    "ZONE_COMPLETION_TYPE_DELVES", "ZONE_COMPLETION_TYPE_GROUP_DELVES", "ZONE_COMPLETION_TYPE_GROUP_BOSSES",
    "ZONE_COMPLETION_TYPE_WORLD_EVENTS", "ZONE_COMPLETION_TYPE_SKYSHARDS", "ZONE_COMPLETION_TYPE_PRIORITY_QUESTS",
    "ZONE_COMPLETION_TYPE_POINTS_OF_INTEREST", "ZONE_COMPLETION_TYPE_WAYSHRINES", "ZONE_COMPLETION_TYPE_SET_STATIONS",
    "ZONE_COMPLETION_TYPE_MUNDUS_STONES", "ZONE_COMPLETION_TYPE_STRIKING_LOCALES", "ZONE_COMPLETION_TYPE_MAGES_GUILD_BOOKS",
}

-- The names to look for: "the rift" stays whole (one word on its own is too loose), but
-- "the banished cells i" is also searched as "banished cells i".
local function namesFor(name)
    local lower = HA.Lower(name)
    local names = { lower }
    local rest = string.match(lower, "^the (.+)$")
    if rest and string.find(rest, " ", 1, true) then names[#names + 1] = rest end
    return names
end

-- Where the player is now.
function Place.Current()
    local zoneId = HA.PlayerZoneId()
    local rootId = HA.RootZone(zoneId)
    local inside = zoneId ~= 0 and zoneId ~= rootId
    local placeId = inside and zoneId or rootId
    local place = {
        id = placeId,
        zoneId = zoneId,
        rootId = rootId,
        inside = inside,
        name = HA.Clean(HA.Safe(GetZoneNameById, placeId) or ""),
        rootName = HA.Clean(HA.Safe(GetZoneNameById, rootId) or ""),
    }
    local difficulty = HA.Safe(GetCurrentZoneDungeonDifficulty)
    place.veteran = DUNGEON_DIFFICULTY_VETERAN ~= nil and difficulty == DUNGEON_DIFFICULTY_VETERAN
    place.normal = DUNGEON_DIFFICULTY_NORMAL ~= nil and difficulty == DUNGEON_DIFFICULTY_NORMAL
    if place.name == "" then place.name = "Here" end
    return place
end

local function progressOf(achievementId)
    local count = HA.Safe(GetAchievementNumCriteria, achievementId) or 0
    local partsDone, share, nextStep = 0, 0, nil
    local single
    for i = 1, count do
        local description, numCompleted, numRequired = HA.Safe(GetAchievementCriterion, achievementId, i)
        numCompleted, numRequired = numCompleted or 0, numRequired or 1
        if numRequired < 1 then numRequired = 1 end
        local part = math.min(numCompleted, numRequired) / numRequired
        share = share + part
        if numCompleted >= numRequired then
            partsDone = partsDone + 1
        elseif not nextStep and description and description ~= "" then
            nextStep = HA.Clean(description)
        end
        if count == 1 then single = { numCompleted, numRequired } end
    end
    local progress = { fraction = count > 0 and share / count or 0, nextStep = nextStep }
    if single and single[2] > 1 then
        progress.text = math.min(single[1], single[2]) .. " of " .. single[2]
    elseif count > 1 then
        progress.text = partsDone .. " of " .. count .. " done"
    end
    -- One step with nothing to count: the step itself is all there is to say
    if count == 1 and single and single[2] == 1 and progress.nextStep then
        progress.text = nil
    end
    return progress
end

local function rewardOf(achievementId)
    local hasCollectible, collectibleId = HA.Safe(GetAchievementRewardCollectible, achievementId)
    if hasCollectible and collectibleId and collectibleId ~= 0 then
        local kind
        local categoryType = HA.Safe(GetCollectibleCategoryType, collectibleId)
        if categoryType then kind = HA.Safe(GetString, "SI_COLLECTIBLECATEGORYTYPE", categoryType) end
        if not kind or kind == "" then kind = "Collectible" end
        return { kind = HA.Clean(kind), text = HA.Clean(HA.Safe(GetCollectibleName, collectibleId) or "") }
    end
    local hasTitle, titleName = HA.Safe(GetAchievementRewardTitle, achievementId)
    if hasTitle and titleName and titleName ~= "" then return { kind = "Title", text = HA.Clean(titleName) } end
    local hasDye, dyeId = HA.Safe(GetAchievementRewardDye, achievementId)
    if hasDye and dyeId and dyeId ~= 0 then
        return { kind = "Dye", text = HA.Clean(HA.Safe(GetDyeInfoById, dyeId) or "") }
    end
    local hasItem, itemName = HA.Safe(GetAchievementRewardItem, achievementId)
    if hasItem and itemName and itemName ~= "" then return { kind = "Item", text = HA.Clean(itemName) } end
    return nil
end

-- One achievement, or one line of achievements (tier 1, 2, 3), as it stands for this character.
local function entryFor(achievementId)
    local first = HA.Safe(GetFirstAchievementInLine, achievementId)
    if not first or first == 0 then first = achievementId end
    local stages, current, stageNumber = {}, nil, nil
    local id, guard = first, 0
    while id and id ~= 0 and guard < 20 do
        guard = guard + 1
        stages[#stages + 1] = id
        if not current and not HA.Earned(id) then
            current = id
            stageNumber = #stages
        end
        local nextId = HA.Safe(GetNextAchievementInLine, id)
        if nextId == id then break end
        id = nextId
    end
    if #stages == 0 then stages[1] = achievementId end
    local done = current == nil
    local shown = current or stages[#stages]
    local name, description, _, _, _, date = HA.Safe(GetAchievementInfo, shown)
    local entry = {
        id = shown,
        lineId = first,
        name = HA.Clean(name or ""),
        description = HA.Clean(description or ""),
        done = done,
        date = date,
        reward = rewardOf(shown),
        veteranOnly = string.find(HA.Lower(description or ""), "veteran", 1, true) ~= nil,
    }
    if #stages > 1 then entry.stage = (stageNumber or #stages) .. " of " .. #stages end
    if not done then
        local progress = progressOf(shown)
        entry.fraction = progress.fraction
        entry.progressText = progress.text
        entry.nextStep = progress.nextStep
    else
        entry.fraction = 1
    end
    return entry
end

local function byCloseness(a, b)
    if a.fraction ~= b.fraction then return a.fraction > b.fraction end
    return a.name < b.name
end

-- Every achievement for where you are now, with how far this character has got.
function Place.Build()
    local place = Place.Current()
    local result = {
        place = place, entries = {}, todo = {}, doneList = {}, rewards = {},
        sources = { zoneGuide = 0, category = 0, name = 0, description = 0 },
        indexReady = HA.Index.Ready(), indexSize = #HA.Index.Entries(),
    }
    local found, order = {}, {}
    local function take(achievementId, source)
        if not achievementId or achievementId == 0 or found[achievementId] then return end
        found[achievementId] = source
        order[#order + 1] = achievementId
        result.sources[source] = result.sources[source] + 1
    end

    -- The Zone Guide's own links, for the zone itself (not inside a dungeon or delve)
    if not place.inside and place.rootId ~= 0 then
        for _, typeName in ipairs(ZONE_GUIDE_TYPES) do
            local completionType = _G[typeName]
            if completionType then
                local count = HA.Safe(GetNumAssociatedAchievementsForZoneCompletionType, place.rootId, completionType) or 0
                for i = 1, count do
                    take(HA.Safe(GetAssociatedAchievementIdForZoneCompletionType, place.rootId, completionType, i), "zoneGuide")
                end
            end
        end
    end

    local names = namesFor(place.name)
    if place.name ~= "Here" then
        for _, item in ipairs(HA.Index.Entries()) do
            if not found[item.id] then
                for _, name in ipairs(names) do
                    if item.sub == name or (item.sub == "" and item.top == name) then
                        take(item.id, "category")
                        break
                    elseif HA.HasName(item.name, name) then
                        take(item.id, "name")
                        break
                    elseif HA.HasName(item.desc, name) then
                        take(item.id, "description")
                        break
                    end
                end
            end
        end
    end

    local lines = {}
    for _, achievementId in ipairs(order) do
        local ok, entry = pcall(entryFor, achievementId)
        if ok and entry and entry.name ~= "" and not lines[entry.lineId] then
            lines[entry.lineId] = true
            entry.source = found[achievementId]
            result.entries[#result.entries + 1] = entry
            if entry.done then
                result.doneList[#result.doneList + 1] = entry
            else
                result.todo[#result.todo + 1] = entry
                if entry.reward then result.rewards[#result.rewards + 1] = entry end
            end
        end
    end
    table.sort(result.todo, byCloseness)
    table.sort(result.rewards, byCloseness)
    table.sort(result.doneList, function(a, b) return a.name < b.name end)
    result.total = #result.entries
    result.done = #result.doneList
    return result
end

-- Cached until you move or an achievement changes.
function Place.Get()
    local here = HA.PlayerZoneId()
    if dirty or not cache or cache.place.zoneId ~= here then
        cache = Place.Build()
        dirty = false
    end
    return cache
end
