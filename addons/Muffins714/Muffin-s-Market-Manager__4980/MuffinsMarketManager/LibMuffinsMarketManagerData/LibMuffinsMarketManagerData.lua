-- This holds price data so it gets its own SavedVariables folder
local ADDON_NAME = "LibMuffinsMarketManagerData"

LibMuffinsMarketManagerData = LibMuffinsMarketManagerData or {}
local MMMData = LibMuffinsMarketManagerData

local PRICE_DATA_DEFAULTS = {
    lastListedPrices = {},
}

local function OnAddOnLoaded(event, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    MMMData.SavedVars = ZO_SavedVars:NewAccountWide(
        "LibMMMDataSavedVars",
        1,
        nil,
        PRICE_DATA_DEFAULTS,
        GetWorldName()
    )

    -- Keep SavedVars safe if the file ever gets corrupted
    if type(MMMData.SavedVars.lastListedPrices) ~= "table" then
        MMMData.SavedVars.lastListedPrices = {}
    end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
