-- Buff/debuff data. Two sources, chosen per trigger scope:
--
--  * Tagged scopes (me, target, bosses, group, companion): the game can list a unit tag's effects
--    directly (GetUnitBuffInfo), which is authoritative and also correct right after a /reloadui.
--    Scans are cached per tag and refreshed when an effect event arrives for that tag (cheap
--    tag-filtered registrations), when the target/group/bosses change, and at least once a second.
--
--  * "All enemies": untagged enemies can't be listed, so their effects are reconstructed from
--    EVENT_EFFECT_CHANGED into a store keyed by unitId -- registered per tracked ability ID so the
--    game only calls us for effects we care about (or unfiltered, only if a tracker matches by name).

local DT = DebuffTracker
local E = DT.Effects
local U = DT.Util
local Units = DT.Units
local C = DT.Const

local NS = "DebuffTracker5_FX"
local SCAN_MAX_AGE = 1.0
local FADE_GRACE = 0.25

E.store = {}            -- [unitId] = { [baseId] = entry } (the instance with the most time left; see Rebuild)
E.inst = {}             -- [unitId] = { [baseId] = { [effectSlot] = instance } }
E.pending = {}          -- [unitId] = { [baseId .. ":" .. slot] = { due, baseId, slot } }
E.scans = {}            -- [tag] = { time = t, dirty = bool, list = { entry, ... } }
E.applyCounter = 0

------------------------------------------------------------------------------
-- Ability copies (copyId -> baseId)
------------------------------------------------------------------------------

local copyToBase = {}
local baseToCopies = {}
for base, copies in pairs(DT.Const.ABILITY_COPIES) do
    baseToCopies[base] = copies
    for _, id in ipairs(copies) do copyToBase[id] = base end
end

function E.BaseId(abilityId)
    return copyToBase[abilityId] or abilityId
end

function E.Copies(baseId)
    return baseToCopies[baseId] or {}
end

------------------------------------------------------------------------------
-- Entries
------------------------------------------------------------------------------

-- Icons of effects by NAME, learned whenever an effect is seen (kept in the saved variables), so an
-- entry a tracker matches by name has a real icon even while the effect isn't there (tutsuraki: buffs
-- added by name showed the game's "missing icon", a red square with a question mark).
local abilityInfo = {}      -- [abilityId] = { raw, rawIcon, name, lname, icon } (see Info below)
local function NameIconStore()
    local sv = DT.Profiles and DT.Profiles.SV and DT.Profiles.SV()
    if not sv then return nil end
    sv.nameIcons = sv.nameIcons or {}
    return sv.nameIcons
end
-- Only names that trackers use are remembered (5.13.1: every effect name seen was stored -- in a trial,
-- hundreds of names into the saved variables, kept and loaded every session).
local iconNames = {}
local ICON_STORE_MAX = 400
function E.SetIconNames(set)
    iconNames = set or {}
    abilityInfo = {}            -- (names already seen are looked at again)
    local store = NameIconStore()
    if store then
        local n = 0
        for _ in pairs(store) do n = n + 1 end
        if n > ICON_STORE_MAX then        -- left over from 5.12.7 - 5.13.0: keep the ones trackers use
            for k in pairs(store) do if not iconNames[k] then store[k] = nil end end
        end
    end
end
function E.LearnIcon(lname, icon)
    if not lname or lname == "" or not icon or icon == "" or icon == C.DEFAULT_ICON then return end
    if not iconNames[lname] then return end
    local store = NameIconStore()
    if store and store[lname] ~= icon then store[lname] = icon end
end
function E.LearnedIcon(lname)
    local store = NameIconStore()
    return store and store[lname] or nil
end

-- Name, lowercase name and icon per ability (5.13.1: worked out ONCE per ability instead of for every
-- buff of every unit at every rescan -- in a trial 12 players x ~45 buffs were rescanned 10x a second,
-- each with two string conversions: megabytes of garbage per second mid-fight)
local function Info(abilityId, name, icon)
    local i = abilityInfo[abilityId]
    if i and i.raw == name and i.rawIcon == icon then return i end
    local useName = name ~= "" and name or GetAbilityName(abilityId)
    local useIcon = (icon and icon ~= "") and icon or GetAbilityIcon(abilityId)
    i = { raw = name, rawIcon = icon, name = U.CleanName(useName), lname = U.Lower(useName), icon = useIcon }
    abilityInfo[abilityId] = i
    E.LearnIcon(i.lname, useIcon)
    return i
end

-- Fills `e` (a reused table) or a new one.
local function FillEntry(e, abilityId, name, icon, beginTime, endTime, stacks, effectType, mine, abilityType)
    local i = Info(abilityId, name or "", icon)
    e = e or {}
    e.abilityType = abilityType
    e.abilityId = abilityId
    e.baseId = E.BaseId(abilityId)
    e.name = i.name
    e.lname = i.lname
    e.icon = i.icon
    e.begin = beginTime or 0
    e.finish = endTime or 0
    e.stacks = stacks or 0
    e.effectType = effectType
    e.mine = mine == true
    return e
end

local function MakeEntry(abilityId, name, icon, beginTime, endTime, stacks, effectType, mine, abilityType)
    return FillEntry(nil, abilityId, name, icon, beginTime, endTime, stacks, effectType, mine, abilityType)
end

------------------------------------------------------------------------------
-- Tagged scans
------------------------------------------------------------------------------

function E.MarkDirty(tag)
    local s = E.scans[tag]
    if s then s.dirty = true end
end

function E.MarkPrefixDirty(prefix)
    local n = #prefix
    for tag, s in pairs(E.scans) do
        if tag:sub(1, n) == prefix then s.dirty = true end
    end
end

function E.MarkAllDirty()
    for _, s in pairs(E.scans) do s.dirty = true end
end

-- A tag's list and its entries are reused from scan to scan (the tables are overwritten in place: a
-- trial's group was rescanned ~10x a second -- 12 players x ~45 buffs -- and every rescan made new ones).
-- Nothing keeps a scanned entry past the update that read it (states copy what they need).
function E.Scan(tag, now)
    local s = E.scans[tag]
    if s and not s.dirty and (now - s.time) < SCAN_MAX_AGE then return s.list end
    if not s then s = { list = {} }; E.scans[tag] = s end
    local list = s.list
    local n = 0
    if DoesUnitExist(tag) then
        for i = 1, GetNumBuffs(tag) do
            local name, startTime, endTime, buffSlot, stacks, icon, _, effectType, abilityType, _, abilityId, _, castByPlayer = GetUnitBuffInfo(tag, i)
            if abilityId then
                n = n + 1
                list[n] = FillEntry(list[n], abilityId, name or "", icon, startTime, endTime, stacks, effectType, castByPlayer, abilityType)
                list[n].slot = buffSlot     -- the same slot its effect events carry (a tab-target lock is seeded from it)
            end
        end
    end
    for i = #list, n + 1, -1 do list[i] = nil end
    s.time, s.dirty = now, false
    return list
end

------------------------------------------------------------------------------
-- Enemy store
------------------------------------------------------------------------------

local wantIds = {}       -- raw ability ids that enemy-scope triggers listen for
local wantNames = {}     -- lowercase names (unfiltered registration)
-- (is this ability listened to on enemies right now? -- for tests and /dt perf)
function E.WantsId(id) return wantIds[id] == true end
-- lowercase of effect names seen by the unfiltered registration (every effect in the area reaches it)
local lowerOf, lowerCount = {}, 0
local function LowerName(name)
    local l = lowerOf[name]
    if l then return l end
    if lowerCount > 4000 then lowerOf, lowerCount = {}, 0 end
    l = U.Lower(name)
    lowerOf[name] = l
    lowerCount = lowerCount + 1
    return l
end
local registeredIds = {}
local nameModeRegistered = false
local tagRegistered = {}

-- Several players (or the same player with several skills) can put the same effect on one enemy:
-- each is its own instance with its own effect slot. One instance fading must not remove the effect
-- while others are still on the enemy (a boss in a trial lost its Major Breach after a few seconds when
-- the first of several applications ran out). So instances are kept by slot and the shown entry is
-- rebuilt from what's left: the instance with the most time left, plus `my` / `others` (the best of
-- your own and of everyone else's) for "cast by me / by others" trackers.
local function Better(a, b)        -- does instance a have more time left than b?
    if not b then return true end
    local pa = a.finish <= a.begin  -- permanent
    local pb = b.finish <= b.begin
    if pa ~= pb then return pa end
    if math.abs(a.finish - b.finish) > 0.05 then return a.finish > b.finish end
    -- same end: the one changed most recently (a stack update can arrive on another slot)
    return (a.changed or 0) > (b.changed or 0)
end

local function Rebuild(unitId, baseId)
    local byBase = E.inst[unitId]
    local slots = byBase and byBase[baseId]
    local best, my, others
    if slots then
        for _, i in pairs(slots) do
            if Better(i, best) then best = i end
            if i.mine then if Better(i, my) then my = i end
            elseif Better(i, others) then others = i end
        end
    end
    local u = E.store[unitId]
    if not best then
        if slots then byBase[baseId] = nil; if next(byBase) == nil then E.inst[unitId] = nil end end
        if u then
            u[baseId] = nil
            if next(u) == nil then E.store[unitId] = nil end
        end
        return
    end
    if not u then u = {}; E.store[unitId] = u end
    -- the shown entry is updated in place (a trial sends hundreds of these changes a second)
    local e = u[baseId]
    local skey = e and e.skey
    if e then for k in pairs(e) do e[k] = nil end else e = {} end
    for k, v in pairs(best) do e[k] = v end
    e.my, e.others = my, others
    -- effects whose stacks count something (Touch of Z'en: the caster's DoTs): the highest count
    if DT.Const.ZERO_BASED_STACKS[baseId] then
        for _, i in pairs(slots) do
            if (i.stacks or 0) > (e.stacks or 0) then e.stacks = i.stacks end
        end
    end
    e.order = best.order
    e.skey = skey
    u[baseId] = e
end
E.Rebuild = Rebuild

-- "/dt debug": every change to the enemy list, with the reason (to diagnose "it disappeared")
local function Who(unitId) return string.format("%s(%s)", tostring(Units.nameOf[unitId] or "?"), tostring(unitId)) end
local function Dbg(fmt, ...) if DT.debug then U.Debug(fmt, ...) end end
E.Who = Who

local function PendingKey(baseId, slot) return baseId .. ":" .. tostring(slot) end

local function ClearPending(unitId, baseId, slot)
    local p = E.pending[unitId]
    if p then
        p[PendingKey(baseId, slot)] = nil
        if next(p) == nil then E.pending[unitId] = nil end
    end
end

-- Remove one instance (slot given) or the whole effect from an enemy.
function E.Remove(unitId, baseId, slot, reason)
    if DT.debug then Dbg("removed %s from %s (slot %s): %s", tostring(GetAbilityName(baseId)), Who(unitId), tostring(slot), tostring(reason or "faded")) end
    local byBase = E.inst[unitId]
    if slot ~= nil and byBase and byBase[baseId] then
        byBase[baseId][slot] = nil
        if next(byBase[baseId]) == nil then byBase[baseId] = nil end
        ClearPending(unitId, baseId, slot)
    else
        if byBase then byBase[baseId] = nil end
        local p = E.pending[unitId]
        if p then
            for k, v in pairs(p) do if v[2] == baseId then p[k] = nil end end
            if next(p) == nil then E.pending[unitId] = nil end
        end
    end
    if byBase and next(byBase) == nil then E.inst[unitId] = nil end
    Rebuild(unitId, baseId)
end

function E.RemoveUnit(unitId, reason)
    E.dots[unitId] = nil
    if DT.debug and E.store[unitId] then Dbg("removed every effect from %s: %s", Who(unitId), tostring(reason or "?")) end
    E.store[unitId] = nil
    E.inst[unitId] = nil
    E.pending[unitId] = nil
end

local function ProcessPending()
    local now = U.Now()
    for unitId, p in pairs(E.pending) do
        for _, v in pairs(p) do
            if now >= v[1] then E.Remove(unitId, v[2], v[3], "faded (no refresh within 0.25 s)") end
        end
    end
    if next(E.pending) == nil then
        EVENT_MANAGER:UnregisterForUpdate(NS .. "_Pending")
        E.pendingScheduled = false
    end
end

-- A FADED event: the instance goes after a short grace (a refresh is often FADED + GAINED).
local function QueueRemoval(unitId, baseId, slot)
    E.pending[unitId] = E.pending[unitId] or {}
    E.pending[unitId][PendingKey(baseId, slot)] = { U.Now() + FADE_GRACE, baseId, slot }
    if not E.pendingScheduled then
        E.pendingScheduled = true
        EVENT_MANAGER:RegisterForUpdate(NS .. "_Pending", 100, ProcessPending)
    end
end

------------------------------------------------------------------------------
-- Which enemy is my target? There is no API that gives the unitId of "reticleover", and looking at an
-- enemy fires no effect event. So the target is DEDUCED: the effects on "reticleover" (ability + start
-- + end time, read with GetUnitBuffInfo) and its name are matched against the enemies we track by
-- unitId. Each matching effect is a vote; a different name rules a unit out; the same name breaks
-- ties. If several units still tie (same name, effects applied at the same instant) all of them are
-- marked -- they can't be told apart. With no matching effects, a name that only one tracked enemy
-- has is enough.
------------------------------------------------------------------------------

local TIME_TOLERANCE = 0.05

function E.ResolveTarget()
    -- a corpse or an ally isn't one of the enemies we track (and must not be matched to a living one
    -- by name: that one would then be forgotten as "dead")
    if not DoesUnitExist("reticleover") or IsUnitDead("reticleover") or not Units.IsEnemyTag("reticleover") then return nil end
    local targetName = U.CleanName(GetUnitName("reticleover"))
    local buffs = {}
    for i = 1, GetNumBuffs("reticleover") do
        local _, startTime, endTime, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("reticleover", i)
        if abilityId then buffs[#buffs + 1] = { E.BaseId(abilityId), startTime or 0, endTime or 0 } end
    end
    local scores = {}
    for unitId, effects in pairs(E.store) do
        local name = Units.nameOf[unitId]
        if not (name and targetName ~= "" and name ~= targetName) then     -- a different name: not it
            local votes = 0
            for _, b in ipairs(buffs) do
                local e = effects[b[1]]
                if e and math.abs(e.begin - b[2]) <= TIME_TOLERANCE and math.abs(e.finish - b[3]) <= TIME_TOLERANCE then
                    votes = votes + 1
                end
            end
            if votes > 0 then scores[unitId] = votes + ((name == targetName) and 0.5 or 0) end
        end
    end
    local best, ties = 0, {}
    for unitId, score in pairs(scores) do
        if score > best then best, ties = score, { unitId }
        elseif score == best then ties[#ties + 1] = unitId end
    end
    if #ties == 0 and targetName ~= "" then
        -- no effect matched: fall back to the name. A same-named enemy that has a tracked effect the
        -- target doesn't show can't be it; if several remain, all of them are marked (like twins).
        local onTarget = {}
        for _, b in ipairs(buffs) do onTarget[b[1]] = true end
        local now = U.Now()
        local seen = {}
        for unitId in pairs(E.store) do seen[unitId] = true end
        for unitId in pairs(Units.engaged) do seen[unitId] = true end
        for unitId in pairs(seen) do
            if Units.nameOf[unitId] == targetName then
                local contradicts = false
                for baseId, e in pairs(E.store[unitId] or {}) do
                    if not onTarget[baseId] and (e.finish <= e.begin or e.finish > now) then contradicts = true; break end
                end
                if not contradicts then ties[#ties + 1] = unitId end
            end
        end
    end
    if #ties == 0 then return nil end
    table.sort(ties)
    Units.SetTarget(ties[1], ties)
    return ties[1], ties
end

local groupWant = { all = true }

-- Tab-target lock (DT.TabTarget): while "my target" follows an enemy you're not looking at, the effects of
-- the "my target" trackers are stored for THAT enemy from its effect events (registered only while locked).
local lockUnit = nil
local lockIds, lockNames = {}, {}        -- what "my target" trackers look for (set by SetRequirements)
local function LockWants(abilityId, effectName)
    if lockIds.all or lockIds[abilityId] then return true end
    return next(lockNames) ~= nil and effectName ~= nil and lockNames[LowerName(effectName)] == true
end
local function GroupWants(abilityId, effectName)
    local w = groupWant
    if w.all or w.ids[abilityId] then return true end
    if next(w.names) and effectName and w.names[LowerName(effectName)] then return true end
    return false
end

-- Shared intake for every EVENT_EFFECT_CHANGED registration.
E.eventCount = 0     -- effect events received (for /dt perf)
local last = {}     -- the previous event: one game event reaches several of our registrations
local function OnEffect(_, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName,
                        _, effectType, _, _, unitName, unitId, abilityId, sourceType)
    -- e.g. a tracked debuff on your target arrives through its ability-ID registration AND the
    -- "reticleover" one, in the same frame: handle it once (the recorder showed every row twice)
    local frame = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
    if last.frame == frame and last.unitId == unitId and last.abilityId == abilityId and last.change == changeType
        and last.b == beginTime and last.e == endTime and last.stacks == stackCount and last.tag == unitTag
        and last.slot == effectSlot then
        return
    end
    -- the same change under another tag (the boss as "boss1" AND as "reticleover", the debug log of a
    -- trial boss showed every Taunt / Off Balance twice): the tag learns from it, the store needn't redo it
    local sameChange = last.frame == frame and last.unitId == unitId and last.abilityId == abilityId and last.change == changeType
        and last.b == beginTime and last.e == endTime and last.stacks == stackCount and last.slot == effectSlot
    last.frame, last.unitId, last.abilityId, last.change, last.slot = frame, unitId, abilityId, changeType, effectSlot
    last.b, last.e, last.stacks, last.tag = beginTime, endTime, stackCount, unitTag
    E.eventCount = E.eventCount + 1
    Units.Observe(unitTag, unitId, unitName)
    if unitTag and unitTag ~= "" then
        -- a group member's buff list is rescanned only for a change a tracker can see (in a trial, 12
        -- players' buffs change all the time; anything else is caught by the once-a-second rescan)
        if unitTag:byte(1) ~= 103 or unitTag:sub(1, 5) ~= "group" or GroupWants(abilityId, effectName) then E.MarkDirty(unitTag) end
    end
    if DT.Recorder.active then DT.Recorder.OnEffect(changeType, effectName, unitTag, beginTime, endTime, stackCount, iconName, effectType, unitName, unitId, abilityId, sourceType) end
    if sameChange and unitId and unitId ~= 0 then return end

    if Units.IsFriendlyTag(unitTag) then return end
    -- your target is an ally (a player, companion, friendly NPC): not an enemy
    if unitTag == "reticleover" and not Units.IsEnemyTag("reticleover") then return end
    if not (wantIds[abilityId] or (next(wantNames) and wantNames[LowerName(effectName or "")])
        or (lockUnit and unitId == lockUnit and LockWants(abilityId, effectName))) then return end

    local baseId = E.BaseId(abilityId)
    local mine = sourceType == COMBAT_UNIT_TYPE_PLAYER or sourceType == COMBAT_UNIT_TYPE_PLAYER_PET
    -- the instance: its effect slot (fallback: whose it is)
    local slot = effectSlot or (mine and "mine" or "other")
    if changeType == EFFECT_RESULT_FADED then
        -- a re-application can arrive as GAINED (new) followed by FADED (old) on the same slot: that
        -- FADED belongs to the old application, not to the one just stored
        local cur = E.inst[unitId] and E.inst[unitId][baseId] and E.inst[unitId][baseId][slot]
        if cur then
            local b, e = tonumber(beginTime) or 0, tonumber(endTime) or 0
            local older = e > 0 and e < cur.finish - 0.05 and b < cur.begin - 0.05
            if older or cur.gainFrame == frame then
                if DT.debug then Dbg("ignored an old FADED of %s on %s (slot %s)", tostring(effectName), Who(unitId), tostring(slot)) end
                return
            end
        end
        if DT.debug then Dbg("FADED %s on %s (slot %s, tag '%s')", tostring(effectName), Who(unitId), tostring(slot), tostring(unitTag)) end
        QueueRemoval(unitId, baseId, slot)
        return
    end
    -- an enemy that just died: effect events still arriving for it (the hit that killed it applied Off
    -- Balance, a proc landed in the same batch) don't bring it back on the list. Much later, a new effect
    -- means it's alive again (a resurrected player in PvP).
    local diedAt = E.died[unitId]
    if diedAt then
        if U.Now() - diedAt < E.DEATH_GRACE then
            if DT.debug then Dbg("ignored %s on %s: it died %.1f s ago", tostring(effectName), Who(unitId), U.Now() - diedAt) end
            return
        end
        if changeType == EFFECT_RESULT_GAINED then E.died[unitId] = nil end
    end
    ClearPending(unitId, baseId, slot)
    local byBase = E.inst[unitId]
    if not byBase then byBase = {}; E.inst[unitId] = byBase end
    local slots = byBase[baseId]
    if not slots then slots = {}; byBase[baseId] = slots end
    local old = slots[slot]
    local shown = E.store[unitId] and E.store[unitId][baseId]
    if not shown or changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_FULL_REFRESH then
        E.applyCounter = E.applyCounter + 1
    end
    -- "order applied" stays with the effect while it's on the enemy
    local order = (shown and shown.order) or (old and old.order) or E.applyCounter
    if changeType == EFFECT_RESULT_GAINED and not shown then order = E.applyCounter end
    -- the instance's table is reused for its next change
    local e = FillEntry(old, abilityId, effectName or "", iconName, beginTime, endTime, stackCount, effectType, mine)
    e.order = order
    e.gainFrame = (changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_FULL_REFRESH) and frame or nil
    E.changeCounter = (E.changeCounter or 0) + 1
    e.changed = E.changeCounter
    if DT.debug then
        Dbg("%s %s on %s (slot %s, %.1fs, stacks %s, tag '%s')", changeType == EFFECT_RESULT_GAINED and "GAINED" or "UPDATED", tostring(effectName),
            Who(unitId), tostring(slot), (tonumber(endTime) or 0) - (tonumber(beginTime) or 0), tostring(stackCount), tostring(unitTag))
    end
    slots[slot] = e
    Rebuild(unitId, baseId)
end
E.OnEffect = OnEffect   -- exposed for the recorder and tests

function E.Prune(now)
    for unitId, byBase in pairs(E.inst) do
        for baseId, slots in pairs(byBase) do
            local changed = false
            for slot, i in pairs(slots) do
                if i.finish > 0 and i.finish > i.begin and i.finish < now - 0.5 then slots[slot] = nil; changed = true end
            end
            if changed then
                if DT.debug then Dbg("expired %s on %s", tostring(GetAbilityName(baseId)), Who(unitId)) end
                Rebuild(unitId, baseId)
            end
        end
    end
end

function E.ResetStore()
    E.store, E.inst, E.pending, E.scans = {}, {}, {}, {}
    E.dots, E.died = {}, {}
    EVENT_MANAGER:UnregisterForUpdate(NS .. "_Pending")
    E.pendingScheduled = false
end

------------------------------------------------------------------------------
-- Registrations
------------------------------------------------------------------------------

local TAG_REGISTRATIONS = {
    player = { "player" },
    target = { "reticleover" },
    companion = { "companion" },
    group = { "group", prefix = true },
    boss = { "boss", prefix = true },
}

-- The group's registration: in a trial 12 players' buffs change all the time, and every change marked
-- that player's buff list for a rescan. When the group trackers list their abilities by ID (no names),
-- it listens to those abilities only (one registration per ability, filtered by ability AND "group"
-- tags); other changes are picked up by the once-a-second rescan. (5.13.1)
local tagIds = {}           -- [scope] = { [abilityId] = true } registered by ability; nil = unfiltered

local function TagNs(scope, id) return NS .. "_Tag_" .. scope .. (id and ("_" .. id) or "") end

local function UnregisterTag(scope)
    if not tagRegistered[scope] then return end
    if tagIds[scope] then
        for id in pairs(tagIds[scope]) do EVENT_MANAGER:UnregisterForEvent(TagNs(scope, id), EVENT_EFFECT_CHANGED) end
    else
        EVENT_MANAGER:UnregisterForEvent(TagNs(scope), EVENT_EFFECT_CHANGED)
    end
    tagRegistered[scope], tagIds[scope] = nil, nil
end

local function SameSet(a, b)
    if (a == nil) ~= (b == nil) then return false end
    if not a then return true end
    for k in pairs(a) do if not b[k] then return false end end
    for k in pairs(b) do if not a[k] then return false end end
    return true
end

-- ids: nil = every effect on the tag(s); a set = only these abilities (prefix scopes only)
local function RegisterTag(scope, ids)
    local spec = TAG_REGISTRATIONS[scope]
    if not spec then return end
    if ids and not (spec.prefix and REGISTER_FILTER_UNIT_TAG_PREFIX) then ids = nil end
    if tagRegistered[scope] then
        if SameSet(tagIds[scope], ids) then return end
        UnregisterTag(scope)
    end
    if ids then
        for id in pairs(ids) do
            local ns = TagNs(scope, id)
            EVENT_MANAGER:RegisterForEvent(ns, EVENT_EFFECT_CHANGED, OnEffect)
            EVENT_MANAGER:AddFilterForEvent(ns, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, id,
                REGISTER_FILTER_UNIT_TAG_PREFIX, spec[1])
        end
    else
        local ns = TagNs(scope)
        EVENT_MANAGER:RegisterForEvent(ns, EVENT_EFFECT_CHANGED, OnEffect)
        if spec.prefix and REGISTER_FILTER_UNIT_TAG_PREFIX then
            EVENT_MANAGER:AddFilterForEvent(ns, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, spec[1])
        elseif not spec.prefix then
            EVENT_MANAGER:AddFilterForEvent(ns, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, spec[1])
        end
    end
    tagRegistered[scope], tagIds[scope] = true, ids
end

-- req = { ids = set of base/raw ids (copies added here), names = set, scopes = set }
------------------------------------------------------------------------------
-- "My damage-over-time effects on that enemy" -- Touch of Z'en's strength is the number of YOUR DoTs
-- on the enemy, and the game doesn't report that as the effect's stacks (Cooldowns counted them the
-- same way). Kept only while a tracker uses "stacks = my DoTs": one registration for effects you
-- cause (source = you), counting damage-type timed effects per enemy.
------------------------------------------------------------------------------

E.dots = {}             -- [unitId] = { [slot] = finish }
local dotsRegistered = false
local NOT_A_DOT = { [126597] = true }     -- Touch of Z'en itself
local function OnMyEffect(_, changeType, effectSlot, _, unitTag, beginTime, endTime, _, _, _, _, abilityType, _, _, unitId, abilityId, sourceType)
    -- your own DoTs only (pets' don't count: same as LibCombat's Z'en count)
    if sourceType ~= COMBAT_UNIT_TYPE_PLAYER then return end
    if NOT_A_DOT[abilityId] then return end
    if abilityType ~= ABILITY_TYPE_DAMAGE or not unitId or unitId == 0 or Units.IsFriendlyTag(unitTag) then return end
    local d = E.dots[unitId]
    if changeType == EFFECT_RESULT_FADED then
        if d then d[effectSlot or 0] = nil; if next(d) == nil then E.dots[unitId] = nil end end
        return
    end
    local e, b = tonumber(endTime) or 0, tonumber(beginTime) or 0
    if e <= b then return end                       -- DoTs are timed
    if not d then d = {}; E.dots[unitId] = d end
    d[effectSlot or 0] = e
end

local function SetDotTracking(on)
    if on == dotsRegistered then return end
    dotsRegistered = on
    if on then
        EVENT_MANAGER:RegisterForEvent(NS .. "_MyDots", EVENT_EFFECT_CHANGED, OnMyEffect)
        EVENT_MANAGER:AddFilterForEvent(NS .. "_MyDots", EVENT_EFFECT_CHANGED, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    else
        EVENT_MANAGER:UnregisterForEvent(NS .. "_MyDots", EVENT_EFFECT_CHANGED)
        E.dots = {}
    end
end

-- How many of your DoTs are on an enemy (by unitId) or on a unit tag (read from its buff list).
function E.MyDots(unitId, tag, now)
    local n = 0
    if tag then
        for _, e in ipairs(E.Scan(tag, now)) do
            if e.mine and e.abilityType == ABILITY_TYPE_DAMAGE and e.finish > now and not NOT_A_DOT[e.abilityId] then n = n + 1 end
        end
        return n
    end
    local d = unitId and E.dots[unitId]
    if not d then return 0 end
    for slot, finish in pairs(d) do
        if finish > now then n = n + 1 else d[slot] = nil end
    end
    return n
end

local lockRegistered = {}     -- [ns] = true
local deathWanted = false
local function SetLockListening(on)
    for ns in pairs(lockRegistered) do EVENT_MANAGER:UnregisterForEvent(ns, EVENT_EFFECT_CHANGED) end
    lockRegistered = {}
    if not on then return end
    if lockIds.all or next(lockNames) then
        -- names (or "every effect"): one unfiltered registration, only while locked
        EVENT_MANAGER:RegisterForEvent(NS .. "_LockAll", EVENT_EFFECT_CHANGED, OnEffect)
        lockRegistered[NS .. "_LockAll"] = true
    end
    if not lockIds.all then
        for id in pairs(lockIds) do
            local ns = NS .. "_Lock_" .. id
            EVENT_MANAGER:RegisterForEvent(ns, EVENT_EFFECT_CHANGED, OnEffect)
            EVENT_MANAGER:AddFilterForEvent(ns, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, id)
            lockRegistered[ns] = true
        end
    end
end

-- Lock "my target" on an enemy by unitId (nil = no lock). seed: its buff list, read while you looked at it
-- (effects applied before the lock send no event; they're copied in, by the same slot their events use).
function E.SetLock(unitId, seed)
    if unitId ~= lockUnit then
        lockUnit = unitId
        SetLockListening(unitId ~= nil)
        E.SetDeathTracking(deathWanted or unitId ~= nil)
    end
    if unitId and seed then
        for _, s0 in ipairs(seed) do
            if LockWants(s0.abilityId, s0.name) then
                local baseId = E.BaseId(s0.abilityId)
                local byBase = E.inst[unitId]
                if not byBase then byBase = {}; E.inst[unitId] = byBase end
                local slots = byBase[baseId]
                if not slots then slots = {}; byBase[baseId] = slots end
                local slot = s0.slot or ("scan" .. s0.abilityId)
                if not slots[slot] then
                    local e = FillEntry(nil, s0.abilityId, s0.name, s0.icon, s0.begin, s0.finish, s0.stacks, s0.effectType, s0.mine, s0.abilityType)
                    E.applyCounter = E.applyCounter + 1
                    e.order = E.applyCounter
                    slots[slot] = e
                    Rebuild(unitId, baseId)
                end
            end
        end
    end
end
function E.LockUnit() return lockUnit end

function E.SetRequirements(req)
    SetDotTracking(req.myDots == true)
    -- what "my target" trackers look for: listened to for the locked tab target only
    lockIds, lockNames = {}, {}
    for id in pairs(req.targetIds or {}) do
        lockIds[id] = true
        for _, copy in ipairs(E.Copies(id)) do lockIds[copy] = true end
    end
    for n in pairs(req.targetNames or {}) do lockNames[n] = true end
    if req.targetAll then lockIds.all = true end
    if lockUnit then SetLockListening(true) end
    if req.groupWant then
        local ids = {}
        for id in pairs(req.groupWant.ids or {}) do
            ids[id] = true
            for _, copy in ipairs(E.Copies(id)) do ids[copy] = true end
        end
        -- proc buffs counted on the group (Roaring Opportunist's Major Slayer on allies)
        for _, p in ipairs(DT.Procs and DT.Procs.All and DT.Procs.All() or {}) do
            for _, id in ipairs(p.buffIds or {}) do ids[id] = true end
        end
        groupWant = { ids = ids, names = req.groupWant.names or {}, all = req.groupWant.all == true }
    else
        groupWant = { all = true }
    end
    wantIds, wantNames = {}, {}
    for id in pairs(req.ids or {}) do
        wantIds[id] = true
        for _, copy in ipairs(E.Copies(id)) do wantIds[copy] = true end
    end
    for n in pairs(req.names or {}) do wantNames[n] = true end

    for id in pairs(registeredIds) do
        if not wantIds[id] then
            EVENT_MANAGER:UnregisterForEvent(NS .. "_Id_" .. id, EVENT_EFFECT_CHANGED)
            registeredIds[id] = nil
        end
    end
    for id in pairs(wantIds) do
        if not registeredIds[id] then
            local ns = NS .. "_Id_" .. id
            EVENT_MANAGER:RegisterForEvent(ns, EVENT_EFFECT_CHANGED, OnEffect)
            EVENT_MANAGER:AddFilterForEvent(ns, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, id)
            registeredIds[id] = true
        end
    end

    local needUnfiltered = next(wantNames) ~= nil or DT.Recorder.active
    if needUnfiltered and not nameModeRegistered then
        EVENT_MANAGER:RegisterForEvent(NS .. "_All", EVENT_EFFECT_CHANGED, OnEffect)
        nameModeRegistered = true
    elseif not needUnfiltered and nameModeRegistered then
        EVENT_MANAGER:UnregisterForEvent(NS .. "_All", EVENT_EFFECT_CHANGED)
        nameModeRegistered = false
    end

    deathWanted = req.enemies == true
    E.SetDeathTracking(deathWanted or lockUnit ~= nil)
    for scope in pairs(TAG_REGISTRATIONS) do
        -- your target: also while enemies are followed (its events name the target's unitId exactly: highlighting)
        local want = req.scopes and req.scopes[scope] or (scope == "target" and req.enemies == true)
        if want then
            local ids
            if scope == "group" and req.groupIds and next(req.groupIds) then
                ids = {}
                for id in pairs(req.groupIds) do
                    ids[id] = true
                    for _, copy in ipairs(E.Copies(id)) do ids[copy] = true end
                end
            end
            RegisterTag(scope, ids)
        else
            UnregisterTag(scope)
        end
    end
end

------------------------------------------------------------------------------
-- Lifecycle: deaths (no reliable FADED follows), target/group/boss changes, zone changes
------------------------------------------------------------------------------

-- enemies that died this fight ([unitId] = when): their ended ("kept after it ends") entries go at once,
-- like Untaunted's, and events still arriving for them right after the death don't bring them back
-- (Yarden, 5.12.0: a long pull left "Off Balance ready" rows on dead enemies -- a hit landing after the
-- death event put the corpse back on the list of enemies you're fighting)
E.died = {}
E.DEATH_GRACE = 3
local function OnDeath(_, result, _, _, _, _, _, _, targetName, _, _, _, _, _, _, targetUnitId)
    if targetUnitId and targetUnitId ~= 0 then E.died[targetUnitId] = U.Now() end
    if E.store[targetUnitId] then E.RemoveUnit(targetUnitId, "death event " .. tostring(result) .. " for " .. tostring(targetName)) end
    Units.RemoveEngaged(targetUnitId)
end

-- Deaths only matter while some tracker follows enemies (5.14.4: registered only then -- a feature nobody
-- uses costs nothing; every death in a trial reached us before)
local deathTracking = false
local function SetDeathTracking(on)
    on = on == true
    if on == deathTracking then return end
    deathTracking = on
    -- a unit dying: "died", "died (xp)" and the killing blow all name it as the target
    for i, result in ipairs({ ACTION_RESULT_DIED or 2260, ACTION_RESULT_DIED_XP or 2262, ACTION_RESULT_KILLING_BLOW or 2265 }) do
        local ns = NS .. "_Died" .. i
        if on then
            EVENT_MANAGER:RegisterForEvent(ns, EVENT_COMBAT_EVENT, OnDeath)
            EVENT_MANAGER:AddFilterForEvent(ns, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, result, REGISTER_FILTER_IS_ERROR, false)
        else
            EVENT_MANAGER:UnregisterForEvent(ns, EVENT_COMBAT_EVENT)
        end
    end
    if not on then E.died = {} end
end
E.SetDeathTracking = SetDeathTracking

function E.Initialize()
    -- leaving combat ends every fight
    EVENT_MANAGER:RegisterForEvent(NS .. "_CombatState", EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        Dbg("combat state: %s", inCombat and "IN combat" or "OUT of combat")
        if inCombat then return end
        -- only once combat has really ended (the state flickers mid-fight; see Load.InCombat)
        zo_callLater(function()
            if not IsUnitInCombat("player") then
                Units.ClearEngaged()
                E.died = {}
                if DT.Engine.RequestUpdate then DT.Engine.RequestUpdate() end
            end
        end, DT.Load.COMBAT_GRACE * 1000)
    end)

    EVENT_MANAGER:RegisterForEvent(NS .. "_Reticle", EVENT_RETICLE_TARGET_CHANGED, function()
        -- the reticle is ALREADY on the new unit here: forget the old target's id first (checking for
        -- a dead target now would blame the previous, living target for the corpse you look at)
        Units.OnReticleChanged()
        E.MarkDirty("reticleover")
        E.ResolveTarget()
        if DT.Engine.RequestUpdate then DT.Engine.RequestUpdate() end
    end)
    local function GroupChanged()
        E.MarkPrefixDirty("group")
        if DT.Engine.StandingChanged then DT.Engine.StandingChanged() end   -- "group size" load conditions
    end
    EVENT_MANAGER:RegisterForEvent(NS .. "_GroupUpdate", EVENT_GROUP_UPDATE, GroupChanged)
    EVENT_MANAGER:RegisterForEvent(NS .. "_GroupJoined", EVENT_GROUP_MEMBER_JOINED, GroupChanged)
    EVENT_MANAGER:RegisterForEvent(NS .. "_GroupLeft", EVENT_GROUP_MEMBER_LEFT, GroupChanged)
    if EVENT_BOSSES_CHANGED then
        EVENT_MANAGER:RegisterForEvent(NS .. "_Bosses", EVENT_BOSSES_CHANGED, function() E.MarkPrefixDirty("boss") end)
    end
end

-- After a loading screen every unitId belongs to the previous area.
function E.OnZoneChanged()
    Dbg("loading screen: enemy list cleared")
    E.ResetStore()
    Units.Reset()
    if DT.TabTarget then DT.TabTarget.Reset() end
    if DT.Ticks then DT.Ticks.Reset() end
end

function E.RegisteredCount()
    local n = U.Count(registeredIds) + (nameModeRegistered and 1 or 0)
    for scope in pairs(tagRegistered) do n = n + (tagIds[scope] and U.Count(tagIds[scope]) or 1) end
    return n
end

function E.IsUnfilteredActive()
    return nameModeRegistered
end
