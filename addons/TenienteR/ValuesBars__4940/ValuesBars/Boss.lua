--[[
    Boss.lua
    Salud combinada de todos los jefes (boss1 .. bossN) sobre la barra grande.
    Se recuerda la última salud conocida de cada jefe: si uno muere y desaparece
    a mitad del combate, sigue contando y el porcentaje no se reinicia de golpe.
]]

ValuesBars = ValuesBars or {}
local VB = ValuesBars

local MAX_BOSS_UNITS = MAX_BOSSES or 6
local bossCache = {}

local unitTags = {}
for i = 1, MAX_BOSS_UNITS do
    unitTags[i] = "boss" .. i
end

local function GetBossValues()
    local anyAlive = false

    for _, unitTag in ipairs(unitTags) do
        if DoesUnitExist(unitTag) then
            anyAlive = true
            local c, m = GetUnitPower(unitTag, COMBAT_MECHANIC_FLAGS_HEALTH)
            bossCache[unitTag] = { current = c or 0, max = m or 0 }
        end
    end

    -- Sin ningún jefe presente, el encuentro terminó: se limpia la memoria
    if not anyAlive then
        ZO_ClearTable(bossCache)
        return 0, 0
    end

    local current, max = 0, 0
    for _, entry in pairs(bossCache) do
        current = current + entry.current
        max = max + entry.max
    end
    return current, max
end

VB.RegisterSource({
    id = "boss",
    controls = { "ZO_BossBarHealth", "ZO_BossBar" },
    unitTagPrefix = "boss",
    powerType = COMBAT_MECHANIC_FLAGS_HEALTH,
    values = GetBossValues,
    events = { EVENT_BOSSES_CHANGED },
})
