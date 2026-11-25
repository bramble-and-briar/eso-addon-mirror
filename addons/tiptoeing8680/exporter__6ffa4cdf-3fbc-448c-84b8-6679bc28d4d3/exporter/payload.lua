-- payload.lua: wire v2 section payloads (pure Lua 5.1, arithmetic only). Spec: docs/wire-v2.md.
--
-- Every payload starts with a header:
--   formatVersion (1 byte, = 2) | apiVersion (varint) | scope (1 byte: 0 account, 1 character)
--   [if scope = 1: characterId as a string (varint length + ASCII bytes)]
-- and then the section body. Strings are length-prefixed raw bytes (UTF-8 as ESO returns them).
-- Bitsets are: bit count (varint), then ceil(n/8) bytes, least-significant bit first.

CompanionExport = CompanionExport or {}

local Payload = {}
CompanionExport.Payload = Payload

local Varint = CompanionExport.Varint
local floor = math.floor

Payload.FORMAT_VERSION = 2
Payload.SCOPE_ACCOUNT = 0
Payload.SCOPE_CHARACTER = 1

function Payload.writeByte(buf, b)
    assert(b >= 0 and b <= 255 and b == floor(b), "payload: byte out of range")
    buf[#buf + 1] = b
end

function Payload.writeString(buf, s)
    s = s or ""
    Varint.write(buf, #s)
    for i = 1, #s do
        buf[#buf + 1] = string.byte(s, i)
    end
end

--- bits: array of booleans (1-based). Writes count, then packed bytes, LSB first.
function Payload.writeBitset(buf, bits)
    local n = #bits
    Varint.write(buf, n)
    local byte, weight = 0, 1
    for i = 1, n do
        if bits[i] then
            byte = byte + weight
        end
        weight = weight * 2
        if weight == 256 then
            buf[#buf + 1] = byte
            byte, weight = 0, 1
        end
    end
    if weight ~= 1 then
        buf[#buf + 1] = byte
    end
end

function Payload.header(buf, apiVersion, scope, characterId)
    Payload.writeByte(buf, Payload.FORMAT_VERSION)
    Varint.write(buf, apiVersion)
    Payload.writeByte(buf, scope)
    if scope == Payload.SCOPE_CHARACTER then
        assert(type(characterId) == "string" and #characterId > 0, "payload: characterId required")
        Payload.writeString(buf, characterId)
    end
end

---------------------------------------------------------------------------------------------
-- Section bodies (pure). `h` = { apiVersion=, scope=, characterId= }
---------------------------------------------------------------------------------------------

--- P profile. p = { classId, raceId, alliance, level, championPoints, esoPlus (bool),
---               platform, name, world }
function Payload.encodeProfile(h, p)
    local buf = {}
    Payload.header(buf, h.apiVersion, Payload.SCOPE_CHARACTER, h.characterId)
    Varint.write(buf, p.classId)
    Varint.write(buf, p.raceId)
    Varint.write(buf, p.alliance)
    Varint.write(buf, p.level)
    Varint.write(buf, p.championPoints)
    Payload.writeByte(buf, p.esoPlus and 1 or 0)
    Varint.write(buf, p.platform)
    Payload.writeString(buf, p.name)
    Payload.writeString(buf, p.world)
    return buf
end

--- R research. records = array of { craftingType, line, trait, endEpoch }, sorted for determinism.
function Payload.encodeResearch(h, records)
    local sorted = {}
    for i, r in ipairs(records) do
        sorted[i] = r
    end
    table.sort(sorted, function(a, b)
        if a[1] ~= b[1] then return a[1] < b[1] end
        if a[2] ~= b[2] then return a[2] < b[2] end
        return a[3] < b[3]
    end)
    local buf = {}
    Payload.header(buf, h.apiVersion, Payload.SCOPE_CHARACTER, h.characterId)
    Varint.write(buf, #sorted)
    for _, r in ipairs(sorted) do
        Varint.write(buf, r[1])
        Varint.write(buf, r[2])
        Varint.write(buf, r[3])
        Varint.write(buf, r[4])
    end
    return buf
end

--- T traits / E recipes / M motifs / L lorebooks / A achievements: header + one bitset.
function Payload.encodeBitsetSection(h, bits)
    local buf = {}
    Payload.header(buf, h.apiVersion, h.scope, h.characterId)
    Payload.writeBitset(buf, bits)
    return buf
end

--- B backpack (character) / K bank / C craft bag (account): header + (id delta, qty) list.
function Payload.encodeItems(h, counts)
    local buf = {}
    Payload.header(buf, h.apiVersion, h.scope, h.characterId)
    Varint.writeIdQtyMap(buf, counts)
    return buf
end

--- S house chests (account): count, then per chest: index (1-10), savedAt (unix), item list.
--- chests = array of { index, savedAt, counts } (counts: itemId -> qty); sorted by index.
function Payload.encodeHouse(h, chests)
    local sorted = {}
    for i, c in ipairs(chests) do sorted[i] = c end
    table.sort(sorted, function(a, b) return a[1] < b[1] end)
    local buf = {}
    Payload.header(buf, h.apiVersion, Payload.SCOPE_ACCOUNT)
    Varint.write(buf, #sorted)
    for _, c in ipairs(sorted) do
        Varint.write(buf, c[1])
        Varint.write(buf, c[2])
        Varint.writeIdQtyMap(buf, c[3])
    end
    return buf
end
