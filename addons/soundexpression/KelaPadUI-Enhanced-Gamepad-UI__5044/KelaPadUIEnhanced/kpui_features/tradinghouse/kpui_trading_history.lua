-- KelaPadUI trading history.
-- Centralizes the former standalone KelaPadUIBuyingData and KelaPadUIListingData add-ons.
-- Data is stored in the existing kpuiSavedVariables file so no additional SavedVariables are needed.

KELA_BUYING_DATA_RETENTION_PERIOD = 30
KELA_LISTING_DATA_RETENTION_PERIOD = 30
KELA_ITEMDATA_WITH_COUNTCHANGE = {}

KPUI_ICON_TRADED = "|t14:14:KelaPadUI/kpui_textures/traded.dds|t"
KPUI_ICON_SOLD = "|t14:14:KelaPadUI/kpui_textures/sold.dds|t"
KPUI_ICON_RECALLED = "|t14:14:KelaPadUI/kpui_textures/recalled.dds|t"

KELA_ATT_GUILD_STAT = {}

-- Trade categories used by the guild statistics tooltip.
KELA_TRADE_CATEGORY_MISCELLANEOUS = 1
KELA_TRADE_CATEGORY_WEAPONS = 2
KELA_TRADE_CATEGORY_ARMOR = 3
KELA_TRADE_CATEGORY_JEWELRY = 4
KELA_TRADE_CATEGORY_ALCHEMY_REAGENTS = 5
KELA_TRADE_CATEGORY_ALCHEMY_BASE = 6
KELA_TRADE_CATEGORY_ALCHEMY_POTION = 7
KELA_TRADE_CATEGORY_ALCHEMY_POISON = 8
KELA_TRADE_CATEGORY_PROVISIONING_MATERIAL = 9
KELA_TRADE_CATEGORY_PROVISIONING_DRINK = 10
KELA_TRADE_CATEGORY_PROVISIONING_FOOD = 11
KELA_TRADE_CATEGORY_CRAFTING_RAW = 12
KELA_TRADE_CATEGORY_CRAFTING_MATERIAL = 13
KELA_TRADE_CATEGORY_CRAFTING_BOOSTER = 14
KELA_TRADE_CATEGORY_CRAFTING_TRAIT = 15
KELA_TRADE_CATEGORY_CRAFTING_STYLE_MATERIAL = 16
KELA_TRADE_CATEGORY_STYLE_MOTIF = 17
KELA_TRADE_CATEGORY_MASTER_WRIT = 18
KELA_TRADE_CATEGORY_RECIPES = 19
KELA_TRADE_CATEGORY_FURNISHING_MATERIAL = 20
KELA_TRADE_CATEGORY_FURNISHING = 21
KELA_TRADE_CATEGORY_SIEGES = 22
KELA_TRADE_CATEGORY_ENCHANTING_RUNE = 23
KELA_TRADE_CATEGORY_ENCHANTING_GLYPH = 24
KELA_TRADE_CATEGORY_TOOL = 25
KELA_TRADE_CATEGORY_LOCKPICK = 26
KELA_TRADE_CATEGORY_LURE = 27
KELA_TRADE_CATEGORY_SOUL_GEM = 28
KELA_TRADE_CATEGORY_FISH = 29
KELA_TRADE_CATEGORY_TROPHY = 30
KELA_TRADE_CATEGORY_COLLECTIBLE = 31
KELA_TRADE_CATEGORY_TREASURE = 32
KELA_TRADE_CATEGORY_TRASH = 33

local ITEM_TYPE_TO_CATEGORY_MAP = {
	[ITEMTYPE_WEAPON] = KELA_TRADE_CATEGORY_WEAPONS,
	[ITEMTYPE_REAGENT] = KELA_TRADE_CATEGORY_ALCHEMY_REAGENTS,
	[ITEMTYPE_POTION_BASE] = KELA_TRADE_CATEGORY_ALCHEMY_BASE,
	[ITEMTYPE_POISON_BASE] = KELA_TRADE_CATEGORY_ALCHEMY_BASE,
	[ITEMTYPE_POTION] = KELA_TRADE_CATEGORY_ALCHEMY_POTION,
	[ITEMTYPE_POISON] = KELA_TRADE_CATEGORY_ALCHEMY_POISON,
	[ITEMTYPE_INGREDIENT] = KELA_TRADE_CATEGORY_PROVISIONING_MATERIAL,
	[ITEMTYPE_ADDITIVE] = KELA_TRADE_CATEGORY_PROVISIONING_MATERIAL,
	[ITEMTYPE_SPICE] = KELA_TRADE_CATEGORY_PROVISIONING_MATERIAL,
	[ITEMTYPE_FLAVORING] = KELA_TRADE_CATEGORY_PROVISIONING_MATERIAL,
	[ITEMTYPE_DRINK] = KELA_TRADE_CATEGORY_PROVISIONING_DRINK,
	[ITEMTYPE_FOOD] = KELA_TRADE_CATEGORY_PROVISIONING_FOOD,
	[ITEMTYPE_BLACKSMITHING_RAW_MATERIAL] = KELA_TRADE_CATEGORY_CRAFTING_RAW,
	[ITEMTYPE_CLOTHIER_RAW_MATERIAL] = KELA_TRADE_CATEGORY_CRAFTING_RAW,
	[ITEMTYPE_WOODWORKING_RAW_MATERIAL] = KELA_TRADE_CATEGORY_CRAFTING_RAW,
	[ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL] = KELA_TRADE_CATEGORY_CRAFTING_RAW,
	[ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER] = KELA_TRADE_CATEGORY_CRAFTING_RAW,
	[ITEMTYPE_BLACKSMITHING_MATERIAL] = KELA_TRADE_CATEGORY_CRAFTING_MATERIAL,
	[ITEMTYPE_CLOTHIER_MATERIAL] = KELA_TRADE_CATEGORY_CRAFTING_MATERIAL,
	[ITEMTYPE_JEWELRYCRAFTING_MATERIAL] = KELA_TRADE_CATEGORY_CRAFTING_MATERIAL,
	[ITEMTYPE_WOODWORKING_MATERIAL] = KELA_TRADE_CATEGORY_CRAFTING_MATERIAL,
	[ITEMTYPE_BLACKSMITHING_BOOSTER] = KELA_TRADE_CATEGORY_CRAFTING_BOOSTER,
	[ITEMTYPE_CLOTHIER_BOOSTER] = KELA_TRADE_CATEGORY_CRAFTING_BOOSTER,
	[ITEMTYPE_JEWELRYCRAFTING_BOOSTER] = KELA_TRADE_CATEGORY_CRAFTING_BOOSTER,
	[ITEMTYPE_WOODWORKING_BOOSTER] = KELA_TRADE_CATEGORY_CRAFTING_BOOSTER,
	[ITEMTYPE_ARMOR_TRAIT] = KELA_TRADE_CATEGORY_CRAFTING_TRAIT,
	[ITEMTYPE_WEAPON_TRAIT] = KELA_TRADE_CATEGORY_CRAFTING_TRAIT,
	[ITEMTYPE_JEWELRY_RAW_TRAIT] = KELA_TRADE_CATEGORY_CRAFTING_TRAIT,
	[ITEMTYPE_JEWELRY_TRAIT] = KELA_TRADE_CATEGORY_CRAFTING_TRAIT,
	[ITEMTYPE_STYLE_MATERIAL] = KELA_TRADE_CATEGORY_CRAFTING_STYLE_MATERIAL,
	[ITEMTYPE_RAW_MATERIAL] = KELA_TRADE_CATEGORY_CRAFTING_STYLE_MATERIAL,
	[ITEMTYPE_RACIAL_STYLE_MOTIF] = KELA_TRADE_CATEGORY_STYLE_MOTIF,
	[ITEMTYPE_MASTER_WRIT] = KELA_TRADE_CATEGORY_MASTER_WRIT,
	[ITEMTYPE_RECIPE] = KELA_TRADE_CATEGORY_RECIPES,
	[ITEMTYPE_FURNISHING_MATERIAL] = KELA_TRADE_CATEGORY_FURNISHING_MATERIAL,
	[ITEMTYPE_FURNISHING] = KELA_TRADE_CATEGORY_FURNISHING,
	[ITEMTYPE_SIEGE] = KELA_TRADE_CATEGORY_SIEGES,
	[ITEMTYPE_AVA_REPAIR] = KELA_TRADE_CATEGORY_SIEGES,
	[ITEMTYPE_ENCHANTING_RUNE_POTENCY] = KELA_TRADE_CATEGORY_ENCHANTING_RUNE,
	[ITEMTYPE_ENCHANTING_RUNE_ASPECT] = KELA_TRADE_CATEGORY_ENCHANTING_RUNE,
	[ITEMTYPE_ENCHANTING_RUNE_ESSENCE] = KELA_TRADE_CATEGORY_ENCHANTING_RUNE,
	[ITEMTYPE_GLYPH_WEAPON] = KELA_TRADE_CATEGORY_ENCHANTING_GLYPH,
	[ITEMTYPE_GLYPH_ARMOR] = KELA_TRADE_CATEGORY_ENCHANTING_GLYPH,
	[ITEMTYPE_GLYPH_JEWELRY] = KELA_TRADE_CATEGORY_ENCHANTING_GLYPH,
	[ITEMTYPE_TOOL] = KELA_TRADE_CATEGORY_TOOL,
	[ITEMTYPE_GROUP_REPAIR] = KELA_TRADE_CATEGORY_TOOL,
	[ITEMTYPE_LOCKPICK] = KELA_TRADE_CATEGORY_LOCKPICK,
	[ITEMTYPE_LURE] = KELA_TRADE_CATEGORY_LURE,
	[ITEMTYPE_SOUL_GEM] = KELA_TRADE_CATEGORY_SOUL_GEM,
	[ITEMTYPE_FISH] = KELA_TRADE_CATEGORY_FISH,
	[ITEMTYPE_TROPHY] = KELA_TRADE_CATEGORY_TROPHY,
	[ITEMTYPE_COLLECTIBLE] = KELA_TRADE_CATEGORY_COLLECTIBLE,
	[ITEMTYPE_TREASURE] = KELA_TRADE_CATEGORY_TREASURE,
	[ITEMTYPE_TRASH] = KELA_TRADE_CATEGORY_TRASH,
}

local ARMOR_EQUIP_TYPE_TO_CATEGORY_MAP = {
	[EQUIP_TYPE_CHEST] = KELA_TRADE_CATEGORY_ARMOR,
	[EQUIP_TYPE_FEET] = KELA_TRADE_CATEGORY_ARMOR,
	[EQUIP_TYPE_HAND] = KELA_TRADE_CATEGORY_ARMOR,
	[EQUIP_TYPE_HEAD] = KELA_TRADE_CATEGORY_ARMOR,
	[EQUIP_TYPE_LEGS] = KELA_TRADE_CATEGORY_ARMOR,
	[EQUIP_TYPE_SHOULDERS] = KELA_TRADE_CATEGORY_ARMOR,
	[EQUIP_TYPE_WAIST] = KELA_TRADE_CATEGORY_ARMOR,
	[EQUIP_TYPE_NECK] = KELA_TRADE_CATEGORY_JEWELRY,
	[EQUIP_TYPE_RING] = KELA_TRADE_CATEGORY_JEWELRY,
}

function KelaGetItemTradeCategory(itemLink)
	if not itemLink then
		return KELA_TRADE_CATEGORY_MISCELLANEOUS
	end

	local itemType = GetItemLinkItemType(itemLink)
	if itemType == ITEMTYPE_ARMOR then
		return ARMOR_EQUIP_TYPE_TO_CATEGORY_MAP[GetItemLinkEquipType(itemLink)] or KELA_TRADE_CATEGORY_ARMOR
	end

	return ITEM_TYPE_TO_CATEGORY_MAP[itemType] or KELA_TRADE_CATEGORY_MISCELLANEOUS
end

local function GetBuyingTable()
	return kpuiSVBuyingData and kpuiSVBuyingData["buyingTable"]
end

local function GetListingTable()
	return kpuiSVListingData and kpuiSVListingData["listingTable"]
end

function KelaAddToBuyingUniqueTable(uniqueId, itemName, buyPrice, buyPricePerUnit, listingIndex, displayQuality)
	local buyingTable = GetBuyingTable()
	if not buyingTable or not uniqueId then
		return
	end

	local itemUID = Id64ToString(uniqueId)
	local guildName = ""
	local currentGuildId = GetSelectedTradingHouseGuildId()
	if currentGuildId then
		_, guildName = GetCurrentTradingHouseGuildDetails()
	end

	buyingTable[itemUID] = {
		["buyingTimeStamp"] = GetTimeStamp(),
		["guildName"] = guildName,
		["itemName"] = itemName,
		["displayQuality"] = displayQuality,
		["buyPrice"] = buyPrice,
		["buyPricePerUnit"] = buyPricePerUnit,
	}
end

local function KelaCleanupBuyingHistory()
	local buyingTable = GetBuyingTable()
	if not buyingTable then
		return
	end

	local checkingTimeStamp = GetTimeStamp() - (KELA_BUYING_DATA_RETENTION_PERIOD * ZO_ONE_DAY_IN_SECONDS)
	for itemUID, data in pairs(buyingTable) do
		if type(data) == "table" and (tonumber(data["buyingTimeStamp"]) or 0) < checkingTimeStamp then
			buyingTable[itemUID] = nil
		end
	end
end

local function KelaOnTradingHistoryInventoryChanged(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason, stackCountChange)
	local buyingTable = GetBuyingTable()
	if not buyingTable then
		return
	end

	local link = GetItemLink(bagId, slotIndex)
	if link == "" then
		KELA_ITEMDATA_WITH_COUNTCHANGE = {}
		return
	end

	if not isNewItem and stackCountChange and stackCountChange > 0 then
		local uniqueId = GetItemUniqueId(bagId, slotIndex)
		if uniqueId then
			local itemUID = Id64ToString(uniqueId)
			local itemName = GetItemName(bagId, slotIndex)
			for uid, data in pairs(buyingTable) do
				if type(data) == "table" and data["itemName"] == itemName then
					KELA_ITEMDATA_WITH_COUNTCHANGE = {
						["itemUID"] = itemUID,
						["link"] = link,
						["itemName"] = itemName,
					}
					break
				end
			end
		end
	elseif not isNewItem and stackCountChange and stackCountChange < 0 then
		local pendingData = KELA_ITEMDATA_WITH_COUNTCHANGE
		if pendingData["link"] == link and pendingData["itemName"] then
			for uid, data in pairs(buyingTable) do
				if type(data) == "table" and data["itemName"] == pendingData["itemName"] then
					buyingTable[pendingData["itemUID"]] = data
					break
				end
			end
		end
		KELA_ITEMDATA_WITH_COUNTCHANGE = {}
	else
		KELA_ITEMDATA_WITH_COUNTCHANGE = {}
	end
end

function KelaAddToListingTable(bagId, listingIndex, stackCount, desiredPrice)
	local listingTable = GetListingTable()
	if not listingTable or not listingIndex then
		return
	end

	local itemLink = GetItemLink(bagId, listingIndex)
	if itemLink == "" then
		return
	end

	local currentGuildId = GetSelectedTradingHouseGuildId()
	local guildName = currentGuildId and GetGuildName(currentGuildId) or ""
	local listingTime = GetTimeStamp()
	while listingTable[listingTime] do
		listingTime = listingTime + 0.001
	end

	listingTable[listingTime] = {
		["itemLink"] = itemLink,
		["stackCount"] = stackCount,
		["guildId"] = currentGuildId,
		["guildName"] = guildName,
		["desiredPrice"] = desiredPrice,
		["result"] = KPUI_ICON_TRADED,
		["seller"] = GetUnitDisplayName("player"),
	}
end

function KelaRemoveFromListingTable(listingIndex, stackCount, desiredPrice, timeRemaining, itemSoldLink, seller, timeSinceEvent, guild)
	local listingTable = GetListingTable()
	if not listingTable then
		return
	end

	local removingTime = timeSinceEvent and (GetTimeStamp() - timeSinceEvent) or GetTimeStamp()
	local itemLink
	local resultIcon
	local unknownMustAdd

	if not itemSoldLink then
		if not listingIndex then
			return
		end
		itemLink = GetTradingHouseListingItemLink(listingIndex)
		resultIcon = KPUI_ICON_RECALLED
		unknownMustAdd = true
	else
		itemLink = itemSoldLink
		resultIcon = KPUI_ICON_SOLD
		unknownMustAdd = (GetUnitDisplayName("player") == seller)
	end

	if not itemLink then
		return
	end

	local currentGuildId
	local guildName
	if type(guild) == "string" then
		guildName = guild
		for i = 1, GetNumGuilds() do
			local guildId = GetGuildId(i)
			if GetGuildName(guildId) == guildName then
				currentGuildId = guildId
				break
			end
		end
	else
		currentGuildId = type(guild) == "number" and guild or GetSelectedTradingHouseGuildId()
		if currentGuildId then
			guildName = GetGuildName(currentGuildId)
		end
	end

	if not guildName or guildName == "" then
		return
	end

	local listingTime = removingTime - (ZO_ONE_MONTH_IN_SECONDS - (timeRemaining or 0))
	local removed = false
	local stackCountValue = tonumber(stackCount) or stackCount
	local desiredPriceValue = tonumber(desiredPrice) or desiredPrice

	for startTime, listingItem in pairs(listingTable) do
		local sellerMatches = seller == nil or seller == listingItem["seller"]
		local listingStackCount = tonumber(listingItem["stackCount"]) or listingItem["stackCount"]
		local listingDesiredPrice = tonumber(listingItem["desiredPrice"]) or listingItem["desiredPrice"]
		if sellerMatches
			and KelaCompareLink(itemLink, listingItem["itemLink"])
			and listingStackCount == stackCountValue
			and listingDesiredPrice == desiredPriceValue
			and listingItem["guildName"] == guildName then
			if listingItem["result"] == KPUI_ICON_TRADED then
				KelaSetValueIfNil(listingItem, "period", removingTime - startTime)
				listingItem["result"] = resultIcon
			end
			removed = true
			break
		end
	end

	if not removed and unknownMustAdd then
		while listingTable[listingTime] do
			listingTime = listingTime + 0.001
		end
		listingTable[listingTime] = {
			["itemLink"] = itemLink,
			["stackCount"] = stackCount,
			["guildId"] = currentGuildId,
			["guildName"] = guildName,
			["desiredPrice"] = desiredPrice,
			["period"] = removingTime - listingTime,
			["result"] = resultIcon,
			["seller"] = GetUnitDisplayName("player"),
		}
	end
end

function KelaGetItemLinkListingTable(itemLink)
	local listingItemsTable = {}
	local listingTable = GetListingTable()
	if not listingTable or not itemLink then
		return listingItemsTable
	end

	for listingTime, listingItem in pairs(listingTable) do
		if type(listingItem) == "table" and KelaCompareLink(itemLink, listingItem["itemLink"]) then
			listingItemsTable[listingTime] = listingItem
		end
	end

	return listingItemsTable
end

local function KelaCleanupListingHistory()
	local listingTable = GetListingTable()
	if not listingTable then
		return
	end

	local checkingTimeStamp = GetTimeStamp() - (KELA_LISTING_DATA_RETENTION_PERIOD * ZO_ONE_DAY_IN_SECONDS)
	for listingTime, data in pairs(listingTable) do
		if type(listingTime) == "number" and listingTime < checkingTimeStamp then
			listingTable[listingTime] = nil
		end
	end
end

local function KelaUpdateGuildList()
	if not kpuiSVListingData then
		return
	end

	KelaSetValueIfNil(kpuiSVListingData, "guildsTable", {})
	local guildsTable = kpuiSVListingData["guildsTable"]

	for i = 1, GetNumGuilds() do
		local guildId = GetGuildId(i)
		local guildName = GetGuildName(guildId)
		if guildName ~= "" then
			KelaSetValueIfNil(guildsTable, guildName, {})
			if type(guildsTable[guildName]) ~= "table" then
				guildsTable[guildName] = {}
			end
			guildsTable[guildName]["guildId"] = guildId
		end
	end
end

local function GetATTSalesTables()
	local salesModule = ArkadiusTradeTools and ArkadiusTradeTools.Modules and ArkadiusTradeTools.Modules.Sales
	return salesModule and salesModule.SalesTables
end

local function ForEachATTSale(callback)
	local salesTables = GetATTSalesTables()
	if not salesTables then
		return false
	end

	local serverName = GetWorldName()
	for i = 1, #salesTables do
		local serverData = salesTables[i] and salesTables[i][serverName]
		local sales = serverData and serverData.sales
		if sales then
			for _, sale in pairs(sales) do
				if type(sale) == "table" then
					callback(sale)
				end
			end
		end
	end

	return true
end

function KelaUpdateGuildATTStat()
	if not GetATTSalesTables() then
		return false
	end

	KELA_ATT_GUILD_STAT = {}

	local periodDays = KelaGetATTAnalysisPeriod()
	local period = periodDays * ZO_ONE_DAY_IN_SECONDS
	local cutoff = GetTimeStamp() - period

	ForEachATTSale(function(sale)
		local eventTimeStamp = tonumber(sale["timeStamp"])
		local guildName = sale["guildName"]
		local itemLink = sale["itemLink"]
		if eventTimeStamp and eventTimeStamp > cutoff and guildName and guildName ~= "" and itemLink then
			local category = KelaGetItemTradeCategory(itemLink)
			local price = tonumber(sale["price"]) or 0
			local quantity = tonumber(sale["quantity"]) or 0

			KelaSetValueIfNil(KELA_ATT_GUILD_STAT, category, {})
			KelaSetValueIfNil(KELA_ATT_GUILD_STAT[category], guildName, { ["price"] = 0, ["quantity"] = 0 })
			local guildStat = KELA_ATT_GUILD_STAT[category][guildName]
			guildStat["price"] = (tonumber(guildStat["price"]) or 0) + price
			guildStat["quantity"] = (tonumber(guildStat["quantity"]) or 0) + quantity
		end
	end)

	return true
end

function KelaSetupATTFunctions()
	local playerName = GetUnitDisplayName("player")
	local now = GetTimeStamp()
	local cutoff = now - KELA_LISTING_DATA_RETENTION_PERIOD * ZO_ONE_DAY_IN_SECONDS
	local hasSalesTables = ForEachATTSale(function(sale)
		local sellerName = sale["sellerName"]
		if sellerName == playerName then
			local eventTimeStamp = tonumber(sale["timeStamp"])
			if eventTimeStamp and eventTimeStamp > cutoff then
				KelaRemoveFromListingTable(
					nil,
					sale["quantity"],
					sale["price"],
					nil,
					sale["itemLink"],
					sellerName,
					now - eventTimeStamp,
					sale["guildName"]
				)
			end
		end
	end)

	if not hasSalesTables then
		return false
	end

	KelaUpdateGuildATTStat()
	return true
end

local attSetupAttempts = 0
local function TryATTSetup()
	attSetupAttempts = attSetupAttempts + 1
	if KelaSetupATTFunctions() then
		return
	end
	if attSetupAttempts < 10 then
		zo_callLater(TryATTSetup, 1000)
	end
end

function KelaInitializeTradingHistory()
	if kpuiSVBuyingData and kpuiSVListingData then
		return true
	end

	if type(kpuiSavedVariables) ~= "table" then
		kpuiSavedVariables = {}
	end

	if type(kpuiSavedVariables.buyingData) ~= "table" then
		kpuiSavedVariables.buyingData = type(kpuiSavedVariablesBuyingData) == "table" and kpuiSavedVariablesBuyingData or {}
	end
	if type(kpuiSavedVariables.listingData) ~= "table" then
		kpuiSavedVariables.listingData = type(kpuiSavedVariablesListingData) == "table" and kpuiSavedVariablesListingData or {}
	end

	kpuiSVBuyingData = kpuiSavedVariables.buyingData
	kpuiSVListingData = kpuiSavedVariables.listingData

	KelaSetValueIfNil(kpuiSVBuyingData, "buyingTable", {})
	KelaSetValueIfNil(kpuiSVListingData, "listingTable", {})
	KelaSetValueIfNil(kpuiSVListingData, "guildsTable", {})

	KelaCleanupBuyingHistory()
	KelaCleanupListingHistory()
	KelaUpdateGuildList()

	if not KelaPadUI.KelaTradingHistoryEventsRegistered then
		EVENT_MANAGER:RegisterForEvent("KelaPadUI_TradingHistoryInventory", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, KelaOnTradingHistoryInventoryChanged)
		EVENT_MANAGER:AddFilterForEvent("KelaPadUI_TradingHistoryInventory", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
		KelaPadUI.KelaTradingHistoryEventsRegistered = true
	end

	if ArkadiusTradeTools then
		attSetupAttempts = 0
		zo_callLater(TryATTSetup, 0)
	end

	return true
end
