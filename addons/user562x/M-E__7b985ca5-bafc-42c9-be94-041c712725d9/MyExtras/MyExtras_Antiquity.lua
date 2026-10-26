local ME = MyExtras
local AR = {}
ME.Antiquity = AR

--------------------------------------------------
-- Config
--------------------------------------------------
local SUBMENU_ICON   = "EsoUI/Art/Journal/Gamepad/GP_journal_tabIcon_antiquities.dds"
local POPUP_ICON     = "EsoUI/Art/Journal/Gamepad/GP_journal_tabIcon_antiquities.dds"

local CHECK_DELAY_MS = 3000
local WAIT_MS        = 1000

local POPUP_WIDTH    = 640
local POPUP_HEIGHT   = 170
local POPUP_Y        = -335
local POPUP_ICON_SIZE = 40
local POPUP_GAP      = 10
local POPUP_PAD      = 44
local POPUP_PAD_Y    = 20
local POPUP_LINE_GAP = 10

local TIMER_NAME = ME.name .. "_AntiquityTimer"
local WAIT_NAME  = ME.name .. "_AntiquityWait"
local TICK_NAME  = ME.name .. "_AntiquityTick"
local TICK_MS    = 100

local JOURNAL_SCENE    = "gamepad_antiquity_journal"
local TRAVEL_WINDOW_MS = 30000
local JOURNAL_DELAY_MS = 1500

local FRAME_GREY = { 0.55, 0.55, 0.55 }

AR.defaults = {
    antiquityEnabled      = true,
    antiquityCheckLogin   = true,
    antiquityCheckZone    = false,
    antiquityCheckTimer   = false,
    antiquityTimerMinutes = 30,
    antiquityDays         = 5,
    antiquityHours        = 0,
    antiquityPopupSeconds = 10,
    antiquityPopupSize    = 120,
}

AR.charDefaults = {
    antiquityUseCharacter = false,
}

AR.checkChoices = {
    { name = "Log In",      value = "login" },
    { name = "Zone Change", value = "zone"  },
    { name = "Timer",       value = "timer" },
}

local CHECK_KEYS = {
    login = "antiquityCheckLogin",
    zone  = "antiquityCheckZone",
    timer = "antiquityCheckTimer",
}

AR.dirty        = true
AR.pageOptions  = nil
AR.pending      = nil
AR.popupShowing = false
AR.preview      = false
AR.activated    = false
AR.lastZoneId   = nil
AR.travelLead   = nil
AR.journalLead  = nil

--------------------------------------------------
-- Helpers
--------------------------------------------------
local charFilled = false

local function CharSettings()
    local cv = ME.charVariables
    if not cv then return nil end
    if type(cv.antiquityCharSettings) ~= "table" then cv.antiquityCharSettings = {} end
    local settings = cv.antiquityCharSettings
    if not settings.seeded then
        local account = ME.savedVariables
        for key, value in pairs(AR.defaults) do
            local current = account and account[key]
            if current == nil then current = value end
            settings[key] = current
        end
        settings.seeded = true
        charFilled = true
    elseif not charFilled then
        for key, value in pairs(AR.defaults) do
            if settings[key] == nil then settings[key] = value end
        end
        charFilled = true
    end
    return settings
end

function AR:UsesCharacterSettings()
    return ME.charVariables ~= nil and ME.charVariables.antiquityUseCharacter == true
end

local function SV()
    if AR:UsesCharacterSettings() then
        return CharSettings() or ME.savedVariables
    end
    return ME.savedVariables
end

local function SavedTip()
    if AR:UsesCharacterSettings() then return ME.SAVED_CHARACTER_TIP end
    return ME.SAVED_ACCOUNT_TIP
end

local function Plural(count, one, many)
    if count == 1 then return "1 " .. one end
    return count .. " " .. many
end

local function LimitSeconds()
    local sv = SV()
    local days = tonumber(sv.antiquityDays) or 0
    local hours = tonumber(sv.antiquityHours) or 0
    return days * 86400 + hours * 3600
end

local function LimitText()
    local sv = SV()
    local days = tonumber(sv.antiquityDays) or 0
    local hours = tonumber(sv.antiquityHours) or 0
    if days > 0 and hours > 0 then
        return Plural(days, "day", "days") .. " " .. Plural(hours, "hour", "hours")
    elseif days > 0 then
        return Plural(days, "day", "days")
    end
    return Plural(hours, "hour", "hours")
end

local function ShortTime(seconds)
    if type(ZO_FormatAntiquityLeadTime) == "function" then
        return ZO_FormatAntiquityLeadTime(seconds)
    end
    return ZO_FormatTimeLargestTwo(seconds, TIME_FORMAT_STYLE_DESCRIPTIVE_MINIMAL_HIDE_ZEROES)
end

local function LongTime(seconds)
    return ZO_FormatTimeLargestTwo(seconds, TIME_FORMAT_STYLE_DESCRIPTIVE)
end

local function AccentColor()
    local sv = ME.savedVariables
    if sv.settingsHighlight == "Custom" and type(sv.settingsHighlightColor) == "table" then
        local c = sv.settingsHighlightColor
        return c.r or 1, c.g or 1, c.b or 1
    end
    local c = GetAllianceColor(GetUnitAlliance("player"))
    return c.r, c.g, c.b
end

local function RefreshPanelPages()
    AR.dirty = true
    local panel = ME.settingsPanel
    if panel and panel.RefreshPages then panel:RefreshPages() end
end

--------------------------------------------------
-- Leads
--------------------------------------------------
local function ScanLeads()
    local leads = {}
    local antiquityId = GetNextAntiquityId()
    while antiquityId do
        if DoesAntiquityHaveLead(antiquityId) then
            local remaining = GetAntiquityLeadTimeRemainingSeconds(antiquityId)
            if remaining and remaining > 0 then
                leads[#leads + 1] = { id = antiquityId, remaining = remaining }
            end
        end
        antiquityId = GetNextAntiquityId(antiquityId)
    end
    return leads
end

local function SortByRemaining(a, b)
    return a.remaining < b.remaining
end

local function ExpiringLeads()
    local limit = LimitSeconds()
    local list = {}
    if limit <= 0 then return list end
    local leads = ScanLeads()
    for i = 1, #leads do
        if leads[i].remaining <= limit then
            list[#list + 1] = leads[i]
        end
    end
    table.sort(list, SortByRemaining)
    return list
end

--------------------------------------------------
-- Popup
--------------------------------------------------
function AR:CreatePopup()
    if self.popup then return end
    local wm = WINDOW_MANAGER

    local root = wm:CreateTopLevelWindow("MyExtras_AntiquityPopupRoot")
    root:SetDimensions(1, 1)
    root:SetAnchor(CENTER, GuiRoot, CENTER, 0, POPUP_Y)
    root:SetDrawLayer(DL_OVERLAY)
    root:SetDrawTier(DT_HIGH)
    root:SetMouseEnabled(false)
    root:SetHidden(true)

    local popup = wm:CreateControl("MyExtras_AntiquityPopup", root, CT_CONTROL)
    popup:SetDimensions(POPUP_WIDTH, POPUP_HEIGHT)
    popup:SetAnchor(CENTER, root, CENTER, 0, 0)

    local bg = wm:CreateControlFromVirtual("MyExtras_AntiquityPopupBg", popup, "ZO_GamepadWhiteOutlineThin")
    bg:SetAnchorFill(popup)
    bg:SetCenterColor(0.02, 0.02, 0.03, 0.85)
    bg:SetEdgeColor(FRAME_GREY[1], FRAME_GREY[2], FRAME_GREY[3], 1)

    local icon = wm:CreateControl("MyExtras_AntiquityPopupIcon", popup, CT_TEXTURE)
    icon:SetDimensions(POPUP_ICON_SIZE, POPUP_ICON_SIZE)
    icon:SetTexture(POPUP_ICON)

    local title = wm:CreateControl("MyExtras_AntiquityPopupTitle", popup, CT_LABEL)
    title:SetFont("$(GAMEPAD_MEDIUM_FONT)|34|soft-shadow-thick")
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    title:SetText("Antiquity Reminder")

    local body = wm:CreateControl("MyExtras_AntiquityPopupBody", popup, CT_LABEL)
    body:SetFont("$(GAMEPAD_MEDIUM_FONT)|27|soft-shadow-thick")
    body:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    body:SetColor(0.82, 0.85, 0.9, 1)

    local hint = wm:CreateControl("MyExtras_AntiquityPopupHint", popup, CT_LABEL)
    hint:SetFont("$(GAMEPAD_MEDIUM_FONT)|27|soft-shadow-thick")
    hint:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    hint:SetColor(1, 1, 1, 1)

    local countdown = wm:CreateControl("MyExtras_AntiquityPopupCountdown", popup, CT_LABEL)
    countdown:SetFont("$(GAMEPAD_MEDIUM_FONT)|22|soft-shadow-thick")
    countdown:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    countdown:SetColor(0.7, 0.72, 0.76, 1)
    countdown:SetAnchor(BOTTOMRIGHT, popup, BOTTOMRIGHT, -12, -8)

    self.popupRoot = root
    self.popup = popup
    self.popupIcon = icon
    self.popupTitle = title
    self.popupBody = body
    self.popupHint = hint
    self.popupCountdown = countdown
end

local function MeasureWidth(label, maxWidth)
    label:SetWidth(maxWidth)
    local width = math.ceil(label:GetTextWidth() or 0) + 2
    if width > maxWidth then width = maxWidth end
    return width
end

function AR:LayoutPopup()
    local maxLine = POPUP_WIDTH - POPUP_PAD * 2
    local title, body, hint = self.popupTitle, self.popupBody, self.popupHint

    local titleWidth = MeasureWidth(title, maxLine - POPUP_ICON_SIZE - POPUP_GAP)
    local bodyWidth = MeasureWidth(body, maxLine)
    local hintWidth = MeasureWidth(hint, maxLine)

    local rowWidth = POPUP_ICON_SIZE + POPUP_GAP + titleWidth
    local lineWidth = math.max(rowWidth, bodyWidth, hintWidth)

    title:SetWidth(titleWidth)
    body:SetWidth(lineWidth)
    hint:SetWidth(lineWidth)

    local titleHeight = math.max(title:GetTextHeight() or 0, POPUP_ICON_SIZE)
    local textHeight = titleHeight
        + (body:GetTextHeight() or 0)
        + (hint:GetTextHeight() or 0)
        + POPUP_LINE_GAP * 2

    local width = lineWidth + POPUP_PAD * 2
    local height = textHeight + POPUP_PAD_Y * 2
    self.popup:SetDimensions(width, height)

    local startX = math.floor((width - rowWidth) / 2 + 0.5)

    self.popupIcon:ClearAnchors()
    self.popupIcon:SetAnchor(LEFT, self.popup, TOPLEFT, startX, POPUP_PAD_Y + titleHeight / 2)

    title:ClearAnchors()
    title:SetAnchor(LEFT, self.popupIcon, RIGHT, POPUP_GAP, 0)

    body:ClearAnchors()
    body:SetAnchor(TOP, self.popup, TOP, 0, POPUP_PAD_Y + titleHeight + POPUP_LINE_GAP)
    hint:ClearAnchors()
    hint:SetAnchor(TOP, body, BOTTOM, 0, POPUP_LINE_GAP)
end

function AR:ApplyPopupSize()
    if not self.popup then return end
    local size = tonumber(SV().antiquityPopupSize) or self.defaults.antiquityPopupSize
    self.popup:SetScale(size / 100)
end

local function PopupSeconds()
    return tonumber(SV().antiquityPopupSeconds) or AR.defaults.antiquityPopupSeconds
end

function AR:RefreshCountdown()
    local remaining = (self.popupEndsMs or 0) - GetFrameTimeMilliseconds()
    if remaining <= 0 then
        if self.popupShowing then
            self:HidePopup()
            return
        end
        self.popupEndsMs = GetFrameTimeMilliseconds() + PopupSeconds() * 1000
        remaining = PopupSeconds() * 1000
    end
    local seconds = math.ceil(remaining / 1000)
    if seconds ~= self.countdownShown then
        self.countdownShown = seconds
        self.popupCountdown:SetText(tostring(seconds))
    end
end

local function OnCountdownTick()
    AR:RefreshCountdown()
end

function AR:StartCountdown()
    self.popupEndsMs = GetFrameTimeMilliseconds() + PopupSeconds() * 1000
    self.countdownShown = nil
    self:RefreshCountdown()
    EVENT_MANAGER:UnregisterForUpdate(TICK_NAME)
    EVENT_MANAGER:RegisterForUpdate(TICK_NAME, TICK_MS, OnCountdownTick)
end

function AR:FillPopup(count)
    local r, g, b = AccentColor()
    self.popupTitle:SetColor(r, g, b, 1)

    local limitText = LimitText()
    local startKey = ZO_Keybindings_GenerateIconKeyMarkup(KEY_GAMEPAD_START, 100)
    if count == 1 then
        self.popupBody:SetText("1 lead expires within " .. limitText .. ".")
        self.popupHint:SetText("Press " .. startKey .. " to view it.")
    else
        self.popupBody:SetText(count .. " leads expire within " .. limitText .. ".")
        self.popupHint:SetText("Press " .. startKey .. " to view them.")
    end

    self:ApplyPopupSize()
    self:LayoutPopup()
end

function AR:ShowPreview()
    self:CreatePopup()
    self:FillPopup(2)
    self.popupRoot:SetHidden(false)
    self:StartCountdown()
end

function AR:SetPreview(value)
    self.preview = value == true
    if self.popupShowing then return end
    if self.preview then
        self:ShowPreview()
    else
        EVENT_MANAGER:UnregisterForUpdate(TICK_NAME)
        if self.popupRoot then self.popupRoot:SetHidden(true) end
    end
end

function AR:RefreshPreview()
    if self.preview and not self.popupShowing and self.popup then
        self:ShowPreview()
    end
end

function AR:HidePopup()
    EVENT_MANAGER:UnregisterForUpdate(TICK_NAME)
    self.popupShowing = false
    if self.preview then
        self:ShowPreview()
        return
    end
    if self.popupRoot then self.popupRoot:SetHidden(true) end
end

function AR:ShowPopup(count)
    self:CreatePopup()
    self:FillPopup(count)
    self.popupRoot:SetHidden(false)
    self.popupShowing = true
    PlaySound(SOUNDS.NEW_NOTIFICATION)
    self:StartCountdown()
end

local function CanShowPopup()
    if not SCENE_MANAGER:IsShowing("hud") then return false end
    if IsUnitInCombat("player") or IsUnitDead("player") then return false end
    return true
end

function AR:TryShowPending()
    if not self.pending then
        EVENT_MANAGER:UnregisterForUpdate(WAIT_NAME)
        return
    end
    if not CanShowPopup() then return end
    EVENT_MANAGER:UnregisterForUpdate(WAIT_NAME)

    local pending = self.pending
    self.pending = nil
    if not SV().antiquityEnabled then return end
    self:ShowPopup(#pending)
end

function AR:QueuePopup(list)
    self.pending = list
    EVENT_MANAGER:UnregisterForUpdate(WAIT_NAME)
    if CanShowPopup() then
        self:TryShowPending()
    else
        EVENT_MANAGER:RegisterForUpdate(WAIT_NAME, WAIT_MS, function() AR:TryShowPending() end)
    end
end

--------------------------------------------------
-- Checks
--------------------------------------------------
function AR:RunCheck()
    if not SV().antiquityEnabled then return end
    local list = ExpiringLeads()
    if #list == 0 then return end
    self:QueuePopup(list)
end

function AR:ScheduleCheck()
    zo_callLater(function() AR:RunCheck() end, CHECK_DELAY_MS)
end

function AR:ApplyTimer()
    EVENT_MANAGER:UnregisterForUpdate(TIMER_NAME)
    local sv = SV()
    if not (sv.antiquityEnabled and sv.antiquityCheckTimer) then return end
    local minutes = tonumber(sv.antiquityTimerMinutes) or self.defaults.antiquityTimerMinutes
    if minutes < 1 then minutes = 1 end
    EVENT_MANAGER:RegisterForUpdate(TIMER_NAME, minutes * 60000, function() AR:RunCheck() end)
end

--------------------------------------------------
-- Open List
--------------------------------------------------
function AR:FirstLeadRow()
    return #self:SettingOptions() + 2
end

function AR:OpenList()
    if not self.submenu then return end
    self.dirty = true
    ME:OpenPage(self.submenu, self:FirstLeadRow())
end

local function OnToggleUIMode()
    if not AR.popupShowing then return false end
    if not IsGameCameraActive() or SCENE_MANAGER:IsInUIMode() then return false end
    if not ME.settingsPanel then return false end
    AR:HidePopup()
    AR:OpenList()
    return true
end

function AR:InstallHooks()
    ZO_PreHook(SCENE_MANAGER, "OnToggleUIModeBinding", OnToggleUIMode)

    local hud = SCENE_MANAGER:GetScene("hud")
    if hud then
        hud:RegisterCallback("StateChange", function(oldState, newState)
            if newState == SCENE_HIDING and AR.popupShowing then
                AR:HidePopup()
            end
        end)
    end
end

--------------------------------------------------
-- Settings
--------------------------------------------------
local function IsOff()
    return not SV().antiquityEnabled
end

function AR:SetEnabled(value)
    SV().antiquityEnabled = value
    if not value then
        self.pending = nil
        EVENT_MANAGER:UnregisterForUpdate(WAIT_NAME)
        self.preview = false
        self:HidePopup()
    end
    self:ApplyTimer()
end

function AR:SetUseCharacterSettings(value)
    local cv = ME.charVariables
    if not cv then return end
    value = value == true
    if (cv.antiquityUseCharacter == true) == value then return end
    cv.antiquityUseCharacter = value
    if not SV().antiquityEnabled then
        self.pending = nil
        EVENT_MANAGER:UnregisterForUpdate(WAIT_NAME)
        self.preview = false
        self:HidePopup()
    end
    self:ApplyTimer()
    self:RefreshPreview()
    RefreshPanelPages()
end

function AR:SettingOptions()
    if self.settingOptions then return self.settingOptions end
    local defaults = self.defaults

    self.settingOptions = {
        {
            type    = "toggle",
            name    = "Enabled",
            preset  = "YES_NO",
            default = defaults.antiquityEnabled,
            tooltip = "Your expiring leads still show on this page whether enabled or not.",
            getFunc = function() return SV().antiquityEnabled end,
            setFunc = function(val) AR:SetEnabled(val) end,
        },
        {
            type    = "toggle",
            name    = "Character Settings",
            tooltip = "Off uses the same settings for the whole account. On gives this character its own settings, "
                   .. "copied from the account settings the first time you turn it on.",
            details = function()
                if AR:UsesCharacterSettings() then
                    return "This character has its own settings."
                end
                return "All your characters share the same settings."
            end,
            getFunc = function() return AR:UsesCharacterSettings() end,
            setFunc = function(val) AR:SetUseCharacterSettings(val) end,
        },
        {
            type     = "toggle",
            name     = "Preview",
            tooltip  = "Shows it on screen so you can size it. Stays on until you turn it off or leave the settings.",
            disabled = IsOff,
            getFunc  = function() return AR.preview end,
            setFunc  = function(val) AR:SetPreview(val) end,
        },
        {
            type     = "checklist",
            name     = "Check On",
            choices  = self.checkChoices,
            default  = { "login" },
            tooltip  = "When it checks your leads.",
            disabled = IsOff,
            getFunc = function()
                local sv = SV()
                local values = {}
                for i = 1, #AR.checkChoices do
                    local value = AR.checkChoices[i].value
                    if sv[CHECK_KEYS[value]] then values[#values + 1] = value end
                end
                return values
            end,
            setFunc = function(values)
                local sv = SV()
                local set = {}
                if type(values) == "table" then
                    for i = 1, #values do set[values[i]] = true end
                end
                for value, key in pairs(CHECK_KEYS) do
                    sv[key] = set[value] == true
                end
                AR:ApplyTimer()
            end,
        },
        {
            type     = "slider",
            name     = "Timer Interval",
            min      = 5, max = 120, step = 5,
            default  = defaults.antiquityTimerMinutes,
            tooltip  = "How often it checks while you play, in minutes.\n\n"
                    .. "Default is " .. defaults.antiquityTimerMinutes .. ".",
            disabled = function() return IsOff() or not SV().antiquityCheckTimer end,
            getFunc  = function() return SV().antiquityTimerMinutes end,
            setFunc  = function(val)
                SV().antiquityTimerMinutes = val
                AR:ApplyTimer()
            end,
        },
        {
            type    = "slider",
            name    = "Days",
            min     = 0, max = 30, step = 1,
            default = defaults.antiquityDays,
            tooltip = "Leads with less time left than your Days and Hours show up here and in the pop-up.\n\n"
                   .. "Default is " .. defaults.antiquityDays .. ".",
            getFunc = function() return SV().antiquityDays end,
            setFunc = function(val)
                SV().antiquityDays = val
                RefreshPanelPages()
                AR:RefreshPreview()
            end,
        },
        {
            type    = "slider",
            name    = "Hours",
            min     = 0, max = 23, step = 1,
            default = defaults.antiquityHours,
            tooltip = "Leads with less time left than your Days and Hours show up here and in the pop-up.\n\n"
                   .. "Default is " .. defaults.antiquityHours .. ".",
            getFunc = function() return SV().antiquityHours end,
            setFunc = function(val)
                SV().antiquityHours = val
                RefreshPanelPages()
                AR:RefreshPreview()
            end,
        },
        {
            type     = "slider",
            name     = "Size",
            min      = 50, max = 150, step = 5,
            default  = defaults.antiquityPopupSize,
            tooltip  = "Default is " .. defaults.antiquityPopupSize .. ".",
            disabled = IsOff,
            getFunc  = function() return SV().antiquityPopupSize end,
            setFunc  = function(val)
                SV().antiquityPopupSize = val
                AR:ApplyPopupSize()
            end,
        },
        {
            type     = "slider",
            name     = "Pop-Up Duration",
            min      = 10, max = 30, step = 1,
            default  = defaults.antiquityPopupSeconds,
            tooltip  = "How long the pop-up stays on screen, in seconds.\n\n"
                    .. "Default is " .. defaults.antiquityPopupSeconds .. ".",
            disabled = IsOff,
            getFunc  = function() return SV().antiquityPopupSeconds end,
            setFunc  = function(val)
                SV().antiquityPopupSeconds = val
                AR:RefreshPreview()
            end,
        },
    }
    return self.settingOptions
end

--------------------------------------------------
-- Travel
--------------------------------------------------
local function WayshrinesByZone()
    local zones = {}
    for nodeIndex = 1, GetNumFastTravelNodes() do
        local known, _, _, _, _, _, poiType, _, locked = GetFastTravelNodeInfo(nodeIndex)
        if known and not locked and poiType == POI_TYPE_WAYSHRINE
            and GetFastTravelNodeHouseId(nodeIndex) == 0
            and not GetFastTravelNodeOutboundOnlyInfo(nodeIndex) then
            local zoneIndex = GetFastTravelNodePOIIndicies(nodeIndex)
            local zoneId = zoneIndex and GetZoneId(zoneIndex) or 0
            if zoneId and zoneId ~= 0 then
                local nodes = zones[zoneId]
                if not nodes then
                    nodes = {}
                    zones[zoneId] = nodes
                end
                nodes[#nodes + 1] = nodeIndex
            end
        end
    end
    return zones
end

local function ZoneWayshrines(zones, zoneId)
    if not zoneId or zoneId == 0 then return nil end
    local nodes = zones[zoneId]
    if nodes then return nodes end
    local parentId = GetParentZoneId(zoneId)
    if parentId and parentId ~= 0 and parentId ~= zoneId then
        return zones[parentId]
    end
    return nil
end

local function RecallCost(nodeIndex)
    return GetRecallCost(nodeIndex) or 0
end

local function TravelTo(nodes, antiquityId)
    if IsUnitDead("player") or IsInCampaign() or not CanLeaveCurrentLocationViaTeleport() then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, "You can't travel from here right now.")
        return
    end

    local nodeIndex = nodes[math.random(#nodes)]

    local cost = RecallCost(nodeIndex)
    local currency = GetRecallCurrency(nodeIndex)
    if cost > GetCurrencyAmount(currency, CURRENCY_LOCATION_CHARACTER) then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, "You don't have enough gold to travel.")
        return
    end

    AR.travelLead = { id = antiquityId, startMs = GetFrameTimeMilliseconds(), loading = false }
    FastTravelToNode(nodeIndex)
    SCENE_MANAGER:ShowBaseScene()
end

--------------------------------------------------
-- Journal
--------------------------------------------------
local function OnJournalShown()
    local antiquityId = AR.journalLead
    AR.journalLead = nil
    if not antiquityId then return end

    local journal = rawget(_G, "ANTIQUITY_JOURNAL_GAMEPAD")
    local category = rawget(_G, "ZO_SCRYABLE_ANTIQUITY_CURRENT_ZONE_SUBCATEGORY_DATA")
    if not (journal and category and journal.ViewCategory) then return end

    local manager = rawget(_G, "ANTIQUITY_DATA_MANAGER")
    local antiquityData = manager and manager.GetAntiquityData and manager:GetAntiquityData(antiquityId)
    pcall(journal.ViewCategory, journal, category, true, antiquityData)
end

function AR:InstallJournalHook()
    local scene = SCENE_MANAGER:GetScene(JOURNAL_SCENE)
    if not scene then return end
    scene:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_SHOWN then OnJournalShown() end
    end)
end

function AR:OpenJournal(antiquityId)
    if not SCENE_MANAGER:GetScene(JOURNAL_SCENE) then return end
    if IsUnitDead("player") then return end
    self.journalLead = antiquityId

    local mainMenu = SYSTEMS and SYSTEMS.GetObject and SYSTEMS:GetObject("mainMenu")
    if mainMenu and type(mainMenu.ShowAntiquityJournal) == "function" then
        mainMenu:ShowAntiquityJournal()
    else
        SCENE_MANAGER:Push(JOURNAL_SCENE)
    end
end

local function OnPlayerDeactivated()
    local lead = AR.travelLead
    if not lead then return end
    if GetFrameTimeMilliseconds() - lead.startMs <= TRAVEL_WINDOW_MS then
        lead.loading = true
    else
        AR.travelLead = nil
    end
end

function AR:TakeTravelLead()
    local lead = self.travelLead
    self.travelLead = nil
    if lead and lead.loading then return lead.id end
    return nil
end

--------------------------------------------------
-- List
--------------------------------------------------
local function LeadOption(lead, zones)
    local antiquityId = lead.id
    local name = ZO_CachedStrFormat(SI_ANTIQUITY_NAME_FORMATTER, GetAntiquityName(antiquityId))
    local colorDef = GetAntiquityQualityColor(GetAntiquityQuality(antiquityId))
    if colorDef then name = colorDef:Colorize(name) end

    local zoneId = GetAntiquityZoneId(antiquityId)
    local zoneName = zoneId and zoneId ~= 0 and zo_strformat(SI_ZONE_NAME, GetZoneNameById(zoneId)) or ""

    local tooltip = "Time Left: " .. LongTime(lead.remaining)
    if zoneName ~= "" then
        tooltip = "Zone: " .. zoneName .. "\n" .. tooltip
    end

    local option = {
        type    = "button",
        name    = name .. "   " .. ShortTime(lead.remaining),
        tooltip = tooltip,
    }

    local nodes = ZoneWayshrines(zones, zoneId)
    if nodes and #nodes > 0 then
        option.buttonText = "Travel"
        option.tooltip = function()
            local cost = RecallCost(nodes[1])
            local costText = "It costs gold to travel."
            if cost > 0 then costText = "It costs " .. ZO_CommaDelimitNumber(cost) .. " gold to travel." end
            return tooltip .. "\n\nTravel takes you to a random wayshrine you've unlocked in this zone. " .. costText
        end
        option.func = function() TravelTo(nodes, antiquityId) end
    elseif zoneName ~= "" then
        option.tooltip = tooltip .. "\n\nYou haven't unlocked a wayshrine you can travel to in this zone."
    end

    return option
end

function AR:BuildPageOptions()
    local options = {}
    local settings = self:SettingOptions()
    for i = 1, #settings do options[#options + 1] = settings[i] end

    local list = ExpiringLeads()
    local zones = #list > 0 and WayshrinesByZone() or {}
    options[#options + 1] = {
        type = "header",
        name = "Expiring Leads (" .. #list .. ")",
    }

    if #list == 0 then
        local emptyText = "No leads expire within " .. LimitText() .. "."
        if LimitSeconds() <= 0 then emptyText = "Set Days or Hours to see your expiring leads." end
        options[#options + 1] = {
            type    = "button",
            name    = emptyText,
            tooltip = "Leads with less time left than your Days and Hours show up here.",
        }
    else
        for i = 1, #list do
            options[#options + 1] = LeadOption(list[i], zones)
        end
    end

    self.pageOptions = options
    self.dirty = false
    return options
end

function AR:PageOptions()
    if self.dirty or not self.pageOptions then
        return self:BuildPageOptions()
    end
    return self.pageOptions
end

function AR:GetOptions()
    if not self.submenu then
        self.submenu = {
            type    = "submenu",
            name    = "Antiquity Reminder",
            icon    = SUBMENU_ICON,
            tooltip = function()
                return "Reminds you when your antiquity leads are about to expire, and lists every lead under your time.\n\n"
                    .. SavedTip()
            end,
            options = function() return AR:PageOptions() end,
        }
    end
    return { self.submenu }
end

function AR:OnSettingsState(newState)
    if newState == SCENE_HIDDEN then
        self.dirty = true
        self.pageOptions = nil
        if self.preview then self:SetPreview(false) end
    end
end

--------------------------------------------------
-- Lifecycle
--------------------------------------------------
function AR:Init()
    local sv = SV()
    sv.antiquitySeen = nil
    sv.antiquityOnlyNew = nil
    self:InstallHooks()
    self:InstallJournalHook()
    EVENT_MANAGER:RegisterForEvent(ME.name .. "_AntiquityTravel", EVENT_PLAYER_DEACTIVATED, OnPlayerDeactivated)
    self:ApplyTimer()
end

local function CurrentZoneId()
    local zoneId = GetZoneId(GetUnitZoneIndex("player")) or 0
    local parentId = GetParentZoneId(zoneId)
    if parentId and parentId ~= 0 then return parentId end
    return zoneId
end

function AR:OnPlayerActivated(initial)
    local sv = SV()
    local zoneId = CurrentZoneId()
    local changed = self.lastZoneId ~= nil and zoneId ~= self.lastZoneId
    self.lastZoneId = zoneId

    local travelId = self:TakeTravelLead()
    if travelId then
        zo_callLater(function() AR:OpenJournal(travelId) end, JOURNAL_DELAY_MS)
        return
    end

    if not self.activated then
        self.activated = true
        if initial ~= false and sv.antiquityCheckLogin then self:ScheduleCheck() end
    elseif changed and sv.antiquityCheckZone then
        self:ScheduleCheck()
    end
end

function AR:ResetSkipKeys()
    local keys = {}
    if self:UsesCharacterSettings() then
        for key in pairs(self.defaults) do keys[#keys + 1] = key end
    end
    return keys
end

function AR:OnReset()
    self.pending = nil
    EVENT_MANAGER:UnregisterForUpdate(WAIT_NAME)
    if self:UsesCharacterSettings() then
        local settings = CharSettings()
        if settings then
            for key, value in pairs(self.defaults) do
                settings[key] = value
            end
        end
    end
    self.preview = false
    self:HidePopup()
    self:ApplyTimer()
    RefreshPanelPages()
end

ME:RegisterFeature(AR)
