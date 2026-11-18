-- Triggers turn game data into "states": one state per thing a display should show (a debuff on an
-- enemy, a missing buff on a group member, a running proc timer, a boss's health...).
--
-- State fields: key (stable identity across ticks), name, unitName, icon, abilityId, start, expire,
-- duration (0 = permanent/untimed), stacks, active (false = missing/ready), isTarget, isBoss, mine,
-- value/max/pct (resources), order (application order), sourceName.

local DT = DebuffTracker
local T = DT.Triggers
local U = DT.Util
local C = DT.Const
local E = DT.Effects
local Units = DT.Units

------------------------------------------------------------------------------
-- Compilation (cached until the tracker is edited)
------------------------------------------------------------------------------

local compiled = setmetatable({}, { __mode = "k" })

function T.ClearCache()
    compiled = setmetatable({}, { __mode = "k" })
end

-- Extra triggers: each runs as a light proxy of the tracker (same display, name, conditions) with
-- its own trigger and its own id for ability timers ("<id>#x<n>"). Entries of all triggers are shown
-- together in the one tracker.
local proxies = setmetatable({}, { __mode = "k" })
local function TriggerProxy(tracker, i)
    local list = proxies[tracker]
    if not list then list = {}; proxies[tracker] = list end
    local tr = tracker.extraTriggers[i]
    local p = list[i]
    if not p or rawget(p, "trigger") ~= tr then
        p = setmetatable({ id = tracker.id .. "#x" .. i, trigger = tr }, { __index = tracker })
        list[i] = p
    end
    return p
end
T.TriggerProxy = TriggerProxy

-- every trigger of a tracker: { {tracker-or-proxy, prefix}, ... }
function T.AllTriggers(tracker)
    local all = { tracker }
    for i = 1, #(tracker.extraTriggers or {}) do all[#all + 1] = TriggerProxy(tracker, i) end
    return all
end

-- The player's own icon for one listed ability (tutsuraki): an ability ID (its icon) or a texture path.
function T.CustomIcon(tr, key)
    local v = tr and tr.abilityIcons and tr.abilityIcons[U.Lower(tostring(key))]
    if not v or v == "" then return nil end
    local n = tonumber(v)
    if n then
        local icon = GetAbilityIcon(n)
        return (icon and icon ~= "") and icon or nil
    end
    return v
end

-- The player's own variants of a listed ability (ID or name): other IDs that count as it.
local NO_VARIANTS = {}
function T.Variants(tr, key)
    return (tr and tr.variants and tr.variants[U.Lower(tostring(key))]) or NO_VARIANTS
end

-- Every ability ID a trigger listens for: its list plus the player's variants (for event registrations).
function T.AllIds(tr)
    local v = tr.variants
    if not v or next(v) == nil then return tr.abilityIds end
    local out, seen = {}, {}
    for _, id in ipairs(tr.abilityIds) do if not seen[id] then seen[id] = true; out[#out + 1] = id end end
    for _, list in pairs(v) do
        for _, id in ipairs(list) do if not seen[id] then seen[id] = true; out[#out + 1] = id end end
    end
    return out
end

-- The icon for an effect the tracker matches by name: a known effect's own icon (Major / Minor buffs and
-- debuffs, Off Balance), else the icon last seen on an effect with that name, else the icon the abilities
-- with that name have (the ability search index -- built in the background the first time), else nil.
function T.NameIcon(lname)
    lname = U.Lower(U.Trim(lname or ""))
    local id = C.NAME_ICON_IDS[lname]
    if id then
        local icon = GetAbilityIcon(id)
        if icon and icon ~= "" then return icon end
    end
    local learned = E.LearnedIcon and E.LearnedIcon(lname)
    if learned then return learned end
    return DT.AbilitySearch and DT.AbilitySearch.IconForName and DT.AbilitySearch.IconForName(lname) or nil
end

function T.TrackerIcon(tracker)
    local o = tracker.iconOverride
    if o and o ~= "" then
        local n = tonumber(o)
        if n then return GetAbilityIcon(n) end
        return o
    end
    local id = tracker.trigger.abilityIds[1]
    local first = id or (tracker.trigger.names or {})[1]
    local own = first and T.CustomIcon(tracker.trigger, first)
    if own then return own end
    if id then
        local icon = GetAbilityIcon(id)
        if icon and icon ~= "" then return icon end
    end
    -- added by name only: that effect's icon instead of the game's red "?" (tutsuraki)
    for _, n in ipairs(tracker.trigger.names or {}) do
        local icon = T.NameIcon(n)
        if icon then return icon end
    end
    return C.DEFAULT_ICON
end

local function Capitalize(s)
    return (s:gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end))
end

local function Compile(tracker)
    local c = compiled[tracker]
    if c then return c end
    local tr = tracker.trigger
    -- keyOf: which listed ability an ID counts as ("i:<id>"), so a listed ID and its variants make ONE row per unit
    -- (Casual player Geldis: 75753 on the target showed two rows, "Roar of Alkosh" and "Line-Breaker" -- the target's
    -- buff list has both IDs, and they were kept apart by ID). exact: listed IDs whose built-in variants are off.
    c = { ids = {}, names = {}, groups = {}, keyOf = {}, keyOfName = {}, exact = {} }
    local noCopies = tr.noCopies or {}
    for _, id in ipairs(tr.abilityIds) do
        local custom = T.CustomIcon(tr, id)
        local g = { label = U.CleanName(GetAbilityName(id)), icon = custom or GetAbilityIcon(id), fixedIcon = custom ~= nil, ids = { [id] = true }, names = {} }
        if g.label == "" then g.label = "#" .. id end
        c.ids[id] = true
        if noCopies[tostring(id)] then
            c.exact[id] = true
            g.exact = true
        else
            for _, copy in ipairs(E.Copies(id)) do c.ids[copy] = true; g.ids[copy] = true end
        end
        for _, vid in ipairs(T.Variants(tr, id)) do
            c.ids[vid] = true; g.ids[vid] = true
            for _, copy in ipairs(E.Copies(vid)) do c.ids[copy] = true; g.ids[copy] = true end
        end
        c.groups[#c.groups + 1] = g
        local key = "i:" .. id
        for gid in pairs(g.ids) do if c.keyOf[gid] == nil then c.keyOf[gid] = key end end
    end
    for _, n in ipairs(tr.names) do
        c.names[n] = true
        local custom = T.CustomIcon(tr, n)
        local g = { label = Capitalize(n), icon = custom or T.NameIcon(n) or T.TrackerIcon(tracker), fixedIcon = custom ~= nil,
            ids = {}, names = { [n] = true } }
        for _, vid in ipairs(T.Variants(tr, n)) do
            c.ids[vid] = true; g.ids[vid] = true
            for _, copy in ipairs(E.Copies(vid)) do c.ids[copy] = true; g.ids[copy] = true end
        end
        c.groups[#c.groups + 1] = g
        local key = "n:" .. n
        if c.keyOfName[n] == nil then c.keyOfName[n] = key end
        for gid in pairs(g.ids) do if c.keyOf[gid] == nil then c.keyOf[gid] = key end end
    end
    c.icon = T.TrackerIcon(tracker)
    c.missingName = tracker.display.title ~= "" and tracker.display.title or tracker.name
    compiled[tracker] = c
    return c
end
T.Compile = Compile

------------------------------------------------------------------------------
-- Effect triggers
------------------------------------------------------------------------------

local function PassesFilters(tr, e)
    if tr.effectType == "buff" and e.effectType ~= BUFF_EFFECT_TYPE_BUFF then return false end
    if tr.effectType == "debuff" and e.effectType ~= BUFF_EFFECT_TYPE_DEBUFF then return false end
    if tr.source == "me" and not e.mine then return false end
    if tr.source == "others" and e.mine then return false end
    if tr.minStacks > 0 and (e.stacks or 0) < tr.minStacks then return false end
    return true
end

-- Enemy-store entries carry the best instance of everyone's (the entry itself), of yours (e.my) and
-- of everyone else's (e.others): "cast by me" follows YOUR instance's timer, not someone else's.
local function ForSource(tr, e)
    if tr.source == "me" then return e.my or e end
    if tr.source == "others" then return e.others or e end
    return e
end

-- (an ID whose built-in variants are off -- "exact" -- doesn't match its variants through their shared base ID)
local function MatchesGroup(g, e)
    return g.ids[e.abilityId] or (g.ids[e.baseId] and not g.exact) or g.names[e.lname]
end

local function Matches(c, e)
    return c.ids[e.abilityId] or (c.ids[e.baseId] and not c.exact[e.baseId]) or c.names[e.lname]
end

-- the row an entry belongs to: the listed ability (or name) it counts as
local function RowKey(c, e)
    return c.keyOf[e.abilityId] or (not c.exact[e.baseId] and c.keyOf[e.baseId]) or c.keyOfName[e.lname] or e.baseId
end

-- Entry tables are reused (5.13.1). An update over a trial pull builds hundreds of them (25 enemies x
-- the raid board's debuffs, the Off Balance cycle, the group boards ...) ten times a second: megabytes of
-- garbage a second mid-fight, which the game collects in the middle of the fight. A table made in one
-- update is still read until the next one has replaced it (the displays animate it every frame, "keep
-- it after it ends" compares against it), so it's freed at the end of the update AFTER the one that
-- made it and reused from then on.
local statePool, poolN = {}, 0
local liveGen, prevGen = {}, {}
local POOL_MAX = 3000

local function NewState()
    local s
    if poolN > 0 then
        s = statePool[poolN]
        statePool[poolN] = nil
        poolN = poolN - 1
        for k in pairs(s) do s[k] = nil end
    else
        s = {}
    end
    liveGen[#liveGen + 1] = s
    return s
end

-- Called by the engine after every update (all displays rendered).
function T.EndUpdate()
    for i = #prevGen, 1, -1 do
        if poolN < POOL_MAX then poolN = poolN + 1; statePool[poolN] = prevGen[i] end
        prevGen[i] = nil
    end
    prevGen, liveGen = liveGen, prevGen
end

function T.PoolStats() return poolN, #liveGen, #prevGen end

local function StateFromEntry(key, e, unitName, isTarget, isBoss)
    local timed = e.finish > e.begin
    local s = NewState()
    s.key, s.name, s.unitName, s.icon, s.abilityId = key, e.name, unitName, e.icon, e.abilityId
    s.baseId, s.lname = e.baseId, e.lname     -- (which listed ability it is: its "slot")
    s.start, s.expire, s.duration = e.begin, timed and e.finish or 0, timed and (e.finish - e.begin) or 0
    s.stacks, s.active, s.isTarget, s.isBoss, s.mine = e.stacks, true, isTarget, isBoss, e.mine
    s.order = e.order or e.begin
    -- Touch of Z'en & co.: 0 and 1 are real values (see C.ZERO_BASED_STACKS)
    s.allStacks = C.ZERO_BASED_STACKS[e.baseId or e.abilityId] or C.ZERO_BASED_STACKS[e.abilityId] or nil
    return s
end

local function MissingState(key, name, icon, unitName, isTarget, isBoss)
    local s = NewState()
    s.key, s.name, s.unitName, s.icon, s.start, s.expire = key, name, unitName or "", icon, 0, 0
    s.duration, s.stacks, s.active, s.isTarget, s.isBoss, s.mine, s.order = 0, 0, false, isTarget, isBoss, false, 0
    return s
end

local function ScopeTags(scope, index)
    if scope == "player" then return { "player" } end
    if scope == "target" then return DoesUnitExist("reticleover") and { "reticleover" } or {} end
    -- a specific boss / group member ("boss 2", "group member 3") when index > 0
    if scope == "boss" then
        if (index or 0) > 0 then return DoesUnitExist("boss" .. index) and { "boss" .. index } or {} end
        return Units.BossTags()
    end
    if scope == "group" then
        if (index or 0) > 0 then return DoesUnitExist("group" .. index) and { "group" .. index } or {} end
        return Units.GroupTags(true)
    end
    if scope == "companion" then return DoesUnitExist("companion") and { "companion" } or {} end
    return {}
end
T.ScopeTags = ScopeTags

-- Dead units are skipped: a dead boss (its boss tag lives on until the fight ends) or a dead group
-- member is never "missing" anything, and their remaining effects don't matter.
local function LivingTags(scope, index)
    local out = {}
    for _, tag in ipairs(ScopeTags(scope, index)) do
        if not IsUnitDead(tag) then out[#out + 1] = tag end
    end
    return out
end

-- "Cycle" mode: ONE entry per unit that shows the first ability in the tracker's list that is active
-- on it (e.g. Off Balance, then Off Balance Immunity), and "<first ability> ready" when none is.
-- The entry keeps the same key through every phase, so its row never jumps or flickers.
local function GroupIndexOf(c, e)
    for gi, g in ipairs(c.groups) do
        if MatchesGroup(g, e) then return gi end
    end
end

-- "Timer counts down to: Ready" on a cycle (opt-in -- Tony likes Off Balance + immunity as one run; the default,
-- "Each part", counts every phase on its own). Nothing is hard-coded: the length of a phase that hasn't started
-- yet is the one the game gave it the last time it was applied (learned from the effect), or -- before it was
-- ever seen -- the game's own duration for that ability. Once that phase IS applied, its real time from its own
-- event takes over.
local phaseDur = {}     -- [abilityId] = seconds the game gave it last time
local function GroupDuration(g)
    for id in pairs(g.ids) do
        if phaseDur[id] then return phaseDur[id] end
    end
    for id in pairs(g.ids) do
        local ms = type(GetAbilityDuration) == "function" and tonumber(GetAbilityDuration(id)) or 0
        if ms and ms > 0 then return ms / 1000 end
    end
    return 0
end

-- A phase that has just run out while the next one isn't reported yet: Off Balance reaches 0 a moment
-- before the game reports its immunity (Tony's log: 0.06 s later), and for that update the cycle showed
-- "ready" -- a one-frame flash between the two (Tony's video, 5.13.4). A phase that ended less than this
-- long ago is still shown if a later phase can follow it (it never delays the real "ready" after the last).
local HANDOVER = 0.5

local function CycleEntry(key, c, tr, effects, isList, now, unitName, isTarget, isBoss)
    local best, bestGi, recent, recentGi
    local last = #c.groups
    for _, e0 in (isList and ipairs or pairs)(effects) do
        local e = ForSource(tr, e0)
        if PassesFilters(tr, e) then
            local timed = e.finish > e.begin
            if not (timed and e.finish <= now) then
                local gi = GroupIndexOf(c, e)
                if gi and (not bestGi or gi < bestGi) then best, bestGi = e, gi end
            elseif e.finish > now - HANDOVER then
                local gi = GroupIndexOf(c, e)
                if gi and gi < last and (not recentGi or gi < recentGi) then recent, recentGi = e, gi end
            end
        end
    end
    -- nothing running: the phase that just ended hands over to the next one (only before the next shows up)
    if not best and recent then best, bestGi = recent, recentGi end
    local s
    if best then
        s = StateFromEntry(key, best, unitName, isTarget, isBoss)
        s.phase = bestGi
        -- each phase's own time is the one the game reported when that effect was applied (what "Each
        -- part" shows). For "Ready" the run's end is worked out too: this phase + the later ones.
        local d = best.finish - best.begin
        if d > 0 then
            phaseDur[best.abilityId] = d
            if best.baseId then phaseDur[best.baseId] = d end
            local before, after = 0, 0
            for j = 1, bestGi - 1 do before = before + GroupDuration(c.groups[j]) end
            for j = bestGi + 1, #c.groups do after = after + GroupDuration(c.groups[j]) end
            s.cycleWhole = true
            s.wholeStart = s.start - before
            if after > 0 then s.cdEnd = s.expire + after end
        end
    else
        local g = c.groups[1]
        s = MissingState(key, DT.L("<<1>> ready", g and g.label or c.missingName), g and g.icon or c.icon, unitName, isTarget, isBoss)
        s.phase, s.ready = 0, true
    end
    return s
end
T.CycleEntry = CycleEntry

-- A unit can carry the same effect several times (from several players): the game lists each
-- instance. One entry per ability: the instance with the most time left (two entries with the same
-- key made the display leave a frozen copy on screen).
local function BestPerAbility(list, pred, keyOf)
    local best, order = {}, {}
    for _, e in ipairs(list) do
        if pred(e) then
            local id = keyOf and keyOf(e) or e.abilityId
            local b = best[id]
            if not b then
                best[id] = e
                order[#order + 1] = id
            else
                local permE, permB = e.finish <= e.begin, b.finish <= b.begin
                if (permE and not permB) or (permE == permB and e.finish > b.finish) then best[id] = e end
            end
        end
    end
    local out = {}
    for i, id in ipairs(order) do out[i] = best[id] end
    return out
end

-- "Only these roles" (group scope): BuffTheGroup's "show only DPS"
local function RoleAllowed(tr, tag)
    if not tr.unitRoles or next(tr.unitRoles) == nil then return true end
    local role = DT.Conditions.UnitRole({ unitTag = tag })
    return role ~= "" and tr.unitRoles[role] == true
end

-- One unit's entries (a tagged unit's buff list, or the locked tab target's stored effects). keyTag keeps
-- the keys the same either way, so the row doesn't jump when you look back at your tab target.
local function UnitStates(tr, c, now, out, keyTag, list, unitName, isTarget, isBoss)
    local tag = keyTag
    if tr.mode == "cycle" then
        out[#out + 1] = CycleEntry(tag .. ":cycle", c, tr, list, true, now, unitName, isTarget, isBoss)
    elseif tr.perAbility and #c.groups > 0 then
        for gi, g in ipairs(c.groups) do
            local found = false
            -- one row per listed ability: its variants are the same row (the one with the most time left)
            for _, e in ipairs(BestPerAbility(list, function(x) return MatchesGroup(g, x) and PassesFilters(tr, x) end, function() return gi end)) do
                found = true
                if tr.mode ~= "missing" then
                    out[#out + 1] = StateFromEntry(tag .. ":" .. gi, e, unitName, isTarget, isBoss)
                end
            end
            if not found and tr.mode ~= "present" then
                out[#out + 1] = MissingState(tag .. ":" .. gi .. ":missing", g.label, g.icon, unitName, isTarget, isBoss)
                    out[#out].slot = gi
            end
        end
    else
        local found = false
        for _, e in ipairs(BestPerAbility(list, function(x) return Matches(c, x) and PassesFilters(tr, x) end, function(x) return RowKey(c, x) end)) do
            found = true
            if tr.mode ~= "missing" then
                out[#out + 1] = StateFromEntry(tag .. ":" .. RowKey(c, e), e, unitName, isTarget, isBoss)
            end
        end
        if not found and tr.mode ~= "present" then
            out[#out + 1] = MissingState(tag .. ":missing", c.missingName, c.icon, unitName, isTarget, isBoss)
        end
    end
end

-- The locked tab target's effects (DT.TabTarget), as a list like a buff list: timed ones that ran out are left out
local lockList = {}
local function LockedList(unitId, now)
    local n = 0
    for _, e in pairs(E.store[unitId] or {}) do
        if not (e.finish > e.begin and e.finish <= now) then n = n + 1; lockList[n] = e end
    end
    for i = #lockList, n + 1, -1 do lockList[i] = nil end
    return lockList
end

local function EffectStatesTagged(tracker, c, now, out)
    local tr = tracker.trigger
    -- "my target" with a tab target set and locked: the locked enemy while the crosshair isn't on it
    if tr.scope == "target" then
        local TT = DT.TabTarget
        local l = TT and TT.lock
        if l and l.id and not TT.ReticleIsLock() then
            local first = #out + 1
            UnitStates(tr, c, now, out, "reticleover", LockedList(l.id, now), Units.nameOf[l.id] or l.name, true, Units.IsBoss(l.id))
            for i = first, #out do out[i].tabLocked = true end
            return
        end
    end
    -- the cycle on the group keeps EVERY member's row, the dead too (BuffTheGroup keeps all names on
    -- the window), in group order; other modes skip the dead (a dead member isn't "missing" anything)
    local keepAll = tr.mode == "cycle" and tr.scope == "group"
    local tags = keepAll and ScopeTags(tr.scope, tr.unitIndex) or LivingTags(tr.scope, tr.unitIndex)
    for ti, tag in ipairs(tags) do
      if RoleAllowed(tr, tag) then
        local first = #out + 1
        local list = E.Scan(tag, now)
        UnitStates(tr, c, now, out, tag, list, Units.NameForTag(tag), tag == "reticleover", tag:sub(1, 4) == "boss")
        if keepAll and tr.mode == "cycle" then out[first].fixedPos = ti end
        -- which unit an entry belongs to (the "above heads" display places it over that unit)
        for i = first, #out do out[i].unitTag = tag end
      end
    end
end

-- "All enemies": entries come from the event store (enemies that HAVE a matching effect). Missing
-- entries need the list of enemies you're fighting (Units.EngagedList): an enemy without the effect
-- never produces an event, so that list is the only way to know it exists.
-- "Minimum enemy difficulty" (in trials, like 4.x): enemies whose difficulty isn't known yet count
-- as 0 until you've targeted them once (or they're a boss).
local function DifficultyFilter(tr)
    if (tr.minDifficulty or 0) <= 0 or DT.Load.zone.type ~= "trial" then return nil end
    local min = tr.minDifficulty
    return function(unitId) return Units.DifficultyOf(unitId) >= min end
end

local function EffectStatesEnemiesCycle(tracker, c, now, out)
    local tr = tracker.trigger
    local allowed = DifficultyFilter(tr)
    local engaged = {}
    for _, id in ipairs(Units.EngagedList(now)) do
        if not allowed or allowed(id) then engaged[id] = true end
    end
    local done = {}
    for unitId, effects in pairs(E.store) do
      if not allowed or allowed(unitId) then
        local s = CycleEntry(unitId .. ":cycle", c, tr, effects, false, now, Units.nameOf[unitId] or "?",
            Units.IsTarget(unitId), Units.IsBoss(unitId))
        -- an enemy only known for unrelated effects (other trackers' abilities) isn't "ready" unless fought
        if not s.ready or engaged[unitId] then out[#out + 1] = s end
        done[unitId] = true
      end
    end
    for unitId in pairs(engaged) do
        if not done[unitId] then
            out[#out + 1] = CycleEntry(unitId .. ":cycle", c, tr, {}, true, now, Units.nameOf[unitId] or "?",
                Units.IsTarget(unitId), Units.IsBoss(unitId))
        end
    end
end

local function EffectStatesEnemies(tracker, c, now, out)
    local tr = tracker.trigger
    if tr.mode == "cycle" then return EffectStatesEnemiesCycle(tracker, c, now, out) end
    local wantMissing = tr.mode ~= "present"
    local allowed = DifficultyFilter(tr)
    local foundOn = wantMissing and {} or nil     -- [unitId] = true, or { [groupIndex] = true } per ability
    for unitId, effects in pairs(E.store) do
      if not allowed or allowed(unitId) then
        local unitName = Units.nameOf[unitId] or "?"
        local isTarget = Units.IsTarget(unitId)
        local isBoss = Units.IsBoss(unitId)
        for baseId, e0 in pairs(effects) do
            local e = ForSource(tr, e0)
            if Matches(c, e) and PassesFilters(tr, e) and not (e.finish > e.begin and e.finish <= now) then
                if wantMissing then
                    if tr.perAbility then
                        local f = foundOn[unitId]
                        if type(f) ~= "table" then f = {}; foundOn[unitId] = f end
                        for gi, g in ipairs(c.groups) do
                            if MatchesGroup(g, e) then f[gi] = true end
                        end
                    else
                        foundOn[unitId] = true
                    end
                end
                if tr.mode ~= "missing" then
                    local key = e.skey
                    if not key then key = unitId .. ":" .. baseId; e.skey = key end
                    local st = StateFromEntry(key, e, unitName, isTarget, isBoss)
                    st.unitId = unitId
                    out[#out + 1] = st
                end
            end
        end
      end
    end
    if wantMissing then
        for _, unitId in ipairs(Units.EngagedList(now)) do
          if not allowed or allowed(unitId) then
            local unitName = Units.nameOf[unitId] or "?"
            local isTarget, isBoss = Units.IsTarget(unitId), Units.IsBoss(unitId)
            local f = foundOn[unitId]
            if tr.perAbility then
                for gi, g in ipairs(c.groups) do
                    if not (type(f) == "table" and f[gi]) then
                        out[#out + 1] = MissingState(unitId .. ":" .. gi .. ":missing", g.label, g.icon, unitName, isTarget, isBoss)
                        out[#out].slot = gi
                    end
                end
            elseif not f then
                out[#out + 1] = MissingState(unitId .. ":missing", c.missingName, c.icon, unitName, isTarget, isBoss)
            end
          end
        end
    end
end

------------------------------------------------------------------------------
-- Ability timers and resources
------------------------------------------------------------------------------

-- One state for a running timer: phase 1 (active part) or phase 2 (cooldown), nil when over.
local function TimerState(key, t, now, name, icon)
    local s = {
        key = key, name = name or t.name, unitName = t.unitName, icon = icon or t.icon,
        abilityId = t.abilityId, stacks = t.stacks or 0, active = true, mine = true, order = t.order,
        sourceName = t.sourceName, isTarget = false, isBoss = false,
    }
    if t.untimed or now < (t.expire or 0) then
        s.phase = 1
        if t.untimed then
            s.start, s.expire, s.duration = t.start, 0, 0
        else
            s.start, s.expire, s.duration = t.start, t.expire, t.duration
        end
        s.cdEnd = (t.cdEnd or 0) > 0 and t.cdEnd or nil      -- (for "Timer counts down to: ready")
        s.wholeStart = t.start
        return s
    end
    if now < (t.cdEnd or 0) then
        local from = math.max(t.expire or t.start, t.start)
        if from >= t.cdEnd then from = t.start end
        s.phase, s.cooldown = 2, true
        s.start, s.expire, s.duration = from, t.cdEnd, t.cdEnd - from
        s.wholeStart = t.start
        s.stacks = 0
        return s
    end
    return nil
end
T.TimerState = TimerState

local function ReadyState(key, name, icon, readyAt)
    local s = MissingState(key, name, icon, DT.L("Ready"))
    s.phase, s.ready, s.readyAt = 0, true, readyAt
    return s
end

local function CombatStates(tracker, c, now, out)
    local timers = DT.Combat.Timers(tracker.id, now)
    local any = false
    if timers then
        for key, t in pairs(timers) do
            local s
            if t.count then
                -- proc counter: a 1 s flash per proc, then "ready" with the count as stacks
                s = MissingState("timer:" .. tostring(key), t.name, t.icon, DT.L("Ready"))
                s.ready, s.phase, s.stacks = true, 0, t.stacks
                if now < t.expire then s.active, s.ready, s.phase = true, nil, 1 end
            else
                s = TimerState("timer:" .. tostring(key), t, now)
            end
            if s then
                any = true
                s.icon = T.CustomIcon(tracker.trigger, t.abilityId) or s.icon    -- the player's own icon
                out[#out + 1] = s
            end
        end
    end
    if not any and tracker.trigger.showReady then
        local g = c.groups[1]
        out[#out + 1] = ReadyState("ready", g and g.label or c.missingName, g and g.icon or c.icon, DT.Combat.readyAt[tracker.id])
    end
end

-- "My procs": one entry per catalogue proc you have (Core/Procs.lua).
local POWER_OF = { stamina = "stamina", magicka = "magicka", ultimate = "ultimate" }
local GateState, GatePower

-- A resource set (Bahsei's Mania, Coral Riptide, Automated Defense...) as a "proc card": the bonus it
-- gives right now (big number), your resource % (gauge inside the icon + a badge), the point where
-- the bonus is full (a line on the gauge) and how much of the bonus you have (level: "max" / "part" /
-- "none", which colours the card).
local function PowerState(tr, e, key, pct, perfected)
    local Procs = DT.Procs
    local scale = (e.jorvuld and Procs.HasJorvuld()) and 1.4 or 1
    local a = { scalar = (perfected and e.pscalar) or e.scalar, start = e.start, cap = e.cap, div = e.div, scale = scale }
    local v = Procs.Calc(e.calc, pct, a)
    local s = MissingState(key, Procs.DisplayName(e), Procs.Icon(e, tr.procIcon == "set"), "")
    s.active, s.ready, s.value, s.pct, s.calc = true, nil, v, pct, v
    local level
    if e.calc == "missing" then
        local full = Procs.Calc("missing", e.cap or 0, a)
        level = (v >= full - 0.01 and full > 0) and "max" or (v >= 0.5 and "part" or "none")
        s.gaugeMark = (e.cap or 0) / 100
    else
        level = v >= 1 and (pct >= 99.5 and "max" or "part") or "none"
    end
    if level == "none" then s.text = ""
    elseif e.fmt then s.text = string.format(e.fmt, math.floor(v + 0.5))
    else s.text = Procs.CalcText(e.calc, v, 1) end
    s.calcText = s.text
    s.gauge, s.gaugePower, s.level = pct / 100, e.power, level
    s.badge = string.format("%d%%", math.floor(pct + 0.5))
    s.procKey, s.procKind = e.k, e.t
    s.order = e.idx
    return s
end
T.PowerState = PowerState

-- The cost of the Ultimate on your active bar (what an Ultimate cast spends), 0 when unknown
local function SlottedUltimateCost()
    if type(GetSlotAbilityCost) ~= "function" or not ACTION_BAR_ULTIMATE_SLOT_INDEX then return 0 end
    local bar = type(GetActiveHotbarCategory) == "function" and GetActiveHotbarCategory() or nil
    local ok, cost = pcall(GetSlotAbilityCost, ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, COMBAT_MECHANIC_FLAGS_ULTIMATE or POWERTYPE_ULTIMATE, bar)
    return ok and tonumber(cost) or 0
end

-- Halls of Fabrication sets (Master Architect, War Machine, Automated Defense, Inventor's Guard): "1 second
-- per 10 Ultimate spent" when you cast an Ultimate (Tony: the old number, 35.7 s at full Ultimate, was the
-- Ultimate POOL / 2.8 -- Cooldowns does the same; it's wrong). The card now shows:
--   big number   the buff's time left while it runs on you (green), nothing otherwise
--   top right    how long the buff will last if you cast now: casting an Ultimate spends ALL the Ultimate
--                you have, not only its cost (Yarden, 5.12.3: 400 Ultimate + a 100-cost Ultimate = 400
--                spent). Cooldowns does the same -- its value comes from your current Ultimate pool
--                (Tracking.lua OnPowerUpdate -> Interface.lua UpdatePower), never from the cost -- only its
--                divisor is old (pool % / 2.8 = 1 s per 14). The datamined tooltip's 1 s per 10 Ultimate
--                spent is used: your Ultimate / 10 (x1.4 Jorvuld's). ExoY's ProcSet Timer has no HoF sets.
--   bottom strip your Ultimate toward that Ultimate's cost (100% = castable); gauge the same
local function UltState(tr, e, key, now)
    local Procs = DT.Procs
    local cur, max = DT.Resources.Read("player", "ultimate")
    local cost = SlottedUltimateCost()
    local scale = (e.jorvuld and Procs.HasJorvuld()) and 1.4 or 1
    local s = MissingState(key, Procs.DisplayName(e), Procs.Icon(e, tr.procIcon == "set"), "")
    s.active, s.ready = true, nil
    -- what a cast spends: everything you have (Cooldowns: the current Ultimate pool)
    local spendable = cur
    s.info = spendable / e.ultSpent * scale
    s.infoFull = cost > 0 and cur >= cost
    local frac = cost > 0 and math.min(1, cur / cost) or ((max or 0) > 0 and cur / max or 0)
    s.gauge, s.gaugePower = frac, "ultimate"
    s.badge = string.format("%d%%", math.floor(frac * 100 + 0.5))
    s.pct, s.value = frac * 100, cur
    s.level = s.infoFull and "part" or "none"
    -- the buff itself, on you
    local want = {}
    for _, id in ipairs(e.buffIds or {}) do want[id] = true end
    local best
    for _, x in ipairs(DT.Effects.Scan("player", now)) do
        if (want[x.abilityId] or want[x.baseId]) and x.finish > now and (not best or x.finish > best.finish) then best = x end
    end
    -- ...or, when that buff can't be seen, from the Ultimate you just spent (1 s per e.ultSpent spent)
    local spent = DT.Resources.ultSpent
    if not best and spent and now >= spent.at then
        local d = spent.amount / e.ultSpent * scale
        if now < spent.at + d then
            best = { begin = spent.at, finish = spent.at + d }
        end
    end
    if best then
        s.start, s.expire, s.duration = best.begin, best.finish, best.finish - best.begin
        s.phase, s.level, s.text = 1, "max", nil
    else
        s.text = ""
    end
    s.procKey, s.procKind = e.k, e.t
    s.order = e.idx
    return s
end
T.UltState = UltState

-- A proc that can only happen while a resource is low (Martial Knowledge: stamina below 50%): the
-- resource as a gauge with a line at the limit; "armed" (green) while you're under it.
GateState = function(s, e, pct, power, wasted)
    s.gate = true
    s.gauge, s.gaugePower, s.gaugeMark = pct / 100, power or e.gate.power, e.gate.below / 100
    s.badge = string.format("%d%%", math.floor(pct + 0.5))
    s.level = pct < e.gate.below and "max" or "none"
    if e.count then
        -- a counter (Pearls, Esoteric Greaves): procs this fight as the big number, e.g. "x3"
        s.text = (s.stacks or 0) > 0 and ("x" .. s.stacks) or ""
        s.counted = true
        s.wasted = wasted
    end
end

-- the gate's resource right now: % and which resource ("primary" = the bigger of magicka / stamina)
GatePower = function(e)
    local power = e.gate.power
    if power == "primary" then
        local _, mag = DT.Resources.Read("player", "magicka")
        local _, stam = DT.Resources.Read("player", "stamina")
        power = stam > mag and "stamina" or "magicka"
    end
    local _, _, pct = DT.Resources.Read("player", POWER_OF[power] or "stamina")
    local wasted
    if e.waste then
        local _, _, full = DT.Resources.Read("player", POWER_OF[e.waste] or "ultimate")
        wasted = full >= 99.5
    end
    return pct, power, wasted
end
local function ProcStates(tracker, c, now, out)
    local Procs = DT.Procs
    local tr = tracker.trigger
    for _, cand in ipairs(Procs.Candidates(tr)) do
        local e = cand.entry
        local key = "p:" .. e.k
        if e.on == "power" and e.ultSpent then
            out[#out + 1] = UltState(tr, e, key, now)
        elseif e.on == "power" then
            local _, _, pct = DT.Resources.Read("player", POWER_OF[e.power] or "ultimate")
            out[#out + 1] = PowerState(tr, e, key, pct, e.pscalar and Procs.IsPerfected(e))
        else
            local proxy = Procs.Proxy(tracker, e)
            local timers = DT.Combat.Timers(proxy.id, now)
            local t = timers and timers[0]
            local s
            if t and t.count then
                s = MissingState(key, Procs.DisplayName(e), Procs.Icon(e, tr.procIcon == "set"), "")
                s.ready, s.phase, s.stacks = true, 0, t.stacks
                if now < t.expire then s.active, s.phase, s.ready = true, 1, nil end
            elseif t then
                s = TimerState(key, t, now, Procs.DisplayName(e), Procs.Icon(e, tr.procIcon == "set"))
            end
            if not s and cand.available and tr.procReady and not e.noReady then   -- (a soul isn't "ready")
                s = ReadyState(key, Procs.DisplayName(e), Procs.Icon(e, tr.procIcon == "set"), DT.Combat.readyAt[proxy.id])
            end
            if s then
                if e.noTimer and s.phase == 1 then s.expire, s.duration = 0, 0 end
                if e.info then s.info, s.allies = Procs.BuffInfo(e.info, now) end
                if e.slayer then s.info, s.infoFull = Procs.SlayerDuration(e) end   -- the Slayer you'd give now
                if e.targets or e.burst then
                    -- players who have the buff from you right now, you included (effect events); while the
                    -- proc's buff runs, at least the players its events reached
                    local n = e.targets and Procs.TargetCount(e.targets, now) or 0
                    -- (Tony) the players it reached stay shown until YOUR cooldown is over -- they carry the
                    -- same 22 s cooldown (ExoY counts those 135924 events for 22 s), not only while Slayer runs
                    if e.burst and (s.phase == 1 or s.phase == 2) and t and t.reached and t.reached > n then n = t.reached end
                    s.allies = n > 0 and n or nil
                    -- colour: green when it reached everyone it could (you + 5, or your whole smaller group),
                    -- gold when fewer (RoaringOpportunist turns yellow under half the group)
                    local g = math.max(1, GetGroupSize() or 0)
                    local possible = math.min(g, e.reachMax or 6)
                    s.alliesLow = s.allies and s.allies < possible or nil
                    s.alliesFull = s.allies and s.allies >= possible or nil
                end
                -- Spaulder of Ruin: while it's on, the allies who get the aura from you (Cooldowns' number on the icon)
                if e.allies and s.phase == 1 then
                    local n = Procs.AllyCount(e.allies, now)
                    s.allies = n > 0 and n or nil
                end
                if e.gate then GateState(s, e, GatePower(e)) end
                -- (Cooldowns counts them all the time, not only while Z'en is up: TrackZenDOTs every 500 ms)
                if e.dots then
                    -- Touch of Z'en: its strength is your DoTs on the enemy (the game reports 0 stacks). "Count on
                    -- the boss" (ExoY's focusOnBoss): with exactly one boss, on that boss, else on your target
                    local tag = "reticleover"
                    if tr.procZenBoss and DoesUnitExist("boss1") and not DoesUnitExist("boss2") then tag = "boss1" end
                    s.stacks = DoesUnitExist(tag) and E.MyDots(nil, tag, now) or 0   -- all of them, like Cooldowns
                    s.allStacks = true
                    -- ExoY's colours: under 30 % of the most low, over 70 % high
                    local pct = s.stacks / e.dots * 100
                    s.stackLevel = (pct > 70 and "max") or (pct < 30 and "bad") or "part"
                end
                -- stacking mythics / sets (ExoY's maxstack): the count turns green at the most it can have
                if e.maxStacks and s.active and (s.stacks or 0) > 0 then
                    s.stackLevel = (s.stacks >= e.maxStacks) and "max" or "info"
                end
                s.procKey, s.procKind = e.k, e.t
                s.order = e.idx         -- catalogue order: stable place with the "fixed" sort
                out[#out + 1] = s
            end
        end
    end
end

local COMPARE = {
    ["<"] = function(a, b) return a < b end, ["<="] = function(a, b) return a <= b end,
    ["=="] = function(a, b) return a == b end, ["~="] = function(a, b) return a ~= b end,
    [">="] = function(a, b) return a >= b end, [">"] = function(a, b) return a > b end,
}
T.COMPARE = COMPARE

local function ResourceStates(tracker, c, now, out)
    local tr = tracker.trigger
    local label = C.Label(C.POWER_TYPES, tr.powerType)
    for _, tag in ipairs(DT.Resources.Tags(tr.unit)) do
        local cur, max, pct = DT.Resources.Read(tag, tr.powerType)
        local pass = true
        if tr.thresholdOp ~= "none" and COMPARE[tr.thresholdOp] then
            pass = COMPARE[tr.thresholdOp](pct, tr.threshold)
        end
        if pass and max > 0 then
            local s = {
                key = "res:" .. tag, name = label, unitName = Units.NameForTag(tag), icon = c.icon,
                start = 0, expire = 0, duration = 0, stacks = 0, active = true,
                value = cur, max = max, pct = pct, isTarget = tag == "reticleover",
                isBoss = tag:sub(1, 4) == "boss", mine = tag == "player", order = 0,
            }
            if tr.calc ~= "none" then
                local v = DT.Procs.Calc(tr.calc, pct, { scalar = tr.calcScalar, start = tr.calcStart, cap = tr.calcCap, div = tr.calcDiv })
                s.calc = v
                s.calcText = tr.calc == "divide" and DT.Procs.CalcText("divide", v, tr.calcDecimals)
                    or string.format("%." .. tr.calcDecimals .. "f", v)
                s.text = s.calcText
            end
            out[#out + 1] = s
        end
    end
end

-- stacks = number of my DoTs on that unit (Touch of Z'en), and/or a cap on the stacks shown
local function AdjustStacks(tr, out, first, now)
    if tr.stacksFrom ~= "mydots" and (tr.stacksMax or 0) <= 0 then return end
    for i = first, #out do
        local s = out[i]
        if s.active then
            if tr.stacksFrom == "mydots" then
                if s.unitTag then s.stacks = E.MyDots(nil, s.unitTag, now)
                elseif s.unitId then s.stacks = E.MyDots(s.unitId, nil, now) end
                s.allStacks = true
            end
            if (tr.stacksMax or 0) > 0 and (s.stacks or 0) > tr.stacksMax then s.stacks = tr.stacksMax end
        end
    end
end

------------------------------------------------------------------------------
-- Cycle + "then a cooldown": after the effect ends, the entry counts down a cooldown before it is
-- ready again (BuffTheGroup's Pillager's Profit: the cooldown isn't an effect anyone can see, so it is
-- worked out -- counted from when the effect started; when that isn't known, the BuffTheGroup way:
-- from when it ended, minus the effect's own duration). Shown as the step after the listed abilities.
------------------------------------------------------------------------------

local cycleMemory = {}      -- [tracker or proxy id] = { [entry key] = { start, abilityId, readyAt } }

local function CooldownAfter(tr)
    if (tr.cooldownAfter or 0) > 0 then return tr.cooldownAfter end
    if (tr.cooldownAfterId or 0) > 0 and type(GetAbilityDuration) == "function" then
        return (GetAbilityDuration(tr.cooldownAfterId) or 0) / 1000
    end
    return 0
end

local function CycleCooldowns(tracker, c, out, first, now)
    local tr = tracker.trigger
    local cd = CooldownAfter(tr)
    if cd <= 0 then cycleMemory[tracker.id] = nil; return end
    local mem = cycleMemory[tracker.id]
    if not mem then mem = {}; cycleMemory[tracker.id] = mem end
    local seen = {}
    for i = first, #out do
        local s = out[i]
        seen[s.key] = true
        local m = mem[s.key]
        if (s.phase or 0) >= 1 then
            mem[s.key] = { start = s.start or 0, abilityId = s.abilityId }
        elseif m then
            if not m.readyAt then
                if m.start > 0 then m.readyAt = m.start + cd
                else
                    local own = type(GetAbilityDuration) == "function" and (GetAbilityDuration(m.abilityId or 0) or 0) / 1000 or 0
                    m.readyAt = now + cd - own
                end
                m.from = now     -- the bar drains over the cooldown part (like ability timers' step 2)
            end
            if now < m.readyAt then
                local g = c.groups[1]
                s.name = DT.L("<<1>> cooldown", g and g.label or c.missingName)
                s.phase, s.ready, s.cooldown, s.active = #c.groups + 1, false, true, true
                s.start, s.expire = m.from, m.readyAt
                s.duration = m.readyAt - m.from
            else
                mem[s.key] = nil
            end
        end
    end
    for key in pairs(mem) do if not seen[key] then mem[key] = nil end end
end

------------------------------------------------------------------------------
-- "One entry: how many have it": the tracker's entries become a single one -- how many of the units
-- listed have the effect running (value / max / pct), timed by the one that runs out first
-- (BuffTheGroup's "minimal mode": the % of the group with the buff, coloured by the shortest timer).
------------------------------------------------------------------------------

local function Summarize(tracker, c, out, first, now)
    local units, have, total = {}, {}, 0
    local soonest
    for i = first, #out do
        local s = out[i]
        local u = s.unitTag or s.unitId or s.unitName or s.key
        if not units[u] then units[u] = true; total = total + 1 end
        local running = s.active and not s.cooldown and not s.ready and not s.expired
        if running and not have[u] then have[u] = true end
        if running then
            local timed = (s.expire or 0) > 0 and (s.duration or 0) > 0
            if timed and (not soonest or s.expire < soonest.expire) then soonest = s end
            if not timed and not soonest then soonest = s end
        end
    end
    local n = 0
    for _ in pairs(have) do n = n + 1 end
    for i = #out, first, -1 do out[i] = nil end
    local g = c.groups[1]
    local s = {
        key = "summary", name = (g and g.label) or c.missingName or tracker.name, unitName = "",
        icon = (g and g.icon) or c.icon, stacks = 0, order = 0, slot = 1, mine = false,
        active = n > 0, value = n, max = total, pct = total > 0 and n / total * 100 or 0,
        start = 0, expire = 0, duration = 0,
    }
    if soonest and (soonest.expire or 0) > 0 then
        s.start, s.expire, s.duration = soonest.start, soonest.expire, soonest.duration
    end
    out[first] = s
end
T.Summarize = Summarize

-- Toggles (tutsuraki): one entry per listed ability, on (active, untimed: "on for X s" with {elapsed}) or
-- off (not active: greyed / coloured by rules). Show: on and off / only on / only off.
local toggleSince = {}      -- [tracker id .. ":" .. index] = when it was switched on
local function ToggleStates(tracker, c, now, out)
    local tr = tracker.trigger
    for gi, g in ipairs(c.groups) do
        local on, slotted, icon, name = DT.Toggles.State(g)
        local key = tracker.id .. ":" .. gi
        if on then toggleSince[key] = toggleSince[key] or now else toggleSince[key] = nil end
        if (on and tr.mode ~= "missing") or (not on and tr.mode ~= "present") then
            local s = MissingState("toggle:" .. gi, g.label, (not g.fixedIcon and icon) or g.icon, "", false, false)
            s.active = on
            s.slot = gi
            s.toggle, s.slotted = true, slotted
            if on then s.start = toggleSince[key] end
            out[#out + 1] = s
        end
    end
end

-- Stat trackers (Core/Stats.lua): one entry, the value against its cap (pen vs. the enemy's resistance, crit damage vs.
-- 125 %, resistances vs. 33,100); a bar fills to the cap. {value} {max} {pct} {detail} in texts.
local function StatStates(tracker, c, now, out)
    local tr = tracker.trigger
    local value, max, unit, which = DT.Stats.Value(tr.stat, now, "reticleover")
    if tr.statOp ~= "none" and COMPARE[tr.statOp] and not COMPARE[tr.statOp](value, tr.statValue) then return end
    -- one entry per trigger: a tracker can show several stats side by side (e.g. spell + physical resist)
    local s = MissingState("stat", C.Label(C.STATS, tr.stat), c.icon, "", false, false)
    s.active = true
    s.value, s.max = value, max > 0 and max or nil
    s.pct = max > 0 and math.min(100, value / max * 100) or 100
    -- how the number is written (the Meter display rolls it with the same format)
    local fmt = "%d"
    if tr.stat == "ultPerSecond" or tr.stat == "critChance" then fmt = "%.1f" end
    if tr.stat == "critChance" or tr.stat == "critTarget" or tr.stat == "critDamage" then fmt = fmt .. "%%" end
    if tr.stat == "critResistPct" then fmt = "-%.1f%%" end
    if (tr.statDecimals or -1) >= 0 then
        fmt = (tr.stat == "critResistPct" and "-" or "") .. "%." .. tr.statDecimals .. "f" .. (fmt:find("%%%%") and "%%" or "")
    end
    s.fmt = fmt
    s.text = string.format(fmt, fmt:find("d") and math.floor(value + 0.5) or value)
    -- the caption (Meter display): the trigger's own label, else the stat's; "lowest" names which one it is
    local caption = (tr.label and tr.label ~= "") and tr.label or C.STAT_CAPTIONS[tr.stat] or s.name
    if tr.stat == "lowestResist" and not (tr.label and tr.label ~= "") then
        caption = which == "spell" and C.STAT_CAPTIONS.spellResist or C.STAT_CAPTIONS.physResist
    end
    s.caption, s.accent, s.stat = caption, C.STAT_ACCENTS[tr.stat], tr.stat
    -- "vs. my target" with no enemy to compare with: your sheet value only, not judged against the cap
    if tr.stat == "penTarget" or tr.stat == "critTarget" then
        s.vsTarget = DoesUnitExist("reticleover") or (unit ~= nil and #unit.list > 0)
    end
    if unit then
        s.detail = table.concat(unit.list, ", ")
        if DoesUnitExist("reticleover") then s.unitName = Units.NameForTag("reticleover") end
        s.unitTag = "reticleover"
    end
    out[#out + 1] = s
end

-- "Combat state": one entry, "Combat" while you're in combat and "No Combat" out of it (HangryGinger: the indicator
-- under the crosshair). The game's combat state as it is now (no grace), {elapsed} = time in this fight.
local fightStart, wasInCombat = 0, false
local function CombatStateStates(tracker, c, now, out)
    local tr = tracker.trigger
    local inCombat = type(IsUnitInCombat) == "function" and IsUnitInCombat("player") == true
    if inCombat and not wasInCombat then fightStart = now end
    wasInCombat = inCombat
    local s = MissingState("combatState", inCombat and tr.combatOnText or tr.combatOffText, c.icon, "", false, false)
    s.active = true                 -- (both states are "on": the text isn't greyed out of combat)
    s.inCombat = inCombat
    s.start = inCombat and fightStart or nil
    s.text = s.name
    out[#out + 1] = s
end

-- "Resource tick": one entry that fills up toward your next health / magicka / stamina regen tick (Core/Ticks.lua,
-- after Miat's Ticks Tracker). Nothing until the first tick is seen; hidden while the resource is full unless the
-- tracker says otherwise. {gain} = "+amount" just after a tick, {fill} = how far to the next one, {value} = the
-- resource now. Rules: "Progress to the next tick", "Seconds since the last tick", "Regen per tick", "Dodge fatigue".
local function TickStates(tracker, c, now, out)
    local tr = tracker.trigger
    local res = tr.powerType
    local info = DT.Ticks.Info(res, now)
    if not info then return end
    local cur, max, pct = DT.Resources.Read("player", res)
    if not tr.tickShowFull and max > 0 and cur >= max then return end
    local g1 = c.groups[1]
    local s = MissingState("tick:" .. res, (g1 and g1.label) or C.Label(C.TICK_POWER_TYPES, res), (g1 and g1.icon) or c.icon, "", false, false)
    s.active, s.mine = true, true
    local period = DT.Ticks.Period(res)          -- measured from the game's ticks (2 s until known)
    s.start, s.duration, s.expire = info.trusted, period, info.trusted + period
    s.fillUp = true
    s.trusted = info.wasTrusted
    s.value, s.max, s.pct = cur, max, pct
    s.gain, s.gainAt = info.amount, info.at
    s.regen = DT.Ticks.Regen(res)
    s.tickRes = res
    s.unitTag = "player"
    out[#out + 1] = s
end

-- "Global cooldown": one bar per GCD / cast / channel / heavy attack (Core/GlobalCooldown.lua, after Combat
-- Metronome, GCD Bar and Global Cooldown Monitor). Each one is its own entry (a one-shot rule -- a sound -- fires
-- once per GCD); s.zone = your ping as the end of the bar, the window to queue the next input.
local function GcdStates(tracker, c, now, out)
    local tr = tracker.trigger
    local GC = DT.GlobalCooldown
    local e = GC.Current(now)
    -- cooldowns without a skill (and what's left after an early end) only with "Track all GCDs"
    if e and (e.kind == "other" or e.kind == "dodge") and not tr.gcdOther then e = nil end
    if not e then
        if tr.gcdIdle then
            local s = MissingState("gcd:idle", "", "", "", false, false)
            s.idle, s.gcdKind, s.text = true, "idle", ""
            out[#out + 1] = s
        end
        return
    end
    local s = MissingState("gcd:" .. e.serial, e.name, e.icon, "", false, false)
    s.active, s.mine = true, true
    s.start, s.expire, s.duration = e.start, e.finish, math.max(0.001, e.finish - e.start)
    s.abilityId, s.gcdKind = e.id, e.kind
    s.unitTag = "player"
    -- Metronome's "changed colour on channels": the cast / channel part (all of it when over 1 s; a heavy throughout)
    s.gcdCasting = e.kind == "heavy" or ((e.kind == "cast" or e.kind == "channel") and (e.delay > 1000 or now < e.start + e.delay / 1000))
    -- name, icon and time: on every bar, or only on casts / channels (and heavies if wanted) -- Metronome's default
    local labelled = true
    if e.kind == "heavy" then labelled = tr.gcdHeavyNames
    elseif tr.gcdNames == "timed" then labelled = e.kind == "cast" or e.kind == "channel" or e.kind == "other" or e.kind == "dodge" end
    if not labelled then s.name, s.icon, s.text = "", "", "" end
    local ping = tr.gcdPing
    if e.kind == "heavy" then ping = ping and tr.gcdHeavyPing
    elseif e.kind == "other" or e.kind == "dodge" then ping = ping and tr.gcdOtherPing end
    if ping then
        s.zone = U.Clamp(math.min(GC.Ping(), tr.gcdMaxPing) / 1000 / s.duration, 0, 1)
    end
    out[#out + 1] = s
end

local function BuildOne(tracker, now, out)
    local c = Compile(tracker)
    local tt = tracker.trigger.type
    if tt == "effect" then
        local first = #out + 1
        if C.TAGGED_SCOPES[tracker.trigger.scope] then
            EffectStatesTagged(tracker, c, now, out)
        else
            EffectStatesEnemies(tracker, c, now, out)
        end
        AdjustStacks(tracker.trigger, out, first, now)
        -- slot = which listed ability an entry is (1st, 2nd...): the "Fixed" sort keeps that order
        for i = first, #out do
            local st = out[i]
            if not st.slot then
                for gi, g in ipairs(c.groups) do
                    if MatchesGroup(g, st) then st.slot = gi; break end
                end
                st.slot = st.slot or 0
            end
            -- the player's own icon for that ability, active or missing
            local g = c.groups[st.slot]
            if g and g.fixedIcon then st.icon = g.icon end
        end
        if tracker.trigger.mode == "cycle" then CycleCooldowns(tracker, c, out, first, now) end
        if tracker.trigger.summary then Summarize(tracker, c, out, first, now) end
    elseif tt == "combat" then
        CombatStates(tracker, c, now, out)
    elseif tt == "procs" then
        ProcStates(tracker, c, now, out)
    elseif tt == "resource" then
        ResourceStates(tracker, c, now, out)
    elseif tt == "toggle" then
        ToggleStates(tracker, c, now, out)
    elseif tt == "stat" then
        StatStates(tracker, c, now, out)
    elseif tt == "combatState" then
        CombatStateStates(tracker, c, now, out)
    elseif tt == "tick" then
        TickStates(tracker, c, now, out)
    elseif tt == "gcd" then
        GcdStates(tracker, c, now, out)
    end
    return out
end

-- "Use the tracker's icon for every entry" (custom texture trackers)
local function ForceIcon(tracker, out)
    if not tracker.display.forceIcon or tracker.iconOverride == "" then return end
    local icon = T.TrackerIcon(tracker)
    for _, s in ipairs(out) do s.icon = icon end
end

------------------------------------------------------------------------------
-- "Keep it shown after it ends": when an entry's effect runs out, the entry stays for `linger`
-- seconds as an EXPIRED entry (s.expired, s.endedAt), on the same row, so e.g. a tank sees that HIS
-- taunt just fell off that enemy -- which is different from "never applied / missing". By default
-- only effects that ran out count (not ones removed early: cleansed or overwritten); `lingerEarly`
-- includes those too. Re-applying the effect replaces the entry at once.
--
-- The Untaunted way (Solinur/Untaunted 1.1.6, Cleanup/onTaunt/OnUnitDeath):
--   * lingerToDue: an entry that ended early (someone else taunted your enemy) is kept until the time
--     it WOULD have ended + linger -- Untaunted keeps the row until 5 s past the taunt's own end time;
--   * lingerUnit: an enemy's ended entries stay while that enemy still has another of the tracker's
--     entries running (Taunt ended, Taunt Immunity still on), and go together `linger` s after the
--     last one ended -- Untaunted removes a unit's rows only when none ended less than 5 s ago;
--   * an enemy that dies takes its ended entries along at once (Untaunted's OnUnitDeath), always.
------------------------------------------------------------------------------

local lingerMemory = {}     -- [tracker or proxy id] = { last = {key = state}, lingering = {key = state}, current = ... }

local function LingerSeconds(tr)
    local linger = tr.linger or 0
    -- only "Show while active" effect trackers and ability timers: missing/always/cycle modes already
    -- show the unit when the effect isn't there
    if tr.type == "effect" and tr.mode ~= "present" then return 0 end
    if tr.type == "resource" or tr.type == "toggle" or tr.type == "stat" then return 0 end
    -- an ability timer that shows "Ready" already says it ended (the expired copy would sit next to it)
    if tr.type == "combat" and tr.showReady then return 0 end
    return linger
end

-- Step 1 (per trigger): entries that were active last update and are gone now become lingering.
local function CollectLinger(t, now, out, first, last, died)
    local tr = t.trigger
    local linger = LingerSeconds(tr)
    local mem = lingerMemory[t.id]
    if linger <= 0 then
        if mem then lingerMemory[t.id] = nil end
        return nil
    end
    if not mem then mem = { last = {}, lingering = {} }; lingerMemory[t.id] = mem end
    local current = {}
    for j = first, last do
        local s = out[j]
        if s.active then current[s.key] = s end
    end
    for key, prev in pairs(mem.last) do
        if not current[key] and not mem.lingering[key] and not (prev.unitId and died[prev.unitId]) then
            local ranOut = (prev.expire or 0) > 0 and now >= prev.expire - 0.3
            if ranOut or tr.lingerEarly then
                local endedAt = ranOut and prev.expire or now
                local due = endedAt
                if not ranOut and tr.lingerToDue and (prev.expire or 0) > now then due = prev.expire end
                local s = {}
                for k, v in pairs(prev) do s[k] = v end
                s.active, s.expired, s.endedAt, s.look = false, true, endedAt, nil
                s.keepUntil = due + linger
                s.start, s.duration, s.expire = endedAt, s.keepUntil - endedAt, s.keepUntil
                s.stacks = 0
                mem.lingering[key] = s
            end
        end
    end
    mem.last, mem.current, mem.byUnit = current, current, tr.lingerUnit == true
    return mem
end

-- Step 2: show the lingering entries until their time is up, the effect is back or the enemy died.
-- units[unitId] = how long that enemy's entries stay (lingerUnit): forever while one is running.
local function ShowLinger(mem, now, out, units, died)
    for key, s in pairs(mem.lingering) do
        local untilT = s.keepUntil
        if mem.byUnit and s.unitId and units[s.unitId] and units[s.unitId] > untilT then untilT = units[s.unitId] end
        if mem.current[key] or now >= untilT or (s.unitId and died[s.unitId]) then
            mem.lingering[key] = nil
        else
            out[#out + 1] = s
        end
    end
end

local NO_DEATHS = {}
-- does this tracker (or one of its extra triggers) keep ended entries? (else: no bookkeeping at all)
local function AnyLinger(tracker)
    if LingerSeconds(tracker.trigger) > 0 or lingerMemory[tracker.id] then return true end
    local extras = tracker.extraTriggers
    if extras then
        for i = 1, #extras do
            if LingerSeconds(extras[i]) > 0 or lingerMemory[tracker.id .. "#x" .. i] then return true end
        end
    end
    return false
end

local function WithExtras(tracker, now, builder, linger)
    local out = builder(tracker, now, {})
    linger = linger and AnyLinger(tracker)
    local ranges = linger and { { tracker, 1, #out } } or nil
    local extras = tracker.extraTriggers
    if extras and #extras > 0 then
        for i = 1, #extras do
            local first = #out + 1
            local proxy = TriggerProxy(tracker, i)
            builder(proxy, now, out)
            for j = first, #out do
                local key = tostring(out[j].key)
                if key:sub(1, 1 + #tostring(i) + 1) ~= "x" .. i .. ":" then out[j].key = "x" .. i .. ":" .. key end
            end
            if ranges then ranges[#ranges + 1] = { proxy, first, #out } end
        end
    end
    if ranges then
        local died = E.died or NO_DEATHS
        local mems = {}
        for _, r in ipairs(ranges) do
            local mem = CollectLinger(r[1], now, out, r[2], r[3], died)
            if mem then mems[#mems + 1] = mem end
        end
        if #mems > 0 then
            -- per enemy, over every trigger of the tracker: running -> kept; else the latest keep time
            local units = {}
            for j = 1, #out do
                local s = out[j]
                if s.active and s.unitId then units[s.unitId] = math.huge end
            end
            for _, mem in ipairs(mems) do
                for _, s in pairs(mem.lingering) do
                    if s.unitId and (units[s.unitId] or 0) < s.keepUntil then units[s.unitId] = s.keepUntil end
                end
            end
            for _, mem in ipairs(mems) do ShowLinger(mem, now, out, units, died) end
        end
    end
    -- "Nothing to show: keep one entry" (Tony: the Off Balance icon vanished whenever no enemy was being
    -- fought -- "ready" exists per enemy hit in the last 10 s, and leaving combat clears that list)
    local tr = tracker.trigger
    if #out == 0 and tr.idleEntry and tr.type == "effect" then
        local c = Compile(tracker)
        local g = c.groups[1]
        local s
        -- "ready" only where it's true: on All enemies nothing fought has it. On your target / a boss / a
        -- group member with no such unit (looking away, dead) there's nothing to be ready on: a plain icon.
        if tr.mode == "cycle" and not C.TAGGED_SCOPES[tr.scope] then
            s = MissingState("idle", DT.L("<<1>> ready", g and g.label or c.missingName), g and g.icon or c.icon, "", false, false)
            s.phase, s.ready = 0, true
        else
            s = MissingState("idle", g and g.label or c.missingName, g and g.icon or c.icon, "", false, false)
        end
        s.idle, s.slot = true, 1
        out[1] = s
    end
    ForceIcon(tracker, out)
    return out
end

function T.Build(tracker, now)
    return WithExtras(tracker, now, BuildOne, true)
end

function T.ResetLinger(id)
    if id then lingerMemory[id] = nil else lingerMemory = {} end
end

------------------------------------------------------------------------------
-- Test mode: believable fake states so a tracker can be designed without being in combat
------------------------------------------------------------------------------

local TEST_UNITS = { "Iron Atronach", "Ogrim Brute", "Dremora Kynval", "Daedroth", "Lurcher", "Skeever" }

local function Cycle(now, period, offset)
    local phase = (now + offset) % period
    return now - phase, now - phase + period
end

-- Sample entries for "above heads": over every group member when grouped, else over yourself, so
-- the look can be designed anywhere. Alternates present / missing so both looks are visible.
local function HeadTestStates(tracker, c, now)
    local out = {}
    local tags = Units.GroupTags(true)
    local groups = #c.groups > 0 and c.groups or { { label = c.missingName, icon = c.icon } }
    local tr = tracker.trigger
    for ti, tag in ipairs(tags) do
        for gi, g in ipairs(groups) do
            local missing = tr.mode == "missing" or (tr.mode == "always" and (ti + gi) % 3 == 0)
            local s
            if missing then
                s = MissingState("test:" .. tag .. ":" .. gi, g.label, g.icon, Units.NameForTag(tag), false, false)
            else
                local period = 10 + gi * 4 + ti
                local phase = (now + ti * 3 + gi) % period
                s = {
                    key = "test:" .. tag .. ":" .. gi, name = g.label, unitName = Units.NameForTag(tag), icon = g.icon,
                    start = now - phase, expire = now - phase + period, duration = period, stacks = gi == 2 and 2 or 0,
                    active = true, isTarget = false, isBoss = false, mine = true, order = gi,
                }
            end
            s.unitTag = tag
            s.preview = true
            out[#out + 1] = s
        end
    end
    return out
end

local TestStatesOne
-- A buff / ability-timer trigger with no abilities yet has nothing to show: it adds no sample
-- entries (an extra trigger just added used to bring four fake enemies with it). With nothing
-- listed anywhere, one placeholder entry keeps the window visible while it's being set up.
local function EmptyTrigger(tr)
    return (tr.type == "effect" or tr.type == "combat") and #tr.abilityIds == 0 and #tr.names == 0
end

function T.TestStates(tracker, now)
    if tracker.display.type == "heads" then
        return WithExtras(tracker, now, function(t, n, out)
            for _, s in ipairs(TestStatesOne(t, n)) do out[#out + 1] = s end
            return out
        end)
    end
    local anyFilled = not EmptyTrigger(tracker.trigger)
    for _, x in ipairs(tracker.extraTriggers or {}) do anyFilled = anyFilled or not EmptyTrigger(x) end
    local placeholder = false
    return WithExtras(tracker, now, function(t, n, out)
        if EmptyTrigger(t.trigger) then
            if anyFilled or placeholder then return out end
            placeholder = true
            local one = TestStatesOne(t, n)[1]
            if one then out[#out + 1] = one end
            return out
        end
        local first = #out + 1
        for _, s in ipairs(TestStatesOne(t, n)) do out[#out + 1] = s end
        -- "One entry: how many have it": the sample is one entry too
        if t.trigger.type == "effect" and t.trigger.summary and #out >= first then Summarize(t, Compile(t), out, first, n) end
        return out
    end)
end

TestStatesOne = function(tracker, now)
    local c = Compile(tracker)
    local tr = tracker.trigger
    if tracker.display.type == "heads" then return HeadTestStates(tracker, c, now) end
    local out = {}
    local function Timed(key, name, icon, unit, period, offset, extra)
        local start, expire = Cycle(now, period, offset)
        local s = {
            key = key, name = name, unitName = unit, icon = icon, start = start, expire = expire,
            duration = period, stacks = 0, active = true, isTarget = false, isBoss = false, mine = true,
            order = offset, abilityId = tr.abilityIds[1],
        }
        if extra then for k, v in pairs(extra) do s[k] = v end end
        return s
    end
    local g1 = c.groups[1]
    local name = g1 and g1.label or c.missingName
    local icon = g1 and g1.icon or c.icon

    if tr.type == "stat" then
        local cap = (tr.stat == "penTarget" or tr.stat == "pen") and 18200 or (tr.stat:find("crit") and 125) or 0
        local v = cap > 0 and cap * (0.8 + 0.2 * math.abs(math.sin(now / 3))) or 3200
        -- (the Meter display's caption, accent and number format, as on real entries)
        local fmt = tr.stat:find("crit") and tr.stat ~= "critResist" and "%d%%" or "%d"
        return { { key = "stat", name = C.Label(C.STATS, tr.stat), unitName = TEST_UNITS[1], icon = c.icon, start = 0, expire = 0,
            duration = 0, stacks = 0, active = true, value = v, max = cap > 0 and cap or nil, pct = cap > 0 and v / cap * 100 or 100,
            text = string.format(fmt, math.floor(v)), fmt = fmt, stat = tr.stat, accent = C.STAT_ACCENTS[tr.stat], vsTarget = true,
            caption = (tr.label ~= "" and tr.label) or C.STAT_CAPTIONS[tr.stat],
            detail = "Major Breach 5948, Crusher 2108", order = 1 } }
    end
    if tr.type == "gcd" then
        -- a skill every 1.2 s, every third a 2.5 s channel
        local cyc = math.floor(now / 1.2)
        local start = cyc * 1.2
        local channel = cyc % 3 == 2
        return { { key = "gcd:test" .. cyc, name = channel and "Radiant Glory" or "Surprise Attack", unitName = "", icon = c.icon,
            start = start, expire = start + 1.0, duration = 1.0, stacks = 0, active = true, mine = true,
            gcdKind = channel and "channel" or "skill", zone = tr.gcdPing and 0.08 or nil, order = 1 } }
    end
    if tr.type == "tick" then
        -- a tick every 2 s, the gain shown after each
        local start = now - (now % 2)
        return { { key = "tick:" .. tr.powerType, name = C.Label(C.TICK_POWER_TYPES, tr.powerType), unitName = "", icon = c.icon,
            start = start, expire = start + 2, duration = 2, stacks = 0, active = true, fillUp = true, mine = true,
            value = 18000, max = 30000, pct = 60, gain = 1450, gainAt = start, regen = 1450, tickRes = tr.powerType, order = 1 } }
    end
    if tr.type == "combatState" then
        local on = math.floor(now / 4) % 2 == 0
        return { { key = "combatState", name = on and tr.combatOnText or tr.combatOffText, unitName = "", icon = c.icon,
            start = on and now - (now % 4) or nil, expire = 0, duration = 0, stacks = 0, active = true, inCombat = on, order = 1 } }
    end
    if tr.type == "toggle" then
        -- each listed toggle flips on / off every few seconds
        for gi, g in ipairs(#c.groups > 0 and c.groups or { { label = name, icon = icon } }) do
            local on = math.floor((now + gi * 2) / 4) % 2 == 0
            if (on and tr.mode ~= "missing") or (not on and tr.mode ~= "present") then
                out[#out + 1] = { key = "test" .. gi, name = g.label, unitName = "", icon = g.icon, start = now, expire = 0,
                    duration = 0, stacks = 0, active = on, toggle = true, slotted = true, isTarget = false, isBoss = false,
                    mine = true, order = gi, slot = gi }
            end
        end
        return out
    end
    if tr.type == "resource" then
        local n = (tr.unit == "group") and 4 or (tr.unit == "boss" and 2 or 1)
        for i = 1, n do
            local pct = 50 + 45 * math.sin(now / 2 + i)
            out[#out + 1] = { key = "test" .. i, name = C.Label(C.POWER_TYPES, tr.powerType), unitName = TEST_UNITS[i],
                icon = c.icon, start = 0, expire = 0, duration = 0, stacks = 0, active = true,
                value = pct * 300, max = 30000, pct = pct, isTarget = i == 1, isBoss = tr.unit == "boss", order = i }
            if tr.calc ~= "none" then
                local v = DT.Procs.Calc(tr.calc, pct, { scalar = tr.calcScalar, start = tr.calcStart, cap = tr.calcCap, div = tr.calcDiv })
                out[i].calc = v
                out[i].calcText = tr.calc == "divide" and DT.Procs.CalcText("divide", v, tr.calcDecimals)
                    or string.format("%." .. tr.calcDecimals .. "f", v)
                out[i].text = out[i].calcText
            end
        end
        return out
    end
    if tr.type == "combat" then
        if (tr.cooldown or 0) > 0 then
            -- walk through active -> cooldown -> ready
            local cd = math.max(tr.cooldown, tr.duration)
            local period = cd + 3
            local t = now % period
            local start = now - t
            local fake = { start = start, expire = start + tr.duration, duration = tr.duration, cdEnd = start + cd,
                name = name, icon = icon, unitName = "", order = 0, stacks = 0, abilityId = tr.abilityIds[1] }
            out[1] = TimerState("test1", fake, now) or ReadyState("test1", name, icon)
        else
            out[1] = Timed("test1", name, icon, "", tr.duration + 2, 0)
            out[1].duration = tr.duration + 2
        end
        return out
    end
    if tr.type == "procs" then
        -- a proc's own tracker: just that proc; otherwise what you have now, or three examples
        -- (active, on cooldown, ready)
        local picks = {}
        if #tr.procOnly > 0 then
            for _, k in ipairs(tr.procOnly) do picks[#picks + 1] = k end
        else
            for _, cand in ipairs(DT.Procs.Candidates(tr)) do picks[#picks + 1] = cand.entry.k end
            if #picks == 0 then picks = { "Burning Spellweave", "Bahsei's Mania", "Roaring Opportunist", "Way of Martial Knowledge", "Pearls of Ehlnofey" } end
        end
        for i, k in ipairs(picks) do
            local e = DT.Procs.Get(k)
            if e and e.on == "power" and e.ultSpent then
                out[#out + 1] = UltState(tr, e, "test" .. i, now)
                out[#out].order = i
            elseif e and e.on == "power" then
                -- the resource drains and refills, so the gauge, the line and the colours can be seen
                local pct = 50 + 48 * math.sin(now / 3 + i)
                out[#out + 1] = PowerState(tr, e, "test" .. i, pct, false)
                out[#out].order = i
            elseif e then
                local d = e.d or 5
                local cd = math.max(e.cd or (d + 6), d)
                local period = cd + 4
                local t = (now + i * 5) % period
                local start = now - t
                local fake = { start = start, expire = start + d, duration = d, cdEnd = start + cd, order = i, stacks = 0 }
                out[#out + 1] = TimerState("test" .. i, fake, now, DT.Procs.DisplayName(e), DT.Procs.Icon(e, tr.procIcon == "set"))
                    or ReadyState("test" .. i, DT.Procs.DisplayName(e), DT.Procs.Icon(e, tr.procIcon == "set"))
                out[#out].procKey, out[#out].procKind = e.k, e.t
                if e.gate then
                    if e.count then out[#out].stacks = 3 end
                    GateState(out[#out], e, 50 + 45 * math.sin(now / 3 + i), e.gate.power == "primary" and "magicka" or nil)
                end
                if e.info then
                    local left = 12 - (now + i * 5) % 16
                    out[#out].info = left > 0 and left or nil
                    out[#out].allies = left > 0 and 4 or 0
                end
                if e.slayer then out[#out].info = 8.1 end
                if e.burst then out[#out].allies = 4 end
            end
        end
        return out
    end

    if tr.mode == "cycle" then
        -- each sample unit walks through every listed ability (8 s each) and then "ready" (5 s)
        local groups = #c.groups > 0 and c.groups or { { label = c.missingName, icon = c.icon } }
        local n = C.TAGGED_SCOPES[tr.scope] and (tr.scope == "boss" and 2 or 1) or 4
        local period = #groups * 8 + 5
        for i = 1, n do
            local t = (now + i * 6) % period
            local gi = math.floor(t / 8) + 1
            local key = "test:cycle:" .. i
            if gi <= #groups then
                local start = now - (t - (gi - 1) * 8)
                out[#out + 1] = { key = key, name = groups[gi].label, unitName = TEST_UNITS[i], icon = groups[gi].icon,
                    start = start, expire = start + 8, duration = 8, stacks = 0, active = true, isTarget = i == 1,
                    isBoss = false, mine = false, order = i, phase = gi }
            else
                local s = MissingState(key, DT.L("<<1>> ready", groups[1].label), groups[1].icon, TEST_UNITS[i], i == 1, false)
                s.phase, s.ready, s.order = 0, true, i
                out[#out + 1] = s
            end
        end
        return out
    end

    if tr.perAbility or tr.mode ~= "present" then
        local groups = #c.groups > 0 and c.groups or { { label = c.missingName, icon = c.icon } }
        for gi, g in ipairs(groups) do
            local present = (tr.mode == "present") or (tr.mode == "always" and gi % 3 ~= 0)
            if present then
                out[#out + 1] = Timed("test" .. gi, g.label, g.icon, "Iron Atronach", 12 + gi * 3, gi * 4,
                    { stacks = gi == 2 and 3 or 0, isBoss = true })
            else
                out[#out + 1] = MissingState("test" .. gi, g.label, g.icon, "Iron Atronach", false, true)
            end
        end
        return out
    end

    local count = C.TAGGED_SCOPES[tr.scope] and (tr.scope == "group" and 4 or 1) or 4
    for i = 1, count do
        out[#out + 1] = Timed("test" .. i, name, icon, tr.scope == "player" and GetUnitName("player") or TEST_UNITS[i],
            15 + i * 2, i * 5, { isTarget = i == 2, stacks = (i == 3) and 2 or 0 })
    end
    return out
end
