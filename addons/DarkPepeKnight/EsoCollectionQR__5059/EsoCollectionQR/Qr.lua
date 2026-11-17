-- QR-кодировщик: алфавитно-цифровой режим, уровень коррекции M, версии 1–25 (по умолчанию не больше MAX_VERSION).
-- Без битовых операций: в ESO нет библиотеки bit, а этот же файл проверяется в тестах приложения через LuaJ.
EsoCollectionQR = EsoCollectionQR or {}
local Q = {}
EsoCollectionQR.Qr = Q

local ALNUM = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:"
local ALIDX = {}
for i = 1, #ALNUM do ALIDX[ALNUM:sub(i, i)] = i - 1 end
Q.ALNUM = ALNUM
-- коды крупнее версии 20 ZXing уже плохо находит даже на чистой картинке, а с камеры по монитору — тем более
Q.MAX_VERSION = 20
local TABLE_VERSIONS = 25

-- уровень M: {кодовых слов коррекции на блок, блоков группы 1, слов данных в них, блоков группы 2, слов данных в них}
local EC_M = {
  { 10, 1, 16, 0, 0 }, { 16, 1, 28, 0, 0 }, { 26, 1, 44, 0, 0 }, { 18, 2, 32, 0, 0 }, { 24, 2, 43, 0, 0 },
  { 16, 4, 27, 0, 0 }, { 18, 4, 31, 0, 0 }, { 22, 2, 38, 2, 39 }, { 22, 3, 36, 2, 37 }, { 26, 4, 43, 1, 44 },
  { 30, 1, 50, 4, 51 }, { 22, 6, 36, 2, 37 }, { 22, 8, 37, 1, 38 }, { 24, 4, 40, 5, 41 }, { 24, 5, 41, 5, 42 },
  { 28, 7, 45, 3, 46 }, { 28, 10, 46, 1, 47 }, { 26, 9, 43, 4, 44 }, { 26, 3, 44, 11, 45 }, { 26, 3, 41, 13, 42 },
  { 26, 17, 42, 0, 0 }, { 28, 17, 46, 0, 0 }, { 28, 4, 47, 14, 48 }, { 28, 6, 45, 14, 46 }, { 28, 8, 47, 13, 48 },
}
local ALIGN = {
  {}, { 6, 18 }, { 6, 22 }, { 6, 26 }, { 6, 30 }, { 6, 34 }, { 6, 22, 38 }, { 6, 24, 42 }, { 6, 26, 46 }, { 6, 28, 50 },
  { 6, 30, 54 }, { 6, 32, 58 }, { 6, 34, 62 }, { 6, 26, 46, 66 }, { 6, 26, 48, 70 }, { 6, 26, 50, 74 }, { 6, 30, 54, 78 },
  { 6, 30, 56, 82 }, { 6, 30, 58, 86 }, { 6, 34, 62, 90 }, { 6, 28, 50, 72, 94 }, { 6, 26, 50, 74, 98 },
  { 6, 30, 54, 78, 102 }, { 6, 28, 54, 80, 106 }, { 6, 32, 58, 84, 110 },
}
local REMAINDER = { 0, 7, 7, 7, 7, 7, 0, 0, 0, 0, 0, 0, 0, 3, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4 }

local function bxor(a, b)
  local r, p = 0, 1
  while a > 0 or b > 0 do
    local x, y = a % 2, b % 2
    if x ~= y then r = r + p end
    a, b, p = (a - x) / 2, (b - y) / 2, p * 2
  end
  return r
end

local function bit(v, i) return math.floor(v / 2 ^ i) % 2 end

-- поле Галуа GF(256) с порождающим многочленом 0x11D
local EXP, LOG = {}, {}
do
  local x = 1
  for i = 0, 254 do
    EXP[i] = x
    LOG[x] = i
    x = x * 2
    if x >= 256 then x = bxor(x, 285) end
  end
  for i = 255, 511 do EXP[i] = EXP[i - 255] end
end
local function gmul(a, b) if a == 0 or b == 0 then return 0 end return EXP[LOG[a] + LOG[b]] end

local genCache = {}
local function generator(n)
  if genCache[n] then return genCache[n] end
  local g = { 1 }
  for i = 0, n - 1 do
    local r = {}
    for j = 1, #g + 1 do r[j] = 0 end
    for j = 1, #g do
      r[j] = bxor(r[j], g[j])
      r[j + 1] = bxor(r[j + 1], gmul(g[j], EXP[i]))
    end
    g = r
  end
  genCache[n] = g
  return g
end

-- кодовые слова коррекции Рида — Соломона для блока данных
local function ecc(data, n)
  local g, res = generator(n), {}
  for i = 1, n do res[i] = 0 end
  for _, d in ipairs(data) do
    local f = bxor(d, res[1])
    table.remove(res, 1)
    res[n] = 0
    if f ~= 0 then for j = 1, n do res[j] = bxor(res[j], gmul(g[j + 1], f)) end end
  end
  return res
end

local function dataCount(v) local e = EC_M[v] return e[2] * e[3] + e[4] * e[5] end
local function ccBits(v) return v <= 9 and 9 or 11 end
local function bitsFor(v, len) return 4 + ccBits(v) + 11 * math.floor(len / 2) + 6 * (len % 2) end

--- Сколько символов помещается в код версии v
function Q.Capacity(v)
  local cap = dataCount(v) * 8 - 4 - ccBits(v)
  local n = math.floor(cap / 11) * 2
  if cap % 11 >= 6 then n = n + 1 end
  return n
end

local function push(bits, val, len)
  for i = len - 1, 0, -1 do bits[#bits + 1] = bit(val, i) end
end

local function codewords(text, v)
  local bits = {}
  push(bits, 2, 4)
  push(bits, #text, ccBits(v))
  local i = 1
  while i <= #text do
    local a = ALIDX[text:sub(i, i)]
    if i < #text then
      push(bits, a * 45 + ALIDX[text:sub(i + 1, i + 1)], 11)
      i = i + 2
    else
      push(bits, a, 6)
      i = i + 1
    end
  end
  local total = dataCount(v) * 8
  for _ = 1, math.min(4, total - #bits) do bits[#bits + 1] = 0 end
  while #bits % 8 ~= 0 do bits[#bits + 1] = 0 end
  local cw = {}
  for k = 1, #bits, 8 do
    local x = 0
    for t = 0, 7 do x = x * 2 + bits[k + t] end
    cw[#cw + 1] = x
  end
  local pad, p = { 236, 17 }, 1
  while #cw < dataCount(v) do
    cw[#cw + 1] = pad[p]
    p = 3 - p
  end
  return cw
end

-- блоки данных и коррекции, перемешанные по стандарту
local function finalBits(v, cw)
  local e = EC_M[v]
  local blocks, eccs, pos = {}, {}, 1
  for gi = 0, 1 do
    for _ = 1, e[2 + gi * 2] do
      local b = {}
      for k = 1, e[3 + gi * 2] do
        b[k] = cw[pos]
        pos = pos + 1
      end
      blocks[#blocks + 1] = b
      eccs[#eccs + 1] = ecc(b, e[1])
    end
  end
  local out = {}
  for k = 1, math.max(e[3], e[5]) do
    for _, b in ipairs(blocks) do if b[k] then out[#out + 1] = b[k] end end
  end
  for k = 1, e[1] do
    for _, c in ipairs(eccs) do out[#out + 1] = c[k] end
  end
  local bits = {}
  for _, x in ipairs(out) do push(bits, x, 8) end
  for _ = 1, REMAINDER[v] do bits[#bits + 1] = 0 end
  return bits
end

local function bchFormat(mask)
  local data = mask -- уровень M кодируется битами 00
  local d = data * 1024
  for i = 14, 10, -1 do
    if bit(d, i) == 1 then d = bxor(d, 1335 * 2 ^ (i - 10)) end
  end
  return bxor(data * 1024 + d, 21522)
end

local function bchVersion(v)
  local d = v * 4096
  for i = 17, 12, -1 do
    if bit(d, i) == 1 then d = bxor(d, 7973 * 2 ^ (i - 12)) end
  end
  return v * 4096 + d
end

local function maskOn(m, r, c)
  if m == 0 then return (r + c) % 2 == 0
  elseif m == 1 then return r % 2 == 0
  elseif m == 2 then return c % 3 == 0
  elseif m == 3 then return (r + c) % 3 == 0
  elseif m == 4 then return (math.floor(c / 3) + math.floor(r / 2)) % 2 == 0
  elseif m == 5 then return (r * c) % 2 + (r * c) % 3 == 0
  elseif m == 6 then return ((r * c) % 2 + (r * c) % 3) % 2 == 0
  end
  return ((r + c) % 2 + (r * c) % 3) % 2 == 0
end

local function penalty(M, n)
  local p, dark = 0, 0
  for dir = 0, 1 do
    for a = 0, n - 1 do
      local seq, run, prev = {}, 0, -1
      for b = 0, n - 1 do
        local v = dir == 0 and M[a * n + b] or M[b * n + a]
        seq[b + 1] = v
        if v == prev then
          run = run + 1
        else
          if run >= 5 then p = p + run - 2 end
          run, prev = 1, v
        end
      end
      if run >= 5 then p = p + run - 2 end
      -- узор, похожий на поисковый: 1:1:3:1:1 и четыре светлых модуля с одной стороны
      for b = 1, n - 6 do
        if seq[b] == 1 and seq[b + 1] == 0 and seq[b + 2] == 1 and seq[b + 3] == 1 and seq[b + 4] == 1 and seq[b + 5] == 0 and seq[b + 6] == 1 then
          local before, after = true, true
          for t = 1, 4 do
            if b - t >= 1 and seq[b - t] == 1 then before = false end
            if b + 6 + t <= n and seq[b + 6 + t] == 1 then after = false end
          end
          if before or after then p = p + 40 end
        end
      end
    end
  end
  for r = 0, n - 1 do
    for c = 0, n - 1 do
      local v = M[r * n + c]
      dark = dark + v
      if r < n - 1 and c < n - 1 and v == M[r * n + c + 1] and v == M[(r + 1) * n + c] and v == M[(r + 1) * n + c + 1] then p = p + 3 end
    end
  end
  return p + math.floor(math.abs(dark * 20 - n * n * 10) / (n * n)) * 10
end

--- Кодирует строку из символов ALNUM. Возвращает строки модулей: rows[r][c] = 1 — тёмный.
--- forceMask — номер маски; без него выбирается лучшая. Вторым и третьим значением возвращаются лучшая и вторая по качеству маски:
--- ZXing не находит примерно 2–5% кодов с выбранной маской, а с другой маской тот же текст читается.
function Q.Encode(text, forceMask)
  for i = 1, #text do
    if not ALIDX[text:sub(i, i)] then error("QR: недопустимый символ " .. text:sub(i, i)) end
  end
  local v = 1
  while bitsFor(v, #text) > dataCount(v) * 8 do
    v = v + 1
    if v > TABLE_VERSIONS then error("QR: слишком длинный текст") end
  end
  local n = 17 + 4 * v
  local M, F = {}, {}
  for i = 0, n * n - 1 do M[i] = 0 end
  local function set(r, c, val) M[r * n + c] = val; F[r * n + c] = true end

  local function finder(r, c)
    for dr = -1, 7 do
      for dc = -1, 7 do
        local rr, cc = r + dr, c + dc
        if rr >= 0 and rr < n and cc >= 0 and cc < n then
          local inside = dr >= 0 and dr <= 6 and dc >= 0 and dc <= 6
          local on = inside and (dr == 0 or dr == 6 or dc == 0 or dc == 6 or (dr >= 2 and dr <= 4 and dc >= 2 and dc <= 4))
          set(rr, cc, on and 1 or 0)
        end
      end
    end
  end
  finder(0, 0)
  finder(0, n - 7)
  finder(n - 7, 0)

  local al = ALIGN[v]
  for i, r in ipairs(al) do
    for j, c in ipairs(al) do
      local corner = (i == 1 and j == 1) or (i == 1 and j == #al) or (i == #al and j == 1)
      if not corner then
        for dr = -2, 2 do
          for dc = -2, 2 do set(r + dr, c + dc, math.max(math.abs(dr), math.abs(dc)) ~= 1 and 1 or 0) end
        end
      end
    end
  end
  for i = 8, n - 9 do
    set(6, i, (i + 1) % 2)
    set(i, 6, (i + 1) % 2)
  end

  local function drawFormat(mask)
    local b = bchFormat(mask)
    for i = 0, 5 do set(i, 8, bit(b, i)) end
    set(7, 8, bit(b, 6))
    set(8, 8, bit(b, 7))
    set(8, 7, bit(b, 8))
    for i = 9, 14 do set(8, 14 - i, bit(b, i)) end
    for i = 0, 7 do set(8, n - 1 - i, bit(b, i)) end
    for i = 8, 14 do set(n - 15 + i, 8, bit(b, i)) end
    set(n - 8, 8, 1)
  end
  drawFormat(0)
  if v >= 7 then
    local b = bchVersion(v)
    for i = 0, 17 do
      local a, c = n - 11 + i % 3, math.floor(i / 3)
      set(c, a, bit(b, i))
      set(a, c, bit(b, i))
    end
  end

  -- данные змейкой снизу вверх по парам столбцов
  local bits, i = finalBits(v, codewords(text, v)), 1
  local right = n - 1
  while right >= 1 do
    if right == 6 then right = 5 end
    local upward = math.floor((right + 1) / 2) % 2 == 0
    for vert = 0, n - 1 do
      for j = 0, 1 do
        local c = right - j
        local r = upward and (n - 1 - vert) or vert
        if not F[r * n + c] then
          if i <= #bits then M[r * n + c] = bits[i] end
          i = i + 1
        end
      end
    end
    right = right - 2
  end

  local function applyMask(m)
    for r = 0, n - 1 do
      for c = 0, n - 1 do
        if not F[r * n + c] and maskOn(m, r, c) then M[r * n + c] = 1 - M[r * n + c] end
      end
    end
  end
  local best, second, bestScore, secondScore = forceMask or 0, nil, nil, nil
  for m = 0, forceMask and -1 or 7 do
    applyMask(m)
    drawFormat(m)
    local s = penalty(M, n)
    if not bestScore or s < bestScore then
      second, secondScore = best, bestScore
      best, bestScore = m, s
    elseif not secondScore or s < secondScore then
      second, secondScore = m, s
    end
    applyMask(m)
  end
  applyMask(best)
  drawFormat(best)

  local rows = {}
  for r = 0, n - 1 do
    local row = {}
    for c = 0, n - 1 do row[c + 1] = M[r * n + c] end
    rows[r + 1] = row
  end
  return rows, best, second
end
