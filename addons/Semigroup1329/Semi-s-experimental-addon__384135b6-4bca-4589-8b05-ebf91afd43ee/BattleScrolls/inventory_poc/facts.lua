if not SemisPlaygroundCheckAccess() then return end

---@class InventoryPocWardrobeGear
---@field id string
---@field link string
---@class InventoryPocWardrobeSetup
---@field name string
---@field gear table<number, InventoryPocWardrobeGear>
---@field skills table<HotBarCategory, table<number, number>>|nil
---@field cp table<number, number>|nil
---@field code string|nil
---@field food table<string, string|number>|nil
---@class InventoryPocWardrobePage
---@field name string
---@field selected number|nil Only page zero
---@class InventoryPocWardrobeZone
---@field tag string
---@class InventoryPocWardrobeSelection
---@field zone InventoryPocWardrobeZone
---@field pageId number
---@class InventoryPocWardrobeSettings
---@field auto table<string, boolean>
---@field unequipEmpty boolean
---@class InventoryPocWardrobeConditions
---@field LoadSubstitute fun(bossName: string)
---@class InventoryPocWardrobeGui
---@field OnZoneSelect fun(zone: InventoryPocWardrobeZone)
---@class InventoryPocWardrobe
---@field version string
---@field setups table<string, table<number, table<number, InventoryPocWardrobeSetup>>>
---@field pages table<string, table<number, InventoryPocWardrobePage>>
---@field zones table<string, InventoryPocWardrobeZone>
---@field selection InventoryPocWardrobeSelection
---@field settings InventoryPocWardrobeSettings
---@field conditions InventoryPocWardrobeConditions
---@field gui InventoryPocWardrobeGui
---@field LoadSetup fun(zone: InventoryPocWardrobeZone, page: number, index: number, auto: boolean, skipValidation: boolean|nil): boolean
---@field AreSkillsEqual fun(a: number, b: number): boolean|nil
---@field GetSlotBoundAbilityId fun(slot: number, bar: HotBarCategory): number
---@field HasCryptCanon fun(): boolean
---@field HasFoodRunning fun(): number|false|nil
---@field SaveGear fun(setup: InventoryPocWardrobeSetup)|nil
---@field BUFFFOOD table<number, number>

---@class InventoryPocTscData
---@field avgPrice number|nil
---@field commonMin number|nil
---@field commonMax number|nil
---@field fromLegacy boolean|nil
---@class InventoryPocTsc
---@field GetItemData fun(self: InventoryPocTsc, link: string): InventoryPocTscData|nil
---@field LOADING unknown
---@field priceData table<number, string|unknown>|nil

---@class InventoryPocKnowledge
---@field KNOWLEDGE_KNOWN number
---@field KNOWLEDGE_UNKNOWN number
---@field GetItemKnowledgeForCharacter fun(link: string, server: nil, characterId: string): number

---@class InventoryPocBuildGear
---@field equipSlot number
---@field state number
---@field bag number
---@field slot number
---@field uniqueId string|nil
---@field link string|nil
---@class InventoryPocBuild
---@field index number
---@field name string
---@field gear InventoryPocBuildGear[]
---@class InventoryPocSetup
---@field zone string
---@field page number
---@field index number
---@field pageName string
---@field name string
---@field gear InventoryPocWardrobeGear[]
---@class InventoryPocAddon
---@field name string
---@field version number
---@class InventoryPocSnapshot
---@field timestamp number
---@field character string
---@field characterId string
---@field world string
---@field api number
---@field interaction number
---@field armory InventoryPocBuild[]
---@field wardrobe InventoryPocSetup[]
---@field items InventoryPocItem[]
---@field companionId number
---@field companionName string
---@field companionGear InventoryPocItem[]
---@field addons InventoryPocAddon[]
---@field guildIds number[]
---@field crafterId string|nil

---@class InventoryPocFacts
---@field gearSlots number[]
---@field quotes table<string, InventoryPocCachedQuote>
---@field waitingPriceLink string|nil One probe suffices: TSC publishes its table after all chunks load
local facts = {
    quotes = {},
    gearSlots = {
        EQUIP_SLOT_HEAD, EQUIP_SLOT_CHEST, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_HAND,
        EQUIP_SLOT_WAIST, EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET, EQUIP_SLOT_NECK,
        EQUIP_SLOT_RING1, EQUIP_SLOT_RING2, EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND,
        EQUIP_SLOT_BACKUP_MAIN, EQUIP_SLOT_BACKUP_OFF,
    },
}
BattleScrolls.inventoryPocFacts = facts

---@class InventoryPocVariant
---@field itemId number
---@field quality number
---@field trait number
---@field style number
---@field level number
---@field championPoints number
---@field actorCategory number
---@field armorType number
---@field weaponType number
---@field equipType number
---@field setId number|nil

---@param link string
---@return InventoryPocVariant
function facts.variant(link)
    return { itemId = GetItemLinkItemId(link), quality = GetItemLinkFunctionalQuality(link),
        trait = GetItemLinkTraitType(link), style = GetItemLinkItemStyle(link),
        level = GetItemLinkRequiredLevel(link), championPoints = GetItemLinkRequiredChampionPoints(link),
        actorCategory = GetItemLinkActorCategory(link), armorType = GetItemLinkArmorType(link),
        weaponType = GetItemLinkWeaponType(link), equipType = GetItemLinkEquipType(link),
        setId = select(6, GetItemLinkSetInfo(link, false)) }
end

local policy = BattleScrolls.inventoryPocPolicy
---@class InventoryPocCachedQuote
---@field price number
---@field expiredPrice number|nil

---@param item InventoryPocVariant
---@return string
function facts.variantKey(item)
    return table.concat({ item.itemId, item.quality, item.trait, item.style, item.level, item.championPoints }, ':')
end

---@param item InventoryPocVariant
---@param price number
---@param expiredPrice number|nil
function facts.rememberQuote(item, price, expiredPrice)
    facts.quotes[facts.variantKey(item)] = { price = price, expiredPrice = expiredPrice }
end

---@param link string
---@return number|nil
---@return boolean|nil loading
function facts.referencePrice(link)
    local companionPrices = BattleScrolls.inventoryPocCompanionPrices
    if companionPrices and GetItemLinkActorCategory(link) == GAMEPLAY_ACTOR_CATEGORY_COMPANION then
        return companionPrices.referencePrice(link)
    end
    local itemType = GetItemLinkItemType(link)
    if (itemType == ITEMTYPE_ARMOR or itemType == ITEMTYPE_WEAPON)
        and GetItemLinkActorCategory(link) ~= GAMEPLAY_ACTOR_CATEGORY_COMPANION then
        return BattleScrolls.inventoryPocGearPrices.referencePrice(link)
    end
    return facts.price(link)
end

---@param link string
---@param expired boolean|nil
---@return number|nil
---@return boolean|nil loading
function facts.marketPrice(link, expired)
    local quote = facts.quotes[facts.variantKey(facts.variant(link))]
    if quote then return expired and quote.expiredPrice or quote.price end
    local price, loading = facts.referencePrice(link)
    return price and (expired and price * 0.5 or price) or nil, loading
end
local CRAFTER_NAME = 'Isomorphism'
-- Confirmed in game; native fragment APIs do not expose pieces consumed per use.
local FRAGMENT_USE_QUANTITIES = {
    [171730] = 5, -- Mirth Shard
    [178697] = 10, -- Bonedust Pigment
}
---@type table<number, string>|nil
local traitMaterials

---@return string|nil
function facts.crafterId()
    for index = 1, GetNumCharacters() do
        local name, _, _, _, _, _, id = GetCharacterInfo(index)
        if zo_strformat(SI_UNIT_NAME, name) == CRAFTER_NAME then return id end
    end
end

local TRADING_GUILDS = { 'hermits', 'dynasty' }

---@return number[] In listing priority order
function facts.guildIds()
    local membership, result = {}, {}
    for index = 1, GetNumGuilds() do
        local id = GetGuildId(index)
        membership[zo_strlower(GetGuildName(id))] = id
    end
    for _, name in ipairs(TRADING_GUILDS) do
        if membership[name] then result[#result + 1] = membership[name] end
    end
    return result
end

---TSC 120's 18-field records store white through gold in columns 1–15.
---Its API adds one to ESO's 1–5 quality value. Read this known format with the
---native value; do not patch TSC or reinterpret a future/unknown record format.
---@param entry string
---@param quality number
---@param allowLegacy boolean
---@return boolean recognized
---@return number|nil price
local function tscEntryPrice(entry, quality, allowLegacy)
    local values = {}
    for value in (entry .. ','):gmatch('(.-),') do
        if value ~= '-' then
            local number = tonumber(value)
            if not number or number < 0 or number >= math.huge then return false, nil end
        end
        values[#values + 1] = value
    end
    if #values ~= 18 or quality < 1 or quality > 5 then return false, nil end
    local offset = (quality - 1) * 3 + 1
    -- TSC expands legacy aliases into quality columns and discards the alias
    -- flag. An identical triple has ambiguous provenance; equipment waits
    -- for another quote. Materials can use the legacy pool.
    if not allowLegacy and values[offset] == values[16] and values[offset + 1] == values[17]
        and values[offset + 2] == values[18] then return true, nil end
    local price = tonumber(values[offset])
    if policy.validPrice(price) then return true, price end
    local legacy = allowLegacy and tonumber(values[16]) or nil
    return true, policy.validPrice(legacy) and legacy or nil
end

---@param link string
---@return number|nil
---@return boolean|nil loading
function facts.price(link)
    -- TSC's audited adapter maps the PC NA world to Xbox NA. Never use that
    -- mapping for the Mac test account or a different platform's economy.
    if GetWorldName() ~= 'XB1live-eu' or link == '' then return nil end
    local api = rawget(_G, 'TSCPriceDataAPI') ---@type InventoryPocTsc|nil
    if not api then return nil end
    local itemType = GetItemLinkItemType(link)
    local equipment = GetItemLinkActorCategory(link) == GAMEPLAY_ACTOR_CATEGORY_COMPANION
        or itemType == ITEMTYPE_ARMOR or itemType == ITEMTYPE_WEAPON
    local entry = api.priceData and api.priceData[GetItemLinkItemId(link)]
    if api.LOADING ~= nil and entry == api.LOADING then
        facts.waitingPriceLink = link
        return nil, true
    end
    if type(entry) == 'string' then
        local recognized, price = tscEntryPrice(entry, GetItemLinkFunctionalQuality(link), not equipment)
        if recognized then return price end
    end
    if type(api.GetItemData) ~= 'function' then return nil end
    local data = api:GetItemData(link)
    if api.LOADING ~= nil and data == api.LOADING then
        facts.waitingPriceLink = link
        return nil, true
    end
    if type(data) ~= 'table' then return nil end
    -- Equipment needs a quote with an identified quality. The legacy pool
    -- blends qualities and can include several traits for the same name.
    if equipment and data.fromLegacy ~= false then return nil end
    return policy.validPrice(data.avgPrice) and data.avgPrice or nil
end

---TSC exposes a loading sentinel, but no completion event. While it loads,
---this reads one proxy entry without allocating tables or scanning inventory.
---@return boolean
function facts.pricesChanged()
    if not facts.waitingPriceLink then return false end
    local _, loading = facts.price(facts.waitingPriceLink)
    if loading then return false end
    facts.waitingPriceLink = nil
    return true
end

---@param trait number
---@return string, boolean
local function traitMaterial(trait)
    if trait == ITEM_TRAIT_TYPE_NONE then return '', true end
    if not traitMaterials and GetNumSmithingTraitItems() > 0 then
        traitMaterials = {}
        for index = 1, GetNumSmithingTraitItems() do
            local traitType = GetSmithingTraitItemInfo(index)
            if traitType then traitMaterials[traitType] = GetSmithingTraitItemLink(index, LINK_STYLE_DEFAULT) end
        end
    end
    if not traitMaterials then return '', false end
    return traitMaterials[trait] or '', true
end

---Run inside LibEffect.Async. Cleanup needs only IDs, not a sorted report.
---@param reservationsOnly boolean|nil
---@return InventoryPocSetup[], table<string, boolean>
function facts.wardrobe(reservationsOnly)
    local setups, reserved = {}, {}
    local ww = rawget(_G, 'WizardsWardrobe') ---@type InventoryPocWardrobe|nil
    if not ww or type(ww.setups) ~= 'table' then return setups, reserved end
    -- pairs includes page/index zero and pages omitted by WW's GUI iterator.
    local scanned = 0
    for zone, pages in pairs(ww.setups) do
        for pageId, page in pairs(pages) do
            for index, setup in pairs(page) do
                scanned = scanned + 1
                if scanned % 10 == 0 then LibEffect.Yield():Await() end
                if type(setup) == 'table' and type(setup.gear) == 'table' then
                    local entry
                    if not reservationsOnly then
                        local pageData = ww.pages and ww.pages[zone] and ww.pages[zone][pageId]
                        entry = { zone = zone, page = pageId, index = index,
                            pageName = pageData and pageData.name or tostring(pageId), name = setup.name or '', gear = {} }
                    end
                    for slot, ref in pairs(setup.gear) do
                        if type(slot) == 'number' and type(ref) == 'table' and type(ref.id) == 'string' and ref.id ~= '0' then
                            reserved[ref.id] = true
                            if entry then entry.gear[#entry.gear + 1] = { id = ref.id, link = ref.link } end
                        end
                    end
                    if entry then setups[#setups + 1] = entry end
                end
            end
            LibEffect.Yield():Await()
        end
    end
    if not reservationsOnly then table.sort(setups, function(a, b)
        if a.zone ~= b.zone then return a.zone < b.zone end
        if a.page ~= b.page then return a.page < b.page end
        return a.index < b.index
    end) end
    return setups, reserved
end

---@return InventoryPocBuild[]
function facts.armory()
    local builds = {}
    for index = 1, GetNumUnlockedArmoryBuilds() do
        local build = { index = index, name = GetArmoryBuildName(index), gear = {} }
        for _, equipSlot in ipairs(facts.gearSlots) do
            local state, bag, slot = GetArmoryBuildEquipSlotInfo(index, equipSlot)
            local gear = { equipSlot = equipSlot, state = state, bag = bag, slot = slot }
            if state == ARMORY_BUILD_EQUIP_SLOT_STATE_VALID then
                gear.link = GetItemLink(bag, slot, LINK_STYLE_DEFAULT)
                local id = GetItemUniqueId(bag, slot)
                gear.uniqueId = id and Id64ToString(id) or nil
            end
            build.gear[#build.gear + 1] = gear
        end
        builds[#builds + 1] = build
        LibEffect.Yield():Await()
    end
    return builds
end

---@param link string
---@param itemType number
---@param specializedType number
---@return InventoryPocKind
local function kind(link, itemType, specializedType)
    -- Sealed activities are containers in the API, but opening them consumes
    -- their tradeable/stackable form. Classify them before generic containers.
    if specializedType == SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP
        or GetItemLinkItemUseType(link) == ITEM_USE_TYPE_TREASURE_MAP then return 'map' end
    if specializedType == SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT then return 'survey' end
    if itemType == ITEMTYPE_MASTER_WRIT or specializedType == SPECIALIZED_ITEMTYPE_MASTER_WRIT
        or specializedType == SPECIALIZED_ITEMTYPE_HOLIDAY_WRIT then return 'writ' end
    if itemType == ITEMTYPE_CONTAINER_STACKABLE or specializedType == SPECIALIZED_ITEMTYPE_CONTAINER_STACKABLE then
        return 'sealedContainer'
    end
    if GetItemLinkActorCategory(link) == GAMEPLAY_ACTOR_CATEGORY_COMPANION then return 'companion' end
    if specializedType == SPECIALIZED_ITEMTYPE_TROPHY_RUNEBOX_FRAGMENT
        or specializedType == SPECIALIZED_ITEMTYPE_TROPHY_COLLECTIBLE_FRAGMENT then return 'fragment' end
    if GetItemLinkContainerCollectibleId(link) > 0 then return 'collectible' end
    if itemType == ITEMTYPE_ARMOR or itemType == ITEMTYPE_WEAPON then return 'gear' end
    if itemType == ITEMTYPE_GLYPH_ARMOR or itemType == ITEMTYPE_GLYPH_JEWELRY or itemType == ITEMTYPE_GLYPH_WEAPON then return 'glyph' end
    if itemType == ITEMTYPE_TREASURE then return 'treasure' end
    if itemType == ITEMTYPE_TRASH or specializedType == SPECIALIZED_ITEMTYPE_COLLECTIBLE_MONSTER_TROPHY then return 'junk' end
    if itemType == ITEMTYPE_FOOD or itemType == ITEMTYPE_DRINK then return 'food' end
    if itemType == ITEMTYPE_POTION then return 'potion' end
    if itemType == ITEMTYPE_POISON then return 'poison' end
    if itemType == ITEMTYPE_SOUL_GEM then return 'soulGem' end
    if GetItemLinkItemUseType(link) == ITEM_USE_TYPE_CRAFTED_ABILITY_SCRIPT then return 'script' end
    if itemType == ITEMTYPE_RACIAL_STYLE_MOTIF then return 'motif' end
    if itemType == ITEMTYPE_RECIPE then
        local result = GetItemLinkRecipeResultItemLink(link, LINK_STYLE_DEFAULT)
        return GetItemLinkItemType(result) == ITEMTYPE_FURNISHING and 'plan' or 'recipe'
    end
    if itemType == ITEMTYPE_CONTAINER or itemType == ITEMTYPE_CONTAINER_CURRENCY then
        return 'container'
    end
    return 'other'
end

---Read a dedicated progress line in the live ability description.
---Localized descriptions use several newline and spacing conventions.
---@param description string
---@return number|nil
---@return number|nil
local function fragmentProgress(description)
    local text = description:gsub('|[cC]%x%x%x%x%x%x', ''):gsub('|[rR]', '')
        :gsub('\r\n', '\n'):gsub('\r', '\n'):gsub('\194\160', ' '):gsub('\226\128\175', ' '):gsub('：', ':')
    local progress, required
    for line in text:gmatch('[^\n]+') do
        -- Havok's %d includes B2/B3/B9, which occur inside UTF-8 labels such as "Прогресс".
        local currentText, totalText = line:match('^[^0-9:]*:[ \t]*([0-9]+)[ \t]*/[ \t]*([0-9]+)[ \t]*%.?[ \t]*$')
        if currentText then
            if progress then return nil, nil end
            progress, required = tonumber(currentText), tonumber(totalText)
        end
    end
    if progress and required and required > 0 and progress <= required then return progress, required end
    return nil, nil
end

---@param link string
---@return boolean|nil known
---@return number|nil progress Pieces already used, distinct from pieces held in inventory
---@return number|nil required
function facts.collectibleKnowledge(link)
    local collectible = GetItemLinkContainerCollectibleId(link)
    if collectible > 0 then
        if IsCollectibleOwnedByDefId(collectible) then return true end
        if GetCollectibleCategoryType(collectible) == COLLECTIBLE_CATEGORY_TYPE_COMBINATION_FRAGMENT
            and not CanCombinationFragmentBeUnlocked(collectible) then return true end
        return false
    end
    local combination = GetItemLinkCombinationId(link)
    local rewards = combination > 0 and GetCombinationNumUnlockedCollectibles(combination) or 0
    if rewards > 0 then
        for index = 1, rewards do
            if not IsCollectibleOwnedByDefId(GetCombinationUnlockedCollectibleId(combination, index)) then return false end
        end
        return true
    end
    local _, specializedType = GetItemLinkItemType(link)
    if specializedType == SPECIALIZED_ITEMTYPE_TROPHY_COLLECTIBLE_FRAGMENT then
        local _, _, description = GetItemLinkOnUseAbilityInfo(link)
        local progress, required = fragmentProgress(description)
        if not progress then
            local abilityId = GetItemLinkOnUseAbilityId(link)
            if abilityId > 0 then progress, required = fragmentProgress(GetAbilityDescription(abilityId, nil, 'player')) end
        end
        if progress and required then return progress == required, progress, required end
    end
    return nil
end

---@param link string
---@param itemKind InventoryPocKind
---@param characterId string|nil
---@return boolean|nil
local function knowledge(link, itemKind, characterId)
    if itemKind == 'script' then return IsCraftedAbilityScriptUnlocked(GetItemLinkItemUseReferenceId(link)) end
    if itemKind ~= 'motif' and itemKind ~= 'recipe' and itemKind ~= 'plan' then return nil end
    if not characterId or characterId == GetCurrentCharacterId() then
        if itemKind == 'motif' then return IsItemLinkBookKnown(link) end
        return IsItemLinkRecipeKnown(link)
    end
    local api = rawget(_G, 'LibCharacterKnowledge') ---@type InventoryPocKnowledge|nil
    if not api or type(api.GetItemKnowledgeForCharacter) ~= 'function' then return nil end
    -- nil server selects the library's current server, avoiding its distinct
    -- display-name convention (XBEU versus the engine's XB1live-eu).
    local state = api.GetItemKnowledgeForCharacter(link, nil, characterId)
    if state == api.KNOWLEDGE_KNOWN then return true end
    if state == api.KNOWLEDGE_UNKNOWN then return false end
    return nil
end

---@param bag number
---@param slot number
---@param reserved table<string, boolean>|nil
---@return InventoryPocItem|nil
function facts.item(bag, slot, reserved)
    local link = GetItemLink(bag, slot, LINK_STYLE_DEFAULT)
    if link == '' then return nil end
    local id = GetItemUniqueId(bag, slot)
    local uniqueId = id and Id64ToString(id) or '0'
    local stack, maxStack = GetSlotStackSize(bag, slot)
    local itemType, specializedType = GetItemLinkItemType(link)
    local itemKind = kind(link, itemType, specializedType)
    local quality = GetItemLinkFunctionalQuality(link)
    local style = GetItemLinkItemStyle(link)
    local trait = GetItemLinkTraitType(link)
    local material, traitLink, traitResolved = '', '', true
    -- Glyphs and other non-equipment items can carry style IDs too. Retain the
    -- raw metadata for inspection without treating it as recoverable material.
    if itemKind == 'gear' then
        if style > 0 then material = GetItemStyleMaterialLink(style, LINK_STYLE_DEFAULT) end
        traitLink, traitResolved = traitMaterial(trait)
    end
    local crafterId = facts.crafterId()
    local known, crafterKnown, learnProgress, learnRequired
    if itemKind == 'collectible' or itemKind == 'fragment' then
        known, learnProgress, learnRequired = facts.collectibleKnowledge(link)
        crafterKnown = known
    else
        known = knowledge(link, itemKind)
        if crafterId then crafterKnown = knowledge(link, itemKind, crafterId) end
    end
    local usable = IsItemUsable(bag, slot)
    local locked = IsItemPlayerLocked(bag, slot)
    local equipped = bag == BAG_WORN or bag == BAG_COMPANION_WORN
    local armorType = GetItemLinkArmorType(link)
    local itemId = GetItemLinkItemId(link)
    local learnQuantity = 1
    if itemKind == 'fragment' then
        if FRAGMENT_USE_QUANTITIES[itemId] then learnQuantity = FRAGMENT_USE_QUANTITIES[itemId]
        elseif learnProgress or (specializedType == SPECIALIZED_ITEMTYPE_TROPHY_COLLECTIBLE_FRAGMENT
            and GetItemLinkItemUseType(link) == ITEM_USE_TYPE_COLLECTIBLE_GRANT) then learnQuantity = 1
        else learnQuantity = nil end
    end
    local companions = BattleScrolls.inventoryPocCompanions
    local crafted, hasOnUseAbility, onUseAbilityId, alchemyTraitCount
    local tradeable, hasSet, setCollected, collectionKey, improvementMaterial
    if itemKind == 'gear' or itemKind == 'companion' then tradeable = IsItemSellableOnTradingHouse(bag, slot) end
    if itemKind == 'gear' then
        crafted = IsItemLinkCrafted(link)
        local _, _, _, _, _, setId = GetItemLinkSetInfo(link, false)
        hasSet = setId > 0
        if hasSet and IsItemLinkSetCollectionPiece(link) then
            local collectionSlot = GetItemLinkItemSetCollectionSlot(link)
            setCollected = IsItemSetCollectionSlotUnlocked(setId, collectionSlot)
            if not setCollected then collectionKey = tostring(setId) .. ':' .. Id64ToString(collectionSlot) end
        end
        if tradeable and quality >= 5 then
            local craft = GetItemLinkCraftingSkillType(link)
            if craft ~= CRAFTING_TYPE_INVALID then
                improvementMaterial = GetSmithingImprovementItemLink(craft, quality - 1, LINK_STYLE_DEFAULT)
            end
        end
    end
    if itemKind == 'potion' or itemKind == 'poison' then
        crafted = IsItemLinkCrafted(link)
        hasOnUseAbility = GetItemLinkOnUseAbilityInfo(link)
        onUseAbilityId = GetItemLinkOnUseAbilityId(link)
        alchemyTraitCount = 0
        for index = 1, GetMaxTraits() do
            if GetItemLinkTraitOnUseAbilityInfo(link, index) then alchemyTraitCount = alchemyTraitCount + 1 end
        end
    end
    local marketUnit, marketLoading = facts.marketPrice(link)
    local styleMaterialUnit, styleLoading, traitMaterialUnit, traitLoading, improvementUnit, improvementLoading
    if material ~= '' then styleMaterialUnit, styleLoading = facts.price(material) end
    if traitLink ~= '' then traitMaterialUnit, traitLoading = facts.price(traitLink) end
    if improvementMaterial and improvementMaterial ~= '' then improvementUnit, improvementLoading = facts.price(improvementMaterial) end
    local item = {
        bag = bag, slot = slot, uniqueId = uniqueId, itemId = itemId, link = link,
        name = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(link)), stack = stack, maxStack = maxStack,
        searchName = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkTradingHouseItemSearchName(link)),
        kind = itemKind, quality = quality, trait = trait, style = style,
        equipType = GetItemLinkEquipType(link), armorType = armorType, weaponType = GetItemLinkWeaponType(link),
        actorCategory = GetItemLinkActorCategory(link),
        level = GetItemLinkRequiredLevel(link), championPoints = GetItemLinkRequiredChampionPoints(link),
        locked = locked,
        reserved = equipped or locked or IsItemInArmory(bag, slot) or (reserved and reserved[uniqueId]) == true,
        stolen = IsItemStolen(bag, slot), crown = IsItemLinkFromCrownStore(link) or IsItemLinkFromCrownCrate(link),
        vendorUnit = GetItemSellValueWithBonuses(bag, slot), marketUnit = marketUnit,
        prioritySell = GetItemSellInformation(bag, slot) == ITEM_SELL_INFORMATION_PRIORITY_SELL,
        styleMaterialLink = material, styleMaterialUnit = styleMaterialUnit,
        traitMaterialLink = traitLink, traitMaterialUnit = traitMaterialUnit, traitMaterialResolved = traitResolved,
        tradeable = tradeable, hasSet = hasSet, setId = select(6, GetItemLinkSetInfo(link, false)),
        setCollected = setCollected, collectionKey = collectionKey,
        improvementMaterialLink = improvementMaterial, improvementMaterialUnit = improvementUnit,
        priceLoading = marketLoading or styleLoading or traitLoading or improvementLoading or false,
        known = known, crafterKnown = crafterKnown,
        isCrafter = crafterId == GetCurrentCharacterId(),
        -- Batch fragments consume their required pieces together. Progress-based
        -- shards and direct collectible grants consume one; unknown recipes wait.
        learnQuantity = learnQuantity,
        learnProgress = learnProgress, learnRequired = learnRequired,
        usable = usable, filledSoulGem = itemKind == 'soulGem' and IsItemSoulGem(SOUL_GEM_TYPE_FILLED, bag, slot),
        crafted = crafted, hasOnUseAbility = hasOnUseAbility, onUseAbilityId = onUseAbilityId, alchemyTraitCount = alchemyTraitCount,
    }
    if itemKind == 'companion' and companions then item.companionNeeded = companions.isNeeded(item) end
    BattleScrolls.inventoryPocSealedLeads.apply(item)
    if itemKind == 'container' then item.openAfter = BattleScrolls.inventoryPocCoffers.openAfter(itemId) end
    local returns = BattleScrolls.inventoryPocReturns
    if returns and returns.isDiscounted(item) then
        item.marketUnit, marketLoading = facts.marketPrice(link, true)
        item.priceLoading = item.priceLoading or marketLoading
    end
    return item
end

---@param bag number
---@param reserved table<string, boolean>|nil
---@return InventoryPocItem[]
function facts.bag(bag, reserved)
    local items = {}
    for slot = 0, GetBagSize(bag) - 1 do
        local item = facts.item(bag, slot, reserved)
        if item then items[#items + 1] = item end
        if (slot + 1) % 5 == 0 then LibEffect.Yield():Await() end
    end
    return items
end

---@param items InventoryPocItem[] Backpack items collected by the paced diagnostic scan
---@return InventoryPocSnapshot
---@return table<string, boolean> reserved
function facts.snapshot(items)
    local wardrobe, reserved = facts.wardrobe()
    local companionId = GetActiveCompanionDefId()
    local addons = {}
    local addonManager = GetAddOnManager()
    for index = 1, addonManager:GetNumAddOns() do
        local name, _, _, _, enabled = addonManager:GetAddOnInfo(index)
        if enabled then addons[#addons + 1] = { name = name, version = addonManager:GetAddOnVersion(index) } end
    end
    return {
        timestamp = GetTimeStamp(), character = GetUnitName('player'), characterId = GetCurrentCharacterId(),
        world = GetWorldName(), api = GetAPIVersion(), interaction = GetInteractionType(),
        armory = facts.armory(), wardrobe = wardrobe, items = items,
        companionId = companionId, companionName = companionId > 0 and GetCompanionName(companionId) or '',
        companionGear = companionId > 0 and facts.bag(BAG_COMPANION_WORN, reserved) or {},
        addons = addons, guildIds = facts.guildIds(), crafterId = facts.crafterId(),
    }, reserved
end
