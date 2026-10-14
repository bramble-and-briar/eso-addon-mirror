-- Groupbound_Launcher.lua : the button. Logo (picked 2026-10-13) = an enamel badge: gold rim, black
-- enamel, two figures and a gold plus (Textures/logo.dds, _GroupboundDev/make_logo.ps1); the count of
-- groups that fit you sits on a small gold disc (badge.dds). Hover = the badge brightens and grows a
-- little; click = open / close the board; drag = move; right-click = menu; x top right = hide.
-- Until the game was restarted once (new textures), the old look shows: the game's Group Finder
-- icon on a see-through black tile with a plain number.

local G = Groupbound
local C = G.COLOR
local L = G.L
local Anim = G.Anim
local W = G.W
local Launcher = {}
G.Launcher = Launcher

local SIZE = 44
local DEFAULT_X, DEFAULT_Y = 16, 228
local LOGO = "Groupbound/Textures/logo.dds"
local BADGE = "Groupbound/Textures/badge.dds"
local LOGO_SIZE = 40
local SCALE_MIN, SCALE_MAX = 0.7, 1.6
local btn, fragment

local function Paint()
    local p = btn.hoverP
    if btn.newArt then
        -- the badge: a touch dimmer at rest, full light + 6 % bigger on hover, dips when pressed
        btn.fill:SetAlpha(0)
        local v = Anim.Lerp(0.86, 1, p)
        btn.logo:SetColor(v, v, v, 1)
        btn.logo:SetScale(btn.pressed and 0.94 or Anim.Lerp(1, 1.06, p))
    else
        btn.fill:SetAlpha(Anim.Lerp(0.45, 0.75, p))
        btn.logo:SetColor(Anim.Lerp(C.normal.r, C.selected.r, p), Anim.Lerp(C.normal.g, C.selected.g, p), Anim.Lerp(C.normal.b, C.selected.b, p), 1)
        btn.logo:SetScale(btn.pressed and 0.94 or 1)
    end
end

-- the new logo once the game has the file (it only knows new files after a full restart): an
-- invisible copy (btn.probe) loads it; until then the old icon shows (a missing file would draw as
-- a white square). Checked every second for 10 s.
local artTries = 0
local function CheckArt()
    if not btn or btn.newArt then return end
    artTries = artTries + 1
    local loaded = btn.probe.IsTextureLoaded and btn.probe:IsTextureLoaded()
    -- (a missing file can count as "loaded" with the game's placeholder: the real one is 64 wide)
    if loaded and btn.probe.GetTextureFileDimensions then
        local w = btn.probe:GetTextureFileDimensions()
        loaded = w == 64
    end
    if loaded then
        btn.newArt = true
        btn.logo:SetTexture(LOGO)
        btn.logo:SetDimensions(LOGO_SIZE, LOGO_SIZE)
        Paint()
        Launcher.Refresh()
    elseif artTries < 10 then
        G.Later(CheckArt, 1000, "Launcher")
    end
end

local function Place()
    btn:ClearAnchors()
    local x, y = G.sv.launcher.x, G.sv.launcher.y
    btn:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x or DEFAULT_X, y or DEFAULT_Y)
end

local function Create()
    btn = WINDOW_MANAGER:CreateTopLevelWindow("Groupbound_Launcher")
    btn:SetDimensions(SIZE, SIZE)
    btn:SetMouseEnabled(true)
    btn:SetMovable(true)
    btn:SetClampedToScreen(true)
    Place()
    btn.hoverP = 0
    btn.fill = W.Tex(btn, nil, nil, nil, C.panel, 1)
    btn.fill:SetAnchorFill(btn)
    -- (starts with the old icon; CheckArt switches to the badge once its file loaded)
    btn.logo = W.Tex(btn, G.LOGO, SIZE - 6, SIZE - 6)
    btn.logo:SetAnchor(CENTER, btn, CENTER, 0, 0)
    btn.logo:SetDrawLevel(2)
    btn.probe = W.Tex(btn, LOGO, 1, 1)
    btn.probe:SetAnchor(TOPLEFT, btn, TOPLEFT, 0, 0)
    btn.probe:SetAlpha(0)
    -- the count: on the gold disc (new look) or plain bottom right (old look)
    btn.countBg = W.Tex(btn, BADGE, 18, 18)
    btn.countBg:SetAnchor(BOTTOMRIGHT, btn, BOTTOMRIGHT, 2, 2)
    btn.countBg:SetDrawLevel(3)
    btn.countBg:SetHidden(true)
    btn.count = W.Label(btn, "ZoFontGameSmall", C.selected, "", TEXT_ALIGN_RIGHT)
    btn.count:SetAnchor(BOTTOMRIGHT, btn, BOTTOMRIGHT, -2, 0)
    btn.count:SetDrawLevel(4)
    -- small x just OUTSIDE the badge's top right corner (user 2026-10-14: on the badge it was hard to
    -- see): shows while the mouse is on the button or the x; click = hide the button (/gb brings
    -- it back). Its own control with its own click (it sits outside the button).
    btn.close = W.Tex(btn, "EsoUI/Art/Buttons/closeButton_up.dds", 16, 16)
    -- (-7, 9: closer to the badge's rim without touching it; was -2, 4 = "too far", user 2026-10-14)
    btn.close:SetAnchor(BOTTOMLEFT, btn, TOPRIGHT, -7, 9)
    btn.close:SetDrawLevel(5)
    btn.close:SetMouseEnabled(true)
    btn.close:SetHidden(true)
    btn.close:SetHandler("OnMouseEnter", function()
        btn.close:SetTexture("EsoUI/Art/Buttons/closeButton_mouseOver.dds")
        InitializeTooltip(InformationTooltip, btn.close, BOTTOM, 0, -4, TOP)
        SetTooltipText(InformationTooltip, L("LAUNCHER_HIDE"))
    end)
    btn.close:SetHandler("OnMouseExit", function()
        btn.close:SetTexture("EsoUI/Art/Buttons/closeButton_up.dds")
        ClearTooltip(InformationTooltip)
        Launcher.HideCloseSoon()
    end)
    btn.close:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
            PlaySound(SOUNDS.DEFAULT_CLICK)
            ClearTooltip(InformationTooltip)
            btn.close:SetHidden(true)
            Launcher.HideButton()
        end
    end)
    -- size: mouse wheel over the button (70 % - 160 %, like the other addons' buttons)
    btn:SetScale(G.sv.launcher.scale or 1)
    btn:SetHandler("OnMouseWheel", function(_, delta)
        local scale = (G.sv.launcher.scale or 1) + (delta > 0 and 0.1 or -0.1)
        scale = math.max(SCALE_MIN, math.min(SCALE_MAX, math.floor(scale * 10 + 0.5) / 10))
        G.sv.launcher.scale = scale
        btn:SetScale(scale)
    end)

    local key = "Groupbound_LauncherHover"
    local function Hover(on)
        local from = btn.hoverP
        Anim.Run(key, Anim.MICRO, Anim.Out, function(p)
            btn.hoverP = Anim.Lerp(from, on and 1 or 0, p)
            Paint()
        end)
    end
    btn:SetHandler("OnMouseEnter", function()
        Hover(true)
        btn.close:SetHidden(false)
        InitializeTooltip(InformationTooltip, btn, LEFT, 6, 0, RIGHT)
        SetTooltipText(InformationTooltip, L("TITLE"))
        local fits = G.Board.ForMeCount()
        local line = fits == 1 and L("LAUNCHER_TT_ONE", G.RoleName(G.MyRole())) or L("LAUNCHER_TT", fits, G.RoleName(G.MyRole()))
        InformationTooltip:AddLine(line, "", C.normal.r, C.normal.g, C.normal.b)
        InformationTooltip:AddLine(L("LAUNCHER_X_TT"), "", C.dim.r, C.dim.g, C.dim.b)
        InformationTooltip:AddLine(L("LAUNCHER_WHEEL_TT"), "", C.dim.r, C.dim.g, C.dim.b)
    end)
    btn:SetHandler("OnMouseExit", function()
        Hover(false)
        Launcher.HideCloseSoon()
        btn.pressed = false
        Paint()
        ClearTooltip(InformationTooltip)
    end)
    -- a click = no movement (the game fires OnMoveStart even for a plain click on a movable
    -- control, so "dragged" is measured, like Set Hunter's button)
    btn:SetHandler("OnMouseDown", function(_, button)
        btn.pressX, btn.pressY = btn:GetLeft(), btn:GetTop()
        if button == MOUSE_BUTTON_INDEX_LEFT then
            btn.pressed = true
            Paint()
        end
    end)
    btn:SetHandler("OnMoveStop", function()
        G.sv.launcher.x, G.sv.launcher.y = btn:GetLeft(), btn:GetTop()
    end)
    btn:SetHandler("OnMouseUp", function(_, button, upInside)
        btn.pressed = false
        Paint()
        local moved = btn.pressX and (math.abs(btn:GetLeft() - btn.pressX) > 3 or math.abs(btn:GetTop() - btn.pressY) > 3)
        btn.pressX, btn.pressY = nil, nil
        if not upInside or moved then return end
        if button == MOUSE_BUTTON_INDEX_LEFT then
            PlaySound(SOUNDS.DEFAULT_CLICK)
            ClearTooltip(InformationTooltip)
            G.UI.Toggle()
        elseif button == MOUSE_BUTTON_INDEX_RIGHT then
            ClearTooltip(InformationTooltip)
            G.UI.ShowMenu(Launcher.MenuParts)
        end
    end)
    Paint()
    fragment = G.HudFragment(btn)
end

-- the x goes away a moment after the mouse left both the button and the x (moving from the button
-- onto the x doesn't hide it)
function Launcher.HideCloseSoon()
    G.Later(function()
        if btn and not G.IsOver(btn) and not G.IsOver(btn.close) then btn.close:SetHidden(true) end
    end, 150, "Launcher")
end

-- right-click menu (picked 2026-10-14, sketch D): header (name + how many groups fit you), GO TO
-- (board, post, list again), ON SCREEN switches (small board, quiet in dungeons; the menu stays
-- open and shows On / Off), then Settings and Hide this button. Same look as a group's menu.
function Launcher.MenuParts()
    local fits = G.Board.ForMeCount()
    local role = G.RoleName(G.MyRole())
    local sub = G.Colorize(C.dim, fits == 1 and L("LAUNCHER_TT_ONE", role) or L("LAUNCHER_TT", fits, role))
    local go = {
        { icon = G.LOGO, text = L(G.UI.IsShown() and "MENU_CLOSE_BOARD" or "MENU_OPEN_BOARD"), key = "GROUPBOUND_WINDOW", fn = function() G.UI.Toggle() end },
        { icon = "EsoUI/Art/Buttons/plus_up.dds", text = L("POST_A_GROUP"), key = "GROUPBOUND_POST", fn = function() G.UI.ShowPost() end },
    }
    if G.Finder.LastListing() and not G.Finder.MyListing() then
        go[#go + 1] = { icon = "primary", text = L("RELIST"), key = "GROUPBOUND_RELIST", fn = function() G.Finder.Relist() end }
    end
    return L("TITLE"), sub, {
        { head = L("MENU_GO_TO"), upper = true, items = go },
        { head = L("SET_HEAD_SCREEN"), upper = true, items = {
            { text = L("MENU_HUD"), state = function() return G.sv.hud.shown end, fn = function() G.ToggleHud() end },
            { text = L("MENU_QUIET"), state = function() return G.sv.quietInside end, fn = function()
                G.sv.quietInside = not G.sv.quietInside
                G.callbacks:FireCallbacks("SettingsChanged")
            end },
        } },
        { items = {
            { icon = "EsoUI/Art/MenuBar/Gamepad/gp_playermenu_icon_settings.dds", iconSize = 15, text = L("SETTINGS"), fn = function() G.OpenSettings() end },
            { icon = "hide", text = L("LAUNCHER_HIDE"), fn = function() Launcher.HideButton() end },
        } },
    }
end

-- hides the button; the chat line says how to get it back (/gb)
function Launcher.HideButton()
    G.sv.launcher.hidden = true
    Launcher.Refresh()
    G.Print(L("HIDDEN_HINT"))
end

function Launcher.Refresh()
    if not btn then return end
    local show = not G.sv.launcher.hidden and not (G.sv.launcher.combatHide and IsUnitInCombat("player"))
        and not G.Quiet()
    G.ShowOnHud(fragment, show)
    local n = G.Board.ForMeCount()
    btn.count:SetHidden(n == 0)
    btn.count:SetText(n > 99 and "99" or tostring(n))
    btn.countBg:SetHidden(n == 0 or not btn.newArt)
    btn.count:ClearAnchors()
    if btn.newArt then
        -- dark number centered on the gold disc
        btn.count:SetAnchor(CENTER, btn.countBg, CENTER, 0, 0)
        btn.count:SetColor(0.16, 0.10, 0.02, 1)
        btn.count:SetFont("$(BOLD_FONT)|12")
    else
        btn.count:SetAnchor(BOTTOMRIGHT, btn, BOTTOMRIGHT, -2, 0)
        btn.count:SetColor(G.RGBA(C.selected))
        btn.count:SetFont("ZoFontGameSmall")
    end
end

function Launcher.Init()
    Create()
    Launcher.Refresh()
    G.Later(CheckArt, 500, "Launcher")
    G.EM:RegisterForEvent("Groupbound_LauncherCombat", EVENT_PLAYER_COMBAT_STATE, Launcher.Refresh)
    -- (entering / leaving a dungeon or trial: hidden inside with "stay out of the way")
    G.EM:RegisterForEvent("Groupbound_LauncherZone", EVENT_PLAYER_ACTIVATED, Launcher.Refresh)
    G.callbacks:RegisterCallback("SettingsChanged", Launcher.Refresh)
    G.callbacks:RegisterCallback("BoardChanged", Launcher.Refresh)
    G.callbacks:RegisterCallback("PositionsReset", function()
        G.sv.launcher.scale = nil
        btn:SetScale(1)
        Place()
    end)
end
