
BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.Plot = BGMeter.Plot or {}

local P = {}

local function ui() return BGMeter.zenimax.ui end

local _id = 0
local function uniq(prefix)
    _id = _id + 1
    return (prefix or "BGMeterC") .. _id
end

function P.label(parent, font, color, name)
    local c = ui().create_control(name or uniq("BGMeterLbl"), parent, CT_LABEL)
    c:SetFont(font or BGMeter.Plot.style.FONT.row)
    if color then BGMeter.Plot.style.color(c, color) end
    c:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    return c
end

local FILL = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"

function P.rect(parent, color, name)
    local c = ui().create_control(name or uniq("BGMeterRect"), parent, CT_TEXTURE)
    c:SetTexture(FILL)
    c:SetTextureCoords(0, 1, 0, 0.05)
    if c.SetPixelRoundingEnabled then c:SetPixelRoundingEnabled(false) end
    local col = color or { 1, 1, 1, 1 }
    c:SetColor(col[1], col[2], col[3], col[4] or 1)
    return c
end

function P.set_rect_color(c, color)
    if not c or not color then return end
    c:SetColor(color[1], color[2], color[3], color[4] or 1)
end

function P.backdrop(parent, name)
    return P.rect(parent, BGMeter.Constants.COLOR.panel, name or uniq("BGMeterBd"))
end

P.FRAME_EDGE = "bgmeter/assets/frame.dds"
P.FRAME_SIZE = 14
P.FRAME_THIN_EDGE = "bgmeter/assets/frame_thin.dds"
P.FRAME_THIN_SIZE = 8

function P.frame(parent, name)
    local c = ui().create_control(name or uniq("BGMeterFrame"), parent, CT_BACKDROP)
    c:SetEdgeTexture(P.FRAME_EDGE, 256, 32, P.FRAME_SIZE)
    c:SetCenterColor(0, 0, 0, 0)
    c:SetInsets(0, 0, 0, 0)
    return c
end

function P.frame_thin(parent, name)
    local c = ui().create_control(name or uniq("BGMeterFrameThin"), parent, CT_BACKDROP)
    c:SetEdgeTexture(P.FRAME_THIN_EDGE, 128, 16, P.FRAME_THIN_SIZE)
    c:SetCenterColor(0, 0, 0, 0)
    c:SetInsets(0, 0, 0, 0)
    return c
end

function P.hairline_box(parent, color)
    local box = {}
    local col = color or { 1, 1, 1, 0.16 }
    local top = P.rect(parent, col)
    top:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
    top:SetAnchor(TOPRIGHT, parent, TOPRIGHT, 0, 0)
    top:SetHeight(1)
    local bottom = P.rect(parent, col)
    bottom:SetAnchor(BOTTOMLEFT, parent, BOTTOMLEFT, 0, 0)
    bottom:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, 0, 0)
    bottom:SetHeight(1)
    local left = P.rect(parent, col)
    left:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
    left:SetAnchor(BOTTOMLEFT, parent, BOTTOMLEFT, 0, 0)
    left:SetWidth(1)
    local right = P.rect(parent, col)
    right:SetAnchor(TOPRIGHT, parent, TOPRIGHT, 0, 0)
    right:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, 0, 0)
    right:SetWidth(1)
    box.top, box.bottom, box.left, box.right = top, bottom, left, right
    return box
end

function P.button(parent, normal, pressed, over, name)
    local b = ui().create_control(name or uniq("BGMeterBtn"), parent, CT_BUTTON)
    b:SetNormalTexture(normal)
    if pressed then b:SetPressedTexture(pressed) end
    if over then b:SetMouseOverTexture(over) end
    b:SetMouseEnabled(true)
    return b
end

P.BUTTON_TEX = {
    up = "bgmeter/assets/button_up.dds", over = "bgmeter/assets/button_over.dds",
    down = "bgmeter/assets/button_down.dds", disabled = "bgmeter/assets/button_disabled.dds",
}
P.BUTTON_FACE = { 0.18, 0.13, 0.12 }
P.BUTTON_SQ_TEX = {
    up = "bgmeter/assets/button_sq_up.dds", over = "bgmeter/assets/button_sq_over.dds",
    down = "bgmeter/assets/button_sq_down.dds", disabled = "bgmeter/assets/button_sq_disabled.dds",
}

function P.gold_button(parent, label, name, square)
    local b = ui().create_from_virtual(name or uniq("BGMeterGoldButton"), parent, "ZO_DefaultButton")
    if label then b:SetText(label) end
    local tex = square and P.BUTTON_SQ_TEX or P.BUTTON_TEX
    if b.SetNormalTexture then
        b:SetNormalTexture(tex.up)
        b:SetMouseOverTexture(tex.over)
        b:SetPressedTexture(tex.down)
        b:SetDisabledTexture(tex.disabled)
        if b.SetEndCapWidth then b:SetEndCapWidth(0) end
        if b.SetMouseOverBlendMode then b:SetMouseOverBlendMode(TEX_BLEND_MODE_ALPHA or 0) end
    end
    P.button_text_color(b, true)
    return b
end

function P.button_text_color(b, lit)
    if not b.SetNormalFontColor then return end
    local g = BGMeter.Constants.COLOR.gold
    if lit then
        b:SetNormalFontColor(g[1], g[2], g[3], 1)
        b:SetMouseOverFontColor(1, 0.94, 0.66, 1)
        b:SetPressedFontColor(g[1] * 0.85, g[2] * 0.85, g[3] * 0.85, 1)
    else
        b:SetNormalFontColor(0.62, 0.58, 0.50, 1)
        b:SetMouseOverFontColor(0.80, 0.76, 0.66, 1)
        b:SetPressedFontColor(0.50, 0.46, 0.40, 1)
    end
    b:SetDisabledFontColor(0.45, 0.42, 0.35, 1)
end

function P.button_text_silver(b, font)
    if font and b.SetFont then b:SetFont(font) end
    if not b.SetNormalFontColor then return end
    b:SetNormalFontColor(0.84, 0.82, 0.78, 1)
    b:SetMouseOverFontColor(1, 1, 1, 1)
    b:SetPressedFontColor(0.66, 0.64, 0.60, 1)
    b:SetDisabledFontColor(0.45, 0.42, 0.35, 1)
end

function P.icon(parent, texturePath, name)
    local c = ui().create_control(name or uniq("BGMeterIcon"), parent, CT_TEXTURE)
    if texturePath then c:SetTexture(texturePath) end
    return c
end

function P.line(parent, color, thickness)
    local ok, c = pcall(function()
        return ui().create_from_virtual(uniq("BGMeterLine"), parent, "BGMeterLineTemplate")
    end)
    if not ok or not c then return nil end
    if c.SetPixelRoundingEnabled then c:SetPixelRoundingEnabled(false) end
    if c.SetThickness then c:SetThickness(thickness or 2) end
    local col = color or { 1, 1, 1, 1 }
    c:SetColor(col[1], col[2], col[3], col[4] or 1)
    return c
end

BGMeter.Plot.primitives = P
