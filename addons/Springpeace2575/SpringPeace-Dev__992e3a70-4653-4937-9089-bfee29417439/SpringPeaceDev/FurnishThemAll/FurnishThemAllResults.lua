-----------------------------------------------------------
-- Author: SpringPeace2575 | Version: 0.9.0
-- Results module for FurnishThemAll add-on
-----------------------------------------------------------

FurnishThemAllResults = FurnishThemAllResults or {}
local FTAResults = FurnishThemAllResults
local FTAData = FurnishThemAllData

FTAResults.COLLECTION = {
    CATEGORIES = "categories",
    SUBCATEGORIES = "subcategories",
    SOURCES = "sources",
    GROUPS = "groups",
    TAGS = "tags",
    TYPES = "types",
}

FTAResults.OrderByNone = "None"
FTAResults.OrderById = "Id"
FTAResults.OrderByCollection = "Collection"
FTAResults.OrderByName = "Name"
FTAResults.OrderBy = { FTAResults.OrderByNone, FTAResults.OrderById, FTAResults.OrderByCollection, FTAResults.OrderByName }

FTAResults.TimeUnitMinute = "Minute"
FTAResults.TimeUnitHour = "Hour"
FTAResults.TimeUnitDay = "Day"
FTAResults.TimeUnitWeek = "Week"
FTAResults.TimeUnitMonth = "Month"
FTAResults.TimeUnit = { FTAResults.TimeUnitMinute, FTAResults.TimeUnitHour, FTAResults.TimeUnitDay, FTAResults.TimeUnitWeek, FTAResults.TimeUnitMonth }

FTAResults.refreshDelay = 1200
FTAResults.chunkDelay = 300
FTAResults.chunkSize = 50

FTAResults.sv = {
    showUncollectedItemsOnly = false,
    rebuildOnDemandOnly = true,
    orderedBy = 3,

    freshLevelTimeUnit = "Day",
    freshLevelTimeValue = 1,
    recentLevelTimeUnit = "Month",
    recentLevelTimeValue = 1,

    selectedCategory = "All",
    selectedSubcategory = "All",
    selectedSource = "All",
    selectedGroup = "All",
    selectedTag = "All",
    selectedInventory = "All",

    debug = false,

    inventoriesLastCheck = {},

    -- collections, values by ix
    results = {},
    categories = {},
    subcategories = {},
    sources = {},
    groups = {},
    tags = {},
    types = {},

    collectedCount = 0,
    totalCount = 0,

    lastVersion = "0.0.1",
    nextVersion = nil,
}

FTAResults.state = {
    matchingRows = {},
    matchingPageRows = {},
    matchingSelectedRow = nil,
    matchingPage = 1,
    matchingPageSize = 50,
    matchingTotalPages = 1,

    searchFilter = "",

    -- ids/ixs by value
    _categories = {},
    _subcategories = {},
    _sources = {},
    _groups = {},
    _tags = {},
    _types = {},
    _inventories = {},

    -- for build only
    _matchingItems = {},
}

FTAResults.cache = {
    categoryNames = {},
}

FTAResults.callbacks = {
    RefreshFull = function() end,
}

function FTAResults.Initialize(sv, RefreshFull)
    FTAResults.sv = sv

    FTAResults.EnsureSavedVariables()
    FTAResults.EnsureState()

    if RefreshFull then FTAResults.callbacks.RefreshFull = RefreshFull end

    local forced = FTAResults.sv.nextVersion ~= FTAResults.sv.lastVersion or FTAResults.sv.lastVersion == nil
    FTAResults.Build(forced)
end

function FTAResults.EnsureSavedVariables()
    if type(FTAResults.sv.debug) ~= "boolean" then FTAResults.sv.debug = false end

    if type(FTAResults.sv.showUncollectedItemsOnly) ~= "boolean" then FTAResults.sv.showUncollectedItemsOnly = false end
    if type(FTAResults.sv.rebuildOnDemandOnly) ~= "boolean" then FTAResults.sv.rebuildOnDemandOnly = true end
    if type(FTAResults.sv.orderedBy) ~= "number" then FTAResults.sv.orderedBy = 3 end
    if type(FTAResults.sv.freshLevelTimeUnit) ~= "string" then FTAResults.sv.freshLevelTimeUnit = "Day" end
    if type(FTAResults.sv.freshLevelTimeValue) ~= "number" then FTAResults.sv.freshLevelTimeValue = 1 end
    if type(FTAResults.sv.recentLevelTimeUnit) ~= "string" then FTAResults.sv.recentLevelTimeUnit = "Month" end
    if type(FTAResults.sv.recentLevelTimeValue) ~= "number" then FTAResults.sv.recentLevelTimeValue = 1 end
    if type(FTAResults.sv.selectedCategory) ~= "string" then FTAResults.sv.selectedCategory = "All" end
    if type(FTAResults.sv.selectedSubcategory) ~= "string" then FTAResults.sv.selectedSubcategory = "All" end
    if type(FTAResults.sv.selectedSource) ~= "string" then FTAResults.sv.selectedSource = "All" end
    if type(FTAResults.sv.selectedGroup) ~= "string" then FTAResults.sv.selectedGroup = "All" end
    if type(FTAResults.sv.selectedTag) ~= "string" then FTAResults.sv.selectedTag = "All" end
    if type(FTAResults.sv.selectedInventory) ~= "string" then FTAResults.sv.selectedInventory = "All" end

    if type(FTAResults.sv.inventoriesLastCheck) ~= "table" then FTAResults.sv.inventoriesLastCheck = {} end

    if type(FTAResults.sv.results) ~= "table" then FTAResults.sv.results = {} end
    if type(FTAResults.sv.categories) ~= "table" then FTAResults.sv.categories = {} end
    if type(FTAResults.sv.subcategories) ~= "table" then FTAResults.sv.subcategories = {} end
    if type(FTAResults.sv.sources) ~= "table" then FTAResults.sv.sources = {} end
    if type(FTAResults.sv.groups) ~= "table" then FTAResults.sv.groups = {} end
    if type(FTAResults.sv.tags) ~= "table" then FTAResults.sv.tags = {} end
    if type(FTAResults.sv.types) ~= "table" then FTAResults.sv.types = {} end

    if type(FTAResults.sv.collectedCount) ~= "number" then FTAResults.sv.collectedCount = 0 end
    if type(FTAResults.sv.totalCount) ~= "number" then FTAResults.sv.totalCount = 0 end
end

function FTAResults.EnsureState()
    FTAResults.state.matchingRows = FTAResults.state.matchingRows or {}
    FTAResults.state.matchingPageRows = FTAResults.state.matchingPageRows or {}
    FTAResults.state.matchingSelectedRow = FTAResults.state.matchingSelectedRow or nil
    FTAResults.state.matchingPage = FTAResults.state.matchingPage or 1
    FTAResults.state.matchingPageSize = FTAResults.state.matchingPageSize or 50
    FTAResults.state.matchingTotalPages = FTAResults.state.matchingTotalPages or 1

    FTAResults.state.searchFilter = FTAResults.state.searchFilter or ""
end

function FTAResults.ClearWholeState()
    FTAResults.sv.results = {}

    FTAResults.sv.categories = {}
    FTAResults.sv.subcategories = {}
    FTAResults.sv.sources = {}
    FTAResults.sv.groups = {}
    FTAResults.sv.tags = {}
    FTAResults.sv.types = {}

    FTAResults.state._categories = {}
    FTAResults.state._subcategories = {}
    FTAResults.state._sources = {}
    FTAResults.state._groups = {}
    FTAResults.state._tags = {}
    FTAResults.state._types = {}
    FTAResults.state._inventories = {}

    FTAResults.state.matchingSelectedRow = nil
    FTAResults.state.matchingPage = 1
    FTAResults.state.matchingTotalPages = 1
    FTAResults.state.matchingRows = {}
    FTAResults.state.matchingPageRows = {}

    FTAResults.cache.categoryNames = {}

    FTAResults.sv.collectedCount = 0
    FTAResults.sv.totalCount = 0

    FTAResults.Debug("All saved results cleared.")
end

function FTAResults.AddToCollection(collection, value, getValueKeyFunc)
    local valueKey = getValueKeyFunc and getValueKeyFunc(value) or value

    local reverseCollection = "_"..collection
    if FTAResults.state[reverseCollection][valueKey] then
        return FTAResults.state[reverseCollection][valueKey]
    end

    local ix = #FTAResults.sv[collection] + 1

    FTAResults.sv[collection][ix] = value
    FTAResults.state[reverseCollection][valueKey] = ix

    return ix
end

function FTAResults.RebuildReverseCollection(collection, getValueKeyFunc)
    local reverseCollection = "_"..collection

    local collectionData = {}
    local collectionDataCandidate = FTAResults.sv[collection]
    if type(collectionDataCandidate) == "table" then
        collectionData = collectionDataCandidate
    end

    FTAResults.state[reverseCollection] = {}
    for ix, value in ipairs(collectionData) do
        local valueKey = getValueKeyFunc and getValueKeyFunc(value) or value
        FTAResults.state[reverseCollection][valueKey] = ix
    end
end

function FTAResults.Debug(text)
    if FTAResults.sv and FTAResults.sv.debug then
        d(string.format("[FTA] DEBUG: %s", tostring(text)))
    end
end

function FTAResults.GetOrderedByLabel()
    return FTAResults.OrderBy[FTAResults.sv.orderedBy] or ""
end

function FTAResults.NextOrderedBy()
    FTAResults.sv.orderedBy = FTAResults.sv.orderedBy % #FTAResults.OrderBy + 1
end

function FTAResults.GetSources()
    local sources = {}
    local sourcesCheck = {}

    for _, group in ipairs(FTAData.groups) do
        if not sourcesCheck[group.source] then
            sourcesCheck[group.source] = true
            sources[#sources + 1] = group.source
        end
    end

    -- sources[#sources + 1] = FTAData.specialSource
    sources[#sources + 1] = FTAData.defaultSource

    return sources
end

function FTAResults.GetGroups()
    local groups = {}
    local groupsCheck = {}

    for _, group in ipairs(FTAData.groups) do
        if FTAResults.sv.selectedSource == "All" or FTAResults.sv.selectedSource == group.source then
            if not groupsCheck[group.name] then
                groupsCheck[group.name] = true
                groups[#groups + 1] = group.name
            end
        end
    end
    return groups
end

function FTAResults.ShouldIncludeRowInView(row)
    local isUncollected = row and row.iu or false
    if FTAResults.sv.showUncollectedItemsOnly and not isUncollected then
        return false
    end
    if FTAResults.sv.selectedCategory ~= "All" and row.cn ~= FTAResults.state._categories[FTAResults.sv.selectedCategory] then
        return false
    end
    if FTAResults.sv.selectedSubcategory ~= "All" and row.sn ~= FTAResults.state._subcategories[FTAResults.sv.selectedSubcategory] then
        return false
    end
    if FTAResults.sv.selectedSource ~= "All" and not SPFLibUtils.Contains(row.sns, FTAResults.state._sources[FTAResults.sv.selectedSource]) then
        return false
    end
    if FTAResults.sv.selectedGroup ~= "All" and not SPFLibUtils.Contains(row.gns, FTAResults.state._groups[FTAResults.sv.selectedGroup]) then
        return false
    end
    if FTAResults.sv.selectedTag ~= "All" and not SPFLibUtils.Contains(row.tns, FTAResults.state._tags[FTAResults.sv.selectedTag]) then
        return false
    end
    if FTAResults.sv.selectedInventory ~= "All" and (row.inv[FTAResults.state._inventories[FTAResults.sv.selectedInventory]] or 0) == 0 then
        return false
    end
    return true
end

function FTAResults.IsAttunableCraftingStation(furnishingName)
    for _, i in ipairs(FTAData.attunableCraftingStations) do
        if string.find(furnishingName, i, 1, true) then
            return true
        end
    end
    return false
end

local function DebugStringBytes(label, value)
    value = tostring(value or "")

    d(label .. " len=" .. tostring(#value))
    d(label .. " raw=[" .. value .. "]")

    local parts = {}
    for i = 1, #value do
        local b = string.byte(value, i)
        local c = string.sub(value, i, i)

        parts[#parts + 1] = string.format(
            "%03d: %3d 0x%02X [%s]",
            i,
            b,
            b,
            c
        )
    end

    d(label .. " bytes:\n" .. table.concat(parts, "\n"))
end

local function DebugCompareStrings(a, b)
    a = tostring(a or "")
    b = tostring(b or "")

    d("COMPARE RESULT: " .. tostring(a == b))
    d("A len=" .. tostring(#a) .. " | B len=" .. tostring(#b))

    local maxLen = math.max(#a, #b)

    for i = 1, maxLen do
        local ba = string.byte(a, i)
        local bb = string.byte(b, i)

        if ba ~= bb then
            d("FIRST DIFF at byte " .. tostring(i))
            d("A byte=" .. tostring(ba) .. " char=[" .. tostring(string.sub(a, i, i)) .. "]")
            d("B byte=" .. tostring(bb) .. " char=[" .. tostring(string.sub(b, i, i)) .. "]")
            return
        end
    end

    d("No byte diff found.")
end

function FTAResults.ShouldIncludeInResults(furnishingName, item, categoryType, furnishingId)
    --[[ if furnishingId == 10167 and item.name == "Colovian Floor, Small Dual-Sided" then
        d("=== DEBUG Colovian Floor, Small Dual-Sided ===")

        DebugStringBytes("ITEM_NAME", item.name)
        DebugStringBytes("DB_NAME", furnishingName)

        DebugCompareStrings(item.name, furnishingName)
    end ]]
    if furnishingName == item.name then
        if item.id ~= nil then
            return item.id == furnishingId
        end
        return true
    end
    return false
end

function FTAResults.GetItemKey(group, item)
    return string.format("%s - %s - %s", SPFLibUtils.SafeText(group.source), SPFLibUtils.SafeText(group.name), SPFLibUtils.SafeText(item.name))
end

function FTAResults.DisplayUnmatched(matching, itemName)
    if not FTAResults.sv or not FTAResults.sv.debug then
        return
    end

    local unmatchedItems = {}
    for key, isKnown in pairs(matching) do
        if not isKnown then
            unmatchedItems[#unmatchedItems + 1] = key
        end
    end
    if #unmatchedItems > 0 then
        d(string.format("[FTA]: %d %ss are not matched with existing furnishings", #unmatchedItems, itemName))
        local displayMax = 40
        local counter = 0
        for _, unmatchedItem in ipairs(unmatchedItems) do
            d(string.format("[FTA]: Unmatched %s: %s", itemName, unmatchedItem))
            counter = counter + 1
            if counter >= displayMax then
                return
            end
        end
    else
        d(string.format("[FTA]: All %ss are matched with existing furnishings", itemName))
    end
end

function FTAResults.RebuildInventoriesState()
    local inventoriesReverseMap = {}
    for _, inventory in ipairs(FTAResults.GetInventories()) do
        inventoriesReverseMap[inventory.name] = inventory.id
    end
    FTAResults.state._inventories = inventoriesReverseMap
end

function FTAResults.RebuildState()
    FTAResults.RebuildReverseCollection(FTAResults.COLLECTION.CATEGORIES)
    FTAResults.RebuildReverseCollection(FTAResults.COLLECTION.SUBCATEGORIES)
    FTAResults.RebuildReverseCollection(FTAResults.COLLECTION.SOURCES)
    FTAResults.RebuildReverseCollection(FTAResults.COLLECTION.GROUPS)
    FTAResults.RebuildReverseCollection(FTAResults.COLLECTION.TAGS)
    FTAResults.RebuildReverseCollection(FTAResults.COLLECTION.TYPES)

    FTAResults.RebuildInventoriesState()
end

function FTAResults.BuildPrepare()
    FTAResults.ClearWholeState()

    local matchingItems = {}

    for _, group in ipairs(FTAData.groups) do
        if not group.collection then
            d("FTA: Broken data, source: " .. tostring(group.source) .. ", group: " .. tostring(group.name))
            return
        end
        for itemCategoryType, items in pairs(group.collection) do
            for _, item in ipairs(items) do
                matchingItems[FTAResults.GetItemKey(group, item)] = false
            end
        end
    end
    FTAResults.state._matchingItems = matchingItems

    FTAResults.RebuildInventoriesState()
end

FTAResults.refreshRequested = false
function FTAResults.RequestRefresh()
    if not FTAResults.refreshRequested then
        FTAResults.refreshRequested = true
        zo_callLater(function()
            FTAResults.callbacks.RefreshFull()
            FTAResults.refreshRequested = false
        end, FTAResults.refreshDelay)
    end
end

function FTAResults.DatamineFurnishings(from, lastItemId, skipIntervals)
    local counter = 0

    for itemId = from, lastItemId do
        for _, skipInterval in ipairs(skipIntervals) do
            if itemId >= skipInterval.from and itemId <= skipInterval.to then
                zo_callLater(function() FTAResults.DatamineFurnishings(skipInterval.to + 1, lastItemId, skipIntervals) end, FTAResults.chunkDelay)
                FTAResults.RequestRefresh()
                return
            end
        end

        local itemLink = string.format("|H0:item:%d:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", itemId)
        local itemType = GetItemLinkItemType(itemLink)
        if itemType == ITEMTYPE_FURNISHING then
            FTAResults.BuildResultItem(itemId, itemLink)
        end

        counter = counter + 1

        if counter >= FTAResults.chunkSize then
            zo_callLater(function() FTAResults.DatamineFurnishings(itemId + 1, lastItemId, skipIntervals) end, FTAResults.chunkDelay)
            FTAResults.RequestRefresh()
            return
        end
    end

    zo_callLater(function()
        d(string.format("[FTA]: Found %d furnishing items", FTAResults.sv.totalCount))
        FTAResults.sv.lastVersion = FTAResults.sv.nextVersion
        FTAResults.RegisterFurniture(true)
        FTAResults.DisplayUnmatched(FTAResults.state._matchingItems, "item")
        FTAResults.state._matchingItems = {}
    end, 2000)
end

function FTAResults.BuildResults()
    zo_callLater(function() FTAResults.DatamineFurnishings(FTAData.fromItemId, FTAData.lastItemId, FTAData.skipIntervalsFurnishing) end, FTAResults.chunkDelay)
    FTAResults.RequestRefresh()
end

function FTAResults.GetItemCollectionsInfo(name, unlocked, categoryType, collectibleId)
    local ici = {
        sourceNames = {},
        groupNames = {},
        tagNames = {},
        quality = nil,
        tradeBars = nil,
        no = nil,
        motif = nil,
        achievement = nil,
        info = nil,
        sortKey = nil,

        specificGroup = nil,
        specificQuality = nil,
        specificSortKey = nil,

        overridedUnlocked = nil,
    }

    local isUnobtainable = false

    local firstGroupIndex = 0
    local firstCategoryTypeIndex = 0
    local firstItemIndex = 0

    local specificGroupIndex = 0
    local specificCategoryTypeIndex = 0
    local specificItemIndex = 0
    local specificBasesort = nil

    for groupIndex, group in ipairs(FTAData.groups) do
        for itemCategoryType, items in pairs(group.collection) do
            if categoryType == nil or itemCategoryType == categoryType then
                for itemIndex, item in ipairs(items) do
                    if FTAResults.ShouldIncludeInResults(name, item, categoryType, collectibleId) then
                        FTAResults.state._matchingItems[FTAResults.GetItemKey(group, item)] = true
                        ici.sourceNames[#ici.sourceNames + 1] = FTAResults.AddToCollection(FTAResults.COLLECTION.SOURCES, group.source)
                        ici.groupNames[#ici.groupNames + 1] = FTAResults.AddToCollection(FTAResults.COLLECTION.GROUPS, group.name)

                        local gtags = group.tags or {}
                        for _, tag in ipairs(gtags) do
                            ici.tagNames[#ici.tagNames + 1] = FTAResults.AddToCollection(FTAResults.COLLECTION.TAGS, tag)
                        end

                        local tags = item.tags or {}
                        for _, tag in ipairs(tags) do
                            ici.tagNames[#ici.tagNames + 1] = FTAResults.AddToCollection(FTAResults.COLLECTION.TAGS, tag)
                        end

                        if group.source == FTAData.othersSource and group.name == FTAData.unobtainableGroup then
                            isUnobtainable = true
                            firstGroupIndex = groupIndex
                            firstCategoryTypeIndex = FTAData.categoryTypesMap[categoryType or 1] or 0 -- TODO: we don't have categoryTypesMap currently
                            firstItemIndex = itemIndex
                        end

                        if firstGroupIndex == 0 then firstGroupIndex = groupIndex end
                        if firstCategoryTypeIndex == 0 then firstCategoryTypeIndex = FTAData.categoryTypesMap[categoryType or 1] or 0 end
                        if firstItemIndex == 0 then firstItemIndex = itemIndex end

                        -- specific behavior
                        if group.specific then
                            if specificGroupIndex == 0 then specificGroupIndex = groupIndex end
                            if specificCategoryTypeIndex == 0 then specificCategoryTypeIndex = FTAData.categoryTypesMap[categoryType or 1] or 0 end
                            if specificItemIndex == 0 then specificItemIndex = itemIndex end
                            if ici.specificGroup == nil then ici.specificGroup = FTAResults.AddToCollection(FTAResults.COLLECTION.GROUPS, group.name) end
                            if ici.specificQuality == nil then ici.specificQuality = item.q end
                            if specificBasesort == nil then specificBasesort = group.basesort end
                        end


                        if ici.quality == nil then ici.quality = item.q end
                        if ici.tradeBars == nil then ici.tradeBars = item.bars end
                        if ici.no == nil then ici.no = item.no end
                        if ici.motif == nil then ici.motif = item.motif end
                        if ici.achievement == nil then ici.achievement = item.achievement end
                        if ici.info == nil then ici.info = item.info end
                    end
                end
            end
        end
    end

    local firstQuality = ici.quality or 9
    ici.sortKey = firstGroupIndex * 1e8 + firstQuality * 1e7 + firstCategoryTypeIndex * 1e5 + firstItemIndex

    if ici.specificGroup then
        local specificQuality = ici.specificQuality or 0
        if specificBasesort then specificQuality = 0 end
        ici.specificSortKey = specificGroupIndex * 1e8 + specificQuality * 1e7 + specificCategoryTypeIndex * 1e5 + specificItemIndex
    end

    if #ici.sourceNames == 0 then
        --[[ if
            categoryType == COLLECTIBLE_CATEGORY_TYPE_TRIBUTE_PATRON
            or categoryType == COLLECTIBLE_CATEGORY_TYPE_DLC
            or categoryType == COLLECTIBLE_CATEGORY_TYPE_ACCOUNT_UPGRADE
            or categoryType == COLLECTIBLE_CATEGORY_TYPE_HOUSE_BANK
        then
            ici.sourceNames[#ici.sourceNames + 1] = FTAResults.AddToCollection(FTAResults.COLLECTION.SOURCES, FTAData.specialSource)
        else ]]
            ici.sourceNames[#ici.sourceNames + 1] = FTAResults.AddToCollection(FTAResults.COLLECTION.SOURCES, FTAData.defaultSource)
        -- end
        
        ici.sortKey = 1e11

        if ici.specificGroup then
            ici.specificSortKey = 1e11
        end
    end

    -- override categorization of the unobtainable item
    if isUnobtainable then
        ici.sourceNames = {
            FTAResults.AddToCollection(FTAResults.COLLECTION.SOURCES, FTAData.othersSource),
        }
        ici.groupNames = {
            FTAResults.AddToCollection(FTAResults.COLLECTION.GROUPS, FTAData.unobtainableGroup),
        }
    end

    return ici
end

function FTAResults.BuildResultItem(itemId, itemLink)
    local furnitureDataId = GetItemLinkFurnitureDataId(itemLink)
    local rawName = GetItemLinkName(itemLink)
    -- local icon = GetItemLinkIcon(itemLink)
    local displayQuality = GetItemLinkDisplayQuality(itemLink)
    local categoryId, subcategoryId, furnitureTheme, limitType = GetFurnitureDataInfo(furnitureDataId)
    -- GetFurnitureDataCategoryInfo(furnitureDataId)
    local categoryName = GetFurnitureCategoryName(categoryId)
    local subcategoryName = GetFurnitureCategoryName(subcategoryId)

    local name = zo_strformat(SI_TOOLTIP_ITEM_NAME, rawName)
    if furnitureDataId == 10167 then
        name = name:gsub("\194\160", "") -- name:gsub("\194\160+$", "")
    end

    local unlocked = false -- TODO: this will have to be based on inventories and houses scans
    local categoryType = nil -- categoryId -- TODO: probably there are not any categoryTypes defined directly, and no need to split items by dynamic categories

    if subcategoryName == FTAData.craftingStationsSubcategory and FTAResults.IsAttunableCraftingStation(name) then
        subcategoryName = FTAData.attunableCraftingStationsCategory
    end

    local ici = FTAResults.GetItemCollectionsInfo(name, unlocked, categoryType, furnitureDataId)

    local isUncollected = unlocked == false
    if ici.overridedUnlocked ~= nil then
        isUncollected = ici.overridedUnlocked == false
    end
    local result = {
        -- ix = index,
        im = name,
        ii = itemId,
        id = furnitureDataId,
        iu = isUncollected,
        cn = FTAResults.AddToCollection(FTAResults.COLLECTION.CATEGORIES, categoryName),
        sn = FTAResults.AddToCollection(FTAResults.COLLECTION.SUBCATEGORIES, subcategoryName),
        tn = FTAResults.AddToCollection(FTAResults.COLLECTION.TYPES, GetString("SI_HOUSINGFURNISHINGLIMITTYPE", limitType)),
        sk = ici.sortKey,
        sns = ici.sourceNames,
        gns = ici.groupNames,
        tns = ici.tagNames,
        q = displayQuality,
        ft = furnitureTheme,
        inv = {},
    }

    if ici.quality ~= nil then result.q = ici.quality end
    if ici.tradeBars ~= nil then result.tb = ici.tradeBars end
    if ici.no ~= nil then result.no = ici.no end
    if ici.motif ~= nil then result.mo = ici.motif end
    if ici.achievement ~= nil then result.ach = ici.achievement end
    if ici.info ~= nil then result.info = ici.info end

    -- specific behavior
    if ici.specificSortKey ~= nil then result.ssk = ici.specificSortKey end
    if ici.specificGroup ~= nil then result.sg = ici.specificGroup end
    if ici.specificQuality ~= nil then result.sq = ici.specificQuality end

    if not isUncollected then
        FTAResults.sv.collectedCount = FTAResults.sv.collectedCount + 1
    end
    
    FTAResults.sv.totalCount = FTAResults.sv.totalCount + 1
    FTAResults.sv.results[FTAResults.sv.totalCount] = result
end

function FTAResults.Build(forced)
    if not FTAResults.sv.rebuildOnDemandOnly or forced == true then
        FTAResults.BuildPrepare()
        FTAResults.BuildResults()
    else
        FTAResults.RebuildState()
    end
end

function FTAResults.RecheckUncollectedItems()
    FTAResults.RegisterFurniture(true)
end

function FTAResults.RecheckUncollectedItem(collectibleId)
    -- TODO: rewrite or remove
    if not (FTAResults.sv and FTAResults.sv and type(FTAResults.sv.results) == "table") then
        return 0
    end

    local refreshed = 0
    for _, item in ipairs(FTAResults.sv.results) do
        if item and item.id == collectibleId and item.iu == true then
            local _, _, _, _, unlocked = GetCollectibleInfo(item.id)
            local isUncollected = unlocked == false

            item.iu = isUncollected

            refreshed = refreshed + 1
        elseif item and item.fr then
            for _, fragment in ipairs(item.fr) do
                if fragment.id == collectibleId then
                    fragment.unlocked = true
                    refreshed = refreshed + 1
                end
            end
        end
    end

    if refreshed > 0 then
        FTAResults.callbacks.RefreshFull()
    end

    return refreshed
end

function FTAResults.RecreateResult(rx)
    if rx == nil then
        return nil
    end

    local result = FTAResults.sv.results[rx] or {}

    local quality = result.q or 0
    if
        FTAResults.sv.selectedGroup ~= "All"
        and result ~= nil and SPFLibUtils.Contains(result.gns, FTAResults.state._groups[FTAResults.sv.selectedGroup]) -- this is not necessary probably already
        and result.sg == FTAResults.state._groups[FTAResults.sv.selectedGroup]
        and result.sq ~= nil
    then
        quality = result.sq
    end

    local sources = {}
    for i = 1, #result.sns do
        sources[#sources + 1] = FTAResults.sv.sources[result.sns[i]]
    end

    local groups = {}
    for i = 1, #result.gns do
        groups[#groups + 1] = FTAResults.sv.groups[result.gns[i]]
    end

    local tags = {}
    for i = 1, #result.tns do
        tags[#tags + 1] = FTAResults.sv.tags[result.tns[i]]
    end

    local inventories = {}
    for _, inventory in ipairs(FTAResults.GetInventories()) do
        local count = result.inv[inventory.id] or 0
        if count > 0 then
            inventories[#inventories + 1] = { id = inventory.id, name = inventory.name, count = count }
        end
    end

    -- TODO: fallbacks will not be probably needed already, because reindexing should be fixed now
    local resultFull = {
        itemId = result.ii,
        furnishingId = result.id,
        -- TODO: if the colorize will work, add some q to all the data
        furnishingName = SPFLibUtils.ColorizeByQuality(string.format("%s", result.im), 7 - quality + 1),
        categoryName = FTAResults.sv.categories[result.cn or 0] or "",
        subcategoryName = FTAResults.sv.subcategories[result.sn or 0] or "",
        typeName = FTAResults.sv.types[result.tn or 0] or "",

        isUncollected = result.iu,

        quality = SPFLibUtils.ColorizeByQuality(GetString("SI_ITEMQUALITY", quality), 7 - quality + 1),
        theme = GetString("SI_FURNITURETHEMETYPE", result.ft),
        
        tradeBars = FTAResults.GetItemTradeBars(result),
        motif = result.mo,
        no = result.no,
        achievement = result.ach,
        info = result.info,
        sources = table.concat(sources, ", "),
        groups = table.concat(groups, ", "),
        tags = table.concat(tags, ", "),
        inventories = inventories,
    }
    return resultFull
end

function FTAResults.GetResultCompareValues(rx)
    local result = FTAResults.sv.results[rx]

    local im = ""
    local id = 0
    local sk = 0
    if result ~= nil then im = result.im end
    if result ~= nil then id = result.id end
    if result ~= nil then sk = result.sk end

    if
        FTAResults.sv.selectedGroup ~= "All"
        and result ~= nil and SPFLibUtils.Contains(result.gns, FTAResults.state._groups[FTAResults.sv.selectedGroup]) -- this is not necessary probably already
    then
        if result.sg ~= nil and result.sg == FTAResults.state._groups[FTAResults.sv.selectedGroup] and result.ssk ~= nil then
            sk = result.ssk
        end

        sk = sk % 1e8 -- ignore group part of the sortKey
    end

    return im, id, sk
end

function FTAResults.SortRows(rows)
    if FTAResults.OrderBy[FTAResults.sv.orderedBy] == FTAResults.OrderByName then
        table.sort(rows, function(a, b)
            local an, ad = FTAResults.GetResultCompareValues(a)
            local bn, bd = FTAResults.GetResultCompareValues(b)

            if an == bn then
                return ad < bd
            end
            return an < bn
        end)
    elseif FTAResults.OrderBy[FTAResults.sv.orderedBy] == FTAResults.OrderById then
        table.sort(rows, function(a, b)
            local an, ad = FTAResults.GetResultCompareValues(a)
            local bn, bd = FTAResults.GetResultCompareValues(b)

            if ad == bd then
                return an < bn
            end
            return ad < bd
        end)
    elseif FTAResults.OrderBy[FTAResults.sv.orderedBy] == FTAResults.OrderByCollection then
        table.sort(rows, function(a, b)
            local an, _, ask = FTAResults.GetResultCompareValues(a)
            local bn, _, bsk = FTAResults.GetResultCompareValues(b)

            if ask == bsk then
                return an < bn
            end
            return ask < bsk
        end)
    end
end

function FTAResults.BuildAllRows()
    local rows = {}
    local rowix = 0
    for rx, result in pairs(FTAResults.sv.results) do
        if result ~= nil and FTAResults.ShouldIncludeRowInView(result) then
            rowix = rowix + 1
            rows[rowix] = rx
        end
    end

    FTAResults.SortRows(rows)

    return rows
end

function FTAResults.GetAllVisibleRows()
    local rows = FTAResults.BuildAllRows()
    local filterText = FTAResults.state.searchFilter -- SPFLibUtils.Lower(FTAResults.state.searchFilter)
    if filterText == "" then
        return rows
    end

    local filtered = {}
    local fx = 0
    for _, row in ipairs(rows) do
        local result = FTAResults.sv.results[row]

        local haystack = result.im
            -- TODO: this has performance issue for thousands items
            -- SPFLibUtils.Lower(result.im) .. " " ..
            -- SPFLibUtils.Lower(FTAResults.sv.categories[result.cn])

        if string.find(haystack, filterText, 1, true) then
            fx = fx + 1
            filtered[fx] = row
        end
    end
    return filtered
end

function FTAResults.CalculateVisibleRows()
    local rows = FTAResults.GetAllVisibleRows()
    local pageSize = math.max(1, tonumber(FTAResults.state.matchingPageSize) or 50)
    local totalPages = math.max(1, math.ceil(#rows / pageSize))
    local page = tonumber(FTAResults.state.matchingPage) or 1
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

    FTAResults.state.matchingRows = rows
    FTAResults.state.matchingPageRows = pageRows
    FTAResults.state.matchingPage = page
    FTAResults.state.matchingTotalPages = totalPages
end

function FTAResults.GetSelectedRow()
    local selectedRow = FTAResults.state.matchingSelectedRow
    if not selectedRow or not FTAResults.state.matchingPageRows then return nil end
    for _, row in ipairs(FTAResults.state.matchingPageRows) do
        if row == selectedRow then
            return row
        end
    end
    return nil
end

function FTAResults.DebugCounts()
    d("FTA Results: "..tostring(#FTAResults.sv.results))
    d("FTA Categories: "..tostring(#FTAResults.sv.categories))
    d("FTA SubCategories: "..tostring(#FTAResults.sv.subcategories))
    d("FTA Sources: "..tostring(#FTAResults.sv.sources))
    d("FTA Groups: "..tostring(#FTAResults.sv.groups))
    d("FTA Tags: "..tostring(#FTAResults.sv.tags))
    d("FTA Types: "..tostring(#FTAResults.sv.types))
end

function FTAResults.DebugResult(rx)
    local result = FTAResults.sv.results[rx]
    local message = {}
    table.insert(message, "rx: "..tostring(rx))
    for key, value in pairs(result or {}) do
        table.insert(message, key..": "..tostring(value))
    end
    d("FTA Result: "..table.concat(message, " ; "))
end

function FTAResults.GetItemTradeBars(result)
    if result and result.tb and result.iu == true then
        return result.tb
    end
    return 0
end

function FTAResults.GetStats()
    local allMatchingRows = FTAResults.state.matchingRows
    local matching = #allMatchingRows
    local collectedTotal = FTAResults.sv.collectedCount
    local total = FTAResults.sv.totalCount
    local page = FTAResults.state.matchingPage
    local totalPages = FTAResults.state.matchingTotalPages

    local collectedMatching = 0
    local neededTradeBars = 0

    for _, row in ipairs(allMatchingRows) do
        local result = FTAResults.sv.results[row]

        if result and result.iu == false then
            collectedMatching = collectedMatching + 1
        end

        neededTradeBars = neededTradeBars + FTAResults.GetItemTradeBars(result)
    end

    return matching, total, collectedMatching, collectedTotal, page, totalPages, neededTradeBars
end

local minute = 60
local hour = minute * minute
local day = hour * 24
local week = day * 7
local month = day * 30

function FTAResults.GetLevelTime(levelTimeValue, levelTimeUnit)
    local freshUnitMultiplier = 0
    if levelTimeUnit == FTAResults.TimeUnitMinute then
        freshUnitMultiplier = minute
    elseif levelTimeUnit == FTAResults.TimeUnitHour then
        freshUnitMultiplier = hour
    elseif levelTimeUnit == FTAResults.TimeUnitDay then
        freshUnitMultiplier = day
    elseif levelTimeUnit == FTAResults.TimeUnitWeek then
        freshUnitMultiplier = week
    elseif levelTimeUnit == FTAResults.TimeUnitMonth then
        freshUnitMultiplier = month
    end

    local levelTime = levelTimeValue * freshUnitMultiplier
    return levelTime
end

function FTAResults.ShouldRefreshInventory(inventoryId, forced)
    if forced == true then
        return true
    end

    local now = GetTimeStamp()
    local elapsed = now - (FTAResults.sv.inventoriesLastCheck[inventoryId] or now)

    local freshLevelTime = FTAResults.GetLevelTime(FTAResults.sv.freshLevelTimeValue, FTAResults.sv.freshLevelTimeUnit)

    if elapsed == 0 or elapsed > freshLevelTime then
        return true
    end

    return false
end

function FTAResults.UpdateResultsInventories(inventoryId, inventory)
    for _, item in ipairs(FTAResults.sv.results) do
        local count = inventory[item.id] or 0
        item.inv[inventoryId] = count
        if item.iu == true then
            item.iu = count == 0
            -- TODO: moving items between inventories, placing/unplacing them in houses, destroying them or selling them will cause inconsistent data
        end
    end

    FTAResults.sv.inventoriesLastCheck[inventoryId] = GetTimeStamp()
    FTAResults.RequestRefresh()
end

function FTAResults.UpdateCollectedCount()
    local collectedCount = 0
    for _, item in ipairs(FTAResults.sv.results) do
        if item.iu == false then
            collectedCount = collectedCount + 1
        end
    end
    FTAResults.sv.collectedCount = collectedCount
    FTAResults.RequestRefresh()
end

function FTAResults.ResetCollectedStatus()
    for _, item in ipairs(FTAResults.sv.results) do
        item.inv = {}
        item.iu = true
    end
    FTAResults.sv.collectedCount = 0
    FTAResults.RequestRefresh()
end

function FTAResults.ProcessBagSlot(bagId, slotIndex, inventory)
    -- ZO_SharedInventoryManager:CreateOrUpdateSlotData is source
    local isPlaceableFurniture = IsItemPlaceableFurniture(bagId, slotIndex)
    if isPlaceableFurniture then
        local icon, stackCount, sellPrice, meetsUsageRequirement, locked, equipType, _, functionalQuality, displayQuality = GetItemInfo(bagId, slotIndex)
        -- local rawName = GetItemName(bagId, slotIndex)
        local furnitureDataId = GetItemFurnitureDataId(bagId, slotIndex)

        inventory[furnitureDataId] = stackCount
    end
end

FTAResults.refreshBatchSize = 100
FTAResults.refreshDelayMs = 500

local function ProcessBagSlotsAsync(bagId, inventory, processSlot, batchSize, delayMs, onDone)
    local iterator, state, lastSlot = ZO_IterateBagSlots(bagId)

    local function ProcessBatch()
        local processed = 0

        while processed < batchSize do
            local slotIndex
            lastSlot, slotIndex = iterator(state, lastSlot), nil

            slotIndex = lastSlot

            if slotIndex == nil then
                if onDone then onDone() end
                return
            end

            processSlot(bagId, slotIndex, inventory)
            processed = processed + 1
        end

        zo_callLater(ProcessBatch, delayMs)
    end

    ProcessBatch()
end

function FTAResults.RegisterFurnitureInBag(bagId, forced, houseDepended, onDone)
    -- d("Furniture in bag: " .. tostring(FTAData.BagNames[bagId]) .. " (" .. bagId .. ")")

    if not FTAResults.ShouldRefreshInventory(bagId, forced) then
        if onDone then onDone() end
        return
    end

    if houseDepended == true then
        local houseId = GetCurrentZoneHouseId()
        local isOwner = IsOwnerOfCurrentHouse()
        if houseId == 0 or not isOwner then
            if onDone then onDone() end
            return
        end
    end

    local inventory = {}

    ProcessBagSlotsAsync(
        bagId,
        inventory,
        FTAResults.ProcessBagSlot,
        FTAResults.refreshBatchSize,
        FTAResults.refreshDelayMs,
        function()
            FTAResults.UpdateResultsInventories(bagId, inventory)
            if onDone then onDone() end
        end
    )
end

function FTAResults.ProcessPlacedFurnitureId(furnitureId, inventory)
    local rawName, icon, furnitureDataId = GetPlacedHousingFurnitureInfo(furnitureId)
    -- local displayQuality = GetPlacedHousingFurnitureDisplayQuality(furnitureId)

    if inventory[furnitureDataId] == nil then
        inventory[furnitureDataId] = 0
    end
    inventory[furnitureDataId] = inventory[furnitureDataId] + 1
end

local function ProcessFurnitureAsync(inventory, processFurniture, batchSize, delayMs, onDone)
    batchSize = batchSize or 10
    delayMs = delayMs or 20

    local lastFurnitureId = nil

    local function ProcessBatch()
        local processed = 0

        while processed < batchSize do
            local furnitureId = GetNextPlacedHousingFurnitureId(lastFurnitureId)

            if not furnitureId then
                if onDone then
                    onDone()
                end
                return
            end

            processFurniture(furnitureId, inventory)

            lastFurnitureId = furnitureId
            processed = processed + 1
        end

        zo_callLater(ProcessBatch, delayMs)
    end

    ProcessBatch()
end

function FTAResults.RegisterFurnitureInCurrentHouse(forced, onDone)
    local houseId = GetCurrentZoneHouseId()
    local isOwner = IsOwnerOfCurrentHouse()
    -- d("Furniture in current house: " .. tostring(houseId) .. ", Owner: " .. tostring(isOwner))
    -- if GetCurrentZoneHouseId() ~= 0 then
    if houseId == 0 or not isOwner then
        if onDone then onDone() end
        return
    end

    if not FTAResults.ShouldRefreshInventory(houseId + FTAData.houseIdShift, forced) then
        if onDone then onDone() end
        return
    end

    local inventory = {}

    ProcessFurnitureAsync(
        inventory,
        FTAResults.ProcessPlacedFurnitureId,
        FTAResults.refreshBatchSize,
        FTAResults.refreshDelayMs,
        function()
            FTAResults.UpdateResultsInventories(houseId + FTAData.houseIdShift, inventory)
            if onDone then onDone() end
        end
    )
end

local function RunAsyncQueue(tasks, onAllDone)
    local index = 1

    local function RunNext()
        local task = tasks[index]

        if not task then
            if onAllDone then
                onAllDone()
            end
            return
        end

        index = index + 1

        task(function()
            zo_callLater(RunNext, 100)
        end)
    end

    RunNext()
end

FTAResults.RefreshDelayMs = 1000

FTAResults.RefreshManager = {
    running = false,
    dirty = false,
    scheduled = false,
}

function FTAResults.RunStateRefreshIfNeeded()
    if FTAResults.RefreshManager.running then
        return
    end

    if not FTAResults.RefreshManager.dirty then
        return
    end

    FTAResults.RefreshManager.running = true
    FTAResults.RefreshManager.dirty = false

    FTAResults.RegisterFurniture(false, function()
        FTAResults.RefreshManager.running = false

        if FTAResults.RefreshManager.dirty then
            FTAResults.RequestStateRefresh()
        end
    end)
end

function FTAResults.RequestStateRefresh()
    FTAResults.RefreshManager.dirty = true

    if FTAResults.RefreshManager.running then
        return
    end

    if FTAResults.RefreshManager.scheduled then
        return
    end

    FTAResults.RefreshManager.scheduled = true

    zo_callLater(function()
        FTAResults.RefreshManager.scheduled = false
        FTAResults.RunStateRefreshIfNeeded()
    end, FTAResults.RefreshDelayMs)
end

function FTAResults.InvalidateCurrentHouseInventory()
    local houseId = GetCurrentZoneHouseId()
    local isOwner = IsOwnerOfCurrentHouse()
    if houseId == 0 or not isOwner then
        return
    end
    local inventoryId = houseId + FTAData.houseIdShift
    FTAResults.sv.inventoriesLastCheck[inventoryId] = nil
end

function FTAResults.InvalidateInventory(inventoryId)
    FTAResults.sv.inventoriesLastCheck[inventoryId] = nil
end

function FTAResults.RegisterFurniture(forced, onDone)
    if not FTAResults.sv.enable then
        return
    end

    if #FTAResults.sv.results == 0 then
        return
    end

    if forced == true then
        FTAResults.sv.inventoriesLastCheck = {}
        FTAResults.ResetCollectedStatus()
    end

    local tasks = {}

    tasks[#tasks + 1] = function(onDone)
        FTAResults.RegisterFurnitureInCurrentHouse(forced, onDone)
    end

    for bagId = BAG_HOUSE_BANK_ONE, BAG_HOUSE_BANK_TEN do
        tasks[#tasks + 1] = function(onDone)
            FTAResults.RegisterFurnitureInBag(bagId, forced, true, onDone)
        end
    end

    tasks[#tasks + 1] = function(onDone)
        FTAResults.RegisterFurnitureInBag(BAG_FURNITURE_VAULT, forced, true, onDone)
    end

    tasks[#tasks + 1] = function(onDone)
        FTAResults.RegisterFurnitureInBag(BAG_BACKPACK, forced, false, onDone)
    end

    tasks[#tasks + 1] = function(onDone)
        FTAResults.RegisterFurnitureInBag(BAG_BANK, forced, false, onDone)
    end

    RunAsyncQueue(
        tasks,
        function()
            FTAResults.UpdateCollectedCount()
            d("[FTA]: Collected status refreshed")
            if onDone then onDone() end
        end
    )
end

function FTAResults.GetInventoryStatusColor(inventoryId)
    local now = GetTimeStamp()
    local elapsed = now - (FTAResults.sv.inventoriesLastCheck[inventoryId] or now)

    if elapsed == 0 then
        return nil
    end

    local freshLevelTime = FTAResults.GetLevelTime(FTAResults.sv.freshLevelTimeValue, FTAResults.sv.freshLevelTimeUnit)
    local recentLevelTime = FTAResults.GetLevelTime(FTAResults.sv.recentLevelTimeValue, FTAResults.sv.recentLevelTimeUnit)

    if elapsed <= freshLevelTime then
        return ZO_ColorDef:New("2DC50E") -- fine
    elseif elapsed <= recentLevelTime then
        return ZO_ColorDef:New("CCAA1A") -- legendary
    end

    return ZO_ColorDef:New("E58B27") -- apex
end

function FTAResults.GetInventories()
    local primaryResidance = GetHousingPrimaryHouse()
    local inventories = {}

    inventories[#inventories + 1] = { id = BAG_BACKPACK, name = FTAData.BagNames[BAG_BACKPACK], color = FTAResults.GetInventoryStatusColor(BAG_BACKPACK) }
    inventories[#inventories + 1] = { id = BAG_BANK, name = FTAData.BagNames[BAG_BANK], color = FTAResults.GetInventoryStatusColor(BAG_BANK) }
    inventories[#inventories + 1] = { id = BAG_FURNITURE_VAULT, name = FTAData.BagNames[BAG_FURNITURE_VAULT], color = FTAResults.GetInventoryStatusColor(BAG_FURNITURE_VAULT), houseId = primaryResidance }

    for bagId = BAG_HOUSE_BANK_ONE, BAG_HOUSE_BANK_TEN do
        local name = FTAData.BagNames[bagId]
        local color = FTAResults.GetInventoryStatusColor(bagId)
        if name ~= "" then
            inventories[#inventories + 1] = { id = bagId, name = name, color = color, houseId = primaryResidance }
        end
    end

    for _, house in ipairs(FTAData.houses) do
        local collectibleId = GetCollectibleIdForHouse(house.no)
        local name, _, _, _, unlocked = GetCollectibleInfo(collectibleId)
        local color = FTAResults.GetInventoryStatusColor(house.no + FTAData.houseIdShift)

        if unlocked then
            inventories[#inventories + 1] = { id = house.no + FTAData.houseIdShift, name = name, color = color, houseId = house.no }
        end
    end

    return inventories
end
