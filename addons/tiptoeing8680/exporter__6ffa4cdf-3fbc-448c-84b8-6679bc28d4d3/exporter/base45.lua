-- base45.lua: RFC 9285 Base45 encoder (pure Lua 5.1, no bit operations).
--
-- Every output character is in the QR "alphanumeric" charset, so the QR encoder can use
-- alphanumeric mode (5.5 bits/char). That is about 97% as dense as binary mode, and it keeps
-- arbitrary bytes out of Lua strings and the QR byte mode.

CompanionExport = CompanionExport or {}

local Base45 = {}
CompanionExport.Base45 = Base45

Base45.ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:"

local floor = math.floor
local CHARS = {}
for i = 1, 45 do
    CHARS[i - 1] = string.sub(Base45.ALPHABET, i, i)
end

--- Encode an array of byte values (integers 0..255, 1-based) as a Base45 string.
function Base45.encode(bytes)
    local out = {}
    local n = #bytes
    local i = 1
    while i + 1 <= n do
        local a, b = bytes[i], bytes[i + 1]
        assert(a >= 0 and a <= 255 and b >= 0 and b <= 255, "base45: byte out of range")
        local v = a * 256 + b
        local c = v % 45
        v = floor(v / 45)
        local d = v % 45
        local e = floor(v / 45)
        out[#out + 1] = CHARS[c] .. CHARS[d] .. CHARS[e]
        i = i + 2
    end
    if i == n then
        local v = bytes[i]
        assert(v >= 0 and v <= 255, "base45: byte out of range")
        out[#out + 1] = CHARS[v % 45] .. CHARS[floor(v / 45)]
    end
    return table.concat(out)
end

--- Convenience: bytes of an ASCII string.
function Base45.bytesOf(s)
    local bytes = {}
    for i = 1, #s do
        bytes[i] = string.byte(s, i)
    end
    return bytes
end
