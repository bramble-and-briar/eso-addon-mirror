-- Ability timers: when a combat event (or a buff on you) for one of a tracker's abilities happens,
-- start a timer. Covers proc cooldowns, set internal cooldowns, boss mechanics and anything else the
-- game doesn't expose as a visible buff.
--
-- A timer has up to two parts: the ACTIVE part (`duration`, e.g. a set's 10 s buff) and the
-- COOLDOWN (`cooldown` seconds counted from the proc, e.g. "can proc again after 15 s"). After both,
-- the tracker can show "ready". Phases: 1 = active, 2 = cooldown, 0 = ready.
--
-- Starting it:
--   startOn "combat": a combat event for the abilities (cast, hit, proc...), filtered by result.
--   startOn "effect": a buff on you; the active part and stacks come from the buff itself, and it
--                     ends when the buff fades (the cooldown keeps running).
-- Extras: cooldownIds = abilities whose event carries the cooldown length (hit value, ms) -- some
-- stacking sets announce their cooldown that way; endIds = abilities that end the active part
-- early (e.g. Turning Tide's release). `count` (catalogue only) counts procs instead of timing them.

local DT = DebuffTracker
local Cb = DT.Combat
local U = DT.Util

local NS = "DebuffTracker5_CB"

Cb.timers = {}          -- [trackerId] = { [key] = timer }
Cb.readyAt = {}         -- [trackerId] = when its last timer finished (for "just became ready")
local registered = {}   -- [namespace] = event
local configs = {}      -- [trackerId] = trigger table (live reference)
local scales = {}       -- [trackerId] = active-part multiplier (Jorvuld's Guidance)

local RESULT_SETS
local function Results()
    if RESULT_SETS then return RESULT_SETS end
    local function Set(names)
        local s = {}
        for _, n in ipairs(names) do
            local v = _G[n]
            if v then s[v] = true end
        end
        return s
    end
    local damage = { "ACTION_RESULT_DAMAGE", "ACTION_RESULT_CRITICAL_DAMAGE", "ACTION_RESULT_DOT_TICK",
                     "ACTION_RESULT_DOT_TICK_CRITICAL", "ACTION_RESULT_BLOCKED_DAMAGE", "ACTION_RESULT_DAMAGE_SHIELDED" }
    local hit = { "ACTION_RESULT_DODGED" }
    for _, n in ipairs(damage) do hit[#hit + 1] = n end
    RESULT_SETS = {
        damage = Set(damage),
        hit = Set(hit),
        heal = Set({ "ACTION_RESULT_HEAL", "ACTION_RESULT_CRITICAL_HEAL", "ACTION_RESULT_HOT_TICK",
                     "ACTION_RESULT_HOT_TICK_CRITICAL" }),
        gained = Set({ "ACTION_RESULT_EFFECT_GAINED", "ACTION_RESULT_EFFECT_GAINED_DURATION" }),
        duration = Set({ "ACTION_RESULT_EFFECT_GAINED_DURATION" }),
        -- ExoY's ProcSet Timer starts a set's timer on these (OnCombatEvent)
        proc = Set({ "ACTION_RESULT_EFFECT_GAINED", "ACTION_RESULT_EFFECT_GAINED_DURATION", "ACTION_RESULT_DAMAGE",
                     "ACTION_RESULT_CRITICAL_DAMAGE" }),
        energize = Set({ "ACTION_RESULT_POWER_ENERGIZE" }),
        drain = Set({ "ACTION_RESULT_POWER_DRAIN" }),
    }
    return RESULT_SETS
end

local function List(trackerId)
    local list = Cb.timers[trackerId]
    if not list then list = {}; Cb.timers[trackerId] = list end
    return list
end

local function Requested()
    if DT.Engine.RequestUpdate then DT.Engine.RequestUpdate() end
end

-- When the timer is completely over (active part and cooldown).
local function EndOf(t)
    if t.untimed then return math.huge end
    return math.max(t.expire or 0, t.cdEnd or 0)
end
Cb.EndOf = EndOf

local function Fresh(cfg, trackerId, now, abilityId, abilityName, targetName, sourceName)
    local active = (cfg.duration or 0) * (scales[trackerId] or 1)
    local cooldown = cfg.cooldown or 0
    return {
        start = now,
        expire = now + active,
        duration = active,
        cdEnd = cooldown > 0 and (now + cooldown) or 0,
        abilityId = abilityId,
        name = U.CleanName((abilityName and abilityName ~= "") and abilityName or GetAbilityName(abilityId)),
        icon = GetAbilityIcon(abilityId),
        unitName = U.CleanName(targetName or ""),
        sourceName = U.CleanName(sourceName or ""),
        order = now,
        stacks = 0,
    }
end

local function Start(trackerId, result, abilityName, sourceName, targetName, targetUnitId, abilityId, hitValue, targetType)
    local cfg = configs[trackerId]
    if not cfg then return end
    -- "the ability is on cooldown" is not a proc (Cooldowns ignores it too)
    if result ~= nil and ACTION_RESULT_ABILITY_ON_COOLDOWN and result == ACTION_RESULT_ABILITY_ON_COOLDOWN then return end
    if cfg.combatResult ~= "any" and result ~= nil then   -- nil = manual test fire
        local set = Results()[cfg.combatResult]
        if set and not set[result] then return end
    end
    local now = U.Now()
    local key = cfg.perTarget and (targetUnitId or 0) or 0
    local list = List(trackerId)
    local t = list[key]
    if cfg.count then
        -- counting procs (e.g. Pearls of Ehlnofey): a short flash per proc, the count as stacks
        if t and now - t.start < (cfg.minInterval or 0) then return end
        local n = (t and t.stacks or 0) + 1
        t = Fresh(cfg, trackerId, now, abilityId, abilityName, targetName, sourceName)
        t.expire, t.duration, t.stacks, t.count = now + 1, 1, n, true
        list[key] = t
        Requested()
        return
    end
    if t and t.started then
        if now - t.start < (cfg.minInterval or 0) then
            -- the same proc's "gained" and "gained duration" events: the one carrying the length fills in
            -- an active part that's still empty (Roaring Opportunist showed only its 22 s cooldown)
            -- The longest one wins: Sul-Xan's soul sends GAINED with hit 1 (ms) and then GAINED_DURATION with
            -- hit 6200 in the same frame (in-game /dt tabtest, 5.15.4). Before, the 1 ms "length" was kept and
            -- the 6.2 s ignored, so the soul's icon vanished at once.
            local ms = tonumber(hitValue) or 0
            if cfg.durationFromHit and ms > 0 and ms / 1000 > (t.hit or 0) then
                t.duration = ms / 1000 * (scales[trackerId] or 1)
                t.expire = t.start + t.duration
                t.hit = ms / 1000
                Requested()
            end
            -- one proc, several events (Roaring Opportunist: one per player it buffs): count them
            if cfg.burst then
                t.burst = (t.burst or 1) + 1
                local id = targetUnitId or 0
                if not (t.seen and t.seen[id]) then
                    t.seen = t.seen or {}
                    t.seen[id] = true
                    t.reached = (t.reached or 0) + 1
                end
                Requested()
            end
            return
        end
        -- "restart when it fires again" off: ignored until the whole timer (incl. cooldown) is over
        if not cfg.restartOnRefresh and EndOf(t) > now then return end
    end
    local t2 = Fresh(cfg, trackerId, now, abilityId, abilityName, targetName, sourceName)
    -- "how long" carried by the event itself (hit value, ms): e.g. Sul-Xan's soul lifetime
    local ms = tonumber(hitValue) or 0
    if cfg.durationFromHit and ms > 0 then
        t2.duration = ms / 1000 * (scales[trackerId] or 1)
        t2.expire = now + t2.duration
    end
    if cfg.burst then
        t2.burst = 1
        t2.reached = 1                       -- players this proc reached (you included)
        t2.seen = { [targetUnitId or 0] = true }
    end
    t2.started = true
    -- "until it fades" (Bloodlord's Embrace): on, with no timer, until it fades from the enemy it went on
    if cfg.untilFaded then
        t2.untimed, t2.target = true, targetUnitId
        t2.expire, t2.duration = now, 0
    end
    -- the cooldown event can arrive first (same frame): keep the cooldown it announced
    if t and not t.started and (t.cdEnd or 0) > (t2.cdEnd or 0) and now - t.start < 1 then t2.cdEnd = t.cdEnd end
    t2.hit = ms > 0 and ms / 1000 or nil
    list[key] = t2
    Requested()
end

local function CombatHandler(trackerId)
    return function(_, result, isError, abilityName, _, _, sourceName, _, targetName, targetType, hitValue, _, _, _, _, targetUnitId, abilityId)
        if isError then return end
        Start(trackerId, result, abilityName or "", sourceName, targetName, targetUnitId, abilityId, hitValue, targetType)
    end
end

-- A buff on you starts it: active part = the buff's own time; stacks = its stacks.
local function EffectHandler(trackerId)
    return function(_, changeType, _, effectName, _, beginTime, endTime, stackCount, iconName, _, _, _, _, _, _, abilityId)
        local cfg = configs[trackerId]
        if not cfg then return end
        local now = U.Now()
        local list = List(trackerId)
        local t = list[0]
        if changeType == EFFECT_RESULT_FADED then
            if t and (t.untimed or (t.expire or 0) > now) then
                t.untimed = nil
                t.expire = now
                t.stacks = 0
                Requested()
            end
            return
        end
        if changeType ~= EFFECT_RESULT_GAINED and changeType ~= EFFECT_RESULT_UPDATED
            and changeType ~= EFFECT_RESULT_FULL_REFRESH then return end
        -- a new proc when nothing is running or the active part is over; with "restart when it fires
        -- again" off, a proc during the cooldown shows the buff but keeps the running cooldown
        local activeNow = t and (t.untimed or (t.expire or 0) > now)
        local isNew = not t or (not activeNow and (cfg.restartOnRefresh or EndOf(t) <= now))
        if isNew then
            t = Fresh(cfg, trackerId, now, abilityId, effectName, "", "")
            list[0] = t
        end
        local b, e = tonumber(beginTime) or 0, tonumber(endTime) or 0
        if e > b then
            t.start = b
            t.expire = e
            t.duration = e - b
            t.untimed = nil
        elseif (cfg.duration or 0) > 0 then
            -- the game gives this buff no end time (e.g. Nothing Wasted): the duration set on the tracker is
            -- used, and every new stack / refresh starts it again ("Restart when it fires again"). Before
            -- 5.10.4 a new stack never extended it -- it ran down to 0 with the buff still up.
            if cfg.restartOnRefresh or isNew then
                local d = cfg.duration * (scales[trackerId] or 1)
                t.start, t.expire, t.duration = now, now + d, d
                t.untimed = nil
            else
                t.expire = math.max(t.expire or 0, now)
            end
        else
            t.untimed = true          -- no end (toggles, permanent buffs): active until it fades
        end
        t.stacks = stackCount or 0
        if iconName and iconName ~= "" then t.icon = iconName end
        Requested()
    end
end

-- An event announcing the cooldown: its hit value is the cooldown in milliseconds.
local function CooldownHandler(trackerId)
    return function(_, result, isError, abilityName, _, _, _, _, _, _, hitValue, _, _, _, _, targetUnitId, abilityId)
        if isError then return end
        local cfg = configs[trackerId]
        if not cfg then return end
        local now = U.Now()
        local list = List(trackerId)
        local t = list[0]

        if result == ACTION_RESULT_EFFECT_FADED then
            if t and (t.cdEnd or 0) > now then t.cdEnd = now; Requested() end
            return
        end
        if result ~= ACTION_RESULT_EFFECT_GAINED_DURATION and result ~= ACTION_RESULT_EFFECT_GAINED then return end
        local ms = tonumber(hitValue) or 0
        if ms <= 0 then return end
        if not t then
            t = Fresh(cfg, trackerId, now, abilityId, abilityName, "", "")
            t.expire, t.duration = now, 0
            list[0] = t
        end
        t.cdEnd = now + ms / 1000
        Requested()
    end
end

-- Roaring Opportunist puts its 22 s cooldown on every player it buffed (ExoY's ProcSet Timer counts these
-- events, from you, on anyone): one more player reached by the proc that's running.
local function ReachHandler(trackerId)
    return function(_, result, isError, _, _, _, _, _, _, _, _, _, _, _, _, targetUnitId)
        if isError or result == ACTION_RESULT_EFFECT_FADED then return end
        local t = Cb.timers[trackerId] and Cb.timers[trackerId][0]
        local now = U.Now()
        if not (t and t.started and now - t.start < 1) then return end
        local id = targetUnitId or 0
        if t.seen and t.seen[id] then return end
        t.seen = t.seen or {}
        t.seen[id] = true
        t.reached = (t.reached or 0) + 1
        Requested()
    end
end

-- A timer whose length came from the effect itself ("Use the length the event carries"): the same effect
-- FADING ends it. Sul-Xan's soul fades (source none, target you) when it's picked up -- 1-2 s after it
-- spawned in game, not the 6.2 s it was sent with -- and the icon should go then, not keep counting.
-- A fade in the first 0.25 s is the previous one's (one soul at a time: a new soul can come in the same
-- frame as the old one fading).
local FADE_GRACE = 0.25
local function FadeHandler(trackerId)
    return function(_, result, isError)
        if isError or result ~= ACTION_RESULT_EFFECT_FADED then return end
        local t = Cb.timers[trackerId] and Cb.timers[trackerId][0]
        local now = U.Now()
        if t and t.started and (t.expire or 0) > now and now - t.start >= FADE_GRACE then
            t.expire = now
            t.faded = true
            Requested()
        end
    end
end

-- An event that ends the active part early (the cooldown keeps running).
local function EndHandler(trackerId)
    return function(_, result, isError, _, _, _, _, _, _, _, _, _, _, _, _, targetUnitId)
        if isError then return end
        local t = Cb.timers[trackerId] and Cb.timers[trackerId][0]
        local now = U.Now()
        local cfg = configs[trackerId]
        -- "until it fades": only its fading from the enemy it was put on ends it (ExoY's Bloodlord's Embrace)
        if cfg and cfg.untilFaded then
            if result ~= ACTION_RESULT_EFFECT_FADED then return end
            if t and t.target and targetUnitId and t.target ~= targetUnitId then return end
        end
        if t and (t.untimed or (t.expire or 0) > now) then
            t.untimed = nil
            t.expire = now
            Requested()
        end
    end
end

local function Want(want, ns, w) want[ns] = w end

-- trackers: trackers (or trigger proxies) whose trigger.type == "combat"
function Cb.SetRequirements(trackers)
    local want = {}
    configs, scales = {}, {}
    for _, t in ipairs(trackers) do
        local cfg = t.trigger
        configs[t.id] = cfg
        scales[t.id] = t.durationScale or 1
        local onEffect = cfg.startOn == "effect"
        for _, id in ipairs(DT.Triggers.AllIds(cfg)) do
            if onEffect then
                Want(want, string.format("%s_%s_%d_fx", NS, t.id, id), { id = t.id, ability = id, kind = "effect" })
            else
                Want(want, string.format("%s_%s_%d_%s", NS, t.id, id, cfg.combatSource),
                    { id = t.id, ability = id, kind = "combat", source = cfg.combatSource })
            end
        end
        for _, id in ipairs(cfg.cooldownIds or {}) do
            Want(want, string.format("%s_%s_%d_cd", NS, t.id, id), { id = t.id, ability = id, kind = "cooldown" })
            if cfg.burst then
                Want(want, string.format("%s_%s_%d_reach", NS, t.id, id), { id = t.id, ability = id, kind = "reach" })
            end
        end
        if cfg.durationFromHit and not onEffect and not cfg.perTarget then
            for _, id in ipairs(DT.Triggers.AllIds(cfg)) do
                Want(want, string.format("%s_%s_%d_fade", NS, t.id, id), { id = t.id, ability = id, kind = "fade" })
            end
        end
        for _, id in ipairs(cfg.endIds or {}) do
            -- "until it fades": the fade can come with no source (ExoY listens to it from anyone)
            Want(want, string.format("%s_%s_%d_end%s", NS, t.id, id, cfg.untilFaded and "_any" or ""),
                { id = t.id, ability = id, kind = "end", any = cfg.untilFaded == true })
        end
    end
    for ns, ev in pairs(registered) do
        if not want[ns] then
            EVENT_MANAGER:UnregisterForEvent(ns, ev)
            registered[ns] = nil
        end
    end
    for ns, w in pairs(want) do
        if not registered[ns] then
            if w.kind == "effect" then
                EVENT_MANAGER:RegisterForEvent(ns, EVENT_EFFECT_CHANGED, EffectHandler(w.id))
                EVENT_MANAGER:AddFilterForEvent(ns, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, w.ability,
                    REGISTER_FILTER_UNIT_TAG, "player")
                registered[ns] = EVENT_EFFECT_CHANGED
            else
                local handler
                if w.kind == "cooldown" then handler = CooldownHandler(w.id)
                elseif w.kind == "end" then handler = EndHandler(w.id)
                elseif w.kind == "reach" then handler = ReachHandler(w.id)
                elseif w.kind == "fade" then handler = FadeHandler(w.id)
                else handler = CombatHandler(w.id) end
                EVENT_MANAGER:RegisterForEvent(ns, EVENT_COMBAT_EVENT, handler)
                if w.kind == "fade" then
                    -- the fade has no source (0, 0): only the effect and that it's on you
                    EVENT_MANAGER:AddFilterForEvent(ns, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, w.ability,
                        REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER,
                        REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_FADED)
                elseif w.kind == "cooldown" or w.source == "onme" then
                    EVENT_MANAGER:AddFilterForEvent(ns, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, w.ability,
                        REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER, REGISTER_FILTER_IS_ERROR, false)
                elseif (w.kind == "end" and not w.any) or w.kind == "reach" or w.source == "me" then
                    EVENT_MANAGER:AddFilterForEvent(ns, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, w.ability,
                        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER, REGISTER_FILTER_IS_ERROR, false)
                else
                    EVENT_MANAGER:AddFilterForEvent(ns, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, w.ability,
                        REGISTER_FILTER_IS_ERROR, false)
                end
                registered[ns] = EVENT_COMBAT_EVENT
            end
        end
    end
    for id in pairs(Cb.timers) do
        if not configs[id] then Cb.timers[id] = nil end
    end
end

-- Running timers for a tracker (finished ones are dropped; proc counters are kept).
function Cb.Timers(trackerId, now)
    local list = Cb.timers[trackerId]
    if not list then return nil end
    for key, t in pairs(list) do
        if not t.count and EndOf(t) <= now then
            list[key] = nil
            Cb.readyAt[trackerId] = EndOf(t)
        end
    end
    return list
end

-- Forget proc counts (end of a fight).
function Cb.ResetCounts()
    for _, list in pairs(Cb.timers) do
        for key, t in pairs(list) do
            if t.count then list[key] = nil end
        end
    end
end

function Cb.Fire(trackerId, abilityId)   -- used by tests and the "test fire" editor button
    Start(trackerId, nil, GetAbilityName(abilityId) or "", "", "", 0, abilityId)
end

function Cb.RegisteredCount()
    return U.Count(registered)
end
