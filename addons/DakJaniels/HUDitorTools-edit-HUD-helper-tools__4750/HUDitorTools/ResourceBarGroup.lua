-- -----------------------------------------------------------------------------
-- HUDitorTools - stack player resource bars at a fixed width
-- PlayerAttributeBars.lua: NORMAL_WIDTH 237, EXPANDED_WIDTH 323, SHRUNK_WIDTH 141.
-- Pyramid matches LuiExtended UnitFrames.RepositionDefaultFrames: magicka
-- TOPRIGHT and stamina TOPLEFT on health BOTTOM. Health stays CENTER.
-- ShrinkExpand OnValueChanged(..., ANIMATION_INSTANT) keeps every width at 237.
-- PlayerAttributeBars.lua AddModule list, unregistered by class .. GetModuleId().
-- -----------------------------------------------------------------------------
local HT = HUDitorTools

local STOCK_BAR_WIDTH = 237
local STOCK_EXPANDED_WIDTH = 323
local STOCK_SHRUNK_WIDTH = 141
local STOCK_SMALL_BAR_WIDTH = 228
local MIN_HEALTH_WIDTH = 200
local MAX_HEALTH_WIDTH = 1200

HT.RESOURCE_BAR_GROUP_DEFAULT_WIDTH = STOCK_BAR_WIDTH * 2

local groupedLayoutIsApplied = false
local resourceBarHooksInstalled = false
local shrinkExpandModule = nil

-- Event namespace is the string passed to RegisterForEvent in each module's OnAdded.
local VISUAL_MODULE_EVENT_PREFIX =
{
    [ZO_UnitVisualizer_ArrowRegenerationModule] = "ZO_UnitVisualizer_ArrowRegenerationModule",
    [ZO_UnitVisualizer_ShrinkExpandModule] = "ZO_UnitVisualizer_ShrinkExpandModule",
    [ZO_UnitVisualizer_ArmorDamage] = "ZO_UnitVisualizer_ArmorDamage",
    [ZO_UnitVisualizer_UnwaveringModule] = "ZO_UnitVisualizer_UnwaveringModule",
    [ZO_UnitVisualizer_PossessionModule] = "ZO_UnitVisualizer_PossessionModule",
    [ZO_UnitVisualizer_PowerShieldModule] = "ZO_UnitVisualizer_PowerShieldModule",
}

local function ClampHealthWidth(healthWidth)
    healthWidth = zo_floor(tonumber(healthWidth) or HT.RESOURCE_BAR_GROUP_DEFAULT_WIDTH)
    if healthWidth < MIN_HEALTH_WIDTH then
        return MIN_HEALTH_WIDTH
    end
    if healthWidth > MAX_HEALTH_WIDTH then
        return MAX_HEALTH_WIDTH
    end
    return healthWidth
end

function HT.CopyResourceBarGroup(sourceGroup)
    local healthWidth = HT.RESOURCE_BAR_GROUP_DEFAULT_WIDTH
    local enabled = false
    local preventExpand = false
    if type(sourceGroup) == "table" then
        enabled = sourceGroup.enabled == true
        healthWidth = ClampHealthWidth(sourceGroup.healthWidth)
        preventExpand = sourceGroup.preventExpand == true
    end
    return
    {
        enabled = enabled,
        healthWidth = healthWidth,
        preventExpand = preventExpand,
    }
end

local function GetResourceBarGroupSettings()
    local settings = HT.SV.resourceBarGroup
    if type(settings) ~= "table" then
        settings = HT.CopyResourceBarGroup(nil)
        HT.SV.resourceBarGroup = settings
    end
    settings.healthWidth = ClampHealthWidth(settings.healthWidth)
    settings.enabled = settings.enabled == true
    settings.preventExpand = settings.preventExpand == true
    return settings
end

function HT.IsResourceBarGroupEnabled()
    local settings = HT.SV.resourceBarGroup
    return type(settings) == "table" and settings.enabled == true
end

function HT.IsResourceBarPreventExpand()
    local settings = HT.SV.resourceBarGroup
    return type(settings) == "table" and settings.preventExpand == true
end

function HT.GetResourceBarGroupedHealthWidth()
    return GetResourceBarGroupSettings().healthWidth
end

function HT.GetResourceBarGroupedWidth(stat)
    local healthWidth = HT.GetResourceBarGroupedHealthWidth()
    if stat == STAT_HEALTH_MAX then
        return healthWidth
    end
    if stat == STAT_MAGICKA_MAX or stat == STAT_STAMINA_MAX then
        return zo_floor((healthWidth - 2) / 2)
    end
    return nil
end

function HT.IsPlayerAttributeFrameSaveKey(saveKey)
    return saveKey == "ZO_PlayerAttribute"
end

function HT.IsPlayerResourceBarSaveKey(saveKey)
    return saveKey == "ZO_PlayerAttribute"
        or saveKey == "ZO_PlayerAttributeHealth"
        or saveKey == "ZO_PlayerAttributeMagicka"
        or saveKey == "ZO_PlayerAttributeStamina"
end

local function GetShrinkExpandModule()
    if shrinkExpandModule then
        return shrinkExpandModule
    end
    local visualModules = PLAYER_ATTRIBUTE_BARS.attributeVisualizer.visualModules
    for visualModule in pairs(visualModules) do
        if visualModule:IsInstanceOf(ZO_UnitVisualizer_ShrinkExpandModule) then
            shrinkExpandModule = visualModule
            return visualModule
        end
    end
    return nil
end

local function SetBarWidth(bar, width)
    bar:SetWidth(width)
    bar.bgContainer:SetWidth(width)
end

local function GetPlayerAttributeFrameElement()
    if IsInGamepadPreferredMode() then
        return HUD_MANAGER:GetGamepadElementForControl(ZO_PlayerAttribute)
    end
    return HUD_MANAGER:GetKeyboardElementForControl(ZO_PlayerAttribute)
end

local function IsPlayerAttributeFrameCombined()
    return GetPlayerAttributeFrameElement():GetCustomOptionValue("Combine") == true
end

local function SetResourceBarsCombined()
    local frameElement = GetPlayerAttributeFrameElement()
    if frameElement:GetCustomOptionValue("Combine") then
        return
    end
    frameElement:SetCustomOptionValue("Combine", nil, true)
end

local function ApplyStackedResourceBarLayout()
    local health = ZO_PlayerAttributeHealth
    health:ClearAnchors()
    health:SetAnchor(CENTER, ZO_PlayerAttribute, CENTER, 0, 0)

    -- LuiExtended UnitFrames.RepositionDefaultFrames
    ZO_PlayerAttributeMagicka:ClearAnchors()
    ZO_PlayerAttributeMagicka:SetAnchor(TOPRIGHT, health, BOTTOM, -1, 2)

    ZO_PlayerAttributeStamina:ClearAnchors()
    ZO_PlayerAttributeStamina:SetAnchor(TOPLEFT, health, BOTTOM, 1, 2)

    ZO_PlayerAttributeSiegeHealth:ClearAnchors()
    ZO_PlayerAttributeSiegeHealth:SetAnchor(CENTER, health, CENTER, 300, 0)
end

local function RestoreStockResourceBarLayout()
    local health = ZO_PlayerAttributeHealth
    ZO_PlayerAttributeMagicka:ClearAnchors()
    ZO_PlayerAttributeMagicka:SetAnchor(RIGHT, ZO_PlayerAttribute, LEFT, STOCK_BAR_WIDTH, 0)
    health:ClearAnchors()
    health:SetAnchor(CENTER, ZO_PlayerAttribute, CENTER, 0, 0)
    ZO_PlayerAttributeStamina:ClearAnchors()
    ZO_PlayerAttributeStamina:SetAnchor(LEFT, ZO_PlayerAttribute, RIGHT, -STOCK_BAR_WIDTH, 0)

    ZO_PlayerAttributeSiegeHealth:ClearAnchors()
    ZO_PlayerAttributeSiegeHealth:SetAnchor(TOP, health, BOTTOM, 0, -1)
    ZO_PlayerAttributeSiegeHealth:SetWidth(STOCK_SMALL_BAR_WIDTH)
    ZO_PlayerAttributeWerewolf:SetWidth(STOCK_SMALL_BAR_WIDTH)
    ZO_PlayerAttributeMountStamina:SetWidth(STOCK_SMALL_BAR_WIDTH)

    local shrinkModule = GetShrinkExpandModule()
    if shrinkModule.barInfo then
        for stat, info in pairs(shrinkModule.barInfo) do
            local width = STOCK_BAR_WIDTH
            if info.state == ATTRIBUTE_BAR_STATE_EXPANDED then
                width = STOCK_EXPANDED_WIDTH
            elseif info.state == ATTRIBUTE_BAR_STATE_SHRUNK then
                width = STOCK_SHRUNK_WIDTH
            end
            SetBarWidth(shrinkModule.barControls[stat], width)
        end
    else
        SetBarWidth(health, STOCK_BAR_WIDTH)
        SetBarWidth(ZO_PlayerAttributeMagicka, STOCK_BAR_WIDTH)
        SetBarWidth(ZO_PlayerAttributeStamina, STOCK_BAR_WIDTH)
    end

    PLAYER_ATTRIBUTE_BARS:ResizeToFitScreen()
end

local function ApplyPreventResourceBarExpand()
    local shrinkModule = GetShrinkExpandModule()
    shrinkModule.normalWidth = STOCK_BAR_WIDTH
    shrinkModule.expandedWidth = STOCK_BAR_WIDTH
    shrinkModule.shrunkWidth = STOCK_BAR_WIDTH
    -- OnAdded calls InitializeBarValues only when IsPlayerActivated() is already true.
    if not shrinkModule.barInfo then
        return
    end
    for stat, bar in pairs(shrinkModule.barControls) do
        local info = shrinkModule.barInfo[stat]
        -- TryChangingState returns a width only when info.state does not already match.
        if info.value == 0 then
            info.state = ATTRIBUTE_BAR_STATE_EXPANDED
        else
            info.state = ATTRIBUTE_BAR_STATE_NORMAL
        end
        shrinkModule:OnValueChanged(bar, info, stat, ANIMATION_INSTANT)
    end
end

function HT.ApplyResourceBarGroup()
    GetResourceBarGroupSettings()
    if HT.IsResourceBarGroupEnabled() and not IsPlayerAttributeFrameCombined() then
        GetResourceBarGroupSettings().enabled = false
    end
    if HT.IsResourceBarGroupEnabled() then
        ApplyStackedResourceBarLayout()
        groupedLayoutIsApplied = true
    elseif groupedLayoutIsApplied then
        RestoreStockResourceBarLayout()
        groupedLayoutIsApplied = false
    end
    ApplyPreventResourceBarExpand()
end

function HT.SetResourceBarPreventExpand(preventExpand)
    local settings = GetResourceBarGroupSettings()
    settings.preventExpand = preventExpand == true
    ApplyPreventResourceBarExpand()
    HT.RefreshLayoutInfoBoxSection()
end

function HT.SetResourceBarGroupEnabled(enabled)
    local settings = GetResourceBarGroupSettings()
    settings.enabled = enabled == true
    if settings.enabled then
        SetResourceBarsCombined()
    end
    HT.ApplyResourceBarGroup()
    if HUD_EDITOR_KEYBOARD:IsShowing() then
        HUD_EDITOR_KEYBOARD:RebuildAllElements()
    end
    HT.RefreshLayoutInfoBoxSection()
end

function HT.SetResourceBarGroupHealthWidth(healthWidth)
    local settings = GetResourceBarGroupSettings()
    settings.healthWidth = ClampHealthWidth(healthWidth)
    if settings.enabled then
        HT.ApplyResourceBarGroup()
        if HUD_EDITOR_KEYBOARD:IsShowing() then
            HUD_EDITOR_KEYBOARD:RebuildAllElements()
        end
    end
    HT.RefreshLayoutInfoBoxSection()
    return settings.healthWidth
end

-- While the original runs, the instance field points at the original so any
-- self:methodName() call inside it cannot re-enter this wrapper.
local function HookPlayerAttributeBarsMethod(methodName)
    local originalMethod = PLAYER_ATTRIBUTE_BARS[methodName]
    local hookedMethod
    hookedMethod = function (self, ...)
        self[methodName] = originalMethod
        originalMethod(self, ...)
        self[methodName] = hookedMethod
        if HT.IsResourceBarGroupEnabled() then
            ApplyStackedResourceBarLayout()
            groupedLayoutIsApplied = true
        end
        if methodName == "ApplyStyle" then
            HT.ApplyAllElementAppearances()
        end
    end
    PLAYER_ATTRIBUTE_BARS[methodName] = hookedMethod
end

local function GetPlayerAttributeVisualEventName(visualModule)
    for visualClass, eventPrefix in pairs(VISUAL_MODULE_EVENT_PREFIX) do
        if visualModule:IsInstanceOf(visualClass) then
            return eventPrefix .. visualModule:GetModuleId()
        end
    end
    return nil
end

local function HideNamedControl(info, controlFieldName)
    local control = info[controlFieldName]
    if control then
        control:SetHidden(true)
    end
end

local function ReleasePlayerAttributeVisualModule(visualModule)
    if visualModule:IsInstanceOf(ZO_UnitVisualizer_ArrowRegenerationModule) then
        visualModule.arrowPool:ReleaseAllObjects()
        return
    end
    if visualModule:IsInstanceOf(ZO_UnitVisualizer_ArmorDamage) then
        visualModule:GetOrCreateIncreaseArmorPool():ReleaseAllObjects()
        visualModule:GetOrCreateDecreaseArmorPool():ReleaseAllObjects()
        visualModule:GetOrCreateIncreasePowerPool():ReleaseAllObjects()
        return
    end
    -- ShowOverlay and PlayAnimation create these controls the first time the effect runs.
    if visualModule:IsInstanceOf(ZO_UnitVisualizer_PowerShieldModule) and visualModule.attributeInfo then
        for _, info in pairs(visualModule.attributeInfo) do
            if info.overlayControls then
                for _, overlay in ipairs(info.overlayControls) do
                    overlay:SetHidden(true)
                end
            end
        end
        return
    end
    if visualModule:IsInstanceOf(ZO_UnitVisualizer_UnwaveringModule) and visualModule.barInfo then
        for _, info in pairs(visualModule.barInfo) do
            HideNamedControl(info, "control")
        end
        return
    end
    if visualModule:IsInstanceOf(ZO_UnitVisualizer_PossessionModule) and visualModule.barInfo then
        for _, info in pairs(visualModule.barInfo) do
            HideNamedControl(info, "barOverlayControl")
        end
    end
end

local function SilencePlayerAttributeVisualizer()
    local visualModules = PLAYER_ATTRIBUTE_BARS.attributeVisualizer.visualModules
    for visualModule in pairs(visualModules) do
        local eventName = GetPlayerAttributeVisualEventName(visualModule)
        EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_PLAYER_ACTIVATED)
        EVENT_MANAGER:UnregisterForUpdate(eventName)
        ReleasePlayerAttributeVisualModule(visualModule)
        visualModules[visualModule] = nil
    end
end

function HT.InitializeResourceBarGroup()
    GetResourceBarGroupSettings()
    if not resourceBarHooksInstalled then
        resourceBarHooksInstalled = true
        HookPlayerAttributeBarsMethod("ApplyStyle")
        HookPlayerAttributeBarsMethod("OnScreenResized")
    end
    HT.ApplyResourceBarGroup()
    SilencePlayerAttributeVisualizer()
end
