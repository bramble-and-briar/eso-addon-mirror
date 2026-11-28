-- Fury Night: the shared library of Fury's addons. Look (colors, fonts, window header, tabs,
-- Start here page), chat lines, the welcome line, saved settings, confirm pop-ups, "More from Fury" and this
-- addon's place in the Fury sidebar. The same file ships in every Fury addon, so they all
-- look and behave the same. Only the six lines below differ: it hangs off that addon's own table,
-- so no Fury addon depends on another Fury addon being installed. The Fury sidebar itself comes
-- from the library Fury's Addons Menu (FurysAddonMenu), which every Fury addon requires.

local A = FurysQualityOfLife
local GLYPH = "EsoUI/Art/Crafting/enchantment_tabIcon_deconstruction_up.dds"
local CHAT = "Quality of Life"   -- the name in front of this addon's chat lines
local MENU_NAME = "Fury's Quality of Life"   -- this addon's line in the Fury addons menu
local function MenuOpen() A.ShowStart() end
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
T.LIB = 16

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

-- Saved settings, the standard way: call it in the addon's EVENT_ADD_ON_LOADED (never before) with
-- the name from the manifest's ## SavedVariables line. One set for the whole PC, as before.
-- Builds up to November 2026 kept their settings at the top of the file: they are moved into
-- place the first time, so nothing is lost. The second result is true on a brand-new install.
function T.SavedVars(svName)
    local old = _G[svName]
    local newInstall = old == nil or next(old) == nil
    local saved = ZO_SavedVars:NewAccountWide(svName, 1, nil, nil, nil, "$AllAccounts")
    if old then
        for key, value in pairs(old) do
            if key ~= "Default" then
                if key == "version" then saved.dataVersion = value else saved[key] = value end
                old[key] = nil
            end
        end
    end
    return saved, newInstall
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
-- The Fury sidebar, the Fury addons list (/fury) and the other Fury addons' icons in each window's
-- title bar live in the library Fury's Addons Menu (FurysAddonMenu), which every Fury addon
-- requires. This addon only puts itself on its list.
------------------------------------------------------------------------------
FurysAddonMenu:Register({ name = MENU_NAME, glyph = GLYPH, open = MenuOpen, settings = MenuSettings })

-- The other installed Fury addons as a row of small icons in a window's title bar, between its
-- name and its version. `rightOf` is the leftmost control on the right side of the title bar,
-- `reserve` extra width to keep free left of it, `start` the Start here button when T.StartButton
-- did not make it. Call it after T.SetTitle.
function T.TitleIcons(win, rightOf, start, reserve)
    local info = win.furyTitle
    FurysAddonMenu:TitleIcons(win, {
        skip = MENU_NAME,
        label = info.label,
        version = info.versionLabel,
        rightOf = rightOf,
        reserve = reserve,
        start = start,
    })
end
