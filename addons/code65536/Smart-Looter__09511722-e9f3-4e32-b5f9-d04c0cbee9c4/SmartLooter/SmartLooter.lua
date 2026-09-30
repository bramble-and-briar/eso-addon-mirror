SmartLooter = {
	name = "SmartLooter",

	normalCurrencies = {
		CURT_MONEY,
		CURT_ALLIANCE_POINTS,
		CURT_TELVAR_STONES,
		CURT_WRIT_VOUCHERS,
		CURT_UNDAUNTED_KEYS,
		CURT_STYLE_STONES,
		CURT_SEALS,
		CURT_ARCHIVAL_FORTUNES,
		CURT_IMPERIAL_FRAGMENTS,
		CURT_TRADE_BARS,
		CURT_UNDAUNTED_CRESTS,
	},

	cappedCurrencies = {
		CURT_TRANSMUTE_CRYSTALS,
	},

	validTargetTypes = {
		[INTERACT_TARGET_TYPE_NONE]   = true,	-- backpacks, desks, barrels, etc.
		[INTERACT_TARGET_TYPE_OBJECT] = true,	-- enemies, crafting nodes, chests, etc.
		[INTERACT_TARGET_TYPE_ITEM]   = true,	-- coffers and other inventory containers
	},

	validStealthStates = {
		[STEALTH_STATE_HIDDEN]                  = true,
		[STEALTH_STATE_STEALTH]                 = true,
		[STEALTH_STATE_HIDDEN_ALMOST_DETECTED]  = true,
		[STEALTH_STATE_STEALTH_ALMOST_DETECTED] = true,
	},

	settingWarning = {
		default = "|cFF9900Warning:|r The base game Auto Loot feature is enabled, which overrides Smart Looter.",
	},
}
local SmartLooter = SmartLooter

local function OnAddOnLoaded( eventCode, addonName )
	if (addonName ~= SmartLooter.name) then return end

	EVENT_MANAGER:UnregisterForEvent(SmartLooter.name, EVENT_ADD_ON_LOADED)

	EVENT_MANAGER:RegisterForEvent(SmartLooter.name, EVENT_LOOT_UPDATED, SmartLooter.OnLootUpdated)
	EVENT_MANAGER:RegisterForEvent(SmartLooter.name, EVENT_PLAYER_ACTIVATED, function( )
		if (GetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_LOOT) == "1") then
			CHAT_ROUTER:AddSystemMessage(SmartLooter.settingWarning[GetCVar("Language.2")] or SmartLooter.settingWarning.default)
		end
	end, true)
end

function SmartLooter.OnLootUpdated( eventCode )
	if (IsLooting()) then
		local _, targetType = GetLootTargetInfo()

		if (SmartLooter.validTargetTypes[targetType]) then
			-- Needed for manual closing of container loot windows
			local hasSkipped = false
			local scene = SCENE_MANAGER:GetCurrentScene().name

			-- Handle uncapped currencies
			for _, currencyType in ipairs(SmartLooter.normalCurrencies) do
				local unownedCurrency, ownedCurrency = GetLootCurrency(currencyType)

				if (unownedCurrency > 0) then
					if (targetType == INTERACT_TARGET_TYPE_ITEM and currencyType == CURT_TELVAR_STONES and DoesCurrentZoneHaveTelvarStoneBehavior()) then
						-- Keep Tel Var safe inside coffers if the player is in IC
						hasSkipped = true
					else
						LootCurrency(currencyType)
					end
				elseif (ownedCurrency > 0) then
					if (not SmartLooter.IsStealingSafe()) then
						hasSkipped = true
					else
						LootCurrency(currencyType)
					end
				end
			end

			-- Handle capped currencies
			for _, currencyType in ipairs(SmartLooter.cappedCurrencies) do
				local unownedCurrency = GetLootCurrency(currencyType)

				if (unownedCurrency > 0) then
					if (GetMaxPossibleCurrency(currencyType, CURRENCY_LOCATION_ACCOUNT) < GetCurrencyAmount(currencyType, CURRENCY_LOCATION_ACCOUNT) + unownedCurrency) then
						-- Never let a capped currency overflow
						hasSkipped = true
					elseif (targetType == INTERACT_TARGET_TYPE_ITEM and currencyType ~= CURT_TRANSMUTE_CRYSTALS) then
						-- Always leave capped currencies in coffers, unless it's transmute crystals
						hasSkipped = true
					elseif (targetType == INTERACT_TARGET_TYPE_ITEM and currencyType == CURT_TRANSMUTE_CRYSTALS and unownedCurrency > 20) then
						-- For transmute crystals, leave them in coffers only for large quantities
						hasSkipped = true
					else
						LootCurrency(currencyType)
					end
				end
			end

			-- Handle items
			local lootIds = { }
			local lootItems = GetNumLootItems()
			for i = 1, lootItems do
				local lootId, _, _, count, _, _, _, stolen, lootType = GetLootItemInfo(i)
				if (SmartLooter.IsLootAcceptable(lootId, count, stolen, lootType)) then
					table.insert(lootIds, lootId)
				end
			end
			if ((#lootIds == lootItems or #lootIds > 20) and not hasSkipped) then
				LootAll(false)
			else
				for _, lootId in ipairs(lootIds) do
					LootItemById(lootId)
				end
				hasSkipped = true
			end

			-- Need to manually close the loot dialog for fully-looted containers
			if (targetType == INTERACT_TARGET_TYPE_ITEM and not hasSkipped) then
				SCENE_MANAGER:Show(scene)
			end
		end
	end
end

function SmartLooter.IsLootAcceptable( lootId, count, stolen, lootType )
	if (lootType == LOOT_TYPE_QUEST_ITEM or lootType == LOOT_TYPE_COLLECTIBLE or lootType == LOOT_TYPE_ANTIQUITY_LEAD) then
		return true
	end

	if (stolen and not SmartLooter.IsStealingSafe()) then
		return false
	end

	if (lootType == LOOT_TYPE_ITEM) then
		local itemLink = GetLootItemLink(lootId, LINK_STYLE_DEFAULT)

		if (not stolen and HasCraftBagAccess() and CanItemLinkBeVirtual(itemLink)) then
			-- Can it go into the craft bag?
			return true
		elseif (SmartLooter.FindStack(itemLink, count, stolen)) then
			-- Is there a compatible, suitably-sized stack in the player's bag?
			return true
		elseif (SmartLooter.bypassMode == true) then
			-- If bypass mode is active
			return true
		end
	end

	return false
end

function SmartLooter.FindStack( itemLink, count, stolen )
	if (not count) then count = 0 end
	if (not stolen) then stolen = false end

	if (IsItemLinkStackable(itemLink)) then
		local itemId = GetItemLinkItemId(itemLink)
		local requiredLevel = GetItemLinkRequiredLevel(itemLink)
		local requiredChampionPoints = GetItemLinkRequiredChampionPoints(itemLink)
		local bagCache = SHARED_INVENTORY:GetOrCreateBagCache(BAG_BACKPACK)

		for _, data in pairs(bagCache) do
			if ( itemId == GetItemId(data.bagId, data.slotIndex) and
			     stolen == data.stolen and
			     requiredLevel == data.requiredLevel and
			     requiredChampionPoints == data.requiredChampionPoints ) then
				local stack, maxStack = GetSlotStackSize(data.bagId, data.slotIndex)
				if (stack + count <= maxStack) then
					return data.slotIndex
				end
			end
		end
	end

	return nil
end

function SmartLooter.IsStealingSafe( )
	return IsInOutlawZone() or not IsInJusticeEnabledZone() or SmartLooter.validStealthStates[GetUnitStealthState("player")]
end

EVENT_MANAGER:RegisterForEvent(SmartLooter.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
