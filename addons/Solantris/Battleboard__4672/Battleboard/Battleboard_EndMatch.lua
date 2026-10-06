-- Battleboard_EndMatch.lua  (center-screen post-match scoreboard overlay)
-- Part of Battleboard. This intentionally does not use the LibMainMenu scene.

local BL = Battleboard
local _x = BL.__constants

local BLANK_ICON = _x.BLANK_ICON
local SORT_ICON_UP = _x.SORT_ICON_UP
local SORT_ICON_DOWN = _x.SORT_ICON_DOWN
local classIcons = _x.classIcons
local allianceColours = _x.allianceColours
local allianceNames = _x.allianceNames
local GetPlayerTableTeamIcon = _x.GetPlayerTableTeamIcon
local GetOutcomeBannerResultIcon = _x.GetOutcomeBannerResultIcon
local GetPlayerResultText = _x.GetPlayerResultText
local GetPlayerResultDisplayText = _x.GetPlayerResultDisplayText
local GetDisplayMatchNumber = _x.GetDisplayMatchNumber
local GetCompactGameTypeName = _x.GetCompactGameTypeName
local GetAllianceDisplayName = _x.GetAllianceDisplayName
local BaseCreateLabel = _x.CreateLabel
local CreateSoftFill = _x.CreateSoftFill
local SetHiddenIfControl = _x.SetHiddenIfControl
local Num = _x.Num
local FormatBigNumber = _x.FormatBigNumber
local FormatTimestamp = _x.FormatTimestamp
local IsNumericSortKey = _x.IsNumericSortKey
local MAX_SCOREBOARD_PLAYERS = _x.MAX_SCOREBOARD_PLAYERS
local END_MATCH_ROW_HEIGHT = 22
local END_MATCH_ROW_STRIDE = 24
local END_MATCH_EXTRA_HEIGHT = math.max(0, MAX_SCOREBOARD_PLAYERS - 16) * END_MATCH_ROW_STRIDE
local LAYOUT_SCALE = 1.35
local TEXT_SCALE = 1.5
local PLAYER_NAME_EXTRA_WIDTH = 60
local STAT_COLUMN_EXTRA_WIDTH = 34
local PANEL_HEIGHT_TRIM = 0
local OVERLAY_MARGIN = 20
local MVP_STAT_ICONS = {
    kills = "/esoui/art/compass/ava_murderball_neutral.dds",
    deaths = "/esoui/art/tutorial/poi_cemetary_complete.dds",
    damage = "/esoui/art/addons/gamepad/gp_mod_listing_category_combat.dds",
    healing = "/esoui/art/lfg/gamepad/lfg_roleicon_healer_down.dds",
}
local PLAYER_TABLE_MVP_ICON = "/esoui/art/ava/ava_rankicon64_general.dds"

local function s(value)
    return math.floor((tonumber(value) or 0) * LAYOUT_SCALE + 0.5)
end

local function CreateLabel(...)
    local label = BaseCreateLabel(...)
    if label and label.SetScale then label:SetScale(TEXT_SCALE) end
    return label
end

local function BuildEndMatchColumns()
    local result = {}
    local x = 0
    for index, source in ipairs(_x.columns) do
        local col = {}
        for key, value in pairs(source) do
            col[key] = value
        end
        col.w = s(col.w)
        if col.key == "playerName" then
            col.w = col.w + PLAYER_NAME_EXTRA_WIDTH
        elseif not col.skipCell then
            col.w = col.w + STAT_COLUMN_EXTRA_WIDTH
        end
        col.x = x
        result[index] = col
        x = x + col.w
        if index < #_x.columns then
            x = x + s(col.gap or _x.DETAIL_TABLE_COLUMN_GAP)
        end
    end
    return result, x + s(30)
end

local columns, DETAIL_TABLE_WIDTH = BuildEndMatchColumns()
local DETAIL_TABLE_BODY_FONT = _x.DETAIL_TABLE_BODY_FONT
local PAGE_ONE_PANEL_HEIGHT = s(_x.PAGE_ONE_PANEL_HEIGHT + END_MATCH_EXTRA_HEIGHT) - PANEL_HEIGHT_TRIM
local PAGE_ONE_FOOTER_HEIGHT = s(_x.PAGE_ONE_FOOTER_HEIGHT)

local OVERLAY_SCALE = 1
local BASE_DETAIL_X = OVERLAY_MARGIN
local BASE_DETAIL_Y = s(10)
local BASE_WINDOW_WIDTH = DETAIL_TABLE_WIDTH + OVERLAY_MARGIN * 2
local BASE_WINDOW_HEIGHT = BASE_DETAIL_Y + PAGE_ONE_PANEL_HEIGHT + PAGE_ONE_FOOTER_HEIGHT + s(10)
local TEAM_BLOCK_HEIGHT = s(105)
local PLAYER_TABLE_HEIGHT = s(457 + END_MATCH_EXTRA_HEIGHT)

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

local function BuildRawMvpStats(player)
    if not player then return nil end
    return {
        kills = Num(player.kills),
        deaths = Num(player.deaths),
        damage = Num(player.damage),
        healing = Num(player.healing),
    }
end

local function GetLocalTeamMvpPlayer(match)
    if not match then return nil end

    local playerAlliance = tonumber(match.playerAlliance) or 0
    if playerAlliance <= 0 then
        for _, player in ipairs(match.players or {}) do
            if player and player.isLocalPlayer then
                playerAlliance = tonumber(player.alliance) or 0
                break
            end
        end
    end
    if playerAlliance <= 0 then return nil end

    for _, player in ipairs(match.players or {}) do
        if player and tonumber(player.alliance) == playerAlliance and player.isTeamMvp == true then
            return player
        end
    end

    return nil
end

local function GetLocalTeamMvp(match)
    local player = GetLocalTeamMvpPlayer(match)
    if not player then return nil end
    return {
        displayName = player.displayName,
        characterName = player.characterName,
        rawStats = BuildRawMvpStats(player),
        alliance = tonumber(player.alliance) or tonumber(match and match.playerAlliance) or 0,
    }
end

local function FormatPlayerNameCell(player)
    local displayName = tostring(player and player.displayName or "")
    local characterName = tostring(player and player.characterName or "")
    if displayName == "" and characterName == "" then return "" end
    if displayName == "" then return characterName end
    if characterName == "" then return displayName end
    return string.format("%s (%s)", displayName, characterName)
end

local function BuildTeamOutcomeRows(match)
    local rows = {}
    if not match or type(match.teamSummaries) ~= "table" then
        return rows
    end

    local byAlliance = {}
    for _, summary in ipairs(match.teamSummaries) do
        if type(summary) == "table" then
            local alliance = tonumber(summary.alliance) or 0
            if alliance > 0 then
                byAlliance[alliance] = summary
            end
        end
    end

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

local function CopyMatchIdToChat(match)
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

function BL.ShouldShowEndMatchScoreboard()
    return BL.vars ~= nil and BL.vars.showEndMatchScoreboard == true
end

function BL.PrintEndMatchSweetroll(match)
    local mvp = GetLocalTeamMvp(match)
    if not mvp then return end

    local userId = tostring(mvp.displayName or "")
    if userId == "" then userId = tostring(mvp.characterName or "the team MVP") end

    local rawStats = mvp.rawStats or {}
    d(string.format(
        "|cFFD700Battleboard|r The sweetroll goes to %s with %s kills, %s damage and %s healing!",
        userId,
        FormatMvpRawStat(rawStats.kills),
        FormatMvpRawStat(rawStats.damage),
        FormatMvpRawStat(rawStats.healing)
    ))
end

function BL.HideEndMatchMvpPanel()
    local overlay = BL.endMatchOverlay
    if not overlay then return end
    if overlay.mvpPanel then overlay.mvpPanel:SetHidden(true) end
    if overlay.mvpPanelReviewNote then overlay.mvpPanelReviewNote:SetHidden(true) end
end

function BL.ShowEndMatchMvpPanel(player)
    local overlay = BL.endMatchOverlay
    if not overlay or not overlay.mvpPanel or not player then return end

    local userId = tostring(player.displayName or "")
    if userId == "" then userId = tostring(player.characterName or "MVP") end

    if overlay.mvpPanelClassIcon then
        overlay.mvpPanelClassIcon:SetTexture(classIcons[tonumber(player.classId) or 0] or BLANK_ICON)
    end
    if overlay.mvpPanelUserId then
        overlay.mvpPanelUserId:SetText(userId)
    end
    if overlay.mvpPanelContributionStats then
        local statValues = {
            kills = player.kills,
            deaths = player.deaths,
            damage = player.damage,
            healing = player.healing,
        }
        for key, controls in pairs(overlay.mvpPanelContributionStats) do
            if controls and controls.value then
                controls.value:SetText(FormatMvpRawStat(statValues[key]))
            end
        end
    end

    overlay.mvpPanel:SetHidden(false)
    if overlay.mvpPanelReviewNote then
        overlay.mvpPanelReviewNote:SetHidden(false)
    end
end

function BL.GetEndMatchSortedPlayers(match)
    local sort = BL.endMatchSort
    if not sort or sort.matchId ~= match.id or not sort.key then
        return match.players or {}
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

    return players
end

function BL.SortEndMatchScoreboard(matchId, key)
    if key == "teamIcon" then
        if BL.endMatchSort and BL.endMatchSort.matchId == matchId then
            BL.endMatchSort.groupByTeam = not BL.endMatchSort.groupByTeam
        else
            BL.endMatchSort = {
                matchId = matchId,
                key = "score",
                ascending = false,
                groupByTeam = true,
            }
        end
    elseif BL.endMatchSort and BL.endMatchSort.matchId == matchId and BL.endMatchSort.key == key then
        BL.endMatchSort.ascending = not BL.endMatchSort.ascending
    else
        BL.endMatchSort = {
            matchId = matchId,
            key = key,
            ascending = not IsNumericSortKey(key),
        }
    end

    BL.RefreshEndMatchScoreboard(BL.endMatchMatch)
end

local function AddBorder(parent, prefix, alpha)
    local borders = {}
    for _, side in ipairs({ "Top", "Bottom", "Left", "Right" }) do
        local border = WINDOW_MANAGER:CreateControl(prefix .. side, parent, CT_BACKDROP)
        border:SetCenterColor(1, 0.82, 0.28, alpha or 0.26)
        border:SetEdgeColor(0, 0, 0, 0)
        borders[side] = border
    end
    borders.Top:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
    borders.Top:SetAnchor(TOPRIGHT, parent, TOPRIGHT, 0, 0)
    borders.Top:SetHeight(1)
    borders.Bottom:SetAnchor(BOTTOMLEFT, parent, BOTTOMLEFT, 0, 0)
    borders.Bottom:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, 0, 0)
    borders.Bottom:SetHeight(1)
    borders.Left:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
    borders.Left:SetAnchor(BOTTOMLEFT, parent, BOTTOMLEFT, 0, 0)
    borders.Left:SetWidth(1)
    borders.Right:SetAnchor(TOPRIGHT, parent, TOPRIGHT, 0, 0)
    borders.Right:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, 0, 0)
    borders.Right:SetWidth(1)
    return borders
end

function BL.BuildEndMatchScoreboard()
    if BL.endMatchOverlay then return end

    local overlay = {}
    BL.endMatchOverlay = overlay

    local window = WINDOW_MANAGER:CreateTopLevelWindow("BattleboardEndMatchScoreboard")
    window:SetDimensions(BASE_WINDOW_WIDTH * OVERLAY_SCALE, BASE_WINDOW_HEIGHT * OVERLAY_SCALE)
    window:ClearAnchors()
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetMouseEnabled(true)
    window:SetMovable(false)
    window:SetClampedToScreen(false)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetDrawTier(DT_HIGH)
    window:SetHidden(true)
    overlay.window = window

    local bg = CreateSoftFill(window, "BattleboardEndMatchScoreboardBg", 0, 0, 0, 1)
    bg:SetAnchorFill(window)
    overlay.bg = bg
    AddBorder(window, "BattleboardEndMatchScoreboardBorder", 0.30)

    local close = WINDOW_MANAGER:CreateControl("BattleboardEndMatchCloseX", window, CT_BUTTON)
    close:SetDimensions(s(20), s(20))
    close:SetAnchor(TOPRIGHT, window, TOPRIGHT, -s(8), s(6))
    close:SetFont("ZoFontGameBold")
    close:SetText("X")
    close:SetNormalFontColor(0.76, 0.72, 0.62, 1)
    close:SetMouseOverFontColor(1, 0.86, 0.36, 1)
    close:SetPressedFontColor(1, 0.82, 0.28, 1)
    close:SetDrawLayer(DL_OVERLAY)
    close:SetDrawTier(DT_HIGH)
    if close.SetDrawLevel then close:SetDrawLevel(100) end
    close:SetHandler("OnClicked", function() BL.HideEndMatchScoreboard() end)
    overlay.closeButton = close

    local scaledRoot = WINDOW_MANAGER:CreateControl("BattleboardEndMatchScaledRoot", window, CT_CONTROL)
    scaledRoot:SetDimensions(BASE_WINDOW_WIDTH, BASE_WINDOW_HEIGHT)
    scaledRoot:SetAnchor(CENTER, window, CENTER, 0, 0)
    scaledRoot:SetMouseEnabled(true)
    overlay.scaledRoot = scaledRoot

    local matchDetailsPanel = WINDOW_MANAGER:CreateControl("BattleboardEndMatchDetailsPanel", scaledRoot, CT_CONTROL)
    matchDetailsPanel:SetDimensions(DETAIL_TABLE_WIDTH, PAGE_ONE_PANEL_HEIGHT)
    matchDetailsPanel:SetAnchor(TOPLEFT, scaledRoot, TOPLEFT, BASE_DETAIL_X, BASE_DETAIL_Y)
    overlay.matchDetailsPanel = matchDetailsPanel

    overlay.outcomeBanner = WINDOW_MANAGER:CreateControl("BattleboardEndMatchOutcomeBanner", matchDetailsPanel, CT_CONTROL)
    overlay.outcomeBanner:SetDimensions(DETAIL_TABLE_WIDTH, s(60))
    overlay.outcomeBanner:SetAnchor(TOPLEFT, matchDetailsPanel, TOPLEFT, 0, s(2))

    overlay.outcomeBannerTeamIcon = WINDOW_MANAGER:CreateControl("BattleboardEndMatchOutcomeBannerTeamIcon", overlay.outcomeBanner, CT_TEXTURE)
    overlay.outcomeBannerTeamIcon:SetDimensions(s(592), s(296))
    overlay.outcomeBannerTeamIcon:SetAnchor(CENTER, overlay.outcomeBanner, CENTER, 0, s(116))
    overlay.outcomeBannerTeamIcon:SetAlpha(1)
    overlay.outcomeBannerTeamIcon:SetDrawLayer(DL_BACKGROUND)
    overlay.outcomeBannerTeamIcon:SetDrawTier(DT_LOW)
    if overlay.outcomeBannerTeamIcon.SetDrawLevel then
        overlay.outcomeBannerTeamIcon:SetDrawLevel(0)
    end
    overlay.outcomeBannerTeamIcon:SetHidden(true)

    overlay.matchSummaryPanel = WINDOW_MANAGER:CreateControl("BattleboardEndMatchSummaryPanel", matchDetailsPanel, CT_CONTROL)
    overlay.matchSummaryPanel:SetDimensions(DETAIL_TABLE_WIDTH, TEAM_BLOCK_HEIGHT)
    overlay.matchSummaryPanel:SetAnchor(TOPLEFT, overlay.outcomeBanner, BOTTOMLEFT, 0, s(17))

    overlay.matchGameTypeLabel = CreateLabel(overlay.outcomeBanner, "BattleboardEndMatchGameTypeLabel", "", "ZoFontWinH5", {0.95, 0.90, 0.76, 1})
    overlay.matchGameTypeLabel:SetAnchor(TOP, overlay.outcomeBanner, TOP, 0, s(4))
    overlay.matchGameTypeLabel:SetDimensions(DETAIL_TABLE_WIDTH, s(22))
    overlay.matchGameTypeLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    overlay.matchGameTypeLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    overlay.matchGameTypeLabel:SetDrawLayer(DL_OVERLAY)
    overlay.matchGameTypeLabel:SetDrawTier(DT_HIGH)
    overlay.matchGameTypeLabel:SetHidden(true)

    overlay.matchOutcomeText = CreateLabel(overlay.outcomeBanner, "BattleboardEndMatchOutcomeText", "", "ZoFontWinH1", {0.84, 0.82, 0.70, 1})
    overlay.matchOutcomeText:SetAnchor(BOTTOM, overlay.outcomeBanner, BOTTOM, 0, -s(4))
    overlay.matchOutcomeText:SetDimensions(DETAIL_TABLE_WIDTH, s(34))
    overlay.matchOutcomeText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    overlay.matchOutcomeText:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    overlay.matchOutcomeText:SetDrawLayer(DL_OVERLAY)
    overlay.matchOutcomeText:SetDrawTier(DT_HIGH)
    if overlay.matchOutcomeText.SetScale then overlay.matchOutcomeText:SetScale(TEXT_SCALE * 1.1) end
    if overlay.matchOutcomeText.SetDrawLevel then overlay.matchOutcomeText:SetDrawLevel(100) end
    if overlay.matchOutcomeText.SetShadowColor then overlay.matchOutcomeText:SetShadowColor(0, 0, 0, 0) end
    if overlay.matchOutcomeText.SetShadow then overlay.matchOutcomeText:SetShadow(0, 0, 0, 0) end

    overlay.teamSummaryBlock = WINDOW_MANAGER:CreateControl("BattleboardEndMatchTeamSummaryBlock", overlay.matchSummaryPanel, CT_CONTROL)
    overlay.teamSummaryBlock:SetDimensions(DETAIL_TABLE_WIDTH, TEAM_BLOCK_HEIGHT)
    overlay.teamSummaryBlock:SetAnchor(TOPLEFT, overlay.matchSummaryPanel, TOPLEFT, 0, 0)

    local TB_PAD       = s(6)
    local TB_STRIPE_H  = s(4)
    local TB_BLOCK_W   = math.floor(DETAIL_TABLE_WIDTH / 3)
    local TB_TEAM_ICON_SZ = s(66)
    local TB_LOGO_COL_W   = s(60)
    local TB_TEAM_ICON_X  = TB_PAD + math.floor((TB_LOGO_COL_W - s(48)) / 2)
    local TB_TEAM_ICON_Y  = s(10)
    local TB_GROUP_LEADER_ICON = "/esoui/art/icons/mapkey/mapkey_groupleader.dds"
    local TB_GROUP_LEADER_ICON_SZ = s(22)
    local TB_GROUP_LEADER_ICON_X = TB_TEAM_ICON_X + math.floor((TB_TEAM_ICON_SZ - TB_GROUP_LEADER_ICON_SZ) / 2)
    local TB_GROUP_LEADER_ICON_Y = TB_TEAM_ICON_Y - s(20)
    local TB_SCORE_H  = s(26)
    local TB_SCORE_X  = TB_PAD + s(10) - 20
    local TB_SCORE_Y  = s(58)
    local TB_SCORE_W  = TB_LOGO_COL_W
    local TB_STAT_X0    = TB_PAD + TB_LOGO_COL_W + s(6)
    local TB_STAT_AREA  = TB_BLOCK_W - TB_STAT_X0 - TB_PAD
    local TB_COL_W      = math.floor(TB_STAT_AREA / 5)
    local TB_ICON_ROW_Y = s(38)
    local TB_VAL_ROW_Y  = TB_ICON_ROW_Y + s(36)
    local TB_ICON_SZ   = s(22)
    local TB_ICON_DRAW = s(30)
    local TB_VAL_H     = s(22)
    local TB_COLS = {
        { key = "Kills",   statKey = "kills",   x = TB_STAT_X0 + 0 * TB_COL_W, w = TB_COL_W },
        { key = "Deaths",  statKey = "deaths",  x = TB_STAT_X0 + 1 * TB_COL_W, w = TB_COL_W },
        { key = "Damage",  statKey = "damage",  x = TB_STAT_X0 + 2 * TB_COL_W, w = TB_COL_W },
        { key = "Healing", statKey = "healing", x = TB_STAT_X0 + 3 * TB_COL_W, w = TB_COL_W },
        { key = "KD",      statKey = "kd",      x = TB_STAT_X0 + 4 * TB_COL_W, w = TB_COL_W },
    }
    for _, col in ipairs(TB_COLS) do
        col.cx = col.x + math.floor(col.w / 2)
    end
    local TB_ICON_PATHS = {
        Kills   = "/esoui/art/compass/ava_murderball_neutral.dds",
        Deaths  = "/esoui/art/tutorial/poi_cemetary_complete.dds",
        Damage  = "/esoui/art/addons/gamepad/gp_mod_listing_category_combat.dds",
        Healing = "/esoui/art/lfg/gamepad/lfg_roleicon_healer_down.dds",
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
    overlay.teamBlockDisplayOrder = TB_DISPLAY_ORDER
    overlay.teamBlocks = {}

    for _, entry in ipairs(TB_DISPLAY_ORDER) do
        local allianceId = entry.alliance
        local aName = tostring(allianceId)
        local block = WINDOW_MANAGER:CreateControl("BattleboardEndMatchTeamBlock_" .. aName, overlay.teamSummaryBlock, CT_CONTROL)
        block:SetDimensions(TB_BLOCK_W, TEAM_BLOCK_HEIGHT)
        block:SetAnchor(TOPLEFT, overlay.teamSummaryBlock, TOPLEFT, entry.xOffset, 0)

        local score = CreateLabel(block, "BattleboardEndMatchTeamBlockScore_" .. aName, "", "ZoFontWinH1", {0.92, 0.84, 0.62, 1})
        score:SetAnchor(TOPLEFT, block, TOPLEFT, TB_SCORE_X, TB_SCORE_Y)
        score:SetDimensions(TB_SCORE_W, TB_SCORE_H)
        score:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        score:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        score:SetDrawLayer(DL_OVERLAY)
        score:SetDrawTier(DT_HIGH)
        if score.SetDrawLevel then score:SetDrawLevel(30) end

        local teamIcon = WINDOW_MANAGER:CreateControl("BattleboardEndMatchTeamBlockTeamIcon_" .. aName, block, CT_TEXTURE)
        teamIcon:SetTexture(GetPlayerTableTeamIcon(allianceId))
        teamIcon:SetDimensions(TB_TEAM_ICON_SZ, TB_TEAM_ICON_SZ)
        teamIcon:SetAnchor(TOPLEFT, block, TOPLEFT, TB_TEAM_ICON_X, TB_TEAM_ICON_Y)
        teamIcon:SetDrawLayer(DL_CONTROLS)
        teamIcon:SetDrawTier(DT_LOW)
        if teamIcon.SetDrawLevel then teamIcon:SetDrawLevel(0) end
        teamIcon:SetMouseEnabled(true)
        teamIcon:SetHandler("OnMouseEnter", function(ctrl)
            ZO_Tooltips_ShowTextTooltip(ctrl, BOTTOM, GetAllianceDisplayName(allianceId))
        end)
        teamIcon:SetHandler("OnMouseExit", function() ZO_Tooltips_HideTextTooltip() end)

        local leaderIcon = WINDOW_MANAGER:CreateControl("BattleboardEndMatchTeamBlockGroupLeaderIcon_" .. aName, block, CT_TEXTURE)
        leaderIcon:SetTexture(TB_GROUP_LEADER_ICON)
        leaderIcon:SetDimensions(TB_GROUP_LEADER_ICON_SZ, TB_GROUP_LEADER_ICON_SZ)
        leaderIcon:SetAnchor(TOPLEFT, block, TOPLEFT, TB_GROUP_LEADER_ICON_X, TB_GROUP_LEADER_ICON_Y)
        leaderIcon:SetDrawLayer(DL_CONTROLS)
        leaderIcon:SetDrawTier(DT_HIGH)
        leaderIcon:SetHidden(true)

        local icons = {}
        local vals = {}
        for _, col in ipairs(TB_COLS) do
            local tex = nil
            if TB_ICON_PATHS[col.key] then
                tex = WINDOW_MANAGER:CreateControl("BattleboardEndMatchTeamBlockIcon_" .. aName .. "_" .. col.key, block, CT_TEXTURE)
                tex:SetTexture(TB_ICON_PATHS[col.key])
                tex:SetDimensions(TB_ICON_DRAW, TB_ICON_DRAW)
                tex:SetAnchor(CENTER, block, TOPLEFT, col.cx, TB_ICON_ROW_Y + math.floor(TB_ICON_SZ / 2))
                tex:SetDrawLayer(DL_CONTROLS)
                tex:SetDrawTier(DT_HIGH)
                icons[col.statKey] = tex
            else
                tex = CreateLabel(block, "BattleboardEndMatchTeamBlockIcon_" .. aName .. "_" .. col.key, col.key, "ZoFontWinH4", {0.80, 0.76, 0.66, 1})
                tex:SetAnchor(CENTER, block, TOPLEFT, col.cx, TB_ICON_ROW_Y + math.floor(TB_ICON_SZ / 2))
                tex:SetDimensions(col.w, TB_ICON_DRAW)
                tex:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
                tex:SetVerticalAlignment(TEXT_ALIGN_CENTER)
                icons[col.statKey] = tex
            end

            local val = CreateLabel(block, "BattleboardEndMatchTeamBlockVal_" .. aName .. "_" .. col.key, "", "ZoFontWinH4", {0.88, 0.86, 0.78, 1})
            val:SetAnchor(TOP, block, TOPLEFT, col.cx, TB_VAL_ROW_Y)
            val:SetDimensions(col.w, TB_VAL_H)
            val:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            val:SetVerticalAlignment(TEXT_ALIGN_CENTER)
            vals[col.statKey] = val
        end

        local stripe = WINDOW_MANAGER:CreateControl("BattleboardEndMatchTeamBlockStripe_" .. aName, block, CT_BACKDROP)
        stripe:SetDimensions(TB_BLOCK_W - s(4), TB_STRIPE_H)
        stripe:SetAnchor(BOTTOMLEFT, block, BOTTOMLEFT, s(2), 0)
        local ac = TB_ACCENT[allianceId]
        if ac then stripe:SetCenterColor(unpack(ac)) else stripe:SetCenterColor(0, 0, 0, 0) end
        stripe:SetEdgeColor(0, 0, 0, 0)

        local noData = CreateLabel(block, "BattleboardEndMatchTeamBlockNoData_" .. aName, "", "ZoFontWinH1", {0.92, 0.84, 0.62, 1})
        noData:SetAnchor(CENTER, block, CENTER, 0, 0)
        noData:SetDimensions(TB_BLOCK_W, s(40))
        noData:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        noData:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        noData:SetHidden(true)

        overlay.teamBlocks[allianceId] = {
            block = block,
            logo = nil,
            teamIcon = teamIcon,
            leaderIcon = leaderIcon,
            score = score,
            icons = icons,
            vals = vals,
            stripe = stripe,
            noData = noData,
        }
    end

    overlay.playerTable = WINDOW_MANAGER:CreateControl("BattleboardEndMatchPlayerTable", matchDetailsPanel, CT_CONTROL)
    overlay.playerTable:SetAnchor(TOPLEFT, overlay.matchSummaryPanel, BOTTOMLEFT, 0, s(4))
    overlay.playerTable:SetDimensions(DETAIL_TABLE_WIDTH, PLAYER_TABLE_HEIGHT)
    overlay.playerTable:SetMouseEnabled(true)
    overlay.playerTable:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT and BL.endMatchSelectedPlayerRowKey then
            BL.endMatchSelectedPlayerRowKey = nil
            BL.RefreshEndMatchScoreboard(BL.endMatchMatch)
        end
    end)

    overlay.ptControls = { headers = {}, headerIcons = {}, rows = {} }
    local pt = overlay.ptControls
    local MAX_PLAYER_ROWS = MAX_SCOREBOARD_PLAYERS
    local HEADER_H = s(30)
    local ROW_H = s(END_MATCH_ROW_HEIGHT)
    local ROW_STRIDE = s(END_MATCH_ROW_STRIDE)
    -- Labels in this overlay are scaled by TEXT_SCALE. Keep their unscaled
    -- control height small enough that the rendered bounds equal the row height.
    local ROW_LABEL_H = math.max(1, math.floor(ROW_H / TEXT_SCALE + 0.5))
    local HEADER_ICON_H = s(28)

    local ptHeaderBg = WINDOW_MANAGER:CreateControl("BattleboardEndMatchPTHeaderBg", overlay.playerTable, CT_BACKDROP)
    ptHeaderBg:SetDimensions(DETAIL_TABLE_WIDTH, HEADER_H)
    ptHeaderBg:SetAnchor(TOPLEFT, overlay.playerTable, TOPLEFT, 0, 0)
    ptHeaderBg:SetCenterColor(0.010, 0.009, 0.007, 0.86)
    ptHeaderBg:SetEdgeColor(0, 0, 0, 0)
    pt.headerBg = ptHeaderBg

    local ptHeaderUnderline = WINDOW_MANAGER:CreateControl("BattleboardEndMatchPTHeaderUnderline", overlay.playerTable, CT_BACKDROP)
    ptHeaderUnderline:SetDimensions(DETAIL_TABLE_WIDTH, s(2))
    ptHeaderUnderline:SetAnchor(BOTTOMLEFT, ptHeaderBg, BOTTOMLEFT, 0, 0)
    ptHeaderUnderline:SetCenterColor(0.549019607843, 0.541176470588, 0.450980392157, 1)
    ptHeaderUnderline:SetEdgeColor(0, 0, 0, 0)
    ptHeaderUnderline:SetDrawLayer(DL_CONTROLS)
    ptHeaderUnderline:SetDrawTier(DT_HIGH)

    for _, col in ipairs(columns) do
        local hdr = CreateLabel(overlay.playerTable, "BattleboardEndMatchPTHeader_" .. col.key, col.text, "ZoFontWinH4", {0.80, 0.76, 0.66, 1})
        hdr:SetAnchor(TOPLEFT, overlay.playerTable, TOPLEFT, col.x, s(1))
        hdr:SetDimensions(col.w, HEADER_H - s(8))
        hdr:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        if col.align then hdr:SetHorizontalAlignment(col.align) end
        if col.sortable then
            hdr:SetMouseEnabled(true)
            hdr:SetHandler("OnMouseEnter", function() hdr:SetColor(1, 0.92, 0.52, 1) end)
            hdr:SetHandler("OnMouseExit", function()
                local normal = overlay.ptControls.headers[col.key]._normalColor or {0.80, 0.76, 0.66, 1}
                hdr:SetColor(unpack(normal))
            end)
            hdr:SetHandler("OnMouseUp", function(_, button, upInside)
                if upInside and button == MOUSE_BUTTON_INDEX_LEFT and BL.endMatchMatch then
                    BL.SortEndMatchScoreboard(BL.endMatchMatch.id, col.key)
                end
            end)
        end
        hdr._normalColor = {0.80, 0.76, 0.66, 1}
        pt.headers[col.key] = hdr

        if col.kind == "iconHeader" and col.iconPath then
            local iconY = math.floor((HEADER_H - HEADER_ICON_H) / 2)
            local tex = WINDOW_MANAGER:CreateControl("BattleboardEndMatchPTHeaderIcon_" .. col.key, overlay.playerTable, CT_TEXTURE)
            tex:SetTexture(col.iconPath)
            tex:SetDimensions(HEADER_ICON_H, HEADER_ICON_H)
            local iconX = col.x + math.floor(col.w / 2)
            if col.key == "damage" or col.key == "healing" then
                iconX = iconX + 15
            end
            tex:SetAnchor(TOP, overlay.playerTable, TOPLEFT, iconX, iconY)
            tex:SetDrawLayer(DL_CONTROLS)
            tex:SetDrawTier(DT_HIGH)
            tex:SetMouseEnabled(false)
            pt.headerIcons[col.key] = tex
        end
    end

    local ptSortIcon = WINDOW_MANAGER:CreateControl("BattleboardEndMatchPTSortIcon", overlay.playerTable, CT_TEXTURE)
    ptSortIcon:SetDimensions(s(12), s(12))
    ptSortIcon:SetAnchor(TOPLEFT, overlay.playerTable, TOPLEFT, 0, s(15))
    ptSortIcon:SetMouseEnabled(false)
    ptSortIcon:SetHidden(true)
    pt.sortIcon = ptSortIcon

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
    for i = 1, MAX_PLAYER_ROWS do
        local rowY = HEADER_H + (i - 1) * ROW_STRIDE + s(8)
        local bgRow = WINDOW_MANAGER:CreateControl("BattleboardEndMatchPTRowBg_" .. i, overlay.playerTable, CT_BACKDROP)
        bgRow:SetDimensions(DETAIL_TABLE_WIDTH, ROW_H)
        bgRow:SetAnchor(TOPLEFT, overlay.playerTable, TOPLEFT, 0, rowY)
        bgRow:SetCenterColor(0, 0, 0, 0)
        bgRow:SetEdgeColor(0, 0, 0, 0)
        bgRow:SetHidden(true)

        local teamTex = WINDOW_MANAGER:CreateControl("BattleboardEndMatchPTRowTeam_" .. i, overlay.playerTable, CT_TEXTURE)
        local teamIconSize = s(22)
        teamTex:SetDimensions(teamIconSize, teamIconSize)
        if teamColumn then
            teamTex:SetAnchor(TOPLEFT, overlay.playerTable, TOPLEFT, teamColumn.x + math.floor((teamColumn.w - teamIconSize) / 2), rowY + math.floor((ROW_H - teamIconSize) / 2))
        else
            teamTex:SetAnchor(TOPLEFT, overlay.playerTable, TOPLEFT, s(4), rowY)
        end
        teamTex:SetHidden(true)

        local winnerTex = WINDOW_MANAGER:CreateControl("BattleboardEndMatchPTRowWinner_" .. i, overlay.playerTable, CT_TEXTURE)
        local winnerSize = s(22)
        winnerTex:SetTexture(PLAYER_TABLE_MVP_ICON)
        winnerTex:SetDimensions(winnerSize, winnerSize)
        if mvpColumn then
            winnerTex:SetAnchor(TOPLEFT, overlay.playerTable, TOPLEFT, mvpColumn.x + math.floor((mvpColumn.w - winnerSize) / 2), rowY + math.floor((ROW_H - winnerSize) / 2))
        else
            winnerTex:SetAnchor(CENTER, teamTex, CENTER, 0, 0)
        end
        winnerTex:SetDrawLayer(DL_CONTROLS)
        winnerTex:SetDrawTier(DT_HIGH)
        winnerTex:SetMouseEnabled(true)
        winnerTex:SetHidden(true)

        local classTex = WINDOW_MANAGER:CreateControl("BattleboardEndMatchPTRowClass_" .. i, overlay.playerTable, CT_TEXTURE)
        local classIconSize = s(20)
        classTex:SetDimensions(classIconSize, classIconSize)
        if classColumn then
            classTex:SetAnchor(TOPLEFT, overlay.playerTable, TOPLEFT, classColumn.x + math.floor((classColumn.w - classIconSize) / 2), rowY + math.floor((ROW_H - classIconSize) / 2))
        else
            classTex:SetAnchor(TOPLEFT, overlay.playerTable, TOPLEFT, s(36), rowY)
        end
        classTex:SetHidden(true)

        local cells = {}
        for _, col in ipairs(columns) do
            if not col.skipCell then
                local cell = CreateLabel(overlay.playerTable, "BattleboardEndMatchPTCell_" .. i .. "_" .. col.key, "", DETAIL_TABLE_BODY_FONT, {0.88, 0.86, 0.78, 0.96})
                cell:SetAnchor(LEFT, bgRow, LEFT, col.x, 0)
                cell:SetDimensions(col.w, ROW_LABEL_H)
                cell:SetVerticalAlignment(TEXT_ALIGN_CENTER)
                if col.align then cell:SetHorizontalAlignment(col.align) end
                cell:SetHidden(true)
                cells[col.key] = cell
            end
        end

        pt.rows[i] = { bg = bgRow, teamTex = teamTex, winnerTex = winnerTex, classTex = classTex, cells = cells }
    end

    local contribY = HEADER_H + MAX_PLAYER_ROWS * ROW_STRIDE + s(8) + s(10)
    local ptContribBorder = WINDOW_MANAGER:CreateControl("BattleboardEndMatchPTContribBorder", overlay.playerTable, CT_BACKDROP)
    ptContribBorder:SetDimensions(DETAIL_TABLE_WIDTH, s(2))
    ptContribBorder:SetAnchor(TOPLEFT, overlay.playerTable, TOPLEFT, 0, contribY - s(6))
    ptContribBorder:SetCenterColor(0.549019607843, 0.541176470588, 0.450980392157, 1)
    ptContribBorder:SetEdgeColor(0, 0, 0, 0)
    ptContribBorder:SetHidden(true)

    local ptContribBg = WINDOW_MANAGER:CreateControl("BattleboardEndMatchPTContribBg", overlay.playerTable, CT_BACKDROP)
    ptContribBg:SetDimensions(DETAIL_TABLE_WIDTH, ROW_H)
    ptContribBg:SetAnchor(TOPLEFT, overlay.playerTable, TOPLEFT, 0, contribY)
    ptContribBg:SetCenterColor(0, 0, 0, 0)
    ptContribBg:SetEdgeColor(0, 0, 0, 0)
    ptContribBg:SetHidden(true)

    local medalsColX = DETAIL_TABLE_WIDTH
    for _, col in ipairs(columns) do
        if col.key == "score" then
            medalsColX = col.x
            break
        end
    end
    local contribLabelW = s(118)
    local ptContribLabel = CreateLabel(overlay.playerTable, "BattleboardEndMatchPTContribLabel", "", DETAIL_TABLE_BODY_FONT, {0.92, 0.84, 0.62, 1})
    ptContribLabel:SetAnchor(LEFT, ptContribBg, LEFT, medalsColX - contribLabelW - s(28), 0)
    ptContribLabel:SetDimensions(contribLabelW, ROW_LABEL_H)
    ptContribLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    ptContribLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    ptContribLabel:SetHidden(true)

    local ptContribCells = {}
    for _, col in ipairs(columns) do
        if not col.skipCell and col.key ~= "playerName" then
            local align = col.key == "playerName" and TEXT_ALIGN_RIGHT or col.align
            local cell = CreateLabel(overlay.playerTable, "BattleboardEndMatchPTContrib_" .. col.key, "", DETAIL_TABLE_BODY_FONT, {0.92, 0.84, 0.62, 1})
            cell:SetAnchor(LEFT, ptContribBg, LEFT, col.x, 0)
            cell:SetDimensions(col.w, ROW_LABEL_H)
            cell:SetVerticalAlignment(TEXT_ALIGN_CENTER)
            if align then cell:SetHorizontalAlignment(align) end
            cell:SetHidden(true)
            ptContribCells[col.key] = cell
        end
    end
    pt.contrib = { border = ptContribBorder, bg = ptContribBg, label = ptContribLabel, cells = ptContribCells }

    local footer = WINDOW_MANAGER:CreateControl("BattleboardEndMatchFooter", scaledRoot, CT_CONTROL)
    footer:SetDimensions(DETAIL_TABLE_WIDTH, PAGE_ONE_FOOTER_HEIGHT)
    footer:SetAnchor(TOPLEFT, scaledRoot, TOPLEFT, BASE_DETAIL_X, BASE_DETAIL_Y + PAGE_ONE_PANEL_HEIGHT)
    overlay.footer = footer
    local footerDivider = WINDOW_MANAGER:CreateControl("BattleboardEndMatchFooterDivider", footer, CT_BACKDROP)
    footerDivider:SetDimensions(DETAIL_TABLE_WIDTH, 1)
    footerDivider:SetAnchor(TOPLEFT, footer, TOPLEFT, 0, 0)
    footerDivider:SetCenterColor(0.72, 0.72, 0.72, 0.14)
    footerDivider:SetEdgeColor(0, 0, 0, 0)

    overlay.matchMetadata = CreateLabel(footer, "BattleboardEndMatchMetadata", "", "ZoFontGameSmall", {0.74, 0.70, 0.60, 1})
    overlay.matchMetadata:SetAnchor(CENTER, footer, CENTER, 0, 0)
    overlay.matchMetadata:SetDimensions(DETAIL_TABLE_WIDTH - s(20), s(24))
    overlay.matchMetadata:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    overlay.matchMetadata:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    overlay.matchMetadata:SetMouseEnabled(true)
    overlay.matchMetadata:SetHandler("OnMouseEnter", function(ctrl)
        ZO_Tooltips_ShowTextTooltip(ctrl, TOP, "Right-click to copy Match ID to chat")
    end)
    overlay.matchMetadata:SetHandler("OnMouseExit", function() ZO_Tooltips_HideTextTooltip() end)
    overlay.matchMetadata:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_RIGHT then
            CopyMatchIdToChat(BL.endMatchMatch)
        end
    end)

    local mvpPanel = WINDOW_MANAGER:CreateControl("BattleboardEndMatchMVPPanel", scaledRoot, CT_CONTROL)
    mvpPanel:SetDimensions(512, 512)
    mvpPanel:SetAnchor(TOPRIGHT, matchDetailsPanel, TOPLEFT, 45, 0)
    mvpPanel:SetDrawLayer(DL_OVERLAY)
    mvpPanel:SetDrawTier(DT_HIGH)
    mvpPanel:SetHidden(true)
    overlay.mvpPanel = mvpPanel

    local mvpSweetrollArt = WINDOW_MANAGER:CreateControl("BattleboardEndMatchMVPPanelSweetrollArtTexture", mvpPanel, CT_TEXTURE)
    mvpSweetrollArt:SetTexture("/esoui/art/crowncrates/rewards/crowncrate_cardillo_sweetroll.dds")
    mvpSweetrollArt:SetAnchorFill(mvpPanel)
    mvpSweetrollArt:SetDrawLayer(DL_BACKGROUND)
    mvpSweetrollArt:SetDrawTier(DT_LOW)
    if mvpSweetrollArt.SetDrawLevel then mvpSweetrollArt:SetDrawLevel(0) end

    local mvpBg = WINDOW_MANAGER:CreateControl("BattleboardEndMatchMVPPanelBg", mvpPanel, CT_BACKDROP)
    mvpBg:SetDimensions(265, 472)
    mvpBg:SetAnchor(CENTER, mvpPanel, CENTER, 0, 0)
    mvpBg:SetCenterColor(0, 0, 0, 0.80)
    mvpBg:SetEdgeColor(0, 0, 0, 0)
    mvpBg:SetDrawLayer(DL_BACKGROUND)
    mvpBg:SetDrawTier(DT_LOW)
    if mvpBg.SetDrawLevel then mvpBg:SetDrawLevel(10) end

    local mvpMiddle = WINDOW_MANAGER:CreateControl("BattleboardEndMatchMVPPanelMiddleTexture", mvpPanel, CT_TEXTURE)
    mvpMiddle:SetTexture("/esoui/art/crowncrates/crowncrate_card_bg.dds")
    mvpMiddle:SetAnchorFill(mvpPanel)
    mvpMiddle:SetDrawLayer(DL_CONTROLS)
    mvpMiddle:SetDrawTier(DT_LOW)
    if mvpMiddle.SetDrawLevel then mvpMiddle:SetDrawLevel(20) end

    local mvpTop = WINDOW_MANAGER:CreateControl("BattleboardEndMatchMVPPanelTopTexture", mvpPanel, CT_TEXTURE)
    mvpTop:SetTexture("/esoui/art/crowncrates/crowncrate_card_frame_crafting.dds")
    mvpTop:SetAnchorFill(mvpPanel)
    mvpTop:SetDrawLayer(DL_OVERLAY)
    mvpTop:SetDrawTier(DT_HIGH)
    if mvpTop.SetDrawLevel then mvpTop:SetDrawLevel(50) end

    local MVP_GOLD_LINE = {0.80, 0.66, 0.30, 0.95}
    local MVP_GOLD_TEXT = {0.98, 0.86, 0.42, 1}
    local MVP_LINE_WIDTH = 210
    local MVP_LINE_HEIGHT = 3

    overlay.mvpPanelContributorLabel = CreateLabel(mvpPanel, "BattleboardEndMatchMVPPanelContributorLabel", "Highest Contributor", "ZoFontWinH3", MVP_GOLD_TEXT)
    overlay.mvpPanelContributorLabel:SetDimensions(280, 34)
    overlay.mvpPanelContributorLabel:SetAnchor(TOP, mvpPanel, TOP, 0, 129)
    overlay.mvpPanelContributorLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    overlay.mvpPanelContributorLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    overlay.mvpPanelContributorLabel:SetDrawLayer(DL_OVERLAY)
    overlay.mvpPanelContributorLabel:SetDrawTier(DT_HIGH)
    if overlay.mvpPanelContributorLabel.SetDrawLevel then overlay.mvpPanelContributorLabel:SetDrawLevel(100) end

    overlay.mvpPanelContributorLineBottom = WINDOW_MANAGER:CreateControl("BattleboardEndMatchMVPPanelContributorLineBottom", mvpPanel, CT_BACKDROP)
    overlay.mvpPanelContributorLineBottom:SetDimensions(MVP_LINE_WIDTH, MVP_LINE_HEIGHT)
    overlay.mvpPanelContributorLineBottom:SetAnchor(TOP, overlay.mvpPanelContributorLabel, BOTTOM, 0, 8)
    overlay.mvpPanelContributorLineBottom:SetCenterColor(unpack(MVP_GOLD_LINE))
    overlay.mvpPanelContributorLineBottom:SetEdgeColor(0, 0, 0, 0)
    overlay.mvpPanelContributorLineBottom:SetDrawLayer(DL_OVERLAY)
    overlay.mvpPanelContributorLineBottom:SetDrawTier(DT_HIGH)
    if overlay.mvpPanelContributorLineBottom.SetDrawLevel then overlay.mvpPanelContributorLineBottom:SetDrawLevel(100) end

    overlay.mvpPanelClassIcon = WINDOW_MANAGER:CreateControl("BattleboardEndMatchMVPPanelClassIcon", mvpPanel, CT_TEXTURE)
    overlay.mvpPanelClassIcon:SetTexture(BLANK_ICON)
    overlay.mvpPanelClassIcon:SetDimensions(82, 82)
    overlay.mvpPanelClassIcon:SetAnchor(TOP, overlay.mvpPanelContributorLineBottom, BOTTOM, 0, 56)
    overlay.mvpPanelClassIcon:SetDrawLayer(DL_OVERLAY)
    overlay.mvpPanelClassIcon:SetDrawTier(DT_HIGH)
    if overlay.mvpPanelClassIcon.SetDrawLevel then overlay.mvpPanelClassIcon:SetDrawLevel(100) end

    overlay.mvpPanelUserId = CreateLabel(mvpPanel, "BattleboardEndMatchMVPPanelUserId", "", "ZoFontWinH2", {0.98, 0.86, 0.42, 1})
    overlay.mvpPanelUserId:SetAnchor(TOP, overlay.mvpPanelClassIcon, BOTTOM, 0, -2)
    overlay.mvpPanelUserId:SetDimensions(360, 36)
    overlay.mvpPanelUserId:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    overlay.mvpPanelUserId:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    overlay.mvpPanelUserId:SetDrawLayer(DL_OVERLAY)
    overlay.mvpPanelUserId:SetDrawTier(DT_HIGH)
    if overlay.mvpPanelUserId.SetDrawLevel then overlay.mvpPanelUserId:SetDrawLevel(100) end

    overlay.mvpPanelContributionStats = {}
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
        local icon = WINDOW_MANAGER:CreateControl("BattleboardEndMatchMVPPanelContributionIcon_" .. stat.key, mvpPanel, CT_TEXTURE)
        icon:SetTexture(MVP_STAT_ICONS[stat.key] or BLANK_ICON)
        icon:SetDimensions(MVP_STAT_ICON_SIZE, MVP_STAT_ICON_SIZE)
        icon:SetAnchor(BOTTOMLEFT, mvpPanel, BOTTOM, MVP_STAT_COL_X[stat.col], MVP_STAT_ROW_Y[stat.row])
        icon:SetDrawLayer(DL_OVERLAY)
        icon:SetDrawTier(DT_HIGH)
        if icon.SetDrawLevel then icon:SetDrawLevel(100) end

        local value = CreateLabel(mvpPanel, "BattleboardEndMatchMVPPanelContributionValue_" .. stat.key, "", "ZoFontWinH3", {0.88, 0.84, 0.74, 1})
        value:SetAnchor(LEFT, icon, RIGHT, 6, 0)
        value:SetDimensions(MVP_STAT_VALUE_W, MVP_STAT_VALUE_H)
        value:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        value:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        value:SetDrawLayer(DL_OVERLAY)
        value:SetDrawTier(DT_HIGH)
        if value.SetDrawLevel then value:SetDrawLevel(100) end

        overlay.mvpPanelContributionStats[stat.key] = {
            icon = icon,
            value = value,
        }
    end

    overlay.mvpPanelReviewNote = CreateLabel(scaledRoot, "BattleboardEndMatchMVPPanelReviewNote", "(Calculation currently under review)", "ZoFontGameSmall", {0.74, 0.70, 0.60, 1})
    overlay.mvpPanelReviewNote:SetAnchor(TOP, mvpPanel, BOTTOM, 0, 20)
    overlay.mvpPanelReviewNote:SetDimensions(300, 18)
    overlay.mvpPanelReviewNote:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    overlay.mvpPanelReviewNote:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    overlay.mvpPanelReviewNote:SetDrawLayer(DL_OVERLAY)
    overlay.mvpPanelReviewNote:SetDrawTier(DT_HIGH)
    overlay.mvpPanelReviewNote:SetHidden(true)
end

function BL.RefreshEndMatchScoreboard(match)
    local overlay = BL.endMatchOverlay
    if not overlay or not match then return end

    BL.HideEndMatchMvpPanel()
    BL.endMatchMatch = match

    SetHiddenIfControl(overlay.playerTable, false)
    SetHiddenIfControl(overlay.outcomeBanner, false)
    SetHiddenIfControl(overlay.matchSummaryPanel, false)
    SetHiddenIfControl(overlay.teamSummaryBlock, false)
    SetHiddenIfControl(overlay.matchMetadata, false)

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
    overlay.matchMetadata:SetText(table.concat(parts, "  " .. divider .. "  "))

    local resultLine = GetPlayerResultText(match)
    local outcomeResultIcon = GetOutcomeBannerResultIcon(match)
    if overlay.outcomeBannerTeamIcon then
        if outcomeResultIcon then
            overlay.outcomeBannerTeamIcon:SetTexture(outcomeResultIcon)
            overlay.outcomeBannerTeamIcon:SetHidden(false)
        else
            overlay.outcomeBannerTeamIcon:SetHidden(true)
        end
    end
    overlay.matchOutcomeText:SetText(GetPlayerResultDisplayText(match))
    if resultLine == "Loss" then
        overlay.matchOutcomeText:SetColor(0.58, 0.57, 0.53, 1)
    else
        overlay.matchOutcomeText:SetColor(1, 1, 1, 1)
    end

    local teamOutcomeRows = BuildTeamOutcomeRows(match)
    local teamByAlliance = {}
    for _, team in ipairs(teamOutcomeRows) do
        teamByAlliance[tonumber(team.alliance) or 0] = team
    end
    local winningAlliance = GetWinningAllianceForTeamBlocks(match, teamByAlliance)
    local visibleTeamCount = 0
    for _, entry in ipairs(overlay.teamBlockDisplayOrder or {}) do
        if teamByAlliance[entry.alliance] then visibleTeamCount = visibleTeamCount + 1 end
    end
    local TWO_TEAM_INSET = s(30)

    for _, entry in ipairs(overlay.teamBlockDisplayOrder or {}) do
        local allianceId = entry.alliance
        local tb = overlay.teamBlocks and overlay.teamBlocks[allianceId]
        if tb then
            if visibleTeamCount == 2 then
                if allianceId == BATTLEGROUND_ALLIANCE_FIRE_DRAKES then
                    tb.block:ClearAnchors()
                    tb.block:SetAnchor(TOPLEFT, overlay.teamSummaryBlock, TOPLEFT, entry.xOffset + TWO_TEAM_INSET, 0)
                elseif allianceId == BATTLEGROUND_ALLIANCE_PIT_DAEMONS then
                    tb.block:ClearAnchors()
                    tb.block:SetAnchor(TOPLEFT, overlay.teamSummaryBlock, TOPLEFT, entry.xOffset - TWO_TEAM_INSET, 0)
                else
                    tb.block:ClearAnchors()
                    tb.block:SetAnchor(TOPLEFT, overlay.teamSummaryBlock, TOPLEFT, entry.xOffset, 0)
                end
            else
                tb.block:ClearAnchors()
                tb.block:SetAnchor(TOPLEFT, overlay.teamSummaryBlock, TOPLEFT, entry.xOffset, 0)
            end

            local team = teamByAlliance[allianceId]
            if team then
                if tb.logo then tb.logo:SetTexture(GetPlayerTableTeamIcon(allianceId)) end
                tb.score:SetText(FormatBigNumber(team.score))
                tb.vals.kills:SetText(FormatBigNumber(team.kills))
                tb.vals.deaths:SetText(FormatBigNumber(team.deaths))
                tb.vals.damage:SetText(FormatBigNumber(team.damage))
                tb.vals.healing:SetText(FormatBigNumber(team.healing))
                tb.vals.kd:SetText(FormatKD(team.kd))
                if tb.logo then tb.logo:SetHidden(false) end
                if tb.teamIcon then tb.teamIcon:SetHidden(false) end
                if tb.leaderIcon then tb.leaderIcon:SetHidden(winningAlliance ~= allianceId) end
                tb.score:SetHidden(false)
                for _, icon in pairs(tb.icons) do icon:SetHidden(false) end
                for _, val in pairs(tb.vals) do val:SetHidden(false) end
                tb.stripe:SetHidden(false)
                tb.noData:SetHidden(true)
            else
                if tb.logo then tb.logo:SetHidden(true) end
                if tb.teamIcon then tb.teamIcon:SetHidden(true) end
                if tb.leaderIcon then tb.leaderIcon:SetHidden(true) end
                tb.score:SetHidden(true)
                for _, icon in pairs(tb.icons) do icon:SetHidden(true) end
                for _, val in pairs(tb.vals) do val:SetHidden(true) end
                tb.stripe:SetHidden(true)
                tb.noData:SetHidden(false)
            end
        end
    end

    local pt = overlay.ptControls
    if not pt then return end
    local activeSort = BL.endMatchSort and BL.endMatchSort.matchId == match.id and BL.endMatchSort or nil
    for _, col in ipairs(columns) do
        local hdr = pt.headers[col.key]
        if hdr then
            local isActive = activeSort and (activeSort.key == col.key or (col.key == "teamIcon" and activeSort.groupByTeam))
            local color = isActive and {1, 0.82, 0.28, 1} or {0.80, 0.76, 0.66, 1}
            hdr:SetColor(unpack(color))
            hdr._normalColor = color
        end
    end
    if activeSort then
        local col = nil
        for _, c in ipairs(columns) do if c.key == activeSort.key then col = c break end end
        if col then
            pt.sortIcon:SetTexture(activeSort.ascending and SORT_ICON_UP or SORT_ICON_DOWN)
            pt.sortIcon:ClearAnchors()
            pt.sortIcon:SetAnchor(RIGHT, overlay.playerTable, TOPLEFT, col.x + col.w - s(2), s(15))
            pt.sortIcon:SetHidden(false)
        end
    else
        pt.sortIcon:SetHidden(true)
    end

    local sortedPlayers = BL.GetEndMatchSortedPlayers(match)
    local MAX_PLAYER_ROWS = #(pt.rows or {})
    for i = 1, MAX_PLAYER_ROWS do
        local slot = pt.rows[i]
        local player = sortedPlayers[i]
        if not slot then break end
        if player then
            local playerRowKey = tostring(player.displayName or "") .. "|" .. tostring(player.characterName or "") .. "|" .. tostring(i)
            local isSelected = BL.endMatchSelectedPlayerRowKey == playerRowKey
            local cellColor = player.isLocalPlayer and {1, 0.82, 0.28, 1} or {0.88, 0.86, 0.78, 0.96}
            local tc = allianceColours[tonumber(player.alliance)] or {0.20, 0.20, 0.20}
            local isMvp = player.isTeamMvp == true

            if isSelected then
                slot.bg:SetCenterColor(0.10, 0.080, 0.032, 0.52)
                slot.bg:SetEdgeColor(1, 0.82, 0.28, 0.34)
            elseif isMvp then
                slot.bg:SetCenterColor(math.min(1, tc[1] + 0.05), math.min(1, tc[2] + 0.05), math.min(1, tc[3] + 0.05), 0.24)
                slot.bg:SetEdgeColor(1, 0.82, 0.28, 0.16)
            else
                slot.bg:SetCenterColor(tc[1], tc[2], tc[3], 0.14)
                slot.bg:SetEdgeColor(0, 0, 0, 0)
            end

            local function onRowClick(control, button, upInside)
                if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
                    BL.endMatchSelectedPlayerRowKey = playerRowKey
                    BL.RefreshEndMatchScoreboard(match)
                elseif upInside and button == MOUSE_BUTTON_INDEX_RIGHT and BL.ShowPlayerContextMenu then
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
                        BL.ShowEndMatchMvpPanel(player)
                    end)
                    slot.winnerTex:SetHandler("OnMouseExit", function()
                        if BL.vars and BL.vars.autoShowEndMatchSweetroll == true then
                            local autoPlayer = GetLocalTeamMvpPlayer(match)
                            if autoPlayer then
                                BL.ShowEndMatchMvpPanel(autoPlayer)
                            else
                                BL.HideEndMatchMvpPanel()
                            end
                        else
                            BL.HideEndMatchMvpPanel()
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
                playerName = FormatPlayerNameCell(player),
                score = player.score,
                kills = player.kills,
                deaths = player.deaths,
                assists = player.assists,
                damage = FormatBigNumber(player.damage),
                healing = FormatBigNumber(player.healing),
                kd = Num(player.kd) > 0 and FormatKD(player.kd) or "--",
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

    local contrib = pt.contrib
    local contribValues = match.playerContribution
    if contribValues and contrib then
        if contrib.label then
            contrib.label:SetText(tostring(contribValues.characterName or "Contribution"))
            contrib.label:SetHidden(false)
        end
        for _, col in ipairs(columns) do
            local cell = contrib.cells[col.key]
            if cell then
                local text = contribValues[col.key]
                if col.key == "kd" then
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
        if contrib.label then contrib.label:SetHidden(true) end
        for _, cell in pairs(contrib.cells) do cell:SetHidden(true) end
    end

    if BL.vars and BL.vars.autoShowEndMatchSweetroll == true then
        local autoPlayer = GetLocalTeamMvpPlayer(match)
        if autoPlayer then
            BL.ShowEndMatchMvpPanel(autoPlayer)
        else
            BL.HideEndMatchMvpPanel()
        end
    else
        BL.HideEndMatchMvpPanel()
    end
end

function BL.ShowEndMatchScoreboard(match)
    if not match then return end

    BL.BuildEndMatchScoreboard()
    BL.endMatchMatch = match
    BL.endMatchSelectedPlayerRowKey = nil
    BL.endMatchSort = nil
    BL.RefreshEndMatchScoreboard(match)

    if BL.endMatchOverlay and BL.endMatchOverlay.window then
        BL.endMatchOverlay.window:SetHidden(false)
    end
end

function BL.HideEndMatchScoreboard()
    BL.HideEndMatchMvpPanel()
    if BL.endMatchOverlay and BL.endMatchOverlay.window then
        BL.endMatchOverlay.window:SetHidden(true)
    end
end

function BL.IsEndMatchScoreboardVisible()
    return BL.endMatchOverlay
        and BL.endMatchOverlay.window
        and BL.endMatchOverlay.window.IsHidden
        and not BL.endMatchOverlay.window:IsHidden()
end

function BL.ShowLatestEndMatchScoreboard()
    local match = BL.selectedMatchId and BL.GetMatch(BL.selectedMatchId) or nil
    if not match then
        match = BL.GetLastSavedMatch()
    end

    if not match then
        d("|cFFD700Battleboard|r No saved match is available for the end-match overlay.")
        return
    end

    BL.ShowEndMatchScoreboard(match)
end

function BL.ToggleLatestEndMatchScoreboard()
    if BL.IsEndMatchScoreboardVisible() then
        BL.HideEndMatchScoreboard()
        return
    end

    BL.ShowLatestEndMatchScoreboard()
end
