SmartChatMsg = SmartChatMsg or {}

-- Preserve punctuation and link identity. General fuzzy matching is too broad
-- for deciding whether somebody else's advertisement belongs to this guild.
function SmartChatMsg:NormalizeIncomingChatText(text)
    local value = zo_strlower(tostring(text or ""))
    value = value:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    value = value:gsub("|h%d+:([^|]+)|h([^|]*)|h", "|h:%1|h%2|h")
    value = value:gsub("[%c]", " "):gsub("%s+", " ")
    return self:Trim(value)
end

function SmartChatMsg:IsOwnChatSender(fromName, fromDisplayName)
    local account = self:Trim(GetDisplayName() or "")
    for _, name in ipairs({ fromDisplayName or "", fromName or "" }) do
        if account ~= "" and self:StringsEqualIgnoreCase(name, account) then
            return true
        end
    end
    local function characterName(name)
        return self:Trim(zo_strlower(tostring(name or "")):gsub("%^[%a]+", ""))
    end
    local player = characterName(GetUnitName("player"))
    return player ~= "" and characterName(fromName) == player
end

function SmartChatMsg:GetIncomingChatScope(messageType)
    if type(messageType) ~= "number" then return nil end
    if messageType == CHAT_CHANNEL_ZONE then return "Zone", nil end
    if messageType == CHAT_CHANNEL_PARTY then return "Group", nil end
    if messageType >= CHAT_CHANNEL_GUILD_1 and messageType <= CHAT_CHANNEL_GUILD_5 then
        return "Guild", self:GetGuildNameByIndex(messageType - CHAT_CHANNEL_GUILD_1 + 1)
    end
    if messageType >= CHAT_CHANNEL_OFFICER_1 and messageType <= CHAT_CHANNEL_OFFICER_5 then
        return "Officer", self:GetGuildNameByIndex(messageType - CHAT_CHANNEL_OFFICER_1 + 1)
    end
    return nil
end

function SmartChatMsg:IsKnownIncomingZoneName(value)
    if not self.incomingZoneNames then
        self.incomingZoneNames = {}
        for index = 1, GetNumZones() do
            local name = GetZoneNameByIndex(index)
            if name and name ~= "" then
                self.incomingZoneNames[self:NormalizeIncomingChatText(name)] = true
                self.incomingZoneNames[self:NormalizeIncomingChatText(zo_strformat("<<1>>", name))] = true
            end
        end
    end
    local currentZone = self:GetCurrentZoneName()
    if currentZone then self.incomingZoneNames[self:NormalizeIncomingChatText(currentZone)] = true end
    return self.incomingZoneNames[value] == true
end

function SmartChatMsg:IsGeneratedCountdownText(text, soonText)
    if text == soonText or text == "soon" then return true end
    local shortMinutes = text:match("^(%d+)m$")
    if shortMinutes then
        local minutes = tonumber(shortMinutes)
        return minutes >= 5 and minutes < 15
    end
    -- The current formatter emits compact durations, optionally prefixed with
    -- '~' when rounded; older versions used 'about '. Validate both grammars.
    local duration = text:match("^about (.+)$") or text:gsub("^~", "", 1)
    local previousRank, count = 0, 0
    local units = { d = {1, 36500}, h = {2, 23}, m = {3, 59} }
    for part in duration:gmatch("%S+") do
        local amount, unit = part:match("^(%d+)([dhm])$")
        local rule = unit and units[unit]
        amount = tonumber(amount)
        if not rule or not amount or amount < 1 or amount > rule[2] or rule[1] <= previousRank then
            return false
        end
        previousRank, count = rule[1], count + 1
    end
    return count > 0
end

function SmartChatMsg:IsGeneratedTimeAddition(text, details)
    -- Also recognize the unannotated original from older addon versions.
    if text == "" then return true end
    local suffix, countdown = text:match("^(.-)%s*%(([^()]*)%)$")
    if not countdown or not self:IsGeneratedCountdownText(countdown, details.soonText) then return false end
    suffix = self:Trim(suffix)
    if details.allowMeridiem then
        suffix = suffix:gsub("^[ap]m%s*", "", 1)
    end
    if suffix == "" then return true end
    if not details.allowTimezone then return false end
    for _, token in ipairs(self:GetSupportedTimezoneTokens()) do
        if suffix == zo_strlower(token) then return true end
    end
    return suffix == "adt" or suffix:match("^utc[%+%-]%d%d?$") ~= nil
end

function SmartChatMsg:BuildIncomingMessageMatcher(template, guildName, commandId)
    local fields = {}
    local function field(kind, details)
        local marker = "SCMMATCHFIELD" .. tostring(#fields + 1) .. "SCM"
        fields[#fields + 1] = { marker = zo_strlower(marker), kind = kind, details = details }
        return marker
    end
    local source = tostring(template or "")
    -- Avoid interpreting a literal marker supplied by a user as a wildcard.
    if zo_strlower(source):find("scmmatchfield", 1, true) then return nil end
    source = source:gsub("%%([%a]+)%%", function(token)
        token = zo_strlower(token)
        if token == "guild" then return guildName end
        if token == "time" or token == "timeofday" or token == "greeting" then return field("greeting") end
        if token == "zone" then return field("zone") end
        if commandId and (token == "eventdate" or token == "eventtime" or token == "eventfaction") then
            return self:GetScheduledEventTokenValue(token,commandId,guildName) or "%"..token.."%"
        end
        if commandId and token == "eventwhen" then
            local schedule=self:GetGuildSchedule(commandId,guildName)
            if schedule then
                return self:GetScheduledEventTokenValue(token,commandId,guildName)
            end
        end
        return "%" .. token .. "%"
    end)
    local _, timeDetails = self:InsertCountdownIntoMessageText(source)
    -- Older clients may annotate a bare time even though the current formatter
    -- requires an explicit timezone. Match only additions at that detected time.
    if not timeDetails then
        local detected = self:AnalyzeEmbeddedTime(source)
        if detected and not detected.explicitTimezone then
            timeDetails = {
                prefix = source:sub(1, detected.startPos - 1),
                timeText = detected.rawMatch,
                suffix = source:sub(detected.endPos + 1),
                allowMeridiem = not detected.explicitMeridiem and detected.ambiguous,
                allowTimezone = true,
                soonText = self:HasEndingPhraseBeforeTime(source, detected.rawMatch) and "ending soon" or "starting soon",
            }
        end
    end
    if timeDetails then
        source = timeDetails.prefix .. timeDetails.timeText .. field("countdown", timeDetails) .. timeDetails.suffix
    end
    source = self:NormalizeIncomingChatText(source)
    if source == "" then return nil end

    local captures, chunks, position, literalLength = {}, {}, 1, 0
    while position <= #source do
        local firstStart, firstEnd, nextField
        for _, candidate in ipairs(fields) do
            local startPos, endPos = source:find(candidate.marker, position, true)
            if startPos and (not firstStart or startPos < firstStart) then
                firstStart, firstEnd, nextField = startPos, endPos, candidate
            end
        end
        local literal = source:sub(position, firstStart and firstStart - 1 or #source)
        literalLength = literalLength + #literal:gsub("[%s%p]", "")
        chunks[#chunks + 1] = self:EscapeLuaPattern(literal)
        if not firstStart then break end
        chunks[#chunks + 1] = "(.-)"
        captures[#captures + 1] = nextField
        position = firstEnd + 1
    end
    -- A template made only of variables cannot establish message identity.
    if #captures > 0 and literalLength == 0 then return nil end
    return { pattern = "^" .. table.concat(chunks) .. "$", captures = captures }
end

function SmartChatMsg:MatchesIncomingMessage(entry, guildName, normalizedText)
    self.incomingMessageMatchCache = self.incomingMessageMatchCache or setmetatable({}, { __mode = "k" })
    local cached = self.incomingMessageMatchCache[entry]
    local schedule=self:GetGuildSchedule(entry.commandId,guildName)
    local occurrence=schedule and self:GetScheduleOccurrence(schedule,GetTimeStamp())
    local eventAt=occurrence and occurrence.eventAtUtc or (schedule and schedule.eventAtUtc)
    local eventWhen=schedule and self:GetScheduledEventTokenValue("eventwhen",entry.commandId,guildName)
    local eventFaction=schedule and self:GetScheduledEventTokenValue("eventfaction",entry.commandId,guildName)
    if not cached or cached.text ~= entry.text or cached.guildName ~= guildName or cached.eventAt~=eventAt or cached.eventWhen~=eventWhen or cached.eventFaction~=eventFaction then
        cached = { text = entry.text, guildName = guildName,eventAt=eventAt,eventWhen=eventWhen,eventFaction=eventFaction, matcher = self:BuildIncomingMessageMatcher(entry.text, guildName,entry.commandId) }
        self.incomingMessageMatchCache[entry] = cached
    end
    local matcher = cached.matcher
    if not matcher then return false end
    if #matcher.captures == 0 then return normalizedText:match(matcher.pattern) ~= nil end
    local values = { normalizedText:match(matcher.pattern) }
    if #values ~= #matcher.captures then return false end
    local substitutions = {}
    for index, capture in ipairs(matcher.captures) do
        local value = values[index]
        if capture.kind == "greeting" then
            if value ~= "morning" and value ~= "afternoon" and value ~= "evening" then return false end
        elseif capture.kind == "zone" then
            if not self:IsKnownIncomingZoneName(value) then return false end
        elseif not self:IsGeneratedTimeAddition(value, capture.details) then
            return false
        end
        if capture.kind ~= "countdown" then
            if substitutions[capture.kind] and substitutions[capture.kind] ~= value then return false end
            substitutions[capture.kind] = value
        end
    end
    return true
end

function SmartChatMsg:NormalizeObservedChatCooldowns(value)
    local result = {}
    if type(value) ~= "table" then return result end
    for scope, usage in pairs(value) do
        local zone = tonumber(scope)
        if (scope == "*" or (zone and zone > 0 and zone == math.floor(zone))) and type(usage) == "table"
            and type(usage.at) == "number" and usage.at > 0 and usage.at < math.huge
            and type(usage.delaySeconds) == "number" and usage.delaySeconds >= 30 and usage.delaySeconds <= 90 then
            result[tostring(scope)] = { at = math.floor(usage.at), delaySeconds = math.floor(usage.delaySeconds) }
        end
    end
    return result
end

function SmartChatMsg:GetObservedChatCooldownEndsAt(commandId, guildName, zoneId, cooldownSeconds)
    local settings = self:GetCommandGuildSettings(commandId, guildName, false)
    local usages = settings and settings.observedChatCooldowns
    if type(usages) ~= "table" then return nil end
    local endsAt
    for _, scope in ipairs({ "*", tostring(zoneId) }) do
        local usage = usages[scope]
        if type(usage) == "table" then
            local candidate = usage.at + cooldownSeconds + usage.delaySeconds
            endsAt = endsAt and math.max(endsAt, candidate) or candidate
        end
    end
    return endsAt
end

-- Passive observations apply even before this command's automation is started.
function SmartChatMsg:GetObservedCommandCooldownEndsAt(commandId,guildName,channel)
    local minutes=self:GetGuildReminderMinutes(commandId,guildName) or self:GetGuildAutoPopulateCooldownMinutes(commandId,guildName)
    local zone=channel=="Zone" and self:GetPlayerZoneId() or nil
    return self:GetObservedChatCooldownEndsAt(commandId,guildName,zone,(minutes or 0)*60)
end

function SmartChatMsg:WithdrawObservedChatDuplicate(commandId, guildName)
    local state = self.pendingRestoreState
    local metadata = state and state.metadata
    if type(metadata) ~= "table" or metadata.commandId ~= commandId
        or not self:StringsEqualIgnoreCase(metadata.guildName or "", guildName) then return end
    local edit = self:GetChatEditControl()
    if edit and edit.GetText and state.rawExpectedText
        and edit:GetText() == state.rawExpectedText then
        self:ClearPendingChatBuffer()
        self:RestoreChatChannel(state.previousChannel)
    end
    -- Cancel timeout/retry even when the player has edited the pending text.
    self:ClearPendingRestoreState("another player posted a matching command/guild message")
    if metadata.startupQueue then
        self:FinalizeStartupQueueCurrent(true, "another player already posted the startup message")
    end
end

function SmartChatMsg:MarkObservedChatUsage(entry, guildName, channel)
    local commandId = entry.commandId
    local command = self:GetCommandById(commandId)
    if not command then return end
    local repeatActive = self:IsReminderAutomationActive(commandId, guildName)
    local timestamp, delaySeconds = GetTimeStamp(), zo_random(30, 90)
    local paramText = self:GetGuildLastUsedParamText(commandId, guildName)
    local guildIndex = self:GetGuildLastUsedGuildIndex(commandId, guildName) or self:GetGuildSlotByName(guildName)
    self:SetGuildLastUsedState(commandId, guildName, timestamp, paramText, guildIndex)
    command.lastUsedAt = timestamp
    self:MarkMessageEntryUsed(entry)

    local zoneId = self:GetPlayerZoneId()
    local settings = self:GetCommandGuildSettings(commandId, guildName, true)
    settings.observedChatCooldowns = settings.observedChatCooldowns or {}
    local scope = channel == "Zone" and zoneId and tostring(zoneId) or "*"
    settings.observedChatCooldowns[scope] = { at = timestamp, delaySeconds = delaySeconds }
    if zoneId and zoneId ~= 0 then
        self:SetGuildAutoPopulateLastSentAt(commandId, guildName, zoneId, timestamp)
    end
    self:WithdrawObservedChatDuplicate(commandId, guildName)
    local key=self:GetReminderStateKey(commandId,guildName)
    local waiting=self.chatPopulationQueue and self.chatPopulationQueue[key]
    if waiting and waiting.metadata.observedDueAt then
        waiting.metadata.observedDueAt=self:GetObservedCommandCooldownEndsAt(commandId,guildName,waiting.channelOverride or channel)
    else self:CancelQueuedChatPopulation(commandId, guildName) end
    local scheduledRuntime = self.scheduleRuntime and self.scheduleRuntime[self:GetReminderStateKey(commandId, guildName)]
    if scheduledRuntime then scheduledRuntime.zonePending = false end
    if repeatActive then self:ScheduleCommandReminder(commandId, guildName, delaySeconds) end
    self:DebugLog(string.format("Incoming match commandId=%s guild=%s channel=%s cooldown delay=%ds", commandId, guildName, channel, delaySeconds))
end

function SmartChatMsg:HandleIncomingChatMessage(eventCode, messageType, fromName, text, isCustomerService, fromDisplayName)
    if not self.savedVars or isCustomerService or self:IsOwnChatSender(fromName, fromDisplayName) then return end
    if self:Trim(fromName or "") == "" and self:Trim(fromDisplayName or "") == "" then return end
    local channel, receivingGuild = self:GetIncomingChatScope(messageType)
    if not channel or (channel ~= "Zone" and channel ~= "Group" and not receivingGuild) then return end
    local normalizedText = self:NormalizeIncomingChatText(text)
    if normalizedText == "" then return end
    local matched = {}
    for _, entry in ipairs(self.savedVars.messages or {}) do
        if type(entry) == "table" and type(entry.text) == "string" and self:GetCommandById(entry.commandId) then
            local guildName = entry.guildName
            if not guildName or guildName == "" then guildName = self:GetGuildNameByIndex(entry.guildIndex) end
            if guildName and self:GetSavedChatChannel(entry.commandId, guildName) == channel
                and (channel == "Zone" or channel == "Group" or self:StringsEqualIgnoreCase(guildName, receivingGuild)) then
                local key = self:GetReminderStateKey(entry.commandId, guildName)
                if key and not matched[key] and self:MatchesIncomingMessage(entry, guildName, normalizedText) then
                    matched[key] = true
                    self:MarkObservedChatUsage(entry, guildName, channel)
                end
            end
        end
    end
    if next(matched) and self.statusPanelVisible then self:RefreshStatusPanel() end
end

function SmartChatMsg:RegisterIncomingChatWatcher()
    EVENT_MANAGER:RegisterForEvent(self.name .. "_IncomingChat", EVENT_CHAT_MESSAGE_CHANNEL, function(...)
        SmartChatMsg:HandleIncomingChatMessage(...)
    end)
end
