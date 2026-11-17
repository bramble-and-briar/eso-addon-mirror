-- Упаковка коллекции для QR. Формат (версии 2 и 3), все числа — varint:
--   версия, время выгрузки, [версия 3: длина имени аккаунта и его байты UTF-8], число сетов, затем по каждому сету в порядке id:
--   разница id с предыдущим, число предметов * 4 + состояние (0 — ничего, 1 — всё, 2 — дальше биты по предметам),
--   затем число разделов и разделы: тег, способ и данные. Теги: 1 — стили снаряжения (больше не передаются), 2 — изученные главы мотивов,
--   3 — id декора, который создают изученные рецепты (игра перечисляет только изученные рецепты),
--   4 — древности (зацепки наборов), на которые сейчас есть зацепка, 5 — древности, найденные хотя бы раз.
--   0 — число отрезков и отрезки подряд идущих id: (отступ от конца предыдущего, длина);
--   1 — битовая карта: первый id, число id в диапазоне, байты (младший бит — меньший id);
--   2 — число id и разницы между соседними id по возрастанию (первая — от нуля). Выбирается то, что короче.
--   в конце два байта контрольной суммы (сумма байтов по модулю 65521).
-- Байты кодируются в Base45 (RFC 9285): его алфавит совпадает с алфавитно-цифровым режимом QR.
-- Каждый код: "EC1:<время в base36>:<номер>:<всего>:<кусок Base45>".
EsoCollectionQR = EsoCollectionQR or {}
local P = {}
EsoCollectionQR.Payload = P

local function varint(out, x)
  while x >= 128 do
    out[#out + 1] = x % 128 + 128
    x = math.floor(x / 128)
  end
  out[#out + 1] = x
end

--- Множество id: отрезками подряд идущих чисел или битовой картой — что короче
local function idSet(out, ids)
  table.sort(ids)
  -- повторы не нужны: отрезки должны идти строго по возрастанию
  local u = {}
  for _, x in ipairs(ids) do if x ~= u[#u] then u[#u + 1] = x end end
  ids = u
  local r, i = {}, 1
  while i <= #ids do
    local j = i
    while j < #ids and ids[j + 1] == ids[j] + 1 do j = j + 1 end
    r[#r + 1] = { ids[i], j - i + 1 }
    i = j + 1
  end
  local a = { 0 }
  varint(a, #r)
  local prev = 0
  for _, x in ipairs(r) do
    varint(a, x[1] - prev)
    varint(a, x[2])
    prev = x[1] + x[2]
  end
  local b = { 1 }
  if #ids > 0 then
    local lo, span = ids[1], ids[#ids] - ids[1] + 1
    varint(b, lo)
    varint(b, span)
    local bytes = {}
    for k = 1, math.ceil(span / 8) do bytes[k] = 0 end
    for _, x in ipairs(ids) do
      local o = x - lo
      local k = math.floor(o / 8) + 1
      bytes[k] = bytes[k] + 2 ^ (o % 8)
    end
    for _, v in ipairs(bytes) do b[#b + 1] = v end
  else
    varint(b, 0)
    varint(b, 0)
  end
  -- разреженные id (например, номера предметов декора) короче всего разницами между соседними
  local c = { 2 }
  varint(c, #ids)
  local p = 0
  for _, x in ipairs(ids) do varint(c, x - p); p = x end
  local best = a
  if #b < #best then best = b end
  if #c < #best then best = c end
  for _, v in ipairs(best) do out[#out + 1] = v end
end

--- sets: { {id = setId, bits = {true, false, …}} } — биты в порядке GetItemSetCollectionPieceInfo;
--- known: { [тег] = {id} } — можно не передавать; account — «@Имя» (с ним формат версии 3)
function P.Bytes(sets, stamp, known, account)
  table.sort(sets, function(a, b) return a.id < b.id end)
  local out = { account and 3 or 2 }
  varint(out, stamp)
  if account then
    varint(out, #account)
    for i = 1, #account do out[#out + 1] = account:byte(i) end
  end
  varint(out, #sets)
  local prev = 0
  for _, s in ipairs(sets) do
    local n, k = #s.bits, 0
    for i = 1, n do if s.bits[i] then k = k + 1 end end
    local state = k == 0 and 0 or (k == n and 1 or 2)
    varint(out, s.id - prev)
    prev = s.id
    varint(out, n * 4 + state)
    if state == 2 then
      for b = 0, math.ceil(n / 8) - 1 do
        local x, p = 0, 1
        for t = 1, 8 do
          local i = b * 8 + t
          if i <= n and s.bits[i] then x = x + p end
          p = p * 2
        end
        out[#out + 1] = x
      end
    end
  end
  local tags = {}
  for tag in pairs(known or {}) do tags[#tags + 1] = tag end
  table.sort(tags)
  varint(out, #tags)
  for _, tag in ipairs(tags) do
    varint(out, tag)
    idSet(out, known[tag])
  end
  local sum = 0
  for _, x in ipairs(out) do sum = (sum + x) % 65521 end
  out[#out + 1] = math.floor(sum / 256)
  out[#out + 1] = sum % 256
  return out
end

function P.Base45(bytes)
  local A, t, i = EsoCollectionQR.Qr.ALNUM, {}, 1
  local function ch(x) return A:sub(x + 1, x + 1) end
  while i <= #bytes do
    if i < #bytes then
      local x = bytes[i] * 256 + bytes[i + 1]
      local c = x % 45
      x = (x - c) / 45
      local d = x % 45
      t[#t + 1] = ch(c) .. ch(d) .. ch((x - d) / 45)
      i = i + 2
    else
      local x = bytes[i]
      local c = x % 45
      t[#t + 1] = ch(c) .. ch((x - c) / 45)
      i = i + 1
    end
  end
  return table.concat(t)
end

local function base36(x)
  local D, s = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ", ""
  repeat
    local r = x % 36
    s = D:sub(r + 1, r + 1) .. s
    x = (x - r) / 36
  until x == 0
  return s
end

--- Тексты QR-кодов: куски примерно одинаковой длины, каждый не больше кода версии Qr.MAX_VERSION
function P.Parts(bytes, stamp)
  local data = P.Base45(bytes)
  local tag = "EC1:" .. base36(stamp) .. ":"
  local room = EsoCollectionQR.Qr.Capacity(EsoCollectionQR.Qr.MAX_VERSION) - #tag - 8
  local count = math.max(1, math.ceil(#data / room))
  local size = math.ceil(#data / count)
  local parts = {}
  for k = 1, count do
    parts[k] = tag .. k .. ":" .. count .. ":" .. data:sub((k - 1) * size + 1, k * size)
  end
  return parts
end
