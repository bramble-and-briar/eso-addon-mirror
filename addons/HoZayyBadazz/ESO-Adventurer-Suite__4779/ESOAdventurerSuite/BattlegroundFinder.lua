-- ESO Adventurer Suite
-- Battleground Finder - live ESO Activity Finder battleground sets
local EPC = ESOProgressionCoach
EPC.BattlegroundFinder = EPC.BattlegroundFinder or {}
local B = EPC.BattlegroundFinder

B.PAGE_SIZE = 10
B.page = B.page or 1
B.showLocked = B.showLocked == true
B.selectedId = B.selectedId or nil
B.lastQueueKind = B.lastQueueKind or nil
B.lastQueuedName = B.lastQueuedName or nil

local function message(text)
    if EPC and type(EPC.Print) == "function" then EPC:Print(text)
    elseif type(d) == "function" then d("[EAS] " .. tostring(text)) end
end

local function cleanName(value)
    local name = tostring(value or "")
    if type(zo_strformat) == "function" and name ~= "" then
        local ok, formatted = pcall(zo_strformat, "<<C:1>>", name)
        if ok and type(formatted) == "string" and formatted ~= "" then name = formatted end
    end
    return name
end

local function safeMethod(object, methodName, default, ...)
    if not object then return default end
    local fn = object[methodName]
    if type(fn) ~= "function" then return default end
    local ok, a, b, c, d = pcall(fn, object, ...)
    if not ok then return default end
    if a == nil then return default end
    return a, b, c, d
end

function B:GetBattlegroundActivityTypes()
    local types = {}
    local seen = {}
    local candidates = {
        rawget(_G, "LFG_ACTIVITY_BATTLE_GROUND_LOW_LEVEL"),
        rawget(_G, "LFG_ACTIVITY_BATTLE_GROUND_CHAMPION"),
        rawget(_G, "LFG_ACTIVITY_BATTLE_GROUND_NON_CHAMPION"),
    }
    for _, activityType in ipairs(candidates) do
        if type(activityType) == "number" and not seen[activityType] then
            seen[activityType] = true
            types[#types + 1] = activityType
        end
    end
    return types
end

function B:IsBattlegroundActivityType(activityType)
    activityType = tonumber(activityType)
    if not activityType then return false end
    for _, bgType in ipairs(self:GetBattlegroundActivityTypes()) do
        if activityType == bgType then return true end
    end
    return false
end

function B:IsDungeonActivityType(activityType)
    activityType = tonumber(activityType)
    if not activityType then return false end
    return (rawget(_G, "LFG_ACTIVITY_DUNGEON") ~= nil and activityType == LFG_ACTIVITY_DUNGEON)
        or (rawget(_G, "LFG_ACTIVITY_MASTER_DUNGEON") ~= nil and activityType == LFG_ACTIVITY_MASTER_DUNGEON)
end

function B:GetRootManager()
    return rawget(_G, "ZO_ACTIVITY_FINDER_ROOT_MANAGER")
end

function B:RefreshRootData()
    local rootManager = self:GetRootManager()
    if rootManager and type(rootManager.UpdateLocationData) == "function" then
        pcall(rootManager.UpdateLocationData, rootManager)
    end
end

function B:BuildLocations(forceRefresh)
    local rootManager = self:GetRootManager()
    if not rootManager or type(rootManager.GetLocationsData) ~= "function" then
        self.locations = {}
        self.lastBuildReason = "ESO Battleground Finder data is not ready yet."
        return self.locations
    end
    if forceRefresh then self:RefreshRootData() end

    local byName = {}
    for _, activityType in ipairs(self:GetBattlegroundActivityTypes()) do
        local ok, locations = pcall(rootManager.GetLocationsData, rootManager, activityType)
        if ok and type(locations) == "table" then
            for _, location in ipairs(locations) do
                local isSet = safeMethod(location, "IsSetEntryType", false) == true
                if isSet then
                    local active = safeMethod(location, "IsActive", true) ~= false
                    local locked = safeMethod(location, "IsLocked", false) == true
                    if active then
                        local id = tonumber(safeMethod(location, "GetId", 0)) or 0
                        local rawName = cleanName(safeMethod(location, "GetRawName", "Battleground"))
                        if rawName == "" then rawName = cleanName(safeMethod(location, "GetNameKeyboard", "Battleground")) end
                        local key = string.lower(rawName):gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%s+", " ")
                        local minGroup, maxGroup = safeMethod(location, "GetGroupSizeRange", 1)
                        local entry = {
                            id = id,
                            activityType = activityType,
                            location = location,
                            name = rawName,
                            description = tostring(safeMethod(location, "GetDescription", "") or ""),
                            locked = locked,
                            active = active,
                            lockReason = tostring(safeMethod(location, "GetLockReasonText", "") or ""),
                            minGroupSize = tonumber(minGroup) or 1,
                            maxGroupSize = tonumber(maxGroup) or tonumber(minGroup) or 1,
                            dailyReady = safeMethod(location, "IsEligibleForDailyReward", false) == true,
                            soloBonus = safeMethod(location, "HasSoloBonus", false) == true,
                        }
                        local old = byName[key]
                        -- The same queue can exist for multiple level/CP activity types.
                        -- Prefer the unlocked live variant so the player sees one usable row.
                        if not old or (old.locked and not entry.locked) then byName[key] = entry end
                    end
                end
            end
        end
    end

    local rows = {}
    for _, entry in pairs(byName) do
        if self.showLocked or not entry.locked then rows[#rows + 1] = entry end
    end
    table.sort(rows, function(a, b)
        if a.locked ~= b.locked then return not a.locked end
        return string.lower(a.name or "") < string.lower(b.name or "")
    end)
    self.locations = rows
    self.lastBuildReason = #rows > 0 and "" or (self.showLocked and "No Battleground queues are exposed by ESO right now." or "No available Battleground queues. Switch to ALL to see locked entries.")

    local selectedFound = false
    for _, entry in ipairs(rows) do
        if self.selectedId and entry.id == self.selectedId then selectedFound = true break end
    end
    if not selectedFound then
        self.selectedId = rows[1] and rows[1].id or nil
    end

    local pageCount = math.max(1, math.ceil(#rows / self.PAGE_SIZE))
    self.page = math.max(1, math.min(tonumber(self.page) or 1, pageCount))
    return rows
end

function B:GetSelected()
    local rows = self.locations or self:BuildLocations(false)
    for _, entry in ipairs(rows) do
        if entry.id == self.selectedId then return entry end
    end
    return rows[1]
end

function B:SelectRow(visibleIndex)
    local rows = self.locations or self:BuildLocations(false)
    local globalIndex = ((tonumber(self.page) or 1) - 1) * self.PAGE_SIZE + (tonumber(visibleIndex) or 1)
    local entry = rows[globalIndex]
    if entry then self.selectedId = entry.id end
    return entry
end

function B:ChangePage(delta)
    local rows = self.locations or self:BuildLocations(false)
    local pages = math.max(1, math.ceil(#rows / self.PAGE_SIZE))
    self.page = math.max(1, math.min(pages, (tonumber(self.page) or 1) + (tonumber(delta) or 0)))
end

function B:SetShowLocked(showLocked)
    self.showLocked = showLocked == true
    self.page = 1
    self:BuildLocations(false)
end

function B:IsQueued()
    if type(IsCurrentlySearchingForGroup) == "function" then
        local ok, queued = pcall(IsCurrentlySearchingForGroup)
        if ok and queued then return true end
    end
    if type(GetActivityFinderStatus) == "function" then
        local ok, status = pcall(GetActivityFinderStatus)
        if ok then
            return (rawget(_G, "ACTIVITY_FINDER_STATUS_QUEUED") ~= nil and status == ACTIVITY_FINDER_STATUS_QUEUED)
                or (rawget(_G, "ACTIVITY_FINDER_STATUS_READY_CHECK") ~= nil and status == ACTIVITY_FINDER_STATUS_READY_CHECK)
        end
    end
    return false
end

function B:QueueSelected()
    local selected = self:GetSelected()
    if not selected then message("Select a Battleground queue first."); return false end
    if selected.locked then
        message(selected.lockReason ~= "" and selected.lockReason or "That Battleground queue is locked.")
        return false
    end
    if self:IsQueued() then message("You are already in an Activity Finder queue."); return false end
    if type(ClearActivityFinderSearch) ~= "function" or type(StartActivityFinderSearch) ~= "function" then
        message("ESO Activity Finder API is unavailable on this client.")
        return false
    end
    if not selected.location or type(selected.location.AddActivitySearchEntry) ~= "function" then
        message("ESO did not expose a queue action for that Battleground set.")
        return false
    end

    pcall(ClearActivityFinderSearch)
    local okAdd = pcall(selected.location.AddActivitySearchEntry, selected.location)
    if not okAdd then message("Could not add that Battleground queue."); return false end
    local ok, result = pcall(StartActivityFinderSearch)
    if not ok then message("ESO rejected the Battleground queue request."); return false end
    if rawget(_G, "ACTIVITY_QUEUE_RESULT_SUCCESS") ~= nil and result ~= ACTIVITY_QUEUE_RESULT_SUCCESS then
        if type(ZO_AlertEvent) == "function" and rawget(_G, "EVENT_ACTIVITY_QUEUE_RESULT") ~= nil then
            pcall(ZO_AlertEvent, EVENT_ACTIVITY_QUEUE_RESULT, result)
        end
        message("ESO rejected the Battleground queue request.")
        return false
    end
    self.lastQueueKind = "BATTLEGROUND"
    self.lastQueuedName = selected.name
    message(string.format("Battleground queue requested: %s", tostring(selected.name or "Battleground")))
    return true
end

function B:CancelQueue()
    if type(CancelGroupSearches) ~= "function" then message("Cancel queue API is unavailable."); return false end
    local ok = pcall(CancelGroupSearches)
    if ok then message("Activity Finder queue canceled.") end
    return ok
end

function B:FindAnySetById(setId)
    setId = tonumber(setId) or 0
    if setId <= 0 then return nil, nil end
    local rootManager = self:GetRootManager()
    if not rootManager or type(rootManager.GetLocationsData) ~= "function" then return nil, nil end
    local ok, allData = pcall(rootManager.GetLocationsData, rootManager)
    if not ok or type(allData) ~= "table" then return nil, nil end
    for activityType, locations in pairs(allData) do
        if type(locations) == "table" then
            for _, location in ipairs(locations) do
                local id = tonumber(safeMethod(location, "GetId", 0)) or 0
                if id == setId and safeMethod(location, "IsSetEntryType", false) == true then
                    return location, tonumber(activityType)
                end
            end
        end
    end
    return nil, nil
end

function B:GetCurrentQueueInfo()
    local info = { kind = "ACTIVITY", name = "Activity Finder queue", requestNames = {} }
    local sawBattleground, sawDungeon, sawOther = false, false, false
    local count = 0
    if type(GetNumActivityRequests) == "function" and type(GetActivityRequestIds) == "function" then
        local okCount, requestCount = pcall(GetNumActivityRequests)
        requestCount = okCount and tonumber(requestCount) or 0
        for i = 1, requestCount do
            local okIds, activityId, setId = pcall(GetActivityRequestIds, i)
            if okIds then
                activityId = tonumber(activityId) or 0
                setId = tonumber(setId) or 0
                local activityType, requestName
                if activityId > 0 then
                    if type(GetActivityType) == "function" then
                        local okType, value = pcall(GetActivityType, activityId)
                        if okType then activityType = tonumber(value) end
                    end
                    if type(GetActivityName) == "function" then
                        local okName, value = pcall(GetActivityName, activityId)
                        if okName then requestName = cleanName(value) end
                    elseif type(GetActivityInfo) == "function" then
                        local okName, value = pcall(GetActivityInfo, activityId)
                        if okName then requestName = cleanName(value) end
                    end
                elseif setId > 0 then
                    -- Activity-set requests are what ESO uses for random/specific
                    -- Battleground queue groups. Derive the type directly from the
                    -- set's first activity so native ESO queues classify correctly
                    -- even if the stock finder UI has not been opened yet.
                    if type(GetNumActivitySetActivities) == "function" and type(GetActivitySetActivityIdByIndex) == "function" and type(GetActivityType) == "function" then
                        local okNum, numActivities = pcall(GetNumActivitySetActivities, setId)
                        if okNum and (tonumber(numActivities) or 0) > 0 then
                            local okActivity, firstActivityId = pcall(GetActivitySetActivityIdByIndex, setId, 1)
                            if okActivity and (tonumber(firstActivityId) or 0) > 0 then
                                local okType, value = pcall(GetActivityType, firstActivityId)
                                if okType then activityType = tonumber(value) end
                            end
                        end
                    end
                    local location, locatedType = self:FindAnySetById(setId)
                    if activityType == nil then activityType = locatedType end
                    if location then requestName = cleanName(safeMethod(location, "GetRawName", "")) end
                end
                if self:IsBattlegroundActivityType(activityType) then sawBattleground = true
                elseif self:IsDungeonActivityType(activityType) then sawDungeon = true
                elseif activityType ~= nil then sawOther = true end
                if requestName and requestName ~= "" then
                    count = count + 1
                    info.requestNames[count] = requestName
                end
            end
        end
    end

    if sawBattleground then info.kind = "BATTLEGROUND"
    elseif sawDungeon then info.kind = "DUNGEON"
    elseif sawOther then info.kind = "ACTIVITY"
    elseif self:IsQueued() and self.lastQueueKind then info.kind = self.lastQueueKind
    else info.kind = "ACTIVITY" end

    if #info.requestNames == 1 then info.name = info.requestNames[1]
    elseif #info.requestNames > 1 then info.name = string.format("%d Activity Finder selections", #info.requestNames)
    elseif info.kind == "BATTLEGROUND" and self.lastQueuedName then info.name = self.lastQueuedName
    elseif info.kind == "BATTLEGROUND" then info.name = "Battleground queue"
    elseif info.kind == "DUNGEON" then info.name = "Dungeon queue" end
    return info
end

function B:BuildView(forceRefresh)
    local rows = self:BuildLocations(forceRefresh == true)
    local total = #rows
    local pages = math.max(1, math.ceil(total / self.PAGE_SIZE))
    self.page = math.max(1, math.min(self.page or 1, pages))
    local first = (self.page - 1) * self.PAGE_SIZE + 1
    local visible = {}
    for i = first, math.min(total, first + self.PAGE_SIZE - 1) do
        local entry = rows[i]
        local state = entry.locked and "LOCKED" or "READY"
        local team = entry.maxGroupSize and ("TEAM " .. tostring(entry.maxGroupSize)) or "BATTLEGROUND"
        local reward = entry.dailyReady and "DAILY READY" or "STANDARD REWARD"
        visible[#visible + 1] = {
            id = entry.id,
            name = entry.name,
            detail = string.format("%s  |  %s  |  %s", state, team, reward),
            locked = entry.locked,
            lockReason = entry.lockReason,
            dailyReady = entry.dailyReady,
        }
    end
    return {
        rows = visible,
        total = total,
        page = self.page,
        pageCount = pages,
        selected = self:GetSelected(),
        showLocked = self.showLocked,
        queued = self:IsQueued(),
        hint = self.lastBuildReason,
    }
end

function B:RefreshJournal()
    local journal = EPC and EPC.Journal
    if journal and journal.activeTab == "BATTLEGROUNDS" and type(journal.RefreshSuitePage) == "function" then
        journal:RefreshSuitePage("BATTLEGROUNDS")
    end
end

function B:Initialize()
    if self.initialized02876 then return end
    self.initialized02876 = true
    if EVENT_MANAGER and rawget(_G, "EVENT_ACTIVITY_FINDER_STATUS_UPDATE") ~= nil then
        EPC.Runtime:RegisterEvent("BattlegroundFinder", "Status", EVENT_ACTIVITY_FINDER_STATUS_UPDATE,
            function(_, status)
                if rawget(_G, "ACTIVITY_FINDER_STATUS_NONE") ~= nil and status == ACTIVITY_FINDER_STATUS_NONE then
                    self.lastQueueKind = nil
                    self.lastQueuedName = nil
                end
                self:RefreshJournal()
            end)
    end
end

-- Core owns add-on bootstrap; this module is loaded after Core.
if zo_callLater then zo_callLater(function() B:Initialize() end, 600) else B:Initialize() end
