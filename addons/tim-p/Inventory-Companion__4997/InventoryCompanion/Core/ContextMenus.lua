InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

local CONTEXT_MENU_DELAY_MS = 50
local PARTIAL_STOW_GEMMIFIABLE_DIALOG = "INVENTORYCOMPANION_PARTIAL_STOW_GEMMIFIABLE"

ZO_Dialogs_RegisterCustomDialog(PARTIAL_STOW_GEMMIFIABLE_DIALOG, {
    canQueue = true,
    gamepadInfo = {
        dialogType = GAMEPAD_DIALOGS.BASIC,
    },
    title = {
        text = SI_CONFIRM_STOW_GEMIFIABLE_TITLE,
    },
    mainText = {
        text = SI_CONFIRM_STOW_GEMIFIABLE_TEXT,
    },
    buttons = {
        [1] = {
            text = SI_YES,
            callback = function(dialog)
                local data = dialog.data
                this.StowContextItem(
                    data.sourceSlotIndex, data.amount, data.sourceCount, data.sourceItemLink, true)
            end,
        },
        [2] = {
            text = SI_NO,
        },
    },
})

local function AddCraftBagStowOptions(slotIndex, currentCount, itemLink)
    if IsGuildBankOpen() or not HasCraftBagAccess()
        or not CanItemBeVirtual(BAG_BACKPACK, slotIndex)
        or IsItemStolen(BAG_BACKPACK, slotIndex)
        or not itemLink or itemLink == "" then
        return
    end

    local slotData = SHARED_INVENTORY:GenerateSingleSlotData(BAG_BACKPACK, slotIndex)
    if not slotData then return end

    local function AddStowOption(label, amount)
        AddCustomMenuItem(label, function()
            if slotData.isGemmable then
                ZO_Dialogs_ShowPlatformDialog(PARTIAL_STOW_GEMMIFIABLE_DIALOG, {
                    sourceSlotIndex = slotIndex,
                    amount = amount,
                    sourceCount = currentCount,
                    sourceItemLink = itemLink,
                })
            else
                this.StowContextItem(slotIndex, amount, currentCount, itemLink)
            end
        end, MENU_ADD_OPTION_LABEL)
    end

    AddStowOption(string.format("Stow 1 (of %d)", currentCount), 1)
    AddStowOption(string.format("Stow %d (of %d)", currentCount - 1, currentCount), currentCount - 1)
    AddStowOption(string.format("Stow %d (of %d)", currentCount, currentCount), currentCount)
end

local function AddContextMenuItems(rowControl)
    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(rowControl)
    if not bagId or not slotIndex then return end

    local itemId = GetItemId(bagId, slotIndex)
    local itemLink
    if itemId and itemId > 0 then
        itemLink = GetItemLink(bagId, slotIndex)
        local icon = GetItemLinkIcon(itemLink)
        
        local trackedList = this.GetActiveTrackedItems()
        local isTracked = (trackedList and trackedList[itemId] ~= nil)
        local trackLabel = isTracked and "Remove from Tracked Items" or "Add to Tracked Items"

        AddCustomMenuItem(trackLabel, function()
            local currentList = this.GetActiveTrackedItems()
            currentList = currentList or {}
          
  			if isTracked then
                currentList[itemId] = nil
            else
                currentList[itemId] = {
                    link = itemLink,
                    icon = icon,
                    display = {
                        show = true,
                        notify = false,
                        bank = false,
                        group = false,
                    },
                }
            end

            this.UpdateEventRegistry()
            if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
        end, MENU_ADD_OPTION_LABEL)
    end

    local isVirtualStorage = bagId == BAG_VIRTUAL or bagId == BAG_FURNITURE_VAULT
    if IsBankOpen() or IsGuildBankOpen() or isVirtualStorage then
        local currentCount = select(2, GetItemInfo(bagId, slotIndex))
        if currentCount and currentCount > 1 then 
            local mode = nil
            local useGuildBankTransfer = false

            if isVirtualStorage then
                if not IsGuildBankOpen() then mode = "Withdraw" end
            elseif bagId == BAG_BACKPACK then
                if IsGuildBankOpen() and this.CanUseGuildBankPartialDeposits() then
                    mode = "Deposit"
                    useGuildBankTransfer = true
                elseif IsBankOpen() then
                    mode = "Deposit"
                end
            elseif bagId == BAG_BANK or bagId == BAG_SUBSCRIBER_BANK or IsHouseBankBag(bagId) then
                if IsBankOpen() then mode = "Withdraw" end
            elseif bagId == BAG_GUILDBANK and this.CanUseGuildBankPartialWithdrawals() then
                mode = "Withdraw"
                useGuildBankTransfer = true
            end

            if mode then
                local function AddTransferOption(label, amount)
                    AddCustomMenuItem(label, function()
                        if useGuildBankTransfer then
                            if bagId == BAG_GUILDBANK then
                                this.WithdrawGuildBankPartial(slotIndex, amount, currentCount)
                            else
                                this.DepositGuildBankPartial(slotIndex, amount, currentCount)
                            end
                        else
                            this.TransferContextItem(bagId, slotIndex, amount, currentCount, itemLink)
                        end
                    end, MENU_ADD_OPTION_LABEL)
                end

                AddTransferOption(string.format("%s 1 (of %d)", mode, currentCount), 1)
                if mode == "Withdraw" and isVirtualStorage and currentCount > 201 then
                    AddTransferOption("Withdraw 200 (one stack)", 200)
                    local remainingCount = currentCount - 1
                    local stackCount = math.ceil(remainingCount / 200)
                    AddTransferOption(
                        string.format("Withdraw %d (of %d, %d stacks)", remainingCount, currentCount, stackCount),
                        remainingCount)
                else
                    AddTransferOption(string.format("%s %d (of %d)", mode, currentCount - 1, currentCount),
                        currentCount - 1)
                end
            end
        end
    end

    if bagId == BAG_BACKPACK then
        local currentCount = select(2, GetItemInfo(bagId, slotIndex))
        if currentCount and currentCount > 1 then
            AddCraftBagStowOptions(slotIndex, currentCount, itemLink)
        end
    end

    ShowMenu()
end

local function AddContextMenuItemsWithDelay(rowControl)
    zo_callLater(function()
        AddContextMenuItems(rowControl)
    end, CONTEXT_MENU_DELAY_MS)
end

function this.InitContextMenus()
    ZO_PreHook("ZO_InventorySlot_ShowContextMenu", AddContextMenuItemsWithDelay)
end