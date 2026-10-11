--[[
    Ultimate.lua
    Porcentaje de la habilidad máxima sobre su botón de la barra de acciones.
    100% significa que la habilidad máxima está lista; puede superarlo si acumulas más puntos.
]]

ValuesBars = ValuesBars or {}
local VB = ValuesBars

local ULTIMATE = COMBAT_MECHANIC_FLAGS_ULTIMATE
local SLOT = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1 -- indice 1-based, como lo usa el juego

-- Devuelve (puntos actuales, coste de la habilidad máxima equipada en la barra activa)
local function GetUltimateValues()
    local current = GetUnitPower("player", ULTIMATE)
    local cost = GetSlotAbilityCost(SLOT, ULTIMATE, GetActiveHotbarCategory())
    return current, cost
end

local function FormatUltimate(current, cost)
    if not VB.sv.showUltimatePercent then return "" end
    -- Sin habilidad máxima equipada el coste es 0: no se muestra nada
    if type(current) ~= "number" or type(cost) ~= "number" or cost <= 0 then
        return ""
    end
    -- floor y no round: así "100%" solo aparece cuando de verdad está lista
    return string.format("%d%%", zo_floor((current / cost) * 100))
end

local ULTIMATE_PADDING = 2 -- separación en px respecto al borde del botón

local ANCHORS = {
    top    = { point = TOP, direction = 1 },
    center = { point = CENTER, direction = 0 },
    bottom = { point = BOTTOM, direction = -1 },
}

-- Coloca el texto dentro del botón: siempre se ancla al propio botón, nunca fuera
local function ApplyUltimatePosition(label)
    local anchor = ANCHORS[VB.sv.ultimatePosition] or ANCHORS.center
    local offsets = VB.STYLE_OFFSET_Y and VB.STYLE_OFFSET_Y[VB.sv.fontStyle]
    local fontOffset = offsets and offsets.inside or 0

    label:ClearAnchors()
    label:SetAnchor(anchor.point, label:GetParent(), anchor.point, 0, anchor.direction * ULTIMATE_PADDING + fontOffset)
end

VB.RegisterSource({
    id = "ultimate",
    controls = { "ActionButton" .. SLOT },
    unitTags = { "player" },
    powerType = ULTIMATE,
    values = GetUltimateValues,
    format = FormatUltimate,
    applyPosition = ApplyUltimatePosition,
    events = {
        EVENT_ACTIVE_WEAPON_PAIR_CHANGED,
        EVENT_ULTIMATE_ABILITY_COST_CHANGED,
        EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED,
    },
})
