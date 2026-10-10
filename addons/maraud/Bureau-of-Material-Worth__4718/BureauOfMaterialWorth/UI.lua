local addon = BureauOfMaterialWorth
local private = addon.private

-- Shared visual language
-- ---------------------------------------------------------------------------
-- Shared colors, fonts, spacing, control styling, and custom-tooltip helpers.
-- Loads after the core palette and before the window modules.
local UI = {}
private.UI = UI

local tonumber = tonumber
local stringsub = string.sub
local unpack = unpack

-- Colour
-- ---------------------------------------------------------------------------
-- Convert inline-text hex colors to normalized control RGB values.
function UI.HexToRGB(hex)
    local r = (tonumber(stringsub(hex, 1, 2), 16) or 0) / 255
    local g = (tonumber(stringsub(hex, 3, 4), 16) or 0) / 255
    local b = (tonumber(stringsub(hex, 5, 6), 16) or 0) / 255
    return r, g, b
end

-- Named text and control tones.
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

-- Cache normalized RGB triples for the named tones.
UI.RGB = {}
for tone, hex in pairs(UI.HEX) do
    local r, g, b = UI.HexToRGB(hex)
    UI.RGB[tone] = { r, g, b }
end

-- Unknown tones fall back to the primary text color.
function UI.Tone(tone)
    local rgb = UI.RGB[tone] or UI.RGB.name
    return rgb[1], rgb[2], rgb[3]
end

-- Type scale
-- ---------------------------------------------------------------------------
-- Font roles for totals, titles, headings, body text, and captions.
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
-- Shared insets and spacing; window-specific geometry stays in each module.
UI.METRIC = {
    PADDING      = 16,
    PADDING_WIDE = 16,
    GAP_TIGHT    = 4,
    GAP          = 8,
    GAP_WIDE     = 12,
    RULE_HEIGHT  = 4,   -- the divider texture's natural height
    ACCENT_RULE  = 1,
    BAND_PAD     = 6,   -- air between a header band's edge and its text
    -- Negative backdrop insets place the selection outline outside its control.
    SELECT_BLEED = 1,
}

-- Chrome
-- ---------------------------------------------------------------------------
-- Panel surfaces, brass header accents, row fills, and progress tracks.
UI.CHROME = {
    BG          = { 0.067, 0.075, 0.075 },
    BG_ALPHA    = 0.96,
    -- More opaque background for the withdrawal editor.
    BG_ALPHA_SOLID = 0.98,
    EDGE        = { 0.737, 0.655, 0.475 },
    EDGE_ALPHA  = 0.42,
    INSET       = 1,
    HEADER_BAND = { 0.737, 0.655, 0.475, 0.065 },
    ACCENT_LINE = { 0.737, 0.655, 0.475, 0.48 },
    ROW_HOVER   = { 0.439, 0.773, 0.741, 0.12 },
    CATEGORY_SHARE = { 0.439, 0.773, 0.741, 0.38 },
    BADGE       = { 1, 1, 1, 0.055 },
    -- Opacity for selection outlines and category markers.
    ACCENT_MARK = 0.95,
    ROW_ZEBRA   = { 1, 1, 1, 0.025 },
    TRACK       = { 1, 1, 1, 0.07 },
    RULE_STRONG = 0.24,
    RULE_SOFT   = 0.12,
}

local DIVIDER_TEXTURE = "EsoUI/Art/Miscellaneous/horizontalDivider.dds"

-- Apply panel styling with optional background, border, and opacity overrides.
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

-- Remove default edges and insets from Lua-created and XML-template fills.
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

-- Repaint an existing fill from an RGBA table.
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

-- Return an unanchored selection outline for the caller to position.
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

-- Strong dividers separate sections; soft dividers separate rows.
function UI.CreateRule(name, parent, width, weight)
    local rule = WINDOW_MANAGER:CreateControl(name, parent, CT_TEXTURE)
    rule:SetTexture(DIVIDER_TEXTURE)
    rule:SetDimensions(width, UI.METRIC.RULE_HEIGHT)
    rule:SetColor(1, 1, 1, weight == "soft" and UI.CHROME.RULE_SOFT or UI.CHROME.RULE_STRONG)
    return rule
end

-- Return an unanchored header band with a child underline that follows its size.
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

-- Hidden, mouse-disabled hover fill; create it before the row's foreground controls.
function UI.CreateHoverFill(name, parent)
    local fill = UI.CreateFill(name, parent, UI.CHROME.ROW_HOVER)
    fill:SetAnchorFill(parent)
    fill:SetHidden(true)
    return fill
end

-- Repaint recycled row fills, removing any default XML backdrop edges.
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

-- Add a sibling track behind the progress bar and retain it for UI.ShowMeter.
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

-- Toggle both the bar and its background track.
function UI.ShowMeter(statusBar, shown)
    statusBar:SetHidden(not shown)
    if statusBar.bmwTrack then
        statusBar.bmwTrack:SetHidden(not shown)
    end
end

-- List rows
-- ---------------------------------------------------------------------------
-- XML defines row geometry; apply fonts only once per recycled control.
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
-- Section heading without a divider; TipTitle adds the divider.
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
