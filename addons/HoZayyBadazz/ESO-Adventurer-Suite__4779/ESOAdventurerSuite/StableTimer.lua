-- ESO Adventurer Suite
-- Copyright (c) 2026 HoZayyBadazz. All Rights Reserved.
-- Proprietary source. Unauthorized redistribution, republication, rebranding,
-- or public distribution of modified/derivative versions is prohibited.
-- Private personal-use modifications are permitted. See LICENSE.txt.

local EPC = ESOProgressionCoach
EPC.StableTimer = EPC.StableTimer or {}
local S = EPC.StableTimer
local wm = WINDOW_MANAGER

local function num(v, fallback) return tonumber(v) or tonumber(fallback) or 0 end
local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a,b,c,d,e,f = pcall(fn, ...)
    if not ok then return fallback end
    return a,b,c,d,e,f
end

local function setHiddenIfChanged(control, hidden)
    if not control or type(control.IsHidden) ~= "function" or type(control.SetHidden) ~= "function" then return end
    local ok, current = pcall(control.IsHidden, control)
    if not ok or current ~= hidden then pcall(control.SetHidden, control, hidden) end
end

local function setTextIfChanged(control, text, cacheOwner, cacheKey)
    if not control then return end
    text = tostring(text or "")
    if cacheOwner[cacheKey] ~= text then
        cacheOwner[cacheKey] = text
        control:SetText(text)
    end
end

function S:Create()
    local frame = wm:CreateTopLevelWindow("EPC_StableTrainingTimer")
    frame:SetDimensions(190, 34)
    frame:SetClampedToScreen(true)
    frame:SetMouseEnabled(false)
    frame:SetMovable(false)

    local left = EPC.saved and num(EPC.saved.stableTimerLeft, -1) or -1
    local top = EPC.saved and num(EPC.saved.stableTimerTop, -1) or -1
    if left >= 0 and top >= 0 then frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    else frame:SetAnchor(TOP, GuiRoot, TOP, 0, 18) end

    local bg = wm:CreateControl("EPC_StableTrainingTimer_BG", frame, CT_BACKDROP)
    bg:SetAnchorFill(frame)
    bg:SetCenterColor(0.020, 0.026, 0.036, 0.78)
    bg:SetEdgeColor(0.20, 0.23, 0.30, 0.92)
    bg:SetEdgeTexture(nil, 1, 1, 1)

    local title = wm:CreateControl("EPC_StableTrainingTimer_Title", frame, CT_LABEL)
    title:SetFont("ZoFontGameBold")
    title:SetColor(0.91, 0.70, 0.28, 1)
    title:SetAnchor(LEFT, frame, LEFT, 14, 0)
    title:SetDimensions(70, 34)
    title:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    title:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    title:SetText("STABLE")

    -- v0.29.564: compact fixed-position timer.  Each component still owns its
    -- own anchor so proportional-font reflow cannot move the hour, but the
    -- fields are packed tightly enough to read as one normal H:MM:SS string.
    local timeRoot = wm:CreateControl("EPC_StableTrainingTimer_TimeRoot", frame, CT_CONTROL)
    timeRoot:SetAnchor(RIGHT, frame, RIGHT, -12, 0)
    timeRoot:SetDimensions(68, 34)

    local hour = wm:CreateControl("EPC_StableTrainingTimer_Hour", timeRoot, CT_LABEL)
    hour:SetFont("ZoFontGameBold")
    hour:SetDimensions(16, 34)
    hour:SetAnchor(LEFT, timeRoot, LEFT, 0, 0)
    hour:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    hour:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    local colon1 = wm:CreateControl("EPC_StableTrainingTimer_Colon1", timeRoot, CT_LABEL)
    colon1:SetFont("ZoFontGameBold")
    colon1:SetDimensions(5, 34)
    colon1:SetAnchor(LEFT, hour, RIGHT, 0, 0)
    colon1:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    colon1:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    colon1:SetText(":")

    local minute = wm:CreateControl("EPC_StableTrainingTimer_Minute", timeRoot, CT_LABEL)
    minute:SetFont("ZoFontGameBold")
    minute:SetDimensions(20, 34)
    minute:SetAnchor(LEFT, colon1, RIGHT, 0, 0)
    minute:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    minute:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    local colon2 = wm:CreateControl("EPC_StableTrainingTimer_Colon2", timeRoot, CT_LABEL)
    colon2:SetFont("ZoFontGameBold")
    colon2:SetDimensions(5, 34)
    colon2:SetAnchor(LEFT, minute, RIGHT, 0, 0)
    colon2:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    colon2:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    colon2:SetText(":")

    local second = wm:CreateControl("EPC_StableTrainingTimer_Second", timeRoot, CT_LABEL)
    second:SetFont("ZoFontGameBold")
    second:SetDimensions(20, 34)
    second:SetAnchor(LEFT, colon2, RIGHT, 0, 0)
    second:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    second:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    local status = wm:CreateControl("EPC_StableTrainingTimer_Status", timeRoot, CT_LABEL)
    status:SetFont("ZoFontGameBold")
    status:SetAnchorFill(timeRoot)
    status:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    status:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    status:SetHidden(true)

    frame:SetHandler("OnMoveStop", function(control)
        if EPC.saved then
            EPC.saved.stableTimerLeft = control:GetLeft()
            EPC.saved.stableTimerTop = control:GetTop()
        end
    end)

    self.frame, self.bg, self.title = frame, bg, title
    self.timeRoot, self.hour, self.colon1, self.minute, self.colon2, self.second, self.status = timeRoot, hour, colon1, minute, colon2, second, status
    self.lastVisible029560 = nil
    self.lastColorKey029560 = nil
    self.lastTimeMode029563 = nil
end

function S:IsMaxed()
    if type(GetRidingStats) ~= "function" then return false end
    local inv, maxInv, stam, maxStam, speed, maxSpeed = safe(GetRidingStats, 0)
    return num(maxInv,0) > 0 and num(inv,0) >= num(maxInv,0)
        and num(stam,0) >= num(maxStam,0)
        and num(speed,0) >= num(maxSpeed,0)
end

local function applyColor(self, colorKey)
    if colorKey == self.lastColorKey029560 then return end
    self.lastColorKey029560 = colorKey
    local r, g, b
    if colorKey == "READY" then r, g, b = 0.25, 0.72, 0.40
    else r, g, b = 0.91, 0.70, 0.28 end
    for _, control in ipairs({self.title, self.hour, self.colon1, self.minute, self.colon2, self.second, self.status}) do
        if control then control:SetColor(r, g, b, 1) end
    end
end

local function setCountdownMode(self, active)
    local mode = active and "COUNTDOWN" or "STATUS"
    if self.lastTimeMode029563 == mode then return end
    self.lastTimeMode029563 = mode
    setHiddenIfChanged(self.status, active)
    for _, control in ipairs({self.hour, self.colon1, self.minute, self.colon2, self.second}) do
        setHiddenIfChanged(control, not active)
    end
end

local function applyStatus(self, text, colorKey)
    setCountdownMode(self, false)
    setTextIfChanged(self.status, text, self, "lastStatusText029563")
    applyColor(self, colorKey)
end

local function applyCountdown(self, ms)
    setCountdownMode(self, true)
    ms = math.max(0, num(ms, 0))
    local totalSeconds = math.ceil(ms / 1000)
    local h = math.floor(totalSeconds / 3600)
    local m = math.floor((totalSeconds % 3600) / 60)
    local s = totalSeconds % 60

    if h > 0 then
        setTextIfChanged(self.hour, tostring(h), self, "lastHour029563")
        setHiddenIfChanged(self.hour, false)
        setHiddenIfChanged(self.colon1, false)
    else
        setTextIfChanged(self.hour, "", self, "lastHour029563")
        setHiddenIfChanged(self.hour, true)
        setHiddenIfChanged(self.colon1, true)
    end
    setTextIfChanged(self.minute, string.format("%02d", m), self, "lastMinute029563")
    setTextIfChanged(self.second, string.format("%02d", s), self, "lastSecond029563")
    applyColor(self, "WAIT")
end

function S:Refresh()
    if not self.frame or not EPC.saved then return end
    local show = EPC.saved.showStableTimer ~= false
    if self.layoutMode == true then show = true
    elseif EPC.OverlayModeAllows then show = show and EPC:OverlayModeAllows("stableTimerVisibility") end
    if show and self.layoutMode ~= true and EPC.IsGameplayHudSuppressed and EPC:IsGameplayHudSuppressed() then show = false end

    if self.lastVisible029560 ~= show then
        self.lastVisible029560 = show
        setHiddenIfChanged(self.frame, not show)
    end
    if not show then return end

    if type(GetTimeUntilCanBeTrained) ~= "function" then
        applyStatus(self, "--", "WAIT")
        return
    end

    if self:IsMaxed() then
        applyStatus(self, "MAX", "READY")
        return
    end

    local timeMs = num(safe(GetTimeUntilCanBeTrained, 0), 0)
    if timeMs <= 0 then
        applyStatus(self, "0", "READY")
    else
        applyCountdown(self, timeMs)
    end
end

function S:SetLayoutMode(active)
    self.layoutMode = active == true
    if not self.frame then return end
    self.frame:SetMouseEnabled(self.layoutMode)
    self.frame:SetMovable(self.layoutMode)
    self.lastVisible029560 = nil
    self:Refresh()
end

function S:ResetPosition()
    if not self.frame or not EPC.saved then return end
    EPC.saved.stableTimerLeft = -1
    EPC.saved.stableTimerTop = -1
    self.frame:ClearAnchors()
    self.frame:SetAnchor(TOP, GuiRoot, TOP, 0, 18)
end

function S:Initialize()
    self.layoutMode = false
    self:Create()
    self:Refresh()
    EPC.Runtime:RegisterUpdate("StableTimer","Pulse",1000,function()
        if not EPC.saved then return end
        if EPC.saved.showStableTimer == false and self.layoutMode ~= true then return end
        self:Refresh()
    end)
end
