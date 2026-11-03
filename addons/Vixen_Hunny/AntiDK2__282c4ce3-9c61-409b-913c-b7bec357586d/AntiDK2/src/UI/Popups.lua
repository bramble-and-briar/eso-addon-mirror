local ADK = AntiDK2
local M   = {}
ADK.UI.Popups = M

-- ── Shared control helpers ───────────────────────────────────────────────────

-- Kept as an alias for UI/Wings.lua and any external callers; new code uses ADK.Font.
ADK.UI.BoldFont = ADK.Font

--- Create a label. `color` may be an ADK.COLORS entry or separate r, g, b.
function ADK.UI.MakeLabel(name, parent, font, color, g, b)
    local lbl = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    lbl:SetFont(font or ADK.Font(16))
    if type(color) == "table" then
        lbl:SetColor(ADK.RGB(color))
    else
        lbl:SetColor(color or 1, g or 1, b or 1, 1)
    end
    return lbl
end

--- Create a 0-100 status bar. `color` may be an ADK.COLORS entry or separate r, g, b.
function ADK.UI.MakeStatusBar(name, parent, width, height, color, g, b)
    local bar = WINDOW_MANAGER:CreateControl(name, parent, CT_STATUSBAR)
    bar:SetDimensions(width or 200, height or 20)
    if type(color) == "table" then
        bar:SetColor(ADK.RGB(color))
    else
        bar:SetColor(color or 1, g or 1, b or 1, 1)
    end
    bar:SetMinMax(0, 100)
    bar:SetValue(0)
    bar:SetTexture("/esoui/art/miscellaneous/progressbar_genericfill.dds")
    return bar
end

-- Kept for backwards compat but no longer used
function ADK.UI.MakeBackdrop(name, parent)
    local bg = WINDOW_MANAGER:CreateControl(name, parent, CT_BACKDROP)
    bg:SetAnchorFill(parent)
    bg:SetCenterColor(0, 0, 0, 0)
    bg:SetEdgeTexture("", 1, 1, 0)
    return bg
end

-- ── Panel visibility: show main panel only when a DK enemy is active ─────────
ADK.UI.panelFlags = { wings = false, molten = false, powerLash = false }

function ADK.UI.SetPanelFlag(key, hasData)
    ADK.UI.panelFlags[key] = hasData
    if not ADK.UI.MainPanel then return end
    local any = false
    for _, v in pairs(ADK.UI.panelFlags) do
        if v then any = true; break end
    end
    ADK.UI.MainPanel:SetHidden(not any)
end

-- ── Main panel: transparent container, GCD-Tracker style ─────────────────────
local PANEL_W = 280
local PANEL_H = 230
local WIN     = ADK.WINDOWS.main

local function SaveMainPos(win)
    ADK.savedVars[WIN.x] = win:GetLeft()
    ADK.savedVars[WIN.y] = win:GetTop()
end

function M.Init()
    local c = ADK.COLORS

    local win = WINDOW_MANAGER:CreateTopLevelWindow(WIN.control)
    win:SetDimensions(PANEL_W, PANEL_H)
    win:SetAnchor(WIN.anchor, GuiRoot, WIN.anchor, ADK.Get(WIN.x), ADK.Get(WIN.y))
    win:SetMovable(true)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    win:SetHandler("OnMoveStop", SaveMainPos)
    win:SetScale(ADK.Get(WIN.scale))
    win:SetHidden(false)  -- SetPanelFlag hides it until a tracked DK enemy is detected

    -- Header label only, no background
    local hdr = ADK.UI.MakeLabel("AntiDK2MainHdr", win, ADK.Font(14), c.LIGHT_BLUE)
    hdr:SetText(ADK.Colorize(c.LIGHT_BLUE, "Anti DK") .. " " .. ADK.Colorize(c.PINK, "2.0"))
    hdr:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    hdr:SetAnchor(TOPLEFT, win, TOPLEFT, 0, 2)

    ADK.UI.MainPanel = win
end
