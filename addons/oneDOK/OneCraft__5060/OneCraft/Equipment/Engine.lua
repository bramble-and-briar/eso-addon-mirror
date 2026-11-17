-- OneCraft's private equipment crafting engine. Uses only the ESO API.
local O, P = OneCraft, OneCraft.Equipment
local E = {order = 0, SUCCESS = "success", INITIAL = "initial", FAILED = "failed", WAITING = "waiting"}
P.Engine = E
local Client = {}
Client.__index = Client

-- ESO recipe facts: material item IDs and quantities for the 41 level choices.
-- Quantities are checked against the native station before every actual craft.
local base = {1,2,3,4,5,6,7,2,3,4,5,6,3,4,5,6,7,4,5,6,7,8,5,6,7,6,7,8,7,8,9,8,9,9,10,11,12,13,14,9,9}
local offsets = {
    [CRAFTING_TYPE_BLACKSMITHING] = {2,2,2,4,4,4,1,6,4,4,4,5,4,4},
    [CRAFTING_TYPE_CLOTHIER] = {6,6,4,4,4,5,4,4,6,4,4,4,5,4,4},
    [CRAFTING_TYPE_WOODWORKING] = {2,5,2,2,2,2},
}
local tierStarts = {1,8,13,18,23,26,29,32,34,40}
local materials = {
    [CRAFTING_TYPE_BLACKSMITHING] = {5413,4487,23107,6000,6001,46127,46128,46129,46130,64489},
    [CRAFTING_TYPE_CLOTHIER] = {811,4463,23125,23126,23127,46131,46132,46133,46134,64504},
    leather = {794,4447,23099,23100,23101,46135,46136,46137,46138,64506},
    [CRAFTING_TYPE_WOODWORKING] = {803,533,23121,23122,23123,46139,46140,46141,46142,64502},
    [CRAFTING_TYPE_JEWELRYCRAFTING] = {135138,135140,135142,135144,135146},
}
local jewelry = {
    {2,3,1},{3,5,1},{4,6,1},{5,8,1},{6,9,1},{7,11,1},{8,12,1},{9,14,1},{10,15,1},{11,17,1},{12,19,1},{13,20,1},
    {3,5,2},{4,6,2},{5,8,2},{6,9,2},{7,11,2},{8,12,2},{9,14,2},{10,15,2},{11,17,2},{12,18,2},{13,20,2},{14,21,2},{15,23,2},
    {4,6,3},{6,9,3},{8,12,3},{10,15,3},{12,18,3},{14,21,3},{16,24,3},
    {6,8,4},{8,12,4},{10,16,4},{12,20,4},{14,24,4},{16,28,4},{18,32,4},{10,15,5},{100,150,5},
}

function E.NextOrder() E.order = E.order + 1; return E.order end
function E.Sets()
    if not E.sets then
        E.sets = {[0] = {P.words.none}}
        -- The consolidated-station list can be empty away from a station.
        -- Our existing crafted-item catalogue supplies the global set IDs.
        for id in pairs(P.itemRanges) do
            if id > 0 then E.sets[id] = {GetItemSetName(id)} end
        end
    end
    local count = GetNumConsolidatedSmithingSets()
    if E.setCount ~= count then
        for _, entry in pairs(E.sets) do entry.consolidatedIndex = nil end
        for i = 1, count do
            local id = GetConsolidatedSmithingItemSetIdByIndex(i)
            if id and id > 0 then E.sets[id] = {GetItemSetName(id), consolidatedIndex = i} end
        end
        E.setCount = count
    end
    return E.sets
end

function Client.isSmithingLevelValid(cp, level)
    if type(level) ~= "number" then return false end
    if cp then return level >= 10 and level <= 160 and level % 10 == 0 end
    return level == 1 or level >= 4 and level <= 50 and level % 2 == 0
end
function Client.GetMatRequirements(pattern, index, station)
    if station == CRAFTING_TYPE_JEWELRYCRAFTING then return jewelry[index][pattern] end
    local quantity = base[index] + offsets[station][pattern]
    if station == CRAFTING_TYPE_WOODWORKING and pattern ~= 2 and index >= 40 then quantity = quantity + 1 end
    if station == CRAFTING_TYPE_BLACKSMITHING then
        if pattern == 12 and index >= 8 and index < 13 then quantity = quantity - 1 end
        if pattern >= 4 and pattern <= 6 and index >= 40 then quantity = quantity + 1 end
    end
    return index == 41 and quantity * 10 or quantity
end
function E.MaterialId(request)
    local index, tier = request.materialIndex, 1
    if request.station == CRAFTING_TYPE_JEWELRYCRAFTING then tier = jewelry[index][3]
    else for i, start in ipairs(tierStarts) do if index >= start then tier = i end end end
    local category = request.station == CRAFTING_TYPE_CLOTHIER and request.pattern > 8 and "leather" or request.station
    return materials[category][tier]
end
function Client:getMatRequirements(request)
    local result = {[E.MaterialId(request)] = request.materialQuantity}
    local function add(link, amount)
        if link and link ~= "" then
            local id = GetItemLinkItemId(link)
            if id and id > 0 then result[id] = (result[id] or 0) + amount end
        end
    end
    if request.station ~= CRAFTING_TYPE_JEWELRYCRAFTING then add(GetItemStyleMaterialLink(request.style, LINK_STYLE_DEFAULT), 1) end
    if request.trait > 1 then add(GetSmithingTraitItemLink(E.TraitIndex(request.trait - 1), LINK_STYLE_DEFAULT), 1) end
    for quality = 1, request.quality - 1 do
        add(GetSmithingImprovementItemLink(request.station, quality, LINK_STYLE_DEFAULT),
            GetSmithingGuaranteedImprovementItemAmount(request.station, quality))
    end
    return result
end
function E.TraitIndex(trait)
    for i = 1, GetNumSmithingTraitItems() do if GetSmithingTraitItemInfo(i) == trait then return i end end
end

local function unique(bag, slot) return Id64ToString(GetItemUniqueId(bag, slot)) end
local function findUnique(id)
    if not id then return end
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if GetItemId(BAG_BACKPACK, slot) > 0 and unique(BAG_BACKPACK, slot) == id then return BAG_BACKPACK, slot end
    end
end
local function snapshot()
    local result = {}
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if GetItemId(BAG_BACKPACK, slot) > 0 then result[unique(BAG_BACKPACK, slot)] = select(2, GetItemInfo(BAG_BACKPACK, slot)) end
    end
    return result
end
local function enchantKey(link)
    local id, quality, level = link:match("item:%d+:%d+:%d+:(%d+):(%d+):(%d+)")
    return id and id .. ":" .. quality .. ":" .. level
end
local function announce(client, event, request)
    client.callback(event, request and request.station or GetCraftingInteractionType(), request)
end
function Client:getAddonCraftingQueue() return self.personalQueue end
function Client:SetAllAutoCraft(value)
    for _, list in ipairs(self.personalQueue) do for _, request in ipairs(list) do request.autocraft = value end end
end
function Client:cancelItemByReference(reference)
    for _, list in ipairs(self.personalQueue) do
        for i = #list, 1, -1 do if list[i].reference == reference then table.remove(list, i) end end
    end
end
function Client:cancelItem()
    for i = 1, 7 do self.personalQueue[i] = {} end
end
function Client:CraftSmithingItemByLevel(pattern, cp, level, style, trait, universal, station, set, quality, auto, reference, potency, essence, aspect)
    if not Client.isSmithingLevelValid(cp, level) or universal then return nil end
    local index = cp and 25 + level / 10 or math.max(1, level / 2)
    if level == 1 then index = 1 end
    local request = {nativeVersion = 1, type = "smithing", pattern = pattern, isCP = cp, level = level,
        materialIndex = index, materialQuantity = Client.GetMatRequirements(pattern, index, station),
        style = style, trait = trait, station = station, setIndex = set, quality = quality,
        autocraft = auto, reference = reference, timestamp = E.NextOrder(),
        potencyItemID = potency, essenceItemID = essence, aspectItemID = aspect}
    self.personalQueue[station][#self.personalQueue[station] + 1] = request
    if potency then self.personalQueue[CRAFTING_TYPE_ENCHANTING][#self.personalQueue[CRAFTING_TYPE_ENCHANTING] + 1] = request end
    return request
end

local patternCounts = {[CRAFTING_TYPE_BLACKSMITHING] = 14, [CRAFTING_TYPE_CLOTHIER] = 15,
    [CRAFTING_TYPE_WOODWORKING] = 6, [CRAFTING_TYPE_JEWELRYCRAFTING] = 2}
function E.ResolvePattern(request)
    if request.station ~= GetCraftingInteractionType() then return end
    if request.setIndex ~= 0 then
        local entry = E.Sets()[request.setIndex]
        if GetCraftingInteractionMode() == CRAFTING_INTERACTION_MODE_CONSOLIDATED_STATION then
            if not entry or not entry.consolidatedIndex or not IsConsolidatedSmithingSetIndexUnlocked(entry.consolidatedIndex) then return end
            if GetActiveConsolidatedSmithingItemSetId() ~= request.setIndex then SetActiveConsolidatedSmithingSetByIndex(entry.consolidatedIndex) end
        elseif not CanSpecificSmithingItemSetPatternBeCraftedHere(request.setIndex) then return end
    end
    local traitIndex = E.TraitIndex(request.trait - 1)
    if not traitIndex then return end
    local baseCount = patternCounts[request.station]
    for pattern = 1, GetNumSmithingPatterns() do
        -- At a set station, the second block is the set variant. Jewelry sets
        -- can reverse ring/neck order, so validate equip type on the result.
        local basePattern = (pattern - 1) % baseCount + 1
        local wanted = basePattern == request.pattern
        if request.station == CRAFTING_TYPE_JEWELRYCRAFTING then wanted = true end
        if wanted then
            local _, _, amount, _, usable = GetSmithingPatternMaterialItemInfo(pattern, request.materialIndex)
            local link = GetSmithingPatternResultLink(pattern, request.materialIndex, amount, request.style, traitIndex, LINK_STYLE_DEFAULT)
            if link and link ~= "" then
                local _, _, _, _, _, setId = GetItemLinkSetInfo(link, false)
                local jewelryMatches = request.station ~= CRAFTING_TYPE_JEWELRYCRAFTING or
                    GetItemLinkEquipType(link) == (request.pattern == 1 and EQUIP_TYPE_RING or EQUIP_TYPE_NECK)
                if (setId or 0) == request.setIndex and jewelryMatches then
                    return {pattern = pattern, material = request.materialIndex, quantity = amount,
                        style = request.style, trait = traitIndex, link = link, usable = usable}
                end
            end
        end
    end
end
function Client:getItemLinkFromParticulars(pattern, cp, level, style, trait, station, set, quality, potency, essence, aspect)
    return P.PreviewLink(pattern, cp, level, style, trait - 1, station, set, quality or 1, potency, essence, aspect)
end

function E.Migrate(client)
    -- Read the earlier bridge's saved request format without loading that library.
    -- Consolidate duplicate station entries by reference, preserving created IDs.
    local byReference = {}
    for station, list in ipairs(client.personalQueue) do
        for _, request in ipairs(list) do
            if not request.nativeVersion then
                local target = byReference[request.reference] or request
                byReference[request.reference] = target
                if request.type == "improvement" then
                    target.gearId = request.itemStringUniqueId or request.itemUniqueId and Id64ToString(request.itemUniqueId)
                    target.station = station
                end
                local gear, glyph = request.equipInfo and request.equipInfo[1], request.glyphInfo and request.glyphInfo[1]
                if gear then target.gearId = gear.uniqueIdString or Id64ToString(gear.uniqueId) end
                if glyph then target.glyphId = glyph.uniqueIdString or Id64ToString(glyph.uniqueId) end
                if request.equipCreated or request.smithingQuantity == 0 then target.gearCreated = true end
                if request.quantity == 0 then target.glyphCreated = true end
            end
        end
    end
    if not next(byReference) then return end
    local queue = {{},{},{},{},{},{},{}}
    for _, request in pairs(byReference) do
        request.nativeVersion = 1
        if request.isJewelrySwapped and not request.gearId then request.pattern = request.pattern == 1 and 2 or 1 end
        if request.materialIndex and not request.level then
            request.isCP = request.materialIndex > 25
            request.level = request.isCP and (request.materialIndex - 25) * 10 or request.materialIndex == 1 and 1 or request.materialIndex * 2
        end
        -- A partly created object with no retained unique ID is kept blocked;
        -- it must never be recreated on the assumption that it was not crafted.
        if request.gearCreated and not request.gearId or request.glyphCreated and not request.glyphId then request.blocked = true end
        if request.station ~= CRAFTING_TYPE_ENCHANTING then queue[request.station][#queue[request.station] + 1] = request end
        if request.potencyItemID then queue[CRAFTING_TYPE_ENCHANTING][#queue[CRAFTING_TYPE_ENCHANTING] + 1] = request end
    end
    client.personalQueue = queue
end

local function finish(client, request)
    request.completed = true
    client:cancelItemByReference(request.reference)
    announce(client, E.SUCCESS, request)
end
local function resolvePending(client, request)
    local pending = request.pending
    if not pending then return true end
    if pending.kind == "gear" or pending.kind == "glyph" then
        local found
        for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
            if GetItemId(BAG_BACKPACK, slot) > 0 then
                local link, id = GetItemLink(BAG_BACKPACK, slot, LINK_STYLE_DEFAULT), unique(BAG_BACKPACK, slot)
                local count = select(2, GetItemInfo(BAG_BACKPACK, slot))
                if count > (pending.before[id] or 0) and GetItemLinkItemId(link) == GetItemLinkItemId(pending.link) and
                    GetItemLinkFunctionalQuality(link) == GetItemLinkFunctionalQuality(pending.link) and
                    GetItemLinkRequiredLevel(link) == GetItemLinkRequiredLevel(pending.link) and
                    GetItemLinkRequiredChampionPoints(link) == GetItemLinkRequiredChampionPoints(pending.link) then
                    if found then return false end -- Ambiguous inventory changes must not select an unrelated object.
                    found = id
                end
            end
        end
        if found then
            if pending.kind == "gear" then request.gearId = found else request.glyphId = found end
            request.pending = nil
            announce(client, E.INITIAL, request)
            return true
        end
    else
        local bag, slot = findUnique(request.gearId)
        if bag then
            local link = GetItemLink(bag, slot, LINK_STYLE_DEFAULT)
            if pending.kind == "improve" and GetItemLinkFunctionalQuality(link) >= pending.quality then
                request.pending = nil
                announce(client, E.INITIAL, request)
                return true
            elseif pending.kind == "enchant" and enchantKey(link) == pending.enchant then
                request.pending = nil
                finish(client, request)
                return true
            end
        end
    end
    return false
end

local function begin(client, request, pending, action)
    request.pending = pending
    client.active = request
    P.SaveQueue() -- Record intent before spending materials, including across reloads.
    action()
    return true
end
local function applyGlyph(client, request)
    local gearBag, gearSlot = findUnique(request.gearId)
    local glyphBag, glyphSlot = findUnique(request.glyphId)
    if not gearBag or not glyphBag or IsItemPlayerLocked(gearBag, gearSlot) or IsItemPlayerLocked(glyphBag, glyphSlot) then return false end
    if GetItemFunctionalQuality(gearBag, gearSlot) < request.quality then return false end
    local result = GetEnchantedItemResultingItemLink(gearBag, gearSlot, glyphBag, glyphSlot, LINK_STYLE_DEFAULT)
    local key = result and enchantKey(result)
    if not key then return false end
    begin(client, request, {kind = "enchant", enchant = key}, function() EnchantItem(gearBag, gearSlot, glyphBag, glyphSlot) end)
    zo_callLater(function()
        if client.active == request then
            client.active = nil
            if not resolvePending(client, request) then announce(client, E.FAILED, request) end
            E.Run()
        end
    end, 300)
    return true
end

local function tryRequest(client, request, station)
    if not request.autocraft or request.blocked or request.failed then return false end
    if not resolvePending(client, request) then return false end
    if request.completed then return false end
    -- A resolved enchant may have removed the request from both lists.
    if request.gearId and request.glyphId and applyGlyph(client, request) then return true end
    if station == request.station then
        if not request.gearId then
            local resolved = E.ResolvePattern(request)
            if not resolved or not resolved.usable or not CheckInventorySpaceSilently(1) then return false end
            local _, _, _, _, required, known = GetSmithingPatternInfo(resolved.pattern)
            if known < required or request.trait > 1 and not IsSmithingTraitKnownForPattern(resolved.pattern, request.trait - 1) then return false end
            if station ~= CRAFTING_TYPE_JEWELRYCRAFTING and (not IsSmithingStyleKnown(request.style, resolved.pattern) or
                not CanSmithingStyleBeUsedOnPattern(request.style, resolved.pattern, resolved.material, resolved.quantity)) then return false end
            local maximum = GetMaxIterationsPossibleForSmithingItem(resolved.pattern, resolved.material, resolved.quantity, resolved.style, resolved.trait, false)
            if maximum < 1 then return false end
            return begin(client, request, {kind = "gear", before = snapshot(), link = resolved.link}, function()
                CraftSmithingItem(resolved.pattern, resolved.material, resolved.quantity, resolved.style, resolved.trait, false, 1)
            end)
        end
        local bag, slot = findUnique(request.gearId)
        if not bag or IsItemPlayerLocked(bag, slot) then return false end
        local quality = GetItemFunctionalQuality(bag, slot)
        if quality < request.quality then
            local boosters = GetSmithingGuaranteedImprovementItemAmount(station, quality)
            local _, _, count = GetSmithingImprovementItemInfo(station, quality)
            if boosters < 1 or count < boosters or not CanItemBeSmithingImproved(bag, slot, station) or
                GetSmithingImprovementChance(bag, slot, boosters, station) < 100 then return false end
            return begin(client, request, {kind = "improve", quality = quality + 1}, function() ImproveSmithingItem(bag, slot, boosters) end)
        end
        if not request.potencyItemID then finish(client, request); return false end
    elseif station == CRAFTING_TYPE_ENCHANTING and request.potencyItemID and not request.glyphId then
        if not CheckInventorySpaceSilently(1) then return false end
        local A = O.Enchanting
        A.Inventory.Scan()
        local arguments = {}
        for _, id in ipairs({request.potencyItemID, request.essenceItemID, request.aspectItemID}) do
            local rune = A.inventory[id]
            if not rune or not A.Inventory.Usable(rune.bag, rune.slot, id) or not DoesRunePassRequirements(rune.runeType, rune.rank, rune.rarity) then return false end
            arguments[#arguments + 1], arguments[#arguments + 2] = rune.bag, rune.slot
        end
        if GetMaxIterationsPossibleForEnchantingItem(unpack(arguments)) < 1 then return false end
        arguments[7] = LINK_STYLE_DEFAULT
        local link = GetEnchantingResultingItemLink(unpack(arguments))
        if not link or link == "" then return false end
        arguments[7] = 1
        return begin(client, request, {kind = "glyph", before = snapshot(), link = link}, function()
            -- Match ZO_SharedEnchanting:Create before the craft-start event reads
            -- these values for the queued rune sounds (keyboard or gamepad).
            local enchanting = ZO_Enchanting_GetVisibleEnchanting()
            enchanting.potencySound, enchanting.potencyLength = GetRunestoneSoundInfo(arguments[1], arguments[2])
            enchanting.essenceSound, enchanting.essenceLength = GetRunestoneSoundInfo(arguments[3], arguments[4])
            enchanting.aspectSound, enchanting.aspectLength = GetRunestoneSoundInfo(arguments[5], arguments[6])
            CraftEnchantingItem(unpack(arguments))
        end)
    end
    return false
end

function E.Run()
    local client, station = E.client, GetCraftingInteractionType()
    if not client or client.active or station == 0 or ZO_CraftingUtils_IsPerformingCraftProcess() then return end
    local candidates = {}
    for _, request in ipairs(client.personalQueue[station] or {}) do candidates[#candidates + 1] = request end
    for _, request in ipairs(candidates) do if tryRequest(client, request, station) then return end end
    announce(client, E.WAITING)
end
function E.New(callback)
    local client = setmetatable({personalQueue = {{},{},{},{},{},{},{}}, callback = callback}, Client)
    E.client = client
    EVENT_MANAGER:RegisterForEvent("OneCraftEquipmentCraftComplete", EVENT_CRAFT_COMPLETED, function(_, station)
        local request = client.active
        if not request or request.pending.kind == "enchant" or station ~= GetCraftingInteractionType() and GetCraftingInteractionType() ~= 0 then return end
        zo_callLater(function()
            client.active = nil
            if not resolvePending(client, request) then announce(client, E.FAILED, request) end
            E.Run()
        end, 150)
    end)
    EVENT_MANAGER:RegisterForEvent("OneCraftEquipmentCraftFailed", EVENT_CRAFT_FAILED, function()
        local request = client.active
        if request and request.pending.kind ~= "enchant" then
            client.active, request.pending, request.failed = nil, nil, true
            announce(client, E.FAILED, request)
        end
    end)
    CALLBACK_MANAGER:RegisterCallback("CraftingAnimationsStopped", E.Run)
    return client
end
