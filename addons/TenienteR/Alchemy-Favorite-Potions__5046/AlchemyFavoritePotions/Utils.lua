-- Utilidades generales.
local AFP = AlchemyFavoritePotions

local CHAT_PREFIX = "[Alchemy Favorite Potions] "
-- Separación entre el cuadro de una casilla y su texto
local CHECKBOX_LABEL_GAP = 4

--- Escribe un mensaje en el chat con el prefijo del addon
function AFP.Print(text)
    d(CHAT_PREFIX .. text)
end

--- Ruta de una textura del addon.
-- La carpeta cambia según la versión cargada (AlchemyFavoritePotions o AlchemyFavoritePotionsDev).
function AFP.GetTexturePath(fileName)
    local folderName = AFP.isDev and AFP.devName or AFP.name
    return string.format("%s/textures/%s.dds", folderName, fileName)
end

--- Crea una casilla con la plantilla del juego.
-- El estado inicial se pone antes de asignar la función, para que no se dispare al crearla.
function AFP.CreateCheckBox(name, parent, labelText, isChecked, onToggle)
    local checkBox = WINDOW_MANAGER:CreateControlFromVirtual(name, parent, "ZO_CheckButton")
    ZO_CheckButton_SetLabelText(checkBox, labelText)
    ZO_CheckButton_SetCheckState(checkBox, isChecked)
    ZO_CheckButton_SetToggleFunction(checkBox, onToggle)
    return checkBox
end

--- Ancho que ocupa una casilla con su texto (cuadro + separación + texto)
function AFP.GetCheckBoxWidth(checkBox)
    local label = checkBox.label or checkBox:GetNamedChild("Label")
    local labelWidth = label and label:GetTextWidth() or 0
    return checkBox:GetWidth() + CHECKBOX_LABEL_GAP + labelWidth
end

--- Texto de lista vacía según el filtro de tipo (nil: sin filtro, ni pociones ni venenos)
function AFP.GetNoFavoritesText(kind)
    if kind == AFP.KIND.POTION then
        return AFP.L("NO_FAVORITE_POTIONS")
    elseif kind == AFP.KIND.POISON then
        return AFP.L("NO_FAVORITE_POISONS")
    end
    return AFP.L("NO_FAVORITES")
end
