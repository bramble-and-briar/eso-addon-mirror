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

local function ItemQualityToRGB(quality, itemLink)
--• Normal (White): #ffffff (or standard default interface white)
--• Fine (Green): #2dc50e (RGB: 45, 197, 14)
--• Superior (Blue): #3a92ff (RGB: 58, 146, 255)
--• Epic (Purple): #a02ef7 (RGB: 160, 46, 247)
--• Legendary (Gold): #eeca2a (RGB: 238, 202, 42)
--• Mythic (Orange / Red-Orange): #ff8200 (RGB: 255, 130, 0

    if quality == ITEM_QUALITY_NORMAL then
        return "|cffffff" .. itemLink .. "|cE2E209"
    elseif quality == ITEM_QUALITY_MAGIC then
        return "|c2dc50e" .. itemLink .. "|cE2E209"
    elseif quality == ITEM_QUALITY_ARCANE then
        return "|c3a92ff" .. itemLink .. "|cE2E209"
    elseif quality == ITEM_QUALITY_ARTIFACT then
        return "|ca02ef7" .. itemLink .. "|cE2E209"
    elseif quality == ITEM_QUALITY_LEGENDARY then
        return "|ceeca2a" .. itemLink .. "|cE2E209"
    else
        return "|cffffff" .. itemLink .. "|cE2E209" -- Default to white if unknown quality
    end
end

local function IsItemStackable(itemLink)
    return IsItemLinkStackable(itemLink)
end 

function GoldNation.Automation.OpenStore(event, self) -- Currently not selling. will need to look into it.
    

    -- Sell all junk
    SellAllJunk()

    -- Check if we have items to sell and if we are allowed to autosell
    if #savedVariables.DB_Sell > 0 and savedVariables.GN_AutoSell then
        for i = 1, #savedVariables.DB_Sell, 1 do
            local itemLink = savedVariables.DB_Sell[i]
            local bagSize = GetNumBagUsedSlots(BAG_BACKPACK)

            for j = 0, bagSize, 1 do
                local bagItemLink = GetItemLink(BAG_BACKPACK, j)
                if bagItemLink == itemLink then
                    local stack, maxStack = GetSlotStackSize(BAG_BACKPACK, j)
                    SellInventoryItem(BAG_BACKPACK, j, stack)
                    
                    GoldNation.DeliverMessage("Sold -> " .. tostring(bagItemLink) .. " " .. tostring(stack) .. "x (Sold)", "success")
                end
            end
        end
        
        -- Clear the sell database after selling items
        savedVariables.DB_Sell = {}
    end
end

function GoldNation.Automation.InventorySingleSlotUpdate(event, bagId, slotId, isNewItem, itemSoundCategory, updateReason, stackCountChange) --this updates alot
    --d("Gold Nation: Inventory single slot update event triggered.")
end

-- AutoLoot, AutoBind work, handler for everything doesnt work yet
function GoldNation.Automation.LootUpdated(event, self) --This triggers when the loot window is open
    -- If AutoLoot is disabled just return
    if savedVariables.GN_AutoLoot == false then
        return
    end

    -- Loot gold obviously!
    if savedVariables.AL_Gold then
        LootMoney()
        --for curt in pairs(LOOT_SHARED:GetLootCurrencyInformation()) do
        --    LootCurrency(curt)
        --end
    end

    -- Main loop to cycle loot window
    local num = GetNumLootItems()
    for i = 1, num, 1 do
        local lootId, name, _, count, quality, value, isQuest, stolen, _ = GetLootItemInfo(i)
        local link = GetLootItemLink(lootId)
        local itemType, specItemType = GetItemLinkItemType(link)

        -- Loot Armor
        if itemType == ITEMTYPE_ARMOR or itemType == ITEMTYPE_GLYPH_ARMOR or itemType == ITEMTYPE_ARMOR_TRAIT then
            if savedVariables.AL_Armour then 
                LootItemById(lootId)

                -- If we are collecting then collect it
                if savedVariables.AL_Collectables_Bind then 
                    if GetItemLinkSetCollectionStatus(link) == 1 or GetItemLinkSetCollectionStatus(link) == 3 then 
                        local bagSize = GetNumBagUsedSlots(BAG_BACKPACK)

                        for i = 0, bagSize, 1 do
                            local bagItemLink = GetItemLink(BAG_BACKPACK, i)
                            if bagItemLink == link then
                                BindItem(BAG_BACKPACK, i)
                            end
                        end
                    end
                end

                -- Handle the sell, discard, keep
                if savedVariables.AL_Armour_Handle == "Sell" then 
                    table.insert(savedVariables.DB_Sell, link)
                    GoldNation.DeliverMessage("Sell -> " .. tostring(ItemQualityToRGB(quality, link)) .. "(Looted)", "info")
                elseif savedVariables.AL_Armour_Handle == "Discard" then 
                    DestroyItem(BAG_BACKPACK, i)
                    GoldNation.DeliverMessage("Destroy -> " .. tostring(ItemQualityToRGB(quality, link)) .. "(Discarded)", "info")
                else
                    GoldNation.DeliverMessage("Keep -> " .. tostring(ItemQualityToRGB(quality, link)) .. "(Looted)", "info")
                end
            end
        end

        -- Item is a food or drink
        if itemType == ITEMTYPE_FOOD or itemType == ITEMTYPE_DRINK then
            
        end

        -- Item is a weapon
        if itemType == ITEMTYPE_WEAPON or itemType == ITEMTYPE_GLYPH_WEAPON or itemType == ITEMTYPE_WEAPON_TRAIT then
            if savedVariables.AL_Weapons then
                LootItemById(lootId)

                -- If we are collecting then collect it
                if savedVariables.AL_Collectables_Bind then 
                    if GetItemLinkSetCollectionStatus(link) == 1 or GetItemLinkSetCollectionStatus(link) == 3 then 
                        local bagSize = GetNumBagUsedSlots(BAG_BACKPACK)

                        for i = 0, bagSize, 1 do
                            local bagItemLink = GetItemLink(BAG_BACKPACK, i)
                            if bagItemLink == link then
                                BindItem(BAG_BACKPACK, i)
                            end
                        end
                    end
                end

                -- Handle the sell, discard, keep
                if savedVariables.AL_Weapons_Handle == "Sell" then 
                    table.insert(savedVariables.DB_Sell, link)
                    GoldNation.DeliverMessage("Sell -> " .. tostring(ItemQualityToRGB(quality, link)) .. "(Looted)", "info")
                elseif savedVariables.AL_Weapons_Handle == "Discard" then 
                    DestroyItem(BAG_BACKPACK, i)
                    GoldNation.DeliverMessage("Destroy -> " .. tostring(ItemQualityToRGB(quality, link)) .. "(Discarded)", "info")
                else
                    GoldNation.DeliverMessage("Keep -> " .. tostring(ItemQualityToRGB(quality, link)) .. "(Looted)", "info")
                end
            end
        end

        -- Item is a poison or a potion
        if itemType == ITEMTYPE_POISON or itemType == ITEMTYPE_POTION then
            if savedVariables.AL_Consumables then
                LootItemById(lootId)
                GoldNation.DeliverMessage("Keep -> " .. tostring(ItemQualityToRGB(quality, link)) .. "(Looted)", "info")
            end
        end

        if itemType == ITEMTYPE_CONTAINER or itemType == ITEMTYPE_CONTAINER_CURRENCY then
            LootItemById(lootId)
            GoldNation.DeliverMessage("Keep -> " .. tostring(ItemQualityToRGB(quality, link)) .. "(Container)", "info")
        end
        if itemType == ITEMTYPE_JEWELRY_RAW_TRAIT or itemType == ITEMTYPE_JEWELRY_TRAIT or itemType == ITEMTYPE_GLYPH_JEWELRY then
            if savedVariables.AL_Jewelry then
                LootItemById(lootId)

                -- If we are collecting then collect it
                if savedVariables.AL_Collectables_Bind then 
                    if GetItemLinkSetCollectionStatus(link) == 1 or GetItemLinkSetCollectionStatus(link) == 3 then 
                        local bagSize = GetNumBagUsedSlots(BAG_BACKPACK)

                        for i = 0, bagSize, 1 do
                            local bagItemLink = GetItemLink(BAG_BACKPACK, i)
                            if bagItemLink == link then
                                BindItem(BAG_BACKPACK, i)
                            end
                        end
                    end
                end

                -- Handle the sell, discard, keep
                if savedVariables.AL_Jewelry_Handle == "Sell" then 
                    table.insert(savedVariables.DB_Sell, link)
                    GoldNation.DeliverMessage("Sell -> " .. tostring(ItemQualityToRGB(quality, link)) .. "(Looted)", "info")
                elseif savedVariables.AL_Jewelry_Handle == "Discard" then 
                    DestroyItem(BAG_BACKPACK, i)
                    GoldNation.DeliverMessage("Destroy -> " .. tostring(ItemQualityToRGB(quality, link)) .. "(Discarded)", "info")
                else
                    GoldNation.DeliverMessage("Keep -> " .. tostring(ItemQualityToRGB(quality, link)) .. "(Looted)", "info")
                end
            end
        end
        if itemType == ITEMTYPE_TREASURE or itemType == ITEMTYPE_TROPHY or itemType == ITEMTYPE_COLLECTIBLE or itemType == ITEMTYPE_RACIAL_STYLE_MOTIF then
            LootItemById(lootId)
            GoldNation.DeliverMessage("Keep -> " .. tostring(ItemQualityToRGB(quality, link)) .. "(Looted)", "info")
        end
        if itemType == ITEMTYPE_TRASH then
            LootItemById(lootId)
            GoldNation.DeliverMessage("Keep -> " .. tostring(ItemQualityToRGB(quality, link)) .. "(Trash)", "info")    
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

