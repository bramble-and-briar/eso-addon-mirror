local O = OneCrosshair
O.Settings = {}
O.Settings.defaults = {
    preset = "dot", crosshairOpacity = O.Config.crosshairOpacity, hudOpacity = O.Config.hudOpacity,
    resources = true, gcd = true, visibility = "DYNAMIC",
    lowResource = true, shield = true,
    combatFeedback = true,
    resourceThickness = O.Config.resourceThickness, resourceLength = O.Config.resourceLength, resourceRadius = O.Config.resourceRadius,
}
function O.Settings.Load()
    local s = ZO_SavedVars:NewAccountWide("OneCrosshairSavedVariables", 1, nil, O.Settings.defaults)
    for key, default in pairs(O.Settings.defaults) do
        if type(s[key]) ~= type(default) then s[key] = default end
    end
    -- Release appearance is code-owned, independent of old account settings.
    for key, value in pairs(O.Config) do s[key] = value end
    s.criticalState, s.heavyChannel = nil, nil -- retired options; GCD is authoritative
    for key, bounds in pairs({ resourceThickness = {1,12}, resourceLength = {0,100}, resourceRadius = {20,100} }) do
        if s[key] ~= s[key] then s[key] = O.Settings.defaults[key] end
        s[key] = math.max(bounds[1], math.min(bounds[2], s[key]))
    end
    s.crosshairOpacity, s.hudOpacity = O.Clamp(s.crosshairOpacity), O.Clamp(s.hudOpacity)
    s.preset = O.PresetRegistry.Get(s.preset).id
    if not ({ ALWAYS = true, COMBAT_ONLY = true, DYNAMIC = true, OFF = true })[s.visibility] then
        s.visibility = "DYNAMIC"
    end
    return s
end
function O.Settings.Initialize(s)
    local LAM = LibAddonMenu2
    if not LAM then return end -- manifest dependency normally prevents this case
    local function text(key) return GetString(_G["SI_ONECROSSHAIR_" .. key]) end
    local panel = LAM:RegisterAddonPanel(O.name .. "Settings", {
        type = "panel", name = "OneCrosshair", displayName = "OneCrosshair", author = O.author,
        version = O.version, registerForRefresh = true, registerForDefaults = false,
    })
    local options = {}
    local function add(option) options[#options + 1] = option end
    local function header(key) add({ type = "header", name = text(key) }) end
    local function checkbox(key, label)
        add({ type = "checkbox", name = text(label), getFunc = function() return s[key] end,
            setFunc = function(value) s[key] = value; O.Preview.Refresh() end, width = "full" })
    end
    add({ type = "custom", width = "full", minHeight = 200, maxHeight = 200,
        createFunc = function(control) O.Preview.Initialize(control, s) end,
        refreshFunc = function() O.Preview.Refresh() end })
    header("CROSSHAIR")
    local choices, values = {}, {}
    for _, preset in ipairs(O.PresetRegistry.list) do
        choices[#choices + 1], values[#values + 1] = GetString(preset.name), preset.id
    end
    add({ type = "dropdown", name = text("PRESET"), choices = choices, choicesValues = values,
        getFunc = function() return s.preset end,
        setFunc = function(value) s.preset = value; O.Preview.Refresh() end })
    header("HUD")
    checkbox("resources", "RESOURCES")
    checkbox("gcd", "GCD")
    add({ type = "dropdown", name = text("VISIBILITY"),
        choices = { text("ALWAYS"), text("COMBAT_ONLY"), text("DYNAMIC"), text("OFF") },
        choicesValues = { "ALWAYS", "COMBAT_ONLY", "DYNAMIC", "OFF" },
        getFunc = function() return s.visibility end, setFunc = function(value) s.visibility = value; O.Preview.Refresh() end })
    header("EFFECTS")
    checkbox("lowResource", "LOW_RESOURCE")
    checkbox("shield", "SHIELD")
    checkbox("combatFeedback", "COMBAT_FEEDBACK")
    LAM:RegisterOptionControls(O.name .. "Settings", options)
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(opened)
        if opened == panel then O.Preview.Show(true) end
    end)
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(closed)
        if closed == panel then O.Preview.Show(false) end
    end)
end
