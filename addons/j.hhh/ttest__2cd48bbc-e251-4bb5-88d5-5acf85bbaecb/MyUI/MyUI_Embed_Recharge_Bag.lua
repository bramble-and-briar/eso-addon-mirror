local Recharge = Recharge

local function GetBagItems(bagId,func)
	
	local cache = SHARED_INVENTORY:GenerateFullSlotData(nil, bagId)
	local tbl = {}
	for slotId,data in pairs(cache) do 
		local funcRes = func(data.slotIndex)
		if funcRes ~= nil then
			table.insert(tbl,funcRes)
		end 
	end 
	
	return tbl
end

local function getItemStackSize(bagId, slotIndex)
	--Returns: textureName, stack, sellPrice, meetsUsageRequirement, locked, equipType, itemStyle, quality
	local _, stackSize = GetItemInfo(bagId, slotIndex)
	return stackSize or 0
end

local function getItemInfo(bagId, index, infoColumn, infoFunc)
	if bagId==nil or index==nil or infoColumn == nil or infoFunc == nil then return nil end

	return {
		--Static columns
		bag = 			bagId,
		index = 		index,
		size =			getItemStackSize(bagId,index),
		--Dynamic content
		[infoColumn] = 	infoFunc(bagId,index),
	}
end

local function GetSoulGems(bagId)
	--Soul gem tiers
	--0 = Crown soul gem
	--1 = Soul gem
	local useCrownSoulgemsFirst = Recharge.settings.useCrownSoulgemsFirst

	local tbl = GetBagItems(bagId,function(i)
		if IsItemSoulGem(SOUL_GEM_TYPE_FILLED,bagId,i) == true then
			return getItemInfo(bagId, i, "tier", GetSoulGemItemInfo)
		end
	end)

	--Crown store soulgems should be used first?
	-->Sort the table of soulgems by it's tier but lowest tier (crown store soul gem = tier 0) last, as the function
	-->ChargeItem will use the #gems, so the last entry in the table!!
	if useCrownSoulgemsFirst == true then
		table.sort(tbl,function(x,y)
			return x.tier > y.tier
		end)
	else
		table.sort(tbl,function(x,y)
			return x.tier < y.tier
		end)
	end

	return tbl
end

local function GetRepairKits(bagId)
	--Repair kit tiers
	--1 =  repair kit lowest
	--2 =  repair kit lower
	--3 =  repair kit low
	--4 =  repair kit medium
	--5 =  repair kit higher
	--6 =  repair kit highest
	--7 =  Crown repair kit
	--Impressaria group repair kits: Are not counted as repair kits
	--this IsItemRepairKit returns false and GetRepairKitTier returns 0
	local settings = Recharge.settings
	local dontUseCrownRepairKits = settings.dontUseCrownRepairKits
	local useCrownRepairKitsFirst = settings.useCrownRepairKitsFirst

	local tbl, tblCrownRepair

	local function getRepairKitsFromBagId(bagId, onlyCrownRepairKits)
		onlyCrownRepairKits = onlyCrownRepairKits or false
		tblCrownRepair = {}


		local tabWithRepairKits = GetBagItems(bagId, function(i)
			local isRepairKit = IsItemRepairKit(bagId,i)
			if isRepairKit == true then
				local isCrownStoreRepairKit = (IsItemNonCrownRepairKit(bagId,i) == false) or false
				if (isCrownStoreRepairKit == false or (isCrownStoreRepairKit == true and dontUseCrownRepairKits == false)) then

					--Use CrownStore repair kits first but do keep the tier sort order for normal repair kits ascending afterwards
					--so the smalest ones will be used after crown?
					if isCrownStoreRepairKit == true and onlyCrownRepairKits == true then
						-->Crown kits Will be added to the table tblCrownRepair now
						tblCrownRepair[#tblCrownRepair + 1] = getItemInfo(bagId, i, "tier", GetRepairKitTier)
					else
						return getItemInfo(bagId, i, "tier", GetRepairKitTier)
					end
				end
			end
		end)
		return tabWithRepairKits
	end


	local function normalSortRepairKits()
		if tbl == nil then return end
		--Sort the repair kits by their tier -> highest first (means crown on top)
		--> But function RepairItem in file Repair.lua will use #kits (means the last entry! with lowest tier then)!
		table.sort(tbl,function(x,y)
			return x.tier > y.tier
		end)
	end


	--Get the repair kits. First all (but strip crown store repair kits if they are not needed to be used OR if they should be used first!
	-->If they should be used first they will be collected to the other table "tblCrownRepair" and then tables tbl and tblCrownRepair will
	-->be combined with tblCrownRepair entries at last
	tbl = getRepairKitsFromBagId(bagId, useCrownRepairKitsFirst)
	if dontUseCrownRepairKits == false and useCrownRepairKitsFirst == true then
		--Sort the repair kits by their tier -> highest first (means highest non-crown on top)
		--> But function RepairItem in file Repair.lua will use #kits (means the last entry! with lowest tier then)!
		normalSortRepairKits()
		if #tblCrownRepair > 0 then
			--After that add the crown tier items now at the bottom of the general table
			-->Makes the table tbl sorted by highest tier -> lowest tier, and then added "Crown tier" at the end
			-->So that function RepairItem will use #tbl (#kits) -> last entry first = crown store kit first
			for k,crownRepairKitData in ipairs(tblCrownRepair) do
				tbl[#tbl + 1] = crownRepairKitData
			end
		end
	else
		normalSortRepairKits()
	end

	return tbl
end 

local function GetItemsByType(bagId,types)
	
	local tbl = GetBagItems(bagId,function(i)
		
		local itemType = GetItemType(bagId,i)
		
		for i,t in ipairs(types) do
			if itemType == t then
				return {
					bag = bagId,
					index = i,
					itemType=itemType
				}
			end
		end
	
	end)
	
	return tbl
end

local rechargeBag          = {}

rechargeBag.GetBagItems    = GetBagItems
rechargeBag.GetSoulGems    = GetSoulGems
rechargeBag.GetRepairKits  = GetRepairKits
rechargeBag.GetItemsByType = GetItemsByType

Recharge.Bag               = rechargeBag