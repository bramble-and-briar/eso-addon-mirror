local CMA = CraftMaterialAssistant

-- called at the end of all operations to print the results to the chat
function CMA:printResultsToChat()
    if self.db.showBankAlerts then
        if #self.movedItems > 0 then
            self:SendChatMessageLimitedItemCount("|c00AA00Moved to Bank:|r ", self.movedItems)
        end
        if #self.failedItems > 0 then
            self:SendChatMessageLimitedItemCount("|cCF9700No success callback:|r ", self.failedItems)
        end
    end
    if self.db.showJunkAlerts then
        if #self.junkedItems > 0 then
            self:SendChatMessageLimitedItemCount("|cFFEE00Set for Vendoring:|r ", self.junkedItems)
        end
        if #self.ignoredItems > 0 then
            self:SendChatMessageLimitedItemCount("|cFFFFFFIgnored:|r ", self.ignoredItems)
        end
    end
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.ABILITY_SYNERGY_AVAILABLE, "CMA: Finished banking materials.")
    self:cleanupTables()
end

-- Called if the server rejects the move or times out
function CMA:OnMoveFailed(itemLink, stackSizeToDeposit)
    EVENT_MANAGER:UnregisterForUpdate(self.moveTimeoutName)
    -- check if there are attempts left
    local uniqueId = self.processedUniqueId
    -- check if the item is still in the bag or if only the success message got lost
    local bagId, slotIndex = self:findItemByUniqueId(self.sourceBag, uniqueId)
    if slotIndex ~= nil then
        -- item is still in the bag, retry
        if self:checkIfAttemptsLeft(uniqueId) then
            -- readd to list and go on with processing
            table.insert(self.itemsToMove, uniqueId)
        else
            table.insert(self.failedItems, itemLink .. " (" .. stackSizeToDeposit .. ")")
        end
    else
        -- not in bag anymore -> was moved
        table.insert(self.movedItems, itemLink .. " (" .. stackSizeToDeposit .. ")")
    end
    -- set processing to false to enable processing of new items
    self.processingMove = false
    self.processedSlot = nil
    self.processedUniqueId = nil
    -- go on and process the next move
    self:MoveNextItem()
end

-- this function checks if the maximum number of retries for an item is reached and returns true or false
function CMA:checkIfAttemptsLeft(uniqueId)
    if self.failedItemMoveAttempts[uniqueId] then
        if self.failedItemMoveAttempts[uniqueId][1] >= self.numberOfRetriesPerItem then
            -- reached maximum number of reties -> no retry
            return false
        else
            -- was retried before, but limit not reached yet -> increase count, retry
            self.failedItemMoveAttempts[uniqueId][1] = self.failedItemMoveAttempts[uniqueId][1] + 1
            return true
        end
        -- reached maximum number of retries
        return false
    else
        -- did not reach number
        if self.numberOfRetriesPerItem > 0 then
            -- retries allowed, register -> retry for the first time
            self.failedItemMoveAttempts[uniqueId] = {1}
            return true
        else
            -- no retries allowed -> no retry
            return false
        end
    end
end

-- Called when a move operation was successful
function CMA:OnMoveSuccess(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason, stackCountChange)
    -- Verify this update matches the queried bag and slot
    local uniqueId = self:GetUniqueIdString(self.targetBag, self.processedSlot)
    if uniqueId == self.processedUniqueId then
        -- clear the timeout
        EVENT_MANAGER:UnregisterForUpdate(self.moveTimeoutName)
        -- set processing to false to be able to handle the next item
        self.processingMove = false
        self.processedSlot = nil
        self.processedUniqueId = nil
        -- add the item to movedItems
        local itemLink = GetItemLink(bagId, slotIndex)
        table.insert(self.movedItems, itemLink .. " (" .. stackCountChange .. ")")
        -- now trigger the processing of the next item
        self:MoveNextItem()
    end
end

-- starts a timeout event which triggers in case the move operation fails or is too slow
function CMA:StartTimeout(itemLink, stackSizeToDeposit)
    EVENT_MANAGER:RegisterForUpdate(
        self.moveTimeoutName,
        500,
        function()
            self:OnMoveFailed(itemLink, stackSizeToDeposit)
        end
    )
end

-- moves the next single item from the itemsToMove list
function CMA:MoveNextItem()
    -- prevent overlapping requests
    if self.processingMove then return end
    -- if no items left to move -> finished
    if #self.itemsToMove == 0 then
        -- unregister from the move event
        EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
        -- print results to chat
        self:printResultsToChat()
        return
    end
    -- set processing to true to prevent other items to be processed at the same time
    self.processingMove = true

    local uniqueId = table.remove(self.itemsToMove)
    local bagId, slotIndex = self:findItemByUniqueId(self.sourceBag, uniqueId)
    local itemId = GetItemId(bagId, slotIndex)
    local itemLink = GetItemLink(bagId, slotIndex)
    local stackSizeToDeposit = GetSlotStackSize(bagId, slotIndex)
    local depositSlot = self:GetBestFitMapSlot(self.targetBag, itemId, stackSizeToDeposit)

    if depositSlot ~= nil then
        -- start a timer and abort operation it takes too long (=timeout)
        self:StartTimeout(itemLink, stackSizeToDeposit)
        self.processedSlot = depositSlot
        self.processedUniqueId = uniqueId
        -- try to do the move operation - if successful will end up in the callback OnMoveSuccess before timeout triggers
        CallSecureProtected("RequestMoveItem", bagId, slotIndex, self.targetBag, self.processedSlot, stackSizeToDeposit)
    else
        -- did not find an existing slot to deposit - try using a new slot
        if GetNumBagFreeSlots(self.targetBag) <= 0 then
            -- handle the failed item
            self:OnMoveFailed(itemLink, stackSizeToDeposit)
        else
            self.processedSlot = FindFirstEmptySlotInBag(self.targetBag)
            self.processedUniqueId = uniqueId
            -- start a timer and abort operation it takes too long (=timeout)
            self:StartTimeout(itemLink, stackSizeToDeposit)
            -- try to do the move operation - if successful will end up in the callback OnMoveSuccess before timeout triggers
            CallSecureProtected("RequestMoveItem", bagId, slotIndex, self.targetBag, self.processedSlot, stackSizeToDeposit)
        end
    end
end

-- at the start of the banking operation, initialize all tables
function CMA:InitializeTables()
    self.movedItems = {}
    self.junkedItems = {}
    self.ignoredItems = {}
    self.failedItems = {}
    self.itemsToMove = {}
    self.cachedBankSlots = {}
    self.failedItemMoveAttempts = {}
end

-- set tables nil once the process is finished (might help the GC)
function CMA:cleanupTables()
    self.movedItems = nil
    self.junkedItems = nil
    self.ignoredItems = nil
    self.failedItems = nil
    self.itemsToMove = nil
    self.cachedBankSlots = nil
    self.failedItemMoveAttempts = nil
end

function CMA:StartBankingProcess()
    EVENT_MANAGER:UnregisterForUpdate(self.initialTimeoutName)
    if not IsBankOpen() then return end

    self:InitializeTables()

    -- iterate the bag and check each item individually
    local totalSlots = GetBagSize(self.sourceBag)
    for slotIndex = 0, totalSlots do
        if HasItemInSlot(self.sourceBag, slotIndex) then
            local itemLink = GetItemLink(self.sourceBag, slotIndex)
            local stackCount = GetSlotStackSize(self.sourceBag, slotIndex)
            local uniqueId = self:GetUniqueIdString(self.sourceBag, slotIndex)
            local isLocked = IsItemPlayerLocked(self.sourceBag, slotIndex)
            -- only bank / move / sell items if its not locked
            if not isLocked then
                local action = self:DetermineItemAction(self.sourceBag, slotIndex)

                if action == "bank" then
                    -- if it was marked junk previously, unmark it
                    if IsItemJunk(self.sourceBag, slotIndex) then
                        SetItemIsJunk(self.sourceBag, slotIndex, false)
                    end
                    -- add item to be moved to the bank
                    table.insert(self.itemsToMove, uniqueId)
                elseif action == "junk" then
                    if self.db.markAsTrashIfNotBanked then
                        if not IsItemJunk(self.sourceBag, slotIndex) then
                            SetItemIsJunk(self.sourceBag, slotIndex, true)
                            table.insert(self.junkedItems, itemLink .. " (" .. stackCount .. ")")
                            table.insert(self.junkedIds, uniqueId)
                        end
                    else
                        table.insert(self.ignoredItems, itemLink .. " (" .. stackCount .. ")")
                    end
                end
            end
        end
    end
    -- iterate over all banked items and index them in cachedBankSlots
    self:ScanAndMapBankSlots(self.targetBag)
    -- register for the callback of a successful move operation - which triggers the start of the new 
    EVENT_MANAGER:RegisterForEvent(
        self.name,
        EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        function(...)
            self:OnMoveSuccess(...)
        end
    )
    
    EVENT_MANAGER:AddFilterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, self.targetBag)
    -- start the move process
    self:MoveNextItem()
end

function CMA:OnBankOpen(eventCode, bag)
    if bag ~= BAG_BANK then return end
    if not self.db.enableAddon then return end
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.NO_SOUND, "CMA: Banking materials in " .. tostring(math.ceil(self.db.initialDelayInMs / 1000)) .. " seconds.")
    -- start the inital delay
    EVENT_MANAGER:RegisterForUpdate(self.initialTimeoutName, self.db.initialDelayInMs, function() self:StartBankingProcess() end)

end

function CMA:OnBankClosed(event, bankBag)
    EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
end