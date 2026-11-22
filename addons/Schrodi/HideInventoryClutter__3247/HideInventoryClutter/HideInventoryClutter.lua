HideInventoryClutter = { 
    ADDON_NAME = "HideInventoryClutter",
    log = true  and function(msg) d("[HideInventoryClutter]: "        .. msg) end or function() end,
    dbg = false and function(msg) d("[HideInventoryClutter][DEBUG]: " .. msg) end or function() end,
    err = true  and function(msg) d("[HideInventoryClutter][ERROR]: " .. msg) end or function() end,
}

function HideInventoryClutter:toggleConsumables()
    if self.movableIcon then
        self.log("Toggle is disabled when icons are unlocked!")
        return
    end

    self.consumablesVisible = not self.consumablesVisible
    self.libFilters:RequestUpdate(self.lastActiveMenu)
    HideInventoryClutter_ConsumablesButton:SetAlpha(self.consumablesVisible and 1 or 0.3)
    self.dbg("consumables visible: " .. tostring(self.consumablesVisible))
end

function HideInventoryClutter:toggleLocked(filter)
    if self.movableIcon then
        self.log("Toggle is disabled when icons are unlocked!")
        return
    end
    
    self.lockedVisible = not self.lockedVisible
    self.libFilters:RequestUpdate(self.lastActiveMenu)
    HideInventoryClutter_LockedButton:SetAlpha(self.lockedVisible and 1 or 0.3)
    self.dbg("locked items visible: " .. tostring(self.lockedVisible))
end

-- Crafting station filters get (bagId, slotIndex), the inventory filters a slot table.
local function AsSlot(a, b)
    if type(a) == "table" then return a end
    return { bagId = a, slotIndex = b }
end

function HideInventoryClutter:initalize()
    self.consumablesVisible = false
    self.lockedVisible = false
    self.movableIcon = false
    self.buttonsVisible = false
    self.lastActiveMenu = nil
    self.libFilters = LibFilters3
    self.libFilters:InitializeLibFilters()
    self:setupSavedVars()

    local lockedFilters = {
        [LF_BANK_DEPOSIT         ] = function(s) if self:isLocked(s) then return self.lockedVisible else return true end end,
        [LF_BANK_WITHDRAW        ] = function(s) if self:isLocked(s) then return self.lockedVisible else return true end end,
        [LF_HOUSE_BANK_DEPOSIT   ] = function(s) if self:isLocked(s) then return self.lockedVisible else return true end end,
        [LF_INVENTORY            ] = function(s) if self:isLocked(s) then return self.lockedVisible else return true end end,
        [LF_RETRAIT              ] = function(a, b) if self:isLocked(AsSlot(a, b)) then return self.lockedVisible else return true end end,
		
        [LF_VENDOR_SELL          ] = function(s) if self.lockedVisible then return true else return self:isWorthSelling(s) end end,
        
		[LF_SMITHING_DECONSTRUCT ] = function(a, b) if self.lockedVisible then return true else return self:isWorthDeconstructing(AsSlot(a, b)) end end,
        [LF_JEWELRY_DECONSTRUCT  ] = function(a, b) if self.lockedVisible then return true else return self:isWorthDeconstructing(AsSlot(a, b)) end end,
        [LF_ENCHANTING_EXTRACTION] = function(a, b) if self.lockedVisible then return true else return self:isWorthDeconstructing(AsSlot(a, b)) end end,
		
	--	[LF_TRADE				 ] = function(s) if self.lockedVisible then return true else return self:isEitherTradeableGearOrDifferentItemType(s) end end,
	}
    
    local consumableFilters = {
        [LF_BANK_DEPOSIT         ] = function(s) if self:isConsumable(s) then return self.consumablesVisible else return true end end,
        [LF_HOUSE_BANK_DEPOSIT   ] = function(s) if self:isConsumable(s) then return self.consumablesVisible else return true end end,
        [LF_GUILDBANK_DEPOSIT    ] = function(s) if self:isConsumable(s) then return self.consumablesVisible else return true end end,
        [LF_VENDOR_SELL          ] = function(s) if self:isConsumable(s) then return self.consumablesVisible else return true end end,
        [LF_MAIL_SEND            ] = function(s) if self:isConsumable(s) then return self.consumablesVisible else return true end end,
        [LF_INVENTORY            ] = function(s) if self:isConsumable(s) then return self.consumablesVisible else return true end end,
        [LF_GUILDSTORE_SELL      ] = function(s) if self:isConsumable(s) then return self.consumablesVisible else return true end end,
		[LF_TRADE                ] = function(s) if self:isConsumable(s) then return self.consumablesVisible else return true end end,
    }
    
    local universalDeconFilters = {
        ["all"       ] = LF_SMITHING_DECONSTRUCT, 
        ["armor"     ] = LF_SMITHING_DECONSTRUCT, 
        ["weapons"   ] = LF_SMITHING_DECONSTRUCT, 
        ["jewelry"   ] = LF_JEWELRY_DECONSTRUCT,  
        ["enchanting"] = LF_ENCHANTING_EXTRACTION,
    }
    
    self:SetupFilters(lockedFilters, "locked")
    self:SetupFilters(consumableFilters, "consumable")
    self:SetupUniversalDeconFilter(universalDeconFilters, "decon", function(b, i) if self.lockedVisible then return true else return self:isWorthDeconstructing({ bagId = b, slotIndex = i }) end end)
    self:SetupButtonSafetyNets()

    self:initializeUI()
    self:buildLAM2Menu()
end

function HideInventoryClutter:SetupFilters(filters, name)
    for menu, filter in pairs(filters) do
        local nameShown  = self.libFilters:CreateCallbackName(menu, true)
        local nameHidden = self.libFilters:CreateCallbackName(menu, false)
        
        local callbackShown = function (callbackName, filterType, _, _, _, _, _)
            if not self.libFilters:IsFilterRegistered(self.ADDON_NAME .. name .. menu, menu) then
                self.libFilters:RegisterFilter(self.ADDON_NAME .. name .. menu, menu, filters[menu])
                self.libFilters:RequestUpdate(menu)
                self.dbg("registered " .. tostring(name) .. " " .. tostring(menu))
            end
            self.lastActiveMenu = menu
            self.dbg("lastActiveMenu: " .. tostring(self.lastActiveMenu))
            self:showButtons()
        end
        
        local callbackHidden = function (callbackName, filterType, _, _, _, _, _)
            self.libFilters:UnregisterFilter(self.ADDON_NAME .. name .. menu, menu)
            self:hideButtons()
            self.dbg("unregistered " .. tostring(name) .. " " .. tostring(menu))
        end
        
        CALLBACK_MANAGER:RegisterCallback(nameShown, callbackShown)
        CALLBACK_MANAGER:RegisterCallback(nameHidden, callbackHidden)
    end
end

function HideInventoryClutter:SetupUniversalDeconFilter(filters, name, filterFn)
    for scope, menu in pairs(filters) do
        local nameShown  = self.libFilters:CreateCallbackName(menu, true, scope)
        local nameHidden = self.libFilters:CreateCallbackName(menu, false,scope)
            
        local callbackShown = function (callbackName, filterType, _, _, _, _, _)
            if not self.libFilters:IsFilterRegistered(self.ADDON_NAME .. name .. scope, menu) then
                self.libFilters:RegisterFilter(self.ADDON_NAME .. name .. scope, menu, filterFn)
                self.libFilters:RequestUpdate(menu)
                self.dbg("registered " .. name .. " " .. tostring(scope) .. " " .. tostring(menu))
            end
            self.lastActiveMenu = menu
            self.dbg("lastActiveMenu: " .. tostring(self.lastActiveMenu))
            self:showButtons()
        end
            
        local callbackHidden = function (callbackName, filterType, _, _, _, _, _)
            self.libFilters:UnregisterFilter(self.ADDON_NAME .. name .. scope, menu)
            self:hideButtons()
            self.dbg("unregistered " .. name .. " " .. tostring(scope) .. " " .. tostring(menu))
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
function HideInventoryClutter:SetupButtonSafetyNets()
    local function HideButtons()
        if not self.movableIcon and self.buttonsVisible then
            self:hideButtons()
        end
    end

    CALLBACK_MANAGER:RegisterCallback(self.libFilters:CreateCallbackName(LF_CRAFTBAG, true), HideButtons)
    CALLBACK_MANAGER:RegisterCallback(self.libFilters:CreateCallbackName(LF_CRAFTBAG, false), HideButtons)

    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, _, newState)
        if newState == SCENE_SHOWN then
            local sceneName = scene:GetName()
            if sceneName == "hud" or sceneName == "hudui" then
                HideButtons()
            end
        end
    end)
end

EVENT_MANAGER:RegisterForEvent(HideInventoryClutter.ADDON_NAME, EVENT_ADD_ON_LOADED, function(eventCode, addOnName)
    if addOnName ~= HideInventoryClutter.ADDON_NAME then return end 
    EVENT_MANAGER:UnregisterForEvent(HideInventoryClutter.ADDON_NAME, EVENT_ADD_ON_LOADED)
    HideInventoryClutter:initalize()
end)
