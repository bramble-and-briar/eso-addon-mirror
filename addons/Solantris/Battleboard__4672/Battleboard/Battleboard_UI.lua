-- Battleboard_UI.lua  (All in-game UI construction and rendering)
-- Part of Battleboard.
-- Cross-file constants and helpers are read from Battleboard.__constants (aliased _x).

local BL = Battleboard
local _x = BL.__constants

local LMM = _x.LMM
local BG_ICON = _x.BG_ICON
local MENU_ICON = _x.MENU_ICON
local MENU_ICON_DOWN = _x.MENU_ICON_DOWN
local MENU_ICON_OVER = _x.MENU_ICON_OVER
local BLANK_ICON = _x.BLANK_ICON
local SORT_ICON_UP = _x.SORT_ICON_UP
local SORT_ICON_DOWN = _x.SORT_ICON_DOWN
local ALL_CHARACTERS_KEY = _x.ALL_CHARACTERS_KEY
local MAX_SCOREBOARD_PLAYERS = _x.MAX_SCOREBOARD_PLAYERS
local classIcons = _x.classIcons
local allianceNames = _x.allianceNames
local allianceColours = _x.allianceColours
local GetPlayerTableTeamIcon = _x.GetPlayerTableTeamIcon
local GetOutcomeBannerResultIcon = _x.GetOutcomeBannerResultIcon
local Num = _x.Num
local FormatMatchId = _x.FormatMatchId
local FormatBigNumber = _x.FormatBigNumber
local FormatTimestamp = _x.FormatTimestamp
local Score = _x.Score
local GetPlayerResultText = _x.GetPlayerResultText
local GetPlayerResultDisplayText = _x.GetPlayerResultDisplayText
local NormalizePlayerName = _x.NormalizePlayerName
local MakeCharacterKey = _x.MakeCharacterKey
local GetCurrentCharacterIdOrNil = _x.GetCurrentCharacterIdOrNil
local GetCurrentCharacterName = _x.GetCurrentCharacterName
local GetMatchCharacterName = _x.GetMatchCharacterName
local GetMatchCharacterId = _x.GetMatchCharacterId
local GetMatchCharacterKey = _x.GetMatchCharacterKey
local GetSelectedCharacterKey = _x.GetSelectedCharacterKey
local GetSelectedCharacterName = _x.GetSelectedCharacterName
local GetMatchLocalClassId = _x.GetMatchLocalClassId
local MatchPassesSelectedCharacter = _x.MatchPassesSelectedCharacter
local GetLocalPlayerForMatch = _x.GetLocalPlayerForMatch
local MatchPassesHistoryFilter = _x.MatchPassesHistoryFilter
local GetDisplayMatchNumber = _x.GetDisplayMatchNumber
local GetCompactGameTypeName = _x.GetCompactGameTypeName
local GetTeamSizeFilterLabel = _x.GetTeamSizeFilterLabel
local NormalizeTeamSizeFilter = _x.NormalizeTeamSizeFilter
local encounterClassOrder = _x.encounterClassOrder
local GetAllianceDisplayName = _x.GetAllianceDisplayName
local CreateLabel = _x.CreateLabel
local CreateBackdrop = _x.CreateBackdrop
local CreateSoftFill = _x.CreateSoftFill
local SetHiddenIfControl = _x.SetHiddenIfControl
local DETAIL_TABLE_WIDTH = _x.DETAIL_TABLE_WIDTH
local DETAIL_PANEL_WIDTH_TRIM = _x.DETAIL_PANEL_WIDTH_TRIM
local DETAIL_TABLE_BODY_FONT = _x.DETAIL_TABLE_BODY_FONT
local HISTORY_PANEL_WIDTH = _x.HISTORY_PANEL_WIDTH
local HISTORY_SCROLLBAR_WIDTH = _x.HISTORY_SCROLLBAR_WIDTH
local HISTORY_SCROLLBAR_GAP = _x.HISTORY_SCROLLBAR_GAP
local HISTORY_CARD_AREA_WIDTH = _x.HISTORY_CARD_AREA_WIDTH
local HISTORY_SCROLL_WIDTH = _x.HISTORY_SCROLL_WIDTH
local CONTENT_TOP = _x.CONTENT_TOP
local PAGE_ONE_FOOTER_HEIGHT = _x.PAGE_ONE_FOOTER_HEIGHT
local PAGE_ONE_PANEL_HEIGHT = _x.PAGE_ONE_PANEL_HEIGHT
local HISTORY_VIEWPORT_HEIGHT = _x.HISTORY_VIEWPORT_HEIGHT
local DETAIL_PANEL_X = _x.DETAIL_PANEL_X
local DETAIL_PANEL_WIDTH = _x.DETAIL_PANEL_WIDTH
local DETAIL_SEPARATOR_X = _x.DETAIL_SEPARATOR_X
local HISTORY_PANEL_X = _x.HISTORY_PANEL_X
local STRIP_WIDTH = _x.STRIP_WIDTH
local PAGE_ONE_BOTTOM_Y = _x.PAGE_ONE_BOTTOM_Y
local PAGE_TWO_PANEL_HEIGHT = _x.PAGE_TWO_PANEL_HEIGHT
local CONTENT_BOTTOM_Y = _x.CONTENT_BOTTOM_Y
local DATA_SUMMARY_STRIP_HEIGHT = _x.DATA_SUMMARY_STRIP_HEIGHT
local DATA_CONTRIBUTION_PANEL_HEIGHT = _x.DATA_CONTRIBUTION_PANEL_HEIGHT
local DETAIL_TABLE_COLUMN_GAP = _x.DETAIL_TABLE_COLUMN_GAP
local function BuildHistoryColumns()
    local result = {}
    local x = 0
    for index, source in ipairs(_x.columns or {}) do
        local col = {}
        for key, value in pairs(source) do
            col[key] = value
        end
        if col.key == "mvpIcon" then
            col.w = 22
        elseif col.key == "playerName" then
            col.w = col.w + 36
        elseif col.key == "kills" or col.key == "deaths" or col.key == "assists" then
            col.w = col.w - 10
        end
        col.x = x
        result[index] = col
        x = x + col.w
        if index < #_x.columns then
            x = x + (col.gap or DETAIL_TABLE_COLUMN_GAP)
        end
    end
    return result
end
local columns = BuildHistoryColumns()
local IsNumericSortKey = _x.IsNumericSortKey
local GetSelectedCharacterWinRate = _x.GetSelectedCharacterWinRate
local FormatStatTableNumber = _x.FormatStatTableNumber
local GetSelectedCharacterKD = _x.GetSelectedCharacterKD
local FormatContributionAverageValue = _x.FormatContributionAverageValue
local GetSelectedCharacterStatSummaryForAllTime = _x.GetSelectedCharacterStatSummaryForAllTime
local GetSelectedCharacterStatAveragesForAllTime = _x.GetSelectedCharacterStatAveragesForAllTime
local GetSelectedCharacterContributionAverages = _x.GetSelectedCharacterContributionAverages
local GetSelectedCharacterPersonalBests = _x.GetSelectedCharacterPersonalBests
local GetSelectedCharacterMatchCounts = _x.GetSelectedCharacterMatchCounts
local GetClassMetricForWindows = _x.GetClassMetricForWindows
local GetSelectedCharacterTimerSummary = _x.GetSelectedCharacterTimerSummary
local GetDeserterSummary = _x.GetDeserterSummary

local SCENE_CONTENT_TOP_INSET = 0
local HISTORY_MVP_ICON = "/esoui/art/collections/favorite_staronly.dds"
local HISTORY_LOCKED_ICON = "/esoui/art/tooltips/icon_lock.dds"
local MVP_RANK_ICON = "/esoui/art/ava/ava_rankicon64_general.dds"
local PLAYER_TABLE_MVP_ICON = MVP_RANK_ICON
local MVP_STAT_ICONS = {
    kills = "/esoui/art/compass/ava_murderball_neutral.dds",
    deaths = "/esoui/art/tutorial/poi_cemetary_complete.dds",
    damage = "/esoui/art/addons/gamepad/gp_mod_listing_category_combat.dds",
    healing = "/esoui/art/lfg/gamepad/lfg_roleicon_healer_down.dds",
}

local FILTER_DROPDOWN_GOLD = {1.00, 0.84, 0.28, 1}
local FILTER_DROPDOWN_HOVER = {1.00, 0.95, 0.58, 1}

local function SetComboTextStyle(control, combo)
    local textControls = {}
    if combo then
        textControls[#textControls + 1] = combo.m_selectedItemText
        textControls[#textControls + 1] = combo.selectedItemText
        if combo.SetNormalColor then combo:SetNormalColor(unpack(FILTER_DROPDOWN_GOLD)) end
        if combo.SetHighlightedColor then combo:SetHighlightedColor(unpack(FILTER_DROPDOWN_HOVER)) end
        if combo.SetSelectedColor then combo:SetSelectedColor(unpack(FILTER_DROPDOWN_GOLD)) end
        if combo.SetDisabledColor then combo:SetDisabledColor(0.55, 0.48, 0.30, 1) end
    end
    if control and control.GetNamedChild then
        textControls[#textControls + 1] = control:GetNamedChild("SelectedItemText")
        textControls[#textControls + 1] = control:GetNamedChild("Text")
    end
    for _, label in ipairs(textControls) do
        if label then
            if label.SetColor then label:SetColor(unpack(FILTER_DROPDOWN_GOLD)) end
            if label.SetFont then label:SetFont("ZoFontGameBold") end
        end
    end
end

local function StyleFilterDropdown(control, combo, name)
    if not control then return end

    if not control.battleboardGoldFrame and CreateBackdrop then
        local frame = CreateBackdrop(control, name .. "GoldFrame", 0.42, 0.92)
        frame:SetAnchorFill(control)
        frame:SetCenterColor(0.16, 0.105, 0.020, 0.72)
        frame:SetEdgeColor(1.00, 0.78, 0.22, 0.92)
        if frame.SetDrawLayer then frame:SetDrawLayer(DL_BACKGROUND) end
        if frame.SetDrawTier then frame:SetDrawTier(DT_LOW) end
        if frame.SetMouseEnabled then frame:SetMouseEnabled(false) end
        control.battleboardGoldFrame = frame
    end

    SetComboTextStyle(control, combo)
end

local function GetAlphabeticalClassOrder()
    local sorted = {}
    for i, classSpec in ipairs(encounterClassOrder or {}) do
        sorted[i] = classSpec
    end
    table.sort(sorted, function(a, b)
        return string.lower(tostring(a and a.label or "")) < string.lower(tostring(b and b.label or ""))
    end)
    return sorted
end
local SCENE_CONTENT_RIGHT_INSET = -15

local DATE_RANGE_OPTIONS = {
    { key = "Today", label = "Today" },
    { key = "7 day", label = "7 day" },
    { key = "14 day", label = "14 day" },
    { key = "30 day", label = "30 day" },
    { key = "All", label = "All time" },
}

local function GetDateRangeFilterLabel(key)
    for _, option in ipairs(DATE_RANGE_OPTIONS) do
        if option.key == key then return option.label end
    end
    return "All time"
end

local PERFORMANCE_AGGREGATE_OPTIONS = {
    { key = "Averages", label = "Averages" },
    { key = "Totals", label = "Totals" },
}

function BL.AnchorSceneWindow()
    if not BL.window then return end

    -- BattleboardXMLMain inherits ZO_RightPanelFootPrint, so ESO owns the
    -- scene's vertical placement and dimensions under the title/header row.
    -- Resizing or re-anchoring it can shift the footprint differently across
    -- UI scales, which is what caused title/content clipping.
end

function BL.SetControlTreeHidden(control, hidden)
    if control then control:SetHidden(hidden) end
end

function BL.RefreshPageTabs()
    -- Page selection lives in the standard LibMainMenu scene-group header.
end


function BL.RefreshFooterMatchesSaved()
    if BL.visibleHistoryMatches then
        BL.SetFooterMatchesCount(#BL.visibleHistoryMatches)
        return
    end

    local count = 0
    for _, match in ipairs(BL.matches or {}) do
        if MatchPassesHistoryFilter(match) then
            count = count + 1
        end
    end

    BL.SetFooterMatchesCount(count)
end

local function CountLocalMvpMatches(matches)
    local count = 0
    for _, match in ipairs(matches or {}) do
        local player = GetLocalPlayerForMatch(match)
        if player and player.isTeamMvp == true then
            count = count + 1
        end
    end
    return count
end

local function IsLocalPlayerMvpMatch(match)
    local player = GetLocalPlayerForMatch(match)
    return player ~= nil and player.isTeamMvp == true
end

local function GetLocalTeamMvpPlayer(match)
    if not match then return nil end

    local localPlayer = GetLocalPlayerForMatch(match)
    local playerAlliance = tonumber(localPlayer and localPlayer.alliance) or tonumber(match.playerAlliance) or 0
    if playerAlliance <= 0 then return nil end

    for _, player in ipairs(match.players or {}) do
        if player and tonumber(player.alliance) == playerAlliance and player.isTeamMvp == true then
            return player
        end
    end
    return nil
end

local function ApplyHistoryCardBackground(controls, selected)
    if not controls or not controls.bg then return end

    controls.bg:SetCenterColor(
        selected and 0.010 or 0.050,
        selected and 0.009 or 0.044,
        selected and 0.007 or 0.036,
        selected and 0.62 or 0.17)
end

local function CountLockedMatches(matches)
    local count = 0
    for _, match in ipairs(matches or {}) do
        if match and match.isLocked == true then
            count = count + 1
        end
    end
    return count
end

local function FormatDurationSeconds(seconds)
    seconds = math.floor(Num(seconds) + 0.5)
    if seconds <= 0 then return nil end

    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60

    if hours > 0 then
        return string.format("%dh %02dm %02ds", hours, minutes, secs)
    end
    return string.format("%dm %02ds", minutes, secs)
end

local function FormatSummaryDuration(seconds)
    seconds = tonumber(seconds)
    if seconds == nil then return "--" end
    seconds = math.floor(math.max(0, seconds) + 0.5)

    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60

    if hours > 0 then
        return string.format("%dh %02dm", hours, minutes)
    end
    return string.format("%dm %02ds", minutes, secs)
end

local function FormatRate(value)
    value = tonumber(value)
    if not value then return "--" end
    return string.format("%.1f", value)
end

local function FormatKD(value)
    value = tonumber(value)
    if not value or value < 0 then return "--" end
    return string.format("%.2f", value)
end

local function FormatMvpRawStat(value)
    value = tonumber(value)
    if not value then return "--" end
    return FormatBigNumber(math.floor(value + 0.5))
end

local function FormatPlayerNameCell(player)
    local displayName = tostring(player and player.displayName or "")
    local characterName = tostring(player and player.characterName or "")
    if displayName == "" and characterName == "" then return "" end
    if displayName == "" then return characterName end
    if characterName == "" then return displayName end
    return string.format("%s (%s)", displayName, characterName)
end

function BL.CopySelectedMatchIdToChat()
    local match = BL.GetMatch(BL.selectedMatchId)
    if not match then return end

    local text = tostring(GetDisplayMatchNumber(match) or "")
    if text == "" then return end

    if type(StartChatInput) == "function" then
        StartChatInput(text)
    elseif CHAT_SYSTEM and type(CHAT_SYSTEM.StartTextEntry) == "function" then
        CHAT_SYSTEM:StartTextEntry(text)
    else
        d("|cFFD700Battleboard|r Match ID: " .. text)
    end
end

function BL.SetActivePage(page)
    BL.activePage = page or "History"
    BL.BuildUI()

    local showData = BL.activePage == "Data"
    local showObservatory = BL.activePage == "Observatory"
    local showHistory = not showData and not showObservatory

    for _, control in ipairs(BL.historyPageControls or {}) do
        SetHiddenIfControl(control, not showHistory)
    end
    SetHiddenIfControl(BL.dataPageContainer, not showData)
    SetHiddenIfControl(BL.observatoryPageContainer, not showObservatory)

    if showData then
        -- Preserve the selected match while moving from Match History to Match Metrics,
        -- so returning to Match History in the same addon session keeps the same match selected.
        BL.RefreshDataPage()
    elseif showObservatory then
        BL.RefreshObservatoryPage()
    else
        BL.RefreshHistory(not BL.historyListBuilt or BL.historyNeedsRebuild)
        BL.RefreshHistoryScrollThumb()
        BL.RefreshDetails(BL.EnsureVisibleSelection())
    end
    if not showHistory then
        BL.HideMvpPanel()
    end

    BL.RefreshMatchTypeButtons()
    BL.RefreshPageTabs()
    BL.RefreshFooterMatchesSaved()
end

function BL.BuildUI()
    if BL.window then return end

    -- Scene content: BattleboardXMLMain is defined in Battleboard.xml and added to
    -- a ZO_HUDFadeSceneFragment, rather than creating a floating Lua window.
    local root = BattleboardXMLMain
    if not root then
        d("|cFFD700Battleboard|r failed to initialise: BattleboardXMLMain was not loaded from XML.")
        return
    end

    BL.window = root
    root:SetMouseEnabled(true)
    root:SetDrawLayer(DL_CONTROLS)
    root:SetDrawTier(DT_HIGH)
    BL.AnchorSceneWindow()
    root:SetHandler("OnEffectivelyShown", function()
        BL.AnchorSceneWindow()
    end)

    -- Filter strip: character dropdown + match type/objective filter buttons.
    BL.filterStrip = WINDOW_MANAGER:CreateControl("BattleboardFilterStrip", root, CT_CONTROL)
    BL.filterStrip:SetMouseEnabled(true)
    BL.filterStrip:SetDrawLayer(DL_CONTROLS)
    BL.filterStrip:SetDrawTier(DT_HIGH)
    BL.filterStrip:SetDimensions(STRIP_WIDTH, 36)
    BL.filterStrip:SetAnchor(TOPRIGHT, root, TOPRIGHT, SCENE_CONTENT_RIGHT_INSET, SCENE_CONTENT_TOP_INSET)

    BL.filterStripBg = CreateSoftFill(BL.filterStrip, "BattleboardFilterStripBg", 0.018, 0.016, 0.013, 0.72)
    BL.filterStripBg:SetAnchorFill(BL.filterStrip)

    -- Page selection is handled by LibMainMenu scene-group icons in the standard
    -- top-right menu position, matching SuperStar.
    BL.pageTabs = nil
    BL.pageSelectorIcons = nil
    BL.pageTabHighlights = nil
    BL.pageTabMarkers = nil
    BL.pageTitle = nil

    -- Page one, right side: match history panel containing match history cards.
    local historyPanel = WINDOW_MANAGER:CreateControl("BattleboardHistoryPanel", root, CT_CONTROL)
    historyPanel:SetDimensions(HISTORY_PANEL_WIDTH, PAGE_ONE_PANEL_HEIGHT)
    historyPanel:SetAnchor(TOPLEFT, root, TOPLEFT, HISTORY_PANEL_X + 55 + SCENE_CONTENT_RIGHT_INSET, CONTENT_TOP + SCENE_CONTENT_TOP_INSET)
    BL.historyPanel = historyPanel
    BL.matchHistoryPanel = historyPanel

    BL.historyHeader = CreateLabel(historyPanel, "BattleboardHistoryHeader", "", "ZoFontWinH2", {0.92, 0.84, 0.62, 1})
    BL.historyHeader:SetHidden(true)

    if WINDOW_MANAGER.CreateControlFromVirtual and ZO_ComboBox_ObjectFromContainer then
        BL.dateRangeDropdown = WINDOW_MANAGER:CreateControlFromVirtual("BattleboardDateRangeDropdown", BL.filterStrip, "ZO_ComboBox")
        BL.dateRangeDropdown:SetDimensions(92, 28)
        BL.dateRangeDropdown:SetAnchor(RIGHT, BL.filterStrip, RIGHT, -6, 0)
        BL.dateRangeDropdownCombo = ZO_ComboBox_ObjectFromContainer(BL.dateRangeDropdown)
        if BL.dateRangeDropdownCombo then
            BL.dateRangeDropdownCombo:SetSortsItems(false)
            for _, option in ipairs(DATE_RANGE_OPTIONS) do
                local item = BL.dateRangeDropdownCombo:CreateItemEntry(option.label, function()
                    BL.dateRangeFilter = option.key
                    BL.selectedMatchId = nil
                    BL.RefreshHistory(true)
                    BL.RefreshDetails(nil)
                    if BL.activePage == "Data" then BL.RefreshDataPage(true) elseif BL.activePage == "Observatory" then BL.RefreshObservatoryPage() end
                end)
                BL.dateRangeDropdownCombo:AddItem(item, ZO_COMBOBOX_SUPPRESS_UPDATE)
            end
            BL.dateRangeDropdownCombo:SetSelectedItem(GetDateRangeFilterLabel(BL.dateRangeFilter or "All"))
        end
        StyleFilterDropdown(BL.dateRangeDropdown, BL.dateRangeDropdownCombo, "BattleboardDateRangeDropdown")

        -- Character dropdown anchors to the LEFT edge of the strip.
        BL.characterDropdown = WINDOW_MANAGER:CreateControlFromVirtual("BattleboardCharacterDropdown", BL.filterStrip, "ZO_ComboBox")
        BL.characterDropdown:SetDimensions(150, 28)
        BL.characterDropdown:SetAnchor(LEFT, BL.filterStrip, LEFT, 6, 0)
        BL.characterDropdownCombo = ZO_ComboBox_ObjectFromContainer(BL.characterDropdown)
        if BL.characterDropdownCombo then
            BL.characterDropdownCombo:SetSortsItems(false)
        end
        StyleFilterDropdown(BL.characterDropdown, BL.characterDropdownCombo, "BattleboardCharacterDropdown")
    else
        BL.dateRangeDropdown = CreateLabel(BL.filterStrip, "BattleboardDateRangeDropdownFallback", GetDateRangeFilterLabel(BL.dateRangeFilter or "All"), "ZoFontGame", {0.80, 0.76, 0.64, 1})
        BL.dateRangeDropdown:SetDimensions(92, 24)
        BL.dateRangeDropdown:SetAnchor(RIGHT, BL.filterStrip, RIGHT, -6, 0)
        StyleFilterDropdown(BL.dateRangeDropdown, nil, "BattleboardDateRangeDropdownFallback")

        BL.characterDropdown = CreateLabel(BL.filterStrip, "BattleboardCharacterDropdownFallback", GetSelectedCharacterName(), "ZoFontGame", {0.80, 0.76, 0.64, 1})
        BL.characterDropdown:SetAnchor(LEFT, BL.filterStrip, LEFT, 6, 0)
        BL.characterDropdown:SetDimensions(150, 24)
        StyleFilterDropdown(BL.characterDropdown, nil, "BattleboardCharacterDropdownFallback")
    end

    -- Compact team-configuration filter for all supported Battleground formats.
    BL.teamSizeDropdown = nil
    BL.teamSizeDropdownCombo = nil
    if WINDOW_MANAGER.CreateControlFromVirtual and ZO_ComboBox_ObjectFromContainer then
        BL.teamSizeDropdown = WINDOW_MANAGER:CreateControlFromVirtual("BattleboardTeamSizeDropdown", BL.filterStrip, "ZO_ComboBox")
        BL.teamSizeDropdown:SetDimensions(52, 28)
        BL.teamSizeDropdown:SetAnchor(LEFT, BL.characterDropdown, RIGHT, 3, 0)
        BL.teamSizeDropdownCombo = ZO_ComboBox_ObjectFromContainer(BL.teamSizeDropdown)
        if BL.teamSizeDropdownCombo then
            BL.teamSizeDropdownCombo:SetSortsItems(false)
            local options = {
                { key = "All", label = "All" },
                { key = "4v4", label = "4v4" },
                { key = "4v4v4", label = "4v4v4" },
                { key = "8v8", label = "8v8" },
                { key = "6v6v6", label = "6v6v6" },
                { key = "9v9", label = "9v9" },
            }
            for _, option in ipairs(options) do
                local item = BL.teamSizeDropdownCombo:CreateItemEntry(option.label, function()
                    BL.teamSizeFilter = option.key
                    BL.selectedMatchId = nil
                    BL.RefreshHistory(true)
                    BL.RefreshDetails(nil)
                    if BL.activePage == "Data" then BL.RefreshDataPage() elseif BL.activePage == "Observatory" then BL.RefreshObservatoryPage() end
                            end)
                BL.teamSizeDropdownCombo:AddItem(item, ZO_COMBOBOX_SUPPRESS_UPDATE)
            end
            BL.teamSizeFilter = NormalizeTeamSizeFilter(BL.teamSizeFilter)
            BL.teamSizeDropdownCombo:SetSelectedItem(GetTeamSizeFilterLabel(BL.teamSizeFilter))
        end
        StyleFilterDropdown(BL.teamSizeDropdown, BL.teamSizeDropdownCombo, "BattleboardTeamSizeDropdown")
    else
        BL.teamSizeDropdown = CreateLabel(BL.filterStrip, "BattleboardTeamSizeDropdownFallback", "All", "ZoFontGame", {0.80, 0.76, 0.64, 1})
        BL.teamSizeDropdown:SetDimensions(52, 24)
        BL.teamSizeDropdown:SetAnchor(LEFT, BL.characterDropdown, RIGHT, 3, 0)
        StyleFilterDropdown(BL.teamSizeDropdown, nil, "BattleboardTeamSizeDropdownFallback")
    end

    -- Shared match-type filters. These are created after the character dropdown
    -- exists, and parented to the same filterStrip so they persist across pages.
    BL.matchTypeButtons = {}
    local matchTypeSpecs = {
        { key = "All", label = "All", w = 38 },
        { key = "Deathmatch", label = "Deathmatch", w = 96 },
        { key = "Objective", label = "Objective", w = 78 },
    }

    local lastMatchTypeButton = nil
    for _, spec in ipairs(matchTypeSpecs) do
        local button = WINDOW_MANAGER:CreateControl("BattleboardMatchTypeFilter" .. spec.key, BL.filterStrip, CT_BUTTON)
        button:SetDimensions(spec.w, 22)
        button:SetFont("ZoFontGameBold")
        button:SetText(spec.label)
        button:SetNormalFontColor(0.76, 0.72, 0.62, 1)
        button:SetMouseOverFontColor(1, 0.86, 0.36, 1)
        button:SetPressedFontColor(1, 0.82, 0.28, 1)

        if lastMatchTypeButton then
            button:SetAnchor(TOPLEFT, lastMatchTypeButton, TOPRIGHT, 1, 0)
        else
            button:SetAnchor(LEFT, BL.teamSizeDropdown or BL.characterDropdown, RIGHT, 4, 0)
        end

        local bg = CreateSoftFill(button, "BattleboardMatchTypeFilterBg" .. spec.key, 0.075, 0.066, 0.050, 0.48)
        bg:SetAnchorFill(button)

        button.bg = bg
        button.matchTypeKey = spec.key
        button:SetHandler("OnClicked", function()
            BL.matchTypeFilter = spec.key
            BL.historyFilter = "All"
            BL.selectedMatchId = nil
            BL.RefreshHistory(true)
            BL.RefreshDetails(nil)
            if BL.activePage == "Data" then BL.RefreshDataPage() elseif BL.activePage == "Observatory" then BL.RefreshObservatoryPage() end
            end)
        BL.matchTypeButtons[#BL.matchTypeButtons + 1] = button
        lastMatchTypeButton = button
    end

    -- Objective-mode subfilters. These live in the shared filter strip beside
    -- the main filters, but only appear when Objective is selected.
    BL.historyFilterButtons = {}
    local filterSpecs = {
        { key = "R",   label = "Capture the Relic", controlName = "BattleboardCTFFilter" },
        { key = "C",   label = "Chaosball",          controlName = "BattleboardChaosballFilter" },
        { key = "CK",  label = "Crazy King",         controlName = "BattleboardCrazyKingFilter" },
        { key = "DOM", label = "Dom",                controlName = "BattleboardDominationFilter" },
    }

    local lastFilter = nil
    for _, spec in ipairs(filterSpecs) do
        local button = WINDOW_MANAGER:CreateControl(spec.controlName, BL.filterStrip, CT_BUTTON)
        local filterWidth = 82
        if spec.key == "R" then
            filterWidth = 140
        elseif spec.key == "C" then
            filterWidth = 84
        elseif spec.key == "CK" then
            filterWidth = 92
        elseif spec.key == "DOM" then
            filterWidth = 48
        end

        button:SetDimensions(filterWidth, 22)
        button:SetFont("ZoFontGameBold")
        button:SetText(spec.label)
        button:SetNormalFontColor(0.76, 0.72, 0.62, 1)
        button:SetMouseOverFontColor(1, 0.86, 0.36, 1)
        button:SetPressedFontColor(1, 0.82, 0.28, 1)

        if lastFilter then
            button:SetAnchor(TOPLEFT, lastFilter, TOPRIGHT, 1, 0)
        else
            button:SetAnchor(LEFT, lastMatchTypeButton, RIGHT, 4, 0)
        end

        local bg = CreateSoftFill(button, "BattleboardHistoryFilterBg" .. spec.key, 0.030, 0.027, 0.022, 0.22)
        bg:SetAnchorFill(button)

        button.bg = bg
        button.filterKey = spec.key
        button:SetHandler("OnClicked", function()
            BL.matchTypeFilter = "Objective"
            BL.historyFilter = spec.key
            BL.RefreshHistory(true)
            BL.RefreshDetails(BL.EnsureVisibleSelection())
            if BL.activePage == "Data" then BL.RefreshDataPage() elseif BL.activePage == "Observatory" then BL.RefreshObservatoryPage() end
            end)

        BL.historyFilterButtons[#BL.historyFilterButtons + 1] = button
        lastFilter = button
    end

    -- Page one, left side: match details panel.
    local matchDetailsPanel = WINDOW_MANAGER:CreateControl("BattleboardMatchDetailsPanel", root, CT_CONTROL)
    matchDetailsPanel:SetDimensions(DETAIL_PANEL_WIDTH - DETAIL_PANEL_WIDTH_TRIM, PAGE_ONE_PANEL_HEIGHT)
    matchDetailsPanel:SetAnchor(TOPLEFT, root, TOPLEFT, DETAIL_PANEL_X + SCENE_CONTENT_RIGHT_INSET, CONTENT_TOP + SCENE_CONTENT_TOP_INSET)
    BL.MatchDetailsPanel = matchDetailsPanel

    local separator = WINDOW_MANAGER:CreateControl("BattleboardMatchDetailsDivider", matchDetailsPanel, CT_BACKDROP)
    BL.matchDetailsDivider = separator
    separator:SetDimensions(1, PAGE_ONE_PANEL_HEIGHT)
    separator:SetAnchor(TOPLEFT, matchDetailsPanel, TOPLEFT, DETAIL_SEPARATOR_X + 55 - DETAIL_PANEL_X, 0)
    separator:SetCenterColor(0.549019607843, 0.541176470588, 0.450980392157, 1)
    separator:SetEdgeColor(0, 0, 0, 0)

    -- Outcome banner sits above the score strip and owns the match result text.
    BL.outcomeBanner = WINDOW_MANAGER:CreateControl("BattleboardOutcomeBanner", matchDetailsPanel, CT_CONTROL)
    BL.outcomeBanner:SetDimensions(DETAIL_TABLE_WIDTH, 60)
    BL.outcomeBanner:SetAnchor(TOPLEFT, matchDetailsPanel, TOPLEFT, 0, 2)

    -- Team indicator removed - player highlight in the table now uses alliance colour.
    BL.teamIndicator = nil
    BL.teamIndicatorImage = nil
    BL.teamAllianceIndicators = {}

    BL.outcomeBannerTeamIcon = WINDOW_MANAGER:CreateControl("BattleboardOutcomeBannerTeamIcon", BL.outcomeBanner, CT_TEXTURE)
    BL.outcomeBannerTeamIcon:SetDimensions(592, 296)
    BL.outcomeBannerTeamIcon:SetAnchor(CENTER, BL.outcomeBanner, CENTER, 0, 116)
    BL.outcomeBannerTeamIcon:SetAlpha(1)
    BL.outcomeBannerTeamIcon:SetDrawLayer(DL_BACKGROUND)
    BL.outcomeBannerTeamIcon:SetDrawTier(DT_LOW)
    if BL.outcomeBannerTeamIcon.SetDrawLevel then
        BL.outcomeBannerTeamIcon:SetDrawLevel(0)
    end
    BL.outcomeBannerTeamIcon:SetHidden(true)

    -- Score strip height reduced a further 10px.
    local TEAM_BLOCK_HEIGHT = 105
    BL.matchSummaryPanel = WINDOW_MANAGER:CreateControl("BattleboardMatchSummaryPanel", matchDetailsPanel, CT_CONTROL)
    BL.matchSummaryPanel:SetDimensions(DETAIL_TABLE_WIDTH, TEAM_BLOCK_HEIGHT)
    BL.matchSummaryPanel:SetAnchor(TOPLEFT, BL.outcomeBanner, BOTTOMLEFT, 0, 17)

    -- outcomeColor was the divider below the score strip. Now that the strip sits at
    -- the bottom the footer divider plays that role, so outcomeColor is kept as a
    -- hidden no-op to avoid errors in RefreshDetails show/hide calls.
    -- outcomeColor removed: was a 2px divider at the top of the score strip
    -- that was always hidden. Removal eliminates the visual seam it caused.

    BL.detailSectionHeader = CreateLabel(matchDetailsPanel, "BattleboardDetailSectionHeader", "", "ZoFontWinH1", {1, 0.82, 0.28, 1})
    BL.detailSectionHeader:SetAnchor(TOPLEFT, matchDetailsPanel, TOPLEFT, 0, 98)
    BL.detailSectionHeader:SetDimensions(300, 30)


    BL.matchGameTypeLabel = CreateLabel(BL.outcomeBanner, "BattleboardMatchGameTypeLabel", "", "ZoFontWinH5", {0.95, 0.90, 0.76, 1})
    BL.matchGameTypeLabel:SetAnchor(TOP, BL.outcomeBanner, TOP, 0, 4)
    BL.matchGameTypeLabel:SetDimensions(DETAIL_TABLE_WIDTH, 22)
    BL.matchGameTypeLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    BL.matchGameTypeLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    BL.matchGameTypeLabel:SetDrawLayer(DL_OVERLAY)
    BL.matchGameTypeLabel:SetDrawTier(DT_HIGH)

    BL.matchOutcomeText = CreateLabel(BL.outcomeBanner, "BattleboardMatchOutcomeText", "", "ZoFontWinH1", {0.84, 0.82, 0.70, 1})
    BL.matchOutcomeText:SetAnchor(BOTTOM, BL.outcomeBanner, BOTTOM, 0, -4)
    BL.matchOutcomeText:SetDimensions(DETAIL_TABLE_WIDTH, 34)
    BL.matchOutcomeText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    BL.matchOutcomeText:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    BL.matchOutcomeText:SetDrawLayer(DL_OVERLAY)
    BL.matchOutcomeText:SetDrawTier(DT_HIGH)
    if BL.matchOutcomeText.SetScale then BL.matchOutcomeText:SetScale(1.1) end
    if BL.matchOutcomeText.SetDrawLevel then
        BL.matchOutcomeText:SetDrawLevel(100)
    end
    if BL.matchOutcomeText.SetShadowColor then
        BL.matchOutcomeText:SetShadowColor(0, 0, 0, 0)
    end
    if BL.matchOutcomeText.SetShadow then
        BL.matchOutcomeText:SetShadow(0, 0, 0, 0)
    end

    BL.selectMatchText = CreateLabel(matchDetailsPanel, "BattleboardSelectMatchText", "Select a match", "ZoFontWinH2", {0.74, 0.70, 0.60, 1})
    BL.selectMatchText:SetAnchor(CENTER, matchDetailsPanel, CENTER, 0, 0)
    BL.selectMatchText:SetDimensions(DETAIL_TABLE_WIDTH, 40)
    BL.selectMatchText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    BL.selectMatchText:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    BL.mvpPanel = WINDOW_MANAGER:CreateControl("BattleboardMVPPanel", root, CT_CONTROL)
    BL.mvpPanel:SetDimensions(512, 512)
    BL.mvpPanel:SetAnchor(TOPRIGHT, matchDetailsPanel, TOPLEFT, -15, 0)
    BL.mvpPanel:SetDrawLayer(DL_OVERLAY)
    BL.mvpPanel:SetDrawTier(DT_HIGH)
    BL.mvpPanel:SetHidden(true)

    local mvpSweetrollArt = WINDOW_MANAGER:CreateControl("BattleboardMVPPanelSweetrollArtTexture", BL.mvpPanel, CT_TEXTURE)
    mvpSweetrollArt:SetTexture("/esoui/art/crowncrates/rewards/crowncrate_cardillo_sweetroll.dds")
    mvpSweetrollArt:SetAnchorFill(BL.mvpPanel)
    mvpSweetrollArt:SetDrawLayer(DL_BACKGROUND)
    mvpSweetrollArt:SetDrawTier(DT_LOW)
    if mvpSweetrollArt.SetDrawLevel then mvpSweetrollArt:SetDrawLevel(0) end

    local mvpBg = WINDOW_MANAGER:CreateControl("BattleboardMVPPanelBg", BL.mvpPanel, CT_BACKDROP)
    mvpBg:SetDimensions(265, 472)
    mvpBg:SetAnchor(CENTER, BL.mvpPanel, CENTER, 0, 0)
    mvpBg:SetCenterColor(0, 0, 0, 0.80)
    mvpBg:SetEdgeColor(0, 0, 0, 0)
    mvpBg:SetDrawLayer(DL_BACKGROUND)
    mvpBg:SetDrawTier(DT_LOW)
    if mvpBg.SetDrawLevel then mvpBg:SetDrawLevel(10) end

    local mvpMiddle = WINDOW_MANAGER:CreateControl("BattleboardMVPPanelMiddleTexture", BL.mvpPanel, CT_TEXTURE)
    mvpMiddle:SetTexture("/esoui/art/crowncrates/crowncrate_card_bg.dds")
    mvpMiddle:SetAnchorFill(BL.mvpPanel)
    mvpMiddle:SetDrawLayer(DL_CONTROLS)
    mvpMiddle:SetDrawTier(DT_LOW)
    if mvpMiddle.SetDrawLevel then mvpMiddle:SetDrawLevel(20) end

    local mvpTop = WINDOW_MANAGER:CreateControl("BattleboardMVPPanelTopTexture", BL.mvpPanel, CT_TEXTURE)
    mvpTop:SetTexture("/esoui/art/crowncrates/crowncrate_card_frame_crafting.dds")
    mvpTop:SetAnchorFill(BL.mvpPanel)
    mvpTop:SetDrawLayer(DL_OVERLAY)
    mvpTop:SetDrawTier(DT_HIGH)
    if mvpTop.SetDrawLevel then mvpTop:SetDrawLevel(50) end

    -- "Highest Contributor" caption beneath the sweetroll, framed by two gold rules.
    local MVP_GOLD_LINE   = {0.80, 0.66, 0.30, 0.95}
    local MVP_GOLD_TEXT   = {0.98, 0.86, 0.42, 1}
    local MVP_LINE_WIDTH  = 210
    local MVP_LINE_HEIGHT = 3

    BL.mvpPanelContributorLabel = CreateLabel(BL.mvpPanel, "BattleboardMVPPanelContributorLabel", "Highest Contributor", "ZoFontWinH2", MVP_GOLD_TEXT)
    BL.mvpPanelContributorLabel:SetDimensions(280, 38)
    BL.mvpPanelContributorLabel:SetAnchor(TOP, BL.mvpPanel, TOP, 0, 129)
    BL.mvpPanelContributorLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    BL.mvpPanelContributorLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    BL.mvpPanelContributorLabel:SetDrawLayer(DL_OVERLAY)
    BL.mvpPanelContributorLabel:SetDrawTier(DT_HIGH)
    if BL.mvpPanelContributorLabel.SetDrawLevel then BL.mvpPanelContributorLabel:SetDrawLevel(100) end

    BL.mvpPanelContributorLineBottom = WINDOW_MANAGER:CreateControl("BattleboardMVPPanelContributorLineBottom", BL.mvpPanel, CT_BACKDROP)
    BL.mvpPanelContributorLineBottom:SetDimensions(MVP_LINE_WIDTH, MVP_LINE_HEIGHT)
    BL.mvpPanelContributorLineBottom:SetAnchor(TOP, BL.mvpPanelContributorLabel, BOTTOM, 0, 8)
    BL.mvpPanelContributorLineBottom:SetCenterColor(unpack(MVP_GOLD_LINE))
    BL.mvpPanelContributorLineBottom:SetEdgeColor(0, 0, 0, 0)
    BL.mvpPanelContributorLineBottom:SetDrawLayer(DL_OVERLAY)
    BL.mvpPanelContributorLineBottom:SetDrawTier(DT_HIGH)
    if BL.mvpPanelContributorLineBottom.SetDrawLevel then BL.mvpPanelContributorLineBottom:SetDrawLevel(100) end

    BL.mvpPanelClassIcon = WINDOW_MANAGER:CreateControl("BattleboardMVPPanelClassIcon", BL.mvpPanel, CT_TEXTURE)
    BL.mvpPanelClassIcon:SetTexture(BLANK_ICON)
    BL.mvpPanelClassIcon:SetDimensions(82, 82)
    BL.mvpPanelClassIcon:SetAnchor(TOP, BL.mvpPanelContributorLineBottom, BOTTOM, 0, 56)
    BL.mvpPanelClassIcon:SetDrawLayer(DL_OVERLAY)
    BL.mvpPanelClassIcon:SetDrawTier(DT_HIGH)
    if BL.mvpPanelClassIcon.SetDrawLevel then BL.mvpPanelClassIcon:SetDrawLevel(100) end

    BL.mvpPanelUserId = CreateLabel(BL.mvpPanel, "BattleboardMVPPanelUserId", "", "ZoFontWinH1", {0.98, 0.86, 0.42, 1})
    BL.mvpPanelUserId:SetAnchor(TOP, BL.mvpPanelClassIcon, BOTTOM, 0, 8)
    BL.mvpPanelUserId:SetDimensions(360, 42)
    BL.mvpPanelUserId:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    BL.mvpPanelUserId:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    BL.mvpPanelUserId:SetDrawLayer(DL_OVERLAY)
    BL.mvpPanelUserId:SetDrawTier(DT_HIGH)
    if BL.mvpPanelUserId.SetDrawLevel then BL.mvpPanelUserId:SetDrawLevel(100) end

    BL.mvpPanelContributionStats = {}
    local MVP_STAT_ICON_SIZE = 40
    local MVP_STAT_VALUE_W = 98
    local MVP_STAT_VALUE_H = 34
    local MVP_STAT_ROW_Y = { -86, -50 }
    local MVP_STAT_COL_X = { -112, -4 }
    local MVP_STAT_LAYOUT = {
        { key = "kills",   col = 1, row = 1 },
        { key = "deaths",  col = 1, row = 2 },
        { key = "damage",  col = 2, row = 1 },
        { key = "healing", col = 2, row = 2 },
    }
    for _, stat in ipairs(MVP_STAT_LAYOUT) do
        local icon = WINDOW_MANAGER:CreateControl("BattleboardMVPPanelContributionIcon_" .. stat.key, BL.mvpPanel, CT_TEXTURE)
        icon:SetTexture(MVP_STAT_ICONS[stat.key] or BLANK_ICON)
        icon:SetDimensions(MVP_STAT_ICON_SIZE, MVP_STAT_ICON_SIZE)
        icon:SetAnchor(BOTTOMLEFT, BL.mvpPanel, BOTTOM, MVP_STAT_COL_X[stat.col], MVP_STAT_ROW_Y[stat.row])
        icon:SetDrawLayer(DL_OVERLAY)
        icon:SetDrawTier(DT_HIGH)
        if icon.SetDrawLevel then icon:SetDrawLevel(100) end

        local value = CreateLabel(BL.mvpPanel, "BattleboardMVPPanelContributionValue_" .. stat.key, "", "ZoFontWinH3", {0.88, 0.84, 0.74, 1})
        value:SetAnchor(LEFT, icon, RIGHT, 6, 0)
        value:SetDimensions(MVP_STAT_VALUE_W, MVP_STAT_VALUE_H)
        value:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        value:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        value:SetDrawLayer(DL_OVERLAY)
        value:SetDrawTier(DT_HIGH)
        if value.SetDrawLevel then value:SetDrawLevel(100) end

        BL.mvpPanelContributionStats[stat.key] = {
            icon = icon,
            value = value,
        }
    end

    BL.mvpPanelReviewNote = CreateLabel(root, "BattleboardMVPPanelReviewNote", "(Calculation currently under review)", "ZoFontGameSmall", {0.74, 0.70, 0.60, 1})
    BL.mvpPanelReviewNote:SetAnchor(TOP, BL.mvpPanel, BOTTOM, 0, 20)
    BL.mvpPanelReviewNote:SetDimensions(300, 18)
    BL.mvpPanelReviewNote:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    BL.mvpPanelReviewNote:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    BL.mvpPanelReviewNote:SetDrawLayer(DL_OVERLAY)
    BL.mvpPanelReviewNote:SetDrawTier(DT_HIGH)
    BL.mvpPanelReviewNote:SetHidden(true)


    BL.teamSummaryBlock = WINDOW_MANAGER:CreateControl("BattleboardTeamSummaryBlock", BL.matchSummaryPanel, CT_CONTROL)
    BL.teamSummaryBlock:SetDimensions(DETAIL_TABLE_WIDTH, TEAM_BLOCK_HEIGHT)
    BL.teamSummaryBlock:SetAnchor(TOPLEFT, BL.matchSummaryPanel, TOPLEFT, 0, 0)

    local TB_PAD       = 6
    local TB_STRIPE_H  = 4
    local TB_CONTENT_H = TEAM_BLOCK_HEIGHT - TB_STRIPE_H
    local TB_BLOCK_W   = math.floor(DETAIL_TABLE_WIDTH / 3)

    local TB_TEAM_ICON_SZ = 66
    local TB_LOGO_COL_W   = 60
    local TB_TEAM_ICON_X  = TB_PAD + math.floor((TB_LOGO_COL_W - 48) / 2)
    local TB_TEAM_ICON_Y  = 10
    local TB_GROUP_LEADER_ICON = "/esoui/art/icons/mapkey/mapkey_groupleader.dds"
    local TB_GROUP_LEADER_ICON_SZ = 22
    local TB_GROUP_LEADER_ICON_X = TB_TEAM_ICON_X + math.floor((TB_TEAM_ICON_SZ - TB_GROUP_LEADER_ICON_SZ) / 2)
    local TB_GROUP_LEADER_ICON_Y = TB_TEAM_ICON_Y - 20

    local TB_SCORE_H  = 26
    local TB_SCORE_X  = TB_PAD + 10   -- 10px right
    local TB_SCORE_Y  = 58            -- pinned (orig 8 + 48 + 2); stays put as the logo moves/grows
    local TB_SCORE_W  = TB_LOGO_COL_W

    -- Stat grid: 4 columns (Kills | Deaths | Damage | Healing), each an icon row
    -- over a value row, to the right of the logo/score column.
    local TB_STAT_X0    = TB_PAD + TB_LOGO_COL_W + 6
    local TB_STAT_AREA  = TB_BLOCK_W - TB_STAT_X0 - TB_PAD
    local TB_COL_W      = math.floor(TB_STAT_AREA / 4)
    -- Stat rows shifted down so the value box bottom sits 5px above the content
    -- divider (TB_CONTENT_H). TB_VAL_ROW_Y stays icon-row + 36 to keep spacing.
    local TB_ICON_ROW_Y = 38
    local TB_VAL_ROW_Y  = TB_ICON_ROW_Y + 36
    local TB_KD_ROW_Y = 11

    local TB_NARROW_COL_W = TB_COL_W - 4
    local TB_WIDE_COL_W = TB_COL_W + 4
    local TB_COLS = {
        { key = "Kills",   statKey = "kills",   x = TB_STAT_X0,                                      w = TB_NARROW_COL_W },
        { key = "Deaths",  statKey = "deaths",  x = TB_STAT_X0 + TB_NARROW_COL_W,                    w = TB_NARROW_COL_W },
        { key = "Damage",  statKey = "damage",  x = TB_STAT_X0 + 2 * TB_NARROW_COL_W,                w = TB_WIDE_COL_W },
        { key = "Healing", statKey = "healing", x = TB_STAT_X0 + 2 * TB_NARROW_COL_W + TB_WIDE_COL_W, w = TB_WIDE_COL_W },
    }

    local TB_ICON_SZ   = 22
    local TB_ICON_DRAW = 30
    local TB_VAL_H     = 22

    local TB_ICON_PATHS = {
        Kills   = "/esoui/art/compass/ava_murderball_neutral.dds",
        Deaths  = "/esoui/art/tutorial/poi_cemetary_complete.dds",
        Damage  = "/esoui/art/addons/gamepad/gp_mod_listing_category_combat.dds",
        Healing = "/esoui/art/lfg/gamepad/lfg_roleicon_healer_down.dds",
    }

    -- Per-alliance team icon textures and score alignment.
    local TB_TEAM_ICONS = {
        [BATTLEGROUND_ALLIANCE_FIRE_DRAKES] = "/esoui/art/battlegrounds/battlegrounds_teamicon_orange_64.dds",
        [BATTLEGROUND_ALLIANCE_STORM_LORDS] = "/esoui/art/battlegrounds/battlegrounds_teamicon_purple_64.dds",
        [BATTLEGROUND_ALLIANCE_PIT_DAEMONS] = "/esoui/art/battlegrounds/battlegrounds_teamicon_green_64.dds",
    }
    local TB_SCORE_ALIGN = {
        [BATTLEGROUND_ALLIANCE_FIRE_DRAKES] = TEXT_ALIGN_CENTER,
        [BATTLEGROUND_ALLIANCE_STORM_LORDS] = TEXT_ALIGN_CENTER,
        [BATTLEGROUND_ALLIANCE_PIT_DAEMONS] = TEXT_ALIGN_CENTER,
    }

    local TB_ACCENT = {
        [BATTLEGROUND_ALLIANCE_FIRE_DRAKES] = {0.85, 0.40, 0.00, 0.90},
        [BATTLEGROUND_ALLIANCE_STORM_LORDS] = {0.50, 0.30, 0.60, 0.90},
        [BATTLEGROUND_ALLIANCE_PIT_DAEMONS] = {0.36, 0.60, 0.00, 0.90},
    }

    local TB_DISPLAY_ORDER = {
        { alliance = BATTLEGROUND_ALLIANCE_FIRE_DRAKES, xOffset = 0 },
        { alliance = BATTLEGROUND_ALLIANCE_STORM_LORDS, xOffset = TB_BLOCK_W },
        { alliance = BATTLEGROUND_ALLIANCE_PIT_DAEMONS, xOffset = TB_BLOCK_W * 2 },
    }
    BL.teamBlockDisplayOrder = TB_DISPLAY_ORDER

    BL.teamBlocks = {}

    for _, entry in ipairs(TB_DISPLAY_ORDER) do
        local allianceId = entry.alliance
        local xOff       = entry.xOffset
        local aName      = tostring(allianceId)

        -- Outer container.
        local block = WINDOW_MANAGER:CreateControl("BattleboardTeamBlock_" .. aName, BL.teamSummaryBlock, CT_CONTROL)
        block:SetDimensions(TB_BLOCK_W, TEAM_BLOCK_HEIGHT)
        block:SetAnchor(TOPLEFT, BL.teamSummaryBlock, TOPLEFT, xOff, 0)

        -- Background frame art, drawn behind everything else in the block.
        local frame = WINDOW_MANAGER:CreateControl("BattleboardTeamBlockFrame_" .. aName, block, CT_TEXTURE)
        frame:SetTexture("/esoui/art/hud/daedrichunger_meter_frame.dds")
        frame:SetTextureRotation(math.pi)   -- 180 degrees
        frame:SetDimensions(TB_BLOCK_W, math.floor(TB_BLOCK_W / 2))   -- block-wide, 256x128 (2:1) source ratio
        frame:SetAnchor(TOPLEFT, block, TOPLEFT, 2, 0)
        frame:SetDrawLayer(DL_BACKGROUND)
        frame:SetDrawTier(DT_LOW)

        -- Score: under the team logo in the left column.
        local score = CreateLabel(block, "BattleboardTeamBlockScore_" .. aName,
            "", "ZoFontWinH1", {0.92, 0.84, 0.62, 1})
        score:SetAnchor(TOPLEFT, block, TOPLEFT, TB_SCORE_X, TB_SCORE_Y)
        score:SetDimensions(TB_SCORE_W, TB_SCORE_H)
        score:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        score:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        score:SetDrawLayer(DL_CONTROLS)
        score:SetDrawTier(DT_HIGH)

        -- Team logo: top of the left column.
        local teamIcon = WINDOW_MANAGER:CreateControl("BattleboardTeamBlockTeamIcon_" .. aName, block, CT_TEXTURE)
        teamIcon:SetDimensions(TB_TEAM_ICON_SZ, TB_TEAM_ICON_SZ)
        teamIcon:SetAnchor(TOPLEFT, block, TOPLEFT, TB_TEAM_ICON_X, TB_TEAM_ICON_Y)
        teamIcon:SetTexture(TB_TEAM_ICONS[allianceId] or "")
        teamIcon:SetDrawLayer(DL_BACKGROUND)
        teamIcon:SetDrawTier(DT_MID)
        teamIcon:SetMouseEnabled(true)
        teamIcon:SetHandler("OnMouseEnter", function(ctrl)
            ZO_Tooltips_ShowTextTooltip(ctrl, BOTTOM, GetAllianceDisplayName(allianceId))
        end)
        teamIcon:SetHandler("OnMouseExit", function() ZO_Tooltips_HideTextTooltip() end)

        local leaderIcon = WINDOW_MANAGER:CreateControl("BattleboardTeamBlockGroupLeaderIcon_" .. aName, block, CT_TEXTURE)
        leaderIcon:SetTexture(TB_GROUP_LEADER_ICON)
        leaderIcon:SetDimensions(TB_GROUP_LEADER_ICON_SZ, TB_GROUP_LEADER_ICON_SZ)
        leaderIcon:SetAnchor(TOPLEFT, block, TOPLEFT, TB_GROUP_LEADER_ICON_X, TB_GROUP_LEADER_ICON_Y)
        leaderIcon:SetDrawLayer(DL_CONTROLS)
        leaderIcon:SetDrawTier(DT_HIGH)
        leaderIcon:SetHidden(true)

        local kdLabel = CreateLabel(block, "BattleboardTeamBlockKDLabel_" .. aName,
            "", "ZoFontGameSmall", {0.88, 0.86, 0.78, 1})
        kdLabel:SetAnchor(TOPLEFT, block, TOPLEFT, TB_STAT_X0, TB_KD_ROW_Y)
        kdLabel:SetDimensions(TB_STAT_AREA, 18)
        kdLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        kdLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

        -- Stat grid: 4 columns (K | D | DMG | HLG), icon row over value row.
        local iconSpill = math.floor((TB_ICON_DRAW - TB_ICON_SZ) / 2)
        local icons = {}
        local vals  = {}
        for _, col in ipairs(TB_COLS) do
            local colX   = col.x
            local iconCX = colX + math.floor((col.w - TB_ICON_SZ) / 2)

            local tex = WINDOW_MANAGER:CreateControl(
                "BattleboardTeamBlockIcon_" .. aName .. "_" .. col.key, block, CT_TEXTURE)
            tex:SetTexture(TB_ICON_PATHS[col.key])
            tex:SetDimensions(TB_ICON_DRAW, TB_ICON_DRAW)
            tex:SetAnchor(TOPLEFT, block, TOPLEFT, iconCX - iconSpill, TB_ICON_ROW_Y - iconSpill)
            tex:SetDrawLayer(DL_CONTROLS)
            tex:SetDrawTier(DT_HIGH)
            icons[col.statKey] = tex

            local val = CreateLabel(block,
                "BattleboardTeamBlockVal_" .. aName .. "_" .. col.key,
                "", "ZoFontWinH4", {0.88, 0.86, 0.78, 1})
            val:SetAnchor(TOPLEFT, block, TOPLEFT, colX, TB_VAL_ROW_Y)
            val:SetDimensions(col.w, TB_VAL_H)
            val:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            val:SetVerticalAlignment(TEXT_ALIGN_CENTER)
            vals[col.statKey] = val
        end

        -- Accent stripe.
        local stripe = WINDOW_MANAGER:CreateControl("BattleboardTeamBlockStripe_" .. aName, block, CT_BACKDROP)
        stripe:SetDimensions(TB_BLOCK_W - 4, TB_STRIPE_H)
        stripe:SetAnchor(BOTTOMLEFT, block, BOTTOMLEFT, 2, 0)
        local ac = TB_ACCENT[allianceId]
        if ac then stripe:SetCenterColor(unpack(ac)) else stripe:SetCenterColor(0,0,0,0) end
        stripe:SetEdgeColor(0, 0, 0, 0)

        -- "No data" label.
        local noData = CreateLabel(block, "BattleboardTeamBlockNoData_" .. aName,
            "", "ZoFontWinH1", {0.92, 0.84, 0.62, 1})
        noData:SetAnchor(CENTER, block, CENTER, 0, 0)
        noData:SetDimensions(TB_BLOCK_W, 40)
        noData:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        noData:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        noData:SetHidden(true)

        BL.teamBlocks[allianceId] = {
            block    = block,
            frame    = frame,
            logo     = nil,
            teamIcon = teamIcon,
            leaderIcon = leaderIcon,
            score    = score,
            kdLabel  = kdLabel,
            icons    = icons,
            vals     = vals,
            stripe   = stripe,
            noData   = noData,
        }
    end


    BL.summaryDivider = WINDOW_MANAGER:CreateControl("BattleboardSummaryDivider", BL.matchSummaryPanel, CT_BACKDROP)
    BL.summaryDivider:SetDimensions(DETAIL_TABLE_WIDTH, 1)
    BL.summaryDivider:SetAnchor(TOPLEFT, BL.matchSummaryPanel, TOPLEFT, 0, 186)
    BL.summaryDivider:SetCenterColor(0, 0, 0, 0)
    BL.summaryDivider:SetEdgeColor(0, 0, 0, 0)
    BL.summaryDivider:SetHidden(true)

    -- MatchSearch panel: backdrop container for search box + locked button.
    local HISTORY_FILTER_BAR_H = 28
    local HISTORY_FILTER_BAR_GAP = 4

    local matchSearchPanel = WINDOW_MANAGER:CreateControl("BattleboardMatchSearchPanel", historyPanel, CT_BACKDROP)
    local historyFilterBarW = STRIP_WIDTH - (HISTORY_PANEL_X + 55)
    matchSearchPanel:SetDimensions(historyFilterBarW, HISTORY_FILTER_BAR_H)
    matchSearchPanel:SetAnchor(TOPLEFT, historyPanel, TOPLEFT, 0, 0)
    matchSearchPanel:SetAnchor(TOPRIGHT, BL.filterStrip, TOPRIGHT, 0, CONTENT_TOP)
    matchSearchPanel:SetCenterColor(0, 0, 0, 0)
    matchSearchPanel:SetEdgeColor(0, 0, 0, 0)
    BL.matchSearchPanel = matchSearchPanel

    local historyFilterBar = matchSearchPanel  -- alias so the controls below parent correctly

    -- Match-ID search box.
    local searchBoxW = 112
    BL.historySearchBox = WINDOW_MANAGER:CreateControl("BattleboardHistorySearchBox", historyFilterBar, CT_EDITBOX)
    BL.historySearchBox:SetDimensions(searchBoxW, HISTORY_FILTER_BAR_H)
    BL.historySearchBox:SetAnchor(TOPLEFT, historyFilterBar, TOPLEFT, 0, 0)
    BL.historySearchBox:SetFont("ZoFontGame")
    BL.historySearchBox:SetMaxInputChars(9)
    BL.historySearchBox:SetEditEnabled(true)
    BL.historySearchBox:SetMouseEnabled(true)
    BL.historySearchBox:SetHandler("OnMouseDown", function(ctrl)
        ctrl:TakeFocus()
    end)
    BL.historySearchBox:SetHandler("OnTextChanged", function(ctrl)
        local raw = ctrl:GetText() or ""
        local clean = raw:gsub("[^%d%-]", "")
        if clean ~= raw then ctrl:SetText(clean) end
        BL.historySearchFilter = clean  -- store as string for prefix matching
        BL.RefreshHistory(true)
    end)
    -- Placeholder hint label behind the edit box.
    local searchHint = CreateLabel(historyFilterBar, "BattleboardHistorySearchHint", "ID Search...", "ZoFontGame", {0.55, 0.52, 0.44, 1})
    searchHint:SetAnchor(TOPLEFT, BL.historySearchBox, TOPLEFT, 4, 0)
    searchHint:SetDimensions(searchBoxW, HISTORY_FILTER_BAR_H)
    searchHint:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    searchHint:SetMouseEnabled(false)
    BL.historySearchHint = searchHint
    BL.historySearchBox:SetHandler("OnFocusGained", function() searchHint:SetHidden(true) end)
    BL.historySearchBox:SetHandler("OnFocusLost", function()
        searchHint:SetHidden((BL.historySearchBox:GetText() or "") ~= "")
    end)

    -- Locked and MVP filters - styled identically to the match-type filter buttons.
    local LOCKED_BTN_W = 28
    local MVP_BTN_W = 28
    local FILTER_BTN_GAP = 4
    BL.historyLockedButton = WINDOW_MANAGER:CreateControl("BattleboardHistoryLockedButton", historyFilterBar, CT_BUTTON)
    BL.historyLockedButton:SetDimensions(LOCKED_BTN_W, 22)
    BL.historyLockedButton:SetAnchor(RIGHT, historyFilterBar, RIGHT, -(MVP_BTN_W + FILTER_BTN_GAP), 0)
    local lockedBg = CreateSoftFill(BL.historyLockedButton, "BattleboardHistoryLockedButtonBg", 0.030, 0.027, 0.022, 0.22)
    lockedBg:SetAnchorFill(BL.historyLockedButton)
    BL.historyLockedButton.bg = lockedBg
    local lockedIcon = WINDOW_MANAGER:CreateControl("BattleboardHistoryLockedButtonIcon", BL.historyLockedButton, CT_TEXTURE)
    lockedIcon:SetTexture(HISTORY_LOCKED_ICON)
    lockedIcon:SetDimensions(17, 17)
    lockedIcon:SetAnchor(CENTER, BL.historyLockedButton, CENTER, 0, 0)
    lockedIcon:SetColor(0.76, 0.72, 0.62, 1)
    BL.historyLockedButton.icon = lockedIcon
    BL.historyLockedButton:SetHandler("OnClicked", function()
        BL.historyLockedFilter = not BL.historyLockedFilter
        BL.RefreshHistory(true)
    end)
    BL.historyLockedButton:SetHandler("OnMouseEnter", function()
        if BL.historyLockedButton.bg then
            BL.historyLockedButton.bg:SetCenterColor(0.08, 0.064, 0.030, 0.48)
        end
        if BL.historyLockedButton.icon then
            BL.historyLockedButton.icon:SetColor(1, 0.86, 0.36, 1)
        end
    end)
    BL.historyLockedButton:SetHandler("OnMouseExit", function()
        if BL.historyLockedFilter then
            if BL.historyLockedButton.bg then
                BL.historyLockedButton.bg:SetCenterColor(0.08, 0.064, 0.030, 0.56)
            end
            if BL.historyLockedButton.icon then
                BL.historyLockedButton.icon:SetColor(1, 0.82, 0.28, 1)
            end
        else
            if BL.historyLockedButton.bg then
                BL.historyLockedButton.bg:SetCenterColor(0.030, 0.027, 0.022, 0.22)
            end
            if BL.historyLockedButton.icon then
                BL.historyLockedButton.icon:SetColor(0.76, 0.72, 0.62, 1)
            end
        end
    end)

    BL.historyMvpButton = WINDOW_MANAGER:CreateControl("BattleboardHistoryMvpButton", historyFilterBar, CT_BUTTON)
    BL.historyMvpButton:SetDimensions(MVP_BTN_W, 22)
    BL.historyMvpButton:SetAnchor(RIGHT, historyFilterBar, RIGHT, 0, 0)
    local mvpBg = CreateSoftFill(BL.historyMvpButton, "BattleboardHistoryMvpButtonBg", 0.030, 0.027, 0.022, 0.22)
    mvpBg:SetAnchorFill(BL.historyMvpButton)
    BL.historyMvpButton.bg = mvpBg
    local mvpIcon = WINDOW_MANAGER:CreateControl("BattleboardHistoryMvpButtonIcon", BL.historyMvpButton, CT_TEXTURE)
    mvpIcon:SetTexture(MVP_RANK_ICON)
    mvpIcon:SetDimensions(21, 21)
    mvpIcon:SetAnchor(CENTER, BL.historyMvpButton, CENTER, 0, 0)
    BL.historyMvpButton.icon = mvpIcon
    BL.historyMvpButton:SetHandler("OnClicked", function()
        BL.historyMvpFilter = not BL.historyMvpFilter
        BL.RefreshHistory(true)
    end)
    BL.historyMvpButton:SetHandler("OnMouseEnter", function()
        if BL.historyMvpButton.bg then
            BL.historyMvpButton.bg:SetCenterColor(0.08, 0.064, 0.030, 0.48)
        end
        if BL.historyMvpButton.icon then
            BL.historyMvpButton.icon:SetColor(1, 0.86, 0.36, 1)
        end
    end)
    BL.historyMvpButton:SetHandler("OnMouseExit", function()
        if BL.historyMvpFilter then
            if BL.historyMvpButton.bg then
                BL.historyMvpButton.bg:SetCenterColor(0.08, 0.064, 0.030, 0.56)
            end
            if BL.historyMvpButton.icon then
                BL.historyMvpButton.icon:SetColor(1, 0.82, 0.28, 1)
            end
        else
            if BL.historyMvpButton.bg then
                BL.historyMvpButton.bg:SetCenterColor(0.030, 0.027, 0.022, 0.22)
            end
            if BL.historyMvpButton.icon then
                BL.historyMvpButton.icon:SetColor(0.76, 0.72, 0.62, 1)
            end
        end
    end)

    -- Scrollable match-history card list. The CT_SCROLL viewport clips the long
    -- card stack while historyContainer remains the scroll child that receives
    -- all dynamically-created match cards.
    -- Shift the scroll area down to clear the MatchSearch panel.
    local historyScrollOffsetY = HISTORY_FILTER_BAR_H + HISTORY_FILTER_BAR_GAP
    BL.historyScrollOffsetY = historyScrollOffsetY   -- stored so RefreshHistory uses correct offset
    local historyViewportHeightAdjusted = HISTORY_VIEWPORT_HEIGHT - historyScrollOffsetY
    BL.historyScroll = WINDOW_MANAGER:CreateControl("BattleboardHistoryScroll", historyPanel, CT_SCROLL)
    BL.historyScroll:SetAnchor(TOPLEFT, historyPanel, TOPLEFT, 0, historyScrollOffsetY)
    BL.historyScroll:SetDimensions(HISTORY_SCROLL_WIDTH, historyViewportHeightAdjusted)
    BL.historyScroll:SetMouseEnabled(true)
    BL.historyScroll:SetHandler("OnMouseUp", function() BL.StopHistoryThumbDrag() end)

    BL.historyContainer = WINDOW_MANAGER:CreateControl("BattleboardHistoryContainer", BL.historyScroll, CT_CONTROL)
    BL.historyContainer:SetAnchor(TOPLEFT, BL.historyScroll, TOPLEFT, 0, 0)
    BL.historyContainer:SetDimensions(HISTORY_CARD_AREA_WIDTH or HISTORY_PANEL_WIDTH, HISTORY_VIEWPORT_HEIGHT)

    -- Visual-only scroll indicator for the virtualized match-history list.
    -- Mouse-wheel behavior remains on the historyScroll control.
    BL.historyScrollTrack = WINDOW_MANAGER:CreateControl("BattleboardHistoryScrollTrack", historyPanel, CT_BACKDROP)
    BL.historyScrollTrack:SetDimensions(HISTORY_SCROLLBAR_WIDTH or 12, historyViewportHeightAdjusted)
    BL.historyScrollTrack:SetAnchor(TOPLEFT, BL.historyScroll, TOPRIGHT, HISTORY_SCROLLBAR_GAP, 0)
    BL.historyScrollTrack:SetCenterColor(0.55, 0.55, 0.55, 0.10)
    BL.historyScrollTrack:SetEdgeColor(0, 0, 0, 0)
    BL.historyScrollTrack:SetMouseEnabled(true)
    BL.historyScrollTrack:SetDrawLayer(DL_CONTROLS)
    BL.historyScrollTrack:SetDrawTier(DT_HIGH)
    BL.historyScrollTrack:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            BL.JumpHistoryThumbToMouse()
            BL.StartHistoryThumbDrag(true)
        end
    end)
    BL.historyScrollTrack:SetHandler("OnMouseUp", function() BL.StopHistoryThumbDrag() end)
    BL.historyScrollTrack:SetHandler("OnMouseExit", function() end)

    BL.historyScrollThumb = WINDOW_MANAGER:CreateControl("BattleboardHistoryScrollThumb", BL.historyScrollTrack, CT_BACKDROP)
    BL.historyScrollThumb:SetDimensions(HISTORY_SCROLLBAR_WIDTH or 12, 40)
    BL.historyScrollThumb:SetAnchor(TOP, BL.historyScrollTrack, TOP, 0, 0)
    BL.historyScrollThumb:SetCenterColor(0.92, 0.84, 0.62, 0.58)
    BL.historyScrollThumb:SetEdgeColor(0, 0, 0, 0)
    BL.historyScrollHitbox = WINDOW_MANAGER:CreateControl("BattleboardHistoryScrollHitbox", historyPanel, CT_CONTROL)
    BL.historyScrollHitbox:SetDimensions((HISTORY_SCROLLBAR_WIDTH or 12) + 10, historyViewportHeightAdjusted)
    BL.historyScrollHitbox:SetAnchor(TOPLEFT, BL.historyScrollTrack, TOPLEFT, -5, 0)
    BL.historyScrollHitbox:SetMouseEnabled(true)
    BL.historyScrollHitbox:SetDrawLayer(DL_CONTROLS)
    BL.historyScrollHitbox:SetDrawTier(DT_HIGH)
    BL.historyScrollHitbox:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            BL.JumpHistoryThumbToMouse()
            BL.StartHistoryThumbDrag(true)
        end
    end)
    BL.historyScrollHitbox:SetHandler("OnMouseUp", function() BL.StopHistoryThumbDrag() end)

    BL.historyScrollThumb:SetMouseEnabled(true)
    BL.historyScrollThumb:SetDrawLayer(DL_CONTROLS)
    BL.historyScrollThumb:SetDrawTier(DT_HIGH)
    BL.historyScrollThumb:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then BL.StartHistoryThumbDrag(false) end
    end)
    BL.historyScrollThumb:SetHandler("OnMouseUp", function() BL.StopHistoryThumbDrag() end)
    BL.historyScrollThumb:SetHandler("OnMouseExit", function() end)

    if BL.historyScroll.SetScrollChild then
        BL.historyScroll:SetScrollChild(BL.historyContainer)
    end

    BL.historyScroll:SetHandler("OnMouseWheel", function(control, delta)
        local step = math.max(1, math.floor(Num(BL.historyMouseWheelStep or 3)))
        local current = Num(BL.historyFirstVisibleIndex or BL.historyScrollIndex or 1)
        BL.SetHistoryFirstVisibleIndex(current - (Num(delta) * step))
    end)

    -- Player table sits below the score strip.
    -- outcomeBanner bottom = y66, strip = +9+112 = 187, table starts at 191.
    -- Footer top in panel = 650. Height = 650-191-2 = 457px.
    BL.playerTable = WINDOW_MANAGER:CreateControl("BattleboardPlayerTable", matchDetailsPanel, CT_CONTROL)
    BL.playerTable:SetAnchor(TOPLEFT, BL.matchSummaryPanel, BOTTOMLEFT, 0, 4)
    BL.playerTable:SetDimensions(DETAIL_TABLE_WIDTH, 457)
    BL.playerTable:SetMouseEnabled(true)
    BL.playerTable:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT and BL.selectedPlayerRowKey then
            BL.selectedPlayerRowKey = nil
            if BL.selectedMatchId then
                BL.RefreshDetails(BL.GetMatch(BL.selectedMatchId))
            end
        end
    end)

    -- Permanent player table controls - created once here, populated by
    -- RefreshDetails. No controls are ever created at match-selection time.
    -- Unused row slots are hidden. The tighter spacing keeps all 18 players and
    -- the contribution row inside the existing fixed-height details panel.
    local MAX_PLAYER_ROWS = MAX_SCOREBOARD_PLAYERS
    local HEADER_H        = 30
    local uiScale         = (GetUIGlobalScale and GetUIGlobalScale()) or 1
    if uiScale <= 0 then uiScale = 1 end
    local function AlignToPhysicalPixel(value)
        return math.floor(value * uiScale + 0.5) / uiScale
    end
    local ROW_H           = AlignToPhysicalPixel(20)
    local ROW_GAP         = 1 / uiScale
    local ROW_STRIDE      = ROW_H + ROW_GAP
    local HEADER_ICON_H   = 28

    BL.ptControls = {}   -- permanent player table control references

    -- Header background.
    local ptHeaderBg = WINDOW_MANAGER:CreateControl("BattleboardPTHeaderBg", BL.playerTable, CT_BACKDROP)
    ptHeaderBg:SetDimensions(DETAIL_TABLE_WIDTH, HEADER_H)
    ptHeaderBg:SetAnchor(TOPLEFT, BL.playerTable, TOPLEFT, 0, 0)
    ptHeaderBg:SetCenterColor(0.010, 0.009, 0.007, 0.86)
    ptHeaderBg:SetEdgeColor(0, 0, 0, 0)
    BL.ptControls.headerBg = ptHeaderBg

    -- Underline divider beneath the header row, matching Performance/Encounter panel style.
    local ptHeaderUnderline = WINDOW_MANAGER:CreateControl("BattleboardPTHeaderUnderline", BL.playerTable, CT_BACKDROP)
    ptHeaderUnderline:SetDimensions(DETAIL_TABLE_WIDTH, 2)
    ptHeaderUnderline:SetAnchor(TOPLEFT, BL.playerTable, TOPLEFT, 0, HEADER_H - 2)
    ptHeaderUnderline:SetCenterColor(0.549019607843, 0.541176470588, 0.450980392157, 1)
    ptHeaderUnderline:SetEdgeColor(0, 0, 0, 0)
    ptHeaderUnderline:SetDrawLayer(DL_CONTROLS)
    ptHeaderUnderline:SetDrawTier(DT_HIGH)

    -- Column headers and iconHeader textures.
    BL.ptControls.headers     = {}
    BL.ptControls.headerIcons = {}
    for _, col in ipairs(columns) do
        local hdr = CreateLabel(BL.playerTable, "BattleboardPTHeader_" .. col.key,
            col.text, "ZoFontWinH4", {0.80, 0.76, 0.66, 1})
        hdr:SetAnchor(TOPLEFT, BL.playerTable, TOPLEFT, col.x, 4)
        hdr:SetDimensions(col.w, HEADER_H - 4)
        hdr:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        if col.align then hdr:SetHorizontalAlignment(col.align) end
        if col.sortable then
            hdr:SetMouseEnabled(true)
            hdr:SetHandler("OnMouseEnter", function() hdr:SetColor(1, 0.92, 0.52, 1) end)
            hdr:SetHandler("OnMouseExit",  function() hdr:SetColor(unpack(BL.ptControls.headers[col.key]._normalColor)) end)
            hdr:SetHandler("OnMouseUp", function(_, button, upInside)
                if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
                    BL.SortDetails(BL.selectedMatchId, col.key)
                end
            end)
        end
        -- Store the default colour so RefreshDetails can restore it on sort change.
        hdr._normalColor = {0.80, 0.76, 0.66, 1}
        BL.ptControls.headers[col.key] = hdr

        if col.kind == "iconHeader" and col.iconPath then
            local iconX = col.x + math.floor((col.w - HEADER_ICON_H) / 2)
            local iconY = math.floor((HEADER_H - HEADER_ICON_H) / 2)
            local tex = WINDOW_MANAGER:CreateControl("BattleboardPTHeaderIcon_" .. col.key, BL.playerTable, CT_TEXTURE)
            tex:SetTexture(col.iconPath)
            tex:SetDimensions(HEADER_ICON_H, HEADER_ICON_H)
            tex:SetAnchor(TOPLEFT, BL.playerTable, TOPLEFT, iconX, iconY)
            tex:SetDrawLayer(DL_CONTROLS)
            tex:SetDrawTier(DT_HIGH)
            tex:SetMouseEnabled(false)
            BL.ptControls.headerIcons[col.key] = tex
        end
    end

    -- Single shared sort icon - repositioned by RefreshDetails.
    local ptSortIcon = WINDOW_MANAGER:CreateControl("BattleboardPTSortIcon", BL.playerTable, CT_TEXTURE)
    ptSortIcon:SetDimensions(12, 12)
    ptSortIcon:SetAnchor(TOPLEFT, BL.playerTable, TOPLEFT, 0, 15)
    ptSortIcon:SetMouseEnabled(false)
    ptSortIcon:SetHidden(true)
    BL.ptControls.sortIcon = ptSortIcon

    -- Permanent player row slots.
    BL.ptControls.rows = {}
    local mvpColumn = nil
    local teamColumn = nil
    local classColumn = nil
    for _, col in ipairs(columns) do
        if col.key == "mvpIcon" then
            mvpColumn = col
        elseif col.key == "teamIcon" then
            teamColumn = col
        elseif col.key == "classId" then
            classColumn = col
        end
    end
    local firstRowY = AlignToPhysicalPixel(HEADER_H + 8)
    local previousRowBg = nil
    for i = 1, MAX_PLAYER_ROWS do
        local bg = WINDOW_MANAGER:CreateControl("BattleboardPTRowBg_" .. i, BL.playerTable, CT_BACKDROP)
        bg:SetDimensions(DETAIL_TABLE_WIDTH, ROW_H)
        if previousRowBg then
            -- ROW_GAP is one physical screen pixel, even when ESO uses a
            -- fractional custom UI scale such as 1.10.
            bg:SetAnchor(TOPLEFT, previousRowBg, BOTTOMLEFT, 0, ROW_GAP)
        else
            bg:SetAnchor(TOPLEFT, BL.playerTable, TOPLEFT, 0, firstRowY)
        end
        bg:SetCenterColor(0, 0, 0, 0)
        bg:SetEdgeColor(0, 0, 0, 0)
        bg:SetHidden(true)
        previousRowBg = bg

        local teamTex = WINDOW_MANAGER:CreateControl("BattleboardPTRowTeam_" .. i, BL.playerTable, CT_TEXTURE)
        local teamIconSize = 22
        teamTex:SetDimensions(teamIconSize, teamIconSize)
        if teamColumn then
            teamTex:SetAnchor(LEFT, bg, LEFT, teamColumn.x + math.floor((teamColumn.w - teamIconSize) / 2), 0)
        else
            teamTex:SetAnchor(LEFT, bg, LEFT, 4, 0)
        end
        teamTex:SetHidden(true)

        local winnerTex = WINDOW_MANAGER:CreateControl("BattleboardPTRowWinner_" .. i, BL.playerTable, CT_TEXTURE)
        local winnerSize = 22
        winnerTex:SetTexture(PLAYER_TABLE_MVP_ICON)
        winnerTex:SetDimensions(winnerSize, winnerSize)
        if mvpColumn then
            winnerTex:SetAnchor(LEFT, bg, LEFT, mvpColumn.x + math.floor((mvpColumn.w - winnerSize) / 2), 0)
        else
            winnerTex:SetAnchor(CENTER, teamTex, CENTER, 0, 0)
        end
        winnerTex:SetDrawLayer(DL_CONTROLS)
        winnerTex:SetDrawTier(DT_HIGH)
        winnerTex:SetMouseEnabled(true)
        winnerTex:SetHidden(true)

        local classTex = WINDOW_MANAGER:CreateControl("BattleboardPTRowClass_" .. i, BL.playerTable, CT_TEXTURE)
        local classIconSize = 20
        classTex:SetDimensions(classIconSize, classIconSize)
        if classColumn then
            classTex:SetAnchor(LEFT, bg, LEFT, classColumn.x + math.floor((classColumn.w - classIconSize) / 2), 0)
        else
            classTex:SetAnchor(LEFT, bg, LEFT, 36, 0)
        end
        classTex:SetHidden(true)

        local cells = {}
        for _, col in ipairs(columns) do
            if not col.skipCell then
                local cell = CreateLabel(BL.playerTable, "BattleboardPTCell_" .. i .. "_" .. col.key,
                    "", DETAIL_TABLE_BODY_FONT, {0.88, 0.86, 0.78, 0.96})
                cell:SetAnchor(TOPLEFT, bg, TOPLEFT, col.x, 0)
                cell:SetDimensions(col.w, 17)
                if col.align then cell:SetHorizontalAlignment(col.align) end
                cell:SetHidden(true)
                cells[col.key] = cell
            end
        end

        BL.ptControls.rows[i] = { bg = bg, teamTex = teamTex, winnerTex = winnerTex, classTex = classTex, cells = cells }
    end

    -- Permanent contribution row (shown only when match.playerContribution exists).
    local contribY = HEADER_H + MAX_PLAYER_ROWS * ROW_STRIDE + 8 + 10
    local ptContribBorder = WINDOW_MANAGER:CreateControl("BattleboardPTContribBorder", BL.playerTable, CT_BACKDROP)
    ptContribBorder:SetDimensions(DETAIL_TABLE_WIDTH, 2)
    ptContribBorder:SetAnchor(TOPLEFT, BL.playerTable, TOPLEFT, 0, contribY - 6)
    ptContribBorder:SetCenterColor(0.549019607843, 0.541176470588, 0.450980392157, 1)
    ptContribBorder:SetEdgeColor(0, 0, 0, 0)
    ptContribBorder:SetHidden(true)

    local ptContribBg = WINDOW_MANAGER:CreateControl("BattleboardPTContribBg", BL.playerTable, CT_BACKDROP)
    ptContribBg:SetDimensions(DETAIL_TABLE_WIDTH, ROW_H)
    ptContribBg:SetAnchor(TOPLEFT, BL.playerTable, TOPLEFT, 0, contribY)
    ptContribBg:SetCenterColor(0, 0, 0, 0)
    ptContribBg:SetEdgeColor(0, 0, 0, 0)
    ptContribBg:SetHidden(true)

    local ptContribCells = {}
    for _, col in ipairs(columns) do
        if not col.skipCell then
            local align = col.key == "playerName" and TEXT_ALIGN_RIGHT or col.align
            local cell = CreateLabel(BL.playerTable, "BattleboardPTContrib_" .. col.key,
                "", DETAIL_TABLE_BODY_FONT, {0.92, 0.84, 0.62, 1})
            cell:SetAnchor(TOPLEFT, BL.playerTable, TOPLEFT, col.x, contribY)
            cell:SetDimensions(col.w, 17)
            if align then cell:SetHorizontalAlignment(align) end
            cell:SetHidden(true)
            ptContribCells[col.key] = cell
        end
    end

    BL.ptControls.contrib = {
        border = ptContribBorder,
        bg     = ptContribBg,
        cells  = ptContribCells,
    }


    -- ESO inventory-inspired bottom well spanning both Page 1 panels. It gives
    -- the lower edge of the history/details layout a shared visual footing.
    BL.pageOneFooter = WINDOW_MANAGER:CreateControl("BattleboardPageOneFooter", root, CT_CONTROL)
    BL.pageOneFooter:SetDimensions(STRIP_WIDTH, PAGE_ONE_FOOTER_HEIGHT)
    -- Footer follows the History content height instead of the global page bottom.
    BL.pageOneFooter:SetAnchor(TOPRIGHT, root, TOPRIGHT, SCENE_CONTENT_RIGHT_INSET, PAGE_ONE_BOTTOM_Y + SCENE_CONTENT_TOP_INSET)
    BL.pageOneFooterBg = CreateSoftFill(BL.pageOneFooter, "BattleboardPageOneFooterBg", 0, 0, 0, 0)
    BL.pageOneFooterBg:SetAnchorFill(BL.pageOneFooter)

    BL.footerDivider = WINDOW_MANAGER:CreateControl("BattleboardFooterDivider", BL.pageOneFooter, CT_BACKDROP)
    BL.footerDivider:SetDimensions(STRIP_WIDTH, 1)
    BL.footerDivider:SetAnchor(TOPLEFT, BL.pageOneFooter, TOPLEFT, 0, 0)
    BL.footerDivider:SetCenterColor(0.72, 0.72, 0.72, 0.14)
    BL.footerDivider:SetEdgeColor(0, 0, 0, 0)

    -- Game metadata: match date + match Id.
    BL.matchMetadata = CreateLabel(BL.pageOneFooter, "BattleboardMatchMetadata", "", "ZoFontGameSmall", {0.74, 0.70, 0.60, 1})
    BL.gameMetadataFooter = BL.matchMetadata
    BL.matchMetadata:SetAnchor(LEFT, BL.pageOneFooter, LEFT, 10, 0)
    BL.matchMetadata:SetDimensions(680, 24)
    BL.matchMetadata:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    BL.matchMetadata:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    BL.matchMetadata:SetMouseEnabled(true)
    BL.matchMetadata:SetHandler("OnMouseEnter", function(ctrl)
        if BL.selectedMatchId then
            ZO_Tooltips_ShowTextTooltip(ctrl, TOP, "Right-click to copy Match ID to chat")
        end
    end)
    BL.matchMetadata:SetHandler("OnMouseExit", function()
        ZO_Tooltips_HideTextTooltip()
    end)
    BL.matchMetadata:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_RIGHT then
            BL.CopySelectedMatchIdToChat()
        end
    end)

    BL.footerMatchesSaved = CreateLabel(BL.pageOneFooter, "BattleboardFooterMatchesSaved", "", "ZoFontGameSmall", {0.74, 0.70, 0.60, 1})
    BL.footerMatchesSaved:SetAnchor(RIGHT, BL.pageOneFooter, RIGHT, -10, 0)
    BL.footerMatchesSaved:SetDimensions(320, 28)
    BL.footerMatchesSaved:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    BL.footerMatchesSaved:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    BL.footerMatchesSaved:SetHidden(false)
    BL.footerLockedLabel = nil  -- merged into footerMatchesSaved

    BL.footerCountControls = {}
    local function CreateFooterCountDivider(name, rightAnchor)
        local divider = CreateLabel(BL.pageOneFooter, name, string.char(226, 128, 162), "ZoFontGameSmall", {0.54, 0.50, 0.40, 0.85})
        divider:SetDimensions(14, 24)
        divider:SetAnchor(RIGHT, rightAnchor, LEFT, -6, 0)
        divider:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        divider:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        return divider
    end

    local matchesValue = CreateLabel(BL.pageOneFooter, "BattleboardFooterMatchesValue", "0", "ZoFontGameSmall", {0.74, 0.70, 0.60, 1})
    matchesValue:SetDimensions(38, 24)
    matchesValue:SetAnchor(RIGHT, BL.pageOneFooter, RIGHT, -10, 0)
    matchesValue:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    matchesValue:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    BL.footerCountControls.matches = { value = matchesValue }

    BL.footerCountDividerMvp = CreateFooterCountDivider("BattleboardFooterCountDividerMvp", matchesValue)
    local mvpIcon = WINDOW_MANAGER:CreateControl("BattleboardFooterMvpCountIcon", BL.pageOneFooter, CT_TEXTURE)
    mvpIcon:SetTexture(MVP_RANK_ICON)
    mvpIcon:SetDimensions(20, 20)
    mvpIcon:SetMouseEnabled(false)
    local mvpValue = CreateLabel(BL.pageOneFooter, "BattleboardFooterMvpCountValue", "0", "ZoFontGameSmall", {0.74, 0.70, 0.60, 1})
    mvpValue:SetDimensions(38, 24)
    mvpValue:SetAnchor(RIGHT, BL.footerCountDividerMvp, LEFT, -6, 0)
    mvpValue:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    mvpValue:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    mvpIcon:SetAnchor(RIGHT, mvpValue, LEFT, 0, 0)
    BL.footerCountControls.mvp = { icon = mvpIcon, value = mvpValue }

    BL.footerCountDividerLocked = CreateFooterCountDivider("BattleboardFooterCountDividerLocked", mvpIcon)
    local lockedIcon = WINDOW_MANAGER:CreateControl("BattleboardFooterLockedCountIcon", BL.pageOneFooter, CT_TEXTURE)
    lockedIcon:SetTexture(HISTORY_LOCKED_ICON)
    lockedIcon:SetDimensions(16, 16)
    lockedIcon:SetMouseEnabled(false)
    local lockedValue = CreateLabel(BL.pageOneFooter, "BattleboardFooterLockedCountValue", "0", "ZoFontGameSmall", {0.74, 0.70, 0.60, 1})
    lockedValue:SetDimensions(38, 24)
    lockedValue:SetAnchor(RIGHT, BL.footerCountDividerLocked, LEFT, -6, 0)
    lockedValue:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    lockedValue:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    lockedIcon:SetAnchor(RIGHT, lockedValue, LEFT, 0, 0)
    BL.footerCountControls.locked = { icon = lockedIcon, value = lockedValue }
    matchesValue:SetHidden(true)
    BL.footerCountDividerMvp:SetHidden(true)
    mvpIcon:SetHidden(true)
    mvpValue:SetHidden(true)
    BL.footerCountDividerLocked:SetHidden(true)
    lockedIcon:SetHidden(true)
    lockedValue:SetHidden(true)

    BL.RefreshFooterMatchesSaved() -- initial footer count

    BL.dataPageContainer = WINDOW_MANAGER:CreateControl("BattleboardDataPageContainer", root, CT_CONTROL)
    BL.dataPageContainer:SetDimensions(STRIP_WIDTH, PAGE_TWO_PANEL_HEIGHT)
    BL.dataPageContainer:SetAnchor(TOPLEFT, BL.filterStrip, TOPLEFT, 0, CONTENT_TOP)
    BL.dataPageContainer:SetHidden(true)

    local dataPageWidth            = STRIP_WIDTH
    local DATA_PANEL_GAP           = 8
    local DATA_PANEL_W             = math.floor((dataPageWidth - 2 * DATA_PANEL_GAP) / 3)   -- 323
    local METRICS_SUMMARY_STRIP_HEIGHT = 122
    local DATA_PANEL_Y             = METRICS_SUMMARY_STRIP_HEIGHT + DATA_PANEL_GAP
    local DATA_TOP_PANEL_HEIGHT    = 332
    local dataContributionPanelWidth = DATA_PANEL_W
    -- dataContentX / dataContentWidth kept for any legacy references below.
    local dataContributionPanelGap = DATA_PANEL_GAP
    local dataContentX             = dataContributionPanelWidth + dataContributionPanelGap
    local dataContentWidth         = dataPageWidth - dataContentX

    -- Contribution panel: column 1 (left).
    BL.dataContributionPanel = WINDOW_MANAGER:CreateControl("BattleboardDataContributionPanel", BL.dataPageContainer, CT_CONTROL)
    BL.dataContributionPanel:SetDimensions(dataContributionPanelWidth, DATA_TOP_PANEL_HEIGHT)
    BL.dataContributionPanel:SetAnchor(TOPLEFT, BL.dataPageContainer, TOPLEFT, 0, DATA_PANEL_Y)

    BL.dataContributionPanelBg = CreateSoftFill(BL.dataContributionPanel, "BattleboardDataContributionPanelBg", 0, 0, 0, 0.50)
    BL.dataContributionPanelBg:SetAnchorFill(BL.dataContributionPanel)

    BL.dataContributionPanelBorder = {}

    local dataContributionPanelBorderTop = WINDOW_MANAGER:CreateControl("BattleboardDataContributionPanelBorderTop", BL.dataContributionPanel, CT_BACKDROP)
    dataContributionPanelBorderTop:SetAnchor(TOPLEFT, BL.dataContributionPanel, TOPLEFT, 0, 0)
    dataContributionPanelBorderTop:SetAnchor(TOPRIGHT, BL.dataContributionPanel, TOPRIGHT, 0, 0)
    dataContributionPanelBorderTop:SetHeight(1)
    dataContributionPanelBorderTop:SetCenterColor(1, 0.82, 0.28, 0.32)
    dataContributionPanelBorderTop:SetEdgeColor(0, 0, 0, 0)
    BL.dataContributionPanelBorder.Top = dataContributionPanelBorderTop

    local dataContributionPanelBorderBottom = WINDOW_MANAGER:CreateControl("BattleboardDataContributionPanelBorderBottom", BL.dataContributionPanel, CT_BACKDROP)
    dataContributionPanelBorderBottom:SetAnchor(BOTTOMLEFT, BL.dataContributionPanel, BOTTOMLEFT, 0, 0)
    dataContributionPanelBorderBottom:SetAnchor(BOTTOMRIGHT, BL.dataContributionPanel, BOTTOMRIGHT, 0, 0)
    dataContributionPanelBorderBottom:SetHeight(1)
    dataContributionPanelBorderBottom:SetCenterColor(1, 0.82, 0.28, 0.32)
    dataContributionPanelBorderBottom:SetEdgeColor(0, 0, 0, 0)
    BL.dataContributionPanelBorder.Bottom = dataContributionPanelBorderBottom

    local dataContributionPanelBorderLeft = WINDOW_MANAGER:CreateControl("BattleboardDataContributionPanelBorderLeft", BL.dataContributionPanel, CT_BACKDROP)
    dataContributionPanelBorderLeft:SetAnchor(TOPLEFT, BL.dataContributionPanel, TOPLEFT, 0, 0)
    dataContributionPanelBorderLeft:SetAnchor(BOTTOMLEFT, BL.dataContributionPanel, BOTTOMLEFT, 0, 0)
    dataContributionPanelBorderLeft:SetWidth(1)
    dataContributionPanelBorderLeft:SetCenterColor(1, 0.82, 0.28, 0.32)
    dataContributionPanelBorderLeft:SetEdgeColor(0, 0, 0, 0)
    BL.dataContributionPanelBorder.Left = dataContributionPanelBorderLeft

    local dataContributionPanelBorderRight = WINDOW_MANAGER:CreateControl("BattleboardDataContributionPanelBorderRight", BL.dataContributionPanel, CT_BACKDROP)
    dataContributionPanelBorderRight:SetAnchor(TOPRIGHT, BL.dataContributionPanel, TOPRIGHT, 0, 0)
    dataContributionPanelBorderRight:SetAnchor(BOTTOMRIGHT, BL.dataContributionPanel, BOTTOMRIGHT, 0, 0)
    dataContributionPanelBorderRight:SetWidth(1)
    dataContributionPanelBorderRight:SetCenterColor(1, 0.82, 0.28, 0.32)
    dataContributionPanelBorderRight:SetEdgeColor(0, 0, 0, 0)
    BL.dataContributionPanelBorder.Right = dataContributionPanelBorderRight

    BL.dataContributionPanelHeader = WINDOW_MANAGER:CreateControl("BattleboardDataContributionPanelHeader", BL.dataContributionPanel, CT_CONTROL)
    BL.dataContributionPanelHeader:SetDimensions(dataContributionPanelWidth - 28, 34)
    BL.dataContributionPanelHeader:SetAnchor(TOP, BL.dataContributionPanel, TOP, 0, 10)

    BL.dataContributionPanelHeaderBottomEdge = WINDOW_MANAGER:CreateControl("BattleboardDataContributionPanelHeaderBottomEdge", BL.dataContributionPanelHeader, CT_BACKDROP)
    BL.dataContributionPanelHeaderBottomEdge:SetAnchor(BOTTOMLEFT, BL.dataContributionPanelHeader, BOTTOMLEFT, 0, 0)
    BL.dataContributionPanelHeaderBottomEdge:SetAnchor(BOTTOMRIGHT, BL.dataContributionPanelHeader, BOTTOMRIGHT, 0, 0)
    BL.dataContributionPanelHeaderBottomEdge:SetHeight(2)
    BL.dataContributionPanelHeaderBottomEdge:SetCenterColor(0.549019607843, 0.541176470588, 0.450980392157, 1)
    BL.dataContributionPanelHeaderBottomEdge:SetEdgeColor(0, 0, 0, 0)

    BL.dataContributionPanelHeaderLabel = CreateLabel(BL.dataContributionPanelHeader, "BattleboardDataContributionPanelHeaderLabel", "CONTRIBUTION", "ZoFontGameBold", {0.92, 0.84, 0.62, 1})
    BL.dataContributionPanelHeaderLabel:SetAnchorFill(BL.dataContributionPanelHeader)
    BL.dataContributionPanelHeaderLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    BL.dataContributionPanelHeaderLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    local dataContributionTooltip = WINDOW_MANAGER:CreateControl("BattleboardDataContributionPanelTooltip", BL.dataContributionPanel, CT_CONTROL)
    dataContributionTooltip:SetAnchorFill(BL.dataContributionPanel)
    dataContributionTooltip:SetDrawLayer(DL_OVERLAY)
    dataContributionTooltip:SetDrawTier(DT_HIGH)
    if dataContributionTooltip.SetDrawLevel then dataContributionTooltip:SetDrawLevel(100) end
    dataContributionTooltip:SetMouseEnabled(true)
    dataContributionTooltip:SetHandler("OnMouseEnter", function(ctrl)
        ZO_Tooltips_ShowTextTooltip(ctrl, LEFT, "Average")
    end)
    dataContributionTooltip:SetHandler("OnMouseExit", function()
        ZO_Tooltips_HideTextTooltip()
    end)
    BL.dataContributionTooltip = dataContributionTooltip

    BL.dataContributionAverageLabels = {}

    local contributionSpecs = {
        { key = "kills",   label = "Kills",   icon = "/esoui/art/compass/ava_murderball_neutral.dds",                                         y = 50  },
        { key = "deaths",  label = "Deaths",  icon = "/esoui/art/tutorial/poi_cemetary_complete.dds",                                          y = 96  },
        { key = "damage",  label = "Damage",  icon = "/esoui/art/addons/gamepad/gp_mod_listing_category_combat.dds",                           y = 142 },
        { key = "healing", label = "Healing", icon = "/esoui/art/lfg/gamepad/lfg_roleicon_healer_down.dds",                                    y = 188 },
        { key = "score",   label = "Medals",  icon = "/esoui/art/notifications/gamepad/gp_notification_leaderboardaccept_down.dds",             y = 234 },
        { key = "kd",      label = "KD Ratio", icon = "/esoui/art/guild/gamepad/gp_guild_menuicon_changemessage.dds",                           y = 280 },
    }

    local contributionIconX    = 12
    local contributionLabelX   = 68    -- iconX(12) + iconSz(48) + gap(8)
    local contributionRowHeight = 46
    local contributionIconSz   = 42
    -- Narrower label column (was ending at 186) so avg column has more room and stays right-aligned.
    local contributionValueX    = 160
    local contributionRawValueX = contributionValueX + math.floor((dataContributionPanelWidth - contributionValueX - 8) / 2)

    for _, spec in ipairs(contributionSpecs) do
        local icon = WINDOW_MANAGER:CreateControl("BattleboardDataContributionAvg" .. spec.key .. "Icon", BL.dataContributionPanel, CT_TEXTURE)
        icon:SetDimensions(contributionIconSz, contributionIconSz)
        icon:SetAnchor(TOPLEFT, BL.dataContributionPanel, TOPLEFT, contributionIconX, spec.y + math.floor((contributionRowHeight - contributionIconSz) / 2))
        icon:SetTexture(spec.icon)
        icon:SetAlpha(0.88)

        local label = CreateLabel(BL.dataContributionPanel, "BattleboardDataContributionAvg" .. spec.key .. "Label", spec.label, "ZoFontGame", {0.88, 0.84, 0.72, 1})
        label:SetAnchor(TOPLEFT, BL.dataContributionPanel, TOPLEFT, contributionLabelX, spec.y)
        label:SetDimensions(contributionValueX - contributionLabelX - 8, contributionRowHeight)
        label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)

        -- Avg column - right-aligned, flush to the % column on its right
        local pctW = contributionRawValueX - contributionValueX - 4
        local rawValue = CreateLabel(BL.dataContributionPanel, "BattleboardDataContributionAvg" .. spec.key .. "RawValue", "--", "ZoFontWinH1", {0.88, 0.84, 0.72, 1})
        rawValue:SetAnchor(TOPLEFT, BL.dataContributionPanel, TOPLEFT, contributionValueX, spec.y)
        rawValue:SetDimensions(pctW, contributionRowHeight)
        rawValue:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        rawValue:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        if rawValue.SetScale then rawValue:SetScale(0.96) end   -- match the % column

        -- % contribution column - now on the RIGHT
        local rawW = dataContributionPanelWidth - contributionRawValueX - 8
        local value = CreateLabel(BL.dataContributionPanel, "BattleboardDataContributionAvg" .. spec.key .. "Value", "--", "ZoFontWinH1", {0.88, 0.84, 0.72, 1})
        value:SetAnchor(TOPLEFT, BL.dataContributionPanel, TOPLEFT, contributionRawValueX, spec.y)
        value:SetDimensions(rawW, contributionRowHeight)
        value:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        value:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        if value.SetScale then value:SetScale(0.96) end

        BL.dataContributionAverageLabels[spec.key] = { value = value, label = label, icon = icon, rawValue = rawValue }
    end

    -- Shared helper: builds a stat panel with the same visual frame as the
    -- contribution panel. Returns a table of { value, label, [subLabel] } per key.
    local function BuildStatPanel(name, title, parent, xOffset, panelHeight, specs, panelY)
        local panel = WINDOW_MANAGER:CreateControl("Battleboard" .. name .. "Panel", parent, CT_CONTROL)
        panel:SetDimensions(DATA_PANEL_W, panelHeight)
        panel:SetAnchor(TOPLEFT, parent, TOPLEFT, xOffset, panelY or DATA_PANEL_Y)

        local bg = CreateSoftFill(panel, "Battleboard" .. name .. "PanelBg", 0, 0, 0, 0.50)
        bg:SetAnchorFill(panel)

        -- Gold 1px border (4 sides).
        for _, side in ipairs({"Top","Bottom","Left","Right"}) do
            local b = WINDOW_MANAGER:CreateControl("Battleboard"..name.."PanelBorder"..side, panel, CT_BACKDROP)
            if side == "Top" then
                b:SetAnchor(TOPLEFT, panel, TOPLEFT, 0, 0)
                b:SetAnchor(TOPRIGHT, panel, TOPRIGHT, 0, 0)
                b:SetHeight(1)
            elseif side == "Bottom" then
                b:SetAnchor(BOTTOMLEFT, panel, BOTTOMLEFT, 0, 0)
                b:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, 0, 0)
                b:SetHeight(1)
            elseif side == "Left" then
                b:SetAnchor(TOPLEFT, panel, TOPLEFT, 0, 0)
                b:SetAnchor(BOTTOMLEFT, panel, BOTTOMLEFT, 0, 0)
                b:SetWidth(1)
            elseif side == "Right" then
                b:SetAnchor(TOPRIGHT, panel, TOPRIGHT, 0, 0)
                b:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, 0, 0)
                b:SetWidth(1)
            end
            b:SetCenterColor(1, 0.82, 0.28, 0.32)
            b:SetEdgeColor(0, 0, 0, 0)
        end

        -- Panel header.
        local hdr = WINDOW_MANAGER:CreateControl("Battleboard" .. name .. "PanelHeader", panel, CT_CONTROL)
        hdr:SetDimensions(DATA_PANEL_W - 28, 34)
        hdr:SetAnchor(TOP, panel, TOP, 0, 10)
        local hdrEdge = WINDOW_MANAGER:CreateControl("Battleboard"..name.."PanelHeaderEdge", hdr, CT_BACKDROP)
        hdrEdge:SetAnchor(BOTTOMLEFT, hdr, BOTTOMLEFT, 0, 0)
        hdrEdge:SetAnchor(BOTTOMRIGHT, hdr, BOTTOMRIGHT, 0, 0)
        hdrEdge:SetHeight(2)
        hdrEdge:SetCenterColor(0.549019607843, 0.541176470588, 0.450980392157, 1)
        hdrEdge:SetEdgeColor(0, 0, 0, 0)
        local hdrLabel = CreateLabel(hdr, "Battleboard"..name.."PanelHeaderLabel", title, "ZoFontGameBold", {0.92, 0.84, 0.62, 1})
        hdrLabel:SetAnchorFill(hdr)
        hdrLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        hdrLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

        -- Rows.
        local rows = {}
        for _, spec in ipairs(specs) do
            local icon = nil
            if not spec.noIcon then
                icon = WINDOW_MANAGER:CreateControl("Battleboard"..name..spec.key.."Icon", panel, CT_TEXTURE)
                icon:SetDimensions(contributionIconSz, contributionIconSz)
                icon:SetAnchor(TOPLEFT, panel, TOPLEFT, contributionIconX, spec.y + math.floor((contributionRowHeight - contributionIconSz) / 2))
                icon:SetTexture(spec.icon)
                icon:SetAlpha(0.88)
            end

            local lbl = CreateLabel(panel, "Battleboard"..name..spec.key.."Label", spec.label, "ZoFontGame", {0.88, 0.84, 0.72, 1})
            lbl:SetAnchor(TOPLEFT, panel, TOPLEFT, contributionLabelX, spec.y)
            lbl:SetDimensions(contributionValueX - contributionLabelX - 8, spec.hasSubLabel and math.floor(contributionRowHeight * 0.55) or contributionRowHeight)
            lbl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
            lbl:SetVerticalAlignment(TEXT_ALIGN_CENTER)

            local subLbl = nil
            if spec.hasSubLabel then
                subLbl = CreateLabel(panel, "Battleboard"..name..spec.key.."SubLabel", "", "ZoFontGameSmall", {0.60, 0.58, 0.50, 1})
                subLbl:SetAnchor(TOPLEFT, panel, TOPLEFT, contributionLabelX, spec.y + math.floor(contributionRowHeight * 0.55))
                subLbl:SetDimensions(contributionValueX - contributionLabelX - 8, math.floor(contributionRowHeight * 0.45))
                subLbl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
                subLbl:SetVerticalAlignment(TEXT_ALIGN_TOP)
            end

            local val = CreateLabel(panel, "Battleboard"..name..spec.key.."Value", "--", "ZoFontWinH1", {0.88, 0.84, 0.72, 1})
            val:SetAnchor(TOPLEFT, panel, TOPLEFT, contributionValueX, spec.y)
            val:SetDimensions(DATA_PANEL_W - contributionValueX - 12, contributionRowHeight)
            val:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
            val:SetVerticalAlignment(TEXT_ALIGN_CENTER)
            if val.SetScale then val:SetScale(0.96) end

            rows[spec.key] = { value = val, label = lbl, subLabel = subLbl, icon = icon }
        end
        return rows
    end

    -- Personal Records panel (column 2): max value per stat across all matches.
    -- Each row shows stat name + match ID sub-label, plus the max value.
    local personalRecordsSpecs = {
        { key = "kills",   label = "Kills",   icon = "/esoui/art/compass/ava_murderball_neutral.dds", y = 50,  hasSubLabel = true },
        { key = "deaths",  label = "Deaths",  icon = "/esoui/art/tutorial/poi_cemetary_complete.dds",          y = 96, hasSubLabel = true },
        { key = "damage",  label = "Damage",  icon = "/esoui/art/addons/gamepad/gp_mod_listing_category_combat.dds",      y = 142, hasSubLabel = true },
        { key = "healing", label = "Healing", icon = "/esoui/art/lfg/gamepad/lfg_roleicon_healer_down.dds",   y = 188, hasSubLabel = true },
        { key = "score",   label = "Medals",  icon = "/esoui/art/notifications/gamepad/gp_notification_leaderboardaccept_down.dds",           y = 234, hasSubLabel = true },
        { key = "kd",      label = "KD Ratio", icon = "/esoui/art/guild/gamepad/gp_guild_menuicon_changemessage.dds",                         y = 280, hasSubLabel = true },
    }
    local RECORDS_PANEL_H = DATA_TOP_PANEL_HEIGHT
    BL.dataPersonalRecordsLabels = BuildStatPanel(
        "PersonalRecords", "PERSONAL RECORDS",
        BL.dataPageContainer, 2 * (DATA_PANEL_W + DATA_PANEL_GAP),
        RECORDS_PANEL_H, personalRecordsSpecs)

    -- Matches panel (column 2 / middle): count of matches per game type.
    local PLACEHOLDER_ICON = "/esoui/art/battlegrounds/battlegrounds_tabicon_battlegrounds_up.dds"
    local matchesSpecs = {
        { key = "deathmatch",  label = "Deathmatch",   icon = "/esoui/art/battlegrounds/gamepad/gp_battlegrounds_tabicon_deathmatch.dds", y = 50  },
        { key = "relic",       label = "Relic",         icon = "/esoui/art/mappins/ava_town_neutral.dds", y = 96 },
        { key = "chaos",       label = "Chaos Ball",    icon = "/esoui/art/mappins/battlegrounds_murderball_neutral.dds", y = 142 },
        { key = "king",        label = "Crazy King",    icon = "/esoui/art/mappins/battlegrounds_mobilecapturepoint_pin_neutral.dds", y = 188 },
        { key = "domination",  label = "Domination",    icon = "/esoui/art/compass/compass_bg_capturepoint_neutral.dds", y = 234 },
        { key = "total",       label = "Total",          noIcon = true, y = 280 },
        -- "other" intentionally omitted from display; counted in backend via GetSelectedCharacterMatchCounts().
    }
    local MATCHES_PANEL_H = DATA_TOP_PANEL_HEIGHT
    BL.dataMatchCountLabels = BuildStatPanel(
        "MatchCount", "MATCHES",
        BL.dataPageContainer, DATA_PANEL_W + DATA_PANEL_GAP,
        MATCHES_PANEL_H, matchesSpecs)

    -- Add Wins / Losses value labels to each match-count row.
    -- The original "value" label (Total) is hidden; W and L replace it with muted colours.
    do
        local matchPanel = WINDOW_MANAGER:GetControlByName("BattleboardMatchCountPanel")
        if matchPanel and BL.dataMatchCountLabels then
            local COL_W = 46
            local winsX    = contributionValueX + 28   -- shifted right so "Deathmatch" fits on one line
            local lossesX  = winsX + COL_W + 4
            local LABEL_W  = winsX - contributionLabelX - 12   -- widened label box
            -- No column headers

            local WIN_COLOR  = {0.34, 0.58, 0.32, 0.90}   -- muted green
            local LOSS_COLOR = {0.55, 0.22, 0.20, 0.90}   -- muted red
            local TOTAL_COLOR = {0.88, 0.84, 0.72, 1}

            local matchKeys = {"deathmatch", "relic", "chaos", "king", "domination", "total"}
            local matchYs   = { 50, 96, 142, 188, 234, 280 }
            for i, k in ipairs(matchKeys) do
                local row = BL.dataMatchCountLabels[k]
                local ry  = matchYs[i]
                if row and row.value then
                    row.value:SetHidden(true)
                    if row.label then
                        row.label:SetWidth(LABEL_W)   -- room for "Deathmatch"
                        if k == "total" then
                            row.label:SetFont("ZoFontGameBold")
                            row.label:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
                        end
                    end

                    if k == "total" then
                        local totalDivider = WINDOW_MANAGER:CreateControl("BattleboardMatchCountTotalDivider", matchPanel, CT_BACKDROP)
                        totalDivider:SetDimensions(lossesX + COL_W - contributionLabelX, 1)
                        totalDivider:SetAnchor(TOPLEFT, matchPanel, TOPLEFT, contributionLabelX, ry - 4)
                        totalDivider:SetCenterColor(0.549019607843, 0.541176470588, 0.450980392157, 0.45)
                        totalDivider:SetEdgeColor(0, 0, 0, 0)
                        row.totalDivider = totalDivider
                    end

                    local wVal = CreateLabel(matchPanel, "BattleboardMatchCountWins_"..k, "--", "ZoFontWinH1", k == "total" and TOTAL_COLOR or WIN_COLOR)
                    wVal:SetAnchor(TOPLEFT, matchPanel, TOPLEFT, winsX, ry)
                    wVal:SetDimensions(COL_W, contributionRowHeight)
                    wVal:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
                    wVal:SetVerticalAlignment(TEXT_ALIGN_CENTER)
                    if wVal.SetScale then wVal:SetScale(0.96) end
                    row.winsValue = wVal

                    local lVal = CreateLabel(matchPanel, "BattleboardMatchCountLosses_"..k, "--", "ZoFontWinH1", k == "total" and TOTAL_COLOR or LOSS_COLOR)
                    lVal:SetAnchor(TOPLEFT, matchPanel, TOPLEFT, lossesX, ry)
                    lVal:SetDimensions(COL_W, contributionRowHeight)
                    lVal:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
                    lVal:SetVerticalAlignment(TEXT_ALIGN_CENTER)
                    if lVal.SetScale then lVal:SetScale(0.96) end
                    row.lossesValue = lVal
                end
            end
        end
    end
    local dataSummaryStrip = WINDOW_MANAGER:CreateControl("BattleboardDataSummaryStrip", BL.dataPageContainer, CT_CONTROL)
    dataSummaryStrip:SetDimensions(dataPageWidth, METRICS_SUMMARY_STRIP_HEIGHT)
    dataSummaryStrip:SetAnchor(TOPLEFT, BL.dataPageContainer, TOPLEFT, 0, 0)
    BL.dataSummaryStrip = dataSummaryStrip
    BL.dataTopContainer = dataSummaryStrip

    local dataSummaryStripBg = CreateSoftFill(dataSummaryStrip, "BattleboardDataSummaryStripBg", 0, 0, 0, 0.50)
    dataSummaryStripBg:SetAnchorFill(dataSummaryStrip)
    BL.dataSummaryStripBg = dataSummaryStripBg

    -- Crisp visual frame for the Page 2 summary strip. Avoid the ESO tooltip
    -- border texture here because it creates a thick translucent edge and leaves
    -- the centre looking like a transparent hole at some UI scales.
    BL.dataSummaryStripBorder = {}

    local dataSummaryStripBorderTop = WINDOW_MANAGER:CreateControl("BattleboardDataSummaryStripBorderTop", dataSummaryStrip, CT_BACKDROP)
    dataSummaryStripBorderTop:SetAnchor(TOPLEFT, dataSummaryStrip, TOPLEFT, 0, 0)
    dataSummaryStripBorderTop:SetAnchor(TOPRIGHT, dataSummaryStrip, TOPRIGHT, 0, 0)
    dataSummaryStripBorderTop:SetHeight(1)
    dataSummaryStripBorderTop:SetCenterColor(1, 0.82, 0.28, 0.32)
    dataSummaryStripBorderTop:SetEdgeColor(0, 0, 0, 0)
    BL.dataSummaryStripBorder.Top = dataSummaryStripBorderTop

    local dataSummaryStripBorderBottom = WINDOW_MANAGER:CreateControl("BattleboardDataSummaryStripBorderBottom", dataSummaryStrip, CT_BACKDROP)
    dataSummaryStripBorderBottom:SetAnchor(BOTTOMLEFT, dataSummaryStrip, BOTTOMLEFT, 0, 0)
    dataSummaryStripBorderBottom:SetAnchor(BOTTOMRIGHT, dataSummaryStrip, BOTTOMRIGHT, 0, 0)
    dataSummaryStripBorderBottom:SetHeight(1)
    dataSummaryStripBorderBottom:SetCenterColor(1, 0.82, 0.28, 0.32)
    dataSummaryStripBorderBottom:SetEdgeColor(0, 0, 0, 0)
    BL.dataSummaryStripBorder.Bottom = dataSummaryStripBorderBottom

    local dataSummaryStripBorderLeft = WINDOW_MANAGER:CreateControl("BattleboardDataSummaryStripBorderLeft", dataSummaryStrip, CT_BACKDROP)
    dataSummaryStripBorderLeft:SetAnchor(TOPLEFT, dataSummaryStrip, TOPLEFT, 0, 0)
    dataSummaryStripBorderLeft:SetAnchor(BOTTOMLEFT, dataSummaryStrip, BOTTOMLEFT, 0, 0)
    dataSummaryStripBorderLeft:SetWidth(1)
    dataSummaryStripBorderLeft:SetCenterColor(1, 0.82, 0.28, 0.32)
    dataSummaryStripBorderLeft:SetEdgeColor(0, 0, 0, 0)
    BL.dataSummaryStripBorder.Left = dataSummaryStripBorderLeft

    local dataSummaryStripBorderRight = WINDOW_MANAGER:CreateControl("BattleboardDataSummaryStripBorderRight", dataSummaryStrip, CT_BACKDROP)
    dataSummaryStripBorderRight:SetAnchor(TOPRIGHT, dataSummaryStrip, TOPRIGHT, 0, 0)
    dataSummaryStripBorderRight:SetAnchor(BOTTOMRIGHT, dataSummaryStrip, BOTTOMRIGHT, 0, 0)
    dataSummaryStripBorderRight:SetWidth(1)
    dataSummaryStripBorderRight:SetCenterColor(1, 0.82, 0.28, 0.32)
    dataSummaryStripBorderRight:SetEdgeColor(0, 0, 0, 0)
    BL.dataSummaryStripBorder.Right = dataSummaryStripBorderRight

    -- Summary strip: compact sweetroll / MVP / match count / win-rate / KD blocks.
    BL.dataDateSummaryLabels = {}  -- kept as no-op table so legacy refresh code doesn't error

    local SUMMARY_CENTER_W = dataPageWidth
    local SUMMARY_PANEL_H = METRICS_SUMMARY_STRIP_HEIGHT

    local function CreateSummaryPanel(key, x, w, centreStyle)
        local panel = WINDOW_MANAGER:CreateControl("BattleboardSummary" .. key .. "Panel", dataSummaryStrip, CT_CONTROL)
        panel:SetDimensions(w, SUMMARY_PANEL_H)
        panel:SetAnchor(TOPLEFT, dataSummaryStrip, TOPLEFT, x, 0)
        return panel
    end

    BL.dataSummaryCenterPanel = CreateSummaryPanel("Center", 0, SUMMARY_CENTER_W, true)

    local BLOCK_H = METRICS_SUMMARY_STRIP_HEIGHT - 12
    local DIVIDER_Y = math.floor(BLOCK_H * 0.52)
    local SUMMARY_LABEL_OFFSET_Y = 6
    local SUMMARY_BLOCK_W = math.floor((DATA_PANEL_W - 6 * 2) / 3)
    local SUMMARY_NEAR_OFFSET_X = SUMMARY_BLOCK_W + 44
    local SUMMARY_FAR_OFFSET_X = SUMMARY_NEAR_OFFSET_X + SUMMARY_BLOCK_W + 18

    local function BuildCenterMetricColumn(key, labelText, offsetX)
        local colW = SUMMARY_BLOCK_W
        local block = WINDOW_MANAGER:CreateControl("BattleboardSummaryCenter" .. key .. "Column", BL.dataSummaryCenterPanel, CT_CONTROL)
        block:SetDimensions(colW, BLOCK_H)
        block:SetAnchor(TOP, BL.dataSummaryCenterPanel, TOP, offsetX, 6)

        local value = CreateLabel(block, "BattleboardSummaryCenter" .. key .. "Value", "--", "ZoFontWinH1", {0.88, 0.84, 0.72, 1})
        value:SetAnchor(TOPLEFT, block, TOPLEFT, 0, 4)
        value:SetDimensions(colW, DIVIDER_Y)
        value:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        value:SetVerticalAlignment(TEXT_ALIGN_CENTER)

        local div = WINDOW_MANAGER:CreateControl("BattleboardSummaryCenter" .. key .. "Div", block, CT_BACKDROP)
        div:SetDimensions(colW - 8, 1)
        div:SetAnchor(TOPLEFT, block, TOPLEFT, 4, DIVIDER_Y + SUMMARY_LABEL_OFFSET_Y)
        div:SetCenterColor(0.549019607843, 0.541176470588, 0.450980392157, 0.7)
        div:SetEdgeColor(0, 0, 0, 0)

        local label = CreateLabel(block, "BattleboardSummaryCenter" .. key .. "Label", labelText, "ZoFontGameBold", {0.72, 0.68, 0.58, 1})
        label:SetAnchor(TOPLEFT, block, TOPLEFT, 0, DIVIDER_Y + 4 + SUMMARY_LABEL_OFFSET_Y)
        label:SetDimensions(colW, BLOCK_H - DIVIDER_Y - 4 - SUMMARY_LABEL_OFFSET_Y)
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetVerticalAlignment(TEXT_ALIGN_TOP)
        if label.SetScale then label:SetScale(1.08) end

        return value, label
    end

    BL.dataSweetrollsValue, BL.dataSweetrollsLabel = BuildCenterMetricColumn("Sweetrolls", "SWEETROLLS", -SUMMARY_FAR_OFFSET_X)
    BL.dataMvpRateValue, BL.dataMvpRateLabel = BuildCenterMetricColumn("MvpRate", "MVP RATE", -SUMMARY_NEAR_OFFSET_X)
    BL.dataWinRateValue, BL.dataWinRateLabel = BuildCenterMetricColumn("WinRate", "WIN RATE", SUMMARY_NEAR_OFFSET_X)
    BL.dataOverallKDValue, BL.dataOverallKDLabel = BuildCenterMetricColumn("OverallKD", "KD", SUMMARY_FAR_OFFSET_X)
    BL.dataMatchCountValue = CreateLabel(dataSummaryStrip, "BattleboardSummaryCenterMatchesValue", "--", "ZoFontWinH1", {0.88, 0.84, 0.72, 1})
    BL.dataMatchCountValue:SetAnchor(CENTER, dataSummaryStrip, CENTER, 0, -8)
    BL.dataMatchCountValue:SetDimensions(84, 44)
    BL.dataMatchCountValue:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    BL.dataMatchCountValue:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    if BL.dataMatchCountValue.SetScale then BL.dataMatchCountValue:SetScale(1.8) end
    BL.dataMatchCountValue:SetDrawLayer(DL_OVERLAY)
    BL.dataMatchCountValue:SetDrawTier(DT_HIGH)
    if BL.dataMatchCountValue.SetDrawLevel then BL.dataMatchCountValue:SetDrawLevel(101) end
    BL.dataMatchCountValue:SetMouseEnabled(true)
    BL.dataMatchCountValue:SetHandler("OnMouseEnter", function(ctrl)
        ZO_Tooltips_ShowTextTooltip(ctrl, BOTTOM, "Total Matches")
    end)
    BL.dataMatchCountValue:SetHandler("OnMouseExit", function()
        ZO_Tooltips_HideTextTooltip()
    end)
    local dataHeaderDivider = WINDOW_MANAGER:CreateControl("BattleboardDataHeaderDivider", BL.dataPageContainer, CT_BACKDROP)
    dataHeaderDivider:SetDimensions(dataPageWidth, 2)
    dataHeaderDivider:SetAnchor(TOPLEFT, BL.dataPageContainer, TOPLEFT, 0, METRICS_SUMMARY_STRIP_HEIGHT)
    dataHeaderDivider:SetCenterColor(0.549019607843, 0.541176470588, 0.450980392157, 1)
    dataHeaderDivider:SetEdgeColor(0, 0, 0, 0)
    BL.dataHeaderDivider = dataHeaderDivider

    -- Lower panels sit directly below the top stat panels, using the same
    -- vertical gap as the summary strip above them.
    local LOWER_PANEL_GAP  = 8
    local ENC_CONTENT_H    = 232   -- header(30) + pad(10) + colHdr(22) + gap(6) + 7x(20+2)(154) + pad(10)
    local LOWER_PANEL_H    = ENC_CONTENT_H
    local LOWER_PANEL_Y    = DATA_PANEL_Y + DATA_TOP_PANEL_HEIGHT + DATA_PANEL_GAP
    local LOWER_PANEL_W    = math.floor((dataPageWidth - LOWER_PANEL_GAP) / 2)

    local HEADER_BG_H  = 30
    local TABLE_PAD    = 10
    local COL_ROW_H    = 20
    local HDR_ROW_H    = 22

    -- Timer panel (left half)
    BL.timerPanel = WINDOW_MANAGER:CreateControl("BattleboardMetricsTimerPanel", BL.dataPageContainer, CT_CONTROL)
    BL.timerPanel:SetDimensions(LOWER_PANEL_W, LOWER_PANEL_H)
    BL.timerPanel:SetAnchor(TOPLEFT, BL.dataPageContainer, TOPLEFT, 0, LOWER_PANEL_Y)

    local timerBg = CreateSoftFill(BL.timerPanel, "BattleboardMetricsTimerPanelBg", 0, 0, 0, 0.50)
    timerBg:SetAnchorFill(BL.timerPanel)

    for _, side in ipairs({"Top","Bottom","Left","Right"}) do
        local b = WINDOW_MANAGER:CreateControl("BattleboardMetricsTimerPanelBorder" .. side, BL.timerPanel, CT_BACKDROP)
        if side == "Top" then
            b:SetAnchor(TOPLEFT, BL.timerPanel, TOPLEFT, 0, 0)
            b:SetAnchor(TOPRIGHT, BL.timerPanel, TOPRIGHT, 0, 0)
            b:SetHeight(1)
        elseif side == "Bottom" then
            b:SetAnchor(BOTTOMLEFT, BL.timerPanel, BOTTOMLEFT, 0, 0)
            b:SetAnchor(BOTTOMRIGHT, BL.timerPanel, BOTTOMRIGHT, 0, 0)
            b:SetHeight(1)
        elseif side == "Left" then
            b:SetAnchor(TOPLEFT, BL.timerPanel, TOPLEFT, 0, 0)
            b:SetAnchor(BOTTOMLEFT, BL.timerPanel, BOTTOMLEFT, 0, 0)
            b:SetWidth(1)
        elseif side == "Right" then
            b:SetAnchor(TOPRIGHT, BL.timerPanel, TOPRIGHT, 0, 0)
            b:SetAnchor(BOTTOMRIGHT, BL.timerPanel, BOTTOMRIGHT, 0, 0)
            b:SetWidth(1)
        end
        b:SetCenterColor(1, 0.82, 0.28, 0.32)
        b:SetEdgeColor(0, 0, 0, 0)
    end

    local timerHdr = WINDOW_MANAGER:CreateControl("BattleboardMetricsTimerPanelHeader", BL.timerPanel, CT_CONTROL)
    timerHdr:SetDimensions(LOWER_PANEL_W - TABLE_PAD * 2, HEADER_BG_H)
    timerHdr:SetAnchor(TOPLEFT, BL.timerPanel, TOPLEFT, TABLE_PAD, 0)
    local timerHdrEdge = WINDOW_MANAGER:CreateControl("BattleboardMetricsTimerPanelHdrEdge", timerHdr, CT_BACKDROP)
    timerHdrEdge:SetAnchor(BOTTOMLEFT, timerHdr, BOTTOMLEFT, 0, 0)
    timerHdrEdge:SetAnchor(BOTTOMRIGHT, timerHdr, BOTTOMRIGHT, 0, 0)
    timerHdrEdge:SetHeight(2)
    timerHdrEdge:SetCenterColor(0.549019607843, 0.541176470588, 0.450980392157, 1)
    timerHdrEdge:SetEdgeColor(0, 0, 0, 0)
    BL.timerPanelHeader = CreateLabel(timerHdr, "BattleboardMetricsTimerPanelHeaderText", "AVERAGE DURATION", "ZoFontGameBold", {0.92, 0.84, 0.62, 1})
    BL.timerPanelHeader:SetAnchorFill(timerHdr)
    BL.timerPanelHeader:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    BL.timerPanelHeader:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    BL.timerSummaryRows = {}
    do
        local blockGap = 4
        local blockW = math.floor((LOWER_PANEL_W - TABLE_PAD * 2 - blockGap * 4) / 5)
        local blockH = LOWER_PANEL_H - HEADER_BG_H - TABLE_PAD * 2
        local blockY = HEADER_BG_H + TABLE_PAD
        local timerIcon = "/esoui/art/tutorial/timer_icon.dds"
        local specs = {
            { key = "queueDuration", label = "Queue" },
            { key = "matchDuration", label = "Match" },
            { key = "deserter",      label = "Deserter" },
            { key = "deadDuration",  label = "Dead" },
            { key = "combatDuration", label = "In Combat" },
        }
        local function AttachQueueLengthTooltip(control, anchorControl)
            if not control then return end
            control:SetMouseEnabled(true)
            control:SetHandler("OnMouseEnter", function(ctrl)
                ZO_Tooltips_ShowTextTooltip(anchorControl or ctrl, LEFT, "For Haki, with love")
            end)
            control:SetHandler("OnMouseExit", function()
                ZO_Tooltips_HideTextTooltip()
            end)
        end

        for i, spec in ipairs(specs) do
            local block = WINDOW_MANAGER:CreateControl("BattleboardMetricsTimerBlock_" .. spec.key, BL.timerPanel, CT_CONTROL)
            block:SetDimensions(blockW, blockH)
            block:SetAnchor(TOPLEFT, BL.timerPanel, TOPLEFT, TABLE_PAD + (i - 1) * (blockW + blockGap), blockY)

            local blockBg = CreateSoftFill(block, "BattleboardMetricsTimerBlockBg_" .. spec.key, 0.075, 0.066, 0.050, 0.48)
            blockBg:SetAnchorFill(block)

            local label = CreateLabel(block, "BattleboardMetricsTimerBlockLabel_" .. spec.key, spec.label, "ZoFontGameBold", {0.92, 0.84, 0.62, 1})
            label:SetAnchor(TOPLEFT, block, TOPLEFT, 4, 8)
            label:SetDimensions(blockW - 8, 22)
            label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            label:SetVerticalAlignment(TEXT_ALIGN_CENTER)

            local icon = WINDOW_MANAGER:CreateControl("BattleboardMetricsTimerBlockIcon_" .. spec.key, block, CT_TEXTURE)
            icon:SetTexture(timerIcon)
            icon:SetDimensions(36, 36)
            icon:SetAnchor(TOP, block, TOP, 0, 42)

            local average = CreateLabel(block, "BattleboardMetricsTimerBlockAverage_" .. spec.key, "--", "ZoFontWinH2", {0.88, 0.84, 0.72, 1})
            average:SetAnchor(TOPLEFT, block, TOPLEFT, 4, 92)
            average:SetDimensions(blockW - 8, 32)
            average:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            average:SetVerticalAlignment(TEXT_ALIGN_CENTER)

            local total = CreateLabel(block, "BattleboardMetricsTimerBlockTotal_" .. spec.key, "Total: --", "ZoFontGameSmall", {0.70, 0.68, 0.60, 1})
            total:SetAnchor(BOTTOMLEFT, block, BOTTOMLEFT, 4, -10)
            total:SetDimensions(blockW - 8, 18)
            total:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            total:SetVerticalAlignment(TEXT_ALIGN_CENTER)

            local matchesLeft = nil
            if spec.key == "deserter" then
                matchesLeft = CreateLabel(block, "BattleboardMetricsTimerBlockMatchesLeft_" .. spec.key, "Count: --", "ZoFontGameSmall", {0.70, 0.68, 0.60, 1})
                matchesLeft:SetAnchor(BOTTOMLEFT, block, BOTTOMLEFT, 4, -30)
                matchesLeft:SetDimensions(blockW - 8, 18)
                matchesLeft:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
                matchesLeft:SetVerticalAlignment(TEXT_ALIGN_CENTER)
            end

            if spec.key == "queueDuration" then
                AttachQueueLengthTooltip(block, block)
                AttachQueueLengthTooltip(label, block)
                AttachQueueLengthTooltip(average, block)
                AttachQueueLengthTooltip(total, block)
            end

            BL.timerSummaryRows[spec.key] = { block = block, label = label, icon = icon, average = average, total = total, matchesLeft = matchesLeft }
        end
    end

    -- Breakdown panel (right half)
    BL.performancePanel = WINDOW_MANAGER:CreateControl("BattleboardDataRightPanel", BL.dataPageContainer, CT_CONTROL)
    BL.performancePanel:SetDimensions(LOWER_PANEL_W, LOWER_PANEL_H)
    BL.performancePanel:SetAnchor(TOPLEFT, BL.dataPageContainer, TOPLEFT, LOWER_PANEL_W + LOWER_PANEL_GAP, LOWER_PANEL_Y)

    local perfBg = CreateSoftFill(BL.performancePanel, "BattleboardPerfPanelBg", 0, 0, 0, 0.50)
    perfBg:SetAnchorFill(BL.performancePanel)

    -- 4-sided border matching Contribution/Records/Matches panels.
    for _, side in ipairs({"Top","Bottom","Left","Right"}) do
        local b = WINDOW_MANAGER:CreateControl("BattleboardPerfPanelBorder"..side, BL.performancePanel, CT_BACKDROP)
        if side == "Top" then
            b:SetAnchor(TOPLEFT, BL.performancePanel, TOPLEFT, 0, 0)
            b:SetAnchor(TOPRIGHT, BL.performancePanel, TOPRIGHT, 0, 0)
            b:SetHeight(1)
        elseif side == "Bottom" then
            b:SetAnchor(BOTTOMLEFT, BL.performancePanel, BOTTOMLEFT, 0, 0)
            b:SetAnchor(BOTTOMRIGHT, BL.performancePanel, BOTTOMRIGHT, 0, 0)
            b:SetHeight(1)
        elseif side == "Left" then
            b:SetAnchor(TOPLEFT, BL.performancePanel, TOPLEFT, 0, 0)
            b:SetAnchor(BOTTOMLEFT, BL.performancePanel, BOTTOMLEFT, 0, 0)
            b:SetWidth(1)
        elseif side == "Right" then
            b:SetAnchor(TOPRIGHT, BL.performancePanel, TOPRIGHT, 0, 0)
            b:SetAnchor(BOTTOMRIGHT, BL.performancePanel, BOTTOMRIGHT, 0, 0)
            b:SetWidth(1)
        end
        b:SetCenterColor(1, 0.82, 0.28, 0.32)
        b:SetEdgeColor(0, 0, 0, 0)
    end

    -- Breakdown header: class-based metrics across time windows.
    local perfHdr = WINDOW_MANAGER:CreateControl("BattleboardPerfPanelHeader", BL.performancePanel, CT_CONTROL)
    perfHdr:SetDimensions(LOWER_PANEL_W - TABLE_PAD * 2, HEADER_BG_H)
    perfHdr:SetAnchor(TOPLEFT, BL.performancePanel, TOPLEFT, TABLE_PAD, 0)
    local perfHdrEdge = WINDOW_MANAGER:CreateControl("BattleboardPerfHdrEdge", perfHdr, CT_BACKDROP)
    perfHdrEdge:SetAnchor(BOTTOMLEFT, perfHdr, BOTTOMLEFT, 0, 0)
    perfHdrEdge:SetAnchor(BOTTOMRIGHT, perfHdr, BOTTOMRIGHT, 0, 0)
    perfHdrEdge:SetHeight(2)
    perfHdrEdge:SetCenterColor(0.549019607843, 0.541176470588, 0.450980392157, 1)
    perfHdrEdge:SetEdgeColor(0, 0, 0, 0)
    BL.performanceHeader = CreateLabel(perfHdr, "BattleboardPerformanceHeader", "BREAKDOWN", "ZoFontGameBold", {0.92, 0.84, 0.62, 1})
    BL.performanceHeader:SetAnchor(LEFT, perfHdr, LEFT, 2, 0)
    BL.performanceHeader:SetDimensions(150, HDR_ROW_H)
    BL.performanceHeader:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    BL.performanceHeader:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    if WINDOW_MANAGER.CreateControlFromVirtual and ZO_ComboBox_ObjectFromContainer then
        BL.performanceAggregateDropdown = WINDOW_MANAGER:CreateControlFromVirtual("BattleboardPerformanceAggregateDropdown", perfHdr, "ZO_ComboBox")
        BL.performanceAggregateDropdown:SetDimensions(78, 24)
        BL.performanceAggregateDropdown:SetAnchor(RIGHT, perfHdr, RIGHT, 0, 0)
        BL.performanceAggregateDropdownCombo = ZO_ComboBox_ObjectFromContainer(BL.performanceAggregateDropdown)
        if BL.performanceAggregateDropdownCombo then
            BL.performanceAggregateDropdownCombo:SetSortsItems(false)
            for _, option in ipairs(PERFORMANCE_AGGREGATE_OPTIONS) do
                local item = BL.performanceAggregateDropdownCombo:CreateItemEntry(option.label, function()
                    BL.performanceAggregateMode = option.key
                    BL.RefreshPerformanceTable()
                end)
                BL.performanceAggregateDropdownCombo:AddItem(item, ZO_COMBOBOX_SUPPRESS_UPDATE)
            end
            BL.performanceAggregateDropdownCombo:SetSelectedItem(BL.performanceAggregateMode or "Averages")
        end
    else
        BL.performanceAggregateDropdown = CreateLabel(perfHdr, "BattleboardPerformanceAggregateDropdownFallback", BL.performanceAggregateMode or "Averages", "ZoFontGame", {0.80, 0.76, 0.64, 1})
        BL.performanceAggregateDropdown:SetDimensions(78, 20)
        BL.performanceAggregateDropdown:SetAnchor(RIGHT, perfHdr, RIGHT, 0, 0)
    end

    -- Local metric selector buttons (right side of the header). These only change
    -- which metric this table shows; they do not touch the global filter strip.
    -- Styled to match the filter-strip buttons.
    BL.performanceMetricButtons = {}
    do
        local metricSpecs = {
            { key = "kills",   label = "Kills",   w = 52 },
            { key = "kd",      label = "KD",      w = 40 },
            { key = "damage",  label = "Damage",  w = 66 },
            { key = "healing", label = "Healing", w = 66 },
        }
        -- Build right-to-left so the row sits flush against the header's right edge.
        local prevBtn = nil
        for i = #metricSpecs, 1, -1 do
            local spec = metricSpecs[i]
            local button = WINDOW_MANAGER:CreateControl("BattleboardPerfMetric_" .. spec.key, perfHdr, CT_BUTTON)
            button:SetDimensions(spec.w, 20)
            button:SetFont("ZoFontGameBold")
            button:SetText(spec.label)
            button:SetNormalFontColor(0.76, 0.72, 0.62, 1)
            button:SetMouseOverFontColor(1, 0.86, 0.36, 1)
            button:SetPressedFontColor(1, 0.82, 0.28, 1)
            if prevBtn then
                button:SetAnchor(RIGHT, prevBtn, LEFT, -1, 0)
            else
                button:SetAnchor(RIGHT, BL.performanceAggregateDropdown, LEFT, -4, 0)
            end
            local bg = CreateSoftFill(button, "BattleboardPerfMetricBg_" .. spec.key, 0.075, 0.066, 0.050, 0.48)
            bg:SetAnchorFill(button)
            button.bg = bg
            button.metricKey = spec.key
            button:SetHandler("OnClicked", function()
                BL.performanceMetric = spec.key
                BL.RefreshPerformanceMetricButtons()
                BL.RefreshPerformanceTable()
            end)
            BL.performanceMetricButtons[#BL.performanceMetricButtons + 1] = button
            prevBtn = button
        end
    end

    -- Class metric table: mirrors encounter panel layout.
    -- Columns: Today | 7 day | 30 day | Overall
    -- Rows: one per class, displayed alphabetically.
    do
        local TW      = LOWER_PANEL_W - TABLE_PAD * 2
        local LABEL_W = 130   -- matches encounter panel
        local KD_COLS = {
            { key = "today",   label = "Today"   },
            { key = "week",    label = "7 day"   },
            { key = "thirty",  label = "30 day"  },
            { key = "overall", label = "Overall" },
        }
        local KD_COL_W = math.floor((TW - LABEL_W) / #KD_COLS)
        local tableY   = HEADER_BG_H + TABLE_PAD

        -- Column headers
        for i, col in ipairs(KD_COLS) do
            local cx = TABLE_PAD + LABEL_W + (i - 1) * KD_COL_W
            local hdr = CreateLabel(BL.performancePanel, "BattleboardPerfKDColHdr_" .. col.key, col.label, "ZoFontGameBold", {0.92, 0.84, 0.62, 1})
            hdr:SetAnchor(TOPLEFT, BL.performancePanel, TOPLEFT, cx, tableY)
            hdr:SetDimensions(KD_COL_W, HDR_ROW_H)
            hdr:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            hdr:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        end

        -- Header divider
        local hdrDiv = WINDOW_MANAGER:CreateControl("BattleboardPerfHdrDiv", BL.performancePanel, CT_BACKDROP)
        hdrDiv:SetDimensions(TW, 1)
        hdrDiv:SetAnchor(TOPLEFT, BL.performancePanel, TOPLEFT, TABLE_PAD, tableY + HDR_ROW_H + 2)
        hdrDiv:SetCenterColor(0.549019607843, 0.541176470588, 0.450980392157, 0.6)
        hdrDiv:SetEdgeColor(0, 0, 0, 0)

        -- Class rows
        local rowY = tableY + HDR_ROW_H + 6
        BL.performanceClassKDLabels = {}
        for _, classSpec in ipairs(GetAlphabeticalClassOrder()) do
            local ry = rowY
            rowY = rowY + COL_ROW_H + 2

            local icon = WINDOW_MANAGER:CreateControl("BattleboardPerfClassIcon_" .. classSpec.key, BL.performancePanel, CT_TEXTURE)
            icon:SetTexture(classIcons[classSpec.key] or BG_ICON)
            icon:SetDimensions(17, 17)
            icon:SetAnchor(TOPLEFT, BL.performancePanel, TOPLEFT, TABLE_PAD, ry + 1)

            local nameLabel = CreateLabel(BL.performancePanel, "BattleboardPerfClassName_" .. classSpec.key, classSpec.label, "ZoFontGame", {0.86, 0.84, 0.75, 1})
            nameLabel:SetAnchor(TOPLEFT, BL.performancePanel, TOPLEFT, TABLE_PAD + 22, ry)
            nameLabel:SetDimensions(LABEL_W - 22, COL_ROW_H)
            nameLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
            nameLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

            BL.performanceClassKDLabels[classSpec.key] = {}
            for i, col in ipairs(KD_COLS) do
                local cx = TABLE_PAD + LABEL_W + (i - 1) * KD_COL_W
                local cell = CreateLabel(BL.performancePanel, "BattleboardPerfKDCell_" .. classSpec.key .. "_" .. col.key, "--", "ZoFontGame", {0.86, 0.84, 0.75, 1})
                cell:SetAnchor(TOPLEFT, BL.performancePanel, TOPLEFT, cx, ry)
                cell:SetDimensions(KD_COL_W, COL_ROW_H)
                cell:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
                cell:SetVerticalAlignment(TEXT_ALIGN_CENTER)
                BL.performanceClassKDLabels[classSpec.key][col.key] = cell
            end
        end
        -- Clear old performance table references
        BL.performanceTableLabels = nil
        BL.performanceKDCell = nil
    end

    if false then
    -- Timers pop-out for the Metrics page. Kept outside the main Metrics layout
    -- while the final placement/design settles.
    BL.metricsTimerPopup = WINDOW_MANAGER:CreateControl("BattleboardMetricsTimerPopup", root, CT_CONTROL)
    BL.metricsTimerPopup:SetDimensions(248, 118)
    BL.metricsTimerPopup:SetAnchor(TOPRIGHT, BL.dataPageContainer, TOPLEFT, -12, 0)
    BL.metricsTimerPopup:SetHidden(true)

    local timerPopupBg = CreateSoftFill(BL.metricsTimerPopup, "BattleboardMetricsTimerPopupBg", 0, 0, 0, 0.72)
    timerPopupBg:SetAnchorFill(BL.metricsTimerPopup)
    for _, side in ipairs({"Top","Bottom","Left","Right"}) do
        local b = WINDOW_MANAGER:CreateControl("BattleboardMetricsTimerPopupBorder" .. side, BL.metricsTimerPopup, CT_BACKDROP)
        if side == "Top" then
            b:SetAnchor(TOPLEFT, BL.metricsTimerPopup, TOPLEFT, 0, 0)
            b:SetAnchor(TOPRIGHT, BL.metricsTimerPopup, TOPRIGHT, 0, 0)
            b:SetHeight(1)
        elseif side == "Bottom" then
            b:SetAnchor(BOTTOMLEFT, BL.metricsTimerPopup, BOTTOMLEFT, 0, 0)
            b:SetAnchor(BOTTOMRIGHT, BL.metricsTimerPopup, BOTTOMRIGHT, 0, 0)
            b:SetHeight(1)
        elseif side == "Left" then
            b:SetAnchor(TOPLEFT, BL.metricsTimerPopup, TOPLEFT, 0, 0)
            b:SetAnchor(BOTTOMLEFT, BL.metricsTimerPopup, BOTTOMLEFT, 0, 0)
            b:SetWidth(1)
        elseif side == "Right" then
            b:SetAnchor(TOPRIGHT, BL.metricsTimerPopup, TOPRIGHT, 0, 0)
            b:SetAnchor(BOTTOMRIGHT, BL.metricsTimerPopup, BOTTOMRIGHT, 0, 0)
            b:SetWidth(1)
        end
        b:SetCenterColor(1, 0.82, 0.28, 0.32)
        b:SetEdgeColor(0, 0, 0, 0)
    end

    local timerPopupTitle = CreateLabel(BL.metricsTimerPopup, "BattleboardMetricsTimerPopupTitle", "AVERAGE DURATION", "ZoFontGameBold", {0.92, 0.84, 0.62, 1})
    timerPopupTitle:SetAnchor(TOPLEFT, BL.metricsTimerPopup, TOPLEFT, 10, 8)
    timerPopupTitle:SetDimensions(228, 18)
    timerPopupTitle:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    BL.timerSummaryRows = {}
    do
        local labelW = 104
        local colW = 62
        local headerY = 30
        local rowStartY = 50
        local rowH = 18
        local avgHeader = CreateLabel(BL.metricsTimerPopup, "BattleboardTimerPopupAverageHeader", "Average", "ZoFontGameSmall", {0.92, 0.84, 0.62, 1})
        avgHeader:SetAnchor(TOPLEFT, BL.metricsTimerPopup, TOPLEFT, 10 + labelW, headerY)
        avgHeader:SetDimensions(colW, 16)
        avgHeader:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

        local totalHeader = CreateLabel(BL.metricsTimerPopup, "BattleboardTimerPopupTotalHeader", "Total", "ZoFontGameSmall", {0.92, 0.84, 0.62, 1})
        totalHeader:SetAnchor(TOPLEFT, BL.metricsTimerPopup, TOPLEFT, 10 + labelW + colW, headerY)
        totalHeader:SetDimensions(colW, 16)
        totalHeader:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

        local rows = {
            { key = "matchDuration", label = "Match duration" },
            { key = "queueDuration", label = "Queue duration" },
            { key = "deserter",      label = "Deserter" },
        }
        for i, spec in ipairs(rows) do
            local rowY = rowStartY + (i - 1) * rowH
            local label = CreateLabel(BL.metricsTimerPopup, "BattleboardTimerPopupLabel_" .. spec.key, spec.label, "ZoFontGameSmall", {0.86, 0.84, 0.75, 1})
            label:SetAnchor(TOPLEFT, BL.metricsTimerPopup, TOPLEFT, 10, rowY)
            label:SetDimensions(labelW, rowH)
            label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

            local average = CreateLabel(BL.metricsTimerPopup, "BattleboardTimerPopupAverage_" .. spec.key, "--", "ZoFontGameSmall", {0.86, 0.84, 0.75, 1})
            average:SetAnchor(TOPLEFT, BL.metricsTimerPopup, TOPLEFT, 10 + labelW, rowY)
            average:SetDimensions(colW, rowH)
            average:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

            local total = CreateLabel(BL.metricsTimerPopup, "BattleboardTimerPopupTotal_" .. spec.key, "--", "ZoFontGameSmall", {0.86, 0.84, 0.75, 1})
            total:SetAnchor(TOPLEFT, BL.metricsTimerPopup, TOPLEFT, 10 + labelW + colW, rowY)
            total:SetDimensions(colW, rowH)
            total:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

            BL.timerSummaryRows[spec.key] = { label = label, average = average, total = total }
        end
    end

    -- Encounter panel (right half)
    -- Table: Average seen per match for Today/7d/30d, plus all-time Total column.
    BL.encounterPanel = WINDOW_MANAGER:CreateControl("BattleboardDataRightPanel", BL.dataPageContainer, CT_CONTROL)
    BL.encounterPanel:SetDimensions(LOWER_PANEL_W, LOWER_PANEL_H)
    BL.encounterPanel:SetAnchor(TOPLEFT, BL.dataPageContainer, TOPLEFT, LOWER_PANEL_W + LOWER_PANEL_GAP, LOWER_PANEL_Y)

    local encBg = CreateSoftFill(BL.encounterPanel, "BattleboardEncPanelBg", 0, 0, 0, 0.50)
    encBg:SetAnchorFill(BL.encounterPanel)

    -- 4-sided border matching Contribution/Records/Matches panels.
    for _, side in ipairs({"Top","Bottom","Left","Right"}) do
        local b = WINDOW_MANAGER:CreateControl("BattleboardEncPanelBorder"..side, BL.encounterPanel, CT_BACKDROP)
        if side == "Top" then
            b:SetAnchor(TOPLEFT, BL.encounterPanel, TOPLEFT, 0, 0)
            b:SetAnchor(TOPRIGHT, BL.encounterPanel, TOPRIGHT, 0, 0)
            b:SetHeight(1)
        elseif side == "Bottom" then
            b:SetAnchor(BOTTOMLEFT, BL.encounterPanel, BOTTOMLEFT, 0, 0)
            b:SetAnchor(BOTTOMRIGHT, BL.encounterPanel, BOTTOMRIGHT, 0, 0)
            b:SetHeight(1)
        elseif side == "Left" then
            b:SetAnchor(TOPLEFT, BL.encounterPanel, TOPLEFT, 0, 0)
            b:SetAnchor(BOTTOMLEFT, BL.encounterPanel, BOTTOMLEFT, 0, 0)
            b:SetWidth(1)
        elseif side == "Right" then
            b:SetAnchor(TOPRIGHT, BL.encounterPanel, TOPRIGHT, 0, 0)
            b:SetAnchor(BOTTOMRIGHT, BL.encounterPanel, BOTTOMRIGHT, 0, 0)
            b:SetWidth(1)
        end
        b:SetCenterColor(1, 0.82, 0.28, 0.32)
        b:SetEdgeColor(0, 0, 0, 0)
    end

    -- Encounter header - transparent bg, underline only (matches Contribution/Records/Matches style).
    local encHdr = WINDOW_MANAGER:CreateControl("BattleboardEncPanelHeader", BL.encounterPanel, CT_CONTROL)
    encHdr:SetDimensions(LOWER_PANEL_W - TABLE_PAD * 2, HEADER_BG_H)
    encHdr:SetAnchor(TOPLEFT, BL.encounterPanel, TOPLEFT, TABLE_PAD, 0)
    local encHdrEdge2 = WINDOW_MANAGER:CreateControl("BattleboardEncHdrEdge2", encHdr, CT_BACKDROP)
    encHdrEdge2:SetAnchor(BOTTOMLEFT, encHdr, BOTTOMLEFT, 0, 0)
    encHdrEdge2:SetAnchor(BOTTOMRIGHT, encHdr, BOTTOMRIGHT, 0, 0)
    encHdrEdge2:SetHeight(2)
    encHdrEdge2:SetCenterColor(0.549019607843, 0.541176470588, 0.450980392157, 1)
    encHdrEdge2:SetEdgeColor(0, 0, 0, 0)
    BL.encounterHeader = CreateLabel(encHdr, "BattleboardEncounterHeader", "ENCOUNTER (avg)", "ZoFontGameBold", {0.92, 0.84, 0.62, 1})
    BL.encounterHeader:SetAnchorFill(encHdr)
    BL.encounterHeader:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    BL.encounterHeader:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    do
        local TW          = LOWER_PANEL_W - TABLE_PAD * 2
        local LABEL_W     = 130   -- widened from 112 to prevent 'Dragon Knight' truncation
        -- Columns: Today avg, 7d avg, 30d avg, Overall (all-time avg), Total
        local ENC_COLS = {
            { key = "today",   label = "Today"   },
            { key = "week",    label = "7 day"   },
            { key = "thirty",  label = "30 day"  },
            { key = "overall", label = "Overall" },
            { key = "total",   label = "Total"   },
        }
        local ENC_COL_W   = math.floor((TW - LABEL_W) / #ENC_COLS)
        local tableY      = HEADER_BG_H + TABLE_PAD

        -- Column headers
        for i, col in ipairs(ENC_COLS) do
            local cx = TABLE_PAD + LABEL_W + (i - 1) * ENC_COL_W
            local hdr = CreateLabel(BL.encounterPanel, "BattleboardEncColHdr_" .. col.key, col.label, "ZoFontGameBold", {0.92, 0.84, 0.62, 1})
            hdr:SetAnchor(TOPLEFT, BL.encounterPanel, TOPLEFT, cx, tableY)
            hdr:SetDimensions(ENC_COL_W, HDR_ROW_H)
            hdr:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            hdr:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        end

        -- Header divider
        local hdrDiv = WINDOW_MANAGER:CreateControl("BattleboardEncHdrDiv", BL.encounterPanel, CT_BACKDROP)
        hdrDiv:SetDimensions(TW, 1)
        hdrDiv:SetAnchor(TOPLEFT, BL.encounterPanel, TOPLEFT, TABLE_PAD, tableY + HDR_ROW_H + 2)
        hdrDiv:SetCenterColor(0.549019607843, 0.541176470588, 0.450980392157, 0.6)
        hdrDiv:SetEdgeColor(0, 0, 0, 0)

        -- Class rows
        local rowY = tableY + HDR_ROW_H + 6
        BL.encounterClassAverageTableLabels = {}
        for _, classSpec in ipairs(encounterClassOrder) do
            local ry = rowY
            rowY = rowY + COL_ROW_H + 2

            local icon = WINDOW_MANAGER:CreateControl("BattleboardEncClassIcon_" .. classSpec.key, BL.encounterPanel, CT_TEXTURE)
            icon:SetTexture(classIcons[classSpec.key] or BG_ICON)
            icon:SetDimensions(17, 17)
            icon:SetAnchor(TOPLEFT, BL.encounterPanel, TOPLEFT, TABLE_PAD, ry + 1)

            local nameLabel = CreateLabel(BL.encounterPanel, "BattleboardEncClassName_" .. classSpec.key, classSpec.label, "ZoFontGame", {0.86, 0.84, 0.75, 1})
            nameLabel:SetAnchor(TOPLEFT, BL.encounterPanel, TOPLEFT, TABLE_PAD + 22, ry)
            nameLabel:SetDimensions(LABEL_W - 22, COL_ROW_H)
            nameLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
            nameLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

            BL.encounterClassAverageTableLabels[classSpec.key] = {}
            for i, col in ipairs(ENC_COLS) do
                local cx = TABLE_PAD + LABEL_W + (i - 1) * ENC_COL_W
                local cell = CreateLabel(BL.encounterPanel, "BattleboardEncCell_" .. classSpec.key .. "_" .. col.key, "--", "ZoFontGame", {0.86, 0.84, 0.75, 1})
                cell:SetAnchor(TOPLEFT, BL.encounterPanel, TOPLEFT, cx, ry)
                cell:SetDimensions(ENC_COL_W, COL_ROW_H)
                cell:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
                cell:SetVerticalAlignment(TEXT_ALIGN_CENTER)
                BL.encounterClassAverageTableLabels[classSpec.key][col.key] = cell
            end
        end
    end

    end

    if BL.BuildObservatoryPage then
        BL.BuildObservatoryPage(root)
    end

    -- dataLeftPanel / dataRightPanel aliased to the new panels for any legacy refresh paths.
    BL.dataLeftPanel  = BL.timerPanel
    BL.dataRightPanel = BL.performancePanel

    BL.historyPageControls = {
        BL.historyPanel,
        BL.matchDetailsDivider,
        BL.MatchDetailsPanel,
        BL.pageOneFooter,
        BL.footerDivider,
    }

    BL.RefreshPageTabs()
end

function BL.ClearControls(list)
    for _, control in ipairs(list) do
        control:SetHidden(true)
        control:ClearAnchors()
    end
    ZO_ClearNumericallyIndexedTable(list)
end

function BL.HideMvpPanel()
    if BL.mvpPanel then
        BL.mvpPanel:SetHidden(true)
    end
    if BL.mvpPanelReviewNote then
        BL.mvpPanelReviewNote:SetHidden(true)
    end
end

function BL.ShowMvpPanel(player)
    if not BL.mvpPanel or not player then return end

    local userId = tostring(player.displayName or "")
    if userId == "" then userId = tostring(player.characterName or "MVP") end

    if BL.mvpPanelClassIcon then
        BL.mvpPanelClassIcon:SetTexture(classIcons[tonumber(player.classId) or 0] or BLANK_ICON)
    end
    if BL.mvpPanelUserId then
        BL.mvpPanelUserId:SetText(userId)
    end
    if BL.mvpPanelContributionStats then
        local statValues = {
            kills = player.kills,
            deaths = player.deaths,
            damage = player.damage,
            healing = player.healing,
        }
        for key, controls in pairs(BL.mvpPanelContributionStats) do
            if controls and controls.value then
                controls.value:SetText(FormatMvpRawStat(statValues[key]))
            end
        end
    end

    BL.mvpPanel:SetHidden(false)
    if BL.mvpPanelReviewNote then
        BL.mvpPanelReviewNote:SetHidden(false)
    end
end

function BL.RefreshAccountCharacters()
    BL.vars.characters = BL.vars.characters or {}
    local characters = {}
    local seenByName = {}

    local function add(name, characterId, classId)
        name = zo_strformat(SI_PLAYER_NAME, name or "")
        local nameKey = NormalizePlayerName(name)
        if nameKey == "" then return end

        local key = MakeCharacterKey(name, characterId)
        local existingIndex = seenByName[nameKey]
        if existingIndex then
            -- Same visible character can appear from both GetCharacterInfo and the
            -- current-character fallback. Keep one dropdown entry and prefer richer data.
            local existing = characters[existingIndex]
            if (not existing.characterId or tostring(existing.characterId) == "0") and characterId and tostring(characterId) ~= "0" then
                existing.characterId = characterId
                existing.key = key
            end
            if (not existing.classId or tonumber(existing.classId) == 0) and tonumber(classId) and tonumber(classId) > 0 then
                existing.classId = tonumber(classId)
            end
            return
        end

        seenByName[nameKey] = #characters + 1
        characters[#characters + 1] = {
            name = name ~= "" and name or "Character",
            key = key,
            characterId = characterId,
            classId = tonumber(classId) or 0,
            nameKey = nameKey,
        }
    end

    local count = Num(GetNumCharacters())
    if count > 0 then
        for i = 1, count do
            local name, gender, level, classId, raceId, alliance, characterId = GetCharacterInfo(i)
            add(name, characterId, classId)
        end
    end

    -- Fallback for API edge cases: always include the current character.
    add(GetCurrentCharacterName(), GetCurrentCharacterIdOrNil(), tonumber(GetUnitClassId("player")) or 0)

    table.sort(characters, function(a, b)
        local currentNameKey = NormalizePlayerName(GetCurrentCharacterName())
        if a.nameKey == currentNameKey then return true end
        if b.nameKey == currentNameKey then return false end
        return tostring(a.name or "") < tostring(b.name or "")
    end)

    BL.vars.characters = characters
end

function BL.GetCharacterOptions()
    local hasSavedMatches = #(BL.matches or {}) > 0
    if hasSavedMatches and (not BL.vars.characters or #BL.vars.characters == 0) then
        BL.RefreshAccountCharacters()
    end

    local allCharacters = BL.vars.characters or {}
    local charactersWithMatches = {
        {
            name = "All Characters",
            key = ALL_CHARACTERS_KEY,
            characterId = nil,
            classId = 0,
            nameKey = "",
        }
    }
    local seen = { [ALL_CHARACTERS_KEY] = true }

    for _, match in ipairs(BL.matches or {}) do
        local key = GetMatchCharacterKey(match)
        local name = GetMatchCharacterName(match)
        local nameKey = NormalizePlayerName(name)
        local classId = GetMatchLocalClassId(match) or 0
        local characterId = GetMatchCharacterId(match)

        if key and key ~= "" and not seen[key] then
            seen[key] = true

            local existing = nil
            for _, character in ipairs(allCharacters) do
                if character.key == key then
                    existing = character
                    break
                end
            end

            charactersWithMatches[#charactersWithMatches + 1] = {
                name = (existing and existing.name) or name or "Character",
                key = key,
                characterId = (existing and existing.characterId) or characterId,
                classId = (existing and existing.classId) or classId,
                nameKey = nameKey,
            }
        end
    end

    table.sort(charactersWithMatches, function(a, b)
        return tostring(a.name or "") < tostring(b.name or "")
    end)

    -- If saved matches exist but no match-specific character rows were found,
    -- expose account characters as optional filters.
    if hasSavedMatches and #charactersWithMatches == 1 then
        for _, character in ipairs(allCharacters) do
            if character.key and character.key ~= "" and not seen[character.key] then
                seen[character.key] = true
                charactersWithMatches[#charactersWithMatches + 1] = character
            end
        end
    end

    return charactersWithMatches
end

function BL.RefreshMenuIcon()
    -- Keep the main menu icon static; character filtering changes the displayed matches, not the addon category icon.
    if BL.menuCategoryData then
        BL.menuCategoryData.normal = MENU_ICON
        BL.menuCategoryData.pressed = MENU_ICON_DOWN
        BL.menuCategoryData.highlight = MENU_ICON_OVER
    end
    local menu = LibMainMenu2 or LMM
    if menu and BL.menuCategory and menu.Update then
        local sceneName = (BL.IsBattleboardSceneName(SCENE_MANAGER:GetCurrentSceneName()) and SCENE_MANAGER:GetCurrentSceneName()) or BL.GetDefaultBattleboardSceneName()
        menu:Update(BL.menuCategory, sceneName)
    end
end

function BL.RefreshCharacterDropdown()
    if not BL.selectedCharacterKey or BL.selectedCharacterKey == "" then
        BL.selectedCharacterKey = ALL_CHARACTERS_KEY
    end

    local options = BL.GetCharacterOptions()
    local selectedExists = false
    for _, option in ipairs(options) do
        if option.key == BL.selectedCharacterKey then
            selectedExists = true
            break
        end
    end
    if not selectedExists then
        BL.selectedCharacterKey = ALL_CHARACTERS_KEY
    end

    if BL.characterDropdown then
        BL.characterDropdown:SetDimensions(164, 28)
        BL.characterDropdown:ClearAnchors()
        BL.characterDropdown:SetAnchor(LEFT, BL.filterStrip, LEFT, 6, 0)
        StyleFilterDropdown(BL.characterDropdown, BL.characterDropdownCombo, "BattleboardCharacterDropdown")
    end

    if BL.characterDropdownCombo then
        BL.characterDropdownCombo:ClearItems()
        for _, option in ipairs(options) do
            local item = BL.characterDropdownCombo:CreateItemEntry(option.name or "Character", function()
                BL.selectedCharacterKey = option.key
                BL.selectedMatchId = nil
                BL.RefreshMenuIcon()
                BL.RefreshHistory(true)
                BL.RefreshDetails(BL.EnsureVisibleSelection())
                if BL.activePage == "Data" then BL.RefreshDataPage() elseif BL.activePage == "Observatory" then BL.RefreshObservatoryPage() end
            end)
            BL.characterDropdownCombo:AddItem(item, ZO_COMBOBOX_SUPPRESS_UPDATE)
        end
        BL.characterDropdownCombo:SetSelectedItem(GetSelectedCharacterName())
        StyleFilterDropdown(BL.characterDropdown, BL.characterDropdownCombo, "BattleboardCharacterDropdown")
    elseif BL.characterDropdown and BL.characterDropdown.SetText then
        BL.characterDropdown:SetText(GetSelectedCharacterName())
        StyleFilterDropdown(BL.characterDropdown, nil, "BattleboardCharacterDropdownFallback")
    end

    BL.RefreshMenuIcon()
end

-- Highlights the active metric button on the Performance panel (local control,
-- independent of the global filter strip). Mirrors the filter-button active style.
function BL.RefreshPerformanceMetricButtons()
    local active = BL.performanceMetric or "kills"
    for _, button in ipairs(BL.performanceMetricButtons or {}) do
        if button.metricKey == active then
            button:SetNormalFontColor(1, 0.82, 0.28, 1)
            if button.bg then button.bg:SetCenterColor(0.12, 0.095, 0.045, 0.62) end
        else
            button:SetNormalFontColor(0.76, 0.72, 0.62, 1)
            if button.bg then button.bg:SetCenterColor(0.075, 0.066, 0.050, 0.48) end
        end
    end
end

-- Repopulates only the Performance table cells for the currently selected metric.
function BL.RefreshPerformanceTable()
    if not BL.performanceClassKDLabels then return end
    local metric = BL.performanceMetric or "kills"
    local mode = BL.performanceAggregateMode == "Totals" and "Totals" or "Averages"
    BL.performanceAggregateMode = mode
    if BL.performanceAggregateDropdownCombo then
        BL.performanceAggregateDropdownCombo:SetSelectedItem(mode)
    elseif BL.performanceAggregateDropdown and BL.performanceAggregateDropdown.SetText then
        BL.performanceAggregateDropdown:SetText(mode)
    end

    local classData = GetClassMetricForWindows(metric, mode)
    for _, classSpec in ipairs(encounterClassOrder) do
        local row = BL.performanceClassKDLabels[classSpec.key]
        if row then
            local vals = classData[classSpec.key] or {}
            for _, wKey in ipairs({"today","week","thirty","overall"}) do
                local cell = row[wKey]
                if cell then cell:SetText(vals[wKey] or "--") end
            end
        end
    end
end

function BL.RefreshDataPage(force)
    local todayText = FormatTimestamp(GetTimeStamp())

    -- BREAKDOWN: every stat function below scans the entire match list, so with
    -- large datasets re-running them on each open causes the stutter. The page is
    -- a pure function of (selected character, match count, today's date, and the
    -- active filters), so cache on that key and skip the recompute when nothing
    -- changed. Adding/deleting a match changes the count, and changing a filter
    -- button changes the key, so both force a fresh calculation.
    local cacheKey = table.concat({
        tostring(GetSelectedCharacterKey()),
        tostring(#(BL.matches or {})),
        tostring(todayText),
        tostring(BL.historyFilter or "All"),
        tostring(BL.matchTypeFilter or "All"),
        tostring(BL.teamSizeFilter or "All"),
        tostring(BL.dateRangeFilter or "All"),
    }, "#")
    if not force and cacheKey == BL._dataPageCacheKey then return end
    BL._dataPageCacheKey = cacheKey

    local statAverages = GetSelectedCharacterStatAveragesForAllTime()

    -- Filtered win rate with green/red colouring.
    if BL.dataWinRateValue then
        local wr = GetSelectedCharacterWinRate()
        if wr then
            BL.dataWinRateValue:SetText(string.format("%d%%", wr))
            if wr >= 50 then
                BL.dataWinRateValue:SetColor(0.46, 0.72, 0.42, 1)
            else
                BL.dataWinRateValue:SetColor(0.58, 0.18, 0.16, 1)
            end
        else
            BL.dataWinRateValue:SetText("--")
            BL.dataWinRateValue:SetColor(0.88, 0.84, 0.72, 1)
        end
    end

    -- Filtered summary averages and counts.
    do
        local _, filteredCount = GetSelectedCharacterStatSummaryForAllTime()
        local mvpCount = 0
        for _, match in ipairs(BL.matches or {}) do
            if MatchPassesHistoryFilter(match) then
                local player = GetLocalPlayerForMatch(match)
                if player and player.isTeamMvp == true then
                    mvpCount = mvpCount + 1
                end
            end
        end

        if BL.dataMatchCountValue then
            BL.dataMatchCountValue:SetText(filteredCount > 0 and FormatBigNumber(filteredCount) or "--")
        end
        if BL.dataSweetrollsValue then
            BL.dataSweetrollsValue:SetText(filteredCount > 0 and FormatBigNumber(mvpCount) or "--")
            BL.dataSweetrollsValue:SetColor(0.88, 0.84, 0.72, 1)
        end
        if BL.dataMvpRateValue then
            if filteredCount > 0 then
                local mvpRate = math.floor((mvpCount / filteredCount) * 100 + 0.5)
                BL.dataMvpRateValue:SetText(string.format("%d%%", mvpRate))
                if mvpRate >= 25 then
                    BL.dataMvpRateValue:SetColor(0.46, 0.72, 0.42, 1)
                else
                    BL.dataMvpRateValue:SetColor(0.58, 0.18, 0.16, 1)
                end
            else
                BL.dataMvpRateValue:SetText("--")
                BL.dataMvpRateValue:SetColor(0.88, 0.84, 0.72, 1)
            end
        end
        if BL.dataOverallKDValue then
            BL.dataOverallKDValue:SetText(filteredCount > 0 and GetSelectedCharacterKD() or "--")
            BL.dataOverallKDValue:SetColor(0.88, 0.84, 0.72, 1)
        end
    end

    local contributionAverages = GetSelectedCharacterContributionAverages()

    if BL.dataContributionAverageLabels then
        local KEY_ORDER = { "score", "kills", "deaths", "damage", "healing", "kd" }
        for _, key in ipairs(KEY_ORDER) do
            local controls = BL.dataContributionAverageLabels[key]
            if controls then
                -- % contribution column
                if controls.value then
                    if key == "kd" then
                        local avg = statAverages and statAverages[key]
                        controls.value:SetText(avg and FormatStatTableNumber(avg, key, true) or "--")
                    else
                        controls.value:SetText(FormatContributionAverageValue(contributionAverages and contributionAverages[key]))
                    end
                end
                -- Raw avg per match column
                if controls.rawValue then
                    local avg = statAverages and statAverages[key]
                    if key == "kd" then
                        controls.rawValue:SetText("")
                    elseif avg then
                        controls.rawValue:SetText(FormatStatTableNumber(avg, key, true))
                    else
                        controls.rawValue:SetText("--")
                    end
                end
            end
        end
    end

    -- Breakdown panel: class metric (Kills/KD/Damage/Healing) across time windows.
    BL.RefreshPerformanceMetricButtons()
    BL.RefreshPerformanceTable()

    -- Timers panel.
    if BL.timerSummaryRows then
        local timers = GetSelectedCharacterTimerSummary()
        local function setTimerRow(key, data)
            local row = BL.timerSummaryRows[key]
            if not row then return end
            local hasData = data and Num(data.count) > 0
            if row.average then row.average:SetText(hasData and FormatSummaryDuration(data.average) or "--") end
            if row.total then
                row.total:SetText("Total: " .. (hasData and FormatSummaryDuration(data.total) or "--"))
            end
            if row.matchesLeft then
                row.matchesLeft:SetText("Count: " .. (hasData and tostring(Num(data.count)) or "--"))
            end
        end
        setTimerRow("matchDuration", timers and timers.matchDuration)
        setTimerRow("queueDuration", timers and timers.queueDuration)
        setTimerRow("deadDuration", timers and timers.deadDuration)
        setTimerRow("combatDuration", timers and timers.combatDuration)
        setTimerRow("deserter", GetDeserterSummary())
    end

    -- Personal Records panel.
    if BL.dataPersonalRecordsLabels then
        local bests = GetSelectedCharacterPersonalBests()
        local keyOrder = { "kills", "deaths", "damage", "healing", "score", "kd" }
        for _, key in ipairs(keyOrder) do
            local ctrl = BL.dataPersonalRecordsLabels[key]
            if ctrl then
                local best = bests[key]
                if best and best.value ~= nil then
                    ctrl.value:SetText(FormatStatTableNumber(best.value, key, false))
                    if ctrl.subLabel then
                        ctrl.subLabel:SetText(best.matchId and ("Match " .. FormatMatchId(best.matchId)) or "")
                    end
                else
                    ctrl.value:SetText("--")
                    if ctrl.subLabel then ctrl.subLabel:SetText("") end
                end
            end
        end
    end

    -- Matches panel.
    if BL.dataMatchCountLabels then
        local counts = GetSelectedCharacterMatchCounts()
        local keyMap = {
            deathmatch = "DM",
            relic      = "R",
            chaos      = "C",
            king       = "CK",
            domination = "DOM",
            other      = "Other",
        }
        for panelKey, filterKey in pairs(keyMap) do
            local ctrl = BL.dataMatchCountLabels[panelKey]
            if ctrl then
                local c = counts[filterKey] or { total = 0, wins = 0, losses = 0 }
                ctrl.value:SetText(c.total > 0 and tostring(c.total) or "--")
                if ctrl.winsValue then
                    ctrl.winsValue:SetText(c.total > 0 and tostring(c.wins) or "--")
                end
                if ctrl.lossesValue then
                    ctrl.lossesValue:SetText(c.total > 0 and tostring(c.losses) or "--")
                end
            end
        end
        local totalCtrl = BL.dataMatchCountLabels.total
        if totalCtrl then
            local wins, losses, total = 0, 0, 0
            for _, filterKey in ipairs({"DM", "R", "C", "CK", "DOM", "Other"}) do
                local c = counts[filterKey] or { total = 0, wins = 0, losses = 0 }
                wins = wins + Num(c.wins)
                losses = losses + Num(c.losses)
                total = total + Num(c.total)
            end
            if totalCtrl.value then totalCtrl.value:SetText(total > 0 and tostring(total) or "--") end
            if totalCtrl.winsValue then totalCtrl.winsValue:SetText(total > 0 and tostring(wins) or "--") end
            if totalCtrl.lossesValue then totalCtrl.lossesValue:SetText(total > 0 and tostring(losses) or "--") end
        end
    end

    -- (Old performanceTableLabels and performanceKDCell removed with the stat-average table.)

end

function BL.RefreshMatchTypeButtons()
    if not BL.matchTypeFilter or BL.matchTypeFilter == "" then
        BL.matchTypeFilter = "All"
    end
    if not BL.teamSizeFilter or BL.teamSizeFilter == "" then
        BL.teamSizeFilter = "All"
    end
    BL.teamSizeFilter = NormalizeTeamSizeFilter(BL.teamSizeFilter)
    if BL.teamSizeDropdownCombo then
        BL.teamSizeDropdownCombo:SetSelectedItem(GetTeamSizeFilterLabel(BL.teamSizeFilter))
        StyleFilterDropdown(BL.teamSizeDropdown, BL.teamSizeDropdownCombo, "BattleboardTeamSizeDropdown")
    elseif BL.teamSizeDropdown and BL.teamSizeDropdown.SetText then
        BL.teamSizeDropdown:SetText(GetTeamSizeFilterLabel(BL.teamSizeFilter))
        StyleFilterDropdown(BL.teamSizeDropdown, nil, "BattleboardTeamSizeDropdownFallback")
    end
    if BL.dateRangeDropdownCombo then
        BL.dateRangeDropdownCombo:SetSelectedItem(GetDateRangeFilterLabel(BL.dateRangeFilter or "All"))
        StyleFilterDropdown(BL.dateRangeDropdown, BL.dateRangeDropdownCombo, "BattleboardDateRangeDropdown")
    elseif BL.dateRangeDropdown and BL.dateRangeDropdown.SetText then
        BL.dateRangeDropdown:SetText(GetDateRangeFilterLabel(BL.dateRangeFilter or "All"))
        StyleFilterDropdown(BL.dateRangeDropdown, nil, "BattleboardDateRangeDropdownFallback")
    end

    for _, button in ipairs(BL.matchTypeButtons or {}) do
        if button.matchTypeKey == BL.matchTypeFilter then
            button:SetNormalFontColor(1, 0.82, 0.28, 1)
            if button.bg then button.bg:SetCenterColor(0.12, 0.095, 0.045, 0.62) end
        else
            button:SetNormalFontColor(0.76, 0.72, 0.62, 1)
            if button.bg then button.bg:SetCenterColor(0.075, 0.066, 0.050, 0.48) end
        end
    end
end


local HISTORY_ROW_HEIGHT = 40
local HISTORY_ROW_GAP = 2
local HISTORY_ROW_STRIDE = HISTORY_ROW_HEIGHT + HISTORY_ROW_GAP
local HISTORY_POOL_EXTRA_ROWS = 4

function BL.CreateHistoryCardPool()
    if BL.historyCardPoolBuilt then return end
    if not BL.historyContainer then return end

    BL.historyRows = BL.historyRows or {}
    BL.historyCardPool = {}
    BL.historyCardControls = {}

    local poolSize = math.floor((HISTORY_VIEWPORT_HEIGHT or 645) / HISTORY_ROW_STRIDE) + HISTORY_POOL_EXTRA_ROWS
    if poolSize < 18 then poolSize = 18 end

    for i = 1, poolSize do
        local row = WINDOW_MANAGER:CreateControl("BattleboardHistoryVirtualRow" .. i, BL.historyContainer, CT_CONTROL)
        row:SetDimensions(HISTORY_CARD_AREA_WIDTH or HISTORY_PANEL_WIDTH, HISTORY_ROW_HEIGHT)
        row:SetAnchor(TOPLEFT, BL.historyContainer, TOPLEFT, 0, 0)
        row:SetHidden(true)
        row:SetMouseEnabled(true)
        BL.historyRows[#BL.historyRows + 1] = row

        local bd = CreateSoftFill(row, "BattleboardHistoryVirtualRowBackdrop" .. i, 0.050, 0.044, 0.036, 0.78)
        bd:SetAnchorFill(row)
        BL.historyRows[#BL.historyRows + 1] = bd

        local accent = WINDOW_MANAGER:CreateControl("BattleboardHistoryVirtualAccent" .. i, row, CT_BACKDROP)
        accent:SetDimensions(3, 34)
        accent:SetAnchor(LEFT, row, LEFT, 0, 0)
        accent:SetCenterColor(1, 0.82, 0.28, 0.82)
        accent:SetEdgeColor(0, 0, 0, 0)
        accent:SetHidden(true)
        BL.historyRows[#BL.historyRows + 1] = accent

        local matchClassIcon = WINDOW_MANAGER:CreateControl("BattleboardHistoryVirtualClassIcon" .. i, row, CT_TEXTURE)
        matchClassIcon:SetDimensions(22, 22)
        matchClassIcon:SetAnchor(LEFT, row, LEFT, 6, 0)
        matchClassIcon:SetMouseEnabled(true)
        BL.historyRows[#BL.historyRows + 1] = matchClassIcon

        local title = CreateLabel(row, "BattleboardHistoryVirtualRowTitle" .. i, "", "ZoFontGameBold", {0.95, 0.90, 0.76, 1})
        title:SetAnchor(TOPLEFT, row, TOPLEFT, 36, 4)
        title:SetDimensions(154, 17)
        BL.historyRows[#BL.historyRows + 1] = title

        local matchNumber = CreateLabel(row, "BattleboardHistoryVirtualRowMatchNumber" .. i, "", "ZoFontGameSmall", {0.58, 0.56, 0.50, 0.46})
        matchNumber:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 0)
        matchNumber:SetDimensions(154, 15)
        BL.historyRows[#BL.historyRows + 1] = matchNumber

        local result = CreateLabel(row, "BattleboardHistoryVirtualRowResult" .. i, "", "ZoFontGameBold", {0.84, 0.82, 0.70, 1})
        result:SetAnchor(RIGHT, row, RIGHT, -8, 0)
        result:SetDimensions(18, 18)
        result:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        BL.historyRows[#BL.historyRows + 1] = result

        local lockedIcon = WINDOW_MANAGER:CreateControl("BattleboardHistoryLockedIcon" .. i, row, CT_TEXTURE)
        lockedIcon:SetTexture(HISTORY_LOCKED_ICON)
        lockedIcon:SetDimensions(14, 14)
        lockedIcon:SetAnchor(RIGHT, result, LEFT, -2, 0)
        lockedIcon:SetDrawLayer(DL_CONTROLS)
        lockedIcon:SetDrawTier(DT_HIGH)
        lockedIcon:SetHidden(true)
        lockedIcon:SetMouseEnabled(false)
        BL.historyRows[#BL.historyRows + 1] = lockedIcon

        BL.historyCardPool[i] = {
            row = row,
            bg = bd,
            accent = accent,
            classIcon = matchClassIcon,
            title = title,
            matchNumber = matchNumber,
            result = result,
            lockedIcon = lockedIcon,
            match = nil,
        }

        -- Sweetroll icon: visible when the local player was team MVP.
        local mvpIcon = WINDOW_MANAGER:CreateControl("BattleboardHistoryMvpIcon" .. i, row, CT_TEXTURE)
        mvpIcon:SetTexture(HISTORY_MVP_ICON)
        mvpIcon:SetDimensions(22, 22)
        mvpIcon:SetAnchor(LEFT, row, LEFT, 6, 0)  -- same anchor as class icon
        mvpIcon:SetDrawLayer(DL_CONTROLS)
        mvpIcon:SetDrawTier(DT_HIGH)  -- above the class icon (DT_LOW)
        mvpIcon:SetHidden(true)
        mvpIcon:SetMouseEnabled(false)
        BL.historyCardPool[i].mvpIcon = mvpIcon
    end

    BL.historyCardPoolBuilt = true
end

function BL.SetFooterMatchesCount(count)
    if BL.footerMatchesSaved then
        local footerMatches = {}
        for _, match in ipairs(BL.matches or {}) do
            if MatchPassesHistoryFilter(match) then
                footerMatches[#footerMatches + 1] = match
            end
        end
        local lockedCount = CountLockedMatches(BL.matches or {})
        local mvpCount = CountLocalMvpMatches(footerMatches)
        local divider = string.char(226, 128, 162)
        BL.footerMatchesSaved:SetText(string.format(
            "|t16:16:%s|t%d  %s  |t20:20:%s|t%d  %s  %d",
            HISTORY_LOCKED_ICON,
            lockedCount,
            divider,
            MVP_RANK_ICON,
            mvpCount,
            divider,
            Num(count)
        ))
    end
end

function BL.RefreshVisibleHistoryRows()
    zo_callLater(function() BL.RefreshHistoryScrollThumb() end, 1)
    BL.RefreshHistoryScrollThumb()
    if not BL.historyCardPool then return end

    local matches = BL.visibleHistoryMatches or {}
    local scrollY = 0
    if BL.historyScroll and BL.historyScroll.GetVerticalScroll then
        scrollY = Num(BL.historyScroll:GetVerticalScroll())
    end

    local firstIndex = math.floor(scrollY / HISTORY_ROW_STRIDE) + 1
    if firstIndex < 1 then firstIndex = 1 end

    BL.historyCardControls = {}

    for poolIndex, controls in ipairs(BL.historyCardPool) do
        local matchIndex = firstIndex + poolIndex - 1
        local match = matches[matchIndex]
        local row = controls.row

        if not match then
            row:SetHidden(true)
            controls.match = nil
        else
            local y = (matchIndex - 1) * HISTORY_ROW_STRIDE
            row:ClearAnchors()
            row:SetAnchor(TOPLEFT, BL.historyContainer, TOPLEFT, 0, y)
            row:SetDimensions(HISTORY_CARD_AREA_WIDTH or HISTORY_PANEL_WIDTH, HISTORY_ROW_HEIGHT)
            row:SetHidden(false)
            controls.match = match

            local selected = match.id == BL.selectedMatchId
            ApplyHistoryCardBackground(controls, selected)
            if controls.accent then
                controls.accent:SetHidden(not selected)
            end

            local resultLine = GetPlayerResultText(match)
            local displayResultLine = "--"
            if resultLine == "Win" then
                displayResultLine = "W"
            elseif resultLine == "Loss" then
                displayResultLine = "L"
            elseif resultLine == "Tie" then
                displayResultLine = "T"
            end

            if controls.classIcon then
                controls.classIcon:SetTexture(classIcons[GetMatchLocalClassId(match) or 0] or BLANK_ICON)
                controls.classIcon:SetHandler("OnMouseEnter", function(control)
                    ZO_Tooltips_ShowTextTooltip(control, BOTTOM, GetMatchCharacterName(match) or "Character")
                end)
                controls.classIcon:SetHandler("OnMouseExit", function()
                    ZO_Tooltips_HideTextTooltip()
                end)
            end

            if controls.title then
                controls.title:SetText(GetCompactGameTypeName(match.gameType))
                if selected then
                    controls.title:SetColor(1, 0.84, 0.32, 1)
                else
                    controls.title:SetColor(0.95, 0.90, 0.76, 1)
                end
            end

            if controls.matchNumber then
                controls.matchNumber:SetText(FormatTimestamp(match.capturedAt))
            end

            if controls.result then
                controls.result:SetText(displayResultLine)
                if resultLine == "Win" then
                    controls.result:SetColor(0.46, 0.72, 0.42, 1)
                elseif resultLine == "Loss" then
                    controls.result:SetColor(0.58, 0.18, 0.16, 1)
                else
                    controls.result:SetColor(0.84, 0.82, 0.70, 1)
                end
            end

            BL.historyCardControls[match.id] = {
                row = controls.row,
                bg = controls.bg,
                accent = controls.accent,
                title = controls.title,
                match = match,
            }

            -- Sweetroll icon: visible when the local player was team MVP.
            if controls.mvpIcon then
                controls.mvpIcon:SetHidden(not IsLocalPlayerMvpMatch(match))
            end
            if controls.lockedIcon then
                controls.lockedIcon:SetHidden(not (match.isLocked == true))
            end

            row:SetHandler("OnMouseUp", function(_, button, upInside)
                if not upInside then return end
                if button == MOUSE_BUTTON_INDEX_LEFT then
                    BL.SelectMatch(match.id)
                elseif button == MOUSE_BUTTON_INDEX_RIGHT then
                    ClearMenu()
                    local lockedLabel = BL.IsLocked(match.id) and "Unlock match" or "Lock match"
                    AddCustomMenuItem(lockedLabel, function()
                        BL.ToggleLocked(match.id)
                    end)
                    AddCustomMenuItem("Share", function()
                        BL.ShareMatch(match)
                    end)
                    ShowMenu(row)
                end
            end)
        end
    end
end




local function GetMouseYForBattleboard()
    local _, y = GetUIMousePosition()
    return Num(y)
end

function BL.GetHistoryVisibleCount()
    if BL.historyVisibleRowCount and BL.historyVisibleRowCount > 0 then
        return BL.historyVisibleRowCount
    end
    if BL.visibleHistoryRowCount and BL.visibleHistoryRowCount > 0 then
        return BL.visibleHistoryRowCount
    end

    local rowStride = Num(HISTORY_ROW_STRIDE)
    if rowStride <= 0 then rowStride = 42 end

    local viewport = Num(BL.historyViewportHeight or HISTORY_VIEWPORT_HEIGHT)
    if viewport <= 0 then viewport = Num(HISTORY_VIEWPORT_HEIGHT) end

    local visible = math.floor(viewport / rowStride)
    if visible < 1 then visible = 1 end

    BL.historyVisibleRowCount = visible
    return visible
end

function BL.GetHistoryTotalCount()
    return #(BL.visibleHistoryMatches or BL.filteredHistoryMatches or BL.historyMatches or {})
end

function BL.RenderCurrentHistoryWindow()
    -- Single dispatch point for the virtualized Match History list.
    -- Mouse wheel and draggable thumb both call this after changing
    -- historyFirstVisibleIndex/historyScrollIndex.
    if BL.UpdateHistoryCardPool then
        BL.UpdateHistoryCardPool()
    elseif BL.RefreshHistoryCardPool then
        BL.RefreshHistoryCardPool()
    elseif BL.RefreshHistoryCards then
        BL.RefreshHistoryCards()
    elseif BL.RenderHistoryCards then
        BL.RenderHistoryCards()
    elseif BL.RenderHistoryVisibleCards then
        BL.RenderHistoryVisibleCards()
    elseif BL.RenderVisibleHistoryCards then
        BL.RenderVisibleHistoryCards()
    elseif BL.UpdateHistoryVisibleCards then
        BL.UpdateHistoryVisibleCards()
    elseif BL.RefreshHistoryVisibleCards then
        BL.RefreshHistoryVisibleCards()
    elseif BL.RefreshVisibleHistoryRows then
        BL.RefreshVisibleHistoryRows()
    elseif BL.RenderVisibleHistoryRows then
        BL.RenderVisibleHistoryRows()
    elseif BL.UpdateVisibleHistoryRows then
        BL.UpdateVisibleHistoryRows()
    elseif BL.UpdateHistoryVirtualRows then
        BL.UpdateHistoryVirtualRows()
    else
        -- Last resort: force a non-rebuild refresh if the virtualized
        -- implementation has kept RefreshHistory as the renderer.
        BL.RefreshHistory(false)
    end
end

function BL.SetHistoryFirstVisibleIndex(index)
    local total = BL.GetHistoryTotalCount()
    local visible = BL.GetHistoryVisibleCount()
    local maxFirst = math.max(1, total - visible + 1)

    index = math.floor(Num(index) + 0.5)
    if index < 1 then index = 1 end
    if index > maxFirst then index = maxFirst end

    BL.historyFirstVisibleIndex = index
    BL.historyScrollIndex = index
    BL.historyStartIndex = index
    BL.historyFirstIndex = index
    BL.historyVisibleStartIndex = index

    BL.SyncNativeHistoryScrollFromIndex()
    BL.RenderCurrentHistoryWindow()
    BL.RefreshHistoryScrollThumb()
end

function BL.SyncNativeHistoryScrollFromIndex()
    if not BL.historyScroll or not BL.historyScroll.SetVerticalScroll then return end

    local first = Num(BL.historyFirstVisibleIndex or BL.historyScrollIndex or 1)
    if first < 1 then first = 1 end

    local rowStride = Num(HISTORY_ROW_STRIDE)
    if rowStride <= 0 then
        rowStride = Num(BL.historyRowHeight or BL.historyCardHeight or 42)
    end
    if rowStride <= 0 then rowStride = 42 end

    local total = BL.GetHistoryTotalCount()
    local visible = BL.GetHistoryVisibleCount()
    local maxFirst = math.max(1, total - visible + 1)
    if first > maxFirst then first = maxFirst end

    BL.historyScroll:SetVerticalScroll(math.max(0, (first - 1) * rowStride))
end

function BL.HistoryThumbYToIndex(y)
    local total = BL.GetHistoryTotalCount()
    local visible = BL.GetHistoryVisibleCount()
    local maxFirst = math.max(1, total - visible + 1)

    if maxFirst <= 1 then return 1 end

    local trackHeight = Num(HISTORY_VIEWPORT_HEIGHT)
    local thumbHeight = Num(BL.historyScrollThumbHeight or 32)
    local maxY = math.max(1, trackHeight - thumbHeight)

    y = Num(y)
    if y < 0 then y = 0 end
    if y > maxY then y = maxY end

    local progress = y / maxY
    return math.floor(progress * (maxFirst - 1) + 1.5)
end

function BL.StartHistoryThumbDrag(fromTrack)
    if not BL.historyScrollTrack or not BL.historyScrollThumb then return end

    BL.historyThumbDragging = true

    local mouseY = GetMouseYForBattleboard()
    local thumbY = Num(BL.historyScrollThumbY or 0)
    local trackTop = 0
    if BL.historyScrollTrack.GetTop then
        trackTop = Num(BL.historyScrollTrack:GetTop())
    end

    if fromTrack then
        -- Track clicks jump first, then drag from the centre of the thumb.
        BL.historyThumbGrabOffset = Num(BL.historyScrollThumbHeight or 32) / 2
    else
        -- Thumb clicks preserve the place you grabbed, preventing snap-to-top.
        BL.historyThumbGrabOffset = mouseY - trackTop - thumbY
        if BL.historyThumbGrabOffset < 0 then BL.historyThumbGrabOffset = 0 end
        local thumbHeight = Num(BL.historyScrollThumbHeight or 32)
        if BL.historyThumbGrabOffset > thumbHeight then BL.historyThumbGrabOffset = thumbHeight end
    end

    BL.historyScrollThumb:SetCenterColor(1, 0.86, 0.36, 0.82)

    BL.historyScrollTrack:SetHandler("OnUpdate", function()
        BL.UpdateHistoryThumbDrag()
    end)
    if BL.historyScrollHitbox then
        BL.historyScrollHitbox:SetHandler("OnUpdate", function()
            BL.UpdateHistoryThumbDrag()
        end)
    end
end

function BL.StopHistoryThumbDrag()
    if not BL.historyThumbDragging then return end

    BL.historyThumbDragging = false

    if BL.historyScrollTrack then
        BL.historyScrollTrack:SetHandler("OnUpdate", nil)
    end
    if BL.historyScrollHitbox then
        BL.historyScrollHitbox:SetHandler("OnUpdate", nil)
    end

    if BL.historyScrollThumb then
        BL.historyScrollThumb:SetCenterColor(0.92, 0.84, 0.62, 0.58)
    end
end

function BL.UpdateHistoryThumbDrag()
    if not BL.historyThumbDragging then return end
    if not BL.historyScrollTrack or not BL.historyScrollThumb then return end

    local mouseY = GetMouseYForBattleboard()
    local trackTop = 0
    if BL.historyScrollTrack.GetTop then
        trackTop = Num(BL.historyScrollTrack:GetTop())
    end

    local y = mouseY - trackTop - Num(BL.historyThumbGrabOffset or 0)
    BL.SetHistoryFirstVisibleIndex(BL.HistoryThumbYToIndex(y))
end

function BL.JumpHistoryThumbToMouse()
    if not BL.historyScrollTrack then return end

    local mouseY = GetMouseYForBattleboard()
    local trackTop = 0
    if BL.historyScrollTrack.GetTop then
        trackTop = Num(BL.historyScrollTrack:GetTop())
    end

    local thumbHeight = Num(BL.historyScrollThumbHeight or 32)
    local y = mouseY - trackTop - (thumbHeight / 2)

    BL.SetHistoryFirstVisibleIndex(BL.HistoryThumbYToIndex(y))
end


function BL.RefreshHistoryScrollThumb()
    if not BL.historyScrollTrack or not BL.historyScrollThumb then return end

    local total = BL.GetHistoryTotalCount()
    local visible = BL.GetHistoryVisibleCount()

    if total <= 0 or total <= visible then
        BL.historyScrollTrack:SetHidden(true)
        if BL.historyScrollThumb then BL.historyScrollThumb:SetHidden(true) end
        return
    end

    BL.historyScrollTrack:SetHidden(false)
    if BL.historyScrollThumb then BL.historyScrollThumb:SetHidden(false) end

    local trackHeight = Num(BL.historyViewportHeight or HISTORY_VIEWPORT_HEIGHT)
    local thumbHeight = math.floor(trackHeight * (visible / total))
    if thumbHeight < 32 then thumbHeight = 32 end
    if thumbHeight > trackHeight then thumbHeight = trackHeight end

    BL.historyScrollThumbHeight = thumbHeight

    local maxFirst = math.max(1, total - visible + 1)
    local first = Num(BL.historyFirstVisibleIndex or BL.historyScrollIndex or 1)
    if first < 1 then first = 1 end
    if first > maxFirst then first = maxFirst end

    local maxY = math.max(0, trackHeight - thumbHeight)
    local y = 0
    if maxFirst > 1 then
        y = math.floor(((first - 1) / (maxFirst - 1)) * maxY + 0.5)
    end

    BL.historyScrollThumbY = y

    BL.historyScrollThumb:ClearAnchors()
    BL.historyScrollThumb:SetDimensions(HISTORY_SCROLLBAR_WIDTH or 12, thumbHeight)
    BL.historyScrollThumb:SetAnchor(TOP, BL.historyScrollTrack, TOP, 0, y)
end

function BL.RefreshHistory(forceRebuild)
    zo_callLater(function() BL.RefreshHistoryScrollThumb() end, 1)
    BL.BuildUI()

    if BL.historyListBuilt and not forceRebuild and not BL.historyNeedsRebuild then
        BL.RefreshCharacterDropdown()
        BL.RefreshMatchTypeButtons()
        BL.UpdateHistorySelectionVisuals()
        return
    end

    BL.historyNeedsRebuild = false
    BL.historyListBuilt = true

    BL.RefreshCharacterDropdown()
    BL.RefreshMatchTypeButtons()
    BL.CreateHistoryCardPool()

    local showObjectiveButtons = (BL.matchTypeFilter or "All") == "Objective"
    local historyViewportHeight = HISTORY_VIEWPORT_HEIGHT - (BL.historyScrollOffsetY or 0)
    BL.historyViewportHeight = historyViewportHeight

    if BL.historyScroll then
        BL.historyScroll:ClearAnchors()
        BL.historyScroll:SetAnchor(TOPLEFT, BL.historyPanel, TOPLEFT, 0, BL.historyScrollOffsetY or 0)
        BL.historyScroll:SetDimensions(HISTORY_SCROLL_WIDTH, historyViewportHeight)
    end
    if BL.historyScrollTrack then
        BL.historyScrollTrack:ClearAnchors()
        BL.historyScrollTrack:SetDimensions(HISTORY_SCROLLBAR_WIDTH or 12, historyViewportHeight)
        BL.historyScrollTrack:SetAnchor(TOPLEFT, BL.historyScroll, TOPRIGHT, HISTORY_SCROLLBAR_GAP, 0)
    end
    if BL.historyScrollHitbox then
        BL.historyScrollHitbox:ClearAnchors()
        BL.historyScrollHitbox:SetDimensions((HISTORY_SCROLLBAR_WIDTH or 12) + 10, historyViewportHeight)
        BL.historyScrollHitbox:SetAnchor(TOPLEFT, BL.historyScrollTrack, TOPLEFT, -5, 0)
    end

    if BL.historyContainer then
        BL.historyContainer:ClearAnchors()
        BL.historyContainer:SetAnchor(TOPLEFT, BL.historyScroll or BL.historyPanel, TOPLEFT, 0, 0)
    end

    for _, button in ipairs(BL.historyFilterButtons or {}) do
        SetHiddenIfControl(button, not showObjectiveButtons)
        if button.bg then SetHiddenIfControl(button.bg, not showObjectiveButtons) end

        if button.filterKey == (BL.historyFilter or "All") then
            button:SetNormalFontColor(1, 0.82, 0.28, 1)
            if button.bg then button.bg:SetCenterColor(0.08, 0.064, 0.030, 0.56) end
        else
            button:SetNormalFontColor(0.76, 0.72, 0.62, 1)
            if button.bg then button.bg:SetCenterColor(0.030, 0.027, 0.022, 0.22) end
        end
    end

    -- Update locked button highlight (same visual pattern as filter buttons).
    if BL.historyLockedButton then
        if BL.historyLockedFilter then
            if BL.historyLockedButton.bg then
                BL.historyLockedButton.bg:SetCenterColor(0.08, 0.064, 0.030, 0.56)
            end
            if BL.historyLockedButton.icon then
                BL.historyLockedButton.icon:SetColor(1, 0.82, 0.28, 1)
            end
        else
            if BL.historyLockedButton.bg then
                BL.historyLockedButton.bg:SetCenterColor(0.030, 0.027, 0.022, 0.22)
            end
            if BL.historyLockedButton.icon then
                BL.historyLockedButton.icon:SetColor(0.76, 0.72, 0.62, 1)
            end
        end
    end

    if BL.historyMvpButton then
        if BL.historyMvpFilter then
            if BL.historyMvpButton.bg then
                BL.historyMvpButton.bg:SetCenterColor(0.08, 0.064, 0.030, 0.56)
            end
            if BL.historyMvpButton.icon then
                BL.historyMvpButton.icon:SetColor(1, 0.82, 0.28, 1)
            end
        else
            if BL.historyMvpButton.bg then
                BL.historyMvpButton.bg:SetCenterColor(0.030, 0.027, 0.022, 0.22)
            end
            if BL.historyMvpButton.icon then
                BL.historyMvpButton.icon:SetColor(0.76, 0.72, 0.62, 1)
            end
        end
    end

    local visible = {}
    for _, match in ipairs(BL.matches or {}) do
        if MatchPassesHistoryFilter(match) then
            -- Search filter: only show matches whose ID string starts with the typed text.
            local passesSearch = true
            if BL.historySearchFilter and BL.historySearchFilter ~= "" then
                local idStr    = string.upper(tostring(match.id or ""))
                local searchStr = string.upper(tostring(BL.historySearchFilter))
                passesSearch = idStr:sub(1, #searchStr) == searchStr
            end
            -- History-only toggles layered on top of the shared filters.
            local passesLocked = not BL.historyLockedFilter or (match.isLocked == true)
            local passesMvp = not BL.historyMvpFilter or IsLocalPlayerMvpMatch(match)
            if passesSearch and passesLocked and passesMvp then
                visible[#visible + 1] = match
            end
        end
    end
    table.sort(visible, function(a, b)
        local at = Num(a and a.capturedAt)
        local bt = Num(b and b.capturedAt)
        if at == bt then
            return tostring(a and a.id or "") > tostring(b and b.id or "")
        end
        return at > bt
    end)
    BL.visibleHistoryMatches = visible
    BL.SetFooterMatchesCount(#visible)

    local contentHeight = math.max(historyViewportHeight, (#visible * HISTORY_ROW_STRIDE) + 8)
    BL.historyContentHeight = contentHeight

    if BL.historyContainer then
        BL.historyContainer:SetDimensions(HISTORY_PANEL_WIDTH, contentHeight)
    end

    if BL.historyScroll and BL.historyScroll.SetVerticalScroll then
        local rowStride = Num(HISTORY_ROW_STRIDE)
        if rowStride <= 0 then rowStride = 42 end

        local visibleRows = BL.GetHistoryVisibleCount()
        local maxFirst = math.max(1, #visible - visibleRows + 1)
        local current = Num(BL.historyScroll:GetVerticalScroll())
        local currentFirst = math.floor(current / rowStride) + 1

        if forceRebuild then currentFirst = 1 end
        if currentFirst < 1 then currentFirst = 1 end
        if currentFirst > maxFirst then currentFirst = maxFirst end

        BL.historyFirstVisibleIndex = currentFirst
        BL.historyScrollIndex = currentFirst
        BL.historyScroll:SetVerticalScroll(math.max(0, (currentFirst - 1) * rowStride))
    end

    if #visible == 0 then
        if not BL.historyEmptyLabel then
            BL.historyEmptyLabel = CreateLabel(BL.historyContainer, "BattleboardHistoryEmpty", "No data matches these filters", "ZoFontGame", {0.72, 0.69, 0.60, 1})
            BL.historyEmptyLabel:SetDimensions(HISTORY_PANEL_WIDTH - 14, 80)
        end
        BL.historyEmptyLabel:ClearAnchors()
        BL.historyEmptyLabel:SetAnchor(TOPLEFT, BL.historyContainer, TOPLEFT, 8, 10)
        BL.historyEmptyLabel:SetHidden(false)
    elseif BL.historyEmptyLabel then
        BL.historyEmptyLabel:SetHidden(true)
    end

    BL.RefreshVisibleHistoryRows()
end




function BL.SortDetails(matchId, key)
    if key == "teamIcon" then
        if BL.currentSort and BL.currentSort.matchId == matchId then
            BL.currentSort.groupByTeam = not BL.currentSort.groupByTeam
        else
            BL.currentSort = {
                matchId = matchId,
                key = "score",
                ascending = false,
                groupByTeam = true,
            }
        end
    elseif BL.currentSort and BL.currentSort.matchId == matchId and BL.currentSort.key == key then
        BL.currentSort.ascending = not BL.currentSort.ascending
    else
        BL.currentSort = {
            matchId = matchId,
            key = key,
            ascending = not IsNumericSortKey(key), -- text starts A-Z; numbers start highest-first
        }
    end

    BL.RefreshDetails(BL.GetMatch(matchId))
end

function BL.GetSortedPlayers(match)
    local sort = BL.currentSort
    if not sort or sort.matchId ~= match.id or not sort.key then
        match._battleboardDetailCache = match._battleboardDetailCache or {}
        if not match._battleboardDetailCache.defaultPlayers then
            match._battleboardDetailCache.defaultPlayers = match.players or {}
        end
        return match._battleboardDetailCache.defaultPlayers
    end

    local cacheKey = tostring(sort.key) .. ":" .. tostring(sort.ascending) .. ":" .. tostring(sort.groupByTeam == true)
    match._battleboardDetailCache = match._battleboardDetailCache or {}
    match._battleboardDetailCache.sortedPlayers = match._battleboardDetailCache.sortedPlayers or {}
    if match._battleboardDetailCache.sortedPlayers[cacheKey] then
        return match._battleboardDetailCache.sortedPlayers[cacheKey]
    end

    local players = {}
    for i, player in ipairs(match.players or {}) do
        players[i] = player
    end

    local key = sort.key
    local ascending = sort.ascending
    table.sort(players, function(a, b)
        if sort.groupByTeam and Num(a.alliance) ~= Num(b.alliance) then
            return Num(a.alliance) < Num(b.alliance)
        end

        local av = a[key]
        local bv = b[key]
        if key == "playerName" then
            av = FormatPlayerNameCell(a)
            bv = FormatPlayerNameCell(b)
        end

        if IsNumericSortKey(key) then
            av = Num(av)
            bv = Num(bv)
            if av == bv then
                return tostring(a.characterName or "") < tostring(b.characterName or "")
            end
            if ascending then return av < bv end
            return av > bv
        end

        av = string.lower(tostring(av or ""))
        bv = string.lower(tostring(bv or ""))
        if av == bv then
            return tostring(a.displayName or "") < tostring(b.displayName or "")
        end
        if ascending then return av < bv end
        return av > bv
    end)

    match._battleboardDetailCache.sortedPlayers[cacheKey] = players
    return players
end

local function FormatLocalPlayerSummary(match)
    local player = GetLocalPlayerForMatch(match)
    if not player then return "" end

    return string.format("Kills: %d | Deaths: %d",
        Num(player.kills),
        Num(player.deaths)
    )
end

local function FormatWinRateText()
    local winRate = GetSelectedCharacterWinRate()
    if winRate == nil then return "win rate: --" end
    return string.format("win rate: %d%%", winRate)
end


local function BuildTeamOutcomeRows(match)
    -- Match details must only read stored team summaries from saved variables.
    -- Incomplete records intentionally return no rows so the summary strip can
    -- display "--" instead of reconstructing values.
    local rows = {}

    if not match or type(match.teamSummaries) ~= "table" then
        return rows
    end

    -- Do not sort by score: the score strip has fixed team slots.
    local byAlliance = {}
    for _, summary in ipairs(match.teamSummaries) do
        if type(summary) == "table" then
            local alliance = tonumber(summary.alliance) or 0
            if alliance > 0 then
                byAlliance[alliance] = summary
            end
        end
    end

    -- Fixed display order: Fire Drakes left, Pit Daemons right, Storm Lords centre.
    -- The visual placement is handled below; this order only controls creation.
    local fixedOrder = {
        BATTLEGROUND_ALLIANCE_FIRE_DRAKES,
        BATTLEGROUND_ALLIANCE_PIT_DAEMONS,
        BATTLEGROUND_ALLIANCE_STORM_LORDS,
    }

    for _, alliance in ipairs(fixedOrder) do
        local summary = byAlliance[alliance]
        if summary then
            rows[#rows + 1] = summary
        end
    end

    return rows
end

local function GetWinningAllianceForTeamBlocks(match, teamByAlliance)
    local winner = tonumber(match and match.winner) or 0
    if winner > 0 and teamByAlliance and teamByAlliance[winner] then
        return winner
    end

    return 0
end

local function GetLocalRateTooltipText(match, statKey)
    if not match then return nil end
    if statKey == "damage" and match.localDps ~= nil then
        return "DPS: " .. FormatRate(match.localDps)
    elseif statKey == "healing" and match.localHps ~= nil then
        return "HPS: " .. FormatRate(match.localHps)
    end
    return nil
end

function BL.RefreshDetails(match)
    BL.BuildUI()
    BL.HideMvpPanel()
    if match and not MatchPassesSelectedCharacter(match) then
        match = nil
    end

    -- Match detail controls are expensive to recreate. Saved match values do not
    -- change, so cache the default rendered detail view per match and only hide/show
    -- All player table controls are permanent (created in BuildUI).
    -- RefreshDetails only populates them - no cache needed.

    if not match then
        BL.selectedPlayerRowKey = nil
        if BL.selectMatchText then
            BL.selectMatchText:SetText(BL.pendingMatchLoad and "Loading..." or "Select a match")
        end
        SetHiddenIfControl(BL.selectMatchText, false)
        BL.detailSectionHeader:SetText("")
        BL.detailSectionHeader:SetHidden(true)
        SetHiddenIfControl(BL.outcomeBanner, true)
        SetHiddenIfControl(BL.matchSummaryPanel, true)
        SetHiddenIfControl(BL.teamSummaryBlock, true)
        SetHiddenIfControl(BL.playerTable, true)
        SetHiddenIfControl(BL.summaryDivider, true)
        SetHiddenIfControl(BL.matchMetadata, true)
        return
    end

    SetHiddenIfControl(BL.selectMatchText, true)
    SetHiddenIfControl(BL.playerTable, false)
    SetHiddenIfControl(BL.outcomeBanner, false)
    SetHiddenIfControl(BL.matchSummaryPanel, false)
    SetHiddenIfControl(BL.teamSummaryBlock, false)
    SetHiddenIfControl(BL.summaryDivider, true)
    SetHiddenIfControl(BL.matchMetadata, false)

    BL.detailSectionHeader:SetText("")
    BL.detailSectionHeader:SetHidden(true)

    if BL.matchMetadata then
        local divider = string.char(226, 128, 162)
        local parts = {
            FormatTimestamp(match.capturedAt),
            "Match Id: " .. GetDisplayMatchNumber(match),
        }

        local queueText = FormatDurationSeconds(match.localQueueSeconds)
        parts[#parts + 1] = "Queue length: " .. (queueText or "--")

        local durationText = FormatDurationSeconds(match.localDurationSeconds)
        if durationText then
            parts[#parts + 1] = "Match length: " .. durationText
        end

        BL.matchMetadata:SetText(table.concat(parts, "  " .. divider .. "  "))
    end

    local resultLine = GetPlayerResultText(match)
    local outcomeResultIcon = GetOutcomeBannerResultIcon(match)
    if BL.outcomeBannerTeamIcon then
        if outcomeResultIcon then
            BL.outcomeBannerTeamIcon:SetTexture(outcomeResultIcon)
            BL.outcomeBannerTeamIcon:SetHidden(false)
        else
            BL.outcomeBannerTeamIcon:SetHidden(true)
        end
    end

    if BL.matchGameTypeLabel then
        BL.matchGameTypeLabel:SetText(GetCompactGameTypeName(match.gameType))
    end

    if BL.matchOutcomeText then
        BL.matchOutcomeText:SetText(GetPlayerResultDisplayText(match))
        if resultLine == "Loss" then
            BL.matchOutcomeText:SetColor(0.58, 0.57, 0.53, 1)
        else
            BL.matchOutcomeText:SetColor(1, 1, 1, 1)
        end
    end
    local teamOutcomeRows = BuildTeamOutcomeRows(match)
    local teamByAlliance = {}
    for _, team in ipairs(teamOutcomeRows) do
        teamByAlliance[tonumber(team.alliance) or 0] = team
    end
    local winningAlliance = GetWinningAllianceForTeamBlocks(match, teamByAlliance)

    local visibleTeamCount = 0
    for _, entry in ipairs(BL.teamBlockDisplayOrder or {}) do
        if teamByAlliance[entry.alliance] then visibleTeamCount = visibleTeamCount + 1 end
    end
    local TWO_TEAM_INSET = 30  -- px to shift outer blocks inward for 2-team matches

    for _, entry in ipairs(BL.teamBlockDisplayOrder or {}) do
        local allianceId = entry.alliance
        local tb = BL.teamBlocks and BL.teamBlocks[allianceId]
        if tb then
            -- Adjust horizontal position for 2-team vs 3-team matches.
            if visibleTeamCount == 2 then
                -- For 2-team matches, inset Fire Drakes (left) and Pit Daemons (right).
                if allianceId == BATTLEGROUND_ALLIANCE_FIRE_DRAKES then
                    tb.block:ClearAnchors()
                    tb.block:SetAnchor(TOPLEFT, BL.teamSummaryBlock, TOPLEFT, entry.xOffset + TWO_TEAM_INSET, 0)
                elseif allianceId == BATTLEGROUND_ALLIANCE_PIT_DAEMONS then
                    tb.block:ClearAnchors()
                    tb.block:SetAnchor(TOPLEFT, BL.teamSummaryBlock, TOPLEFT, entry.xOffset - TWO_TEAM_INSET, 0)
                else
                    tb.block:ClearAnchors()
                    tb.block:SetAnchor(TOPLEFT, BL.teamSummaryBlock, TOPLEFT, entry.xOffset, 0)
                end
            else
                -- 3-team: restore original positions.
                tb.block:ClearAnchors()
                tb.block:SetAnchor(TOPLEFT, BL.teamSummaryBlock, TOPLEFT, entry.xOffset, 0)
            end

            local team = teamByAlliance[allianceId]
            if team then
                if tb.logo then tb.logo:SetTexture(GetPlayerTableTeamIcon(allianceId)) end
                tb.score:SetText(FormatBigNumber(team.score))
                if tb.kdLabel then tb.kdLabel:SetText("KD: " .. FormatKD(team.kd)) end
                tb.vals.kills:SetText(FormatBigNumber(team.kills))
                tb.vals.deaths:SetText(FormatBigNumber(team.deaths))
                tb.vals.damage:SetText(FormatBigNumber(team.damage))
                tb.vals.healing:SetText(FormatBigNumber(team.healing))
                if tb.logo then tb.logo:SetHidden(false) end
                if tb.teamIcon then tb.teamIcon:SetHidden(false) end
                if tb.leaderIcon then tb.leaderIcon:SetHidden(winningAlliance ~= allianceId) end
                tb.score:SetHidden(false)
                if tb.kdLabel then tb.kdLabel:SetHidden(false) end
                for _, icon in pairs(tb.icons) do icon:SetHidden(false) end
                for _, val  in pairs(tb.vals)  do val:SetHidden(false)  end
                tb.stripe:SetHidden(false)
                tb.noData:SetHidden(true)
                if tb.frame then tb.frame:SetHidden(false) end
            else
                -- No saved data for this alliance in this match.
                if tb.logo then tb.logo:SetHidden(true) end
                if tb.teamIcon then tb.teamIcon:SetHidden(true) end
                if tb.leaderIcon then tb.leaderIcon:SetHidden(true) end
                tb.score:SetHidden(true)
                if tb.kdLabel then tb.kdLabel:SetHidden(true) end
                for _, icon in pairs(tb.icons) do icon:SetHidden(true) end
                for _, val  in pairs(tb.vals)  do val:SetHidden(true)  end
                tb.stripe:SetHidden(true)
                tb.noData:SetHidden(false)
                if tb.frame then tb.frame:SetHidden(true) end
            end
        end
    end

    -- Populate permanent player table controls (created once in BuildUI).
    -- No controls are created here - only SetText, SetTexture, SetHidden, SetColor.
    local pt = BL.ptControls
    if not pt then return end

    -- Header: update sort highlight colours and reposition the single sort icon.
    local activeSort = BL.currentSort and BL.currentSort.matchId == match.id and BL.currentSort or nil
    for _, col in ipairs(columns) do
        local hdr = pt.headers[col.key]
        if hdr then
            local isActive = activeSort and (activeSort.key == col.key or (col.key == "teamIcon" and activeSort.groupByTeam))
            local color = isActive and {1, 0.82, 0.28, 1} or {0.80, 0.76, 0.66, 1}
            hdr:SetColor(unpack(color))
            hdr._normalColor = color
            -- Wire up sort handler to the current match (key doesn't change, matchId might).
            if col.sortable then
                hdr:SetHandler("OnMouseUp", function(_, button, upInside)
                    if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
                        BL.SortDetails(match.id, col.key)
                    end
                end)
            end
        end
    end
    if activeSort then
        local col = nil
        for _, c in ipairs(columns) do if c.key == activeSort.key then col = c break end end
        if col then
            pt.sortIcon:SetTexture(activeSort.ascending and SORT_ICON_UP or SORT_ICON_DOWN)
            pt.sortIcon:ClearAnchors()
            pt.sortIcon:SetAnchor(RIGHT, BL.playerTable, TOPLEFT, col.x + col.w - 2, 15)
            pt.sortIcon:SetHidden(false)
        end
    else
        pt.sortIcon:SetHidden(true)
    end

    local sortedPlayers = BL.GetSortedPlayers(match)
    local MAX_PLAYER_ROWS = #(BL.ptControls and BL.ptControls.rows or {})
    for i = 1, MAX_PLAYER_ROWS do
        local slot   = pt.rows[i]
        local player = sortedPlayers[i]
        if not slot then break end
        if player then
            local playerRowKey = tostring(player.displayName or "") .. "|" .. tostring(player.characterName or "") .. "|" .. tostring(i)
            local isSelected   = BL.selectedPlayerRowKey == playerRowKey
            local cellColor    = player.isLocalPlayer and {1, 0.82, 0.28, 1} or {0.88, 0.86, 0.78, 0.96}

            local tc = allianceColours[tonumber(player.alliance)] or {0.20, 0.20, 0.20}
            local isMvp = player.isTeamMvp == true
            if isSelected then
                slot.bg:SetCenterColor(0.10, 0.080, 0.032, 0.52)
            elseif isMvp then
                slot.bg:SetCenterColor(math.min(1, tc[1] + 0.05), math.min(1, tc[2] + 0.05), math.min(1, tc[3] + 0.05), 0.24)
            else
                slot.bg:SetCenterColor(tc[1], tc[2], tc[3], 0.14)
            end
            -- Keep the one-pixel inter-row gap visually uniform. The previous
            -- selected/MVP outline added an extra horizontal edge that could look
            -- like a team divider; their fill treatment and MVP icon remain.
            slot.bg:SetEdgeColor(0, 0, 0, 0)
            local function onRowClick(control, button, upInside)
                if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
                    BL.selectedPlayerRowKey = playerRowKey
                    BL.RefreshDetails(match)
                elseif upInside and button == MOUSE_BUTTON_INDEX_RIGHT then
                    BL.ShowPlayerContextMenu(control, player)
                end
            end
            slot.bg:SetMouseEnabled(true)
            slot.bg:SetHandler("OnMouseUp", onRowClick)

            slot.teamTex:SetTexture(GetPlayerTableTeamIcon(player.alliance))
            slot.teamTex:SetMouseEnabled(true)
            slot.teamTex:SetHandler("OnMouseEnter", function(ctrl)
                ZO_Tooltips_ShowTextTooltip(ctrl, BOTTOM, allianceNames[player.alliance] or "Team")
            end)
            slot.teamTex:SetHandler("OnMouseExit", function() ZO_Tooltips_HideTextTooltip() end)
            slot.teamTex:SetHandler("OnMouseUp", onRowClick)
            if slot.winnerTex then
                local showMvpIcon = isMvp
                slot.winnerTex:SetHidden(not showMvpIcon)
                slot.winnerTex:SetHandler("OnMouseUp", onRowClick)
                if showMvpIcon then
                    slot.winnerTex:SetHandler("OnMouseEnter", function()
                        BL.ShowMvpPanel(player)
                    end)
                    slot.winnerTex:SetHandler("OnMouseExit", function()
                        if BL.vars and BL.vars.autoShowHistorySweetroll == true then
                            local autoPlayer = GetLocalTeamMvpPlayer(match)
                            if autoPlayer then
                                BL.ShowMvpPanel(autoPlayer)
                            else
                                BL.HideMvpPanel()
                            end
                        else
                            BL.HideMvpPanel()
                        end
                    end)
                else
                    slot.winnerTex:SetHandler("OnMouseEnter", nil)
                    slot.winnerTex:SetHandler("OnMouseExit", nil)
                end
            end

            slot.classTex:SetTexture(classIcons[player.classId] or BLANK_ICON)
            slot.classTex:SetHandler("OnMouseUp", onRowClick)

            local values = {
                playerName    = FormatPlayerNameCell(player),
                score         = player.score,
                kills         = player.kills,
                deaths        = player.deaths,
                assists       = player.assists,
                damage        = FormatBigNumber(player.damage),
                healing       = FormatBigNumber(player.healing),
                kd            = Num(player.kd) > 0 and FormatKD(player.kd) or "--",
            }
            for _, col in ipairs(columns) do
                local cell = slot.cells[col.key]
                if cell then
                    cell:SetText(tostring(values[col.key] or ""))
                    cell:SetColor(unpack(cellColor))
                    cell:SetMouseEnabled(true)
                    cell:SetHandler("OnMouseUp", onRowClick)
                    cell:SetHandler("OnMouseEnter", nil)
                    cell:SetHandler("OnMouseExit", nil)
                    local tooltipText = player.isLocalPlayer and GetLocalRateTooltipText(match, col.key) or nil
                    if tooltipText then
                        cell:SetHandler("OnMouseEnter", function(ctrl)
                            ZO_Tooltips_ShowTextTooltip(ctrl, TOP, tooltipText)
                        end)
                        cell:SetHandler("OnMouseExit", function()
                            ZO_Tooltips_HideTextTooltip()
                        end)
                    end
                    cell:SetHidden(false)
                end
            end

            slot.bg:SetHidden(false)
            slot.teamTex:SetHidden(false)
            slot.classTex:SetHidden(false)
        else
            slot.bg:SetHidden(true)
            slot.teamTex:SetHidden(true)
            if slot.winnerTex then
                slot.winnerTex:SetHandler("OnMouseEnter", nil)
                slot.winnerTex:SetHandler("OnMouseExit", nil)
                slot.winnerTex:SetHandler("OnMouseUp", nil)
                slot.winnerTex:SetHidden(true)
            end
            slot.classTex:SetHidden(true)
            for _, cell in pairs(slot.cells) do
                cell:SetHandler("OnMouseEnter", nil)
                cell:SetHandler("OnMouseExit", nil)
                cell:SetHidden(true)
            end
        end
    end

    -- Contribution row.
    local contrib   = pt.contrib
    local contribValues = match.playerContribution
    if contribValues and contrib then
        for _, col in ipairs(columns) do
            local cell = contrib.cells[col.key]
            if cell then
                local text = contribValues[col.key]
                if col.key == "playerName" then
                    text = contribValues.characterName
                elseif col.key == "kd" then
                    text = ""
                end
                cell:SetText(tostring(text or ""))
                cell:SetHidden(false)
            end
        end
        contrib.border:SetHidden(false)
        contrib.bg:SetHidden(false)
    elseif contrib then
        contrib.border:SetHidden(true)
        contrib.bg:SetHidden(true)
        for _, cell in pairs(contrib.cells) do cell:SetHidden(true) end
    end

    if BL.vars and BL.vars.autoShowHistorySweetroll == true then
        local autoPlayer = GetLocalTeamMvpPlayer(match)
        if autoPlayer then
            BL.ShowMvpPanel(autoPlayer)
        else
            BL.HideMvpPanel()
        end
    else
        BL.HideMvpPanel()
    end
end

function BL.UpdateHistorySelectionVisuals()
    for matchId, controls in pairs(BL.historyCardControls or {}) do
        local selected = matchId == BL.selectedMatchId
        local match = controls.match

        ApplyHistoryCardBackground(controls, selected)

        if controls.accent then
            controls.accent:SetHidden(not selected)
        end

        if controls.title then
            if selected then
                controls.title:SetColor(1, 0.84, 0.32, 1)
            else
                controls.title:SetColor(0.95, 0.90, 0.76, 1)
            end
        end
    end
end

function BL.SelectMatch(matchId)
    if BL.selectedMatchId == matchId then
        -- Match is already selected; do nothing (no deselect behaviour).
        return
    end

    BL.currentSort = nil
    BL.selectedPlayerRowKey = nil
    BL.selectedMatchId = matchId
    local match = BL.GetMatch(matchId)
    -- Avoid the expensive full-history rebuild when selecting a saved match.
    -- Update only the lightweight selected-card visuals.
    BL.UpdateHistorySelectionVisuals()
    BL.RefreshDetails(match)
end

function BL.PrepareDefaultHistoryOpen()
    -- This is called only when the addon is being opened from outside the Battleboard UI.
    -- Page tab changes inside the addon do not use this path, so the current match
    -- selection survives History -> Match Metrics -> History navigation.
    BL.activePage = BL.activePage or BL.GetDefaultBattleboardPage()
    BL.selectedCharacterKey = ALL_CHARACTERS_KEY
    BL.matchTypeFilter = "All"
    BL.historyFilter = "All"
    BL.teamSizeFilter = "All"
    BL.dateRangeFilter = "All"
    BL.currentSort = nil
    BL.selectedPlayerRowKey = nil

    local latest = BL.GetLastSavedMatch()
    BL.selectedMatchId = latest and latest.id or nil
    BL.historyNeedsRebuild = true
    BL.historyFirstVisibleIndex = 1
    BL.historyScrollIndex = 1
    if BL.historyScroll and BL.historyScroll.SetVerticalScroll then
        BL.historyScroll:SetVerticalScroll(0)
    end
end

function BL.HandleAddonSceneOpening()
    BL.BuildUI()
    BL.AnchorSceneWindow()
    if BL.resetHistoryOnNextOpen then
        BL.PrepareDefaultHistoryOpen()
        BL.resetHistoryOnNextOpen = false
    end
    BL.RefreshHistory(not BL.historyListBuilt or BL.historyNeedsRebuild)

    -- End-of-match loading state: show the window with no selection and a
    -- "Loading..." placeholder until the captured match is saved and selected.
    if BL.pendingMatchLoad then
        BL.selectedMatchId = nil
        BL.UpdateHistorySelectionVisuals()
        BL.RefreshDetails(nil)
        BL.SetActivePage(BL.activePage or BL.GetDefaultBattleboardPage())
        return
    end

    -- Auto-select the most recent visible match if nothing is already selected.
    local match = BL.EnsureVisibleSelection()
    if not match and BL.visibleHistoryMatches and #BL.visibleHistoryMatches > 0 then
        BL.selectedMatchId = BL.visibleHistoryMatches[1].id
        BL.UpdateHistorySelectionVisuals()
        match = BL.visibleHistoryMatches[1]
    end
    BL.RefreshDetails(match)
    BL.SetActivePage(BL.activePage or BL.GetDefaultBattleboardPage())
end

function BL.HandleAddonSceneClosed()
    BL.resetHistoryOnNextOpen = true
end

function BL.IsBattleboardSceneName(sceneName)
    return sceneName == "BattleboardHistory" or sceneName == "BattleboardMetrics" or sceneName == "BattleboardObservatory"
end

function BL.ShowDefaultBattleboardScene()
    BL.BuildUI()

    local sceneName = BL.GetDefaultBattleboardSceneName()
    BL.activePage = BL.GetDefaultBattleboardPage()

    if SCENE_MANAGER:GetScene(sceneName) then
        SCENE_MANAGER:Show(sceneName)
        return
    end

    BL.HandleAddonSceneOpening()
    if BL.window then
        BL.window:SetHidden(false)
    end
end

function BL.Show()
    BL.ShowDefaultBattleboardScene()
end

function BL.Hide()
    BL.HandleAddonSceneClosed()
    if BL.IsBattleboardSceneName(SCENE_MANAGER:GetCurrentSceneName()) then
        SCENE_MANAGER:ShowBaseScene()
    elseif BL.window then
        BL.window:SetHidden(true)
    end
end

function BL.Toggle()
    BL.BuildUI()
    if BL.IsBattleboardSceneName(SCENE_MANAGER:GetCurrentSceneName()) then
        BL.Hide()
    else
        BL.ShowDefaultBattleboardScene()
    end
end
