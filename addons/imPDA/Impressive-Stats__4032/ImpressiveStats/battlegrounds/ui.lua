local IMP_STATS_SHARED = IMP_STATS_SHARED
local PossibleNan = IMP_STATS_SHARED.PossibleNan
local FormatNumber = IMP_STATS_SHARED.FormatNumberWithoutSpace

local function comma_value(n) -- credit http://richard.warburton.it
	local left, num, right = string.match(n, '^([^%d]*%d)(%d*)(.-)$')
	return left..(num:reverse():gsub('(%d%d%d)', '%1,'):reverse())..right
end

-- ----------------------------------------------------------------------------

local addon = {}

addon.name = 'IMP_STATS_MATCHES_UI'

local EVENT_NAMESPACE = addon.name

-- addon.listControl = nil
-- addon.statsControl = nil

-- TODO: some global to avoid duplication, it also present in newMatchManager
local TEAM_TYPE_4_SOLO = 1
local TEAM_TYPE_8_SOLO = 2
local TEAM_TYPE_4_GROUP = 3
local TEAM_TYPE_8_GROUP = 4
local TEAM_TYPE_4_3_SOLO = 5
local TEAM_TYPE_4_3_GROUP = 6
local TEAM_TYPE_6_3_SOLO = 7
local TEAM_TYPE_6_3_GROUP = 8
local TEAM_TYPE_9_SOLO = 9
local TEAM_TYPE_9_GROUP = 10

local TEAM_TYPES = {
    [TEAM_TYPE_4_SOLO] = '4x4 - Solo',
    [TEAM_TYPE_8_SOLO] = '8x8 - Solo',
    [TEAM_TYPE_4_GROUP] = '4x4 - Group',
    [TEAM_TYPE_8_GROUP] = '8x8 - Group',
    [TEAM_TYPE_4_3_SOLO] = '4x4x4 - Solo',
    [TEAM_TYPE_4_3_GROUP] = '4x4x4 - Group',
    [TEAM_TYPE_6_3_SOLO] = '6x6x6 - Solo',
    [TEAM_TYPE_6_3_GROUP] = '6x6x6 - Group',
    [TEAM_TYPE_9_SOLO] = '9x9 - Solo',
    [TEAM_TYPE_9_GROUP] = '9x9 - Group',
}

addon.filters = {}

addon.selections = {
    teamTypes = {
        TEAM_TYPE_4_SOLO,
        TEAM_TYPE_8_SOLO,
        TEAM_TYPE_4_GROUP,
        TEAM_TYPE_8_GROUP,
        TEAM_TYPE_4_3_SOLO,
        TEAM_TYPE_4_3_GROUP,
    },
    modes = {
        BATTLEGROUND_GAME_TYPE_CAPTURE_THE_FLAG,
        BATTLEGROUND_GAME_TYPE_DEATHMATCH,
        BATTLEGROUND_GAME_TYPE_KING_OF_THE_HILL,
        BATTLEGROUND_GAME_TYPE_DOMINATION,
        BATTLEGROUND_GAME_TYPE_CRAZY_KING,
        BATTLEGROUND_GAME_TYPE_MURDERBALL,
    },
    characters = {}
}

local Log = IMP_STATS_Logger('MATCHES_UI')

--#region IMP STATS MATCHES STATS
local MatchesStats = {}

function MatchesStats:New(o)
    o = o or {}

    setmetatable(o, self)
    self.__index = self

    return o
end

function MatchesStats:Clear()
    self.totalMatches = 0
    self.totalWon = 0
    self.totalLost = 0
    self.totalTied = 0
    -- self.totalLeft = 0
    self.totalKills = 0
    self.totalDeaths = 0
    self.totalAssists = 0
    self.totalDamageDone = 0
    self.totalHealingDone = 0
    self.totalDamageTaken = 0
    self.totalScore = 0

    self.observationsDamageDone = {}
    self.observationsHealingDone = {}
    self.observationsDamageTaken = {}
    self.observationsKills = {}

    -- self.lastProceededIndex = 0
end

local function _sum(tbl)
    local s = 0
    for i = 1, #tbl do
        s = s + tbl[i]
    end
    return s
end

local function _avg(tbl)
    return _sum(tbl) / #tbl
end

local function _var(tbl, E)
    E = E or _avg(tbl)
    local s = 0
    for i = 1, #tbl do
        s = s + (tbl[i] - E)^2
    end
    return s / #tbl
end

function MatchesStats:AddMatch(index, data)
      -- TODO: make actual use of it or remove
    -- if self.lastProceededIndex and index <= self.lastProceededIndex then return end
    -- self.lastProceededIndex = index

    self.totalMatches       = self.totalMatches     + 1
    self.totalKills         = self.totalKills       + data.kills
    self.totalDeaths        = self.totalDeaths      + data.deaths
    self.totalAssists       = self.totalAssists     + data.assists
    self.totalDamageDone    = self.totalDamageDone  + data.damageDone
    self.totalHealingDone   = self.totalHealingDone + data.healingDone
    self.totalDamageTaken   = self.totalDamageTaken + data.damageTaken
    self.totalScore         = self.totalScore       + data.medalScore

    if data.result == BATTLEGROUND_RESULT_WIN then
        self.totalWon = self.totalWon + 1
    elseif data.result == BATTLEGROUND_RESULT_LOSS then
        self.totalLost = self.totalLost + 1
    elseif data.result == BATTLEGROUND_RESULT_TIE then
        self.totalTied = self.totalTied + 1
    end

    -- self.totalLeft = self.totalLeft + 1

    -- self.lastProceededIndex = 0

    if data.damageDoneRatio then
        self.observationsDamageDone[#self.observationsDamageDone+1] = data.damageDoneRatio
        self.observationsDamageTaken[#self.observationsDamageTaken+1] = data.damageTakenRatio
        self.observationsHealingDone[#self.observationsHealingDone+1] = data.healingDoneRatio
        self.observationsKills[#self.observationsKills+1] = data.killsRatio
    end
end

local function _calcStats(observations)
    if #observations < 16 then
        return nil, nil
    end
    table.sort(observations)

    local q = math.floor(#observations / 4)
    local Q1 = observations[q]
    local Q2 = observations[q*2]
    local Q3 = observations[q*3]
    local IQR = Q3-Q1
    local IQR1_5 = IQR * 1.5
    local left, right = Q1 - IQR1_5, Q3 + IQR1_5

    local filtered = {}
    for l = 1, #observations do
        local dmg = observations[l]
        if dmg > left and dmg < right then
            filtered[#filtered+1] = dmg
        end
    end

    local avg = _sum(filtered) / #filtered
    local sigma = math.sqrt(_var(filtered, avg))

    -- return avg, sigma
    return Q2, Q1, Q3
end

function MatchesStats:NewStats()
    -- self.EDD, self.sigmaDD = _calcStats(self.observationsDamageDone)
    self.EDD, self.Q1DD, self.Q3DD = _calcStats(self.observationsDamageDone)
    self.EDT, self.Q1DT, self.Q3DT = _calcStats(self.observationsDamageTaken)
    self.EHD, self.Q1HD, self.Q3HD = _calcStats(self.observationsHealingDone)
    -- self.EK, self.sigmaK = _calcStats(self.observationsKills)  -- TODO: ?
end
--#endregion

--#region IMP STATS MATCHES ADDON
local WL_VALUE_TEXT_FORMAT = '|c00FF00%sW|r - |cFF0000%sL|r'
local KDA_VALUE_TEXT_FORMAT = '%.1f / %.1f / %.1f'
local ONE_F_TEXT_FORMAT = '%.1f'
local D_TEXT_FORMAT = '%d'
function addon:UpdateStatsControl()
    local totalMatchesRecorded = #self.matches  -- self.stats.totalMatches

    self.matchCounterValue:SetText(totalMatchesRecorded)

    local stats = self.stats

    local N = stats.totalMatches
    if IMP_STATS_MATCHES_MANAGER.sv.last150 then N = math.min(N, 150) end
    -- TODO: reimplement counter how many matches are currently selected
    -- self.statsControl:GetNamedChild('MatchesCount'):SetText(zo_strformat('Stats over last <<1>> <<m:2>>', N, 'match^n'))

    local totalMatches = stats.totalMatches

    local winrate = PossibleNan(stats.totalWon / totalMatches)

    self.winLoseValue:SetText(WL_VALUE_TEXT_FORMAT:format(
        FormatNumber(stats.totalWon),
        FormatNumber(stats.totalLost)
    ))

    local kdaRatio = PossibleNan((stats.totalKills + stats.totalAssists) / stats.totalDeaths)
    self.kdaRatioValue:SetText(string.format('%.1f', kdaRatio))

    -- TODO: left

    -- TODO: reimplement everything below (add tooltip with totals)
    -- local KDAStatsControl = self.statsControl:GetNamedChild('KDAStats')
    -- KDAStatsControl:GetNamedChild('KSum'):SetText(IMP_STATS_SHARED.FormatNumber(stats.totalKills))
    -- KDAStatsControl:GetNamedChild('DSum'):SetText(IMP_STATS_SHARED.FormatNumber(stats.totalDeaths))
    -- KDAStatsControl:GetNamedChild('ASum'):SetText(IMP_STATS_SHARED.FormatNumber(stats.totalAssists))

    local avgK = PossibleNan(stats.totalKills / totalMatches)
    local avgD = PossibleNan(stats.totalDeaths / totalMatches)
    local avgA = PossibleNan(stats.totalAssists / totalMatches)
    self.kdaValue:SetText(KDA_VALUE_TEXT_FORMAT:format(avgK, avgD, avgA))

    local avgDD = PossibleNan(stats.totalDamageDone / totalMatches)
    self.damageDoneValue:SetText(FormatNumber(avgDD))

    local avgHD = PossibleNan(stats.totalHealingDone / totalMatches)
    self.healingDoneValue:SetText(FormatNumber(avgHD))

    local avgDT = PossibleNan(stats.totalDamageTaken / totalMatches)
    self.damageTakenValue:SetText(FormatNumber(avgDT))

    local avgMS = PossibleNan(stats.totalScore / totalMatches)
    self.medalScoreValue:SetText(math.floor(avgMS))

    IMP_STATS_SHARED.SetGaugeKDAMeter(self.gaugeKDAMeter, winrate)

    self.damageDonePerformance:SetValue(stats.EDD or 0)
    self.healingDonePerformance:SetValue(stats.EHD or 0)
    self.damageTakenPerformance:SetValue(stats.EDT or 0)
end

local WIN_LOSE_TEXT_TEMPLATE = 'Won: |c00FF00%d|r\nLost: |cFF0000%d|r\nTied: |c555555%d|r\n\nWR: |cFFFFFF%.2f%%|r'
local DAMAGE_DONE_TEXT_TEMPLATE = 'Average Damage Done:\n|cFFFFFF%s|r\n\nTotal Damage Done:\n|cFFFFFF%s|r'
local HEALING_DONE_TEXT_TEMPLATE = 'Average Healing Done:\n|cFFFFFF%s|r\n\nTotal Healing Done:\n|cFFFFFF%s|r'
local DAMAGE_TAKEN_TEXT_TEMPLATE = 'Average Damage Taken:\n|cFFFFFF%s|r\n\nTotal Damage Taken:\n|cFFFFFF%s|r'
local MEDAL_SCORE_TEXT_TEMPLATE = 'Average Medal Score:\n|cFFFFFF%s|r\n\nTotal Medal Score:\n|cFFFFFF%s|r'

-- local PERFORMANCE_TEMPLATE = 'You are |cFFFFFF%.2f|r times %s in this than others on average.'
local PERFORMANCE_TEMPLATE = '|cFFFFFF%.1fx|r vs. Others\' Avg\n\nTypical range: |cFFFFFF%.1fx - %.1fx|r'
local NOT_ENOUGH_DATA = 'Not enough data... Play some matches first!'

function addon:CreateControls()
    local matchesControl = IMP_STATS_MATCHES
    self.tlc = matchesControl

    assert(matchesControl ~= nil, 'Matches control was not created')

    -- local listControl = matchesControl:GetNamedChild('Listing'):GetNamedChild('ScrollableList')
    local statsControl = matchesControl:GetNamedChild('Header'):GetNamedChild('Stats')
    local filtersControl = matchesControl:GetNamedChild('Header'):GetNamedChild('Filters')

    self.matchesControl = matchesControl
    -- self.listControl = listControl
    self.statsControl = statsControl
    self.filtersControl = filtersControl
    self.performanceMeter = matchesControl:GetNamedChild('PerformanceMeter')

    matchesControl:SetHandler('OnShow', function()
        if self.dirty then self:Update() end
    end)

    local leftInnerContainer = statsControl:GetNamedChild('LeftContainerInnerContainer')
    self.winLoseValue = leftInnerContainer:GetNamedChild('WLValue')
    self.gaugeKDAMeter = leftInnerContainer:GetNamedChild('GaugeKDAMeter')
    IMP_STATS_SHARED.SetGaugeKDAMeter(self.gaugeKDAMeter, 0.5)

    local rightContainer = statsControl:GetNamedChild('RightContainer')

    local topContainer = rightContainer:GetNamedChild('TopContainer')
    self.kdaRatioValue = topContainer:GetNamedChild('KDARatio'):GetNamedChild('Value')
    self.kdaValue = topContainer:GetNamedChild('KDA'):GetNamedChild('Value')
    self.matchCounterValue = topContainer:GetNamedChild('MatchCounterValue')

    local bottomContainer = rightContainer:GetNamedChild('BottomContainer')
    self.damageDoneValue = bottomContainer:GetNamedChild('Damage'):GetNamedChild('Value')
    self.healingDoneValue = bottomContainer:GetNamedChild('Healing'):GetNamedChild('Value')
    self.damageTakenValue = bottomContainer:GetNamedChild('Taken'):GetNamedChild('Value')
    self.medalScoreValue = bottomContainer:GetNamedChild('Medals'):GetNamedChild('Value')

    self.damageDonePerformance = bottomContainer:GetNamedChild('DamagePerformance')
    self.healingDonePerformance = bottomContainer:GetNamedChild('HealingPerformance')
    self.damageTakenPerformance = bottomContainer:GetNamedChild('TakenPerformance')

    local controlsWithTooltips = {
        self.winLoseValue,
        -- self.gaugeKDAMeter,
        -- self.kdaRatioValue,
        -- self.kdaValue,
        -- self.matchCounterValue,
        self.damageDoneValue,
        self.healingDoneValue,
        self.damageTakenValue,
        self.medalScoreValue,
        self.damageDonePerformance,
        self.healingDonePerformance,
        self.damageTakenPerformance,
    }

    for i = 1, #controlsWithTooltips do
        local ctrl = controlsWithTooltips[i]
        ctrl:SetMouseEnabled(true)
        ctrl:SetHandler('OnMouseExit', ZO_Tooltips_HideTextTooltip)
    end

    local stats = self.stats

    self.winLoseValue:SetHandler('OnMouseEnter', function(ctrl)
        if not stats.totalMatches or stats.totalMatches == 0 then
            ZO_Tooltips_ShowTextTooltip(ctrl, nil, NOT_ENOUGH_DATA)
        else
            local winrate = stats.totalWon / stats.totalMatches * 100
            ZO_Tooltips_ShowTextTooltip(ctrl, nil,
                WIN_LOSE_TEXT_TEMPLATE:format(stats.totalWon, stats.totalLost, stats.totalTied, winrate)
            )
        end
    end)

    local function _tooltipHelper(parameter, tooltipTemplate)
        return function(ctrl)
            if not stats[parameter] or stats.totalMatches == 0 then return end

            -- ZO_Tooltips_ShowTextTooltip(ctrl, nil, tooltipTemplate:format(
            --     comma_value(math.floor(stats[parameter] / stats.totalMatches)..''),
            --     comma_value(stats[parameter]..''))
            -- )

            local r, g, b = ZO_TOOLTIP_DEFAULT_COLOR:UnpackRGB()

            InitializeTooltip(InformationTooltip)
            ZO_Tooltips_SetupDynamicTooltipAnchors(InformationTooltip, ctrl)
            InformationTooltip:AddLine(
                tooltipTemplate:format(
                    comma_value(math.floor(stats[parameter] / stats.totalMatches)..''),
                    comma_value(stats[parameter]..'')
                ),
                '',
                r, g, b,
                nil,
                nil,
                TEXT_ALIGN_CENTER
            )
        end
    end

    self.damageDoneValue:SetHandler('OnMouseEnter', _tooltipHelper('totalDamageDone', DAMAGE_DONE_TEXT_TEMPLATE))
    self.healingDoneValue:SetHandler('OnMouseEnter', _tooltipHelper('totalHealingDone', HEALING_DONE_TEXT_TEMPLATE))
    self.damageTakenValue:SetHandler('OnMouseEnter', _tooltipHelper('totalDamageTaken', DAMAGE_TAKEN_TEXT_TEMPLATE))
    self.medalScoreValue:SetHandler('OnMouseEnter', _tooltipHelper('totalScore', MEDAL_SCORE_TEXT_TEMPLATE))

    -- self.damageDoneValue:SetHandler('OnMouseEnter', function(ctrl)
    --     if not stats.totalDamageDone then return end

    --     ZO_Tooltips_ShowTextTooltip(ctrl, nil, DAMAGE_DONE_TEXT_TEMPLATE:format(
    --         comma_value(stats.totalDamageDone / stats.totalMatches),
    --         comma_value(stats.totalDamageDone))
    --     )
    -- end)

    local function _tooltipHelperPerformance(parameter, parameterQ1, parameterQ3)
        local r, g, b = ZO_TOOLTIP_DEFAULT_COLOR:UnpackRGB()

        return function(ctrl)
            InitializeTooltip(InformationTooltip)
            ZO_Tooltips_SetupDynamicTooltipAnchors(InformationTooltip, ctrl)
            local value = stats[parameter]

            if value then
                InformationTooltip:AddLine(
                    PERFORMANCE_TEMPLATE:format(
                        -- value >= 1 and value or 1 / value,
                        value,
                        -- value >= 1 and 'Higher' or 'Lower',
                        stats[parameterQ1],
                        stats[parameterQ3]
                    ),
                    '',
                    r, g, b,
                    nil,
                    nil,
                    TEXT_ALIGN_CENTER
                )
            else
                InformationTooltip:AddLine(NOT_ENOUGH_DATA, '', r, g, b, nil, nil, TEXT_ALIGN_CENTER)
            end
        end
    end

    self.damageDonePerformance:SetHandler('OnMouseEnter', _tooltipHelperPerformance('EDD', 'Q1DD', 'Q3DD'))
    self.healingDonePerformance:SetHandler('OnMouseEnter', _tooltipHelperPerformance('EHD', 'Q1HD', 'Q3HD'))
    self.damageTakenPerformance:SetHandler('OnMouseEnter', _tooltipHelperPerformance('EDT', 'Q1DT', 'Q3DT'))

    if PP then
        local playersButton = self.tlc:GetNamedChild('OpenPlayers')
        playersButton:ClearAnchors()
        playersButton:SetAnchor(BOTTOMLEFT, self.tlc, TOPLEFT, -12, -8)

        local divider = matchesControl:GetNamedChild('Divider')
        local isValidAnchor, point, relativeTo, relativePoint, offsetX, offsetY, anchorConstrains = divider:GetAnchor(0)
        divider:SetAnchorOffsets(8, offsetY, 1)
    end

    Log('Controls created')
end

local GAME_TYPE_ABBREVIATION = {
    [BATTLEGROUND_GAME_TYPE_CAPTURE_THE_FLAG] = 'CR',
    [BATTLEGROUND_GAME_TYPE_CRAZY_KING] = 'CK',
    [BATTLEGROUND_GAME_TYPE_DEATHMATCH] = 'DM',
    [BATTLEGROUND_GAME_TYPE_DOMINATION] = 'Dom',
    -- [BATTLEGROUND_GAME_TYPE_KING_OF_THE_HILL] = 'KOtH',  -- not present in the game rn
    [BATTLEGROUND_GAME_TYPE_MURDERBALL] = 'CB',  -- Chaosball
    -- [BATTLEGROUND_GAME_TYPE_NONE] = 'None',
}

local tooltipTable = {}

local function AddLine(line)
    tooltipTable[#tooltipTable+1] = line or ''
end

local function ClearTooltip()
    ZO_ClearNumericallyIndexedTable(tooltipTable)
end

local RACE_CLASS_ROW = '%s / %s'

function addon:BuildTooltip(rowControl)
    ClearTooltip()

    local data = rowControl.dataEntry.data
    local summary = self:GetMatchSummary(data[1])

    if summary.entryTimestamp then
        local formattedTime = os.date('%d.%m.%Y %H:%M', summary.entryTimestamp)
        AddLine(formattedTime)
        AddLine()
    end
    AddLine(zo_strformat('<<1>> (<<2>>)', summary.displayName, summary.characterName))
    AddLine(RACE_CLASS_ROW:format(GetRaceName(0, summary.playerRace), GetClassName(0, summary.playerClass)))
    AddLine(self.matches[data[1]].playedFromStart == true and 'Played from beginning' or self.matches[data[1]].playedFromStart == false and 'Played NOT from beginning' or '(?) Played from beginning')
    AddLine(TEAM_TYPES[self.matches[data[1]].teamType] .. ', ' .. (self.matches[data[1]].grouped == true and 'Grouped' or self.matches[data[1]].grouped == false and 'Solo' or '(?) Solo/Grouped'))

    AddLine()

    -- tooltip = tooltip .. '\nScores:'
    local localPlayerTeam = self.matches[data[1]].rounds[1].players[1].battlegroundTeam
    local otherTeam = localPlayerTeam == 1 and 2 or 1
    for roundIndex, roundData in ipairs(self.matches[data[1]].rounds) do
        if roundData.result ~= BATTLEGROUND_ROUND_RESULT_INVALID then
            local localPlayerTeamScore = roundData.scores[localPlayerTeam]
            local otherTeamScore = roundData.scores[otherTeam]
            local color = localPlayerTeamScore >= otherTeamScore and '00FF00' or 'FF0000'
            AddLine(('|c%sRound %d:|r %d - %d'):format(color, roundIndex, localPlayerTeamScore, otherTeamScore))
        end
    end

    -- if self.matchSummaries[data[1]].damageDoneRatio then
    --     tooltip = tooltip .. '\n'
    --     tooltip = tooltip .. ('Ratio: %.2f'):format(self.matchSummaries[data[1]].damageDoneRatio)
    -- end

    return table.concat(tooltipTable, '\n')
end

function addon:ShowTooltip(rowControl)
    ZO_Tooltips_ShowTextTooltip(rowControl, LEFT, self:BuildTooltip(rowControl))
end

local ALPHA = 0.6
local COLOR_OF_RESULT = {
    [BATTLEGROUND_RESULT_WIN]  = {     0,      1,      0, ALPHA},
    [BATTLEGROUND_RESULT_LOSS] = {     1,      0,      0, ALPHA},
    [BATTLEGROUND_RESULT_TIE]  = {55/255, 55/255, 55/255, ALPHA},
    [BATTLEGROUND_RESULT_INVALID] = {135/255, 206/255, 235/255, ALPHA},
}

--[[
local function ShowRMBMenu(control, button)
    if button ~= MOUSE_BUTTON_INDEX_RIGHT then return end

    local data = control.dataEntry.data
    local particularMatch = self.matches[data.matchIndex]
    local text = particularMatch.playedFromStart and 'Mark as played NOT from beginning' or 'Mark as played from beginning'

    ClearMenu()

    AddCustomMenuItem(text, function()
        particularMatch.playedFromStart = not particularMatch.playedFromStart
        GetControl(control, 'Warning'):SetHidden(particularMatch.playedFromStart)
    end)

    ShowMenu()
end
--]]

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
	local TH = IMP_STATS_TABLESTYLES.Text.Header

	local ClassIcon = IMP_STATS_TABLESTYLES.ClassIcon

	local SORTABLE = true
	local columns = {
        Column('Index', 	   40,  0, TC.Right,     '###',  TH.Right,      SORTABLE),
		Column('Mode',  	   56,  8, TC.Center,    'Mode', TH.Center, not SORTABLE),
		Column('Map',  	      180,  0, TC.Left,     'Map',   TH.Left,   not SORTABLE),
		Column('Class', 	   50,  0, ClassIcon,	'Class', TH.Center, not SORTABLE),
		Column('Score',  	   70,  0, TC.Center,   'Score', TH.Center,     SORTABLE),
        Column('Kills',        60,  0, TC.Center,	'Kills', TH.Center,     SORTABLE),
		Column('Deaths',       60,  0, TC.Center,  'Deaths', TH.Center,     SORTABLE),
		Column('Assists',      60,  0, TC.Center, 'Assists', TH.Center,     SORTABLE),
        Column('DamageDone',   90,  0, FC.Center,  'Damage', TH.Center,     SORTABLE),
		Column('HealingDone',  90,  0, FC.Center, 'Healing', TH.Center,     SORTABLE),
        Column('DamageTaken',  90,  0, FC.Center,   'Taken', TH.Center,     SORTABLE),
        Column('Build', 	   32,  0, BuildButton,	    nil, TH.Center, not SORTABLE),
    }

	local WITH_HEADERS = true
    local myTable = Table(WITH_HEADERS)

    local function showTooltip(ctrl)
        self:ShowTooltip(ctrl)
    end

    local function onMouseDown(rowControl, button)
        local scrollList = rowControl:GetParent():GetParent()
        ZO_ScrollList_MouseClick(scrollList, rowControl)
    end

    local function LayoutMatchRow(previouslySelectedData, selectedData, selectingDuringRebuild)
		if not selectedData then
			IMP_STATS_VIEWER:OnDeselect()
		elseif selectedData then
			local match = IMP_STATS_MATCHES_MANAGER.matches[selectedData[1]]
            if #match.rounds[1].players < 2 then
                local FULL = true
                match = IMP_STATS_MATCHES_MANAGER.UnpackMatch(IMP_STATS_MATCHES_MANAGER.savedMatches[selectedData[1]], FULL)
            end
			IMP_STATS_VIEWER:LayoutMatch(match)
		end
	end

	local postCreateCallback = function(rowControl)
		local background = CreateControlFromVirtual('$(parent)Background', rowControl, 'IMP_TallListSelectedHighlight')
        background:SetAlpha(0.6)

        rowControl:SetHandler('OnMouseEnter', showTooltip)
        rowControl:SetHandler('OnMouseExit', ZO_Tooltips_HideTextTooltip)

        rowControl:SetHandler('OnMouseDown', onMouseDown)

        local scrollList = rowControl:GetParent():GetParent()

        ZO_ScrollList_EnableSelection(scrollList, 'ZO_ThinListHighlight', LayoutMatchRow)
	    ZO_ScrollList_SetDeselectOnReselect(scrollList, true)
	end
	local postSetupCallback = function(rowControl, dataEntryData, scrollList)
        local result = dataEntryData[13]
        if result then
            GetControl(rowControl, 'Background'):SetHidden(false)
            GetControl(rowControl, 'Background'):SetColor(unpack(COLOR_OF_RESULT[result]))
        else
            GetControl(rowControl, 'Background'):SetHidden(true)
        end
	end
    myTable:AddDataType(1, columns, 32, postCreateCallback, postSetupCallback)


	myTable:SetDefaultSortingCriteria(1, ZO_SORT_ORDER_DOWN)

	local REPLACE = true
    local scrollControl = myTable:Create('Listing', self.tlc, REPLACE)
    -- scrollControl:SetDimensions(1048+36-75-8, 0)

	self.table = myTable
end

local function CreateMatchSummary(matchIndex, matchData)
    local matchSummary = {
        index = matchIndex,
        mode = matchData.type,
        result = matchData.result,
        playerRace = matchData.playerRace,
        playerClass =  matchData.playerClass,
        zone = GetZoneNameById(matchData.zoneId),
        medalScore = 0,
        kills = 0,
        deaths = 0,
        assists = 0,
        damageDone = 0,
        healingDone = 0,
        damageTaken = 0,
        entryTimestamp = matchData.entryTimestamp,
        rounds = #matchData.rounds,
    }

    for roundIndex, roundData in ipairs(matchData.rounds) do
        local roundPlayerData = roundData.players[1]  -- player 1 = always local player

        -- should I check first player is actually local player?
        if roundPlayerData then
            matchSummary.kills      = matchSummary.kills            + roundPlayerData.kills
            matchSummary.deaths     = matchSummary.deaths           + roundPlayerData.deaths
            matchSummary.assists    = matchSummary.assists          + roundPlayerData.assists
            matchSummary.damageDone     = matchSummary.damageDone   + roundPlayerData.damageDone
            matchSummary.healingDone    = matchSummary.healingDone  + roundPlayerData.healingDone
            matchSummary.damageTaken    = matchSummary.damageTaken  + roundPlayerData.damageTaken
            matchSummary.medalScore     = matchSummary.medalScore   + roundPlayerData.medalScore

            matchSummary.displayName = roundPlayerData.displayName
            matchSummary.characterName = roundPlayerData.characterName
        end
    end

    if matchSummary.rounds == 1 then
        local sDD, sHD, sDT, sK = 0, 0, 0, 0

        local players = matchData.rounds[1].players
        for p = 2, #players do
            sDD = sDD + players[p].damageDone
            sHD = sHD + players[p].healingDone
            sDT = sDT + players[p].damageTaken
            sK = sK + players[p].kills
        end

        local nOthers = #players - 1
        matchSummary.damageDoneRatio  = players[1].damageDone  * nOthers / sDD
        matchSummary.damageTakenRatio = players[1].damageTaken * nOthers / sDT
        matchSummary.healingDoneRatio = players[1].healingDone * nOthers / sHD
        matchSummary.killsRatio       = players[1].kills       * nOthers / sK
    end

    return matchSummary
end

function addon:UpdateMatchSummary(matchIndex)
    if self.matchSummaries[matchIndex] then return end

    self.matchSummaries[matchIndex] = CreateMatchSummary(matchIndex, self.matches[matchIndex])
end

function addon:GetMatchSummary(matchIndex)
    if not self.matchSummaries[matchIndex] then
        self.matchSummaries[matchIndex] = CreateMatchSummary(matchIndex, self.matches[matchIndex])
    end

    return self.matchSummaries[matchIndex]
end

function addon:AddFilter(filterCallback)
    table.insert(self.filters, filterCallback)
end

-- function addon:PassFilters(data)
--     for _, filter in ipairs(self.filters) do
--         if not filter(data) then return end
--     end

--     return true
-- end

function addon:CalculateStats(task)
    self.stats:Clear()

    local function AddMatch(index, matchIndex)
        matchIndex = self.dataRows[index]
        self.stats:AddMatch(matchIndex, self:GetMatchSummary(matchIndex))
    end

    local LAST_N = #self.dataRows
    if IMP_STATS_MATCHES_MANAGER.sv.last150 then LAST_N = 150 end

    local stopIndex = #self.dataRows
    local startIndex = math.max(1, stopIndex - LAST_N + 1)

    Log('Calculating stats, start: %d, stop: %s', startIndex, stopIndex)

    return task:Call(function() task:For(startIndex, stopIndex):Do(AddMatch) end)  -- ipairs(self.dataRows)
end

function addon:IsHidden()
    return self.matchesControl:IsHidden()
end

function addon:Update()
    -- TODO ShowWarning
    local updateStart = GetGameTimeSeconds()

    if self:IsHidden() then
        self.dirty = true
        return
    end

    -- TODO: clear via ZO_ClearTable etc.?
    self.dataRows = {}

    -- local function UpdateSummaries(task)
    --     return task:For(ipairs(self.dataRows)):Do(function(index, matchIndex) self:UpdateMatchSummary(matchIndex) end)
    -- end

    local task = LibAsync:Create('UpdateBattlegroundsDataRows')

    IMP_STATS_MATCHES_MANAGER
    :GetMatches(task, self.filters, self.dataRows)
    :Then(function()
        self:UpdateScrollList()
        self:CalculateStats(task)
        :Then(function() self.stats:NewStats() end)
        :Then(function() self:UpdateStatsControl() end)
    end)
    :Then(function() self.dirty = false end)
    :Then(function()
        local updateDuration = GetGameTimeSeconds() - updateStart
        -- self.performanceMeter:SetText(('Update ~%d ms'):format(updateDuration * 1000))
    end)
end

function addon:UpdateScrollList()
    local matches = self.dataRows

    local data = {}
    for i = 1, #matches do
        local matchId = matches[i]
        local summary = self:GetMatchSummary(matchId)

        -- GetControl(rowControl, 'Warning'):SetHidden(self.matches[data.matchIndex].playedFromStart)  -- TODO

        data[#data+1] = {
            matchId,
            GAME_TYPE_ABBREVIATION[summary.mode],
            summary.zone,
            summary.playerClass,
            summary.medalScore,
            summary.kills,
            summary.deaths,
            summary.assists,
            summary.damageDone,
            summary.healingDone,
            summary.damageTaken,
            self.matches[i].superstar ~= nil,
            summary.result
        }
    end

    self.table:Update(1, data)
end

local InitializeFilter = IMP_STATS_SHARED.InitializeFilter

-- local function SelectAllElements(filter)
--     for i, item in ipairs(filter.m_sortedItems) do
--         filter:SelectItem(item, true)
--     end
-- end

function addon:InitializeTeamTypeFilter()
    local entriesData = {}

    for teamType, teamTypeName in ipairs(TEAM_TYPES) do
        entriesData[teamType] = {
            type = teamType,
            text = teamTypeName,
        }
    end

    local function callback(newSelection)
        self.selections.teamTypes = newSelection
        self:Update()
    end

    local filterControl = GetControl(self.filtersControl, 'FilterTeamType')
    local filter = InitializeFilter(filterControl, entriesData, callback)
    filter:SetNoSelectionText('|cFF0000Select Team Type|r')
    filter:SetMultiSelectionTextFormatter('<<1[$d Team Type/$d Team Types]>>')

    -- SelectAllElements(filter)
    -- TODO: hash table?
    local function SelectTeamType(teamType)
        for i, item in ipairs(filter.m_sortedItems) do
            if item.filterType == teamType then
                filter:SelectItem(item, true)
                return
            end
        end
    end
    for _, mode in ipairs(self.selections.teamTypes) do
        SelectTeamType(mode)
    end

    return filter
end

function addon:InitializeMatchModeFilter()
    local entriesData = {}

    -- TODO: game types
    for mode, modeName in pairs(GAME_TYPE_ABBREVIATION) do
        table.insert(entriesData, {
            text = string.format(
                '%s (%s)',
                GetString('SI_BATTLEGROUNDGAMETYPE', mode),
               modeName
            ),
            type = mode,
        })
    end

    --[[
    for i = 1, 6 do
        table.insert(entriesData, {
            text = string.format(
                '%s (%s)',
                GetString('SI_BATTLEGROUNDGAMETYPE', i),
                GAME_TYPE_ABBREVIATION[i]
            ),
            type = i,
        })
    end
    ]]

    local function callback(newSelection)
        self.selections.modes = newSelection
        self:Update()
    end

    local filterControl = GetControl(self.filtersControl, 'FilterGameMode')
    local filter = InitializeFilter(filterControl, entriesData, callback)
    filter:SetNoSelectionText('|cFF0000Select Match Mode|r')
    filter:SetMultiSelectionTextFormatter('<<1[$d Mode/$d Modes]>>')

    -- SelectAllElements(filter)
    -- TODO: hash table?
    local function SelectMode(mode)
        for i, item in ipairs(filter.m_sortedItems) do
            if item.filterType == mode then
                filter:SelectItem(item, true)
                return
            end
        end
    end
    for _, mode in ipairs(self.selections.modes) do
        SelectMode(mode)
    end

    return filter
end

addon.InitializePlayerCharactersFilter = IMP_STATS_SHARED.InitializePlayerCharactersFilter

function addon:Initialize(naming, selections, filterByApi, debugging)
    self.matches = IMP_STATS_MATCHES_MANAGER.matches
    self.matchSummaries = {}
    self.stats = MatchesStats:New()

    self:CreateControls()
    self:_createTable()

    local function GoodDataFilter(matchData)
        -- if not matchData.rounds then
        --     -- Log('matchData.rounds is not present')
        --     return
        -- end

        if not matchData.rounds or #matchData.rounds < 1 then
            -- Log('Less than 1 round: %s', tostring(#matchData.rounds))
            return
        end

        if #matchData.rounds[1].players < 1 then
            -- Log('No players recorded')
            -- TODO: add players on BG start
            return
        end

        if not matchData.result then  -- shit to fix some errors
            -- Log('No match result')
            return
        end

        -- if matchData.result == BATTLEGROUND_RESULT_INVALID then
        --     return
        -- end

        return true
    end
    self:AddFilter(GoodDataFilter)

    local function GetMatchTeamType(matchData)
        -- teamType set function moved to MatchManager 1.1.0

        return matchData.teamType
    end

    local function TeamTypeFilter(matchData)
        for i, option in ipairs(self.selections.teamTypes) do
            -- Log('Match %d, teamType: %d', i, GetMatchTeamType(matchData))
            if GetMatchTeamType(matchData) == option then return true end
        end
    end
    self:AddFilter(TeamTypeFilter)

    local function ModeFilter(matchData)
        for i, option in ipairs(self.selections.modes) do
            if matchData.type == option then return true end  -- type is old name for mode
        end
    end
    self:AddFilter(ModeFilter)

    local function CharactersFilter(matchData)
        -- local rounds = matchData.rounds
        -- local players = rounds[1].players
        -- local player = players[1]
        -- local chId = player.characterId
        local chId = matchData.playerCharacterId

        return chId and self.selections.characters[chId]
    end
    if not debugging then
        self:AddFilter(CharactersFilter)
    end

    if filterByApi then
        local currentApiVerision = GetAPIVersion()
        local function ShowOnlyLastUpdateFilter(matchData)
            return matchData.api == currentApiVerision
        end
        self:AddFilter(ShowOnlyLastUpdateFilter)
    end

    for selectionName, defaultSelectionData in pairs(self.selections) do
        selections[selectionName] = selections[selectionName] or defaultSelectionData
    end
    self.selections = selections
    -- self.selections = selections or self.selections

    self:InitializeTeamTypeFilter()
    self:InitializeMatchModeFilter()

    if IMP_STATS_SHARED.TableLength(self.selections.characters) < 1 then
        self.selections.characters[GetCurrentCharacterId()] = true
    end
    self:InitializePlayerCharactersFilter(GetControl(self.filtersControl, 'CharactersFilter'), self.selections.characters)

    local manager = IMP_STATS_MATCHES_MANAGER
    if manager.states then
        local function OnMatchStateChanged(oldState, newState)
            if newState ~= manager.states.MATCH_STATE_ENDED then return end
            self:Update()
        end

        manager:RegisterCallback(EVENT_NAMESPACE, manager.events.EVENT_MATCH_STATE_CHANGED, OnMatchStateChanged)

        self:Update()
    end
end
--#endregion

function addon:LayoutBuildFor(row)
    if not (row and row.dataEntry and row.dataEntry.data[1]) then return end

    local matchIndex = row.dataEntry.data[1]

    LibDataPacker_Build_LayoutShortBuild(self.matches[matchIndex].superstar)
end

do
    IMP_STATS_MATCHES_UI = addon
end