--[[
    PlayerBars.lua
    Salud, magia y aguante del personaje.
]]

ValuesBars = ValuesBars or {}
local VB = ValuesBars

local function RegisterPlayerBar(id, controlName, powerType)
    VB.RegisterSource({
        id = id,
        controls = { controlName },
        unitTags = { "player" },
        powerType = powerType,
        positionable = true,
        values = function() return GetUnitPower("player", powerType) end,
    })
end

RegisterPlayerBar("health", "ZO_PlayerAttributeHealth", COMBAT_MECHANIC_FLAGS_HEALTH)
RegisterPlayerBar("magicka", "ZO_PlayerAttributeMagicka", COMBAT_MECHANIC_FLAGS_MAGICKA)
RegisterPlayerBar("stamina", "ZO_PlayerAttributeStamina", COMBAT_MECHANIC_FLAGS_STAMINA)
