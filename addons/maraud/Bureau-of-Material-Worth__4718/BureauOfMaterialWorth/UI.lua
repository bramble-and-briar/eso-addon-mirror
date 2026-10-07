local addon = BureauOfMaterialWorth
local private = addon.private

-- Shared visual language
-- ---------------------------------------------------------------------------
-- Three surfaces are drawn by this addon: the summary panel beside the Craft Bag
-- (Window.lua), the material table (DetailWindow.lua) and the withdraw window
-- (WithdrawDialog.lua). Each one used to carry its own copy of the chrome --
-- backdrop tint, border colour, divider alpha, title font, row-hover wash -- and
-- those copies had drifted: three different background opacities, two different
-- tooltip title fonts, dividers at one weight in one file and another elsewhere,
-- and every tooltip line colour hand-written as a normalized RGB triple that no
-- longer matched the hex palette it was converted from.
--
-- This module is the single source of truth for all of it. It holds the design
-- tokens (colour, type scale, spacing, chrome) and the small builders that apply
-- them, so a window file describes WHAT it is drawing and never re-decides HOW
-- the addon looks. Changing a token here restyles every window at once.
--
-- Loaded after the core (it reads private.COLOR_*) and before the window files.
local UI = {}
private.UI = UI

local tonumber = tonumber
local stringsub = string.sub
local unpack = unpack

-- Colour
-- ---------------------------------------------------------------------------
-- The palette itself stays in the core as hex strings, because most of the
-- addon's colouring happens inside text via inline |c codes. Controls, however,
-- are tinted with normalized RGB components. Converting here -- rather than
-- writing the triples out by hand at each call site -- is what keeps a control's
-- tint and a label's |c code the same colour, which is exactly what had drifted.
function UI.HexToRGB(hex)
    local r = (tonumber(stringsub(hex, 1, 2), 16) or 0) / 255
    local g = (tonumber(stringsub(hex, 3, 4), 16) or 0) / 255
    local b = (tonumber(stringsub(hex, 5, 6), 16) or 0) / 255
    return r, g, b
end

-- Named tones, in the order they matter: the brand accent, the reading tones for
-- primary and secondary text, then the three semantic signals (gold figures, a
-- warning, and the gain/loss pair).
UI.HEX = {
    accent = private.COLOR_ACCENT,
    name   = private.COLOR_NAME,
    soft   = private.COLOR_SOFT,
    muted  = private.COLOR_MUTED,
    gold   = private.COLOR_GOLD,
    warn   = private.COLOR_WARN,
    gain   = private.COLOR_GAIN,
    loss   = private.COLOR_LOSS,
    brass  = "BCA779",
}

-- The same tones as { r, g, b } triples, derived once at load. Anything that
-- calls SetColor / SetCenterColor / AddLine reads from here.
UI.RGB = {}
for tone, hex in pairs(UI.HEX) do
    local r, g, b = UI.HexToRGB(hex)
    UI.RGB[tone] = { r, g, b }
end

-- Resolve a tone name to r, g, b. Falls back to the primary reading tone so a
-- typo degrades to legible text instead of an invisible or black label.
function UI.Tone(tone)
    local rgb = UI.RGB[tone] or UI.RGB.name
    return rgb[1], rgb[2], rgb[3]
end

-- Type scale
-- ---------------------------------------------------------------------------
-- Five steps, and deliberately no more: a window title, a section heading, the
-- sub-heading used by tooltip titles, body text, and the small size used by
-- captions, column headers and footers. Every label in the addon picks one of
-- these instead of naming a ZoFont directly, so the three windows share one
-- rhythm and a change of scale is a change in one table.
UI.FONT = {
    hero    = "ZoFontWinH1",   -- the grand total, and nothing else
    title   = "ZoFontWinH3",   -- window titles
    heading = "ZoFontWinH4",   -- section headings
    subhead = "ZoFontWinH5",   -- tooltip titles
    body    = "ZoFontGame",    -- rows, values, inputs
    small   = "ZoFontGameSmall", -- captions, column headers, footers
}

-- Spacing
-- ---------------------------------------------------------------------------
-- One 4px-based rhythm shared by all three windows. The summary panel is narrow
-- and uses PADDING; the two free-floating windows have more room and use
-- PADDING_WIDE, but every internal gap comes from this scale.
UI.METRIC = {
    PADDING      = 16,
    PADDING_WIDE = 16,
    GAP_TIGHT    = 4,
    GAP          = 8,
    GAP_WIDE     = 12,
    RULE_HEIGHT  = 4,   -- the divider texture's natural height
    ACCENT_RULE  = 1,
    BAND_PAD     = 6,   -- air between a header band's edge and its text
    -- How far a selection outline sits outside the control it marks. Negative
    -- insets on a CT_BACKDROP grow the frame, so the ring reads as around the
    -- button rather than as a border drawn on top of its own edge.
    SELECT_BLEED = 1,
}

-- Chrome
-- ---------------------------------------------------------------------------
-- The panel shell. A near-black, very slightly blue-cool ground reads as "UI
-- surface" against Tamriel's warm scenery, and the warm stone border ties it to
-- the game's own frames. HEADER_BAND is a barely-there accent wash that gives
-- every window the same letterhead: a tinted strip behind the title, closed by
-- an accent underline. ROW_HOVER is the same accent at a lower alpha, so
-- pointing at a row and reading a title feel like the same surface.
UI.CHROME = {
    BG          = { 0.067, 0.075, 0.075 },
    BG_ALPHA    = 0.96,
    -- The one sanctioned deviation from BG_ALPHA: a window that takes typed input
    -- (the withdraw quantity) must not let a busy scene bleed through the digits,
    -- so it reads a little more solid. A token rather than a local constant in
    -- that file, so "more solid" means the same thing everywhere it is claimed.
    BG_ALPHA_SOLID = 0.98,
    EDGE        = { 0.737, 0.655, 0.475 },
    EDGE_ALPHA  = 0.42,
    INSET       = 1,
    HEADER_BAND = { 0.737, 0.655, 0.475, 0.065 },
    ACCENT_LINE = { 0.737, 0.655, 0.475, 0.48 },
    ROW_HOVER   = { 0.439, 0.773, 0.741, 0.12 },
    CATEGORY_SHARE = { 0.439, 0.773, 0.741, 0.38 },
    BADGE       = { 1, 1, 1, 0.055 },
    -- The accent at near-full strength: what a marker is drawn at when it must
    -- read as a hard edge rather than a wash -- the ring around the active filter
    -- button, the tick beside the leading category. Above ACCENT_LINE, because a
    -- mark points at one thing while an underline only closes a band.
    ACCENT_MARK = 0.95,
    ROW_ZEBRA   = { 1, 1, 1, 0.025 },
    TRACK       = { 1, 1, 1, 0.07 },
    RULE_STRONG = 0.24,
    RULE_SOFT   = 0.12,
}

local DIVIDER_TEXTURE = "EsoUI/Art/Miscellaneous/horizontalDivider.dds"

-- Apply the shared panel shell to a CT_BACKDROP that fills a top-level window.
-- `opts.background` / `opts.border` allow either layer to be switched off (the
-- summary panel exposes both as settings); `opts.alpha` overrides the default
-- opacity for a window that must read as more solid, e.g. one that takes typed
-- input over a busy scene.
function UI.ApplyPanelChrome(backdrop, opts)
    opts = opts or {}
    local chrome = UI.CHROME

    backdrop:SetEdgeTexture("", 1, 1, 1)
    backdrop:SetInsets(chrome.INSET, chrome.INSET, -chrome.INSET, -chrome.INSET)

    if opts.background == false then
        backdrop:SetCenterColor(0, 0, 0, 0)
    else
        backdrop:SetCenterColor(chrome.BG[1], chrome.BG[2], chrome.BG[3],
            opts.alpha or chrome.BG_ALPHA)
    end

    if opts.border == false then
        backdrop:SetEdgeColor(0, 0, 0, 0)
    else
        backdrop:SetEdgeColor(chrome.EDGE[1], chrome.EDGE[2], chrome.EDGE[3],
            chrome.EDGE_ALPHA)
    end
end

-- A flat colour rectangle. CT_BACKDROP with a transparent edge is the addon's
-- only way to draw a plain fill (there is no solid-colour texture we can rely
-- on), and it is already how the value-history chart draws its bars -- so bands,
-- underlines, hover washes, zebra stripes and meter tracks all use it too.
-- Strip a CT_BACKDROP down to a bare rectangle: no edge, no insets. Both the
-- fills this module creates and the ones declared in DetailWindow.xml (a list row
-- template must be markup) have to be flattened the same way, so the "how" lives
-- here once instead of being re-derived at a call site.
local function FlattenBackdrop(backdrop)
    backdrop:SetEdgeTexture("", 1, 1, 1)
    backdrop:SetEdgeColor(0, 0, 0, 0)
    backdrop:SetInsets(0, 0, 0, 0)
end

function UI.CreateFill(name, parent, color)
    local fill = WINDOW_MANAGER:CreateControl(name, parent, CT_BACKDROP)
    FlattenBackdrop(fill)
    fill:SetCenterColor(unpack(color))
    fill:SetMouseEnabled(false)
    return fill
end

-- Re-tint an existing fill. The value-history chart repaints its pooled bars on
-- every refresh (the whole silhouette switches between the gain and loss tone),
-- so the { r, g, b, a } tables the palette hands out are unpacked here rather
-- than component-by-component at the call site.
function UI.PaintFill(fill, color)
    fill:SetCenterColor(unpack(color))
end

function UI.ApplyField(backdrop)
    FlattenBackdrop(backdrop)
    backdrop:SetInsets(1, 1, -1, -1)
    backdrop:SetCenterColor(0, 0, 0, 0.32)
    backdrop:SetEdgeColor(1, 1, 1, 0.16)
end

function UI.RowHeight(surface)
    local compact = private.savedVars and private.savedVars.uiDensity == "compact"
    if surface == "category" then
        return compact and 24 or 30
    elseif surface == "queue" then
        return compact and 28 or 34
    end
    return compact and 26 or 32
end

local function PaintButtonText(button, method, tone, alpha)
    local r, g, b = UI.Tone(tone)
    button[method](button, r, g, b, alpha or 1)
end

function UI.PaintButton(button)
    local plate = button.bmwPlate
    if not plate then
        return
    end
    local disabled = button:GetState() == BSTATE_DISABLED
        or button:GetState() == BSTATE_DISABLED_PRESSED
    local active = not disabled and (button.bmwSelected or button.bmwHovered)
    local primary = button.bmwStyle == "primary"
    local r, g, b = UI.Tone((active or primary) and "accent" or "name")
    plate:SetCenterColor(r, g, b, active and 0.18 or (primary and 0.12 or 0.035))
    plate:SetAlpha(disabled and 0.35 or 1)
    PaintButtonText(button, "SetNormalFontColor",
        (button.bmwSelected or primary) and "accent" or "soft")
    if button.bmwUnderline then
        button.bmwUnderline:SetHidden(not button.bmwSelected)
    end
end

function UI.SelectButton(button, selected)
    button.bmwSelected = selected
    UI.PaintButton(button)
end

function UI.ApplyButton(button, style)
    if button.bmwPlate then
        return
    end
    button.bmwStyle = style
    button:SetFont(UI.FONT.small)
    button:SetNormalTexture("")
    button:SetMouseOverTexture("")
    button:SetPressedTexture("")
    button:SetPressedMouseOverTexture("")
    button:SetDisabledTexture("")
    button:SetDisabledPressedTexture("")
    button:SetNormalOffset(0, 0)
    button:SetPressedOffset(0, 0)
    PaintButtonText(button, "SetMouseOverFontColor", "name")
    PaintButtonText(button, "SetPressedFontColor", "accent")
    PaintButtonText(button, "SetDisabledFontColor", "muted", 0.65)
    PaintButtonText(button, "SetDisabledPressedFontColor", "muted", 0.65)
    button:GetLabelControl():SetMaxLineCount(1)
    button:GetLabelControl():SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

    button.bmwPlate = UI.CreateFill(nil, button, UI.CHROME.TRACK)
    button.bmwPlate:SetAnchorFill(button)
    button.bmwPlate:SetDrawLayer(DL_BACKGROUND)
    if style == "tab" then
        button.bmwUnderline = UI.CreateFill(nil, button, UI.CHROME.ROW_HOVER)
        local r, g, b = UI.Tone("accent")
        button.bmwUnderline:SetCenterColor(r, g, b, 1)
        button.bmwUnderline:SetHeight(2)
        button.bmwUnderline:SetAnchor(BOTTOMLEFT, button, BOTTOMLEFT, 0, 0)
        button.bmwUnderline:SetAnchor(BOTTOMRIGHT, button, BOTTOMRIGHT, 0, 0)
    end
    local enter = button:GetHandler("OnMouseEnter")
    local exit = button:GetHandler("OnMouseExit")
    button:SetHandler("OnMouseEnter", function(self, ...)
        self.bmwHovered = true
        UI.PaintButton(self)
        if enter then
            return enter(self, ...)
        end
    end)
    button:SetHandler("OnMouseExit", function(self, ...)
        self.bmwHovered = false
        UI.PaintButton(self)
        if exit then
            return exit(self, ...)
        end
    end)
    UI.PaintButton(button)
end

-- The inverse of a fill: an empty rectangle with an accent outline, used to mark
-- the active choice in a group of buttons. The frame is returned unanchored so
-- the caller re-points it as the selection moves.
function UI.CreateSelectionFrame(name, parent)
    local frame = WINDOW_MANAGER:CreateControl(name, parent, CT_BACKDROP)
    local bleed = UI.METRIC.SELECT_BLEED
    frame:SetEdgeTexture("", 1, 1, 1)
    frame:SetInsets(-bleed, -bleed, bleed, bleed)
    frame:SetCenterColor(0, 0, 0, 0)

    local r, g, b = UI.Tone("accent")
    frame:SetEdgeColor(r, g, b, UI.CHROME.ACCENT_MARK)
    frame:SetMouseEnabled(false)
    return frame
end

-- A horizontal divider at one of the two standard weights. STRONG separates the
-- structural blocks of a window (header / body / footer); SOFT separates rows
-- inside one block, where a full-weight rule would fight the content.
function UI.CreateRule(name, parent, width, weight)
    local rule = WINDOW_MANAGER:CreateControl(name, parent, CT_TEXTURE)
    rule:SetTexture(DIVIDER_TEXTURE)
    rule:SetDimensions(width, UI.METRIC.RULE_HEIGHT)
    rule:SetColor(1, 1, 1, weight == "soft" and UI.CHROME.RULE_SOFT or UI.CHROME.RULE_STRONG)
    return rule
end

-- The letterhead every window opens with: a faint accent wash the full width of
-- the window, closed at the bottom by a brighter accent line. It costs two flat
-- fills and is what makes the three windows read as one product -- the title
-- always sits in the same kind of space, whatever the window does below it.
--
-- The band is returned unanchored so the caller places it; its underline is a
-- child anchored to its own bottom edge, so moving or resizing the band carries
-- the line with it.
function UI.CreateHeaderBand(name, parent, width, height)
    local band = UI.CreateFill(name, parent, UI.CHROME.HEADER_BAND)
    band:SetDimensions(width, height)

    local line = UI.CreateFill(name .. "Line", band, UI.CHROME.ACCENT_LINE)
    line:SetHeight(UI.METRIC.ACCENT_RULE)
    line:SetAnchor(BOTTOMLEFT, band, BOTTOMLEFT, 0, 0)
    line:SetAnchor(BOTTOMRIGHT, band, BOTTOMRIGHT, 0, 0)

    band.accentLine = line
    return band
end

-- A hidden accent wash filling `parent`, shown on hover. Created as the first
-- child so it sits behind the row's own labels, and mouse-disabled so it never
-- eats the click it is advertising.
function UI.CreateHoverFill(name, parent)
    local fill = UI.CreateFill(name, parent, UI.CHROME.ROW_HOVER)
    fill:SetAnchorFill(parent)
    fill:SetHidden(true)
    return fill
end

-- Tint an existing hover/stripe fill to one of the shared row states. Kept as a
-- setter (rather than three creators) because a recycled list row switches state
-- as it scrolls -- and because the virtualized lists get their fill from the XML
-- template, where only geometry is declared. Such a fill arrives with the
-- backdrop default edge, so flatten it here too: the caller then never has to
-- know whether its fill came from markup or from UI.CreateFill.
function UI.PaintRowFill(fill, state)
    local color = UI.CHROME.ROW_HOVER
    if state == "zebra" then
        color = UI.CHROME.ROW_ZEBRA
    elseif state == "badge" then
        color = UI.CHROME.BADGE
    end
    FlattenBackdrop(fill)
    fill:SetCenterColor(unpack(color))
end

-- Style a CT_STATUSBAR as the addon's progress meter: an accent bar over a faint
-- track, so an empty meter still reads as a container waiting to fill rather
-- than as a gap in the layout. The track is a sibling fill (a child would draw
-- in front of the bar) anchored to the bar's own rectangle, so the caller places
-- the bar and the track follows. It is stashed on the bar for UI.ShowMeter and
-- also returned, for a caller that needs it directly.
function UI.ApplyMeter(statusBar, trackName)
    local r, g, b = UI.Tone("accent")
    statusBar:SetColor(r, g, b, 1)

    local track = UI.CreateFill(trackName, statusBar:GetParent(), UI.CHROME.TRACK)
    track:SetAnchorFill(statusBar)
    -- Behind the bar: created after it in draw order, so drop it a level.
    track:SetDrawLevel((statusBar:GetDrawLevel() or 0) - 1)
    track:SetHidden(statusBar:IsHidden())

    statusBar.bmwTrack = track
    return track
end

-- Show or hide a meter as one thing. A bar and its track are two controls but a
-- single element on screen: toggling only the bar leaves an empty track behind,
-- and every call site that reveals a meter would otherwise have to remember the
-- second control.
function UI.ShowMeter(statusBar, shown)
    statusBar:SetHidden(not shown)
    if statusBar.bmwTrack then
        statusBar.bmwTrack:SetHidden(not shown)
    end
end

-- List rows
-- ---------------------------------------------------------------------------
-- The two virtualized lists must declare their row controls in XML
-- (ZO_ScrollList instantiates them from a template), so their geometry lives in
-- DetailWindow.xml. Their type does not: a `font=` attribute in the markup is a
-- sixth place the type scale could be decided from, and it is the one place a
-- reader of this module would never think to look. So the templates name no font
-- and every row column is faced here instead.
--
-- Applied once per recycled control via a sentinel, because ZO_ScrollList calls
-- its setup function again for every row that scrolls into view.
function UI.ApplyRowFonts(rowControl, columns, tone)
    if rowControl.bmwFontsApplied then
        return
    end
    rowControl.bmwFontsApplied = true

    local font = UI.FONT[tone or "body"] or UI.FONT.body
    for i = 1, #columns do
        local label = rowControl:GetNamedChild(columns[i])
        if label then
            label:SetFont(font)
        end
    end
end

-- Tooltips
-- ---------------------------------------------------------------------------
-- Every hover in the addon now composes its tooltip from these three calls, so
-- the whole product explains itself in one voice: an accent title, a divider,
-- then lines whose tone names the kind of fact they carry (a value, a caption,
-- a warning, a gain). Previously each file wrote its own AddLine triples, which
-- is how two different title fonts and four slightly different greys got in.
-- A sub-heading inside a tooltip: the same voice as a title, without the divider.
-- Long hovers (the material row explains stock, price, fees and provenance) need
-- to break into blocks, and a block opener must not read as a second title.
function UI.TipSection(tooltip, text)
    tooltip:AddLine(text, UI.FONT.subhead, UI.Tone("accent"))
end

function UI.TipTitle(tooltip, text)
    UI.TipSection(tooltip, text)
    ZO_Tooltip_AddDivider(tooltip)
end

function UI.TipLine(tooltip, text, tone)
    tooltip:AddLine(text, UI.FONT.body, UI.Tone(tone or "name"))
end

function UI.TipCaption(tooltip, text, tone)
    tooltip:AddLine(text, UI.FONT.small, UI.Tone(tone or "muted"))
end

function UI.TipDivider(tooltip)
    ZO_Tooltip_AddDivider(tooltip)
end
