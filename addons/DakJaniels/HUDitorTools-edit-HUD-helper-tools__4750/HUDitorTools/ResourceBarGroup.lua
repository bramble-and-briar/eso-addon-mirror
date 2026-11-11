-- -----------------------------------------------------------------------------
-- HUDitorTools - stack player resource bars at a fixed width
-- PlayerAttributeBars.lua: NORMAL_WIDTH 237, EXPANDED_WIDTH 323, SHRUNK_WIDTH 141.
-- Pyramid matches LuiExtended UnitFrames.RepositionDefaultFrames: magicka
-- TOPRIGHT and stamina TOPLEFT on health BOTTOM. Health stays CENTER.
-- ShrinkExpand stays registered. Don't expand keeps increased max power at
-- normalWidth. Shield, armor, regen, unwavering, and possession stay registered.
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
local shrinkExpandOnValueChangedHooked = false
local shrinkExpandModule = nil

local function ClampHealthWidth(healthWidth)
    return HT.ClampInteger(healthWidth, MIN_HEALTH_WIDTH, MAX_HEALTH_WIDTH, HT.RESOURCE_BAR_GROUP_DEFAULT_WIDTH)
end

function HT.CopyResourceBarGroup(sourceGroup)
    local healthWidth = HT.RESOURCE_BAR_GROUP_DEFAULT_WIDTH
    local enabled = false
    local preventExpand = false
    local hideHealthGlow = false
    if type(sourceGroup) == "table" then
        enabled = sourceGroup.enabled == true
        healthWidth = ClampHealthWidth(sourceGroup.healthWidth)
        preventExpand = sourceGroup.preventExpand == true
        hideHealthGlow = sourceGroup.hideHealthGlow == true
    end
    return
    {
        enabled = enabled,
        healthWidth = healthWidth,
        preventExpand = preventExpand,
        hideHealthGlow = hideHealthGlow,
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
    settings.hideHealthGlow = settings.hideHealthGlow == true
    return settings
end

function HT.IsResourceBarGroupEnabled()
    local settings = HT.SV.resourceBarGroup
    return type(settings) == "table" and settings.enabled == true
end

function HT.IsHealthBuffGlowHidden()
    local settings = HT.SV.resourceBarGroup
    return type(settings) == "table" and settings.hideHealthGlow == true
end

local playerHealthBuffGlowHookInstalled = false

local function GetPlayerArmorDamageModule()
    local visualModules = PLAYER_ATTRIBUTE_BARS.attributeVisualizer.visualModules
    for visualModule in pairs(visualModules) do
        if visualModule:IsInstanceOf(ZO_UnitVisualizer_ArmorDamage) then
            return visualModule
        end
    end
    return nil
end

local function SetPlayerHealthBuffGlowControlsHidden(hidden)
    local armorModule = GetPlayerArmorDamageModule()
    if not armorModule then
        return
    end
    local healthBar = ZO_PlayerAttributeHealth
    local activeObjects = armorModule:GetOrCreateIncreasePowerPool():GetActiveObjects()
    for _, container in pairs(activeObjects) do
        local fadeAnimation = container.fadeAnimation
        local glowOnHealthBar = fadeAnimation and fadeAnimation.bar == healthBar
        if not glowOnHealthBar and container.increasedPowerGlow then
            glowOnHealthBar = container.increasedPowerGlow:GetParent() == healthBar
        end
        if glowOnHealthBar then
            if container.increasedPowerGlow then
                container.increasedPowerGlow:SetHidden(hidden)
            end
            if container.increasedPowerTexture then
                container.increasedPowerTexture:SetHidden(hidden)
            end
        end
    end
end

local function PlayPowerIncreaseWithoutHealthBuffGlow(originalPlay, self, bar, info, instant)
    local animation = originalPlay(self, bar, info, instant)
    if HT.IsHealthBuffGlowHidden() and bar == ZO_PlayerAttributeHealth then
        SetPlayerHealthBuffGlowControlsHidden(true)
    end
    return animation
end

local function ApplyPlayerHealthBuffGlow()
    local armorModule = GetPlayerArmorDamageModule()
    if not armorModule then
        return
    end
    if not playerHealthBuffGlowHookInstalled then
        playerHealthBuffGlowHookInstalled = true
        -- InitializeBarValues stores self.PlayPowerIncreaseAnimation on barInfo
        -- (ArmorDamage.lua 227) before this addon loads, so the instance method
        -- is not what OnValueChanged calls.
        local originalPlayPowerIncreaseAnimation = armorModule.PlayPowerIncreaseAnimation
        local wrappedPlay = function (self, bar, info, instant)
            return PlayPowerIncreaseWithoutHealthBuffGlow(originalPlayPowerIncreaseAnimation, self, bar, info, instant)
        end
        armorModule.PlayPowerIncreaseAnimation = wrappedPlay
        local powerInfo = armorModule.barInfo and armorModule.barInfo[STAT_POWER]
        if powerInfo then
            powerInfo.playIncreaseAnimation = wrappedPlay
        end
    end
    -- ArmorDamage.lua 446-449 parents increasedPowerGlow
    -- (ArmorDamage.xml ZO_IncreasedPowerGlowArrow) and the animated halo
    -- (increasedPower_animatedHalo_32fr.dds) onto the health bar.
    SetPlayerHealthBuffGlowControlsHidden(HT.IsHealthBuffGlowHidden())
end

function HT.SetHealthBuffGlowHidden(hideHealthGlow)
    local settings = GetResourceBarGroupSettings()
    settings.hideHealthGlow = hideHealthGlow == true
    ApplyPlayerHealthBuffGlow()
    HT.RefreshLayoutInfoBoxSection()
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
    return HT.GetHudElementForControl(ZO_PlayerAttribute)
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

-- Instance method only. Target frames use ZO_UnitVisualizer_ShrinkExpandModule too.
-- While the original runs, the instance field points at the original so any
-- self:OnValueChanged() call inside it cannot re-enter this wrapper.
local function HookPlayerShrinkExpandOnValueChanged(shrinkModule)
    if shrinkExpandOnValueChangedHooked then
        return
    end
    shrinkExpandOnValueChangedHooked = true
    local originalOnValueChanged = ZO_UnitVisualizer_ShrinkExpandModule.OnValueChanged
    local hookedOnValueChanged
    hookedOnValueChanged = function (self, bar, info, stat, instant)
        if HT.IsResourceBarPreventExpand() and info.value > 0 then
            -- Stop a width animation that is already playing, or it writes the expanded width when it ends.
            if info.animation then
                info.animation:Stop()
            end
            info.state = ATTRIBUTE_BAR_STATE_NORMAL
            SetBarWidth(bar, self.normalWidth)
            return
        end
        self.OnValueChanged = originalOnValueChanged
        originalOnValueChanged(self, bar, info, stat, instant)
        self.OnValueChanged = hookedOnValueChanged
    end
    shrinkModule.OnValueChanged = hookedOnValueChanged
end

local function ApplyResourceBarExpandSetting()
    local shrinkModule = GetShrinkExpandModule()
    if not shrinkModule then
        return
    end
    HookPlayerShrinkExpandOnValueChanged(shrinkModule)
    shrinkModule.normalWidth = STOCK_BAR_WIDTH
    shrinkModule.expandedWidth = STOCK_EXPANDED_WIDTH
    shrinkModule.shrunkWidth = STOCK_SHRUNK_WIDTH
    -- OnAdded calls InitializeBarValues only when IsPlayerActivated() is already true.
    if not shrinkModule.barInfo then
        return
    end
    for stat, bar in pairs(shrinkModule.barControls) do
        local info = shrinkModule.barInfo[stat]
        if info then
            shrinkModule:OnValueChanged(bar, info, stat, ANIMATION_INSTANT)
        end
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
    ApplyResourceBarExpandSetting()
    ApplyPlayerHealthBuffGlow()
end

function HT.SetResourceBarPreventExpand(preventExpand)
    local settings = GetResourceBarGroupSettings()
    settings.preventExpand = preventExpand == true
    ApplyResourceBarExpandSetting()
    HT.RefreshLayoutInfoBoxSection()
end

function HT.SetResourceBarGroupEnabled(enabled)
    local settings = GetResourceBarGroupSettings()
    settings.enabled = enabled == true
    if settings.enabled then
        SetResourceBarsCombined()
    end
    HT.ApplyResourceBarGroup()
    HT.RebuildHudEditorIfShowing()
    HT.RefreshLayoutInfoBoxSection()
end

function HT.SetResourceBarGroupHealthWidth(healthWidth)
    local settings = GetResourceBarGroupSettings()
    settings.healthWidth = ClampHealthWidth(healthWidth)
    if settings.enabled then
        HT.ApplyResourceBarGroup()
        HT.RebuildHudEditorIfShowing()
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

function HT.InitializeResourceBarGroup()
    GetResourceBarGroupSettings()
    if not resourceBarHooksInstalled then
        resourceBarHooksInstalled = true
        HookPlayerAttributeBarsMethod("ApplyStyle")
        HookPlayerAttributeBarsMethod("OnScreenResized")
    end
    HT.ApplyResourceBarGroup()
end
