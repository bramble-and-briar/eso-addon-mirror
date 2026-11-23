Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Say = {}
local M = Verdant.Say

local api = Verdant.zenimax.api
local zc  = Verdant.zenimax.constants
local GetString     = api.GetString
local math_floor    = math.floor
local string_format = string.format
local table_concat  = table.concat
local value, secs   = Verdant.Format.value, Verdant.Format.secs

local function clean(name)
  return (tostring(name):gsub("|", ""))
end

local function percent(share)
  return math_floor(share * 100 + 0.5)
end

function M.text()
  local G = Verdant.Graph
  if not G.fight_available() then return nil end
  local s = Verdant.TemporalBuffer.summary()
  local parts = {
    clean(G.fight_name()),
    string_format(GetString(VERDANT_SAY_AVG), value(s.avg_ems)),
    string_format(GetString(VERDANT_SAY_PEAK), value(s.peak_ems)),
    string_format(GetString(VERDANT_SAY_CRIT), percent(s.crit_pct)),
    secs(s.dur_ms),
  }
  local out = s.total_heal + s.total_shield
  if s.total_shield > 0 then
    parts[#parts + 1] = string_format(GetString(VERDANT_SAY_SHIELD), percent(s.total_shield / out))
  end
  if s.total_overheal > 0 then
    parts[#parts + 1] = string_format(GetString(VERDANT_SAY_OVERHEAL), percent(s.wasted_pct))
  end
  return table_concat(parts, GetString(VERDANT_SAY_SEP))
end

function M.post()
  local text = M.text()
  if not text then return false end
  api.StartChatInput(text, api.IsUnitGrouped("player") and zc.CHAT_CHANNEL_PARTY or zc.CHAT_CHANNEL_SAY)
  return true
end
