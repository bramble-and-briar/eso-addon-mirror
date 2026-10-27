InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

local CAPACITY_RESOURCES = {
    {
        key = "capacity:bag",
        resourceKey = "bag",
        name = "Backpack",
        texture = "EsoUI/Art/Tooltips/icon_bag.dds",
        defaultOffsetX = 50,
        defaultOffsetY = 90,
        defaultShowBar = true,
        warningThreshold = 0.75,
        dangerThreshold = 0.90,
    },
    {
        key = "capacity:bank",
        resourceKey = "bank",
        name = "Bank",
        texture = "EsoUI/Art/Tooltips/icon_bank.dds",
        defaultOffsetX = 50,
        defaultOffsetY = 130,
        defaultShowBar = true,
        warningThreshold = 0.80,
        dangerThreshold = 0.95,
    },
}

local DEFAULT_CURRENCY_WARNING_THRESHOLD = 0.75
local DEFAULT_CURRENCY_DANGER_THRESHOLD = 0.90
local DEFAULT_WARNING_COLOR = { r = 0.95, g = 0.55, b = 0.08, a = 1 }
local DEFAULT_DANGER_COLOR = { r = 0.85, g = 0.18, b = 0.18, a = 1 }
local malformedPreferenceWarnings = {}
local progressBarResources

local function WarnMalformedPreference(message)
    if malformedPreferenceWarnings[message] then return end
    malformedPreferenceWarnings[message] = true
    d("[InventoryCompanion] Ignoring malformed progress bar preference: " .. message)
end

local function EnsurePreferences()
    if type(this.accountWide.progressBarPreferences) ~= "table" then
        if this.accountWide.progressBarPreferences ~= nil then
            WarnMalformedPreference("progressBarPreferences must be a table")
        end
        this.accountWide.progressBarPreferences = {}
    end
end

local function GetResourceDefaults(resource)
    if resource.kind == "capacity" then
        return resource.defaultShowBar, resource.warningThreshold, resource.dangerThreshold
    end
    return false, DEFAULT_CURRENCY_WARNING_THRESHOLD, DEFAULT_CURRENCY_DANGER_THRESHOLD
end

local function IsValidThreshold(value)
    return type(value) == "number"
        and value == value
        and value >= 0
        and value <= 1
        and value < math.huge
end

local function IsValidColor(color)
    return type(color) == "table"
        and type(color.r) == "number" and color.r >= 0 and color.r <= 1
        and type(color.g) == "number" and color.g >= 0 and color.g <= 1
        and type(color.b) == "number" and color.b >= 0 and color.b <= 1
        and type(color.a) == "number" and color.a >= 0 and color.a <= 1
end

local function CopyColor(color)
    return { r = color.r, g = color.g, b = color.b, a = color.a }
end

local function StoreDeviation(preference, setting, value, defaultValue)
    if value == defaultValue then
        preference[setting] = nil
    else
        preference[setting] = value
    end
end

local function GetStoredPreference(resource, create)
    EnsurePreferences()
    local preferences = this.accountWide.progressBarPreferences
    local preference = preferences[resource.key]
    if type(preference) ~= "table" then
        if preference ~= nil then
            WarnMalformedPreference(resource.key .. " must be a table")
        end
        if not create then return nil end
        preference = {}
        preferences[resource.key] = preference
    end
    return preference
end

local function GetAlertColors()
    local colors = this.accountWide.progressBarAlertColors
    if type(colors) ~= "table" then
        if colors ~= nil then
            WarnMalformedPreference("progressBarAlertColors must be a table")
        end
        colors = {}
        this.accountWide.progressBarAlertColors = colors
    end
    return colors
end

local function BuildProgressBarResourceList()
    local resources = {}
    for _, definition in ipairs(CAPACITY_RESOURCES) do
        table.insert(resources, {
            key = definition.key,
            kind = "capacity",
            resourceKey = definition.resourceKey,
            name = definition.name,
            texture = definition.texture,
            defaultOffsetX = definition.defaultOffsetX,
            defaultOffsetY = definition.defaultOffsetY,
            defaultShowBar = definition.defaultShowBar,
            warningThreshold = definition.warningThreshold,
            dangerThreshold = definition.dangerThreshold,
        })
    end

    for index, currencyType in ipairs(this.GetCappedCurrencyList()) do
        local info = this.GetCappedCurrencyInfo(currencyType)
        assert(info and info.cap ~= nil, "Capped currency is missing cap information")
        table.insert(resources, {
            key = "currency:" .. tostring(currencyType),
            kind = "currency",
            currencyType = currencyType,
            name = info.name,
            texture = info.keyboardTexture or info.gamepadTexture,
            defaultOffsetX = 50,
            defaultOffsetY = 170 + (index - 1) * 30,
            defaultShowBar = false,
            warningThreshold = DEFAULT_CURRENCY_WARNING_THRESHOLD,
            dangerThreshold = DEFAULT_CURRENCY_DANGER_THRESHOLD,
        })
    end

    return resources
end

local function GetProgressBarResourceList()
    if not progressBarResources then
        progressBarResources = BuildProgressBarResourceList()
    end
    return progressBarResources
end

local function FindProgressBarResource(resourceKey)
    for _, resource in ipairs(GetProgressBarResourceList()) do
        if resource.key == resourceKey then
            return resource
        end
    end
    return nil
end

function this.GetProgressBarResources()
    return GetProgressBarResourceList()
end

function this.RefreshProgressBarResourceDiscovery()
    progressBarResources = BuildProgressBarResourceList()
    this.RefreshResourceProgressBars()
end

function this.GetProgressBarResourceValues(resource)
    assert(type(resource) == "table" and type(resource.key) == "string", "A progress bar resource descriptor is required")

    if resource.kind == "currency" then
        local info = this.GetCappedCurrencyInfo(resource.currencyType)
        if not info or info.cap == nil then
            return nil
        end
        return {
            amount = info.amount,
            cap = info.cap,
        }
    end

    assert(resource.kind == "capacity", "Unknown progress bar resource kind: " .. tostring(resource.kind))
    if resource.resourceKey == "bag" then
        return {
            amount = GetNumBagUsedSlots(BAG_BACKPACK),
            cap = GetBagSize(BAG_BACKPACK),
        }
    end
    if resource.resourceKey == "bank" then
        return {
            amount = GetNumBagUsedSlots(BAG_BANK) + GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK),
            cap = GetBagSize(BAG_BANK) + GetBagUseableSize(BAG_SUBSCRIBER_BANK),
        }
    end
    error("Unknown capacity progress bar resource: " .. tostring(resource.resourceKey))
end

function this.GetProgressBarSettings(resourceKey)
    local resource = FindProgressBarResource(resourceKey)
    assert(resource, "Unknown progress bar resource: " .. tostring(resourceKey))

    local defaultShowBar, defaultWarningThreshold, defaultDangerThreshold = GetResourceDefaults(resource)
    local preference = GetStoredPreference(resource, false)
    local showBar = defaultShowBar
    local warningThreshold = defaultWarningThreshold
    local dangerThreshold = defaultDangerThreshold
    local offsetX = resource.defaultOffsetX or 50
    local offsetY = resource.defaultOffsetY or 170
    local normalColor

    if preference then
        if preference.showBar ~= nil then
            if type(preference.showBar) == "boolean" then
                showBar = preference.showBar
            else
                WarnMalformedPreference(resource.key .. ".showBar must be boolean")
            end
        end
        if preference.warningThreshold ~= nil then
            if IsValidThreshold(preference.warningThreshold) then
                warningThreshold = preference.warningThreshold
            else
                WarnMalformedPreference(resource.key .. ".warningThreshold must be between 0 and 1")
            end
        end
        if preference.dangerThreshold ~= nil then
            if IsValidThreshold(preference.dangerThreshold) then
                dangerThreshold = preference.dangerThreshold
            else
                WarnMalformedPreference(resource.key .. ".dangerThreshold must be between 0 and 1")
            end
        end
        if preference.normalColor ~= nil then
            if IsValidColor(preference.normalColor) then
                normalColor = CopyColor(preference.normalColor)
            else
                WarnMalformedPreference(resource.key .. ".normalColor must contain RGBA components between 0 and 1")
            end
        end
        if type(preference.offsetX) == "number" and preference.offsetX >= 0 and preference.offsetX < math.huge then
            offsetX = preference.offsetX
        elseif preference.offsetX ~= nil then
            WarnMalformedPreference(resource.key .. ".offsetX must be a non-negative number")
        end
        if type(preference.offsetY) == "number" and preference.offsetY >= 0 and preference.offsetY < math.huge then
            offsetY = preference.offsetY
        elseif preference.offsetY ~= nil then
            WarnMalformedPreference(resource.key .. ".offsetY must be a non-negative number")
        end
    end

    if warningThreshold > dangerThreshold then
        WarnMalformedPreference(resource.key .. " warning threshold must not exceed its danger threshold")
        warningThreshold = defaultWarningThreshold
        dangerThreshold = defaultDangerThreshold
    end

    return {
        showBar = showBar,
        warningThreshold = warningThreshold,
        dangerThreshold = dangerThreshold,
        offsetX = offsetX,
        offsetY = offsetY,
        normalColor = normalColor,
    }
end

function this.GetProgressBarNormalColor(resourceKey)
    local settings = this.GetProgressBarSettings(resourceKey)
    if settings.normalColor then
        return settings.normalColor
    end
    local resource = FindProgressBarResource(resourceKey)
    if resource.kind == "capacity" and resource.resourceKey == "bank" then
        return { r = 0.57, g = 0.30, b = 0.77, a = 1 }
    end
    return { r = 0.25, g = 0.55, b = 0.95, a = 1 }
end

function this.GetProgressBarAlertColor(alertType)
    assert(alertType == "warning" or alertType == "danger", "Unknown progress bar alert color")
    local defaults = alertType == "warning" and DEFAULT_WARNING_COLOR or DEFAULT_DANGER_COLOR
    local color = GetAlertColors()[alertType]
    if color == nil then
        return CopyColor(defaults)
    end
    if IsValidColor(color) then
        return CopyColor(color)
    end
    WarnMalformedPreference("progressBarAlertColors." .. alertType .. " must contain RGBA components between 0 and 1")
    return CopyColor(defaults)
end

function this.GetProgressBarAlertColorPreference(alertType)
    assert(alertType == "warning" or alertType == "danger", "Unknown progress bar alert color")
    local color = GetAlertColors()[alertType]
    if color == nil then return nil end
    if IsValidColor(color) then
        return CopyColor(color)
    end
    WarnMalformedPreference("progressBarAlertColors." .. alertType .. " must contain RGBA components between 0 and 1")
    return nil
end

function this.SetProgressBarAlertColor(alertType, color)
    assert(alertType == "warning" or alertType == "danger", "Unknown progress bar alert color")
    assert(IsValidColor(color), "Alert color must contain RGBA components between 0 and 1")
    GetAlertColors()[alertType] = CopyColor(color)
end

-- The colour the progress bar shows for a resource at a level ("normal", "warning" or "danger").
-- Returns nil when no progress bar exists for the resource.
function this.GetProgressBarColorForLevel(resourceKey, level)
    if not FindProgressBarResource(resourceKey) then return nil end
    if level == "danger" or level == "warning" then
        return this.GetProgressBarAlertColor(level)
    end
    return this.GetProgressBarNormalColor(resourceKey)
end

-- The colour the progress bar shows for a resource at a fill fraction (0-1), using that bar's
-- warning and danger thresholds. Returns nil when no progress bar exists for the resource.
function this.GetProgressBarColorForPercent(resourceKey, percent)
    if not FindProgressBarResource(resourceKey) then return nil end
    local settings = this.GetProgressBarSettings(resourceKey)
    local level = "normal"
    if percent >= settings.dangerThreshold then
        level = "danger"
    elseif percent >= settings.warningThreshold then
        level = "warning"
    end
    return this.GetProgressBarColorForLevel(resourceKey, level)
end

function this.SetProgressBarSetting(resourceKey, setting, value)
    local resource = FindProgressBarResource(resourceKey)
    assert(resource, "Unknown progress bar resource: " .. tostring(resourceKey))
    assert(
        setting == "showBar" or setting == "warningThreshold" or setting == "dangerThreshold" or setting == "normalColor",
        "Unknown progress bar setting: " .. tostring(setting)
    )

    if setting == "showBar" then
        assert(type(value) == "boolean", "showBar must be boolean")
    elseif setting == "normalColor" then
        assert(IsValidColor(value), "normalColor must contain RGBA components between 0 and 1")
    else
        assert(IsValidThreshold(value), setting .. " must be between 0 and 1")
    end

    local preference = GetStoredPreference(resource, true)
    local settings = this.GetProgressBarSettings(resourceKey)
    local defaultShowBar, defaultWarningThreshold, defaultDangerThreshold = GetResourceDefaults(resource)

    if setting == "normalColor" then
        preference.normalColor = CopyColor(value)
    elseif setting == "showBar" then
        StoreDeviation(preference, "showBar", value, defaultShowBar)
    elseif setting == "warningThreshold" then
        StoreDeviation(preference, "warningThreshold", value, defaultWarningThreshold)
        if value > settings.dangerThreshold then
            StoreDeviation(preference, "dangerThreshold", value, defaultDangerThreshold)
        end
    else
        StoreDeviation(preference, "dangerThreshold", value, defaultDangerThreshold)
        if value < settings.warningThreshold then
            StoreDeviation(preference, "warningThreshold", value, defaultWarningThreshold)
        end
    end

    if next(preference) == nil then
        this.accountWide.progressBarPreferences[resource.key] = nil
    end
end

function this.SetProgressBarPosition(resourceKey, offsetX, offsetY)
    local resource = FindProgressBarResource(resourceKey)
    assert(resource, "Unknown progress bar resource: " .. tostring(resourceKey))
    assert(
        type(offsetX) == "number" and offsetX >= 0 and offsetX < math.huge
            and type(offsetY) == "number" and offsetY >= 0 and offsetY < math.huge,
        "Progress bar position must contain non-negative numeric offsets"
    )

    local preference = GetStoredPreference(resource, true)
    preference.offsetX = offsetX
    preference.offsetY = offsetY
end

function this.InitializeProgressBarResources()
    EnsurePreferences()
    progressBarResources = BuildProgressBarResourceList()
end

function this.HasVisibleCurrencyProgressBars()
    for _, resource in ipairs(this.GetProgressBarResources()) do
        if resource.kind == "currency" and this.IsProgressBarVisible(resource.key) then
            return true
        end
    end
    return false
end

function this.IsCurrencyProgressBarVisible(currencyType)
    return this.IsProgressBarVisible("currency:" .. tostring(currencyType))
end

function this.HasVisibleCappedProgressBars()
    return this.HasVisibleCurrencyProgressBars()
end
