NAGA_UI = NAGA_UI or {}
local NAGA_UI = NAGA_UI

local BarVisuals = {}
NAGA_UI.BarVisuals = BarVisuals

local EDGE_FRAME_TEXTURE = "EsoUI/Art/Miscellaneous/Gamepad/edgeframeGamepadBorder_thin.dds"
local LOSS_TRAIL_HOLD_MS = 350
local LOSS_TRAIL_CATCHUP_MS = 850

-- Custom bar textures supplied by the user (all are 256x32 DXT5 DDS).
local CUSTOM_BAR_TEXTURE_FILES =
{
    Button = "Button.dds", Cloud = "Cloud.dds", Dabs = "Dabs.dds", DarkBottom = "DarkBottom.dds",
    Flat = "Flat.dds", g1 = "g1.dds", g2 = "g2.dds", Glaze = "Glaze.dds", Gloss = "Gloss.dds",
    grad = "grad.dds", grainy = "grainy.dds", Healbot = "Healbot.dds", HorizontalGrad = "HorizontalGrad.dds",
    LiteStep = "LiteStep.dds", Lyfe = "Lyfe.dds", Perl2 = "Perl2.dds", Rain = "Rain.dds", Rocks = "Rocks.dds",
    Ruben = "Ruben.dds", Runes = "Runes.dds", SandPaper = "SandPaper.dds", SandPaperV2 = "SandPaperV2.dds",
    Smudge = "Smudge.dds", Steel = "Steel.dds", Striped = "Striped.dds",
}

BarVisuals.CustomBarTextureKeys = {
    "genericTall", "Button", "Cloud", "Dabs", "DarkBottom", "Flat", "g1", "g2", "Glaze", "Gloss",
    "grad", "grainy", "Healbot", "HorizontalGrad", "LiteStep", "Lyfe", "Perl2", "Rain", "Rocks",
    "Ruben", "Runes", "SandPaper", "SandPaperV2", "Smudge", "Steel", "Striped",
}

BarVisuals.CustomBarTextureLabels =
{
    genericTall = "Padrão ESO", Button = "Button", Cloud = "Cloud", Dabs = "Dabs", DarkBottom = "DarkBottom",
    Flat = "Flat", g1 = "g1", g2 = "g2", Glaze = "Glaze", Gloss = "Gloss", grad = "grad", grainy = "grainy",
    Healbot = "Healbot", HorizontalGrad = "Horizontal Grad", LiteStep = "LiteStep", Lyfe = "Lyfe", Perl2 = "Perl2",
    Rain = "Rain", Rocks = "Rocks", Ruben = "Ruben", Runes = "Runes", SandPaper = "SandPaper",
    SandPaperV2 = "SandPaper V2", Smudge = "Smudge", Steel = "Steel", Striped = "Striped",
}

BarVisuals.Textures =
{
    genericTall =
    {
        texture = "EsoUI/Art/Miscellaneous/progressbar_genericFill_tall.dds",
        gloss = "EsoUI/Art/Miscellaneous/timerBar_genericFill_gloss.dds",
        coords = { 0, 1, 0, 0.8125 },
    },
    genericArrow =
    {
        texture = "EsoUI/Art/Miscellaneous/progressbar_genericFill.dds",
        gloss = "EsoUI/Art/Miscellaneous/progressbar_genericFill_gloss.dds",
        coords = { 0, 1, 0, 0.625 },
    },
    gamepadMedium =
    {
        texture = "EsoUI/Art/Miscellaneous/Gamepad/gp_dynamicBar_medium_fill.dds",
        gloss = "EsoUI/Art/Miscellaneous/timerBar_genericFill_gloss.dds",
        coords = { 0, 1, 0, 1 },
    },
    gamepadLarge =
    {
        texture = "EsoUI/Art/Miscellaneous/Gamepad/gp_dynamicBar_large_fill.dds",
        gloss = "EsoUI/Art/Miscellaneous/timerBar_genericFill_gloss.dds",
        coords = { 0, 1, 0, 1 },
    },
    tributeLarge =
    {
        texture = "EsoUI/Art/Miscellaneous/progressbar_large_genericFill.dds",
        gloss = "EsoUI/Art/Miscellaneous/progressbar_large_genericFill_gloss.dds",
        coords = { 0, 1, 0, 1 },
    },
}

-- The custom bar DDS files are not present in this addon package. Point these
-- legacy texture choices at ESO's built-in monochrome fill instead of a missing
-- path, so the configured Health/Magicka/Stamina/Target/Companion color gradients
-- render normally. The selector labels are kept to preserve saved settings.
for key, _ in pairs(CUSTOM_BAR_TEXTURE_FILES) do
    BarVisuals.Textures[key] =
    {
        texture = BarVisuals.Textures.genericTall.texture,
        gloss = BarVisuals.Textures.genericTall.gloss,
        coords = { 0, 1, 0, 0.8125 },
    }
end

function BarVisuals:GetBarTextureInfo(key)
    return self.Textures[key] or self.Textures.genericTall
end


BarVisuals.Patterns =
{
    smoke = "/art/fx/texture/smokecombinetexture.dds",
    stillwater = "/art/maps/housing/stillwatersretreatext_base_0.dds",
    ZigZag = "/esoui/art/miscellaneous/progressbar_texture_overlay.dds",
    Stone = "/art/fx/texture/fxmaterial/stormatronach_rocktexture_d.dds",
    Dirt = "/art/fx/texture/dirtprojection.dds",
    Lava = "/art/fx/texture/fxmaterial/stoneskinlava_d.dds",
    RockLava = "/art/fx/texture/modelfxtextures/mq6_rockwalldoorlava_n.dds",
    LavaWave = "/art/fx/texture/fxmaterial/lavayellow_d.dds",
    Molten = "/art/fx/texture/modelfxtextures/lava_005_d.dds",
}

BarVisuals.Fonts =
{
    gameSmall = "$(BOLD_FONT)",
    gameMedium = "$(MEDIUM_FONT)",
    antique = "$(ANTIQUE_FONT)",
    trajan = "EsoUI/Common/Fonts/TrajanPro-Regular.slug",
    univers = "EsoUI/Common/Fonts/Univers57.slug",
    chat = "$(CHAT_FONT)",
}

local function Clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    return math.min(math.max(value, minimum), maximum)
end

local function ReadColor(color, fallbackR, fallbackG, fallbackB, fallbackA)
    color = color or {}
    return tonumber(color.r or color[1]) or fallbackR,
        tonumber(color.g or color[2]) or fallbackG,
        tonumber(color.b or color[3]) or fallbackB,
        tonumber(color.a or color[4]) or fallbackA
end

local function ConfigureStatusBar(control, textureInfo)
    textureInfo = textureInfo or BarVisuals.Textures.genericTall
    control:SetTexture(textureInfo.texture)
    control:SetTextureCoords(unpack(textureInfo.coords))
    control:EnableLeadingEdge(false)
    control:SetPixelRoundingEnabled(false)
end

local function ConfigureOverlay(control, parent, drawLevel, textureInfo)
    control:SetAnchorFill(parent)
    ConfigureStatusBar(control, textureInfo)
    control:SetMinMax(0, 1)
    control:SetValue(1)
    control:SetDrawLayer(DL_OVERLAY)
    control:SetDrawLevel(drawLevel or 2)
    control:SetAlpha(0)
    control:SetHidden(true)
end

local function CreateLabel(parent, alignment)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    label:SetHorizontalAlignment(alignment)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetModifyTextType(MODIFY_TEXT_TYPE_NONE)
    label:SetDrawLayer(DL_OVERLAY)
    label:SetDrawLevel(6)
    return label
end

-- Plain vertex gradients keep shadows soft without stretching a decorative
-- frame texture. Pieces are reused when sliders or frame dimensions change.
local function ApplyShadow(control, width, height, opacity, inside)
    control:SetHidden(opacity <= 0)
    if opacity <= 0 then return end
    local size = math.min(inside and 3 or 4, width / 2, height / 2)
    local pieces
    if inside then
        pieces = {
            { 0, 0, width, size, 1, 1, 0, 0 },
            { 0, height - size, width, size, 0, 0, 1, 1 },
            { 0, 0, size, height, 1, 0, 1, 0 },
            { width - size, 0, size, height, 0, 1, 0, 1 },
        }
    else
        pieces = {
            { 0, -size, width, size, 0, 0, 1, 1 },
            { 0, height, width, size, 1, 1, 0, 0 },
            { -size, 0, size, height, 0, 1, 0, 1 },
            { width, 0, size, height, 1, 0, 1, 0 },
            { -size, -size, size, size, 0, 0, 0, 1 },
            { width, -size, size, size, 0, 0, 1, 0 },
            { -size, height, size, size, 0, 1, 0, 0 },
            { width, height, size, size, 1, 0, 0, 0 },
        }
    end
    local vertices = { VERTEX_POINTS_TOPLEFT, VERTEX_POINTS_TOPRIGHT,
        VERTEX_POINTS_BOTTOMLEFT, VERTEX_POINTS_BOTTOMRIGHT }
    control.pieces = control.pieces or {}
    for i, piece in ipairs(pieces) do
        local texture = control.pieces[i]
        if not texture then
            texture = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
            texture:SetMouseEnabled(false)
            texture:SetDrawLayer(inside and DL_OVERLAY or DL_BACKGROUND)
            texture:SetDrawLevel(inside and 2 or 0)
            control.pieces[i] = texture
        end
        texture:ClearAnchors()
        texture:SetAnchor(TOPLEFT, control, TOPLEFT, piece[1], piece[2])
        texture:SetDimensions(piece[3], piece[4])
        for j, vertex in ipairs(vertices) do
            texture:SetVertexColors(vertex, 0, 0, 0, piece[j + 4] * opacity)
        end
    end
end

function BarVisuals:Create(parent, name, options)
    options = options or {}
    local frame = WINDOW_MANAGER:CreateControl(name, parent, CT_CONTROL)
    frame:SetDimensions(options.width or 1, options.height or 1)

    frame.outerShadow = WINDOW_MANAGER:CreateControl(nil, frame, CT_CONTROL)
    frame.outerShadow:SetAnchorFill(frame)
    frame.outerShadow:SetDrawLayer(DL_BACKGROUND)

    frame.border = WINDOW_MANAGER:CreateControl(nil, frame, CT_BACKDROP)
    frame.border:SetAnchorFill(frame)
    frame.border:SetCenterColor(0, 0, 0, 0)
    frame.border:SetEdgeColor(0, 0, 0, 1)
    frame.border:SetEdgeTexture("", 1, 1, 1, 0)
    frame.border:SetDrawLayer(DL_OVERLAY)
    frame.border:SetDrawLevel(5)

    frame.track = WINDOW_MANAGER:CreateControl(nil, frame, CT_BACKDROP)
    frame.track:SetAnchorFill(frame)
    frame.track:SetCenterColor(0.01, 0.01, 0.01, 0.55)
    frame.track:SetEdgeColor(0, 0, 0, 0)
    frame.track:SetEdgeTexture("", 1, 1, 0)

    frame.lossTrail = WINDOW_MANAGER:CreateControl(nil, frame.track, CT_STATUSBAR)
    frame.lossTrail:SetAnchorFill(frame.track)
    ConfigureStatusBar(frame.lossTrail, BarVisuals.Textures.genericTall)
    frame.lossTrail:SetDrawLayer(DL_CONTROLS)
    frame.lossTrail:SetDrawLevel(0)
    frame.lossTrail:SetHidden(true)

    frame.bar = WINDOW_MANAGER:CreateControl(nil, frame.track, CT_STATUSBAR)
    frame.bar:SetAnchorFill(frame.track)
    ConfigureStatusBar(frame.bar, BarVisuals.Textures.genericTall)
    frame.bar:SetDrawLayer(DL_CONTROLS)
    frame.bar:SetDrawLevel(1)

    frame.patternBar = WINDOW_MANAGER:CreateControl(nil, frame.track, CT_STATUSBAR)
    frame.patternBar:SetAnchorFill(frame.track)
    ConfigureStatusBar(frame.patternBar, BarVisuals.Textures.genericTall)
    frame.patternBar:SetDrawLayer(DL_OVERLAY)
    frame.patternBar:SetDrawLevel(1)
    frame.patternBar:SetHidden(true)

    frame.innerShadow = WINDOW_MANAGER:CreateControl(nil, frame, CT_CONTROL)
    frame.innerShadow:SetAnchorFill(frame.track)
    frame.innerShadow:SetDrawLayer(DL_OVERLAY)
    frame.innerShadow:SetDrawLevel(0)

    frame.feedbackFlash = WINDOW_MANAGER:CreateControl(nil, frame.track, CT_STATUSBAR)
    ConfigureOverlay(frame.feedbackFlash, frame.track, 3, BarVisuals.Textures.genericTall)
    frame.readyFlash = WINDOW_MANAGER:CreateControl(nil, frame.track, CT_STATUSBAR)
    ConfigureOverlay(frame.readyFlash, frame.track, 4, BarVisuals.Textures.genericTall)

    frame.lowResourceGlow = WINDOW_MANAGER:CreateControl(nil, frame, CT_BACKDROP)
    frame.lowResourceGlow:SetAnchor(TOPLEFT, frame, TOPLEFT, -4, -4)
    frame.lowResourceGlow:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, 4, 4)
    frame.lowResourceGlow:SetCenterColor(0, 0, 0, 0)
    frame.lowResourceGlow:SetEdgeTexture(EDGE_FRAME_TEXTURE, 128, 16, 4, 0)
    frame.lowResourceGlow:SetDrawLayer(DL_OVERLAY)
    frame.lowResourceGlow:SetDrawLevel(1)
    frame.lowResourceGlow:SetHidden(true)

    if options.withShield then
        frame.shieldBar = WINDOW_MANAGER:CreateControl(nil, frame.track, CT_STATUSBAR)
        ConfigureStatusBar(frame.shieldBar, BarVisuals.Textures.genericTall)
        frame.shieldBar:SetMinMax(0, 1)
        frame.shieldBar:SetValue(1)
        frame.shieldBar:SetDrawLayer(DL_OVERLAY)

        frame.shieldGlow = WINDOW_MANAGER:CreateControl(nil, frame.track, CT_STATUSBAR)
        ConfigureStatusBar(frame.shieldGlow, BarVisuals.Textures.genericTall)
        frame.shieldGlow:SetMinMax(0, 1)
        frame.shieldGlow:SetValue(1)
        frame.shieldGlow:SetDrawLayer(DL_OVERLAY)
        frame.shieldGlow:SetDrawLevel(2)
        frame.shieldGlow:SetHidden(true)

        frame.shieldPulse = WINDOW_MANAGER:CreateControl(nil, frame.track, CT_STATUSBAR)
        ConfigureOverlay(frame.shieldPulse, frame.track, 5, BarVisuals.Textures.genericTall)
    end

    frame.gloss = WINDOW_MANAGER:CreateControl(nil, frame.bar, CT_STATUSBAR)
    frame.gloss:SetAnchorFill(frame.bar)
    ConfigureStatusBar(frame.gloss, BarVisuals.Textures.genericTall)
    frame.gloss:SetColor(1, 1, 1, 0.13)
    frame.gloss:SetMinMax(0, 1)
    frame.gloss:SetValue(1)

    frame.rhythmGlint = WINDOW_MANAGER:CreateControl(nil, frame.track, CT_TEXTURE)
    frame.rhythmGlint:SetTexture("EsoUI/Art/Miscellaneous/timerBar_genericFill_gloss.dds")
    frame.rhythmGlint:SetBlendMode(TEX_BLEND_MODE_ADD)
    frame.rhythmGlint:SetDrawLayer(DL_OVERLAY)
    frame.rhythmGlint:SetDrawLevel(5)
    frame.rhythmGlint:SetHidden(true)

    frame.centerLabel = CreateLabel(frame, TEXT_ALIGN_CENTER)
    frame.centerLabel:SetAnchor(CENTER, frame, CENTER, 0, 0)
    frame.leftLabel = CreateLabel(frame, TEXT_ALIGN_LEFT)
    frame.leftLabel:SetAnchor(LEFT, frame, LEFT, 6, 0)
    frame.rightLabel = CreateLabel(frame, TEXT_ALIGN_RIGHT)
    frame.rightLabel:SetAnchor(RIGHT, frame, RIGHT, -6, 0)

    self:SetAlignment(frame, options.alignment or BAR_ALIGNMENT_NORMAL)
    return frame
end

function BarVisuals:SetAlignment(frame, alignment)
    if not frame then
        return
    end

    local controls =
    {
        frame.lossTrail,
        frame.bar,
        frame.patternBar,
        frame.gloss,
        frame.feedbackFlash,
        frame.readyFlash,
        frame.shieldBar,
        frame.shieldGlow,
        frame.shieldPulse,
    }
    for _, control in ipairs(controls) do
        if control and control.SetBarAlignment then
            control:SetBarAlignment(alignment)
        end
    end
    frame.alignment = alignment
end

function BarVisuals:StopLossTrail(frame, current, maximum)
    if not frame or not frame.lossTrail then
        return
    end

    current = math.max(tonumber(current) or 0, 0)
    maximum = math.max(tonumber(maximum) or 0, 0)
    frame.lossTrail:SetHandler("OnUpdate", nil)
    frame.lossTrail:SetMinMax(0, maximum)
    frame.lossTrail:SetValue(current)
    frame.lossTrail:SetHidden(true)
    frame.lossTrailValue = current
    frame.lossTrailTarget = nil
    frame.lossTrailStartValue = nil
    frame.lossTrailStartMS = nil
    frame.lossTrailHoldUntilMS = nil
end

function BarVisuals:UpdateLossTrail(frame)
    if not frame or not frame.lossTrail or frame.lossTrailTarget == nil then
        return
    end

    local now = GetFrameTimeMilliseconds()
    if now < (frame.lossTrailHoldUntilMS or 0) then
        return
    end

    if not frame.lossTrailStartMS then
        frame.lossTrailStartMS = now
        frame.lossTrailStartValue = frame.lossTrailValue or frame.lossTrailTarget
    end

    local progress = Clamp((now - frame.lossTrailStartMS) / LOSS_TRAIL_CATCHUP_MS, 0, 1)
    local easedProgress = 1 - ((1 - progress) * (1 - progress))
    local startValue = frame.lossTrailStartValue or frame.lossTrailTarget
    local value = startValue + ((frame.lossTrailTarget - startValue) * easedProgress)
    frame.lossTrailValue = value
    frame.lossTrail:SetValue(value)

    if progress >= 1 then
        self:StopLossTrail(frame, frame.lossTrailTarget, frame.nagaMaximum)
    end
end

function BarVisuals:StartLossTrail(frame, previous, current, maximum)
    if not frame or not frame.lossTrail then
        return
    end

    previous = math.max(tonumber(previous) or 0, 0)
    current = math.max(tonumber(current) or 0, 0)
    maximum = math.max(tonumber(maximum) or 0, 0)
    local startValue = math.min(math.max(frame.lossTrailValue or previous, previous), maximum)

    frame.lossTrail:SetMinMax(0, maximum)
    frame.lossTrail:SetValue(startValue)
    frame.lossTrail:SetHidden(false)
    frame.lossTrailValue = startValue
    frame.lossTrailTarget = math.min(current, maximum)
    frame.lossTrailStartValue = nil
    frame.lossTrailStartMS = nil
    frame.lossTrailHoldUntilMS = GetFrameTimeMilliseconds() + LOSS_TRAIL_HOLD_MS
    frame.lossTrailUpdateHandler = frame.lossTrailUpdateHandler or function()
        self:UpdateLossTrail(frame)
    end
    frame.lossTrail:SetHandler("OnUpdate", frame.lossTrailUpdateHandler)
end

function BarVisuals:ApplyPattern(frame)
    if not frame or not frame.patternBar then
        return
    end

    local style = frame.nagaStyle or {}
    local enabled = style.patternEnabled == true
    local opacity = Clamp(style.patternOpacity or 0, 0, 1)
    local texture = style.patternTexture
    if not enabled or not texture or opacity <= 0 then
        frame.patternBar:SetHidden(true)
        return
    end

    local width = frame.layoutWidth or frame:GetWidth()
    local height = frame.layoutHeight or frame:GetHeight()
    local scale = Clamp(style.patternScale or width, 1, 512)
    frame.patternBar:SetTexture(texture)
    frame.patternBar:SetTextureCoords(0, math.max(width / scale, 0.01), 0, math.max(height / scale, 0.01))
    frame.patternBar:SetColor(1, 1, 1, opacity)
    frame.patternBar:SetHidden((frame.nagaCurrent or 0) <= 0 or width <= 0)
end

function BarVisuals:ApplyRpgBorder(frame, enabled, width, height, alpha)
    -- cap_dxt5.dds / rail_dxt5.dds removed — RPG iron borders disabled.
    if frame and frame.rpgBorder then
        for _, c in pairs(frame.rpgBorder) do
            c:SetHidden(true)
        end
    end
end

function BarVisuals:ApplyStyle(frame, style)
    if not frame then
        return
    end

    style = style or {}
    frame.nagaStyle = style
    local width = math.max(tonumber(style.width) or frame:GetWidth(), 1)
    local height = math.max(tonumber(style.height) or frame:GetHeight(), 1)
    local borderWidth = Clamp(style.borderWidth or 0, 0, math.min(12, (width - 1) / 2, (height - 1) / 2))
    local innerShadowAlpha = Clamp(style.innerShadowAlpha or 0, 0, 1)
    local outerShadowAlpha = Clamp(style.outerShadowAlpha or 0, 0, 1)
    local alpha = Clamp(style.alpha or 1, 0, 1)
    local textureInfo = style.textureInfo or BarVisuals.Textures.genericTall

    frame:SetDimensions(width, height)
    self:ApplyRpgBorder(frame,style.rpgBorder == true,width,height,alpha)
    frame.layoutWidth = width
    frame.layoutHeight = height
    frame.contentWidth = math.max(width - (borderWidth * 2), 1)
    frame.contentHeight = math.max(height - (borderWidth * 2), 1)

    ApplyShadow(frame.outerShadow, width, height, outerShadowAlpha * alpha * 0.65, false)

    frame.border:SetHidden(borderWidth <= 0)
    frame.border:SetEdgeColor(0, 0, 0, alpha)
    frame.border:SetCenterColor(0, 0, 0, 0)
    frame.border:SetEdgeTexture("", 1, 1, borderWidth, 0)

    frame.track:ClearAnchors()
    frame.track:SetAnchor(TOPLEFT, frame, TOPLEFT, borderWidth, borderWidth)
    frame.track:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -borderWidth, -borderWidth)
    local trackR, trackG, trackB, trackA = ReadColor(style.trackColor, 0.01, 0.01, 0.01, 0.55)
    frame.track:SetCenterColor(trackR, trackG, trackB, trackA * alpha)
    frame.track:SetEdgeTexture("", 1, 1, 0)
    frame.track:SetEdgeColor(0, 0, 0, 0)

    ApplyShadow(frame.innerShadow, frame.contentWidth, frame.contentHeight, innerShadowAlpha * alpha * 0.55, true)

    ConfigureStatusBar(frame.bar, textureInfo)
    ConfigureStatusBar(frame.lossTrail, textureInfo)
    ConfigureStatusBar(frame.patternBar, textureInfo)
    ConfigureStatusBar(frame.feedbackFlash, textureInfo)
    ConfigureStatusBar(frame.readyFlash, textureInfo)
    frame.bar:SetAlpha(alpha)

    local startR, startG, startB, startA = ReadColor(style.fillStartColor, 0.7, 0.05, 0.07, 1)
    local endR, endG, endB, endA = ReadColor(style.fillEndColor, startR, startG, startB, startA)
    frame.bar:SetGradientColors(startR, startG, startB, startA, endR, endG, endB, endA)

    local lossR, lossG, lossB, lossA = ReadColor(style.lossTrailColor, 1, 0.70, 0.24, 0.78)
    frame.lossTrail:SetColor(lossR, lossG, lossB, lossA)
    frame.lossTrail:SetAlpha(alpha)
    if style.lossTrailEnabled ~= true then
        self:StopLossTrail(frame, frame.nagaCurrent or 0, frame.nagaMaximum or 0)
    end

    frame.gloss:SetTexture(textureInfo.gloss or textureInfo.texture)
    frame.gloss:SetTextureCoords(unpack(textureInfo.coords))
    frame.gloss:SetColor(1, 1, 1, Clamp(style.glossOpacity or 0.13, 0, 1))
    frame.gloss:SetHidden(style.glossEnabled == false)

    if frame.shieldBar then
        ConfigureStatusBar(frame.shieldBar, textureInfo)
        local shieldR, shieldG, shieldB = ReadColor(style.shieldFillColor, 0.95, 0.60, 0.33, 1)
        frame.shieldBar:SetColor(shieldR, shieldG, shieldB, Clamp(style.shieldFillOpacity or 0, 0, 1))
        frame.shieldBar:SetAlpha(alpha)
    end
    if frame.shieldGlow then
        frame.shieldGlow:SetTexture(textureInfo.gloss or textureInfo.texture)
        frame.shieldGlow:SetTextureCoords(unpack(textureInfo.coords))
        local glowR, glowG, glowB = ReadColor(style.shieldGlowColor, 0.95, 0.66, 0.56, 1)
        frame.shieldGlow:SetColor(glowR, glowG, glowB, Clamp(style.shieldGlowOpacity or 0, 0, 1))
        frame.shieldGlow:SetAlpha(alpha)
    end
    if frame.shieldPulse then
        ConfigureStatusBar(frame.shieldPulse, textureInfo)
    end

    local textR, textG, textB = ReadColor(style.textColor, 1, 1, 1, 1)
    local textAlpha = Clamp(style.textOpacity or 1, 0, 1)
    local font = style.font or "ZoFontGameSmall"
    for _, label in ipairs({ frame.centerLabel, frame.leftLabel, frame.rightLabel }) do
        label:SetFont(font)
        label:SetColor(textR, textG, textB, textAlpha)
    end
    local inset = tonumber(style.textInset) or 6
    local verticalOffset = tonumber(style.textVerticalOffset) or 0
    frame.centerLabel:ClearAnchors()
    frame.centerLabel:SetAnchor(CENTER, frame, CENTER, 0, verticalOffset)
    frame.leftLabel:ClearAnchors()
    frame.leftLabel:SetAnchor(LEFT, frame, LEFT, inset, verticalOffset)
    frame.rightLabel:ClearAnchors()
    frame.rightLabel:SetAnchor(RIGHT, frame, RIGHT, -inset, verticalOffset)

    -- HUD 2: Vida e Escudo usam a mesma direção das demais barras:
    -- preenchimento normal, da esquerda para a direita.
    if frame.powerKey == "health" then
        self:SetAlignment(frame, BAR_ALIGNMENT_NORMAL)
    elseif style.alignment then
        self:SetAlignment(frame, style.alignment)
    end
    self:ApplyPattern(frame)
    self:SetShield(frame, frame.nagaShield or 0, frame.nagaMaximum or 0, false)
end

function BarVisuals:SetLowState(frame, current, maximum, color, threshold, intensity, enabled)
    if not frame or not frame.lowResourceGlow then
        return
    end

    local maxValue = tonumber(maximum) or 0
    local ratio = maxValue > 0 and Clamp((tonumber(current) or 0) / maxValue, 0, 1) or 1
    threshold = Clamp(threshold or 0, 0, 1)
    intensity = Clamp(intensity or 0, 0, 2)
    -- Borda de "recurso baixo" desativada: ela ficava saindo para fora do frame.
    frame.lowResourceGlow:SetHidden(true)
    if true or not enabled or ratio <= 0 or ratio >= threshold or intensity <= 0 then
        return
    end

    local r, g, b = ReadColor(color, 1, 0.1, 0.1, 1)
    local urgency = (threshold - ratio) / math.max(threshold, 0.001)
    local alpha = Clamp((0.18 + urgency * 0.35) * intensity, 0.08, 0.52)
    frame.lowResourceGlow:SetEdgeColor(r, g, b, alpha)
    frame.lowResourceGlow:SetCenterColor(r, g, b, alpha * 0.08)
    frame.lowResourceGlow:SetHidden(false)
end

function BarVisuals:SetValue(frame, current, maximum, smooth, animateLoss)
    if not frame or not frame.bar then
        return
    end

    -- HUD 2: mantém a Vida na mesma direção de Magicka e Stamina.
    if frame.powerKey == "health" then
        self:SetAlignment(frame, BAR_ALIGNMENT_NORMAL)
    end

    current = math.max(tonumber(current) or 0, 0)
    maximum = math.max(tonumber(maximum) or 0, 0)
    local previous = frame.nagaCurrent
    frame.nagaCurrent = current
    frame.nagaMaximum = maximum
    frame.bar:SetMinMax(0, maximum)
    if ZO_StatusBar_SmoothTransition then
        -- The fourth argument forces the value and cancels an in-flight ESO
        -- smooth transition. A direct SetValue alone can leave that previous
        -- transition running after a unit/frame swap.
        ZO_StatusBar_SmoothTransition(frame.bar, current, maximum, not smooth)
    else
        frame.bar:SetValue(current)
    end

    frame.patternBar:SetMinMax(0, maximum)
    frame.patternBar:SetValue(current)
    self:ApplyPattern(frame)

    local style = frame.nagaStyle or {}
    if style.lossTrailEnabled == true and animateLoss == true and previous ~= nil and current < previous then
        self:StartLossTrail(frame, previous, current, maximum)
    elseif animateLoss ~= nil or style.lossTrailEnabled ~= true then
        self:StopLossTrail(frame, current, maximum)
    end
    self:SetLowState(frame, current, maximum, style.lowGlowColor or style.fillEndColor, style.lowGlowThreshold, style.feedbackIntensity, style.lowGlowEnabled)
end

function BarVisuals:SetShield(frame, value, healthMaximum, smooth)
    if not frame or not frame.shieldBar then
        return
    end

    -- O escudo da Vida acompanha obrigatoriamente a mesma direção da Vida.
    if frame.powerKey == "health" then
        self:SetAlignment(frame, BAR_ALIGNMENT_NORMAL)
    end

    value = math.max(tonumber(value) or 0, 0)
    healthMaximum = math.max(tonumber(healthMaximum) or 0, 0)
    frame.nagaShield = value
    local style = frame.nagaStyle or {}
    local ratio = healthMaximum > 0 and Clamp(value / healthMaximum, 0, 1) or 0
    local visible = style.shieldEnabled ~= false and ratio > 0
    frame.shieldBar:SetHidden(not visible)
    frame.shieldGlow:SetHidden(not visible or style.shieldGlowEnabled == false)
    if not visible then
        return
    end

    local baseWidth = style.shieldUseOuterDimensions and frame.layoutWidth or frame.contentWidth
    local baseHeight = style.shieldUseOuterDimensions and frame.layoutHeight or frame.contentHeight
    local width = math.max((baseWidth or frame:GetWidth()) * ratio, 1)
    local height = baseHeight or frame:GetHeight()
    -- O escudo acompanha a mesma direção da barra de vida.
    -- No HUD 2, cresce da esquerda para a direita.
    local alignment = frame.alignment or BAR_ALIGNMENT_NORMAL
    for _, control in ipairs({ frame.shieldBar, frame.shieldGlow }) do
        control:ClearAnchors()
        if alignment == BAR_ALIGNMENT_REVERSE then
            control:SetAnchor(RIGHT, frame.track, RIGHT, 0, 0)
        else
            control:SetAnchor(LEFT, frame.track, LEFT, 0, 0)
        end
        control:SetDimensions(width, height)
    end
end

local function PlayAlpha(control, alpha, durationMS)
    if not control or alpha <= 0 then
        return
    end

    local animation = control.nagaAlphaAnimation
    local timeline = control.nagaAlphaTimeline
    if not animation then
        animation, timeline = CreateSimpleAnimation(ANIMATION_ALPHA, control)
        animation:SetHandler("OnStop", function(_, completedPlaying)
            if completedPlaying then
                control:SetAlpha(0)
                control:SetHidden(true)
            end
        end)
        control.nagaAlphaAnimation = animation
        control.nagaAlphaTimeline = timeline
    end

    control:SetHidden(false)
    control:SetAlpha(alpha)
    animation:SetAlphaValues(alpha, 0)
    animation:SetDuration(durationMS)
    timeline:SetPlaybackType(ANIMATION_PLAYBACK_ONE_SHOT, 0)
    timeline:PlayFromStart()
end

function BarVisuals:PlayFeedback(frame, effect, color, intensity)
    if not frame then
        return
    end

    intensity = Clamp(intensity or 0, 0, 1)
    local target = frame.feedbackFlash
    local duration = effect == "gain" and 420 or 320
    if effect == "full" then
        target = frame.readyFlash
        duration = 520
    elseif effect == "shield" then
        target = frame.shieldPulse
        duration = 500
    elseif effect == "death" or effect == "revive" then
        target = frame.readyFlash
        duration = effect == "death" and 300 or 420
    end
    if not target then
        return
    end

    local r, g, b = ReadColor(color, 1, 1, 1, 1)
    target:SetColor(r, g, b, intensity)
    PlayAlpha(target, intensity, duration)
end

function BarVisuals:PlayRecovery(frame, intensity)
    if not frame or not frame.rhythmGlint then
        return
    end

    local glint = frame.rhythmGlint
    local width = frame.contentWidth or frame.layoutWidth or frame:GetWidth()
    local height = frame.contentHeight or frame.layoutHeight or frame:GetHeight()
    local glintWidth = math.max(math.min(width * 0.16, 42), 18)
    glint:SetDimensions(glintWidth, height)
    glint:SetColor(0.8, 0.92, 1, Clamp(intensity or 0.18, 0, 0.5))
    glint:ClearAnchors()
    glint:SetAnchor(LEFT, frame.track, LEFT, -glintWidth, 0)
    glint:SetHidden(false)

    if not glint.nagaTimeline then
        local timeline = ANIMATION_MANAGER:CreateTimeline()
        local translate = timeline:InsertAnimation(ANIMATION_TRANSLATE, glint, 0)
        translate:SetDuration(620)
        if ZO_EaseInOutQuadratic then
            translate:SetEasingFunction(ZO_EaseInOutQuadratic)
        end
        timeline:SetHandler("OnStop", function()
            glint:SetHidden(true)
        end)
        glint.nagaTimeline = timeline
        glint.nagaTranslate = translate
    end
    glint.nagaTranslate:SetTranslateOffsets(0, 0, width + (glintWidth * 2), 0)
    glint.nagaTimeline:SetPlaybackType(ANIMATION_PLAYBACK_ONE_SHOT, 0)
    glint.nagaTimeline:PlayFromStart()
end

local function HideControl(control)
    if not control then
        return
    end
    if control.nagaAlphaTimeline then
        control.nagaAlphaTimeline:Stop()
    end
    control:SetAlpha(0)
    control:SetHidden(true)
end

function BarVisuals:HideFeedback(frame)
    if not frame then
        return
    end
    HideControl(frame.feedbackFlash)
    HideControl(frame.readyFlash)
    HideControl(frame.shieldPulse)
    if frame.lowResourceGlow then
        frame.lowResourceGlow:SetHidden(true)
    end
    if frame.rhythmGlint then
        if frame.rhythmGlint.nagaTimeline then
            frame.rhythmGlint.nagaTimeline:Stop()
        end
        frame.rhythmGlint:SetHidden(true)
    end
end
