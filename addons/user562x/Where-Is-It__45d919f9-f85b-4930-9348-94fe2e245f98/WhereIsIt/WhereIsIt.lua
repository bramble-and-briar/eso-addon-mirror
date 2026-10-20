WhereIsIt = {}
WhereIsIt.name = "WhereIsIt"
WhereIsIt.version = "1.4"

--------------------------------------------------
-- Utility Functions
--------------------------------------------------
local function IsBankUnavailable(bagId)
    return (bagId == BAG_BANK or bagId == BAG_SUBSCRIBER_BANK) and not IsBankOpen()
end

--------------------------------------------------
-- Categories
--------------------------------------------------
local CATEGORY_CURRENCY_ORDER = 1
local CATEGORY_FALLBACK_ORDER = 10

local CATEGORY_ORDER          = {}
local CATEGORY_LABEL_TYPE     = {}
local CATEGORY_LABEL_BY_ORDER = {}

local function RegisterCategory(filterType, order, labelFilterType)
    if filterType == nil then return end
    CATEGORY_ORDER[filterType]      = order
    CATEGORY_LABEL_TYPE[filterType] = labelFilterType or filterType
end

RegisterCategory(ITEMFILTERTYPE_WEAPONS,       2)
RegisterCategory(ITEMFILTERTYPE_ARMOR,         3)
RegisterCategory(ITEMFILTERTYPE_JEWELRY,       3, ITEMFILTERTYPE_ARMOR)
RegisterCategory(ITEMFILTERTYPE_CONSUMABLE,    4)
RegisterCategory(ITEMFILTERTYPE_CRAFTING,      5)
RegisterCategory(ITEMFILTERTYPE_FURNISHING,    6)
RegisterCategory(ITEMFILTERTYPE_COMPANION,     7)
RegisterCategory(ITEMFILTERTYPE_QUEST,         8)
RegisterCategory(ITEMFILTERTYPE_JUNK,          9)
RegisterCategory(ITEMFILTERTYPE_MISCELLANEOUS, CATEGORY_FALLBACK_ORDER)

local function BuildCategoryLabels()
    for filterType, order in pairs(CATEGORY_ORDER) do
        if not CATEGORY_LABEL_BY_ORDER[order] then
            local labelType = CATEGORY_LABEL_TYPE[filterType]
            local label = labelType and GetString("SI_ITEMFILTERTYPE", labelType)
            if label and label ~= "" then CATEGORY_LABEL_BY_ORDER[order] = label end
        end
    end
    CATEGORY_LABEL_BY_ORDER[CATEGORY_FALLBACK_ORDER] = CATEGORY_LABEL_BY_ORDER[CATEGORY_FALLBACK_ORDER] or "Miscellaneous"
    CATEGORY_LABEL_BY_ORDER[CATEGORY_CURRENCY_ORDER] = "Currency"
end
BuildCategoryLabels()

local function CategoryLabelForOrder(order)
    return CATEGORY_LABEL_BY_ORDER[order or CATEGORY_FALLBACK_ORDER] or "Miscellaneous"
end

WhereIsIt.CategoryLabelForOrder = CategoryLabelForOrder

local function PickCategoryOrder(...)
    local numFilters = select("#", ...)
    for i = 1, numFilters do
        local filterType = select(i, ...)
        local order = CATEGORY_ORDER[filterType]
        if order then return order end
    end
    return CATEGORY_FALLBACK_ORDER
end

local function ResolveCategoryOrder(itemLink)
    if not itemLink or itemLink == "" or not GetItemLinkFilterTypeInfo then
        return CATEGORY_FALLBACK_ORDER
    end
    return PickCategoryOrder(GetItemLinkFilterTypeInfo(itemLink))
end

--------------------------------------------------
-- In-Game Groups
--------------------------------------------------
local GROUP_PACK        = 1
local GROUP_WEAPONS     = 2
local GROUP_APPAREL     = 3
local GROUP_ACCESSORIES = 4

local PACK_SUPPLIES     = 1
local PACK_MATERIALS    = 2
local PACK_SLOTTABLE    = 3
local PACK_FURNISHINGS  = 4
local PACK_COMPANION    = 5

WhereIsIt.GROUP_PACK        = GROUP_PACK
WhereIsIt.GROUP_WEAPONS     = GROUP_WEAPONS
WhereIsIt.GROUP_APPAREL     = GROUP_APPAREL
WhereIsIt.GROUP_ACCESSORIES = GROUP_ACCESSORIES

WhereIsIt.PACK_SUPPLIES     = PACK_SUPPLIES
WhereIsIt.PACK_MATERIALS    = PACK_MATERIALS
WhereIsIt.PACK_SLOTTABLE    = PACK_SLOTTABLE
WhereIsIt.PACK_FURNISHINGS  = PACK_FURNISHINGS
WhereIsIt.PACK_COMPANION    = PACK_COMPANION

WhereIsIt.COMPANION_WORN_LOCATION = "Companion Worn"

local EQUIP_TYPE_GROUP = {}

local function RegisterEquipGroup(equipType, group)
    if equipType == nil then return end
    EQUIP_TYPE_GROUP[equipType] = group
end

RegisterEquipGroup(EQUIP_TYPE_MAIN_HAND, GROUP_WEAPONS)
RegisterEquipGroup(EQUIP_TYPE_OFF_HAND,  GROUP_WEAPONS)
RegisterEquipGroup(EQUIP_TYPE_ONE_HAND,  GROUP_WEAPONS)
RegisterEquipGroup(EQUIP_TYPE_TWO_HAND,  GROUP_WEAPONS)

RegisterEquipGroup(EQUIP_TYPE_HEAD,      GROUP_APPAREL)
RegisterEquipGroup(EQUIP_TYPE_CHEST,     GROUP_APPAREL)
RegisterEquipGroup(EQUIP_TYPE_SHOULDERS, GROUP_APPAREL)
RegisterEquipGroup(EQUIP_TYPE_WAIST,     GROUP_APPAREL)
RegisterEquipGroup(EQUIP_TYPE_HAND,      GROUP_APPAREL)
RegisterEquipGroup(EQUIP_TYPE_LEGS,      GROUP_APPAREL)
RegisterEquipGroup(EQUIP_TYPE_FEET,      GROUP_APPAREL)

RegisterEquipGroup(EQUIP_TYPE_COSTUME,   GROUP_ACCESSORIES)
RegisterEquipGroup(EQUIP_TYPE_NECK,      GROUP_ACCESSORIES)
RegisterEquipGroup(EQUIP_TYPE_RING,      GROUP_ACCESSORIES)


local function CollectFilterTypes(set, ...)
    for i = 1, select("#", ...) do
        local filterType = select(i, ...)
        if filterType ~= nil then set[filterType] = true end
    end
    return set
end

local function ItemFilterSet(itemLink)
    if not itemLink or itemLink == "" or not GetItemLinkFilterTypeInfo then
        return {}
    end

    local ok, set = pcall(function()
        return CollectFilterTypes({}, GetItemLinkFilterTypeInfo(itemLink))
    end)

    if not ok or type(set) ~= "table" then return {} end
    return set
end

local function ClassifyItem(itemLink, location)
    if not itemLink or itemLink == "" then
        return GROUP_PACK, PACK_SUPPLIES
    end

    local filters = ItemFilterSet(itemLink)

    if location ~= WhereIsIt.COMPANION_WORN_LOCATION
       and ITEMFILTERTYPE_COMPANION and filters[ITEMFILTERTYPE_COMPANION] then
        return GROUP_PACK, PACK_COMPANION
    end

    local equipType = GetItemLinkEquipType and GetItemLinkEquipType(itemLink)
    local group     = equipType and EQUIP_TYPE_GROUP[equipType]
    if group then return group, nil end

    if ITEMFILTERTYPE_CRAFTING and filters[ITEMFILTERTYPE_CRAFTING] then
        return GROUP_PACK, PACK_MATERIALS
    end

    if ITEMFILTERTYPE_QUICKSLOT and filters[ITEMFILTERTYPE_QUICKSLOT] then
        return GROUP_PACK, PACK_SLOTTABLE
    end

    if ITEMFILTERTYPE_FURNISHING and filters[ITEMFILTERTYPE_FURNISHING] then
        return GROUP_PACK, PACK_FURNISHINGS
    end

    return GROUP_PACK, PACK_SUPPLIES
end

WhereIsIt.ClassifyItem = ClassifyItem

--------------------------------------------------
-- Item Category Names
--------------------------------------------------
local function FurnitureCategoryName(itemLink)
    if not (GetItemLinkFurnitureDataId and GetFurnitureDataCategoryInfo and GetFurnitureCategoryInfo) then
        return nil
    end

    local ok, name = pcall(function()
        local dataId = GetItemLinkFurnitureDataId(itemLink)
        if not dataId or dataId == 0 then return nil end

        local categoryId = GetFurnitureDataCategoryInfo(dataId)
        if not categoryId then return nil end

        local categoryName = GetFurnitureCategoryInfo(categoryId)
        if categoryName and categoryName ~= "" then return categoryName end
        return nil
    end)

    if ok then return name end
    return nil
end

local function FormatCategoryHeader(name)
    if not name or name == "" then return nil end

    if zo_strformat and SI_INVENTORY_HEADER then
        local ok, formatted = pcall(zo_strformat, SI_INVENTORY_HEADER, name)
        if ok and type(formatted) == "string" and formatted ~= "" then
            return formatted
        end
    end

    return name
end

local function ItemCategoryName(itemLink)
    if not itemLink or itemLink == "" then return nil end

    local itemType = GetItemLinkItemType and GetItemLinkItemType(itemLink)

    if ITEMTYPE_FURNISHING and itemType == ITEMTYPE_FURNISHING then
        local furnitureName = FurnitureCategoryName(itemLink)
        if furnitureName then return FormatCategoryHeader(furnitureName) end
    end

    local Describe = rawget(_G, "ZO_InventoryUtils_Gamepad_GetBestItemCategoryDescription")
    if type(Describe) == "function" then
        local itemData = {
            itemLink      = itemLink,
            itemType      = itemType,
            equipType     = GetItemLinkEquipType and GetItemLinkEquipType(itemLink),
            actorCategory = GetItemLinkActorCategory and GetItemLinkActorCategory(itemLink),
        }

        local ok, name = pcall(Describe, itemData)
        if ok and type(name) == "string" and name ~= "" then
            return FormatCategoryHeader(name)
        end
    end

    if itemType ~= nil then
        local ok, name = pcall(GetString, "SI_ITEMTYPE", itemType)
        if ok and type(name) == "string" and name ~= "" then
            return FormatCategoryHeader(name)
        end
    end

    return nil
end

WhereIsIt.ItemCategoryName = ItemCategoryName

function WhereIsIt.EnsureClassified(item)
    if type(item) ~= "table" then return GROUP_PACK, PACK_SUPPLIES end

    if item.group == nil then
        item.group, item.packSub = ClassifyItem(item.itemLink, item.location)
    end

    if item.catName == nil then
        item.catName = ItemCategoryName(item.itemLink) or false
    end

    return item.group, item.packSub
end

--------------------------------------------------
-- Classification Migration
--------------------------------------------------
local CLASSIFY_VERSION = 2

local function ForEachItemTable(sv, callback)
    if not sv then return end

    for _, character in pairs(sv.characters or {}) do
        callback(character.items)
    end

    local account = sv.account or {}
    callback(account.craftBag)
    callback(account.bank)
    callback(account.furnitureVault)

    for _, guild in pairs(account.guildBanks or {}) do
        callback(guild.items)
    end

    for _, companion in pairs(account.companions or {}) do
        callback(companion.items)
    end

    for _, chest in pairs(account.houseChests or {}) do
        callback(chest.items)
    end
end

function WhereIsIt:MigrateClassification()
    local sv = self.savedVariables
    if not sv then return end
    if sv.classifyVersion == CLASSIFY_VERSION then return end

    ForEachItemTable(sv, function(items)
        if type(items) ~= "table" then return end
        for _, item in pairs(items) do
            if type(item) == "table" then
                item.group   = nil
                item.packSub = nil
            end
        end
    end)

    sv.classifyVersion = CLASSIFY_VERSION
end

function WhereIsIt.CategoryNameFor(item)
    if type(item) ~= "table" then return nil end

    WhereIsIt.EnsureClassified(item)

    local name = item.catName
    if name == false or name == "" then return nil end
    return name
end

--------------------------------------------------
-- Tracked Sources
--------------------------------------------------
WhereIsIt.TRACK_KEYS = {
    "currencies", "characters", "companions",
    "craftBag", "bank", "guildBanks", "storage",
}

function WhereIsIt:IsTracked(key)
    local sv = self.savedVariables
    if not (sv and sv.tracked) then return true end
    return sv.tracked[key] ~= false
end

function WhereIsIt:ClearTracked(key)
    local sv = self.savedVariables
    if not sv then return end

    sv.account = sv.account or {}

    if key == "currencies" then
        for _, character in pairs(sv.characters or {}) do
            character.currencies = nil
        end
    elseif key == "characters" then
        for _, character in pairs(sv.characters or {}) do
            character.items = {}
        end
    elseif key == "companions" then
        sv.account.companions = {}
    elseif key == "craftBag" then
        sv.account.craftBag = {}
    elseif key == "bank" then
        sv.account.bank = {}
    elseif key == "guildBanks" then
        sv.account.guildBanks = {}
    elseif key == "storage" then
        sv.account.houseChests   = {}
        sv.account.furnitureVault = {}
    end
end

function WhereIsIt:RescanTracked(key)
    if not self:IsTracked(key) then return end

    local function Try(fn)
        if type(fn) == "function" then pcall(fn, self) end
    end

    if key == "currencies" or key == "characters" then
        Try(self.ScanCharacter)
    elseif key == "companions" then
        Try(self.ScanCompanion)
    elseif key == "craftBag" then
        Try(self.ScanCraftBag)
    elseif key == "bank" then
        Try(self.ScanBank)
    elseif key == "guildBanks" then
        Try(self.ScanGuildBank)
    elseif key == "storage" then
        Try(self.ScanHouseChests)
        Try(self.ScanFurnitureVault)
    end
end

--------------------------------------------------
-- Bag Scanner
--------------------------------------------------
local function ItemIdentity(itemLink, quality, trait)
    if not itemLink or itemLink == "" or not GetItemLinkItemId then return nil end

    local itemId = GetItemLinkItemId(itemLink)
    if not itemId or itemId == 0 then return nil end

    local requiredLevel = GetItemLinkRequiredLevel and GetItemLinkRequiredLevel(itemLink) or 0
    local requiredCP    = GetItemLinkRequiredChampionPoints and GetItemLinkRequiredChampionPoints(itemLink) or 0
    local stolen        = (IsItemLinkStolen and IsItemLinkStolen(itemLink)) and 1 or 0

    return itemId .. ":" .. (quality or 0) .. ":" .. requiredLevel
        .. ":" .. requiredCP .. ":" .. (trait or 0) .. ":" .. stolen
end

local function ScanSlotIntoTable(bagId, slotIndex, tbl, location, index)
    local rawName = GetItemName(bagId, slotIndex)
    if not rawName or rawName == "" then return end

    local count = select(2, GetItemInfo(bagId, slotIndex)) or 0
    if count <= 0 then return end

    local itemName = ZO_CachedStrFormat(SI_TOOLTIP_ITEM_NAME, rawName)
    local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_BRACKETS)
    local hasLink  = itemLink and itemLink ~= ""
    local trait    = hasLink and GetItemLinkTraitInfo(itemLink) or 0
    local quality  = hasLink and GetItemLinkDisplayQuality(itemLink) or nil

    local identity = hasLink and ItemIdentity(itemLink, quality, trait)
    local key
    if identity then
        key = identity .. "|" .. location
    else
        key = zo_strlower(rawName) .. "|" .. location .. "|" .. tostring(trait)
    end

    if tbl[key] then
        tbl[key].count = tbl[key].count + count
        tbl[key].slots = (tbl[key].slots or 1) + 1
    else
        local group, packSub = ClassifyItem(itemLink, location)
        tbl[key] = {
            displayName = itemName,
            count       = count,
            location    = location,
            itemLink    = itemLink,
            quality     = quality,
            slots       = 1,
            catOrder    = ResolveCategoryOrder(itemLink),
            group       = group,
            packSub     = packSub,
            catName     = ItemCategoryName(itemLink) or false,
        }
    end

    if index then
        index[slotIndex] = { key = key, count = count }
    end
end

local function ScanBagIntoTable(bagId, tbl, location, index)
    if not ZO_IterateBagSlots then return end

    local ok, iterator, state, initialIndex = pcall(ZO_IterateBagSlots, bagId)
    if not ok or type(iterator) ~= "function" then return end

    local slotIndex = initialIndex
    while true do
        local nextIndex = iterator(state, slotIndex)
        if nextIndex == nil then break end
        slotIndex = nextIndex
        ScanSlotIntoTable(bagId, slotIndex, tbl, location, index)
    end
end

local SLOT_LOCATION = {}
local function InitSlotLocations()
    SLOT_LOCATION[BAG_BACKPACK]       = "Inventory"
    SLOT_LOCATION[BAG_WORN]           = "Worn"
    SLOT_LOCATION[BAG_COMPANION_WORN] = "Companion Worn"
    SLOT_LOCATION[BAG_VIRTUAL]        = "Craft Bag"
    SLOT_LOCATION[BAG_BANK]           = "Bank"
    SLOT_LOCATION[BAG_SUBSCRIBER_BANK] = "Bank"
end
InitSlotLocations()

--------------------------------------------------
-- Active Companion
--------------------------------------------------
local function ActiveCompanionInfo()
    if not (HasActiveCompanion and HasActiveCompanion()) then return nil end
    if not GetActiveCompanionDefId then return nil end

    local defId = GetActiveCompanionDefId()
    if not defId or defId == 0 then return nil end

    local name = GetCompanionName and GetCompanionName(defId) or ""
    if ZO_CachedStrFormat and name ~= "" then
        name = ZO_CachedStrFormat(SI_UNIT_NAME, name)
    end
    if not name or name == "" then name = "Companion " .. tostring(defId) end

    return tostring(defId), name
end

function WhereIsIt:ScanCharacter()
    local charId   = tostring(GetCurrentCharacterId())
    local charName = GetUnitName("player")
    local sv       = self.savedVariables

    sv.characters[charId] = sv.characters[charId] or {}
    local slot = sv.characters[charId]
    slot.name  = charName
    slot.items = {}

    self.slotIndex = {}
    self.slotIndex[BAG_BACKPACK] = {}
    self.slotIndex[BAG_WORN]     = {}

    if self:IsTracked("characters") then
        ScanBagIntoTable(BAG_BACKPACK, slot.items, "Inventory", self.slotIndex[BAG_BACKPACK])
        ScanBagIntoTable(BAG_WORN,     slot.items, "Worn",      self.slotIndex[BAG_WORN])
    end

    slot.alliance = GetUnitAlliance and GetUnitAlliance("player") or nil

    slot.companion = nil
    self:ScanCompanion()

    if not self:IsTracked("currencies") then
        slot.currencies = nil
        return
    end

    slot.currencies = {
        gold           = GetCurrencyAmount(CURT_MONEY,           CURRENCY_LOCATION_CHARACTER),
        alliancePoints = GetCurrencyAmount(CURT_ALLIANCE_POINTS, CURRENCY_LOCATION_CHARACTER),
        telVar         = GetCurrencyAmount(CURT_TELVAR_STONES,   CURRENCY_LOCATION_CHARACTER),
        writVouchers   = GetCurrencyAmount(CURT_WRIT_VOUCHERS,   CURRENCY_LOCATION_CHARACTER),
    }
end

function WhereIsIt:ScanCraftBag()
    if not self:IsTracked("craftBag") then return end
    local sv   = self.savedVariables
    sv.account = sv.account or {}
    sv.account.craftBag = {}

    self.slotIndex = self.slotIndex or {}
    self.slotIndex[BAG_VIRTUAL] = {}

    ScanBagIntoTable(BAG_VIRTUAL, sv.account.craftBag, "Craft Bag", self.slotIndex[BAG_VIRTUAL])
end

function WhereIsIt:ScanBank()
    if not self:IsTracked("bank") then return end
    local sv   = self.savedVariables
    sv.account = sv.account or {}
    local acct = sv.account
    acct.bank = acct.bank or {}

    if IsBankUnavailable(BAG_BANK) then return end

    self.slotIndex = self.slotIndex or {}
    local bankIndex       = {}
    local subscriberIndex = {}

    local scanned = {}
    ScanBagIntoTable(BAG_BANK,            scanned, "Bank", bankIndex)
    ScanBagIntoTable(BAG_SUBSCRIBER_BANK, scanned, "Bank", subscriberIndex)

    if next(scanned) == nil and next(acct.bank) ~= nil then return end

    acct.bank = scanned
    self.slotIndex[BAG_BANK]            = bankIndex
    self.slotIndex[BAG_SUBSCRIBER_BANK] = subscriberIndex
end

local TRACK_KEY_FOR_BAG = {}
local function InitTrackKeys()
    TRACK_KEY_FOR_BAG[BAG_BACKPACK]        = "characters"
    TRACK_KEY_FOR_BAG[BAG_WORN]            = "characters"
    TRACK_KEY_FOR_BAG[BAG_COMPANION_WORN]  = "companions"
    TRACK_KEY_FOR_BAG[BAG_VIRTUAL]         = "craftBag"
    TRACK_KEY_FOR_BAG[BAG_BANK]            = "bank"
    TRACK_KEY_FOR_BAG[BAG_SUBSCRIBER_BANK] = "bank"
end
InitTrackKeys()

function WhereIsIt:UpdateInventorySlot(bagId, slotIndex)
    local location = SLOT_LOCATION[bagId]
    if not location or slotIndex == nil then return false end

    local trackKey = TRACK_KEY_FOR_BAG[bagId]
    if trackKey and not self:IsTracked(trackKey) then
        if self.slotIndex then self.slotIndex[bagId] = nil end
        return true
    end

    if bagId == BAG_COMPANION_WORN then
        if not (HasActiveCompanion and HasActiveCompanion()) then return false end
        self:ScanCompanion()
        return true
    end

    local sv = self.savedVariables
    if not sv then return false end

    local index = self.slotIndex and self.slotIndex[bagId]
    if not index then return false end

    local target
    if bagId == BAG_VIRTUAL then
        target = sv.account and sv.account.craftBag
    elseif bagId == BAG_BANK or bagId == BAG_SUBSCRIBER_BANK then
        target = sv.account and sv.account.bank
    else
        local charId = tostring(GetCurrentCharacterId())
        local slot   = sv.characters and sv.characters[charId]
        if not slot then return false end
        target = slot.items
    end
    if not target then return false end

    local previous = index[slotIndex]
    if previous then
        local record = target[previous.key]
        if record then
            record.count = record.count - previous.count
            record.slots = (record.slots or 1) - 1
            if record.count <= 0 or record.slots <= 0 then
                target[previous.key] = nil
            end
        end
        index[slotIndex] = nil
    end

    ScanSlotIntoTable(bagId, slotIndex, target, location, index)
    return true
end

function WhereIsIt:RefreshCharacterCurrencies()
    local sv     = self.savedVariables
    local charId = tostring(GetCurrentCharacterId())
    local slot   = sv and sv.characters and sv.characters[charId]
    if not slot or not slot.currencies then return end

    slot.currencies.gold           = GetCurrencyAmount(CURT_MONEY,           CURRENCY_LOCATION_CHARACTER)
    slot.currencies.alliancePoints = GetCurrencyAmount(CURT_ALLIANCE_POINTS, CURRENCY_LOCATION_CHARACTER)
    slot.currencies.telVar         = GetCurrencyAmount(CURT_TELVAR_STONES,   CURRENCY_LOCATION_CHARACTER)
    slot.currencies.writVouchers   = GetCurrencyAmount(CURT_WRIT_VOUCHERS,   CURRENCY_LOCATION_CHARACTER)
end

local function CurrentHouseName()
    if not (GetCurrentZoneHouseId and GetCollectibleIdForHouse) then return nil, nil end

    local houseId = GetCurrentZoneHouseId()
    if not houseId or houseId == 0 then return nil, nil end

    local name = GetCollectibleName and GetCollectibleName(GetCollectibleIdForHouse(houseId)) or ""
    if ZO_CachedStrFormat and name ~= "" then
        name = ZO_CachedStrFormat(SI_COLLECTIBLE_NAME_FORMATTER, name)
    end
    if not name or name == "" then name = "House " .. tostring(houseId) end

    return tostring(houseId), name
end

function WhereIsIt:ScanHouseChests()
    if not self:IsTracked("storage") then return end
    if not (IsOwnerOfCurrentHouse and IsOwnerOfCurrentHouse()) then return end

    local sv   = self.savedVariables
    sv.account = sv.account or {}
    sv.account.houseChests = sv.account.houseChests or {}

    local houseId, houseName = CurrentHouseName()
    if not houseId then return end

    local chests = sv.account.houseChests

    for bagId = BAG_HOUSE_BANK_ONE, BAG_HOUSE_BANK_TEN do
        local key = tostring(bagId)
        local collectibleId = GetCollectibleForBag(bagId)

        if not (collectibleId and collectibleId > 0 and IsCollectibleUnlocked(collectibleId)) then
            chests[key] = nil
        else
            local chestName = GetCollectibleNickname(collectibleId)
            if not chestName or chestName == "" then chestName = GetCollectibleName(collectibleId) end
            if not chestName or chestName == "" then chestName = "House Chest" end

            local items = {}
            ScanBagIntoTable(bagId, items, chestName)

            local existing = chests[key]
            if next(items) ~= nil then
                chests[key] = {
                    name    = chestName,
                    house   = houseName,
                    houseId = houseId,
                    items   = items,
                }
            elseif existing and existing.houseId == houseId then
                existing.name  = chestName
                existing.house = houseName
                existing.items = items
            elseif not existing then
                chests[key] = nil
            end
        end
    end
end

local function IsHouseBankBag(bagId)
    if not (BAG_HOUSE_BANK_ONE and BAG_HOUSE_BANK_TEN) then return false end
    return bagId ~= nil and bagId >= BAG_HOUSE_BANK_ONE and bagId <= BAG_HOUSE_BANK_TEN
end

WhereIsIt.IsHouseBankBag = IsHouseBankBag

function WhereIsIt:ScanHouseChest(bagId)
    if not self:IsTracked("storage") then return false end
    if not IsHouseBankBag(bagId) then return false end

    local sv = self.savedVariables
    if not sv then return false end
    sv.account = sv.account or {}
    sv.account.houseChests = sv.account.houseChests or {}

    local houseId, houseName = CurrentHouseName()
    if not houseId then return false end

    local key           = tostring(bagId)
    local collectibleId = GetCollectibleForBag(bagId)

    if not (collectibleId and collectibleId > 0 and IsCollectibleUnlocked(collectibleId)) then
        sv.account.houseChests[key] = nil
        return true
    end

    local chestName = GetCollectibleNickname(collectibleId)
    if not chestName or chestName == "" then chestName = GetCollectibleName(collectibleId) end
    if not chestName or chestName == "" then chestName = "House Chest" end

    local items = {}
    ScanBagIntoTable(bagId, items, chestName)

    sv.account.houseChests[key] = {
        name    = chestName,
        house   = houseName,
        houseId = houseId,
        items   = items,
    }

    return true
end

function WhereIsIt:ScanFurnitureVault(force)
    if not self:IsTracked("storage") then return end
    if not (IsOwnerOfCurrentHouse and IsOwnerOfCurrentHouse()) then return end
    local sv   = self.savedVariables
    sv.account = sv.account or {}
    sv.account.furnitureVault = sv.account.furnitureVault or {}

    local scanned = {}
    ScanBagIntoTable(BAG_FURNITURE_VAULT, scanned, "Furniture Vault")

    if not force and next(scanned) == nil and next(sv.account.furnitureVault) ~= nil then
        return
    end

    sv.account.furnitureVault = scanned
end

function WhereIsIt:ScanGuildBank()
    if not self:IsTracked("guildBanks") then return end
    local sv   = self.savedVariables
    sv.account = sv.account or {}
    sv.account.guildBanks = sv.account.guildBanks or {}

    local guildId = self.selectedGuildBankId
    if (not guildId or guildId == 0) and GetSelectedGuildBankId then
        guildId = GetSelectedGuildBankId()
    end
    if not guildId or guildId == 0 then return end

    if IsGuildBankOpen and not IsGuildBankOpen() then return end

    local guildName = GetGuildName(guildId)
    if not guildName or guildName == "" then guildName = "Guild Bank" end

    local key  = tostring(guildId)
    local slot = { name = guildName, items = {} }
    ScanBagIntoTable(BAG_GUILDBANK, slot.items, guildName)

    if next(slot.items) == nil then
        local existing = sv.account.guildBanks[key]
        if existing and existing.items and next(existing.items) ~= nil then
            existing.name = guildName
            return
        end
    end

    sv.account.guildBanks[key] = slot
end

function WhereIsIt:ScanCompanion()
    if not self:IsTracked("companions") then return end
    local sv   = self.savedVariables
    sv.account = sv.account or {}
    sv.account.companions = sv.account.companions or {}

    self.slotIndex = self.slotIndex or {}
    self.slotIndex[BAG_COMPANION_WORN] = {}

    local key, name = ActiveCompanionInfo()
    if not key then return end

    local slot = { name = name, items = {} }
    ScanBagIntoTable(BAG_COMPANION_WORN, slot.items, "Companion Worn", self.slotIndex[BAG_COMPANION_WORN])

    if next(slot.items) == nil then
        local existing = sv.account.companions[key]
        if existing and existing.items and next(existing.items) ~= nil then
            existing.name = name
            return
        end
    end

    sv.account.companions[key] = slot
end

--------------------------------------------------
-- Stale Data Pruning
--------------------------------------------------
local function BuildAccountCharacterIdSet()
    if not (GetNumCharacters and GetCharacterInfo and GetCurrentCharacterId) then return nil end

    local numCharacters = GetNumCharacters()
    if not numCharacters or numCharacters == 0 then return nil end

    local currentId = tostring(GetCurrentCharacterId() or "")
    if currentId == "" then return nil end

    local numReturns = select("#", GetCharacterInfo(1))
    local idPosition
    for i = 1, numCharacters do
        local values = { GetCharacterInfo(i) }
        for position = 1, numReturns do
            if type(values[position]) == "string" and values[position] == currentId then
                idPosition = position
                break
            end
        end
        if idPosition then break end
    end
    if not idPosition then return nil end

    local ids = {}
    for i = 1, numCharacters do
        local id = select(idPosition, GetCharacterInfo(i))
        if id ~= nil then ids[tostring(id)] = true end
    end

    if not ids[currentId] then return nil end
    return ids
end

function WhereIsIt:PruneDeletedCharacters()
    local sv = self.savedVariables
    if not sv or not sv.characters then return end

    local validIds = BuildAccountCharacterIdSet()
    if not validIds then return end

    for charId in pairs(sv.characters) do
        if not validIds[charId] then
            sv.characters[charId] = nil
        end
    end
end

function WhereIsIt:PruneLeftGuilds()
    local sv = self.savedVariables
    if not sv or not sv.account or not sv.account.guildBanks then return end
    if not (GetNumGuilds and GetGuildId) then return end

    local validIds = {}
    for i = 1, GetNumGuilds() do
        local guildId = GetGuildId(i)
        if guildId and guildId ~= 0 then
            validIds[tostring(guildId)] = true
        end
    end

    if next(validIds) == nil then return end

    local storedCount, matchCount = 0, 0
    for guildId in pairs(sv.account.guildBanks) do
        storedCount = storedCount + 1
        if validIds[guildId] then matchCount = matchCount + 1 end
    end
    if storedCount > 0 and matchCount == 0 then return end

    for guildId in pairs(sv.account.guildBanks) do
        if not validIds[guildId] then
            sv.account.guildBanks[guildId] = nil
        end
    end
end

--------------------------------------------------
-- Addon Loaded
--------------------------------------------------
local function OnAddonLoaded(event, addonName)
    if addonName ~= WhereIsIt.name then return end

    WhereIsIt.savedVariables = ZO_SavedVars:NewAccountWide(
        "WhereIsIt_SavedVars", 4, nil,
        { characters = {}, account = { bank = {}, craftBag = {}, guildBanks = {}, companions = {}, houseChests = {}, furnitureVault = {} }, tracked = {} }
    )

    WhereIsIt.savedVariables.account = WhereIsIt.savedVariables.account or {}
    WhereIsIt.savedVariables.account.guildBanks = WhereIsIt.savedVariables.account.guildBanks or {}
    WhereIsIt.savedVariables.account.companions = WhereIsIt.savedVariables.account.companions or {}
    WhereIsIt.savedVariables.account.houseChests = WhereIsIt.savedVariables.account.houseChests or {}
    WhereIsIt.savedVariables.account.house = nil
    WhereIsIt.savedVariables.account.guildBank  = nil

    WhereIsIt.savedVariables.lastSeenVersion = nil
    WhereIsIt.savedVariables.tooltipMode     = nil
    WhereIsIt.savedVariables.tracked = WhereIsIt.savedVariables.tracked or {}
    for _, key in ipairs(WhereIsIt.TRACK_KEYS) do
        if WhereIsIt.savedVariables.tracked[key] == nil then
            WhereIsIt.savedVariables.tracked[key] = true
        end
    end

    for _, character in pairs(WhereIsIt.savedVariables.characters or {}) do
        character.companion = nil
    end

    WhereIsIt:MigrateClassification()

    EVENT_MANAGER:RegisterForEvent(
        WhereIsIt.name .. "_Activate",
        EVENT_PLAYER_ACTIVATED,
        function()
            WhereIsIt:ScanCharacter()
            WhereIsIt:ScanCraftBag()
            WhereIsIt:PruneDeletedCharacters()
        end
    )

    EVENT_MANAGER:RegisterForEvent(
        WhereIsIt.name .. "_HouseEnter",
        EVENT_PLAYER_ACTIVATED,
        function()
            if IsOwnerOfCurrentHouse and IsOwnerOfCurrentHouse() then
                WhereIsIt:ScanHouseChests()
                WhereIsIt:ScanFurnitureVault()
            end
        end
    )

    local currencyPending = false
    EVENT_MANAGER:RegisterForEvent(
        WhereIsIt.name .. "_InvUpdate",
        EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        function(eventCode, bagId, slotIndex)
            if IsHouseBankBag(bagId) then
                WhereIsIt:ScanHouseChest(bagId)
                return
            end

            if BAG_FURNITURE_VAULT and bagId == BAG_FURNITURE_VAULT then
                if WhereIsIt:IsTracked("storage") then
                    local FORCE = true
                    WhereIsIt:ScanFurnitureVault(FORCE)
                end
                return
            end

            if not WhereIsIt:UpdateInventorySlot(bagId, slotIndex) then
                if bagId == BAG_BACKPACK or bagId == BAG_WORN then
                    WhereIsIt:ScanCharacter()
                elseif bagId == BAG_VIRTUAL then
                    WhereIsIt:ScanCraftBag()
                elseif bagId == BAG_BANK or bagId == BAG_SUBSCRIBER_BANK then
                    WhereIsIt:ScanBank()
                end
                return
            end

            if not currencyPending then
                currencyPending = true
                zo_callLater(function()
                    currencyPending = false
                    WhereIsIt:RefreshCharacterCurrencies()
                end, 3000)
            end
        end
    )

    EVENT_MANAGER:RegisterForEvent(
        WhereIsIt.name .. "_Currency",
        EVENT_CURRENCY_UPDATE,
        function()
            if currencyPending then return end
            currencyPending = true
            zo_callLater(function()
                currencyPending = false
                WhereIsIt:RefreshCharacterCurrencies()
            end, 1000)
        end
    )

    EVENT_MANAGER:RegisterForEvent(
        WhereIsIt.name .. "_Bank",
        EVENT_OPEN_BANK,
        function() WhereIsIt:ScanBank() end
    )

    EVENT_MANAGER:RegisterForEvent(
        WhereIsIt.name .. "_BankClosed",
        EVENT_CLOSE_BANK,
        function()
            if WhereIsIt.slotIndex then
                WhereIsIt.slotIndex[BAG_BANK]            = nil
                WhereIsIt.slotIndex[BAG_SUBSCRIBER_BANK] = nil
            end
        end
    )

    EVENT_MANAGER:RegisterForEvent(
        WhereIsIt.name .. "_House",
        EVENT_HOUSING_EDITOR_MODE_CHANGED,
        function()
            WhereIsIt:ScanHouseChests()
            WhereIsIt:ScanFurnitureVault()
        end
    )

    EVENT_MANAGER:RegisterForEvent(
        WhereIsIt.name .. "_GuildBankSelected",
        EVENT_GUILD_BANK_SELECTED,
        function(eventCode, guildId)
            WhereIsIt.selectedGuildBankId = guildId
        end
    )

    EVENT_MANAGER:RegisterForEvent(
        WhereIsIt.name .. "_GuildBankDeselected",
        EVENT_GUILD_BANK_DESELECTED,
        function()
            WhereIsIt.selectedGuildBankId = nil
        end
    )

    EVENT_MANAGER:RegisterForEvent(
        WhereIsIt.name .. "_GuildDataLoaded",
        EVENT_GUILD_DATA_LOADED,
        function() WhereIsIt:PruneLeftGuilds() end
    )

    EVENT_MANAGER:RegisterForEvent(
        WhereIsIt.name .. "_GuildLeft",
        EVENT_GUILD_SELF_LEFT_GUILD,
        function(eventCode, guildServerId, characterName, guildId)
            local sv = WhereIsIt.savedVariables
            if sv and sv.account and sv.account.guildBanks and guildId then
                sv.account.guildBanks[tostring(guildId)] = nil
            end
        end
    )

    EVENT_MANAGER:RegisterForEvent(
        WhereIsIt.name .. "_GuildBankReady",
        EVENT_GUILD_BANK_ITEMS_READY,
        function() WhereIsIt:ScanGuildBank() end
    )

    local guildScanPending = false
    local function RequestGuildBankScan()
        if guildScanPending then return end
        guildScanPending = true
        zo_callLater(function()
            guildScanPending = false
            WhereIsIt:ScanGuildBank()
        end, 1500)
    end

    EVENT_MANAGER:RegisterForEvent(
        WhereIsIt.name .. "_GuildBankAdded",
        EVENT_GUILD_BANK_ITEM_ADDED,
        RequestGuildBankScan
    )

    EVENT_MANAGER:RegisterForEvent(
        WhereIsIt.name .. "_GuildBankRemoved",
        EVENT_GUILD_BANK_ITEM_REMOVED,
        RequestGuildBankScan
    )

    EVENT_MANAGER:RegisterForEvent(
        WhereIsIt.name .. "_CompanionOn",
        EVENT_COMPANION_ACTIVATED,
        function() WhereIsIt:ScanCompanion() end
    )

    EVENT_MANAGER:RegisterForEvent(
        WhereIsIt.name .. "_CompanionOff",
        EVENT_COMPANION_DEACTIVATED,
        function()
            if WhereIsIt.slotIndex then
                WhereIsIt.slotIndex[BAG_COMPANION_WORN] = nil
            end
        end
    )

    EVENT_MANAGER:RegisterForEvent(
        WhereIsIt.name .. "_Deactivate",
        EVENT_PLAYER_DEACTIVATED,
        function() WhereIsIt:ScanCharacter() end
    )

    SLASH_COMMANDS["/wii"] = function()
        if WhereIsIt.OpenMenu then WhereIsIt.OpenMenu() end
    end

    EVENT_MANAGER:UnregisterForEvent(WhereIsIt.name, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(WhereIsIt.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
