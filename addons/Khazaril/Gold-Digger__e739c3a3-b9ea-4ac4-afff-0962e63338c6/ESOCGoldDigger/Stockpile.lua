-- Gold Digger stockpile: buy-and-hold purchases, so nothing is forgotten in the chest.

local GP = ESOC_GoldDigger
local Stockpile = {}
GP.Stockpile = Stockpile

local MAX_ENTRIES = 100
local strikeTable
local MAX_LISTED = 150
local RELIST_DISCOUNT = 0.95     -- it didn't sell at the old price
local FORGET_AFTER = 45 * 86400  -- a listing that never came back is dropped from the records
local MAX_STACK = 200
local BLACKLIST_SECONDS = 60 * 86400
local BREAK_EVEN_MARGIN = 1.01

-- Anything bought from the action list is remembered until you've sold it.
function Stockpile.OnPurchase(bought)
    local listing = GP.sv.listings[bought.id]
    local found = listing and GP.Scanner.EvaluateListing(bought.id) or nil
    GP.sv.listings[bought.id] = nil
    if listing then GP.Scanner.RemoveAsk(listing.k, bought.id) end
    local recorded = false
    if found and found.flag then
        recorded = true
        Stockpile.Add(bought.link, bought.name, bought.quantity, bought.price, found.flag, found.sellAt)
        GP.Alert(found.flag == "hold" and "added to your stockpile to hold" or "added to your list to sell")
    end
    GP.Interface.Refresh()
    return recorded
end

function Stockpile.Add(link, name, quantity, totalPrice, kind, sellAt)
    local stock = GP.sv.stock
    if #stock >= MAX_ENTRIES then
        GP.Alert("stockpile is full, remove a sold entry")
        return false
    end
    stock[#stock + 1] = {
        link = link, name = zo_strformat("<<t:1>>", name), q = quantity,
        paid = totalPrice / quantity, at = GetTimeStamp(), kind = kind or "hold", sellAt = sellAt,
    }
    return true
end

function Stockpile.Remove(index)
    if GP.sv.stock[index] then table.remove(GP.sv.stock, index) end
    GP.Interface.Refresh()
end

local function listPrice(entry)
    if entry.kind == "manual" or entry.kind == "excess" then return GP.Scanner.SellPriceFor(entry.link) or entry.sellAt end
    if entry.kind == "flip" then return GP.Scanner.SellPriceFor(entry.link) or entry.sellAt end
    local market = GP.Scanner.MarketPrice(entry.link)
    return market and GP.Scoring.ListAt(market) or nil
end

-- Flips sell once they'd still make money. Held items wait for the event to end and prices to recover.
function Stockpile.IsReady(entry)
    if entry.held then return false end
    if entry.kind == "manual" or entry.kind == "excess" then return true end
    if GP.Events.Current() then return false end
    if entry.kind == "flip" then
        local price = listPrice(entry)
        return price ~= nil and price * (1 - GP.Scoring.SELL_FEE) > entry.paid
    end
    return GP.Scoring.ReadyToSell(entry.paid, GP.Scanner.MarketPrice(entry.link))
end

function Stockpile.Line(entry)
    if entry.held then return "UNSOLD " .. entry.name .. " x" .. entry.q .. ", failed 3 times. Keep, vendor or remove it" end
    local paid = ZO_CommaDelimitNumber(zo_round(entry.paid))
    local text = entry.name .. " x" .. entry.q .. ", paid " .. paid .. " each"
    if entry.kind == "manual" then text = entry.name .. " x" .. entry.q .. ", added by you" end
    if entry.kind == "excess" then text = entry.name .. " x" .. entry.q .. ", excess stock" end
    local price = listPrice(entry)
    if not price then
        if entry.kind == "manual" then
            local how = GP.sv.options.choosePrice and "you set the price" or "uses the game's suggested price"
            return "SELL " .. text .. ", " .. how
        end
        return text .. ", no current price"
    end
    if Stockpile.IsReady(entry) then
        if entry.unsold then text = text .. ", last try" end
        return "SELL " .. text .. ", list at " .. ZO_CommaDelimitNumber(zo_round(entry.relistAt and math.min(price, entry.relistAt) or price))
    end
    return text .. ", now " .. ZO_CommaDelimitNumber(zo_round(price)) .. ", keep holding"
end

function Stockpile.NumReady()
    local count = 0
    for _, entry in ipairs(GP.sv.stock) do
        if Stockpile.IsReady(entry) then count = count + 1 end
    end
    return count
end

-- Items you add yourself, from the inventory's Actions menu.

function Stockpile.FindEntry(link)
    local key = GP.Scanner.KeyFor(link)
    for index, entry in ipairs(GP.sv.stock) do
        if GP.Scanner.KeyFor(entry.link) == key then return index end
    end
    return nil
end

function Stockpile.AddFromBag(bag, slot)
    local link = GetItemLink(bag, slot)
    if not link or link == "" then return false end
    local stack = GetSlotStackSize(bag, slot)
    if not stack or stack <= 0 then return false end
    local quantity = math.min(stack, MAX_STACK)
    if not Stockpile.Add(link, GetItemLinkName(link), quantity, 0, "manual", nil) then return false end
    GP.Alert("added to your stockpile")
    GP.Interface.Refresh()
    return true
end

function Stockpile.RemoveLink(link)
    local index = Stockpile.FindEntry(link)
    if not index then return false end
    Stockpile.Remove(index)
    GP.Alert("removed from your stockpile")
    return true
end

-- The bag, slot and link of an inventory item that can go on the stockpile.
local function stockableItem(inventorySlot)
    if not GP.unlocked or not inventorySlot then return nil end
    local bag, slot = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if bag ~= BAG_BACKPACK and bag ~= BAG_VIRTUAL then return nil end
    local link = GetItemLink(bag, slot)
    if not link or link == "" then return nil end
    if bag == BAG_BACKPACK and not IsItemSellableOnTradingHouse(bag, slot) then return nil end
    if bag == BAG_VIRTUAL and IsItemLinkBound(link) then return nil end
    return bag, slot, link
end

function Stockpile.CanToggle(inventorySlot)
    local ok, bag = pcall(stockableItem, inventorySlot)
    return ok and bag ~= nil
end

function Stockpile.Toggle(inventorySlot)
    local bag, slot, link = stockableItem(inventorySlot)
    if not bag then return false end
    if Stockpile.FindEntry(link) then return Stockpile.RemoveLink(link) end
    return Stockpile.AddFromBag(bag, slot)
end

local function selectedItem()
    local ok, data = pcall(function() return GAMEPAD_INVENTORY:GetCurrentList():GetTargetData() end)
    return ok and data or nil
end

local inventoryButton = {
    alignment = KEYBIND_STRIP_ALIGN_LEFT,
    {
        keybind = "UI_SHORTCUT_QUINARY",
        name = function()
            local ok, bag, _, link = pcall(stockableItem, selectedItem())
            if ok and bag and Stockpile.FindEntry(link) then return "Remove from Stockpile" end
            return "Add to Stockpile"
        end,
        visible = function() return Stockpile.CanToggle(selectedItem()) end,
        callback = function()
            Stockpile.Toggle(selectedItem())
            KEYBIND_STRIP:UpdateKeybindButtonGroup(Stockpile.inventoryButton)
        end,
    },
}
Stockpile.inventoryButton = inventoryButton

-- A one-press button on the inventory screen, on a shortcut the game doesn't use there.
function Stockpile.InstallButton(hook)
    local inventory, scene = rawget(_G, "GAMEPAD_INVENTORY"), rawget(_G, "GAMEPAD_INVENTORY_ROOT_SCENE")
    if not inventory or not scene then return false end
    inventoryButton.alignment = KEYBIND_STRIP_ALIGN_LEFT
    scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING then
            KEYBIND_STRIP:AddKeybindButtonGroup(inventoryButton)
        elseif newState == SCENE_HIDING then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(inventoryButton)
        end
    end)
    local function update() pcall(function() KEYBIND_STRIP:UpdateKeybindButtonGroup(inventoryButton) end) end
    hook(inventory, "OnTargetChanged", update)
    hook(inventory, "RefreshKeybinds", update)
    hook(inventory, "SetSelectedInventoryData", update)
    return true
end

local function addActions(inventorySlot, slotActions)
    if not SCENE_MANAGER:IsShowing("gamepad_inventory_root") then return end
    local bag, slot, link = stockableItem(inventorySlot)
    if not bag then return end
    if Stockpile.FindEntry(link) then
        slotActions:AddSlotAction(SI_GOLD_DIGGER_STOCK_REMOVE, function() Stockpile.RemoveLink(link) end, "secondary")
    else
        slotActions:AddSlotAction(SI_GOLD_DIGGER_STOCK_ADD, function() Stockpile.AddFromBag(bag, slot) end, "secondary")
    end
    if GP.Levels.GroupFor(link) then
        if GP.Levels.HasItem(link) then
            slotActions:AddSlotAction(SI_GOLD_DIGGER_LEVEL_CLEAR, function() GP.Levels.ClearItem(link) end, "secondary")
        else
            slotActions:AddSlotAction(SI_GOLD_DIGGER_LEVEL_KEEP, function() GP.Levels.KeepCurrent(link) end, "secondary")
            slotActions:AddSlotAction(SI_GOLD_DIGGER_LEVEL_NEVER, function() GP.Levels.NeverSell(link) end, "secondary")
        end
    end
end

-- A secure hook, so the game's own item actions keep working normally.
function Stockpile.InstallActions()
    local hook, createString = rawget(_G, "SecurePostHook"), rawget(_G, "ZO_CreateStringId")
    if not hook or not createString then return false end
    createString("SI_GOLD_DIGGER_STOCK_ADD", "Add to Gold Digger stockpile")
    createString("SI_GOLD_DIGGER_STOCK_REMOVE", "Remove from Gold Digger stockpile")
    createString("SI_GOLD_DIGGER_LEVEL_KEEP", "Gold Digger: keep this stock level")
    createString("SI_GOLD_DIGGER_LEVEL_NEVER", "Gold Digger: never sell this")
    createString("SI_GOLD_DIGGER_LEVEL_CLEAR", "Gold Digger: clear stock level")
    hook("CancelTradingHouseListing", function(index) pcall(Stockpile.OnCancel, index) end)
    hook("ZO_InventorySlot_DiscoverSlotActionsFromActionList", function(inventorySlot, slotActions)
        pcall(addActions, inventorySlot, slotActions)
    end)
    pcall(Stockpile.InstallButton, hook)
    return true
end

local function listedRecords()
    GP.sv.listed = GP.sv.listed or {}
    return GP.sv.listed
end

-- Watch list and blacklist. One failed listing goes on the watch list, a second blacklists the item.

strikeTable = function()
    GP.sv.strikes = GP.sv.strikes or {}
    return GP.sv.strikes
end

function Stockpile.IsBlacklisted(key)
    local strikes = strikeTable()
    local strike = strikes[key]
    if not strike or not strike.till then return false end
    if GetTimeStamp() >= strike.till then
        strikes[key] = nil
        return false
    end
    return true
end

function Stockpile.ClearStrike(key)
    strikeTable()[key] = nil
    for _, entry in ipairs(GP.sv.stock) do
        if GP.Scanner.KeyFor(entry.link) == key then entry.held, entry.unsold = nil, nil end
    end
    GP.Scanner.MarkDirty()
end

-- Copies listed together count as one failure. A new strike needs a listing made after the last one.
local function addStrike(record, key)
    local strikes, now = strikeTable(), GetTimeStamp()
    local strike = strikes[key]
    if strike and strike.at and record.at < strike.at then return strike.n end
    strike = strike or { n = 0, name = record.name }
    strike.n, strike.at = strike.n + 1, now
    if strike.n >= 2 then strike.till = now + BLACKLIST_SECONDS end
    strikes[key] = strike
    GP.Scanner.MarkDirty()
    return strike.n
end

function Stockpile.StrikeList()
    local list = {}
    for key, strike in pairs(strikeTable()) do
        if not strike.till or Stockpile.IsBlacklisted(key) then
            list[#list + 1] = { key = key, name = strike.name, n = strike.n, till = strike.till }
        end
    end
    table.sort(list, function(a, b)
        if (a.till ~= nil) ~= (b.till ~= nil) then return a.till ~= nil end
        if a.name ~= b.name then return a.name < b.name end
        return a.key < b.key
    end)
    return list
end

function Stockpile.StrikeLine(row)
    if row.till then
        local days = math.max(1, math.ceil((row.till - GetTimeStamp()) / 86400))
        return "BLACKLIST " .. row.name .. ", " .. days .. " days left"
    end
    return "WATCH " .. row.name .. ", came back once"
end

-- You cancelled it, so it didn't fail to sell.
function Stockpile.OnCancel(index)
    local link = GetTradingHouseListingItemLink(index)
    local _, _, _, stack = GetTradingHouseListingItemInfo(index)
    if not link or link == "" then return false end
    local records, key = listedRecords(), GP.Scanner.KeyFor(link)
    for position = #records, 1, -1 do
        if records[position].q == stack and GP.Scanner.KeyFor(records[position].link) == key then
            table.remove(records, position)
            return true
        end
    end
    return false
end

-- Listings are remembered, so anything that comes back unsold can go back on the sell list.

-- A guild with no trader this week only sells to its members, so a return there proves nothing.
local function guildHasTrader()
    local guildId = GetSelectedTradingHouseGuildId()
    for _, guild in ipairs(GP.Selling.Guilds()) do
        if guild.id == guildId then return guild.kiosk ~= nil end
    end
    return true
end

function Stockpile.CurrentMarket()
    local guildId = GetSelectedTradingHouseGuildId()
    for _, guild in ipairs(GP.Selling.Guilds()) do
        if guild.id == guildId then return GP.Selling.MarketKey(guild) end
    end
    return nil
end

-- The markets where you already have this item on sale.
function Stockpile.ActiveMarkets(link)
    local markets, now, key = {}, GetTimeStamp(), GP.Scanner.KeyFor(link)
    for _, record in ipairs(listedRecords()) do
        if record.market and now < record.ends and GP.Scanner.KeyFor(record.link) == key then
            markets[record.market] = true
        end
    end
    return markets
end

function Stockpile.RecordListing(entry, quantity, price)
    local records, now = listedRecords(), GetTimeStamp()
    records[#records + 1] = {
        link = entry.link, name = entry.name, q = quantity, paid = entry.paid, kind = entry.kind, price = price,
        at = now, ends = now + GP.Scanner.ListingDays() * 86400, hadTrader = guildHasTrader(),
        market = Stockpile.CurrentMarket(),
    }
    while #records > MAX_LISTED do table.remove(records, 1) end
end

-- A sale in your guild's history means that listing won't be coming back.
function Stockpile.MarkSold(link, quantity, time)
    local records = listedRecords()
    local key = GP.Scanner.KeyFor(link)
    local strike = strikeTable()[key]
    -- It sold, so it isn't a dead item after all
    if strike and (not strike.at or time >= strike.at) then Stockpile.ClearStrike(key) end
    for index, record in ipairs(records) do
        if record.q == quantity and record.at <= time and GP.Scanner.KeyFor(record.link) == key then
            table.remove(records, index)
            return true
        end
    end
    return false
end

local function amountsHeld()
    local held = {}
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        local link = GetItemLink(BAG_BACKPACK, slot)
        if link and link ~= "" and IsItemSellableOnTradingHouse(BAG_BACKPACK, slot) then
            local _, stack = GetItemInfo(BAG_BACKPACK, slot)
            local key = GP.Scanner.KeyFor(link)
            held[key] = (held[key] or 0) + (stack or 0)
        end
    end
    return held
end

local function inCraftBag(link)
    local bag, size = rawget(_G, "BAG_VIRTUAL"), rawget(_G, "GetSlotStackSize")
    if bag == nil or not size then return 0 end
    local ok, count = pcall(size, bag, GetItemLinkItemId(link))
    return ok and count or 0
end

-- Puts expired, unsold listings back on the sell list once they're in your backpack or craft bag.
function Stockpile.RecoverReturned()
    local records, now = listedRecords(), GetTimeStamp()
    local anyExpired = false
    for _, record in ipairs(records) do
        if now >= record.ends then anyExpired = true end
    end
    if not anyExpired then return 0 end
    local held, claimed, recovered = amountsHeld(), {}, 0
    for _, entry in ipairs(GP.sv.stock) do
        local key = GP.Scanner.KeyFor(entry.link)
        claimed[key] = (claimed[key] or 0) + entry.q
    end
    for index = #records, 1, -1 do
        local record = records[index]
        if now >= record.ends then
            local key = GP.Scanner.KeyFor(record.link)
            local available = (held[key] or 0) + inCraftBag(record.link) - (claimed[key] or 0)
            -- Excess came from a bag that still holds your kept stock, which isn't a returned listing
            if record.kind == "excess" then available = available - GP.Levels.ProtectedAmount(record.link) end
            if available >= record.q then
                local unit = record.price / record.q
                local kind = (record.kind == "manual" or record.kind == "excess") and record.kind or "flip"
                if Stockpile.Add(record.link, record.name, record.q, record.paid * record.q, kind, unit) then
                    local entry = GP.sv.stock[#GP.sv.stock]
                    if record.hadTrader ~= false then
                        local strikeCount = addStrike(record, key)
                        entry.relistAt = unit * RELIST_DISCOUNT
                        if strikeCount >= 2 then
                            entry.unsold = true
                            if record.paid > 0 then
                                entry.relistAt = record.paid / (1 - GP.Scoring.SELL_FEE) * BREAK_EVEN_MARGIN
                            end
                        end
                        if strikeCount >= 3 then entry.held = true end
                    end
                    claimed[key] = (claimed[key] or 0) + record.q
                    table.remove(records, index)
                    recovered = recovered + 1
                end
            elseif now - record.ends > FORGET_AFTER then
                table.remove(records, index)
            end
        end
    end
    if recovered > 0 then
        GP.Alert(recovered .. " unsold items are back on your sell list. Choose List what I bought")
        GP.Interface.Refresh()
    end
    return recovered
end
