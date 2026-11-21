local LF = LetsFurnish
local ask, L = LF.ask, LF.L
LF.SOURCES = { "backpack", "bank", "vault", "storage", "placed_here", "placed_elsewhere" }
local LABELS = { backpack = L.stock.inventory, bank = L.core.bank, vault = L.stock.vault, storage = L.stock.storage,
                 placed_here = L.stock.placed_here, placed_elsewhere = L.stock.placed_elsewhere }
LF.sourceLabels = LABELS
local open
local function now() return ask(GetTimeStamp) or 0 end
function LF.sourceOn(key)
    return not (type(LF.saved.sources) == "table" and LF.saved.sources[key] == false)
end
function LF.setSource(key, on)
    LF.saved.sources = type(LF.saved.sources) == "table" and LF.saved.sources or {}
    if on then LF.saved.sources[key] = nil else LF.saved.sources[key] = false end
end
local function kept()
    local seen = type(LF.saved.seen) == "table" and LF.saved.seen or {}
    LF.saved.seen = seen
    seen.storage = type(seen.storage) == "table" and seen.storage or {}
    seen.placed = type(seen.placed) == "table" and seen.placed or {}
    return seen
end
local function houseBag(bag) return bag ~= nil and ask(IsHouseBankBag, bag) == true end
local function vaultBag(bag) return bag ~= nil and ask(IsFurnitureVault, bag) == true end
local function bankBag(bag) return bag ~= nil and (bag == BAG_BANK or bag == BAG_SUBSCRIBER_BANK) end
local function ownHouse()
    local id = GetCurrentZoneHouseId()
    if id and id ~= 0 and ask(IsOwnerOfCurrentHouse) then return id end
    return nil
end
local function readBag(bag, into)
    for slot = 0, (bag and ask(GetBagSize, bag) or 0) - 1 do
        local id = ask(GetItemId, bag, slot)
        if id and id ~= 0 and (ask(IsItemPlaceableFurniture, bag, slot) ~= false or (ITEMTYPE_RECIPE and ask(GetItemType, bag, slot) == ITEMTYPE_RECIPE)) then
            local what = "item:" .. tostring(id)
            into[what] = (into[what] or 0) + ((ask(GetSlotStackSize, bag, slot)) or 1)
        end
    end
    return into
end
local function holdsAny(bag)
    for slot = 0, (ask(GetBagSize, bag) or 0) - 1 do
        local id = ask(GetItemId, bag, slot)
        if id and id ~= 0 then return true end
    end
    return false
end
local function placedHere()
    local items = {}
    for _, id in pairs(LF.placedIds()) do
        local what = LF.whatIs(id)
        if what:sub(1, 5) == "item:" then items[what] = (items[what] or 0) + 1 end
    end
    return items
end
local function houseBags()
    local out = {}
    for _, bag in ipairs(LF.bags) do
        if houseBag(bag) then out[#out + 1] = bag end
    end
    return out
end
local fresh = {}
local function keepBag(bag)
    local seen = kept()
    local place = { at = now(), items = readBag(bag, {}), name = LF.bagName(bag) }
    if bankBag(bag) then
        place.items, place.name = readBag(BAG_SUBSCRIBER_BANK, readBag(BAG_BANK, {})), nil
        seen.bank, fresh.bank = place, true
    elseif vaultBag(bag) then
        place.name = nil
        seen.vault, fresh.vault = place, true
    elseif houseBag(bag) then
        local house = ownHouse()
        place.house = house and LF.houseName(house) or nil
        seen.storage[tostring(bag)], fresh["storage:" .. tostring(bag)] = place, true
    end
end
local function refresh()
    fresh = {}
    if bankBag(open) or vaultBag(open) or houseBag(open) then keepBag(open) end
    local house = ownHouse()
    if house then
        for _, bag in ipairs(houseBags()) do
            if bag ~= open and holdsAny(bag) then keepBag(bag) end
        end
        local vault = BAG_FURNITURE_VAULT
        if vault and vault ~= open and vaultBag(vault) and holdsAny(vault) then keepBag(vault) end
        kept().placed[LF.houseKey()] = { at = now(), items = placedHere(), name = LF.houseName(house) }
        fresh["placed_here:" .. LF.houseKey()] = true
    end
end
LF.refreshStock = refresh
local function live(source, key)
    if source == "backpack" then return true end
    return fresh[key and (source .. ":" .. key) or source] == true
end
local function sortedKeys(t)
    local keys = {}
    for key in pairs(t) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
        local na, nb = tonumber(a) or 0, tonumber(b) or 0
        return na < nb or (na == nb and a < b)
    end)
    return keys
end
local function stockGroups()
    local seen = kept()
    local groups = { bank = { [""] = seen.bank }, vault = { [""] = seen.vault }, storage = seen.storage,
                     placed_here = {}, placed_elsewhere = {} }
    local here = ownHouse() and LF.houseKey()
    for key, place in pairs(seen.placed) do
        local group = key == here and groups.placed_here or groups.placed_elsewhere
        group[key] = place
    end
    return groups
end
local function places()
    local groups, out = stockGroups(), {}
    if LF.sourceOn("backpack") then out[#out + 1] = { source = "backpack", label = LABELS.backpack, place = { items = readBag(BAG_BACKPACK, {}) } } end
    for _, source in ipairs(LF.SOURCES) do
        if groups[source] and LF.sourceOn(source) then
            local moved = source == "placed_here" or source == "placed_elsewhere"
            for _, key in ipairs(sortedKeys(groups[source])) do
                local place = groups[source][key]
                out[#out + 1] = { source = source, key = key ~= "" and key or nil, label = tostring(place.name or (moved and key) or LABELS[source]),
                                  place = place, moved = moved }
            end
        end
    end
    return out
end
function LF.held()
    refresh()
    local out = {}
    for _, p in ipairs(places()) do
        if type(p.place) == "table" and type(p.place.items) == "table" and not p.place.changed then
            local at = not live(p.source, p.key) and p.place.at or nil
            for what, n in pairs(p.place.items) do
                if type(n) == "number" and n > 0 then
                    out[what] = out[what] or {}
                    table.insert(out[what], { source = p.source, label = p.label, count = n, at = at, moved = p.moved })
                end
            end
        end
    end
    return out
end
function LF.sourceStates()
    refresh()
    local groups, out = stockGroups(), {}
    for _, key in ipairs(LF.SOURCES) do
        local state = { key = key, label = LABELS[key], state = "never" }
        if not LF.sourceOn(key) then
            state.state = "off"
        elseif key == "backpack" then
            state.state = "now"
        elseif key == "placed_here" and not ownHouse() then
            state.state = "away"
        else
            for k, place in pairs(groups[key]) do
                state.seen = (state.seen or 0) + 1
                if place.changed then
                    state.changed, state.at = (state.changed or 0) + 1, math.min(state.at or place.changed, place.changed)
                elseif not live(key, k ~= "" and k or nil) and type(place.at) == "number" then
                    state.old = math.min(state.old or place.at, place.at)
                end
            end
            if state.seen then
                state.state = state.changed and "changed" or (state.old and "seen" or "now")
                state.at = state.at or state.old
            end
        end
        out[#out + 1] = state
    end
    return out
end
function LF.seenText(at)
    local day = ask(os.date, "%Y-%m-%d", at)
    if day and day == ask(os.date, "%Y-%m-%d", now()) then return zo_strformat(L.stock.today, ask(os.date, "%H:%M", at)) end
    return LF.stamp(at)
end
local function onSlot(_, bag)
    if not LF.saved then return end
    local seen = kept()
    if bankBag(bag) then
        if bankBag(open) then keepBag(bag) elseif seen.bank then seen.bank.changed = seen.bank.changed or now() end
    elseif vaultBag(bag) then
        if vaultBag(open) or ownHouse() then keepBag(bag) elseif seen.vault then seen.vault.changed = seen.vault.changed or now() end
    elseif houseBag(bag) then
        local place = seen.storage[tostring(bag)]
        if open == bag or ownHouse() then keepBag(bag) elseif place then place.changed = place.changed or now() end
    end
end
EVENT_MANAGER:RegisterForEvent(LF.name .. "Stock", EVENT_OPEN_BANK, function(_, bag)
    open = bag
    if LF.saved then keepBag(bag) end
end)
EVENT_MANAGER:RegisterForEvent(LF.name .. "Stock", EVENT_CLOSE_BANK, function() open = nil end)
EVENT_MANAGER:RegisterForEvent(LF.name .. "Stock", EVENT_PLAYER_ACTIVATED, function() open = nil end)
EVENT_MANAGER:RegisterForEvent(LF.name .. "Stock", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, onSlot)
