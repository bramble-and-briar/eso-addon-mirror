--[[
    ARC_NetGraph
    Author: @arcsinan
    Description: Real-time network telemetry HUD displaying Ping, Jitter,
                 Min/Max latency spikes, and Framerate with extensive customization.
]]

ARC_NetGraph = ARC_NetGraph or {}
local ADDON_NAME = "ARC_NetGraph"
local ADDON_VERSION = "1.0.0"
local ADDON_AUTHOR = "@arcsinan"

ARC_NetGraph.name = ADDON_NAME
ARC_NetGraph.version = ADDON_VERSION
ARC_NetGraph.author = ADDON_AUTHOR

local defaults = {
    language = "en",
    enabled = true,
    updateInterval = 500,     -- in milliseconds (200 to 2000)
    layoutMode = "compact",    -- "compact", "detailed", "minimal"
    showPing = true,
    showJitter = true,
    showFPS = true,
    showMinMax = true,
    showServer = false,
    colorCoding = true,
    isLocked = false,
    uiScale = 1.0,
    backgroundOpacity = 0.85,
    windowPosition = { point = TOPRIGHT, relPoint = TOPRIGHT, x = -40, y = 30 },
}

-- Telemetry state
local pingHistory = {}
local maxHistorySize = 20
local lastPing = nil
local currentJitter = 0.0
local minPing = 999
local maxPing = 0

--------------------------------------------------------------------------------
-- Telemetry Calculations
--------------------------------------------------------------------------------

local function ResetHistory()
    pingHistory = {}
    lastPing = nil
    currentJitter = 0.0
    minPing = 999
    maxPing = 0
end

local function UpdateTelemetry()
    local ping = GetLatency() or 0
    local fps = math.floor((GetFramerate() or 0) + 0.5)

    -- RFC 3550 Interarrival Jitter Calculation
    if lastPing ~= nil then
        local diff = math.abs(ping - lastPing)
        currentJitter = currentJitter + (diff - currentJitter) / 16.0
    end
    lastPing = ping

    -- Update sliding buffer
    table.insert(pingHistory, ping)
    if #pingHistory > maxHistorySize then
        table.remove(pingHistory, 1)
    end

    -- Calculate Min and Max from history
    local curMin = 9999
    local curMax = 0
    for _, p in ipairs(pingHistory) do
        if p < curMin then curMin = p end
        if p > curMax then curMax = p end
    end
    minPing = curMin
    maxPing = curMax

    return ping, currentJitter, fps, minPing, maxPing
end

local function GetPingColor(ping)
    if ping < 70 then
        return "|c00FF66" -- Crisp Green
    elseif ping <= 130 then
        return "|cFFD700" -- Yellow / Gold
    else
        return "|cFF4444" -- Red Alert
    end
end

local function GetJitterColor(jitter)
    if jitter < 6.0 then
        return "|c00FF66"
    elseif jitter <= 15.0 then
        return "|cFFD700"
    else
        return "|cFF4444"
    end
end

local function GetFPSColor(fps)
    if fps >= 60 then
        return "|c00FF66"
    elseif fps >= 30 then
        return "|cFFD700"
    else
        return "|cFF4444"
    end
end

--------------------------------------------------------------------------------
-- UI Refresh & Layout Modes
--------------------------------------------------------------------------------

function ARC_NetGraph:RefreshDisplay()
    if not self.savedVars.enabled or not self.hud or self.hud:IsHidden() then return end

    local ping, jitter, fps, curMin, curMax = UpdateTelemetry()
    local mode = self.savedVars.layoutMode or "compact"
    local useColor = self.savedVars.colorCoding

    local pingColor = useColor and GetPingColor(ping) or "|c00D4FF"
    local jitterColor = useColor and GetJitterColor(jitter) or "|c00D4FF"
    local fpsColor = useColor and GetFPSColor(fps) or "|c00D4FF"
    local accentColor = "|c00D4FF"
    local normalColor = "|cFFFFFF"

    local singleLabel = ARC_NetGraph_HUD_SingleLineLabel
    local detailContainer = ARC_NetGraph_HUD_DetailedContainer

    if mode == "compact" then
        -- Compact Single-Line Bar
        detailContainer:SetHidden(true)
        singleLabel:SetHidden(false)

        local parts = {}
        if self.savedVars.showFPS then
            table.insert(parts, string.format("FPS: %s%d|r", fpsColor, fps))
        end
        if self.savedVars.showPing then
            local pingStr = string.format("PING: %s%dms|r", pingColor, ping)
            if self.savedVars.showJitter then
                pingStr = pingStr .. string.format(" (%s±%.1fms|r)", jitterColor, jitter)
            end
            table.insert(parts, pingStr)
        elseif self.savedVars.showJitter then
            table.insert(parts, string.format("JITTER: %s%.1fms|r", jitterColor, jitter))
        end
        if self.savedVars.showMinMax and curMin <= curMax and curMin < 9000 then
            table.insert(parts, string.format("SPIKE: %s%d-%dms|r", normalColor, curMin, curMax))
        end
        if self.savedVars.showServer then
            table.insert(parts, string.format("%s%s|r", accentColor, tostring(GetWorldName())))
        end

        local combined = table.concat(parts, "  |c555555•|r  ")
        singleLabel:SetText(combined)
        singleLabel:SetFont("ZoFontGameMedium")

        -- Auto-size width according to content
        local textWidth = singleLabel:GetTextWidth()
        local width = math.max(160, textWidth + 24)
        self.hud:SetDimensions(width, 30)

    elseif mode == "minimal" then
        -- Ultra-clean minimal badge
        detailContainer:SetHidden(true)
        singleLabel:SetHidden(false)

        local parts = {}
        if self.savedVars.showFPS then
            table.insert(parts, string.format("%s%d|r %sFPS|r", fpsColor, fps, "|cAAAAAA"))
        end
        if self.savedVars.showPing then
            local pStr = string.format("%s%d|r %sms|r", pingColor, ping, "|cAAAAAA")
            if self.savedVars.showJitter then
                pStr = pStr .. string.format(" (%s±%.0f|r)", jitterColor, jitter)
            end
            table.insert(parts, pStr)
        end

        local combined = table.concat(parts, "  ")
        singleLabel:SetText(combined)
        singleLabel:SetFont("ZoFontGame")

        local textWidth = singleLabel:GetTextWidth()
        local width = math.max(110, textWidth + 18)
        self.hud:SetDimensions(width, 24)

    else
        -- Detailed Card Mode
        singleLabel:SetHidden(true)
        detailContainer:SetHidden(false)

        local rowControls = {
            ARC_NetGraph_HUD_DetailedContainer_Row1,
            ARC_NetGraph_HUD_DetailedContainer_Row2,
            ARC_NetGraph_HUD_DetailedContainer_Row3,
        }

        local rows = {}

        if self.savedVars.showFPS or self.savedVars.showServer then
            local r1 = {}
            if self.savedVars.showFPS then
                table.insert(r1, string.format("FPS: %s%d|r", fpsColor, fps))
            end
            if self.savedVars.showServer then
                table.insert(r1, string.format("%s: %s%s|r", GetString(SI_ARC_NG_LBL_SERVER), accentColor, tostring(GetWorldName())))
            end
            table.insert(rows, table.concat(r1, "    "))
        end

        if self.savedVars.showPing or self.savedVars.showJitter then
            local r2 = {}
            if self.savedVars.showPing then
                table.insert(r2, string.format("%s: %s%d ms|r", GetString(SI_ARC_NG_LBL_PING), pingColor, ping))
            end
            if self.savedVars.showJitter then
                table.insert(r2, string.format("%s: %s±%.1f ms|r", GetString(SI_ARC_NG_LBL_JITTER), jitterColor, jitter))
            end
            table.insert(rows, table.concat(r2, "    "))
        end

        if self.savedVars.showMinMax and curMin <= curMax and curMin < 9000 then
            table.insert(rows, string.format("%s: %s%d ms|r  —  %s%d ms|r", GetString(SI_ARC_NG_LBL_SPIKES), normalColor, curMin, normalColor, curMax))
        end

        local maxW = 0
        local curY = 8

        for idx, rowCtrl in ipairs(rowControls) do
            if rows[idx] then
                rowCtrl:SetHidden(false)
                rowCtrl:ClearAnchors()
                rowCtrl:SetAnchor(TOPLEFT, detailContainer, TOPLEFT, 14, curY)
                rowCtrl:SetAnchor(TOPRIGHT, detailContainer, TOPRIGHT, -14, curY)
                rowCtrl:SetText(rows[idx])
                rowCtrl:SetFont("ZoFontGame")

                local textW = rowCtrl:GetTextWidth() or 0
                if textW > maxW then
                    maxW = textW
                end

                curY = curY + 22
            else
                rowCtrl:SetHidden(true)
            end
        end

        local cardWidth = math.max(260, maxW + 28)
        local cardHeight = math.max(30, curY + 6)
        self.hud:SetDimensions(cardWidth, cardHeight)
    end
end

--------------------------------------------------------------------------------
-- Window & Layout Configuration
--------------------------------------------------------------------------------

function ARC_NetGraph:ApplyAppearance()
    if not self.hud then return end

    local scale = self.savedVars.uiScale or 1.0
    self.hud:SetScale(scale)

    local opacity = self.savedVars.backgroundOpacity or 0.85
    ARC_NetGraph_HUD_Backdrop:SetAlpha(opacity)

    -- Hide top accent bar if completely transparent
    ARC_NetGraph_HUD_TopBar:SetHidden(opacity <= 0.05)

    -- Lock / Unlock Mouse Interactivity
    local isLocked = self.savedVars.isLocked
    self.hud:SetMovable(not isLocked)
    self.hud:SetMouseEnabled(not isLocked)

    self:RefreshDisplay()
end

function ARC_NetGraph:StartTicker()
    EVENT_MANAGER:UnregisterForUpdate("ARC_NetGraph_TelemetryTicker")
    if not self.savedVars.enabled then return end

    local interval = math.max(150, tonumber(self.savedVars.updateInterval) or 500)
    EVENT_MANAGER:RegisterForUpdate("ARC_NetGraph_TelemetryTicker", interval, function()
        ARC_NetGraph:RefreshDisplay()
    end)
end

function ARC_NetGraph:StopTicker()
    EVENT_MANAGER:UnregisterForUpdate("ARC_NetGraph_TelemetryTicker")
end

function ARC_NetGraph:ShowHUD()
    if not self.hud then return end
    self.hud:SetHidden(false)
    self:ApplyAppearance()
    self:StartTicker()
end

function ARC_NetGraph:HideHUD()
    if not self.hud then return end
    self.hud:SetHidden(true)
    self:StopTicker()
end

function ARC_NetGraph:ToggleHUD()
    if self.hud and not self.hud:IsHidden() then
        self:HideHUD()
    else
        self:ShowHUD()
    end
end

function ARC_NetGraph:ToggleLock()
    self.savedVars.isLocked = not self.savedVars.isLocked
    self:ApplyAppearance()
    local status = self.savedVars.isLocked and "|c00FF00Locked (Click-Through)|r" or "|cFFD700Unlocked (Draggable)|r"
    d("|c00D4FF[ARC NetGraph]|r Position: " .. status)
end

--------------------------------------------------------------------------------
-- Donation / In-Game Mail to @arcsinan
--------------------------------------------------------------------------------

function ARC_NetGraph.DonateGold(amount)
    local world = GetWorldName()
    if world ~= "" and not string.find(string.lower(world), "eu") then
        local warnFmt = GetString(SI_ARC_NG_CHAT_SERVER_WARN)
        d(string.format(warnFmt, tostring(world)))
    end

    local goldAmount = tonumber(amount) or 0

    SCENE_MANAGER:Show("mailSend")
    zo_callLater(function()
        if ZO_MailSendToField then
            ZO_MailSendToField:SetText("@arcsinan")
        end
        if ZO_MailSendSubjectField then
            ZO_MailSendSubjectField:SetText("ARC NetGraph Donation")
        end
        if ZO_MailSendBodyField then
            local mailBody = GetString(SI_ARC_NG_MAIL_BODY)
            ZO_MailSendBodyField:SetText(mailBody)
            ZO_MailSendBodyField:TakeFocus()
        end
        if goldAmount > 0 and QueueMoneyAttachment then
            QueueMoneyAttachment(goldAmount)
            if ZO_MailSendSendCurrency and ZO_MailSendSendCurrency.OnBeginInput then
                ZO_MailSendSendCurrency:OnBeginInput()
            end
        end
    end, 250)
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

local function OnAddOnLoaded(event, addonName)
    if addonName ~= ADDON_NAME then return end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    -- SavedVariables initialization (Account-wide with Megaserver isolation)
    ARC_NetGraph.savedVars = ZO_SavedVars:NewAccountWide(
        "ARC_NetGraph_SavedVariables",
        1,
        GetWorldName(),
        defaults,
        nil,
        nil
    )

    -- Apply Turkish if configured in SavedVariables (English remains default otherwise)
    if ARC_NetGraph.savedVars.language == "tr" and ARC_NetGraph.ApplyTurkishStrings then
        ARC_NetGraph.ApplyTurkishStrings()
    end

    -- Hook TopLevelControl
    ARC_NetGraph.hud = ARC_NetGraph_HUD
    if ARC_NetGraph.hud then
        -- Restore position if saved
        local pos = ARC_NetGraph.savedVars.windowPosition
        if pos and pos.point and pos.x and pos.y then
            ARC_NetGraph.hud:ClearAnchors()
            ARC_NetGraph.hud:SetAnchor(pos.point, GuiRoot, pos.relPoint or pos.point, pos.x, pos.y)
        end

        ARC_NetGraph.hud:SetHandler("OnMoveStop", function()
            local isValid, point, relTo, relPoint, x, y = ARC_NetGraph.hud:GetAnchor(0)
            if isValid then
                ARC_NetGraph.savedVars.windowPosition = { point = point, relPoint = relPoint, x = x, y = y }
            end
        end)
    end

    -- Register Slash Commands
    SLASH_COMMANDS["/netgraph"] = function() ARC_NetGraph:ToggleHUD() end
    SLASH_COMMANDS["/ang"] = function() ARC_NetGraph:ToggleHUD() end
    SLASH_COMMANDS["/anglock"] = function() ARC_NetGraph:ToggleLock() end
    SLASH_COMMANDS["/angsettings"] = function()
        if LibAddonMenu2 and ARC_NetGraph.settingsPanel then
            LibAddonMenu2:OpenToPanel(ARC_NetGraph.settingsPanel)
        else
            d("|c00D4FF[ARC NetGraph]|r " .. GetString(SI_ARC_NG_TITLE))
            d("Commands: /netgraph (toggle), /anglock (toggle drag lock)")
        end
    end
    SLASH_COMMANDS["/arcdonate"] = function() ARC_NetGraph.DonateGold(0) end

    -- Initialize Settings Panel
    if ARC_NetGraph.InitializeSettings then
        ARC_NetGraph:InitializeSettings()
    end

    -- Initial Activation
    if ARC_NetGraph.savedVars.enabled then
        ARC_NetGraph:ShowHUD()
    else
        ARC_NetGraph:HideHUD()
    end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
