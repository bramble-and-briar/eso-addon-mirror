-- =================================================================================================
-- Спливаючі вікна предметів: англійські назви предмета, зачарування, трейту та сету.
--
-- Принцип: перед показом підказки тимчасово підміняємо рядки-шаблони гри
-- (SI_TOOLTIP_ITEM_NAME тощо) готовим текстом, а після показу — відновлюємо оригінали.
-- =================================================================================================

local DovahMova = DovahMova
local Util = DovahMova.Util
local ItemNames = DovahMova.ItemNames

local ItemTooltips = {}
DovahMova.ItemTooltips = ItemTooltips

local STRING_OVERRIDE_VERSION = 10

-- Рядки гри, які модуль тимчасово підміняє
local OVERRIDDEN_STRINGS = {
	"SI_TOOLTIP_ITEM_NAME",
	"SI_ITEM_FORMAT_STR_ENCHANT_HEADER_NAMED",
	"SI_ITEM_FORMAT_STR_ITEM_TRAIT_HEADER",
	"SI_ITEM_FORMAT_STR_ITEM_TRAIT_WITH_ICON_HEADER",
	"SI_ITEM_FORMAT_STR_SET_NAME",
}
local originalStrings = {}

local TRAIT_TYPES = {
	[ITEMTYPE_ARMOR] = true,
	[ITEMTYPE_WEAPON] = true,
	[ITEMTYPE_ARMOR_TRAIT] = true,
	[ITEMTYPE_JEWELRY_TRAIT] = true,
	[ITEMTYPE_WEAPON_TRAIT] = true,
}
local ENCHANT_TYPES = {
	[ITEMTYPE_ARMOR] = true,
	[ITEMTYPE_WEAPON] = true,
	[ITEMTYPE_GLYPH_ARMOR] = true,
	[ITEMTYPE_GLYPH_JEWELRY] = true,
	[ITEMTYPE_GLYPH_WEAPON] = true,
}

local function Override(stringName, text)
	SafeAddString(_G[stringName], text, STRING_OVERRIDE_VERSION)
end

function ItemTooltips.RestoreStrings()
	for stringName, text in pairs(originalStrings) do
		SafeAddString(_G[stringName], text, STRING_OVERRIDE_VERSION)
	end
end

local function IsEnabled()
	local settings = DovahMova.settings
	return settings.ShowItemsNamesTooltip ~= DovahMova.MODE_UA
		or settings.ShowItemsEnchantsTooltip ~= DovahMova.MODE_UA
		or settings.ShowItemsTraitsTooltip ~= DovahMova.MODE_UA
		or settings.ShowItemsSetsTooltip ~= DovahMova.MODE_UA
end

local function OverrideName(itemLink, itemType)
	local mode = DovahMova.settings.ShowItemsNamesTooltip
	if mode == DovahMova.MODE_UA then
		return
	end
	local rawName = ItemNames.GetRawItemLinkName(itemLink)
	if not rawName or rawName == "" then
		return
	end
	local ukrainianName = ZO_CachedStrFormat(originalStrings.SI_TOOLTIP_ITEM_NAME, DovahMova.Adjectives.ProcessItemName(rawName))
	local englishName = ItemNames.GetEnglishName(ukrainianName, GetItemLinkItemId(itemLink), itemType)
	if englishName then
		Override("SI_TOOLTIP_ITEM_NAME", Util.FormatBilingual(ukrainianName, englishName, mode))
	end
end

local function OverrideEnchant(itemLink, itemType)
	local mode = DovahMova.settings.ShowItemsEnchantsTooltip
	if mode == DovahMova.MODE_UA or not ENCHANT_TYPES[itemType] then
		return
	end
	local englishEnchant = DovahMova.StaticData.EnchantNames[GetItemLinkFinalEnchantId(itemLink)]
	local _, enchantHeader = GetItemLinkEnchantInfo(itemLink)
	local ukrainianEnchant = enchantHeader and string.match(enchantHeader, ": (.*)$")
	if englishEnchant and ukrainianEnchant then
		local text = Util.FormatBilingual(ukrainianEnchant, englishEnchant, mode)
		Override("SI_ITEM_FORMAT_STR_ENCHANT_HEADER_NAMED", ZO_CachedStrFormat(originalStrings.SI_ITEM_FORMAT_STR_ENCHANT_HEADER_NAMED, text))
	end
end

local function OverrideTrait(itemLink, itemType)
	local mode = DovahMova.settings.ShowItemsTraitsTooltip
	if mode == DovahMova.MODE_UA or not TRAIT_TYPES[itemType] then
		return
	end
	local traitType = GetItemLinkTraitType(itemLink)
	local englishTrait = DovahMova.db.Traits[traitType]
	if englishTrait then
		local text = Util.FormatBilingual(GetString("SI_ITEMTRAITTYPE", traitType), englishTrait, mode)
		Override("SI_ITEM_FORMAT_STR_ITEM_TRAIT_HEADER", text)
		Override("SI_ITEM_FORMAT_STR_ITEM_TRAIT_WITH_ICON_HEADER", Util.PlainReplace(originalStrings.SI_ITEM_FORMAT_STR_ITEM_TRAIT_WITH_ICON_HEADER, "<<2>>", text))
	end
end

local function OverrideSet(itemLink, itemType)
	local mode = DovahMova.settings.ShowItemsSetsTooltip
	if mode == DovahMova.MODE_UA or not ItemNames.GEAR_TYPES[itemType] then
		return
	end
	local hasSet, ukrainianSet, _, _, _, setId = GetItemLinkSetInfo(itemLink, false)
	local englishSet = hasSet and DovahMova.db.Sets[setId]
	if englishSet then
		local text
		if mode == DovahMova.MODE_UAEN then
			text = string.format("«%s» (%s)", ukrainianSet, englishSet)
		else
			text = string.format("«%s»", englishSet)
		end
		Override("SI_ITEM_FORMAT_STR_SET_NAME", Util.PlainReplace(originalStrings.SI_ITEM_FORMAT_STR_SET_NAME, "«<<1>>»", text))
	end
end

--- Готує рядки-шаблони для підказки конкретного предмета.
function ItemTooltips.PrepareStrings(itemLink)
	if not itemLink or itemLink == "" or not IsEnabled() then
		return
	end
	local itemType = GetItemLinkItemType(itemLink)
	OverrideName(itemLink, itemType)
	OverrideEnchant(itemLink, itemType)
	OverrideTrait(itemLink, itemType)
	OverrideSet(itemLink, itemType)
end

-- -------------------------------------------------------------------------------------------------
-- Хуки підказок
-- -------------------------------------------------------------------------------------------------

local function GetWornItemLink(slotIndex, bagId)
	return GetItemLink(bagId, slotIndex)
end

local function PassLink(itemLink)
	return itemLink
end

local function GetKnownAlchemyResultLink(...)
	local itemLink, result = GetAlchemyResultingItemLink(...)
	if result == PROSPECTIVE_ALCHEMY_RESULT_KNOWN then
		return itemLink
	end
	return nil
end

--- Обгортає метод підказки: готує рядки -> викликає оригінал -> відновлює рядки.
-- getLink отримує аргументи методу і повертає посилання на предмет.
local function HookTooltipMethod(tooltip, methodName, getLink)
	if not tooltip or not tooltip[methodName] then
		return
	end
	local original = tooltip[methodName]
	tooltip[methodName] = function(self, ...)
		ItemTooltips.PrepareStrings(getLink(...))
		original(self, ...)
		ItemTooltips.RestoreStrings()
	end
end

local function PreHookGamepad(object, methodName, getLink)
	if not object or not object[methodName] then
		return
	end
	ZO_PreHook(object, methodName, function(self, ...)
		ItemTooltips.PrepareStrings(getLink(self, ...))
	end)
	ZO_PostHook(object, methodName, ItemTooltips.RestoreStrings)
end

local function InstallKeyboardHooks()
	HookTooltipMethod(ItemTooltip, "SetAttachedMailItem", GetAttachedItemLink)
	HookTooltipMethod(ItemTooltip, "SetBagItem", GetItemLink)
	HookTooltipMethod(ItemTooltip, "SetBuybackItem", GetBuybackItemLink)
	HookTooltipMethod(ItemTooltip, "SetLink", PassLink)
	HookTooltipMethod(ItemTooltip, "SetLootItem", GetLootItemLink)
	HookTooltipMethod(ItemTooltip, "SetStoreItem", GetStoreItemLink)
	HookTooltipMethod(ItemTooltip, "SetTradeItem", GetTradeItemLink)
	HookTooltipMethod(ItemTooltip, "SetTradingHouseItem", GetTradingHouseSearchResultItemLink)
	HookTooltipMethod(ItemTooltip, "SetTradingHouseListing", GetTradingHouseListingItemLink)
	HookTooltipMethod(ItemTooltip, "SetWornItem", GetWornItemLink)
	HookTooltipMethod(ItemTooltip, "SetReward", GetItemRewardItemLink)
	HookTooltipMethod(ItemTooltip, "SetItemUsingEnchantment", GetEnchantedItemResultingItemLink)
	HookTooltipMethod(ItemTooltip, "SetAction", GetSlotItemLink)
	HookTooltipMethod(ItemTooltip, "SetItemSetCollectionPieceLink", PassLink)
	HookTooltipMethod(PopupTooltip, "SetLink", PassLink)

	HookTooltipMethod(ZO_AlchemyTopLevelTooltip, "SetPendingAlchemyItem", GetKnownAlchemyResultLink)
	HookTooltipMethod(ZO_EnchantingTopLevelTooltip, "SetPendingEnchantingItem", GetEnchantingResultingItemLink)
	HookTooltipMethod(ZO_ProvisionerTopLevelTooltip, "SetProvisionerResultItem", GetRecipeResultItemLink)
	HookTooltipMethod(ZO_SmithingTopLevelCreationPanelResultTooltip, "SetPendingSmithingItem", GetSmithingPatternResultLink)
	HookTooltipMethod(ZO_SmithingTopLevelImprovementPanelResultTooltip, "SetSmithingImprovementResult", GetSmithingImprovedItemLink)
	HookTooltipMethod(ZO_RetraitStation_KeyboardTopLevelRetraitPanelResultTooltip, "SetPendingRetraitItem", GetResultingItemLinkAfterRetrait)
	HookTooltipMethod(ZO_RetraitStation_KeyboardTopLevelRetraitPanelResultTooltip, "SetBagItem", GetItemLink)
	HookTooltipMethod(ZO_RetraitStation_KeyboardTopLevelReconstructPanelOptionsPreviewTooltip, "SetItemSetCollectionPieceLink", PassLink)

	-- Підказка порівняння з одягненим предметом
	local function OnAddComparativeGameData(tooltip, gameDataType, ...)
		if gameDataType == TOOLTIP_GAME_DATA_EQUIPPED_INFO then
			local slotIndex, actorCategory = ...
			ItemTooltips.PrepareStrings(GetItemLink(GetWornBagForGameplayActorCategory(actorCategory), slotIndex))
		elseif gameDataType == TOOLTIP_GAME_DATA_MYTHIC_OR_STOLEN then
			ItemTooltips.RestoreStrings()
		end
	end
	ZO_PreHookHandler(ComparativeTooltip1, "OnAddGameData", OnAddComparativeGameData)
	ZO_PreHookHandler(ComparativeTooltip2, "OnAddGameData", OnAddComparativeGameData)
end

local function InstallGamepadHooks()
	local function FirstArgument(_, itemLink)
		return itemLink
	end
	for _, tooltipType in ipairs({ GAMEPAD_LEFT_TOOLTIP, GAMEPAD_RIGHT_TOOLTIP, GAMEPAD_MOVABLE_TOOLTIP }) do
		PreHookGamepad(GAMEPAD_TOOLTIPS:GetTooltip(tooltipType), "LayoutItem", FirstArgument)
	end

	PreHookGamepad(ZO_GamepadSmithingCreation, "SetupResultTooltip", function(_, ...)
		return GetSmithingPatternResultLink(...)
	end)
	PreHookGamepad(ZO_GamepadSmithingImprovement, "SetupResultTooltip", function(_, ...)
		return GetSmithingImprovedItemLink(...)
	end)
	PreHookGamepad(ZO_GamepadAlchemy, "UpdateTooltip", function(station)
		return GetKnownAlchemyResultLink(station:GetAllCraftingBagAndSlots())
	end)
	PreHookGamepad(ZO_GamepadEnchanting, "UpdateTooltip", function(station)
		if station:IsCraftable() then
			return GetEnchantingResultingItemLink(station:GetAllCraftingBagAndSlots())
		elseif station:IsExtractable() and station.extractionSlot:HasOneItem() then
			return GetItemLink(station.extractionSlot:GetItemBagAndSlot(1))
		end
	end)
	PreHookGamepad(ZO_GamepadProvisioner, "RefreshRecipeDetails", function(_, selectedData)
		if selectedData then
			return GetRecipeResultItemLink(selectedData.recipeListIndex, selectedData.recipeIndex)
		end
	end)
	PreHookGamepad(ZO_GamepadSmithingExtraction, "RefreshTooltip", function(station)
		if station.extractionSlot:HasOneItem() then
			return GetItemLink(station.extractionSlot:GetItemBagAndSlot(1))
		end
	end)
	PreHookGamepad(ZO_RetraitStation_Retrait_Gamepad, "LayoutSourceItemTooltip", function(_, itemData)
		if itemData then
			return GetItemLink(itemData.bagId, itemData.slotIndex)
		end
	end)
	PreHookGamepad(ZO_RetraitStation_Retrait_Gamepad, "LayoutResultItemTooltip", function(station, traitData)
		local itemData = station.inventory:CurrentSelection()
		if itemData and traitData then
			return GetResultingItemLinkAfterRetrait(itemData.bagId, itemData.slotIndex, traitData.trait)
		end
	end)
	PreHookGamepad(ZO_RetraitStation_Reconstruct_Gamepad, "RefreshResultTooltip", function(station)
		if station.itemSetPieceData and station:IsOptionsModeShowing() then
			return station.itemSetPieceData:GetItemLink()
		end
	end)

	-- Підказка джерела при покращенні предмета створюється пізно, тому хукаємо її при першому Refresh
	local sourceTooltipHooked = false
	ZO_PreHook(ZO_GamepadSmithingImprovement, "Refresh", function(station)
		if sourceTooltipHooked or not station.sourceTooltip then
			return
		end
		sourceTooltipHooked = true
		PreHookGamepad(station.sourceTooltip.tip, "LayoutImproveSourceSmithingItem", function(_, bagId, slotIndex)
			return GetItemLink(bagId, slotIndex)
		end)
	end)
end

local function InstallThirdPartyHooks()
	-- Tamriel Trade Centre додає свої рядки в підказку: вони мають бачити оригінальні шаблони
	if TamrielTradeCentre_ItemInfo then
		ZO_PreHook(TamrielTradeCentre_ItemInfo, "New", ItemTooltips.RestoreStrings)
	end
	if TamrielTradeCentre_MasterWritInfo then
		ZO_PreHook(TamrielTradeCentre_MasterWritInfo, "New", ItemTooltips.RestoreStrings)
	end
	-- Item Set Browser
	if ItemBrowser and ExtendedJournalItemTooltip then
		HookTooltipMethod(ExtendedJournalItemTooltip, "SetLink", PassLink)
	end
	-- Wish List
	if WishList and WishListTooltip then
		HookTooltipMethod(WishListTooltip, "SetLink", PassLink)
	end
end

local installed = false

function ItemTooltips.Install()
	if installed then
		return
	end
	installed = true

	for _, stringName in ipairs(OVERRIDDEN_STRINGS) do
		originalStrings[stringName] = GetString(_G[stringName])
	end

	InstallKeyboardHooks()
	InstallGamepadHooks()
	InstallThirdPartyHooks()
end
