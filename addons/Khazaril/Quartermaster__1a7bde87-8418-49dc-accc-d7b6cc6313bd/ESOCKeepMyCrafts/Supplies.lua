-- Supplies: keeps lockpicks and filled soul gems to one stack, in the backpack.
--
-- At a merchant: stacks the backpack, sells any second stack, and sells anything over the amount kept
-- (200 soul gems; lockpicks are your choice, 200 by default). Lockpicks below that amount are
-- bought back up to it if this merchant sells them for gold.
-- Filled soul gems can't be bought from merchants. Empty gems, Crown items, locked and stolen stacks are never sold.
--
-- In a group dungeon or trial, a warning goes on screen when you enter with fewer filled soul gems
-- than your chosen minimum (10 by default), when using them takes you below it, and if you run out.

local QM = ESOC_Quartermaster
local Supplies = {}
QM.Supplies = Supplies

Supplies.TARGET = 200 -- a full stack
Supplies.WARN_BELOW = 10

local STACK_WAIT_MS = 700
local SALE_POLL_MS = 100
local SALE_POLLS = 15
local SALE_GAP_MS = 200
local MAX_SALES = 12
local WARN_DELAY_MS = 4000
local RECHECK_MS = 1000

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h, i, j, k, l = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h, i, j, k, l end
    return nil
end

local function money(n)
    local ok, text = pcall(ZO_CommaDelimitNumber, n)
    return ok and text or tostring(n)
end

local function isLockpick(bag, slot)
    return ITEMTYPE_LOCKPICK ~= nil and safe(GetItemType, bag, slot) == ITEMTYPE_LOCKPICK
end

local function isFilledGem(bag, slot)
    return SOUL_GEM_TYPE_FILLED ~= nil and safe(IsItemSoulGem, SOUL_GEM_TYPE_FILLED, bag, slot) == true
end

-- How many lockpicks you chose to keep: 10 to 200, so they always fit in one slot.
function Supplies.LockpickTarget()
    local n = math.floor(tonumber(QM.Options().lockpickAmount) or Supplies.TARGET)
    return math.max(10, math.min(Supplies.TARGET, n))
end

local KINDS = {
    { name = "lockpicks", option = "keepLockpicks", matches = isLockpick, target = Supplies.LockpickTarget },
    { name = "soul gems", option = "keepSoulGems", matches = isFilledGem, target = function() return Supplies.TARGET end },
}

local function isCrown(bag, slot)
    return safe(IsItemFromCrownStore, bag, slot) or safe(IsItemFromCrownCrate, bag, slot)
end

local function canSell(bag, slot)
    if isCrown(bag, slot) or safe(IsItemPlayerLocked, bag, slot) or safe(IsItemStolen, bag, slot) then return false end
    if ITEM_SELL_INFORMATION_CANNOT_SELL ~= nil and safe(GetItemSellInformation, bag, slot) == ITEM_SELL_INFORMATION_CANNOT_SELL then
        return false
    end
    return (safe(GetItemSellValueWithBonuses, bag, slot) or 0) > 0
end

-- Stacks of this kind: sellable ones smallest first, plus the total we hold (Crown items aside).
local function read(kind)
    local stacks, held, sellableTotal = {}, 0, 0
    for slot = 0, (safe(GetBagSize, BAG_BACKPACK) or 0) - 1 do
        if (safe(GetItemId, BAG_BACKPACK, slot) or 0) ~= 0 and kind.matches(BAG_BACKPACK, slot) and not isCrown(BAG_BACKPACK, slot) then
            local _, count = safe(GetItemInfo, BAG_BACKPACK, slot)
            count = count or 0
            held = held + count
            if canSell(BAG_BACKPACK, slot) then
                stacks[#stacks + 1] = { slot = slot, count = count }
                sellableTotal = sellableTotal + count
            end
        end
    end
    table.sort(stacks, function(a, b)
        if a.count ~= b.count then return a.count < b.count end
        return a.slot < b.slot
    end)
    return stacks, held, sellableTotal
end

-- The next sale this kind needs: a whole small stack, or the part of one stack over the target.
function Supplies.NextSale(kind)
    local stacks, _, sellableTotal = read(kind)
    if #stacks > 1 then return stacks[1].slot, stacks[1].count end
    local target = kind.target()
    if #stacks == 1 and sellableTotal > target then return stacks[1].slot, sellableTotal - target end
    return nil
end

local function goldOnly(currencyType)
    return currencyType == nil or currencyType == 0 or (CURT_NONE ~= nil and currencyType == CURT_NONE) or currencyType == CURT_MONEY
end

local function findLockpickEntry()
    for index = 1, safe(GetNumStoreItems) or 0 do
        local link = safe(GetStoreItemLink, index, LINK_STYLE_DEFAULT)
        if link and safe(GetItemLinkItemType, link) == ITEMTYPE_LOCKPICK then
            local _, _, stack, price, _, meetsRequirements, _, _, _, currency1, amount1, currency2 = safe(GetStoreEntryInfo, index)
            local special = not goldOnly(currency1) or (amount1 or 0) > 0 and currency1 ~= CURT_MONEY or not goldOnly(currency2)
            if not special and (price or 0) > 0 and meetsRequirements ~= false then
                return index, price, math.max(stack or 1, 1)
            end
        end
    end
    return nil
end

-- Tops lockpicks up to the amount you keep. Returns a line for chat, or nil.
function Supplies.BuyLockpicks()
    local options = QM.Options()
    if not options.keepLockpicks then return nil end
    local _, held = read(KINDS[1])
    local target = Supplies.LockpickTarget()
    if held >= target then return nil end
    local entry, price, perPurchase = findLockpickEntry()
    if not entry then return nil end -- most merchants don't stock them; no need to say so at each one
    if held == 0 and (safe(GetNumBagFreeSlots, BAG_BACKPACK) or 0) < 1 then
        return "Couldn't buy lockpicks: your bags are full."
    end
    local purchases = math.floor((target - held) / perPurchase)
    local gold = safe(GetCurrencyAmount, CURT_MONEY, CURRENCY_LOCATION_CHARACTER) or 0
    purchases = math.min(purchases, math.floor(gold / price))
    local maxBuyable = safe(GetStoreEntryMaxBuyable, entry)
    if maxBuyable and maxBuyable > 0 then purchases = math.min(purchases, maxBuyable) end
    if purchases < 1 then return "Couldn't buy lockpicks: not enough gold." end
    local ok = pcall(BuyStoreItem, entry, purchases)
    if not ok then return "Couldn't buy lockpicks." end
    local count = purchases * perPurchase
    return string.format("Bought %d lockpick%s for %s gold.", count, count == 1 and "" or "s", money(purchases * price))
end

local running = false

local function finish(lines)
    running = false
    if #lines > 0 then QM.say(table.concat(lines, " ")) end
    if QM.onChanged then pcall(QM.onChanged) end
end

local function buyThenFinish(lines, sold)
    if not QM.IsAtStore() then return finish(lines) end
    for _, kind in ipairs(KINDS) do
        if sold[kind.name] then lines[#lines + 1] = string.format("Sold %d extra %s.", sold[kind.name], kind.name) end
    end
    local line = Supplies.BuyLockpicks()
    if line then lines[#lines + 1] = line end
    finish(lines)
end

local function sellNext(lines, sold, salesLeft)
    if not QM.IsAtStore() then return finish(lines) end
    local kind, slot, quantity
    if salesLeft > 0 then
        for _, candidate in ipairs(KINDS) do
            if QM.Options()[candidate.option] then
                slot, quantity = Supplies.NextSale(candidate)
                if slot then kind = candidate; break end
            end
        end
    end
    if not kind then return buyThenFinish(lines, sold) end
    local _, before = safe(GetItemInfo, BAG_BACKPACK, slot)
    local id = safe(GetItemId, BAG_BACKPACK, slot)
    if not pcall(SellInventoryItem, BAG_BACKPACK, slot, quantity) then return buyThenFinish(lines, sold) end
    -- Wait for this sale to land before counting again, so nothing is ever sold twice.
    local polls = SALE_POLLS
    local function check()
        local _, now = safe(GetItemInfo, BAG_BACKPACK, slot)
        if safe(GetItemId, BAG_BACKPACK, slot) ~= id or (now or 0) < (before or 0) then
            sold[kind.name] = (sold[kind.name] or 0) + quantity
            zo_callLater(function() sellNext(lines, sold, salesLeft - 1) end, SALE_GAP_MS)
        elseif polls > 1 then
            polls = polls - 1
            zo_callLater(check, SALE_POLL_MS)
        else
            buyThenFinish(lines, sold)
        end
    end
    zo_callLater(check, SALE_POLL_MS)
end

-- Runs once the normal selling is done.
function Supplies.Run()
    if running or not QM.IsAtStore() then return end
    if ESOC_Organizer and ESOC_Organizer.IsOrganizing() then return end
    local options = QM.Options()
    if not options.keepLockpicks and not options.keepSoulGems then return end
    running = true
    local needsStacking = false
    for _, kind in ipairs(KINDS) do
        if options[kind.option] and #(read(kind)) > 1 then needsStacking = true end
    end
    local lines, sold = {}, {}
    if needsStacking then
        pcall(StackBag, BAG_BACKPACK)
        zo_callLater(function() sellNext(lines, sold, MAX_SALES) end, STACK_WAIT_MS)
    else
        sellNext(lines, sold, MAX_SALES)
    end
end

---------------------------------------------------------------------------
-- Warning in dungeons and trials
---------------------------------------------------------------------------
function Supplies.FilledGems()
    local total = 0
    for slot = 0, (safe(GetBagSize, BAG_BACKPACK) or 0) - 1 do
        if (safe(GetItemId, BAG_BACKPACK, slot) or 0) ~= 0 and isFilledGem(BAG_BACKPACK, slot) then
            local _, count = safe(GetItemInfo, BAG_BACKPACK, slot)
            total = total + (count or 0)
        end
    end
    return total
end

function Supplies.InGroupContent()
    if safe(IsPlayerInRaid) then return true end
    return safe(IsUnitInDungeon, "player") == true and safe(IsActiveWorldGroupOwnable) == true
end

local function showWarning(gems)
    local title, detail
    if gems == 0 then
        title, detail = "Out of soul gems", "You can't revive anyone until you get more."
    else
        title = "Low on soul gems"
        detail = string.format("You have %d filled. Get more so you can revive your group.", gems)
    end
    QM.say(title .. ": " .. detail)
    pcall(function()
        local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, SOUNDS.GENERAL_ALERT_ERROR)
        params:SetText(title, detail)
        params:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_DISPLAY_ANNOUNCEMENT)
        CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)
    end)
end

function Supplies.WarnAt()
    return tonumber(QM.Options().soulGemWarnAt) or Supplies.WARN_BELOW
end

-- Warned once when you drop below your minimum, and once more if you run out.
local warnedLow, warnedEmpty = false, false

function Supplies.ResetWarning()
    warnedLow, warnedEmpty = false, false
end

function Supplies.CheckWarning()
    if not QM.Options().warnSoulGems or not Supplies.InGroupContent() then return false end
    local gems = Supplies.FilledGems()
    if gems >= Supplies.WarnAt() then
        Supplies.ResetWarning()
        return false
    end
    if gems == 0 then
        if warnedEmpty then return false end
        warnedLow, warnedEmpty = true, true
    else
        warnedEmpty = false
        if warnedLow then return false end
        warnedLow = true
    end
    showWarning(gems)
    return true
end

function QM.InitSupplies()
    if not EVENT_MANAGER or not EVENT_PLAYER_ACTIVATED then return end
    local name = "ESOC_QuartermasterSupplies"
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_ACTIVATED, function()
        Supplies.ResetWarning()
        zo_callLater(function() pcall(Supplies.CheckWarning) end, WARN_DELAY_MS)
    end)
    if EVENT_INVENTORY_SINGLE_SLOT_UPDATE then
        local pending = false
        EVENT_MANAGER:RegisterForEvent(name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(_, bagId)
            if bagId ~= BAG_BACKPACK or pending or not QM.Options().warnSoulGems then return end
            if not Supplies.InGroupContent() then return end
            pending = true
            zo_callLater(function()
                pending = false
                pcall(Supplies.CheckWarning)
            end, RECHECK_MS)
        end)
        if EVENT_MANAGER.AddFilterForEvent and REGISTER_FILTER_BAG_ID then
            pcall(EVENT_MANAGER.AddFilterForEvent, EVENT_MANAGER, name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
        end
    end
end
