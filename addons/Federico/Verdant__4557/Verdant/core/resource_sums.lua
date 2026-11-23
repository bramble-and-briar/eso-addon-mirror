Verdant = Verdant or {}
local Verdant = Verdant

Verdant.ResourceSums = {}
local M = Verdant.ResourceSums

local table_sort = table.sort

M.SPENT, M.REC = 1, 2
local MAG, STA = 1, 2

local function plain_rec(id, sec)
  return { id = id, sec = sec, n = 0, mag = 0, sta = 0, total = 0, gen = -1, con = 0 }
end

function M.state(make_rec)
  return {
    make_rec = make_rec or plain_rec,
    gen = 0,
    by_id = { {}, {} },
    order = { { n = 0 }, { n = 0 } },
    race = { n = 0 },
    totals = { spend = 0, casts = 0, regained = 0, energized = 0 },
    contrib = { by_name = {}, total = 0, n = -1, t0 = 0, t1 = 0, src = nil },
  }
end

local want_mag, want_sta = true, true

local function wants(p) return (p == MAG and want_mag) or (p == STA and want_sta) end

local function by_total_desc(a, b) return a.total > b.total end

local function contribution(st, TB)
  local c = st.contrib
  local n = TB.count()
  local first, last = TB.at(1), TB.at(n)
  local t0, t1 = first and first.t or 0, last and last.t or 0
  local heal_by, shield_by = TB.ability_sums()
  if c.n == n and c.t0 == t0 and c.t1 == t1 and c.src == heal_by then
    return c.by_name
  end
  c.n, c.t0, c.t1, c.src = n, t0, t1, heal_by
  for k in pairs(c.by_name) do c.by_name[k] = nil end
  c.total = 0
  local SC = Verdant.SkillColors
  for _, by in ipairs({ heal_by or {}, shield_by or {} }) do
    for id, v in pairs(by) do
      if v > 0 then
        c.total = c.total + v
        local nm = SC.ability_name(id)
        if nm and nm ~= "" then c.by_name[nm] = (c.by_name[nm] or 0) + v end
      end
    end
  end
  return c.by_name
end

local function rec_for(st, sec, id)
  local rec = st.by_id[sec][id]
  if not rec then
    rec = st.make_rec(id, sec)
    st.by_id[sec][id] = rec
  end
  if rec.gen ~= st.gen then
    rec.gen = st.gen
    rec.n, rec.mag, rec.sta, rec.total = 0, 0, 0, 0
    local o = st.order[sec]
    o.n = o.n + 1
    o[o.n] = rec
  end
  return rec
end

local function add(rec, p, v)
  rec.n = rec.n + 1
  if p == MAG then rec.mag = rec.mag + v else rec.sta = rec.sta + v end
  rec.total = rec.total + v
end

local function finish(st, sec)
  local o = st.order[sec]
  for k = o.n + 1, #o do o[k] = nil end
  if o.n > 1 then table_sort(o, by_total_desc) end
end

function M.aggregate(st, mag, sta, sums)
  want_mag, want_sta = mag and true or false, sta and true or false
  st.gen = st.gen + 1
  local by_name = contribution(st, Verdant.TemporalBuffer)
  local order, totals, race = st.order, st.totals, st.race
  order[M.SPENT].n, order[M.REC].n = 0, 0
  totals.spend, totals.casts, totals.regained, totals.energized = 0, 0, 0, 0
  local _, cid, cpool, ccost, n, ctick = Verdant.Casts.records()
  for i = Verdant.Casts.first(), n do
    local p, cost = cpool[i], ccost[i]
    if p > 0 and cost > 0 and wants(p) then
      local rec = rec_for(st, M.SPENT, cid[i])
      add(rec, p, cost)
      totals.spend = totals.spend + cost
      if ctick[i] == 1 then
        rec.n = rec.n - 1
      else
        totals.casts = totals.casts + 1
      end
    end
  end
  finish(st, M.SPENT)
  local SC = Verdant.SkillColors
  local o = order[M.SPENT]
  for i = 1, o.n do
    local rec = o[i]
    rec.con = (rec.id > 0) and (by_name[SC.ability_name(rec.id)] or 0) or 0
  end
  race.n = 0
  for i = 1, o.n do
    if o[i].con > 0 then race.n = race.n + 1; race[race.n] = o[i] end
  end
  for i = 1, o.n do
    if o[i].con <= 0 then race.n = race.n + 1; race[race.n] = o[i] end
  end
  for k = race.n + 1, #race do race[k] = nil end
  local em, es = 0, 0
  local _, rid, rpool, ramt, rn = Verdant.Restores.records()
  for i = Verdant.Restores.first(), rn do
    local p = rpool[i]
    if p > 0 and wants(p) then
      add(rec_for(st, M.REC, rid[i]), p, ramt[i])
      if p == MAG then em = em + ramt[i] else es = es + ramt[i] end
    end
  end
  totals.energized = em + es
  local in_m = (sums and wants(MAG)) and sums.mag_in or 0
  local in_s = (sums and wants(STA)) and sums.sta_in or 0
  totals.regained = in_m + in_s
  local res_m, res_s = in_m - em, in_s - es
  if res_m < 0 then res_m = 0 end
  if res_s < 0 then res_s = 0 end
  if res_m + res_s > 0 then
    local rec = rec_for(st, M.REC, 0)
    if res_m > 0 then add(rec, MAG, res_m) end
    if res_s > 0 then add(rec, STA, res_s) end
  end
  finish(st, M.REC)
end
