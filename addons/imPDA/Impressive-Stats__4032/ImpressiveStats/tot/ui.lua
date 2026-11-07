local IMP_STATS_SHARED = IMP_STATS_SHARED

local PATRON_ABBRIVIATIONS = {
    [1] = "Saint Pelin",  -- Saint Pelin
    [2] = "Treasury",  -- Treasury
    [3] = "Grandmaster Delmene Hlaalu",  -- Grandmaster Delmene Hlaalu
    [4] = "Duke of Crows",  -- Duke of Crows
    [5] = "Psijic Loremaster Celarus",  -- Psijic Loremaster Celarus
    [7] = "Ansei Frandar Hunding",  -- Ansei Frandar Hunding
    [8] = "Red Eagle, King of the Reach",  -- Red Eagle, King of the Reach
    [9] = "Sorcerer-King Orgnum",  -- Sorcerer-King Orgnum
    [10] = "Rajhin, the Purring Liar",  -- Rajhin, the Purring Liar
    [11] = "Grand Master Fillia",  -- Grand Master Fillia
    [12] = "Grand Master Linyia",  -- Grand Master Linyia
    [13] = "Grand Master Murzaga",  -- Grand Master Murzaga
    [14] = "Grand Master Nhorhim",  -- Grand Master Nhorhim
    [15] = "The Author",  -- The Author
    [16] = "Ansei Frandar Hunding",  -- Ansei Frandar Hunding
    [17] = "Duke of Crows",  -- Duke of Crows
    [18] = "Grandmaster Delmene Hlaalu",  -- Grandmaster Delmene Hlaalu
    [19] = "Psijic Loremaster Celarus",  -- Psijic Loremaster Celarus
    [20] = "Rajhin, the Purring Liar",  -- Rajhin, the Purring Liar
    [21] = "Red Eagle, King of the Reach",  -- Red Eagle, King of the Reach
    [22] = "Saint Pelin",  -- Saint Pelin
    [23] = "Sorcerer-King Orgnum",  -- Sorcerer-King Orgnum
    [24] = "The Druid King",  -- The Druid King
    [25] = "Druid Braigh",  -- Druid Braigh
    [26] = "The Druid King",  -- The Druid King
    [27] = "Almalexia",  -- Almalexia
    [28] = "Armiger Bolm, The Paramount",  -- Armiger Bolm, The Paramount
    [29] = "Almalexia",  -- Almalexia
    [30] = "Hermaeus Mora",  -- Hermaeus Mora
    [31] = "Metrand Vyrix",  -- Metrand Vyrix
    [32] = "Hermaeus Mora",  -- Hermaeus Mora
    [33] = "Saint Alessia",  -- Saint Alessia
    [34] = "Master Caledonia",  -- Master Caledonia
    [35] = "Saint Alessia",  -- Saint Alessia
}

local addon = {}

addon.name = 'IMP_STATS_TRIBUTE_UI'

addon.listControl = nil
addon.statsControl = nil

addon.filters = {
    opponentName = '',
    selectedCharacters = {},
}

local EVENT_NAMESPACE = 'IMP_STATS_TRIBUTE_UI'

local Log = IMP_STATS_Logger('TOT_UI')

--#region IMP STATS TRIBUTE UI
function addon:UpdateStatsControl()
    local stats = IMP_STATS_TRIBUTE_STATS_MANAGER.totalStats

    local games = stats.totalFP + stats.totalSP
    self.statsControl:GetNamedChild('TotalGamesValue'):SetText(games)

    self.statsControl:GetNamedChild('HighestRankValue'):SetText(stats.highestRank or '-')

    local won = stats.totalWonFP + stats.totalWonSP
    local lost = stats.totalLostFP + stats.totalLostSP
    local winrate = IMP_STATS_SHARED.PossibleNan(won / games)
    self.statsControl:GetNamedChild('WinrateValue'):SetText(
        string.format('%.1f %% (|c00FF00%d|r / |cFF0000%d|r)', winrate * 100, won, lost)
    )

    local FPWon = stats.totalWonFP
    local FPLost = stats.totalLostFP
    local FPWinrate = IMP_STATS_SHARED.PossibleNan(FPWon / (FPWon + FPLost))
    self.statsControl:GetNamedChild('FirstPickWinrateValue'):SetText(
        string.format('%.1f %% (|c00FF00%d|r / |cFF0000%d|r)', FPWinrate * 100, FPWon, FPLost)
    )

    local SPWon = stats.totalWonSP
    local SPLost = stats.totalLostSP
    local SPWinrate = IMP_STATS_SHARED.PossibleNan(SPWon / (SPWon + SPLost))
    self.statsControl:GetNamedChild('SecondPickWinrateValue'):SetText(
        string.format('%.1f %% (|c00FF00%d|r / |cFF0000%d|r)', SPWinrate * 100, SPWon, SPLost)
    )

    -- self.statsControl:GetNamedChild('TotalsValue'):SetText(
    --     string.format(
    --         '%s / %s / %s',
    --         IMP_STATS_SHARED.FormatNumber(self.stats.totalDamageDone),
    --         IMP_STATS_SHARED.FormatNumber(self.stats.totalDamageTaken),
    --         IMP_STATS_SHARED.FormatNumber(self.stats.totalHealingTaken)
    --     )
    -- )

    IMP_STATS_SHARED.SetGaugeKDAMeter(self.statsControl:GetNamedChild('GaugeKDAMeter'), winrate)
end

local WIN = 1
local LOSS = 2

-- TODO: make color uniforme and global
local COLOR_OF_RESULT = {
    [WIN] = ZO_ColorDef:New(0, 1, 0, 1),
    [LOSS] = ZO_ColorDef:New(1, 0, 0, 1),
    -- [PLAYER_FORFEIT] = {35/255, 35/255, 35/255, 1},
    -- [OPPONENT_FORFEIT] = {75/255, 75/255, 75/255, 1},
}
local NEUTRAL = ZO_ColorDef:New(75/255, 75/255, 75/255, 1)

function addon.GetName(data)
    assert(false, 'Must be owerritten!')
end

function addon:CreateScrollListDataType()
    local function LayoutRow(rowControl, data, scrollList)
        local game = IMP_STATS_TRIBUTE_MANAGER.games[data.gameIndex]

        local upIcon = zo_iconFormatInheritColor('/esoui/art/tooltips/arrow_up.dds', 12, 12)
        local downIcon = zo_iconFormatInheritColor('/esoui/art/tooltips/arrow_down.dds', 12, 12)
        if game.win ~= nil then
            local result = game.win and WIN or LOSS
            GetControl(rowControl, 'BG'):SetHidden(false)
            GetControl(rowControl, 'Result'):SetText(game.win and 'W' or 'L')
            GetControl(rowControl, 'Result'):SetColor(COLOR_OF_RESULT[result]:UnpackRGBA())
        end
        GetControl(rowControl, 'Index'):SetText(data.index)

        local duration = IMP_STATS_SHARED.SecondsToTime(zo_round(game.duration / 1000))
        GetControl(rowControl, 'Duration'):SetText(duration)

        GetControl(rowControl, 'OpponentName'):SetText(game.opponent.name)

        local patronsControl = GetControl(rowControl, 'Patrons')
        local patrons = game.patrons
        if patrons and #patrons > 0 then
            for i = 0, 3 do
                local patronIcon = patronsControl:GetNamedChild('_' .. tostring(i))
                patronIcon:SetTexture(GetTributePatronSmallIcon(patrons[i]))
                patronIcon:SetHandler('OnMouseEnter', function()
                    InitializeTooltip(IMP_STATS_Tribute_Tooltip, patronIcon, BOTTOM)
                    IMP_STATS_Tribute_Tooltip:AddLine(GetTributePatronName(patrons[i]), "", ZO_TOOLTIP_DEFAULT_COLOR:UnpackRGB())
                    ZO_PropagateHandler(rowControl, 'OnMouseEnter', rowControl)
                end)
                patronIcon:SetHandler('OnMouseExit', function()
                    ClearTooltip(IMP_STATS_Tribute_Tooltip)
                    ZO_PropagateHandler(rowControl, 'OnMouseExit', rowControl)
                end)
            end
            patronsControl:SetHidden(false)
        else
            patronsControl:SetHidden(true)
        end

        local fp = (game.fp == nil and '?') or (game.fp and '1P' or '2P')
        GetControl(rowControl, 'Pick'):SetText(fp)
        GetControl(rowControl, 'Score'):SetText(string.format('%d/%d', game.player.score or 0, game.opponent.score or 0))

        local THE_LESS_THE_BETTER = -1
        local function IconSighColor(before, after, direction)
            if after == before and after == 0 then return '-' end

            direction = direction or 1
            if after then
                if before then
                    local diff = (after - before) * direction

                    if diff ~= 0 then
                        local icon = diff > 0 and upIcon or downIcon
                        local color = diff > 0 and COLOR_OF_RESULT[WIN] or COLOR_OF_RESULT[LOSS]
                        local text = string.format('%d (%s%d)', after, icon, diff)

                        return color:Colorize(text)
                    else
                        return after
                    end
                else
                    return after
                end
            else
                return '?'
            end
        end

        rowControl:SetHandler('OnMouseDown', function(control, button)
            if button == MOUSE_BUTTON_INDEX_RIGHT then
                ClearMenu()

                AddCustomMenuItem('Edit note', function()
                    IMP_STATS_NOTES_MANAGER:ShowEditNoteDialog(game.opponent.name)
                end)

                ShowMenu()
            end
        end)

        GetControl(rowControl, 'PlayerMMR'):SetText(IconSighColor(game.player.atStart.mmr, game.player.atEnd.mmr))
        GetControl(rowControl, 'Rank'):SetText(IconSighColor(game.player.atStart.rank, game.player.atEnd.rank, THE_LESS_THE_BETTER))

        GetControl(rowControl, 'TopPercent'):SetText(string.format('%.1f%%', (game.player.atEnd.topP or 0) * 100))

        -- rowControl:SetHandler('OnMouseUp', function()
        --     ZO_ScrollList_MouseClick(scrollList, rowControl)
        -- end)

        local tooltip = {}

        if game.timestamp then
            tooltip[#tooltip+1] = os.date('%d.%m.%Y %H:%M', game.timestamp)
        end

        local note = IMP_STATS_NOTES_MANAGER:GetNote(game.opponent.name)
        if note then
            tooltip[#tooltip+1] = ''
            tooltip[#tooltip+1] = 'Note:'
            tooltip[#tooltip+1] = note
        end

        if patrons and #patrons > 0 then
            local drafts = {
                [1] = {
                    patrons[TRIBUTE_PATRON_DRAFT_ID_FIRST_PLAYER_FIRST_PICK],
                    patrons[TRIBUTE_PATRON_DRAFT_ID_FIRST_PLAYER_SECOND_PICK],
                },
                [2] = {
                    patrons[TRIBUTE_PATRON_DRAFT_ID_SECOND_PLAYER_FIRST_PICK],
                    patrons[TRIBUTE_PATRON_DRAFT_ID_SECOND_PLAYER_SECOND_PICK],
                }
            }
            tooltip[#tooltip+1] = ''
            tooltip[#tooltip+1] = 'Your pick:'
            local q = game.fp and 1 or 2
            for n = 1, 2 do
                tooltip[#tooltip+1] = ('|t20:20:%s|t %s'):format(GetTributePatronSmallIcon(drafts[q][n]), GetTributePatronName(drafts[q][n]))
            end
            tooltip[#tooltip+1] = ''
            tooltip[#tooltip+1] = 'Opponent pick:'
            q = game.fp and 2 or 1
            for n = 1, 2 do
                tooltip[#tooltip+1] = ('|t20:20:%s|t %s'):format(GetTributePatronSmallIcon(drafts[q][n]), GetTributePatronName(drafts[q][n]))
            end
        end

        rowControl:SetHandler('OnMouseEnter', function() ZO_Tooltips_ShowTextTooltip(rowControl, LEFT, table.concat(tooltip, '\n')) end)
        rowControl:SetHandler('OnMouseExit', function() ZO_Tooltips_HideTextTooltip() end)
    end

	local control = self.listControl
	local typeId = 1
	local templateName = 'IMP_STATS_TributeGameSummaryRow'  -- TODO: change
	local height = 32
	local setupFunction = LayoutRow
	local hideCallback = nil
	local dataTypeSelectSound = nil
	local resetControlCallback = nil

	ZO_ScrollList_AddDataType(control, typeId, templateName, height, setupFunction, hideCallback, dataTypeSelectSound, resetControlCallback)

    -- local selectTemplate = 'ZO_ThinListHighlight'
	-- local selectCallback = nil
	-- ZO_ScrollList_EnableSelection(control, selectTemplate, selectCallback)
end

function addon:AddFilter(filterCallback)
    table.insert(self.filters, filterCallback)
end

function addon:UpdateScrollListControl(task)
    local control = self.listControl
    local data = self.dataRows

	local dataList = ZO_ScrollList_GetDataList(control)

	ZO_ScrollList_Clear(control)

    local function CreateAndAddDataEntry(index)
        local value = {index = index, gameIndex = data[index]}
        local entry = ZO_ScrollList_CreateDataEntry(1, value)
		table.insert(dataList, entry)
    end

	-- table.sort(dataList, function(a,b) return a.data.index > b.data.index end)

    return task:Call(function() task:For(#data, 1, -1):Do(CreateAndAddDataEntry):Then(function() ZO_ScrollList_Commit(control) end) end)
end

function addon:CalculateStats(task)
    IMP_STATS_TRIBUTE_STATS_MANAGER:Clear()

    local function AddGame(index, gameIndex)
        IMP_STATS_TRIBUTE_STATS_MANAGER:AddGame(gameIndex, self.games[gameIndex])
    end

    return task:Call(function() task:For(ipairs(self.dataRows)):Do(AddGame) end)
end

local function HideWarning()
    GetControl(IMP_STATS_TRIBUTE, 'Warning'):SetHidden(true)
end

local function ShowWarning()
    GetControl(IMP_STATS_TRIBUTE, 'Warning'):SetHidden(false)
end

function addon:Update()
    if #self.games > 60000 then ShowWarning() end

    self.dataRows = {}

    local task = LibAsync:Create('UpdateToTDataRows')

    IMP_STATS_TRIBUTE_MANAGER:GetGames(task, self.filters, self.dataRows):Then(function()
        self:UpdateScrollListControl(task)
        self:CalculateStats(task):Then(function() self:UpdateStatsControl() end)
    end):Then(HideWarning)
end

function addon:CreateControls()
    local totControl = IMP_STATS_TRIBUTE

    assert(totControl ~= nil, 'Tribute control was not created')

    local listControl = totControl:GetNamedChild('Listing'):GetNamedChild('ScrollableList')
    local statsControl = totControl:GetNamedChild('StatsBlock')

    local function OnSearchTextChanged(editBox, field)
        local newText = string.lower(editBox:GetText())

        Log('[T] New search: ', newText)

        if newText == self.filters[field] then return end

        self.filters[field] = newText
        self:Update()
    end

    local oppSearchBox = totControl:GetNamedChild('OpponentSearchBox')
    oppSearchBox:SetHandler('OnTextChanged', function(editBox) OnSearchTextChanged(editBox, 'opponentName') end)

    self.totControl = totControl
    self.listControl = listControl
    self.statsControl = statsControl
end

local function SelectAllElements(filter)
    for i, item in ipairs(filter.m_sortedItems) do
        filter:SelectItem(item, true)
    end
end

function addon:InitializePlayerCharactersFilter()
    -- TODO: basically copied from bgs and replaced highlighter fucntions, so can make universal function
    local function InitializeFilter(contorl, entriesData, setFiltersCallback)
        local comboBox = ZO_ComboBox_ObjectFromContainer(contorl)

        comboBox:SetSortsItems(false)
        comboBox:SetFont('ZoFontWinT1')
        comboBox:SetSpacing(4)

        local function OnFilterChanged(comboBox, entryText, entry)
            local newFilters = {}

            for i, itemData in ipairs(comboBox.m_selectedItemData) do
                table.insert(newFilters, itemData.filterType)
            end

            setFiltersCallback(newFilters)

            Log('Selection changed: ', table.concat(comboBox.m_selectedItemData, ','))
        end

        for i, entry in ipairs(entriesData) do
            local item = comboBox:CreateItemEntry(entry.text, OnFilterChanged)
            item.filterType = entry.type

            comboBox:AddItem(item)
        end

        return comboBox
    end

    local numCharacters = GetNumCharacters()
    local entriesData = {}

    for i = 1, numCharacters do
        local name, _, _, _, _, _, characterId, _ = GetCharacterInfo(i)
        local formattedName = zo_strformat('<<1>>', name)

        entriesData[i] = {
            text = formattedName,
            type = characterId,
        }
    end

    local function callback(newFilters)
        -- TODO: clear table instead
        for characterId, _ in pairs(self.filters.selectedCharacters) do
            self.filters.selectedCharacters[characterId] = false
        end

        for _, characterId in ipairs(newFilters) do
            self.filters.selectedCharacters[characterId] = true
        end

        self:Update()
    end

    local filterControl = GetControl(self.totControl, 'CharactersFilter')
    local filter = InitializeFilter(filterControl, entriesData, callback)
    filter:SetNoSelectionText('|cFF0000Select Character|r')
    filter:SetMultiSelectionTextFormatter('<<1[$d Character/$d Characters]>> Selected')

    for i, item in ipairs(filter.m_sortedItems) do
        -- Log('%d - %s', i, item.name)
        if self.filters.selectedCharacters[item.filterType] then
            filter:SelectItem(item, true)
            Log('[T] Selecting %s', item.text)
        end
    end
end

function addon:Initialize(naming)
    self.games = IMP_STATS_TRIBUTE_MANAGER.games

    -- local buffer = {}
    -- local NAMINGS = {
    --     [1] = function(data)
    --         if not buffer[data.characterName] then
    --             buffer[data.characterName] = zo_strformat('<<1>>', data.characterName)
    --         end
    --         return buffer[data.characterName]
    --     end,
    --     [2] = function(data)
    --         if not buffer[data.displayName] then
    --             buffer[data.displayName] = data.displayName
    --         end
    --         return buffer[data.displayName]
    --     end,
    --     [3] = function(data)
    --         if not buffer[data.displayName] then
    --             buffer[data.displayName] = zo_strformat('<<1>> (<<2>>)', data.displayName, data.characterName)
    --         end
    --         return buffer[data.displayName]
    --     end,
    -- }
    -- self.GetName = NAMINGS[naming]
    self.GetName = function(data) return data.name end

    self:CreateControls()
    self:CreateScrollListDataType()

    local function OpponentNameFilter(data)
        if self.filters.opponentName == '' then return true end

        -- local characterName = string.lower(data.opponent.characterName)
        -- local displayName = string.lower(data.opponent.displayName)

        -- if string.find(displayName, self.filters.opponentName) or string.find(characterName, self.filters.opponentName) then
        --     return true
        -- end

        local name = string.lower(data.opponent.name)
        return string.find(name, self.filters.opponentName) ~= nil
    end
    self:AddFilter(OpponentNameFilter)

    local task = LibAsync:Create('UpdateTributeScrollList')
    IMP_STATS_NOTES_MANAGER:RegisterCallback(EVENT_NAMESPACE, IMP_STATS_NOTES_MANAGER.events.EVENT_NOTE_EDITED, function() self:UpdateScrollListControl(task) end)
end
--#endregion

do
    IMP_STATS_TRIBUTE_UI = addon
end