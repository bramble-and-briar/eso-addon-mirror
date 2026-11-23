Bankir = Bankir or {}

Bankir.name = "Bankir"
Bankir.author = "vexaiv"
Bankir.version = "2.9.10"

local function debugPrint(message)
	d(Bankir.name .. ": " .. message)
end

local d = debugPrint --override built-in d(...)

Bankir.currentBankBagId = nil
Bankir.initQueueProcess = nil

local queue
local totals
local requiredForQuests
local reprocessNeeded

local function unifiedBagId(bagId)
	if bagId == BAG_VIRTUAL then return BAG_BACKPACK end
	if bagId ~= BAG_BACKPACK then return BAG_BANK end
	return bagId
end

local function getRuleForItem(itemLink, bagIdAlias, itemQuality, itemStackSize)
	local itemType, specializedItemType, itemId = Bankir.Functions.redefineItemTypes(itemLink)
	local rule, ruleDefId
	
	-- byItemId is the highest priority, next bySpecializedItemType, and then byItemType
	rule = Bankir.Functions.getEffectiveRule(itemId, "itemId", bagIdAlias, itemQuality, itemStackSize)
	ruleDefId = itemId
	
	if rule.push == 0 and rule.pull == 0
	-- for specializedItemType at first check if itemId is not a child of some specializedItemType.
	-- In case if it's a child, it would mean that the parent specializedItemType has rules but there's
	-- no rule set for this specific child itemId. So, that specific itemId is set to "Do nothing" intentionally by player,
	-- and in this case we shouldn't proceed. Parent type rule shouldn't affect specific children id rules.
	and not Bankir.Data.isChildOf(itemId, "itemId", specializedItemType, "specializedItemType")
	then
		rule = Bankir.Functions.getEffectiveRule(specializedItemType, "specializedItemType", bagIdAlias, itemQuality, itemStackSize)
		ruleDefId = specializedItemType
	end
		
	if rule.push == 0 and rule.pull == 0
	-- for itemType do the same kind of child/parent check as for specializedItemType
	and not Bankir.Data.isChildOf(itemId, "itemId", itemType, "itemType")
	then
		rule = Bankir.Functions.getEffectiveRule(itemType, "itemType", bagIdAlias, itemQuality, itemStackSize)
		ruleDefId = itemType
	end
	
	local itemType = GetItemLinkItemType(itemLink)
	if itemType == ITEMTYPE_ARMOR or itemType == ITEMTYPE_WEAPON then
		-- special case for armor/weapon to count totals of all intricate light armor
		-- as same item, all companion shields as same item and so on
		rule.totalsId = ruleDefId
	else
		rule.totalsId = Bankir.Functions.getNormalizedLink(itemLink)
	end
	
	return rule
end

local function getEmptySlot(bagId)
	if bagId == BAG_GUILDBANK then
		-- guild bank slots are virtual, every new transfer creates a new slotId
		-- that is +1 from the last created slot. None of the slots is empty.
		local count = 0
		local lastSlot
		for slotId in ZO_IterateBagSlots(bagId) do
			count = count + 1
			lastSlot = slotId
		end
		-- after getting the last slotId we know that next transfer will end up at lastSlot+1
		if count < GetBagSize(bagId) then
			return (lastSlot or -1) + 1
		end
	else
		-- other bags simply have slots from 0 up to GetBagSize-1
		for slotId = 0, GetBagSize(bagId) - 1 do
			local size = GetSlotStackSize(bagId, slotId)
			if size == 0 then
				return slotId
			end
		end
	end
end

local function tryGetNotFullSlot(sourceBagId, targetBagId, itemLink)
	local isGuildBank = sourceBagId == BAG_GUILDBANK or targetBagId == BAG_GUILDBANK
	local comp1 = isGuildBank and Bankir.Functions.getNormalizedLink(itemLink) or itemLink
	local emptySlot, targetSlot, itemLinkInSlot
	local targetStack = 0
	for slotId in ZO_IterateBagSlots(targetBagId) do
		local stack, maxStack = GetSlotStackSize(targetBagId, slotId)
		if stack == 0 then
			if not emptySlot then
				emptySlot = slotId
			end
		elseif stack < maxStack then
			itemLinkInSlot = GetItemLink(targetBagId, slotId)
			local comp2 = isGuildBank and Bankir.Functions.getNormalizedLink(itemLinkInSlot) or itemLinkInSlot
			if comp1 == comp2 then
				if stack > targetStack then
					targetStack = stack
					targetSlot = slotId
				end
			end
		end
	end
	if targetSlot then
		return targetSlot, targetStack
	end
	return emptySlot, 0
end

local function getTargetSlot(sourceBagId, targetBagId, itemLink)
	if targetBagId == BAG_BACKPACK and IsESOPlusSubscriber() and CanItemLinkBeVirtual(itemLink) then
		if GetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_ADD_TO_CRAFT_BAG) == "1" then
			-- if craft items set to go to craft bag. Slots in craft bag are itemId-numbered
			local itemId = GetItemLinkItemId(itemLink)
			return itemId, BAG_VIRTUAL
		end
	end

	-- non-stackable items need new empty slot
	if not IsItemLinkStackable(itemLink) then
		slotId = getEmptySlot(targetBagId)
		-- try ESO+ bank
		if not slotId and targetBagId == BAG_BANK and IsESOPlusSubscriber() then
			slotId = getEmptySlot(BAG_SUBSCRIBER_BANK)
			if slotId then
				return slotId, BAG_SUBSCRIBER_BANK
			end
		end
		-- return anyway because not stackable items won't fit into occupied anyway
		return slotId, targetBagId
	end
	
	-- try find appropriate half-occupied slot or empty slot
	local slotId, stack = tryGetNotFullSlot(sourceBagId, targetBagId, itemLink)
	
	-- return half-occupied if found
	if slotId and stack > 0 then
		return slotId, targetBagId
	end
	
	-- try ESO+ extra bank bag
	local subSlotId, subStack
	if targetBagId == BAG_BANK and IsESOPlusSubscriber() then
		subSlotId, subStack = tryGetNotFullSlot(sourceBagId, BAG_SUBSCRIBER_BANK, itemLink)
		if subSlotId and subStack > 0 then
			return subSlotId, BAG_SUBSCRIBER_BANK
		end
	end
	
	-- no appropriate half-occupied slot found, use empty slot, found earlier or new
	slotId = slotId or getEmptySlot(targetBagId)
	
	-- if only ESO+ bank has empty slots
	if not slotId and subSlotId then
		return subSlotId, BAG_SUBSCRIBER_BANK
	end
	
	return slotId, targetBagId
end

local function countSameItemsInBag(bagId, totalsId)
	local count = 0
	for slotId in ZO_IterateBagSlots(bagId) do
		repeat
			local itemLinkInSlot = GetItemLink(bagId, slotId)
			if not itemLinkInSlot then break end
			if totalsId ~= Bankir.Functions.getNormalizedLink(itemLinkInSlot) then
				-- special case for armor/weapon to count totals of all intricate light armor
				-- as same item, all companion shields as same item and so on
				local itemType, specializedItemType, itemId = Bankir.Functions.redefineItemTypes(itemLinkInSlot)
				if itemId ~= totalsId and specializedItemType ~= totalsId and itemType ~= totalsId then
					break
				end
			end
			local stack = GetSlotStackSize(bagId, slotId)
			count = count + stack
		until true
	end
	return count
end

local function getTotalItemsInBag(bagId, totalsId)
	local uBagId = unifiedBagId(bagId)
	
	if not totals[uBagId][totalsId] then
		local count = countSameItemsInBag(bagId, totalsId)
		if bagId == BAG_BANK then
			count = count + countSameItemsInBag(BAG_SUBSCRIBER_BANK, totalsId)
		elseif bagId == BAG_SUBSCRIBER_BANK then
			count = count + countSameItemsInBag(BAG_BANK, totalsId)
		elseif bagId == BAG_BACKPACK then
			count = count + countSameItemsInBag(BAG_VIRTUAL, totalsId)
		elseif bagId == BAG_VIRTUAL then
			count = count + countSameItemsInBag(BAG_BACKPACK, totalsId)
		end
		totals[uBagId][totalsId] = count
	end
	return totals[uBagId][totalsId]
end

local function updateTotals(totalsId, bagId, movedCount)
	local bagId = unifiedBagId(bagId)
	totals[bagId][totalsId] = totals[bagId][totalsId] + movedCount
	--d("totals of " .. itemLink .. " in " .. Bankir.Functions.getBagName(bagId) .. ": " .. totals[bagId][totalsId])
end

local function printToChat(itemName, amount, targetBagId)		
	if not amount then
		d(itemName)
	else
		local targetBagName = Bankir.Functions.getBagName(targetBagId)
		d(string.format("%s x%d → %s", itemName, amount, targetBagName))
	end
end

local function processCurrency(bagId)
	if not Bankir.SVProfile[bagId].currency then return end
	for currencyType, rules in pairs(Bankir.SVProfile[bagId].currency) do
		repeat
			if not rules.push and not rules.pull then break end
			local amount = GetCurrencyAmount(currencyType, CURRENCY_LOCATION_CHARACTER) - rules.amount
			if rules.push and amount > 0 then
				printToChat(ZO_Currency_GetPlatformFormattedCurrencyIcon(currencyType), amount, bagId)
				if bagId == BAG_BANK then
					DepositCurrencyIntoBank(currencyType, amount)
				else
					DepositCurrencyIntoGuildBank(currencyType, amount)
				end
			elseif rules.pull and amount < 0 then
				local amountInBank
				if bagId == BAG_BANK then
					amountInBank = GetCurrencyAmount(currencyType, CURRENCY_LOCATION_BANK)
				else
					amountInBank = GetCurrencyAmount(currencyType, CURRENCY_LOCATION_GUILD_BANK)
				end
				amount = math.min(amount * -1, amountInBank)
				if amount > 0 then
					printToChat(ZO_Currency_GetPlatformFormattedCurrencyIcon(currencyType), amount, BAG_BACKPACK)
					if bagId == BAG_BANK then
						WithdrawCurrencyFromBank(currencyType, amount)
					else
						WithdrawCurrencyFromGuildBank(currencyType, amount)
					end
				end
			end
		until true
	end
end

local function populateQueue(sourceBagId, targetBagId)
	--which of the bags is a bank bag?
	local bankBagAlias = sourceBagId == BAG_BACKPACK and targetBagId or sourceBagId
	if bankBagAlias == BAG_GUILDBANK then
		local guildId = GetSelectedGuildBankId()
		bankBagAlias = "Guild" .. guildId
	elseif bankBagAlias == BAG_SUBSCRIBER_BANK then
		bankBagAlias = BAG_BANK
	end
	
	local cache = SHARED_INVENTORY:GetOrCreateBagCache(sourceBagId)
	for slotId in pairs(cache) do
		repeat
			if IsItemStolen(sourceBagId, slotId) then break end
			if IsItemPlayerLocked(sourceBagId, slotId)
		    and not Bankir.SVCommon.moveLockedItems then break end
		    if targetBagId == BAG_GUILDBANK
			and IsItemBound(sourceBagId, slotId) then break end
			
			local itemLink = GetItemLink(sourceBagId, slotId)
			
			if sourceBagId == BAG_BACKPACK
			and GetItemLinkBindType(itemLink) == BIND_TYPE_ON_PICKUP_BACKPACK then break end
			
			local stackSize, maxStackSize = GetSlotStackSize(sourceBagId, slotId)
			local itemQuality = GetItemLinkDisplayQuality(itemLink)
			
			local rule =
				getRuleForItem(itemLink, bankBagAlias, itemQuality, maxStackSize)
			
			local pullForQuests = 0
			if Bankir.SVCommon.moveQuestItems then
				if requiredForQuests[itemLink] then
					pullForQuests = requiredForQuests[itemLink]
				else
					--check whether it's required or not
					local required = Bankir.Functions.checkItemForQuests(sourceBagId, slotId)
					if required > 0 then
						d(zo_strformat(GetString(BANKIR_CHAT_REQUIRED_FOR_QUESTS), itemLink, required))
						requiredForQuests[itemLink] = required
						pullForQuests = required
					end
				end
			end
			
			if rule.push == 0 and rule.pull == 0 and pullForQuests == 0 then break end
			
			if (targetBagId ~= BAG_BACKPACK and rule.push == 0) --target is bank but nothing to push
			or (sourceBagId ~= BAG_BACKPACK and rule.pull == 0 and pullForQuests == 0) --source is bank but nothing to pull
			then break end
			
			--update how many of the item is already in target bag
			getTotalItemsInBag(targetBagId, rule.totalsId)
			getTotalItemsInBag(sourceBagId, rule.totalsId)
			
			if rule.pullInStacks then
				rule.pull = rule.pull * maxStackSize
			end
			rule.pull = rule.pull + pullForQuests
			
			local targetMax
			if sourceBagId == BAG_BACKPACK then
				targetMax = rule.push * maxStackSize
			else
				targetMax = rule.pull
			end
			
			if getTotalItemsInBag(targetBagId, rule.totalsId) >= targetMax then break end
			
			--finally, if all good, add to the queue
			--d("add to queue " .. itemLink .. " as " .. totalsId .. " sourceBagId = " .. sourceBagId .. " sourceSlotId = " .. slotId .. " targetBagId = " .. targetBagId .. " targetMax = " .. targetMax .. " sourceMin = " .. toPull)
			table.insert(queue.items, { sourceBagId = sourceBagId, sourceSlotId = slotId,
				targetBagId = targetBagId, itemLink = itemLink,
				targetMax = targetMax, sourceMin = rule.pull,
				totalsId = rule.totalsId })
		until true
	end
end

local function onQueueProcessed()
	if IsBankOpen() then
		processCurrency(BAG_BANK)
	elseif IsGuildBankOpen() then
		local guildId = GetSelectedGuildBankId()
		processCurrency("Guild" .. guildId)
	end

	-- print "Done" only if still in banking interface
	if IsBankOpen() or IsGuildBankOpen() then
		d(GetString(SI_GAMEPAD_CAMPAIGN_SCORING_DURATION_REMAINING_DONE))
	end
	
	--let GC free some memory
	queue = nil
	totals = nil
	requiredForQuests = nil
	
	EVENT_MANAGER:UnregisterForEvent(name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
	EVENT_MANAGER:UnregisterForEvent(name, EVENT_BANK_DEPOSIT_NOT_ALLOWED)
	EVENT_MANAGER:UnregisterForEvent(name, EVENT_GUILD_BANK_ITEM_ADDED)
	EVENT_MANAGER:UnregisterForEvent(name, EVENT_GUILD_BANK_ITEM_REMOVED)
end

local function moveItem(itemLink, sourceBagId, sourceSlotId, targetBagId, targetSlotId, stackSize, maxStackSize)
	--d("moveItem from " .. Bankir.Functions.getBagName(sourceBagId) .. " slot " .. sourceSlotId .. " to " .. Bankir.Functions.getBagName(targetBagId) .. " slot " .. targetSlotId .. " stackSize " .. stackSize)
	if (sourceBagId == BAG_GUILDBANK) then
		TransferFromGuildBank(sourceSlotId)
		local soundCategory = GetItemSoundCategory(sourceBagId, sourceSlotId)
		PlayItemSound(soundCategory, ITEM_SOUND_ACTION_PICKUP)
	elseif (targetBagId == BAG_GUILDBANK) then
		TransferToGuildBank(sourceBagId, sourceSlotId)
		local soundCategory = GetItemSoundCategory(sourceBagId, sourceSlotId)
		PlayItemSound(soundCategory, ITEM_SOUND_ACTION_PICKUP)
	else
		CallSecureProtected("RequestMoveItem", sourceBagId, sourceSlotId, targetBagId, targetSlotId, stackSize)
	end
end

local function processQueue()
	if not IsBankOpen() and not IsGuildBankOpen() then return end
	if not queue then return end
	
	if not reprocessNeeded then
		queue.index = queue.index + 1
	end
	reprocessNeeded = false

	if queue.index > #queue.items then
		onQueueProcessed()
		return
	end
	
	local sourceBagId = queue.items[queue.index].sourceBagId
	local sourceSlotId = queue.items[queue.index].sourceSlotId
	local targetBagId = queue.items[queue.index].targetBagId
	local itemLink = queue.items[queue.index].itemLink
	local targetMax = queue.items[queue.index].targetMax
	local sourceMin = queue.items[queue.index].sourceMin
	local totalsId = queue.items[queue.index].totalsId
	
	--d("processQueue at index " .. queue.index .. "(" .. itemLink .. ") bag " .. sourceBagId .. " slot " .. sourceSlotId)
	
	local targetTotal = getTotalItemsInBag(targetBagId, totalsId)
	local sourceTotal = getTotalItemsInBag(sourceBagId, totalsId)
	
	if IsItemLinkUnique(itemLink) then
		if getTotalItemsInBag(targetBagId, totalsId) > 0 then
			if Bankir.SVCommon.showOperationFailMessages then
				d(zo_strformat(GetString(BANKIR_CHAT_ALREADY_HAVE_UNIQUE_ITEM), itemLink, Bankir.Functions.getBagName(targetBagId)))
			end
			processQueue()
			return
		end
	end
	
	local sourceStackSize, maxStackSize = GetSlotStackSize(sourceBagId, sourceSlotId)
	local sourceStackSizeFinal = sourceStackSize
	
	if sourceStackSize > targetMax - targetTotal then
		--d("sourceStackSize of " .. itemLink .. " (" .. sourceStackSize .. ") exceeds the max needed (targetMax (" .. targetMax .. ") - targetTotal (" .. targetTotal .. ")), will be targetMax - targetTotal (" .. targetMax - targetTotal .. ")")
		sourceStackSizeFinal = targetMax - targetTotal
	end
	
	if sourceBagId == BAG_BACKPACK then
		if sourceMin then
			local remains = sourceTotal - sourceStackSizeFinal
			if remains < sourceMin then
				--d("stack is " .. sourceStackSizeFinal .. " have to keep " .. sourceMin .. " will move " .. sourceStackSizeFinal - (sourceMin - remains))
				sourceStackSizeFinal = sourceStackSizeFinal - (sourceMin - remains)
			end
		end
	end
	
	if sourceStackSizeFinal <= 0 then
		processQueue()
		return
	end
	
	local targetSlotId
	targetSlotId, targetBagId = getTargetSlot(sourceBagId, targetBagId, itemLink)
	
	if not targetSlotId then
		if Bankir.SVCommon.showOperationFailMessages then
			d(zo_strformat(GetString(BANKIR_CHAT_NO_FREE_SPACE), Bankir.Functions.getBagName(targetBagId), itemLink))
		end
		processQueue()
		return
	end
	
	queue.items[queue.index].targetSlotId = targetSlotId
	
	local targetStackSize = GetSlotStackSize(targetBagId, targetSlotId)
	--d("targetSlot " .. targetSlotId .. " in " .. Bankir.Functions.getBagName(targetBagId) .. " stack size: " .. targetStackSize)
	
	if targetBagId == BAG_VIRTUAL then
		-- craft bag no limits
		targetStackSize = 0
		maxStackSize = math.max
	elseif sourceStackSizeFinal > maxStackSize - targetStackSize then
		--d("sourceStackSize (" .. sourceStackSizeFinal .. ") doesn't fit into the target slot, will be maxStackSize(".. maxStackSize .. ") - targetStackSize(".. targetStackSize .. ")")
		sourceStackSizeFinal = maxStackSize - targetStackSize
	end
	
	if IsBankOpen() and sourceStackSize ~= sourceStackSizeFinal then
		--to step back and re-process what remains in this slot in next iteration
		reprocessNeeded = true
	end
	
	-- special temporary transfer for guild bank. We move the whole stack to backpack where it'll be split if needed.
	-- it only works if player has WITHDRAW permission. Without permission this section is skipped and regular moveItem is called
	if IsGuildBankOpen()
	and DoesPlayerHaveGuildPermission(GetSelectedGuildBankId(), GUILD_PERMISSION_BANK_WITHDRAW)
	then
		local fromBag, fromSlot
		if targetStackSize > 0 or sourceStackSize ~= sourceStackSizeFinal then
			if sourceBagId == BAG_GUILDBANK then
				fromBag = sourceBagId
				fromSlot = sourceSlotId
			elseif sourceBagId == BAG_BACKPACK then
				fromBag = targetBagId
				fromSlot = targetSlotId
			end
		end
		if fromBag then
			--d("need to split. targetStackSize: " .. targetStackSize .. " sourceStackSize: " .. sourceStackSize .. " sourceStackSizeFinal: " .. sourceStackSizeFinal)
			local stack, maxStack = GetSlotStackSize(fromBag, fromSlot)
			local backpackEmptySlotId = getEmptySlot(BAG_BACKPACK)
			
			if not backpackEmptySlotId then
				if Bankir.SVCommon.showOperationFailMessages then
					d(zo_strformat(GetString(BANKIR_CHAT_NO_FREE_SPACE), Bankir.Functions.getBagName(BAG_BACKPACK), itemLink))
				end
				processQueue()
			end
			
			if targetStackSize == 0 and sourceBagId == BAG_BACKPACK then
				-- if target in guild bank is empty, we skip the step where we pull slot from guild bank and go right to state 2
				queue.items[queue.index].tempState = 2
				queue.items[queue.index].tempSlotId = backpackEmptySlotId
				queue.items[queue.index].tempDest = { BAG_BACKPACK, sourceSlotId, BAG_BACKPACK, backpackEmptySlotId }
				--d("move " .. sourceStackSizeFinal .. " of " .. itemLink .. " from " .. Bankir.Functions.getBagName(BAG_BACKPACK) .. " source slot " .. sourceSlotId .. " to " .. Bankir.Functions.getBagName(BAG_BACKPACK) .. " empty slot " .. backpackEmptySlotId)
				moveItem(itemLink, BAG_BACKPACK, sourceSlotId, BAG_BACKPACK, backpackEmptySlotId, sourceStackSizeFinal, maxStack)
			else
				queue.items[queue.index].tempState = 0
				queue.items[queue.index].tempSlotId = backpackEmptySlotId
				queue.items[queue.index].tempAmount = sourceStackSizeFinal
				queue.items[queue.index].tempDest = { fromBag, fromSlot, BAG_BACKPACK, backpackEmptySlotId }
				--d("move " .. stack .. " of " .. itemLink .. " from " .. Bankir.Functions.getBagName(fromBag) .. " slot " .. fromSlot .. " to " .. Bankir.Functions.getBagName(BAG_BACKPACK) .. " empty slot " .. backpackEmptySlotId)
				moveItem(itemLink, fromBag, fromSlot, BAG_BACKPACK, backpackEmptySlotId, stack, maxStack)
			end
			return
		end
	end
	-- trying to fix issue when ZO_IterateBagSlots() in getEmptySlot() fails for guild bank sometimes.
	-- probably the reason is: if there's no temp backpack slot sequence and processQueue() starts right after the item in the queue arrived to backpack
	-- it's not removed from guild bank yet, and right at the moment when next item is processed, the previous one is removed from guild bank
	-- and guild bank cache is getting updated, so there's no slots data in cache during update, therefore ZO_IterateBagSlots doesn't iterate (no slots to iterate)
	-- so, let's make the direct transaction wait for both events too (arrived to bag, removed from bag) that will make next processQueue() run only after all done and new cache is ready
	queue.items[queue.index].tempState = 4
	queue.items[queue.index].tempDest = { sourceBagId, sourceSlotId, targetBagId, targetSlotId }
	moveItem(itemLink, sourceBagId, sourceSlotId, targetBagId, targetSlotId, sourceStackSizeFinal, maxStackSize)
end

local function onSlotChanged(bagId, slotId, countChange, byLocalPlayer)
	--d("onSlotChanged(bagId .. " .. bagId .. ", slotId " .. slotId .. ", countChange " .. countChange)
	
	local itemInQueue = queue.items[queue.index]
	
	if itemInQueue.tempDest then
		local interfered
		if not byLocalPlayer then
			interfered = true
		elseif countChange < 0 and itemInQueue.tempDest[1] ~= bagId and itemInQueue.tempDest[2] ~= slotId then
			interfered = true
		elseif countChange > 0 and itemInQueue.tempDest[3] ~= bagId and itemInQueue.tempDest[4] ~= slotId then
			interfered = true
		end
		if interfered then
			d(GetString(BANKIR_CHAT_QUEUE_INTERFERED))
			onQueueProcessed()
			if Bankir.SVCommon.restartOnInterfered then
				d(GetString(BANKIR_CHAT_QUEUE_RESTARTED))
				Bankir.initQueueProcess()
			end
			return
		end
	end
	
	local itemLink = itemInQueue.itemLink
	local totalsId = itemInQueue.totalsId
	local stack, maxStack = GetSlotStackSize(bagId, slotId)
	
	if countChange > 0 then
		if bagId == BAG_GUILDBANK then
			-- giuld bank only returns countChange as 1 or -1, and moves whole stacks
			countChange = stack * countChange
		end
	end
	
	if itemInQueue.tempState then
		itemInQueue.tempState = itemInQueue.tempState + 1
		
		--[[
		local stateNamesByTargetBag = {
			[BAG_GUILDBANK] = { -- target
				[0] = "state 0",
				[1] = "arrived to temp OR moved from GBANK",
				[2] = "arrived to temp AND moved from GBANK",
				[3] = "arrived to temp OR moved from BAG",
				[4] = "arrived to temp AND moved from BAG",
				[5] = "arrived to GBANK OR moved from temp",
				[6] = "arrived to GBANK AND moved from temp",
			},
			[BAG_BACKPACK] = { -- target
				[0] = "state 0",
				[1] = "arrived to temp OR moved from GBANK",
				[2] = "arrived to temp AND moved from GBANK",
				[3] = "arrived to BAG OR moved from temp",
				[4] = "arrived to BAG AND moved from temp",
				[5] = "arrived to GBANK OR moved from temp",
				[6] = "arrived to GBANK AND moved from temp",
			},
		}
		d("STATE: " .. itemInQueue.tempState .. " " .. stateNamesByTargetBag[itemInQueue.targetBagId][itemInQueue.tempState])
		]]--
	end
	
	local state = itemInQueue.tempState
	
	-- for regular transfers without tempBAG, or tempBAG<=>GUILDBANK, and not BAG<=>BAG (states 3, 4)
	if countChange > 0 and state ~= 3 and state ~= 4 then
		printToChat(itemLink, countChange, bagId)
		local thisBag = unifiedBagId(bagId)
		local otherBag = thisBag == BAG_BACKPACK and BAG_BANK or BAG_BACKPACK
		updateTotals(itemInQueue.totalsId, thisBag, countChange)
		updateTotals(itemInQueue.totalsId, otherBag, -countChange)
	end
	
	if not state then
		if countChange > 0 then processQueue() end
		return
	end
	
	if state == 2 then
		if itemInQueue.targetBagId == BAG_GUILDBANK then
			--d("~= bagId. now move inside " .. Bankir.Functions.getBagName(BAG_BACKPACK) .. " from slot " .. itemInQueue.sourceSlotId .. " to temp slot " .. itemInQueue.tempSlotId .. " move  tempAmount: " .. itemInQueue.tempAmount)
			itemInQueue.tempDest = { BAG_BACKPACK, itemInQueue.sourceSlotId, BAG_BACKPACK, itemInQueue.tempSlotId }
			moveItem(itemLink, BAG_BACKPACK, itemInQueue.sourceSlotId, BAG_BACKPACK, itemInQueue.tempSlotId, itemInQueue.tempAmount, maxStack)
		else
			if itemInQueue.targetSlotId == itemInQueue.tempSlotId then
				local newTargetSlotId = getEmptySlot(BAG_BACKPACK)
				itemInQueue.targetSlotId = newTargetSlotId
			end
			itemInQueue.tempDest = { BAG_BACKPACK, itemInQueue.tempSlotId, BAG_BACKPACK, itemInQueue.targetSlotId }
			--d("==bagId. now move inside " .. Bankir.Functions.getBagName(BAG_BACKPACK) .. " from temp slot " .. itemInQueue.tempSlotId .. " to target slot " .. itemInQueue.targetSlotId .. " move tempAmount: " .. itemInQueue.tempAmount)
			moveItem(itemLink, BAG_BACKPACK, itemInQueue.tempSlotId, BAG_BACKPACK, itemInQueue.targetSlotId, itemInQueue.tempAmount, maxStack)
		end
	elseif state == 4 then
		if itemInQueue.targetBagId == BAG_GUILDBANK then
			local newTargetSlotId = getEmptySlot(itemInQueue.targetBagId)
			itemInQueue.targetSlotId = newTargetSlotId
			local stack, maxStack = GetSlotStackSize(BAG_BACKPACK, itemInQueue.tempSlotId)
			itemInQueue.tempDest = { BAG_BACKPACK, itemInQueue.tempSlotId, itemInQueue.targetBagId, newTargetSlotId }
			--d("~= bagId. now move back to " .. Bankir.Functions.getBagName(itemInQueue.targetBagId) .. " from temp slot " .. itemInQueue.tempSlotId  .. " to new target slot " .. newTargetSlotId .. " move stack amount: " .. stack)
			moveItem(itemInQueue.itemLink, BAG_BACKPACK, itemInQueue.tempSlotId, itemInQueue.targetBagId, newTargetSlotId, stack, maxStack)
		else
			local stack, maxStack = GetSlotStackSize(BAG_BACKPACK, itemInQueue.tempSlotId)
			--d("stack remains in temp slot " .. itemInQueue.tempSlotId .. ": " .. stack)
			if stack > 0 then
				reprocessNeeded = true
				itemInQueue.sourceSlotId = getEmptySlot(itemInQueue.sourceBagId)
				itemInQueue.tempDest = { BAG_BACKPACK, itemInQueue.tempSlotId, itemInQueue.sourceBagId, itemInQueue.sourceSlotId }
				--d("now move back to " .. Bankir.Functions.getBagName(itemInQueue.sourceBagId) .. " from slot " .. itemInQueue.tempSlotId  .. " to new source slot " .. itemInQueue.sourceSlotId .. " move stack amount: " .. stack)
				moveItem(itemInQueue.itemLink, BAG_BACKPACK, itemInQueue.tempSlotId, itemInQueue.sourceBagId, itemInQueue.sourceSlotId, stack, maxStack)
			else
				itemInQueue.tempState = nil
				itemInQueue.tempDest = nil
				processQueue()
			end
		end
	elseif state == 6 then
		if itemInQueue.targetBagId == BAG_GUILDBANK then
			local stack, maxStack = GetSlotStackSize(itemInQueue.sourceBagId, itemInQueue.sourceSlotId)
			--d("stack remains in source slot " .. itemInQueue.sourceSlotId .. ": " .. stack)
			if stack > 0 then
				reprocessNeeded = true
			end
		end
		itemInQueue.tempState = nil
		itemInQueue.tempDest = nil
		processQueue()
	end
end

local function onBankDepositNotAllowed()
	if Bankir.SVCommon.showOperationFailMessages then
		local itemInQueue = queue.items[queue.index]
		if itemInQueue then
			d(itemInQueue.itemLink .. " " .. GetString(SI_INVENTORY_ERROR_BANK_DEPOSIT_NOT_ALLOWED))
		end
	end
	
	processQueue()
end

function Bankir.initQueueProcess()
	--local startTimeMs = GetGameTimeMilliseconds()
	local bagId = Bankir.currentBankBagId
	
	totals = { [BAG_BACKPACK] = {}, [BAG_BANK] = {} }
	queue = { index = 0, items = {} }
	requiredForQuests = {}
	
	if IsBankOpen() or DoesPlayerHaveGuildPermission(GetSelectedGuildBankId(), GUILD_PERMISSION_BANK_DEPOSIT) then
		populateQueue(BAG_BACKPACK, bagId)
	end
	if IsBankOpen() or DoesPlayerHaveGuildPermission(GetSelectedGuildBankId(), GUILD_PERMISSION_BANK_WITHDRAW) then
		populateQueue(bagId, BAG_BACKPACK)
	end
	if bagId == BAG_BANK and IsESOPlusSubscriber() then
		populateQueue(BAG_SUBSCRIBER_BANK, BAG_BACKPACK)
	end
	
	if #queue.items > 0 then
		EVENT_MANAGER:RegisterForEvent(name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
			function(eventCode, bagId, slotId, isNewItem, itemSoundCategory, updateReason, countChange)
				onSlotChanged(bagId, slotId, countChange, true)
		end)
		EVENT_MANAGER:AddFilterForEvent(name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
		
		EVENT_MANAGER:RegisterForEvent(name, EVENT_BANK_DEPOSIT_NOT_ALLOWED, function(eventCode) onBankDepositNotAllowed() end)
		
		if bagId == BAG_GUILDBANK then
			EVENT_MANAGER:RegisterForEvent(name, EVENT_GUILD_BANK_ITEM_ADDED, function(eventCode, slotId, addedByLocalPlayer)
				onSlotChanged(BAG_GUILDBANK, slotId, 1, addedByLocalPlayer)
			end)
			EVENT_MANAGER:RegisterForEvent(name, EVENT_GUILD_BANK_ITEM_REMOVED, function(eventCode, slotId, addedByLocalPlayer)
				onSlotChanged(BAG_GUILDBANK, slotId, -1, addedByLocalPlayer)
			end)
		end
	end
	
	--d("Queue building took " .. GetGameTimeMilliseconds() - startTimeMs .. " ms")
	processQueue()
end

local function onBankOpen(bagId)
	--d("opened " .. bagId ..  " " .. Bankir.Functions.getBagName(bagId))
	
	local supportedBanks = {
		[BAG_BANK] = true,
		[BAG_GUILDBANK] = true,
		[BAG_HOUSE_BANK_ONE] = true,
		[BAG_HOUSE_BANK_TWO] = true,
		[BAG_HOUSE_BANK_THREE] = true,
		[BAG_HOUSE_BANK_FOUR] = true,
		[BAG_HOUSE_BANK_FIVE] = true,
		[BAG_HOUSE_BANK_SIX] = true,
		[BAG_HOUSE_BANK_SEVEN] = true,
		[BAG_HOUSE_BANK_EIGHT] = true,
	}
	-- process only supported bank bags. Furniture vault is not one of them yet.
	if supportedBanks[bagId] then
		Bankir.Button.button:SetState(BSTATE_NORMAL, true)
		Bankir.Button.button:SetAlpha(1.0)
		
		Bankir.currentBankBagId = bagId
	else
		Bankir.Button:SetHidden(true)
		return
	end
	
	if Bankir.SVCommon.autoModeEnabled then
		Bankir.initQueueProcess()
	end
end

local function onBankClose()
	--d("Bank closed")
	onQueueProcessed()
	
	Bankir.currentBankBagId = nil
	
	Bankir.Button.button:SetState(BSTATE_DISABLED, false)
	Bankir.Button.button:SetAlpha(0.5)
end

local function onAddOnLoaded(event, addonName)
	if addonName ~= Bankir.name then return end
	EVENT_MANAGER:UnregisterForEvent(Bankir.name, EVENT_ADD_ON_LOADED)
	
	Bankir.Data.getBankBagIds()
	Bankir.Data.getBankNames()
	Bankir.Data.getCharactersList()
	
	local defaultProfileName = "Default"
	local profiles = Bankir.Profiles.getProfilesNames()
	if #profiles > 0 then
		defaultProfileName = profiles[1]
	end
	Bankir.SVCharacter = ZO_SavedVars:NewCharacterIdSettings("BankirSavedVariables", 2, nil, { profile = defaultProfileName })
	Bankir.Profiles.initProfile(Bankir.SVCharacter.profile)
	
	BankirSavedVariables.Common = BankirSavedVariables.Common or Bankir.Data.getDefaultCommonSettings()
	Bankir.SVCommon = BankirSavedVariables.Common
	
	BankirSavedVariables.Server = BankirSavedVariables.Server or {}
	BankirSavedVariables.Server[GetWorldName()] = BankirSavedVariables.Server[GetWorldName()] or Bankir.Data.getDefaultServerSettings()
	Bankir.SVServer = BankirSavedVariables.Server[GetWorldName()]
	
	if BankirSavedVariables.Common.version ~= version then
		for profile in pairs(BankirSavedVariables.Profiles) do
			Bankir.Functions.mergeData(BankirSavedVariables.Profiles[profile], Bankir.Data.getDefaultProfileSettings())
		end
		Bankir.Functions.mergeData(BankirSavedVariables.Common, Bankir.Data.getDefaultCommonSettings())
		Bankir.Functions.mergeData(BankirSavedVariables.Server[GetWorldName()], Bankir.Data.getDefaultServerSettings())
		BankirSavedVariables.Common.version = version
	end
	
	Bankir.Data.updateResearchCharacters()
	Bankir.Profiles.updateBankProfiles()
	Bankir.Menu.create()
	Bankir.Button = Bankir.Functions.createProcessButton()
	
	EVENT_MANAGER:RegisterForEvent(Bankir.name, EVENT_OPEN_BANK, function(eventCode, bankBag)
		onBankOpen(bankBag)
	end)
	EVENT_MANAGER:RegisterForEvent(Bankir.name, EVENT_GUILD_BANK_ITEMS_READY, function()
		onBankOpen(BAG_GUILDBANK)
	end)
	EVENT_MANAGER:RegisterForEvent(Bankir.name, EVENT_CLOSE_BANK, onBankClose)
	EVENT_MANAGER:RegisterForEvent(Bankir.name, EVENT_CLOSE_GUILD_BANK, onBankClose)
	EVENT_MANAGER:RegisterForEvent(Bankir.name, EVENT_GUILD_BANK_SELECTED, function()
		if Bankir.currentBankBagId then
			onBankClose()
		end
	end)
	EVENT_MANAGER:RegisterForEvent(Bankir.name, EVENT_GUILD_SELF_JOINED_GUILD, function(eventCode, guildServerId, characterName, guildId)
		Bankir.Data.onBanksUpdated()
	end)
	EVENT_MANAGER:RegisterForEvent(Bankir.name, EVENT_COLLECTIBLES_UNLOCK_STATE_CHANGED, function(eventCode)
		local function GetNextDirtyUnlockStateCollectibleIdIter(_, lastCollectibleId)
			return GetNextDirtyUnlockStateCollectibleId(lastCollectibleId)
		end
		for id in GetNextDirtyUnlockStateCollectibleIdIter do
			local collectibleData = ZO_COLLECTIBLE_DATA_MANAGER:GetCollectibleDataById(id)
			if collectibleData and (collectibleData:IsHouseBank() and not collectibleData:IsFurnitureVault()) then
				Bankir.Data.onBanksUpdated()
			end
		end
	end)
	EVENT_MANAGER:RegisterForEvent(Bankir.name, EVENT_COLLECTIBLE_UPDATED, function(eventCode, id)
		local collectibleData = ZO_COLLECTIBLE_DATA_MANAGER:GetCollectibleDataById(id)
		if collectibleData and (collectibleData:IsHouseBank() and not collectibleData:IsFurnitureVault()) then
			Bankir.Data.onBanksUpdated()
		end
	end)
end

EVENT_MANAGER:RegisterForEvent(Bankir.name, EVENT_ADD_ON_LOADED, onAddOnLoaded)
