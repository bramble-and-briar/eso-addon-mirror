-- ESO Adventurer Suite
-- Copyright (c) 2026 HoZayyBadazz. All Rights Reserved.
-- Lightweight Suite-owned FPS / latency HUD replacement.

local EPC = ESOProgressionCoach
EPC.PerformanceOverlay = EPC.PerformanceOverlay or {}
local P = EPC.PerformanceOverlay
local wm = WINDOW_MANAGER

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a, b, c = pcall(fn, ...)
    if not ok then return fallback end
    return a, b, c
end

local function setColor(label, r, g, b, a)
    if not label or type(label.SetColor) ~= "function" then return end
    label:SetColor(tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1)
end

local function actualNativePerformanceControls()
    local controls = {}
    local seen = {}
    local function add(control)
        if control and not seen[control] then
            seen[control] = true
            controls[#controls + 1] = control
        end
    end
    add(_G and _G.ZO_PerformanceMeters or nil)
    add(_G and _G.ZO_PerformanceMetersFramerateMeter or nil)
    add(_G and _G.ZO_PerformanceMetersLatencyMeter or nil)
    return controls
end

function P:Anchor()
    if not self.frame then return end
    self.frame:ClearAnchors()
    local left = tonumber(EPC.saved and EPC.saved.performanceOverlayLeft) or -1
    local top = tonumber(EPC.saved and EPC.saved.performanceOverlayTop) or -1
    local rootW = GuiRoot and tonumber(GuiRoot:GetWidth()) or 0
    local rootH = GuiRoot and tonumber(GuiRoot:GetHeight()) or 0
    local valid = left >= 0 and top >= 0
        and (rootW <= 0 or left <= rootW - 80)
        and (rootH <= 0 or top <= rootH - 28)
    if valid then
        self.frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    else
        if EPC.saved then
            EPC.saved.performanceOverlayLeft = -1
            EPC.saved.performanceOverlayTop = -1
        end
        self.frame:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -38, 132)
    end
end

function P:Create()
    if self.frame or not wm or not GuiRoot then return end
    local frame = wm:CreateTopLevelWindow("EAS_PerformanceOverlay029124")
    frame:SetDimensions(270, 34)
    frame:SetClampedToScreen(true)
    frame:SetMouseEnabled(false)
    frame:SetMovable(false)
    frame:SetHidden(true)
    if frame.SetDrawTier and DT_HIGH then frame:SetDrawTier(DT_HIGH) end
    if frame.SetDrawLayer and DL_OVERLAY then frame:SetDrawLayer(DL_OVERLAY) end
    if frame.SetDrawLevel then frame:SetDrawLevel(930) end

    local bg = wm:CreateControl("EAS_PerformanceOverlay029124_BG", frame, CT_BACKDROP)
    bg:SetAnchorFill(frame)
    bg:SetCenterColor(0.012, 0.015, 0.022, 0.74)
    bg:SetEdgeColor(0.42, 0.47, 0.56, 0.72)
    bg:SetEdgeTexture(nil, 1, 1, 1)

    local fpsTitle = wm:CreateControl("EAS_PerformanceOverlay029124_FPSTitle", frame, CT_LABEL)
    fpsTitle:SetAnchor(LEFT, frame, LEFT, 10, 0)
    fpsTitle:SetDimensions(42, 30)
    fpsTitle:SetFont("ZoFontGameSmall")
    fpsTitle:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    setColor(fpsTitle, 0.70, 0.74, 0.80, 1)
    fpsTitle:SetText("FPS")

    local fpsValue = wm:CreateControl("EAS_PerformanceOverlay029124_FPSValue", frame, CT_LABEL)
    fpsValue:SetAnchor(LEFT, fpsTitle, RIGHT, 0, 0)
    fpsValue:SetDimensions(62, 30)
    fpsValue:SetFont("$(BOLD_FONT)|18|soft-shadow-thick")
    fpsValue:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    fpsValue:SetText("--")

    local divider = wm:CreateControl("EAS_PerformanceOverlay029124_Divider", frame, CT_BACKDROP)
    divider:SetAnchor(CENTER, frame, CENTER, -3, 0)
    divider:SetDimensions(1, 20)
    divider:SetCenterColor(0.36, 0.40, 0.48, 0.50)
    divider:SetEdgeColor(0, 0, 0, 0)

    local pingTitle = wm:CreateControl("EAS_PerformanceOverlay029124_PingTitle", frame, CT_LABEL)
    pingTitle:SetAnchor(LEFT, divider, RIGHT, 12, 0)
    pingTitle:SetDimensions(48, 30)
    pingTitle:SetFont("ZoFontGameSmall")
    pingTitle:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    setColor(pingTitle, 0.70, 0.74, 0.80, 1)
    pingTitle:SetText("PING")

    local pingValue = wm:CreateControl("EAS_PerformanceOverlay029124_PingValue", frame, CT_LABEL)
    pingValue:SetAnchor(LEFT, pingTitle, RIGHT, 0, 0)
    pingValue:SetDimensions(72, 30)
    pingValue:SetFont("$(BOLD_FONT)|18|soft-shadow-thick")
    pingValue:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    pingValue:SetText("-- ms")

    frame:SetHandler("OnMoveStop", function(control)
        if EPC.saved then
            EPC.saved.performanceOverlayLeft = control:GetLeft()
            EPC.saved.performanceOverlayTop = control:GetTop()
        end
    end)

    self.frame = frame
    self.hudFragment029125 = EPC.CreateHudFadeFragment and EPC:CreateHudFadeFragment(frame) or nil
    self.bg = bg
    self.fpsTitle = fpsTitle
    self.fpsValue = fpsValue
    self.pingTitle = pingTitle
    self.pingValue = pingValue
    self.divider = divider
    self:Anchor()
end

function P:SuppressNative(shouldSuppress)
    shouldSuppress = shouldSuppress == true
    local controls = actualNativePerformanceControls()

    if shouldSuppress then
        self.nativeHiddenState029124 = self.nativeHiddenState029124 or {}
        for i = 1, #controls do
            local control = controls[i]
            if self.nativeHiddenState029124[control] == nil then
                local hidden = true
                if type(control.IsHidden) == "function" then
                    hidden = safe(control.IsHidden, true, control) == true
                elseif type(control.IsControlHidden) == "function" then
                    hidden = safe(control.IsControlHidden, true, control) == true
                end
                self.nativeHiddenState029124[control] = hidden
            end
            if type(control.SetHidden) == "function" then pcall(control.SetHidden, control, true) end
        end
        self.nativeSuppressed029124 = true
    elseif self.nativeSuppressed029124 then
        for control, wasHidden in pairs(self.nativeHiddenState029124 or {}) do
            if control and type(control.SetHidden) == "function" then
                pcall(control.SetHidden, control, wasHidden == true)
            end
        end
        self.nativeHiddenState029124 = nil
        self.nativeSuppressed029124 = false
    end
end

function P:ShouldShow()
    if not EPC.saved or EPC.saved.enabled == false or EPC.saved.showPerformanceOverlay == false then return false end
    if self.layoutMode then return true end
    return not (EPC.IsGameplayHudSuppressed and EPC:IsGameplayHudSuppressed() == true)
end

function P:ApplyHudReason(showRequested)
    showRequested = showRequested == true
    if self.hudFragment029125 and type(self.hudFragment029125.SetHiddenForReason) == "function" then
        pcall(self.hudFragment029125.SetHiddenForReason, self.hudFragment029125, "EAS_PERFORMANCE_DISABLED", not showRequested)
    elseif self.frame then
        self.frame:SetHidden(not showRequested)
    end
end

function P:UpdateValues()
    if not self.fpsValue or not self.pingValue then return end
    local fps = tonumber(safe(GetFramerate, 0)) or 0
    local ping = tonumber(safe(GetLatency, 0)) or 0
    if fps < 0 then fps = 0 end
    if ping < 0 then ping = 0 end
    fps = math.floor(fps + 0.5)
    ping = math.floor(ping + 0.5)

    self.fpsValue:SetText(tostring(fps))
    self.pingValue:SetText(tostring(ping) .. " ms")

    if fps >= 60 then setColor(self.fpsValue, 0.48, 0.90, 0.58, 1)
    elseif fps >= 40 then setColor(self.fpsValue, 0.94, 0.82, 0.44, 1)
    else setColor(self.fpsValue, 1.00, 0.43, 0.38, 1) end

    if ping <= 100 then setColor(self.pingValue, 0.48, 0.90, 0.58, 1)
    elseif ping <= 180 then setColor(self.pingValue, 0.94, 0.82, 0.44, 1)
    else setColor(self.pingValue, 1.00, 0.43, 0.38, 1) end
end

function P:Refresh(forceValues)
    if not self.frame or not EPC.saved then return end
    local show = self:ShouldShow()
    self:ApplyHudReason(show)
    self.frame:SetScale(tonumber(EPC.saved.performanceOverlayScale) or 1.0)

    -- Only hide ESO's stock meter after our replacement control exists and the
    -- feature is enabled. This prevents a failed replacement from leaving the
    -- player with no performance display at all.
    local enabled = EPC.saved.showPerformanceOverlay ~= false and self.frame ~= nil
    self:SuppressNative(enabled and EPC.saved.suppressNativePerformanceMeters ~= false)
    if show and forceValues == true then self:UpdateValues() end
end

function P:SetLayoutMode(active)
    self.layoutMode = active == true
    if not self.frame then return end
    self.frame:SetMouseEnabled(self.layoutMode)
    self.frame:SetMovable(self.layoutMode)
    self:Refresh(true)
    if self.layoutMode then
        pcall(function()
            if self.frame.SetTopLevel then self.frame:SetTopLevel(true) end
            if self.frame.SetDrawTier and DT_HIGH then self.frame:SetDrawTier(DT_HIGH) end
            if self.frame.SetDrawLayer and DL_OVERLAY then self.frame:SetDrawLayer(DL_OVERLAY) end
            if self.frame.SetDrawLevel then self.frame:SetDrawLevel(940) end
            if self.frame.BringWindowToTop then self.frame:BringWindowToTop() end
        end)
    end
end

function P:ResetPosition()
    if EPC.saved then
        EPC.saved.performanceOverlayLeft = -1
        EPC.saved.performanceOverlayTop = -1
    end
    self:Anchor()
end

function P:Initialize()
    self.layoutMode = false
    self:Create()
    local prefix = (EPC.name or "ESOAdventurerSuite") .. "_PerformanceOverlay"

    if EPC.Runtime then EPC.Runtime:UnregisterUpdate("PerformanceOverlay","Pulse") end
    EPC.Runtime:RegisterUpdate("PerformanceOverlay","Pulse",500,function()
        if not P.frame or not EPC.saved then return end
        local enabled = EPC.saved.showPerformanceOverlay ~= false
        P:SuppressNative(enabled and EPC.saved.suppressNativePerformanceMeters ~= false)
        local show = P:ShouldShow()
        P:ApplyHudReason(show)
        if enabled then P:UpdateValues() end
    end)

    if EVENT_PLAYER_ACTIVATED then
        EPC.Runtime:RegisterEvent("PerformanceOverlay","Activated",EVENT_PLAYER_ACTIVATED,function()
            P:Refresh(true)
        end)
    end

    self:Refresh(true)
end
