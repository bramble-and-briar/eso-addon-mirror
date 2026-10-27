InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

local BAR_COLORS = {
    bag_normal = ZO_XP_BAR_GRADIENT_COLORS,
    bank_normal = {
        ZO_ColorDef:New(0.45, 0.20, 0.65, 1.0),
        ZO_ColorDef:New(0.70, 0.40, 0.90, 1.0),
    },
    warning = {
        ZO_ColorDef:New(0.90, 0.50, 0.05, 1.0),
        ZO_ColorDef:New(1.00, 0.70, 0.10, 1.0),
    },
    danger = {
        ZO_ColorDef:New(0.70, 0.15, 0.15, 1.0),
        ZO_ColorDef:New(0.95, 0.25, 0.25, 1.0),
    },
}

local progressBarControls = {}
local isCutsceneHidden = false

local function GetControlName(resourceKey)
    return "InventoryCompanion_ProgressBar_" .. resourceKey:gsub("[^%w]", "_")
end

local function GetEffectiveSettings(resource)
    local settings = this.GetProgressBarSettings(resource.key)
    return settings
end

local function CreateProgressBarControl(resource, resourceSettings)
    local control = CreateControlFromVirtual(
        GetControlName(resource.key),
        GuiRoot,
        "InventoryCompanion_ProgressBar_Template"
    )
    control:SetAnchor(
        TOPLEFT,
        GuiRoot,
        TOPLEFT,
        resourceSettings.offsetX,
        resourceSettings.offsetY
    )
    control.resourceKey = resource.key
    control.icon = GetControl(control, "Icon")
    control.trackBG = GetControl(control, "TrackBG")
    control.bar = GetControl(control, "Bar")
    control.label = GetControl(control, "Label")
    control.icon:SetTexture(resource.texture)
    control.icon:SetDrawLayer(DL_CONTROLS)
    control.icon:SetDrawLevel(3)
    control.trackBG:SetTexture("/esoui/art/miscellaneous/progressbar_frame_bg.dds")
    control.trackBG:SetTextureCoords(0.0195, 0.5898, 0, 0.625)
    control.trackBG:SetDrawLayer(DL_CONTROLS)
    control.trackBG:SetDrawLevel(1)
    control.bar:SetBarAlignment(BAR_ALIGNMENT_NORMAL)
    control.bar:SetTexture("/esoui/art/miscellaneous/progressbar_genericfill.dds")
    control.bar:SetTextureCoords(0, 1, 0, 0.625)
    control.bar:SetDrawLayer(DL_CONTROLS)
    control.bar:SetDrawLevel(2)
    control.bar:SetMinMax(0, 1)
    control.bar:SetValue(0)
    control.label:SetDrawLayer(DL_CONTROLS)
    control.label:SetDrawLevel(4)
    progressBarControls[resource.key] = control

    control:SetHandler("OnMoveStop", function(movedControl)
        this.SetProgressBarPosition(resource.key, movedControl:GetLeft(), movedControl:GetTop())
    end)

    return control
end

local function GetNormalColors(resource)
    local color = this.GetProgressBarSettings(resource.key).normalColor
    if not color then
        if resource.kind == "capacity" and resource.resourceKey == "bank" then
            return BAR_COLORS.bank_normal
        end
        return BAR_COLORS.bag_normal
    end
    return {
        ZO_ColorDef:New(color.r * 0.8, color.g * 0.8, color.b * 0.8, color.a),
        ZO_ColorDef:New(math.min(color.r * 1.15, 1), math.min(color.g * 1.15, 1), math.min(color.b * 1.15, 1), color.a),
    }
end

local function GetAlertColors(alertType)
    local color = this.GetProgressBarAlertColorPreference(alertType)
    if not color then
        return BAR_COLORS[alertType]
    end
    return {
        ZO_ColorDef:New(color.r * 0.8, color.g * 0.8, color.b * 0.8, color.a),
        ZO_ColorDef:New(math.min(color.r * 1.15, 1), math.min(color.g * 1.15, 1), math.min(color.b * 1.15, 1), color.a),
    }
end

local function UpdateProgressBar(resource, control, settings)
    local values = this.GetProgressBarResourceValues(resource)
    if not values then
        control:SetHidden(true)
        return
    end

    local percent = values.cap > 0 and values.amount / values.cap or 0
    control.bar:SetMinMax(0, values.cap)
    control.bar:SetValue(values.amount)

    if percent >= settings.dangerThreshold then
        ZO_StatusBar_SetGradientColor(control.bar, GetAlertColors("danger"))
    elseif percent >= settings.warningThreshold then
        ZO_StatusBar_SetGradientColor(control.bar, GetAlertColors("warning"))
    else
        ZO_StatusBar_SetGradientColor(control.bar, GetNormalColors(resource))
    end

    control.label:SetText(string.format("%d / %d", values.amount, values.cap))
    control:SetHidden(not settings.showBar or isCutsceneHidden)
end

function this.RefreshResourceProgressBars()
    local activeResources = {}
    for _, resource in ipairs(this.GetProgressBarResources()) do
        activeResources[resource.key] = true
        local settings = GetEffectiveSettings(resource)
        local control = progressBarControls[resource.key]
        if settings.showBar or control then
            control = control or CreateProgressBarControl(resource, this.GetProgressBarSettings(resource.key))
            UpdateProgressBar(resource, control, settings)
        end
    end
    for resourceKey, control in pairs(progressBarControls) do
        if not activeResources[resourceKey] then
            control:SetHidden(true)
        end
    end
end

function this.InitResourceProgressBars()
    for _, resource in ipairs(this.GetProgressBarResources()) do
        local settings = GetEffectiveSettings(resource)
        if settings.showBar then
            local control = progressBarControls[resource.key]
                or CreateProgressBarControl(resource, this.GetProgressBarSettings(resource.key))
            UpdateProgressBar(resource, control, settings)
        end
    end
end

function this.SetProgressBarsHidden(hidden)
    isCutsceneHidden = hidden == true
    for _, resource in ipairs(this.GetProgressBarResources()) do
        local control = progressBarControls[resource.key]
        if control then
            control:SetHidden(isCutsceneHidden or not GetEffectiveSettings(resource).showBar)
        end
    end
end

function this.HasVisibleProgressBars()
    for _, resource in ipairs(this.GetProgressBarResources()) do
        if GetEffectiveSettings(resource).showBar then
            return true
        end
    end
    return false
end

function this.IsProgressBarVisible(resourceKey)
    local resource
    for _, candidate in ipairs(this.GetProgressBarResources()) do
        if candidate.key == resourceKey then
            resource = candidate
            break
        end
    end
    return resource ~= nil and GetEffectiveSettings(resource).showBar
end
