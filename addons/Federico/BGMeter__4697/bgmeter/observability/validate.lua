BGMeter = BGMeter or {}
local BGMeter = BGMeter

local K = BGMeter.Constants
local Val = { on = false }
BGMeter.Validate = Val

local NOOP = function() end
Val.fail = NOOP
Val.reset = NOOP
Val.check = function(cond) return cond end
Val.monotonic = NOOP
Val.cap = NOOP
Val.finite = NOOP
Val.roundtrip = NOOP
Val.pool = NOOP
Val.count = function() return 0 end
Val.lines = function() return { "[validate] off (release build)" } end

if not (K and K.dev_tools and K.dev_tools()) then return end

Val.on = true

local now = GetGameTimeMilliseconds
local MAX_FAILURES = 200
local MAX_NODES = 250000

local failures, nfail = {}, 0
local counts = {}
local ncounts = 0

function Val.fail(name, detail)
    local c = counts[name]
    if not c then
        c = { name = name, n = 0 }
        counts[name] = c
        ncounts = ncounts + 1
    end
    c.n = c.n + 1
    if nfail < MAX_FAILURES then
        nfail = nfail + 1
        failures[nfail] = { t = now(), name = name, detail = detail and tostring(detail) or "" }
    end
    local Log = BGMeter.Log
    if Log and Log.debug then Log.debug("validate %s: %s", tostring(name), tostring(detail)) end
end

function Val.check(cond, name, detail)
    if not cond then Val.fail(name, detail) end
    return cond
end

function Val.monotonic(label, prev, cur)
    if prev ~= nil and cur ~= nil and cur < prev then
        Val.fail("clock." .. label, string.format("%s -> %s", tostring(prev), tostring(cur)))
    end
end

function Val.cap(label, n, cap)
    if n and cap and n > cap then
        Val.fail("cap." .. label, string.format("%d > %d", n, cap))
    end
end

function Val.pool(label, active, cap)
    if active and cap and active > cap then
        Val.fail("pool." .. label, string.format("%d active > %d", active, cap))
    end
end

local function walk(label, t, depth, seen, budget)
    if budget.n <= 0 then return end
    for k, v in pairs(t) do
        budget.n = budget.n - 1
        local tv = type(v)
        if tv == "number" then
            if v ~= v or v == math.huge or v == -math.huge then
                Val.fail("finite." .. label, tostring(k) .. " at depth " .. depth)
            end
        elseif tv == "table" and depth < 8 and not seen[v] then
            seen[v] = true
            walk(label, v, depth + 1, seen, budget)
        end
        if budget.n <= 0 then
            Val.fail("finite.budget", label)
            return
        end
    end
end

function Val.finite(label, t)
    if type(t) ~= "table" then return end
    walk(label, t, 0, { [t] = true }, { n = MAX_NODES })
end

function Val.roundtrip(label, m)
    local Match = BGMeter.Match
    local tl = m and m.timeline
    if not (Match and tl and tl.t) then return end
    local n = #tl.t
    local checked = 0
    for nm, rec in pairs(tl.p or {}) do
        if type(rec.d) == "table" then
            local packed = Match.pack_series(rec.d, n)
            local back = Match.unpack_series(packed, n)
            for i = 1, n do
                local a, b = rec.d[i] or 0, back[i] or 0
                if math.abs(a - b) > 1 then
                    Val.fail("codec." .. label, string.format("%s[%d] %s vs %s", tostring(nm), i, tostring(a), tostring(b)))
                    break
                end
            end
            checked = checked + 1
        end
    end
    if tl.mt and type(tl.mx) == "table" and type(tl.mx[1]) == "number" then
        local mn = #tl.mt
        local back = Match.unpack_series(Match.pack_series(tl.mx, mn), mn)
        for i = 1, mn do
            if math.abs((tl.mx[i] or 0) - (back[i] or 0)) > 1 then
                Val.fail("codec." .. label, string.format("mx[%d] %s vs %s", i, tostring(tl.mx[i]), tostring(back[i])))
                break
            end
        end
        checked = checked + 1
    end
    return checked
end

function Val.count() return nfail end

function Val.reset()
    failures, nfail = {}, 0
    counts, ncounts = {}, 0
end

function Val.lines()
    local L = { string.format("--- validation  ·  %d failures  ·  %d checks tripped ---", nfail, ncounts) }
    local names = {}
    for name in pairs(counts) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        L[#L + 1] = string.format("  %-28s %d", name, counts[name].n)
    end
    local from = math.max(1, nfail - 19)
    for i = from, nfail do
        local f = failures[i]
        L[#L + 1] = string.format("  t=%d  %s  %s", f.t, f.name, f.detail)
    end
    if nfail == 0 then L[#L + 1] = "  (nothing tripped)" end
    return L
end
