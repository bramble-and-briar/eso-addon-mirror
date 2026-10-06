-- Trial Tagger: payload encoder. Mirrors bot/trial_tagger/payload.py exactly.
-- See docs/PAYLOAD.md for the byte layout. If you change anything here, change
-- payload.py too and re-run the parity test.
--
-- Everything is pure arithmetic rather than the BitAnd/BitXor globals. The code
-- runs once when the panel opens, so speed is irrelevant, and avoiding the bit
-- API sidesteps signed-vs-unsigned surprises on the console client.

TrialTagger = TrialTagger or {}
local TT = TrialTagger
local Codec = {}
TT.Codec = Codec

local ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
local TWO32 = 4294967296

local function bxor(a, b)
    local result, place = 0, 1
    for _ = 1, 32 do
        local x, y = a % 2, b % 2
        if x ~= y then result = result + place end
        a, b, place = (a - x) / 2, (b - y) / 2, place * 2
    end
    return result
end

----------------------------------------------------------------------------
-- CRC-32 (IEEE, reflected, poly 0xEDB88320) -- byte-identical to zlib.crc32
----------------------------------------------------------------------------

local crcTable

local function buildCrcTable()
    crcTable = {}
    for i = 0, 255 do
        local c = i
        for _ = 1, 8 do
            if c % 2 == 1 then
                c = bxor((c - 1) / 2, 0xEDB88320)
            else
                c = c / 2
            end
        end
        crcTable[i] = c
    end
end

function Codec.Crc32(bytes)
    if not crcTable then buildCrcTable() end
    local crc = 0xFFFFFFFF
    for i = 1, #bytes do
        local index = bxor(crc % 256, bytes[i]) % 256
        crc = bxor(math.floor(crc / 256), crcTable[index])
    end
    return bxor(crc, 0xFFFFFFFF)
end

----------------------------------------------------------------------------
-- FNV-1a/32, folded to 16 bits
----------------------------------------------------------------------------

local FNV_PRIME_LO = 0x0193
local FNV_PRIME_HI = 0x0100

-- Multiply mod 2^32 in 16-bit halves. A direct h * 16777619 would reach 2^56
-- and silently lose precision in Lua's doubles.
local function fnvMultiply(h)
    local lo, hi = h % 65536, math.floor(h / 65536)
    local lowProduct = lo * FNV_PRIME_LO
    local highProduct = (lo * FNV_PRIME_HI + hi * FNV_PRIME_LO) % 65536
    return (highProduct * 65536 + lowProduct) % TWO32
end

function Codec.AccountHash(name)
    local h = 0x811C9DC5
    local upper = string.upper(name or "")
    for i = 1, #upper do
        h = fnvMultiply(bxor(h, string.byte(upper, i)))
    end
    return bxor(math.floor(h / 65536), h) % 65536
end

----------------------------------------------------------------------------
-- Crockford Base32, MSB-first with trailing zero padding
----------------------------------------------------------------------------

function Codec.Base32Encode(bytes)
    local out, accumulator, bits = {}, 0, 0
    for i = 1, #bytes do
        accumulator = accumulator * 256 + bytes[i]
        bits = bits + 8
        while bits >= 5 do
            bits = bits - 5
            local divisor = 2 ^ bits
            local index = math.floor(accumulator / divisor)
            accumulator = accumulator - index * divisor
            out[#out + 1] = string.sub(ALPHABET, index + 1, index + 1)
        end
    end
    if bits > 0 then
        local index = accumulator * (2 ^ (5 - bits))
        out[#out + 1] = string.sub(ALPHABET, index + 1, index + 1)
    end
    return table.concat(out)
end

----------------------------------------------------------------------------
-- Payload assembly
----------------------------------------------------------------------------

local function appendUint(bytes, value, width)
    for shift = width - 1, 0, -1 do
        local divisor = 256 ^ shift
        local byte = math.floor(value / divisor) % 256
        bytes[#bytes + 1] = byte
    end
end

-- Minutes since 2024-01-01T00:00:00Z. GetTimeStamp() is a Unix timestamp.
local EPOCH_UNIX = 1704067200

function Codec.MinutesSinceEpoch()
    local now = GetTimeStamp()
    local minutes = math.floor((now - EPOCH_UNIX) / 60)
    if minutes < 0 then minutes = 0 end
    return minutes % 16777216
end

--- Build the code string.
--
-- `values` is indexed 1..#trials (trial.index + 1) and holds each trial's slot
-- bits. `widths` is indexed the same way and gives how many bits that trial
-- occupies, because trials do not all have the same number of slots. The
-- fields are concatenated MSB-first into one bit stream that is not aligned to
-- byte boundaries.
--
-- `trialBytes` is the fixed length of that stream. It is bigger than the slots
-- need; the spare tail is reserve for trials ESO has not shipped yet, and
-- encodes as zeros. Padding to it here is what keeps the code the same length
-- from one catalog to the next.
function Codec.Encode(values, displayName, payloadVersion, catalogVersion, widths, trialBytes)
    local bytes = {}
    bytes[#bytes + 1] = payloadVersion % 256
    bytes[#bytes + 1] = catalogVersion % 256
    appendUint(bytes, Codec.MinutesSinceEpoch(), 3)
    appendUint(bytes, Codec.AccountHash(displayName), 2)

    local header = #bytes
    local current, held = 0, 0
    for i = 1, #widths do
        local value = values[i] or 0
        local width = widths[i]
        for bit = 1, width do
            local divisor = 2 ^ (width - bit)
            current = current * 2 + (math.floor(value / divisor) % 2)
            held = held + 1
            if held == 8 then
                bytes[#bytes + 1] = current
                current, held = 0, 0
            end
        end
    end
    if held > 0 then
        bytes[#bytes + 1] = current * (2 ^ (8 - held))
    end
    while #bytes - header < trialBytes do
        bytes[#bytes + 1] = 0
    end

    appendUint(bytes, Codec.Crc32(bytes), 4)
    return Codec.Base32Encode(bytes)
end

function Codec.Group(text, size)
    size = size or 5
    local parts = {}
    for i = 1, #text, size do
        parts[#parts + 1] = string.sub(text, i, i + size - 1)
    end
    return parts
end
