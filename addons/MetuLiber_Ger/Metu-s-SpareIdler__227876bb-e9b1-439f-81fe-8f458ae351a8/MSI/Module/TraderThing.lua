-- TraderThing.lua
if MSI == nil then MSI = MSI or {} end
local MSI = _G['MSI']

local isUnboxingCraftReward = false
local pendingUnboxingQueue 	= {}
local unboxingInterrupted 	= false
local isUnboxing 			= false
local lastLootUpdatedTimetag = 0
local isAllCurtLooted = true

--***********************--
-- Sell & Launder Stolen
local function SellAllStolenJunk()
    local filteredDataTable = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK)
    for _, data in pairs(filteredDataTable) do
        local totalSells, sellsUsed, _ = GetFenceSellTransactionInfo()
        if data.stolen == true and data.isJunk == true then
            if totalSells == sellsUsed then
                MSI.Print("c", GetString(SI_STOREFAILURE23)) -- Limit erreicht
				MSI.ShowCenterMsg(2468, [[icon_warn.dds]], GetString(SI_STOREFAILURE23))
				break
            else
				SellInventoryItem(BAG_BACKPACK, data.slotIndex, data.stackCount)
                MSI.Print("d", zo_strformat(GetString(MSI_MOD_SELL_STLN_ITM_CHTLINE), GetItemLink(BAG_BACKPACK, data.slotIndex)))
            end
        end
    end
	SCENE_MANAGER:ShowBaseScene()
end

local function LaunderAllStolen()
    local filteredDataTable = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK)
    for _, data in pairs(filteredDataTable) do
        local totalLaunders, laundersUsed, _ = GetFenceLaunderTransactionInfo()
        if data.stolen == true and data.isJunk == false and GetItemLaunderPrice(BAG_BACKPACK, data.slotIndex) > 0 then
            if totalLaunders == laundersUsed then
				MSI.Print("c", GetString(SI_ITEMLAUNDERRESULT7)) -- Limit erreicht
				MSI.ShowCenterMsg(2468, [[icon_warn.dds]], GetString(SI_ITEMLAUNDERRESULT7))
                break
            else
				LaunderItem(BAG_BACKPACK, data.slotIndex, math.min(math.min(data.stackCount, 100), (totalLaunders - laundersUsed)))
				MSI.Print("d", zo_strformat(GetString(MSI_MOD_LNDER_STLN_ITM_CHTLINE), GetItemLink(BAG_BACKPACK, data.slotIndex)))
            end
        end
    end
	SCENE_MANAGER:ShowBaseScene()
end

local function OpenStore()
if not MSI.SVars.IsSellALLJunk then return end
MSI.Print("d", GetString(MSI_MOD_OPEN_STORE_CHTLINE))
	local total = 0 
	local filteredDataTable = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK)
	for _, data in pairs(filteredDataTable) do
		if data.stolen == false and data.isJunk == true then
			total = total + data.sellPrice * data.stackCount
		end
	end
	if total > 0 then		
		SellAllJunk()
		MSI.Print("c", zo_strformat(GetString(MSI_MOD_SLD_JUNK_CHTLINE), total, GetCurrencyName(CURT_MONEY, false, false)))
		MSI.ShowCenterMsg(2468, [[icon_info.dds]], zo_strformat(GetString(MSI_MOD_SLD_JUNK_CHTLINE), total, GetCurrencyName(CURT_MONEY, false, false)))

	end
end

local function OpenFence()
if not MSI.SVars.IsSellStolenJunk then return end
MSI.Print("d", GetString(MSI_MOD_OPEN_FENCE_CHTLINE))
	if AreAnyItemsStolen(BAG_BACKPACK) then
		local total = 0
		local filteredDataTable = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK)
		for _, data in pairs(filteredDataTable) do
			if data.stolen == true and data.isJunk == true then
				total = total + data.sellPrice * data.stackCount
			end
		end
		if total > 0 then
			SellAllStolenJunk()
			MSI.Print("c", zo_strformat(GetString(MSI_MOD_SLD_STLN_JUNK_CHTLINE), total, GetCurrencyName(CURT_MONEY, false, false)))
			MSI.ShowCenterMsg(2468, [[icon_info.dds]], zo_strformat(GetString(MSI_MOD_SLD_STLN_JUNK_CHTLINE), total, GetCurrencyName(CURT_MONEY, false, false)))
		end
	end
end

local function OpenLaunder()
if not MSI.SVars.IsLaunderStolen then return end
MSI.Print("d", GetString(MSI_MOD_OPEN_LAUNDER_CHTLINE))
	if AreAnyItemsStolen(BAG_BACKPACK) then
		local total = 0 
		local filteredDataTable = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK)
		for _, data in pairs(filteredDataTable) do
			if data.stolen == true and data.isJunk == false then
				total = total + data.sellPrice * data.stackCount
			end
		end
		if total > 0 then
			LaunderAllStolen()
			MSI.Print("c", zo_strformat(GetString(MSI_MOD_LAUNDRD_STLN_CHTLINE), total, GetCurrencyName(CURT_MONEY, false, false)))
			MSI.ShowCenterMsg(2468, [[icon_info.dds]], zo_strformat(GetString(MSI_MOD_LAUNDRD_STLN_CHTLINE), total, GetCurrencyName(CURT_MONEY, false, false)))
		end
	end
end

--***************************--
-- Bind Learn Routine Checks
local function IsPlayerIdle(slotIndex)
	return CanInteractWithItem(BAG_BACKPACK, slotIndex) and not IsUnitInCombat("player") and (SCENE_MANAGER:GetCurrentScene().name == "hudui" or SCENE_MANAGER:GetCurrentScene().name == "hud")
end

local function ItemStatus(itemLink)
    -- Returns:
    -- 0: Not a collectible
    -- 1: Collectible and not collected
    -- 2: Collectible and collected
    -- 3: Item Set Collectible and not collected
    -- 4: Item Set Collectible and collected
 
    if (IsItemLinkSetCollectionPiece(itemLink)) then
        if (IsItemSetCollectionPieceUnlocked(GetItemLinkItemId(itemLink))) then
            return 4
        else
            return 3
        end
    else
        local id = GetItemLinkContainerCollectibleId(itemLink)
        if (id > 0) then
            if (IsCollectibleOwnedByDefId(id)) then
                return 2
            elseif (GetCollectibleCategoryType(id) == COLLECTIBLE_CATEGORY_TYPE_COMBINATION_FRAGMENT and not CanCombinationFragmentBeUnlocked(id)) then
                return 2
            else
                return 1
            end
        end
        return 0
    end
end

--************************--
-- Auto-Bind & Auto-Learn
local function BindThatItem(bagId, slotIndex)
	local success = BindItem(bagId, slotIndex)
	return success
end
local function UseThatItem(bagId, slotIndex)
	if IsProtectedFunction("UseItem") then
		local success = CallSecureProtected("UseItem", bagId, slotIndex)
		return success
	else
		local success = UseItem(bagId, slotIndex)
		return success
	end 
end
--***********************--
-- Unbekannte Item Daten
local craftingContainerSuffix = {
    "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
}
local function IsCraftingContainer(str)
    for _, suffix in ipairs(craftingContainerSuffix) do
        if string.sub(str, -#suffix) == suffix then
            return true
        end
    end
    return false
end
local function OnLootUpdatedThrottled()
    lootActivityTimestamp = GetGameTimeMilliseconds()
    local currentTime = GetGameTimeMilliseconds()
	local currencyInfo = LOOT_SHARED:GetLootCurrencyInformation()
	
	for curt, info in pairs(currencyInfo) do
		if curt == CURT_MONEY then
		isAllCurtLooted = false
			if info.currencyAmount > 0 then
				LootMoney()
			end
		end
		isAllCurtLooted = true
	end
	
    if (currentTime - lastLootUpdatedTimetag) > (GetLatency() + 200) then
		for i = 1, GetNumLootItems(), 1 do
			local lootId, name, _, _, _, _, _, _, _ = GetLootItemInfo(i)
            LootItemById(lootId)
		end
		lastLootUpdatedTimetag = currentTime
	end
    EndLooting()
	--MSI.ApplyRightScene(SCENE_MANAGER:GetCurrentScene():GetName())
	SCENE_MANAGER:ShowBaseScene()
end
local function LootClosed()
    isAllCurtLooted = true
	isUnboxingCraftReward = false
    lootActivityTimestamp = GetGameTimeMilliseconds()
end

local function GetItemDataIfUnknown(bagId, slotIndex)
	local getBagId = bagId
	local getSlotIndex = slotIndex
	local getLink = GetItemLink(getBagId, getSlotIndex)--, LINK_STYLE_DEFAULT)
	local getQuality = GetItemLinkFunctionalQuality(getLink)
	local getLinkId = GetItemLinkItemId(getLink)
	local getLinkName = GetItemLinkName(getLink)
	
	local linkBindType = GetItemLinkBindType(getLink)
	local itemTraitInfo = GetItemLinkTraitInfo(getLink)
	local itemLinkType, specializedItemType = GetItemLinkItemType(getLink)

	local isUncollected = not IsItemSetCollectionPieceUnlocked(getLinkId)
	local isNotSellable = (GetItemLinkSellInformation(getLink) == ITEM_SELL_INFORMATION_CANNOT_SELL)
	local isItemKnownJunk = IsItemJunk(getBagId, getSlotIndex)
	local isMarkableAsJunk = CanItemBeMarkedAsJunk(getBagId, getSlotIndex)
	local isSellableOnTradingHouse = IsItemSellableOnTradingHouse(getBagId, getSlotIndex)
	local isCraftingContainer = IsCraftingContainer(getLinkName)
	local isSetItem = IsItemLinkSetCollectionPiece(getLink)
	local isCrafted = IsItemLinkCrafted(getLink)
	local isBound = IsItemLinkBound(getLink)
	local isStolen = IsItemStolen(getBagId, getSlotIndex)
	local isUnknown = CanItemLinkBeUsedToLearn(getLink)
	local isCompanionGear = (GetItemLinkActorCategory(getLink) == GAMEPLAY_ACTOR_CATEGORY_COMPANION)
	local isRecipeKnown = IsItemLinkRecipeKnown(getLink)

	local specializedRecipes = {
		  [SPECIALIZED_ITEMTYPE_RECIPE_ALCHEMY_FORMULA_FURNISHING]		 = true,
		  [SPECIALIZED_ITEMTYPE_RECIPE_BLACKSMITHING_DIAGRAM_FURNISHING] = true,
		  [SPECIALIZED_ITEMTYPE_RECIPE_CLOTHIER_PATTERN_FURNISHING]		 = true,
		  [SPECIALIZED_ITEMTYPE_RECIPE_ENCHANTING_SCHEMATIC_FURNISHING]	 = true,
		  [SPECIALIZED_ITEMTYPE_RECIPE_JEWELRYCRAFTING_SKETCH_FURNISHING]= true,
		  [SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_DESIGN_FURNISHING]	 = true,
		  [SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_FOOD]		 = true,
		  [SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_DRINK]		 = true,
		  [SPECIALIZED_ITEMTYPE_RECIPE_WOODWORKING_BLUEPRINT_FURNISHING] = true,
		  [SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT]					 = true,
		  [SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP]					 = true,
		  [SPECIALIZED_ITEMTYPE_TROPHY_COLLECTIBLE_FRAGMENT]			 = true,
		  [SPECIALIZED_ITEMTYPE_TROPHY_RECIPE_FRAGMENT]					 = true,
		  [SPECIALIZED_ITEMTYPE_TROPHY_RUNEBOX_FRAGMENT]				 = true,
		  [SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_BOOK]				 = true,
		  [SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_CHAPTER]				 = true,
		  [SPECIALIZED_ITEMTYPE_COLLECTIBLE_STYLE_PAGE]					 = true,
	}
		
--*****--
-- Use 
	local isRecipePage  = (itemLinkType == ITEMTYPE_RECIPE
						or itemLinkType == ITEMTYPE_COLLECTIBLE
						or itemLinkType == ITEMTYPE_RACIAL_STYLE_MOTIF
						or itemLinkType == ITEMTYPE_RECIPE_FRAGMENT
						or itemLinkType == ITEMTYPE_STYLE_MATERIAL
						or itemLinkType == ITEMTYPE_DISGUISE_STYLE
						or (itemLinkType == ITEMTYPE_TROPHY and specializedItemType == SPECIALIZED_ITEMTYPE_TROPHY_RECIPE_FRAGMENT)
						or (itemLinkType == ITEMTYPE_TROPHY and specializedItemType == SPECIALIZED_ITEMTYPE_TROPHY_COLLECTIBLE_FRAGMENT)
						or itemLinkType == ITEMTYPE_CRAFTED_ABILITY_SCRIPT
						or specializedRecipes[specializedItemType])

	
	local 	isContainer = (itemLinkType == ITEMTYPE_CONTAINER)
	local 	 isUnopened	= (itemLinkType == ITEMTYPE_CONTAINER_STACKABLE)
	local 		 isFish = (itemLinkType == ITEMTYPE_FISH)
	local isTreasureMap = (itemLinkType == ITEMTYPE_TREASURE_MAP
						or (itemLinkType == ITEMTYPE_BOOK and string.find(getLink, "Treasure Map")))

--*****--
-- Junk
	local isCollectible = (itemLinkType == ITEMTYPE_COLLECTIBLE)
	local  isOrnateGear = (itemTraitInfo == ITEM_TRAIT_TYPE_ARMOR_ORNATE
						or itemTraitInfo == ITEM_TRAIT_TYPE_WEAPON_ORNATE)
						--or itemTraitInfo == ITEM_TRAIT_TYPE_JEWELRY_ORNATE)
	local  isOrnatJewel = (itemTraitInfo == ITEM_TRAIT_TYPE_JEWELRY_ORNATE)
	local 	   isPoison = (itemLinkType == ITEMTYPE_POISON)
	local 	 isTreasure	= (itemLinkType == ITEMTYPE_TREASURE) -- Diebesgut (Hehlerware)
	local 	    isTrash = (itemLinkType == ITEMTYPE_TRASH)
	local 		 isPoor = (getQuality == ITEM_QUALITY_POOR)
	local 		 isMisc = (itemLinkType == ITEMTYPE_TROPHY
						and specializedItemType ~= SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP
						and specializedItemType ~= SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT
						and specializedItemType ~= SPECIALIZED_ITEMTYPE_TROPHY_RECIPE_FRAGMENT
						and specializedItemType ~= SPECIALIZED_ITEMTYPE_TROPHY_COLLECTIBLE_FRAGMENT)
--
	local isFoodAndDrink = (itemLinkType == ITEMTYPE_FOOD
						or itemLinkType == ITEMTYPE_DRINK)
	local  isLaunderable = (itemLinkType == ITEMTYPE_LOCKPICKS
						or itemLinkType == ITEMTYPE_SOUL_GEM
						or itemLinkType == ITEMTYPE_CRAFTING_MATERIAL
						or itemLinkType == ITEMTYPE_FURNISHING_MATERIAL
						or itemLinkType == ITEMTYPE_SURVEY_REPORT
						or itemLinkType == ITEMTYPE_ARMORY_SCENE
						or itemLinkType == ITEMTYPE_MASTER_WRIT)

	local 		 isBook = (itemLinkType == ITEMTYPE_BOOK)

	local 	   isScript = (itemLinkType == ITEMTYPE_CRAFTED_ABILITY_SCRIPT)
	local 	isTradeable = (linkBindType == BIND_TYPE_NONE
						or linkBindType == BIND_TYPE_ON_EQUIP
						or linkBindType == BIND_TYPE_UNSET)


	return {
		getBagId = getBagId,
		getSlotIndex = getSlotIndex,
		getLink = getLink,
		getQuality = getQuality,
		getLinkId = getLinkId,
		getLinkName = getLinkName,
		isUncollected = isUncollected,
		isNotSellable = isNotSellable,
		isItemKnownJunk = isItemKnownJunk,
		isMarkableAsJunk = isMarkableAsJunk,
		isSellableOnTradingHouse = isSellableOnTradingHouse,
		isCraftingContainer = isCraftingContainer,
		isSetItem = isSetItem,
		isCrafted = isCrafted,
		isBound = isBound,
		isStolen = isStolen,
		isUnknown = isUnknown,
		isCompanionGear = isCompanionGear,
		isRecipeKnown = isRecipeKnown,
		isRecipePage = isRecipePage,
		isContainer = isContainer,
		isUnopened = isUnopened,
		isFish = isFish,
		isTreasureMap = isTreasureMap,
		isCollectible = isCollectible,
		isOrnateGear = isOrnateGear,
		isOrnatJewel = isOrnatJewel,
		isFoodAndDrink = isFoodAndDrink,
		isLaunderable =  isLaunderable,
		isTreasure = isTreasure,
		isPoison = isPoison,
		isTrash = isTrash,
		isPoor = isPoor,
		isMisc = isMisc,
		isBook = isBook,
		isScript = isScript,
		isTradeable = isTradeable,
	}
end

local function unboxQueuedContainer()
	local cachedUnboxingQueue = pendingUnboxingQueue
	pendingUnboxingQueue = {}
	isUnboxing = true
	zo_callLater(function() 
		isUnboxing = false
		-- if new containers were obtained during unboxing
		if #pendingUnboxingQueue > 0 then
			unboxQueuedContainer()
		end
	end, #cachedUnboxingQueue * (1000 + GetLatency()))
	for i, slotIndex in ipairs(cachedUnboxingQueue) do
		if GetItemName(BAG_BACKPACK, slotIndex) == "" then
            MSI.Print("c", GetString(MSI_MOD_MISSING_ITEM_CHTLINE))
			--MSI.ShowCenterMsg(2468, [[icon_warn.dds]], zo_strformat(GetString(MSI_MOD_MISSING_ITEM_CHTLINE)))
		else
			zo_callLater(function() 

				-- MSI.Print("d", string.format("TypId: %s Typ: %s", GetItemLinkItemType(GetItemLink(BAG_BACKPACK, slotIndex)), tostring(GetString("SI_ITEMTYPE", GetItemLinkItemType(GetItemLink(BAG_BACKPACK, slotIndex))))))
				-- MSI.Print("d", string.format("Quali: %s Set: %s", GetItemLinkFunctionalQuality(GetItemLink(BAG_BACKPACK, slotIndex)), (IsItemSetCollectionPieceUnlocked(GetItemLinkItemId(GetItemLink(BAG_BACKPACK, slotIndex))) and GetString(MSI_ADDON_YES) or GetString(MSI_ADDON_NO))))
				-- MSI.Print("d", string.format("Conti: %s Geb: %s", (IsItemLinkContainer(GetItemLink(BAG_BACKPACK, slotIndex)) and GetString(MSI_ADDON_YES) or GetString(MSI_ADDON_NO)), (IsItemLinkBound(GetItemLink(BAG_BACKPACK, slotIndex)) and GetString(MSI_ADDON_YES) or GetString(MSI_ADDON_NO))))
		
				local item = GetItemDataIfUnknown(BAG_BACKPACK, slotIndex)
				if item ~= nil then
					if UseThatItem(BAG_BACKPACK, item.getSlotIndex) then
						if item.isFish then
							MSI.Print("c", zo_strformat(GetString(MSI_MOD_FISH_FILLET_CHTLINE), item.getLink))
						elseif (item.isTreasureMap and item.isUnopened) then
							MSI.Print("i", zo_strformat(GetString(MSI_MOD_OPENED_SCROLL_CHTLINE), item.getLink))
							MSI.ShowCenterMsg(2468, [[icon_info.dds]], zo_strformat(GetString(MSI_MOD_OPENED_SCROLL_CHTLINE), item.getLink))
						elseif item.isTreasureMap then
							MSI.Print("i", zo_strformat(GetString(MSI_MOD_VIEWED_NOTE_CHTLINE), item.getLink))
							MSI.ShowCenterMsg(2468, [[icon_info.dds]], zo_strformat(GetString(MSI_MOD_VIEWED_NOTE_CHTLINE), item.getLink))
						elseif item.isRecipePage then
							MSI.Print("c", zo_strformat(GetString(MSI_MOD_LEARNED_ITEM_CHTLINE), item.getLink))
						elseif (item.isContainer or item.isUnopened) then
							-- if (item.isContainer and item.isCraftingContainer) then
								-- isUnboxingCraftReward = false
							-- end
							MSI.Print("c", zo_strformat(GetString(MSI_MOD_OPENED_CONTI_CHTLINE), item.getLink))
							--OnLootUpdatedThrottled()
							EVENT_MANAGER:UnregisterForEvent(MSI.Name.."LootUpdate", EVENT_LOOT_UPDATED)
							zo_callLater(function()
							EVENT_MANAGER:RegisterForEvent(MSI.Name.."LootUpdate", EVENT_LOOT_UPDATED, OnLootUpdatedThrottled)
							end, GetLatency() + 200)
						else
							MSI.Print("c", zo_strformat(GetString(MSI_MOD_USED_USEITEM_CHTLINE), item.getLink))
						end
					end
					--UseThatItem(BAG_BACKPACK, item.getSlotIndex)
				end
			end, (i - 1) * (1000 + GetLatency()))
		end
	end
end

--**********************--
-- Interruption Monitor
local function listenInterruption(slotIndex)
	EVENT_MANAGER:UnregisterForUpdate(MSI.Name.."UnboxingListen")
	EVENT_MANAGER:RegisterForUpdate(MSI.Name.."UnboxingListen", (100 + GetLatency()), 
	function()
		if IsPlayerIdle(slotIndex) then
			-- Item is interactive, continue monitoring
		else
			unboxingInterrupted = true
			EVENT_MANAGER:UnregisterForUpdate(MSI.Name.."UnboxingListen")
		end
	end)
end

local function checkInterruption(slotIndex)
	EVENT_MANAGER:UnregisterForUpdate(MSI.Name.."UnboxingCheck")
	local timeout
	if isUnboxingCraftReward then
		timeout = (2000 + GetLatency())
	else
		timeout = (0 + GetLatency())
	end
	EVENT_MANAGER:RegisterForUpdate(MSI.Name.."UnboxingCheck", timeout, 
	function()
		EVENT_MANAGER:UnregisterForUpdate(MSI.Name.."UnboxingCheck")
		if unboxingInterrupted == false then
			EVENT_MANAGER:UnregisterForUpdate(MSI.Name.."UnboxingListen")
			unboxQueuedContainer()
		else
			startInterruptionListener(slotIndex)
		end
	end)
end

-- wait for item to be interactive and start listening
local function startInterruptionListener(slotIndex)
	EVENT_MANAGER:UnregisterForUpdate(MSI.Name.."UnboxingListener")
	EVENT_MANAGER:UnregisterForUpdate(MSI.Name.."UnboxingListen")
	EVENT_MANAGER:UnregisterForUpdate(MSI.Name.."UnboxingCheck")

	EVENT_MANAGER:RegisterForUpdate(MSI.Name.."UnboxingListener", (100 + GetLatency()), 
	function()
		if isUnboxing == true then
			EVENT_MANAGER:UnregisterForUpdate(MSI.Name.."UnboxingListener")
		else
			if IsPlayerIdle(slotIndex) then
				EVENT_MANAGER:UnregisterForUpdate(MSI.Name.."UnboxingListener")
				unboxingInterrupted = false
				listenInterruption(slotIndex)
				checkInterruption(slotIndex)
			end
		end
	end)
end

function MSI.FilletInventoryFish()
if not MSI.SVars.IsMSIActive then return end
	local filteredDataTable = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK)
	for _, data in pairs(filteredDataTable) do
		local item = GetItemDataIfUnknown(BAG_BACKPACK, data.slotIndex)
		if item ~= nil then
			if (item.isFish and MSI.SVars.IsFilletFish) then
				for i = 1, data.stackCount do
					table.insert(pendingUnboxingQueue, item.getSlotIndex)
				end
				startInterruptionListener(item.getSlotIndex)
			end
		end
	end
	SCENE_MANAGER:ShowBaseScene()
	unboxQueuedContainer()
end

function MSI.LearnCollectibleItems()
if not MSI.SVars.IsMSIActive then return end
	local filteredDataTable = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK)
	for _, data in pairs(filteredDataTable) do
		local item = GetItemDataIfUnknown(BAG_BACKPACK, data.slotIndex)
		if item ~= nil then
			if (item.isRecipePage and not item.isRecipeKnown and MSI.SVars.IsLearnCllctbl and item.isUnknown) then
			for i = 1, data.stackCount do
					table.insert(pendingUnboxingQueue, item.getSlotIndex)
				end
				startInterruptionListener(item.getSlotIndex)
			end
		end
	end
	SCENE_MANAGER:ShowBaseScene()
	unboxQueuedContainer()
end

function MSI.UnrollRolledTreasureMap()
if not MSI.SVars.IsMSIActive then return end
	local filteredDataTable = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK)
	for _, data in pairs(filteredDataTable) do
		local item = GetItemDataIfUnknown(BAG_BACKPACK, data.slotIndex)
		if item ~= nil then
			if ((item.isTreasureMap or (item.getLinkId == 224681)) and MSI.SVars.IsUnrollTrsrMap) then
				for i = 1, data.stackCount do
					table.insert(pendingUnboxingQueue, item.getSlotIndex)
				end
				startInterruptionListener(item.getSlotIndex)
			end
		end
	end
	SCENE_MANAGER:ShowBaseScene()
	unboxQueuedContainer()
end

function MSI.UnboxInventoryContainer()
if not MSI.SVars.IsMSIActive then return end
	local filteredDataTable = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK)
	for _, data in pairs(filteredDataTable) do
		local item = GetItemDataIfUnknown(BAG_BACKPACK, data.slotIndex)
		if item ~= nil then
			if (item.isContainer and (MSI.SVars.IsOpenContainer or (item.isBound and MSI.SVars.IsOpenBoundConti)) and (not isUnboxingCraftReward or not MSI.HasActiveWrit)) then
				for i = 1, data.stackCount do
					table.insert(pendingUnboxingQueue, item.getSlotIndex)
				end
				startInterruptionListener(item.getSlotIndex)
			end
		end
	end
	SCENE_MANAGER:ShowBaseScene()
	unboxQueuedContainer()
end

function MSI.UnboxInventoryUnopened()
if not MSI.SVars.IsMSIActive then return end
	local filteredDataTable = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK)
	for _, data in pairs(filteredDataTable) do
		local item = GetItemDataIfUnknown(BAG_BACKPACK, data.slotIndex)
		if item ~= nil then
			if (item.isUnopened and MSI.SVars.IsOpenUnopened) then
				for i = 1, data.stackCount do
					table.insert(pendingUnboxingQueue, item.getSlotIndex)
				end
				startInterruptionListener(item.getSlotIndex)
			end
		end
	end
	SCENE_MANAGER:ShowBaseScene()
	unboxQueuedContainer()
end

function MSI.BindUnboundSetItems()
if not MSI.SVars.IsMSIActive then return end
	local filteredDataTable = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK)
	for _, data in pairs(filteredDataTable) do
		local item = GetItemDataIfUnknown(BAG_BACKPACK, data.slotIndex)
		if item ~= nil then
			if (MSI.SVars.IsBindSetParts and not item.isBound and item.isSetItem and item.isUncollected and not item.isCompanionGear and not item.isCrafted) then
				for i = 1, data.stackCount do
					zo_callLater(function() 
								BindThatItem(BAG_BACKPACK, item.getSlotIndex)
								MSI.Print("c", zo_strformat(GetString(MSI_MOD_BOUND_SET_ITEM_CHTLINE), item.getLink))
					end, data.stackCount * (1000 + GetLatency()))
				end
			end
		end
	end
	SCENE_MANAGER:ShowBaseScene()
end

function MSI.MarkUnwantedJunk()
if not MSI.SVars.IsSellALLJunk then return end
	local filteredDataTable = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK)
	for _, data in pairs(filteredDataTable) do
		local item = GetItemDataIfUnknown(BAG_BACKPACK, data.slotIndex)
		if item ~= nil then
			if item.isMarkableAsJunk and not item.isItemKnownJunk then -- and not item.isSellableOnTradingHouse and not item.isNotSellable ) then
				if (MSI.SVars.IsSellALLJunk -- Setze Junk Trödel
				and ((item.isTrash and not item.isNotSellable)-- Plunder
				or (MSI.SVars.IsSellOrnJewel and item.isOrnatJewel) -- Verziert Schmuck
				or item.isOrnateGear -- Verziert Ausrüstung
				or item.isPoor -- Qualität Poor???
				or (item.isCollectible and (item.getQuality <= 3)) -- Sammlungsstück Fisch Q2Grün Q3Blau
				or (MSI.SVars.IsSellPoison and item.isPoison) -- Gift
				or (item.isTreasure and not item.isRecipePage and not item.isTreasureMap and not item.isFoodAndDrink and not item.isLaunderable))) then -- Diebesgut (Hehlerware)
					for i = 1, data.stackCount do
						zo_callLater(function() 
									SetItemIsJunk(BAG_BACKPACK, item.getSlotIndex, true)
									MSI.Print("c", zo_strformat(GetString(MSI_MOD_ITEM_MARKED_AS_JUNK), item.getLink))
						end, data.stackCount * (100 + GetLatency()))
					end
				end
			end
		end
	end
	SCENE_MANAGER:ShowBaseScene()
end

function MSI.UnmarkAll()
    local output = GetString(SI_ITEM_ACTION_UNMARK_AS_JUNK) .. ": "
    for slotId in ZO_IterateBagSlots(BAG_BACKPACK) do
        if zo_strlen(output .. GetItemLink(BAG_BACKPACK, slotId) .. "  ") > MAX_TEXT_CHAT_INPUT_CHARACTERS then
            MSI.Print("d", output)
            output = ""
		end
        if IsItemJunk(BAG_BACKPACK, slotId) then
            SetItemIsJunk(BAG_BACKPACK, slotId, false)
            output = output .. GetItemLink(BAG_BACKPACK, slotId) .. "  "
        end
    end
    MSI.Print("d", output)
end

function MSI.PrintJunk()
    local output = GetString(SI_ITEMFILTERTYPE9) .. ": "
    for slotIndex in ZO_IterateBagSlots(BAG_BACKPACK) do
        if zo_strlen(output .. GetItemLink(BAG_BACKPACK, slotIndex) .. "  ") > MAX_TEXT_CHAT_INPUT_CHARACTERS then
            MSI.Print("d", output)
            output = ""
        end
        if IsItemJunk(BAG_BACKPACK, slotIndex) then
            output = output .. GetItemLink(BAG_BACKPACK, slotIndex) .. "  "
        end
    end
    MSI.Print("d", output)
end

-- print all bag items --SetItemIsJunk(BAG_BACKPACK, slotIndex, false)
function MSI.ListAllBagItems()
    for bagSlot = 1, GetBagSize(BAG_BACKPACK) do
        local itemLink = GetItemLink(BAG_BACKPACK, bagSlot)
        local itemName = GetItemName(BAG_BACKPACK, bagSlot)
        if string.len(itemName) ~= 0 then
        -- CHAT_ROUTER:AddSystemMessage("item Type: " .. GetItemType(BAG_BACKPACK, bagSlot) .. ", slotIndex: " .. bagSlot .. ", itemLink: " .. itemLink)
        -- let's do some hacking here to get the item type string
        MSI.Print("d", "Item: " .. GetItemType(BAG_BACKPACK, bagSlot) .. " " .. GetString(_G["SI_ITEMTYPE" .. GetItemType(BAG_BACKPACK, bagSlot)]) .. ", slotIndex: " .. bagSlot .. ", itemLink: " .. itemLink)
        end
    end
end

local function PrintControlNames(control, indent)
    indent = indent or 0
    local controlName = control:GetName()
    local w, h = control:GetDimensions()
	--CHAT_ROUTER:AddSystemMessage(string.rep("--", indent) .. controlName .. " /  w:" .. math.floor(w) .. " h: " .. math.floor(h)) -- 打印控件名称
	MSI.Print("d", string.rep("--", indent) .. controlName .. " /  w:" .. math.floor(w) .. " h: " .. math.floor(h))
    -- 递归处理子控件
    for i = 1, control:GetNumChildren() do
        local childControl = control:GetChild(i)
        if childControl then
            PrintControlNames(childControl, indent + 1)
        end
    end
end

--**************************--
-- Inventory Update Handler
local function InventoryUpdate(eventCode, bagId, slotIndex, ...)
if not MSI.SVars.IsMSIActive then return end

	local item = GetItemDataIfUnknown(bagId, slotIndex)
	if item ~= nil then
	
		--************************--
		-- SetItem Binden Sammeln
		if (MSI.SVars.IsBindSetParts and not item.isBound and item.isSetItem and item.isUncollected and not item.isCompanionGear and not item.isCrafted) then
			BindThatItem(item.getBagId, item.getSlotIndex)
			MSI.Print("c", zo_strformat(GetString(MSI_MOD_BOUND_SET_ITEM_CHTLINE), item.getLink))
		end

		--***********************--
		-- Queue für Behältnisse
		if (item.isContainer and item.isCraftingContainer) then
			isUnboxingCraftReward = true else
			isUnboxingCraftReward = false
		end

		if (item.isContainer and (MSI.SVars.IsOpenContainer or (item.isBound and MSI.SVars.IsOpenBoundConti)) and (not isUnboxingCraftReward or not MSI.HasActiveWrit))
		or (item.isUnopened and MSI.SVars.IsOpenUnopened)
		or (item.isFish and MSI.SVars.IsFilletFish)
		or (item.isMisc and item.isUnknown) -- Trophähe
		or (item.isRecipePage and not item.isRecipeKnown and MSI.SVars.IsLearnCllctbl and item.isUnknown)
		or ((item.isTreasureMap or (item.getLinkId == 224681)) and MSI.SVars.IsUnrollTrsrMap) then 
			table.insert(pendingUnboxingQueue, item.getSlotIndex)
			MSI.Print("d", zo_strformat(GetString(MSI_MOD_QUEUED_CONTI_CHTLINE), item.getLink))
			startInterruptionListener(item.getSlotIndex)
		end

		--***********************--
		-- Trödel Junk markieren
		if item.isMarkableAsJunk and not item.isItemKnownJunk then -- and not item.isSellableOnTradingHouse and not item.isNotSellable ) then
			if (MSI.SVars.IsSellALLJunk -- Setze Junk Trödel
			and ((item.isTrash and not item.isNotSellable)-- Plunder
			or (MSI.SVars.IsSellOrnJewel and item.isOrnatJewel) -- Verziert Schmuck
			or item.isOrnateGear -- Verziert Ausrüstung
			or item.isPoor -- Qualität Poor???
			or (item.isCollectible and (item.getQuality <= 3)) -- Sammlungsstück Fisch Q2Grün Q3Blau
			or (MSI.SVars.IsSellPoison and item.isPoison) -- Gift
			or (item.isTreasure and not item.isRecipePage and not item.isTreasureMap and not item.isFoodAndDrink and not item.isLaunderable))) then -- Diebesgut (Hehlerware)
				SetItemIsJunk(item.getBagId, item.getSlotIndex, true)
				MSI.Print("c", zo_strformat(GetString(MSI_MOD_ITEM_MARKED_AS_JUNK), item.getLink))
			end
		end
	end
end

--************************--
-- Bind Learn Open Sell Lounder
function MSI.InitModTraderThing()
	local function UnRegModuleEvents()
        EVENT_MANAGER:UnregisterForEvent(MSI.Name.."LootUpdate", EVENT_LOOT_UPDATED)
		EVENT_MANAGER:UnregisterForEvent(MSI.Name.."SlotUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
		EVENT_MANAGER:UnregisterForEvent(MSI.Name.."LootClosed", EVENT_LOOT_CLOSED)
		EVENT_MANAGER:UnregisterForEvent(MSI.Name.."OpenStore", EVENT_OPEN_STORE)
		EVENT_MANAGER:UnregisterForEvent(MSI.Name.."OpenFence", EVENT_OPEN_FENCE)
		EVENT_MANAGER:UnregisterForEvent(MSI.Name.."OpenLaunder", EVENT_OPEN_FENCE)
	end
	local function RegModuleEvents()
		UnRegModuleEvents()
		--EVENT_MANAGER:RegisterForEvent(MSI.Name.."LootUpdate", LOOT, EVENT_LOOT_UPDATED, OnLootUpdatedThrottled)
		EVENT_MANAGER:RegisterForEvent(MSI.Name.."SlotUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, InventoryUpdate)
		EVENT_MANAGER:AddFilterForEvent(MSI.Name.."SlotUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_IS_NEW_ITEM, true)
		EVENT_MANAGER:AddFilterForEvent(MSI.Name.."SlotUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
		EVENT_MANAGER:AddFilterForEvent(MSI.Name.."SlotUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
		EVENT_MANAGER:RegisterForEvent(MSI.Name.."LootClosed", EVENT_LOOT_CLOSED, LootClosed)
		EVENT_MANAGER:RegisterForEvent(MSI.Name.."OpenStore", EVENT_OPEN_STORE, OpenStore)
		EVENT_MANAGER:RegisterForEvent(MSI.Name.."OpenFence", EVENT_OPEN_FENCE, OpenFence)
		EVENT_MANAGER:RegisterForEvent(MSI.Name.."OpenLaunder", EVENT_OPEN_FENCE, OpenLaunder)
	end
	if (MSI.SVars.IsSellALLJunk
	or MSI.SVars.IsSellStolenJunk
	or MSI.SVars.IsLaunderStolen
	or MSI.SVars.IsFilletFish
	or MSI.SVars.IsLearnCllctbl
	or MSI.SVars.isBindSetParts 
	or MSI.SVars.IsUnrollTrsrMap 
	or MSI.SVars.IsOpenContainer 
	or MSI.SVars.IsOpenBoundConti 
	or MSI.SVars.IsOpenUnopened) and MSI.SVars.IsMSIActive then
		RegModuleEvents()
		-- Auto Bind/Use Item at StartUp
		MSI.MarkUnwantedJunk()
		MSI.FilletInventoryFish()
		MSI.LearnCollectibleItems()
		MSI.BindUnboundSetItems()
		MSI.UnrollRolledTreasureMap()
		MSI.UnboxInventoryContainer()
		MSI.UnboxInventoryUnopened()
		--MSI.Print("d", "Modul option change!! BindLearnOpen Event registered")
	elseif (not MSI.SVars.IsSellALLJunk
	and not MSI.SVars.IsSellStolenJunk
	and not MSI.SVars.IsLaunderStolen
	and not MSI.SVars.IsFilletFish
	and not MSI.SVars.IsLearnCllctbl
	and not MSI.SVars.isBindSetParts 
	and not MSI.SVars.IsUnrollTrsrMap 
	and not MSI.SVars.IsOpenContainer 
	and not MSI.SVars.IsOpenBoundConti 
	and not MSI.SVars.IsOpenUnopened) or not MSI.SVars.IsMSIActive then
		UnRegModuleEvents()
		--MSI.Print("d", "Module disabled!! BindLearnOpen Event unregistered")
	else
		UnRegModuleEvents()
		--MSI.Print("d", "MSI |c8B0000not|r Active!! BindLearnOpen Event unregistered")
	end
end
--eof