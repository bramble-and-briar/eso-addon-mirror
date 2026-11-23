Verdant = Verdant or {}
local Verdant = Verdant

Verdant.EncounterLog = {}
local M = Verdant.EncounterLog

local api = Verdant.zenimax.api

M.FILE_HINT = "Documents\\Elder Scrolls Online\\live\\Logs\\Encounter.log"

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
    .. "  -> " .. M.FILE_HINT
end
