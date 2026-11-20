local LF = LetsFurnish
local L = LF.L
local floor, byte, char, concat, format = math.floor, string.byte, string.char, table.concat, string.format
local code = {}
LF.code = code
local P2 = {}
for i = 0, 63 do P2[i] = 2 ^ i end
local PREFIX = "LF1:"
local CUT, DAMAGED, TOO_LARGE = L.code.cut, L.code.damaged, L.code.too_large
local MOST = 4 * 1024 * 1024
local PART_PREFIX = "LF2:"
local CARRIES = 29900
local MOST_PARTS = 99
local WRITE_RATE, READ_RATE = 64, 4
local function toBytes(s)
    local out, n = {}, 0
    for i = 1, #s, 4096 do
        local part = { byte(s, i, math.min(i + 4095, #s)) }
        for k = 1, #part do out[n + k] = part[k] end
        n = n + #part
    end
    return out
end
local function toText(bytes, first, last)
    local parts = {}
    for i = first, last, 4096 do parts[#parts + 1] = char(unpack(bytes, i, math.min(i + 4095, last))) end
    return concat(parts)
end
local function adlerOn(bytes, first, last, a, b)
    for i = first, last do
        a = (a + bytes[i]) % 65521
        b = (b + a) % 65521
    end
    return a, b
end
local function adler32(bytes, first, last)
    local a, b = adlerOn(bytes, first, last, 1, 0)
    return b * 65536 + a
end
local function adlerHex(s)
    local a, b = 1, 0
    for i = 1, #s, 4096 do a, b = adlerOn({ byte(s, i, math.min(i + 4095, #s)) }, 1, math.min(4096, #s - i + 1), a, b) end
    return format("%08x", b * 65536 + a)
end
local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local DIGIT, VALUE = {}, {}
for i = 1, 64 do
    DIGIT[i - 1] = ALPHABET:sub(i, i)
    VALUE[byte(ALPHABET, i)] = i - 1
end
local function base64Into(bytes, n, from, to, out)
    for i = from, to, 3 do
        local v = bytes[i] * 65536 + (bytes[i + 1] or 0) * 256 + (bytes[i + 2] or 0)
        out[#out + 1] = DIGIT[floor(v / 262144)] .. DIGIT[floor(v / 4096) % 64] .. (i + 1 <= n and DIGIT[floor(v / 64) % 64] or "=")
            .. (i + 2 <= n and DIGIT[v % 64] or "=")
    end
end
local function unbase64(text)
    local n = #text
    if n % 4 ~= 0 then return nil, CUT end
    local out, k = {}, 0
    for i = 1, n, 4 do
        local c1, c2, c3, c4 = byte(text, i, i + 3)
        local v1, v2, v3, v4 = VALUE[c1], VALUE[c2], VALUE[c3], VALUE[c4]
        local padded = i + 3 == n and c4 == 61 and (v3 or c3 == 61)
        if not (v1 and v2 and (v4 or padded) and (v3 or padded)) then return nil, DAMAGED end
        local v = v1 * 262144 + v2 * 4096 + (v3 or 0) * 64 + (v4 or 0)
        k = k + 1
        out[k] = floor(v / 65536)
        if v3 then k = k + 1; out[k] = floor(v / 256) % 256 end
        if v4 then k = k + 1; out[k] = v % 256 end
    end
    return out
end
local ESCAPE = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t", ["\b"] = "\\b", ["\f"] = "\\f" }
local function escape(c) return ESCAPE[c] or format("\\u%04x", byte(c)) end
local function quoted(s) return '"' .. s:gsub('[%c"\\]', escape) .. '"' end
local function number(v)
    if v ~= v or v == math.huge or v == -math.huge then error("a value that is not a number", 0) end
    if v == floor(v) and math.abs(v) < 2 ^ 53 then return format("%.0f", v) end
    for digits = 15, 16 do
        local s = format("%." .. digits .. "g", v)
        if tonumber(s) == v then return s end
    end
    return format("%.17g", v)
end
local function jsonValue(v, out)
    local kind = type(v)
    if kind == "string" then
        out[#out + 1] = quoted(v)
    elseif kind == "number" then
        out[#out + 1] = number(v)
    elseif kind == "boolean" then
        out[#out + 1] = v and "true" or "false"
    elseif kind ~= "table" then
        error("a value JSON has no word for (" .. kind .. ")", 0)
    else
        local keys, count = {}, 0
        for k in pairs(v) do
            count = count + 1
            keys[count] = tostring(k)
        end
        if count == #v then
            out[#out + 1] = "["
            for i = 1, count do
                if i > 1 then out[#out + 1] = "," end
                jsonValue(v[i], out)
            end
            out[#out + 1] = "]"
            return
        end
        table.sort(keys)
        out[#out + 1] = "{"
        for i, k in ipairs(keys) do
            if i > 1 then out[#out + 1] = "," end
            out[#out + 1] = quoted(k) .. ":"
            local value = v[k]
            if value == nil then value = v[tonumber(k)] end
            jsonValue(value, out)
        end
        out[#out + 1] = "}"
    end
end
local function toJson(value)
    local out = {}
    jsonValue(value, out)
    return concat(out)
end
local function jsonWriter(value)
    local keys, count = {}, 0
    if type(value) == "table" then
        for k in pairs(value) do
            count = count + 1
            keys[count] = tostring(k)
        end
    end
    if type(value) ~= "table" or count == #value then
        local text = toJson(value)
        return function() return true, text, #text end
    end
    table.sort(keys)
    local out, key, list, entry = { "{" }, 0, nil, 0
    return function(budget)
        local start = #out
        local stop = start + budget
        while #out < stop do
            if list then
                entry = entry + 1
                if entry > #list then
                    out[#out + 1] = "]"
                    list = nil
                else
                    if entry > 1 then out[#out + 1] = "," end
                    jsonValue(list[entry], out)
                end
            else
                key = key + 1
                if key > count then
                    out[#out + 1] = "}"
                    return true, concat(out), #out - start
                end
                local k = keys[key]
                out[#out + 1] = (key > 1 and "," or "") .. quoted(k) .. ":"
                local v = value[k]
                if v == nil then v = value[tonumber(k)] end
                local n = 0
                if type(v) == "table" then
                    for _ in pairs(v) do n = n + 1 end
                end
                if n > 0 and n == #v then
                    out[#out + 1] = "["
                    list, entry = v, 0
                else
                    jsonValue(v, out)
                end
            end
        end
        return false, nil, #out - start
    end
end
local UNESCAPE = { b = "\b", f = "\f", n = "\n", r = "\r", t = "\t", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
local function utf8(cp)
    if cp < 0x80 then return char(cp) end
    if cp < 0x800 then return char(0xC0 + floor(cp / 64), 0x80 + cp % 64) end
    if cp < 0x10000 then return char(0xE0 + floor(cp / 4096), 0x80 + floor(cp / 64) % 64, 0x80 + cp % 64) end
    return char(0xF0 + floor(cp / 262144), 0x80 + floor(cp / 4096) % 64, 0x80 + floor(cp / 64) % 64, 0x80 + cp % 64)
end
local function jsonReader(s)
    local pos = 1
    local function fail(what) error(format("%s at byte %d", what, pos), 0) end
    local function space() pos = string.find(s, "[^ \t\r\n]", pos) or #s + 1 end
    local function text()
        local parts, i = {}, pos + 1
        while true do
            local j = string.find(s, '["\\]', i)
            if not j then fail("text without its end") end
            parts[#parts + 1] = s:sub(i, j - 1)
            if byte(s, j) == 34 then
                pos = j + 1
                return concat(parts)
            end
            local e = s:sub(j + 1, j + 1)
            if e == "u" and string.find(s, "^%x%x%x%x", j + 2) then
                local cp = tonumber(s:sub(j + 2, j + 5), 16)
                i = j + 6
                if cp >= 0xD800 and cp < 0xDC00 and string.find(s, "^\\u[dD][c-fC-F]%x%x", i) then
                    cp = 0x10000 + (cp - 0xD800) * 1024 + (tonumber(s:sub(i + 2, i + 5), 16) - 0xDC00)
                    i = i + 6
                end
                parts[#parts + 1] = utf8(cp)
            elseif UNESCAPE[e] then
                parts[#parts + 1] = UNESCAPE[e]
                i = j + 2
            else
                fail("a broken escape")
            end
        end
    end
    local value
    local function list(depth, close, entry)
        pos = pos + 1
        space()
        if byte(s, pos) == close then
            pos = pos + 1
            return
        end
        while true do
            entry(depth + 1)
            space()
            local c = byte(s, pos)
            pos = pos + 1
            if c == close then return end
            if c ~= 44 then fail("no comma") end
        end
    end
    value = function(depth)
        if depth > 64 then fail("nested too deep") end
        space()
        local c = byte(s, pos)
        if c == 123 then
            local t = {}
            list(depth, 125, function(d)
                space()
                if byte(s, pos) ~= 34 then fail("a key that is not text") end
                local k = text()
                space()
                if byte(s, pos) ~= 58 then fail("no colon") end
                pos = pos + 1
                t[k] = value(d)
            end)
            return t
        elseif c == 91 then
            local t, n = {}, 0
            list(depth, 93, function(d)
                n = n + 1
                t[n] = value(d)
            end)
            return t
        elseif c == 34 then
            return text()
        end
        if c == 116 and s:sub(pos, pos + 3) == "true" then
            pos = pos + 4
            return true
        elseif c == 102 and s:sub(pos, pos + 4) == "false" then
            pos = pos + 5
            return false
        elseif c == 110 and s:sub(pos, pos + 3) == "null" then
            pos = pos + 4
            return nil
        end
        local num = string.match(s, "^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
        local v = num and tonumber(num)
        if not v then fail("no value") end
        pos = pos + #num
        return v
    end
    local start
    local function ended(result)
        space()
        if pos <= #s then fail("more after the end") end
        return true, result, pos - start
    end
    local top, entries, n
    return function(budget)
        start = pos
        local stop = pos + budget
        if top == nil then
            space()
            if byte(s, pos) ~= 123 then
                top = false
                return ended(value(0))
            end
            top = {}
            pos = pos + 1
            space()
            if byte(s, pos) == 125 then
                pos = pos + 1
                return ended(top)
            end
        end
        while pos < stop do
            if entries then
                n = n + 1
                entries[n] = value(2)
                space()
                local c = byte(s, pos)
                pos = pos + 1
                if c == 93 then
                    entries = nil
                elseif c ~= 44 then
                    fail("no comma")
                end
            else
                space()
                if byte(s, pos) ~= 34 then fail("a key that is not text") end
                local k = text()
                space()
                if byte(s, pos) ~= 58 then fail("no colon") end
                pos = pos + 1
                space()
                if byte(s, pos) == 91 then
                    pos = pos + 1
                    space()
                    top[k] = {}
                    if byte(s, pos) == 93 then
                        pos = pos + 1
                    else
                        entries, n = top[k], 0
                    end
                else
                    top[k] = value(1)
                end
            end
            if not entries then
                space()
                local c = byte(s, pos)
                pos = pos + 1
                if c == 125 then return ended(top) end
                if c ~= 44 then fail("no comma") end
            end
        end
        return false, (pos - 1) / #s, pos - start
    end
end
local function fromJson(s)
    local step = jsonReader(s)
    local done, result
    repeat done, result = step(#s + 1) until done
    return result
end
local MATCH_MAX, END_POS_MODEL, FULL_DISTANCES = 273, 14, 128
local TOP = 2 ^ 24
local function probabilities(n)
    local t = {}
    for i = 1, n do t[i] = 1024 end
    return t
end
local function newModel(lc, lp)
    local function lengths() return { choice = probabilities(2), low = probabilities(128), mid = probabilities(128), high = probabilities(255) } end
    return {
        isMatch = probabilities(192), isRep0Long = probabilities(192),
        isRep = probabilities(12), isRepG0 = probabilities(12), isRepG1 = probabilities(12), isRepG2 = probabilities(12),
        posSlot = probabilities(256),
        posSpecial = probabilities(114),
        align = probabilities(15),
        literal = probabilities(0x300 * P2[lc + lp]),
        len = lengths(), repLen = lengths(),
    }
end
local function afterLiteral(state)
    if state < 4 then return 0 elseif state < 10 then return state - 3 end
    return state - 6
end
local function lzmaDecoder(src, first, last)
    if last - first + 1 < 18 then error(CUT, 0) end
    local props = src[first]
    if props >= 225 then error(DAMAGED, 0) end
    local lc, lp, pb = props % 9, floor(props / 9) % 5, floor(props / 45)
    if lc + lp > 4 then error(DAMAGED, 0) end
    local dictSize = math.max(4096, src[first + 1] + src[first + 2] * 256 + src[first + 3] * 65536 + src[first + 4] * 16777216)
    local size, known = 0, false
    for i = first + 12, first + 5, -1 do
        if src[i] ~= 255 then known = true end
        size = size * 256 + src[i]
    end
    if known and size > MOST then error(TOO_LARGE, 0) end
    local m = newModel(lc, lp)
    local lit, lcBase, lpMask, pbMask = m.literal, P2[8 - lc], P2[lp], P2[pb]
    local range, value, at = 4294967295, 0, first + 13
    local function input()
        if at > last then error(CUT, 0) end
        at = at + 1
        return src[at - 1]
    end
    if input() ~= 0 then error(DAMAGED, 0) end
    for _ = 1, 4 do value = value * 256 + input() end
    if value == range then error(DAMAGED, 0) end
    local function bit(p, i)
        local v = p[i]
        local bound = floor(range / 2048) * v
        local b = 0
        if value < bound then
            range = bound
            p[i] = v + floor((2048 - v) / 32)
        else
            value = value - bound
            range = range - bound
            p[i] = v - floor(v / 32)
            b = 1
        end
        if range < TOP then
            range = range * 256
            value = value * 256 + input()
        end
        return b
    end
    local function tree(p, base, bits)
        local i = 1
        for _ = 1, bits do i = i * 2 + bit(p, base + i) end
        return i - P2[bits]
    end
    local function reverse(p, base, bits)
        local i, symbol = 1, 0
        for k = 0, bits - 1 do
            local b = bit(p, base + i)
            i = i * 2 + b
            symbol = symbol + b * P2[k]
        end
        return symbol
    end
    local function direct(bits)
        local v = 0
        for _ = 1, bits do
            range = floor(range / 2)
            local b = 0
            if value >= range then
                value = value - range
                b = 1
            end
            v = v * 2 + b
            if range < TOP then
                range = range * 256
                value = value * 256 + input()
            end
        end
        return v
    end
    local function length(c, posState)
        if bit(c.choice, 1) == 0 then return tree(c.low, posState * 8, 3) end
        if bit(c.choice, 2) == 0 then return 8 + tree(c.mid, posState * 8, 3) end
        return 16 + tree(c.high, 0, 8)
    end
    local function distance(len)
        local slot = tree(m.posSlot, (len < 3 and len or 3) * 64, 6)
        if slot < 4 then return slot end
        local bits = floor(slot / 2) - 1
        local dist = (2 + slot % 2) * P2[bits]
        if slot < END_POS_MODEL then return dist + reverse(m.posSpecial, dist - slot, bits) end
        return dist + direct(bits - 4) * 16 + reverse(m.align, 0, 4)
    end
    local out, n = {}, 0
    local state, rep0, rep1, rep2, rep3 = 0, 0, 0, 0, 0
    return function(budget)
        local stop = n + budget
        while n < stop do
            if known and n == size then return true, out, n end
            if n >= MOST then error(TOO_LARGE, 0) end
            local posState = n % pbMask
            local len
            if bit(m.isMatch, state * 16 + posState + 1) == 0 then
                local base = 0x300 * ((n % lpMask) * P2[lc] + floor((n > 0 and out[n] or 0) / lcBase))
                local symbol = 1
                if state >= 7 then
                    local matchByte = out[n - rep0]
                    repeat
                        local matchBit = floor(matchByte / 128) % 2
                        matchByte = matchByte * 2
                        local b = bit(lit, base + (1 + matchBit) * 256 + symbol)
                        symbol = symbol * 2 + b
                    until matchBit ~= b or symbol >= 256
                end
                while symbol < 256 do symbol = symbol * 2 + bit(lit, base + symbol) end
                n = n + 1
                out[n] = symbol - 256
                state = afterLiteral(state)
            elseif bit(m.isRep, state + 1) == 0 then
                rep3, rep2, rep1 = rep2, rep1, rep0
                len = length(m.len, posState)
                state = state < 7 and 7 or 10
                rep0 = distance(len)
                if rep0 == 4294967295 then
                    if value ~= 0 or (known and n ~= size) then error(DAMAGED, 0) end
                    return true, out, n
                end
            else
                if n == 0 then error(DAMAGED, 0) end
                if bit(m.isRepG0, state + 1) == 0 then
                    if bit(m.isRep0Long, state * 16 + posState + 1) == 0 then
                        state = state < 7 and 9 or 11
                        len = -1
                    end
                else
                    local dist
                    if bit(m.isRepG1, state + 1) == 0 then
                        dist = rep1
                    else
                        if bit(m.isRepG2, state + 1) == 0 then
                            dist = rep2
                        else
                            dist = rep3
                            rep3 = rep2
                        end
                        rep2 = rep1
                    end
                    rep1 = rep0
                    rep0 = dist
                end
                if not len then
                    len = length(m.repLen, posState)
                    state = state < 7 and 8 or 11
                end
            end
            if len then
                len = len + 2
                if rep0 >= n or rep0 >= dictSize or (known and n + len > size) then error(DAMAGED, 0) end
                for _ = 1, len do
                    n = n + 1
                    out[n] = out[n - rep0 - 1]
                end
            end
        end
        return false, known and n / size or (at - first) / (last - first + 1)
    end
end
local NICE, DEPTH, WINDOW, REFRESH = 128, 48, 2048, 256
local DICT_SIZE = 1048576
local LC, LP, PB = 0, 0, 0
local NUM_SLOTS = 40
local LIT, SHORT, REP, MATCH = 1, 2, 3, 7
local PRICE = {}
for p = 1, 2047 do PRICE[p] = -math.log(p / 2048) / math.log(2) end
local SLOT = {}
for d = 0, 3 do SLOT[d + 1] = d end
for slot = 4, 23 do
    local bits = floor(slot / 2) - 1
    local base = (2 + slot % 2) * P2[bits]
    for d = base, base + P2[bits] - 1 do SLOT[d + 1] = slot end
end
local function slotOf(d)
    local add = 0
    while d >= 4096 do
        d = floor(d / 64)
        add = add + 12
    end
    return SLOT[d + 1] + add
end
local function treePrice(p, base, bits, symbol)
    local price, i = 0, 1
    for k = bits - 1, 0, -1 do
        local b = floor(symbol / P2[k]) % 2
        local v = p[base + i]
        price = price + (b == 0 and PRICE[v] or PRICE[2048 - v])
        i = i * 2 + b
    end
    return price
end
local function reversePrice(p, base, bits, symbol)
    local price, i = 0, 1
    for _ = 1, bits do
        local b = symbol % 2
        local v = p[base + i]
        price = price + (b == 0 and PRICE[v] or PRICE[2048 - v])
        i = i * 2 + b
        symbol = floor(symbol / 2)
    end
    return price
end
local function lzmaEncoder(data, n)
    local m = newModel(LC, LP)
    local lit, pbMask = m.literal, P2[PB]
    local out, count = {}, 0
    local function put(b)
        count = count + 1
        out[count] = b
    end
    put((PB * 5 + LP) * 9 + LC)
    for i = 0, 3 do put(floor(DICT_SIZE / P2[8 * i]) % 256) end
    for _ = 1, 8 do put(255) end
    local low, range, cache, cacheSize = 0, 4294967295, 0, 1
    local function shiftLow()
        if low < 4278190080 or low >= 4294967296 then
            local carry = low >= 4294967296 and 1 or 0
            local b = cache
            repeat
                put((b + carry) % 256)
                b = 255
                cacheSize = cacheSize - 1
            until cacheSize == 0
            cache = floor(low / 16777216) % 256
        end
        cacheSize = cacheSize + 1
        low = (low % 16777216) * 256
    end
    local function bit(p, i, b)
        local v = p[i]
        local bound = floor(range / 2048) * v
        if b == 0 then
            range = bound
            p[i] = v + floor((2048 - v) / 32)
        else
            low = low + bound
            range = range - bound
            p[i] = v - floor(v / 32)
        end
        if range < TOP then
            range = range * 256
            shiftLow()
        end
    end
    local function tree(p, base, bits, symbol)
        local i = 1
        for k = bits - 1, 0, -1 do
            local b = floor(symbol / P2[k]) % 2
            bit(p, base + i, b)
            i = i * 2 + b
        end
    end
    local function reverse(p, base, bits, symbol)
        local i = 1
        for _ = 1, bits do
            local b = symbol % 2
            bit(p, base + i, b)
            i = i * 2 + b
            symbol = floor(symbol / 2)
        end
    end
    local function direct(v, bits)
        for k = bits - 1, 0, -1 do
            range = floor(range / 2)
            if floor(v / P2[k]) % 2 == 1 then low = low + range end
            if range < TOP then
                range = range * 256
                shiftLow()
            end
        end
    end
    local function length(c, len, posState)
        if len < 8 then
            bit(c.choice, 1, 0)
            tree(c.low, posState * 8, 3, len)
        elseif len < 16 then
            bit(c.choice, 1, 1)
            bit(c.choice, 2, 0)
            tree(c.mid, posState * 8, 3, len - 8)
        else
            bit(c.choice, 1, 1)
            bit(c.choice, 2, 1)
            tree(c.high, 0, 8, len - 16)
        end
    end
    local function distance(d, len)
        local slot = slotOf(d)
        tree(m.posSlot, (len < 3 and len or 3) * 64, 6, slot)
        if slot >= 4 then
            local bits = floor(slot / 2) - 1
            local base = (2 + slot % 2) * P2[bits]
            if slot < END_POS_MODEL then
                reverse(m.posSpecial, base - slot, bits, d - base)
            else
                direct(floor((d - base) / 16), bits - 4)
                reverse(m.align, 0, 4, (d - base) % 16)
            end
        end
    end
    local pos, state, rep0, rep1, rep2, rep3 = 0, 0, 0, 0, 0, 0
    local function codeLiteral(i)
        bit(m.isMatch, state * 16 + (i - 1) % pbMask + 1, 0)
        local symbol, matchByte, index = data[i], state >= 7 and data[i - rep0 - 1], 1
        for k = 7, 0, -1 do
            local b = floor(symbol / P2[k]) % 2
            if matchByte then
                local mb = floor(matchByte / P2[k]) % 2
                bit(lit, (1 + mb) * 256 + index, b)
                if mb ~= b then matchByte = nil end
            else
                bit(lit, index, b)
            end
            index = index * 2 + b
        end
        state = afterLiteral(state)
    end
    local function codeMatch(i, d, len)
        local posState = (i - 1) % pbMask
        bit(m.isMatch, state * 16 + posState + 1, 1)
        bit(m.isRep, state + 1, 0)
        length(m.len, len - 2, posState)
        distance(d, len - 2)
        rep3, rep2, rep1, rep0 = rep2, rep1, rep0, d
        state = state < 7 and 7 or 10
    end
    local function codeRep(i, which, len)
        local posState = (i - 1) % pbMask
        bit(m.isMatch, state * 16 + posState + 1, 1)
        bit(m.isRep, state + 1, 1)
        if which == 0 then
            bit(m.isRepG0, state + 1, 0)
            bit(m.isRep0Long, state * 16 + posState + 1, len == 1 and 0 or 1)
        else
            bit(m.isRepG0, state + 1, 1)
            local d
            if which == 1 then
                bit(m.isRepG1, state + 1, 0)
                d = rep1
            else
                bit(m.isRepG1, state + 1, 1)
                bit(m.isRepG2, state + 1, which - 2)
                if which == 3 then
                    d = rep3
                    rep3 = rep2
                else
                    d = rep2
                end
                rep2 = rep1
            end
            rep1 = rep0
            rep0 = d
        end
        if len == 1 then
            state = state < 7 and 9 or 11
        else
            length(m.repLen, len - 2, posState)
            state = state < 7 and 8 or 11
        end
    end
    local lenPrice, repLenPrice, slotPrice, distPrice, alignPrice = {}, {}, {}, {}, {}
    local function lengthPrices(c, t)
        local a0, a1 = PRICE[c.choice[1]], PRICE[2048 - c.choice[1]]
        local b0, b1 = PRICE[c.choice[2]], PRICE[2048 - c.choice[2]]
        for posState = 0, pbMask - 1 do
            for len = 0, 271 do
                local price
                if len < 8 then
                    price = a0 + treePrice(c.low, posState * 8, 3, len)
                elseif len < 16 then
                    price = a1 + b0 + treePrice(c.mid, posState * 8, 3, len - 8)
                else
                    price = a1 + b1 + treePrice(c.high, 0, 8, len - 16)
                end
                t[posState * 272 + len + 1] = price
            end
        end
    end
    local function refresh()
        lengthPrices(m.len, lenPrice)
        lengthPrices(m.repLen, repLenPrice)
        for lenState = 0, 3 do
            for slot = 0, NUM_SLOTS - 1 do
                local price = treePrice(m.posSlot, lenState * 64, 6, slot)
                if slot >= END_POS_MODEL then price = price + floor(slot / 2) - 5 end
                slotPrice[lenState * 64 + slot + 1] = price
            end
            for d = 0, FULL_DISTANCES - 1 do
                local slot = SLOT[d + 1]
                local price = slotPrice[lenState * 64 + slot + 1]
                if slot >= 4 then
                    local bits = floor(slot / 2) - 1
                    local base = (2 + slot % 2) * P2[bits]
                    price = price + reversePrice(m.posSpecial, base - slot, bits, d - base)
                end
                distPrice[lenState * 128 + d + 1] = price
            end
        end
        for a = 0, 15 do alignPrice[a + 1] = reversePrice(m.align, 0, 4, a) end
    end
    local function distancePrice(d, len)
        local lenState = len < 5 and len - 2 or 3
        if d < FULL_DISTANCES then return distPrice[lenState * 128 + d + 1] end
        return slotPrice[lenState * 64 + slotOf(d) + 1] + alignPrice[d % 16 + 1]
    end
    local function literalPrice(i, matchByte)
        local symbol, index, price = data[i], 1, 0
        for k = 7, 0, -1 do
            local b = floor(symbol / P2[k]) % 2
            local v
            if matchByte then
                local mb = floor(matchByte / P2[k]) % 2
                v = lit[(1 + mb) * 256 + index]
                if mb ~= b then matchByte = nil end
            else
                v = lit[index]
            end
            price = price + (b == 0 and PRICE[v] or PRICE[2048 - v])
            index = index * 2 + b
        end
        return price
    end
    local head, chain = {}, {}
    local found, foundLen, foundDist = 0, {}, {}
    local function insert(i)
        if i + 2 > n then return end
        local h = data[i] * 65536 + data[i + 1] * 256 + data[i + 2]
        chain[i] = head[h]
        head[h] = i
    end
    local function search(i)
        found = 0
        if i + 2 > n then return end
        local most = n - i + 1
        if most > MATCH_MAX then most = MATCH_MAX end
        local best, j, tries = 2, head[data[i] * 65536 + data[i + 1] * 256 + data[i + 2]], DEPTH
        while j and tries > 0 and i - j <= DICT_SIZE do
            if data[j + best] == data[i + best] then
                local len = 3
                while len < most and data[j + len] == data[i + len] do len = len + 1 end
                if len > best then
                    best = len
                    found = found + 1
                    foundLen[found], foundDist[found] = len, i - j - 1
                    if len >= NICE or len == most then break end
                end
            end
            j = chain[j]
            tries = tries - 1
        end
        insert(i)
    end
    local function repLength(i, d, most)
        local j = i - d - 1
        if j < 1 or most < 2 or data[j] ~= data[i] or data[j + 1] ~= data[i + 1] then return 0 end
        local len = 2
        while len < most and data[j + len] == data[i + len] do len = len + 1 end
        return len
    end
    local price, back, how, howLen, howDist = {}, {}, {}, {}, {}
    local states, d0, d1, d2, d3 = {}, {}, {}, {}, {}
    local reached, farthest, start = 0, 0, 0
    local path = {}
    local function reach(from, k, p, kind, len, d)
        while reached < k do
            reached = reached + 1
            price[reached + 1] = math.huge
        end
        if p < price[k + 1] then
            price[k + 1], back[k + 1], how[k + 1], howLen[k + 1], howDist[k + 1] = p, from, kind, len, d
        end
    end
    local function arrive(k)
        local from, kind = back[k + 1] + 1, how[k + 1]
        local s, a, b, c, d = states[from], d0[from], d1[from], d2[from], d3[from]
        if kind == LIT then
            s = afterLiteral(s)
        elseif kind == SHORT then
            s = s < 7 and 9 or 11
        elseif kind == MATCH then
            s = s < 7 and 7 or 10
            a, b, c, d = howDist[k + 1], a, b, c
        else
            s = s < 7 and 8 or 11
            if kind == REP + 1 then a, b = b, a
            elseif kind == REP + 2 then a, b, c = c, a, b
            elseif kind == REP + 3 then a, b, c, d = d, a, b, c end
        end
        states[k + 1], d0[k + 1], d1[k + 1], d2[k + 1], d3[k + 1] = s, a, b, c, d
    end
    local function leave(k)
        local i = start + k
        local s, p0 = states[k + 1], price[k + 1]
        local posState = (i - 1) % pbMask
        local si = s * 16 + posState + 1
        local match1 = PRICE[2048 - m.isMatch[si]]
        local matchByte = data[i - d0[k + 1] - 1]
        reach(k, k + 1, p0 + PRICE[m.isMatch[si]] + literalPrice(i, s >= 7 and matchByte), LIT)
        local repBase = p0 + match1 + PRICE[2048 - m.isRep[s + 1]]
        local g0, g1, g2 = m.isRepG0[s + 1], m.isRepG1[s + 1], m.isRepG2[s + 1]
        if matchByte == data[i] then
            reach(k, k + 1, repBase + PRICE[g0] + PRICE[m.isRep0Long[si]], SHORT)
        end
        local most = n - i + 1
        if most > MATCH_MAX then most = MATCH_MAX end
        local lens = posState * 272 - 1
        for which = 0, 3 do
            local len = repLength(i, (which == 0 and d0 or which == 1 and d1 or which == 2 and d2 or d3)[k + 1], most)
            if len >= 2 then
                local p
                if which == 0 then p = repBase + PRICE[g0] + PRICE[2048 - m.isRep0Long[si]]
                elseif which == 1 then p = repBase + PRICE[2048 - g0] + PRICE[g1]
                elseif which == 2 then p = repBase + PRICE[2048 - g0] + PRICE[2048 - g1] + PRICE[g2]
                else p = repBase + PRICE[2048 - g0] + PRICE[2048 - g1] + PRICE[2048 - g2] end
                for l = 2, len do reach(k, k + l, p + repLenPrice[lens + l], REP + which, l) end
                if k + len > farthest then farthest = k + len end
            end
        end
        if found > 0 then
            local p = p0 + match1 + PRICE[m.isRep[s + 1]]
            local from = 2
            for f = 1, found do
                local len, d = foundLen[f], foundDist[f]
                local far = distancePrice(d, 5)
                for l = from, len do
                    reach(k, k + l, p + lenPrice[lens + l] + (l < 5 and distancePrice(d, l) or far), MATCH, l, d)
                end
                from = len + 1
            end
            if k + foundLen[found] > farthest then farthest = k + foundLen[found] end
        end
    end
    local function longestRep(i)
        local most = n - i + 1
        if most > MATCH_MAX then most = MATCH_MAX end
        local best, which = 0, 0
        for w, d in ipairs({ rep0, rep1, rep2, rep3 }) do
            local len = repLength(i, d, most)
            if len > best then best, which = len, w - 1 end
        end
        return best, which
    end
    local pending = false
    local nextRefresh = 0
    local function stretch()
        start = pos + 1
        if not pending then search(start) end
        pending = false
        local repLen, which = longestRep(start)
        local take = repLen >= NICE and -1 or (found > 0 and foundLen[found] >= NICE and found)
        if take then
            local len = take == -1 and repLen or foundLen[take]
            if take == -1 then codeRep(start, which, len) else codeMatch(start, foundDist[take], len) end
            for i = start + 1, start + len - 1 do insert(i) end
            pos = pos + len
            return
        end
        price[1], states[1], d0[1], d1[1], d2[1], d3[1] = 0, state, rep0, rep1, rep2, rep3
        reached, farthest = 0, 0
        local k = 0
        while true do
            if k > 0 then
                if k >= farthest or k >= WINDOW or start + k > n then break end
                arrive(k)
                search(start + k)
                if found > 0 and foundLen[found] >= NICE then
                    pending = true
                    break
                end
            end
            leave(k)
            k = k + 1
        end
        local steps = 0
        local at = k
        while at > 0 do
            steps = steps + 1
            path[steps] = at
            at = back[at + 1]
        end
        for x = steps, 1, -1 do
            local t = path[x]
            local i, kind = start + back[t + 1], how[t + 1]
            if kind == LIT then codeLiteral(i)
            elseif kind == SHORT then codeRep(i, 0, 1)
            elseif kind == MATCH then codeMatch(i, howDist[t + 1], howLen[t + 1])
            else codeRep(i, kind - REP, howLen[t + 1]) end
        end
        pos = pos + k
    end
    return function(budget)
        local stop = pos + budget
        while pos < n and pos < stop do
            if pos >= nextRefresh then
                refresh()
                nextRefresh = pos + REFRESH
            end
            stretch()
        end
        if pos < n then return false, pos / n end
        local posState = n % pbMask
        bit(m.isMatch, state * 16 + posState + 1, 1)
        bit(m.isRep, state + 1, 0)
        length(m.len, 0, posState)
        distance(4294967295, 0)
        for _ = 1, 5 do shiftLow() end
        return true, out, count
    end
end
local function refused(why)
    return function() return nil, why end
end
local function steps(list, share)
    local i, carried, failed = 1, nil, nil
    return function(left)
        if failed then return nil, failed end
        while left > 0 do
            local done, result, used = list[i](left, carried)
            if done == nil then
                failed = result
                return nil, failed
            end
            left = left - math.max(1, used or left)
            if not done then return false, share(i, result) end
            carried = result
            if i == #list then return true, result end
            i = i + 1
        end
        return false, share(i)
    end
end
function code.encoder(layout)
    local json = jsonWriter(layout)
    local data, n, a, b, at, lzma, out, count, text = {}, 0, 1, 0, 0, nil, nil, 0, {}
    return steps({
        function(left)
            local done, written, used = json(math.ceil(left * WRITE_RATE / 4))
            return done, written, used * 4 / WRITE_RATE
        end,
        function(left, written)
            local stop = math.min(#written, at + math.ceil(left * WRITE_RATE))
            for i = at + 1, stop, 4096 do
                local part = { byte(written, i, math.min(i + 4095, stop)) }
                for k = 1, #part do data[n + k] = part[k] end
                n = n + #part
            end
            local used = (stop - at) / WRITE_RATE
            at = stop
            if at < #written then return false, nil, used end
            at = 0
            return true, nil, used
        end,
        function(left)
            local stop = math.min(n, at + math.ceil(left * WRITE_RATE))
            a, b = adlerOn(data, at + 1, stop, a, b)
            local used = (stop - at) / WRITE_RATE
            at = stop
            if at < n then return false, nil, used end
            at = 0
            lzma = lzmaEncoder(data, n)
            return true, nil, used
        end,
        function(left)
            local done, bytes, total = lzma(math.ceil(left))
            if not done then return false, bytes, left end
            out, count = bytes, total
            local check = b * 65536 + a
            for k = 1, 4 do out[count + k] = floor(check / P2[8 * (4 - k)]) % 256 end
            count = count + 4
            return true, nil, 1
        end,
        function(left)
            local stop = math.min(count, at + 3 * math.ceil(left * WRITE_RATE / 3))
            base64Into(out, count, at + 1, stop, text)
            local used = (stop - at) / WRITE_RATE
            at = stop
            if at < count then return false, nil, used end
            return true, PREFIX .. concat(text), used
        end,
    }, function(i, packed)
        if i < 4 then return 0 end
        if i > 4 then return 1 end
        return packed or 0
    end)
end
function code.split(text)
    if #text <= LF.CODE_MOST then return { text } end
    local body = text:sub(#PREFIX + 1)
    local id, n = adlerHex(body), math.ceil(#body / CARRIES)
    local parts = {}
    for k = 1, n do
        local head = format("%s%s:%d/%d:%s", PART_PREFIX, id, k, n, body:sub((k - 1) * CARRIES + 1, k * CARRIES))
        parts[k] = head .. ":" .. adlerHex(head)
    end
    return parts
end
local function readPart(text)
    local id, k, n, body, check = string.match(text, "^LF2:(%x%x%x%x%x%x%x%x):(%d+)/(%d+):([^:]*):(%x%x%x%x%x%x%x%x)$")
    if not id then
        local saidK, saidN = string.match(text, "^LF2:%x+:(%d+)/(%d+):")
        if saidK then return nil, zo_strformat(L.code.part_damaged, saidK, saidN) end
        return nil, L.code.part_unreadable
    end
    k, n = tonumber(k), tonumber(n)
    if adlerHex(text:sub(1, #text - 9)) ~= check:lower() or n < 2 or n > MOST_PARTS or k < 1 or k > n then
        return nil, zo_strformat(L.code.part_damaged, k, n)
    end
    return { id = id:lower(), k = k, n = n, body = body }
end
function code.parts(text)
    local packed = string.gsub(tostring(text or ""), "%s+", "")
    local out, at = {}, 1
    while at <= #packed do
        local after = string.find(packed, PART_PREFIX, at + 1, true)
        local part, why = readPart(packed:sub(at, (after or #packed + 1) - 1))
        out[#out + 1] = { part = part, why = why }
        at = after or #packed + 1
    end
    return out
end
function code.isParts(text)
    return string.sub((string.gsub(tostring(text or ""), "%s+", "")), 1, #PART_PREFIX) == PART_PREFIX
end
function code.join(held)
    local bodies = {}
    for k = 1, held.n do
        if not held.bodies[k] then return nil, zo_strformat(L.code.parts_missing, held.n) end
        bodies[k] = held.bodies[k]
    end
    local body = concat(bodies)
    if adlerHex(body) ~= held.id then return nil, L.code.parts_mismatch end
    return PREFIX .. body
end
function code.decoder(text)
    local packed = string.gsub(tostring(text or ""), "%s+", "")
    if packed:sub(1, #PART_PREFIX) == PART_PREFIX then
        local held
        for _, read in ipairs(code.parts(packed)) do
            if not read.part then return refused(read.why) end
            held = held or { id = read.part.id, n = read.part.n, bodies = {}, count = 0 }
            if read.part.id ~= held.id or read.part.n ~= held.n then return refused(L.code.parts_mixed) end
            if not held.bodies[read.part.k] then held.count = held.count + 1 end
            held.bodies[read.part.k] = read.part.body
        end
        local joined, why = code.join(held)
        if not joined then return refused(why) end
        packed = joined
    end
    if packed:sub(1, #PREFIX) ~= PREFIX then
        local other = string.match(packed, "^LF(%d+):")
        return refused(other and zo_strformat(L.code.newer_code, other) or L.code.not_a_code)
    end
    local bytes, why = unbase64(packed:sub(#PREFIX + 1))
    if not bytes then return refused(why) end
    local ok, lzma = pcall(lzmaDecoder, bytes, 1, #bytes - 4)
    if not ok then return refused(lzma) end
    local out, n, a, b, at, chunks, reader = nil, 0, 1, 0, 0, {}, nil
    return steps({
        function(left)
            local fine, done, unpacked, total = pcall(lzma, math.ceil(left))
            if not fine then return nil, done end
            if not done then return false, unpacked, left end
            out, n = unpacked, total
            return true, nil, 1
        end,
        function(left)
            local stop = math.min(n, at + math.ceil(left * READ_RATE))
            a, b = adlerOn(out, at + 1, stop, a, b)
            local used = (stop - at) / READ_RATE
            at = stop
            if at < n then return false, nil, used end
            local stored = 0
            for k = #bytes - 3, #bytes do stored = stored * 256 + bytes[k] end
            if b * 65536 + a ~= stored then return nil, DAMAGED end
            at = 0
            return true, nil, used
        end,
        function(left)
            local stop = math.min(n, at + math.ceil(left * READ_RATE))
            for i = at + 1, stop, 4096 do chunks[#chunks + 1] = char(unpack(out, i, math.min(i + 4095, stop))) end
            local used = (stop - at) / READ_RATE
            at = stop
            if at < n then return false, nil, used end
            reader = jsonReader(concat(chunks))
            return true, nil, used
        end,
        function(left)
            local read, done, value, used = pcall(reader, math.ceil(left * READ_RATE))
            if not read then return nil, zo_strformat(L.code.no_layout_because, tostring(done)) end
            if not done then return false, value, used / READ_RATE end
            if type(value) ~= "table" or value.format ~= "letsfurnish.house" then return nil, L.code.no_layout end
            local major = tonumber(string.match(tostring(value.version), "^(%d+)%.%d+$"))
            if not major then return nil, L.code.no_version end
            if major > 2 then return nil, zo_strformat(L.code.newer_layout, tostring(value.version)) end
            if major < 2 then return nil, L.house.code_earlier end
            return true, value, used / READ_RATE
        end,
    }, function(i, share)
        if i == 1 then return 0.6 * (share or 0) end
        if i == 4 then return 0.65 + 0.35 * (share or 0) end
        return 0.6 + 0.025 * (i - 1)
    end)
end
code.fromJson, code.toJson, code.jsonWriter, code.jsonReader = fromJson, toJson, jsonWriter, jsonReader
code.lzmaEncoder, code.lzmaDecoder, code.CARRIES = lzmaEncoder, lzmaDecoder, CARRIES
