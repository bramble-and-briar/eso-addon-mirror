local ADDON_NAME = "BETABars"
BETABars = BETABars or {}
local T = BETABars

local defaults = {
    enabled = true,
    style = "thin",
    hideStock = true,
    hideFull = true,
    showNumbers = false,
    showPercent = false,
    damageTail = true,
    shieldRim = true,
    notches = true,
    scale = 100,
    offsetX = 0,
    offsetY = 220,
    colorH = { 0.80, 0.18, 0.16, 1 },
    colorM = { 0.22, 0.48, 0.95, 1 },
    colorS = { 0.28, 0.72, 0.34, 1 },
    preview = false,
}

function T.Vars()
    return T.savedVars
end

local function OnAddOnLoaded(_, name)
    if name ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    T.savedVars = ZO_SavedVars:NewAccountWide("BETABarsSavedVars", 1, nil, defaults)
    if T.RegisterSettings then T.RegisterSettings() end
    if T.Build then T.Build() end

    if CHAT_ROUTER and T.L and T.L.LOADED then
        CHAT_ROUTER:AddSystemMessage(T.L.LOADED)
    end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
