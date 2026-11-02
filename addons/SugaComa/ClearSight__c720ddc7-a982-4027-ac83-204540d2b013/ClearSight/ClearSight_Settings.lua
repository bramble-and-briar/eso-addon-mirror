local CS = ClearSight

function CS:InitializeSettings()
    if not LibHarvensAddonSettings then
        return
    end

    local panel = LibHarvensAddonSettings:AddAddon("ClearSight", {
        allowDefaults = false,
        allowRefresh = true,
    })

    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_CHECKBOX,
        label = "ClearSight Compass Aid",
        tooltip = "Enable or disable the ClearSight high-visibility compass waypoint aid.",
        getFunction = function()
            return CS.saved.waypoint.enabled
        end,
        setFunction = function(value)
            CS.saved.waypoint.enabled = value
            if CS.UpdateWaypoint then
                CS:UpdateWaypoint()
            end
        end,
        default = true,
    })

    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_CHECKBOX,
        label = "ClearSight Reticle",
        tooltip = "Enable or disable the ClearSight high-visibility reticle.",
        getFunction = function()
            return CS.saved.reticle.enabled
        end,
        setFunction = function(value)
            CS.saved.reticle.enabled = value
            if CS.UpdateReticle then
                CS:UpdateReticle()
            end
        end,
        default = true,
    })

    local styles = {"Circle", "Square", "Cross", "Compass"}
    local items = {}
    for _, name in ipairs(styles) do items[#items+1] = {name=name, data=name} end
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_DROPDOWN,
        label = "Reticle Sight",
        tooltip = "Choose Circle, Square, Cross or Compass. Compass shows north and your custom waypoint around a clear centre as the camera turns.",
        items = items,
        getFunction = function() return CS.saved.reticle.style or "Cross" end,
        setFunction = function(controlOrValue, itemName, itemData)
            local value = itemData or itemName or controlOrValue
            if type(value) == "table" then value = value.data or value.name end
            if type(value) == "number" then value = styles[value] end
            for _, name in ipairs(styles) do
                if value == name then CS.saved.reticle.style = name; CS:UpdateReticle(); return end
            end
        end,
        default = "Cross",
    })

    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_DROPDOWN,
        label = "Wayfinder Location",
        tooltip = "Show custom waypoint guidance on the upper Compass, around the Reticle, or Both. Reticle guidance requires ClearSight Reticle enabled and works with every sight style.",
        items = {{name="Compass",data="Compass"},{name="Reticle",data="Reticle"},{name="Both",data="Both"}},
        getFunction = function() return CS.saved.waypoint.location or "Both" end,
        setFunction = function(controlOrValue, itemName, itemData)
            local value = itemData or itemName or controlOrValue
            if type(value) == "table" then value = value.data or value.name end
            if value == "Compass" or value == "Reticle" or value == "Both" then
                CS.saved.waypoint.location = value
                CS:UpdateReticle()
                CS:UpdateWaypoint()
            end
        end,
        default = "Both",
    })

    -- User-adjustable sizes; calibrated values are defaults and maximums.
    local function PreviewCompass()
        local scene = SCENE_MANAGER:GetCurrentScene()
        if not scene then return end
        CS.compassPreviewScene = scene
        if CS.previewRegisteredScene ~= scene then
            CS.previewRegisteredScene = scene
            scene:RegisterCallback("StateChange", function(_, state)
                if state == SCENE_HIDDEN and CS.compassPreviewScene == scene then
                    CS.compassPreviewScene = nil
                    CS:UpdateReticle()
                end
            end)
        end
        CS:UpdateReticle()
    end
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_CHECKBOX,
        label = "Preview Compass in Settings",
        tooltip = "Live preview with a DETECTED text guide. Adjusting a calibration slider also starts preview. Preview ends when you leave this menu.",
        getFunction = function() return CS.compassPreviewScene ~= nil end,
        setFunction = function(value)
            if value then PreviewCompass() else CS.compassPreviewScene = nil; CS:UpdateReticle() end
        end,
        default = false,
    })
    local function Calibration(label, key, minimum, maximum, default)
        panel:AddSetting({
            type = LibHarvensAddonSettings.ST_SLIDER,
            label = label,
            tooltip = "Adjust up to the calibrated maximum. Smaller values may overlap stealth text; check the live preview.",
            min = minimum, max = maximum, step = 1, format = "%d",
            getFunction = function() return CS.saved.reticle[key] or default end,
            setFunction = function(value)
                CS.saved.reticle[key] = math.max(minimum, math.min(maximum, math.floor(value)))
                PreviewCompass()
            end,
            default = default,
        })
    end
    Calibration("Compass Letter Radius", "compassLetterRadius", 40, 95, 95)
    Calibration("North Letter Size", "compassLetterSize", 16, 48, 48)
    Calibration("East / West / South Letter Size", "compassOtherLetterSize", 16, 32, 32)
    Calibration("Wayfinder Radius", "wayfinderRadius", 40, 140, 140)
    Calibration("Wayfinder Size", "wayfinderSize", 16, 40, 40)

    local function AddColor(group, key, label)
        panel:AddSetting({
            type = LibHarvensAddonSettings.ST_COLOR,
            label = label,
            tooltip = "Choose this colour using ESO's colour picker.",
            getFunction = function()
                local c = CS.saved[group][key]
                return c[1], c[2], c[3], c[4] or 1
            end,
            setFunction = function(r, g, b, a)
                CS.saved[group][key] = {r, g, b, a or 1}
                CS:UpdateReticle()
                CS:UpdateWaypoint()
            end,
            default = {unpack(CS.defaults[group][key])},
        })
    end
    AddColor("reticle", "normalColor", "Reticle: Neutral / No Target")
    AddColor("reticle", "friendlyColor", "Reticle: Friendly")
    AddColor("reticle", "hostileColor", "Reticle: Hostile")
    AddColor("reticle", "deadColor", "Reticle: Dead")
    AddColor("waypoint", "greenColor", "Waypoint: Aligned")
    AddColor("waypoint", "amberColor", "Waypoint: Nearby Direction")
    AddColor("waypoint", "redColor", "Waypoint: Turn Required")
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_BUTTON,
        label = "Restore Default Colours",
        buttonText = "Restore",
        tooltip = "Restore ClearSight's original reticle and waypoint colours.",
        clickHandler = function()
            for _, group in ipairs({"reticle", "waypoint"}) do
                for key, value in pairs(CS.defaults[group]) do
                    if type(value) == "table" and key:find("Color$") then
                        CS.saved[group][key] = {value[1], value[2], value[3], value[4]}
                    end
                end
            end
            CS:UpdateReticle()
            CS:UpdateWaypoint()
        end,
    })

end
