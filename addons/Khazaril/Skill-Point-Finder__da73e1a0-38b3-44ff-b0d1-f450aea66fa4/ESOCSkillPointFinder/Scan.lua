-- Skill Point Finder: reads what this character still has to collect.
-- Skyshards, public dungeons and zone stories come from the game's own Zone Guide data.
-- Dungeon quests come from this character's quest history and journal.

local SP = ESOC_SkillPointFinder
local Data = SP.Data
local Scan = {}
SP.Scan = Scan

local cache, dirty = nil, true

function SP.MarkDirty()
    dirty = true
end

local function zoneEntry(state, zoneId)
    if not zoneId or zoneId == 0 then return nil end
    local zone = state.zones[zoneId]
    if zone then return zone end
    local name = SP.Clean(SP.Safe(GetZoneNameById, zoneId) or "")
    if name == "" then return nil end
    local key = string.lower(name)
    zone = {
        id = zoneId, name = name, key = key,
        isBase = Data.BASE_ZONES[key] == true,
        isPvP = Data.PVP_ZONES[key] == true,
        shards = {}, shardsMissing = 0, shardsTotal = 0,
        publics = {},
    }
    state.zones[zoneId] = zone
    state.zoneList[#state.zoneList + 1] = zone
    return zone
end

local function readSkyshards(state)
    local count = SP.Safe(GetNumSkyshards) or 0
    for i = 1, count do
        local id = SP.Safe(GetSkyshardId, i)
        if id and id ~= 0 then
            local zoneId = SP.Safe(GetWorldPositionForSkyshardId, id)
            local zone = zoneEntry(state, SP.RootZone(zoneId))
            if zone then
                local done = SP.Safe(GetSkyshardDiscoveryStatus, id) == SKYSHARD_DISCOVERY_STATUS_ACQUIRED
                zone.shardsTotal = zone.shardsTotal + 1
                state.shardsTotal = state.shardsTotal + 1
                if done then
                    state.shardsFound = state.shardsFound + 1
                else
                    zone.shardsMissing = zone.shardsMissing + 1
                    zone.shards[#zone.shards + 1] = { id = id }
                end
            end
        end
    end
end

-- Every "Group Event" achievement, read once per session a little at a time:
-- the console stops an add-on that uses more than a second of work in one frame.
local achievementIndex = { groupEvents = {}, groupEventList = {}, ready = false }
local indexing, waiting = false, {}
local INDEX_UPDATE = "ESOCSkillPointFinderIndex"

local function look(achievementId)
    if not achievementId or achievementId == 0 then return end
    local raw = SP.Safe(GetAchievementInfo, achievementId)
    if type(raw) ~= "string" then return end
    local lower = string.lower(raw)
    local extra = SP.Data.GROUP_EVENT_EXTRA[lower]
    if extra then
        achievementIndex.groupEvents[SP.Loose(extra)] = achievementId
        local list = achievementIndex.groupEventList
        list[#list + 1] = { id = achievementId, name = SP.Clean(raw), pairsWith = extra }
    elseif string.find(lower, "group event", 1, true) then
        local public = string.match(SP.Loose(raw), "^(.-) group event$")
        if public then
            achievementIndex.groupEvents[public] = achievementId
            local list = achievementIndex.groupEventList
            list[#list + 1] = { id = achievementId, name = SP.Clean(raw) }
        end
    end
end

-- Starts reading achievements (one category or subcategory per frame). onDone runs when finished.
function Scan.StartIndex(onDone)
    if onDone then waiting[#waiting + 1] = onDone end
    if achievementIndex.ready then
        local callbacks = waiting
        waiting = {}
        for _, callback in ipairs(callbacks) do pcall(callback) end
        return
    end
    if indexing then return end
    indexing = true
    local steps = {}
    local numCategories = SP.Safe(GetNumAchievementCategories) or 0
    for c = 1, numCategories do
        local _, numSub, numInCategory = SP.Safe(GetAchievementCategoryInfo, c)
        if (numInCategory or 0) > 0 then steps[#steps + 1] = { c, nil, numInCategory } end
        for sub = 1, numSub or 0 do
            local _, numAchievements = SP.Safe(GetAchievementSubCategoryInfo, c, sub)
            if (numAchievements or 0) > 0 then steps[#steps + 1] = { c, sub, numAchievements } end
        end
    end
    local nextStep = 1
    EVENT_MANAGER:RegisterForUpdate(INDEX_UPDATE, 0, function()
        local step = steps[nextStep]
        if step then
            nextStep = nextStep + 1
            for a = 1, step[3] do look(SP.Safe(GetAchievementId, step[1], step[2], a)) end
            return
        end
        EVENT_MANAGER:UnregisterForUpdate(INDEX_UPDATE)
        achievementIndex.ready, indexing = true, false
        SP.MarkDirty()
        Scan.StartIndex()
    end)
end

function Scan.IndexReady()
    return achievementIndex.ready
end

local function indexAchievements()
    return achievementIndex
end

-- Public dungeon group events (from the Zone Guide, per character) and zone story progress.
local function readZoneStories(state)
    local PUBLIC = ZONE_COMPLETION_TYPE_PUBLIC_DUNGEONS
    local STORY = ZONE_COMPLETION_TYPE_PRIORITY_QUESTS
    local zoneId = SP.Safe(GetNextZoneStoryZoneId, nil)
    local guard = 0
    while zoneId and zoneId ~= 0 and guard < 1000 do
        guard = guard + 1
        local zone = zoneEntry(state, zoneId)
        if zone then
            local groupEvents = indexAchievements().groupEvents
            local count = SP.Safe(GetNumZoneActivitiesForZoneCompletionTypeAndIndex, zoneId, PUBLIC, nil) or 0
            for i = 1, count do
                local name = SP.Clean(SP.Safe(GetZoneStoryActivityNameByActivityIndex, zoneId, PUBLIC, i, nil) or "")
                local key = string.lower(name)
                local achievementId = groupEvents[SP.Loose(name)]
                if not achievementId then
                    for _, event in ipairs(indexAchievements().groupEventList) do
                        if SP.WordsMatch(event.pairsWith or event.name, name) then
                            achievementId = event.id
                            break
                        end
                    end
                end
                if achievementId then state.check.usedGroupEvents[achievementId] = true end
                local achievementDone, perCharacter
                if achievementId then
                    achievementDone = SP.AchievementEarned(achievementId)
                    perCharacter = SP.Safe(GetAchievementPersistenceLevel, achievementId) == ACHIEVEMENT_PERSISTENCE_CHARACTER
                end
                local guideDone = SP.Safe(IsZoneStoryActivityComplete, zoneId, PUBLIC, i, nil) == true
                local ease = zone.isBase and 4 or 3
                if Data.HARD_GROUP_EVENTS[key] then ease = 2 end
                local public = {
                    name = name ~= "" and name or ("Public dungeon " .. i), zone = zone,
                    -- The group event achievement is the one the journal shows, so it counts as done
                    done = guideDone or achievementDone == true,
                    guideDone = guideDone, achievementDone = achievementDone, perCharacter = perCharacter, ease = ease,
                }
                zone.publics[#zone.publics + 1] = public
                state.publics[#state.publics + 1] = public
            end
            local points = Data.STORY_POINTS[zone.key]
            if points then
                local total = SP.Safe(GetNumZoneActivitiesForZoneCompletionTypeAndIndex, zoneId, STORY, nil) or 0
                local done = SP.Safe(GetNumCompletedZoneActivitiesForZoneCompletionTypeAndIndex, zoneId, STORY, nil) or 0
                zone.story = { done = done, total = total, points = points, finished = total > 0 and done >= total }
            end
        end
        zoneId = SP.Safe(GetNextZoneStoryZoneId, zoneId)
    end
end

local function readDungeons(state)
    local byZone, byName, byQuest = {}, {}, {}
    local function add(activityType, field)
        local count = SP.Safe(GetNumActivitiesByType, activityType) or 0
        for i = 1, count do
            local activityId = SP.Safe(GetActivityIdByTypeAndIndex, activityType, i)
            local zoneId = activityId and SP.Safe(GetActivityZoneId, activityId) or 0
            if zoneId ~= 0 then
                local dungeon = byZone[zoneId]
                if not dungeon then
                    local name = SP.Clean(SP.Safe(GetActivityName, activityId) or "")
                    local collectible = SP.Safe(GetRequiredActivityCollectibleId, activityId) or 0
                    dungeon = {
                        zoneId = zoneId, name = name, key = string.lower(name),
                        isDLC = collectible ~= 0,
                        owned = collectible == 0 or SP.Safe(IsCollectibleUnlocked, collectible) == true,
                    }
                    byZone[zoneId] = dungeon
                    byName[SP.Loose(name)] = dungeon
                    local questName = Data.DUNGEON_QUESTS[SP.Loose(name)]
                    if questName then
                        dungeon.storyQuest = questName
                        byQuest[SP.Loose(questName)] = dungeon
                    end
                    state.dungeons[#state.dungeons + 1] = dungeon
                end
                dungeon[field] = activityId
            end
        end
    end
    add(LFG_ACTIVITY_DUNGEON, "normalId")
    add(LFG_ACTIVITY_MASTER_DUNGEON, "vetId")
    state.dungeonByZone = byZone

    local function find(zoneName, objective, zoneIndex, startZoneIndex)
        for _, index in ipairs({ zoneIndex or 0, startZoneIndex or 0 }) do
            if index > 0 then
                local zoneId = SP.Safe(GetZoneId, index)
                if zoneId and byZone[zoneId] then return byZone[zoneId] end
            end
        end
        return byName[SP.Loose(zoneName)] or byName[SP.Loose(objective)]
    end

    -- Quest history (this character only)
    local questId = SP.Safe(GetNextCompletedQuestId, nil)
    local guard = 0
    while questId and guard < 50000 do
        guard = guard + 1
        local name, questType = SP.Safe(GetCompletedQuestInfo, questId)
        local byStory = byQuest[SP.Loose(name)]
        if byStory then
            byStory.questDone, byStory.source, byStory.questName = true, "history", SP.Clean(name)
            state.check.matchedByName = state.check.matchedByName + 1
        elseif questType == QUEST_TYPE_DUNGEON then
            state.check.historyDungeonQuests = state.check.historyDungeonQuests + 1
            local zoneName, objective, zoneIndex = SP.Safe(GetCompletedQuestLocationInfo, questId)
            local dungeon = find(zoneName, objective, zoneIndex)
            if dungeon then
                dungeon.questDone, dungeon.source, dungeon.questName = true, "history", SP.Clean(name)
            else
                state.check.unmatched[#state.check.unmatched + 1] = {
                    name = SP.Clean(name), zone = SP.Clean(zoneName), objective = SP.Clean(objective),
                }
            end
        end
        questId = SP.Safe(GetNextCompletedQuestId, questId)
    end

    -- Journal
    for i = 1, MAX_JOURNAL_QUESTS or 25 do
        local name = SP.Safe(IsValidQuestIndex, i) and SP.Clean(SP.Safe(GetJournalQuestName, i) or "") or ""
        local byStory = name ~= "" and byQuest[SP.Loose(name)]
        if byStory then
            byStory.inJournal, byStory.journalName = true, name
        elseif name ~= "" and SP.Safe(GetJournalQuestType, i) == QUEST_TYPE_DUNGEON then
            local zoneName, objective, zoneIndex = SP.Safe(GetJournalQuestLocationInfo, i)
            local dungeon = find(zoneName, objective, zoneIndex, SP.Safe(GetJournalQuestStartingZone, i))
            if dungeon then
                dungeon.inJournal, dungeon.journalName = true, name
            else
                state.check.journalUnmatched[#state.check.journalUnmatched + 1] = { name = name, zone = SP.Clean(zoneName) }
            end
        end
    end

    for _, dungeon in ipairs(state.dungeons) do
        if not dungeon.questDone and SP.character.dungeonQuests[dungeon.zoneId] then
            dungeon.questDone, dungeon.source = true, "seen"
        end
        if SP.character.overrides[dungeon.zoneId] then
            dungeon.questDone, dungeon.source = true, "manual"
        end
        if dungeon.questDone then dungeon.inJournal = false end
    end
    table.sort(state.dungeons, function(a, b) return a.name < b.name end)
end

function Scan.Get()
    if cache and not dirty then return cache end
    local state = {
        zones = {}, zoneList = {}, publics = {}, dungeons = {},
        shardsTotal = 0, shardsFound = 0,
        check = { unmatched = {}, journalUnmatched = {}, historyDungeonQuests = 0, matchedByName = 0, usedGroupEvents = {} },
    }
    state.indexReady = achievementIndex.ready
    readSkyshards(state)
    readZoneStories(state)
    readDungeons(state)
    table.sort(state.zoneList, function(a, b) return a.name < b.name end)
    cache, dirty = state, false
    return state
end

-- What's left in one zone, honouring the PvP option.
function Scan.ZoneLeft(zone)
    local shards = (zone.isPvP and SP.sv.options.hidePvP) and 0 or zone.shardsMissing
    local publics = 0
    for _, public in ipairs(zone.publics) do
        if not public.done then publics = publics + 1 end
    end
    local story = (zone.story and not zone.story.finished) and zone.story.points or 0
    return { shards = shards, publics = publics, story = story, points = shards / 3 + publics + story }
end

-- Dungeons this character can queue for and hasn't done the quest in.
function Scan.MissingDungeons(state)
    local list = {}
    for _, dungeon in ipairs(state.dungeons) do
        if not dungeon.questDone and dungeon.owned then list[#list + 1] = dungeon end
    end
    return list
end

-- The achievement names found in the game (for the Check tab).
function Scan.Achievements()
    return indexAchievements()
end
