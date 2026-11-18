-- Scoreboard Remastered: namespace and shared helpers.
ScoreboardRemastered = ScoreboardRemastered or {}
local SBR = ScoreboardRemastered

SBR.name = "ScoreboardRemastered"
SBR.displayName = "|c4FC3F7Scoreboard|r Remastered"
SBR.version = "1.0.0"

local function pack(...)
    return { n = select("#", ...), ... }
end

-- Calls fn(...) protected. Returns fn's results, or nothing if fn is missing or errors.
-- Everything that touches the game API goes through this so that a renamed or
-- removed API function degrades to an empty column instead of a Lua error.
function SBR.SafeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local r = pack(pcall(fn, ...))
    if not r[1] then
        SBR.Debug("call failed: %s", tostring(r[2]))
        return nil
    end
    return unpack(r, 2, r.n)
end

-- Calls a global API function by name (nil-safe).
function SBR.API(fnName, ...)
    return SBR.SafeCall(_G[fnName], ...)
end

function SBR.HasAPI(fnName)
    return type(_G[fnName]) == "function"
end

-- Returns the value of the first global constant in the list that exists.
function SBR.Const(...)
    for i = 1, select("#", ...) do
        local v = _G[select(i, ...)]
        if v ~= nil then return v end
    end
    return nil
end

-- Builds a lookup set from global constant names, skipping ones that don't exist.
function SBR.ConstSet(names)
    local set = {}
    for _, n in ipairs(names) do
        local v = _G[n]
        if v ~= nil then set[v] = true end
    end
    return set
end

function SBR.Print(fmt, ...)
    local msg = select("#", ...) > 0 and string.format(fmt, ...) or fmt
    d(string.format("%s: %s", SBR.displayName, msg))
end

function SBR.Debug(fmt, ...)
    if SBR.sv and SBR.sv.debug then
        local ok, msg = pcall(string.format, fmt, ...)
        d("|c888888[SBR]|r " .. (ok and msg or tostring(fmt)))
    end
end

-- Strips ESO grammar suffixes ("Name^Mx") so names from the scoreboard and the
-- combat log compare equal.
function SBR.CleanName(name)
    if type(name) ~= "string" or name == "" then return "" end
    if zo_strformat and SI_UNIT_NAME then
        local ok, clean = pcall(zo_strformat, SI_UNIT_NAME, name)
        if ok and clean then return clean end
    end
    return (name:gsub("%^.*$", ""))
end

function SBR.FormatNumber(n)
    if type(n) ~= "number" then return n == nil and "-" or tostring(n) end
    local a = math.abs(n)
    if a >= 1e6 then return string.format("%.2fM", n / 1e6) end
    if a >= 1e4 then return string.format("%.1fk", n / 1e3) end
    if n ~= math.floor(n) then
        -- rates like DPS read as whole numbers; keep one decimal only for small values
        if a >= 100 then return tostring(math.floor(n + 0.5)) end
        return string.format("%.1f", n)
    end
    return tostring(n)
end

function SBR.FormatDuration(seconds)
    if type(seconds) ~= "number" or seconds < 0 then return "-" end
    seconds = math.floor(seconds)
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function SBR.FormatTimestamp(ts)
    if type(ts) ~= "number" then return "-" end
    local date = SBR.API("GetDateStringFromTimestamp", ts) or ""
    local time = SBR.API("ZO_FormatTime", ts % 86400, TIME_FORMAT_STYLE_CLOCK_TIME, TIME_FORMAT_PRECISION_TWENTY_FOUR_HOUR) or ""
    return ((date .. " " .. time):gsub("^%s+", ""):gsub("%s+$", ""))
end

function SBR.Colorize(hex, text)
    if not hex or hex == "" then return text end
    return string.format("|c%s%s|r", hex, text)
end

function SBR.HexToRGB(hex)
    if type(hex) ~= "string" or #hex < 6 then return 1, 1, 1 end
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

-- "DAMAGE_DONE" -> "Damage Done"
function SBR.Prettify(constSuffix)
    local s = constSuffix:lower():gsub("_", " ")
    return (s:gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end))
end

function SBR.Now()
    return GetTimeStamp()
end

function SBR.ShallowCopy(t)
    local c = {}
    if t then for k, v in pairs(t) do c[k] = v end end
    return c
end

