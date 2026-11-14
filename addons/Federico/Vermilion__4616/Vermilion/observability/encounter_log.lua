Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.EncounterLog = {}
local M = Vermilion.EncounterLog

if not Vermilion.Constants.DEBUG then return end

local api = Vermilion.zenimax.api

function M.file_hint()
  local folder = (api.GetWorldName and api.GetWorldName() == "PTS") and "pts" or "live"
  return "Documents\\Elder Scrolls Online\\" .. folder .. "\\Logs\\Encounter.log"
end

function M.available()
  return api.SetEncounterLogEnabled ~= nil and api.IsEncounterLogEnabled ~= nil
end

function M.is_enabled()
  return M.available() and api.IsEncounterLogEnabled() == true
end

function M.set_enabled(on)
  if not M.available() then return false end
  api.SetEncounterLogEnabled(on and true or false)
  return true
end

function M.toggle()
  return M.set_enabled(not M.is_enabled())
end

function M.version()
  if api.GetEncounterLogVersion then return api.GetEncounterLogVersion() or 0 end
  return 0
end

function M.status_line()
  if not M.available() then return "encounter log: not available on this client" end
  return "encounter log " .. (M.is_enabled() and "ON" or "OFF")
    .. "  format v" .. tostring(M.version())
    .. "  -> " .. M.file_hint()
end
