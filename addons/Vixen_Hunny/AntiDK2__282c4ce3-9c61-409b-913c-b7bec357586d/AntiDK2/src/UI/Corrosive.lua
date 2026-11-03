local ADK = AntiDK2
local M   = {}
ADK.UI.Corrosive = M

local PANEL_W   = 480
local PANEL_H   = 130
local MAX_MULT  = 4      -- highest "xN" multiplier shown
local WIN       = ADK.WINDOWS.corrosive

local panel, titleLbl, statusLbl, timerLbl, stackLbl
local fadeHandle = nil

local function SavePos()
    local sv = ADK.savedVars
    sv[WIN.x] = panel:GetLeft() + panel:GetWidth()  / 2 - GuiRoot:GetWidth()  / 2
    sv[WIN.y] = panel:GetTop()  + panel:GetHeight() / 2 - GuiRoot:GetHeight() / 2
end

local function CurrentFont()
    return ADK.PresetFont(WIN.fontGroup, ADK.Get(WIN.font))
end

function M.Init()
    local c = ADK.COLORS

    panel = WINDOW_MANAGER:CreateTopLevelWindow(WIN.control)
    panel:SetDimensions(PANEL_W, PANEL_H)
    panel:SetAnchor(WIN.anchor, GuiRoot, WIN.anchor, ADK.Get(WIN.x), ADK.Get(WIN.y))
    panel:SetMovable(true)
    panel:SetMouseEnabled(true)
    panel:SetClampedToScreen(true)
    panel:SetHidden(true)
    panel:SetScale(ADK.Get(WIN.scale))
    panel:SetHandler("OnMoveStop", SavePos)

    -- No backdrop - pure text

    -- Title: "CORROSIVE ARMOR"
    titleLbl = ADK.UI.MakeLabel("AntiDK2CorrosiveTitle", panel, CurrentFont(), c.CORROSIVE)
    titleLbl:SetText("CORROSIVE ARMOR")
    titleLbl:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    titleLbl:SetAnchor(TOP, panel, TOP, 0, 0)

    -- Status: "IN RANGE" / "CRITICAL HIT"
    statusLbl = ADK.UI.MakeLabel("AntiDK2CorrosiveStatus", panel, ADK.Font(26), c.WARN)
    statusLbl:SetText("IN RANGE")
    statusLbl:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    statusLbl:SetAnchor(TOP, titleLbl, BOTTOM, 0, 2)

    -- Bottom-left: elapsed timer
    timerLbl = ADK.UI.MakeLabel("AntiDK2CorrosiveTimer", panel, ADK.Font(22), c.WHITE)
    timerLbl:SetText("0:00")
    timerLbl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    timerLbl:SetAnchor(BOTTOMLEFT, panel, BOTTOMLEFT, 0, 0)

    -- Bottom-right: x2 / x3 multiplier
    stackLbl = ADK.UI.MakeLabel("AntiDK2CorrosiveStack", panel, CurrentFont(), c.PINK)
    stackLbl:SetText("")
    stackLbl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    stackLbl:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, 0, 0)
end

--- Apply a font string to the labels that follow the user's font preset.
function M.ApplyFont(font)
    if titleLbl then titleLbl:SetFont(font) end
    if stackLbl then stackLbl:SetFont(font) end
end

function M.Show(hitCount, isCrit)
    fadeHandle = ADK.CancelTimer(fadeHandle)

    local c = ADK.COLORS
    if hitCount and hitCount > 0 then
        stackLbl:SetText(ADK.Colorize(c.PINK, "x" .. math.min(hitCount, MAX_MULT)))
    else
        stackLbl:SetText("")
    end

    if isCrit then
        statusLbl:SetText(ADK.Colorize(c.DANGER, "CRITICAL HIT"))
        statusLbl:SetColor(ADK.RGB(c.DANGER))
    else
        statusLbl:SetText("IN RANGE")
        statusLbl:SetColor(ADK.RGB(c.WARN))
    end

    panel:SetHidden(false)

    fadeHandle = zo_callLater(function()
        fadeHandle = nil
        M.Hide()
    end, math.max(ADK.Get("corrosiveFadeDelay") * 1000, 1000))
end

function M.UpdateTimer(formatted)
    if timerLbl then timerLbl:SetText(formatted) end
end

function M.Hide()
    panel:SetHidden(true)
    if timerLbl then timerLbl:SetText("0:00") end
    if stackLbl then stackLbl:SetText("") end
end

function M.GetPanel() return panel end
