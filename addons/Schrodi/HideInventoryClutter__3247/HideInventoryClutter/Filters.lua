local HIC = HideInventoryClutter

function HIC.isCraftingMaterial(slot) 
    if not HIC.savedVariables.materialsEnabled then return false end
	local b, i = slot.bagId, slot.slotIndex
    return GetItemFilterTypeInfo(b, i) == ITEMFILTERTYPE_CRAFTING or GetItemType(b, i) == ITEMTYPE_LURE 
end

function HIC.isWorthDeconstructing(slot)
    if not HIC.savedVariables.deconstructionEnabled then return true end
	local b, i = slot.bagId, slot.slotIndex
    --return GetItemQuality(b, i) >= ITEM_QUALITY_ARTIFACT 
	local itemLink = GetItemLink(b, i)
	if IsItemLinkCrafted(itemLink) then return false end
	local deconValue = LibDeconValue:GetDeconValue(itemLink, HIC.savedVariables.deconstructionValueMinMatPrice)
	local vendorValue = LibDeconValue:GetVendorValue(itemLink)
	return deconValue > vendorValue * HIC.savedVariables.deconstructionValueMultiplier + HIC.savedVariables.deconstructionValueMinDifference
end

local ITEMTYPES_NOT_FOR_SALE = {
	[ITEMTYPE_FURNISHING			] = true,
	[ITEMTYPE_RECIPE    			] = true,
	[ITEMTYPE_RACIAL_STYLE_MOTIF	] = true,
	[ITEMTYPE_FISH					] = true,
--	[ITEMTYPE_CRAFTED_ABILITY_SCRIPT] = true,
}

local SPECIALIZED_ITEMTYPES_NOT_FOR_SALE = {
	[SPECIALIZED_ITEMTYPE_TROPHY_RUNEBOX_FRAGMENT] = true,
}

function HIC.isWorthSelling(slot)
	local b, i = slot.bagId, slot.slotIndex
	if GetItemSellInformation(b, i) == ITEM_SELL_INFORMATION_CANNOT_SELL then return false end
	local itemType, specalizedItemType = GetItemType(b, i) 
    if itemType == ITEMTYPE_TREASURE then return true end
	if ITEMTYPES_NOT_FOR_SALE[itemType] then return false end
	if SPECIALIZED_ITEMTYPES_NOT_FOR_SALE[specalizedItemType] then return false end
	if HIC.isCraftingMaterial(slot) then return false end
	if IsItemLinkCrafted(GetItemLink(b, i)) and not HIC.isConsumable(slot) then return false end
	-- with the deconstruction filter off isWorthDeconstructing() returns true for everything
	if not HIC.savedVariables.deconstructionEnabled then return true end
	return not HIC.isWorthDeconstructing(slot)
end

local CONSUMABLE_ITEMTYPES = {
	[ITEMTYPE_FOOD  ] = true,
	[ITEMTYPE_DRINK ] = true,
	[ITEMTYPE_POTION] = true,
	[ITEMTYPE_POISON] = true,
}

local EXTRA_CONSUMABLES = {
	[30357 ] = true, -- Lockpick
	[44879 ] = true, -- Grand Repair Kit
	[33271 ] = true, -- Soul Gem
}

-- Experience and Alliance War skill line boosters (scrolls, war tortes, ambrosia, ...).
-- Known items are listed here; anything else is recognized by its "use" text mentioning
-- experience, in the client's language.
local BOOSTERS = {
	[64537 ] = true, -- Crown Experience Scroll (50%)
	[94440 ] = true, -- Major Gold Coast Experience Scroll (100%)
	[94441 ] = true, -- Grand Gold Coast Experience Scroll (150%)
	[171323] = true, -- Colovian War Torte (50%)
	[171329] = true, -- Molten War Torte (100%)
	[171432] = true, -- White-Gold War Torte (150%)
}

local EXPERIENCE_WORDS = {
	en = "experience",
	de = "erfahrung",
	fr = "expérience",
	es = "experiencia",
	ru = "опыт",
	jp = "経験",
	zh = "经验",
}
local experienceWord = nil

local NOT_BOOSTER_ITEMTYPES = {
	[ITEMTYPE_ARMOR ] = true,
	[ITEMTYPE_WEAPON] = true,
}

-- itemId -> true/false; an item's use text doesn't change, so each id is checked once.
local boosterCache = {}

local function IsBooster(b, i)
	local itemId = GetItemId(b, i)
	if BOOSTERS[itemId] then return true end
	local cached = boosterCache[itemId]
	if cached ~= nil then return cached end

	local isBooster = false
	if not NOT_BOOSTER_ITEMTYPES[GetItemType(b, i)] then
		experienceWord = experienceWord or EXPERIENCE_WORDS[GetCVar("language.2")] or EXPERIENCE_WORDS.en
		local hasAbility, _, description = GetItemLinkOnUseAbilityInfo(GetItemLink(b, i))
		isBooster = hasAbility and description ~= nil and zo_strlower(description):find(experienceWord, 1, true) ~= nil
	end
	boosterCache[itemId] = isBooster
	return isBooster
end

-- Siege weapons (including forward camps, oil, battle standards) and Alliance War repair kits
-- for keep walls, doors, bridges and siege.
local ALLIANCE_WAR_ITEMTYPES = {}
for _, itemType in ipairs({ ITEMTYPE_SIEGE, ITEMTYPE_AVA_REPAIR }) do
	ALLIANCE_WAR_ITEMTYPES[itemType] = true
end

-- Items that take you somewhere in Cyrodiil and Imperial City.
local TRAVEL_ITEMS = {
	[141731] = true, -- Keep Recall Stone
	[68347 ] = true, -- Sigil of Imperial Retreat
}
local function IsTravelItem(b, i, itemType)
	return TRAVEL_ITEMS[GetItemId(b, i)] or (ITEMTYPE_RECALL_STONE ~= nil and itemType == ITEMTYPE_RECALL_STONE)
end

function HIC.isConsumable(slot)
    if not HIC.savedVariables.consumablesEnabled then return false end
	local b, i = slot.bagId, slot.slotIndex
    
	if IsItemStolen(b, i) then return false end

	-- With the option on boosters are consumables whatever their item type; with it off they
	-- are not, even the ones that are food.
	if IsBooster(b, i) then return HIC.savedVariables.boostersAreConsumables end

	local itemType = GetItemType(b, i)
	if ALLIANCE_WAR_ITEMTYPES[itemType] then return HIC.savedVariables.siegeAreConsumables end
	if IsTravelItem(b, i, itemType) then return HIC.savedVariables.travelItemsAreConsumables end
	if CONSUMABLE_ITEMTYPES[itemType] then return true end
    return EXTRA_CONSUMABLES[GetItemId(b, i)] ~= nil
end

function HIC.isLocked(slot)
    if not HIC.savedVariables.lockedEnabled then return false end
	
	local b, i = slot.bagId, slot.slotIndex
	return CanItemBePlayerLocked(b, i) and IsItemPlayerLocked(b, i)
end

function HIC.isEitherTradeableGearOrDifferentItemType(slot)
	local b, i = slot.bagId, slot.slotIndex
	local itemType = GetItemType(b, i)
	if itemType == ITEMTYPE_ARMOR or itemType == ITEMTYPE_WEAPON then
		return IsItemBoPAndTradeable(b, i) or HIC.isConsumable(slot)
	end
	return true
end