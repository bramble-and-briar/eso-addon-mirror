local C = CrownCrateCodex
local crateAliases={ ["ouroboros crown crate"]="ouroboros crate" }
function C:HistoricalCatalogFor(crate)
    if not crate then return end
    local name=string.lower(crate.name or "")
    local key=crateAliases[name] or name
    if self.historicalCatalog and self.historicalCatalog[key] then
        -- Cache the verified English identity beside the numeric crate ID. The
        -- displayed client-language name can subsequently change independently.
        crate.catalogKey=key
    end
    return self.historicalCatalog and self.historicalCatalog[crate.catalogKey or key]
end
function C:HistoricalRewardFact(key)
    if not self.historicalRewardFacts then
        local facts={}
        for _,catalog in pairs(self.historicalCatalog or {}) do
            for identity,tier in pairs(catalog) do
                if type(tier)=="number" then
                    local previous=facts[identity]
                    if previous==nil then facts[identity]={tier=tier,source=catalog.source}
                    elseif previous and previous.tier~=tier then facts[identity]=false end
                end
            end
        end
        self.historicalRewardFacts=facts
    end
    -- IDs, product type and stack only. Conflicting catalog facts stay unknown.
    return self.historicalRewardFacts[key]
end
function C:ApplyHistoricalCatalog(opening, reward)
    local crate = self.db.crates[opening.crateId]
    local catalog = self:HistoricalCatalogFor(crate)
    local kind = reward.productType == MARKET_PRODUCT_TYPE_COLLECTIBLE and "c" or reward.productType == MARKET_PRODUCT_TYPE_ITEM and "i"
    if not kind then return end
    local key = kind .. ":" .. tostring(reward.referenceId) .. ":" .. tostring(reward.stack)
    local itemFact = kind=="i" and self.historicalItemCatalog and self.historicalItemCatalog[reward.referenceId]
    local fact=self:HistoricalRewardFact(key)
    local tier = catalog and catalog[key] or itemFact and itemFact.tier or fact and fact.tier
    if not tier then return end
    if reward.apexUnresolved and tier<6 then return end
    reward.catalogTier, reward.catalogSource = tier, catalog and catalog[key] and catalog.source or itemFact and itemFact.tier and itemFact.source or fact.source
    if not reward.tier or reward.tier==0 or reward.apexUnresolved or not reward.rarity then
        reward.rarity=tier
        reward.apexUnresolved=nil
        reward.raritySource="UESP crate catalog"
        if opening.source=="tracker" then reward.tierSource="UESP crate catalog" end
    end
end

function C.RewardRarityName(reward)
    if reward.apexUnresolved then return C.L("Apex tier: split unresolved") end
    return C.RarityName(reward.rarity)
end

function C.RewardTierName(reward)
    if reward.catalogTier then return C.RewardRarityName(reward) .. C.L(" (catalog)") end
    return C.TierName(reward.tier)
end
