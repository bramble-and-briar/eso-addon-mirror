local Colorblind = {
	Name = "Colorblind",
	Author = "Lousytourist",
	Version = "2026.11.22",
	SettingsVersion = "1.13",
	Cache = {} -- High-performance memory lookup table
}

Colorblind.Default = { ['item_text'] = true, ['enchant_text'] = true }

-- Helper function to return explicit text descriptors for colorblind clarity
local function GetQualityTextTag(quality)
	if quality == ITEM_FUNCTIONAL_QUALITY_NORMAL or quality == 1 or quality == "1" then return " [Normal]"
	elseif quality == ITEM_FUNCTIONAL_QUALITY_FINE or quality == 2 or quality == "2" then return " [Fine]"
	elseif quality == ITEM_FUNCTIONAL_QUALITY_SUPERIOR or quality == 3 or quality == "3" then return " [Superior]"
	elseif quality == ITEM_FUNCTIONAL_QUALITY_EPIC or quality == 4 or quality == "4" then return " [Epic]"
	elseif quality == ITEM_FUNCTIONAL_QUALITY_LEGENDARY or quality == 5 or quality == "5" then return " [Legendary]"
	end
	return ""
end

-- Calculates and caches the full quality + enchantment tag string for any itemLink
local function GetColorblindTagForLink(itemLink)
	if not itemLink or itemLink == "" then return "" end

	-- CACHE CHECK: Instantly return if we processed this exact item configuration before
	local cachedTag = Colorblind.Cache[itemLink]
	if cachedTag ~= nil then
		return cachedTag
	end

	local tagString = ""

	-- 1. Base Item Quality Processing (Runs universally on all objects)
	local itemQuality = GetItemLinkFunctionalQuality(itemLink)
	if Colorblind.SavedVars.item_text and itemQuality and itemQuality > 0 then
		tagString = tagString .. GetQualityTextTag(itemQuality)
	end

	-- 2. Enchantment Quality Processing (Runs optionally if matching indexes are found)
	if Colorblind.SavedVars.enchant_text then
		local itemLinkStr = tostring(itemLink)
		local linkParts = { zo_strsplit(":", itemLinkStr) }
		local itemIdStr = linkParts[4]
		local enchantIdStr = linkParts[5]
		local enchantSubIdStr = linkParts[6]
		
		if itemIdStr and enchantIdStr and enchantSubIdStr then
			local activeEnchantId = tonumber(enchantIdStr)
			local enchantSubId = tonumber(enchantSubIdStr)
			
			if activeEnchantId and activeEnchantId > 0 and enchantSubId and enchantSubId > 0 then
				local fakeEnchantLink = string.format("|H1:item:%s:%s:50:0:0:0:0:0:0:0:0:0:0:0:0:1:1:0:0:10000:0|h|h", itemIdStr, enchantSubIdStr)
				local enchantQuality = GetItemLinkFunctionalQuality(fakeEnchantLink)
				
				if enchantQuality and enchantQuality > 0 and enchantQuality ~= itemQuality then
					-- Deduplication filter tracking (safely handles trial/dungeon set variations)
					if not (itemQuality == 5 and enchantQuality ~= 5) then
						tagString = tagString .. " " .. GetQualityTextTag(enchantQuality)
					end
				end
			end
		end
	end

	Colorblind.Cache[itemLink] = tagString
	return tagString
end

-- Safely extracts the exact itemLink depending on which window/scene is active
local function GetTrueItemLink(rowControl, data)
	local coreData = data or (rowControl.dataEntry and rowControl.dataEntry.data)
	if not coreData then return nil end

	local bagId = coreData.bagId
	local slotIndex = coreData.slotIndex

	if bagId and slotIndex then
		return GetItemLink(bagId, slotIndex)
	elseif coreData.lootId then
		return GetLootItemLink(coreData.lootId)
	elseif slotIndex then
		if TRADING_HOUSE_SCENE and TRADING_HOUSE_SCENE:IsShowing() then
			return GetTradingHouseSearchResultItemLink(slotIndex)
		elseif STORE_SCENE and STORE_SCENE:IsShowing() then
			return GetStoreItemLink(slotIndex)
		elseif BUY_BACK_SCENE and BUY_BACK_SCENE:IsShowing() then
			return GetBuybackItemLink(slotIndex)
		end
	end
	
	local itemLink = coreData.itemLink
	if itemLink then return itemLink end
	if type(coreData) == "string" and string.byte(coreData, 1) == 124 then return coreData end

	return nil
end

-- Renders the independent accessibility text tag label container on list rows
local function DrawColorblindLabel(rowControl, data)
	if not rowControl then return end
	local nameLabel = rowControl:GetNamedChild("Name")
	if not nameLabel then return end

	local cbLabel = rowControl:GetNamedChild("EQColorblindLabel")
	if not cbLabel then
		cbLabel = WINDOW_MANAGER:CreateControl(rowControl:GetName() .. "EQColorblindLabel", rowControl, CT_LABEL)
		cbLabel:SetFont("$(CHAT_FONT)|14|soft-shadow-thin")
		cbLabel:SetAnchor(LEFT, nameLabel, RIGHT, 10, 0)
		cbLabel:SetWidth(120) 
		if type(cbLabel.SetWrapMode) == "function" and TEXT_WRAP_MODE_ELLIPSIS then
			cbLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
		end
	end

	local itemLink = GetTrueItemLink(rowControl, data)
	if itemLink then
		local tagString = GetColorblindTagForLink(itemLink)
		if tagString ~= "" then
			cbLabel:SetText(tagString)
			cbLabel:SetHidden(false)
		else
			cbLabel:SetHidden(true)
		end
	else
		cbLabel:SetHidden(true)
	end
end

-- Hooks ItemTooltip & PopupTooltip for Mail attachments, Quest rewards, Chat links, and Equipped gear
local function HookTooltips()
	local function AddTooltipQuality(tooltipControl, itemLink)
		if not itemLink or itemLink == "" then return end
		local tagString = GetColorblindTagForLink(itemLink)
		if tagString ~= "" then
			tooltipControl:AddLine("Quality:" .. tagString, "ZoFontWinH4", 1, 1, 1, CENTER, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_CENTER, true)
		end
	end

	local tooltipMethods = {
		"SetBagItem",
		"SetWornItem",
		"SetTradeItem",
		"SetBuybackItem",
		"SetStoreItem",
		"SetAttachedMailItem",
		"SetLootItem",
		"SetReward",
		"SetQuestReward",
		"SetTradingHouseItem",
		"SetTradingHouseListing",
		"SetLink"
	}

	local function HookSingleTooltip(tooltip)
		if not tooltip then return end
		for _, methodName in ipairs(tooltipMethods) do
			if type(tooltip[methodName]) == "function" then
				ZO_PostHook(tooltip, methodName, function(self, ...)
					local itemLink
					if methodName == "SetLink" then
						itemLink = ...
					elseif methodName == "SetBagItem" or methodName == "SetWornItem" then
						local bagId, slotIndex = ...
						itemLink = GetItemLink(bagId, slotIndex)
					elseif methodName == "SetAttachedMailItem" then
						local mailId, attachIndex = ...
						itemLink = GetAttachedItemLink(mailId, attachIndex)
					elseif methodName == "SetLootItem" then
						local lootId = ...
						itemLink = GetLootItemLink(lootId)
					elseif methodName == "SetStoreItem" then
						local entryIndex = ...
						itemLink = GetStoreItemLink(entryIndex)
					elseif methodName == "SetBuybackItem" then
						local entryIndex = ...
						itemLink = GetBuybackItemLink(entryIndex)
					elseif methodName == "SetTradingHouseItem" then
						local index = ...
						itemLink = GetTradingHouseSearchResultItemLink(index)
					elseif methodName == "SetTradingHouseListing" then
						local index = ...
						itemLink = GetTradingHouseListingItemLink(index)
					elseif methodName == "SetQuestReward" then
						local rewardIndex = ...
						itemLink = GetQuestRewardItemLink(rewardIndex)
					end

					if itemLink then
						AddTooltipQuality(self, itemLink)
					end
				end)
			end
		end
	end

	HookSingleTooltip(ItemTooltip)
	HookSingleTooltip(PopupTooltip)
end

-- Safely hooks the universal row layout templates across all list styles
local function HookGameLists()
	local function WrapSetupCallback(targetList)
		if not targetList or not targetList.dataTypes then return end
		for _, dataType in pairs(targetList.dataTypes) do
			local originalSetup = dataType.setupCallback
			if originalSetup and not dataType.cbHooked then
				dataType.cbHooked = true
				dataType.setupCallback = function(rowControl, data, ...)
					originalSetup(rowControl, data, ...)
					DrawColorblindLabel(rowControl, data)
				end
			end
		end
	end

	-- Standard Player Inventories (Backpack, Bank, Guild Bank, Craft Bag, Companion)
	if PLAYER_INVENTORY and PLAYER_INVENTORY.inventories then
		for _, inv in pairs(PLAYER_INVENTORY.inventories) do
			if inv.listView then WrapSetupCallback(inv.listView) end
		end
	end

	-- Guild Store (Search Results & Posted Listings)
	if TRADING_HOUSE then
		if TRADING_HOUSE.searchResultsList then WrapSetupCallback(TRADING_HOUSE.searchResultsList) end
		if TRADING_HOUSE.postedItemsList then WrapSetupCallback(TRADING_HOUSE.postedItemsList) end
	end

	-- NPC Vendors & Buyback
	if STORE_WINDOW and STORE_WINDOW.list then
		WrapSetupCallback(STORE_WINDOW.list)
	end
	if BUY_BACK_WINDOW and BUY_BACK_WINDOW.list then
		WrapSetupCallback(BUY_BACK_WINDOW.list)
	end

	-- Loot Window
	if LOOT_WINDOW and LOOT_WINDOW.list then
		WrapSetupCallback(LOOT_WINDOW.list)
	end

	-- Crafting: Refine, Improve, Research
	if SMITHING and SMITHING.inventory and SMITHING.inventory.list then
		WrapSetupCallback(SMITHING.inventory.list)
	end

	-- Crafting: Blacksmithing, Clothing, Woodworking, Jewelry Deconstruction
	if SMITHING and SMITHING.deconstructionPanel and SMITHING.deconstructionPanel.inventory and SMITHING.deconstructionPanel.inventory.list then
		WrapSetupCallback(SMITHING.deconstructionPanel.inventory.list)
	end

	-- Enchanting: Creation & Extraction (Deconstruction)
	if ENCHANTING and ENCHANTING.inventory and ENCHANTING.inventory.list then
		WrapSetupCallback(ENCHANTING.inventory.list)
	end

	-- Universal Deconstruction (Deconstruction Assistant)
	if UNIVERSAL_DECONSTRUCTION and UNIVERSAL_DECONSTRUCTION.deconstructionPanel and UNIVERSAL_DECONSTRUCTION.deconstructionPanel.inventory and UNIVERSAL_DECONSTRUCTION.deconstructionPanel.inventory.list then
		WrapSetupCallback(UNIVERSAL_DECONSTRUCTION.deconstructionPanel.inventory.list)
	end
end

-- Registers LibAddonMenu-2.0 settings (if installed) and /cb slash commands
local function SetupSettings()
	-- Slash commands (/cb item, /cb enchant)
	SLASH_COMMANDS["/cb"] = function(arg)
		arg = string.lower(arg or "")
		if arg == "item" then
			Colorblind.SavedVars.item_text = not Colorblind.SavedVars.item_text
			Colorblind.Cache = {}
			d("[Colorblind] Item Quality Text: " .. tostring(Colorblind.SavedVars.item_text))
		elseif arg == "enchant" then
			Colorblind.SavedVars.enchant_text = not Colorblind.SavedVars.enchant_text
			Colorblind.Cache = {}
			d("[Colorblind] Enchantment Quality Text: " .. tostring(Colorblind.SavedVars.enchant_text))
		else
			d("[Colorblind] Commands: /cb item | /cb enchant")
		end
	end

	-- Optional LibAddonMenu-2.0 integration
	local LAM = LibAddonMenu2
	if not LAM then return end

	local panelData = {
		type = "panel",
		name = "Colorblind Quality Tags",
		displayName = "Colorblind Quality Tags",
		author = Colorblind.Author,
		version = Colorblind.Version,
		registerForRefresh = true,
	}

	local optionsData = {
		{
			type = "checkbox",
			name = "Show Base Item Quality Tag",
			tooltip = "Displays [Normal], [Fine], [Superior], [Epic], or [Legendary] next to item names.",
			getFunc = function() return Colorblind.SavedVars.item_text end,
			setFunc = function(value)
				Colorblind.SavedVars.item_text = value
				Colorblind.Cache = {}
			end,
		},
		{
			type = "checkbox",
			name = "Show Enchantment Quality Tag",
			tooltip = "Displays an additional quality tag if an item's enchantment quality differs from the base item.",
			getFunc = function() return Colorblind.SavedVars.enchant_text end,
			setFunc = function(value)
				Colorblind.SavedVars.enchant_text = value
				Colorblind.Cache = {}
			end,
		},
	}

	LAM:RegisterAddonPanel(Colorblind.Name .. "Options", panelData)
	LAM:RegisterOptionControls(Colorblind.Name .. "Options", optionsData)
end

-- Delayed initialization to prevent crashing LibChatMessage on load screens
local function OnPlayerActivated(event)
	EVENT_MANAGER:UnregisterForEvent(Colorblind.Name, EVENT_PLAYER_ACTIVATED)
	HookGameLists()
	HookTooltips()
	SetupSettings()
end

local function OnAddOnLoaded(event, addonName)
	if addonName == Colorblind.Name then
		Colorblind.SavedVars = ZO_SavedVars:NewAccountWide("ColorblindVars", Colorblind.SettingsVersion, nil, Colorblind.Default)
		EVENT_MANAGER:RegisterForEvent(Colorblind.Name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
		EVENT_MANAGER:UnregisterForEvent(Colorblind.Name, EVENT_ADD_ON_LOADED)
	end
end

EVENT_MANAGER:RegisterForEvent(Colorblind.Name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
