LeadDigger = {}

local addon = LeadDigger
local ADDON_NAME = "LeadDigger"
local DISPLAY_NAME = "Lead Digger"
local SAVED_VARIABLES_NAME = "LeadDiggerSavedVariables"
local SAVED_VARIABLES_VERSION = 1
local IS_RUSSIAN = GetCVar("language.2") == "ru"

local DEFAULT_VISIBLE_ZONES = 3
local MAX_CONFIGURABLE_ZONES = 10
local ROW_HEIGHT = 24
local DEFAULT_ZONE_WIDTH = 120
local MIN_ZONE_WIDTH = 60
local MAX_ZONE_WIDTH = 400
local COUNT_COLUMN_WIDTH = 20
local DEFAULT_WINDOW_HEIGHT = ROW_HEIGHT * (DEFAULT_VISIBLE_ZONES + 2)
local REFRESH_DELAY_MS = 200
local PERIODIC_REFRESH_MS = 60000
local PREVIEW_ZONE_COUNT = 11

local DEFAULT_HEADER_COLOR = { r = 1, g = 1, b = 1, a = 1 }
local DEFAULT_ZONE_COLOR = { r = 1, g = 1, b = 1, a = 1 }
local DEFAULT_FOOTER_COLOR = { r = 0.72, g = 0.72, b = 0.72, a = 1 }

local QUALITY_PRIORITY = {
    ANTIQUITY_QUALITY_ORANGE,
    ANTIQUITY_QUALITY_GOLD,
    ANTIQUITY_QUALITY_PURPLE,
    ANTIQUITY_QUALITY_BLUE,
    ANTIQUITY_QUALITY_GREEN,
    ANTIQUITY_QUALITY_WHITE,
}

local PREVIEW_QUALITIES = {
    ANTIQUITY_QUALITY_GOLD,
    ANTIQUITY_QUALITY_PURPLE,
    ANTIQUITY_QUALITY_BLUE,
    ANTIQUITY_QUALITY_GREEN,
}

local DEFAULTS = {
    hidden = false,
    locked = false,
    visibleZones = DEFAULT_VISIBLE_ZONES,
    zoneWidth = DEFAULT_ZONE_WIDTH,
    showHeader = true,
    showFooter = true,
    headerColor = DEFAULT_HEADER_COLOR,
    zoneColor = DEFAULT_ZONE_COLOR,
    footerColor = DEFAULT_FOOTER_COLOR,
    hasPosition = false,
    left = 0,
    top = 0,
}

local function Print(message)
    d(string.format("|cD4AF37[%s]|r %s", DISPLAY_NAME, message))
end

local function GetDisplayVersion()
    local addonManager = GetAddOnManager()
    for index = 1, addonManager:GetNumAddOns() do
        local addonName = addonManager:GetAddOnInfo(index)
        if addonName == ADDON_NAME then
            local version = addonManager:GetAddOnVersion(index)
            local major = math.floor(version / 10000)
            local minor = math.floor(version / 100) % 100
            local patch = version % 100
            return string.format("%d.%d.%d", major, minor, patch)
        end
    end

    return ""
end

local function FormatMoreZones(count)
    local stringId
    if IS_RUSSIAN then
        local lastTwoDigits = count % 100
        local lastDigit = count % 10
        if lastDigit == 1 and lastTwoDigits ~= 11 then
            stringId = SI_LEADDIGGER_MORE_ZONES_ONE
        elseif lastDigit >= 2 and lastDigit <= 4 and (lastTwoDigits < 12 or lastTwoDigits > 14) then
            stringId = SI_LEADDIGGER_MORE_ZONES_FEW
        else
            stringId = SI_LEADDIGGER_MORE_ZONES_MANY
        end
    elseif count == 1 then
        stringId = SI_LEADDIGGER_MORE_ZONES_ONE
    else
        stringId = SI_LEADDIGGER_MORE_ZONES_MANY
    end

    return zo_strformat(GetString(stringId), count)
end

local function FormatZoneName(zoneId)
    local zoneName = GetZoneNameById(zoneId)
    if not zoneName or zoneName == "" then
        return zo_strformat(GetString(SI_LEADDIGGER_UNKNOWN_ZONE), zoneId)
    end
    return zo_strformat("<<C:1>>", zoneName)
end

local function GetBestQuality(zoneData)
    for _, quality in ipairs(QUALITY_PRIORITY) do
        if (zoneData.qualityCounts[quality] or 0) > 0 then
            return quality
        end
    end
    return ANTIQUITY_QUALITY_WHITE
end

local function CompareZones(left, right)
    if left.count ~= right.count then
        return left.count > right.count
    end

    for _, quality in ipairs(QUALITY_PRIORITY) do
        local leftCount = left.qualityCounts[quality] or 0
        local rightCount = right.qualityCounts[quality] or 0
        if leftCount ~= rightCount then
            return leftCount > rightCount
        end
    end

    if left.earliestExpiration ~= right.earliestExpiration then
        return left.earliestExpiration < right.earliestExpiration
    end

    return left.name < right.name
end

function addon:GetZoneColumnWidth()
    local width = tonumber(self.savedVariables.zoneWidth) or DEFAULT_ZONE_WIDTH
    return math.max(MIN_ZONE_WIDTH, math.min(MAX_ZONE_WIDTH, math.floor(width + 0.5)))
end

function addon:GetWindowWidth()
    return self:GetZoneColumnWidth() + COUNT_COLUMN_WIDTH
end

function addon:ApplyWidth()
    if not self.container then
        return
    end

    local zoneWidth = self:GetZoneColumnWidth()
    local windowWidth = zoneWidth + COUNT_COLUMN_WIDTH
    self.container:SetWidth(windowWidth)
    self.headerLabel:SetWidth(windowWidth)
    self.moreLabel:SetWidth(windowWidth)

    for _, row in ipairs(self.rows) do
        row:SetWidth(windowWidth)
        row.zoneLabel:SetWidth(zoneWidth)
        row.countLabel:SetWidth(COUNT_COLUMN_WIDTH)
    end
end

local function ApplyLabelColor(label, color, fallback)
    color = color or fallback
    label:SetColor(
        color.r or fallback.r,
        color.g or fallback.g,
        color.b or fallback.b,
        color.a or fallback.a
    )
end

function addon:ApplyColors()
    if not self.headerLabel then
        return
    end

    ApplyLabelColor(self.headerLabel, self.savedVariables.headerColor, DEFAULT_HEADER_COLOR)
    ApplyLabelColor(self.moreLabel, self.savedVariables.footerColor, DEFAULT_FOOTER_COLOR)
    for _, row in ipairs(self.rows) do
        ApplyLabelColor(row.zoneLabel, self.savedVariables.zoneColor, DEFAULT_ZONE_COLOR)
    end
end

function addon:CollectZones()
    local zonesById = {}
    local antiquityId = GetNextAntiquityId()

    while antiquityId do
        if DoesAntiquityHaveLead(antiquityId) then
            local timeRemaining = GetAntiquityLeadTimeRemainingSeconds(antiquityId)
            if timeRemaining and timeRemaining > 0 then
                local zoneId = GetAntiquityZoneId(antiquityId)
                if zoneId and zoneId > 0 then
                    local zoneData = zonesById[zoneId]
                    if not zoneData then
                        zoneData = {
                            zoneId = zoneId,
                            name = FormatZoneName(zoneId),
                            count = 0,
                            qualityCounts = {},
                            earliestExpiration = timeRemaining,
                        }
                        zonesById[zoneId] = zoneData
                    end

                    zoneData.count = zoneData.count + 1
                    zoneData.earliestExpiration = math.min(zoneData.earliestExpiration, timeRemaining)

                    local quality = GetAntiquityQuality(antiquityId)
                    zoneData.qualityCounts[quality] = (zoneData.qualityCounts[quality] or 0) + 1
                end
            end
        end

        antiquityId = GetNextAntiquityId(antiquityId)
    end

    local zones = {}
    for _, zoneData in pairs(zonesById) do
        zones[#zones + 1] = zoneData
    end
    table.sort(zones, CompareZones)
    return zones
end

function addon:CollectPreviewZones()
    local zones = {}
    local previewCounts = { 9, 7, 6, 5, 4, 3, 3, 2, 2, 1, 1 }

    for index = 1, PREVIEW_ZONE_COUNT do
        local quality = PREVIEW_QUALITIES[((index - 1) % #PREVIEW_QUALITIES) + 1]
        local count = previewCounts[index]
        zones[index] = {
            zoneId = index,
            name = zo_strformat(GetString(SI_LEADDIGGER_PREVIEW_ZONE), index),
            count = count,
            qualityCounts = { [quality] = count },
            earliestExpiration = index * 3600,
        }
    end

    table.sort(zones, CompareZones)
    return zones
end

function addon:Refresh()
    if not self.content then
        return
    end

    if self.savedVariables.hidden then
        self.content:SetHidden(true)
        self.container:SetMouseEnabled(false)
        return
    end

    local zones = self.previewMode and self:CollectPreviewZones() or self:CollectZones()
    local configuredZoneCount = tonumber(self.savedVariables.visibleZones) or DEFAULT_VISIBLE_ZONES
    configuredZoneCount = math.max(1, math.min(MAX_CONFIGURABLE_ZONES, configuredZoneCount))
    local visibleZoneCount = math.min(#zones, configuredZoneCount)
    local headerIsVisible = self.savedVariables.showHeader
    local headerRowCount = headerIsVisible and 1 or 0

    self.headerLabel:SetHidden(not headerIsVisible)

    for index, row in ipairs(self.rows) do
        row:ClearAnchors()
        row:SetAnchor(TOPLEFT, self.content, TOPLEFT, 0, (headerRowCount + index - 1) * ROW_HEIGHT)
        local zoneData = zones[index]
        if index <= visibleZoneCount and zoneData then
            row.zoneLabel:SetText(zoneData.name)
            row.countLabel:SetText(tostring(zoneData.count))

            local quality = GetBestQuality(zoneData)
            local red, green, blue = GetInterfaceColor(INTERFACE_COLOR_TYPE_ANTIQUITY_QUALITY_COLORS, quality)
            row.countLabel:SetColor(red, green, blue, 1)
            row:SetHidden(false)
        else
            row:SetHidden(true)
        end
    end

    local hiddenZoneCount = #zones - visibleZoneCount
    local footerIsVisible = self.savedVariables.showFooter and hiddenZoneCount > 0
    self.moreLabel:ClearAnchors()
    self.moreLabel:SetAnchor(TOPLEFT, self.content, TOPLEFT, 0, (headerRowCount + visibleZoneCount) * ROW_HEIGHT)
    if footerIsVisible then
        self.moreLabel:SetText(FormatMoreZones(hiddenZoneCount))
        self.moreLabel:SetHidden(false)
    else
        self.moreLabel:SetHidden(true)
    end

    local displayedRowCount = headerRowCount + visibleZoneCount + (footerIsVisible and 1 or 0)
    local windowHeight = math.max(1, displayedRowCount) * ROW_HEIGHT
    self.container:SetHeight(windowHeight)

    local hasLeads = #zones > 0
    self.content:SetHidden(not hasLeads)
    self.container:SetMouseEnabled(hasLeads and not self.savedVariables.locked)
end

function addon:ScheduleRefresh(delayMs)
    local updateName = ADDON_NAME .. "ScheduledRefresh"
    EVENT_MANAGER:UnregisterForUpdate(updateName)
    EVENT_MANAGER:RegisterForUpdate(updateName, delayMs or REFRESH_DELAY_MS, function()
        EVENT_MANAGER:UnregisterForUpdate(updateName)
        self:Refresh()
    end)
end

function addon:SavePosition()
    local left = self.container:GetLeft()
    local top = self.container:GetTop()
    if left and top then
        self.savedVariables.left = math.floor(left + 0.5)
        self.savedVariables.top = math.floor(top + 0.5)
        self.savedVariables.hasPosition = true
    end
end

function addon:RestorePosition()
    self.container:ClearAnchors()
    if self.savedVariables.hasPosition then
        self.container:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self.savedVariables.left, self.savedVariables.top)
    else
        self.container:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -80, 260)
    end
end

function addon:SetLocked(locked)
    self.savedVariables.locked = locked
    self.container:SetMovable(not locked)
    self:Refresh()
end

function addon:SetShown(shown)
    self.savedVariables.hidden = not shown
    self:Refresh()
end

function addon:ToggleVisibility()
    self:SetShown(self.savedVariables.hidden)
    Print(GetString(self.savedVariables.hidden and SI_LEADDIGGER_CHAT_HIDDEN or SI_LEADDIGGER_CHAT_SHOWN))
end

function addon:ResetPosition()
    self.savedVariables.hasPosition = false
    self:RestorePosition()
    Print(GetString(SI_LEADDIGGER_CHAT_RESET))
end

function addon:CreateRow(index)
    local row = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "Row" .. index, self.content, CT_CONTROL)
    row:SetDimensions(self:GetWindowWidth(), ROW_HEIGHT)
    row:SetAnchor(TOPLEFT, self.content, TOPLEFT, 0, (index - 1) * ROW_HEIGHT)

    local zoneLabel = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "Row" .. index .. "Zone", row, CT_LABEL)
    zoneLabel:SetFont("ZoFontGameShadow")
    zoneLabel:SetColor(1, 1, 1, 1)
    zoneLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    zoneLabel:SetAnchor(LEFT, row, LEFT, 0, 0)
    zoneLabel:SetDimensions(self:GetZoneColumnWidth(), ROW_HEIGHT)

    local countLabel = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "Row" .. index .. "Count", row, CT_LABEL)
    countLabel:SetFont("ZoFontGameShadow")
    countLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    countLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    countLabel:SetAnchor(RIGHT, row, RIGHT, 0, 0)
    countLabel:SetDimensions(COUNT_COLUMN_WIDTH, ROW_HEIGHT)

    row.zoneLabel = zoneLabel
    row.countLabel = countLabel
    return row
end

function addon:CreateUI()
    local container = WINDOW_MANAGER:CreateTopLevelWindow(ADDON_NAME .. "Container")
    container:SetDimensions(self:GetWindowWidth(), DEFAULT_WINDOW_HEIGHT)
    container:SetClampedToScreen(true)
    container:SetDrawTier(DT_HIGH)
    container:SetDrawLayer(DL_OVERLAY)
    container:SetMovable(not self.savedVariables.locked)
    container:SetHandler("OnMoveStop", function()
        self:SavePosition()
    end)
    self.container = container

    local content = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "Content", container, CT_CONTROL)
    content:SetAnchorFill(container)
    self.content = content

    local headerLabel = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "Header", content, CT_LABEL)
    headerLabel:SetFont("ZoFontGameShadow")
    headerLabel:SetColor(1, 1, 1, 1)
    headerLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    headerLabel:SetAnchor(TOPLEFT, content, TOPLEFT, 0, 0)
    headerLabel:SetDimensions(self:GetWindowWidth(), ROW_HEIGHT)
    headerLabel:SetText(GetString(SI_LEADDIGGER_HEADER))
    self.headerLabel = headerLabel

    self.rows = {}
    for index = 1, MAX_CONFIGURABLE_ZONES do
        self.rows[index] = self:CreateRow(index)
    end

    local moreLabel = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "More", content, CT_LABEL)
    moreLabel:SetFont("ZoFontGameShadow")
    moreLabel:SetColor(0.72, 0.72, 0.72, 1)
    moreLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    moreLabel:SetAnchor(TOPLEFT, content, TOPLEFT, 0, (DEFAULT_VISIBLE_ZONES + 1) * ROW_HEIGHT)
    moreLabel:SetDimensions(self:GetWindowWidth(), ROW_HEIGHT)
    self.moreLabel = moreLabel

    self:ApplyColors()
    self:RestorePosition()

    self.fragment = ZO_SimpleSceneFragment:New(container)
    HUD_SCENE:AddFragment(self.fragment)
    HUD_UI_SCENE:AddFragment(self.fragment)
end

function addon:RegisterSettings()
    local panelId = ADDON_NAME .. "Settings"
    local panelData = {
        type = "panel",
        name = DISPLAY_NAME,
        displayName = DISPLAY_NAME,
        author = "manukartofanu",
        version = GetDisplayVersion(),
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsData = {
        {
            type = "checkbox",
            name = GetString(SI_LEADDIGGER_SETTING_SHOW),
            tooltip = GetString(SI_LEADDIGGER_SETTING_SHOW_TOOLTIP),
            getFunc = function()
                return not self.savedVariables.hidden
            end,
            setFunc = function(value)
                self:SetShown(value)
            end,
            default = true,
        },
        {
            type = "checkbox",
            name = GetString(SI_LEADDIGGER_SETTING_LOCK),
            tooltip = GetString(SI_LEADDIGGER_SETTING_LOCK_TOOLTIP),
            getFunc = function()
                return self.savedVariables.locked
            end,
            setFunc = function(value)
                self:SetLocked(value)
            end,
            disabled = function()
                return self.savedVariables.hidden
            end,
            default = false,
        },
        {
            type = "checkbox",
            name = GetString(SI_LEADDIGGER_SETTING_PREVIEW),
            tooltip = GetString(SI_LEADDIGGER_SETTING_PREVIEW_TOOLTIP),
            getFunc = function()
                return self.previewMode
            end,
            setFunc = function(value)
                self.previewMode = value
                self:Refresh()
            end,
            disabled = function()
                return self.savedVariables.hidden
            end,
            default = false,
        },
        {
            type = "slider",
            name = GetString(SI_LEADDIGGER_SETTING_ZONES_SHOWN),
            tooltip = GetString(SI_LEADDIGGER_SETTING_ZONES_SHOWN_TOOLTIP),
            min = 1,
            max = MAX_CONFIGURABLE_ZONES,
            step = 1,
            decimals = 0,
            clampInput = true,
            getFunc = function()
                return self.savedVariables.visibleZones
            end,
            setFunc = function(value)
                self.savedVariables.visibleZones = value
                self:Refresh()
            end,
            disabled = function()
                return self.savedVariables.hidden
            end,
            default = DEFAULT_VISIBLE_ZONES,
        },
        {
            type = "slider",
            name = GetString(SI_LEADDIGGER_SETTING_ZONE_WIDTH),
            tooltip = GetString(SI_LEADDIGGER_SETTING_ZONE_WIDTH_TOOLTIP),
            min = MIN_ZONE_WIDTH,
            max = MAX_ZONE_WIDTH,
            step = 10,
            decimals = 0,
            clampInput = true,
            getFunc = function()
                return self:GetZoneColumnWidth()
            end,
            setFunc = function(value)
                self.savedVariables.zoneWidth = value
                self:ApplyWidth()
            end,
            disabled = function()
                return self.savedVariables.hidden
            end,
            default = DEFAULT_ZONE_WIDTH,
        },
        {
            type = "colorpicker",
            name = GetString(SI_LEADDIGGER_SETTING_ZONE_COLOR),
            tooltip = GetString(SI_LEADDIGGER_SETTING_ZONE_COLOR_TOOLTIP),
            getFunc = function()
                local color = self.savedVariables.zoneColor or DEFAULT_ZONE_COLOR
                return color.r, color.g, color.b, color.a
            end,
            setFunc = function(red, green, blue, alpha)
                self.savedVariables.zoneColor = { r = red, g = green, b = blue, a = alpha or 1 }
                self:ApplyColors()
            end,
            disabled = function()
                return self.savedVariables.hidden
            end,
            default = DEFAULT_ZONE_COLOR,
        },
        {
            type = "checkbox",
            name = GetString(SI_LEADDIGGER_SETTING_SHOW_HEADER),
            tooltip = GetString(SI_LEADDIGGER_SETTING_SHOW_HEADER_TOOLTIP),
            getFunc = function()
                return self.savedVariables.showHeader
            end,
            setFunc = function(value)
                self.savedVariables.showHeader = value
                self:Refresh()
            end,
            disabled = function()
                return self.savedVariables.hidden
            end,
            default = true,
        },
        {
            type = "colorpicker",
            name = GetString(SI_LEADDIGGER_SETTING_HEADER_COLOR),
            tooltip = GetString(SI_LEADDIGGER_SETTING_HEADER_COLOR_TOOLTIP),
            getFunc = function()
                local color = self.savedVariables.headerColor or DEFAULT_HEADER_COLOR
                return color.r, color.g, color.b, color.a
            end,
            setFunc = function(red, green, blue, alpha)
                self.savedVariables.headerColor = { r = red, g = green, b = blue, a = alpha or 1 }
                self:ApplyColors()
            end,
            disabled = function()
                return self.savedVariables.hidden or not self.savedVariables.showHeader
            end,
            default = DEFAULT_HEADER_COLOR,
        },
        {
            type = "checkbox",
            name = GetString(SI_LEADDIGGER_SETTING_SHOW_FOOTER),
            tooltip = GetString(SI_LEADDIGGER_SETTING_SHOW_FOOTER_TOOLTIP),
            getFunc = function()
                return self.savedVariables.showFooter
            end,
            setFunc = function(value)
                self.savedVariables.showFooter = value
                self:Refresh()
            end,
            disabled = function()
                return self.savedVariables.hidden
            end,
            default = true,
        },
        {
            type = "colorpicker",
            name = GetString(SI_LEADDIGGER_SETTING_FOOTER_COLOR),
            tooltip = GetString(SI_LEADDIGGER_SETTING_FOOTER_COLOR_TOOLTIP),
            getFunc = function()
                local color = self.savedVariables.footerColor or DEFAULT_FOOTER_COLOR
                return color.r, color.g, color.b, color.a
            end,
            setFunc = function(red, green, blue, alpha)
                self.savedVariables.footerColor = { r = red, g = green, b = blue, a = alpha or 1 }
                self:ApplyColors()
            end,
            disabled = function()
                return self.savedVariables.hidden or not self.savedVariables.showFooter
            end,
            default = DEFAULT_FOOTER_COLOR,
        },
    }

    LibAddonMenu2:RegisterAddonPanel(panelId, panelData)
    LibAddonMenu2:RegisterOptionControls(panelId, optionsData)
end

function addon:RegisterSlashCommands()
    local function HandleCommand(arguments)
        local command = zo_strlower(zo_strtrim(arguments or ""))
        if command == "" then
            self:ToggleVisibility()
        elseif command == "lock" then
            self:SetLocked(true)
            Print(GetString(SI_LEADDIGGER_CHAT_LOCKED))
        elseif command == "unlock" then
            self:SetLocked(false)
            Print(GetString(SI_LEADDIGGER_CHAT_UNLOCKED))
        elseif command == "reset" then
            self:ResetPosition()
        elseif command == "show" then
            self:SetShown(true)
            Print(GetString(SI_LEADDIGGER_CHAT_SHOWN))
        elseif command == "hide" then
            self:SetShown(false)
            Print(GetString(SI_LEADDIGGER_CHAT_HIDDEN))
        else
            Print(GetString(SI_LEADDIGGER_CHAT_COMMANDS))
        end
    end

    SLASH_COMMANDS["/ld"] = HandleCommand
    SLASH_COMMANDS["/leaddigger"] = HandleCommand
end

function addon:RegisterEvents()
    local function RefreshSoon()
        self:ScheduleRefresh()
    end

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, RefreshSoon)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ANTIQUITIES_UPDATED, RefreshSoon)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ANTIQUITY_UPDATED, RefreshSoon)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ANTIQUITY_LEAD_ACQUIRED, RefreshSoon)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ANTIQUITY_DIGGING_ANTIQUITY_UNEARTHED, RefreshSoon)

    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "PeriodicRefresh", PERIODIC_REFRESH_MS, function()
        self:Refresh()
    end)
end

function addon:Initialize()
    self.previewMode = false
    self.savedVariables = ZO_SavedVars:NewAccountWide(
        SAVED_VARIABLES_NAME,
        SAVED_VARIABLES_VERSION,
        nil,
        DEFAULTS,
        GetWorldName()
    )

    self:CreateUI()
    self:RegisterSettings()
    self:RegisterSlashCommands()
    self:RegisterEvents()
    self:ScheduleRefresh()
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    addon:Initialize()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
