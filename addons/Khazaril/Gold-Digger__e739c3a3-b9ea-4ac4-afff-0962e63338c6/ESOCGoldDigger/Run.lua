-- Gold Digger guided run. It remembers what to buy and where, finds each item when you open that
-- trader, and opens the game's own confirm box. Then it does the same for listing what you bought.
-- It never buys or lists anything by itself: every purchase and listing is your button press.

local GP = ESOC_GoldDigger
local Run = {}
GP.Run = Run

local MAX_ITEMS = 40
local MAX_SEARCH_PAGES = 5
local READY_POLL_MS = 400
local READY_TRIES = 12
local SEARCH_TIMEOUT_MS = 15000
local NEXT_ITEM_DELAY_MS = 600
local DIALOG_POLL_MS = 500
local RESULT_GRACE_POLLS = 6
local NEXT_LISTING_DELAY_MS = 900
local FETCH_POLLS = 6
local MAX_STACK = 200
local LISTING_SCENE = "gamepad_trading_house_create_listing"

local state           -- "searching", "confirming" or "posting"
local current         -- the item or stock entry being handled
local token = 0
local searchedPages = 0
local sellVisit = false   -- listing what you've bought at a banker, with more still to buy afterwards
local listingAll = false  -- you asked to list your purchases, so flips are offered even if prices have dipped
local fetchTried = {}     -- stockpile entries already fetched from the craft bag on this visit
local splitTried = {}     -- stockpile entries already split from a merged stack on this visit
local moveLabel           -- what the guide says while an item is being moved
local triedGuilds = {}    -- guilds found full, or out of reach, on this visit
local anyGuildFull = false

local function gold(value)
    return ZO_CommaDelimitNumber(zo_round(value))
end

local function run()
    return GP.sv.run
end

-- The game's price range filter. The buy run sets it to the exact price, then puts it back.
local function setPriceFilter(low, high)
    pcall(function() TRADING_HOUSE_SEARCH.features.priceRangeFeature:SetPriceRange(low, high) end)
end

local function clearPriceFilter()
    setPriceFilter(nil, nil)
end

local function isSelling()
    return run().phase == "sell" or sellVisit
end

function Run.IsActive()
    local r = run()
    return r ~= nil and r.active == true
end

function Run.IsSearching()
    return state == "searching"
end

function Run.IsRestocking()
    local r = run()
    return r ~= nil and r.active == true and r.phase == "restock"
end

local function place(item)
    return item.t .. "|" .. item.z
end

local function nextItem()
    for _, item in ipairs(run().items) do
        if item.status == "todo" then return item end
    end
    return nil
end

local function nextItemHere()
    -- A guild holds one trader, so its name is enough, even if its zone was only known by town
    local here = GP.Scanner.StoreLocation()
    for _, item in ipairs(run().items) do
        if item.status == "todo" and item.t == here then return item end
    end
    return nil
end

local function counts()
    local total, done, profit = 0, 0, 0
    for _, item in ipairs(run().items) do
        total = total + 1
        if item.status ~= "todo" then done = done + 1 end
        if item.status == "todo" or item.status == "bought" then profit = profit + item.profit end
    end
    return total, done, profit
end

local function refresh()
    GP.Interface.RefreshPanel()
end

-- Turns the current report into a checklist, one trader at a time.
function Run.Start()
    local report = GP.Scanner.CachedReport()
    if not report or #report.rows == 0 then
        GP.Alert("nothing to buy yet. Scan some traders first")
        return false
    end
    -- Never start from a list made for a different spending limit
    if (report.budget or 0) ~= (GP.sv.options.budget or 0) then
        GP.Scanner.MarkDirty()
        GP.Scanner.Report()
        GP.Alert("updating the list for your spending limit. Try again in a moment")
        return false
    end
    local items, cost = {}, 0
    for _, zone in ipairs(report.zones) do
        for _, stop in ipairs(zone.stops) do
            for _, row in ipairs(stop.rows) do
                if #items < MAX_ITEMS and row.listing.l then
                    local total = row.listing.p * row.listing.q
                    cost = cost + total
                    items[#items + 1] = {
                        id = row.id, key = row.listing.k, link = row.listing.l, name = row.name, q = row.listing.q,
                        unit = row.listing.p, total = total, sellAt = row.sellAt, profit = row.profit, kind = row.flag,
                        t = row.listing.t, z = row.listing.z, npc = stop.npc, town = stop.town, status = "todo",
                    }
                end
            end
        end
    end
    if #items == 0 then
        GP.Alert("nothing to buy yet. Scan some traders first")
        return false
    end
    GP.sv.run = { active = true, phase = "buy", items = items, cost = cost, started = GetTimeStamp() }
    state, current = nil, nil
    token = token + 1
    local money = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER)
    if money < cost then
        GP.Alert("this run costs " .. gold(cost) .. " and you're carrying " .. gold(money))
    else
        GP.Alert("buy run started: " .. #items .. " items")
    end
    GP.Interface.Refresh()
    return true
end

-- Lists what you've already bought, for when there's no buy run in progress.
function Run.StartSelling()
    if Run.IsActive() then return false end
    if #GP.sv.stock == 0 then
        GP.Alert("nothing to list yet")
        return false
    end
    GP.sv.run = { active = true, phase = "sell", items = {}, cost = 0, started = GetTimeStamp() }
    state, current, sellVisit = nil, nil, false
    listingAll = false
    token = token + 1
    GP.Alert("collect your mail, then open your guild store at any banker")
    GP.Interface.Refresh()
    return true
end

function Run.Stop()
    clearPriceFilter()
    if run() then run().active = false end
    state, current, sellVisit = nil, nil, false
    listingAll = false
    token = token + 1
    GP.Alert("run stopped")
    GP.Interface.Refresh()
end

local function finish()
    clearPriceFilter()
    local total, _, profit = counts()
    run().active = false
    state, current, sellVisit = nil, nil, false
    listingAll = false
    token = token + 1
    if total > 0 then
        GP.Alert("run finished: " .. total .. " items, expected profit " .. gold(profit))
    else
        GP.Alert("selling finished")
    end
    GP.Interface.Refresh()
end

local function traderReady()
    local trader = rawget(_G, "TRADING_HOUSE_GAMEPAD")
    local browse = rawget(_G, "GAMEPAD_TRADING_HOUSE_BROWSE")
    return trader and browse and trader.currentListObject == browse
        and TRADING_HOUSE_GAMEPAD_SCENE and TRADING_HOUSE_GAMEPAD_SCENE:IsShowing()
end

-- Selling can start from whichever tab the store opens on.
local function storeReady()
    return rawget(_G, "TRADING_HOUSE_GAMEPAD") and TRADING_HOUSE_GAMEPAD_SCENE and TRADING_HOUSE_GAMEPAD_SCENE:IsShowing()
end

local function whenReady(fn, tries, isReady, giveUp)
    local thisToken = token
    zo_callLater(function()
        if thisToken ~= token or not Run.IsActive() then return end
        if (isReady or traderReady)() then
            fn()
        elseif tries > 1 then
            whenReady(fn, tries - 1, isReady, giveUp)
        elseif giveUp then
            GP.Alert(giveUp)
        end
    end, READY_POLL_MS)
end

local function afterStop()
    clearPriceFilter()
    state, current = nil, nil
    local following = nextItem()
    if following then
        GP.Alert("all done here. Next: " .. (following.npc or "trader") .. ", " .. following.t .. ", " .. (following.town or following.z))
    else
        run().phase = "sell"
        GP.Alert("buying done. Collect your mail, then open your guild store at any banker")
    end
    refresh()
end

local findCurrent
local restockNext

local function finishRestock()
    local r = run()
    r.active = false
    state, current = nil, nil
    token = token + 1
    if (r.spent or 0) > 0 then
        GP.Alert("restock finished, spent " .. gold(r.spent) .. ". Collect your mail")
    else
        GP.Alert("restock finished, nothing bought")
    end
    GP.Interface.Refresh()
end

local function markGone(item, why)
    item.status = "gone"
    GP.Alert(item.name .. " " .. why)
    state, current = nil, nil
    token = token + 1
    local thisToken = token
    zo_callLater(function()
        if thisToken == token and Run.IsActive() then findCurrent() end
    end, NEXT_ITEM_DELAY_MS)
    refresh()
end

findCurrent = function()
    if Run.IsRestocking() then return restockNext() end
    if not Run.IsActive() or run().phase ~= "buy" then return end
    local item = nextItemHere()
    if not item then return afterStop() end
    token = token + 1
    local thisToken = token
    state, current, searchedPages = "searching", item, 0
    refresh()
    zo_callLater(function()
        if thisToken == token and state == "searching" then markGone(item, "couldn't be found") end
    end, SEARCH_TIMEOUT_MS)
    -- The game's own "search for this item". Its helper does nothing if Browse is already showing,
    -- so this loads the item and runs the search directly. The game waits out its own cooldown.
    local ok = pcall(function()
        TRADING_HOUSE_SEARCH:LoadSearchItem(item.link)
        -- Companion gear and other common names can fill many pages. Searching for the exact
        -- price puts this listing on the first page, however many similar ones there are.
        local low = math.floor(math.min(item.unit, item.total))
        local high = math.ceil(math.max(item.unit, item.total))
        setPriceFilter(low, high)
        pcall(function() GAMEPAD_TRADING_HOUSE_BROWSE:RefreshList() end)
        TRADING_HOUSE_GAMEPAD:EnterBrowseResults()
    end)
    if not ok then markGone(item, "couldn't be searched") end
end

-- The exact listing, or an identical stack at the same price or less.
local function findOnPage(item, numItems)
    local fallback
    for index = 1, numItems or 0 do
        local _, _, _, stack, seller, _, price, _, uniqueId = GetTradingHouseSearchResultItemInfo(index)
        -- The game won't sell you your own listing, so never offer it
        if stack and stack > 0 and seller ~= GetDisplayName() then
            if Id64ToString(uniqueId) .. ":" .. price == item.id then return index end
            if not fallback and stack == item.q and price / stack <= item.unit + 0.001 then
                local link = GetTradingHouseSearchResultItemLink(index)
                if link and link ~= "" and GP.Scanner.KeyFor(link) == item.key then fallback = index end
            end
        end
    end
    return fallback
end

local function watchBuyDialog(thisToken, polls)
    zo_callLater(function()
        if thisToken ~= token or state ~= "confirming" then return end
        if ZO_Dialogs_IsShowing("TRADING_HOUSE_CONFIRM_BUY_ITEM") then
            return watchBuyDialog(thisToken, RESULT_GRACE_POLLS)
        end
        if polls > 1 then return watchBuyDialog(thisToken, polls - 1) end
        -- The box closed and nothing was bought, so you said no to this one
        markGone(current, "skipped")
    end, DIALOG_POLL_MS)
end

local function present(item, index)
    token = token + 1
    local thisToken = token
    state = "confirming"
    local data = ZO_TradingHouse_CreateSearchResultItemData(index)
    if not data then return markGone(item, "has already sold") end
    item.id = Id64ToString(data.itemUniqueId) .. ":" .. data.purchasePrice
    GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS:ShowPurchaseItemConfirmation(data)
    refresh()
    watchBuyDialog(thisToken, RESULT_GRACE_POLLS)
end

-- Restocking: the same steps as a buy run, for whatever is below its stock level at this trader.
restockNext = function()
    if not Run.IsRestocking() then return end
    local item
    for _, candidate in ipairs(run().items) do
        if candidate.status == "todo" then
            item = candidate
            break
        end
    end
    if not item then return finishRestock() end
    token = token + 1
    local thisToken = token
    state, current, searchedPages = "searching", item, 0
    refresh()
    zo_callLater(function()
        if thisToken == token and state == "searching" then markGone(item, "couldn't be found") end
    end, SEARCH_TIMEOUT_MS)
    local ok = pcall(function()
        TRADING_HOUSE_SEARCH:LoadSearchItem(item.link)
        clearPriceFilter()
        pcall(function() GAMEPAD_TRADING_HOUSE_BROWSE:RefreshList() end)
        TRADING_HOUSE_GAMEPAD:EnterBrowseResults()
    end)
    if not ok then markGone(item, "couldn't be searched") end
end

function Run.StartRestock()
    if Run.IsActive() then
        GP.Alert("finish or stop your current run first")
        return false
    end
    if select(5, GP.Scanner.StoreLocation()) then
        GP.Alert("restock at a guild trader. Banks are just for selling")
        return false
    end
    local items = {}
    for _, need in ipairs(GP.Levels.Shortfalls()) do
        items[#items + 1] = {
            link = need.link, key = need.key, name = need.name, need = need.need, room = need.room, maxUnit = need.maxUnit,
            q = need.need, unit = 0, total = 0, profit = 0, t = "", z = "", status = "todo",
        }
    end
    if #items == 0 then
        GP.Alert("everything is at or above its stock level")
        return false
    end
    GP.sv.run = { active = true, phase = "restock", items = items, cost = 0, spent = 0, started = GetTimeStamp() }
    state, current, sellVisit = nil, nil, false
    listingAll = false
    token = token + 1
    GP.Alert("restocking " .. #items .. " materials")
    restockNext()
    return true
end

-- The cheapest fair listing that fits what you need and what's left of your budget.
local function findRestock(item, numItems)
    local budget, spent = GP.Levels.Budget(), run().spent or 0
    local money = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER)
    for index = 1, numItems or 0 do
        local _, _, _, stack, seller, _, price = GetTradingHouseSearchResultItemInfo(index)
        if stack and stack > 0 and seller ~= GetDisplayName() and stack <= item.room and price <= money
            and (budget <= 0 or spent + price <= budget)
            and (not item.maxUnit or price / stack <= item.maxUnit + 0.001) then
            local link = GetTradingHouseSearchResultItemLink(index)
            if link and link ~= "" and GetItemLinkItemId(link) == GetItemLinkItemId(item.link) then
                item.q, item.total, item.unit = stack, price, price / stack
                return index
            end
        end
    end
    return nil
end

-- Called for every trader page that's read.
function Run.OnPage(numItems, _, hasMore)
    if state ~= "searching" or not current then return end
    local item = current
    local restocking = Run.IsRestocking()
    local index
    if restocking then index = findRestock(item, numItems) else index = findOnPage(item, numItems) end
    if index then
        local ok = pcall(present, item, index)
        if not ok then markGone(item, "couldn't be opened") end
        return
    end
    searchedPages = searchedPages + 1
    if hasMore and searchedPages < MAX_SEARCH_PAGES then
        if not pcall(function() TRADING_HOUSE_SEARCH:SearchNextPage() end) then markGone(item, "couldn't be searched") end
    elseif restocking then
        markGone(item, "has no fair listing that fits here")
    else
        markGone(item, "has already sold")
    end
end

function Run.OnBought(bought, recorded)
    if state ~= "confirming" or not current then return end
    local item = current
    if Run.IsRestocking() then
        run().spent = (run().spent or 0) + bought.price
        GP.Levels.RecordPurchase(item.link, bought.quantity)
        if GP.sv.listings[bought.id] then
            GP.Scanner.RemoveAsk(GP.sv.listings[bought.id].k, bought.id)
            GP.sv.listings[bought.id] = nil
        end
        item.need, item.room = item.need - bought.quantity, item.room - bought.quantity
        if item.need <= 0 or item.room <= 0 then item.status = "bought" end
        state, current = nil, nil
        token = token + 1
        local nextToken = token
        GP.Alert("bought " .. item.name .. " x" .. bought.quantity)
        zo_callLater(function()
            if nextToken == token and Run.IsActive() then restockNext() end
        end, NEXT_ITEM_DELAY_MS)
        refresh()
        return
    end
    item.status = "bought"
    if not recorded then GP.Stockpile.Add(item.link, item.name, bought.quantity, bought.price, item.kind, item.sellAt) end
    state, current = nil, nil
    token = token + 1
    local thisToken = token
    GP.Alert("bought " .. item.name)
    zo_callLater(function()
        if thisToken == token and Run.IsActive() then findCurrent() end
    end, NEXT_ITEM_DELAY_MS)
    refresh()
end

function Run.OnBuyFailed()
    if state == "confirming" and current then markGone(current, "couldn't be bought, it may have sold") end
end

-- Selling.

-- How many to put in one listing. Motifs, recipes and furnishings sell one at a time, even if
-- someone listed two by accident. Everything else, like materials, stays together up to a full stack.
local function listingAmount(entry)
    if GP.Scanner.SellsSingly(entry.link) then return 1 end
    local key = GP.Scanner.KeyFor(entry.link)
    local total = 0
    for _, stocked in ipairs(GP.sv.stock) do
        if not stocked.skipped and GP.Scanner.KeyFor(stocked.link) == key then total = total + stocked.q end
    end
    return math.min(math.max(total, entry.q), MAX_STACK)
end

local function findInBackpack(entry)
    local wanted = GP.Scanner.KeyFor(entry.link)
    local amount = listingAmount(entry)
    local best, bestStack
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        local link = GetItemLink(BAG_BACKPACK, slot)
        if link and link ~= "" and GP.Scanner.KeyFor(link) == wanted and IsItemSellableOnTradingHouse(BAG_BACKPACK, slot) then
            local _, stack = GetItemInfo(BAG_BACKPACK, slot)
            if stack == amount then return slot, stack end
            if not best or stack > bestStack then best, bestStack = slot, stack end
        end
    end
    return best, bestStack
end

-- Craft bag slots are numbered by item id.
local function craftBagCount(entry)
    local bag, size = rawget(_G, "BAG_VIRTUAL"), rawget(_G, "GetSlotStackSize")
    if bag == nil or not size then return 0, nil end
    local id = GetItemLinkItemId(entry.link)
    local ok, count = pcall(size, bag, id)
    return ok and count or 0, id
end

local function nextToSell()
    local waiting, notReady = 0, 0
    for _, entry in ipairs(GP.sv.stock) do
        if not entry.skipped and not entry.held then
            if GP.Stockpile.IsReady(entry) or (listingAll and entry.kind == "flip" and entry.sellAt) then
                local slot, stack = findInBackpack(entry)
                if not fetchTried[entry] then
                    local inCraftBag = craftBagCount(entry)
                    if inCraftBag > 0 and (not slot or stack < math.min(listingAmount(entry), inCraftBag)) then
                        return entry, nil, nil, waiting, notReady, true
                    end
                end
                if slot then return entry, slot, stack, waiting, notReady end
                waiting = waiting + 1
            else
                notReady = notReady + 1
            end
        end
    end
    return nil, nil, nil, waiting, notReady
end

local listNext

local function skipListing(entry, why)
    entry.skipped = true
    state, current = nil, nil
    if why then GP.Alert(entry.name .. " " .. why) end
    token = token + 1
    local thisToken = token
    zo_callLater(function()
        if thisToken == token and Run.IsActive() then listNext() end
    end, NEXT_LISTING_DELAY_MS)
end

local function callGame(name, ...)
    local isProtected = rawget(_G, "IsProtectedFunction")
    if isProtected and isProtected(name) then
        local ok, allowed = pcall(CallSecureProtected, name, ...)
        return ok and allowed ~= false
    end
    return (pcall(_G[name], ...))
end

-- Moves part of a stack into its own empty backpack slot, using the game's transfer first.
local function moveToEmptySlot(entry, bag, slotIndex, quantity, label, onFail)
    local empty = FindFirstEmptySlotInBag(BAG_BACKPACK)
    if not empty then return onFail("needs a free backpack slot") end
    token = token + 1
    local thisToken = token
    state, current, moveLabel = "fetching", entry, label
    refresh()
    local moves = {
        function()
            if callGame("PickupInventoryItem", bag, slotIndex, quantity) then
                callGame("PlaceInInventory", BAG_BACKPACK, empty)
            end
            pcall(ClearCursor)
        end,
        function() callGame("RequestMoveItem", bag, slotIndex, BAG_BACKPACK, empty, quantity) end,
    }
    local function attempt(index)
        if not moves[index] then
            state, current = nil, nil
            return onFail("couldn't be moved")
        end
        moves[index]()
        local polls = FETCH_POLLS
        local function check()
            zo_callLater(function()
                if thisToken ~= token or state ~= "fetching" then return end
                local arrived = GetSlotStackSize(BAG_BACKPACK, empty)
                if arrived and arrived >= quantity then
                    state, current = nil, nil
                    listNext()
                elseif polls > 1 then
                    polls = polls - 1
                    check()
                else
                    attempt(index + 1)
                end
            end, READY_POLL_MS)
        end
        check()
    end
    attempt(1)
end

-- Guild stores only list from the backpack, so materials are brought out of the craft bag first.
local function fetchFromCraftBag(entry)
    fetchTried[entry] = true
    local count, id = craftBagCount(entry)
    local quantity = math.min(listingAmount(entry), count, MAX_STACK)
    moveToEmptySlot(entry, BAG_VIRTUAL, id, quantity, "Taking " .. entry.name .. " from your craft bag...", function(why)
        if why == "couldn't be moved" then why = "couldn't be taken from your craft bag. Move it to your backpack and try again" end
        skipListing(entry, why)
    end)
end

-- Identical purchases merge in the backpack, and the store lists a whole stack.
-- So only the amount for this listing is split off, leaving anything else you own.
local function splitStack(entry, slot)
    splitTried[entry] = true
    moveToEmptySlot(entry, BAG_BACKPACK, slot, listingAmount(entry), "Separating " .. entry.name .. "...", function()
        state, current = nil, nil
        GP.Alert(entry.name .. " couldn't be separated, so the whole stack is priced together")
        listNext()
    end)
end

local function watchListing(thisToken, polls)
    zo_callLater(function()
        if thisToken ~= token or state ~= "posting" then return end
        if SCENE_MANAGER:IsShowing(LISTING_SCENE) then return watchListing(thisToken, RESULT_GRACE_POLLS) end
        if polls > 1 then return watchListing(thisToken, polls - 1) end
        skipListing(current, "skipped")
    end, DIALOG_POLL_MS)
end

-- The guild this item should be listed in. Nil means use the store that's open.
local function routeEntry(entry)
    local order = GP.Selling.ListingOrder()
    if #order == 0 then return nil end
    local open = {}
    for _, guild in ipairs(order) do
        if not triedGuilds[guild.id] then open[#open + 1] = guild end
    end
    if #open == 0 then return "none" end
    -- A second copy of a motif in the same market would only compete with the first
    if #order >= 2 and GP.Scanner.SellsSingly(entry.link) then
        local active = GP.Stockpile.ActiveMarkets(entry.link)
        for _, guild in ipairs(open) do
            if not active[GP.Selling.MarketKey(guild)] then return guild end
        end
        return "duplicate"
    end
    return open[1]
end

local function switchGuild(guild)
    pcall(SelectTradingHouseGuildId, guild.id)
    token = token + 1
    local thisToken = token
    -- The game needs a moment to load the other guild's store
    zo_callLater(function()
        if thisToken ~= token or not Run.IsActive() then return end
        if GetSelectedTradingHouseGuildId() ~= guild.id or not CanSellOnTradingHouse(guild.id) then
            triedGuilds[guild.id] = true
        end
        listNext()
    end, READY_POLL_MS)
end

listNext = function()
    if not Run.IsActive() or not isSelling() then return end
    local entry, slot, stack, waiting, notReady, needsFetch = nextToSell()
    if entry then
        local target = routeEntry(entry)
        if target == "duplicate" then
            return skipListing(entry, "is already on sale in each of your markets, so it will wait")
        elseif target == "none" then
            if anyGuildFull then
                GP.Alert("all the guilds you can reach from here are full")
            else
                GP.Alert("you can't list in this store. Open your guild store at a banker")
            end
            refresh()
            return
        elseif target and GetSelectedTradingHouseGuildId() ~= target.id then
            return switchGuild(target)
        end
        local used, maximum = GetTradingHouseListingCounts()
        -- The count can read 0 of 0 until the store has loaded, which doesn't mean it's full
        if used and maximum and maximum > 0 and used >= maximum then
            if not target then
                GP.Alert("this guild store is full, " .. used .. " of " .. maximum .. " listed")
                return
            end
            triedGuilds[target.id], anyGuildFull = true, true
            GP.Alert(target.name .. " is full, " .. used .. " of " .. maximum .. ". Trying your next guild")
            return listNext()
        end
    end
    if needsFetch then return fetchFromCraftBag(entry) end
    if not entry then
        if waiting > 0 then
            GP.Alert(waiting .. " items still in your mail or bank. Put them in your backpack and reopen the store")
            refresh()
            return
        end
        for _, stocked in ipairs(GP.sv.stock) do stocked.skipped = nil end
        if notReady > 0 then
            GP.Alert(notReady .. " items aren't worth listing at today's prices, so they stay in your stockpile")
        end
        if sellVisit and nextItem() then
            sellVisit = false
            state, current = nil, nil
            local following = nextItem()
            GP.Alert("listing done. Next buy: " .. (following.npc or "trader") .. ", " .. following.t .. ", " .. (following.town or following.z))
            refresh()
        else
            finish()
        end
        return
    end
    if stack > listingAmount(entry) and not splitTried[entry] then return splitStack(entry, slot) end
    -- The store lists the whole stack, so the price always covers all of it
    local count = stack
    local unitPrice = GP.Scanner.SellPriceFor(entry.link) or entry.sellAt
    -- Items you add are priced automatically unless you've chosen to set prices yourself
    local choosePrice = entry.kind == "manual" and GP.sv.options.choosePrice == true
    local gamePrice = false
    if not unitPrice and entry.kind == "manual" then
        local market = GP.Scanner.MarketPrice(entry.link)
        if market then unitPrice = GP.Scoring.ListAt(market) end
    end
    if not unitPrice then
        if entry.kind ~= "manual" then return skipListing(entry, "has no price") end
        local ok, suggested = pcall(ZO_TradingHouse_CalculateItemSuggestedPostPrice, BAG_BACKPACK, slot)
        if ok and suggested and suggested > 0 then
            unitPrice, gamePrice = suggested / stack, true
        else
            -- Nothing to go on at all, so never offer it at a throwaway price
            unitPrice, choosePrice = 1, true
        end
    end
    -- If today's price would lose money, offer the price this flip was bought to sell at
    if entry.kind == "flip" and entry.sellAt and unitPrice * (1 - GP.Scoring.SELL_FEE) <= entry.paid then
        unitPrice = entry.sellAt
    end
    -- It came back unsold, so go a little lower, without dropping below what it cost
    if entry.relistAt then
        unitPrice = math.min(unitPrice, entry.relistAt)
        if entry.paid > 0 then unitPrice = math.max(unitPrice, entry.paid / (1 - GP.Scoring.SELL_FEE) * 1.01) end
    end
    local price = math.max(1, math.floor(unitPrice * count))
    local icon = GetItemInfo(BAG_BACKPACK, slot)
    local data = {
        slotIndex = slot, stackCount = count, name = entry.name,
        displayQuality = GetItemLinkDisplayQuality(entry.link), itemData = { iconFile = icon },
    }
    token = token + 1
    local thisToken = token
    state, current = "posting", entry
    current.postCount, current.postPrice, current.choosePrice = count, price, choosePrice or nil
    current.gamePrice = gamePrice or nil
    refresh()
    TRADING_HOUSE_GAMEPAD:SelectHeaderTab(ZO_TRADING_HOUSE_MODE_SELL)
    zo_callLater(function()
        if thisToken ~= token or state ~= "posting" then return end
        ZO_TradingHouse_CreateListing_Gamepad_BeginCreateListing(data, BAG_BACKPACK, slot, price)
        zo_callLater(function()
            if thisToken ~= token or state ~= "posting" then return end
            -- Opens the game's own "list this item?" box with the price filled in
            if not choosePrice then
                pcall(function() TRADING_HOUSE_CREATE_LISTING_GAMEPAD:ShowListItemConfirmation() end)
            end
            watchListing(thisToken, RESULT_GRACE_POLLS)
        end, READY_POLL_MS)
    end, READY_POLL_MS)
end

function Run.OnPosted(success)
    if state ~= "posting" or not current then return end
    local entry = current
    if not success then return skipListing(entry, "couldn't be listed") end
    local sold = entry.postCount or entry.q
    if entry.choosePrice then
        local ok, chosen = pcall(function() return TRADING_HOUSE_CREATE_LISTING_GAMEPAD.listingPrice end)
        if ok and chosen then entry.postPrice = chosen end
        entry.choosePrice = nil
    end
    GP.Stockpile.RecordListing(entry, sold, entry.postPrice or 0)
    if sold >= entry.q then
        local extra = sold - entry.q
        local key = GP.Scanner.KeyFor(entry.link)
        for index = #GP.sv.stock, 1, -1 do
            local stocked = GP.sv.stock[index]
            if stocked == entry then
                table.remove(GP.sv.stock, index)
            elseif extra > 0 and GP.Scanner.KeyFor(stocked.link) == key then
                -- A merged stack sold other entries of the same item with it
                local used = math.min(extra, stocked.q)
                extra = extra - used
                stocked.q = stocked.q - used
                if stocked.q <= 0 then table.remove(GP.sv.stock, index) end
            end
        end
    else
        entry.q = entry.q - sold
        -- There's more of this purchase to separate
        splitTried[entry] = nil
    end
    GP.Alert("listed " .. entry.name .. " for " .. gold(entry.postPrice or 0))
    state, current = nil, nil
    token = token + 1
    local thisToken = token
    zo_callLater(function()
        if thisToken == token and Run.IsActive() then listNext() end
    end, NEXT_LISTING_DELAY_MS)
    refresh()
end

local STORE_STUCK = "the store didn't finish opening. Close it and open it again"

local function beginSelling()
    triedGuilds, anyGuildFull = {}, false
    if #GP.Selling.ListingOrder() > 0 then return listNext() end
    local guild = GP.Selling.Primary()
    local function afterChoosing()
        if not CanSellOnTradingHouse(GetSelectedTradingHouseGuildId()) then
            sellVisit = false
            GP.Alert("you can't list in this store. Open your guild store at a banker")
            refresh()
            return
        end
        listNext()
    end
    if guild and GetSelectedTradingHouseGuildId() ~= guild.id then
        pcall(SelectTradingHouseGuildId, guild.id)
        -- The game needs a moment to load the other guild's store
        local thisToken = token
        zo_callLater(function()
            if thisToken == token and Run.IsActive() then afterChoosing() end
        end, READY_POLL_MS)
    else
        afterChoosing()
    end
end

-- A store you belong to, such as at a banker, rather than another guild's trader.
local function isMyStore()
    local guildId = GetSelectedTradingHouseGuildId()
    local inGuild = rawget(_G, "IsPlayerInGuild")
    if inGuild then return guildId ~= nil and inGuild(guildId) end
    return CanSellOnTradingHouse(guildId)
end

local function pointToNextStop()
    local following = nextItem()
    if following then GP.Alert("not on this stop. Go to " .. (following.npc or "trader") .. ", " .. following.t) end
end

-- A purchase the game confirmed late can be missing from the sell list. If it's in your backpack, add it.
local function adoptPurchases()
    local r = run()
    if not r or not r.items then return end
    local inBag, claimed = {}, {}
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        local link = GetItemLink(BAG_BACKPACK, slot)
        if link and link ~= "" and IsItemSellableOnTradingHouse(BAG_BACKPACK, slot) then
            local _, stack = GetItemInfo(BAG_BACKPACK, slot)
            local key = GP.Scanner.KeyFor(link) .. "x" .. stack
            inBag[key] = (inBag[key] or 0) + 1
        end
    end
    for _, entry in ipairs(GP.sv.stock) do
        local key = GP.Scanner.KeyFor(entry.link) .. "x" .. entry.q
        claimed[key] = (claimed[key] or 0) + 1
    end
    for _, item in ipairs(r.items) do
        if item.status ~= "todo" then
            local key = GP.Scanner.KeyFor(item.link) .. "x" .. item.q
            if (inBag[key] or 0) > (claimed[key] or 0) then
                claimed[key] = (claimed[key] or 0) + 1
                GP.Stockpile.Add(item.link, item.name, item.q, item.total, item.kind, item.sellAt)
            end
        end
    end
end

function Run.CanList()
    return GP.unlocked == true and state ~= "posting" and state ~= "fetching" and not GP.Scanner.IsScanning()
end

-- The "List what I bought" row in the store. Every listing still waits for your press.
function Run.ListNow()
    if not Run.CanList() then return false end
    if not isMyStore() then
        GP.Alert("you can't list in this store. Open your guild store at a banker")
        return false
    end
    adoptPurchases()
    GP.Stockpile.RecoverReturned()
    if #GP.sv.stock == 0 then
        GP.Alert("no purchases on record to list. Items bought without Gold Digger can be listed from the Sell tab")
        return false
    end
    for _, entry in ipairs(GP.sv.stock) do entry.skipped = nil end
    fetchTried, splitTried = {}, {}
    if not Run.IsActive() then
        GP.sv.run = { active = true, phase = "sell", items = {}, cost = 0, started = GetTimeStamp() }
    elseif run().phase ~= "sell" then
        sellVisit = true
    end
    token = token + 1
    state, current, listingAll = nil, nil, true
    beginSelling()
    return true
end

-- Returns true when the run is handling this trader, so the normal scan stays out of the way.
function Run.OnTraderOpen()
    if not Run.IsActive() then return false end
    token = token + 1
    state, current, sellVisit = nil, nil, false
    listingAll = false
    if run().phase == "sell" then
        whenReady(beginSelling, READY_TRIES, storeReady, STORE_STUCK)
    elseif nextItemHere() then
        whenReady(findCurrent, READY_TRIES)
    elseif #GP.sv.stock > 0 then
        -- You can list what you've bought so far at a banker, then carry on buying
        whenReady(function()
            if isMyStore() then
                sellVisit = true
                beginSelling()
            else
                pointToNextStop()
            end
        end, READY_TRIES, storeReady, STORE_STUCK)
    else
        pointToNextStop()
    end
    return true
end

function Run.OnTraderClose()
    if not Run.IsActive() then return end
    clearPriceFilter()
    if Run.IsRestocking() then return finishRestock() end
    state, current, sellVisit = nil, nil, false
    listingAll = false
    token = token + 1
    refresh()
end

-- The short guide at the top of the screen.
function Run.PanelText()
    if not Run.IsActive() then return nil end
    local r = run()
    local total, done, profit = counts()
    if r.phase == "restock" then
        if state == "confirming" and current then
            return "RESTOCK\n" .. current.name .. " x" .. current.q .. " for " .. gold(current.total)
                .. (current.maxUnit and "" or " (no usual price yet)") .. "\nPress A to buy, B to skip."
        end
        if state == "searching" and current then return "RESTOCK\nFinding " .. current.name .. "..." end
        return "RESTOCK\nWorking..."
    end
    if isSelling() then
        if state == "fetching" and current then
            return "SELL RUN\n" .. (moveLabel or ("Moving " .. current.name .. "..."))
        end
        if state == "posting" and current and current.choosePrice then
            return "SELL RUN\nSet a price for " .. current.name .. " x" .. (current.postCount or current.q)
                .. "\nA changes the price, X lists it, B skips."
        end
        if state == "posting" and current then
            return "SELL RUN\nList " .. current.name .. " x" .. (current.postCount or current.q) .. " for " .. gold(current.postPrice or 0)
                .. (current.gamePrice and " (game's suggested price)" or "")
                .. "\nPress A to confirm, B to skip."
        end
        local guild = GP.Selling.Primary()
        local where = guild and ("Guild store: " .. guild.name) or "your guild store"
        return "SELL RUN\nCollect your mail, then open " .. where .. " at any banker."
            .. "\nAlready there? Choose Gold Digger: List what I bought."
    end
    if state == "confirming" and current then
        return "BUY " .. (done + 1) .. " of " .. total .. "\n" .. current.name .. " x" .. current.q .. " for " .. gold(current.total)
            .. "\nProfit " .. gold(current.profit) .. ". Press A to buy, B to skip."
    end
    if state == "searching" and current then
        return "BUY " .. (done + 1) .. " of " .. total .. "\nFinding " .. current.name .. "..."
    end
    local item = nextItem()
    if not item then return "BUY RUN\nFinishing..." end
    local here, names = place(item), {}
    for _, other in ipairs(r.items) do
        if other.status == "todo" and place(other) == here and #names < 3 then names[#names + 1] = other.name end
    end
    local lines = {
        "BUY RUN: " .. done .. " of " .. total .. " done, profit " .. gold(profit),
        "Go to: " .. (item.town and (item.town .. ", ") or "") .. item.z,
        "Trader: " .. (item.npc or "Name not recorded") .. "   Guild: " .. item.t,
        "Buy: " .. table.concat(names, ", "),
    }
    return table.concat(lines, "\n")
end

-- The whole checklist, for the report screen.
function Run.ChecklistText()
    local r = run()
    if not r or not r.items then return "No run yet." end
    local lines, lastPlace = {}, nil
    local marks = { todo = "[ ] ", bought = "[X] ", gone = "[-] " }
    for _, item in ipairs(r.items) do
        if place(item) ~= lastPlace then
            lastPlace = place(item)
            lines[#lines + 1] = ""
            lines[#lines + 1] = "ZONE: " .. string.upper(item.z)
            lines[#lines + 1] = "Trader: " .. (item.npc or "Name not recorded")
            lines[#lines + 1] = "Guild: " .. item.t
            if item.town then lines[#lines + 1] = "Town: " .. item.town end
        end
        lines[#lines + 1] = marks[item.status] .. item.name .. " x" .. item.q .. ", " .. gold(item.total) .. ", +" .. gold(item.profit)
    end
    return table.concat(lines, "\n")
end
