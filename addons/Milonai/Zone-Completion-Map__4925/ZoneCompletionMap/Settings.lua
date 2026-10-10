ZoneCompletionMap = ZoneCompletionMap or {}

local Settings = {}
ZoneCompletionMap.Settings = Settings

Settings.DEFAULTS = {
    enabled = true,
    color = { r = 0.2, g = 0.9, b = 0.3, a = 0.35 },
    invert = false,
    types = {}, -- [completionType] = false means disabled; missing means enabled
}

function Settings.Init(sv, onChange)
    local LAM = LibAddonMenu2
    local defaults = Settings.DEFAULTS

    LAM:RegisterAddonPanel("ZoneCompletionMapPanel", {
        type = "panel",
        name = GetString(ZCM_PANEL_TITLE),
        author = "Domenikus",
        version = "3.0.0",
        registerForDefaults = true,
    })

    local options = {
        {
            type = "checkbox",
            name = GetString(ZCM_ENABLED),
            tooltip = GetString(ZCM_ENABLED_TOOLTIP),
            getFunc = function() return sv.enabled end,
            setFunc = function(value)
                sv.enabled = value
                onChange()
            end,
            default = defaults.enabled,
        },
        {
            type = "colorpicker",
            name = GetString(ZCM_COLOR),
            tooltip = GetString(ZCM_COLOR_TOOLTIP),
            getFunc = function()
                local c = sv.color
                return c.r, c.g, c.b, c.a
            end,
            setFunc = function(r, g, b, a)
                sv.color = { r = r, g = g, b = b, a = a }
                onChange()
            end,
            default = defaults.color,
        },
        {
            type = "checkbox",
            name = GetString(ZCM_INVERT),
            tooltip = GetString(ZCM_INVERT_TOOLTIP),
            getFunc = function() return sv.invert end,
            setFunc = function(value)
                sv.invert = value
                onChange()
            end,
            default = defaults.invert,
        },
        {
            type = "header",
            name = GetString(ZCM_CATEGORIES),
        },
        {
            type = "description",
            text = GetString(ZCM_CATEGORIES_DESC),
        },
    }

    for _, completionType in ipairs(ZO_ZONE_STORY_ACTIVITY_COMPLETION_TYPES_SORTED_LIST) do
        options[#options + 1] = {
            type = "checkbox",
            name = GetString("SI_ZONECOMPLETIONTYPE", completionType),
            getFunc = function() return sv.types[completionType] ~= false end,
            setFunc = function(value)
                sv.types[completionType] = value
                onChange()
            end,
            default = true,
        }
    end

    LAM:RegisterOptionControls("ZoneCompletionMapPanel", options)
end
