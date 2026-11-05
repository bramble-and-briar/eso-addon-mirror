local C = CrownCrateCodex
C.rarityNames = { "Common", "Fine", "Superior", "Epic", "Legendary", "Apex", "Radiant Apex" }
C.referenceRates = { 98, 72, 86, 21, 14, 2 }
local function GemHint(gems,quantity,source)
    local function Word(one,many,count)
        if C.LanguageCode and C:LanguageCode()=="ru" then
            local mod10,mod100=count%10,count%100
            if mod10==1 and mod100~=11 then return C.L(one) end
            if mod10>=2 and mod10<=4 and not (mod100>=12 and mod100<=14) then
                return one=="Crown Gem" and "кронных самоцвета" or "предмета"
            end
            return C.L(many)
        end
        return C.L(count==1 and one or many)
    end
    return "\n|cB270FF"..string.format(C.L("Gem Extraction: %d %s per %d %s."),gems,Word("Crown Gem","Crown Gems",gems),quantity,Word("item","items",quantity)).."|r\n|cB270FF"..C.L("For the Crown Crate version; potential value, not gems earned.").."|r\n"..string.format(C.L("Extraction source: %s"),source)
end
function C:ItemGemHint(reward)
    if reward.productType~=MARKET_PRODUCT_TYPE_ITEM then return "" end
    if GetNumCrownGemsFromItemManualGemification and GetBagSize and GetItemId and BAG_BACKPACK then
        for slot=0,GetBagSize(BAG_BACKPACK)-1 do
            if GetItemId(BAG_BACKPACK,slot)==reward.referenceId then
                local required,gems=GetNumCrownGemsFromItemManualGemification(BAG_BACKPACK,slot)
                if required and required>0 and gems and gems>0 then
                    return GemHint(gems,required,C.L("ESO (matching backpack item)"))
                end
            end
        end
    end
    local fact=self.gemExtractionCatalog and self.gemExtractionCatalog[tostring(reward.referenceId)..":"..tostring(reward.stack)]
    if fact then
        return GemHint(fact.gems,reward.stack,C.L("UESP catalog - ")..fact.source)
    end
    return "\n|cB270FF"..C.L("Extraction value not yet verified for this reward stack. Check Gem Extraction in ESO.").."|r"
end
C.rarityColors={"AEB8C5","66D06B","4BAAF0","B270FF","E7C877","FFA83D","FF766E"}

function C.RarityName(rarity)
    return C.L(C.rarityNames[rarity] or C.L("Unknown rarity"))
end

function C:EnrichReward(reward)
    -- The tier's NPC reaction groups are supplied by ESO, independent of season IDs.
    -- The sixth reaction groups Apex and Radiant together; do not pretend to split them.
    if reward.tier and reward.tier > 0 and GetCrownCrateTierReactionNPCAnimation then
        reward.rarity,reward.apexUnresolved=nil,nil
        local reaction = GetCrownCrateTierReactionNPCAnimation(reward.tier)
        local reactions = {
            CROWN_CRATE_NPC_ANIMATION_TYPE_TIER_ONE_CARD,
            CROWN_CRATE_NPC_ANIMATION_TYPE_TIER_TWO_CARD,
            CROWN_CRATE_NPC_ANIMATION_TYPE_TIER_THREE_CARD,
            CROWN_CRATE_NPC_ANIMATION_TYPE_TIER_FOUR_CARD,
            CROWN_CRATE_NPC_ANIMATION_TYPE_TIER_FIVE_CARD,
            CROWN_CRATE_NPC_ANIMATION_TYPE_TIER_SIX_CARD,
        }
        if reaction then
            for index, value in pairs(reactions) do
                if value==reaction then
                    if index==6 then reward.apexUnresolved=true else reward.rarity=index end
                    break
                end
            end
        end
    end
    local name, icon, typeText
    if reward.productType == MARKET_PRODUCT_TYPE_COLLECTIBLE and reward.referenceId and GetCollectibleInfo then
        local description, locked, unlocked, purchasable, active, category
        name, description, icon, locked, unlocked, purchasable, active, category = GetCollectibleInfo(reward.referenceId)
        reward.categoryId = category
        if category and GetString then typeText = GetString("SI_COLLECTIBLECATEGORYTYPE", category) end
    elseif reward.productType == MARKET_PRODUCT_TYPE_ITEM and reward.link and reward.link ~= "" and GetItemLinkName then
        name = GetItemLinkName(reward.link)
        icon = GetItemLinkIcon(reward.link)
        if GetItemLinkItemType and GetString then typeText = GetString("SI_ITEMTYPE", GetItemLinkItemType(reward.link)) end
    end
    if name and name ~= "" then reward.name = zo_strformat("<<1>>", name) end
    if icon and icon ~= "" then reward.icon = icon end
    if typeText and typeText ~= "" then reward.typeText = typeText end
    reward.icon = reward.icon or reward.image or "EsoUI/Art/Icons/icon_missing.dds"
    if reward.icon == "" then reward.icon = "EsoUI/Art/Icons/icon_missing.dds" end
end

function C:BackfillLegacyTiers(crateId)
    local known = {}
    for _, opening in ipairs(self.db.history) do
        if opening.crateId == crateId and opening.source ~= "tracker" then
            for _, reward in ipairs(opening.rewards) do
                if reward.tier and reward.tier > 0 then
                    local key = C.RewardKey(reward) .. ":" .. reward.stack
                    local previous = known[key]
                    if previous and previous.tier ~= reward.tier then known[key] = false
                    elseif previous == nil then known[key] = reward end
                end
            end
        end
    end
    for _, opening in ipairs(self.db.history) do
        if opening.crateId == crateId and opening.source == "tracker" then
            for _, reward in ipairs(opening.rewards) do
                local match = known[C.RewardKey(reward) .. ":" .. reward.stack]
                if match then
                    reward.tier, reward.rarity, reward.tierSource = match.tier, match.rarity, "matched live reward"
                    reward.apexUnresolved=match.apexUnresolved
                elseif reward.tierSource == "matched live reward" then
                    reward.tier, reward.rarity, reward.tierSource = 0, nil, nil
                    reward.apexUnresolved=nil
                end
            end
        end
    end
end

function C:RebuildCatalog()
    for _, crate in pairs(self.db.crates) do crate.rewards = {} end
    for _, opening in ipairs(self.db.history) do
        local crate = self.db.crates[opening.crateId] or self:LearnCrate(opening.crateId)
        for _, reward in ipairs(opening.rewards) do
            self:EnrichReward(reward)
            if self.ApplyHistoricalCatalog then self:ApplyHistoricalCatalog(opening, reward) end
            local key = C.RewardKey(reward)
            local previous = crate.rewards[key]
            if not previous or (reward.tier or 0) > 0 then crate.rewards[key] = reward end
        end
    end
end
