
GoldNation = GoldNation or {}

GoldNation.name = "GoldNation"
GoldNation.version = "1.0"
GoldNation.author = "@SvlphvryVoid"
GoldNation.initialized = false
GoldNation.DebugMode = false
GoldNation.savedVariables = nil
-- {Sell, Keep, Discard}
local defaultVariables = {
    GN_AutoLoot = true,
        AL_Gold = true,
        AL_Weapons = true,
        AL_Weapons_Handle = "Sell",
        AL_Armor = true,
        AL_Armor_Handle = "Sell",
        AL_Jewelry = true,
        AL_Jewelry_Handle = "Sell",
        AL_Consumables = true,
        AL_Consumables_Handle = "Sell",
        AL_Collectables = true, -- If we havnt got it, collect it
        AL_Collectables_Handle = "Sell",
        AL_Collectables_Bind = true, -- Bind collectables to account
        AL_Stackables = true, 

    GN_AutoSell = true,
    GN_AutoRepair = true,
        AR_Threshold = 20,
    GN_AutoCollect = true,
    
    DB_Collect = {},
    DB_Sell = {},

}

function GoldNation.DeliverMessage(message, type)
    if type == "error" then
        d("|cE2E209[GN]: |cFF0000" .. message .. "|r")
    elseif type == "success" then
        d("|cE2E209[GN]: |c00FF00" .. message .. "|r")
    elseif type == "info" then
        d("|cE2E209[GN]: |cFFFFFF" .. message .. "|r")
    else
        d("[GN]: " .. message)
    end
end

-- Check if player is in PVP area (Returns true if in PVP area, false otherwise)
function GoldNation.IsInPVPArea()
    if IsActiveWorldBattleground() then
        return true
    end

    if IsInCampaign() then
        return true
    end

    if IsInCyrodiil() then
        return true
    end

    if IsInImperialCity() then
        return true
    end

    if IsPlayerInAvAWorld() then
        return true
    end

    return false
end
-- ZO_CallLater(function(), 1000)

function GoldNation.Initialize()

    if GoldNation.initialized then
        return
    end

    GoldNation.initialized = true

    savedVariables = ZO_SavedVars:NewAccountWide(
        "GoldNationSavedVariables",
        1,
        nil,
        defaultVariables
    )

    if GoldNation.Automation then
        GoldNation.Automation.Initialize()
    end

    if GoldNation.MoneyMaking then
        GoldNation.MoneyMaking.Initialize()
    end

    if GoldNation.Guild then
        GoldNation.Guild.Initialize()
    end

    if GoldNation.Settings then
        GoldNation.Settings.Initialize()
    end

    if GoldNation.Menu then
        GoldNation.Menu.Initialize()
    end

end

function GoldNation.OnPlayerActivated(event)

    GoldNation.Initialize()

    EVENT_MANAGER:UnregisterForEvent(
        GoldNation.name,
        EVENT_PLAYER_ACTIVATED
    )

end

EVENT_MANAGER:RegisterForEvent(
    GoldNation.name,
    EVENT_PLAYER_ACTIVATED,
    GoldNation.OnPlayerActivated
)

EVENT_MANAGER:RegisterForEvent( -- Register when we take loot
    GoldNation.name,
    EVENT_LOOT_RECEIVED,
    GoldNation.Automation.LootReceived
)

EVENT_MANAGER:RegisterForEvent( -- Register when loot window is closed
    GoldNation.name,
    EVENT_LOOT_CLOSED,
    GoldNation.Automation.LootClosed
)

EVENT_MANAGER:RegisterForEvent( -- Register when a loot window is open
    GoldNation.name,
    EVENT_LOOT_UPDATED,
    GoldNation.Automation.LootUpdated
)

EVENT_MANAGER:RegisterForEvent(
    GoldNation.name,
    EVENT_OPEN_STORE,
    GoldNation.Automation.OpenStore
)

EVENT_MANAGER:RegisterForEvent(
    GoldNation.name,
    EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
    GoldNation.Automation.InventorySingleSlotUpdate
)

-- EVENT_ADD_ON_LOADED
-- EVENT_LOOT_RECEIVED
-- EVENT_LOOT_CLOSED
-- EVENT_LOOT_UPDATED
-- EVENT_OPEN_STORE
-- EVENT_OPEN_FENCE
-- EVENT_LOCKPICK_SUCCESS
-- EVENT_INVENTORY_SINGLE_SLOT_UPDATE
-- 


--local currentScene = SCENE_MANAGER:GetCurrentScene().name
    --if ((IsInGamepadPreferredMode() and tostring(currentScene) == "lootInventoryGamepad") or
    --    (not IsInGamepadPreferredMode() and tostring(currentScene) == "inventory") or false) then
    --    isBagContainer = true
    --end
