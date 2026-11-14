NQOL = NQOL or {}
NQOL.Features = NQOL.Features or {}

local PlayerBars = NQOL.Features.PlayerBars
local Shared = PlayerBars.Shared
local C = PlayerBars.Constants
local Shadow = PlayerBars.Shadow
local Radial = {}
PlayerBars.Radial = Radial

local WIDTH = 210
local HEIGHT = 420
local TEXTURE_ROOT = "Art/PlayerBars/"
local MASKS = {
    [C.RESOURCE_HEALTH] = TEXTURE_ROOT .. "nqol_radial_health.dds",
    [C.RESOURCE_MAGICKA] = TEXTURE_ROOT .. "nqol_radial_outer.dds",
    [C.RESOURCE_STAMINA] = TEXTURE_ROOT .. "nqol_radial_outer.dds",
    [C.RESOURCE_MOUNT_STAMINA] = TEXTURE_ROOT .. "nqol_radial_secondary_outer.dds",
    [COMBAT_MECHANIC_FLAGS_WEREWOLF] = TEXTURE_ROOT .. "nqol_radial_secondary_outer.dds",
    [PlayerBars.SIEGE_HEALTH] = TEXTURE_ROOT .. "nqol_radial_secondary.dds",
}
local OUTER_MASK = TEXTURE_ROOT .. "nqol_radial_outer.dds"
-- Keep directional alpha in the texture: console can discard runtime gradients when a hidden DDS first loads.
local SHADOW_TEXTURES = {
    [MASKS[C.RESOURCE_HEALTH]] = {
        [Shadow.TOP] = TEXTURE_ROOT .. "nqol_radial_shadow_health_top.dds",
        [Shadow.BOTTOM] = TEXTURE_ROOT .. "nqol_radial_shadow_health_bottom.dds",
        [Shadow.LEFT] = TEXTURE_ROOT .. "nqol_radial_shadow_health_left.dds",
        [Shadow.RIGHT] = TEXTURE_ROOT .. "nqol_radial_shadow_health_right.dds",
    },
    [OUTER_MASK] = {
        [Shadow.TOP] = TEXTURE_ROOT .. "nqol_radial_shadow_outer_top.dds",
        [Shadow.BOTTOM] = TEXTURE_ROOT .. "nqol_radial_shadow_outer_bottom.dds",
        [Shadow.LEFT] = TEXTURE_ROOT .. "nqol_radial_shadow_outer_left.dds",
        [Shadow.RIGHT] = TEXTURE_ROOT .. "nqol_radial_shadow_outer_right.dds",
    },
    [MASKS[C.RESOURCE_MOUNT_STAMINA]] = {
        [Shadow.TOP] = TEXTURE_ROOT .. "nqol_radial_shadow_secondary_outer_top.dds",
        [Shadow.BOTTOM] = TEXTURE_ROOT .. "nqol_radial_shadow_secondary_outer_bottom.dds",
        [Shadow.LEFT] = TEXTURE_ROOT .. "nqol_radial_shadow_secondary_outer_left.dds",
        [Shadow.RIGHT] = TEXTURE_ROOT .. "nqol_radial_shadow_secondary_outer_right.dds",
    },
    [MASKS[PlayerBars.SIEGE_HEALTH]] = {
        [Shadow.TOP] = TEXTURE_ROOT .. "nqol_radial_shadow_secondary_top.dds",
        [Shadow.BOTTOM] = TEXTURE_ROOT .. "nqol_radial_shadow_secondary_bottom.dds",
        [Shadow.LEFT] = TEXTURE_ROOT .. "nqol_radial_shadow_secondary_left.dds",
        [Shadow.RIGHT] = TEXTURE_ROOT .. "nqol_radial_shadow_secondary_right.dds",
    },
}
local STACK_BREAK_SIZE = 3
local OUTER_CURVE = {
    { 116, 42 }, { 56, 166 }, { 55, 342 }, { 118, 474 },
}
local TEXTURE_SCALE_X = WIDTH / 256
local INWARD_TIPS = {
    health = { center = 164 * TEXTURE_SCALE_X, halfWidth = 13 * TEXTURE_SCALE_X },
    top = { center = 117 * TEXTURE_SCALE_X, halfWidth = 11 * TEXTURE_SCALE_X },
    bottom = { center = 117 * TEXTURE_SCALE_X, halfWidth = 11 * TEXTURE_SCALE_X },
    outer = { center = 117 * TEXTURE_SCALE_X, halfWidth = 11 * TEXTURE_SCALE_X },
    secondary = { center = 149 * TEXTURE_SCALE_X, halfWidth = 5 * TEXTURE_SCALE_X },
}
local VERTICAL_TEXTURE_BOUNDS = {
    [C.RESOURCE_HEALTH] = { 29 / 512, 487 / 512 },
    [C.RESOURCE_MAGICKA] = { 31 / 512, 266 / 512 },
    [C.RESOURCE_STAMINA] = { 244 / 512, 485 / 512 },
    [C.RESOURCE_MOUNT_STAMINA] = { 49 / 512, 467 / 512 },
    [COMBAT_MECHANIC_FLAGS_WEREWOLF] = { 49 / 512, 467 / 512 },
    [PlayerBars.SIEGE_HEALTH] = { 50 / 512, 466 / 512 },
}
local FULL_OUTER_BOUNDS = { 29 / 512, 487 / 512 }
local BORDER_DIRECTIONS = {
    { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 },
    { -0.707, -0.707 }, { 0.707, -0.707 }, { -0.707, 0.707 }, { 0.707, 0.707 },
}
local BAR_LANE_GAP = 8
local SECONDARY_LANE_WIDTH = 36
local TOP_VALUE_Y = 10
local BOTTOM_VALUE_Y = 414
local MAGICKA_VALUE_X = 42
local STAMINA_VALUE_X = 43

local function GetAddonTexturePath(texture)
    return "/" .. tostring(NQOL.name or "NQOL") .. "/" .. texture
end

local function SetAddonTexture(control, texture)
    control:SetTexture(GetAddonTexturePath(texture))
end

local function MoveAboveHud(control, level)
    Shared.MoveAboveHud(control)
    if control and control.SetDrawLevel then
        control:SetDrawLevel(level)
    end
end

local function CreateTexture(parent, texture, level, red, green, blue, alpha)
    local control = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
    SetAddonTexture(control, texture)
    control:SetColor(red, green, blue, alpha)
    control:SetDimensions(WIDTH, HEIGHT)
    MoveAboveHud(control, level)
    return control
end

local function CreateLabel(parent)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    label:SetFont(NQOL.Util.CreateFontString(NQOL.Util.GetDefaultFont(), 18, "ZoFontGamepad18"))
    label:SetColor(1, 1, 1, 1)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetDimensions(76, 22)
    label:SetDrawLevel(C.DRAW_LEVEL + 8)
    MoveAboveHud(label, C.DRAW_LEVEL + 8)
    return label
end

local function CreateChangeLabel(parent)
    local label = CreateLabel(parent)
    label:SetFont(NQOL.Util.CreateFontString(NQOL.Util.GetDefaultFont(), 30, "ZoFontGamepad34"))
    label:SetAlpha(0)
    label:SetHidden(true)
    return label
end

local function CreateWidget(root, resourceType)
    local widget = WINDOW_MANAGER:CreateControl(nil, root, CT_CONTROL)
    widget:SetDimensions(WIDTH, HEIGHT)
    if widget.SetClipsChildren then
        widget:SetClipsChildren(false)
    end
    widget.resourceType = resourceType
    widget.mask = MASKS[resourceType]

    widget.borderTextures = {}
    for index = 1, #BORDER_DIRECTIONS do
        widget.borderTextures[index] = CreateTexture(widget, widget.mask, C.DRAW_LEVEL, 0.005, 0.005, 0.005, 0.96)
    end

    widget.track = CreateTexture(widget, widget.mask, C.DRAW_LEVEL + 1, 0.015, 0.015, 0.015, 0.82)
    widget.track:SetAnchorFill(widget)
    widget.loss = CreateTexture(widget, widget.mask, C.DRAW_LEVEL + 2, 1, 1, 1, 0)
    widget.fill = CreateTexture(widget, widget.mask, C.DRAW_LEVEL + 3, 1, 1, 1, 1)
    if resourceType == C.RESOURCE_HEALTH then
        widget.trauma = CreateTexture(widget, widget.mask, C.DRAW_LEVEL + 4, C.PLAYER_TRAUMA_COLOR[1], C.PLAYER_TRAUMA_COLOR[2], C.PLAYER_TRAUMA_COLOR[3], C.PLAYER_TRAUMA_COLOR[4])
        widget.trauma:SetHidden(true)
        widget.shield = CreateTexture(widget, widget.mask, C.DRAW_LEVEL + 5, C.PLAYER_SHIELD_COLOR[1], C.PLAYER_SHIELD_COLOR[2], C.PLAYER_SHIELD_COLOR[3], C.PLAYER_SHIELD_COLOR[4])
        widget.shield:SetHidden(true)
        widget.noHealing = CreateTexture(widget, widget.mask, C.DRAW_LEVEL + 6, 0.86, 0.94, 0.96, 0.42)
        widget.noHealing:SetHidden(true)
    end
    widget.shadow = WINDOW_MANAGER:CreateControl(nil, widget, CT_TEXTURE)
    widget.shadow:SetDimensions(WIDTH, HEIGHT)
    widget.shadow:SetColor(1, 1, 1, 1)
    widget.shadow:SetHidden(true)
    MoveAboveHud(widget.shadow, C.DRAW_LEVEL + 7)
    if resourceType == C.RESOURCE_HEALTH or resourceType == C.RESOURCE_MAGICKA or resourceType == C.RESOURCE_STAMINA then
        widget.maximumLabel = CreateLabel(root)
        widget.currentLabel = CreateLabel(root)
        if resourceType == C.RESOURCE_HEALTH then
            widget.maximumLabel:SetDimensions(112, 22)
        end
    else
        widget.icon = WINDOW_MANAGER:CreateControl(nil, root, CT_TEXTURE)
        if resourceType == COMBAT_MECHANIC_FLAGS_WEREWOLF then
            widget.icon:SetTexture(GetAbilityIcon and GetAbilityIcon(32455) or "EsoUI/Art/Icons/ability_werewolf_001.dds")
        elseif resourceType == PlayerBars.SIEGE_HEALTH then
            widget.icon:SetTexture("EsoUI/Art/MapPins/AvA_siegeWeaponry.dds")
        else
            widget.icon:SetTexture("EsoUI/Art/Collections/Default/collections_default_mount.dds")
        end
        widget.icon:SetDimensions(16, 16)
        widget.icon:SetColor(1, 1, 1, 0.92)
        MoveAboveHud(widget.icon, C.DRAW_LEVEL + 8)
    end

    widget.changeLabels = {}
    widget.nextChangeLabelIndex = 1
    for index = 1, C.CLASSIC_CHANGE_POOL_SIZE do
        widget.changeLabels[index] = CreateChangeLabel(root)
    end
    MoveAboveHud(widget, C.DRAW_LEVEL)
    return widget
end

function Radial.CreateControls(root)
    local controls = { widgets = {} }
    for _, resourceType in ipairs(C.RESOURCE_KEYS) do
        controls.widgets[resourceType] = CreateWidget(root, resourceType)
        controls.widgets[resourceType]:SetAnchorFill(root)
    end
    return controls
end

local function SetMirrored(control, mirrored)
    if control and control.SetTextureCoords then
        control:SetTextureCoords(mirrored and 1 or 0, mirrored and 0 or 1, 0, 1)
        control.nqolLeftCoord = nil
        control.nqolRightCoord = nil
        control.nqolFilledTop = nil
        control.nqolFilledBottom = nil
    end
end

local function GetOuterCurvePointAndAngle(progress, mirrored)
    local inverse = 1 - progress
    local p0, p1, p2, p3 = OUTER_CURVE[1], OUTER_CURVE[2], OUTER_CURVE[3], OUTER_CURVE[4]
    local x = inverse * inverse * inverse * p0[1]
        + 3 * inverse * inverse * progress * p1[1]
        + 3 * inverse * progress * progress * p2[1]
        + progress * progress * progress * p3[1]
    local y = inverse * inverse * inverse * p0[2]
        + 3 * inverse * inverse * progress * p1[2]
        + 3 * inverse * progress * progress * p2[2]
        + progress * progress * progress * p3[2]
    local tangentX = 3 * inverse * inverse * (p1[1] - p0[1])
        + 6 * inverse * progress * (p2[1] - p1[1])
        + 3 * progress * progress * (p3[1] - p2[1])
    local tangentY = 3 * inverse * inverse * (p1[2] - p0[2])
        + 6 * inverse * progress * (p2[2] - p1[2])
        + 3 * progress * progress * (p3[2] - p2[2])
    if mirrored then
        x = 256 - x
        tangentX = -tangentX
    end
    -- The cap's flat edge starts horizontal. Rotate it opposite to the curve's
    -- horizontal lean so that the join remains perpendicular to the tangent.
    local curveLean = math.atan2 and math.atan2(tangentX, tangentY) or math.atan(tangentX / tangentY)
    local angle = -curveLean
    return x * WIDTH / 256, y * HEIGHT / 512, angle
end

local function GetOuterCurveProgressForLengthFraction(fraction)
    fraction = NQOL.Util.Clamp(fraction, 0, 1)
    local samples = {}
    local previousX, previousY = GetOuterCurvePointAndAngle(0, false)
    local totalLength = 0
    samples[1] = { progress = 0, length = 0 }
    for index = 1, 40 do
        local progress = index / 40
        local x, y = GetOuterCurvePointAndAngle(progress, false)
        local dx, dy = x - previousX, y - previousY
        totalLength = totalLength + math.sqrt(dx * dx + dy * dy)
        samples[index + 1] = { progress = progress, length = totalLength }
        previousX, previousY = x, y
    end
    local targetLength = totalLength * fraction
    for index = 2, #samples do
        local current = samples[index]
        if current.length >= targetLength then
            local previous = samples[index - 1]
            local segmentLength = current.length - previous.length
            local segmentProgress = segmentLength > 0 and (targetLength - previous.length) / segmentLength or 0
            return previous.progress + (current.progress - previous.progress) * segmentProgress
        end
    end
    return 1
end

local function GetOuterIconPoint(targetY)
    local low, high = 0, 1
    for _ = 1, 12 do
        local middle = (low + high) * 0.5
        local _, y = GetOuterCurvePointAndAngle(middle, false)
        if y < targetY then low = middle else high = middle end
    end
    local x, _, angle = GetOuterCurvePointAndAngle((low + high) * 0.5, false)
    local offset = 50 * WIDTH / 256
    return x + math.cos(angle) * offset, targetY
end

local function LayoutBorder(widget, mirrored, borderSize, bounds)
    local topCoord, bottomCoord = bounds[1], bounds[2]
    for index, direction in ipairs(BORDER_DIRECTIONS) do
        local border = widget.borderTextures[index]
        if borderSize <= 0 then
            border:SetHidden(true)
        else
            border:ClearAnchors()
            border:SetAnchor(TOPLEFT, widget, TOPLEFT, direction[1] * borderSize, direction[2] * borderSize + HEIGHT * topCoord)
            border:SetDimensions(WIDTH, math.max(1, HEIGHT * (bottomCoord - topCoord)))
            border:SetTextureCoords(mirrored and 1 or 0, mirrored and 0 or 1, topCoord, bottomCoord)
            border:SetHidden(false)
        end
    end
end

local function LayoutTextureSegment(control, bounds, mirrored)
    local topCoord, bottomCoord = bounds[1], bounds[2]
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, control:GetParent(), TOPLEFT, 0, HEIGHT * topCoord)
    control:SetDimensions(WIDTH, math.max(1, HEIGHT * (bottomCoord - topCoord)))
    control:SetTextureCoords(mirrored and 1 or 0, mirrored and 0 or 1, topCoord, bottomCoord)
end

local function SetWidgetMask(widget, texture, bounds, inverseFill, mirrored, borderSize, tip, showBorder, borderBounds)
    widget.mask = texture
    widget.verticalBounds = bounds
    widget.inverseFill = inverseFill == true
    widget.mirrored = mirrored == true
    widget.inwardExtent = tip.center + tip.halfWidth + borderSize
    widget.outwardExtent = tip.center - tip.halfWidth - borderSize
    SetAddonTexture(widget.track, texture)
    widget.track:SetHidden(false)
    SetAddonTexture(widget.fill, texture)
    SetAddonTexture(widget.loss, texture)
    if widget.trauma then
        SetAddonTexture(widget.trauma, texture)
    end
    if widget.shield then
        SetAddonTexture(widget.shield, texture)
    end
    if widget.noHealing then
        SetAddonTexture(widget.noHealing, texture)
    end
    LayoutTextureSegment(widget.track, bounds, mirrored)
    LayoutTextureSegment(widget.shadow, bounds, mirrored)
    SetMirrored(widget.fill, mirrored)
    SetMirrored(widget.loss, mirrored)
    SetMirrored(widget.trauma, mirrored)
    SetMirrored(widget.shield, mirrored)
    SetMirrored(widget.noHealing, mirrored)
    for _, border in ipairs(widget.borderTextures) do
        SetAddonTexture(border, texture)
    end
    if showBorder == false then
        for _, border in ipairs(widget.borderTextures) do
            border:SetHidden(true)
        end
    else
        LayoutBorder(widget, mirrored, borderSize, borderBounds or bounds)
    end
end

local function LayoutShadow(widget, settings)
    local shadow = widget.shadow
    local direction = settings.shadow
    local alpha = NQOL.Util.Clamp(tonumber(settings.shadowIntensity) or 0, 0, 100) * 0.01
    if direction == Shadow.NONE or not Shadow.VALID[direction] or alpha <= 0 then
        shadow:SetHidden(true)
        return
    end

    local textureDirection = direction
    if widget.mirrored == true then
        if direction == Shadow.LEFT then textureDirection = Shadow.RIGHT
        elseif direction == Shadow.RIGHT then textureDirection = Shadow.LEFT end
    end
    local textureSet = SHADOW_TEXTURES[widget.mask]
    local texture = textureSet and textureSet[textureDirection]
    if not texture then
        shadow:SetHidden(true)
        return
    end

    if shadow.nqolTexture ~= texture then
        shadow.nqolTexture = texture
        SetAddonTexture(shadow, texture)
    end
    shadow:SetAlpha(alpha)
    shadow:SetHidden(false)
end

local function GetWidgetX(widget, side, screenCenter, halfGap)
    local inwardExtent = widget.inwardExtent or WIDTH * 0.5
    if side == C.FLYING_ORIENTATION_LEFT then
        return screenCenter - halfGap - inwardExtent
    end
    return screenCenter + halfGap - (WIDTH - inwardExtent)
end

local function MoveLaneOutward(x, side, laneIndex, borderSize, secondaryOffset)
    local laneOffset = laneIndex * (22 + borderSize * 2 + BAR_LANE_GAP) + secondaryOffset
    return side == C.FLYING_ORIENTATION_LEFT and x - laneOffset or x + laneOffset
end

local function IsSecondaryVisible(resourceValues, resourceType)
    local value = resourceValues and resourceValues[resourceType]
    return value ~= nil and value.hidden ~= true
end

local function AnchorLabel(label, root, originX, originY, x, y, mirrored)
    label:ClearAnchors()
    label:SetAnchor(CENTER, root, TOPLEFT, originX + (mirrored and WIDTH - x or x), originY + y)
end

local function LayoutFullBarLabels(widget, root, originX, originY, x, mirrored)
    widget.currentLabel:SetHidden(false)
    widget.maximumLabel:SetHidden(false)
    AnchorLabel(widget.currentLabel, root, originX, originY, x, TOP_VALUE_Y, mirrored)
    AnchorLabel(widget.maximumLabel, root, originX, originY, x, BOTTOM_VALUE_Y, mirrored)
end

local function LayoutStackedBarLabels(widget, root, originX, originY, x, mirrored, first)
    widget.maximumLabel:SetHidden(true)
    widget.currentLabel:SetHidden(false)
    AnchorLabel(widget.currentLabel, root, originX, originY, x, first and TOP_VALUE_Y or BOTTOM_VALUE_Y, mirrored)
end

local function GetHealthValueLabelX(healthWidget, resourceWidget)
    local healthExtent = healthWidget.inwardExtent or WIDTH * 0.5
    local resourceExtent = resourceWidget.inwardExtent or WIDTH * 0.5
    return math.max(healthExtent - resourceExtent + (MAGICKA_VALUE_X + STAMINA_VALUE_X) * 0.5, 0)
end

local function GetLaneValueLabelX(widget, normalX, laneIndex, outermostLane)
    local inwardExtent = widget.inwardExtent or WIDTH * 0.5
    local outwardExtent = widget.outwardExtent or WIDTH * 0.5
    local normalGap = math.max(outwardExtent - normalX, 0) * 0.5
    if laneIndex == outermostLane then
        return math.max(outwardExtent - normalGap, 0)
    end
    if laneIndex > 0 then
        return (inwardExtent + outwardExtent) * 0.5
    end
    return math.min(inwardExtent + normalGap, WIDTH)
end

function Radial.Layout(preset, resourceValues)
    local root = preset.root
    local controls = preset.controls
    local settings = Shared.GetRadialSettings()
    Shared.ApplyChangeFont(preset)
    local screenWidth = Shared.GetScreenWidth()
    local screenHeight = Shared.GetScreenHeight()
    local responsiveScale = math.min(1, screenHeight / 1080)
    local scale = responsiveScale * NQOL.Util.Clamp(settings.scale or 100, C.RADIAL_SCALE_MIN, C.RADIAL_SCALE_MAX) * 0.01
    local logicalWidth = screenWidth / scale
    local logicalHeight = screenHeight / scale
    local screenCenter = logicalWidth * 0.5
    local halfGap = math.max(screenCenter - WIDTH, 0) * settings.horizontalPosition * 0.01
    local clusterY = math.max(logicalHeight - HEIGHT, 0) * settings.verticalPosition * 0.01

    root:SetDimensions(logicalWidth, logicalHeight)
    root:SetScale(scale)

    local borderSize = settings.borderSize
    local stacked = settings.stack ~= C.RADIAL_STACK_NOTHING
    local healthMirrored = settings.healthSide == C.FLYING_ORIENTATION_RIGHT
    local magickaSide = stacked and settings.stackPosition or settings.magickaSide
    local staminaSide = stacked and settings.stackPosition or settings.staminaSide
    local magickaMirrored = magickaSide == C.FLYING_ORIENTATION_RIGHT
    local staminaMirrored = staminaSide == C.FLYING_ORIENTATION_RIGHT
    local stackSplit = preset.radialSplit or 0.5
    local _, splitY = GetOuterCurvePointAndAngle(stackSplit, false)
    local splitCoord = splitY / HEIGHT
    local halfBreakCoord = STACK_BREAK_SIZE / (HEIGHT * 2)
    local topBounds = { FULL_OUTER_BOUNDS[1], splitCoord - halfBreakCoord }
    local bottomBounds = { splitCoord + halfBreakCoord, FULL_OUTER_BOUNDS[2] }

    SetWidgetMask(controls.widgets[C.RESOURCE_HEALTH], MASKS[C.RESOURCE_HEALTH], VERTICAL_TEXTURE_BOUNDS[C.RESOURCE_HEALTH], false, healthMirrored, borderSize, INWARD_TIPS.health)
    if settings.stack == C.RADIAL_STACK_MAGICKA_STAMINA then
        SetWidgetMask(controls.widgets[C.RESOURCE_MAGICKA], OUTER_MASK, topBounds, false, magickaMirrored, borderSize, INWARD_TIPS.top, true, FULL_OUTER_BOUNDS)
        SetWidgetMask(controls.widgets[C.RESOURCE_STAMINA], OUTER_MASK, bottomBounds, true, staminaMirrored, borderSize, INWARD_TIPS.bottom, false)
        LayoutTextureSegment(controls.widgets[C.RESOURCE_MAGICKA].track, FULL_OUTER_BOUNDS, magickaMirrored)
        controls.widgets[C.RESOURCE_STAMINA].track:SetHidden(true)
    elseif settings.stack == C.RADIAL_STACK_STAMINA_MAGICKA then
        SetWidgetMask(controls.widgets[C.RESOURCE_STAMINA], OUTER_MASK, topBounds, false, staminaMirrored, borderSize, INWARD_TIPS.top, true, FULL_OUTER_BOUNDS)
        SetWidgetMask(controls.widgets[C.RESOURCE_MAGICKA], OUTER_MASK, bottomBounds, true, magickaMirrored, borderSize, INWARD_TIPS.bottom, false)
        LayoutTextureSegment(controls.widgets[C.RESOURCE_STAMINA].track, FULL_OUTER_BOUNDS, staminaMirrored)
        controls.widgets[C.RESOURCE_MAGICKA].track:SetHidden(true)
    else
        SetWidgetMask(controls.widgets[C.RESOURCE_MAGICKA], OUTER_MASK, FULL_OUTER_BOUNDS, false, magickaMirrored, borderSize, INWARD_TIPS.outer)
        SetWidgetMask(controls.widgets[C.RESOURCE_STAMINA], OUTER_MASK, FULL_OUTER_BOUNDS, false, staminaMirrored, borderSize, INWARD_TIPS.outer)
    end
    local labelFont = NQOL.Util.CreateFontString(settings.font, settings.fontSize, "ZoFontGamepad18")
    for _, widget in pairs(controls.widgets) do
        if widget.currentLabel then widget.currentLabel:SetFont(labelFont); widget.maximumLabel:SetFont(labelFont) end
    end
    local healthX = GetWidgetX(controls.widgets[C.RESOURCE_HEALTH], settings.healthSide, screenCenter, halfGap)
    local magickaX = GetWidgetX(controls.widgets[C.RESOURCE_MAGICKA], magickaSide, screenCenter, halfGap)
    local staminaX = GetWidgetX(controls.widgets[C.RESOURCE_STAMINA], staminaSide, screenCenter, halfGap)
    local laneCounts = {
        [C.FLYING_ORIENTATION_LEFT] = 0,
        [C.FLYING_ORIENTATION_RIGHT] = 0,
    }
    local secondaryOffsets = {
        [C.FLYING_ORIENTATION_LEFT] = 0,
        [C.FLYING_ORIENTATION_RIGHT] = 0,
    }
    local healthLane = laneCounts[settings.healthSide]
    healthX = MoveLaneOutward(healthX, settings.healthSide, healthLane, borderSize, 0)
    laneCounts[settings.healthSide] = laneCounts[settings.healthSide] + 1
    local magickaLane = laneCounts[magickaSide]
    -- An extra bar reaches inward from its parent. Open space before that
    -- lane only while needed, then carry the offset to later lanes on its side.
    if magickaLane > 0 and (IsSecondaryVisible(resourceValues, COMBAT_MECHANIC_FLAGS_WEREWOLF)
        or (stacked and IsSecondaryVisible(resourceValues, C.RESOURCE_MOUNT_STAMINA))) then
        secondaryOffsets[magickaSide] = secondaryOffsets[magickaSide] + SECONDARY_LANE_WIDTH
    end
    magickaX = MoveLaneOutward(magickaX, magickaSide, magickaLane, borderSize, secondaryOffsets[magickaSide])
    local staminaLane
    if stacked then
        staminaX = magickaX
        staminaLane = magickaLane
        laneCounts[magickaSide] = laneCounts[magickaSide] + 1
    else
        laneCounts[magickaSide] = laneCounts[magickaSide] + 1
        staminaLane = laneCounts[staminaSide]
        if staminaLane > 0 and IsSecondaryVisible(resourceValues, C.RESOURCE_MOUNT_STAMINA) then
            secondaryOffsets[staminaSide] = secondaryOffsets[staminaSide] + SECONDARY_LANE_WIDTH
        end
        staminaX = MoveLaneOutward(staminaX, staminaSide, staminaLane, borderSize, secondaryOffsets[staminaSide])
        laneCounts[staminaSide] = laneCounts[staminaSide] + 1
    end

    for resourceType, widget in pairs(controls.widgets) do
        local mirrored = healthMirrored
        local widgetX = healthX
        if resourceType == C.RESOURCE_MAGICKA then
            mirrored = magickaMirrored
            widgetX = magickaX
        elseif resourceType == C.RESOURCE_STAMINA then
            mirrored = staminaMirrored
            widgetX = staminaX
        elseif resourceType ~= C.RESOURCE_HEALTH then
            local secondaryBounds = VERTICAL_TEXTURE_BOUNDS[resourceType]
            local secondaryInverse = false
            widgetX = healthX
                widget.secondaryIconX = 136
            widget.secondaryIconY = 210
            if resourceType == C.RESOURCE_MOUNT_STAMINA then
                mirrored = staminaMirrored
                widgetX = staminaX
                if stacked then
                    local staminaFirst = settings.stack == C.RADIAL_STACK_STAMINA_MAGICKA
                    local split = topBounds[2]
                    local visibleBounds = VERTICAL_TEXTURE_BOUNDS[resourceType]
                    secondaryBounds = staminaFirst
                        and { visibleBounds[1], math.max(split, visibleBounds[1] + 1 / HEIGHT) }
                        or { math.min(split + STACK_BREAK_SIZE / HEIGHT, visibleBounds[2] - 1 / HEIGHT), visibleBounds[2] }
                    secondaryInverse = not staminaFirst
                end
            elseif resourceType == COMBAT_MECHANIC_FLAGS_WEREWOLF then
                mirrored = magickaMirrored
                widgetX = magickaX
                if stacked then
                    local magickaFirst = settings.stack == C.RADIAL_STACK_MAGICKA_STAMINA
                    local split = topBounds[2]
                    local visibleBounds = VERTICAL_TEXTURE_BOUNDS[resourceType]
                    secondaryBounds = magickaFirst
                        and { visibleBounds[1], math.max(split, visibleBounds[1] + 1 / HEIGHT) }
                        or { math.min(split + STACK_BREAK_SIZE / HEIGHT, visibleBounds[2] - 1 / HEIGHT), visibleBounds[2] }
                    secondaryInverse = not magickaFirst
                end
            end
            local segmentCenterY = HEIGHT * (secondaryBounds[1] + secondaryBounds[2]) * 0.5
            if resourceType == C.RESOURCE_MOUNT_STAMINA or resourceType == COMBAT_MECHANIC_FLAGS_WEREWOLF then
                widget.secondaryIconX, widget.secondaryIconY = GetOuterIconPoint(segmentCenterY)
            else
                widget.secondaryIconY = segmentCenterY
            end
            SetWidgetMask(widget, MASKS[resourceType], secondaryBounds, secondaryInverse, mirrored, borderSize, INWARD_TIPS.secondary)
        end

        widget:ClearAnchors()
        widget:SetDimensions(WIDTH, HEIGHT)
        widget:SetAnchor(TOPLEFT, root, TOPLEFT, widgetX, clusterY)
        if widget.icon then
            AnchorLabel(widget.icon, root, widgetX, clusterY, widget.secondaryIconX, widget.secondaryIconY, mirrored)
        end
        for _, changeLabel in ipairs(widget.changeLabels) do
            AnchorLabel(changeLabel, root, widgetX, clusterY, resourceType == C.RESOURCE_HEALTH and 146 or 42, 210, mirrored)
        end
    end

    for _, widget in pairs(controls.widgets) do
        LayoutShadow(widget, settings)
    end

    local health = controls.widgets[C.RESOURCE_HEALTH]
    local magicka = controls.widgets[C.RESOURCE_MAGICKA]
    local stamina = controls.widgets[C.RESOURCE_STAMINA]
    local healthValueX = GetLaneValueLabelX(health, GetHealthValueLabelX(health, magicka), healthLane, laneCounts[settings.healthSide] - 1)
    local magickaValueX = GetLaneValueLabelX(magicka, MAGICKA_VALUE_X, magickaLane, laneCounts[magickaSide] - 1)
    local staminaValueX = GetLaneValueLabelX(stamina, STAMINA_VALUE_X, staminaLane, laneCounts[staminaSide] - 1)
    LayoutFullBarLabels(health, root, healthX, clusterY, healthValueX, healthMirrored)
    if stacked then
        local magickaFirst = settings.stack == C.RADIAL_STACK_MAGICKA_STAMINA
        LayoutStackedBarLabels(magicka, root, magickaX, clusterY, magickaValueX, magickaMirrored, magickaFirst)
        LayoutStackedBarLabels(stamina, root, staminaX, clusterY, staminaValueX, staminaMirrored, not magickaFirst)
    else
        LayoutFullBarLabels(magicka, root, magickaX, clusterY, magickaValueX, magickaMirrored)
        LayoutFullBarLabels(stamina, root, staminaX, clusterY, staminaValueX, staminaMirrored)
    end
end

local function SetClippedTexture(control, percent, alpha, widget)
    percent = NQOL.Util.Clamp(percent, 0, 1)
    if percent <= 0 then
        if control.nqolHidden ~= true then
            control:SetHidden(true)
            control.nqolHidden = true
        end
        return
    end

    local bounds = widget.verticalBounds
    local topCoord = bounds and bounds[1] or 0
    local bottomCoord = bounds and bounds[2] or 1
    local span = bottomCoord - topCoord
    local filledSpan = span * percent
    local inverse = widget.inverseFill == true
    local filledTop = inverse and topCoord or bottomCoord - filledSpan
    local filledBottom = inverse and topCoord + filledSpan or bottomCoord
    -- Keep position and height on the same fractional scale as the full track.
    -- Bottom anchoring or rounding the height can leave a stale-looking offset
    -- when ESO changes a resource maximum during rapid power updates.
    local y = HEIGHT * filledTop
    if control.nqolY ~= y then
        control:ClearAnchors()
        control:SetAnchor(TOPLEFT, control:GetParent(), TOPLEFT, 0, y)
        control.nqolY = y
    end

    local fillHeight = math.max(1, HEIGHT * filledSpan)
    if control.nqolWidth ~= WIDTH or control.nqolHeight ~= fillHeight then
        control:SetDimensions(WIDTH, fillHeight)
        control.nqolWidth = WIDTH
        control.nqolHeight = fillHeight
    end

    local mirrored = widget.mirrored == true
    local leftCoord = mirrored and 1 or 0
    local rightCoord = mirrored and 0 or 1
    if control.nqolLeftCoord ~= leftCoord
        or control.nqolRightCoord ~= rightCoord
        or control.nqolFilledTop ~= filledTop
        or control.nqolFilledBottom ~= filledBottom
    then
        control:SetTextureCoords(leftCoord, rightCoord, filledTop, filledBottom)
        control.nqolLeftCoord = leftCoord
        control.nqolRightCoord = rightCoord
        control.nqolFilledTop = filledTop
        control.nqolFilledBottom = filledBottom
    end
    if alpha and control.nqolAlpha ~= alpha then
        control:SetAlpha(alpha)
        control.nqolAlpha = alpha
    end
    if control.nqolHidden ~= false then
        control:SetHidden(false)
        control.nqolHidden = false
    end
end

local function SetClippedTextureRange(control, startPercent, endPercent, alpha, widget)
    if not control then
        return
    end

    startPercent = NQOL.Util.Clamp(startPercent, 0, 1)
    endPercent = NQOL.Util.Clamp(endPercent, startPercent, 1)
    if endPercent <= startPercent then
        if control.nqolHidden ~= true then
            control:SetHidden(true)
            control.nqolHidden = true
        end
        return
    end

    local bounds = widget.verticalBounds
    local topCoord = bounds and bounds[1] or 0
    local bottomCoord = bounds and bounds[2] or 1
    local span = bottomCoord - topCoord
    local inverse = widget.inverseFill == true
    local filledTop = inverse and topCoord + span * startPercent or bottomCoord - span * endPercent
    local filledBottom = inverse and topCoord + span * endPercent or bottomCoord - span * startPercent
    local y = HEIGHT * filledTop
    if control.nqolY ~= y then
        control:ClearAnchors()
        control:SetAnchor(TOPLEFT, control:GetParent(), TOPLEFT, 0, y)
        control.nqolY = y
    end
    local fillHeight = math.max(1, HEIGHT * (filledBottom - filledTop))
    if control.nqolWidth ~= WIDTH or control.nqolHeight ~= fillHeight then
        control:SetDimensions(WIDTH, fillHeight)
        control.nqolWidth = WIDTH
        control.nqolHeight = fillHeight
    end
    local mirrored = widget.mirrored == true
    local leftCoord = mirrored and 1 or 0
    local rightCoord = mirrored and 0 or 1
    if control.nqolLeftCoord ~= leftCoord
        or control.nqolRightCoord ~= rightCoord
        or control.nqolFilledTop ~= filledTop
        or control.nqolFilledBottom ~= filledBottom
    then
        control:SetTextureCoords(leftCoord, rightCoord, filledTop, filledBottom)
        control.nqolLeftCoord = leftCoord
        control.nqolRightCoord = rightCoord
        control.nqolFilledTop = filledTop
        control.nqolFilledBottom = filledBottom
    end
    alpha = alpha or 1
    if control.nqolAlpha ~= alpha then
        control:SetAlpha(alpha)
        control.nqolAlpha = alpha
    end
    if control.nqolHidden ~= false then
        control:SetHidden(false)
        control.nqolHidden = false
    end
end

local function SetLabelText(label, text)
    if label and label.nqolText ~= text then
        label:SetText(text)
        label.nqolText = text
    end
end

local function ApplyWidget(widget, resourceValue, resourceType, settings, staticUpdate, smoothUpdate)
    if not widget or not resourceValue then
        return
    end
    if staticUpdate then
        widget:SetHidden(resourceValue.hidden == true)
        if widget.icon then
            widget.icon:SetHidden(resourceValue.hidden == true)
        end
    end
    if resourceValue.hidden == true then
        if staticUpdate then
            SetClippedTexture(widget.loss, 0, 0, widget)
            if widget.trauma then
                SetClippedTextureRange(widget.trauma, 0, 0, 0, widget)
            end
            if widget.shield then
                SetClippedTextureRange(widget.shield, 0, 0, 0, widget)
            end
            if widget.noHealing then
                SetClippedTextureRange(widget.noHealing, 0, 0, 0, widget)
            end
            if PlayerBars.Smooth then
                if resourceType == C.RESOURCE_HEALTH then
                    PlayerBars.ResetPlayerHealthAnimations(widget)
                else
                    PlayerBars.Smooth.Reset(widget, resourceType)
                end
            end
        end
        return
    end

    local maximum = math.max(1, resourceValue.maximum)
    local current = resourceValue.current
    local traumaAmount = 0
    local shieldAmount = 0
    settings = settings or Shared.GetRadialSettings()
    if resourceType == C.RESOURCE_HEALTH then
        if not widget.nqolRadialSmoothUpdateCallback then
            widget.nqolRadialSmoothUpdateCallback = function()
                ApplyWidget(widget, resourceValue, resourceType, settings, false, true)
            end
        end
        current, traumaAmount, shieldAmount = PlayerBars.GetAnimatedPlayerHealthSegments(widget, resourceValue, settings, widget.nqolRadialSmoothUpdateCallback)
    elseif settings.smoothTransitions == true and PlayerBars.Smooth then
        if not widget.nqolRadialSmoothUpdateCallback then
            widget.nqolRadialSmoothUpdateCallback = function()
                ApplyWidget(widget, resourceValue, resourceType, settings, false, true)
            end
        end
        current = PlayerBars.Smooth.GetValue(widget, resourceType, current, widget.nqolRadialSmoothUpdateCallback, maximum)
    elseif staticUpdate and PlayerBars.Smooth then
        PlayerBars.Smooth.Reset(widget, resourceType)
    end

    if staticUpdate then
        local red, green, blue, alpha = Shared.GetPlayerResourceColor(settings, resourceType)
        widget:SetAlpha(1)
        widget.fill:SetColor(red, green, blue, alpha)
        widget.loss:SetColor(red, green, blue, alpha)
    end
    SetClippedTexture(widget.fill, current / maximum, 1, widget)
    if widget.trauma then
        if staticUpdate then
            local traumaRed, traumaGreen, traumaBlue, traumaAlpha = Shared.GetPlayerTraumaColor(settings)
            widget.trauma:SetColor(traumaRed, traumaGreen, traumaBlue, traumaAlpha)
            local shieldRed, shieldGreen, shieldBlue, shieldAlpha = Shared.GetPlayerShieldColor(settings)
            widget.shield:SetColor(shieldRed, shieldGreen, shieldBlue, shieldAlpha)
        end
        SetClippedTextureRange(widget.trauma, current / maximum, (current + traumaAmount) / maximum, 1, widget)
    end
    if widget.shield then
        local shieldStart = current + traumaAmount
        local visibleShieldAmount = math.min(shieldAmount, maximum)
        SetClippedTextureRange(widget.shield, shieldStart / maximum, (shieldStart + visibleShieldAmount) / maximum, 1, widget)
    end
    if widget.noHealing then
        local noHealingAmount = PlayerBars.GetNoHealingHealthAmount(current, PlayerBars.GetHealthVisualValues())
        SetClippedTextureRange(widget.noHealing, 0, noHealingAmount / maximum, 1, widget)
    end
    if settings.smoothTransitions == true and settings.transitionShadow == true and PlayerBars.Smooth then
        local lossValue, lossAlpha = PlayerBars.Smooth.GetLoss(widget, resourceType)
        SetClippedTexture(widget.loss, lossValue / maximum, lossAlpha, widget)
    elseif staticUpdate then
        SetClippedTexture(widget.loss, 0, 0, widget)
    end

    if widget.maximumLabel then
        if staticUpdate then
            local maximumText = Shared.FormatCompactNumber(resourceValue.maximum)
            if resourceType == C.RESOURCE_HEALTH and PlayerBars.GetHealthVisualValues then
                local visuals = PlayerBars.GetHealthVisualValues()
                if visuals.shield > 0 then
                    maximumText = maximumText .. " + " .. Shared.FormatCompactNumber(visuals.shield)
                end
            end
            SetLabelText(widget.maximumLabel, maximumText)
        end
        if not smoothUpdate then
            SetLabelText(widget.currentLabel, Shared.FormatCurrentValue(resourceValue, maximum, settings.currentValue, true))
        end
    end
end

local function UpdateResourceSplit(preset, resourceValues, settings)
    local magickaMaximum = tonumber(resourceValues[C.RESOURCE_MAGICKA] and resourceValues[C.RESOURCE_MAGICKA].maximum) or 0
    local staminaMaximum = tonumber(resourceValues[C.RESOURCE_STAMINA] and resourceValues[C.RESOURCE_STAMINA].maximum) or 0
    if preset.radialStack ~= settings.stack
        or preset.radialStackType ~= settings.stackType
        or preset.radialMagickaMaximum ~= magickaMaximum
        or preset.radialStaminaMaximum ~= staminaMaximum
    then
        local stackSplit = GetOuterCurveProgressForLengthFraction(0.5)
        local combinedMaximum = math.max(magickaMaximum + staminaMaximum, 0)
        if settings.stack ~= C.RADIAL_STACK_NOTHING and settings.stackType == C.RADIAL_STACK_TYPE_RELATIVE and combinedMaximum > 0 then
            local topMaximum = settings.stack == C.RADIAL_STACK_MAGICKA_STAMINA and magickaMaximum or staminaMaximum
            stackSplit = GetOuterCurveProgressForLengthFraction(topMaximum / combinedMaximum)
        end
        preset.radialStack = settings.stack
        preset.radialStackType = settings.stackType
        preset.radialMagickaMaximum = magickaMaximum
        preset.radialStaminaMaximum = staminaMaximum
        if preset.radialSplit ~= stackSplit then
            preset.radialSplit = stackSplit
            Radial.Layout(preset, resourceValues)
            return true
        end
    end
    return false
end

function Radial.ApplyResource(preset, resourceValues, resourceType, settings, staticUpdate)
    settings = settings or Shared.GetRadialSettings()
    local splitChanged = false
    if resourceType == C.RESOURCE_MAGICKA or resourceType == C.RESOURCE_STAMINA then
        splitChanged = UpdateResourceSplit(preset, resourceValues, settings)
    end

    if splitChanged then
        -- A relative stack split changes the bounds of both primary resources
        -- and their secondary overlays, so every crop must be updated together.
        for _, updatedResourceType in ipairs(C.RESOURCE_KEYS) do
            ApplyWidget(preset.controls.widgets[updatedResourceType], resourceValues[updatedResourceType], updatedResourceType, settings, true)
        end
        return
    end

    ApplyWidget(preset.controls.widgets[resourceType], resourceValues[resourceType], resourceType, settings, staticUpdate)
end

function Radial.ApplyResources(preset, resourceValues)
    local settings = Shared.GetRadialSettings()
    UpdateResourceSplit(preset, resourceValues, settings)

    for _, resourceType in ipairs(C.RESOURCE_KEYS) do
        ApplyWidget(preset.controls.widgets[resourceType], resourceValues[resourceType], resourceType, settings, true)
    end

end

function Radial.GetAnimationSettings()
    return Shared.GetRadialSettings()
end

function Radial.GetChangeDirection(resourceType, settings)
    settings = settings or Shared.GetRadialSettings()
    local side = settings.healthSide
    if resourceType == C.RESOURCE_MAGICKA then
        side = settings.stack == C.RADIAL_STACK_NOTHING and settings.magickaSide or settings.stackPosition
    elseif resourceType == C.RESOURCE_STAMINA then
        side = settings.stack == C.RADIAL_STACK_NOTHING and settings.staminaSide or settings.stackPosition
    end
    return side
end
