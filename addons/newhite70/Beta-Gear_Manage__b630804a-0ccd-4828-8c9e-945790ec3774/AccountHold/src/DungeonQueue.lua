-- AccountHold/src/DungeonQueue.lua
--
-- Turns the Priorities activity plan into real Dungeon Finder actions:
--   * queue for exactly the prioritized dungeons, and
--   * pick one at random to travel to (rotation variety without the player
--     always defaulting to the top of the list).
--
-- WHY THIS IS A MODEL AND NOT A UI HOOK
-- -------------------------------------
-- The obvious request is "add a Quartermaster tab to the gamepad Dungeon
-- Finder". That surface is the highest-risk integration available: no known
-- add-on decorates the GAMEPAD activity finder (BetterDungeonFinder, the
-- closest prior art, ships "Gamepad Support: x"), the entry builder is a LOCAL
-- function inside ZO_ActivityFinderTemplate_Gamepad:RefreshView so it cannot be
-- hooked directly, and ClearAndUpdate() calls ClearSelections() on group/level/
-- cooldown events -- which would silently wipe any selection we injected.
--
-- None of that is needed. StartActivityFinderSearch() queues directly, so the
-- capability the player actually wants (pick prioritized dungeons, queue for
-- them) needs no base-UI surgery at all. This module owns that capability; the
-- UI simply calls it.
--
-- VERIFIED API CONTRACT (ESOUIDocumentation.txt, fetched from esoui/esoui
-- @ master). NONE of these carry the *protected* marker -- only 36 functions in
-- the whole API do, and they are all cursor / action-bar / keybind operations:
--   ClearActivityFinderSearch()
--   AddActivityFinderSpecificSearchEntry(integer activityId)
--   StartActivityFinderSearch()
--   GetNumActivitiesByType(LFGActivity activity)
--   GetActivityIdByTypeAndIndex(LFGActivity activity, luaindex index)
--   GetActivityName(integer activityId)
--   GetActivityZoneId(integer activityId)
--
-- The Priorities plan describes activities by NAME (data/setSources.lua stores
-- activityName / activityKey, not an LFG activityId), so this module builds a
-- name -> activityId index the same way src/Travel.lua builds its wayshrine
-- name index. Name matching is the join, and it is normalized on both sides.
--
-- ESO runs Lua 5.1: no goto, no //, no bitwise operators. Every ZOS global is
-- type-guarded so this file loads under tests/zos_mock.lua with none present.

AccountHold = AccountHold or {}
AccountHold.DungeonQueue = AccountHold.DungeonQueue or {}

local DQ = AccountHold.DungeonQueue

-- The activity types a gear-farming plan can actually queue for. Battlegrounds,
-- Tribute and Home Show are deliberately excluded: no gear sets drop there, so
-- including them could only ever produce a wrong match.
local QUEUEABLE_TYPE_NAMES = {
    "LFG_ACTIVITY_DUNGEON",
    "LFG_ACTIVITY_MASTER_DUNGEON",
    "LFG_ACTIVITY_TRIAL",
    "LFG_ACTIVITY_ARENA",
}

DQ._QUEUEABLE_TYPE_NAMES = QUEUEABLE_TYPE_NAMES

-- ---------------------------------------------------------------------------
-- Pure helpers (ZO-free, testable)
-- ---------------------------------------------------------------------------

-- Fold a display name to a comparison key. Dungeon names differ between our
-- data file and the client only by punctuation, case and roman-numeral spacing,
-- so strip everything that is not alphanumeric. "Fungal Grotto I" and
-- "Fungal Grotto  I." both fold to "fungalgrottoi".
function DQ.NormalizeName(s)
    if type(s) ~= "string" then return nil end
    local out = string.lower(s)
    out = string.gsub(out, "[^%w]", "")
    if out == "" then return nil end
    return out
end

-- Deterministic, dependency-free selection used by the travel action.
--
-- `roll` is injected so the behaviour is testable: a caller passes nothing and
-- gets math.random, a test passes an exact value. Returns nil for an empty list
-- rather than erroring.
function DQ.PickOne(entries, roll)
    if type(entries) ~= "table" then return nil end
    local n = #entries
    if n == 0 then return nil end
    if n == 1 then return entries[1] end

    local index
    if type(roll) == "number" then
        -- Accept either a 1..n index or a 0..1 fraction, so a test can express
        -- whichever is clearer.
        if roll >= 1 then
            index = math.floor(roll)
        else
            index = math.floor(roll * n) + 1
        end
    elseif type(math.random) == "function" then
        index = math.random(1, n)
    else
        index = 1
    end

    if index < 1 then index = 1 end
    if index > n then index = n end
    return entries[index]
end

-- ---------------------------------------------------------------------------
-- Activity resolution
-- ---------------------------------------------------------------------------

-- Build { [normalizedName] = activityId } across every queueable activity type.
-- Returns an empty table (never nil) when the API is absent, so callers can
-- treat "no client API" and "no matches" identically.
function DQ:BuildActivityIndex()
    local index = {}
    if type(GetNumActivitiesByType) ~= "function"
       or type(GetActivityIdByTypeAndIndex) ~= "function"
       or type(GetActivityName) ~= "function" then
        return index
    end

    for _, typeName in ipairs(QUEUEABLE_TYPE_NAMES) do
        local activityType = _G and _G[typeName]
        if activityType ~= nil then
            local okCount, count = pcall(GetNumActivitiesByType, activityType)
            if okCount and type(count) == "number" then
                for i = 1, count do
                    local okId, activityId = pcall(GetActivityIdByTypeAndIndex, activityType, i)
                    if okId and type(activityId) == "number" then
                        local okName, name = pcall(GetActivityName, activityId)
                        if okName then
                            local key = DQ.NormalizeName(name)
                            -- First match wins: normal difficulty is enumerated
                            -- before veteran, and a player queueing from a gear
                            -- plan wants the accessible one.
                            if key and index[key] == nil then
                                index[key] = activityId
                            end
                        end
                    end
                end
            end
        end
    end
    return index
end

-- Map ONE plan activity onto an LFG activity id, or nil when it is not a
-- queueable activity (overland zones, crafting sites, and the synthetic
-- "source unknown" row all legitimately return nil).
function DQ:FindActivityId(activity, index)
    if type(activity) ~= "table" then return nil end
    if activity.activityKey == "unknown" then return nil end
    index = index or self:BuildActivityIndex()
    local key = DQ.NormalizeName(activity.activityName)
    if not key then return nil end
    return index[key]
end

-- Resolve the whole Priorities plan into queueable entries.
--
-- Returns (entries, unmatched) where each entry is
--   { activity = <plan activity>, activityId = <number>, name = <string> }
-- and `unmatched` counts plan rows that describe no queueable activity. The
-- caller reports that count rather than silently queueing a subset -- a player
-- who asked for five dungeons and got three needs to know.
function DQ:ResolvePlan(plan)
    local entries, unmatched = {}, 0
    if type(plan) ~= "table" then return entries, unmatched end

    local index = self:BuildActivityIndex()
    local seen = {}
    for i = 1, #plan do
        local activity = plan[i]
        local activityId = self:FindActivityId(activity, index)
        if activityId and not seen[activityId] then
            seen[activityId] = true
            entries[#entries + 1] = {
                activity   = activity,
                activityId = activityId,
                name       = activity.activityName,
            }
        elseif not activityId then
            unmatched = unmatched + 1
        end
    end
    return entries, unmatched
end

-- Normal and Veteran are two DIFFERENT LFG activity types, not a difficulty
-- flag on one id (zo_dungeonfinder_manager.lua:31 builds the dungeon finder as
-- ZO_ActivityFinderFilterModeData:New(LFG_ACTIVITY_DUNGEON,
-- LFG_ACTIVITY_MASTER_DUNGEON), and the finder renders one tab per type at
-- zo_activityfindertemplate_gamepad.lua:551-600).
--
-- BuildActivityIndex above folds EVERY type into one map with first-match-wins,
-- and LFG_ACTIVITY_DUNGEON is scanned first, so a veteran id can never win a
-- lookup there. Callers that must distinguish difficulty need a per-type index.
--
-- We deliberately do NOT touch SetVeteranDifficulty: veterandifficultysettings.lua:141-143
-- is its only caller, from the group-difficulty toggle, and it mutates the
-- player's GROUP settings as a side effect. The activity id alone carries the
-- difficulty (zo_activityfinderroot_classes.lua:325-327 submits only the id).
DQ.DIFFICULTY_TYPE_NAMES = {
    normal  = "LFG_ACTIVITY_DUNGEON",
    veteran = "LFG_ACTIVITY_MASTER_DUNGEON",
}

-- Index one activity type. `activityTypeName` is a STRING key into _G, never a
-- captured number: the numeric constants are client-version dependent and
-- absent under the mock harness.
--
-- Returns { [normalizedName] = activityId } -- always a table, never nil.
--
-- Registers BOTH the folded name and a "veteran"-prefix-stripped alias, because
-- GetActivityName may bake the word into the raw name in some locales while
-- zo_activityfinderroot_classes.lua:316-323 applies the marker at DISPLAY time.
-- Matching either form keeps the join working both ways.
function DQ:BuildActivityIndexByType(activityTypeName)
    local index = {}
    if type(activityTypeName) ~= "string" then return index end
    if type(GetNumActivitiesByType) ~= "function"
       or type(GetActivityIdByTypeAndIndex) ~= "function"
       or type(GetActivityName) ~= "function" then
        return index
    end

    local activityType = _G and _G[activityTypeName]
    if activityType == nil then return index end

    local okCount, count = pcall(GetNumActivitiesByType, activityType)
    if not okCount or type(count) ~= "number" then return index end

    for i = 1, count do
        local okId, activityId = pcall(GetActivityIdByTypeAndIndex, activityType, i)
        if okId and type(activityId) == "number" then
            local okName, name = pcall(GetActivityName, activityId)
            if okName and type(name) == "string" and name ~= "" then
                local key = DQ.NormalizeName(name)
                if key and index[key] == nil then index[key] = activityId end
                -- "Veteran Fungal Grotto I" must also answer to "Fungal Grotto I",
                -- or a plan naming the plain dungeon can never find the vet id.
                local stripped = string.gsub(string.lower(name), "^%s*veteran%s+", "")
                local altKey = DQ.NormalizeName(stripped)
                if altKey and index[altKey] == nil then index[altKey] = activityId end
            end
        end
    end
    return index
end

-- Everything currently on the Priorities plan that can be queued for.
function DQ:GetPrioritizedActivities()
    local P = AccountHold and AccountHold.Priorities
    if type(P) ~= "table" or type(P.BuildPlan) ~= "function" then return {}, 0 end
    local ok, plan = pcall(P.BuildPlan, P)
    if not ok or type(plan) ~= "table" then return {}, 0 end
    return self:ResolvePlan(plan)
end

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------

-- Queue for exactly these activities.
--
-- Returns (queued, reason). `queued` is the number of entries submitted;
-- reason is a short machine key on failure ("no_api" / "empty" / "start_failed").
--
-- Order matters and is deliberate: Clear first, so a previous search cannot
-- leave stale selections in the queue; Add each; Start last.
function DQ:QueueFor(entries)
    if type(entries) ~= "table" or #entries == 0 then return 0, "empty" end
    if type(ClearActivityFinderSearch) ~= "function"
       or type(AddActivityFinderSpecificSearchEntry) ~= "function"
       or type(StartActivityFinderSearch) ~= "function" then
        return 0, "no_api"
    end

    if not pcall(ClearActivityFinderSearch) then return 0, "no_api" end

    local added = 0
    for i = 1, #entries do
        local e = entries[i]
        if type(e) == "table" and type(e.activityId) == "number" then
            if pcall(AddActivityFinderSpecificSearchEntry, e.activityId) then
                added = added + 1
            end
        end
    end
    if added == 0 then
        pcall(ClearActivityFinderSearch)
        return 0, "empty"
    end

    -- StartActivityFinderSearch REPORTS failure through its return value
    -- (ActivityQueueResult, ESOUIDocumentation.txt); it does not throw. Only
    -- "did not throw" was checked before, so a refused queue was announced
    -- to the player as "Queued for N dungeon(s)".
    local okStart, result = pcall(StartActivityFinderSearch)
    if not okStart then
        return 0, "start_failed"
    end
    if type(result) == "number" and ACTIVITY_QUEUE_RESULT_SUCCESS ~= nil
       and result ~= ACTIVITY_QUEUE_RESULT_SUCCESS then
        return 0, "start_failed", result
    end
    return added
end

-- Queue for everything currently prioritized.
function DQ:QueueForPrioritized()
    local entries, unmatched = self:GetPrioritizedActivities()
    local queued, reason = self:QueueFor(entries)
    return queued, reason, unmatched
end

-- Pick one prioritized activity at random. Returns the entry, or nil.
--
-- Random rather than first-in-list is the point: a player working a gear plan
-- would otherwise run the same dungeon every time, which is exactly the
-- rotation staleness the queue normally solves for them.
function DQ:PickRandomPrioritized(roll)
    local entries = self:GetPrioritizedActivities()
    return DQ.PickOne(entries, roll)
end
