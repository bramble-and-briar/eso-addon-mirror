if not SemisPlaygroundCheckAccess() then return end

BattleScrolls = BattleScrolls or {}

---@alias InventoryPocKind 'other'|'gear'|'companion'|'glyph'|'treasure'|'junk'|'food'|'poison'|'potion'|'script'|'motif'|'recipe'|'plan'|'collectible'|'fragment'|'container'|'soulGem'|'map'|'survey'|'writ'|'sealedContainer'|'sealedLead'
---@alias InventoryPocAction 'keep'|'defer'|'sell'|'deconstruct'|'bank'|'learn'|'list'|'destroy'|'open'|'bind'|'equip'
---@alias InventoryPocReason 'reserved'|'stolen'|'crown'|'junk'|'glyph'|'material'|'gear'|'knowledge'|'price'|'companion'|'container'|'supplies'|'unassigned'|'learn'|'valuablePlan'|'duplicate'|'sale'|'collection'

---@class InventoryPocItem: InventoryPocVariant
---@field bag number
---@field slot number
---@field uniqueId string
---@field itemId number
---@field link string
---@field name string
---@field searchName string
---@field stack number
---@field keepQuantity number|nil Copies reserved for a missing antiquity fragment
---@field antiquityId number|nil Sealed lead's target
---@field openAfter number|nil Next daily reset for a gated reward coffer
---@field maxStack number
---@field kind InventoryPocKind
---@field quality number
---@field trait number
---@field style number
---@field equipType number
---@field armorType number
---@field weaponType number
---@field level number
---@field championPoints number
---@field reserved boolean
---@field locked boolean|nil Player lock, including equipped companion slots
---@field stolen boolean
---@field crown boolean
---@field vendorUnit number
---@field prioritySell boolean|nil Native merchant recommendation
---@field marketUnit number|nil
---@field priceLoading boolean|nil TSC has not finished loading; distinct from a missing quote
---@field styleMaterialLink string
---@field styleMaterialUnit number|nil
---@field traitMaterialLink string
---@field traitMaterialUnit number|nil
---@field traitMaterialResolved boolean
---@field tradeable boolean|nil Native guild-store eligibility for player and companion gear
---@field hasSet boolean|nil
---@field setCollected boolean|nil Nil when the gear has no sticker-book entry
---@field collectionKey string|nil Set ID and slot for a missing collection entry
---@field improvementMaterialLink string|nil Gold gear's upgrade material
---@field improvementMaterialUnit number|nil
---@field known boolean|nil Knowledge of the current character/account, as applicable
---@field crafterKnown boolean|nil Knowledge of the account's arcanist
---@field isCrafter boolean
---@field companionNeeded boolean|nil Nil until the companion kits have been captured
---@field usable boolean
---@field learnQuantity number|nil Required pieces per use; unknown fragment requirements stay unset
---@field learnProgress number|nil Pieces already used toward a skill-style collectible
---@field learnRequired number|nil Total pieces to finish that progress
---@field filledSoulGem boolean
---@field crafted boolean|nil Set for player gear, potions and poisons
---@field hasOnUseAbility boolean|nil Set for potions and poisons
---@field onUseAbilityId number|nil Native fixed ability for potions and poisons
---@field alchemyTraitCount number|nil Counted across all native alchemy trait slots

---@class InventoryPocDecision
---@field action InventoryPocAction
---@field reason InventoryPocReason

---@class InventoryPocQuote
---@field unitPrice number Unrounded price after discounts; round only the listing total
---@field totalPrice number
---@field quantity number
---@field discount number

---@class InventoryPocPolicy
---@field MIN_LISTING number
---@field EXPENSIVE_PLAN number
local policy = {
    MIN_LISTING = 2000,
    EXPENSIVE_PLAN = 10000,
}
BattleScrolls.inventoryPocPolicy = policy

-- Estimates for maxed extraction passives and Meticulous Disassembly.
-- Samples, limitations and the chosen rounding: docs/inventory-addon/material-recovery.md.
local STYLE_MATERIAL_CHANCE, TRAIT_MATERIAL_CHANCE = 0.40, 0.75
local MATERIAL_VENDOR_MULTIPLIER = 2
local JEWELRY_TRAIT_PIECES = 10

---@param action InventoryPocAction
---@param reason InventoryPocReason
---@return InventoryPocDecision
local function decision(action, reason)
    return { action = action, reason = reason }
end

---@param price number|nil
---@return boolean
function policy.validPrice(price)
    return type(price) == 'number' and price > 0 and price < math.huge
end

---@param item InventoryPocItem
---@return number|nil value Nil means a material or its price is unresolved
local function expectedMaterialValue(item)
    if not item.traitMaterialResolved then return nil end
    local value = 0
    if item.styleMaterialLink ~= '' then
        if not policy.validPrice(item.styleMaterialUnit) then return nil end
        value = STYLE_MATERIAL_CHANCE * item.styleMaterialUnit
    end
    if item.traitMaterialLink ~= '' then
        if not policy.validPrice(item.traitMaterialUnit) then return nil end
        -- GetSmithingTraitItemLink supplies the refined trait stone, but jewelry
        -- deconstruction returns one pulverized piece: ten pieces make a stone.
        local pieces = (item.equipType == EQUIP_TYPE_RING or item.equipType == EQUIP_TYPE_NECK) and JEWELRY_TRAIT_PIECES or 1
        value = value + TRAIT_MATERIAL_CHANCE * item.traitMaterialUnit / pieces
    end
    return value
end

---@param item InventoryPocItem
---@return number|nil floor A missing recovery quote leaves the sale floor unresolved
function policy.gearSaleMinimum(item)
    local materialValue = expectedMaterialValue(item)
    if materialValue == nil then return nil end
    if item.quality >= 5 then
        if not policy.validPrice(item.improvementMaterialUnit) then return nil end
        -- Reserve one full upgrade material's value for gold gear. This sale
        -- floor covers its possible return without assuming an extraction rate.
        materialValue = materialValue + item.improvementMaterialUnit
    end
    return math.max(policy.MIN_LISTING, item.vendorUnit, materialValue)
end

---@param item InventoryPocItem
---@return number quantity Zero when no suitable listing reaches the minimum
function policy.listingQuantity(item)
    local unit = item.marketUnit
    if not policy.validPrice(unit) or policy.disposalQuantity(item) < 1 then return 0 end
    -- Identical pieces are useful in multiples only when we know the quantity
    -- that makes one collectible. Other learnables and equipment sell singly.
    local complete = item.kind == 'fragment' and (item.learnRequired or item.learnQuantity)
    if not complete or complete <= 1 then return math.floor(unit) >= policy.MIN_LISTING and 1 or 0 end
    local minimum = math.ceil(policy.MIN_LISTING / unit)
    if math.floor(unit * minimum) < policy.MIN_LISTING then minimum = minimum + 1 end
    if minimum > item.stack then return 0 end
    local function canLeave(quantity)
        local remainder = item.stack - quantity
        return remainder == 0 or remainder >= minimum
    end
    if complete >= minimum and complete <= item.stack and canLeave(complete) then return complete end
    if canLeave(minimum) then return minimum end
    return item.stack
end

---@param item InventoryPocItem
---@return number
function policy.disposalQuantity(item)
    return math.max(0, item.stack - (item.keepQuantity or 0))
end

---Only a completed search may supply lowestUnit. Companion searches use the
---same quality, trait and equipment class; other searches require exact variants.
---Expired stock gets one discount from today's baseline, not the previous ask.
---@param tscUnit number|nil
---@param lowestUnit number|nil
---@param lowestSeconds number|nil
---@param quantity number
---@param expired boolean
---@return InventoryPocQuote|nil
function policy.quote(tscUnit, lowestUnit, lowestSeconds, quantity, expired)
    if quantity < 1 or quantity ~= math.floor(quantity) then return nil end
    local baseline
    if policy.validPrice(tscUnit) then baseline = tscUnit end
    if policy.validPrice(lowestUnit) then baseline = math.min(baseline or lowestUnit, lowestUnit) end
    if not baseline then return nil end
    local oldListing = policy.validPrice(lowestUnit) and lowestSeconds and lowestSeconds >= 0 and lowestSeconds < 16 * 86400
    local discount = expired and 0.5 or (oldListing and 0.8 or 1)
    local total = math.floor(baseline * discount * quantity)
    if total < 1 then return nil end
    return { unitPrice = baseline * discount, totalPrice = total, quantity = quantity, discount = discount }
end

---@param item InventoryPocItem
---@param cheapAction InventoryPocAction
---@return InventoryPocDecision
local function sellDuplicate(item, cheapAction)
    if not policy.validPrice(item.marketUnit) then return decision('defer', 'price') end
    if policy.listingQuantity(item) > 0 then return decision('list', 'duplicate') end
    return decision(cheapAction, 'duplicate')
end

---Priority is deliberate: protections, special uses, then generic cleanup.
---@param item InventoryPocItem
---@return InventoryPocDecision
function policy.decide(item)
    if item.reserved then return decision('keep', 'reserved') end
    if item.stolen then return decision('keep', 'stolen') end
    if item.kind == 'sealedLead' then
        if policy.disposalQuantity(item) == 0 then return decision('bank', 'knowledge') end
        if item.priceLoading then return decision('defer', 'price') end
        return decision(policy.listingQuantity(item) > 0 and 'list' or 'sell', 'duplicate')
    end
    if item.kind == 'container' and item.openAfter then return decision('keep', 'container') end
    if item.kind == 'map' or item.kind == 'survey' or item.kind == 'writ' or item.kind == 'sealedContainer' then
        return decision('bank', 'supplies')
    end
    if item.crown then
        if item.kind == 'food' or item.kind == 'poison' then return decision('bank', 'crown') end
        if item.kind == 'container' then return decision('open', 'container') end
        return decision('keep', 'crown')
    end
    if item.kind == 'gear' and item.setCollected == false then return decision('bind', 'collection') end
    if item.prioritySell then return decision('sell', 'junk') end
    -- The native "Scroll" subtype also contains supplies worth keeping.
    -- This personal sale choice is for the unbound Scrying/Excavation treatise.
    if item.itemId == 227303 then
        if not policy.validPrice(item.marketUnit) then return decision('defer', 'price') end
        return decision(policy.listingQuantity(item) > 0 and 'list' or 'keep', 'sale')
    end
    if item.kind == 'treasure' or item.kind == 'junk' then return decision('sell', 'junk') end
    if item.kind == 'glyph' then return decision('deconstruct', 'glyph') end
    if item.kind == 'food' and item.quality == 1 then return decision('sell', 'junk') end
    if item.kind == 'poison' and item.quality == 1 and item.crafted == false then return decision('sell', 'junk') end
    if item.kind == 'potion' and item.quality == 1 and item.crafted == false and item.hasOnUseAbility == false
        and (item.alchemyTraitCount == 1 or item.alchemyTraitCount == 2) then return decision('sell', 'junk') end
    if item.kind == 'script' then
        if item.known == true then return decision('sell', 'junk') end
        return decision('keep', 'knowledge')
    end
    if item.kind == 'collectible' or item.kind == 'fragment' then
        if item.known == false then
            if item.kind == 'fragment' and (not item.learnQuantity or item.stack < item.learnQuantity) then
                return decision('bank', 'supplies')
            end
            return decision('learn', 'learn')
        end
        if item.known == nil then
            return item.kind == 'fragment' and decision('bank', 'supplies') or decision('defer', 'knowledge')
        end
        return sellDuplicate(item, 'destroy')
    end
    if item.kind == 'motif' or item.kind == 'recipe' or item.kind == 'plan' then
        if item.kind == 'plan' then
            if not policy.validPrice(item.marketUnit) then return decision('defer', 'price') end
            if item.marketUnit > policy.EXPENSIVE_PLAN then return decision('list', 'valuablePlan') end
        end
        if item.crafterKnown == nil then return decision('defer', 'knowledge') end
        if item.crafterKnown == false then
            return decision(item.isCrafter and 'learn' or 'bank', 'learn')
        end
        return sellDuplicate(item, 'sell')
    end
    if item.kind == 'companion' then
        if item.quality >= 5 then return decision('keep', 'companion') end
        if item.companionNeeded == true then return decision('keep', 'companion') end
        if item.companionNeeded == nil then return decision('defer', 'companion') end
        if item.quality <= 1 then return decision('sell', 'junk') end
        if item.tradeable == false then return decision('sell', 'duplicate') end
        if item.priceLoading then return decision('defer', 'price') end
        return sellDuplicate(item, 'sell')
    end
    if item.kind == 'gear' then
        if item.tradeable then
            if item.priceLoading then return decision('defer', 'price') end
            if policy.validPrice(item.marketUnit) then
                local minimum = policy.gearSaleMinimum(item)
                if minimum and math.floor(item.marketUnit) >= minimum then return decision('list', 'sale') end
                if not minimum and item.marketUnit >= policy.MIN_LISTING then return decision('defer', 'price') end
            end
        end
        if item.quality >= 5 then return decision('deconstruct', 'gear') end
        if item.priceLoading then return decision('defer', 'price') end
        local materialValue = expectedMaterialValue(item)
        -- No tax deduction: the required 100% margin already covers selling costs.
        -- An absent material contributes zero; a missing quote still favors decon.
        if materialValue == nil or (materialValue > 0 and materialValue >= MATERIAL_VENDOR_MULTIPLIER * item.vendorUnit) then
            return decision('deconstruct', 'material')
        end
        return decision('sell', 'junk')
    end
    if item.kind == 'container' then return decision('open', 'container') end
    if item.kind == 'soulGem' then return decision('keep', 'supplies') end
    return decision('keep', 'unassigned')
end

---Fragments can reach their use requirement across both account-bank bags
---and the pack. Only fetch a complete use; spare known copies need no minimum.
---@param item InventoryPocItem
---@param carried number Unreserved, matching items in the backpack
---@param banked number Unreserved, matching items in the account bank
---@return number
function policy.withdrawQuantity(item, carried, banked)
    local action = policy.decide(item).action
    if item.kind == 'fragment' and item.known == false and not item.learnProgress and (action == 'bank' or action == 'learn') then
        if not item.learnQuantity or carried + banked < item.learnQuantity then return 0 end
        return math.min(item.stack, math.max(0, item.learnQuantity - carried))
    end
    if action == 'learn' then
        local wanted = item.learnRequired and item.learnProgress and item.learnRequired - item.learnProgress or item.learnQuantity or 1
        return math.min(item.stack, math.max(0, wanted - carried))
    end
    if action == 'list' or action == 'sell' or action == 'destroy' then return policy.disposalQuantity(item) end
    if policy.needsMarketPrice(item) then return item.stack end
    return 0
end

---@param item InventoryPocItem
---@return boolean
function policy.needsMarketPrice(item)
    if item.kind ~= 'companion' and not (item.kind == 'gear' and item.tradeable) then return false end
    local choice = policy.decide(item)
    return choice.action == 'defer' and choice.reason == 'price'
end

---Positive means deposit, negative means withdraw. Never sells overflow.
---Use full 200-gem stacks where possible; a partly filled bank can accept less.
---@param backpack number
---@param bank number
---@return number
function policy.soulGemTransfer(backpack, bank)
    if backpack > 400 and bank < 1000 then
        return math.min(math.floor((backpack - 200) / 200) * 200, 1000 - bank)
    end
    if backpack < 200 and bank > 0 then return -math.min(400 - backpack, bank, 200) end
    return 0
end

---Slot reuse, restacking, and replacement copies invalidate a queued action.
---@param before InventoryPocItem
---@param current InventoryPocItem|nil
---@return boolean
function policy.sameItem(before, current)
    return current ~= nil and current.bag == before.bag and current.slot == before.slot
        and current.uniqueId == before.uniqueId and current.link == before.link and current.stack == before.stack
end

---Current listing identity: price/expiry do not form part of an item variant.
---@param a InventoryPocVariant
---@param b InventoryPocVariant
---@return boolean
function policy.sameVariant(a, b)
    return a.itemId == b.itemId and a.quality == b.quality and a.trait == b.trait
        and a.level == b.level and a.championPoints == b.championPoints
        and a.style == b.style
end

---Same-set substitutes retain quality, trait, level and equipment family.
---@param a InventoryPocVariant
---@param b InventoryPocVariant
---@return boolean
function policy.sameSetGearClass(a, b)
    if not a.setId or a.setId == 0 or a.setId ~= b.setId
        or a.actorCategory == GAMEPLAY_ACTOR_CATEGORY_COMPANION or b.actorCategory == GAMEPLAY_ACTOR_CATEGORY_COMPANION
        or a.quality ~= b.quality or a.trait ~= b.trait or a.level ~= b.level or a.championPoints ~= b.championPoints then
        return false
    end
    if a.weaponType ~= WEAPONTYPE_NONE then return a.weaponType == b.weaponType end
    if b.weaponType ~= WEAPONTYPE_NONE then return false end
    if a.equipType == EQUIP_TYPE_RING or a.equipType == EQUIP_TYPE_NECK then
        return b.equipType == EQUIP_TYPE_RING or b.equipType == EQUIP_TYPE_NECK
    end
    return a.armorType ~= ARMORTYPE_NONE and a.armorType == b.armorType
end

---@param weaponType number
---@return number[]
function policy.companionWeaponTypes(weaponType)
    local oneHand = { WEAPONTYPE_AXE, WEAPONTYPE_SWORD, WEAPONTYPE_HAMMER, WEAPONTYPE_DAGGER }
    local twoHand = { WEAPONTYPE_TWO_HANDED_AXE, WEAPONTYPE_TWO_HANDED_SWORD, WEAPONTYPE_TWO_HANDED_HAMMER }
    for _, types in ipairs({ oneHand, twoHand }) do
        for _, value in ipairs(types) do if value == weaponType then return types end end
    end
    -- Bows, each staff type, and shields have different uses and prices.
    return { weaponType }
end

---@param a InventoryPocVariant
---@param b InventoryPocVariant
---@return boolean
function policy.sameCompanionClass(a, b)
    if a.actorCategory ~= GAMEPLAY_ACTOR_CATEGORY_COMPANION or b.actorCategory ~= GAMEPLAY_ACTOR_CATEGORY_COMPANION
        or a.quality ~= b.quality or a.trait ~= b.trait then return false end
    if a.weaponType ~= WEAPONTYPE_NONE then
        for _, weaponType in ipairs(policy.companionWeaponTypes(a.weaponType)) do
            if b.weaponType == weaponType then return true end
        end
        return false
    end
    if b.weaponType ~= WEAPONTYPE_NONE then return false end
    if a.equipType == EQUIP_TYPE_RING or a.equipType == EQUIP_TYPE_NECK then
        return b.equipType == EQUIP_TYPE_RING or b.equipType == EQUIP_TYPE_NECK
    end
    return a.armorType ~= ARMORTYPE_NONE and a.armorType == b.armorType
end
