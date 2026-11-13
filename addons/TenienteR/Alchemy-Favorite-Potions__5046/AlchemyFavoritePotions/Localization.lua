-- Espacio de nombres del addon y acceso a los textos traducidos.
-- Se carga primero; los archivos de lang/ rellenan AFP.strings.
AlchemyFavoritePotions = AlchemyFavoritePotions or {}
local AFP = AlchemyFavoritePotions

AFP.strings = AFP.strings or {}

--- Devuelve el texto traducido; si falta la clave, devuelve la clave misma
function AFP.L(key)
    return AFP.strings[key] or key
end
