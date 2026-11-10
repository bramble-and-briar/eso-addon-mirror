-- Storage.lua
-- Account-wide storage for the phone app's item search: the bank (plus the ESO+ bank), the craft bag,
-- and house storage chests and coffers.
--
-- The bank and craft bag can be read anywhere. A house chest can only be read while it is open, so each
-- time you open one the addon saves a snapshot (SavedVariables) and sends it with every storage sync,
-- marked with when it was last seen.
--
-- Text format: one record per line, fields separated by tabs.
--   V    format  apiVersion  timestamp  account
--   SET  setId  setName                                       (each set once)
--   LOC  key  kind  name  house  seenTimestamp                 kind: bank | craft | chest
--   I    key  itemId  count  itemName  quality  setId  traitName
--
-- QR chunk header: ESOCB1 <account> <index>/<total>

ESOC_Storage = ESOC_Storage or {}
local ST = ESOC_Storage

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g end
    return nil
end

local function fmt(s)
    local ok, r = pcall(zo_strformat, "<<1>>", s or "")
    return ok and r or (s or "")
end

-- One item as a list of fields: itemId, count, name, quality, setId, setName, traitName
local function readSlot(bag, slot)
    local id = safe(GetItemId, bag, slot)
    if not id or id == 0 then return nil end
    local link = safe(GetItemLink, bag, slot) or ""
    local hasSet, setName, _, _, _, setId = safe(GetItemLinkSetInfo, link, false)
    local trait = safe(GetItemTrait, bag, slot) or 0
    local traitName = (trait ~= 0) and (safe(GetString, "SI_ITEMTRAITTYPE", trait) or "") or ""
    local _, count = safe(GetItemInfo, bag, slot)
    count = count or safe(GetSlotStackSize, bag, slot) or 1
    return { id, count, fmt(safe(GetItemName, bag, slot)), safe(GetItemDisplayQuality, bag, slot) or 0,
        (hasSet and setId) or 0, hasSet and fmt(setName) or "", traitName }
end
ST.readSlot = readSlot

local function readBag(bag)
    local items = {}
    for slot = 0, (safe(GetBagSize, bag) or 0) - 1 do
        local it = readSlot(bag, slot)
        if it then items[#items + 1] = it end
    end
    return items
end

local function readCraftBag()
    local items = {}
    if not BAG_VIRTUAL or not safe(HasCraftBagAccess) then return items end
    local slot = safe(GetNextVirtualBagSlotId, nil)
    local guard = 0
    while slot and guard < 5000 do
        local it = readSlot(BAG_VIRTUAL, slot)
        if it then items[#items + 1] = it end
        slot = safe(GetNextVirtualBagSlotId, slot)
        guard = guard + 1
    end
    return items
end

-- Name of the chest or coffer behind a house bank bag, and the house it's in.
local function chestNames(bag)
    local name
    local collectibleId = safe(GetCollectibleForHouseBankBag, bag)
    if collectibleId and collectibleId ~= 0 then
        local nick = safe(GetCollectibleNickname, collectibleId)
        name = (nick and nick ~= "") and nick or fmt(safe(GetCollectibleName, collectibleId))
    end
    if not name or name == "" then
        name = "Storage " .. (BAG_HOUSE_BANK_ONE and (bag - BAG_HOUSE_BANK_ONE + 1) or bag)
    end
    local house = ""
    local houseId = safe(GetCurrentZoneHouseId)
    if houseId and houseId ~= 0 then house = fmt(safe(GetCollectibleName, safe(GetCollectibleIdForHouse, houseId))) end
    return fmt(name), house
end

local sv
local openBag

-- Save what is in an open house chest.
function ST.SnapshotChest(bag)
    if not sv or not bag or not safe(IsHouseBankBag, bag) then return false end
    local name, house = chestNames(bag)
    sv.chests = sv.chests or {}
    local rows = {}
    for _, it in ipairs(readBag(bag)) do
        for i = 1, #it do it[i] = tostring(it[i]):gsub("\t", " ") end
        rows[#rows + 1] = table.concat(it, "\t")
    end
    sv.chests[tostring(bag)] = { name = name, house = house, seen = safe(GetTimeStamp) or 0, items = rows }
    return true
end

function ST.Init(savedVars)
    sv = savedVars
    sv.chests = sv.chests or {}
    if not EVENT_MANAGER or not EVENT_OPEN_BANK then return false end
    EVENT_MANAGER:RegisterForEvent("ESOC_Storage", EVENT_OPEN_BANK, function(_, bag)
        bag = bag or safe(GetBankingBag)
        if bag and safe(IsHouseBankBag, bag) then
            openBag = bag
            ST.SnapshotChest(bag)
        end
    end)
    -- Again on closing, so items moved in or out while it was open are counted.
    EVENT_MANAGER:RegisterForEvent("ESOC_Storage", EVENT_CLOSE_BANK, function()
        if openBag then ST.SnapshotChest(openBag) end
        openBag = nil
    end)
    return true
end

-- How many chests have been recorded, for the screen.
function ST.ChestCount()
    local n = 0
    for _ in pairs(sv and sv.chests or {}) do n = n + 1 end
    return n
end

function ST.Collect()
    local clean = ESOC_SkillExport.clean
    local out = {}
    local function row(...)
        local t = { ... }
        for i = 1, #t do t[i] = clean(t[i]) end
        out[#out + 1] = table.concat(t, "\t")
    end
    local setsSeen = {}
    local function items(key, list)
        for _, it in ipairs(list) do
            local setId = tonumber(it[5]) or 0
            if setId ~= 0 and not setsSeen[setId] then
                setsSeen[setId] = true
                row("SET", setId, it[6])
            end
            row("I", key, it[1], it[2], it[3], it[4], setId, it[7])
        end
    end
    local now = safe(GetTimeStamp) or 0
    local account = safe(GetDisplayName) or ""
    row("V", 1, safe(GetAPIVersion) or 0, now, account)

    local bank = readBag(BAG_BANK)
    if BAG_SUBSCRIBER_BANK then
        for _, it in ipairs(readBag(BAG_SUBSCRIBER_BANK)) do bank[#bank + 1] = it end
    end
    row("LOC", "bank", "bank", "Bank", "", now)
    items("bank", bank)

    if safe(HasCraftBagAccess) then
        row("LOC", "craft", "craft", "Craft bag", "", now)
        items("craft", readCraftBag())
    end

    local keys = {}
    for k in pairs(sv and sv.chests or {}) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return (tonumber(a) or 0) < (tonumber(b) or 0) end)
    for _, k in ipairs(keys) do
        local c = sv.chests[k]
        local key = "chest" .. k
        row("LOC", key, "chest", c.name or "", c.house or "", c.seen or 0)
        local list = {}
        for _, line in ipairs(c.items or {}) do
            local f, i = {}, 0
            for field in (line .. "\t"):gmatch("([^\t]*)\t") do i = i + 1; f[i] = field end
            list[#list + 1] = f
        end
        items(key, list)
    end
    return table.concat(out, "\n"), account
end
