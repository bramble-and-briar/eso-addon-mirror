GoldNation.Automation = {}

--GoldNation.Modules = GoldNation.Modules or {}


local isOrnate = trait == ITEM_TRAIT_TYPE_ARMOR_ORNATE or trait == ITEM_TRAIT_TYPE_WEAPON_ORNATE or trait == ITEM_TRAIT_TYPE_JEWELRY_ORNATE



local function GetItemLinkSetCollectionStatus( itemLink )
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

local function IsItemInBag(itemLink)
    --BAG_BACKPACK
    --BAG_BANK
    local bagSize = GetNumBagUsedSlots(BAG_BACKPACK)

    for i = 1, bagSize, 1 do
        local bagItemLink = GetItemLink(BAG_BACKPACK, i)
        if bagItemLink == itemLink then
            return true
        end
    end

    return false
end

local function IsItemStackable(itemLink)
    return IsItemLinkStackable(itemLink)
end 

local function CollectAndBindItem(itemLink)

    for i = 1, bagSize, 1 do
        local bagItemLink = GetItemLink(BAG_BACKPACK, i)
        if bagItemLink == itemLink then
            BindItem(BAG_BACKPACK, i)
            
            d("Item " .. itemLink .. " has been bound.")
        end
    end
end

function GoldNation.Automation.OpenStore(event, self)
    --d("Gold Nation: Store open, there is x" .. #GoldNation.savedVariables.DB_Sell .. " items to sell.")
end

function GoldNation.Automation.InventorySingleSlotUpdate(event, bagId, slotId, isNewItem, itemSoundCategory, updateReason, stackCountChange) --this updates alot
    --d("Gold Nation: Inventory single slot update event triggered.")
end

function GoldNation.Automation.LootUpdated(event, self) --This triggers when the loot window is open
    if savedVariables.GN_AutoLoot == false then
        return
    end
    --LootMoney()
    --for curt in pairs(LOOT_SHARED:GetLootCurrencyInformation()) do
    --    LootCurrency(curt)
    --end

    local num = GetNumLootItems()
    --local bListedSetGearList = {}
    for i = 1, num, 1 do
        local lootId, name, _, _, _, _, _, _, _ = GetLootItemInfo(i)
        local link = GetLootItemLink(lootId)
        --and IsItemStackable(link)
        if savedVariables.AL_Stackables then
            LootItemById(lootId)
            GoldNation.DeliverMessage("Loot -> " .. link .. "(Stackable)", "info")
        elseif savedVariables.AL_Collectables and (GetItemLinkSetCollectionStatus(link) == 1 or GetItemLinkSetCollectionStatus(link) == 3) then
            -- Loot something we dont have already
            LootItemById(lootId)

            if savedVariables.AL_Collectables_Bind then 
                local bagSize = GetNumBagUsedSlots(BAG_BACKPACK)

                for i = 1, bagSize, 1 do
                    local bagItemLink = GetItemLink(BAG_BACKPACK, i)
                    if bagItemLink == link then
                        BindItem(BAG_BACKPACK, i)
                        GoldNation.DeliverMessage("Bind -> " .. link .. "(Not collected)", "info")
                    
                    end
                end
            end

            if savedVariables.AL_Collectables_Handle == "Discard" then
                local bagSize = GetNumBagUsedSlots(BAG_BACKPACK)

                for i = 1, bagSize, 1 do
                    local bagItemLink = GetItemLink(BAG_BACKPACK, i)
                    if bagItemLink == link then
                        DestroyItem(BAG_BACKPACK, i)
                        GoldNation.DeliverMessage("Destroy -> " .. link .. "(Discarded)", "info")
                    end
                end
                
            elseif savedVariables.AL_Collectables_Handle == "Sell" then
                --table.insert(GoldNation.savedVariables.DB_Sell, link)
                
                GoldNation.DeliverMessage("Sell -> " .. link .. "(Looted)", "info")
            else
                GoldNation.DeliverMessage("Keep -> " .. link .. "(Looted)", "info")
            end

            
        else
            LootItemById(lootId)
            GoldNation.DeliverMessage("Loot -> " .. link, "info")
        end

    end

    -- Close loot window if no items are left to loot
    if GetNumLootItems() <= 0 then
        SCENE_MANAGER:HideCurrentScene()
    end
end

function GoldNation.Automation.LootReceived(event, receivedBy, itemLink, quantity, lootType, self)
    --d("Gold Nation: Loot received " .. itemLink .. " x" .. quantity .. " by " .. receivedBy .. ".")
end

function GoldNation.Automation.LootClosed(event, self) --This triggers when the loot window is closed
    --d("Gold Nation: Loot closed event triggered.")
end

function GoldNation.Automation.Initialize()
    -- AutoLoot 

    
end

