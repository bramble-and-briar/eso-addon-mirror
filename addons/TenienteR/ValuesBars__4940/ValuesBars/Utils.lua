--[[
    Utils.lua
    Funciones auxiliares compartidas por el resto de archivos.
]]

ValuesBars = ValuesBars or {}
local VB = ValuesBars

-- Formatos de número disponibles. Para añadir uno nuevo, basta una entrada aquí.
local NUMBER_FORMATTERS = {
    separated = ZO_CommaDelimitNumber,
    plain = function(value) return tostring(zo_round(value)) end,
}

local function FormatNumber(value)
    local formatter = NUMBER_FORMATTERS[VB.sv.numberFormat] or ZO_CommaDelimitNumber
    return formatter(value)
end

-- Devuelve "actual/máximo (porcentaje%)" o "" si los valores no son válidos
function VB.FormatText(current, max)
    if type(current) ~= "number" or type(max) ~= "number" or max <= 0 then
        return ""
    end

    local text = string.format("%s / %s", FormatNumber(current), FormatNumber(max))

    if VB.sv.showPercent then
        text = string.format("%s (%d%%)", text, zo_round((current / max) * 100))
    end

    return text
end

-- Recibe una lista de nombres de control y devuelve el primero que exista
function VB.FindControl(names)
    for _, name in ipairs(names) do
        local control = _G[name]
        if control then return control end
    end
end

-- Construye la cadena de fuente a partir de las opciones guardadas
function VB.BuildFont()
    local sv = VB.sv
    return string.format("%s|%d|%s", sv.fontFace, sv.fontSize, sv.fontStyle)
end
