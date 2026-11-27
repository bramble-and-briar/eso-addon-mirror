-- Panel de ajustes (requiere LibAddonMenu-2.0; si no está, usa /nwui).
local NWUI = NWUI
local ST = {}
NWUI.Settings = ST

local function Relayout()
    if NWUI.HUD and NWUI.HUD.LayoutAll then NWUI.HUD.LayoutAll() end
end

local function ResizeInventory()
    if NWUI.Price and NWUI.Price.ClearCache then NWUI.Price.ClearCache() end
    if NWUI.Inventory and NWUI.Inventory.ResizeAll then NWUI.Inventory.ResizeAll() end
    if NWUI.Equipment and NWUI.Equipment.tlw and not NWUI.Equipment.tlw:IsHidden() then NWUI.Equipment.Refresh() end
end

local function root(name, key, onSet, tooltip)
    return {
        type = "checkbox", name = name, tooltip = tooltip,
        getFunc = function() return NWUI.sv[key] end,
        setFunc = function(v) NWUI.sv[key] = v; if onSet then onSet() end end,
    }
end

local function check(name, tbl, key, onSet, reload, tooltip)
    return {
        type = "checkbox", name = name, tooltip = tooltip,
        getFunc = function() return NWUI.sv[tbl][key] end,
        setFunc = function(v)
            NWUI.sv[tbl][key] = v
            if onSet then onSet() end
        end,
        requiresReload = reload,
    }
end

local function slider(name, tbl, key, min, max, step, onSet)
    return {
        type = "slider", name = name, min = min, max = max, step = step or 1,
        getFunc = function() return NWUI.sv[tbl][key] end,
        setFunc = function(v)
            NWUI.sv[tbl][key] = v
            if onSet then onSet() end
        end,
    }
end

function ST.Init()
    local LAM = LibAddonMenu2
    if not LAM then return end

    NWUI.settingsPanel = LAM:RegisterAddonPanel("NWInterfazPanel", {
        type = "panel",
        name = "NW Interfaz",
        displayName = "|cC9A35ENW|r Interfaz",
        author = "Kireto",
        version = NWUI.version,
        registerForRefresh = true,
    })

    local options = {
        {
            type = "dropdown", name = NWUI.T("o_lang"), tooltip = NWUI.T("o_lang_tip"),
            choices = { NWUI.T("o_lang_auto"), "Español", "English", "Português" },
            choicesValues = { "auto", "es", "en", "pt" },
            getFunc = function() return NWUI.sv.lang or "auto" end,
            setFunc = function(v) NWUI.sv.lang = v end,
            requiresReload = true,
        },
        { type = "header", name = NWUI.T("h_bars") },
        check(NWUI.T("o_hud"), "hud", "enabled", nil, true),
        check(NWUI.T("o_hidebars"), "hud", "hideDefaultBars", nil, true),
        slider(NWUI.T("o_barw"), "hud", "barWidth", 200, 800, 10, Relayout),
        slider(NWUI.T("o_hph"), "hud", "healthHeight", 12, 48, 1, Relayout),
        slider(NWUI.T("o_resh"), "hud", "resourceHeight", 6, 30, 1, Relayout),
        {
            type = "dropdown", name = NWUI.T("o_stacol"),
            choices = { NWUI.T("o_stacol_nw"), NWUI.T("o_stacol_eso") }, choicesValues = { "nw", "eso" },
            getFunc = function() return NWUI.sv.hud.staminaColor end,
            setFunc = function(v) NWUI.sv.hud.staminaColor = v; Relayout() end,
        },
        check(NWUI.T("o_bartext"), "hud", "showBarText", Relayout),
        {
            type = "dropdown", name = NWUI.T("o_barborder"),
            choices = { NWUI.T("o_dark"), NWUI.T("o_gold") }, choicesValues = { "dark", "gold" },
            getFunc = function() return NWUI.sv.hud.barBorder end,
            setFunc = function(v) NWUI.sv.hud.barBorder = v; Relayout() end,
        },
        check(NWUI.T("o_level"), "hud", "showLevel", Relayout),
        slider(NWUI.T("o_levelsize"), "hud", "levelSize", 14, 44, 1, Relayout),

        { type = "header", name = NWUI.T("h_abil") },
        check(NWUI.T("o_moveab"), "hud", "moveActionBar", Relayout, true),
        check(NWUI.T("o_flat"), "hud", "flatAbilities", Relayout, true),
        slider(NWUI.T("o_abs"), "hud", "abilitySize", 36, 96, 1, Relayout),
        slider(NWUI.T("o_ult"), "hud", "ultSize", 36, 110, 1, Relayout),
        slider(NWUI.T("o_abgap"), "hud", "abilityGap", 0, 24, 1, Relayout),
        slider(NWUI.T("o_iconb"), "hud", "iconBorder", 0, 4, 1, Relayout),
        check(NWUI.T("o_backbar"), "hud", "backBar", Relayout),
        check(NWUI.T("o_weapicon"), "hud", "weaponIcon", Relayout),
        check(NWUI.T("o_swapanim"), "hud", "swapAnim"),
        NWUI.BUILD_SWEEP and check(NWUI.T("o_sweep"), "hud", "swapSweep") or nil,
        NWUI.BUILD_SWEEP and slider(NWUI.T("o_sweepms"), "hud", "swapSweepMs", 300, 2000, 50) or nil,

        { type = "header", name = NWUI.T("h_cons") },
        check(NWUI.T("o_cons"), "hud", "consumablesEnabled", Relayout),
        slider(NWUI.T("o_consn"), "hud", "consumableCount", 1, 8, 1, Relayout),
        slider(NWUI.T("o_conss"), "hud", "consumableSize", 30, 80, 1, Relayout),
        slider(NWUI.T("o_qss"), "hud", "quickslotSize", 30, 90, 1, Relayout),
        check(NWUI.T("o_buiqs"), "hud", "hideBanditsQuickslots", nil, true),

        { type = "header", name = NWUI.T("h_inv") },
        check(NWUI.T("o_inv"), "inv", "enabled", nil, true),
        slider(NWUI.T("o_icons"), "inv", "iconSize", 40, 72, 1, ResizeInventory),
        slider(NWUI.T("o_perrow"), "inv", "iconsPerRow", 3, 6, 1, ResizeInventory),
        slider(NWUI.T("o_gap"), "inv", "iconGap", 2, 20, 1, ResizeInventory),
        slider(NWUI.T("o_slotalpha"), "inv", "slotBgAlpha", 10, 100, 5, ResizeInventory),
        slider(NWUI.T("o_panelalpha"), "inv", "panelAlpha", 20, 100, 5, function()
            if NWUI.Inventory and NWUI.Inventory.ApplyPanelAlpha then NWUI.Inventory.ApplyPanelAlpha() end
        end),
        slider(NWUI.T("o_eqsize"), "inv", "eqSize", 32, 90, 1, ResizeInventory),
        check(NWUI.T("o_hidebg"), "inv", "hideBackgrounds"),
        check(NWUI.T("o_eq"), "inv", "equipment", nil, true),
        check(NWUI.T("o_eqbank"), "inv", "equipmentInBank", nil, true),
        check(NWUI.T("o_menu"), "inv", "useGameMenu", nil, false,
            NWUI.T("o_menu_tip")),

        { type = "header", name = NWUI.T("h_price") },
        check(NWUI.T("o_price"), "inv", "showPrices", ResizeInventory),
        {
            type = "dropdown", name = NWUI.T("o_psrc"),
            tooltip = NWUI.T("o_psrc_tip"),
            choices = { NWUI.T("o_psrc_auto"), NWUI.T("o_psrc_ttcsp"), NWUI.T("o_psrc_own") },
            choicesValues = { "auto", "ttcsp", "own" },
            getFunc = function() return NWUI.sv.inv.priceSource end,
            setFunc = function(v) NWUI.sv.inv.priceSource = v; ResizeInventory() end,
        },
        {
            type = "dropdown", name = NWUI.T("o_ptype"),
            choices = { NWUI.T("o_pavg"), NWUI.T("o_psug") }, choicesValues = { "AVERAGE", "TTC" },
            getFunc = function() return NWUI.sv.inv.priceType end,
            setFunc = function(v) NWUI.sv.inv.priceType = v; ResizeInventory() end,
        },
        slider(NWUI.T("o_pmin"), "inv", "priceMin", 1, 100000, 100, ResizeInventory),
        check(NWUI.T("o_plow"), "inv", "priceShowLow", ResizeInventory),
        check(NWUI.T("o_pstack"), "inv", "priceStack", ResizeInventory),

        { type = "header", name = NWUI.T("h_pos") },
        root(NWUI.T("o_grid"), "showGrid"),
        root(NWUI.T("o_snap"), "snap"),
        {
            type = "slider", name = NWUI.T("o_gridsize"), min = 8, max = 64, step = 2,
            getFunc = function() return NWUI.sv.gridSize end,
            setFunc = function(v) NWUI.sv.gridSize = v; if NWUI.unlocked then NWUI.BuildGrid() end end,
        },
        { type = "button", name = NWUI.T("o_edit"), func = function() NWUI.SetUnlocked(not NWUI.unlocked) end },
        { type = "button", name = NWUI.T("o_reset"), func = NWUI.ResetPositions, isDangerous = true,
          warning = NWUI.T("o_reset_warn") },
    }
    -- quita los huecos (opciones que no existen en esta versión)
    local list, maxi = {}, 0
    for k in pairs(options) do if type(k) == "number" and k > maxi then maxi = k end end
    for i = 1, maxi do if options[i] then list[#list + 1] = options[i] end end
    LAM:RegisterOptionControls("NWInterfazPanel", list)
end
