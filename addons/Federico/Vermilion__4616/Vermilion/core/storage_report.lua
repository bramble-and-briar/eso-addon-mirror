Vermilion = Vermilion or {}
Vermilion.StorageReport = {}
local M = Vermilion.StorageReport

local SESSIONS = { "library" }
local DIAGNOSTICS = { "probe", "trace", "traces", "evidence", "debug" }
local PREFERENCES = { "settings", "graph", "temporal", "assign", "logo", "log_lamp", "copybox", "skill_overrides", "skill_basic_ids" }
local SECTION = {}
for i = 1, #SESSIONS do SECTION[SESSIONS[i]] = "sessions" end
for i = 1, #DIAGNOSTICS do SECTION[DIAGNOSTICS[i]] = "diagnostics" end
for i = 1, #PREFERENCES do SECTION[PREFERENCES[i]] = "preferences" end

local function escaped(s)
  local _, n = s:gsub('[\\"\n]', "")
  return n
end

local function size_of(value, depth)
  local t = type(value)
  if t == "string" then return #value + 2 + escaped(value) end
  if t == "number" then return #tostring(value) end
  if t == "boolean" then return value and 4 or 5 end
  if t ~= "table" then return 0 end
  local indent = (depth + 1) * 4
  local total = 2 * depth * 4 + 8
  for k, v in pairs(value) do
    local key = (type(k) == "string") and (#k + 4) or (#tostring(k) + 2)
    total = total + indent + key + 3 + size_of(v, depth + 1) + 4
  end
  return total
end
M.size_of = size_of

local function sum(sv, keys)
  local total = 0
  for i = 1, #keys do
    local v = sv[keys[i]]
    if v ~= nil then total = total + size_of(v, 4) end
  end
  return total
end

function M.section_of(key)
  return SECTION[key]
end

function M.report()
  local sv = Vermilion.SavedVars or {}
  local SS = Vermilion.SessionStore
  return {
    sessions = sum(sv, SESSIONS),
    session_count = SS.count(),
    session_cap = SS.cap(),
    diagnostics = Vermilion.Constants.DEBUG and sum(sv, DIAGNOSTICS) or 0,
    preferences = sum(sv, PREFERENCES),
  }
end

function M.format_bytes(n)
  if n >= 1048576 then return string.format("%.1f MB", n / 1048576) end
  if n >= 1024 then return string.format("%d KB", math.floor(n / 1024 + 0.5)) end
  return string.format("%d B", n)
end
