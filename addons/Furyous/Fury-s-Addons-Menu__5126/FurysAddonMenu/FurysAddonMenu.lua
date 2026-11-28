-- Fury's Addons Menu: the Fury sidebar, the Fury addons list (/fury menu) and the icons of the
-- other Fury addons in each Fury window's title bar.
--
-- Each Fury addon calls FurysAddonMenu:Register() once with its name, icon and two functions
-- (open, settings). This library does everything else: it builds the sidebar and the list, keeps
-- their settings, owns the /fury command and the key "Show or hide the Fury sidebar".
--
-- Every Fury addon requires it (DependsOn), so it is always loaded before them.

FurysAddonMenu = { version = 132 }
local M = FurysAddonMenu

local NAME = "Fury's Addons"
local MENU_WIDTH, MENU_ROW = 600, 40
local MENU_HELP = "Type /fury, or press the key (Controls > Keybindings > Fury's Addons), to show or hide the sidebar. /fury menu opens this window."
-- Sidebar sizes: small (the default, about the size of other sidebars) and big. Icon, gap, grip.
local BAR_SMALL = { icon = 28, pad = 2, grip = 12 }
local BAR_BIG = { icon = 40, pad = 5, grip = 12 }
local FALLBACK_GLYPH = "EsoUI/Art/MainMenu/menuBar_collections_up.dds"
local TITLE_ICON, TITLE_GAP = 30, 2

------------------------------------------------------------------------------
-- The Fury look (the same colors and fonts as Fury's addons)
------------------------------------------------------------------------------
local PANEL  = ZO_ColorDef:New("0F0E1F")
local EDGE   = ZO_ColorDef:New("4A3D99")
local GLOW   = ZO_ColorDef:New("1E1A44")
local VIOLET = ZO_ColorDef:New("A08CFF")
local TEXT   = ZO_ColorDef:New("ECEAF8")
local SUB    = ZO_ColorDef:New("B4B0D8")
local FONT_TITLE = "$(ANTIQUE_FONT)|26|soft-shadow-thick"
local TITLE_BAR = 46

local function Chat(text)
    CHAT_ROUTER:AddSystemMessage("|cA08CFF[" .. NAME .. "]|r " .. text)
end

local function Paint(control, color)
    control:SetColor(color:UnpackRGBA())
end

local function Rect(name, parent, color, layer, level)
    local t = WINDOW_MANAGER:CreateControl(name, parent, CT_TEXTURE)
    t:SetDrawLayer(layer or DL_BACKGROUND)
    t:SetDrawLevel(level or 1)
    Paint(t, color)
    return t
end

local function Tip(control, text)
    control:SetHandler("OnMouseEnter", function(self)
        InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -4)
        SetTooltipText(InformationTooltip, text)
    end)
    control:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
end

-- An icon button for one Fury addon: left-click opens it, right-click opens its settings.
local function AddonIcon(name, parent, entry)
    local glyph = entry.glyph or FALLBACK_GLYPH
    local icon = WINDOW_MANAGER:CreateControl(name, parent, CT_BUTTON)
    icon:SetNormalTexture(glyph)
    icon:SetMouseOverTexture((string.gsub(glyph, "_up.dds", "_over.dds")))
    icon:EnableMouseButton(MOUSE_BUTTON_INDEX_RIGHT, true)
    icon:SetHandler("OnClicked", function(_, button)
        if button == MOUSE_BUTTON_INDEX_RIGHT then entry.settings() else entry.open() end
    end)
    Tip(icon, entry.name .. "\nLeft-click: open. Right-click: settings.")
    return icon
end

------------------------------------------------------------------------------
-- The list of installed Fury addons
------------------------------------------------------------------------------
local entries = {}
M.entries = entries   -- read by Fury addons from before 1.3.0

-- Called once by each Fury addon while it loads. `entry` is
-- { name = "Fury's Something", glyph = "path/to/icon_up.dds", open = function, settings = function }.
function M:Register(entry)
    entries[entry.name] = entry
end

local function SortedNames()
    local names = {}
    for name in pairs(entries) do names[#names + 1] = name end
    table.sort(names)
    return names
end

-- The sidebar's settings (shown, place, row or column, size, locked, hidden in combat, shown
-- without the cursor), one set for the whole PC. Set at this library's EVENT_ADD_ON_LOADED.
local saved = {}

------------------------------------------------------------------------------
-- The sidebar: a slim bar of icons, one per installed Fury addon, as a column or a row. Drag it
-- by its violet line. It starts turned off.
------------------------------------------------------------------------------
local bar, barGrip, barGear, barFragment
local barIcons = {}
local checks   -- the boxes in the list window, once it is built

local function LayoutBar()
    local size = saved.big == true and BAR_BIG or BAR_SMALL
    local across = saved.across == true
    local step = size.icon + size.pad
    local count = #barIcons
    local long, short = size.grip + (count + 1) * step + size.pad, size.icon + 2 * size.pad
    barGrip:ClearAnchors()
    barGrip:SetAnchor(TOPLEFT, bar, TOPLEFT, size.pad, size.pad)
    if across then
        bar:SetDimensions(long, short)
        barGrip:SetAnchor(BOTTOMRIGHT, bar, BOTTOMLEFT, size.pad + 3, -size.pad)
    else
        bar:SetDimensions(short, long)
        barGrip:SetAnchor(BOTTOMRIGHT, bar, TOPRIGHT, -size.pad, size.pad + 3)
    end
    for i = 1, count + 1 do
        local icon = barIcons[i] or barGear
        local edge = icon == barGear and size.icon - 6 or size.icon
        local at = size.grip + (i - 1) * step + (size.icon - edge) / 2
        icon:SetDimensions(edge, edge)
        icon:ClearAnchors()
        if across then
            icon:SetAnchor(LEFT, bar, LEFT, at, 0)
        else
            icon:SetAnchor(TOP, bar, TOP, 0, at)
        end
    end
end

-- Puts the saved settings on the sidebar.
local function ApplyBar()
    if not bar then return end
    LayoutBar()
    bar:SetMovable(not saved.locked)
    barFragment:SetHiddenForReason("off", not saved.shown)
    barFragment:SetHiddenForReason("combat", saved.combat == true and IsUnitInCombat("player"))
    -- The icons can only be clicked with the cursor out, so the sidebar shows in cursor mode only,
    -- unless the player asks to see it all the time.
    if saved.always == true then
        HUD_SCENE:AddFragment(barFragment)
    else
        HUD_SCENE:RemoveFragment(barFragment)
    end
end

local function BuildBar()
    bar = WINDOW_MANAGER:CreateTopLevelWindow("FurysAddonMenuBar")
    bar:SetHidden(true)
    bar:SetMouseEnabled(true)
    bar:SetClampedToScreen(true)
    if saved.x and saved.y then
        bar:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, saved.x, saved.y)
    else
        bar:SetAnchor(LEFT, GuiRoot, LEFT, 20, 0)
    end
    bar:SetHandler("OnMoveStop", function(self)
        saved.x, saved.y = self:GetLeft(), self:GetTop()
    end)

    local bg = WINDOW_MANAGER:CreateControl("$(parent)Bg", bar, CT_BACKDROP)
    bg:SetAnchorFill(bar)
    bg:SetEdgeTexture("", 1, 1, 2, 0)
    bg:SetCenterColor(PANEL.r, PANEL.g, PANEL.b, 0.85)
    bg:SetEdgeColor(EDGE:UnpackRGBA())

    -- The grip: a violet line. It takes no clicks, so a drag there moves the bar.
    barGrip = Rect("$(parent)Grip", bar, VIOLET, DL_CONTROLS, 1)
    for i, name in ipairs(SortedNames()) do
        barIcons[i] = AddonIcon("$(parent)Icon" .. i, bar, entries[name])
    end

    barGear = WINDOW_MANAGER:CreateControl("$(parent)Gear", bar, CT_BUTTON)
    barGear:SetNormalTexture("/esoui/art/chatwindow/chat_options_up.dds")
    barGear:SetPressedTexture("/esoui/art/chatwindow/chat_options_down.dds")
    barGear:SetMouseOverTexture("/esoui/art/chatwindow/chat_options_over.dds")
    barGear:SetHandler("OnClicked", function() M.Menu() end)
    Tip(barGear, "The Fury addons list and this sidebar's options: lock it in place, a row or a column, big or small icons, hide it in combat, keep it on screen without the cursor, turn it off.\nTo move the sidebar, drag its violet line. /fury shows or hides it.")

    barFragment = ZO_HUDFadeSceneFragment:New(bar)
    HUD_UI_SCENE:AddFragment(barFragment)
    EVENT_MANAGER:RegisterForEvent("FurysAddonMenuBar", EVENT_PLAYER_COMBAT_STATE, ApplyBar)
    ApplyBar()
end

-- Builds the sidebar once, when the first character is in the world and every Fury addon is on
-- the list.
local function StartBar()
    if not bar then BuildBar() end
end
M.Start = StartBar
-- Fury addons from before 1.3.0 build their own sidebar only when their copy is newer than this.
M.lib = 1000

local function RefreshChecks()
    if not checks then return end
    for field, check in pairs(checks) do
        ZO_CheckButton_SetCheckState(check, saved[field] == true)
    end
end

-- Shows or hides the sidebar (/fury and the key).
function M.Toggle()
    StartBar()
    saved.shown = not saved.shown
    ApplyBar()
    RefreshChecks()
    if saved.shown then
        Chat("Sidebar on. It shows whenever your cursor is out. Left-click an icon to open that addon, right-click for its settings. Drag its violet line to move it. /fury hides it again.")
    else
        Chat("Sidebar off. /fury shows it again; /fury menu opens the list of your Fury addons.")
    end
end

------------------------------------------------------------------------------
-- The list window (/fury menu, or the sidebar's gear): every installed Fury addon with an Open
-- and a Settings button, and the sidebar's options.
------------------------------------------------------------------------------
local menuWindow

local function MenuButton(name, win, text, tip, onClick)
    local button = WINDOW_MANAGER:CreateControlFromVirtual(name, win, "ZO_DefaultButton")
    button:SetDimensions(110, 28)
    button:SetText(text)
    button:SetHandler("OnClicked", onClick)
    Tip(button, tip)
    return button
end

local function MenuCheck(name, win, y, text, tip, field)
    local check = WINDOW_MANAGER:CreateControlFromVirtual(name, win, "ZO_CheckButton")
    check:SetAnchor(TOPLEFT, win, TOPLEFT, 22, y)
    ZO_CheckButton_SetLabelText(check, text)
    ZO_CheckButton_SetToggleFunction(check, function(_, checked)
        StartBar()
        saved[field] = checked
        ApplyBar()
    end)
    Tip(check, tip)
    return check
end

-- The window frame: indigo-edged panel, title glow, violet line under the centered title.
local function PaintWindow(win, bg, title)
    bg:SetDrawLayer(DL_BACKGROUND)
    bg:SetDrawLevel(0)
    bg:SetCenterColor(PANEL:UnpackRGBA())
    bg:SetEdgeColor(EDGE:UnpackRGBA())
    title:SetFont(FONT_TITLE)
    Paint(title, TEXT)

    local glow = Rect("$(parent)Glow", win, GLOW, DL_BACKGROUND, 1)
    glow:SetAnchor(TOPLEFT, win, TOPLEFT, 2, 2)
    glow:SetAnchor(BOTTOMRIGHT, win, TOPRIGHT, -2, TITLE_BAR)
    glow:SetColor(1, 1, 1, 1)
    local r1, g1, b1, a1 = GLOW:UnpackRGBA()
    local r2, g2, b2, a2 = PANEL:UnpackRGBA()
    glow:SetVertexColors(VERTEX_POINTS_TOPLEFT, r1, g1, b1, a1)
    glow:SetVertexColors(VERTEX_POINTS_TOPRIGHT, r1, g1, b1, a1)
    glow:SetVertexColors(VERTEX_POINTS_BOTTOMLEFT, r2, g2, b2, a2)
    glow:SetVertexColors(VERTEX_POINTS_BOTTOMRIGHT, r2, g2, b2, a2)

    local line = Rect("$(parent)Line", win, VIOLET, DL_BACKGROUND, 2)
    line:SetAnchor(TOPLEFT, win, TOPLEFT, 2, TITLE_BAR)
    line:SetAnchor(BOTTOMRIGHT, win, TOPRIGHT, -2, TITLE_BAR + 2)
end

local function BuildMenu()
    local win = WINDOW_MANAGER:CreateTopLevelWindow("FurysAddonMenuWindow")
    win:SetHidden(true)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:SetDrawTier(DT_HIGH)
    win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)

    local bg = WINDOW_MANAGER:CreateControl("$(parent)Bg", win, CT_BACKDROP)
    bg:SetAnchorFill(win)
    bg:SetEdgeTexture("", 1, 1, 2, 0)

    local title = WINDOW_MANAGER:CreateControl("$(parent)Title", win, CT_LABEL)
    title:SetAnchor(TOP, win, TOP, 0, 10)
    title:SetText(NAME)

    local close = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)Close", win, "ZO_CloseButton")
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -12, 12)
    close:SetHandler("OnClicked", function() SCENE_MANAGER:HideTopLevel(win) end)
    Tip(close, "Close (Esc)")

    PaintWindow(win, bg, title)

    local names = SortedNames()
    for i, name in ipairs(names) do
        local entry = entries[name]
        local y = 62 + (i - 1) * MENU_ROW
        local label = WINDOW_MANAGER:CreateControl("$(parent)Name" .. i, win, CT_LABEL)
        label:SetFont("ZoFontWinH4")
        Paint(label, TEXT)
        label:SetText(name)
        label:SetAnchor(TOPLEFT, win, TOPLEFT, 20, y + 3)
        local settings = MenuButton("$(parent)Settings" .. i, win, "Settings", "Opens the settings of " .. name .. ".", function()
            SCENE_MANAGER:HideTopLevel(win)
            entry.settings()
        end)
        settings:SetAnchor(TOPRIGHT, win, TOPRIGHT, -20, y)
        local open = MenuButton("$(parent)Open" .. i, win, "Open", "Opens the window of " .. name .. ".", function()
            SCENE_MANAGER:HideTopLevel(win)
            entry.open()
        end)
        open:SetAnchor(RIGHT, settings, LEFT, -8, 0)
    end

    local y = 62 + #names * MENU_ROW + 10
    checks = {
        shown = MenuCheck("$(parent)BarShown", win, y, "Show the sidebar",
            "A slim bar of icons, one per Fury addon, that shows whenever your cursor is out. Left-click an icon to open that addon, right-click for its settings. Starts turned off. /fury and the key do the same as this box.", "shown"),
        across = MenuCheck("$(parent)BarAcross", win, y + 28, "Horizontal sidebar (a row of icons)",
            "With this on, the icons sit side by side in a row. Off: they are stacked in a column.", "across"),
        big = MenuCheck("$(parent)BarBig", win, y + 56, "Bigger sidebar icons",
            "With this on, the sidebar's icons are bigger and further apart. Off: a slim sidebar with small icons.", "big"),
        locked = MenuCheck("$(parent)BarLocked", win, y + 84, "Lock the sidebar in place",
            "With this on, the sidebar can't be dragged. Off: drag its violet line to move it.", "locked"),
        combat = MenuCheck("$(parent)BarCombat", win, y + 112, "Hide the sidebar in combat",
            "With this on, the sidebar is hidden while you are in combat and comes back afterwards.", "combat"),
        always = MenuCheck("$(parent)BarAlways", win, y + 140, "Show the sidebar without the cursor too",
            "Off: the sidebar shows only while your cursor is out, which is when you can click it. With this on, it also stays on screen while you play without the cursor.", "always"),
    }

    local help = WINDOW_MANAGER:CreateControl("$(parent)Help", win, CT_LABEL)
    help:SetFont("ZoFontGameSmall")
    Paint(help, SUB)
    help:SetWidth(MENU_WIDTH - 40)
    help:SetText(MENU_HELP)
    help:SetAnchor(TOPLEFT, win, TOPLEFT, 20, y + 174)

    win:SetDimensions(MENU_WIDTH, y + 174 + 52)
    SCENE_MANAGER:RegisterTopLevel(win, false)
    return win
end

-- Opens or closes the list window (/fury menu and the sidebar's gear).
function M.Menu()
    if not menuWindow then menuWindow = BuildMenu() end
    if menuWindow:IsHidden() then
        RefreshChecks()
        SCENE_MANAGER:ShowTopLevel(menuWindow)
    else
        SCENE_MANAGER:HideTopLevel(menuWindow)
    end
end

------------------------------------------------------------------------------
-- The other Fury addons in a window's title bar: a row of small icons between the window's name
-- and its version, built the first time the window shows (when every Fury addon is on the list):
--   [glyph] Title  [icons]  v1.2.3  [Start here]  . . .  [search]  [gear]  [X]
-- opts:
--   skip     the calling addon's own name (its icon is left out)
--   label    the title label
--   version  the label with the version, moved to the right of the icons
--   rightOf  the leftmost control on the right side of the title bar
--   reserve  extra width to keep free left of rightOf (optional)
--   start    the Start here button, moved after the version (default: the window's child
--            named StartHere, when it has one)
-- Icons that would push Start here into the reserved space are left out.
------------------------------------------------------------------------------
function M:TitleIcons(win, opts)
    local built = false
    local function Build()
        if built then return end
        built = true
        local others = {}
        for _, name in ipairs(SortedNames()) do
            if name ~= opts.skip then others[#others + 1] = name end
        end
        local start = opts.start or win:GetNamedChild("StartHere")
        local left = start or opts.label
        local room = opts.rightOf:GetLeft() - (opts.reserve or 0) - left:GetRight() - 24
        local count = math.min(#others, math.floor(room / (TITLE_ICON + TITLE_GAP)))
        if count < 1 then return end

        local previous = opts.label
        for i = 1, count do
            local icon = AddonIcon(win:GetName() .. "FuryIcon" .. i, win, entries[others[i]])
            icon:SetDimensions(TITLE_ICON, TITLE_ICON)
            icon:SetAnchor(LEFT, previous, RIGHT, i == 1 and 10 or TITLE_GAP, 0)
            icon:SetDrawLayer(DL_CONTROLS)
            icon:SetDrawLevel(1)
            previous = icon
        end

        -- The version moves to the right of the icons, still on the title's baseline; Start here
        -- follows it.
        opts.version:ClearAnchors()
        opts.version:SetAnchor(BOTTOMLEFT, previous, BOTTOMRIGHT, 8, -3)
        if start then
            local offset = 8 + opts.version:GetTextWidth() + 14
            start:ClearAnchors()
            start:SetAnchor(LEFT, opts.label, RIGHT, 10 + count * (TITLE_ICON + TITLE_GAP) - TITLE_GAP + offset, 0)
        end
    end
    ZO_PreHookHandler(win, "OnEffectivelyShown", Build)
    if not win:IsHidden() then Build() end
end

------------------------------------------------------------------------------
-- Start-up: the key's name, /fury, saved settings, the sidebar once in the world
------------------------------------------------------------------------------
ZO_CreateStringId("SI_BINDING_NAME_FURYSADDONMENU_TOGGLE", "Show or hide the Fury sidebar")

SLASH_COMMANDS["/fury"] = function(text)
    if zo_strlower(zo_strtrim(text or "")) == "menu" then M.Menu() else M.Toggle() end
end

local function OnActivated()
    EVENT_MANAGER:UnregisterForEvent("FurysAddonMenu", EVENT_PLAYER_ACTIVATED)
    StartBar()
end

local function OnLoaded(_, name)
    if name ~= "FurysAddonMenu" then return end
    EVENT_MANAGER:UnregisterForEvent("FurysAddonMenu", EVENT_ADD_ON_LOADED)
    -- The sidebar's settings, the standard way: one set for the whole PC. Up to 1.3.1 they sat at
    -- the top of the saved file; they are moved into place the first time, so nothing is lost.
    local old = FurysAddonMenu_SV
    saved = ZO_SavedVars:NewAccountWide("FurysAddonMenu_SV", 1, nil, nil, nil, "$AllAccounts")
    if old then
        for key, value in pairs(old) do
            if key ~= "Default" then
                saved[key] = value
                old[key] = nil
            end
        end
    end
    M.sv = saved
    EVENT_MANAGER:RegisterForEvent("FurysAddonMenu", EVENT_PLAYER_ACTIVATED, OnActivated)
end
EVENT_MANAGER:RegisterForEvent("FurysAddonMenu", EVENT_ADD_ON_LOADED, OnLoaded)
