local Hermes = _G["Hermes"]

local res = HermesMediaRes

local ROW_TYPE_TOME = 1
local ROW_TYPE_TOME_COMPACT = 2
local TIME_REMAINING_UPDATE_INTERVAL_MS = 1000
local TOME_REROLL_CURRENCY_TYPE = CURT_TOME_CHALLENGE_REROLLS
local TOME_POINTS_CURRENCY_TYPE = CURT_TOME_POINTS
local TOME_MONEY_CURRENCY_TYPE = CURT_MONEY
local TOME_ICON_WEEKLY = "/esoui/art/tamrieltomes/timedactivitycategory_weekly_up.dds"
local TOME_ICON_SEASONAL = "/esoui/art/tamrieltomes/timedactivitycategory_seasonal_up.dds"

local TAB_ICON_ALPHA_ACTIVE = 1
local TAB_ICON_ALPHA_INACTIVE = 0.45
local TAB_ICON_ALPHA_HOVER = 0.8

local COLOR_TRACKED = { 0.34, 0.71, 0.91, 1 }
local COLOR_QUEUED = { 0.94, 0.89, 0.26, 1 }
local COLOR_CLAIMABLE = { 0.20, 0.78, 0.60, 1 }
local COLOR_PROGRESS = { 0.90, 0.62, 0.00, 1 }
local COLOR_COMPLETED = { 0.62, 0.62, 0.62, 1 }
local COLOR_OPEN = { 0.82, 0.82, 0.82, 1 }
local COLOR_TIER = { 1, 0.82, 0.40, 1 }

local COMPACT_WINDOW_WIDTH = 420
local TOME_LIST_TOP = 94
local TOME_BOTTOM_MARGIN = 44
local COMPACT_BOTTOM_MARGIN = 56
local TOME_ROW_HEIGHT = 38
local TOME_COMPACT_ROW_HEIGHT = 55
local TOME_SECTION_TOP = 40
local TOME_SECTION_GAP = 8
local TOME_LIST_BASE_HEIGHT = 182
local TOME_COMPACT_LIST_BASE_HEIGHT = 166
local TOME_MIN_VISIBLE_ROWS = 3
local TOME_MAX_VISIBLE_ROWS = 6
local TOME_SECTION_BASE_ROWS = 3
local TRACK_REQUEST_INTERVAL_MS = 1000

local function showTooltip(control, text)
    InitializeTooltip(InformationTooltip, control, TOP, 0, -4, BOTTOM)
    SetTooltipText(InformationTooltip, text)
end

local function hideTooltip()
    ClearTooltip(InformationTooltip)
end

local function getTomeRewardText(index)
    local reward = Hermes.GetTomeRewards(index)

    if reward == "" then
        return "-"
    end

    return reward
end

local function getFilterActivityType(filterKey)
    if filterKey == "seasonal" then
        return TIMED_ACTIVITY_TYPE_SEASONAL
    end

    return TIMED_ACTIVITY_TYPE_WEEKLY
end

local function canRerollTome(entry, rerollsLeft, canAffordGoldReroll)
    if entry.activityType ~= TIMED_ACTIVITY_TYPE_WEEKLY then
        return false
    end

    if entry.isCompleted then
        return false
    end

    if entry.numTimesClaimed > 0 then
        return false
    end

    if entry.canClaim then
        return false
    end

    if rerollsLeft > 0 then
        return true
    end

    return canAffordGoldReroll
end

local function canShowRerollUnavailable(entry, rerollsLeft, canAffordGoldReroll)
    if entry.activityType ~= TIMED_ACTIVITY_TYPE_WEEKLY then
        return false
    end

    if entry.isFullyCompleted then
        return false
    end

    if rerollsLeft > 0 then
        return false
    end

    if canAffordGoldReroll then
        return false
    end

    return not entry.canClaim and not entry.canReroll
end

local function createTabIndicator(tab)
    local indicator = WINDOW_MANAGER:CreateControl(nil, tab, CT_BACKDROP)
    indicator:SetAnchor(TOP, tab, BOTTOM, 0, 1)
    indicator:SetDimensions(32, 2)
    indicator:SetCenterColor(1, 0.82, 0.40, 0.90)
    indicator:SetEdgeColor(0, 0, 0, 0)
    indicator:SetHidden(true)

    return indicator
end

local function sortTomeEntries(left, right)
    if left.isFullyCompleted ~= right.isFullyCompleted then
        return not left.isFullyCompleted
    end

    if left.isTracked ~= right.isTracked then
        return left.isTracked
    end

    if left.isMarked ~= right.isMarked then
        return left.isMarked
    end

    if left.isMarked then
        return left.queuePosition < right.queuePosition
    end

    local leftInProgress = not left.isFullyCompleted and left.progress > 0
    local rightInProgress = not right.isFullyCompleted and right.progress > 0

    if leftInProgress ~= rightInProgress then
        return leftInProgress
    end

    return left.index < right.index
end

local hoveredRowControl = nil

local function applyRowBgColor(control, hovered)
    local data = control.data
    if hovered then
        if data.isTracked then
            control.bg:SetCenterColor(0.00, 0.45, 0.70, 0.50)
        elseif data.canClaim then
            control.bg:SetCenterColor(0.00, 0.62, 0.45, 0.40)
        elseif data.isMarked then
            control.bg:SetCenterColor(0.94, 0.89, 0.26, 0.20)
        else
            control.bg:SetCenterColor(1, 1, 1, 0.09)
        end
    elseif data.isTracked then
        control.bg:SetCenterColor(0.00, 0.45, 0.70, 0.35)
    elseif data.canClaim then
        control.bg:SetCenterColor(0.00, 0.62, 0.45, 0.25)
    elseif data.isMarked then
        control.bg:SetCenterColor(0.94, 0.89, 0.26, 0.08)
    elseif data.isStriped then
        control.bg:SetCenterColor(1, 1, 1, 0.035)
    else
        control.bg:SetCenterColor(0, 0, 0, 0)
    end
    control.bg:SetEdgeColor(0, 0, 0, 0)
end

local function setRowHovered(control, hovered)
    if hovered then
        if hoveredRowControl and hoveredRowControl ~= control then
            hoveredRowControl.isHovered = false
            applyRowBgColor(hoveredRowControl, false)
        end
        hoveredRowControl = control
        control.isHovered = true
        applyRowBgColor(control, true)
    else
        if hoveredRowControl == control then
            hoveredRowControl = nil
        end
        control.isHovered = false
        applyRowBgColor(control, false)
    end
end

local function clearAllRowHovers()
    if hoveredRowControl then
        hoveredRowControl.isHovered = false
        applyRowBgColor(hoveredRowControl, false)
        hoveredRowControl = nil
    end
end

local function refreshTrackButtonVisual(control)
    local data = control.data
    if data.isFullyCompleted then
        control.trackButton:SetHidden(true)
        return
    end

    control.trackButton:SetHidden(false)

    if not data.canTrack then
        control.trackButtonIcon:SetTexture(res.IconTomeTrackOff)
        control.trackButtonIcon:SetColor(1, 1, 1, 1)
        control.trackButtonIcon:SetAlpha(0.80)
        control.trackButton:SetMouseEnabled(false)
        return
    end

    if data.isTracked then
        control.trackButtonIcon:SetTexture(res.IconTomeTrackOn)
        control.trackButtonIcon:SetColor(unpack(COLOR_TRACKED))
        control.trackButtonIcon:SetAlpha(1)
    elseif data.isMarked then
        control.trackButtonIcon:SetTexture(res.IconTomeTrackOn)
        control.trackButtonIcon:SetColor(unpack(COLOR_QUEUED))
        control.trackButtonIcon:SetAlpha(1)
    else
        control.trackButtonIcon:SetTexture(res.IconTomeTrackOff)
        control.trackButtonIcon:SetColor(1, 1, 1, 1)
        control.trackButtonIcon:SetAlpha(0.80)
    end

    control.trackButton:SetMouseEnabled(true)
end

local function refreshActionButtonVisual(control)
    local data = control.data
    if data.isFullyCompleted or data.canClaim then
        control.actionButton:SetHidden(true)
        control.actionButtonIcon:SetHidden(true)
        control.actionButton:SetMouseEnabled(false)
        return
    end

    control.actionButton:SetHidden(false)
    control.actionButtonIcon:SetHidden(false)
    control.actionButtonIcon:SetTexture(res.IconTomesChange)
    control.actionButtonIcon:SetColor(1, 1, 1, 1)

    if data.canReroll then
        control.actionButtonIcon:SetAlpha(0.80)
        control.actionButton:SetMouseEnabled(true)
        return
    end

    if data.showRerollUnavailable then
        control.actionButtonIcon:SetAlpha(0.45)
        control.actionButton:SetMouseEnabled(true)
        return
    end

    control.actionButton:SetHidden(true)
    control.actionButtonIcon:SetHidden(true)
    control.actionButton:SetMouseEnabled(false)
end

local function refreshProgressBar(control, data)
    local show = Hermes.db.showTomeProgressBar and not data.isFullyCompleted
    control.progressBG:SetHidden(not show)
    control.progressFill:SetHidden(not show or data.progress <= 0)

    if not show or data.progress <= 0 then
        return
    end

    if data.canClaim then
        control.progressFill:SetCenterColor(unpack(COLOR_CLAIMABLE))
    else
        control.progressFill:SetCenterColor(unpack(COLOR_PROGRESS))
    end

    if data.maxProgress > 0 then
        local ratio = math.min(data.progress / data.maxProgress, 1)
        control.progressFill:SetWidth(control.progressBG:GetWidth() * ratio)
    end
end

local function getTomeRunText(numTimesClaimed, totalNumTimesClaimable)
    if totalNumTimesClaimable <= 1 then
        return ""
    end

    local claimedRuns = numTimesClaimed
    if claimedRuns > totalNumTimesClaimable then
        claimedRuns = totalNumTimesClaimable
    end

    return string.format("%d/%d", claimedRuns, totalNumTimesClaimable)
end

local function getTimeRemainingTextFromEndTime(endTimeS)
    local currentTime = GetTimeStamp()

    if not endTimeS or endTimeS <= currentTime then
        return nil
    end

    return ZO_FormatTimeLargestTwo(endTimeS - currentTime, TIME_FORMAT_STYLE_DESCRIPTIVE_MINIMAL)
end

local function getTomeProgressText(data)
    local progressText

    if data.isFullyCompleted then
        progressText = res.IconCheck
    elseif data.isCycleClaimed then
        progressText = res.IconCheck
    else
        progressText = string.format("%s/%s", ZO_CommaDelimitNumber(data.progress), ZO_CommaDelimitNumber(data.maxProgress))
    end

    if data.runText ~= "" then
        progressText = string.format("%s |c8A8A8A(%s)|r", progressText, data.runText)
    end

    return progressText
end

local function getTomeViewModeTexture(isCompact, state)
    local textureType = isCompact and "plus" or "minus"
    return string.format("/esoui/art/buttons/%s_%s.dds", textureType, state)
end

local function setupTomeNameTooltip(control)
    control.nameLabel:SetHandler("OnMouseEnter", function(label)
        local data = control.data
        setRowHovered(control, true)
        local tooltipText = data.name
        if data.activityTimeRemainingText then
            tooltipText = string.format("%s\n|cB8B8B8%s|r", tooltipText, data.activityTimeRemainingText)
        end
        showTooltip(label, tooltipText)
    end)

    control.nameLabel:SetHandler("OnMouseExit", function()
        hideTooltip()
    end)
end

local function setupTrackAndActionHandlers(control)
    control.trackButton:SetHandler("OnMouseEnter", function(button)
        local data = control.data
        if not control.trackButton:IsMouseEnabled() then
            return
        end
        setRowHovered(control, true)
        control.trackButtonIcon:SetAlpha(1)
        if data.isTracked then
            showTooltip(button, Hermes.GetDefaultLocaleString("TOME_WINDOW_BUTTON_UNTRACK"))
        elseif data.isMarked then
            showTooltip(button, Hermes.GetDefaultLocaleString("TOME_WINDOW_BUTTON_UNMARK"))
        elseif GetTrackedTimedActivityInfo() then
            showTooltip(button, Hermes.GetDefaultLocaleString("TOME_WINDOW_BUTTON_MARK"))
        else
            showTooltip(button, Hermes.GetDefaultLocaleString("TOME_WINDOW_BUTTON_TRACK"))
        end
    end)

    control.trackButton:SetHandler("OnMouseExit", function()
        refreshTrackButtonVisual(control)
        hideTooltip()
    end)

    control.trackButton:SetHandler("OnClicked", function()
        Hermes:ToggleTomeQueue(control.data)
        Hermes:RefreshTomeWindow()
    end)

    control.actionButton:SetHandler("OnMouseEnter", function(button)
        local data = control.data
        if not control.actionButton:IsMouseEnabled() then
            return
        end
        setRowHovered(control, true)
        if data.canReroll then
            control.actionButtonIcon:SetAlpha(1)
            if data.usesGoldReroll and data.goldRerollCost then
                local goldIcon = GetCurrencyLootKeyboardIcon(TOME_MONEY_CURRENCY_TYPE)
                showTooltip(button, string.format("%s (%s |t16:16:%s|t)", Hermes.GetDefaultLocaleString("TOME_WINDOW_BUTTON_REROLL"), ZO_CommaDelimitNumber(data.goldRerollCost), goldIcon))
            else
                showTooltip(button, string.format("%s (%d)", Hermes.GetDefaultLocaleString("TOME_WINDOW_BUTTON_REROLL"), data.rerollsLeft))
            end
        elseif data.showRerollUnavailable then
            showTooltip(button, Hermes.GetDefaultLocaleString("TOME_WINDOW_BUTTON_REROLL_UNAVAILABLE"))
        end
    end)

    control.actionButton:SetHandler("OnMouseExit", function()
        refreshActionButtonVisual(control)
        hideTooltip()
    end)

    control.actionButton:SetHandler("OnClicked", function()
        local data = control.data
        if data.canReroll then
            RerollTimedActivity(data.index)
        end
    end)
end

local function setupTomeRow(control, data)
    control.data = data
    control.isHovered = false

    if not control.nameLabel then
        control.bg = control:GetNamedChild("BG")
        control.nameLabel = control:GetNamedChild("Name")
        control.progressLabel = control:GetNamedChild("Progress")
        control.rewardLabel = control:GetNamedChild("Reward")
        control.trackButton = control:GetNamedChild("TrackButton")
        control.actionButton = control:GetNamedChild("ActionButton")
        control.trackButtonIcon = control.trackButton:GetNamedChild("Icon")
        control.actionButtonIcon = control.actionButton:GetNamedChild("Icon")

        control:SetHandler("OnMouseEnter", function()
            setRowHovered(control, true)
        end)

        control:SetHandler("OnMouseExit", function()
            setRowHovered(control, false)
        end)

        control.progressBG = control:GetNamedChild("ProgressBG")
        control.progressFill = control:GetNamedChild("ProgressFill")

        control.progressBG:SetCenterColor(0.32, 0.32, 0.32, 0.55)
        control.progressBG:SetEdgeColor(0, 0, 0, 0)
        control.progressFill:SetEdgeColor(0, 0, 0, 0)

        setupTomeNameTooltip(control)
        setupTrackAndActionHandlers(control)
    end

    applyRowBgColor(control, false)

    control.nameLabel:SetText(data.name)
    control.progressLabel:SetText(getTomeProgressText(data))
    control.rewardLabel:SetText(data.reward)

    if data.isFullyCompleted then
        control.nameLabel:SetColor(unpack(COLOR_COMPLETED))
        control.progressLabel:SetColor(unpack(COLOR_COMPLETED))
    elseif data.canClaim then
        control.nameLabel:SetColor(1, 1, 1, 1)
        control.progressLabel:SetColor(unpack(COLOR_CLAIMABLE))
    elseif data.progress > 0 then
        control.nameLabel:SetColor(1, 1, 1, 1)
        control.progressLabel:SetColor(unpack(COLOR_PROGRESS))
    else
        control.nameLabel:SetColor(1, 1, 1, 1)
        control.progressLabel:SetColor(unpack(COLOR_OPEN))
    end

    control.rewardLabel:SetColor(0.78, 0.78, 0.78, 1)

    refreshTrackButtonVisual(control)
    refreshActionButtonVisual(control)
    refreshProgressBar(control, data)
end

local function setupTomeCompactEntry(control, data)
    control.data = data
    control.isHovered = false

    if not control.nameLabel then
        control.bg = control:GetNamedChild("BG")
        control.nameLabel = control:GetNamedChild("Name")
        control.detailsLabel = control:GetNamedChild("Details")
        control.trackButton = control:GetNamedChild("TrackButton")
        control.actionButton = control:GetNamedChild("ActionButton")
        control.trackButtonIcon = control.trackButton:GetNamedChild("Icon")
        control.actionButtonIcon = control.actionButton:GetNamedChild("Icon")

        control.nameLabel:SetFont("$(BOLD_FONT)|16|soft-shadow-thin")
        control.detailsLabel:SetFont("$(MEDIUM_FONT)|15|soft-shadow-thin")

        control:SetHandler("OnMouseEnter", function()
            setRowHovered(control, true)
        end)

        control:SetHandler("OnMouseExit", function()
            setRowHovered(control, false)
        end)

        control.progressBG = control:GetNamedChild("ProgressBG")
        control.progressFill = control:GetNamedChild("ProgressFill")

        control.progressBG:SetCenterColor(0.32, 0.32, 0.32, 0.55)
        control.progressBG:SetEdgeColor(0, 0, 0, 0)
        control.progressFill:SetEdgeColor(0, 0, 0, 0)

        setupTomeNameTooltip(control)
        setupTrackAndActionHandlers(control)
    end

    applyRowBgColor(control, false)

    control.nameLabel:SetText(data.name)

    local detailsText = getTomeProgressText(data)
    if data.reward ~= "" and data.reward ~= "-" then
        detailsText = string.format("%s - %s", detailsText, data.reward)
    end

    control.detailsLabel:SetText(detailsText)

    if data.isFullyCompleted then
        control.nameLabel:SetColor(unpack(COLOR_COMPLETED))
        control.detailsLabel:SetColor(unpack(COLOR_COMPLETED))
    elseif data.canClaim then
        control.nameLabel:SetColor(1, 1, 1, 1)
        control.detailsLabel:SetColor(unpack(COLOR_CLAIMABLE))
    elseif data.progress > 0 then
        control.nameLabel:SetColor(1, 1, 1, 1)
        control.detailsLabel:SetColor(unpack(COLOR_PROGRESS))
    else
        control.nameLabel:SetColor(1, 1, 1, 1)
        control.detailsLabel:SetColor(unpack(COLOR_OPEN))
    end

    refreshTrackButtonVisual(control)
    refreshActionButtonVisual(control)
    refreshProgressBar(control, data)
end

local function initializeTomeSection(control, activityType)
    local bg = control:GetNamedChild("BG")
    local accent = control:GetNamedChild("Accent")
    local isSeasonal = activityType == TIMED_ACTIVITY_TYPE_SEASONAL

    bg:SetCenterColor(1, 1, 1, 0.06)
    bg:SetEdgeColor(0, 0, 0, 0)
    accent:SetCenterColor(unpack(COLOR_TIER))
    accent:SetEdgeColor(0, 0, 0, 0)
    control:GetNamedChild("Icon"):SetTexture(isSeasonal and TOME_ICON_SEASONAL or TOME_ICON_WEEKLY)

    return {
        control = control,
        activityType = activityType,
        nameKey = isSeasonal and "TOME_WINDOW_TAB_SEASONAL" or "TOME_WINDOW_TAB_WEEKLY",
        nameLabel = control:GetNamedChild("Name"),
        timeLabel = control:GetNamedChild("Time"),
    }
end

local function refreshTomeSectionTime(section)
    section.timeLabel:SetText(zo_strformat(Hermes.GetDefaultLocaleString("TOME_WINDOW_TIME_LEFT"),
            Hermes:GetTomeTypeTimeRemainingText(section.activityType)))
end

local function refreshTomeSection(section, numEntries)
    section.nameLabel:SetText(string.format("%s (%d)", Hermes.GetDefaultLocaleString(section.nameKey), numEntries))
    refreshTomeSectionTime(section)
end

local function fillTomeList(list, rowType, entries)
    local scrollData = ZO_ScrollList_GetDataList(list)

    ZO_ClearNumericallyIndexedTable(scrollData)

    for _, entry in ipairs(entries) do
        table.insert(scrollData, ZO_ScrollList_CreateDataEntry(rowType, entry))
    end

    ZO_ScrollList_Commit(list)
end

local function splitTomeRows(numEntries, numSeasonalEntries)
    local weeklyRows = zo_min(numEntries, TOME_SECTION_BASE_ROWS)
    local seasonalRows = zo_min(numSeasonalEntries, TOME_SECTION_BASE_ROWS)
    local freeRows = TOME_MAX_VISIBLE_ROWS - weeklyRows - seasonalRows
    local extraWeeklyRows = zo_min(freeRows, numEntries - weeklyRows)

    weeklyRows = weeklyRows + extraWeeklyRows
    seasonalRows = seasonalRows + zo_min(freeRows - extraWeeklyRows, numSeasonalEntries - seasonalRows)

    return zo_max(weeklyRows, 1), zo_max(seasonalRows, 1)
end

function Hermes:RestoreTomeWindowPosition()
    local control = self.tomeWindow.control

    if self.db.tomeWindowX ~= nil and self.db.tomeWindowY ~= nil then
        control:ClearAnchors()
        control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self.db.tomeWindowX, self.db.tomeWindowY)
    end
end

function Hermes:SaveTomeWindowPosition()
    local control = self.tomeWindow.control

    self.db.tomeWindowX = zo_floor(control:GetLeft())
    self.db.tomeWindowY = zo_floor(control:GetTop())
end

function Hermes:RestoreTomeIconPosition()
    local control = self.tomeIcon.moveHandle

    if self.db.tomeIconUIX ~= nil and self.db.tomeIconUIY ~= nil then
        control:ClearAnchors()
        control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self.db.tomeIconUIX, self.db.tomeIconUIY)
    end
end

function Hermes:SaveTomeIconPosition()
    local control = self.tomeIcon.moveHandle
    self.db.tomeIconUIX = zo_floor(control:GetLeft())
    self.db.tomeIconUIY = zo_floor(control:GetTop())
end

function Hermes:GetTomeRerollsLeft()
    return GetCurrencyAmount(TOME_REROLL_CURRENCY_TYPE, CURRENCY_LOCATION_ACCOUNT)
end

function Hermes:GetTomeGoldRerollCost()
    return GetGoldCostOfNextTimedActivityReroll()
end

function Hermes:CanAffordTomeGoldReroll(cost)
    if not cost or cost <= 0 then
        return false
    end

    return GetCurrencyAmount(TOME_MONEY_CURRENCY_TYPE, CURRENCY_LOCATION_CHARACTER) >= cost
end

function Hermes:GetTomePointsTotal()
    return GetCurrencyAmount(TOME_POINTS_CURRENCY_TYPE, CURRENCY_LOCATION_ACCOUNT)
end

function Hermes:CanClaimAllTomeRewards()
    if not IsTimedActivitySystemAvailable() then
        return false
    end

    return HasAnyUnclaimedTimedActivityRewards()
end

function Hermes:RefreshTomeViewModeButtonVisual(state)
    if not self.tomeWindow or not self.tomeWindow.viewModeButtonIcon then
        return
    end

    self.tomeWindow.viewModeButtonIcon:SetTexture(getTomeViewModeTexture(self:IsTomeWindowCompactMode(), state or "up"))
end

function Hermes:RefreshTomeClaimAllButtonVisual()
    if not self.tomeWindow or not self.tomeWindow.claimAllButton then
        return
    end

    local button = self.tomeWindow.claimAllButton
    button:SetEnabled(button.canClaimAll == true)
end

function Hermes:RefreshTomeClaimAllButton()
    if not self.tomeWindow or not self.tomeWindow.claimAllButton then
        return
    end

    local button = self.tomeWindow.claimAllButton

    if self.db.enableTomeAutoClaim then
        button:SetHidden(true)
        button:SetMouseEnabled(false)
        button.canClaimAll = false
        return
    end

    if not IsTimedActivitySystemAvailable() then
        button:SetHidden(true)
        button:SetMouseEnabled(false)
        button.canClaimAll = false
        return
    end

    button.canClaimAll = self:CanClaimAllTomeRewards()
    button:SetHidden(false)
    button:SetMouseEnabled(true)

    self:RefreshTomeClaimAllButtonVisual()
end

function Hermes:IsTomeWindowCompactMode()
    return self.db.tomeWindowCompactMode == true
end

function Hermes:ApplyTomeWindowPointsLayout()
    local window = self.tomeWindow

    window.pointsLabel:ClearAnchors()
    window.pointsValue:ClearAnchors()

    if self:IsTomeWindowCompactMode() then
        local labelWidth = window.pointsLabel:GetTextDimensions()

        window.pointsLabel:SetAnchor(TOPLEFT, window.tier, TOPLEFT, 4, 0)
        window.pointsLabel:SetDimensions(labelWidth, 20)
        window.pointsLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

        window.pointsValue:SetAnchor(LEFT, window.pointsLabel, RIGHT, 6, 0)
        window.pointsValue:SetDimensions(120, 20)
        window.pointsValue:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        return
    end

    local offsetX = window.currentFilter == "all" and -57 or -228

    window.pointsLabel:SetAnchor(TOPRIGHT, window.control, TOPRIGHT, offsetX, 40)
    window.pointsLabel:SetDimensions(160, 20)
    window.pointsLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    window.pointsValue:SetAnchor(TOPRIGHT, window.control, TOPRIGHT, offsetX, 56)
    window.pointsValue:SetDimensions(160, 20)
    window.pointsValue:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
end

function Hermes:ApplyTomeWindowLayout()
    local window = self.tomeWindow
    local control = window.control
    local listBg = control:GetNamedChild("ListBG")
    local isCompact = self:IsTomeWindowCompactMode()
    local isSplit = window.currentFilter == "all"
    local mainList = isCompact and window.compactList or window.list
    local listTop = isSplit and TOME_SECTION_TOP or (isCompact and 6 or 34)

    window.tierLabel:ClearAnchors()
    window.tierBarBG:ClearAnchors()

    if isCompact then
        control:SetWidth(COMPACT_WINDOW_WIDTH)

        window.timeRemainingLabel:ClearAnchors()
        window.timeRemainingLabel:SetAnchor(TOPRIGHT, control, TOPRIGHT, -14, 40)
        window.timeRemainingLabel:SetDimensions(200, 20)
        window.timeRemainingLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

        window.timeRemainingValue:ClearAnchors()
        window.timeRemainingValue:SetAnchor(TOPRIGHT, control, TOPRIGHT, -14, 56)
        window.timeRemainingValue:SetDimensions(200, 20)
        window.timeRemainingValue:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

        window.tier:SetHeight(36)
        window.tierLabel:SetAnchor(TOPRIGHT, window.tier, TOPRIGHT, -4, 0)
        window.tierLabel:SetDimensions(190, 20)
        window.tierLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        window.tierValue:SetHidden(true)
        window.tierBarBG:SetAnchor(BOTTOMLEFT, window.tier, BOTTOMLEFT, 4, 0)
        window.tierBarWidth = 384
    else
        control:SetWidth(716)

        window.timeRemainingLabel:ClearAnchors()
        window.timeRemainingLabel:SetAnchor(TOPRIGHT, control, TOPRIGHT, -42, 40)
        window.timeRemainingLabel:SetDimensions(190, 20)
        window.timeRemainingLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

        window.timeRemainingValue:ClearAnchors()
        window.timeRemainingValue:SetAnchor(TOPRIGHT, control, TOPRIGHT, -42, 56)
        window.timeRemainingValue:SetDimensions(190, 20)
        window.timeRemainingValue:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

        window.tier:SetHeight(22)
        window.tierLabel:SetAnchor(LEFT, window.tier, LEFT, 4, 0)
        window.tierLabel:SetDimensions(130, 22)
        window.tierLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        window.tierValue:SetHidden(false)
        window.tierBarBG:SetAnchor(LEFT, window.tierLabel, RIGHT, 12, 0)
        window.tierBarWidth = 356
    end

    window.headerName:SetHidden(isCompact or isSplit)
    window.headerProgress:SetHidden(isCompact or isSplit)
    window.headerReward:SetHidden(isCompact or isSplit)

    window.list:SetHidden(isCompact)
    window.seasonalList:SetHidden(isCompact)
    window.compactList:SetHidden(not isCompact)
    window.seasonalCompactList:SetHidden(not isCompact)

    window.weeklySection.control:SetHidden(not isSplit)
    window.seasonalListBg:SetHidden(not isSplit)

    mainList:ClearAnchors()
    mainList:SetAnchor(TOPLEFT, listBg, TOPLEFT, 6, listTop)
    mainList:SetAnchor(BOTTOMRIGHT, listBg, BOTTOMRIGHT, -6, -10)

    window.emptyLabel:ClearAnchors()
    window.emptyLabel:SetAnchor(TOPLEFT, listBg, TOPLEFT, 10, listTop + 4)

    window.tierBarBG:SetWidth(window.tierBarWidth)
    self:ApplyTomeWindowPointsLayout()
    self:UpdateTomeTierProgress()

    local alpha = self.db.tomeWindowBackgroundAlpha / 100
    control:GetNamedChild("BG"):SetAlpha(alpha)
    listBg:SetCenterColor(0, 0, 0, alpha * 0.8)
    listBg:SetEdgeColor(1, 1, 1, alpha)
    window.seasonalListBg:SetCenterColor(0, 0, 0, alpha * 0.8)
    window.seasonalListBg:SetEdgeColor(1, 1, 1, alpha)
end

function Hermes:UpdateTomeWindowPoints()
    local points = self:GetTomePointsTotal()
    local icon = GetCurrencyLootKeyboardIcon(TOME_POINTS_CURRENCY_TYPE)

    self.tomeWindow.pointsLabel:SetText(self.GetDefaultLocaleString("TOME_WINDOW_LABEL_TOTAL"))
    self.tomeWindow.pointsValue:SetText(string.format("%s |t18:18:%s|t", ZO_CommaDelimitNumber(points), icon))
end

function Hermes:GetTomeTierProgress()
    local tomeId = GetActiveReferenceTrackIdsForRewardTrackType(REWARD_TRACK_TYPE_TAMRIEL_TOMES)
    local tomeIndex = tomeId and GetReferenceTrackIndex(REWARD_TRACK_TYPE_TAMRIEL_TOMES, tomeId)

    if not tomeIndex then
        return nil
    end

    local rewardTrackId = GetRewardTrackIdFromReferenceTrackId(REWARD_TRACK_TYPE_TAMRIEL_TOMES, tomeId)
    local _, currentTier, progress = GetInfoForRewardTrack(REWARD_TRACK_TYPE_TAMRIEL_TOMES, tomeIndex)
    local numTiers = GetTotalNumTiersForRewardTrack(rewardTrackId)

    if currentTier >= numTiers then
        return currentTier
    end

    return currentTier, progress, GetCostToProgressToNextTier(rewardTrackId, currentTier)
end

function Hermes:UpdateTomeTierProgress()
    local window = self.tomeWindow
    local currentTier, progress, cost = self:GetTomeTierProgress()

    window.tier:SetHidden(currentTier == nil)
    window.tierTooltip = nil

    if not currentTier then
        return
    end

    if not cost then
        window.tierLabel:SetText(self.GetDefaultLocaleString("TOME_WINDOW_TIER_MAX"))
        window.tierValue:SetText("")
        window.tierBarFill:SetWidth(window.tierBarWidth)
        return
    end

    local icon = GetCurrencyLootKeyboardIcon(TOME_POINTS_CURRENCY_TYPE)
    local nextTier = currentTier + 1

    if self:IsTomeWindowCompactMode() then
        window.tierLabel:SetText(zo_strformat(self.GetDefaultLocaleString("TOME_WINDOW_TIER_REMAINING"),
                ZO_CommaDelimitNumber(zo_max(cost - progress, 0)), nextTier))
    else
        window.tierLabel:SetText(zo_strformat(self.GetDefaultLocaleString("TOME_WINDOW_TIER_NEXT"), nextTier))
    end

    window.tierValue:SetText(string.format("%s / %s |t18:18:%s|t", ZO_CommaDelimitNumber(progress), ZO_CommaDelimitNumber(cost), icon))
    window.tierBarFill:SetWidth(window.tierBarWidth * (cost > 0 and zo_min(progress / cost, 1) or 1))
    window.tierTooltip = zo_strformat(self.GetDefaultLocaleString("TOME_WINDOW_TIER_TOOLTIP"),
            ZO_CommaDelimitNumber(zo_max(cost - progress, 0)), nextTier)
end

function Hermes:GetTomeTypeTimeRemainingSeconds(activityType)
    local currentTime = GetTimeStamp()

    if activityType == TIMED_ACTIVITY_TYPE_WEEKLY then
        local resetTimeS = GetTimedActivityTypeResetTimeS(activityType)
        if resetTimeS and resetTimeS > currentTime then
            return resetTimeS - currentTime
        end

        return 0
    end

    if activityType == TIMED_ACTIVITY_TYPE_SEASONAL then
        local seasonEndTimeS = GetActiveTamrielTomeSeasonEndTimeS()
        if seasonEndTimeS and seasonEndTimeS > currentTime then
            return seasonEndTimeS - currentTime
        end

        return 0
    end

    return 0
end

function Hermes:GetTomeTypeTimeRemainingText(activityType)
    local secondsRemaining = self:GetTomeTypeTimeRemainingSeconds(activityType)
    if secondsRemaining <= 0 then
        return "-"
    end

    return ZO_FormatTimeLargestTwo(secondsRemaining, TIME_FORMAT_STYLE_DESCRIPTIVE_MINIMAL)
end

function Hermes:UpdateTomeWindowTimeRemaining()
    if not IsTimedActivitySystemAvailable() then
        self.tomeWindow.pointsLabel:SetText("")
        self.tomeWindow.pointsValue:SetText("")
        self.tomeWindow.timeRemainingLabel:SetText("")
        self.tomeWindow.timeRemainingValue:SetText("")
        return
    end

    if self.tomeWindow.currentFilter == "all" then
        self.tomeWindow.timeRemainingLabel:SetText("")
        self.tomeWindow.timeRemainingValue:SetText("")

        refreshTomeSectionTime(self.tomeWindow.weeklySection)
        refreshTomeSectionTime(self.tomeWindow.seasonalSection)

        return
    end

    local activityType = getFilterActivityType(self.tomeWindow.currentFilter)
    local timeText = self:GetTomeTypeTimeRemainingText(activityType)

    if activityType == TIMED_ACTIVITY_TYPE_SEASONAL then
        self.tomeWindow.timeRemainingLabel:SetText(self.GetDefaultLocaleString("TOME_WINDOW_TIME_SEASONAL"))
        self.tomeWindow.timeRemainingValue:SetColor(0.78, 0.88, 1, 1)
    else
        self.tomeWindow.timeRemainingLabel:SetText(self.GetDefaultLocaleString("TOME_WINDOW_TIME_WEEKLY"))
        self.tomeWindow.timeRemainingValue:SetColor(0.90, 0.90, 0.90, 1)
    end

    self.tomeWindow.timeRemainingValue:SetText(timeText)
end

function Hermes:StartTomeWindowTimeRemainingUpdate()
    EVENT_MANAGER:RegisterForUpdate(self.name .. "TomeWindowTimeRemaining", TIME_REMAINING_UPDATE_INTERVAL_MS, function()
        self:UpdateTomeWindowTimeRemaining()
    end)
end

function Hermes:StopTomeWindowTimeRemainingUpdate()
    EVENT_MANAGER:UnregisterForUpdate(self.name .. "TomeWindowTimeRemaining")
end

function Hermes:ShowTomeWindow()
    local window = self.tomeWindow

    if window.isEnabled then
        return
    end

    HUD_SCENE:AddFragment(window.fragment)
    HUD_UI_SCENE:AddFragment(window.fragment)
    window.isEnabled = true
    self.db.tomeWindowVisible = true
end

function Hermes:HideTomeWindow()
    local window = self.tomeWindow

    if not window.isEnabled then
        return
    end

    HUD_SCENE:RemoveFragment(window.fragment)
    HUD_UI_SCENE:RemoveFragment(window.fragment)
    window.isEnabled = false
    self.db.tomeWindowVisible = false
end

function Hermes:SetTomeIconVisible(enable)
    self.db.showTomeIconUI = enable

    if enable then
        if not self.tomeIcon.isEnabled then
            HUD_SCENE:AddFragment(self.tomeIcon.fragment)
            HUD_UI_SCENE:AddFragment(self.tomeIcon.fragment)
            self.tomeIcon.isEnabled = true
        end
    elseif self.tomeIcon.isEnabled then
        HUD_SCENE:RemoveFragment(self.tomeIcon.fragment)
        HUD_UI_SCENE:RemoveFragment(self.tomeIcon.fragment)
        self.tomeIcon.isEnabled = false
    end
end

function Hermes:InitializeTomeIcon()
    local control = HermesTomeIcon
    local moveHandle = control:GetNamedChild("MoveHandle")
    local button = control:GetNamedChild("Button")
    local icon = button:GetNamedChild("Icon")

    self.tomeIcon = {
        control = control,
        moveHandle = moveHandle,
        button = button,
        icon = icon,
        fragment = ZO_HUDFadeSceneFragment:New(control, nil, 0),
        isEnabled = false,
        isDragging = false,
    }

    local tomeIcon = self.tomeIcon

    control:SetHidden(true)

    icon:SetTexture(res.IconTomesUI)
    icon:SetAlpha(0.80)

    moveHandle:SetAlpha(0)
    moveHandle:SetCenterColor(1, 0, 0, 0.25)
    moveHandle:SetEdgeColor(1, 0, 0, 0.38)

    self:RestoreTomeIconPosition()

    moveHandle:SetHandler("OnMouseEnter", function(handle)
        WINDOW_MANAGER:SetMouseCursor(12)
        handle:SetAlpha(1)
    end)

    moveHandle:SetHandler("OnMouseExit", function(handle)
        if not tomeIcon.isDragging then
            WINDOW_MANAGER:SetMouseCursor(0)
            handle:SetAlpha(0)
        end
    end)

    moveHandle:SetHandler("OnMouseDown", function(_, buttonIndex)
        if buttonIndex == MOUSE_BUTTON_INDEX_LEFT then
            tomeIcon.isDragging = true
            hideTooltip()
        end
    end)

    moveHandle:SetHandler("OnMouseUp", function(handle, buttonIndex)
        if buttonIndex == MOUSE_BUTTON_INDEX_LEFT then
            tomeIcon.isDragging = false
            WINDOW_MANAGER:SetMouseCursor(12)
            handle:SetAlpha(1)
            handle:StopMovingOrResizing()
        end
    end)

    moveHandle:SetHandler("OnMoveStop", function(handle)
        tomeIcon.isDragging = false
        WINDOW_MANAGER:SetMouseCursor(0)
        handle:SetAlpha(0)
        Hermes:SaveTomeIconPosition()
    end)

    button:SetHandler("OnMouseEnter", function()
        icon:SetAlpha(1)
        showTooltip(button, Hermes.GetDefaultLocaleString("TOME_ICON_UI_OPEN"))
    end)

    button:SetHandler("OnMouseExit", function()
        icon:SetAlpha(0.80)
        hideTooltip()
    end)

    button:SetHandler("OnClicked", function()
        self:ToggleTomeWindow()
    end)

    self:SetTomeIconVisible(self.db.showTomeIconUI)
end

function Hermes:InitializeTomeWindow()
    local control = HermesTomeWindow
    local listBg = control:GetNamedChild("ListBG")
    local closeButton = control:GetNamedChild("Close")
    local claimAllButton = control:GetNamedChild("ClaimAll")
    local viewModeButton = control:GetNamedChild("ViewMode")
    local viewModeButtonIcon = viewModeButton and viewModeButton:GetNamedChild("Icon")
    local compactList = listBg:GetNamedChild("CompactList")
    local seasonalListBg = control:GetNamedChild("SeasonalListBG")

    self.tomeWindow = {
        control = control,
        title = control:GetNamedChild("Title"),
        pointsLabel = control:GetNamedChild("PointsLabel"),
        pointsValue = control:GetNamedChild("PointsValue"),
        timeRemainingLabel = control:GetNamedChild("TimeRemainingLabel"),
        timeRemainingValue = control:GetNamedChild("TimeRemainingValue"),
        tabs = {
            weekly = { control = control:GetNamedChild("WeeklyTab"), tooltipKey = "TOME_WINDOW_TAB_WEEKLY" },
            seasonal = { control = control:GetNamedChild("SeasonalTab"), tooltipKey = "TOME_WINDOW_TAB_SEASONAL" },
            all = { control = control:GetNamedChild("AllTab"), tooltipKey = "TOME_WINDOW_TAB_ALL" },
        },
        tier = control:GetNamedChild("Tier"),
        tierLabel = control:GetNamedChild("Tier"):GetNamedChild("Label"),
        tierValue = control:GetNamedChild("Tier"):GetNamedChild("Value"),
        tierBarBG = control:GetNamedChild("Tier"):GetNamedChild("BarBG"),
        tierBarFill = control:GetNamedChild("Tier"):GetNamedChild("BarFill"),
        tierBarWidth = 356,
        claimAllButton = claimAllButton,
        viewModeButton = viewModeButton,
        viewModeButtonIcon = viewModeButtonIcon,
        list = listBg:GetNamedChild("List"),
        compactList = compactList,
        seasonalListBg = seasonalListBg,
        seasonalList = seasonalListBg:GetNamedChild("List"),
        seasonalCompactList = seasonalListBg:GetNamedChild("CompactList"),
        weeklySection = initializeTomeSection(listBg:GetNamedChild("Section"), TIMED_ACTIVITY_TYPE_WEEKLY),
        seasonalSection = initializeTomeSection(seasonalListBg:GetNamedChild("Section"), TIMED_ACTIVITY_TYPE_SEASONAL),
        emptyLabel = listBg:GetNamedChild("Empty"),
        headerName = listBg:GetNamedChild("HeaderName"),
        headerProgress = listBg:GetNamedChild("HeaderProgress"),
        headerReward = listBg:GetNamedChild("HeaderReward"),
        currentFilter = (self.db.tomeWindowLastFilter == "seasonal" or self.db.tomeWindowLastFilter == "all")
                and self.db.tomeWindowLastFilter or "weekly",
    }

    local window = self.tomeWindow

    window.fragment = ZO_HUDFadeSceneFragment:New(control, nil, 0)
    window.isEnabled = false
    control:SetHidden(true)
    window.compactList:SetHidden(true)

    local function requestRefresh()
        Hermes.Debounce("HermesTomeWindowRefresh", 100, function()
            self:RefreshTomeWindowIfVisible()
        end)
    end

    window.title:SetText(self.GetDefaultLocaleString("TOME_WINDOW_TITLE"))
    window.pointsLabel:SetText(self.GetDefaultLocaleString("TOME_WINDOW_LABEL_TOTAL"))
    window.pointsValue:SetText("")
    window.timeRemainingLabel:SetText("")
    window.timeRemainingValue:SetText("")
    window.emptyLabel:SetText("")

    window.headerName:SetText(self.GetDefaultLocaleString("TOME_WINDOW_LABEL_NAME"))
    window.headerProgress:SetText(self.GetDefaultLocaleString("TOME_WINDOW_LABEL_PROGRESS"))
    window.headerReward:SetText(self.GetDefaultLocaleString("TOME_WINDOW_LABEL_REWARD"))

    if claimAllButton then
        claimAllButton:SetText(self.GetDefaultLocaleString("TOME_WINDOW_BUTTON_CLAIM_ALL"))
        claimAllButton.canClaimAll = false

        claimAllButton:SetHandler("OnMouseEnter", function(button)
            if button.canClaimAll then
                showTooltip(button, self.GetDefaultLocaleString("TOME_WINDOW_BUTTON_CLAIM_ALL_TOOLTIP"))
            else
                showTooltip(button, self.GetDefaultLocaleString("TOME_WINDOW_BUTTON_CLAIM_ALL_UNAVAILABLE"))
            end
        end)

        claimAllButton:SetHandler("OnMouseExit", function()
            self:RefreshTomeClaimAllButtonVisual()
            hideTooltip()
        end)

        claimAllButton:SetHandler("OnClicked", function()
            if self:CanClaimAllTomeRewards() then
                ClaimAllTimedActivityRewards()
                requestRefresh()
            end
        end)
    end

    self:SetupGuideHelp(control:GetNamedChild("Help"), "TOMES_TRACK", self.GetDefaultLocaleString("TOME_WINDOW_HELP"))

    if viewModeButton then
        viewModeButton:SetHandler("OnMouseEnter", function()
            self:RefreshTomeViewModeButtonVisual("over")
        end)

        viewModeButton:SetHandler("OnMouseExit", function()
            self:RefreshTomeViewModeButtonVisual("up")
        end)

        viewModeButton:SetHandler("OnMouseDown", function(_, buttonIndex)
            if buttonIndex == MOUSE_BUTTON_INDEX_LEFT then
                self:RefreshTomeViewModeButtonVisual("down")
            end
        end)

        viewModeButton:SetHandler("OnClicked", function()
            self.db.tomeWindowCompactMode = not self.db.tomeWindowCompactMode
            self:ApplyTomeWindowLayout()
            self:RefreshTomeViewModeButtonVisual("over")
            self:RefreshTomeWindowIfVisible()
        end)
    end

    if closeButton then
        closeButton:SetHandler("OnClicked", function()
            self:HideTomeWindow()
        end)
    end

    for filterKey, tab in pairs(window.tabs) do
        tab.icon = tab.control:GetNamedChild("Icon")
        tab.indicator = createTabIndicator(tab.control)

        tab.control:SetHandler("OnClicked", function()
            self:SetTomeWindowFilter(filterKey)
        end)

        tab.control:SetHandler("OnMouseEnter", function(button)
            showTooltip(button, self.GetDefaultLocaleString(tab.tooltipKey))

            if window.currentFilter ~= filterKey then
                tab.icon:SetAlpha(TAB_ICON_ALPHA_HOVER)
            end
        end)

        tab.control:SetHandler("OnMouseExit", function()
            hideTooltip()
            self:UpdateTomeTabState()
        end)
    end

    window.tierBarBG:SetCenterColor(0.32, 0.32, 0.32, 0.55)
    window.tierBarBG:SetEdgeColor(0, 0, 0, 0)
    window.tierBarFill:SetCenterColor(unpack(COLOR_TIER))
    window.tierBarFill:SetEdgeColor(0, 0, 0, 0)

    window.tier:SetHandler("OnMouseEnter", function()
        if window.tierTooltip then
            showTooltip(window.tier, window.tierTooltip)
        end
    end)

    window.tier:SetHandler("OnMouseExit", function()
        hideTooltip()
    end)

    control:SetHandler("OnMoveStop", function()
        self:SaveTomeWindowPosition()
    end)

    control:SetHandler("OnEffectivelyShown", function()
        self:RestoreTomeWindowPosition()
        self:UpdateTomeWindowPoints()
        self:ApplyTomeWindowLayout()
        self:RefreshTomeViewModeButtonVisual("up")
        self:UpdateTomeWindowTimeRemaining()
        self:RefreshTomeClaimAllButton()
        self:StartTomeWindowTimeRemainingUpdate()
        self:RefreshTomeWindow()
    end)

    control:SetHandler("OnEffectivelyHidden", function()
        clearAllRowHovers()
        self:StopTomeWindowTimeRemainingUpdate()
    end)

    control:SetHandler("OnMouseExit", function()
        clearAllRowHovers()
    end)

    ZO_ScrollList_AddDataType(window.list, ROW_TYPE_TOME, "HermesTomeRow", TOME_ROW_HEIGHT, setupTomeRow)
    ZO_ScrollList_AddDataType(window.compactList, ROW_TYPE_TOME_COMPACT, "HermesTomeCompactEntry", TOME_COMPACT_ROW_HEIGHT, setupTomeCompactEntry)
    ZO_ScrollList_AddDataType(window.seasonalList, ROW_TYPE_TOME, "HermesTomeRow", TOME_ROW_HEIGHT, setupTomeRow)
    ZO_ScrollList_AddDataType(window.seasonalCompactList, ROW_TYPE_TOME_COMPACT, "HermesTomeCompactEntry", TOME_COMPACT_ROW_HEIGHT, setupTomeCompactEntry)

    EVENT_MANAGER:RegisterForEvent(self.name .. "TomeWindow", EVENT_TIMED_ACTIVITIES_UPDATED, requestRefresh)
    EVENT_MANAGER:RegisterForEvent(self.name .. "TomeWindow", EVENT_TIMED_ACTIVITY_PROGRESS_UPDATED, requestRefresh)
    EVENT_MANAGER:RegisterForEvent(self.name .. "TomeWindow", EVENT_TIMED_ACTIVITY_TRACKING_UPDATED, requestRefresh)
    EVENT_MANAGER:RegisterForEvent(self.name .. "TomeWindow", EVENT_TIMED_ACTIVITY_SYSTEM_STATUS_UPDATED, requestRefresh)

    EVENT_MANAGER:RegisterForEvent(self.name .. "TomeWindowCurrency", EVENT_CURRENCY_UPDATE, function(_, currencyType, currencyLocation)
        if currencyLocation ~= CURRENCY_LOCATION_ACCOUNT and currencyLocation ~= CURRENCY_LOCATION_CHARACTER then
            return
        end

        if currencyType == TOME_REROLL_CURRENCY_TYPE then
            requestRefresh()
            return
        end

        if currencyType == TOME_MONEY_CURRENCY_TYPE then
            local canAffordGoldReroll = self:GetTomeRerollsLeft() <= 0 and self:CanAffordTomeGoldReroll(self:GetTomeGoldRerollCost())

            if canAffordGoldReroll ~= window.canAffordGoldReroll then
                window.canAffordGoldReroll = canAffordGoldReroll
                requestRefresh()
            end

            return
        end

        if currencyType == TOME_POINTS_CURRENCY_TYPE and window.isEnabled and not window.control:IsHidden() then
            self:UpdateTomeWindowPoints()
            self:UpdateTomeTierProgress()
            self:RefreshTomeClaimAllButton()
        end
    end)

    EVENT_MANAGER:RegisterForEvent(self.name .. "TomeWindowTier", EVENT_REWARD_TRACK_PROGRESS_GAINED, function(_, rewardTrackType)
        if rewardTrackType == REWARD_TRACK_TYPE_TAMRIEL_TOMES and window.isEnabled and not window.control:IsHidden() then
            self:UpdateTomeTierProgress()
        end
    end)

    EVENT_MANAGER:RegisterForEvent(self.name .. "TomeWindowRerollPriceReset", EVENT_TIMED_ACTIVITIES_REROLL_PRICE_RESET, requestRefresh)

    EVENT_MANAGER:RegisterForEvent(self.name .. "TomeWindowRerollResult", EVENT_TIMED_ACTIVITY_REROLL_RESULT, requestRefresh)

    EVENT_MANAGER:RegisterForEvent(self.name .. "TomeQueue", EVENT_TIMED_ACTIVITY_PROGRESS_UPDATED, function(_, _, _, _, complete)
        if complete then
            self:UpdateTomeQueue()
        end
    end)
    EVENT_MANAGER:RegisterForEvent(self.name .. "TomeQueue", EVENT_TIMED_ACTIVITIES_UPDATED, function()
        self:UpdateTomeQueue()
    end)

    self:UpdateTomeTabState()
    self:RestoreTomeWindowPosition()
    self:ApplyTomeWindowLayout()
    self:RefreshTomeViewModeButtonVisual("up")
    self:RefreshTomeClaimAllButton()

    if self.db.tomeWindowVisible then
        self:ShowTomeWindow()
    end
end

function Hermes:RefreshTomeWindowIfVisible()
    if self.tomeWindow.isEnabled and not self.tomeWindow.control:IsHidden() then
        self:UpdateTomeWindowPoints()
        self:UpdateTomeWindowTimeRemaining()
        self:RefreshTomeWindow()
    end
end

function Hermes:SetTomeWindowFilter(filterKey)
    if not self.tomeWindow or self.tomeWindow.currentFilter == filterKey then
        return
    end

    self.tomeWindow.currentFilter = filterKey
    self.db.tomeWindowLastFilter = filterKey
    self:UpdateTomeTabState()
    self:ApplyTomeWindowLayout()
    self:UpdateTomeWindowTimeRemaining()
    self:RefreshTomeWindow()
end

function Hermes:UpdateTomeTabState()
    for filterKey, tab in pairs(self.tomeWindow.tabs) do
        local isActive = self.tomeWindow.currentFilter == filterKey
        tab.indicator:SetHidden(not isActive)
        tab.icon:SetAlpha(isActive and TAB_ICON_ALPHA_ACTIVE or TAB_ICON_ALPHA_INACTIVE)
    end
end

function Hermes:BuildTomeWindowEntries(activityType)
    local entries = {}

    if not IsTimedActivitySystemAvailable() then
        return entries
    end

    local trackedIndex = select(1, GetTrackedTimedActivityInfo())
    local numTimedActivities = GetNumTimedActivities()
    local rerollsLeft = self:GetTomeRerollsLeft()
    local goldRerollCost = self:GetTomeGoldRerollCost()
    local canUseGoldReroll = rerollsLeft <= 0 and goldRerollCost ~= nil and goldRerollCost > 0
    local canAffordGoldReroll = canUseGoldReroll and self:CanAffordTomeGoldReroll(goldRerollCost)
    local seasonEndTimeS = nil
    local queuePositions = {}

    for position, activityId in ipairs(self.db.tomeQueue) do
        queuePositions[activityId] = position
    end

    if activityType == TIMED_ACTIVITY_TYPE_SEASONAL then
        seasonEndTimeS = GetActiveTamrielTomeSeasonEndTimeS()
    end

    for index = 1, numTimedActivities do
        if GetTimedActivityType(index) == activityType then
            local name = GetTimedActivityName(index):gsub("|t[^:|]+:[^:|]+:", "|t100%%:100%%:")
            local progress = GetTimedActivityProgress(index)
            local maxProgress = GetTimedActivityMaxProgress(index)
            local numTimesClaimed = GetTimedActivityNumTimesClaimed(index)
            local totalNumTimesClaimable = GetTimedActivityTotalNumTimesClaimable(index)

            local isCompleted = maxProgress > 0 and progress >= maxProgress
            local canClaim = isCompleted and totalNumTimesClaimable > 0 and numTimesClaimed < totalNumTimesClaimable
            local isFullyCompleted = totalNumTimesClaimable > 0 and numTimesClaimed >= totalNumTimesClaimable
            local isCycleClaimed = activityType == TIMED_ACTIVITY_TYPE_SEASONAL
                    and maxProgress == 1
                    and progress == 0
                    and numTimesClaimed > 0
                    and not canClaim
                    and not isFullyCompleted
            local canTrack = not isCompleted and not canClaim and not isFullyCompleted
            local activityTimeRemainingText = nil

            if activityType == TIMED_ACTIVITY_TYPE_SEASONAL and seasonEndTimeS then
                local activityEndTimeS = GetTimedActivityEndTimeS(index)

                if activityEndTimeS and activityEndTimeS > 0 and activityEndTimeS < seasonEndTimeS - 60 then
                    activityTimeRemainingText = getTimeRemainingTextFromEndTime(activityEndTimeS)
                end
            end

            local activityId = GetTimedActivityId(index)
            local isTracked = trackedIndex == index and canTrack

            local entry = {
                index = index,
                activityId = activityId,
                queuePosition = queuePositions[activityId],
                isMarked = queuePositions[activityId] ~= nil and not isTracked,
                activityType = activityType,
                name = name,
                progress = progress,
                maxProgress = maxProgress,
                reward = getTomeRewardText(index),
                numTimesClaimed = numTimesClaimed,
                totalNumTimesClaimable = totalNumTimesClaimable,
                runText = getTomeRunText(numTimesClaimed, totalNumTimesClaimable),
                activityTimeRemainingText = activityTimeRemainingText,
                isCompleted = isCompleted,
                isFullyCompleted = isFullyCompleted,
                isCycleClaimed = isCycleClaimed,
                canClaim = canClaim,
                canTrack = canTrack,
                isTracked = isTracked,
                rerollsLeft = rerollsLeft,
                goldRerollCost = canUseGoldReroll and goldRerollCost or nil,
            }

            entry.canReroll = canRerollTome(entry, rerollsLeft, canAffordGoldReroll)
            entry.usesGoldReroll = canUseGoldReroll
            entry.showRerollUnavailable = canShowRerollUnavailable(entry, rerollsLeft, canAffordGoldReroll)

            table.insert(entries, entry)
        end
    end

    table.sort(entries, sortTomeEntries)

    for i, entry in ipairs(entries) do
        entry.isStriped = i % 2 == 0
    end

    return entries
end

function Hermes:RefreshTomeLists(entries, seasonalEntries)
    local window = self.tomeWindow

    if self:IsTomeWindowCompactMode() then
        fillTomeList(window.compactList, ROW_TYPE_TOME_COMPACT, entries)
        fillTomeList(window.seasonalCompactList, ROW_TYPE_TOME_COMPACT, seasonalEntries)
    else
        fillTomeList(window.list, ROW_TYPE_TOME, entries)
        fillTomeList(window.seasonalList, ROW_TYPE_TOME, seasonalEntries)
    end
end

local function isTomeTrackable(index)
    local progress = GetTimedActivityProgress(index)
    local maxProgress = GetTimedActivityMaxProgress(index)
    local numTimesClaimed = GetTimedActivityNumTimesClaimed(index)
    local totalNumTimesClaimable = GetTimedActivityTotalNumTimesClaimable(index)

    if maxProgress > 0 and progress >= maxProgress then
        return false
    end

    return totalNumTimesClaimable == 0 or numTimesClaimed < totalNumTimesClaimable
end

local function findTomeIndex(activityId)
    for index = 1, GetNumTimedActivities() do
        if GetTimedActivityId(index) == activityId then
            return index
        end
    end
end

local function findBestTomeIndex()
    local bestIndex = nil
    local bestProgress = 0

    for index = 1, GetNumTimedActivities() do
        local activityType = GetTimedActivityType(index)
        local progress = GetTimedActivityProgress(index)

        if (activityType == TIMED_ACTIVITY_TYPE_WEEKLY or activityType == TIMED_ACTIVITY_TYPE_SEASONAL)
                and progress > bestProgress
                and isTomeTrackable(index) then
            bestIndex = index
            bestProgress = progress
        end
    end

    return bestIndex
end

local lastTrackRequestTime = -TRACK_REQUEST_INTERVAL_MS

function Hermes:ToggleTomeQueue(data)
    local queue = self.db.tomeQueue

    if data.isTracked or data.isMarked then
        ZO_RemoveFirstElementFromNumericallyIndexedTable(queue, data.activityId)

        if data.isTracked then
            lastTrackRequestTime = GetGameTimeMilliseconds()
            ClearTrackedTimedActivity()
        end
    elseif GetTrackedTimedActivityInfo() then
        local trackedId = GetTimedActivityId(GetTrackedTimedActivityInfo())

        if not ZO_IsElementInNumericallyIndexedTable(queue, trackedId) then
            table.insert(queue, 1, trackedId)
        end

        table.insert(queue, data.activityId)
    else
        table.insert(queue, 1, data.activityId)
        lastTrackRequestTime = GetGameTimeMilliseconds()
        TrackTimedActivity(data.index)
    end

    self:UpdateTomeQueue()
end

function Hermes:UpdateTomeQueue()
    if not IsTimedActivitySystemAvailable() or GetNumTimedActivities() == 0 then
        return
    end

    local queue = self.db.tomeQueue

    for position = #queue, 1, -1 do
        local index = findTomeIndex(queue[position])

        if not index or not isTomeTrackable(index) then
            table.remove(queue, position)
        end
    end

    local trackedIndex = GetTrackedTimedActivityInfo()

    if trackedIndex and isTomeTrackable(trackedIndex) then
        return
    end

    local nextIndex = queue[1] and findTomeIndex(queue[1])

    if not nextIndex and self.db.autoTrackTomes then
        nextIndex = findBestTomeIndex()
    end

    if not nextIndex and not trackedIndex then
        return
    end

    local now = GetGameTimeMilliseconds()

    if now - lastTrackRequestTime < TRACK_REQUEST_INTERVAL_MS then
        Hermes.Debounce("HermesTomeQueueRetry", TRACK_REQUEST_INTERVAL_MS - (now - lastTrackRequestTime), function()
            self:UpdateTomeQueue()
        end)
        return
    end

    lastTrackRequestTime = now

    if nextIndex then
        TrackTimedActivity(nextIndex)
    else
        ClearTrackedTimedActivity()
    end
end

function Hermes:UpdateTomeWindowHeight(numEntries, numSeasonalEntries)
    local window = self.tomeWindow
    local control = window.control
    local listBg = control:GetNamedChild("ListBG")
    local isCompact = self:IsTomeWindowCompactMode()
    local rowHeight = isCompact and TOME_COMPACT_ROW_HEIGHT or TOME_ROW_HEIGHT
    local bottomMargin = isCompact and COMPACT_BOTTOM_MARGIN or TOME_BOTTOM_MARGIN

    listBg:ClearAnchors()
    listBg:SetAnchor(TOPLEFT, control, TOPLEFT, 14, TOME_LIST_TOP)

    if window.currentFilter ~= "all" then
        local rows = zo_clamp(numEntries, TOME_MIN_VISIBLE_ROWS, TOME_MAX_VISIBLE_ROWS)

        listBg:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, -14, -bottomMargin)
        control:SetHeight((isCompact and TOME_COMPACT_LIST_BASE_HEIGHT or TOME_LIST_BASE_HEIGHT) + rows * rowHeight)
        return
    end

    local weeklyRows, seasonalRows = splitTomeRows(numEntries, numSeasonalEntries)
    local weeklyHeight = TOME_SECTION_TOP + weeklyRows * rowHeight + 10
    local seasonalHeight = TOME_SECTION_TOP + seasonalRows * rowHeight + 10

    listBg:SetAnchor(TOPRIGHT, control, TOPRIGHT, -14, TOME_LIST_TOP)
    listBg:SetHeight(weeklyHeight)
    window.seasonalListBg:SetHeight(seasonalHeight)
    control:SetHeight(TOME_LIST_TOP + weeklyHeight + TOME_SECTION_GAP + seasonalHeight + bottomMargin)
end

function Hermes:RefreshTomeWindow()
    local window = self.tomeWindow

    if not IsTimedActivitySystemAvailable() then
        window.emptyLabel:SetText(self.GetDefaultLocaleString("TOME_WINDOW_EMPTY"))
        self:UpdateTomeWindowHeight(0, 0)
        self:RefreshTomeLists({}, {})
        self:RefreshTomeClaimAllButton()
        return
    end

    self:UpdateTomeQueue()

    local entries
    local seasonalEntries = {}

    if window.currentFilter == "all" then
        entries = self:BuildTomeWindowEntries(TIMED_ACTIVITY_TYPE_WEEKLY)
        seasonalEntries = self:BuildTomeWindowEntries(TIMED_ACTIVITY_TYPE_SEASONAL)
        refreshTomeSection(window.weeklySection, #entries)
        refreshTomeSection(window.seasonalSection, #seasonalEntries)
    else
        entries = self:BuildTomeWindowEntries(getFilterActivityType(window.currentFilter))
    end

    self:UpdateTomeWindowHeight(#entries, #seasonalEntries)

    self:RefreshTomeLists(entries, seasonalEntries)

    if #entries + #seasonalEntries == 0 then
        window.emptyLabel:SetText(self.GetDefaultLocaleString("TOME_WINDOW_EMPTY"))
    else
        window.emptyLabel:SetText("")
    end

    self:RefreshTomeClaimAllButton()
end

function Hermes:ToggleTomeWindow()
    if self.tomeWindow.isEnabled then
        self:HideTomeWindow()
    else
        self:ShowTomeWindow()
    end
end

ZO_CreateStringId("SI_BINDING_NAME_HERMES_TOME_WINDOW", Hermes.GetDefaultLocaleString("BINDING_OPEN_TOMES_WINDOW"))