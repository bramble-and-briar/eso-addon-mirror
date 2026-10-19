if not SemisPlaygroundCheckAccess() then return end

---@class InventoryPocSearch
---@field item InventoryPocItem
---@field stage 'name'|'search'|'page'|'ready'
---@field taskId number|nil
---@field hash number|nil
---@field page number
---@field deadline number
---@field lowest number|nil
---@field seconds number|nil

---@class InventoryPocMarket
---@field search InventoryPocSearch|nil
---@field tried table<string, boolean>
---@field registered boolean
---@field ownRequest boolean
---@field stopped boolean
---@field touched boolean
local market = { tried = {}, registered = false, ownRequest = false, stopped = false, touched = false }
BattleScrolls.inventoryPocMarket = market
local poc = BattleScrolls.inventoryPoc
local facts = BattleScrolls.inventoryPocFacts
local policy = BattleScrolls.inventoryPocPolicy
local EVENT_NAME = 'BattleScrollsInventoryPocMarket'

---The native UI also requests listings and purchases. Search cooldown alone
---does not tell us whether that shared request channel is available.
---@return boolean
function market.canRequest()
    return TRADING_HOUSE_SEARCH:CanDoCommonOperation() == true
end

---Only the name lookup and a sent search have response deadlines. Waiting to
---send a page or post a priced item must not consume that response timeout.
---@return boolean
function market.isWaiting()
    if market.stopped then return false end
    local search = market.search
    if search and (search.stage == 'name' or search.stage == 'search') then
        return GetFrameTimeMilliseconds() <= search.deadline
    end
    return not market.canRequest()
        or (search ~= nil and search.stage == 'page' and GetTradingHouseCooldownRemaining() > 0)
end

function market.stop()
    if market.search and market.search.taskId then CancelMatchTradingHouseItemNames(market.search.taskId) end
    market.search = nil
    market.stopped = true
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

---@param search InventoryPocSearch
local function execute(search)
    if not market.canRequest() or GetTradingHouseCooldownRemaining() > 0 then return end
    market.ownRequest = true
    if search.page == 0 then
        ClearAllTradingHouseSearchTerms()
        local filtered
        if search.item.kind == 'companion' then filtered = companionFilters(search.item)
        else filtered = SetTradingHouseFilter(TRADING_HOUSE_FILTER_TYPE_NAME_HASH, search.hash) end
        if not filtered then
            market.ownRequest = false; market.search = nil; return
        end
    end
    search.stage = 'search'
    search.deadline = GetFrameTimeMilliseconds() + 15000
    ExecuteTradingHouseSearch(search.page, TRADING_HOUSE_SORT_SALE_PRICE_PER_UNIT, true, search.page > 0)
    market.ownRequest = false
end

---@param items InventoryPocItem[]
---@param reserved table<string, boolean>
---@return boolean
function market.step(items, reserved)
    if market.stopped or not poc.enabled then return false end
    local search = market.search
    if search and (search.stage == 'name' or search.stage == 'search')
        and GetFrameTimeMilliseconds() > search.deadline then
        -- Do not forget an unanswered server search and immediately send the
        -- next item into the same channel. A name lookup is local and cancels.
        if search.stage == 'search' then market.stop(); return false end
        if search.taskId then CancelMatchTradingHouseItemNames(search.taskId) end
        market.search = nil
        return true
    end
    if not market.canRequest() then return true end
    local guildId = facts.guildId()
    if not guildId or not CanSellOnTradingHouse(guildId) then return false end
    if GetSelectedTradingHouseGuildId() ~= guildId then
        -- Select only a guild offered by this interaction: a different public
        -- kiosk does not become an account bank merely because we know its ID.
        local accessible = false
        for index = 1, GetNumTradingHouseGuilds() do
            if GetTradingHouseGuildDetails(index) == guildId then accessible = true; break end
        end
        if accessible then
            market.ownRequest, market.touched = true, true
            accessible = SelectTradingHouseGuildId(guildId)
            market.ownRequest = false
        end
        return accessible
    end
    local used, capacity = GetTradingHouseListingCounts()
    if used >= capacity then return false end
    if search then
        if search.stage == 'page' then execute(search); return true end
        if search.stage ~= 'ready' then return true end
        local current = facts.item(search.item.bag, search.item.slot, reserved)
        if not current or current.uniqueId ~= search.item.uniqueId or current.link ~= search.item.link then
            market.search = nil
            return true
        end
        search.item = current
        local tsc = facts.price(search.item.link)
        if not policy.validPrice(tsc) and not policy.validPrice(search.lowest) then tsc = policy.fallbackPrice(search.item) end
        local expired = BattleScrolls.inventoryPocReturns.isDiscounted(search.item)
        -- Resolve the discounted unit price before choosing a stack. Preserve
        -- its fractions until the final total, including at the 2,000 boundary.
        local normal = policy.quote(tsc, search.lowest, search.seconds, search.item.stack, false)
        local returned = policy.quote(tsc, search.lowest, search.seconds, search.item.stack, true)
        local priced = normal
        if expired then priced = returned end
        if priced then
            facts.rememberQuote(search.item, normal and normal.unitPrice or priced.unitPrice, returned and returned.unitPrice)
            -- A plan below the learning cutoff after the live search goes back
            -- through learning policy, rather than inheriting a stale TSC ask.
            search.item.marketUnit = priced.unitPrice
            local quantity = policy.listingQuantity(search.item)
            local quote = policy.quote(tsc, search.lowest, search.seconds, quantity, expired)
            if quote and quote.totalPrice >= policy.MIN_LISTING and policy.decide(search.item).action == 'list' then
                market.ownRequest = true
                local posted = poc.post(search.item, quote, guildId, reserved)
                market.ownRequest = false
                if posted and quantity < search.item.stack then
                    -- Reuse the completed search for identical stock, choosing
                    -- the next stack only after the native post receipt.
                    return true
                end
            end
        end
        market.search = nil
        return true
    end
    for _, item in ipairs(items) do
        local decision = policy.decide(item)
        local key = item.uniqueId .. ':' .. tostring(item.slot) .. ':' .. facts.variantKey(item) .. ':' .. tostring(item.stack)
        if not item.priceLoading and not market.tried[key] and (decision.action == 'list' or (decision.action == 'defer' and decision.reason == 'price'))
            and IsItemSellableOnTradingHouse(item.bag, item.slot) then
            market.tried[key], market.touched = true, true
            local state = { item = item, stage = 'name', page = 0, deadline = GetFrameTimeMilliseconds() + 15000 }
            market.search = state
            if item.kind == 'companion' then state.stage = 'page'
            else
                state.taskId = MatchTradingHouseItemNames(item.searchName)
                if not state.taskId then market.search = nil end
            end
            return true
        end
    end
    return false
end

function market.initialize()
    market.stopped = false
    if market.registered then return end
    market.registered = true
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_OPEN_TRADING_HOUSE, function()
        if not poc.enabled then return end
        market.stop()
        market.search, market.tried, market.stopped, market.touched = nil, {}, false, false
        poc.wake()
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_TRADING_HOUSE_SELECTED_GUILD_CHANGED, function()
        if not market.ownRequest then poc.wake() end
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_TRADING_HOUSE_STATUS_RECEIVED, function()
        if not poc.enabled then return end
        BattleScrolls.inventoryPocUI.refreshTradingHouse()
        poc.resume()
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_CLOSE_TRADING_HOUSE, function()
        market.stop()
        poc.wake()
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_MATCH_TRADING_HOUSE_ITEM_NAMES_COMPLETE, function(_, taskId, count)
        local search = market.search
        if not poc.enabled or not search or search.stage ~= 'name' or taskId ~= search.taskId then return end
        search.taskId = nil -- A completed match must not be cancelled on close.
        poc.resume()
        for index = 1, count do
            local name, hash = GetMatchTradingHouseItemNamesResult(taskId, index)
            if zo_strformat(SI_TOOLTIP_ITEM_NAME, name) == search.item.searchName then
                search.hash, search.stage = hash, 'page'
                return
            end
        end
        market.search = nil
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_TRADING_HOUSE_RESPONSE_RECEIVED, function(_, response, result)
        if not poc.enabled then return end
        -- Native listing refreshes share this channel. Their completion also
        -- releases a waiting automated search/post, irrespective of event order.
        poc.resume()
        local pending = poc.saved and poc.saved.pending
        if response == TRADING_HOUSE_RESULT_POST_PENDING and pending and pending.action == 'list' then
            pending.receipt = result == TRADING_HOUSE_RESULT_SUCCESS
            BattleScrolls.inventoryPocUI.refreshTradingHouse()
            return
        end
        local search = market.search
        if response ~= TRADING_HOUSE_RESULT_SEARCH_PENDING or not search or search.stage ~= 'search' then return end
        if result ~= TRADING_HOUSE_RESULT_SUCCESS or GetSelectedTradingHouseGuildId() ~= facts.guildId() then
            market.search = nil; return
        end
        local count, page, more = GetTradingHouseSearchResultsInfo()
        if page ~= search.page then market.stop(); return end
        for index = 1, count do
            local link = GetTradingHouseSearchResultItemLink(index, LINK_STYLE_DEFAULT)
            local _, _, _, quantity, seller, seconds, total, currency = GetTradingHouseSearchResultItemInfo(index)
            local variant = facts.variant(link)
            local matches = search.item.kind == 'companion' and policy.sameCompanionClass(search.item, variant)
                or (search.item.kind ~= 'companion' and policy.sameVariant(search.item, variant))
            if seller ~= GetDisplayName() and quantity > 0 and currency == CURT_MONEY and matches then
                local unit = total / quantity
                if policy.validPrice(unit) and (not search.lowest or unit < search.lowest) then
                    search.lowest, search.seconds = unit, seconds
                end
            end
        end
        -- Sorted by unit price: the first matching competitor is sufficient.
        -- No extra paging just to find a listing with a particular age.
        if search.lowest or not more then search.stage = 'ready'
        elseif search.page < 20 then search.page, search.stage = search.page + 1, 'page'
        else market.search = nil end
    end)
    local function onTimeout(_, response)
        if not poc.enabled then return end
        if response == TRADING_HOUSE_RESULT_SEARCH_PENDING and market.search and market.search.stage == 'search' then
            market.stop()
        end
        poc.resume()
    end
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_TRADING_HOUSE_RESPONSE_TIMEOUT, onTimeout)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_TRADING_HOUSE_OPERATION_TIME_OUT, onTimeout)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_TRADING_HOUSE_ERROR, function()
        if not poc.enabled then return end
        -- A rejected Execute call need not produce RESPONSE_RECEIVED. Never
        -- mistake another request's eventual results for this rejected search.
        if market.search and market.search.stage == 'search' then market.stop() end
        poc.resume()
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_TRADING_HOUSE_SEARCH_COOLDOWN_UPDATE, function(_, remaining)
        if poc.enabled and remaining == 0 then poc.resume() end
    end)
    -- Shared native search state cannot be owned by two callers. A player or
    -- another addon taking over the search ends our work for this visit.
    ZO_PreHook('ExecuteTradingHouseSearch', function()
        if poc.enabled and market.search and not market.ownRequest then market.stop() end
    end)
    ZO_PreHook('SelectTradingHouseGuildId', function(guildId)
        -- SCENE_SHOWING reselects the current guild. Opening/returning to the
        -- native store is not a player taking over with a different guild.
        if poc.enabled and market.touched and not market.ownRequest
            and guildId ~= GetSelectedTradingHouseGuildId() then market.stop() end
    end)
    ZO_PreHook('RequestPostItemOnTradingHouse', function()
        if poc.enabled and not market.ownRequest then
            market.stop()
            local pending = poc.saved and poc.saved.pending
            if pending and pending.action == 'list' then pending.conflicted = true end
        end
    end)
end
