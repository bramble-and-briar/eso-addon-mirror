--[[
   Yudo's Inventory Processor
   Copyright (C) 2025-2026 YudoAn

   This file is part of Yudo's Inventory Processor.

   Yudo's Inventory Processor is free software; you can redistribute it and/or modify
   it under the terms of the Artistic License 2.0.

   For full license details, please see the LICENSE file included with this distribution.
--]]

-- Localizing ESO API functions for faster register access within loops
local GetItemLink                        = GetItemLink
local GetItemLinkItemType                = GetItemLinkItemType
local GetItemInfo                        = GetItemInfo
local GetItemName                        = GetItemName
local GetItemTraitInformation            = GetItemTraitInformation
local GetItemId                          = GetItemId
local GetBagSize                         = GetBagSize
local IsItemJunk                         = IsItemJunk
local IsItemPlayerLocked                 = IsItemPlayerLocked
local GetItemLinkItemId                  = GetItemLinkItemId
local GetSlotStackSize                   = GetSlotStackSize
local GetItemLinkRequiredChampionPoints = GetItemLinkRequiredChampionPoints
local IsItemBound                        = IsItemBound
local GetItemType                        = GetItemType
local GetItemLinkActorCategory           = GetItemLinkActorCategory
local IsItemLinkCrafted                  = IsItemLinkCrafted
local IsItemLinkReconstructed            = IsItemLinkReconstructed
local IsItemInArmory                     = IsItemInArmory
local IsItemLinkRecipeKnown              = IsItemLinkRecipeKnown
local IsItemStolen                       = IsItemStolen
local CanItemBeSmithingExtractedOrRefined = CanItemBeSmithingExtractedOrRefined

-- String optimization
local stringFind                 = string.find
local stringLower                = string.lower

local YIP_addonName = "YudosInventoryProcessor" -- Fast local variable
local YIP = {}
YIP.name = YIP_addonName
YIP.isAutoJunking = false -- Semaphore Fix: Prevent auto-junk from saving to memory
YIP.isDeconstructing = 0 -- Track if we are in a decon batch
YIP.deconstructSuccessful = false -- Verify if at least one item was decon'd via event
local inventoryTimer = false -- High-speed debounce flag
local filletTimer = nil
local refineTimer = nil
local deconTimer = nil
local function IsDolgubonBusy()
    if not YIP.savedVars.global.respectLWC then return false end
    if WritCreater then
        -- 1. Check if LWC is currently crafting at a station
        -- This flag is set to true by LWC while it's automating crafts
        if WritCreater.isCrafting then return true end

        -- 2. Check if LWC is at a bank and has writs to fulfill
        -- writSearch returns (table, hasAny)
        if WritCreater.writSearch and WritCreater.GetSettings then
            local _, hasAnyWrits = WritCreater.writSearch()
            local shouldGrab = WritCreater:GetSettings().shouldGrab
            
            -- If the player has writs and LWC is configured to withdraw them
            if hasAnyWrits and shouldGrab then
                return true
            end
        end
    end
    return false
end

YIP.Whitelists = {
    Traits = {
        "Nirncrux", "Aurbic Amber", "Slaughterstone",
        "Gilding Wax", "Dawn-Prism", "Dibellium", "Titanium"
    }
}

local DELAY_TICK = 10  -- ms between actions (Reduced from 20 to 10)

local defaults = {
    accountWide = true,
    global = {
        respectFCOIS = true,
        respectLWC = true
    },
    decon = { 
        deconstruct = false, 
        refine = false, 
        fillet = false,
        qualityThreshold = 2, -- Default Green (Fine)
        includeBackpack = false,
        includeBank = false,
    },
    merchant = { 
        markJunk = false, 
        sellJunk = false, 
        sellNormalJunk = false,
        fenceJunk = false,
        companionSellThreshold = 0,
        repair = false,
        -- Granular Junk Rules
        junkRules = {
            trash = false,
            treasures = false,
            traitItems = false,
            styleMats = false,
            scripts = false,
            ornate = false,
            foodDrink = false,
            potions = false,
            lowLevelMats = false,
            lowQualityKnownRecipes = false,
        }
    }, 
    banker = {
        depositMats = false,
        depositCurrencies = false,
        minCurrency = { gold = 50000, telvar = 100, ap = 50000, writ = 0 }
    },
    junkMemory = {}
}

function YIP.Initialize()
    local charSavedVars = (ZO_SavedVars.NewCharacterIdSettings and ZO_SavedVars:NewCharacterIdSettings("YudosInventoryProcessorVars", 1, nil, defaults, GetWorldName())) or ZO_SavedVars:New("YudosInventoryProcessorVars", 1, nil, defaults, GetWorldName())
    local acctSavedVars = ZO_SavedVars:NewAccountWide("YudosInventoryProcessorVars", 1, nil, defaults, GetWorldName())

    YIP.charSavedVars = charSavedVars
    YIP.acctSavedVars = acctSavedVars

    if charSavedVars.accountWide then
        YIP.savedVars = acctSavedVars
    else
        YIP.savedVars = charSavedVars
    end

    YIP.savedVars.banker = YIP.savedVars.banker or {}
    YIP.savedVars.banker.minCurrency = YIP.savedVars.banker.minCurrency or {}
    
    -- Migration/Defaults safety checks
    YIP.savedVars.decon = YIP.savedVars.decon or {}
    if YIP.savedVars.decon.includeBackpack == nil then YIP.savedVars.decon.includeBackpack = false end
    if YIP.savedVars.decon.includeBank == nil then YIP.savedVars.decon.includeBank = false end
    YIP.savedVars.merchant = YIP.savedVars.merchant or {}
    YIP.savedVars.merchant.junkRules = YIP.savedVars.merchant.junkRules or defaults.merchant.junkRules
    if YIP.savedVars.merchant.fenceJunk == nil then YIP.savedVars.merchant.fenceJunk = false end
    if YIP.savedVars.merchant.sellNormalJunk == nil then YIP.savedVars.merchant.sellNormalJunk = YIP.savedVars.merchant.sellJunk end
    if YIP.savedVars.merchant.companionSellThreshold == nil then YIP.savedVars.merchant.companionSellThreshold = 0 end
    YIP.savedVars.global = YIP.savedVars.global or defaults.global
    if YIP.savedVars.global.respectLWC == nil then YIP.savedVars.global.respectLWC = true end
    
    -- SILENT DATA MIGRATION: Convert old strings to numbers once
    local oldVal = YIP.savedVars.decon.qualityThreshold
    if type(oldVal) == "string" then
        if stringFind(oldVal, "Epic") then YIP.savedVars.decon.qualityThreshold = 4
        elseif stringFind(oldVal, "Superior") then YIP.savedVars.decon.qualityThreshold = 3
        else YIP.savedVars.decon.qualityThreshold = 2 end
    end
    
    -- Ensure everything is a number for the logic
    YIP.savedVars.decon.qualityThreshold = tonumber(YIP.savedVars.decon.qualityThreshold) or 2
    
    YIP.savedVars.global = YIP.savedVars.global or defaults.global
    YIP.savedVars.junkMemory = YIP.savedVars.junkMemory or {}

    -- Register the Confirmation Popup
    ZO_Dialogs_RegisterCustomDialog("YIP_CONFIRM_RESET_MEMORY", {
        title = { text = "Reset Junk Memory" },
        mainText = { text = "Are you sure you want to clear memory of items you have manually marked or unmarked as junk?" },
        buttons = {
            {
                text = SI_DIALOG_CONFIRM,
                callback = function() 
                    YIP.savedVars.junkMemory = {} 
                    d("Cleared junk memory.")
                end,
            },
            {
                text = SI_DIALOG_CANCEL,
            },
        },
        showWithoutMainGui = true,
    })

    ZO_PostHook("SetItemIsJunk", function(bagId, slotIndex, isJunk)
        -- Strictly respect the markJunk toggle for Junk Memory writing
        -- SEMAPHORE FIX: ONLY record if the addon isn't currently doing an auto-junk run
        if YIP.savedVars.merchant.markJunk and not YIP.isAutoJunking then
            local id = GetItemLinkItemId(GetItemLink(bagId, slotIndex))
            if id > 0 then YIP.savedVars.junkMemory[id] = isJunk end
        end
    end)

    if LibAddonMenu2 then YIP.InitializeSettings() end
    
    -- Event registrations moved into Initialize for a clean startup flow
    EVENT_MANAGER:RegisterForEvent(YIP_addonName, EVENT_OPEN_BANK, function() YIP.OnOpenBank() end)
    EVENT_MANAGER:RegisterForEvent(YIP_addonName, EVENT_OPEN_STORE, function() YIP.OnOpenStore(false) end)
    EVENT_MANAGER:RegisterForEvent(YIP_addonName, EVENT_OPEN_FENCE, function() YIP.OnOpenStore(true) end)
    EVENT_MANAGER:RegisterForEvent(YIP_addonName, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(...) YIP.OnInventoryUpdate(...) end)
    EVENT_MANAGER:AddFilterForEvent(YIP_addonName, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK, REGISTER_FILTER_IS_NEW_ITEM, true)
    EVENT_MANAGER:RegisterForEvent(YIP_addonName, EVENT_CRAFTING_STATION_INTERACT, function() YIP.OnCraftingStationInteract() end)
    EVENT_MANAGER:RegisterForEvent(YIP_addonName, EVENT_END_CRAFTING_STATION_INTERACT, function()
        -- Unregister all temporary success checks
        EVENT_MANAGER:UnregisterForEvent(YIP_addonName .. "_FilletCheck", EVENT_CRAFT_COMPLETED)
        EVENT_MANAGER:UnregisterForEvent(YIP_addonName .. "_RefineCheck", EVENT_CRAFT_COMPLETED)
        EVENT_MANAGER:UnregisterForEvent(YIP_addonName .. "_DeconCheck", EVENT_CRAFT_COMPLETED)
        
        -- Reset deconstruction counter semaphore
        YIP.isDeconstructing = 0
    end)

    -- Pre-process Whitelist for faster lookups
    for category, list in pairs(YIP.Whitelists) do
        for i, val in ipairs(list) do
            list[i] = stringLower(val)
        end
    end
end

function YIP.IsFCOISLocked(bagId, slotIndex, lockType)
    if not YIP.savedVars.global.respectFCOIS then return false end
    if not FCOIS then return false end

    if lockType == "decon" then
        return FCOIS.IsDeconstructionLocked(bagId, slotIndex, false)
    elseif lockType == "sell" then
        return FCOIS.IsVendorSellLocked(bagId, slotIndex)
    elseif lockType == "refine" then
        return FCOIS.IsRefinementLocked(bagId, slotIndex)
    end
    return false
end

function YIP.IsWhitelisted(name)
    name = stringLower(name)
    for _, list in pairs(YIP.Whitelists) do
        for _, target in ipairs(list) do
            -- Use plain string search (4th arg = true) to handle hyphens correctly
            if stringFind(name, target, 1, true) then return true end
        end
    end
    return false
end

function YIP.GetMaterialRank(link, itemType)
    if itemType == ITEMTYPE_BLACKSMITHING_RAW_MATERIAL or 
       itemType == ITEMTYPE_CLOTHIER_RAW_MATERIAL or 
       itemType == ITEMTYPE_WOODWORKING_RAW_MATERIAL or 
       itemType == ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL then
       
       if GetItemLinkRefinedMaterialItemLink then
           local refined = GetItemLinkRefinedMaterialItemLink(link)
           if refined and refined ~= "" then
               return GetItemLinkRequiredCraftingSkillRank(refined)
           end
       end
    end
    return GetItemLinkRequiredCraftingSkillRank(link)
end

function YIP.ShouldBeJunk(bagId, slotIndex)
    local link = GetItemLink(bagId, slotIndex)
    
    -- Use Link method for better reliability with specialized types
    local itemType, specializedType = GetItemLinkItemType(link)
    
    -- Fallback to bag method if link method returns 0 (unlikely but safe)
    if itemType == 0 then 
        itemType, specializedType = GetItemType(bagId, slotIndex) 
    end

    local _, _, _, _, _, _, _, quality = GetItemInfo(bagId, slotIndex)
    local id = GetItemLinkItemId(link)
    local name = GetItemName(bagId, slotIndex)
    local rules = YIP.savedVars.merchant.junkRules

    -- 0. FCOIS Check
    if YIP.IsFCOISLocked(bagId, slotIndex, "sell") then return false end

    -- 1. Check Memory (Manual Override) - Strictly respect the markJunk toggle
    if YIP.savedVars.merchant.markJunk and YIP.savedVars.junkMemory[id] ~= nil then 
        return YIP.savedVars.junkMemory[id] 
    end

    -- 2. Crafted Item Protection - Never junk crafted items unless manually marked
    if IsItemLinkCrafted(link) then return false end

    -- 3. Whitelist (Name Check) - Always-respected
    if YIP.IsWhitelisted(name) then return false end

    -- 4. Crown Store Protection - Global
    -- Protects Mimic Stones, Repair Kits, Potions, Meals, Poisons, etc.
    if stringFind(name, "Crown", 1, true) then return false end

    -- 5. Safe Items (Boosters / Furnishing Mats)
    -- Style mats are intentionally NOT here so they fall through to logic below unless whitelisted
    if itemType == ITEMTYPE_BLACKSMITHING_BOOSTER or itemType == ITEMTYPE_CLOTHIER_BOOSTER or
       itemType == ITEMTYPE_WOODWORKING_BOOSTER or itemType == ITEMTYPE_JEWELRYCRAFTING_BOOSTER or
       itemType == ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER or itemType == ITEMTYPE_FURNISHING_MATERIAL then
       return false
    end

    -- 6. Specific Target Logic (Treasures)
    if rules.treasures then
        -- specializedType 80/81/2550 = Treasure
        if specializedType == 80 or specializedType == 81 or specializedType == 2550 then return true end
    end

    -- 7. General Junk Types
    if rules.trash and itemType == ITEMTYPE_TRASH then return true end
    
    -- 8. Trait Items
    if rules.traitItems then
        if itemType == ITEMTYPE_WEAPON_TRAIT or 
           itemType == ITEMTYPE_ARMOR_TRAIT or 
           itemType == ITEMTYPE_JEWELRY_TRAIT or 
           itemType == ITEMTYPE_JEWELRYCRAFTING_RAW_TRAIT or
           stringFind(name, "Pulverized", 1, true) then
           return true 
        end
    end

    -- Style Materials (including specializedType 800)
    if rules.styleMats and (itemType == ITEMTYPE_STYLE_MATERIAL or specializedType == 800) then return true end

    -- Bound Scripts
    if rules.scripts then
        if (specializedType == 3250 or specializedType == 3251 or specializedType == 3252) and IsItemBound(bagId, slotIndex) then
            return true
        end
    end

    -- 9. Quality Checks
    -- Check for Ornate Trait
    if rules.ornate and GetItemTraitInformation(bagId, slotIndex) == ITEM_TRAIT_INFORMATION_ORNATE then return true end

    -- Food/Drink (Renamed from consumables)
    if rules.foodDrink then
        if (itemType == ITEMTYPE_FOOD or itemType == ITEMTYPE_DRINK) and quality < ITEM_DISPLAY_QUALITY_ARCANE then return true end
    end

    -- Known Recipes/Plans
    if rules.lowQualityKnownRecipes then
        if itemType == ITEMTYPE_RECIPE and quality < ITEM_DISPLAY_QUALITY_ARCANE and IsItemLinkRecipeKnown(link) then return true end
    end

    -- Potions & Poisons
    if rules.potions and (itemType == ITEMTYPE_POTION or itemType == ITEMTYPE_POISON) then
        local cp = GetItemLinkRequiredChampionPoints(link)
        -- Logic: If (Level < CP150) AND (Quality < Arcane), then Junk.
        if cp < 150 and quality < ITEM_DISPLAY_QUALITY_ARCANE then return true end
    end
    
    -- 10. Low Level Crafting Materials (Below CP150)
    if rules.lowLevelMats then
        if itemType == ITEMTYPE_ENCHANTING_RUNE_POTENCY then
            if GetItemLinkRequiredCraftingSkillRank(link) < 10 then return true end
        end

        if itemType == ITEMTYPE_BLACKSMITHING_MATERIAL or itemType == ITEMTYPE_BLACKSMITHING_RAW_MATERIAL or
           itemType == ITEMTYPE_CLOTHIER_MATERIAL or itemType == ITEMTYPE_CLOTHIER_RAW_MATERIAL or
           itemType == ITEMTYPE_WOODWORKING_MATERIAL or itemType == ITEMTYPE_WOODWORKING_RAW_MATERIAL then
           if YIP.GetMaterialRank(link, itemType) < 10 then return true end
        end

        if itemType == ITEMTYPE_JEWELRYCRAFTING_MATERIAL or itemType == ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL then
           if YIP.GetMaterialRank(link, itemType) < 5 then return true end
        end

        if itemType == ITEMTYPE_POTION_BASE or itemType == ITEMTYPE_POISON_BASE then
           if GetItemLinkRequiredCraftingSkillRank(link) < 8 then return true end
        end
    end

    return false
end

function YIP.ProcessNewItem(bagId, slotIndex)
    if YIP.ShouldBeJunk(bagId, slotIndex) then 
        YIP.isAutoJunking = true
        SetItemIsJunk(bagId, slotIndex, true) 
        YIP.isAutoJunking = false
    end
end

function YIP.OnInventoryUpdate(_, bagId, slotIndex, isNewItem)
    if not isNewItem then return end
    if not YIP.savedVars.merchant.markJunk then return end
    
    -- Process ONLY the item that was just added. O(1) operation.
    YIP.ProcessNewItem(bagId, slotIndex)
end

function YIP.OnOpenBank()
    -- COMPATIBILITY: Stop if Dolgubon is performing banking tasks
    if IsDolgubonBusy() then return end

    -- 1. Exit if both settings are disabled
    if not YIP.savedVars.banker.depositCurrencies and not YIP.savedVars.banker.depositMats then return end

    -- 2. The Definitive Check: What bag is the bank actually showing?
    -- GetBankingBag() returns BAG_BANK for personal banks and assistants.
    -- It returns a different ID (like BAG_HOUSE_BANK_ONE) for storage chests.
    if GetBankingBag() ~= BAG_BANK then 
        return 
    end

    -- 3. Check for Guild Bank (Skip based on requirement)
    if IsGuildBankOpen() then 
        return 
    end

    -- 4. Execute for Personal Bank / Assistant
    if IsBankOpen() then
        zo_callLater(function()
            -- Re-verify we are still looking at the correct bag after the delay
            if not IsBankOpen() or GetBankingBag() ~= BAG_BANK then return end
            YIP.RunBankerQueue(BAG_BANK)
        end, 0) 
    end
end

function YIP.RunBankerQueue(targetBagId)
    local targetBag = targetBagId or BAG_BANK
    -- REMOVED: Stacking inventory at start to increase performance

    zo_callLater(function()
        if not IsBankOpen() and not IsGuildBankOpen() then return end
        
        local queue = {}
        local reservedSlots = {} 
        local report = { items = 0, currency = {}, processedSlots = {} }
        
        -- 1. Build Currency Queue (Process Immediately)
        local function GetAmt(type)
            if type == 1 and GetCurrentMoney then return GetCurrentMoney() end
            if type == 2 and GetAlliancePoints then return GetAlliancePoints() end
            if type == 3 and GetTelvarStones then return GetTelvarStones() end
            if GetCurrencyAmount then return GetCurrencyAmount(type, 0) end 
            return 0
        end

        if YIP.savedVars.banker.depositCurrencies and targetBag == BAG_BANK then
            local curMap = {
                {id=1, name="Gold", key="gold"},
                {id=2, name="AP", key="ap"},
                {id=3, name="Tel Var", key="telvar"},
                {id=4, name="Writ", key="writ"}
            }
            for _, c in ipairs(curMap) do
                local current = GetAmt(c.id)
                local keep = YIP.savedVars.banker.minCurrency[c.key] or 0
                local amount = math.floor(current - keep)
                if amount > 0 then
                    if DepositCurrencyIntoBank then
                        DepositCurrencyIntoBank(c.id, amount)
                    end
                    table.insert(report.currency, amount .. " " .. c.name)
                end
            end
        end

        -- 2. INDEX EVERYTHING ONCE
        local bankIndex = {}
        local emptySlots = {} -- Index empty slots for O(1) retrieval

        for slot = 0, GetBagSize(targetBag) - 1 do
            local id = GetItemId(targetBag, slot)
            if id > 0 then
                bankIndex[id] = bankIndex[id] or {}
                table.insert(bankIndex[id], slot)
            else
                table.insert(emptySlots, slot) -- Store empty slot index
            end
        end

        -- Helper to get simulated stack info
        local function GetTargetSlotInfo(bag, slot)
            if reservedSlots[slot] then
                return reservedSlots[slot].count, reservedSlots[slot].max
            end
            local _, count = GetItemInfo(bag, slot)
            local _, max = GetSlotStackSize(bag, slot)
            return count, max
        end

        -- Helper to find a stacking candidate using optimized lookup
        local function FindSlotToStack(itemId, count)
            local slots = bankIndex[itemId]
            if slots then
                for _, slot in ipairs(slots) do
                    local current, max = GetTargetSlotInfo(targetBag, slot)
                    if current < max then return slot, (max - current) end
                end
            end
            return nil, 0
        end

        -- O(1) Empty Slot Finder
        local function FindEmptySlot()
            if #emptySlots > 0 then
                -- table.remove without an index pops the LAST element instantly (O(1))
                return table.remove(emptySlots) 
            end
            return nil
        end

        -- 2. Build Item Queue with Direct Stacking Logic
        if YIP.savedVars.banker.depositMats then
            for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
                if YIP.IsItemMaterial(BAG_BACKPACK, slot) and not IsItemJunk(BAG_BACKPACK, slot) then
                    local itemId = GetItemId(BAG_BACKPACK, slot)
                    local _, count = GetItemInfo(BAG_BACKPACK, slot)
                    local remaining = count

                    local safetyIterator = 0
                    -- Attempt to stack into existing items
                    while remaining > 0 and safetyIterator < 215 do
                        safetyIterator = safetyIterator + 1
                        local targetSlot, space = FindSlotToStack(itemId, remaining)
                        
                        if targetSlot then
                            local moveAmt = math.min(remaining, space)
                            table.insert(queue, {type="item", src=slot, dest=targetSlot, count=moveAmt})
                            
                            -- Update our reservation tracker
                            if not reservedSlots[targetSlot] then
                                local c, m = GetTargetSlotInfo(targetBag, targetSlot)
                                reservedSlots[targetSlot] = { count = c, max = m }
                            end
                            reservedSlots[targetSlot].count = reservedSlots[targetSlot].count + moveAmt
                            
                            remaining = remaining - moveAmt
                        else
                            -- If no stacking space, start a NEW stack in an empty slot
                            local emptySlot = FindEmptySlot()
                            if emptySlot then
                                local _, max = GetSlotStackSize(BAG_BACKPACK, slot)
                                local moveAmt = math.min(remaining, max)
                                
                                table.insert(queue, {type="item", src=slot, dest=emptySlot, count=moveAmt})
                                reservedSlots[emptySlot] = { count = moveAmt, max = max }
                                
                                -- FIX: Add this new slot to the index so subsequent items can stack into it!
                                bankIndex[itemId] = bankIndex[itemId] or {}
                                table.insert(bankIndex[itemId], emptySlot)
                                
                                remaining = remaining - moveAmt
                            else
                                break -- Bank full
                            end
                        end
                    end
                end
            end
        end

        -- Process Queue
        local function Process()
            if not IsBankOpen() and not IsGuildBankOpen() then return end
            if #queue == 0 then
                -- Done: Report and final stack
                local msgParts = {}
                if report.items > 0 then 
                    table.insert(msgParts, string.format("%d %s", report.items, report.items == 1 and "item" or "items")) 
                end
                for _, cur in ipairs(report.currency) do table.insert(msgParts, cur) end
                if #msgParts > 0 then d("Deposited " .. table.concat(msgParts, ", ") .. ".") end
                
                zo_callLater(function()
                    if not IsBankOpen() and not IsGuildBankOpen() then return end
                    if StackBag then 
                        StackBag(targetBag) 
                        StackBag(BAG_BACKPACK) -- (New)
                    end
                end, 10) -- Reduced delay for final stacking
                return
            end

            -- Pull exactly one task
            local task = table.remove(queue, 1)

            if task.type == "item" then
                if CallSecureProtected then
                    CallSecureProtected("RequestMoveItem", BAG_BACKPACK, task.src, targetBag, task.dest, task.count)
                else
                    RequestMoveItem(BAG_BACKPACK, task.src, targetBag, task.dest, task.count)
                end
                
                -- Only increment the count if we haven't counted this backpack slot yet
                if not report.processedSlots[task.src] then
                    report.items = report.items + 1
                    report.processedSlots[task.src] = true
                end
            end

            -- Schedule next single item move
            zo_callLater(Process, 10) -- Reduced from 20ms to 10ms for faster depositing
        end

        Process()
    end, 0) -- Reduced from 200 to 0 for instant start
end

function YIP.IsItemMaterial(bagId, slotIndex)
    local link = GetItemLink(bagId, slotIndex)
    local itemType, specializedType = GetItemLinkItemType(link)
    
    -- Explicitly check whitelisted names to ensure Pulverized items are caught even if ItemType is weird
    local name = GetItemName(bagId, slotIndex)
    if YIP.IsWhitelisted(name) then return true end
    
    if itemType == ITEMTYPE_BLACKSMITHING_RAW_MATERIAL or itemType == ITEMTYPE_BLACKSMITHING_MATERIAL or
       itemType == ITEMTYPE_CLOTHIER_RAW_MATERIAL or itemType == ITEMTYPE_CLOTHIER_MATERIAL or
       itemType == ITEMTYPE_WOODWORKING_RAW_MATERIAL or itemType == ITEMTYPE_WOODWORKING_MATERIAL or
       itemType == ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL or itemType == ITEMTYPE_JEWELRYCRAFTING_MATERIAL or
       itemType == ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER or itemType == ITEMTYPE_JEWELRYCRAFTING_BOOSTER or
       itemType == ITEMTYPE_BLACKSMITHING_BOOSTER or itemType == ITEMTYPE_CLOTHIER_BOOSTER or itemType == ITEMTYPE_WOODWORKING_BOOSTER or
       itemType == ITEMTYPE_STYLE_MATERIAL or specializedType == 800 or
       itemType == ITEMTYPE_WEAPON_TRAIT or itemType == ITEMTYPE_ARMOR_TRAIT or itemType == ITEMTYPE_JEWELRY_TRAIT or itemType == ITEMTYPE_JEWELRYCRAFTING_RAW_TRAIT or
       itemType == ITEMTYPE_REAGENT or itemType == ITEMTYPE_INGREDIENT or itemType == ITEMTYPE_POISON_BASE or itemType == ITEMTYPE_POTION_BASE or
       itemType == ITEMTYPE_ENCHANTING_RUNE_POTENCY or itemType == ITEMTYPE_ENCHANTING_RUNE_ASPECT or itemType == ITEMTYPE_ENCHANTING_RUNE_ESSENCE or
       itemType == ITEMTYPE_SCRIBING_INK or
       itemType == ITEMTYPE_FURNISHING_MATERIAL or itemType == ITEMTYPE_RAW_MATERIAL then
       return true
    end
    
    return false
end

function YIP.ShouldDeconstruct(bagId, slotIndex)
    -- FCOIS Check
    if YIP.IsFCOISLocked(bagId, slotIndex, "decon") then return false end

    -- Engine Check: Can this item actually be deconstructed?
    if not CanItemBeSmithingExtractedOrRefined(bagId, slotIndex) then return false end

    local link = GetItemLink(bagId, slotIndex)
    local traitInfo = GetItemTraitInformation(bagId, slotIndex)
    
    -- Safety: Never deconstruct crafted, reconstructed, researchable, armory, or transmuted items
    if IsItemLinkCrafted(link) or IsItemLinkReconstructed(link) then return false end
    if traitInfo == ITEM_TRAIT_INFORMATION_CAN_BE_RESEARCHED or traitInfo == ITEM_TRAIT_INFORMATION_RETRAITED then return false end
    if IsItemInArmory(bagId, slotIndex) then return false end

    local itemType = GetItemLinkItemType(link)
    local _, _, _, _, _, _, _, quality = GetItemInfo(bagId, slotIndex)

    if itemType ~= ITEMTYPE_WEAPON and 
       itemType ~= ITEMTYPE_ARMOR and 
       itemType ~= ITEMTYPE_JEWELRY and
       itemType ~= ITEMTYPE_GLYPH_ARMOR and 
       itemType ~= ITEMTYPE_GLYPH_JEWELRY and 
       itemType ~= ITEMTYPE_GLYPH_WEAPON then
       return false
    end

    -- Check Max Quality setting
    -- SAFETY: tonumber conversion to prevent string < number errors
    local threshold = tonumber(YIP.savedVars.decon.qualityThreshold) or 2
    if quality > threshold then return false end
    
    -- Always skip Ornate items (better to sell)
    if traitInfo == ITEM_TRAIT_INFORMATION_ORNATE then return false end
    
    return true
end

function YIP.OnCraftingStationInteract()
    -- COMPATIBILITY: Stop if Dolgubon is currently crafting writs
    if IsDolgubonBusy() then return end

    if not YIP.savedVars.decon.deconstruct and not YIP.savedVars.decon.refine and not YIP.savedVars.decon.fillet then return end

    local session = { refined = 0, filleted = 0 }

    local function RunCycle()
        local stationType = GetCraftingInteractionType()
        local interactionMode = GetCraftingInteractionMode()

        -- FIX: Exit only if BOTH the station type is invalid AND we aren't in universal mode
        if stationType == CRAFTING_TYPE_INVALID and interactionMode ~= CRAFTING_INTERACTION_MODE_UNIVERSAL_DECONSTRUCTION then 
            return 
        end

        local isUniversal = (interactionMode == CRAFTING_INTERACTION_MODE_UNIVERSAL_DECONSTRUCTION)

        -- 1. FILLET LOGIC (Modified for batch processing)
        if not isUniversal and stationType == CRAFTING_TYPE_PROVISIONING and YIP.savedVars.decon.fillet then
            local fishQueue = {}

            -- Scan everything and collect all fish first
            for _, bag in ipairs({BAG_BACKPACK, BAG_BANK}) do
                for slot = 0, GetBagSize(bag) - 1 do
                    local itemType = GetItemLinkItemType(GetItemLink(bag, slot))
                    if itemType == ITEMTYPE_FISH and not IsItemPlayerLocked(bag, slot) then
                        -- FCOIS check removed as requested
                        local _, stackSize = GetItemInfo(bag, slot)
                        table.insert(fishQueue, {bag = bag, slot = slot, qty = stackSize})
                    end
                end
            end

            -- Process the entire batch
            if #fishQueue > 0 then
                PrepareDeconstructMessage()
                for _, fish in ipairs(fishQueue) do
                    AddItemToDeconstructMessage(fish.bag, fish.slot, fish.qty)
                end
                
                -- Register for Success Check ONLY before sending the request
                EVENT_MANAGER:RegisterForEvent(YIP_addonName .. "_FilletCheck", EVENT_CRAFT_COMPLETED, function()
                    EVENT_MANAGER:UnregisterForEvent(YIP_addonName .. "_FilletCheck", EVENT_CRAFT_COMPLETED)
                    if filletTimer then zo_removeCallLater(filletTimer); filletTimer = nil end
                    session.filleted = session.filleted + #fishQueue
                    zo_callLater(RunCycle, 200) 
                end)
                
                if filletTimer then zo_removeCallLater(filletTimer) end
                filletTimer = zo_callLater(function() 
                    EVENT_MANAGER:UnregisterForEvent(YIP_addonName .. "_FilletCheck", EVENT_CRAFT_COMPLETED) 
                    filletTimer = nil
                end, 1000)
                
                SendDeconstructMessage()
                return 
            elseif session.filleted > 0 then
                -- This only triggers when fishQueue is 0 (all done) but we filleted something this session
                d("Filleted fish.")
                session.filleted = 0 -- Reset so it doesn't print again in the next tick
            end
        end

        local totals = {}
        local refineQueue = {}
        local deconQueue = {}

        -- 2. REFINING AND DECONSTRUCTION LOGIC
        -- FIX: Hardcode the bags to scan, similar to Filleting logic
        local bagsToScan = {BAG_BACKPACK, BAG_BANK}

        for _, bag in ipairs(bagsToScan) do
            for slot = 0, GetBagSize(bag) - 1 do
                local link = GetItemLink(bag, slot)
                
                if link ~= "" then
                    -- COMPANION GEAR PROTECTION (STATION)
                    if GetItemLinkActorCategory(link) ~= GAMEPLAY_ACTOR_CATEGORY_COMPANION then
                        local itemType = GetItemLinkItemType(link)
                        local skillType = GetItemLinkCraftingSkillType(link)
                        local isLocked = IsItemPlayerLocked(bag, slot)
                        
                        -- 1. REFINING: Always runs for both bags if the main Refine toggle is ON
                        local isValidMaterial = false
                        if not isUniversal and YIP.savedVars.decon.refine then
                            -- Fallback check for ITEMTYPE_RAW_MATERIAL
                            local isRawFallback = (itemType == ITEMTYPE_RAW_MATERIAL)
                            
                            if stationType == CRAFTING_TYPE_BLACKSMITHING then
                                isValidMaterial = (itemType == ITEMTYPE_BLACKSMITHING_RAW_MATERIAL or itemType == ITEMTYPE_BLACKSMITHING_RAW_BOOSTER or isRawFallback)
                            elseif stationType == CRAFTING_TYPE_CLOTHIER then
                                isValidMaterial = (itemType == ITEMTYPE_CLOTHIER_RAW_MATERIAL or isRawFallback)
                            elseif stationType == CRAFTING_TYPE_WOODWORKING then
                                isValidMaterial = (itemType == ITEMTYPE_WOODWORKING_RAW_MATERIAL or isRawFallback)
                            elseif stationType == CRAFTING_TYPE_JEWELRYCRAFTING then
                                -- Platinum Dust Fix + Pulverized name check reinforcement
                                isValidMaterial = (itemType == ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL or 
                                                   itemType == ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER or 
                                                   itemType == ITEMTYPE_JEWELRYCRAFTING_RAW_TRAIT or
                                                   isRawFallback or
                                                   stringFind(stringLower(GetItemName(bag, slot)), "pulverized", 1, true))
                            end
                        end

                        if isValidMaterial and not isLocked then
                            if not YIP.IsFCOISLocked(bag, slot, "refine") then
                                local itemId = GetItemId(bag, slot)
                                local _, stackSize = GetItemInfo(bag, slot)
                                if not totals[itemId] then totals[itemId] = { total = 0, slots = {} } end
                                totals[itemId].total = totals[itemId].total + stackSize
                                table.insert(totals[itemId].slots, {bag = bag, slot = slot, count = stackSize})
                            end
                        
                        -- 2. DECONSTRUCTION: Only runs if the specific bag toggle is enabled
                        elseif YIP.savedVars.decon.deconstruct and not isLocked then
                            -- Check if the current bag is enabled in the Deconstruct sub-menu
                            local isBagEnabled = (bag == BAG_BACKPACK and YIP.savedVars.decon.includeBackpack) or 
                                                 (bag == BAG_BANK and YIP.savedVars.decon.includeBank)

                            if isBagEnabled then
                                -- Refinement is strict, but Deconstruction allows Universal stations
                                if isUniversal or (skillType == stationType) then
                                    if YIP.ShouldDeconstruct(bag, slot) then
                                        local _, stackCount = GetItemInfo(bag, slot)
                                        table.insert(deconQueue, {bag = bag, slot = slot, qty = stackCount})
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        -- Processing Refinement Queue
        if not isUniversal and YIP.savedVars.decon.refine then
            for itemId, data in pairs(totals) do
                if data.total >= 10 then
                    -- 1. Calculate the valid total (multiples of 10, max 200)
                    local refineQty = math.min(data.total - (data.total % 10), 200)
                    
                    -- 2. Send only ONE request for the total amount using the first slot found
                    -- The game engine handles pulling the rest from other stacks automatically
                    table.insert(refineQueue, {
                        bag = data.slots[1].bag, 
                        slot = data.slots[1].slot, 
                        qty = refineQty
                    })
                end
            end
        end

        if #refineQueue > 0 then
            PrepareDeconstructMessage()
            for _, item in ipairs(refineQueue) do AddItemToDeconstructMessage(item.bag, item.slot, item.qty) end
            
            -- Register for Success Check ONLY before sending the request
            EVENT_MANAGER:RegisterForEvent(YIP_addonName .. "_RefineCheck", EVENT_CRAFT_COMPLETED, function()
                EVENT_MANAGER:UnregisterForEvent(YIP_addonName .. "_RefineCheck", EVENT_CRAFT_COMPLETED)
                if refineTimer then zo_removeCallLater(refineTimer); refineTimer = nil end
                session.refined = session.refined + #refineQueue
                zo_callLater(RunCycle, 200)
            end)
            
            if refineTimer then zo_removeCallLater(refineTimer) end
            refineTimer = zo_callLater(function() 
                EVENT_MANAGER:UnregisterForEvent(YIP_addonName .. "_RefineCheck", EVENT_CRAFT_COMPLETED) 
                refineTimer = nil
            end, 1000)
            
            SendDeconstructMessage()
            return
        elseif session.refined > 0 then
            d("Refined raw materials.")
            session.refined = 0 -- This clears the state
        end

        -- Processing Deconstruction Queue
        if #deconQueue > 0 then
            -- Enchanting: Switch to extraction tab to avoid errors
            if stationType == CRAFTING_TYPE_ENCHANTING then
                if ZO_MenuBar_GetSelectedDescriptor(ENCHANTING.modeBar) ~= ENCHANTING_MODE_EXTRACTION then 
                    ZO_MenuBar_SelectDescriptor(ENCHANTING.modeBar, ENCHANTING_MODE_EXTRACTION, true, false)
                end
            end
            PrepareDeconstructMessage()
            local count = #deconQueue
            for _, item in ipairs(deconQueue) do AddItemToDeconstructMessage(item.bag, item.slot, item.qty) end
            
            YIP.isDeconstructing = count
            
            -- Register for Success Check ONLY before sending the request
            EVENT_MANAGER:RegisterForEvent(YIP_addonName .. "_DeconCheck", EVENT_CRAFT_COMPLETED, function()
                EVENT_MANAGER:UnregisterForEvent(YIP_addonName .. "_DeconCheck", EVENT_CRAFT_COMPLETED)
                if deconTimer then zo_removeCallLater(deconTimer); deconTimer = nil end
                if YIP.isDeconstructing > 0 then
                    d(string.format("Deconstructed %d %s.", YIP.isDeconstructing, YIP.isDeconstructing == 1 and "item" or "items"))
                    YIP.isDeconstructing = 0
                end
            end)
            
            if deconTimer then zo_removeCallLater(deconTimer) end
            deconTimer = zo_callLater(function() 
                EVENT_MANAGER:UnregisterForEvent(YIP_addonName .. "_DeconCheck", EVENT_CRAFT_COMPLETED) 
                deconTimer = nil
            end, 1000)

            SendDeconstructMessage()
        end
    end
    
    zo_callLater(RunCycle, 0)
end

function YIP.OnOpenStore(isFenceOverride)
    local interactionType = GetInteractionType() or 0
    local isFence = isFenceOverride or (interactionType == INTERACTION_FENCE)
    local canRepair = CanStoreRepair() or false
    
    -- Check if we have anything to do
    local hasWork = YIP.savedVars.merchant.repair or 
                    (YIP.savedVars.merchant.sellJunk and (
                        (isFence and YIP.savedVars.merchant.fenceJunk) or 
                        (not isFence and YIP.savedVars.merchant.sellNormalJunk) or
                        (not isFence and YIP.savedVars.merchant.companionSellThreshold and YIP.savedVars.merchant.companionSellThreshold > 0)
                    ))

    if not hasWork then return end

    zo_callLater(function()
        -- 1. Handle Repairs
        local repaired = false
        if canRepair and YIP.savedVars.merchant.repair then
            local repairCost = GetRepairAllCost()
            if repairCost > 0 and GetCurrentMoney() >= repairCost then
                RepairAll()
                repaired = true
            end
        end
        if repaired then d("Repaired gear.") end

        -- 2. Handle Selling Junk
        if YIP.savedVars.merchant.sellJunk then
            if isFence then
                if YIP.savedVars.merchant.fenceJunk then
                    local limit, used = GetFenceSellTransactionInfo()
                    local soldCount = 0
                    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
                        if IsItemJunk(BAG_BACKPACK, slot) and IsItemStolen(BAG_BACKPACK, slot) and used < limit then
                            local _, stack = GetItemInfo(BAG_BACKPACK, slot)
                            SellInventoryItem(BAG_BACKPACK, slot, stack)
                            used = used + 1
                            soldCount = soldCount + 1
                        end
                    end
                    if soldCount > 0 then
                        d(string.format("Fenced %d junk %s.", soldCount, soldCount == 1 and "item" or "items"))
                    end
                end
            else
                local totalSoldCount = 0
                if YIP.savedVars.merchant.sellNormalJunk then
                    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
                        if IsItemJunk(BAG_BACKPACK, slot) then
                            local _, _, sellPrice = GetItemInfo(BAG_BACKPACK, slot)
                            -- SellAllJunk automatically excludes stolen items and items with 0 value
                            if sellPrice > 0 and not IsItemStolen(BAG_BACKPACK, slot) then
                                totalSoldCount = totalSoldCount + 1
                            end
                        end
                    end
                    SellAllJunk(BAG_BACKPACK)
                end

                -- 3. Handle Companion Gear Selling
                if YIP.savedVars.merchant.companionSellThreshold and YIP.savedVars.merchant.companionSellThreshold > 0 then
                    local threshold = YIP.savedVars.merchant.companionSellThreshold
                    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
                        local link = GetItemLink(BAG_BACKPACK, slot)
                        if link ~= "" then
                            if GetItemLinkActorCategory(link) == GAMEPLAY_ACTOR_CATEGORY_COMPANION then
                                local quality = GetItemLinkDisplayQuality(link)
                                if quality <= threshold and not YIP.IsFCOISLocked(BAG_BACKPACK, slot, "sell") then
                                    local _, stack = GetItemInfo(BAG_BACKPACK, slot)
                                    SellInventoryItem(BAG_BACKPACK, slot, stack)
                                    totalSoldCount = totalSoldCount + 1
                                end
                            end
                        end
                    end
                end

                if totalSoldCount > 0 then
                    d(string.format("Sold %d junk %s.", totalSoldCount, totalSoldCount == 1 and "item" or "items"))
                end
            end
        end
    end, 0)
end

function YIP.InitializeSettings()
    local LAM = LibAddonMenu2
    if not LAM then d("Error: LibAddonMenu-2.0 missing!") return end

    local panelData = {
        type = "panel",
        name = "Yudo's Inventory Processor",
        displayName = "Yudo's Inventory Processor",
        author = "YudoAn",
        version = "1.12.1",
        website = "https://www.esoui.com/downloads/info4324-YudosInventoryProcessor.html",
        registerForRefresh = true,
    }

    local optionsTable = {
        {
            type = "checkbox",
            name = "Account-Wide Settings",
            tooltip = "Shared settings across all characters.",
            getFunc = function() return YIP.charSavedVars.accountWide end,
            setFunc = function(v) 
                YIP.charSavedVars.accountWide = v 
            end,
            default = true,
            requiresReload = true,
        },

        { type = "header", name = "Compatibility" },
        {
            type = "checkbox",
            name = "Dolgubon's Lazy Writ Crafter",
            tooltip = "While crafting writs with DLWC, processing will be paused.",
            getFunc = function() return YIP.savedVars.global.respectLWC end,
            setFunc = function(v) YIP.savedVars.global.respectLWC = v end,
        },
        {
            type = "checkbox",
            name = "FCO ItemSaver",
            tooltip = "Items marked as locked in FCO ItemSaver will be ignored.",
            getFunc = function() return YIP.savedVars.global.respectFCOIS end,
            setFunc = function(v) YIP.savedVars.global.respectFCOIS = v end,
        },

        { type = "header", name = "Auto Banker" },
        {
            type = "checkbox",
            name = "Deposit Materials",
            tooltip = "Automatically deposits crafting materials. Excludes junk.",
            getFunc = function() return YIP.savedVars.banker.depositMats end,
            setFunc = function(v) YIP.savedVars.banker.depositMats = v end,
        },
        {
            type = "checkbox",
            name = "Deposit Currency",
            tooltip = "Automatically deposits currencies",
            getFunc = function() return YIP.savedVars.banker.depositCurrencies end,
            setFunc = function(v) YIP.savedVars.banker.depositCurrencies = v end,
        },
        {
            type = "submenu",
            name = "Currency Rules",
            controls = {
                {
                    type = "slider",
                    name = "Keep Gold",
                    tooltip = "Amount of Gold to keep on character.",
                    min = 0, max = 100000, step = 1000,
                    getFunc = function() return YIP.savedVars.banker.minCurrency.gold or 0 end,
                    setFunc = function(v) YIP.savedVars.banker.minCurrency.gold = v end,
                    disabled = function() return not (YIP.savedVars.banker.depositCurrencies) end,
                },
                {
                    type = "slider",
                    name = "Keep Alliance Points",
                    tooltip = "Amount of AP to keep on character.",
                    min = 0, max = 100000, step = 1000,
                    getFunc = function() return YIP.savedVars.banker.minCurrency.ap or 0 end,
                    setFunc = function(v) YIP.savedVars.banker.minCurrency.ap = v end,
                    disabled = function() return not (YIP.savedVars.banker.depositCurrencies) end,
                },
                {
                    type = "slider",
                    name = "Keep Tel Var Stones",
                    tooltip = "Amount of Tel Var to keep on character.",
                    min = 0, max = 10000, step = 100,
                    getFunc = function() return YIP.savedVars.banker.minCurrency.telvar or 0 end,
                    setFunc = function(v) YIP.savedVars.banker.minCurrency.telvar = v end,
                    disabled = function() return not (YIP.savedVars.banker.depositCurrencies) end,
                },
                {
                    type = "slider",
                    name = "Keep Writ Vouchers",
                    tooltip = "Amount of Writs to keep on character.",
                    min = 0, max = 1000, step = 10,
                    getFunc = function() return YIP.savedVars.banker.minCurrency.writ or 0 end,
                    setFunc = function(v) YIP.savedVars.banker.minCurrency.writ = v end,
                    disabled = function() return not (YIP.savedVars.banker.depositCurrencies) end,
                },
            },
        },

        { type = "header", name = "Auto Crafter" },
        {
            type = "checkbox",
            name = "Refine Mats",
            tooltip = "Automatically refines raw materials from backpack and bank.",
            getFunc = function() return YIP.savedVars.decon.refine end,
            setFunc = function(v) YIP.savedVars.decon.refine = v end,
        },
        {
            type = "checkbox",
            name = "Fillet Fish",
            tooltip = "Automatically fillets fish at a provisioning station.",
            getFunc = function() return YIP.savedVars.decon.fillet end,
            setFunc = function(v) YIP.savedVars.decon.fillet = v end,
        },
        {
            type = "checkbox",
            name = "Deconstruct",
            tooltip = "Automatically deconstructs items.",
            getFunc = function() return YIP.savedVars.decon.deconstruct end,
            setFunc = function(v) YIP.savedVars.decon.deconstruct = v end,
        },
        {
            type = "submenu",
            name = "Deconstruct rules",
            controls = {
                {
                    type = "description",
                    text = "Items are destroyed instantly at stations. Lock gear to protect it.",
                },
                {
                    type = "checkbox",
                    name = "Scan Backpack",
                    tooltip = "Scan items in your inventory for deconstruction.",
                    getFunc = function() return YIP.savedVars.decon.includeBackpack end,
                    setFunc = function(v) YIP.savedVars.decon.includeBackpack = v end,
                    disabled = function() return not YIP.savedVars.decon.deconstruct end,
                },
                {
                    type = "checkbox",
                    name = "Scan Bank",
                    tooltip = "Scan items in your bank for deconstruction.",
                    getFunc = function() return YIP.savedVars.decon.includeBank end,
                    setFunc = function(v) YIP.savedVars.decon.includeBank = v end,
                    disabled = function() return not YIP.savedVars.decon.deconstruct end,
                },
                {
                    type = "dropdown",
                    name = "Max Quality to Deconstruct",
                    tooltip = "Deconstructs items of this quality and lower. Excludes Crafted, Reconstructed, Transmuted, Researchable, Ornate items.",
                    choices = {"|c2dc50eFine|r", "|c3a92ffSuperior|r", "|ca02ef7Epic|r"},
                    choicesValues = {2, 3, 4}, 
                    getFunc = function() return tonumber(YIP.savedVars.decon.qualityThreshold) or 2 end,
                    setFunc = function(v) YIP.savedVars.decon.qualityThreshold = v end,
                    disabled = function() return not YIP.savedVars.decon.deconstruct end,
                },
            },
        },
        
        { type = "header", name = "Auto Merchant" },
        {
            type = "checkbox",
            name = "Repair Gear",
            tooltip = "Automatically repairs all gear at a merchant.",
            getFunc = function() return YIP.savedVars.merchant.repair end,
            setFunc = function(v) YIP.savedVars.merchant.repair = v end,
        },
        {
            type = "checkbox",
            name = "Sell Items",
            tooltip = "Automatically sells items at a merchant.",
            getFunc = function() return YIP.savedVars.merchant.sellJunk end,
            setFunc = function(v) YIP.savedVars.merchant.sellJunk = v end,
        },
        {
            type = "checkbox",
            name = "Mark Junk",
            tooltip = "Automatically marks items as junk when looted. Enables junk memory.",
            getFunc = function() return YIP.savedVars.merchant.markJunk end,
            setFunc = function(v) YIP.savedVars.merchant.markJunk = v end,
        },
        {
            type = "submenu",
            name = "Sell Rules",
            controls = {
                {
                    type = "checkbox",
                    name = "Sell Junk",
                    tooltip = "Sells all junk items. Excludes 0-value junk.",
                    getFunc = function() return YIP.savedVars.merchant.sellNormalJunk end,
                    setFunc = function(v) YIP.savedVars.merchant.sellNormalJunk = v end,
                    disabled = function() return not YIP.savedVars.merchant.sellJunk end,
                },
                {
                    type = "checkbox",
                    name = "Fence Junk",
                    tooltip = "Fences all stolen junk items.",
                    getFunc = function() return YIP.savedVars.merchant.fenceJunk end,
                    setFunc = function(v) YIP.savedVars.merchant.fenceJunk = v end,
                    disabled = function() return not YIP.savedVars.merchant.sellJunk end,
                },
                {
                    type = "dropdown",
                    name = "Sell Companion Gear",
                    tooltip = "Sells companion gear of this quality and lower.",
                    choices = {"Off", "|c2dc50eFine|r", "|c3a92ffSuperior|r"},
                    choicesValues = {0, 2, 3},
                    getFunc = function() return YIP.savedVars.merchant.companionSellThreshold or 0 end,
                    setFunc = function(v) YIP.savedVars.merchant.companionSellThreshold = v end,
                    disabled = function() return not YIP.savedVars.merchant.sellJunk end,
                },
            },
        },
        {
            type = "submenu",
            name = "Junk Rules",
            controls = {
                {
                    type = "description",
                    text = "Manually marking/unmarking items as Junk will override these rules.",
                },
                {
                    type = "checkbox",
                    name = "Bound Scripts",
                    tooltip = "Mark bound scribing scripts.",
                    getFunc = function() return YIP.savedVars.merchant.junkRules.scripts end,
                    setFunc = function(v) YIP.savedVars.merchant.junkRules.scripts = v end,
                    disabled = function() return not YIP.savedVars.merchant.markJunk end,
                },
                {
                    type = "checkbox",
                    name = "Low Level Materials",
                    tooltip = "Mark crafting mats that are below CP150 requirements.",
                    getFunc = function() return YIP.savedVars.merchant.junkRules.lowLevelMats end,
                    setFunc = function(v) YIP.savedVars.merchant.junkRules.lowLevelMats = v end,
                    disabled = function() return not YIP.savedVars.merchant.markJunk end,
                },
                {
                    type = "checkbox",
                    name = "Low Level Potion/Poison",
                    tooltip = "Mark potion/poison that is below CP150 and Blue quality. Excludes crafted items.",
                    getFunc = function() return YIP.savedVars.merchant.junkRules.potions end,
                    setFunc = function(v) YIP.savedVars.merchant.junkRules.potions = v end,
                    disabled = function() return not YIP.savedVars.merchant.markJunk end,
                },
                {
                    type = "checkbox",
                    name = "Low Quality Food/Drink",
                    tooltip = "Mark food/drink that is below Blue quality. Excludes crafted items.",
                    getFunc = function() return YIP.savedVars.merchant.junkRules.foodDrink end,
                    setFunc = function(v) YIP.savedVars.merchant.junkRules.foodDrink = v end,
                    disabled = function() return not YIP.savedVars.merchant.markJunk end,
                },
                {
                    type = "checkbox",
                    name = "Low Quality Known Recipes",
                    tooltip = "Mark known recipes and furnishing plans that are below Blue quality.",
                    getFunc = function() return YIP.savedVars.merchant.junkRules.lowQualityKnownRecipes end,
                    setFunc = function(v) YIP.savedVars.merchant.junkRules.lowQualityKnownRecipes = v end,
                    disabled = function() return not YIP.savedVars.merchant.markJunk end,
                },
                {
                    type = "checkbox",
                    name = "Low Value Trait Items",
                    tooltip = "Mark all trait materials. Excludes Nirncrux, Aurbic Amber, Slaughterstone, Gilding Wax, Dawn-Prism, Dibellium, Titanium.",
                    getFunc = function() return YIP.savedVars.merchant.junkRules.traitItems end,
                    setFunc = function(v) YIP.savedVars.merchant.junkRules.traitItems = v end,
                    disabled = function() return not YIP.savedVars.merchant.markJunk end,
                },
                {
                    type = "checkbox",
                    name = "Ornate Items",
                    tooltip = "Mark items with Ornate trait.",
                    getFunc = function() return YIP.savedVars.merchant.junkRules.ornate end,
                    setFunc = function(v) YIP.savedVars.merchant.junkRules.ornate = v end,
                    disabled = function() return not YIP.savedVars.merchant.markJunk end,
                },
                {
                    type = "checkbox",
                    name = "Style Materials",
                    tooltip = "Mark all style materials.",
                    getFunc = function() return YIP.savedVars.merchant.junkRules.styleMats end,
                    setFunc = function(v) YIP.savedVars.merchant.junkRules.styleMats = v end,
                    disabled = function() return not YIP.savedVars.merchant.markJunk end,
                },
                {
                    type = "checkbox",
                    name = "Trash Items",
                    tooltip = "Mark items of type Trash",
                    getFunc = function() return YIP.savedVars.merchant.junkRules.trash end,
                    setFunc = function(v) YIP.savedVars.merchant.junkRules.trash = v end,
                    disabled = function() return not YIP.savedVars.merchant.markJunk end,
                },
                {
                    type = "checkbox",
                    name = "Treasures",
                    tooltip = "Mark treasures/trophies made for selling.",
                    getFunc = function() return YIP.savedVars.merchant.junkRules.treasures end,
                    setFunc = function(v) YIP.savedVars.merchant.junkRules.treasures = v end,
                    disabled = function() return not YIP.savedVars.merchant.markJunk end,
                },
            },
        },
        {
            type = "button",
            name = "Scan inventory for Junk",
            tooltip = "Scans inventory and marks items as junk based on junk rules and memory.",
            disabled = function() return not YIP.savedVars.merchant.markJunk end,
            func = function() 
                local junkCount = 0
                YIP.isAutoJunking = true -- Semaphore Fix
                for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
                    -- Only count if it wasn't already junk but should be
                    if YIP.ShouldBeJunk(BAG_BACKPACK, slot) and not IsItemJunk(BAG_BACKPACK, slot) then 
                        SetItemIsJunk(BAG_BACKPACK, slot, true) 
                        junkCount = junkCount + 1
                    end
                end
                YIP.isAutoJunking = false -- Semaphore Fix
                d(string.format("Marked %d items as junk.", junkCount))
            end,
        },
        {
            type = "button",
            name = "Reset Junk Memory",
            tooltip = "Clears the memory of items you manually marked or unmarked as junk.",
            disabled = function() return not YIP.savedVars.merchant.markJunk end,
            func = function() 
                ZO_Dialogs_ShowDialog("YIP_CONFIRM_RESET_MEMORY")
            end,
        },
    }

    LAM:RegisterAddonPanel("YudosInventoryProcessorOptions", panelData)
    LAM:RegisterOptionControls("YudosInventoryProcessorOptions", optionsTable)
end

-- 1. This fires when the player is physically in the world
function YIP.OnPlayerActivated(eventCode, initialCall)
    -- Unregister immediately so it only runs once per load
    EVENT_MANAGER:UnregisterForEvent(YIP_addonName, EVENT_PLAYER_ACTIVATED)

    -- Safety check and then start the addon
    if not YIP.isInitialized then
        YIP.isInitialized = true
        YIP.Initialize()
    end
end

-- 2. This fires when your addon files are loaded into memory
function YIP.OnAddOnLoaded(eventCode, loadedAddonName)
    -- Filter for your addon name using the fast local variable
    if loadedAddonName ~= YIP_addonName then return end
    
    -- Clean up the loader event
    EVENT_MANAGER:UnregisterForEvent(YIP_addonName, EVENT_ADD_ON_LOADED)

    -- Now wait for the player to be active before initializing
    EVENT_MANAGER:RegisterForEvent(YIP_addonName, EVENT_PLAYER_ACTIVATED, YIP.OnPlayerActivated)
end

-- Initial Kick-off
EVENT_MANAGER:RegisterForEvent(YIP_addonName, EVENT_ADD_ON_LOADED, YIP.OnAddOnLoaded)
