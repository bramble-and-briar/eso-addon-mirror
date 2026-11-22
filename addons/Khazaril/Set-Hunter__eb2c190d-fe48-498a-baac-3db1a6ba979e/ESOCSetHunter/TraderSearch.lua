-- Set Hunter "Search my list": searches the guild trader you're at for the sets you still need.
-- One press is one search, using the game's own name search and cooldown. Nothing repeats by itself,
-- and nothing is bought.
-- Exact trait: pieces you still need in the trait you chose, even if the Sticker Book already has them.
-- Sticker Book: pieces missing from the Sticker Book, in any trait.
-- Trader filter: while any kind is switched on in Settings (Sticker Book gear, motifs, furniture
-- plans, recipes, collectibles, furnishings), every search shows only what you don't have of those kinds.

local SH = ESOC_SetHunter
local S = {}
SH.TraderSearch = S

local MATCH_TIMEOUT = 4000
local STOP_WORDS = { ["of"] = true, ["the"] = true, ["a"] = true, ["an"] = true }

local searched = {}  -- [setId] = true once searched at this trader
local pending       -- the search waiting on the game's name match
local token = 0
local descriptors = {}
local armedTraits   -- trait filter for the next search only
local titleChanged = false  -- the results title is showing the filter's count

local filterPaused = false  -- turned off with the button, until the next trader
local KIND_KEYS = { "traderSticker", "traderMotifs", "traderFurniture", "traderRecipes", "traderCollectibles", "traderFurnishings" }

local MODE_NAMES = { exact = "Exact trait", sticker = "Sticker Book" }
local NEXT_MODE = { exact = "sticker", sticker = "exact" }

function S.Mode()
    local mode = SH.internal.opts.traderSearchMode
    return MODE_NAMES[mode] and mode or "exact"
end

function S.ModeName(mode)
    return MODE_NAMES[mode or S.Mode()]
end

local function alert(text) pcall(ZO_Alert, UI_ALERT_CATEGORY_ALERT, nil, "Set Hunter: " .. text) end

local function kindOn(name) return SH.internal.opts[name] == true end

function S.AnyKindOn()
    return kindOn("traderSticker") or kindOn("traderMotifs") or kindOn("traderFurniture") or kindOn("traderRecipes")
        or kindOn("traderCollectibles") or kindOn("traderFurnishings")
end

function S.Filtering()
    return S.AnyKindOn() and not filterPaused
end

-- 2.11 switched five kinds on by default without filtering until a separate mode was chosen.
-- Those untouched defaults must not start hiding listings now. Choices someone made are kept.
function S.MigrateFilter(opts)
    if opts.traderFilterSetup then return end
    opts.traderFilterSetup = true
    if opts.traderSearchMode == "new" then
        opts.traderSearchMode = "exact"
    elseif opts.traderSticker and opts.traderMotifs and opts.traderFurniture and opts.traderRecipes
        and opts.traderCollectibles and not opts.traderFurnishings then
        for _, key in ipairs(KIND_KEYS) do opts[key] = false end
    end
end

-- Furniture has no collection, so "have" means a copy in your bags, bank, house storage or
-- furniture vault. The game can't see furniture placed in your houses from a trader.
local function holdsCopy(link)
    local bag, bank, craftBag, houseBanks, vault = GetItemLinkStacks(link)
    return (bag or 0) + (bank or 0) + (craftBag or 0) + (houseBanks or 0) + (vault or 0) > 0
end

-- The same test the game's tooltip uses for "already in your collection".
local function collectibleIsNew(collectibleId)
    if IsCollectibleOwnedByDefId(collectibleId) then return false end
    if GetCollectibleCategoryType(collectibleId) == COLLECTIBLE_CATEGORY_TYPE_COMBINATION_FRAGMENT
        and not CanCombinationFragmentBeUnlocked(collectibleId) then
        return false
    end
    return true
end

-- Uses the same checks as the game's own "Not Collected" and "Not Learned" icons.
-- This is a strict filter: anything that can't be confirmed as missing is hidden.
function S.IsUncollected(link)
    local ok, result = pcall(function()
        local collectibleId = GetItemLinkContainerCollectibleId(link)
        if collectibleId and collectibleId > 0 then
            return kindOn("traderCollectibles") and collectibleIsNew(collectibleId)
        end
        local itemType = GetItemLinkItemType(link)
        if itemType == ITEMTYPE_WEAPON or itemType == ITEMTYPE_ARMOR or itemType == ITEMTYPE_JEWELRY then
            return kindOn("traderSticker") and IsItemLinkLockedSetPiece(link)
        elseif itemType == ITEMTYPE_RACIAL_STYLE_MOTIF then
            return kindOn("traderMotifs") and CanItemLinkBeUsedToLearn(link)
        elseif itemType == ITEMTYPE_RECIPE then
            local kind = IsItemLinkFurnitureRecipe(link) and "traderFurniture" or "traderRecipes"
            return kindOn(kind) and CanItemLinkBeUsedToLearn(link)
        elseif itemType == ITEMTYPE_FURNISHING then
            return kindOn("traderFurnishings") and not holdsCopy(link)
        end
        return false
    end)
    if not ok then
        S.checkError = tostring(result)
        return false
    end
    return result == true
end

-- Narrows the search on the server so fewer pages are full of things you can't use.
local function applyCollectFilters(search)
    local sticker, motifs, furniture, recipes = kindOn("traderSticker"), kindOn("traderMotifs"), kindOn("traderFurniture"), kindOn("traderRecipes")
    local collectibles, furnishings = kindOn("traderCollectibles"), kindOn("traderFurnishings")
    if furniture and not (sticker or motifs or recipes or collectibles or furnishings) then
        local plans = {
            SPECIALIZED_ITEMTYPE_RECIPE_BLACKSMITHING_DIAGRAM_FURNISHING, SPECIALIZED_ITEMTYPE_RECIPE_CLOTHIER_PATTERN_FURNISHING,
            SPECIALIZED_ITEMTYPE_RECIPE_ENCHANTING_SCHEMATIC_FURNISHING, SPECIALIZED_ITEMTYPE_RECIPE_ALCHEMY_FORMULA_FURNISHING,
            SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_DESIGN_FURNISHING, SPECIALIZED_ITEMTYPE_RECIPE_WOODWORKING_BLUEPRINT_FURNISHING,
            SPECIALIZED_ITEMTYPE_RECIPE_JEWELRYCRAFTING_SKETCH_FURNISHING,
        }
        if #plans <= GetMaxTradingHouseFilterExactTerms(TRADING_HOUSE_FILTER_TYPE_SPECIALIZED_ITEM) then
            search:SetFilter(TRADING_HOUSE_FILTER_TYPE_SPECIALIZED_ITEM, plans)
            return
        end
    end
    local types = {}
    if sticker then
        types[#types + 1] = ITEMTYPE_WEAPON
        types[#types + 1] = ITEMTYPE_ARMOR
        types[#types + 1] = ITEMTYPE_JEWELRY
    end
    if motifs then types[#types + 1] = ITEMTYPE_RACIAL_STYLE_MOTIF end
    if furniture or recipes then types[#types + 1] = ITEMTYPE_RECIPE end
    if collectibles then
        types[#types + 1] = ITEMTYPE_CONTAINER
        types[#types + 1] = ITEMTYPE_CONTAINER_STACKABLE
        types[#types + 1] = ITEMTYPE_COLLECTIBLE
    end
    if furnishings then types[#types + 1] = ITEMTYPE_FURNISHING end
    if #types > 0 and #types <= GetMaxTradingHouseFilterExactTerms(TRADING_HOUSE_FILTER_TYPE_ITEM) then
        search:SetFilter(TRADING_HOUSE_FILTER_TYPE_ITEM, types)
    end
    if sticker and not (motifs or furniture or recipes or collectibles or furnishings) then
        search:SetFilter(TRADING_HOUSE_FILTER_TYPE_GAMEPLAY_ACTOR_CATEGORY, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
    end
end

local function isSearching()
    local search = TRADING_HOUSE_SEARCH
    return TRADING_HOUSE_SEARCH_STATE_WAITING ~= nil and search.GetSearchState ~= nil
        and search:GetSearchState() == TRADING_HOUSE_SEARCH_STATE_WAITING
end

-- Removes everything except what you asked for from the page the game just built.
function S.FilterResults(results)
    S.checkError = nil
    local scrollData = ZO_ScrollList_GetDataList(results.list)
    local total = #scrollData
    for index = #scrollData, 1, -1 do
        local data = scrollData[index].data
        if data.isGuildSpecificItem or not S.IsUncollected(data.itemLink) then
            table.remove(scrollData, index)
            if not data.isGuildSpecificItem then
                results.searchResultItemDataList[data.slotIndex] = nil
                local preview = results.previewListEntries
                for previewIndex = #preview, 1, -1 do
                    if preview[previewIndex] == data.slotIndex then table.remove(preview, previewIndex) end
                end
            end
        end
    end
    if TRADING_HOUSE_PREVIEW_GAMEPAD_SCENE and TRADING_HOUSE_PREVIEW_GAMEPAD_SCENE:IsShowing() then
        results:UpdatePreviewForChangedData()
    end
    titleChanged = true
    results:SetTitle(total > 0 and ("Not collected: " .. #scrollData .. " of " .. total) or "Not collected")
    if S.checkError then alert("couldn't check some listings, so they're hidden") end
    if #scrollData == 0 and total > 0 then
        if TRADING_HOUSE_SEARCH:HasNextPage() then
            results:SetEmptyText("Nothing new on this page. Press L3 for the next page.")
        else
            results:SetEmptyText("Nothing new on the last page. Press L3 to start over.")
        end
    end
end

local function restoreTitle(results)
    if not titleChanged then return end
    titleChanged = false
    results:SetTitle(GetString(SI_GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS_TITLE))
end

-- Only an untouched "All Items" search gets narrowed. A category you picked yourself is kept.
local function isAllItemsSearch(search)
    local ok, key = pcall(function() return search.features.searchCategoryFeature:GetCategoryParams():GetKey() end)
    return ok and key == "AllItems"
end

local function refreshKeys()
    for _, descriptor in ipairs(descriptors) do
        pcall(function() KEYBIND_STRIP:UpdateKeybindButtonGroup(descriptor) end)
    end
end

local function splitWords(text)
    local words = {}
    for word in string.gmatch(text, "%S+") do words[#words + 1] = word end
    return words
end

local function hasPhrase(name, phrase)
    return string.find(" " .. string.lower(name) .. " ", " " .. string.lower(phrase) .. " ", 1, true) ~= nil
end

-- The longest run of words shared by every piece name, such as "Noble Duelist".
function S.CommonName(names)
    if #names == 0 then return nil end
    if #names == 1 then return names[1] end
    local words = splitWords(names[1])
    for length = #words, 1, -1 do
        for first = 1, #words - length + 1 do
            local last = first + length - 1
            local phrase = table.concat(words, " ", first, last)
            local inAll = true
            for _, name in ipairs(names) do
                if not hasPhrase(name, phrase) then
                    inAll = false
                    break
                end
            end
            if inAll then
                while first <= last and STOP_WORDS[string.lower(words[first])] do first = first + 1 end
                while last >= first and STOP_WORDS[string.lower(words[last])] do last = last - 1 end
                if last >= first then
                    local trimmed = table.concat(words, " ", first, last)
                    if #trimmed >= 4 then return trimmed end
                end
            end
        end
    end
    return nil
end

-- Dungeon, trial, arena, monster, mythic and Archive gear can never be listed at a trader.
-- Uses the Sticker Book's top category and the set type. Anything unclear stays in the search.
local NEVER_LISTED = { "dungeon", "trial", "arena", "monster", "mythic", "archive" }

function S.CanBeListed(setId)
    local ok, listable = pcall(function()
        local setType = GetItemSetType(setId)
        if setType ~= nil and (setType == ITEM_SET_TYPE_MONSTER or setType == ITEM_SET_TYPE_WEAPON) then return false end
        local categoryId = GetItemSetCollectionCategoryId(setId)
        if not categoryId or categoryId == 0 then return true end
        local parentId = GetItemSetCollectionCategoryParentId(categoryId)
        local topId = (parentId and parentId ~= 0) and parentId or categoryId
        local text = string.lower(GetItemSetCollectionCategoryName(topId) or "")
        for _, word in ipairs(NEVER_LISTED) do
            if string.find(text, word, 1, true) then return false end
        end
        return true
    end)
    return not ok or listable ~= false
end

-- One group per set that still has pieces to find for the current mode, in name order.
function S.Groups()
    local I = SH.internal
    local mode = S.Mode()
    local groups = {}
    for setId, goal in pairs(I.ActiveSets()) do
        local listable = S.CanBeListed(setId)
        local names, seen, traits, seenTraits, anyTrait = {}, {}, {}, {}, false
        for pieceId, want in pairs(goal.wants) do
            local state = I.PieceState(setId, pieceId, want)
            -- "need" is the only state with no copy to bind and no Sticker Book unlock
            local wanted
            if mode == "sticker" then wanted = state == "need" else wanted = state ~= "done" and state ~= "bind" end
            if listable and wanted and want.name then
                if not seen[want.name] then
                    seen[want.name] = true
                    names[#names + 1] = want.name
                end
                local trait = I.TargetTrait(want)
                if not trait or trait == 0 then
                    anyTrait = true
                elseif not seenTraits[trait] then
                    seenTraits[trait] = true
                    traits[#traits + 1] = trait
                end
            end
        end
        if #names > 0 then
            table.sort(names)
            table.sort(traits)
            groups[#groups + 1] = {
                setId = setId, setName = zo_strformat("<<t:1>>", GetItemSetName(setId)), names = names,
                traits = (mode == "exact" and not anyTrait) and traits or nil,
            }
        end
    end
    table.sort(groups, function(a, b) return a.setName < b.setName end)
    return groups
end

function S.SearchTexts(group)
    local texts = {}
    local common = S.CommonName(group.names)
    if common then texts[1] = common end
    if group.setName ~= "" and group.setName ~= common then texts[#texts + 1] = group.setName end
    return texts
end

function S.ButtonName()
    if S.Filtering() then
        if GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS:IsActive() then
            return TRADING_HOUSE_SEARCH:HasNextPage() and "Next page" or "Start over"
        end
        return "Show what I don't have"
    end
    local groups = S.Groups()
    if #groups == 0 then return "Search list: nothing to search" end
    local done = 0
    for _, group in ipairs(groups) do
        if searched[group.setId] then done = done + 1 end
    end
    if #groups > 0 and done == #groups then return "List searched, start over" end
    local label = S.Mode() == "sticker" and "Search list: Sticker Book (" or "Search list: exact trait ("
    return label .. (done + 1) .. " of " .. #groups .. ")"
end

local function finish(message)
    pending = nil
    token = token + 1
    if message then alert(message) end
    refreshKeys()
end

local function startSearch()
    local group = pending.group
    finish(nil)
    local count = #group.names
    local traitText = "any trait"
    if group.traits then
        local names = {}
        for _, trait in ipairs(group.traits) do names[#names + 1] = SH.internal.TraitName(trait) end
        traitText = table.concat(names, ", ")
    end
    armedTraits = group.traits
    alert("searching for " .. group.setName .. ", " .. traitText .. " (" .. count .. (count == 1 and " piece)" or " pieces)"))
    TRADING_HOUSE_GAMEPAD:EnterBrowseResults()
end

local function tryNextText()
    local feature = GAMEPAD_TRADING_HOUSE_BROWSE:GetNameSearchFeature()
    while pending do
        pending.index = pending.index + 1
        local text = pending.texts[pending.index]
        if not text then
            return finish("no items match " .. pending.group.setName)
        end
        feature:SetSearchText(text)
        pcall(function() GAMEPAD_TRADING_HOUSE_BROWSE:RefreshVisible() end)
        if feature:IsSearchTextLongEnough() then
            if feature:HasPendingNameMatch() then
                local current = token
                zo_callLater(function()
                    if pending and token == current then finish("the search didn't start, try again") end
                end, MATCH_TIMEOUT)
                return
            end
            if feature:HasMatchedAtLeastOneName() then return startSearch() end
        end
    end
end

function S.OnNameMatch()
    if not pending then return end
    token = token + 1
    local feature = GAMEPAD_TRADING_HOUSE_BROWSE:GetNameSearchFeature()
    if feature:HasMatchedAtLeastOneName() then
        startSearch()
    else
        tryNextText()
    end
end

-- One press, one page.
local function browseNext()
    if isSearching() then return false end
    local results = GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS
    if results:IsActive() and TRADING_HOUSE_SEARCH:HasNextPage() then
        TRADING_HOUSE_SEARCH:SearchNextPage()
    else
        if results:IsActive() then TRADING_HOUSE_GAMEPAD:DeactivateBrowseResults() end
        GAMEPAD_TRADING_HOUSE_BROWSE:ResetSearch()
        TRADING_HOUSE_GAMEPAD:EnterBrowseResults()
    end
    refreshKeys()
    return true
end

-- One press, one search.
function S.SearchNext()
    if pending then return false end
    if S.Filtering() then return browseNext() end
    local groups = S.Groups()
    if #groups == 0 then
        alert("nothing left on your list that traders can sell")
        return false
    end
    local nextGroup
    for _, group in ipairs(groups) do
        if not searched[group.setId] then
            nextGroup = group
            break
        end
    end
    if not nextGroup then
        searched = {}
        nextGroup = groups[1]
    end
    searched[nextGroup.setId] = true
    if GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS:IsActive() then TRADING_HOUSE_GAMEPAD:DeactivateBrowseResults() end
    GAMEPAD_TRADING_HOUSE_BROWSE:ResetSearch()
    pending = { group = nextGroup, texts = S.SearchTexts(nextGroup), index = 0 }
    tryNextText()
    refreshKeys()
    return true
end

function S.SetMode(mode)
    SH.internal.opts.traderSearchMode = MODE_NAMES[mode] and mode or "exact"
    S.ResetProgress()
    pcall(function() GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS:RefreshData() end)
end

function S.ToggleMode()
    S.SetMode(NEXT_MODE[S.Mode()])
    alert("searching for: " .. S.ModeName())
end

-- Lets you see everything at this trader. The filter is back at the next one.
function S.ToggleFilter()
    filterPaused = not filterPaused
    alert(filterPaused and "trader filter off, showing everything" or "trader filter on")
    S.ResetProgress()
    pcall(function() GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS:RefreshData() end)
end

function S.ResetProgress()
    searched = {}
    armedTraits = nil
    if pending then finish(nil) else refreshKeys() end
end

local function searchKey(isShown)
    return {
        keybind = "UI_SHORTCUT_LEFT_STICK",
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        name = function() return S.ButtonName() end,
        visible = isShown,
        enabled = function() return pending == nil and not isSearching() end,
        callback = function() S.SearchNext() end,
    }
end

local function listOrCollectMode()
    return S.Filtering() or next(SH.internal.ActiveSets()) ~= nil
end

local function addKey(object, withModeKey)
    local descriptor = object.keybindStripDescriptor
    if not descriptor or descriptor.setHunterSearch then return end
    descriptor.setHunterSearch = true
    descriptors[#descriptors + 1] = descriptor
    table.insert(descriptor, searchKey(listOrCollectMode))
    -- The results screen already uses this button for its own search
    if withModeKey then
        table.insert(descriptor, {
            keybind = "UI_SHORTCUT_QUATERNARY",
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            name = function()
                if S.AnyKindOn() then return "Trader filter: " .. (filterPaused and "Off" or "On") end
                return "Search mode: " .. S.ModeName()
            end,
            visible = function() return S.AnyKindOn() or next(SH.internal.ActiveSets()) ~= nil end,
            enabled = function() return pending == nil end,
            callback = function()
                if S.AnyKindOn() then S.ToggleFilter() else S.ToggleMode() end
            end,
        })
    end
end

-- A page with nothing new has no rows, so the game moves focus to the column headers.
-- The button has to be there too, or you'd be stuck on that page.
local function addHeaderKey(results)
    local headers = results.headersFocalArea
    local descriptor = headers and headers.keybindDescriptor
    if not descriptor or descriptor.setHunterSearch then return end
    descriptor.setHunterSearch = true
    descriptors[#descriptors + 1] = descriptor
    headers:AppendKeybind(searchKey(function() return S.Filtering() end))
end

local function watchKeys(object, withModeKey)
    addKey(object, withModeKey)
    if object.setHunterKeysWatched then return end
    object.setHunterKeysWatched = true
    local initialize = object.InitializeKeybindStripDescriptors
    object.InitializeKeybindStripDescriptors = function(self, ...)
        initialize(self, ...)
        addKey(self, withModeKey)
    end
end

-- Safe to call more than once. The gamepad trader builds its buttons the first time it opens.
function S.Install()
    local browse, results = GAMEPAD_TRADING_HOUSE_BROWSE, GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS
    if not browse or not results then return end
    watchKeys(browse, true)
    watchKeys(results)
    pcall(addHeaderKey, results)
    if S.installed then return end
    S.installed = true
    -- The game clears every filter just before searching, so ours go on after that
    local search = TRADING_HOUSE_SEARCH
    local applyFilters = search.ApplyFilters
    search.ApplyFilters = function(self, isPerformingSearch, ...)
        applyFilters(self, isPerformingSearch, ...)
        if isPerformingSearch and S.Filtering() and isAllItemsSearch(self) then
            pcall(applyCollectFilters, self)
        end
        if isPerformingSearch and armedTraits then
            local traits = armedTraits
            armedTraits = nil
            if #traits <= GetMaxTradingHouseFilterExactTerms(TRADING_HOUSE_FILTER_TYPE_TRAIT) then
                pcall(self.SetFilter, self, TRADING_HOUSE_FILTER_TYPE_TRAIT, traits)
            end
        end
    end
    if browse.features and browse.features.nameSearchFeature then
        browse.features.nameSearchFeature:RegisterCallback("OnNameMatchComplete", function() pcall(S.OnNameMatch) end)
    end
    local filterList = results.FilterScrollList
    if filterList then
        results.FilterScrollList = function(self, ...)
            filterList(self, ...)
            if S.Filtering() then
                local ok = pcall(S.FilterResults, self)
                if not ok then
                    -- Never fall back to showing everything
                    ZO_ClearNumericallyIndexedTable(ZO_ScrollList_GetDataList(self.list))
                    alert("the Not collected filter failed on this page")
                end
            else
                pcall(restoreTitle, self)
            end
        end
    end
    if search.RegisterCallback then
        search:RegisterCallback("OnSearchStateChanged", refreshKeys)
    end
    local name = "ESOCSetHunterTraderSearch"
    EVENT_MANAGER:RegisterForEvent(name, EVENT_OPEN_TRADING_HOUSE, function()
        filterPaused = false
        S.ResetProgress()
    end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_TRADING_HOUSE_SELECTED_GUILD_CHANGED, function() S.ResetProgress() end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_CLOSE_TRADING_HOUSE, function()
        armedTraits = nil
        if pending then finish(nil) end
    end)
end
