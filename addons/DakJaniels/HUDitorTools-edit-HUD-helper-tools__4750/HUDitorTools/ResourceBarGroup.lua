-- -----------------------------------------------------------------------------
-- HUDitorTools - stack player resource bars at a fixed width
-- Observed: PlayerAttributeBars.lua NORMAL_WIDTH 237, EXPANDED_WIDTH 323,
-- SHRUNK_WIDTH 141, ResizeToFitScreen, FRAME_OPTIONS key "Combine".
-- Pyramid matches LuiExtended UnitFrames.RepositionDefaultFrames
-- (_DefaultFrames.lua): magicka TOPRIGHT and stamina TOPLEFT on health BOTTOM.
-- Health stays CENTER of ZO_PlayerAttribute so HUD_MANAGER keeps the offset.
-- Bar widths stay the stock values. Siege uses the same CENTER offset as LuiExtended.
-- preventExpand sets ShrinkExpand expandedWidth to NORMAL_WIDTH 237.
-- Observed: ShrinkExpand.lua TryChangingState / OnValueChanged(bar, info, stat, instant).
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
    return {
        enabled = enabled,
        healthWidth = healthWidth,
        preventExpand = preventExpand,
    }
end

local function GetResourceBarGroupSettings()
    local settings = HT.SV and HT.SV.resourceBarGroup
    if type(settings) ~= "table" then
        settings = HT.CopyResourceBarGroup(nil)
        if HT.SV then
            HT.SV.resourceBarGroup = settings
        end
    end
    settings.healthWidth = ClampHealthWidth(settings.healthWidth)
    settings.enabled = settings.enabled == true
    settings.preventExpand = settings.preventExpand == true
    return settings
end

function HT.IsResourceBarGroupEnabled()
    local settings = HT.SV and HT.SV.resourceBarGroup
    return type(settings) == "table" and settings.enabled == true
end

function HT.IsResourceBarPreventExpand()
    local settings = HT.SV and HT.SV.resourceBarGroup
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
    local attributeBars = PLAYER_ATTRIBUTE_BARS
    if not attributeBars or not attributeBars.attributeVisualizer then
        return nil
    end
    local visualModules = attributeBars.attributeVisualizer.visualModules
    if not visualModules then
        return nil
    end
    for visualModule in pairs(visualModules) do
        if visualModule.normalWidth and visualModule.expandedWidth and visualModule.barControls then
            return visualModule
        end
    end
    return nil
end

local function SetBarWidth(bar, width)
    if not bar or not width then
        return
    end
    bar:SetWidth(width)
    if bar.bgContainer and bar.bgContainer.SetWidth then
        bar.bgContainer:SetWidth(width)
    end
end

local function GetPlayerAttributeFrameElement()
    if not ZO_PlayerAttribute or not HUD_MANAGER then
        return nil
    end
    if IsInGamepadPreferredMode() then
        return HUD_MANAGER:GetGamepadElementForControl(ZO_PlayerAttribute)
    end
    return HUD_MANAGER:GetKeyboardElementForControl(ZO_PlayerAttribute)
end

local function IsPlayerAttributeFrameCombined()
    local frameElement = GetPlayerAttributeFrameElement()
    if not frameElement or not frameElement.GetCustomOptionValue then
        return false
    end
    return frameElement:GetCustomOptionValue("Combine") == true
end

local function SetResourceBarsCombined()
    local frameElement = GetPlayerAttributeFrameElement()
    if not frameElement or not frameElement.GetCustomOptionValue then
        return
    end
    if frameElement:GetCustomOptionValue("Combine") then
        return
    end
    frameElement:SetCustomOptionValue("Combine", nil, true)
end

local function ApplyStackedResourceBarLayout()
    local parent = ZO_PlayerAttribute
    local health = ZO_PlayerAttributeHealth
    local magicka = ZO_PlayerAttributeMagicka
    local stamina = ZO_PlayerAttributeStamina
    if not parent or not health or not magicka or not stamina then
        return
    end

    health:ClearAnchors()
    health:SetAnchor(CENTER, parent, CENTER, 0, 0)

    -- LuiExtended UnitFrames.RepositionDefaultFrames
    magicka:ClearAnchors()
    magicka:SetAnchor(TOPRIGHT, health, BOTTOM, -1, 2)

    stamina:ClearAnchors()
    stamina:SetAnchor(TOPLEFT, health, BOTTOM, 1, 2)

    local siege = ZO_PlayerAttributeSiegeHealth
    if siege then
        siege:ClearAnchors()
        siege:SetAnchor(CENTER, health, CENTER, 300, 0)
    end
end

local function RestoreStockResourceBarLayout()
    local parent = ZO_PlayerAttribute
    local health = ZO_PlayerAttributeHealth
    local magicka = ZO_PlayerAttributeMagicka
    local stamina = ZO_PlayerAttributeStamina
    if not parent or not health or not magicka or not stamina then
        return
    end

    magicka:ClearAnchors()
    magicka:SetAnchor(RIGHT, parent, LEFT, STOCK_BAR_WIDTH, 0)
    health:ClearAnchors()
    health:SetAnchor(CENTER, parent, CENTER, 0, 0)
    stamina:ClearAnchors()
    stamina:SetAnchor(LEFT, parent, RIGHT, -STOCK_BAR_WIDTH, 0)

    local siege = ZO_PlayerAttributeSiegeHealth
    if siege then
        siege:ClearAnchors()
        siege:SetAnchor(TOP, health, BOTTOM, 0, -1)
        siege:SetWidth(STOCK_SMALL_BAR_WIDTH)
    end
    if ZO_PlayerAttributeWerewolf then
        ZO_PlayerAttributeWerewolf:SetWidth(STOCK_SMALL_BAR_WIDTH)
    end
    if ZO_PlayerAttributeMountStamina then
        ZO_PlayerAttributeMountStamina:SetWidth(STOCK_SMALL_BAR_WIDTH)
    end

    local shrinkModule = GetShrinkExpandModule()
    if shrinkModule and shrinkModule.barInfo and shrinkModule.barControls then
        for stat, info in pairs(shrinkModule.barInfo) do
            local bar = shrinkModule.barControls[stat]
            local width = STOCK_BAR_WIDTH
            if info.state == ATTRIBUTE_BAR_STATE_EXPANDED then
                width = STOCK_EXPANDED_WIDTH
            elseif info.state == ATTRIBUTE_BAR_STATE_SHRUNK then
                width = STOCK_SHRUNK_WIDTH
            end
            SetBarWidth(bar, width)
        end
    else
        SetBarWidth(health, STOCK_BAR_WIDTH)
        SetBarWidth(magicka, STOCK_BAR_WIDTH)
        SetBarWidth(stamina, STOCK_BAR_WIDTH)
    end

    if PLAYER_ATTRIBUTE_BARS and PLAYER_ATTRIBUTE_BARS.ResizeToFitScreen then
        PLAYER_ATTRIBUTE_BARS:ResizeToFitScreen()
    end
end

local function ApplyPreventResourceBarExpand()
    local shrinkModule = GetShrinkExpandModule()
    if not shrinkModule or not shrinkModule.barControls or not shrinkModule.barInfo or not shrinkModule.OnValueChanged then
        return
    end
    local targetExpandedWidth = STOCK_EXPANDED_WIDTH
    if HT.IsResourceBarPreventExpand() then
        targetExpandedWidth = STOCK_BAR_WIDTH
    end
    shrinkModule.expandedWidth = targetExpandedWidth
    for stat, bar in pairs(shrinkModule.barControls) do
        local info = shrinkModule.barInfo[stat]
        if bar and info and info.animation and info.state == ATTRIBUTE_BAR_STATE_EXPANDED and bar.GetWidth and zo_abs(bar:GetWidth() - targetExpandedWidth) > 0.5 then
            info.state = ATTRIBUTE_BAR_STATE_NORMAL
            shrinkModule:OnValueChanged(bar, info, stat, true)
        end
    end
end

function HT.ApplyResourceBarGroup()
    if not HT.SV then
        return
    end
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
    if HT.RefreshLayoutInfoBoxSection then
        HT.RefreshLayoutInfoBoxSection()
    end
end

function HT.SetResourceBarGroupEnabled(enabled)
    local settings = GetResourceBarGroupSettings()
    settings.enabled = enabled == true
    if settings.enabled then
        SetResourceBarsCombined()
    end
    HT.ApplyResourceBarGroup()
    if HUD_EDITOR_KEYBOARD and HUD_EDITOR_KEYBOARD:IsShowing() then
        HUD_EDITOR_KEYBOARD:RebuildAllElements()
    end
    if HT.RefreshLayoutInfoBoxSection then
        HT.RefreshLayoutInfoBoxSection()
    end
end

function HT.SetResourceBarGroupHealthWidth(healthWidth)
    local settings = GetResourceBarGroupSettings()
    settings.healthWidth = ClampHealthWidth(healthWidth)
    if settings.enabled then
        HT.ApplyResourceBarGroup()
        if HUD_EDITOR_KEYBOARD and HUD_EDITOR_KEYBOARD:IsShowing() then
            HUD_EDITOR_KEYBOARD:RebuildAllElements()
        end
    end
    if HT.RefreshLayoutInfoBoxSection then
        HT.RefreshLayoutInfoBoxSection()
    end
    return settings.healthWidth
end

-- While the original runs, the instance field points at the original so any
-- self:methodName() call inside it cannot re-enter this wrapper.
local function CreateGroupedLayoutMethodHook(attributeBars, methodName)
    local originalMethod = attributeBars[methodName]
    if type(originalMethod) ~= "function" then
        return
    end
    local groupedLayoutMethod
    groupedLayoutMethod = function (self, ...)
        self[methodName] = originalMethod
        originalMethod(self, ...)
        self[methodName] = groupedLayoutMethod
        if HT.IsResourceBarGroupEnabled() then
            ApplyStackedResourceBarLayout()
            groupedLayoutIsApplied = true
        end
        if methodName == "ApplyStyle" and HT.ApplyAllElementAppearances then
            HT.ApplyAllElementAppearances()
        end
    end
    attributeBars[methodName] = groupedLayoutMethod
end

function HT.InitializeResourceBarGroup()
    GetResourceBarGroupSettings()
    if not resourceBarHooksInstalled then
        resourceBarHooksInstalled = true
        if PLAYER_ATTRIBUTE_BARS then
            CreateGroupedLayoutMethodHook(PLAYER_ATTRIBUTE_BARS, "ApplyStyle")
            CreateGroupedLayoutMethodHook(PLAYER_ATTRIBUTE_BARS, "OnScreenResized")
        end
    end
    HT.ApplyResourceBarGroup()
end
