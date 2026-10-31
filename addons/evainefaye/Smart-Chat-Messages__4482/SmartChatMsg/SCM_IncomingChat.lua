SmartChatMsg = SmartChatMsg or {}

-- Normalize presentation while preserving punctuation and identities.
-- A bounded spelling fallback below only edits unprotected letters.
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
    local fields,identities = {},{}
    local function resolved(token)
        local value=self:GetScheduledEventTokenValue(token,commandId,guildName)
        if value then identities[#identities+1]=self:NormalizeIncomingChatText(value) end
        return value
    end
    local function field(kind, details)
        local marker = "SCMMATCHFIELD" .. tostring(#fields + 1) .. "SCM"
        fields[#fields + 1] = { marker = zo_strlower(marker), kind = kind, details = details }
        return marker
    end
    local source = tostring(template or "")
    -- Avoid interpreting a literal marker supplied by a user as a wildcard.
    if zo_strlower(source):find("scmmatchfield", 1, true) then return nil end
    source = source:gsub("%%([%a][%w_:+%-]*)%%", function(token)
        token = zo_strlower(token)
        if token == "guild" then return guildName end
        if token == "time" or token == "timeofday" or token == "greeting" then return field("greeting") end
        if token == "zone" then return field("zone") end
        local eventKind=self:ParseScheduledEventToken(token)
        if commandId and eventKind=="eventcountdown" and self:GetGuildSchedule(commandId,guildName) then
            return field("eventcountdown")
        end
        if commandId and (eventKind=="eventtime" or eventKind=="eventdate") and self:GetScheduledEventTokenValue(token,commandId,guildName) then
            return field("eventvalue:"..token,{token=token,commandId=commandId,guildName=guildName,allowCountdown=eventKind=="eventtime" and not self:HasExplicitEventCountdown(template)})
        end
        if commandId and (eventKind == "eventdate" or eventKind == "eventtime" or eventKind == "eventfaction" or eventKind == "eventactivity") then
            return resolved(token) or "%"..token.."%"
        end
        if commandId and eventKind == "eventwhen" then
            local schedule=self:GetGuildSchedule(commandId,guildName)
            if schedule then
                return field("eventwhen",{token=token,commandId=commandId,guildName=guildName})
            end
        end
        return "%" .. token .. "%"
    end)
    local timeDetails
    local explicitCountdown=self:HasExplicitEventCountdown(template)
    if not explicitCountdown then
        local ignored
        ignored,timeDetails=self:InsertCountdownIntoMessageText(source)
    end
    -- Older clients may annotate a bare time even though the current formatter
    -- requires an explicit timezone. Match only additions at that detected time.
    if not explicitCountdown and not timeDetails then
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

    local captures, chunks, parts, position, literalLength = {}, {}, {}, 1, 0
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
        parts[#parts+1]={literal=literal}
        if not firstStart then break end
        chunks[#chunks + 1] = "(.-)"
        captures[#captures + 1] = nextField
        parts[#parts+1]={capture=nextField}
        position = firstEnd + 1
    end
    -- A template made only of variables cannot establish message identity.
    if #captures > 0 and literalLength == 0 then return nil end
    return { pattern = "^" .. table.concat(chunks) .. "$", captures = captures, parts=parts, literalLength=literalLength, guildName=self:NormalizeIncomingChatText(guildName), identities=identities }
end

function SmartChatMsg:IsValidIncomingMatchCapture(capture,value)
 if capture.kind:match('^eventvalue:') then return self:IsMatchingEventValue(value,capture.details)
 elseif capture.kind=='greeting' then return value=='morning' or value=='afternoon' or value=='evening'
 elseif capture.kind=='zone' then return self:IsKnownIncomingZoneName(value)
 elseif capture.kind=='eventwhen' then return self:IsMatchingEventWhen(value,capture.details)
 elseif capture.kind=='eventcountdown' then
  local minutes=tonumber(value:match('^(%d+)m$'))
  return (minutes and minutes>=1 and minutes<=59) or value=='now' or value=='passed' or self:IsGeneratedCountdownText(value,'soon')
 else return self:IsGeneratedTimeAddition(value,capture.details) end
end

-- Banded optimal-string-alignment distance: insertion, omission, substitution
-- or adjacent transposition of ASCII letters only. Structural characters stay exact.
local function letter(char) local n=char:byte();return n and n>=97 and n<=122 end
local function spellingDistance(a,b,limit)
 if a==b then return 0 end
 if math.abs(#a-#b)>limit then return nil end
 local previous,older={},nil
 previous[0]=0
 for j=1,math.min(#b,limit) do if previous[j-1] and letter(b:sub(j,j)) then previous[j]=j end end
 for i=1,#a do
  local current={};if i<=limit and previous[0] and letter(a:sub(i,i)) then current[0]=i end
  local best=current[0] or 9999
  for j=math.max(1,i-limit),math.min(#b,i+limit) do
   local ac,bc=a:sub(i,i),b:sub(j,j)
   local cost=ac==bc and 0 or (letter(ac) and letter(bc) and 1 or 9999)
   local value=(previous[j-1] or 9999)+cost
   if letter(ac) then value=math.min(value,(previous[j] or 9999)+1) end
   if letter(bc) then value=math.min(value,(current[j-1] or 9999)+1) end
   if older and i>1 and j>1 and letter(ac) and letter(bc) and ac==b:sub(j-1,j-1) and bc==a:sub(i-1,i-1) then value=math.min(value,(older[j-2] or 9999)+1) end
   current[j]=value;best=math.min(best,value)
  end
  if best>limit then return nil end
  older,previous=previous,current
 end
 local cost=previous[#b];return cost and cost<=limit and cost or nil
end

local function identityCount(text,identity)
 local at,count=1,0
 if identity=='' then return 0 end
 while true do
  local first,last=text:find(identity,at,true);if not first then break end
  if not (letter(identity:sub(1,1)) and letter(text:sub(first-1,first-1))) and not (letter(identity:sub(-1)) and letter(text:sub(last+1,last+1))) then count=count+1 end
  at=last+1
 end
 return count
end

local function protectedSignature(text,guildName,identities)
 local values={}
 for link in text:gmatch('|h[^|]*|h[^|]*|h') do values[#values+1]='link:'..link end
 for word in text:gmatch('%S+') do if word:find('%d') then values[#values+1]='number:'..word end end
 local zones={et=true,est=true,edt=true,ct=true,cst=true,cdt=true,mt=true,mst=true,mdt=true,pt=true,pst=true,pdt=true,utc=true,gmt=true,am=true,pm=true}
 for word in text:gmatch('%a+') do if zones[word] then values[#values+1]='clock:'..word end end
 if guildName~='' then values[#values+1]='guild:'..identityCount(text,guildName) end
 for _,identity in ipairs(identities or {}) do
  values[#values+1]='identity:'..identity..':'..identityCount(text,identity)
  -- Protect complete words containing an identity, including deliberate suffixes.
  if identity~='' and not identity:find('%s') then for word in text:gmatch('%S+') do if word:find(identity,1,true) then values[#values+1]='identity-word:'..word end end end
 end
 return table.concat(values,'\001')
end

function SmartChatMsg:MatchesIncomingSpelling(matcher,text)
 -- No fuzzy matching for short/generic notices; long ads get at most 3 edits.
 local length=matcher.literalLength or 0
 if length<40 or #text>2000 then return false end
 local budget=math.min(3,math.max(1,math.floor(length/80)))
 local attempts,substitutions=0,{}
 local function match(partIndex,position,remaining)
  attempts=attempts+1;if attempts>5000 then return false end
  local part=matcher.parts[partIndex]
  if not part then return position==#text+1 end
  if part.literal then
   local literal=part.literal
   if literal=='' then return match(partIndex+1,position,remaining) end
   local signature=protectedSignature(literal,matcher.guildName,matcher.identities)
   -- Consider only nearby boundaries for inserted/omitted letters.
   for delta=-remaining,remaining do
    local size=#literal+delta
    if size>=0 and position+size-1<=#text then
     local candidate=text:sub(position,position+size-1)
     if signature==protectedSignature(candidate,matcher.guildName,matcher.identities) then
      local cost=spellingDistance(literal,candidate,remaining)
      if cost and match(partIndex+1,position+size,remaining-cost) then return true end
     end
    end
   end
   return false
  end
  local capture=part.capture
  for size=0,math.min(256,#text-position+1) do
   local value=text:sub(position,position+size-1)
   if self:IsValidIncomingMatchCapture(capture,value) then
    local consistent=capture.kind~='countdown' and capture.kind~='eventcountdown' and capture.kind~='eventwhen'
    local previous=consistent and substitutions[capture.kind] or nil
    if not previous or previous==value then
     if consistent then substitutions[capture.kind]=value end
     if match(partIndex+1,position+size,remaining) then return true end
     if consistent then substitutions[capture.kind]=previous end
    end
   end
  end
  return false
 end
 return match(1,1,budget)
end

function SmartChatMsg:MatchesIncomingMessage(entry, guildName, normalizedText)
    self.incomingMessageMatchCache = self.incomingMessageMatchCache or setmetatable({}, { __mode = "k" })
    local cached = self.incomingMessageMatchCache[entry]
    local schedule=self:GetGuildSchedule(entry.commandId,guildName)
    local occurrence=schedule and self:GetScheduleOccurrence(schedule,GetTimeStamp())
    local eventAt=occurrence and occurrence.eventAtUtc or (schedule and schedule.eventAtUtc)
    local eventWhen=schedule and self:GetScheduledEventTokenValue("eventwhen",entry.commandId,guildName)
    local eventFaction=schedule and self:GetScheduledEventTokenValue("eventfaction",entry.commandId,guildName)
    local eventActivity=schedule and self:GetScheduledEventTokenValue("eventactivity",entry.commandId,guildName)
    if not cached or cached.eventActivity~=eventActivity or cached.schedule~=schedule or cached.text ~= entry.text or cached.guildName ~= guildName or cached.eventAt~=eventAt or cached.eventWhen~=eventWhen or cached.eventFaction~=eventFaction then
        cached = { eventActivity=eventActivity,schedule=schedule,text = entry.text, guildName = guildName,eventAt=eventAt,eventWhen=eventWhen,eventFaction=eventFaction, matcher = self:BuildIncomingMessageMatcher(entry.text, guildName,entry.commandId) }
        self.incomingMessageMatchCache[entry] = cached
    end
    local matcher = cached.matcher
    if not matcher then return false end
    if #matcher.captures == 0 then return normalizedText:match(matcher.pattern) ~= nil or self:MatchesIncomingSpelling(matcher,normalizedText) end
    local values = { normalizedText:match(matcher.pattern) }
    if #values ~= #matcher.captures then return self:MatchesIncomingSpelling(matcher,normalizedText) end
    local substitutions = {}
    for index, capture in ipairs(matcher.captures) do
        local value = values[index]
        if not self:IsValidIncomingMatchCapture(capture,value) then return self:MatchesIncomingSpelling(matcher,normalizedText) end
        if capture.kind ~= "countdown" and capture.kind~="eventcountdown" and capture.kind~="eventwhen" then
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
    local phaseStart=self:GetScheduledCooldownStart(commandId,guildName)
    local endsAt
    for _, scope in ipairs({ "*", tostring(zoneId) }) do
        local usage = usages[scope]
        if type(usage) == "table" and (not phaseStart or usage.at>=phaseStart) then
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
                if key and self:MatchesIncomingMessage(entry, guildName, normalizedText) then
                    if not matched[key] then matched[key]={guildName=guildName,entries={}} end
                    local entries=matched[key].entries;entries[#entries+1]=entry
                end
            end
        end
    end
    for _,match in pairs(matched) do self:MarkObservedChatUsage(match.entries[1],match.guildName,channel,match.entries) end
    if next(matched) and self.statusPanelVisible then self:RefreshStatusPanel() end
end

function SmartChatMsg:RegisterIncomingChatWatcher()
    EVENT_MANAGER:RegisterForEvent(self.name .. "_IncomingChat", EVENT_CHAT_MESSAGE_CHANNEL, function(...)
        SmartChatMsg:HandleIncomingChatMessage(...)
    end)
end

-- Relative words may change while a prepared message waits across midnight.
-- Validate against this occurrence, never turn arbitrary date text into a wildcard.
function SmartChatMsg:IsMatchingEventWhen(value,details)
    local schedule=self:GetGuildSchedule(details.commandId,details.guildName)
    local now=GetTimeStamp()
    local occurrence=schedule and self:GetScheduleOccurrence(schedule,now)
    if not occurrence then return false end
    local function formatted(clock,condensed)
        return self:NormalizeIncomingChatText(self:GetScheduledEventTokenValue(details.token,details.commandId,details.guildName,{schedule=schedule,occurrence=occurrence,now=clock,condensedDateTime=condensed}) or "")
    end
    for _,condensed in ipairs({false,true}) do
        if value==formatted(now,condensed) or value==formatted(now-15*60,condensed) then return true end
    end
    local _,offset,mark=self:ParseScheduledEventToken(details.token)
    if mark then local important=(schedule.importantTimes or {})[mark];if not important then return false end;offset=important.offsetMinutes*60 end
    local event=self:GetScheduleParts(occurrence.eventAtUtc+(offset or 0),schedule)
    local days={"Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"}
    local absolute=string.format("%s %02d/%02d/%04d",days[event.wday],event.month,event.day,event.year)
    local compact=string.format("%s %02d/%02d",days[event.wday]:sub(1,3),event.month,event.day)
    return value==self:NormalizeIncomingChatText(absolute) or value==self:NormalizeIncomingChatText(absolute:sub(1,-6)) or value==self:NormalizeIncomingChatText(compact)
end

-- Formatting differs between peers, but the resolved event clock and date must agree.
function SmartChatMsg:IsMatchingEventValue(value,details)
    local schedule=self:GetGuildSchedule(details.commandId,details.guildName)
    if not schedule then return false end
    if details.allowCountdown then
        local clock,countdown=value:match("^(.-)%s*%(([^()]*)%)$")
        if clock and (countdown=='now' or countdown=='passed' or self:IsGeneratedCountdownText(countdown,'soon') or self:IsGeneratedCountdownText(countdown,'starting soon') or self:IsGeneratedCountdownText(countdown,'ending soon')) then value=self:Trim(clock) end
    end
    for _,condensed in ipairs({false,true}) do
        local expected=self:GetScheduledEventTokenValue(details.token,details.commandId,details.guildName,{schedule=schedule,condensedDateTime=condensed})
        if expected and value==self:NormalizeIncomingChatText(expected) then return true end
    end
    return false
end
