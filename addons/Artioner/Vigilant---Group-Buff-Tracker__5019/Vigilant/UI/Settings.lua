-- Entrada en Ajustes > Add-Ons (LibAddonMenu-2.0): aspecto del panel y qué bufos seguir.

local VG = Vigilant
local L = VG.L
local S = {}
VG.Settings = S

local PANEL_NAME = "VigilantOptions"
local CUSTOM_LIST = "VigilantCustomList"   -- referencia global que crea LibAddonMenu

function S.Open()
    LibAddonMenu2:OpenToPanel(S.panel)
end

local function Refresh()
    VG.Panel.Refresh()
end

-- Casilla enlazada a VG.sv[key].
local function Checkbox(key, name, tooltip)
    return {
        type = "checkbox",
        name = name,
        tooltip = tooltip,
        getFunc = function() return VG.sv[key] end,
        setFunc = function(v) VG.sv[key] = v; Refresh() end,
        default = VG.defaults[key],
    }
end

local function Slider(key, name, min, max, step, tooltip)
    return {
        type = "slider",
        name = name,
        tooltip = tooltip,
        min = min, max = max, step = step or 1,
        getFunc = function() return VG.sv[key] end,
        setFunc = function(v) VG.sv[key] = v; Refresh() end,
        default = VG.defaults[key],
    }
end

local function Dropdown(key, name, choices, values, tooltip)
    return {
        type = "dropdown",
        name = name,
        tooltip = tooltip,
        choices = choices,
        choicesValues = values,
        getFunc = function() return VG.sv[key] end,
        setFunc = function(v) VG.sv[key] = v; Refresh() end,
        default = VG.defaults[key],
    }
end

---------------------------------------------------------------------------
-- Bufos del catálogo
---------------------------------------------------------------------------
local function BuffCheckbox(b)
    return {
        type = "checkbox",
        name = zo_iconFormat(b.icon, 24, 24) .. " " .. b.name,
        getFunc = function() return VG.Catalog.IsTracked(b.key) end,
        setFunc = function(v) VG.Catalog.SetTracked(b.key, v) end,
        default = b.on or false,
    }
end

local function CategorySubmenus()
    local menus = {}
    for _, cat in ipairs(VG.Catalog.CATEGORIES) do
        local controls = {}
        for _, b in ipairs(VG.Catalog.BUFFS) do
            if b.cat == cat.key then controls[#controls + 1] = BuffCheckbox(b) end
        end
        menus[#menus + 1] = { type = "submenu", name = L[cat.label], controls = controls }
    end
    return menus
end

---------------------------------------------------------------------------
-- Otros bufos y procs (añadidos desde el catálogo de efectos)
---------------------------------------------------------------------------
local function CustomChoices()
    local choices, values = {}, {}
    local keys = VG.Catalog.CustomKeys()
    for i, entry in ipairs(VG.sv.custom) do
        choices[i] = VG.Catalog.CustomLabel(entry)
        values[i] = keys[i]
    end
    if #choices == 0 then
        choices[1], values[1] = L.CUSTOM_NONE, ""
    end
    return choices, values
end

-- Lo llama el catálogo al añadir o quitar uno. LibAddonMenu crea los controles la
-- primera vez que se abre el panel: hasta entonces el desplegable aún no existe.
function S.RefreshCustomList()
    local dropdown = _G[CUSTOM_LIST]
    if not dropdown then return end
    local choices, values = CustomChoices()
    dropdown:UpdateChoices(choices, values)
    S.selectedCustom = values[1]
    dropdown:UpdateValue()
end

local function CustomSubmenu()
    local choices, values = CustomChoices()
    S.selectedCustom = values[1]
    return {
        type = "submenu",
        name = L.H_CUSTOM,
        controls = {
            { type = "description", text = L.CUSTOM_DESC },
            {
                type = "button",
                name = L.BROWSE_BUTTON,
                tooltip = L.BROWSE_TIP,
                width = "half",
                func = function() VG.Browser.Open() end,
            },
            {
                type = "dropdown",
                name = L.CUSTOM_LIST,
                choices = choices,
                choicesValues = values,
                getFunc = function() return S.selectedCustom end,
                setFunc = function(v) S.selectedCustom = v end,
                reference = CUSTOM_LIST,
            },
            {
                type = "button",
                name = L.CUSTOM_REMOVE,
                width = "half",
                func = function()
                    if S.selectedCustom ~= "" then VG.Catalog.RemoveCustom(S.selectedCustom) end
                end,
            },
        },
    }
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
function S.Init()
    local LAM = LibAddonMenu2
    S.panel = LAM:RegisterAddonPanel(PANEL_NAME, {
        type = "panel",
        name = "Vigilant",
        displayName = VG.title .. " |cAAAAAA- " .. L.TAGLINE .. "|r",
        author = VG.author,
        version = VG.version,
        registerForRefresh = true,
        registerForDefaults = true,
    })

    local window = VG.sv.window
    local options = {
        { type = "description", text = L.SETTINGS_DESC },

        { type = "header", name = L.H_GENERAL },
        {
            type = "checkbox",
            name = L.ACCOUNT_WIDE,
            tooltip = L.ACCOUNT_WIDE_TIP,
            getFunc = VG.UsesAccountSettings,
            setFunc = VG.SetUseAccountSettings,
            requiresReload = true,
            default = true,
        },
        {
            type = "checkbox",
            name = L.SHOW_PANEL,
            getFunc = function() return window.shown end,
            setFunc = function(v) VG.Panel.SetShown(v) end,
            default = VG.defaults.window.shown,
        },
        {
            type = "checkbox",
            name = L.LOCK_PANEL,
            tooltip = L.LOCK_TIP,
            getFunc = function() return window.locked end,
            setFunc = function(v) VG.Panel.SetLocked(v) end,
            default = VG.defaults.window.locked,
        },
        Dropdown("layout", L.LAYOUT, { L.LAYOUT_GRID, L.LAYOUT_SUMMARY }, { "grid", "summary" }, L.LAYOUT_TIP),
        Checkbox("onlyInGroup", L.ONLY_GROUP, L.ONLY_GROUP_TIP),
        Checkbox("onlyInCombat", L.ONLY_COMBAT),
        {
            type = "button",
            name = L.RESET_POSITION,
            width = "half",
            func = function() VG.Panel.ResetPosition() end,
        },

        { type = "header", name = L.H_LOOK },
        Slider("nameWidth", L.NAME_WIDTH, VG.Panel.NAME_MIN, VG.Panel.NAME_MAX, 1),
        {
            type = "slider",
            name = L.BG_ALPHA,
            min = 0, max = 100, step = 5,
            getFunc = function() return zo_round(VG.sv.bgOpacity * 100) end,
            setFunc = function(v) VG.sv.bgOpacity = v / 100; Refresh() end,
            default = zo_round(VG.defaults.bgOpacity * 100),
        },
        Dropdown("nameFormat", L.NAME_FORMAT, { L.NAME_CHARACTER, L.NAME_ACCOUNT }, { "character", "account" }),
        Checkbox("showRoles", L.SHOW_ROLES),
        {
            type = "checkbox",
            name = string.format(L.SORT_ROLE, GetString("SI_LFGROLE", LFG_ROLE_TANK),
                GetString("SI_LFGROLE", LFG_ROLE_HEAL), GetString("SI_LFGROLE", LFG_ROLE_DPS)),
            getFunc = function() return VG.sv.sortByRole end,
            setFunc = function(v)
                VG.sv.sortByRole = v
                VG.Tracker.unitsDirty = true
                Refresh()
            end,
            default = VG.defaults.sortByRole,
        },
        Checkbox("showTimers", L.SHOW_TIMERS),
        Checkbox("showUptime", L.SHOW_UPTIME, L.SHOW_UPTIME_TIP),
        {
            type = "dropdown",
            name = L.UPTIME_SCOPE,
            tooltip = L.UPTIME_SCOPE_TIP,
            choices = { L.UPTIME_SCOPE_FIGHT, L.UPTIME_SCOPE_RUN },
            choicesValues = { "fight", "run" },
            getFunc = function() return VG.sv.uptimeScope end,
            setFunc = VG.SetUptimeScope,
            disabled = function() return not VG.sv.showUptime end,
            default = VG.defaults.uptimeScope,
        },
        {
            type = "button",
            name = L.UPTIME_RESET,
            width = "half",
            func = VG.ResetUptime,
            disabled = function() return not VG.sv.showUptime end,
        },
        Slider("warnSeconds", L.WARN_SECONDS, 0, 10, 1, L.WARN_SECONDS_TIP),
        Dropdown("missingStyle", L.MISSING_STYLE, { L.MISSING_DIM, L.MISSING_RED }, { "dim", "red" }),

        { type = "header", name = L.H_BUFFS },
        { type = "description", text = L.BUFFS_DESC },
        {
            type = "button",
            name = L.BUFFS_DEFAULT,
            width = "half",
            func = function() VG.Catalog.SetAll(nil) end,
        },
        {
            type = "button",
            name = L.BUFFS_NONE,
            width = "half",
            func = function() VG.Catalog.SetAll(false) end,
        },
        {
            type = "button",
            name = L.ORDER_BUTTON,
            tooltip = L.ORDER_TIP,
            width = "half",
            func = function() VG.Browser.Open("tracked") end,
        },
    }
    for _, menu in ipairs(CategorySubmenus()) do options[#options + 1] = menu end
    options[#options + 1] = CustomSubmenu()

    options[#options + 1] = { type = "header", name = L.H_COMMANDS }
    options[#options + 1] = { type = "description", text = table.concat(L.HELP, "\n") }

    LAM:RegisterOptionControls(PANEL_NAME, options)
end
