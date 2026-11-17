-- EsoCollectionQR: показывает «Коллекцию комплектов» QR-кодами для приложения ESO Guide.
-- /collqr — показать или спрятать коды; закрыть можно и кнопкой «Закрыть» под кодом. Коды сменяются сами: каждый показывается дважды, с двумя разными масками,
-- потому что примерно 2–5% кодов сканер не находит с одной маской, но читает с другой.
local A = EsoCollectionQR
local ADDON = "EsoCollectionQR"
local ROTATE_MS = 1500

local win, label, closeBtn
local BOTTOM_H = 84 -- место под кодом: подпись и кнопка
local hide
local uiByUs = false -- курсор включили мы: при закрытии вернём как было
local pool, used = {}, 0
local holders, frames, parts, current = {}, 0, 0, 0

local function safe(f, ...) local ok, a, b, c, d = pcall(f, ...) if ok then return a, b, c, d end end

-- тексты на языке клиента игры: русский для русского клиента, иначе английский
local function T(ru, en) return (GetCVar and GetCVar("language.2") == "ru") and ru or en end

local function unlocked(pieceId, slot)
  if IsItemSetCollectionPieceUnlocked then
    local v = safe(IsItemSetCollectionPieceUnlocked, pieceId)
    if v ~= nil then return v == true end
  end
  local m = ITEM_SET_COLLECTIONS_DATA_MANAGER
  if m and m.GetOrCreateItemSetCollectionPieceData then
    local data = safe(m.GetOrCreateItemSetCollectionPieceData, m, pieceId, slot)
    if data and data.IsUnlocked then return data:IsUnlocked() == true end
  end
  return false
end

-- биты по предметам в том же порядке, в каком их перебирает SetsExport
local function collect()
  local sets, have, total = {}, 0, 0
  local id = GetNextItemSetCollectionId(nil)
  while id and id ~= 0 do
    local n = safe(GetNumItemSetCollectionPieces, id) or 0
    if n > 0 then
      local bits = {}
      for i = 1, n do
        local pieceId, slot = safe(GetItemSetCollectionPieceInfo, id, i)
        bits[i] = pieceId and unlocked(pieceId, slot) or false
        total = total + 1
        if bits[i] then have = have + 1 end
      end
      sets[#sets + 1] = { id = id, bits = bits }
    end
    id = GetNextItemSetCollectionId(id)
  end
  return sets, have, total
end

-- раздел мотивов в Библиотеке знаний: книги — предметы ITEMTYPE_RACIAL_STYLE_MOTIF (так же, как в SetsExport)
local function isMotifCategory(c)
  local name, nColl = safe(GetLoreCategoryInfo, c)
  for k = 1, math.min(nColl or 0, 3) do
    local link = GetLoreBookLink and safe(GetLoreBookLink, c, k, 1, LINK_STYLE_DEFAULT)
    if link and link ~= "" and ITEMTYPE_RACIAL_STYLE_MOTIF and safe(GetItemLinkItemType, link) == ITEMTYPE_RACIAL_STYLE_MOTIF then return true end
  end
  name = name or ""
  return name:find("отив") ~= nil or name:find("otif") ~= nil
end

-- изученные главы мотивов из Библиотеки знаний
local function collectKnown()
  local books = {}
  if GetNumLoreCategories then
    for c = 1, safe(GetNumLoreCategories) or 0 do
      local _, nColl = safe(GetLoreCategoryInfo, c)
      if not isMotifCategory(c) then nColl = 0 end
      for k = 1, nColl or 0 do
        local _, _, _, totalBooks = safe(GetLoreCollectionInfo, c, k)
        for b = 1, totalBooks or 0 do
          local _, _, known, bookId = safe(GetLoreBookInfo, c, k, b)
          if known and bookId and bookId ~= 0 then books[#books + 1] = bookId end
        end
      end
    end
  end
  return { [2] = books }, #books
end

-- изученные рецепты декора: id предметов декора, которые они создают. Игра перечисляет в списках рецептов
-- только изученные рецепты, поэтому передаём сами id, а не отметки по порядку
local function collectRecipes(known)
  if not GetNumRecipeLists or not ITEMTYPE_FURNISHING then known[3] = {} return 0 end
  local list = {}
  for l = 1, safe(GetNumRecipeLists) or 0 do
    local _, n = safe(GetRecipeListInfo, l)
    for r = 1, n or 0 do
      local link = GetRecipeResultItemLink and safe(GetRecipeResultItemLink, l, r, LINK_STYLE_DEFAULT) or ""
      if link ~= "" and safe(GetItemLinkItemType, link) == ITEMTYPE_FURNISHING and safe(GetRecipeInfo, l, r) ~= false then
        local id = tonumber(safe(GetItemLinkItemId, link)) or 0
        if id > 0 then list[#list + 1] = id end
      end
    end
  end
  known[3] = list
  return #list
end

-- Мотивы и рецепты изучает каждый персонаж отдельно, а коллекция сетов и древности общие для аккаунта.
-- Поэтому знания каждого персонажа запоминаются при входе им в игру (EsoCollectionQR_SV — общий файл аккаунта),
-- а в код идёт объединение по всем персонажам этого сервера: «изучено хотя бы одним».
local function world() return GetWorldName and safe(GetWorldName) or "" end

local function remember()
  -- библиотека знаний ещё не загрузилась — не затираем запомненное пустым
  if not GetNumLoreCategories or (safe(GetNumLoreCategories) or 0) == 0 then return end
  local id = GetCurrentCharacterId and safe(GetCurrentCharacterId)
  if not id then return end
  local known = collectKnown()
  collectRecipes(known)
  EsoCollectionQR_SV = type(EsoCollectionQR_SV) == "table" and EsoCollectionQR_SV or {}
  local sv = EsoCollectionQR_SV
  sv.chars = sv.chars or {}
  sv.chars[tostring(id)] = {
    name = GetUnitName and safe(GetUnitName, "player") or "", world = world(), time = GetTimeStamp(),
    books = known[2], rec = known[3] or {},
  }
end

-- объединение знаний всех запомненных персонажей этого сервера
local function mergedKnown()
  local known = collectKnown()
  collectRecipes(known)
  local books, rec, n = {}, {}, 0
  local function add(set, list) for _, x in ipairs(list or {}) do set[x] = true end end
  add(books, known[2]); add(rec, known[3])
  local sv = type(EsoCollectionQR_SV) == "table" and EsoCollectionQR_SV or {}
  local me = GetCurrentCharacterId and tostring(safe(GetCurrentCharacterId)) or ""
  for id, c in pairs(sv.chars or {}) do
    if c.world == world() then
      n = n + 1
      if id ~= me then
        add(books, c.books)
        add(rec, c.rec)
      end
    end
  end
  local function list(set) local t = {} for x in pairs(set) do t[#t + 1] = x end return t end
  known[2], known[3] = list(books), list(rec)
  return known, #known[2], #known[3], math.max(n, 1)
end

-- для проверки вне игры (тест на LuaJ)
A.Remember, A.MergedKnown = remember, mergedKnown

-- зацепки наборов древностей (мифики и др.): на какие древности сейчас есть зацепка и какие уже найдены
local function collectLeads(known)
  if not GetNextAntiquityId then return 0, 0 end
  local lead, dug = {}, {}
  local id = GetNextAntiquityId()
  while id do
    if (safe(GetAntiquitySetId, id) or 0) ~= 0 then
      if DoesAntiquityHaveLead and safe(DoesAntiquityHaveLead, id) then lead[#lead + 1] = id end
      if GetNumAntiquitiesRecovered and (safe(GetNumAntiquitiesRecovered, id) or 0) > 0 then dug[#dug + 1] = id end
    end
    id = GetNextAntiquityId(id)
  end
  known[4] = lead
  known[5] = dug
  return #lead, #dug
end

local function ensureWindow()
  if win then return end
  win = WINDOW_MANAGER:CreateTopLevelWindow(ADDON .. "Window")
  win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
  win:SetClampedToScreen(true)
  win:SetHidden(true)
  local bg = WINDOW_MANAGER:CreateControl(ADDON .. "Bg", win, CT_TEXTURE)
  bg:SetAnchorFill(win)
  bg:SetColor(1, 1, 1, 1)
  bg:SetDrawLevel(0)
  label = WINDOW_MANAGER:CreateControl(ADDON .. "Label", win, CT_LABEL)
  label:SetFont("ZoFontWinH3")
  label:SetColor(0, 0, 0, 1)
  label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
  label:SetAnchor(BOTTOM, win, BOTTOM, 0, -48)
  label:SetDrawLevel(2)
  closeBtn = WINDOW_MANAGER:CreateControl(ADDON .. "Close", win, CT_BUTTON)
  closeBtn:SetDimensions(160, 32)
  closeBtn:SetAnchor(BOTTOM, win, BOTTOM, 0, -10)
  closeBtn:SetFont("ZoFontGameBold")
  closeBtn:SetText(T("Закрыть", "Close"))
  closeBtn:SetNormalFontColor(0.15, 0.12, 0.08, 1)
  closeBtn:SetMouseOverFontColor(0.6, 0.42, 0.07, 1)
  closeBtn:SetDrawLevel(3)
  -- рамка и фон кнопки — простые цветные текстуры, как фон кода
  local edge = WINDOW_MANAGER:CreateControl(ADDON .. "CloseEdge", closeBtn, CT_TEXTURE)
  edge:SetAnchorFill(closeBtn)
  edge:SetColor(0.4, 0.35, 0.28, 1)
  edge:SetDrawLevel(1)
  local fill = WINDOW_MANAGER:CreateControl(ADDON .. "CloseFill", closeBtn, CT_TEXTURE)
  fill:SetAnchor(TOPLEFT, closeBtn, TOPLEFT, 1, 1)
  fill:SetAnchor(BOTTOMRIGHT, closeBtn, BOTTOMRIGHT, -1, -1)
  fill:SetColor(0.92, 0.9, 0.86, 1)
  fill:SetDrawLevel(2)
  closeBtn:SetHandler("OnClicked", function() hide() end)
end

-- тёмные модули рисуются полосами по строкам: так элементов интерфейса в разы меньше
local function rect(parent)
  used = used + 1
  local t = pool[used]
  if not t then
    t = WINDOW_MANAGER:CreateControl(ADDON .. "Px" .. used, win, CT_TEXTURE)
    t:SetColor(0, 0, 0, 1)
    t:SetDrawLevel(1)
    pool[used] = t
  end
  t:SetParent(parent)
  t:ClearAnchors()
  t:SetHidden(false)
  return t
end

local function drawPart(k, m, s, off)
  local h = holders[k]
  if not h then
    h = WINDOW_MANAGER:CreateControl(ADDON .. "Part" .. k, win, CT_CONTROL)
    holders[k] = h
  end
  h:ClearAnchors()
  h:SetAnchor(TOPLEFT, win, TOPLEFT, off, off)
  h:SetDimensions(#m * s, #m * s)
  for r = 1, #m do
    local row, c = m[r], 1
    while c <= #row do
      if row[c] == 1 then
        local c2 = c
        while c2 < #row and row[c2 + 1] == 1 do c2 = c2 + 1 end
        local t = rect(h)
        t:SetDimensions((c2 - c + 1) * s, s)
        t:SetAnchor(TOPLEFT, h, TOPLEFT, (c - 1) * s, (r - 1) * s)
        c = c2 + 1
      else
        c = c + 1
      end
    end
  end
end

local function show(k)
  current = k
  for i, h in ipairs(holders) do h:SetHidden(i ~= k) end
  local hint = T("Наведите камеру приложения ESO Guide", "Point the ESO Guide app camera here")
  local p = (k - 1) % parts + 1
  label:SetText(parts > 1 and string.format(T("Код %d из %d · %s", "Code %d of %d · %s"), p, parts, hint) or hint)
end

function hide()
  if win then win:SetHidden(true) end
  EVENT_MANAGER:UnregisterForUpdate(ADDON)
  if uiByUs then
    uiByUs = false
    pcall(SCENE_MANAGER.SetInUIMode, SCENE_MANAGER, false)
  end
end

local function layout(mats)
  local maxN = 0
  for _, m in ipairs(mats) do maxN = math.max(maxN, #m) end
  local avail = math.min(GuiRoot:GetWidth(), GuiRoot:GetHeight()) * 0.8
  local s = math.max(2, math.floor(avail / (maxN + 8)))
  local side = (maxN + 8) * s
  win:SetDimensions(side, side + BOTTOM_H)
  for k, m in ipairs(mats) do drawPart(k, m, s, 4 * s + math.floor((maxN - #m) * s / 2)) end
  for k = #mats + 1, #holders do holders[k]:SetHidden(true) end
  frames = #mats
  win:SetHidden(false)
  -- курсор, чтобы можно было нажать «Закрыть»
  if SCENE_MANAGER and SCENE_MANAGER.SetInUIMode and not (SCENE_MANAGER.IsInUIMode and SCENE_MANAGER:IsInUIMode()) then
    uiByUs = pcall(SCENE_MANAGER.SetInUIMode, SCENE_MANAGER, true)
  end
  show(1)
  EVENT_MANAGER:RegisterForUpdate(ADDON, ROTATE_MS, function() show(current % frames + 1) end)
end

local function toggle()
  ensureWindow()
  if not win:IsHidden() then hide() return end
  if not GetNextItemSetCollectionId then d(T("[Коллекция] В этой версии игры нет коллекции комплектов.", "[Collection] This game version has no set collection.")) return end
  local sets, have, total = collect()
  local stamp = GetTimeStamp()
  remember()
  local known, nBooks, nRec, nChars = mergedKnown()
  local nLead, nDug = collectLeads(known)
  local account = GetDisplayName and safe(GetDisplayName) or nil
  if account == "" then account = nil end
  local texts = A.Payload.Parts(A.Payload.Bytes(sets, stamp, known, account), stamp)
  d(string.format(T("[Коллекция] %s: собрано %d из %d предметов сетов, глав мотивов: %d, рецептов декора: %d, зацепок на руках: %d, найдено древностей: %d. Кодов: %d.",
    "[Collection] %s: %d of %d set items collected, motif chapters: %d, furnishing recipes: %d, leads in hand: %d, antiquities found: %d. Codes: %d."),
    account or "?", have, total, nBooks, nRec, nLead, nDug, #texts))
  d(string.format(T("[Коллекция] Мотивы и рецепты — по всем персонажам, которыми вы заходили с этим аддоном: %d. Зайдите каждым крафтером хотя бы раз.",
    "[Collection] Motifs and recipes are combined from every character you have logged in with this addon: %d. Log in with each crafter at least once."), nChars))
  for _, t in ipairs(pool) do t:SetHidden(true) end
  used = 0
  -- по одному коду за кадр, чтобы игра не подвисала; кадры: все коды с лучшей маской, затем все со второй
  parts = #texts
  local mats = {}
  local function step(i)
    local rows, _, second = A.Qr.Encode(texts[i])
    mats[i] = rows
    mats[parts + i] = A.Qr.Encode(texts[i], second)
    if i < parts then zo_callLater(function() step(i + 1) end, 30) else layout(mats) end
  end
  step(1)
end

EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, function(_, name)
  if name ~= ADDON then return end
  EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)
  SLASH_COMMANDS["/collqr"] = toggle
  -- знания персонажа запоминаем при каждом входе: библиотеке знаний нужно время, поэтому с задержкой
  EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_PLAYER_ACTIVATED, function()
    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_PLAYER_ACTIVATED)
    zo_callLater(function() pcall(remember) end, 8000)
  end)
end)
