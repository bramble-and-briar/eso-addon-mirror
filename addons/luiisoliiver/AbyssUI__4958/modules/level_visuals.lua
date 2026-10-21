local ADDON_NAME = "AbyssUI"

NAGA_UI = NAGA_UI or {}
local NAGA_UI = NAGA_UI
local LevelVisuals = {}
NAGA_UI.LevelVisuals = LevelVisuals

LevelVisuals.SHIMMER_CADENCE_MS = 4200

local CHAMPION_ICON_TEXTURE = "EsoUI/Art/Champion/champion_icon_32.dds"

local function GetChampionIconTexture()
    if ZO_GetChampionPointsIconSmall then
        local texture = ZO_GetChampionPointsIconSmall()
        if texture and texture ~= "" then
            return texture
        end
    end
    return CHAMPION_ICON_TEXTURE
end

local TIERS =
{
    { maximum = 0, textColor = { r = 0.68, g = 0.75, b = 0.84 } },
    { maximum = 599, textColor = { r = 1, g = 1, b = 1 } },
    { maximum = 1199, textColor = { r = 0, g = 1, b = 0 } },
    { maximum = 1799, textColor = { r = 64 / 255, g = 64 / 255, b = 1 } },
    { maximum = 2399, textColor = { r = 160 / 255, g = 32 / 255, b = 240 / 255 }, shimmer = 0.30 },
    { maximum = 2999, textColor = { r = 1, g = 1, b = 0 }, shimmer = 0.50, glowPulse = 0.18 },
    { maximum = 3599, textColor = { r = 1, g = 165 / 255, b = 0 }, shimmer = 0.70, glowPulse = 0.24, doubleSweep = true },
    { maximum = math.huge, textColor = { r = 1, g = 165 / 255, b = 0 }, shimmer = 0.70, glowPulse = 0.24, doubleSweep = true, finishingGlow = true },
}
LevelVisuals.Tiers = TIERS

local function Clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    return math.min(math.max(value, minimum), maximum)
end

local function InterpolateColor(startColor, endColor, progress)
    progress = Clamp(progress, 0, 1)
    return
    {
        r = startColor.r + ((endColor.r - startColor.r) * progress),
        g = startColor.g + ((endColor.g - startColor.g) * progress),
        b = startColor.b + ((endColor.b - startColor.b) * progress),
    }
end

local function ColorChannelToHex(value)
    return math.floor((Clamp(value, 0, 1) * 255) + 0.5)
end

local function SamplePalette(stops, progress)
    local stopCount = stops and #stops or 0
    if stopCount == 0 then
        return { r = 1, g = 1, b = 1 }
    elseif stopCount == 1 then
        return stops[1]
    end
    local paletteIndex = math.floor((Clamp(progress, 0, 1) * (stopCount - 1)) + 0.5) + 1
    return stops[math.min(paletteIndex, stopCount)]
end

local function GetGlyphColor(tier, progress)
    if tier.textColor then
        return tier.textColor
    elseif tier.textStops then
        return SamplePalette(tier.textStops, progress)
    elseif tier.textMid then
        if progress <= 0.5 then
            return InterpolateColor(tier.textStart, tier.textMid, progress * 2)
        end
        return InterpolateColor(tier.textMid, tier.textEnd, (progress - 0.5) * 2)
    end
    return InterpolateColor(tier.textStart, tier.textEnd, progress)
end

function LevelVisuals:GetTier(data)
    if not data or not data.champion then
        return 1, TIERS[1]
    end
    local championPoints = tonumber(data.championPoints) or 0
    for index = 2, #TIERS do
        if championPoints <= TIERS[index].maximum then
            return index, TIERS[index]
        end
    end
    return #TIERS, TIERS[#TIERS]
end

function LevelVisuals:BuildGradientText(plainText, tier, shimmer)
    plainText = tostring(plainText or "")
    local glyphCount = #plainText
    local coloredGlyphs = {}
    for index = 1, glyphCount do
        local progress = glyphCount > 1 and ((index - 1) / (glyphCount - 1)) or 0.5
        local color = GetGlyphColor(tier, progress)
        if shimmer then
            color = InterpolateColor(color, { r = 1, g = 1, b = 1 }, 0.45)
        end
        coloredGlyphs[index] = string.format(
            "|c%02X%02X%02X%s|r",
            ColorChannelToHex(color.r),
            ColorChannelToHex(color.g),
            ColorChannelToHex(color.b),
            string.sub(plainText, index, index))
    end
    return table.concat(coloredGlyphs)
end

function LevelVisuals:Create(parent, options)
    options = options or {}
    local badge = {}
    local font = options.font or "$(BOLD_FONT)|13|outline"
    badge.fontTemplate = font
    badge.height = tonumber(options.height) or 18
    badge.minimumWidth = tonumber(options.minimumWidth) or 34
    badge.maximumWidth = tonumber(options.maximumWidth) or 64
    badge.horizontalPadding = tonumber(options.horizontalPadding) or 10
    badge.showChampionIcon = options.showChampionIcon == true
    badge.championIconSize = tonumber(options.championIconSize) or 14
    badge.championIconGap = tonumber(options.championIconGap) or 2
    badge.fontSize = tonumber(options.fontSize) or tonumber(string.match(font, "|(%d+)|")) or 13

    badge.control = WINDOW_MANAGER:CreateControl(options.name, parent, CT_CONTROL)
    badge.control:SetDimensions(42, badge.height)

    badge.championIcon = WINDOW_MANAGER:CreateControl(nil, badge.control, CT_TEXTURE)
    badge.championIcon:SetDimensions(badge.championIconSize, badge.championIconSize)
    badge.championIcon:SetTexture(options.championIconTexture or GetChampionIconTexture())
    badge.championIcon:SetColor(1, 1, 1, 1)
    badge.championIcon:SetDrawLayer(DL_OVERLAY)
    badge.championIcon:SetDrawLevel(6)
    badge.championIcon:SetHidden(true)

    badge.label = WINDOW_MANAGER:CreateControl(nil, badge.control, CT_LABEL)
    badge.label:SetAnchorFill(badge.control)
    badge.label:SetFont(font)
    badge.label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    badge.label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    badge.label:SetModifyTextType(MODIFY_TEXT_TYPE_NONE)
    badge.label:SetColor(1, 1, 1, 1)
    badge.label:SetDrawLayer(DL_OVERLAY)
    badge.label:SetDrawLevel(5)

    badge.clip = WINDOW_MANAGER:CreateControl(nil, badge.control, CT_CONTROL)
    badge.clip:SetDimensions(10, badge.height)
    badge.clip:SetAutoRectClipChildren(true)
    badge.clip:SetDrawLayer(DL_OVERLAY)
    badge.clip:SetDrawLevel(6)
    badge.clip:SetAlpha(0)
    badge.clip:SetHidden(true)

    badge.content = WINDOW_MANAGER:CreateControl(nil, badge.clip, CT_CONTROL)
    badge.content:SetDimensions(42, badge.height)
    badge.content:SetAnchor(TOPLEFT, badge.clip, TOPLEFT, 0, 0)

    badge.glow = WINDOW_MANAGER:CreateControl(nil, badge.control, CT_LABEL)
    badge.glow:SetAnchorFill(badge.control)
    badge.glow:SetFont(font)
    badge.glow:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    badge.glow:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    badge.glow:SetModifyTextType(MODIFY_TEXT_TYPE_NONE)
    badge.glow:SetColor(1, 1, 1, 1)
    badge.glow:SetDrawLayer(DL_OVERLAY)
    badge.glow:SetDrawLevel(5)
    badge.glow:SetAlpha(0)

    badge.shimmer = WINDOW_MANAGER:CreateControl(nil, badge.content, CT_LABEL)
    badge.shimmer:SetAnchorFill(badge.content)
    badge.shimmer:SetFont(font)
    badge.shimmer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    badge.shimmer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    badge.shimmer:SetModifyTextType(MODIFY_TEXT_TYPE_NONE)
    badge.shimmer:SetColor(1, 1, 1, 1)
    badge.shimmer:SetDrawLayer(DL_OVERLAY)
    badge.shimmer:SetDrawLevel(6)
    badge.shimmer:SetAlpha(1)
    badge.control:SetHandler("OnHide", function() self:Stop(badge) end)
    return badge
end

local function ApplyFontSize(badge, fontSize)
    fontSize = Clamp(fontSize, 8, 32)
    if badge.fontSize == fontSize then
        return
    end

    local font = string.gsub(badge.fontTemplate, "|%d+|", "|" .. fontSize .. "|", 1)
    badge.fontSize = fontSize
    badge.label:SetFont(font)
    badge.glow:SetFont(font)
    badge.shimmer:SetFont(font)
end

local function ApplyContentLayout(badge, championIconVisible, width, textWidth)
    badge.championIcon:SetHidden(not championIconVisible)
    badge.championIcon:ClearAnchors()
    badge.label:ClearAnchors()
    badge.glow:ClearAnchors()
    badge.shimmer:ClearAnchors()
    badge.content:SetDimensions(width, badge.height)

    if not championIconVisible then
        -- Sub-50 level text (L25): center inside the badge so it lines up with the nick midline.
        local textNudge = 2
        badge.label:ClearAnchors()
        badge.label:SetAnchor(CENTER, badge.control, CENTER, 0, textNudge)
        badge.label:SetDimensions(width, badge.height)
        badge.label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        badge.label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        badge.glow:ClearAnchors()
        badge.glow:SetAnchor(CENTER, badge.control, CENTER, 0, textNudge)
        badge.glow:SetDimensions(width, badge.height)
        badge.shimmer:ClearAnchors()
        badge.shimmer:SetAnchor(CENTER, badge.content, CENTER, 0, textNudge)
        badge.shimmer:SetDimensions(width, badge.height)
        return
    end

    local iconSize = badge.championIconSize
    local gap = badge.championIconGap
    local availableTextWidth = math.max(width - iconSize - gap - 2, 1)
    local renderedTextWidth = math.min(math.max(math.ceil(textWidth) + 2, 1), availableTextWidth)
    local contentWidth = iconSize + gap + renderedTextWidth
    local startX = math.max((width - contentWidth) * 0.5, 0)
    local textX = startX + iconSize + gap

    -- Icon on the nick midline; number nudged slightly down.
    local textNudge = 2
    badge.championIcon:ClearAnchors()
    badge.championIcon:SetAnchor(LEFT, badge.control, LEFT, startX, 0)
    badge.label:ClearAnchors()
    badge.label:SetAnchor(LEFT, badge.control, LEFT, textX, textNudge)
    badge.label:SetDimensions(renderedTextWidth, badge.height)
    badge.label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    badge.glow:ClearAnchors()
    badge.glow:SetAnchor(LEFT, badge.control, LEFT, textX, textNudge)
    badge.glow:SetDimensions(renderedTextWidth, badge.height)
    badge.shimmer:ClearAnchors()
    badge.shimmer:SetAnchor(LEFT, badge.content, LEFT, textX, textNudge)
    badge.shimmer:SetDimensions(renderedTextWidth, badge.height)
end

function LevelVisuals:Stop(badge)
    if not badge then
        return
    end
    if badge.timeline then
        badge.timeline:Stop()
    end
    badge.playing = false
    badge.clip:SetAlpha(0)
    badge.clip:SetHidden(true)
    badge.glow:SetAlpha(0)
    badge.glow:SetHidden(true)
end

function LevelVisuals:Play(badge)
    if not badge or (badge.shimmerIntensity or 0) <= 0 or badge.control:IsHidden()
        or badge.playing then
        return
    end
    local width = badge.control:GetWidth()
    local bandWidth = badge.empowered and Clamp(width * 0.34, 10, 18) or Clamp(width * 0.24, 7, 11)
    if not badge.timeline then
        local timeline = ANIMATION_MANAGER:CreateTimeline()
        local function Alpha(control, offset, duration, first, last)
            local animation = timeline:InsertAnimation(ANIMATION_ALPHA, control, offset)
            animation:SetDuration(duration)
            animation:SetAlphaValues(first, last)
            if ZO_EaseInOutQuadratic then
                animation:SetEasingFunction(ZO_EaseInOutQuadratic)
            end
        end
        local function Sweep(offset, strength, reverse)
            local duration = badge.empowered and (reverse and 520 or 880) or 720
            local startX, endX = -bandWidth, width
            if reverse then
                startX, endX = endX, startX
            end
            local sweep = timeline:InsertAnimation(ANIMATION_TRANSLATE, badge.clip, offset)
            sweep:SetDuration(duration)
            sweep:SetTranslateOffsets(startX, 0, endX, 0)
            local counterSweep = timeline:InsertAnimation(ANIMATION_TRANSLATE, badge.content, offset)
            counterSweep:SetDuration(duration)
            counterSweep:SetTranslateOffsets(-startX, 0, -endX, 0)
            -- Matching easing keeps the highlighted digits stationary inside the moving band.
            if badge.empowered and ZO_EaseInOutQuadratic then
                sweep:SetEasingFunction(ZO_EaseInOutQuadratic)
                counterSweep:SetEasingFunction(ZO_EaseInOutQuadratic)
            end
            Alpha(badge.clip, offset, 120, 0, strength)
            Alpha(badge.clip, offset + duration - 180, 180, strength, 0)
            if badge.glowIntensity > 0 then
                local peak = math.floor(duration * 0.4)
                Alpha(badge.glow, offset, peak, 0, badge.glowIntensity * strength)
                Alpha(badge.glow, offset + peak, duration - peak, badge.glowIntensity * strength, 0)
            end
        end
        Sweep(0, 1)
        if badge.doubleSweep then
            Sweep(1040, 0.85, true)
        end
        if badge.finishingGlow then
            Alpha(badge.glow, 1680, 140, 0, 0.65)
            Alpha(badge.glow, 1820, 260, 0.65, 0.16)
            Alpha(badge.glow, 2080, 160, 0.16, 0.42)
            Alpha(badge.glow, 2240, 580, 0.42, 0)
        end
        timeline:SetHandler("OnStop", function()
            badge.playing = false
            badge.clip:SetAlpha(0)
            badge.clip:SetHidden(true)
            badge.glow:SetAlpha(0)
            badge.glow:SetHidden(true)
        end)
        badge.timeline = timeline
    end
    badge.clip:ClearAnchors()
    badge.clip:SetAnchor(TOPLEFT, badge.control, TOPLEFT, 0, 0)
    badge.clip:SetDimensions(bandWidth, badge.height)
    badge.clip:SetHidden(false)
    badge.clip:SetAlpha(0)
    badge.content:ClearAnchors()
    badge.content:SetAnchor(TOPLEFT, badge.clip, TOPLEFT, 0, 0)
    badge.content:SetDimensions(width, badge.height)
    badge.shimmer:SetAlpha(badge.shimmerIntensity)
    badge.glow:SetHidden(false)
    badge.glow:SetAlpha(0)
    badge.playing = true
    badge.timeline:SetPlaybackType(ANIMATION_PLAYBACK_ONE_SHOT, 0)
    badge.timeline:PlayFromStart()
end

function LevelVisuals:Apply(badge, data, options)
    options = options or {}
    local shown = options.shown ~= false
    badge.control:SetHidden(not shown)
    if not shown then
        badge.championIcon:SetHidden(true)
        badge.shimmerIntensity = 0
        badge.glowIntensity = 0
        self:Stop(badge)
        return 0, nil
    end

    data = data or {}
    local tierIndex, tier = self:GetTier(data)
    local text = data.champion and tostring(tonumber(data.championPoints) or 0)
        or string.format("L%d", tonumber(data.level) or 0)
    local styleEnabled = options.styled ~= false
    local fontSize = options.fontSize ~= nil and Clamp(options.fontSize, 8, 32) or badge.fontSize
    if options.height ~= nil then
        badge.height = math.max(tonumber(options.height) or badge.height, fontSize)
    end
    if badge.tierIndex ~= tierIndex or badge.plainText ~= text or badge.styleEnabled ~= styleEnabled
        or badge.appliedFontSize ~= fontSize then
        self:Stop(badge)
        badge.timeline = nil
    end
    ApplyFontSize(badge, fontSize)
    badge.tierIndex = tierIndex
    badge.plainText = text
    badge.styleEnabled = styleEnabled
    badge.appliedFontSize = fontSize
    badge.doubleSweep = tier.doubleSweep == true
    badge.finishingGlow = tier.finishingGlow == true
    badge.empowered = data.champion == true and (tonumber(data.championPoints) or 0) >= 2000
    badge.label:SetColor(1, 1, 1, 1)
    badge.label:SetText(text)
    local textWidth = badge.label.GetStringWidth and tonumber(badge.label:GetStringWidth(text)) or 0
    if textWidth <= 0 then
        textWidth = math.max(math.ceil(#text * badge.fontSize * 0.58), 12)
    end
    if options.championIconSize ~= nil then
        -- Honor CP Icon Size setting directly (not clamped to text height).
        badge.championIconSize = Clamp(options.championIconSize, 8, 36)
        if badge.championIcon then
            badge.championIcon:SetDimensions(badge.championIconSize, badge.championIconSize)
        end
        if badge.championIconSize + 2 > badge.height then
            badge.height = badge.championIconSize + 2
        end
    end
    local championIconVisible = data.champion == true and badge.showChampionIcon == true
    local iconWidth = championIconVisible and (badge.championIconSize + badge.championIconGap) or 0
    local maxWidth = tonumber(options.maximumWidth) or badge.maximumWidth
    local width = math.max(badge.minimumWidth,
        math.min(textWidth + badge.horizontalPadding + iconWidth, maxWidth))
    badge.control:SetDimensions(width, badge.height)
    ApplyContentLayout(badge, championIconVisible, width, textWidth)

    if options.styled ~= false then
        badge.label:SetText(self:BuildGradientText(text, tier, false))
        local effectEligible = data.champion and (tonumber(data.championPoints) or 0) >= 1800
        local effectText = effectEligible and self:BuildGradientText(text, tier, true) or ""
        badge.shimmer:SetText(effectText)
        badge.glow:SetText(effectText)
        badge.shimmerIntensity = effectEligible and (tier.shimmer or 0) or 0
        badge.glowIntensity = effectEligible and (tier.glowPulse or 0) or 0
        if badge.empowered then
            badge.shimmerIntensity = math.min(badge.shimmerIntensity + 0.30, 1)
            badge.glowIntensity = (tier.glowPulse or 0) + 0.22
        end
    else
        badge.label:SetText(text)
        badge.shimmer:SetText("")
        badge.glow:SetText("")
        badge.shimmerIntensity = 0
        badge.glowIntensity = 0
    end

    local hasEffects = badge.shimmerIntensity > 0 or badge.glowIntensity > 0
    if not hasEffects then
        self:Stop(badge)
    end
    if options.styled ~= false and options.playOnTierUpgrade and options.previousTier
        and tierIndex > options.previousTier and hasEffects then
        self:Play(badge)
    end
    return width, tierIndex
end
