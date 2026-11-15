-- Export/import strings. Format: "DT5" .. kind .. ":" .. checksum .. ":" .. base64(payload)
--
-- Payload grammar (strings are LENGTH-PREFIXED, so user text containing any character -- quotes,
-- colons, braces -- can never break parsing; a known flaw of delimiter-based formats):
--   nil  -> Z        true -> T      false -> F
--   num  -> N<digits>;               str  -> S<len>:<bytes>
--   tbl  -> { key value key value ... }

local DT = DebuffTracker
local Ser = DT.Serializer

local MAX_DEPTH = 40
local MAX_LENGTH = 2000000

------------------------------------------------------------------------------
-- Encode
------------------------------------------------------------------------------

local function KeyOrder(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then return ta < tb end
    if ta == "number" or ta == "string" then return a < b end
    return tostring(a) < tostring(b)
end

local function NumberToString(n)
    if n ~= n or n == math.huge or n == -math.huge then return "0" end
    local s = tostring(n)
    if tonumber(s) == n then return s end
    return string.format("%.17g", n)
end

local function Encode(value, out, depth)
    local t = type(value)
    if value == nil then
        out[#out + 1] = "Z"
    elseif t == "boolean" then
        out[#out + 1] = value and "T" or "F"
    elseif t == "number" then
        out[#out + 1] = "N" .. NumberToString(value) .. ";"
    elseif t == "string" then
        out[#out + 1] = "S" .. #value .. ":" .. value
    elseif t == "table" then
        if depth > MAX_DEPTH then error("table nested too deeply") end
        out[#out + 1] = "{"
        local keys = {}
        for k in pairs(value) do
            local kt = type(k)
            if kt == "string" or kt == "number" or kt == "boolean" then keys[#keys + 1] = k end
        end
        table.sort(keys, KeyOrder)
        for _, k in ipairs(keys) do
            local v = value[k]
            local vt = type(v)
            if vt ~= "function" and vt ~= "userdata" and vt ~= "thread" then
                Encode(k, out, depth + 1)
                Encode(v, out, depth + 1)
            end
        end
        out[#out + 1] = "}"
    end
end

function Ser.Encode(value)
    local out = {}
    Encode(value, out, 0)
    return table.concat(out)
end

------------------------------------------------------------------------------
-- Decode
------------------------------------------------------------------------------

local function Decode(s, pos, depth)
    local c = s:sub(pos, pos)
    if c == "Z" then return nil, pos + 1
    elseif c == "T" then return true, pos + 1
    elseif c == "F" then return false, pos + 1
    elseif c == "N" then
        local finish = s:find(";", pos + 1, true)
        if not finish then error("unterminated number") end
        local n = tonumber(s:sub(pos + 1, finish - 1))
        if not n then error("bad number") end
        return n, finish + 1
    elseif c == "S" then
        local colon = s:find(":", pos + 1, true)
        if not colon then error("bad string header") end
        local len = tonumber(s:sub(pos + 1, colon - 1))
        if not len or len < 0 or colon + len > #s then error("bad string length") end
        return s:sub(colon + 1, colon + len), colon + len + 1
    elseif c == "{" then
        if depth > MAX_DEPTH then error("nested too deeply") end
        local t = {}
        pos = pos + 1
        while true do
            if pos > #s then error("unterminated table") end
            if s:sub(pos, pos) == "}" then return t, pos + 1 end
            local k, v
            k, pos = Decode(s, pos, depth + 1)
            v, pos = Decode(s, pos, depth + 1)
            if k ~= nil then t[k] = v end
        end
    end
    error("unexpected '" .. c .. "' at " .. pos)
end

function Ser.Decode(s)
    if type(s) ~= "string" or #s == 0 then return nil, "empty" end
    local ok, value, finish = pcall(Decode, s, 1, 0)
    if not ok then return nil, tostring(value) end
    if finish ~= #s + 1 then return nil, "trailing data" end
    return value
end

------------------------------------------------------------------------------
-- Base64 (no bit library needed) and checksum
------------------------------------------------------------------------------

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_INDEX = {}
for i = 1, 64 do B64_INDEX[B64:sub(i, i)] = i - 1 end

function Ser.ToBase64(data)
    local out = {}
    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64
        out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
            .. (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
    end
    return table.concat(out)
end

function Ser.FromBase64(text)
    text = text:gsub("[^%w%+/=]", "")
    if #text % 4 ~= 0 then return nil end
    local out = {}
    for i = 1, #text, 4 do
        local chunk = text:sub(i, i + 3)
        local n, pad = 0, 0
        for j = 1, 4 do
            local ch = chunk:sub(j, j)
            if ch == "=" then
                pad = pad + 1
                n = n * 64
            else
                local v = B64_INDEX[ch]
                if not v then return nil end
                n = n * 64 + v
            end
        end
        local a = math.floor(n / 65536) % 256
        local b = math.floor(n / 256) % 256
        local c = n % 256
        if pad == 0 then out[#out + 1] = string.char(a, b, c)
        elseif pad == 1 then out[#out + 1] = string.char(a, b)
        else out[#out + 1] = string.char(a) end
    end
    return table.concat(out)
end

function Ser.Checksum(data)
    local a, b = 1, 0
    for i = 1, #data do
        a = (a + data:byte(i)) % 65521
        b = (b + a) % 65521
    end
    return string.format("%04X%04X", b, a)
end

------------------------------------------------------------------------------
-- Public: export strings
------------------------------------------------------------------------------

-- kind: "T" single tracker, "B" bundle of trackers, "P" whole profile
function Ser.Export(kind, value)
    local payload = Ser.Encode(value)
    return "DT5" .. kind .. ":" .. Ser.Checksum(payload) .. ":" .. Ser.ToBase64(payload)
end

-- Returns kind, value  or  nil, errorMessage
function Ser.Import(text)
    text = tostring(text or ""):gsub("%s", "")
    if #text > MAX_LENGTH then return nil, DT.L("That text is too long.") end
    local kind, sum, body = text:match("^DT5(%u):(%x+):(.+)$")
    if not kind then return nil, DT.L("That isn't a DebuffTracker export string.") end
    local payload = Ser.FromBase64(body)
    if not payload then return nil, DT.L("The export string is damaged (bad characters).") end
    if Ser.Checksum(payload) ~= sum:upper() then
        return nil, DT.L("The export string is incomplete or was changed (checksum mismatch).")
    end
    local value, err = Ser.Decode(payload)
    if value == nil then return nil, DT.L("Couldn't read the export string: <<1>>", err or "?") end
    return kind, value
end

------------------------------------------------------------------------------
-- JSON: a human- and AI-writable form of a tracker. The import box accepts plain JSON (one tracker
-- object, an array of them, or {"trackers": [...]}) -- so an assistant that knows the tracker fields
-- can write a tracker for a player to paste. Anything missing gets its default and anything invalid
-- is corrected by Schema.Normalize, exactly like any other import.
------------------------------------------------------------------------------

local function JsonError(msg, pos) error(string.format("%s (at character %d)", msg, pos), 0) end

local function SkipWs(s, pos)
    local _, e = s:find("^[ \t\r\n]*", pos)
    return e + 1
end

local function Utf8(code)
    if code < 0x80 then return string.char(code) end
    if code < 0x800 then return string.char(0xC0 + math.floor(code / 64), 0x80 + code % 64) end
    return string.char(0xE0 + math.floor(code / 4096), 0x80 + math.floor(code / 64) % 64, 0x80 + code % 64)
end

local JsonValue
local ESC = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }

local function JsonString(s, pos)     -- pos at the opening quote
    local out, i = {}, pos + 1
    while true do
        local c = s:sub(i, i)
        if c == "" then JsonError("unterminated text", pos) end
        if c == '"' then return table.concat(out), i + 1 end
        if c == "\\" then
            local e = s:sub(i + 1, i + 1)
            if e == "u" then
                local hex = s:sub(i + 2, i + 5)
                local code = tonumber(hex, 16)
                if not code or #hex < 4 then JsonError("bad \\u escape", i) end
                out[#out + 1] = Utf8(code)
                i = i + 6
            elseif ESC[e] then
                out[#out + 1] = ESC[e]
                i = i + 2
            else
                JsonError("bad escape", i)
            end
        else
            out[#out + 1] = c
            i = i + 1
        end
    end
end

JsonValue = function(s, pos, depth)
    if depth > MAX_DEPTH then JsonError("nested too deeply", pos) end
    pos = SkipWs(s, pos)
    local c = s:sub(pos, pos)
    if c == "{" then
        local t = {}
        pos = SkipWs(s, pos + 1)
        if s:sub(pos, pos) == "}" then return t, pos + 1 end
        while true do
            pos = SkipWs(s, pos)
            if s:sub(pos, pos) ~= '"' then JsonError("expected a \"name\"", pos) end
            local k
            k, pos = JsonString(s, pos)
            pos = SkipWs(s, pos)
            if s:sub(pos, pos) ~= ":" then JsonError("expected ':'", pos) end
            local v
            v, pos = JsonValue(s, pos + 1, depth + 1)
            t[k] = v
            pos = SkipWs(s, pos)
            local d = s:sub(pos, pos)
            if d == "}" then return t, pos + 1 end
            if d ~= "," then JsonError("expected ',' or '}'", pos) end
            pos = pos + 1
        end
    elseif c == "[" then
        local t, n = {}, 0
        pos = SkipWs(s, pos + 1)
        if s:sub(pos, pos) == "]" then return t, pos + 1 end
        while true do
            local v
            v, pos = JsonValue(s, pos, depth + 1)
            n = n + 1
            t[n] = v
            pos = SkipWs(s, pos)
            local d = s:sub(pos, pos)
            if d == "]" then return t, pos + 1 end
            if d ~= "," then JsonError("expected ',' or ']'", pos) end
            pos = pos + 1
        end
    elseif c == '"' then
        return JsonString(s, pos)
    elseif s:sub(pos, pos + 3) == "true" then return true, pos + 4
    elseif s:sub(pos, pos + 4) == "false" then return false, pos + 5
    elseif s:sub(pos, pos + 3) == "null" then return nil, pos + 4
    else
        local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
        if num and num ~= "" and tonumber(num) then return tonumber(num), pos + #num end
    end
    JsonError("unexpected '" .. c .. "'", pos)
end

-- Does this text look like JSON (possibly inside a ```json code block an assistant wrote)?
function Ser.LooksLikeJSON(text)
    local t = tostring(text or ""):gsub("^%s*```[%w]*", ""):gsub("^%s+", "")
    local c = t:sub(1, 1)
    return c == "{" or c == "["
end

-- Returns kind ("T" tracker / "B" several), value  or  nil, errorMessage
function Ser.ImportJSON(text)
    text = tostring(text or "")
    text = text:gsub("^%s*```[%w]*%s*", ""):gsub("%s*```%s*$", "")    -- an assistant's code fence
    if #text > MAX_LENGTH then return nil, DT.L("That text is too long.") end
    local ok, value, finish = pcall(JsonValue, text, 1, 0)
    if not ok then return nil, DT.L("That JSON couldn't be read: <<1>>", tostring(value)) end
    if SkipWs(text, finish) <= #text then return nil, DT.L("That JSON has extra text after the end.") end
    if type(value) ~= "table" then return nil, DT.L("That JSON isn't a tracker.") end
    local list
    if value[1] ~= nil then list = value
    elseif type(value.trackers) == "table" then list = value.trackers
    else return "T", value end
    local out = {}
    for _, t in ipairs(list) do if type(t) == "table" then out[#out + 1] = t end end
    if #out == 0 then return nil, DT.L("That JSON has no trackers in it.") end
    return "B", out
end

-- JSON text of a value (sorted keys, two-space indent): for "export for an AI assistant".
local function JsonQuote(s)
    s = s:gsub('[%c"\\]', function(c)
        if c == '"' then return '\\"' elseif c == "\\" then return "\\\\"
        elseif c == "\n" then return "\\n" elseif c == "\t" then return "\\t"
        else return string.format("\\u%04x", c:byte()) end
    end)
    return '"' .. s .. '"'
end

local function IsArray(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    for i = 1, n do if t[i] == nil then return false end end
    return true, n
end

local function ToJSON(v, indent, depth)
    local tv = type(v)
    if tv == "nil" then return "null" end
    if tv == "boolean" then return v and "true" or "false" end
    if tv == "number" then return NumberToString(v) end
    if tv == "string" then return JsonQuote(v) end
    if tv ~= "table" or depth > MAX_DEPTH then return "null" end
    local pad, pad2 = string.rep("  ", indent), string.rep("  ", indent + 1)
    local arr, n = IsArray(v)
    if arr then
        if n == 0 then return "[]" end
        local simple = true
        for i = 1, n do if type(v[i]) == "table" then simple = false end end
        local parts = {}
        for i = 1, n do parts[i] = ToJSON(v[i], indent + 1, depth + 1) end
        if simple then return "[" .. table.concat(parts, ", ") .. "]" end
        return "[\n" .. pad2 .. table.concat(parts, ",\n" .. pad2) .. "\n" .. pad .. "]"
    end
    local keys = {}
    for k, val in pairs(v) do
        local tk, tval = type(k), type(val)
        if (tk == "string" or tk == "number") and tval ~= "function" and tval ~= "userdata" then keys[#keys + 1] = k end
    end
    if #keys == 0 then return "{}" end
    table.sort(keys, KeyOrder)
    local parts = {}
    for i, k in ipairs(keys) do parts[i] = JsonQuote(tostring(k)) .. ": " .. ToJSON(v[k], indent + 1, depth + 1) end
    return "{\n" .. pad2 .. table.concat(parts, ",\n" .. pad2) .. "\n" .. pad .. "}"
end

function Ser.ToJSON(value)
    return ToJSON(value, 0, 0)
end
