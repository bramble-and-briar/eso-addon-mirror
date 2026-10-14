local SF = LibSFUtils
local color = SF.hex

local logDebug = ThiefTools.logDebug

--[[ HotItem
	Represents a snapshot of an item in an ESO inventory bag slot. Captures
	item identity, type information, stack quantities, sale and laundering
	prices, lock state, quality, and other properties used by ThiefTools.

	Instances are created from the current state of an inventory slot using
	ESO API functions. The stored fields are not automatically refreshed if
	the item or slot subsequently changes.

	Price fields:
		baseSellPrice       Base sell price returned by GetItemInfo.
		sellPrice           Unit sell value including applicable bonuses.
		launderPrice        Unit laundering price.
		stackSellPrice      Total sell value for the entire stack.
		stackLaunderPrice   Total laundering price for the entire stack.

	Identity and location:
		bagId               ESO inventory bag identifier.
		slotIndex           Slot index within the specified bag.
		itemInstanceId      Item instance identifier.
		uniqueId            Item unique identifier.

	Item information:
		rawName             Unformatted item name, or "unknown".
		name                Item name formatted for tooltip display.
		stackCount          Number of items in the stack, defaulting to 0.
		itemType            ESO item type.
		specializedItemType ESO specialized item type.
		equipType           ESO equipment type.
		itemStyle           Item style returned by GetItemInfo, if applicable.
		quality             Item quality, defaulting to 0.

	State:
		locked              Whether the item is locked for equipping because
							it is already equipped, as returned by GetItemInfo.
		isPlayerLocked      Whether the player has locked the item.
		stolen              Whether the item is stolen.
		isJunk              Whether the item is marked as junk.
		isPlaceableFurniture Whether the item is placeable furniture.

	Usage:
		local item = HotItem:New(BAG_BACKPACK, slotIndex)
		item:Display()
--]]

--[[ HotList
	Maintains a collection of HotItem objects indexed by inventory slot
	index. The collection is sparse: slot indices are used as keys and may
	contain gaps. Consequently, the itemList table must not be traversed
	using the length operator (#) or ipairs().

	HotList maintains an itemCount field to track the number of populated
	slots. Its size() method returns this count.

	The list is associated with one bag, defaulting to BAG_BACKPACK, and
	supports adding, retrieving, removing, and clearing entries.

	Usage:
		local list = HotList:New(BAG_BACKPACK)
		list:addItem(HotItem:New(BAG_BACKPACK, slotIndex))

		local item = list:getItem(slotIndex)
		local count = list:size()
--]]
ThiefTools_HotItem = {}
local HotItem = ThiefTools_HotItem
HotItem.__index = HotItem

--[[ Creates a HotItem snapshot for the specified inventory slot.
	Reads item metadata and state from ESO APIs and stores the results
	on a new HotItem instance. Price values are captured at construction
	time and are not automatically recalculated.

	@param bagId number ESO inventory bag identifier.
	@param slotIndex number Slot index within the specified bag.
	@return table A new HotItem populated with item information.
--]]
function HotItem:New(bagId, slotIndex)
    local o = setmetatable({}, self)

    -- populate fields
	local icon, stackCount, sellPrice, meetsUsageRequirement, locked, equipType,
			itemStyle, quality = GetItemInfo(bagId, slotIndex)

    o.bagId = bagId
    o.slotIndex = slotIndex
    o.rawName = GetItemName(bagId, slotIndex) or "unknown"
	o.name = zo_strformat(SI_TOOLTIP_ITEM_NAME, o.rawName)

    o.itemInstanceId = GetItemInstanceId(bagId, slotIndex)
	o.stackCount = stackCount or 0
	o.itemType, o.specializedItemType = GetItemType(bagId, slotIndex)
	o.equipType = equipType
	o.uniqueId = GetItemUniqueId(bagId, slotIndex)

	o.baseSellPrice = sellPrice or 0
    o.sellPrice = GetItemSellValueWithBonuses(bagId, slotIndex) or 0
    o.launderPrice = GetItemLaunderPrice(bagId, slotIndex) or 0
    o.stackSellPrice = o.stackCount * o.sellPrice
    o.stackLaunderPrice = o.stackCount * o.launderPrice

    o.locked = locked	-- locked for equipping because it is already equipped
    o.isPlayerLocked = IsItemPlayerLocked(bagId, slotIndex)

    o.quality = quality or 0
    o.stolen = IsItemStolen(bagId, slotIndex)
    o.isJunk = IsItemJunk(bagId, slotIndex)
    o.isPlaceableFurniture = IsItemPlaceableFurniture(bagId, slotIndex)
    return o
end

-- Writes the item's identifying information and selected properties
-- to the ThiefTools debug log.
--
-- Includes name, unique ID, stolen status, item and specialized item
-- types, equipment type, quality, stack count, and unit sell price.
-- Requires ThiefTools.logDebug and LibSFUtils.bool2str.
--
-- @return nil
function HotItem:Display()
	logDebug("name=HotItem")
	logDebug("name=",self.name)
	logDebug("   (id: ",self.uniqueId,")")
	logDebug("    stolen=",SF.bool2str(self.stolen))
	logDebug("    itemtype=",self.itemType,"  specializedItemType=",self.specializedItemType)
	logDebug("    equipType=",self.equipType)
	logDebug("    quality=",self.quality)
	logDebug("    stackCount=",self.stackCount, "    sellprice=",self.sellPrice)
end

------------------------------------------------------------------------------
--[[ HotList is a sparse array with entries keyed off of the slotIndex of the
	BAG_BACKPACK. 
	Do not use #itemList or ipairs() to traverse its entries.
--]]
ThiefTools_HotList = {}
local HotList = ThiefTools_HotList
HotList.__index = HotList

-- Creates an empty HotList associated with a bag.
--
-- @param bagId number|nil ESO inventory bag identifier.
--                     Defaults to BAG_BACKPACK.
-- @return table A new HotList with an empty itemList and itemCount 0.
function HotList:New(bagId)
	local o = {}
	setmetatable(o, self)
	o.itemList = {}
	o.init = false
	o.bagId = bagId or BAG_BACKPACK
	o.itemCount = 0
	return o
end

-- Returns the HotItem stored at the specified slot index.
--
-- @param slotIndex number Inventory slot index.
-- @return table|nil The HotItem at that slot, or nil if absent.
function HotList:getItem(slotIndex)
	return self.itemList[slotIndex]
end

-- Removes the entry at the specified slot index, if present.
--
-- Decrements itemCount only when an entry exists.
--
-- @param slotIndex number Inventory slot index.
-- @return boolean True if an item was removed; otherwise false.
function HotList:removeItem(slotIndex)
    if not self.itemList[slotIndex] then
        return false
    end

    self.itemList[slotIndex] = nil
    self.itemCount = self.itemCount - 1
    return true
end

-- Inserts or replaces a HotItem at its slot index.
--
-- Increments itemCount only when the slot did not already contain
-- an entry. Replacing an existing entry leaves the count unchanged.
--
-- @param hotItem table HotItem instance with a slotIndex field.
-- @return table The HotItem stored at hotItem.slotIndex.
function HotList:addItem(hotItem)
	local slotIndex = hotItem.slotIndex
	local itemList = self.itemList
	
	if not itemList[slotIndex] then
		self.itemCount = self.itemCount + 1
	end
	itemList[slotIndex] = hotItem
	return itemList[slotIndex]
end

-- Removes all entries and resets the item count.
--
-- The itemList table is replaced with a new empty table.
--
-- @return nil
function HotList:empty()
	self.itemList = {}
	self.itemCount = 0
end

-- Returns the number of populated entries in the list.
--
-- This is the tracked entry count, not the highest slot index.
--
-- @return number Number of entries currently stored.
function HotList:size()
	return self.itemCount
end
