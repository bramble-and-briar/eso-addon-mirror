HideInventoryClutter = { 
    ADDON_NAME = "HideInventoryClutter",
    log = true  and function(msg) d("[HideInventoryClutter]: "        .. msg) end or function() end,
    dbg = false and function(msg) d("[HideInventoryClutter][DEBUG]: " .. msg) end or function() end,
    err = true  and function(msg) d("[HideInventoryClutter][ERROR]: " .. msg) end or function() end,
}
local HIC = HideInventoryClutter

function HIC.toggleConsumables()
    if HIC.movableIcon then
        HIC.log("Toggle is disabled when icons are unlocked!")
        return
    end

    HIC.consumablesVisible = not HIC.consumablesVisible
    HIC.libFilters:RequestUpdate(HIC.lastActiveMenu)
    HideInventoryClutter_ConsumablesButton:SetAlpha(HIC.consumablesVisible and 1 or 0.3)
    HIC.dbg("consumables visible: " .. tostring(HIC.consumablesVisible))
end

function HIC.toggleLocked(filter)
    if HIC.movableIcon then
        HIC.log("Toggle is disabled when icons are unlocked!")
        return
    end
    
    HIC.lockedVisible = not HIC.lockedVisible
    HIC.libFilters:RequestUpdate(HIC.lastActiveMenu)
    HideInventoryClutter_LockedButton:SetAlpha(HIC.lockedVisible and 1 or 0.3)
    HIC.dbg("locked items visible: " .. tostring(HIC.lockedVisible))
end

-- Crafting station filters get (bagId, slotIndex), the inventory filters a slot table.
local function AsSlot(a, b)
    if type(a) == "table" then return a end
    return { bagId = a, slotIndex = b }
end

function HIC.initalize()
    HIC.consumablesVisible = false
    HIC.lockedVisible = false
    HIC.movableIcon = false
    HIC.buttonsVisible = false
    HIC.lastActiveMenu = nil
    HIC.libFilters = LibFilters3
    HIC.libFilters:InitializeLibFilters()
    HIC.setupSavedVars()

    local lockedFilters = {
        [LF_BANK_DEPOSIT         ] = function(s) if HIC.isLocked(s) then return HIC.lockedVisible else return true end end,
        [LF_BANK_WITHDRAW        ] = function(s) if HIC.isLocked(s) then return HIC.lockedVisible else return true end end,
        [LF_HOUSE_BANK_DEPOSIT   ] = function(s) if HIC.isLocked(s) then return HIC.lockedVisible else return true end end,
        [LF_INVENTORY            ] = function(s) if HIC.isLocked(s) then return HIC.lockedVisible else return true end end,
        [LF_RETRAIT              ] = function(a, b) if HIC.isLocked(AsSlot(a, b)) then return HIC.lockedVisible else return true end end,
		
        [LF_VENDOR_SELL          ] = function(s) if HIC.lockedVisible then return true else return HIC.isWorthSelling(s) end end,
        
		[LF_SMITHING_DECONSTRUCT ] = function(a, b) if HIC.lockedVisible then return true else return HIC.isWorthDeconstructing(AsSlot(a, b)) end end,
        [LF_JEWELRY_DECONSTRUCT  ] = function(a, b) if HIC.lockedVisible then return true else return HIC.isWorthDeconstructing(AsSlot(a, b)) end end,
        [LF_ENCHANTING_EXTRACTION] = function(a, b) if HIC.lockedVisible then return true else return HIC.isWorthDeconstructing(AsSlot(a, b)) end end,
		
	--	[LF_TRADE				 ] = function(s) if HIC.lockedVisible then return true else return HIC.isEitherTradeableGearOrDifferentItemType(s) end end,
	}
    
    local consumableFilters = {
        [LF_BANK_DEPOSIT         ] = function(s) if HIC.isConsumable(s) then return HIC.consumablesVisible else return true end end,
        [LF_HOUSE_BANK_DEPOSIT   ] = function(s) if HIC.isConsumable(s) then return HIC.consumablesVisible else return true end end,
        [LF_GUILDBANK_DEPOSIT    ] = function(s) if HIC.isConsumable(s) then return HIC.consumablesVisible else return true end end,
        [LF_VENDOR_SELL          ] = function(s) if HIC.isConsumable(s) then return HIC.consumablesVisible else return true end end,
        [LF_MAIL_SEND            ] = function(s) if HIC.isConsumable(s) then return HIC.consumablesVisible else return true end end,
        [LF_INVENTORY            ] = function(s) if HIC.isConsumable(s) then return HIC.consumablesVisible else return true end end,
        [LF_GUILDSTORE_SELL      ] = function(s) if HIC.isConsumable(s) then return HIC.consumablesVisible else return true end end,
		[LF_TRADE                ] = function(s) if HIC.isConsumable(s) then return HIC.consumablesVisible else return true end end,
    }
    
    local universalDeconFilters = {
        ["all"       ] = LF_SMITHING_DECONSTRUCT, 
        ["armor"     ] = LF_SMITHING_DECONSTRUCT, 
        ["weapons"   ] = LF_SMITHING_DECONSTRUCT, 
        ["jewelry"   ] = LF_JEWELRY_DECONSTRUCT,  
        ["enchanting"] = LF_ENCHANTING_EXTRACTION,
    }
    
    HIC.SetupFilters(lockedFilters, "locked")
    HIC.SetupFilters(consumableFilters, "consumable")
    HIC.SetupUniversalDeconFilter(universalDeconFilters, "decon", function(b, i) if HIC.lockedVisible then return true else return HIC.isWorthDeconstructing({ bagId = b, slotIndex = i }) end end)
    HIC.SetupButtonSafetyNets()

    HIC.initializeUI()
    HIC.buildLAM2Menu()
end

function HIC.SetupFilters(filters, name)
    for menu, filter in pairs(filters) do
        local nameShown  = HIC.libFilters:CreateCallbackName(menu, true)
        local nameHidden = HIC.libFilters:CreateCallbackName(menu, false)
        
        local callbackShown = function (callbackName, filterType, _, _, _, _, _)
            if not HIC.libFilters:IsFilterRegistered(HIC.ADDON_NAME .. name .. menu, menu) then
                HIC.libFilters:RegisterFilter(HIC.ADDON_NAME .. name .. menu, menu, filters[menu])
                HIC.libFilters:RequestUpdate(menu)
                HIC.dbg("registered " .. tostring(name) .. " " .. tostring(menu))
            end
            HIC.lastActiveMenu = menu
            HIC.dbg("lastActiveMenu: " .. tostring(HIC.lastActiveMenu))
            HIC.showButtons()
        end
        
        local callbackHidden = function (callbackName, filterType, _, _, _, _, _)
            HIC.libFilters:UnregisterFilter(HIC.ADDON_NAME .. name .. menu, menu)
            HIC.hideButtons()
            HIC.dbg("unregistered " .. tostring(name) .. " " .. tostring(menu))
        end
        
        CALLBACK_MANAGER:RegisterCallback(nameShown, callbackShown)
        CALLBACK_MANAGER:RegisterCallback(nameHidden, callbackHidden)
    end
end

function HIC.SetupUniversalDeconFilter(filters, name, filterFn)
    for scope, menu in pairs(filters) do
        local nameShown  = HIC.libFilters:CreateCallbackName(menu, true, scope)
        local nameHidden = HIC.libFilters:CreateCallbackName(menu, false,scope)
            
        local callbackShown = function (callbackName, filterType, _, _, _, _, _)
            if not HIC.libFilters:IsFilterRegistered(HIC.ADDON_NAME .. name .. scope, menu) then
                HIC.libFilters:RegisterFilter(HIC.ADDON_NAME .. name .. scope, menu, filterFn)
                HIC.libFilters:RequestUpdate(menu)
                HIC.dbg("registered " .. name .. " " .. tostring(scope) .. " " .. tostring(menu))
            end
            HIC.lastActiveMenu = menu
            HIC.dbg("lastActiveMenu: " .. tostring(HIC.lastActiveMenu))
            HIC.showButtons()
        end
            
        local callbackHidden = function (callbackName, filterType, _, _, _, _, _)
            HIC.libFilters:UnregisterFilter(HIC.ADDON_NAME .. name .. scope, menu)
            HIC.hideButtons()
            HIC.dbg("unregistered " .. name .. " " .. tostring(scope) .. " " .. tostring(menu))
        end
            
        CALLBACK_MANAGER:RegisterCallback(nameShown, callbackShown)
        CALLBACK_MANAGER:RegisterCallback(nameHidden, callbackHidden)
    end
end

-- LibFilters only raises the "hidden" callback for the panel it saw shown last. Switching the
-- inventory to the Craft Bag tab shows LF_CRAFTBAG before LF_INVENTORY hides, so LF_INVENTORY's
-- hidden callback never fires, and closing the inventory from the Craft Bag left the buttons on
-- screen. None of the filters apply to the Craft Bag, so hide the buttons there, and hide them
-- whenever the plain HUD comes back as a safety net for any similar path.
function HIC.SetupButtonSafetyNets()
    local function HideButtons()
        if not HIC.movableIcon and HIC.buttonsVisible then
            HIC.hideButtons()
        end
    end

    CALLBACK_MANAGER:RegisterCallback(HIC.libFilters:CreateCallbackName(LF_CRAFTBAG, true), HideButtons)
    CALLBACK_MANAGER:RegisterCallback(HIC.libFilters:CreateCallbackName(LF_CRAFTBAG, false), HideButtons)

    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, _, newState)
        if newState == SCENE_SHOWN then
            local sceneName = scene:GetName()
            if sceneName == "hud" or sceneName == "hudui" then
                HideButtons()
            end
        end
    end)
end

EVENT_MANAGER:RegisterForEvent(HIC.ADDON_NAME, EVENT_ADD_ON_LOADED, function(eventCode, addOnName)
    if addOnName ~= HIC.ADDON_NAME then return end 
    EVENT_MANAGER:UnregisterForEvent(HIC.ADDON_NAME, EVENT_ADD_ON_LOADED)
    HIC.initalize()
end)
