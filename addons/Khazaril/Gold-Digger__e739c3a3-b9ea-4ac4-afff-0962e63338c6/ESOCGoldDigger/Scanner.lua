-- Gold Digger trader log. Choosing "Scan new listings" runs one scan of a trader's newest listings,
-- at the game's own search speed, and B stops it. It never buys, lists or sells anything.

local GP = ESOC_GoldDigger
local Scanner = {}
GP.Scanner = Scanner

local Scoring = GP.Scoring
local History = GP.History
local Selling = GP.Selling
local Jobs = GP.Jobs

-- A tour of several zones takes a while, so listings stay usable for three hours
Scanner.STALE_SECONDS = 3 * 3600
Scanner.BUDGET_BYTES = 5 * 1024 * 1024
local KEEP_LISTING_SECONDS = 8 * 3600
local MAX_LISTINGS = 1500
local MAX_ITEMS = 1500
local LISTING_BYTES = 470
local MAX_SALES_PER_READ = 500
local READ_DELAY_MS = 200
local PRUNE_EVERY_PAGES = 10
local REPORT_SECONDS = 60
local CHECK_ROWS = 8
local MAX_SCAN_PAGES = 60
local RESCAN_SECONDS = 30 * 60
local SCAN_NEXT_DELAY_MS = 150
local SCAN_TIMEOUT_MS = 20000
local SCAN_OPEN_POLL_MS = 400
local SCAN_OPEN_TRIES = 10
local REPORT_DELAY_MS = 1500
local BLACKLIST_BARGAIN = 0.5   -- a blacklisted item is only mentioned at half its resale price or less

local RELIABLE_NAMES = {
    "ITEMTYPE_RACIAL_STYLE_MOTIF", "ITEMTYPE_RECIPE", "ITEMTYPE_REAGENT", "ITEMTYPE_POTION_BASE",
    "ITEMTYPE_POISON_BASE", "ITEMTYPE_STYLE_MATERIAL", "ITEMTYPE_RAW_MATERIAL", "ITEMTYPE_INGREDIENT",
    "ITEMTYPE_BLACKSMITHING_MATERIAL", "ITEMTYPE_CLOTHIER_MATERIAL", "ITEMTYPE_WOODWORKING_MATERIAL",
    "ITEMTYPE_JEWELRYCRAFTING_MATERIAL", "ITEMTYPE_BLACKSMITHING_BOOSTER", "ITEMTYPE_CLOTHIER_BOOSTER",
    "ITEMTYPE_WOODWORKING_BOOSTER", "ITEMTYPE_JEWELRYCRAFTING_BOOSTER", "ITEMTYPE_ENCHANTING_RUNE_ASPECT",
    "ITEMTYPE_ENCHANTING_RUNE_ESSENCE", "ITEMTYPE_ENCHANTING_RUNE_POTENCY", "ITEMTYPE_ARMOR_TRAIT",
    "ITEMTYPE_WEAPON_TRAIT", "ITEMTYPE_JEWELRY_TRAIT",
}
local reliable, tracked = {}, {}
for _, name in ipairs(RELIABLE_NAMES) do
    local value = _G[name]
    if value ~= nil then reliable[value], tracked[value] = true, true end
end
-- Furnishings keep a price history too. Random gear doesn't unless it has actually sold.
if _G.ITEMTYPE_FURNISHING ~= nil then tracked[_G.ITEMTYPE_FURNISHING] = true end

local report, reportDirty = nil, true
local pagesSincePrune = 0
local lastBytes = 0
local restoreSort = false  -- a scan changed the order, so put it back before your next search
local scanRowShown = false
local scan, scanToken = nil, 0
local seenIds, seenDay, seenCount = {}, nil, 0
local MAX_SEEN_IDS = 6000
local BOOK_ASKS = 3
local reportQueued = false
local EMPTY_REPORT = { at = 0, rows = {}, stops = {}, zones = {}, stale = 0, hiddenOld = 0, hiddenPrice = 0, plan = {}, farm = {}, building = true }

local SINGLE_SALE_NAMES = { "ITEMTYPE_RACIAL_STYLE_MOTIF", "ITEMTYPE_RECIPE", "ITEMTYPE_FURNISHING" }
local singleSale = {}
for _, name in ipairs(SINGLE_SALE_NAMES) do
    local value = _G[name]
    if value ~= nil then singleSale[value] = true end
end

-- Motifs, recipes and furnishings are bought and sold one at a time.
function Scanner.SellsSingly(link)
    return singleSale[GetItemLinkItemType(link)] == true
end

-- What one resale listing would be worth, which is what the minimum listing value is about.
function Scanner.ListingValue(listing, sellAt)
    if listing.l and Scanner.SellsSingly(listing.l) then return sellAt end
    return sellAt * listing.q
end

-- Same item, quality, level and trait share one price history.
function Scanner.KeyFor(link)
    local trait = GetItemLinkTraitType and GetItemLinkTraitType(link) or GetItemLinkTraitInfo(link)
    return table.concat({
        GetItemLinkItemId(link), GetItemLinkDisplayQuality(link), GetItemLinkRequiredLevel(link),
        GetItemLinkRequiredChampionPoints(link), trait or 0,
    }, ":")
end

local function itemFor(key, link, name, always)
    local items = GP.sv.items
    local item = items[key]
    if not item then
        local itemType = GetItemLinkItemType(link)
        if not always and not tracked[itemType] then return nil end
        item = { name = zo_strformat("<<t:1>>", name), t = itemType, r = reliable[itemType] == true }
        items[key] = item
    end
    item.last = GetTimeStamp()
    return item
end

-- Items being changed are unpacked once and packed again when the page is finished.
local function workingCopy(working, key, item)
    local entry = working[key]
    if not entry then
        entry = { item = item, view = History.View(item) }
        working[key] = entry
    end
    return entry.view
end

local function saveWorking(working, today, tick)
    for _, entry in pairs(working) do
        if tick then tick() end
        History.Compact(entry.view, today)
        History.Store(entry.item, entry.view)
    end
end

function Scanner.ListingDays()
    return GP.sv.listingDays or 14
end

-- The cheapest few live prices for an item where you sell, kept as one short line of text.
-- This survives however many traders you scan afterwards.
local function readBook(text)
    local asks = {}
    local body = string.match(text or "", "|(.*)$") or ""
    for entry in string.gmatch(body, "[^;]+") do
        local price, expires, id = string.match(entry, "^([^,]*),([^,]*),(.*)$")
        asks[#asks + 1] = { p = tonumber(price), x = tonumber(expires), id = id }
    end
    return asks
end

local function writeBook(asks, now)
    local parts = {}
    for index = 1, math.min(#asks, BOOK_ASKS) do
        local ask = asks[index]
        parts[index] = string.format("%.2f,%.0f,%s", ask.p, ask.x or 0, ask.id)
    end
    return string.format("%.0f|", now) .. table.concat(parts, ";")
end

local function cheaperAsk(a, b)
    if a.p ~= b.p then return a.p < b.p end
    return a.id < b.id
end

local function addToBook(zoneKey, key, id, unit, expires, now)
    local book = GP.sv.book[zoneKey] or {}
    GP.sv.book[zoneKey] = book
    local asks = readBook(book[key])
    for index = #asks, 1, -1 do
        if asks[index].id == id then table.remove(asks, index) end
    end
    asks[#asks + 1] = { p = unit, x = expires, id = id }
    table.sort(asks, cheaperAsk)
    book[key] = writeBook(asks, now)
end

-- Takes a listing out of the price book, such as one you've just bought.
function Scanner.RemoveAsk(key, id)
    local now = GetTimeStamp()
    for _, book in pairs(GP.sv.book) do
        if book[key] then
            local asks = readBook(book[key])
            for index = #asks, 1, -1 do
                if asks[index].id == id then table.remove(asks, index) end
            end
            book[key] = #asks > 0 and writeBook(asks, now) or nil
        end
    end
end

-- The live asks for one item in your best selling market.
function Scanner.AsksFor(key)
    local now, byZone = GetTimeStamp(), {}
    for zoneKey, book in pairs(GP.sv.book) do
        local text = book[key]
        if text and Selling.InSellZone(zoneKey) then
            local at = tonumber(string.match(text, "^(%d+)|"))
            if at and now - at <= Scanner.STALE_SECONDS then
                local asks = readBook(text)
                for _, ask in ipairs(asks) do
                    if ask.x and ask.x > 0 then ask.age = math.max(0, Scanner.ListingDays() - (ask.x - now) / 86400) end
                end
                if #asks > 0 then byZone[zoneKey] = { [key] = asks } end
            end
        end
    end
    return Selling.BestAsks(key, byZone)
end

-- True when it can't be a deal against what's already known in your selling market.
local function tooDear(key, id, unit)
    if GP.Events.Current() then return false end
    local asks = Scanner.AsksFor(key)
    if not asks then return false end
    for _, ask in ipairs(asks) do
        if ask.id ~= id then
            local sellAt = Scoring.ListAt(ask.p)
            return Scoring.Margin(unit, sellAt) < Scoring.TOUR_MARGIN
        end
    end
    return false
end

local function firstSightingToday(id, today)
    if seenDay ~= today or seenCount >= MAX_SEEN_IDS then
        seenIds, seenDay, seenCount = {}, today, 0
    end
    if seenIds[id] then return false end
    seenIds[id] = true
    seenCount = seenCount + 1
    return true
end

local function logListing(index, traderName, zoneName, today, now, working, maxAge, inSellZone, zoneKey)
    local _, name, _, stack, seller, timeLeft, price, currency, uniqueId = GetTradingHouseSearchResultItemInfo(index)
    if not name or name == "" or not stack or stack <= 0 then return false end
    if currency and currency ~= CURT_MONEY then return false end
    local link = GetTradingHouseSearchResultItemLink(index)
    if not link or link == "" then return false end

    -- Patch notes say 14 days. A longer time left proves the game is using 30.
    if timeLeft and timeLeft > 14.5 * 86400 then
        GP.sv.listingDays, GP.sv.listingDaysAt = 30, now
    end
    local mine = seller == GetDisplayName()
    local tooOld = timeLeft ~= nil and Scanner.ListingDays() - timeLeft / 86400 > maxAge
    -- Old listings only matter where you sell, as prices to beat
    if not inSellZone and tooOld then return true end

    local unit = price / stack
    local key = Scanner.KeyFor(link)
    local id = Id64ToString(uniqueId) .. ":" .. price
    local item = itemFor(key, link, name)
    if item and firstSightingToday(id, today) then
        local view = workingCopy(working, key, item)
        local bucket = view.days[today] or { c = 0, s = 0 }
        local reference = Scoring.GoingRate(view, today)
        if not reference and bucket.c >= 3 then reference = bucket.s / bucket.c end
        if not Scoring.IsOutlier(unit, reference) then
            Scoring.AddPrice(bucket, unit)
            view.days[today] = bucket
            local eventName = GP.Events.ActiveName()
            if eventName then
                bucket.e = true
                view.ev = view.ev or {}
                local eventPrices = view.ev[eventName] or { c = 0, s = 0 }
                Scoring.AddPrice(eventPrices, unit)
                view.ev[eventName] = eventPrices
            end
        end
    end
    if inSellZone and not mine then addToBook(zoneKey, key, id, unit, timeLeft and (now + timeLeft) or nil, now) end

    -- Only possible buys are kept, which is what keeps a long tour small
    local minValue = GP.sv.options.minListValue or 0
    if mine or tooOld or (minValue > 0 and price < minValue * 0.2) or tooDear(key, id, unit) then
        GP.sv.listings[id] = nil
        return true, key, unit, id
    end
    GP.sv.listings[id] = {
        k = key, p = unit, q = stack, t = traderName, z = zoneName, at = now, d = today,
        x = timeLeft and (now + timeLeft) or nil, l = link,
        n = not item and zo_strformat("<<t:1>>", name) or nil,
    }
    return true, key, unit, id
end

local function sortValues()
    return rawget(_G, "TRADING_HOUSE_SEARCH"), rawget(_G, "TRADING_HOUSE_SORT_EXPIRY_TIME"), rawget(_G, "ZO_SORT_ORDER_DOWN")
end

-- Lowest unit price first, the game's own default. This is how a price check finds the cheapest copy.
local function cheapestSortActive()
    local search = rawget(_G, "TRADING_HOUSE_SEARCH")
    local key, up = rawget(_G, "TRADING_HOUSE_SORT_SALE_PRICE_PER_UNIT"), rawget(_G, "ZO_SORT_ORDER_UP")
    if not search or key == nil or up == nil then return false end
    return search.sortField == key and search.sortOrder == up
end

local function setSort(search, key, order)
    search.sortField, search.sortOrder = key, order
    local results = rawget(_G, "GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS")
    if results then
        results.currentSortKey, results.currentSortOrder = key, order
        pcall(function() results.sortHeaderGroup:SelectHeaderByKey(key, ZO_SortHeaderGroup.SUPPRESS_CALLBACKS, nil, order) end)
    end
end

-- Puts the game's normal order back after a scan.
function Scanner.RestoreSort()
    if not restoreSort then return end
    local search = rawget(_G, "TRADING_HOUSE_SEARCH")
    local key, up = rawget(_G, "TRADING_HOUSE_SORT_SALE_PRICE_PER_UNIT"), rawget(_G, "ZO_SORT_ORDER_UP")
    if not search or key == nil or up == nil then return end
    restoreSort = false
    setSort(search, key, up)
end

local function searchText()
    local search = rawget(_G, "TRADING_HOUSE_SEARCH")
    if not search then return "" end
    local ok, text = pcall(function() return search.features.nameSearchFeature:GetSearchText() end)
    return ok and text or ""
end

-- Scans go newest first and the guided run goes cheapest first. Your own searches are left alone.
function Scanner.ChooseSort(search)
    if GP.Run.IsSearching() then
        restoreSort = false
        local key, up = rawget(_G, "TRADING_HOUSE_SORT_SALE_PRICE_PER_UNIT"), rawget(_G, "ZO_SORT_ORDER_UP")
        if key ~= nil and up ~= nil then setSort(search, key, up) end
    elseif scan then
        local _, key, down = sortValues()
        if key ~= nil and down ~= nil then setSort(search, key, down) end
    else
        Scanner.RestoreSort()
    end
end

local function watchSearches()
    local search = rawget(_G, "TRADING_HOUSE_SEARCH")
    if not search or search.goldDiggerWatched or not search.DoSearch then return end
    search.goldDiggerWatched = true
    local doSearch = search.DoSearch
    search.DoSearch = function(self, ...)
        -- Paging uses the last search's filters and must keep its order
        if not self.useLastExecutedSearchFilters then pcall(Scanner.ChooseSort, self) end
        return doSearch(self, ...)
    end
    local changeSort = search.ChangeSort
    if changeSort then
        search.ChangeSort = function(self, key, order, ...)
            -- A column you pick yourself after a scan is yours to keep
            if not scan and (key ~= self.sortField or order ~= self.sortOrder) then restoreSort = false end
            return changeSort(self, key, order, ...)
        end
    end
end

-- Only an All Items search can finish a trader. A category search leaves the rest unread.
local function isAllItemsSearch()
    local search = rawget(_G, "TRADING_HOUSE_SEARCH")
    if not search then return true end
    local ok, key = pcall(function() return search.features.searchCategoryFeature:GetCategoryParams():GetKey() end)
    return not ok or key == "AllItems"
end

-- The name of the NPC you're talking to, the same call the game uses for its own title.
local function traderNpcName()
    local ok, name = pcall(GetUnitName, "interact")
    if not ok or not name or name == "" then return nil end
    return zo_strformat("<<1>>", name)
end

-- The town or area you're standing in, when the game gives one that differs from the zone.
local function townName(zoneName)
    local getLocation = rawget(_G, "GetPlayerLocationName")
    if not getLocation then return nil end
    local ok, name = pcall(getLocation)
    if not ok or not name or name == "" then return nil end
    name = zo_strformat("<<C:1>>", name)
    if name == zoneName then return nil end
    return name
end

-- A fresh price check for this item, if there is one.
function Scanner.CheckFor(key)
    local check = GP.sv.checks[key]
    if check and GetTimeStamp() - check.at <= Scanner.STALE_SECONDS then return check end
    return nil
end

local function recordCheck(key, traderName, now, low)
    local check = Scanner.CheckFor(key) or { n = 0, traders = {} }
    if not check.traders[traderName] then
        check.traders[traderName] = true
        check.n = check.n + 1
    end
    check.at = now
    if low and (not check.low or low < check.low) then check.low = low end
    GP.sv.checks[key] = check
end

-- A first page sorted cheapest first shows this trader's lowest price for each item on it.
local function recordChecks(checkKeys, firstSeen, traderName, now, hasMore)
    local text = string.lower(searchText())
    for key in pairs(checkKeys) do
        if firstSeen[key] then
            recordCheck(key, traderName, now, firstSeen[key])
            reportDirty = true
        elseif #text >= 3 and not hasMore then
            local item = GP.sv.items[key]
            if item and string.find(string.lower(item.name or ""), text, 1, true) then
                recordCheck(key, traderName, now, nil)
                reportDirty = true
            end
        end
    end
end

function Scanner.ReadPage()
    if not GP.unlocked then return 0 end
    Selling.Refresh()
    local numItems, page, hasMore = GetTradingHouseSearchResultsInfo()
    local _, traderName = GetCurrentTradingHouseGuildDetails()
    traderName = traderName or ""
    local zoneName = zo_strformat("<<C:1>>", GetUnitZone("player"))
    local today, now, logged = GP.Today(), GetTimeStamp(), 0
    if GP.sv.listingDaysAt and now - GP.sv.listingDaysAt > 31 * 86400 then
        GP.sv.listingDays, GP.sv.listingDaysAt = nil, nil
    end
    local npc, town = traderNpcName(), townName(zoneName)
    Selling.Learn(npc, town, zoneName)
    local inSellZone = Selling.InSellZone(zoneName)
    local zoneKey = Selling.ZoneKey(zoneName)
    -- Taken before reading the page, because a cheaper copy can knock an item off the report
    local checkKeys = inSellZone and (page or 0) == 0 and cheapestSortActive() and Scanner.CheckKeys() or nil
    local maxAge, reachedCutoff, inAgeOrder, lastAge = GP.sv.options.maxAgeDays or 3, false, true, nil
    local working, firstSeen = {}, {}
    for index = 1, numItems or 0 do
        local read, key, unit = logListing(index, traderName, zoneName, today, now, working, maxAge, inSellZone, zoneKey)
        if read then logged = logged + 1 end
        if key and not firstSeen[key] then firstSeen[key] = unit end
        local _, _, _, _, _, timeLeft = GetTradingHouseSearchResultItemInfo(index)
        if timeLeft then
            local age = Scanner.ListingDays() - timeLeft / 86400
            if age > maxAge then reachedCutoff = true end
            if lastAge and age + 0.01 < lastAge then inAgeOrder = false end
            lastAge = age
        end
    end
    saveWorking(working, today)
    reportDirty = true
    if checkKeys then recordChecks(checkKeys, firstSeen, traderName, now, hasMore) end

    local place = traderName .. "|" .. zoneName
    local progress = GP.sv.tour[place]
    if not progress or now - progress.at > Scanner.STALE_SECONDS then progress = { pages = 0 } end
    progress.t, progress.z, progress.at = traderName, zoneName, now
    progress.npc = npc or progress.npc
    progress.town = town or progress.town
    progress.page, progress.more = (page or 0) + 1, hasMore == true
    progress.seen = ((page or 0) == 0 and 0 or (progress.seen or 0)) + logged
    if progress.page > progress.pages then progress.pages = progress.page end
    -- In a newest-first scan, one listing past the cutoff means every newer one has been read
    progress.cutoff = scan ~= nil and reachedCutoff and inAgeOrder
    progress.full = isAllItemsSearch()
    progress.done = progress.done or (progress.full and not progress.more)
    GP.sv.tour[place] = progress

    pagesSincePrune = pagesSincePrune + 1
    if pagesSincePrune >= PRUNE_EVERY_PAGES then Scanner.PruneListings() end
    if scan then
        scan.pages = scan.pages + 1
        if progress.cutoff or not progress.more or scan.pages >= MAX_SCAN_PAGES then
            Scanner.FinishScan(true)
        else
            Scanner.NextScanPage()
        end
    else
        Scanner.QueueReport()
    end
    GP.Run.OnPage(numItems, page or 0, hasMore)
    GP.Interface.RefreshPanel()
    return logged
end

-- Adds real sales from every guild you're in, using the history the game has already loaded.
local function readGuildSales(guildId, working, today, tick)
    local sv, added = GP.sv, 0
    local cursorKey = tostring(guildId)
    local cursor = sv.saleCursors[cursorKey] or { time = 0, ids = {} }
    local newestTime, newestIds = cursor.time, {}
    for id in pairs(cursor.ids) do newestIds[id] = true end
    local count = math.min(GetNumGuildHistoryEvents(guildId, GUILD_HISTORY_EVENT_CATEGORY_TRADER), MAX_SALES_PER_READ)
    for index = 1, count do
        if tick then tick() end
        local eventId, time, redacted, _, seller, buyer, link, quantity, price = GetGuildHistoryTraderEventInfo(guildId, index)
        if time < cursor.time then break end
        local idText = tostring(eventId)
        if not redacted and buyer and buyer ~= "" and link and link ~= "" and (price or 0) > 0 and (quantity or 0) > 0
            and not cursor.ids[idText] then
            if seller == GetDisplayName() then GP.Stockpile.MarkSold(link, quantity, time) end
            local key = Scanner.KeyFor(link)
            local item = itemFor(key, link, GetItemLinkName(link), true)
            local view = workingCopy(working, key, item)
            local day = math.floor((time - GP.ResetHour() * 3600) / 86400)
            local bucket = view.sales[day] or { n = 0, q = 0, g = 0 }
            bucket.n, bucket.q, bucket.g = bucket.n + 1, bucket.q + quantity, bucket.g + price
            if GP.Events.NameAt(time) then bucket.e = true end
            view.sales[day] = bucket
            added = added + 1
        end
        if time > newestTime then
            newestTime, newestIds = time, {}
        end
        if time == newestTime then newestIds[idText] = true end
    end
    sv.saleCursors[cursorKey] = { time = newestTime, ids = newestIds }
    return added
end

function Scanner.ReadSales(tick)
    if not GP.unlocked then return 0 end
    local added, working, today = 0, {}, GP.Today()
    for index = 1, GetNumGuilds() do
        added = added + readGuildSales(GetGuildId(index), working, today, tick)
    end
    saveWorking(working, today, tick)
    if added > 0 then reportDirty = true end
    return added
end

local function trimOldest(map, limit, timeField)
    local entries = {}
    for key, value in pairs(map) do entries[#entries + 1] = { key = key, time = value[timeField] or 0 } end
    if #entries <= limit then return end
    table.sort(entries, function(a, b) return a.time < b.time end)
    for index = 1, #entries - limit do map[entries[index].key] = nil end
end

-- When the list is full, every trader keeps a fair share, so a new zone can't push out the earlier ones.
-- Listings your selling prices rule out go first. Within a trader, proven deals and the newest stay.
local function trimListings()
    local listings, total = GP.sv.listings, 0
    for _ in pairs(listings) do total = total + 1 end
    if total <= MAX_LISTINGS then return end
    local eventOn, asksByKey, groups, byPlace = GP.Events.Current() ~= nil, {}, {}, {}
    for id, listing in pairs(listings) do
        local asks = asksByKey[listing.k]
        if asks == nil then
            asks = Scanner.AsksFor(listing.k) or false
            asksByKey[listing.k] = asks
        end
        local other
        for _, ask in ipairs(asks or {}) do
            if ask.id ~= id then
                other = ask
                break
            end
        end
        if other and not eventOn and Scoring.Margin(listing.p, Scoring.ListAt(other.p)) < Scoring.TOUR_MARGIN then
            listings[id] = nil
            total = total - 1
        else
            local place = listing.t .. "|" .. listing.z
            local group = byPlace[place]
            if not group then
                group = {}
                byPlace[place] = group
                groups[#groups + 1] = group
            end
            group[#group + 1] = { id = id, proven = other ~= nil, x = listing.x or 0 }
        end
    end
    if total <= MAX_LISTINGS then return end
    table.sort(groups, function(a, b) return #a < #b end)
    local room = MAX_LISTINGS
    for index, group in ipairs(groups) do
        local share = math.floor(room / (#groups - index + 1))
        if #group > share then
            table.sort(group, function(a, b)
                if a.proven ~= b.proven then return a.proven end
                if a.x ~= b.x then return a.x > b.x end
                return a.id < b.id
            end)
            for position = share + 1, #group do listings[group[position].id] = nil end
        end
        room = room - math.min(#group, share)
    end
end

-- The light cleanup that runs during a tour.
function Scanner.PruneListings()
    pagesSincePrune = 0
    local sv, now = GP.sv, GetTimeStamp()
    for id, listing in pairs(sv.listings) do
        if now - listing.at > KEEP_LISTING_SECONDS then sv.listings[id] = nil end
    end
    trimListings()
    for place, progress in pairs(sv.tour) do
        if now - progress.at > KEEP_LISTING_SECONDS then sv.tour[place] = nil end
    end
    for key, check in pairs(sv.checks) do
        if now - check.at > Scanner.STALE_SECONDS then sv.checks[key] = nil end
    end
    for _, book in pairs(sv.book) do
        for key, text in pairs(book) do
            local at = tonumber(string.match(text, "^(%d+)|"))
            if not at or now - at > Scanner.STALE_SECONDS then book[key] = nil end
        end
    end
    reportDirty = true
end

-- Roughly how much memory Gold Digger's saved data takes.
function Scanner.EstimateBytes()
    local bytes = 0
    for _, item in pairs(GP.sv.items) do bytes = bytes + History.Bytes(item) end
    for _ in pairs(GP.sv.listings) do bytes = bytes + LISTING_BYTES end
    for _, book in pairs(GP.sv.book) do
        for _, text in pairs(book) do bytes = bytes + 60 + #text end
    end
    lastBytes = bytes
    return bytes
end

function Scanner.LastBytes()
    return lastBytes
end

-- Drops the items you haven't seen for longest until everything fits the budget.
local function enforceBudget()
    local bytes = Scanner.EstimateBytes()
    if bytes <= Scanner.BUDGET_BYTES then return end
    local entries = {}
    for key, item in pairs(GP.sv.items) do
        entries[#entries + 1] = { key = key, time = item.last or 0, bytes = History.Bytes(item) }
    end
    table.sort(entries, function(a, b) return a.time < b.time end)
    for _, entry in ipairs(entries) do
        if bytes <= Scanner.BUDGET_BYTES then break end
        GP.sv.items[entry.key] = nil
        bytes = bytes - entry.bytes
    end
    lastBytes = bytes
end

-- The full cleanup, once at login.
function Scanner.Prune()
    local sv, today = GP.sv, GP.Today()
    Scanner.PruneListings()
    for _, item in pairs(sv.items) do
        -- Packed items are only opened when something in them has actually expired
        if item.days or (item.o and item.o < today - History.KEEP_DAYS) then
            local view = History.View(item)
            History.Compact(view, today)
            History.Store(item, view)
        end
    end
    trimOldest(sv.items, MAX_ITEMS, "last")
    enforceBudget()
end

function Scanner.InSellZone(zone)
    return Selling.InSellZone(zone)
end

-- How many days it has been on sale, worked out from the time it has left.
local function ageDays(listing, now)
    if not listing.x then return nil end
    return math.max(0, Scanner.ListingDays() - (listing.x - now) / 86400)
end

-- Ranked buys from fresh listings: quick flips, then buy-and-hold, each by profit.
function Scanner.ShoppingList(limit, tick)
    local sv, now, today = GP.sv, GetTimeStamp(), GP.Today()
    local active, rows, staleCount, facts, markets = {}, {}, 0, {}, {}
    local eventActive = GP.Events.Current() ~= nil
    local options = sv.options
    local maxAge, maxPrice = options.maxAgeDays or 3, options.maxPrice or 0
    local minValue, minProfit = options.minListValue or 0, options.minProfit or 0
    local hiddenOld, hiddenPrice = 0, 0
    local warned, hiddenBlacklist = {}, 0
    for _, listing in pairs(sv.listings) do active[listing.k] = (active[listing.k] or 0) + 1 end
    for id, listing in pairs(sv.listings) do
        if tick then tick() end
        local age = ageDays(listing, now)
        if now - listing.at > Scanner.STALE_SECONDS then
            staleCount = staleCount + 1
        elseif not listing.mine and age and age > maxAge then
            hiddenOld = hiddenOld + 1
        elseif not listing.mine and maxPrice > 0 and listing.p * listing.q > maxPrice then
            hiddenPrice = hiddenPrice + 1
        elseif not listing.mine then
            local key = listing.k
            local item = sv.items[key] or { name = listing.n or "Unknown item", r = false, days = {}, weeks = {}, sales = {} }
            if not facts[key] then
                facts[key] = Scoring.ItemFacts(item, today, active[key], item.r, eventActive)
                local asks, guild = Scanner.AsksFor(key)
                markets[key] = { asks = asks, guild = guild }
            end
            local market = markets[key]
            local result = Scoring.Evaluate(item, listing, today, active[key], item.r, eventActive,
                { asks = market.asks, id = id, age = age, facts = facts[key] })
            -- A listing has to be worth a trader slot once it's resold
            if result and result.flag and Scanner.ListingValue(listing, result.sellAt) >= minValue and result.profit >= minProfit then
                result.id, result.listing, result.name = id, listing, item.name
                result.sellGuild = market.guild
                result.sellZone = market.guild and market.guild.zone or Selling.PrimaryZone()
                result.check = Scanner.CheckFor(key)
                if GP.Stockpile.IsBlacklisted(key) then
                    -- Never on a buy run. A huge bargain is still pointed out, with a warning
                    hiddenBlacklist = hiddenBlacklist + 1
                    if listing.p <= result.sellAt * BLACKLIST_BARGAIN then warned[#warned + 1] = result end
                else
                    rows[#rows + 1] = result
                end
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.flag ~= b.flag then return a.flag == "flip" end
        if a.profit ~= b.profit then return a.profit > b.profit end
        return a.id < b.id
    end)
    for index = #rows, (limit or #rows) + 1, -1 do rows[index] = nil end
    table.sort(warned, function(a, b)
        if a.profit ~= b.profit then return a.profit > b.profit end
        return a.id < b.id
    end)
    return rows, staleCount, hiddenOld, hiddenPrice, warned, hiddenBlacklist
end

-- Spending limit. The gold a deal ties up is its price plus the fee paid up front to relist it.
local LISTING_FEE = 0.01
local MAX_PLAN_ITEMS = 40    -- the most a buy run can hold
local BUDGET_OPTIONS = 400   -- how many spending combinations are kept while comparing

local function capitalFor(row)
    return row.listing.p * row.listing.q + math.ceil(row.sellAt * row.listing.q * LISTING_FEE)
end
Scanner.CapitalFor = capitalFor

-- The deals worth comparing: the best earners and the best returns on the gold, in turn.
local function shortlist(rows, money, maxCount)
    local byProfit, byReturn = {}, {}
    for _, row in ipairs(rows) do
        if capitalFor(row) <= money then
            byProfit[#byProfit + 1] = row
            byReturn[#byReturn + 1] = row
        end
    end
    table.sort(byProfit, function(a, b)
        if a.profit ~= b.profit then return a.profit > b.profit end
        return a.id < b.id
    end)
    table.sort(byReturn, function(a, b)
        local left, right = a.profit / capitalFor(a), b.profit / capitalFor(b)
        if left ~= right then return left > right end
        return a.id < b.id
    end)
    local list, seen = {}, {}
    for index = 1, #byProfit do
        for _, row in ipairs({ byProfit[index], byReturn[index] }) do
            if not seen[row] and #list < maxCount then
                seen[row] = true
                list[#list + 1] = row
            end
        end
        if #list >= maxCount then break end
    end
    return list
end

-- The combination of deals that earns the most without going over the money available.
local function bestWithin(rows, money, maxCount, tick)
    local candidates = shortlist(rows, money, maxCount)
    if #candidates == 0 or money <= 0 then return {}, 0 end
    -- Each option is a spend and its profit. Spending more is only kept if it also earns more.
    local options = { { cost = 0, profit = 0 } }
    for _, row in ipairs(candidates) do
        if tick then tick() end
        local price, merged, withoutIndex, withIndex, topProfit = capitalFor(row), {}, 1, 1, -1
        while withoutIndex <= #options or withIndex <= #options do
            local without, base = options[withoutIndex], options[withIndex]
            local withCost = base and base.cost + price
            if withCost and withCost > money then
                base, withCost, withIndex = nil, nil, #options + 1
            end
            local option
            if without and (not base or without.cost < withCost
                or (without.cost == withCost and without.profit >= base.profit + row.profit)) then
                option, withoutIndex = without, withoutIndex + 1
            elseif base then
                option = { cost = withCost, profit = base.profit + row.profit, row = row, previous = base }
                withIndex = withIndex + 1
            end
            if option and option.profit > topProfit then
                merged[#merged + 1] = option
                topProfit = option.profit
            end
        end
        if #merged > BUDGET_OPTIONS then
            local thinned, gap = {}, #merged / BUDGET_OPTIONS
            for index = 1, BUDGET_OPTIONS - 1 do thinned[index] = merged[math.floor((index - 1) * gap) + 1] end
            thinned[BUDGET_OPTIONS] = merged[#merged]
            merged = thinned
        end
        options = merged
    end
    local chosen, used, spent = {}, {}, 0
    local option = options[#options]
    while option and option.row do
        chosen[#chosen + 1] = option.row
        used[option.row] = true
        spent = spent + capitalFor(option.row)
        option = option.previous
    end
    -- If a very long list had to be thinned, use any room that's left
    for _, row in ipairs(candidates) do
        if not used[row] and spent + capitalFor(row) <= money then
            chosen[#chosen + 1] = row
            used[row] = true
            spent = spent + capitalFor(row)
        end
    end
    return chosen, spent
end

-- Fills the budget with quick flips first, then spends what's left on buy-and-hold deals.
function Scanner.FitBudget(rows, budget, tick)
    if not budget or budget <= 0 then return rows, nil end
    local flips, holds = {}, {}
    for _, row in ipairs(rows) do
        if row.listing.l then
            if row.flag == "flip" then flips[#flips + 1] = row else holds[#holds + 1] = row end
        end
    end
    local chosenFlips, spent = bestWithin(flips, budget, MAX_PLAN_ITEMS, tick)
    local chosenHolds, spentHolds = bestWithin(holds, budget - spent, MAX_PLAN_ITEMS - #chosenFlips, tick)
    local picked = {}
    for _, row in ipairs(chosenFlips) do picked[row] = true end
    for _, row in ipairs(chosenHolds) do picked[row] = true end
    local fitted, info = {}, { budget = budget, cost = 0, fees = 0, profit = 0, left = 0, skipped = 0 }
    for _, row in ipairs(rows) do
        if picked[row] then
            fitted[#fitted + 1] = row
            local price = row.listing.p * row.listing.q
            info.cost = info.cost + price
            info.fees = info.fees + capitalFor(row) - price
            info.profit = info.profit + row.profit
        else
            info.skipped = info.skipped + 1
        end
    end
    info.left = budget - spent - spentHolds
    return fitted, info
end

-- The buys grouped by trader, most profitable stop first.
function Scanner.Route(rows)
    rows = rows or Scanner.ShoppingList()
    local stops, byTrader = {}, {}
    for _, row in ipairs(rows) do
        local place = row.listing.t .. "|" .. row.listing.z
        local stop = byTrader[place]
        if not stop then
            local progress = Scanner.TraderProgress(row.listing.t, row.listing.z)
            stop = { trader = row.listing.t, zone = row.listing.z, rows = {}, cost = 0, profit = 0,
                npc = progress and progress.npc, town = progress and progress.town }
            byTrader[place] = stop
            stops[#stops + 1] = stop
        end
        stop.rows[#stop.rows + 1] = row
        stop.cost = stop.cost + row.listing.p * row.listing.q
        stop.profit = stop.profit + row.profit
    end
    table.sort(stops, function(a, b)
        if a.profit ~= b.profit then return a.profit > b.profit end
        return a.trader < b.trader
    end)
    return stops
end

-- The stops grouped by zone, with the most profitable zone first.
function Scanner.Zones(stops)
    stops = stops or Scanner.Route()
    local zones, byName = {}, {}
    for _, stop in ipairs(stops) do
        local zone = byName[stop.zone]
        if not zone then
            zone = { name = stop.zone, stops = {}, cost = 0, profit = 0 }
            byName[stop.zone] = zone
            zones[#zones + 1] = zone
        end
        zone.stops[#zone.stops + 1] = stop
        zone.cost, zone.profit = zone.cost + stop.cost, zone.profit + stop.profit
    end
    table.sort(zones, function(a, b)
        if a.profit ~= b.profit then return a.profit > b.profit end
        return a.name < b.name
    end)
    return zones
end

function Scanner.MarkDirty()
    reportDirty = true
end

-- The full report. It's built in the background, so this returns the latest one straight away.
function Scanner.Report()
    local now = GetTimeStamp()
    if report and not reportDirty and now - report.at < REPORT_SECONDS then return report end
    if not Jobs.IsRunning("report") then
        Jobs.Start("report", function(tick)
            reportDirty = false
            local builtAt = GetTimeStamp()
            Selling.Refresh()
            local budget = GP.sv.options.budget or 0
            local rows, stale, hiddenOld, hiddenPrice, warned, hiddenBlacklist = Scanner.ShoppingList(nil, tick)
            local budgetInfo
            rows, budgetInfo = Scanner.FitBudget(rows, budget, tick)
            local stops = Scanner.Route(rows)
            local plan = GP.Interface.BuildPlanLines(tick)
            local farm = GP.Interface.SHOW_EXTRAS and GP.Farm.List(10, tick) or {}
            report = { at = builtAt, rows = rows, stale = stale, hiddenOld = hiddenOld, hiddenPrice = hiddenPrice,
                stops = stops, zones = Scanner.Zones(stops), plan = plan, farm = farm,
                budget = budget, budgetInfo = budgetInfo, warned = warned, hiddenBlacklist = hiddenBlacklist }
            GP.Interface.OnReportReady()
        end)
    end
    return report or EMPTY_REPORT
end

-- Rebuilds shortly after the last page you read, not after every one.
function Scanner.QueueReport()
    reportDirty = true
    if reportQueued then return end
    reportQueued = true
    zo_callLater(function()
        reportQueued = false
        Scanner.Report()
    end, REPORT_DELAY_MS)
end

-- The last report, without recalculating. Used while you page through a trader.
function Scanner.CachedReport()
    return report
end

-- One listing's verdict, for the moment you buy it.
function Scanner.EvaluateListing(id)
    local sv, now, today = GP.sv, GetTimeStamp(), GP.Today()
    local listing = sv.listings[id]
    if not listing or listing.mine then return nil end
    local key = listing.k
    local item = sv.items[key] or { name = listing.n or "Unknown item", r = false, days = {}, weeks = {}, sales = {} }
    local active = 0
    for _, other in pairs(sv.listings) do
        if other.k == key then active = active + 1 end
    end
    local eventActive = GP.Events.Current() ~= nil
    local asks = Scanner.AsksFor(key)
    return Scoring.Evaluate(item, listing, today, active, item.r, eventActive, { asks = asks, id = id, age = ageDays(listing, now) })
end

function Scanner.CurrentPlace()
    local _, traderName = GetCurrentTradingHouseGuildDetails()
    return (traderName or "") .. "|" .. zo_strformat("<<C:1>>", GetUnitZone("player"))
end

function Scanner.IsScanning()
    return scan ~= nil
end

function Scanner.ScanPages()
    return scan and scan.pages or 0
end

local function armScanTimeout()
    scanToken = scanToken + 1
    local token = scanToken
    zo_callLater(function()
        if scan and token == scanToken then Scanner.FinishScan(false, "the trader stopped responding") end
    end, SCAN_TIMEOUT_MS)
end

-- Asks for the next page. The game itself waits out its search cooldown.
function Scanner.NextScanPage()
    armScanTimeout()
    local token = scanToken
    zo_callLater(function()
        if not scan or token ~= scanToken then return end
        local ok = pcall(function() TRADING_HOUSE_SEARCH:SearchNextPage() end)
        if not ok then Scanner.FinishScan(false, "couldn't turn the page") end
    end, SCAN_NEXT_DELAY_MS)
end

function Scanner.FinishScan(completed, problem)
    if not scan then return end
    local finished = scan
    scan = nil
    scanToken = scanToken + 1
    restoreSort = true
    local progress = GP.sv.tour[finished.place]
    if progress then progress.scannedAt = GetTimeStamp() end
    GP.sv.scanStops = GP.sv.scanStops or {}
    GP.sv.scanStops[finished.place] = GetTimeStamp()
    if problem then
        GP.Alert("scan stopped: " .. problem)
    elseif completed then
        GP.Alert("trader scanned, " .. finished.pages .. " pages. Move on to the next one.")
    else
        GP.Alert("scan stopped")
    end
    Scanner.QueueReport()
    Scanner.UpdateScanRow()
    GP.Interface.RefreshPanel()
end

function Scanner.CanStartScan()
    return GP.unlocked and not scan and not GP.Run.IsActive()
end

-- One pass through this trader's newest listings, when you ask for it. B stops it.
function Scanner.StartScan()
    if not Scanner.CanStartScan() then return false end
    local search = rawget(_G, "TRADING_HOUSE_SEARCH")
    local browse = rawget(_G, "GAMEPAD_TRADING_HOUSE_BROWSE")
    local trader = rawget(_G, "TRADING_HOUSE_GAMEPAD")
    if not search or not browse or not trader then return false end
    local place = Scanner.CurrentPlace()
    scan = { place = place, pages = 0 }
    armScanTimeout()
    local ok = pcall(function()
        browse:ResetSearch()
        Scanner.ChooseSort(search)
        trader:EnterBrowseResults()
    end)
    if not ok then
        scan = nil
        scanToken = scanToken + 1
        restoreSort = true
        GP.Alert("couldn't start the scan")
        return false
    end
    Scanner.UpdateScanRow()
    GP.Interface.RefreshPanel()
    return true
end

local function shouldAutoScan()
    if not GP.sv.options.scanOnOpen or not Scanner.CanStartScan() then return false end
    local stops = GP.sv.scanStops
    local lastScan = stops and stops[Scanner.CurrentPlace()]
    return not lastScan or GetTimeStamp() - lastScan >= RESCAN_SECONDS
end

-- Only with "Scan as soon as I open a trader" on. Waits for the Browse tab, then scans once.
local function scheduleAutoScan(tries)
    if not shouldAutoScan() then return end
    zo_callLater(function()
        if not shouldAutoScan() then return end
        local trader = rawget(_G, "TRADING_HOUSE_GAMEPAD")
        local browse = rawget(_G, "GAMEPAD_TRADING_HOUSE_BROWSE")
        local ready = trader and browse and trader.currentListObject == browse
            and TRADING_HOUSE_GAMEPAD_SCENE and TRADING_HOUSE_GAMEPAD_SCENE:IsShowing()
        if ready then
            Scanner.StartScan()
        elseif tries > 1 then
            scheduleAutoScan(tries - 1)
        end
    end, SCAN_OPEN_POLL_MS)
end

function Scanner.UpdateScanRow()
    local browse = rawget(_G, "GAMEPAD_TRADING_HOUSE_BROWSE")
    if browse and browse.keybindStripDescriptor then
        pcall(function() KEYBIND_STRIP:UpdateKeybindButtonGroup(browse.keybindStripDescriptor) end)
    end
end

-- Every handy button on this screen is taken, so the scan is a row in the game's Browse list.
local SCAN_ROW = {
    labelText = "Gold Digger: Scan new listings",
    isSelectableEntry = true,
    onSelectedCallback = function() Scanner.StartScan() end,
    isEnabledCallback = function() return Scanner.CanStartScan() end,
    narrationText = function(entryData)
        return SCREEN_NARRATION_MANAGER:CreateNarratableObject(entryData.labelText)
    end,
}

local LIST_ROW = {
    labelText = "Gold Digger: List what I bought",
    isSelectableEntry = true,
    onSelectedCallback = function() GP.Run.ListNow() end,
    isEnabledCallback = function() return GP.Run.CanList() end,
    narrationText = function(entryData)
        return SCREEN_NARRATION_MANAGER:CreateNarratableObject(entryData.labelText)
    end,
}

local RESTOCK_ROW = {
    labelText = "Gold Digger: Restock materials",
    isSelectableEntry = true,
    onSelectedCallback = function() GP.Run.StartRestock() end,
    isEnabledCallback = function() return GP.unlocked == true and not scan and not GP.Run.IsActive() end,
    narrationText = function(entryData)
        return SCREEN_NARRATION_MANAGER:CreateNarratableObject(entryData.labelText)
    end,
}

local function installScanRow()
    local browse = rawget(_G, "GAMEPAD_TRADING_HOUSE_BROWSE")
    if not browse or not browse.AddEnterSearchHistoryEntry then return end
    if not browse.goldDiggerRow then
        browse.goldDiggerRow = true
        local addHistory = browse.AddEnterSearchHistoryEntry
        browse.AddEnterSearchHistoryEntry = function(self, itemList, ...)
            addHistory(self, itemList, ...)
            scanRowShown = GP.unlocked == true
            -- Players without access never see it
            if scanRowShown then
                itemList:AddEntry("ZO_GamepadGuildStoreBrowseSelectableEntryTemplate", SCAN_ROW)
                itemList:AddEntry("ZO_GamepadGuildStoreBrowseSelectableEntryTemplate", LIST_ROW)
                itemList:AddEntry("ZO_GamepadGuildStoreBrowseSelectableEntryTemplate", RESTOCK_ROW)
            end
        end
    end
    if browse.isInitialized and scanRowShown ~= (GP.unlocked == true) then browse:RefreshList() end
end

local function watchLeaving()
    local trader = rawget(_G, "TRADING_HOUSE_GAMEPAD")
    if not trader or trader.goldDiggerWatched or not trader.LeaveBrowseResults then return end
    trader.goldDiggerWatched = true
    local leave = trader.LeaveBrowseResults
    trader.LeaveBrowseResults = function(self, ...)
        Scanner.FinishScan(false)
        return leave(self, ...)
    end
end

-- The top buys, which are the ones worth price-checking where you sell.
function Scanner.CheckKeys()
    local keys, count = {}, 0
    for _, row in ipairs(report and report.rows or {}) do
        if not keys[row.listing.k] then
            keys[row.listing.k] = true
            count = count + 1
            if count >= CHECK_ROWS then break end
        end
    end
    return keys
end

-- Names of the top buys still waiting for a price check.
function Scanner.UncheckedNames(rows)
    local names, seen = {}, {}
    for _, row in ipairs(rows) do
        if #seen >= CHECK_ROWS then break end
        if not seen[row.listing.k] then
            seen[row.listing.k] = true
            seen[#seen + 1] = row.listing.k
            if not Scanner.CheckFor(row.listing.k) then names[#names + 1] = row.name end
        end
    end
    return names
end

function Scanner.TraderProgress(trader, zone)
    return GP.sv.tour[(trader or "") .. "|" .. (zone or "")]
end

-- How much of the tour has been read.
function Scanner.TourSummary()
    local now, traders, partial, listings = GetTimeStamp(), 0, 0, 0
    for _, progress in pairs(GP.sv.tour) do
        if now - progress.at <= Scanner.STALE_SECONDS then
            traders = traders + 1
            if not progress.done then partial = partial + 1 end
        end
    end
    for _, progress in pairs(GP.sv.tour) do
        if now - progress.at <= Scanner.STALE_SECONDS then listings = listings + (progress.seen or 0) end
    end
    return traders, partial, listings
end

-- Zones you've scanned, for choosing where you sell.
function Scanner.SeenZones()
    local seen, zones = {}, {}
    local function add(zone)
        if zone and zone ~= "" and not seen[zone] then
            seen[zone] = true
            zones[#zones + 1] = zone
        end
    end
    add("Deshaan")
    add(GP.sv.options.sellZone)
    for _, progress in pairs(GP.sv.tour) do add(progress.z) end
    table.sort(zones)
    return zones
end

-- What this item could be listed for right now, where, and the cheapest copy there.
function Scanner.SellPlan(link)
    local key = Scanner.KeyFor(link)
    local item = GP.sv.items[key]
    local rate, source
    if item then rate, source = Scoring.GoingRate(item, GP.Today()) end
    local asks, guild = Scanner.AsksFor(key)
    local target = asks and Scoring.SellTarget(asks, nil, rate, source)
    if not target and rate then target = Scoring.ListAt(rate) end
    return target, guild or Selling.Primary(), asks and asks[1] and asks[1].p or nil
end

function Scanner.SellPriceFor(link)
    return (Scanner.SellPlan(link))
end

-- The items with the most price history, for the history page.
function Scanner.TopItems(limit)
    local rows = {}
    for key, item in pairs(GP.sv.items) do
        local seen = item.n
        if not seen then
            seen = 0
            for _, bucket in pairs(item.days or {}) do seen = seen + bucket.c end
            for _, bucket in pairs(item.weeks or {}) do seen = seen + bucket.c end
        end
        if seen > 0 then rows[#rows + 1] = { key = key, name = item.name, seen = seen } end
    end
    table.sort(rows, function(a, b)
        if a.seen ~= b.seen then return a.seen > b.seen end
        return a.key < b.key
    end)
    for index = #rows, limit + 1, -1 do rows[index] = nil end
    return rows
end

function Scanner.FindRate(link)
    local item = GP.sv.items[Scanner.KeyFor(link)]
    if not item then return nil end
    return (Scoring.GoingRate(item, GP.Today()))
end

-- This week's market price, falling back to the usual rate.
function Scanner.MarketPrice(link)
    local item = GP.sv.items[Scanner.KeyFor(link)]
    if not item then return nil end
    local today = GP.Today()
    local view = History.View(item)
    return Scoring.RecentPrice(view, today) or (Scoring.GoingRate(view, today))
end

local pendingPurchase

local function onResponse(_, responseType, result)
    if result ~= TRADING_HOUSE_RESULT_SUCCESS then
        if responseType == TRADING_HOUSE_RESULT_PURCHASE_PENDING then
            pendingPurchase = nil
            pcall(GP.Run.OnBuyFailed)
        elseif responseType == rawget(_G, "TRADING_HOUSE_RESULT_POST_PENDING") then
            pcall(GP.Run.OnPosted, false)
        end
        return
    end
    if responseType == TRADING_HOUSE_RESULT_SEARCH_PENDING then
        -- Results can read as blank for a moment after the event
        zo_callLater(function() pcall(Scanner.ReadPage) end, READ_DELAY_MS)
    elseif responseType == TRADING_HOUSE_RESULT_PURCHASE_PENDING and pendingPurchase then
        local bought = pendingPurchase
        pendingPurchase = nil
        -- Restocked materials are yours to craft with, so they never go on the sell list
        local ok, recorded = true, true
        if not GP.Run.IsRestocking() then ok, recorded = pcall(GP.Stockpile.OnPurchase, bought) end
        pcall(GP.Run.OnBought, bought, ok and recorded)
    elseif responseType == rawget(_G, "TRADING_HOUSE_RESULT_POST_PENDING") then
        pcall(GP.Run.OnPosted, true)
    end
end

local function watchPurchases()
    local results = GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS
    if not results or results.goldDiggerWatched or not results.ShowPurchaseItemConfirmation then return end
    results.goldDiggerWatched = true
    local confirm = results.ShowPurchaseItemConfirmation
    results.ShowPurchaseItemConfirmation = function(self, data, ...)
        pendingPurchase = nil
        Scanner.FinishScan(false)
        if GP.unlocked and data and not data.isGuildSpecificItem and data.itemUniqueId then
            pendingPurchase = {
                id = Id64ToString(data.itemUniqueId) .. ":" .. data.purchasePrice,
                link = data.itemLink, name = data.name, quantity = data.stackCount, price = data.purchasePrice,
            }
        end
        return confirm(self, data, ...)
    end
end

function Scanner.Install()
    EVENT_MANAGER:RegisterForEvent(GP.NAME .. "Scanner", EVENT_TRADING_HOUSE_RESPONSE_RECEIVED, onResponse)
    EVENT_MANAGER:RegisterForEvent(GP.NAME .. "Scanner", EVENT_OPEN_TRADING_HOUSE, function()
        pcall(watchPurchases)
        pcall(watchSearches)
        pcall(watchLeaving)
        pcall(installScanRow)
        pcall(Scanner.RestoreSort)
        if GP.unlocked then
            pcall(Selling.Refresh)
            Jobs.Start("sales", function(tick) Scanner.ReadSales(tick) end)
            pcall(GP.Stockpile.RecoverReturned)
            if not GP.Run.OnTraderOpen() then scheduleAutoScan(SCAN_OPEN_TRIES) end
        end
    end)
    EVENT_MANAGER:RegisterForEvent(GP.NAME .. "Scanner", EVENT_CLOSE_TRADING_HOUSE, function()
        Scanner.FinishScan(false)
        pcall(GP.Run.OnTraderClose)
        Scanner.QueueReport()
    end)
end
