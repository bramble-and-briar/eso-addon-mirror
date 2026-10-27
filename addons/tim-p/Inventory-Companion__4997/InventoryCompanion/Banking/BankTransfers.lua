InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

------------------------------------------------------------------
-- 1. Local Constants
------------------------------------------------------------------
local KNOWN_BANK_NAMES = {
    [BAG_BANK]             = "Bank",
    [BAG_SUBSCRIBER_BANK]  = "ESO+ Bank",
    [BAG_HOUSE_BANK_ONE]   = "House Bank",
    [BAG_HOUSE_BANK_TWO]   = "House Bank",
    [BAG_HOUSE_BANK_THREE] = "House Bank",
    [BAG_HOUSE_BANK_FOUR]  = "House Bank",
    [BAG_HOUSE_BANK_FIVE]  = "House Bank",
    [BAG_HOUSE_BANK_SIX]   = "House Bank",
    [BAG_HOUSE_BANK_SEVEN] = "House Bank",
    [BAG_HOUSE_BANK_EIGHT] = "House Bank",
    [BAG_HOUSE_BANK_NINE]  = "House Bank",
    [BAG_HOUSE_BANK_TEN]   = "House Bank",
}

------------------------------------------------------------------
-- 2. Local Transfer Execution Helpers
------------------------------------------------------------------
local function ExecuteTransferInstruction(instruction)
    local amount = instruction.amount or select(2, GetItemInfo(instruction.sourceBag, instruction.sourceSlot))
    if not amount or amount <= 0 then return false end

    if CallSecureProtected("PickupInventoryItem", instruction.sourceBag, instruction.sourceSlot, amount) then
        if instruction.message then
            this.Utils.UserMessage(instruction.message, instruction.message)
        end

        CallSecureProtected("PlaceInTransfer", instruction.targetBag)
        return true
    end

    return false
end

local function ProcessTransferQueue(queue, index)
    if not IsBankOpen() then return end

    if index > #queue then      
        return
    end

    ExecuteTransferInstruction(queue[index])

    local delay = (this.accountWide and this.accountWide.bankItemDelay) or 100
    zo_callLater(function() ProcessTransferQueue(queue, index + 1) end, delay)
end

------------------------------------------------------------------
-- 3. Local Stack Merging Helpers
------------------------------------------------------------------
local function GetHouseChestName(bankType)
    local collectibleId = GetCollectibleForHouseBankBag(bankType)
    if not collectibleId or collectibleId == 0 then return nil end

    local nickname = GetCollectibleNickname(collectibleId)
    if nickname and nickname ~= "" then return nickname end

    return GetCollectibleName(collectibleId)
end

local function MapBagContentsByName(bagId)   
    local slotMap = {}
    local contents = this.Scanning.GetBagContents({ bagId })

    d(string.format("[IC Debug] MapBagContentsByName scanning bag ID: %d (Total items found: %d)", bagId, #contents))

    for _, itemData in ipairs(contents) do
        local itemName = GetItemLinkName(itemData.link)
        if itemName then
            d(string.format("[IC Debug]   -> Found item: '%s' (Slot: %d, Count: %d/%d)", itemName, itemData.slotIndex, itemData.count, itemData.maxCount))
            slotMap[itemName] = slotMap[itemName] or { slots = {} }

            table.insert(slotMap[itemName].slots, {
                slotIndex    = itemData.slotIndex,
                currentCount = itemData.count,
                maxCount     = itemData.maxCount,
            })
        end
    end

    return slotMap
end

local function BuildChestMergePlan(containerBagId)
    local chestMap = MapBagContentsByName(containerBagId)
    local backpackMap = MapBagContentsByName(BAG_BACKPACK)

    local commonItems = {}
    for itemName, backpackEntry in pairs(backpackMap) do
        if chestMap[itemName] then
            commonItems[itemName] = backpackEntry
        end
    end

    local mergePlan = {}

    for itemName, backpackEntry in pairs(commonItems) do
        local chestEntry = chestMap[itemName]

        for _, backpackSlot in ipairs(backpackEntry.slots) do
            local remainingSourceCount = backpackSlot.currentCount
            local viableTargets = {}

            for _, chestSlot in ipairs(chestEntry.slots) do
                local availableSpace = chestSlot.maxCount - chestSlot.currentCount
                if availableSpace > 0 then
                    local amountToTransfer = math.min(remainingSourceCount, availableSpace)
                    table.insert(viableTargets, {
                        targetSlotIndex = chestSlot.slotIndex,
                        transferAmount  = amountToTransfer,
                    })

                    remainingSourceCount = remainingSourceCount - amountToTransfer
                    if remainingSourceCount <= 0 then break end
                end
            end

            if #viableTargets > 0 then
                table.insert(mergePlan, {
                    itemName          = itemName,
                    backpackSlotIndex = backpackSlot.slotIndex,
                    targets           = viableTargets,
                })
            end
        end
    end

    return mergePlan
end

local function QueueChestMergeInstructions(containerBagId)
    local mergePlan  = BuildChestMergePlan(containerBagId)
    local targetName = (this.accountWide.houseBankNames and this.accountWide.houseBankNames[containerBagId]) or "Chest"
    local queue      = {}

    for _, planEntry in ipairs(mergePlan) do
        local itemLink = GetItemLink(BAG_BACKPACK, planEntry.backpackSlotIndex)

        for _, target in ipairs(planEntry.targets) do
            local moveText = string.format("Moving x%d %s to %s", target.transferAmount, itemLink, targetName)

            table.insert(queue, {
                sourceBag  = BAG_BACKPACK,
                sourceSlot = planEntry.backpackSlotIndex,
                targetBag  = containerBagId,
                amount     = target.transferAmount,
                message    = moveText, -- Explicit per-item message
            })
        end
    end

    return queue
end

------------------------------------------------------------------
-- 4. Local Target Slot Finder
------------------------------------------------------------------
local function FindTargetSlotForItem(targetBag, sourceBag, sourceSlot)
    local itemLink = GetItemLink(sourceBag, sourceSlot)
    if not itemLink or itemLink == "" then return nil end

    local itemName = GetItemLinkName(itemLink)
    local bagSize = GetBagSize(targetBag)

    -- Pass 1: Look for an existing stack of the same item with available capacity
    for slotIndex = 0, bagSize - 1 do
        local slotLink = GetItemLink(targetBag, slotIndex)
        if slotLink and slotLink ~= "" then
            if GetItemLinkName(slotLink) == itemName then
                local currentCount, maxCount = GetSlotStackSize(targetBag, slotIndex)
                if currentCount < maxCount then
                    return slotIndex
                end
            end
        end
    end

    -- Pass 2: Fallback to the first empty slot
    return FindFirstEmptySlotInBag(targetBag)
end

------------------------------------------------------------------
-- Progress Milestone Helper
------------------------------------------------------------------
local function AttachProgressMilestones(queue)
    local totalItems = #queue
    if totalItems == 0 then return end

    -- Infer verb from first instruction's targetBag
    local firstTarget = queue[1].targetBag
    local verb = "Transfer"

    if firstTarget == BAG_BANK or firstTarget == BAG_SUBSCRIBER_BANK then
        verb = "Deposit"
    elseif firstTarget == BAG_BACKPACK then
        verb = "Withdrawal"
    end

    -- 1. Start/end messages
	queue[1].message = string.format("%s 0%% complete (0/%d)", verb, totalItems)
    queue[totalItems].message = string.format("%s 100%% complete (%d/%d)", verb, totalItems, totalItems)

    -- Intermediate milestones for larger queues
    if totalItems >= 4 then
        local quarter = math.floor(totalItems * 0.25)
        local half    = math.floor(totalItems * 0.50)
        local threeQ  = math.floor(totalItems * 0.75)

        if quarter > 1 and queue[quarter] then
            queue[quarter].message = string.format("%s 25%% complete (%d/%d)", verb, quarter, totalItems)
        end
        if half > 0 and queue[half] then
            queue[half].message = string.format("%s 50%% complete (%d/%d)", verb, half, totalItems)
        end
        if threeQ > 0 and queue[threeQ] then
            queue[threeQ].message = string.format("%s 75%% complete (%d/%d)", verb, threeQ, totalItems)
        end
    end
end

------------------------------------------------------------------
-- 5. Exported Module Endpoints (this.*)
------------------------------------------------------------------

--- Process bulk pre-crafted item transfers between backpack and bank
function this.ProcessBags(sourceBags, targetBag)
    if not IsBankOpen() then
        this.Utils.UserWarning(nil, "Banker not open! Cannot move stuff")
        return 
    end

    local myName = GetUnitName("player")
    local queue = {}
    local verb = (targetBag == BAG_BANK and "Depositing") or (targetBag == BAG_BACKPACK and "Withdrawing") or "Moving"

    for _, bagId in ipairs(sourceBags) do
        local numSlots = GetBagSize(bagId)

        for slotIndex = 0, numSlots - 1 do
            local rawName = GetItemName(bagId, slotIndex)

            if rawName and rawName ~= "" then
                local itemName = zo_strformat(SI_TOOLTIP_ITEM_NAME, rawName)
                local creator  = GetItemCreatorName(bagId, slotIndex)
                local rule     = this.TargetItems and this.TargetItems[itemName]

                if not creator or creator == "" then
                    -- Not crafted, ignore
                elseif rule == nil or rule == false then
                    -- Skipped or blacklisted
                elseif creator ~= myName then
                    this.Utils.DebugMessage("|cFFA500Skipping (created by " .. creator .. "):|r " .. itemName)
                else
                    table.insert(queue, {
                        sourceBag  = bagId,
                        sourceSlot = slotIndex,
                        targetBag  = targetBag,
                        message    = nil, -- Silent per-item by default
                    })
                end
            end
        end
    end

    if #queue > 0 then       
        -- Attach milestone messages (25%, 50%, 75%) before starting transfers
        AttachProgressMilestones(queue)

        ProcessTransferQueue(queue, 1)
    else
        this.Utils.UserMessage("Nothing to move...", "Nothing to move")
    end 
end

--- Handler invoked when opening a bank or house chest
function this.OnBankOpened(eventCode, bankType)
    local bankName = KNOWN_BANK_NAMES[bankType]
    
    if not bankName then 
        if this.accountWide.debugEnabled and this.Utils and this.Utils.UserWarning then 
            this.Utils.UserWarning("Bank ID " .. bankType .. " is not in the list of known banks", "Unknown bank! - ID: " .. bankType)
        end
        return
    end 

    if IsHouseBankBag(bankType) then 
        bankName = GetHouseChestName(bankType) or "House Chest"
        
        if this.accountWide then
            this.accountWide.houseBankNames = this.accountWide.houseBankNames or {}
            this.accountWide.houseBankNames[bankType] = bankName
        end

        if not this.accountWide or this.accountWide.autoMergeChests ~= false then
            local queue = QueueChestMergeInstructions(bankType)
            if #queue > 0 then              
                ProcessTransferQueue(queue, 1)
            end
        end
    end
    
    if this.accountWide.debugEnabled and this.Utils and this.Utils.UserMessage then
        this.Utils.UserMessage("", "Opened " .. bankName)                 
    end
end

--- Context Menu single-item or bulk transfer helper
function this.TransferContextItem(sourceBag, sourceSlot, amount)
    if not IsBankOpen() then return end

    local currentCount = select(2, GetItemInfo(sourceBag, sourceSlot))
    if not currentCount or currentCount <= 0 then return end

    local mode = (sourceBag == BAG_BACKPACK) and "Deposit" or "Withdraw"
    local targetBag = (mode == "Deposit") and GetBankingBag() or BAG_BACKPACK
    local targetSlot = FindTargetSlotForItem(targetBag, sourceBag, sourceSlot)

    -- Fallback for ESO Plus Subscriber Bank when depositing to standard bank
    if not targetSlot then
        if targetBag == BAG_BANK and IsESOPlusSubscriber() then
            targetBag = BAG_SUBSCRIBER_BANK
            targetSlot = FindTargetSlotForItem(targetBag, sourceBag, sourceSlot)
        elseif targetBag == BAG_SUBSCRIBER_BANK then
            targetBag = BAG_BANK
            targetSlot = FindTargetSlotForItem(targetBag, sourceBag, sourceSlot)
        end
    end

    if not targetSlot then
        local errorStringId = (targetBag == BAG_BACKPACK) and SI_INVENTORY_ERROR_INVENTORY_FULL or SI_INVENTORY_ERROR_BANK_FULL
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, errorStringId)
        return
    end

    -- UserMessage for Context Menu Transfers
    local itemLink   = GetItemLink(sourceBag, sourceSlot)
    local targetName = (mode == "Deposit") 
        and ((this.accountWide.houseBankNames and this.accountWide.houseBankNames[targetBag]) or "Bank") 
        or "Backpack"
    local moveText   = string.format("Moving x%d %s to %s", amount, itemLink, targetName)

    this.Utils.UserMessage(moveText, moveText)

    CallSecureProtected("RequestMoveItem", sourceBag, sourceSlot, targetBag, targetSlot, amount)
    PlaySound(SOUNDS.DIALOG_ACCEPT)
end

