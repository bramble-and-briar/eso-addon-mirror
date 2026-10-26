if not SemisPlaygroundCheckAccess() then return end

---@class InventoryPocCofferGroup
---@field key string
---@field containers number[]
---@field firstMotif number|nil
---@field lastMotif number|nil
---@class InventoryPocCofferSaved
---@field untilReset table<string, number>
---@field observed table<number, table<number, boolean>> Coffer IDs and the motif item IDs found inside
---@class InventoryPocCoffers
local coffers = {}
BattleScrolls.inventoryPocCoffers = coffers

-- Item Cooldown Tracker's coffer/page catalog, plus the observed veteran RftW
-- coffer. IDs distinguish same-named Skyrim boxes with separate motif drops.
-- Sources and catalog coverage: docs/inventory-addon/research.md.
---@type InventoryPocCofferGroup[]
local GROUPS = {
    { key = 'worthy', containers = { 134619, 145577, 181436, 184171, 190009, 194353, 204404, 210866, 214239, 219651, 224367, 225248 } },
    { key = 'shieldOfSenchal', containers = { 153853, 153854 }, firstMotif = 156628, lastMotif = 156641 },
    { key = 'dragonguard', containers = { 153851, 153852 }, firstMotif = 156556, lastMotif = 156569 },
    { key = 'blackreachVanguard', containers = { 165575, 165576 }, firstMotif = 160494, lastMotif = 160507 },
    { key = 'greymoor', containers = { 165577 }, firstMotif = 160543, lastMotif = 160556 },
    { key = 'arkthzandArmory', containers = { 170223, 170224 }, firstMotif = 167961, lastMotif = 167974 },
    { key = 'nighthollow', containers = { 170225 }, firstMotif = 167944, lastMotif = 167957 },
    { key = 'waywardGuardian', containers = { 170226 }, firstMotif = 167978, lastMotif = 167991 },
    { key = 'blackFinLegion', containers = { 178407 }, firstMotif = 171879, lastMotif = 171892 },
    { key = 'ivoryBrigade', containers = { 178408 }, firstMotif = 171896, lastMotif = 171909 },
    { key = 'houseHexos', containers = { 182936 }, firstMotif = 170132, lastMotif = 170145 },
    { key = 'fargraveGuardian', containers = { 183008 }, firstMotif = 178707, lastMotif = 178720 },
    { key = 'steadfastSociety', containers = { 188137 }, firstMotif = 182538, lastMotif = 182551 },
    { key = 'systresGuardian', containers = { 188136 }, firstMotif = 182555, lastMotif = 182568 },
    { key = 'houseMornard', containers = { 190948, 190949 }, firstMotif = 188325, lastMotif = 188338 },
    { key = 'firesong', containers = { 190952 }, firstMotif = 188308, lastMotif = 188321 },
    { key = 'deadKeeper', containers = { 197818, 197819 }, firstMotif = 194514, lastMotif = 194527 },
    { key = 'kindredsConcord', containers = { 197820 }, firstMotif = 194541, lastMotif = 194554 },
    { key = 'shardborn', containers = { 207980, 207981 }, firstMotif = 203361, lastMotif = 203374 },
    { key = 'westWealdLegion', containers = { 207982 }, firstMotif = 203474, lastMotif = 203487 },
    { key = 'tideBorn', containers = { 217731, 217732 }, firstMotif = 212119, lastMotif = 212132 },
    { key = 'koldaneCartel', containers = { 225207 }, firstMotif = 223948, lastMotif = 223961 },
}
---@type table<number, InventoryPocCofferGroup>
local byItem = {}
for _, group in ipairs(GROUPS) do
    for _, id in ipairs(group.containers) do byItem[id] = group end
end
---@type table<number, boolean>
local checkedNames = {}

---@param itemId number
---@return string
local function cofferName(itemId)
    local link = string.format('|H0:item:%d:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h', itemId)
    return zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(link))
end

---@param itemId number
---@return InventoryPocCofferGroup|nil
local function groupFor(itemId)
    if byItem[itemId] or checkedNames[itemId] then return byItem[itemId] end
    checkedNames[itemId] = true
    local name = cofferName(itemId)
    -- Additional RftW levels/qualities use the native localized coffer name.
    if name ~= '' and (name == cofferName(224367) or name == cofferName(225248)) then
        byItem[itemId] = GROUPS[1]
        GROUPS[1].containers[#GROUPS[1].containers + 1] = itemId
    end
    return byItem[itemId]
end
local EVENT_NAME = 'BattleScrollsInventoryPocCoffers'
local registered = false
---@type InventoryPocCofferSaved|nil
local saved
---@type number|nil
local openingId, openingUntil
---@type table<number, boolean>
local openingLoot = {}

---@return number
local function nextReset()
    local now = GetTimeStamp()
    local remaining = GetTimeUntilNextDailyLoginRewardClaimS()
    if remaining > 0 and remaining <= 86400 then return now + remaining end
    -- An unclaimed login reward reports zero. Daily resets are 03:00 UTC on
    -- European megaservers and 10:00 UTC on North American megaservers.
    local world = string.lower(GetWorldName())
    local hour = (world:find('eu', 1, true) or world:find('europe', 1, true)) and 3 or 10
    return now - ((now - hour * 3600) % 86400) + 86400
end

local function wakeAtReset()
    EVENT_MANAGER:UnregisterForUpdate(EVENT_NAME)
    if not saved then return end
    local now, earliest = GetTimeStamp(), nil
    for key, expires in pairs(saved.untilReset) do
        if expires <= now then saved.untilReset[key] = nil
        else earliest = math.min(earliest or expires, expires) end
    end
    if earliest then
        EVENT_MANAGER:RegisterForUpdate(EVENT_NAME, math.max(1, (earliest - now) * 1000), function()
            wakeAtReset()
            BattleScrolls.inventoryPoc.wake()
        end)
    end
end

---@param group InventoryPocCofferGroup
local function block(group)
    if not saved then return end
    saved.untilReset[group.key] = nextReset()
    wakeAtReset()
    BattleScrolls.inventoryPoc.resume()
end

---@param itemId number
---@return number|nil
function coffers.openAfter(itemId)
    local group = groupFor(itemId)
    if not group or not saved then return nil end
    local now = GetTimeStamp()
    local expires = saved.untilReset[group.key]
    if expires and expires > now then return expires end
    if openingId and openingUntil and openingUntil > now and byItem[openingId] == group then return openingUntil end
end

---@param itemId number
function coffers.beginUse(itemId)
    openingId, openingUntil = itemId, GetTimeStamp() + 15
    openingLoot = {}
    EVENT_MANAGER:RegisterForUpdate(EVENT_NAME .. 'Drain', 15000, function()
        EVENT_MANAGER:UnregisterForUpdate(EVENT_NAME .. 'Drain')
        openingId, openingUntil, openingLoot = nil, nil, {}
        BattleScrolls.inventoryPoc.wake()
    end)
end

---@param contents InventoryPocLootEntry[]
function coffers.capture(contents)
    for _, entry in ipairs(contents) do
        if entry.link and entry.link ~= '' then openingLoot[GetItemLinkItemId(entry.link)] = true end
    end
end

---@param group InventoryPocCofferGroup
---@param itemId number
---@return boolean
local function isMotif(group, itemId)
    return group.firstMotif ~= nil and itemId >= group.firstMotif and itemId <= group.lastMotif
end

---@param cofferId number
---@param link string
local function observe(cofferId, link)
    if not saved or link == '' or GetItemLinkItemType(link) ~= ITEMTYPE_RACIAL_STYLE_MOTIF then return end
    saved.observed[cofferId] = saved.observed[cofferId] or {}
    saved.observed[cofferId][GetItemLinkItemId(link)] = true
end

---@param itemId number
---@param contents InventoryPocLootEntry[]|nil
function coffers.opened(itemId, contents)
    local group = groupFor(itemId)
    if group and group.key == 'worthy' then block(group) end
    for _, entry in ipairs(contents or {}) do
        if entry.link and entry.link ~= '' then
            observe(itemId, entry.link)
            if group and isMotif(group, GetItemLinkItemId(entry.link)) then block(group) end
        end
    end
end

---@param group InventoryPocCofferGroup
---@return boolean
local function isCurrentLoot(group)
    local name, target = GetLootTargetInfo()
    if target ~= INTERACT_TARGET_TYPE_ITEM or name == '' then return false end
    name = zo_strformat(SI_TOOLTIP_ITEM_NAME, name)
    for _, id in ipairs(group.containers) do
        if name == cofferName(id) then return true end
    end
    return false
end

---@param state InventoryPocCofferSaved
---@param log InventoryPocLogEntry[]|nil Existing openings recover today's cooldown on first installation
function coffers.initialize(state, log)
    saved = state
    local previousReset = nextReset() - 86400
    for _, entry in ipairs(log or {}) do
        if entry.action == 'open' and entry.result == 'done' and entry.timestamp >= previousReset then
            coffers.opened(entry.itemId, entry.contents)
        end
    end
    wakeAtReset()
    if registered then return end
    registered = true
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_LOOT_RECEIVED,
        function(_, _, link, _, _, _, receivedBySelf, _, _, itemId)
            if not BattleScrolls.inventoryPoc.enabled or not receivedBySelf then return end
            local source = openingId and openingUntil and openingUntil > GetTimeStamp() and openingLoot[itemId] and openingId or nil
            if source then
                observe(source, link)
                local group = byItem[source]
                if group and (group.key == 'worthy' or isMotif(group, itemId)) then block(group) end
            else
                for _, group in ipairs(GROUPS) do
                    if (group.key == 'worthy' or isMotif(group, itemId)) and isCurrentLoot(group) then block(group) end
                end
            end
        end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_LOOT_CLOSED, function()
        if not openingId then return end
        local id = openingId
        EVENT_MANAGER:RegisterForUpdate(EVENT_NAME .. 'Drain', 1000 + GetLatency(), function()
            EVENT_MANAGER:UnregisterForUpdate(EVENT_NAME .. 'Drain')
            if openingId == id then openingId, openingUntil, openingLoot = nil, nil, {} end
            BattleScrolls.inventoryPoc.wake()
        end)
    end)
end
