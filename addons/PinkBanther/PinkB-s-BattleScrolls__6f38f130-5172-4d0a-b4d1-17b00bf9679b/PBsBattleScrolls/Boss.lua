PBsBattleScrolls = PBsBattleScrolls or {}
local ADDON = PBsBattleScrolls

---------------------------------------------------------------------------------------------------
-- The player's share of the damage done to bosses, from the bosses' health
--
-- A boss's health drops with every hit from anybody -- group members without this add-on, other
-- players, companions -- so "how much health the boss lost while the player fought" is everybody's
-- damage, and the player's own damage to it over that is the player's share. Only bosses can be
-- read this way: health is readable for units with a unit tag (GetUnitPower), and enemies that are
-- not bosses have none the add-on can list.
--
-- How (the way the client's own boss bar reads them, ingame/unitframes/bossbar.lua):
--   * the boss tags are boss<BOSS_RANK_ITERATION_BEGIN .. _END> (MAX_BOSSES is a PC-only alias);
--   * EVENT_POWER_UPDATE filtered to the "boss" tag prefix and to health, registered only while a
--     fight goes on (Main.lua); EVENT_BOSSES_CHANGED to pick up a boss that appears mid-fight;
--   * every DROP in a boss's health is added up; a rise (the boss healing, or resetting) is not
--     taken away, so the sum is the damage that reached its health;
--   * the player's part is the damage the player and pets dealt to a unit of the boss's name,
--     without the part a damage shield took (that never reached its health).
--
-- Not exact: damage the boss's own shields absorbed counts for the player but not in its health,
-- an overkill hit may count more than the health left, and an add with the boss's name counts as the
-- boss. A share above 100% is shown as 100%.
---------------------------------------------------------------------------------------------------

local bosses = { scans = 0, updates = 0 }
ADDON.bosses = bosses

local Plain = ADDON.Plain

local tags
local function Tags()
    if not tags then
        tags = {}
        local first = BOSS_RANK_ITERATION_BEGIN or 1
        local last = BOSS_RANK_ITERATION_END or 12
        for index = first, last do
            tags[#tags + 1] = "boss" .. index
        end
    end
    return tags
end

local function Health(tag)
    local current, max = GetUnitPower(tag, COMBAT_MECHANIC_FLAGS_HEALTH)
    return tonumber(current) or 0, tonumber(max) or 0
end

-- Notes every boss there is now. A tag that now holds another boss starts a new entry; the old one
-- stays in the fight's list with what it lost.
function bosses:Scan(fight)
    fight = fight or ADDON.fights.live
    if not fight or type(DoesUnitExist) ~= "function" then
        return
    end
    self.scans = self.scans + 1
    for _, tag in ipairs(Tags()) do
        if DoesUnitExist(tag) then
            local name = type(GetUnitName) == "function" and Plain(GetUnitName(tag) or "") or ""
            local entry = fight.bosses[tag]
            if name ~= "" and (not entry or entry.name ~= name) then
                local current, max = Health(tag)
                entry = { name = name, hp = current, max = max, lost = 0 }
                fight.bosses[tag] = entry
                fight.bossEntries[#fight.bossEntries + 1] = entry
            end
        end
    end
end

-- EVENT_POWER_UPDATE for a boss's health.
function bosses:PowerUpdate(tag, value, max)
    local fight = ADDON.fights.live
    if not fight then
        return
    end
    self.updates = self.updates + 1
    local entry = fight.bosses[tag]
    if not entry then
        -- a boss the fight has not seen yet: noted at its health now, nothing lost so far
        self:Scan(fight)
        return
    end
    value = tonumber(value) or entry.hp
    if value < entry.hp then
        entry.lost = entry.lost + (entry.hp - value)
    end
    entry.hp = value
    if (tonumber(max) or 0) > entry.max then
        entry.max = max
    end
end

-- The bosses by name: health lost, the player's damage, the player's share.
local function ByName(fight)
    local byName, order = {}, {}
    for _, entry in ipairs(fight.bossEntries) do
        local row = byName[entry.name]
        if not row then
            row = { name = entry.name, lost = 0, max = 0, mine = 0 }
            byName[entry.name] = row
            order[#order + 1] = row
        end
        row.lost = row.lost + entry.lost
        row.max = math.max(row.max, entry.max)
    end
    local lost, mine = 0, 0
    for _, row in ipairs(order) do
        row.mine = fight.hpDmg[row.name] or 0
        if row.lost > 0 then
            row.share = math.min(1, row.mine / row.lost)
            lost = lost + row.lost
            -- a boss's part is never more than it lost (overkill, its own shields)
            mine = mine + math.min(row.mine, row.lost)
        end
    end
    return order, lost, mine
end

-- The share over every boss of the fight that lost health; nil when none did.
function bosses.Share(fight)
    if not fight or #fight.bossEntries == 0 then
        return nil
    end
    local _, lost, mine = ByName(fight)
    if lost <= 0 then
        return nil
    end
    return math.min(1, mine / lost)
end

function bosses.FoldInto(fight, record)
    if #fight.bossEntries == 0 then
        return
    end
    local order, lost, mine = ByName(fight)
    if lost <= 0 then
        return
    end
    local list = {}
    for _, row in ipairs(order) do
        if row.lost > 0 then
            list[#list + 1] = { name = row.name, lost = row.lost, max = row.max, mine = row.mine, share = row.share }
        end
    end
    table.sort(list, function(a, b) return a.lost > b.lost end)
    record.bosses = list
    record.bossShare = math.min(1, mine / lost)
    record.bossLost = lost
end

-- The share for a target name of a record; nil when it is not one of its bosses.
function bosses.TargetShare(record, name)
    for _, row in ipairs(record.bosses or {}) do
        if row.name == name then
            return row.share
        end
    end
    return nil
end
