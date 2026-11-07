--[[
    LibFights - Util
    Generic helpers: time, formatting, safe API calls, ring buffers, table tools.
]]

local LF = LibFights
local Util = {}
LF.Util = Util

local floor, abs = math.floor, math.abs
local sformat, slower, sfind = string.format, string.lower, string.find
local GetGameTimeMilliseconds = GetGameTimeMilliseconds

-- Time --------------------------------------------------------------------------
function Util.Now()
    return GetGameTimeMilliseconds()
end

function Util.Timestamp()
    return GetTimeStamp()
end

-- Math ----------------------------------------------------------------------------
function Util.Round(v, decimals)
    if v == nil then return 0 end
    local m = 10 ^ (decimals or 0)
    return floor(v * m + 0.5) / m
end

function Util.Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function Util.SafeDiv(a, b)
    if not b or b == 0 then return 0 end
    return (a or 0) / b
end

-- Safe API calls --------------------------------------------------------------------
local function pack(...)
    return { n = select("#", ...), ... }
end

-- Calls a function value safely. Returns nothing on error or if it is not a function.
function Util.Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local r = pack(pcall(fn, ...))
    if not r[1] then return nil end
    return unpack(r, 2, r.n)
end

-- Calls a global function by name safely (handles API differences between versions).
function Util.SafeCall(fnName, ...)
    return Util.Try(_G[fnName], ...)
end

function Util.Global(name)
    return _G[name]
end

-- Strings ---------------------------------------------------------------------------
function Util.Lower(s)
    if s == nil then return "" end
    return slower(tostring(s))
end

function Util.Contains(haystack, needle)
    if not haystack or not needle or needle == "" then return false end
    return sfind(slower(haystack), slower(needle), 1, true) ~= nil
end

function Util.Trim(s)
    if not s then return "" end
    return (tostring(s):gsub("^%s+", ""):gsub("%s+$", ""))
end

function Util.Fmt(s)
    if s == nil or s == "" then return "" end
    if type(zo_strformat) == "function" then
        local ok, r = pcall(zo_strformat, "<<1>>", s)
        if ok and r then return r end
    end
    return s
end

local nameCache, nameCacheSize = {}, 0
function Util.CleanName(name)
    if name == nil or name == "" then return "" end
    local c = nameCache[name]
    if c then return c end
    local clean = name
    if type(zo_strformat) == "function" and SI_UNIT_NAME then
        local ok, r = pcall(zo_strformat, SI_UNIT_NAME, name)
        if ok and r then clean = r end
    end
    if nameCacheSize > 4000 then nameCache, nameCacheSize = {}, 0 end
    nameCache[name] = clean
    nameCacheSize = nameCacheSize + 1
    return clean
end

function Util.CleanAbilityName(name)
    if name == nil or name == "" then return "" end
    if type(zo_strformat) == "function" and SI_ABILITY_NAME then
        local ok, r = pcall(zo_strformat, SI_ABILITY_NAME, name)
        if ok and r then return r end
    end
    return name
end

-- Normalises a name for loose matching ("Perfected Kinras's Wrath" -> "kinrass wrath")
function Util.NormalizeName(name)
    local s = slower(Util.Fmt(name or ""))
    s = s:gsub("^perfected%s+", "")
    s = s:gsub("[%p]", "")
    s = s:gsub("%s+", " ")
    return Util.Trim(s)
end

-- Number formatting -------------------------------------------------------------------
function Util.FormatNumber(n)
    n = n or 0
    local a = abs(n)
    if a >= 1e9 then return sformat("%.2fB", n / 1e9) end
    if a >= 1e6 then return sformat("%.2fM", n / 1e6) end
    if a >= 1e4 then return sformat("%.1fk", n / 1e3) end
    return sformat("%.0f", n)
end

function Util.CommaNumber(n)
    n = floor((n or 0) + 0.5)
    if type(ZO_CommaDelimitNumber) == "function" then
        return ZO_CommaDelimitNumber(n)
    end
    return tostring(n)
end

function Util.FormatPct(v, decimals)
    return sformat("%." .. (decimals or 1) .. "f%%", (v or 0) * 100)
end

function Util.FormatDuration(ms)
    ms = ms or 0
    local totalSec = ms / 1000
    local m = floor(totalSec / 60)
    local s = totalSec - m * 60
    return sformat("%d:%04.1f", m, s)
end

-- Icons / texture markup --------------------------------------------------------------
function Util.IconMarkup(path, size)
    if not path or path == "" then return "" end
    size = size or 20
    return sformat("|t%d:%d:%s|t", size, size, path)
end

-- Tables ------------------------------------------------------------------------------------
function Util.Count(t)
    local n = 0
    if t then for _ in pairs(t) do n = n + 1 end end
    return n
end

function Util.ShallowCopy(t)
    local c = {}
    if t then for k, v in pairs(t) do c[k] = v end end
    return c
end

-- Deep copy into plain data: drops functions, metatables and keys starting with "_".
function Util.ToPlain(v, seen)
    local tv = type(v)
    if tv ~= "table" then
        if tv == "function" or tv == "userdata" or tv == "thread" then return nil end
        return v
    end
    seen = seen or {}
    if seen[v] then return nil end
    seen[v] = true
    local out = {}
    for k, val in pairs(v) do
        if not (type(k) == "string" and k:sub(1, 1) == "_") then
            local pv = Util.ToPlain(val, seen)
            if pv ~= nil then out[k] = pv end
        end
    end
    seen[v] = nil
    return out
end

function Util.SortedValues(map, field, descending, limit)
    local arr = {}
    for _, v in pairs(map or {}) do arr[#arr + 1] = v end
    table.sort(arr, function(a, b)
        local x, y = a[field] or 0, b[field] or 0
        if descending then return x > y end
        return x < y
    end)
    if limit and #arr > limit then
        for i = #arr, limit + 1, -1 do arr[i] = nil end
    end
    return arr
end

function Util.SortedKeys(map)
    local keys = {}
    for k in pairs(map or {}) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

-- Ring buffer (fixed capacity, overwrites oldest) ------------------------------------------
local Ring = {}
Ring.__index = Ring
Util.RingClass = Ring

function Util.NewRing(capacity)
    return setmetatable({ cap = math.max(1, capacity or 100), head = 0, count = 0, items = {} }, Ring)
end

function Ring:Push(v)
    self.head = (self.head % self.cap) + 1
    self.items[self.head] = v
    if self.count < self.cap then self.count = self.count + 1 end
end

-- i = 1 is the oldest entry, i = count the newest
function Ring:Get(i)
    if i < 1 or i > self.count then return nil end
    local start = self.head - self.count + 1
    return self.items[((start + i - 2) % self.cap) + 1]
end

function Ring:Newest()
    if self.count == 0 then return nil end
    return self.items[self.head]
end

function Ring:Count()
    return self.count
end

function Ring:ToArray()
    local t = {}
    for i = 1, self.count do t[i] = self:Get(i) end
    return t
end

-- newest n entries, oldest first
function Ring:Last(n)
    local t = {}
    local from = math.max(1, self.count - n + 1)
    for i = from, self.count do t[#t + 1] = self:Get(i) end
    return t
end

function Ring:Clear()
    self.head, self.count, self.items = 0, 0, {}
end

-- Restores ring metatable on plain data loaded from SavedVariables
function Util.RestoreRing(data)
    if type(data) ~= "table" then return nil end
    if data.cap and data.items then return setmetatable(data, Ring) end
    -- plain array -> ring
    local r = Util.NewRing(math.max(#data, 1))
    for i = 1, #data do r:Push(data[i]) end
    return r
end

-- Throttle helper ----------------------------------------------------------------------------
function Util.Throttle(key, ms, fn)
    local now = Util.Now()
    Util._throttle = Util._throttle or {}
    local last = Util._throttle[key]
    if last and now - last < ms then return false end
    Util._throttle[key] = now
    fn()
    return true
end
