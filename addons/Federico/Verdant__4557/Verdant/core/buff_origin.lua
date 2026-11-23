Verdant = Verdant or {}
local Verdant = Verdant

Verdant.BuffOrigin = {}
local M = Verdant.BuffOrigin

local api = Verdant.zenimax.api
local zc  = Verdant.zenimax.constants
local zev = Verdant.zenimax.events
local string_gsub, string_lower, string_upper = string.gsub, string.lower, string.upper

local CACHE_MAX = 1024
local CASTER = "player"
local FAIL = "Verdant_BuffOrigin"

M.COLORS = {
  mundus   = { r = 0.93, g = 0.80, b = 0.42, a = 0.95 },
  champion = { r = 0.90, g = 0.27, b = 0.46, a = 0.95 },
  set      = { r = 0.86, g = 0.52, b = 0.86, a = 0.95 },
  skill    = { r = 0.80, g = 0.80, b = 0.55, a = 0.95 },
}

local NONE = { kind = false }
local cache, cached = {}, 0
local type_family
local champions
local told = false
local SEEN_MAX, IDS_MAX = 256, 4
local seen, n_seen = {}, 0

local function clean(s)
  if type(s) ~= "string" then return "" end
  return (string_gsub(s, "%^.*$", ""))
end

local function family_of_type()
  if type_family then return type_family end
  type_family = {}
  for word, fam in pairs(Verdant.SkillColors.BUFF_FAMILY_WORDS) do
    local up = string_upper(word)
    for _, key in ipairs({ "MAJOR_" .. up, "MINOR_" .. up, up }) do
      local v = zc.buff_type(key)
      if v and v ~= zc.BUFF_TYPE_NONE then type_family[v] = fam end
    end
  end
  return type_family
end

local function champion_index()
  if champions then return champions end
  local ix = { by_ability = {}, by_name = {}, n = 0 }
  for d = 1, api.GetNumChampionDisciplines() or 0 do
    local disc = clean(api.GetChampionDisciplineName(api.GetChampionDisciplineId(d)))
    for s = 1, api.GetNumChampionDisciplineSkills(d) or 0 do
      local cs = api.GetChampionSkillId(d, s)
      local e = { disc = disc }
      local ab = api.GetChampionAbilityId(cs) or 0
      if ab > 0 then ix.by_ability[ab] = e end
      local nm = string_lower(clean(api.GetChampionSkillName(cs)))
      if nm ~= "" and not ix.by_name[nm] then ix.by_name[nm] = e end
      ix.n = ix.n + 1
    end
  end
  if ix.n > 0 then champions = ix end
  return ix
end

local function by_type(id)
  local bt = api.GetAbilityBuffType(id, CASTER)
  if not bt or bt == zc.BUFF_TYPE_NONE then return nil end
  local fam = family_of_type()[bt]
  if fam then return "type", fam end
end

local function by_mundus(id)
  local m = api.GetAbilityMundusStoneType(id)
  if m and m ~= zc.MUNDUS_STONE_INVALID then return "mundus" end
end

local function champion_disc(id, key)
  local ix = champion_index()
  local e = ix.by_ability[id] or ix.by_name[key]
  return e and e.disc or nil
end

local function by_champion(id, key)
  local disc = champion_disc(id, key)
  if disc then return "champion", nil, disc end
end

local function by_catalog(id, key)
  local a = Verdant.BuffCatalog.answer(id)
  if a == nil then
    Verdant.BuffCatalog.ask(id, key)
    return nil
  end
  if a and a.k == "set" then return "set", nil, a.n end
  if a and a.k == "skill" then return "skill", nil, a.a end
end

M.DETECTORS = {
  { key = "type",     fn = by_type },
  { key = "mundus",   fn = by_mundus },
  { key = "champion", fn = by_champion },
  { key = "catalog",  fn = by_catalog },
}

local function failed(key, err)
  zev.fail(FAIL, key .. ": " .. tostring(err))
  if told then return end
  told = true
  api.chat("[Verdant] " .. string.format(api.GetString(VERDANT_BUFF_ORIGIN_FAILED), zev.error_label(FAIL)))
end

function M.champion_of(id, name)
  local key = string_lower(clean(name or api.GetAbilityName(id)))
  local ok, disc = pcall(champion_disc, id, key)
  if not ok then
    failed("champion", disc)
    return nil
  end
  return disc
end

function M.of(id, name)
  local hit = cache[id]
  if hit then return hit end
  name = clean(name or api.GetAbilityName(id))
  local key = string_lower(name)
  local out = NONE
  for i = 1, #M.DETECTORS do
    local d = M.DETECTORS[i]
    local ok, kind, fam, detail = pcall(d.fn, id, key, name)
    if not ok then
      failed(d.key, kind)
    elseif kind then
      out = { kind = kind, family = fam, detail = detail }
      break
    end
  end
  if cached >= CACHE_MAX then
    cache, cached = {}, 0
  end
  cache[id] = out
  cached = cached + 1
  return out
end

local function skill_group(ab)
  local g = Verdant.SkillColors.group_of_quiet(ab)
  if g and g ~= "other" then return g end
  return nil
end

function M.color(id, name)
  local o = M.of(id, name)
  if o.family then return Verdant.SkillColors.buff_family_colors[o.family] end
  if o.kind == "skill" then
    local g = skill_group(o.detail)
    if g then return Verdant.SkillColors.group_color(g) end
  end
  if o.kind then return M.COLORS[o.kind] end
  return nil
end

function M.label(id, name)
  local o = M.of(id, name)
  if o.family then return api.GetString(rawget(_G, "VERDANT_BUFF_FAM_" .. string_upper(o.family))) end
  if o.kind == "mundus" then return api.GetString(VERDANT_BUFF_FAM_MUNDUS) end
  if o.kind == "champion" then return string.format(api.GetString(VERDANT_BUFF_FAM_CHAMPION), o.detail or "") end
  if o.kind == "set" then return string.format(api.GetString(VERDANT_BUFF_FAM_SET), o.detail or "") end
  if o.kind == "skill" then
    local g = skill_group(o.detail)
    local what = g and Verdant.SkillColors.group_label(g) or clean(api.GetAbilityName(o.detail))
    return string.format(api.GetString(VERDANT_BUFF_FAM_SKILL), what)
  end
  return nil
end

function M.forget(ids)
  for i = 1, #ids do
    if cache[ids[i]] then
      cache[ids[i]] = nil
      cached = cached - 1
    end
  end
end

function M.note(id, name)
  if type(id) ~= "number" or id <= 0 then return end
  name = clean(name or api.GetAbilityName(id))
  if name == "" then return end
  local e = seen[name]
  if not e then
    if n_seen >= SEEN_MAX then return end
    e = { n = 0 }
    seen[name] = e
    n_seen = n_seen + 1
  end
  for i = 1, e.n do
    if e[i] == id then return end
  end
  if e.n >= IDS_MAX then return end
  e.n = e.n + 1
  e[e.n] = id
  M.of(e[1], name)
end

function M.is_grey(id, name, group)
  if group and group ~= "other" then return false end
  if Verdant.SkillColors.group_of_quiet(id) ~= "other" then return false end
  if M.color(id, name) then return false end
  return Verdant.BuffCatalog.settled(id)
end

function M.unknowns()
  local out = {}
  for name, e in pairs(seen) do
    if M.is_grey(e[1], name) then
      local ids = {}
      for i = 1, e.n do ids[i] = e[i] end
      out[#out + 1] = { id = e[1], ids = ids, name = name, icon = api.GetAbilityIcon(e[1]) or "" }
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

function M.unknown_count()
  return #M.unknowns()
end

function M.reset()
  cache, cached = {}, 0
  type_family, champions = nil, nil
  seen, n_seen = {}, 0
  told = false
end
