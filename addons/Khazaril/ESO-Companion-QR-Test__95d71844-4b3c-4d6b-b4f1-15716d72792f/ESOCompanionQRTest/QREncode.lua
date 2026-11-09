-- QREncode.lua
-- Minimal QR Code encoder (byte mode, ECC levels L and M, versions 1-40) in pure Lua 5.1.
-- Written for the ESO Companion addon. Algorithm follows ISO/IEC 18004.
--
-- Usage:
--   local qr = ESOC_QR.Encode(text, "L")        -- or "M"
--   qr.size, qr.version, qr.mask, qr.modules     -- modules[y * size + x + 1] = 1 (dark) or 0
--   ESOC_QR.Encode(text, "L", { yield = fn })   -- fn is called at checkpoints (for spreading work over frames)

local floor, abs = math.floor, math.abs

ESOC_QR = ESOC_QR or {}
local QR = ESOC_QR

---------------------------------------------------------------------------
-- Bit helpers (ESO provides BitXor; fall back to arithmetic elsewhere)
---------------------------------------------------------------------------
local function bxorArith(a, b)
    local r, bit = 0, 1
    while a > 0 or b > 0 do
        local x, y = a % 2, b % 2
        if x ~= y then r = r + bit end
        a, b, bit = floor(a / 2), floor(b / 2), bit * 2
    end
    return r
end
local bxor = BitXor or bxorArith
QR._setXor = function(fn) bxor = fn or bxorArith end -- for testing

local function getBit(x, i)
    return floor(x / 2 ^ i) % 2
end

---------------------------------------------------------------------------
-- Error correction table: [level][version] = { eccPerBlock, blocks1, data1, blocks2, data2 }
---------------------------------------------------------------------------
local ECC = {
    L = {
        {7,1,19,0,0},{10,1,34,0,0},{15,1,55,0,0},{20,1,80,0,0},{26,1,108,0,0},
        {18,2,68,0,0},{20,2,78,0,0},{24,2,97,0,0},{30,2,116,0,0},{18,2,68,2,69},
        {20,4,81,0,0},{24,2,92,2,93},{26,4,107,0,0},{30,3,115,1,116},{22,5,87,1,88},
        {24,5,98,1,99},{28,1,107,5,108},{30,5,120,1,121},{28,3,113,4,114},{28,3,107,5,108},
        {28,4,116,4,117},{28,2,111,7,112},{30,4,121,5,122},{30,6,117,4,118},{26,8,106,4,107},
        {28,10,114,2,115},{30,8,122,4,123},{30,3,117,10,118},{30,7,116,7,117},{30,5,115,10,116},
        {30,13,115,3,116},{30,17,115,0,0},{30,17,115,1,116},{30,13,115,6,116},{30,12,121,7,122},
        {30,6,121,14,122},{30,17,122,4,123},{30,4,122,18,123},{30,20,117,4,118},{30,19,118,6,119},
    },
    M = {
        {10,1,16,0,0},{16,1,28,0,0},{26,1,44,0,0},{18,2,32,0,0},{24,2,43,0,0},
        {16,4,27,0,0},{18,4,31,0,0},{22,2,38,2,39},{22,3,36,2,37},{26,4,43,1,44},
        {30,1,50,4,51},{22,6,36,2,37},{22,8,37,1,38},{24,4,40,5,41},{24,5,41,5,42},
        {28,7,45,3,46},{28,10,46,1,47},{26,9,43,4,44},{26,3,44,11,45},{26,3,41,13,42},
        {26,17,42,0,0},{28,17,46,0,0},{28,4,47,14,48},{28,6,45,14,46},{28,8,47,13,48},
        {28,19,46,4,47},{28,22,45,3,46},{28,3,45,23,46},{28,21,45,7,46},{28,19,47,10,48},
        {28,2,46,29,47},{28,10,46,23,47},{28,14,46,21,47},{28,14,46,23,47},{28,12,47,26,48},
        {28,6,47,34,48},{28,29,46,14,47},{28,13,46,32,47},{28,40,47,7,48},{28,18,47,31,48},
    },
}
QR._ECC = ECC
local FORMAT_ECC_BITS = { L = 1, M = 0 }

local function numRawDataModules(ver)
    local result = (16 * ver + 128) * ver + 64
    if ver >= 2 then
        local numAlign = floor(ver / 7) + 2
        result = result - ((25 * numAlign - 10) * numAlign - 55)
        if ver >= 7 then result = result - 36 end
    end
    return result
end
QR._numRawDataModules = numRawDataModules

local function numDataCodewords(ver, ecc)
    local e = ECC[ecc][ver]
    return e[2] * e[3] + e[4] * e[5]
end
QR.NumDataCodewords = numDataCodewords

local function charCountBits(ver)
    return ver <= 9 and 8 or 16
end

-- Largest byte payload that fits in a version / level
function QR.MaxBytes(ver, ecc)
    return floor((numDataCodewords(ver, ecc) * 8 - 4 - charCountBits(ver)) / 8)
end

---------------------------------------------------------------------------
-- Galois field GF(256) and Reed-Solomon
---------------------------------------------------------------------------
local EXP, LOG = {}, {}
do
    local x = 1
    for i = 0, 254 do
        EXP[i] = x
        LOG[x] = i
        x = x * 2
        if x >= 256 then x = bxorArith(x, 0x11D) end
    end
end

local function gfMul(a, b)
    if a == 0 or b == 0 then return 0 end
    return EXP[(LOG[a] + LOG[b]) % 255]
end

local divisorCache = {}
local function rsDivisor(degree)
    if divisorCache[degree] then return divisorCache[degree] end
    local result = {}
    for i = 1, degree do result[i] = 0 end
    result[degree] = 1
    local root = 1
    for _ = 0, degree - 1 do
        for j = 1, degree do
            result[j] = gfMul(result[j], root)
            if j < degree then result[j] = bxor(result[j], result[j + 1]) end
        end
        root = gfMul(root, 2)
    end
    divisorCache[degree] = result
    return result
end

local function rsRemainder(data, first, last, divisor)
    local n = #divisor
    local res = {}
    for i = 1, n do res[i] = 0 end
    for k = first, last do
        local factor = bxor(data[k], res[1])
        for i = 1, n - 1 do res[i] = res[i + 1] end
        res[n] = 0
        if factor ~= 0 then
            for i = 1, n do
                res[i] = bxor(res[i], gfMul(divisor[i], factor))
            end
        end
    end
    return res
end

---------------------------------------------------------------------------
-- Encoder
---------------------------------------------------------------------------
local function alignmentPositions(ver, size)
    if ver == 1 then return {} end
    local numAlign = floor(ver / 7) + 2
    local step
    if ver == 32 then
        step = 26
    else
        step = math.ceil((ver * 4 + 4) / (numAlign * 2 - 2)) * 2
    end
    local result = { 6 }
    local pos = size - 7
    local tail = {}
    for _ = 1, numAlign - 1 do
        table.insert(tail, 1, pos)
        pos = pos - step
    end
    for _, p in ipairs(tail) do result[#result + 1] = p end
    return result
end

local MASKS = {
    [0] = function(x, y) return (x + y) % 2 == 0 end,
    [1] = function(x, y) return y % 2 == 0 end,
    [2] = function(x, y) return x % 3 == 0 end,
    [3] = function(x, y) return (x + y) % 3 == 0 end,
    [4] = function(x, y) return (floor(x / 3) + floor(y / 2)) % 2 == 0 end,
    [5] = function(x, y) return (x * y) % 2 + (x * y) % 3 == 0 end,
    [6] = function(x, y) return ((x * y) % 2 + (x * y) % 3) % 2 == 0 end,
    [7] = function(x, y) return ((x + y) % 2 + (x * y) % 3) % 2 == 0 end,
}

-- Scratch tables reused by every encode. Console add-ons share a small memory budget, so the
-- encoder allocates its big working lists once instead of once per QR code.
-- NOTE: the returned qr.modules is one of these shared tables; use it before the next Encode.
local CW, FINAL, M, F = {}, {}, {}, {}

function QR.Encode(text, ecc, opts)
    ecc = ecc or "L"
    opts = opts or {}
    local yield = opts.yield or function() end
    local len = #text

    -- 1. Pick the smallest version that fits
    local ver
    for v = opts.minVersion or 1, 40 do
        if len <= QR.MaxBytes(v, ecc) then ver = v break end
    end
    if not ver then return nil, "too much data" end

    -- 2. Bit stream: mode, count, data, terminator, padding -- written straight into bytes
    local codewords = CW
    local nCw, acc, nAcc, nBits = 0, 0, 0, 0
    local function appendBits(val, n)
        for i = n - 1, 0, -1 do
            acc = acc * 2 + getBit(val, i)
            nAcc = nAcc + 1
            nBits = nBits + 1
            if nAcc == 8 then
                nCw = nCw + 1
                codewords[nCw] = acc
                acc, nAcc = 0, 0
            end
        end
    end
    appendBits(4, 4) -- byte mode 0100
    appendBits(len, charCountBits(ver))
    for i = 1, len do appendBits(text:byte(i), 8) end
    local dataCw = numDataCodewords(ver, ecc)
    local capBits = dataCw * 8
    appendBits(0, math.min(4, capBits - nBits)) -- terminator
    if nAcc > 0 then appendBits(0, 8 - nAcc) end -- pad to a whole byte
    local pad = 0xEC
    while nCw < dataCw do
        nCw = nCw + 1
        codewords[nCw] = pad
        pad = (pad == 0xEC) and 0x11 or 0xEC
    end

    -- 3. Split into blocks, add error correction, interleave
    local e = ECC[ecc][ver]
    local eccLen, b1, d1, b2, d2 = e[1], e[2], e[3], e[4], e[5]
    local divisor = rsDivisor(eccLen)
    local blocks = {}
    local k = 1
    for bi = 1, b1 + b2 do
        local dlen = (bi <= b1) and d1 or d2
        blocks[bi] = { first = k, last = k + dlen - 1, ecc = rsRemainder(codewords, k, k + dlen - 1, divisor) }
        k = k + dlen
        if bi % 8 == 0 then yield() end
    end
    local final, nFinal = FINAL, 0
    local maxD = math.max(d1, d2)
    for i = 0, maxD - 1 do
        for bi = 1, #blocks do
            local blk = blocks[bi]
            if blk.first + i <= blk.last then nFinal = nFinal + 1 final[nFinal] = codewords[blk.first + i] end
        end
    end
    for i = 1, eccLen do
        for bi = 1, #blocks do nFinal = nFinal + 1 final[nFinal] = blocks[bi].ecc[i] end
    end
    blocks = nil
    yield()

    -- 4. Draw function patterns
    local size = ver * 4 + 17
    local m, f = M, F
    for i = 1, size * size do m[i] = 0 f[i] = false end
    local function setF(x, y, dark)
        local idx = y * size + x + 1
        m[idx] = dark and 1 or 0
        f[idx] = true
    end
    for i = 0, size - 1 do
        setF(6, i, i % 2 == 0)
        setF(i, 6, i % 2 == 0)
    end
    local function finder(cx, cy)
        for dy = -4, 4 do
            for dx = -4, 4 do
                local x, y = cx + dx, cy + dy
                if x >= 0 and x < size and y >= 0 and y < size then
                    local d = math.max(abs(dx), abs(dy))
                    setF(x, y, d ~= 2 and d ~= 4)
                end
            end
        end
    end
    finder(3, 3)
    finder(size - 4, 3)
    finder(3, size - 4)
    local ap = alignmentPositions(ver, size)
    local na = #ap
    for i = 1, na do
        for j = 1, na do
            if not ((i == 1 and j == 1) or (i == 1 and j == na) or (i == na and j == 1)) then
                for dy = -2, 2 do
                    for dx = -2, 2 do
                        setF(ap[i] + dx, ap[j] + dy, math.max(abs(dx), abs(dy)) ~= 1)
                    end
                end
            end
        end
    end
    local function drawFormat(mask)
        local data = FORMAT_ECC_BITS[ecc] * 8 + mask
        local rem = data
        for _ = 1, 10 do rem = bxor(rem * 2, floor(rem / 512) * 0x537) end
        local fb = bxor(data * 1024 + rem, 0x5412)
        for i = 0, 5 do setF(8, i, getBit(fb, i) == 1) end
        setF(8, 7, getBit(fb, 6) == 1)
        setF(8, 8, getBit(fb, 7) == 1)
        setF(7, 8, getBit(fb, 8) == 1)
        for i = 9, 14 do setF(14 - i, 8, getBit(fb, i) == 1) end
        for i = 0, 7 do setF(size - 1 - i, 8, getBit(fb, i) == 1) end
        for i = 8, 14 do setF(8, size - 15 + i, getBit(fb, i) == 1) end
        setF(8, size - 8, true)
    end
    drawFormat(0)
    if ver >= 7 then
        local rem = ver
        for _ = 1, 12 do rem = bxor(rem * 2, floor(rem / 2048) * 0x1F25) end
        local vb = ver * 4096 + rem
        for i = 0, 17 do
            local bit = getBit(vb, i) == 1
            local a = size - 11 + i % 3
            local b = floor(i / 3)
            setF(a, b, bit)
            setF(b, a, bit)
        end
    end

    -- 5. Place data in zigzag
    local totalBits = nFinal * 8
    local i = 0
    local right = size - 1
    while right >= 1 do
        if right == 6 then right = 5 end
        local upward = floor((right + 1) / 2) % 2 == 0
        for vert = 0, size - 1 do
            for j = 0, 1 do
                local x = right - j
                local y = upward and (size - 1 - vert) or vert
                local idx = y * size + x + 1
                if not f[idx] and i < totalBits then
                    m[idx] = getBit(final[floor(i / 8) + 1], 7 - i % 8)
                    i = i + 1
                end
            end
        end
        right = right - 2
    end
    yield()

    -- 6. Masking: try all 8, keep the lowest penalty
    local function applyMask(mask)
        local fn = MASKS[mask]
        for y = 0, size - 1 do
            local row = y * size
            for x = 0, size - 1 do
                local idx = row + x + 1
                if not f[idx] and fn(x, y) then m[idx] = 1 - m[idx] end
            end
        end
    end

    -- One row or column: modules m[start], m[start + step], ... (no closures: no garbage)
    local function linePenalty(start, step)
        local p = 0
        -- rule 1: runs of 5+
        local runColor, runLen = -1, 0
        for t = 0, size - 1 do
            local c = m[start + t * step]
            if c == runColor then
                runLen = runLen + 1
                if runLen == 5 then p = p + 3 elseif runLen > 5 then p = p + 1 end
            else
                runColor, runLen = c, 1
            end
        end
        -- rule 3: finder-like 1011101 with 4 light modules on one side
        for t = 0, size - 7 do
            local b0 = start + t * step
            if m[b0] == 1 and m[b0 + step] == 0 and m[b0 + 2 * step] == 1 and m[b0 + 3 * step] == 1
                and m[b0 + 4 * step] == 1 and m[b0 + 5 * step] == 0 and m[b0 + 6 * step] == 1 then
                local before, after = true, true
                for q = 1, 4 do
                    local a, b = t - q, t + 6 + q
                    if a >= 0 and m[start + a * step] == 1 then before = false end
                    if b < size and m[start + b * step] == 1 then after = false end
                end
                if before then p = p + 40 end
                if after then p = p + 40 end
            end
        end
        return p
    end

    local function penalty()
        local p = 0
        for y = 0, size - 1 do p = p + linePenalty(y * size + 1, 1) end
        for x = 0, size - 1 do p = p + linePenalty(x + 1, size) end
        local dark = 0
        for y = 0, size - 2 do
            for x = 0, size - 2 do
                local idx = y * size + x + 1
                local c = m[idx]
                if c == m[idx + 1] and c == m[idx + size] and c == m[idx + size + 1] then p = p + 3 end
            end
        end
        for idx = 1, size * size do dark = dark + m[idx] end
        local total = size * size
        local percent = dark * 100 / total
        p = p + floor(abs(percent - 50) / 5) * 10
        return p
    end

    local bestMask = opts.mask
    if bestMask == nil then
        local best = math.huge
        for mask = 0, 7 do
            applyMask(mask)
            drawFormat(mask)
            local p = penalty()
            if p < best then best, bestMask = p, mask end
            applyMask(mask)
            yield()
        end
    end
    applyMask(bestMask)
    drawFormat(bestMask)

    return { size = size, version = ver, mask = bestMask, ecc = ecc, modules = m, bytes = len }
end
