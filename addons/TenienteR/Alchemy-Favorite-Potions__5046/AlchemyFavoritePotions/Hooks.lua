-- Ganchos sobre la interfaz de alquimia del teclado (ALCHEMY):
-- pestaña de favoritas y su lista de filas.
local AFP = AlchemyFavoritePotions

-- Descriptor de la pestaña: no coincide con ningún tipo de objeto del juego
local FAVORITES_FILTER = "AlchemyFavoritePotionsFavorites"
AFP.FAVORITES_FILTER = FAVORITES_FILTER
-- Tipo de dato de la lista; el juego usa 1 y 2 para solventes y reactivos
local FAVORITE_DATA_TYPE = 100
local FAVORITE_ROW_TEMPLATE = "AlchemyFavoritePotions_Row"
local FAVORITE_ROW_HEIGHT = 108
local DEFAULT_NAME_QUALITY = ITEM_DISPLAY_QUALITY_MAGIC or 2
-- Fila de una favorita que no se puede preparar, y color del ingrediente que falta
local UNAVAILABLE_ROW_ALPHA = 0.5
local MISSING_INGREDIENT_COLOR = { 0.85, 0.3, 0.3 }

--- Reconstruye las pestañas del juego añadiendo la de favoritas.
-- Es una réplica de ZO_AlchemyInventory:Initialize (alchemy_keyboard.lua). La de favoritas va
-- la primera porque el juego selecciona por defecto la última pestaña, que debe seguir siendo "Todo".
local function SetupTabs(inventory)
    local favoritesTab = inventory:CreateNewTabFilterData(
        FAVORITES_FILTER,
        AFP.L("TAB_FAVORITES"),
        AFP.GetTexturePath("heart_up"),
        AFP.GetTexturePath("heart_down"),
        AFP.GetTexturePath("heart_over"),
        AFP.GetTexturePath("heart_disabled")
    )
    local reagentsTab = inventory:CreateNewTabFilterData(
        ITEMTYPE_REAGENT,
        GetString(SI_ALCHEMY_REAGENTS_TAB),
        "EsoUI/Art/Crafting/alchemy_tabIcon_reagent_up.dds",
        "EsoUI/Art/Crafting/alchemy_tabIcon_reagent_down.dds",
        "EsoUI/Art/Crafting/alchemy_tabIcon_reagent_over.dds",
        "EsoUI/Art/Crafting/alchemy_tabIcon_reagent_disabled.dds"
    )
    local solventsTab = inventory:CreateNewTabFilterData(
        IsAlchemySolvent,
        GetString(SI_ALCHEMY_SOLVENT_TAB),
        "EsoUI/Art/Crafting/alchemy_tabIcon_solvent_up.dds",
        "EsoUI/Art/Crafting/alchemy_tabIcon_solvent_down.dds",
        "EsoUI/Art/Crafting/alchemy_tabIcon_solvent_over.dds",
        "EsoUI/Art/Crafting/alchemy_tabIcon_solvent_disabled.dds"
    )
    local allTab = inventory:CreateNewTabFilterData(
        nil,
        GetString("SI_ITEMFILTERTYPE", ITEMFILTERTYPE_ALL),
        "EsoUI/Art/Inventory/inventory_tabIcon_all_up.dds",
        "EsoUI/Art/Inventory/inventory_tabIcon_all_down.dds",
        "EsoUI/Art/Inventory/inventory_tabIcon_all_over.dds",
        "EsoUI/Art/Inventory/inventory_tabIcon_all_disabled.dds"
    )

    inventory:SetFilters({ favoritesTab, reagentsTab, solventsTab, allTab })
end

--- Dibuja una fila de favorita con los datos de AFP.GetFavoriteRows()
local function SetupFavoriteRow(rowControl, data)
    rowControl.favoriteData = data

    rowControl.icon:SetTexture(data.icon)
    rowControl.name:SetText(data.name)
    local nameRed, nameGreen, nameBlue = GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS,
        data.displayQuality or DEFAULT_NAME_QUALITY)
    rowControl.name:SetColor(nameRed, nameGreen, nameBlue, 1)

    rowControl:SetAlpha(data.problems and UNAVAILABLE_ROW_ALPHA or 1)

    local textRed, textGreen, textBlue = GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_TOOLTIP, ITEM_TOOLTIP_COLOR_ACCENT)
    for index, label in ipairs(rowControl.ingredientLabels) do
        local ingredient = data.ingredients[index]
        if ingredient then
            label:SetHidden(false)
            label:SetText(ingredient.name)
            if ingredient.isMissing then
                label:SetColor(MISSING_INGREDIENT_COLOR[1], MISSING_INGREDIENT_COLOR[2], MISSING_INGREDIENT_COLOR[3], 1)
            else
                label:SetColor(textRed, textGreen, textBlue, 1)
            end
            label.icon:SetTexture(ingredient.icon)
        else
            label:SetHidden(true)
        end
    end
end

--- Limpia la fila cuando el juego la devuelve al pool.
--- Al pasar un reset propio, el juego ya no aplica el suyo, así que hay que ocultar la fila aquí
local function ResetFavoriteRow(rowControl)
    if rowControl.isShowingTooltip then
        rowControl.isShowingTooltip = false
        ClearTooltip(InformationTooltip)
    end

    rowControl:SetHidden(true)
    rowControl.favoriteData = nil
    rowControl.highlight:SetHidden(true)
end

--- Sustituye Refresh y SortData de la lista solo mientras está activa la pestaña de favoritas
local function InstallListOverrides(inventory)
    local baseRefresh = inventory.Refresh
    inventory.Refresh = function(self, data)
        if self.filterType ~= FAVORITES_FILTER then
            return baseRefresh(self, data)
        end

        for _, favorite in ipairs(AFP.GetFavoriteRows()) do
            data[#data + 1] = ZO_ScrollList_CreateDataEntry(FAVORITE_DATA_TYPE, favorite)
        end

        self:SetNoItemLabelText(AFP.L("NO_FAVORITES"))
        self:SetNoItemLabelHidden(#data > 0)
    end

    -- El orden de las favoritas lo decide AFP.GetFavoriteRows, no el criterio de orden del juego
    local baseSortData = inventory.SortData
    inventory.SortData = function(self)
        if self.filterType ~= FAVORITES_FILTER then
            return baseSortData(self)
        end
    end
end

--- Vuelve a dibujar la lista si está abierta la pestaña de favoritas (tras añadir o quitar una)
function AFP.RefreshFavoritesList()
    local inventory = ALCHEMY and ALCHEMY.inventory
    if inventory and inventory.filterType == FAVORITES_FILTER then
        inventory:HandleDirtyEvent()
    end
end

--- Muestra el tooltip de la fila: el texto completo de la etiqueta si está cortado
-- y los motivos por los que no se puede preparar. Si no hay nada que decir, no muestra nada.
local function ShowRowTooltip(rowControl, label)
    local lines = {}

    if label and label:WasTruncated() then
        lines[#lines + 1] = label:GetText()
    end

    local problems = rowControl.favoriteData and rowControl.favoriteData.problems
    if problems then
        lines[#lines + 1] = AFP.GetProblemsText(problems)
    end

    if #lines == 0 then
        return
    end

    -- A la izquierda de la fila: la lista está a la derecha de la pantalla
    rowControl.isShowingTooltip = true
    InitializeTooltip(InformationTooltip, rowControl, RIGHT, -10, 0)
    SetTooltipText(InformationTooltip, table.concat(lines, "\n\n"))
end

--- label es la etiqueta bajo el ratón, o nil si el ratón está sobre la fila
function AFP.OnFavoriteRowMouseEnter(rowControl, label)
    rowControl.highlight:SetHidden(false)
    ShowRowTooltip(rowControl, label)
end

function AFP.OnFavoriteRowMouseExit(rowControl)
    rowControl.highlight:SetHidden(true)

    if rowControl.isShowingTooltip then
        rowControl.isShowingTooltip = false
        ClearTooltip(InformationTooltip)
    end
end

--- Quita una favorita de la lista y refresca la pantalla
local function RemoveFavoriteFromList(favorite)
    AFP.RemoveFavorite(favorite)
    AFP.RefreshFavoritesList()
    AFP.UpdateSlotButton()
end

--- Menú del clic derecho sobre una fila: permite quitarla de favoritos
local function ShowFavoriteRowMenu(rowControl)
    local favorite = rowControl.favoriteData.favorite

    ClearMenu()
    AddMenuItem(AFP.L("SLOT_BUTTON_REMOVE"), function()
        RemoveFavoriteFromList(favorite)
    end)
    ShowMenu(rowControl)
end

function AFP.OnFavoriteRowMouseUp(rowControl, button, upInside)
    if not upInside or not rowControl.favoriteData then
        return
    end

    if button == MOUSE_BUTTON_INDEX_LEFT then
        AFP.OnFavoriteSelected(rowControl.favoriteData)
    elseif button == MOUSE_BUTTON_INDEX_RIGHT then
        ShowFavoriteRowMenu(rowControl)
    end
end

--- Instala todos los ganchos. Se llama una sola vez al cargar el addon.
function AFP.InstallHooks()
    if AFP.hooksInstalled then
        return
    end

    local inventory = ALCHEMY and ALCHEMY.inventory
    if not inventory then
        error("ALCHEMY.inventory not found")
    end

    SetupTabs(inventory)
    ZO_ScrollList_AddDataType(inventory.list, FAVORITE_DATA_TYPE, FAVORITE_ROW_TEMPLATE, FAVORITE_ROW_HEIGHT,
        SetupFavoriteRow, nil, nil, ResetFavoriteRow)
    InstallListOverrides(inventory)
    AFP.CreateOrderToggle(inventory)
    -- Al desbloquear la tercera ranura cambia qué favoritas se pueden preparar
    ZO_PostHook(ALCHEMY, "UpdateThirdAlchemySlot", AFP.RefreshFavoritesList)
    AFP.CreateSlotButton()

    AFP.hooksInstalled = true
end
