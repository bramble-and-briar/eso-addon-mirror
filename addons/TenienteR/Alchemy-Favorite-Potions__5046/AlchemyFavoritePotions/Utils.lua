-- Utilidades generales.
local AFP = AlchemyFavoritePotions

local CHAT_PREFIX = "[Alchemy Favorite Potions] "

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
