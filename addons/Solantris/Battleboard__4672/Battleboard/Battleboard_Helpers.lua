-- Battleboard_Helpers.lua  (shared helper functions and computed layout exports)
-- Part of Battleboard. Loaded after Core state and before feature modules.

local BL = Battleboard
BL.__constants = BL.__constants or {}
local _x = BL.__constants

local LMM = _x.LMM
local LAM = _x.LAM

local DEFAULT_SCENE_HISTORY = _x.DEFAULT_SCENE_HISTORY
local DEFAULT_SCENE_METRICS = _x.DEFAULT_SCENE_METRICS
local DEFAULT_SCENE_OBSERVATORY = _x.DEFAULT_SCENE_OBSERVATORY

local BG_ICON = _x.BG_ICON
local BG_ICON_DOWN = _x.BG_ICON_DOWN
local BG_ICON_OVER = _x.BG_ICON_OVER

-- Page-tab icon states. The header tab now swaps textures
-- directly instead of moving on hover or using a selected underline.
local MATCH_HISTORY_ICON = _x.MATCH_HISTORY_ICON
local MATCH_HISTORY_ICON_DOWN = _x.MATCH_HISTORY_ICON_DOWN
local MATCH_HISTORY_ICON_OVER = _x.MATCH_HISTORY_ICON_OVER
local MATCH_HISTORY_ICON_SELECTED = _x.MATCH_HISTORY_ICON_SELECTED

local STATS_ICON = _x.STATS_ICON
local STATS_ICON_DOWN = _x.STATS_ICON_DOWN
local STATS_ICON_OVER = _x.STATS_ICON_OVER
local STATS_ICON_SELECTED = _x.STATS_ICON_SELECTED

local OBSERVATORY_ICON = _x.OBSERVATORY_ICON
local OBSERVATORY_ICON_DOWN = _x.OBSERVATORY_ICON_DOWN
local OBSERVATORY_ICON_OVER = _x.OBSERVATORY_ICON_OVER

-- Static addon menu icon. Use the Battlegrounds tab icon so the menu entry matches the addon's purpose.
local MENU_ICON = _x.MENU_ICON
local MENU_ICON_DOWN = _x.MENU_ICON_DOWN
local MENU_ICON_OVER = _x.MENU_ICON_OVER
local BLANK_ICON = _x.BLANK_ICON

-- Team block logos - the 64px battleground team icons.
-- These are also used in the player table team column and the outcome banner indicator.
local TEAM_ICON_FIRE_DRAKES = _x.TEAM_ICON_FIRE_DRAKES
local TEAM_ICON_PIT_DAEMONS = _x.TEAM_ICON_PIT_DAEMONS
local TEAM_ICON_STORM_LORDS = _x.TEAM_ICON_STORM_LORDS

-- Player table uses the compact round battleground team markers.
local PLAYER_TABLE_TEAM_ICON_FIRE_DRAKES = _x.PLAYER_TABLE_TEAM_ICON_FIRE_DRAKES
local PLAYER_TABLE_TEAM_ICON_PIT_DAEMONS = _x.PLAYER_TABLE_TEAM_ICON_PIT_DAEMONS
local PLAYER_TABLE_TEAM_ICON_STORM_LORDS = _x.PLAYER_TABLE_TEAM_ICON_STORM_LORDS

-- Outcome banner uses the saved match result.
local OUTCOME_BANNER_RESULT_ICON_WIN = _x.OUTCOME_BANNER_RESULT_ICON_WIN
local OUTCOME_BANNER_RESULT_ICON_LOSS = _x.OUTCOME_BANNER_RESULT_ICON_LOSS
local OUTCOME_BANNER_RESULT_ICON_TIE = _x.OUTCOME_BANNER_RESULT_ICON_TIE

-- Team indicator banner: one icon centred above the victory/defeat text,
-- representing the local player's team for that saved match.
local TEAM_INDICATOR_BANNER_FIRE_DRAKES = _x.TEAM_INDICATOR_BANNER_FIRE_DRAKES
local TEAM_INDICATOR_BANNER_PIT_DAEMONS = _x.TEAM_INDICATOR_BANNER_PIT_DAEMONS
local TEAM_INDICATOR_BANNER_STORM_LORDS = _x.TEAM_INDICATOR_BANNER_STORM_LORDS

local PLAYER_TABLE_TEAM_HEADER_ICON = _x.PLAYER_TABLE_TEAM_HEADER_ICON

local SORT_ICON_UP = _x.SORT_ICON_UP
local SORT_ICON_DOWN = _x.SORT_ICON_DOWN

local ALL_CHARACTERS_KEY = _x.ALL_CHARACTERS_KEY

local classIcons = _x.classIcons

local allianceOrder = _x.allianceOrder

local allianceNames = _x.allianceNames

local allianceTeamIcons = _x.allianceTeamIcons

local playerTableTeamIcons = _x.playerTableTeamIcons

local teamIndicatorBanners = _x.teamIndicatorBanners

local allianceColours = _x.allianceColours

local function GetTeamSummaryIcon(alliance)
    -- Prefer explicit Battleboard team icons so saved and live battleground displays
    -- stay visually consistent across clients.
    local icon = allianceTeamIcons[alliance]
    if icon and icon ~= "" then return icon end

    return BLANK_ICON
end

local function GetPlayerTableTeamIcon(alliance)
    local icon = playerTableTeamIcons[alliance]
    if icon and icon ~= "" then return icon end
    return GetTeamSummaryIcon(alliance)
end

local function GetTeamIndicatorBanner(alliance)
    alliance = tonumber(alliance) or 0
    local icon = teamIndicatorBanners[alliance]
    if icon and icon ~= "" then return icon end
    return nil
end

local function GetOutcomeBannerResultIcon(match)
    -- This helper is declared before GetPlayerResultText(), so read the saved
    -- result field directly instead of calling that later local function.
    local result = match and match.playerResult or nil
    if result == "Win" then
        return OUTCOME_BANNER_RESULT_ICON_WIN
    elseif result == "Loss" then
        return OUTCOME_BANNER_RESULT_ICON_LOSS
    elseif result == "Tie" or result == "Draw" then
        return OUTCOME_BANNER_RESULT_ICON_TIE
    end
    return OUTCOME_BANNER_RESULT_ICON_TIE
end

local function Num(value)
    return tonumber(value) or 0
end

local MAX_LOCKED_MATCHES = _x.MAX_LOCKED_MATCHES

-- Timestamps are stored and compared as raw GetTimeStamp() values. ESO already returns
-- GetTimeStamp() as a server (UTC) Unix epoch in seconds, so no timezone reconstruction is
-- needed. The previous GetServerTimestamp() conversion (rebuilding a timestamp from
-- GetGlobalTimeOfDay/GetLocalTimeOfDay) was removed because it could shift a match by a full
-- day when a clock read failed, corrupting match-history sort order.

local function FormatMatchId(matchOrId)
    local id = matchOrId
    if type(matchOrId) == "table" then
        id = matchOrId.id
    end

    if type(id) == "string" and tonumber(id) == nil then
        return id
    end

    id = math.floor(Num(id))
    if id < 0 then id = 0 end

    -- Keep old numeric admin/test records readable without using the old counter.
    local s = string.format("%06d", id)
    return s:sub(1, 3) .. " " .. s:sub(4)
end

local function GetCurrentClassIcon()
    local classId = tonumber(GetUnitClassId("player")) or 0
    return classIcons[classId] or BG_ICON
end

-- Older 4v4v4 BGs used three fixed battleground alliances. Modern 4v4/8v8
-- battlegrounds should enumerate active teams from the battleground definition
-- rather than assuming team ids are sequential or discovering them from player rows.
local function FireAlliance() return 1 end
local function PitAlliance() return 2 end
local function StormAlliance() return 3 end

-- Bug #7 fix: forward-declare the canonical filter-key helpers here so
-- GetSelectedCharacterWinRate (and any other early local function) can call them
-- without duplicating the logic. The implementations follow later in the file.
local GetGameTypeFilterKey
local GetMatchTypeFilterKey

local function AddUniqueAlliance(list, seen, alliance)
    alliance = tonumber(alliance) or 0
    if alliance > 0 and not seen[alliance] then
        seen[alliance] = true
        list[#list + 1] = alliance
    end
end

local function GetLegacyAllianceList()
    return { FireAlliance(), PitAlliance(), StormAlliance() }
end

local function GetCurrentBattlegroundTeamList()
    local list, seen = {}, {}
    local bgId = GetCurrentBattlegroundId() or 0
    local numTeams = Num(GetBattlegroundNumTeams(bgId))

    if bgId > 0 and numTeams > 0 then
        for i = 1, numTeams do
            AddUniqueAlliance(list, seen, GetBattlegroundTeamByIndex(bgId, i))
        end
    end

    -- Compatibility fallback for clients where GetBattlegroundTeamByIndex is
    -- unavailable or returns nothing. This is only a fallback, not the primary path.
    if #list == 0 and numTeams > 0 then
        for team = 1, numTeams do
            AddUniqueAlliance(list, seen, team)
        end
    end

    -- Last compatibility fallback if the battleground definition returns no teams.
    if #list == 0 then
        AddUniqueAlliance(list, seen, GetUnitBattlegroundTeam("player"))
    end

    table.sort(list, function(a, b) return a < b end)
    return list
end

local function GetAllianceList(scores, players)
    local list, seen = {}, {}

    -- Saved-match display should use the teams stored on that saved match.
    if players then
        for _, player in ipairs(players) do
            AddUniqueAlliance(list, seen, player and player.alliance)
        end
    end

    if scores then
        for alliance, _ in pairs(scores) do
            AddUniqueAlliance(list, seen, alliance)
        end
    end

    -- Save-time/current-BG use with no saved data: ask the BG definition for
    -- the active teams via GetBattlegroundTeamByIndex.
    if #list == 0 and not scores and not players then
        for _, team in ipairs(GetCurrentBattlegroundTeamList()) do
            AddUniqueAlliance(list, seen, team)
        end
    end

    if #list == 0 then
        return GetLegacyAllianceList()
    end

    table.sort(list, function(a, b) return a < b end)
    return list
end

local function GetAllianceScore(alliance)
    local roundIndex = Num(GetCurrentBattlegroundRoundIndex())
    return Num(GetCurrentBattlegroundScore(roundIndex, alliance))
end

local function FormatBigNumber(value)
    value = Num(value)
    if value >= 1000000 then
        return string.format("%.1fm", value / 1000000)
    elseif value >= 1000 then
        return string.format("%dk", math.floor(value / 1000))
    end
    return tostring(value)
end


local function FormatTimestamp(timestamp)
    timestamp = tonumber(timestamp) or GetTimeStamp()
    local formatted = FormatAchievementLinkTimestamp(tostring(timestamp))
    if formatted and formatted ~= "" then return formatted end

    local date = GetDateStringFromTimestamp(timestamp)
    if date and date ~= "" then return date end

    return tostring(timestamp)
end

local function Score(entryIndex, scoreType, roundIndex, aggregate)
    if aggregate then
        return Num(GetBattlegroundCumulativeScoreForScoreboardEntryByType(entryIndex, scoreType, roundIndex))
    end
    return Num(GetScoreboardEntryScoreByType(entryIndex, scoreType, roundIndex))
end

local function GetGameTypeName()
    local bgId = GetCurrentBattlegroundId()
    local gameType = nil
    if bgId and bgId > 0 then
        gameType = GetBattlegroundGameType(bgId)
    end
    if gameType then
        local name = GetString("SI_BATTLEGROUNDGAMETYPE", gameType)
        if name and name ~= "" then return name end
    end
    return "Battleground"
end

local function IsRoundBased4v4Deathmatch(bgId)
    bgId = Num(bgId)
    if bgId <= 0 then return false end
    if DoesBattlegroundHaveRounds(bgId) ~= true then return false end
    if GetBattlegroundGameType(bgId) ~= BATTLEGROUND_GAME_TYPE_DEATHMATCH then return false end

    local teamSize = Num(GetBattlegroundTeamSize(bgId))
    local numTeams = Num(GetBattlegroundNumTeams(bgId))
    return teamSize == 4 and numTeams == 2
end

local function IsFinalRoundPostround4v4Deathmatch(bgId)
    if not IsRoundBased4v4Deathmatch(bgId) then return false end
    if GetCurrentBattlegroundState() ~= BATTLEGROUND_STATE_POSTROUND then return false end

    if HasTeamWonBattlegroundEarly() == true then
        return true
    end

    local roundIndex = Num(GetCurrentBattlegroundRoundIndex())
    local numRounds = Num(GetBattlegroundNumRounds(bgId))
    return roundIndex > 0 and numRounds > 0 and roundIndex >= numRounds
end

local function GetRoundIndex()
    -- Use the documented battleground API; finished round-based match capture
    -- handles cumulative results separately.
    return GetCurrentBattlegroundRoundIndex(), false
end

local function DetermineWinner(scores)
    local winner, bestScore, tied = nil, -1, false
    for _, alliance in ipairs(GetAllianceList(scores)) do
        local score = Num(scores and scores[alliance])
        if score > bestScore then
            winner, bestScore, tied = alliance, score, false
        elseif score == bestScore then
            tied = true
        end
    end
    if tied then return 0, bestScore end
    return winner, bestScore
end

local function GetPlayerResultText(match)
    -- Match cards and details must only read the saved result value.
    -- Incomplete records intentionally display "--".
    if match and match.playerResult and match.playerResult ~= "" then
        return match.playerResult
    end
    return "--"
end

local function GetPlayerResultDisplayText(match)
    -- Match cards and details must only read the saved display value.
    -- Incomplete records intentionally display "--".
    if match and match.playerResultDisplay and match.playerResultDisplay ~= "" then
        return match.playerResultDisplay
    end
    return "--"
end

local function NormalizePlayerName(name)
    name = tostring(name or "")
    if name == "" then return "" end
    return string.lower(zo_strformat(SI_PLAYER_NAME, name))
end

local function MakeCharacterKey(name, characterId)
    if characterId and tostring(characterId) ~= "" and tostring(characterId) ~= "0" then
        return "id:" .. tostring(characterId)
    end
    return NormalizePlayerName(name)
end

local function GetCurrentCharacterIdOrNil()
    local id = GetCurrentCharacterId()
    if id and tostring(id) ~= "" and tostring(id) ~= "0" then return id end
    return nil
end

local function GetCurrentCharacterName()
    return zo_strformat(SI_PLAYER_NAME, GetUnitName("player") or "")
end

local function GetCurrentCharacterKey()
    return MakeCharacterKey(GetCurrentCharacterName(), GetCurrentCharacterIdOrNil())
end

local function GetMatchCharacterName(match)
    if not match then return nil end
    if match.characterName and match.characterName ~= "" then return match.characterName end
    return nil
end

local function GetMatchCharacterId(match)
    if not match then return nil end
    if match.characterId and tostring(match.characterId) ~= "" and tostring(match.characterId) ~= "0" then return match.characterId end
    return nil
end

local function GetMatchCharacterKey(match)
    return MakeCharacterKey(GetMatchCharacterName(match), GetMatchCharacterId(match))
end

local function GetSelectedCharacterKey()
    -- Default to account-wide history. Character selection is an optional filter,
    -- not the base state of the history view.
    if BL.selectedCharacterKey and BL.selectedCharacterKey ~= "" then
        return BL.selectedCharacterKey
    end
    return ALL_CHARACTERS_KEY
end

local function GetSelectedCharacterName()
    local selectedKey = GetSelectedCharacterKey()
    if selectedKey == ALL_CHARACTERS_KEY then
        return "All Characters"
    end

    if BL.vars and BL.vars.characters then
        for _, character in ipairs(BL.vars.characters) do
            if character.key == selectedKey then
                return character.name or "Character"
            end
        end
    end

    local currentName = GetCurrentCharacterName()
    if selectedKey == GetCurrentCharacterKey() then return currentName end

    for _, match in ipairs(BL.matches or {}) do
        if GetMatchCharacterKey(match) == selectedKey then
            return GetMatchCharacterName(match)
        end
    end
    return currentName ~= "" and currentName or "Character"
end


local function GetSelectedCharacterNameKey()
    return NormalizePlayerName(GetSelectedCharacterName())
end

local function GetMatchLocalClassId(match)
    if not match then return nil end
    if match.localClassId and tonumber(match.localClassId) and tonumber(match.localClassId) > 0 then
        return tonumber(match.localClassId)
    end
    return nil
end

local function GetSelectedCharacterClassIcon()
    local selectedKey = GetSelectedCharacterKey()

    if BL.vars and BL.vars.characters then
        for _, character in ipairs(BL.vars.characters) do
            if character.key == selectedKey then
                local classId = tonumber(character.classId) or 0
                if classIcons[classId] then return classIcons[classId] end
            end
        end
    end

    if selectedKey == GetCurrentCharacterKey() then
        return GetCurrentClassIcon()
    end

    for i = #(BL.matches or {}), 1, -1 do
        local match = BL.matches[i]
        if GetMatchCharacterKey(match) == selectedKey then
            local classId = GetMatchLocalClassId(match)
            if classId and classIcons[classId] then return classIcons[classId] end
        end
    end
    return BG_ICON
end

local function MatchPassesSelectedCharacter(match)
    local selectedKey = GetSelectedCharacterKey()
    if selectedKey == ALL_CHARACTERS_KEY then
        return true
    end
    return GetMatchCharacterKey(match) == selectedKey
end

local GetLocalPlayerForMatch
local MatchPassesHistoryFilter
GetLocalPlayerForMatch = function(match)
    for _, player in ipairs(match and match.players or {}) do
        if player.isLocalPlayer then return player end
    end
    return nil
end
local function MatchCapturedOnDate(match, dateText)
    if not match or not dateText or dateText == "" then return false end

    -- Primary path: use the same display formatter as the header date.
    if FormatTimestamp(match.capturedAt) == dateText then
        return true
    end

    -- Alternate date comparison for ESO helper format differences. Some ESO date
    -- helpers can format the same timestamp differently depending on context.
    if match.capturedAt then
        local matchDate = GetDateStringFromTimestamp(match.capturedAt)
        local todayDate = GetDateStringFromTimestamp(GetTimeStamp())
        if matchDate and todayDate and matchDate ~= "" and matchDate == todayDate then
            return true
        end
    end

    return false
end

local MatchCapturedInServerDayRange

local function GetCurrentServerDayStart()
    local serverNow = Num(GetTimeStamp())
    if serverNow <= 0 then return 0 end

    -- Derive the start of the current day straight from ESO's own date helpers, applied to
    -- GetTimeStamp(). This stays in the same frame as the displayed date and avoids the old
    -- GetGlobalTimeOfDay time-of-day subtraction.
    local year, month, day = GetDateElementsFromTimestamp(serverNow)
    year, month, day = Num(year), Num(month), Num(day)
    if year > 0 and month > 0 and day > 0 then
        local serverDayStart = Num(GetTimestampForStartOfDate(year, month, day, false))
        if serverDayStart > 0 then
            return serverDayStart
        end
    end

    return 0
end

MatchCapturedInServerDayRange = function(match, days)
    local capturedAt = Num(match and match.capturedAt)
    if capturedAt <= 0 then return false end

    local serverDayStart = GetCurrentServerDayStart()
    if serverDayStart <= 0 then
        return MatchCapturedOnDate(match, FormatTimestamp(GetTimeStamp()))
    end

    days = math.max(1, math.floor(Num(days or 1)))
    local startTime = serverDayStart - ((days - 1) * 86400)
    local endTime = serverDayStart + 86400
    return capturedAt >= startTime and capturedAt < endTime
end

local function MatchCapturedOnServerToday(match)
    return MatchCapturedInServerDayRange(match, 1)
end

local function GetDisplayMatchNumber(match)
    return FormatMatchId(match)
end

local function GetCompactGameTypeName(gameType)
    return tostring(gameType or "Battleground")
end

-- Bug #7 fix: assign to the forward-declared upvalue so GetSelectedCharacterWinRate
-- (and any other early caller) automatically picks up the canonical implementation.
GetGameTypeFilterKey = function(gameType)
    local text = string.lower(tostring(gameType or ""))
    if text:find("death") then return "DM" end
    if text:find("relic") then return "R" end
    if text:find("chaos") or text:find("ball") then return "C" end
    if text:find("crazy") or text:find("king") then return "CK" end
    if text:find("domination") or text:find("dom") then return "DOM" end
    return "Other"
end

GetMatchTypeFilterKey = function(gameType)
    if GetGameTypeFilterKey(gameType) == "DM" then
        return "Deathmatch"
    end
    return "Objective"
end

local function GetMatchTeamCount(match)
    if not match then return 0 end
    local count = #(GetAllianceList(match.scores, match.players) or {})
    return count
end

local function GetMatchPlayerCount(match)
    if not match or not match.players then return 0 end
    return #(match.players or {})
end

local function GetTeamConfigurationKey(match)
    local bg = match and match.battleground or nil
    local savedTeamSize = Num((bg and bg.teamSize) or (match and match.battlegroundTeamSize))
    local savedNumTeams = Num((bg and bg.numTeams) or (match and match.battlegroundNumTeams))

    if savedNumTeams > 0 and savedTeamSize > 0 then
        if savedNumTeams == 2 and savedTeamSize <= 4 then return "4v4" end
        if savedNumTeams == 2 and savedTeamSize <= 8 then return "8v8" end
        if savedNumTeams == 2 and savedTeamSize >= 9 then return "9v9" end
        if savedNumTeams == 3 and savedTeamSize <= 4 then return "4v4v4" end
        if savedNumTeams == 3 and savedTeamSize >= 6 then return "6v6v6" end
    end

    local teamCount = GetMatchTeamCount(match)
    local playerCount = GetMatchPlayerCount(match)

    -- Fallback for legacy matches without battleground metadata. Full new-mode
    -- matches can be distinguished by their larger player counts; heavily
    -- depleted matches remain classified as the nearest smaller format.
    if teamCount == 2 and playerCount <= 8 then
        return "4v4"
    elseif teamCount == 2 and playerCount <= 16 then
        return "8v8"
    elseif teamCount == 2 then
        return "9v9"
    elseif teamCount == 3 and playerCount <= 12 then
        return "4v4v4"
    elseif teamCount == 3 then
        return "6v6v6"
    end

    return nil
end

local function GetTeamSizeFilterLabel(filter)
    if filter == "4v4" then return "4v4" end
    if filter == "4v4v4" then return "4v4v4" end
    if filter == "8v8" then return "8v8" end
    if filter == "6v6v6" then return "6v6v6" end
    if filter == "9v9" then return "9v9" end
    return "All"
end

local function NormalizeTeamSizeFilter(filter)
    if filter == "2" then return "4v4" end
    if filter == "3" then return "4v4v4" end
    if filter == "4v4" or filter == "4v4v4" or filter == "8v8" or filter == "6v6v6" or filter == "9v9" then return filter end
    return "All"
end

local function MatchPassesTeamSizeFilter(match)
    local filter = NormalizeTeamSizeFilter(BL.teamSizeFilter or "All")
    BL.teamSizeFilter = filter
    if filter == "All" then return true end

    return GetTeamConfigurationKey(match) == filter
end

local function MatchPassesMatchTypeFilter(match)
    local filter = BL.matchTypeFilter or "All"
    if filter == "All" then return true end
    return GetMatchTypeFilterKey(match and match.gameType) == filter
end

local MatchInLastDays

local function NormalizeDateRangeFilter(filter)
    if filter == "Today" or filter == "today" then return "Today" end
    if filter == "7" or filter == "7 day" or filter == "7day" then return "7 day" end
    if filter == "14" or filter == "14 day" or filter == "14day" then return "14 day" end
    if filter == "30" or filter == "30 day" or filter == "30day" then return "30 day" end
    return "All"
end

local function MatchPassesDateRangeFilter(match)
    local filter = NormalizeDateRangeFilter(BL.dateRangeFilter or "All")
    BL.dateRangeFilter = filter
    if filter == "All" then return true end

    if filter == "Today" then
        return MatchCapturedOnServerToday(match)
    elseif filter == "7 day" then
        return MatchInLastDays(match, 7)
    elseif filter == "14 day" then
        return MatchInLastDays(match, 14)
    elseif filter == "30 day" then
        return MatchInLastDays(match, 30)
    end

    return true
end

MatchPassesHistoryFilter = function(match, ignoreDateFilter)
    if not MatchPassesSelectedCharacter(match) then return false end
    if not MatchPassesTeamSizeFilter(match) then return false end
    if not MatchPassesMatchTypeFilter(match) then return false end

    if (BL.matchTypeFilter or "All") == "Deathmatch" then
        return ignoreDateFilter == true or MatchPassesDateRangeFilter(match)
    end

    local filter = BL.historyFilter or "All"
    if filter ~= "All" and GetGameTypeFilterKey(match and match.gameType) ~= filter then return false end
    if ignoreDateFilter == true then return true end
    return MatchPassesDateRangeFilter(match)
end


MatchInLastDays = function(match, days)
    return MatchCapturedInServerDayRange(match, days)
end

-- Deserter penalty summary, independent of match data. Reads BL.vars.deserterEvents
-- entries as { duration = <minutes>, timestamp = <GetTimeStamp> } and reports
-- totals for the selected date-range filter. Returned durations are seconds so
-- the Metrics timer block can use the same formatter as match/queue timers.
local function GetDeserterSummary()
    local events = (BL.vars and type(BL.vars.deserterEvents) == "table" and BL.vars.deserterEvents) or {}
    local filter = NormalizeDateRangeFilter(BL.dateRangeFilter or "All")
    local now = Num(GetTimeStamp())
    local todayStart = GetCurrentServerDayStart()
    if todayStart <= 0 and now > 0 then
        todayStart = now - (now % 86400)
    end

    local windowDays, startTime, endTime
    if filter == "Today" then
        windowDays = 1
        startTime = todayStart
        endTime = todayStart + 86400
    elseif filter == "7 day" then
        windowDays = 7
        startTime = todayStart - 6 * 86400
        endTime = todayStart + 86400
    elseif filter == "14 day" then
        windowDays = 14
        startTime = todayStart - 13 * 86400
        endTime = todayStart + 86400
    elseif filter == "30 day" then
        windowDays = 30
        startTime = todayStart - 29 * 86400
        endTime = todayStart + 86400
    end

    local totalMinutes, count = 0, 0
    local activeDays = {}
    local activeDayCount = 0
    local function GetDeserterDayKey(timestamp)
        local year, month, day = GetDateElementsFromTimestamp(timestamp)
        year, month, day = Num(year), Num(month), Num(day)
        if year > 0 and month > 0 and day > 0 then
            return string.format("%04d-%02d-%02d", year, month, day)
        end
        return tostring(math.floor(timestamp / 86400))
    end

    for _, event in ipairs(events) do
        local timestamp = Num(event and event.timestamp)
        local duration = Num(event and event.duration)
        local inWindow = timestamp > 0 and duration > 0
        if inWindow and filter ~= "All" then
            inWindow = todayStart > 0 and timestamp >= startTime and timestamp < endTime
        end
        if inWindow then
            totalMinutes = totalMinutes + duration
            count = count + 1
            local dayKey = GetDeserterDayKey(timestamp)
            if not activeDays[dayKey] then
                activeDays[dayKey] = true
                activeDayCount = activeDayCount + 1
            end
        end
    end
    windowDays = activeDayCount > 0 and activeDayCount or 1

    local totalSeconds = totalMinutes * 60
    return {
        count = count,
        total = totalSeconds,
        average = totalSeconds / windowDays,
    }
end

local function MatchPassesEncounterWindow(match, windowKey, todayText)
    if not MatchPassesHistoryFilter(match) then return false end
    if windowKey == "today" then
        return MatchCapturedOnServerToday(match)
    elseif windowKey == "week" then
        return MatchInLastDays(match, 7)
    elseif windowKey == "thirty" then
        return MatchInLastDays(match, 30)
    end
    return true
end

local encounterClassOrder = _x.encounterClassOrder

function BL.GetLatestVisibleMatch(ignoreGameTypeFilter)
    local latestMatch = nil
    local latestTime = -1
    local latestId = ""

    for _, match in ipairs(BL.matches or {}) do
        if MatchPassesSelectedCharacter(match) and (ignoreGameTypeFilter or MatchPassesHistoryFilter(match)) then
            local capturedAt = Num(match and match.capturedAt)
            local id = tostring(match and match.id or "")
            if capturedAt > latestTime or (capturedAt == latestTime and id > latestId) then
                latestMatch = match
                latestTime = capturedAt
                latestId = id
            end
        end
    end

    return latestMatch
end

function BL.SelectionIsVisible()
    if not BL.selectedMatchId then return false end
    local match = BL.GetMatch(BL.selectedMatchId)
    return match ~= nil and MatchPassesHistoryFilter(match)
end

function BL.EnsureVisibleSelection()
    if BL.SelectionIsVisible() then
        return BL.GetMatch(BL.selectedMatchId)
    end
    BL.selectedMatchId = nil
    return nil
end

local function GetAllianceDisplayName(alliance)
    if allianceNames[alliance] then return allianceNames[alliance] end
    return "Team " .. tostring(alliance or "?")
end

local function FormatTeamScores(scores)
    scores = scores or {}
    local parts = {}
    for _, alliance in ipairs(GetAllianceList(scores)) do
        parts[#parts + 1] = string.format("%s %d", GetAllianceDisplayName(alliance), Num(scores[alliance]))
    end
    return table.concat(parts, "   ")
end


local function GetSavedTeamSummariesSorted(match)
    local rows = {}
    if match and match.teamSummaries then
        for _, summary in ipairs(match.teamSummaries) do
            if type(summary) == "table" then
                rows[#rows + 1] = summary
            end
        end
    end

    table.sort(rows, function(a, b)
        local av = Num(a and a.score)
        local bv = Num(b and b.score)
        if av == bv then
            return Num(a and a.alliance) < Num(b and b.alliance)
        end
        return av > bv
    end)

    return rows
end

local function GetScoreOrderedAlliances(match)
    local scores = match and match.scores or {}
    local list = GetAllianceList(scores, match and match.players)
    table.sort(list, function(a, b)
        local av = Num(scores[a])
        local bv = Num(scores[b])
        if av == bv then return a < b end
        return av > bv
    end)
    return list
end

local function MakeSignature(match)
    -- Bug #10 fix: the original signature only included gameType, team scores, and
    -- player count. Two back-to-back matches that happened to end with identical
    -- scores and the same number of players would produce the same signature, causing
    -- the second save to be silently skipped. Including capturedAt makes each
    -- scoreboard session unique even when the visible data is identical.
    local parts = { tostring(match.gameType or ""), tostring(match.capturedAt or 0) }
    for _, alliance in ipairs(GetScoreOrderedAlliances(match)) do
        parts[#parts + 1] = tostring(alliance) .. "=" .. tostring(Num(match.scores and match.scores[alliance]))
    end
    parts[#parts + 1] = tostring(#(match.players or {}))
    return table.concat(parts, ":")
end

local function CreateLabel(parent, name, text, font, colour)
    local label = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    label:SetFont(font or "ZoFontGame")
    label:SetText(text or "")
    if colour then label:SetColor(unpack(colour)) end
    return label
end

local function CreateBackdrop(parent, name, alpha, edgeAlpha)
    local bd = WINDOW_MANAGER:CreateControl(name, parent, CT_BACKDROP)
    bd:SetCenterColor(0.018, 0.016, 0.014, alpha or 0.88)
    bd:SetEdgeColor(0.55, 0.47, 0.34, edgeAlpha or 0.26)
    bd:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 128, 16)
    bd:SetInsets(10, 10, -10, -10)
    return bd
end

local function CreateSoftFill(parent, name, r, g, b, a)
    local bd = WINDOW_MANAGER:CreateControl(name, parent, CT_BACKDROP)
    bd:SetCenterColor(r or 0.03, g or 0.027, b or 0.022, a or 0.34)
    bd:SetEdgeColor(0, 0, 0, 0)
    return bd
end

local function SetHiddenIfControl(control, hidden)
    if control then control:SetHidden(hidden) end
end

function BL.GetDefaultBattleboardSceneName()
    local value = BL.vars and BL.vars.defaultScene or DEFAULT_SCENE_HISTORY
    if value == DEFAULT_SCENE_OBSERVATORY or value == "Observatory" or value == 3 or value == "3" then
        return DEFAULT_SCENE_OBSERVATORY
    end
    if value == DEFAULT_SCENE_METRICS or value == "Metrics" or value == "Data" or value == 2 or value == "2" then
        return DEFAULT_SCENE_METRICS
    end
    return DEFAULT_SCENE_HISTORY
end

function BL.GetDefaultBattleboardPage()
    local sceneName = BL.GetDefaultBattleboardSceneName()
    if sceneName == DEFAULT_SCENE_OBSERVATORY then return "Observatory" end
    return sceneName == DEFAULT_SCENE_METRICS and "Data" or "History"
end

-- Detail table sizing is owned by Battleboard_Constants.lua. Core still performs
-- the one-time column reflow so later modules see the same computed width.
local DETAIL_TABLE_COLUMN_GAP = _x.DETAIL_TABLE_COLUMN_GAP
local DETAIL_TABLE_WIDTH = _x.DETAIL_TABLE_WIDTH
local DETAIL_PANEL_WIDTH_TRIM = _x.DETAIL_PANEL_WIDTH_TRIM
local DETAIL_TABLE_BODY_FONT = _x.DETAIL_TABLE_BODY_FONT

-- Bind shared scene layout values. The history column is pinned flush to the
-- right edge; widening the content area shifts the details panel left while
-- keeping the card list flush-right.
local HISTORY_PANEL_WIDTH = _x.HISTORY_PANEL_WIDTH
local HISTORY_SCROLLBAR_WIDTH = _x.HISTORY_SCROLLBAR_WIDTH
local HISTORY_SCROLLBAR_GAP = _x.HISTORY_SCROLLBAR_GAP
local HISTORY_CARD_AREA_WIDTH = _x.HISTORY_CARD_AREA_WIDTH
local HISTORY_SCROLL_WIDTH = _x.HISTORY_SCROLL_WIDTH
local CONTENT_TOP = _x.CONTENT_TOP
local CONTENT_END = _x.CONTENT_END
local PAGE_ONE_FOOTER_HEIGHT = _x.PAGE_ONE_FOOTER_HEIGHT
local PAGE_ONE_PANEL_HEIGHT = _x.PAGE_ONE_PANEL_HEIGHT
local HISTORY_VIEWPORT_HEIGHT = _x.HISTORY_VIEWPORT_HEIGHT
local DETAIL_PANEL_X = _x.DETAIL_PANEL_X
local DETAIL_PANEL_WIDTH = _x.DETAIL_PANEL_WIDTH
local DETAIL_SEPARATOR_X = _x.DETAIL_SEPARATOR_X
local HISTORY_PANEL_X = _x.HISTORY_PANEL_X
local CONTENT_WIDTH = _x.CONTENT_WIDTH
local STRIP_WIDTH = _x.STRIP_WIDTH
local PAGE_ONE_BOTTOM_Y = _x.PAGE_ONE_BOTTOM_Y

-- Match Metrics page uses the same content lower bound as Match History.
local PAGE_TWO_PANEL_HEIGHT = _x.PAGE_TWO_PANEL_HEIGHT
local CONTENT_BOTTOM_Y = _x.CONTENT_BOTTOM_Y
local DATA_SUMMARY_STRIP_HEIGHT = _x.DATA_SUMMARY_STRIP_HEIGHT
local DATA_SUMMARY_DIVIDER_GAP = _x.DATA_SUMMARY_DIVIDER_GAP
-- Contribution panel height: 10 (top pad) + 34 (header) + 5 rowsx52 (starting y=62) + 10 (bottom pad) = 332
-- All three stat panels (Contribution, Personal Records, Matches) have 5 rows x 52px.
-- Height: 10 (top pad) + 34 (header) + 5x52 (rows) + 30 (bottom pad, +20 extra) = 334
local DATA_CONTRIBUTION_PANEL_HEIGHT = _x.DATA_CONTRIBUTION_PANEL_HEIGHT

local PAGE_TAB_NORMAL_SIZE = _x.PAGE_TAB_NORMAL_SIZE
local PAGE_TAB_BASE_Y = _x.PAGE_TAB_BASE_Y
local PAGE_TAB_HOVER_OFFSET_Y = _x.PAGE_TAB_HOVER_OFFSET_Y
local PAGE_TAB_GAP = _x.PAGE_TAB_GAP

-- Player table columns are created by Shared before BuildUI loads.
local columns = _x.columns

local function ReflowDetailColumns()
    local x = 0
    for index, col in ipairs(columns) do
        col.x = x
        x = x + col.w
        if index < #columns then
            x = x + (col.gap or DETAIL_TABLE_COLUMN_GAP)
        end
    end
    DETAIL_TABLE_WIDTH = x
end

ReflowDetailColumns()

local function IsNumericSortKey(key)
    return key == "classId" or key == "kills" or key == "deaths" or key == "assists" or key == "damage" or key == "healing" or key == "score" or key == "kd"
end

-- Export helper functions and the computed layout values for later files.
do
    local _x = BL.__constants
    _x.LMM = LMM
    _x.LAM = LAM
    _x.BG_ICON = BG_ICON
    _x.BG_ICON_DOWN = BG_ICON_DOWN
    _x.BG_ICON_OVER = BG_ICON_OVER
    _x.MATCH_HISTORY_ICON = MATCH_HISTORY_ICON
    _x.MATCH_HISTORY_ICON_DOWN = MATCH_HISTORY_ICON_DOWN
    _x.MATCH_HISTORY_ICON_OVER = MATCH_HISTORY_ICON_OVER
    _x.MATCH_HISTORY_ICON_SELECTED = MATCH_HISTORY_ICON_SELECTED
    _x.STATS_ICON = STATS_ICON
    _x.STATS_ICON_DOWN = STATS_ICON_DOWN
    _x.STATS_ICON_OVER = STATS_ICON_OVER
    _x.STATS_ICON_SELECTED = STATS_ICON_SELECTED
    _x.MENU_ICON = MENU_ICON
    _x.MENU_ICON_DOWN = MENU_ICON_DOWN
    _x.MENU_ICON_OVER = MENU_ICON_OVER
    _x.BLANK_ICON = BLANK_ICON
    _x.DEFAULT_SCENE_HISTORY = DEFAULT_SCENE_HISTORY
    _x.TEAM_ICON_FIRE_DRAKES = TEAM_ICON_FIRE_DRAKES
    _x.TEAM_ICON_PIT_DAEMONS = TEAM_ICON_PIT_DAEMONS
    _x.TEAM_ICON_STORM_LORDS = TEAM_ICON_STORM_LORDS
    _x.PLAYER_TABLE_TEAM_ICON_FIRE_DRAKES = PLAYER_TABLE_TEAM_ICON_FIRE_DRAKES
    _x.PLAYER_TABLE_TEAM_ICON_PIT_DAEMONS = PLAYER_TABLE_TEAM_ICON_PIT_DAEMONS
    _x.PLAYER_TABLE_TEAM_ICON_STORM_LORDS = PLAYER_TABLE_TEAM_ICON_STORM_LORDS
    _x.OUTCOME_BANNER_RESULT_ICON_WIN = OUTCOME_BANNER_RESULT_ICON_WIN
    _x.OUTCOME_BANNER_RESULT_ICON_LOSS = OUTCOME_BANNER_RESULT_ICON_LOSS
    _x.OUTCOME_BANNER_RESULT_ICON_TIE = OUTCOME_BANNER_RESULT_ICON_TIE
    _x.TEAM_INDICATOR_BANNER_FIRE_DRAKES = TEAM_INDICATOR_BANNER_FIRE_DRAKES
    _x.TEAM_INDICATOR_BANNER_PIT_DAEMONS = TEAM_INDICATOR_BANNER_PIT_DAEMONS
    _x.TEAM_INDICATOR_BANNER_STORM_LORDS = TEAM_INDICATOR_BANNER_STORM_LORDS
    _x.PLAYER_TABLE_TEAM_HEADER_ICON = PLAYER_TABLE_TEAM_HEADER_ICON
    _x.SORT_ICON_UP = SORT_ICON_UP
    _x.SORT_ICON_DOWN = SORT_ICON_DOWN
    _x.ALL_CHARACTERS_KEY = ALL_CHARACTERS_KEY
    _x.classIcons = classIcons
    _x.allianceOrder = allianceOrder
    _x.allianceNames = allianceNames
    _x.allianceTeamIcons = allianceTeamIcons
    _x.playerTableTeamIcons = playerTableTeamIcons
    _x.teamIndicatorBanners = teamIndicatorBanners
    _x.allianceColours = allianceColours
    _x.GetTeamSummaryIcon = GetTeamSummaryIcon
    _x.GetPlayerTableTeamIcon = GetPlayerTableTeamIcon
    _x.GetTeamIndicatorBanner = GetTeamIndicatorBanner
    _x.GetOutcomeBannerResultIcon = GetOutcomeBannerResultIcon
    _x.Num = Num
    _x.MAX_LOCKED_MATCHES = MAX_LOCKED_MATCHES
    _x.FormatMatchId = FormatMatchId
    _x.GetCurrentClassIcon = GetCurrentClassIcon
    _x.FireAlliance = FireAlliance
    _x.PitAlliance = PitAlliance
    _x.StormAlliance = StormAlliance
    _x.GetGameTypeFilterKey = GetGameTypeFilterKey
    _x.GetMatchTypeFilterKey = GetMatchTypeFilterKey
    _x.AddUniqueAlliance = AddUniqueAlliance
    _x.GetLegacyAllianceList = GetLegacyAllianceList
    _x.GetCurrentBattlegroundTeamList = GetCurrentBattlegroundTeamList
    _x.GetAllianceList = GetAllianceList
    _x.GetAllianceScore = GetAllianceScore
    _x.FormatBigNumber = FormatBigNumber
    _x.FormatTimestamp = FormatTimestamp
    _x.Score = Score
    _x.GetGameTypeName = GetGameTypeName
    _x.IsRoundBased4v4Deathmatch = IsRoundBased4v4Deathmatch
    _x.IsFinalRoundPostround4v4Deathmatch = IsFinalRoundPostround4v4Deathmatch
    _x.GetRoundIndex = GetRoundIndex
    _x.DetermineWinner = DetermineWinner
    _x.GetPlayerResultText = GetPlayerResultText
    _x.GetPlayerResultDisplayText = GetPlayerResultDisplayText
    _x.NormalizePlayerName = NormalizePlayerName
    _x.MakeCharacterKey = MakeCharacterKey
    _x.GetCurrentCharacterIdOrNil = GetCurrentCharacterIdOrNil
    _x.GetCurrentCharacterName = GetCurrentCharacterName
    _x.GetCurrentCharacterKey = GetCurrentCharacterKey
    _x.GetMatchCharacterName = GetMatchCharacterName
    _x.GetMatchCharacterId = GetMatchCharacterId
    _x.GetMatchCharacterKey = GetMatchCharacterKey
    _x.GetSelectedCharacterKey = GetSelectedCharacterKey
    _x.GetSelectedCharacterName = GetSelectedCharacterName
    _x.GetSelectedCharacterNameKey = GetSelectedCharacterNameKey
    _x.GetMatchLocalClassId = GetMatchLocalClassId
    _x.GetSelectedCharacterClassIcon = GetSelectedCharacterClassIcon
    _x.MatchPassesSelectedCharacter = MatchPassesSelectedCharacter
    _x.GetLocalPlayerForMatch = GetLocalPlayerForMatch
    _x.MatchPassesHistoryFilter = MatchPassesHistoryFilter
    _x.MatchCapturedOnDate = MatchCapturedOnDate
    _x.GetDisplayMatchNumber = GetDisplayMatchNumber
    _x.GetCompactGameTypeName = GetCompactGameTypeName
    _x.GetMatchTeamCount = GetMatchTeamCount
    _x.GetMatchPlayerCount = GetMatchPlayerCount
    _x.GetTeamConfigurationKey = GetTeamConfigurationKey
    _x.GetTeamSizeFilterLabel = GetTeamSizeFilterLabel
    _x.NormalizeTeamSizeFilter = NormalizeTeamSizeFilter
    _x.MatchPassesTeamSizeFilter = MatchPassesTeamSizeFilter
    _x.MatchPassesMatchTypeFilter = MatchPassesMatchTypeFilter
    _x.MatchInLastDays = MatchInLastDays
    _x.GetDeserterSummary = GetDeserterSummary
    _x.MatchPassesEncounterWindow = MatchPassesEncounterWindow
    _x.encounterClassOrder = encounterClassOrder
    _x.GetAllianceDisplayName = GetAllianceDisplayName
    _x.FormatTeamScores = FormatTeamScores
    _x.GetSavedTeamSummariesSorted = GetSavedTeamSummariesSorted
    _x.GetScoreOrderedAlliances = GetScoreOrderedAlliances
    _x.MakeSignature = MakeSignature
    _x.CreateLabel = CreateLabel
    _x.CreateBackdrop = CreateBackdrop
    _x.CreateSoftFill = CreateSoftFill
    _x.SetHiddenIfControl = SetHiddenIfControl
    _x.DETAIL_TABLE_COLUMN_GAP = DETAIL_TABLE_COLUMN_GAP
    _x.DETAIL_TABLE_WIDTH = DETAIL_TABLE_WIDTH
    _x.DETAIL_PANEL_WIDTH_TRIM = DETAIL_PANEL_WIDTH_TRIM
    _x.DETAIL_TABLE_BODY_FONT = DETAIL_TABLE_BODY_FONT
    _x.HISTORY_PANEL_WIDTH = HISTORY_PANEL_WIDTH
    _x.HISTORY_SCROLLBAR_WIDTH = HISTORY_SCROLLBAR_WIDTH
    _x.HISTORY_SCROLLBAR_GAP = HISTORY_SCROLLBAR_GAP
    _x.HISTORY_CARD_AREA_WIDTH = HISTORY_CARD_AREA_WIDTH
    _x.HISTORY_SCROLL_WIDTH = HISTORY_SCROLL_WIDTH
    _x.CONTENT_TOP = CONTENT_TOP
    _x.CONTENT_END = CONTENT_END
    _x.PAGE_ONE_FOOTER_HEIGHT = PAGE_ONE_FOOTER_HEIGHT
    _x.PAGE_ONE_PANEL_HEIGHT = PAGE_ONE_PANEL_HEIGHT
    _x.HISTORY_VIEWPORT_HEIGHT = HISTORY_VIEWPORT_HEIGHT
    _x.DETAIL_PANEL_X = DETAIL_PANEL_X
    _x.DETAIL_PANEL_WIDTH = DETAIL_PANEL_WIDTH
    _x.DETAIL_SEPARATOR_X = DETAIL_SEPARATOR_X
    _x.HISTORY_PANEL_X = HISTORY_PANEL_X
    _x.CONTENT_WIDTH = CONTENT_WIDTH
    _x.STRIP_WIDTH = STRIP_WIDTH
    _x.PAGE_ONE_BOTTOM_Y = PAGE_ONE_BOTTOM_Y
    _x.PAGE_TWO_PANEL_HEIGHT = PAGE_TWO_PANEL_HEIGHT
    _x.CONTENT_BOTTOM_Y = CONTENT_BOTTOM_Y
    _x.DATA_SUMMARY_STRIP_HEIGHT = DATA_SUMMARY_STRIP_HEIGHT
    _x.DATA_SUMMARY_DIVIDER_GAP = DATA_SUMMARY_DIVIDER_GAP
    _x.DATA_CONTRIBUTION_PANEL_HEIGHT = DATA_CONTRIBUTION_PANEL_HEIGHT
    _x.PAGE_TAB_NORMAL_SIZE = PAGE_TAB_NORMAL_SIZE
    _x.PAGE_TAB_BASE_Y = PAGE_TAB_BASE_Y
    _x.PAGE_TAB_HOVER_OFFSET_Y = PAGE_TAB_HOVER_OFFSET_Y
    _x.PAGE_TAB_GAP = PAGE_TAB_GAP
    _x.columns = columns
    _x.ReflowDetailColumns = ReflowDetailColumns
    _x.IsNumericSortKey = IsNumericSortKey
end
