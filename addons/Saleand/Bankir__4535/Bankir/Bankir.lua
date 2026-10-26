Bankir = Bankir or {}

local name = "Bankir"
local version = "2.7.1"
local author = "vexaiv"

local function debugPrint(message)
	d(name .. ": " .. message)
end

local d = debugPrint --override built-in d(...)

local queue
local localCache
local lastCacheUpdateData
local requiredForQuests
local reprocessNeeded

local function getRuleForItem(itemLink, bagIdAlias)
	local toPush, toPull, pullInStacks, ruleDefId, qualityNeeded
	local itemType, specializedItemType, itemId = Bankir.Functions.redefineItemTypes(itemLink)
	
	ruleDefId = itemLink
	
	-- byItemId is the highest priority, next bySpecializedItemType, and then byItemType
	local rule = Bankir.savedVarsProfile[bagIdAlias].byItemId[itemId]
	if rule then
		toPush = rule.push
		toPull = rule.pull
		pullInStacks = rule.pullInStacks
		ruleDefId = itemId
	end
	-- for specializedItemType at first check if itemId is not a child of some specializedItemType.
	-- In case if it's a child, it would mean that the parent specializedItemType has rules but there's
	-- no rule set for this specific child itemId. So, that specific itemId is set to "Do nothing" intentionally by player,
	-- and in this case we shouldn't proceed. Parent type rule shouldn't affect specific children id rules.
	if not rule
	and not Bankir.Data.isChildOf(itemId, "itemId", specializedItemType, "specializedItemType") then
		rule = Bankir.savedVarsProfile[bagIdAlias].bySpecializedItemType[specializedItemType]
		if rule then
			toPush = rule.push
			toPull = rule.pull
			pullInStacks = rule.pullInStacks
			ruleDefId = specializedItemType
		end
	end
	-- for itemType do the same kind of child/parent check as for specializedItemType
	if not rule
	and not Bankir.Data.isChildOf(itemId, "itemId", itemType, "itemType")
	and not Bankir.Data.isChildOf(specializedItemType, "specializedItemType", itemType, "itemType") then
		rule = Bankir.savedVarsProfile[bagIdAlias].byItemType[itemType]
		if rule then
			toPush = rule.push
			toPull = rule.pull
			pullInStacks = rule.pullInStacks
			ruleDefId = itemType
		end
	end
	
	if rule and rule.quality then
		local displayQuality = GetItemLinkDisplayQuality(itemLink)
		if displayQuality < rule.quality then
			toPush = nil
			toPull = nil
			pullInStacks = false
			ruleDefId = itemLink
		end
		qualityNeeded = rule.quality
	end
	
	return toPush, toPull, pullInStacks, ruleDefId, qualityNeeded
end

local function getSlotData(bagId, slotId)
	--first search in local cache
	if localCache and localCache[bagId].slots[slotId] then
		return localCache[bagId].slots[slotId]
	--then do server data request and update local cache
	else
		local itemLink = GetItemLink(bagId, slotId)
		local size, maxSize = GetSlotStackSize(bagId, slotId)
		localCache[bagId].slots[slotId] = { itemLink = itemLink, stackSize = size, maxStackSize = maxSize }
		return localCache[bagId].slots[slotId]
	end
end

local function getSlotStackSizeLocal(bagId, slotId)
	local data = getSlotData(bagId, slotId)
	return data.stackSize, data.maxStackSize
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
			local size, _ = getSlotStackSizeLocal(bagId, slotId)
			if size == 0 then
				return slotId
			end
		end
	end
end

local function getTargetSlot(bagId, itemLink, except)
	for slotId in ZO_IterateBagSlots(bagId) do
		if slotId ~= except then
			local data = getSlotData(bagId, slotId)
			if data then
				if Bankir.Functions.isEqualItemLink(data.itemLink, itemLink)
				and data.stackSize < data.maxStackSize then
					return slotId
				end
			end
		end
	end
	--no slots of same item or they are full, find free slot
	return getEmptySlot(bagId)
end

local function initCacheForBag(bagId)
	localCache = localCache or {}
	if not localCache[bagId] then
		localCache[bagId] = { slots = {}, totals = {} }
		if bagId == BAG_BANK and IsESOPlusSubscriber() then
			localCache[BAG_SUBSCRIBER_BANK] = { slots = {} }
		end
	end
end

local function updateTotalItemsInBag(bagId, itemLink, totalsId, minQuality)
	local count = 0
	for slotId in ZO_IterateBagSlots(bagId) do
		repeat
			local itemLinkInSlot = GetItemLink(bagId, slotId)
			if not itemLinkInSlot then break end
			if minQuality then
				-- don't count if quality rule is set and this item is lower quality
				local displayQuality = GetItemLinkDisplayQuality(itemLinkInSlot)
				if displayQuality < minQuality then break end
			end
			-- special case for armor/weapon to count totals of all intricate light armor
			-- as same item, all companion shields as same item and so on
			if itemLink ~= totalsId then
				local itemType, specializedItemType, itemId = Bankir.Functions.redefineItemTypes(itemLinkInSlot)
				if itemId ~= totalsId and specializedItemType ~= totalsId and itemType ~= totalsId then
					break
				end
			elseif not Bankir.Functions.isEqualItemLink(itemLinkInSlot, itemLink) then
				break
			end
			local stackSize, maxStackSize = getSlotStackSizeLocal(bagId, slotId)
			count = count + stackSize
		until true
	end
	localCache[bagId].totals[totalsId] = count
end

local function updateLocalCache(itemLink, totalsId, sourceBagId, sourceSlotId, targetBagId, targetSlotId, movedCount, maxStackSize)
	lastCacheUpdateData = { itemLink = itemLink, totalsId = totalsId, sourceBagId = sourceBagId, sourceSlotId = sourceSlotId,
		targetBagId = targetBagId, targetSlotId = targetSlotId, movedCount = movedCount, maxStackSize = maxStackSize }
	
	if localCache[sourceBagId] then
		if not localCache[sourceBagId].slots[sourceSlotId] then
			localCache[sourceBagId].slots[sourceSlotId] = { itemLink = itemLink, stackSize = 0, maxStackSize = maxStackSize }
		end
		localCache[sourceBagId].slots[sourceSlotId].itemLink = itemLink
		localCache[sourceBagId].slots[sourceSlotId].stackSize = localCache[sourceBagId].slots[sourceSlotId].stackSize - movedCount
		localCache[sourceBagId].slots[sourceSlotId].maxStackSize = maxStackSize
		if localCache[sourceBagId].slots[sourceSlotId].stackSize <= 0 then
			localCache[sourceBagId].slots[sourceSlotId] = nil
		end
		--for totals use BAG_BANK for both BAG_BANK and BAG_SUBSCRIBER_BANK
		if sourceBagId == BAG_SUBSCRIBER_BANK then sourceBagId = BAG_BANK end
		localCache[sourceBagId].totals[totalsId] = localCache[sourceBagId].totals[totalsId] - movedCount
	end
	if localCache[targetBagId] then
		if not localCache[targetBagId].slots[targetSlotId] then
			localCache[targetBagId].slots[targetSlotId] = { itemLink = itemLink, stackSize = movedCount, maxStackSize = maxStackSize }
		else
			localCache[targetBagId].slots[targetSlotId].itemLink = itemLink
			localCache[targetBagId].slots[targetSlotId].stackSize = localCache[targetBagId].slots[targetSlotId].stackSize + movedCount
			localCache[targetBagId].slots[targetSlotId].maxStackSize = maxStackSize
		end
		--for totals use BAG_BANK for both BAG_BANK and BAG_SUBSCRIBER_BANK
		if targetBagId == BAG_SUBSCRIBER_BANK then targetBagId = BAG_BANK end
		localCache[targetBagId].totals[totalsId] = localCache[targetBagId].totals[totalsId] + movedCount
	end
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
			
			local toPush, toPull, pullInStacks, ruleDefId, minQuality = getRuleForItem(itemLink, bankBagAlias)
			toPush = toPush or 0
			toPull = toPull or 0
			
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
			
			if (targetBagId ~= BAG_BACKPACK and toPush == 0) --target is bank but nothing to push
			or (sourceBagId ~= BAG_BACKPACK and toPull == 0 and pullForQuests == 0) --source is bank but nothing to pull
			then break end
			
			if toPush == 0 and toPull == 0 and pullForQuests == 0 then break end
			
			local totalsId = itemLink
			-- special case for armor/weapon to count totals of all intricate light armor
			-- as same item, all companion shields as same item and so on
			local itemType = GetItemLinkItemType(itemLink)
			if itemType == ITEMTYPE_ARMOR or itemType == ITEMTYPE_WEAPON then
				totalsId = ruleDefId
			end
			
			--update how many of the item is already in target bag
			if not localCache[targetBagId].totals[totalsId] or not localCache[sourceBagId].totals[totalsId] then
				updateTotalItemsInBag(targetBagId, itemLink, totalsId, minQuality)
				updateTotalItemsInBag(sourceBagId, itemLink, totalsId, minQuality)
			end
			
			local stackSize, maxStackSize = getSlotStackSizeLocal(sourceBagId, slotId)
			
			if pullInStacks then
				toPull = toPull * maxStackSize
			end
			toPull = toPull + pullForQuests
			
			local targetMax
			if sourceBagId == BAG_BACKPACK then
				targetMax = toPush * maxStackSize
			else
				targetMax = toPull
			end
			
			if localCache[targetBagId].totals[totalsId] >= targetMax then break end
			
			--finally, if all good, add to the queue
			--d("add to queue " .. itemLink .. " as " .. totalsId .. " sourceBagId = " .. sourceBagId .. " sourceSlotId = " .. slotId .. " targetBagId = " .. targetBagId .. " targetMax = " .. targetMax .. " sourceMin = " .. toPull)
			table.insert(queue.items, { sourceBagId = sourceBagId, sourceSlotId = slotId,
				targetBagId = targetBagId, itemLink = itemLink, targetMax = targetMax, sourceMin = toPull, totalsId = totalsId })
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
	localCache = nil
	requiredForQuests = nil
	EVENT_MANAGER:UnregisterForEvent(name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
	EVENT_MANAGER:UnregisterForEvent(name, EVENT_BANK_DEPOSIT_NOT_ALLOWED)
	EVENT_MANAGER:UnregisterForEvent(name, EVENT_GUILD_BANK_ITEM_ADDED)
	EVENT_MANAGER:UnregisterForEvent(name, EVENT_GUILD_BANK_ITEM_REMOVED)
end

local function moveItem(itemLink, totalsId, sourceBagId, sourceSlotId, targetBagId, targetSlotId, stackSize, maxStackSize)
	--d("moveItem from " .. Bankir.Functions.getBagName(sourceBagId) .. " slot " .. sourceSlotId .. " to " .. Bankir.Functions.getBagName(targetBagId) .. " slot " .. targetSlotId .. " stackSize " .. stackSize)
	--save local data
	updateLocalCache(itemLink, totalsId, sourceBagId, sourceSlotId, targetBagId, targetSlotId, stackSize, maxStackSize)
	
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
	
	local targetTotal = localCache[targetBagId].totals[totalsId]
	local sourceTotal = localCache[sourceBagId].totals[totalsId]
	
	local sourceStackSize, maxStackSize = getSlotStackSizeLocal(sourceBagId, sourceSlotId)
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
		
		if not targetSlotId then
			if Bankir.savedVarsCommon.showOperationFailMessages then
				d(zo_strformat(GetString(BANKIR_CHAT_NO_FREE_SPACE), Bankir.Functions.getBagName(targetBagId), itemLink))
			end
			processQueue()
			return
		end
		
		local targetStackSize, _ = getSlotStackSizeLocal(targetBagId, targetSlotId)
		
		if sourceStackSizeFinal > maxStackSize - targetStackSize then
			--d("sourceStackSize (" .. sourceStackSizeFinal .. ") doesn't fit into the target slot, will be maxStackSize(".. maxStackSize .. ") - targetStackSize(".. targetStackSize .. ")")
			sourceStackSizeFinal = maxStackSize - targetStackSize
		end
		
		if IsBankOpen() and sourceStackSize ~= sourceStackSizeFinal then
			--to step back and re-process what remains in this slot in next iteration
			reprocessNeeded = true
		-- special temporary transfer for guild bank. We move the whole stack to backpack where it'll be split if needed
		elseif IsGuildBankOpen() and DoesPlayerHaveGuildPermission(GetSelectedGuildBankId(), GUILD_PERMISSION_BANK_WITHDRAW) then
			local stack, maxStack, backpackEmptySlotId, fromBag, fromSlot, moveAmount
			if targetStackSize > 0 then
				if targetBagId == BAG_BACKPACK then
					--d("if targetStackSize > 0 in BAG")
					fromBag = sourceBagId
					fromSlot = sourceSlotId
				else
					--d("if targetStackSize > 0 in BANK")
					fromBag = targetBagId
					fromSlot = targetSlotId
				end
			elseif sourceStackSize ~= sourceStackSizeFinal then
				--d("if sourceStackSize ~= sourceStackSizeFinal")
				fromBag = sourceBagId
				fromSlot = sourceSlotId
			end
			if fromBag then -- need to split
				stack, maxStack = getSlotStackSizeLocal(fromBag, fromSlot)
				backpackEmptySlotId = getEmptySlot(BAG_BACKPACK)
				if backpackEmptySlotId then
					if fromBag == BAG_BACKPACK then
						queue.items[queue.index].tempSlotId = -1
						moveAmount = sourceStackSizeFinal
					else
						queue.items[queue.index].tempSlotId = backpackEmptySlotId
						queue.items[queue.index].tempAmount = sourceStackSizeFinal
						moveAmount = stack
					end
					--d("move " .. moveAmount .. " of " .. itemLink .. " from " .. Bankir.Functions.getBagName(fromBag) .. " slot " .. fromSlot .. " to " .. Bankir.Functions.getBagName(BAG_BACKPACK) .. " empty slot " .. backpackEmptySlotId)
					moveItem(itemLink, totalsId, fromBag, fromSlot, BAG_BACKPACK, backpackEmptySlotId, moveAmount, maxStack)
				else
					if Bankir.savedVarsCommon.showOperationFailMessages then
						d(zo_strformat(GetString(BANKIR_CHAT_NO_FREE_SPACE), Bankir.Functions.getBagName(BAG_BACKPACK), itemLink))
					end
					processQueue()
				end
				return
			end
		end
		
		moveItem(itemLink, totalsId, sourceBagId, sourceSlotId, targetBagId, targetSlotId, sourceStackSizeFinal, maxStackSize)
	end
end

local function onSlotChanged(bagId, slotId, countChange)
	--d("onSlotChanged(bagId .. " .. bagId .. ", slotId " .. slotId .. ", countChange " .. countChange)
	if queue.index > #queue.items then
		onQueueProcessed()
		return
	end
	
	local itemInQueue = queue.items[queue.index]
	local itemLink = itemInQueue.itemLink -- GetItemLink(bagId, slotId)
	
	if itemInQueue and itemLink and countChange > 0 then
		-- print on success
		printToChat(itemLink, countChange, bagId)
		
		local totalsId = itemInQueue.totalsId
		if itemInQueue.tempSlotId == slotId then
			if itemInQueue.targetBagId == bagId then
				local stack, maxStack = getSlotStackSizeLocal(bagId, slotId)
				local targetSlotId = getTargetSlot(bagId, itemLink, slotId)
				queue.items[queue.index].tempSlotId = nil
				--d("now move inside " .. Bankir.Functions.getBagName(BAG_BACKPACK) .. " from slot " .. slotId  .. " to slot " .. targetSlotId .. " move amount: " .. itemInQueue.tempAmount .. "/" .. maxStack)
				moveItem(itemLink, totalsId, BAG_BACKPACK, slotId, BAG_BACKPACK, targetSlotId, itemInQueue.tempAmount, maxStack)
				-- if something remains in this slot, move it back and reset queue index
				if itemInQueue.tempAmount ~= stack then
					stack = stack - itemInQueue.tempAmount
					--queue.index = queue.index - 1
					reprocessNeeded = true
					moveItem(itemLink, totalsId, bagId, slotId, itemInQueue.sourceBagId, itemInQueue.sourceSlotId, stack, maxStack)
				end
			else
				local stack, maxStack = getSlotStackSizeLocal(BAG_BACKPACK, slotId)
				queue.items[queue.index].tempSlotId = -1
				--d("now move inside " .. Bankir.Functions.getBagName(BAG_BACKPACK) .. " from slot " .. itemInQueue.sourceSlotId  .. " to slot " .. slotId .. " move amount: " .. itemInQueue.tempAmount .. "/" .. maxStack)
				moveItem(itemLink, totalsId, BAG_BACKPACK, itemInQueue.sourceSlotId, BAG_BACKPACK, slotId, itemInQueue.tempAmount, maxStack)
			end
			return
		elseif itemInQueue.tempSlotId == -1 then
			if itemInQueue.targetBagId ~= bagId then
				local targetSlotId = getEmptySlot(itemInQueue.targetBagId)
				local stack, maxStack = getSlotStackSizeLocal(bagId, slotId)
				queue.items[queue.index].tempSlotId = nil
				--d("now move back to " .. Bankir.Functions.getBagName(itemInQueue.targetBagId) .. " from slot " .. slotId  .. " to slot " .. targetSlotId .. " move amount: " .. stack .. "/" .. maxStack)
				moveItem(itemInQueue.itemLink, totalsId, BAG_BACKPACK, slotId, itemInQueue.targetBagId, targetSlotId, stack, maxStack)
				return
			end
		end
		-- proceed to next item in the queue
		processQueue()
	elseif countChange < 0 then
		-- we only need to know if an item moved FROM the source bag
		if localCache[bagId].slots[slotId] then
			for i = 1, #queue.items do
				local item = queue.items[i]
				if item.sourceBagId == bagId and item.sourceSlotId == slotId then
					local localStack = localCache[bagId].slots[slotId].stackSize
					local remoteStack = GetSlotStackSize(bagId, slotId)
					-- check if data is different from what we have in local cache, it means that someone else has moved the item
					if remoteStack < localStack then
						--d("!!! data for " .. itemLink .. " don't match. local: " .. localStack .. " remote: " .. remoteStack .. " change: ".. countChange)
						updateLocalCache(item.itemLink, item.totalsId, item.sourceBagId, item.sourceSlotId, nil, nil, -countChange)
					end
				end
			end
		end
	end
end

local function onBankDepositNotAllowed()
	if queue.index > #queue.items then
		onQueueProcessed()
		return
	end
	
	-- revert last cache changes
	updateLocalCache(lastCacheUpdateData.itemLink, lastCacheUpdateData.totalsId, lastCacheUpdateData.targetBagId, lastCacheUpdateData.targetSlotId,
		lastCacheUpdateData.sourceBagId, lastCacheUpdateData.sourceSlotId, lastCacheUpdateData.movedCount, lastCacheUpdateData.maxStackSize)
	
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
	initCacheForBag(bagId)
	initCacheForBag(BAG_BACKPACK)
	
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
		populateQueueForQuests(BAG_SUBSCRIBER_BANK)
	end
	
	--d("Queue building took " .. GetGameTimeMilliseconds() - startTimeMs .. " ms")
	
	if #queue.items > 0 then
		EVENT_MANAGER:RegisterForEvent(name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
			function(eventCode, bagId, slotId, isNewItem, itemSoundCategory, updateReason, countChange)
				onSlotChanged(bagId, slotId, countChange)
		end)
		EVENT_MANAGER:AddFilterForEvent(name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
		
		EVENT_MANAGER:RegisterForEvent(name, EVENT_BANK_DEPOSIT_NOT_ALLOWED, function(eventCode) onBankDepositNotAllowed() end)
		
		if bagId == BAG_GUILDBANK then
			EVENT_MANAGER:RegisterForEvent(name, EVENT_GUILD_BANK_ITEM_ADDED, function(eventCode, slotId, addedByLocalPlayer)
				onSlotChanged(BAG_GUILDBANK, slotId, 1)
			end)
			EVENT_MANAGER:RegisterForEvent(name, EVENT_GUILD_BANK_ITEM_REMOVED, function(eventCode, slotId, addedByLocalPlayer)
				onSlotChanged(BAG_GUILDBANK, slotId, -1)
			end)
		end
	end
	
	processQueue()
end

local function onBankClose()
	--d("Bank closed")
	onQueueProcessed()
end

local function onAddOnLoaded(event, addonName)
	if addonName ~= name then return end
	EVENT_MANAGER:UnregisterForEvent(name, EVENT_ADD_ON_LOADED)
	
	Bankir.Data.getBankBags()
	Bankir.Data.getCharactersList()
	
	-- upgrade saved vars structure for Bankir 2.7
	if BankirSavedVariables then
		if BankirSavedVariables.Default then
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
						elseif settingName == "version" then
							BankirSavedVariables.Common[settingName] = 2.7
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
	end
	
	local defaultProfileName = "Default"
	local profiles = Bankir.Profiles.getProfilesNames()
	if #profiles > 0 then
		defaultProfileName = profiles[1]
	end
	Bankir.savedVarsCharacter = ZO_SavedVars:NewCharacterIdSettings("BankirSavedVariables", 2, nil, { profile = defaultProfileName })
	
	Bankir.Profiles.createNewProfile(Bankir.savedVarsCharacter.profile)
	
	BankirSavedVariables.Common = BankirSavedVariables.Common or Bankir.Data.getDefaultCommonSettings()
	Bankir.savedVarsCommon = BankirSavedVariables.Common
	
	BankirSavedVariables.Server = BankirSavedVariables.Server or {}
	BankirSavedVariables.Server[GetWorldName()] = BankirSavedVariables.Server[GetWorldName()] or Bankir.Data.getDefaultServerSettings()
	Bankir.savedVarsServer = BankirSavedVariables.Server[GetWorldName()]
	
	Bankir.Data.cleanUpLCKList()
	
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
