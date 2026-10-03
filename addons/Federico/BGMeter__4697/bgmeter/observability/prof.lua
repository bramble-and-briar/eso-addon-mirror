BGMeter = BGMeter or {}
local BGMeter = BGMeter

local K = BGMeter.Constants
local Prof = { on = false }
BGMeter.Prof = Prof

local NOOP = function() end
Prof.enter = NOOP
Prof.exit = NOOP
Prof.reset = NOOP
Prof.install = NOOP
Prof.wrap_table = NOOP
Prof.wrap_method = NOOP
Prof.span = function(_, fn, ...) return fn(...) end
Prof.wrap = function(_, fn) return fn end
Prof.report = function() return {}, 0 end
Prof.lines = function() return { "[prof] off (release build)" } end
Prof.budget_of = function() return nil end

if not (K and K.dev_tools and K.dev_tools()) then return end

Prof.on = true

local now = GetGameTimeMilliseconds
local gcc = collectgarbage
local math_floor = math.floor

local BOUNDS = { 0, 1, 2, 4, 8, 16, 32, 64, 128, 256 }
local NB = #BOUNDS
local MAX_STAGES = 256
local STACK_MAX = 32

local BUDGET = {
    ["up:BGMeterScoreSample"] = { ms = 4, kb = 1 },
    ["up:BGMeterPosSample"]   = { ms = 4, kb = 2 },
    ["up:BGMeterMeSample"]    = { ms = 2, kb = 1 },
    ["cap:on_kill"]           = { ms = 2, kb = 2 },
    ["cap:on_objective"]      = { ms = 2, kb = 2 },
    ["cap:on_flag"]           = { ms = 2, kb = 2 },
    ["cap:on_murderball"]     = { ms = 2, kb = 2 },
    ["cap:on_reticle_player"] = { ms = 1, kb = 1 },
    ["ev:BGMeter_Roster"]     = { ms = 4 },
    ["cap:finalize"]          = { ms = 250 },
    ["pub:publish"]           = { ms = 250 },
    ["ui:render"]             = { ms = 60, kb = 96 },
    ["tl:derive"]             = { ms = 40, kb = 800 },
    ["ui:show_match"]         = { ms = 80 },
    ["map:render"]            = { ms = 40, kb = 48 },
    ["map:scrub"]             = { ms = 8, kb = 8 },
    ["menu:refresh"]          = { ms = 30, kb = 64 },
    ["panel:refresh"]         = { ms = 10, kb = 16 },
}

local stages, order, nstages = {}, {}, 0
local stack = {}
local top = 0
local started = now()
local unbalanced = 0

local function stage(name)
    local s = stages[name]
    if s then return s end
    if nstages >= MAX_STAGES then return nil end
    s = { name = name, calls = 0, ms = 0, maxMs = 0, kb = 0, maxKb = 0, gc = 0, gcMs = 0, gcMax = 0, over = 0, b = {} }
    for i = 1, NB do s.b[i] = 0 end
    nstages = nstages + 1
    stages[name] = s
    order[nstages] = s
    return s
end

local function bucket(ms)
    for i = NB, 1, -1 do
        if ms >= BOUNDS[i] then return i end
    end
    return 1
end

local function fail(what, detail)
    unbalanced = unbalanced + 1
    local V = BGMeter.Validate
    if V and V.on then V.fail("prof." .. what, detail) end
end

function Prof.enter(name)
    if top >= STACK_MAX then
        fail("overflow", name)
        return
    end
    top = top + 1
    local f = stack[top]
    if not f then f = {}; stack[top] = f end
    f.name = name
    f.k0 = gcc("count")
    f.t0 = now()
end

function Prof.exit(name)
    if top == 0 then
        fail("unbalanced", "exit without enter: " .. tostring(name))
        return
    end
    local f = stack[top]
    if f.name ~= name then
        fail("unbalanced", "expected " .. tostring(f.name) .. " got " .. tostring(name))
        top = top - 1
        return
    end
    local dt = now() - f.t0
    local dk = gcc("count") - f.k0
    top = top - 1
    local s = stage(name)
    if not s then return end
    s.calls = s.calls + 1
    s.ms = s.ms + dt
    if dk < 0 then
        s.gc = s.gc + 1
        s.gcMs = s.gcMs + dt
        if dt > s.gcMax then s.gcMax = dt end
        return
    end
    if dt > s.maxMs then s.maxMs = dt end
    local bi = bucket(dt)
    s.b[bi] = s.b[bi] + 1
    s.kb = s.kb + dk
    if dk > s.maxKb then s.maxKb = dk end
    local bud = BUDGET[name]
    if bud and ((bud.ms and dt > bud.ms) or (bud.kb and dk > bud.kb)) then
        s.over = s.over + 1
    end
end

function Prof.span(name, fn, ...)
    Prof.enter(name)
    local ok, r1, r2, r3, r4 = pcall(fn, ...)
    Prof.exit(name)
    if not ok then error(r1, 0) end
    return r1, r2, r3, r4
end

function Prof.wrap(name, fn)
    if type(fn) ~= "function" then return fn end
    return function(...)
        Prof.enter(name)
        local ok, r1, r2, r3, r4, r5, r6 = pcall(fn, ...)
        Prof.exit(name)
        if not ok then error(r1, 0) end
        return r1, r2, r3, r4, r5, r6
    end
end

function Prof.wrap_table(tbl, prefix, keys)
    if type(tbl) ~= "table" then return end
    tbl._prof_wrapped = tbl._prof_wrapped or {}
    for i = 1, #keys do
        local k = keys[i]
        if type(tbl[k]) == "function" and not tbl._prof_wrapped[k] then
            tbl[k] = Prof.wrap(prefix .. k, tbl[k])
            tbl._prof_wrapped[k] = true
        end
    end
end

function Prof.wrap_method(tbl, key, prefix, namer)
    if type(tbl) ~= "table" or type(tbl[key]) ~= "function" then return end
    tbl._prof_wrapped = tbl._prof_wrapped or {}
    if tbl._prof_wrapped[key] then return end
    local fn = tbl[key]
    tbl[key] = function(self, ...)
        local name = self._prof_name
        if not name then
            name = prefix .. tostring(namer(self))
            self._prof_name = name
        end
        Prof.enter(name)
        local ok, r1, r2, r3, r4 = pcall(fn, self, ...)
        Prof.exit(name)
        if not ok then error(r1, 0) end
        return r1, r2, r3, r4
    end
    tbl._prof_wrapped[key] = true
end

function Prof.budget_of(name) return BUDGET[name] end

function Prof.reset()
    for i = 1, nstages do
        local s = order[i]
        s.calls, s.ms, s.maxMs, s.kb, s.maxKb, s.gc, s.gcMs, s.gcMax, s.over = 0, 0, 0, 0, 0, 0, 0, 0, 0
        for j = 1, NB do s.b[j] = 0 end
    end
    top = 0
    unbalanced = 0
    started = now()
end

local function percentile(s, p)
    local clean = s.calls - s.gc
    if clean <= 0 then return 0 end
    local target = clean * p
    local cum = 0
    for i = 1, NB do
        cum = cum + s.b[i]
        if cum >= target then return BOUNDS[i] end
    end
    return BOUNDS[NB]
end

function Prof.report()
    local r = {}
    for i = 1, nstages do
        local s = order[i]
        if s.calls > 0 then
            r[s.name] = { calls = s.calls, ms = s.ms, maxMs = s.maxMs, p50 = percentile(s, 0.5), p95 = percentile(s, 0.95),
                          kb = s.kb, maxKb = s.maxKb, gc = s.gc, gcMs = s.gcMs, gcMax = s.gcMax, over = s.over, budget = BUDGET[s.name] }
        end
    end
    return r, (now() - started) / 1000
end

function Prof.lines()
    local r, secs = Prof.report()
    local names = {}
    for name in pairs(r) do names[#names + 1] = name end
    table.sort(names, function(a, b)
        local x, y = r[a], r[b]
        if x.ms ~= y.ms then return x.ms > y.ms end
        return x.kb > y.kb
    end)
    local L = { string.format("--- profiler  ·  %.0fs window  ·  %d stages  ·  %d unbalanced  ·  calls that saw a GC step count in gc and gc max, not in p50/p95/max ---", secs, #names, unbalanced) }
    L[#L + 1] = "  stage                       calls   total ms   p50   p95   max      KB   avg B   worst KB  gc  gc max  over"
    for _, name in ipairs(names) do
        local s = r[name]
        local budget = s.budget and string.format("%d/%s%s", s.over, s.budget.ms and (s.budget.ms .. "ms") or "-", s.budget.kb and ("," .. s.budget.kb .. "KB") or "") or "-"
        local clean = s.calls - s.gc
        L[#L + 1] = string.format("  %-26s %6d  %8d  %4d  %4d  %4d  %7.1f  %6.0f  %8.1f  %2d  %6d  %s",
            name, s.calls, s.ms, s.p50, s.p95, s.maxMs, s.kb, (clean > 0) and (s.kb * 1024 / clean) or 0, s.maxKb, s.gc, s.gcMax, budget)
    end
    if #names == 0 then L[#L + 1] = "  (no stage has run yet)" end
    local pools = BGMeter.Plot and BGMeter.Plot.pool and BGMeter.Plot.pool.all and BGMeter.Plot.pool.all() or {}
    if #pools > 0 then
        local warm = BGMeter.UI and BGMeter.UI.warmup
        L[#L + 1] = string.format("--- pools  ·  %d  ·  warm-up %s ---", #pools,
            warm and (warm.done and string.format("done, %d reserved in %d ticks", warm.made, warm.ticks) or (warm.running and "running" or "not started")) or "n/a")
        L[#L + 1] = "  pool                  created   active"
        for _, p in ipairs(pools) do
            if p.created > 0 then
                L[#L + 1] = string.format("  %-20s %8d  %7d", tostring(p.label), p.created, p:active_count())
            end
        end
    end
    return L
end

local installed = {}

function Prof.install()
    local function once(key, fn)
        if installed[key] then return end
        installed[key] = true
        fn()
    end
    once("capture", function()
        Prof.wrap_table(BGMeter.Capture, "cap:", { "begin", "finalize", "read_battle", "rescan", "on_kill", "on_objective", "on_flag", "on_murderball", "on_reticle_player", "on_ap", "on_xp", "on_cp", "on_reward_track" })
    end)
    once("match", function()
        Prof.wrap_table(BGMeter.Match, "match:", { "geo", "geo_heat", "geo_heat_deaths", "damage_race", "balance", "surrender", "experience", "flag_lanes", "relic_lanes", "combat_momentum", "kill_pressure", "pack_timeline", "derive" })
    end)
    once("publish", function()
        local P = BGMeter.Pipeline and BGMeter.Pipeline.presentation
        if P then Prof.wrap_table(P, "pub:", { "publish" }) end
        Prof.wrap_table(BGMeter.History, "pub:history.", { "push", "delete" })
        Prof.wrap_table(BGMeter.Faces, "pub:faces.", { "record", "backfill", "backfill_kills" })
        Prof.wrap_table(BGMeter.Ledger, "pub:ledger.", { "record", "backfill", "backfill_balance" })
        Prof.wrap_table(BGMeter.Records, "pub:records.", { "evaluate" })
        Prof.wrap_table(BGMeter.Session, "pub:session.", { "record" })
        Prof.wrap_table(BGMeter.Standing, "pub:standing.", { "request", "on_data" })
        Prof.wrap_table(BGMeter.Storage, "storage:", { "report", "estimate" })
    end)
    local UI = BGMeter.UI
    if UI and UI.window and installed.window ~= UI.window then
        installed.window = UI.window
        Prof.wrap_table(UI.window, "ui:", { "render", "render_detail", "show_match", "refresh_if_visible" })
        if type(UI.window._sections) == "table" then
            local keys = {}
            for k, fn in pairs(UI.window._sections) do if type(fn) == "function" then keys[#keys + 1] = k end end
            Prof.wrap_table(UI.window._sections, "sec:", keys)
        end
    end
    if UI and UI.map and installed.map ~= UI.map then
        installed.map = UI.map
        Prof.wrap_table(UI.map, "map:", { "render", "set_time", "open", "on_report_render" })
    end
    if UI and UI.menu and installed.menu ~= UI.menu then
        installed.menu = UI.menu
        Prof.wrap_table(UI.menu, "menu:", { "refresh", "show_menu", "refresh_if_visible" })
        if UI.panel then Prof.wrap_table(UI.panel, "panel:", { "refresh" }) end
        if UI.Drawer then
            Prof.wrap_method(UI.Drawer, "refresh", "drawer:", function(self) return self.key end)
            Prof.wrap_method(UI.Drawer, "fetch", "fetch:", function(self) return self.key end)
        end
    end
end
