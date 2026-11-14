Vermilion = Vermilion or {}
Vermilion.Say = {}
local M = Vermilion.Say

local api = Vermilion.zenimax.api
local zc = Vermilion.zenimax.constants
local GetString = api.GetString
local math_floor = math.floor
local string_format = string.format
local table_concat = table.concat
local readout, secs = Vermilion.Format.readout, Vermilion.Format.secs

local function clean(name)
  return (tostring(name or ""):gsub("|", ""))
end

function M.text()
  local G = Vermilion.Graph
  if not G.export_available() then return nil end
  local sm = G.export_summary()
  local parts = {
    clean(Vermilion.SessionStore.title(G.export_head())),
    string_format(GetString(VERMILION_SAY_DPS), readout(sm.avg)),
    string_format(GetString(VERMILION_SAY_CRIT), math_floor(sm.crit_rate * 100 + 0.5)),
    secs(sm.fight_ms),
  }
  local st = Vermilion.FightStats.compute(Vermilion.TemporalBuffer)
  if st.n > 0 then
    parts[#parts + 1] = string_format(GetString(VERMILION_SAY_MEDIAN), readout(st.p50))
    parts[#parts + 1] = string_format(GetString(VERMILION_SAY_P90), readout(st.p90))
    if st.p10 > 0 then parts[#parts + 1] = string_format(GetString(VERMILION_SAY_P10), readout(st.p10)) end
  end
  return table_concat(parts, GetString(VERMILION_SAY_SEP))
end

function M.post()
  local text = M.text()
  if not text then return false end
  api.StartChatInput(text, api.IsUnitGrouped("player") and zc.CHAT_CHANNEL_PARTY or zc.CHAT_CHANNEL_SAY)
  return true
end
