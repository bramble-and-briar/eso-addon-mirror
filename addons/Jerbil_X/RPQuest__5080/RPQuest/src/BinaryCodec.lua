-- Ref: docs/adr/0008-codec-compacto-rpq3-lzss-base85.md
-- Ref: docs/adr/0018-ejes-de-victoria-modo-freeform-y-objetivos-requeridos.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.BinaryCodec = {}
local BinaryCodec = Addon.BinaryCodec

local BYTE_TO_CHAR = {}
for b = 0, 255 do
    BYTE_TO_CHAR[b] = string.char(b)
end

local B64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local B64_LOOKUP = {}
local B64_CHARS = {}
for i = 1, #B64_ALPHABET do
    local ch = string.sub(B64_ALPHABET, i, i)
    B64_LOOKUP[ch] = i - 1
    B64_CHARS[i - 1] = ch
end

local B85_ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!$%&+,-./;=?@^{}()[]#'\""
local B85_LOOKUP = {}
local B85_CHARS = {}
for i = 1, #B85_ALPHABET do
    local ch = string.sub(B85_ALPHABET, i, i)
    B85_LOOKUP[ch] = i - 1
    B85_CHARS[i - 1] = ch
end

--- Encodes binary data into URL-safe Base64 without padding.
function BinaryCodec:Base64UrlEncode(input)
    local out = {}
    local outLen = 0
    local len = #input
    local i = 1
    local strByte = string.byte
    local floor = math.floor
    while i <= len do
        local b1 = strByte(input, i) or 0
        local b2 = strByte(input, i + 1)
        local b3 = strByte(input, i + 2)

        local n = (b1 * 65536) + ((b2 or 0) * 256) + (b3 or 0)
        local c1 = floor(n / 262144) % 64
        local c2 = floor(n / 4096) % 64
        local c3 = floor(n / 64) % 64
        local c4 = n % 64

        outLen = outLen + 1
        out[outLen] = B64_CHARS[c1]
        outLen = outLen + 1
        out[outLen] = B64_CHARS[c2]
        if b2 then
            outLen = outLen + 1
            out[outLen] = B64_CHARS[c3]
        end
        if b3 then
            outLen = outLen + 1
            out[outLen] = B64_CHARS[c4]
        end

        i = i + 3
    end
    return table.concat(out)
end

--- Decodes URL-safe Base64 without padding back to raw bytes.
function BinaryCodec:Base64UrlDecode(encoded)
    if type(encoded) ~= "string" or encoded == "" then
        return nil
    end

    local out = {}
    local outLen = 0
    local len = #encoded
    local i = 1
    local strSub = string.sub
    local floor = math.floor
    while i <= len do
        local ch1 = strSub(encoded, i, i)
        local ch2 = strSub(encoded, i + 1, i + 1)
        local ch3 = (i + 2 <= len) and strSub(encoded, i + 2, i + 2) or nil
        local ch4 = (i + 3 <= len) and strSub(encoded, i + 3, i + 3) or nil

        local v1 = B64_LOOKUP[ch1]
        local v2 = B64_LOOKUP[ch2]
        local v3 = ch3 and B64_LOOKUP[ch3] or 0
        local v4 = ch4 and B64_LOOKUP[ch4] or 0

        if v1 == nil or v2 == nil or (ch3 and B64_LOOKUP[ch3] == nil) or (ch4 and B64_LOOKUP[ch4] == nil) then
            return nil
        end

        local n = (v1 * 262144) + (v2 * 4096) + (v3 * 64) + v4
        local b1 = floor(n / 65536) % 256
        local b2 = floor(n / 256) % 256
        local b3 = n % 256

        outLen = outLen + 1
        out[outLen] = BYTE_TO_CHAR[b1]
        if ch3 then
            outLen = outLen + 1
            out[outLen] = BYTE_TO_CHAR[b2]
        end
        if ch4 then
            outLen = outLen + 1
            out[outLen] = BYTE_TO_CHAR[b3]
        end

        i = i + 4
    end

    return table.concat(out)
end

--- Encodes binary data into Base85 using the ESOUI-safe alphabet.
function BinaryCodec:Base85Encode(input)
    local out = {}
    local outLen = 0
    local len = #input
    local i = 1
    local strByte = string.byte
    local floor = math.floor
    while i <= len do
        local rem = len - i + 1
        local chunkLen = rem >= 4 and 4 or rem
        local b1 = strByte(input, i) or 0
        local b2 = (chunkLen >= 2) and strByte(input, i + 1) or 0
        local b3 = (chunkLen >= 3) and strByte(input, i + 2) or 0
        local b4 = (chunkLen >= 4) and strByte(input, i + 3) or 0

        local n = ((b1 * 256 + b2) * 256 + b3) * 256 + b4
        local d5 = n % 85; n = floor(n / 85)
        local d4 = n % 85; n = floor(n / 85)
        local d3 = n % 85; n = floor(n / 85)
        local d2 = n % 85; n = floor(n / 85)
        local d1 = n % 85

        local digits = { d1, d2, d3, d4, d5 }
        local emitCount = chunkLen + 1
        for k = 1, emitCount do
            outLen = outLen + 1
            out[outLen] = B85_CHARS[digits[k]]
        end
        i = i + 4
    end
    return table.concat(out)
end

--- Decodes Base85-encoded text back to raw bytes.
function BinaryCodec:Base85Decode(encoded)
    if type(encoded) ~= "string" then return nil end
    local len = #encoded
    if len == 0 then return "" end
    local out = {}
    local outLen = 0
    local i = 1
    local strSub = string.sub
    local floor = math.floor
    while i <= len do
        local rem = len - i + 1
        if rem == 1 then
            return nil
        end
        local chunkChars = rem >= 5 and 5 or rem
        local n = 0
        for k = 0, chunkChars - 1 do
            local ch = strSub(encoded, i + k, i + k)
            local v = B85_LOOKUP[ch]
            if v == nil then return nil end
            n = n * 85 + v
        end
        for _ = chunkChars + 1, 5 do
            n = n * 85 + 84
        end
        if n > 4294967295 then
            return nil
        end
        local b4 = n % 256; n = floor(n / 256)
        local b3 = n % 256; n = floor(n / 256)
        local b2 = n % 256; n = floor(n / 256)
        local b1 = n % 256

        local emitBytes = chunkChars - 1
        local bytes = { b1, b2, b3, b4 }
        for k = 1, emitBytes do
            outLen = outLen + 1
            out[outLen] = BYTE_TO_CHAR[bytes[k]]
        end
        i = i + 5
    end
    return table.concat(out)
end

--- Appends a single byte (0..255) to the output buffer.
function BinaryCodec:WriteByte(buf, byteVal)
    buf[#buf + 1] = BYTE_TO_CHAR[math.floor(tonumber(byteVal) or 0) % 256]
end

--- Reads a single byte (0..255) from data at pos, returning byte and nextPos.
function BinaryCodec:ReadByte(data, pos, len)
    if pos > len then return nil, pos end
    return string.byte(data, pos), pos + 1
end

--- Appends an unsigned LEB128 varint to the output buffer.
function BinaryCodec:WriteUVarint(buf, n)
    n = math.max(0, math.floor(tonumber(n) or 0))
    while n >= 128 do
        buf[#buf + 1] = BYTE_TO_CHAR[(n % 128) + 128]
        n = math.floor(n / 128)
    end
    buf[#buf + 1] = BYTE_TO_CHAR[n]
end

--- Reads an unsigned LEB128 varint from data at pos.
function BinaryCodec:ReadUVarint(data, pos, len)
    local result = 0
    local mult = 1
    while pos <= len do
        local b = string.byte(data, pos)
        pos = pos + 1
        result = result + (b % 128) * mult
        if b < 128 then
            return result, pos
        end
        mult = mult * 128
        if mult > 2 ^ 49 then return nil, pos end
    end
    return nil, pos
end

--- Appends a ZigZag-encoded signed varint to the output buffer.
function BinaryCodec:WriteSVarint(buf, n)
    n = math.floor(tonumber(n) or 0)
    local zz = (n >= 0) and (n * 2) or (-n * 2 - 1)
    self:WriteUVarint(buf, zz)
end

--- Reads a ZigZag-encoded signed varint from data at pos.
function BinaryCodec:ReadSVarint(data, pos, len)
    local zz, nextPos = self:ReadUVarint(data, pos, len)
    if not zz then return nil, nextPos end
    local n = (zz % 2 == 0) and (zz / 2) or -((zz + 1) / 2)
    return n, nextPos
end

--- Appends a normalized [0, 1] float quantized as big-endian uint16.
function BinaryCodec:WriteUInt16(buf, val)
    local snapped = tonumber(string.format("%.4f", tonumber(val) or 0)) or 0
    local q = math.floor(math.max(0, math.min(1, snapped)) * 65535 + 0.5)
    buf[#buf + 1] = BYTE_TO_CHAR[math.floor(q / 256)]
    buf[#buf + 1] = BYTE_TO_CHAR[q % 256]
end

--- Reads a big-endian uint16 normalized back to [0, 1].
function BinaryCodec:ReadUInt16(data, pos, len)
    if pos + 1 > len then return nil, pos end
    local b1, b2 = string.byte(data, pos, pos + 1)
    return ((b1 * 256) + b2) / 65535, pos + 2
end

--- Appends a length-prefixed string to the output buffer.
function BinaryCodec:WriteStr(buf, str)
    local s = (str ~= nil) and tostring(str) or ""
    self:WriteUVarint(buf, #s)
    if #s > 0 then
        buf[#buf + 1] = s
    end
end

--- Reads a length-prefixed string from data at pos.
function BinaryCodec:ReadStr(data, pos, len)
    local sLen, nextPos = self:ReadUVarint(data, pos, len)
    if not sLen or nextPos + sLen - 1 > len then return nil, nextPos end
    if sLen == 0 then return "", nextPos end
    return string.sub(data, nextPos, nextPos + sLen - 1), nextPos + sLen
end

--- Appends a packed LSB-first bitset of `count` booleans (`math.ceil(count / 8)` bytes) from `items[i][field]` or `items[i]`.
function BinaryCodec:WriteBitset(buf, items, count, field)
    local total = math.max(0, math.floor(tonumber(count) or 0))
    local byteCount = math.ceil(total / 8)
    for b = 0, byteCount - 1 do
        local mask = 0
        local bit = 1
        for k = 1, 8 do
            local idx = b * 8 + k
            if idx <= total then
                local entry = items and items[idx]
                local flag = field and (type(entry) == "table" and entry[field] == true) or (entry == true)
                if flag then
                    mask = mask + bit
                end
            end
            bit = bit * 2
        end
        self:WriteByte(buf, mask)
    end
end

--- Reads `math.ceil(count / 8)` packed LSB-first bitset bytes from `data` at `pos`, returning an array of `count` booleans and `nextPos`.
function BinaryCodec:ReadBitset(data, pos, len, count)
    local total = math.max(0, math.floor(tonumber(count) or 0))
    local byteCount = math.ceil(total / 8)
    local out = {}
    local floor = math.floor
    for b = 0, byteCount - 1 do
        local mask
        mask, pos = self:ReadByte(data, pos, len)
        if not mask then
            return nil, pos
        end
        for k = 0, 7 do
            local idx = b * 8 + k + 1
            if idx <= total then
                out[idx] = (floor(mask / (2 ^ k)) % 2) == 1
            end
        end
    end
    return out, pos
end

--- Compresses binary data using LZSS (with raw fallback if not smaller).
function BinaryCodec:CompressLZSS(data)
    local n = #data
    if n < 8 then
        return "\0" .. data
    end

    local strByte = string.byte
    local head = {}
    local out = {}
    local outLen = 0
    local i = 1

    while i <= n do
        local flagPos = outLen + 1
        outLen = flagPos
        out[flagPos] = "\0"
        local flags = 0
        local bit = 1

        for _ = 1, 8 do
            if i > n then break end
            local bestLen = 0
            local bestOff = 0
            if i + 2 <= n then
                local b1, b2, b3 = strByte(data, i, i + 2)
                local h = (b1 * 65536) + (b2 * 256) + b3
                local prev = head[h]
                head[h] = i
                if prev and (i - prev) <= 4096 then
                    local maxLen = math.min(18, n - i + 1)
                    local m = 0
                    while m < maxLen and strByte(data, prev + m) == strByte(data, i + m) do
                        m = m + 1
                    end
                    if m >= 3 then
                        bestLen = m
                        bestOff = i - prev
                    end
                end
            end

            if bestLen >= 3 then
                flags = flags + bit
                local offM1 = bestOff - 1
                local lenM3 = bestLen - 3
                outLen = outLen + 1
                out[outLen] = BYTE_TO_CHAR[math.floor(offM1 / 16)]
                outLen = outLen + 1
                out[outLen] = BYTE_TO_CHAR[((offM1 % 16) * 16) + lenM3]
                i = i + bestLen
            else
                outLen = outLen + 1
                out[outLen] = string.sub(data, i, i)
                i = i + 1
            end
            bit = bit * 2
        end
        out[flagPos] = BYTE_TO_CHAR[flags]
    end

    local compressed = table.concat(out)
    if #compressed + 1 >= n then
        return "\0" .. data
    end
    return "\1" .. compressed
end

--- Decompresses LZSS-compressed or raw-prefixed binary data.
function BinaryCodec:DecompressLZSS(data)
    if type(data) ~= "string" or #data < 1 then return nil end
    local mode = string.byte(data, 1)
    if mode == 0 then
        return string.sub(data, 2)
    elseif mode ~= 1 then
        return nil
    end

    local len = #data
    local pos = 2
    local out = {}
    local outLen = 0
    local strByte = string.byte
    local floor = math.floor

    while pos <= len do
        local flags = strByte(data, pos)
        pos = pos + 1
        for k = 0, 7 do
            if pos > len then break end
            local isRef = (floor(flags / (2 ^ k)) % 2) == 1
            if isRef then
                if pos + 1 > len then return nil end
                local b1, b2 = strByte(data, pos, pos + 1)
                pos = pos + 2
                local offset = (b1 * 16) + floor(b2 / 16) + 1
                local matchLen = (b2 % 16) + 3
                if offset < 1 or offset > outLen then return nil end
                local startIdx = outLen - offset + 1
                for m = 0, matchLen - 1 do
                    outLen = outLen + 1
                    out[outLen] = out[startIdx + m]
                end
            else
                outLen = outLen + 1
                out[outLen] = BYTE_TO_CHAR[strByte(data, pos)]
                pos = pos + 1
            end
        end
    end

    return table.concat(out)
end
