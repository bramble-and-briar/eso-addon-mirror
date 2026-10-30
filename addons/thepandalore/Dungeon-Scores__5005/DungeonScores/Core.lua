DungeonScores = DungeonScores or {}

-- Shared runtime constants, SavedVariables defaults, and pure helpers.

local DS = DungeonScores
DS.Util = DS.Util or {}
local Util = DS.Util

DS.NAME = "DungeonScores"
DS.VERSION = "0.5.37"
DS.SV_NAME = "DungeonScoresSavedVariables"
DS.SV_VERSION = 3
DS.MAX_BOSS_TAGS = 20 -- simultaneous boss unit-tag scan ceiling, not a dungeon boss-count assumption
DS.PULSE_INTERVAL_MS = 500
DS.RECENT_BOSS_DEATH_WINDOW_MS = 5000
DS.COMPLETION_GRACE_MS = 1000
DS.TERMINAL_ABILITY_DEATH_JOIN_MS = 2000
DS.ACTIVE_RUN_RESTORE_MAX_AGE_SECONDS = 15 * 60
DS.ZONE_EXIT_ABANDON_SECONDS = 4 * 60
DS.POST_EXIT_COMPLETION_RECOVERY_MS = 5000
DS.BOSS_ENCOUNTER_QUIET_MS = 4000
DS.HM_EVIDENCE_POLICY_VERSION = 8
DS.CLIENT_LANGUAGE = GetCVar and GetCVar("Language.2") or "en"
DS.MAX_PUBLICATION_QUEUE = 50

function DS:GetRecordsSnapshot()
    local records = rawget(_G, "DungeonScoresRecords")
    if type(records) == "table" and type(records.Data) == "table" then
        return records.Data
    end
    -- Read-only compatibility with older Records packages.
    local legacy = rawget(_G, "DungeonScoresRecordsData")
    return type(legacy) == "table" and legacy or nil
end

function DS:GetDeliverySnapshot()
    local records = rawget(_G, "DungeonScoresRecords")
    if type(records) == "table" and type(records.Delivery) == "table" then
        return records.Delivery
    end
    -- Read-only compatibility with older Records packages.
    local legacy = rawget(_G, "DungeonScoresDeliveryData")
    return type(legacy) == "table" and legacy or nil
end

local LEGACY_REFERENCE_FIELDS = {
    eliteQualified = true,
    eliteReferenceAsOf = true,
    eliteReferenceKind = true,
    eliteReferenceMs = true,
    beatWorldReference = true,
    wrDeltaMs = true,
    wrReferenceAsOf = true,
    wrReferenceCategory = true,
    wrReferenceMs = true,
    wrReferencePlatform = true,
}

DS.DEFAULTS = {
    settings = {
        showHud = true,
        showFinalScoreNotification = true,
        browserTitleFontSize = 24,
        browserHeaderFontSize = 18,
        browserListFontSize = 16,
        browserDetailFontSize = 16,
    },
    publicationTeams = {
        registryText = "",
    },
    publicationQueue = {},
    nextPublicationRequestId = 0,
    betaRunSnapshots = {},
    history = {},
    highScores = {},
    highScoresByParty = {},
    activeRun = nil,
    nextRunId = 0,
    frozenSessionZoneId = nil,
    historyWindow = {
        left = nil,
        top = nil,
        width = 900,
        height = 780,
    },
    hud = {
        left = nil,
        top = nil,
    },
}

function Util.NormalizeName(name)
    if not name or name == "" then
        return ""
    end
    return zo_strformat(SI_UNIT_NAME, name)
end

function Util.IsAuthoritativeCompletionReason(reason)
    return reason == "activity-finder-event" or reason == "lfg-activity-complete" or reason == "activity-finder-complete"
end

function Util.FormatDurationMs(milliseconds)
    if not milliseconds then
        return "--:--"
    end
    local totalSeconds = math.floor(milliseconds / 1000)
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds % 60
    return string.format("%d:%02d", minutes, seconds)
end

function Util.FormatString(stringId, ...)
    return zo_strformat(GetString(stringId), ...)
end

function Util.HasHealthLoss(currentHealth, maxHealth)
    return currentHealth ~= nil and maxHealth ~= nil and maxHealth > 0 and currentHealth < maxHealth
end

function Util.DeepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    if seen[value] then
        return seen[value]
    end

    local copy = {}
    seen[value] = copy
    for key, item in pairs(value) do
        copy[Util.DeepCopy(key, seen)] = Util.DeepCopy(item, seen)
    end
    return copy
end

local function PurgeLegacyReferenceFields(value, seen)
    if type(value) ~= "table" then
        return
    end
    seen = seen or {}
    if seen[value] then
        return
    end
    seen[value] = true
    for key, item in pairs(value) do
        if LEGACY_REFERENCE_FIELDS[key] then
            value[key] = nil
        else
            PurgeLegacyReferenceFields(item, seen)
        end
    end
end

function DS:PurgeLegacyReferenceData()
    if self.saved then
        PurgeLegacyReferenceFields(self.saved)
    end
end

function DS:UpgradePendingStandardPublicationPayloads()
    -- A 0.5.22 request may still be waiting for the companion. Preserve its
    -- queue identity while removing unselected RTB evidence before upload.
    for _, request in ipairs(self.saved and self.saved.publicationQueue or {}) do
        local payload = type(request) == "table" and request.payload or nil
        if type(payload) == "table" and payload.schemaVersion == 2
            and payload.raceToBottomRequested ~= true then
            payload.schemaVersion = 3
            -- The request's version is the scorer that produced its points.
            -- Upgrading transport schema must not relabel an old score.
            payload.abandonmentPenalty = nil
            payload.abandonedHardModeCount = nil
            payload.abandonedHardModeScore = nil
            payload.companionObserved = nil
            payload.companionPenalty = nil
            payload.pitstopObserved = nil
            payload.pitstopPenalty = nil
            payload.raceToBottomScore = nil
        end
    end
end

-- Compare against the same published party-size division, never the
-- cross-division overall winner. Classification is read from the final
-- settlement; it is deliberately allowed to change after Freeze Completion.
function DS:GetCapturedWorldRecord(zoneId, runGroupSize)
    local snapshot = self:GetRecordsSnapshot()
    if type(snapshot) ~= "table"
        or type(snapshot.partyRecords) ~= "table" then
        return nil
    end

    local zone = tonumber(zoneId)
    local groupSize = tonumber(runGroupSize)
    if not zone or not groupSize or groupSize ~= math.floor(groupSize)
        or groupSize < 1 or groupSize > 4 then
        return nil
    end
    local function ReadDivision(records)
        local bySize = type(records) == "table"
            and (records[zone] or records[tostring(zone)]) or nil
        local record = type(bySize) == "table"
            and (bySize[groupSize] or bySize[tostring(groupSize)]) or nil
        if type(record) == "table" and tonumber(record.zoneId) == zone
            and tonumber(record.runGroupSize) == groupSize
            and tonumber(record.finalScore) ~= nil
            and (tonumber(record.elapsedMs) or 0) > 0
            and type(record.teamName) == "string" and record.teamName ~= ""
            and (record.megaserver == "NA Megaserver" or record.megaserver == "EU Megaserver") then
            return record
        end
    end
    if tonumber(snapshot.schemaVersion) == 2 then
        return ReadDivision(snapshot.partyRecords)
    elseif tonumber(snapshot.schemaVersion) == 1 then
        -- Read-only transition fallback until the companion refreshes the file.
        -- Old partitions are merged, never used as an eligibility boundary.
        local best = nil
        for _, records in pairs(snapshot.partyRecords) do
            local record = ReadDivision(records)
            if record and (not best or tonumber(record.finalScore) > tonumber(best.finalScore)
                or (tonumber(record.finalScore) == tonumber(best.finalScore)
                    and tonumber(record.elapsedMs) < tonumber(best.elapsedMs))) then
                best = record
            end
        end
        return best
    end
end

local function IsPublicIdentifier(value)
    return type(value) == "string" and #value >= 1 and #value <= 64
        and value:match("^[a-z0-9][a-z0-9_-]*$") ~= nil
end

local function EventIncludesZone(event, zoneId)
    if type(event.zoneIds) ~= "table" or #event.zoneIds == 0 then
        return true
    end
    for _, configuredZoneId in ipairs(event.zoneIds) do
        if tonumber(configuredZoneId) == tonumber(zoneId) then
            return true
        end
    end
    return false
end

local function HasConfiguredGuildMembership(esoGuildName, configuredMegaserver, currentMegaserver)
    if configuredMegaserver ~= currentMegaserver or type(esoGuildName) ~= "string"
        or esoGuildName == "" or not GetNumGuilds or not GetGuildId or not GetGuildName then
        return false
    end
    local expected = zo_strlower(esoGuildName)
    for guildIndex = 1, GetNumGuilds() do
        local guildId = GetGuildId(guildIndex)
        local guildName = guildId and GetGuildName(guildId) or nil
        if type(guildName) == "string" and zo_strlower(guildName) == expected then
            return true
        end
    end
    return false
end

function DS:GetAvailableGuildConfigurations(settlement)
    local snapshot = self:GetRecordsSnapshot()
    if type(snapshot) ~= "table"
        or (tonumber(snapshot.schemaVersion) ~= 1 and tonumber(snapshot.schemaVersion) ~= 2)
        or type(snapshot.guilds) ~= "table" or type(settlement) ~= "table" then
        return {}
    end

    local megaserver = GetWorldName and GetWorldName() or nil
    local zoneId = tonumber(settlement.zoneId)
    local completionTime = tonumber(settlement.completedAtTimeStamp)
        or tonumber(settlement.finalizedAtTimeStamp)
    if not megaserver or not zoneId or not completionTime then
        return {}
    end

    local availableGuilds = {}
    for _, guild in ipairs(snapshot.guilds) do
        local guildId = guild and guild.guildId
        local guildName = guild and guild.guildName
        local accessMode = guild and guild.accessMode or "public"
        local membershipValidated = guild and accessMode == "eso-members"
            and HasConfiguredGuildMembership(
                guild.esoGuildName, guild.megaserver, megaserver) or false
        local guildRouteAllowed = accessMode == "public" or membershipValidated
        if IsPublicIdentifier(guildId) and type(guildName) == "string"
            and guildName ~= "" and #guildName <= 80 and type(guild.events) == "table"
            and (accessMode == "public" or accessMode == "eso-members") then
            local availableEvents = {}
            for _, event in ipairs(guild.events) do
                local eventId = event and event.guildEventId
                local eventName = event and event.guildEventName
                local startsAt = event and tonumber(event.startsAt)
                local endsAt = event and tonumber(event.endsAt)
                local eventAccessMode = event and event.accessMode or "public"
                local eventMembershipValidated = eventAccessMode == "eso-members"
                    and HasConfiguredGuildMembership(
                        event.esoGuildName, event.accessMegaserver, megaserver) or false
                if IsPublicIdentifier(eventId) and type(eventName) == "string"
                    and eventName ~= "" and #eventName <= 80
                    and (eventAccessMode == "public" or eventAccessMode == "eso-members")
                    and (eventAccessMode == "public" or eventMembershipValidated)
                    and (not event.megaserver or event.megaserver == megaserver)
                    and (not startsAt or completionTime >= startsAt)
                    and (not endsAt or completionTime <= endsAt)
                    and EventIncludesZone(event, zoneId) then
                    availableEvents[#availableEvents + 1] = {
                        guildId = guildId,
                        guildName = guildName,
                        guildEventId = eventId,
                        guildEventName = eventName,
                        guildRecordsEnabled = guild.recordsEnabled == true,
                        guildRouteAllowed = guildRouteAllowed,
                        guildMembershipValidated = membershipValidated,
                        accessMode = eventAccessMode,
                        eventMembershipValidated = eventAccessMode == "public"
                            or eventMembershipValidated,
                        isGlobal = eventAccessMode == "public",
                    }
                end
            end
            local recordsEnabled = guild.recordsEnabled == true
            table.sort(availableEvents, function(left, right)
                return zo_strlower(left.guildEventName) < zo_strlower(right.guildEventName)
            end)
            if guildRouteAllowed or #availableEvents > 0 then
                availableGuilds[#availableGuilds + 1] = {
                    guildId = guildId,
                    guildName = guildName,
                    recordsEnabled = recordsEnabled,
                    accessMode = accessMode,
                    esoGuildName = guild.esoGuildName,
                    megaserver = guild.megaserver,
                    guildRouteAllowed = guildRouteAllowed,
                    guildMembershipValidated = accessMode == "public"
                        or membershipValidated,
                    events = availableEvents,
                }
            end
        end
    end
    table.sort(availableGuilds, function(left, right)
        return zo_strlower(left.guildName) < zo_strlower(right.guildName)
    end)
    return availableGuilds
end

function DS:GetAvailableGuildEvents(settlement, selectedGuildId)
    local available = {}
    for _, guild in ipairs(self:GetAvailableGuildConfigurations(settlement)) do
        if selectedGuildId == nil or guild.guildId == selectedGuildId then
            for _, event in ipairs(guild.events) do
                if selectedGuildId ~= nil or event.isGlobal == true then
                    available[#available + 1] = event
                end
            end
        end
    end
    table.sort(available, function(left, right)
        local leftKey = zo_strlower(tostring(left.guildName or "") .. "\0"
            .. tostring(left.guildEventName or ""))
        local rightKey = zo_strlower(tostring(right.guildName or "") .. "\0"
            .. tostring(right.guildEventName or ""))
        return leftKey < rightKey
    end)
    return available
end

local function GetFeaturedGuildDirectoryEvent(guild, megaserver, currentTime)
    local current = nil
    local upcoming = nil
    for _, event in ipairs(type(guild.events) == "table" and guild.events or {}) do
        local accessMode = event and event.accessMode or "public"
        local accessible = accessMode == "public"
            or (accessMode == "eso-members" and HasConfiguredGuildMembership(
                event.esoGuildName, event.accessMegaserver, megaserver))
        local startsAt = event and tonumber(event.startsAt)
        local endsAt = event and tonumber(event.endsAt)
        if event and IsPublicIdentifier(event.guildEventId)
            and type(event.guildEventName) == "string" and event.guildEventName ~= ""
            and (accessMode == "public" or accessMode == "eso-members")
            and accessible
            and (not event.megaserver or event.megaserver == megaserver)
            and (not endsAt or endsAt >= currentTime) then
            local candidate = {
                guildEventId = event.guildEventId,
                guildEventName = event.guildEventName,
                startsAt = startsAt,
                endsAt = endsAt,
                zoneIds = type(event.zoneIds) == "table" and event.zoneIds or {},
                accessMode = accessMode,
                isCurrent = not startsAt or startsAt <= currentTime,
            }
            if candidate.isCurrent then
                if not current or (startsAt or 0) > (current.startsAt or 0) then
                    current = candidate
                end
            elseif not upcoming or startsAt < upcoming.startsAt then
                upcoming = candidate
            end
        end
    end
    return current or upcoming
end

function DS:GetGuildDirectoryEntries()
    local snapshot = self:GetRecordsSnapshot()
    if type(snapshot) ~= "table"
        or (tonumber(snapshot.schemaVersion) ~= 1 and tonumber(snapshot.schemaVersion) ~= 2)
        or type(snapshot.guilds) ~= "table" then
        return {}
    end
    local megaserver = GetWorldName and GetWorldName() or nil
    local currentTime = GetTimeStamp and GetTimeStamp() or 0
    local entries = {}
    for _, guild in ipairs(snapshot.guilds) do
        local mode = guild and guild.recruitmentMode or "off"
        local server = guild and guild.recruitmentMegaserver or nil
        if guild and IsPublicIdentifier(guild.guildId)
            and type(guild.guildName) == "string" and guild.guildName ~= ""
            and (mode == "eso-guild" or mode == "discord-server" or mode == "both")
            and type(guild.recruitmentCopy) == "string"
            and guild.recruitmentCopy ~= "" and #guild.recruitmentCopy <= 300
            and type(guild.recruitmentContact) == "string"
            and guild.recruitmentContact ~= "" and #guild.recruitmentContact <= 120
            and ((mode == "discord-server")
                or (type(guild.recruitmentGuildLink) == "string"
                    and #guild.recruitmentGuildLink <= 180
                    and guild.recruitmentGuildLink:match(
                        "^|H1:guild:%d+|h[^|\r\n]+|h$")))
            and (server == nil or server == megaserver) then
            entries[#entries + 1] = {
                guildId = guild.guildId,
                guildName = guild.guildName,
                recruitmentMode = mode,
                recruitmentCopy = guild.recruitmentCopy,
                recruitmentContact = guild.recruitmentContact,
                recruitmentGuildLink = guild.recruitmentGuildLink,
                recruitmentMegaserver = server,
                featuredEvent = GetFeaturedGuildDirectoryEvent(
                    guild, megaserver, currentTime),
            }
        end
    end
    table.sort(entries, function(left, right)
        return zo_strlower(left.guildName) < zo_strlower(right.guildName)
    end)
    return entries
end

local function Trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$") or ""
end

function Util.NormalizePublicationTeamName(value)
    local name = Trim(value):gsub("%s+", " ")
    if name == "" or #name > 80 then
        return nil
    end
    return name, zo_strlower(name)
end

function Util.NormalizePublicationAccountName(value)
    local accountName = Trim(value)
    if #accountName < 2 or #accountName > 64 or accountName:sub(1, 1) ~= "@"
        or accountName:find("[%s,;|]") then
        return nil
    end
    return accountName, zo_strlower(accountName)
end

local function SameStringArray(left, right)
    if #left ~= #right then
        return false
    end
    for index = 1, #left do
        if left[index] ~= right[index] then
            return false
        end
    end
    return true
end

function Util.ParsePublicationTeamRegistry(registryText)
    local teams = {}
    local errors = {}
    local seenTeamKeys = {}
    local lineNumber = 0

    registryText = tostring(registryText or "")
    for rawLine in (registryText .. "\n"):gmatch("(.-)\r?\n") do
        lineNumber = lineNumber + 1
        local line = Trim(rawLine)
        if line ~= "" then
            local rawName, rawMembers = line:match("^(.-)%s*|%s*(.-)$")
            local name, nameKey = Util.NormalizePublicationTeamName(rawName)
            local members = {}
            local memberKeys = {}
            local seenMembers = {}
            local valid = name ~= nil and rawMembers ~= nil

            if valid then
                for token in rawMembers:gmatch("[^,%s;]+") do
                    local member, memberKey = Util.NormalizePublicationAccountName(token)
                    if not member or seenMembers[memberKey] then
                        valid = false
                        break
                    end
                    seenMembers[memberKey] = true
                    members[#members + 1] = member
                    memberKeys[#memberKeys + 1] = memberKey
                end
            end
            if #members < 1 or #members > 4 then
                valid = false
            end

            if valid then
                local paired = {}
                for index = 1, #members do
                    paired[#paired + 1] = { display = members[index], key = memberKeys[index] }
                end
                table.sort(paired, function(left, right)
                    return left.key < right.key
                end)
                members = {}
                memberKeys = {}
                for index, member in ipairs(paired) do
                    members[index] = member.display
                    memberKeys[index] = member.key
                end

                local teamKey = nameKey .. "|" .. table.concat(memberKeys, ",")
                if not seenTeamKeys[teamKey] then
                    seenTeamKeys[teamKey] = true
                    teams[#teams + 1] = {
                        name = name,
                        nameKey = nameKey,
                        members = members,
                        memberKeys = memberKeys,
                        teamKey = teamKey,
                    }
                end
            else
                errors[#errors + 1] = lineNumber
            end
        end
    end

    return teams, errors
end

function Util.SerializePublicationTeamRegistry(teams)
    local lines = {}
    for _, team in ipairs(teams or {}) do
        if team.name and type(team.members) == "table" and #team.members > 0 then
            lines[#lines + 1] = team.name .. " | " .. table.concat(team.members, ", ")
        end
    end
    return table.concat(lines, "\n")
end

local function PublicationRosterKeys(groupMembers)
    local rosterKeys = {}
    local seenRosterMembers = {}
    for _, member in ipairs(groupMembers or {}) do
        local accountName = type(member) == "table" and member.accountName or member
        local _, memberKey = Util.NormalizePublicationAccountName(accountName)
        if memberKey and not seenRosterMembers[memberKey] then
            seenRosterMembers[memberKey] = true
            rosterKeys[#rosterKeys + 1] = memberKey
        end
    end
    table.sort(rosterKeys)
    return rosterKeys
end

function Util.GetMatchingPublicationTeams(publicationTeams, groupMembers)
    publicationTeams = type(publicationTeams) == "table" and publicationTeams or {}
    local teams = Util.ParsePublicationTeamRegistry(publicationTeams.registryText)
    local rosterKeys = PublicationRosterKeys(groupMembers)
    local matches = {}
    if #rosterKeys == 0 then
        return matches
    end
    for _, team in ipairs(teams) do
        if SameStringArray(team.memberKeys, rosterKeys) then
            matches[#matches + 1] = Util.DeepCopy(team)
        end
    end
    return matches
end

function Util.ResolvePublicationTeam(publicationTeams, groupMembers)
    publicationTeams = type(publicationTeams) == "table" and publicationTeams or {}
    local matches = Util.GetMatchingPublicationTeams(publicationTeams, groupMembers)
    if #matches == 0 then
        return nil, "none"
    end
    if #matches == 1 then
        return Util.DeepCopy(matches[1]), "matched"
    end

    local _, preferredKey = Util.NormalizePublicationTeamName(publicationTeams.preferredTeamName)
    if preferredKey then
        local preferredMatch = nil
        for _, team in ipairs(matches) do
            if team.nameKey == preferredKey then
                if preferredMatch then
                    return nil, "ambiguous"
                end
                preferredMatch = team
            end
        end
        if preferredMatch then
            return Util.DeepCopy(preferredMatch), "matched-preferred"
        end
    end
    return nil, "ambiguous"
end

local function SameSettlementRun(left, right)
    if type(left) ~= "table" or type(right) ~= "table" then
        return false
    end
    return tonumber(left.runId) == tonumber(right.runId)
        and tonumber(left.zoneId) == tonumber(right.zoneId)
        and tonumber(left.completedAtTimeStamp or left.finalizedAtTimeStamp)
            == tonumber(right.completedAtTimeStamp or right.finalizedAtTimeStamp)
end

local function PublicationTeamSnapshot(settlement)
    if type(settlement) ~= "table"
        or type(settlement.publicationTeamName) ~= "string"
        or type(settlement.publicationTeamMembers) ~= "table" then
        return nil
    end

    local teamName, teamNameKey = Util.NormalizePublicationTeamName(
        settlement.publicationTeamName)
    if not teamName then
        return nil
    end

    local members = {}
    local memberKeys = {}
    local seenMembers = {}
    for _, value in ipairs(settlement.publicationTeamMembers) do
        local member, memberKey = Util.NormalizePublicationAccountName(value)
        if not member or seenMembers[memberKey] then
            return nil
        end
        seenMembers[memberKey] = true
        members[#members + 1] = member
        memberKeys[#memberKeys + 1] = memberKey
    end
    if #members < 1 or #members > 4 then
        return nil
    end

    local paired = {}
    for index = 1, #members do
        paired[#paired + 1] = { display = members[index], key = memberKeys[index] }
    end
    table.sort(paired, function(left, right)
        return left.key < right.key
    end)
    members = {}
    memberKeys = {}
    for index, member in ipairs(paired) do
        members[index] = member.display
        memberKeys[index] = member.key
    end

    return {
        name = teamName,
        nameKey = teamNameKey,
        members = members,
        memberKeys = memberKeys,
        teamKey = teamNameKey .. "|" .. table.concat(memberKeys, ","),
    }
end

local function ApplyToSettlementViews(owner, settlement, apply)
    apply(settlement)
    for _, historySettlement in ipairs(owner.saved and owner.saved.history or {}) do
        if SameSettlementRun(historySettlement, settlement) then
            apply(historySettlement)
        end
    end
    for _, highScoreSettlement in pairs(owner.saved and owner.saved.highScores or {}) do
        if SameSettlementRun(highScoreSettlement, settlement) then
            apply(highScoreSettlement)
        end
    end
    for _, bySize in pairs(owner.saved and owner.saved.highScoresByParty or {}) do
        if type(bySize) == "table" then
            for _, partySettlement in pairs(bySize) do
                if SameSettlementRun(partySettlement, settlement) then
                    apply(partySettlement)
                end
            end
        end
    end
end

-- Changing publication targets after one queue request is intentional: each
-- distinct target may be submitted independently from the same finalized run.
function DS:SetPublicationRaceToBottomRequested(settlement, requested)
    if type(settlement) ~= "table" or settlement.scoreSessionOpen ~= false then
        return false
    end
    -- Earlier beta settlements folded the abandonment deduction into finalScore
    -- and have no independent RTB projection. They cannot be safely published
    -- through the current schema. Allow a stale opt-in to be turned off.
    if requested == true and tonumber(settlement.raceToBottomScore) == nil then
        return false
    end
    ApplyToSettlementViews(self, settlement, function(target)
        target.publicationRaceToBottomRequested = requested == true
    end)
    return true
end

function DS:AssignPublicationTeamToRun(settlement, team)
    if type(settlement) ~= "table" or type(team) ~= "table" then
        return false, "invalid"
    end
    if self:IsSettlementQueuedForPublication(settlement) then
        return false, "already-queued"
    end
    local matches = Util.GetMatchingPublicationTeams(self.saved and self.saved.publicationTeams,
        settlement.groupMembers)
    local selectedTeam = nil
    for _, candidate in ipairs(matches) do
        if candidate.teamKey == team.teamKey then
            selectedTeam = candidate
            break
        end
    end
    if not selectedTeam then
        return false, "roster-mismatch"
    end

    local function Apply(target)
        target.publicationTeamName = selectedTeam.name
        target.publicationTeamMembers = Util.DeepCopy(selectedTeam.members)
        target.publicationTeamResolution = "assigned"
    end
    ApplyToSettlementViews(self, settlement, Apply)
    return true, selectedTeam
end

function DS:AssignPublicationGuildToRun(settlement, guild)
    if type(settlement) ~= "table" or type(guild) ~= "table" then
        return false, "invalid"
    end
    if not PublicationTeamSnapshot(settlement) then
        return false, "no-team"
    end
    local selectedGuild = nil
    for _, candidate in ipairs(self:GetAvailableGuildConfigurations(settlement)) do
        if candidate.guildId == guild.guildId then
            selectedGuild = candidate
            break
        end
    end
    if not selectedGuild then
        return false, "guild-unavailable"
    end
    ApplyToSettlementViews(self, settlement, function(target)
        target.publicationGuildId = selectedGuild.guildId
        target.publicationGuildName = selectedGuild.guildName
        target.publicationGuildRecordsEnabled = selectedGuild.recordsEnabled == true
            and selectedGuild.guildRouteAllowed == true
        target.publicationGuildRecordsRequested = selectedGuild.recordsEnabled == true
            and selectedGuild.guildRouteAllowed == true
        target.publicationGuildMembershipValidated = selectedGuild.guildMembershipValidated == true
        target.publicationGuildEventId = nil
        target.publicationGuildEventName = nil
        target.publicationEventMembershipValidated = nil
    end)
    return true, selectedGuild
end

function DS:AssignPublicationEventToRun(settlement, guildEvent)
    if type(settlement) ~= "table" or type(guildEvent) ~= "table" then
        return false, "invalid"
    end
    if not PublicationTeamSnapshot(settlement) then
        return false, "no-team"
    end
    local selectedEvent = nil
    for _, candidate in ipairs(self:GetAvailableGuildEvents(
        settlement, settlement.publicationGuildId)) do
        if candidate.guildEventId == guildEvent.guildEventId then
            selectedEvent = candidate
            break
        end
    end
    if not selectedEvent then
        return false, "event-unavailable"
    end
    ApplyToSettlementViews(self, settlement, function(target)
        local preserveGuildRecords = target.publicationGuildId == selectedEvent.guildId
            and target.publicationGuildRecordsRequested == true
        target.publicationGuildId = selectedEvent.guildId
        target.publicationGuildName = selectedEvent.guildName
        target.publicationGuildRecordsEnabled = selectedEvent.guildRecordsEnabled == true
            and selectedEvent.guildRouteAllowed == true
        target.publicationGuildRecordsRequested = preserveGuildRecords
            and target.publicationGuildRecordsEnabled == true
        target.publicationGuildMembershipValidated =
            selectedEvent.guildMembershipValidated == true
        target.publicationGuildEventId = selectedEvent.guildEventId
        target.publicationGuildEventName = selectedEvent.guildEventName
        target.publicationEventMembershipValidated =
            selectedEvent.eventMembershipValidated == true
    end)
    return true, selectedEvent
end

function DS:ClearPublicationGuildFromRun(settlement)
    if type(settlement) ~= "table" then
        return false, "invalid"
    end
    ApplyToSettlementViews(self, settlement, function(target)
        target.publicationGuildId = nil
        target.publicationGuildName = nil
        target.publicationGuildRecordsEnabled = nil
        target.publicationGuildRecordsRequested = nil
        target.publicationGuildMembershipValidated = nil
        target.publicationGuildEventId = nil
        target.publicationGuildEventName = nil
        target.publicationEventMembershipValidated = nil
    end)
    return true
end

function DS:ClearPublicationEventFromRun(settlement)
    if type(settlement) ~= "table" then
        return false, "invalid"
    end
    ApplyToSettlementViews(self, settlement, function(target)
        target.publicationGuildEventId = nil
        target.publicationGuildEventName = nil
        target.publicationEventMembershipValidated = nil
    end)
    return true
end

function DS:GetPublicationQueueKey(settlement, sourceMegaserver)
    local team = PublicationTeamSnapshot(settlement)
    local megaserver = sourceMegaserver or (GetWorldName and GetWorldName() or nil)
    local abandoned = settlement and settlement.runOutcome == "abandoned"
    local completionTime = tonumber(settlement and settlement.completedAtTimeStamp)
        or tonumber(settlement and settlement.finalizedAtTimeStamp)
    if not team or not megaserver or megaserver == "" or not completionTime then
        return nil
    end
    local parts = {
        team.teamKey,
        zo_strlower(tostring(megaserver)),
        tostring(tonumber(settlement.zoneId) or 0),
        tostring(math.floor(completionTime)),
    }
    if not abandoned and settlement.publicationGuildId then
        parts[#parts + 1] = "guild:" .. tostring(settlement.publicationGuildId)
        parts[#parts + 1] = "guild-records:"
            .. (settlement.publicationGuildRecordsRequested == true and "1" or "0")
    end
    if not abandoned and settlement.publicationGuildEventId then
        parts[#parts + 1] = "event:" .. tostring(settlement.publicationGuildEventId)
    end
    -- Opt-in Race to the Bottom is an independent publication route.
    if settlement.publicationRaceToBottomRequested == true then
        parts[#parts + 1] = "race-to-bottom:1"
    end
    return table.concat(parts, "|")
end

function DS:GetPublicationEligibility(settlement)
    if type(settlement) ~= "table" then
        return false, "no-selection"
    end
    if settlement.scoreSessionOpen ~= false then
        return false, "not-finalized"
    end
    if settlement.publicationRaceToBottomRequested == true
        and tonumber(settlement.raceToBottomScore) == nil then
        return false, "ineligible"
    end
    local runOutcome = tostring(settlement.runOutcome or "completed")
    local abandoned = runOutcome == "abandoned"
    if settlement.isVeteran ~= true then
        return false, "ineligible"
    end
    if abandoned then
        -- No ordinary WR is possible for an abandoned run; publication here
        -- is only valid as an explicit Race to the Bottom request.
        if settlement.publicationRaceToBottomRequested ~= true then
            return false, "race-to-bottom-not-selected"
        end
        local progressFloor = tonumber(settlement.minimumCredibleBossKills) or 1
        if settlement.competitiveEligible ~= false
            or settlement.integrityStatus ~= "abandoned"
            or settlement.raceToBottomEligible ~= true
            or progressFloor < 1
            or (tonumber(settlement.bossKills) or 0) < progressFloor
            or settlement.completedAtTimeStamp ~= nil
            or not tonumber(settlement.finalizedAtTimeStamp) then
            return false, "ineligible"
        end
    elseif runOutcome ~= "completed"
        or settlement.competitiveEligible ~= true
        or settlement.integrityStatus ~= "full" then
        return false, "ineligible"
    end
    if not PublicationTeamSnapshot(settlement) then
        if settlement.publicationTeamResolution == "ambiguous" then
            return false, "ambiguous-team"
        end
        return false, "no-team"
    end
    if not abandoned and settlement.publicationGuildId ~= nil
        and not IsPublicIdentifier(settlement.publicationGuildId) then
        return false, "incomplete"
    end
    if not abandoned and settlement.publicationGuildEventId ~= nil
        and not IsPublicIdentifier(settlement.publicationGuildEventId) then
        return false, "incomplete"
    end
    if not abandoned and settlement.publicationGuildEventId ~= nil
        and settlement.publicationGuildId == nil then
        return false, "incomplete"
    end
    if not abandoned and settlement.publicationGuildRecordsRequested == true
        and settlement.publicationGuildId == nil then
        return false, "incomplete"
    end
    if not abandoned and settlement.publicationGuildId ~= nil
        and settlement.publicationGuildEventId == nil
        and settlement.publicationGuildRecordsRequested ~= true then
        return false, "guild-route-unavailable"
    end
    if not self:GetPublicationQueueKey(settlement)
        or not tonumber(settlement.runId)
        or not tonumber(settlement.zoneId)
        or not tonumber(settlement.elapsedMs)
        or not tonumber(settlement.finalScore) then
        return false, "incomplete"
    end
    return true, "eligible"
end

function DS:GetQueuedPublicationRequest(settlement)
    local queueKey = self:GetPublicationQueueKey(settlement)
    if not queueKey then
        return nil
    end
    for _, request in ipairs(self.saved and self.saved.publicationQueue or {}) do
        if request.queueKey == queueKey then
            return request
        end
        -- Keep old queue keys byte-for-byte: the companion uses them as sent
        -- receipts. Compare their explicit payload without rewriting/requeuing.
        local payload = request.payload
        if type(payload) == "table" and type(payload.megaserver) == "string"
            and self:GetPublicationQueueKey({
                publicationTeamName = payload.teamName,
                publicationTeamMembers = payload.teamMembers,
                zoneId = payload.zoneId,
                completedAtTimeStamp = payload.completedAtTimeStamp,
                finalizedAtTimeStamp = payload.finalizedAtTimeStamp,
                runOutcome = payload.runOutcome,
                publicationGuildId = payload.guildId,
                publicationGuildEventId = payload.guildEventId,
                publicationGuildRecordsRequested = payload.guildRecordsRequested,
                publicationRaceToBottomRequested = payload.raceToBottomRequested,
            }, payload.megaserver) == queueKey then
            return request
        end
    end
    return nil
end

function DS:IsSettlementQueuedForPublication(settlement)
    return self:GetQueuedPublicationRequest(settlement) ~= nil
end

function DS:QueueSettlementForPublication(settlement)
    local eligible, reason = self:GetPublicationEligibility(settlement)
    if not eligible then
        return false, reason
    end
    if self:IsSettlementQueuedForPublication(settlement) then
        return false, "already-queued"
    end

    local team = PublicationTeamSnapshot(settlement)
    local queueKey = self:GetPublicationQueueKey(settlement)
    self.saved.publicationQueue = self.saved.publicationQueue or {}
    self.saved.nextPublicationRequestId = (tonumber(self.saved.nextPublicationRequestId) or 0) + 1

    local request = {
        schemaVersion = 1,
        requestId = self.saved.nextPublicationRequestId,
        queueKey = queueKey,
        queuedAtTimeStamp = GetTimeStamp(),
        payload = {
            schemaVersion = settlement.raceToBottomScore ~= nil and 3 or 1,
            megaserver = GetWorldName(),
            addonVersion = tostring(settlement.addonVersion or self.VERSION),
            runId = tonumber(settlement.runId),
            zoneId = tonumber(settlement.zoneId),
            zoneName = tostring(settlement.zoneName or ""),
            teamName = team.name,
            teamMembers = Util.DeepCopy(team.members),
            guildId = settlement.runOutcome ~= "abandoned"
                and settlement.publicationGuildId or nil,
            guildEventId = settlement.runOutcome ~= "abandoned"
                and settlement.publicationGuildEventId or nil,
            guildRecordsRequested = settlement.runOutcome ~= "abandoned"
                and settlement.publicationGuildRecordsRequested == true,
            guildMembershipValidated = settlement.runOutcome ~= "abandoned"
                and settlement.publicationGuildMembershipValidated == true,
            eventMembershipValidated = settlement.runOutcome ~= "abandoned"
                and settlement.publicationEventMembershipValidated == true,
            submitterAccount = tostring(GetDisplayName() or ""),
            runOutcome = tostring(settlement.runOutcome or "completed"),
            raceToBottomEligible = settlement.raceToBottomEligible == true,
            -- Contract addition; Work must honor this opt-in on the Worker.
            raceToBottomRequested = settlement.publicationRaceToBottomRequested == true,
            minimumCredibleBossKills = tonumber(settlement.minimumCredibleBossKills),
            bossKills = tonumber(settlement.bossKills) or 0,
            isVeteran = settlement.isVeteran == true,
            scoreSessionOpen = settlement.scoreSessionOpen == true,
            competitiveEligible = settlement.competitiveEligible == true,
            integrityStatus = tostring(settlement.integrityStatus or ""),
            completedAtTimeStamp = tonumber(settlement.completedAtTimeStamp),
            finalizedAtTimeStamp = tonumber(settlement.finalizedAtTimeStamp),
            elapsedMs = tonumber(settlement.elapsedMs),
            runGroupSize = tonumber(settlement.runGroupSize),
            partyAverageGroupSize = tonumber(settlement.partyAverageGroupSize),
            deaths = tonumber(settlement.deathsAtCompletion) or tonumber(settlement.deaths) or 0,
            hmBossKills = tonumber(settlement.hmBossKills) or 0,
            expectedHardModes = tonumber(settlement.expectedHardModes),
            trifectaQualified = settlement.trifectaQualified == true,
            veteranBase = tonumber(settlement.veteranBase) or 0,
            killScore = tonumber(settlement.killScore) or 0,
            hmScore = tonumber(settlement.hmScore) or 0,
            speedBonus = tonumber(settlement.speedBonus) or 0,
            additionalSpeedBonus = tonumber(settlement.additionalSpeedBonus) or 0,
            noDeathBonus = tonumber(settlement.noDeathBonus) or 0,
            trifectaBonus = tonumber(settlement.trifectaBonus) or 0,
            vitalityScore = tonumber(settlement.vitalityScore) or 0,
            tempoScore = tonumber(settlement.tempoScore) or 0,
            partyChallengeScore = tonumber(settlement.partyChallengeScore) or 0,
            coefficient = tonumber(settlement.coefficient),
            finalScore = tonumber(settlement.finalScore),
        },
    }
    -- Keep both projections in the saved settlement, but do not export RTB
    -- evidence or deductions in an ordinary publication request.
    if settlement.publicationRaceToBottomRequested == true
        or settlement.raceToBottomScore == nil then
        local payload = request.payload
        payload.abandonmentPenalty = tonumber(settlement.abandonmentPenalty) or 0
        payload.abandonedHardModeCount = tonumber(settlement.abandonedHardModeCount) or 0
        payload.abandonedHardModeScore = tonumber(settlement.abandonedHardModeScore) or 0
        payload.companionObserved = settlement.companionObserved == true
        payload.companionPenalty = tonumber(settlement.companionPenalty) or 0
        payload.pitstopObserved = settlement.pitstopObserved == true
        payload.pitstopPenalty = tonumber(settlement.pitstopPenalty) or 0
        if settlement.raceToBottomScore ~= nil then
            payload.raceToBottomScore = tonumber(settlement.raceToBottomScore)
        end
    end
    self.saved.publicationQueue[#self.saved.publicationQueue + 1] = request
    while #self.saved.publicationQueue > self.MAX_PUBLICATION_QUEUE do
        table.remove(self.saved.publicationQueue, 1)
    end
    return true, request
end

function DS:Chat(message)
    d(Util.FormatString(SI_DUNGEON_SCORES_CHAT_PREFIX, tostring(message)))
end
