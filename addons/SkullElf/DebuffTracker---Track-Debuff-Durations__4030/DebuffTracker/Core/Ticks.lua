-- Resource ticks: when your health / magicka / stamina regenerates next (Trigger "Resource tick").
--
-- The game regenerates resources in steps every 2 s, and no API says when the next step comes. How Miat's Ticks
-- Tracker (Dorrino / Asquart, 1.15) finds them, read in full:
--   * EVENT_POWER_UPDATE on "player": a rise that is exactly your regen stat (GetPlayerStat STAT_<res>_REGEN_COMBAT in
--     combat, _IDLE out of it, STAT_BONUS_OPTION_APPLY_BONUS) is a regen tick; any other rise (a heal, a skill's
--     restore, a potion) isn't.
--   * it "trusts" that time; a rise of the right size less than 1.75 s after a trusted tick is ignored (a restore that
--     happened to be the same size) -- unless, added to the one ignored before it, it makes 1.9-2.1 s (the real tick
--     came after a false one).
--   * between ticks: progress = time since the trusted tick / 2 s; 10 ms past 2 s with no tick seen (resource full,
--     or the rise hidden by a cost in the same update) the next tick is predicted and no longer trusted.
-- Dodge fatigue (ability 69143, "Show dodge fatigue on the bar"): +1 per gain on you, 0 when it fades. Miat 1.15 passes
-- the event's code as the result (the handler is registered without dropping the event code), so its fatigue never
-- counts; 1.12 used EFFECT_GAINED_DURATION. Here both gain results count, once per dodge (they can arrive together).
--
-- Here: the same detection, but only for the resources a "Resource tick" tracker shows (one EVENT_POWER_UPDATE
-- registration per resource, filtered to it and to you), and dodge fatigue only while a tracker or rule uses it.
-- A predicted tick keeps the rhythm (the trusted time moves by whole periods) instead of restarting from the
-- frame that noticed it.
--
-- The period comes from the game, not from a constant (5.20.1; a tester: "about 300-400 ms off (late), same with all
-- of them", while the "+amount" -- the detected tick itself -- was "insanely accurate"): with a fixed 2.000 s the bar
-- was full before the real tick arrived. The time between two detected ticks in a row (or a whole number of periods
-- when some were missed: resource full, blocking) is measured, and the median of the last few is the period; 2 s
-- until three are known. Miat's windows scale with it (1.75 / 1.9-2.1 / +10 ms of a 2 s period).

local DT = DebuffTracker
local Tk = {}
DT.Ticks = Tk
local U = DT.Util

local NS = "DebuffTracker5_Tick_"
Tk.PERIOD = 2.0              -- until measured
Tk.IGNORE_BEFORE = 0.875     -- x period (1.75 s of 2) after a trusted tick: a same-size rise is not a tick...
Tk.PAIR_MIN, Tk.PAIR_MAX = 0.95, 1.05   -- ...unless with the ignored one before it it makes this (x period)
Tk.LATE = 0.01               -- s: no tick seen this long past the period: predicted
Tk.SAMPLES = 7               -- intervals kept for the measured period (median)
Tk.MIN_SAMPLES = 3
Tk.PERIOD_MIN, Tk.PERIOD_MAX = 1.8, 3.2   -- a measured interval outside this (per period) isn't one
Tk.FATIGUE_ID = 69143
Tk.GAIN_SHOWN = 1.5          -- {gain}: "+amount" for this long after a tick (Miat's pop-up)

local REGEN_STATS = {
    stamina = { "STAT_STAMINA_REGEN_COMBAT", "STAT_STAMINA_REGEN_IDLE" },
    magicka = { "STAT_MAGICKA_REGEN_COMBAT", "STAT_MAGICKA_REGEN_IDLE" },
    health = { "STAT_HEALTH_REGEN_COMBAT", "STAT_HEALTH_REGEN_IDLE" },
}
Tk.RESOURCES = REGEN_STATS

local state = {}        -- [resource] = { prev, trusted, wasTrusted, partial, amount, at, count }
local watched = {}      -- [resource] = true while registered
local fatigue, fatigueAt, fatigueWatched = 0, -100, false

-- your regen per tick right now (what a tick adds); 0 = none (e.g. stamina while blocking or sprinting)
function Tk.Regen(res)
    local s = REGEN_STATS[res]
    if not s or type(GetPlayerStat) ~= "function" then return 0 end
    local inCombat = type(IsUnitInCombat) == "function" and IsUnitInCombat("player") == true
    local stat = rawget(_G, inCombat and s[1] or s[2])
    if not stat then return 0 end
    return tonumber(GetPlayerStat(stat, STAT_BONUS_OPTION_APPLY_BONUS)) or 0
end

-- the period: the median of the measured intervals (2 s until there are enough)
local function Period(st)
    return st.period or Tk.PERIOD
end
function Tk.Period(res) local st = state[res]; return st and Period(st) or Tk.PERIOD end

-- a new detected tick `dt` s after the previous detected one: one period, or k of them (ticks missed in between)
local function Measure(st, dt)
    local p = Period(st)
    local k = math.max(1, math.floor(dt / p + 0.5))
    local one = dt / k
    if one < Tk.PERIOD_MIN or one > Tk.PERIOD_MAX or k > 5 then return end
    local s = st.samples
    s[#s + 1] = one
    if #s > Tk.SAMPLES then table.remove(s, 1) end
    if #s >= Tk.MIN_SAMPLES then
        local sorted = {}
        for i, v in ipairs(s) do sorted[i] = v end
        table.sort(sorted)
        local n = #sorted
        st.period = n % 2 == 1 and sorted[(n + 1) / 2] or (sorted[n / 2] + sorted[n / 2 + 1]) / 2
    end
end

-- past the period with no tick seen: the next one is predicted (whole periods, so the rhythm stays)
local function Advance(st, now)
    local p = Period(st)
    if st.trusted and now - st.trusted >= p + Tk.LATE then
        st.trusted = st.trusted + p * math.floor((now - st.trusted) / p)
        st.wasTrusted = false
    end
end

-- A tick that fills the resource up only adds what was missing: smaller than the regen stat (Yarden, 5.21.5: after a
-- reload the tracker only started "after I dodged a few times" -- out of combat one tick refills more than a dodge
-- costs, so every tick was a partial one until enough was missing; Miat's check has the same blind spot). A rise
-- that ends exactly at the maximum, and is no bigger than a tick, counts as one -- with the same 1.75 s guard as a
-- full-size tick, so a potion topping you up right after a tick isn't taken for one.
function Tk.OnPower(res, value, now, max)
    local st = state[res]
    if not st then return end
    now = now or U.Now()
    value = tonumber(value) or 0
    max = tonumber(max)
    Advance(st, now)
    if st.prev then
        local delta = value - st.prev
        local regen = Tk.Regen(res)
        local toppedUp = max and max > 0 and value >= max and delta > 0 and delta < regen
        if delta > 0 and (delta == regen or toppedUp) then
            local pairOk
            local ignore = false
            if st.trusted then
                local dt = now - st.trusted
                local p = Period(st)
                if st.partial then
                    local sum = st.partial.dt + (now - st.partial.at)
                    pairOk = sum > Tk.PAIR_MIN * p and sum < Tk.PAIR_MAX * p
                    st.partial = nil
                end
                if st.wasTrusted and dt < Tk.IGNORE_BEFORE * p and not pairOk then
                    ignore = true
                    if pairOk == nil then st.partial = { dt = dt, at = now } end
                end
            end
            if not ignore then
                if st.at then Measure(st, now - st.at) end
                if DT.debug then
                    U.Debug("tick %s +%d, %.3f s after the last (period %.3f s%s)", res, delta, st.at and (now - st.at) or 0,
                        Period(st), st.period and "" or ", not measured yet")
                end
                st.trusted, st.wasTrusted = now, true
                st.amount, st.at = delta, now
                st.count = st.count + 1
                if DT.Engine and DT.Engine.RequestUpdate then DT.Engine.RequestUpdate() end
            end
        end
    end
    st.prev = value
end

-- what a tracker shows: nil until the first tick was seen (no guessing the rhythm)
-- { start = the last (or predicted) tick, trusted, amount = last tick's gain, at = when, regen = per tick now }
function Tk.Info(res, now)
    local st = state[res]
    if not st or not st.trusted then return nil end
    Advance(st, now)
    return st
end

local function PowerTypeOf(res) return DT.Const.PowerConstant(res) end

local function Register(res)
    local pt = PowerTypeOf(res)
    local ns = NS .. res
    EVENT_MANAGER:RegisterForEvent(ns, EVENT_POWER_UPDATE, function(_, unitTag, _, powerType, value, powerMax)
        if unitTag and unitTag ~= "player" then return end
        if powerType ~= pt then return end
        Tk.OnPower(res, value, nil, powerMax)
    end)
    if REGISTER_FILTER_POWER_TYPE then
        EVENT_MANAGER:AddFilterForEvent(ns, EVENT_POWER_UPDATE, REGISTER_FILTER_POWER_TYPE, pt, REGISTER_FILTER_UNIT_TAG, "player")
    elseif REGISTER_FILTER_UNIT_TAG then
        EVENT_MANAGER:AddFilterForEvent(ns, EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")
    end
    -- the starting value (so the first rise can already be a tick)
    local cur = GetUnitPower("player", pt)
    state[res] = { prev = tonumber(cur), count = 0, samples = {} }
end

local function OnFatigue(_, result)
    local now = U.Now()
    if result == ACTION_RESULT_EFFECT_FADED then
        fatigue = 0
    elseif result == ACTION_RESULT_EFFECT_GAINED or result == ACTION_RESULT_EFFECT_GAINED_DURATION then
        -- a gain and a duration gain can come for the same dodge: one roll takes far longer than this
        if now - fatigueAt > 0.25 then fatigue = fatigue + 1 end
        fatigueAt = now
    else
        return
    end
    if DT.Engine and DT.Engine.RequestUpdate then DT.Engine.RequestUpdate() end
end

-- dodge fatigue stacks on you (0 when none)
function Tk.Fatigue() return fatigue end

-- resources = set of "stamina" / "magicka" / "health"; fatigueOn = a tracker / rule uses dodge fatigue
function Tk.SetWatched(resources, fatigueOn)
    if not EVENT_POWER_UPDATE then return end
    for res in pairs(watched) do
        if not resources[res] then
            EVENT_MANAGER:UnregisterForEvent(NS .. res, EVENT_POWER_UPDATE)
            watched[res], state[res] = nil, nil
        end
    end
    for res in pairs(resources) do
        if REGEN_STATS[res] and not watched[res] then
            Register(res)
            watched[res] = true
        end
    end
    fatigueOn = fatigueOn == true
    if fatigueOn ~= fatigueWatched then
        fatigueWatched = fatigueOn
        local ns = NS .. "Fatigue"
        if fatigueOn then
            EVENT_MANAGER:RegisterForEvent(ns, EVENT_COMBAT_EVENT, OnFatigue)
            EVENT_MANAGER:AddFilterForEvent(ns, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, Tk.FATIGUE_ID,
                REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
        else
            EVENT_MANAGER:UnregisterForEvent(ns, EVENT_COMBAT_EVENT)
            fatigue = 0
        end
    end
end

function Tk.IsWatched(res) return watched[res] == true end
function Tk.FatigueWatched() return fatigueWatched end

-- after a loading screen the old rhythm means nothing
function Tk.Reset()
    for res, st in pairs(state) do
        local cur = GetUnitPower("player", PowerTypeOf(res))
        -- (the measured period stays: it's the game's, not the area's)
        state[res] = { prev = tonumber(cur), count = 0, samples = st.samples, period = st.period }
    end
    fatigue = 0
end
