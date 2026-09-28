HighLow = HighLow or {}
local HL = HighLow

HL.name = "HighLow"
HL.displayName = "High-Low"
HL.version = "0.1.9"
HL.savedVersion = 1

ZO_CreateStringId("SI_KEYBINDINGS_CATEGORY_HIGHLOW", "High-Low")
ZO_CreateStringId("SI_BINDING_NAME_HIGHLOW_TOGGLE_WINDOW", "Toggle High-Low Window")

local WM = WINDOW_MANAGER

local STATE_IDLE = "IDLE"
local STATE_ENTRIES_OPEN = "ENTRIES_OPEN"
local STATE_ENTRIES_CLOSED = "ENTRIES_CLOSED"
local STATE_ROLLS_OPEN = "ROLLS_OPEN"
local STATE_ROLLS_CLOSED = "ROLLS_CLOSED"
local STATE_TIE_ROLLS_OPEN = "TIE_ROLLS_OPEN"
local STATE_TIE_ROLLS_CLOSED = "TIE_ROLLS_CLOSED"

local RED = "|cE65A5A"
local GREEN = "|c67D56B"
local GOLD = "|cD9B65D"
local GRAY = "|cAAAAAA"
local WHITE = "|cFFFFFF"
local RESET = "|r"

local defaults = {
    entryTrigger = "!hl",
    startEntriesMessage = "High-Low for {ROLL} gold starting! Type {trigger} in group chat to enter.",
    closeEntriesMessage = "High-Low entries are now closed! Type /roll {ROLL}",
    closeRollsMessage = "High-Low rolls are now closed!",
    rollMax = 100,
    windowX = nil,
    windowY = nil,
}

local historyDefaults = {
    history = {},
    migratedLegacy = false,
}

HL.state = STATE_IDLE
HL.players = {}
HL.playerOrder = {}
HL.tieResolution = nil
HL.ui = {}
HL.maxHistory = 100

-- ============================================================================
-- My lil helpers
-- ============================================================================

local function Trim(value)
    value = tostring(value or "")
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function StripDisplayNamePrefix(name)
    local cleaned = Trim(name)
    return (cleaned:gsub("^@", ""))
end

local function NormalizeDisplayName(name)
    return string.lower(StripDisplayNamePrefix(name))
end

local function SafeNumber(value, fallback)
    local numberValue = tonumber(value)
    if not numberValue then
        return fallback
    end
    return math.floor(numberValue)
end

local function FormatGold(value)
    if ZO_CommaDelimitNumber then
        return ZO_CommaDelimitNumber(value)
    end
    return tostring(value)
end

function HL:Debug(message)
    d(string.format("[%s] %s", self.displayName, tostring(message)))
end

function HL:SetLocalStatus(message, isError)
    if not self.ui.status then return end
    self.ui.status:SetText(message or "")
    if isError then
        self.ui.status:SetColor(1, 0.35, 0.35, 1)
    else
        self.ui.status:SetColor(0.82, 0.72, 0.52, 1)
    end
end

-- ============================================================================
-- Player + roll helpers
-- ============================================================================

function HL:GetPlayerCount()
    return #self.playerOrder
end

function HL:GetRolledCount()
    local count = 0
    for _, key in ipairs(self.playerOrder) do
        local player = self.players[key]
        if player and player.roll ~= nil then
            count = count + 1
        end
    end
    return count
end

function HL:GetTieWaitingCount()
    local count = 0
    for _, key in ipairs(self.playerOrder) do
        local player = self.players[key]
        if player and player.needsTieRoll then
            count = count + 1
        end
    end
    return count
end

function HL:GetPlayersNeedingRoll()
    local names = {}

    if self.state == STATE_ROLLS_OPEN or self.state == STATE_ROLLS_CLOSED then
        for _, key in ipairs(self.playerOrder) do
            local player = self.players[key]
            if player and player.roll == nil then
                table.insert(names, player.displayName)
            end
        end
    elseif self.state == STATE_TIE_ROLLS_OPEN or self.state == STATE_TIE_ROLLS_CLOSED then
        for _, key in ipairs(self.playerOrder) do
            local player = self.players[key]
            if player and player.needsTieRoll and player.tieRoll == nil then
                table.insert(names, player.displayName)
            end
        end
    end

    return names
end

function HL:AnnouncePlayersNeedingRoll()
    local names = self:GetPlayersNeedingRoll()
    if #names == 0 then return end
    self:PrefillGroupChat("Needs to Roll: " .. table.concat(names, ", "))
end

function HL:AllInitialRollsComplete()
    if self:GetPlayerCount() < 2 then return false end
    for _, key in ipairs(self.playerOrder) do
        local player = self.players[key]
        if not player or player.roll == nil then
            return false
        end
    end
    return true
end

function HL:AllTieRollsComplete()
    local hasTiePlayers = false
    for _, key in ipairs(self.playerOrder) do
        local player = self.players[key]
        if player and player.needsTieRoll then
            hasTiePlayers = true
            if player.tieRoll == nil then
                return false
            end
        end
    end
    return hasTiePlayers
end

function HL:IsDisplayNameInCurrentGroup(displayName)
    local normalized = NormalizeDisplayName(displayName)
    if normalized == "" then return false end

    if normalized == NormalizeDisplayName(GetDisplayName()) then
        return IsUnitGrouped("player")
    end

    local groupSize = GetGroupSize()
    for index = 1, groupSize do
        local unitTag = GetGroupUnitTagByIndex(index)
        if unitTag and unitTag ~= "" and DoesUnitExist(unitTag) then
            if NormalizeDisplayName(GetUnitDisplayName(unitTag)) == normalized then
                return true
            end
        end
    end
    return false
end

function HL:GetConfiguredRollMax()
    local maxValue = SafeNumber(self.saved.rollMax, 100)
    if maxValue < 2 then maxValue = 2 end
    if RANDOM_ROLL_MAX_RESULT and maxValue > RANDOM_ROLL_MAX_RESULT then
        maxValue = RANDOM_ROLL_MAX_RESULT
    end
    return maxValue
end

-- ============================================================================
-- Chat message stuff
-- ============================================================================

function HL:ExpandMessage(message)
    local text = tostring(message or "")
    return (text:gsub("{([%a]+)}", function(token)
        local originalToken = token
        token = string.upper(token)
        if token == "ROLL" then
            return tostring(self:GetConfiguredRollMax())
        elseif token == "COUNT" then
            return tostring(self:GetPlayerCount())
        elseif token == "TRIGGER" then
            return tostring(self.saved.entryTrigger or defaults.entryTrigger)
        end
        return "{" .. originalToken .. "}"
    end))
end

function HL:PrefillGroupChat(message)
    local text = self:ExpandMessage(message)
    if text == "" then return end
    StartChatInput(text, CHAT_CHANNEL_PARTY)
end

-- ============================================================================
-- Event listeners
-- ============================================================================

function HL:RegisterEntryListener()
    EVENT_MANAGER:UnregisterForEvent(self.name .. "Entries", EVENT_CHAT_MESSAGE_CHANNEL)
    EVENT_MANAGER:RegisterForEvent(self.name .. "Entries", EVENT_CHAT_MESSAGE_CHANNEL,
        function(...) self:OnChatMessage(...) end)
end

function HL:UnregisterEntryListener()
    EVENT_MANAGER:UnregisterForEvent(self.name .. "Entries", EVENT_CHAT_MESSAGE_CHANNEL)
end

function HL:RegisterRollListener()
    EVENT_MANAGER:UnregisterForEvent(self.name .. "Rolls", EVENT_RANDOM_RANGE_ROLL)
    EVENT_MANAGER:RegisterForEvent(self.name .. "Rolls", EVENT_RANDOM_RANGE_ROLL,
        function(...) self:OnRandomRangeRoll(...) end)
end

function HL:UnregisterRollListener()
    EVENT_MANAGER:UnregisterForEvent(self.name .. "Rolls", EVENT_RANDOM_RANGE_ROLL)
end

-- ============================================================================
-- Starting, stopping, and running a round
-- ============================================================================

function HL:ClearRound()
    self:UnregisterEntryListener()
    self:UnregisterRollListener()
    self.players = {}
    self.playerOrder = {}
    self.tieResolution = nil
    self.state = STATE_IDLE
    self:RefreshUI()
end

function HL:ResetRound()
    self:ClearRound()
    self:SetLocalStatus("Round reset. Ready for a new game.", false)
end

function HL:AddPlayer(displayName, characterName)
    local key = NormalizeDisplayName(displayName)
    if key == "" or self.players[key] then return false end

    self.players[key] = {
        displayName = StripDisplayNamePrefix(displayName),
        characterName = characterName or "",
        roll = nil,
        tieRoll = nil,
        needsTieRoll = false,
    }
    table.insert(self.playerOrder, key)
    self:RefreshUI()
    return true
end

function HL:OnChatMessage(_, channelType, fromName, messageText, isCustomerService, fromDisplayName)
    if self.state ~= STATE_ENTRIES_OPEN then return end
    if channelType ~= CHAT_CHANNEL_PARTY then return end
    if isCustomerService then return end

    local trigger = string.lower(Trim(self.saved.entryTrigger))
    local message = string.lower(Trim(messageText))
    if trigger == "" or message ~= trigger then return end

    local displayName = Trim(fromDisplayName)
    if displayName == "" then return end
    if not self:IsDisplayNameInCurrentGroup(displayName) then return end

    self:AddPlayer(displayName, fromName)
end

function HL:OnRandomRangeRoll(_, displayName, characterName, minValue, maxValue, rollResult)
    if self.state ~= STATE_ROLLS_OPEN and self.state ~= STATE_TIE_ROLLS_OPEN then return end

    local key = NormalizeDisplayName(displayName)
    local player = self.players[key]
    if not player then return end
    if not self:IsDisplayNameInCurrentGroup(displayName) then return end

    local expectedMax = self:GetConfiguredRollMax()
    if minValue ~= 1 or maxValue ~= expectedMax then
        return
    end

    if self.state == STATE_ROLLS_OPEN then
        if player.roll ~= nil then return end
        player.roll = rollResult
        player.characterName = characterName or player.characterName
    else
        if not player.needsTieRoll or player.tieRoll ~= nil then return end
        player.tieRoll = rollResult
        player.characterName = characterName or player.characterName
    end

    self:RefreshUI()
end

function HL:StartEntries()
    if self.state ~= STATE_IDLE then return end
    if not IsUnitGrouped("player") or GetGroupSize() < 2 then
        self:SetLocalStatus("You must be in a group with at least two players to start High-Low.", true)
        return
    end

    self.players = {}
    self.playerOrder = {}
    self.tieResolution = nil
    self.state = STATE_ENTRIES_OPEN
    self:RegisterEntryListener()
    self:PrefillGroupChat(self.saved.startEntriesMessage)
    self:RefreshUI()
end

function HL:CloseEntriesAndStartRolls()
    if self.state ~= STATE_ENTRIES_OPEN then return end
    if self:GetPlayerCount() < 2 then
        self:SetLocalStatus("At least two entries are required before rolls can start.", true)
        return
    end

    self:UnregisterEntryListener()
    for _, key in ipairs(self.playerOrder) do
        local player = self.players[key]
        player.roll = nil
        player.tieRoll = nil
        player.needsTieRoll = false
    end

    self.state = STATE_ROLLS_OPEN
    self:RegisterRollListener()
    self:PrefillGroupChat(self.saved.closeEntriesMessage)
    self:RefreshUI()
end

function HL:StartRolls(reopening)
    if self.state ~= STATE_ROLLS_CLOSED then return end
    if self:GetPlayerCount() < 2 then return end
    if not reopening then return end

    self.state = STATE_ROLLS_OPEN
    self:RegisterRollListener()
    self:RefreshUI()
end

function HL:CloseRolls()
    if self.state ~= STATE_ROLLS_OPEN then return end
    self.state = STATE_ROLLS_CLOSED
    self:UnregisterRollListener()
    self:PrefillGroupChat(self.saved.closeRollsMessage)
    self:RefreshUI()
end

-- ============================================================================
-- Winner + tie stuff
-- ============================================================================

function HL:GetInitialExtremes()
    local highestValue = nil
    local lowestValue = nil
    local highestKeys = {}
    local lowestKeys = {}

    for _, key in ipairs(self.playerOrder) do
        local value = self.players[key].roll
        if value ~= nil then
            if highestValue == nil or value > highestValue then
                highestValue = value
                highestKeys = { key }
            elseif value == highestValue then
                table.insert(highestKeys, key)
            end

            if lowestValue == nil or value < lowestValue then
                lowestValue = value
                lowestKeys = { key }
            elseif value == lowestValue then
                table.insert(lowestKeys, key)
            end
        end
    end

    return highestValue, highestKeys, lowestValue, lowestKeys
end

local function CopyArray(source)
    local result = {}
    for index, value in ipairs(source or {}) do
        result[index] = value
    end
    return result
end

function HL:PrepareTieResolution(highestKeys, lowestKeys)
    self.tieResolution = {
        winnerKey = (#highestKeys == 1) and highestKeys[1] or nil,
        loserKey = (#lowestKeys == 1) and lowestKeys[1] or nil,
        highCandidates = (#highestKeys > 1) and CopyArray(highestKeys) or nil,
        lowCandidates = (#lowestKeys > 1) and CopyArray(lowestKeys) or nil,
    }
    self:BeginTieRollRound()
end

function HL:MarkTiePlayersWaiting()
    local waiting = {}
    local resolution = self.tieResolution

    if resolution.highCandidates then
        for _, key in ipairs(resolution.highCandidates) do waiting[key] = true end
    end
    if resolution.lowCandidates then
        for _, key in ipairs(resolution.lowCandidates) do waiting[key] = true end
    end

    for _, key in ipairs(self.playerOrder) do
        local player = self.players[key]
        player.needsTieRoll = waiting[key] == true
        player.tieRoll = nil
    end
end

function HL:BeginTieRollRound()
    self:MarkTiePlayersWaiting()
    self.state = STATE_TIE_ROLLS_OPEN
    self:RegisterRollListener()
    self:RefreshUI()
end

function HL:CloseTieRolls()
    if self.state ~= STATE_TIE_ROLLS_OPEN then return end
    self.state = STATE_TIE_ROLLS_CLOSED
    self:UnregisterRollListener()
    self:RefreshUI()
end

function HL:ResolveTieCandidateSet(candidates, chooseHighest)
    local extreme = nil
    local tied = {}

    for _, key in ipairs(candidates or {}) do
        local player = self.players[key]
        local value = player and player.tieRoll or nil
        if value ~= nil then
            if extreme == nil or (chooseHighest and value > extreme) or ((not chooseHighest) and value < extreme) then
                extreme = value
                tied = { key }
            elseif value == extreme then
                table.insert(tied, key)
            end
        end
    end

    if #tied == 1 then
        return tied[1], nil, extreme
    end
    return nil, tied, extreme
end

function HL:ResolveTieRound()
    local resolution = self.tieResolution
    if not resolution then return end

    if resolution.highCandidates then
        local winnerKey, stillTied, decidingRoll = self:ResolveTieCandidateSet(resolution.highCandidates, true)
        if winnerKey then
            resolution.winnerKey = winnerKey
            resolution.winnerTieRoll = decidingRoll
            resolution.highCandidates = nil
        else
            resolution.highCandidates = stillTied
        end
    end

    if resolution.lowCandidates then
        local loserKey, stillTied, decidingRoll = self:ResolveTieCandidateSet(resolution.lowCandidates, false)
        if loserKey then
            resolution.loserKey = loserKey
            resolution.loserTieRoll = decidingRoll
            resolution.lowCandidates = nil
        else
            resolution.lowCandidates = stillTied
        end
    end

    if resolution.winnerKey and resolution.loserKey then
        self:FinishGame(resolution.winnerKey, resolution.loserKey)
    else
        self:BeginTieRollRound()
    end
end

function HL:SelectWinner()
    if self.state == STATE_ROLLS_CLOSED then
        if not self:AllInitialRollsComplete() then return end

        local highestValue, highestKeys, lowestValue, lowestKeys = self:GetInitialExtremes()
        if not highestValue or not lowestValue then return end

        if #highestKeys == 1 and #lowestKeys == 1 then
            self:FinishGame(highestKeys[1], lowestKeys[1])
        else
            self:PrepareTieResolution(highestKeys, lowestKeys)
        end
    elseif self.state == STATE_TIE_ROLLS_CLOSED then
        if not self:AllTieRollsComplete() then return end
        self:ResolveTieRound()
    end
end

-- ============================================================================
-- Game finishing stuff
-- ============================================================================

function HL:FinishGame(winnerKey, loserKey)
    local winner = self.players[winnerKey]
    local loser = self.players[loserKey]
    if not winner or not loser then return end

    local winnerRoll = winner.roll or 0
    local loserRoll = loser.roll or 0
    local amount = math.abs(winnerRoll - loserRoll)

    if amount == 0 and self.tieResolution then
        local resolvedWinnerRoll = self.tieResolution.winnerTieRoll
        local resolvedLoserRoll = self.tieResolution.loserTieRoll
        if resolvedWinnerRoll ~= nil and resolvedLoserRoll ~= nil then
            winnerRoll = resolvedWinnerRoll
            loserRoll = resolvedLoserRoll
            amount = math.abs(winnerRoll - loserRoll)
        end
    end

    local resultText = string.format("%s Wins! %s owes %s %s gold!",
        winner.displayName,
        loser.displayName,
        winner.displayName,
        FormatGold(amount))

    table.insert(self.historySaved.history, 1, {
        timestamp = GetTimeStamp(),
        winner = winner.displayName,
        loser = loser.displayName,
        amount = amount,
        winnerRoll = winnerRoll,
        loserRoll = loserRoll,
        text = resultText,
    })

    while #self.historySaved.history > self.maxHistory do
        table.remove(self.historySaved.history)
    end

    self:UnregisterEntryListener()
    self:UnregisterRollListener()

    self.players = {}
    self.playerOrder = {}
    self.tieResolution = nil
    self.state = STATE_IDLE

    self:PrefillGroupChat(resultText)
    self:RefreshUI()
    self:RefreshHistoryUI()
end

-- ============================================================================
-- Saved settings
-- ============================================================================

function HL:SaveMessageSettings()
    if not self.ui.entryTrigger then return end

    local trigger = Trim(self.ui.entryTrigger:GetText())
    if trigger == "" then trigger = defaults.entryTrigger end

    local rollMax = SafeNumber(self.ui.rollMax:GetText(), defaults.rollMax)
    if rollMax < 2 then rollMax = 2 end
    if RANDOM_ROLL_MAX_RESULT and rollMax > RANDOM_ROLL_MAX_RESULT then
        rollMax = RANDOM_ROLL_MAX_RESULT
    end

    self.saved.entryTrigger = trigger
    self.saved.startEntriesMessage = Trim(self.ui.startEntriesMessage:GetText())
    self.saved.closeEntriesMessage = Trim(self.ui.closeEntriesMessage:GetText())
    self.saved.closeRollsMessage = Trim(self.ui.closeRollsMessage:GetText())
    self.saved.rollMax = rollMax

    self.ui.entryTrigger:SetText(self.saved.entryTrigger)
    self.ui.rollMax:SetText(tostring(self.saved.rollMax))
end

function HL:ResetMessagesToDefaults()
    self.saved.entryTrigger = defaults.entryTrigger
    self.saved.startEntriesMessage = defaults.startEntriesMessage
    self.saved.closeEntriesMessage = defaults.closeEntriesMessage
    self.saved.closeRollsMessage = defaults.closeRollsMessage
    self.saved.rollMax = defaults.rollMax
    self:PopulateSettingsFields()
    self:SetLocalStatus("Message settings reset to defaults.", false)
end

function HL:PopulateSettingsFields()
    if not self.ui.entryTrigger then return end
    self.ui.entryTrigger:SetText(self.saved.entryTrigger or defaults.entryTrigger)
    self.ui.startEntriesMessage:SetText(self.saved.startEntriesMessage or defaults.startEntriesMessage)
    self.ui.closeEntriesMessage:SetText(self.saved.closeEntriesMessage or defaults.closeEntriesMessage)
    self.ui.closeRollsMessage:SetText(self.saved.closeRollsMessage or defaults.closeRollsMessage)
    self.ui.rollMax:SetText(tostring(self.saved.rollMax or defaults.rollMax))
end

function HL:UpdateSettingsEnabledState()
    local canEdit = self.state == STATE_IDLE
    local fields = {
        self.ui.entryTrigger,
        self.ui.startEntriesMessage,
        self.ui.closeEntriesMessage,
        self.ui.closeRollsMessage,
        self.ui.rollMax,
    }
    for _, field in ipairs(fields) do
        if field then
            field:SetEditEnabled(canEdit)
            field:SetMouseEnabled(canEdit)
            field:SetColor(canEdit and 1 or 0.6, canEdit and 1 or 0.6, canEdit and 1 or 0.6, 1)
        end
    end
    if self.ui.defaultsButton then self.ui.defaultsButton:SetEnabled(canEdit) end
    if self.ui.resetRoundButton then self.ui.resetRoundButton:SetEnabled(self.state ~= STATE_IDLE) end
end

-- ============================================================================
-- Keeping the main window up to date
-- ============================================================================

function HL:GetPlayerRowText(index, key)
    local player = self.players[key]
    if not player then return "" end

    if self.state == STATE_ROLLS_OPEN or self.state == STATE_ROLLS_CLOSED then
        if player.roll == nil then
            return string.format("%s%s%s", RED, player.displayName, RESET)
        end
        return string.format("%s%s%s    %s%d%s", GREEN, player.displayName, RESET, WHITE, player.roll, RESET)
    elseif self.state == STATE_TIE_ROLLS_OPEN or self.state == STATE_TIE_ROLLS_CLOSED then
        if player.needsTieRoll then
            if player.tieRoll == nil then
                return string.format("%s%s%s    %s%d%s  %s(reroll)%s", RED, player.displayName, RESET, GRAY, player.roll or 0, RESET, GRAY, RESET)
            end
            return string.format("%s%s%s    %s%d%s  %s→ %d%s", GREEN, player.displayName, RESET, GRAY, player.roll or 0, RESET, GOLD, player.tieRoll, RESET)
        end
        return string.format("%s%s%s    %s%d%s", GRAY, player.displayName, RESET, GRAY, player.roll or 0, RESET)
    end

    return player.displayName
end

function HL:RefreshPlayerRows()
    if not self.ui.playerRows then return end

    for index = 1, #self.ui.playerRows do
        local row = self.ui.playerRows[index]
        local key = self.playerOrder[index]
        if key then
            row:SetText(self:GetPlayerRowText(index, key))
            row:SetHidden(false)
        else
            row:SetText("")
            row:SetHidden(true)
        end
    end

    if self.ui.entriesCount then
        self.ui.entriesCount:SetText(string.format("%d player%s", self:GetPlayerCount(), self:GetPlayerCount() == 1 and "" or "s"))
    end
end

function HL:RefreshButtons()
    local entryButton = self.ui.entryButton
    local rollButton = self.ui.rollButton
    local winnerButton = self.ui.winnerButton
    if not entryButton then return end

    if self.state == STATE_IDLE then
        entryButton:SetText("START ENTRIES")
        entryButton:SetEnabled(true)
    elseif self.state == STATE_ENTRIES_OPEN then
        entryButton:SetText("CLOSE ENTRIES / START ROLLS")
        entryButton:SetEnabled(self:GetPlayerCount() >= 2)
    else
        entryButton:SetText("ENTRIES CLOSED")
        entryButton:SetEnabled(false)
    end

    if self.state == STATE_ROLLS_OPEN then
        rollButton:SetText("CLOSE ROLLS")
        rollButton:SetEnabled(true)
    elseif self.state == STATE_ROLLS_CLOSED then
        if self:AllInitialRollsComplete() then
            rollButton:SetText("ROLLS CLOSED")
            rollButton:SetEnabled(false)
        else
            rollButton:SetText("REOPEN ROLLS")
            rollButton:SetEnabled(true)
        end
    elseif self.state == STATE_TIE_ROLLS_OPEN then
        rollButton:SetText("CLOSE REROLLS")
        rollButton:SetEnabled(true)
    elseif self.state == STATE_TIE_ROLLS_CLOSED then
        if self:AllTieRollsComplete() then
            rollButton:SetText("REROLLS CLOSED")
            rollButton:SetEnabled(false)
        else
            rollButton:SetText("REOPEN REROLLS")
            rollButton:SetEnabled(true)
        end
    else
        rollButton:SetText("ROLLS NOT OPEN")
        rollButton:SetEnabled(false)
    end

    local winnerEnabled = (self.state == STATE_ROLLS_CLOSED and self:AllInitialRollsComplete())
        or (self.state == STATE_TIE_ROLLS_CLOSED and self:AllTieRollsComplete())
    winnerButton:SetEnabled(winnerEnabled)

    if self.ui.needsRollButton then
        self.ui.needsRollButton:SetEnabled(#self:GetPlayersNeedingRoll() > 0)
    end
end

function HL:RefreshStatus()
    local count = self:GetPlayerCount()
    if self.state == STATE_IDLE then
        self:SetLocalStatus("Ready. Open entries when your group is assembled.", false)
    elseif self.state == STATE_ENTRIES_OPEN then
        if count < 2 then
            self:SetLocalStatus(string.format("Entries open — type %s in group chat to join. (%d entered; 2 required)", self.saved.entryTrigger, count), false)
        else
            self:SetLocalStatus(string.format("Entries open — %d players entered. Ready to close entries and start rolls.", count), false)
        end
    elseif self.state == STATE_ROLLS_OPEN then
        self:SetLocalStatus(string.format("Rolls open — %d/%d players have rolled 1-%d.", self:GetRolledCount(), count, self:GetConfiguredRollMax()), false)
    elseif self.state == STATE_ROLLS_CLOSED then
        if self:AllInitialRollsComplete() then
            self:SetLocalStatus("Rolls closed — ready to select the winner.", false)
        else
            self:SetLocalStatus(string.format("Rolls closed — %d/%d players rolled. Reopen rolls to finish.", self:GetRolledCount(), count), true)
        end
    elseif self.state == STATE_TIE_ROLLS_OPEN then
        self:SetLocalStatus(string.format("Tie detected — red players must reroll /roll %d. (%d waiting)", self:GetConfiguredRollMax(), self:GetTieWaitingCount()), true)
    elseif self.state == STATE_TIE_ROLLS_CLOSED then
        if self:AllTieRollsComplete() then
            self:SetLocalStatus("Tie rerolls closed — select winner to resolve the tie.", false)
        else
            self:SetLocalStatus("Tie rerolls closed before everyone rerolled. Reopen rerolls to finish.", true)
        end
    end
end

function HL:RefreshUI()
    if not self.ui.window then return end
    self:RefreshPlayerRows()
    self:RefreshButtons()
    self:RefreshStatus()
    self:UpdateSettingsEnabledState()
end

-- ============================================================================
-- Button clicks + opening windows
-- ============================================================================

function HL:HandleEntryButton()
    self:SaveMessageSettings()
    if self.state == STATE_IDLE then
        self:StartEntries()
    elseif self.state == STATE_ENTRIES_OPEN then
        self:CloseEntriesAndStartRolls()
    end
end

function HL:HandleRollButton()
    if self.state == STATE_ROLLS_OPEN then
        self:CloseRolls()
    elseif self.state == STATE_ROLLS_CLOSED and not self:AllInitialRollsComplete() then
        self:StartRolls(true)
    elseif self.state == STATE_TIE_ROLLS_OPEN then
        self:CloseTieRolls()
    elseif self.state == STATE_TIE_ROLLS_CLOSED and not self:AllTieRollsComplete() then
        self.state = STATE_TIE_ROLLS_OPEN
        self:RegisterRollListener()
        self:RefreshUI()
    end
end

function HL:SaveWindowPosition()
    if not self.ui.window then return end
    self.saved.windowX = self.ui.window:GetLeft()
    self.saved.windowY = self.ui.window:GetTop()
end

function HL:ToggleWindow()
    if not self.ui.window then return end
    SCENE_MANAGER:ToggleTopLevel(self.ui.window)
end

function HL:ShowHistoryWindow()
    if not self.ui.historyWindow then return end
    self:RefreshHistoryUI()
    SCENE_MANAGER:ShowTopLevel(self.ui.historyWindow)
    self.ui.historyWindow:BringWindowToTop()
end

function HL:ClearHistory()
    self.historySaved.history = {}
    self:RefreshHistoryUI()
end

function HL:RefreshHistoryUI()
    if not self.ui.historyRows then return end
    local history = self.historySaved and self.historySaved.history or {}

    for index = 1, #self.ui.historyRows do
        local row = self.ui.historyRows[index]
        local entry = history[index]
        if entry then
            row.winner:SetText(StripDisplayNamePrefix(entry.winner or ""))
            row.loser:SetText(StripDisplayNamePrefix(entry.loser or ""))
            row.prize:SetText(string.format("%s gold", FormatGold(entry.amount or 0)))
            row.control:SetHidden(false)
        else
            row.winner:SetText("")
            row.loser:SetText("")
            row.prize:SetText("")
            row.control:SetHidden(true)
        end
    end

    if self.ui.historyEmpty then
        self.ui.historyEmpty:SetHidden(#history > 0)
    end
    if self.ui.historyScroll and ZO_Scroll_ResetToTop then
        ZO_Scroll_ResetToTop(self.ui.historyScroll)
    end
end

-- ============================================================================
-- UI helpers
-- ============================================================================

local function CreateLabel(parent, name, text, font, point, relativeTo, relativePoint, x, y, width, height)
    local label = WM:CreateControl(name, parent, CT_LABEL)
    label:SetFont(font or "ZoFontGame")
    label:SetText(text or "")
    label:SetColor(0.88, 0.84, 0.76, 1)
    label:SetAnchor(point, relativeTo or parent, relativePoint or point, x or 0, y or 0)
    if width and height then label:SetDimensions(width, height) end
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    return label
end

local function CreateEditBox(parent, name, anchorTarget, y, width)
    local backdrop = WM:CreateControlFromVirtual(name .. "Backdrop", parent, "ZO_DefaultBackdrop")
    backdrop:ClearAnchors()
    backdrop:SetDimensions(width, 34)
    backdrop:SetAnchor(TOPLEFT, anchorTarget, BOTTOMLEFT, 0, y)

    local edit = WM:CreateControlFromVirtual(name, backdrop, "ZO_DefaultEditForDarkBackdrop")
    edit:ClearAnchors()
    edit:SetAnchor(TOPLEFT, backdrop, TOPLEFT, 8, 3)
    edit:SetAnchor(BOTTOMRIGHT, backdrop, BOTTOMRIGHT, -8, -3)
    edit:SetMaxInputChars(220)
    edit:SetHandler("OnFocusLost", function() HL:SaveMessageSettings() end)
    return edit, backdrop
end

-- ===========================================================================
-- Main Window
-- ============================================================================

function HL:CreateMainWindow()
    local window = WM:CreateTopLevelWindow("HighLowWindow")
    self.ui.window = window
    window:SetDimensions(980, 660)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:SetMouseEnabled(true)
    window:SetDrawTier(DT_HIGH)
    window:SetHidden(true)
    SCENE_MANAGER:RegisterTopLevel(window, true)

    if self.saved.windowX and self.saved.windowY then
        window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self.saved.windowX, self.saved.windowY)
    else
        window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end

    local bg = WM:CreateControlFromVirtual("HighLowWindowBG", window, "ZO_DefaultBackdrop")
    bg:SetAnchorFill(window)

    local header = WM:CreateControl("HighLowWindowHeader", window, CT_CONTROL)
    header:SetDimensions(930, 46)
    header:SetAnchor(TOPLEFT, window, TOPLEFT, 20, 10)
    header:SetMouseEnabled(true)
    header:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then window:StartMoving() end
    end)
    header:SetHandler("OnMouseUp", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            window:StopMovingOrResizing()
            HL:SaveWindowPosition()
        end
    end)

    local title = CreateLabel(header, "HighLowTitle", "HIGH-LOW", "ZoFontWinH1", LEFT, header, LEFT, 0, 0, 400, 40)
    title:SetColor(0.88, 0.72, 0.39, 1)

    local version = CreateLabel(header, "HighLowVersion", "v" .. self.version, "ZoFontGameSmall", RIGHT, header, RIGHT, -48, 1, 90, 25)
    version:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    version:SetColor(0.55, 0.55, 0.55, 1)

    local close = WM:CreateControlFromVirtual("HighLowClose", window, "ZO_CloseButton")
    close:SetAnchor(TOPRIGHT, window, TOPRIGHT, -8, 8)
    close:SetHandler("OnClicked", function() SCENE_MANAGER:HideTopLevel(window) end)

    local divider = WM:CreateControl("HighLowDivider", window, CT_TEXTURE)
    divider:SetTexture("/esoui/art/miscellaneous/horizontaldivider.dds")
    divider:SetDimensions(940, 8)
    divider:SetAnchor(TOP, window, TOP, 0, 57)

    local left = WM:CreateControl("HighLowLeftPanel", window, CT_CONTROL)
    left:SetDimensions(585, 515)
    left:SetAnchor(TOPLEFT, window, TOPLEFT, 24, 72)

    local sectionTitle = CreateLabel(left, "HighLowMessagesHeader", "GAME MESSAGES", "ZoFontWinH3", TOPLEFT, left, TOPLEFT, 0, 0, 550, 28)
    sectionTitle:SetColor(0.88, 0.72, 0.39, 1)

    local triggerLabel = CreateLabel(left, "HighLowTriggerLabel", "Entry Trigger (exact group-chat message)", "ZoFontGameSmall", TOPLEFT, sectionTitle, BOTTOMLEFT, 0, 12, 550, 22)
    local triggerEdit, triggerBackdrop = CreateEditBox(left, "HighLowEntryTrigger", triggerLabel, 0, 250)
    triggerEdit:SetMaxInputChars(40)
    self.ui.entryTrigger = triggerEdit

    local rollMaxLabel = CreateLabel(left, "HighLowRollMaxLabel", "Roll Maximum", "ZoFontGameSmall", TOPLEFT, triggerLabel, TOPLEFT, 285, 0, 200, 22)
    local rollEdit, rollBackdrop = CreateEditBox(left, "HighLowRollMax", rollMaxLabel, 0, 170)
    rollEdit:SetTextType(TEXT_TYPE_NUMERIC)
    rollEdit:SetMaxInputChars(8)
    self.ui.rollMax = rollEdit

    local startLabel = CreateLabel(left, "HighLowStartEntriesLabel", "Start Entries Message", "ZoFontGameSmall", TOPLEFT, triggerBackdrop, BOTTOMLEFT, 0, 14, 550, 22)
    local startEdit, startBackdrop = CreateEditBox(left, "HighLowStartEntriesMessage", startLabel, 0, 545)
    self.ui.startEntriesMessage = startEdit

    local closeEntriesLabel = CreateLabel(left, "HighLowCloseEntriesLabel", "Close Entries / Start Rolls Message", "ZoFontGameSmall", TOPLEFT, startBackdrop, BOTTOMLEFT, 0, 14, 550, 22)
    local closeEntriesEdit, closeEntriesBackdrop = CreateEditBox(left, "HighLowCloseEntriesMessage", closeEntriesLabel, 0, 545)
    self.ui.closeEntriesMessage = closeEntriesEdit

    local closeRollsLabel = CreateLabel(left, "HighLowCloseRollsLabel", "Close Rolls Message", "ZoFontGameSmall", TOPLEFT, closeEntriesBackdrop, BOTTOMLEFT, 0, 14, 550, 22)
    local closeRollsEdit, closeRollsBackdrop = CreateEditBox(left, "HighLowCloseRollsMessage", closeRollsLabel, 0, 545)
    self.ui.closeRollsMessage = closeRollsEdit

    local hint = CreateLabel(left, "HighLowPlaceholderHint", "Placeholders: {ROLL}=maximum  •  {trigger}=entry trigger  •  {COUNT}=entries", "ZoFontGameSmall", TOPLEFT, closeRollsBackdrop, BOTTOMLEFT, 2, 8, 550, 22)
    hint:SetColor(0.58, 0.58, 0.58, 1)

    local defaultsButton = WM:CreateControlFromVirtual("HighLowDefaultsButton", left, "ZO_DefaultButton")
    defaultsButton:SetDimensions(180, 30)
    defaultsButton:SetAnchor(TOPLEFT, hint, BOTTOMLEFT, -4, 8)
    defaultsButton:SetText("RESET MESSAGES")
    defaultsButton:SetHandler("OnClicked", function() HL:ResetMessagesToDefaults() end)
    self.ui.defaultsButton = defaultsButton

    local resetRoundButton = WM:CreateControlFromVirtual("HighLowResetRoundButton", left, "ZO_DefaultButton")
    resetRoundButton:SetDimensions(180, 30)
    resetRoundButton:SetAnchor(LEFT, defaultsButton, RIGHT, 12, 0)
    resetRoundButton:SetText("RESET ROUND")
    resetRoundButton:SetHandler("OnClicked", function() HL:ResetRound() end)
    self.ui.resetRoundButton = resetRoundButton

    local right = WM:CreateControl("HighLowRightPanel", window, CT_CONTROL)
    right:SetDimensions(325, 515)
    right:SetAnchor(TOPRIGHT, window, TOPRIGHT, -24, 72)

    local rightBG = WM:CreateControlFromVirtual("HighLowRightPanelBG", right, "ZO_DarkThinFrame")
    rightBG:SetAnchorFill(right)

    local entriesHeader = CreateLabel(right, "HighLowEntriesHeader", "ENTRIES", "ZoFontWinH3", TOPLEFT, right, TOPLEFT, 18, 13, 180, 28)
    entriesHeader:SetColor(0.88, 0.72, 0.39, 1)

    local entriesCount = CreateLabel(right, "HighLowEntriesCount", "0 players", "ZoFontGameSmall", TOPRIGHT, right, TOPRIGHT, -18, 18, 110, 22)
    entriesCount:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    entriesCount:SetColor(0.6, 0.6, 0.6, 1)
    self.ui.entriesCount = entriesCount

    local needsRollButton = WM:CreateControlFromVirtual("HighLowNeedsRollButton", right, "ZO_DefaultButton")
    needsRollButton:SetDimensions(190, 32)
    needsRollButton:SetAnchor(BOTTOM, right, BOTTOM, 0, -14)
    needsRollButton:SetText("NEEDS TO ROLL")
    needsRollButton:SetHandler("OnClicked", function() HL:AnnouncePlayersNeedingRoll() end)
    self.ui.needsRollButton = needsRollButton

    local line = WM:CreateControl("HighLowEntriesLine", right, CT_TEXTURE)
    line:SetTexture("/esoui/art/miscellaneous/horizontaldivider.dds")
    line:SetDimensions(292, 8)
    line:SetAnchor(TOP, right, TOP, 0, 48)

    self.ui.playerRows = {}
    local previous = line
    for index = 1, 12 do
        local row = CreateLabel(right, "HighLowPlayerRow" .. index, "", "ZoFontGame", TOPLEFT, previous, BOTTOMLEFT, index == 1 and 17 or 0, index == 1 and 3 or 0, 285, 31)
        if index > 1 then
            row:ClearAnchors()
            row:SetAnchor(TOPLEFT, previous, BOTTOMLEFT, 0, 0)
        end
        row:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        self.ui.playerRows[index] = row
        previous = row
    end

    local status = CreateLabel(window, "HighLowStatus", "", "ZoFontGameSmall", BOTTOMLEFT, window, BOTTOMLEFT, 28, -68, 920, 28)
    status:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    status:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.ui.status = status

    local entryButton = WM:CreateControlFromVirtual("HighLowEntryButton", window, "ZO_DefaultButton")
    entryButton:SetDimensions(250, 36)
    entryButton:SetAnchor(BOTTOMLEFT, window, BOTTOMLEFT, 26, -24)
    entryButton:SetHandler("OnClicked", function() HL:HandleEntryButton() end)
    self.ui.entryButton = entryButton

    local rollButton = WM:CreateControlFromVirtual("HighLowRollButton", window, "ZO_DefaultButton")
    rollButton:SetDimensions(190, 36)
    rollButton:SetAnchor(LEFT, entryButton, RIGHT, 12, 0)
    rollButton:SetHandler("OnClicked", function() HL:HandleRollButton() end)
    self.ui.rollButton = rollButton

    local winnerButton = WM:CreateControlFromVirtual("HighLowWinnerButton", window, "ZO_DefaultButton")
    winnerButton:SetDimensions(190, 36)
    winnerButton:SetAnchor(LEFT, rollButton, RIGHT, 12, 0)
    winnerButton:SetText("SELECT WINNER")
    winnerButton:SetHandler("OnClicked", function() HL:SelectWinner() end)
    self.ui.winnerButton = winnerButton

    local historyButton = WM:CreateControlFromVirtual("HighLowHistoryButton", window, "ZO_DefaultButton")
    historyButton:SetDimensions(190, 36)
    historyButton:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -26, -24)
    historyButton:SetText("GAME LOGS")
    historyButton:SetHandler("OnClicked", function() HL:ShowHistoryWindow() end)
    self.ui.historyButton = historyButton

    self:PopulateSettingsFields()
    self:RefreshUI()
end

-- ============================================================================
-- Build the game logs window
-- ============================================================================

function HL:CreateHistoryWindow()
    local window = WM:CreateTopLevelWindow("HighLowHistoryWindow")
    self.ui.historyWindow = window
    window:SetDimensions(760, 650)
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:SetMouseEnabled(true)
    window:SetDrawTier(DT_HIGH)
    window:SetDrawLevel(100)
    window:SetHidden(true)
    SCENE_MANAGER:RegisterTopLevel(window, true)

    local bg = WM:CreateControlFromVirtual("HighLowHistoryBG", window, "ZO_DefaultBackdrop")
    bg:SetAnchorFill(window)

    local header = WM:CreateControl("HighLowHistoryHeaderDrag", window, CT_CONTROL)
    header:SetDimensions(710, 44)
    header:SetAnchor(TOPLEFT, window, TOPLEFT, 20, 10)
    header:SetMouseEnabled(true)
    header:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            window:BringWindowToTop()
            window:StartMoving()
        end
    end)
    header:SetHandler("OnMouseUp", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then window:StopMovingOrResizing() end
    end)

    local title = CreateLabel(header, "HighLowHistoryTitle", "HIGH-LOW GAME LOGS", "ZoFontWinH2", LEFT, header, LEFT, 0, 0, 500, 38)
    title:SetColor(0.88, 0.72, 0.39, 1)

    local close = WM:CreateControlFromVirtual("HighLowHistoryClose", window, "ZO_CloseButton")
    close:SetAnchor(TOPRIGHT, window, TOPRIGHT, -8, 8)
    close:SetHandler("OnClicked", function() SCENE_MANAGER:HideTopLevel(window) end)

    local line = WM:CreateControl("HighLowHistoryDivider", window, CT_TEXTURE)
    line:SetTexture("/esoui/art/miscellaneous/horizontaldivider.dds")
    line:SetDimensions(720, 8)
    line:SetAnchor(TOP, window, TOP, 0, 58)

    local tableHeader = WM:CreateControl("HighLowHistoryTableHeader", window, CT_CONTROL)
    tableHeader:SetDimensions(690, 38)
    tableHeader:SetAnchor(TOP, line, BOTTOM, 0, 6)

    local winnerHeader = CreateLabel(tableHeader, "HighLowHistoryWinnerHeader", "WINNER", "ZoFontWinH3", LEFT, tableHeader, LEFT, 10, 0, 245, 34)
    winnerHeader:SetColor(0.88, 0.72, 0.39, 1)
    local loserHeader = CreateLabel(tableHeader, "HighLowHistoryLoserHeader", "LOSER", "ZoFontWinH3", LEFT, tableHeader, LEFT, 265, 0, 245, 34)
    loserHeader:SetColor(0.88, 0.72, 0.39, 1)
    local prizeHeader = CreateLabel(tableHeader, "HighLowHistoryPrizeHeader", "PRIZE", "ZoFontWinH3", RIGHT, tableHeader, RIGHT, -10, 0, 160, 34)
    prizeHeader:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    prizeHeader:SetColor(0.88, 0.72, 0.39, 1)

    local headerLine = WM:CreateControl("HighLowHistoryTableHeaderLine", window, CT_TEXTURE)
    headerLine:SetTexture("/esoui/art/miscellaneous/horizontaldivider.dds")
    headerLine:SetDimensions(690, 8)
    headerLine:SetAnchor(TOP, tableHeader, BOTTOM, 0, -2)

    local empty = CreateLabel(window, "HighLowHistoryEmpty", "No completed games yet.", "ZoFontGameLarge", CENTER, window, CENTER, 0, -5, 500, 44)
    empty:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    empty:SetColor(0.55, 0.55, 0.55, 1)
    self.ui.historyEmpty = empty

    local scroll = WM:CreateControlFromVirtual("HighLowHistoryScroll", window, "ZO_ScrollContainer")
    scroll:SetDimensions(710, 455)
    scroll:SetAnchor(TOP, headerLine, BOTTOM, 0, 2)
    self.ui.historyScroll = scroll

    local scrollControl = scroll:GetNamedChild("Scroll")
    local child = scrollControl:GetNamedChild("Child")

    self.ui.historyRows = {}
    local previous = nil
    for index = 1, self.maxHistory do
        local row = WM:CreateControl("HighLowHistoryRow" .. index, child, CT_CONTROL)
        row:SetDimensions(680, 44)
        if previous then
            row:SetAnchor(TOPLEFT, previous, BOTTOMLEFT, 0, 0)
        else
            row:SetAnchor(TOPLEFT, child, TOPLEFT, 8, 0)
        end

        local winner = CreateLabel(row, "HighLowHistoryWinner" .. index, "", "ZoFontGameLarge", LEFT, row, LEFT, 4, 0, 245, 40)
        winner:SetVerticalAlignment(TEXT_ALIGN_CENTER)

        local loser = CreateLabel(row, "HighLowHistoryLoser" .. index, "", "ZoFontGameLarge", LEFT, row, LEFT, 259, 0, 245, 40)
        loser:SetVerticalAlignment(TEXT_ALIGN_CENTER)

        local prize = CreateLabel(row, "HighLowHistoryPrize" .. index, "", "ZoFontGameLarge", RIGHT, row, RIGHT, -4, 0, 160, 40)
        prize:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        prize:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        prize:SetColor(0.88, 0.72, 0.39, 1)

        local rowLine = WM:CreateControl("HighLowHistoryRowLine" .. index, row, CT_TEXTURE)
        rowLine:SetTexture("/esoui/art/miscellaneous/horizontaldivider.dds")
        rowLine:SetDimensions(670, 6)
        rowLine:SetAnchor(BOTTOM, row, BOTTOM, 0, 0)
        rowLine:SetAlpha(0.35)

        self.ui.historyRows[index] = { control = row, winner = winner, loser = loser, prize = prize }
        previous = row
    end

    local clear = WM:CreateControlFromVirtual("HighLowHistoryClear", window, "ZO_DefaultButton")
    clear:SetDimensions(180, 34)
    clear:SetAnchor(BOTTOM, window, BOTTOM, 0, -20)
    clear:SetText("CLEAR HISTORY")
    clear:SetHandler("OnClicked", function() HL:ClearHistory() end)

    self:RefreshHistoryUI()
end

-- ============================================================================
-- Startup stuff
-- ============================================================================

function HL:MigrateSavedMessages()
    if self.saved.startEntriesMessage == "High-Low is starting! Type !hl in group chat to enter." then
        self.saved.startEntriesMessage = defaults.startEntriesMessage
    end
    if self.saved.closeEntriesMessage == "High-Low entries are now closed!" then
        self.saved.closeEntriesMessage = defaults.closeEntriesMessage
    end
end

function HL:MigrateHistory()
    if self.historySaved.migratedLegacy then return end

    -- Old logs had no server attached to them, so just copy them over once.
    if self.saved.history and #self.saved.history > 0 and #self.historySaved.history == 0 then
        for index, entry in ipairs(self.saved.history) do
            self.historySaved.history[index] = {
                timestamp = entry.timestamp,
                winner = entry.winner,
                loser = entry.loser,
                amount = entry.amount,
                winnerRoll = entry.winnerRoll,
                loserRoll = entry.loserRoll,
                text = entry.text,
            }
        end
    end

    self.historySaved.migratedLegacy = true
end

function HL:Initialize()
    self.saved = ZO_SavedVars:NewAccountWide("HighLowSavedVars", self.savedVersion, nil, defaults)
    self.historySaved = ZO_SavedVars:NewAccountWide("HighLowHistoryVars", 1, GetWorldName(), historyDefaults)

    self:MigrateSavedMessages()
    self:MigrateHistory()

    self:CreateMainWindow()
    self:CreateHistoryWindow()

    SLASH_COMMANDS["/highlow"] = function() self:ToggleWindow() end
    SLASH_COMMANDS["/hl"] = function() self:ToggleWindow() end

    self:Debug("Loaded v" .. self.version .. ". Use /hl or bind Toggle High-Low Window in Controls.")
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= HL.name then return end
    EVENT_MANAGER:UnregisterForEvent(HL.name, EVENT_ADD_ON_LOADED)
    HL:Initialize()
end

EVENT_MANAGER:RegisterForEvent(HL.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
