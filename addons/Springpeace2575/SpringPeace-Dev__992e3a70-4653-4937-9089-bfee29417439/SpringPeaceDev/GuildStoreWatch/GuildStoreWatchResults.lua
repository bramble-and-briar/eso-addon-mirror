-----------------------------------------------------------
-- Author: SpringPeace2575 | Version: 0.9.0
-- Results module for GuildStoreWatch add-on
-----------------------------------------------------------

GuildStoreWatchResults = GuildStoreWatchResults or {}
local GSWResults = GuildStoreWatchResults
local GSWData = GuildStoreWatchData

GSWResults.COLLECTION = {
    ITEMS = "items",
    CONTEXTS = "contexts",
    SELLERS = "sellers",
    ZONES = "zones",
    TRADERS = "traders",
    GUILDS = "guilds",
    SEARCHES = "searches",
}

GSWResults.sv = {
    maxResults = 10000,

    keepUncollectedItemsOnly = false,
    showCheapestItemsOnly = true,
    showUncollectedItemsOnly = false,
    enablePageRotation = true,
    deleteWholeItem = false,
    trimResults = false,
    orderedByName = false,

    selectedProvince = "All",
    selectedAlliance = "All",
    selectedZone = "All",
    selectedSign = "All",
    selectedTrader = "All",

    debug = false,

    tradersLastCheck = {},

    -- collections, values by ix
    results = {},
    items = {},
    contexts = {},
    sellers = {},
    zones = {},
    traders = {},
    guilds = {},
    searches = {},

    resultsCount = 0,
    resultsLength = 0,
}

GSWResults.state = {
    matchingRows = {},
    matchingPageRows = {},
    matchingSelectedRow = nil,
    matchingPage = 1,
    matchingPageSize = 50,
    matchingTotalPages = 1,

    searchFilter = "",

    -- ids/ixs by value
    _items = {},
    _contexts = {}, -- savedAt can be diractly in context, because it is not part of the key and evrey page (context) will have different savedAt
    _sellers = {},
    _zones = {},
    _traders = {},
    _guilds = {},
    _searches = {},
}

GSWResults.callbacks = {
    RefreshFull = function() end,
}

function GSWResults.Initialize(sv, RefreshFull)
    GSWResults.sv = sv

    GSWResults.EnsureSavedVariables()
    GSWResults.EnsureState()

    if RefreshFull then GSWResults.callbacks.RefreshFull = RefreshFull end

    SPFLibMotif.RebuildMotifChapterCache()

    GSWResults.RebuildResults()

    -- TODO: only temporary to fix already existing data
    GSWResults.FillKeyInItems()
end

function GSWResults.FillKeyInItems()
    for _, item in ipairs(GSWResults.sv.items) do
        if item and not item.ik then
            item.ik = GSWResults.GetItemKeyFromItemLink(item.il)
        end
    end
end

function GSWResults.EnsureSavedVariables()
    if type(GSWResults.sv.maxResults) ~= "number" then GSWResults.sv.maxResults = 10000 end
    if type(GSWResults.sv.debug) ~= "boolean" then GSWResults.sv.debug = false end

    if type(GSWResults.sv.keepUncollectedItemsOnly) ~= "boolean" then GSWResults.sv.keepUncollectedItemsOnly = false end
    if type(GSWResults.sv.showCheapestItemsOnly) ~= "boolean" then GSWResults.sv.showCheapestItemsOnly = true end
    if type(GSWResults.sv.showUncollectedItemsOnly) ~= "boolean" then GSWResults.sv.showUncollectedItemsOnly = false end
    if type(GSWResults.sv.enablePageRotation) ~= "boolean" then GSWResults.sv.enablePageRotation = true end
    if type(GSWResults.sv.deleteWholeItem) ~= "boolean" then GSWResults.sv.deleteWholeItem = false end
    if type(GSWResults.sv.trimResults) ~= "boolean" then GSWResults.sv.trimResults = false end
    if type(GSWResults.sv.orderedByName) ~= "boolean" then GSWResults.sv.orderedByName = false end
    if type(GSWResults.sv.selectedProvince) ~= "string" then GSWResults.sv.selectedProvince = "All" end
    if type(GSWResults.sv.selectedAlliance) ~= "string" then GSWResults.sv.selectedAlliance = "All" end
    if type(GSWResults.sv.selectedZone) ~= "string" then GSWResults.sv.selectedZone = "All" end
    if type(GSWResults.sv.selectedSign) ~= "string" then GSWResults.sv.selectedSign = "All" end
    if type(GSWResults.sv.selectedTrader) ~= "string" then GSWResults.sv.selectedTrader = "All" end

    if type(GSWResults.sv.tradersLastCheck) ~= "table" then GSWResults.sv.tradersLastCheck = {} end

    if type(GSWResults.sv.results) ~= "table" then GSWResults.sv.results = {} end
    if type(GSWResults.sv.items) ~= "table" then GSWResults.sv.items = {} end
    if type(GSWResults.sv.contexts) ~= "table" then GSWResults.sv.contexts = {} end
    if type(GSWResults.sv.sellers) ~= "table" then GSWResults.sv.sellers = {} end
    if type(GSWResults.sv.zones) ~= "table" then GSWResults.sv.zones = {} end
    if type(GSWResults.sv.traders) ~= "table" then GSWResults.sv.traders = {} end
    if type(GSWResults.sv.guilds) ~= "table" then GSWResults.sv.guilds = {} end
    if type(GSWResults.sv.searches) ~= "table" then GSWResults.sv.searches = {} end

    if type(GSWResults.sv.resultsCount) ~= "number" then GSWResults.sv.resultsCount = 0 end
    if type(GSWResults.sv.resultsLength) ~= "number" then GSWResults.sv.resultsLength = 0 end
end

function GSWResults.EnsureState()
    GSWResults.state.matchingRows = GSWResults.state.matchingRows or {}
    GSWResults.state.matchingPageRows = GSWResults.state.matchingPageRows or {}
    GSWResults.state.matchingSelectedRow = GSWResults.state.matchingSelectedRow or nil
    GSWResults.state.matchingPage = GSWResults.state.matchingPage or 1
    GSWResults.state.matchingPageSize = GSWResults.state.matchingPageSize or 50
    GSWResults.state.matchingTotalPages = GSWResults.state.matchingTotalPages or 1

    GSWResults.state.searchFilter = GSWResults.state.searchFilter or ""
end

function GSWResults.ClearWholeState()
    GSWResults.sv.results = {}

    GSWResults.sv.items = {}
    GSWResults.sv.contexts = {}
    GSWResults.sv.sellers = {}
    GSWResults.sv.zones = {}
    GSWResults.sv.traders = {}
    GSWResults.sv.guilds = {}
    GSWResults.sv.searches = {}

    GSWResults.state._items = {}
    GSWResults.state._contexts = {}
    GSWResults.state._sellers = {}
    GSWResults.state._zones = {}
    GSWResults.state._traders = {}
    GSWResults.state._guilds = {}
    GSWResults.state._searches = {}

    GSWResults.state.matchingSelectedRow = nil
    GSWResults.state.matchingPage = 1
    GSWResults.state.matchingTotalPages = 1
    GSWResults.state.matchingRows = {}
    GSWResults.state.matchingPageRows = {}

    GSWResults.sv.resultsCount = 0
    GSWResults.sv.resultsLength = 0

    GSWResults.Debug("All saved rows cleared.")

    GSWResults.callbacks.RefreshFull()
end

function GSWResults.ReverseMap(map, getValueKeyFunc)
    local reversed = {}
     for key, value in ipairs(map) do
        if value then
            local valueKey = getValueKeyFunc and getValueKeyFunc(value) or value
            if valueKey then
                reversed[valueKey] = key
            end
        end
    end
    return reversed
end

function GSWResults.AddValueToMap(map, reverseMap, value, getValueKeyFunc)
    -- TODO: currently unused
    local valueKey = getValueKeyFunc and getValueKeyFunc(value) or value

    if reverseMap[valueKey] then
        return reverseMap[valueKey]
    end

    local ix = #map

    map[ix] = value
    reverseMap[valueKey] = ix

    return ix
end

function GSWResults.AddToCollection(collection, value, getValueKeyFunc)
    local valueKey = getValueKeyFunc and getValueKeyFunc(value) or value

    local reverseCollection = "_"..collection
    if GSWResults.state[reverseCollection][valueKey] then
        return GSWResults.state[reverseCollection][valueKey]
    end

    
    local ix = #GSWResults.sv[collection] + 1

    GSWResults.sv[collection][ix] = value
    GSWResults.state[reverseCollection][valueKey] = ix

    return ix
end

function GSWResults.GetItemKey(item)
    if not item or not item.il then
        return ""
    end

    if item.k then
        return item.k
    end

    local key =
        tostring(GetItemLinkItemId(item.il) or 0) .. "|" ..
        tostring(GetItemLinkDisplayQuality(item.il) or 0) .. "|" ..
        tostring(GetItemLinkTraitInfo(item.il) or 0) .. "|" ..
        tostring(GetItemLinkFinalEnchantId(item.il) or 0)

    item.k = key

    return key
end

function GSWResults.GetContextKey(context)
    if not context then
        return ""
    end

    local key =
        tostring(context.tn or 0) .. "|" ..
        tostring(context.st or 0) .. "|" ..
        tostring(context.pg or 0)

    return key
end

function GSWResults.GetContextAllPagesKey(context)
    if not context then
        return ""
    end

    local key =
        tostring(context.tn or 0) .. "|" ..
        tostring(context.st or 0)

    return key
end

function GSWResults.RebuildCollection(collection, assignedIxs)
    local oldIndexMap = {}
    local items = {}
    local ixn = 0

    local collectionData = GSWResults.sv[collection] or {}
    if type(collectionData) ~= "table" then collectionData = {} end

    for ix, item in ipairs(collectionData) do
        if assignedIxs[ix] == true then
            ixn = ixn + 1
            items[ixn] = item

            oldIndexMap[ix] = ixn
        end
    end

    GSWResults.sv[collection] = items

    return oldIndexMap
end

function GSWResults.RebuildResults()
    local assignedItems = {}
    local assignedContexts = {}
    local assignedSellers = {}
    local assignedZones = {}
    local assignedTraders = {}
    local assignedGuilds = {}
    local assignedSearches = {}

    local results = {}
    local rxn = 0
    for rx = 1, GSWResults.sv.resultsLength do
        local result = GSWResults.sv.results[rx]
        if result ~= nil then
            assignedItems[result.ix] = true
            assignedContexts[result.cx] = true
            assignedSellers[result.sn] = true

            rxn = rxn + 1
            results[rxn] = result
        end
    end
    GSWResults.sv.results = results
    GSWResults.sv.resultsCount = rxn
    GSWResults.sv.resultsLength = rxn

    for cx, context in ipairs(GSWResults.sv.contexts) do
        if assignedContexts[cx] == true then
            assignedZones[context.zn] = true
            assignedTraders[context.tn] = true
            assignedGuilds[context.gn] = true
            assignedSearches[context.st] = true
        end
    end

    local itemsOldIndexMap = GSWResults.RebuildCollection(GSWResults.COLLECTION.ITEMS, assignedItems)
    local contextsOldIndexMap = GSWResults.RebuildCollection(GSWResults.COLLECTION.CONTEXTS, assignedContexts)
    local sellersOldIndexMap = GSWResults.RebuildCollection(GSWResults.COLLECTION.SELLERS, assignedSellers)
    local zonesOldIndexMap = GSWResults.RebuildCollection(GSWResults.COLLECTION.ZONES, assignedZones)
    local tradersOldIndexMap = GSWResults.RebuildCollection(GSWResults.COLLECTION.TRADERS, assignedTraders)
    local guildsOldIndexMap = GSWResults.RebuildCollection(GSWResults.COLLECTION.GUILDS, assignedGuilds)
    local searchesOldIndexMap = GSWResults.RebuildCollection(GSWResults.COLLECTION.SEARCHES, assignedSearches)

    for _, context in ipairs(GSWResults.sv.contexts) do
        context.zn = zonesOldIndexMap[context.zn]
        context.tn = tradersOldIndexMap[context.tn]
        context.gn = guildsOldIndexMap[context.gn]
        context.st = searchesOldIndexMap[context.st]
    end

    for _, result in ipairs(GSWResults.sv.results) do
        result.ix = itemsOldIndexMap[result.ix]
        result.cx = contextsOldIndexMap[result.cx]
        result.sn = sellersOldIndexMap[result.sn]
    end

    -- prepera reverse mappings
    GSWResults.state._items = GSWResults.ReverseMap(GSWResults.sv.items, GSWResults.GetItemKey)
    GSWResults.state._contexts = GSWResults.ReverseMap(GSWResults.sv.contexts, GSWResults.GetContextKey)
    GSWResults.state._sellers = GSWResults.ReverseMap(GSWResults.sv.sellers)
    GSWResults.state._zones = GSWResults.ReverseMap(GSWResults.sv.zones)
    GSWResults.state._traders = GSWResults.ReverseMap(GSWResults.sv.traders)
    GSWResults.state._guilds = GSWResults.ReverseMap(GSWResults.sv.guilds)
    GSWResults.state._searches = GSWResults.ReverseMap(GSWResults.sv.searches)
end

function GSWResults.Debug(text)
    if GSWResults.sv and GSWResults.sv.debug then
        d(string.format("[GSW] DEBUG: %s", tostring(text)))
    end
end

function GSWResults.TrimResults()
    if not GSWResults.sv.trimResults then
        return
    end

    local toRemove = GSWResults.sv.resultsCount - GSWResults.sv.maxResults
    local removed = 0

    for i = 1, GSWResults.sv.resultsLength do
        if toRemove <= 0 then
            break
        end

        if GSWResults.sv.results[i] ~= nil then
            GSWResults.sv.results = nil
            GSWResults.sv.resultsCount = GSWResults.sv.resultsCount - 1
            toRemove = toRemove - 1
            removed = removed + 1
        end
    end

    if removed > 0 then
        GSWResults.Debug(string.format("Trimmed %d old rows", removed))

        GSWResults.RebuildResults()
    end
end

function GSWResults.MakeResultKey(result)
    local key =
        tostring(result.id or 0) .. "|" ..
        tostring(result.ix or 0) .. "|" ..
        tostring(result.sn or 0) .. "|" ..
        tostring(result.pp or 0) .. "|" ..
        tostring(result.sc or 0) .. "|" ..
        tostring(result.tr or 0)
    return key
end

function GSWResults.MakeTargetKey(result)
    if GSWResults.sv.deleteWholeItem then
        return result.ix
    end
    return GSWResults.MakeResultKey(result)
end

function GSWResults.BuildExistingKeyMap()
    local existing = {}
    for _, result in pairs(GSWResults.sv.results) do
        if result ~= nil then
            existing[GSWResults.MakeResultKey(result)] = true
        end
    end
    return existing
end

function GSWResults.MakeTraderSearchKey(traderName, searchText)
    local key =
        tostring(GSWResults.state._traders[traderName] or 0) .. "|" ..
        tostring(GSWResults.state._searches[searchText] or 0)
    return key
end

function GSWResults.ClearRowsForTraderSearch(traderName, searchText)
    local targetKey = GSWResults.MakeTraderSearchKey(traderName, searchText)
    local cxs = {}
    for cx, context in ipairs(GSWResults.sv.contexts) do
        if targetKey == GSWResults.GetContextAllPagesKey(context) then
            cxs[cx] = true
        end
    end

    local removed = 0

    for rx, result in pairs(GSWResults.sv.results) do
        if result ~= nil and cxs[result.cx] == true then
            GSWResults.sv.results[rx] = nil
            removed = removed + 1
        end
    end

    GSWResults.sv.resultsCount = GSWResults.sv.resultsCount - removed

    if GSWResults.sv and GSWResults.sv.debug and removed > 0 then
        local sessionKey = GSWResults.MakeTraderSearchKey(traderName, searchText)
        GSWResults.Debug(string.format("Removed %d stale rows for trader/search %s", removed, sessionKey))
    end

    if removed > 0 then
        GSWResults.RebuildResults()
    end
end

function GSWResults.GetProvince(zoneName)
    for _, zone in ipairs(GSWData.zones) do
        if zone.zone == zoneName then
            return zone.province
        end
    end
    return nil
end

function GSWResults.GetAlliance(zoneName)
    for _, zone in ipairs(GSWData.zones) do
        if zone.zone == zoneName then
            return zone.alliance
        end
    end
    return nil
end

function GSWResults.GetSign(traderName)
    for _, zone in ipairs(GSWData.zones) do
        for _, trader in ipairs(zone.traders) do
            if trader.name == traderName then
                return trader.alliance
            end
        end
    end
    return nil
end

function GSWResults.ShouldIncludeRowInView(row)
    local item = GSWResults.sv.items[row.ix]
    local context = GSWResults.sv.contexts[row.cx]
    local province = GSWResults.GetProvince(GSWResults.sv.zones[context.zn])
    local alliance = GSWResults.GetAlliance(GSWResults.sv.zones[context.zn])
    local sign = GSWResults.GetSign(GSWResults.sv.zones[context.tn])
    local isUncollected = item and item.iu or false
    if GSWResults.sv.showUncollectedItemsOnly and not isUncollected then
        return false
    end
    if GSWResults.sv.selectedZone ~= "All" and context.zn ~= GSWResults.state._zones[GSWResults.sv.selectedZone] then
        return false
    end
    if GSWResults.sv.selectedTrader ~= "All" and context.tn ~= GSWResults.state._traders[GSWResults.sv.selectedTrader] then
        return false
    end
    if GSWResults.sv.selectedProvince ~= "All" and province ~= GSWResults.sv.selectedProvince then
        return false
    end
    if GSWResults.sv.selectedAlliance ~= "All" and alliance ~= GSWResults.state._zones[GSWResults.sv.selectedAlliance] then
        return false
    end
    if GSWResults.sv.selectedSign ~= "All" and sign ~= GSWResults.state._zones[GSWResults.sv.selectedSign] then
        return false
    end
    return true
end

function GSWResults.GetCollectibleItemKey(collectibleId) return "c:" .. tostring(collectibleId) end
function GSWResults.GetRecipeItemKey(recipeListIndex, recipeIndex) return "r:" .. tostring(recipeListIndex) .. ":" .. tostring(recipeIndex) end
function GSWResults.GetMotifItemKey(styleId) return "m:" .. tostring(styleId) end
function GSWResults.GetSetItemKey(setId) return "s:" .. tostring(setId) end

function GSWResults.GetItemKeyFromItemLink(itemLink)
    local canBeUsedToLearn = CanItemLinkBeUsedToLearn(itemLink)
    if not canBeUsedToLearn then
        if IsItemLinkSetCollectionPiece(itemLink) then
            -- local itemId = GetItemLinkItemId(itemLink)
            -- TODO: very interesting function with potential for some next add-on, search for "function ZO_Tooltip:AddSet(itemLink, equipped, extraData)"
            local hasSet, setName, numBonuses, numNormalEquipped, maxEquipped, setId, numPerfectedEquipped = GetItemLinkSetInfo(itemLink, false)
            if hasSet then
                return GSWResults.GetSetItemKey(setId)
            end
        end
        return nil
    end

    local itemType = GetItemLinkItemType(itemLink)

    if itemType == ITEMTYPE_COLLECTIBLE then
        -- local collectibleId = GetCollectibleIdFromLink(itemLink)
        local collectibleId = GetItemLinkContainerCollectibleId(itemLink)
        return GSWResults.GetCollectibleItemKey(collectibleId)
    elseif itemType == ITEMTYPE_RECIPE then
        local recipeListIndex, recipeIndex = GetItemLinkGrantedRecipeIndices(itemLink)
        return GSWResults.GetRecipeItemKey(recipeListIndex, recipeIndex)
    elseif itemType == ITEMTYPE_RACIAL_STYLE_MOTIF or itemType == ITEMTYPE_NONE then
        local motifNumber = SPFLibMotif.GetStyleAndChapterFromMotif(itemLink)
        return GSWResults.GetMotifItemKey(motifNumber)
    end

    return nil
end

function GSWResults.AddItem(itemLink, isUncollected)
    local item = {
        il = itemLink,
        im = GetItemLinkName(itemLink),
        iu = isUncollected,
        ik = GSWResults.GetItemKeyFromItemLink(itemLink),
    }
    return GSWResults.AddToCollection(GSWResults.COLLECTION.ITEMS, item, GSWResults.GetItemKey)
end

function GSWResults.AddContext(source, savedAt, searchText, page, traderZone, traderName, guildName)
    local context = {
        -- src = source,
        sv = savedAt,
        st = GSWResults.AddToCollection(GSWResults.COLLECTION.SEARCHES, searchText),
        pg = page,
        zn = GSWResults.AddToCollection(GSWResults.COLLECTION.ZONES, traderZone),
        tn = GSWResults.AddToCollection(GSWResults.COLLECTION.TRADERS, traderName),
        gn = GSWResults.AddToCollection(GSWResults.COLLECTION.GUILDS, guildName),
    }
    -- context.ak = GSWResults.GetContextAllPagesKey(context)
    return GSWResults.AddToCollection(GSWResults.COLLECTION.CONTEXTS, context, GSWResults.GetContextKey)
end

GSWResults.uncollectedFilterNamePrefixes = {
    -- "Motif:",
    -- "Recipe:",
    -- "Style Page:",
}
GSWResults.uncollectedFilterItemTypes = {
    -- ITEMTYPE_ARMOR,
    -- ITEMTYPE_WEAPON,
    -- ITEMTYPE_JEWELRY_RAW_TRAIT,
}

function GSWResults.ItemMatchesUncollectedFilterScope(itemLink)
    local prefixList = GSWResults.uncollectedFilterNamePrefixes or {}
    local itemTypeList = GSWResults.uncollectedFilterItemTypes or {}

    local hasPrefixRules = type(prefixList) == "table" and next(prefixList) ~= nil
    local hasItemTypeRules = type(itemTypeList) == "table" and next(itemTypeList) ~= nil

    if not hasPrefixRules and not hasItemTypeRules then
        return true
    end

    local normalizedName = SPFLibUtils.Lower((itemLink and GetItemLinkName and GetItemLinkName(itemLink)) or "")
    if hasPrefixRules then
        for _, prefix in ipairs(prefixList) do
            local p = SPFLibUtils.Lower(prefix)
            if p ~= "" and zo_plainstrfind(normalizedName, p, 1, true) == 1 then
                return true
            end
        end
    end

    if hasItemTypeRules and itemLink and GetItemLinkItemType then
        local itemType = GetItemLinkItemType(itemLink)
        for _, allowedType in ipairs(itemTypeList) do
            if itemType == allowedType then
                return true
            end
        end
    end

    return false
end

function GSWResults.ShouldKeepItem(itemLink)
    local canBeUsedToLearn = CanItemLinkBeUsedToLearn(itemLink)

    local isSetCollectionPieceToUnlock = false
    if not canBeUsedToLearn then
        if IsItemLinkSetCollectionPiece(itemLink) then
            local itemId = GetItemLinkItemId(itemLink)
            if not IsItemSetCollectionPieceUnlocked(itemId) then
                isSetCollectionPieceToUnlock = true
            end
        end
    end

    local isCollectibleOrLearnable = GSWResults.ItemMatchesUncollectedFilterScope(itemLink)

    local isUncollected = canBeUsedToLearn or isSetCollectionPieceToUnlock

    if GSWResults.sv.keepUncollectedItemsOnly and isCollectibleOrLearnable and not isUncollected then
        return false, isUncollected
    end

    return true, isUncollected
end

function GSWResults.StoreCurrentSearchResults(items, sourceLabel, savedAt, searchText, page, traderZone, traderName, guildName)
    local existing = GSWResults.BuildExistingKeyMap()
    local added = 0
    local skippedCollected = 0
    local behindLimit = 0

    for _, itemData in ipairs(items) do
        local keepItem, isUncollected = GSWResults.ShouldKeepItem(itemData.itemLink)
        if keepItem then
            if (GSWResults.sv.resultsCount < GSWResults.sv.maxResults) or GSWResults.sv.trimResults == true then
                local ix = GSWResults.AddItem(itemData.itemLink, isUncollected)
                local cx = GSWResults.AddContext(sourceLabel, savedAt, searchText, page, traderZone, traderName, guildName)
                local result = {
                    ix = ix,
                    cx = cx,
                    id = itemData.itemUniqueId,
                    tr = itemData.timeRemaining,
                    sc = itemData.stackCount,
                    pp = itemData.purchasePrice,
                    pu = itemData.purchasePricePerUnit,
                    sn = GSWResults.AddToCollection(GSWResults.COLLECTION.SELLERS, itemData.sellerName),
                }
                local key = GSWResults.MakeResultKey(result)
                if not existing[key] then
                    existing[key] = true
                    GSWResults.sv.resultsCount = GSWResults.sv.resultsCount + 1
                    GSWResults.sv.resultsLength = GSWResults.sv.resultsLength + 1
                    GSWResults.sv.results[GSWResults.sv.resultsLength] = result
                    added = added + 1
                else
                    -- d("GSW Existing Result Key: "..key.." ; id: "..itemData.itemUniqueId.." ; ix: "..ix.." ; item: "..itemData.itemLink) -- TODO: remove after debug
                end
            else
                behindLimit = behindLimit + 1
            end
        else
            skippedCollected = skippedCollected + 1
        end
    end

    if skippedCollected > 0 then
        GSWResults.Debug(string.format("Skipped %d items filtered by collected-items rule", skippedCollected))
    end

    if behindLimit > 0 then
        GSWResults.Debug(string.format("Skipped %d items, because max results limit reached", behindLimit))
    end

    if added > 0 then
        GSWResults.Debug(string.format("Captured %d rows from %s", added, sourceLabel))
    else
        GSWResults.Debug("No new rows captured from " .. tostring(sourceLabel))
    end

    GSWResults.TrimResults()
    GSWResults.RefreshTrader(traderName)
end

function GSWResults.GetResult(rx)
    return GSWResults.sv.results[rx] or {}
end

function GSWResults.GetResultItem(rx)
    local result = GSWResults.sv.results[rx] or {}
    return GSWResults.sv.items[result and result.ix or 1] or {}
end

function GSWResults.GetContextItem(rx)
    local result = GSWResults.sv.results[rx] or {}
    return GSWResults.sv.contexts[result and result.cx or 1] or {}
end

function GSWResults.RecreateResult(rx)
    if rx == nil then
        return nil
    end

    local result = GSWResults.sv.results[rx] or {}

    local item = GSWResults.sv.items[result.ix or 0] or {}

    local context = GSWResults.sv.contexts[result.cx or 0] or {}

    -- TODO: fallbacks will not be probably needed already, because reindexing should be fixed now
    local resultFull = {
        -- source = sourceLabel,
        savedAt = context.sv or 0,
        searchText = GSWResults.sv.searches[context.st or 0] or "",
        page = context.pg or 0,

        traderZone = GSWResults.sv.zones[context.zn or 0] or "",
        traderName = GSWResults.sv.traders[context.tn or 0] or "",
        guildName = GSWResults.sv.guilds[context.gn or 0] or "",

        isUncollected = item.iu,

        -- itemName = ZO_TradingHouse_GetItemDataFormattedName(itemData), -- itemData.formattedName
        -- itemData = itemData,

        itemData = {
            itemLink = item.il,
            sellerName = GSWResults.sv.sellers[result.sn or 0] or "",
            purchasePrice = result.pp,
            purchasePricePerUnit = result.pu,
            stackCount = result.sc,
            itemUniqueId = result.id, -- maybe not needed when we are index based
            timeRemaining = result.tr,
        },
    }
    return resultFull
end

function GSWResults.GetResultCompareValues(rx)
    local result = GSWResults.sv.results[rx]
    local item = GSWResults.sv.items[result.ix]
    local context = GSWResults.sv.contexts[result.cx]

    local im = ""
    local pp = 0
    local sv = 0
    if item ~= nil then im = item.im end
    if result ~= nil then pp = result.pp end
    if context ~= nil then sv = context.sv end

    return im, pp, sv
end

function GSWResults.SortRows(rows)
    if GSWResults.sv.orderedByName then
        table.sort(rows, function(a, b)
            local an, ap, as = GSWResults.GetResultCompareValues(a)
            local bn, bp, bs = GSWResults.GetResultCompareValues(b)

            if an == bn then
                if ap == bp then
                    return as > bs
                end
                return ap < bp
            end
            return an < bn
        end)
    else
        table.sort(rows, function(a, b)
            local an, ap, as = GSWResults.GetResultCompareValues(a)
            local bn, bp, bs = GSWResults.GetResultCompareValues(b)

            if ap == bp then
                if an == bn then
                    return as > bs
                end
                return an < bn
            end
            return ap < bp
        end)
    end
end

function GSWResults.BuildCheapestRows()
    local cheapestByItem = {}

    for rx, result in pairs(GSWResults.sv.results) do
        if result ~= nil and GSWResults.ShouldIncludeRowInView(result) then
            local ix = result.ix
            local crx = cheapestByItem[ix]

            if crx == nil then
                cheapestByItem[ix] = rx
            else
                local current = GSWResults.GetResult(crx)
                local resultUnitPrice = SPFLibUtils.Safe(result.pu, result.pp)
                local currentUnitPrice = SPFLibUtils.Safe(current.pu, current.pp)
                
                local resultContext = GSWResults.GetContextItem(rx)
                local currentContext = GSWResults.GetContextItem(crx)

                if resultUnitPrice < currentUnitPrice
                    or (resultUnitPrice == currentUnitPrice and SPFLibUtils.Safe(resultContext.sv, 0) > SPFLibUtils.Safe(currentContext.sv, 0)) then
                    cheapestByItem[ix] = rx
                end
            end
        end
    end

    local rows = {}
    local rowix = 0
    for _, row in pairs(cheapestByItem) do
        rowix = rowix + 1
        rows[rowix] = row
    end

    GSWResults.SortRows(rows)

    return rows
end

function GSWResults.BuildAllRows()
    local rows = {}
    local rowix = 0
    for rx, result in pairs(GSWResults.sv.results) do
        if result ~= nil and GSWResults.ShouldIncludeRowInView(result) then
            rowix = rowix + 1
            rows[rowix] = rx
        end
    end

    GSWResults.SortRows(rows)

    return rows
end

function GSWResults.BuildRowsForCurrentMenuMode()
    if GSWResults.sv.showCheapestItemsOnly then
        return GSWResults.BuildCheapestRows()
    end
    return GSWResults.BuildAllRows()
end

function GSWResults.GetAllVisibleRows()
    local rows = GSWResults.BuildRowsForCurrentMenuMode()
    local filterText = SPFLibUtils.Lower(GSWResults.state.searchFilter)
    if filterText == "" then
        return rows
    end

    local filtered = {}
    local fx = 0
    for _, row in ipairs(rows) do
        local result = GSWResults.sv.results[row]
        local item = GSWResults.sv.items[result.ix]
        local context = GSWResults.sv.contexts[result.cx]

        local haystack =
            SPFLibUtils.Lower(item.im) .. " " ..
            SPFLibUtils.Lower(GSWResults.sv.guilds[context.gn]) .. " " ..
            SPFLibUtils.Lower(GSWResults.sv.traders[context.tn]) .. " " ..
            SPFLibUtils.Lower(GSWResults.sv.zones[context.zn]) .. " " ..
            SPFLibUtils.Lower(GSWResults.sv.sellers[result.sn]) .. " " ..
            SPFLibUtils.Lower(GSWResults.sv.searches[context.st])

        if string.find(haystack, filterText, 1, true) then
            fx = fx + 1
            filtered[fx] = row
        end
    end
    return filtered
end

function GSWResults.CalculateVisibleRows()
    local rows = GSWResults.GetAllVisibleRows()
    local pageSize = math.max(1, tonumber(GSWResults.state.matchingPageSize) or 50)
    local totalPages = math.max(1, math.ceil(#rows / pageSize))
    local page = tonumber(GSWResults.state.matchingPage) or 1
    if page < 1 then page = 1 end
    if page > totalPages then page = totalPages end

    local startIndex = ((page - 1) * pageSize) + 1
    local endIndex = math.min(#rows, startIndex + pageSize - 1)
    local pageRows = {}
    local pageRowsIndex = 0
    for i = startIndex, endIndex do
        pageRowsIndex = pageRowsIndex + 1
        pageRows[pageRowsIndex] = rows[i]
    end

    GSWResults.state.matchingRows = rows
    GSWResults.state.matchingPageRows = pageRows
    GSWResults.state.matchingPage = page
    GSWResults.state.matchingTotalPages = totalPages
end

function GSWResults.RemoveResultsByKeys(keyMap)
    local removed = 0

    for rx, result in pairs(GSWResults.sv.results) do
        if result ~= nil then
            local key = GSWResults.MakeTargetKey(result)
            if keyMap[key] == true then
                GSWResults.sv.results[rx] = nil
                removed = removed + 1
            end
        end
    end

    if removed > 0 then
        GSWResults.Debug(string.format("Removed %d rows", removed))

        GSWResults.sv.resultsCount = GSWResults.sv.resultsCount - removed
        GSWResults.state.matchingSelectedRow = nil
        GSWResults.RebuildResults()
        GSWResults.callbacks.RefreshFull()
    end
end

function GSWResults.RecheckUncollectedItems()
    if not (GSWResults.sv and GSWResults.sv and type(GSWResults.sv.items) == "table") then
        return 0
    end

    local refreshed = 0
    for _, item in ipairs(GSWResults.sv.items) do
        if item and item.iu == true then
            local _, isUncollected = GSWResults.ShouldKeepItem(item.il)

            item.iu = isUncollected

            refreshed = refreshed + 1
        end
    end

    if refreshed > 0 then
        GSWResults.callbacks.RefreshFull()
    end

    return refreshed
end

function GSWResults.GetSelectedRow()
    local selectedRow = GSWResults.state.matchingSelectedRow
    if not selectedRow or not GSWResults.state.matchingPageRows then return nil end
    for _, row in ipairs(GSWResults.state.matchingPageRows) do
        if row == selectedRow then
            return row
        end
    end
    return nil
end

function GSWResults.DeleteSelectedRow(selectedRow)
    local row = selectedRow or GSWResults.GetSelectedRow()
    if not row then return end
    local keyMap = {}
    keyMap[GSWResults.MakeTargetKey(GSWResults.sv.results[row])] = true
    GSWResults.RemoveResultsByKeys(keyMap)
end

function GSWResults.DeleteCurrentView()
    local rows = GSWResults.state.matchingPageRows or {}
    if #rows == 0 then return end
    local keyMap = {}
    for _, row in ipairs(rows) do
        keyMap[GSWResults.MakeTargetKey(GSWResults.sv.results[row])] = true
    end
    GSWResults.RemoveResultsByKeys(keyMap)
end

function GSWResults.DebugCounts()
    d("GSW Results: "..tostring(#GSWResults.sv.results))
    d("GSW Items: "..tostring(#GSWResults.sv.items))
    d("GSW Contexts: "..tostring(#GSWResults.sv.contexts))
    d("GSW Sellers: "..tostring(#GSWResults.sv.sellers))
    d("GSW Searches: "..tostring(#GSWResults.sv.searches))
    d("GSW Zones: "..tostring(#GSWResults.sv.zones))
    d("GSW Traders: "..tostring(#GSWResults.sv.traders))
    d("GSW Guilds: "..tostring(#GSWResults.sv.guilds))
end

function GSWResults.DebugResult(rx)
    local result = GSWResults.sv.results[rx]
    local message = {}
    table.insert(message, "rx: "..tostring(rx))
    for key, value in pairs(result or {}) do
        table.insert(message, key..": "..tostring(value))
    end
    d("GSW Result: "..table.concat(message, " ; "))
end

function GSWResults.DebugItem(ix)
    local item = GSWResults.sv.items[ix]
    local message = {}
    table.insert(message, "ix: "..tostring(ix))
    for key, value in pairs(item or {}) do
        table.insert(message, key..": "..tostring(value))
    end
    d("GSW Item: "..table.concat(message, " ; "))
end

function GSWResults.DebugContext(ix)
    local context = GSWResults.sv.contexts[cx]
    local message = {}
    table.insert(message, "cx: "..tostring(cx))
    for key, value in pairs(context or {}) do
        table.insert(message, key..": "..tostring(value))
    end
    d("GSW Context: "..table.concat(message, " ; "))
end

function GSWResults.SumStoredRowPrices()
    local total = 0
    for _, row in pairs(GSWResults.sv.results) do
        if row ~= nil then
            total = total + (tonumber(row.pp) or tonumber(row.pu) or 0)
        end
    end
    return total
end

function GSWResults.SumRowPrices(rows)
    local total = 0
    for _, row in ipairs(rows or {}) do
        local result = GSWResults.sv.results[row]
        total = total + (tonumber(result.pp) or tonumber(result.pu) or 0)
    end
    return total
end

function GSWResults.GetStats()
    local viewMode = GSWResults.sv.showCheapestItemsOnly and "Cheapest" or "All"
    local allMatchingRows = GSWResults.state.matchingRows
    local matching = #allMatchingRows
    local stored = GSWResults.sv.resultsCount
    local matchingGold = GSWResults.SumRowPrices(allMatchingRows)
    local storedGold = GSWResults.SumStoredRowPrices()
    local page = GSWResults.state.matchingPage
    local totalPages = GSWResults.state.matchingTotalPages

    return viewMode, matching, stored, matchingGold, storedGold, page, totalPages
end

function GSWResults.RecheckUncollectedItem(itemKey)
    if not (GSWResults.sv and GSWResults.sv and type(GSWResults.sv.items) == "table") then
        return 0
    end

    local refreshed = 0
    for _, item in ipairs(GSWResults.sv.items) do
        if item and item.iu == true and item.ik == itemKey then
            local _, isUncollected = GSWResults.ShouldKeepItem(item.il)

            item.iu = isUncollected

            refreshed = refreshed + 1
        end
    end

    if refreshed > 0 then
        GSWResults.callbacks.RefreshFull()
    end

    return refreshed
end

-- could be made probably in better way, but this means parsing and comparing every itemKey and it is worse
function GSWResults.RefreshMotifCacheEntry(styleId)
    SPFLibMotif.RebuildMotifChapterCacheEntry(styleId)
end

local function GetNextDirtyUnlockStateCollectibleIdIter(_, lastCollectibleId)
    return GetNextDirtyUnlockStateCollectibleId(lastCollectibleId)
end

function GSWResults.OnCollectiblesUnlockStateChanged()
    for collectibleId in GetNextDirtyUnlockStateCollectibleIdIter do
        local itemKey = GSWResults.GetCollectibleItemKey(collectibleId)
        GSWResults.Debug("EVENT_COLLECTIBLES_UPDATED - " .. tostring(itemKey))
        local refreshed = GSWResults.RecheckUncollectedItem(itemKey)
        if refreshed > 0 then
            GSWResults.Debug("Item collected - ".. tostring(itemKey))
        else
            GSWResults.Debug("EVENT_COLLECTIBLES_UPDATED had no effect - " .. tostring(itemKey))
        end
    end
end

function GSWResults.RefreshTrader(trader)
    GSWResults.sv.tradersLastCheck[trader] = GetTimeStamp()
end

function GSWResults.InvalidateTrader(trader)
    GSWResults.sv.tradersLastCheck[trader] = nil
end

function GSWResults.InvalidateAllTraders()
    GSWResults.sv.tradersLastCheck = {}
end

local minute = 60
local hour = minute * minute
local day = hour * 24
local week = day * 7
local month = day * 30

function GSWResults.GetTraderStatusColor(trader)
    local now = GetTimeStamp()
    local elapsed = now - (GSWResults.sv.tradersLastCheck[trader] or now)

    if elapsed == 0 then
        return nil
    end

    local freshLevelTime = 1 * hour
    local recentLevelTime = 3 * hour

    if elapsed <= freshLevelTime then
        return ZO_ColorDef:New("2DC50E") -- fine
    elseif elapsed <= recentLevelTime then
        return ZO_ColorDef:New("CCAA1A") -- legendary
    end

    return ZO_ColorDef:New("E58B27") -- apex
end

function GSWResults.GetTradersStatusColor(traders)
    local now = GetTimeStamp()
    local allFresh = true
    local allRecent = true
    local anyTouched = false
    local anyUntouched = false

    for _, trader in ipairs(traders) do
        local elapsed = now - (GSWResults.sv.tradersLastCheck[trader] or now)

        if elapsed ~= 0 then
            anyTouched = true

            local freshLevelTime = 1 * hour
            local recentLevelTime = 3 * hour

            if elapsed > recentLevelTime then
                allRecent = false
            elseif elapsed > freshLevelTime then
                allFresh = false
            end
        else
            anyUntouched = true
        end
    end

    if not anyTouched then
        return nil
    end
    
    if anyTouched and anyUntouched then
        allFresh = false
        allRecent = false
    end

    if allFresh then
        return ZO_ColorDef:New("2DC50E") -- fine
    elseif allRecent then
        return ZO_ColorDef:New("CCAA1A") -- legendary
    elseif anyTouched then
        return ZO_ColorDef:New("3A92FF") -- superior
    end

    return ZO_ColorDef:New("E58B27") -- apex
end

function GSWResults.GetProvinces()
    local provinces = {}
    for _, province in ipairs(GSWData.provinces) do
        local traders = {}
        for _, zone in ipairs(GSWData.zones) do
            if zone.province == province then
                for _, trader in ipairs(zone.traders) do
                    traders[#traders + 1] = trader.name
                end
            end
        end
        local color = GSWResults.GetTradersStatusColor(traders)
        -- TODO: color by traders by selections
        provinces[#provinces + 1] = { id = province, name = province, color = color }
    end

    return provinces
end

function GSWResults.GetAlliances()
    local alliances = {}
    for _, alliance in ipairs(GSWData.alliances) do
        local traders = {}
        for _, zone in ipairs(GSWData.zones) do
            if zone.alliance == alliance then
                for _, trader in ipairs(zone.traders) do
                    traders[#traders + 1] = trader.name
                end
            end
        end
        local color = GSWResults.GetTradersStatusColor(traders)
        -- TODO: color by traders by selections
        alliances[#alliances + 1] = { id = alliance, name = alliance, color = color }
    end

    return alliances
end

function GSWResults.GetZones()
    local zones = {}
    for _, zone in ipairs(GSWData.zones) do
        if
            (GSWResults.sv.selectedProvince == "All" or GSWResults.sv.selectedProvince == zone.province) and
            (GSWResults.sv.selectedAlliance == "All" or GSWResults.sv.selectedAlliance == zone.alliance)
        then
            local traders = {}
            for _, trader in ipairs(zone.traders) do
                traders[#traders + 1] = trader.name
            end
            local color = GSWResults.GetTradersStatusColor(traders)
            zones[#zones + 1] = { id = zone.zone, name = zone.zone, color = color }
        end
    end

    return zones
end

function GSWResults.GetSigns()
    local signs = {}
    for _, sign in ipairs(GSWData.signs) do
        local traders = {}
        for _, zone in ipairs(GSWData.zones) do
            for _, trader in ipairs(zone.traders) do
                if trader.sign == sign.value then
                    traders[#traders + 1] = trader.name
                end
            end
        end
        local color = GSWResults.GetTradersStatusColor(traders)
        -- TODO: color by traders by selections
        signs[#signs + 1] = { id = sign.value, name = sign.name, color = color }
    end

    return signs
end

function GSWResults.GetTraders()
    local traders = {}
    for _, zone in ipairs(GSWData.zones) do
        if
            (GSWResults.sv.selectedProvince == "All" or GSWResults.sv.selectedProvince == zone.province) and
            (GSWResults.sv.selectedAlliance == "All" or GSWResults.sv.selectedAlliance == zone.alliance) and
            (GSWResults.sv.selectedZone == "All" or GSWResults.sv.selectedZone == zone.zone)
        then
            -- TODO: limit by other selections
            for _, trader in ipairs(zone.traders) do
                if GSWResults.sv.selectedSign == "All" or GSWResults.sv.selectedSign == trader.sign then
                    local color = GSWResults.GetTraderStatusColor(trader.name)
                    local name = trader.name
                    if trader.sign then
                        name = name .. " (" .. trader.sign .. ")"
                    end
                    traders[#traders + 1] = { id = trader.name, name = name, color = color }
                end
            end
        end
    end
    return traders
end
