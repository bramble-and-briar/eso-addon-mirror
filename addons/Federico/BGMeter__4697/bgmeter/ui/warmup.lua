BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.UI = BGMeter.UI or {}

local Warm = { done = false, running = false, made = 0, ticks = 0 }

local NAME = "BGMeterWarmup"
local TICK_MS = 50
local BUSY_MS = 1000
local STEP = 8
local rate = 0

local function set_rate(ms)
    if rate == ms then return end
    local E = BGMeter.zenimax.events
    if rate ~= 0 then E.unregister_update(NAME) end
    rate = ms
    E.register_update(NAME, ms, function() Warm.tick_now() end)
end

local TARGETS = {
    { "row_pool",       "battle.rows",   18,   8 },
    { "dot_pool",       "chart.rects",   600,  1 },
    { "line_pool",      "chart.lines",   700,  1 },
    { "skull_pool",     "chart.skulls",  40,   1 },
    { "ribbon_pool",    "ribbon.rects",  260,  1 },
    { "pin_pool",       "ribbon.pins",   60,   1 },
    { "occ_pool",       "occupation",    12,   1 },
    { "race_pool",      "race.fill",     650,  1 },
    { "race_line_pool", "race.lines",    800,  1 },
    { "mom_pool",       "momentum",      160,  1 },
    { "kills_pool",     "kills",         220,  1 },
    { "hit_pool",       "hits",          220,  2 },
    { "line_pool",      "map.path",      1500, 1, "map" },
    { "team_pool",      "map.team",      1700, 1, "map" },
    { "tc_line_pool",   "map.score",     740,  1, "map" },
    { "tc_cohesion",    "map.cohesion",  250,  1, "map" },
    { "tc_solo",        "map.solo",      250,  1, "map" },
    { "tc_kills",       "map.kills",     740,  1, "map" },
    { "tc_base",        "map.base",      250,  1, "map" },
    { "tc_control",     "map.control",   250,  1, "map" },
    { "icon_pool",      "map.icons",     64,   1, "map" },
    { "hit_pool",       "map.hits",      64,   2, "map" },
    { "heat_pool",      "map.heat",      1024, 1, "map" },
}

local function pool_of(t)
    if t[5] == "map" then
        local MapUI = BGMeter.UI.map
        local mc = MapUI and MapUI.controls and MapUI.controls()
        return mc and mc[t[1]] or nil
    end
    local W = BGMeter.UI.window
    return W and W.battle and W.battle[t[1]] or nil
end

Warm.TARGETS = TARGETS
Warm.STEP = STEP

function Warm.take(need, weight, budget)
    if need <= 0 or budget < weight then return 0 end
    local n = math.floor(budget / weight)
    if n > need then n = need end
    return n
end

local function label_pools()
    for _, t in ipairs(TARGETS) do
        local pool = pool_of(t)
        if pool then pool.label = t[2] end
    end
end

local function busy()
    local W = BGMeter.UI.window
    if BGMeter.Capture and BGMeter.Capture.is_active() then return true end
    if W and W.in_combat and W.in_combat() then return true end
    return false
end

local function finish()
    BGMeter.zenimax.events.unregister_update(NAME)
    rate = 0
    Warm.running = false
    Warm.done = true
    BGMeter.Log.debug("warm-up done: %d controls reserved in %d ticks", Warm.made, Warm.ticks)
end

local function tick()
    if busy() then
        set_rate(BUSY_MS)
        return
    end
    set_rate(TICK_MS)
    local W = BGMeter.UI.window
    if not (W and W.battle) then finish() return end
    Warm.ticks = Warm.ticks + 1
    local budget = STEP
    local pending = false
    for _, t in ipairs(TARGETS) do
        local pool = pool_of(t)
        if pool then
            local need = t[3] - pool:total()
            if need > 0 then
                local n = Warm.take(need, t[4] or 1, budget)
                if n > 0 then
                    Warm.made = Warm.made + pool:reserve(pool:total() + n)
                    budget = budget - n * (t[4] or 1)
                end
                if need > n then pending = true end
                if budget <= 0 then return end
            end
        end
    end
    if pending then return end
    finish()
end

function Warm.start()
    if Warm.done or Warm.running then return end
    local W = BGMeter.UI.window
    if not (W and W.ensure_built) then return end
    W.ensure_built()
    if not W.battle then return end
    local MapUI = BGMeter.UI.map
    if MapUI and MapUI.ensure_built then MapUI.ensure_built() end
    label_pools()
    Warm.running = true
    set_rate(TICK_MS)
end

function Warm.tick_now() tick() end

function Warm.rate() return rate end

function Warm.reset()
    if Warm.running then BGMeter.zenimax.events.unregister_update(NAME) end
    rate = 0
    Warm.done, Warm.running, Warm.made, Warm.ticks = false, false, 0, 0
end

BGMeter.UI.warmup = Warm
