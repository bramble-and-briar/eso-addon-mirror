Verdant = Verdant or {}
local Verdant = Verdant
if not Verdant.Constants.DEBUG then return end

Verdant.BuffProbe = {}
local M = Verdant.BuffProbe

local api = Verdant.zenimax.api
local zc  = Verdant.zenimax.constants
local string_find, string_format, string_gsub, string_lower, string_sub, string_match =
  string.find, string.format, string.gsub, string.lower, string.sub, string.match
local table_concat, table_sort = table.concat, table.sort
local math_floor = math.floor
local collectgarbage = collectgarbage

local LIST_MAX = 3
local SET_LIMIT = 5000

local MAJOR = {
  "AEGIS", "BERSERK", "BREACH", "BRITTLE", "BRUTALITY", "COURAGE", "COWARDICE", "DEFILE", "ENDURANCE",
  "EVASION", "EXPEDITION", "FORCE", "FORTITUDE", "HEROISM", "INTELLECT", "MAIM", "MANGLE", "MENDING",
  "PROPHECY", "PROTECTION", "RESOLVE", "SAVAGERY", "SLAYER", "SORCERY", "TIMIDITY", "VITALITY", "VULNERABILITY",
}
local MINOR = {
  "AEGIS", "BERSERK", "BREACH", "BRITTLE", "BRUTALITY", "COURAGE", "COWARDICE", "DEFILE", "ENDURANCE",
  "ENERVATION", "EVASION", "EXPEDITION", "FORCE", "FORTITUDE", "HEROISM", "INTELLECT", "LIFESTEAL",
  "MAGICKASTEAL", "MAIM", "MANGLE", "MENDING", "PROPHECY", "PROTECTION", "RESOLVE", "SAVAGERY", "SLAYER",
  "SORCERY", "TIMIDITY", "TOUGHNESS", "UNCERTAINTY", "VITALITY", "VULNERABILITY",
}
local OTHER = { "EMPOWER", "GALLOP" }

local function clean(s)
  if type(s) ~= "string" then return "" end
  return (string_gsub(s, "%^.*$", ""))
end

local function low(s) return string_lower(clean(s)) end
local function clock() return api.GetGameTimeMilliseconds() end
local function kb() return collectgarbage("count") end

local FAIL = "Verdant_BuffProbe"

local function timed(cost, key, fallback, fn, ...)
  local m0, t0 = kb(), clock()
  local fine, a, b = pcall(fn, ...)
  cost[key] = { ms = clock() - t0, kb = math_floor(kb() - m0 + 0.5), err = (not fine) and tostring(a) or nil }
  if not fine then
    Verdant.zenimax.events.fail(FAIL, key .. ": " .. tostring(a))
    return fallback, 0
  end
  return a, b
end

local function buff_type_names()
  local out = {}
  local function add(key)
    local v = zc.buff_type(key)
    if v then out[v] = key end
  end
  for _, w in ipairs(MAJOR) do add("MAJOR_" .. w) end
  for _, w in ipairs(MINOR) do add("MINOR_" .. w) end
  for _, w in ipairs(OTHER) do add(w) end
  return out
end

local function champion_index()
  local by_name, by_ability, n, dup = {}, {}, 0, 0
  for d = 1, api.GetNumChampionDisciplines() or 0 do
    local disc = clean(api.GetChampionDisciplineName(api.GetChampionDisciplineId(d)))
    for s = 1, api.GetNumChampionDisciplineSkills(d) or 0 do
      local cs = api.GetChampionSkillId(d, s)
      local e = { cs = cs, disc = disc, ab = api.GetChampionAbilityId(cs) or 0 }
      local nm = low(api.GetChampionSkillName(cs))
      if nm ~= "" then
        if by_name[nm] then dup = dup + 1 else by_name[nm] = e end
      end
      if e.ab > 0 then by_ability[e.ab] = e end
      n = n + 1
    end
  end
  return { by_name = by_name, by_ability = by_ability, n = n, dup = dup }
end

local function bonus_text(link, equipped)
  local has, name, nb, _, _, set_id = api.GetItemLinkSetInfo(link, equipped)
  if not has then return nil end
  local parts = {}
  for b = 1, nb or 0 do
    local _, desc = api.GetItemLinkSetBonusInfo(link, equipped, b)
    parts[#parts + 1] = string_lower(desc or "")
  end
  return table_concat(parts, "\n"), clean(name), set_id, #parts
end

local function set_names()
  local sets, dup, seen = {}, 0, {}
  local id = api.GetNextItemSetCollectionId(nil)
  while id and id > 0 and #sets < SET_LIMIT do
    local name = clean(api.GetItemSetName(id))
    local key = string_lower(name)
    if seen[key] then dup = dup + 1 end
    seen[key] = true
    sets[#sets + 1] = { id = id, name = name, key = key }
    id = api.GetNextItemSetCollectionId(id)
  end
  return sets, dup
end

local function set_texts(sets)
  local texts, chars = 0, 0
  for i = 1, #sets do
    local s = sets[i]
    if (api.GetNumItemSetCollectionPieces(s.id) or 0) > 0 then
      local piece = api.GetItemSetCollectionPieceInfo(s.id, 1)
      local link = api.GetItemSetCollectionPieceItemLink(piece, zc.LINK_STYLE_DEFAULT, zc.ITEM_TRAIT_TYPE_NONE)
      local text, _, _, n = bonus_text(link, false)
      if text then
        s.text = text
        texts = texts + n
        chars = chars + #text
      end
    end
  end
  return texts, chars
end

local function worn_sets()
  local out, seen = {}, {}
  for slot = 0, (api.GetBagSize(zc.BAG_WORN) or 0) - 1 do
    local link = api.GetItemLink(zc.BAG_WORN, slot, zc.LINK_STYLE_DEFAULT)
    if link and link ~= "" then
      local text, name, set_id = bonus_text(link, true)
      if text and set_id and not seen[set_id] then
        seen[set_id] = true
        out[#out + 1] = { id = set_id, name = name, key = string_lower(name), text = text }
      end
    end
  end
  return out
end

local function skill_index()
  local list, seen = {}, {}
  for st = 1, api.GetNumSkillTypes() or 0 do
    for li = 1, api.GetNumSkillLines(st) or 0 do
      for si = 1, api.GetNumSkillAbilities(st, li) or 0 do
        for morph = 0, 2 do
          local ab = api.GetSpecificSkillAbilityInfo(st, li, si, morph, 1)
          if ab and ab > 0 and not seen[ab] then
            seen[ab] = true
            list[#list + 1] = { id = ab, name = clean(api.GetAbilityName(ab)), key = low(api.GetAbilityName(ab)),
                                text = string_lower(api.GetAbilityDescription(ab) or "") }
          end
        end
      end
    end
  end
  return list
end

local function has_word(text, word)
  if not text or word == "" then return false, false end
  local from, found = 1, false
  while true do
    local a, b = string_find(text, word, from, true)
    if not a then return found, false end
    found = true
    local before = a > 1 and string_sub(text, a - 1, a - 1) or ""
    local after = string_sub(text, b + 1, b + 1)
    if not string_find(before, "%w") and not string_find(after, "%w") then return true, true end
    from = b + 1
  end
end

local function match_list(list, key, self_id)
  local by_name, by_text, by_word, names = 0, 0, 0, {}
  for i = 1, #list do
    local e = list[i]
    if e.id ~= self_id then
      if e.key == key then by_name = by_name + 1 end
      local inside, word = has_word(e.text, key)
      if inside then by_text = by_text + 1 end
      if word then
        by_word = by_word + 1
        if #names < LIST_MAX then names[#names + 1] = e.name end
      end
    end
  end
  local first_name
  if by_name > 0 then
    for i = 1, #list do if list[i].key == key and list[i].id ~= self_id then first_name = list[i].name break end end
  end
  return by_name, by_text, by_word, table_concat(names, " | "), first_name
end

local function collect()
  local rows, by_id = {}, {}
  local function add(id, name, from)
    if type(id) ~= "number" or id <= 0 then return end
    local e = by_id[id]
    if not e then
      e = { id = id, name = name, from = from, seen = 0 }
      by_id[id] = e
      rows[#rows + 1] = e
    end
    e.seen = e.seen + 1
  end
  local SS = Verdant.SessionStore
  for i = 1, SS.count() do
    local s = SS.get(i)
    if s and type(s.buffs) == "table" then
      for _, b in pairs(s.buffs) do
        if type(b) == "table" then add(b.id, b.name, "library") end
      end
    end
  end
  local BT = Verdant.BuffTracker
  for i = 1, BT.count() do
    local rec = BT.get(i)
    for k = 1, rec.n_ids do add(rec.ids[k], rec.name, "window") end
  end
  return rows
end

local function verdict(r)
  if r.grp and r.grp ~= "other" and r.grp ~= "champion" then return "group" end
  if r.bt_name then return "type" end
  if r.mundus ~= zc.MUNDUS_STONE_INVALID then return "mundus" end
  if r.cp_id or r.cp_name then return "champion" end
  if r.set_by_name == 1 then return "set name" end
  if r.set_by_word == 1 then return "set text" end
  if r.skill_by_name == 1 then return "skill name" end
  if r.skill_by_word == 1 then return "skill text" end
  return "left"
end

local function classify(e, ix)
  local SC = Verdant.SkillColors
  local id = e.id
  local name = clean(api.GetAbilityName(id))
  local key = string_lower(name)
  local r = { id = id, name = name, from = e.from, seen = e.seen }
  local bt = api.GetAbilityBuffType(id, "player")
  r.bt = bt
  r.bt_name = (bt and bt ~= zc.BUFF_TYPE_NONE) and (ix.bt_names[bt] or tostring(bt)) or nil
  r.mundus = api.GetAbilityMundusStoneType(id) or zc.MUNDUS_STONE_INVALID
  r.perm = api.IsAbilityPermanent(id) and true or false
  r.passive = api.IsAbilityPassive(id) and true or false
  local st, li, si = api.GetSpecificSkillAbilityKeysByAbilityId(id)
  if st and st > 0 then r.skill_key = string_format("%d/%d/%d", st, li or 0, si or 0) end
  r.grp = SC.group_of_quiet(id)
  r.has_desc = #(api.GetAbilityDescription(id) or "") > 0
  r.icon = string_match(api.GetAbilityIcon(id) or "", "([^/]+)%.dds$") or ""
  local cp = ix.cp.by_ability[id]
  if cp then r.cp_id = cp.cs end
  local cpn = ix.cp.by_name[key]
  if cpn then r.cp_name = cpn.cs r.cp_disc = cpn.disc end
  r.set_by_name, r.set_by_text, r.set_by_word, r.set_text_first, r.set_name = match_list(ix.sets, key, nil)
  r.worn_by_name, r.worn_by_text, r.worn_by_word, r.worn_text_first, r.worn_name = match_list(ix.worn, key, nil)
  r.skill_by_name, r.skill_by_text, r.skill_by_word, r.skill_text_first, r.skill_name = match_list(ix.skills, key, id)
  r.verdict = verdict(r)
  return r
end

local last

function M.run()
  local cost = {}
  local ix = {}
  local t0, m0 = clock(), kb()
  ix.bt_names = timed(cost, "buff_types", {}, buff_type_names)
  ix.cp = timed(cost, "champion", { by_name = {}, by_ability = {}, n = 0, dup = 0 }, champion_index)
  local sets, set_dup = timed(cost, "set_names", {}, set_names)
  ix.sets = sets
  local texts, chars = timed(cost, "set_texts", 0, set_texts, sets)
  ix.worn = timed(cost, "worn", {}, worn_sets)
  ix.skills = timed(cost, "skills", {}, skill_index)
  local found = timed(cost, "collect", {}, collect)
  local rows = {}
  local function classify_all()
    for i = 1, #found do rows[#rows + 1] = classify(found[i], ix) end
  end
  timed(cost, "match", nil, classify_all)
  table_sort(rows, function(a, b) return a.name < b.name end)
  cost.total = { ms = clock() - t0, kb = math_floor(kb() - m0 + 0.5) }

  local counts, ambiguous = {}, 0
  for _, r in ipairs(rows) do
    counts[r.verdict] = (counts[r.verdict] or 0) + 1
    if not r.bt_name and (r.set_by_name > 1 or r.set_by_word > 1) then ambiguous = ambiguous + 1 end
  end

  last = {
    at = api.GetTimeStamp(), api = api.GetAPIVersion(), lang = api.GetCVar("language.2"),
    cost = cost, rows = rows, counts = counts, ambiguous = ambiguous,
    n_sets = #sets, set_name_dup = set_dup, n_texts = texts, text_chars = chars,
    n_worn = #ix.worn, n_stars = ix.cp.n, star_name_dup = ix.cp.dup, n_skills = #ix.skills,
  }
  Verdant.Probe.keep("buffprobe", last)

  local chat = api.chat
  chat(string_format("[buffprobe] %d buffs, %d sets (%d bonus texts, %d KB of text), %d champion stars, %d skills, %d worn sets",
    #rows, #sets, texts, math_floor(chars / 1024 + 0.5), ix.cp.n, #ix.skills, #ix.worn))
  chat(string_format("[buffprobe] set names %d ms %d KB · set texts %d ms %d KB · champion %d ms · skills %d ms · match %d ms · total %d ms",
    cost.set_names.ms, cost.set_names.kb, cost.set_texts.ms, cost.set_texts.kb, cost.champion.ms, cost.skills.ms,
    cost.match.ms, cost.total.ms))
  local order = { "group", "type", "mundus", "champion", "set name", "set text", "skill name", "skill text", "left" }
  local parts = {}
  for _, k in ipairs(order) do parts[#parts + 1] = k .. " " .. (counts[k] or 0) end
  chat("[buffprobe] " .. table_concat(parts, " · ") .. string_format(" · ambiguous %d", ambiguous))
  for _, k in ipairs({ "buff_types", "champion", "set_names", "set_texts", "worn", "skills", "collect", "match" }) do
    if cost[k].err then chat("[buffprobe] " .. k .. " failed: " .. cost[k].err) end
  end
  chat("[buffprobe] saved to SavedVars probe.buffprobe; /reloadui writes it to disk")
  return last
end

function M.last() return last end
