if not SemisPlaygroundCheckAccess() then return end

---Progress for the work panel and a completed quote reusable for split stock.
---@class InventoryPocSearch
---@field item InventoryPocItem
---@field stage 'name'|'search'|'page'|'ready'
---@field hash number|nil
---@field page number
---@field lowest number|nil
---@field seconds number|nil
---@field guildIds number[]
---@field guildIndex number

---@class InventoryPocGuildListings
---@field used number
---@field capacity number
---@field fresh boolean

---@class InventoryPocMarketError
---@field marketError boolean
---@field reason string
---@field result number|nil

---@class InventoryPocMarketIssue
---@field diagnostics string
---@field result number|nil

---@class InventoryPocMarket
---@field search InventoryPocSearch|nil
---@field fiber Fiber<boolean>|nil
---@field requestFiber Fiber<any>|nil Sent server work retains its response subscription until settlement
---@field tried table<string, boolean>
---@field registered boolean
---@field ownRequest boolean
---@field stopped boolean
---@field touched boolean
---@field guildIds number[]|nil
---@field activityGuildId number|nil
---@field listings table<number, InventoryPocGuildListings>
---@field refreshUI boolean
---@field revision number Inventory/reservation changes during an awaited request
---@field phase string|nil
---@field phaseSince number|nil
---@field trace string[]
---@field failureRecorded boolean
local market = { tried = {}, registered = false, ownRequest = false, stopped = false, touched = false,
    listings = {}, refreshUI = false, revision = 0, trace = {}, failureRecorded = false }
BattleScrolls.inventoryPocMarket = market
local poc = BattleScrolls.inventoryPoc
local facts = BattleScrolls.inventoryPocFacts
local policy = BattleScrolls.inventoryPocPolicy
local Effect = LibEffect
local EVENT_NAME = 'BattleScrollsInventoryPocMarket'
local REQUEST_TIMEOUT_MS = 15000

---@param event string
---@param response number|nil
---@param result number|nil
local function trace(event, response, result)
    market.trace[#market.trace + 1] = string.format('%d %s guild=%s response=%s result=%s',
        GetFrameTimeMilliseconds(), event, tostring(GetSelectedTradingHouseGuildId()), tostring(response), tostring(result))
    if #market.trace > 24 then table.remove(market.trace, 1) end
end

---@param phase string
local function setPhase(phase)
    market.phase, market.phaseSince = phase, GetFrameTimeMilliseconds()
    trace(phase)
end

---@param reason string
---@param result number|nil
local function recordFailure(reason, result)
    if market.failureRecorded or not poc.saved then return end
    market.failureRecorded = true
    local search = market.search
    local item = search and search.item
    local native = TRADING_HOUSE_SEARCH
    local awaiting = native.GetAwaitingResponseType and native:GetAwaitingResponseType()
    local diagnostics = string.format('phase=%s reason=%s elapsed=%dms\nguild=%s target=%s awaiting=%s cooldown=%dms cached=%s\n%s',
        tostring(market.phase), reason, GetFrameTimeMilliseconds() - (market.phaseSince or GetFrameTimeMilliseconds()),
        tostring(GetSelectedTradingHouseGuildId()), tostring(market.activityGuildId), tostring(awaiting),
        GetTradingHouseCooldownRemaining(), tostring(HasTradingHouseListings()), table.concat(market.trace, '\n'))
    poc.appendLog({ timestamp = GetTimeStamp(), character = GetUnitName('player'), action = 'keep', result = 'uncertain',
        itemLink = item and item.link or '', itemId = item and item.itemId or 0, quantity = item and item.stack or 0,
        fromBag = item and item.bag or BAG_BACKPACK, guildId = market.activityGuildId,
        marketIssue = { diagnostics = diagnostics, result = result } })
end

---@param reason string
local function fail(reason)
    error({ marketError = true, reason = reason }, 0)
end

local function checkVisit()
    if market.stopped or not poc.enabled or poc.cancelled or GetInteractionType() ~= INTERACTION_TRADINGHOUSE
        or IsUnitInCombat('player') or IsUnitDead('player') then fail('visit-ended') end
end

---Successful posts advance this visit's per-guild listing count.
---@return number used
---@return number capacity
function market.listingCounts()
    local counts = market.listings[GetSelectedTradingHouseGuildId()]
    if counts then return counts.used, counts.capacity end
    return GetTradingHouseListingCounts()
end

---@param guildIds number[]
---@return number
function market.availableListingSlots(guildIds)
    local available = 0
    for _, guildId in ipairs(guildIds) do
        local counts = market.listings[guildId]
        available = available + (counts and math.max(0, counts.capacity - counts.used) or 30)
    end
    return available
end

---Searches, purchases, posts and native listing refreshes share a request channel.
---@return boolean
function market.canRequest()
    return not (market.requestFiber and market.requestFiber:IsRunning())
        and TRADING_HOUSE_SEARCH:CanDoCommonOperation() == true
end

---@return boolean
function market.isWaiting()
    return not market.stopped and (market.fiber ~= nil or not market.canRequest())
end

function market.invalidate()
    market.revision = market.revision + 1
end

---@param reason string|nil
---@param result number|nil
function market.stop(reason, result)
    if reason and (market.fiber or (market.requestFiber and market.requestFiber:IsRunning())) then
        recordFailure(reason, result)
    end
    market.stopped = true
    local fiber = market.fiber
    market.fiber = nil
    if fiber then fiber:Cancel() end
    market.search, market.activityGuildId = nil, nil
end

---Each pricing pass needs access to every configured trading guild.
---@return number[]
local function accessibleGuilds()
    local guildIds, accessible = facts.guildIds(), {}
    for index = 1, GetNumTradingHouseGuilds() do accessible[GetTradingHouseGuildDetails(index)] = true end
    for _, guildId in ipairs(guildIds) do
        if not accessible[guildId] then return {} end
    end
    return guildIds
end

---Recheck readiness after all subscribers have handled the native event.
---A cooldown also has a timer so its expiry can wake us without another event.
---@param searching boolean|nil
---@return Effect<nil>
local function ready(searching)
    return Effect.Async(function()
        while true do
            checkVisit()
            local remaining = searching and GetTradingHouseCooldownRemaining() or 0
            if market.canRequest() and remaining <= 0 then return end
            if market.phase ~= 'ready' then setPhase('ready') end
            local changed = Effect.Events(function(events, resolve)
                local function wake() resolve(nil) end
                events:On(EVENT_TRADING_HOUSE_RESPONSE_RECEIVED, wake)
                events:On(EVENT_TRADING_HOUSE_RESPONSE_TIMEOUT, wake)
                events:On(EVENT_TRADING_HOUSE_OPERATION_TIME_OUT, wake)
                events:On(EVENT_TRADING_HOUSE_SELECTED_GUILD_CHANGED, wake)
                events:On(EVENT_TRADING_HOUSE_SEARCH_COOLDOWN_UPDATE, wake)
                events:On(EVENT_TRADING_HOUSE_STATUS_RECEIVED, wake)
                local pending = market.requestFiber
                if pending then pending:OnComplete(wake) end
                -- Events can finish while this subscription is being scheduled.
                if market.canRequest() and (not searching or GetTradingHouseCooldownRemaining() <= 0) then wake() end
            end)
            if remaining > 0 then
                changed = Effect.Race({ changed, Effect.SleepUntil(GetFrameTimeMilliseconds() + remaining) })
            end
            changed:Await()
        end
    end):Timeout(REQUEST_TIMEOUT_MS * 2)
end

---@generic T
---@param send fun(): T
---@return T
local function issue(send)
    checkVisit()
    market.ownRequest, market.touched = true, true
    local ok, result = pcall(send)
    market.ownRequest = false
    if not ok then error(result, 0) end
    return result
end

---@param events EffectEventScope
---@param reject fun(err: any)
---@param responseType number|nil
local function requestErrors(events, reject, responseType)
    local function rejectRequest(_, result) reject({ marketError = true, reason = 'request-failed', result = result }) end
    local function timeout(_, response)
        if response == nil or response == responseType then reject({ marketError = true, reason = 'response-timeout' }) end
    end
    events:On(EVENT_TRADING_HOUSE_ERROR, rejectRequest)
    events:On(EVENT_TRADING_HOUSE_RESPONSE_TIMEOUT, timeout)
    events:On(EVENT_TRADING_HOUSE_OPERATION_TIME_OUT, timeout)
end

---@generic T
---@param response Effect<T>
---@return Fiber<T>
local function trackRequest(response)
    local fiber = response:Ensure(function() BattleScrolls.gc:RequestGC() end):Run()
    market.requestFiber = fiber
    fiber:OnComplete(function()
        if market.requestFiber == fiber then market.requestFiber = nil; poc.resume() end
    end)
    return fiber
end

---@generic T
---@param register fun(events: EffectEventScope, resolve: fun(value: T), reject: fun(err: any))
---@param searching boolean|nil
---@return Effect<T>
local function awaitResponse(register, searching)
    return Effect.Async(function()
        while true do
            ready(searching):Await()
            local started = false
            local response = Effect.Events(function(events, resolve, reject)
                checkVisit()
                -- Check and send in the same callback. Native screens may send
                -- a request during any earlier Effect scheduling boundary.
                if not TRADING_HOUSE_SEARCH:CanDoCommonOperation()
                    or (searching and GetTradingHouseCooldownRemaining() > 0) then resolve(nil); return end
                started = true
                register(events, resolve, reject)
            end):Timeout(REQUEST_TIMEOUT_MS)
            -- Closing the store cancels the transaction. A sent request keeps
            -- its response subscription so reopening can wait for settlement.
            local fiber = trackRequest(response)
            local result = fiber:Await()
            if started then return result end
        end
    end)
end

---@param guildId number
---@return Effect<nil>
local function selectGuild(guildId)
    return Effect.Async(function()
        ready():Await()
        market.activityGuildId = guildId
        if GetSelectedTradingHouseGuildId() == guildId then return end
        awaitResponse(function(events, resolve, reject)
            if GetSelectedTradingHouseGuildId() == guildId then resolve(nil); return end
            setPhase('guild')
            requestErrors(events, reject)
            events:On(EVENT_TRADING_HOUSE_SELECTED_GUILD_CHANGED, function()
                if GetSelectedTradingHouseGuildId() ~= guildId then fail('guild-changed') end
                resolve(nil)
            end)
            if not issue(function() return SelectTradingHouseGuildId(guildId) end) then fail('guild-unavailable') end
        end):Await()
        ready():Await()
    end)
end

---Listeners precede the send, including APIs which deliver a synchronous reply.
---The response reader captures transient native data before another UI request.
---@generic T
---@param responseType number
---@param guildId number
---@param send fun(): boolean|nil False means validation prevented the send
---@param read fun(): T
---@return Effect<T|nil>
local function request(responseType, guildId, send, read)
    return awaitResponse(function(events, resolve, reject)
        if GetSelectedTradingHouseGuildId() ~= guildId then fail('guild-changed') end
        -- The native listings screen may have supplied this data while we waited.
        if responseType == TRADING_HOUSE_RESULT_LISTINGS_PENDING and HasTradingHouseListings() then
            resolve(read())
            return
        end
        setPhase(responseType == TRADING_HOUSE_RESULT_LISTINGS_PENDING and 'listings'
            or (responseType == TRADING_HOUSE_RESULT_POST_PENDING and 'post' or 'search'))
        requestErrors(events, reject, responseType)
        events:On(EVENT_TRADING_HOUSE_RESPONSE_RECEIVED, function(_, received, result)
            if received ~= responseType then return end
            if result ~= TRADING_HOUSE_RESULT_SUCCESS then
                reject({ marketError = true, reason = 'request-rejected', result = result })
                return
            end
            if GetSelectedTradingHouseGuildId() ~= guildId then fail('guild-changed') end
            resolve(read())
        end)
        if issue(send) == false then resolve(nil) end
    end, responseType == TRADING_HOUSE_RESULT_SEARCH_PENDING)
end

local function readListingCounts()
    local guildId = GetSelectedTradingHouseGuildId()
    if not guildId then return end
    local _, capacity = GetTradingHouseListingCounts()
    market.listings[guildId] = { used = GetNumTradingHouseListings(), capacity = capacity, fresh = true }
end

---@param guildIds number[]
---@return number|nil
local function listingGuild(guildIds)
    for _, guildId in ipairs(guildIds) do
        if CanSellOnTradingHouse(guildId) then
            local counts = market.listings[guildId]
            if not counts or not counts.fresh then
                selectGuild(guildId):Await()
                counts = market.listings[guildId]
                if HasTradingHouseListings() then readListingCounts()
                elseif not counts or not counts.fresh then
                    request(TRADING_HOUSE_RESULT_LISTINGS_PENDING, guildId, RequestTradingHouseListings, readListingCounts):Await()
                end
                counts = market.listings[guildId]
            end
            if counts and counts.used < counts.capacity then return guildId end
        end
    end
end

---@param item InventoryPocItem
---@return boolean
local function companionFilters(item)
    if not SetTradingHouseFilter(TRADING_HOUSE_FILTER_TYPE_GAMEPLAY_ACTOR_CATEGORY, GAMEPLAY_ACTOR_CATEGORY_COMPANION)
        or not SetTradingHouseFilter(TRADING_HOUSE_FILTER_TYPE_QUALITY, GetItemLinkDisplayQuality(item.link))
        or not SetTradingHouseFilter(TRADING_HOUSE_FILTER_TYPE_TRAIT, item.trait) then return false end
    if item.weaponType ~= WEAPONTYPE_NONE then
        return SetTradingHouseFilter(TRADING_HOUSE_FILTER_TYPE_WEAPON, unpack(policy.companionWeaponTypes(item.weaponType)))
    end
    if item.equipType == EQUIP_TYPE_RING or item.equipType == EQUIP_TYPE_NECK then
        return SetTradingHouseFilter(TRADING_HOUSE_FILTER_TYPE_EQUIP, item.equipType)
    end
    return SetTradingHouseFilter(TRADING_HOUSE_FILTER_TYPE_ARMOR, item.armorType)
end

---@param item InventoryPocItem
---@return Effect<number|nil>
local function matchName(item)
    return Effect.Defer(function()
        local taskId
        return Effect.Events(function(events, resolve)
            events:On(EVENT_MATCH_TRADING_HOUSE_ITEM_NAMES_COMPLETE, function(_, id, count)
                if id ~= taskId then return end
                taskId = nil
                for index = 1, count do
                    local name, hash = GetMatchTradingHouseItemNamesResult(id, index)
                    if zo_strformat(SI_TOOLTIP_ITEM_NAME, name) == item.searchName then resolve(hash); return end
                end
                resolve(nil)
            end)
            taskId = MatchTradingHouseItemNames(item.searchName)
            if not taskId then resolve(nil) end
        end):Timeout(REQUEST_TIMEOUT_MS):Ensure(function()
            if taskId then CancelMatchTradingHouseItemNames(taskId) end
        end):Recover(function(err)
            -- Local name matching can be cancelled and skipped safely.
            if Effect.IsTimeoutError(err) then return nil end
            error(err, 0)
        end)
    end)
end

---@class InventoryPocMarketRow
---@field link string
---@field quantity number
---@field seller string
---@field seconds number
---@field total number
---@field currency CurrencyType
---@class InventoryPocMarketPage
---@field rows InventoryPocMarketRow[]
---@field more boolean

---@param search InventoryPocSearch
---@return InventoryPocMarketPage
local function readPage(search)
    local count, page, more = GetTradingHouseSearchResultsInfo()
    if page ~= search.page then fail('page-changed') end
    local rows = {}
    for index = 1, count do
        local link = GetTradingHouseSearchResultItemLink(index, LINK_STYLE_DEFAULT)
        local _, _, _, quantity, seller, seconds, total, currency = GetTradingHouseSearchResultItemInfo(index)
        rows[#rows + 1] = { link = link, quantity = quantity, seller = seller, seconds = seconds, total = total, currency = currency }
    end
    return { rows = rows, more = more }
end

---@param search InventoryPocSearch
---@return boolean complete
local function searchGuilds(search)
    if search.item.kind ~= 'companion' then
        search.hash = matchName(search.item):Await()
        if not search.hash then return false end
    end
    for index, guildId in ipairs(search.guildIds) do
        search.guildIndex, search.page, search.stage = index, 0, 'page'
        selectGuild(guildId):Await()
        while true do
            search.stage = 'page'
            ready(true):Await()
            checkVisit()
            if GetSelectedTradingHouseGuildId() ~= guildId then fail('guild-changed') end
            if search.page == 0 then
                ClearAllTradingHouseSearchTerms()
                local filtered
                if search.item.kind == 'companion' then filtered = companionFilters(search.item)
                else filtered = SetTradingHouseFilter(TRADING_HOUSE_FILTER_TYPE_NAME_HASH, search.hash) end
                if not filtered then return false end
            end
            local page = request(TRADING_HOUSE_RESULT_SEARCH_PENDING, guildId, function()
                search.stage = 'search'
                ExecuteTradingHouseSearch(search.page, TRADING_HOUSE_SORT_SALE_PRICE_PER_UNIT, true, search.page > 0)
            end, function() return readPage(search) end):Await()
            local found = false
            for rowIndex, row in ipairs(page.rows) do
                local variant = facts.variant(row.link)
                local matches = search.item.kind == 'companion' and policy.sameCompanionClass(search.item, variant)
                    or (search.item.kind ~= 'companion' and policy.sameVariant(search.item, variant))
                if row.seller ~= GetDisplayName() and row.quantity > 0 and row.currency == CURT_MONEY and matches then
                    local unit = row.total / row.quantity
                    if policy.validPrice(unit) then
                        found = true
                        if not search.lowest or unit < search.lowest or (unit == search.lowest and row.seconds < search.seconds) then
                            search.lowest, search.seconds = unit, row.seconds
                        end
                    end
                end
                if rowIndex % 10 == 0 then Effect.Yield():Await() end
            end
            if found or not page.more then break end
            if search.page >= 20 then return false end
            search.page = search.page + 1
        end
    end
    search.stage = 'ready'
    return true
end

---@param items InventoryPocItem[]
---@return InventoryPocSearch|nil
local function nextSearch(items)
    for _, item in ipairs(items) do
        local decision = policy.decide(item)
        local key = item.uniqueId .. ':' .. tostring(item.slot) .. ':' .. facts.variantKey(item) .. ':' .. tostring(item.stack)
        if not item.priceLoading and not market.tried[key] and (decision.action == 'list' or (decision.action == 'defer' and decision.reason == 'price'))
            and IsItemSellableOnTradingHouse(item.bag, item.slot) then
            market.tried[key], market.touched = true, true
            return { item = item, stage = 'name', page = 0, guildIds = market.guildIds, guildIndex = 1 }
        end
    end
end

---@param search InventoryPocSearch
---@param guildId number
---@param reserved table<string, boolean>
---@return boolean splitStock
local function post(search, guildId, reserved)
    local current = facts.item(search.item.bag, search.item.slot, reserved)
    if not current or current.uniqueId ~= search.item.uniqueId or current.link ~= search.item.link then return false end
    search.item = current
    local tsc = facts.price(current.link)
    if not policy.validPrice(tsc) and not policy.validPrice(search.lowest) then tsc = policy.fallbackPrice(current) end
    local expired = BattleScrolls.inventoryPocReturns.isDiscounted(current)
    local normal = policy.quote(tsc, search.lowest, search.seconds, current.stack, false)
    local returned = policy.quote(tsc, search.lowest, search.seconds, current.stack, true)
    local priced = expired and returned or normal
    if not priced then return false end
    facts.rememberQuote(current, normal and normal.unitPrice or priced.unitPrice, returned and returned.unitPrice)
    current.marketUnit = priced.unitPrice
    local quantity = policy.listingQuantity(current)
    local quote = policy.quote(tsc, search.lowest, search.seconds, quantity, expired)
    if not quote or quote.totalPrice < policy.MIN_LISTING or policy.decide(current).action ~= 'list' then return false end
    local posted = request(TRADING_HOUSE_RESULT_POST_PENDING, guildId, function()
        return poc.post(current, quote, guildId, reserved)
    end, function() return true end):Await()
    return posted == true and quantity < current.stack
end

---One cancellable program owns a transaction. Runtime inventory events can
---invalidate its snapshot while the outstanding server request finishes.
---@param items InventoryPocItem[]
---@param reserved table<string, boolean>
---@return boolean
function market.step(items, reserved)
    if market.stopped or not poc.enabled or poc.cancelled then return false end
    if market.refreshUI then
        market.refreshUI = false
        BattleScrolls.inventoryPocUI.refreshTradingHouse()
    end
    if market.fiber then return true end
    if not market.guildIds then market.guildIds = accessibleGuilds() end
    if #market.guildIds == 0 then return false end
    local revision = market.revision
    local operation = Effect.Async(function()
        local guildId = listingGuild(market.guildIds)
        if not guildId then market.search = nil; return false end
        if not market.search then
            market.search = nextSearch(items)
            if not market.search then return false end
            if not searchGuilds(market.search) then market.search = nil; return true end
        end
        selectGuild(guildId):Await()
        -- Rebuild reservations after a manual inventory or Wardrobe edit.
        -- Keep rechecking across yields until the snapshot stays current.
        local checked = revision
        while true do
            if checked ~= market.revision then
                checked = market.revision
                local _, refreshed = facts.wardrobe(true)
                reserved = refreshed
            end
            ready():Await()
            if checked == market.revision then break end
        end
        if not post(market.search, guildId, reserved) then market.search = nil end
        return true
    end):Ensure(function() BattleScrolls.gc:RequestGC(2) end)
    local fiber = operation:Run()
    market.fiber = fiber
    fiber:OnComplete(function(completed)
        if market.fiber ~= fiber then return end
        if completed:IsFailed() then
            local err = completed._error
            recordFailure(Effect.IsTimeoutError(err) and 'deadline' or
                (type(err) == 'table' and err.reason or tostring(err)), type(err) == 'table' and err.result or nil)
            market.stopped, market.search = true, nil
            if not Effect.IsTimeoutError(err) and not (type(err) == 'table' and err.marketError) then Effect.RaiseError(err) end
        end
        market.fiber, market.activityGuildId = nil, nil
        if market.refreshUI then
            market.refreshUI = false
            BattleScrolls.inventoryPocUI.refreshTradingHouse()
        end
        poc.resume()
        if completed:IsSucceeded() and not completed._value and revision == market.revision then poc.dirty = false end
        BattleScrolls.inventoryPocWorkUI.refresh()
    end)
    return true
end

local function resetVisit()
    market.stop()
    market.tried, market.stopped, market.touched, market.guildIds = {}, false, false, nil
    market.trace, market.failureRecorded, market.phase, market.phaseSince = {}, false, nil, nil
    for _, counts in pairs(market.listings) do counts.fresh = false end
end

function market.initialize()
    resetVisit()
    if market.registered then return end
    market.registered = true
    for _, entry in ipairs({
        { EVENT_TRADING_HOUSE_AWAITING_RESPONSE, 'awaiting' },
        { EVENT_TRADING_HOUSE_RESPONSE_TIMEOUT, 'response-timeout' },
        { EVENT_TRADING_HOUSE_OPERATION_TIME_OUT, 'operation-timeout' },
        { EVENT_TRADING_HOUSE_ERROR, 'error' },
        { EVENT_TRADING_HOUSE_SELECTED_GUILD_CHANGED, 'guild-changed' },
    }) do
        EVENT_MANAGER:RegisterForEvent(EVENT_NAME, entry[1], function(_, response, result)
            if poc.enabled and GetInteractionType() == INTERACTION_TRADINGHOUSE then trace(entry[2], response, result) end
        end)
    end
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_OPEN_TRADING_HOUSE, function()
        if not poc.enabled then return end
        resetVisit()
        poc.beginVisit()
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_CLOSE_TRADING_HOUSE, function()
        market.stop()
        poc.wake()
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_TRADING_HOUSE_STATUS_RECEIVED, function()
        if not poc.enabled then return end
        market.refreshUI = true
        poc.resume()
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_TRADING_HOUSE_RESPONSE_RECEIVED, function(_, response, result)
        if not poc.enabled then return end
        trace('received', response, result)
        -- These receipts outlive a cancelled program and keep the log and slot
        -- counts accurate for requests already submitted to the server.
        if response == TRADING_HOUSE_RESULT_LISTINGS_PENDING and result == TRADING_HOUSE_RESULT_SUCCESS then
            readListingCounts()
            market.refreshUI = true
        end
        local pending = poc.saved and poc.saved.pending
        if response == TRADING_HOUSE_RESULT_POST_PENDING and pending and pending.action == 'list' and pending.receipt == nil then
            pending.receipt = result == TRADING_HOUSE_RESULT_SUCCESS
            if pending.receipt then
                local counts = market.listings[pending.guildId]
                if counts then counts.used, counts.fresh = counts.used + 1, true end
                market.refreshUI = true
            else market.stop('request-rejected', result) end
        end
        poc.resume()
    end)
    ZO_PreHook('RequestTradingHouseListings', function()
        if not poc.enabled or market.ownRequest or GetInteractionType() ~= INTERACTION_TRADINGHOUSE then return end
        -- The game queues its awaiting-response event. Reserve this channel at
        -- the call so another task cannot start work before that event arrives.
        if market.requestFiber and market.requestFiber:IsRunning() then return true end
        -- Our transaction supplies the listing data and its native response
        -- events also refresh the game's listings panel.
        if market.fiber and not market.stopped and not poc.cancelled then return true end
        if HasTradingHouseListings() then return end
        setPhase('native-listings')
        local fiber = trackRequest(Effect.Events(function(events, resolve, reject)
            requestErrors(events, reject, TRADING_HOUSE_RESULT_LISTINGS_PENDING)
            events:On(EVENT_TRADING_HOUSE_RESPONSE_RECEIVED, function(_, response, result)
                if response ~= TRADING_HOUSE_RESULT_LISTINGS_PENDING then return end
                if result == TRADING_HOUSE_RESULT_SUCCESS then resolve(nil)
                else reject({ marketError = true, reason = 'request-rejected', result = result }) end
            end)
        end):Timeout(REQUEST_TIMEOUT_MS))
        fiber:OnComplete(function(completed)
            if completed:IsFailed() and not market.stopped then
                local err = completed._error
                recordFailure(Effect.IsTimeoutError(err) and 'deadline' or err.reason, err.result)
                market.stop()
                BattleScrolls.inventoryPocWorkUI.refresh()
            end
        end)
    end)
    -- Shared native search state has one owner. External searches, posts and
    -- guild changes end this visit's program. Opening the UI reselects its guild.
    ZO_PreHook('ExecuteTradingHouseSearch', function()
        if poc.enabled and market.search and not market.ownRequest then market.stop() end
    end)
    ZO_PreHook('SelectTradingHouseGuildId', function(guildId)
        if not poc.enabled or market.ownRequest then return end
        if guildId == GetSelectedTradingHouseGuildId() then
            -- SCENE_SHOWING reselects this guild. The native busy check runs
            -- before its equality check and rejects this repeated selection.
            if market.fiber or (market.requestFiber and market.requestFiber:IsRunning()) then
                trace('guild-already-selected')
                return true
            end
        elseif market.touched then market.stop() end
    end)
    ZO_PreHook('RequestPostItemOnTradingHouse', function()
        if poc.enabled and not market.ownRequest then
            market.stop()
            local pending = poc.saved and poc.saved.pending
            if pending and pending.action == 'list' then pending.conflicted = true end
        end
    end)
end
