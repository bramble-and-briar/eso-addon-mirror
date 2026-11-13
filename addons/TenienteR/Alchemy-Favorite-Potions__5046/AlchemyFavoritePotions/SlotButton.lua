-- Botón de favoritos en la barra de atajos de la mesa de alquimia (entre "Fabricar" y "Eliminar selecciones").
-- Guarda la combinación puesta como favorita o la quita si ya lo es.
local AFP = AlchemyFavoritePotions

-- Acción definida en Bindings.xml; el jugador le asigna la tecla en Controles
local KEYBIND_ACTION = "ALCHEMY_FAVORITE_POTIONS_TOGGLE"
-- Posición del botón en la barra: después de "Fabricar", antes de "Eliminar selecciones"
local STRIP_INDEX = 2

-- Nombre de la acción en el menú de controles (debe existir antes de que el juego lea Bindings.xml)
ZO_CreateStringId("SI_BINDING_NAME_" .. KEYBIND_ACTION, AFP.L("KEYBIND_NAME"))

--- Devuelve la combinación actual y si ya es favorita
local function GetCurrentState()
    local combination, status = AFP.GetCurrentCombination()
    return combination, status, combination ~= nil and AFP.IsFavorite(combination)
end

local function GetButtonName()
    local combination, _, isFavorite = GetCurrentState()
    if combination and isFavorite then
        return AFP.L("SLOT_BUTTON_REMOVE")
    end
    return AFP.L("SLOT_BUTTON_ADD")
end

local function IsButtonEnabled()
    return GetCurrentState() ~= nil
end

local function OnButtonPressed()
    local combination, _, isFavorite = GetCurrentState()
    if not combination then
        -- Mismo aviso que antes se mostraba en el tooltip
        local status = select(2, GetCurrentState())
        local statuses = AFP.COMBINATION_STATUS
        local key = "SLOT_BUTTON_INCOMPLETE"
        if status == statuses.INVALID then
            key = "SLOT_BUTTON_INVALID"
        elseif status == statuses.UNKNOWN then
            key = "SLOT_BUTTON_UNKNOWN"
        end
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEGATIVE_CLICK, AFP.L(key))
        return
    end

    PlaySound(SOUNDS.DEFAULT_CLICK)

    if isFavorite then
        AFP.RemoveFavorite(combination)
    else
        AFP.AddFavorite(combination)
    end

    AFP.UpdateSlotButton()
    AFP.RefreshFavoritesList()
end

--- Refresca el nombre y el estado (activo/inactivo) del botón en la barra
function AFP.UpdateSlotButton()
    local descriptor = ALCHEMY.keybindStripDescriptor
    if KEYBIND_STRIP:HasKeybindButtonGroup(descriptor) then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(descriptor)
    end
end

--- Añade el botón al grupo de atajos de la mesa de alquimia.
-- Se inserta en la tabla antes de que la escena la registre en la barra.
function AFP.CreateSlotButton()
    if AFP.slotButtonDescriptor then
        return
    end

    AFP.slotButtonDescriptor = {
        name = GetButtonName,
        keybind = KEYBIND_ACTION,
        enabled = IsButtonEnabled,
        callback = OnButtonPressed,
    }
    table.insert(ALCHEMY.keybindStripDescriptor, STRIP_INDEX, AFP.slotButtonDescriptor)

    -- El juego avisa de cualquier cambio en las ranuras con OnSlotChanged
    ZO_PostHook(ALCHEMY, "OnSlotChanged", AFP.UpdateSlotButton)
end
