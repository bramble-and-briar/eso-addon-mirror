-- ESO Adventurer Suite
-- Automatic dungeon run history and achievement-based historical import.
-- Exact run timestamps can only be recorded while the addon is loaded; ESO's
-- achievement API is used to recover reliable older completion dates where available.

local EPC = ESOProgressionCoach
EPC.DungeonHistory = EPC.DungeonHistory or {}
local H = EPC.DungeonHistory

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if not ok then return fallback end
    return a, b, c, d, e
end

local function clean(value)
    value = tostring(value or "")
    if type(zo_strformat) == "function" and value ~= "" then
        local ok, formatted = pcall(zo_strformat, "<<C:1>>", value)
        if ok and formatted and formatted ~= "" then value = formatted end
    end
    return value
end

local function nowTimestamp()
    return tonumber(safe(GetTimeStamp, 0)) or tonumber(safe(GetTimeStamp32, 0)) or 0
end

local function currentCharacterId()
    return tostring(safe(GetCurrentCharacterId, "") or "")
end

local function currentCharacterName()
    return clean(safe(GetUnitName, "", "player"))
end

local function currentZoneInfo()
    local zoneIndex = tonumber(safe(GetUnitZoneIndex, 0, "player")) or 0
    local zoneId = 0
    if zoneIndex > 0 and type(GetZoneId) == "function" then
        zoneId = tonumber(safe(GetZoneId, 0, zoneIndex)) or 0
    end
    local name = clean(safe(GetUnitZone, "", "player"))
    if name == "" and zoneId > 0 and type(GetZoneNameById) == "function" then
        name = clean(safe(GetZoneNameById, "", zoneId))
    end
    return zoneId, name, zoneIndex
end

local function currentDifficulty()
    local difficulty = safe(GetCurrentZoneDungeonDifficulty, nil)
    if DUNGEON_DIFFICULTY_VETERAN ~= nil and difficulty == DUNGEON_DIFFICULTY_VETERAN then
        return "VETERAN"
    end
    if DUNGEON_DIFFICULTY_NORMAL ~= nil and difficulty == DUNGEON_DIFFICULTY_NORMAL then
        return "NORMAL"
    end
    -- Preserve the exact mode requested by the Suite queue. This is stored
    -- separately because Dungeon Finder UI state can change after the queue starts.
    local pending = EPC.saved and EPC.saved.dungeonHistory and tostring(EPC.saved.dungeonHistory.pendingDifficulty or ""):upper() or ""
    if pending == "VETERAN" or pending == "NORMAL" then return pending end
    local queued = EPC.DungeonFinder and tostring(EPC.DungeonFinder.difficulty or ""):upper() or ""
    if queued == "VETERAN" or queued == "NORMAL" then return queued end
    return "UNKNOWN"
end

function H:EnsureSaved()
    if not EPC.saved then return nil end
    if type(EPC.saved.dungeonHistory) ~= "table" then EPC.saved.dungeonHistory = {} end
    local s = EPC.saved.dungeonHistory
    if type(s.runs) ~= "table" then s.runs = {} end
    if type(s.importedAchievements) ~= "table" then s.importedAchievements = {} end
    return s
end

function H:RememberQueuedDifficulty(value)
    local s = self:EnsureSaved()
    if not s then return end
    value = tostring(value or ""):upper()
    if value == "VETERAN" or value == "NORMAL" then
        s.pendingDifficulty = value
    end
end

function H:StartRun(source)
    local s = self:EnsureSaved()
    if not s then return end
    local zoneId, zoneName = currentZoneInfo()
    s.activeRun = {
        startedAt = nowTimestamp(),
        zoneId = zoneId,
        zoneName = zoneName,
        difficulty = currentDifficulty(),
        characterId = currentCharacterId(),
        characterName = currentCharacterName(),
        source = tostring(source or "AUTO"),
    }
end

function H:RecordRun(source)
    local s = self:EnsureSaved()
    if not s then return false end
    local completedAt = nowTimestamp()
    local zoneId, zoneName = currentZoneInfo()
    local active = type(s.activeRun) == "table" and s.activeRun or nil
    if (zoneName == "" or zoneId == 0) and active then
        zoneName = zoneName ~= "" and zoneName or tostring(active.zoneName or "")
        zoneId = zoneId ~= 0 and zoneId or tonumber(active.zoneId) or 0
    end

    -- Avoid double inserts if ESO fires the completion/update path more than once.
    local last = s.runs[#s.runs]
    if type(last) == "table" and tonumber(last.completedAt) and completedAt > 0 then
        if tostring(last.characterId or "") == currentCharacterId()
            and tonumber(last.zoneId or 0) == zoneId
            and math.abs(completedAt - tonumber(last.completedAt)) < 60 then
            s.activeRun = nil
            return false
        end
    end

    local startedAt = active and tonumber(active.startedAt) or 0
    local entry = {
        dungeon = zoneName ~= "" and zoneName or "Dungeon",
        zoneId = zoneId,
        difficulty = (active and active.difficulty) or currentDifficulty(),
        startedAt = startedAt,
        completedAt = completedAt,
        durationSeconds = (startedAt > 0 and completedAt >= startedAt) and (completedAt - startedAt) or 0,
        characterId = currentCharacterId(),
        characterName = currentCharacterName(),
        source = tostring(source or "ACTIVITY_FINDER"),
        exactRun = true,
    }
    s.runs[#s.runs + 1] = entry
    s.pendingDifficulty = nil
    -- Keep a generous bounded history so SavedVariables cannot grow forever.
    while #s.runs > 2000 do table.remove(s.runs, 1) end
    s.activeRun = nil
    return true
end

local function isDungeonCategoryName(name)
    name = string.lower(clean(name))
    return name:find("dungeon", 1, true) ~= nil
end

function H:ImportHistoricalDungeonAchievements()
    local s = self:EnsureSaved()
    if not s then return 0 end
    if type(GetNumAchievementCategories) ~= "function" or type(GetAchievementId) ~= "function" then return 0 end
    local imported = 0
    local topCount = tonumber(safe(GetNumAchievementCategories, 0)) or 0

    local function importAchievement(topIndex, subIndex, achievementIndex, categoryName, subName)
        local achievementId = tonumber(safe(GetAchievementId, 0, topIndex, subIndex, achievementIndex)) or 0
        if achievementId <= 0 or s.importedAchievements[tostring(achievementId)] then return end
        if safe(IsAchievementComplete, false, achievementId) ~= true then return end
        local timestamp = tonumber(safe(GetAchievementTimestamp, 0, achievementId)) or 0
        if timestamp <= 0 then return end
        local name, description, _, _, completed, dateText, timeText = safe(GetAchievementInfo, "", achievementId)
        if completed ~= true then return end
        s.importedAchievements[tostring(achievementId)] = {
            achievementId = achievementId,
            name = clean(name),
            description = tostring(description or ""),
            completedAt = timestamp,
            date = tostring(dateText or ""),
            time = tostring(timeText or ""),
            category = clean(categoryName),
            subcategory = clean(subName),
            source = "ESO_ACHIEVEMENT",
            exactRun = false,
        }
        imported = imported + 1
    end

    for top = 1, topCount do
        local categoryName, numSub, numAchievements = safe(GetAchievementCategoryInfo, "", top)
        numSub = tonumber(numSub) or 0
        numAchievements = tonumber(numAchievements) or 0
        if isDungeonCategoryName(categoryName) then
            for i = 1, numAchievements do importAchievement(top, nil, i, categoryName, "") end
        end
        for sub = 1, numSub do
            local subName, subAchievements = safe(GetAchievementSubCategoryInfo, "", top, sub)
            subAchievements = tonumber(subAchievements) or 0
            if isDungeonCategoryName(categoryName) or isDungeonCategoryName(subName) then
                for i = 1, subAchievements do importAchievement(top, sub, i, categoryName, subName) end
            end
        end
    end
    s.historicalAchievementImportComplete = true
    s.historicalAchievementImportAt = nowTimestamp()
    return imported
end

function H:GetHistory()
    local s = self:EnsureSaved()
    return s and s.runs or {}, s and s.importedAchievements or {}
end

function H:OnActivityFinderStatus(status)
    if ACTIVITY_FINDER_STATUS_IN_PROGRESS ~= nil and status == ACTIVITY_FINDER_STATUS_IN_PROGRESS then
        if safe(IsUnitInDungeon, false, "player") == true then self:StartRun("ACTIVITY_FINDER") end
    end
end

function H:Initialize()
    local s = self:EnsureSaved()
    if not s then return end
    local prefix = EPC.name .. "_DungeonHistory"

    if EVENT_ACTIVITY_FINDER_STATUS_UPDATE ~= nil then
        EPC.Runtime:RegisterEvent("DungeonHistory", "Status", EVENT_ACTIVITY_FINDER_STATUS_UPDATE,
            function(_, status) self:OnActivityFinderStatus(status) end)
    end
    if EVENT_ACTIVITY_FINDER_ACTIVITY_COMPLETE ~= nil then
        EPC.Runtime:RegisterEvent("DungeonHistory", "Complete", EVENT_ACTIVITY_FINDER_ACTIVITY_COMPLETE,
            function() self:RecordRun("ACTIVITY_FINDER") end)
    end
    if EVENT_PLAYER_ACTIVATED ~= nil then
        EPC.Runtime:RegisterEvent("DungeonHistory", "Activated", EVENT_PLAYER_ACTIVATED, function()
            if safe(IsUnitInDungeon, false, "player") == true and type(s.activeRun) ~= "table" then
                self:StartRun("AUTO_DETECTED")
            end
        end)
    end

    -- Import reliable historical completion dates exposed by ESO achievements.
    -- These are evidence of prior dungeon completions, not a reconstruction of
    -- every individual run; the game does not expose a complete pre-addon run log.
    if s.historicalAchievementImportComplete ~= true then
        if type(zo_callLater) == "function" then
            zo_callLater(function() self:ImportHistoricalDungeonAchievements() end, 1500)
        else
            self:ImportHistoricalDungeonAchievements()
        end
    end
end
