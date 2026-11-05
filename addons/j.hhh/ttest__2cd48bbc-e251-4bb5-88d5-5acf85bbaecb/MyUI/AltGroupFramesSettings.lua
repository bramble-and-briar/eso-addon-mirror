--[[
Alternative Group Frames - Console settings
Version 1.4.1

Uses the standard LibAddonMenu-2.0 API. The console distribution of
LibAddonMenu presents these controls through its gamepad settings backend.
]]

local PANEL_ID = "ALTGF_Settings"

local function ColorTable(color)
    local r, g, b, a = color:UnpackRGBA()
    return { r = r, g = g, b = b, a = a }
end

local function AddColorPicker(options, manager, name, tooltip, defaultColor, getColor, setColor)
    options[#options + 1] = {
        type = "colorpicker",
        name = name,
        tooltip = tooltip,
        width = "full",
        default = ColorTable(defaultColor),
        getFunc = function()
            return getColor():UnpackRGBA()
        end,
        setFunc = function(r, g, b, a)
            setColor(ZO_ColorDef:New(r, g, b, a or 1))
            manager:ApplySavedSettings(true, false)
        end,
    }
end

CALLBACK_MANAGER:RegisterCallback(ALT_GROUP_FRAMES.EVENT.MANAGER_CREATED, function(manager)
    local LAM2 = LibAddonMenu2
    if not LAM2 then
        d("[Alternative Group Frames] LibAddonMenu-2.0 was not loaded; settings are unavailable.")
        return
    end

    -- My UI owns the settings navigation. Never register a second LAM panel.

    local rootWidth = math.max(1, zo_round(tonumber(GuiRoot:GetWidth()) or 1920))
    local rootHeight = math.max(1, zo_round(tonumber(GuiRoot:GetHeight()) or 1080))
    local options = {
        {
            type = "header",
            name = "Health-bar colors",
        },
        {
            type = "dropdown",
            name = "Health-bar color mode",
            tooltip = "Role colors uses the individually configurable Tank, Healer, and Damage Dealer gradients. ESO default uses the game's standard health gradient.",
            choices = { "Role colors", "ESO default" },
            choicesValues = { 1, 0 },
            default = manager.DEFAULTS.COLORS_SHOW,
            getFunc = function()
                return manager.SAVEVARS.COLORS_SHOW
            end,
            setFunc = function(value)
                -- Some console adapters return the displayed choice string instead
                -- of choicesValues, so accept both representations.
                local colorMode = tonumber(value)
                if colorMode == nil then
                    local valuesByName = {
                        ["Role colors"] = 1,
                        ["ESO default"] = 0,
                    }
                    colorMode = valuesByName[value]
                end
                manager.SAVEVARS.COLORS_SHOW = colorMode or manager.DEFAULTS.COLORS_SHOW
                manager:ApplySavedSettings(true, true)
            end,
        },
        {
            type = "header",
            name = "Tank gradient",
        },
    }

    AddColorPicker(
        options,
        manager,
        "Tank gradient start",
        "Color at the beginning of the tank health gradient. Use the same color for start and end to make the bar solid.",
        manager.DEFAULTS.LFG_COLORS[LFG_ROLE_TANK][1],
        function() return manager.SAVEVARS.LFG_COLORS[LFG_ROLE_TANK][1] end,
        function(color) manager.SAVEVARS.LFG_COLORS[LFG_ROLE_TANK][1] = color end
    )
    AddColorPicker(
        options,
        manager,
        "Tank gradient end",
        "Color at the end of the tank health gradient.",
        manager.DEFAULTS.LFG_COLORS[LFG_ROLE_TANK][2],
        function() return manager.SAVEVARS.LFG_COLORS[LFG_ROLE_TANK][2] end,
        function(color) manager.SAVEVARS.LFG_COLORS[LFG_ROLE_TANK][2] = color end
    )

    options[#options + 1] = { type = "header", name = "Healer gradient" }
    AddColorPicker(
        options,
        manager,
        "Healer gradient start",
        "Color at the beginning of the healer health gradient. Use the same color for start and end to make the bar solid.",
        manager.DEFAULTS.LFG_COLORS[LFG_ROLE_HEAL][1],
        function() return manager.SAVEVARS.LFG_COLORS[LFG_ROLE_HEAL][1] end,
        function(color) manager.SAVEVARS.LFG_COLORS[LFG_ROLE_HEAL][1] = color end
    )
    AddColorPicker(
        options,
        manager,
        "Healer gradient end",
        "Color at the end of the healer health gradient.",
        manager.DEFAULTS.LFG_COLORS[LFG_ROLE_HEAL][2],
        function() return manager.SAVEVARS.LFG_COLORS[LFG_ROLE_HEAL][2] end,
        function(color) manager.SAVEVARS.LFG_COLORS[LFG_ROLE_HEAL][2] = color end
    )

    options[#options + 1] = { type = "header", name = "Damage Dealer gradient" }
    AddColorPicker(
        options,
        manager,
        "Damage Dealer gradient start",
        "Color at the beginning of the damage-dealer health gradient. Use the same color for start and end to make the bar solid.",
        manager.DEFAULTS.LFG_COLORS[LFG_ROLE_DPS][1],
        function() return manager.SAVEVARS.LFG_COLORS[LFG_ROLE_DPS][1] end,
        function(color) manager.SAVEVARS.LFG_COLORS[LFG_ROLE_DPS][1] = color end
    )
    AddColorPicker(
        options,
        manager,
        "Damage Dealer gradient end",
        "Color at the end of the damage-dealer health gradient.",
        manager.DEFAULTS.LFG_COLORS[LFG_ROLE_DPS][2],
        function() return manager.SAVEVARS.LFG_COLORS[LFG_ROLE_DPS][2] end,
        function(color) manager.SAVEVARS.LFG_COLORS[LFG_ROLE_DPS][2] = color end
    )

    options[#options + 1] = { type = "header", name = "Other bar colors" }
    AddColorPicker(
        options,
        manager,
        "Missing health",
        "Color shown behind the filled health bar. This represents the unit's missing health.",
        manager.DEFAULTS.MISSING_HEALTH_COLOR,
        function() return manager.SAVEVARS.MISSING_HEALTH_COLOR end,
        function(color) manager.SAVEVARS.MISSING_HEALTH_COLOR = color end
    )
    AddColorPicker(
        options,
        manager,
        "Overshield",
        "Color of damage shields drawn over the health bar.",
        manager.DEFAULTS.SHIELD_COLOR,
        function() return manager.SAVEVARS.SHIELD_COLOR end,
        function(color) manager.SAVEVARS.SHIELD_COLOR = color end
    )
    options[#options + 1] = {
        type = "slider",
        name = "Overshield opacity",
        tooltip = "Controls how transparent the overshield is. 0% is invisible and 100% is fully opaque.",
        min = 0,
        max = 100,
        step = 1,
        default = zo_round(select(4, manager.DEFAULTS.SHIELD_COLOR:UnpackRGBA()) * 100),
        getFunc = function()
            local _, _, _, alpha = manager.SAVEVARS.SHIELD_COLOR:UnpackRGBA()
            return zo_round((tonumber(alpha) or 0.8) * 100)
        end,
        setFunc = function(value)
            local r, g, b = manager.SAVEVARS.SHIELD_COLOR:UnpackRGBA()
            local alpha = zo_clamp((tonumber(value) or 80) / 100, 0, 1)
            manager.SAVEVARS.SHIELD_COLOR = ZO_ColorDef:New(r, g, b, alpha)
            manager:ApplySavedSettings(true, false)
        end,
    }

    options[#options + 1] = { type = "header", name = "Group-frame layout" }
    options[#options + 1] = {
        type = "dropdown",
        name = "Group-frame windows",
        tooltip = "Choose one window with all 12 players or two windows with 6 players each.",
        choices = { "1 window - 12 players", "2 windows - 6 players each" },
        choicesValues = { 1, 2 },
        default = manager.DEFAULTS.GROUP_LAYOUT,
        getFunc = function()
            return tonumber(manager.SAVEVARS.GROUP_LAYOUT) == 2 and 2 or 1
        end,
        setFunc = function(value)
            local layout = tonumber(value)
            if layout == nil then
                layout = value == "2 windows - 6 players each" and 2 or 1
            end
            manager.SAVEVARS.GROUP_LAYOUT = layout == 2 and 2 or 1
            manager.SAVEVARS.FRAMES_PER_COLUMN = manager.SAVEVARS.GROUP_LAYOUT == 2 and 6 or 12
            manager:ApplySavedSettings(true, false)
        end,
    }
    options[#options + 1] = {
        type = "slider",
        name = "Gap between windows",
        tooltip = "Horizontal space between the two group windows. With up to 12 players the windows contain 6 players each; with 13-24 players they expand to 12 players each.",
        min = 0,
        max = 200,
        step = 1,
        default = manager.DEFAULTS.GROUP_WINDOW_GAP,
        getFunc = function()
            return zo_round(tonumber(manager.SAVEVARS.GROUP_WINDOW_GAP) or manager.DEFAULTS.GROUP_WINDOW_GAP)
        end,
        setFunc = function(value)
            manager.SAVEVARS.GROUP_WINDOW_GAP = zo_clamp(zo_round(tonumber(value) or manager.DEFAULTS.GROUP_WINDOW_GAP), 0, 200)
            manager:ApplySavedSettings(true, false)
        end,
        disabled = function()
            return tonumber(manager.SAVEVARS.GROUP_LAYOUT) ~= 2
        end,
    }

    options[#options + 1] = { type = "header", name = "Size and position" }
    options[#options + 1] = {
        type = "slider",
        name = "Frame scale",
        tooltip = "Scales the complete group-frame container, including bars, text, icons, spacing, shields, and trauma overlays.",
        min = 50,
        max = 200,
        step = 1,
        default = manager.DEFAULTS.FRAME_SCALE,
        getFunc = function()
            return zo_round(tonumber(manager.SAVEVARS.FRAME_SCALE) or manager.DEFAULTS.FRAME_SCALE)
        end,
        setFunc = function(value)
            manager.SAVEVARS.FRAME_SCALE = zo_clamp(zo_round(tonumber(value) or manager.DEFAULTS.FRAME_SCALE), 50, 200)
            manager:ApplySavedSettings(true, false)
        end,
    }
    options[#options + 1] = {
        type = "slider",
        name = "Horizontal position",
        tooltip = "Moves the group-frame container left or right. The value is clamped so the frame remains on screen.",
        min = 0,
        max = rootWidth,
        step = 1,
        default = manager.DEFAULTS.FRAME_CONTAINER_BASE_OFFSET_X,
        getFunc = function()
            return zo_round(tonumber(manager.SAVEVARS.FRAME_CONTAINER_BASE_OFFSET_X) or manager.DEFAULTS.FRAME_CONTAINER_BASE_OFFSET_X)
        end,
        setFunc = function(value)
            manager.SAVEVARS.FRAME_CONTAINER_BASE_OFFSET_X = zo_round(tonumber(value) or manager.DEFAULTS.FRAME_CONTAINER_BASE_OFFSET_X)
            manager:ApplySavedSettings(false, false)
        end,
    }
    options[#options + 1] = {
        type = "slider",
        name = "Vertical position",
        tooltip = "Moves the group-frame container up or down. The value is clamped so the frame remains on screen.",
        min = 0,
        max = rootHeight,
        step = 1,
        default = manager.DEFAULTS.FRAME_CONTAINER_BASE_OFFSET_Y,
        getFunc = function()
            return zo_round(tonumber(manager.SAVEVARS.FRAME_CONTAINER_BASE_OFFSET_Y) or manager.DEFAULTS.FRAME_CONTAINER_BASE_OFFSET_Y)
        end,
        setFunc = function(value)
            manager.SAVEVARS.FRAME_CONTAINER_BASE_OFFSET_Y = zo_round(tonumber(value) or manager.DEFAULTS.FRAME_CONTAINER_BASE_OFFSET_Y)
            manager:ApplySavedSettings(false, false)
        end,
    }
    options[#options + 1] = {
        type = "button",
        name = "Reset frame position",
        tooltip = "Returns the group-frame container to its default position without changing colors or scale.",
        func = function()
            manager.SAVEVARS.FRAME_CONTAINER_BASE_OFFSET_X = manager.DEFAULTS.FRAME_CONTAINER_BASE_OFFSET_X
            manager.SAVEVARS.FRAME_CONTAINER_BASE_OFFSET_Y = manager.DEFAULTS.FRAME_CONTAINER_BASE_OFFSET_Y
            manager:ApplySavedSettings(false, false)
        end,
    }

    options[#options + 1] = { type = "header", name = "Preview" }
    options[#options + 1] = {
        type = "checkbox",
        name = "Show layout preview",
        tooltip = "Shows 24 dummy player frames so you can see the exact size, position, scale, and one-window/two-window layout without joining a group.",
        default = manager.DEFAULTS.PREVIEW_MODE,
        getFunc = function()
            return manager.SAVEVARS.PREVIEW_MODE == true
        end,
        setFunc = function(value)
            manager.SAVEVARS.PREVIEW_MODE = value == true
            manager:ApplySavedSettings(true, false)
        end,
    }
    options[#options + 1] = {
        type = "checkbox",
        name = "Show my frame while solo",
        tooltip = "Shows your own frame when you are not grouped, making color, scale, and position changes easy to preview.",
        default = manager.DEFAULTS.SHOW_NOGROUP,
        getFunc = function()
            return manager.SAVEVARS.SHOW_NOGROUP
        end,
        setFunc = function(value)
            manager.SAVEVARS.SHOW_NOGROUP = value
            manager:ApplySavedSettings(true, true)
        end,
    }

    if BUI and BUI.SettingsBridge and BUI.SettingsBridge.AddGroupedSection then
        BUI.SettingsBridge.AddGroupedSection("BUI_BanditUI", {
            id = "MyUIAltGroupFramesSettings", name = "Group Frames", order = 16,
            options = options, nestedGroup = "Alternative Groupframes",
        })
    end
end)
