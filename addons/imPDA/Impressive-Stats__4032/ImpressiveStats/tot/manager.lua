local IMP_STATS_SHARED = IMP_STATS_SHARED

local addon = {}

addon.name = 'IMP_STATS_TRIBUTE_MANAGER'
addon.playerData = nil

local EVENT_NAMESPACE = 'IMP_STATS_TRIBUTE_MANAGER'

local Log = IMP_STATS_Logger('TRIBUTE_MANAGER')

local function GetOpponentData(opponentName)
    local numEntries = GetNumTributeLeaderboardEntries(TRIBUTE_LEADERBOARD_TYPE_RANKED)
    for i = 1, numEntries do
        local rank, displayName, characterName, score = GetTributeLeaderboardEntryInfo(TRIBUTE_LEADERBOARD_TYPE_RANKED, i)
        if displayName == opponentName then return true, rank, displayName, characterName, score end
    end

    return false
end

--#region Game
local PENDING = 1
local READY = 2

local mt = {
    __call = function(cls)
        local tbl = setmetatable({}, cls)

        tbl:__init()

        return tbl
    end
}

local Game = setmetatable({}, mt)
Game.__index = Game

-- function Game:New(o)
--     o = o or {}

--     setmetatable(o, self)
--     self.__index = self

--     self.Initialize(o)

--     return o
-- end

function Game:__init()
    self.timestamp = GetTimeStamp()
    self.gameOver = false

    local name, playerType = GetTributePlayerInfo(TRIBUTE_PLAYER_PERSPECTIVE_SELF)

    self.player = {
        name = name,
        atStart = {},
        atEnd = {},
    }

    local oppName, oppPlayerType = GetTributePlayerInfo(TRIBUTE_PLAYER_PERSPECTIVE_OPPONENT)

    -- TODO: oppPlayerType

    self.opponent = {
        name = oppName,
        atStart = {},
        atEnd = {},
    }

    self:UpdatePlayerRank()
    self:UpdatePlayerMMR()

    -- TODO: opp rank
    self:UpdateOpponentRankAndMMR()
end

function Game:UpdatePlayerRank(skipRequest)
    local type = self.gameOver and 'final' or 'starting'
    -- Log('[Game] Updating player\'s %s rank', type)
    local tbl = self.gameOver and self.player.atEnd or self.player.atStart

    if not tbl.rankStatus then
        tbl.rankStatus = PENDING
        EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_TRIBUTE_LEADERBOARD_RANK_RECEIVED, function()
            Log('!!!!!!!!!! Rank received')
            self:UpdatePlayerRank(true)
            Log('MMR status: %d', tbl.mmrStatus)
            if not tbl.mmrStatus == READY then self:UpdatePlayerMMR() end
        end)
        Log('[Game] Waiting for player\'s %s rank update', type)
    end

    if not skipRequest then Log('[Game] Sending request for rank') end

    if skipRequest or RequestTributeLeaderboardRank() == LEADERBOARD_DATA_READY then
        local playerLeaderboardRank, totalLeaderboardPlayers = GetTributeLeaderboardRankInfo()
        local topPercent = playerLeaderboardRank == 0 and 1 or playerLeaderboardRank / totalLeaderboardPlayers

        tbl.rank = math.abs(playerLeaderboardRank)
        tbl.topP = math.abs(topPercent)

        tbl.rankStatus = READY
        Log('[Game] Player\'s %s rank updated', type)
        EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_TRIBUTE_LEADERBOARD_RANK_RECEIVED)
    end
end

function Game:UpdatePlayerMMR(skipRequest)
    local type = self.gameOver and 'final' or 'starting'
    -- Log('[Game] Updating player\'s %s MMR', type)
    local tbl = self.gameOver and self.player.atEnd or self.player.atStart

    if not tbl.mmrStatus then
        tbl.mmrStatus = PENDING
        EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_TRIBUTE_LEADERBOARD_DATA_RECEIVED, function()
            self:UpdatePlayerMMR(true)
            Log('[Game] Rank status: %d', tbl.rankStatus)
            -- if tbl.rankStatus ~= READY then self:UpdatePlayerRank() end
            self:UpdatePlayerRank()
        end)
        Log('[Game] Waiting for player\'s %s MMR updates', type)
    end

    if not skipRequest then Log('[Game] Sending request for MMR') end

    if skipRequest or QueryTributeLeaderboardData(TRIBUTE_LEADERBOARD_TYPE_RANKED) == LEADERBOARD_DATA_READY then
        local _, score = GetTributeLeaderboardLocalPlayerInfo(TRIBUTE_LEADERBOARD_TYPE_RANKED)

        tbl.mmr = math.abs(score)

        tbl.mmrStatus = READY
        Log('[Game] Player\'s %s MMR updated', type)
        EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_TRIBUTE_LEADERBOARD_DATA_RECEIVED)
    end
end

function Game:UpdateOpponentRankAndMMR()
    local opponent = self.opponent
    local inLadder, rank, displayName, characterName, score = GetOpponentData(opponent.name)

    if inLadder then
        if self.gameOver then
            if opponent.atStart.mmr ~= score then
                opponent.atEnd.mmr = score
                opponent.atEnd.rank = rank
            else
                -- TODO: ensure it will not cause problems
                zo_callLater(function() self:UpdateOpponentRankAndMMR() end, 1500)
            end
        else
            opponent.atStart.mmr = score
            opponent.atStart.rank = rank
        end
    end
end

function Game:PredictMMRChange()
    if
    not self.player or
    not self.player.atStart or
    not self.player.atStart.mmr or
    not self.opponent or
    not self.opponent.atStart or
    not self.opponent.atStart.mmr
    then return end

    local playerMMR = self.player.atStart.mmr
    local opponentMMR = self.opponent.atStart.mmr

    local difference = playerMMR - opponentMMR
    local predict1 = 125.0 - 0.0896 * difference + 0.00002 * difference^2
    local predict2 = 99.6 - 0.0766 * difference + 0.0000269 * difference^2
    local predict3 = -89.7 - 0.0675 * difference - 0.0000332 * difference^2

    return predict1, predict2, predict3
end

function Game:AddPatronPicks()
    self.patrons = {}
    for patronDraftId = 0, 3 do
        self.patrons[patronDraftId] = GetDraftedPatronId(patronDraftId)
    end
end

-- function Game:UpdateScore(name)
--     local found, rank, displayName, characterName, score = GetOpponentData(name)
--     Log('Updated rank: %d (#%d)', score, rank)
--     EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_TRIBUTE_LEADERBOARD_DATA_RECEIVED)
-- end

--[[
function IMP_TOTGame:InitializeOpponent()
    local name, playerType = GetTributePlayerInfo(TRIBUTE_PLAYER_PERSPECTIVE_OPPONENT)

    self.opponent = {
        name = name,
    }

    -- if playerType == TRIBUTE_PLAYER_TYPE_PLAYER or playerType == TRIBUTE_PLAYER_TYPE_REMOTE_PLAYER then
    --     local found, rank, displayName, characterName, score = GetOpponentData(name)

    --     self.opponent.atStart = {
    --         mmr = found and score or 0,
    --         rank = found and rank or 0,
    --         -- topP = topPercent
    --     }
    --     Log('Rank: %d (#%d)', score, rank)
    -- end

    -- EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_TRIBUTE_LEADERBOARD_DATA_RECEIVED, function() self:UpdateScore(name) end)
    -- QueryTributeLeaderboardData(TRIBUTE_LEADERBOARD_TYPE_RANKED)
end
]]

function Game:AddFirstPick()
    self.fp = GetActiveTributePlayerPerspective() == TRIBUTE_PLAYER_PERSPECTIVE_SELF
    Log('Fist pick: %s', tostring(self.fp))
end

function Game:WriteGameResults()
    Log('[Game] Getting results')
    --A
    local winner, victoryType = GetTributeResultsWinnerInfo()

    self.win = winner == TRIBUTE_PLAYER_PERSPECTIVE_SELF
    self.victoryType = victoryType

    -- B
    local matchDurationMS, goldAccumulated, cardsAcquired = GetTributeMatchStatistics()
    self.duration = matchDurationMS
    self.player.goldAccumulated = goldAccumulated
    self.player.cardsAcquired = cardsAcquired

    -- C
    local playerScore = GetTributePlayerPerspectiveResource(TRIBUTE_PLAYER_PERSPECTIVE_SELF, TRIBUTE_RESOURCE_PRESTIGE)
    local opponentScore = GetTributePlayerPerspectiveResource(TRIBUTE_PLAYER_PERSPECTIVE_OPPONENT, TRIBUTE_RESOURCE_PRESTIGE)
    self.player.score = playerScore
    self.opponent.score = opponentScore
end

function Game:OnGameOver()
    self.gameOver = true

    self:WriteGameResults()

    self:UpdatePlayerRank()
    self:UpdatePlayerMMR()

    self:UpdateOpponentRankAndMMR()
end
--#endregion Game

--#region ADDON
function addon:SaveCurrentGame()
    self.games[#self.games+1] = self.currentGame
    self.currentGame = nil
    Log('Game saved, id: %d', #self.games)
end

function addon:UpdateOpponentPreview()
    local opponent = self.currentGame.opponent

    GetControl(self.previewControl, 'OpponentName'):SetText(opponent.name)

    local gamesPlayedBefore, totalWinrate, FPWinrate, SPWinrate = IMP_STATS_TRIBUTE_STATS_MANAGER:GetStatsVS(opponent.name)
    local playedBeforeText = gamesPlayedBefore and ('Played %d games'):format(gamesPlayedBefore) or 'Not played before'
    local winrateValueText = gamesPlayedBefore and ('%.1f %%'):format(IMP_STATS_SHARED.PossibleNan(totalWinrate) * 100) or '-'
    GetControl(self.previewControl, 'PlayedBefore'):SetText(playedBeforeText)
    GetControl(self.previewControl, 'WinrateValue'):SetText(winrateValueText)

    -- local inLadder, rank, displayName, characterName, mmr = GetOpponentData(opponent.name)
    local rank = opponent.atStart.rank
    local mmr = opponent.atStart.mmr
    local opponentRankText = rank and ('Ladder #%d (%d MMR)'):format(rank, mmr) or 'Not in top-100'
    GetControl(self.previewControl, 'OpponentRank'):SetText(opponentRankText)

    local note = IMP_STATS_NOTES_MANAGER:GetNote(opponent.name)
    GetControl(self.previewControl, 'NoteIcon'):SetHidden(note == nil)
    GetControl(self.previewControl, 'AddNoteIcon'):SetHidden(note ~= nil)
end

function addon:ShowOpponentPreview()
    -- update preview data
    self.previewControl:SetHidden(false)
end

function addon:HideOpponentPreview()
    self.previewControl:SetHidden(true)
end

function addon:OnIntro()
    Log('Game started')

    if GetTributeMatchType() ~= TRIBUTE_MATCH_TYPE_COMPETITIVE then
        Log('Not competitive game')
        -- return
    end

    self.currentGame = Game()

    -- self.currentGame:AddPlayerData()
    -- self.currentGame:AddOpponentData()
end

function addon:OnPatronDraft()
    self.currentGame:AddFirstPick()

    self:UpdateOpponentPreview()
    self:ShowOpponentPreview()
end

function addon:OnGameStarted()
    self.currentGame:AddPatronPicks()
end

function addon:OnGameOver()
    Log('Game over')
    if not self.currentGame then return end

    self.currentGame:OnGameOver()
    -- self.currentGame:AddResults()
    self:SaveCurrentGame()
    self:HideOpponentPreview()

    -- TODO: find better solution
    -- since rating and mmr updated asyncronously, there is situation when
    -- ui starts to update but mmr or rank not updated yet and equal 'nil'
    zo_callLater(function() IMP_STATS_TRIBUTE_UI:Update() end, 2000)
end

function addon:OnGameState(state)
    Log('Game state: %d', state)
    if state == TRIBUTE_GAME_FLOW_STATE_INTRO then
        self:OnIntro()
    elseif state == TRIBUTE_GAME_FLOW_STATE_PATRON_DRAFT then
        self:OnPatronDraft()
    elseif state == TRIBUTE_GAME_FLOW_STATE_PLAYING then
        self:OnGameStarted()
    elseif state == TRIBUTE_GAME_FLOW_STATE_GAME_OVER then
        self:OnGameOver()
    end
end

function addon:PlayerActivated(initial)
    local function OnTributeGameFlowStateChanged(_, state)
        self:OnGameState(state)
    end

    EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_TRIBUTE_GAME_FLOW_STATE_CHANGE, OnTributeGameFlowStateChanged)
    -- EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_TRIBUTE_PATRON_DRAFTED, function(...) Log(...) end)

    IMP_STATS_TRIBUTE_UI:Update()
end

function addon:GetGamesWith(task, opponentName, tbl)
    local function ContainsName(searchedName)
        searchedName = string.lower(searchedName)
        local function inner(data)
            return string.find(string.lower(data.opponent.name), searchedName)
        end

        return inner
    end

    local escapedOpponentName = opponentName:gsub('%-', '%%-')
    local nameFilter = ContainsName(escapedOpponentName)

    return self:GetGames(task, {nameFilter}, tbl)
end

function addon:GetGames(task, filters, tbl)
    local function PassFilters(data)
        for _, filter in ipairs(filters) do
            if not filter(data) then return end
        end

        return true
    end

    local function FilterGames(gameIndex, gameData)
        if PassFilters(gameData) then table.insert(tbl, gameIndex) end
    end

    return task:For(ipairs(self.games)):Do(FilterGames)
end
--#endregion ADDON

local function OnPlayerActivated(_, initial)
    addon:PlayerActivated(initial)
end

function IMP_STATS_InitializeTributeManager(settings, characterSettings)
    IMP_STATS_NotesManager_Initialize()

    IMP_STATS_TRIBUTE_MANAGER = addon

    IMP_STATS_TRIBUTE_MANAGER.settings = settings

    local server = string.sub(GetWorldName(), 1, 2)
    IMP_STATS_TRIBUTE_MANAGER.playerData = {
        name = GetDisplayName(),
    }

    ImpressiveStatsTributeData = ImpressiveStatsTributeData or {}
    ImpressiveStatsTributeData[server] = ImpressiveStatsTributeData[server] or {}

    IMP_STATS_TRIBUTE_MANAGER.games = ImpressiveStatsTributeData[server]
    Log('There are %d games saved', #addon.games)

    EVENT_MANAGER:RegisterForEvent(IMP_STATS_TRIBUTE_MANAGER.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    IMP_STATS_TRIBUTE_UI:Initialize(settings.namingMode, characterSettings.selectedCharacters)

    IMP_STATS_TRIBUTE_MANAGER.previewControl = IMP_STATS_TributeOpponentPreview
    do
        if settings.opponentPreview and settings.opponentPreview.anchor then
            local anchor = settings.opponentPreview.anchor
            IMP_STATS_TRIBUTE_MANAGER.previewControl:ClearAnchors()
            IMP_STATS_TRIBUTE_MANAGER.previewControl:SetAnchor(anchor[1], nil, anchor[3], anchor[4], anchor[5])
        end
    end

    local function ChangeOpponentPreviewIconVisibility()
        local name, playerType = GetTributePlayerInfo(TRIBUTE_PLAYER_PERSPECTIVE_OPPONENT)
        local note = IMP_STATS_NOTES_MANAGER:GetNote(name)
        GetControl(IMP_STATS_TRIBUTE_MANAGER.previewControl, 'NoteIcon'):SetHidden(note == nil)
        GetControl(IMP_STATS_TRIBUTE_MANAGER.previewControl, 'AddNoteIcon'):SetHidden(note ~= nil)
    end
    IMP_STATS_NOTES_MANAGER:RegisterCallback(EVENT_NAMESPACE, IMP_STATS_NOTES_MANAGER.events.EVENT_NOTE_EDITED, ChangeOpponentPreviewIconVisibility)

    Log('Leaderboard: %s', tostring(settings.leaderboard))
    if settings.leaderboard then
        IMP_STATS_TributeLeaderboard_Initialize()
    end

    SLASH_COMMANDS['/impspredict'] = function()
        local currentGame = IMP_STATS_TRIBUTE_MANAGER.currentGame
        if not currentGame then
            Log('No game to calculate prediction for')
            return
        end

        local p1, p2, p3 = currentGame:PredictMMRChange()

        if not p1 then
            Log('No prediction to print')
            return
        end

        df('[ToT Rank] Prediction: +%d or +%d / -%d', p1, p2, p3)
    end
end

-- function FindGamesByName(name)
--     Log('Searching for %s', name)
--     local games = {}

--     local task = LibAsync:Create('TestOpponentSearch')
--     IMP_STATS_TRIBUTE_MANAGER:GetGamesWith(task, name, games):Then(function()
--         Log('%d found', #games)
--     end)
-- end

-- SLASH_COMMANDS['/imptotf'] = FindGamesByName