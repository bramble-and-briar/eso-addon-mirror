
Verdant = Verdant or {}
Verdant.zenimax = Verdant.zenimax or {}
local Verdant = Verdant

Verdant.zenimax.events = {}

local EVENT_MANAGER = EVENT_MANAGER
local d             = d
local pcall         = pcall
local tostring      = tostring
local string_format = string.format
local GetString     = GetString

local M = Verdant.zenimax.events

function M.register_addon_loaded(name, callback)
  EVENT_MANAGER:RegisterForEvent(name, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName == name then
      EVENT_MANAGER:UnregisterForEvent(name, EVENT_ADD_ON_LOADED)
      callback()
    end
  end)
end


local MAX_NAMES = 32
local MSG_MAX   = 200
local err_total = 0
local err_names = 0
local err_by    = {}
local err_lines = {}
local notified  = false
local no_code   = {}

local function code_of(name)
  local map = Verdant.Constants.ERRORS
  return map and map.CODES[name] or 0
end

local function label_of(code)
  return string_format("V-%03d", code)
end

local function seen(name)
  if code_of(name) == 0 then no_code[name] = true end
end

local function note(name, err, fallback, quiet)
  err_total = err_total + 1
  local code = code_of(name)
  if code == 0 then code = fallback or 0 end
  local e = err_by[name]
  local first = false
  if e then
    e.count = e.count + 1
  elseif err_names < MAX_NAMES then
    err_names = err_names + 1
    err_by[name] = { count = 1, code = code, first = tostring(err):sub(1, MSG_MAX) }
    first = true
  end
  if quiet then return end
  if Verdant.Constants.DEBUG then
    if first then
      d("[Verdant] " .. label_of(code) .. " '" .. name .. "' error: " .. tostring(err))
    end
  elseif not notified then
    notified = true
    d("[Verdant] " .. string_format(GetString(VERDANT_ERROR_NOTICE), label_of(code)))
  end
end

local guarded = setmetatable({}, { __mode = "k" })

local function catch_all()
  local map = Verdant.Constants.ERRORS
  return map and map.CATCH_ALL or 0
end

function M.guard(name, fn)
  local function door(...)
    local ok, err = pcall(fn, ...)
    if not ok then note(name, err, catch_all()) end
  end
  guarded[door] = true
  return door
end

function M.is_guarded(fn)
  return guarded[fn] == true
end

function M.doors(prefix)
  return setmetatable({}, { __index = function(modules, module)
    local fns = setmetatable({}, { __index = function(known, fn)
      local function call(...) return Verdant[module][fn](...) end
      local door = M.guard(prefix .. module .. "." .. fn, call)
      rawset(known, fn, door)
      return door
    end })
    rawset(modules, module, fns)
    return fns
  end })
end

function M.register(name, eventCode, handler)
  seen(name)
  EVENT_MANAGER:RegisterForEvent(name, eventCode, function(_, ...)
    local ok, err = pcall(handler, ...)
    if not ok then note(name, err) end
  end)
end

function M.error_label(name)
  return label_of(code_of(name))
end

function M.fail(name, err, line)
  seen(name)
  note(name, err, nil, true)
  if line then d("[Verdant] " .. line) end
end

function M.uncoded()
  local names = {}
  for name in pairs(no_code) do names[#names + 1] = name end
  table.sort(names)
  return names
end

function M.error_count() return err_total end

function M.errors() return err_by, err_total end

function M.error_lines()
  for i = #err_lines, 1, -1 do err_lines[i] = nil end
  if err_total == 0 then
    err_lines[1] = "none"
    return err_lines
  end
  local names = {}
  for name in pairs(err_by) do names[#names + 1] = name end
  table.sort(names, function(a, b)
    local ca, cb = err_by[a].code, err_by[b].code
    if ca ~= cb then return ca < cb end
    return a < b
  end)
  err_lines[1] = "total " .. err_total .. " in " .. #names .. " handlers"
  for i = 1, #names do
    local e = err_by[names[i]]
    err_lines[#err_lines + 1] = label_of(e.code) .. " " .. names[i] .. " x" .. e.count .. ": " .. e.first
  end
  return err_lines
end

function M.reset_errors()
  err_total = 0
  err_names = 0
  notified = false
  for k in pairs(err_by) do err_by[k] = nil end
end

function M.unregister(name, eventCode)
  EVENT_MANAGER:UnregisterForEvent(name, eventCode)
end

function M.add_filter(name, eventCode, ...)
  EVENT_MANAGER:AddFilterForEvent(name, eventCode, ...)
end

function M.register_update(name, interval_ms, callback)
  seen(name)
  EVENT_MANAGER:RegisterForUpdate(name, interval_ms, function(...)
    local ok, err = pcall(callback, ...)
    if not ok then note(name, err) end
  end)
end

function M.unregister_update(name)
  EVENT_MANAGER:UnregisterForUpdate(name)
end
