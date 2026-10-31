local CMA = CraftMaterialAssistant

-- Evaluates if an item passes its specific material category filter and gets a target quality threshold
function CMA:DetermineItemAction(bag, slotIndex)
    local itemType, specializedItemType = GetItemType(bag, slotIndex)

    -- TODO: Turn on for Item-Identification
    -- local i = GetItemLink(bag, slotIndex)
    -- local id = GetItemLinkItemId(i)
    -- self:SendChatMessage(i)
    -- self:SendChatMessage("id: " .. id)
    -- self:SendChatMessage("itemType: " .. itemType)
    -- if specializedItemType ~= null then
    --     self:SendChatMessage("specializedItemType: " .. specializedItemType)
    -- end

    -- check if customized rules is active
    if self.db.activateCustomRules then
       -- get the item id of the current item
        local itemId = GetItemId(bag, slotIndex)
        -- iterate over all rules in the custom rules table
        for k, v in pairs(self.customItemRuleTable) do
            if tonumber(k) == itemId then
                -- item found in table, return the persisted action
                return self.simpleMaterialDecisionMap[v[3]]
            end
        end
    end

    -- handle the categories only having an on|off state
    if itemType == ITEMTYPE_FURNISHING_MATERIAL then
        return self.simpleMaterialDecisionMap[self.db.bankFurnishingMaterials]
    elseif itemType == ITEMTYPE_LURE then
        return self.simpleMaterialDecisionMap[self.db.bankBait]
    elseif itemType == ITEMTYPE_RAW_MATERIAL then
        return self.simpleMaterialDecisionMap[self.db.bankRawMaterials]
    elseif itemType == ITEMTYPE_TREASURE then
        local isStolen = IsItemStolen(bag, slotIndex)
        if isStolen and self.db.autoSellStolenTreasureItems then
            return "junk"
        elseif not isStolen and self.db.autoSellTreasureItems then
            return "junk"
        end
        -- if this point is reached its a treasure but selling is turned off - stop the evaluation by ignoring it
        return "ignore"
    elseif itemType == ITEMTYPE_TRASH then
        if self.db.autoSellTrashItems then
            return "junk"
        else
            return "ignore"
        end
    elseif itemType == ITEMTYPE_POTION or itemType == ITEMTYPE_POISON then
        local itemLink = GetItemLink(bag, slotIndex)
        local isCrafted = IsItemLinkCrafted(itemLink)
        local isBound = IsItemBound(bag, slotIndex)
        if self.db.autoSellLootedPotionsAndPoisons and not isCrafted and not isBound then
            return "junk"
        else
            -- item is a potion or a poison but crafted or selling is turned off
            return "ignore"
        end
    elseif (specializedItemType == SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_FOOD) or (specializedItemType == SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_DRINK) then
        local itemLink = GetItemLink(bag, slotIndex)
        local quality = GetItemLinkFunctionalQuality(itemLink)
        local known = IsItemLinkRecipeKnown(itemLink)
        if (known == false) and (self.db.showBankAlerts) then
            self:SendChatMessage("|cFFEE00Unknown Provisioning Recipe:|r " .. itemLink)
        elseif self.db.bankProvisioningSellKnownRecipe and (quality < self.qualityMap[self.db.bankQualityThresholdProvisioningRecipe]) then
            -- its known and below the quality threshold
            return "junk"
        end
    elseif itemType == ITEMTYPE_REAGENT then
        if not self.db.bankAlchemy then
            return "ignore"
        else 
            return self.db.bankAlchemyReagents and "bank" or "junk"
        end
    elseif itemType == ITEMTYPE_JEWELRY_RAW_TRAIT then
        if not self.db.bankJewelry then
            return "ignore"
        else
            return self.db.bankRawJewelryTraits and "bank" or "junk"
        end
    elseif itemType == ITEMTYPE_ENCHANTING_RUNE_ESSENCE then
        if not self.db.bankEnchanting then
            return "ignore"
        else
            return self.db.bankEssenceRunes and "bank" or "junk"
        end
    elseif itemType == ITEMTYPE_STYLE_MATERIAL then
        if (
            (self.db.bankStyleMaterials == "Ignore") or (self.db.bankStyleMaterials == "Sell") or 
            ((self.db.bankStyleMaterials == "Bank") and (not self.db.limitStyleMaterialByCount))
        ) then
            return self.simpleMaterialDecisionMap[self.db.bankStyleMaterials]
        else
            local itemLink = GetItemLink(bag, slotIndex)
            local stackCountBackpack, stackCountBank, stackCountCraftBag, stackCountHouseBanks = GetItemLinkStacks(itemLink)
            return ((stackCountBank + stackCountCraftBag + stackCountHouseBanks) < self.db.bankMinimumNumberStyleMaterial) and "bank" or "junk"
        end
    elseif itemType == ITEMTYPE_ARMOR_TRAIT or itemType == ITEMTYPE_JEWELRY_TRAIT or itemType == ITEMTYPE_WEAPON_TRAIT then
        if (
            (self.db.bankTraitMaterials == "Ignore") or (self.db.bankTraitMaterials == "Sell") or 
            ((self.db.bankTraitMaterials == "Bank") and (not self.db.limitTraitMaterialByCount))
        ) then
            return self.simpleMaterialDecisionMap[self.db.bankTraitMaterials]
        else
            local itemLink = GetItemLink(bag, slotIndex)
            local stackCountBackpack, stackCountBank, stackCountCraftBag, stackCountHouseBanks = GetItemLinkStacks(itemLink)
            return ((stackCountBank + stackCountCraftBag + stackCountHouseBanks) < self.db.bankMinimumNumberTraitMaterial) and "bank" or "junk"
        end
    elseif itemType == ITEMTYPE_ARMOR_TRAIT or itemType == ITEMTYPE_JEWELRY_TRAIT or itemType == ITEMTYPE_WEAPON_TRAIT then
        if (
            (self.db.bankTraitMaterials == "Ignore") or (self.db.bankTraitMaterials == "Sell") or 
            ((self.db.bankTraitMaterials == "Bank") and (not self.db.limitTraitMaterialByCount))
        ) then
            return self.simpleMaterialDecisionMap[self.db.bankTraitMaterials]
        else
            local itemLink = GetItemLink(bag, slotIndex)
            local stackCountBackpack, stackCountBank, stackCountCraftBag, stackCountHouseBanks = GetItemLinkStacks(itemLink)
            return ((stackCountBank + stackCountCraftBag + stackCountHouseBanks) < self.db.bankMinimumNumberTraitMaterial) and "bank" or "junk"
        end
    elseif itemType == ITEMTYPE_SCRIBING_INK then
        if not self.db.bankScribingMaterials then
            return "ignore"
        else 
            return self.simpleMaterialDecisionMap[self.db.bankInk]
        end
    elseif itemType == ITEMTYPE_CRAFTED_ABILITY_SCRIPT then
        local itemLink = GetItemLink(bag, slotIndex)
        local isLinkBound = IsItemLinkBound(itemLink)
        local linkBindType = GetItemLinkBindType(itemLink)
        if (not self.db.bankScribingMaterials) then
            return "ignore"
        elseif (not isLinkBound) and (linkBindType ~= BIND_TYPE_ON_PICKUP) then
            -- The item linked is unbound -> handle unbound script
            return self.simpleMaterialDecisionMap[self.db.bankUnboundScripts]
        elseif  (not self.db.bankUnknownScripts) then
            -- item is not unbount and chosen not to handle unknown scripts
            return "ignore"
        else
            local scriptId = GetItemLinkItemUseReferenceId(itemLink)
            local names, count = self:GetCharactersWithoutScriptKnowledge(scriptId)
            if names == nil or count == nil then
                -- no LibCharacterKnowledge available -> ignore
                return "ignore"
            else
                -- got some value: print the script and missing persons
                if count > 0 then
                    local stackCountBackpack, stackCountBank, stackCountCraftBag, stackCountHouseBanks = GetItemLinkStacks(itemLink)
                    local availableCopies = stackCountBank + stackCountHouseBanks
                    if ((stackCountBank + stackCountHouseBanks) < count) then
                        -- not known bei all and too few copies for all
                        self:SendChatMessage(itemLink .. " learnable by " .. count .. " Characters: " .. names .. ".\nThere are " .. availableCopies .. " copies in the bank (" .. stackCountBank .. ") and house banks (" .. stackCountHouseBanks ..") -> banking it." )
                        return "bank"
                    else
                        -- not known bei all but enough copies to learn with all
                        self:SendChatMessage(itemLink .. " learnable by " .. count .. " Characters: " .. names .. ".\nHowever there are " .. availableCopies .. " copies in the bank (" .. stackCountBank .. ") and house banks (" .. stackCountHouseBanks ..") -> marking it as junk." )
                        return "junk"
                    end
                else
                    -- known by everyone
                    self:SendChatMessage(itemLink .. " already learned by all characters.")
                    return "junk"
                end
            end
        end
    end

    -- handle the categories also having a style criteria
    local groupToggle = nil
    local qualityThreshold = nil
    local tierThreshold = nil
    local materialMap = {}
    if itemType == ITEMTYPE_BLACKSMITHING_MATERIAL or itemType == ITEMTYPE_BLACKSMITHING_RAW_MATERIAL then
        groupToggle = self.db.bankBlacksmithing
        tierThreshold = self.db.bankTierThresholdBlacksmithing
        materialMap = self.blacksmithingMaterialMap
    elseif itemType == ITEMTYPE_BLACKSMITHING_BOOSTER then
        groupToggle = self.db.bankBlacksmithing
        qualityThreshold = self.db.bankQualityThresholdBlacksmithing
    elseif itemType == ITEMTYPE_CLOTHIER_MATERIAL or itemType == ITEMTYPE_CLOTHIER_RAW_MATERIAL then
        groupToggle = self.db.bankClothing
        tierThreshold = self.db.bankTierThresholdClothing
        materialMap = self.clothingMaterialMap
    elseif itemType == ITEMTYPE_CLOTHIER_BOOSTER then
        groupToggle = self.db.bankClothing
        qualityThreshold = self.db.bankQualityThresholdClothing
    elseif itemType == ITEMTYPE_WOODWORKING_MATERIAL or itemType == ITEMTYPE_WOODWORKING_RAW_MATERIAL then
        groupToggle = self.db.bankWoodworking
        tierThreshold = self.db.bankTierThresholdWoodworking
        materialMap = self.woodworkingMaterialMap
    elseif itemType == ITEMTYPE_WOODWORKING_BOOSTER then
        groupToggle = self.db.bankWoodworking
        qualityThreshold = self.db.bankQualityThresholdWoodworking
    elseif itemType == ITEMTYPE_JEWELRYCRAFTING_MATERIAL or itemType == ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL then
        groupToggle = self.db.bankJewelry
        tierThreshold = self.db.bankTierThresholdJewelry
        materialMap = self.jewelryMaterialMap
    elseif itemType == ITEMTYPE_JEWELRYCRAFTING_BOOSTER then
        groupToggle = self.db.bankJewelry
        qualityThreshold = self.db.bankQualityThresholdJewelry
    elseif itemType == ITEMTYPE_ENCHANTING_RUNE_POTENCY then
        groupToggle = self.db.bankEnchanting
        tierThreshold = self.db.bankImprovementThresholdPotencyRunes
        materialMap = self.enchantingMaterialMap
    elseif itemType == ITEMTYPE_ENCHANTING_RUNE_ASPECT then
        groupToggle = self.db.bankEnchanting
        qualityThreshold = self.db.bankQualityThresholdEnchanting
    elseif itemType == ITEMTYPE_POTION_BASE or itemType == ITEMTYPE_POISON_BASE then
        groupToggle = self.db.bankAlchemy
        materialMap = self.alchemyMaterialMap
        tierThreshold = self.db.bankProficiencyThresholdAlchemyBases
    elseif itemType == ITEMTYPE_INGREDIENT then
        groupToggle =  self.db.bankProvisioning
        if specializedItemType == SPECIALIZED_ITEMTYPE_INGREDIENT_RARE then
            qualityThreshold = self.db.bankQualityThresholdProvisioning
        end
    else
        -- all the other unlocked gear
        local link = GetItemLink(bag, slotIndex)
        local isCrafted = IsItemLinkCrafted(link)
        -- check if its armor or weapon with no trait
        if not isCrafted and (itemType == ITEMTYPE_ARMOR or itemType == ITEMTYPE_WEAPON) then
            local traitInfo = GetItemTraitInformation(bag, slotIndex)
            if traitInfo == ITEM_TRAIT_INFORMATION_ORNATE then
                if self.db.autoSellOrnateGear then
                    return "junk"
                else
                    return "ignore"
                end
            elseif traitInfo == ITEM_TRAIT_INFORMATION_INTRICATE then
                if self.db.autoSellIntricateGear then
                    return "junk"
                else
                    return "ignore"
                end
            elseif traitInfo == ITEM_TRAIT_INFORMATION_NONE then
                local itemLink = GetItemLink(bag, slotIndex)
                local quality = GetItemLinkFunctionalQuality(itemLink)
                local actorCategory = GetItemActorCategory(bag, slotIndex)
                if actorCategory ~= GAMEPLAY_ACTOR_CATEGORY_COMPANION then
                    if self.db.bankTraitlessGear == "Bank" then
                        -- has no trait and bank is turned on -> check quality
                        if quality >= self.qualityMap[self.db.bankTraitlessGearThreshold] then
                            -- quality fits -> bank
                            return "bank"
                        elseif self.db.markAsTrashIfNotBanked then
                            -- quality is too low and sell is active -> sell
                            return "junk"
                        end
                        -- ignore
                    elseif self.db.bankTraitlessGear == "Sell" then
                        -- sell is activated, check quality
                        if quality < self.qualityMap[self.db.bankTraitlessGearThreshold] then
                            -- quality lower than threshold -> sell
                            return "junk"
                        end
                        -- ignore
                    end
                    return "ignore"
                end
            end
        end
        -- check  if its trait researchable... but only if selected to handle it
        if self.db.bankResearchableItems and not IsItemPlayerLocked(bag, slotIndex) then
            -- call the logic to get trait info and check with LibCharacterKnowledge if all chars know it
            local traitResearchResult = self:HandleTraitItem(bag, slotIndex)
            if traitResearchResult == "bank" then
                return traitResearchResult
            elseif traitResearchResult == "learned" then
                -- its learned already, only carry out the decision if its not gold quality (do not sell gold quality)
                local itemLink = GetItemLink(bag, slotIndex)
                local quality = GetItemLinkFunctionalQuality(itemLink)
                if (self.simpleMaterialDecisionMap[self.db.actionKnownTraitItems] == "junk") and (quality >= ITEM_DISPLAY_QUALITY_LEGENDARY) then
                    -- prevent gold or higher tier item from selling
                    return "ignore"
                else
                    return self.simpleMaterialDecisionMap[self.db.actionKnownTraitItems]
                end
            end
        end
        -- if companion items are handled, try if its a companion item
        if self.db.handleCompanionGear then
            -- get the actor category to know if its a companion item
            local actorCategory = GetItemActorCategory(bag, slotIndex)
            -- iterate the types
            if actorCategory == GAMEPLAY_ACTOR_CATEGORY_COMPANION then
                -- it is comanion gear - handle it
                -- get the trait of the item and its quality
                local traitType = GetItemTrait(bag, slotIndex)
                local itemLink = GetItemLink(bag, slotIndex)
                local quality = GetItemLinkFunctionalQuality(itemLink)
                if
                    (traitType ~= nil) and
                    (self.db.companionGearTraitHandling[traitType] == true) and
                    (quality >= self.qualityMap[self.db.bankQualityCompanionGear])
                then
                    -- quality meets bank criteria and trait type is to be banked -> bank
                    return "bank"
                elseif self.db.sellNotBankedCompanionGear then
                    -- item is not banked and sell option active -> mark as junk
                    return "junk"
                end
                -- its a companion item but not banked or sold - break the loop and go on (probably leading to 'unknown')
            end
        end
        -- if that point is reached, its not a supported item with no traits to research
        return "unknown"
    end

    local itemLink = GetItemLink(bag, slotIndex)
    local quality = GetItemLinkFunctionalQuality(itemLink)
    local itemId = GetItemLinkItemId(itemLink)
    local materialTierInfo = materialMap[itemId]
    local itemTier = nil

    if materialTierInfo then
        itemTier = materialTierInfo.tier
    end
    
    if not groupToggle then
        -- category turned off, ignore the item
        return "ignore"
    elseif (
        (itemType == ITEMTYPE_INGREDIENT) and
        (specializedItemType ~= SPECIALIZED_ITEMTYPE_INGREDIENT_RARE)
    ) then
        -- handle the case of writ ingredients only
        if (self.provisioningTopLevelWritIngredientsMap[itemId] ~= nil) then
             return self.db.bankProvisioningKeepWritIngredients and "bank" or "junk"
        else
            return self.db.bankProvisioningKeepOtherIngredients and "bank" or "junk"
        end
    elseif (
        ((qualityThreshold == nil) or (quality >= self.qualityMap[qualityThreshold])) and
        ((tierThreshold == nil) or (itemTier == nil) or (itemTier >= tierThreshold))
    ) then
        -- its a tier item and tier is met
        return "bank"
    else
        return "junk"
    end
end