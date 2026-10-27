-- Core/InventoryCompanion_Scanning.lua
InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

this.Scanning = this.Scanning or {}
local scanning = this.Scanning

--- Scan a list of bags and return a structured table of item instances/slots, optionally filtered by a select function.
function scanning.GetBagContents(bagIdList, selectFunc)
    local contents = {}

    for _, bagId in ipairs(bagIdList) do
        if bagId == BAG_VIRTUAL then
            -- Special handling for Craft Bag iterator
            local slotIndex = GetNextVirtualBagSlotId(nil)
            while slotIndex do
                local itemId = GetItemId(bagId, slotIndex)
                if itemId and itemId > 0 then
                    local link = GetItemLink(bagId, slotIndex)
                    if link and link ~= "" then                   
                        local currentCount, maxCount = GetSlotStackSize(bagId, slotIndex)
                        local itemData = {
                            bagId = bagId,
                            slotIndex = slotIndex,
                            itemId = itemId,
                            link = link,
                            icon = GetItemLinkIcon(link),
                            count = currentCount,
                            maxCount = maxCount,
                        }
                        
                        if not selectFunc or selectFunc(itemData) then
                            table.insert(contents, itemData)
                        end
                    end
                end
                slotIndex = GetNextVirtualBagSlotId(slotIndex)
            end
        else
            -- Standard contiguous bags (Backpack, Banks, Chests)
            local bagSize = GetBagSize(bagId)
            for slotIndex = 0, bagSize - 1 do
                local itemId = GetItemId(bagId, slotIndex)
                if itemId and itemId > 0 then
                    local link = GetItemLink(bagId, slotIndex)
                    if link and link ~= "" then                   
                        local currentCount, maxCount = GetSlotStackSize(bagId, slotIndex)
                        local itemData = {
                            bagId = bagId,
                            slotIndex = slotIndex,
                            itemId = itemId,
                            link = link,
                            icon = GetItemLinkIcon(link),
                            count = currentCount,
                            maxCount = maxCount,
                        }                        
                        if not selectFunc or selectFunc(itemData) then
                            table.insert(contents, itemData)
                        end
                    end
                end
            end
        end
    end

    return contents
end