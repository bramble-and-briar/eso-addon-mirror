-- Tamriel Progress Map: small, defensive quest metadata service.
-- ESO's live API remains authoritative. Optional libraries only add provenance.

RaccoonQuestData = RaccoonQuestData or {}
local RQD = RaccoonQuestData

RQD.VERSION = "1.0.0"
RQD.FALLBACK_MAX_ID = 15000
RQD.zoneContent = RQD.zoneContent or {}
RQD.questExceptions = RQD.questExceptions or {}
RQD.exclusiveGroups = RQD.exclusiveGroups or {}
RQD._recordCache = RQD._recordCache or {}
RQD._knownCache = nil

local function AddReason(record, reason)
    record.reasons = record.reasons or {}
    record.reasons[#record.reasons + 1] = reason
end

local function SafeNumber(value)
    value = tonumber(value)
    if value and value > 0 then return value end
    return nil
end

function RQD:RegisterZoneContent(zoneId, definition)
    zoneId = SafeNumber(zoneId)
    if zoneId and type(definition) == "table" then
        self.zoneContent[zoneId] = definition
    end
end

function RQD:RegisterQuestException(questId, definition)
    questId = SafeNumber(questId)
    if questId and type(definition) == "table" then
        self.questExceptions[questId] = definition
    end
end

function RQD:RegisterExclusiveGroup(groupId, questIds)
    if type(groupId) ~= "string" or type(questIds) ~= "table" then return end
    self.exclusiveGroups[groupId] = questIds
    for _, questId in ipairs(questIds) do
        questId = SafeNumber(questId)
        if questId then
            local definition = self.questExceptions[questId] or {}
            definition.exclusiveGroup = groupId
            self.questExceptions[questId] = definition
        end
    end
end

function RQD:GetZoneContent(zoneId)
    zoneId = SafeNumber(zoneId)
    return zoneId and self.zoneContent[zoneId] or nil
end

function RQD:InvalidateCache()
    self._recordCache = {}
    self._knownCache = nil
end

local function MarkSource(sources, questId, source)
    sources[questId] = sources[questId] or {}
    sources[questId][source] = true
end

function RQD:GetKnownQuestIds(forceRefresh)
    if self._knownCache and not forceRefresh then
        return self._knownCache.ids, self._knownCache.sources, self._knownCache.library
    end

    local knownIds, sources = {}, {}
    local libraryInfo = { available = false, count = 0, verified = 0 }
    local lib = _G.LibQuestData
    if type(lib) == "table" and type(lib.quest_data) == "table" then
        local gameApiIndex = type(lib.quest_data_index) == "table" and lib.quest_data_index.game_api or nil
        for rawQuestId, questData in pairs(lib.quest_data) do
            local questId = SafeNumber(rawQuestId)
            if questId then
                knownIds[questId] = true
                MarkSource(sources, questId, "libquestdata")
                libraryInfo.count = libraryInfo.count + 1
                local gameApi = gameApiIndex and type(questData) == "table" and tonumber(questData[gameApiIndex]) or nil
                sources[questId].libraryGameApi = gameApi
                sources[questId].libraryVerified = gameApi ~= nil and gameApi >= 100000 and gameApi ~= 100003
                if sources[questId].libraryVerified then
                    libraryInfo.verified = libraryInfo.verified + 1
                end
            end
        end
        libraryInfo.available = libraryInfo.count > 0
    end

    if type(_G.GetNextCompletedQuestId) == "function" then
        local previousQuestId = nil
        for _ = 1, 20000 do
            local questId = SafeNumber(_G.GetNextCompletedQuestId(previousQuestId))
            if not questId or questId == previousQuestId then break end
            knownIds[questId] = true
            MarkSource(sources, questId, "completed_history")
            previousQuestId = questId
        end
    end

    -- The fallback discovers candidates only. Validation deliberately keeps these
    -- records unknown until completion, library provenance or an explicit include
    -- verifies that the ID is actually available on this client.
    if type(_G.GetQuestName) == "function" then
        for questId = 1, self.FALLBACK_MAX_ID do
            local name = _G.GetQuestName(questId)
            if type(name) == "string" and name ~= "" then
                knownIds[questId] = true
                MarkSource(sources, questId, "fallback_scan")
            end
        end
    end

    local ids = {}
    for questId in pairs(knownIds) do ids[#ids + 1] = questId end
    table.sort(ids)
    self._knownCache = { ids = ids, sources = sources, library = libraryInfo }
    return ids, sources, libraryInfo
end

function RQD:GetQuestRecord(questId, priorityQuestIds, forceRefresh)
    questId = SafeNumber(questId)
    if not questId then return nil end
    local isPriorityQuest = type(priorityQuestIds) == "table" and priorityQuestIds[questId] == true
    local priorityCacheKey = isPriorityQuest and "priority" or "ordinary"
    local cachedVariants = self._recordCache[questId]
    if type(cachedVariants) == "table" and cachedVariants[priorityCacheKey] and not forceRefresh then
        return cachedVariants[priorityCacheKey]
    end

    local _, sources = self:GetKnownQuestIds(forceRefresh)
    local source = sources[questId] or {}
    local exception = self.questExceptions[questId] or {}
    local record = {
        id = questId,
        name = type(_G.GetQuestName) == "function" and _G.GetQuestName(questId) or nil,
        zoneId = type(_G.GetQuestZoneId) == "function" and _G.GetQuestZoneId(questId) or nil,
        questType = type(_G.GetQuestType) == "function" and _G.GetQuestType(questId) or nil,
        repeatType = type(_G.GetQuestRepeatableType) == "function" and _G.GetQuestRepeatableType(questId) or nil,
        completed = type(_G.HasCompletedQuest) == "function" and _G.HasCompletedQuest(questId) == true or false,
        source = source,
        libraryGameApi = source.libraryGameApi,
        libraryVerified = source.libraryVerified == true,
        explicitInclude = exception.include == true,
        explicitExclude = exception.exclude == true,
        exclusiveGroup = exception.exclusiveGroup,
        reasons = {},
    }
    record.storyZoneId = record.zoneId
    if SafeNumber(record.zoneId) and type(_G.GetZoneStoryZoneIdForZoneId) == "function" then
        record.storyZoneId = SafeNumber(_G.GetZoneStoryZoneIdForZoneId(record.zoneId)) or record.zoneId
    end
    if type(self.ValidateQuestRecord) == "function" then
        self:ValidateQuestRecord(record, priorityQuestIds)
    else
        record.classification = "unknown"
        record.eligible = false
        AddReason(record, "validation_unavailable")
    end
    cachedVariants = type(cachedVariants) == "table" and cachedVariants or {}
    cachedVariants[priorityCacheKey] = record
    self._recordCache[questId] = cachedVariants
    return record
end

local function EmptyBucket()
    return { completed = 0, total = 0, open = 0, records = {} }
end

local function ExclusiveRecordRank(record)
    return (record.eligible and 100 or 0) + (record.completed and 10 or 0) + (record.verified and 1 or 0)
end

function RQD:GetSideQuestStatistics(progressZoneIds, priorityQuestIds, forceRefresh)
    if forceRefresh then self:InvalidateCache() end
    local zoneScope = nil
    if type(progressZoneIds) == "table" then
        zoneScope = {}
        for _, zoneId in ipairs(progressZoneIds) do zoneScope[tonumber(zoneId)] = true end
        for zoneId, enabled in pairs(progressZoneIds) do
            if type(zoneId) == "number" and enabled then zoneScope[zoneId] = true end
        end
    end

    local result = {
        base = EmptyBucket(),
        dlc = EmptyBucket(),
        unknown = EmptyBucket(),
        excluded = EmptyBucket(),
        source = {},
        diagnosticRecords = {},
    }
    local ids, _, libraryInfo = self:GetKnownQuestIds(false)
    result.source = libraryInfo
    local exclusiveSelections, countableRecords = {}, {}

    for _, questId in ipairs(ids) do
        local record = self:GetQuestRecord(questId, priorityQuestIds, false)
        local inScope = not zoneScope or zoneScope[record.storyZoneId] or zoneScope[record.zoneId]
        if inScope then
            if record.exclusiveGroup then
                local current = exclusiveSelections[record.exclusiveGroup]
                local better = not current or ExclusiveRecordRank(record) > ExclusiveRecordRank(current)
                    or (ExclusiveRecordRank(record) == ExclusiveRecordRank(current) and record.id < current.id)
                if better then exclusiveSelections[record.exclusiveGroup] = record end
            else
                countableRecords[#countableRecords + 1] = record
            end
            result.diagnosticRecords[#result.diagnosticRecords + 1] = record
        end
    end
    for _, record in pairs(exclusiveSelections) do countableRecords[#countableRecords + 1] = record end
    table.sort(countableRecords, function(a, b) return a.id < b.id end)
    for _, record in ipairs(countableRecords) do
        local bucketName = record.eligible and record.classification or (record.classification == "unknown" and "unknown" or "excluded")
        local bucket = result[bucketName] or result.excluded
        bucket.total = bucket.total + 1
        if record.completed then bucket.completed = bucket.completed + 1 end
        bucket.open = bucket.total - bucket.completed
        bucket.records[#bucket.records + 1] = record
    end
    result.coverageComplete = result.source.available == true and result.source.verified > 0 and result.unknown.total == 0
    return result
end

local function DiagnosticMatches(record, filter)
    if filter == "all" then return true end
    if filter == "base" or filter == "dlc" or filter == "unknown" then return record.classification == filter end
    if filter == "excluded" then return record.eligible ~= true and record.classification ~= "unknown" end
    if filter == "open" then return record.eligible == true and not record.completed end
    if filter == "complete" then return record.eligible == true and record.completed == true end
    return record.eligible ~= true or record.classification == "unknown" or #(record.reasons or {}) > 0
end

function RQD:GetDiagnosticPage(filter, page, pageSize, progressZoneIds, priorityQuestIds)
    filter = type(filter) == "string" and string.lower(filter) or "suspicious"
    pageSize = math.min(math.max(1, tonumber(pageSize) or 8), 8)
    page = math.max(1, math.floor(tonumber(page) or 1))
    local statistics = self:GetSideQuestStatistics(progressZoneIds, priorityQuestIds, false)
    local records = {}
    for _, record in ipairs(statistics.diagnosticRecords or {}) do
        if DiagnosticMatches(record, filter) then records[#records + 1] = record end
    end
    table.sort(records, function(a, b) return a.id < b.id end)
    local totalPages = math.max(1, math.ceil(#records / pageSize))
    page = math.min(page, totalPages)
    local items = {}
    local first = ((page - 1) * pageSize) + 1
    for index = first, math.min(#records, first + pageSize - 1) do items[#items + 1] = records[index] end
    return { filter = filter, page = page, pageSize = pageSize, total = #records, totalPages = totalPages, items = items }
end

function RQD:GetQuestDiagnostic(questId, progressZoneIds, priorityQuestIds)
    local record = self:GetQuestRecord(questId, priorityQuestIds, false)
    if not record then return nil end
    if type(progressZoneIds) == "table" then
        record.inProgressScope = false
        for _, zoneId in ipairs(progressZoneIds) do
            if tonumber(zoneId) == tonumber(record.storyZoneId) or tonumber(zoneId) == tonumber(record.zoneId) then
                record.inProgressScope = true
                break
            end
        end
    end
    return record
end

