-- Questbound_Launcher.lua : the rounded "QUESTBOUND" button, same behavior as Set
-- Hunter's: logo + name + « / » arrow. Click = show / hide the quest tracker,
-- drag = move, « / » = only the logo / the name again, right-click = menu,
-- small "x" on the corner = hide the button (/qb brings it back).
-- Also W.Logo(): the logo (dark disc + gold ring and quest marker, sketch 2) that
-- the tracker header uses too.
-- The button is a movable window, which swallows its children's clicks: the arrow
-- and the "x" are found by mouse position in the button's own OnMouseUp.

local W = Questbound
local L = W.L
local C = W.COLOR
local Launcher = {}
W.Launcher = Launcher

local H = 32               -- button height
local LOGO = 28
local ARROW_W = 16         -- « collapse / » expand
local ARROW_RIGHT = 10     -- the arrow sits this far from the right edge (clear of the "x")
local ANIM = 0.2           -- seconds to hide / show the name
local BG_ALPHA, BG_ALPHA_HOVER = 0.65, 0.85

local ui = {}
local inCombat = false

-- ---------------------------------------------------------------------------
-- Logo

-- Returns the dark disc; its gold part (ring + marker) is logo.gold, tinted with the
-- accent color. Before a full game restart the new images aren't loaded yet: then
-- the compass icon stands in (logo:Refresh() again once they are).
function W.Logo(parent, size, level)
    level = level or 2
    local fill = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
    fill:SetDimensions(size, size)
    fill:SetMouseEnabled(false)
    fill:SetDrawLevel(level)
    local gold = WINDOW_MANAGER:CreateControl(nil, fill, CT_TEXTURE)
    gold:SetAnchorFill(fill)
    gold:SetMouseEnabled(false)
    gold:SetDrawLevel(level + 1)
    fill.gold = gold
    fill.Refresh = function(self)
        local ok = W.TextureLoaded("logo_fill.dds") and W.TextureLoaded("logo_gold.dds")
        self:SetTexture(W.UI("logo_fill.dds"))
        self:SetColor(C.disc.r, C.disc.g, C.disc.b, ok and 1 or 0)
        self.gold:SetTexture(W.UI(ok and "logo_gold.dds" or "compass.dds"))
        self.gold:SetColor(W.RGBA(C.theme))
    end
    fill:Refresh()
    return fill
end

-- ---------------------------------------------------------------------------
-- Button

local function IsOver(control, pad)
    if not control or control:IsHidden() then return false end
    pad = pad or 0
    local x, y = GetUIMousePosition()
    return x >= control:GetLeft() - pad and x <= control:GetRight() + pad
        and y >= control:GetTop() - pad and y <= control:GetBottom() + pad
end

local function Disc()
    return W.TEX .. (W.TextureLoaded("disc.dds") and "disc.dds" or "dot.dds")
end

-- name bright while hovered or while the tracker is shown
local function Paint(hovered)
    if not ui.win then return end
    local bright = hovered or W.sv.tracker.shown
    ui.text:SetColor(W.RGBA(bright and C.theme or C.text, bright and 1 or 0.8))
    ui.logo:SetAlpha(bright and 1 or 0.75)
    ui.arrow:SetText(W.sv.launcher.compact and "»" or "«")
    ui.arrow:SetColor(W.RGBA(ui.arrowHover and C.theme or C.dim))
end

-- width with / without the name (the arrow is pinned to the right edge)
local function Width(compact)
    local base = 3 + LOGO + ARROW_W + ARROW_RIGHT
    if compact then return base + 4 end
    return base + 7 + math.max(ui.text:GetTextWidth(), 90) + 4
end

-- animate: slide the width and fade the name (and "x") instead of snapping
local function SetCompact(on, animate)
    W.sv.launcher.compact = on
    local win, text, close = ui.win, ui.text, ui.close
    Paint(false)
    local from, to = win:GetWidth(), Width(on)
    if not animate then
        win:SetHandler("OnUpdate", nil)
        text:SetHidden(on); text:SetAlpha(1)
        close:SetHidden(on); close:SetAlpha(1)
        win:SetWidth(to)
        return
    end
    text:SetHidden(false)
    close:SetHidden(false)
    local start = GetFrameTimeSeconds()
    win:SetHandler("OnUpdate", function(self)
        local t = math.min(1, (GetFrameTimeSeconds() - start) / ANIM)
        local eased = 1 - (1 - t) ^ 3   -- ease out: quick start, gentle stop
        self:SetWidth(from + (to - from) * eased)
        -- hiding: the name fades a bit faster than the button shrinks, so it never sticks out
        local alpha = on and math.max(0, 1 - eased * 1.6) or eased
        text:SetAlpha(alpha)
        close:SetAlpha(alpha)
        if t >= 1 then
            self:SetHandler("OnUpdate", nil)
            text:SetHidden(on)
            close:SetHidden(on)
        end
    end)
end

local function ToggleTracker()
    W.sv.tracker.shown = not W.sv.tracker.shown
    W.callbacks:FireCallbacks("SettingsChanged")
end

local function Hide()
    W.sv.launcher.hidden = true
    Launcher.Update()
    W.Print(L("HIDDEN_HINT", L("NAME_LAUNCHER"), "/qb"))
end

-- Standard spot: right above the quest tracker, left edges lined up (it follows the
-- tracker until you drag the button somewhere yourself).
local ABOVE_TRACKER_GAP = 6   -- (release layout)

local function Place()
    local s = W.sv.launcher
    ui.win:ClearAnchors()
    local tracker = W.Tracker.Window and W.Tracker.Window()
    if s.x and s.y then
        ui.win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, s.x, s.y)
    elseif tracker then
        ui.win:SetAnchor(BOTTOMLEFT, tracker, TOPLEFT, 0, -ABOVE_TRACKER_GAP)
    else
        ui.win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 16, 128)
    end
end

local function Menu()
    ClearTooltip(InformationTooltip)
    ClearMenu()
    AddMenuItem(L(W.sv.tracker.shown and "LAUNCHER_MENU_HIDE_TRACKER" or "LAUNCHER_MENU_SHOW_TRACKER"), ToggleTracker)
    AddMenuItem(L(W.sv.launcher.compact and "LAUNCHER_MENU_WIDE" or "LAUNCHER_MENU_COMPACT"), function()
        SetCompact(not W.sv.launcher.compact, true)
    end)
    AddMenuItem(L("LAUNCHER_MENU_HIDE"), Hide)
    AddMenuItem(L("LAUNCHER_MENU_SETTINGS"), W.OpenSettings)
    ShowMenu(ui.win)
end

-- shown unless you hid it, or (with "hide in combat" on) while you're fighting
function Launcher.Update()
    if not ui.win then return end
    local s = W.sv.launcher
    W.ShowOnHud(ui.fragment, not s.hidden and not (s.combatHide and inCombat))
    ui.logo:Refresh()
    local disc = Disc()
    ui.capL:SetTexture(disc)
    ui.capR:SetTexture(disc)
    ui.closeBg:SetTexture(disc)
    -- background in the color theme's shade
    local a = IsOver(ui.win) and BG_ALPHA_HOVER or BG_ALPHA
    for _, t in ipairs(ui.bg) do t:SetColor(C.shade.r, C.shade.g, C.shade.b, a) end
    ui.closeBg:SetColor(C.shade.r, C.shade.g, C.shade.b, 0.85)
    ui.text:SetFont(W.Font("title", 16))
    if not ui.win:GetHandler("OnUpdate") then SetCompact(s.compact == true) end
    Paint(IsOver(ui.win))
end

function Launcher.SetCompact(on)
    if ui.win then SetCompact(on, true) else W.sv.launcher.compact = on end
end

function Launcher.Init()
    local s = W.sv.launcher
    local win = WINDOW_MANAGER:CreateTopLevelWindow("Questbound_Launcher")
    ui.win = win
    win:SetHeight(H)
    win:SetClampedToScreen(true)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    Place()

    -- rounded background: left half disc + strip + right half disc
    ui.capL = WINDOW_MANAGER:CreateControl(nil, win, CT_TEXTURE)
    ui.capL:SetTextureCoords(0, 0.5, 0, 1)
    ui.capL:SetDimensions(H / 2, H)
    ui.capL:SetAnchor(TOPLEFT, win, TOPLEFT, 0, 0)
    ui.capR = WINDOW_MANAGER:CreateControl(nil, win, CT_TEXTURE)
    ui.capR:SetTextureCoords(0.5, 1, 0, 1)
    ui.capR:SetDimensions(H / 2, H)
    ui.capR:SetAnchor(TOPRIGHT, win, TOPRIGHT, 0, 0)
    ui.mid = WINDOW_MANAGER:CreateControl(nil, win, CT_TEXTURE)
    ui.mid:SetAnchor(TOPLEFT, ui.capL, TOPRIGHT, 0, 0)
    ui.mid:SetAnchor(BOTTOMRIGHT, ui.capR, BOTTOMLEFT, 0, 0)
    ui.bg = { ui.capL, ui.mid, ui.capR }
    for _, t in ipairs(ui.bg) do
        t:SetColor(C.shade.r, C.shade.g, C.shade.b, BG_ALPHA)
        t:SetMouseEnabled(false)
        t:SetDrawLevel(0)
    end

    ui.logo = W.Logo(win, LOGO, 2)
    ui.logo:SetAnchor(LEFT, win, LEFT, 3, 0)

    ui.text = WINDOW_MANAGER:CreateControl(nil, win, CT_LABEL)
    ui.text:SetFont(W.Font("title", 16))
    ui.text:SetText(zo_strupper(L("TITLE")))
    ui.text:SetAnchor(LEFT, ui.logo, RIGHT, 7, 1)
    ui.text:SetDrawLevel(5)
    ui.text:SetMouseEnabled(false)

    ui.arrow = WINDOW_MANAGER:CreateControl(nil, win, CT_LABEL)
    ui.arrow:SetFont("$(BOLD_FONT)|20|soft-shadow-thin")
    ui.arrow:SetDimensions(ARROW_W, H)
    ui.arrow:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    ui.arrow:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    ui.arrow:SetAnchor(RIGHT, win, RIGHT, -ARROW_RIGHT, -1)   -- moves with the edge
    ui.arrow:SetDrawLevel(9)
    ui.arrow:SetMouseEnabled(false)

    -- small round "x" on the top-right corner: hides the button
    ui.closeBg = WINDOW_MANAGER:CreateControl(nil, win, CT_TEXTURE)
    ui.closeBg:SetColor(C.shade.r, C.shade.g, C.shade.b, 0.85)
    ui.closeBg:SetDimensions(16, 16)
    ui.closeBg:SetAnchor(CENTER, win, TOPRIGHT, -2, 2)
    ui.closeBg:SetDrawLevel(7)
    ui.closeBg:SetMouseEnabled(false)
    local x = WINDOW_MANAGER:CreateControl(nil, ui.closeBg, CT_LABEL)
    x:SetFont("$(BOLD_FONT)|12|soft-shadow-thin")
    x:SetText("x")
    x:SetColor(W.RGBA(C.dim))
    x:SetAnchor(CENTER, ui.closeBg, CENTER, 0, -1)
    x:SetDrawLevel(8)
    x:SetMouseEnabled(false)
    ui.close = ui.closeBg
    ui.closeX = x

    -- hover: brighter background, tooltip for the part under the mouse
    local hoverPart
    local function Hover()
        local part = (IsOver(ui.closeBg, 2) and "close") or (IsOver(ui.arrow, 3) and "arrow") or "button"
        ui.arrowHover = part == "arrow"
        ui.closeX:SetColor(W.RGBA(part == "close" and C.text or C.dim))
        if part ~= hoverPart then
            hoverPart = part
            Paint(true)
            InitializeTooltip(InformationTooltip, win, TOPLEFT, 0, 4, BOTTOMLEFT)
            if part == "close" then
                SetTooltipText(InformationTooltip, L("LAUNCHER_HIDE_TT"))
            elseif part == "arrow" then
                SetTooltipText(InformationTooltip, L(W.sv.launcher.compact and "LAUNCHER_EXPAND" or "LAUNCHER_COLLAPSE"))
            else
                SetTooltipText(InformationTooltip, L("LAUNCHER_TT"))
            end
        end
    end
    win:SetHandler("OnMouseEnter", function()
        for _, t in ipairs(ui.bg) do t:SetColor(C.shade.r, C.shade.g, C.shade.b, BG_ALPHA_HOVER) end
        hoverPart = nil
        Hover()
        EVENT_MANAGER:RegisterForUpdate("Questbound_LauncherHover", 50, Hover)
    end)
    win:SetHandler("OnMouseExit", function()
        EVENT_MANAGER:UnregisterForUpdate("Questbound_LauncherHover")
        for _, t in ipairs(ui.bg) do t:SetColor(C.shade.r, C.shade.g, C.shade.b, BG_ALPHA) end
        ui.arrowHover = false
        ui.closeX:SetColor(W.RGBA(C.dim))
        Paint(false)
        ClearTooltip(InformationTooltip)
    end)

    -- drag to move; a short click (no movement) shows / hides the tracker
    win:SetHandler("OnMouseDown", function(self, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then ui.pressX, ui.pressY = self:GetLeft(), self:GetTop() end
    end)
    win:SetHandler("OnMoveStart", function() ClearTooltip(InformationTooltip) end)
    win:SetHandler("OnMoveStop", function(self)
        W.sv.launcher.x, W.sv.launcher.y = self:GetLeft(), self:GetTop()
        Place()
    end)
    win:SetHandler("OnMouseUp", function(self, button, upInside)
        if button == MOUSE_BUTTON_INDEX_RIGHT and upInside then
            Menu()
            return
        end
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        local moved = ui.pressX and (math.abs(self:GetLeft() - ui.pressX) > 3 or math.abs(self:GetTop() - ui.pressY) > 3)
        ui.pressX, ui.pressY = nil, nil
        if not upInside or moved then return end
        PlaySound(SOUNDS.DEFAULT_CLICK)
        ClearTooltip(InformationTooltip)
        if IsOver(ui.closeBg, 2) then
            Hide()
        elseif IsOver(ui.arrow, 3) then
            SetCompact(not W.sv.launcher.compact, true)
        else
            ToggleTracker()
        end
    end)

    ui.fragment = W.HudFragment(win)
    inCombat = IsUnitInCombat("player")
    EVENT_MANAGER:RegisterForEvent("Questbound_Launcher", EVENT_PLAYER_COMBAT_STATE, function(_, combat)
        inCombat = combat
        Launcher.Update()
    end)
    W.callbacks:RegisterCallback("SettingsChanged", Launcher.Update)
    W.callbacks:RegisterCallback("PositionsReset", Place)
    Launcher.Update()
    zo_callLater(function() SetCompact(W.sv.launcher.compact == true) end, 1)   -- the font's width is only known a frame later
end
