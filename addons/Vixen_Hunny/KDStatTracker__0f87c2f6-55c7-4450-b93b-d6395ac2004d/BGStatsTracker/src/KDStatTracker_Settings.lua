-- KDStatTracker_Settings.lua
-- One list of controls, rendered with LibAddonMenu-2.0 on PC or
-- LibHarvensAddonSettings on console / when LAM is missing.

local KDST = KDStatTracker

local function S() return KDST.settings end
local function RefreshHUD() if KDST.HUD then KDST.HUD:ApplyStyle() end end
-- Position sliders: move the HUD and briefly show it on top of the menu so
-- the change is visible (the HUD is otherwise hidden while menus are open).
local function MoveHUD()
    if not KDST.HUD then return end
    KDST.HUD:ApplyPosition()
    KDST.HUD:Preview()
end

local function BuildControls()
    local D = KDST.settingDefaults
    local function Check(key, label, tooltip, onChange)
        return {
            kind = "checkbox", label = label, tooltip = tooltip, default = D[key],
            get = function() return S()[key] end,
            set = function(v) S()[key] = v; if onChange then onChange(v) end end,
        }
    end
    local function Slider(key, label, tooltip, min, max, step, decimals, onChange)
        return {
            kind = "slider", label = label, tooltip = tooltip, default = D[key],
            min = min, max = max, step = step, decimals = decimals or 0,
            get = function() return S()[key] end,
            set = function(v) S()[key] = v; if onChange then onChange(v) end end,
        }
    end
    local function Button(label, tooltip, onClick, warning)
        return { kind = "button", label = label, buttonText = label, tooltip = tooltip, onClick = onClick, warning = warning }
    end

    return {
        { kind = "section", label = "Stats Window" },
        Button("Open Stats", "Open the stats dialog", function() KDST.OpenStatsDialog() end),

        { kind = "section", label = "HUD Tracker" },
        Check("showHUD", "Show HUD tracker", "Show the on-screen kill / death panel.", RefreshHUD),
        Check("hudPvPOnly", "Only show in PvP areas", "Hide the HUD outside battlegrounds, Cyrodiil and Imperial City.", RefreshHUD),
        Check("hudShowCharacter", "Show character totals", "Off: this session's numbers. On: lifetime numbers for this character.", RefreshHUD),
        Check("hudShowDetails", "Show favorite / nemesis skill", "Add the favorite killing skill and nemesis skill lines.", RefreshHUD),
        Check("lockHUD", "Lock position", "Prevent the HUD from being dragged.", RefreshHUD),
        Slider("x", "Horizontal position (X)", "Distance of the HUD from the left edge of the screen.", 0, zo_round(GuiRoot:GetWidth()), 1, 0, MoveHUD),
        Slider("y", "Vertical position (Y)", "Distance of the HUD from the top edge of the screen.", 0, zo_round(GuiRoot:GetHeight()), 1, 0, MoveHUD),
        Slider("fontSize", "Font size", nil, 12, 40, 1, 0, RefreshHUD),
        Slider("scale", "Scale", nil, 0.5, 2.5, 0.05, 2, RefreshHUD),
        {
            kind = "color", label = "Text color", tooltip = "Base color of the HUD text.",
            default = { ZO_ColorDef:New(D.fontColor):UnpackRGBA() },
            get = function() return ZO_ColorDef:New(KDST.ValidHex(S().fontColor)):UnpackRGBA() end,
            set = function(r, g, b) S().fontColor = ZO_ColorDef:New(r, g, b, 1):ToHex(); RefreshHUD() end,
        },
        Button("Reset HUD Position", "Move the HUD back to its default position", function() KDST.HUD:ResetPosition() end),

        { kind = "section", label = "Announcer" },
        Check("showBanners", "Kill banners", "Show Double Kill, Killing Spree and similar banners."),
        Check("playSounds", "Banner sounds", "Play a sound with each banner."),
        Check("showMatchSummary", "Match summary dialog", "Show a summary dialog when a battleground ends."),
        Check("chatKills", "Kill / death chat messages", "Print each kill and death to chat."),
        Slider("multiKillWindow", "Multi-kill window (seconds)", "Kills within this many seconds of each other chain into a multi-kill.", 2, 15, 1, 0),

        { kind = "section", label = "Tracking" },
        Check("trackOnlyPvP", "Only track in PvP areas", "Only count kills and deaths in battlegrounds, Cyrodiil and Imperial City."),
        Check("playersOnly", "Only count player kills", "Ignore NPC kills (guards, monsters) outside battlegrounds."),

        { kind = "section", label = "Data" },
        Button("Reset Session", "Clear this play session's numbers", function() KDST.ShowResetDialog("session") end),
        Button("Reset Character", "Clear all saved stats for this character", function() KDST.ShowResetDialog("character") end, "Asks for confirmation."),
        Button("Reset Everything", "Clear saved stats for every character", function() KDST.ShowResetDialog("all") end, "Asks for confirmation."),
    }
end

-------------------------------------------------------------------------------
-- LibAddonMenu-2.0
-------------------------------------------------------------------------------
local LAM_TYPES = { section = "header", checkbox = "checkbox", slider = "slider", button = "button", color = "colorpicker" }

local function RegisterLAM(controls)
    local LAM = LibAddonMenu2
    local panelName = "KDStatTrackerSettingsPanel"
    KDST.ui.lamPanel = LAM:RegisterAddonPanel(panelName, {
        type = "panel",
        name = KDST.displayName,
        displayName = KDST.Color(KDST.COLORS.accent, KDST.displayName),
        author = KDST.author,
        version = KDST.version,
        slashCommand = "/kdsettings",
        registerForRefresh = true,
        registerForDefaults = true,
    })

    local options = {}
    for _, c in ipairs(controls) do
        local o = { type = LAM_TYPES[c.kind], name = c.label, tooltip = c.tooltip }
        if c.kind == "checkbox" or c.kind == "slider" or c.kind == "color" then
            o.getFunc, o.setFunc = c.get, c.set
            o.default = c.kind == "color" and { r = c.default[1], g = c.default[2], b = c.default[3], a = c.default[4] } or c.default
        end
        if c.kind == "slider" then
            o.min, o.max, o.step, o.decimals = c.min, c.max, c.step, c.decimals
        elseif c.kind == "button" then
            o.func, o.warning, o.width = c.onClick, c.warning, "half"
        end
        options[#options + 1] = o
    end
    LAM:RegisterOptionControls(panelName, options)
    return "LibAddonMenu-2.0"
end

-------------------------------------------------------------------------------
-- LibHarvensAddonSettings
-------------------------------------------------------------------------------
local function RegisterHarvens(controls)
    local LHAS = LibHarvensAddonSettings
    local panel = LHAS:AddAddon(KDST.displayName, { allowDefaults = true, allowRefresh = true })
    KDST.ui.lhasPanel = panel

    local types = {
        section = LHAS.ST_SECTION, checkbox = LHAS.ST_CHECKBOX, slider = LHAS.ST_SLIDER,
        button = LHAS.ST_BUTTON, color = LHAS.ST_COLOR,
    }
    for _, c in ipairs(controls) do
        local t = types[c.kind]
        if t then
            local setting = { type = t, label = c.label, tooltip = c.tooltip }
            if c.kind == "checkbox" or c.kind == "slider" or c.kind == "color" then
                setting.getFunction, setting.setFunction, setting.default = c.get, c.set, c.default
            end
            if c.kind == "slider" then
                setting.min, setting.max, setting.step = c.min, c.max, c.step
                setting.format = c.decimals > 0 and ("%." .. c.decimals .. "f") or "%d"
            elseif c.kind == "button" then
                setting.buttonText, setting.clickHandler = c.buttonText, c.onClick
            end
            panel:AddSetting(setting)
        end
    end
    return "LibHarvensAddonSettings"
end

-------------------------------------------------------------------------------
local function HasLAM()
    if KDST.IsConsole() then return false end
    return type(LibAddonMenu2) == "table" and type(LibAddonMenu2.RegisterAddonPanel) == "function"
end

local function HasHarvens()
    return type(LibHarvensAddonSettings) == "table" and type(LibHarvensAddonSettings.AddAddon) == "function"
end

function KDST.RegisterSettings()
    local renderer = (HasLAM() and RegisterLAM) or (HasHarvens() and RegisterHarvens) or nil
    if not renderer then return nil end
    local ok, result = pcall(renderer, BuildControls())
    if not ok then
        KDST.Print("Settings menu failed to load: " .. tostring(result))
        return nil
    end
    KDST.settingsLibrary = result
    return result
end

function KDST.OpenSettings()
    if KDST.settingsLibrary == "LibAddonMenu-2.0" and KDST.ui.lamPanel then
        LibAddonMenu2:OpenToPanel(KDST.ui.lamPanel)
    elseif KDST.settingsLibrary == "LibHarvensAddonSettings" then
        KDST.Print("Open Settings > Addons > " .. KDST.displayName .. ".")
    else
        KDST.Print("No settings library installed. Install LibAddonMenu-2.0 (PC) or LibHarvensAddonSettings (console).")
    end
end
