Bankir = Bankir or {}

local name = "Bankir"
local version = "2.9.2"
local author = "vexaiv"

local function debugPrint(message)
	d(name .. ": " .. message)
end

local d = debugPrint --override built-in d(...)

local queue
local totals
local requiredForQuests
local reprocessNeeded

local function getRuleForItem(itemLink, bagIdAlias, itemQuality, itemStackSize)
	local itemType, specializedItemType, itemId = Bankir.Functions.redefineItemTypes(itemLink)
	local rule, ruleDefId
	
	ruleDefId = itemLink
	
	-- byItemId is the highest priority, next bySpecializedItemType, and then byItemType
	rule = Bankir.Functions.getEffectiveRule(itemId, "itemId", bagIdAlias, itemQuality, itemStackSize)
	if rule.push ~= 0 or rule.pull ~= 0 then
		ruleDefId = itemId
	-- for specializedItemType at first check if itemId is not a child of some specializedItemType.
	-- In case if it's a child, it would mean that the parent specializedItemType has rules but there's
	-- no rule set for this specific child itemId. So, that specific itemId is set to "Do nothing" intentionally by player,
	-- and in this case we shouldn't proceed. Parent type rule shouldn't affect specific children id rules.
	elseif not Bankir.Data.isChildOf(itemId, "itemId", specializedItemType, "specializedItemType") then
		rule = Bankir.Functions.getEffectiveRule(specializedItemType, "specializedItemType", bagIdAlias, itemQuality, itemStackSize)
		if rule.push ~= 0 or rule.pull ~= 0 then
			ruleDefId = specializedItemType
		-- for itemType do the same kind of child/parent check as for specializedItemType
		elseif not Bankir.Data.isChildOf(itemId, "itemId", itemType, "itemType") then
			rule = Bankir.Functions.getEffectiveRule(itemType, "itemType", bagIdAlias, itemQuality, itemStackSize)
			if rule.push ~= 0 or rule.pull ~= 0 then
				ruleDefId = itemType
			end
		end
	end
	
	return rule, ruleDefId
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
			return lastSlot + 1
		end
	else
		-- other bags simply have slots from 0 up to GetBagSize-1
		for slotId = 0, GetBagSize(bagId) - 1 do
			local size, _ = GetSlotStackSize(bagId, slotId)
			if size == 0 then
				return slotId
			end
		end
	end
end

local function getTargetSlot(bagId, itemLink, except)
	for slotId in ZO_IterateBagSlots(bagId) do
		if slotId ~= except then
			local itemLinkInSlot = GetItemLink(bagId, slotId)
			local stack, maxStack = GetSlotStackSize(bagId, slotId)
			if Bankir.Functions.isEqualItemLink(itemLink, itemLinkInSlot) then
				if stack == 0 or stack < maxStack then
					return slotId
				end
			end
		end
	end
	--no slots of same item or they are full, find free slot
	return getEmptySlot(bagId)
end

local function countSameItemsInBag(bagId, itemLink, totalsId, neededQualities)
	local count = 0
	for slotId in ZO_IterateBagSlots(bagId) do
		repeat
			local itemLinkInSlot = GetItemLink(bagId, slotId)
			if not itemLinkInSlot then break end
			if neededQualities then
				-- don't count if quality rule is set and this item is not needed quality
				local displayQuality = GetItemLinkDisplayQuality(itemLinkInSlot)
				if not Bankir.Functions.isInArray(neededQualities, displayQuality) then
					break
				end
			end
			-- special case for armor/weapon to count totals of all intricate light armor
			-- as same item, all companion shields as same item and so on
			if totalsId ~= Bankir.Functions.getNormalizedLink(itemLink) then
				local itemType, specializedItemType, itemId = Bankir.Functions.redefineItemTypes(itemLinkInSlot)
				if itemId ~= totalsId and specializedItemType ~= totalsId and itemType ~= totalsId then
					break
				end
			elseif not Bankir.Functions.isEqualItemLink(itemLinkInSlot, itemLink) then
				break
			end
			local stack, maxStack = GetSlotStackSize(bagId, slotId)
			count = count + stack
		until true
	end
	return count
end

local function updateTotalItemsInBag(bagId, itemLink, totalsId, neededQualities)
	local count = countSameItemsInBag(bagId, itemLink, totalsId, neededQualities)
	if IsESOPlusSubscriber() then
		if bagId == BAG_BANK then
			count = count + countSameItemsInBag(BAG_SUBSCRIBER_BANK, itemLink, totalsId, neededQualities)
		elseif bagId == BAG_SUBSCRIBER_BANK then
			count = count + countSameItemsInBag(BAG_BANK, itemLink, totalsId, neededQualities)
			bagId = BAG_BANK
		end
	end
	if bagId ~= BAG_BACKPACK then bagId = BAG_BANK end
	totals[bagId][totalsId] = count
end

local function getTotalItemsInBag(bagId, totalsId)
	if bagId ~= BAG_BACKPACK then bagId = BAG_BANK end
	return totals[bagId][totalsId]
end

local function updateTotals(itemLink, totalsId, bagId, movedCount, maxStackSize)
	if bagId ~= BAG_BACKPACK then bagId = BAG_BANK end
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
	if Bankir.savedVarsProfile[bagId].currency then
		for currencyType, rules in pairs(Bankir.savedVarsProfile[bagId].currency) do
			local amount = GetCarriedCurrencyAmount(currencyType) - rules.amount
			if amount > 0 and rules.push then
				printToChat(ZO_Currency_GetPlatformFormattedCurrencyIcon(currencyType), amount, BAG_BANK)
				DepositCurrencyIntoBank(currencyType, amount)
			elseif amount < 0 and rules.pull then
				amount = amount * -1
				printToChat(ZO_Currency_GetPlatformFormattedCurrencyIcon(currencyType), amount, BAG_BACKPACK)
				WithdrawCurrencyFromBank(currencyType, amount)
			end
		end
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
		    and not Bankir.savedVarsCommon.moveLockedItems then break end
		    if targetBagId == BAG_GUILDBANK
			and IsItemBound(sourceBagId, slotId) then break end
			
			local itemLink = GetItemLink(sourceBagId, slotId)
			
			if sourceBagId == BAG_BACKPACK
			and GetItemLinkBindType(itemLink) == BIND_TYPE_ON_PICKUP_BACKPACK then break end
			
			local stackSize, maxStackSize = GetSlotStackSize(sourceBagId, slotId)
			local itemQuality = GetItemLinkDisplayQuality(itemLink)
			
			local rule, ruleDefId =
				getRuleForItem(itemLink, bankBagAlias, itemQuality, maxStackSize)
			
			local pullForQuests = 0
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
			
			if rule.push == 0 and rule.pull == 0 and pullForQuests == 0 then break end
			
			if (targetBagId ~= BAG_BACKPACK and rule.push == 0) --target is bank but nothing to push
			or (sourceBagId ~= BAG_BACKPACK and rule.pull == 0 and pullForQuests == 0) --source is bank but nothing to pull
			then break end
			
			local totalsId = Bankir.Functions.getNormalizedLink(itemLink)
			-- special case for armor/weapon to count totals of all intricate light armor
			-- as same item, all companion shields as same item and so on
			local itemType = GetItemLinkItemType(itemLink)
			if itemType == ITEMTYPE_ARMOR or itemType == ITEMTYPE_WEAPON then
				totalsId = ruleDefId
			end
			
			--update how many of the item is already in target bag
			if not getTotalItemsInBag(targetBagId, totalsId) or not getTotalItemsInBag(sourceBagId, totalsId) then
				updateTotalItemsInBag(targetBagId, itemLink, totalsId, neededQualities)
				updateTotalItemsInBag(sourceBagId, itemLink, totalsId, neededQualities)
			end
			
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
			
			if getTotalItemsInBag(targetBagId, totalsId) >= targetMax then break end
			
			--finally, if all good, add to the queue
			--d("add to queue " .. itemLink .. " as " .. totalsId .. " sourceBagId = " .. sourceBagId .. " sourceSlotId = " .. slotId .. " targetBagId = " .. targetBagId .. " targetMax = " .. targetMax .. " sourceMin = " .. toPull)
			table.insert(queue.items, { sourceBagId = sourceBagId, sourceSlotId = slotId,
				targetBagId = targetBagId, itemLink = itemLink,
				targetMax = targetMax, sourceMin = rule.pull,
				totalsId = totalsId, maxStackSize = maxStackSize })
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
			if Bankir.savedVarsCommon.showOperationFailMessages then
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
	else
		local targetSlotId = getTargetSlot(targetBagId, itemLink)
		
		-- try ESO+ bank slots
		if not targetSlotId and targetBagId == BAG_BANK and IsESOPlusSubscriber() then
			targetSlotId = getTargetSlot(BAG_SUBSCRIBER_BANK, itemLink)
			if targetSlotId then
				targetBagId = BAG_SUBSCRIBER_BANK
			end
		end
		
		if not targetSlotId then
			if Bankir.savedVarsCommon.showOperationFailMessages then
				d(zo_strformat(GetString(BANKIR_CHAT_NO_FREE_SPACE), Bankir.Functions.getBagName(targetBagId), itemLink))
			end
			processQueue()
			return
		end
		
		queue.items[queue.index].targetSlotId = targetSlotId
		
		local targetStackSize, _ = GetSlotStackSize(targetBagId, targetSlotId)
		--d("targetSlot " .. targetSlotId .. " in " .. Bankir.Functions.getBagName(targetBagId) .. " stack size: " .. targetStackSize)
		
		if sourceStackSizeFinal > maxStackSize - targetStackSize then
			--d("sourceStackSize (" .. sourceStackSizeFinal .. ") doesn't fit into the target slot, will be maxStackSize(".. maxStackSize .. ") - targetStackSize(".. targetStackSize .. ")")
			sourceStackSizeFinal = maxStackSize - targetStackSize
		end
		
		if IsBankOpen() and sourceStackSize ~= sourceStackSizeFinal then
			--to step back and re-process what remains in this slot in next iteration
			reprocessNeeded = true
		end
		
		-- special temporary transfer for guild bank. We move the whole stack to backpack where it'll be split if needed.
		-- it only works if player has WITHDRAW permission. Without permission this section is skipped and regular moveItem is called
		if IsGuildBankOpen() and DoesPlayerHaveGuildPermission(GetSelectedGuildBankId(), GUILD_PERMISSION_BANK_WITHDRAW) then
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
					if Bankir.savedVarsCommon.showOperationFailMessages then
						d(zo_strformat(GetString(BANKIR_CHAT_NO_FREE_SPACE), Bankir.Functions.getBagName(BAG_BACKPACK), itemLink))
					end
					processQueue()
				end
				
				if targetStackSize == 0 and sourceBagId == BAG_BACKPACK then
					-- if target in guild bank is empty, we skip the step where we pull slot from guild bank and go right to state 2
					queue.items[queue.index].tempState = 2
					queue.items[queue.index].tempSlotId = backpackEmptySlotId
					--d("move " .. sourceStackSizeFinal .. " of " .. itemLink .. " from " .. Bankir.Functions.getBagName(BAG_BACKPACK) .. " source slot " .. sourceSlotId .. " to " .. Bankir.Functions.getBagName(BAG_BACKPACK) .. " empty slot " .. backpackEmptySlotId)
					moveItem(itemLink, BAG_BACKPACK, sourceSlotId, BAG_BACKPACK, backpackEmptySlotId, sourceStackSizeFinal, maxStack)
				else
					queue.items[queue.index].tempState = 0
					queue.items[queue.index].tempSlotId = backpackEmptySlotId
					queue.items[queue.index].tempAmount = sourceStackSizeFinal
					--d("move " .. stack .. " of " .. itemLink .. " from " .. Bankir.Functions.getBagName(fromBag) .. " slot " .. fromSlot .. " to " .. Bankir.Functions.getBagName(BAG_BACKPACK) .. " empty slot " .. backpackEmptySlotId)
					moveItem(itemLink, fromBag, fromSlot, BAG_BACKPACK, backpackEmptySlotId, stack, maxStack)
				end
				return
			end
		end
		
		moveItem(itemLink, sourceBagId, sourceSlotId, targetBagId, targetSlotId, sourceStackSizeFinal, maxStackSize)
	end
end

local function onSlotChanged(bagId, slotId, countChange, byLocalPlayer)
	--d("onSlotChanged(bagId .. " .. bagId .. ", slotId " .. slotId .. ", countChange " .. countChange)
	if queue.index > #queue.items then
		onQueueProcessed()
		return
	end
	
	if not byLocalPlayer and bagId == BAG_GUILDBANK then
		d("|cFF0000Someone other interacted with the guild bank. Results may be wrong.|r")
		return
	end
	
	local itemInQueue = queue.items[queue.index]
	local itemLink = itemInQueue.itemLink -- GetItemLink(bagId, slotId)
	
	if itemInQueue and itemLink then
		local totalsId = itemInQueue.totalsId
		local stack, maxStack = GetSlotStackSize(bagId, slotId)
		
		if countChange > 0 and bagId == BAG_GUILDBANK then
			-- giuld bank only returns countChange as 1 or -1, and moves whole stacks
			countChange = stack * countChange
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
		
		-- For 'no temp state' case or states about tempBAG<=>GUILDBANK, not BAG<=>BAG
		if countChange > 0
		and (not state or state == 1 or state == 2 or state == 5 or state == 6)
		then
			printToChat(itemLink, countChange, bagId)
			
			local otherBag = bagId == BAG_BACKPACK and BAG_BANK or BAG_BACKPACK
			updateTotals(itemLink, itemInQueue.totalsId, bagId, countChange, itemInQueue.maxStackSize)
			updateTotals(itemLink, itemInQueue.totalsId, otherBag, -countChange, itemInQueue.maxStackSize)
		end
		
		if not state then
			if countChange > 0 then processQueue() end
			return
		end
		
		if state == 2 then
			if itemInQueue.targetBagId == BAG_GUILDBANK then
				--d("~= bagId. now move inside " .. Bankir.Functions.getBagName(BAG_BACKPACK) .. " from slot " .. itemInQueue.sourceSlotId .. " to temp slot " .. itemInQueue.tempSlotId .. " move  tempAmount: " .. itemInQueue.tempAmount)
				moveItem(itemLink, BAG_BACKPACK, itemInQueue.sourceSlotId, BAG_BACKPACK, itemInQueue.tempSlotId, itemInQueue.tempAmount, maxStack)
			else
				if itemInQueue.targetSlotId == itemInQueue.tempSlotId then
					local newTargetSlotId = getEmptySlot(BAG_BACKPACK)
					itemInQueue.targetSlotId = newTargetSlotId
				end
				--d("==bagId. now move inside " .. Bankir.Functions.getBagName(BAG_BACKPACK) .. " from temp slot " .. itemInQueue.tempSlotId .. " to target slot " .. itemInQueue.targetSlotId .. " move tempAmount: " .. itemInQueue.tempAmount)
				moveItem(itemLink, BAG_BACKPACK, itemInQueue.tempSlotId, BAG_BACKPACK, itemInQueue.targetSlotId, itemInQueue.tempAmount, maxStack)
			end
		elseif state == 4 then
			if itemInQueue.targetBagId == BAG_GUILDBANK then
				local newTargetSlotId = getEmptySlot(itemInQueue.targetBagId)
				itemInQueue.targetSlotId = newTargetSlotId
				--d("~= bagId. now move back to " .. Bankir.Functions.getBagName(itemInQueue.targetBagId) .. " from temp slot " .. itemInQueue.tempSlotId  .. " to new target slot " .. newTargetSlotId .. " move stack amount: " .. stack)
				moveItem(itemInQueue.itemLink, BAG_BACKPACK, itemInQueue.tempSlotId, itemInQueue.targetBagId, newTargetSlotId, stack, maxStack)
			else
				local stack, maxStack = GetSlotStackSize(BAG_BACKPACK, itemInQueue.tempSlotId)
				--d("stack remains in temp slot " .. itemInQueue.tempSlotId .. ": " .. stack)
				if stack > 0 then
					reprocessNeeded = true
					itemInQueue.sourceSlotId = getEmptySlot(itemInQueue.sourceBagId)
					--d("now move back to " .. Bankir.Functions.getBagName(itemInQueue.sourceBagId) .. " from slot " .. itemInQueue.tempSlotId  .. " to new source slot " .. itemInQueue.sourceSlotId .. " move stack amount: " .. stack)
					moveItem(itemInQueue.itemLink, BAG_BACKPACK, itemInQueue.tempSlotId, itemInQueue.sourceBagId, itemInQueue.sourceSlotId, stack, maxStack)
				else
					itemInQueue.tempState = nil
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
			processQueue()
		end
	end
end

local function onBankDepositNotAllowed()
	if queue.index > #queue.items then
		onQueueProcessed()
		return
	end
	
	if Bankir.savedVarsCommon.showOperationFailMessages then
		local itemInQueue = queue.items[queue.index]
		if itemInQueue then
			d(itemInQueue.itemLink .. " " .. GetString(SI_INVENTORY_ERROR_BANK_DEPOSIT_NOT_ALLOWED))
		end
	end
	
	processQueue()
end

local function onBankOpen(bagId)
	--d("opened " .. Bankir.Functions.getBagName(bagId))
	--local startTimeMs = GetGameTimeMilliseconds()
	
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
	
	--d("Queue building took " .. GetGameTimeMilliseconds() - startTimeMs .. " ms")
	
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
	
	processQueue()
end

local function onBankClose()
	--d("Bank closed")
	onQueueProcessed()
end

local function upgradeVars()
	if BankirSavedVariables then
		if BankirSavedVariables.Default then
			-- Profiles moved to higher level, same level as Default, in 2.7
			if BankirSavedVariables.Default.Profiles then
				BankirSavedVariables.Profiles = {}
				BankirSavedVariables.Common = {}
				for profileName, profileTable in pairs(BankirSavedVariables.Default.Profiles) do
					BankirSavedVariables.Profiles[profileName] = {}
					for settingName, settingValue in pairs(profileTable) do
						if settingName == "rules" then
							for bagId, bagRules in pairs(settingValue) do
								for typeId, typeRules in pairs(bagRules) do
									for itemId, itemRules in pairs(typeRules) do
										if itemId == "RepairKit44879" then
											BankirSavedVariables.Default.Profiles[profileName]["rules"][bagId]["byItemId"][44879] = itemRules
											BankirSavedVariables.Default.Profiles[profileName]["rules"][bagId][typeId][itemId] = nil
										end
									end
								end
								BankirSavedVariables.Profiles[profileName][bagId] = bagRules
							end
						elseif settingName == "countAnyIdOfSameType" then
							BankirSavedVariables.Default.Profiles[profileName][settingName] = nil
						elseif settingName == "showDepositNotAllowedMessage" then
							BankirSavedVariables.Common["showOperationFailMessages"] = settingValue
							BankirSavedVariables.Default.Profiles[profileName][settingName] = nil
						else
							BankirSavedVariables.Common[settingName] = settingValue
						end
					end
				end
				BankirSavedVariables.Default.Profiles = nil
				BankirSavedVariables.Common.bankSlidersMaxValue = 50
				BankirSavedVariables.Common.currencySlidersMaxValue = 100000
			end
		end
		if BankirSavedVariables.Common then
			if BankirSavedVariables.Common.version ~= version then
				for profileName, profileTable in pairs(BankirSavedVariables.Profiles) do
					for bagId, bagRules in pairs(profileTable) do
						local newTypeIds = {}
						for typeId, typeRules in pairs(bagRules) do
							-- "byType" renamed to "type" in 2.9
							if typeId == "byItemType" then
								newTypeIds.itemType = Bankir.Functions.copyData(typeRules)
							elseif typeId == "bySpecializedItemType" then
								newTypeIds.specializedItemType = Bankir.Functions.copyData(typeRules)
							elseif typeId == "byItemId" then
								newTypeIds.itemId = Bankir.Functions.copyData(typeRules)
							end
						end
						BankirSavedVariables.Profiles[profileName][bagId].itemType = newTypeIds.itemType
						BankirSavedVariables.Profiles[profileName][bagId].byItemType = nil
						BankirSavedVariables.Profiles[profileName][bagId].specializedItemType = newTypeIds.specializedItemType
						BankirSavedVariables.Profiles[profileName][bagId].bySpecializedItemType = nil
						BankirSavedVariables.Profiles[profileName][bagId].itemId = newTypeIds.itemId
						BankirSavedVariables.Profiles[profileName][bagId].byItemId = nil
					end
				end
				for profileName, profileTable in pairs(BankirSavedVariables.Profiles) do
					for bagId, bagRules in pairs(profileTable) do
						for typeId, typeRules in pairs(bagRules) do
							for itemId, itemRules in pairs(typeRules) do
								if type(itemRules) == "table" and itemRules.quality and type(itemRules.quality) == "number" then
									-- quality converted to table in 2.8, so 1=>{1,2,3,4,5}. 3=>{3,4,5}
									local newQuality = {}
									for i = itemRules.quality, 5 do
										table.insert(newQuality, i)
									end
									itemRules.quality = newQuality
								end
								-- moved 'StyleMaterialRacial/Other' from itemId to specializedItemType in 2.8
								if typeId == "itemType" then
									if itemId == "StyleMaterialRacial" then
										BankirSavedVariables.Profiles[profileName][bagId].specializedItemType["StyleMaterialRacial"] = Bankir.Functions.copyData(itemRules)
										BankirSavedVariables.Profiles[profileName][bagId].itemId[itemId] = nil
									elseif itemId == "StyleMaterialOther" then
										BankirSavedVariables.Profiles[profileName][bagId].specializedItemType["StyleMaterialOther"] = Bankir.Functions.copyData(itemRules)
										BankirSavedVariables.Profiles[profileName][bagId].itemId[itemId] = nil
									end
								elseif typeId == "specializedItemType" then
									-- no more Both type in saved vars
									if string.find(itemId, "Both") then
										BankirSavedVariables.Profiles[profileName][bagId][typeId][itemId] = nil
									-- change type string for researchable equipment
									elseif string.find(itemId, "Research") then
										local name = string.match(itemId, "^(%D+)") -- get starting word
										if name == "ResearchAll" then
											BankirSavedVariables.Profiles[profileName][bagId].specializedItemType["TraitUnknownAll"] = Bankir.Functions.copyData(itemRules)
											BankirSavedVariables.Profiles[profileName][bagId][typeId][itemId] = nil
										elseif name == "ResearchOthersAll" then
											BankirSavedVariables.Profiles[profileName][bagId].specializedItemType["TraitUnknownOthersAll"] = Bankir.Functions.copyData(itemRules)
											BankirSavedVariables.Profiles[profileName][bagId][typeId][itemId] = nil
										else
											local id = string.match(itemId, "(%d+)$") -- get ending number
											if name == "ResearchOthers" then
												BankirSavedVariables.Profiles[profileName][bagId].specializedItemType["TraitUnknownOthers" .. id] = Bankir.Functions.copyData(itemRules)
												BankirSavedVariables.Profiles[profileName][bagId][typeId][itemId] = nil
											else
												BankirSavedVariables.Profiles[profileName][bagId].specializedItemType["TraitUnknown" .. id] = Bankir.Functions.copyData(itemRules)
												BankirSavedVariables.Profiles[profileName][bagId][typeId][itemId] = nil
											end
										end
									end
								elseif typeId == "itemId" then
									-- move unknown recipes from itemId to specializedItemType
									if string.find(itemId, "RecipeUnknown") then
										local id = string.match(itemId, "(%d+)$") -- get ending number
										if id == SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_BOOK
										or id == SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_CHAPTER
										or id == SPECIALIZED_ITEMTYPE_COLLECTIBLE_STYLE_PAGE then
											BankirSavedVariables.Profiles[profileName][bagId].specializedItemType["MotifUnknown" .. id] = Bankir.Functions.copyData(itemRules)
										else
											BankirSavedVariables.Profiles[profileName][bagId].specializedItemType["RecipeUnknown" .. id] = Bankir.Functions.copyData(itemRules)
										end
										BankirSavedVariables.Profiles[profileName][bagId][typeId][itemId] = nil
									end
								end
							end
						end
					end
				end
				-- no Integrations and research chars list is on it's own since 2.9
				if BankirSavedVariables.Server[GetWorldName()].Integrations then
					BankirSavedVariables.Server[GetWorldName()].ResearchCharactersList = Bankir.Functions.copyData(
					BankirSavedVariables.Server[GetWorldName()].Integrations.LCK.CharactersList)
					BankirSavedVariables.Server[GetWorldName()].Integrations = nil
				end
			end
		end
	end
end

local function onAddOnLoaded(event, addonName)
	if addonName ~= name then return end
	EVENT_MANAGER:UnregisterForEvent(name, EVENT_ADD_ON_LOADED)
	
	upgradeVars()
	
	Bankir.Data.getBankBags()
	Bankir.Data.getCharactersList()
	
	local defaultProfileName = "Default"
	local profiles = Bankir.Profiles.getProfilesNames()
	if #profiles > 0 then
		defaultProfileName = profiles[1]
	end
	Bankir.savedVarsCharacter = ZO_SavedVars:NewCharacterIdSettings("BankirSavedVariables", 2, nil, { profile = defaultProfileName })
	Bankir.Profiles.initProfile(Bankir.savedVarsCharacter.profile)
	
	BankirSavedVariables.Common = BankirSavedVariables.Common or Bankir.Data.getDefaultCommonSettings()
	Bankir.savedVarsCommon = BankirSavedVariables.Common
	
	BankirSavedVariables.Server = BankirSavedVariables.Server or {}
	BankirSavedVariables.Server[GetWorldName()] = BankirSavedVariables.Server[GetWorldName()] or Bankir.Data.getDefaultServerSettings()
	Bankir.savedVarsServer = BankirSavedVariables.Server[GetWorldName()]
	
	if BankirSavedVariables.Common.version ~= version then
		for profile in pairs(BankirSavedVariables.Profiles) do
			Bankir.Functions.mergeData(BankirSavedVariables.Profiles[profile], Bankir.Data.getDefaultProfileSettings())
		end
		Bankir.Functions.mergeData(BankirSavedVariables.Common, Bankir.Data.getDefaultCommonSettings())
		Bankir.Functions.mergeData(BankirSavedVariables.Server[GetWorldName()], Bankir.Data.getDefaultServerSettings())
		BankirSavedVariables.Common.version = version
	end
	
	Bankir.Data.cleanUpResearchCharactersList()
	Bankir.createSettingsMenu(name, author, version)
	
	EVENT_MANAGER:RegisterForEvent(name, EVENT_OPEN_BANK, function(eventCode, bankBag)
		onBankOpen(bankBag)
	end)
	EVENT_MANAGER:RegisterForEvent(name, EVENT_GUILD_BANK_ITEMS_READY, function()
		onBankOpen(BAG_GUILDBANK)
	end)
	EVENT_MANAGER:RegisterForEvent(name, EVENT_CLOSE_BANK, onBankClose)
	EVENT_MANAGER:RegisterForEvent(name, EVENT_CLOSE_GUILD_BANK, onBankClose)
end

EVENT_MANAGER:RegisterForEvent(name, EVENT_ADD_ON_LOADED, onAddOnLoaded)
