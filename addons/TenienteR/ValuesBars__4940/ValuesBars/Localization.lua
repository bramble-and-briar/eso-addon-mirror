--[[
    Localization.lua
    Textos del addon por idioma.

    Cada idioma vive en su propio archivo dentro de lang/ y se registra así:

        ValuesBars.RegisterLanguage("en", { MENU_SHOW_VALUES = "Show values", ... })

    El manifiesto carga dos archivos de idioma, en este orden:
      - lang/en.lua           : idioma base. El PRIMER idioma que se registra es el que
                                se usa cuando falta una traducción.
      - lang/$(language).lua  : el del idioma del cliente (en, de, fr, es...). El juego
                                sustituye $(language) y, si ese archivo no existe, lo omite.

    Para añadir un idioma basta con crear lang/<código>.lua con las mismas claves que
    lang/en.lua. No hay que tocar ningún otro archivo.

    VB.L(clave) devuelve el texto en este orden:
      1. idioma del cliente
      2. idioma base
      3. la propia clave (así un texto sin definir se nota en pantalla)
]]

ValuesBars = ValuesBars or {}
local VB = ValuesBars

VB.strings = {}
VB.baseLanguage = nil -- se fija con el primer idioma que se registra

function VB.RegisterLanguage(code, strings)
    VB.strings[code] = strings
    VB.baseLanguage = VB.baseLanguage or code
end

-- El idioma del cliente no cambia mientras el juego está abierto
local clientLanguage = GetCVar("language.2")

local function Lookup(code, key)
    local strings = VB.strings[code]
    return strings and strings[key]
end

function VB.L(key)
    return Lookup(clientLanguage, key) or Lookup(VB.baseLanguage, key) or key
end
