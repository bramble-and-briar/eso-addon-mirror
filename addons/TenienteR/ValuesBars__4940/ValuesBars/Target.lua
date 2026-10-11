--[[
    Target.lua
    Salud del objetivo enfocado (NPCs, enemigos, otros jugadores).
]]

ValuesBars = ValuesBars or {}
local VB = ValuesBars

VB.RegisterSource({
    id = "target",
    controls = { "ZO_TargetUnitFramereticleover" },
    unitTags = { "reticleover" },
    powerType = COMBAT_MECHANIC_FLAGS_HEALTH,
    values = function() return GetUnitPower("reticleover", COMBAT_MECHANIC_FLAGS_HEALTH) end,
    events = { EVENT_RETICLE_TARGET_CHANGED },
})
