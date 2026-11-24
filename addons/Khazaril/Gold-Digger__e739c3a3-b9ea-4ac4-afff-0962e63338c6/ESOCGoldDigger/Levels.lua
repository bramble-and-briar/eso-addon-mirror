-- Gold Digger stock levels. Keep at least a set amount of a material, and sell what's above another.
-- It works out what to buy and what to sell. Every purchase and listing is still your button press.

local GP = ESOC_GoldDigger
local Levels = {}
GP.Levels = Levels

local MAX_STACK = 200
local MAX_STACKS_ON_SALE = 2      -- more than this at once would only drive your own price down
local DEFAULT_BUDGET = 100000
local MAX_OVER_USUAL = 1.25       -- restocking won't pay more than this times the usual price
local MIN_GAP = 1.5               -- "sell above" stays well over "keep", so a stack can't be bought then resold
local PENDING_SECONDS = 7 * 86400 -- how long a purchase is assumed to be waiting in the mail
local LEGENDARY = 5
local DEFAULT_WRIT_DAYS = 31
local MAX_WRIT_CHARACTERS = 100
local MAX_WRIT_DAYS = 365

-- What one character uses over the three-day writ rotation: "high" for max-level crafters, "low" for level 1.
-- Crafters are kept at one or the other, so the materials in between are never needed.
-- All armor and weapons use the Breton style, so Molybdenum is the only style material.
-- "protect" items are kept from being sold but never bought from a guild trader: potency runes come
-- from an Enchanter, Molybdenum from a Clothier, and alchemy depends on how many potions you batch.
Levels.WRIT_MATERIALS = {
    { id = 64489, name = "Rubedite Ingot", high = 116, low = 0, sub = 30, level = 1 },
    { id = 64502, name = "Sanded Ruby Ash", high = 112, low = 0, sub = 30, level = 1 },
    { id = 135146, name = "Platinum Ounce", high = 85, low = 0, sub = 30, level = 1 },
    { id = 64504, name = "Ancestor Silk", high = 81, low = 0, sub = 30, level = 1 },
    { id = 64506, name = "Rubedo Leather", high = 39, low = 0, sub = 30, level = 1 },
    { id = 5413, name = "Iron Ingot", high = 0, low = 43, sub = 30, level = 1 },
    { id = 803, name = "Sanded Maple", high = 0, low = 33, sub = 30, level = 1 },
    { id = 811, name = "Jute", high = 0, low = 33, sub = 30, level = 1 },
    { id = 135138, name = "Pewter Ounce", high = 0, low = 17, sub = 30, level = 1 },
    { id = 794, name = "Rawhide", high = 0, low = 15, sub = 30, level = 1 },
    { id = 64509, name = "Rejera", high = 3, low = 0, sub = 308, level = 50, protect = true, vendor = "an Enchanter" },
    { id = 64508, name = "Jehade", high = 1, low = 0, sub = 308, level = 50, protect = true, vendor = "an Enchanter" },
    { id = 45855, name = "Jora", high = 0, low = 3, sub = 20, level = 5, protect = true, vendor = "an Enchanter" },
    { id = 45817, name = "Jode", high = 0, low = 1, sub = 20, level = 5, protect = true, vendor = "an Enchanter" },
    { id = 45850, name = "Ta", high = 4, low = 4, sub = 20, level = 13 },
    { id = 45831, name = "Oko", high = 2, low = 2, sub = 20, level = 46 },
    { id = 45833, name = "Deni", high = 1, low = 1, sub = 20, level = 46 },
    { id = 45832, name = "Makko", high = 1, low = 1, sub = 20, level = 46 },
    { id = 33251, name = "Molybdenum", high = 27, low = 27, sub = 30, level = 1, protect = true, vendor = "a Clothier" },
    { id = 64501, name = "Lorkhan's Tears", high = 3, low = 0, sub = 308, level = 50, protect = true },
    { id = 883, name = "Natural Water", high = 0, low = 3, sub = 30, level = 1, protect = true },
}
local writById = {}
for _, material in ipairs(Levels.WRIT_MATERIALS) do writById[material.id] = material end

Levels.GROUPS = {
    { id = "gold", label = "Gold improvement materials", sell = false, canKeep = true },
    { id = "writ", label = "Writ and crafting materials", sell = false, neverSell = true },
    { id = "style", label = "Style materials", sell = false, neverSell = true },
    { id = "consumable", label = "Alchemy, enchanting and provisioning", sell = 200 },
    { id = "furnishing", label = "Furnishing materials", sell = 0 },
}
local groupById = {}
for _, group in ipairs(Levels.GROUPS) do groupById[group.id] = group end

local TYPE_NAMES = {
    booster = { "ITEMTYPE_BLACKSMITHING_BOOSTER", "ITEMTYPE_CLOTHIER_BOOSTER", "ITEMTYPE_WOODWORKING_BOOSTER",
        "ITEMTYPE_JEWELRYCRAFTING_BOOSTER", "ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER" },
    writ = { "ITEMTYPE_BLACKSMITHING_MATERIAL", "ITEMTYPE_CLOTHIER_MATERIAL", "ITEMTYPE_WOODWORKING_MATERIAL",
        "ITEMTYPE_JEWELRYCRAFTING_MATERIAL", "ITEMTYPE_BLACKSMITHING_RAW_MATERIAL", "ITEMTYPE_CLOTHIER_RAW_MATERIAL",
        "ITEMTYPE_WOODWORKING_RAW_MATERIAL", "ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL" },
    style = { "ITEMTYPE_STYLE_MATERIAL", "ITEMTYPE_RAW_MATERIAL" },
    consumable = { "ITEMTYPE_REAGENT", "ITEMTYPE_POTION_BASE", "ITEMTYPE_POISON_BASE", "ITEMTYPE_INGREDIENT",
        "ITEMTYPE_ENCHANTING_RUNE_ASPECT", "ITEMTYPE_ENCHANTING_RUNE_ESSENCE", "ITEMTYPE_ENCHANTING_RUNE_POTENCY" },
    furnishing = { "ITEMTYPE_FURNISHING_MATERIAL" },
}
local typeGroups

local function store()
    GP.sv.levels = GP.sv.levels or {}
    local saved = GP.sv.levels
    saved.groups, saved.items = saved.groups or {}, saved.items or {}
    saved.pending, saved.known = saved.pending or {}, saved.known or {}
    if saved.budget == nil then saved.budget = DEFAULT_BUDGET end
    return saved
end

function Levels.WritPlan()
    local saved = store()
    return saved.writCharacters or 0, saved.writDays or DEFAULT_WRIT_DAYS, saved.writLowCharacters or 0
end

function Levels.WritActive()
    local high, _, low = Levels.WritPlan()
    return high > 0 or low > 0
end

function Levels.SetWritLowCharacters(value)
    store().writLowCharacters = math.max(0, math.min(math.floor(value), MAX_WRIT_CHARACTERS))
    GP.Scanner.MarkDirty()
end

function Levels.SetWritCharacters(value)
    store().writCharacters = math.max(0, math.min(math.floor(value), MAX_WRIT_CHARACTERS))
    GP.Scanner.MarkDirty()
end

function Levels.SetWritDays(value)
    store().writDays = math.max(1, math.min(math.floor(value), MAX_WRIT_DAYS))
    GP.Scanner.MarkDirty()
end

-- How much of a writ material your characters and buffer days call for.
function Levels.WritNeed(material)
    local high, days, low = Levels.WritPlan()
    return math.ceil((material.high * high + material.low * low) * days / 3)
end

local function writLink(material)
    local ok, link = pcall(GetItemLink, BAG_VIRTUAL, material.id)
    if ok and link and link ~= "" and GetItemLinkItemId(link) == material.id then return link end
    return string.format("|H1:item:%d:%d:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", material.id, material.sub, material.level)
end

function Levels.Budget()
    return store().budget
end

function Levels.SetBudget(value)
    store().budget = value
end

-- Which kind of material this is. Traits and anything else are never sold unless you set a level.
function Levels.GroupFor(link)
    if not typeGroups then
        typeGroups = {}
        for group, names in pairs(TYPE_NAMES) do
            for _, name in ipairs(names) do
                local value = rawget(_G, name)
                if value ~= nil then typeGroups[value] = group end
            end
        end
    end
    local group = typeGroups[GetItemLinkItemType(link)]
    if group == "booster" then
        return GetItemLinkDisplayQuality(link) >= LEGENDARY and "gold" or "writ"
    end
    return group
end

-- keep, then sell. A sell of nil means keep everything.
function Levels.GroupSetting(groupId)
    local group, saved = groupById[groupId], store().groups[groupId]
    if not group then return 0, nil end
    local keep = group.canKeep and saved and saved.keep or 0
    local sell = group.sell
    if saved and saved.sell ~= nil and not group.neverSell then sell = saved.sell end
    if sell == false then sell = nil end
    return keep, sell
end

function Levels.SetGroup(groupId, field, value)
    local groups = store().groups
    groups[groupId] = groups[groupId] or {}
    groups[groupId][field] = value
    GP.Scanner.MarkDirty()
end

-- The levels for one item: keep at least, sell above (nil = never), most to pay each (nil = automatic).
function Levels.For(link)
    local id = GetItemLinkItemId(link)
    local item = store().items[id]
    local material = writById[id]
    -- A level you set on this exact item always wins
    if material and not (item and (item.keep ~= nil or item.sell ~= nil)) then
        local need = Levels.WritActive() and Levels.WritNeed(material) or 0
        -- Not part of your plan, so it's left alone rather than treated as excess
        if need <= 0 then return 0, nil, item and item.maxPrice or nil, true end
        -- Writ materials get used and topped up, so they're never sold as excess
        return need, nil, item and item.maxPrice or nil, material.protect == true
    end
    local keep, sell = Levels.GroupSetting(Levels.GroupFor(link))
    if item then
        if item.keep ~= nil then keep = item.keep end
        if item.sell ~= nil then
            if item.sell == false then sell = nil else sell = item.sell end
        end
    end
    if sell and keep > 0 then sell = math.max(sell, math.ceil(keep * MIN_GAP)) end
    return keep, sell, item and item.maxPrice or nil
end

function Levels.ParseLevel(text)
    local cleaned = string.lower(tostring(text or ""))
    cleaned = string.gsub(cleaned, "%s", "")
    if cleaned == "all" or cleaned == "keepall" or cleaned == "never" then return false end
    return GP.Interface.ParseGold(text)
end

function Levels.FormatLevel(value)
    if value == nil or value == false then return "All" end
    return GP.Interface.ShortGold(value)
end

-- Your backpack, bank and craft bag together.
function Levels.Owned(link)
    local ok, bag, bank, craft = pcall(GetItemLinkStacks, link)
    if not ok then return 0 end
    return (bag or 0) + (bank or 0) + (craft or 0)
end

-- Bought but still in the mail, so it isn't bought twice.
function Levels.Pending(link, owned)
    local pending, id = store().pending, GetItemLinkItemId(link)
    local entry = pending[id]
    if not entry then return 0 end
    owned = owned or Levels.Owned(link)
    local waiting = entry.q - math.max(0, owned - entry.base)
    if waiting <= 0 or GetTimeStamp() - entry.at > PENDING_SECONDS then
        pending[id] = nil
        return 0
    end
    return waiting
end

function Levels.RecordPurchase(link, quantity)
    local pending, id = store().pending, GetItemLinkItemId(link)
    local owned = Levels.Owned(link)
    local entry = pending[id]
    if entry and Levels.Pending(link, owned) > 0 then
        entry.q, entry.at = entry.q + quantity, GetTimeStamp()
    else
        pending[id] = { q = quantity, base = owned, at = GetTimeStamp() }
    end
end

local function remember(link)
    if Levels.GroupFor(link) == "gold" then store().known[GetItemLinkItemId(link)] = link end
end

-- What's below its level right now.
function Levels.Shortfalls()
    local saved, seen, needs = store(), {}, {}
    local function check(id, link)
        if seen[id] or not link then return end
        seen[id] = true
        local keep, sell, maxPrice, protectOnly = Levels.For(link)
        if keep <= 0 or protectOnly then return end
        local owned = Levels.Owned(link)
        local have = owned + Levels.Pending(link, owned)
        if have >= keep then return end
        local need = keep - have
        -- Writ materials are never sold, so a top-up can take a normal full stack
        local room = sell and (sell - have) or (writById[id] and math.max(need, MAX_STACK) or math.ceil(need * MIN_GAP))
        if not maxPrice then
            local usual = GP.Scanner.FindRate(link)
            maxPrice = usual and usual * MAX_OVER_USUAL or nil
        end
        needs[#needs + 1] = {
            id = id, link = link, key = GP.Scanner.KeyFor(link), name = zo_strformat("<<t:1>>", GetItemLinkName(link)),
            need = need, room = math.max(room, need), maxUnit = maxPrice,
        }
    end
    for id, item in pairs(saved.items) do check(id, item.link) end
    for id, link in pairs(saved.known) do check(id, link) end
    if Levels.WritActive() then
        for _, material in ipairs(Levels.WRIT_MATERIALS) do
            if not material.protect then check(material.id, writLink(material)) end
        end
    end
    table.sort(needs, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    return needs
end

function Levels.RestockText()
    local needs, lines = Levels.Shortfalls(), {}
    if #needs == 0 then return "Everything is at or above its stock level." end
    for _, row in ipairs(needs) do
        local limit = row.maxUnit and ("up to " .. GP.Interface.ShortGold(zo_round(row.maxUnit)) .. " each") or "no usual price yet"
        lines[#lines + 1] = row.name .. ": need " .. row.need .. ", " .. limit
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "At a trader, choose Gold Digger: Restock materials."
    return table.concat(lines, "\n")
end

-- Each writ material against what your characters and buffer days call for.
function Levels.WritText()
    local high, days, low = Levels.WritPlan()
    if not Levels.WritActive() then return "Enter how many characters do daily writs to turn this on." end
    local lines = { high .. " max-level and " .. low .. " level 1 characters, " .. days .. " days of supply", "" }
    for _, material in ipairs(Levels.WRIT_MATERIALS) do
        local link = writLink(material)
        local keep, sell, _, protectOnly = Levels.For(link)
        local owned = Levels.Owned(link)
        local have = owned + Levels.Pending(link, owned)
        local status = "OK"
        if have < keep then
            local short = ZO_CommaDelimitNumber(keep - have)
            if material.vendor then
                status = "buy " .. short .. " from " .. material.vendor
            elseif protectOnly then
                status = "low by " .. short
            else
                status = "buy " .. short
            end
        end
        if keep > 0 then
            lines[#lines + 1] = material.name .. ": need " .. ZO_CommaDelimitNumber(keep) .. ", have "
                .. ZO_CommaDelimitNumber(have) .. ", " .. status
        end
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Items marked with an NPC are bought there, not from guild traders. Alchemy solvents are never bought automatically."
    lines[#lines + 1] = "Provisioning and alchemy reagents aren't counted."
    return table.concat(lines, "\n")
end

-- How much of this item must stay put, for telling a returned listing from your own stock.
function Levels.ProtectedAmount(link)
    local _, sell = Levels.For(link)
    return sell or math.huge
end

local excess, excessChecked, tooSmall, noPrice = {}, false, 0, 0

local function stockedAmount(key)
    local total = 0
    for _, entry in ipairs(GP.sv.stock) do
        if GP.Scanner.KeyFor(entry.link) == key then total = total + entry.q end
    end
    return total
end

local function stacksOnSale(key)
    local count, now = 0, GetTimeStamp()
    for _, record in ipairs(GP.sv.listed or {}) do
        if now < record.ends and GP.Scanner.KeyFor(record.link) == key then count = count + 1 end
    end
    return count
end

-- Everything in the craft bag above its "sell above" level that's worth a listing.
function Levels.ScanExcess(tick)
    local rows, smallCount, unpriced = {}, 0, 0
    local minValue = GP.sv.options.minListValue or 0
    local slot = GetNextVirtualBagSlotId(nil)
    while slot do
        if tick then tick() end
        local link = GetItemLink(BAG_VIRTUAL, slot)
        if link and link ~= "" then
            remember(link)
            local _, sell = Levels.For(link)
            local count = GetSlotStackSize(BAG_VIRTUAL, slot) or 0
            if sell and count > 0 and not IsItemLinkBound(link) then
                local key = GP.Scanner.KeyFor(link)
                local claimed = stockedAmount(key)
                local spare = math.min(count - claimed, Levels.Owned(link) - claimed - sell)
                local slots = MAX_STACKS_ON_SALE - stacksOnSale(key)
                if spare > 0 and slots > 0 then
                    local unit = GP.Scanner.SellPriceFor(link)
                    if not unit then
                        unpriced = unpriced + 1
                    else
                        local stacks = {}
                        local left = math.min(spare, MAX_STACK * slots)
                        while left > 0 do
                            local size = math.min(left, MAX_STACK)
                            if unit * size >= minValue then stacks[#stacks + 1] = size end
                            left = left - size
                        end
                        if #stacks == 0 then
                            smallCount = smallCount + 1
                        else
                            local quantity, value = 0, 0
                            for _, size in ipairs(stacks) do quantity, value = quantity + size, value + unit * size end
                            rows[#rows + 1] = {
                                link = link, key = key, name = zo_strformat("<<t:1>>", GetItemLinkName(link)),
                                stacks = stacks, q = quantity, unit = unit, value = value, kept = sell,
                            }
                        end
                    end
                end
            end
        end
        slot = GetNextVirtualBagSlotId(slot)
    end
    table.sort(rows, function(a, b)
        if a.value ~= b.value then return a.value > b.value end
        return a.name < b.name
    end)
    excess, excessChecked, tooSmall, noPrice = rows, true, smallCount, unpriced
    return rows, smallCount, unpriced
end

function Levels.CheckExcess()
    excessChecked = false
    GP.Jobs.Start("levels", function(tick)
        Levels.ScanExcess(tick)
        if GP.ReportScreen.IsShowing() then GP.ReportScreen.Refresh() end
        GP.Interface.Refresh()
    end)
end

function Levels.Excess()
    return excess
end

function Levels.ExcessText()
    if not excessChecked then return "Checking your craft bag. Press X to refresh in a moment." end
    local lines, total = {}, 0
    for _, row in ipairs(excess) do
        total = total + row.value
        lines[#lines + 1] = row.name .. ": sell " .. row.q .. " at " .. GP.Interface.ShortGold(zo_round(row.unit))
            .. " each, about " .. GP.Interface.ShortGold(zo_round(row.value)) .. ". Keeps " .. row.kept
    end
    if #lines == 0 then
        lines[1] = "Nothing above your levels is ready to sell."
    else
        table.insert(lines, 1, "About " .. ZO_CommaDelimitNumber(zo_round(total)) .. " gold before fees")
        table.insert(lines, 2, "")
    end
    if tooSmall > 0 then lines[#lines + 1] = tooSmall .. " more are worth less than your minimum listing value." end
    if noPrice > 0 then lines[#lines + 1] = noPrice .. " more have no price yet. Scan Mournhold to price them." end
    return table.concat(lines, "\n")
end

-- Puts what you've reviewed on the sell list. Nothing is listed until you press A at a guild store.
function Levels.QueueExcess()
    local added = 0
    for _, row in ipairs(excess) do
        for _, size in ipairs(row.stacks) do
            if GP.Stockpile.Add(row.link, row.name, size, 0, "excess", row.unit) then added = added + 1 end
        end
    end
    excess = {}
    if added > 0 then
        GP.Alert(added .. " stacks on your sell list. At a banker, choose List what I bought")
    else
        GP.Alert("nothing to add. Check your excess first")
    end
    GP.Interface.Refresh()
    return added
end

-- Levels for single items, set from the inventory's Actions menu.

function Levels.HasItem(link)
    return store().items[GetItemLinkItemId(link)] ~= nil
end

function Levels.KeepCurrent(link)
    local amount = Levels.Owned(link)
    store().items[GetItemLinkItemId(link)] = { link = link, keep = amount, name = zo_strformat("<<t:1>>", GetItemLinkName(link)) }
    GP.Alert("keeping at least " .. amount .. ". Change it in Stock Levels")
    GP.Interface.Refresh()
end

function Levels.NeverSell(link)
    store().items[GetItemLinkItemId(link)] = { link = link, sell = false, name = zo_strformat("<<t:1>>", GetItemLinkName(link)) }
    GP.Alert("this item will never be sold as excess")
    GP.Interface.Refresh()
end

function Levels.ClearItem(link)
    store().items[GetItemLinkItemId(link)] = nil
    GP.Alert("back to the normal level for this type")
    GP.Interface.Refresh()
end

function Levels.ItemList()
    local list = {}
    for id, item in pairs(store().items) do list[#list + 1] = { id = id, item = item } end
    table.sort(list, function(a, b)
        if a.item.name ~= b.item.name then return a.item.name < b.item.name end
        return a.id < b.id
    end)
    return list
end
