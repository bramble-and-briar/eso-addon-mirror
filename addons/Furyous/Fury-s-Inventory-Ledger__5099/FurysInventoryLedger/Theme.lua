-- Fury Night: the shared library of Fury's addons. Look (colors, fonts, window header, tabs,
-- Start here page), chat lines, the welcome line, confirm pop-ups, "More from Fury" and the
-- Fury sidebar and addons list (/fury). The same file ships in every Fury addon, so they all look and behave
-- the same. Only the six lines below differ: it hangs off that addon's own table, so no addon
-- depends on another one being installed. Its one global, FurysAddonMenu, is the list the
-- installed Fury addons put themselves on for the menu.

local A = FurysInventoryLedger
local GLYPH = "EsoUI/Art/MainMenu/menuBar_inventory_up.dds"
local CHAT = "Inventory Ledger"   -- the name in front of this addon's chat lines
local MENU_NAME = "Fury's Inventory Ledger"   -- this addon's line in the Fury addons menu
local function MenuOpen() A.OpenSummary() end
local function MenuSettings() A.OpenSettings() end

local T = {}
A.Theme = T

------------------------------------------------------------------------------
-- Palette
------------------------------------------------------------------------------
T.VOID   = ZO_ColorDef:New("07060E")   -- page, input fields
T.PANEL  = ZO_ColorDef:New("0F0E1F")   -- window background
T.STRIPE = ZO_ColorDef:New("16142C")   -- every other row
T.HOVER  = ZO_ColorDef:New("211D46")   -- row under the mouse
T.SELECT = ZO_ColorDef:New("2D2566")   -- active tab, chosen row
T.EDGE   = ZO_ColorDef:New("4A3D99")   -- frame and dividers
T.GLOW   = ZO_ColorDef:New("1E1A44")   -- top of the title bar
T.VIOLET = ZO_ColorDef:New("A08CFF")   -- accent
T.BLUE   = ZO_ColorDef:New("5CC2FF")   -- column headers
T.TEXT   = ZO_ColorDef:New("ECEAF8")   -- body text
T.SUB    = ZO_ColorDef:New("B4B0D8")   -- secondary text
T.MUTED  = ZO_ColorDef:New("8A86B0")   -- hints, notes
T.GOOD   = ZO_ColorDef:New("5EE6A0")   -- fine, done
T.WARN   = ZO_ColorDef:New("FFC857")   -- close to a limit
T.ORANGE = ZO_ColorDef:New("FFA45C")   -- past a limit, action taken (between WARN and BAD)
T.BAD    = ZO_ColorDef:New("FF6B86")   -- over a limit, failed
T.GOLD   = ZO_ColorDef:New("F2C94C")   -- gold amounts only

T.TAG = "|cA08CFF"                     -- chat prefix color

-- The same colors as plain { r, g, b } lists, for code that keeps its colors that way.
T.RGB = {}
for _, key in ipairs({ "VOID", "PANEL", "STRIPE", "HOVER", "SELECT", "EDGE", "GLOW", "VIOLET", "BLUE",
                       "TEXT", "SUB", "MUTED", "GOOD", "WARN", "ORANGE", "BAD", "GOLD" }) do
    local r, g, b = T[key]:UnpackRGB()
    T.RGB[key] = { r, g, b }
end

------------------------------------------------------------------------------
-- Which version of this shared file an addon carries. Raise it with every change to the file,
-- then copy the file into every addon.
------------------------------------------------------------------------------
T.LIB = 12

------------------------------------------------------------------------------
-- Chat: every line an addon prints starts with its name in violet, "[Guild Toolset] text".
------------------------------------------------------------------------------
-- A line under another name (the Guild Crier inside the Guild Toolset).
function T.ChatAs(name, text)
    CHAT_ROUTER:AddSystemMessage(T.TAG .. "[" .. name .. "]|r " .. text)
end

function T.Chat(text)
    T.ChatAs(CHAT, text)
end

-- The one-time welcome line. `saved` is the addon's saved table and `field` the flag in it that
-- remembers the line was shown. Returns true the one time it prints.
function T.Welcome(saved, field, text)
    if saved[field] then return false end
    saved[field] = true
    T.Chat(text)
    return true
end

------------------------------------------------------------------------------
-- Confirm pop-up: a title, a text, a button that does it and Cancel. Nothing that reloads the
-- UI, logs out or can't be undone runs without one. `yes` is the text on the first button
-- (default "Confirm"); onNo is optional and runs on Cancel.
------------------------------------------------------------------------------
local confirmNames, confirmCount = {}, 0
local CONFIRM_PREFIX = "FURY_" .. string.upper((string.gsub(CHAT, " ", ""))) .. "_CONFIRM"

local function ConfirmYes(dialog)
    dialog.data.onYes()
end
local function ConfirmNo(dialog)
    if dialog.data.onNo then dialog.data.onNo() end
end

function T.Confirm(title, text, yes, onYes, onNo)
    yes = yes or GetString(SI_DIALOG_CONFIRM)
    local name = confirmNames[yes]
    if not name then
        -- one dialog per button text, made the first time it is needed
        confirmCount = confirmCount + 1
        name = CONFIRM_PREFIX .. confirmCount
        confirmNames[yes] = name
        ZO_Dialogs_RegisterCustomDialog(name, {
            gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
            title = { text = "<<1>>" },
            mainText = { text = "<<1>>" },
            buttons = {
                { text = yes, callback = ConfirmYes },
                { text = SI_DIALOG_CANCEL, callback = ConfirmNo },
            },
        })
    end
    ZO_Dialogs_ShowDialog(name, { onYes = onYes, onNo = onNo }, {
        titleParams = { title },
        mainTextParams = { text },
    })
end

------------------------------------------------------------------------------
-- Fonts (ESO's own faces only)
------------------------------------------------------------------------------
T.FONT_TITLE   = "$(ANTIQUE_FONT)|26|soft-shadow-thick"
T.FONT_SECTION = "$(ANTIQUE_FONT)|22|soft-shadow-thick"
T.FONT_FLOAT   = "$(ANTIQUE_FONT)|22|outline"          -- text drawn over the game world
T.FONT_HEADER  = "$(BOLD_FONT)|15|soft-shadow-thin"
T.FONT_BODY    = "ZoFontGame"
T.FONT_NUMBER  = "ZoFontWinH2"

local TITLE_BAR = 46   -- height of the glow behind the title; the accent line sits under it

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------
local function Paint(control, color)
    control:SetColor(color:UnpackRGBA())
end
T.Paint = Paint

-- Plain colored rectangle (a texture with no file draws as a solid block).
function T.Rect(name, parent, color, layer, level)
    local t = WINDOW_MANAGER:CreateControl(name, parent, CT_TEXTURE)
    t:SetDrawLayer(layer or DL_BACKGROUND)
    t:SetDrawLevel(level or 1)
    Paint(t, color)
    return t
end

-- Vertical fade from one color to another on a texture.
function T.Fade(texture, top, bottom)
    local r1, g1, b1, a1 = top:UnpackRGBA()
    local r2, g2, b2, a2 = bottom:UnpackRGBA()
    texture:SetColor(1, 1, 1, 1)
    texture:SetVertexColors(VERTEX_POINTS_TOPLEFT, r1, g1, b1, a1)
    texture:SetVertexColors(VERTEX_POINTS_TOPRIGHT, r1, g1, b1, a1)
    texture:SetVertexColors(VERTEX_POINTS_BOTTOMLEFT, r2, g2, b2, a2)
    texture:SetVertexColors(VERTEX_POINTS_BOTTOMRIGHT, r2, g2, b2, a2)
end

------------------------------------------------------------------------------
-- Window frame: opaque indigo-edged panel, title glow, accent line, glyph, Prose Antique title.
-- Call once after the XML is loaded. Options (all optional):
--   bg     name of the Backdrop child (default "Bg")
--   title  name of the title Label child (default "Title")
--   bar    height of the title area, where the violet line goes (default 46)
--   center true for a centered title (no glyph, title stays where the XML put it)
--   font   title font (default T.FONT_TITLE)
--   plain  true for colors and title font only: no glow, line or glyph (alerts and dialogs)
------------------------------------------------------------------------------
function T.Window(win, opts)
    opts = opts or {}
    local bar = opts.bar or TITLE_BAR

    local bg = win:GetNamedChild(opts.bg or "Bg")
    bg:SetDrawLayer(DL_BACKGROUND)
    bg:SetDrawLevel(0)
    bg:SetAlpha(1)
    bg:SetCenterColor(T.PANEL:UnpackRGBA())
    bg:SetEdgeColor(T.EDGE:UnpackRGBA())

    local title = win:GetNamedChild(opts.title or "Title")
    title:SetFont(opts.font or T.FONT_TITLE)
    if opts.plain then return end
    Paint(title, T.TEXT)

    local glow = T.Rect("$(parent)ThemeGlow", win, T.GLOW, DL_BACKGROUND, 1)
    glow:SetAnchor(TOPLEFT, win, TOPLEFT, 2, 2)
    glow:SetAnchor(BOTTOMRIGHT, win, TOPRIGHT, -2, bar)
    T.Fade(glow, T.GLOW, T.PANEL)

    local line = T.Rect("$(parent)ThemeLine", win, T.VIOLET, DL_BACKGROUND, 2)
    line:SetAnchor(TOPLEFT, win, TOPLEFT, 2, bar)
    line:SetAnchor(BOTTOMRIGHT, win, TOPRIGHT, -2, bar + 2)

    if opts.center then return end

    local glyph = WINDOW_MANAGER:CreateControl("$(parent)ThemeGlyph", win, CT_TEXTURE)
    glyph:SetTexture(GLYPH)
    glyph:SetDimensions(34, 34)
    glyph:SetAnchor(TOPLEFT, win, TOPLEFT, 12, 7)
    Paint(glyph, T.VIOLET)

    title:ClearAnchors()
    title:SetAnchor(LEFT, glyph, RIGHT, 6, 1)
end

-- Show or hide a row's hover highlight (a child texture named Highlight).
function T.RowHover(row, on)
    row:GetNamedChild("Highlight"):SetHidden(not on)
end

------------------------------------------------------------------------------
-- The same window header in every Fury addon, as in the Guild Toolset:
--   [glyph] Title  v1.2.3  [Start here]  . . .  [search]  [gear]  [X]
-- The version sits right after the title in muted violet, Start here right after the version,
-- the settings gear left of the close button, and every one of them has a hover tip.
------------------------------------------------------------------------------
T.VERSION_COLOR = "|c8A86B0"

T.FONT_VERSION = "$(MEDIUM_FONT)|13|soft-shadow-thin"

-- "Fury's Something  v1.2.3" in one text, the version muted (for places without a title bar).
function T.TitleText(text, version)
    return text .. "  " .. T.VERSION_COLOR .. "v" .. version .. "|r"
end

-- Sets a window's title, with its version in small print right after it (a label of its own,
-- `<window>FuryVersion`, sitting on the title's baseline). `name` is the Title label's child
-- name (default "Title").
function T.SetTitle(win, text, version, name)
    local label = win:GetNamedChild(name or "Title")
    local info = win.furyTitle
    if not info then
        local small = WINDOW_MANAGER:CreateControl(win:GetName() .. "FuryVersion", win, CT_LABEL)
        small:SetFont(T.FONT_VERSION)
        small:SetAnchor(BOTTOMLEFT, label, BOTTOMRIGHT, 8, -5)
        info = { versionLabel = small }
        win.furyTitle = info
    end
    info.label, info.text, info.version = label, text, version
    label:SetText(text)
    info.versionLabel:SetText(T.VERSION_COLOR .. "v" .. version .. "|r")
end

local function ShowTip(control, text)
    if not text or text == "" then return end
    InitializeTooltip(InformationTooltip, control, BOTTOM, 0, -4)
    SetTooltipText(InformationTooltip, text)
end
local function HideTip()
    ClearTooltip(InformationTooltip)
end
T.ShowTip, T.HideTip = ShowTip, HideTip

-- A hover tip on any control. `tip` is a text, or a function that returns one when the mouse comes in.
function T.Tip(control, tip)
    control:SetHandler("OnMouseEnter", function(self)
        if type(tip) == "function" then ShowTip(self, tip()) else ShowTip(self, tip) end
    end)
    control:SetHandler("OnMouseExit", HideTip)
end

-- The close button's tip, the same words everywhere.
function T.CloseTip(button, text)
    T.Tip(button, text or "Close (Esc)")
end

-- The settings gear, left of `anchorTo` (normally the close button).
function T.Gear(win, anchorTo, onClick, tip)
    local gear = WINDOW_MANAGER:CreateControl(win:GetName() .. "Gear", win, CT_BUTTON)
    gear:SetDimensions(32, 32)
    gear:SetAnchor(RIGHT, anchorTo, LEFT, -10, 0)
    gear:SetNormalTexture("/esoui/art/chatwindow/chat_options_up.dds")
    gear:SetPressedTexture("/esoui/art/chatwindow/chat_options_down.dds")
    gear:SetMouseOverTexture("/esoui/art/chatwindow/chat_options_over.dds")
    gear:SetHandler("OnClicked", onClick)
    T.Tip(gear, tip)
    return gear
end

-- How far right of the title label the Start here button starts: past the small version.
function T.StartOffset(win)
    local info = win.furyTitle
    if not info then return 14 end
    return 8 + info.versionLabel:GetTextWidth() + 14
end

-- The Start here button, right after the title and its version.
function T.StartButton(win, onClick, tip, title)
    local start = WINDOW_MANAGER:CreateControlFromVirtual(win:GetName() .. "StartHere", win, "ZO_DefaultButton")
    start:SetDimensions(110, 28)
    start:SetAnchor(LEFT, title or win:GetNamedChild("Title"), RIGHT, T.StartOffset(win), 0)
    start:SetDrawLayer(DL_CONTROLS)
    start:SetDrawLevel(1)
    start:SetText("Start here")
    start:SetHandler("OnClicked", onClick)
    T.Tip(start, tip)
    return start
end

------------------------------------------------------------------------------
-- Tabs: bold lavender words, white on hover, and the tab you are on is white with a violet
-- line under it. A tab is a plain button, so SetText, SetEnabled and OnClicked work as usual;
-- call T.TabActive to mark the one you are on.
------------------------------------------------------------------------------
T.FONT_TAB = "$(BOLD_FONT)|16|soft-shadow-thin"

function T.Tab(name, parent)
    local tab = WINDOW_MANAGER:CreateControl(name, parent, CT_BUTTON)
    tab:SetFont(T.FONT_TAB)
    tab:SetNormalFontColor(T.SUB:UnpackRGBA())
    tab:SetMouseOverFontColor(T.TEXT:UnpackRGBA())
    tab:SetPressedFontColor(T.TEXT:UnpackRGBA())
    tab:SetDisabledFontColor(T.TEXT:UnpackRGBA())
    local line = T.Rect(name .. "Line", tab, T.VIOLET, DL_CONTROLS, 2)
    line:SetAnchor(BOTTOMLEFT, tab, BOTTOMLEFT, 4, 0)
    line:SetAnchor(BOTTOMRIGHT, tab, BOTTOMRIGHT, -4, 0)
    line:SetHeight(3)
    line:SetHidden(true)
    tab.furyLine = line
    return tab
end

function T.TabActive(tab, active)
    tab:SetEnabled(not active)
    tab.furyLine:SetHidden(not active)
end

-- The thin indigo line the tabs sit on.
function T.TabLine(name, tabs)
    local line = T.Rect(name, tabs:GetParent(), T.EDGE, DL_BACKGROUND, 2)
    line:SetAnchor(TOPLEFT, tabs, BOTTOMLEFT, 0, 1)
    line:SetAnchor(TOPRIGHT, tabs, BOTTOMRIGHT, 0, 1)
    line:SetHeight(1)
    return line
end

------------------------------------------------------------------------------
-- More from Fury: the other public Fury addons, in the same words everywhere. Shown at the end
-- of a Start here page and of the settings page; the addon you are in is left out.
------------------------------------------------------------------------------
T.MORE_TITLE = "More from Fury"
T.MORE_FOOT = "All free on ESOUI and in Minion: search for \"Fury's\"."

local MORE = {
    { global = "FurysGuildToolset", name = "Fury's Guild Toolset", short = "Guild Toolset",
      about = "an officer's toolkit: bank alerts, member and inactivity reports, trader week totals, raffles, event sign-ups and recruiting.",
      url = "https://www.esoui.com/downloads/info5063.html" },
    { global = "FurysCharacterTracker", name = "Fury's Character Tracker", short = "Character Tracker",
      about = "every character on one board: skill lines, crafting, research, daily writs, wallet and gear.",
      url = "https://www.esoui.com/downloads/info5078.html" },
    { global = "FurysInventoryLedger", name = "Fury's Inventory Ledger", short = "Inventory Ledger",
      about = "every item you own in one list, across all your characters, the bank and your houses, with export to Excel.",
      url = "https://www.esoui.com/downloads/info5099.html" },
    { global = "FurysAccountSync", name = "Fury's Account Sync", short = "Account Sync",
      about = "make your other accounts on this PC match your main one: settings, keybinds, addon settings and builds.",
      url = "https://www.esoui.com/downloads/info5106.html" },
    { global = "FurysQualityOfLife", name = "Fury's Quality of Life", short = "Quality of Life",
      about = "small comforts for everyday play: Select all when you deconstruct, a fishing bite alert with the right bait, a queue alert and a lock for everything you wear.",
      url = "https://www.esoui.com/downloads/info5115.html" },
}

-- The other addons: { name, short, about, url } each.
function T.More()
    local list = {}
    for _, entry in ipairs(MORE) do
        if _G[entry.global] ~= A then list[#list + 1] = entry end
    end
    return list
end

-- One "Name: what it does" line per addon, then where to get them.
function T.MoreLines()
    local lines = {}
    for _, entry in ipairs(T.More()) do
        lines[#lines + 1] = entry.name .. ": " .. entry.about
    end
    lines[#lines + 1] = T.MORE_FOOT
    return lines
end

-- Adds the section to the end of a LibAddonMenu options list: the lines, and a button per addon
-- that opens its ESOUI page (the game asks before it opens a web page).
function T.MoreOptions(options)
    options[#options + 1] = { type = "header", name = T.MORE_TITLE }
    options[#options + 1] = { type = "description", text = table.concat(T.MoreLines(), "\n") }
    for _, entry in ipairs(T.More()) do
        local function Open() RequestOpenUnsafeURL(entry.url) end
        options[#options + 1] = { type = "button", name = entry.short, width = "half", func = Open,
            tooltip = "Opens the ESOUI page of " .. entry.name .. " in your web browser. The game asks first." }
    end
end

------------------------------------------------------------------------------
-- Start here page: a window (from the addon's StartHere.xml) with numbered sections.
-- sections = { { title = "1. ...", lines = { "...", "..." } }, ... }
------------------------------------------------------------------------------
function T.FillStartPage(win, intro, sections)
    local child = win:GetNamedChild("Body"):GetNamedChild("ScrollChild")
    local width = win:GetWidth() - 64
    local prefix = win:GetName() .. "Line"
    local index, previous = 0, nil
    local function Add(text, font, color, gap)
        index = index + 1
        local label = WINDOW_MANAGER:GetControlByName(prefix .. index) or WINDOW_MANAGER:CreateControl(prefix .. index, child, CT_LABEL)
        label:SetWidth(width)
        label:SetFont(font)
        Paint(label, color)
        label:SetText(text)
        label:ClearAnchors()
        if previous then
            label:SetAnchor(TOPLEFT, previous, BOTTOMLEFT, 0, gap)
        else
            label:SetAnchor(TOPLEFT, child, TOPLEFT, 0, 0)
        end
        previous = label
    end
    if intro then Add(intro, "ZoFontGame", T.SUB, 0) end
    for _, section in ipairs(sections) do
        Add(section.title, T.FONT_SECTION, T.BLUE, previous and 16 or 0)
        for _, line in ipairs(section.lines) do
            Add(line, "ZoFontGame", T.TEXT, 6)
        end
    end
    Add(T.MORE_TITLE, T.FONT_SECTION, T.BLUE, 16)
    for _, line in ipairs(T.MoreLines()) do
        Add(line, "ZoFontGame", T.SUB, 6)
    end
end

-- Opens a Start here page. The first time, it is painted, filled and registered so Esc closes it.
function T.StartPage(win, intro, sections)
    if not win.furyReady then
        win.furyReady = true
        T.Window(win)
        T.CloseTip(win:GetNamedChild("Close"))
        T.FillStartPage(win, intro, sections)
        SCENE_MANAGER:RegisterTopLevel(win, false)
    end
    SCENE_MANAGER:ShowTopLevel(win)
end

------------------------------------------------------------------------------
-- The Fury sidebar and the Fury addons list.
--
-- The sidebar is a slim bar of icons, one per Fury addon you have installed, that can stay on
-- screen, as a column or a row: left-click an icon to open that addon, right-click for its
-- settings. Drag it by its violet line. /fury shows or hides it, and so does the key "Show or hide the Fury sidebar" under
-- Fury's Addons in Controls > Keybindings. It starts turned off.
--
-- The list (/fury menu, or the gear at the bottom of the sidebar) is a small window with every
-- installed Fury addon, an Open and a Settings button each, and the sidebar's options.
--
-- The key and the sidebar's saved settings live in the small FurysAddonMenu folder that ships
-- inside every Fury addon; the game loads the folder once, so the key shows once however many
-- Fury addons are installed. Each addon's copy of this file puts that addon on the shared list
-- (FurysAddonMenu.entries), so an addon never has to know the names of the others. The newest
-- copy of this file among the installed addons builds the sidebar and the list.
------------------------------------------------------------------------------
local MENU_GLOBAL = "FurysAddonMenu"
local MENU_WIDTH, MENU_ROW = 600, 40
local MENU_HELP = "Type /fury, or press the key (Controls > Keybindings > Fury's Addons), to show or hide the sidebar. /fury menu opens this window."
local BAR_NAME = "Fury's Addons"
-- Sidebar sizes: small (the default, about the size of other sidebars) and big. Icon, gap, grip.
local BAR_SMALL = { icon = 28, pad = 2, grip = 12 }
local BAR_BIG = { icon = 40, pad = 5, grip = 12 }
local BAR_FALLBACK = "EsoUI/Art/MainMenu/menuBar_collections_up.dds"

local shared = rawget(_G, MENU_GLOBAL)
if not shared then
    shared = { entries = {}, lib = 0 }
    _G[MENU_GLOBAL] = shared
end
shared.entries[MENU_NAME] = { name = MENU_NAME, open = MenuOpen, settings = MenuSettings, glyph = GLYPH }

-- The sidebar's settings. The FurysAddonMenu folder saves them; without it they last until the
-- next reload.
local function BarSaved()
    if not shared.sv then shared.sv = {} end
    return shared.sv
end

local function SortedNames()
    local names = {}
    for name in pairs(shared.entries) do names[#names + 1] = name end
    table.sort(names)
    return names
end

local function MenuButton(name, win, text, tip, onClick)
    local button = WINDOW_MANAGER:CreateControlFromVirtual(name, win, "ZO_DefaultButton")
    button:SetDimensions(110, 28)
    button:SetText(text)
    button:SetHandler("OnClicked", onClick)
    T.Tip(button, tip)
    return button
end

-- Lays the sidebar out as a column (the grip line across the top) or, with `across`, as a row
-- (the grip line down the left end), with small or big icons.
local function LayoutBar(across, big)
    local size = big and BAR_BIG or BAR_SMALL
    local BAR_ICON, BAR_PAD, BAR_GRIP = size.icon, size.pad, size.grip
    local bar, step = shared.bar, BAR_ICON + BAR_PAD
    local count = #shared.barIcons
    local long, short = BAR_GRIP + (count + 1) * step + BAR_PAD, BAR_ICON + 2 * BAR_PAD
    shared.barGrip:ClearAnchors()
    if across then
        bar:SetDimensions(long, short)
        shared.barGrip:SetAnchor(TOPLEFT, bar, TOPLEFT, BAR_PAD, BAR_PAD)
        shared.barGrip:SetAnchor(BOTTOMRIGHT, bar, BOTTOMLEFT, BAR_PAD + 3, -BAR_PAD)
    else
        bar:SetDimensions(short, long)
        shared.barGrip:SetAnchor(TOPLEFT, bar, TOPLEFT, BAR_PAD, BAR_PAD)
        shared.barGrip:SetAnchor(BOTTOMRIGHT, bar, TOPRIGHT, -BAR_PAD, BAR_PAD + 3)
    end
    for i = 1, count + 1 do
        local icon = shared.barIcons[i] or shared.barGear
        local edge = icon == shared.barGear and BAR_ICON - 6 or BAR_ICON
        local at = BAR_GRIP + (i - 1) * step + (BAR_ICON - edge) / 2
        icon:SetDimensions(edge, edge)
        icon:ClearAnchors()
        if across then
            icon:SetAnchor(LEFT, bar, LEFT, at, 0)
        else
            icon:SetAnchor(TOP, bar, TOP, 0, at)
        end
    end
end

-- Puts the saved settings on the sidebar: shown or not, where, which way, movable or locked.
local function ApplyBar()
    local bar, saved = shared.bar, BarSaved()
    if not bar then return end
    LayoutBar(saved.across == true, saved.big == true)
    bar:SetMovable(not saved.locked)
    shared.barFragment:SetHiddenForReason("off", not saved.shown)
    shared.barFragment:SetHiddenForReason("combat", saved.combat == true and IsUnitInCombat("player"))
    -- The icons can only be clicked with the cursor out, so the sidebar shows in cursor mode only,
    -- unless the player asks to see it all the time.
    if saved.always == true then
        HUD_SCENE:AddFragment(shared.barFragment)
    else
        HUD_SCENE:RemoveFragment(shared.barFragment)
    end
end

local function ToggleMenu()   -- set below, the sidebar's gear needs it
end

local function BuildBar()
    local saved = BarSaved()
    local names = SortedNames()
    local bar = WINDOW_MANAGER:CreateTopLevelWindow("FurysAddonMenuBar")
    bar:SetHidden(true)
    bar:SetMouseEnabled(true)
    bar:SetClampedToScreen(true)
    if saved.x and saved.y then
        bar:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, saved.x, saved.y)
    else
        bar:SetAnchor(LEFT, GuiRoot, LEFT, 20, 0)
    end
    bar:SetHandler("OnMoveStop", function(self)
        local now = BarSaved()
        now.x, now.y = self:GetLeft(), self:GetTop()
    end)

    local bg = WINDOW_MANAGER:CreateControl("$(parent)Bg", bar, CT_BACKDROP)
    bg:SetAnchorFill(bar)
    bg:SetEdgeTexture("", 1, 1, 2, 0)
    bg:SetCenterColor(T.PANEL.r, T.PANEL.g, T.PANEL.b, 0.85)
    bg:SetEdgeColor(T.EDGE:UnpackRGBA())

    -- The grip: a violet line. It takes no clicks, so a drag there moves the bar.
    shared.barGrip = T.Rect("$(parent)Grip", bar, T.VIOLET, DL_CONTROLS, 1)
    shared.barIcons = {}

    for i, name in ipairs(names) do
        local entry = shared.entries[name]
        local glyph = entry.glyph or BAR_FALLBACK
        local icon = WINDOW_MANAGER:CreateControl("$(parent)Icon" .. i, bar, CT_BUTTON)
        icon:SetNormalTexture(glyph)
        icon:SetMouseOverTexture((string.gsub(glyph, "_up.dds", "_over.dds")))
        icon:EnableMouseButton(MOUSE_BUTTON_INDEX_RIGHT, true)
        icon:SetHandler("OnClicked", function(_, button)
            if button == MOUSE_BUTTON_INDEX_RIGHT then entry.settings() else entry.open() end
        end)
        T.Tip(icon, name .. "\nLeft-click: open. Right-click: settings.")
        shared.barIcons[i] = icon
    end

    local gear = WINDOW_MANAGER:CreateControl("$(parent)Gear", bar, CT_BUTTON)
    gear:SetNormalTexture("/esoui/art/chatwindow/chat_options_up.dds")
    gear:SetPressedTexture("/esoui/art/chatwindow/chat_options_down.dds")
    gear:SetMouseOverTexture("/esoui/art/chatwindow/chat_options_over.dds")
    gear:SetHandler("OnClicked", function() shared.Menu() end)
    T.Tip(gear, "The Fury addons list and this sidebar's options: lock it in place, a row or a column, big or small icons, hide it in combat, keep it on screen without the cursor, turn it off.\nTo move the sidebar, drag its violet line. /fury shows or hides it.")

    shared.barGear = gear
    shared.bar = bar
    shared.barFragment = ZO_HUDFadeSceneFragment:New(bar)
    HUD_UI_SCENE:AddFragment(shared.barFragment)
    EVENT_MANAGER:RegisterForEvent("FurysAddonMenuBar", EVENT_PLAYER_COMBAT_STATE, ApplyBar)
    ApplyBar()
end

-- Builds the sidebar once, when the first character is in the world and every Fury addon is on
-- the list.
local function StartBar()
    if not shared.bar then BuildBar() end
end

local function RefreshChecks()
    if not shared.checks then return end
    local saved = BarSaved()
    ZO_CheckButton_SetCheckState(shared.checks.shown, saved.shown == true)
    ZO_CheckButton_SetCheckState(shared.checks.locked, saved.locked == true)
    ZO_CheckButton_SetCheckState(shared.checks.combat, saved.combat == true)
    ZO_CheckButton_SetCheckState(shared.checks.across, saved.across == true)
    ZO_CheckButton_SetCheckState(shared.checks.big, saved.big == true)
    ZO_CheckButton_SetCheckState(shared.checks.always, saved.always == true)
end

local function ToggleBar()
    StartBar()
    local saved = BarSaved()
    saved.shown = not saved.shown
    ApplyBar()
    RefreshChecks()
    if saved.shown then
        T.ChatAs(BAR_NAME, "Sidebar on. It shows whenever your cursor is out. Left-click an icon to open that addon, right-click for its settings. Drag its violet line to move it. /fury hides it again.")
    else
        T.ChatAs(BAR_NAME, "Sidebar off. /fury shows it again; /fury menu opens the list of your Fury addons.")
    end
end

local function MenuCheck(name, win, y, text, tip, field)
    local check = WINDOW_MANAGER:CreateControlFromVirtual(name, win, "ZO_CheckButton")
    check:SetAnchor(TOPLEFT, win, TOPLEFT, 22, y)
    ZO_CheckButton_SetLabelText(check, text)
    ZO_CheckButton_SetToggleFunction(check, function(_, checked)
        StartBar()
        BarSaved()[field] = checked
        ApplyBar()
    end)
    T.Tip(check, tip)
    return check
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
    title:SetText(BAR_NAME)

    local close = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)Close", win, "ZO_CloseButton")
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -12, 12)
    close:SetHandler("OnClicked", function() SCENE_MANAGER:HideTopLevel(win) end)
    T.CloseTip(close)

    T.Window(win, { center = true })

    local names = SortedNames()
    for i, name in ipairs(names) do
        local entry = shared.entries[name]
        local y = 62 + (i - 1) * MENU_ROW
        local label = WINDOW_MANAGER:CreateControl("$(parent)Name" .. i, win, CT_LABEL)
        label:SetFont("ZoFontWinH4")
        Paint(label, T.TEXT)
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
    shared.checks = {
        shown = MenuCheck("$(parent)BarShown", win, y, "Show the sidebar",
            "A slim bar of icons, one per Fury addon, that shows whenever your cursor is out. Left-click an icon to open that addon, right-click for its settings. Starts turned off. /fury and the key do the same as this box.", "shown"),
        locked = MenuCheck("$(parent)BarLocked", win, y + 84, "Lock the sidebar in place",
            "With this on, the sidebar can't be dragged. Off: drag its violet line to move it.", "locked"),
        combat = MenuCheck("$(parent)BarCombat", win, y + 112, "Hide the sidebar in combat",
            "With this on, the sidebar is hidden while you are in combat and comes back afterwards.", "combat"),
        across = MenuCheck("$(parent)BarAcross", win, y + 28, "Horizontal sidebar (a row of icons)",
            "With this on, the icons sit side by side in a row. Off: they are stacked in a column.", "across"),
        big = MenuCheck("$(parent)BarBig", win, y + 56, "Bigger sidebar icons",
            "With this on, the sidebar's icons are bigger and further apart. Off: a slim sidebar with small icons.", "big"),
        always = MenuCheck("$(parent)BarAlways", win, y + 140, "Show the sidebar without the cursor too",
            "Off: the sidebar shows only while your cursor is out, which is when you can click it. With this on, it also stays on screen while you play without the cursor.", "always"),
    }

    local help = WINDOW_MANAGER:CreateControl("$(parent)Help", win, CT_LABEL)
    help:SetFont("ZoFontGameSmall")
    Paint(help, T.SUB)
    help:SetWidth(MENU_WIDTH - 40)
    help:SetText(MENU_HELP)
    help:SetAnchor(TOPLEFT, win, TOPLEFT, 20, y + 174)

    win:SetDimensions(MENU_WIDTH, y + 174 + 52)
    SCENE_MANAGER:RegisterTopLevel(win, false)
    return win
end

ToggleMenu = function()
    if not shared.window then shared.window = BuildMenu() end
    if shared.window:IsHidden() then
        RefreshChecks()
        SCENE_MANAGER:ShowTopLevel(shared.window)
    else
        SCENE_MANAGER:HideTopLevel(shared.window)
    end
end

-- The newest copy of this file among the installed addons runs the sidebar and the list.
if shared.lib < T.LIB then
    shared.lib = T.LIB
    shared.Toggle = ToggleBar
    shared.Menu = ToggleMenu
    shared.Start = StartBar
end
SLASH_COMMANDS["/fury"] = function(text)
    if zo_strlower(zo_strtrim(text or "")) == "menu" then shared.Menu() else shared.Toggle() end
end

local BAR_EVENT = CONFIRM_PREFIX .. "_BAR"
EVENT_MANAGER:RegisterForEvent(BAR_EVENT, EVENT_PLAYER_ACTIVATED, function()
    EVENT_MANAGER:UnregisterForEvent(BAR_EVENT, EVENT_PLAYER_ACTIVATED)
    shared.Start()
end)

------------------------------------------------------------------------------
-- The other Fury addons in a window's title bar: a row of small icons, one per other Fury addon
-- you have installed, so any of them is one click away. Left-click opens that addon, right-click
-- its settings. It is built
-- the first time the window shows, when every installed Fury addon is on the list.
------------------------------------------------------------------------------
local TITLE_ICON, TITLE_GAP = 30, 2

-- The row sits on the left, between the window's name and its version:
--   [glyph] Title  [icons]  v1.2.3  [Start here]  . . .  [search]  [gear]  [X]
-- `rightOf` is the leftmost control on the right side of the title bar and `reserve` is extra
-- width to keep free left of it (for controls that only show on some tabs). Icons that would
-- push Start here into that space are left out. `start` is the Start here button, when the
-- window has one that T.StartButton did not make.
function T.TitleIcons(win, rightOf, start, reserve)
    local built = false
    local function Build()
        if built then return end
        built = true
        local info = win.furyTitle
        if not info then return end
        local others = {}
        for _, name in ipairs(SortedNames()) do
            if name ~= MENU_NAME then others[#others + 1] = name end
        end
        start = start or win:GetNamedChild("StartHere")
        local left = start or info.label
        local room = rightOf:GetLeft() - (reserve or 0) - left:GetRight() - 24
        local count = math.min(#others, math.floor(room / (TITLE_ICON + TITLE_GAP)))
        if count < 1 then return end

        local previous = info.label
        for i = 1, count do
            local name = others[i]
            local entry = shared.entries[name]
            local glyph = entry.glyph or BAR_FALLBACK
            local icon = WINDOW_MANAGER:CreateControl(win:GetName() .. "FuryIcon" .. i, win, CT_BUTTON)
            icon:SetDimensions(TITLE_ICON, TITLE_ICON)
            icon:SetAnchor(LEFT, previous, RIGHT, i == 1 and 10 or TITLE_GAP, 0)
            icon:SetDrawLayer(DL_CONTROLS)
            icon:SetDrawLevel(1)
            icon:SetNormalTexture(glyph)
            icon:SetMouseOverTexture((string.gsub(glyph, "_up.dds", "_over.dds")))
            icon:EnableMouseButton(MOUSE_BUTTON_INDEX_RIGHT, true)
            icon:SetHandler("OnClicked", function(_, button)
                if button == MOUSE_BUTTON_INDEX_RIGHT then entry.settings() else entry.open() end
            end)
            T.Tip(icon, name .. "\nLeft-click: open. Right-click: settings.")
            previous = icon
        end

        -- The version moves to the right of the icons, still on the title's baseline; Start
        -- here follows it.
        local version = info.versionLabel
        version:ClearAnchors()
        version:SetAnchor(BOTTOMLEFT, previous, BOTTOMRIGHT, 8, -3)
        if start then
            start:ClearAnchors()
            start:SetAnchor(LEFT, info.label, RIGHT, 10 + count * (TITLE_ICON + TITLE_GAP) - TITLE_GAP + T.StartOffset(win), 0)
        end
    end
    ZO_PreHookHandler(win, "OnEffectivelyShown", Build)
    if not win:IsHidden() then Build() end
end
