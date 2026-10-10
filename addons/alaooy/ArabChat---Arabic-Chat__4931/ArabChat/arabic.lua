-- ArabChat / arabic.lua
-- Arabic contextual shaping + simplified bidi reordering.
-- ESO's text renderer draws every character left-to-right and does no
-- joining, so Arabic must be converted to "visual order" presentation forms
-- (U+FE70-U+FEFF) before it is drawn. Pure Lua 5.1: no utf8 library.

ArabChat = ArabChat or {}
local M = {}
M.version = "1.0.2"
M.lastReason = ""
ArabChat.Arabic = M

local char, byte, floor, find, sub = string.char, string.byte, math.floor, string.find, string.sub
local concat = table.concat

-- true if the text contains any byte of U+0600-U+06FF (lead bytes 0xD8-0xDB).
-- Plain byte scan on purpose: no string-pattern ranges, no utf8 library.
local function hasArabicBytes(text)
  if type(text) ~= "string" then return false end
  for i = 1, #text do
    local b = byte(text, i)
    if b >= 216 and b <= 219 then return true end
  end
  return false
end
M.hasArabic = hasArabicBytes

-- [base] = { isolated, final, initial, medial }  (no initial/medial = right-joining only)
local FORMS = {
  [0x0621] = { 0xFE80 },
  [0x0622] = { 0xFE81, 0xFE82 },
  [0x0623] = { 0xFE83, 0xFE84 },
  [0x0624] = { 0xFE85, 0xFE86 },
  [0x0625] = { 0xFE87, 0xFE88 },
  [0x0626] = { 0xFE89, 0xFE8A, 0xFE8B, 0xFE8C },
  [0x0627] = { 0xFE8D, 0xFE8E },
  [0x0628] = { 0xFE8F, 0xFE90, 0xFE91, 0xFE92 },
  [0x0629] = { 0xFE93, 0xFE94 },
  [0x062A] = { 0xFE95, 0xFE96, 0xFE97, 0xFE98 },
  [0x062B] = { 0xFE99, 0xFE9A, 0xFE9B, 0xFE9C },
  [0x062C] = { 0xFE9D, 0xFE9E, 0xFE9F, 0xFEA0 },
  [0x062D] = { 0xFEA1, 0xFEA2, 0xFEA3, 0xFEA4 },
  [0x062E] = { 0xFEA5, 0xFEA6, 0xFEA7, 0xFEA8 },
  [0x062F] = { 0xFEA9, 0xFEAA },
  [0x0630] = { 0xFEAB, 0xFEAC },
  [0x0631] = { 0xFEAD, 0xFEAE },
  [0x0632] = { 0xFEAF, 0xFEB0 },
  [0x0633] = { 0xFEB1, 0xFEB2, 0xFEB3, 0xFEB4 },
  [0x0634] = { 0xFEB5, 0xFEB6, 0xFEB7, 0xFEB8 },
  [0x0635] = { 0xFEB9, 0xFEBA, 0xFEBB, 0xFEBC },
  [0x0636] = { 0xFEBD, 0xFEBE, 0xFEBF, 0xFEC0 },
  [0x0637] = { 0xFEC1, 0xFEC2, 0xFEC3, 0xFEC4 },
  [0x0638] = { 0xFEC5, 0xFEC6, 0xFEC7, 0xFEC8 },
  [0x0639] = { 0xFEC9, 0xFECA, 0xFECB, 0xFECC },
  [0x063A] = { 0xFECD, 0xFECE, 0xFECF, 0xFED0 },
  [0x0640] = { 0x0640, 0x0640, 0x0640, 0x0640 }, -- tatweel joins both sides
  [0x0641] = { 0xFED1, 0xFED2, 0xFED3, 0xFED4 },
  [0x0642] = { 0xFED5, 0xFED6, 0xFED7, 0xFED8 },
  [0x0643] = { 0xFED9, 0xFEDA, 0xFEDB, 0xFEDC },
  [0x0644] = { 0xFEDD, 0xFEDE, 0xFEDF, 0xFEE0 },
  [0x0645] = { 0xFEE1, 0xFEE2, 0xFEE3, 0xFEE4 },
  [0x0646] = { 0xFEE5, 0xFEE6, 0xFEE7, 0xFEE8 },
  [0x0647] = { 0xFEE9, 0xFEEA, 0xFEEB, 0xFEEC },
  [0x0648] = { 0xFEED, 0xFEEE },
  [0x0649] = { 0xFEEF, 0xFEF0 },
  [0x064A] = { 0xFEF1, 0xFEF2, 0xFEF3, 0xFEF4 },
}

-- lam + alef ligatures: [alef] = { isolated, final }
local LAM_ALEF = {
  [0x0622] = { 0xFEF5, 0xFEF6 },
  [0x0623] = { 0xFEF7, 0xFEF8 },
  [0x0625] = { 0xFEF9, 0xFEFA },
  [0x0627] = { 0xFEFB, 0xFEFC },
}

local MIRROR = {
  [0x28] = 0x29, [0x29] = 0x28, [0x5B] = 0x5D, [0x5D] = 0x5B,
  [0x7B] = 0x7D, [0x7D] = 0x7B, [0x3C] = 0x3E, [0x3E] = 0x3C,
}

local function encode(cp)
  if cp < 0x80 then return char(cp) end
  if cp < 0x800 then return char(0xC0 + floor(cp / 64), 0x80 + cp % 64) end
  return char(0xE0 + floor(cp / 4096), 0x80 + floor(cp / 64) % 64, 0x80 + cp % 64)
end

local function classify(cp)
  if cp >= 0x0600 and cp <= 0x06FF then
    if (cp >= 0x0660 and cp <= 0x0669) or (cp >= 0x06F0 and cp <= 0x06F9) then return "EN" end
    if (cp >= 0x064B and cp <= 0x065F) or cp == 0x0670 then return "M" end
    return "R"
  end
  if cp >= 0x0750 and cp <= 0x077F then return "R" end
  if (cp >= 0xFB50 and cp <= 0xFDFF) or (cp >= 0xFE70 and cp <= 0xFEFF) then return "R" end
  if cp >= 0x30 and cp <= 0x39 then return "EN" end
  if (cp >= 0x41 and cp <= 0x5A) or (cp >= 0x61 and cp <= 0x7A) then return "L" end
  if cp < 0xC0 then return "N" end
  if cp <= 0x24F then
    if cp == 0xD7 or cp == 0xF7 then return "N" end
    return "L"
  end
  if (cp >= 0x370 and cp <= 0x58F) or (cp >= 0x1E00 and cp <= 0x1FFF) then return "L" end
  if cp >= 0x3000 and cp < 0x1F000 then return "L" end
  return "N"
end

-- Split UTF-8 into items. Returns items, hasColorCodes.
-- Item: { cp = codepoint | nil, s = original bytes, cls = R/L/EN/N/T/M }
local function decode(text)
  local items, n, i, len = {}, 0, 1, #text
  local hasColor = false
  while i <= len do
    local b = byte(text, i)
    local item
    if b == 0x7C then -- '|' : ESO escape sequences
      local nb = sub(text, i + 1, i + 1)
      local s, e
      if nb == "H" then s, e = find(text, "^|H.-|h.-|h", i)
      elseif nb == "t" then s, e = find(text, "^|t.-|t", i)
      elseif nb == "c" or nb == "C" or nb == "r" or nb == "R" then hasColor = true end
      if s then
        item = { s = sub(text, s, e), cls = "T" }
        i = e + 1
      else
        item = { cp = b, s = "|", cls = "N" }
        i = i + 1
      end
    else
      local size, cp = 1, b
      if b >= 0xF0 then size = 4
      elseif b >= 0xE0 then size = 3
      elseif b >= 0xC0 then size = 2 end
      if size == 2 then
        cp = (b - 0xC0) * 64 + (byte(text, i + 1) or 0x80) - 0x80
      elseif size == 3 then
        cp = (b - 0xE0) * 4096 + ((byte(text, i + 1) or 0x80) - 0x80) * 64 + ((byte(text, i + 2) or 0x80) - 0x80)
      end
      item = { cp = cp, s = sub(text, i, i + size - 1), cls = classify(cp) }
      i = i + size
    end
    n = n + 1
    items[n] = item
  end
  return items, hasColor
end

-- Contextual shaping (logical order in, logical order out)
local function shape(items)
  local out = {}
  local n = #items
  local i = 1
  while i <= n do
    local it = items[i]
    local f = it.cp and FORMS[it.cp]
    if not f then
      out[#out + 1] = it
      i = i + 1
    else
      local prev = out[#out]
      local joinPrev = prev and prev.canNext
      local nxt = items[i + 1]
      local lig = (it.cp == 0x0644 and nxt and nxt.cp) and LAM_ALEF[nxt.cp]
      if lig then
        local cp = joinPrev and lig[2] or lig[1]
        out[#out + 1] = { cp = cp, s = encode(cp), cls = "R", canNext = false }
        i = i + 2
      else
        local canNext = false
        if f[3] then
          local nf = nxt and nxt.cp and FORMS[nxt.cp]
          canNext = (nf ~= nil and nf[2] ~= nil)
        end
        local cp
        if joinPrev and f[2] then
          cp = canNext and f[4] or f[2]
        else
          cp = canNext and f[3] or f[1]
        end
        out[#out + 1] = { cp = cp, s = encode(cp), cls = "R", canNext = canNext }
        i = i + 1
      end
    end
  end
  return out
end

-- Simplified UAX#9: resolve types, assign levels, reverse (rule L2).
local function reorder(items, baseRTL)
  local n = #items
  if n == 0 then return items end
  local types = {}
  for i = 1, n do
    local c = items[i].cls
    types[i] = (c == "T") and "L" or c
  end

  -- W4: single separator between two numbers stays part of the number
  for i = 2, n - 1 do
    local cp = items[i].cp
    if types[i] == "N" and (cp == 0x2C or cp == 0x2E or cp == 0x3A or cp == 0x2F)
       and types[i - 1] == "EN" and types[i + 1] == "EN" then
      types[i] = "EN"
    end
  end
  -- W7: numbers after strong L are L
  local lastStrong = baseRTL and "R" or "L"
  for i = 1, n do
    local t = types[i]
    if t == "R" or t == "L" then lastStrong = t
    elseif t == "EN" and lastStrong == "L" then types[i] = "L" end
  end
  local baseType = baseRTL and "R" or "L"

  -- N0: paired brackets take the direction of what they enclose
  local OPEN = { [0x28] = 0x29, [0x5B] = 0x5D, [0x7B] = 0x7D }
  local CLOSE = { [0x29] = true, [0x5D] = true, [0x7D] = true }
  local stack, bpairs = {}, {}
  for k = 1, n do
    local cp = items[k].cp
    if items[k].cls == "N" and cp then
      if OPEN[cp] then
        stack[#stack + 1] = { k, OPEN[cp] }
      elseif CLOSE[cp] then
        for sIdx = #stack, 1, -1 do
          if stack[sIdx][2] == cp then
            bpairs[#bpairs + 1] = { stack[sIdx][1], k }
            for t = #stack, sIdx, -1 do stack[t] = nil end
            break
          end
        end
      end
    end
  end
  table.sort(bpairs, function(a, b) return a[1] < b[1] end)
  for _, pr in ipairs(bpairs) do
    local o, c = pr[1], pr[2]
    local foundEmbed, foundOpp = false, false
    for k = o + 1, c - 1 do
      local t = types[k]
      if t == "EN" then t = "R" end
      if t == baseType then foundEmbed = true
      elseif t == "R" or t == "L" then foundOpp = true end
    end
    local res
    if foundEmbed then
      res = baseType
    elseif foundOpp then
      local ctx = baseType
      for k = o - 1, 1, -1 do
        local t = types[k]
        if t == "EN" then t = "R" end
        if t == "R" or t == "L" then ctx = t break end
      end
      res = ctx
    end
    if res then types[o] = res types[c] = res end
  end

  -- N1/N2: neutrals
  local i = 1
  while i <= n do
    if types[i] == "N" then
      local j = i
      while j + 1 <= n and types[j + 1] == "N" do j = j + 1 end
      local left = (i > 1) and types[i - 1] or baseType
      local right = (j < n) and types[j + 1] or baseType
      if left == "EN" then left = "R" end
      if right == "EN" then right = "R" end
      local res = (left == right) and left or baseType
      for k = i, j do types[k] = res end
      i = j + 1
    else
      i = i + 1
    end
  end

  -- levels
  local levels = {}
  local maxL, minOdd = 0, 99
  for k = 1, n do
    local t, lv = types[k], 0
    if baseRTL then
      lv = (t == "R") and 1 or 2
    else
      if t == "R" then lv = 1 elseif t == "EN" then lv = 2 end
    end
    levels[k] = lv
    if lv > maxL then maxL = lv end
    if lv % 2 == 1 and lv < minOdd then minOdd = lv end
    -- mirror brackets that end up inside right-to-left runs
    local cp = items[k].cp
    if lv % 2 == 1 and items[k].cls == "N" and cp and MIRROR[cp] then
      items[k] = { cp = MIRROR[cp], s = char(MIRROR[cp]), cls = "N" }
    end
  end
  if minOdd == 99 then return items end

  for lvl = maxL, minOdd, -1 do
    local a = 1
    while a <= n do
      if levels[a] >= lvl then
        local b = a
        while b + 1 <= n and levels[b + 1] >= lvl do b = b + 1 end
        local x, y = a, b
        while x < y do
          items[x], items[y] = items[y], items[x]
          levels[x], levels[y] = levels[y], levels[x]
          x, y = x + 1, y - 1
        end
        a = b + 1
      else
        a = a + 1
      end
    end
  end
  return items
end

local function join(items)
  local parts = {}
  for k = 1, #items do parts[k] = items[k].s end
  return concat(parts)
end

-- Break items into lines of at most `width` characters (word boundaries).
local function chunk(items, width)
  local lines, cur, curLen = {}, {}, 0
  local word, wordLen = {}, 0
  local function flushWord()
    if #word == 0 then return end
    if curLen > 0 and curLen + wordLen > width then
      lines[#lines + 1] = cur
      cur, curLen = {}, 0
    end
    for k = 1, #word do cur[#cur + 1] = word[k] end
    curLen = curLen + wordLen
    word, wordLen = {}, 0
  end
  for k = 1, #items do
    local it = items[k]
    word[#word + 1] = it
    wordLen = wordLen + ((it.cls == "T") and 8 or 1)
    if it.cp == 0x20 then flushWord() end
  end
  flushWord()
  if #cur > 0 then lines[#lines + 1] = cur end
  return lines
end

-- Public: logical Arabic text -> visual text the game can draw correctly.
-- opts.mode: "visual" (default: join + reorder) or "logical" (join only).
-- opts.width (number, 0 = off, visual mode only): wrap into lines of N characters.
function M.process(text, opts)
  M.lastReason = "ok"
  if type(text) ~= "string" or text == "" then M.lastReason = "empty" return text end
  if opts and opts.mode == "raw" then M.lastReason = "raw-mode" return text end
  if not hasArabicBytes(text) then M.lastReason = "no-arabic-bytes" return text end

  local items, hasColor = decode(text)
  if hasColor then M.lastReason = "color-codes" return text end
  local hasArabic = false
  for k = 1, #items do
    local it = items[k]
    if it.cp and ((it.cp >= 0xFB50 and it.cp <= 0xFDFF) or (it.cp >= 0xFE70 and it.cp <= 0xFEFF)) then
      M.lastReason = "already-visual"
      return text -- already in visual form (shaped by someone else): leave alone
    end
    if it.cls == "R" then hasArabic = true end
  end
  if not hasArabic then M.lastReason = "no-rtl-letters" return text end

  -- drop diacritics (tashkeel): they cannot be drawn correctly after reordering
  local clean = {}
  for k = 1, #items do
    if items[k].cls ~= "M" then clean[#clean + 1] = items[k] end
  end

  local baseRTL = false
  for k = 1, #clean do
    local c = clean[k].cls
    if c == "R" then baseRTL = true break end
    if c == "L" then break end
  end

  local shaped = shape(clean)
  -- "logical": only join letters; the game's own text engine does the RTL ordering
  if opts and opts.mode == "logical" then return join(shaped) end
  local width = opts and opts.width or 0
  if width and width > 0 then
    local lines = chunk(shaped, width)
    local out = {}
    for k = 1, #lines do out[k] = join(reorder(lines[k], baseRTL)) end
    return concat(out, "\n")
  end
  return join(reorder(shaped, baseRTL))
end
