local ADK = AntiDK2
local M   = {}
ADK.Config.Settings = M

local W = ADK.WINDOWS

-- ── Helpers ──────────────────────────────────────────────────────────────────

-- Re-anchor and rescale a window from its saved vars. `key` is an ADK.WINDOWS key.
local function ApplyWindow(key)
    local win  = W[key]
    local ctrl = WINDOW_MANAGER:GetControlByName(win.control)
    if not ctrl then return end
    ctrl:ClearAnchors()
    ctrl:SetAnchor(win.anchor, GuiRoot, win.anchor, ADK.Get(win.x), ADK.Get(win.y))
    ctrl:SetScale(ADK.Get(win.scale))
end

-- Apply a font preset to every label a popup owns. UI modules expose ApplyFont.
local function ApplyFont(key, preset)
    local module = (key == "corrosive") and ADK.UI.Corrosive or ADK.UI.Stuns
    if module and module.ApplyFont then
        module.ApplyFont(ADK.PresetFont(W[key].fontGroup, preset))
    end
end

local function ResetLayout()
    for key, win in pairs(W) do
        ADK.savedVars[win.x]     = ADK.defaults[win.x]
        ADK.savedVars[win.y]     = ADK.defaults[win.y]
        ADK.savedVars[win.scale] = ADK.defaults[win.scale]
        ApplyWindow(key)
    end
    ADK.Msg("All positions and scales reset.")
end

-- Test buttons: show normally-hidden popups with dummy data
local function TestCorrosive()
    if not ADK.UI.Corrosive then return end
    ADK.UI.Corrosive.Show(2, false)
    ADK.UI.Corrosive.UpdateTimer("0:05")
end

local function TestAvoid()
    if not ADK.UI.Stuns then return end
    ADK.UI.Stuns.ShowAvoid("Shifting Standard")
    ADK.UI.Stuns.ShowAvoidWithRoll("Fossilize")
    ADK.UI.Stuns.ShowAvoidWithRoll("Shattering Rocks")
end

-- ── Option builders ──────────────────────────────────────────────────────────
-- Each returns a LibAddonMenu control table bound to a saved-var key.

local function Checkbox(key, name, tooltip)
    return {
        type    = "checkbox",
        name    = name,
        tooltip = tooltip,
        getFunc = function() return ADK.savedVars[key] end,
        setFunc = function(v) ADK.savedVars[key] = v end,
        default = ADK.defaults[key],
    }
end

local function Slider(key, name, min, max, tooltip, onChange)
    return {
        type    = "slider",
        name    = name,
        tooltip = tooltip,
        min     = min,
        max     = max,
        step    = 1,
        getFunc = function() return math.floor(ADK.savedVars[key]) end,
        setFunc = function(v)
            ADK.savedVars[key] = v
            if onChange then onChange() end
        end,
        default = ADK.defaults[key],
    }
end

-- Scale is stored as a float but shown as x10 so the slider has integer steps.
local function ScaleSlider(winKey)
    local key = W[winKey].scale
    return {
        type    = "slider",
        name    = "Scale (x10)",
        tooltip = "10 = 1.0x, 20 = 2.0x, 5 = 0.5x",
        min     = 5,
        max     = 30,
        step    = 1,
        getFunc = function() return math.floor(ADK.savedVars[key] * 10 + 0.5) end,
        setFunc = function(v)
            ADK.savedVars[key] = v / 10
            ApplyWindow(winKey)
        end,
        default = math.floor(ADK.defaults[key] * 10 + 0.5),
    }
end

local function FontDropdown(winKey, tooltip)
    local key = W[winKey].font
    return {
        type    = "dropdown",
        name    = "Font Size",
        tooltip = tooltip,
        choices = ADK.FONT_PRESETS,
        getFunc = function() return ADK.savedVars[key] end,
        setFunc = function(v)
            ADK.savedVars[key] = v
            ApplyFont(winKey, v)
        end,
        default = ADK.defaults[key],
    }
end

local function Button(name, tooltip, func)
    return { type = "button", name = name, tooltip = tooltip, width = "full", func = func }
end

local function Header(name)
    return { type = "header", name = name, width = "full" }
end

-- ── Panel ────────────────────────────────────────────────────────────────────

function M.Init()
    local LAM = LibAddonMenu2
    if not LAM then
        ADK.Msg("LibAddonMenu-2.0 not found; settings panel unavailable.")
        return
    end

    local c = ADK.COLORS
    local panelData = {
        type                = "panel",
        name                = ADK.displayName,
        displayName         = ADK.Colorize(c.LIGHT_BLUE, "Anti") .. " "
                           .. ADK.Colorize(c.PINK, "DK") .. " "
                           .. ADK.Colorize(c.WHITE, "2.0"),
        author              = ADK.Colorize(c.PINK, ADK.author),
        version             = ADK.version,
        slashCommand        = ADK.slashCommand,
        registerForRefresh  = true,
        registerForDefaults = true,
    }

    local function ApplyMain()      ApplyWindow("main")      end
    local function ApplyCorrosive() ApplyWindow("corrosive") end
    local function ApplyAvoid()     ApplyWindow("avoid")     end

    local opts = {
        Header("Tracking"),
        Checkbox("trackCorrosive",        "Corrosive Armor (center popup)", "Show popup when Corrosive Armor DoT hits you."),
        Checkbox("trackWings",            "Wing Buffet",                    "Track enemy players that Wing Buffet you."),
        Checkbox("trackMoltenWhip",       "Molten Whip stacks",             "Count Molten Whip hits on you."),
        Checkbox("trackPowerLash",        "Power Lash stacks",              "Count Power Lash hits on you."),
        Checkbox("trackShatteringRocks",  "Shattering Rocks - AVOID"),
        Checkbox("trackFossilize",        "Fossilize - AVOID"),
        Checkbox("trackShiftingStandard", "Shifting Standard - AVOID"),

        Header("Timing"),
        Slider("corrosiveFadeDelay", "Corrosive popup fade (seconds)",      1, 8,  "Seconds after the last DoT tick before the popup hides."),
        Slider("avoidFadeDelay",     "AVOID popup duration (seconds)",      1, 5),
        Slider("wingsCombatTimeout", "Wing Buffet target timeout (seconds)", 2, 30, "Remove a target from the list after this many seconds."),

        Header("Main Panel"),
        Slider("mainPanelX", "Position X", 0, 2560, "Pixels from the left edge of the screen.", ApplyMain),
        Slider("mainPanelY", "Position Y", 0, 1440, "Pixels from the top edge of the screen.",  ApplyMain),
        ScaleSlider("main"),

        Header("Corrosive Armor Popup"),
        Slider("corrosivePopupX", "Position X (from screen center)", -960, 960, "Negative = left of center, positive = right of center.", ApplyCorrosive),
        Slider("corrosivePopupY", "Position Y (from screen center)", -540, 540, "Negative = above center, positive = below center.",     ApplyCorrosive),
        ScaleSlider("corrosive"),
        FontDropdown("corrosive", "Font size for the Corrosive Armor popup text."),
        Button("Test: Show Corrosive Popup", "Preview the Corrosive Armor popup.", TestCorrosive),

        Header("AVOID Popups (Stuns + Standard)"),
        Slider("avoidPopupX", "Position X (from screen center)", -960, 960, nil, ApplyAvoid),
        Slider("avoidPopupY", "Position Y (from screen center)", -540, 540, nil, ApplyAvoid),
        ScaleSlider("avoid"),
        FontDropdown("avoid", "Font size for the AVOID popup text."),
        Button("Test: Show AVOID Popups", "Preview all three AVOID messages at once.", TestAvoid),

        Header("Reset"),
        Button("Reset All Positions and Scales", "Move all windows to default positions and reset scale to 1.0.", ResetLayout),
    }

    LAM:RegisterAddonPanel("AntiDK2_Panel", panelData)
    LAM:RegisterOptionControls("AntiDK2_Panel", opts)
end
