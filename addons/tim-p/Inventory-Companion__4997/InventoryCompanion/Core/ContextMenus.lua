InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

local CONTEXT_MENU_DELAY_MS = 50

local function AddContextMenuItems(rowControl)
    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(rowControl)
    if not bagId or not slotIndex then return end

    local itemId = GetItemId(bagId, slotIndex)
    if itemId and itemId > 0 then
        local itemLink = GetItemLink(bagId, slotIndex)
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

    if IsBankOpen() then
        local currentCount = select(2, GetItemInfo(bagId, slotIndex))
        if currentCount and currentCount > 1 then 
            local mode = nil

            if bagId == BAG_BACKPACK then
                mode = "Deposit"
            elseif bagId == BAG_BANK or bagId == BAG_SUBSCRIBER_BANK or IsHouseBankBag(bagId) then
                mode = "Withdraw"
            end

            if mode then
                local sendOneLabel  = string.format("%s 1 (of %d)", mode, currentCount)
                local sendMostLabel = string.format("%s %d (of %d)", mode, currentCount - 1, currentCount)

                AddCustomMenuItem(sendOneLabel, function() 
                    this.TransferContextItem(bagId, slotIndex, 1) 
                end, MENU_ADD_OPTION_LABEL)

                AddCustomMenuItem(sendMostLabel, function() 
                    this.TransferContextItem(bagId, slotIndex, currentCount - 1) 
                end, MENU_ADD_OPTION_LABEL)
            end
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