-----------------------------------------------------------
-- Author: SpringPeace2575 | Version: 0.9.0
-- ExtraRadialMenu add-on
-----------------------------------------------------------

ExtraRadialMenu = ExtraRadialMenu or {}
local ERM = ExtraRadialMenu
local ERMData = ExtraRadialMenuData
local ERMWheels = ExtraRadialMenuWheels

local GetHouseEntryParameters = function(houseId)
	local collectibleId = GetCollectibleIdForHouse(houseId)
	local name, _, icon, _, unlocked = GetCollectibleInfo(collectibleId)
	local collectibleData = {
		GetReferenceId = function() return houseId end,
	}
	local callback = function()
		ZO_Dialogs_ShowGamepadDialog("GAMEPAD_TRAVEL_TO_HOUSE_OPTIONS_DIALOG", collectibleData)
	end
	return name, icon, callback
end

local GetCollectibleEntryParameters = function(collectibleId)
	local name, _, icon, _, unlocked = GetCollectibleInfo(collectibleId)
	local callback = function()
		UseCollectible(collectibleId, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
	end
	return name, icon, callback
end

ZO_PreHook(ZO_UtilityWheel_Shared, "PopulateMenu", function(self)
	local hotbarCategory = self:GetHotbarCategory()

	if ERMWheels.wheels[hotbarCategory] ~= nil then
		local wheel = ERMWheels.wheels[hotbarCategory] or {}
		local wheelsEntries = ERM.sv.wheelsEntries[hotbarCategory] or {}

		for i = 1, ACTION_BAR_UTILITY_BAR_SIZE do
			local entry = wheelsEntries[i]

			if entry ~= nil then
				if wheel.type == ERMWheels.TypeHouses then
					local name, icon, callback = GetHouseEntryParameters(entry)
					self.menu:AddEntry(name, icon, icon, callback, { slotNum = i, name = name })
				else
					local name, icon, callback = GetCollectibleEntryParameters(entry)
					self.menu:AddEntry(name, icon, icon, callback, { slotNum = i, name = name })
				end
			else
				self.menu:AddEntry(ZO_UTILITY_SLOT_EMPTY_STRING, ZO_UTILITY_SLOT_EMPTY_TEXTURE, ZO_UTILITY_SLOT_EMPTY_TEXTURE, nil, { slotNum = i })
			end
		end

		self.previousCategoryControl:SetHidden(false)
		self.nextCategoryControl:SetHidden(false)

		self:RefreshCategories()
		return true
	end

	return false
end)
