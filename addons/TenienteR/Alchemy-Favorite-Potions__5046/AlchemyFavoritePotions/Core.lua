-- Motor del addon: carga, SavedVariables y lógica de favoritas.
local AFP = AlchemyFavoritePotions

-- Inventarios donde el juego busca ingredientes para la mesa de alquimia
local INVENTORY_TYPES = { INVENTORY_BACKPACK, INVENTORY_CRAFT_BAG, INVENTORY_BANK }

--- Recorre las bolsas una sola vez y devuelve un mapa itemId -> { bagId, slotIndex }.
-- Si hay varias pilas del mismo objeto se queda con la primera que encuentra.
function AFP.BuildAvailableItems()
    local availableItems = {}

    for _, inventoryType in ipairs(INVENTORY_TYPES) do
        for _, bagId in ipairs(PLAYER_INVENTORY.inventories[inventoryType].backingBags) do
            for slotIndex in ZO_IterateBagSlots(bagId) do
                local itemId = GetItemId(bagId, slotIndex)
                if itemId ~= 0 and not availableItems[itemId] then
                    availableItems[itemId] = { bagId = bagId, slotIndex = slotIndex }
                end
            end
        end
    end

    return availableItems
end

local function GetItemDisplayName(itemLink)
    return zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(itemLink))
end

--- Qué impide al personaje preparar una favorita ahora mismo.
-- Devuelve siempre una tabla; hasAny es false si se puede preparar.
-- missingIngredients[n] es true si falta el ingrediente n (1 = disolvente, 2... = reactivos).
function AFP.GetFavoriteProblems(favorite, availableItems)
    local problems = {
        missingNames = {},
        missingIngredients = {},
        thirdSlotLocked = false,
        solventRankTooLow = false,
    }

    local ingredientLinks = { favorite.solvent }
    for _, reagentLink in ipairs(favorite.reagents) do
        ingredientLinks[#ingredientLinks + 1] = reagentLink
    end

    for index, itemLink in ipairs(ingredientLinks) do
        if not availableItems[GetItemLinkItemId(itemLink)] then
            problems.missingIngredients[index] = true
            problems.missingNames[#problems.missingNames + 1] = GetItemDisplayName(itemLink)
        end
    end

    problems.thirdSlotLocked = #favorite.reagents > 2 and not ZO_Alchemy_IsThirdAlchemySlotUnlocked()

    -- Un disolvente de rango alto no se puede usar con poco nivel de alquimia
    local solventItem = availableItems[GetItemLinkItemId(favorite.solvent)]
    if solventItem then
        local _, _, rankRequirement = GetItemCraftingInfo(solventItem.bagId, solventItem.slotIndex)
        if rankRequirement > GetNonCombatBonus(NON_COMBAT_BONUS_ALCHEMY_LEVEL) then
            problems.solventRankTooLow = true
            problems.solventName = GetItemDisplayName(favorite.solvent)
        end
    end

    problems.hasAny = #problems.missingNames > 0 or problems.thirdSlotLocked or problems.solventRankTooLow
    return problems
end

--- Textos de los problemas, uno por línea. Sirve para el tooltip de la fila.
function AFP.GetProblemsText(problems)
    local lines = {}

    if #problems.missingNames > 0 then
        lines[#lines + 1] = string.format(AFP.L("MISSING_INGREDIENTS"), table.concat(problems.missingNames, ", "))
    end
    if problems.thirdSlotLocked then
        lines[#lines + 1] = AFP.L("THIRD_SLOT_LOCKED")
    end
    if problems.solventRankTooLow then
        lines[#lines + 1] = string.format(AFP.L("SOLVENT_RANK_TOO_LOW"), problems.solventName)
    end

    return table.concat(lines, "\n")
end

local function ShowAlert(text)
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEGATIVE_CLICK, text)
end

--- Coloca en las ranuras los ingredientes de una favorita.
-- Si algo lo impide no toca las ranuras y avisa del motivo.
function AFP.ApplyFavorite(favorite)
    local availableItems = AFP.BuildAvailableItems()
    local problems = AFP.GetFavoriteProblems(favorite, availableItems)

    if problems.thirdSlotLocked then
        ShowAlert(AFP.L("THIRD_SLOT_LOCKED"))
        return
    end

    if #problems.missingNames > 0 then
        ShowAlert(string.format(AFP.L("MISSING_INGREDIENTS"), table.concat(problems.missingNames, ", ")))
        return
    end

    if problems.solventRankTooLow then
        ShowAlert(string.format(AFP.L("SOLVENT_RANK_TOO_LOW"), problems.solventName))
        return
    end

    local solventItem = availableItems[GetItemLinkItemId(favorite.solvent)]

    local SUPPRESS_SOUND = true
    ALCHEMY:ClearSelections(SUPPRESS_SOUND)
    ALCHEMY:SetSolventItem(solventItem.bagId, solventItem.slotIndex)
    for reagentIndex, reagentLink in ipairs(favorite.reagents) do
        local reagentItem = availableItems[GetItemLinkItemId(reagentLink)]
        ALCHEMY:SetReagentItem(reagentIndex, reagentItem.bagId, reagentItem.slotIndex)
    end
end

--- Se llama al hacer clic en una fila de favorita
function AFP.OnFavoriteSelected(rowData)
    AFP.ApplyFavorite(rowData.favorite)
end

--- Muestra los mensajes de la versión Dev cuando el chat ya está listo.
-- Durante EVENT_ADD_ON_LOADED el chat aún no existe, por eso se espera a EVENT_PLAYER_ACTIVATED.
local function PrintDevLoadedMessage(svName)
    local eventName = AFP.name .. "DevLoaded"

    EVENT_MANAGER:RegisterForEvent(eventName, EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_PLAYER_ACTIVATED)
        AFP.Print(string.format(AFP.L("LOADED_DEV"), svName))

        if AFP.hooksError then
            AFP.Print(string.format(AFP.L("HOOKS_ERROR"), tostring(AFP.hooksError)))
        end
    end)
end

local function Initialize(isDev)
    AFP.isDev = isDev

    -- Variable guardada distinta para la versión Dev y la estable.
    -- El perfil es el servidor (NA, EU, PTS) para que no se pisen.
    local svName = isDev and AFP.devSvName or AFP.svName
    AFP.sv = ZO_SavedVars:NewAccountWide(svName, AFP.svVersion, nil, AFP.defaults, GetWorldName())

    -- Si el juego cambia algo de su interfaz, falla solo el gancho y no el resto del addon
    local installed, errorMessage = pcall(AFP.InstallHooks)
    if not installed then
        AFP.hooksError = errorMessage
    end

    if isDev then
        PrintDevLoadedMessage(svName)
    end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= AFP.name and addonName ~= AFP.devName then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(AFP.name, EVENT_ADD_ON_LOADED)
    Initialize(addonName == AFP.devName)
end

EVENT_MANAGER:RegisterForEvent(AFP.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
