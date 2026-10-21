local function T(s)
    if NAGA_UI and NAGA_UI.T then return NAGA_UI.T(s) end
    return s
end

local ADDON_NAME = "AbyssUI"
local EVENT_NAMESPACE = ADDON_NAME .. "_PvP"

NAGA_UI = NAGA_UI or {}
local NAGA_UI = NAGA_UI
local PvP = {}
NAGA_UI.PvP = PvP

local DEFAULT_SETTINGS =
{
    enabled = true,
    unlocked = false,
    scale = 100,
    intensity = 100,
    soundEnabled = true,
    chainEnabled = true,
    includeDuels = true,
}

local DEFAULT_POSITION = { x = 0, y = 140 }
local ROOT_WIDTH = 420
local ROOT_HEIGHT = 150
local BATCH_WINDOW_MS = 120
local DUPLICATE_WINDOW_MS = 1500
local SOUND_COOLDOWN_MS = 300
local CHAIN_WINDOW_MS = 3500
local MAX_CHAIN = 8
local HOLD_END_MS = 610
local ANIMATION_MS = 950
local EDGE_TEXTURE = "EsoUI/Art/Miscellaneous/Gamepad/edgeframeGamepadBorder_thin.dds"

local SOUND_KEYS_BY_CHAIN =
{
    [1] = "CHAMPION_STAR_STAGE_UP",
    [2] = "VENGEANCE_PERK_DROP",
    [3] = "VENGEANCE_PERK_DROP",
    [4] = "VENGEANCE_PERK_EQUIPPED",
    [5] = "VENGEANCE_PERK_EQUIPPED",
    [6] = "BATTLEGROUND_ROUND_RECAP_SCREEN_WIN",
    [7] = "BATTLEGROUND_ROUND_RECAP_SCREEN_WIN",
    [8] = "BATTLEGROUND_ROUND_RECAP_SCREEN_FINAL_WIN",
}

local FALLBACK_SOUND_KEYS =
{
    "CODE_REDEMPTION_SUCCESS",
    "BATTLEGROUND_LEAVE_MATCH",
}

local function ClampNumber(value, minimum, maximum)
    value = tonumber(value) or minimum
    return math.min(math.max(value, minimum), maximum)
end

local function EaseOutCubic(progress)
    local inverse = 1 - progress
    return 1 - inverse * inverse * inverse
end

local function EaseOutBack(progress)
    local c1 = 1.70158
    local c3 = c1 + 1
    local offset = progress - 1
    return 1 + c3 * offset * offset * offset + c1 * offset * offset
end

local function EaseInCubic(progress)
    return progress * progress * progress
end

local function NormalizeDisplayName(value)
    value = tostring(value or "")
    if zo_strlower then
        return zo_strlower(value)
    end
    return string.lower(value)
end

local function GetSettings()
    if NAGA_UI.Settings and NAGA_UI.Settings.GetPvP then
        return NAGA_UI.Settings:GetPvP()
    end
    return DEFAULT_SETTINGS
end

local function GetSettingValue(key)
    local settings = GetSettings()
    local value = settings and settings[key]
    if value == nil then
        return DEFAULT_SETTINGS[key]
    end
    return value
end

local function GetPosition()
    if NAGA_UI.Settings and NAGA_UI.Settings.GetPvPPosition then
        return NAGA_UI.Settings:GetPvPPosition()
    end
    return DEFAULT_POSITION
end

local function IsModuleEnabled()
    return GetSettingValue("enabled") == true
end

local function IsModuleUnlocked()
    return GetSettingValue("unlocked") == true
end

local function AreSoundsEnabled()
    return GetSettingValue("soundEnabled") == true
end

local function IsChainEnabled()
    return GetSettingValue("chainEnabled") == true
end

local function ShouldIncludeDuels()
    return GetSettingValue("includeDuels") == true
end

local function GetScale()
    return ClampNumber(GetSettingValue("scale"), 60, 180) / 100
end

local function GetIntensity()
    return ClampNumber(GetSettingValue("intensity"), 0, 150) / 100
end

local function IsHudSceneShowing()
    if not HUD_SCENE and not HUD_UI_SCENE then
        return true
    end
    return (HUD_SCENE and HUD_SCENE:IsShowing()) or (HUD_UI_SCENE and HUD_UI_SCENE:IsShowing())
end

local function GetPalette(count)
    if count <= 3 then
        return
        {
            accent = { 0.12, 0.64, 1.00 },
            hot = { 0.76, 0.95, 1.00 },
            echo = { 0.02, 0.26, 0.92 },
        }
    elseif count <= 5 then
        return
        {
            accent = { 1.00, 0.48, 0.035 },
            hot = { 1.00, 0.88, 0.42 },
            echo = { 0.78, 0.10, 0.015 },
        }
    elseif count <= 7 then
        return
        {
            accent = { 1.00, 0.13, 0.018 },
            hot = { 1.00, 0.66, 0.12 },
            echo = { 0.62, 0.015, 0.08 },
        }
    end
    return
    {
        accent = { 1.00, 0.57, 0.055 },
        hot = { 1.00, 0.96, 0.76 },
        echo = { 0.84, 0.015, 0.025 },
    }
end

local function ResolveSound(count)
    local key = SOUND_KEYS_BY_CHAIN[ClampNumber(count, 1, 8)]
    if key and SOUNDS and SOUNDS[key] then
        return SOUNDS[key], key
    end

    for _, fallbackKey in ipairs(FALLBACK_SOUND_KEYS) do
        if SOUNDS and SOUNDS[fallbackKey] then
            return SOUNDS[fallbackKey], fallbackKey
        end
    end
end

-- All badge geometry is native, smoothed ESO polygons. There are no image
-- assets to load and no rectangular window borders in the live celebration.
local function CreateGroup(parent, width, height, x, y)
    local control = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    control:SetDimensions(width, height)
    control:SetAnchor(CENTER, parent, CENTER, x or 0, y or 0)
    control:SetMouseEnabled(false)
    control:SetTransformNormalizedOriginPoint(0.5, 0.5)
    return control
end

local function SetFill(control, color, alpha)
    control:SetCenterColor(color[1], color[2], color[3], alpha or color[4] or 1)
end

local function SetStroke(control, color, alpha)
    control:SetBorderColor(color[1], color[2], color[3], alpha or color[4] or 1)
end

local function CreatePolygon(parent, width, height, x, y, points, color, level, border)
    local control = WINDOW_MANAGER:CreateControl(nil, parent, CT_POLYGON)
    control:SetDimensions(width, height)
    control:SetAnchor(CENTER, parent, CENTER, x or 0, y or 0)
    control:SetMouseEnabled(false)
    control:SetDrawLayer(DL_CONTROLS)
    control:SetDrawLevel(level or 0)
    control:SetTransformNormalizedOriginPoint(0.5, 0.5)
    control:SetPointLayout(POLYGON_POINT_LAYOUT_CLOCKWISE)
    control:SetSmoothingEnabled(true)
    for _, point in ipairs(points) do
        control:AddPoint(point[1], point[2])
    end
    SetFill(control, color)
    control:SetBorderThickness(border or 0, border or 0, 1)
    control:SetBorderDirection(POLYGON_BORDER_DIRECTION_IN)
    control:SetBorderColor(1, 1, 1, border and 1 or 0)
    return control
end

local RECT_POINTS = { {0, 0}, {1, 0}, {1, 1}, {0, 1} }
local CARD_POINTS = { {0.16, 0}, {0.84, 0}, {1, 0.08}, {1, 0.92}, {0.84, 1}, {0.16, 1}, {0, 0.92}, {0, 0.08} }
local CLEAR = {0, 0, 0, 0}
local STEEL = {0.64, 0.72, 0.77}
local IVORY = {0.94, 0.96, 0.92}
local INK = {0.025, 0.035, 0.042}

local CIRCLE_POINTS = {}
for index = 0, 63 do
    local angle = index * math.pi * 2 / 64
    CIRCLE_POINTS[#CIRCLE_POINTS + 1] = {0.5 + math.cos(angle) * 0.5, 0.5 + math.sin(angle) * 0.5}
end

local function CreateDisc(parent, diameter, x, y, color, level, border)
    return CreatePolygon(parent, diameter, diameter, x, y, CIRCLE_POINTS, color, level, border)
end

-- A crisp, stamped skull. Each contour is convex so ESO's polygon
-- triangulation and the preview renderer draw the same geometry.
local function CreateSkull(parent, size, x, y, level)
    local skull = CreateGroup(parent, size, size, x, y)
    skull.plates = {}
    local function Plate(points, color, depth)
        local plate = CreatePolygon(skull, size, size, 0, 0, points, color, level + depth)
        skull.plates[#skull.plates + 1] = plate
        return plate
    end
    skull.dome = Plate({
        {0.31, 0.09}, {0.69, 0.09}, {0.84, 0.23}, {0.88, 0.48},
        {0.78, 0.67}, {0.22, 0.67}, {0.12, 0.48}, {0.16, 0.23},
    }, IVORY, 0)
    skull.jaw = Plate({
        {0.28, 0.59}, {0.72, 0.59}, {0.68, 0.87}, {0.58, 0.94},
        {0.42, 0.94}, {0.32, 0.87},
    }, IVORY, 0)
    skull.brow = Plate({{0.31, 0.09}, {0.69, 0.09}, {0.80, 0.22}, {0.20, 0.22}}, {1, 1, 0.97, 0.40}, 1)
    Plate({{0.20, 0.38}, {0.44, 0.45}, {0.40, 0.59}, {0.25, 0.56}}, INK, 2)
    Plate({{0.80, 0.38}, {0.75, 0.56}, {0.60, 0.59}, {0.56, 0.45}}, INK, 2)
    Plate({{0.50, 0.57}, {0.58, 0.70}, {0.42, 0.70}}, INK, 2)
    Plate({{0.40, 0.76}, {0.44, 0.76}, {0.44, 0.94}, {0.40, 0.94}}, INK, 2)
    Plate({{0.56, 0.76}, {0.60, 0.76}, {0.60, 0.94}, {0.56, 0.94}}, INK, 2)
    return skull
end

function PvP:GetRoot()
    if self.root then return self.root end

    local root = WINDOW_MANAGER:CreateTopLevelWindow("NAGA_UI_PvPKillCelebrationRoot")
    ApplyTemplateToControl(root, "ZO_HUDManager_Element")
    root:SetDimensions(ROOT_WIDTH, ROOT_HEIGHT)
    root:SetClampedToScreen(true)
    root:SetMouseEnabled(false)
    root:SetDrawTier(DT_HIGH)
    root:SetHidden(true)
    root:SetAlpha(0)
    root.visual = CreateGroup(root, ROOT_WIDTH, ROOT_HEIGHT, 0, 0)

    local visual = root.visual
    root.halo = CreateGroup(visual, 140, 140, 0, 8)
    root.halo.layers = {}
    for index = 1, 5 do
        root.halo.layers[index] = CreateDisc(root.halo, 140 - index * 11, 0, 0, CLEAR, 0)
    end
    root.wave = CreateDisc(visual, 86, 0, 8, CLEAR, 1, 1.1)
    root.maxWave = CreateDisc(visual, 88, 0, 8, CLEAR, 1, 1.8)
    root.wave:SetHidden(true)
    root.maxWave:SetHidden(true)

    root.rails = {}
    for _, side in ipairs({-1, 1}) do
        local rail = CreateGroup(visual, 132, 12, side * 111, 10)
        -- Taper into transparent space instead of finishing as a hard bar.
        rail.core = CreatePolygon(rail, 132, 1.4, 0, 0,
            side == 1 and {{0, 0}, {1, 0.5}, {0, 1}} or {{0, 0.5}, {1, 0}, {1, 1}}, IVORY, 6)
        rail.glow = CreatePolygon(rail, 132, 8, 0, 0,
            side == 1 and {{0, 0}, {1, 0.5}, {0, 1}} or {{0, 0.5}, {1, 0}, {1, 1}}, CLEAR, 5)
        rail:SetTransformNormalizedOriginPoint(side == 1 and 0 or 1, 0.5)
        rail.side = side
        root.rails[#root.rails + 1] = rail
    end

    root.cards = {}
    for index = 1, 8 do
        local card = CreateGroup(visual, 26, 46, 0, -20)
        local level = 10 + index * 4
        card.body = CreatePolygon(card, 26, 46, 0, 0, CARD_POINTS, INK, level, 1)
        card.inset = CreatePolygon(card, 21, 41, 0, 0, CARD_POINTS, {0.07, 0.12, 0.15}, level + 1, 0.6)
        card.stamp = CreateSkull(card, 15, 0, -7, level + 1)
        card.notch = CreatePolygon(card, 10, 1.3, 0, 10, RECT_POINTS, STEEL, level + 3)
        card.glint = CreatePolygon(card, 18, 1.8, 0, -20, RECT_POINTS, IVORY, level + 3)
        card:SetHidden(true)
        root.cards[index] = card
    end

    root.medal = CreateGroup(visual, 76, 76, 0, 8)
    local medal = root.medal
    medal.shadow = CreateDisc(medal, 78, 0, 3, {0, 0, 0, 0.44}, 50)
    medal.rim = CreateDisc(medal, 70, 0, 0, {0.08, 0.11, 0.13}, 51, 1.8)
    medal.bevel = CreateDisc(medal, 64, 0, 0, {0.19, 0.24, 0.26}, 52, 0.7)
    medal.face = CreateDisc(medal, 60, 0, 0, {0.032, 0.051, 0.061}, 53)
    -- These overlapping translucent discs give a restrained directional sheen.
    medal.sheen = CreateDisc(medal, 51, -1, -2, {0.16, 0.21, 0.24, 0.22}, 54)
    medal.inner = CreateDisc(medal, 52, 0, 0, CLEAR, 55, 0.65)
    medal.skull = CreateSkull(medal, 38, 0, -1, 57)
    medal.strike = CreateDisc(medal, 66, 0, 0, {1, 1, 0.95}, 64)
    medal.strike:SetAlpha(0)

    -- Eight small machined cuts on the lower rim, filled by the kill chain.
    root.ranks = {}
    for index = 1, 8 do
        local degrees = 40 + (index - 1) * (100 / 7)
        local angle = math.rad(degrees)
        local tick = CreatePolygon(medal, 4.5, 1.4,
            math.cos(angle) * 31, math.sin(angle) * 31, RECT_POINTS, STEEL, 56)
        tick:SetTransformRotationZ(angle + math.pi * 0.5)
        root.ranks[index] = tick
    end

    root.counter = WINDOW_MANAGER:CreateControl(nil, visual, CT_LABEL)
    root.counter:SetDimensions(62, 25)
    root.counter:SetAnchor(CENTER, visual, CENTER, 0, 58)
    root.counter:SetFont("$(BOLD_FONT)|21|soft-shadow-thick")
    root.counter:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    root.counter:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    root.counter:SetColor(IVORY[1], IVORY[2], IVORY[3], 1)
    root.counter:SetDrawLayer(DL_OVERLAY)
    root.counter:SetDrawLevel(70)
    root.counter:SetTransformNormalizedOriginPoint(0.5, 0.5)
    root.counter:SetText("×1")

    root.flash = CreatePolygon(visual, 344, 7, 0, 8,
        {{0, 0.5}, {0.5, 0}, {1, 0.5}, {0.5, 1}}, IVORY, 65)
    root.flash:SetAlpha(0)

    root.sparks = {}
    for index = 1, 10 do
        local spark = CreatePolygon(visual, 2, 13, 0, 8,
            {{0.5, 0}, {1, 0.75}, {0.5, 1}, {0, 0.75}}, IVORY, 48)
        spark:SetHidden(true)
        root.sparks[index] = spark
    end

    self.root = root
    return root
end

function PvP:GetMover()
    if self.mover then
        return self.mover
    end

    local mover = WINDOW_MANAGER:CreateTopLevelWindow("NAGA_UI_PvPKillCelebrationMover")
    mover:SetDimensions(ROOT_WIDTH, 92)
    mover:SetClampedToScreen(true)
    mover:SetMouseEnabled(true)
    mover:SetMovable(false)
    mover:SetDrawTier(DT_HIGH)
    mover:SetHidden(true)

    local backdrop = WINDOW_MANAGER:CreateControl(nil, mover, CT_BACKDROP)
    backdrop:SetAnchorFill(mover)
    backdrop:SetCenterColor(0.004, 0.010, 0.018, 0.34)
    backdrop:SetEdgeColor(0.12, 0.64, 1.00, 0.74)
    backdrop:SetEdgeTexture(EDGE_TEXTURE, 128, 16, 2, 0)

    local label = WINDOW_MANAGER:CreateControl(nil, mover, CT_LABEL)
    label:SetAnchor(CENTER, mover, CENTER, 0, -8)
    label:SetFont("$(BOLD_FONT)|22|thick-outline")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetText(T("PvP Kill Celebration"))
    label:SetColor(0.76, 0.95, 1.00, 1)

    local sublabel = WINDOW_MANAGER:CreateControl(nil, mover, CT_LABEL)
    sublabel:SetAnchor(TOP, label, BOTTOM, 0, 5)
    sublabel:SetFont("ZoFontGameSmall")
    sublabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    sublabel:SetText(T("Drag to position"))
    sublabel:SetColor(0.62, 0.72, 0.80, 1)

    mover:SetHandler("OnMouseDown", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            control:SetMovable(true)
            control:StartMoving()
        else
            control:SetMovable(false)
        end
    end)

    mover:SetHandler("OnMouseUp", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            control:StopMovingOrResizing()
        end
        control:SetMovable(false)
    end)

    mover:SetHandler("OnMoveStop", function(control)
        control:SetMovable(false)
        local x = control:GetLeft() + (control:GetWidth() * 0.5) - (GuiRoot:GetWidth() * 0.5)
        local y = control:GetTop() + (control:GetHeight() * 0.5) - (GuiRoot:GetHeight() * 0.5)
        if NAGA_UI.Settings and NAGA_UI.Settings.SetPvPPosition then
            NAGA_UI.Settings:SetPvPPosition(x, y)
        end
        self:ApplyLayout()
    end)

    self.mover = mover
    return mover
end

function PvP:ApplyLayout()
    local position = GetPosition()
    local scale = GetScale()
    local root = self:GetRoot()
    local mover = self:GetMover()

    root:ClearAnchors()
    root:SetAnchor(CENTER, GuiRoot, CENTER, position.x, position.y)
    root:SetScale(scale)

    mover:ClearAnchors()
    mover:SetAnchor(CENTER, GuiRoot, CENTER, position.x, position.y)
    mover:SetScale(scale)
    mover:SetHidden(not IsModuleEnabled() or not IsModuleUnlocked() or self.previewing == true)

    if IsModuleUnlocked() and not self.previewing then
        self:StopVisual()
    end
end

function PvP:ApplyPalette(count)
    local root = self:GetRoot()
    local palette = GetPalette(count)
    local accent, hot = palette.accent, palette.hot
    for index, disc in ipairs(root.halo.layers) do
        SetFill(disc, accent, 0.016 + index * 0.008)
    end
    SetStroke(root.wave, count == 8 and palette.echo or accent)
    SetStroke(root.maxWave, hot)
    for _, rail in ipairs(root.rails) do
        SetFill(rail.core, hot, 0.84)
        SetFill(rail.glow, accent, 0.10)
    end
    local medal = root.medal
    SetStroke(medal.rim, hot, 0.95)
    SetStroke(medal.bevel, STEEL, 0.60)
    SetStroke(medal.inner, accent, 0.36)
    SetFill(medal.skull.dome, IVORY)
    SetFill(medal.skull.jaw, {0.72, 0.79, 0.80})
    for index, tick in ipairs(root.ranks) do
        SetFill(tick, index <= count and hot or STEEL, index <= count and 0.95 or 0.15)
    end
    for index, card in ipairs(root.cards) do
        local newest = index == count
        SetStroke(card.body, newest and hot or accent, newest and 0.90 or 0.55)
        SetFill(card.body, {0.045, 0.065, 0.080})
        SetFill(card.inset, {accent[1] * 0.16, accent[2] * 0.16, accent[3] * 0.16})
        SetStroke(card.inset, accent, 0.16)
        SetFill(card.stamp.dome, newest and IVORY or STEEL)
        SetFill(card.stamp.jaw, newest and IVORY or STEEL)
        SetFill(card.notch, accent, 0.55)
        SetFill(card.glint, hot)
    end
    root.counter:SetColor(hot[1], hot[2], hot[3], 1)
    SetFill(root.flash, hot)
    for index, spark in ipairs(root.sparks) do
        local color = index % 3 == 0 and hot or accent
        if count >= 6 and index % 3 == 1 then color = palette.echo end
        SetFill(spark, color)
    end
end

function PvP:ResetVisualState()
    local root = self.root
    if not root then return end
    root:SetHandler("OnUpdate", nil)
    root:SetAlpha(0)
    root:SetHidden(true)
    root.visual:SetTransformOffset(0, 0, 0)
    root.medal:SetTransformScale(1)
    root.medal:SetTransformOffset(0, 0, 0)
    root.medal.skull:SetTransformScale(1)
    root.medal.strike:SetAlpha(0)
    root.flash:SetAlpha(0)
    root.halo:SetAlpha(0)
    root.wave:SetHidden(true)
    root.maxWave:SetHidden(true)
    root.counter:SetAlpha(0)
    root.counter:SetTransformScale(1)
    root.counter:SetTransformOffset(0, 0, 0)
    for _, card in ipairs(root.cards) do
        card:SetHidden(true)
        card:SetAlpha(0)
        card.pose = nil
    end
    for _, rail in ipairs(root.rails) do rail:SetAlpha(0) end
    for _, spark in ipairs(root.sparks) do spark:SetHidden(true) end
    self.animation = nil
end

function PvP:StopVisual()
    self:ResetVisualState()
end

local function CardPose(index, count)
    local spread = index - (count + 1) * 0.5
    return {x = spread * 12.5, y = -31 + math.abs(spread) * 1.35,
        rotation = math.rad(spread * 7), scale = 1, alpha = 1}
end

local function Mix(a, b, progress)
    return a + (b - a) * progress
end

function PvP:UpdateAnimation()
    local animation = self.animation
    if not animation then return end
    local root = self.root
    local elapsed = math.max(0, GetFrameTimeMilliseconds() - animation.startMS)
    if elapsed >= ANIMATION_MS then
        if animation.isPreview then self.previewing = false end
        self:StopVisual()
        self:ApplyLayout()
        return
    end

    local count = animation.count
    local intensity = GetIntensity()
    local impact = math.max(0, 1 - elapsed / 155)
    local entry = ClampNumber(elapsed / 190, 0, 1)
    local exit = ClampNumber((elapsed - HOLD_END_MS) / (ANIMATION_MS - HOLD_END_MS), 0, 1)
    local alpha = 1 - EaseInCubic(exit)

    root:SetHidden(false)
    root:SetAlpha(alpha)
    -- The badge stamps down, recoils once, then holds absolutely still.
    local stamp
    if elapsed < 72 then
        stamp = Mix(1 + 0.32 * intensity, 0.94, EaseOutCubic(elapsed / 72))
    elseif elapsed < 190 then
        stamp = Mix(0.94, 1, EaseOutBack((elapsed - 72) / 118))
    else
        stamp = 1
    end
    root.medal:SetTransformScale(stamp * (1 - exit * 0.055))
    root.medal:SetTransformOffset(0, (1 - EaseOutCubic(entry)) * -5 * intensity + exit * 3, 0)
    root.medal.skull:SetTransformScale(1 + impact * 0.07 * intensity)
    root.medal.strike:SetAlpha(ClampNumber(impact * impact * 0.58 * intensity, 0, 1))
    root.visual:SetTransformOffset(count >= 6 and math.sin(elapsed * 0.18) * impact * impact * intensity * 1.8 or 0, 0, 0)

    for index, card in ipairs(root.cards) do
        if index <= count then
            local from = animation.cardFrom[index]
            local target = animation.cardTo[index]
            local delay = index > animation.previousCount and (index - animation.previousCount - 1) * 12 or 0
            local progress = ClampNumber((elapsed - delay) / 220, 0, 1)
            local eased = EaseOutCubic(progress)
            local travel = EaseOutBack(progress)
            local cardExit = ClampNumber((elapsed - 660 - (count - index) * 13) / 220, 0, 1)
            local pose = {
                x = Mix(from.x, target.x, eased),
                y = Mix(from.y, target.y, travel) + cardExit * cardExit * 13,
                rotation = Mix(from.rotation, target.rotation, eased),
                scale = Mix(from.scale, 1, travel),
                alpha = Mix(from.alpha, 1, eased) * (1 - cardExit * cardExit),
            }
            card.pose = pose
            card:SetHidden(false)
            -- The original anchor is (0, -20); offsets are relative to it.
            card:SetTransformOffset(pose.x, pose.y + 20, 0)
            card:SetTransformRotationZ(pose.rotation)
            card:SetTransformScale(pose.scale)
            card:SetAlpha(ClampNumber(pose.alpha, 0, 1))
            card.glint:SetAlpha(index == count and (0.20 + impact * 0.80) or 0.10)
        else
            card:SetHidden(true)
            card.pose = nil
        end
    end

    local railEntry = EaseOutCubic(ClampNumber((elapsed - 20) / 150, 0, 1))
    for _, rail in ipairs(root.rails) do
        rail:SetTransformScaleX(math.max(0.001, railEntry * (1 - exit * 0.30)))
        rail:SetAlpha(railEntry * (0.56 + impact * 0.44) * (1 - exit))
    end
    local textEntry = ClampNumber((elapsed - 65) / 130, 0, 1)
    root.counter:SetAlpha(textEntry)
    root.counter:SetTransformScale(0.86 + EaseOutBack(textEntry) * 0.14)
    root.counter:SetTransformOffset(0, (1 - EaseOutCubic(textEntry)) * 6, 0)
    root.halo:SetAlpha(ClampNumber((0.25 + impact * 1.5) * intensity * (1 - exit), 0, 1))
    root.flash:SetAlpha(ClampNumber(impact * impact * 0.72 * intensity, 0, 1))
    root.flash:SetTransformScaleX(0.65 + (1 - impact) * 0.35)

    local waveProgress = ClampNumber(elapsed / 440, 0, 1)
    root.wave:SetHidden(waveProgress >= 1 or intensity == 0)
    root.wave:SetTransformScale(0.76 + EaseOutCubic(waveProgress) * 0.74)
    root.wave:SetAlpha(ClampNumber((1 - waveProgress)^3 * (0.25 + count * 0.035) * intensity, 0, 1))
    root.maxWave:SetHidden(count < 8 or waveProgress >= 1 or intensity == 0)
    root.maxWave:SetTransformScale(0.80 + EaseOutCubic(waveProgress) * 1.1)
    root.maxWave:SetAlpha(ClampNumber((1 - waveProgress)^3 * 0.78 * intensity, 0, 1))

    for index, spark in ipairs(root.sparks) do
        local progress = ClampNumber((elapsed - 25 - (index % 3) * 9) / 330, 0, 1)
        local active = index <= 2 + count and progress > 0 and progress < 1 and intensity > 0
        spark:SetHidden(not active)
        if active then
            local angle = math.rad((index % 2 == 0 and 0 or 180) + (math.floor((index - 1) / 2) - 2) * 19)
            local radius = 34 + EaseOutCubic(progress) * (38 + count * 2.8 + index % 3 * 9)
            spark:SetTransformOffset(math.cos(angle) * radius, math.sin(angle) * radius * 0.66, 0)
            spark:SetTransformRotationZ(angle + math.pi * 0.5)
            spark:SetTransformScale(0.4 + (1 - progress) * 0.8)
            spark:SetAlpha(ClampNumber((1 - progress)^2 * 0.8 * intensity, 0, 1))
        end
    end
end

function PvP:ShowCelebration(count, isPreview)
    if not IsModuleEnabled() then return false end
    if IsModuleUnlocked() and not isPreview then return false end
    if not isPreview and not IsHudSceneShowing() then return false end

    count = math.floor(ClampNumber(count, 1, MAX_CHAIN))
    local root = self:GetRoot()
    local previousCount = self.animation and self.animation.count or 0
    local cardFrom, cardTo = {}, {}
    for index = 1, count do
        local target = CardPose(index, count)
        local current = index <= previousCount and root.cards[index].pose
        cardFrom[index] = current or {
            x = target.x + 12, y = target.y + 30,
            rotation = target.rotation + math.rad(16), scale = 0.82, alpha = 0,
        }
        cardTo[index] = target
    end
    self.previewing = isPreview == true
    self:ApplyLayout()
    root.counter:SetText(string.format("×%d", count))
    self:ApplyPalette(count)
    self.animation = {
        count = count, startMS = GetFrameTimeMilliseconds(), isPreview = isPreview == true,
        previousCount = previousCount, cardFrom = cardFrom, cardTo = cardTo,
    }
    root:SetHandler("OnUpdate", function() self:UpdateAnimation() end)
    self:UpdateAnimation()
    return true
end

function PvP:PlayProgressiveSound(count, bypassCooldown)
    if not AreSoundsEnabled() then
        return false
    end

    local nowMS = GetFrameTimeMilliseconds()
    if not bypassCooldown and self.lastSoundMS and nowMS - self.lastSoundMS < SOUND_COOLDOWN_MS then
        return false
    end

    local sound, key = ResolveSound(count)
    if not sound then
        return false
    end

    PlaySound(sound)
    self.lastSoundMS = nowMS
    self.lastSoundKey = key
    return true
end

function PvP:ScheduleChainExpiry()
    self.chainExpiryGeneration = (self.chainExpiryGeneration or 0) + 1
    local generation = self.chainExpiryGeneration
    local expectedLastKillMS = self.lastKillMS

    zo_callLater(function()
        if generation ~= self.chainExpiryGeneration or expectedLastKillMS ~= self.lastKillMS then
            return
        end
        if GetFrameTimeMilliseconds() - (self.lastKillMS or 0) >= CHAIN_WINDOW_MS then
            self.chainCount = 0
            self.lastKillMS = nil
        end
    end, CHAIN_WINDOW_MS)
end

function PvP:FlushPendingKills()
    self.batchScheduled = false
    local pendingCount = self.pendingKillCount or 0
    self.pendingKillCount = 0
    if pendingCount <= 0 or not IsModuleEnabled() then
        return
    end

    local nextCount
    if IsChainEnabled() then
        nextCount = math.min(MAX_CHAIN, (self.chainCount or 0) + pendingCount)
    else
        nextCount = 1
    end
    self.chainCount = nextCount

    if self:ShowCelebration(nextCount, false) then
        self:PlayProgressiveSound(nextCount, false)
    end
end

function PvP:CancelPreview()
    if not self.previewing then
        return
    end

    self.previewGeneration = (self.previewGeneration or 0) + 1
    self.previewing = false
    self:StopVisual()
    self:ApplyLayout()
end

function PvP:QueueAcceptedKill()
    if not IsModuleEnabled() then
        return
    end

    self:CancelPreview()

    local nowMS = GetFrameTimeMilliseconds()
    if not IsChainEnabled() or not self.lastKillMS or nowMS - self.lastKillMS >= CHAIN_WINDOW_MS then
        self.chainCount = 0
    end
    self.lastKillMS = nowMS
    self.pendingKillCount = (self.pendingKillCount or 0) + 1
    self:ScheduleChainExpiry()

    if self.batchScheduled then
        return
    end

    self.batchScheduled = true
    self.batchGeneration = (self.batchGeneration or 0) + 1
    local generation = self.batchGeneration
    zo_callLater(function()
        if generation == self.batchGeneration then
            self:FlushPendingKills()
        end
    end, BATCH_WINDOW_MS)
end

function PvP:IsDuplicateKill(killerDisplayName, victimDisplayName)
    local nowMS = GetFrameTimeMilliseconds()
    self.recentKillSignatures = self.recentKillSignatures or {}

    for signature, timestamp in pairs(self.recentKillSignatures) do
        if nowMS - timestamp > DUPLICATE_WINDOW_MS then
            self.recentKillSignatures[signature] = nil
        end
    end

    local signature = string.format("%s\031%s", NormalizeDisplayName(killerDisplayName), NormalizeDisplayName(victimDisplayName))
    local previousMS = self.recentKillSignatures[signature]
    if previousMS and nowMS - previousMS <= DUPLICATE_WINDOW_MS then
        return true
    end

    self.recentKillSignatures[signature] = nowMS
    return false
end

function PvP:OnPvPKillFeedDeath(killLocation, killerDisplayName, killerCharacterName, killerAlliance, killerRank, victimDisplayName)
    local localDisplayName = NormalizeDisplayName(GetDisplayName and GetDisplayName() or GetUnitDisplayName("player"))
    local killer = NormalizeDisplayName(killerDisplayName)
    local victim = NormalizeDisplayName(victimDisplayName)

    if localDisplayName == "" then
        return
    end
    if victim == localDisplayName then
        self:ResetState(true)
        return
    end
    if killer ~= localDisplayName or victim == "" or killer == victim then
        return
    end
    if self:IsDuplicateKill(killerDisplayName, victimDisplayName) then
        return
    end

    self:QueueAcceptedKill()
end

function PvP:OnDuelFinished(duelResult, wasLocalPlayersResult, opponentCharacterName, opponentDisplayName)
    if not ShouldIncludeDuels()
        or duelResult ~= DUEL_RESULT_WON
        or wasLocalPlayersResult ~= true then
        return
    end

    local localDisplayName = GetDisplayName and GetDisplayName() or GetUnitDisplayName("player")
    if self:IsDuplicateKill(localDisplayName or "player", opponentDisplayName or opponentCharacterName) then
        return
    end
    self:QueueAcceptedKill()
end

function PvP:ResetState(clearRecentKills)
    self.batchGeneration = (self.batchGeneration or 0) + 1
    self.chainExpiryGeneration = (self.chainExpiryGeneration or 0) + 1
    self.previewGeneration = (self.previewGeneration or 0) + 1
    self.debugGeneration = (self.debugGeneration or 0) + 1
    self.batchScheduled = false
    self.pendingKillCount = 0
    self.chainCount = 0
    self.lastKillMS = nil
    self.previewing = false
    if clearRecentKills then
        self.recentKillSignatures = {}
    end
    self:StopVisual()
    self:ApplyLayout()
end

function PvP:PreviewChain()
    if not IsModuleEnabled() then
        return
    end

    self:ResetState(false)
    self.previewGeneration = (self.previewGeneration or 0) + 1
    local generation = self.previewGeneration
    self.lastSoundMS = nil
    local steps =
    {
        { delayMS = 0, count = 1 },
        { delayMS = 650, count = 4 },
        { delayMS = 1300, count = 8 },
    }

    for _, step in ipairs(steps) do
        zo_callLater(function()
            if generation ~= self.previewGeneration or not IsModuleEnabled() then
                return
            end
            if self:ShowCelebration(step.count, true) then
                self:PlayProgressiveSound(step.count, true)
            end
        end, step.delayMS)
    end

    zo_callLater(function()
        if generation == self.previewGeneration then
            self.chainCount = 0
            self.previewing = false
            self:StopVisual()
            self:ApplyLayout()
        end
    end, 2350)
end

function PvP:DebugKill()
    self:QueueAcceptedKill()
end

function PvP:DebugChain()
    self:ResetState(false)
    self.debugGeneration = (self.debugGeneration or 0) + 1
    local generation = self.debugGeneration
    for index = 1, 8 do
        zo_callLater(function()
            if generation == self.debugGeneration and IsModuleEnabled() then
                self:QueueAcceptedKill()
            end
        end, (index - 1) * 420)
    end
end

function PvP:RegisterEvents()
    if self.eventsRegistered then
        return
    end

    self.registeredEvents = {}
    local function Register(suffix, eventCode, callback)
        if not eventCode then
            return
        end
        local namespace = EVENT_NAMESPACE .. suffix
        EVENT_MANAGER:RegisterForEvent(namespace, eventCode, callback)
        self.registeredEvents[#self.registeredEvents + 1] = { namespace = namespace, eventCode = eventCode }
    end

    Register("_KillFeed", EVENT_PVP_KILL_FEED_DEATH, function(_, ...)
        self:OnPvPKillFeedDeath(...)
    end)
    Register("_PlayerDead", EVENT_PLAYER_DEAD, function()
        self:ResetState(true)
    end)
    Register("_Deactivated", EVENT_PLAYER_DEACTIVATED, function()
        self:ResetState(true)
    end)
    Register("_Activated", EVENT_PLAYER_ACTIVATED, function()
        self:ResetState(true)
    end)
    Register("_ZoneChanged", EVENT_ZONE_CHANGED, function()
        self:ResetState(true)
    end)
    Register("_ScreenResized", EVENT_SCREEN_RESIZED, function()
        self:ApplyLayout()
    end)
    Register("_DuelStarted", EVENT_DUEL_STARTED, function()
        self:ResetState(true)
    end)

    if ShouldIncludeDuels() then
        Register("_DuelFinished", EVENT_DUEL_FINISHED, function(_, ...)
            self:OnDuelFinished(...)
        end)
    end

    self.eventsRegistered = true
end

function PvP:UnregisterEvents()
    if not self.eventsRegistered then
        return
    end

    for _, eventData in ipairs(self.registeredEvents or {}) do
        EVENT_MANAGER:UnregisterForEvent(eventData.namespace, eventData.eventCode)
    end
    self.registeredEvents = nil
    self.eventsRegistered = false
end

function PvP:RegisterSceneCallbacks()
    if self.sceneCallbacksRegistered then
        return
    end

    local function OnSceneChanged()
        if not IsHudSceneShowing() and not self.previewing then
            self:StopVisual()
        end
        self:ApplyLayout()
    end

    if HUD_SCENE then
        HUD_SCENE:RegisterCallback("StateChange", OnSceneChanged)
    end
    if HUD_UI_SCENE then
        HUD_UI_SCENE:RegisterCallback("StateChange", OnSceneChanged)
    end
    self.sceneCallbacksRegistered = true
end

local DEBUG_COMMANDS =
{
    ["/nspvpkill"] = function()
        PvP:DebugKill()
    end,
    ["/nspvpchain"] = function()
        PvP:DebugChain()
    end,
}

local function IsDebugModeEnabled()
    return NAGA_UI.Settings and NAGA_UI.Settings:IsDebugModeEnabled()
end

local function RegisterDebugCommands()
    for command, handler in pairs(DEBUG_COMMANDS) do
        SLASH_COMMANDS[command] = IsDebugModeEnabled() and handler or nil
    end
end

function PvP:RefreshDebugCommands()
    RegisterDebugCommands()
end

function PvP:RefreshSettings()
    self:GetRoot()
    self:GetMover()
    self:RegisterSceneCallbacks()
    self:UnregisterEvents()

    if IsModuleEnabled() then
        self:RegisterEvents()
    else
        self:ResetState(true)
    end

    self:ApplyLayout()
    RegisterDebugCommands()
end

NAGA_UI.OnAddonLoaded(function()
    PvP:RefreshSettings()
end)
