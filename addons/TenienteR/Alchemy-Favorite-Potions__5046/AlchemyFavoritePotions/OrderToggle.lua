-- Casilla "Añadir al principio / al final" de la pestaña de favoritas.
-- Ocupa el sitio de "Solo misiones", que ahí no hace nada, y solo se ve en esa pestaña.
local AFP = AlchemyFavoritePotions

local TOGGLE_NAME = "AlchemyFavoritePotionsOrderToggle"

local function UpdateToggleLabel(toggle)
    local textKey = ZO_CheckButton_IsChecked(toggle) and "ORDER_NEWEST_FIRST" or "ORDER_NEWEST_LAST"
    ZO_CheckButton_SetLabelText(toggle, AFP.L(textKey))
end

--- Enseña la casilla propia en la pestaña de favoritas y la de "Solo misiones" en las demás
function AFP.UpdateFilterControls(inventory)
    local toggle = AFP.orderToggle
    if not toggle then
        return
    end

    local isFavoritesTab = inventory.filterType == AFP.FAVORITES_FILTER
    inventory.questFilterCheckButton:SetHidden(isFavoritesTab)
    toggle:SetHidden(not isFavoritesTab)
end

function AFP.CreateOrderToggle(inventory)
    if AFP.orderToggle then
        return
    end

    local toggle = WINDOW_MANAGER:CreateControlFromVirtual(TOGGLE_NAME, inventory.control, "ZO_CheckButton")
    -- Misma posición que "Solo misiones"
    toggle:SetAnchor(TOPLEFT, inventory.questFilterCheckButton, TOPLEFT, 0, 0)
    toggle:SetHidden(true)

    ZO_CheckButton_SetCheckState(toggle, AFP.IsNewestFirst())
    UpdateToggleLabel(toggle)

    ZO_CheckButton_SetToggleFunction(toggle, function()
        AFP.SetNewestFirst(ZO_CheckButton_IsChecked(toggle))
        UpdateToggleLabel(toggle)
        AFP.RefreshFavoritesList()
    end)

    -- Igual que "Solo misiones", se bloquea mientras se fabrica
    ZO_CraftingUtils_ConnectCheckBoxToCraftingProcess(toggle)

    AFP.orderToggle = toggle

    -- Al cambiar de pestaña o de modo el juego vuelve a mostrar "Solo misiones"
    ZO_PostHook(inventory, "ChangeFilter", AFP.UpdateFilterControls)
    ZO_PostHook(inventory, "UpdateMode", AFP.UpdateFilterControls)
    AFP.UpdateFilterControls(inventory)
end
