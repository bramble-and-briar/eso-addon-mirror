local IMP_STATS_SHARED = IMP_STATS_SHARED
local zo_strformat = zo_strformat

-- ----------------------------------------------------------------------------

local addon = {}

addon.name = 'IMP_STATS_Duels_UI'

addon.listControl = nil
addon.statsControl = nil

addon.filters = {
}

-- TODO: delete unused
addon.selections = {
    playerClass = {},
    opponentClass = {},
    playerName = '',
    opponentName = '',
    characters = {}
}

local Log = IMP_STATS_Logger('DUELS_UI')

--#region IMP STATS DUELS STATS
local DuelsStats = {}

function DuelsStats:New(o)
    o = o or {}

    setmetatable(o, self)
    self.__index = self

    o:Clear()

    return o
end

function DuelsStats:Clear()
    self.totalDuels = 0
    self.totalWon = 0
    self.totalLost = 0
    self.totalDamageDone = 0
    self.totalDamageTaken = 0
    self.totalHealingTaken = 0
    self.totalDamageShielded = 0
    self.totalDuration = 0
    self.lastProceededIndex = nil
end

--#region HUMAN UNDERSTANDABLE RESULT
local WIN = 1
local LOSS = 2
local PLAYER_FORFEIT = 3
local OPPONENT_FORFEIT = 4
local UNDEFINED = 0

local DUEL_RESULT_TO_STRING = {
    [WIN] = 'Won',
    [LOSS] = 'Lost',
    [PLAYER_FORFEIT] = 'You run',
    [OPPONENT_FORFEIT] = 'Opponent run',
    [UNDEFINED] = '???',
}

local function GetHumanUnderstandableResult(result, wasLocalPlayersResult)
    local hrr = UNDEFINED

    if result == DUEL_RESULT_WON then
        if wasLocalPlayersResult then
            hrr = WIN
        else
            hrr = LOSS
        end
    elseif result == DUEL_RESULT_FORFEIT then
        if wasLocalPlayersResult then
            hrr = PLAYER_FORFEIT
        else
            hrr = OPPONENT_FORFEIT
        end
    end

    return hrr
end
--#endregion HUMAN UNDERSTANDABLE RESULT

function DuelsStats:AddDuel(duelData)
    local duelIndex = duelData.index

    if self.lastProceededIndex and duelIndex <= self.lastProceededIndex then return end
    self.lastProceededIndex = duelIndex

    self.totalDuels             = self.totalDuels           + 1
    self.totalDamageDone        = self.totalDamageDone      + (duelData.damageDone      or 0)
    self.totalHealingTaken      = self.totalHealingTaken    + (duelData.healingTaken    or 0)
    self.totalDamageTaken       = self.totalDamageTaken     + (duelData.damageTaken     or 0)
    self.totalDamageShielded    = self.totalDamageShielded  + (duelData.damageShielded  or 0)
    self.totalDuration          = self.totalDuration        + (duelData.duration        or 0)

    if duelData.result == WIN then
        self.totalWon = self.totalWon + 1
    elseif duelData.result == LOSS then
        self.totalLost = self.totalLost + 1
    end
end
--#endregion

--#region IMP STATS DUELS UI
function addon:UpdateStatsControl()
    local duelsWithResult = self.stats.totalWon + self.stats.totalLost

    self.statsControl:GetNamedChild('TotalDuelsValue'):SetText(self.stats.totalDuels)

    local winrate = IMP_STATS_SHARED.PossibleNan(self.stats.totalWon / duelsWithResult)
    self.statsControl:GetNamedChild('WinrateValue'):SetText(
        string.format('%.1f %% (|c00FF00%d|r / |cFF0000%d|r)', winrate * 100, self.stats.totalWon, self.stats.totalLost)
    )

    self.statsControl:GetNamedChild('TotalsValue'):SetText(
        string.format(
            '%s / %s / %s',
            IMP_STATS_SHARED.FormatNumber(self.stats.totalDamageDone),
            IMP_STATS_SHARED.FormatNumber(self.stats.totalDamageTaken),
            IMP_STATS_SHARED.FormatNumber(self.stats.totalHealingTaken)
            -- IMP_STATS_SHARED.FormatNumber(self.stats.totalDamageShielded),
            -- IMP_STATS_SHARED.FormatNumber(self.stats.totalDuration)
        )
    )

    IMP_STATS_SHARED.SetGaugeKDAMeter(self.statsControl:GetNamedChild('GaugeKDAMeter'), winrate)
end

-- TODO: make color uniforme and global
local ALPHA = 0.6
local COLOR_OF_RESULT = {
    [WIN]              = {     0,      1,      0, ALPHA},
    [LOSS]             = {     1,      0,      0, ALPHA},
    [PLAYER_FORFEIT]   = {35/255, 35/255, 35/255, ALPHA},
    [OPPONENT_FORFEIT] = {75/255, 75/255, 75/255, ALPHA},
}

function addon.GetName(data)
    assert(false, 'Must be owerritten!')
end

-- local function HideWarning()
--     GetControl(IMP_STATS_DUELS, 'Warning'):SetHidden(true)
-- end

-- local function ShowWarning()
--     GetControl(IMP_STATS_DUELS, 'Warning'):SetHidden(false)
-- end

function addon:_passInternalFilters(duelIndex)
    local duel = self.dataRows[duelIndex]

    if not string.find(duel.opponentNormalizedName, self.selections.opponentName) then
        return false
    end

    if not (self.debugging or self.selections.characters[duel.playerCharacterId]) then
        return false
    end

    return true
end

function addon:UpdateUI()
    local data = {}
    self.stats:Clear()

    for i = 1, #self.dataRows do
        if self:_passInternalFilters(i) then
            local duel = self.dataRows[i]

            data[#data+1] = {
                duel.index,
                duel.duration or 0,
                duel.playerClass,
                duel.playerRace,
                duel.playerName,
                duel.opponentClass,
                duel.opponentRace,
                duel.opponentName,
                duel.damageDone or 0,
                duel.damageTaken or 0,
                duel.healingTaken or 0,
                duel.damageShielded or 0,
                duel.build ~= nil,
                duel.result,
            }

            self.stats:AddDuel(duel)
        end
    end

    self.table:Update(1, data)

    self:UpdateStatsControl()

    Log('UI updated')
end

local function _isGoodData(duelData)
    if not duelData.player
    or not duelData.damageDone
    or not duelData.damageTaken
    or not duelData.healingTaken
    or not duelData.damageShilded
    then  -- or not duelData.opponent
        return
    end

    return true
end

-- TODO: made as in bgs
function addon:Update()
    -- if #self.duels > 60000 then ShowWarning() end

    self.dataRows = {}

    local function HandleDuelData(duelId, duelData)
        if not _isGoodData(duelData) then return end

        local opponentNormalizedName = IMP_NORMALIZE_NAMES.Normalize(self.GetName(duelData.opponent))

        local result = UNDEFINED

        if duelData.result then
            result = GetHumanUnderstandableResult(duelData.result, duelData.wasLocalPlayersResult)
        end

        local nextIndex = #self.dataRows + 1
        self.dataRows[nextIndex] = {
            index = nextIndex,
            result = result,
            wasLocalPlayersResult = duelData.wasLocalPlayersResult,
            playerClass =  duelData.player.classId,
            playerRace = duelData.player.raceId,
            opponentClass =  duelData.opponent.classId,
            opponentRace = duelData.opponent.raceId,
            playerName = self.GetName(duelData.player),
            opponentName = self.GetName(duelData.opponent),
            damageDone = duelData.damageDone,
            damageTaken = duelData.damageTaken,
            healingTaken = duelData.healingTaken or duelData.healingDone,  -- TODO: delete in the future
            damageShielded = duelData.damageShilded,
            startTimestamp = duelData.timestamp,
            duration = duelData.duration,
            duelId = duelId,  -- TODO: some workaround. As stated above, I should follow BG style in the future
            build = duelData.player.build,
            opponentNormalizedName = opponentNormalizedName,
            playerCharacterId = duelData.player.characterId,
        }
    end

    local task = LibAsync:Create('UpdateDuelsDataRows')

    task:For(ipairs(self.duels)):Do(HandleDuelData)
    :Then(function() self:UpdateUI() end)

    Log('Updated')
end

function addon:CreateControls()
    local tlc = IMP_STATS_DUELS
    assert(tlc ~= nil, 'Duels control was not created')
    self.tlc = tlc

    self:_createTable()

    local statsControl = tlc:GetNamedChild('StatsBlock')

    local function OnSearchTextChanged(editBox, field)
        local newText = string.lower(editBox:GetText())

        Log('New search: ', newText)

        if newText == self.selections[field] then return end

        self.selections[field] = newText
        self:UpdateUI()
    end

    local oppSearchBox = tlc:GetNamedChild('OpponentSearchBox')
    oppSearchBox:SetHandler('OnTextChanged', function(editBox) OnSearchTextChanged(editBox, 'opponentName') end)

    self.duelsControl = tlc
    self.statsControl = statsControl
end

addon.InitializePlayerCharactersFilter = IMP_STATS_SHARED.InitializePlayerCharactersFilter

function addon:_createTable()
	local Button = LibScrollList.Button
	local Column = LibScrollList.Column
	local Table = LibScrollList.Table

    local buildButtonStyle = IMP_STATS_TABLESTYLES.buildButtonStyle

    local BuildButton = Button(
        buildButtonStyle,
        function(ctrl, exists)
            if not exists then
                ctrl:SetHidden(true)
            else
                ctrl:SetHidden(false)
                ctrl:SetState(BSTATE_NORMAL)
            end
        end,
        function(ctrl)
            self:LayoutBuildFor(ctrl:GetParent():GetParent())
        end
    )

	local FC = IMP_STATS_TABLESTYLES.Formatted.Cell
	local TC = IMP_STATS_TABLESTYLES.Text.Cell
	local THU = IMP_STATS_TABLESTYLES.Text.HeaderUpper

	local ClassIcon = IMP_STATS_TABLESTYLES.ClassIcon
	local RaceIcon = IMP_STATS_TABLESTYLES.RaceIcon
	local Time = IMP_STATS_TABLESTYLES.Time.Cell.Right

	local SORTABLE = true
	local columns = {
        Column('Index', 	   40,  0, TC.Right,       '###', THU.Right,      SORTABLE),
		Column('Duration',     50, 10, Time,          'Time', THU.Right,      SORTABLE),
		Column('Class', 	   32, 10, ClassIcon,        nil, THU.Center, not SORTABLE),
		Column('Race', 	       32,  0, RaceIcon,         nil, THU.Center, not SORTABLE),
		Column('Name',  	  170,  4, TC.Left,     'Player', THU.Left,   not SORTABLE),
        Column('OppClass', 	   32,  0, ClassIcon,        nil, THU.Center, not SORTABLE),
		Column('OppRace', 	   32,  0, RaceIcon,         nil, THU.Center, not SORTABLE),
		Column('OppName',  	  170,  4, TC.Left,   'Opponent', THU.Left,   not SORTABLE),
        Column('DamageDone',   70,  0, FC.Center,     'Done', THU.Center,     SORTABLE),
        Column('Taken',        70,  0, FC.Center,    'Taken', THU.Center,     SORTABLE),
		Column('HealingDone',  70,  0, FC.Center,     'Heal', THU.Center,     SORTABLE),
        Column('Shielded',     70,  0, FC.Center,   'Shield', THU.Center,     SORTABLE),
        Column('Build', 	   32,  0, BuildButton, 	 nil, THU.Center, not SORTABLE),
    }

	local WITH_HEADERS = true
    local myTable = Table(WITH_HEADERS)

    local tooltipTable = {}

    local function AddLine(line)
        tooltipTable[#tooltipTable+1] = line or ''
    end

    local function ClearTooltip()
        ZO_ClearNumericallyIndexedTable(tooltipTable)
    end

    local RACE_CLASS_ROW = '%s / %s'

    local function BuildTooltip(rowData)
        ClearTooltip()

        local index = rowData[1]
        local data = self.dataRows[index]

        if data.startTimestamp then
            local formattedTime = os.date('%d.%m.%Y %H:%M', data.startTimestamp)
            AddLine(formattedTime)
            AddLine()
        end
        AddLine(data.playerName)
        AddLine(RACE_CLASS_ROW:format(GetRaceName(0, rowData[4]), GetClassName(nil, rowData[3])))
        AddLine('      |cFF0000VS|r ')
        AddLine(data.opponentName)
        AddLine(RACE_CLASS_ROW:format(GetRaceName(0, rowData[7]), GetClassName(nil, rowData[6])))
        AddLine()
        AddLine('Duration: ' .. rowData[2] .. 's')
        AddLine()
        AddLine('Result: ' .. DUEL_RESULT_TO_STRING[rowData[14]])

        return table.concat(tooltipTable, '\n')
    end

    local function showTooltip(rowControl)
        local tooltipText = BuildTooltip(rowControl.dataEntry.data)
        ZO_Tooltips_ShowTextTooltip(rowControl, LEFT, tooltipText)
    end

	local postCreateCallback = function(rowControl)
		local background = CreateControlFromVirtual('$(parent)Background', rowControl, 'IMP_TallListSelectedHighlight')
        background:SetAlpha(0.6)

        -- rowControl:SetHandler('OnMouseDown', onMouseDown)

        -- local scrollList = rowControl:GetParent():GetParent()
        -- ZO_ScrollList_EnableSelection(scrollList, 'ZO_ThinListHighlight', LayoutMatchRow)
	    -- ZO_ScrollList_SetDeselectOnReselect(scrollList, true)

        rowControl:SetHandler('OnMouseEnter', showTooltip)
        rowControl:SetHandler('OnMouseExit', ZO_Tooltips_HideTextTooltip)
	end
	local postSetupCallback = function(rowControl, dataEntryData, scrollList)
        local result = dataEntryData[14]
        if result then
            GetControl(rowControl, 'Background'):SetHidden(false)
            GetControl(rowControl, 'Background'):SetColor(unpack(COLOR_OF_RESULT[result]))
        else
            GetControl(rowControl, 'Background'):SetHidden(true)
        end
	end
    myTable:AddDataType(1, columns, 32, postCreateCallback, postSetupCallback)

	myTable.defaultSortingCriteria = {
		{columnIndex = 1, order = ZO_SORT_ORDER_DOWN},
	}

	local REPLACE = true
    local scrollControl = myTable:Create('Listing', self.tlc, REPLACE)
    -- scrollControl:SetDimensions(0, 0)

	self.table = myTable
end

function addon:Initialize(naming, selectedCharacters, debugging)
    self.duels = IMP_STATS_Duels_MANAGER.duels
    self.stats = DuelsStats:New()
    self.debugging = debugging

    local nameBuffer = {}
    local NAMINGS = {
        [1] = function(data)
            if not nameBuffer[data.characterName] then
                nameBuffer[data.characterName] = zo_strformat('<<1>>', data.characterName)
            end
            return nameBuffer[data.characterName]
        end,
        [2] = function(data)
            if not nameBuffer[data.displayName] then
                nameBuffer[data.displayName] = data.displayName
            end
            return nameBuffer[data.displayName]
        end,
        [3] = function(data)
            if not nameBuffer[data.displayName] then
                nameBuffer[data.displayName] = zo_strformat('<<1>> (<<2>>)', data.displayName, data.characterName)
            end
            return nameBuffer[data.displayName]
        end,
    }
    self.GetName = NAMINGS[naming]

    self:CreateControls()

    self.selections.characters = selectedCharacters
    if IMP_STATS_SHARED.TableLength(self.selections.characters) < 1 then
        self.selections.characters[GetCurrentCharacterId()] = true
    end
    self:InitializePlayerCharactersFilter(GetControl(self.duelsControl, 'CharactersFilter'), self.selections.characters)

    Log('UI initialized')
end
--#endregion

function addon:LayoutBuildFor(row)
    if not (row and row.dataEntry and row.dataEntry.data[1]) then return end
    local duelIndex = row.dataEntry.data[1]
    LibDataPacker_Build_LayoutShortBuild(self.dataRows[duelIndex].build)
end

do
    IMP_STATS_Duels_UI = addon
end
