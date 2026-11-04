-- Utilidades: nombres de habilidades y unidades, tiempo y colores.

local VG = Vigilant
local U = {}
VG.Utils = U

local floor, ceil = math.floor, math.ceil
local ABILITY_FMT = GetString(SI_ABILITY_NAME)
local UNIT_FMT = GetString(SI_UNIT_NAME)

function U.Trim(s)
    return s:match("^%s*(.-)%s*$")
end

-- Nombre de habilidad tal como lo muestra el juego (sin sufijos de género ^m, ^f...).
function U.FormatAbility(name)
    return zo_strformat(ABILITY_FMT, name)
end

-- Nombre de efecto listo para comparar: formateado y en minúsculas.
-- Se guarda en caché porque se llama en cada evento de efecto del grupo.
local normCache = {}
function U.NormName(name)
    if name == "" then return nil end
    local n = normCache[name]
    if not n then
        n = zo_strlower(U.FormatAbility(name))
        normCache[name] = n
    end
    return n
end

function U.AbilityName(abilityId)
    local name = GetAbilityName(abilityId)
    if name ~= "" then return U.FormatAbility(name) end
    return nil
end

function U.UnitName(unitTag)
    return zo_strformat(UNIT_FMT, GetUnitName(unitTag))
end

-- 125 -> "2m", 42 -> "42", 3.2 -> "4"
function U.FormatTime(sec)
    if sec <= 0 then return "" end
    if sec >= 60 then return string.format("%dm", floor(sec / 60)) end
    return string.format("%d", ceil(sec))
end

function U.Color(c)
    return c[1], c[2], c[3], c[4]
end
