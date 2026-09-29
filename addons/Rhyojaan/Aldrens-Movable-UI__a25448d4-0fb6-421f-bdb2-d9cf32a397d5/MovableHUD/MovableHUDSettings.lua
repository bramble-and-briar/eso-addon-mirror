local MH = MovableHUD

if not MH then
    return
end

local PANEL_NAME = "Movable HUD"

local function Round(value)
    value = tonumber(value) or 0
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

local function GetSettings(targetKey)
    return MH:GetElementSettings(targetKey)
end

local function RefreshPanel()
    local panel = MH.settingsPanel
    if not panel then
        return
    end

    -- LibHarvens/LibVotans rebuilds the selected settings page when it is
    -- selected again. This keeps displayed slider values in sync after Reset.
    zo_callLater(function()
        if panel.selected and panel.Select then
            panel.selected = false
            panel:Select()
        end
    end, 0)
end

local function AddSection(panel, library, targetKey, title, supportsDimensions)
    panel:AddSetting({
        type = library.ST_SECTION,
        label = title,
    })

    local native = MH.nativeTargets[targetKey]
    if native and native.unavailable then
        panel:AddSetting({type = library.ST_LABEL, label = native.unavailable})
        return
    end

    panel:AddSetting({
        type = library.ST_CHECKBOX,
        label = "Preview this element",
        tooltip = "This box also appears automatically when enabling its mover or adjusting its sliders. Hidden elements use their last observed bounds or a labeled sample, not an exact native-position prediction. Leaving this page ends the preview.",
        default = false,
        getFunction = function() return MH:IsElementPreviewEnabled(targetKey) end,
        setFunction = function(value)
            MH:SetElementPreviewEnabled(targetKey, value)
            -- Let the settings library retain controller focus and update its row.
            -- Reselecting this panel from the checkbox callback can navigate back.
        end,
    })

    panel:AddSetting({
        type = library.ST_CHECKBOX,
        label = "Enable override (native movers start OFF)",
        tooltip = "When disabled, ESO's original placement is restored for this HUD element.",
        getFunction = function()
            local settings = GetSettings(targetKey)
            return settings and settings.enabled or false
        end,
        setFunction = function(value)
            MH:SetElementEnabled(targetKey, value)
        end,
        default = not MH.nativeTargets[targetKey],
    })

    local function IsDisabled()
        local settings = GetSettings(targetKey)
        return not settings or not settings.enabled
    end

    panel:AddSetting({
        type = library.ST_SLIDER,
        label = "Horizontal position",
        tooltip = "Moves the element left or right. Negative values move it left.",
        min = -2500,
        max = 3500,
        step = 5,
        format = "%.0f",
        unit = " px",
        getFunction = function()
            local settings = GetSettings(targetKey)
            return settings and settings.x or 0
        end,
        setFunction = function(value)
            MH:SetElementValue(targetKey, "x", value)
        end,
        disable = IsDisabled,
        default = 0,
    })

    panel:AddSetting({
        type = library.ST_SLIDER,
        label = "Vertical position",
        tooltip = "Moves the element up or down. Negative values move it up.",
        min = -2500,
        max = 3500,
        step = 5,
        format = "%.0f",
        unit = " px",
        getFunction = function()
            local settings = GetSettings(targetKey)
            return settings and settings.y or 0
        end,
        setFunction = function(value)
            MH:SetElementValue(targetKey, "y", value)
        end,
        disable = IsDisabled,
        default = 0,
    })

    if supportsDimensions then
        panel:AddSetting({
            type = library.ST_SLIDER,
            label = "Width",
            tooltip = "Changes the element's width.",
            min = 100,
            max = 2200,
            step = 5,
            format = "%.0f",
            unit = " px",
            getFunction = function()
                local settings = GetSettings(targetKey)
                return settings and settings.width or 100
            end,
            setFunction = function(value)
                MH:SetElementValue(targetKey, "width", value)
            end,
            disable = IsDisabled,
            default = targetKey == "chat" and 490 or 480,
        })

        panel:AddSetting({
            type = library.ST_SLIDER,
            label = "Height",
            tooltip = "Changes the element's height.",
            min = 60,
            max = 1600,
            step = 5,
            format = "%.0f",
            unit = " px",
            getFunction = function()
                local settings = GetSettings(targetKey)
                return settings and settings.height or 60
            end,
            setFunction = function(value)
                MH:SetElementValue(targetKey, "height", value)
            end,
            disable = IsDisabled,
            default = targetKey == "chat" and 280 or 600,
        })
    end

    if not MH.nativeTargets[targetKey] then
    panel:AddSetting({
        type = library.ST_SLIDER,
        label = "Scale",
        tooltip = supportsDimensions
            and "Scales the entire element after applying its width and height."
            or "Scales all active group frames together. While solo, it also scales your companion name and health frame.",
        min = 25,
        max = 300,
        step = 1,
        format = "%.0f",
        unit = "%",
        getFunction = function()
            local settings = GetSettings(targetKey)
            return settings and Round(settings.scale * 100) or 100
        end,
        setFunction = function(value)
            MH:SetElementValue(targetKey, "scale", value / 100)
        end,
        disable = IsDisabled,
        default = 100,
    })

    end

    panel:AddSetting({
        type = library.ST_BUTTON,
        label = "Restore this element",
        tooltip = "Restores this element to the position and size captured from ESO's interface.",
        buttonText = "Reset",
        clickHandler = function()
            MH:ResetTarget(targetKey)
            RefreshPanel()
        end,
    })
end

function MH:RegisterSettingsPanel()
    if self.settingsPanel then
        return true
    end

    local library = LibHarvensAddonSettings
    if not library then
        self:Print("LibVotans is required for the Options > Addons settings page.")
        return false
    end

    local panel = library:AddAddon(PANEL_NAME, {
        allowDefaults = false,
        allowRefresh = true,
    })

    if not panel then
        self:Print("Could not register the native Addons settings page.")
        return false
    end

    self.settingsPanel = panel
    self:InstallPreviewVisibilityTracking()

    panel:AddSetting({
        type = library.ST_LABEL,
        label = "Existing settings are preserved. Native movers start OFF and use X/Y offsets from ESO placement. Reset disables a native mover. Hidden or unavailable elements wait until ESO creates and shows them. Native scaling is intentionally unavailable.",
        tooltip = "The native settings screen captures controller focus, so its buttons will not activate gameplay actions.",
    })

    panel:AddSetting({
        type = library.ST_CHECKBOX,
        label = "Show exact live outlines while adjusting",
        tooltip = "Attaches labeled outlines to the actual chat and quest controls while this page is open. Group bounds use active group frames; while solo with a companion, the outline follows the companion frame.",
        getFunction = function()
            return MH.saved and MH.saved.previewEnabled ~= false
        end,
        setFunction = function(value)
            MH:SetPreviewEnabled(value)
        end,
        default = true,
    })

    self:AddColorSettings(panel, library)

    AddSection(panel, library, "chat", "Chat Box", true)
    AddSection(panel, library, "quest", "Quest Tracker", true)
    AddSection(panel, library, "group", "Group & Companion Frames", false)
    for _, key in ipairs(self.nativeOrder) do
        AddSection(panel, library, key, self:GetTargetName(key), false)
    end

    panel:AddSetting({
        type = library.ST_SECTION,
        label = "All Elements",
    })

    panel:AddSetting({
        type = library.ST_BUTTON,
        label = "Restore every supported HUD element",
        tooltip = "Restores existing movers and disables all native movers, returning their anchors to ESO.",
        buttonText = "Reset All",
        clickHandler = function()
            MH:ResetAll()
            RefreshPanel()
        end,
    })

    panel:AddSetting({
        type = library.ST_LABEL,
        label = "Version " .. tostring(self.version),
    })

    return true
end

