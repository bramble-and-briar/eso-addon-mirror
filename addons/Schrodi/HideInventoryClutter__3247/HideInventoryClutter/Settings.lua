function HideInventoryClutter:buildLAM2Menu()
    local LAM2 = LibAddonMenu2
	LAM2:RegisterAddonPanel(self.ADDON_NAME  .. "_LAM_PANEL", { type = "panel", name = "Hide Inventory Clutter" })
	local controls = {
		[1] = {
			type = "description",
			width = "full",
			text = 
			[[An addon that hides inventory clutter, namely locked items and common consumables.
			See available filters below (hover over them to get a short description).
			Check addon's website or see README.md file in addon folder to learn the details.
			Full list of affected consumables:
			- lockpicks
			- grand repair kits
			- soul gems
			- buff food / drinks
			- potions
			- poisons
			- experience and Alliance War skill line boosters (optional)
			- siege weapons and Alliance War repair kits (optional)
			- Keep Recall Stones and Sigils of Imperial Retreat (optional)]]
		},
		[2] = {
			type = "button",
			name = "Unlock icon position",
			func = function() 
				self.movableIcon = true
				HideInventoryClutter_ConsumablesButton:SetMovable(true)
				HideInventoryClutter_LockedButton:SetMovable(true)

				HideInventoryClutter_LockedButton:SetAlpha(1)
				HideInventoryClutter_LockedButton:SetHidden(false)
				HideInventoryClutter_ConsumablesButton:SetAlpha(1)
				HideInventoryClutter_ConsumablesButton:SetHidden(false)
				
				self.log("Icons unlocked.")
			end
		},
		[3] = {
			type = "button",
			name = "Reset position",
			func = function()
				HideInventoryClutter_LockedButton:ClearAnchors()
				HideInventoryClutter_LockedButton:SetAnchor(TOPLEFT, ZO_PlayerInventoryInfoBar, TOPLEFT, 282, 9)
					
				HideInventoryClutter_ConsumablesButton:ClearAnchors()
				HideInventoryClutter_ConsumablesButton:SetAnchor(TOPLEFT, ZO_PlayerInventoryInfoBar, TOPLEFT, 300, 0)

				self:saveGuiPosition()
				self.log("Icons position restored to default and saved.")
			end
		},
		[4] = {
			type = "button",
			name = "Save new position",
			func = function()
				self.movableIcon = false
				HideInventoryClutter_ConsumablesButton:SetMovable(false)
				HideInventoryClutter_LockedButton:SetMovable(false)
				HideInventoryClutter_LockedButton:SetAlpha(self.lockedVisible and 1 or 0.3)
				HideInventoryClutter_LockedButton:SetHidden(true)
				HideInventoryClutter_ConsumablesButton:SetAlpha(self.consumablesVisible and 1 or 0.3)
				HideInventoryClutter_ConsumablesButton:SetHidden(true)

				self:saveGuiPosition()
				self.log("Icons locked, new position saved.")
			end
		},
		[5] = {
			type = "checkbox",
			name = "Locked items filter",
			tooltip = "hides locked items from inventory, bank and transmutation station windows",
			getFunc = function() return self.savedVariables.lockedEnabled end,
			setFunc = function(value) self.savedVariables.lockedEnabled = value end
		},
		[6] = {
			type = "checkbox",
			name = "Consumables filter",
			tooltip = "hides common consumables from inventory and merchant sell window",
			getFunc = function() return self.savedVariables.consumablesEnabled end,
			setFunc = function(value) self.savedVariables.consumablesEnabled = value end
		},
		[7] = {
			type = "checkbox",
			name = "Treat XP and Alliance War rank boosters as consumables",
			tooltip = "experience scrolls, war tortes, ambrosia and other items whose use increases experience gains are hidden with the consumables; when off they always stay visible, even the ones that are food",
			getFunc = function() return self.savedVariables.boostersAreConsumables end,
			setFunc = function(value)
				self.savedVariables.boostersAreConsumables = value
				if self.lastActiveMenu then self.libFilters:RequestUpdate(self.lastActiveMenu) end
			end,
			disabled = function() return not self.savedVariables.consumablesEnabled end,
		},
		[8] = {
			type = "checkbox",
			name = "Treat siege weapons and Alliance War repair kits as consumables",
			tooltip = "siege weapons, forward camps, oil, battle standards and keep / siege repair kits are hidden with the consumables",
			getFunc = function() return self.savedVariables.siegeAreConsumables end,
			setFunc = function(value)
				self.savedVariables.siegeAreConsumables = value
				if self.lastActiveMenu then self.libFilters:RequestUpdate(self.lastActiveMenu) end
			end,
			disabled = function() return not self.savedVariables.consumablesEnabled end,
		},
		[9] = {
			type = "checkbox",
			name = "Treat Keep Recall Stones and Sigils of Imperial Retreat as consumables",
			tooltip = "Keep Recall Stones and Sigils of Imperial Retreat are hidden with the consumables",
			getFunc = function() return self.savedVariables.travelItemsAreConsumables end,
			setFunc = function(value)
				self.savedVariables.travelItemsAreConsumables = value
				if self.lastActiveMenu then self.libFilters:RequestUpdate(self.lastActiveMenu) end
			end,
			disabled = function() return not self.savedVariables.consumablesEnabled end,
		},
		[10] = {
			type = "checkbox",
			name = "Materials filter",
			tooltip = "hides materials from merchant sell window",
			getFunc = function() return self.savedVariables.materialsEnabled end,
			setFunc = function(value) self.savedVariables.materialsEnabled = value end
		},
		[11] = {
			type = "checkbox",
			name = "Deconstruction filter",
			tooltip = "hides items not worth deconstructing from deconstruction window and items worth deconstucting from merchant window",
			getFunc = function() return self.savedVariables.deconstructionEnabled end,
			setFunc = function(value) self.savedVariables.deconstructionEnabled = value end
		},
		[12] = {
			type = "slider",
			name = "No ESO+ mode I (they can all be used in conjunction) (you can type in custom value) (1 = off)",
			tooltip = "items are not considered worth deconstructing only if deconstruction value is at least N times the sell value",
			min = 1,
			max = 10,
			getFunc = function() return self.savedVariables.deconstructionValueMultiplier end,
			setFunc = function(value) self.savedVariables.deconstructionValueMultiplier = value end
		},
		[13] = {
			type = "slider",
			name = "No ESO+ mode II (they can all be used in conjunction) (you can type in custom value) (0 = off)",
			tooltip = "deconstruction value used in determining if an item is worth deconstructing will skip materials with price below N gold",
			min = 0,
			step = 10,
			max = 1000,
			getFunc = function() return self.savedVariables.deconstructionValueMinMatPrice end,
			setFunc = function(value) self.savedVariables.deconstructionValueMinMatPrice = value end
		},
		[14] = {
			type = "slider",
			name = "No ESO+ mode III (they can all be used in conjunction) (you can type in custom value) (0 = off)",
			tooltip = "item is only considered worth deconstructing if deconstruction value is at least N gold higher than sell value",
			min = 0,
			step = 10,
			max = 1000,
			getFunc = function() return self.savedVariables.deconstructionValueMinDifference end,
			setFunc = function(value) self.savedVariables.deconstructionValueMinDifference = value end
		},
	}
	LAM2:RegisterOptionControls(self.ADDON_NAME .. "_LAM_PANEL", controls)
end


function HideInventoryClutter:saveGuiPosition()
	self.savedVariables.positionConsumable.left = math.floor(HideInventoryClutter_ConsumablesButton:GetLeft())
	self.savedVariables.positionConsumable.top  = math.floor(HideInventoryClutter_ConsumablesButton:GetTop())	
	
	self.savedVariables.positionLocked.left = math.floor(HideInventoryClutter_LockedButton:GetLeft())
	self.savedVariables.positionLocked.top  = math.floor(HideInventoryClutter_LockedButton:GetTop())		
end

function HideInventoryClutter:setupSavedVars()
	self.savedVariables = ZO_SavedVars:NewAccountWide("HideInventoryClutterPosition", 3, nil, { 
			positionLocked     = { top = nil, left = nil },
			positionConsumable = { top = nil, left = nil },
			lockedEnabled = true,
			consumablesEnabled = true,
			boostersAreConsumables = true,
			siegeAreConsumables = true,
			travelItemsAreConsumables = true,
			materialsEnabled = true,
			deconstructionEnabled = true,
			deconstructionValueMultiplier = 1,
			deconstructionValueMinDifference = 0,
		})
end