local PC = PocketChange

---------------------------------------------------------------------------
--[[ GetBagItems 
	Iterates over all populated slots in a bag and returns the values produced by a callback function. 
	
	Parameters: 
		bagId ESO bag identifier to enumerate, such as BAG_BACKPACK or BAG_BANK. 
		func Callback function invoked once for each slot. Receives the slot index as its only argument: func(slotIndex) 
		The callback may return any value. A nil return value causes that slot to be omitted from the result table. 
		
	Returns: 
		table 	A sequential array containing all non-nil values returned by func. 
--]]
local function GetBagItems(bagId,func)

	local cache = SHARED_INVENTORY:GenerateFullSlotData(nil, bagId)
	local tbl = {}
	for slotId,data in pairs(cache) do 
		local v = func(data.slotIndex) 
		if v ~= nil then 
			table.insert(tbl,v)
		end
	end

	return tbl
end

--[[ getItemStackSize 
	Returns the current stack size of an item in a bag slot. 
	
	Parameters: 
		bagId ESO bag identifier containing the item. 
		slotIndex Slot index containing the item. 
		
	Returns: number The number of items in the stack. 
		Returns 0 if GetItemInfo() does not provide a stack size. 
--]]
local function getItemStackSize(bagId, slotIndex)
	--Returns: textureName, stack, sellPrice, meetsUsageRequirement, locked, equipType, itemStyle, quality
	local _, stackSize = GetItemInfo(bagId, slotIndex)
	return stackSize or 0
end

--[[ GetSoulGems 
	Returns all filled soul gems in the specified bag. 
	
	Parameters: 
		bagId ESO bag identifier to search for filled soul gems. 
		
	Returns: table An array of soul gem entries. 
	Each entry contains: 
		bag The bag identifier containing the soul gem. 
		index The slot index containing the soul gem. 
		tier The soul gem tier returned by GetSoulGemItemInfo(). 
		size The number of soul gems in the stack. 
	Entries are sorted by tier in descending order, with higher tier soul gems appearing first. 
--]]
local function GetSoulGems(bagId)
	local tbl = GetBagItems(bagId,function(i)

		if( IsItemSoulGem(SOUL_GEM_TYPE_FILLED,bagId,i) == true ) then
			return {
				bag=bagId,
				index =i, 
				tier=GetSoulGemItemInfo(bagId,i),
				size=getItemStackSize(bagId,i)
			}
		end

	end)

	table.sort(tbl,function(x,y)
		return x.tier > y.tier
	end)

	return tbl
end


--[[ GetEmptySoulGems
    Returns all empty soul gems in the specified bag.

    Parameters:
        bagId
            ESO bag identifier to search for empty soul gems.

    Returns:
        table
            An array of empty soul gem entries. Each entry contains:
                bag
                    The bag identifier containing the soul gem.

                index
                    The slot index containing the soul gem.

                size
                    The number of soul gems in the stack.
--]]
local function GetEmptySoulGems(bagId)
	local tbl = GetBagItems(bagId, function(i)

			if IsItemSoulGem(SOUL_GEM_TYPE_EMPTY,bagId,i) == true then
				return {
					bag=bagId,
					index =i, 
					size=getItemStackSize(bagId,i)
				}
			end

		end)

	return tbl
end

--[[ GetRepairKits
    Returns all repair kits in the specified bag.

    Parameters:
        bagId
            ESO bag identifier to search for repair kits.

    Returns:
        table
            An array of repair kit entries. Each entry contains:
                bag
                    The bag identifier containing the repair kit.

                index
                    The slot index containing the repair kit.

                tier
                    The repair kit tier returned by GetRepairKitTier().

                size
                    The number of repair kits in the stack.

            Entries are sorted by tier in descending order, with higher
            tier repair kits appearing first.
--]]
local function GetRepairKits(bagId)
    local tbl = GetBagItems(bagId, function(i)
        if IsItemRepairKit(bagId, i) == true then
            return {
                bag = bagId,
                index = i,
                tier = GetRepairKitTier(bagId, i),
                size = getItemStackSize(bagId, i)
            }
        end
    end)

    table.sort(tbl, function(x, y)
        return x.tier > y.tier
    end)

    return tbl
end

--[[ GetItemsByType
    Returns all items in the specified bag whose item type matches one
    of the supplied item types.

    Parameters:
        bagId
            ESO bag identifier to search.

        types
            Sequential array of ESO item type constants to match against.

    Returns:
        table
            An array of matching item entries. Each entry contains:
                bag
                    The bag identifier containing the item.

                index
                    The slot index containing the item.

                itemType
                    The item's ESO item type.

                size
                    The number of items in the stack.

            Only the first matching type is returned for each item slot.
--]]
local function GetItemsByType(bagId, types)

    local tbl = GetBagItems(bagId, function(i)

        local itemType = GetItemType(bagId, i)

        for j, t in ipairs(types) do
            if itemType == t then
                return {
                    bag = bagId,
                    index = i,
                    itemType = itemType,
                    size = getItemStackSize(bagId, i),
                }
            end
        end

    end)

    return tbl
end


local b = {}

b.GetBagItems = GetBagItems
b.GetSoulGems = GetSoulGems
b.GetEmptySoulGems = GetEmptySoulGems
b.GetRepairKits = GetRepairKits
b.GetItemsByType = GetItemsByType

PocketChange.Bag = b