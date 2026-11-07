-- ============================================================================
-- Bloom HPS - UI
-- A soft rounded pastel panel (9-slice texture) that sizes itself to the text,
-- dressed with semi-transparent flowers and sparkles around the edges.
-- ============================================================================

local M = HPSMeterUI
local UI = {}
M.UI = UI

local format, floor, max, min = string.format, math.floor, math.max, math.min
local Fmt = M.FormatShortNumber

local PAD_X, PAD_Y = 16, 11
local PANEL_SLICE = 18 / 64     -- corner size inside panel.dds, in texture coords
local NUMBER_COLOR = "fff4fa"   -- soft white for the numbers
local TITLE_COLOR  = "ffc7e1"
local DIM_COLOR    = "d9b8cc"   -- separators

local controls = {}
local textured = {} -- { control, textureName } for re-pointing on a path change

local function Colorize(hex, text)
    return format("|c%s%s|r", hex, text)
end

local function Icon(name, size)
    if controls.fallback then return "" end -- textures unavailable
    return format("|t%d:%d:%s|t", size, size, M.Texture(name))
end

local function NewTexture(wm, parent, name, level)
    local tex = wm:CreateControl(nil, parent, CT_TEXTURE)
    tex:SetTexture(M.Texture(name))
    textured[#textured + 1] = { tex, name }
    tex:SetDrawLevel(level)
    tex:SetMouseEnabled(false)
    return tex
end

-- Nine textures cut from one rounded panel image, so the corners stay round
-- however big the text gets.
local function CreatePanel(wm, parent)
    local a, b = PANEL_SLICE, 1 - PANEL_SLICE
    local cuts = { { 0, a }, { a, b }, { b, 1 } }
    local panel = {}
    for row = 1, 3 do
        for col = 1, 3 do
            local tex = NewTexture(wm, parent, "panel", 0)
            local u, v = cuts[col], cuts[row]
            tex:SetTextureCoords(u[1], u[2], v[1], v[2])
            panel[(row - 1) * 3 + col] = tex
        end
    end
    return panel
end

local function LayoutPanel(panel, frame, corner)
    local tl, t, tr, l, c, r, bl, bm, br = unpack(panel)
    for _, tex in ipairs(panel) do tex:ClearAnchors() end

    tl:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 0)
    tl:SetDimensions(corner, corner)
    tr:SetAnchor(TOPRIGHT, frame, TOPRIGHT, 0, 0)
    tr:SetDimensions(corner, corner)
    bl:SetAnchor(BOTTOMLEFT, frame, BOTTOMLEFT, 0, 0)
    bl:SetDimensions(corner, corner)
    br:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, 0, 0)
    br:SetDimensions(corner, corner)

    t:SetAnchor(TOPLEFT, tl, TOPRIGHT)
    t:SetAnchor(BOTTOMRIGHT, tr, BOTTOMLEFT)
    bm:SetAnchor(TOPLEFT, bl, TOPRIGHT)
    bm:SetAnchor(BOTTOMRIGHT, br, BOTTOMLEFT)
    l:SetAnchor(TOPLEFT, tl, BOTTOMLEFT)
    l:SetAnchor(BOTTOMRIGHT, bl, TOPRIGHT)
    r:SetAnchor(TOPLEFT, tr, BOTTOMLEFT)
    r:SetAnchor(BOTTOMRIGHT, br, TOPRIGHT)
    c:SetAnchor(TOPLEFT, tl, BOTTOMRIGHT)
    c:SetAnchor(BOTTOMRIGHT, br, TOPLEFT)
end

-- name, texture, anchor point on the frame, offset (in units of the flower
-- size), size (relative to line height), alpha (relative to flowerAlpha), tilt
local DECOR = {
    { "flower_sakura",   TOPLEFT,      0.05,  0.02, 2.6, 1.00,  0.20 },
    { "flower_sakura",   TOPLEFT,      1.30, -0.10, 1.2, 0.85, -0.50 },
    { "sparkle",         TOPLEFT,      2.90,  0.00, 0.9, 0.90,  0.00 },
    { "flower_lavender", BOTTOMRIGHT,  0.00,  0.00, 2.2, 0.95, -0.25 },
    { "flower_mint",     BOTTOMRIGHT, -1.30,  0.15, 1.1, 0.85,  0.60 },
    { "sparkle",         TOPRIGHT,    -0.70,  0.05, 0.8, 0.90,  0.00 },
    { "sparkle",         BOTTOMLEFT,   1.40, -0.05, 0.6, 0.80,  0.00 },
    -- big faint watermark tucked behind the numbers
    { "flower_sakura",   RIGHT,       -0.28,  0.00, 5.0, 0.22,  0.35, true },
}

function UI.Create()
    local wm = WINDOW_MANAGER
    local root = wm:CreateTopLevelWindow("HPSMeterControl")
    root:SetMouseEnabled(false)
    root:SetAnchorFill(GuiRoot)

    local label = wm:CreateControl("HPSMeterLabel", root, CT_LABEL)
    label:SetDrawLevel(5)

    -- invisible box around the text that the panel and flowers hang off
    local frame = wm:CreateControl("HPSMeterFrame", root, CT_CONTROL)
    frame:SetAnchor(TOPLEFT, label, TOPLEFT, -PAD_X, -PAD_Y)
    frame:SetAnchor(BOTTOMRIGHT, label, BOTTOMRIGHT, PAD_X, PAD_Y)

    controls.root, controls.label, controls.frame = root, label, frame
    controls.panel = CreatePanel(wm, root)

    -- plain rectangle used only if the texture files can't be loaded
    local plain = wm:CreateControl("HPSMeterPlainBackdrop", root, CT_BACKDROP)
    plain:SetCenterTexture("EsoUI/Art/Miscellaneous/white.dds")
    plain:SetEdgeTexture("EsoUI/Art/Miscellaneous/white.dds", 1, 1, 2)
    plain:SetCenterColor(M.HexToRGBA("2e1b33", 0.8))
    plain:SetEdgeColor(M.HexToRGBA("ffa8d2", 0.95))
    plain:SetAnchorFill(frame)
    plain:SetDrawLevel(0)
    plain:SetHidden(true)
    controls.plain = plain

    controls.decor = {}
    for i, def in ipairs(DECOR) do
        local isWatermark = def[8]
        local tex = NewTexture(wm, root, def[1], isWatermark and 1 or 3)
        tex:SetTextureRotation(def[7])
        controls.decor[i] = tex
    end

    UI.ApplyLayout()
    UI.VerifyTextures()
end

function UI.ReloadTextures()
    for _, entry in ipairs(textured) do entry[1]:SetTexture(M.Texture(entry[2])) end
    UI.Refresh()
end

function UI.TexturesLoaded()
    local probe = controls.panel and controls.panel[5]
    return probe and probe:IsTextureLoaded() or false
end

-- Textures load asynchronously; if the panel still isn't loaded after a short
-- wait, try the next path spelling.
function UI.VerifyTextures()
    zo_callLater(function()
        -- hidden textures may never load, so only judge while the meter shows
        if UI.TexturesLoaded() or not M.saved.showLabel then return end
        if M.NextTextureRoot() then
            UI.ReloadTextures()
            UI.VerifyTextures()
        else
            -- no path worked: show a plain backdrop instead of white boxes
            controls.fallback = true
            UI.ApplyLayout()
            M.Print("Could not load the flower textures (if you just added them, fully "
                .. "restart the game; /reloadui doesn't pick up new files). "
                .. "Type /bloomhps textures for details.")
        end
    end, 1500)
end

-- Re-applies position, scale and visibility from the saved settings.
function UI.ApplyLayout()
    local saved, label = M.saved, controls.label
    if not label then return end

    local fontSize = max(14, floor(22 * saved.scale))
    controls.fontSize = fontSize
    label:SetFont(format("$(MEDIUM_FONT)|%d|soft-shadow-thick", fontSize))
    label:SetScale(saved.scale)

    label:ClearAnchors()
    label:SetAnchor(TOPLEFT, controls.root, TOPLEFT, saved.labelX, saved.labelY)

    -- decorations scale with how tall a line of text really is on screen
    local lineH = fontSize * saved.scale
    LayoutPanel(controls.panel, controls.frame, min(24, max(10, lineH * 0.9)))

    local frame = controls.frame
    for i, def in ipairs(DECOR) do
        local tex = controls.decor[i]
        local size = max(8, lineH * def[5])
        tex:SetDimensions(size, size)
        tex:ClearAnchors()
        tex:SetAnchor(CENTER, frame, def[2], def[3] * size, def[4] * size)
        tex:SetAlpha(min(1, saved.flowerAlpha * def[6]))
    end

    local hidden = not saved.showLabel
    label:SetHidden(hidden)
    local fallback = controls.fallback
    controls.plain:SetHidden(hidden or not fallback)
    for _, tex in ipairs(controls.panel) do tex:SetHidden(hidden or fallback) end
    for _, tex in ipairs(controls.decor) do tex:SetHidden(hidden or fallback or not saved.showFlowers) end

    UI.Refresh()
end

function UI.BuildText(stats)
    local saved = M.saved
    local iconSize = controls.fontSize or 22
    local dot = Colorize(DIM_COLOR, "  ·  ")
    local lines = {}

    -- icon, colour, then label/value pairs
    local function Add(icon, color, ...)
        local parts = {}
        local args = { ... }
        for i = 1, #args, 2 do
            parts[#parts + 1] = Colorize(color, args[i] .. " ") .. Colorize(NUMBER_COLOR, args[i + 1])
        end
        lines[#lines + 1] = Icon(icon, iconSize) .. " " .. table.concat(parts, dot)
    end

    if saved.showTitle then
        local flower = Icon("flower_sakura", iconSize)
        lines[#lines + 1] = flower .. Colorize(TITLE_COLOR, " Bloom HPS ") .. flower
    end

    Add("heart_cute", saved.labelColor, "HPS", Fmt(stats.hps), "HPM", Fmt(stats.hpm))
    if saved.showSplits then
        Add("sparkle", saved.labelColor,
            "Personal", Fmt(stats.healPersonal), "Group", Fmt(stats.healGroup))
    end

    if saved.showShields then
        Add("shield_cute", saved.shieldColor,
            "SPS", Fmt(stats.sps), "SPM", Fmt(stats.spm), "Shield", Fmt(stats.shieldTotal))
        if saved.showSplits then
            -- group shields are only recorded in LibFights group mode
            local group = stats.groupMode and Fmt(stats.shieldGroup) or "-"
            Add("sparkle", saved.shieldColor, "Personal", Fmt(stats.shieldPersonal), "Group", group)
        end
    end

    if saved.showMitigation then
        Add("flower_mint", saved.mitigationColor,
            "Mitigated", Fmt(stats.mitigated), "MPS", Fmt(stats.mps),
            "", format("%.1f%%", stats.mitigatedPct))
    end

    return table.concat(lines, "\n")
end

function UI.Refresh()
    if not controls.label or not M.saved.showLabel then return end
    controls.label:SetText(UI.BuildText(M.Data.GetStats()))
end
