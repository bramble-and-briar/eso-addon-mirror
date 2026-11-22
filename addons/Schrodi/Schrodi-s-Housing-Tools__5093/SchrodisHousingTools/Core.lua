SchrodisHousingTools = {}
local SHT = SchrodisHousingTools

SHT.ADDON_NAME = "SchrodisHousingTools"
SHT.SORT_KEY_NAME = "name"
SHT.SORT_KEY_DISTANCE = "distance"

local defaults =
{
    sortKey = SHT.SORT_KEY_DISTANCE,
    sortOrder = ZO_SORT_ORDER_UP, -- UP = ascending (A->Z, nearest first)
    rightClickStore = false,
    boundToVault = false,
}

-- The two addons this one replaces. If either is still enabled, its part is skipped here,
-- otherwise every hook would be installed twice (double sort headers, double dropdowns).
local LEGACY_ADDONS =
{
    HousingRetrieveSort = "housing editor",
    FurnitureVaultFilters = "Furniture Vault",
}

local function GetEnabledLegacyAddons()
    local enabled = {}
    local manager = GetAddOnManager()
    for i = 1, manager:GetNumAddOns() do
        local name, _, _, _, isEnabled = manager:GetAddOnInfo(i)
        if isEnabled and LEGACY_ADDONS[name] then
            enabled[name] = true
        end
    end
    return enabled
end

local function WarnAboutLegacyAddons(legacy)
    local names = {}
    for name in pairs(legacy) do
        names[#names + 1] = name
    end
    if #names == 0 then
        return
    end
    table.sort(names)
    local message = string.format(
        "|cFFAA33Schrodi's Housing Tools:|r %s replaced by this addon and still enabled. Its features are skipped here until you disable it in the AddOns menu.",
        table.concat(names, " and ") .. (#names == 1 and " is" or " are"))
    -- Chat is not ready at EVENT_ADD_ON_LOADED.
    EVENT_MANAGER:RegisterForEvent(SHT.ADDON_NAME .. "Warn", EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(SHT.ADDON_NAME .. "Warn", EVENT_PLAYER_ACTIVATED)
        CHAT_ROUTER:AddSystemMessage(message)
    end)
end

function SHT.Msg(text)
    CHAT_ROUTER:AddSystemMessage("|c7FD4FFHousing Tools:|r " .. text)
end

local HOUSING_RESULT_TEXT =
{
    [HOUSING_REQUEST_RESULT_PERMISSION_FAILED] = "Insufficient permissions.",
    [HOUSING_REQUEST_RESULT_NO_SUCH_FURNITURE] = "Furniture not found.",
    [HOUSING_REQUEST_RESULT_PLACE_FAILED] = "Over the furnishing limit.",
    [HOUSING_REQUEST_RESULT_HIGH_IMPACT_COLLECTIBLE_PLACE_LIMIT] = "Over the furnishing limit.",
    [HOUSING_REQUEST_RESULT_MOVE_FAILED] = "Move failed.",
    [HOUSING_REQUEST_RESULT_ALREADY_BEING_MOVED] = "Already being moved.",
    [HOUSING_REQUEST_RESULT_REQUEST_IN_PROGRESS] = "Request in progress.",
    [HOUSING_REQUEST_RESULT_NOT_IN_HOUSE] = "Not in a house.",
    [HOUSING_REQUEST_RESULT_IN_COMBAT] = "In combat.",
}

function SHT.FormatHousingResult(result)
    if result == nil or result == HOUSING_REQUEST_RESULT_SUCCESS then return "" end
    return HOUSING_RESULT_TEXT[result] or ("Error " .. tostring(result) .. ".")
end

local function IsAddOnEnabled(wantedName)
    local manager = GetAddOnManager()
    for i = 1, manager:GetNumAddOns() do
        local name, _, _, _, isEnabled = manager:GetAddOnInfo(i)
        if name == wantedName then
            return isEnabled
        end
    end
    return false
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= SHT.ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(SHT.ADDON_NAME, EVENT_ADD_ON_LOADED)

    SHT.sv = ZO_SavedVars:NewAccountWide("SchrodisHousingTools_SV", 1, nil, defaults)

    local legacy = GetEnabledLegacyAddons()
    WarnAboutLegacyAddons(legacy)

    if not legacy.HousingRetrieveSort then
        SHT.InitializeHousingEditor(SHT.sv)
    end
    if not legacy.FurnitureVaultFilters then
        SHT.InitializeFurnitureVault()
    end

    -- Essential Housing Tools has its own way to summon assistants from the quickslots.
    if not IsAddOnEnabled("EssentialHousingTools") then
        SHT.InitializeAssistants()
    end
    SHT.InitializeStorage()
end

EVENT_MANAGER:RegisterForEvent(SHT.ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
