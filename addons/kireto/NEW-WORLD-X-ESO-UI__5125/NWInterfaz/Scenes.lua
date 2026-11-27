-- Conecta los paneles con las escenas del juego (inventario, banco,
-- almacén de casa y banco de gremio). Mientras esas escenas están abiertas:
--  · aparta las ventanas originales y los fondos oscuros con degradado,
--  · coloca el menú "Objetos" del juego debajo de las armas equipadas,
--  · coloca la barra original (espacio, mejorar bolsa y oro) bajo el panel,
--  · si abres la bolsa de artesanía o los objetos rápidos, muestra los originales.
-- Al cerrar la escena, todo vuelve exactamente a su sitio.
local NWUI = NWUI
local SC = {}
NWUI.Scenes = SC

local HIDE = {
    -- la lista original de objetos rápidos se aparta; su rueda (anclada al
    -- centro de la pantalla) sigue visible para arrastrar objetos a ella
    inventory = { "ZO_PlayerInventory", "ZO_Character", "ZO_CharacterWindowStats", "ZO_QuickSlot_Keyboard_TopLevel", "ZO_QuickSlot" },
    bank      = { "ZO_PlayerInventory", "ZO_PlayerBank" },
    guildbank = { "ZO_PlayerInventory", "ZO_GuildBank" },
    housebank = { "ZO_PlayerInventory", "ZO_HouseBank", "ZO_PlayerBank" },
}

-- Fondos con degradado negro a los lados
local BG_NAMES = {
    "ZO_SharedRightBackground", "ZO_SharedRightPanelBackground",
    "ZO_SharedMediumLeftPanelBackground", "ZO_SharedWideLeftPanelBackground",
    "ZO_SharedThinLeftPanelBackground", "ZO_SharedLeftPanelBackground",
    "ZO_SharedTreeUnderlay", "ZO_SharedWideLeftBackground", "ZO_SharedLeftBackground",
}

local MENU_NAMES = { "ZO_InventoryMenu", "ZO_PlayerInventoryMenu" }

-- Ventanas de otras pestañas del inventario (se muestran las originales)
local OTHER_TABS = { "ZO_CraftBag", "ZO_QuickSlot", "ZO_QuickSlot_Keyboard_TopLevel" }

local SCENE_MODES = {
    inventory = "inventory",
    bank      = "bank",
    guildBank = "guildbank",
    houseBank = "housebank",
}

local OFFSET = 10000
local moved, reanchored = {}, {}
local backgrounds
SC.active = nil

local function IsControl(c)
    return c ~= nil and (type(c) == "userdata" or type(c) == "table") and c.GetAnchor ~= nil and c.ClearAnchors ~= nil
end

local function First(names)
    for _, n in ipairs(names) do
        local c = _G[n]
        if IsControl(c) then return c, n end
    end
end

local function MoveOff(c)
    local m = moved[c]
    if m then
        m.count = m.count + 1
        return
    end
    local anchors = NWUI.SaveAnchors(c)
    moved[c] = { anchors = anchors, count = 1 }
    c:ClearAnchors()
    if #anchors == 0 then
        c:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, -OFFSET, 0)
    else
        for _, a in ipairs(anchors) do
            c:SetAnchor(a[1], a[2], a[3], a[4] - OFFSET, a[5], a[6])
        end
    end
end

local function Restore(c)
    local m = moved[c]
    if not m then return end
    m.count = m.count - 1
    if m.count > 0 then return end
    NWUI.RestoreAnchors(c, m.anchors)
    moved[c] = nil
end

local function Reanchor(c, fn)
    if not IsControl(c) then return end
    if not reanchored[c] then reanchored[c] = { anchors = NWUI.SaveAnchors(c) } end
    c:ClearAnchors()
    fn(c)
end

local function Unanchor(c)
    local r = reanchored[c]
    if not r then return end
    NWUI.RestoreAnchors(c, r.anchors)
    if r.restore then r.restore() end
    reanchored[c] = nil
end

-- Solo nombres concretos: recorrer las variables globales del juego provoca
-- el error "Attempt to access a private function" (funciones privadas de ESO).
function SC.CollectBackgrounds()
    if backgrounds then return backgrounds end
    local set, list = {}, {}
    for _, n in ipairs(BG_NAMES) do
        local c = _G[n]
        if IsControl(c) and not set[c] then
            set[c] = true
            list[#list + 1] = c
        end
    end
    backgrounds = list
    return list
end

-- Iconos de las pestañas tomados del menú original (ordenados de izquierda a derecha)
local harvested
local function HarvestIcons(menu)
    if harvested ~= nil then return harvested end
    local found, seen = {}, {}
    local function walk(c, depth)
        if depth > 5 or not c.GetNumChildren then return end
        local okn, n = pcall(c.GetNumChildren, c)
        for i = 1, (okn and n or 0) do
            local okc, ch = pcall(c.GetChild, c, i)
            if okc and ch then
                if ch.GetTextureFileName then
                    local ok, f = pcall(ch.GetTextureFileName, ch)
                    if ok and type(f) == "string" and f:lower():find("icon", 1, true) then
                        f = f:gsub("_down%.dds$", "_up.dds"):gsub("_over%.dds$", "_up.dds")
                        if not seen[f] then
                            seen[f] = true
                            found[#found + 1] = { f = f, x = ch:GetLeft() or 0 }
                        end
                    end
                end
                walk(ch, depth + 1)
            end
        end
    end
    pcall(walk, menu, 0)
    table.sort(found, function(a, b) return a.x < b.x end)
    if #found == 5 then
        harvested = {}
        for i, e in ipairs(found) do harvested[i] = e.f end
    else
        harvested = false
    end
    return harvested
end
SC.HarvestIcons = HarvestIcons

-- Barra original de espacio/oro DENTRO del pie de nuestro panel
local function AttachInfoBar(barName, panel)
    local bar = _G[barName]
    if not (IsControl(bar) and panel) then return end
    Reanchor(bar, function(c)
        local foot = panel.foot or panel.tlw
        c:SetAnchor(BOTTOMLEFT, foot, BOTTOMLEFT, 10, -4)
        c:SetAnchor(BOTTOMRIGHT, foot, BOTTOMRIGHT, -10, -4)
    end)
    if bar.GetDrawTier and bar.SetDrawTier and not reanchored[bar].tierDone then
        reanchored[bar].tierDone = true
        local tier = bar:GetDrawTier()
        bar:SetDrawTier(DT_MEDIUM)
        local prev = reanchored[bar].restore
        reanchored[bar].restore = function()
            bar:SetDrawTier(tier)
            if prev then prev() end
        end
    end
    -- oro un poco más grande
    local money = bar.GetNamedChild and bar:GetNamedChild("Money")
    if money and money.GetFont and not reanchored[bar].fontDone then
        local font = money:GetFont()
        money:SetFont("ZoFontWinH3")
        reanchored[bar].fontDone = true
        local prev = reanchored[bar].restore
        reanchored[bar].restore = function()
            money:SetFont(font)
            if prev then prev() end
        end
    end
    panel.nativeBar = bar
end

local function OtherTabShown(shown)
    if SC.active ~= "inventory" then return end
    local inv = NWUI.Inventory and NWUI.Inventory.backpack
    if not inv then return end
    if shown then
        inv.tlw:SetHidden(true)
    elseif inv.fragment.GetState == nil or inv.fragment:GetState() == SCENE_FRAGMENT_SHOWN then
        inv.tlw:SetHidden(false)
    end
end

function SC.ApplyMode(mode)
    local INV, EQ = NWUI.Inventory, NWUI.Equipment
    for _, name in ipairs(HIDE[mode] or {}) do
        local c = _G[name]
        if IsControl(c) then MoveOff(c) end
    end
    if NWUI.sv.inv.hideBackgrounds then
        for _, c in ipairs(SC.CollectBackgrounds()) do MoveOff(c) end
    end
    if mode == "inventory" then
        -- El menú original se sustituye por nuestras pestañas con el mismo diseño
        local menu = First(MENU_NAMES)
        if menu then
            local icons = HarvestIcons(menu)
            if icons and INV.SetTabIcons then INV.SetTabIcons(icons) end
            MoveOff(menu)
        end
    end
end

function SC.RevertMode(mode)
    for _, name in ipairs(HIDE[mode] or {}) do
        local c = _G[name]
        if IsControl(c) then Restore(c) end
    end
    if mode == "inventory" then
        local menu = First(MENU_NAMES)
        if menu then Restore(menu) end
    end
    if backgrounds then
        for _, c in ipairs(backgrounds) do Restore(c) end
    end
    for c in pairs(reanchored) do Unanchor(c) end
    local INV = NWUI.Inventory
    if INV and INV.panels then
        for _, p in ipairs(INV.panels) do p.nativeBar = nil end
    end
end

-- Modo según la escena que se está abriendo (fiable aunque el juego aún no
-- haya terminado de cerrar el banco), con la interacción como respaldo.
local function SceneMode()
    if not SCENE_MANAGER then return nil end
    local nextScene = SCENE_MANAGER.GetNextScene and SCENE_MANAGER:GetNextScene()
    local cur = SCENE_MANAGER.GetCurrentScene and SCENE_MANAGER:GetCurrentScene()
    for _, sc in pairs({ nextScene or false, cur or false }) do
        local name = type(sc) == "table" and sc.GetName and sc:GetName()
        if name and SCENE_MODES[name] then return SCENE_MODES[name] end
    end
    return nil
end

function SC.CurrentMode()
    if SC.showing then return SC.showing end
    local m = SceneMode()
    if m then return m end
    local it = GetInteractionType and GetInteractionType()
    if INTERACTION_GUILDBANK and it == INTERACTION_GUILDBANK then return "guildbank" end
    if INTERACTION_BANK and it == INTERACTION_BANK then
        if GetBankingBag and GetBankingBag() ~= BAG_BANK then return "housebank" end
        return "bank"
    end
    return "inventory"
end

function SC.Init()
    local INV, EQ = NWUI.Inventory, NWUI.Equipment
    if not (INV and INV.backpack) then return end
    local s = NWUI.sv.inv
    for sceneName, mode in pairs(SCENE_MODES) do
        local scene = SCENE_MANAGER:GetScene(sceneName)
        if scene then
            scene:AddFragment(INV.backpack.fragment)
            if mode == "bank" or mode == "housebank" then scene:AddFragment(INV.bank.fragment) end
            if mode == "guildbank" then scene:AddFragment(INV.guild.fragment) end
            if EQ and EQ.fragment and (mode == "inventory" or s.equipmentInBank) then
                scene:AddFragment(EQ.fragment)
            end
            scene:RegisterCallback("StateChange", function(_, newState)
                if newState == SCENE_SHOWING then
                    SC.active = mode
                    SC.showing = mode
                    if INV.PlaceTabs then INV.PlaceTabs(mode) end
                    SC.ApplyMode(mode)
                    -- Recolocar los paneles según la escena real (al pasar del
                    -- banco al inventario el panel se quedaba en la posición del banco).
                    for _, p in ipairs(INV.panels or {}) do
                        if p.mode ~= mode and p.ApplyLayout then
                            p.mode = mode
                            p:ApplyLayout(mode)
                        end
                    end
                elseif newState == SCENE_SHOWN then
                    SC.showing = nil
                    if mode == "inventory" and INV.SyncNativeWheel then INV.SyncNativeWheel() end
                elseif newState == SCENE_HIDDEN then
                    if SC.showing == mode then SC.showing = nil end
                    if SC.active == mode then SC.active = nil end
                    SC.RevertMode(mode)
                end
            end)
        end
    end

    -- Bolsa de artesanía y objetos rápidos: se ven las ventanas originales
    local hook = ZO_PostHookHandler or ZO_PreHookHandler
    if hook then
        for _, name in ipairs(OTHER_TABS) do
            local c = _G[name]
            -- objetos rápidos: NO se oculta nuestro panel (se usa con la rueda del juego)
            if IsControl(c) and not name:find("QuickSlot", 1, true) then
                hook(c, "OnShow", function() OtherTabShown(true) end)
                hook(c, "OnHide", function() OtherTabShown(false) end)
            end
        end
    end
end

-- Para /nwui diag
function SC.Diagnose()
    local found = {}
    local menu, menuName = First(MENU_NAMES)
    found[#found + 1] = "Menú Objetos: " .. (menu and menuName or "no encontrado")
        .. " · iconos de pestañas: " .. ((harvested and "del juego") or (harvested == false and "de respaldo") or "aún no leídos")
    for _, n in ipairs({ "ZO_PlayerInventoryInfoBar", "ZO_PlayerBankInfoBar", "ZO_GuildBankInfoBar" }) do
        found[#found + 1] = n .. ": " .. (IsControl(_G[n]) and "sí" or "no")
    end
    found[#found + 1] = "Fondos degradados encontrados: " .. #SC.CollectBackgrounds()
    return found
end
