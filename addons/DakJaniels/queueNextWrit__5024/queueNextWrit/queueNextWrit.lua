local EVENT_MANAGER = GetEventManager()
local SCENE_MANAGER = SCENE_MANAGER

local HUD_TOGGLE_DELAY_MILLISECONDS = 300
local USE_ITEM_DELAY_MILLISECONDS = 300
local ACCEPT_QUEST_DELAY_MILLISECONDS = 500
local SMITHING_MASTER_WRIT_CHAMPION_POINTS = 150
local ALCHEMY_MASTER_WRIT_CHAMPION_POINTS = 150
local ALCHEMY_MASTER_WRIT_REQUIRED_STACK_COUNT = 16
local ALCHEMY_POTION_SOLVENT_ID = 199
local LIGHT_ROBE_ICON = "/esoui/art/icons/gear_breton_light_robe_d.dds"
local PROVISIONING_CRAFT_ITERATIONS = 2
local ADDON_NAME = "queueNextWrit"

local MASTER_WRIT_ICON_CRAFTING_TYPE = {
    ["/esoui/art/icons/master_writ_blacksmithing.dds"] = CRAFTING_TYPE_BLACKSMITHING,
    ["/esoui/art/icons/master_writ_clothier.dds"] = CRAFTING_TYPE_CLOTHIER,
    ["/esoui/art/icons/master_writ_woodworking.dds"] = CRAFTING_TYPE_WOODWORKING,
    ["/esoui/art/icons/master_writ_jewelry.dds"] = CRAFTING_TYPE_JEWELRYCRAFTING,
    ["/esoui/art/icons/master_writ_alchemy.dds"] = CRAFTING_TYPE_ALCHEMY,
    ["/esoui/art/icons/master_writ_enchanting.dds"] = CRAFTING_TYPE_ENCHANTING,
    ["/esoui/art/icons/master_writ_provisioning.dds"] = CRAFTING_TYPE_PROVISIONING,
}

local ENCHANTING_WRIT_LEVEL_CHAMPION_POINTS = {
    [207] = 150,
    [225] = 160,
}

local GEAR_PIECE_BY_TEMPLATE_ID = {
    [53] = { craftingType = CRAFTING_TYPE_BLACKSMITHING, weaponType = WEAPONTYPE_AXE },
    [56] = { craftingType = CRAFTING_TYPE_BLACKSMITHING, weaponType = WEAPONTYPE_HAMMER },
    [59] = { craftingType = CRAFTING_TYPE_BLACKSMITHING, weaponType = WEAPONTYPE_SWORD },
    [68] = { craftingType = CRAFTING_TYPE_BLACKSMITHING, weaponType = WEAPONTYPE_TWO_HANDED_AXE },
    [69] = { craftingType = CRAFTING_TYPE_BLACKSMITHING, weaponType = WEAPONTYPE_TWO_HANDED_HAMMER },
    [67] = { craftingType = CRAFTING_TYPE_BLACKSMITHING, weaponType = WEAPONTYPE_TWO_HANDED_SWORD },
    [62] = { craftingType = CRAFTING_TYPE_BLACKSMITHING, weaponType = WEAPONTYPE_DAGGER },
    [46] = { craftingType = CRAFTING_TYPE_BLACKSMITHING, armorType = ARMORTYPE_HEAVY, equipType = EQUIP_TYPE_CHEST },
    [50] = { craftingType = CRAFTING_TYPE_BLACKSMITHING, armorType = ARMORTYPE_HEAVY, equipType = EQUIP_TYPE_FEET },
    [52] = { craftingType = CRAFTING_TYPE_BLACKSMITHING, armorType = ARMORTYPE_HEAVY, equipType = EQUIP_TYPE_HAND },
    [44] = { craftingType = CRAFTING_TYPE_BLACKSMITHING, armorType = ARMORTYPE_HEAVY, equipType = EQUIP_TYPE_HEAD },
    [49] = { craftingType = CRAFTING_TYPE_BLACKSMITHING, armorType = ARMORTYPE_HEAVY, equipType = EQUIP_TYPE_LEGS },
    [47] = { craftingType = CRAFTING_TYPE_BLACKSMITHING, armorType = ARMORTYPE_HEAVY, equipType = EQUIP_TYPE_SHOULDERS },
    [48] = { craftingType = CRAFTING_TYPE_BLACKSMITHING, armorType = ARMORTYPE_HEAVY, equipType = EQUIP_TYPE_WAIST },

    [28] = { craftingType = CRAFTING_TYPE_CLOTHIER, armorType = ARMORTYPE_LIGHT, equipType = EQUIP_TYPE_CHEST, isRobe = true },
    [75] = { craftingType = CRAFTING_TYPE_CLOTHIER, armorType = ARMORTYPE_LIGHT, equipType = EQUIP_TYPE_CHEST, isRobe = false },
    [32] = { craftingType = CRAFTING_TYPE_CLOTHIER, armorType = ARMORTYPE_LIGHT, equipType = EQUIP_TYPE_FEET },
    [34] = { craftingType = CRAFTING_TYPE_CLOTHIER, armorType = ARMORTYPE_LIGHT, equipType = EQUIP_TYPE_HAND },
    [26] = { craftingType = CRAFTING_TYPE_CLOTHIER, armorType = ARMORTYPE_LIGHT, equipType = EQUIP_TYPE_HEAD },
    [31] = { craftingType = CRAFTING_TYPE_CLOTHIER, armorType = ARMORTYPE_LIGHT, equipType = EQUIP_TYPE_LEGS },
    [29] = { craftingType = CRAFTING_TYPE_CLOTHIER, armorType = ARMORTYPE_LIGHT, equipType = EQUIP_TYPE_SHOULDERS },
    [30] = { craftingType = CRAFTING_TYPE_CLOTHIER, armorType = ARMORTYPE_LIGHT, equipType = EQUIP_TYPE_WAIST },
    [37] = { craftingType = CRAFTING_TYPE_CLOTHIER, armorType = ARMORTYPE_MEDIUM, equipType = EQUIP_TYPE_CHEST },
    [41] = { craftingType = CRAFTING_TYPE_CLOTHIER, armorType = ARMORTYPE_MEDIUM, equipType = EQUIP_TYPE_FEET },
    [43] = { craftingType = CRAFTING_TYPE_CLOTHIER, armorType = ARMORTYPE_MEDIUM, equipType = EQUIP_TYPE_HAND },
    [35] = { craftingType = CRAFTING_TYPE_CLOTHIER, armorType = ARMORTYPE_MEDIUM, equipType = EQUIP_TYPE_HEAD },
    [40] = { craftingType = CRAFTING_TYPE_CLOTHIER, armorType = ARMORTYPE_MEDIUM, equipType = EQUIP_TYPE_LEGS },
    [38] = { craftingType = CRAFTING_TYPE_CLOTHIER, armorType = ARMORTYPE_MEDIUM, equipType = EQUIP_TYPE_SHOULDERS },
    [39] = { craftingType = CRAFTING_TYPE_CLOTHIER, armorType = ARMORTYPE_MEDIUM, equipType = EQUIP_TYPE_WAIST },

    [70] = { craftingType = CRAFTING_TYPE_WOODWORKING, weaponType = WEAPONTYPE_BOW },
    [65] = { craftingType = CRAFTING_TYPE_WOODWORKING, weaponType = WEAPONTYPE_SHIELD },
    [72] = { craftingType = CRAFTING_TYPE_WOODWORKING, weaponType = WEAPONTYPE_FIRE_STAFF },
    [73] = { craftingType = CRAFTING_TYPE_WOODWORKING, weaponType = WEAPONTYPE_FROST_STAFF },
    [74] = { craftingType = CRAFTING_TYPE_WOODWORKING, weaponType = WEAPONTYPE_LIGHTNING_STAFF },
    [71] = { craftingType = CRAFTING_TYPE_WOODWORKING, weaponType = WEAPONTYPE_HEALING_STAFF },

    [24] = { craftingType = CRAFTING_TYPE_JEWELRYCRAFTING, equipType = EQUIP_TYPE_RING },
    [18] = { craftingType = CRAFTING_TYPE_JEWELRYCRAFTING, equipType = EQUIP_TYPE_NECK },
}

-- UTF-8 Text from gamedata/lang *.lang.csv, record id 52420949. Index is the quest id.
local MASTER_WRIT_QUEST_NAME = {
    de = {
        ["Eine meisterhafte Waffe"] = true,
        ["Eine meisterhafte Glyphe"] = true,
        ["Eine meisterhafte Rüstung"] = true,
        ["Ein meisterhafter Schild"] = true,
        ["Ein meisterhaftes Mahl"] = true,
        ["Ein meisterhaftes Gewand"] = true,
        ["Meisterhafte Lederwaren"] = true,
        ["Ein meisterhaftes Gebräu"] = true,
        ["Ein meisterhaftes Schmuckstück"] = true,
    },
    en = {
        ["A Masterful Weapon"] = true,
        ["A Masterful Glyph"] = true,
        ["A Masterful Plate"] = true,
        ["A Masterful Shield"] = true,
        ["A Masterful Feast"] = true,
        ["Masterful Tailoring"] = true,
        ["Masterful Leatherwear"] = true,
        ["A Masterful Concoction"] = true,
        ["Masterful Jewelry"] = true,
    },
    es = {
        ["Un arma magistral"] = true,
        ["Un glifo magistral"] = true,
        ["Una protección magistral"] = true,
        ["Un escudo magistral"] = true,
        ["Un festín magistral"] = true,
        ["Una confección magistral"] = true,
        ["Una prenda de cuero magistral"] = true,
        ["Un brebaje magistral"] = true,
        ["Una joyería magistral"] = true,
        ["Joyería magistral"] = true,
    },
    fr = {
        ["Une arme magistrale"] = true,
        ["Un glyphe magistral"] = true,
        ["Une protection magistrale"] = true,
        ["Un bouclier magistral"] = true,
        ["Un festin magistral"] = true,
        ["Une tenue magistrale"] = true,
        ["Un vêtement de cuir magistral"] = true,
        ["Une concoction magistrale"] = true,
        ["Joaillerie magistrale"] = true,
    },
    jp = {
        ["優れた武器"] = true,
        ["優れたグリフ"] = true,
        ["優れた防具"] = true,
        ["優れた盾"] = true,
        ["優れた料理"] = true,
        ["優れた服"] = true,
        ["優れた革装備"] = true,
        ["優れた調合薬"] = true,
        ["優れた宝飾"] = true,
    },
    ru = {
        ["Мастерское оружие"] = true,
        ["Мастерский глиф"] = true,
        ["Мастерские доспехи"] = true,
        ["Мастерский щит"] = true,
        ["Мастерский пир"] = true,
        ["Мастерское шитье"] = true,
        ["Мастерская кожаная одежда"] = true,
        ["Мастерский отвар"] = true,
        ["Мастерское ювелирное изделие"] = true,
    },
    zh = {
        ["工艺精湛的武器"] = true,
        ["工艺精湛的雕文"] = true,
        ["工艺精湛的护甲"] = true,
        ["工艺精湛的盾牌"] = true,
        ["令人垂涎的盛宴"] = true,
        ["精妙绝伦的剪裁"] = true,
        ["工艺精湛的皮衣"] = true,
        ["完美无缺的调和物"] = true,
        ["大师级的珠宝"] = true,
    },
}

local QueueNextWrit = ZO_InitializingObject:Subclass()
local queueNextWrit

function QueueNextWrit:Initialize()
    self.callLaterRegistrationId = 1
    self.completableByCraftingType = {
        [CRAFTING_TYPE_BLACKSMITHING] = self.IsGearWritCompletable,
        [CRAFTING_TYPE_CLOTHIER] = self.IsGearWritCompletable,
        [CRAFTING_TYPE_WOODWORKING] = self.IsGearWritCompletable,
        [CRAFTING_TYPE_JEWELRYCRAFTING] = self.IsGearWritCompletable,
        [CRAFTING_TYPE_ENCHANTING] = self.IsEnchantingWritCompletable,
        [CRAFTING_TYPE_PROVISIONING] = self.IsProvisioningWritCompletable,
        [CRAFTING_TYPE_ALCHEMY] = self.IsAlchemyWritCompletable,
    }
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_QUEST_COMPLETE, function(eventId, questName, level, previousExperience, currentExperience, championPoints, questType, zoneDisplayType)
        self:OnQuestComplete(eventId, questName, level, previousExperience, currentExperience, championPoints, questType, zoneDisplayType)
    end)
end

function QueueNextWrit:OnQuestComplete(_eventId, questName, _level, _previousExperience, _currentExperience, _championPoints, questType, _zoneDisplayType)
    if questType ~= QUEST_TYPE_CRAFTING or not self:IsMasterWritQuestName(questName) then
        return
    end
    local slotIndex = self:FindCompletableMasterWritSlotIndex()
    if not slotIndex then
        return
    end
    self:CallLater(function()
        SCENE_MANAGER:Toggle("hud")
        self:UseMasterWritAndAcceptQuest(slotIndex)
    end, HUD_TOGGLE_DELAY_MILLISECONDS)
end

function QueueNextWrit:CallLater(callback, delayMilliseconds)
    local registrationId = self.callLaterRegistrationId
    local updateName = ADDON_NAME .. registrationId
    self.callLaterRegistrationId = self.callLaterRegistrationId + 1

    EVENT_MANAGER:RegisterForUpdate(updateName, delayMilliseconds, function()
        EVENT_MANAGER:UnregisterForUpdate(updateName)
        callback()
    end)
    return registrationId
end

function QueueNextWrit:IsMasterWritQuestName(questName)
    if type(questName) ~= "string" then
        return false
    end
    local questNamesForLanguage = MASTER_WRIT_QUEST_NAME[GetCVar("language.2")]
    if not questNamesForLanguage then
        return false
    end
    if questNamesForLanguage[questName] then
        return true
    end
    return questNamesForLanguage[zo_strformat("<<1>>", questName)] == true
end

function QueueNextWrit:ReadSealedWritLink(itemLink)
    local linkFields = { ZO_LinkHandler_ParseLink(itemLink) }
    if linkFields[3] ~= ITEM_LINK_TYPE then
        return nil
    end
    local icon = GetItemLinkInfo(itemLink)
    local craftingType = MASTER_WRIT_ICON_CRAFTING_TYPE[icon]
    if not craftingType then
        return nil
    end
    return {
        craftingType = craftingType,
        firstValue = tonumber(linkFields[10]),
        secondValue = tonumber(linkFields[11]),
        thirdValue = tonumber(linkFields[12]),
        fourthValue = tonumber(linkFields[13]),
        fifthValue = tonumber(linkFields[14]),
        sixthValue = tonumber(linkFields[15]),
    }
end

function QueueNextWrit:IsItemCraftedByPlayer(slotIndex, itemLink)
    if not IsItemLinkCrafted(itemLink) then
        return false
    end
    local creatorName = zo_strformat(SI_UNIT_NAME, GetItemCreatorName(BAG_BACKPACK, slotIndex))
    if creatorName == "" then
        return false
    end
    return creatorName == zo_strformat(SI_UNIT_NAME, GetUnitName("player"))
end

function QueueNextWrit:CountMatchingCraftedItems(itemMatches)
    local stackCount = 0
    for slotIndex in ZO_IterateBagSlots(BAG_BACKPACK) do
        local itemLink = GetItemLink(BAG_BACKPACK, slotIndex, LINK_STYLE_DEFAULT)
        if itemLink ~= "" and self:IsItemCraftedByPlayer(slotIndex, itemLink) and itemMatches(itemLink) then
            stackCount = stackCount + (GetSlotStackSize(BAG_BACKPACK, slotIndex) or 0)
        end
    end
    return stackCount
end

function QueueNextWrit:IsLightRobe(itemLink)
    local itemId = GetItemLinkItemId(itemLink)
    if not itemId or itemId == 0 then
        return false
    end
    local baseItemLink = string.format("|H1:item:%d:%d:50:0:0:0:0:0:0:0:0:0:0:0:0:%d:%d:0:0:%d:0|h|h", itemId, 0, 0, 0, 10000)
    return GetItemLinkIcon(baseItemLink) == LIGHT_ROBE_ICON
end

function QueueNextWrit:DoesGearItemMatchPiece(itemLink, gearPiece)
    if GetItemLinkCraftingSkillType(itemLink) ~= gearPiece.craftingType then
        return false
    end
    if gearPiece.weaponType and GetItemLinkWeaponType(itemLink) ~= gearPiece.weaponType then
        return false
    end
    if gearPiece.armorType and GetItemLinkArmorType(itemLink) ~= gearPiece.armorType then
        return false
    end
    if gearPiece.equipType and GetItemLinkEquipType(itemLink) ~= gearPiece.equipType then
        return false
    end
    if gearPiece.isRobe ~= nil and self:IsLightRobe(itemLink) ~= gearPiece.isRobe then
        return false
    end
    return true
end

function QueueNextWrit:DoesGearItemFulfillWrit(itemLink, sealedWrit)
    local templateId = sealedWrit.firstValue
    local quality = sealedWrit.thirdValue
    local setId = sealedWrit.fourthValue
    local traitType = sealedWrit.fifthValue
    local styleId = sealedWrit.sixthValue
    local gearPiece = GEAR_PIECE_BY_TEMPLATE_ID[templateId]
    if not gearPiece or not quality or not setId or not traitType then
        return false
    end
    if gearPiece.craftingType ~= sealedWrit.craftingType then
        return false
    end
    if GetItemLinkRequiredChampionPoints(itemLink) ~= SMITHING_MASTER_WRIT_CHAMPION_POINTS then
        return false
    end
    if GetItemLinkFunctionalQuality(itemLink) < quality then
        return false
    end
    local hasSet, _setName, _numBonuses, _numNormalEquipped, _maxEquipped, itemSetId = GetItemLinkSetInfo(itemLink)
    if not hasSet or itemSetId ~= setId then
        return false
    end
    if GetItemLinkTraitInfo(itemLink) ~= traitType then
        return false
    end
    if styleId and styleId > 0 and GetItemLinkItemStyle(itemLink) ~= styleId then
        return false
    end
    return self:DoesGearItemMatchPiece(itemLink, gearPiece)
end

function QueueNextWrit:DoesGlyphFulfillWrit(itemLink, sealedWrit)
    local glyphItemId = sealedWrit.firstValue
    local championPoints = ENCHANTING_WRIT_LEVEL_CHAMPION_POINTS[sealedWrit.secondValue]
    local quality = sealedWrit.thirdValue
    if not glyphItemId or not championPoints or not quality then
        return false
    end
    if GetItemLinkItemId(itemLink) ~= glyphItemId then
        return false
    end
    if GetItemLinkRequiredChampionPoints(itemLink) ~= championPoints then
        return false
    end
    return GetItemLinkFunctionalQuality(itemLink) >= quality
end

function QueueNextWrit:GetProvisioningRequiredStackCount(resultItemId)
    local _craftingStationType, recipeListIndex, recipeIndex = GetRecipeInfoFromItemId(resultItemId)
    if not recipeListIndex or not recipeIndex then
        return nil
    end
    local requiredStackCount = GetRecipeResultQuantity(recipeListIndex, recipeIndex, PROVISIONING_CRAFT_ITERATIONS)
    if not requiredStackCount or requiredStackCount < 1 then
        return nil
    end
    return requiredStackCount
end

function QueueNextWrit:ReadPotionEffectIds(itemLink)
    local encodedEffects = tonumber(select(24, ZO_LinkHandler_ParseLink(itemLink)))
    if not encodedEffects then
        return nil
    end
    return BitAnd(BitRShift(encodedEffects, 16), 0x7F), BitAnd(BitRShift(encodedEffects, 8), 0x7F), BitAnd(encodedEffects, 0x7F)
end

function QueueNextWrit:DoPotionEffectsMatch(itemLink, writEffectId1, writEffectId2, writEffectId3)
    if not writEffectId1 or not writEffectId2 or not writEffectId3 then
        return false
    end
    local itemEffectId1, itemEffectId2, itemEffectId3 = self:ReadPotionEffectIds(itemLink)
    if not itemEffectId1 then
        return false
    end
    local itemEffectIds = {
        [itemEffectId1] = true,
        [itemEffectId2] = true,
        [itemEffectId3] = true,
    }
    return itemEffectIds[writEffectId1] and itemEffectIds[writEffectId2] and itemEffectIds[writEffectId3]
end

function QueueNextWrit:IsGearWritCompletable(sealedWrit)
    return self:CountMatchingCraftedItems(function(itemLink)
        return self:DoesGearItemFulfillWrit(itemLink, sealedWrit)
    end) >= 1
end

function QueueNextWrit:IsEnchantingWritCompletable(sealedWrit)
    return self:CountMatchingCraftedItems(function(itemLink)
        return self:DoesGlyphFulfillWrit(itemLink, sealedWrit)
    end) >= 1
end

function QueueNextWrit:IsProvisioningWritCompletable(sealedWrit)
    local resultItemId = sealedWrit.firstValue
    local requiredStackCount = resultItemId and self:GetProvisioningRequiredStackCount(resultItemId)
    if not requiredStackCount then
        return false
    end
    return self:CountMatchingCraftedItems(function(itemLink)
        return GetItemLinkItemId(itemLink) == resultItemId
    end) >= requiredStackCount
end

function QueueNextWrit:IsAlchemyWritCompletable(sealedWrit)
    local solventId = sealedWrit.firstValue
    if not solventId then
        return false
    end
    local requiredItemType = ITEMTYPE_POISON
    if solventId == ALCHEMY_POTION_SOLVENT_ID then
        requiredItemType = ITEMTYPE_POTION
    end
    return self:CountMatchingCraftedItems(function(itemLink)
        if GetItemLinkItemType(itemLink) ~= requiredItemType then
            return false
        end
        if GetItemLinkRequiredChampionPoints(itemLink) ~= ALCHEMY_MASTER_WRIT_CHAMPION_POINTS then
            return false
        end
        return self:DoPotionEffectsMatch(itemLink, sealedWrit.secondValue, sealedWrit.thirdValue, sealedWrit.fourthValue)
    end) >= ALCHEMY_MASTER_WRIT_REQUIRED_STACK_COUNT
end

function QueueNextWrit:IsMasterWritCompletable(itemLink)
    local sealedWrit = self:ReadSealedWritLink(itemLink)
    if not sealedWrit then
        return false
    end
    local isWritCompletable = self.completableByCraftingType[sealedWrit.craftingType]
    return isWritCompletable ~= nil and isWritCompletable(self, sealedWrit)
end

function QueueNextWrit:FindCompletableMasterWritSlotIndex()
    for slotIndex in ZO_IterateBagSlots(BAG_BACKPACK) do
        if GetItemType(BAG_BACKPACK, slotIndex) == ITEMTYPE_MASTER_WRIT then
            local itemLink = GetItemLink(BAG_BACKPACK, slotIndex, LINK_STYLE_DEFAULT)
            if itemLink ~= "" and self:IsMasterWritCompletable(itemLink) then
                return slotIndex
            end
        end
    end
end

function QueueNextWrit:UseMasterWritAndAcceptQuest(slotIndex)
    self:CallLater(function()
        CallSecureProtected("UseItem", BAG_BACKPACK, slotIndex)
    end, USE_ITEM_DELAY_MILLISECONDS)
    self:CallLater(function()
        AcceptOfferedQuest()
    end, ACCEPT_QUEST_DELAY_MILLISECONDS)
end

local function OnAddOnLoaded(_eventId, addonName)
    if addonName ~= ADDON_NAME then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    queueNextWrit = QueueNextWrit:New()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
