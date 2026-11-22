-- Settings panel (console-friendly) via LibHarvensAddonSettings, if installed.
local VGS = VGS

local PRESETS = {
    { name = "Natural pink", r = 1.00, g = 1.00, b = 1.00 },
    { name = "Bubblegum",    r = 1.00, g = 0.85, b = 1.00 },
    { name = "Lavender",     r = 0.80, g = 0.75, b = 1.00 },
    { name = "Peach",        r = 1.00, g = 0.92, b = 0.80 },
    { name = "Rose noir",    r = 0.70, g = 0.45, b = 0.55 },
}

function VGS.RegisterSettings()
    local LHAS = LibHarvensAddonSettings
    if type(LHAS) ~= "table" or type(LHAS.AddAddon) ~= "function" then return end

    local sv, def = VGS.sv, VGS.defaults
    local panel = LHAS:AddAddon(VGS.displayName, { allowDefaults = true, allowRefresh = true })
    if not panel then return end

    -- Every setting change goes through here: redraw, then save.
    local function apply()
        VGS.ApplyAll()
        VGS.RequestSave()
    end

    local function checkbox(label, key, tooltip)
        panel:AddSetting({
            type = LHAS.ST_CHECKBOX, label = label, tooltip = tooltip,
            getFunction = function() return sv[key] end,
            setFunction = function(v) sv[key] = v; apply() end,
            default = def[key],
        })
    end

    local function slider(label, key, min, max, step, tooltip)
        panel:AddSetting({
            type = LHAS.ST_SLIDER, label = label, tooltip = tooltip,
            min = min, max = max, step = step, format = "%.2f",
            getFunction = function() return sv[key] end,
            setFunction = function(v) sv[key] = v; apply() end,
            default = def[key],
        })
    end

    panel:AddSetting({ type = LHAS.ST_SECTION, label = "Status" })
    panel:AddSetting({ type = LHAS.ST_LABEL, label = function() return VGS.GetStatus() end })
    panel:AddSetting({
        type = LHAS.ST_BUTTON, label = "Display test", buttonText = "Toggle test",
        tooltip = "Shows four test squares and paints the menu panels magenta. Press again to turn off.",
        clickHandler = function() VGS.ToggleTest() end,
    })

    panel:AddSetting({ type = LHAS.ST_SECTION, label = "Theme" })
    checkbox("Enable theme", "enabled")

    -- Theme picker: "My class" first, then every theme grouped by kind.
    local themeItems = { { name = "My class (auto)", data = "class" } }
    for _, theme in ipairs(VGS.THEMES) do
        themeItems[#themeItems + 1] = { name = theme.group .. ": " .. theme.name, data = theme.id }
    end
    local defaultThemeItem
    for _, item in ipairs(themeItems) do
        if item.data == def.theme then defaultThemeItem = item end
    end
    panel:AddSetting({
        type = LHAS.ST_DROPDOWN, label = "Theme",
        tooltip = "Cute, cool or class themes. \"My class\" follows the character you're playing.",
        items = themeItems,
        getFunction = function()
            for _, item in ipairs(themeItems) do
                if item.data == sv.theme then return item end
            end
            return defaultThemeItem
        end,
        setFunction = function(_, _, itemData)
            if not itemData then return end
            sv.theme = itemData.data
            apply()
        end,
        default = defaultThemeItem.name,
    })
    checkbox("Theme every gamepad screen", "allScenes",
        "Also theme the backgrounds of other gamepad screens and dialogs, not just the main menu panels.")
    checkbox("Theme the button bar", "keybindStrip",
        "The bar along the bottom with Select / Back / Text Chat and your name and location.")
    panel:AddSetting({
        type = LHAS.ST_BUTTON, label = "Scan this screen", buttonText = "Scan",
        tooltip = "Themes the current screen now and lists what was found in chat (also /vgsscan).",
        clickHandler = function() VGS.ScanCurrentScene() end,
    })

    local STYLES = {
        { name = "Auto", data = "auto" },
        { name = "Images", data = "textures" },
        { name = "Pixel art", data = "shapes" },
    }
    panel:AddSetting({
        type = LHAS.ST_DROPDOWN, label = "Drawing style",
        tooltip = "Images: smooth artwork for each theme. Pixel art: drawn from blocks, works everywhere. Auto: images, switching to pixel art if they can't load.",
        items = STYLES,
        -- Return the list entry itself: the library matches tables by .data,
        -- and crashes if the current value isn't found in the list.
        getFunction = function()
            for _, s in ipairs(STYLES) do
                if s.data == sv.style then return s end
            end
            return STYLES[1]
        end,
        setFunction = function(_, _, itemData)
            if not itemData then return end
            sv.style = itemData.data
            VGS.texturesFailed = false -- give images another try
            apply()
        end,
        default = STYLES[1].name,
    })

    -- "Custom" is a real entry so a color-picker tint (e.g. 0.996) that
    -- matches no preset still has something to show.
    local presetItems = {}
    for i, p in ipairs(PRESETS) do presetItems[i] = { name = p.name, data = i } end
    local customItem = { name = "Custom", data = 0 }
    presetItems[#presetItems + 1] = customItem

    local function near(a, b) return math.abs(a - b) < 0.01 end
    panel:AddSetting({
        type = LHAS.ST_DROPDOWN, label = "Tint preset",
        items = presetItems,
        getFunction = function()
            for i, p in ipairs(PRESETS) do
                if near(p.r, sv.tint.r) and near(p.g, sv.tint.g) and near(p.b, sv.tint.b) then
                    return presetItems[i]
                end
            end
            return customItem
        end,
        setFunction = function(_, _, itemData)
            local p = itemData and PRESETS[itemData.data]
            if not p then return end -- "Custom": keep the picker's color
            sv.tint = { r = p.r, g = p.g, b = p.b }
            apply()
        end,
        default = PRESETS[1].name,
    })
    panel:AddSetting({
        type = LHAS.ST_COLOR, label = "Custom tint",
        getFunction = function() return sv.tint.r, sv.tint.g, sv.tint.b end,
        setFunction = function(r, g, b) sv.tint = { r = r, g = g, b = b }; apply() end,
        default = { def.tint.r, def.tint.g, def.tint.b },
    })

    panel:AddSetting({ type = LHAS.ST_SECTION, label = "Background" })
    slider("Background wash opacity", "washAlpha", 0, 1, 0.05)
    slider("Particle opacity", "heartsAlpha", 0, 1, 0.05)
    slider("Particle size", "heartScale", 0.5, 2, 0.1)
    checkbox("Animate particles", "floating", "Particles drift, fall, twinkle or flicker while a menu is open, depending on the theme.")
    slider("Float speed", "floatSpeed", 0.005, 0.1, 0.005)

    panel:AddSetting({ type = LHAS.ST_SECTION, label = "Decorations" })
    checkbox("Corner emblem", "showCorner")
    slider("Corner emblem opacity", "cornerAlpha", 0, 1, 0.05)
    checkbox("Side divider", "showDivider")
    checkbox("Top ribbon", "showRibbon")
end
