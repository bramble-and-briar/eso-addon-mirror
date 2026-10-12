--[[
    Settings.lua
    Nombre del addon, versión de las SavedVariables y valores por defecto.
    Aqui se añadiran nuevas opciones de configuración.
]]

ValuesBars = ValuesBars or {}
local VB = ValuesBars

VB.name = "ValuesBars"
VB.version = "1.0.1" -- mantener igual que ## Version en ValuesBars.txt
VB.svVersion = 14 -- subir solo si cambia la estructura de las SavedVariables

VB.defaults = {
    enabled = true,
    fontFace = "$(BOLD_FONT)",
    fontSize = 16,
    fontStyle = "soft-shadow-thick",
    showPercent = true,
    color = { r = 1, g = 1, b = 1, a = 0.9 },
    playerBarsPosition = "inside", -- "inside", "above" o "below"
    numberFormat = "plain",        -- "separated" (12,345) o "plain" (12345)
    textGap = 2,                   -- separación en px entre el texto y la barra (solo encima o debajo)
    magickaAlign = "center",       -- "center" o "right"
    staminaAlign = "center",       -- "center" o "left"
    xpAlign = "center",            -- "center" o "left"
    showUltimatePercent = true,
    ultimatePosition = "center",   -- "top", "center" o "bottom"
}
