PBsHpsChecker = PBsHpsChecker or {}
local ADDON = PBsHpsChecker

---------------------------------------------------------------------------------------------------
-- Probe: which heals does the game send to the add-on at all?
--
-- The add-on counts only the heals the player casts (the combat registrations are filtered on the
-- player as source). Whether it could also see what OTHER healers do to a player -- how much of a
-- party member's incoming healing is the player's, say -- depends on which combat events the client
-- delivers, and that is not documented. This measures it.
--
-- /hps probe registers the four heal results again with NO source or target filter, counts every
-- heal that arrives by (source type, target type), and stops by itself after PROBE_MS or when asked
-- again. It then prints the pairs it saw, and a yes / no for the cases that matter:
--
--     player          > party member       baseline: the add-on's own heals (must be yes if any were cast)
--     player          > outside the party  baseline
--     party member    > party member       another healer in the party healing a party member
--     outside party   > party member       a healer outside the party healing a party member
--     outside party   > outside party      two strangers (what the add-on could never see otherwise)
--
-- Nothing is saved and the records are not touched: it is a measurement, not a feature. It is off
-- until asked for, because with no filter every heal in a big fight reaches the handler.
---------------------------------------------------------------------------------------------------

local probe = { running = false }
ADDON.probe = probe

local PROBE_MS = 120000
-- Distinct source names remembered per pair: enough to count a handful of healers, not a whole zerg.
local MAX_NAMES = 200

local HEAL_RESULTS = {
    { name = "Heal", result = ACTION_RESULT_HEAL },
    { name = "CritHeal", result = ACTION_RESULT_CRITICAL_HEAL },
    { name = "Tick", result = ACTION_RESULT_HOT_TICK },
    { name = "CritTick", result = ACTION_RESULT_HOT_TICK_CRITICAL },
}

-- A heal can arrive with no name for its source or its target (the first PS5 run saw 65 of them, type NONE
-- on both sides, amount 0). Such an event still carries the unit IDs, and an ID is named by any other
-- event that has its name, so the IDs are remembered with their names and types and the nameless
-- events are resolved when the result is printed (an ID may be named only after the nameless event).
local MAX_UNITS = 400
local MAX_NAMELESS = 60
-- Lines printed for nameless pairs: the result goes to the chat, which scrolls.
local NAMELESS_LINES = 4

local rows = {}
local known = {}
local knownCount = 0
local nameless = {}
local namelessCount = 0
local namelessLost = 0

local function L(id)
    return GetString(id)
end

local function Plain(name)
    return (tostring(name or ""):gsub("%^.*$", ""))
end

local function Learn(unitId, name, unitType)
    if type(unitId) ~= "number" or unitId <= 0 or name == nil or name == "" then
        return
    end
    if known[unitId] == nil then
        if knownCount >= MAX_UNITS then
            return
        end
        knownCount = knownCount + 1
    end
    known[unitId] = { name = Plain(name), type = unitType }
end

-- rows[sourceType][targetType] = { events, amount, overflow, people, names = {}, sample, ability }
local function OnHeal(_, _, isError, abilityName, _, _, sourceName, sourceType, targetName, targetType, hitValue,
                      _, _, _, sourceUnitId, targetUnitId, abilityId, overflow)
    if isError then
        return
    end
    Learn(sourceUnitId, sourceName, sourceType)
    Learn(targetUnitId, targetName, targetType)

    local row = rows[sourceType]
    if not row then
        row = {}
        rows[sourceType] = row
    end
    local cell = row[targetType]
    if not cell then
        cell = {
            events = 0, amount = 0, overflow = 0, people = 0, names = {},
            sample = Plain(sourceName) .. " > " .. Plain(targetName),
            ability = Plain(abilityName),
        }
        row[targetType] = cell
    end
    cell.events = cell.events + 1
    cell.amount = cell.amount + (tonumber(hitValue) or 0)
    cell.overflow = cell.overflow + (tonumber(overflow) or 0)
    if cell.people < MAX_NAMES and not cell.names[sourceName] then
        cell.names[sourceName] = true
        cell.people = cell.people + 1
    end

    if sourceName == nil or sourceName == "" or targetName == nil or targetName == "" then
        local key = tostring(sourceUnitId) .. ">" .. tostring(targetUnitId)
        local pair = nameless[key]
        if not pair then
            if namelessCount >= MAX_NAMELESS then
                namelessLost = namelessLost + 1
                return
            end
            namelessCount = namelessCount + 1
            pair = {
                events = 0, sourceId = sourceUnitId, targetId = targetUnitId,
                sourceName = Plain(sourceName), sourceType = sourceType,
                targetName = Plain(targetName), targetType = targetType,
                ability = Plain(abilityName), abilityId = abilityId,
            }
            nameless[key] = pair
        end
        pair.events = pair.events + 1
    end
end

-- Who a unit ID is, as far as this run learned: name and type from the event itself, else from another
-- event that named the ID, else nothing.
local function Resolve(unitId, ownName, ownType)
    if ownName ~= "" then
        return ownName, ownType
    end
    local unit = known[unitId]
    if unit then
        return unit.name, unit.type
    end
    return nil, ownType
end

local function Described(name, unitType, unitId)
    if name then
        return string.format("%s (%s)", name, ADDON.TypeName(unitType))
    end
    return string.format("ID %s (%s)", tostring(unitId), ADDON.TypeName(unitType))
end

local function Cell(sourceType, targetType)
    local row = rows[sourceType]
    return row and row[targetType] or nil
end

function probe:Start(nowMs)
    rows = {}
    known, knownCount = {}, 0
    nameless, namelessCount, namelessLost = {}, 0, 0
    self.running = true
    self.startedMs = nowMs
    self.endsMs = nowMs + PROBE_MS
    for _, entry in ipairs(HEAL_RESULTS) do
        local namespace = ADDON.name .. "Probe" .. entry.name
        EVENT_MANAGER:RegisterForEvent(namespace, EVENT_COMBAT_EVENT, OnHeal)
        EVENT_MANAGER:AddFilterForEvent(namespace, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, entry.result)
    end
    ADDON.Print(string.format(L(SI_PBSHPS_PROBE_START), PROBE_MS / 1000))
end

-- The lines of the result, as text. Separate from printing so that it can be tested.
function probe:Lines(seconds)
    local lines = { string.format(L(SI_PBSHPS_PROBE_HEADING), seconds) }

    local pairsSeen = {}
    for sourceType, row in pairs(rows) do
        for targetType, cell in pairs(row) do
            pairsSeen[#pairsSeen + 1] = { source = ADDON.TypeName(sourceType), target = ADDON.TypeName(targetType), cell = cell }
        end
    end
    table.sort(pairsSeen, function(a, b)
        if a.source ~= b.source then
            return a.source < b.source
        end
        return a.target < b.target
    end)
    if #pairsSeen == 0 then
        lines[#lines + 1] = "  " .. L(SI_PBSHPS_PROBE_NONE)
    end
    for _, seen in ipairs(pairsSeen) do
        local cell = seen.cell
        local sample = cell.sample
        if cell.ability ~= "" then
            sample = sample .. " [" .. cell.ability .. "]"
        end
        lines[#lines + 1] = string.format(L(SI_PBSHPS_PROBE_LINE), seen.source, seen.target, cell.events,
            ADDON.records.Commas(cell.amount) .. "/" .. ADDON.records.Commas(cell.overflow), cell.people, sample)
    end

    -- The events that came without a name, resolved through the IDs: the busiest pairs first, and how
    -- many of all of them are aimed at somebody the run knows to be a party member.
    local resolved = {}
    local namelessToGroup, namelessTotal = 0, 0
    for _, pair in pairs(nameless) do
        local sourceName, sourceType = Resolve(pair.sourceId, pair.sourceName, pair.sourceType)
        local targetName, targetType = Resolve(pair.targetId, pair.targetName, pair.targetType)
        local ability = pair.ability
        if ability == "" and type(pair.abilityId) == "number" and pair.abilityId > 0 then
            ability = "#" .. tostring(pair.abilityId)
        end
        resolved[#resolved + 1] = {
            events = pair.events, ability = ability,
            source = Described(sourceName, sourceType, pair.sourceId),
            target = Described(targetName, targetType, pair.targetId),
        }
        namelessTotal = namelessTotal + pair.events
        if targetName and targetType == COMBAT_UNIT_TYPE_GROUP then
            namelessToGroup = namelessToGroup + pair.events
        end
    end
    table.sort(resolved, function(a, b)
        if a.events ~= b.events then
            return a.events > b.events
        end
        return a.source .. a.target < b.source .. b.target
    end)
    for index = 1, math.min(#resolved, NAMELESS_LINES) do
        local pair = resolved[index]
        lines[#lines + 1] = string.format(L(SI_PBSHPS_PROBE_NAMELESS), pair.events, pair.source, pair.target,
            pair.ability ~= "" and pair.ability or "?")
    end

    local PLAYER, GROUP, OTHER = COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_GROUP, COMBAT_UNIT_TYPE_OTHER
    lines[#lines + 1] = L(SI_PBSHPS_PROBE_LEGEND)
    for _, question in ipairs({
        { SI_PBSHPS_PROBE_Q_SELF_GROUP, PLAYER, GROUP },
        { SI_PBSHPS_PROBE_Q_SELF_OTHER, PLAYER, OTHER },
        { SI_PBSHPS_PROBE_Q_GROUP_GROUP, GROUP, GROUP },
        { SI_PBSHPS_PROBE_Q_OTHER_GROUP, OTHER, GROUP },
        { SI_PBSHPS_PROBE_Q_OTHER_OTHER, OTHER, OTHER },
    }) do
        local cell = Cell(question[2], question[3])
        lines[#lines + 1] = "  " .. L(question[1]) .. "  "
            .. (cell and string.format(L(SI_PBSHPS_PROBE_YES), cell.events) or L(SI_PBSHPS_PROBE_NO))
    end
    if namelessTotal > 0 then
        lines[#lines + 1] = "  " .. L(SI_PBSHPS_PROBE_Q_NAMELESS_GROUP) .. "  "
            .. (namelessToGroup > 0 and string.format(L(SI_PBSHPS_PROBE_YES), namelessToGroup)
                or L(SI_PBSHPS_PROBE_NO))
    end
    lines[#lines + 1] = L(SI_PBSHPS_PROBE_CAVEAT)
    return lines
end

function probe:Stop(nowMs)
    if not self.running then
        return
    end
    self.running = false
    for _, entry in ipairs(HEAL_RESULTS) do
        EVENT_MANAGER:UnregisterForEvent(ADDON.name .. "Probe" .. entry.name, EVENT_COMBAT_EVENT)
    end
    for _, line in ipairs(self:Lines(math.floor((nowMs - self.startedMs) / 1000 + 0.5))) do
        ADDON.Print(line)
    end
end

function probe:Toggle(nowMs)
    if self.running then
        self:Stop(nowMs)
    else
        self:Start(nowMs)
    end
end

-- Called about once a second.
function probe:Tick(nowMs)
    if self.running and nowMs >= self.endsMs then
        self:Stop(nowMs)
    end
end

-- How long it has left, for /hps status; nil when it is not running.
function probe:SecondsLeft(nowMs)
    if not self.running then
        return nil
    end
    return math.max(0, math.floor((self.endsMs - nowMs) / 1000))
end
