-- Settings panel via LibAddonMenu-2.0 (LAM2).
--
-- Written the same way as Bloom HPS, whose settings persist on this client:
-- every control reads and writes saved data directly, sliders store their
-- 0-1 values as-is, and colors are stored as hex text.
--
-- Console notes: LAM2 menus can be shown by LibGamepad (as native gamepad
-- options) or LibHarvensAddonSettings, depending on what's installed.
--   * LibGamepad passes slider values as text ("0.35") and has no color
--     picker, so values are converted before saving and the custom tint is a
--     hex text box
--   * a dropdown whose current value isn't in its list crashes the
--     LibHarvensAddonSettings panel, so every getFunc returns a valid value,
--     and dropdown defaults are display names on console
--   * "refresh" is off on console: it pushed each setting's value into reused
--     slider controls
local VGS = VGS

local PANEL_ID = "VixensGamedpadSceneSettings"

local PRESETS = {
    { name = "Natural",   hex = "FFFFFF" },
    { name = "Bubblegum", hex = "FFD9FF" },
    { name = "Lavender",  hex = "CCBFFF" },
    { name = "Peach",     hex = "FFEBCC" },
    { name = "Rose noir", hex = "B3738C" },
}

local function IsConsole()
    return type(IsConsoleUI) == "function" and IsConsoleUI()
end

function VGS.RegisterSettings()
    local LAM = LibAddonMenu2
    if type(LAM) ~= "table" or type(LAM.RegisterAddonPanel) ~= "function" then
        d("[Vixen's Gamepad Scene] LibAddonMenu-2.0 is missing, so there's no settings menu.")
        return
    end

    local sv, def = VGS.sv, VGS.defaults
    local console = IsConsole()

    -- Write straight into saved data, note it for /vgslog, redraw.
    -- Runs inside the settings menu's code, so nothing here may throw.
    local function set(key, value)
        sv[key] = value
        VGS.Try("settings log", VGS.LogWrite, key, value, "saved")
        VGS.ApplyAll()
    end

    -- Defaults button: restore every setting (keeps the load counter).
    local function ResetAll()
        for key, value in pairs(def) do
            sv[key] = value
        end
        VGS.LogWrite("all settings", "defaults", "reset")
        VGS.ApplyAll()
    end

    LAM:RegisterAddonPanel(PANEL_ID, {
        type = "panel",
        name = VGS.displayName,
        displayName = VGS.displayName,
        author = "Vixen",
        version = "1.0.0",
        slashCommand = "/vgs",
        registerForDefaults = true,
        registerForRefresh = true,
        resetFunc = ResetAll,
    })

    local options = {}
    local function add(option) options[#options + 1] = option end

    -- Console guard against stale writes. LibGamepad attaches its "save on
    -- change" handler to pooled slider / list controls, and the game moves
    -- those controls itself when the options list is rebuilt (e.g. when the
    -- menu closes); that saved values nobody chose, such as max opacity. A
    -- player on a gamepad can only move a slider one step, or a list one item,
    -- at a time, so on console any bigger jump is treated as stale and ignored.
    -- (On PC a slider can be dragged and a dropdown can jump, so no guard.)
    local function IsOneStep(old, new, step)
        if not console then return true end
        old = tonumber(old)
        if not old then return true end
        return math.abs(new - old) <= step * 1.5 + 1e-6
    end

    local function IsNeighbourItem(values, old, new)
        if not console then return true end
        local oldIndex, newIndex
        for i, v in ipairs(values) do
            if v == old then oldIndex = i end
            if v == new then newIndex = i end
        end
        if not (oldIndex and newIndex) then return true end
        local distance = math.abs(oldIndex - newIndex)
        return distance <= 1 or distance == #values - 1 -- lists wrap around
    end

    -- Dropdown default: PC LAM2 wants the value, console wants the name.
    local function dropdownDefault(names, values, value)
        if not console then return value end
        for i, v in ipairs(values) do
            if v == value then return names[i] end
        end
        return names[1]
    end

    local function checkbox(name, key, tooltip)
        add({
            type = "checkbox", name = name, tooltip = tooltip,
            getFunc = function() return sv[key] end,
            setFunc = function(value)
                -- may arrive as text from the gamepad options screen
                set(key, value == true or value == "true" or value == 1 or value == "1")
            end,
            default = def[key],
        })
    end

    -- Same shape as Bloom HPS's sliders: the stored 0-1 value. LibGamepad
    -- hands the value over as formatted text ("0.35"), so convert it to a
    -- number (and keep it in range) before saving.
    local function slider(name, key, min, max, step, tooltip)
        add({
            type = "slider", name = name, tooltip = tooltip,
            min = min, max = max, step = step,
            decimals = step < 0.01 and 3 or (step < 1 and 2 or 0),
            getFunc = function() return tonumber(sv[key]) or def[key] end,
            setFunc = function(value)
                local n = tonumber(value)
                if not n then return end
                n = math.max(min, math.min(max, n))
                local old = tonumber(sv[key])
                if old == n then return end
                if not IsOneStep(old, n, step) then
                    VGS.LogWrite(key, n, "BLOCKED: jump from " .. tostring(old))
                    return
                end
                set(key, n)
            end,
            default = def[key],
        })
    end

    -- Status (before the first header, so it sits on the main page on console,
    -- where headers become sub-menus) ----------------------------------------
    add({ type = "description", title = "Status", text = function() return VGS.GetStatus() end })
    add({
        type = "button", name = "Save now",
        tooltip = "Asks the game to save your settings right away (also /vgssave).",
        func = function() VGS.SaveNow() end,
    })
    -- No "Display test" button here on purpose: the gamepad settings menu
    -- (LibGamepad) can fire button callbacks by itself when it closes, which
    -- switched the test on and painted every panel magenta (it looked like
    -- max opacity). The test is only available as /vgstest.

    -- Theme ------------------------------------------------------------------
    add({ type = "header", name = "Theme" })
    checkbox("Enable theme", "enabled")

    -- Pink Hearts (the default) first, then "My class", then every theme.
    local themeNames, themeValues, validTheme = {}, {}, {}
    local function addTheme(name, value)
        themeNames[#themeNames + 1] = name
        themeValues[#themeValues + 1] = value
        validTheme[value] = true
    end
    for _, theme in ipairs(VGS.THEMES) do
        if theme.id == def.theme then addTheme(theme.group .. ": " .. theme.name, theme.id) end
    end
    addTheme("My class (auto)", "class")
    for _, theme in ipairs(VGS.THEMES) do
        if theme.id ~= def.theme then addTheme(theme.group .. ": " .. theme.name, theme.id) end
    end

    add({
        type = "dropdown", name = "Theme",
        tooltip = "Cute, cool or class themes. \"My class\" follows the character you're playing.",
        choices = themeNames, choicesValues = themeValues,
        getFunc = function() return validTheme[sv.theme] and sv.theme or def.theme end,
        setFunc = function(value)
            if not validTheme[value] or value == sv.theme then return end
            if not IsNeighbourItem(themeValues, sv.theme, value) then
                VGS.LogWrite("theme", value, "BLOCKED: jump from " .. tostring(sv.theme))
                return
            end
            set("theme", value)
        end,
        default = dropdownDefault(themeNames, themeValues, def.theme),
    })

    checkbox("Theme every gamepad screen", "allScenes",
        "Also theme the backgrounds of other gamepad screens, not just the main menu panels.")
    checkbox("Theme the button bar", "keybindStrip",
        "The bar along the bottom with Select / Back / Text Chat and your name and location.")
    add({
        type = "button", name = "Scan this screen",
        tooltip = "Themes the current screen now and lists what was found in chat (also /vgsscan).",
        func = function() VGS.ScanCurrentScene() end,
    })

    -- Drawing style: PC only. Console always uses pixel art (images draw as
    -- flat blocks there), and leaving the option out means the menu's stale
    -- writes on close can't switch it.
    local styleNames = { "Pixel art", "Images" }
    local styleValues = { "shapes", "textures" }
    local validStyle = { shapes = true, textures = true }
    if not console then add({
        type = "dropdown", name = "Drawing style",
        tooltip = "Pixel art: drawn from blocks, works everywhere (recommended on console). Images: smooth artwork for each theme, only if your game can show add-on images; otherwise they appear as flat blocks.",
        choices = styleNames, choicesValues = styleValues,
        getFunc = function() return validStyle[sv.style] and sv.style or "shapes" end,
        setFunc = function(value)
            if not validStyle[value] or value == sv.style then return end
            if not IsNeighbourItem(styleValues, sv.style, value) then
                VGS.LogWrite("style", value, "BLOCKED: jump from " .. tostring(sv.style))
                return
            end
            set("style", value)
        end,
        default = dropdownDefault(styleNames, styleValues, "shapes"),
    }) end

    -- Tint presets (hex text, like Bloom HPS's colors). "Custom" (0) shows
    -- when the color picker's tint matches no preset.
    local presetNames, presetValues = {}, {}
    for i, p in ipairs(PRESETS) do
        presetNames[i], presetValues[i] = p.name, i
    end
    presetNames[#presetNames + 1], presetValues[#presetValues + 1] = "Custom", 0

    local function CurrentPreset()
        local current = (sv.tintHex or ""):upper()
        for i, p in ipairs(PRESETS) do
            if p.hex == current then return i end
        end
        return 0
    end

    add({
        type = "dropdown", name = "Tint preset",
        tooltip = "Tints the whole theme. Natural keeps each theme's own colors.",
        choices = presetNames, choicesValues = presetValues,
        getFunc = CurrentPreset,
        setFunc = function(value)
            local index = tonumber(value) or 0
            local p = PRESETS[index]
            if not p then return end
            local old = CurrentPreset()
            if old == index then return end
            if not IsNeighbourItem(presetValues, old, index) then
                VGS.LogWrite("tint", p.hex, "BLOCKED: jump from preset " .. tostring(old))
                return
            end
            set("tintHex", p.hex)
        end,
        default = dropdownDefault(presetNames, presetValues, 1),
    })

    -- Custom tint as a hex text box, like Bloom HPS's colors: LibGamepad (the
    -- gamepad options screen) has no color picker, but it does have text boxes.
    add({
        type = "editbox", name = "Custom tint (hex)",
        tooltip = "6-digit hex color, e.g. FFD9FF. FFFFFF keeps each theme's own colors.",
        getFunc = function() return sv.tintHex end,
        setFunc = function(value)
            local hex = type(value) == "string" and value:match("^%s*#?(%x%x%x%x%x%x)%s*$")
            if hex then set("tintHex", hex:upper()) end
        end,
        default = def.tintHex,
    })

    -- Background --------------------------------------------------------------
    add({ type = "header", name = "Background" })
    slider("Background wash opacity", "washAlpha", 0, 1, 0.05)
    slider("Particle opacity", "heartsAlpha", 0, 1, 0.05)
    slider("Particle size", "heartScale", 0.5, 2, 0.1)
    checkbox("Animate particles", "floating",
        "Particles drift, fall, twinkle or flicker while a menu is open, depending on the theme.")
    slider("Animation speed", "floatSpeed", 0.005, 0.1, 0.005)

    -- Decorations -------------------------------------------------------------
    add({ type = "header", name = "Decorations" })
    checkbox("Corner emblem", "showCorner")
    slider("Corner emblem opacity", "cornerAlpha", 0, 1, 0.05)
    checkbox("Side divider", "showDivider")
    checkbox("Top ribbon", "showRibbon")

    LAM:RegisterOptionControls(PANEL_ID, options)
end
