local NWUI = NWUI

local defaults = {
    positions = {},
    gridSize = 20,
    showGrid = true,
    snap = true,
    compatNoticeShown = false,
    lang = "auto",
    hud = {
        enabled = true,
        hideDefaultBars = true,
        barWidth = 400,
        healthHeight = 28,
        resourceHeight = 16,
        staminaColor = "nw",
        showBarText = true,
        showLevel = true,
        levelSize = 26,
        moveActionBar = true,
        flatAbilities = true,
        abilitySize = 46,
        ultSize = 52,
        abilityGap = 3,
        backBar = true,
        weaponIcon = true,
        swapAnim = true,
        swapSweep = true,
        swapSweepMs = 1000,
        consumablesEnabled = true,
        consumableCount = 4,
        consumableSize = 40,
        quickslotSize = 50,
        hideBanditsQuickslots = true,
        iconBorder = 2,
        barBorder = "dark",
    },
    inv = {
        enabled = true,
        iconSize = 50,
        iconsPerRow = 4,
        iconGap = 7,
        slotBgAlpha = 35,
        panelAlpha = 62,
        collapsed = {},
        sort = "quality",
        equipment = true,
        equipmentInBank = true,
        eqSize = 60,
        useGameMenu = true,
        hideBackgrounds = true,
        panelLocks = { backpack = true, bank = true, guild = true },
        showPrices = true,
        priceSource = "auto",
        priceType = "AVERAGE",
        priceMin = 10000,
        priceShowLow = true,
        priceStack = false,
    },
}

local function SafeInit(mod, label)
    if not (mod and mod.Init) then return end
    local ok, err = pcall(mod.Init)
    if not ok then
        d("|cFF6666[NW Interfaz]|r " .. NWUI.T("init_error", label, tostring(err)))
    end
end

local function OnLoaded(_, addonName)
    if addonName ~= NWUI.name then return end
    EVENT_MANAGER:UnregisterForEvent(NWUI.name, EVENT_ADD_ON_LOADED)

    NWUI.sv = ZO_SavedVars:NewAccountWide("NWInterfaz_SV", 2, nil, defaults)
    NWUI.sv.positions = NWUI.sv.positions or {}
    -- 1.1.1: nueva disposición del equipo; se descartan posiciones viejas de esos bloques
    if (NWUI.sv.layoutRev or 0) < 3 then
        for _, k in ipairs({ "eq_armor", "eq_jewelry", "eq_stats", "eq_mundus" }) do NWUI.sv.positions[k] = nil end
        NWUI.sv.inv.eqSize = 60
        NWUI.sv.layoutRev = 3
    end
    -- 1.2.1: marcos externos en los iconos; más separación para que no se toquen
    if (NWUI.sv.layoutRev or 0) < 4 then
        if (NWUI.sv.hud.abilityGap or 0) < 8 then NWUI.sv.hud.abilityGap = 8 end
        NWUI.sv.layoutRev = 4
    end
    -- 1.2.2: Mundus debajo de Joyería
    if (NWUI.sv.layoutRev or 0) < 5 then
        NWUI.sv.positions["eq_mundus"] = nil
        NWUI.sv.layoutRev = 5
    end

    -- 1.3.5: las estadísticas vuelven junto a la armadura
    if (NWUI.sv.layoutRev or 0) < 6 then
        NWUI.sv.positions["eq_stats"] = nil
        NWUI.sv.layoutRev = 6
    end
    -- 1.4.1: barras del HUD un poco más altas (vida sigue siendo la mayor)
    if (NWUI.sv.layoutRev or 0) < 7 then
        local h = NWUI.sv.hud
        if (h.resourceHeight or 0) < 16 then h.resourceHeight = 16 end
        if (h.healthHeight or 0) < 28 then h.healthHeight = 28 end
        NWUI.sv.layoutRev = 7
    end
    -- 1.7.1: el marco va pegado al icono; habilidades más juntas
    if (NWUI.sv.layoutRev or 0) < 8 then
        local h = NWUI.sv.hud
        if (h.abilityGap or 0) >= 6 then h.abilityGap = 3 end
        NWUI.sv.layoutRev = 8
    end

    SafeInit(NWUI.HUD, "HUD")
    SafeInit(NWUI.Inventory, "inventario")
    SafeInit(NWUI.Equipment, "equipo")
    SafeInit(NWUI.Scenes, "escenas")
    SafeInit(NWUI.Compat, "compatibilidad")
    SafeInit(NWUI.Settings, "ajustes")

    SLASH_COMMANDS["/nwui"] = function(arg)
        arg = zo_strlower(zo_strtrim(arg or ""))
        if arg == "mover" or arg == "move" or arg == "edit" then
            NWUI.SetUnlocked(not NWUI.unlocked)
        elseif arg == "reset" then
            NWUI.ResetPositions()
        elseif arg == "menu" then
            if LibAddonMenu2 and NWUI.settingsPanel then
                LibAddonMenu2:OpenToPanel(NWUI.settingsPanel)
            else
                d("|cC9A35E[NW Interfaz]|r " .. NWUI.T("need_lam"))
            end
        elseif arg == "raton" or arg == "mouse" then
            -- qué control está bajo el ratón (para encontrar qué tapa el panel)
            local c = WINDOW_MANAGER:GetMouseOverControl()
            local chain = {}
            while c and #chain < 8 do
                chain[#chain + 1] = (c.GetName and c:GetName() ~= "" and c:GetName()) or tostring(c)
                c = c.GetParent and c:GetParent() or nil
                if c == GuiRoot then break end
            end
            d("|cC9A35E[NW Interfaz]|r " .. (#chain > 0 and table.concat(chain, "  <  ") or "(nada)"))
        elseif arg == "arma" or arg == "weapon" then
            if NWUI.HUD and NWUI.HUD.DiagWeapon then
                for _, line in ipairs(NWUI.HUD.DiagWeapon()) do d("|cC9A35E[NW Interfaz]|r " .. line) end
            end
        elseif arg == "diag" then
            d("|cC9A35E[NW Interfaz]|r " .. NWUI.T("diag", NWUI.version))
            for _, mod in ipairs({ NWUI.Compat, NWUI.Scenes }) do
                if mod and mod.Diagnose then
                    for _, line in ipairs(mod.Diagnose()) do d("  " .. line) end
                end
            end
        else
            d("|cC9A35E[NW Interfaz]|r " .. NWUI.T("help"))
        end
    end
end

EVENT_MANAGER:RegisterForEvent(NWUI.name, EVENT_ADD_ON_LOADED, OnLoaded)
