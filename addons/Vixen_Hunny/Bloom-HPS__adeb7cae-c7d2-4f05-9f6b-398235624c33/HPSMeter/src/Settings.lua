-- ============================================================================
-- Bloom HPS - Settings
-- LibAddonMenu-2.0 panel (optional: the meter works without it).
-- ============================================================================

local M = HPSMeterUI
local Settings = {}
M.Settings = Settings

local function Relayout() M.UI.ApplyLayout() end

local function Bind(key, onChange)
    return function() return M.saved[key] end,
        function(value)
            M.saved[key] = value
            if onChange then onChange(value) end
        end
end

local function Checkbox(name, key)
    local getFunc, setFunc = Bind(key, Relayout)
    return { type = "checkbox", name = name, getFunc = getFunc, setFunc = setFunc, default = M.defaults[key] }
end

local function Slider(name, key, minValue, maxValue, step)
    local getFunc, setFunc = Bind(key, Relayout)
    return {
        type = "slider", name = name, min = minValue, max = maxValue, step = step,
        decimals = step < 1 and 2 or 0,
        getFunc = getFunc, setFunc = setFunc, default = M.defaults[key],
    }
end

local function Color(name, key, fallback)
    return {
        type = "editbox", name = name, tooltip = "6-digit hex color, e.g. " .. fallback,
        default = fallback,
        getFunc = function() return M.saved[key] end,
        setFunc = function(value)
            M.saved[key] = M.SanitizeHex(value, fallback)
            M.UI.Refresh()
        end,
    }
end

function Settings.Create()
    local LAM = LibAddonMenu2
    if not LAM or not LAM.RegisterAddonPanel then return end

    local panelName = M.name .. "Panel"
    local panel = LAM:RegisterAddonPanel(panelName, {
        type = "panel",
        name = M.title,
        displayName = string.format("|t28:28:%s|t |cffb3d1%s|r |t28:28:%s|t",
            M.Texture("flower_sakura"), M.title, M.Texture("flower_lavender")),
        author = M.author,
        version = M.version,
        registerForRefresh = true,
        registerForDefaults = true,
    })

    -- keep the meter visible on its own settings page so position / scale
    -- changes can be seen, even with "Hide in Menus" on
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(opened)
        if opened == panel then M.UI.SetPreview(true) end
    end)
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(closed)
        if closed == panel then M.UI.SetPreview(false) end
    end)

    LAM:RegisterOptionControls(panelName, {
        { type = "header", name = "Display" },
        Checkbox("Show Meter", "showLabel"),
        Slider("Position X", "labelX", 0, 2000, 1),
        Slider("Position Y", "labelY", 0, 2000, 1),
        Slider("Scale", "scale", 0.1, 10, 0.05),
        Checkbox("Show Title", "showTitle"),
        {
            type = "checkbox", name = "Hide in Menus",
            tooltip = "Only show the meter on the normal HUD. It hides while the inventory, "
                .. "map, settings or any other menu is open.",
            getFunc = function() return M.saved.hideInMenus end,
            setFunc = function(value)
                M.saved.hideInMenus = value
                M.UI.ApplySceneVisibility()
            end,
            default = M.defaults.hideInMenus,
        },

        { type = "header", name = "Flowers" },
        Checkbox("Show Flowers & Sparkles", "showFlowers"),
        Slider("Flower Opacity", "flowerAlpha", 0, 1, 0.05),

        { type = "header", name = "Healing" },
        Color("Healing Color", "labelColor", M.DEFAULT_HEAL_COLOR),

        { type = "header", name = "Shielding" },
        Checkbox("Show Shield Lines (SPS / SPM / total)", "showShields"),
        Color("Shielding Color", "shieldColor", M.DEFAULT_SHIELD_COLOR),

        { type = "header", name = "Personal / Group" },
        Checkbox("Show Personal / Group Splits", "showSplits"),
        {
            type = "checkbox", name = "Track Group Shields (LibFights group mode)",
            tooltip = "Needed for the group shield number. Makes LibFights also read group "
                .. "members' combat events, which costs a little more in big fights. "
                .. "Takes effect after /reloadui. Ignored if another add-on already started LibFights.",
            getFunc = function() return M.saved.groupMode end,
            setFunc = function(value) M.saved.groupMode = value end,
            default = M.defaults.groupMode,
            requiresReload = true,
        },

        { type = "header", name = "Damage Mitigated" },
        Checkbox("Show Mitigation Line", "showMitigation"),
        Color("Mitigation Color", "mitigationColor", M.DEFAULT_MITIGATION_COLOR),
    })
end
