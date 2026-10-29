-- Arc Rob's Furnishing Finder. All game reads are observational.
ARFF = { name = "ArcRobsFurnishingFinder", version = "0.1.2", bagSlots = {}, bankBag = nil }
local F = ARFF
local EM = EVENT_MANAGER

function F:Clean(text)
    return zo_strformat("<<1>>", text or "")
end

function F:Lower(text)
    return zo_strlower(text or "")
end

function F:Changed()
    if not self.UI or not self.UI.visible or self.refreshPending then return end
    self.refreshPending = true
    zo_callLater(function()
        F.refreshPending = false
        if F.UI.visible then F.UI:Rebuild() end
    end, 100)
end

function F:AddItem(items, key, name, icon, quality, link, count)
    if not name or name == "" or not count or count <= 0 then return end
    self.db.catalog = self.db.catalog or {}
    local entry = self.db.catalog[key]
    if not entry then
        self.db.catalog[key] = { name = self:Clean(name), icon = icon, quality = quality or 1 }
    end
    items[key] = (items[key] or 0) + count
end

function F:MigrateRecords()
    -- Keep SavedVariables version 1 so ESO loads existing records for migration.
    self.db.catalog = self.db.catalog or {}
    for _, location in pairs(self.db.locations) do
        for key, item in pairs(location.items) do
            if type(item) == "table" then
                if not self.db.catalog[key] then
                    self.db.catalog[key] = { name = item.name, icon = item.icon, quality = item.quality or 1 }
                end
                location.items[key] = item.count
            end
        end
    end
    self.db.schema = 2
end

function F:ReadSlot(bag, slot)
    local link = GetItemLink(bag, slot, LINK_STYLE_DEFAULT)
    if link == "" or GetItemLinkItemType(link) ~= ITEMTYPE_FURNISHING then return nil end
    local count = GetSlotStackSize(bag, slot)
    if count <= 0 then return nil end
    local icon = GetItemLinkInfo(link)
    local key = "item:" .. GetItemLinkItemId(link)
    self.db.catalog = self.db.catalog or {}
    if not self.db.catalog[key] then
        self.db.catalog[key] = { name = self:Clean(GetItemLinkName(link)),
            icon = icon, quality = GetItemLinkDisplayQuality(link) }
    end
    return { key, count }
end

function F:BagLocation(bag)
    if bag == BAG_BACKPACK then
        local id = tostring(GetCurrentCharacterId())
        return "character:" .. id, "Inventory", "inventory", self:Clean(GetUnitName("player"))
    elseif bag == BAG_BANK or bag == BAG_SUBSCRIBER_BANK then
        return "bag:" .. bag, bag == BAG_BANK and "Bank" or "Bank (ESO Plus)", "bank", "Account"
    elseif BAG_FURNITURE_VAULT and bag == BAG_FURNITURE_VAULT then
        return "bag:" .. bag, "Furniture Vault", "vault", "Account"
    elseif IsHouseBankBag and IsHouseBankBag(bag) then
        local collectible = GetCollectibleForHouseBankBag(bag)
        local name = collectible and collectible > 0 and self:Clean(GetCollectibleName(collectible)) or ""
        if name == "" then name = "Housing storage " .. bag end
        return "bag:" .. bag, name, "storage", "Account"
    end
end

function F:CommitBag(bag)
    local key, name, kind, character = self:BagLocation(bag)
    if not key or not self.bagSlots[bag] then return end
    local items = {}
    for _, entry in pairs(self.bagSlots[bag]) do
        items[entry[1]] = (items[entry[1]] or 0) + entry[2]
    end
    self.db.locations[key] = { name = name, kind = kind, character = character,
        checked = GetTimeStamp(), items = items }
    self:Changed()
end

function F:ScanBag(bag)
    if not self:BagLocation(bag) then return end
    local size = GetBagSize(bag)
    -- An unavailable bag is different from an available bag with empty slots.
    if size <= 0 then return end
    local slots = {}
    for slot = 0, size - 1 do slots[slot] = self:ReadSlot(bag, slot) end
    self.bagSlots[bag] = slots
    self:CommitBag(bag)
end

function F:ScanAccessibleBags()
    self:ScanBag(BAG_BACKPACK)
    if self.bankBag then
        self:ScanBag(self.bankBag)
        if self.bankBag == BAG_BANK and BAG_SUBSCRIBER_BANK then self:ScanBag(BAG_SUBSCRIBER_BANK) end
    end
end

function F:SlotChanged(bag, slot)
    -- Keep the session's slot cache current even when a final transfer event follows bank closure.
    if self.bagSlots[bag] then
        local previous = self.bagSlots[bag][slot]
        local current = self:ReadSlot(bag, slot)
        self.bagSlots[bag][slot] = current
        local locationKey = self:BagLocation(bag)
        local location = self.db.locations[locationKey]
        if not location then self:CommitBag(bag); return end
        if previous then
            local remaining = (location.items[previous[1]] or 0) - previous[2]
            location.items[previous[1]] = remaining > 0 and remaining or nil
        end
        if current then location.items[current[1]] = (location.items[current[1]] or 0) + current[2] end
        location.checked = GetTimeStamp()
        self:Changed()
    elseif bag == BAG_BACKPACK or bag == self.bankBag then
        self:ScanBag(bag)
    end
end

function F:CancelHouseScan()
    self.houseGeneration = (self.houseGeneration or 0) + 1
    EM:UnregisterForUpdate(self.name .. "HouseChunk")
end

function F:ScanHouse()
    self:CancelHouseScan()
    local house = GetCurrentZoneHouseId()
    if house == 0 or not IsOwnerOfCurrentHouse() then return end
    if GetCurrentHousePreviewTemplateId() ~= 0 then return end
    local generation = self.houseGeneration
    local items, seen, last, scanned = {}, {}, nil, 0
    local houseName = self:Clean(GetCollectibleName(GetCollectibleIdForHouse(house)))
    if houseName == "" then houseName = "House " .. house end
    local function chunk()
        if generation ~= self.houseGeneration or house ~= GetCurrentZoneHouseId()
            or not IsOwnerOfCurrentHouse() then
            EM:UnregisterForUpdate(F.name .. "HouseChunk")
            return
        end
        for _ = 1, 40 do
            local id = GetNextPlacedHousingFurnitureId(last)
            if not id then
                EM:UnregisterForUpdate(F.name .. "HouseChunk")
                local expected = 0
                for _, limit in ipairs({ HOUSING_FURNISHING_LIMIT_TYPE_HIGH_IMPACT_COLLECTIBLE,
                    HOUSING_FURNISHING_LIMIT_TYPE_HIGH_IMPACT_ITEM,
                    HOUSING_FURNISHING_LIMIT_TYPE_LOW_IMPACT_COLLECTIBLE,
                    HOUSING_FURNISHING_LIMIT_TYPE_LOW_IMPACT_ITEM }) do
                    expected = expected + GetNumHouseFurnishingsPlaced(limit)
                end
                if expected ~= scanned then
                    F:Message("House data is still loading; previous record kept. Try Scan again.")
                    return
                end
                F.db.locations["house:" .. house] = { name = houseName, kind = "house",
                    character = "Account", checked = GetTimeStamp(), items = items }
                F:Changed()
                return
            end
            -- id64 values are never persisted or converted to floating point.
            local idKey = Id64ToString(id)
            if seen[idKey] then
                EM:UnregisterForUpdate(F.name .. "HouseChunk")
                F:Message("House scan incomplete; previous record kept. Try Scan again.")
                return
            end
            seen[idKey], last = true, id
            scanned = scanned + 1
            local name, icon, furnitureDataId = GetPlacedHousingFurnitureInfo(id)
            local itemLink, collectibleLink = GetPlacedFurnitureLink(id, LINK_STYLE_DEFAULT)
            local key, link
            if itemLink and itemLink ~= "" then
                key, link = "item:" .. GetItemLinkItemId(itemLink), itemLink
            else
                -- Collectible furnishings can appear in several houses; count placed copies only.
                key, link = "collectible:" .. tostring(collectibleLink ~= "" and collectibleLink or furnitureDataId), ""
            end
            if not name or name == "" then
                EM:UnregisterForUpdate(F.name .. "HouseChunk")
                F:Message("House data is still loading; previous record kept. Try Scan again.")
                return
            end
            F:AddItem(items, key, name, icon, GetPlacedHousingFurnitureDisplayQuality(id), link, 1)
        end
    end
    EM:RegisterForUpdate(self.name .. "HouseChunk", 20, chunk)
    chunk()
end

function F:QueueHouseScan(delay)
    self:CancelHouseScan()
    EM:UnregisterForUpdate(self.name .. "HouseDelay")
    local house = GetCurrentZoneHouseId()
    EM:RegisterForUpdate(self.name .. "HouseDelay", delay or 500, function()
        EM:UnregisterForUpdate(F.name .. "HouseDelay")
        if house == GetCurrentZoneHouseId() then F:ScanHouse() end
    end)
end

function F:Scan()
    self:ScanAccessibleBags()
    self:QueueHouseScan(200)
end

function F:Message(message)
    d("|cE8C05CArc Rob's Furnishing Finder:|r " .. message)
end

function F:ShowStats()
    local locations, records, types, copies = 0, 0, 0, 0
    for _, location in pairs(self.db.locations) do
        locations = locations + 1
        for _, count in pairs(location.items) do records, copies = records + 1, copies + count end
    end
    for _ in pairs(self.db.catalog or {}) do types = types + 1 end
    self:Message(string.format("%d locations; %d furnishing types; %d location records; %d copies.",
        locations, types, records, copies))
    if type(GetTotalUserAddOnMemoryPoolUsageMB) == "function"
        and type(GetTotalUserAddOnMemoryPoolCapacityMB) == "function" then
        self:Message(string.format("All add-ons memory pool: %.1f / %.1f MB (shared, not Finder alone).",
            GetTotalUserAddOnMemoryPoolUsageMB(), GetTotalUserAddOnMemoryPoolCapacityMB()))
    end
end

-- Results contain only two array entries. Item details are shared across all locations.
local rowMeta = { __index = function(row, field)
    local location = F.db.locations[row[1]]
    local item = F.db.catalog[row[2]]
    if field == "key" then return row[1] .. "/" .. row[2] end
    if field == "count" then return location.items[row[2]] or 0 end
    if field == "location" then return location.name end
    if field == "kind" or field == "character" or field == "checked" then return location[field] end
    if field == "link" then return "" end
    return item[field]
end }

function F:GetRows(query, kind, sortKey, descending, reuse)
    local rows, total, length = reuse or {}, 0, 0
    query = self:Lower(query):gsub("^%s+", ""):gsub("%s+$", "")
    for locationKey, location in pairs(self.db.locations) do
        for itemKey, count in pairs(location.items) do
            local item = self.db.catalog[itemKey]
            if item and (not kind or kind == "all" or location.kind == kind)
                and self:Lower(item.name):find(query, 1, true) then
                length = length + 1
                local row = rows[length]
                if not row then row = setmetatable({}, rowMeta); rows[length] = row end
                row[1], row[2] = locationKey, itemKey
                total = total + count
            end
        end
    end
    for i = #rows, length + 1, -1 do rows[i] = nil end
    sortKey = sortKey or "name"
    table.sort(rows, function(a, b)
        local av, bv = a[sortKey], b[sortKey]
        if type(av) == "string" then av, bv = self:Lower(av), self:Lower(bv) end
        if av == bv then
            local an, bn = self:Lower(a.name), self:Lower(b.name)
            if an == bn then
                if a[1] == b[1] then return a[2] < b[2] end
                return a[1] < b[1]
            end
            return an < bn
        end
        if descending then return av > bv end
        return av < bv
    end)
    return rows, total
end

function F:Toggle()
    if self.uiError then self:Message("UI initialization failed: " .. tostring(self.uiError)); return end
    if self.UI and self.uiReady then self.UI:Toggle() end
end

function F:RegisterEvents()
    local function register(suffix, event, callback)
        if event then EM:RegisterForEvent(F.name .. suffix, event, callback) end
    end
    register("Activated", EVENT_PLAYER_ACTIVATED, function()
        F.bankBag = nil
        F:ScanBag(BAG_BACKPACK)
        F:QueueHouseScan(1800)
        F.UI:TryRegisterHub()
        zo_callLater(function() F.UI:TryRegisterHub() end, 2500)
    end)
    register("Deactivated", EVENT_PLAYER_DEACTIVATED, function()
        F:CancelHouseScan()
        EM:UnregisterForUpdate(F.name .. "HouseDelay")
        F.bankBag = nil
    end)
    register("Slot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(_, bag, slot) F:SlotChanged(bag, slot) end)
    register("Full", EVENT_INVENTORY_FULL_UPDATE, function() F:ScanAccessibleBags() end)
    register("Bank", EVENT_OPEN_BANK, function(_, bag)
        F.bankBag = bag or GetBankingBag()
        F:ScanAccessibleBags()
        local openedBag = F.bankBag
        zo_callLater(function() if F.bankBag == openedBag then F:ScanAccessibleBags() end end, 300)
    end)
    register("CloseBank", EVENT_CLOSE_BANK, function() F.bankBag = nil end)
    register("Placed", EVENT_HOUSING_FURNITURE_PLACED, function() F:QueueHouseScan() end)
    register("Removed", EVENT_HOUSING_FURNITURE_REMOVED, function() F:QueueHouseScan() end)
    register("HousePermission", EVENT_HOUSING_PLAYER_INFO_CHANGED, function() F:QueueHouseScan(1200) end)
end

EM:RegisterForEvent(F.name, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= F.name then return end
    EM:UnregisterForEvent(F.name, EVENT_ADD_ON_LOADED)
    F.db = ZO_SavedVars:NewAccountWide("ArcRobsFurnishingFinderSV", 1, GetWorldName(), { locations = {} })
    ZO_CreateStringId("SI_BINDING_NAME_ARFF_TOGGLE", "Open / close Furnishing Finder")
    SLASH_COMMANDS["/ff"] = function(text)
        if text == "stats" then F:ShowStats()
        elseif text == "scan" then F:Scan(); F:Message("Scanning accessible locations.")
        else F:Toggle() end
    end
    SLASH_COMMANDS["/furnishingfinder"] = SLASH_COMMANDS["/ff"]
    F:MigrateRecords()
    F:RegisterEvents()
    local ok, problem = pcall(function() F.UI:Initialize() end)
    if not ok then
        F.uiError = problem
        F:Message("UI initialization failed: " .. tostring(problem))
    end
end)
