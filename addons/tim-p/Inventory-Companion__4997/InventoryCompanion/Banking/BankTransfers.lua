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

local GUILD_BANK_WITHDRAW_TIMEOUT_MS = 10000
local GUILD_BANK_PARTIAL_DEPOSIT_TIMEOUT_MS = 10000
local GUILD_BANK_PARTIAL_DEPOSIT_POLL_MS = 100
local guildBankPartialWithdrawal = nil
local guildBankPartialWithdrawalSequence = 0
local guildBankPartialDeposit = nil

local function ExecuteGuildBankAction(functionName, ...)
    if IsProtectedFunction(functionName) then
        local succeeded, failure = CallSecureProtected(functionName, ...)
        if not succeeded then return false, failure end
    else
        _G[functionName](...)
    end
    return true
end

local function PlaceCursorInBagSlot(bagId, slotIndex)
    local placed, failure = CallSecureProtected("PlaceInInventory", bagId, slotIndex)
    if not placed then
        return false, "PlaceInInventory failed: " .. tostring(failure)
    end
    return true
end

local function SplitBackpackStackForGuildBankDeposit(sourceSlot, amount)
    local sourceCount = select(2, GetItemInfo(BAG_BACKPACK, sourceSlot))
    local keepInBackpack = sourceCount - amount
    if keepInBackpack <= 0 then return true end

    local cursorReturnSlot = FindFirstEmptySlotInBag(BAG_BACKPACK)
    if not cursorReturnSlot then
        return false, string.format("You need one free slot to deposit %d to a guild bank.", amount)
    end

    local pickedUp, pickupFailure =
        CallSecureProtected("PickupInventoryItem", BAG_BACKPACK, sourceSlot, keepInBackpack)
    if not pickedUp then
        return false, "PickupInventoryItem failed: " .. tostring(pickupFailure)
    end

    local returned, returnFailure = PlaceCursorInBagSlot(BAG_BACKPACK, cursorReturnSlot)
    if not returned then
        return false, returnFailure .. ". The remainder may still be on your cursor."
    end
    return true
end

------------------------------------------------------------------
-- 2. Local Transfer Execution Helpers
------------------------------------------------------------------
local function GetItemCountsById(bagId, itemId)
    local counts = {}
    for slotIndex = 0, GetBagSize(bagId) - 1 do
        if GetItemId(bagId, slotIndex) == itemId then
            counts[slotIndex] = select(2, GetItemInfo(bagId, slotIndex))
        end
    end
    return counts
end

local function GetTotalItemCountById(bagId, itemId)
    local totalCount = 0
    for _, count in pairs(GetItemCountsById(bagId, itemId)) do
        totalCount = totalCount + count
    end
    return totalCount
end

local function CompleteGuildBankPartialDeposit(operation, succeeded, failure)
    if guildBankPartialDeposit ~= operation then return end
    guildBankPartialDeposit = nil
    operation.onComplete(succeeded, failure, operation)
end

local function PollGuildBankPartialDeposit(operation)
    if guildBankPartialDeposit ~= operation then return end
    if not IsGuildBankOpen() or GetSelectedGuildBankId() ~= operation.guildId then
        CompleteGuildBankPartialDeposit(operation, false,
            "The guild bank closed or changed before the split was confirmed; no transfer was started.")
        return
    end

    local sourceItemId = GetItemId(BAG_BACKPACK, operation.sourceSlot)
    local sourceCount = select(2, GetItemInfo(BAG_BACKPACK, operation.sourceSlot))
    local totalCount = GetTotalItemCountById(BAG_BACKPACK, operation.itemId)
    if sourceItemId == operation.itemId and sourceCount == operation.amount
        and totalCount == operation.initialItemCount then
        local transferStarted, transferFailure =
            ExecuteGuildBankAction("TransferToGuildBank", BAG_BACKPACK, operation.sourceSlot)
        if not transferStarted then
            CompleteGuildBankPartialDeposit(operation, false,
                "TransferToGuildBank failed: " .. tostring(transferFailure))
            return
        end

        CompleteGuildBankPartialDeposit(operation, true)
        return
    end

    zo_callLater(function()
        PollGuildBankPartialDeposit(operation)
    end, GUILD_BANK_PARTIAL_DEPOSIT_POLL_MS)
end

local function TimeoutGuildBankPartialDeposit(operation)
    if guildBankPartialDeposit ~= operation then return end
    local sourceItemId = GetItemId(BAG_BACKPACK, operation.sourceSlot)
    local sourceCount = select(2, GetItemInfo(BAG_BACKPACK, operation.sourceSlot))
    local totalCount = GetTotalItemCountById(BAG_BACKPACK, operation.itemId)
    CompleteGuildBankPartialDeposit(operation, false, string.format(
        "The split did not settle within %d ms (source slot %d has item ID %s and count %s; expected item ID %d and count %d; backpack total is %d of %d); no guild-bank transfer was started.",
        GUILD_BANK_PARTIAL_DEPOSIT_TIMEOUT_MS, operation.sourceSlot, tostring(sourceItemId),
        tostring(sourceCount), operation.itemId, operation.amount, totalCount, operation.initialItemCount))
end

local BeginGuildBankPartialDeposit

BeginGuildBankPartialDeposit = function(sourceSlot, amount, sourceCount, onComplete)
    if guildBankPartialDeposit then
        return false, "A guild-bank partial deposit is already in progress."
    end
    if not this.CanUseGuildBankPartialDeposits() then
        return false, "Guild-bank partial deposits require guild-bank deposit access."
    end

    local itemLink = GetItemLink(BAG_BACKPACK, sourceSlot)
    local itemId = GetItemId(BAG_BACKPACK, sourceSlot)
    local currentCount = select(2, GetItemInfo(BAG_BACKPACK, sourceSlot))
    if not itemLink or itemLink == "" or not itemId or itemId <= 0 or currentCount ~= sourceCount
        or amount < 1 or amount > sourceCount then
        return false, "The backpack stack changed before the partial guild-bank deposit could start."
    end
    if GetNumBagFreeSlots(BAG_GUILDBANK) == 0 or IsItemStolen(BAG_BACKPACK, sourceSlot) then
        return false, "The guild bank has no free slot or this item cannot be deposited."
    end

    local operation = {
        guildId = GetSelectedGuildBankId(),
        itemLink = itemLink,
        itemId = itemId,
        sourceSlot = sourceSlot,
        amount = amount,
        initialItemCount = GetTotalItemCountById(BAG_BACKPACK, itemId),
        onComplete = onComplete,
    }
    guildBankPartialDeposit = operation

    local split, splitFailure = SplitBackpackStackForGuildBankDeposit(sourceSlot, amount)
    if not split then
        guildBankPartialDeposit = nil
        return false, splitFailure
    end

    zo_callLater(function()
        PollGuildBankPartialDeposit(operation)
    end, GUILD_BANK_PARTIAL_DEPOSIT_POLL_MS)
    zo_callLater(function()
        TimeoutGuildBankPartialDeposit(operation)
    end, GUILD_BANK_PARTIAL_DEPOSIT_TIMEOUT_MS)
    return true
end

local function UnregisterGuildBankPartialWithdrawalEvent(operation)
    if operation.eventId then
        EVENT_MANAGER:UnregisterForEvent(operation.eventId, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
        operation.eventId = nil
    end
end

local function FinishGuildBankPartialWithdrawal(operation, message, isError)
    if guildBankPartialWithdrawal ~= operation then return end
    UnregisterGuildBankPartialWithdrawalEvent(operation)
    guildBankPartialWithdrawal = nil
    if message then
        if isError then
            this.Utils.UserError(message, message)
        else
            this.Utils.UserMessage(message, message)
        end
    end
end

local function FailGuildBankPartialWithdrawal(operation, message)
    FinishGuildBankPartialWithdrawal(operation, message, true)
end

local function ReportGuildBankTransferFailure(operation, functionName, failure, context)
    FinishGuildBankPartialWithdrawal(operation)
    local message = string.format("%s failed: %s. %s",
        functionName, tostring(failure), context)
    this.Utils.UserError(message, message)
end

local function ProcessGuildBankPartialWithdrawal(operation, planIndex)
    if guildBankPartialWithdrawal ~= operation then return end
    if not IsGuildBankOpen() or GetSelectedGuildBankId() ~= operation.guildId then
        FailGuildBankPartialWithdrawal(operation,
            "Guild-bank partial withdrawal stopped before the remainder was returned. Check your backpack and guild bank.")
        return
    end

    local plan = operation.returnPlans[planIndex]
    if not plan then
        FinishGuildBankPartialWithdrawal(operation,
            string.format("Withdrew x%d %s from the guild bank.", operation.requestedAmount, operation.itemLink), false)
        return
    end

    local currentItemId = GetItemId(BAG_BACKPACK, plan.slotIndex)
    local currentCount = select(2, GetItemInfo(BAG_BACKPACK, plan.slotIndex))
    if currentItemId ~= operation.itemId or not currentCount or currentCount < plan.amount then
        FailGuildBankPartialWithdrawal(operation,
            "Guild-bank partial withdrawal could not safely return the remainder. Check your backpack and guild bank.")
        return
    end

    if GetNumBagFreeSlots(BAG_GUILDBANK) == 0 or IsItemStolen(BAG_BACKPACK, plan.slotIndex) then
        FailGuildBankPartialWithdrawal(operation,
            "Guild-bank partial withdrawal could not return the remainder. Check your guild-bank space and item eligibility.")
        return
    end

    local depositStarted, failure = BeginGuildBankPartialDeposit(
        plan.slotIndex, plan.amount, currentCount,
        function(succeeded, depositFailure)
            if not succeeded then
                ReportGuildBankTransferFailure(operation, "partial guild-bank deposit", depositFailure,
                    "Check your backpack and guild bank before trying again.")
                return
            end

            local delay = this.accountWide.bankItemDelay
            zo_callLater(function()
                ProcessGuildBankPartialWithdrawal(operation, planIndex + 1)
            end, delay)
        end)
    if not depositStarted then
        ReportGuildBankTransferFailure(operation, "partial guild-bank deposit", failure,
            "Check your backpack and guild bank before trying again.")
    end
end

local function BuildGuildBankPartialWithdrawalPlan(operation)
    local currentCounts = GetItemCountsById(BAG_BACKPACK, operation.itemId)
    local remainingStack = operation.sourceCount
    local remainingToKeep = operation.requestedAmount
    local returnPlans = {}

    for slotIndex = 0, GetBagSize(BAG_BACKPACK) - 1 do
        local currentCount = currentCounts[slotIndex]
        if currentCount then
            local addedCount = math.max(currentCount - (operation.beforeCounts[slotIndex] or 0), 0)
            local attributableCount = math.min(addedCount, remainingStack)
            local keepCount = math.min(attributableCount, remainingToKeep)
            local returnCount = attributableCount - keepCount
            if returnCount > 0 then
                table.insert(returnPlans, { slotIndex = slotIndex, amount = returnCount })
            end
            remainingStack = remainingStack - attributableCount
            remainingToKeep = remainingToKeep - keepCount
        end
    end

    if remainingStack > 0 or remainingToKeep > 0 then
        return nil
    end
    return returnPlans
end

local function GetGuildBankPartialWithdrawalAddedCount(operation)
    local currentCounts = GetItemCountsById(BAG_BACKPACK, operation.itemId)
    local addedCount = 0
    for slotIndex, currentCount in pairs(currentCounts) do
        addedCount = addedCount + math.max(currentCount - (operation.beforeCounts[slotIndex] or 0), 0)
    end
    return addedCount
end

local function OnGuildBankPartialWithdrawalInventoryUpdate(operation, _, bagId)
    if guildBankPartialWithdrawal ~= operation or not operation.waitingForWithdrawal or bagId ~= BAG_BACKPACK then return end
    local addedCount = GetGuildBankPartialWithdrawalAddedCount(operation)
    if addedCount < operation.sourceCount then return end

    operation.waitingForWithdrawal = false
    operation.returnPlans = BuildGuildBankPartialWithdrawalPlan(operation)
    if not operation.returnPlans then
        FailGuildBankPartialWithdrawal(operation,
            "Guild-bank partial withdrawal could not identify the withdrawn stack safely. Check your backpack and guild bank.")
        return
    end

    UnregisterGuildBankPartialWithdrawalEvent(operation)
    zo_callLater(function()
        ProcessGuildBankPartialWithdrawal(operation, 1)
    end, this.accountWide.bankItemDelay)
end

local function PollGuildBankPartialWithdrawal(operation)
    if guildBankPartialWithdrawal ~= operation or not operation.waitingForWithdrawal then return end
    OnGuildBankPartialWithdrawalInventoryUpdate(operation, nil, BAG_BACKPACK)
    if operation.waitingForWithdrawal then
        zo_callLater(function()
            PollGuildBankPartialWithdrawal(operation)
        end, 100)
    end
end

function this.CanUseGuildBankPartialWithdrawals()
    if not this.accountWide.guildBankPartialWithdrawEnabled or not IsGuildBankOpen() then return false end
    local guildId = GetSelectedGuildBankId()
    return guildId ~= nil
        and DoesPlayerHaveGuildPermission(guildId, GUILD_PERMISSION_BANK_WITHDRAW)
        and DoesPlayerHaveGuildPermission(guildId, GUILD_PERMISSION_BANK_DEPOSIT)
        and DoesGuildHavePrivilege(guildId, GUILD_PRIVILEGE_BANK_DEPOSIT)
end

function this.CanUseGuildBankPartialDeposits()
    if not IsGuildBankOpen() then return false end
    local guildId = GetSelectedGuildBankId()
    return guildId ~= nil
        and DoesPlayerHaveGuildPermission(guildId, GUILD_PERMISSION_BANK_DEPOSIT)
        and DoesGuildHavePrivilege(guildId, GUILD_PRIVILEGE_BANK_DEPOSIT)
end

function this.DepositGuildBankPartial(sourceSlot, amount, sourceCount)
    if guildBankPartialDeposit then
        this.Utils.UserWarning("A guild-bank partial deposit is already in progress.")
        return
    end
    if guildBankPartialWithdrawal then
        this.Utils.UserWarning("A guild-bank partial withdrawal is already in progress.")
        return
    end
    if not this.CanUseGuildBankPartialDeposits() then
        this.Utils.UserError("Guild-bank partial deposits require guild-bank deposit access.")
        return
    end

    local itemLink = GetItemLink(BAG_BACKPACK, sourceSlot)
    local itemId = GetItemId(BAG_BACKPACK, sourceSlot)
    local currentCount = select(2, GetItemInfo(BAG_BACKPACK, sourceSlot))
    if not itemLink or itemLink == "" or not itemId or itemId <= 0 or currentCount ~= sourceCount
        or amount < 1 or amount >= sourceCount then
        this.Utils.UserError("The backpack stack changed before the partial guild-bank deposit could start.")
        return
    end
    if not FindFirstEmptySlotInBag(BAG_BACKPACK) then
        this.Utils.UserError(string.format("You need one free slot to deposit %d to a guild bank.", amount))
        return
    end
    if GetNumBagFreeSlots(BAG_GUILDBANK) == 0 or IsItemStolen(BAG_BACKPACK, sourceSlot) then
        this.Utils.UserError("The guild bank has no free slot or this item cannot be deposited.")
        return
    end

    local started, failure = BeginGuildBankPartialDeposit(sourceSlot, amount, sourceCount,
        function(succeeded, depositFailure, operation)
            if not succeeded then
                local message = string.format("Partial guild-bank deposit failed: %s. Check your cursor, backpack, and guild bank.",
                    tostring(depositFailure))
                this.Utils.UserError(message, message)
                return
            end

            local message = string.format("Depositing x%d %s to Guild Bank", operation.amount, operation.itemLink)
            this.Utils.UserMessage(message, message)
        end)
    if not started then
        local message = string.format("Partial guild-bank deposit failed: %s. Check your cursor, backpack, and guild bank.",
            tostring(failure))
        this.Utils.UserError(message, message)
    end
end

function this.WithdrawGuildBankPartial(sourceSlot, requestedAmount, sourceCount)
    if guildBankPartialWithdrawal then
        this.Utils.UserWarning("A guild-bank partial withdrawal is already in progress.")
        return
    end
    if guildBankPartialDeposit then
        this.Utils.UserWarning("A guild-bank partial deposit is already in progress.")
        return
    end
    if not this.CanUseGuildBankPartialWithdrawals() then
        this.Utils.UserError("Guild-bank partial withdrawal requires guild-bank withdrawal and deposit access.")
        return
    end

    local itemLink = GetItemLink(BAG_GUILDBANK, sourceSlot)
    local itemId = GetItemId(BAG_GUILDBANK, sourceSlot)
    local currentCount = select(2, GetItemInfo(BAG_GUILDBANK, sourceSlot))
    if not itemLink or itemLink == "" or not itemId or itemId <= 0 or currentCount ~= sourceCount
        or requestedAmount < 1 or requestedAmount >= sourceCount then
        this.Utils.UserError("The guild-bank stack changed before the partial withdrawal could start.")
        return
    end
    if GetNumBagFreeSlots(BAG_BACKPACK) < 2 then
        this.Utils.UserError(string.format(
            "You need at least 2 slots free to withdraw %d from a guild bank.", sourceCount))
        return
    end
    if not DoesBagHaveSpaceFor(BAG_BACKPACK, BAG_GUILDBANK, sourceSlot) then
        this.Utils.UserError("There is not enough backpack space to withdraw the guild-bank stack.")
        return
    end

    guildBankPartialWithdrawalSequence = guildBankPartialWithdrawalSequence + 1
    local operation = {
        guildId = GetSelectedGuildBankId(),
        itemLink = itemLink,
        itemId = itemId,
        sourceCount = sourceCount,
        requestedAmount = requestedAmount,
        beforeCounts = GetItemCountsById(BAG_BACKPACK, itemId),
        eventId = string.format("%s_GuildBankPartial_%d", this.Name, guildBankPartialWithdrawalSequence),
        waitingForWithdrawal = true,
    }
    guildBankPartialWithdrawal = operation
    EVENT_MANAGER:RegisterForEvent(operation.eventId, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        function(eventCode, bagId)
            OnGuildBankPartialWithdrawalInventoryUpdate(operation, eventCode, bagId)
        end)

    zo_callLater(function()
        if guildBankPartialWithdrawal == operation and operation.waitingForWithdrawal then
            local addedCount = GetGuildBankPartialWithdrawalAddedCount(operation)
            FinishGuildBankPartialWithdrawal(operation)
            local message = string.format(
                "Guild-bank partial withdrawal timed out; detected %d of %d withdrawn items in the backpack.",
                addedCount, operation.sourceCount)
            this.Utils.UserError(message, message)
        end
    end, GUILD_BANK_WITHDRAW_TIMEOUT_MS)

    local transferStarted, transferFailure = ExecuteGuildBankAction("TransferFromGuildBank", sourceSlot)
    if not transferStarted then
        ReportGuildBankTransferFailure(operation, "TransferFromGuildBank", transferFailure,
            "Check your backpack and guild bank before trying again.")
        return
    end
    zo_callLater(function()
        PollGuildBankPartialWithdrawal(operation)
    end, 100)
end

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
