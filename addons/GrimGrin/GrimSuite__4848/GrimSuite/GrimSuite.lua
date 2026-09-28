GrimSuite = GrimSuite or {}
local GS = GrimSuite

GS.name = "GrimSuite"
GS.version = "1.3.0"

GS.SV = {
    gcd = 1000,
    showGCD = true,
    showWeave = true,
    showWeaveMs = true,
    gcdX = 1115,
    gcdY = 1176,
    gcdWidth = 330,
    gcdHeight = 30,
    weaveX = 980,
    weaveY = 1139,
    weaveWidth = 600,
    weaveHeight = 30,
    weaveAverageX = 617,
    weaveAverageY = 7,
    attributesX = 0,
    attributesY = 375,
}

local function LoadSavedVars()
    GS.Saved = ZO_SavedVars:NewAccountWide("GrimSuiteSavedVars", 1, nil, GS.SV)
end

local function Initialize()
    LoadSavedVars()
    GS.Combat:Initialize()
    GS.ActionBar:Initialize()
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= GS.name then return end
    EVENT_MANAGER:UnregisterForEvent(GS.name .. "_Load")
    Initialize()
end

EVENT_MANAGER:RegisterForEvent(GS.name .. "_Load", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
