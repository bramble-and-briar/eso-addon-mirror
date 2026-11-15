-- Casillas "Solo pociones" y "Solo venenos" de la pestaña de favoritas.
-- Son excluyentes: el filtro es una sola variable (AFP.stationKind) con tres valores posibles:
-- nil (todas), AFP.KIND.POTION o AFP.KIND.POISON. No se guarda: cada vez que se vuelve
-- a la pestaña de favoritas empieza en "todas".
local AFP = AlchemyFavoritePotions

local POTIONS_NAME = "AlchemyFavoritePotionsPotionsOnly"
local POISONS_NAME = "AlchemyFavoritePotionsPoisonsOnly"
-- Posición de reserva respecto a "Solo misiones" (si no se encuentra la barra de pestañas)
local FALLBACK_FIRST_OFFSET_X = 180
local FALLBACK_SPACING_X = 140
-- Separación entre las dos casillas
local CHECKBOXES_GAP = 20

local potionsCheckBox
local poisonsCheckBox

--- Alinea las casillas al borde derecho de la barra de pestañas (el borde del corazón)
local function AlignCheckBoxes(inventory)
    local tabs = inventory.control:GetNamedChild("Tabs")
    local anchor = inventory.questFilterCheckButton
    local right = tabs and tabs:GetRight() or 0
    local left = anchor:GetLeft()

    local poisonsX, potionsX
    if right > 0 and left > 0 then
        poisonsX = right - left - AFP.GetCheckBoxWidth(poisonsCheckBox)
        potionsX = poisonsX - CHECKBOXES_GAP - AFP.GetCheckBoxWidth(potionsCheckBox)
    else
        potionsX = FALLBACK_FIRST_OFFSET_X
        poisonsX = FALLBACK_FIRST_OFFSET_X + FALLBACK_SPACING_X
    end

    potionsCheckBox:ClearAnchors()
    potionsCheckBox:SetAnchor(TOPLEFT, anchor, TOPLEFT, potionsX, 0)
    poisonsCheckBox:ClearAnchors()
    poisonsCheckBox:SetAnchor(TOPLEFT, anchor, TOPLEFT, poisonsX, 0)
end

--- Deja las casillas igual que el filtro
local function SyncCheckBoxes()
    ZO_CheckButton_SetCheckState(potionsCheckBox, AFP.stationKind == AFP.KIND.POTION)
    ZO_CheckButton_SetCheckState(poisonsCheckBox, AFP.stationKind == AFP.KIND.POISON)
end

local function SetKind(kind)
    AFP.stationKind = kind
    SyncCheckBoxes()
    AFP.RefreshFavoritesList()
end

local function CreateKindCheckBox(name, inventory, textKey, kind)
    local checkBox
    checkBox = AFP.CreateCheckBox(name, inventory.control, AFP.L(textKey), false, function()
        -- Marcar una desmarca la otra; desmarcar la activa vuelve a mostrar todas
        SetKind(ZO_CheckButton_IsChecked(checkBox) and kind or nil)
    end)
    checkBox:SetAnchor(TOPLEFT, inventory.questFilterCheckButton, TOPLEFT, 0, 0)

    -- Igual que "Solo misiones", se bloquean mientras se fabrica
    ZO_CraftingUtils_ConnectCheckBoxToCraftingProcess(checkBox)
    AFP.AddFavoritesTabControl(checkBox)
    return checkBox
end

function AFP.CreateKindFilters(inventory)
    if potionsCheckBox then
        return
    end

    potionsCheckBox = CreateKindCheckBox(POTIONS_NAME, inventory,
        "KIND_POTIONS_ONLY", AFP.KIND.POTION)
    poisonsCheckBox = CreateKindCheckBox(POISONS_NAME, inventory,
        "KIND_POISONS_ONLY", AFP.KIND.POISON)

    AlignCheckBoxes(inventory)
    -- El borde de la barra solo es fiable con la pestaña a la vista: se recalcula al entrar en ella
    local function OnTabChanged(self)
        if self.filterType == AFP.FAVORITES_FILTER then
            AlignCheckBoxes(self)
        end
    end
    ZO_PostHook(inventory, "UpdateMode", OnTabChanged)

    -- Al salir de la pestaña de favoritas el filtro se borra
    ZO_PostHook(inventory, "ChangeFilter", function(self)
        OnTabChanged(self)
        if self.filterType ~= AFP.FAVORITES_FILTER and AFP.stationKind then
            AFP.stationKind = nil
            SyncCheckBoxes()
        end
    end)
end
