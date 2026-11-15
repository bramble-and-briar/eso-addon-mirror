-- General helpers with no game-state dependencies (safe to call from anywhere, including tests).

local DT = DebuffTracker
local U = DT.Util

------------------------------------------------------------------------------
-- Tables
------------------------------------------------------------------------------

function U.Copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[U.Copy(k)] = U.Copy(v) end
    return out
end

-- Fills keys missing from `t` with (copies of) `defaults`, recursively. Never overwrites a value the
-- user has, never deletes unknown keys. Lists in defaults are only copied when missing entirely.
function U.ApplyDefaults(t, defaults)
    for k, dv in pairs(defaults) do
        local tv = t[k]
        if tv == nil then
            t[k] = U.Copy(dv)
        elseif type(tv) == "table" and type(dv) == "table" and not U.IsList(dv) then
            U.ApplyDefaults(tv, dv)
        end
    end
    return t
end

function U.IsList(t)
    if type(t) ~= "table" then return false end
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n == #t
end

function U.Count(t)
    local n = 0
    if t then for _ in pairs(t) do n = n + 1 end end
    return n
end

function U.SortedKeys(t, cmp)
    local keys = {}
    for k in pairs(t or {}) do keys[#keys + 1] = k end
    table.sort(keys, cmp or function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

function U.Set(list)
    local s = {}
    for _, v in ipairs(list or {}) do s[v] = true end
    return s
end

function U.Contains(list, value)
    for _, v in ipairs(list or {}) do if v == value then return true end end
    return false
end

function U.RemoveValue(list, value)
    for i = #list, 1, -1 do if list[i] == value then table.remove(list, i) end end
end

function U.IndexOf(list, value)
    for i, v in ipairs(list or {}) do if v == value then return i end end
    return nil
end

------------------------------------------------------------------------------
-- Strings / numbers
------------------------------------------------------------------------------

function U.Trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function U.Lower(s)
    s = tostring(s or "")
    if type(zo_strlower) == "function" then return zo_strlower(s) end
    return s:lower()
end

function U.Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function U.Round(v, step)
    step = step or 1
    return math.floor(v / step + 0.5) * step
end

-- "12, 34;56 abc 78" -> {12, 34, 56, 78} (unique, in order)
function U.ParseIds(text)
    local ids, seen = {}, {}
    for d in tostring(text or ""):gmatch("%d+") do
        local n = tonumber(d)
        if n and n > 0 and not seen[n] then seen[n] = true; ids[#ids + 1] = n end
    end
    return ids
end

-- "Major Breach, Off Balance" -> {"major breach", "off balance"}
function U.ParseNames(text)
    local names, seen = {}, {}
    for part in tostring(text or ""):gmatch("[^,;\n]+") do
        local n = U.Lower(U.Trim(part))
        if n ~= "" and not n:match("^%d+$") and not seen[n] then seen[n] = true; names[#names + 1] = n end
    end
    return names
end

function U.JoinList(list, sep)
    local parts = {}
    for i, v in ipairs(list or {}) do parts[i] = tostring(v) end
    return table.concat(parts, sep or ", ")
end

-- Clean an effect/unit name from the game (strips gender/grammar markup like "^M" / "^n").
function U.CleanName(name)
    name = tostring(name or "")
    if type(zo_strformat) == "function" then
        local ok, r = pcall(zo_strformat, "<<C:1>>", name)
        if ok and r then return r end
    end
    return (name:gsub("%^%w+", ""))
end

------------------------------------------------------------------------------
-- Time
------------------------------------------------------------------------------

-- fmt: "auto" (tenths under 10s), "tenths", "seconds", "mmss"
function U.FormatTime(seconds, fmt)
    if not seconds then return "" end
    if seconds < 0 then seconds = 0 end
    fmt = fmt or "auto"
    if fmt == "tenths" or (fmt == "auto" and seconds < 10) then
        return string.format("%.1f", seconds)
    elseif fmt == "seconds" or (fmt == "auto" and seconds < 60) then
        return string.format("%d", math.floor(seconds + 0.5))
    else
        local s = math.floor(seconds + 0.5)
        return string.format("%d:%02d", math.floor(s / 60), s % 60)
    end
end

function U.Now()
    return GetGameTimeSeconds()
end

------------------------------------------------------------------------------
-- Colors: {r, g, b, a} tables in 0..1
------------------------------------------------------------------------------

function U.ColorToHex(c)
    c = c or { 1, 1, 1, 1 }
    local function h(v) return string.format("%02X", U.Clamp(math.floor((v or 0) * 255 + 0.5), 0, 255)) end
    return h(c[1]) .. h(c[2]) .. h(c[3]) .. h(c[4] or 1)
end

function U.HexToColor(hex)
    hex = tostring(hex or ""):gsub("#", "")
    if not hex:match("^%x%x%x%x%x%x$") and not hex:match("^%x%x%x%x%x%x%x%x$") then return nil end
    local function c(i) return tonumber(hex:sub(i, i + 1), 16) / 255 end
    return { c(1), c(3), c(5), #hex == 8 and c(7) or 1 }
end

function U.LerpColor(a, b, t)
    return {
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
        a[3] + (b[3] - a[3]) * t,
        (a[4] or 1) + ((b[4] or 1) - (a[4] or 1)) * t,
    }
end

------------------------------------------------------------------------------
-- Text templates: "{name} on {unit} - {time}"
------------------------------------------------------------------------------

U.ROLE_ICONS = {
    dps = "/esoui/art/lfg/lfg_icon_dps.dds",
    tank = "/esoui/art/lfg/lfg_icon_tank.dds",
    healer = "/esoui/art/lfg/lfg_icon_healer.dds",
}

local TOKEN_FUNCS = {
    name = function(s) return s.name or "" end,
    unit = function(s) return s.unitName or "" end,
    stacks = function(s) return (s.stacks and (s.stacks > 1 or s.allStacks)) and tostring(s.stacks) or "" end,
    source = function(s) return s.sourceName or "" end,
    value = function(s) return s.value and tostring(math.floor(s.value + 0.5)) or "" end,
    max = function(s) return s.max and tostring(math.floor(s.max + 0.5)) or "" end,
    pct = function(s) return s.pct and string.format("%d%%", math.floor(s.pct + 0.5)) or "" end,
    id = function(s) return s.abilityId and tostring(s.abilityId) or "" end,
    calc = function(s) return s.calcText or "" end,
    info = function(s) return s.info and string.format(s.info < 100 and "%.1f" or "%d", s.info) or "" end,
    allies = function(s) return (s.allies and s.allies > 0) and tostring(s.allies) or "" end,
    -- an ally's account name (@name) -- BuffTheGroup lists the group by account
    account = function(s)
        if not s.unitTag or type(GetUnitDisplayName) ~= "function" then return "" end
        local n = GetUnitDisplayName(s.unitTag)
        if n == nil or n == "" then return s.unitName or "" end
        return n
    end,
    -- the group finder role icon of an ally (tank / healer / damage), as inline text
    roleicon = function(s)
        local role = s.unitTag and DT.Conditions and DT.Conditions.UnitRole(s) or ""
        local tex = U.ROLE_ICONS[role]
        return tex and ("|t20:20:" .. tex .. "|t") or ""
    end,
    -- the stat trackers' breakdown ("Major Breach 5948, Crusher 2108")
    detail = function(s) return s.detail or "" end,
    -- resource ticks: "+amount" for a moment after a tick (Miat's pop-up), the fill to the next tick
    gain = function(s)
        if s.gain and s.gainAt and U.Now() - s.gainAt < (DT.Ticks and DT.Ticks.GAIN_SHOWN or 1.5) then
            return "+" .. tostring(math.floor(s.gain + 0.5))
        end
        return ""
    end,
    fill = function(s)
        if s.fillUp and (s.duration or 0) > 0 then
            return string.format("%d%%", math.floor(U.Clamp((U.Now() - s.start) / s.duration, 0, 1) * 100))
        end
        return ""
    end,
    phase = function(s)
        if s.cooldown then return DT.L("cooldown") end
        if s.ready then return DT.L("ready") end
        return ""
    end,
}

-- (no closure per call: the label of every entry is formatted at every update)
local fState, fNow, fFmt
local function Token(token)
    local state, now, timeFmt = fState, fNow, fFmt
    if token == "time" then
        if state.expire and state.expire > 0 and (state.duration or 0) > 0 then
            return U.FormatTime(state.expire - now, timeFmt)
        end
        return ""
    elseif token == "elapsed" then
        return state.start and U.FormatTime(now - state.start, timeFmt) or ""
    elseif token == "duration" then
        return state.duration and state.duration > 0 and U.FormatTime(state.duration, timeFmt) or ""
    end
    local f = TOKEN_FUNCS[token]
    return f and f(state) or ("{" .. token .. "}")
end
-- a template that is one token and nothing else ("{name}", the default): that token's text directly
local single = {}
function U.FormatTemplate(template, state, now, timeFmt)
    template = template or "{name}"
    local one = single[template]
    if one == nil then
        one = template:match("^{(%w+)}$") or false
        single[template] = one
    end
    fState, fNow, fFmt = state, now, timeFmt
    if one then
        local r = Token(one)
        fState = nil
        return tostring(r)
    end
    local r = template:gsub("{(%w+)}", Token)
    fState = nil
    return r
end

------------------------------------------------------------------------------
-- Ids, logging, safety
------------------------------------------------------------------------------

local idCounter = 0
function U.NewId(prefix)
    idCounter = idCounter + 1
    local stamp = type(GetTimeStamp) == "function" and GetTimeStamp() or 0
    return string.format("%s%x%x", prefix or "t", stamp, idCounter)
end

function U.Print(message)
    d("|cF3D27ADebuffTracker|r " .. tostring(message))
end

-- Debug lines go to chat AND to a log kept in the saved variables (last LOG_MAX lines), so they can
-- be copied in game ("/dt log") or sent as the SavedVariables file after /reloadui.
local LOG_MAX = 3000
U.debugLog = nil        -- set to the saved-variables list at start-up
function U.Debug(fmt, ...)
    if DT.debug then
        local ok, msg = pcall(string.format, fmt, ...)
        msg = ok and msg or tostring(fmt)
        d("|c7FB2E5[DT debug]|r " .. msg)
        local log = U.debugLog
        if log then
            local t = type(GetTimeString) == "function" and GetTimeString() or ""
            log[#log + 1] = string.format("%s %.2f %s", t, U.Now(), msg)
            -- trimmed in chunks: table.remove(log, 1) moved all 3000 lines for EVERY new line (a trial
            -- logs hundreds a second while debugging)
            if #log > LOG_MAX + 500 then
                local n, drop = #log, #log - LOG_MAX
                for i = 1, n - drop do log[i] = log[i + drop] end
                for i = n, n - drop + 1, -1 do log[i] = nil end
            end
        end
    end
end

-- Runs fn; on error reports once per key (so a broken user template can't spam chat every tick).
local reported = {}
function U.SafeCall(key, fn, ...)
    local ok, a, b, c = pcall(fn, ...)
    if not ok then
        if not reported[key] then
            reported[key] = true
            U.Print("|cFF6060error|r in " .. tostring(key) .. ": " .. tostring(a))
        end
        return nil
    end
    return a, b, c
end
