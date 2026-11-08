local Colorblind = {
	Name = "Colorblind",
	Author = "Lousytourist",
	Version = "2026.11.07",
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

-- Highly optimized extraction helper using fast upvalues
local function GetTrueItemLink(rowControl, data)
	local coreData = data or (rowControl.dataEntry and rowControl.dataEntry.data)
	if not coreData then return nil end

	local bagId = coreData.bagId
	local slotIndex = coreData.slotIndex

	if bagId and slotIndex then
		return GetItemLink(bagId, slotIndex)
	elseif slotIndex then
		return GetTradingHouseSearchResultItemLink(slotIndex)
	end
	
	local itemLink = coreData.itemLink
	if itemLink then return itemLink end
	if type(coreData) == "string" and string.byte(coreData, 1) == 124 then return coreData end -- Fast character check for '|'

	return nil
end

-- Renders the independent accessibility text tag label container
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
		-- CACHE CHECK: Instantly return if we processed this exact item configuration before
		local cachedTag = Colorblind.Cache[itemLink]
		if cachedTag then
			if cachedTag ~= "" then
				cbLabel:SetText(cachedTag)
				cbLabel:SetHidden(false)
			else
				cbLabel:SetHidden(true)
			end
			return
		end

		local tagString = ""

		-- 1. Base Item Quality Processing (Runs universally on all objects)
		local itemQuality = GetItemLinkFunctionalQuality(itemLink)
		if Colorblind.SavedVars.item_text and itemQuality and itemQuality > 0 then
			tagString = tagString .. GetQualityTextTag(itemQuality)
		end

		-- 2. Enchantment Quality Processing (Runs optionally if matching indexes are found)
		if Colorblind.SavedVars.enchant_text then
			-- Convert link object cleanly to string format for split matching safely
			local itemLinkStr = tostring(itemLink)
			local linkParts = { zo_strsplit(":", itemLinkStr) }
			local itemIdStr = linkParts
			local enchantIdStr = linkParts
			local enchantSubIdStr = linkParts
			
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

		-- Write the calculated configuration mapping value straight into the cache
		Colorblind.Cache[itemLink] = tagString

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

-- Safely hooks the universal row layout templates across all list styles
local function HookGameLists()
	local function WrapSetupCallback(targetList)
		if not targetList or not targetList.dataTypes then return end
		for _, dataType in pairs(targetList.dataTypes) do
			local originalSetup = dataType.setupCallback
			if originalSetup then
				dataType.setupCallback = function(rowControl, data, ...)
					originalSetup(rowControl, data, ...)
					DrawColorblindLabel(rowControl, data)
				end
			end
		end
	end

	if PLAYER_INVENTORY and PLAYER_INVENTORY.inventories then
		for _, inv in pairs(PLAYER_INVENTORY.inventories) do
			if inv.listView then WrapSetupCallback(inv.listView) end
		end
	end

	if TRADING_HOUSE and TRADING_HOUSE.searchResultsList then
		WrapSetupCallback(TRADING_HOUSE.searchResultsList)
	end

	if SMITHING and SMITHING.inventory and SMITHING.inventory.list then
		WrapSetupCallback(SMITHING.inventory.list)
	end
end

-- Delayed initialization to prevent crashing LibChatMessage on load screens
local function OnPlayerActivated(event)
	EVENT_MANAGER:UnregisterForEvent(Colorblind.Name, EVENT_PLAYER_ACTIVATED)
	HookGameLists()
end

local function OnAddOnLoaded(event, addonName)
	if addonName == Colorblind.Name then
		Colorblind.SavedVars = ZO_SavedVars:NewAccountWide("ColorblindVars", Colorblind.SettingsVersion, nil, Colorblind.Default)
		EVENT_MANAGER:RegisterForEvent(Colorblind.Name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
		EVENT_MANAGER:UnregisterForEvent(Colorblind.Name, EVENT_ADD_ON_LOADED)
	end
end

EVENT_MANAGER:RegisterForEvent(Colorblind.Name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
