Verdant = Verdant or {}
local Verdant = Verdant
if not Verdant.Constants.DEBUG then return end

Verdant.SkillProbe = {}
local M = Verdant.SkillProbe

local api = Verdant.zenimax.api
local string_format, string_gsub = string.format, string.gsub
local table_sort = table.sort
local math_floor = math.floor

local last

local function clean(s)
  if type(s) ~= "string" then return "" end
  return (string_gsub(s, "%^.*$", ""))
end

local function chat(line) api.chat("[skillprobe] " .. line) end

local function collect()
  local rows, by_id = {}, {}
  local function add(id, v, from)
    if type(id) ~= "number" or id <= 0 or type(v) ~= "number" or v <= 0 then return end
    local e = by_id[id]
    if not e then
      e = { id = id, amount = 0, seen = 0, from = from }
      by_id[id] = e
      rows[#rows + 1] = e
    end
    e.amount = e.amount + v
    e.seen = e.seen + 1
  end
  local SS, vsf = Verdant.SessionStore, Verdant.lib.vsf
  for i = 1, SS.count() do
    local s = SS.get(i)
    if s and s.streams and s.desc and s.streams.sums and s.desc.sums then
      local recs = vsf.unpack(s.streams.sums, s.desc.sums)
      for k = 1, #(recs or {}) do add(recs[k].id, recs[k].v, "library") end
    end
  end
  local heal_by, shield_by = Verdant.TemporalBuffer.ability_sums()
  for id, v in pairs(heal_by or {}) do add(id, v, "window") end
  for id, v in pairs(shield_by or {}) do add(id, v, "window") end
  return rows
end

local function decider(user, tab, icon, tree, champ, origin, last)
  if user then return "user" end
  if origin then return "game" end
  if tab then return "table" end
  if icon then return "icon" end
  if tree then return "tree" end
  if champ then return "champion" end
  if last then return "game" end
  return "none"
end

local function without_table(icon, tree, champ, origin, last) return origin or icon or tree or champ or last end

function M.run()
  local SC = Verdant.SkillColors
  local rows = collect()
  local total = 0
  local by, by_amount = {}, {}
  local icon_n, icon_same, icon_other, icon_alone = 0, 0, 0, 0
  for _, r in ipairs(rows) do
    local user, tab, icon, tree, champ, origin, last = SC.layers(r.id)
    r.name = clean(api.GetAbilityName(r.id))
    r.user, r.table, r.icon, r.tree, r.champ, r.game = user, tab, icon, tree, champ, origin or last
    r.by = decider(user, tab, icon, tree, champ, origin, last)
    by[r.by] = (by[r.by] or 0) + 1
    by_amount[r.by] = (by_amount[r.by] or 0) + r.amount
    total = total + r.amount
    if r.by == "icon" then
      icon_n = icon_n + 1
      if tree == nil then
        icon_alone = icon_alone + 1
      elseif tree == icon then
        icon_same = icon_same + 1
      else
        icon_other = icon_other + 1
      end
    end
  end
  table_sort(rows, function(a, b) return a.amount > b.amount end)

  local seen = {}
  for _, r in ipairs(rows) do seen[r.id] = r.amount end
  local tab_rows, same, changes, grey = {}, 0, 0, 0
  for _, id in ipairs(SC.override_ids()) do
    local _, tab, icon, tree, champ, origin, last = SC.layers(id)
    local after = without_table(icon, tree, champ, origin, last)
    local verdict = (after == tab) and "same" or (after and "changes" or "grey")
    if verdict == "same" then same = same + 1 elseif verdict == "changes" then changes = changes + 1 else grey = grey + 1 end
    tab_rows[#tab_rows + 1] = { id = id, name = clean(api.GetAbilityName(id)), group = tab, after = after, verdict = verdict,
      amount = seen[id] or 0 }
  end

  last = { api = api.GetAPIVersion(), lang = api.GetCVar("language.2"), rows = rows, table = tab_rows,
    by = by, by_amount = by_amount, total = total,
    icon = { n = icon_n, same = icon_same, other = icon_other, alone = icon_alone } }
  Verdant.Probe.keep("skillprobe", last)

  local function share(k) return (total > 0) and math_floor((by_amount[k] or 0) / total * 100 + 0.5) or 0 end
  chat(string_format("%d healing and shield abilities in the library and the window", #rows))
  chat(string_format("decided by: you %d (%d%%) · game data %d (%d%%) · table %d (%d%%) · icon %d (%d%%) · skill tree %d (%d%%) · champion %d (%d%%) · grey %d (%d%%)",
    by.user or 0, share("user"), by.game or 0, share("game"), by.table or 0, share("table"), by.icon or 0, share("icon"),
    by.tree or 0, share("tree"), by.champion or 0, share("champion"), by.none or 0, share("none")))
  chat(string_format("icon decisions %d: the skill tree says the same %d, something else %d, nothing %d",
    icon_n, icon_same, icon_other, icon_alone))
  chat(string_format("table entries %d: without them the same %d, another category %d, grey %d",
    #tab_rows, same, changes, grey))
  chat("saved to SavedVars probe.skillprobe; /reloadui writes it to disk")
  return last
end

function M.last() return last end
