SmartChatMsg = SmartChatMsg or {}

SmartChatMsg.name = "SmartChatMsg"
SmartChatMsg.dynamicCommands = SmartChatMsg.dynamicCommands or {}
SmartChatMsg.commandReminderTimers = SmartChatMsg.commandReminderTimers or {}
SmartChatMsg.activeReminderStates = SmartChatMsg.activeReminderStates or {}
SmartChatMsg.lastKnownZoneId = SmartChatMsg.lastKnownZoneId or nil
SmartChatMsg.hasSeenInitialPlayerActivated = SmartChatMsg.hasSeenInitialPlayerActivated or false
SmartChatMsg.pendingRestoreState = SmartChatMsg.pendingRestoreState or nil
SmartChatMsg.restoreWatcherEventName = SmartChatMsg.name .. "_RestoreWatcher"
SmartChatMsg.restoreWatcherTimeoutName = SmartChatMsg.name .. "_RestoreWatcherTimeout"
SmartChatMsg.debugEnabled = SmartChatMsg.debugEnabled == true
SmartChatMsg.logger = SmartChatMsg.logger or nil

SmartChatMsg.statusPanel = SmartChatMsg.statusPanel or nil
SmartChatMsg.statusPanelVisible = SmartChatMsg.statusPanelVisible == true
SmartChatMsg.statusPanelRefreshName = SmartChatMsg.name .. "_StatusPanelRefresh"
SmartChatMsg.startupQueue = SmartChatMsg.startupQueue or {}
SmartChatMsg.startupQueueCurrent = SmartChatMsg.startupQueueCurrent or nil
SmartChatMsg.startupQueueInitialized = SmartChatMsg.startupQueueInitialized == true
SmartChatMsg.startupQueueDelayName = SmartChatMsg.name .. "_StartupQueueDelay"
SmartChatMsg.queueProcessingScheduled = SmartChatMsg.queueProcessingScheduled == true

SmartChatMsg.autoPopulateTestHouseZoneId = SmartChatMsg.autoPopulateTestHouseZoneId or 1109
SmartChatMsg.infiniteArchiveZoneId = SmartChatMsg.infiniteArchiveZoneId or 1463


function SmartChatMsg:AddLocalChatMessage(message)
    if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage(tostring(message or ""))
    end
end

function SmartChatMsg:DebugLog(message)
    if not self.debugEnabled then
        return
    end

    local text = tostring(message)

    if self.logger and self.logger.Debug then
        self.logger:Debug(text)
    end

    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] " .. text)
end

function SmartChatMsg:FormatQueueEntry(entry)
    if type(entry) ~= "table" then
        return "nil"
    end

    return string.format(
        "id=%s queueKey=%s commandId=%s guildName=%s guildIndex=%s rawParam=%s paramText=%s source=%s enqueuedAt=%s queueItemId=%s",
        tostring(entry.id),
        tostring(entry.queueKey),
        tostring(entry.commandId),
        tostring(entry.guildName),
        tostring(entry.guildIndex),
        tostring(entry.rawParam),
        tostring(entry.paramText),
        tostring(entry.source),
        tostring(entry.enqueuedAt),
        tostring(entry.queueItemId)
    )
end

function SmartChatMsg:DumpQueueState(reason)
    if not self.debugEnabled then
        return
    end

    local queue = self.startupQueue or {}
    self:DebugLog(string.format(
        "Execution queue dump: reason=%s size=%s current=%s scheduled=%s initialized=%s",
        tostring(reason or "unspecified"),
        tostring(#queue),
        self:FormatQueueEntry(self.startupQueueCurrent),
        tostring(self.queueProcessingScheduled),
        tostring(self.startupQueueInitialized)
    ))

    for index, entry in ipairs(queue) do
        self:DebugLog(string.format(
            "Execution queue dump: index=%s %s",
            tostring(index),
            self:FormatQueueEntry(entry)
        ))
    end
end

function SmartChatMsg:DebugCountdownState(label, data)
    if not self.debugEnabled then
        return
    end

    if type(data) ~= "table" then
        self:DebugLog("Countdown debug: " .. tostring(label) .. " data=nil")
        return
    end

    local parts = {}
    for key, value in pairs(data) do
        table.insert(parts, tostring(key) .. "=" .. tostring(value))
    end

    table.sort(parts)
    self:DebugLog("Countdown debug: " .. tostring(label) .. " " .. table.concat(parts, " "))
end


function SmartChatMsg:FormatChatChannelInfo(channelInfo)
    if not channelInfo then
        return "nil"
    end

    return string.format(
        "short=%s kind=%s index=%s id=%s target=%s",
        tostring(channelInfo.short or "unknown"),
        tostring(channelInfo.kind or "unknown"),
        tostring(channelInfo.index or "-"),
        tostring(channelInfo.id or "nil"),
        tostring(channelInfo.target or "none")
    )
end

function SmartChatMsg:BuildSlashCommandName(commandName)
    if type(commandName) ~= "string" then
        return nil
    end

    local trimmed = self:Trim(commandName)
    if trimmed == "" then
        return nil
    end

    local cleaned = zo_strlower(trimmed):gsub("[^%w]", "")
    if cleaned == "" then
        return nil
    end

    return "/" .. cleaned
end

function SmartChatMsg:GetCurrentTimeTokenValue()
    local hour = tonumber(os.date("%H")) or 12
    if hour < 12 then
        return "morning"
    elseif hour < 18 then
        return "afternoon"
    end

    return "evening"
end

function SmartChatMsg:GetCurrentZoneName()
    local zoneName = GetUnitZone("player")
    zoneName = self:Trim(zoneName or "")
    if zoneName ~= "" then
        return zoneName
    end

    local zoneId = GetZoneId(GetUnitZoneIndex("player"))
    if zoneId and zoneId ~= 0 and GetZoneNameById then
        zoneName = self:Trim(GetZoneNameById(zoneId) or "")
        if zoneName ~= "" then
            return zoneName
        end
    end

    return nil
end

function SmartChatMsg:RoundToNearestQuarterHour(totalMinutes)
    if type(totalMinutes) ~= "number" then
        return 0
    end

    if totalMinutes <= 0 then
        return 0
    end

    return math.floor((totalMinutes + 7.5) / 15) * 15
end

function SmartChatMsg:PluralizeTimeUnit(value, singular, plural)
    if value == 1 then
        return string.format("%d %s", value, singular)
    end

    return string.format("%d %s", value, plural)
end

function SmartChatMsg:HasEndingPhraseBeforeTime(sourceText, timeMatch)
    local source = zo_strlower(tostring(sourceText or ""))
    local target = zo_strlower(tostring(timeMatch or ""))
    if source == "" or target == "" then
        return false
    end

    local timeStart = source:find(target, 1, true)
    if not timeStart then
        return false
    end

    local phraseStart = timeStart

    local beforeTime = source:sub(1, timeStart - 1)
    local weekdayPatterns = {
        "(sunday)%s*$",
        "(monday)%s*$",
        "(tuesday)%s*$",
        "(wednesday)%s*$",
        "(thursday)%s*$",
        "(friday)%s*$",
        "(saturday)%s*$",
        "(sun)%s*$",
        "(mon)%s*$",
        "(tues?)%s*$",
        "(wed)%s*$",
        "(thurs?)%s*$",
        "(fri)%s*$",
        "(sat)%s*$",
        "(today)%s*$",
        "(tomorrow)%s*$",
        "(tonight)%s*$",
    }

    local scanIndex = timeStart - 1
    while scanIndex >= 1 and source:sub(scanIndex, scanIndex):match("%s") do
        scanIndex = scanIndex - 1
    end

    if scanIndex >= 2 then
        local maybeAtStart, maybeAtEnd = beforeTime:find("at%s*$")
        if maybeAtStart and maybeAtEnd and maybeAtEnd == scanIndex then
            phraseStart = maybeAtStart
            beforeTime = source:sub(1, maybeAtStart - 1)
            scanIndex = maybeAtStart - 1
            while scanIndex >= 1 and source:sub(scanIndex, scanIndex):match("%s") do
                scanIndex = scanIndex - 1
            end
        end
    end

    for _, pattern in ipairs(weekdayPatterns) do
        local dayStart, dayEnd = beforeTime:find(pattern)
        if dayStart and dayEnd then
            phraseStart = dayStart
            break
        end
    end

    local prefix = source:sub(1, phraseStart - 1)
    local index = #prefix
    while index >= 1 and prefix:sub(index, index):match("%s") do
        index = index - 1
    end
    if index < 1 then
        return false
    end

    local wordEnd = index
    while index >= 1 and prefix:sub(index, index):match("[%a]") do
        index = index - 1
    end

    local previousWord = prefix:sub(index + 1, wordEnd)
    return previousWord == "until"
end

function SmartChatMsg:GetApproximateCountdownTextFromSeconds(diffSeconds, sourceText, timeMatch)
    local safeSeconds = tonumber(diffSeconds) or 0
    if safeSeconds < 0 then
        safeSeconds = 0
    end

    local soonText = self:HasEndingPhraseBeforeTime(sourceText, timeMatch) and "ending soon" or "starting soon"
    if safeSeconds < (5 * 60) then
        return soonText
    end

    local exactMinutes = math.floor(safeSeconds / 60)
    if exactMinutes < 15 then
        return string.format("%d%s", exactMinutes, exactMinutes == 1 and "m" or "m")
    end

    local totalMinutes = safeSeconds / 60
    local roundingIncrement = 15
    if totalMinutes < 180 then
        roundingIncrement = 5
    elseif totalMinutes < (24 * 60) then
        roundingIncrement = 15
    elseif totalMinutes < (3 * 24 * 60) then
        roundingIncrement = 30
    else
        roundingIncrement = 60
    end

    local roundedMinutes = math.floor((totalMinutes + (roundingIncrement / 2)) / roundingIncrement) * roundingIncrement
    if roundedMinutes < 15 then
        roundedMinutes = 15
    end

    local days = math.floor(roundedMinutes / (24 * 60))
    local remainderMinutes = roundedMinutes % (24 * 60)
    local hours = math.floor(remainderMinutes / 60)
    local minutes = remainderMinutes % 60

    local parts = {}
    if days > 0 then
        table.insert(parts, string.format("%dd", days))
    end
    if hours > 0 then
        table.insert(parts, string.format("%dh", hours))
    end
    if minutes > 0 then
        table.insert(parts, string.format("%dm", minutes))
    end

    if #parts == 0 then
        return "15m"
    end

    return "about " .. table.concat(parts, " ")
end

local function scm_get_utc_now()
    return os.time(os.date("!*t"))
end

local function scm_get_local_utc_offset_seconds(epoch)
    local targetEpoch = tonumber(epoch) or os.time()
    return targetEpoch - os.time(os.date("!*t", targetEpoch))
end

local function scm_build_utc_timestamp(year, month, day, hour, minute, second)
    local localEpoch = os.time({
        year = year,
        month = month,
        day = day,
        hour = hour,
        min = minute,
        sec = second or 0,
    })

    return localEpoch + scm_get_local_utc_offset_seconds(localEpoch)
end

function SmartChatMsg:GetUtcNow()
    return scm_get_utc_now()
end

function SmartChatMsg:GetResolvedTimezoneOffsetHours(timezoneName, eventEpoch)
    local normalized = self:Trim(tostring(timezoneName or ""))
    if normalized == "" then return nil end

    normalized = zo_strupper(normalized)
    normalized = normalized:gsub("%.", "")
    normalized = normalized:gsub("%s+TIME$", "")
    normalized = normalized:gsub("%s+", "")

    local fixedOffsets = {
        UTC = 0,
        GMT = 0,
        EST = -5,
        EDT = -4,
        CST = -6,
        CDT = -5,
        MST = -7,
        MDT = -6,
        PST = -8,
        PDT = -7,
    }

    if fixedOffsets[normalized] ~= nil then
        return fixedOffsets[normalized]
    end

    -- DST based on EVENT TIME (NOT local)
    local isDst = false
    if eventEpoch then
        local t = os.date("*t", eventEpoch)
        isDst = t and t.isdst == true
    end

    local genericOffsets = {
        ET = isDst and -4 or -5,
        EASTERN = isDst and -4 or -5,
        CT = isDst and -5 or -6,
        CENTRAL = isDst and -5 or -6,
        MT = isDst and -6 or -7,
        MOUNTAIN = isDst and -6 or -7,
        PT = isDst and -7 or -8,
        PACIFIC = isDst and -7 or -8,
    }

    return genericOffsets[normalized]
end

function SmartChatMsg:NormalizeExtractedHour(hourValue, ampm)
    local hour = tonumber(hourValue)
    if not hour then
        return nil
    end

    if ampm then
        local normalizedMeridiem = zo_strupper(tostring(ampm))
        if normalizedMeridiem == "AM" then
            if hour == 12 then
                hour = 0
            end
        elseif normalizedMeridiem == "PM" then
            if hour ~= 12 then
                hour = hour + 12
            end
        end
    end

    if hour < 0 or hour > 23 then
        return nil
    end

    return hour
end

function SmartChatMsg:EscapeLuaPattern(text)
    return tostring(text or ""):gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

function SmartChatMsg:GetSupportedTimezoneTokens()
    return {
        "Eastern Time",
        "Central Time",
        "Mountain Time",
        "Pacific Time",
        "Eastern",
        "Central",
        "Mountain",
        "Pacific",
        "UTC",
        "GMT",
        "EST",
        "EDT",
        "CST",
        "CDT",
        "MST",
        "MDT",
        "PST",
        "PDT",
        "ET",
        "CT",
        "MT",
        "PT",
    }
end

function SmartChatMsg:GetSupportedTimezoneTokensSorted()
    local seen = {}
    local tokens = {}

    for _, token in ipairs(self:GetSupportedTimezoneTokens() or {}) do
        local trimmed = self:Trim(tostring(token or ""))
        if trimmed ~= "" then
            local key = zo_strlower(trimmed)
            if not seen[key] then
                table.insert(tokens, trimmed)
                seen[key] = true
            end
        end
    end

    table.sort(tokens, function(a, b)
        if #a ~= #b then
            return #a > #b
        end
        return zo_strlower(a) < zo_strlower(b)
    end)

    return tokens
end

function SmartChatMsg:FindLeadingSupportedTimezoneToken(text)
    local source = tostring(text or "")
    if source == "" then
        return nil, nil
    end

    local lowerSource = zo_strlower(source)
    for _, token in ipairs(self:GetSupportedTimezoneTokensSorted()) do
        local lowerToken = zo_strlower(token)
        local pattern = "^(%s*" .. self:EscapeLuaPattern(lowerToken) .. ")%f[%A]"
        local startPos, endPos = lowerSource:find(pattern)
        if startPos and endPos then
            return token, source:sub(startPos, endPos)
        end
    end

    return nil, nil
end

function SmartChatMsg:GetTrailingSupportedTimezoneToken(text)
    local source = tostring(text or "")
    if source == "" then
        return nil, nil
    end

    local lowerSource = zo_strlower(source)
    for _, token in ipairs(self:GetSupportedTimezoneTokensSorted()) do
        local lowerToken = zo_strlower(token)
        local startPos, endPos = lowerSource:find("(%s*" .. self:EscapeLuaPattern(lowerToken) .. ")%f[%A]$")
        if startPos and endPos then
            return token, source:sub(startPos, endPos)
        end
    end

    return nil, nil
end

function SmartChatMsg:HasExplicitMeridiem(text)
    local source = zo_strlower(tostring(text or ""))
    if source == "" then
        return false
    end

    return source:find("[ap]%.?%s*m%.?%f[%A]") ~= nil
end


function SmartChatMsg:GetLocalTimezoneDisplayName(epochSeconds)
    local when = tonumber(epochSeconds) or os.time()
    local timezoneName = self:Trim(os.date("%Z", when) or "")
    local normalized = zo_strupper(timezoneName):gsub("%.", ""):gsub("%s+TIME$", ""):gsub("%s+", "")

    local localDate = os.date("*t", when)
    local isDst = localDate and localDate.isdst == true
    local aliasMap = {
        UTC = "UTC",
        GMT = "GMT",
        EST = "EST",
        EDT = "EDT",
        CST = "CST",
        CDT = "CDT",
        MST = "MST",
        MDT = "MDT",
        PST = "PST",
        PDT = "PDT",
        ET = isDst and "EDT" or "EST",
        CT = isDst and "CDT" or "CST",
        MT = isDst and "MDT" or "MST",
        PT = isDst and "PDT" or "PST",
        EASTERN = isDst and "EDT" or "EST",
        CENTRAL = isDst and "CDT" or "CST",
        MOUNTAIN = isDst and "MDT" or "MST",
        PACIFIC = isDst and "PDT" or "PST",
    }

    if aliasMap[normalized] then
        return aliasMap[normalized]
    end

    local utcDate = os.date("!*t", when)
    local localEpoch = os.time(localDate)
    local utcEpochAsLocal = os.time(utcDate)
    local offset = (localEpoch - utcEpochAsLocal) / 3600
    if type(offset) ~= "number" then
        return "UTC"
    end

    if offset ~= math.floor(offset) then
        return string.format("UTC%+.1f", offset)
    end

    local lookup = {
        [-8] = "PST",
        [-7] = isDst and "MDT" or "MST",
        [-6] = isDst and "CDT" or "CST",
        [-5] = isDst and "EDT" or "EST",
        [-4] = "ADT",
        [0] = "UTC",
    }

    return lookup[offset] or string.format("UTC%+d", offset)
end

function SmartChatMsg:BuildLowercaseSourceIndexMap(source)
    local map = {}
    local lowerParts = {}
    local lowerPos = 1
    local index = 1

    while index <= #source do
        local byte = source:byte(index)
        local charLength = 1
        if byte >= 240 then
            charLength = 4
        elseif byte >= 224 then
            charLength = 3
        elseif byte >= 192 then
            charLength = 2
        end

        local originalChunk = source:sub(index, index + charLength - 1)
        local loweredChunk = zo_strlower(originalChunk)
        lowerParts[#lowerParts + 1] = loweredChunk

        for _ = 1, #loweredChunk do
            map[lowerPos] = index
            lowerPos = lowerPos + 1
        end

        index = index + charLength
    end

    map[lowerPos] = #source + 1
    return table.concat(lowerParts), map
end

function SmartChatMsg:SliceOriginalByLowerPositions(source, sourceIndexMap, lowerStartPos, lowerEndPos)
    if not lowerStartPos or not lowerEndPos or lowerStartPos < 1 or lowerEndPos < lowerStartPos then
        return nil
    end

    local originalStart = sourceIndexMap[lowerStartPos]
    local originalEndExclusive = sourceIndexMap[lowerEndPos + 1] or (#source + 1)
    if not originalStart or not originalEndExclusive then
        return nil
    end

    return source:sub(originalStart, originalEndExclusive - 1)
end

function SmartChatMsg:TryReturnDetectedTime(source, fullMatch, hour, minute, timezoneToken, patternName)
    if not fullMatch or fullMatch == "" then
        return nil, nil, nil, nil
    end

    local normalizedMinute = tonumber(minute)
    if normalizedMinute == nil or normalizedMinute < 0 or normalizedMinute > 59 then
        return nil, nil, nil, nil
    end

    self:DebugCountdownState("time_detected", {
        match = fullMatch,
        hour = hour,
        minute = normalizedMinute,
        timezone = timezoneToken or "local",
        pattern = patternName,
    })
    return fullMatch, hour, normalizedMinute, timezoneToken
end


function SmartChatMsg:FindEmbeddedTimeDetails(text)
    local source = tostring(text or "")
    local lowerSource, sourceIndexMap = self:BuildLowercaseSourceIndexMap(source)
    self:DebugLog("Countdown debug: scanning for embedded time in text=" .. tostring(source))

    local function tryPattern(pattern, patternName, timezoneToken, hourTransform)
        local searchStart = 1
        while searchStart <= #lowerSource do
            local startPos, endPos, a, b, c = lowerSource:find(pattern, searchStart)
            if not startPos then
                break
            end

            local hour, minute = hourTransform(a, b, c)
            if hour ~= nil and minute ~= nil then
                local originalMatch = self:SliceOriginalByLowerPositions(source, sourceIndexMap, startPos, endPos)
                local detectedMatch, detectedHour, detectedMinute, detectedTimezone = self:TryReturnDetectedTime(source, originalMatch, hour, minute, timezoneToken, patternName)
                if detectedMatch then
                    return detectedMatch, detectedHour, detectedMinute, detectedTimezone
                end
            end

            searchStart = startPos + 1
        end

        return nil, nil, nil, nil
    end

    local function isTokenBoundary(startPos, endPos)
        local beforeChar = (startPos and startPos > 1) and lowerSource:sub(startPos - 1, startPos - 1) or ""
        local afterChar = (endPos and endPos < #lowerSource) and lowerSource:sub(endPos + 1, endPos + 1) or ""
        local beforeOk = beforeChar == "" or not beforeChar:match("[%a%d]")
        local afterOk = afterChar == "" or not afterChar:match("[%a%d]")
        return beforeOk and afterOk
    end

    local snippetPatterns = {
        {
            pattern = "(%d%d?)%s*:%s*(%d%d)%s*([ap])%.?%s*[m]%.?",
            name = "12h_with_minutes",
            transform = function(h, m, ap)
                local meridiem = (ap == "a") and "AM" or "PM"
                local hour = self:NormalizeExtractedHour(h, meridiem)
                local minute = tonumber(m)
                if hour and minute and minute >= 0 and minute <= 59 then return hour, minute end
            end,
        },
        {
            pattern = "(%d%d?)%s*([ap])%.?%s*[m]%.?",
            name = "12h_hour_only",
            transform = function(h, ap)
                local meridiem = (ap == "a") and "AM" or "PM"
                local hour = self:NormalizeExtractedHour(h, meridiem)
                if hour then return hour, 0 end
            end,
        },
        {
            pattern = "(%d)(%d%d)%s*([ap])%.?%s*[m]%.?",
            name = "12h_compact_3digit",
            transform = function(h, m, ap)
                local meridiem = (ap == "a") and "AM" or "PM"
                local hour = self:NormalizeExtractedHour(h, meridiem)
                local minute = tonumber(m)
                if hour and minute and minute >= 0 and minute <= 59 then return hour, minute end
            end,
        },
        {
            pattern = "(%d%d)(%d%d)%s*([ap])%.?%s*[m]%.?",
            name = "12h_compact_4digit",
            transform = function(h, m, ap)
                local meridiem = (ap == "a") and "AM" or "PM"
                local hour = self:NormalizeExtractedHour(h, meridiem)
                local minute = tonumber(m)
                if hour and minute and minute >= 0 and minute <= 59 then return hour, minute end
            end,
        },
        {
            pattern = "(%d%d?)%s*:%s*(%d%d)",
            name = "24h_with_minutes",
            transform = function(h, m, snippetText, relStartPos, relEndPos)
                local tail = tostring(snippetText or ""):sub((relEndPos or 0) + 1)
                if tail:match("^%s*[ap]%.?%s*m%f[%A]") then
                    return nil, nil
                end

                local hour = tonumber(h)
                local minute = tonumber(m)
                if hour and minute and hour >= 0 and hour <= 23 and minute >= 0 and minute <= 59 then return hour, minute end
            end,
        },
    }

    local function parseSnippet(snippet, snippetStart, matchEndLimit, timezoneToken, labelPrefix)
        for _, entry in ipairs(snippetPatterns) do
            local searchStart = 1
            while searchStart <= #snippet do
                local relStart, relEnd, a, b, c = snippet:find(entry.pattern, searchStart)
                if not relStart then
                    break
                end

                local absStart = snippetStart + relStart - 1
                local absEnd = snippetStart + relEnd - 1
                if (not matchEndLimit or absEnd <= matchEndLimit) then
                    if isTokenBoundary(absStart, absEnd) then
                        local hour, minute = entry.transform(a, b, c, snippet, relStart, relEnd)
                        if hour ~= nil and minute ~= nil then
                            local originalMatch = self:SliceOriginalByLowerPositions(source, sourceIndexMap, absStart, absEnd)
                            local detectedMatch, detectedHour, detectedMinute, detectedTimezone =
                                self:TryReturnDetectedTime(source, originalMatch, hour, minute, timezoneToken, labelPrefix .. entry.name)
                            if detectedMatch then
                                return detectedMatch, detectedHour, detectedMinute, detectedTimezone
                            end
                        end
                    end
                end

                searchStart = relStart + 1
            end
        end

        return nil, nil, nil, nil
    end

    local function trySnippetBeforeTimezone(token, tokenStart, tokenEnd)
        local snippetStart = math.max(1, tokenStart - 32)
        local snippet = lowerSource:sub(snippetStart, tokenStart - 1)
        return parseSnippet(snippet, snippetStart, tokenStart - 1, token, "tz_near_token_")
    end

    for _, token in ipairs(self:GetSupportedTimezoneTokens()) do
        local normalizedToken = zo_strlower(token)
        local searchStart = 1
        while searchStart <= #lowerSource do
            local tokenStart, tokenEnd = lowerSource:find(normalizedToken, searchStart, true)
            if not tokenStart then break end
            if isTokenBoundary(tokenStart, tokenEnd) then
                local detectedMatch, detectedHour, detectedMinute, detectedTimezone = trySnippetBeforeTimezone(token, tokenStart, tokenEnd)
                if detectedMatch then return detectedMatch, detectedHour, detectedMinute, detectedTimezone end
            end
            searchStart = tokenStart + 1
        end
    end

    self:DebugLog("Countdown debug: timezone-aware patterns produced no match; trying local fallback patterns")

    do
        local detectedMatch, detectedHour, detectedMinute, detectedTimezone =
            parseSnippet(lowerSource, 1, nil, nil, "local_scan_")
        if detectedMatch then
            return detectedMatch, detectedHour, detectedMinute, detectedTimezone
        end
    end

    local noonStart, noonEnd = lowerSource:find("%f[%a]noon%f[%A]")
    if noonStart then
        local originalMatch = self:SliceOriginalByLowerPositions(source, sourceIndexMap, noonStart, noonEnd)
        local m, h, mi = self:TryReturnDetectedTime(source, originalMatch, 12, 0, nil, "keyword_noon")
        if m then return m, h, mi, nil end
    end

    local midnightStart, midnightEnd = lowerSource:find("%f[%a]midnight%f[%A]")
    if midnightStart then
        local originalMatch = self:SliceOriginalByLowerPositions(source, sourceIndexMap, midnightStart, midnightEnd)
        local m, h, mi = self:TryReturnDetectedTime(source, originalMatch, 0, 0, nil, "keyword_midnight")
        if m then return m, h, mi, nil end
    end

    self:DebugLog("Countdown debug: no embedded time detected")
    return nil, nil, nil, nil
end
function SmartChatMsg:ExtractEmbeddedTimeParts(text)
    local _, hour, minute, timezoneToken = self:FindEmbeddedTimeDetails(text)
    return hour, minute, timezoneToken
end

function SmartChatMsg:FindEmbeddedTimeSubstring(text)
    local fullMatch = self:FindEmbeddedTimeDetails(text)
    return fullMatch
end

function SmartChatMsg:GetWeekdayIndexByName(dayName)
    local normalized = zo_strlower(self:Trim(tostring(dayName or "")))
    normalized = normalized:gsub("%.", "")

    local weekdayMap = {
        sunday = 1,
        sun = 1,
        monday = 2,
        mon = 2,
        tuesday = 3,
        tue = 3,
        tues = 3,
        wednesday = 4,
        wed = 4,
        thursday = 5,
        thu = 5,
        thur = 5,
        thurs = 5,
        friday = 6,
        fri = 6,
        saturday = 7,
        sat = 7,
    }

    return weekdayMap[normalized]
end

function SmartChatMsg:GetEmbeddedDayOffset(text, nowEpoch, timeMatch)
    if not timeMatch or timeMatch == "" then
        self:DebugLog("Countdown debug: day detection skipped because no time was detected")
        return nil
    end

    local source = zo_strlower(tostring(text or ""))
    local nowEpochSafe = tonumber(nowEpoch) or os.time()
    local now = os.date("*t", nowEpochSafe)
    local beforeScope = source
    local afterScope = ""

    local lowerMatch = zo_strlower(tostring(timeMatch))
    local matchStart, matchEnd = source:find(lowerMatch, 1, true)
    if matchStart then
        beforeScope = source:sub(1, matchStart - 1)
        afterScope = source:sub(matchEnd + 1)
        self:DebugLog(string.format(
            "Countdown debug: day scan scopes prepared timeMatch=%s beforeScope=%s afterScope=%s",
            tostring(timeMatch),
            tostring(beforeScope),
            tostring(afterScope)
        ))
    else
        self:DebugLog("Countdown debug: day scan could not locate detected time in source; using full text as before-scope")
    end

    local function tryExtractDateOffset(scope, anchor)
        local scopeText = tostring(scope or "")
        if scopeText == "" then
            self:DebugLog("Countdown debug: no date token seen anchor=" .. tostring(anchor) .. " scope=empty")
            return nil
        end

        local dateToken = nil
        local m, d, y = nil, nil, nil

        local function isDateBoundary(startPos, endPos)
            local beforeChar = (startPos and startPos > 1) and scopeText:sub(startPos - 1, startPos - 1) or ""
            local afterChar = (endPos and endPos < #scopeText) and scopeText:sub(endPos + 1, endPos + 1) or ""
            local beforeOk = beforeChar == "" or not beforeChar:match("[%d]")
            local afterOk = afterChar == "" or not afterChar:match("[%d]")
            return beforeOk and afterOk
        end

        local s1, e1, m1, d1, y1 = scopeText:find("(%d?%d)%s*/%s*(%d?%d)%s*/%s*(%d%d%d%d)")
        if s1 and isDateBoundary(s1, e1) then
            m, d, y = m1, d1, y1
            dateToken = string.format("%s/%s/%s", m, d, y)
        else
            local s2, e2, m2, d2 = scopeText:find("(%d?%d)%s*/%s*(%d?%d)")
            if s2 and isDateBoundary(s2, e2) then
                m, d = m2, d2
                dateToken = string.format("%s/%s", m, d)
            end
        end

        if not m then
            self:DebugLog("Countdown debug: no date token seen anchor=" .. tostring(anchor) .. " scope=" .. tostring(scopeText))
            return nil
        end

        local month = tonumber(m)
        local day = tonumber(d)
        local year = tonumber(y)
        if not month or not day or month < 1 or month > 12 or day < 1 or day > 31 then
            self:DebugLog("Countdown debug: date token ignored anchor=" .. tostring(anchor) .. " token=" .. tostring(dateToken) .. " reason=invalid_month_or_day")
            return nil
        end

        if not year then
            year = now.year
        elseif year < 100 then
            year = 2000 + year
        end

        local candidateEpoch = os.time({year = year, month = month, day = day, hour = 12, min = 0, sec = 0})
        if not candidateEpoch then
            self:DebugLog("Countdown debug: date token ignored anchor=" .. tostring(anchor) .. " token=" .. tostring(dateToken) .. " reason=os_time_failed")
            return nil
        end

        local candidateDate = os.date("*t", candidateEpoch)
        if candidateDate.year ~= year or candidateDate.month ~= month or candidateDate.day ~= day then
            self:DebugLog("Countdown debug: date token ignored anchor=" .. tostring(anchor) .. " token=" .. tostring(dateToken) .. " reason=normalized_to_different_date")
            return nil
        end

        local nowStartOfDay = os.time({year = now.year, month = now.month, day = now.day, hour = 0, min = 0, sec = 0})
        local candidateStartOfDay = os.time({year = year, month = month, day = day, hour = 0, min = 0, sec = 0})
        local dayOffset = math.floor((candidateStartOfDay - nowStartOfDay) / (24 * 60 * 60))

        if dayOffset < 0 then
            self:DebugLog("Countdown debug: date detected but ignored anchor=" .. tostring(anchor) .. " token=" .. tostring(dateToken) .. " dayOffset=" .. tostring(dayOffset) .. " reason=past_date")
            return nil
        end

        self:DebugLog("Countdown debug: date detected anchor=" .. tostring(anchor) .. " token=" .. tostring(dateToken) .. " resolvedYear=" .. tostring(year) .. " resolvedMonth=" .. tostring(month) .. " resolvedDay=" .. tostring(day) .. " dayOffset=" .. tostring(dayOffset))
        return dayOffset
    end

    local beforeDateOffset = tryExtractDateOffset(beforeScope, "before_time")
    if beforeDateOffset ~= nil then
        self:DebugLog("Countdown debug: day detection selected date_before_time dayOffset=" .. tostring(beforeDateOffset))
        return beforeDateOffset
    end

    local afterDateWindow = afterScope
    if #afterDateWindow > 64 then
        afterDateWindow = afterDateWindow:sub(1, 64)
    end
    local afterDateOffset = tryExtractDateOffset(afterDateWindow, "after_time")
    if afterDateOffset ~= nil then
        self:DebugLog("Countdown debug: day detection selected date_after_time dayOffset=" .. tostring(afterDateOffset))
        return afterDateOffset
    end

    -- Do not let a broad full-text date scan suppress relative-day words like tomorrow.
    -- Prefer scoped dates near the detected time first; only use full-text date fallback
    -- after scoped relative-day / weekday parsing has had a chance to win.

    local function normalizeScope(scope)
        local normalizedScope = zo_strlower(tostring(scope or ""))
        normalizedScope = normalizedScope:gsub("[^%a%s]", " ")
        normalizedScope = normalizedScope:gsub("%s+", " ")
        normalizedScope = self:Trim(normalizedScope)
        return normalizedScope
    end

    local function extractDayToken(scope, anchor)
        if not scope or scope == "" then
            self:DebugLog("Countdown debug: no day token seen anchor=" .. tostring(anchor) .. " scope=empty")
            return nil
        end

        local normalizedScope = normalizeScope(scope)
        self:DebugLog("Countdown debug: normalized day scope anchor=" .. tostring(anchor) .. " scope=" .. tostring(normalizedScope))
        if normalizedScope == "" then
            self:DebugLog("Countdown debug: no day token seen anchor=" .. tostring(anchor) .. " scope=empty_after_normalize")
            return nil
        end

        local words = {}
        for word in normalizedScope:gmatch("%a+") do
            table.insert(words, word)
        end
        self:DebugLog("Countdown debug: day scan tokens anchor=" .. tostring(anchor) .. " tokens=" .. table.concat(words, "|"))

        for _, word in ipairs(words) do
            if word == "tomorrow" then
                self:DebugLog("Countdown debug: relative day detected=tomorrow anchor=" .. tostring(anchor) .. " dayOffset=1")
                return 1
            end
            if word == "today" or word == "tonight" then
                self:DebugLog("Countdown debug: relative day detected=today_or_tonight anchor=" .. tostring(anchor) .. " dayOffset=0")
                return 0
            end
        end

        for _, word in ipairs(words) do
            local targetWday = self:GetWeekdayIndexByName(word)
            if targetWday then
                local delta = (targetWday - now.wday) % 7
                self:DebugLog(string.format(
                    "Countdown debug: weekday detected=%s anchor=%s dayOffset=%s currentWday=%s targetWday=%s",
                    tostring(word),
                    tostring(anchor),
                    tostring(delta),
                    tostring(now.wday),
                    tostring(targetWday)
                ))
                return delta
            end
        end

        self:DebugLog("Countdown debug: no day token seen anchor=" .. tostring(anchor) .. " scope=" .. tostring(normalizedScope))
        return nil
    end

    local beforeOffset = extractDayToken(beforeScope, "before_time")
    if beforeOffset ~= nil then
        self:DebugLog("Countdown debug: day detection selected before_time dayOffset=" .. tostring(beforeOffset))
        return beforeOffset
    end

    local afterWindow = afterScope
    if #afterWindow > 48 then
        afterWindow = afterWindow:sub(1, 48)
    end
    local afterOffset = extractDayToken(afterWindow, "after_time")
    if afterOffset ~= nil then
        self:DebugLog("Countdown debug: day detection selected after_time dayOffset=" .. tostring(afterOffset))
        return afterOffset
    end

    local fullOffset = extractDayToken(source, "full_text_fallback")
    if fullOffset ~= nil then
        self:DebugLog("Countdown debug: day detection selected full_text_fallback dayOffset=" .. tostring(fullOffset))
        return fullOffset
    end

    local fullDateOffset = tryExtractDateOffset(source, "full_text_fallback")
    if fullDateOffset ~= nil then
        self:DebugLog("Countdown debug: day detection selected date_full_text_fallback dayOffset=" .. tostring(fullDateOffset))
        return fullDateOffset
    end

    self:DebugLog("Countdown debug: no day detected for matched time; defaulting dayOffset=nil")
    return nil
end

function SmartChatMsg:GetCountdownUntilEmbeddedTimeText(text)
    local timeMatch, hour, minute, sourceTz = self:FindEmbeddedTimeDetails(text)
    if not hour then
        self:DebugLog("Countdown debug: countdown not computed because no time was detected")
        return nil
    end

    local nowEpoch = os.time()
    local nowLocal = os.date("*t", nowEpoch)
    local localOffset = self:GetLocalUtcOffsetHours(nowEpoch)
    local sourceOffset = localOffset

    if sourceTz and self:Trim(sourceTz) ~= "" then
        local resolvedOffset = self:GetResolvedTimezoneOffsetHours(sourceTz)
        if resolvedOffset == nil then
            self:DebugLog("Countdown debug: countdown not computed because timezone could not be resolved for " .. tostring(sourceTz))
            return nil
        end
        sourceOffset = resolvedOffset
    end

    local dayOffset = self:GetEmbeddedDayOffset(text, nowEpoch, timeMatch)
    if dayOffset == nil then
        dayOffset = 0
    end

    local detectedText = zo_strlower(tostring(timeMatch or ""))
    local hasExplicitMeridiem = detectedText:find("%f[%a][ap]%.?%s*[m]%.?%f[%A]") ~= nil
    local shouldUseNearestFuture12Hour = (not hasExplicitMeridiem) and hour >= 1 and hour <= 12

    local function buildTargetEpoch(candidateHour)
        local candidateEpoch = os.time({
            year = nowLocal.year,
            month = nowLocal.month,
            day = nowLocal.day + dayOffset,
            hour = candidateHour,
            min = minute,
            sec = 0,
        }) + ((localOffset - sourceOffset) * 3600)

        if dayOffset == 0 then
            while candidateEpoch <= nowEpoch do
                candidateEpoch = candidateEpoch + (24 * 60 * 60)
            end
        elseif candidateEpoch <= nowEpoch then
            candidateEpoch = candidateEpoch + (7 * 24 * 60 * 60)
        end

        return candidateEpoch
    end

    local targetEpoch = nil
    local resolvedHour = hour
    if shouldUseNearestFuture12Hour then
        local candidateHours = { hour }
        local pmHour = hour % 12 + 12
        if pmHour ~= hour then
            table.insert(candidateHours, pmHour)
        end

        for _, candidateHour in ipairs(candidateHours) do
            local candidateEpoch = buildTargetEpoch(candidateHour)
            if not targetEpoch or candidateEpoch < targetEpoch then
                targetEpoch = candidateEpoch
                resolvedHour = candidateHour
            end
        end

        self:DebugLog(string.format(
            "Countdown debug: ambiguous 12-hour time without meridiem resolved to next future occurrence match=%s baseHour=%s chosenHour=%s chosenTargetEpoch=%s dayOffset=%s",
            tostring(timeMatch),
            tostring(hour),
            tostring(resolvedHour),
            tostring(targetEpoch),
            tostring(dayOffset)
        ))
    else
        targetEpoch = buildTargetEpoch(hour)
        resolvedHour = hour
    end

    local countdownText = self:GetApproximateCountdownTextFromSeconds(targetEpoch - nowEpoch, text, self:FindEmbeddedTimeSubstring(text))
    self:DebugLog(string.format(
        "Countdown debug: countdown computed=%s nowEpoch=%s targetEpoch=%s localOffset=%s sourceOffset=%s dayOffset=%s explicitMeridiem=%s resolvedHour=%s",
        tostring(countdownText),
        tostring(nowEpoch),
        tostring(targetEpoch),
        tostring(localOffset),
        tostring(sourceOffset),
        tostring(dayOffset),
        tostring(hasExplicitMeridiem),
        tostring(resolvedHour)
    ))

    local metadata = {
        timeMatch = timeMatch,
        sourceTz = sourceTz,
        hasExplicitMeridiem = hasExplicitMeridiem,
        shouldUseNearestFuture12Hour = shouldUseNearestFuture12Hour,
        assumedMeridiem = nil,
        resolvedHour24 = resolvedHour,
    }

    if shouldUseNearestFuture12Hour then
        metadata.assumedMeridiem = (resolvedHour >= 12) and "PM" or "AM"
    end

    return countdownText, metadata
end

function SmartChatMsg:InsertCountdownPreservingTemplate(text,eventAtUtc)
    local source = tostring(text or "")
    local timeMatch, _, _, sourceTz = self:FindEmbeddedTimeDetails(source)
    if not timeMatch or timeMatch == "" then
        self:DebugLog("Countdown debug: message text left unchanged because no time was detected")
        return source
    end

    local countdownText, countdownMeta = self:GetCountdownUntilEmbeddedTimeText(source,eventAtUtc)
    if not countdownText or countdownText == "" then
        self:DebugLog("Countdown debug: message text left unchanged because countdown text could not be computed")
        return source
    end

    local matchStart, matchEnd = source:find(self:EscapeLuaPattern(timeMatch), 1)
    if not matchStart then
        self:DebugLog("Countdown debug: message text left unchanged because detected time could not be located in source")
        return source
    end

    local function consumeLeadingPattern(segment, pattern)
        local matched = segment:match(pattern)
        if not matched or matched == "" then
            return "", segment
        end

        return matched, segment:sub(#matched + 1)
    end

    local function consumeLeadingSupportedTimezone(segment)
        local tokens = self:GetSupportedTimezoneTokens() or {}
        local working = segment
        local leadingWhitespace = working:match("^(%s*)") or ""
        local afterWhitespace = working:sub(#leadingWhitespace + 1)
        local lowerAfterWhitespace = zo_strlower(afterWhitespace)

        local bestToken = nil
        for _, token in ipairs(tokens) do
            local trimmedToken = self:Trim(token)
            if trimmedToken ~= "" then
                local lowerToken = zo_strlower(trimmedToken)
                if lowerAfterWhitespace:sub(1, #lowerToken) == lowerToken then
                    local nextChar = afterWhitespace:sub(#trimmedToken + 1, #trimmedToken + 1)
                    if nextChar == "" or not nextChar:match("[%a]") then
                        if not bestToken or #trimmedToken > #bestToken then
                            bestToken = trimmedToken
                        end
                    end
                end
            end
        end

        if not bestToken then
            return "", segment
        end

        local consumed = leadingWhitespace .. afterWhitespace:sub(1, #bestToken)
        return consumed, segment:sub(#consumed + 1)
    end

    local fullDisplayStart = matchStart
    local fullDisplayEnd = matchEnd
    local fullDisplayMatch = source:sub(fullDisplayStart, fullDisplayEnd)
    local trailing = source:sub(matchEnd + 1)

    local consumedMeridiem = ""
    consumedMeridiem, trailing = consumeLeadingPattern(trailing, "^%s*[AaPp]%.?%s*[Mm]%.?")
    if consumedMeridiem ~= "" then
        fullDisplayEnd = fullDisplayEnd + #consumedMeridiem
        fullDisplayMatch = source:sub(fullDisplayStart, fullDisplayEnd)
    end

    local consumedTimezone = ""
    consumedTimezone, trailing = consumeLeadingSupportedTimezone(trailing)
    if consumedTimezone ~= "" then
        fullDisplayEnd = fullDisplayEnd + #consumedTimezone
        fullDisplayMatch = source:sub(fullDisplayStart, fullDisplayEnd)
    end

    local explicitMeridiemMatch = fullDisplayMatch:match("(%s*[AaPp]%.?%s*[Mm]%.?)")
    local assumedMeridiemSuffix = ""
    if countdownMeta and countdownMeta.assumedMeridiem and not explicitMeridiemMatch then
        assumedMeridiemSuffix = " " .. countdownMeta.assumedMeridiem
    end

    local existingTimezoneInDisplay = ""
    do
        local tokens = self:GetSupportedTimezoneTokens() or {}
        local bestToken = nil
        local lowerDisplay = zo_strlower(fullDisplayMatch)
        for _, token in ipairs(tokens) do
            local trimmedToken = self:Trim(token)
            if trimmedToken ~= "" then
                local pattern = "(%s+" .. self:EscapeLuaPattern(trimmedToken) .. ")%s*$"
                local match = fullDisplayMatch:match(pattern)
                if match and (not bestToken or #trimmedToken > #bestToken) then
                    bestToken = trimmedToken
                    existingTimezoneInDisplay = match
                end
            end
        end
    end

    local timezoneSuffix = ""
    if existingTimezoneInDisplay ~= "" and self:Trim(existingTimezoneInDisplay) ~= "" then
        timezoneSuffix = existingTimezoneInDisplay
    elseif consumedTimezone ~= "" and self:Trim(consumedTimezone) ~= "" then
        timezoneSuffix = consumedTimezone
    elseif sourceTz and self:Trim(sourceTz) ~= "" then
        timezoneSuffix = " " .. self:Trim(sourceTz)
    else
        timezoneSuffix = " " .. self:GetLocalTimezoneDisplayName()
    end

    local insertionText = fullDisplayMatch .. assumedMeridiemSuffix
    if existingTimezoneInDisplay == "" and consumedTimezone == "" then
        insertionText = insertionText .. timezoneSuffix
    end
    insertionText = insertionText .. " (" .. countdownText .. ")"

    local remainder = source:sub(fullDisplayEnd + 1)
    local normalizedTimezoneSuffix = self:Trim(timezoneSuffix)
    if normalizedTimezoneSuffix ~= "" then
        local leadingWhitespace = remainder:match("^(%s*)") or ""
        local afterWhitespace = remainder:sub(#leadingWhitespace + 1)
        local lowerAfterWhitespace = zo_strlower(afterWhitespace)
        local lowerTimezoneSuffix = zo_strlower(normalizedTimezoneSuffix)
        if lowerAfterWhitespace:sub(1, #lowerTimezoneSuffix) == lowerTimezoneSuffix then
            local nextChar = afterWhitespace:sub(#normalizedTimezoneSuffix + 1, #normalizedTimezoneSuffix + 1)
            if nextChar == "" or not nextChar:match("[%a]") then
                remainder = leadingWhitespace .. afterWhitespace:sub(#normalizedTimezoneSuffix + 1)
                self:DebugLog("Countdown debug: removed duplicate trailing timezone token from remainder token=" .. tostring(normalizedTimezoneSuffix))
            end
        end
    end

    local updatedText = source:sub(1, fullDisplayStart - 1) .. insertionText .. remainder
    self:DebugLog("Countdown debug: updated message text=" .. tostring(updatedText))
    -- Expose the exact insertion boundary to incoming-template matching. The
    -- original date/time stays literal; only the formatter's additions vary.
    return updatedText, {
        prefix = source:sub(1, fullDisplayStart - 1),
        timeText = fullDisplayMatch,
        suffix = remainder,
        allowMeridiem = countdownMeta and countdownMeta.shouldUseNearestFuture12Hour == true and not explicitMeridiemMatch,
        allowTimezone = existingTimezoneInDisplay == "" and consumedTimezone == "",
        soonText = self:HasEndingPhraseBeforeTime(source, timeMatch) and "ending soon" or "starting soon",
    }
end

function SmartChatMsg:ApplyMessageSubstitutions(text, commandId, guildName)
    local result = self:ResolveScheduledEventTokens(text, commandId, guildName)
    local timeOfDay = self:GetCurrentTimeTokenValue()

    local substitutions = {
        ["timeofday"] = timeOfDay,
        ["greeting"] = timeOfDay,
        ["time"] = timeOfDay,
        ["guild"] = self:Trim(guildName or ""),
        ["zone"] = self:GetCurrentZoneName() or "",
    }

    result = result:gsub("%%([%a]+)%%", function(tokenName)
        local normalizedToken = zo_strlower(tokenName or "")
        local replacement = substitutions[normalizedToken]
        if replacement ~= nil and replacement ~= "" then
            return replacement
        end

        return "%" .. tostring(tokenName or "") .. "%"
    end)

    result = self:InsertCountdownIntoMessageText(result)
    return result
end

function SmartChatMsg:ShowCommandTestNotification(commandName, parameterValue)
    local message = string.format("SmartChatMsg test: command %s called with parameter %s", tostring(commandName), tostring(parameterValue))

    SmartChatMsg:AddLocalChatMessage(message)

    if CENTER_SCREEN_ANNOUNCE then
        CENTER_SCREEN_ANNOUNCE:AddMessage(EVENT_SKILL_RANK_UPDATE, CSA_EVENT_SMALL_TEXT, SOUNDS.DEFAULT_CLICK, message)
    end
end

function SmartChatMsg:ShowStatusMessage(message)
    self:AddLocalChatMessage(message)
    if CENTER_SCREEN_ANNOUNCE then
        CENTER_SCREEN_ANNOUNCE:AddMessage(EVENT_SKILL_RANK_UPDATE, CSA_EVENT_SMALL_TEXT, SOUNDS.DEFAULT_CLICK, tostring(message or ""))
    end
end

function SmartChatMsg:GetSlashCommandDisplayName(commandId, fallbackSlashCommandName)
    local commandName = self:GetCommandNameById(commandId)
    local slashCommandName = self:BuildSlashCommandName(commandName or "") or fallbackSlashCommandName or "/command"
    return slashCommandName
end

function SmartChatMsg:GetGuildSlotByName(guildName)
    if type(guildName) ~= "string" or guildName == "" then
        return nil
    end

    for guildIndex = 1, 5 do
        local guildId = GetGuildId(guildIndex)
        if guildId and guildId ~= 0 then
            local currentGuildName = GetGuildName(guildId)
            if currentGuildName and self:StringsEqualIgnoreCase(currentGuildName, guildName) then
                return guildIndex
            end
        end
    end

    return nil
end

function SmartChatMsg:GetMessageEntriesForCommandAndGuild(commandId, guildName)
    local results = {}

    if type(commandId) ~= "string" or commandId == "" then
        return results
    end

    if type(guildName) ~= "string" or guildName == "" then
        return results
    end

    for _, entry in ipairs(self.savedVars.messages or {}) do
        if type(entry) == "table" and entry.commandId == commandId then
            local entryGuildName = entry.guildName

            if (not entryGuildName or entryGuildName == "") and entry.guildIndex then
                entryGuildName = self:GetGuildNameByIndex(entry.guildIndex)
            end

            if entryGuildName and self:StringsEqualIgnoreCase(entryGuildName, guildName) then
                table.insert(results, entry)
            end
        end
    end

    return results
end


function SmartChatMsg:GetMessageUsageTimestamp(entry)
    local value = type(entry) == "table" and entry.lastUsedAt or nil
    if type(value) ~= "number" or value < 0 then
        return nil
    end

    return math.floor(value)
end

function SmartChatMsg:GetMessageUseCount(entry)
    local value = type(entry) == "table" and entry.useCount or nil
    if type(value) ~= "number" or value < 0 then
        return 0
    end

    return math.floor(value)
end

function SmartChatMsg:SelectWeightedMessageEntry(messages)
    if type(messages) ~= "table" or #messages == 0 then
        return nil
    end

    local ranked = {}
    for _, entry in ipairs(messages) do
        if type(entry) == "table" then
            table.insert(ranked, entry)
        end
    end

    if #ranked == 0 then
        return nil
    end

    table.sort(ranked, function(a, b)
        local aLastUsed = self:GetMessageUsageTimestamp(a)
        local bLastUsed = self:GetMessageUsageTimestamp(b)

        if aLastUsed == nil and bLastUsed ~= nil then
            return true
        end

        if aLastUsed ~= nil and bLastUsed == nil then
            return false
        end

        if aLastUsed ~= bLastUsed then
            return (aLastUsed or 0) < (bLastUsed or 0)
        end

        local aUseCount = self:GetMessageUseCount(a)
        local bUseCount = self:GetMessageUseCount(b)

        if aUseCount ~= bUseCount then
            return aUseCount < bUseCount
        end

        return tostring(a.id or "") < tostring(b.id or "")
    end)

    local totalWeight = 0
    for index = 1, #ranked do
        totalWeight = totalWeight + (#ranked - index + 1)
    end

    local roll = zo_random(1, totalWeight)
    local runningWeight = 0

    for index, entry in ipairs(ranked) do
        runningWeight = runningWeight + (#ranked - index + 1)
        if roll <= runningWeight then
            return entry
        end
    end

    return ranked[1]
end

function SmartChatMsg:MarkMessageEntryUsed(entry)
    if type(entry) ~= "table" then
        return
    end

    entry.useCount = self:GetMessageUseCount(entry) + 1
    entry.lastUsedAt = GetTimeStamp()
end

function SmartChatMsg:MarkCommandUsed(commandId, guildName, paramText, guildIndex)
    local command = self:GetCommandById(commandId)
    if not command then
        self:DebugLog("Reminder debug: MarkCommandUsed aborted, command not found for commandId=" .. tostring(commandId))
        return
    end

    local timestamp = GetTimeStamp()
    command.lastUsedAt = timestamp
    self:SetGuildLastUsedState(commandId, guildName, timestamp, paramText, guildIndex)

    self:DebugLog(string.format(
        "Reminder debug: MarkCommandUsed commandId=%s guildName=%s guildIndex=%s lastUsedAt=%s paramText=%s",
        tostring(commandId),
        tostring(guildName),
        tostring(guildIndex),
        tostring(timestamp),
        tostring(paramText or "")
    ))
end

function SmartChatMsg:GetReminderTimerName(commandId, guildName)
    if type(commandId) ~= "string" or commandId == "" then
        return nil
    end

    local guildKey = self:NormalizeKey(guildName) or "default"
    return "SmartChatMsgReminder_" .. commandId .. "_" .. guildKey
end

function SmartChatMsg:GetReminderStateKey(commandId, guildName)
    if type(commandId) ~= "string" or commandId == "" then
        return nil
    end

    local guildKey = self:NormalizeKey(guildName)
    if not guildKey then
        return nil
    end

    return commandId .. "::" .. guildKey
end

function SmartChatMsg:SetReminderAutomationActive(commandId, guildName, isActive, nextTriggerAt)
    local stateKey = self:GetReminderStateKey(commandId, guildName)
    if not stateKey then
        return
    end

    if isActive then
        local state = self.activeReminderStates[stateKey]
        if type(state) ~= "table" then
            state = {}
            self.activeReminderStates[stateKey] = state
        end

        state.isActive = true
        if type(nextTriggerAt) == "number" and nextTriggerAt > 0 then
            state.nextTriggerAt = math.floor(nextTriggerAt)
        else
            state.nextTriggerAt = nil
        end
    else
        self.activeReminderStates[stateKey] = nil
    end
end

function SmartChatMsg:GetReminderAutomationState(commandId, guildName)
    local stateKey = self:GetReminderStateKey(commandId, guildName)
    local state = stateKey and self.activeReminderStates[stateKey] or nil

    if state == true then
        return { isActive = true, nextTriggerAt = nil }
    end

    if type(state) == "table" and state.isActive == true then
        if type(state.nextTriggerAt) == "number" and state.nextTriggerAt > 0 then
            state.nextTriggerAt = math.floor(state.nextTriggerAt)
        else
            state.nextTriggerAt = nil
        end
        return state
    end

    return nil
end

function SmartChatMsg:GetReminderNextTriggerAt(commandId, guildName)
    local state = self:GetReminderAutomationState(commandId, guildName)
    return state and state.nextTriggerAt or nil
end

function SmartChatMsg:IsReminderAutomationActive(commandId, guildName)
    local state = self:GetReminderAutomationState(commandId, guildName)
    return state ~= nil and state.isActive == true
end

function SmartChatMsg:DeactivateReminderAutomation(commandId, guildName, reason)
    self:SetReminderAutomationActive(commandId, guildName, false)
    self:ClearCommandReminder(commandId, guildName)

    local pendingState = self.pendingRestoreState
    local metadata = pendingState and pendingState.metadata or nil
    if type(metadata) == "table"
        and metadata.reminderRepeat == true
        and metadata.commandId == commandId
        and self:StringsEqualIgnoreCase(metadata.guildName or "", guildName or "") then
        self:ClearPendingRestoreState(reason or "reminder automation deactivated")
    end
end

function SmartChatMsg:ClearCommandReminder(commandId, guildName)
    local timerName = self:GetReminderTimerName(commandId, guildName)
    if timerName then
        self:DebugLog("Reminder debug: clearing timer " .. tostring(timerName))
        EVENT_MANAGER:UnregisterForUpdate(timerName)
    else
        self:DebugLog("Reminder debug: ClearCommandReminder had no timerName for commandId=" .. tostring(commandId))
    end
end

function SmartChatMsg:PlayPopulateSound(commandId, guildName)
    local soundKey = self:GetGuildPopulateSound(commandId, guildName)
    if soundKey == "NONE" then
        return
    end

    if type(SOUNDS) == "table" and SOUNDS[soundKey] then
        PlaySound(SOUNDS[soundKey])
    end
end

function SmartChatMsg:HandleReminderPopulateSuccess(metadata)
    if type(metadata) ~= "table" then
        return
    end

    self:DebugLog(string.format(
        "Reminder debug: confirmed sent by watcher for commandId=%s guildName=%s",
        tostring(metadata.commandId),
        tostring(metadata.guildName)
    ))

    self:MarkCommandUsed(metadata.commandId, metadata.guildName, metadata.paramText, metadata.guildIndex)
    self:ScheduleCommandReminder(metadata.commandId, metadata.guildName)
end

function SmartChatMsg:HandleReminderPopulateTimeout(metadata)
    if type(metadata) ~= "table" then
        return
    end

    if not self:IsReminderAutomationActive(metadata.commandId, metadata.guildName) then
        self:DebugLog("Reminder debug: timeout ignored because reminder automation is inactive")
        return
    end

    local commandId = metadata.commandId
    local guildName = metadata.guildName
    local expectedLastUsedAt = metadata.lastUsedAt

    if type(commandId) ~= "string" or commandId == "" or type(guildName) ~= "string" or guildName == "" then
        return
    end

    local currentLastUsedAt = self:GetGuildLastUsedAt(commandId, guildName)
    self:DebugLog(string.format(
        "Reminder debug: timeout handling commandId=%s guildName=%s expectedLastUsedAt=%s currentLastUsedAt=%s",
        tostring(commandId),
        tostring(guildName),
        tostring(expectedLastUsedAt),
        tostring(currentLastUsedAt)
    ))

    if currentLastUsedAt ~= expectedLastUsedAt then
        self:DebugLog(string.format(
            "Reminder debug: timeout retry skipped because lastUsedAt changed for commandId=%s guildName=%s",
            tostring(commandId),
            tostring(guildName)
        ))
        return
    end

    local retryMinutes = self:GetGuildEffectiveReminderRetryMinutes(commandId, guildName) or 0
    local timerName = self:GetReminderTimerName(commandId, guildName)
    if not timerName then
        return
    end

    if retryMinutes <= 0 then
        self:DebugLog(string.format(
            "Reminder debug: retry disabled, resuming repeat-after schedule commandId=%s guildName=%s",
            tostring(commandId),
            tostring(guildName)
        ))
        self:ScheduleCommandReminder(commandId, guildName)
        return
    end

    local delayMs = retryMinutes * 60 * 1000
    local nextTriggerAt = GetTimeStamp() + (retryMinutes * 60)
    self:SetReminderAutomationActive(commandId, guildName, true, nextTriggerAt)
    self:DebugLog(string.format(
        "Reminder debug: scheduling retry timer timerName=%s commandId=%s guildName=%s retryMinutes=%s delayMs=%s",
        tostring(timerName),
        tostring(commandId),
        tostring(guildName),
        tostring(retryMinutes),
        tostring(delayMs)
    ))

    EVENT_MANAGER:RegisterForUpdate(timerName, delayMs, function()
        self:SetReminderAutomationActive(commandId, guildName, true, nil)
        self:DebugLog(string.format(
            "Reminder debug: retry timer fired timerName=%s commandId=%s guildName=%s",
            tostring(timerName),
            tostring(commandId),
            tostring(guildName)
        ))

        EVENT_MANAGER:UnregisterForUpdate(timerName)
        self:TriggerReminderPopulate(commandId, guildName, expectedLastUsedAt, "retry")
    end)
end

function SmartChatMsg:TriggerReminderPopulate(commandId, guildName, expectedLastUsedAt, reason)
    if not self:IsReminderAutomationActive(commandId, guildName) then
        self:DebugLog("Reminder debug: populate skipped because reminder automation is inactive")
        return
    end

    local command = self:GetCommandById(commandId)
    if not command then
        self:DebugLog("Reminder debug: populate aborted, command not found for commandId=" .. tostring(commandId))
        return
    end

    if not self:GetGuildReminderMinutes(commandId, guildName) then
        self:DebugLog("Reminder debug: populate aborted, repeat-after is not configured for commandId=" .. tostring(commandId))
        return
    end

    local currentLastUsedAt = self:GetGuildLastUsedAt(commandId, guildName)
    self:DebugLog(string.format(
        "Reminder debug: attempting populate commandId=%s guildName=%s reason=%s expectedLastUsedAt=%s currentLastUsedAt=%s",
        tostring(commandId),
        tostring(guildName),
        tostring(reason or "initial"),
        tostring(expectedLastUsedAt),
        tostring(currentLastUsedAt)
    ))

    if currentLastUsedAt ~= expectedLastUsedAt then
        self:DebugLog(string.format(
            "Reminder debug: populate skipped because lastUsedAt changed for commandId=%s guildName=%s",
            tostring(commandId),
            tostring(guildName)
        ))
        return
    end

    local metadata = {
        reminderRepeat = true,
        commandId = commandId,
        guildName = guildName,
        lastUsedAt = expectedLastUsedAt,
        paramText = self:GetGuildLastUsedParamText(commandId, guildName),
        guildIndex = self:GetGuildLastUsedGuildIndex(commandId, guildName),
        reason = reason or "initial",
    }

    local ok, err = self:PopulateChatBufferForCommand(commandId, guildName, nil, metadata)
    if not ok then
        self:DebugLog(string.format(
            "Reminder debug: populate failed commandId=%s guildName=%s err=%s",
            tostring(commandId),
            tostring(guildName),
            tostring(err)
        ))
        return
    end

    self:SetReminderAutomationActive(commandId, guildName, true, nil)
    self:DebugLog(string.format(
        "Reminder debug: populate armed successfully for commandId=%s guildName=%s",
        tostring(commandId),
        tostring(guildName)
    ))
end

function SmartChatMsg:ScheduleCommandReminder(commandId, guildName, extraDelaySeconds)
    if self:GetGuildRunAt(commandId, guildName) == "SCHEDULED" then
        self:ScheduleNextScheduledDelivery(commandId, guildName, extraDelaySeconds)
        return
    end
    local command = self:GetCommandById(commandId)
    if not command then
        self:DebugLog("Reminder debug: schedule aborted, command not found for commandId=" .. tostring(commandId))
        return
    end

    local reminderMinutes = self:GetGuildReminderMinutes(commandId, guildName)
    self:ClearCommandReminder(commandId, guildName)

    if not reminderMinutes then
        self:SetReminderAutomationActive(commandId, guildName, false)
        self:DebugLog(string.format(
            "Reminder debug: schedule aborted, no repeat-after configured for commandId=%s commandName=%s guildName=%s",
            tostring(commandId),
            tostring(command.name or "unknown"),
            tostring(guildName)
        ))
        return
    end

    self:SetReminderAutomationActive(commandId, guildName, true, nil)

    local lastUsedAt = self:GetGuildLastUsedAt(commandId, guildName)
    if type(lastUsedAt) ~= "number" or lastUsedAt <= 0 then
        self:DebugLog(string.format(
            "Reminder debug: schedule aborted, invalid lastUsedAt=%s for commandId=%s commandName=%s guildName=%s",
            tostring(lastUsedAt),
            tostring(commandId),
            tostring(command.name or "unknown"),
            tostring(guildName)
        ))
        self:SetReminderAutomationActive(commandId, guildName, false)
        return
    end

    local timerName = self:GetReminderTimerName(commandId, guildName)
    if not timerName then
        self:DebugLog("Reminder debug: schedule aborted, timerName was nil for commandId=" .. tostring(commandId))
        return
    end

    local delayMs = (reminderMinutes * 60 + (extraDelaySeconds or 0)) * 1000
    local nextTriggerAt = GetTimeStamp() + delayMs / 1000
    self:SetReminderAutomationActive(commandId, guildName, true, nextTriggerAt)
    self:DebugLog(string.format(
        "Reminder debug: scheduling repeat-after timer timerName=%s commandId=%s commandName=%s guildName=%s repeatAfterMinutes=%s delayMs=%s lastUsedAt=%s",
        tostring(timerName),
        tostring(commandId),
        tostring(command.name or "unknown"),
        tostring(guildName),
        tostring(reminderMinutes),
        tostring(delayMs),
        tostring(lastUsedAt)
    ))

    EVENT_MANAGER:RegisterForUpdate(timerName, delayMs, function()
        self:DebugLog(string.format(
            "Reminder debug: repeat-after timer fired timerName=%s commandId=%s guildName=%s",
            tostring(timerName),
            tostring(commandId),
            tostring(guildName)
        ))

        EVENT_MANAGER:UnregisterForUpdate(timerName)
        self:TriggerReminderPopulate(commandId, guildName, lastUsedAt, "initial")
    end)
end

function SmartChatMsg:ClearActiveAutoPopulate()
    self.savedVars.activeAutoPopulate = nil
end

function SmartChatMsg:ToggleOffActiveAutoPopulateIfMatching(commandId, guildName)
    local active = self:GetActiveAutoPopulate()
    if not active then
        return false
    end

    if active.commandId == commandId and self:StringsEqualIgnoreCase(active.guildName, guildName) then
        local pendingState = self.pendingRestoreState
        local metadata = pendingState and pendingState.metadata or nil
        if type(metadata) == "table"
            and metadata.autoPopulate == true
            and metadata.commandId == commandId
            and self:StringsEqualIgnoreCase(metadata.guildName or "", guildName or "") then
            self:ClearPendingRestoreState("matching auto populate toggled off")
        end

        self:ClearActiveAutoPopulate()
        if self.statusPanelVisible then
            self:RefreshStatusPanel()
        end
        return true
    end

    return false
end

function SmartChatMsg:GetPreciseChatChannelInfo()
    if not CHAT_SYSTEM then
        return nil
    end

    local cd, target = CHAT_SYSTEM:GetCurrentChannelData()
    if not cd then
        return nil
    end

    local id = cd.id
    local info = {
        id = id,
        target = target,
        kind = "unknown",
        index = nil,
        short = "unknown",
    }

    if id == CHAT_CHANNEL_ZONE then
        info.kind = "zone"
        info.short = "zone"
    elseif id == CHAT_CHANNEL_PARTY then
        info.kind = "group"
        info.short = "group"
    elseif id == CHAT_CHANNEL_SAY then
        info.kind = "say"
        info.short = "say"
    elseif id == CHAT_CHANNEL_YELL then
        info.kind = "yell"
        info.short = "yell"
    elseif id == CHAT_CHANNEL_EMOTE then
        info.kind = "emote"
        info.short = "emote"
    elseif id == CHAT_CHANNEL_WHISPER or id == CHAT_CHANNEL_WHISPER_SENT then
        info.kind = "tell"
        info.short = "tell"
    elseif id >= CHAT_CHANNEL_GUILD_1 and id <= CHAT_CHANNEL_GUILD_5 then
        local index = id - CHAT_CHANNEL_GUILD_1 + 1
        info.kind = "guild"
        info.index = index
        info.short = "g" .. index
    elseif id >= CHAT_CHANNEL_OFFICER_1 and id <= CHAT_CHANNEL_OFFICER_5 then
        local index = id - CHAT_CHANNEL_OFFICER_1 + 1
        info.kind = "officer"
        info.index = index
        info.short = "o" .. index
    end

    return info
end

function SmartChatMsg:RestoreChatChannel(channelInfo)
    if not channelInfo or not CHAT_SYSTEM or not channelInfo.id then
        self:DebugLog("RestoreChatChannel aborted: missing channel info")
        return false
    end

    self:DebugLog("Restoring chat channel: " .. self:FormatChatChannelInfo(channelInfo))
    CHAT_SYSTEM:SetChannel(channelInfo.id, channelInfo.target)
    return true
end

function SmartChatMsg:ClearPendingChatBuffer()
    self:DebugLog("ClearPendingChatBuffer start")

    local cleared = false

    if self:GetChatEditControl() then
        local editControl = self:GetChatEditControl()

        if editControl.SetText then
            editControl:SetText("")
            cleared = true
        end

        if editControl.LoseFocus then
            editControl:LoseFocus()
        end
    end

    if CHAT_SYSTEM and CHAT_SYSTEM.textEntry then
        if CHAT_SYSTEM.textEntry.SetText then
            CHAT_SYSTEM.textEntry:SetText("")
            cleared = true
        end

        if CHAT_SYSTEM.textEntry.LoseFocus then
            CHAT_SYSTEM.textEntry:LoseFocus()
        end
    end

    if ZO_ChatWindowTextEntryEditBox then
        if ZO_ChatWindowTextEntryEditBox.SetText then
            ZO_ChatWindowTextEntryEditBox:SetText("")
            cleared = true
        end

        if ZO_ChatWindowTextEntryEditBox.LoseFocus then
            ZO_ChatWindowTextEntryEditBox:LoseFocus()
        end
    end

    if CHAT_SYSTEM and CHAT_SYSTEM.Maximize then
        CHAT_SYSTEM:Maximize()
    end

    if CHAT_SYSTEM and CHAT_SYSTEM.Minimize then
        CHAT_SYSTEM:Minimize()
    end

    self:DebugLog("ClearPendingChatBuffer result=" .. tostring(cleared))
    return cleared
end


function SmartChatMsg:NormalizeChatText(text)
    local value = self:Trim(text or "")
    value = zo_strlower(value)

    value = value:gsub("|c%x%x%x%x%x%x", "")
    value = value:gsub("|r", "")
    value = value:gsub("[%c]", " ")
    value = value:gsub("[%p]", " ")
    value = value:gsub("%s+", " ")

    return self:Trim(value)
end

function SmartChatMsg:GetLevenshteinDistance(a, b)
    a = a or ""
    b = b or ""

    local lenA = #a
    local lenB = #b

    if lenA == 0 then
        return lenB
    end

    if lenB == 0 then
        return lenA
    end

    local matrix = {}

    for i = 0, lenA do
        matrix[i] = {}
        matrix[i][0] = i
    end

    for j = 0, lenB do
        matrix[0][j] = j
    end

    for i = 1, lenA do
        local charA = a:sub(i, i)

        for j = 1, lenB do
            local cost = (charA == b:sub(j, j)) and 0 or 1

            local deletion = matrix[i - 1][j] + 1
            local insertion = matrix[i][j - 1] + 1
            local substitution = matrix[i - 1][j - 1] + cost

            matrix[i][j] = math.min(deletion, insertion, substitution)
        end
    end

    return matrix[lenA][lenB]
end

function SmartChatMsg:GetFuzzyMessageMatchDetails(expectedText, actualText)
    local expected = self:NormalizeChatText(expectedText)
    local actual = self:NormalizeChatText(actualText)

    local details = {
        expected = expected,
        actual = actual,
        matched = false,
        method = "none",
        similarity = 0,
        distance = nil,
    }

    if expected == "" or actual == "" then
        return details
    end

    if expected == actual then
        details.matched = true
        details.method = "exact"
        details.similarity = 1
        details.distance = 0
        return details
    end

    if expected:find(actual, 1, true) or actual:find(expected, 1, true) then
        local shorterLength = math.min(#expected, #actual)
        details.method = "contains"
        details.matched = shorterLength >= math.max(8, math.floor(math.min(#expected, #actual) * 0.8))
        details.similarity = shorterLength / math.max(#expected, #actual)
        return details
    end

    local distance = self:GetLevenshteinDistance(expected, actual)
    local longest = math.max(#expected, #actual)
    local similarity = 1 - (distance / longest)

    details.method = "levenshtein"
    details.distance = distance
    details.similarity = similarity
    details.matched = similarity >= 0.82

    return details
end

function SmartChatMsg:IsFuzzyMessageMatch(expectedText, actualText)
    return self:GetFuzzyMessageMatchDetails(expectedText, actualText).matched
end

function SmartChatMsg:IsOutgoingChatMessageType(messageType)
    if type(messageType) ~= "number" then
        return false
    end

    -- Channel ids
    if messageType == CHAT_CHANNEL_SAY
        or messageType == CHAT_CHANNEL_YELL
        or messageType == CHAT_CHANNEL_EMOTE
        or messageType == CHAT_CHANNEL_PARTY
        or messageType == CHAT_CHANNEL_ZONE
        or messageType == CHAT_CHANNEL_WHISPER
        or messageType == CHAT_CHANNEL_WHISPER_SENT
        or (messageType >= CHAT_CHANNEL_GUILD_1 and messageType <= CHAT_CHANNEL_GUILD_5)
        or (messageType >= CHAT_CHANNEL_OFFICER_1 and messageType <= CHAT_CHANNEL_OFFICER_5) then
        return true
    end

    -- Category ids fallback
    if messageType == CHAT_CATEGORY_SAY
        or messageType == CHAT_CATEGORY_YELL
        or messageType == CHAT_CATEGORY_EMOTE
        or messageType == CHAT_CATEGORY_PARTY
        or messageType == CHAT_CATEGORY_ZONE
        or messageType == CHAT_CATEGORY_WHISPER_SENT
        or messageType == CHAT_CATEGORY_WHISPER
        or messageType == CHAT_CATEGORY_GUILD_1
        or messageType == CHAT_CATEGORY_GUILD_2
        or messageType == CHAT_CATEGORY_GUILD_3
        or messageType == CHAT_CATEGORY_GUILD_4
        or messageType == CHAT_CATEGORY_GUILD_5
        or messageType == CHAT_CATEGORY_OFFICER_1
        or messageType == CHAT_CATEGORY_OFFICER_2
        or messageType == CHAT_CATEGORY_OFFICER_3
        or messageType == CHAT_CATEGORY_OFFICER_4
        or messageType == CHAT_CATEGORY_OFFICER_5 then
        return true
    end

    return false
end

function SmartChatMsg:ClearPendingRestoreState(reason)
    local hadPendingState = self.pendingRestoreState ~= nil

    if self.pendingRestoreState then
        self:DebugLog(string.format(
            "Clearing pending restore state reason=%s previousChannel=%s expectedText=%s",
            tostring(reason or "unspecified"),
            self:FormatChatChannelInfo(self.pendingRestoreState.previousChannel),
            tostring(self.pendingRestoreState.expectedText or "")
        ))
    else
        self:DebugLog("ClearPendingRestoreState called with no pending state reason=" .. tostring(reason or "unspecified"))
    end

    self.pendingRestoreState = nil
    EVENT_MANAGER:UnregisterForEvent(self.restoreWatcherEventName, EVENT_CHAT_MESSAGE_CHANNEL)
    EVENT_MANAGER:UnregisterForUpdate(self.restoreWatcherTimeoutName)

    if hadPendingState then
        self:SetGlobalExecutionStatus("available", reason or "pending restore cleared")
    end
end

function SmartChatMsg:GetGlobalExecutionStatus()
    if type(self.savedVars) ~= "table" then
        return "available"
    end

    local status = self.savedVars.globalExecutionStatus
    if status ~= "busy" then
        status = "available"
    end

    return status
end

function SmartChatMsg:SetGlobalExecutionStatus(status, reason)
    if type(self.savedVars) ~= "table" then
        return
    end

    local normalized = (status == "busy") and "busy" or "available"
    local previous = self:GetGlobalExecutionStatus()
    self.savedVars.globalExecutionStatus = normalized

    self:DebugLog(string.format(
        "Execution status changed from %s to %s reason=%s",
        tostring(previous),
        tostring(normalized),
        tostring(reason or "unspecified")
    ))

    if normalized == "available" and previous ~= "available" then
        self:ScheduleStartupQueueNextStep(0, reason or "status available")
    end
end

function SmartChatMsg:IsExecutionBusy()
    return self:GetGlobalExecutionStatus() == "busy" or self.pendingRestoreState ~= nil
end

function SmartChatMsg:BuildQueuedRawParam(guildSlot, channelOverride, stopAutomation)
    local parts = {}

    if type(guildSlot) == "number" and guildSlot >= 1 and guildSlot <= 5 then
        if channelOverride == "Guild" then
            table.insert(parts, string.format("g%d", guildSlot))
        elseif channelOverride == "Officer" then
            table.insert(parts, string.format("o%d", guildSlot))
        else
            table.insert(parts, tostring(guildSlot))
        end
    end

    if stopAutomation == true then
        table.insert(parts, "off")
    end

    return table.concat(parts, " ")
end

function SmartChatMsg:BuildQueueIdentityKey(commandId, guildName, guildIndex)
    if type(commandId) ~= "string" or commandId == "" then
        return nil
    end

    local normalizedGuildName = self:NormalizeKey(guildName)
    if normalizedGuildName then
        return string.format("%s::%s", tostring(commandId), tostring(normalizedGuildName))
    end

    if type(guildIndex) == "number" and guildIndex >= 1 and guildIndex <= 5 then
        local resolvedGuildName = self:GetGuildNameByIndex(guildIndex)
        local resolvedGuildKey = self:NormalizeKey(resolvedGuildName)
        if resolvedGuildKey then
            return string.format("%s::%s", tostring(commandId), tostring(resolvedGuildKey))
        end

        return string.format("%s::guildindex:%d", tostring(commandId), guildIndex)
    end

    return string.format("%s::noguild", tostring(commandId))
end

function SmartChatMsg:QueueCommandExecution(commandId, slashCommandName, rawParam, source, details)
    if type(commandId) ~= "string" or commandId == "" then
        self:DebugLog("Execution queue: enqueue aborted because commandId was invalid")
        return false
    end

    if type(self.startupQueue) ~= "table" then
        self.startupQueue = {}
    end

    local detailsTable = type(details) == "table" and details or nil
    local queueKey = self:BuildQueueIdentityKey(
        commandId,
        detailsTable and detailsTable.guildName or nil,
        detailsTable and detailsTable.guildIndex or nil
    )

    local entry = {
        id = self:GenerateUuid(),
        queueKey = queueKey,
        commandId = commandId,
        slashCommandName = slashCommandName or self:GetSlashCommandDisplayName(commandId),
        rawParam = self:Trim(rawParam or ""),
        source = self:Trim(source or "queued"),
        enqueuedAt = os.time(),
    }

    if detailsTable then
        for key, value in pairs(detailsTable) do
            if entry[key] == nil then
                entry[key] = value
            end
        end
    end

    self:DebugLog("Execution queue: enqueue request " .. self:FormatQueueEntry(entry))

    if queueKey then
        local currentEntry = self.startupQueueCurrent
        if type(currentEntry) == "table" and currentEntry.queueKey == queueKey then
            self:DebugLog("Execution queue: replacing active current entry old=" .. self:FormatQueueEntry(currentEntry))

            local preservedId = currentEntry.id
            local preservedEnqueuedAt = currentEntry.enqueuedAt

            for key, _ in pairs(currentEntry) do
                currentEntry[key] = nil
            end

            for key, value in pairs(entry) do
                currentEntry[key] = value
            end

            currentEntry.id = preservedId or currentEntry.id
            currentEntry.enqueuedAt = preservedEnqueuedAt or currentEntry.enqueuedAt

            for index, existingEntry in ipairs(self.startupQueue) do
                if existingEntry == currentEntry or (type(existingEntry) == "table" and existingEntry.id == currentEntry.id) then
                    self.startupQueue[index] = currentEntry
                    break
                end
            end

            self.startupQueueInitialized = true
            self:DebugLog("Execution queue: replaced active current entry new=" .. self:FormatQueueEntry(currentEntry))
            self:DumpQueueState("after replace active current")
            return true, currentEntry
        end

        for index, existingEntry in ipairs(self.startupQueue) do
            if type(existingEntry) == "table" and existingEntry.queueKey == queueKey then
                self:DebugLog("Execution queue: replacing existing entry old=" .. self:FormatQueueEntry(existingEntry))

                local preservedId = existingEntry.id
                local preservedEnqueuedAt = existingEntry.enqueuedAt
                entry.id = preservedId or entry.id
                entry.enqueuedAt = preservedEnqueuedAt or entry.enqueuedAt
                self.startupQueue[index] = entry
                self.startupQueueInitialized = true

                self:DebugLog("Execution queue: replaced existing entry new=" .. self:FormatQueueEntry(entry))
                self:DumpQueueState("after replace")
                return true, entry
            end
        end
    end

    table.insert(self.startupQueue, entry)
    self.startupQueueInitialized = true

    self:DebugLog("Execution queue: enqueued new entry " .. self:FormatQueueEntry(entry))
    self:DumpQueueState("after enqueue")
    return true, entry
end

function SmartChatMsg:RemoveQueuedEntryById(entryId)
    if type(entryId) ~= "string" or entryId == "" then
        self:DebugLog("Execution queue: remove skipped because entryId was invalid")
        return false
    end

    for index, entry in ipairs(self.startupQueue or {}) do
        if type(entry) == "table" and entry.id == entryId then
            self:DebugLog(string.format(
                "Execution queue: removing entry index=%s %s",
                tostring(index),
                self:FormatQueueEntry(entry)
            ))
            table.remove(self.startupQueue, index)
            self:DumpQueueState("after remove")
            return true
        end
    end

    self:DebugLog("Execution queue: remove missed entryId=" .. tostring(entryId))
    return false
end

function SmartChatMsg:HandleRestoreWatcherChatMessage(eventCode, messageType, fromName, text, isCustomerService, fromDisplayName)
    local state = self.pendingRestoreState
    if not state then
        self:DebugLog("HandleRestoreWatcherChatMessage called without pending state")
        return
    end

    if isCustomerService or not self:IsOwnChatSender(fromName, fromDisplayName) then
        return
    end

    self:DebugLog(string.format(
        "Chat watcher eventCode=%s messageType=%s fromName=%s text=%s",
        tostring(eventCode),
        tostring(messageType),
        tostring(fromName or ""),
        tostring(text or "")
    ))

    if not self:IsOutgoingChatMessageType(messageType) then
        self:DebugLog(string.format("Chat watcher ignored non-outgoing event type=%s text=%s", tostring(messageType), tostring(text or "")))
        return
    end

    local details = self:GetFuzzyMessageMatchDetails(state.expectedText, text or "")
    self:DebugLog(string.format(
        "Watcher saw outgoing message type=%s method=%s matched=%s similarity=%.3f expected=%s actual=%s",
        tostring(messageType),
        tostring(details.method),
        tostring(details.matched),
        tonumber(details.similarity or 0),
        tostring(details.expected),
        tostring(details.actual)
    ))

    if not details.matched then
        return
    end

    local metadata = state.metadata
    if type(metadata) == "table" then
        if type(metadata.selectedEntryId) == "string" and metadata.selectedEntryId ~= "" then
            for _, entry in ipairs(self.savedVars.messages or {}) do
                if type(entry) == "table" and entry.id == metadata.selectedEntryId then
                    self:MarkMessageEntryUsed(entry)
                    break
                end
            end
        end

        if metadata.autoPopulate == true then
            self:DebugLog(string.format(
                "Auto populate debug: confirmed sent by watcher for commandId=%s guildName=%s zoneId=%s",
                tostring(metadata.commandId),
                tostring(metadata.guildName),
                tostring(metadata.zoneId)
            ))
            self:MarkCommandUsed(metadata.commandId, metadata.guildName, metadata.paramText, metadata.guildIndex)
            self:MarkAutoPopulateSent(metadata.commandId, metadata.guildName, metadata.zoneId)
        elseif metadata.reminderRepeat == true then
            self:HandleReminderPopulateSuccess(metadata)
        elseif metadata.commandId and metadata.guildName then
            self:MarkCommandUsed(metadata.commandId, metadata.guildName, metadata.paramText, metadata.guildIndex)
            if self:GetGuildReminderMinutes(metadata.commandId, metadata.guildName) then
                self:ScheduleCommandReminder(metadata.commandId, metadata.guildName)
            end
            if metadata.activateAutoPopulate == true and self:GetGuildAutoPopulateOnZone(metadata.commandId, metadata.guildName) then
                self:SetActiveAutoPopulate(metadata.commandId, metadata.guildName)
            end
        end

        self:HandleScheduledSendConfirmed(metadata)

        if metadata.startupQueue == true or (type(metadata.queueItemId) == "string" and metadata.queueItemId ~= "") then
            self:HandleStartupQueuePopulateSuccess(metadata)
        end
    end

    self:DebugLog("Watcher matched populated message; restoring previous channel")
    local restored = self:RestoreChatChannel(state.previousChannel)
    self:DebugLog("Restore attempt after watcher match restored=" .. tostring(restored))
    self:ClearPendingRestoreState("watcher matched outgoing message")
end

function SmartChatMsg:GetRestoreWatcherTimeoutSeconds(metadata)
    return self:GetRevertChatSeconds() or 60
end

function SmartChatMsg:ArmPendingRestoreState(previousChannelInfo, expectedText, metadata)
    self:ClearPendingRestoreState("arming new restore state")

    if not previousChannelInfo or not previousChannelInfo.id then
        self:DebugLog("ArmPendingRestoreState skipped: no previous channel info")
        return false
    end

    local normalizedExpected = self:NormalizeChatText(expectedText)
    if normalizedExpected == "" then
        self:DebugLog("ArmPendingRestoreState skipped: expected text normalized to empty")
        return false
    end

    local timeoutSeconds = self:GetRestoreWatcherTimeoutSeconds(metadata)

    self.pendingRestoreState = {
        previousChannel = previousChannelInfo,
        expectedText = normalizedExpected,
        rawExpectedText = expectedText,
        metadata = type(metadata) == "table" and metadata or nil,
        timeoutSeconds = timeoutSeconds,
        armedAt = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or nil,
    }

    self:DebugLog("Armed restore watcher with previous channel: " .. self:FormatChatChannelInfo(previousChannelInfo))
    self:DebugLog("Expected outgoing text: " .. tostring(normalizedExpected))
    self:DebugLog("Restore watcher timeout seconds: " .. tostring(timeoutSeconds))

    EVENT_MANAGER:RegisterForEvent(
        self.restoreWatcherEventName,
        EVENT_CHAT_MESSAGE_CHANNEL,
        function(...)
            SmartChatMsg:HandleRestoreWatcherChatMessage(...)
        end
    )

    local armedState=self.pendingRestoreState
    EVENT_MANAGER:RegisterForUpdate(self.restoreWatcherTimeoutName, timeoutSeconds * 1000, function()
        local pendingState = SmartChatMsg.pendingRestoreState
        if pendingState~=armedState then return end
        local pendingTimeoutSeconds = pendingState and pendingState.timeoutSeconds or timeoutSeconds
        SmartChatMsg:DebugLog("Restore watcher timed out after " .. tostring(pendingTimeoutSeconds) .. " seconds")
        local edit=self:GetChatEditControl()
        local untouched=edit and edit.GetText and edit:GetText()==pendingState.rawExpectedText
        if untouched and pendingState.previousChannel then
            SmartChatMsg:DebugLog("Timeout restore attempting previous channel: " .. SmartChatMsg:FormatChatChannelInfo(pendingState.previousChannel))
            local restored = SmartChatMsg:RestoreChatChannel(pendingState.previousChannel)
            SmartChatMsg:DebugLog("Timeout restore result=" .. tostring(restored))
        end

        local cleared = untouched and SmartChatMsg:ClearPendingChatBuffer()
        SmartChatMsg:DebugLog("Timeout clear pending chat result=" .. tostring(cleared))

        if pendingState and type(pendingState.metadata) == "table" and pendingState.metadata.reminderRepeat == true then
            SmartChatMsg:HandleReminderPopulateTimeout(pendingState.metadata)
        end
        if pendingState and type(pendingState.metadata) == "table" and pendingState.metadata.scheduledDelivery then
            SmartChatMsg:HandleScheduledPopulateTimeout(pendingState.metadata)
        end

        if pendingState and type(pendingState.metadata) == "table" and (pendingState.metadata.startupQueue == true or (type(pendingState.metadata.queueItemId) == "string" and pendingState.metadata.queueItemId ~= "")) then
            SmartChatMsg:HandleStartupQueuePopulateTimeout(pendingState.metadata)
        end

        SmartChatMsg:ClearPendingRestoreState("restore timeout")
    end)

    return true
end

function SmartChatMsg:SetActiveAutoPopulate(commandId, guildName)
    local command = self:GetCommandById(commandId)
    if not command then
        self:ClearActiveAutoPopulate()
        return
    end

    if not self:GetGuildAutoPopulateOnZone(commandId, guildName) then
        self:ClearActiveAutoPopulate()
        return
    end

    local normalizedGuildName = self:Trim(guildName or "")
    if normalizedGuildName == "" then
        self:ClearActiveAutoPopulate()
        return
    end

    self.savedVars.activeAutoPopulate = {
        commandId = commandId,
        guildName = normalizedGuildName,
    }
end

function SmartChatMsg:GetActiveAutoPopulate()
    local active = self.savedVars.activeAutoPopulate
    if type(active) ~= "table" then
        return nil
    end

    if type(active.commandId) ~= "string" or active.commandId == "" then
        return nil
    end

    if type(active.guildName) ~= "string" or active.guildName == "" then
        return nil
    end

    local command = self:GetCommandById(active.commandId)
    if not command or not self:GetGuildAutoPopulateOnZone(active.commandId, active.guildName) then
        return nil
    end

    return active
end


function SmartChatMsg:GetPlayerZoneId()
    local zoneIndex = GetUnitZoneIndex("player")
    if not zoneIndex then
        return nil
    end

    local zoneId = GetZoneId(zoneIndex)
    if type(zoneId) ~= "number" or zoneId == 0 then
        return nil
    end

    return zoneId
end

function SmartChatMsg:IsAutoPopulateTestHouseZone(zoneId)
    return type(zoneId) == "number" and zoneId == self.autoPopulateTestHouseZoneId
end

function SmartChatMsg:GetZoneCategory(zoneId)
    if type(zoneId) ~= "number" or zoneId == 0 then
        return "UNKNOWN"
    end

    if self:IsAutoPopulateTestHouseZone(zoneId) then
        return "OVERLAND_TEST_HOUSE"
    end

    if zoneId == self.infiniteArchiveZoneId then
        return "INFINITE_ARCHIVE"
    end

    if IsActiveWorldBattleground() then
        return "BATTLEGROUND"
    end

    if GetCurrentZoneHouseId() ~= 0 then
        return "HOUSE"
    end

    if IsPlayerInAvAWorld() then
        return "AVA_WORLD"
    end

    if IsUnitInDungeon("player") then
        return "INSTANCE"
    end

    return "OVERLAND"
end

function SmartChatMsg:IsAutoPopulateEligibleZone(zoneId)
    local category = self:GetZoneCategory(zoneId)
    return category == "OVERLAND" or category == "OVERLAND_TEST_HOUSE", category
end

function SmartChatMsg:GetAutoPopulateZoneRejectionReason(zoneId)
    local category = self:GetZoneCategory(zoneId)

    if category == "UNKNOWN" then
        return category, "zone id is missing or invalid"
    elseif category == "INFINITE_ARCHIVE" then
        return category, "Infinite Archive is excluded from auto populate"
    elseif category == "BATTLEGROUND" then
        return category, "Battlegrounds are excluded from auto populate"
    elseif category == "HOUSE" then
        return category, "housing is excluded except for the configured test house zone"
    elseif category == "AVA_WORLD" then
        return category, "AvA zones are excluded from auto populate"
    elseif category == "INSTANCE" then
        return category, "instanced PvE zones are excluded from auto populate"
    elseif category == "OVERLAND_TEST_HOUSE" then
        return category, "test house override is allowed"
    elseif category == "OVERLAND" then
        return category, "overland zone is allowed"
    end

    return tostring(category), "zone category is not eligible for auto populate"
end

function SmartChatMsg:GetEffectiveAutoPopulateZoneId(zoneId)
    if type(zoneId) ~= "number" or zoneId == 0 then
        return nil
    end

    local isEligible = self:IsAutoPopulateEligibleZone(zoneId)
    if isEligible then
        return zoneId
    end

    return nil
end

function SmartChatMsg:GetAutoPopulateZoneDisplayName(zoneId)
    if type(zoneId) ~= "number" or zoneId == 0 then
        return "unknown"
    end

    if GetZoneNameById then
        local zoneName = self:Trim(GetZoneNameById(zoneId) or "")
        if zoneName ~= "" then
            return zoneName
        end
    end

    return tostring(zoneId)
end

function SmartChatMsg:ShouldSkipAutoPopulateForZone(commandId, guildName, zoneId)
    local endsAt = self:GetAutoPopulateCooldownEndsAt(commandId, guildName, zoneId)
    if not endsAt then
        return false, nil, nil
    end

    local now = GetTimeStamp()
    local cooldownMinutes = self:GetGuildAutoPopulateCooldownMinutes(commandId, guildName)
    local cooldownSeconds = (cooldownMinutes or 60) * 60
    local elapsed = now - (endsAt - cooldownSeconds)
    return now < endsAt, elapsed, cooldownSeconds
end

function SmartChatMsg:GetAutoPopulateCooldownEndsAt(commandId, guildName, zoneId)
    local lastSentAt = self:GetGuildAutoPopulateLastSentAt(commandId, guildName, zoneId)
    local cooldownMinutes = self:GetGuildAutoPopulateCooldownMinutes(commandId, guildName)
    local cooldownSeconds = (cooldownMinutes or 60) * 60
    local ownEndsAt = lastSentAt and (lastSentAt + cooldownSeconds) or nil
    local observedEndsAt = self:GetObservedChatCooldownEndsAt(commandId, guildName, zoneId, cooldownSeconds)
    if ownEndsAt and observedEndsAt then
        return math.max(ownEndsAt, observedEndsAt)
    end
    return ownEndsAt or observedEndsAt
end

function SmartChatMsg:FormatUnixTimestampForDisplay(timestamp)
    if type(timestamp) ~= "number" or timestamp <= 0 then
        return "unknown"
    end

    return os.date("%m/%d/%Y %I:%M %p", timestamp)
end

function SmartChatMsg:ShowAutoPopulateCooldownAlert(commandId, guildName, zoneId)
    local command = self:GetCommandById(commandId)
    local commandDisplayName = self:BuildSlashCommandName(command and command.name or "") or "/command"
    local zoneName = self:GetAutoPopulateZoneDisplayName(zoneId)
    local cooldownEndsAt = self:GetAutoPopulateCooldownEndsAt(commandId, guildName, zoneId)
    local untilText = self:FormatUnixTimestampForDisplay(cooldownEndsAt)
    local message = string.format("%s Zone %s is in cooldown until %s.", commandDisplayName, zoneName, untilText)
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.NONE, message)
end

function SmartChatMsg:MarkAutoPopulateSent(commandId, guildName, zoneId)
    local timestamp = GetTimeStamp()
    self:SetGuildAutoPopulateLastSentAt(commandId, guildName, zoneId, timestamp)

    self:DebugLog(string.format(
        "Auto populate debug: marked sent commandId=%s guildName=%s zoneId=%s sentAt=%s",
        tostring(commandId),
        tostring(guildName),
        tostring(zoneId),
        tostring(timestamp)
    ))

    if self.statusPanelVisible then
        self:RefreshStatusPanel()
    end
end


function SmartChatMsg:HandleZoneAutoPopulate()
    local scheduledActive = self:GetActiveAutoPopulate()
    if scheduledActive and self:GetGuildRunAt(scheduledActive.commandId, scheduledActive.guildName) == "SCHEDULED" then
        self:TickSchedules()
        return
    end
    local currentZoneId = self:GetPlayerZoneId()
    local trackedZoneId = self:GetEffectiveAutoPopulateZoneId(currentZoneId)
    local previousZoneId = self.lastKnownZoneId
    local isInitialActivation = not self.hasSeenInitialPlayerActivated

    self.lastKnownZoneId = currentZoneId
    self.hasSeenInitialPlayerActivated = true

    if isInitialActivation then
        self:DebugLog(string.format(
            "Auto populate debug: initial player activation evaluating currentZoneId=%s trackedZoneId=%s",
            tostring(currentZoneId),
            tostring(trackedZoneId)
        ))
    end

    if not trackedZoneId then
        local category, reason = self:GetAutoPopulateZoneRejectionReason(currentZoneId)
        self:DebugLog(string.format(
            "Auto populate debug: skipped because currentZoneId=%s category=%s reason=%s",
            tostring(currentZoneId),
            tostring(category),
            tostring(reason)
        ))
        return
    end

    local active = self:GetActiveAutoPopulate()
    if not active then
        self:DebugLog("Auto populate debug: no active auto populate command")
        return
    end

    local shouldSkip, elapsed, cooldown = self:ShouldSkipAutoPopulateForZone(active.commandId, active.guildName, trackedZoneId)
    if shouldSkip then
        self:DebugLog(string.format(
            "Auto populate debug: skipped for commandId=%s guildName=%s zoneId=%s because elapsed=%s cooldown=%s",
            tostring(active.commandId),
            tostring(active.guildName),
            tostring(trackedZoneId),
            tostring(elapsed),
            tostring(cooldown)
        ))

        if isInitialActivation then
            self:ShowAutoPopulateCooldownAlert(active.commandId, active.guildName, trackedZoneId)
        end

        if self.statusPanelVisible then
            self:RefreshStatusPanel()
        end
        return
    end

    self:DebugLog(string.format(
        "Auto populate debug: firing for commandId=%s guildName=%s currentZoneId=%s trackedZoneId=%s previousZoneId=%s initialActivation=%s",
        tostring(active.commandId),
        tostring(active.guildName),
        tostring(currentZoneId),
        tostring(trackedZoneId),
        tostring(previousZoneId),
        tostring(isInitialActivation)
    ))

    local guildIndex = self:GetGuildSlotByName(active.guildName)
    local paramText = guildIndex and tostring(guildIndex) or nil

    local ok, err = self:PopulateChatBufferForCommand(
        active.commandId,
        active.guildName,
        nil,
        {
            autoPopulate = true,
            commandId = active.commandId,
            guildName = active.guildName,
            guildIndex = guildIndex,
            paramText = paramText,
            zoneId = trackedZoneId,
        }
    )

    if not ok then
        self:ClearActiveAutoPopulate()
        if self.statusPanelVisible then
            self:RefreshStatusPanel()
        end
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, err)
        return
    end

    if self.statusPanelVisible then
        self:RefreshStatusPanel()
    end

    local command = self:GetCommandById(active.commandId)
    if command then
        local commandName = self:BuildSlashCommandName(command.name or "") or "command"
        local zoneName = self:GetAutoPopulateZoneDisplayName(trackedZoneId)
        local message = string.format("Auto populated %s for %s. Run the command again to turn it off.", commandName, zoneName)
        self:ShowStatusMessage(message)
    end
end

function SmartChatMsg:PopulateChatBufferForCommand(commandId, guildName, channelOverride, restoreMetadata)
    local startup=self.processingStartupEntry
    if startup and startup.commandId==commandId and self:StringsEqualIgnoreCase(startup.guildName,guildName) then
        local metadata={}; for k,v in pairs(restoreMetadata or {}) do metadata[k]=v end
        metadata.startupQueue=true; restoreMetadata=metadata
    end
    local isScheduled = self:GetGuildRunAt(commandId, guildName) == "SCHEDULED"
    if isScheduled and self:GetGuildScheduleState(commandId, guildName) ~= "RUNNING" then
        return false, "Schedule is outside its active window or paused."
    end
    if isScheduled then
        local pacingEndsAt,pacingReason=self:GetSchedulePacingDelay(commandId,guildName)
        if pacingEndsAt then return false,pacingReason end
    end
    local outputChannel=channelOverride or self:GetSavedChatChannel(commandId,guildName)
    local observedDue=self:GetObservedCommandCooldownEndsAt(commandId,guildName,outputChannel)
    if observedDue and GetTimeStamp()<observedDue then
        self:NotifyCooldownDelay(commandId,guildName,observedDue)
        local metadata={}; for k,v in pairs(restoreMetadata or {}) do metadata[k]=v end
        metadata.observedDueAt=observedDue
        if self:GetGuildReminderMinutes(commandId,guildName) then
            self:SetReminderAutomationActive(commandId,guildName,true,observedDue)
        end
        return self:QueueChatPopulation(commandId,guildName,channelOverride,metadata,metadata.startupQueue and 2 or 1)
    end
    if not (restoreMetadata and restoreMetadata.queuedDelivery) and self:IsChatPopulationBusy() then
        return self:QueueChatPopulation(commandId, guildName, channelOverride, restoreMetadata,
            restoreMetadata and restoreMetadata.startupQueue and 2
                or restoreMetadata and (restoreMetadata.reminderRepeat or restoreMetadata.autoPopulate or restoreMetadata.scheduledDelivery) and 3 or 1)
    end
    self:DebugLog(string.format(
        "PopulateChatBufferForCommand start commandId=%s guildName=%s channelOverride=%s",
        tostring(commandId),
        tostring(guildName),
        tostring(channelOverride)
    ))

    local messages = isScheduled and self:GetScheduledMessageEntries(commandId, guildName)
        or self:GetMessageEntriesForCommandAndGuild(commandId, guildName)
    self:DebugLog("PopulateChatBufferForCommand message count=" .. tostring(#messages))
    if #messages == 0 then
        self:DebugLog("PopulateChatBufferForCommand aborted: no saved messages")
        return false, "No messages are saved for that command and guild."
    end

    local selectedEntry = self:SelectWeightedMessageEntry(messages)
    if not selectedEntry then
        self:DebugLog("PopulateChatBufferForCommand aborted: no selected entry")
        return false, "No messages are saved for that command and guild."
    end

    self:DebugLog("PopulateChatBufferForCommand selected entry id=" .. tostring(selectedEntry.id or "nil"))

    local messageText = self:Trim(selectedEntry.text or "")
    if messageText == "" then
        self:DebugLog("PopulateChatBufferForCommand aborted: selected message text was empty")
        return false, "The selected message is empty."
    end

    local resolvedMessageText = self:Trim(self:ApplyMessageSubstitutions(messageText, commandId, guildName) or "")
    self:DebugLog("PopulateChatBufferForCommand resolved text=" .. tostring(resolvedMessageText))
    if resolvedMessageText == "" then
        self:DebugLog("PopulateChatBufferForCommand aborted: resolved message text was empty")
        return false, "The selected message is empty after substitutions."
    end

    local channel = channelOverride or self:GetSavedChatChannel(commandId, guildName)
    self:DebugLog("PopulateChatBufferForCommand resolved channel=" .. tostring(channel))

    local previousChannelInfo = self:GetPreciseChatChannelInfo()
    self:DebugLog("PopulateChatBufferForCommand previous channel=" .. self:FormatChatChannelInfo(previousChannelInfo))

    local watcherMetadata = nil
    if type(restoreMetadata) == "table" then
        watcherMetadata = {}
        for key, value in pairs(restoreMetadata) do
            watcherMetadata[key] = value
        end
    else
        watcherMetadata = {}
    end
    watcherMetadata.commandId = watcherMetadata.commandId or commandId
    watcherMetadata.guildName = watcherMetadata.guildName or guildName
    watcherMetadata.selectedEntryId = selectedEntry.id
    if isScheduled then
        watcherMetadata.scheduledDelivery = true
        watcherMetadata.scheduledPhase = self:GetSchedulePhase(self:GetGuildSchedule(commandId, guildName), GetTimeStamp())
        local occurrence = self:GetScheduleOccurrence(self:GetGuildSchedule(commandId, guildName), GetTimeStamp())
        watcherMetadata.scheduledOccurrence = occurrence and occurrence.occurrenceKey
    end

    local currentQueueItem = self.startupQueueCurrent
    if type(currentQueueItem) == "table" and type(currentQueueItem.id) == "string" and currentQueueItem.id ~= ""
        and currentQueueItem.commandId==commandId and self:StringsEqualIgnoreCase(currentQueueItem.guildName or "",guildName) then
        watcherMetadata.queueItemId = currentQueueItem.id
    end

    local armedRestore = self:ArmPendingRestoreState(previousChannelInfo, resolvedMessageText, watcherMetadata)
    self:DebugLog("PopulateChatBufferForCommand armedRestore=" .. tostring(armedRestore))

    if armedRestore then
        self:SetGlobalExecutionStatus("busy", "chat populated into buffer")
    end

    if channel == "Zone" then
        self:DebugLog("PopulateChatBufferForCommand starting chat input for Zone")
        StartChatInput(resolvedMessageText, CHAT_CHANNEL_ZONE)
        if isScheduled then
            local runtime = self.scheduleRuntime[self:GetReminderStateKey(commandId, guildName)]
            if runtime then runtime.zonePending = false end
        end
        self:PlayPopulateSound(commandId, guildName)
        return true
    end

    if channel == "Group" then
        StartChatInput(resolvedMessageText,CHAT_CHANNEL_PARTY)
        self:PlayPopulateSound(commandId,guildName)
        return true
    end

    if channel == "Guild" or channel == "Officer" then
        local guildSlot = self:GetGuildSlotByName(guildName)
        self:DebugLog("PopulateChatBufferForCommand guildSlot=" .. tostring(guildSlot))
        if not guildSlot then
            self:ClearPendingRestoreState("guild slot unavailable before StartChatInput")
            return false, "That guild is not currently available."
        end

        if channel == "Guild" then
            local channelId = CHAT_CHANNEL_GUILD_1 + (guildSlot - 1)
            self:DebugLog("PopulateChatBufferForCommand starting chat input for Guild channelId=" .. tostring(channelId))
            StartChatInput(resolvedMessageText, channelId)
            self:PlayPopulateSound(commandId, guildName)
            return true
        end

        local channelId = CHAT_CHANNEL_OFFICER_1 + (guildSlot - 1)
        self:DebugLog("PopulateChatBufferForCommand starting chat input for Officer channelId=" .. tostring(channelId))
        StartChatInput(resolvedMessageText, channelId)
        self:PlayPopulateSound(commandId, guildName)
        return true
    end

    self:ClearPendingRestoreState("no saved chat channel resolved")
    return false, "No chat channel is saved for that command and guild."
end

function SmartChatMsg:ParseCommandParameter(rawParam)
    local trimmed = zo_strlower(self:Trim(rawParam or ""))
    if trimmed == "" then
        return nil
    end

    local result = {
        guildSlot = nil,
        channelOverride = nil,
        reminderParamText = nil,
        stopAutomation = false,
    }

    local tokenCount = 0
    for token in string.gmatch(trimmed, "%S+") do
        tokenCount = tokenCount + 1
        if tokenCount > 2 then
            return false
        end

        if token == "off" then
            if result.stopAutomation then
                return false
            end
            result.stopAutomation = true
        else
            local numericParam = tonumber(token)
            if numericParam and numericParam >= 1 and numericParam <= 5 and numericParam == math.floor(numericParam) then
                if result.guildSlot ~= nil then
                    return false
                end
                result.guildSlot = numericParam
                result.channelOverride = nil
                result.reminderParamText = tostring(numericParam)
            else
                local prefix, slotText = token:match("^([go])([1-5])$")
                if not prefix or not slotText or result.guildSlot ~= nil then
                    return false
                end

                local guildSlot = tonumber(slotText)
                result.guildSlot = guildSlot
                result.channelOverride = (prefix == "g") and "Guild" or "Officer"
                result.reminderParamText = token
            end
        end
    end

    if result.guildSlot == nil and result.stopAutomation == false then
        return false
    end

    return result
end


function SmartChatMsg:HandleDynamicSlashCommand(commandId, slashCommandName, rawParam)
    local trimmedParam = self:Trim(rawParam or "")
    local guildSlot = nil
    local channelOverride = nil
    local reminderParamText = nil
    local stopAutomation = false

    if trimmedParam ~= "" then
        local parsed = self:ParseCommandParameter(trimmedParam)

        if parsed == false then
            ZO_Alert(
                UI_ALERT_CATEGORY_ERROR,
                SOUNDS.NEGATIVE_CLICK,
                string.format("%s accepts off, 1-5, g1-g5, o1-o5, or a combination like '1 off'.", slashCommandName)
            )
            return
        end

        stopAutomation = parsed and parsed.stopAutomation == true
        guildSlot = parsed and parsed.guildSlot or nil
        channelOverride = parsed and parsed.channelOverride or nil
        reminderParamText = parsed and parsed.reminderParamText or nil
    end

    if guildSlot == nil then
        guildSlot = self:GetDefaultGuildIndex()

        if not guildSlot then
            ZO_Alert(
                UI_ALERT_CATEGORY_ERROR,
                SOUNDS.NEGATIVE_CLICK,
                string.format("%s requires 1-5, g1-g5, or o1-o5, or a Default Guild must be set.", slashCommandName)
            )
            return
        end

        reminderParamText = tostring(guildSlot)
    end

    local guildName = self:GetGuildNameByIndex(guildSlot)
    if not guildName then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, string.format("Guild slot %d is not available.", guildSlot))
        return
    end

    self:DebugLog(string.format(
        "HandleDynamicSlashCommand commandId=%s slashCommand=%s guildSlot=%s guildName=%s channelOverride=%s stopAutomation=%s rawParam=%s",
        tostring(commandId),
        tostring(slashCommandName),
        tostring(guildSlot),
        tostring(guildName),
        tostring(channelOverride),
        tostring(stopAutomation),
        tostring(trimmedParam)
    ))

    local commandDisplayName = self:GetSlashCommandDisplayName(commandId, slashCommandName)
    if self.repeatPanelPaused then self.repeatPanelPaused[self:GetReminderStateKey(commandId,guildName)]=nil end

    if self:GetGuildRunAt(commandId, guildName) == "SCHEDULED" then
        if stopAutomation then
            self:PauseGuildSchedule(commandId, guildName)
            self:ShowStatusMessage(commandDisplayName .. " schedule paused for " .. guildName .. ". Resume it in scheduling settings.")
        else
            local ok, reason = self:RequestScheduledDelivery(commandId, guildName, true)
            if ok then self:ProcessChatPopulationQueue() else self:ShowStatusMessage(reason) end
        end
        return
    end

    if stopAutomation then
        self:CancelQueuedChatPopulation(commandId, guildName)
        local stoppedParts = {}

        if self:ToggleOffActiveAutoPopulateIfMatching(commandId, guildName) then
            table.insert(stoppedParts, "auto populate")
        end

        if self:IsReminderAutomationActive(commandId, guildName) then
            self:DeactivateReminderAutomation(commandId, guildName, "explicit off parameter")
            table.insert(stoppedParts, "repeat")
        end

        local message
        if #stoppedParts > 0 then
            message = string.format("%s stopped %s for %s.", commandDisplayName, table.concat(stoppedParts, " and "), guildName)
            PlaySound(SOUNDS.DEFAULT_CLICK)
        else
            message = string.format("%s had nothing active to stop for %s.", commandDisplayName, guildName)
            PlaySound(SOUNDS.NEGATIVE_CLICK)
        end

        self:ShowStatusMessage(message)
        return
    end

    local autoPopulateEnabled = self:GetGuildAutoPopulateOnZone(commandId, guildName) == true

    self:OpenStatusPanelOnRunIfConfigured(commandId, guildName)

    local activeAutoPopulate = self:GetActiveAutoPopulate()
    if activeAutoPopulate and autoPopulateEnabled then
        local sameAutoPopulate = activeAutoPopulate.commandId == commandId and self:StringsEqualIgnoreCase(activeAutoPopulate.guildName or "", guildName or "")
        if not sameAutoPopulate then
            ZO_Alert(
                UI_ALERT_CATEGORY_ERROR,
                SOUNDS.NEGATIVE_CLICK,
                string.format("%s cannot start auto populate because %s is already running for %s.", commandDisplayName, self:BuildSlashCommandName(self:GetCommandNameById(activeAutoPopulate.commandId) or "command") or "another command", tostring(activeAutoPopulate.guildName))
            )
            return
        end
    end

    if autoPopulateEnabled then
        self:SetActiveAutoPopulate(commandId, guildName)
        if self.statusPanelVisible then
            self:RefreshStatusPanel()
        end

        self:DebugLog(string.format(
            "Auto populate debug: armed immediately from slash command commandId=%s guildName=%s",
            tostring(commandId),
            tostring(guildName)
        ))

        local currentZoneId = self:GetPlayerZoneId()
        local trackedZoneId = self:GetEffectiveAutoPopulateZoneId(currentZoneId)

        if not trackedZoneId then
            local category, reason = self:GetAutoPopulateZoneRejectionReason(currentZoneId)
            self:DebugLog(string.format(
                "Auto populate debug: manual start did not populate because currentZoneId=%s category=%s reason=%s",
                tostring(currentZoneId),
                tostring(category),
                tostring(reason)
            ))

            self:ShowStatusMessage(string.format("%s started auto populate for %s.", commandDisplayName, guildName))
            PlaySound(SOUNDS.DEFAULT_CLICK)
            return
        end

        local shouldSkip, elapsed, cooldown = self:ShouldSkipAutoPopulateForZone(commandId, guildName, trackedZoneId)
        if shouldSkip then
            self:DebugLog(string.format(
                "Auto populate debug: manual start skipped populate due to cooldown commandId=%s guildName=%s zoneId=%s elapsed=%s cooldown=%s",
                tostring(commandId),
                tostring(guildName),
                tostring(trackedZoneId),
                tostring(elapsed),
                tostring(cooldown)
            ))
            self:ShowAutoPopulateCooldownAlert(commandId, guildName, trackedZoneId)
            self:ShowStatusMessage(string.format("%s started auto populate for %s.", commandDisplayName, guildName))
            PlaySound(SOUNDS.DEFAULT_CLICK)
            return
        end

        self:ShowStatusMessage(string.format("%s started auto populate for %s.", commandDisplayName, guildName))
        PlaySound(SOUNDS.DEFAULT_CLICK)
        self:HandleZoneAutoPopulate()
        return
    end

    local ok, err = self:PopulateChatBufferForCommand(
        commandId,
        guildName,
        channelOverride,
        {
            commandId = commandId,
            guildName = guildName,
            guildIndex = guildSlot,
            paramText = reminderParamText,
            activateAutoPopulate = autoPopulateEnabled,
        }
    )
    if not ok then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, err)
        return
    end

    local startedParts = { "started" }
    if self:GetGuildReminderMinutes(commandId, guildName) then
        table.insert(startedParts, "repeat")
    end
    if self:GetGuildAutoPopulateOnZone(commandId, guildName) then
        table.insert(startedParts, "auto populate")
    end

    self:ShowStatusMessage(string.format("%s %s for %s.", commandDisplayName, table.concat(startedParts, " with "), guildName))
    PlaySound(SOUNDS.DEFAULT_CLICK)
end

function SmartChatMsg:UnregisterDynamicCommands()
    for slashCommandName, _ in pairs(self.dynamicCommands) do
        SLASH_COMMANDS[slashCommandName] = nil
    end

    self.dynamicCommands = {}
end

function SmartChatMsg:RegisterDynamicCommands()
    self:UnregisterDynamicCommands()

    local seenCommands = {}

    for _, command in ipairs(self:GetCommands()) do
        if type(command) == "table" and type(command.id) == "string" and type(command.name) == "string"
            and self:ShouldRegisterCommand(command.id) then
            local slashCommandName = self:BuildSlashCommandName(command.name)

            if slashCommandName and not seenCommands[slashCommandName] then
                seenCommands[slashCommandName] = true
                self.dynamicCommands[slashCommandName] = command.id

                SLASH_COMMANDS[slashCommandName] = function(paramText)
                    SmartChatMsg:HandleDynamicSlashCommand(command.id, slashCommandName, paramText)
                end
            end
        end
    end
end


function SmartChatMsg:BuildStartupQueueEntries()
    local entries = {}

    for _, command in ipairs(self:GetCommands()) do
        if type(command) == "table" and type(command.id) == "string" and command.id ~= "" then
            for guildIndex = 1, 5 do
                local guildId = GetGuildId(guildIndex)
                if guildId and guildId ~= 0 then
                    local guildName = self:GetGuildNameByIndex(guildIndex)
                    if guildName and self:GetGuildRunAt(command.id, guildName) == "STARTUP" then
                        local entry = {
                            id = self:GenerateUuid(),
                            commandId = command.id,
                            guildName = guildName,
                            guildIndex = guildIndex,
                            paramText = tostring(guildIndex),
                            rawParam = tostring(guildIndex),
                            slashCommandName = self:GetSlashCommandDisplayName(command.id),
                            source = "startup",
                            enqueuedAt = os.time(),
                            queueKey = self:BuildQueueIdentityKey(command.id, guildName, guildIndex),
                        }
                        table.insert(entries, entry)
                        self:DebugLog("Execution queue: startup candidate " .. self:FormatQueueEntry(entry))
                    end
                end
            end
        end
    end

    self:DebugLog("Execution queue: startup build complete count=" .. tostring(#entries))
    return entries
end

function SmartChatMsg:GetStartupQueueRetryDelayMilliseconds()
    return zo_random(0, 20000)
end

function SmartChatMsg:ScheduleStartupQueueNextStep(delayMs, reason)
    EVENT_MANAGER:UnregisterForUpdate(self.startupQueueDelayName)

    local queueCount = #(self.startupQueue or {})
    if queueCount <= 0 then
        self.queueProcessingScheduled = false
        self:DebugLog("Execution queue: nothing left to schedule reason=" .. tostring(reason or "unspecified"))
        return
    end

    local effectiveDelayMs = math.max(0, math.floor(tonumber(delayMs) or 0))
    self.queueProcessingScheduled = true
    self:DebugLog(string.format(
        "Execution queue: scheduling next step delayMs=%s remaining=%s reason=%s",
        tostring(effectiveDelayMs),
        tostring(queueCount),
        tostring(reason or "unspecified")
    ))

    EVENT_MANAGER:RegisterForUpdate(self.startupQueueDelayName, effectiveDelayMs, function()
        EVENT_MANAGER:UnregisterForUpdate(SmartChatMsg.startupQueueDelayName)
        SmartChatMsg.queueProcessingScheduled = false
        SmartChatMsg:ProcessStartupQueue()
    end)
end

function SmartChatMsg:FinalizeStartupQueueCurrent(success, reason)
    local current = self.startupQueueCurrent
    self.startupQueueCurrent = nil

    if not current then
        self:DebugLog("Execution queue: finalize called with no current item reason=" .. tostring(reason or "unspecified"))
        return
    end

    self:DebugLog(string.format(
        "Execution queue: finalizing success=%s reason=%s current=%s",
        tostring(success == true),
        tostring(reason or "unspecified"),
        self:FormatQueueEntry(current)
    ))

    if success == true then
        if current.id then
            self:RemoveQueuedEntryById(current.id)
        else
            for index, entry in ipairs(self.startupQueue or {}) do
                if entry == current then table.remove(self.startupQueue, index); break end
            end
        end
    end

    if #(self.startupQueue or {}) > 0 and not self:IsExecutionBusy() then
        self:ScheduleStartupQueueNextStep(0, reason or "queue continue")
    end
end

function SmartChatMsg:HandleStartupQueuePopulateSuccess(metadata)
    if type(metadata) ~= "table" then
        return
    end

    local current = self.startupQueueCurrent
    if not current or (metadata.queueItemId and current.id~=metadata.queueItemId)
        or (not metadata.queueItemId and (not metadata.startupQueue or current.commandId~=metadata.commandId
            or not self:StringsEqualIgnoreCase(current.guildName or "",metadata.guildName or ""))) then
        return
    end

    self:FinalizeStartupQueueCurrent(true, "queued message sent")
end

function SmartChatMsg:HandleStartupQueuePopulateTimeout(metadata)
    if type(metadata) ~= "table" then
        return
    end

    local current = self.startupQueueCurrent
    if not current or (metadata.queueItemId and current.id~=metadata.queueItemId)
        or (not metadata.queueItemId and (not metadata.startupQueue or current.commandId~=metadata.commandId
            or not self:StringsEqualIgnoreCase(current.guildName or "",metadata.guildName or ""))) then
        return
    end

    self:FinalizeStartupQueueCurrent(false, "queued message timed out")
end

function SmartChatMsg:ProcessStartupQueue()
    if not self.startupQueueInitialized then
        self:DebugLog("Execution queue: process skipped because queue has not been initialized")
        return
    end

    if self.startupQueueCurrent then
        self:DebugLog("Execution queue: process skipped because current item is still active")
        return
    end

    if self:IsExecutionBusy() then
        self:DebugLog("Execution queue: process skipped because execution is busy")
        return
    end

    local queue = self.startupQueue or {}
    if #queue <= 0 then
        self:DebugLog("Execution queue: complete")
        return
    end

    self:DumpQueueState("before process")

    local entry = queue[1]
    self.startupQueueCurrent = entry

    local slashCommandName = entry.slashCommandName or self:GetSlashCommandDisplayName(entry.commandId)
    local rawParam = entry.rawParam
    if self:Trim(rawParam or "") == "" then
        rawParam = entry.paramText or ""
    end

    self:DebugLog("Execution queue: processing current=" .. self:FormatQueueEntry(entry) .. " remaining=" .. tostring(#queue))

    self.processingStartupEntry=entry
    self:HandleDynamicSlashCommand(entry.commandId, slashCommandName, rawParam)
    self.processingStartupEntry=nil

    local currentStillQueued = self.startupQueueCurrent and self.startupQueueCurrent.id == entry.id
    if not currentStillQueued then
        self:DebugLog("Execution queue: current item cleared during processing id=" .. tostring(entry.id))
        return
    end

    local queued=self.chatPopulationQueue and self.chatPopulationQueue[self:GetReminderStateKey(entry.commandId,entry.guildName)]
    if queued and queued.metadata.startupQueue then return end
    if self:IsExecutionBusy() then
        self:DebugLog(string.format(
            "Execution queue: entry id=%s is now waiting for send or timeout",
            tostring(entry.id)
        ))
        return
    end

    self:FinalizeStartupQueueCurrent(true, "queue entry completed without pending chat")
end

function SmartChatMsg:InitializeStartupQueueOnce()
    if self.startupQueueInitialized then
        return
    end

    self.startupQueueInitialized = true
    self.startupQueue = self:BuildStartupQueueEntries()
    self.startupQueueCurrent = nil
    self.queueProcessingScheduled = false
    self:SetGlobalExecutionStatus("available", "startup initialize")

    self:DebugLog("Execution queue: initialized with " .. tostring(#(self.startupQueue or {})) .. " entries")

    if #(self.startupQueue or {}) > 0 then
        self:ScheduleStartupQueueNextStep(0, "queue initialize")
    end
end


function SmartChatMsg:GetAutoPopulateChannelStatusText(commandId, guildName)
    local channel = self:GetSavedChatChannel(commandId, guildName)
    local guildSlot = self:GetGuildSlotByName(guildName)

    if channel == "Guild" and guildSlot then
        return string.format("Guild (/g%d)", guildSlot)
    elseif channel == "Officer" and guildSlot then
        return string.format("Officer (/o%d)", guildSlot)
    elseif channel == "Zone" then
        return "Zone"
    elseif channel == "Group" then
        return "Group (/g)"
    end

    return channel or "Unknown"
end


local function OnAddonLoaded(event, addonName)
    if addonName ~= SmartChatMsg.name then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(SmartChatMsg.name, EVENT_ADD_ON_LOADED)

    SmartChatMsg:InitializeSavedVars()
    SmartChatMsg:ClearActiveAutoPopulate()
    SmartChatMsg.activeReminderStates = {}
    SmartChatMsg:ClearPendingRestoreState()
    SmartChatMsg:CreateSettingsPanel()
    SmartChatMsg:CreateStatusPanel()
    SmartChatMsg:RegisterDynamicCommands()
    SmartChatMsg:RegisterIncomingChatWatcher()
    SmartChatMsg:InitializeScheduler()

    if SmartChatMsg:GetStatusPanelVisiblePreference() then
        SmartChatMsg:SetStatusPanelVisible(true)
    end

    if LibDebugLogger and LibDebugLogger.Create then
        SmartChatMsg.logger = LibDebugLogger.Create("SmartChatMsg")
    else
        SmartChatMsg.logger = nil
    end

    SLASH_COMMANDS["/scm"] = function(paramText)
        local normalized = zo_strlower(SmartChatMsg:Trim(paramText or ""))
        if normalized == "status" then
            SmartChatMsg:ToggleStatusPanel()
            return
        elseif normalized == "schedule" then
            SmartChatMsg:OpenSettings()
            return
        elseif normalized == "resetcooldowns" then
            SmartChatMsg:ResetAllCooldowns()
            return
        elseif normalized ~= "" then
            SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Usage: /scm, /scm schedule, /scm status, or /scm resetcooldowns")
            return
        end

        SmartChatMsg:OpenSettings()
    end

    SLASH_COMMANDS["/scmdebug"] = function(paramText)
        SmartChatMsg:HandleScmDebugCommand(paramText)
    end

    EVENT_MANAGER:RegisterForEvent(SmartChatMsg.name .. "_PlayerActivated", EVENT_PLAYER_ACTIVATED, function()
        SmartChatMsg:HandleZoneAutoPopulate()
        SmartChatMsg:TickSchedules()
        SmartChatMsg:InitializeStartupQueueOnce()
    end)
end

EVENT_MANAGER:RegisterForEvent(SmartChatMsg.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)

-- JDoodle-style countdown analysis override
local SCM_DEFAULT_TIMEZONE = "LOCAL"

local SCM_SUPPORTED_TIMEZONES = {
    PST = true, PDT = true,
    MST = true, MDT = true,
    CST = true, CDT = true,
    EST = true, EDT = true,
    GMT = true, UTC = true,
    PT = true, MT = true, CT = true, ET = true,
}

local SCM_WEEKDAY_ALIASES = {
    { token = "sunday", abbr = "Sun", wday = 1 },
    { token = "sun", abbr = "Sun", wday = 1 },
    { token = "monday", abbr = "Mon", wday = 2 },
    { token = "mon", abbr = "Mon", wday = 2 },
    { token = "tuesday", abbr = "Tue", wday = 3 },
    { token = "tues", abbr = "Tue", wday = 3 },
    { token = "tue", abbr = "Tue", wday = 3 },
    { token = "wednesday", abbr = "Wed", wday = 4 },
    { token = "wed", abbr = "Wed", wday = 4 },
    { token = "thursday", abbr = "Thu", wday = 5 },
    { token = "thurs", abbr = "Thu", wday = 5 },
    { token = "thur", abbr = "Thu", wday = 5 },
    { token = "thu", abbr = "Thu", wday = 5 },
    { token = "friday", abbr = "Fri", wday = 6 },
    { token = "fri", abbr = "Fri", wday = 6 },
    { token = "saturday", abbr = "Sat", wday = 7 },
    { token = "sat", abbr = "Sat", wday = 7 },
}

local function scm_is_dst_active(nowTableOrEpoch)
    if type(nowTableOrEpoch) == "number" then
        local target = os.date("*t", nowTableOrEpoch)
        if target and target.isdst ~= nil then
            return target.isdst and true or false
        end
    elseif type(nowTableOrEpoch) == "table" and nowTableOrEpoch.isdst ~= nil then
        return nowTableOrEpoch.isdst and true or false
    end
    local current = os.date("*t")
    if current and current.isdst ~= nil then
        return current.isdst and true or false
    end
    return false
end

local function scm_get_timezone_family(tz)
    if not tz or tz == "" then
        return nil
    end

    local normalized = tostring(tz):upper():gsub("%.", ""):gsub("%s+TIME$", ""):gsub("%s+", "")
    if normalized == "ET" or normalized == "EST" or normalized == "EDT" or normalized == "EASTERN" then
        return "EASTERN"
    elseif normalized == "CT" or normalized == "CST" or normalized == "CDT" or normalized == "CENTRAL" then
        return "CENTRAL"
    elseif normalized == "MT" or normalized == "MST" or normalized == "MDT" or normalized == "MOUNTAIN" then
        return "MOUNTAIN"
    elseif normalized == "PT" or normalized == "PST" or normalized == "PDT" or normalized == "PACIFIC" then
        return "PACIFIC"
    end

    return nil
end

local function scm_get_family_timezone_for_dst(family, isDst)
    if family == "EASTERN" then
        return isDst and "EDT" or "EST"
    elseif family == "CENTRAL" then
        return isDst and "CDT" or "CST"
    elseif family == "MOUNTAIN" then
        return isDst and "MDT" or "MST"
    elseif family == "PACIFIC" then
        return isDst and "PDT" or "PST"
    end

    return nil
end

local function scm_is_dst_timezone_name(timezoneName)
    local normalized = tostring(timezoneName or ""):upper():gsub("%.", ""):gsub("%s+TIME$", ""):gsub("%s+", "")
    return normalized == "EDT" or normalized == "CDT" or normalized == "MDT" or normalized == "PDT"
end

local function scm_resolve_timezone_context(token, eventEpoch, defaultTimezone)
    local fixedOffsets = {
        UTC = 0,
        GMT = 0,
        EST = -5,
        EDT = -4,
        CST = -6,
        CDT = -5,
        MST = -7,
        MDT = -6,
        PST = -8,
        PDT = -7,
    }

    local function normalize_timezone_name(value)
        local normalized = tostring(value or ""):upper():gsub("%.", ""):gsub("%s+TIME$", ""):gsub("%s+", "")
        if normalized == "" then
            return nil
        end
        return normalized
    end

    local requested = normalize_timezone_name(token)
    local fallback = normalize_timezone_name(defaultTimezone) or SCM_DEFAULT_TIMEZONE
    local normalized = requested or fallback

    local family = scm_get_timezone_family(normalized)
    local resolvedName = normalized
    local targetIsDst = false

    if family then
        local isDst = false
        if type(eventEpoch) == "number" then
            local eventTable = os.date("*t", eventEpoch)
            if eventTable and eventTable.isdst ~= nil then
                isDst = eventTable.isdst == true
            end
        end

        resolvedName = scm_get_family_timezone_for_dst(family, isDst) or normalized
        targetIsDst = isDst
    else
        targetIsDst = scm_is_dst_timezone_name(normalized)
    end

    local offsetHours = fixedOffsets[resolvedName]
    local isSupported = offsetHours ~= nil

    if not requested and not isSupported then
        resolvedName = SCM_DEFAULT_TIMEZONE
        offsetHours = fixedOffsets[resolvedName]
        isSupported = offsetHours ~= nil
        targetIsDst = scm_is_dst_timezone_name(resolvedName)
    end

    return {
        requestedToken = requested,
        resolvedName = resolvedName,
        offsetHours = offsetHours,
        offsetSeconds = offsetHours and (offsetHours * 3600) or nil,
        isSupported = isSupported,
        targetIsDst = targetIsDst,
        usedDefault = requested == nil,
    }
end

local function scm_canonicalize_timezone_token(token, eventEpoch, defaultTimezone)
    local context = scm_resolve_timezone_context(token, eventEpoch, defaultTimezone)
    return context and context.resolvedName or nil
end

function SmartChatMsg:scm_canonicalize_timezone_token(token, eventEpoch)
    return scm_canonicalize_timezone_token(token, eventEpoch)
end

local function scm_normalize_timezone(tz, defaultTimezone, nowTable)
    if not tz or tz == "" then
        local fallback = scm_canonicalize_timezone_token(defaultTimezone or SCM_DEFAULT_TIMEZONE, nowTable)
        return fallback or SCM_DEFAULT_TIMEZONE, false
    end

    tz = scm_canonicalize_timezone_token(tz, nowTable)
    if SCM_SUPPORTED_TIMEZONES[tz] or tz == "UTC" or tz == "GMT" then
        return tz, true
    end

    local fallback = scm_canonicalize_timezone_token(defaultTimezone or SCM_DEFAULT_TIMEZONE, nowTable)
    return fallback or SCM_DEFAULT_TIMEZONE, false
end

local function scm_convert_12h_to_24h(hour, minute, ampm)
    if ampm == "AM" then
        if hour == 12 then
            return 0, minute
        end
        return hour, minute
    elseif ampm == "PM" then
        if hour < 12 then
            return hour + 12, minute
        end
        return hour, minute
    end
    return hour, minute
end

local function scm_format_time_string(hour24, minute, timezone)
    local ampm
    local displayHour

    if hour24 == 0 then
        displayHour = 12
        ampm = "AM"
    elseif hour24 < 12 then
        displayHour = hour24
        ampm = "AM"
    elseif hour24 == 12 then
        displayHour = 12
        ampm = "PM"
    else
        displayHour = hour24 - 12
        ampm = "PM"
    end

    return string.format("%02d:%02d %s %s", displayHour, minute, ampm, timezone)
end

local function scm_clock_minutes(hour24, minute)
    return (hour24 * 60) + minute
end

local function scm_round_minutes_for_display(totalMinutes)
    if totalMinutes == nil then
        return 0
    end
    if totalMinutes < 0 then
        totalMinutes = 0
    end
    if totalMinutes < 30 then
        return math.floor(totalMinutes + 0.5)
    end
    if totalMinutes < 60 then
        return math.floor((totalMinutes + 2.5) / 5) * 5
    end
    if totalMinutes < 120 then
        return math.floor((totalMinutes + 5) / 10) * 10
    end
    if totalMinutes < 720 then
        return math.floor((totalMinutes + 7.5) / 15) * 15
    end
    if totalMinutes < 1440 then
        return math.floor((totalMinutes + 15) / 30) * 30
    end
    if totalMinutes < 4320 then
        return math.floor((totalMinutes + 30) / 60) * 60
    end
    if totalMinutes < 10080 then
        return math.floor((totalMinutes + 90) / 180) * 180
    end
    return math.floor((totalMinutes + 180) / 360) * 360
end

local function scm_format_about_duration(totalMinutes)
    if totalMinutes == nil then
        totalMinutes = 0
    end
    if totalMinutes < 0 then
        totalMinutes = 0
    end
    if totalMinutes < 5 then
        return "soon"
    end

    local rounded = scm_round_minutes_for_display(totalMinutes)
    local isApproximate = rounded ~= totalMinutes

    if rounded <= 0 then
        return isApproximate and "~0m" or "0m"
    end

    local days = math.floor(rounded / 1440)
    local rem = rounded % 1440
    local hours = math.floor(rem / 60)
    local minutes = rem % 60
    local parts = {}

    if days > 0 then table.insert(parts, tostring(days) .. "d") end
    if hours > 0 then table.insert(parts, tostring(hours) .. "h") end
    if minutes > 0 then table.insert(parts, tostring(minutes) .. "m") end
    if #parts == 0 then
        return isApproximate and "~0m" or "0m"
    end

    local body
    if days >= 1 then
        body = parts[1]
        if #parts >= 2 then body = body .. " " .. parts[2] end
    else
        body = table.concat(parts, " ")
    end

    if isApproximate then
        return "~" .. body
    end
    return body
end

local function scm_has_digit_before(text, s)
    return s > 1 and text:sub(s - 1, s - 1):match("%d") ~= nil
end
local function scm_has_digit_after(text, e)
    return e < #text and text:sub(e + 1, e + 1):match("%d") ~= nil
end
local function scm_is_likely_date_fragment(text, s, e)
    local before = s > 1 and text:sub(s - 1, s - 1) or ""
    local after = e < #text and text:sub(e + 1, e + 1) or ""
    return before == "/" or after == "/" or before == "-" or after == "-" or (before == "." and text:sub(s - 2, s - 2):match("%d") ~= nil) or (after == "." and text:sub(e + 2, e + 2):match("%d") ~= nil)
end
local function scm_is_fuzzy_separator_char(ch)
    return ch and ch ~= "" and ch:match("[%s%p]") ~= nil
end
local function scm_advance_over_fuzzy_separators(text, pos, maxAdvance)
    local current = pos
    local advanced = 0
    while current <= #text and advanced < maxAdvance do
        local ch = text:sub(current, current)
        if scm_is_fuzzy_separator_char(ch) then
            current = current + 1
            advanced = advanced + 1
        else
            break
        end
    end
    return current
end
local function scm_is_valid_base_time(hour, minute, hasExplicitMeridiem)
    if hour == nil or minute == nil then return false end
    if minute < 0 or minute > 59 then return false end
    if hasExplicitMeridiem then
        return hour >= 1 and hour <= 12
    end
    return hour >= 0 and hour <= 23
end
local function scm_start_of_day_timestamp(year, month, day)
    return os.time({ year = year, month = month, day = day, hour = 0, min = 0, sec = 0 })
end
local function scm_days_between_dates(targetYear, targetMonth, targetDay, nowTable)
    local nowStart = scm_start_of_day_timestamp(nowTable.year, nowTable.month, nowTable.day)
    local targetStart = scm_start_of_day_timestamp(targetYear, targetMonth, targetDay)
    return math.floor((targetStart - nowStart) / 86400)
end
local function scm_compute_delta_to_specific_date_time(targetYear, targetMonth, targetDay, hour24, minute, nowTable)
    local targetTs = os.time({ year = targetYear, month = targetMonth, day = targetDay, hour = hour24, min = minute, sec = 0 })
    local nowTs = os.time({ year = nowTable.year, month = nowTable.month, day = nowTable.day, hour = nowTable.hour, min = nowTable.min, sec = nowTable.sec or 0, isdst = nowTable.isdst })
    return math.floor((targetTs - nowTs) / 60)
end
local function scm_compute_delta_to_weekday_time(targetWday, hour24, minute, nowTable)
    local dayOffset = (targetWday - nowTable.wday) % 7
    local nowTotal = scm_clock_minutes(nowTable.hour, nowTable.min)
    local targetTotal = scm_clock_minutes(hour24, minute)
    if dayOffset == 0 and targetTotal <= nowTotal then
        dayOffset = 7
    end
    return (dayOffset * 1440) + (targetTotal - nowTotal)
end
local function scm_compute_delta_same_day_cycle(hour24, minute, nowTable)
    local delta = scm_clock_minutes(hour24, minute) - scm_clock_minutes(nowTable.hour, nowTable.min)
    if delta < 0 then delta = delta + (24 * 60) end
    return delta
end

local function scm_detect_weekday(text)
    local lower = tostring(text or ""):lower()
    local best = nil
    local function is_alpha(ch) return ch and ch ~= "" and ch:match("%a") ~= nil end
    for _, entry in ipairs(SCM_WEEKDAY_ALIASES) do
        local startPos = 1
        while true do
            local s, e = lower:find(entry.token, startPos, true)
            if not s then break end
            local before = s > 1 and lower:sub(s - 1, s - 1) or ""
            local after = e < #lower and lower:sub(e + 1, e + 1) or ""
            if not is_alpha(before) and not is_alpha(after) then
                local candidate = { startPos = s, endPos = e, raw = text:sub(s, e), abbr = entry.abbr, wday = entry.wday, tokenLength = #entry.token }
                if not best or candidate.startPos < best.startPos or (candidate.startPos == best.startPos and candidate.tokenLength > best.tokenLength) then
                    best = candidate
                end
            end
            startPos = e + 1
        end
    end
    return best
end

local function scm_detect_tomorrow(text)
    local lower = tostring(text or ""):lower()
    local s, e = lower:find("tomorrow", 1, true)
    if not s then return nil end
    local before = s > 1 and lower:sub(s - 1, s - 1) or ""
    local after = e < #lower and lower:sub(e + 1, e + 1) or ""
    local function is_alpha(ch) return ch and ch ~= "" and ch:match("%a") ~= nil end
    if is_alpha(before) or is_alpha(after) then return nil end
    return { startPos = s, endPos = e, raw = text:sub(s, e), replacement = "tomorrow" }
end

local function scm_normalize_two_digit_year(yy)
    local n = tonumber(yy)
    if not n then return nil end
    if n <= 69 then return 2000 + n end
    return 1900 + n
end
local function scm_format_date_md(month, day) return tostring(month) .. "/" .. tostring(day) end
local function scm_format_date_mdy(month, day, year) return tostring(month) .. "/" .. tostring(day) .. "/" .. tostring(year) end

local function scm_get_weekday_info_for_date(year, month, day)
    local ts = os.time({ year = year, month = month, day = day, hour = 12, min = 0, sec = 0 })
    if not ts then return nil end
    local t = os.date("*t", ts)
    for _, entry in ipairs(SCM_WEEKDAY_ALIASES) do
        if entry.wday == t.wday then
            return { wday = t.wday, abbr = entry.abbr }
        end
    end
    return { wday = t.wday, abbr = tostring(t.wday) }
end

local function scm_detect_explicit_date(text, nowTable)
    local candidates = {}
    local function is_date_separator(ch) return ch == "/" or ch == "-" or ch == "." end
    local function add_candidate(s, e, month, day, year, hasExplicitYear, originalYearText)
        if not month or not day or not year then return end
        if month < 1 or month > 12 or day < 1 or day > 31 then return end
        local ts = os.time({ year = year, month = month, day = day, hour = 12, min = 0, sec = 0 })
        if not ts then return end
        local normalized = os.date("*t", ts)
        if normalized.year ~= year or normalized.month ~= month or normalized.day ~= day then return end
        local adjustedYear = year
        local assumedNextYear = false
        local initialDayDelta = scm_days_between_dates(adjustedYear, month, day, nowTable)
        local dayDelta = initialDayDelta
        if not hasExplicitYear and dayDelta < 0 then
            adjustedYear = nowTable.year + 1
            dayDelta = scm_days_between_dates(adjustedYear, month, day, nowTable)
            assumedNextYear = true
        end
        local explicitPast = hasExplicitYear and initialDayDelta < 0 or false
        local normalizedOutput
        if adjustedYear > nowTable.year or assumedNextYear or explicitPast then
            normalizedOutput = scm_format_date_mdy(month, day, adjustedYear)
        else
            normalizedOutput = scm_format_date_md(month, day)
        end
        local weekdayInfo = scm_get_weekday_info_for_date(adjustedYear, month, day)
        table.insert(candidates, {
            startPos = s, endPos = e, raw = text:sub(s, e), month = month, day = day, year = adjustedYear,
            originalParsedYear = year, hasExplicitYear = hasExplicitYear, originalYearText = originalYearText,
            assumedNextYear = assumedNextYear, dayDelta = dayDelta, normalizedOutput = normalizedOutput,
            normalizedWeekdayAbbr = weekdayInfo and weekdayInfo.abbr or nil,
            normalizedWeekdayWday = weekdayInfo and weekdayInfo.wday or nil,
            explicitPast = explicitPast,
        })
    end

    local i = 1
    while i <= #text do
        local ch = text:sub(i, i)
        if ch:match("%d") then
            local s = i
            local mEnd = i
            if i + 1 <= #text and text:sub(i + 1, i + 1):match("%d") then mEnd = i + 1 end
            local month = tonumber(text:sub(i, mEnd))
            local pos = mEnd + 1
            while pos <= #text and scm_is_fuzzy_separator_char(text:sub(pos, pos)) and not is_date_separator(text:sub(pos, pos)) do pos = pos + 1 end
            if pos <= #text and is_date_separator(text:sub(pos, pos)) then
                pos = pos + 1
                while pos <= #text and scm_is_fuzzy_separator_char(text:sub(pos, pos)) do pos = pos + 1 end
                local dStart = pos
                local dEnd = pos
                if pos <= #text and text:sub(pos, pos):match("%d") then
                    if pos + 1 <= #text and text:sub(pos + 1, pos + 1):match("%d") then dEnd = pos + 1 end
                    local day = tonumber(text:sub(dStart, dEnd))
                    local finalEnd = dEnd
                    local year = nowTable.year
                    local hasExplicitYear = false
                    local originalYearText = nil
                    local temp = dEnd + 1
                    while temp <= #text and scm_is_fuzzy_separator_char(text:sub(temp, temp)) and not is_date_separator(text:sub(temp, temp)) do temp = temp + 1 end
                    if temp <= #text and is_date_separator(text:sub(temp, temp)) then
                        temp = temp + 1
                        while temp <= #text and scm_is_fuzzy_separator_char(text:sub(temp, temp)) do temp = temp + 1 end
                        local yStart = temp
                        local yEnd = temp
                        local yDigits = 0
                        while yEnd <= #text and text:sub(yEnd, yEnd):match("%d") and yDigits < 4 do
                            yEnd = yEnd + 1
                            yDigits = yDigits + 1
                        end
                        yEnd = yEnd - 1
                        if yDigits == 2 or yDigits == 4 then
                            originalYearText = text:sub(yStart, yEnd)
                            year = yDigits == 2 and scm_normalize_two_digit_year(originalYearText) or tonumber(originalYearText)
                            hasExplicitYear = true
                            finalEnd = yEnd
                        end
                    end
                    add_candidate(s, finalEnd, month, day, year, hasExplicitYear, originalYearText)
                end
            end
        end
        i = i + 1
    end

    if #candidates == 0 then return nil end
    table.sort(candidates, function(a, b)
        if a.startPos ~= b.startPos then return a.startPos < b.startPos end
        return (a.endPos - a.startPos) > (b.endPos - b.startPos)
    end)
    return candidates[1]
end

local function scm_detect_fuzzy_colon_core(text)
    local candidates = {}
    local function add_candidate(s, e, hour, minute)
        if scm_has_digit_before(text, s) or scm_has_digit_after(text, e) then return end
        if scm_is_likely_date_fragment(text, s, e) then return end
        if minute < 0 or minute > 59 then return end
        table.insert(candidates, { startPos = s, endPos = e, hour = hour, minute = minute, sourceKind = "colon", explicit24Hour = hour > 12, rawCore = text:sub(s, e) })
    end
    local i = 1
    while i <= #text do
        local ch = text:sub(i, i)
        if ch:match("%d") then
            local hourStart = i
            local hourEnd = i
            if i + 1 <= #text and text:sub(i + 1, i + 1):match("%d") then hourEnd = i + 1 end
            local hourDigits = text:sub(hourStart, hourEnd)
            local pos = hourEnd + 1
            while pos <= #text and scm_is_fuzzy_separator_char(text:sub(pos, pos)) and text:sub(pos, pos) ~= ":" do pos = pos + 1 end
            if pos <= #text and text:sub(pos, pos) == ":" then
                pos = pos + 1
                while pos <= #text and scm_is_fuzzy_separator_char(text:sub(pos, pos)) do pos = pos + 1 end
                if pos + 1 <= #text then
                    local m1 = text:sub(pos, pos)
                    local m2 = text:sub(pos + 1, pos + 1)
                    if m1:match("%d") and m2:match("%d") then
                        add_candidate(hourStart, pos + 1, tonumber(hourDigits), tonumber(m1 .. m2))
                    end
                end
            end
        end
        i = i + 1
    end
    return candidates
end

local function scm_detect_time_core(text)
    local candidates = {}

    local function has_explicit_ampm_or_timezone_after(endPos)
        local pos = scm_advance_over_fuzzy_separators(text, endPos + 1, 12)

        local token2 = text:sub(pos, math.min(pos + 1, #text)):upper()
        if token2 == "AM" or token2 == "PM" then
            return true
        end

        local token4 = text:sub(pos, math.min(pos + 3, #text)):upper()
        if token4 == "A.M." or token4 == "P.M." then
            return true
        end

        local s, _, token = text:find("([A-Za-z][A-Za-z]?[A-Za-z]?[A-Za-z]?)", pos)
        if s == pos then
            local upperToken = token:upper():gsub("%.", ""):gsub("%s+TIME$", ""):gsub("%s+", "")
            local explicitTimezones = {
                UTC = true, GMT = true,
                EST = true, EDT = true,
                CST = true, CDT = true,
                MST = true, MDT = true,
                PST = true, PDT = true,
                ET = true, CT = true, MT = true, PT = true,
            }

            if explicitTimezones[upperToken] then
                return true
            end
        end

        return false
    end

    local function add_candidate(s, e, hour, minute, sourceKind, explicit24Hour)
        if scm_has_digit_before(text, s) or scm_has_digit_after(text, e) then return end
        if scm_is_likely_date_fragment(text, s, e) then return end
        if minute < 0 or minute > 59 then return end
        if (sourceKind == "hour_only" or sourceKind == "compact_3" or sourceKind == "compact_24h") and not has_explicit_ampm_or_timezone_after(e) then return end
        table.insert(candidates, { startPos = s, endPos = e, hour = hour, minute = minute, sourceKind = sourceKind, explicit24Hour = explicit24Hour or false, rawCore = text:sub(s, e) })
    end
    for _, c in ipairs(scm_detect_fuzzy_colon_core(text)) do table.insert(candidates, c) end
    do
        local searchPos = 1
        while true do
            local s, e, h, m = text:find("(%d):(%d%d)", searchPos)
            if not s then break end
            add_candidate(s, e, tonumber(h), tonumber(m), "colon", false)
            searchPos = e + 1
        end
    end
    do
        local searchPos = 1
        while true do
            local s, e, h, m = text:find("(%d%d):(%d%d)", searchPos)
            if not s then break end
            add_candidate(s, e, tonumber(h), tonumber(m), "colon", tonumber(h) > 12)
            searchPos = e + 1
        end
    end
    do
        local searchPos = 1
        while true do
            local s, e, digits = text:find("(%d%d%d%d)", searchPos)
            if not s then break end
            add_candidate(s, e, tonumber(digits:sub(1, 2)), tonumber(digits:sub(3, 4)), "compact_24h", tonumber(digits:sub(1, 2)) > 12)
            searchPos = e + 1
        end
    end
    do
        local searchPos = 1
        while true do
            local s, e, digits = text:find("(%d%d%d)", searchPos)
            if not s then break end
            add_candidate(s, e, tonumber(digits:sub(1, 1)), tonumber(digits:sub(2, 3)), "compact_3", false)
            searchPos = e + 1
        end
    end
    do
        local searchPos = 1
        while true do
            local s, e, digits = text:find("(%d%d?)", searchPos)
            if not s then break end
            add_candidate(s, e, tonumber(digits), 0, "hour_only", false)
            searchPos = e + 1
        end
    end
    if #candidates == 0 then return nil, candidates end
    table.sort(candidates, function(a, b)
        local function score(c)
            local v = 0
            if c.sourceKind == "colon" then v = v + 100 end
            if c.sourceKind == "compact_24h" then v = v + 60 end
            if c.sourceKind == "compact_3" then v = v + 40 end
            if c.sourceKind == "hour_only" then v = v + 10 end
            return v
        end
        local as, bs = score(a), score(b)
        if as ~= bs then return as > bs end
        local alen = a.endPos - a.startPos
        local blen = b.endPos - b.startPos
        if alen ~= blen then return alen > blen end
        return a.startPos < b.startPos
    end)
    return candidates[1], candidates
end

local function scm_detect_ampm_after_fuzzy(text, startPos)
    local pos = scm_advance_over_fuzzy_separators(text, startPos, 8)
    local token2 = text:sub(pos, pos + 1):upper()
    if token2 == "AM" or token2 == "PM" then
        return token2, pos, pos + 1, pos + 2
    end
    local token4 = text:sub(pos, math.min(pos + 3, #text)):upper()
    if token4 == "A.M." then return "AM", pos, pos + 3, pos + 4 end
    if token4 == "P.M." then return "PM", pos, pos + 3, pos + 4 end
    return nil, nil, nil, startPos
end

local function scm_detect_timezone_after_fuzzy(text, startPos, defaultTimezone, nowTable)
    local pos = scm_advance_over_fuzzy_separators(text, startPos, 12)
    local s, e, token = text:find("([A-Za-z][A-Za-z]?[A-Za-z]?[A-Za-z]?)", pos)
    if s == pos then
        local normalizedToken = tostring(token or ""):upper():gsub("%.", ""):gsub("%s+TIME$", ""):gsub("%s+", "")
        if normalizedToken ~= "" then
            return normalizedToken, true, s, e, e + 1
        end
    end
    return nil, false, nil, nil, startPos
end

local function scm_get_timezone_offset_hours(timezoneName, eventEpoch, defaultTimezone)
    local context = scm_resolve_timezone_context(timezoneName, eventEpoch, defaultTimezone)
    return context and context.offsetHours or nil
end

local function scm_resolve_time(hour, minute, detectedAmpm, explicit24Hour, usableDateInfo, tomorrowInfo, weekdayInfo, nowTable, sourceTimezone)
    local nowEpoch = scm_build_utc_timestamp(
        nowTable.year,
        nowTable.month,
        nowTable.day,
        nowTable.hour,
        nowTable.min,
        nowTable.sec or 0
    )

    local function refresh_timing_for_event_timestamp(timing)
        if not timing or type(timing.eventTimestamp) ~= "number" then
            return timing
        end

        local timezoneContext = scm_resolve_timezone_context(sourceTimezone, timing.eventTimestamp)
        timing.timezoneContext = timezoneContext
        timing.sourceTimezoneDisplay = timezoneContext and timezoneContext.resolvedName or nil
        timing.sourceUtcOffsetHours = timezoneContext and timezoneContext.offsetHours or nil
        timing.sourceUtcOffsetSeconds = timezoneContext and timezoneContext.offsetSeconds or nil
        timing.sourceTimezoneSupported = timezoneContext and timezoneContext.isSupported or false
        timing.targetIsDst = timezoneContext and timezoneContext.targetIsDst or false

        timing.diffSeconds = timing.eventTimestamp - nowEpoch

        return timing
    end

    local function build_event_timing(year, month, day, hour24, min24)
        local provisionalUtcTimestamp = scm_build_utc_timestamp(year, month, day, hour24, min24, 0)
        local timezoneContext = scm_resolve_timezone_context(sourceTimezone, provisionalUtcTimestamp)
        local offsetSeconds = timezoneContext and timezoneContext.offsetSeconds or 0
        local eventTimestamp = provisionalUtcTimestamp - offsetSeconds

        local timing = {
            eventTimestamp = eventTimestamp,
            timezoneContext = timezoneContext,
            sourceTimezoneDisplay = timezoneContext and timezoneContext.resolvedName or nil,
            sourceUtcOffsetHours = timezoneContext and timezoneContext.offsetHours or nil,
            sourceUtcOffsetSeconds = offsetSeconds,
            sourceTimezoneSupported = timezoneContext and timezoneContext.isSupported or false,
            targetIsDst = timezoneContext and timezoneContext.targetIsDst or false,
        }

        return refresh_timing_for_event_timestamp(timing)
    end

    local function delta_for(hour24, min24)
        if usableDateInfo then
            local timing = build_event_timing(usableDateInfo.year, usableDateInfo.month, usableDateInfo.day, hour24, min24)
            return math.floor(timing.diffSeconds / 60), timing
        end

        if tomorrowInfo then
            local timing = build_event_timing(nowTable.year, nowTable.month, nowTable.day + 1, hour24, min24)
            return math.floor(timing.diffSeconds / 60), timing
        end

        if weekdayInfo then
            local currentWday = (nowTable and nowTable.wday) or os.date("*t").wday
            local dayOffset = (weekdayInfo.wday - currentWday) % 7
            local timing = build_event_timing(nowTable.year, nowTable.month, nowTable.day + dayOffset, hour24, min24)
            if dayOffset == 0 and timing.eventTimestamp <= nowEpoch then
                timing.eventTimestamp = timing.eventTimestamp + (7 * 24 * 60 * 60)
                timing = refresh_timing_for_event_timestamp(timing)
            end
            return math.floor(timing.diffSeconds / 60), timing
        end

        local timing = build_event_timing(nowTable.year, nowTable.month, nowTable.day, hour24, min24)
        if timing.eventTimestamp < nowEpoch then
            timing.eventTimestamp = timing.eventTimestamp + (24 * 60 * 60)
            timing = refresh_timing_for_event_timestamp(timing)
        end
        return math.floor(timing.diffSeconds / 60), timing
    end

    local function build_result(resolvedAmpm, hour24, minute24, explicitMeridiemValue, inferredMeridiemValue, ambiguousValue, explicit24HourValue)
        local minutesUntil, timing = delta_for(hour24, minute24)
        return {
            resolvedAmpm = resolvedAmpm,
            resolvedHour24 = hour24,
            resolvedMinute24 = minute24,
            explicitMeridiem = explicitMeridiemValue,
            inferredMeridiem = inferredMeridiemValue,
            ambiguous = ambiguousValue,
            explicit24Hour = explicit24HourValue,
            minutesUntil = minutesUntil,
            nowTimestamp = nowEpoch,
            eventTimestamp = timing and timing.eventTimestamp or nil,
            diffSeconds = timing and timing.diffSeconds or nil,
            sourceUtcOffsetHours = timing and timing.sourceUtcOffsetHours or nil,
            sourceUtcOffsetSeconds = timing and timing.sourceUtcOffsetSeconds or nil,
            sourceTimezoneDisplay = timing and timing.sourceTimezoneDisplay or nil,
            sourceTimezoneSupported = timing and timing.sourceTimezoneSupported or false,
            targetIsDst = timing and timing.targetIsDst or false,
        }
    end

    if detectedAmpm then
        local hour24, minute24 = scm_convert_12h_to_24h(hour, minute, detectedAmpm)
        return build_result(detectedAmpm, hour24, minute24, true, false, false, false)
    end
    if explicit24Hour or hour > 12 then
        return build_result(nil, hour, minute, false, false, false, true)
    end
    local amHour24, amMinute24 = scm_convert_12h_to_24h(hour, minute, "AM")
    local pmHour24, pmMinute24 = scm_convert_12h_to_24h(hour, minute, "PM")
    local amResult = build_result("AM", amHour24, amMinute24, false, true, true, false)
    local pmResult = build_result("PM", pmHour24, pmMinute24, false, true, true, false)
    if amResult.minutesUntil <= pmResult.minutesUntil then
        return amResult
    end
    return pmResult
end

local function scm_replace_range(text, startPos, endPos, replacement)
    if not startPos or not endPos or startPos < 1 or endPos < startPos then return text end
    local before = startPos > 1 and text:sub(1, startPos - 1) or ""
    local after = endPos < #text and text:sub(endPos + 1) or ""
    return before .. replacement .. after
end

local function scm_apply_replacements(text, replacements)
    table.sort(replacements, function(a, b) return a.startPos > b.startPos end)
    local out = text
    for _, rep in ipairs(replacements) do out = scm_replace_range(out, rep.startPos, rep.endPos, rep.replacement) end
    return out
end


local SCM_ESO_LINK_PLACEHOLDER_PREFIX = "__SCMESOLINK"
local SCM_ESO_LINK_PLACEHOLDER_SUFFIX = "__"

local function scm_index_to_alpha(index)
    local n = tonumber(index) or 1
    if n < 1 then n = 1 end
    local chars = {}
    while n > 0 do
        local rem = (n - 1) % 26
        table.insert(chars, 1, string.char(string.byte("A") + rem))
        n = math.floor((n - 1) / 26)
    end
    return table.concat(chars)
end

local function scm_map_protected_pos_to_original(pos, protectedSegments)
    if type(pos) ~= "number" then return pos end
    local mappedPos = pos
    for _, segment in ipairs(protectedSegments or {}) do
        if pos > segment.placeholderEnd then
            mappedPos = mappedPos + (segment.originalLength - segment.placeholderLength)
        end
    end
    return mappedPos
end

function SmartChatMsg:ProtectEsoLinksInText(text)
    local source = tostring(text or "")
    local protectedSegments = {}
    local replacements = {}
    local index = 1
    local searchPos = 1

    while searchPos <= #source do
        local startPos = source:find("|H", searchPos, true)
        if not startPos then break end

        local endPos = nil
        local labelStart = source:find("|h", startPos + 2, true)
        if labelStart then
            local labelEnd = source:find("|h", labelStart + 2, true)
            if labelEnd then
                endPos = labelEnd + 1
            end
        end

        if not endPos then
            local nextPipe = source:find("|", startPos + 2, true)
            if nextPipe then
                endPos = nextPipe
            end
        end

        if endPos and endPos >= startPos then
            local placeholder = SCM_ESO_LINK_PLACEHOLDER_PREFIX .. scm_index_to_alpha(index) .. SCM_ESO_LINK_PLACEHOLDER_SUFFIX
            table.insert(replacements, {
                startPos = startPos,
                endPos = endPos,
                placeholder = placeholder,
                original = source:sub(startPos, endPos),
            })
            index = index + 1
            searchPos = endPos + 1
        else
            searchPos = startPos + 2
        end
    end

    if #replacements == 0 then
        return source, {}, {}
    end

    table.sort(replacements, function(a, b) return a.startPos > b.startPos end)
    local protectedText = source
    for _, item in ipairs(replacements) do
        protectedText = scm_replace_range(protectedText, item.startPos, item.endPos, item.placeholder)
    end

    local runningPos = 1
    for _, item in ipairs(replacements) do
        local placeholderStart = protectedText:find(item.placeholder, runningPos, true)
        if placeholderStart then
            local placeholderEnd = placeholderStart + #item.placeholder - 1
            table.insert(protectedSegments, {
                originalStart = item.startPos,
                originalEnd = item.endPos,
                originalLength = #item.original,
                placeholder = item.placeholder,
                placeholderStart = placeholderStart,
                placeholderEnd = placeholderEnd,
                placeholderLength = #item.placeholder,
                original = item.original,
            })
            runningPos = placeholderEnd + 1
        end
    end

    return protectedText, protectedSegments, replacements
end

function SmartChatMsg:RestoreProtectedEsoLinks(text, protectedSegments)
    local restored = tostring(text or "")
    for _, segment in ipairs(protectedSegments or {}) do
        restored = restored:gsub(segment.placeholder, function() return segment.original end, 1)
    end
    return restored
end

function SmartChatMsg:AnalyzeEmbeddedTime(text, defaultTimezone, nowTable)
    local originalText = tostring(text or "")
    defaultTimezone = defaultTimezone or SCM_DEFAULT_TIMEZONE
    nowTable = nowTable or os.date("!*t")

    local protectedText, protectedSegments = self:ProtectEsoLinksInText(originalText)
    local core, allCores = scm_detect_time_core(protectedText)
    if not core then return nil, allCores or {} end

    local ampm, ampmStart, ampmEnd, afterAmpmPos = scm_detect_ampm_after_fuzzy(protectedText, core.endPos + 1)
    if not scm_is_valid_base_time(core.hour, core.minute, ampm ~= nil) then
        return nil, allCores or {}
    end

    local detectedDateInfo = scm_detect_explicit_date(protectedText, nowTable)
    local usableDateInfo = nil
    if detectedDateInfo and detectedDateInfo.dayDelta >= 0 then usableDateInfo = detectedDateInfo end
    local tomorrowInfo = nil
    local weekdayInfo = scm_detect_weekday(protectedText)
    if not usableDateInfo then tomorrowInfo = scm_detect_tomorrow(protectedText) end
    local countdownWeekdayInfo = nil
    if not usableDateInfo and not tomorrowInfo then countdownWeekdayInfo = weekdayInfo end

    local timezone, explicitTimezone, tzStart, tzEnd, afterTzPos = scm_detect_timezone_after_fuzzy(protectedText, afterAmpmPos, defaultTimezone, nowTable)
    local resolved = scm_resolve_time(core.hour, core.minute, ampm, core.explicit24Hour, usableDateInfo, tomorrowInfo, countdownWeekdayInfo, nowTable, explicitTimezone and timezone or nil)

    if detectedDateInfo and not detectedDateInfo.hasExplicitYear and usableDateInfo and usableDateInfo.dayDelta == 0 and resolved.minutesUntil < 0 then
        local rolledYear = usableDateInfo.year + 1
        local rolledWeekdayInfo = scm_get_weekday_info_for_date(rolledYear, usableDateInfo.month, usableDateInfo.day)
        usableDateInfo = {
            startPos = usableDateInfo.startPos,
            endPos = usableDateInfo.endPos,
            raw = usableDateInfo.raw,
            month = usableDateInfo.month,
            day = usableDateInfo.day,
            year = rolledYear,
            originalParsedYear = usableDateInfo.originalParsedYear,
            hasExplicitYear = false,
            originalYearText = usableDateInfo.originalYearText,
            assumedNextYear = true,
            dayDelta = scm_days_between_dates(rolledYear, usableDateInfo.month, usableDateInfo.day, nowTable),
            normalizedOutput = scm_format_date_mdy(usableDateInfo.month, usableDateInfo.day, rolledYear),
            normalizedWeekdayAbbr = rolledWeekdayInfo and rolledWeekdayInfo.abbr or usableDateInfo.normalizedWeekdayAbbr,
            normalizedWeekdayWday = rolledWeekdayInfo and rolledWeekdayInfo.wday or usableDateInfo.normalizedWeekdayWday,
            explicitPast = false,
        }
        detectedDateInfo = usableDateInfo
        tomorrowInfo = nil
        countdownWeekdayInfo = nil
        resolved = scm_resolve_time(core.hour, core.minute, ampm, core.explicit24Hour, usableDateInfo, tomorrowInfo, countdownWeekdayInfo, nowTable, explicitTimezone and timezone or nil)
    end

    if detectedDateInfo and detectedDateInfo.hasExplicitYear and resolved.minutesUntil < 0 then
        detectedDateInfo.explicitPast = true
        detectedDateInfo.normalizedOutput = scm_format_date_mdy(detectedDateInfo.month, detectedDateInfo.day, detectedDateInfo.year)
    end

    self:DebugCountdownState("dst_resolution", {
        inputTimezone = explicitTimezone and (timezone or "nil") or "local",
        normalizedTimezone = resolved and resolved.sourceTimezoneDisplay or "nil",
        eventEpoch = resolved and resolved.eventTimestamp or "nil",
        eventIsDst = resolved and tostring(resolved.targetIsDst) or "nil",
        sourceOffset = resolved and resolved.sourceUtcOffsetHours or "nil",
    })

    self:DebugCountdownState("epoch_compare", {
        now = resolved and resolved.nowTimestamp or scm_get_utc_now(),
        event = resolved and resolved.eventTimestamp or "nil",
        diffSeconds = resolved and resolved.diffSeconds or "nil",
    })

    local displayTimezone = (explicitTimezone and (resolved.sourceTimezoneDisplay or timezone)) or "TZ?"
    local skipCountdownForMissingTimezone = not explicitTimezone
    local skipCountdownForUnsupportedTimezone = explicitTimezone and not resolved.sourceTimezoneSupported
    local timeString = scm_format_time_string(resolved.resolvedHour24, resolved.resolvedMinute24, displayTimezone)
    local suppressCountdown = (detectedDateInfo and detectedDateInfo.explicitPast) or ((detectedDateInfo and detectedDateInfo.hasExplicitYear) and resolved.minutesUntil < 0) or skipCountdownForMissingTimezone or skipCountdownForUnsupportedTimezone
    local aboutString = nil
    local replacementString = timeString
    if not suppressCountdown then
        aboutString = "(" .. scm_format_about_duration(resolved.minutesUntil) .. ")"
        replacementString = timeString .. " " .. aboutString
    end

    local finalEndPos = core.endPos
    if ampmEnd then finalEndPos = ampmEnd end
    if tzEnd then finalEndPos = tzEnd end
    local replacements = { { startPos = core.startPos, endPos = finalEndPos, replacement = replacementString } }
    if detectedDateInfo then
        table.insert(replacements, { startPos = detectedDateInfo.startPos, endPos = detectedDateInfo.endPos, replacement = detectedDateInfo.normalizedOutput })
        if weekdayInfo then
            table.insert(replacements, { startPos = weekdayInfo.startPos, endPos = weekdayInfo.endPos, replacement = detectedDateInfo.normalizedWeekdayAbbr or weekdayInfo.abbr })
        end
    elseif tomorrowInfo then
        table.insert(replacements, { startPos = tomorrowInfo.startPos, endPos = tomorrowInfo.endPos, replacement = "tomorrow" })
    elseif weekdayInfo then
        table.insert(replacements, { startPos = weekdayInfo.startPos, endPos = weekdayInfo.endPos, replacement = weekdayInfo.abbr })
    end

    local outputTextProtected = scm_apply_replacements(protectedText, replacements)
    local outputText = self:RestoreProtectedEsoLinks(outputTextProtected, protectedSegments)

    local originalStartPos = scm_map_protected_pos_to_original(core.startPos, protectedSegments)
    local originalEndPos = scm_map_protected_pos_to_original(finalEndPos, protectedSegments)

    return {
        detectedDateRaw = detectedDateInfo and detectedDateInfo.raw or nil,
        detectedDateValue = detectedDateInfo and string.format("%04d-%02d-%02d", detectedDateInfo.year, detectedDateInfo.month, detectedDateInfo.day) or nil,
        detectedDateNormalized = detectedDateInfo and detectedDateInfo.normalizedOutput or nil,
        detectedDateDayDelta = detectedDateInfo and detectedDateInfo.dayDelta or nil,
        detectedDateAssumedNextYear = detectedDateInfo and detectedDateInfo.assumedNextYear or false,
        detectedDateExplicitPast = detectedDateInfo and detectedDateInfo.explicitPast or false,
        detectedDateWeekdayAbbr = detectedDateInfo and detectedDateInfo.normalizedWeekdayAbbr or nil,
        detectedDateWeekdayWday = detectedDateInfo and detectedDateInfo.normalizedWeekdayWday or nil,
        dateUsedForCountdown = usableDateInfo and true or false,
        tomorrowRaw = tomorrowInfo and tomorrowInfo.raw or nil,
        weekdayAbbr = detectedDateInfo and detectedDateInfo.normalizedWeekdayAbbr or (weekdayInfo and weekdayInfo.abbr or nil),
        weekdayRaw = weekdayInfo and weekdayInfo.raw or nil,
        weekdayWday = detectedDateInfo and detectedDateInfo.normalizedWeekdayWday or (weekdayInfo and weekdayInfo.wday or nil),
        timeString = timeString,
        detectedTimezone = explicitTimezone and displayTimezone or nil,
        detectedTimezoneRaw = explicitTimezone and timezone or nil,
        detectedTimezoneDisplay = displayTimezone,
        explicitTimezone = explicitTimezone == true,
        aboutString = aboutString,
        replacementString = replacementString,
        suppressCountdown = suppressCountdown,
        outputText = outputText,
        startPos = originalStartPos,
        endPos = originalEndPos,
        hour = core.hour,
        minute = core.minute,
        sourceKind = core.sourceKind,
        rawCore = core.rawCore,
        rawMatch = originalText:sub(originalStartPos, originalEndPos),
        detectedAmpm = ampm,
        explicitTimezone = explicitTimezone,
        timezone = displayTimezone,
        ambiguous = resolved.ambiguous,
        explicit24Hour = resolved.explicit24Hour,
        explicitMeridiem = resolved.explicitMeridiem,
        inferredMeridiem = resolved.inferredMeridiem,
        resolvedAmpm = resolved.resolvedAmpm,
        resolvedHour24 = resolved.resolvedHour24,
        resolvedMinute24 = resolved.resolvedMinute24,
        minutesUntil = resolved.minutesUntil,
        nowTimestamp = resolved.nowTimestamp,
        eventTimestamp = resolved.eventTimestamp,
        diffSeconds = resolved.diffSeconds,
        sourceUtcOffsetHours = resolved.sourceUtcOffsetHours,
        sourceUtcOffsetSeconds = resolved.sourceUtcOffsetSeconds,
        sourceTimezoneSupported = resolved.sourceTimezoneSupported,
        targetIsDst = resolved.targetIsDst,
        coreCandidatesFound = allCores and #allCores or 0,
        protectedEsoLinks = #protectedSegments,
    }, allCores or {}
end

function SmartChatMsg:EmitCountdownDebugResult(label, input, best, all)
    if not self.debugEnabled then return end
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] --------------------------------------------------")
    if label and label ~= "" then SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] " .. tostring(label)) end
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Input: " .. tostring(input))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Time String: " .. tostring(best and best.timeString or "nil"))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Output: " .. tostring(best and best.outputText or input))
    if not best then
        SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] No time found")
        return
    end
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Detected Date Raw: " .. tostring(best.detectedDateRaw))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Detected Date Value: " .. tostring(best.detectedDateValue))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Detected Date Normalized: " .. tostring(best.detectedDateNormalized))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Detected Date Day Delta: " .. tostring(best.detectedDateDayDelta))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Detected Date Assumed Next Year: " .. tostring(best.detectedDateAssumedNextYear))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Detected Date Explicit Past: " .. tostring(best.detectedDateExplicitPast))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Detected Date Weekday Abbr: " .. tostring(best.detectedDateWeekdayAbbr))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Date Used For Countdown: " .. tostring(best.dateUsedForCountdown))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Tomorrow Raw: " .. tostring(best.tomorrowRaw))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Weekday Raw: " .. tostring(best.weekdayRaw))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Weekday Abbr: " .. tostring(best.weekdayAbbr))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Countdown Suppressed: " .. tostring(best.suppressCountdown))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] About String: " .. tostring(best.aboutString))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Replacement: " .. tostring(best.replacementString))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Raw core: " .. tostring(best.rawCore))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Source kind: " .. tostring(best.sourceKind))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Detected AM/PM: " .. tostring(best.detectedAmpm))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Timezone: " .. tostring(best.timezone))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Current Timestamp: " .. tostring(best.nowTimestamp))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Event Timestamp: " .. tostring(best.eventTimestamp))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Diff Seconds: " .. tostring(best.diffSeconds))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Source UTC Offset Hours: " .. tostring(best.sourceUtcOffsetHours))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Source UTC Offset Seconds: " .. tostring(best.sourceUtcOffsetSeconds))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Ambiguous: " .. tostring(best.ambiguous))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Inferred meridiem: " .. tostring(best.inferredMeridiem))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Resolved AM/PM: " .. tostring(best.resolvedAmpm))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Resolved 24-hour: " .. string.format("%02d:%02d", best.resolvedHour24, best.resolvedMinute24))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Minutes until: " .. tostring(best.minutesUntil))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Core candidates found: " .. tostring(all and #all or best.coreCandidatesFound or 0))
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Protected ESO Links: " .. tostring(best.protectedEsoLinks or 0))
end

function SmartChatMsg:FindEmbeddedTimeDetails(text)
    local best = self:AnalyzeEmbeddedTime(text)
    if not best then return nil, nil, nil, nil end
    return best.rawMatch, best.resolvedHour24, best.resolvedMinute24, best.timezone
end

function SmartChatMsg:ExtractEmbeddedTimeParts(text)
    local _, hour, minute, timezoneToken = self:FindEmbeddedTimeDetails(text)
    return hour, minute, timezoneToken
end

function SmartChatMsg:FindEmbeddedTimeSubstring(text)
    local best = self:AnalyzeEmbeddedTime(text)
    return best and best.rawMatch or nil
end

function SmartChatMsg:GetExpandedDetectedTimeSpan(sourceText, timeMatch)
    local best = self:AnalyzeEmbeddedTime(sourceText)
    if not best then return nil end
    return {
        startIndex = best.startPos,
        endIndex = best.endPos,
        baseMatchStart = best.startPos,
        baseMatchEnd = best.endPos,
        fullMatch = best.rawMatch,
        replacedSubstring = best.rawMatch,
    }
end

function SmartChatMsg:GetEmbeddedDayOffset(text, nowEpoch, timeMatch)
    local best = self:AnalyzeEmbeddedTime(text, SCM_DEFAULT_TIMEZONE, os.date("!*t", tonumber(nowEpoch) or scm_get_utc_now()))
    if not best then return nil end
    if best.detectedDateDayDelta ~= nil then return best.detectedDateDayDelta end
    if best.tomorrowRaw then return 1 end
    if best.weekdayWday then
        local nowTable = os.date("!*t", tonumber(nowEpoch) or scm_get_utc_now())
        return (best.weekdayWday - nowTable.wday) % 7
    end
    return 0
end

function SmartChatMsg:GetCountdownUntilEmbeddedTimeText(text,eventAtUtc)
    local best = self:AnalyzeEmbeddedTime(text)
    if best and type(eventAtUtc)=="number" then
        best.suppressCountdown=false
        best.aboutString="("..scm_format_about_duration(math.floor((eventAtUtc-GetTimeStamp())/60))..")"
    end
    if not best or best.suppressCountdown then return nil, nil end
    local countdownText = best.aboutString and best.aboutString:gsub("^%(", ""):gsub("%)$", "") or nil
    local metadata = {
        timeMatch = best.rawMatch,
        sourceTz = best.timezone,
        hasExplicitMeridiem = best.explicitMeridiem,
        shouldUseNearestFuture12Hour = best.ambiguous,
        assumedMeridiem = best.inferredMeridiem and best.resolvedAmpm or nil,
        resolvedHour24 = best.resolvedHour24,
    }
    return countdownText, metadata
end

function SmartChatMsg:InsertCountdownIntoMessageText(text,eventAtUtc)
    local source = tostring(text or "")
    local best, all = self:AnalyzeEmbeddedTime(source)
    if self.debugEnabled then
        self:EmitCountdownDebugResult("Countdown Debug", source, best, all)
    end
    -- Use main's improved parser, but preserve the template's literal wording
    -- and expose countdown insertion metadata for incoming peer matching.
    return self:InsertCountdownPreservingTemplate(source,eventAtUtc)
end

function SmartChatMsg:ApplyMessageSubstitutions(text, commandId, guildName)
    local eventAtUtc
    if zo_strlower(tostring(text or "")):find("%eventtime%",1,true) then
        local schedule=self:GetGuildSchedule(commandId,guildName)
        local occurrence=schedule and self:GetScheduleOccurrence(schedule,GetTimeStamp())
        eventAtUtc=occurrence and occurrence.eventAtUtc
    end
    local result = self:ResolveScheduledEventTokens(text,commandId,guildName)
    local timeOfDay = self:GetCurrentTimeTokenValue()
    local substitutions = {
        ["timeofday"] = timeOfDay,
        ["greeting"] = timeOfDay,
        ["morning"] = timeOfDay,
        ["time"] = timeOfDay,
        ["guild"] = self:Trim(guildName or ""),
        ["zone"] = self:GetCurrentZoneName() or "",
    }
    result = result:gsub("%%([%a]+)%%", function(tokenName)
        local normalizedToken = zo_strlower(tokenName or "")
        local replacement = substitutions[normalizedToken]
        if replacement ~= nil and replacement ~= "" then return replacement end
        return "%" .. tostring(tokenName or "") .. "%"
    end)
    result = self:InsertCountdownIntoMessageText(result,eventAtUtc)
    return result
end


function SmartChatMsg:ShowQueuedExecutionNotification(commandDisplayName, guildName)
    local message = string.format("%s queued for execution for %s.", tostring(commandDisplayName or "/command"), tostring(guildName or "unknown guild"))

    if self.debugEnabled then
        SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] " .. message)
        return
    end

    if CENTER_SCREEN_ANNOUNCE then
        CENTER_SCREEN_ANNOUNCE:AddMessage(EVENT_SKILL_RANK_UPDATE, CSA_EVENT_SMALL_TEXT, SOUNDS.DEFAULT_CLICK, message)
    else
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.DEFAULT_CLICK, message)
    end
end

function SmartChatMsg:GetQueueEntryDisplayGuildName(entry)
    local guildName = self:Trim(type(entry) == "table" and entry.guildName or "")
    if guildName ~= "" then
        return guildName
    end

    local guildIndex = type(entry) == "table" and tonumber(entry.guildIndex) or nil
    if guildIndex and guildIndex >= 1 and guildIndex <= 5 then
        local resolvedGuildName = self:GetGuildNameByIndex(guildIndex)
        resolvedGuildName = self:Trim(resolvedGuildName or "")
        if resolvedGuildName ~= "" then
            return resolvedGuildName
        end
    end

    return "Unknown Guild"
end

function SmartChatMsg:GetQueueEntryDisplayCommandName(entry)
    local commandName = nil
    if type(entry) == "table" then
        commandName = self:GetCommandNameById(entry.commandId)
        if self:Trim(commandName or "") == "" then
            commandName = entry.slashCommandName
        end
    end

    commandName = self:Trim(commandName or "")
    if commandName ~= "" then
        return commandName
    end

    return "Unknown Command"
end

function SmartChatMsg:GetQueueEntryDisplaySource(entry)
    local source = self:Trim(type(entry) == "table" and entry.source or "")
    if source == "" then
        return "unknown"
    end

    local lookup = {
        startup = "Startup",
        slash = "Manual",
        manual = "Manual",
        reminder = "Repeat",
        ["repeat"] = "Repeat",
        autopopulate = "Auto Populate",
        zone = "Auto Populate",
        scheduled = "Scheduled",
    }

    return lookup[zo_strlower(source)] or source
end

function SmartChatMsg:GetActiveQueueItemNextAttemptSeconds(entry)
    if type(entry) ~= "table" or type(entry.id) ~= "string" or entry.id == "" then
        return nil
    end

    local pendingState = self.pendingRestoreState
    if type(pendingState) ~= "table" then
        return nil
    end

    local metadata = pendingState.metadata
    if type(metadata) ~= "table" or metadata.queueItemId ~= entry.id then
        return nil
    end

    local timeoutSeconds = tonumber(pendingState.timeoutSeconds)
    local armedAtMs = tonumber(pendingState.armedAt)
    local nowMs = GetFrameTimeMilliseconds and tonumber(GetFrameTimeMilliseconds()) or nil
    if not timeoutSeconds or not armedAtMs or not nowMs then
        return nil
    end

    local elapsedSeconds = math.max(0, (nowMs - armedAtMs) / 1000)
    local timeoutRemainingSeconds = math.max(0, math.ceil(timeoutSeconds - elapsedSeconds))

    if metadata.reminderRepeat == true then
        local commandId = metadata.commandId
        local guildName = metadata.guildName
        if type(commandId) ~= "string" or commandId == "" or type(guildName) ~= "string" or guildName == "" then
            return timeoutRemainingSeconds
        end

        local retryMinutes = self:GetGuildEffectiveReminderRetryMinutes(commandId, guildName) or 0
        if retryMinutes > 0 then
            return timeoutRemainingSeconds + (retryMinutes * 60)
        end

        local reminderMinutes = self:GetGuildReminderMinutes(commandId, guildName) or 0
        if reminderMinutes > 0 then
            return timeoutRemainingSeconds + (reminderMinutes * 60)
        end

        return timeoutRemainingSeconds
    end

    local sourceText = zo_strlower(tostring(entry.source or metadata.source or ""))
    if metadata.autoPopulate == true or sourceText == "autopopulate" or sourceText == "zone" then
        return nil
    end

    return nil
end

function SmartChatMsg:DumpQueueSummaryToChat()
    local queue = self.startupQueue or {}
    local current = self.startupQueueCurrent
    local count = 0

    if type(current) == "table" then
        count = count + 1
    end
    count = count + #queue

    if count <= 0 then
        SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] There are no pending queued commands.")
        return
    end

    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Pending queued commands:")

    local order = 0
    if type(current) == "table" then
        order = order + 1
        local guildName = self:GetQueueEntryDisplayGuildName(current)
        local commandName = self:GetQueueEntryDisplayCommandName(current)
        local sourceText = self:GetQueueEntryDisplaySource(current)
        local nextAttemptSeconds = self:GetActiveQueueItemNextAttemptSeconds(current)
        local nextAttemptText = nextAttemptSeconds ~= nil and string.format(" | Next Attempt In: %ss", tostring(nextAttemptSeconds)) or ""
        SmartChatMsg:AddLocalChatMessage(string.format("[SmartChatMsg] %d) [ACTIVE] %s -> %s | Source: %s%s", order, guildName, commandName, sourceText, nextAttemptText))
    end

    for _, entry in ipairs(queue) do
        order = order + 1
        local guildName = self:GetQueueEntryDisplayGuildName(entry)
        local commandName = self:GetQueueEntryDisplayCommandName(entry)
        local sourceText = self:GetQueueEntryDisplaySource(entry)
        SmartChatMsg:AddLocalChatMessage(string.format("[SmartChatMsg] %d) %s -> %s | Source: %s", order, guildName, commandName, sourceText))
    end

    SmartChatMsg:AddLocalChatMessage(string.format("[SmartChatMsg] Total queued items: %d", count))
end

function SmartChatMsg:HandleScmDebugCommand(paramText)
    local rawText = self:Trim(paramText or "")
    local normalized = zo_strlower(rawText)
    local args = {}
    for token in string.gmatch(rawText, "%S+") do table.insert(args, token) end
    local subCommand = args[1] and zo_strlower(args[1]) or ""
    if normalized == "" then
        self.debugEnabled = not self.debugEnabled
        SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Debug is now " .. (self.debugEnabled and "ON" or "OFF"))
        return
    elseif normalized == "on" or normalized == "1" or normalized == "true" then
        self.debugEnabled = true
        SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Debug is now ON")
        return
    elseif normalized == "off" or normalized == "0" or normalized == "false" then
        self.debugEnabled = false
        SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Debug is now OFF")
        return
    elseif normalized == "status" then
        SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Debug is " .. (self.debugEnabled and "ON" or "OFF"))
        return
    elseif subCommand == "queue" then
        self:DumpQueueSummaryToChat()
        self:DumpQueueState("slash command")
        return
    elseif subCommand == "countdown" then
        local testText = rawText:match("^%S+%s+(.+)$")
        if not testText or self:Trim(testText) == "" then
            SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Usage: /scmdebug countdown <text>")
            return
        end
        local best, all = self:AnalyzeEmbeddedTime(testText)
        self:EmitCountdownDebugResult("Countdown Debug", testText, best, all)
        return
    end
    SmartChatMsg:AddLocalChatMessage("[SmartChatMsg] Usage: /scmdebug, /scmdebug on, /scmdebug off, /scmdebug status, /scmdebug queue, /scmdebug countdown <text>")
end
