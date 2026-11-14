NQOL = NQOL or {}
NQOL.Features = NQOL.Features or {}

local PlayerBars = NQOL.Features.PlayerBars
PlayerBars.Player = PlayerBars.Player or {}

local PlayerBar = PlayerBars.Player
local Shared = PlayerBars.Shared
local C = PlayerBars.Constants
local COMPANION = PlayerBars.Companion
local Shadow = PlayerBars.Shadow
local defaults = Shared.defaults
local Clamp = NQOL.Util.Clamp
local Round = NQOL.Util.Round
local GetSettings = Shared.GetPlayerSettings
local GetCompanionSettings = Shared.GetCompanionSettings
local GetClassicSettings = Shared.GetClassicSettings
local GetPyramidSettings = Shared.GetPyramidSettings
local GetStackSettings = Shared.GetStackSettings
local GetVerticalSettings = Shared.GetVerticalSettings
local GetScreenWidth = Shared.GetScreenWidth
local GetScreenHeight = Shared.GetScreenHeight
local FormatNumber = Shared.FormatNumber
local FormatCompactNumber = Shared.FormatCompactNumber
local FormatCurrentValue = Shared.FormatCurrentValue
local GetClassicLabelFont = Shared.GetClassicLabelFont
local GetPyramidLabelFont = Shared.GetPyramidLabelFont
local GetStackLabelFont = Shared.GetStackLabelFont
local GetVerticalLabelFont = Shared.GetVerticalLabelFont
local GetClassicChangeFont = Shared.GetClassicChangeFont
local GetPyramidChangeFont = Shared.GetPyramidChangeFont
local GetStackChangeFont = Shared.GetStackChangeFont
local GetVerticalChangeFont = Shared.GetVerticalChangeFont
local CreateClassicControls = Shared.CreateClassicControls
local CreatePyramidControls = Shared.CreatePyramidControls
local CreateStackControls = Shared.CreateStackControls
local CreateVerticalControls = Shared.CreateVerticalControls
local Radial = PlayerBars.Radial
local CreateRootControl = Shared.CreateRootControl
local MoveAboveHud = Shared.MoveAboveHud
local ApplyClassicLabelFont = Shared.ApplyClassicLabelFont
local ApplyPyramidLabelFont = Shared.ApplyPyramidLabelFont
local ApplyStackLabelFont = Shared.ApplyStackLabelFont
local ApplyVerticalLabelFont = Shared.ApplyVerticalLabelFont
local ApplyChangeFont = Shared.ApplyChangeFont
local ApplyClassicBorder = Shared.ApplyClassicBorder
local ApplyPyramidBorder = Shared.ApplyPyramidBorder
local ApplyStackBorder = Shared.ApplyStackBorder
local ApplyVerticalBorder = Shared.ApplyVerticalBorder
local HideClassicChangeLabels = Shared.HideClassicChangeLabels
local PlayChangeNumber = Shared.PlayChangeNumber
local GetPresetSettings = Shared.GetPresetSettings
local GetVerticalFlyingOrientationForResource = Shared.GetVerticalFlyingOrientationForResource
local GetVerticalReverseForResource = Shared.GetVerticalReverseForResource
local GetVerticalCurrentValueForResource = Shared.GetVerticalCurrentValueForResource
local GetChangeDirection = Shared.GetChangeDirection
local ApplyRootPosition = Shared.ApplyRootPosition
local SetFrameVisibilityImmediate = Shared.SetFrameVisibilityImmediate
local SetFrameCombatVisibility = Shared.SetFrameCombatVisibility

local initialized = false
local sceneCallbackInstalled = false
local eventsInstalled = false
local settingsPanelVisible = false
local refreshQueued = false
local mounted = false
local runtimeActive = false
local playerPowerEventsRegistered = false
local companionPowerEventsRegistered = false
local groupPowerEventsRegistered = false
local InstallEvents
local UninstallEvents
local activePresetKey
local presets = {}
local resourceValues = {}
local healthVisuals = {
    shield = 0,
    showShield = false,
    trauma = 0,
    noHealing = 0,
}

function PlayerBars.GetHealthVisualValues()
    return healthVisuals
end

local function ShouldShowForCurrentScene()
    if Shared.IsGameplaySceneShowing() then
        return true
    end

    return settingsPanelVisible and GetSettings().showInSettings == true
end

local function IsPreviewVisible()
    return settingsPanelVisible and GetSettings().showInSettings == true
end

function PlayerBar.IsRuntimeActive()
    return runtimeActive
end

function PlayerBar.RefreshRuntimeState()
    runtimeActive = GetSettings().showNqolPlayerFrame == true or IsPreviewVisible()
    if PlayerBars.RefreshEventRegistrations then
        PlayerBars.RefreshEventRegistrations()
    end
    return runtimeActive
end

local function IsMounted()
    if _G and _G.IsMounted then
        return _G.IsMounted()
    end

    return mounted == true
end

local function ShouldShowResource(resourceType, current, maximum, effectiveMaximum)
    if resourceType == PlayerBars.SIEGE_HEALTH then
        return ((IsGameCameraSiegeControlled and IsGameCameraSiegeControlled()) or (IsPlayerEscortingRam and IsPlayerEscortingRam()))
            and ((maximum or 0) > 0 or (effectiveMaximum or 0) > 0 or (current or 0) > 0)
    end

    if resourceType == C.RESOURCE_MOUNT_STAMINA then
        return IsMounted() and ((maximum or 0) > 0 or (effectiveMaximum or 0) > 0 or (current or 0) > 0)
    end

    if resourceType == COMBAT_MECHANIC_FLAGS_WEREWOLF then
        return IsPlayerInWerewolfForm and IsPlayerInWerewolfForm() and ((maximum or 0) > 0 or (effectiveMaximum or 0) > 0 or (current or 0) > 0)
    end

    return true
end

local function IsSecondaryPlayerBarResource(resourceType)
    return resourceType == C.RESOURCE_MOUNT_STAMINA
        or resourceType == COMBAT_MECHANIC_FLAGS_WEREWOLF
        or resourceType == PlayerBars.SIEGE_HEALTH
end

local function InitializeResourceValues()
    for _, resourceType in ipairs(C.RESOURCE_KEYS) do
        if not resourceValues[resourceType] then
            resourceValues[resourceType] = {
                current = nil,
                maximum = nil,
                effectiveMaximum = nil,
                hidden = nil,
            }
        end
    end
end

function PlayerBars.GetAttributeVisualValue(visualType)
    if not GetUnitAttributeVisualizerEffectInfo or not visualType or not STAT_MITIGATION or not ATTRIBUTE_HEALTH then
        return 0
    end

    local value = GetUnitAttributeVisualizerEffectInfo("player", visualType, STAT_MITIGATION, ATTRIBUTE_HEALTH, C.RESOURCE_HEALTH)
    return tonumber(value) or 0
end

function PlayerBars.UpdateHealthVisualValues(force)
    local settings = GetSettings()
    local shouldPreviewHealthVisuals = settingsPanelVisible and settings.showInSettings == true
    local shield = 0
    local showShield = settings.showShield == true
    local trauma = 0
    local noHealing = 0

    if GetUnitAttributeVisualizerEffectInfo and STAT_MITIGATION and ATTRIBUTE_HEALTH then
        shield = PlayerBars.GetAttributeVisualValue(ATTRIBUTE_VISUAL_POWER_SHIELDING)
        trauma = settings.showTrauma == true and PlayerBars.GetAttributeVisualValue(ATTRIBUTE_VISUAL_TRAUMA) or 0
        noHealing = settings.showNoHealing == true and PlayerBars.GetAttributeVisualValue(ATTRIBUTE_VISUAL_NO_HEALING) or 0
    end

    if shouldPreviewHealthVisuals and showShield and shield <= 0 then
        local health = resourceValues[C.RESOURCE_HEALTH]
        local maximum = health and health.maximum or 0
        shield = math.max(1, zo_floor(maximum * 0.25))
    end
    if shouldPreviewHealthVisuals and settings.showTrauma == true then
        local health = resourceValues[C.RESOURCE_HEALTH]
        local maximum = health and health.maximum or 0
        local current = health and health.current or 0
        if trauma <= 0 then
            trauma = math.max(1, zo_floor(math.min(current, maximum * 0.25)))
        end
    end
    if shouldPreviewHealthVisuals and settings.showNoHealing == true and noHealing <= 0 then
        noHealing = 1
    end
    if not force and healthVisuals.shield == shield and healthVisuals.showShield == showShield and healthVisuals.trauma == trauma and healthVisuals.noHealing == noHealing then
        return false
    end

    healthVisuals.shield = shield
    healthVisuals.showShield = showShield
    healthVisuals.trauma = trauma
    healthVisuals.noHealing = noHealing
    return true
end

local function StoreResourceValue(resourceType, current, maximum, effectiveMaximum, force)
    local resourceValue = resourceValues[resourceType]
    if not resourceValue then
        return false
    end

    current = tonumber(current) or 0
    maximum = tonumber(maximum) or 0
    effectiveMaximum = tonumber(effectiveMaximum) or maximum

    local hidden = not ShouldShowResource(resourceType, current, maximum, effectiveMaximum)
    if not force
        and resourceValue.current == current
        and resourceValue.maximum == maximum
        and resourceValue.effectiveMaximum == effectiveMaximum
        and resourceValue.hidden == hidden
    then
        return false
    end

    resourceValue.current = current
    resourceValue.maximum = maximum
    resourceValue.effectiveMaximum = effectiveMaximum
    resourceValue.hidden = hidden
    return true
end

local function UpdateResourceValue(resourceType, force)
    if not GetUnitPower then
        return false
    end

    local current, maximum, effectiveMaximum
    if resourceType == PlayerBars.SIEGE_HEALTH then
        local unitTag = IsGameCameraSiegeControlled and IsGameCameraSiegeControlled() and "controlledsiege" or "escortedram"
        current, maximum, effectiveMaximum = GetUnitPower(unitTag, C.RESOURCE_HEALTH)
    else
        current, maximum, effectiveMaximum = GetUnitPower("player", resourceType)
    end

    return StoreResourceValue(resourceType, current, maximum, effectiveMaximum, force)
end

local function ApplyResourceValueToWidget(widget, resourceValue)
    if not widget or not resourceValue then
        return
    end

    widget:SetHidden(resourceValue.hidden == true)
    if resourceValue.hidden == true then
        return
    end

    local rangeMaximum = resourceValue.maximum
    if rangeMaximum < 1 then
        rangeMaximum = 1
    end

    widget.status:SetMinMax(0, rangeMaximum)
    widget.status:SetValue(Clamp(resourceValue.current, 0, rangeMaximum))
end

function PlayerBars.ApplyWidgetBarColor(widget, resourceType, settings, usePlayerColor)
    if not widget or not widget.fill then
        return
    end

    local color = C.RESOURCE_COLORS[resourceType]
    if not color then
        return
    end

    local red, green, blue, alpha = color[1], color[2], color[3], color[4]
    if usePlayerColor == true then
        red, green, blue, alpha = Shared.GetPlayerResourceColor(settings, resourceType)
    elseif PlayerBars.Group.IsColorTable(settings.healthColor) then
        red, green, blue, alpha = settings.healthColor.r, settings.healthColor.g, settings.healthColor.b, settings.healthColor.a or 1
    end

    widget.fill:SetCenterColor(red, green, blue, alpha)
end

function PlayerBars.HideLossFill(widget)
    if widget and widget.loss then
        widget.loss:SetHidden(true)
    end
end

function PlayerBars.ApplyLossFill(widget, resourceType, rangeMaximum, innerWidth, innerHeight, borderSize, reverse, vertical, enabled)
    if not enabled or not widget or not widget.loss or not PlayerBars.Smooth then
        PlayerBars.HideLossFill(widget)
        return
    end

    local lossValue, lossAlpha = PlayerBars.Smooth.GetLoss(widget, resourceType)
    if lossAlpha <= 0 or lossValue <= 0 or rangeMaximum <= 0 then
        PlayerBars.HideLossFill(widget)
        return
    end

    local activeSize = vertical and innerHeight or innerWidth
    local crossSize = vertical and innerWidth or innerHeight
    local size = zo_floor(activeSize * Clamp(lossValue / rangeMaximum, 0, 1))
    if size < 1 then
        PlayerBars.HideLossFill(widget)
        return
    end

    widget.loss:SetCenterColor(1, 1, 1, lossAlpha)
    widget.loss:ClearAnchors()
    if vertical then
        if reverse then
            widget.loss:SetAnchor(TOPLEFT, widget, TOPLEFT, borderSize, borderSize)
        else
            widget.loss:SetAnchor(BOTTOMLEFT, widget, BOTTOMLEFT, borderSize, -borderSize)
        end
        widget.loss:SetDimensions(crossSize, size)
    else
        if reverse then
            widget.loss:SetAnchor(TOPRIGHT, widget, TOPRIGHT, -borderSize, borderSize)
        else
            widget.loss:SetAnchor(TOPLEFT, widget, TOPLEFT, borderSize, borderSize)
        end
        widget.loss:SetDimensions(size, crossSize)
    end
    widget.loss:SetHidden(false)
end

function PlayerBars.GetHealthSegmentValues(resourceValue, visualValues, currentOverride, shieldOverride)
    if not resourceValue then
        return 0, 0, 0
    end

    visualValues = visualValues or healthVisuals
    local maximum = math.max(1, tonumber(resourceValue.maximum) or 0)
    if currentOverride == nil then
        currentOverride = visualValues.currentOverride
    end
    if shieldOverride == nil then
        shieldOverride = visualValues.shield
    end
    local current = Clamp(tonumber(currentOverride ~= nil and currentOverride or resourceValue.current) or 0, 0, maximum)
    local shieldAmount = visualValues.showShield == false and 0 or math.min(math.max(0, tonumber(shieldOverride) or 0), maximum)
    local shieldOverflow = math.max(0, current + shieldAmount - maximum)
    local healthBeforeShield = math.max(0, current - shieldOverflow)
    local traumaAmount = math.min(math.max(0, tonumber(visualValues.trauma) or 0), healthBeforeShield)
    local normalHealth = healthBeforeShield - traumaAmount
    return normalHealth, traumaAmount, shieldAmount
end

function PlayerBars.ResetPlayerHealthAnimations(widget)
    if not widget then
        return
    end

    if PlayerBars.Smooth then
        PlayerBars.Smooth.Reset(widget, C.RESOURCE_HEALTH)
        if widget.nqolShieldSmoothInitialized == true then
            PlayerBars.Smooth.Reset(widget, C.PLAYER_SHIELD_SMOOTH_KEY)
        end
    end
    widget.nqolShieldSmoothInitialized = nil
end

function PlayerBars.GetAnimatedPlayerHealthSegments(widget, resourceValue, settings, onUpdate)
    local maximum = math.max(1, tonumber(resourceValue and resourceValue.maximum) or 0)
    local current = Clamp(tonumber(resourceValue and resourceValue.current) or 0, 0, maximum)
    local shield = healthVisuals.showShield == true and Clamp(tonumber(healthVisuals.shield) or 0, 0, maximum) or 0

    if settings.smoothTransitions == true and PlayerBars.Smooth then
        current = PlayerBars.Smooth.GetValue(widget, C.RESOURCE_HEALTH, current, onUpdate, maximum)
        if healthVisuals.showShield == true and shield > 0 then
            shield = PlayerBars.Smooth.GetValue(widget, C.PLAYER_SHIELD_SMOOTH_KEY, shield, onUpdate, nil, false)
            widget.nqolShieldSmoothInitialized = true
        elseif widget.nqolShieldSmoothInitialized == true then
            PlayerBars.Smooth.Reset(widget, C.PLAYER_SHIELD_SMOOTH_KEY)
            widget.nqolShieldSmoothInitialized = nil
        end
    elseif PlayerBars.Smooth then
        PlayerBars.Smooth.Reset(widget, C.RESOURCE_HEALTH)
        if widget.nqolShieldSmoothInitialized == true then
            PlayerBars.Smooth.Reset(widget, C.PLAYER_SHIELD_SMOOTH_KEY)
            widget.nqolShieldSmoothInitialized = nil
        end
    end

    return PlayerBars.GetHealthSegmentValues(resourceValue, healthVisuals, current, shield)
end

function PlayerBars.GetTraumaAmountForHealth(resourceValue, visualValues)
    local _, traumaAmount = PlayerBars.GetHealthSegmentValues(resourceValue, visualValues)
    return traumaAmount
end

function PlayerBars.GetVisibleHealthForFill(resourceValue, visualValues)
    local normalHealth = PlayerBars.GetHealthSegmentValues(resourceValue, visualValues)
    return normalHealth
end

function PlayerBars.GetNoHealingHealthAmount(normalHealth, visualValues)
    visualValues = visualValues or healthVisuals
    if (visualValues.noHealing or 0) <= 0 then
        return 0
    end

    return math.max(0, tonumber(normalHealth) or 0)
end

function PlayerBars.HideHealthVisualOverlays(widget)
    if widget and widget.trauma then
        widget.trauma:SetHidden(true)
    end

    if widget and widget.shield then
        widget.shield:SetHidden(true)
    end

    if widget and widget.noHealing then
        widget.noHealing:SetHidden(true)
    end

    if widget and widget.noHealingFractureGlowTiles then
        for _, tile in ipairs(widget.noHealingFractureGlowTiles) do
            tile:SetHidden(true)
        end
    end

    if widget and widget.noHealingFractureTiles then
        for _, tile in ipairs(widget.noHealingFractureTiles) do
            tile:SetHidden(true)
        end
    end
end

function PlayerBars.ApplyHorizontalHealthVisual(control, startSize, size, innerSize, crossSize, reverse, borderSize)
    if not control then
        return
    end

    control:ClearAnchors()
    if size <= 0 or innerSize <= 0 or crossSize <= 0 then
        control:SetHidden(true)
        return
    end

    size = math.min(size, innerSize)
    startSize = Clamp(startSize, 0, math.max(innerSize - size, 0))
    if reverse then
        control:SetAnchor(TOPRIGHT, control:GetParent(), TOPRIGHT, -borderSize - startSize, borderSize)
    else
        control:SetAnchor(TOPLEFT, control:GetParent(), TOPLEFT, borderSize + startSize, borderSize)
    end
    control:SetDimensions(size, crossSize)
    if control.SetMinMax and control.SetValue then
        control:SetMinMax(0, math.max(size, 1))
        control:SetValue(size)
    end
    control:SetHidden(false)
end

function PlayerBars.ApplyVerticalHealthVisual(control, startSize, size, innerSize, crossSize, reverse, borderSize)
    if not control then
        return
    end

    control:ClearAnchors()
    if size <= 0 or innerSize <= 0 or crossSize <= 0 then
        control:SetHidden(true)
        return
    end

    size = math.min(size, innerSize)
    startSize = Clamp(startSize, 0, math.max(innerSize - size, 0))
    if reverse then
        control:SetAnchor(TOPLEFT, control:GetParent(), TOPLEFT, borderSize, borderSize + startSize)
    else
        control:SetAnchor(BOTTOMLEFT, control:GetParent(), BOTTOMLEFT, borderSize, -borderSize - startSize)
    end
    control:SetDimensions(crossSize, size)
    if control.SetMinMax and control.SetValue then
        control:SetMinMax(0, math.max(size, 1))
        control:SetValue(size)
    end
    control:SetHidden(false)
end

function PlayerBars.GetNoHealingFractureTile(widget, tiles, index, texture, drawLevel, red, green, blue, alpha)
    local tile = tiles[index]
    if not tile then
        tile = WINDOW_MANAGER:CreateControl(nil, widget, CT_TEXTURE)
        tiles[index] = tile
        MoveAboveHud(tile)
    end

    tile:SetTexture(texture)
    tile:SetColor(red, green, blue, alpha)
    tile:SetDrawLevel(drawLevel)
    return tile
end

function PlayerBars.HideUnusedNoHealingFractureTiles(tiles, firstUnusedIndex)
    if not tiles then
        return
    end

    for index = firstUnusedIndex, #tiles do
        tiles[index]:SetHidden(true)
    end
end

function PlayerBars.ApplyHorizontalNoHealingFractures(widget, tiles, texture, drawLevel, red, green, blue, alpha, size, innerSize, crossSize, reverse, borderSize)
    if not tiles then
        return
    end

    if not texture or size <= 0 or innerSize <= 0 or crossSize <= 0 then
        PlayerBars.HideUnusedNoHealingFractureTiles(tiles, 1)
        return
    end

    local tileSize = math.max(zo_floor(crossSize * 1.45), 18)
    local index = 1
    local offset = 0
    while offset < size do
        local segmentSize = math.min(tileSize, size - offset)
        local tile = PlayerBars.GetNoHealingFractureTile(widget, tiles, index, texture, drawLevel, red, green, blue, alpha)
        tile:ClearAnchors()
        if tile.SetTextureRotation then
            tile:SetTextureRotation(0)
        end
        if tile.SetTextureCoordsRotation then
            tile:SetTextureCoordsRotation(0)
        end
        if tile.SetTextureCoords then
            tile:SetTextureCoords(0.08, 0.92, 0.08, 0.92)
        end
        if reverse then
            tile:SetAnchor(TOPLEFT, widget, TOPLEFT, borderSize + offset, borderSize)
        else
            tile:SetAnchor(TOPRIGHT, widget, TOPRIGHT, -borderSize - offset, borderSize)
        end
        tile:SetDimensions(segmentSize, crossSize)
        tile:SetHidden(false)
        offset = offset + segmentSize
        index = index + 1
    end

    PlayerBars.HideUnusedNoHealingFractureTiles(tiles, index)
end

function PlayerBars.ApplyVerticalNoHealingFractures(widget, tiles, texture, drawLevel, red, green, blue, alpha, size, innerSize, crossSize, reverse, borderSize)
    if not tiles then
        return
    end

    if not texture or size <= 0 or innerSize <= 0 or crossSize <= 0 then
        PlayerBars.HideUnusedNoHealingFractureTiles(tiles, 1)
        return
    end

    local tile = PlayerBars.GetNoHealingFractureTile(widget, tiles, 1, texture, drawLevel, red, green, blue, alpha)
    tile:ClearAnchors()
    if tile.SetTextureRotation then
        tile:SetTextureRotation(0)
    end
    if tile.SetTextureCoordsRotation then
        tile:SetTextureCoordsRotation(ZO_HALF_PI or 1.5707963267949)
    end
    if tile.SetTextureCoords then
        tile:SetTextureCoords(0.08, 0.92, 0.08, 0.92)
    end
    if reverse then
        tile:SetAnchor(BOTTOMLEFT, widget, BOTTOMLEFT, borderSize, -borderSize)
    else
        tile:SetAnchor(TOPLEFT, widget, TOPLEFT, borderSize, borderSize)
    end
    tile:SetDimensions(crossSize, size)
    tile:SetHidden(false)

    PlayerBars.HideUnusedNoHealingFractureTiles(tiles, 2)
end

function PlayerBars.ApplyHealthVisualOverlays(widget, resourceValue, rangeMaximum, innerWidth, innerHeight, borderSize, reverse, vertical, visualValues, normalHealth, traumaAmount, shieldAmount)
    visualValues = visualValues or healthVisuals
    if not widget or not resourceValue or resourceValue.hidden == true then
        PlayerBars.HideHealthVisualOverlays(widget)
        return
    end

    if normalHealth == nil then
        normalHealth, traumaAmount, shieldAmount = PlayerBars.GetHealthSegmentValues(resourceValue, visualValues)
        if visualValues.normalOverride ~= nil then
            normalHealth = Clamp(tonumber(visualValues.normalOverride) or 0, 0, rangeMaximum)
        end
    end
    local remaining = math.max(0, rangeMaximum - normalHealth)
    traumaAmount = math.min(traumaAmount, remaining)
    shieldAmount = math.min(shieldAmount, math.max(0, remaining - traumaAmount))
    if normalHealth <= 0 and traumaAmount <= 0 and shieldAmount <= 0 then
        PlayerBars.HideHealthVisualOverlays(widget)
        return
    end

    local activeSize = vertical and innerHeight or innerWidth
    local crossSize = vertical and innerWidth or innerHeight
    local normalSize = zo_floor(activeSize * Clamp(normalHealth / rangeMaximum, 0, 1))
    local traumaSize = zo_floor(activeSize * Clamp(traumaAmount / rangeMaximum, 0, 1))
    local shieldSize = zo_floor(activeSize * Clamp(shieldAmount / rangeMaximum, 0, 1))
    local noHealingAmount = PlayerBars.GetNoHealingHealthAmount(normalHealth, visualValues)
    local noHealingSize = zo_floor(activeSize * Clamp(noHealingAmount / rangeMaximum, 0, 1))

    if traumaAmount > 0 and traumaSize < 1 then
        traumaSize = 1
    end

    if shieldAmount > 0 and shieldSize < 1 then
        shieldSize = 1
    end

    local remainingPixels = math.max(0, zo_floor(activeSize) - normalSize)
    traumaSize = math.min(traumaSize, remainingPixels)
    shieldSize = math.min(shieldSize, math.max(0, remainingPixels - traumaSize))

    if noHealingAmount > 0 and noHealingSize < 1 then
        noHealingSize = 1
    end

    if vertical then
        PlayerBars.ApplyVerticalHealthVisual(widget.trauma, normalSize, traumaSize, activeSize, crossSize, reverse, borderSize)
        PlayerBars.ApplyVerticalHealthVisual(widget.shield, normalSize + traumaSize, shieldSize, activeSize, crossSize, reverse, borderSize)
        PlayerBars.ApplyVerticalNoHealingFractures(widget, widget.noHealingFractureGlowTiles, nil, C.DRAW_LEVEL + 3, 0.78, 0.96, 1, 0.24, 0, activeSize, crossSize, reverse, borderSize)
        PlayerBars.ApplyVerticalNoHealingFractures(widget, widget.noHealingFractureTiles, PlayerBars.TEXTURE_NO_HEALING, C.DRAW_LEVEL + 4, 0.86, 0.94, 0.96, 0.42, noHealingSize, activeSize, crossSize, reverse, borderSize)
    else
        PlayerBars.ApplyHorizontalHealthVisual(widget.trauma, normalSize, traumaSize, activeSize, crossSize, reverse, borderSize)
        PlayerBars.ApplyHorizontalHealthVisual(widget.shield, normalSize + traumaSize, shieldSize, activeSize, crossSize, reverse, borderSize)
        PlayerBars.ApplyHorizontalNoHealingFractures(widget, widget.noHealingFractureGlowTiles, nil, C.DRAW_LEVEL + 3, 0.78, 0.96, 1, 0.24, 0, activeSize, crossSize, reverse, borderSize)
        PlayerBars.ApplyHorizontalNoHealingFractures(widget, widget.noHealingFractureTiles, PlayerBars.TEXTURE_NO_HEALING, C.DRAW_LEVEL + 4, 0.86, 0.94, 0.96, 0.42, noHealingSize, activeSize, crossSize, reverse, borderSize)
    end
end

local function SetLabelText(label, text)
    if label and label.nqolText ~= text then
        label:SetText(text)
        label.nqolText = text
    end
end

local function SetStyledValueLabels(widget, resourceValue, resourceType, settings, staticUpdate)
    if resourceType == C.RESOURCE_MOUNT_STAMINA or resourceType == COMBAT_MECHANIC_FLAGS_WEREWOLF or resourceType == PlayerBars.SIEGE_HEALTH then
        return
    end

    local currentLabel = settings.reverse == true and widget.leftLabel or widget.rightLabel
    SetLabelText(currentLabel, FormatCurrentValue(resourceValue, resourceValue.maximum, settings.currentValue, false))

    if staticUpdate then
        local totalText
        if resourceType == C.RESOURCE_HEALTH then
            if healthVisuals.shield > 0 then
                totalText = FormatNumber(resourceValue.maximum) .. " + " .. FormatCompactNumber(healthVisuals.shield)
            else
                totalText = FormatNumber(resourceValue.maximum)
            end
        else
            totalText = FormatNumber(resourceValue.maximum)
        end

        local totalLabel = settings.reverse == true and widget.rightLabel or widget.leftLabel
        SetLabelText(totalLabel, totalText)
    end
end

local function ApplyResourceValueToStyledWidget(widget, resourceValue, resourceType, settings, staticUpdate, smoothUpdate)
    if not widget or not resourceValue then
        return
    end

    if staticUpdate then
        widget:SetHidden(resourceValue.hidden == true)
    end
    if resourceValue.hidden == true then
        if staticUpdate then
            PlayerBars.HideLossFill(widget)
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

    local rangeMaximum = resourceValue.maximum
    if rangeMaximum < 1 then
        rangeMaximum = 1
    end

    local width = widget:GetWidth() or 0
    local height = widget:GetHeight() or 0
    local borderSize = Clamp(settings.borderSize, C.CLASSIC_BORDER_SIZE_MIN, math.max(C.CLASSIC_BORDER_SIZE_MIN, zo_floor((height - 1) * 0.5)))
    local fillCurrent = resourceValue.current
    local traumaAmount = 0
    local shieldAmount = 0
    if resourceType == C.RESOURCE_HEALTH then
        if not widget.nqolStyledSmoothUpdateCallback then
            widget.nqolStyledSmoothUpdateCallback = function()
                ApplyResourceValueToStyledWidget(widget, resourceValue, resourceType, settings, false, true)
            end
        end
        fillCurrent, traumaAmount, shieldAmount = PlayerBars.GetAnimatedPlayerHealthSegments(widget, resourceValue, settings, widget.nqolStyledSmoothUpdateCallback)
    elseif settings.smoothTransitions == true and PlayerBars.Smooth then
        if not widget.nqolStyledSmoothUpdateCallback then
            widget.nqolStyledSmoothUpdateCallback = function()
                ApplyResourceValueToStyledWidget(widget, resourceValue, resourceType, settings, false, true)
            end
        end
        fillCurrent = PlayerBars.Smooth.GetValue(widget, resourceType, fillCurrent, widget.nqolStyledSmoothUpdateCallback, rangeMaximum)
    elseif staticUpdate and PlayerBars.Smooth then
        PlayerBars.Smooth.Reset(widget, resourceType)
    end
    local percent = Clamp(fillCurrent / rangeMaximum, 0, 1)
    local innerWidth = math.max(width - borderSize * 2, 0)
    local innerHeight = math.max(height - borderSize * 2, 0)
    local fillWidth = zo_floor(innerWidth * percent)

    if fillCurrent > 0 and fillWidth < 1 then
        fillWidth = 1
    end

    if staticUpdate then
        PlayerBars.ApplyWidgetBarColor(widget, resourceType, settings, true)
    end
    if settings.smoothTransitions == true and settings.transitionShadow == true then
        PlayerBars.ApplyLossFill(widget, resourceType, rangeMaximum, innerWidth, innerHeight, borderSize, settings.reverse == true, false, true)
    elseif staticUpdate then
        PlayerBars.HideLossFill(widget)
    end

    if staticUpdate then
        widget.fill:ClearAnchors()
        if settings.reverse == true then
            widget.fill:SetAnchor(TOPRIGHT, widget, TOPRIGHT, -borderSize, borderSize)
        else
            widget.fill:SetAnchor(TOPLEFT, widget, TOPLEFT, borderSize, borderSize)
        end
    end
    if widget.nqolFillWidth ~= fillWidth or widget.nqolFillHeight ~= innerHeight then
        widget.fill:SetDimensions(fillWidth, innerHeight)
        widget.nqolFillWidth = fillWidth
        widget.nqolFillHeight = innerHeight
    end
    if resourceType == C.RESOURCE_HEALTH then
        if staticUpdate then
            local red, green, blue, alpha = Shared.GetPlayerTraumaColor(settings)
            widget.trauma:SetCenterColor(red, green, blue, alpha)
            red, green, blue, alpha = Shared.GetPlayerShieldColor(settings)
            widget.shield:SetCenterColor(red, green, blue, alpha)
        end
        PlayerBars.ApplyHealthVisualOverlays(widget, resourceValue, rangeMaximum, innerWidth, innerHeight, borderSize, settings.reverse == true, false, nil, fillCurrent, traumaAmount, shieldAmount)
    elseif staticUpdate then
        PlayerBars.HideHealthVisualOverlays(widget)
    end

    if not smoothUpdate then
        SetStyledValueLabels(widget, resourceValue, resourceType, settings, staticUpdate)
    end
end

local function ApplyResourceValueToVerticalWidget(widget, resourceValue, resourceType, settings, staticUpdate, smoothUpdate)
    if not widget or not resourceValue then
        return
    end

    if staticUpdate then
        widget:SetHidden(resourceValue.hidden == true)
    end
    if resourceValue.hidden == true then
        if staticUpdate then
            PlayerBars.HideLossFill(widget)
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

    local rangeMaximum = resourceValue.maximum
    if rangeMaximum < 1 then
        rangeMaximum = 1
    end

    local width = widget:GetWidth() or 0
    local height = widget:GetHeight() or 0
    local borderSize = Clamp(settings.borderSize, C.CLASSIC_BORDER_SIZE_MIN, math.max(C.CLASSIC_BORDER_SIZE_MIN, zo_floor((math.min(width, height) - 1) * 0.5)))
    local fillCurrent = resourceValue.current
    local traumaAmount = 0
    local shieldAmount = 0
    if resourceType == C.RESOURCE_HEALTH then
        if not widget.nqolVerticalSmoothUpdateCallback then
            widget.nqolVerticalSmoothUpdateCallback = function()
                ApplyResourceValueToVerticalWidget(widget, resourceValue, resourceType, settings, false, true)
            end
        end
        fillCurrent, traumaAmount, shieldAmount = PlayerBars.GetAnimatedPlayerHealthSegments(widget, resourceValue, settings, widget.nqolVerticalSmoothUpdateCallback)
    elseif settings.smoothTransitions == true and PlayerBars.Smooth then
        if not widget.nqolVerticalSmoothUpdateCallback then
            widget.nqolVerticalSmoothUpdateCallback = function()
                ApplyResourceValueToVerticalWidget(widget, resourceValue, resourceType, settings, false, true)
            end
        end
        fillCurrent = PlayerBars.Smooth.GetValue(widget, resourceType, fillCurrent, widget.nqolVerticalSmoothUpdateCallback, rangeMaximum)
    elseif staticUpdate and PlayerBars.Smooth then
        PlayerBars.Smooth.Reset(widget, resourceType)
    end
    local percent = Clamp(fillCurrent / rangeMaximum, 0, 1)
    local innerWidth = math.max(width - borderSize * 2, 0)
    local innerHeight = math.max(height - borderSize * 2, 0)
    local fillHeight = zo_floor(innerHeight * percent)

    if fillCurrent > 0 and fillHeight < 1 then
        fillHeight = 1
    end

    local reverse = GetVerticalReverseForResource(resourceType, settings)
    if staticUpdate then
        PlayerBars.ApplyWidgetBarColor(widget, resourceType, settings, true)
    end
    if settings.smoothTransitions == true and settings.transitionShadow == true then
        PlayerBars.ApplyLossFill(widget, resourceType, rangeMaximum, innerWidth, innerHeight, borderSize, reverse, true, true)
    elseif staticUpdate then
        PlayerBars.HideLossFill(widget)
    end

    if staticUpdate then
        widget.fill:ClearAnchors()
        if reverse then
            widget.fill:SetAnchor(TOPLEFT, widget, TOPLEFT, borderSize, borderSize)
        else
            widget.fill:SetAnchor(BOTTOMLEFT, widget, BOTTOMLEFT, borderSize, -borderSize)
        end
    end
    if widget.nqolFillWidth ~= innerWidth or widget.nqolFillHeight ~= fillHeight then
        widget.fill:SetDimensions(innerWidth, fillHeight)
        widget.nqolFillWidth = innerWidth
        widget.nqolFillHeight = fillHeight
    end
    if resourceType == C.RESOURCE_HEALTH then
        if staticUpdate then
            local red, green, blue, alpha = Shared.GetPlayerTraumaColor(settings)
            widget.trauma:SetCenterColor(red, green, blue, alpha)
            red, green, blue, alpha = Shared.GetPlayerShieldColor(settings)
            widget.shield:SetCenterColor(red, green, blue, alpha)
        end
        PlayerBars.ApplyHealthVisualOverlays(widget, resourceValue, rangeMaximum, innerWidth, innerHeight, borderSize, reverse, true, nil, fillCurrent, traumaAmount, shieldAmount)
    elseif staticUpdate then
        PlayerBars.HideHealthVisualOverlays(widget)
    end

    if not smoothUpdate
        and resourceType ~= C.RESOURCE_MOUNT_STAMINA
        and resourceType ~= COMBAT_MECHANIC_FLAGS_WEREWOLF
        and resourceType ~= PlayerBars.SIEGE_HEALTH
    then
        SetLabelText(widget.rightLabel, FormatCurrentValue(resourceValue, resourceValue.maximum, GetVerticalCurrentValueForResource(resourceType, settings), true))
        if staticUpdate then
            if resourceType == C.RESOURCE_HEALTH and healthVisuals.shield > 0 then
                SetLabelText(widget.leftLabel, FormatCompactNumber(resourceValue.maximum) .. " + " .. FormatCompactNumber(healthVisuals.shield))
            else
                SetLabelText(widget.leftLabel, FormatCompactNumber(resourceValue.maximum))
            end
        end
    end
end

local function ApplyClassicResourceValues(preset)
    local widgets = preset.controls and preset.controls.widgets
    if not widgets then
        return
    end

    local settings = GetClassicSettings()
    for _, resourceType in ipairs(C.RESOURCE_KEYS) do
        ApplyResourceValueToStyledWidget(widgets[resourceType], resourceValues[resourceType], resourceType, settings, true)
    end
end

local function ApplyPyramidResourceValues(preset)
    local widgets = preset.controls and preset.controls.widgets
    if not widgets then
        return
    end

    local settings = GetPyramidSettings()
    for _, resourceType in ipairs(C.RESOURCE_KEYS) do
        ApplyResourceValueToStyledWidget(widgets[resourceType], resourceValues[resourceType], resourceType, settings, true)
    end
end

local function ApplyStackResourceValues(preset)
    local widgets = preset.controls and preset.controls.widgets
    if not widgets then
        return
    end

    local settings = GetStackSettings()
    for _, resourceType in ipairs(C.RESOURCE_KEYS) do
        ApplyResourceValueToStyledWidget(widgets[resourceType], resourceValues[resourceType], resourceType, settings, true)
    end
end

local function ApplyVerticalResourceValues(preset)
    local widgets = preset.controls and preset.controls.widgets
    if not widgets then
        return
    end

    local settings = GetVerticalSettings()
    for _, resourceType in ipairs(C.RESOURCE_KEYS) do
        ApplyResourceValueToVerticalWidget(widgets[resourceType], resourceValues[resourceType], resourceType, settings, true)
    end
end

local function ApplyFlatResourceValues(preset)
    local widgets = preset.controls and preset.controls.widgets
    if not widgets then
        return
    end

    for _, resourceType in ipairs(C.RESOURCE_KEYS) do
        ApplyResourceValueToWidget(widgets[resourceType], resourceValues[resourceType])
    end
end

local function UpdateResourceValues(force)
    for _, resourceType in ipairs(C.RESOURCE_KEYS) do
        UpdateResourceValue(resourceType, force)
    end
end

local function ApplyResourceValuesToPreset(preset)
    if preset.applyResources then
        preset.applyResources(preset, resourceValues)
        return
    end

    ApplyFlatResourceValues(preset)
end

local function ApplyResourceValueToPreset(preset, resourceType, settings, staticUpdate)
    local widgets = preset.controls and preset.controls.widgets
    local widget = widgets and widgets[resourceType]
    local resourceValue = resourceValues[resourceType]
    if not widget or not resourceValue then
        return
    end

    if preset.key == C.RADIAL then
        Radial.ApplyResource(preset, resourceValues, resourceType, settings, staticUpdate)
    elseif preset.key == C.VERTICAL then
        ApplyResourceValueToVerticalWidget(widget, resourceValue, resourceType, settings, staticUpdate)
    elseif preset.key == C.CLASSIC or preset.key == C.PYRAMID or preset.key == C.STACK then
        ApplyResourceValueToStyledWidget(widget, resourceValue, resourceType, settings, staticUpdate)
    else
        ApplyResourceValueToWidget(widget, resourceValue)
    end
end

function PlayerBars.GetVisibleSecondaryBarCount()
    return (resourceValues[C.RESOURCE_MOUNT_STAMINA] and resourceValues[C.RESOURCE_MOUNT_STAMINA].hidden ~= true and 1 or 0)
        + (resourceValues[COMBAT_MECHANIC_FLAGS_WEREWOLF] and resourceValues[COMBAT_MECHANIC_FLAGS_WEREWOLF].hidden ~= true and 1 or 0)
        + (resourceValues[PlayerBars.SIEGE_HEALTH] and resourceValues[PlayerBars.SIEGE_HEALTH].hidden ~= true and 1 or 0)
end

local function GetClassicHeight(preset)
    local settings = GetClassicSettings()
    local height = C.OUTER_PADDING * 2 + settings.boxHeight
    height = height + PlayerBars.GetVisibleSecondaryBarCount() * (C.CLASSIC_ROW_GAP + C.CLASSIC_MOUNT_HEIGHT)

    return height
end

local function GetPyramidHeight(preset)
    local settings = GetPyramidSettings()
    local height = C.OUTER_PADDING * 2 + settings.healthHeight + settings.resourceHeight + C.CLASSIC_ROW_GAP
    height = height + PlayerBars.GetVisibleSecondaryBarCount() * (C.CLASSIC_ROW_GAP + C.CLASSIC_MOUNT_HEIGHT)

    return height
end

local function GetStackHeight(preset)
    local settings = GetStackSettings()
    local height = C.OUTER_PADDING * 2 + settings.healthHeight + settings.magickaHeight + settings.staminaHeight + C.CLASSIC_ROW_GAP * 2
    height = height + PlayerBars.GetVisibleSecondaryBarCount() * (C.CLASSIC_ROW_GAP + C.CLASSIC_MOUNT_HEIGHT)

    return height
end

local function HideWidgetLabels(widget)
    if not widget then
        return
    end

    if widget.leftLabel then
        widget.leftLabel:SetHidden(true)
    end

    if widget.rightLabel then
        widget.rightLabel:SetHidden(true)
    end
end

function PlayerBars.AnchorMountIconLeft(widget)
    if not widget or not widget.icon then
        return
    end

    widget.icon:ClearAnchors()
    widget.icon:SetDimensions(16, 16)
    widget.icon:SetAnchor(RIGHT, widget, LEFT, -3, 0)
    widget.icon:SetHidden(false)
end

function PlayerBars.AnchorMountIconTop(widget)
    if not widget or not widget.icon then
        return
    end

    widget.icon:ClearAnchors()
    widget.icon:SetDimensions(16, 16)
    widget.icon:SetAnchor(BOTTOM, widget, TOP, 0, -3)
    widget.icon:SetHidden(false)
end

function PlayerBars.AnchorMountIconVertical(widget, reverse)
    if not widget or not widget.icon then
        return
    end

    widget.icon:ClearAnchors()
    widget.icon:SetDimensions(16, 16)
    if reverse then
        widget.icon:SetAnchor(TOP, widget, BOTTOM, 0, 3)
    else
        widget.icon:SetAnchor(BOTTOM, widget, TOP, 0, -3)
    end
    widget.icon:SetHidden(false)
end

function PlayerBars.ApplyPresetShadow(preset, settings)
    if not preset or not preset.controls or not preset.controls.widgets or not settings then
        return
    end

    for _, widget in pairs(preset.controls.widgets) do
        Shadow.Layout(widget, widget:GetWidth(), widget:GetHeight(), settings.borderSize, settings.shadow, settings.shadowIntensity)
    end
end

local function LayoutClassic(preset)
    local width = math.min(C.CLASSIC_WIDTH, math.floor(GetScreenWidth() * C.CLASSIC_WIDTH_RATIO))
    if width < C.CLASSIC_MIN_WIDTH then
        width = C.CLASSIC_MIN_WIDTH
    end

    local height = GetClassicHeight(preset)
    local root = preset.root
    local widgets = preset.controls.widgets
    root:SetDimensions(width + C.OUTER_PADDING * 2, height)

    local settings = GetClassicSettings()
    ApplyClassicLabelFont(preset)
    ApplyChangeFont(preset)
    ApplyClassicBorder(preset)

    local healthWidth = settings.healthWidth
    local magickaWidth = settings.magickaWidth
    local staminaWidth = settings.staminaWidth
    local separation = settings.separation
    local totalWidth = magickaWidth + healthWidth + staminaWidth + separation * 2
    if totalWidth > width then
        width = totalWidth
        root:SetDimensions(width + C.OUTER_PADDING * 2, height)
    end

    local healthX = zo_floor((width - healthWidth) * 0.5)
    local magickaX = healthX - separation - magickaWidth
    local staminaX = healthX + healthWidth + separation
    local y = C.OUTER_PADDING

    widgets[C.RESOURCE_MAGICKA]:ClearAnchors()
    widgets[C.RESOURCE_MAGICKA]:SetDimensions(magickaWidth, settings.boxHeight)
    widgets[C.RESOURCE_MAGICKA]:SetAnchor(TOPLEFT, root, TOPLEFT, C.OUTER_PADDING + magickaX, y)

    widgets[C.RESOURCE_HEALTH]:ClearAnchors()
    widgets[C.RESOURCE_HEALTH]:SetDimensions(healthWidth, settings.boxHeight)
    widgets[C.RESOURCE_HEALTH]:SetAnchor(TOPLEFT, root, TOPLEFT, C.OUTER_PADDING + healthX, y)

    widgets[C.RESOURCE_STAMINA]:ClearAnchors()
    widgets[C.RESOURCE_STAMINA]:SetDimensions(staminaWidth, settings.boxHeight)
    widgets[C.RESOURCE_STAMINA]:SetAnchor(TOPLEFT, root, TOPLEFT, C.OUTER_PADDING + staminaX, y)
    y = y + settings.boxHeight + C.CLASSIC_ROW_GAP

    if resourceValues[PlayerBars.SIEGE_HEALTH] and resourceValues[PlayerBars.SIEGE_HEALTH].hidden ~= true then
        widgets[PlayerBars.SIEGE_HEALTH]:ClearAnchors()
        widgets[PlayerBars.SIEGE_HEALTH]:SetDimensions(healthWidth, C.CLASSIC_MOUNT_HEIGHT)
        widgets[PlayerBars.SIEGE_HEALTH]:SetAnchor(TOPLEFT, root, TOPLEFT, C.OUTER_PADDING + healthX, y)
        HideWidgetLabels(widgets[PlayerBars.SIEGE_HEALTH])
        PlayerBars.AnchorMountIconLeft(widgets[PlayerBars.SIEGE_HEALTH])
        y = y + C.CLASSIC_MOUNT_HEIGHT + C.CLASSIC_ROW_GAP
    end

    if resourceValues[COMBAT_MECHANIC_FLAGS_WEREWOLF] and resourceValues[COMBAT_MECHANIC_FLAGS_WEREWOLF].hidden ~= true then
        widgets[COMBAT_MECHANIC_FLAGS_WEREWOLF]:ClearAnchors()
        widgets[COMBAT_MECHANIC_FLAGS_WEREWOLF]:SetDimensions(magickaWidth, C.CLASSIC_MOUNT_HEIGHT)
        widgets[COMBAT_MECHANIC_FLAGS_WEREWOLF]:SetAnchor(TOPLEFT, root, TOPLEFT, C.OUTER_PADDING + magickaX, y)
        HideWidgetLabels(widgets[COMBAT_MECHANIC_FLAGS_WEREWOLF])
        PlayerBars.AnchorMountIconLeft(widgets[COMBAT_MECHANIC_FLAGS_WEREWOLF])
        y = y + C.CLASSIC_MOUNT_HEIGHT + C.CLASSIC_ROW_GAP
    end

    if resourceValues[C.RESOURCE_MOUNT_STAMINA] and resourceValues[C.RESOURCE_MOUNT_STAMINA].hidden ~= true then
        widgets[C.RESOURCE_MOUNT_STAMINA]:ClearAnchors()
        widgets[C.RESOURCE_MOUNT_STAMINA]:SetDimensions(staminaWidth, C.CLASSIC_MOUNT_HEIGHT)
        widgets[C.RESOURCE_MOUNT_STAMINA]:SetAnchor(TOPLEFT, root, TOPLEFT, C.OUTER_PADDING + staminaX, y)
        HideWidgetLabels(widgets[C.RESOURCE_MOUNT_STAMINA])
        PlayerBars.AnchorMountIconLeft(widgets[C.RESOURCE_MOUNT_STAMINA])
    end

    PlayerBars.ApplyPresetShadow(preset, settings)
end

local function LayoutPyramid(preset)
    local width = math.min(C.CLASSIC_WIDTH, math.floor(GetScreenWidth() * C.CLASSIC_WIDTH_RATIO))
    if width < C.CLASSIC_MIN_WIDTH then
        width = C.CLASSIC_MIN_WIDTH
    end

    local height = GetPyramidHeight(preset)
    local root = preset.root
    local widgets = preset.controls.widgets
    root:SetDimensions(width + C.OUTER_PADDING * 2, height)

    local settings = GetPyramidSettings()
    ApplyPyramidLabelFont(preset)
    ApplyChangeFont(preset)
    ApplyPyramidBorder(preset)

    local healthWidth = settings.healthWidth
    local magickaWidth = settings.magickaWidth
    local staminaWidth = settings.staminaWidth
    local healthHeight = settings.healthHeight
    local resourceHeight = settings.resourceHeight
    local bottomWidth = magickaWidth + staminaWidth + C.CLASSIC_ROW_GAP
    local totalWidth = math.max(healthWidth, bottomWidth)
    if totalWidth > width then
        width = totalWidth
        root:SetDimensions(width + C.OUTER_PADDING * 2, height)
    end

    local healthX = zo_floor((width - healthWidth) * 0.5)
    local bottomX = zo_floor((width - bottomWidth) * 0.5)
    local y = C.OUTER_PADDING

    widgets[C.RESOURCE_HEALTH]:ClearAnchors()
    widgets[C.RESOURCE_HEALTH]:SetDimensions(healthWidth, healthHeight)
    widgets[C.RESOURCE_HEALTH]:SetAnchor(TOPLEFT, root, TOPLEFT, C.OUTER_PADDING + healthX, y)
    y = y + healthHeight + C.CLASSIC_ROW_GAP

    widgets[C.RESOURCE_MAGICKA]:ClearAnchors()
    widgets[C.RESOURCE_MAGICKA]:SetDimensions(magickaWidth, resourceHeight)
    widgets[C.RESOURCE_MAGICKA]:SetAnchor(TOPLEFT, root, TOPLEFT, C.OUTER_PADDING + bottomX, y)

    widgets[C.RESOURCE_STAMINA]:ClearAnchors()
    widgets[C.RESOURCE_STAMINA]:SetDimensions(staminaWidth, resourceHeight)
    widgets[C.RESOURCE_STAMINA]:SetAnchor(TOPLEFT, root, TOPLEFT, C.OUTER_PADDING + bottomX + magickaWidth + C.CLASSIC_ROW_GAP, y)
    y = y + resourceHeight + C.CLASSIC_ROW_GAP

    if resourceValues[PlayerBars.SIEGE_HEALTH] and resourceValues[PlayerBars.SIEGE_HEALTH].hidden ~= true then
        widgets[PlayerBars.SIEGE_HEALTH]:ClearAnchors()
        widgets[PlayerBars.SIEGE_HEALTH]:SetDimensions(healthWidth, C.CLASSIC_MOUNT_HEIGHT)
        widgets[PlayerBars.SIEGE_HEALTH]:SetAnchor(TOPLEFT, root, TOPLEFT, C.OUTER_PADDING + healthX, y)
        HideWidgetLabels(widgets[PlayerBars.SIEGE_HEALTH])
        PlayerBars.AnchorMountIconLeft(widgets[PlayerBars.SIEGE_HEALTH])
        y = y + C.CLASSIC_MOUNT_HEIGHT + C.CLASSIC_ROW_GAP
    end

    if resourceValues[COMBAT_MECHANIC_FLAGS_WEREWOLF] and resourceValues[COMBAT_MECHANIC_FLAGS_WEREWOLF].hidden ~= true then
        widgets[COMBAT_MECHANIC_FLAGS_WEREWOLF]:ClearAnchors()
        widgets[COMBAT_MECHANIC_FLAGS_WEREWOLF]:SetDimensions(magickaWidth, C.CLASSIC_MOUNT_HEIGHT)
        widgets[COMBAT_MECHANIC_FLAGS_WEREWOLF]:SetAnchor(TOPLEFT, root, TOPLEFT, C.OUTER_PADDING + bottomX, y)
        HideWidgetLabels(widgets[COMBAT_MECHANIC_FLAGS_WEREWOLF])
        PlayerBars.AnchorMountIconLeft(widgets[COMBAT_MECHANIC_FLAGS_WEREWOLF])
        y = y + C.CLASSIC_MOUNT_HEIGHT + C.CLASSIC_ROW_GAP
    end

    if resourceValues[C.RESOURCE_MOUNT_STAMINA] and resourceValues[C.RESOURCE_MOUNT_STAMINA].hidden ~= true then
        widgets[C.RESOURCE_MOUNT_STAMINA]:ClearAnchors()
        widgets[C.RESOURCE_MOUNT_STAMINA]:SetDimensions(staminaWidth, C.CLASSIC_MOUNT_HEIGHT)
        widgets[C.RESOURCE_MOUNT_STAMINA]:SetAnchor(TOPLEFT, root, TOPLEFT, C.OUTER_PADDING + bottomX + magickaWidth + C.CLASSIC_ROW_GAP, y)
        HideWidgetLabels(widgets[C.RESOURCE_MOUNT_STAMINA])
        PlayerBars.AnchorMountIconLeft(widgets[C.RESOURCE_MOUNT_STAMINA])
    end

    PlayerBars.ApplyPresetShadow(preset, settings)
end

local function LayoutStack(preset)
    local width = math.min(C.CLASSIC_WIDTH, math.floor(GetScreenWidth() * C.CLASSIC_WIDTH_RATIO))
    if width < C.CLASSIC_MIN_WIDTH then
        width = C.CLASSIC_MIN_WIDTH
    end

    local height = GetStackHeight(preset)
    local root = preset.root
    local widgets = preset.controls.widgets
    root:SetDimensions(width + C.OUTER_PADDING * 2, height)

    local settings = GetStackSettings()
    ApplyStackLabelFont(preset)
    ApplyChangeFont(preset)
    ApplyStackBorder(preset)

    width = math.max(width, settings.width)
    root:SetDimensions(width + C.OUTER_PADDING * 2, height)

    local y = C.OUTER_PADDING
    local barX = zo_floor((width - settings.width) * 0.5)
    widgets[C.RESOURCE_HEALTH]:ClearAnchors()
    widgets[C.RESOURCE_HEALTH]:SetDimensions(settings.width, settings.healthHeight)
    widgets[C.RESOURCE_HEALTH]:SetAnchor(TOPLEFT, root, TOPLEFT, C.OUTER_PADDING + barX, y)
    y = y + settings.healthHeight + C.CLASSIC_ROW_GAP

    widgets[C.RESOURCE_MAGICKA]:ClearAnchors()
    widgets[C.RESOURCE_MAGICKA]:SetDimensions(settings.width, settings.magickaHeight)
    widgets[C.RESOURCE_MAGICKA]:SetAnchor(TOPLEFT, root, TOPLEFT, C.OUTER_PADDING + barX, y)
    y = y + settings.magickaHeight + C.CLASSIC_ROW_GAP

    widgets[C.RESOURCE_STAMINA]:ClearAnchors()
    widgets[C.RESOURCE_STAMINA]:SetDimensions(settings.width, settings.staminaHeight)
    widgets[C.RESOURCE_STAMINA]:SetAnchor(TOPLEFT, root, TOPLEFT, C.OUTER_PADDING + barX, y)
    y = y + settings.staminaHeight + C.CLASSIC_ROW_GAP

    if resourceValues[PlayerBars.SIEGE_HEALTH] and resourceValues[PlayerBars.SIEGE_HEALTH].hidden ~= true then
        widgets[PlayerBars.SIEGE_HEALTH]:ClearAnchors()
        widgets[PlayerBars.SIEGE_HEALTH]:SetDimensions(settings.width, C.CLASSIC_MOUNT_HEIGHT)
        widgets[PlayerBars.SIEGE_HEALTH]:SetAnchor(TOPLEFT, root, TOPLEFT, C.OUTER_PADDING + barX, y)
        HideWidgetLabels(widgets[PlayerBars.SIEGE_HEALTH])
        PlayerBars.AnchorMountIconLeft(widgets[PlayerBars.SIEGE_HEALTH])
        y = y + C.CLASSIC_MOUNT_HEIGHT + C.CLASSIC_ROW_GAP
    end

    if resourceValues[COMBAT_MECHANIC_FLAGS_WEREWOLF] and resourceValues[COMBAT_MECHANIC_FLAGS_WEREWOLF].hidden ~= true then
        widgets[COMBAT_MECHANIC_FLAGS_WEREWOLF]:ClearAnchors()
        widgets[COMBAT_MECHANIC_FLAGS_WEREWOLF]:SetDimensions(settings.width, C.CLASSIC_MOUNT_HEIGHT)
        widgets[COMBAT_MECHANIC_FLAGS_WEREWOLF]:SetAnchor(TOPLEFT, root, TOPLEFT, C.OUTER_PADDING + barX, y)
        HideWidgetLabels(widgets[COMBAT_MECHANIC_FLAGS_WEREWOLF])
        PlayerBars.AnchorMountIconLeft(widgets[COMBAT_MECHANIC_FLAGS_WEREWOLF])
        y = y + C.CLASSIC_MOUNT_HEIGHT + C.CLASSIC_ROW_GAP
    end

    if resourceValues[C.RESOURCE_MOUNT_STAMINA] and resourceValues[C.RESOURCE_MOUNT_STAMINA].hidden ~= true then
        widgets[C.RESOURCE_MOUNT_STAMINA]:ClearAnchors()
        widgets[C.RESOURCE_MOUNT_STAMINA]:SetDimensions(settings.width, C.CLASSIC_MOUNT_HEIGHT)
        widgets[C.RESOURCE_MOUNT_STAMINA]:SetAnchor(TOPLEFT, root, TOPLEFT, C.OUTER_PADDING + barX, y)
        HideWidgetLabels(widgets[C.RESOURCE_MOUNT_STAMINA])
        PlayerBars.AnchorMountIconLeft(widgets[C.RESOURCE_MOUNT_STAMINA])
    end

    PlayerBars.ApplyPresetShadow(preset, settings)
end

local function LayoutVerticalResource(widget, root, width, height, x, y, reverse)
    widget:ClearAnchors()
    widget:SetDimensions(width, height)
    widget:SetAnchor(TOPLEFT, root, TOPLEFT, C.OUTER_PADDING + x, C.OUTER_PADDING + y)

    if widget.leftLabel then
        widget.leftLabel:ClearAnchors()
        widget.leftLabel:SetDimensions(math.max(width * 3, 72), 20)
        widget.leftLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        if reverse then
            widget.leftLabel:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
            widget.leftLabel:SetAnchor(BOTTOM, widget, TOP, 0, -4)
        else
            widget.leftLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)
            widget.leftLabel:SetAnchor(TOP, widget, BOTTOM, 0, 4)
        end
    end

    if widget.rightLabel then
        widget.rightLabel:ClearAnchors()
        widget.rightLabel:SetDimensions(math.max(width * 3, 72), 20)
        widget.rightLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        if reverse then
            widget.rightLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)
            widget.rightLabel:SetAnchor(TOP, widget, BOTTOM, 0, 4)
        else
            widget.rightLabel:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
            widget.rightLabel:SetAnchor(BOTTOM, widget, TOP, 0, -4)
        end
    end
end

local function GetVerticalPositionPixels(position, available)
    return math.max(available, 0) * Clamp(tonumber(position) or 0, 0, 100) / 100
end

local function LayoutVertical(preset)
    local root = preset.root
    local widgets = preset.controls.widgets
    local settings = GetVerticalSettings()

    ApplyVerticalLabelFont(preset)
    ApplyChangeFont(preset)
    ApplyVerticalBorder(preset)

    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    root:SetDimensions(screenWidth, screenHeight)

    local healthX = GetVerticalPositionPixels(settings.healthHorizontalPosition, screenWidth - settings.healthWidth - (C.OUTER_PADDING * 2))
    local healthY = GetVerticalPositionPixels(settings.healthVerticalPosition, screenHeight - settings.healthHeight - (C.OUTER_PADDING * 2))
    local magickaX = GetVerticalPositionPixels(settings.magickaHorizontalPosition, screenWidth - settings.magickaWidth - (C.OUTER_PADDING * 2))
    local magickaY = GetVerticalPositionPixels(settings.magickaVerticalPosition, screenHeight - settings.magickaHeight - (C.OUTER_PADDING * 2))
    local staminaX = GetVerticalPositionPixels(settings.staminaHorizontalPosition, screenWidth - settings.staminaWidth - (C.OUTER_PADDING * 2))
    local staminaY = GetVerticalPositionPixels(settings.staminaVerticalPosition, screenHeight - settings.staminaHeight - (C.OUTER_PADDING * 2))

    LayoutVerticalResource(widgets[C.RESOURCE_HEALTH], root, settings.healthWidth, settings.healthHeight, healthX, healthY, settings.healthReverse == true)
    LayoutVerticalResource(widgets[C.RESOURCE_MAGICKA], root, settings.magickaWidth, settings.magickaHeight, magickaX, magickaY, settings.magickaReverse == true)
    LayoutVerticalResource(widgets[C.RESOURCE_STAMINA], root, settings.staminaWidth, settings.staminaHeight, staminaX, staminaY, settings.staminaReverse == true)

    local siegeX = healthX - C.CLASSIC_ROW_GAP - C.CLASSIC_MOUNT_HEIGHT
    if healthX < screenWidth * 0.5 then
        siegeX = healthX + settings.healthWidth + C.CLASSIC_ROW_GAP
    end

    local healthReverse = settings.healthReverse == true
    LayoutVerticalResource(widgets[PlayerBars.SIEGE_HEALTH], root, C.CLASSIC_MOUNT_HEIGHT, settings.healthHeight, siegeX, healthY, healthReverse)
    HideWidgetLabels(widgets[PlayerBars.SIEGE_HEALTH])
    PlayerBars.AnchorMountIconVertical(widgets[PlayerBars.SIEGE_HEALTH], healthReverse)

    local werewolfX = magickaX - C.CLASSIC_ROW_GAP - C.CLASSIC_MOUNT_HEIGHT
    if magickaX < screenWidth * 0.5 then
        werewolfX = magickaX + settings.magickaWidth + C.CLASSIC_ROW_GAP
    end

    local magickaReverse = settings.magickaReverse == true
    LayoutVerticalResource(widgets[COMBAT_MECHANIC_FLAGS_WEREWOLF], root, C.CLASSIC_MOUNT_HEIGHT, settings.magickaHeight, werewolfX, magickaY, magickaReverse)
    HideWidgetLabels(widgets[COMBAT_MECHANIC_FLAGS_WEREWOLF])
    PlayerBars.AnchorMountIconVertical(widgets[COMBAT_MECHANIC_FLAGS_WEREWOLF], magickaReverse)

    local mountX = staminaX + settings.staminaWidth + C.CLASSIC_ROW_GAP
    if staminaX > screenWidth * 0.5 then
        mountX = staminaX - C.CLASSIC_ROW_GAP - C.CLASSIC_MOUNT_HEIGHT
    end

    local staminaReverse = settings.staminaReverse == true
    LayoutVerticalResource(widgets[C.RESOURCE_MOUNT_STAMINA], root, C.CLASSIC_MOUNT_HEIGHT, settings.staminaHeight, mountX, staminaY, staminaReverse)
    HideWidgetLabels(widgets[C.RESOURCE_MOUNT_STAMINA])
    PlayerBars.AnchorMountIconVertical(widgets[C.RESOURCE_MOUNT_STAMINA], staminaReverse)

    PlayerBars.ApplyPresetShadow(preset, settings)
end

local function GetRootSettingsForPreset(preset)
    if preset and preset.key == C.PYRAMID then
        return GetPyramidSettings()
    end

    if preset and preset.key == C.STACK then
        return GetStackSettings()
    end

    if preset and preset.key == C.VERTICAL then
        return nil
    end

    if preset and preset.key == C.RADIAL then
        return nil
    end

    return GetClassicSettings()
end

local function CreatePreset(key, controlName, createControlsFunction, layoutFunction, applyResourcesFunction)
    return {
        key = key,
        controlName = controlName,
        createControls = createControlsFunction,
        layout = layoutFunction,
        applyResources = applyResourcesFunction,
        root = nil,
        controls = nil,
    }
end

presets[C.CLASSIC] = CreatePreset(C.CLASSIC, C.ROOT_CONTROL_NAME .. "Classic", CreateClassicControls, LayoutClassic, ApplyClassicResourceValues)
presets[C.PYRAMID] = CreatePreset(C.PYRAMID, C.ROOT_CONTROL_NAME .. "Pyramid", CreatePyramidControls, LayoutPyramid, ApplyPyramidResourceValues)
presets[C.STACK] = CreatePreset(C.STACK, C.ROOT_CONTROL_NAME .. "Stack", CreateStackControls, LayoutStack, ApplyStackResourceValues)
presets[C.VERTICAL] = CreatePreset(C.VERTICAL, C.ROOT_CONTROL_NAME .. "Vertical", CreateVerticalControls, LayoutVertical, ApplyVerticalResourceValues)
presets[C.RADIAL] = CreatePreset(C.RADIAL, C.ROOT_CONTROL_NAME .. "Radial", Radial.CreateControls, Radial.Layout, Radial.ApplyResources)

local function EnsurePresetControls(preset)
    if preset.root or not WINDOW_MANAGER or not GuiRoot then
        return preset.root ~= nil
    end

    preset.root = CreateRootControl(preset.controlName)
    preset.controls = preset.createControls(preset.root)
    return true
end

local function GetActivePreset()
    local presetKey = GetSettings().preset
    return presets[presetKey] or presets[C.CLASSIC]
end

local function HidePlayerBars()
    for _, preset in pairs(presets) do
        if preset.root then
            SetFrameVisibilityImmediate(preset.root, false)
        end

        local widgets = preset.controls and preset.controls.widgets
        if widgets then
            for _, widget in pairs(widgets) do
                HideClassicChangeLabels(widget)
            end
            PlayerBars.ResetPlayerHealthAnimations(widgets[C.RESOURCE_HEALTH])
        end
    end
end

local function Refresh()
    refreshQueued = false

    local settings = GetSettings()
    local previewVisible = IsPreviewVisible()
    local shouldShowFrame = (settings.showNqolPlayerFrame == true or previewVisible)
        and ShouldShowForCurrentScene()
    local combatOnly = not previewVisible and settings.showOnlyInCombat == true

    if not shouldShowFrame then
        HidePlayerBars()
        return
    end

    -- Build the active preset while hidden so its textures are loaded before the first combat fade-in.
    local inCombat = IsUnitInCombat and IsUnitInCombat("player") == true

    local preset = GetActivePreset()
    if not EnsurePresetControls(preset) then
        return
    end

    if not previewVisible then
        for _, otherPreset in pairs(presets) do
            Shared.RestoreDrawOrder(otherPreset.root)
        end
    end

    if activePresetKey ~= preset.key then
        HidePlayerBars()
        activePresetKey = preset.key
    end

    InitializeResourceValues()
    UpdateResourceValues()
    PlayerBars.UpdateHealthVisualValues()
    ApplyResourceValuesToPreset(preset)
    preset.layout(preset, resourceValues)
    ApplyResourceValuesToPreset(preset)
    ApplyRootPosition(preset.root, GetRootSettingsForPreset(preset))
    if previewVisible then
        Shared.SetSettingsPreviewDrawOrder(preset.root)
    end
    if combatOnly then
        SetFrameCombatVisibility(preset.root, inCombat)
    else
        SetFrameVisibilityImmediate(preset.root, true)
    end
end

local function QueueRefresh()
    if not runtimeActive then
        refreshQueued = false
        HidePlayerBars()
        return
    end

    if refreshQueued then
        return
    end

    refreshQueued = true
    if zo_callLater then
        zo_callLater(Refresh, C.APPLY_DELAY_MS)
    else
        Refresh()
    end
end

PlayerBars.QueueRefresh = QueueRefresh

function PlayerBar.ApplySettingsPanelVisibility(value)
    settingsPanelVisible = value == true
    PlayerBar.RefreshRuntimeState()
    QueueRefresh()
end

function PlayerBar.HidePresetChangeLabels(presetKey)
    local preset = presets[presetKey]
    local widgets = preset and preset.controls and preset.controls.widgets
    if widgets then
        for _, widget in pairs(widgets) do
            HideClassicChangeLabels(widget)
        end
    end
end

local function OnPowerUpdate(_, unitTag, _, powerType, powerValue, powerMaximum, powerEffectiveMaximum)
    if not runtimeActive then
        return
    end

    if unitTag == "controlledsiege" or unitTag == "escortedram" then
        if powerType ~= C.RESOURCE_HEALTH then
            return
        end

        powerType = PlayerBars.SIEGE_HEALTH
    elseif unitTag ~= "player" then
        return
    end

    if powerType ~= C.RESOURCE_HEALTH
        and powerType ~= C.RESOURCE_MAGICKA
        and powerType ~= C.RESOURCE_STAMINA
        and powerType ~= C.RESOURCE_MOUNT_STAMINA
        and powerType ~= COMBAT_MECHANIC_FLAGS_WEREWOLF
        and powerType ~= PlayerBars.SIEGE_HEALTH
    then
        return
    end

    local preset = GetActivePreset()
    if not preset.root or preset.root:IsHidden() then
        return
    end

    local resourceValue = resourceValues[powerType]
    local oldCurrent = resourceValue and resourceValue.current
    local oldMaximum = resourceValue and resourceValue.maximum
    local oldEffectiveMaximum = resourceValue and resourceValue.effectiveMaximum
    local oldHidden = resourceValue and resourceValue.hidden
    if not StoreResourceValue(powerType, powerValue, powerMaximum, powerEffectiveMaximum) then
        return
    end

    local settings = GetPresetSettings(preset)
    local isSecondary = IsSecondaryPlayerBarResource(powerType)
    if isSecondary and oldHidden ~= resourceValue.hidden then
        preset.layout(preset, resourceValues)
        ApplyResourceValuesToPreset(preset)
        ApplyRootPosition(preset.root, GetRootSettingsForPreset(preset))
    else
        local staticUpdate = oldMaximum ~= resourceValue.maximum or oldEffectiveMaximum ~= resourceValue.effectiveMaximum
        ApplyResourceValueToPreset(preset, powerType, settings, staticUpdate)
    end

    if not isSecondary and oldCurrent ~= nil then
        local amount = resourceValue.current - oldCurrent
        local shouldAnimate = (amount > 0 and settings.flyingPositiveAnimation == true)
            or (amount < 0 and settings.flyingNegativeAnimation == true)
        if shouldAnimate then
            local widget = preset.controls and preset.controls.widgets and preset.controls.widgets[powerType]
            if widget then
                PlayChangeNumber(widget, amount, settings, GetChangeDirection(preset, powerType, settings))
            end
        end
    end
end

function PlayerBars.IsPlayerHealthVisual(visualType, stat, attribute, powerType)
    return (visualType == ATTRIBUTE_VISUAL_POWER_SHIELDING
            or visualType == ATTRIBUTE_VISUAL_TRAUMA
            or visualType == ATTRIBUTE_VISUAL_NO_HEALING)
        and stat == STAT_MITIGATION
        and attribute == ATTRIBUTE_HEALTH
        and powerType == C.RESOURCE_HEALTH
end

local function RefreshAfterHealthVisualChanged()
    if not runtimeActive then
        return
    end

    local previousShield = healthVisuals.showShield == true and healthVisuals.shield or 0
    PlayerBars.UpdateHealthVisualValues(true)
    local currentShield = healthVisuals.showShield == true and healthVisuals.shield or 0
    local shieldVisibilityChanged = (previousShield > 0) ~= (currentShield > 0)

    local preset = GetActivePreset()
    if shieldVisibilityChanged and PlayerBars.Smooth then
        local widgets = preset.controls and preset.controls.widgets
        local healthWidget = widgets and widgets[C.RESOURCE_HEALTH]
        if healthWidget then
            PlayerBars.ResetPlayerHealthAnimations(healthWidget)
        end
    end
    if not preset.root then
        QueueRefresh()
    elseif not preset.root:IsHidden() then
        ApplyResourceValueToPreset(preset, C.RESOURCE_HEALTH, GetPresetSettings(preset), true)
    end
end

local function OnAttributeVisualAdded(_, unitTag, visualType, stat, attribute, powerType)
    if unitTag == "player" and PlayerBars.IsPlayerHealthVisual(visualType, stat, attribute, powerType) then
        RefreshAfterHealthVisualChanged()
    end
end

local function OnAttributeVisualUpdated(_, unitTag, visualType, stat, attribute, powerType)
    if unitTag == "player" and PlayerBars.IsPlayerHealthVisual(visualType, stat, attribute, powerType) then
        RefreshAfterHealthVisualChanged()
    end
end

local function OnAttributeVisualRemoved(_, unitTag, visualType, stat, attribute, powerType)
    if unitTag == "player" and PlayerBars.IsPlayerHealthVisual(visualType, stat, attribute, powerType) then
        RefreshAfterHealthVisualChanged()
    end
end

local function OnSceneStateChanged(scene, _, newState)
    local sceneName = scene and scene.GetName and scene:GetName() or nil
    local isGameplayScene = C.GAMEPLAY_SCENES[sceneName] == true
    local isShowing = newState == SCENE_SHOWING or newState == SCENE_SHOWN

    if newState == SCENE_HIDING then
        HidePlayerBars()
        COMPANION.HideFrame()
        PlayerBars.Group.HideFrame()
        return
    end

    if isShowing and not isGameplayScene and runtimeActive and not ShouldShowForCurrentScene() then
        HidePlayerBars()
    end

    if isShowing and not isGameplayScene and COMPANION.IsRuntimeActive() and not COMPANION.ShouldShowForCurrentScene() then
        COMPANION.HideFrame()
    end

    if isShowing and not isGameplayScene and PlayerBars.Group.IsRuntimeActive() and not PlayerBars.Group.ShouldShowForCurrentScene() then
        PlayerBars.Group.HideFrame()
    end

    if isShowing and runtimeActive and ShouldShowForCurrentScene() then
        QueueRefresh()
    end

    if isShowing and COMPANION.IsRuntimeActive() and COMPANION.ShouldShowForCurrentScene() then
        COMPANION.QueueRefresh()
    end

    if isShowing and PlayerBars.Group.IsRuntimeActive() and PlayerBars.Group.ShouldShowForCurrentScene() then
        PlayerBars.Group.QueueRefresh()
    end
end

local function InstallSceneCallback()
    if sceneCallbackInstalled or not SCENE_MANAGER or not SCENE_MANAGER.RegisterCallback then
        return
    end

    sceneCallbackInstalled = true
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", OnSceneStateChanged)
end

local function UninstallSceneCallback()
    if not sceneCallbackInstalled
        or not SCENE_MANAGER
        or not SCENE_MANAGER.UnregisterCallback
    then
        return
    end

    SCENE_MANAGER:UnregisterCallback("SceneStateChanged", OnSceneStateChanged)
    sceneCallbackInstalled = false
end

local function OnGroupPowerUpdate(_, unitTag, _, powerType, powerValue, powerMax, powerEffectiveMax)
    if PlayerBars.Group.IsRuntimeActive()
        and powerType == C.RESOURCE_HEALTH
        and unitTag
        and ZO_Group_IsGroupUnitTag
        and ZO_Group_IsGroupUnitTag(unitTag)
    then
        PlayerBars.Group.QueuePowerUpdate(unitTag, powerValue, powerMax, powerEffectiveMax)
    end
end

local function RefreshPowerEventRegistrations()
    if not eventsInstalled or not EVENT_MANAGER then
        return
    end

    local shouldRegisterPlayer = runtimeActive
    if shouldRegisterPlayer and not playerPowerEventsRegistered then
        EVENT_MANAGER:RegisterForEvent(C.EVENT_NAMESPACE, EVENT_POWER_UPDATE, OnPowerUpdate)
        if EVENT_MANAGER.AddFilterForEvent and REGISTER_FILTER_UNIT_TAG then
            EVENT_MANAGER:AddFilterForEvent(C.EVENT_NAMESPACE, EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")
            EVENT_MANAGER:RegisterForEvent(C.EVENT_NAMESPACE .. "_ControlledSiege", EVENT_POWER_UPDATE, OnPowerUpdate)
            EVENT_MANAGER:AddFilterForEvent(C.EVENT_NAMESPACE .. "_ControlledSiege", EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, "controlledsiege")
            EVENT_MANAGER:RegisterForEvent(C.EVENT_NAMESPACE .. "_EscortedRam", EVENT_POWER_UPDATE, OnPowerUpdate)
            EVENT_MANAGER:AddFilterForEvent(C.EVENT_NAMESPACE .. "_EscortedRam", EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, "escortedram")
        end
        playerPowerEventsRegistered = true
    elseif not shouldRegisterPlayer and playerPowerEventsRegistered then
        EVENT_MANAGER:UnregisterForEvent(C.EVENT_NAMESPACE, EVENT_POWER_UPDATE)
        EVENT_MANAGER:UnregisterForEvent(C.EVENT_NAMESPACE .. "_ControlledSiege", EVENT_POWER_UPDATE)
        EVENT_MANAGER:UnregisterForEvent(C.EVENT_NAMESPACE .. "_EscortedRam", EVENT_POWER_UPDATE)
        playerPowerEventsRegistered = false
    end

    local shouldRegisterCompanion = COMPANION.IsRuntimeActive()
    if shouldRegisterCompanion and not companionPowerEventsRegistered then
        EVENT_MANAGER:RegisterForEvent(COMPANION.EVENT_NAMESPACE, EVENT_POWER_UPDATE, COMPANION.OnPowerUpdate)
        if EVENT_MANAGER.AddFilterForEvent and REGISTER_FILTER_UNIT_TAG then
            EVENT_MANAGER:AddFilterForEvent(COMPANION.EVENT_NAMESPACE, EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, "companion")
        end
        companionPowerEventsRegistered = true
    elseif not shouldRegisterCompanion and companionPowerEventsRegistered then
        EVENT_MANAGER:UnregisterForEvent(COMPANION.EVENT_NAMESPACE, EVENT_POWER_UPDATE)
        companionPowerEventsRegistered = false
    end

    local shouldRegisterGroup = PlayerBars.Group.IsRuntimeActive()
    if shouldRegisterGroup and not groupPowerEventsRegistered then
        EVENT_MANAGER:RegisterForEvent(PlayerBars.Group.EVENT_NAMESPACE, EVENT_POWER_UPDATE, OnGroupPowerUpdate)
        if EVENT_MANAGER.AddFilterForEvent then
            if REGISTER_FILTER_UNIT_TAG_PREFIX then
                EVENT_MANAGER:AddFilterForEvent(PlayerBars.Group.EVENT_NAMESPACE, EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
            end
            if REGISTER_FILTER_POWER_TYPE then
                EVENT_MANAGER:AddFilterForEvent(PlayerBars.Group.EVENT_NAMESPACE, EVENT_POWER_UPDATE, REGISTER_FILTER_POWER_TYPE, C.RESOURCE_HEALTH)
            end
        end
        groupPowerEventsRegistered = true
    elseif not shouldRegisterGroup and groupPowerEventsRegistered then
        EVENT_MANAGER:UnregisterForEvent(PlayerBars.Group.EVENT_NAMESPACE, EVENT_POWER_UPDATE)
        groupPowerEventsRegistered = false
    end
end

local function HasActiveFrame()
    return runtimeActive
        or COMPANION.IsRuntimeActive()
        or PlayerBars.Group.IsRuntimeActive()
end

local function RefreshEventRegistrations()
    if HasActiveFrame() then
        if eventsInstalled then
            RefreshPowerEventRegistrations()
        else
            InstallEvents()
        end
    elseif eventsInstalled then
        UninstallEvents()
    end
end

PlayerBars.RefreshEventRegistrations = RefreshEventRegistrations

InstallEvents = function()
    if eventsInstalled or not EVENT_MANAGER then
        return
    end

    local function QueueGroupDeathStateRefresh()
        if not PlayerBars.Group.IsRuntimeActive() then
            return
        end

        PlayerBars.Group.QueueRefresh()
        if zo_callLater then
            zo_callLater(PlayerBars.Group.QueueRefresh, 100)
        end
    end

    EVENT_MANAGER:RegisterForEvent(C.EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED, QueueRefresh)
    EVENT_MANAGER:RegisterForEvent(COMPANION.EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED, COMPANION.QueueRefresh)
    if EVENT_PLAYER_COMBAT_STATE then
        EVENT_MANAGER:RegisterForEvent(C.EVENT_NAMESPACE .. "_CombatState", EVENT_PLAYER_COMBAT_STATE, function()
            QueueRefresh()
            COMPANION.QueueRefresh()
            PlayerBars.Group.QueueRefresh()
        end)
    end
    EVENT_MANAGER:RegisterForEvent(PlayerBars.Group.EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED, function()
        if not PlayerBars.Group.IsRuntimeActive() then
            return
        end

        PlayerBars.Group.ClearCompanionNameCache()
        PlayerBars.Group.ClearSupportRangeCache()
        PlayerBars.Group.ClearRuntimeRows()
        PlayerBars.Group.QueueRefresh()
    end)
    EVENT_MANAGER:RegisterForEvent(PlayerBars.Group.EVENT_NAMESPACE .. "_PlayerAlive", EVENT_PLAYER_ALIVE, QueueGroupDeathStateRefresh)
    if EVENT_PLAYER_REINCARNATED then
        EVENT_MANAGER:RegisterForEvent(PlayerBars.Group.EVENT_NAMESPACE .. "_PlayerReincarnated", EVENT_PLAYER_REINCARNATED, QueueGroupDeathStateRefresh)
    end
    if EVENT_PLAYER_DEATH_INFO_UPDATE then
        EVENT_MANAGER:RegisterForEvent(PlayerBars.Group.EVENT_NAMESPACE .. "_PlayerDeathInfo", EVENT_PLAYER_DEATH_INFO_UPDATE, QueueGroupDeathStateRefresh)
    end
    if EVENT_GROUP_UPDATE then
        EVENT_MANAGER:RegisterForEvent(PlayerBars.Group.EVENT_NAMESPACE, EVENT_GROUP_UPDATE, PlayerBars.Group.OnGroupMembershipChanged)
    end
    if EVENT_GROUP_TYPE_CHANGED then
        EVENT_MANAGER:RegisterForEvent(PlayerBars.Group.EVENT_NAMESPACE, EVENT_GROUP_TYPE_CHANGED, PlayerBars.Group.OnGroupMembershipChanged)
    end
    if EVENT_GROUP_MEMBER_LEFT then
        EVENT_MANAGER:RegisterForEvent(PlayerBars.Group.EVENT_NAMESPACE, EVENT_GROUP_MEMBER_LEFT, PlayerBars.Group.OnGroupMemberLeft)
    end
    if EVENT_GROUP_MEMBER_ROLE_CHANGED then
        EVENT_MANAGER:RegisterForEvent(PlayerBars.Group.EVENT_NAMESPACE, EVENT_GROUP_MEMBER_ROLE_CHANGED, PlayerBars.Group.QueueRefresh)
        if EVENT_MANAGER.AddFilterForEvent and REGISTER_FILTER_UNIT_TAG_PREFIX then
            EVENT_MANAGER:AddFilterForEvent(PlayerBars.Group.EVENT_NAMESPACE, EVENT_GROUP_MEMBER_ROLE_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
        end
    end
    if EVENT_GROUP_MEMBER_CONNECTED_STATUS then
        EVENT_MANAGER:RegisterForEvent(PlayerBars.Group.EVENT_NAMESPACE, EVENT_GROUP_MEMBER_CONNECTED_STATUS, PlayerBars.Group.QueueRefresh)
        if EVENT_MANAGER.AddFilterForEvent and REGISTER_FILTER_UNIT_TAG_PREFIX then
            EVENT_MANAGER:AddFilterForEvent(PlayerBars.Group.EVENT_NAMESPACE, EVENT_GROUP_MEMBER_CONNECTED_STATUS, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
        end
    end
    if EVENT_TARGET_MARKER_UPDATE then
        EVENT_MANAGER:RegisterForEvent(PlayerBars.Group.EVENT_NAMESPACE, EVENT_TARGET_MARKER_UPDATE, PlayerBars.Group.QueueRefresh)
    end
    if EVENT_GROUP_SUPPORT_RANGE_UPDATE then
        EVENT_MANAGER:RegisterForEvent(PlayerBars.Group.EVENT_NAMESPACE, EVENT_GROUP_SUPPORT_RANGE_UPDATE, PlayerBars.Group.OnSupportRangeUpdate)
        if EVENT_MANAGER.AddFilterForEvent and REGISTER_FILTER_UNIT_TAG_PREFIX then
            EVENT_MANAGER:AddFilterForEvent(PlayerBars.Group.EVENT_NAMESPACE, EVENT_GROUP_SUPPORT_RANGE_UPDATE, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
        end
    end
    if EVENT_UNIT_DEATH_STATE_CHANGED then
        EVENT_MANAGER:RegisterForEvent(PlayerBars.Group.EVENT_NAMESPACE, EVENT_UNIT_DEATH_STATE_CHANGED, PlayerBars.Group.OnDeathStateChanged)
    end
    if EVENT_ACTIVE_COMPANION_STATE_CHANGED then
        EVENT_MANAGER:RegisterForEvent(COMPANION.EVENT_NAMESPACE, EVENT_ACTIVE_COMPANION_STATE_CHANGED, COMPANION.QueueRefresh)
    end
    if EVENT_COMPANION_EXPERIENCE_GAIN then
        EVENT_MANAGER:RegisterForEvent(COMPANION.EVENT_NAMESPACE, EVENT_COMPANION_EXPERIENCE_GAIN, COMPANION.QueueRefresh)
    end
    if EVENT_COMPANION_RAPPORT_UPDATE then
        EVENT_MANAGER:RegisterForEvent(COMPANION.EVENT_NAMESPACE, EVENT_COMPANION_RAPPORT_UPDATE, COMPANION.QueueRefresh)
    end
    if EVENT_UNIT_CREATED then
        EVENT_MANAGER:RegisterForEvent(COMPANION.EVENT_NAMESPACE, EVENT_UNIT_CREATED, function(_, unitTag)
            if COMPANION.IsRuntimeActive() and unitTag == "companion" then
                COMPANION.QueueRefresh()
            end
            if PlayerBars.Group.IsRuntimeActive() and PlayerBars.Group.IsGroupOrGroupCompanionUnitTag(unitTag) then
                PlayerBars.Group.ClearCompanionNameCache()
                PlayerBars.Group.QueueRefresh()
            end
        end)
    end
    if EVENT_UNIT_DESTROYED then
        EVENT_MANAGER:RegisterForEvent(COMPANION.EVENT_NAMESPACE, EVENT_UNIT_DESTROYED, function(_, unitTag)
            if COMPANION.IsRuntimeActive() and unitTag == "companion" then
                COMPANION.QueueRefresh()
            end
            if PlayerBars.Group.IsRuntimeActive() and PlayerBars.Group.IsGroupOrGroupCompanionUnitTag(unitTag) then
                PlayerBars.Group.ClearCompanionNameCache()
                PlayerBars.Group.QueueRefresh()
            end
        end)
    end
    EVENT_MANAGER:RegisterForEvent(C.EVENT_NAMESPACE, EVENT_MOUNTED_STATE_CHANGED, function(_, isMounted)
        mounted = isMounted == true
        QueueRefresh()
    end)
    if EVENT_WEREWOLF_STATE_CHANGED then
        EVENT_MANAGER:RegisterForEvent(C.EVENT_NAMESPACE, EVENT_WEREWOLF_STATE_CHANGED, QueueRefresh)
    end
    if EVENT_BEGIN_SIEGE_CONTROL then
        EVENT_MANAGER:RegisterForEvent(C.EVENT_NAMESPACE, EVENT_BEGIN_SIEGE_CONTROL, QueueRefresh)
    end
    if EVENT_END_SIEGE_CONTROL then
        EVENT_MANAGER:RegisterForEvent(C.EVENT_NAMESPACE, EVENT_END_SIEGE_CONTROL, QueueRefresh)
    end
    if EVENT_LEAVE_RAM_ESCORT then
        EVENT_MANAGER:RegisterForEvent(C.EVENT_NAMESPACE, EVENT_LEAVE_RAM_ESCORT, QueueRefresh)
    end

    if EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED then
        EVENT_MANAGER:RegisterForEvent(C.EVENT_NAMESPACE, EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, OnAttributeVisualAdded)
        EVENT_MANAGER:AddFilterForEvent(C.EVENT_NAMESPACE, EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, REGISTER_FILTER_UNIT_TAG, "player")
        EVENT_MANAGER:RegisterForEvent(PlayerBars.Group.EVENT_NAMESPACE .. "_AttributeVisualAdded", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, PlayerBars.Group.OnAttributeVisualChanged)
        if EVENT_MANAGER.AddFilterForEvent and REGISTER_FILTER_UNIT_TAG_PREFIX then
            EVENT_MANAGER:AddFilterForEvent(PlayerBars.Group.EVENT_NAMESPACE .. "_AttributeVisualAdded", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
        end
    end

    if EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED then
        EVENT_MANAGER:RegisterForEvent(C.EVENT_NAMESPACE, EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, OnAttributeVisualUpdated)
        EVENT_MANAGER:AddFilterForEvent(C.EVENT_NAMESPACE, EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, REGISTER_FILTER_UNIT_TAG, "player")
        EVENT_MANAGER:RegisterForEvent(PlayerBars.Group.EVENT_NAMESPACE .. "_AttributeVisualUpdated", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, PlayerBars.Group.OnAttributeVisualChanged)
        if EVENT_MANAGER.AddFilterForEvent and REGISTER_FILTER_UNIT_TAG_PREFIX then
            EVENT_MANAGER:AddFilterForEvent(PlayerBars.Group.EVENT_NAMESPACE .. "_AttributeVisualUpdated", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
        end
    end

    if EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED then
        EVENT_MANAGER:RegisterForEvent(C.EVENT_NAMESPACE, EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, OnAttributeVisualRemoved)
        EVENT_MANAGER:AddFilterForEvent(C.EVENT_NAMESPACE, EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, REGISTER_FILTER_UNIT_TAG, "player")
        EVENT_MANAGER:RegisterForEvent(PlayerBars.Group.EVENT_NAMESPACE .. "_AttributeVisualRemoved", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, PlayerBars.Group.OnAttributeVisualChanged)
        if EVENT_MANAGER.AddFilterForEvent and REGISTER_FILTER_UNIT_TAG_PREFIX then
            EVENT_MANAGER:AddFilterForEvent(PlayerBars.Group.EVENT_NAMESPACE .. "_AttributeVisualRemoved", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
        end
    end

    if EVENT_SCREEN_RESIZED then
        EVENT_MANAGER:RegisterForEvent(C.EVENT_NAMESPACE, EVENT_SCREEN_RESIZED, QueueRefresh)
        EVENT_MANAGER:RegisterForEvent(COMPANION.EVENT_NAMESPACE, EVENT_SCREEN_RESIZED, COMPANION.QueueRefresh)
        EVENT_MANAGER:RegisterForEvent(PlayerBars.Group.EVENT_NAMESPACE, EVENT_SCREEN_RESIZED, PlayerBars.Group.QueueRefresh)
    end

    eventsInstalled = true
    RefreshPowerEventRegistrations()
    InstallSceneCallback()
end

UninstallEvents = function()
    if not eventsInstalled or not EVENT_MANAGER then
        return
    end

    RefreshPowerEventRegistrations()

    local function Unregister(namespace, eventCode)
        if eventCode then
            EVENT_MANAGER:UnregisterForEvent(namespace, eventCode)
        end
    end

    Unregister(C.EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED)
    Unregister(COMPANION.EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED)
    Unregister(PlayerBars.Group.EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED)
    Unregister(PlayerBars.Group.EVENT_NAMESPACE .. "_PlayerAlive", EVENT_PLAYER_ALIVE)
    Unregister(C.EVENT_NAMESPACE .. "_CombatState", EVENT_PLAYER_COMBAT_STATE)
    Unregister(PlayerBars.Group.EVENT_NAMESPACE .. "_PlayerReincarnated", EVENT_PLAYER_REINCARNATED)
    Unregister(PlayerBars.Group.EVENT_NAMESPACE .. "_PlayerDeathInfo", EVENT_PLAYER_DEATH_INFO_UPDATE)
    Unregister(PlayerBars.Group.EVENT_NAMESPACE, EVENT_GROUP_UPDATE)
    Unregister(PlayerBars.Group.EVENT_NAMESPACE, EVENT_GROUP_TYPE_CHANGED)
    Unregister(PlayerBars.Group.EVENT_NAMESPACE, EVENT_GROUP_MEMBER_LEFT)
    Unregister(PlayerBars.Group.EVENT_NAMESPACE, EVENT_GROUP_MEMBER_ROLE_CHANGED)
    Unregister(PlayerBars.Group.EVENT_NAMESPACE, EVENT_GROUP_MEMBER_CONNECTED_STATUS)
    Unregister(PlayerBars.Group.EVENT_NAMESPACE, EVENT_TARGET_MARKER_UPDATE)
    Unregister(PlayerBars.Group.EVENT_NAMESPACE, EVENT_GROUP_SUPPORT_RANGE_UPDATE)
    Unregister(PlayerBars.Group.EVENT_NAMESPACE, EVENT_UNIT_DEATH_STATE_CHANGED)
    Unregister(COMPANION.EVENT_NAMESPACE, EVENT_ACTIVE_COMPANION_STATE_CHANGED)
    Unregister(COMPANION.EVENT_NAMESPACE, EVENT_COMPANION_EXPERIENCE_GAIN)
    Unregister(COMPANION.EVENT_NAMESPACE, EVENT_COMPANION_RAPPORT_UPDATE)
    Unregister(COMPANION.EVENT_NAMESPACE, EVENT_UNIT_CREATED)
    Unregister(COMPANION.EVENT_NAMESPACE, EVENT_UNIT_DESTROYED)
    Unregister(C.EVENT_NAMESPACE, EVENT_MOUNTED_STATE_CHANGED)
    Unregister(C.EVENT_NAMESPACE, EVENT_WEREWOLF_STATE_CHANGED)
    Unregister(C.EVENT_NAMESPACE, EVENT_BEGIN_SIEGE_CONTROL)
    Unregister(C.EVENT_NAMESPACE, EVENT_END_SIEGE_CONTROL)
    Unregister(C.EVENT_NAMESPACE, EVENT_LEAVE_RAM_ESCORT)
    Unregister(C.EVENT_NAMESPACE, EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED)
    Unregister(C.EVENT_NAMESPACE, EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED)
    Unregister(C.EVENT_NAMESPACE, EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED)
    Unregister(PlayerBars.Group.EVENT_NAMESPACE .. "_AttributeVisualAdded", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED)
    Unregister(PlayerBars.Group.EVENT_NAMESPACE .. "_AttributeVisualUpdated", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED)
    Unregister(PlayerBars.Group.EVENT_NAMESPACE .. "_AttributeVisualRemoved", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED)
    Unregister(C.EVENT_NAMESPACE, EVENT_SCREEN_RESIZED)
    Unregister(COMPANION.EVENT_NAMESPACE, EVENT_SCREEN_RESIZED)
    Unregister(PlayerBars.Group.EVENT_NAMESPACE, EVENT_SCREEN_RESIZED)

    eventsInstalled = false
    UninstallSceneCallback()
end

function PlayerBars.InitializeSavedVariables()
    Shared.InitializeSavedVariables()
end

function PlayerBars.Initialize()
    if initialized then
        return
    end

    initialized = true
    mounted = IsMounted()
    PlayerBars.Group.lastGroupSize = GetGroupSize and (tonumber(GetGroupSize()) or 0) or 0
    PlayerBar.RefreshRuntimeState()
    COMPANION.RefreshRuntimeState()
    PlayerBars.Group.RefreshRuntimeState()
    RefreshEventRegistrations()
    if runtimeActive then
        QueueRefresh()
    end
    if COMPANION.IsRuntimeActive() then
        COMPANION.QueueRefresh()
    end
    if PlayerBars.Group.IsRuntimeActive() then
        PlayerBars.Group.QueueRefresh()
    end
end
NQOL.Features.PlayerBars = PlayerBars
