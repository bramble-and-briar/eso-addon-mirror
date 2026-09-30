-- ESO Adventurer Suite
-- Persistent history for non-dungeon endgame/group/PvP activities.
-- Exact future records are captured when ESO exposes completion/session events.
-- Older completion evidence is imported from achievement timestamps where available.

local EPC = ESOProgressionCoach
EPC.ActivityRunHistory = EPC.ActivityRunHistory or {}
local H = EPC.ActivityRunHistory

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

local function lower(value) return string.lower(clean(value)) end
local function nowTimestamp() return tonumber(safe(GetTimeStamp, 0)) or tonumber(safe(GetTimeStamp32, 0)) or 0 end
local function charId() return tostring(safe(GetCurrentCharacterId, "") or "") end
local function charName() return clean(safe(GetUnitName, "", "player")) end

local function zoneInfo()
    local index = tonumber(safe(GetUnitZoneIndex, 0, "player")) or 0
    local id = 0
    if index > 0 and type(GetZoneId) == "function" then id = tonumber(safe(GetZoneId, 0, index)) or 0 end
    local name = clean(safe(GetUnitZone, "", "player"))
    if name == "" and id > 0 and type(GetZoneNameById) == "function" then name = clean(safe(GetZoneNameById, "", id)) end
    return id, name, index
end

local KNOWN_ARENAS = {
    ["dragonstar arena"] = true, ["maelstrom arena"] = true, ["blackrose prison"] = true,
    ["vateshran hollows"] = true, ["endless archive"] = true, ["infinite archive"] = true,
}

local function difficultyLabel()
    local d = safe(GetCurrentZoneDungeonDifficulty, nil)
    if DUNGEON_DIFFICULTY_VETERAN ~= nil and d == DUNGEON_DIFFICULTY_VETERAN then return "VETERAN" end
    if DUNGEON_DIFFICULTY_NORMAL ~= nil and d == DUNGEON_DIFFICULTY_NORMAL then return "NORMAL" end
    return "N/A"
end

local function classifyZone()
    local _, name = zoneInfo()
    local n = lower(name)
    if type(IsUnitInBattleground) == "function" and safe(IsUnitInBattleground, false, "player") == true then
        return "BATTLEGROUND", "BATTLEGROUND"
    end
    if n:find("infinite archive", 1, true) or n:find("endless archive", 1, true) then
        return "ARCHIVE", difficultyLabel()
    end
    if KNOWN_ARENAS[n] or n:find(" arena", 1, true) or n:find("arena ", 1, true) then
        return "ARENA", difficultyLabel()
    end
    if safe(IsUnitInDungeon, false, "player") == true then
        local groupSize = tonumber(safe(GetGroupSize, 0)) or 0
        if groupSize >= 8 then return "TRIAL", difficultyLabel() end
    end
    if safe(IsActiveWorldBattleground, false) == true then
        return "PVP", "PVP"
    end
    if n:find("cyrodiil", 1, true) or n:find("imperial city", 1, true) then
        return "PVP", "PVP"
    end
    return nil, nil
end

function H:EnsureSaved()
    if not EPC.saved then return nil end
    if type(EPC.saved.activityRunHistory) ~= "table" then EPC.saved.activityRunHistory = {} end
    local s = EPC.saved.activityRunHistory
    if type(s.runs) ~= "table" then s.runs = {} end
    if type(s.importedAchievements) ~= "table" then s.importedAchievements = {} end
    return s
end

function H:StartSession(category, mode, source)
    local s = self:EnsureSaved()
    if not s or not category then return end
    local zid, zname = zoneInfo()
    local active = s.activeSession
    if type(active) == "table" and tostring(active.category) == tostring(category) and tonumber(active.zoneId or 0) == zid then return end
    s.activeSession = {
        category = category, mode = mode or "N/A", startedAt = nowTimestamp(),
        zoneId = zid, zoneName = zname, characterId = charId(), characterName = charName(), source = source or "AUTO",
    }
end

function H:Record(category, mode, source, completed)
    local s = self:EnsureSaved()
    if not s or not category then return false end
    local now = nowTimestamp()
    local zid, zname = zoneInfo()
    local active = type(s.activeSession) == "table" and s.activeSession or nil
    if zname == "" and active then zname = tostring(active.zoneName or "") end
    if zid == 0 and active then zid = tonumber(active.zoneId) or 0 end
    local last = s.runs[#s.runs]
    if type(last) == "table" and tostring(last.category) == tostring(category)
        and tostring(last.characterId or "") == charId()
        and tonumber(last.zoneId or 0) == zid
        and math.abs(now - (tonumber(last.completedAt) or 0)) < 60 then
        s.activeSession = nil
        return false
    end
    local started = active and tonumber(active.startedAt) or 0
    s.runs[#s.runs + 1] = {
        category = category,
        activity = zname ~= "" and zname or category,
        zoneId = zid,
        mode = mode or (active and active.mode) or "N/A",
        startedAt = started,
        completedAt = now,
        durationSeconds = (started > 0 and now >= started) and (now - started) or 0,
        characterId = charId(), characterName = charName(), source = source or "AUTO",
        completed = completed ~= false, exactRun = true,
    }
    while #s.runs > 15000 do table.remove(s.runs, 1) end
    s.activeSession = nil
    return true
end

function H:RecordCurrent(source)
    local category, mode = classifyZone()
    if category then return self:Record(category, mode, source or "AUTO", true) end
    return false
end

local function classifyAchievement(categoryName, subName, achievementName, description)
    local evidence = lower(table.concat({categoryName or "", subName or "", achievementName or "", description or ""}, " "))
    if evidence:find("battleground", 1, true) then return "BATTLEGROUND" end
    if evidence:find("trial", 1, true) or evidence:find("trials", 1, true) then return "TRIAL" end
    if evidence:find("arena", 1, true) or evidence:find("maelstrom", 1, true) or evidence:find("vateshran", 1, true) or evidence:find("blackrose", 1, true) or evidence:find("dragonstar", 1, true) then return "ARENA" end
    if evidence:find("infinite archive", 1, true) or evidence:find("endless archive", 1, true) then return "ARCHIVE" end
    if evidence:find("alliance war", 1, true) or evidence:find("cyrodiil", 1, true) or evidence:find("imperial city", 1, true) or evidence:find("player versus player", 1, true) then return "PVP" end
    return nil
end

local function historicalMode(category, name, description)
    local e = lower(tostring(name or "") .. " " .. tostring(description or ""))
    if category == "PVP" then return "PVP" end
    if category == "BATTLEGROUND" then return "BATTLEGROUND" end
    if e:find("veteran", 1, true) or e:find("hard mode", 1, true) or e:find("conqueror", 1, true) or e:find("challenger", 1, true) then return "VETERAN" end
    return "HISTORICAL - MODE NOT EXPOSED"
end

function H:ImportHistoricalAchievements()
    local s = self:EnsureSaved()
    if not s or type(GetNumAchievementCategories) ~= "function" or type(GetAchievementId) ~= "function" then return 0 end
    local imported = 0
    local topCount = tonumber(safe(GetNumAchievementCategories, 0)) or 0
    local function inspect(top, sub, idx, cat, subName)
        local id = tonumber(safe(GetAchievementId, 0, top, sub, idx)) or 0
        if id <= 0 or s.importedAchievements[tostring(id)] then return end
        if safe(IsAchievementComplete, false, id) ~= true then return end
        local ts = tonumber(safe(GetAchievementTimestamp, 0, id)) or 0
        if ts <= 0 then return end
        local name, description, _, _, completed, dateText, timeText = safe(GetAchievementInfo, "", id)
        if completed ~= true then return end
        local kind = classifyAchievement(cat, subName, name, description)
        if not kind then return end
        s.importedAchievements[tostring(id)] = {
            achievementId = id, category = kind, activity = clean(name), description = tostring(description or ""),
            mode = historicalMode(kind, name, description), completedAt = ts,
            date = tostring(dateText or ""), time = tostring(timeText or ""), source = "ESO_ACHIEVEMENT", exactRun = false,
        }
        imported = imported + 1
    end
    for top = 1, topCount do
        local cat, numSub, numAchievements = safe(GetAchievementCategoryInfo, "", top)
        numSub, numAchievements = tonumber(numSub) or 0, tonumber(numAchievements) or 0
        for i = 1, numAchievements do inspect(top, nil, i, cat, "") end
        for sub = 1, numSub do
            local subName, n = safe(GetAchievementSubCategoryInfo, "", top, sub)
            n = tonumber(n) or 0
            for i = 1, n do inspect(top, sub, i, cat, subName) end
        end
    end
    s.historicalImportComplete = true
    s.historicalImportAt = nowTimestamp()
    return imported
end

function H:GetHistory()
    local s = self:EnsureSaved()
    return s and s.runs or {}, s and s.importedAchievements or {}
end

function H:OnActivated()
    local category, mode = classifyZone()
    if category then self:StartSession(category, mode, "ZONE_ENTER") end
end

function H:OnDeactivated()
    local s = self:EnsureSaved()
    if not s or type(s.activeSession) ~= "table" then return end
    local active = s.activeSession
    -- Open-world PvP is session-based rather than a single completion event.
    if active.category == "PVP" then self:Record("PVP", active.mode or "PVP", "ZONE_SESSION", false) end
end

function H:Initialize()
    local s = self:EnsureSaved()
    if not s then return end
    local prefix = EPC.name .. "_ActivityRunHistory"
    if EVENT_PLAYER_ACTIVATED ~= nil then EPC.Runtime:RegisterEvent("ActivityRunHistory", "Activated", EVENT_PLAYER_ACTIVATED, function() self:OnActivated() end) end
    if EVENT_PLAYER_DEACTIVATED ~= nil then EPC.Runtime:RegisterEvent("ActivityRunHistory", "Deactivated", EVENT_PLAYER_DEACTIVATED, function() self:OnDeactivated() end) end
    if EVENT_ACTIVITY_FINDER_ACTIVITY_COMPLETE ~= nil then
        EPC.Runtime:RegisterEvent("ActivityRunHistory", "FinderComplete", EVENT_ACTIVITY_FINDER_ACTIVITY_COMPLETE, function() self:RecordCurrent("ACTIVITY_FINDER") end)
    end
    if EVENT_RAID_TRIAL_COMPLETE ~= nil then
        EPC.Runtime:RegisterEvent("ActivityRunHistory", "TrialComplete", EVENT_RAID_TRIAL_COMPLETE, function() self:Record("TRIAL", difficultyLabel(), "TRIAL_COMPLETE", true) end)
    end
    if EVENT_BATTLEGROUND_STATE_CHANGED ~= nil then
        EPC.Runtime:RegisterEvent("ActivityRunHistory", "BGState", EVENT_BATTLEGROUND_STATE_CHANGED, function(_, oldState, newState)
            if BATTLEGROUND_STATE_RUNNING ~= nil and newState == BATTLEGROUND_STATE_RUNNING then self:StartSession("BATTLEGROUND", "BATTLEGROUND", "BG_STATE") end
            if BATTLEGROUND_STATE_FINISHED ~= nil and newState == BATTLEGROUND_STATE_FINISHED then self:Record("BATTLEGROUND", "BATTLEGROUND", "BG_FINISHED", true) end
        end)
    end
    if s.historicalImportComplete ~= true then
        if type(zo_callLater) == "function" then zo_callLater(function() self:ImportHistoricalAchievements() end, 1900)
        else self:ImportHistoricalAchievements() end
    end
end
