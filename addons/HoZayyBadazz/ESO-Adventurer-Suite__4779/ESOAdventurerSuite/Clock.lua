-- ESO Adventurer Suite
-- Copyright (c) 2026 HoZayyBadazz. All Rights Reserved.
-- Proprietary source. Unauthorized redistribution, republication, rebranding,
-- or public distribution of modified/derivative versions is prohibited.
-- Private personal-use modifications are permitted. See LICENSE.txt.

local EPC = ESOProgressionCoach
EPC.Clock = EPC.Clock or {}
local C = EPC.Clock
local wm = WINDOW_MANAGER

local function num(v, fallback) return tonumber(v) or tonumber(fallback) or 0 end

local function formatClock12()
    local seconds = nil
    if type(GetSecondsSinceMidnight) == "function" then
        local ok, value = pcall(GetSecondsSinceMidnight)
        if ok then seconds = tonumber(value) end
    end

    local h, m
    if seconds then
        seconds = math.max(0, seconds)
        h = math.floor(seconds / 3600) % 24
        m = math.floor(seconds / 60) % 60
    else
        local raw = type(GetTimeString) == "function" and GetTimeString() or ""
        local hs, ms = string.match(raw or "", "^(%d+):(%d+)")
        h, m = tonumber(hs), tonumber(ms)
    end

    if h == nil or m == nil then return "--:--" end
    local suffix = h >= 12 and "PM" or "AM"
    local h12 = h % 12
    if h12 == 0 then h12 = 12 end
    return string.format("%d:%02d %s", h12, m, suffix)
end

local function setHiddenIfChanged(control, hidden)
    if not control or type(control.IsHidden) ~= "function" or type(control.SetHidden) ~= "function" then return end
    local ok, current = pcall(control.IsHidden, control)
    if not ok or current ~= hidden then pcall(control.SetHidden, control, hidden) end
end

function C:Create()
    local frame = wm:CreateTopLevelWindow("EAS_Clock")
    frame:SetDimensions(128, 34)
    frame:SetClampedToScreen(true)
    frame:SetMouseEnabled(false)
    frame:SetMovable(false)

    local left = EPC.saved and num(EPC.saved.clockLeft, -1) or -1
    local top = EPC.saved and num(EPC.saved.clockTop, -1) or -1
    if left >= 0 and top >= 0 then
        frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    else
        frame:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -28, 18)
    end

    local bg = wm:CreateControl("EAS_Clock_BG", frame, CT_BACKDROP)
    bg:SetAnchorFill(frame)
    bg:SetCenterColor(0.020, 0.026, 0.036, 0.78)
    bg:SetEdgeColor(0.20, 0.23, 0.30, 0.92)
    bg:SetEdgeTexture(nil, 1, 1, 1)

    local label = wm:CreateControl("EAS_Clock_Label", frame, CT_LABEL)
    label:SetFont("ZoFontGameBold")
    label:SetColor(0.91, 0.70, 0.28, 1)
    label:SetAnchorFill(frame)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    local hint = wm:CreateControl("EAS_Clock_MoveHint", frame, CT_LABEL)
    hint:SetFont("ZoFontGameSmall")
    hint:SetColor(0.91, 0.70, 0.28, 1)
    hint:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -3, 1)
    hint:SetDimensions(40, 14)
    hint:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    hint:SetText("DRAG")
    hint:SetHidden(true)

    frame:SetHandler("OnMoveStop", function(control)
        if EPC.saved then
            EPC.saved.clockLeft = control:GetLeft()
            EPC.saved.clockTop = control:GetTop()
        end
    end)

    self.frame, self.bg, self.label, self.hint = frame, bg, label, hint
    self.lastVisible029560 = nil
    self.lastText029560 = nil
end

function C:Refresh()
    if not self.frame or not EPC.saved then return end
    local show = EPC.saved.showClock ~= false
    if self.layoutMode == true then show = true
    elseif EPC.OverlayModeAllows then show = show and EPC:OverlayModeAllows("clockVisibility") end
    if show and self.layoutMode ~= true and EPC.IsGameplayHudSuppressed and EPC:IsGameplayHudSuppressed() then
        show = false
    end

    -- v0.29.560: never re-toggle visibility every timer tick. Repeated SetHidden
    -- calls on a top-level window can visibly blink when scene/HUD reconciliation
    -- lands in the same frame.
    if self.lastVisible029560 ~= show then
        self.lastVisible029560 = show
        setHiddenIfChanged(self.frame, not show)
    end
    if not show then return end

    local text = formatClock12()
    if text ~= self.lastText029560 then
        self.lastText029560 = text
        self.label:SetText(text)
    end
end

function C:SetLayoutMode(active)
    self.layoutMode = active == true
    if not self.frame then return end
    self.frame:SetMouseEnabled(self.layoutMode)
    self.frame:SetMovable(self.layoutMode)
    if self.hint then setHiddenIfChanged(self.hint, not self.layoutMode) end
    self.lastVisible029560 = nil
    self:Refresh()
end

function C:ResetPosition()
    if not self.frame or not EPC.saved then return end
    EPC.saved.clockLeft = -1
    EPC.saved.clockTop = -1
    self.frame:ClearAnchors()
    self.frame:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -28, 18)
end

function C:Initialize()
    self.layoutMode = false
    self:Create()
    self:Refresh()
    EPC.Runtime:RegisterUpdate("Clock","Pulse",1000,function()
        self:Refresh()
    end)
end
