-- Battleboard_Capture.lua  (scoreboard capture and saved match construction)
-- Part of Battleboard.
-- Cross-file constants and helpers are read from Battleboard.__constants (aliased _x).

local BL = Battleboard
local _x = BL.__constants

local Num = _x.Num
local GetCurrentBattlegroundTeamList = _x.GetCurrentBattlegroundTeamList
local GetAllianceList = _x.GetAllianceList
local GetAllianceScore = _x.GetAllianceScore
local Score = _x.Score
local GetGameTypeName = _x.GetGameTypeName
local GetRoundIndex = _x.GetRoundIndex
local IsFinalRoundPostround4v4Deathmatch = _x.IsFinalRoundPostround4v4Deathmatch
local MAX_SCOREBOARD_PLAYERS = _x.MAX_SCOREBOARD_PLAYERS
local DetermineWinner = _x.DetermineWinner
local GetCurrentCharacterIdOrNil = _x.GetCurrentCharacterIdOrNil
local GetCurrentCharacterName = _x.GetCurrentCharacterName

local function FormatContributionPercent(value, total)
    value = Num(value)
    total = Num(total)
    if total <= 0 then return "--" end
    return string.format("%d%%", math.floor((value / total) * 100 + 0.5))
end

local function RoundToTwoDecimals(value)
    value = Num(value)
    return math.floor(value * 100 + 0.5) / 100
end

local function CalculateMean(values, key)
    local count = 0
    local total = 0
    for _, value in ipairs(values or {}) do
        total = total + Num(value and value[key])
        count = count + 1
    end
    if count <= 0 then return 0 end
    return total / count
end

local function CalculateStdDev(values, key, mean)
    local count = 0
    local total = 0
    mean = Num(mean)
    for _, value in ipairs(values or {}) do
        local delta = Num(value and value[key]) - mean
        total = total + (delta * delta)
        count = count + 1
    end
    if count <= 0 then return 0 end
    return math.sqrt(total / count)
end

local function CalculateZScore(value, mean, stdDev)
    value = Num(value)
    mean = Num(mean)
    stdDev = Num(stdDev)
    if stdDev <= 0 then return 0 end
    return (value - mean) / stdDev
end

local function CalculateTeamMvpScores(teamPlayers)
    local outputValues = {}
    for _, player in ipairs(teamPlayers or {}) do
        outputValues[#outputValues + 1] = {
            output = Num(player and player.damage) + Num(player and player.healing),
            kills = Num(player and player.kills),
            deaths = Num(player and player.deaths),
        }
    end

    local means = {
        output = CalculateMean(outputValues, "output"),
        kills = CalculateMean(outputValues, "kills"),
        deaths = CalculateMean(outputValues, "deaths"),
    }
    local stdDevs = {
        output = CalculateStdDev(outputValues, "output", means.output),
        kills = CalculateStdDev(outputValues, "kills", means.kills),
        deaths = CalculateStdDev(outputValues, "deaths", means.deaths),
    }

    local scores = {}
    for index, player in ipairs(teamPlayers or {}) do
        local values = outputValues[index] or {}
        local output = Num(values.output)
        local zOutput = CalculateZScore(output, means.output, stdDevs.output)
        local zKills = CalculateZScore(values.kills, means.kills, stdDevs.kills)
        local zDeaths = CalculateZScore(values.deaths, means.deaths, stdDevs.deaths)
        local combat = 0

        if Num(player and player.healing) > Num(player and player.damage) then
            combat = -zDeaths
        else
            combat = zKills - zDeaths
        end

        scores[player] = {
            score = (0.7 * zOutput) + (0.3 * combat),
            output = output,
        }
    end

    return scores
end

local function IsBetterTeamMVP(candidate, current, mvpScores)
    if not current then return true end

    local candidateScore = Num(mvpScores and mvpScores[candidate] and mvpScores[candidate].score)
    local currentScore = Num(mvpScores and mvpScores[current] and mvpScores[current].score)
    if candidateScore ~= currentScore then
        return candidateScore > currentScore
    end

    local candidateOutput = Num(mvpScores and mvpScores[candidate] and mvpScores[candidate].output)
    local currentOutput = Num(mvpScores and mvpScores[current] and mvpScores[current].output)
    if candidateOutput ~= currentOutput then
        return candidateOutput > currentOutput
    end

    return tostring(candidate and candidate.displayName or "") < tostring(current and current.displayName or "")
end

local function CalculateTeamKD(kills, deaths)
    kills = Num(kills)
    deaths = Num(deaths)
    if kills <= 0 and deaths > 0 then
        return RoundToTwoDecimals(-deaths)
    end
    if deaths <= 0 then
        return RoundToTwoDecimals(kills)
    end
    return RoundToTwoDecimals(kills / deaths)
end

local function ReadBattlegroundMetadata(bgId)
    bgId = Num(bgId)
    if bgId <= 0 then
        return {
            id = bgId,
            name = "",
            infoTexture = "",
            teamSize = 0,
            numTeams = 0,
        }
    end

    return {
        id = bgId,
        name = GetBattlegroundName(bgId) or "",
        infoTexture = GetBattlegroundInfoTexture(bgId) or "",
        teamSize = Num(GetBattlegroundTeamSize(bgId)),
        numTeams = Num(GetBattlegroundNumTeams(bgId)),
    }
end

local function RoundToOneDecimal(value)
    value = Num(value)
    return math.floor(value * 10 + 0.5) / 10
end

local function CalculateLocalPerformance(localPlayer, startedAt, endedAt, combatSeconds, deadSeconds)
    local durationSeconds = nil
    startedAt = Num(startedAt)
    endedAt = Num(endedAt)
    combatSeconds = Num(combatSeconds)
    deadSeconds = Num(deadSeconds)

    if startedAt > 0 and endedAt > startedAt then
        durationSeconds = endedAt - startedAt
    end

    local activeSeconds = nil
    if durationSeconds then
        if deadSeconds > durationSeconds then deadSeconds = durationSeconds end
        if combatSeconds > durationSeconds then combatSeconds = durationSeconds end
        activeSeconds = math.max(0, combatSeconds - deadSeconds)
    end

    local dps, hps = nil, nil
    if localPlayer and activeSeconds and activeSeconds > 0 then
        dps = RoundToOneDecimal(Num(localPlayer.damage) / activeSeconds)
        hps = RoundToOneDecimal(Num(localPlayer.healing) / activeSeconds)
    end

    return durationSeconds, deadSeconds, combatSeconds, activeSeconds, dps, hps
end

local function ScoresAreEmpty(scores)
    -- Bug #5 fix: the original code returned true when all scores were 0 AND when
    -- the table was nil/empty. A valid 0-0 scoreboard (e.g. a Deathmatch tie at
    -- game start, or an all-zero post-match snapshot) was being rejected as empty.
    -- Now: return true only when there are no entries at all; zero is a valid score.
    if not scores then return true end
    local sawEntry = false
    for _ in pairs(scores) do
        sawEntry = true
        break
    end
    return not sawEntry
end

local function IsMatchResultsRoundBasedBattleground(bgId)
    if not bgId or Num(bgId) <= 0 then return false end
    if not DoesBattlegroundHaveRounds(bgId) then return false end
    if GetCurrentBattlegroundState() == BATTLEGROUND_STATE_FINISHED then
        return true
    end
    return IsFinalRoundPostround4v4Deathmatch(bgId) == true
end

local function GetCaptureContext(bgId)
    local roundIndex, aggregate = GetRoundIndex()
    local useMatchResults = IsMatchResultsRoundBasedBattleground(bgId)

    if useMatchResults then
        roundIndex = Num(GetCurrentBattlegroundRoundIndex())
        if roundIndex <= 0 then
            roundIndex = Num(GetBattlegroundNumRounds(bgId))
        end
        if roundIndex > 0 then
            return {
                roundIndex = roundIndex,
                aggregate = true,
                useMatchResults = true,
            }
        end
    end

    return {
        roundIndex = roundIndex,
        aggregate = aggregate == true,
        useMatchResults = false,
    }
end

local function ReadCurrentTeamScores(context)
    -- Save-time only. Do not cache team scores during the match.
    -- Team ids are enumerated from the current battleground definition with
    -- GetBattlegroundTeamByIndex. Finished round-based matches use rounds won
    -- for the match-results score; other matches use the current BG score.
    local scores = {}
    for _, alliance in ipairs(GetCurrentBattlegroundTeamList()) do
        if context and context.useMatchResults then
            local roundsWon = GetCurrentBattlegroundRoundsWonByTeam(alliance)
            scores[alliance] = Num(roundsWon)
        else
            scores[alliance] = GetAllianceScore(alliance)
        end
    end
    return scores
end

local function DetermineWinnerForCapture(scores, context)
    if context and context.useMatchResults then
        local sawTie = false
        local bestScore = -1

        for _, alliance in ipairs(GetAllianceList(scores)) do
            local score = Num(scores and scores[alliance])
            if score > bestScore then bestScore = score end

            local result = GetBattlegroundResultForTeam(alliance)
            if result == BATTLEGROUND_RESULT_WIN then
                return alliance, score
            elseif result == BATTLEGROUND_RESULT_TIE then
                sawTie = true
            end
        end

        if sawTie then return 0, bestScore end
    end

    return DetermineWinner(scores)
end

local function BuildSavedMatchSummary(scores, players, winner, playerAlliance)
    local rows = {}
    local byAlliance = {}
    local playersByAlliance = {}

    for _, alliance in ipairs(GetAllianceList(scores, players)) do
        byAlliance[alliance] = {
            alliance = alliance,
            score = Num(scores and scores[alliance]),
            result = winner == 0 and "Tie" or (winner == alliance and "Win" or "Loss"),
            medals = 0,
            kills = 0,
            deaths = 0,
            assists = 0,
            damage = 0,
            healing = 0,
        }
        rows[#rows + 1] = byAlliance[alliance]
    end

    local localPlayer = nil
    for _, player in ipairs(players or {}) do
        local alliance = tonumber(player and player.alliance) or 0
        if alliance > 0 then
            if not byAlliance[alliance] then
                byAlliance[alliance] = {
                    alliance = alliance,
                    score = Num(scores and scores[alliance]),
                    result = winner == 0 and "Tie" or (winner == alliance and "Win" or "Loss"),
                    medals = 0,
                    kills = 0,
                    deaths = 0,
                    assists = 0,
                    damage = 0,
                    healing = 0,
                }
                rows[#rows + 1] = byAlliance[alliance]
            end

            local data = byAlliance[alliance]
            playersByAlliance[alliance] = playersByAlliance[alliance] or {}
            playersByAlliance[alliance][#playersByAlliance[alliance] + 1] = player

            data.medals = data.medals + Num(player.score)
            data.kills = data.kills + Num(player.kills)
            data.deaths = data.deaths + Num(player.deaths)
            data.assists = data.assists + Num(player.assists)
            data.damage = data.damage + Num(player.damage)
            data.healing = data.healing + Num(player.healing)
        end

        if player and player.isLocalPlayer then
            localPlayer = player
        end
    end

    local teamMvps = {}
    for _, player in ipairs(players or {}) do
        if player then
            player.isTeamMvp = nil
        end
    end

    for alliance, teamPlayers in pairs(playersByAlliance) do
        local mvpScores = CalculateTeamMvpScores(teamPlayers)
        for _, player in ipairs(teamPlayers or {}) do
            if IsBetterTeamMVP(player, teamMvps[alliance], mvpScores) then
                teamMvps[alliance] = player
            end
        end
    end

    for _, data in ipairs(rows) do
        data.kd = CalculateTeamKD(data.kills, data.deaths)

        local mvp = teamMvps[tonumber(data.alliance) or 0]
        if mvp then
            mvp.isTeamMvp = true
        end
    end

    table.sort(rows, function(a, b)
        if Num(a.score) == Num(b.score) then
            return Num(a.alliance) < Num(b.alliance)
        end
        return Num(a.score) > Num(b.score)
    end)

    local playerResult = nil
    if playerAlliance == nil then
        playerResult = nil
    elseif winner and winner ~= 0 then
        playerResult = playerAlliance == winner and "Win" or "Loss"
    else
        playerResult = "Tie"
    end

    local playerContribution = nil
    if localPlayer then
        local teamTotals = byAlliance[tonumber(localPlayer.alliance) or 0]
        playerContribution = {
            alliance = localPlayer.alliance,
            displayName = "",
            characterName = "Contribution:",
            score = FormatContributionPercent(localPlayer.score, teamTotals and teamTotals.medals),
            kills = FormatContributionPercent(localPlayer.kills, teamTotals and teamTotals.kills),
            deaths = FormatContributionPercent(localPlayer.deaths, teamTotals and teamTotals.deaths),
            assists = FormatContributionPercent(localPlayer.assists, teamTotals and teamTotals.assists),
            damage = FormatContributionPercent(localPlayer.damage, teamTotals and teamTotals.damage),
            healing = FormatContributionPercent(localPlayer.healing, teamTotals and teamTotals.healing),
            values = {
                score = Num(localPlayer.score),
                kills = Num(localPlayer.kills),
                deaths = Num(localPlayer.deaths),
                assists = Num(localPlayer.assists),
                damage = Num(localPlayer.damage),
                healing = Num(localPlayer.healing),
            },
            teamTotals = teamTotals and {
                score = Num(teamTotals.medals),
                kills = Num(teamTotals.kills),
                deaths = Num(teamTotals.deaths),
                assists = Num(teamTotals.assists),
                damage = Num(teamTotals.damage),
                healing = Num(teamTotals.healing),
            } or nil,
        }
    end

    return {
        playerResult = playerResult,
        playerResultDisplay = playerResult == "Win" and "VICTORY" or (playerResult == "Loss" and "DEFEAT" or (playerResult == "Tie" and "DRAW" or "")),
        teamSummaries = rows,
        playerContribution = playerContribution,
    }
end

function BL.CaptureCurrentScoreboard()
    -- Scoreboard capture. This is called by /bb save and by automatic postgame autosave.
    if not IsActiveWorldBattleground() then return nil end

    local bgId = GetCurrentBattlegroundId()
    local battlegroundMetadata = ReadBattlegroundMetadata(bgId)
    local gameType = GetGameTypeName()
    local captureContext = GetCaptureContext(bgId)
    local roundIndex = captureContext.roundIndex
    local aggregate = captureContext.aggregate
    local scores = ReadCurrentTeamScores(captureContext)

    local players = {}
    local count = math.min(Num(GetNumScoreboardEntries(roundIndex)), MAX_SCOREBOARD_PLAYERS)
    local localPlayerEntryIndex = Num(GetScoreboardLocalPlayerEntryIndex(roundIndex))

    for i = 1, count do
        local characterName, displayName, battlegroundAlliance, isLocalPlayer = GetScoreboardEntryInfo(i, roundIndex)
        if characterName or displayName then
            isLocalPlayer = isLocalPlayer == true or (localPlayerEntryIndex > 0 and localPlayerEntryIndex == i)
            local player = {
                entryIndex = i,
                characterName = zo_strformat(SI_PLAYER_NAME, characterName or ""),
                displayName = zo_strformat(SI_PLAYER_NAME, displayName or ""),
                alliance = battlegroundAlliance,
                isLocalPlayer = isLocalPlayer,
                classId = Num(GetScoreboardEntryClassId(i, roundIndex)),
                kills = Score(i, SCORE_TRACKER_TYPE_KILL, roundIndex, aggregate),
                deaths = Score(i, SCORE_TRACKER_TYPE_DEATH, roundIndex, aggregate),
                assists = Score(i, SCORE_TRACKER_TYPE_ASSISTS, roundIndex, aggregate),
                damage = Score(i, SCORE_TRACKER_TYPE_DAMAGE_DONE, roundIndex, aggregate),
                healing = Score(i, SCORE_TRACKER_TYPE_HEALING_DONE, roundIndex, aggregate),
                score = Score(i, SCORE_TRACKER_TYPE_SCORE, roundIndex, aggregate),
            }
            player.kd = CalculateTeamKD(player.kills, player.deaths)
            players[#players + 1] = player
        end
    end

    table.sort(players, function(a, b)
        if a.alliance == b.alliance then
            return (a.score or 0) > (b.score or 0)
        end
        return (a.alliance or 0) < (b.alliance or 0)
    end)

    local winner, winningScore = DetermineWinnerForCapture(scores, captureContext)
    local playerAlliance = nil
    local localCharacterName = nil
    local localDisplayName = nil
    local localClassId = tonumber(GetUnitClassId("player")) or 0
    local localCharacterId = GetCurrentCharacterIdOrNil()
    local localPlayer = nil
    for _, player in ipairs(players) do
        if player.isLocalPlayer then
            localPlayer = player
            playerAlliance = player.alliance
            localCharacterName = player.characterName
            localDisplayName = player.displayName
            localClassId = player.classId or localClassId
            break
        end
    end
    if playerAlliance == nil then
        local unitTeam = Num(GetUnitBattlegroundTeam("player"))
        if unitTeam > 0 then playerAlliance = unitTeam end
    end

    local savedSummary = BuildSavedMatchSummary(scores, players, winner, playerAlliance)
    -- GetTimeStamp() is already a server (UTC) Unix epoch timestamp, so it is stored
    -- directly. No timezone reconstruction is performed (it was the source of sort bugs).
    local localCapturedAt = GetTimeStamp()
    local capturedAt = localCapturedAt
    local performanceEndedAt = BL.currentBattlegroundTimersFrozen and Num(BL.currentBattlegroundFrozenAt) or localCapturedAt
    if performanceEndedAt <= 0 then performanceEndedAt = localCapturedAt end
    local deadSeconds = BL.GetCurrentBattlegroundDeadSeconds(performanceEndedAt)
    local combatSeconds = BL.GetCurrentBattlegroundCombatSeconds(performanceEndedAt)
    local durationSeconds, localDeadSeconds, localCombatSeconds, localActiveSeconds, localDps, localHps = CalculateLocalPerformance(localPlayer, BL.currentBattlegroundEnteredAt, performanceEndedAt, combatSeconds, deadSeconds)

    local match = {
        id = nil,
        capturedAt = capturedAt,
        gameType = gameType,
        battlegroundId = bgId,
        battlegroundName = battlegroundMetadata.name,
        battlegroundInfoTexture = battlegroundMetadata.infoTexture,
        battlegroundTeamSize = battlegroundMetadata.teamSize,
        battlegroundNumTeams = battlegroundMetadata.numTeams,
        battleground = battlegroundMetadata,
        localDurationSeconds = durationSeconds,
        localDeadSeconds = localDeadSeconds,
        localCombatSeconds = localCombatSeconds,
        localActiveSeconds = localActiveSeconds,
        localQueueSeconds = BL.queueCacheSeconds or BL.currentBattlegroundQueueSeconds,
        localDps = localDps,
        localHps = localHps,
        characterName = localCharacterName or GetCurrentCharacterName(),
        characterId = localCharacterId,
        localDisplayName = localDisplayName or zo_strformat(SI_PLAYER_NAME, GetUnitDisplayName("player") or ""),
        localClassId = localClassId,
        winner = winner,
        winningScore = winningScore,
        playerAlliance = playerAlliance,
        playerResult = savedSummary.playerResult,
        playerResultDisplay = savedSummary.playerResultDisplay,
        teamSummaries = savedSummary.teamSummaries,
        playerContribution = savedSummary.playerContribution,
        scores = scores,
        players = players,
    }

    return match
end
