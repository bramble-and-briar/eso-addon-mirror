-- =================================================================================================
-- Назви предметів в інвентарі, банку, у торговців і в гільдійському магазині.
-- Перевизначає API-функції гри, що повертають назву предмета:
--   • узгоджує прикметники з родом (завжди в українському клієнті);
--   • додає англійську назву в дужках, якщо обрано режим «Українська+Англійська».
-- =================================================================================================

local DovahMova = DovahMova
local ItemNames = DovahMova.ItemNames

local ItemsDisplay = {}
DovahMova.ItemsDisplay = ItemsDisplay

local function FormatName(name, itemLink, mode)
	if DovahMova.isBuildingDatabase then
		return name
	end
	return ItemNames.FormatForDisplay(name, itemLink, mode)
end

local function InventoryMode()
	return DovahMova.settings.ShowItemsDisplay
end

local function GuildStoreMode()
	return DovahMova.settings.ShowGuildStoreDisplay
end

--- Замінює другий результат (назву) функції виду GetXxxInfo(index) -> icon, name, ...
local function HookInfoFunction(functionName, getLink, getMode)
	local original = _G[functionName]
	local function Replace(index, icon, name, ...)
		return icon, FormatName(name, getLink(index), getMode()), ...
	end
	_G[functionName] = function(index, ...)
		return Replace(index, original(index, ...))
	end
end

local installed = false

function ItemsDisplay.Install()
	if installed then
		return
	end
	installed = true

	local rawGetItemLinkName = ItemNames.GetRawItemLinkName
	GetItemLinkName = function(itemLink)
		return FormatName(rawGetItemLinkName(itemLink), itemLink, InventoryMode())
	end

	local rawGetItemName = ItemNames.GetRawItemName
	GetItemName = function(bagId, slotIndex)
		return FormatName(rawGetItemName(bagId, slotIndex), GetItemLink(bagId, slotIndex), InventoryMode())
	end

	HookInfoFunction("GetStoreEntryInfo", GetStoreItemLink, InventoryMode)
	HookInfoFunction("GetBuybackItemInfo", GetBuybackItemLink, InventoryMode)
	HookInfoFunction("GetTradingHouseSearchResultItemInfo", GetTradingHouseSearchResultItemLink, GuildStoreMode)
	HookInfoFunction("GetTradingHouseListingItemInfo", GetTradingHouseListingItemLink, GuildStoreMode)
end
