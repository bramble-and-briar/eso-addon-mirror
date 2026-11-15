-- Unit resources (health / magicka / stamina / ultimate) and equipped gear sets.

local DT = DebuffTracker
local R = DT.Resources
local G = DT.Gear
local C = DT.Const

------------------------------------------------------------------------------
-- Ultimate spent (Tony: Master Architect showed no Slayer countdown). The Halls of Fabrication sets give
-- their buff for 1 s per 10 Ultimate SPENT, and no source we have names the buff's own ability ID on you
-- (Cooldowns' "JorvuldIds" 93120 & co. are its catalogue IDs, not the buff), so the countdown starts
-- from the spend itself: R.ultSpent = { at = time, amount = Ultimate spent }.
------------------------------------------------------------------------------

R.ultSpent = nil
R.ultGains = {}             -- { { time, gained }, ... } over the last 30 s

-- Ultimate gained per second over the last `window` seconds
function R.UltPerSecond(now, window)
    window = window or 10
    local sum = 0
    for _, g in ipairs(R.ultGains) do
        if now - g[1] <= window then sum = sum + g[2] end
    end
    return sum / window
end
local ULT_SPEND_MIN = 30      -- a cast (the cheapest ultimates cost more); smaller drops aren't a cast
function R.InitializeUltWatch()
    if not EVENT_POWER_UPDATE then return end
    local last
    local ns = "DebuffTracker5_UltSpend"
    EVENT_MANAGER:RegisterForEvent(ns, EVENT_POWER_UPDATE, function(_, unitTag, _, powerType, value)
        if powerType ~= POWERTYPE_ULTIMATE or (unitTag and unitTag ~= "player") then return end
        value = tonumber(value) or 0
        -- gains, for "Ultimate per second" (Stat tracker): measured, so every source counts (Hyperioxes' calculator
        -- adds them up from a list; here the game says what you actually got). Last 30 s kept.
        if last and value > last then
            local g, now = R.ultGains, DT.Util.Now()
            g[#g + 1] = { now, value - last }
            while g[1] and now - g[1][1] > 30 do table.remove(g, 1) end
        end
        if last and last - value >= ULT_SPEND_MIN then
            R.ultSpent = { at = DT.Util.Now(), amount = last - value }
            if DT.Engine.RequestUpdate then DT.Engine.RequestUpdate() end
        end
        last = value
    end)
    -- only your ULTIMATE (as the game's own action bar does): unfiltered, every health / magicka / stamina
    -- change reached us -- dozens a second in a fight (5.14.4)
    local ult = COMBAT_MECHANIC_FLAGS_ULTIMATE or POWERTYPE_ULTIMATE
    if REGISTER_FILTER_POWER_TYPE and ult then
        EVENT_MANAGER:AddFilterForEvent(ns, EVENT_POWER_UPDATE, REGISTER_FILTER_POWER_TYPE, ult, REGISTER_FILTER_UNIT_TAG, "player")
    elseif REGISTER_FILTER_UNIT_TAG then
        EVENT_MANAGER:AddFilterForEvent(ns, EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")
    end
end

------------------------------------------------------------------------------
-- Resources: read on demand (the engine evaluates ~10x per second; GetUnitPower is cheap)
------------------------------------------------------------------------------

function R.Tags(unit)
    if unit == "player" then return { "player" } end
    if unit == "target" then
        if DoesUnitExist("reticleover") then return { "reticleover" } end
        return {}
    end
    if unit == "boss" then return DT.Units.BossTags() end
    if unit == "group" then return DT.Units.GroupTags(true) end
    return {}
end

function R.Read(tag, powerType)
    local current, max = GetUnitPower(tag, C.PowerConstant(powerType))
    current, max = current or 0, max or 0
    local pct = max > 0 and (current / max * 100) or 0
    return current, max, pct
end

------------------------------------------------------------------------------
-- Gear: pieces equipped per set id (for the "set equipped" load condition)
------------------------------------------------------------------------------

G.counts = {}
G.countsAll = {}    -- including the other weapon bar
G.max = {}          -- [setId] = pieces for the full bonus (sets you're wearing)
G.names = {}        -- [setId] = set name in the game's language
G.icons = {}        -- [setId] = icon of a worn piece of the set (armour first, then weapons, jewelry last)

-- Which worn piece stands for a set: the game has no set icon, so a piece's icon is used. Armour and
-- weapons look like the set (dropped sets have their own style); jewelry icons are the same for every
-- set, so they're only used when nothing else of the set is worn.
local ICON_SLOT_PRIORITY = {}
for i, slot in ipairs({
    rawget(_G, "EQUIP_SLOT_HEAD") or 0, rawget(_G, "EQUIP_SLOT_SHOULDERS") or 3, rawget(_G, "EQUIP_SLOT_CHEST") or 2,
    rawget(_G, "EQUIP_SLOT_HAND") or 16, rawget(_G, "EQUIP_SLOT_WAIST") or 6, rawget(_G, "EQUIP_SLOT_LEGS") or 8,
    rawget(_G, "EQUIP_SLOT_FEET") or 9, rawget(_G, "EQUIP_SLOT_MAIN_HAND") or 4, rawget(_G, "EQUIP_SLOT_OFF_HAND") or 5,
    rawget(_G, "EQUIP_SLOT_BACKUP_MAIN") or 20, rawget(_G, "EQUIP_SLOT_BACKUP_OFF") or 21,
    rawget(_G, "EQUIP_SLOT_NECK") or 1, rawget(_G, "EQUIP_SLOT_RING1") or 11, rawget(_G, "EQUIP_SLOT_RING2") or 12,
}) do ICON_SLOT_PRIORITY[slot] = i end
G.version = 0       -- bumped on every refresh

local function SetOf(link)
    local hasSet, _, _, _, _, setId = GetItemLinkSetInfo(link, true)
    if hasSet then return setId end
end

function G.Refresh()
    local counts, maxes, names, icons, iconRank = {}, {}, {}, {}, {}
    if BAG_WORN and GetBagSize then
        for slot = 0, GetBagSize(BAG_WORN) - 1 do
            local link = GetItemLink(BAG_WORN, slot)
            if link and link ~= "" then
                local hasSet, setName, _, numEquipped, maxEquipped, setId, numPerfected = GetItemLinkSetInfo(link, true)
                if hasSet and setId then
                    local n = (numEquipped or 0) + (numPerfected or 0)
                    if n > (counts[setId] or 0) then counts[setId] = n end
                    if (maxEquipped or 0) > (maxes[setId] or 0) then maxes[setId] = maxEquipped end
                    if setName and setName ~= "" then names[setId] = DT.Util.CleanName(setName) end
                    local rank = ICON_SLOT_PRIORITY[slot] or 99
                    if rank < (iconRank[setId] or 100) and type(GetItemLinkIcon) == "function" then
                        local icon = GetItemLinkIcon(link)
                        if icon and icon ~= "" then icons[setId], iconRank[setId] = icon, rank end
                    end
                end
            end
        end
    end
    G.counts, G.max, G.names, G.icons = counts, maxes, names, icons
    G.version = G.version + 1
    -- the game counts only the active bar's weapons; add the other bar's (a 2-hander counts twice)
    local all = {}
    for k, v in pairs(counts) do all[k] = v end
    if EQUIP_SLOT_BACKUP_MAIN and GetItemLink then
        local back = { EQUIP_SLOT_BACKUP_MAIN, EQUIP_SLOT_BACKUP_OFF }
        if type(GetActiveWeaponPairInfo) == "function" and ACTIVE_WEAPON_PAIR_BACKUP
            and GetActiveWeaponPairInfo() == ACTIVE_WEAPON_PAIR_BACKUP then
            back = { EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND }
        end
        for _, slot in ipairs(back) do
            local link = GetItemLink(BAG_WORN, slot)
            local setId = link and link ~= "" and SetOf(link)
            if setId then
                local twoHanded = type(GetItemLinkEquipType) == "function" and EQUIP_TYPE_TWO_HAND
                    and GetItemLinkEquipType(link) == EQUIP_TYPE_TWO_HAND
                all[setId] = (all[setId] or 0) + (twoHanded and 2 or 1)
            end
        end
    end
    G.countsAll = all
end

-- the full bonus is on (both bars counted: the other bar's set is still "worn" for swapping)
function G.IsFull(setId)
    local max = G.max[setId]
    return max ~= nil and max > 0 and G.Pieces(setId, true) >= max
end

function G.Pieces(setId, includeOtherBar)
    if includeOtherBar then return G.countsAll[setId] or G.counts[setId] or 0 end
    return G.counts[setId] or 0
end

local refreshQueued = false
function G.Initialize()
    local function Queue()
        if refreshQueued then return end
        refreshQueued = true
        zo_callLater(function()
            refreshQueued = false
            G.Refresh()
            if DT.Procs.OnLoadoutChanged then DT.Procs.OnLoadoutChanged() end
            if DT.Engine.RequestRebuildLoad then DT.Engine.RequestRebuildLoad() end
        end, 200)
    end
    EVENT_MANAGER:RegisterForEvent("DebuffTracker5_Gear", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, Queue)
    if REGISTER_FILTER_BAG_ID then
        EVENT_MANAGER:AddFilterForEvent("DebuffTracker5_Gear", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
    end
    if EVENT_ACTIVE_WEAPON_PAIR_CHANGED then
        EVENT_MANAGER:RegisterForEvent("DebuffTracker5_GearSwap", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, Queue)
    end
    if EVENT_ARMORY_BUILD_RESTORE_RESPONSE then     -- armory loads swap everything at once
        EVENT_MANAGER:RegisterForEvent("DebuffTracker5_GearArmory", EVENT_ARMORY_BUILD_RESTORE_RESPONSE, Queue)
    end
    G.Refresh()
end
