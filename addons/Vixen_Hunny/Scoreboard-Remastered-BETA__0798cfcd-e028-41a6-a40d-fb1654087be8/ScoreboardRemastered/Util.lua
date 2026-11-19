-- Scoreboard Remastered: namespace and shared helpers.
ScoreboardRemastered = ScoreboardRemastered or {}
local SBR = ScoreboardRemastered

SBR.name = "ScoreboardRemastered"
SBR.displayName = "|c4FC3F7Scoreboard|r Remastered"
SBR.version = "1.0.0"

-- Load timing ("CPU budget reached" diagnostics). Marks are taken as each of our
-- files finishes, at each setup step, and whenever any add-on finishes loading, so
-- the report (chat after login, saved in sv.loadReports) shows where load time goes.
local Now = GetGameTimeMilliseconds
SBR.loadProfile = { start = Now(), marks = {}, addons = {} }
function SBR.Mark(label)
    local p = SBR.loadProfile
    if p.done then return end
    p.marks[#p.marks + 1] = { label, Now() }
end
EVENT_MANAGER:RegisterForEvent(SBR.name .. "_LoadTimeline", EVENT_ADD_ON_LOADED, function(_, name)
    local p = SBR.loadProfile
    if not p.done then p.addons[#p.addons + 1] = { name, Now() } end
end)

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


---------------------------------------------------------------------------
-- Packed storage for saved variables
---------------------------------------------------------------------------
-- A saved-variables file is Lua code that ESO runs on every load, inside the add-on's
-- load-time CPU budget. Every saved table and field costs time there, while a long
-- string costs almost nothing. So finished matches, records and players are saved as
-- a few strings each and unpacked only when used.
--
-- Format: T<key><value>...E table, S<bytes>:<text> string, N<number>; number,
-- B / F true / false. Strings carry their byte length, so nothing needs escaping.
-- Saved strings are cut into pieces of at most PACK_PIECE bytes (ESO's saved
-- variables only keep strings up to about 2000 characters).
local PACK_PIECE = 1900
local concat, format, byte, sub, find, tonumber_ = table.concat, string.format, string.byte, string.sub, string.find, tonumber

local function Write(out, v, depth)
    local t = type(v)
    if t == "table" then
        if depth > 20 then return end
        out[#out + 1] = "T"
        for k, val in pairs(v) do
            local kt, vt = type(k), type(val)
            if (kt == "string" or kt == "number") and (vt == "table" or vt == "string" or vt == "number" or vt == "boolean") then
                Write(out, k, depth + 1)
                Write(out, val, depth + 1)
            end
        end
        out[#out + 1] = "E"
    elseif t == "string" then
        out[#out + 1] = "S" .. #v .. ":" .. v
    elseif t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then v = 0 end
        if v == math.floor(v) and v > -1e15 and v < 1e15 then
            out[#out + 1] = format("N%d;", v)
        else
            out[#out + 1] = format("N%.6g;", v)
        end
    elseif t == "boolean" then
        out[#out + 1] = v and "B" or "F"
    end
end

-- value -> a string, or a list of strings when longer than one saved string allows
function SBR.Pack(value)
    local out = {}
    Write(out, value, 0)
    local s = concat(out)
    if #s <= PACK_PIECE then return s end
    local pieces, i = {}, 1
    while i <= #s do
        local j = math.min(#s, i + PACK_PIECE - 1)
        -- never cut inside a UTF-8 character
        while j < #s and j > i do
            local b = byte(s, j + 1)
            if b < 128 or b >= 192 then break end
            j = j - 1
        end
        pieces[#pieces + 1] = sub(s, i, j)
        i = j + 1
    end
    return pieces
end

local function Read(s, pos)
    local c = byte(s, pos)
    if c == 84 then -- T
        local t = {}
        pos = pos + 1
        while byte(s, pos) ~= 69 do -- E
            local k, v
            k, pos = Read(s, pos)
            v, pos = Read(s, pos)
            if k == nil then error("packed data: bad key at " .. pos) end
            t[k] = v
        end
        return t, pos + 1
    elseif c == 83 then -- S
        local colon = find(s, ":", pos + 1, true)
        local len = tonumber_(sub(s, pos + 1, colon - 1))
        return sub(s, colon + 1, colon + len), colon + len + 1
    elseif c == 78 then -- N
        local semi = find(s, ";", pos + 1, true)
        return tonumber_(sub(s, pos + 1, semi - 1)), semi + 1
    elseif c == 66 then
        return true, pos + 1
    elseif c == 70 then
        return false, pos + 1
    end
    error("packed data: unexpected byte at " .. tostring(pos))
end

function SBR.Unpack(packed)
    if type(packed) == "table" then packed = concat(packed) end
    if type(packed) ~= "string" or packed == "" then return nil end
    local ok, v = pcall(Read, packed, 1)
    if ok then return v end
    SBR.Debug("could not unpack saved data: %s", tostring(v))
    return nil
end

-- A table that unpacks itself the first time any field is read. `known` fields
-- (ids, timestamps) are set up front so they can be read without unpacking.
-- Call SBR.Realize(t) before pairs() / next() on such a table itself.
local LAZY = {}
local function RealizeInto(t, mt)
    setmetatable(t, nil)
    local v = SBR.Unpack(mt.packed)
    if type(v) == "table" then
        for k, val in pairs(v) do rawset(t, k, val) end
    end
end

function SBR.LazyUnpack(packed, known)
    local t = {}
    if known then for k, v in pairs(known) do t[k] = v end end
    local mt = { packed = packed, [LAZY] = true }
    mt.__index = function(self, k)
        RealizeInto(self, mt)
        return rawget(self, k)
    end
    -- a write unpacks first, so the saved values can't overwrite it afterwards
    mt.__newindex = function(self, k, v)
        RealizeInto(self, mt)
        rawset(self, k, v)
    end
    return setmetatable(t, mt)
end

function SBR.IsLazy(t)
    local mt = type(t) == "table" and getmetatable(t)
    return mt ~= nil and mt ~= false and type(mt) == "table" and mt[LAZY] == true
end

function SBR.Realize(t)
    if SBR.IsLazy(t) then RealizeInto(t, getmetatable(t)) end
    return t
end
ScoreboardRemastered.Mark("Util.lua")

-- Battleground art for a team (ESO's files are named by team colour): emblem,
-- capture-bar fill, scoreboard background, highlight strip, objective point, banner.
local TEAM_ART_COLOR
function SBR.TeamArtColor(id)
    if not TEAM_ART_COLOR then
        TEAM_ART_COLOR = {
            [BATTLEGROUND_TEAM_FIRE_DRAKES or 1] = "orange",
            [BATTLEGROUND_TEAM_PIT_DAEMONS or 2] = "green",
            [BATTLEGROUND_TEAM_STORM_LORDS or 3] = "purple",
        }
    end
    return TEAM_ART_COLOR[id] or "green"
end
local BG_ART = "EsoUI/Art/Battlegrounds/"
function SBR.TeamArt(id, kind, won)
    local c = SBR.TeamArtColor(id)
    if kind == "emblem" then return BG_ART .. "battlegrounds_teamIcon_" .. c .. ".dds" end
    -- the gamepad emblem is the larger file: use it for anything drawn over ~40 px
    if kind == "emblemLarge" then return BG_ART .. "Gamepad/gp_battlegrounds_teamIcon_" .. c .. ".dds" end
    if kind == "fill" then return BG_ART .. "battlegroundsCaptureBar_fill_" .. c .. ".dds" end
    if kind == "background" then return BG_ART .. "battlegrounds_scoreboardBG_" .. c .. ".dds" end
    if kind == "strip" then return BG_ART .. "battlegrounds_scoreboard_highlightStrip_" .. c .. ".dds" end
    if kind == "point" then return BG_ART .. "battlegroundsCaptureBar_point_" .. c .. ".dds" end
    if kind == "banner" then return BG_ART .. "battleground_banner_" .. c .. (won and "_win" or "_loss") .. ".dds" end
end

-- A smooth two-colour gradient on an untextured texture control (SetVertexColors).
-- Crisp at any size, unlike stretched art. horizontal: a = left, b = right;
-- otherwise a = top, b = bottom. Colours are { r, g, b, alpha }.
function SBR.Gradient(tex, a, b, horizontal)
    local TL, TR, BL, BR = VERTEX_POINTS_TOPLEFT, VERTEX_POINTS_TOPRIGHT, VERTEX_POINTS_BOTTOMLEFT, VERTEX_POINTS_BOTTOMRIGHT
    if not (tex.SetVertexColors and TL) then
        tex:SetColor(a[1], a[2], a[3], a[4])
        return tex
    end
    tex:SetColor(1, 1, 1, 1)
    local first, second = horizontal and (TL + BL) or (TL + TR), horizontal and (TR + BR) or (BL + BR)
    tex:SetVertexColors(first, a[1], a[2], a[3], a[4])
    tex:SetVertexColors(second, b[1], b[2], b[3], b[4])
    return tex
end
