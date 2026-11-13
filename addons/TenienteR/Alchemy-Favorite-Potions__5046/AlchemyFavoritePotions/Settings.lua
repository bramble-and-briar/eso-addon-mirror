-- Nombres, versión de SavedVariables y valores por defecto.
AlchemyFavoritePotions = AlchemyFavoritePotions or {}
local AFP = AlchemyFavoritePotions

AFP.name = "AlchemyFavoritePotions"
AFP.devName = AFP.name .. "Dev"
AFP.svName = AFP.name .. "_SV"
AFP.devSvName = AFP.devName .. "_SV"

-- Subir solo si cambia la estructura de los datos (la comparación es por igualdad)
AFP.svVersion = 1

AFP.defaults = {
    favorites = {},
    -- Contador que solo sube: da a cada favorita un número para ordenarlas, aunque se borren otras
    lastFavoriteId = 0,
    -- true: las nuevas van al principio de la lista; false: al final
    newestFirst = true,
}
