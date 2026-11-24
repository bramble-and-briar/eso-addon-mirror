-- Fury Night: the shared look for Fury's addons.
-- The same file ships in each addon; only the first two lines differ, so it hangs off that
-- addon's own table and adds no globals of its own.

local A = FurysInventoryLedger
local GLYPH = "EsoUI/Art/MainMenu/menuBar_inventory_up.dds"

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
T.GOOD   = ZO_ColorDef:New("5EE6A0")
T.WARN   = ZO_ColorDef:New("FFC857")
T.BAD    = ZO_ColorDef:New("FF6B86")
T.GOLD   = ZO_ColorDef:New("F2C94C")   -- gold amounts only

T.TAG = "|cA08CFF"                     -- chat prefix color

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
-- Expects children named Bg (Backdrop) and Title (Label). Call once after the XML is loaded.
------------------------------------------------------------------------------
function T.Window(win)
    local bg = win:GetNamedChild("Bg")
    bg:SetDrawLayer(DL_BACKGROUND)
    bg:SetDrawLevel(0)
    bg:SetCenterColor(T.PANEL:UnpackRGBA())
    bg:SetEdgeColor(T.EDGE:UnpackRGBA())

    local glow = T.Rect("$(parent)ThemeGlow", win, T.GLOW, DL_BACKGROUND, 1)
    glow:SetAnchor(TOPLEFT, win, TOPLEFT, 2, 2)
    glow:SetAnchor(BOTTOMRIGHT, win, TOPRIGHT, -2, TITLE_BAR)
    T.Fade(glow, T.GLOW, T.PANEL)

    local line = T.Rect("$(parent)ThemeLine", win, T.VIOLET, DL_BACKGROUND, 2)
    line:SetAnchor(TOPLEFT, win, TOPLEFT, 2, TITLE_BAR)
    line:SetAnchor(BOTTOMRIGHT, win, TOPRIGHT, -2, TITLE_BAR + 2)

    local glyph = WINDOW_MANAGER:CreateControl("$(parent)ThemeGlyph", win, CT_TEXTURE)
    glyph:SetTexture(GLYPH)
    glyph:SetDimensions(34, 34)
    glyph:SetAnchor(TOPLEFT, win, TOPLEFT, 12, 7)
    Paint(glyph, T.VIOLET)

    local title = win:GetNamedChild("Title")
    title:ClearAnchors()
    title:SetAnchor(LEFT, glyph, RIGHT, 6, 1)
    title:SetFont(T.FONT_TITLE)
    Paint(title, T.TEXT)
end
