-- Controles propios de la pestaña de favoritas: casilla "Añadir al principio / al final"
-- (ocupa el sitio de "Solo misiones", que ahí no hace nada) y las casillas de KindFilters.lua.
-- Solo se ven en esa pestaña.
local AFP = AlchemyFavoritePotions

local TOGGLE_NAME = "AlchemyFavoritePotionsOrderToggle"

-- Controles que solo se ven en la pestaña de favoritas
local favoritesTabControls = {}

local function GetToggleLabel(isNewestFirst)
    return AFP.L(isNewestFirst and "ORDER_NEWEST_FIRST" or "ORDER_NEWEST_LAST")
end

--- Registra un control que solo debe verse en la pestaña de favoritas
function AFP.AddFavoritesTabControl(control)
    control:SetHidden(true)
    favoritesTabControls[#favoritesTabControls + 1] = control
end

--- Enseña los controles propios en la pestaña de favoritas y la de "Solo misiones" en las demás
function AFP.UpdateFilterControls(inventory)
    if not AFP.orderToggle then
        return
    end

    local isFavoritesTab = inventory.filterType == AFP.FAVORITES_FILTER
    inventory.questFilterCheckButton:SetHidden(isFavoritesTab)
    for _, control in ipairs(favoritesTabControls) do
        control:SetHidden(not isFavoritesTab)
    end
end

function AFP.CreateOrderToggle(inventory)
    if AFP.orderToggle then
        return
    end

    local toggle
    toggle = AFP.CreateCheckBox(TOGGLE_NAME, inventory.control, GetToggleLabel(AFP.IsNewestFirst()),
        AFP.IsNewestFirst(), function()
            local isNewestFirst = ZO_CheckButton_IsChecked(toggle)
            AFP.SetNewestFirst(isNewestFirst)
            ZO_CheckButton_SetLabelText(toggle, GetToggleLabel(isNewestFirst))
            AFP.RefreshFavoritesList()
        end)
    -- Misma posición que "Solo misiones"
    toggle:SetAnchor(TOPLEFT, inventory.questFilterCheckButton, TOPLEFT, 0, 0)

    -- Igual que "Solo misiones", se bloquea mientras se fabrica
    ZO_CraftingUtils_ConnectCheckBoxToCraftingProcess(toggle)

    AFP.AddFavoritesTabControl(toggle)
    AFP.orderToggle = toggle

    -- Al cambiar de pestaña o de modo el juego vuelve a mostrar "Solo misiones"
    ZO_PostHook(inventory, "ChangeFilter", AFP.UpdateFilterControls)
    ZO_PostHook(inventory, "UpdateMode", AFP.UpdateFilterControls)
    AFP.UpdateFilterControls(inventory)
end
