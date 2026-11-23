Verdant = Verdant or {}
local Verdant = Verdant

Verdant.BuffCatalog = {}
local M = Verdant.BuffCatalog

local api = Verdant.zenimax.api
local zc  = Verdant.zenimax.constants
local zev = Verdant.zenimax.events
local string_find, string_gsub, string_lower, string_sub = string.find, string.gsub, string.lower, string.sub

local TICK = "VerdantBuffCatalog"
local DONE = "VerdantBuffCatalogDone"
local SET_LIMIT = 5000
local MAX_ANSWERS = 2048
M.SETS_PER_STEP = 12
M.LINES_PER_STEP = 4

local store
local pending, pending_n = {}, 0
local job
local listeners = {}
local ticking, broken = false, false

local function clean(s)
  if type(s) ~= "string" then return "" end
  return (string_gsub(s, "%^.*$", ""))
end

local function low(s) return string_lower(clean(s)) end

local function has_word(text, word)
  if not text or word == "" then return false end
  local from = 1
  while true do
    local a, b = string_find(text, word, from, true)
    if not a then return false end
    local before = a > 1 and string_sub(text, a - 1, a - 1) or ""
    local after = string_sub(text, b + 1, b + 1)
    if not string_find(before, "%w") and not string_find(after, "%w") then return true end
    from = b + 1
  end
end

local function fresh(t)
  local ver, lang = api.GetAPIVersion(), api.GetCVar("language.2")
  if t.api ~= ver or t.lang ~= lang or type(t.ids) ~= "table" or (t.n or 0) > MAX_ANSWERS then
    t.api, t.lang, t.ids, t.n = ver, lang, {}, 0
  end
end

function M.bind(t)
  store = t
  job, broken = nil, false
  pending, pending_n = {}, 0
  if store then fresh(store) end
end

function M.answer(id)
  if not store then return nil end
  return store.ids[id]
end

function M.on_done(fn)
  listeners[#listeners + 1] = zev.guard(DONE, fn)
end

function M.running() return job ~= nil end
function M.phase() return job and job.phase or nil end
function M.pending() return pending_n end
function M.settled(id) return broken or not store or store.ids[id] ~= nil end

local function busy()
  return api.IsUnitInCombat("player") or Verdant.TemporalBuffer.is_recording()
end

local function set_text(id)
  if (api.GetNumItemSetCollectionPieces(id) or 0) <= 0 then return "" end
  local piece = api.GetItemSetCollectionPieceInfo(id, 1)
  local link = api.GetItemSetCollectionPieceItemLink(piece, zc.LINK_STYLE_DEFAULT, zc.ITEM_TRAIT_TYPE_NONE)
  local has, _, nb = api.GetItemLinkSetInfo(link, false)
  if not has then return "" end
  local text = ""
  for b = 1, nb or 0 do
    local _, desc = api.GetItemLinkSetBonusInfo(link, false, b)
    text = text .. "\n" .. string_lower(desc or "")
  end
  return text
end

local function match_set(id)
  local name = clean(api.GetItemSetName(id))
  local key = string_lower(name)
  local text = set_text(id)
  for bid, c in pairs(job.counts) do
    local want = job.keys[bid]
    if key == want then c.sn, c.sn_v = c.sn + 1, name end
    if has_word(text, want) then c.sw, c.sw_v = c.sw + 1, name end
  end
end

local function match_skill(ab)
  local key = low(api.GetAbilityName(ab))
  local text = string_lower(api.GetAbilityDescription(ab) or "")
  for bid, c in pairs(job.counts) do
    if bid ~= ab then
      local want = job.keys[bid]
      if key == want then c.kn, c.kn_v = c.kn + 1, ab end
      if has_word(text, want) then c.kw, c.kw_v = c.kw + 1, ab end
    end
  end
end

local function sets_step()
  for _ = 1, M.SETS_PER_STEP do
    local id = api.GetNextItemSetCollectionId(job.set_id)
    job.walked = job.walked + 1
    if not id or id <= 0 or job.walked > SET_LIMIT then
      job.phase = "skills"
      return
    end
    job.set_id = id
    match_set(id)
  end
end

local function skills_step()
  for _ = 1, M.LINES_PER_STEP do
    if job.st > (api.GetNumSkillTypes() or 0) then
      job.phase = "done"
      return
    end
    if job.li > (api.GetNumSkillLines(job.st) or 0) then
      job.st, job.li = job.st + 1, 1
    else
      for si = 1, api.GetNumSkillAbilities(job.st, job.li) or 0 do
        for morph = 0, 2 do
          local ab = api.GetSpecificSkillAbilityInfo(job.st, job.li, si, morph, 1)
          if ab and ab > 0 and not job.seen[ab] then
            job.seen[ab] = true
            match_skill(ab)
          end
        end
      end
      job.li = job.li + 1
    end
  end
end

local function verdict(c)
  if c.sn == 1 then return { k = "set", n = c.sn_v } end
  if c.sn == 0 and c.sw == 1 then return { k = "set", n = c.sw_v } end
  if c.sn + c.sw == 0 then
    if c.kn == 1 then return { k = "skill", a = c.kn_v } end
    if c.kn == 0 and c.kw == 1 then return { k = "skill", a = c.kw_v } end
  end
  return false
end

local function stop_tick()
  ticking = false
  zev.unregister_update(TICK)
end

local function finish()
  local done = job
  job = nil
  local ids = {}
  for bid, c in pairs(done.counts) do
    if store.ids[bid] == nil then store.n = (store.n or 0) + 1 end
    store.ids[bid] = verdict(c)
    ids[#ids + 1] = bid
  end
  Verdant.BuffOrigin.forget(ids)
  for i = 1, #listeners do
    listeners[i](ids)
  end
end

local function begin()
  job = { keys = pending, counts = {}, phase = "sets", walked = 0, st = 1, li = 1, seen = {} }
  for bid in pairs(pending) do job.counts[bid] = { sn = 0, sw = 0, kn = 0, kw = 0 } end
  pending, pending_n = {}, 0
end

local function work()
  if job.phase == "sets" then
    sets_step()
  elseif job.phase == "skills" then
    skills_step()
  end
end

local function step()
  if busy() then return end
  if not job then
    if pending_n == 0 then return stop_tick() end
    begin()
  end
  local ok, err = pcall(work)
  if not ok then
    job, broken = nil, true
    pending, pending_n = {}, 0
    stop_tick()
    zev.fail(TICK, err, string.format(api.GetString(VERDANT_BUFF_CATALOG_FAILED), zev.error_label(TICK)))
    return
  end
  if job.phase == "done" then finish() end
end

function M.ask(id, key)
  if broken or not store or type(id) ~= "number" or key == nil or key == "" then return end
  if store.ids[id] ~= nil or pending[id] or (job and job.keys[id]) then return end
  pending[id] = key
  pending_n = pending_n + 1
  if not ticking then
    ticking = true
    zev.register_update(TICK, 0, step)
  end
end
