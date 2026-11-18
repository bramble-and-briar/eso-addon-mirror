---@diagnostic disable: undefined-field, inject-field -- ESO Control/ZO_* stubs do not describe native UI fields completely
if not SemisPlaygroundCheckAccess() then return end

---Item facts as tooltip lines, shared by the log and the pack view.
---@class InventoryPocDetails
local details = {}
BattleScrolls.inventoryPocDetails = details

---@type table<InventoryPocReason, string|number>
details.REASONS = {
    reserved = BATTLESCROLLS_IPOC_REASON_RESERVED, stolen = BATTLESCROLLS_IPOC_REASON_STOLEN,
    crown = BATTLESCROLLS_IPOC_REASON_CROWN, junk = BATTLESCROLLS_IPOC_REASON_JUNK,
    glyph = BATTLESCROLLS_IPOC_REASON_GLYPH, material = BATTLESCROLLS_IPOC_REASON_MATERIAL,
    gear = BATTLESCROLLS_IPOC_REASON_GEAR, knowledge = BATTLESCROLLS_IPOC_REASON_KNOWLEDGE,
    price = BATTLESCROLLS_IPOC_REASON_PRICE, companion = BATTLESCROLLS_IPOC_REASON_COMPANION,
    priceCheck = BATTLESCROLLS_IPOC_REASON_PRICE_CHECK,
    container = BATTLESCROLLS_IPOC_REASON_CONTAINER, supplies = BATTLESCROLLS_IPOC_REASON_SUPPLIES,
    unassigned = BATTLESCROLLS_IPOC_REASON_UNASSIGNED, learn = BATTLESCROLLS_IPOC_REASON_LEARN,
    valuablePlan = BATTLESCROLLS_IPOC_REASON_VALUABLE_PLAN, duplicate = BATTLESCROLLS_IPOC_REASON_DUPLICATE,
    sale = BATTLESCROLLS_IPOC_REASON_SALE,
    collection = BATTLESCROLLS_IPOC_REASON_COLLECTION, crafted = BATTLESCROLLS_IPOC_REASON_CRAFTED,
    -- ESO's own "Cannot Sell" label, localized by the game.
    unsellable = _G['SI_ITEMSELLINFORMATION' .. ITEM_SELL_INFORMATION_CANNOT_SELL],
}

---@param lines string[]
---@param id string|number
---@param ... any
function details.add(lines, id, ...)
    lines[#lines + 1] = zo_strformat(GetString(id), ...)
end

---What the item is, read from its link: this works after the item is gone.
---@param lines string[]
---@param link string
---@param itemId number
function details.identity(lines, link, itemId)
    local itemType, specializedType = GetItemLinkItemType(link)
    details.add(lines, BATTLESCROLLS_IPOC_DETAIL_ITEM_ID, itemId)
    details.add(lines, BATTLESCROLLS_IPOC_DETAIL_TYPE, GetString('SI_ITEMTYPE', itemType), itemType,
        GetString('SI_SPECIALIZEDITEMTYPE', specializedType), specializedType)
    local quality = GetItemLinkFunctionalQuality(link)
    details.add(lines, BATTLESCROLLS_IPOC_DETAIL_QUALITY, GetString('SI_ITEMQUALITY', quality), quality)
    local trait = GetItemLinkTraitInfo(link)
    if trait ~= ITEM_TRAIT_TYPE_NONE then
        details.add(lines, BATTLESCROLLS_IPOC_DETAIL_TRAIT, GetString('SI_ITEMTRAITTYPE', trait), trait)
    end
    local style = GetItemLinkItemStyle(link)
    if style > 0 then details.add(lines, BATTLESCROLLS_IPOC_DETAIL_STYLE, GetItemStyleName(style), style) end
    local hasSet, setName, _, _, _, setId = GetItemLinkSetInfo(link, false)
    if hasSet then details.add(lines, BATTLESCROLLS_IPOC_DETAIL_SET, setName, setId) end
end

---The prices a decision used.
---@param lines string[]
---@param link string
---@param prices InventoryPocLogDetails
function details.prices(lines, link, prices)
    lines[#lines + 1] = ''
    details.add(lines, BATTLESCROLLS_IPOC_DETAIL_PRICES)
    details.add(lines, BATTLESCROLLS_IPOC_DETAIL_VENDOR, prices.vendorUnit)
    if prices.marketUnit then details.add(lines, BATTLESCROLLS_IPOC_DETAIL_MARKET, prices.marketUnit) end
    -- Older entries also saved style-material quotes for glyphs and
    -- other items that cannot return smithing materials.
    local itemType = GetItemLinkItemType(link)
    local playerGear = (itemType == ITEMTYPE_ARMOR or itemType == ITEMTYPE_WEAPON)
        and GetItemLinkActorCategory(link) ~= GAMEPLAY_ACTOR_CATEGORY_COMPANION
    if not playerGear then return end
    for _, material in ipairs({
        { link = prices.styleMaterialLink, price = prices.styleMaterialUnit },
        { link = prices.traitMaterialLink, price = prices.traitMaterialUnit },
        { link = prices.improvementMaterialLink, price = prices.improvementMaterialUnit },
    }) do
        if material.link and material.link ~= '' then
            if material.price then details.add(lines, BATTLESCROLLS_IPOC_DETAIL_MATERIAL, material.link, material.price)
            else details.add(lines, BATTLESCROLLS_IPOC_DETAIL_UNPRICED, material.link) end
        end
    end
    if prices.gearSaleMinimum then
        details.add(lines, BATTLESCROLLS_IPOC_DETAIL_SALE_MINIMUM, math.ceil(prices.gearSaleMinimum))
    end
end
