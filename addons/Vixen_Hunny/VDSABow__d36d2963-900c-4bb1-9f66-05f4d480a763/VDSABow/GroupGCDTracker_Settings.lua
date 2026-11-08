-- =============================================================================
-- GroupGCDTracker_Settings.lua  —  LibAddonMenu-2.0 panel (optional)
-- =============================================================================

local T = GroupGCDTracker
local D = T.DEFAULTS

local function Hdr(text, hex) return { type = "header", name = string.format("|c%s%s|r", hex, text) } end

local function Refresh() if T.RefreshUI then T:RefreshUI() end end

--- Checkbox bound to a setting key.
local function Check(key, name, tooltip, onChange)
    return {
        type = "checkbox", name = name, tooltip = tooltip, default = D[key],
        getFunc = function() return T.settings[key] end,
        setFunc = function(v) T.settings[key] = v; if onChange then onChange(v) end end,
    }
end

--- Slider bound to a setting key.
local function Slider(key, name, tooltip, min, max, step, onChange, decimals)
    return {
        type = "slider", name = name, tooltip = tooltip, default = D[key],
        min = min, max = max, step = step, decimals = decimals,
        getFunc = function() return T.settings[key] end,
        setFunc = function(v) T.settings[key] = v; if onChange then onChange(v) end end,
    }
end

--- Colour picker bound to an RGBA setting key.
local function Color(key, name, tooltip)
    return {
        type = "colorpicker", name = name, tooltip = tooltip,
        getFunc = function() return unpack(T.settings[key]) end,
        setFunc = function(r, g, b, a) T.settings[key] = { r, g, b, a or 1 }; Refresh() end,
        default = { r = D[key][1], g = D[key][2], b = D[key][3], a = D[key][4] },
    }
end

function T:BuildSettingsPanel()
    local LAM = LibAddonMenu2
    if not LAM then return end
    local S = self.settings
    local H = self.HEX

    local panel = {
        type = "panel",
        name = self.NAME,
        displayName = string.format("|c%sGroup|r |c%sGCD|r |c%sTracker|r", H.BLUE, H.PINK, H.WHITE),
        author = "",
        version = self.VERSION,
        slashCommand = "/ggcdt",
        registerForRefresh = true,
        registerForDefaults = true,
        resetFunc = function() self:ResetSettings() end,
    }

    local options = {
        Hdr("General", H.BLUE),
        Check("enabled",   "Enable tracking", "Master on / off switch.", Refresh),
        Check("trackSelf", "Track yourself",  "Include your own casts."),
        Slider("gcdDurationMs", "GCD length (ms)", "Standard ESO GCD is 1000 ms.", 500, 2000, 50),

        Hdr("Proximity Detonation", H.PINK),
        Check("trackProximityDet", "Track detonations", "Show a countdown while a detonation is armed."),
        {
            type = "editbox",
            name = "Ability names",
            tooltip = "Comma-separated, exact in-game names. All morphs share the base name.",
            isMultiline = true,
            default = "Proximity Detonation",
            getFunc = function()
                local list = {}
                for n in pairs(S.proxDetAbilityNames) do list[#list + 1] = n end
                table.sort(list)
                return table.concat(list, ", ")
            end,
            setFunc = function(v)
                local set = {}
                for chunk in v:gmatch("[^,]+") do
                    local n = chunk:match("^%s*(.-)%s*$")
                    if n ~= "" then set[n] = true end
                end
                S.proxDetAbilityNames = set
            end,
        },
        Slider("proxDetDefaultDurationMs", "Fallback duration (ms)",
            "Used when the buff timer can't be read (e.g. a group member out of range).",
            1000, 30000, 500),

        Hdr("HUD", H.BLUE),
        Check("showUI",        "Show HUD",            "Also toggled with /ggcdui.", Refresh),
        Check("hideInMenus",   "Hide in menus",       "Only show the HUD during gameplay.", Refresh),
        Check("lockPosition",  "Lock position",       "Prevent the HUD from being dragged.", Refresh),
        Check("showHeader",    "Show title & column headers", nil, Refresh),
        Check("showRoleIcons", "Show role icons",     nil, Refresh),
        Check("sortByRole",    "Sort by role",        "Tanks, then healers, then DPS.", Refresh),
        Check("hideGCD",       "Hide GCD column",     "The detonation column widens to fill the space.", Refresh),
        Slider("uiOpacity", "Opacity", nil, 0.1, 1, 0.05, Refresh, 2),
        Slider("uiScale",   "Scale",   "Capped automatically so the HUD always fits on screen.", 0.5, 3, 0.05, Refresh, 2),
        Slider("fontSizeName",   "Name font size",   nil, 10, 32, 1, Refresh),
        Slider("fontSizeTimer",  "Timer font size",  nil, 10, 28, 1, Refresh),
        Slider("fontSizeHeader", "Title font size",  nil, 10, 40, 1, Refresh),
        {
            type = "slider", name = "Position X", min = 0, max = zo_round(GuiRoot:GetWidth()), step = 1,
            tooltip = "Pixels from the left edge. Dragging the HUD also updates this.",
            getFunc = function() return zo_round(S.uiX or 0) end,
            setFunc = function(v) self:MoveUITo(v, S.uiY or 0) end,
        },
        {
            type = "slider", name = "Position Y", min = 0, max = zo_round(GuiRoot:GetHeight()), step = 1,
            tooltip = "Pixels from the top edge. Dragging the HUD also updates this.",
            getFunc = function() return zo_round(S.uiY or 0) end,
            setFunc = function(v) self:MoveUITo(S.uiX or 0, v) end,
        },
        {
            type = "button", name = "Reset position",
            tooltip = "Centre the HUD on screen.",
            func = function() self:ResetUIPosition() end,
        },

        Hdr("Colours", H.PINK),
        Color("colorNameLive", "Member name"),
        Color("colorBarText",  "Timer text"),
        Color("colorGcdFull",  "GCD bar",            "Colour while plenty of the GCD remains."),
        Color("colorGcdLow",   "GCD bar (ending)",   "Blended in during the last 30%."),
        Color("colorDetFull",  "DET bar",            "Colour while plenty of time remains."),
        Color("colorDetHigh",  "DET bar (imminent)", "Blended in during the last 40%."),

        Hdr("Debug", H.WHITE),
        Check("showChatAlerts", "Chat alerts", "Print every tracked cast to chat."),
        Check("debugMode",      "Debug mode",  "Print detonation arming and load info."),
    }

    LAM:RegisterAddonPanel(self.NAME .. "_Panel", panel)
    LAM:RegisterOptionControls(self.NAME .. "_Panel", options)
end
