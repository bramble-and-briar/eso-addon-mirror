DungeonScores = DungeonScores or {}

local DS = DungeonScores
DS.History = DS.History or {}
local History = DS.History
local Data = DS.Data or {}
local Scoring = DS.Scoring or {}
local WM = WINDOW_MANAGER
local EM = EVENT_MANAGER
local FormatString = DS.Util.FormatString

local PAGE_SIZE = 10
local WINDOW_DEFAULT_WIDTH = 900
local WINDOW_DEFAULT_HEIGHT = 780
local WINDOW_MIN_WIDTH = 760
local WINDOW_MIN_HEIGHT = 760
local WINDOW_MAX_WIDTH = 1600
local WINDOW_MAX_HEIGHT = 1200
local RESIZE_POLL_NAME = "DungeonScoresHistoryResizePoll"
local HIGH_SCORE_DATA_TYPE = 1
local TAB_HISTORY = "history"
local TAB_BASEGAME = "basegame"
local TAB_DLC = "dlc"
local TAB_GUILDS = "guilds"
local TAB_TEAMS = "teams"
local TAB_BETA = "beta"

local TAB_DEFINITIONS = {
    { key = TAB_HISTORY, stringId = SI_DUNGEON_SCORES_TAB_HISTORY, width = 150 },
    { key = TAB_BASEGAME, stringId = SI_DUNGEON_SCORES_TAB_BASEGAME, width = 205 },
    { key = TAB_DLC, stringId = SI_DUNGEON_SCORES_TAB_DLC, width = 175 },
    { key = TAB_GUILDS, stringId = SI_DUNGEON_SCORES_TAB_GUILDS, width = 90 },
    { key = TAB_TEAMS, stringId = SI_DUNGEON_SCORES_TAB_TEAMS, width = 90 },
    { key = TAB_BETA, stringId = SI_DUNGEON_SCORES_TAB_BETA, width = 90 },
}

local HISTORY_IDLE_COLOR = { 0.72, 0.72, 0.72, 1 }
local HIGH_SCORE_IDLE_SCORED = ZO_ColorDef:New(0.72, 0.72, 0.72, 1)
local HIGH_SCORE_IDLE_EMPTY = ZO_ColorDef:New(0.50, 0.50, 0.50, 1)
local PARTY_SIZE_NAMES = { "Solo", "Duo", "Trio", "Quartet" }

local function Clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    return math.max(minimum, math.min(maximum, value))
end

local function MediumFont(size)
    return string.format("$(MEDIUM_FONT)|%d|soft-shadow-thin", zo_round(size))
end

local function BoldFont(size)
    return string.format("$(BOLD_FONT)|%d|soft-shadow-thin", zo_round(size))
end

local function ConfigureWrappingLabel(label)
    if not label then
        return
    end
    label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    label:SetVerticalAlignment(TEXT_ALIGN_TOP)
    label:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
    label:SetMaxLineCount(0)
end

local function NormalizeName(name)
    if not name or name == "" then
        return GetString(SI_DUNGEON_SCORES_UNKNOWN)
    end
    return zo_strformat(SI_UNIT_NAME, name)
end

local function FormatDurationMs(milliseconds)
    if not milliseconds then
        return "--:--"
    end
    local totalSeconds = math.floor(milliseconds / 1000)
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds % 60
    return string.format("%d:%02d", minutes, seconds)
end

local function NumberText(value)
    return ZO_CommaDelimitNumber(tonumber(value) or 0)
end

local function CoefficientText(value)
    value = tonumber(value) or 100
    local rounded = zo_round(value)
    if math.abs(value - rounded) < 0.005 then
        return string.format("%d%%", rounded)
    end
    return string.format("%.2f%%", value)
end

local function PartyAverageText(value)
    value = tonumber(value)
    if not value then
        return GetString(SI_DUNGEON_SCORES_NOT_AVAILABLE)
    end
    return string.format("%.2f", value)
end

local function DateText(timestamp)
    if not timestamp then
        return GetString(SI_DUNGEON_SCORES_UNKNOWN_DATE)
    end
    return GetDateStringFromTimestamp(timestamp)
end

local function SpeedText(settlement)
    if not settlement or not settlement.speedKnown then
        return GetString(SI_DUNGEON_SCORES_UNKNOWN_LOWER)
    end
    return settlement.speedQualified and GetString(SI_DUNGEON_SCORES_YES)
        or GetString(SI_DUNGEON_SCORES_NO)
end

local function YesNo(value)
    return value and GetString(SI_DUNGEON_SCORES_YES)
        or GetString(SI_DUNGEON_SCORES_NO)
end

local function IsTrifectaSupported(settlement)
    if not settlement then
        return false
    end
    if type(Scoring.IsTrifectaSupported) == "function" then
        return Scoring:IsTrifectaSupported(settlement.zoneId) == true
    end
    return settlement.trifectaSupported == true
end

local function IsValidTab(tabKey)
    return tabKey == TAB_HISTORY or tabKey == TAB_BASEGAME or tabKey == TAB_DLC
        or tabKey == TAB_GUILDS or tabKey == TAB_TEAMS or tabKey == TAB_BETA
end

local function GetZoneDisplayName(zoneId)
    zoneId = tonumber(zoneId)
    if not zoneId then
        return GetString(SI_DUNGEON_SCORES_UNKNOWN_DUNGEON)
    end
    local name = GetZoneNameById and GetZoneNameById(zoneId) or nil
    if name and name ~= "" then
        return NormalizeName(name)
    end
    return FormatString(SI_DUNGEON_SCORES_ZONE_FORMAT, zoneId)
end

function History:Initialize(savedVariables)
    self.saved = savedVariables
    self.saved.historyWindow = self.saved.historyWindow or {}
    self.saved.settings = self.saved.settings or {}
    self.saved.settings.browserTitleFontSize = tonumber(self.saved.settings.browserTitleFontSize) or 24
    self.saved.settings.browserHeaderFontSize = tonumber(self.saved.settings.browserHeaderFontSize) or 18
    self.saved.settings.browserListFontSize = tonumber(self.saved.settings.browserListFontSize) or 16
    self.saved.settings.browserDetailFontSize = tonumber(self.saved.settings.browserDetailFontSize) or 16
    local savedTab = self.saved.historyWindow.activeTab
    self.activeTab = IsValidTab(savedTab) and savedTab or TAB_HISTORY
    self.page = 1
    self.selectedIndex = nil
    self.selectedZoneId = nil
    self.selectedPartySize = nil
    self.selectedBetaIndex = nil
    self.selectedTeamIndex = nil
    self.selectedGuildDirectoryIndex = nil
    self.teamEditorNew = false
    self.selectedSettlement = nil
    self.pendingDeleteIndex = nil
    self:CreateWindow()
    self:Refresh()
end

function History:GetHistory()
    if not self.saved then
        return {}
    end
    self.saved.history = self.saved.history or {}
    return self.saved.history
end

function History:GetHighScore(zoneId, partySize)
    if not self.saved then
        return nil
    end
    zoneId = tonumber(zoneId)
    if not zoneId then
        return nil
    end
    if partySize == nil then
        -- Retain the historical overall PB store for compatibility.
        return self.saved.highScores and self.saved.highScores[zoneId] or nil
    end
    partySize = tonumber(partySize)
    if not partySize or partySize ~= math.floor(partySize)
        or partySize < 1 or partySize > 4 then
        return nil
    end
    local bySize = self.saved.highScoresByParty and self.saved.highScoresByParty[zoneId]
    if type(bySize) == "table" then
        local best = bySize[partySize] or bySize[tostring(partySize)]
        if best then
            return best
        end
    end
    -- Preserved overall PBs predate division indexing. Only reuse one when
    -- it actually belongs to the requested party size.
    local overall = self.saved.highScores and self.saved.highScores[zoneId]
    return overall and tonumber(overall.runGroupSize) == partySize and overall or nil
end

function History:IsBaseGameZone(zoneId)
    return Data.BASE_GAME_ZONE_IDS and Data.BASE_GAME_ZONE_IDS[tonumber(zoneId)] == true
end

function History:GetHighScoreRows(tabKey)
    local rows = {}
    for zoneId in pairs(Data.ZONES or {}) do
        local isBaseGame = self:IsBaseGameZone(zoneId)
        if (tabKey == TAB_BASEGAME and isBaseGame) or (tabKey == TAB_DLC and not isBaseGame) then
            local zoneName = GetZoneDisplayName(zoneId)
            for partySize = 1, 4 do
                rows[#rows + 1] = {
                    zoneId = tonumber(zoneId),
                    partySize = partySize,
                    zoneBaseName = zoneName,
                    zoneName = string.format("%s (%s)", zoneName, PARTY_SIZE_NAMES[partySize]),
                    settlement = self:GetHighScore(zoneId, partySize),
                }
            end
        end
    end

    table.sort(rows, function(a, b)
        local left = string.lower(a.zoneBaseName or "")
        local right = string.lower(b.zoneBaseName or "")
        if left == right then
            if a.zoneId == b.zoneId then
                return a.partySize < b.partySize
            end
            return (a.zoneId or 0) < (b.zoneId or 0)
        end
        return left < right
    end)
    return rows
end

function History:CreateTabControl(parent, definition, previous)
    local tab = WM:CreateControl(nil, parent, CT_CONTROL)
    tab:SetDimensions(definition.width, 32)
    if previous then
        tab:SetAnchor(LEFT, previous, RIGHT, 6, 0)
    else
        tab:SetAnchor(TOPLEFT, parent, TOPLEFT, 18, 48)
    end
    tab:SetMouseEnabled(true)

    local backdrop = WM:CreateControl(nil, tab, CT_BACKDROP)
    backdrop:SetAnchorFill(tab)
    backdrop:SetCenterColor(0.07, 0.07, 0.07, 0.9)
    backdrop:SetEdgeColor(0.25, 0.25, 0.25, 0.9)

    local label = WM:CreateControl(nil, tab, CT_LABEL)
    label:SetAnchorFill(tab)
    label:SetFont("ZoFontGameBold")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetText(GetString(definition.stringId))
    tab:SetWidth(math.max(definition.width, zo_ceil(label:GetTextWidth()) + 24))

    tab:SetHandler("OnMouseUp", function(_, button, upInside)
        if button == MOUSE_BUTTON_INDEX_LEFT and upInside then
            self:SetTab(definition.key)
        end
    end)
    tab:SetHandler("OnMouseEnter", function()
        if self.activeTab ~= definition.key then
            backdrop:SetCenterColor(0.13, 0.13, 0.13, 0.95)
        end
    end)
    tab:SetHandler("OnMouseExit", function()
        if self.activeTab ~= definition.key then
            backdrop:SetCenterColor(0.07, 0.07, 0.07, 0.9)
        end
    end)

    self.tabControls[definition.key] = {
        control = tab,
        backdrop = backdrop,
        label = label,
        baseWidth = definition.width,
    }
    return tab
end

function History:CreateWindow()
    if self.window then
        return
    end

    self.saved.historyWindow = self.saved.historyWindow or {}

    local window = WM:CreateTopLevelWindow("DungeonScoresHistoryWindow")
    local maxWidth = math.max(WINDOW_MIN_WIDTH, math.min(WINDOW_MAX_WIDTH, (GuiRoot:GetWidth() or WINDOW_MAX_WIDTH) - 24))
    local maxHeight = math.max(WINDOW_MIN_HEIGHT, math.min(WINDOW_MAX_HEIGHT, (GuiRoot:GetHeight() or WINDOW_MAX_HEIGHT) - 24))
    local savedWidth = Clamp(self.saved.historyWindow.width or WINDOW_DEFAULT_WIDTH, WINDOW_MIN_WIDTH, maxWidth)
    local savedHeight = Clamp(self.saved.historyWindow.height or WINDOW_DEFAULT_HEIGHT, WINDOW_MIN_HEIGHT, maxHeight)
    window:SetDimensionConstraints(WINDOW_MIN_WIDTH, WINDOW_MIN_HEIGHT, maxWidth, maxHeight)
    window:SetDimensions(savedWidth, savedHeight)
    window:SetResizeHandleSize(18)
    window:SetClampedToScreen(true)
    window:SetMouseEnabled(true)
    window:SetMovable(true)
    -- Keep the browser in the standard addon-control stack. ESO's shared
    -- context-menu window uses a higher stack and must remain visible and
    -- clickable when a team or guild selector is open.
    window:SetDrawLayer(DL_CONTROLS)
    window:SetDrawTier(DT_LOW)
    window:SetDrawLevel(0)
    window:SetHidden(true)

    if self.saved.historyWindow.left and self.saved.historyWindow.top then
        window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self.saved.historyWindow.left, self.saved.historyWindow.top)
    else
        window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end

    local backdrop = WM:CreateControl(nil, window, CT_BACKDROP)
    backdrop:SetAnchorFill(window)
    backdrop:SetCenterColor(0.03, 0.03, 0.03, 0.94)
    backdrop:SetEdgeColor(0.35, 0.35, 0.35, 1)

    local title = WM:CreateControl(nil, window, CT_LABEL)
    title:SetAnchor(TOPLEFT, window, TOPLEFT, 18, 12)
    title:SetFont("ZoFontWinH2")
    title:SetText(GetString(SI_DUNGEON_SCORES_ADDON_NAME))

    local countLabel = WM:CreateControl(nil, window, CT_LABEL)
    countLabel:SetAnchor(LEFT, title, RIGHT, 16, 2)
    countLabel:SetFont("ZoFontGameSmall")
    countLabel:SetColor(0.7, 0.7, 0.7, 1)

    local closeButton = WM:CreateControl(nil, window, CT_BUTTON)
    closeButton:SetDimensions(40, 28)
    closeButton:SetAnchor(TOPRIGHT, window, TOPRIGHT, -10, 8)
    closeButton:SetFont("ZoFontWinH3")
    closeButton:SetText(GetString(SI_DUNGEON_SCORES_CLOSE))
    closeButton:SetHandler("OnClicked", function()
        self:Hide()
    end)

    self.tabControls = {}
    local previousTab = nil
    for _, definition in ipairs(TAB_DEFINITIONS) do
        previousTab = self:CreateTabControl(window, definition, previousTab)
    end

    local divider = WM:CreateControl(nil, window, CT_TEXTURE)
    divider:SetDimensions(1, 640)
    divider:SetAnchor(TOPLEFT, window, TOPLEFT, 405, 100)
    divider:SetColor(0.35, 0.35, 0.35, 0.8)

    local listHeader = WM:CreateControl(nil, window, CT_LABEL)
    listHeader:SetAnchor(TOPLEFT, window, TOPLEFT, 18, 94)
    listHeader:SetFont("ZoFontGameBold")

    self.rows = {}
    local previous = listHeader
    for i = 1, PAGE_SIZE do
        local row = WM:CreateControl(nil, window, CT_CONTROL)
        row:SetDimensions(370, 34)
        if i == 1 then
            row:SetAnchor(TOPLEFT, listHeader, BOTTOMLEFT, 0, 8)
        else
            row:SetAnchor(TOPLEFT, previous, BOTTOMLEFT, 0, 3)
        end
        row:SetMouseEnabled(true)

        local rowBackdrop = WM:CreateControl(nil, row, CT_BACKDROP)
        rowBackdrop:SetAnchorFill(row)
        rowBackdrop:SetCenterColor(0.08, 0.08, 0.08, 0.5)
        rowBackdrop:SetEdgeColor(0.18, 0.18, 0.18, 0.7)

        local rowLabel = WM:CreateControl(nil, row, CT_LABEL)
        rowLabel:SetAnchor(TOPLEFT, row, TOPLEFT, 8, 4)
        rowLabel:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, -8, -4)
        rowLabel:SetFont("ZoFontGameSmall")
        rowLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        rowLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

        row:SetHandler("OnMouseUp", function(_, button, upInside)
            if button == MOUSE_BUTTON_INDEX_LEFT and upInside and row.selectionKey ~= nil then
                self.pendingDeleteIndex = nil
                if self.activeTab == TAB_HISTORY then
                    self.selectedIndex = row.selectionKey
                elseif self.activeTab == TAB_BETA then
                    self.selectedBetaIndex = row.selectionKey
                elseif self.activeTab == TAB_TEAMS then
                    self.selectedTeamIndex = row.selectionKey
                    self.teamEditorNew = false
                elseif self.activeTab == TAB_GUILDS then
                    self.selectedGuildDirectoryIndex = row.selectionKey
                else
                    self.selectedZoneId = row.selectionKey
                end
                self:Refresh()
            end
        end)

        row:SetHandler("OnMouseEnter", function()
            if row.selectionKey ~= nil and not row.isSelected then
                rowBackdrop:SetCenterColor(0.14, 0.14, 0.14, 0.7)
                rowLabel:SetColor(1, 1, 1, 1)
            end
        end)
        row:SetHandler("OnMouseExit", function()
            if row.selectionKey ~= nil and not row.isSelected then
                rowBackdrop:SetCenterColor(0.08, 0.08, 0.08, 0.5)
                rowLabel:SetColor(HISTORY_IDLE_COLOR[1], HISTORY_IDLE_COLOR[2], HISTORY_IDLE_COLOR[3], HISTORY_IDLE_COLOR[4])
            end
        end)

        self.rows[i] = {
            control = row,
            backdrop = rowBackdrop,
            label = rowLabel,
        }
        previous = row
    end

    local highScoreList = WM:CreateControlFromVirtual("DungeonScoresHighScoreList", window, "ZO_ScrollList")
    highScoreList:SetDimensions(370, 600)
    highScoreList:SetAnchor(TOPLEFT, listHeader, BOTTOMLEFT, 0, 8)
    highScoreList:SetHidden(true)

    local function HighScoreRowOnMouseDown(control, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then
            return
        end
        local data = ZO_ScrollList_GetData(control)
        if data then
            ZO_ScrollList_SelectData(highScoreList, data, control)
        end
    end

    local function HighScoreRowSetup(control, data, list)
        control:SetHandler("OnMouseDown", HighScoreRowOnMouseDown)
        control:SetHeight(34)
        control:SetFont(MediumFont(self:GetListFontSize()))
        control:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        control:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        control:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        control:SetText(self:FormatHighScoreRow(data))
        ZO_SelectableLabel_SetNormalColor(control, data.settlement and HIGH_SCORE_IDLE_SCORED or HIGH_SCORE_IDLE_EMPTY)
        control:SetSelected(ZO_ScrollList_IsDataSelected(list, data))
    end

    local function HighScoreRowSelected(_, selectedData, reselectingDuringRebuild)
        if reselectingDuringRebuild or not selectedData then
            return
        end
        self.selectedZoneId = selectedData.zoneId
        self.selectedPartySize = selectedData.partySize
        self.pendingDeleteIndex = nil
        if selectedData.settlement then
            self:ShowSettlementDetails(selectedData.settlement, true)
        else
            self:ClearDetails(FormatString(
                SI_DUNGEON_SCORES_NO_PRESERVED_HIGH_SCORE,
                selectedData.zoneName))
        end
    end

    ZO_ScrollList_AddDataType(highScoreList, HIGH_SCORE_DATA_TYPE, "ZO_SelectableLabel", 34, HighScoreRowSetup)
    ZO_ScrollList_EnableHighlight(highScoreList, "ZO_ThinListHighlight")
    ZO_ScrollList_EnableSelection(highScoreList, "ZO_ThinListHighlight", HighScoreRowSelected)

    local previousButton = WM:CreateControl(nil, window, CT_BUTTON)
    previousButton:SetDimensions(90, 28)
    previousButton:SetAnchor(BOTTOMLEFT, window, BOTTOMLEFT, 18, -14)
    previousButton:SetFont("ZoFontGameSmall")
    previousButton:SetText(GetString(SI_DUNGEON_SCORES_PREVIOUS))
    previousButton:SetHandler("OnClicked", function()
        if self.page > 1 then
            self.page = self.page - 1
            self.pendingDeleteIndex = nil
            if self.activeTab == TAB_HISTORY then
                self.selectedIndex = nil
            elseif self.activeTab == TAB_BETA then
                self.selectedBetaIndex = nil
            elseif self.activeTab == TAB_TEAMS then
                self.selectedTeamIndex = nil
                self.teamEditorNew = false
            elseif self.activeTab == TAB_GUILDS then
                self.selectedGuildDirectoryIndex = nil
            else
                self.selectedZoneId = nil
            end
            self:Refresh()
        end
    end)

    local pageLabel = WM:CreateControl(nil, window, CT_LABEL)
    pageLabel:SetDimensions(120, 28)
    pageLabel:SetAnchor(LEFT, previousButton, RIGHT, 10, 0)
    pageLabel:SetFont("ZoFontGameSmall")
    pageLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    pageLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    local nextButton = WM:CreateControl(nil, window, CT_BUTTON)
    nextButton:SetDimensions(90, 28)
    nextButton:SetAnchor(LEFT, pageLabel, RIGHT, 10, 0)
    nextButton:SetFont("ZoFontGameSmall")
    nextButton:SetText(GetString(SI_DUNGEON_SCORES_NEXT))
    nextButton:SetHandler("OnClicked", function()
        local total = self:GetActiveRowCount()
        local totalPages = math.max(1, math.ceil(total / PAGE_SIZE))
        if self.page < totalPages then
            self.page = self.page + 1
            self.pendingDeleteIndex = nil
            if self.activeTab == TAB_HISTORY then
                self.selectedIndex = nil
            elseif self.activeTab == TAB_BETA then
                self.selectedBetaIndex = nil
            elseif self.activeTab == TAB_TEAMS then
                self.selectedTeamIndex = nil
                self.teamEditorNew = false
            elseif self.activeTab == TAB_GUILDS then
                self.selectedGuildDirectoryIndex = nil
            else
                self.selectedZoneId = nil
            end
            self:Refresh()
        end
    end)

    local detailHeader = WM:CreateControl(nil, window, CT_LABEL)
    detailHeader:SetAnchor(TOPLEFT, divider, TOPRIGHT, 18, -8)
    detailHeader:SetFont("ZoFontGameBold")

    local detailScroll = WM:CreateControlFromVirtual("DungeonScoresHistoryDetailScroll", window, "ZO_ScrollContainer")
    detailScroll:SetAnchor(TOPLEFT, detailHeader, BOTTOMLEFT, 0, 8)
    detailScroll:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -18, -122)
    local detailScrollChild = detailScroll:GetNamedChild("ScrollChild")

    local detailLabel = WM:CreateControl(nil, detailScrollChild, CT_LABEL)
    detailLabel:SetAnchor(TOPLEFT, detailScrollChild, TOPLEFT, 0, 0)
    detailLabel:SetFont("ZoFontGame")
    ConfigureWrappingLabel(detailLabel)
    detailLabel:SetMouseEnabled(true)
    detailLabel:SetLinkEnabled(true)
    detailLabel:SetHandler("OnLinkClicked", function(_, _, linkText, button)
        ZO_LinkHandler_OnLinkClicked(linkText, button)
    end)

    local componentHeader = WM:CreateControl(nil, detailScrollChild, CT_LABEL)
    componentHeader:SetFont("ZoFontGame")
    componentHeader:SetColor(0.8, 0.8, 0.8, 1)
    componentHeader:SetText(GetString(SI_DUNGEON_SCORES_SCORE_COMPONENTS))
    ConfigureWrappingLabel(componentHeader)

    local componentLabels = {}
    for i = 1, 13 do
        local label = WM:CreateControl(nil, detailScrollChild, CT_LABEL)
        label:SetFont("ZoFontGame")
        ConfigureWrappingLabel(label)
        componentLabels[i] = label
    end

    local groupHeader = WM:CreateControl(nil, detailScrollChild, CT_LABEL)
    groupHeader:SetFont("ZoFontGame")
    groupHeader:SetColor(0.8, 0.8, 0.8, 1)
    groupHeader:SetText(GetString(SI_DUNGEON_SCORES_GROUP_MEMBERS))
    ConfigureWrappingLabel(groupHeader)

    local groupLabels = {}
    for i = 1, 6 do
        local label = WM:CreateControl(nil, detailScrollChild, CT_LABEL)
        label:SetFont("ZoFontGameSmall")
        ConfigureWrappingLabel(label)
        groupLabels[i] = label
    end

    local completionBossLabel = WM:CreateControl(nil, detailScrollChild, CT_LABEL)
    completionBossLabel:SetFont("ZoFontGame")
    ConfigureWrappingLabel(completionBossLabel)

    local completionReasonLabel = WM:CreateControl(nil, detailScrollChild, CT_LABEL)
    completionReasonLabel:SetFont("ZoFontGame")
    ConfigureWrappingLabel(completionReasonLabel)

    local recordedByLabel = WM:CreateControl(nil, detailScrollChild, CT_LABEL)
    recordedByLabel:SetFont("ZoFontGame")
    ConfigureWrappingLabel(recordedByLabel)

    local teamEditor = WM:CreateControl(nil, window, CT_CONTROL)
    teamEditor:SetHidden(true)

    local teamHelp = WM:CreateControl(nil, teamEditor, CT_LABEL)
    teamHelp:SetFont("ZoFontGame")
    teamHelp:SetText(GetString(SI_DUNGEON_SCORES_TEAMS_HELP))
    ConfigureWrappingLabel(teamHelp)

    local teamNameLabel = WM:CreateControl(nil, teamEditor, CT_LABEL)
    teamNameLabel:SetFont("ZoFontGameBold")
    teamNameLabel:SetText(GetString(SI_DUNGEON_SCORES_TEAM_NAME))

    local teamNameBackdrop = WM:CreateControlFromVirtual(
        "DungeonScoresTeamNameEditBackdrop", teamEditor, "ZO_EditBackdrop")
    local teamNameEdit = WM:CreateControlFromVirtual(
        "DungeonScoresTeamNameEdit", teamNameBackdrop, "ZO_DefaultEditForBackdrop")
    teamNameEdit:SetMaxInputChars(80)
    teamNameEdit:SetMouseEnabled(true)
    teamNameEdit:SetEditEnabled(true)
    teamNameEdit:SetHandler("OnEscape", function(control)
        control:LoseFocus()
    end)

    local teamMembersLabel = WM:CreateControl(nil, teamEditor, CT_LABEL)
    teamMembersLabel:SetFont("ZoFontGameBold")
    teamMembersLabel:SetText(GetString(SI_DUNGEON_SCORES_TEAM_MEMBERS))

    local teamMembersBackdrop = WM:CreateControlFromVirtual(
        "DungeonScoresTeamMembersEditBackdrop", teamEditor, "ZO_EditBackdrop")
    local teamMembersEdit = WM:CreateControlFromVirtual(
        "DungeonScoresTeamMembersEdit", teamMembersBackdrop, "ZO_DefaultEditForBackdrop")
    teamMembersEdit:SetMaxInputChars(280)
    teamMembersEdit:SetMouseEnabled(true)
    teamMembersEdit:SetEditEnabled(true)
    teamMembersEdit:SetHandler("OnEscape", function(control)
        control:LoseFocus()
    end)

    local teamSaveButton = WM:CreateControlFromVirtual(nil, teamEditor, "ZO_DefaultButton")
    teamSaveButton:SetDimensions(150, 30)
    teamSaveButton:SetFont("ZoFontGameSmall")
    teamSaveButton:SetText(GetString(SI_DUNGEON_SCORES_TEAM_SAVE))
    teamSaveButton:SetEnabled(true)
    teamSaveButton:SetHandler("OnClicked", function()
        self:SaveTeamEditor()
    end)

    local teamNewButton = WM:CreateControlFromVirtual(nil, teamEditor, "ZO_DefaultButton")
    teamNewButton:SetDimensions(120, 30)
    teamNewButton:SetFont("ZoFontGameSmall")
    teamNewButton:SetText(GetString(SI_DUNGEON_SCORES_TEAM_NEW))
    teamNewButton:SetEnabled(true)
    teamNewButton:SetHandler("OnClicked", function()
        self:BeginNewTeam()
    end)

    local teamDeleteButton = WM:CreateControlFromVirtual(nil, teamEditor, "ZO_DefaultButton")
    teamDeleteButton:SetDimensions(150, 30)
    teamDeleteButton:SetFont("ZoFontGameSmall")
    teamDeleteButton:SetText(GetString(SI_DUNGEON_SCORES_TEAM_DELETE))
    teamDeleteButton:SetHandler("OnClicked", function()
        self:DeleteSelectedTeam()
    end)

    local deleteButton = WM:CreateControl(nil, window, CT_BUTTON)
    deleteButton:SetDimensions(150, 30)
    deleteButton:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -18, -16)
    deleteButton:SetFont("ZoFontGameSmall")
    deleteButton:SetText(GetString(SI_DUNGEON_SCORES_DELETE_SELECTED))
    deleteButton:SetHandler("OnClicked", function()
        self:RequestDeleteSelected()
    end)

    local publishButton = WM:CreateControlFromVirtual(nil, window, "ZO_DefaultButton")
    publishButton:SetDimensions(190, 30)
    publishButton:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -18, -50)
    publishButton:SetFont("ZoFontGameSmall")
    publishButton:SetText(GetString(SI_DUNGEON_SCORES_SEND_SELECTED_SCORE))
    publishButton:SetHandler("OnClicked", function()
        self:QueueSelectedScore()
    end)
    publishButton:SetHandler("OnMouseEnter", function(control)
        InitializeTooltip(InformationTooltip, control, TOPRIGHT, 0, -4, BOTTOMRIGHT)
        SetTooltipText(InformationTooltip, GetString(SI_DUNGEON_SCORES_SEND_SCORE_TOOLTIP))
    end)
    publishButton:SetHandler("OnMouseExit", function()
        ClearTooltip(InformationTooltip)
    end)

    local assignTeamButton = WM:CreateControlFromVirtual(nil, window, "ZO_DefaultButton")
    assignTeamButton:SetDimensions(150, 30)
    assignTeamButton:SetAnchor(BOTTOMRIGHT, publishButton, BOTTOMLEFT, -10, 0)
    assignTeamButton:SetFont("ZoFontGameSmall")
    assignTeamButton:SetText(GetString(SI_DUNGEON_SCORES_ASSIGN_TEAM))
    assignTeamButton:SetHandler("OnClicked", function()
        self:ShowTeamAssignmentMenu()
    end)

    local raceButton = WM:CreateControlFromVirtual(nil, window, "ZO_DefaultButton")
    raceButton:SetDimensions(190, 30)
    raceButton:SetAnchor(BOTTOMRIGHT, assignTeamButton, BOTTOMLEFT, -10, 0)
    raceButton:SetFont("ZoFontGameSmall")
    raceButton:SetText(GetString(SI_DUNGEON_SCORES_RACE_TO_BOTTOM_OFF))
    raceButton:SetHandler("OnClicked", function()
        local settlement = self.selectedSettlement
        if settlement and DS:SetPublicationRaceToBottomRequested(
            settlement, settlement.publicationRaceToBottomRequested ~= true) then
            self:Refresh()
        end
    end)
    raceButton:SetHandler("OnMouseEnter", function(control)
        InitializeTooltip(InformationTooltip, control, TOPRIGHT, 0, -4, BOTTOMRIGHT)
        SetTooltipText(InformationTooltip, GetString(SI_DUNGEON_SCORES_RACE_TO_BOTTOM_TOOLTIP))
    end)
    raceButton:SetHandler("OnMouseExit", function()
        ClearTooltip(InformationTooltip)
    end)

    local assignGuildButton = WM:CreateControlFromVirtual(nil, window, "ZO_DefaultButton")
    assignGuildButton:SetDimensions(190, 30)
    assignGuildButton:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -18, -84)
    assignGuildButton:SetFont("ZoFontGameSmall")
    assignGuildButton:SetText(GetString(SI_DUNGEON_SCORES_ASSIGN_GUILD))
    assignGuildButton:SetHandler("OnClicked", function()
        self:ShowGuildAssignmentMenu()
    end)

    local assignEventButton = WM:CreateControlFromVirtual(nil, window, "ZO_DefaultButton")
    assignEventButton:SetDimensions(190, 30)
    assignEventButton:SetAnchor(BOTTOMRIGHT, assignGuildButton, BOTTOMLEFT, -10, 0)
    assignEventButton:SetFont("ZoFontGameSmall")
    assignEventButton:SetText(GetString(SI_DUNGEON_SCORES_SELECT_EVENT))
    assignEventButton:SetHandler("OnClicked", function()
        self:ShowEventAssignmentMenu()
    end)

    window:SetHandler("OnMoveStop", function(control)
        self.saved.historyWindow.left = control:GetLeft()
        self.saved.historyWindow.top = control:GetTop()
    end)
    window:SetHandler("OnResizeStop", function(control)
        self.saved.historyWindow.width = zo_round(control:GetWidth())
        self.saved.historyWindow.height = zo_round(control:GetHeight())
        self:ApplyLayout(true)
    end)

    self.window = window
    self.highScoreList = highScoreList
    self.backdrop = backdrop
    self.title = title
    self.closeButton = closeButton
    self.divider = divider
    self.countLabel = countLabel
    self.listHeader = listHeader
    self.pageLabel = pageLabel
    self.previousButton = previousButton
    self.nextButton = nextButton
    self.detailHeader = detailHeader
    self.detailScroll = detailScroll
    self.detailScrollChild = detailScrollChild
    self.detailLabel = detailLabel
    self.componentHeader = componentHeader
    self.componentLabels = componentLabels
    self.groupHeader = groupHeader
    self.groupLabels = groupLabels
    self.completionBossLabel = completionBossLabel
    self.completionReasonLabel = completionReasonLabel
    self.recordedByLabel = recordedByLabel
    self.teamEditor = teamEditor
    self.teamHelp = teamHelp
    self.teamNameLabel = teamNameLabel
    self.teamNameBackdrop = teamNameBackdrop
    self.teamNameEdit = teamNameEdit
    self.teamMembersLabel = teamMembersLabel
    self.teamMembersBackdrop = teamMembersBackdrop
    self.teamMembersEdit = teamMembersEdit
    self.teamSaveButton = teamSaveButton
    self.teamNewButton = teamNewButton
    self.teamDeleteButton = teamDeleteButton
    self.deleteButton = deleteButton
    self.publishButton = publishButton
    self.raceButton = raceButton
    self.assignTeamButton = assignTeamButton
    self.assignGuildButton = assignGuildButton
    self.assignEventButton = assignEventButton
    self:ApplyFonts()
    self:ApplyLayout(true)
end

function History:GetTitleFontSize()
    return Clamp(self.saved and self.saved.settings and self.saved.settings.browserTitleFontSize or 24, 18, 34)
end

function History:GetHeaderFontSize()
    return Clamp(self.saved and self.saved.settings and self.saved.settings.browserHeaderFontSize or 18, 14, 22)
end

function History:GetListFontSize()
    return Clamp(self.saved and self.saved.settings and self.saved.settings.browserListFontSize or 16, 12, 22)
end

function History:GetDetailFontSize()
    return Clamp(self.saved and self.saved.settings and self.saved.settings.browserDetailFontSize or 16, 12, 20)
end

function History:ApplyFonts()
    if not self.window then
        return
    end
    local titleSize = self:GetTitleFontSize()
    local headerSize = self:GetHeaderFontSize()
    local listSize = self:GetListFontSize()
    local detailSize = self:GetDetailFontSize()

    self.title:SetFont(BoldFont(titleSize))
    self.countLabel:SetFont(MediumFont(math.max(12, listSize - 2)))
    self.closeButton:SetFont(BoldFont(math.max(18, headerSize + 2)))
    self.listHeader:SetFont(BoldFont(headerSize))
    self.detailHeader:SetFont(BoldFont(headerSize))
    self.pageLabel:SetFont(MediumFont(listSize))
    self.previousButton:SetFont(MediumFont(listSize))
    self.nextButton:SetFont(MediumFont(listSize))
    self.deleteButton:SetFont(MediumFont(listSize))
    self.publishButton:SetFont(MediumFont(listSize))
    self.raceButton:SetFont(MediumFont(math.min(listSize, 16)))
    self.assignTeamButton:SetFont(MediumFont(listSize))
    self.assignGuildButton:SetFont(MediumFont(listSize))
    self.assignEventButton:SetFont(MediumFont(listSize))
    self.teamHelp:SetFont(MediumFont(detailSize))
    self.teamNameLabel:SetFont(BoldFont(math.max(13, detailSize)))
    self.teamNameEdit:SetFont(MediumFont(detailSize))
    self.teamMembersLabel:SetFont(BoldFont(math.max(13, detailSize)))
    self.teamMembersEdit:SetFont(MediumFont(detailSize))
    self.teamSaveButton:SetFont(MediumFont(listSize))
    self.teamNewButton:SetFont(MediumFont(listSize))
    self.teamDeleteButton:SetFont(MediumFont(listSize))

    for _, tab in pairs(self.tabControls or {}) do
        tab.label:SetFont(BoldFont(math.max(13, headerSize - 1)))
    end
    for _, row in ipairs(self.rows or {}) do
        row.label:SetFont(MediumFont(listSize))
    end

    self.detailLabel:SetFont(MediumFont(detailSize))
    self.componentHeader:SetFont(BoldFont(math.max(13, detailSize)))
    self.groupHeader:SetFont(BoldFont(math.max(13, detailSize)))
    for _, label in ipairs(self.componentLabels or {}) do
        label:SetFont(MediumFont(detailSize))
    end
    for _, label in ipairs(self.groupLabels or {}) do
        label:SetFont(MediumFont(detailSize))
    end
    self.completionBossLabel:SetFont(MediumFont(detailSize))
    self.completionReasonLabel:SetFont(MediumFont(detailSize))
    self.recordedByLabel:SetFont(MediumFont(detailSize))

    if self.highScoreList then
        ZO_ScrollList_RefreshVisible(self.highScoreList)
    end
end

function History:ReflowWrappingLabel(label, width, minimumHeight)
    if not label then
        return minimumHeight or 0
    end

    width = math.max(1, tonumber(width) or 1)
    minimumHeight = math.max(0, tonumber(minimumHeight) or 0)
    label:SetWidth(width)
    -- Give the label ample vertical room while measuring so GetTextHeight()
    -- reports every wrapped line instead of the currently visible subset.
    label:SetHeight(math.max(4096, minimumHeight))

    -- Re-applying text after a width/font change forces ESO to rebuild the
    -- wrapped layout before GetTextHeight() is queried.
    local text = label:GetText() or ""
    label:SetText("")
    label:SetText(text)

    local textHeight = label:GetTextHeight() or 0
    local finalHeight = math.max(minimumHeight, math.ceil(textHeight + 2))
    label:SetHeight(math.max(1, finalHeight))
    return math.max(1, finalHeight)
end

function History:ResetDetailScroll()
    if self.detailScroll and self.detailScroll.SetVerticalScroll then
        self.detailScroll:SetVerticalScroll(0)
    end
end

function History:ApplyTabLayout(width)
    local tabX, tabY = 18, 48
    local rightEdge = width - 18
    for _, definition in ipairs(TAB_DEFINITIONS) do
        local tab = self.tabControls[definition.key]
        local tabWidth = math.min(rightEdge - 18,
            math.max(tab.baseWidth, zo_ceil(tab.label:GetTextWidth()) + 24))
        if tabX > 18 and tabX + tabWidth > rightEdge then
            tabX, tabY = 18, tabY + 38
        end
        tab.control:ClearAnchors()
        tab.control:SetAnchor(TOPLEFT, self.window, TOPLEFT, tabX, tabY)
        tab.control:SetWidth(tabWidth)
        tabX = tabX + tabWidth + 6
    end
    return tabY + 46
end

function History:ApplyFooterLayout(listWidth, rightWidth)
    -- Keep publication routes inside the details column at the minimum
    -- browser width, and place the RTB toggle inside the run-list column.
    local routeWidth = math.min(190, math.floor((rightWidth - 10) / 2))
    self.assignEventButton:SetWidth(routeWidth)
    self.assignGuildButton:SetWidth(routeWidth)
    self.raceButton:ClearAnchors()
    self.raceButton:SetAnchor(BOTTOMLEFT, self.window, BOTTOMLEFT,
        18 + math.floor((listWidth - 190) / 2), -50)
end

function History:ApplyLayout(recommitScrollList)
    if not self.window then
        return
    end
    local width = self.window:GetWidth()
    local height = self.window:GetHeight()
    if not width or not height or width <= 0 or height <= 0 then
        return
    end

    local headerY = self:ApplyTabLayout(width)

    local dividerX = Clamp(math.floor(width * 0.45), 350, width - 330)
    local listWidth = math.max(300, dividerX - 35)
    local rightX = dividerX + 18
    local rightWidth = math.max(285, width - rightX - 18)
    local scrollHeight = math.max(300, height - headerY - 66)
    local detailFont = self:GetDetailFontSize()
    local detailLineHeight = math.max(20, detailFont + 6)
    local sectionGap = 12
    local contentWidth = math.max(250, rightWidth - 22)

    self:ApplyFooterLayout(listWidth, rightWidth)

    self.divider:ClearAnchors()
    self.divider:SetAnchor(TOPLEFT, self.window, TOPLEFT, dividerX, headerY + 6)
    self.divider:SetAnchor(BOTTOMLEFT, self.window, BOTTOMLEFT, dividerX, -44)
    self.divider:SetWidth(1)

    self.listHeader:ClearAnchors()
    self.listHeader:SetAnchor(TOPLEFT, self.window, TOPLEFT, 18, headerY)
    self.listHeader:SetWidth(listWidth)
    for _, row in ipairs(self.rows or {}) do
        row.control:SetWidth(listWidth)
    end
    self.highScoreList:SetWidth(listWidth)
    self.highScoreList:SetHeight(scrollHeight)

    self.detailHeader:ClearAnchors()
    self.detailHeader:SetAnchor(TOPLEFT, self.window, TOPLEFT, rightX, headerY - 2)
    self.detailHeader:SetWidth(rightWidth)

    self.detailScroll:ClearAnchors()
    self.detailScroll:SetAnchor(TOPLEFT, self.detailHeader, BOTTOMLEFT, 0, 8)
    self.detailScroll:SetAnchor(BOTTOMRIGHT, self.window, BOTTOMRIGHT, -18, -122)
    self.detailScrollChild:SetWidth(contentWidth)

    self.teamEditor:ClearAnchors()
    self.teamEditor:SetAnchor(TOPLEFT, self.detailHeader, BOTTOMLEFT, 0, 8)
    self.teamEditor:SetAnchor(BOTTOMRIGHT, self.window, BOTTOMRIGHT, -18, -50)
    self.teamHelp:ClearAnchors()
    self.teamHelp:SetAnchor(TOPLEFT, self.teamEditor, TOPLEFT, 0, 0)
    self:ReflowWrappingLabel(self.teamHelp, rightWidth, detailLineHeight * 3)
    self.teamNameLabel:ClearAnchors()
    self.teamNameLabel:SetAnchor(TOPLEFT, self.teamHelp, BOTTOMLEFT, 0, 20)
    self.teamNameBackdrop:ClearAnchors()
    self.teamNameBackdrop:SetAnchor(TOPLEFT, self.teamNameLabel, BOTTOMLEFT, 0, 6)
    self.teamNameBackdrop:SetDimensions(rightWidth, 32)
    self.teamMembersLabel:ClearAnchors()
    self.teamMembersLabel:SetAnchor(TOPLEFT, self.teamNameBackdrop, BOTTOMLEFT, 0, 18)
    self.teamMembersBackdrop:ClearAnchors()
    self.teamMembersBackdrop:SetAnchor(TOPLEFT, self.teamMembersLabel, BOTTOMLEFT, 0, 6)
    self.teamMembersBackdrop:SetDimensions(rightWidth, 32)
    self.teamSaveButton:ClearAnchors()
    self.teamSaveButton:SetAnchor(TOPLEFT, self.teamMembersBackdrop, BOTTOMLEFT, 0, 24)
    self.teamNewButton:ClearAnchors()
    self.teamNewButton:SetAnchor(LEFT, self.teamSaveButton, RIGHT, 10, 0)
    self.teamDeleteButton:ClearAnchors()
    self.teamDeleteButton:SetAnchor(LEFT, self.teamNewButton, RIGHT, 10, 0)

    local contentHeight = 0

    self.detailLabel:ClearAnchors()
    self.detailLabel:SetAnchor(TOPLEFT, self.detailScrollChild, TOPLEFT, 0, 0)
    local detailHeight = self:ReflowWrappingLabel(self.detailLabel, contentWidth, detailLineHeight)
    contentHeight = detailHeight

    self.componentHeader:ClearAnchors()
    self.componentHeader:SetAnchor(TOPLEFT, self.detailLabel, BOTTOMLEFT, 0, sectionGap)
    local componentHeaderHeight = self:ReflowWrappingLabel(self.componentHeader, contentWidth, detailLineHeight + 2)
    contentHeight = contentHeight + sectionGap + componentHeaderHeight

    local previous = self.componentHeader
    for _, label in ipairs(self.componentLabels or {}) do
        label:ClearAnchors()
        label:SetAnchor(TOPLEFT, previous, BOTTOMLEFT, 0, 0)
        local labelHeight = self:ReflowWrappingLabel(label, contentWidth, detailLineHeight)
        contentHeight = contentHeight + labelHeight
        previous = label
    end

    self.groupHeader:ClearAnchors()
    self.groupHeader:SetAnchor(TOPLEFT, previous, BOTTOMLEFT, 0, sectionGap)
    local groupHeaderHeight = self:ReflowWrappingLabel(self.groupHeader, contentWidth, detailLineHeight + 2)
    contentHeight = contentHeight + sectionGap + groupHeaderHeight
    previous = self.groupHeader

    for _, label in ipairs(self.groupLabels or {}) do
        label:ClearAnchors()
        -- IsHidden() includes the hidden state inherited from the browser
        -- window. The opening layout pass runs before that window is shown,
        -- so using it here used to classify populated roster rows as empty.
        -- A later resize happened while the window was visible and appeared
        -- to repair the layout. Row content is the stable source of truth.
        local rowText = label:GetText() or ""
        if rowText == "" then
            label:SetHeight(0)
        else
            label:SetAnchor(TOPLEFT, previous, BOTTOMLEFT, 0, 0)
            local labelHeight = self:ReflowWrappingLabel(label, contentWidth, detailLineHeight)
            contentHeight = contentHeight + labelHeight
            previous = label
        end
    end

    self.completionBossLabel:ClearAnchors()
    self.completionBossLabel:SetAnchor(TOPLEFT, previous, BOTTOMLEFT, 0, sectionGap)
    local completionBossHeight = self:ReflowWrappingLabel(self.completionBossLabel, contentWidth, detailLineHeight)
    contentHeight = contentHeight + sectionGap + completionBossHeight

    self.completionReasonLabel:ClearAnchors()
    self.completionReasonLabel:SetAnchor(TOPLEFT, self.completionBossLabel, BOTTOMLEFT, 0, 0)
    local completionReasonHeight = self:ReflowWrappingLabel(self.completionReasonLabel, contentWidth, detailLineHeight)
    contentHeight = contentHeight + completionReasonHeight

    self.recordedByLabel:ClearAnchors()
    self.recordedByLabel:SetAnchor(TOPLEFT, self.completionReasonLabel, BOTTOMLEFT, 0, 0)
    local recordedByHeight = self:ReflowWrappingLabel(self.recordedByLabel, contentWidth, detailLineHeight)
    contentHeight = contentHeight + recordedByHeight

    self.detailScrollChild:SetHeight(math.max(1, contentHeight + 10))

    if recommitScrollList and self.highScoreList and not self.highScoreList:IsHidden() then
        ZO_ScrollList_Commit(self.highScoreList)
    elseif self.highScoreList then
        ZO_ScrollList_RefreshVisible(self.highScoreList)
    end
end

function History:CheckWindowResize()
    if not self.window or self.window:IsHidden() then
        return
    end
    local width = zo_round(self.window:GetWidth())
    local height = zo_round(self.window:GetHeight())
    if width ~= self.lastObservedWidth or height ~= self.lastObservedHeight then
        self.lastObservedWidth = width
        self.lastObservedHeight = height
        self.saved.historyWindow.width = width
        self.saved.historyWindow.height = height
        self:ApplyLayout(true)
    end
end

function History:StartResizePolling()
    EM:UnregisterForUpdate(RESIZE_POLL_NAME)
    EM:RegisterForUpdate(RESIZE_POLL_NAME, 75, function()
        self:CheckWindowResize()
    end)
end

function History:StopResizePolling()
    EM:UnregisterForUpdate(RESIZE_POLL_NAME)
end

function History:ResetWindowSize()
    if not self.window then
        return
    end
    self.window:SetDimensions(WINDOW_DEFAULT_WIDTH, WINDOW_DEFAULT_HEIGHT)
    self.saved.historyWindow.width = WINDOW_DEFAULT_WIDTH
    self.saved.historyWindow.height = WINDOW_DEFAULT_HEIGHT
    self.lastObservedWidth = WINDOW_DEFAULT_WIDTH
    self.lastObservedHeight = WINDOW_DEFAULT_HEIGHT
    self:ApplyLayout(true)
end

function History:SetTab(tabKey)
    if not IsValidTab(tabKey) or tabKey == self.activeTab then
        return
    end
    self.activeTab = tabKey
    self.saved.historyWindow.activeTab = tabKey
    self.page = 1
    self.pendingDeleteIndex = nil
    if tabKey == TAB_HISTORY then
        self.selectedIndex = #self:GetHistory() > 0 and #self:GetHistory() or nil
    elseif tabKey == TAB_BETA then
        local snapshots = DS.Diagnostics and DS.Diagnostics:GetBetaRunSnapshots() or {}
        self.selectedBetaIndex = #snapshots > 0 and #snapshots or nil
    elseif tabKey == TAB_TEAMS then
        local teams = self:GetPublicationTeams()
        self.selectedTeamIndex = #teams > 0 and 1 or nil
        self.teamEditorNew = #teams == 0
    elseif tabKey == TAB_GUILDS then
        local guilds = type(DS.GetGuildDirectoryEntries) == "function"
            and DS:GetGuildDirectoryEntries() or {}
        self.selectedGuildDirectoryIndex = #guilds > 0 and 1 or nil
    else
        self.selectedZoneId = nil
        self.selectedPartySize = nil
    end
    self:Refresh()
end

function History:RefreshTabs()
    for key, tab in pairs(self.tabControls or {}) do
        local selected = key == self.activeTab
        if selected then
            tab.backdrop:SetCenterColor(0.18, 0.28, 0.36, 0.95)
            tab.backdrop:SetEdgeColor(0.45, 0.7, 0.9, 1)
            tab.label:SetColor(1, 1, 1, 1)
        else
            tab.backdrop:SetCenterColor(0.07, 0.07, 0.07, 0.9)
            tab.backdrop:SetEdgeColor(0.25, 0.25, 0.25, 0.9)
            tab.label:SetColor(0.78, 0.78, 0.78, 1)
        end
    end
end

local function DisplayedScore(settlement)
    if settlement and settlement.publicationRaceToBottomRequested == true
        and settlement.raceToBottomScore ~= nil then
        return settlement.raceToBottomScore
    end
    return settlement and settlement.finalScore or 0
end

function History:FormatRow(settlement)
    local zoneText = GetZoneDisplayName(settlement.zoneId)
    if settlement.runOutcome == "abandoned" then
        zoneText = zoneText .. " [" .. GetString(SI_DUNGEON_SCORES_RUN_ABANDONED) .. "]"
    end
    return FormatString(
        SI_DUNGEON_SCORES_HISTORY_ROW,
        DateText(settlement.finalizedAtTimeStamp or settlement.completedAtTimeStamp),
        zoneText,
        NumberText(DisplayedScore(settlement)),
        FormatDurationMs(settlement.elapsedMs))
end

function History:FormatHighScoreRow(entry)
    local settlement = entry and entry.settlement or nil
    if not settlement then
        return FormatString(
            SI_DUNGEON_SCORES_HIGH_SCORE_ROW_EMPTY,
            entry and entry.zoneName or GetString(SI_DUNGEON_SCORES_UNKNOWN_DUNGEON))
    end
    return FormatString(
        SI_DUNGEON_SCORES_HIGH_SCORE_ROW,
        entry.zoneName,
        NumberText(settlement.finalScore),
        FormatDurationMs(settlement.elapsedMs))
end

local function PaceText(settlement)
    if not settlement or not settlement.paceRatio then
        return GetString(SI_DUNGEON_SCORES_UNKNOWN_LOWER)
    end
    return FormatString(
        SI_DUNGEON_SCORES_PACE_CUTOFF,
        string.format("%.1f", settlement.paceRatio * 100))
end

local function CapturedWorldRecordText(settlement)
    local record = type(DS.GetCapturedWorldRecord) == "function"
        and DS:GetCapturedWorldRecord(
            settlement.zoneId, settlement.runGroupSize) or nil
    if not record then
        return GetString(SI_DUNGEON_SCORES_CAPTURED_WR_UNSUBMITTED)
    end
    local server = record.megaserver == "NA Megaserver" and "PC NA" or "PC EU"
    local scoreDelta = (tonumber(settlement.finalScore) or 0) - tonumber(record.finalScore)
    return FormatString(
        SI_DUNGEON_SCORES_CAPTURED_WR,
        NumberText(record.finalScore),
        FormatDurationMs(record.elapsedMs),
        tostring(record.teamName),
        tostring(math.floor(tonumber(record.runGroupSize))),
        server,
        string.format("%+d", scoreDelta))
end

local function RecordSnapshotAgeText()
    local snapshot = DS:GetRecordsSnapshot()
    local generatedAt = type(snapshot) == "table" and tonumber(snapshot.generatedAt) or nil
    if not generatedAt or generatedAt <= 0 then
        return GetString(SI_DUNGEON_SCORES_RECORD_SNAPSHOT_UNAVAILABLE)
    end
    local age = math.max(0, (tonumber(GetTimeStamp()) or generatedAt) - generatedAt)
    local ageText
    if age < 60 then
        ageText = GetString(SI_DUNGEON_SCORES_RECORD_SNAPSHOT_JUST_NOW)
    elseif age < 3600 then
        ageText = FormatString(SI_DUNGEON_SCORES_RECORD_SNAPSHOT_MINUTES,
            math.floor(age / 60))
    elseif age < 86400 then
        ageText = FormatString(SI_DUNGEON_SCORES_RECORD_SNAPSHOT_HOURS,
            math.floor(age / 3600))
    else
        ageText = FormatString(SI_DUNGEON_SCORES_RECORD_SNAPSHOT_DAYS,
            math.floor(age / 86400))
    end
    return FormatString(SI_DUNGEON_SCORES_RECORD_SNAPSHOT_AGE, ageText)
end

function History:FormatDetails(settlement, highScoreView)
    if not settlement then
        return GetString(SI_DUNGEON_SCORES_SELECT_RUN)
    end

    local thresholdText = settlement.speedThresholdMs
        and FormatDurationMs(settlement.speedThresholdMs)
        or GetString(SI_DUNGEON_SCORES_UNKNOWN_LOWER)
    local scoreLabel = settlement.scoreSessionOpen
        and GetString(SI_DUNGEON_SCORES_CURRENT_SCORE)
        or GetString(SI_DUNGEON_SCORES_FINAL_SCORE)
    local details = {
        string.format("|c88CCFF%s|r", GetZoneDisplayName(settlement.zoneId)),
        FormatString(
            SI_DUNGEON_SCORES_DETAIL_DATE,
            DateText(settlement.finalizedAtTimeStamp or settlement.completedAtTimeStamp),
            settlement.scoreSessionOpen
                and GetString(SI_DUNGEON_SCORES_OPEN_SCORE_SUFFIX) or ""),
        FormatString(SI_DUNGEON_SCORES_DETAIL_SCORE,
            settlement.publicationRaceToBottomRequested == true
                and settlement.raceToBottomScore ~= nil
                and GetString(SI_DUNGEON_SCORES_RACE_TO_BOTTOM_ON) or scoreLabel,
            NumberText(DisplayedScore(settlement))),
        FormatString(
            SI_DUNGEON_SCORES_DETAIL_TIME,
            FormatDurationMs(settlement.elapsedMs),
            thresholdText,
            SpeedText(settlement)),
    }

    if settlement.publicationTeamName
        and type(settlement.publicationTeamMembers) == "table"
        and #settlement.publicationTeamMembers > 0 then
        details[#details + 1] = FormatString(
            SI_DUNGEON_SCORES_DETAIL_TEAM,
            settlement.publicationTeamName,
            table.concat(settlement.publicationTeamMembers, ", "))
        if settlement.publicationGuildEventId then
            details[#details + 1] = FormatString(
                SI_DUNGEON_SCORES_DETAIL_GUILD_EVENT,
                tostring(settlement.publicationGuildName or ""),
                tostring(settlement.publicationGuildEventName
                    or settlement.publicationGuildEventId))
        elseif settlement.publicationGuildId
            and settlement.publicationGuildRecordsEnabled ~= false then
            details[#details + 1] = FormatString(
                SI_DUNGEON_SCORES_DETAIL_GUILD_RECORDS,
                tostring(settlement.publicationGuildName
                    or settlement.publicationGuildId))
        elseif settlement.publicationGuildId then
            details[#details + 1] = FormatString(
                SI_DUNGEON_SCORES_DETAIL_GUILD_SELECTED_NO_RECORDS,
                tostring(settlement.publicationGuildName
                    or settlement.publicationGuildId))
        else
            details[#details + 1] = GetString(
                SI_DUNGEON_SCORES_DETAIL_GUILD_EVENT_NONE)
        end
    end
    local publicationStatus = self:GetPublicationStatusText(settlement)
    if publicationStatus then
        details[#details + 1] = publicationStatus
    end

    if settlement.publicationRaceToBottomRequested == true then
        details[#details + 1] = GetString(SI_DUNGEON_SCORES_RACE_TO_BOTTOM_SELECTED)
    end
    if settlement.runOutcome == "abandoned" then
        details[#details + 1] = FormatString(
            SI_DUNGEON_SCORES_ABANDONED_STATUS,
            tonumber(settlement.bossKills) or 0,
            tonumber(settlement.minimumCredibleBossKills) or 1,
            YesNo(settlement.raceToBottomEligible == true))
    elseif settlement.competitiveEligible == false then
        details[#details + 1] = FormatString(
            SI_DUNGEON_SCORES_COMPETITIVE_INELIGIBLE,
            tostring(settlement.integrityReason
                or GetString(SI_DUNGEON_SCORES_PARTIAL_OBSERVATION)))
    elseif settlement.scoreSessionOpen then
        details[#details + 1] = FormatString(
            SI_DUNGEON_SCORES_SCORE_SESSION_OPEN,
            NumberText(settlement.scoreAtCompletion or settlement.finalScore),
            string.format("%+d", tonumber(settlement.postCompletionGain) or 0))
    end

    if settlement.runOutcome ~= "abandoned" then
        if not highScoreView then
            local highScore = self:GetHighScore(settlement.zoneId, settlement.runGroupSize)
            if highScore and highScore.finalScore ~= nil then
                local suffix = tonumber(highScore.finalScore) == tonumber(settlement.finalScore)
                    and GetString(SI_DUNGEON_SCORES_SELECTED_TIES_PB) or ""
                details[3] = details[3] .. FormatString(
                    SI_DUNGEON_SCORES_HIGH_SCORE_APPEND,
                    NumberText(highScore.finalScore),
                    suffix)
            end
        else
            details[3] = details[3] .. GetString(SI_DUNGEON_SCORES_PERSONAL_BEST_APPEND)
        end
    end

    if settlement.paceRatio ~= nil then
        details[#details + 1] = FormatString(
            SI_DUNGEON_SCORES_PACE_LINE, PaceText(settlement))
    end
    if settlement.runOutcome ~= "abandoned" then
        details[#details + 1] = CapturedWorldRecordText(settlement)
    end
    details[#details + 1] = RecordSnapshotAgeText()

    local trifectaSupported = IsTrifectaSupported(settlement)
    if trifectaSupported then
        details[#details + 1] = FormatString(
            SI_DUNGEON_SCORES_QUALIFICATION_LINE,
            YesNo(settlement.noDeathQualified),
            YesNo(settlement.trifectaQualified),
            settlement.deaths or 0,
            NumberText(settlement.vitalityScore))
        details[#details + 1] = (settlement.expectedHardModes
            and settlement.expectedHardModes > 0)
            and FormatString(
                SI_DUNGEON_SCORES_BOSS_KILLS_EXPECTED,
                settlement.bossKills or 0,
                settlement.hmBossKills or 0,
                settlement.expectedHardModes)
            or FormatString(
                SI_DUNGEON_SCORES_BOSS_KILLS,
                settlement.bossKills or 0,
                settlement.hmBossKills or 0)
    else
        details[#details + 1] = FormatString(
            SI_DUNGEON_SCORES_QUALIFICATION_LINE_NO_TRIFECTA,
            YesNo(settlement.noDeathQualified),
            settlement.deaths or 0,
            NumberText(settlement.vitalityScore))
        details[#details + 1] = FormatString(
            SI_DUNGEON_SCORES_BOSS_KILLS_ONLY,
            settlement.bossKills or 0)
    end
    if settlement.expectedBossEncountersAtCompletion then
        details[#details + 1] = FormatString(
            SI_DUNGEON_SCORES_BOSS_ENCOUNTERS,
            tonumber(settlement.bossEncountersAtCompletion) or 0,
            tonumber(settlement.expectedBossEncountersAtCompletion) or 0)
    end
    details[#details + 1] = FormatString(
        SI_DUNGEON_SCORES_KILL_COUNTS,
        settlement.xpKills or 0,
        settlement.noXpDeaths or 0,
        settlement.uniqueDeaths or 0)
    return table.concat(details, "\n")
end

function History:GetComponentRows(settlement)
    if not settlement then
        return {}
    end

    local rows = {
        FormatString(SI_DUNGEON_SCORES_COMPONENT_VETERAN, NumberText(settlement.veteranBase)),
        FormatString(SI_DUNGEON_SCORES_COMPONENT_KILL, NumberText(settlement.killScore)),
    }
    local showRacePenalties = settlement.publicationRaceToBottomRequested == true
    if settlement.runOutcome == "abandoned" then
        if (tonumber(settlement.hmScore) or 0) > 0 then
            rows[#rows + 1] = FormatString(
                SI_DUNGEON_SCORES_COMPONENT_HM, NumberText(settlement.hmScore))
        end
        rows[#rows + 1] = FormatString(
            SI_DUNGEON_SCORES_COMPONENT_TEMPO, NumberText(settlement.tempoScore))
        rows[#rows + 1] = FormatString(
            SI_DUNGEON_SCORES_COMPONENT_VITALITY, NumberText(settlement.vitalityScore))
        if showRacePenalties and (tonumber(settlement.abandonedHardModeCount) or 0) > 0 then
            rows[#rows + 1] = FormatString(
                SI_DUNGEON_SCORES_COMPONENT_HM_ABANDONED,
                NumberText(settlement.abandonedHardModeScore),
                tonumber(settlement.abandonedHardModeCount) or 0)
        end
        if showRacePenalties and (tonumber(settlement.companionPenalty) or 0) < 0 then
            rows[#rows + 1] = FormatString(
                SI_DUNGEON_SCORES_COMPONENT_COMPANION,
                NumberText(settlement.companionPenalty))
        end
        if showRacePenalties then
            if (tonumber(settlement.pitstopPenalty) or 0) < 0 then
                rows[#rows + 1] = FormatString(
                    SI_DUNGEON_SCORES_COMPONENT_PITSTOP,
                    NumberText(settlement.pitstopPenalty))
            end
            rows[#rows + 1] = FormatString(
                SI_DUNGEON_SCORES_COMPONENT_ABANDONMENT,
                NumberText(settlement.abandonmentPenalty))
        end
        return rows
    end
    local trifectaSupported = IsTrifectaSupported(settlement)
    if trifectaSupported then
        local hmRow = FormatString(
            SI_DUNGEON_SCORES_COMPONENT_HM,
            NumberText(settlement.hmScore))
        if showRacePenalties and (tonumber(settlement.abandonedHardModeCount) or 0) > 0 then
            hmRow = hmRow .. " | " .. FormatString(
                SI_DUNGEON_SCORES_COMPONENT_HM_ABANDONED,
                NumberText(settlement.abandonedHardModeScore),
                tonumber(settlement.abandonedHardModeCount) or 0)
        end
        rows[#rows + 1] = hmRow
    end
    rows[#rows + 1] = FormatString(
        SI_DUNGEON_SCORES_COMPONENT_SPEED,
        NumberText(settlement.speedBonus))

    if settlement.additionalSpeedBonus ~= nil then
        local additional = FormatString(
            SI_DUNGEON_SCORES_COMPONENT_ADDITIONAL_SPEED,
            NumberText(settlement.additionalSpeedBonus))
        if tonumber(settlement.additionalSpeedBonus) and tonumber(settlement.additionalSpeedBonus) > 0
            and tonumber(settlement.additionalSpeedTierMs) then
            additional = additional .. FormatString(
                SI_DUNGEON_SCORES_COMPONENT_THRESHOLD_SUFFIX,
                FormatDurationMs(settlement.additionalSpeedTierMs))
        end
        rows[#rows + 1] = additional
    end

    rows[#rows + 1] = FormatString(SI_DUNGEON_SCORES_COMPONENT_TEMPO, NumberText(settlement.tempoScore))
    if settlement.partyChallengeScore ~= nil then
        local partyLabel = SI_DUNGEON_SCORES_COMPONENT_PARTY_CHALLENGE
        local partyBasis = PartyAverageText(settlement.partyAverageGroupSize)
        if settlement.partyChallengePolicy == "peak-terminal-weighted-10pct" then
            partyLabel = settlement.terminalEncounterPartySizeSource == "observed-final-fight"
                and SI_DUNGEON_SCORES_COMPONENT_PARTY_CHALLENGE_TERMINAL
                or SI_DUNGEON_SCORES_COMPONENT_PARTY_CHALLENGE_FALLBACK
            partyBasis = tostring(settlement.runGroupSize or "?")
        end
        rows[#rows + 1] = FormatString(partyLabel,
            NumberText(settlement.partyChallengeScore), partyBasis,
            tostring(settlement.terminalEncounterPartySize or "?"))
    end
    rows[#rows + 1] = FormatString(SI_DUNGEON_SCORES_COMPONENT_COEFFICIENT, CoefficientText(settlement.coefficient or 100))
    rows[#rows + 1] = FormatString(SI_DUNGEON_SCORES_COMPONENT_VITALITY, NumberText(settlement.vitalityScore))
    rows[#rows + 1] = FormatString(SI_DUNGEON_SCORES_COMPONENT_NO_DEATH, NumberText(settlement.noDeathBonus))
    if showRacePenalties and (tonumber(settlement.companionPenalty) or 0) < 0 then
        rows[#rows + 1] = FormatString(
            SI_DUNGEON_SCORES_COMPONENT_COMPANION,
            NumberText(settlement.companionPenalty))
    end
    if showRacePenalties and (tonumber(settlement.pitstopPenalty) or 0) < 0 then
        rows[#rows + 1] = FormatString(
            SI_DUNGEON_SCORES_COMPONENT_PITSTOP,
            NumberText(settlement.pitstopPenalty))
    end
    if trifectaSupported then
        rows[#rows + 1] = FormatString(
            SI_DUNGEON_SCORES_COMPONENT_TRIFECTA,
            NumberText(settlement.trifectaBonus or 0))
    end
    return rows
end

function History:GetGroupRows(settlement)
    local members = settlement and settlement.groupMembers or nil
    if not members or #members == 0 then
        return { GetString(SI_DUNGEON_SCORES_NO_GROUP_MEMBERS) }
    end

    local rows = {}
    for i = 1, math.min(4, #members) do
        local member = members[i]
        local accountName = member.accountName or ""
        local characterName = NormalizeName(member.characterName)
        if accountName ~= "" and characterName ~= GetString(SI_DUNGEON_SCORES_UNKNOWN) then
            rows[#rows + 1] = string.format("%s  |  %s", accountName, characterName)
        elseif accountName ~= "" then
            rows[#rows + 1] = accountName
        else
            rows[#rows + 1] = characterName
        end
    end
    return rows
end

function History:ClearDetails(message)
    self.selectedSettlement = nil
    self.detailLabel:SetText(message or "")
    for _, label in ipairs(self.componentLabels or {}) do
        label:SetText("")
    end
    for _, label in ipairs(self.groupLabels or {}) do
        label:SetText("")
        label:SetHidden(true)
    end
    self.completionBossLabel:SetText("")
    self.completionReasonLabel:SetText("")
    self.recordedByLabel:SetText("")
    self:ApplyLayout(false)
    self:ResetDetailScroll()
    self:RefreshPublishButton()
end

function History:ShowSettlementDetails(settlement, highScoreView)
    if not settlement then
        self:ClearDetails("")
        return
    end
    self.selectedSettlement = settlement
    self.componentHeader:SetText(GetString(SI_DUNGEON_SCORES_SCORE_COMPONENTS))
    self.groupHeader:SetText(GetString(SI_DUNGEON_SCORES_GROUP_MEMBERS))
    self.detailLabel:SetText(self:FormatDetails(settlement, highScoreView))
    local componentRows = self:GetComponentRows(settlement)
    for i, label in ipairs(self.componentLabels or {}) do
        label:SetText(componentRows[i] or "")
    end
    local groupRows = self:GetGroupRows(settlement)
    for i, label in ipairs(self.groupLabels or {}) do
        local row = groupRows[i] or ""
        label:SetText(row)
        label:SetHidden(row == "")
    end
    local completionBoss = settlement.completionBossName and NormalizeName(settlement.completionBossName) or "--"
    self.completionBossLabel:SetText(FormatString(
        SI_DUNGEON_SCORES_COMPLETION_BOSS,
        completionBoss))
    local completionReason = settlement.runOutcome == "abandoned"
        and GetString(SI_DUNGEON_SCORES_RUN_ABANDONED)
        or tostring(settlement.completionReason
            or GetString(SI_DUNGEON_SCORES_UNKNOWN_LOWER))
    local finalizationReason = settlement.scoreSessionOpen
        and GetString(SI_DUNGEON_SCORES_OPEN)
        or tostring(settlement.finalizeReason
            or GetString(SI_DUNGEON_SCORES_UNKNOWN_LOWER))
    self.completionReasonLabel:SetText(FormatString(
        SI_DUNGEON_SCORES_COMPLETION_REASON,
        completionReason,
        finalizationReason))
    self.recordedByLabel:SetText(FormatString(
        SI_DUNGEON_SCORES_RECORDED_BY,
        tostring(settlement.addonVersion
            or GetString(SI_DUNGEON_SCORES_UNKNOWN_LOWER))))
    self:ApplyLayout(false)
    self:ResetDetailScroll()
    self:RefreshPublishButton()
end

function History:GetPublicationStatusText(settlement)
    if not settlement then
        return nil
    end
    local request = type(DS.GetQueuedPublicationRequest) == "function"
        and DS:GetQueuedPublicationRequest(settlement) or nil
    if request then
        local delivery = DS:GetDeliverySnapshot()
        local receipts = type(delivery) == "table"
            and tonumber(delivery.schemaVersion) == 1
            and type(delivery.receipts) == "table" and delivery.receipts or nil
        local receipt = receipts and receipts[request.queueKey] or nil
        local status = type(receipt) == "table" and receipt.status or nil
        if status == "delivered" then
            return GetString(SI_DUNGEON_SCORES_DETAIL_PUBLICATION_DELIVERED)
        elseif status == "rejected" then
            return GetString(SI_DUNGEON_SCORES_DETAIL_PUBLICATION_REJECTED)
        elseif status == "retrying" then
            return GetString(SI_DUNGEON_SCORES_DETAIL_PUBLICATION_RETRYING)
        elseif status == "outcome-unknown" then
            return GetString(SI_DUNGEON_SCORES_DETAIL_PUBLICATION_OUTCOME_UNKNOWN)
        end
        return GetString(SI_DUNGEON_SCORES_DETAIL_PUBLICATION_QUEUED)
    end
    if type(DS.GetPublicationEligibility) ~= "function" then
        return nil
    end
    local eligible, reason = DS:GetPublicationEligibility(settlement)
    if eligible then
        return GetString(SI_DUNGEON_SCORES_DETAIL_PUBLICATION_READY)
    elseif reason == "not-finalized" then
        return GetString(SI_DUNGEON_SCORES_DETAIL_PUBLICATION_NOT_FINALIZED)
    elseif reason == "ineligible" or reason == "incomplete" then
        return GetString(SI_DUNGEON_SCORES_DETAIL_PUBLICATION_INELIGIBLE)
    elseif reason == "ambiguous-team" then
        return GetString(SI_DUNGEON_SCORES_DETAIL_PUBLICATION_AMBIGUOUS)
    elseif reason == "no-team" then
        local matches = type(DS.Util.GetMatchingPublicationTeams) == "function"
            and DS.Util.GetMatchingPublicationTeams(
                self.saved and self.saved.publicationTeams,
                settlement.groupMembers)
            or {}
        if #matches > 0 then
            return GetString(SI_DUNGEON_SCORES_DETAIL_PUBLICATION_UNASSIGNED)
        end
        return GetString(SI_DUNGEON_SCORES_DETAIL_PUBLICATION_NO_TEAM)
    elseif reason == "guild-route-unavailable" then
        return GetString(SI_DUNGEON_SCORES_DETAIL_PUBLICATION_GUILD_ROUTE_UNAVAILABLE)
    elseif reason == "race-to-bottom-not-selected" then
        return GetString(SI_DUNGEON_SCORES_RACE_TO_BOTTOM_REQUIRE_SELECTION)
    end
    return GetString(SI_DUNGEON_SCORES_DETAIL_PUBLICATION_INELIGIBLE)
end

function History:RefreshPublishButton()
    if not self.publishButton or not self.raceButton
        or not self.assignTeamButton or not self.assignGuildButton
        or not self.assignEventButton then
        return
    end
    local settlement = self.selectedSettlement
    local visible = self.activeTab ~= TAB_BETA and self.activeTab ~= TAB_TEAMS
        and self.activeTab ~= TAB_GUILDS
        and settlement ~= nil
    self.publishButton:SetHidden(not visible)
    self.raceButton:SetHidden(not visible)
    self.assignTeamButton:SetHidden(not visible)
    self.assignGuildButton:SetHidden(not visible)
    self.assignEventButton:SetHidden(not visible)
    if not visible then
        self.publishButton:SetEnabled(false)
        self.raceButton:SetEnabled(false)
        self.assignTeamButton:SetEnabled(false)
        self.assignGuildButton:SetEnabled(false)
        self.assignEventButton:SetEnabled(false)
        return
    end
    local eligible = DS:GetPublicationEligibility(settlement)
    local queued = DS:IsSettlementQueuedForPublication(settlement)
    local abandoned = settlement.runOutcome == "abandoned"
    self.publishButton:SetText(GetString(queued
        and SI_DUNGEON_SCORES_SCORE_QUEUED
        or SI_DUNGEON_SCORES_SEND_SELECTED_SCORE))
    self.publishButton:SetEnabled(eligible and not queued)
    self.raceButton:SetText(GetString(
        settlement.publicationRaceToBottomRequested == true
            and SI_DUNGEON_SCORES_RACE_TO_BOTTOM_ON
            or SI_DUNGEON_SCORES_RACE_TO_BOTTOM_OFF))
    self.raceButton:SetEnabled(settlement.scoreSessionOpen == false
        and (tonumber(settlement.raceToBottomScore) ~= nil
            or settlement.publicationRaceToBottomRequested == true))
    local matchingTeams = DS.Util.GetMatchingPublicationTeams(
        self.saved and self.saved.publicationTeams,
        settlement.groupMembers)
    self.assignTeamButton:SetText(GetString(settlement.publicationTeamName
        and SI_DUNGEON_SCORES_CHANGE_TEAM
        or SI_DUNGEON_SCORES_ASSIGN_TEAM))
    self.assignTeamButton:SetEnabled(not queued and #matchingTeams > 0)
    local guilds = type(DS.GetAvailableGuildConfigurations) == "function"
        and DS:GetAvailableGuildConfigurations(settlement) or {}
    self.assignGuildButton:SetText(GetString(settlement.publicationGuildId
        and SI_DUNGEON_SCORES_CHANGE_GUILD
        or SI_DUNGEON_SCORES_ASSIGN_GUILD))
    self.assignGuildButton:SetEnabled(not abandoned
        and settlement.publicationTeamName ~= nil
        and (#guilds > 0 or settlement.publicationGuildId ~= nil))
    self.assignEventButton:SetText(GetString(settlement.publicationGuildEventId
        and SI_DUNGEON_SCORES_CHANGE_EVENT
        or SI_DUNGEON_SCORES_SELECT_EVENT))
    local events = type(DS.GetAvailableGuildEvents) == "function"
        and DS:GetAvailableGuildEvents(settlement, settlement.publicationGuildId) or {}
    self.assignEventButton:SetEnabled(not abandoned
        and settlement.publicationTeamName ~= nil
        and (#events > 0 or settlement.publicationGuildEventId ~= nil))
end

function History:QueueSelectedScore()
    local queued, result = DS:QueueSettlementForPublication(self.selectedSettlement)
    if queued then
        DS:Chat(GetString(SI_DUNGEON_SCORES_CHAT_SCORE_QUEUED))
    elseif result == "already-queued" then
        DS:Chat(GetString(SI_DUNGEON_SCORES_CHAT_SCORE_ALREADY_QUEUED))
    elseif result == "ambiguous-team" then
        DS:Chat(GetString(SI_DUNGEON_SCORES_CHAT_SCORE_AMBIGUOUS_TEAM))
    elseif result == "no-team" then
        DS:Chat(GetString(SI_DUNGEON_SCORES_CHAT_SCORE_NO_TEAM))
    else
        DS:Chat(GetString(SI_DUNGEON_SCORES_CHAT_SCORE_INELIGIBLE))
    end
    self:Refresh()
end

function History:ShowTeamAssignmentMenu()
    local settlement = self.selectedSettlement
    if not settlement or DS:IsSettlementQueuedForPublication(settlement) then
        DS:Chat(GetString(SI_DUNGEON_SCORES_CHAT_TEAM_ASSIGNMENT_LOCKED))
        return
    end
    local matches = DS.Util.GetMatchingPublicationTeams(
        self.saved and self.saved.publicationTeams,
        settlement.groupMembers)
    if #matches == 0 then
        DS:Chat(GetString(SI_DUNGEON_SCORES_CHAT_NO_MATCHING_TEAM))
        return
    end
    if #matches == 1 then
        self:AssignTeamToSettlement(settlement, matches[1])
        return
    end
    ClearMenu()
    for _, team in ipairs(matches) do
        local selectedTeam = team
        AddMenuItem(selectedTeam.name, function()
            self:AssignTeamToSettlement(settlement, selectedTeam)
        end)
    end
    self:ShowForegroundMenu(self.assignTeamButton)
end

function History:ShowForegroundMenu(anchor)
    ShowMenu(anchor)
    if ZO_Menus and ZO_Menus.BringWindowToTop then
        ZO_Menus:BringWindowToTop()
    end
end

function History:AssignTeamToSettlement(settlement, team)
    local assigned, reason = DS:AssignPublicationTeamToRun(settlement, team)
    if assigned then
        DS:Chat(FormatString(SI_DUNGEON_SCORES_CHAT_TEAM_ASSIGNED, team.name))
    elseif reason == "already-queued" then
        DS:Chat(GetString(SI_DUNGEON_SCORES_CHAT_TEAM_ASSIGNMENT_LOCKED))
    else
        DS:Chat(GetString(SI_DUNGEON_SCORES_CHAT_NO_MATCHING_TEAM))
    end
    self:Refresh()
    return assigned, reason
end

function History:ShowGuildAssignmentMenu()
    local settlement = self.selectedSettlement
    if not settlement then
        return
    end
    if not settlement.publicationTeamName then
        DS:Chat(GetString(SI_DUNGEON_SCORES_CHAT_SCORE_NO_TEAM))
        return
    end
    local guilds = type(DS.GetAvailableGuildConfigurations) == "function"
        and DS:GetAvailableGuildConfigurations(settlement) or {}
    if #guilds == 0 and not settlement.publicationGuildId then
        DS:Chat(GetString(SI_DUNGEON_SCORES_CHAT_GUILD_EVENT_UNAVAILABLE))
        return
    end
    ClearMenu()
    AddMenuItem(GetString(SI_DUNGEON_SCORES_ASSIGN_GUILD_GLOBAL), function()
        self:ClearGuildFromSettlement(settlement)
    end)
    for _, guild in ipairs(guilds) do
        local selectedGuild = guild
        AddMenuItem(FormatString(
            selectedGuild.recordsEnabled == true
                and selectedGuild.guildRouteAllowed == true
                and SI_DUNGEON_SCORES_ASSIGN_GUILD_RECORDS
                or SI_DUNGEON_SCORES_ASSIGN_GUILD_EVENTS_ONLY,
            tostring(selectedGuild.guildName or "")), function()
            self:AssignGuildToSettlement(settlement, selectedGuild)
        end)
    end
    self:ShowForegroundMenu(self.assignGuildButton)
end

function History:AssignGuildToSettlement(settlement, guild)
    local assigned, reason = DS:AssignPublicationGuildToRun(settlement, guild)
    if assigned then
        DS:Chat(FormatString(
            SI_DUNGEON_SCORES_CHAT_GUILD_SELECTED_WARNING,
            guild.guildName))
    elseif reason == "no-team" then
        DS:Chat(GetString(SI_DUNGEON_SCORES_CHAT_SCORE_NO_TEAM))
    else
        DS:Chat(GetString(SI_DUNGEON_SCORES_CHAT_GUILD_EVENT_UNAVAILABLE))
    end
    self:Refresh()
    return assigned, reason
end

function History:ShowEventAssignmentMenu()
    local settlement = self.selectedSettlement
    if not settlement then
        return
    end
    if not settlement.publicationTeamName then
        DS:Chat(GetString(SI_DUNGEON_SCORES_CHAT_SCORE_NO_TEAM))
        return
    end
    local events = type(DS.GetAvailableGuildEvents) == "function"
        and DS:GetAvailableGuildEvents(settlement, settlement.publicationGuildId) or {}
    if #events == 0 and not settlement.publicationGuildEventId then
        DS:Chat(GetString(SI_DUNGEON_SCORES_CHAT_NO_ACTIVE_EVENTS))
        return
    end
    ClearMenu()
    if settlement.publicationGuildId then
        AddMenuItem(GetString(SI_DUNGEON_SCORES_SELECT_EVENT_NONE), function()
            self:ClearEventFromSettlement(settlement)
        end)
    end
    for _, guildEvent in ipairs(events) do
        local selectedEvent = guildEvent
        local eventLabel = settlement.publicationGuildId
            and tostring(selectedEvent.guildEventName or "")
            or string.format("%s — %s",
                tostring(selectedEvent.guildName or ""),
                tostring(selectedEvent.guildEventName or ""))
        AddMenuItem(eventLabel, function()
            self:AssignGuildEventToSettlement(settlement, selectedEvent)
        end)
    end
    self:ShowForegroundMenu(self.assignEventButton)
end

function History:AssignGuildEventToSettlement(settlement, guildEvent)
    local assigned, reason = DS:AssignPublicationEventToRun(settlement, guildEvent)
    if assigned then
        DS:Chat(FormatString(
            SI_DUNGEON_SCORES_CHAT_GUILD_EVENT_ASSIGNED,
            guildEvent.guildName,
            guildEvent.guildEventName))
    elseif reason == "already-queued" then
        DS:Chat(GetString(SI_DUNGEON_SCORES_CHAT_TEAM_ASSIGNMENT_LOCKED))
    elseif reason == "no-team" then
        DS:Chat(GetString(SI_DUNGEON_SCORES_CHAT_SCORE_NO_TEAM))
    else
        DS:Chat(GetString(SI_DUNGEON_SCORES_CHAT_GUILD_EVENT_UNAVAILABLE))
    end
    self:Refresh()
    return assigned, reason
end

function History:ClearGuildFromSettlement(settlement)
    local cleared, reason = DS:ClearPublicationGuildFromRun(settlement)
    if cleared then
        DS:Chat(GetString(SI_DUNGEON_SCORES_CHAT_GUILD_EVENT_CLEARED))
    else
        DS:Chat(GetString(SI_DUNGEON_SCORES_CHAT_TEAM_ASSIGNMENT_LOCKED))
    end
    self:Refresh()
    return cleared, reason
end

function History:ClearEventFromSettlement(settlement)
    local cleared, reason = DS:ClearPublicationEventFromRun(settlement)
    if cleared then
        DS:Chat(GetString(SI_DUNGEON_SCORES_CHAT_EVENT_CLEARED))
    else
        DS:Chat(GetString(SI_DUNGEON_SCORES_CHAT_TEAM_ASSIGNMENT_LOCKED))
    end
    self:Refresh()
    return cleared, reason
end

History.ClearGuildEventFromSettlement = History.ClearEventFromSettlement

function History:SetTeamEditorVisible(visible)
    self.teamEditor:SetHidden(not visible)
    self.detailScroll:SetHidden(visible)
end

function History:GetPublicationTeams()
    self.saved.publicationTeams = self.saved.publicationTeams or { registryText = "" }
    return DS.Util.ParsePublicationTeamRegistry(self.saved.publicationTeams.registryText)
end

function History:LoadTeamEditor(team)
    self.teamNameEdit:SetText(team and team.name or "")
    self.teamMembersEdit:SetText(team and table.concat(team.members or {}, ", ") or "")
end

function History:BeginNewTeam()
    self.selectedTeamIndex = nil
    self.teamEditorNew = true
    self.pendingTeamDeleteIndex = nil
    self:LoadTeamEditor(nil)
    self:RefreshTeams()
    if self.teamNameEdit and self.teamNameEdit.TakeFocus then
        self.teamNameEdit:TakeFocus()
    end
end

function History:SaveTeamEditor()
    local line = tostring(self.teamNameEdit:GetText() or "") .. " | "
        .. tostring(self.teamMembersEdit:GetText() or "")
    local parsed, errors = DS.Util.ParsePublicationTeamRegistry(line)
    if #errors > 0 or #parsed ~= 1 then
        DS:Chat(GetString(SI_DUNGEON_SCORES_CHAT_TEAM_INVALID))
        return
    end

    local teams = self:GetPublicationTeams()
    local editIndex = self.teamEditorNew and nil or tonumber(self.selectedTeamIndex)
    for index, team in ipairs(teams) do
        if team.teamKey == parsed[1].teamKey and index ~= editIndex then
            DS:Chat(GetString(SI_DUNGEON_SCORES_CHAT_TEAM_DUPLICATE))
            return
        end
    end
    if editIndex and teams[editIndex] then
        teams[editIndex] = parsed[1]
        self.selectedTeamIndex = editIndex
    else
        teams[#teams + 1] = parsed[1]
        self.selectedTeamIndex = #teams
    end
    self.saved.publicationTeams.registryText = DS.Util.SerializePublicationTeamRegistry(teams)
    self.teamEditorNew = false
    self.pendingTeamDeleteIndex = nil
    self.page = math.floor((self.selectedTeamIndex - 1) / PAGE_SIZE) + 1
    if self.teamNameEdit and self.teamNameEdit.LoseFocus then
        self.teamNameEdit:LoseFocus()
    end
    if self.teamMembersEdit and self.teamMembersEdit.LoseFocus then
        self.teamMembersEdit:LoseFocus()
    end
    DS:Chat(FormatString(SI_DUNGEON_SCORES_CHAT_TEAM_SAVED, parsed[1].name))
    self:RefreshTeams()
end

function History:DeleteSelectedTeam()
    local teams = self:GetPublicationTeams()
    local index = tonumber(self.selectedTeamIndex)
    if self.teamEditorNew or not index or not teams[index] then
        return
    end
    if self.pendingTeamDeleteIndex ~= index then
        self.pendingTeamDeleteIndex = index
        self:RefreshTeams()
        local pendingIndex = index
        zo_callLater(function()
            if self.pendingTeamDeleteIndex == pendingIndex then
                self.pendingTeamDeleteIndex = nil
                self:RefreshTeams()
            end
        end, 5000)
        return
    end

    local deletedName = teams[index].name
    table.remove(teams, index)
    self.saved.publicationTeams.registryText = DS.Util.SerializePublicationTeamRegistry(teams)
    self.pendingTeamDeleteIndex = nil
    self.selectedTeamIndex = #teams > 0 and math.min(index, #teams) or nil
    self.teamEditorNew = #teams == 0
    DS:Chat(FormatString(SI_DUNGEON_SCORES_CHAT_TEAM_DELETED, deletedName))
    self:RefreshTeams()
end

function History:RequestDeleteSelected()
    if self.activeTab ~= TAB_HISTORY then
        return
    end

    local history = self:GetHistory()
    local index = self.selectedIndex
    local settlement = index and history[index] or nil
    if not settlement then
        self.pendingDeleteIndex = nil
        self:Refresh()
        return
    end

    if self.pendingDeleteIndex ~= index then
        self.pendingDeleteIndex = index
        self:Refresh()

        local pendingIndex = index
        zo_callLater(function()
            if self.pendingDeleteIndex == pendingIndex then
                self.pendingDeleteIndex = nil
                self:Refresh()
            end
        end, 5000)
        return
    end

    table.remove(history, index)
    self.pendingDeleteIndex = nil

    local total = #history
    if total == 0 then
        self.page = 1
        self.selectedIndex = nil
    else
        self.selectedIndex = math.min(index, total)
        self.page = math.floor((total - self.selectedIndex) / PAGE_SIZE) + 1
    end

    self:Refresh()
end

local function BetaBoolean(value)
    if value == nil then
        return GetString(SI_DUNGEON_SCORES_NOT_AVAILABLE)
    end
    return value and GetString(SI_DUNGEON_SCORES_YES_LOWER)
        or GetString(SI_DUNGEON_SCORES_NO)
end

local function BetaValue(value)
    if value == nil or value == "" then
        return GetString(SI_DUNGEON_SCORES_NOT_AVAILABLE)
    end
    return tostring(value)
end

local function GetBetaHardModeCounts(snapshot)
    local trackerCount = tonumber(snapshot.hardModeTrackerCount)
        or tonumber(snapshot.hardModeAttemptCount)
    local observedCount = tonumber(snapshot.hardModeObservedCount)
    if observedCount == nil then
        observedCount = 0
        local diagnostics = DS.Diagnostics
        if diagnostics and type(diagnostics.CountObservedHardModeAttempts) == "function" then
            observedCount = diagnostics:CountObservedHardModeAttempts(
                snapshot.hardModeEncounterAttempts)
        end
        observedCount = math.max(
            observedCount,
            tonumber(snapshot.hmCreditedBossCount) or 0)
    end
    return trackerCount, observedCount
end

local function FormatBetaTerminalAbilityAttempts(snapshot)
    if snapshot.terminalAbilityAttempts == nil then
        return GetString(SI_DUNGEON_SCORES_BETA_TERMINAL_ATTEMPTS_UNAVAILABLE)
    end
    local rows = {}
    for _, attempt in ipairs(snapshot.terminalAbilityAttempts or {}) do
        rows[#rows + 1] = FormatString(
            SI_DUNGEON_SCORES_BETA_TERMINAL_ATTEMPT,
            BetaValue(attempt.encounterKey),
            BetaValue(attempt.confirmedEmitterCount),
            BetaValue(attempt.matchedDeathCount),
            BetaValue(attempt.cohortIdentityCount),
            BetaBoolean(attempt.hmObserved),
            BetaBoolean(attempt.terminalDeathSatisfied),
            BetaBoolean(attempt.terminalAbilityDeathAmbiguous),
            BetaBoolean(attempt.credited))
    end
    if #rows == 0 then
        return GetString(SI_DUNGEON_SCORES_BETA_TERMINAL_ATTEMPTS_NONE)
    end
    return table.concat(rows, "\n")
end

function History:FormatBetaRow(snapshot)
    return FormatString(
        SI_DUNGEON_SCORES_BETA_ROW,
        DateText(snapshot.finalizedAtTimeStamp or snapshot.createdAtTimeStamp),
        GetZoneDisplayName(snapshot.zoneId),
        FormatDurationMs(snapshot.elapsedMs),
        BetaValue(snapshot.runGeneration))
end

local function FormatBetaLifecycleTrace(snapshot)
    local trace = type(snapshot.lifecycleTrace) == "table" and snapshot.lifecycleTrace or {}
    if #trace == 0 then
        return ""
    end
    local lines = { GetString(SI_DUNGEON_SCORES_RUN_STATE) }
    local startedAt = tonumber(snapshot.startedAtTimeStamp)
    for index = math.max(1, #trace - 7), #trace do
        local event = trace[index]
        if type(event) == "table" then
            local offset = startedAt and tonumber(event.at)
                and string.format("%+ds", tonumber(event.at) - startedAt) or "?"
            lines[#lines + 1] = string.format("%s  %s  %s",
                offset, BetaValue(event.kind), BetaValue(event.reason))
        end
    end
    return table.concat(lines, "\n")
end

function History:ShowBetaDetails(snapshot)
    if not snapshot then
        self:ClearDetails(GetString(SI_DUNGEON_SCORES_SELECT_BETA))
        return
    end

    self.componentHeader:SetText(GetString(SI_DUNGEON_SCORES_RUN_STATE))
    self.groupHeader:SetText(GetString(SI_DUNGEON_SCORES_SUPPORT_STATE))
    self.detailLabel:SetText(table.concat({
        string.format("|c88CCFF%s|r", GetZoneDisplayName(snapshot.zoneId)),
        FormatString(SI_DUNGEON_SCORES_BETA_RUNTIME_ID, BetaValue(snapshot.snapshotId)),
        FormatString(
            SI_DUNGEON_SCORES_BETA_ADDON_ZONE,
            BetaValue(snapshot.addonVersion),
            BetaValue(snapshot.zoneId),
            BetaBoolean(snapshot.isVeteran)),
        FormatString(
            SI_DUNGEON_SCORES_BETA_DATE,
            DateText(snapshot.finalizedAtTimeStamp or snapshot.completedAtTimeStamp),
            FormatDurationMs(snapshot.elapsedMs)),
        GetString(SI_DUNGEON_SCORES_BETA_PAIR_FILES),
        GetString(SI_DUNGEON_SCORES_BETA_PRIVACY),
    }, "\n"))

    local hmTrackerCount, hmObservedCount = GetBetaHardModeCounts(snapshot)
    local runRows = {
        FormatString(SI_DUNGEON_SCORES_BETA_START, BetaValue(snapshot.startReason), BetaValue(snapshot.restoreCount), BetaValue(snapshot.integrityStatus)),
        FormatString(SI_DUNGEON_SCORES_BETA_COMPETITIVE, BetaBoolean(snapshot.competitiveEligible), BetaValue(snapshot.integrityReason)),
        FormatString(SI_DUNGEON_SCORES_BETA_SCORE, BetaValue(snapshot.scoreAtCompletion), BetaValue(snapshot.currentScore), string.format("%+d", tonumber(snapshot.postCompletionGain) or 0)),
        FormatString(SI_DUNGEON_SCORES_BETA_SESSION, BetaBoolean(snapshot.scoreSessionOpen), BetaValue(snapshot.bossEncountersAtCompletion), BetaValue(snapshot.expectedBossEncountersAtCompletion)),
        FormatString(SI_DUNGEON_SCORES_BETA_KILLS, BetaValue(snapshot.bossKillsAtCompletion), BetaValue(snapshot.deathsAtCompletion), BetaValue(snapshot.hmBossKillsAtCompletion), BetaValue(snapshot.bossEncountersObserved)),
        FormatString(SI_DUNGEON_SCORES_BETA_ELIGIBILITY, BetaBoolean(snapshot.eligibleAtReset), BetaValue(snapshot.eligibilityReason), BetaValue(snapshot.groupSizeAtReset), BetaValue(snapshot.maxConcurrentGroupSize)),
        FormatString(
            SI_DUNGEON_SCORES_BETA_PARTY_CLOCK,
            PartyAverageText(snapshot.partyAverageGroupSize),
            BetaValue(snapshot.partyChallengeScore),
            FormatDurationMs(snapshot.partySizeDurationsMs and snapshot.partySizeDurationsMs[1]),
            FormatDurationMs(snapshot.partySizeDurationsMs and snapshot.partySizeDurationsMs[2]),
            FormatDurationMs(snapshot.partySizeDurationsMs and snapshot.partySizeDurationsMs[3]),
            FormatDurationMs(snapshot.partySizeDurationsMs and snapshot.partySizeDurationsMs[4])),
        FormatString(SI_DUNGEON_SCORES_BETA_AF, BetaBoolean(snapshot.wasLFG), BetaBoolean(snapshot.lfgCompleteState), BetaBoolean(snapshot.finalEncounterArmed), BetaBoolean(snapshot.finalEncounterCompleted), BetaValue(snapshot.completionCandidateReason)),
        FormatString(SI_DUNGEON_SCORES_BETA_IDENTITIES, BetaValue(snapshot.bossIdentitySequence), BetaValue(snapshot.activeBossCountAtCapture), BetaValue(snapshot.reconciledBossKillCount)),
        FormatString(SI_DUNGEON_SCORES_BETA_HM, BetaValue(hmObservedCount), BetaValue(snapshot.hmCreditedBossCount), BetaValue(snapshot.finalEncounterDeathCount)),
    }
    for index, label in ipairs(self.componentLabels or {}) do
        label:SetText(runRows[index] or "")
    end

    local supportRows = {
        FormatString(SI_DUNGEON_SCORES_BETA_BOSS_STATE, BetaValue(snapshot.seenBossNameCount), BetaValue(snapshot.bossEncountersObserved), BetaValue(snapshot.routeAbilityEncounterCount)),
        FormatString(SI_DUNGEON_SCORES_BETA_HM_STATE, BetaValue(hmTrackerCount), BetaValue(hmObservedCount), BetaValue(snapshot.hmCreditedBossCount)),
        FormatString(SI_DUNGEON_SCORES_BETA_FINAL_ATTEMPT, BetaValue(snapshot.finalEncounterAttemptId), BetaValue(snapshot.finalEncounterDeathCount)),
        FormatString(
            SI_DUNGEON_SCORES_BETA_TERMINAL_EMISSION,
            BetaValue(snapshot.terminalAbilityEmitterCount),
            BetaValue(snapshot.terminalAbilityDeathCount)),
        FormatBetaTerminalAbilityAttempts(snapshot),
        FormatString(SI_DUNGEON_SCORES_BETA_SNAPSHOT_KEY, BetaValue(snapshot.snapshotId)),
    }
    for index, label in ipairs(self.groupLabels or {}) do
        label:SetText(supportRows[index] or "")
        label:SetHidden(false)
    end

    self.completionBossLabel:SetText(FormatString(
        SI_DUNGEON_SCORES_COMPLETION_BOSS,
        BetaValue(snapshot.completionBossName)))
    local completionReasonText = FormatString(
        SI_DUNGEON_SCORES_COMPLETION_REASON,
        BetaValue(snapshot.completionReason or snapshot.completionCandidateReason),
        BetaValue(snapshot.finalizeReason))
    local lifecycleText = FormatBetaLifecycleTrace(snapshot)
    if lifecycleText ~= "" then
        completionReasonText = completionReasonText .. "\n\n" .. lifecycleText
    end
    self.completionReasonLabel:SetText(completionReasonText)
    self.recordedByLabel:SetText(GetString(SI_DUNGEON_SCORES_SAVED_VARIABLES_ARTIFACT))
    self:ApplyLayout(false)
    self:ResetDetailScroll()
end

function History:RefreshBeta()
    self:SetTeamEditorVisible(false)
    self.selectedSettlement = nil
    self:RefreshPublishButton()
    if self.highScoreList then
        self.highScoreList:SetHidden(true)
    end
    self.pageLabel:SetHidden(true)
    self.previousButton:SetHidden(true)
    self.nextButton:SetHidden(true)
    self.deleteButton:SetHidden(true)
    self.pendingDeleteIndex = nil

    local snapshots = DS.Diagnostics and DS.Diagnostics:GetBetaRunSnapshots() or {}
    local total = #snapshots
    self.countLabel:SetText(FormatString(SI_DUNGEON_SCORES_COUNT_CAPTURED, total))
    self.listHeader:SetText(GetString(SI_DUNGEON_SCORES_RECENT_BETA))
    self.detailHeader:SetText(GetString(SI_DUNGEON_SCORES_RUN_SUPPORT))

    local firstVisibleIndex = nil
    for rowNumber, row in ipairs(self.rows or {}) do
        local snapshotIndex = total - (rowNumber - 1)
        local snapshot = snapshotIndex >= 1 and snapshots[snapshotIndex] or nil
        row.control.selectionKey = snapshot and snapshotIndex or nil
        row.control.isSelected = snapshot and self.selectedBetaIndex == snapshotIndex or false
        row.control:SetHidden(snapshot == nil)

        if snapshot then
            firstVisibleIndex = firstVisibleIndex or snapshotIndex
            row.label:SetText(self:FormatBetaRow(snapshot))
            if row.control.isSelected then
                row.label:SetColor(1, 1, 1, 1)
                row.backdrop:SetCenterColor(0.18, 0.28, 0.36, 0.85)
                row.backdrop:SetEdgeColor(0.45, 0.7, 0.9, 1)
            else
                row.label:SetColor(HISTORY_IDLE_COLOR[1], HISTORY_IDLE_COLOR[2], HISTORY_IDLE_COLOR[3], HISTORY_IDLE_COLOR[4])
                row.backdrop:SetCenterColor(0.08, 0.08, 0.08, 0.5)
                row.backdrop:SetEdgeColor(0.18, 0.18, 0.18, 0.7)
            end
        end
    end

    if total == 0 then
        self.selectedBetaIndex = nil
        self.componentHeader:SetText(GetString(SI_DUNGEON_SCORES_RUN_STATE))
        self.groupHeader:SetText(GetString(SI_DUNGEON_SCORES_SUPPORT_STATE))
        self:ClearDetails(GetString(SI_DUNGEON_SCORES_NO_BETA))
        return
    end

    if not self.selectedBetaIndex or not snapshots[self.selectedBetaIndex] then
        self.selectedBetaIndex = firstVisibleIndex or total
    end
    self:ShowBetaDetails(snapshots[self.selectedBetaIndex])
end

function History:RefreshTeams()
    self:SetTeamEditorVisible(true)
    self.selectedSettlement = nil
    self:RefreshPublishButton()
    if self.highScoreList then
        self.highScoreList:SetHidden(true)
    end
    self.deleteButton:SetHidden(true)
    self.publishButton:SetHidden(true)
    self.assignTeamButton:SetHidden(true)
    self.assignGuildButton:SetHidden(true)
    self.assignEventButton:SetHidden(true)
    self.pendingDeleteIndex = nil

    local teams = self:GetPublicationTeams()
    local total = #teams
    local totalPages = math.max(1, math.ceil(total / PAGE_SIZE))
    if self.page > totalPages then
        self.page = totalPages
    elseif self.page < 1 then
        self.page = 1
    end

    self.countLabel:SetText(FormatString(SI_DUNGEON_SCORES_COUNT_TEAMS, total))
    self.listHeader:SetText(GetString(SI_DUNGEON_SCORES_REGISTERED_TEAMS))
    self.detailHeader:SetText(GetString(SI_DUNGEON_SCORES_TEAM_DETAILS))
    self.pageLabel:SetHidden(false)
    self.previousButton:SetHidden(false)
    self.nextButton:SetHidden(false)
    self.pageLabel:SetText(FormatString(SI_DUNGEON_SCORES_PAGE, self.page, totalPages))
    self.previousButton:SetEnabled(self.page > 1)
    self.nextButton:SetEnabled(self.page < totalPages)

    local firstIndex = ((self.page - 1) * PAGE_SIZE) + 1
    local firstVisibleIndex = nil
    for rowNumber, row in ipairs(self.rows or {}) do
        local teamIndex = firstIndex + rowNumber - 1
        local team = teams[teamIndex]
        row.control.selectionKey = team and teamIndex or nil
        row.control.isSelected = team and not self.teamEditorNew
            and self.selectedTeamIndex == teamIndex or false
        row.control:SetHidden(team == nil)
        if team then
            firstVisibleIndex = firstVisibleIndex or teamIndex
            row.label:SetText(FormatString(
                SI_DUNGEON_SCORES_TEAM_ROW,
                team.name,
                table.concat(team.members, ", ")))
            if row.control.isSelected then
                row.label:SetColor(1, 1, 1, 1)
                row.backdrop:SetCenterColor(0.18, 0.28, 0.36, 0.85)
                row.backdrop:SetEdgeColor(0.45, 0.7, 0.9, 1)
            else
                row.label:SetColor(HISTORY_IDLE_COLOR[1], HISTORY_IDLE_COLOR[2], HISTORY_IDLE_COLOR[3], HISTORY_IDLE_COLOR[4])
                row.backdrop:SetCenterColor(0.08, 0.08, 0.08, 0.5)
                row.backdrop:SetEdgeColor(0.18, 0.18, 0.18, 0.7)
            end
        end
    end

    if not self.teamEditorNew then
        if not self.selectedTeamIndex or not teams[self.selectedTeamIndex] then
            self.selectedTeamIndex = firstVisibleIndex or (total > 0 and 1 or nil)
        end
        self:LoadTeamEditor(self.selectedTeamIndex and teams[self.selectedTeamIndex] or nil)
    end
    self.teamDeleteButton:SetEnabled(not self.teamEditorNew and self.selectedTeamIndex ~= nil)
    self.teamDeleteButton:SetText(GetString(
        self.pendingTeamDeleteIndex == self.selectedTeamIndex
            and SI_DUNGEON_SCORES_TEAM_CONFIRM_DELETE
            or SI_DUNGEON_SCORES_TEAM_DELETE))
end

function History:GetActiveRowCount()
    if self.activeTab == TAB_HISTORY then
        return #self:GetHistory()
    elseif self.activeTab == TAB_BETA then
        local snapshots = DS.Diagnostics and DS.Diagnostics:GetBetaRunSnapshots() or {}
        return #snapshots
    elseif self.activeTab == TAB_TEAMS then
        return #self:GetPublicationTeams()
    elseif self.activeTab == TAB_GUILDS then
        return type(DS.GetGuildDirectoryEntries) == "function"
            and #DS:GetGuildDirectoryEntries() or 0
    end
    return #self:GetHighScoreRows(self.activeTab)
end

local function GuildDirectoryModeText(entry)
    if entry.recruitmentMode == "eso-guild" then
        return GetString(SI_DUNGEON_SCORES_GUILD_MODE_ESO)
    elseif entry.recruitmentMode == "discord-server" then
        return GetString(SI_DUNGEON_SCORES_GUILD_MODE_DISCORD)
    end
    return GetString(SI_DUNGEON_SCORES_GUILD_MODE_BOTH)
end

local function GuildDirectoryName(entry)
    if type(entry.recruitmentGuildLink) == "string"
        and (entry.recruitmentMode == "eso-guild"
            or entry.recruitmentMode == "both") then
        return entry.recruitmentGuildLink
    end
    return string.format("|c88CCFF%s|r", tostring(entry.guildName or ""):gsub("|", ""))
end

local function EventTimestampText(timestamp)
    timestamp = tonumber(timestamp)
    if not timestamp then
        return GetString(SI_DUNGEON_SCORES_UNKNOWN)
    end
    local dateText, timeText = FormatAchievementLinkTimestamp(timestamp)
    return string.format("%s %s", tostring(dateText or ""), tostring(timeText or ""))
end

local function FeaturedEventDungeonText(event)
    if type(event.zoneIds) ~= "table" or #event.zoneIds == 0 then
        return GetString(SI_DUNGEON_SCORES_GUILD_EVENT_ALL_DUNGEONS)
    end
    local names = {}
    for _, zoneId in ipairs(event.zoneIds) do
        names[#names + 1] = GetZoneDisplayName(zoneId)
    end
    table.sort(names, function(left, right)
        return zo_strlower(left) < zo_strlower(right)
    end)
    return table.concat(names, ", ")
end

function History:ShowGuildDirectoryDetails(entry)
    if not entry then
        self:ClearDetails(GetString(SI_DUNGEON_SCORES_NO_GUILD_LISTINGS))
        return
    end
    self.detailLabel:SetText(table.concat({
        GuildDirectoryName(entry),
        tostring(entry.recruitmentCopy or ""),
    }, "\n\n"))
    self.componentHeader:SetText(GetString(SI_DUNGEON_SCORES_GUILD_LISTING_DETAILS))
    local rows = {
        FormatString(SI_DUNGEON_SCORES_GUILD_LISTING_MODE, GuildDirectoryModeText(entry)),
        FormatString(
            SI_DUNGEON_SCORES_GUILD_LISTING_SERVER,
            tostring(entry.recruitmentMegaserver
                or GetString(SI_DUNGEON_SCORES_BOTH_PC_MEGASERVERS))),
        FormatString(
            SI_DUNGEON_SCORES_GUILD_LISTING_CONTACT,
            tostring(entry.recruitmentContact or "")),
    }
    for index, label in ipairs(self.componentLabels or {}) do
        label:SetText(rows[index] or "")
    end
    local event = entry.featuredEvent
    self.groupHeader:SetText(GetString(event
        and SI_DUNGEON_SCORES_GUILD_LISTING_FEATURED_EVENT
        or SI_DUNGEON_SCORES_GUILD_LISTING_ACCESS))
    local eventRows = nil
    if event then
        eventRows = {
            FormatString(
                event.isCurrent
                    and SI_DUNGEON_SCORES_GUILD_LISTING_CURRENT_EVENT
                    or SI_DUNGEON_SCORES_GUILD_LISTING_NEXT_EVENT,
                tostring(event.guildEventName or "")),
            FormatString(
                SI_DUNGEON_SCORES_GUILD_EVENT_VISIBILITY,
                GetString(event.accessMode == "eso-members"
                    and SI_DUNGEON_SCORES_GUILD_EVENT_GUILD_ONLY
                    or SI_DUNGEON_SCORES_GUILD_EVENT_GLOBAL)),
            FormatString(
                SI_DUNGEON_SCORES_GUILD_EVENT_WINDOW,
                EventTimestampText(event.startsAt),
                EventTimestampText(event.endsAt)),
            FormatString(
                SI_DUNGEON_SCORES_GUILD_EVENT_DUNGEONS,
                FeaturedEventDungeonText(event)),
            GetString(SI_DUNGEON_SCORES_GUILD_LISTING_ACCESS_NOTICE),
        }
    end
    for index, label in ipairs(self.groupLabels or {}) do
        local row = eventRows and eventRows[index]
            or (index == 1
                and GetString(SI_DUNGEON_SCORES_GUILD_LISTING_ACCESS_NOTICE) or "")
        label:SetText(row)
        label:SetHidden(not row or row == "")
    end
    self.completionBossLabel:SetText("")
    self.completionReasonLabel:SetText("")
    self.recordedByLabel:SetText(GetString(SI_DUNGEON_SCORES_GUILD_LISTING_CONFIGURED_BY))
    self:ApplyLayout(false)
    self:ResetDetailScroll()
end

function History:RefreshGuilds()
    self:SetTeamEditorVisible(false)
    self.selectedSettlement = nil
    self:RefreshPublishButton()
    if self.highScoreList then
        self.highScoreList:SetHidden(true)
    end
    self.deleteButton:SetHidden(true)
    self.pendingDeleteIndex = nil

    local guilds = type(DS.GetGuildDirectoryEntries) == "function"
        and DS:GetGuildDirectoryEntries() or {}
    local total = #guilds
    local totalPages = math.max(1, math.ceil(total / PAGE_SIZE))
    self.page = math.max(1, math.min(self.page, totalPages))
    self.countLabel:SetText(FormatString(SI_DUNGEON_SCORES_COUNT_GUILDS, total))
    self.listHeader:SetText(GetString(SI_DUNGEON_SCORES_REGISTERED_GUILDS))
    self.detailHeader:SetText(GetString(SI_DUNGEON_SCORES_GUILD_DETAILS))
    self.pageLabel:SetHidden(false)
    self.previousButton:SetHidden(false)
    self.nextButton:SetHidden(false)
    self.pageLabel:SetText(FormatString(SI_DUNGEON_SCORES_PAGE, self.page, totalPages))
    self.previousButton:SetEnabled(self.page > 1)
    self.nextButton:SetEnabled(self.page < totalPages)

    local firstIndex = ((self.page - 1) * PAGE_SIZE) + 1
    local firstVisibleIndex = nil
    for rowNumber, row in ipairs(self.rows or {}) do
        local guildIndex = firstIndex + rowNumber - 1
        local guild = guilds[guildIndex]
        row.control.selectionKey = guild and guildIndex or nil
        row.control.isSelected = guild and self.selectedGuildDirectoryIndex == guildIndex or false
        row.control:SetHidden(guild == nil)
        if guild then
            firstVisibleIndex = firstVisibleIndex or guildIndex
            row.label:SetText(tostring(guild.guildName or ""))
            if row.control.isSelected then
                row.label:SetColor(1, 1, 1, 1)
                row.backdrop:SetCenterColor(0.18, 0.28, 0.36, 0.85)
                row.backdrop:SetEdgeColor(0.45, 0.7, 0.9, 1)
            else
                row.label:SetColor(HISTORY_IDLE_COLOR[1], HISTORY_IDLE_COLOR[2], HISTORY_IDLE_COLOR[3], HISTORY_IDLE_COLOR[4])
                row.backdrop:SetCenterColor(0.08, 0.08, 0.08, 0.5)
                row.backdrop:SetEdgeColor(0.18, 0.18, 0.18, 0.7)
            end
        end
    end
    if total == 0 then
        self.selectedGuildDirectoryIndex = nil
        self:ClearDetails(GetString(SI_DUNGEON_SCORES_NO_GUILD_LISTINGS))
        return
    end
    if not self.selectedGuildDirectoryIndex
        or not guilds[self.selectedGuildDirectoryIndex] then
        self.selectedGuildDirectoryIndex = firstVisibleIndex or 1
    end
    self:ShowGuildDirectoryDetails(guilds[self.selectedGuildDirectoryIndex])
end

function History:RefreshHistory()
    self:SetTeamEditorVisible(false)
    if self.highScoreList then
        self.highScoreList:SetHidden(true)
    end
    for _, row in ipairs(self.rows or {}) do
        row.control:SetHidden(false)
    end
    self.pageLabel:SetHidden(false)
    self.previousButton:SetHidden(false)
    self.nextButton:SetHidden(false)

    local history = self:GetHistory()
    local total = #history
    local totalPages = math.max(1, math.ceil(total / PAGE_SIZE))
    if self.page > totalPages then
        self.page = totalPages
    elseif self.page < 1 then
        self.page = 1
    end

    self.countLabel:SetText(FormatString(SI_DUNGEON_SCORES_COUNT_SAVED, total))
    self.listHeader:SetText(GetString(SI_DUNGEON_SCORES_COMPLETED_RUNS))
    self.detailHeader:SetText(GetString(SI_DUNGEON_SCORES_RUN_DETAILS))
    self.componentHeader:SetText(GetString(SI_DUNGEON_SCORES_SCORE_COMPONENTS))
    self.groupHeader:SetText(GetString(SI_DUNGEON_SCORES_GROUP_MEMBERS))
    self.pageLabel:SetText(FormatString(SI_DUNGEON_SCORES_PAGE, self.page, totalPages))
    self.previousButton:SetEnabled(self.page > 1)
    self.nextButton:SetEnabled(self.page < totalPages)
    self.deleteButton:SetHidden(false)
    self.deleteButton:SetEnabled(total > 0 and self.selectedIndex ~= nil)
    if self.pendingDeleteIndex and self.pendingDeleteIndex == self.selectedIndex then
        self.deleteButton:SetText(GetString(SI_DUNGEON_SCORES_CONFIRM_DELETE))
    else
        self.deleteButton:SetText(GetString(SI_DUNGEON_SCORES_DELETE_SELECTED))
    end

    local newestIndex = total - ((self.page - 1) * PAGE_SIZE)
    local firstVisibleIndex = nil

    for rowNumber, row in ipairs(self.rows) do
        local historyIndex = newestIndex - (rowNumber - 1)
        local settlement = historyIndex >= 1 and history[historyIndex] or nil
        row.control.selectionKey = settlement and historyIndex or nil
        row.control.isSelected = settlement and self.selectedIndex == historyIndex or false
        row.control:SetHidden(settlement == nil)

        if settlement then
            if not firstVisibleIndex then
                firstVisibleIndex = historyIndex
            end
            row.label:SetText(self:FormatRow(settlement))
            if row.control.isSelected then
                row.label:SetColor(1, 1, 1, 1)
                row.backdrop:SetCenterColor(0.18, 0.28, 0.36, 0.85)
                row.backdrop:SetEdgeColor(0.45, 0.7, 0.9, 1)
            else
                row.label:SetColor(HISTORY_IDLE_COLOR[1], HISTORY_IDLE_COLOR[2], HISTORY_IDLE_COLOR[3], HISTORY_IDLE_COLOR[4])
                row.backdrop:SetCenterColor(0.08, 0.08, 0.08, 0.5)
                row.backdrop:SetEdgeColor(0.18, 0.18, 0.18, 0.7)
            end
        end
    end

    if total == 0 then
        self.selectedIndex = nil
        self.pendingDeleteIndex = nil
        self.deleteButton:SetEnabled(false)
        self.deleteButton:SetText(GetString(SI_DUNGEON_SCORES_DELETE_SELECTED))
        self:ClearDetails(GetString(SI_DUNGEON_SCORES_NO_HISTORY))
        return
    end

    if not self.selectedIndex or not history[self.selectedIndex] then
        self.selectedIndex = firstVisibleIndex or total
        self:RefreshHistory()
        return
    end

    self:ShowSettlementDetails(history[self.selectedIndex], false)
end

function History:RefreshHighScores(tabKey)
    self:SetTeamEditorVisible(false)
    local entries = self:GetHighScoreRows(tabKey)
    local total = #entries
    local scored = 0
    for _, entry in ipairs(entries) do
        if entry.settlement then
            scored = scored + 1
        end
    end

    local basegame = tabKey == TAB_BASEGAME
    self.countLabel:SetText(FormatString(SI_DUNGEON_SCORES_COUNT_SCORED, scored, total))
    self.listHeader:SetText(basegame
        and GetString(SI_DUNGEON_SCORES_BASEGAME_PERSONAL_BESTS)
        or GetString(SI_DUNGEON_SCORES_DLC_PERSONAL_BESTS))
    self.detailHeader:SetText(GetString(SI_DUNGEON_SCORES_HIGH_SCORE_DETAILS))
    self.componentHeader:SetText(GetString(SI_DUNGEON_SCORES_SCORE_COMPONENTS))
    self.groupHeader:SetText(GetString(SI_DUNGEON_SCORES_GROUP_MEMBERS))
    self.pageLabel:SetHidden(true)
    self.previousButton:SetHidden(true)
    self.nextButton:SetHidden(true)
    self.deleteButton:SetHidden(true)
    self.pendingDeleteIndex = nil

    for _, row in ipairs(self.rows or {}) do
        row.control:SetHidden(true)
        row.control.selectionKey = nil
        row.control.isSelected = false
    end

    if not self.highScoreList then
        self.selectedZoneId = nil
        self:ClearDetails(GetString(SI_DUNGEON_SCORES_HIGH_SCORE_UNAVAILABLE))
        return
    end

    self.highScoreList:SetHidden(false)
    ZO_ScrollList_Clear(self.highScoreList)
    local scrollData = ZO_ScrollList_GetDataList(self.highScoreList)

    local selectedEntry = nil
    for index, entry in ipairs(entries) do
        entry.sortIndex = index
        scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(HIGH_SCORE_DATA_TYPE, entry)
        if entry.zoneId == self.selectedZoneId
            and entry.partySize == self.selectedPartySize then
            selectedEntry = entry
        end
    end
    ZO_ScrollList_Commit(self.highScoreList)

    if total == 0 then
        self.selectedZoneId = nil
        self:ClearDetails(GetString(SI_DUNGEON_SCORES_NO_CONFIGURED_DUNGEONS))
        return
    end

    if not selectedEntry then
        selectedEntry = entries[1]
        self.selectedZoneId = selectedEntry.zoneId
        self.selectedPartySize = selectedEntry.partySize
    end

    ZO_ScrollList_SelectData(self.highScoreList, selectedEntry, nil, true)
    ZO_ScrollList_RefreshVisible(self.highScoreList)
    ZO_ScrollList_ScrollDataIntoView(self.highScoreList, selectedEntry.sortIndex)

    if selectedEntry.settlement then
        self:ShowSettlementDetails(selectedEntry.settlement, true)
    else
        self:ClearDetails(FormatString(
            SI_DUNGEON_SCORES_NO_PRESERVED_HIGH_SCORE,
            selectedEntry.zoneName))
    end
end

function History:Refresh()
    if not self.window then
        return
    end
    self:RefreshTabs()
    if self.activeTab == TAB_HISTORY then
        self:RefreshHistory()
    elseif self.activeTab == TAB_BETA then
        self:RefreshBeta()
    elseif self.activeTab == TAB_TEAMS then
        self:RefreshTeams()
    elseif self.activeTab == TAB_GUILDS then
        self:RefreshGuilds()
    else
        self:RefreshHighScores(self.activeTab)
    end
end

function History:Show()
    if not self.window then
        return
    end
    self:ApplyFonts()
    self:ApplyLayout(true)
    self:StartResizePolling()
    self.page = 1
    self.pendingDeleteIndex = nil
    if self.activeTab == TAB_HISTORY then
        self.selectedIndex = #self:GetHistory() > 0 and #self:GetHistory() or nil
    elseif self.activeTab == TAB_BETA then
        local snapshots = DS.Diagnostics and DS.Diagnostics:GetBetaRunSnapshots() or {}
        self.selectedBetaIndex = #snapshots > 0 and #snapshots or nil
    elseif self.activeTab == TAB_GUILDS then
        local guilds = type(DS.GetGuildDirectoryEntries) == "function"
            and DS:GetGuildDirectoryEntries() or {}
        self.selectedGuildDirectoryIndex = #guilds > 0 and 1 or nil
    else
        self.selectedZoneId = nil
    end
    self:Refresh()
    self.window:SetHidden(false)
    if self.window.BringWindowToTop then
        self.window:BringWindowToTop()
    end
end

function History:ShowBeta()
    if not self.window then
        return
    end
    self.activeTab = TAB_BETA
    self.saved.historyWindow.activeTab = TAB_BETA
    local snapshots = DS.Diagnostics and DS.Diagnostics:GetBetaRunSnapshots() or {}
    self.selectedBetaIndex = #snapshots > 0 and #snapshots or nil
    self:Show()
end

function History:Hide()
    self:StopResizePolling()
    if self.window then
        self.window:SetHidden(true)
    end
end

function History:Toggle()
    if not self.window then
        return
    end
    if self.window:IsHidden() then
        self:Show()
    else
        self:Hide()
    end
end

function History:OnRunFinalized()
    if self.window and not self.window:IsHidden() then
        self.page = 1
        if self.activeTab == TAB_HISTORY then
            self.selectedIndex = #self:GetHistory()
        elseif self.activeTab == TAB_BETA then
            local snapshots = DS.Diagnostics and DS.Diagnostics:GetBetaRunSnapshots() or {}
            self.selectedBetaIndex = #snapshots > 0 and #snapshots or nil
        else
            self.selectedZoneId = nil
        end
        self:Refresh()
    end
end
