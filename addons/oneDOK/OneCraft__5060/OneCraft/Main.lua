local O = OneCraft
local EM = EVENT_MANAGER

local function queue(A)
    if not A.active or A.refreshQueued then return end
    A.refreshQueued = true
    zo_callLater(function()
        A.refreshQueued = false
        if A.active then
            if A.IsBusy() then queue(A) else A.Refresh() end
        end
    end, 100)
end

local function connect(A, module, station, scene, creation)
    local function sync()
        local wanted = scene:IsShowing() and not IsInGamepadPreferredMode() and creation()
        if wanted then
            if not A.active then
                A.active, A.suspended = true, false
                A.view:Show()
                A.Refresh()
            else A.view:EnforceHidden() end
        elseif A.active then
            A.active = false
            A.view:Hide()
        end
    end
    scene:RegisterCallback("StateChange", function(_, state)
        if state == SCENE_HIDING or state == SCENE_HIDDEN then
            A.active = false
            A.view:Hide()
        elseif state == SCENE_SHOWING or state == SCENE_SHOWN then sync() end
    end)
    ZO_PostHook(station, module == "Alchemy" and "SetMode" or "OnModeUpdated", sync)
    EM:RegisterForEvent(O.name .. module, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, sync)
    local craftingType = module == "Alchemy" and CRAFTING_TYPE_ALCHEMY or CRAFTING_TYPE_ENCHANTING
    for _, bagId in ipairs({BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK, BAG_VIRTUAL}) do
        local namespace = O.name .. module .. bagId
        EM:RegisterForEvent(namespace, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(_, bag, slot)
            if A.active and (GetItemCraftingInfo(bag, slot) == craftingType or GetItemId(bag, slot) == 0) then queue(A) end
        end)
        EM:AddFilterForEvent(namespace, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, bagId)
    end
    EM:RegisterForEvent(O.name .. module, EVENT_INVENTORY_FULL_UPDATE, function() queue(A) end)
    EM:RegisterForEvent(O.name .. module, EVENT_NON_COMBAT_BONUS_CHANGED, function(_, bonus)
        if (module == "Alchemy" and (bonus == NON_COMBAT_BONUS_ALCHEMY_LEVEL or bonus == NON_COMBAT_BONUS_ALCHEMY_THIRD_SLOT)) or
            (module == "Enchanting" and (bonus == NON_COMBAT_BONUS_ENCHANTING_LEVEL or bonus == NON_COMBAT_BONUS_ENCHANTING_RARITY_LEVEL)) then queue(A) end
    end)
    CALLBACK_MANAGER:RegisterCallback("CraftingAnimationsStopped", function() queue(A) end)
    if module == "Alchemy" then EM:RegisterForEvent(O.name, EVENT_TRAIT_LEARNED, function() queue(A) end) end
    sync()
end

local function initialize()
    EM:UnregisterForEvent(O.name, EVENT_PLAYER_ACTIVATED)
    if GetAPIVersion() ~= O.apiVersion then d(O.text.unsupported); return end
    O.InitializeSettings()
    O.Equipment.Initialize()
    for _, module in ipairs({"Alchemy", "Enchanting"}) do
        local A = O[module]
        A.Initialize()
        if module == "Alchemy" then
            connect(A, module, ALCHEMY, ALCHEMY_SCENE, function() return ALCHEMY.mode == ZO_ALCHEMY_MODE_CREATION end)
        else
            connect(A, module, ENCHANTING, ENCHANTING_SCENE, function() return ENCHANTING:GetEnchantingMode() == ENCHANTING_MODE_CREATION end)
        end
    end
end

EM:RegisterForEvent(O.name, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= O.name then return end
    EM:UnregisterForEvent(O.name, EVENT_ADD_ON_LOADED)
    EM:RegisterForEvent(O.name, EVENT_PLAYER_ACTIVATED, initialize)
end)
