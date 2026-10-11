--[[
    Experience.lua
    Barra de experiencia: nivel normal (1-50) y puntos de campeón.
]]

ValuesBars = ValuesBars or {}
local VB = ValuesBars

local function GetXPValues()
    if IsUnitChampion("player") then
        local points = GetPlayerChampionPointsEarned()
        return GetPlayerChampionXP(), GetNumChampionXPInChampionPoint(points)
    end
    return GetUnitXP("player"), GetUnitXPMax("player")
end

VB.RegisterSource({
    id = "xp",
    controls = { "ZO_PlayerProgressBar", "ZO_PlayerProgress" },
    values = GetXPValues,
    events = { EVENT_EXPERIENCE_UPDATE, EVENT_LEVEL_UPDATE, EVENT_CHAMPION_POINT_UPDATE },
})
