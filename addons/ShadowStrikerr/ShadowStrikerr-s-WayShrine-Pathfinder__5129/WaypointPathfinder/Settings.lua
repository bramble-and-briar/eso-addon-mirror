local addon = ShadowStrikerrWaypointPathfinder
local styles = { "Chevron", "Arrowhead", "Diamond", "FlatChevron", "DoubleChevron", "NeedleArrow", "WayshrineArrow" }

ZO_CreateStringId("SI_BINDING_NAME_SHADOWSTRIKERR_WPF_SETTINGS", "Open quick settings")
ZO_CreateStringId("SI_BINDING_NAME_SHADOWSTRIKERR_WPF_GUIDANCE", "Toggle waypoint guidance")
ZO_CreateStringId("SI_BINDING_NAME_SHADOWSTRIKERR_WPF_MOVE", "Move the distance panel or compact icon")
ZO_CreateStringId("SI_BINDING_NAME_SHADOWSTRIKERR_WPF_TARGET_WAYSHRINE", "Target hovered wayshrine")

function addon.RegisterSettings()
    local lam = LibAddonMenu2
    if not lam then return end
    local settings = addon.settings
    local preview
    local function refreshPreview()
        if not preview then return end
        local color = settings.groundColors.near
        preview:SetTexture("WaypointPathfinder/" .. settings.icon .. ".dds")
        preview:SetColor(color[1], color[2], color[3], 1)
    end
    local function checkbox(name, key, tip)
        return {
            type = "checkbox",
            name = name,
            tooltip = tip,
            getFunc = function() return settings[key] end,
            setFunc = function(value)
                settings[key] = value
                addon.Refresh()
            end,
        }
    end
    local function colorPicker(name, key)
        return {
            type = "colorpicker",
            name = name,
            getFunc = function()
                local color = settings.groundColors[key]
                return color[1], color[2], color[3]
            end,
            setFunc = function(r, g, b)
                settings.groundColors[key] = { r, g, b }
                refreshPreview()
                addon.Refresh()
            end,
        }
    end

    local panelId = "ShadowStrikerrWaypointPathfinderOptions"
    local dropdownId = panelId .. "GroundStyle"
    addon.settingsPanel = lam:RegisterAddonPanel(panelId, {
        type = "panel", name = "WayShrine Pathfinder", displayName = "WayShrine Pathfinder",
        author = "ShadowStrikerr", version = "0.1.0",
        registerForRefresh = true,
    })
    local function onControlsCreated(createdPanel)
        if createdPanel ~= addon.settingsPanel then return end
        CALLBACK_MANAGER:UnregisterCallback("LAM-PanelControlsCreated", onControlsCreated)
        local dropdown = _G[dropdownId]
        preview = WINDOW_MANAGER:CreateControl(nil, dropdown, CT_TEXTURE)
        preview:SetDimensions(36, 36)
        preview:SetAnchor(RIGHT, dropdown.combobox, LEFT, -6, 0)
        preview:SetDrawLayer(DL_OVERLAY)
        refreshPreview()
    end
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", onControlsCreated)
    function addon.OpenSettings()
        lam:OpenToPanel(addon.settingsPanel)
    end
    lam:RegisterOptionControls(panelId, {
        checkbox("Show ground arrows", "groundTrail"),
        checkbox("Follow recorded walked paths", "followWalkedPaths",
            "Records your overland movement locally for future waypoint routes."),
        checkbox("Show arrows through terrain", "visibleThroughTerrain"),
        checkbox("Show dots on AUI's minimap only", "minimapTrail",
            "Requires the optional AUI - Advanced UI minimap. The world map is unchanged."),
        {
            type = "dropdown", name = "Ground trail icon", reference = dropdownId,
            tooltip = "The preview uses the very-close waypoint color.",
            choices = { "Chevron", "Arrowhead", "Diamond", "Flat chevron", "Double chevron", "Needle arrow", "Wayshrine Arrow" },
            choicesValues = styles,
            getFunc = function() return settings.icon end,
            setFunc = function(value)
                settings.icon = value
                refreshPreview()
                addon.Refresh()
            end,
        },
        { type = "header", name = "Distance panel" },
        checkbox("Show distance panel (expanded)", "showPanel"),
        checkbox("Show collapsed waypoint icon", "showCompact"),
        { type = "header", name = "Ground trail colors" },
        colorPicker("Very close (0-100 m)", "near"),
        colorPicker("Nearby (over 100-500 m)", "middle"),
        colorPicker("Distant (over 500 m)", "far"),
        { type = "header", name = "Auto Wayshrines" },
        checkbox("Show nearby wayshrines with no waypoint selected", "autoWayshrines",
            "A personal waypoint takes priority and shows only its own trail."),
        {
            type = "slider", name = "Maximum wayshrine trails", min = 1, max = 5, step = 1,
            getFunc = function() return settings.autoWayshrineCount end,
            setFunc = function(value)
                settings.autoWayshrineCount = value
                addon.Refresh()
            end,
            disabled = function() return not settings.autoWayshrines end,
        },
    })
end
