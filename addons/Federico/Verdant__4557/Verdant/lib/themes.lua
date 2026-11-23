Verdant = Verdant or {}
local Verdant = Verdant
Verdant.lib = Verdant.lib or {}
Verdant.lib.themes = {}
local M = Verdant.lib.themes

local BASE = "Verdant/assets/themes/"
local STANDARD = "piano"
local FORMAT = 1
local COLORS = { "text", "dim", "metal", "accent" }
local ROLES = {
  "arrow_down_down", "arrow_down_over", "arrow_down_up", "arrow_left_down", "arrow_left_over",
  "arrow_left_up", "arrow_right_down", "arrow_right_over", "arrow_right_up", "arrow_up_down",
  "arrow_up_over", "arrow_up_up", "background", "btn_disabled", "btn_down", "btn_over", "btn_up",
  "bucket_down", "bucket_over", "bucket_up", "caret", "close_down", "close_over", "close_up", "delete",
  "export_disabled", "export_down", "export_over", "export_up", "frame_edge", "help", "lacq_disabled",
  "lacq_down", "lacq_over", "lacq_up", "lamp_off", "lamp_on", "lib_down", "lib_over", "lib_up",
  "lock_closed", "lock_open", "panel_center", "panel_edge", "radio_off", "radio_off_disabled", "radio_on",
  "radio_on_disabled", "save_disabled", "save_down", "save_over", "save_up", "say_disabled", "say_down",
  "say_over", "say_up", "scroll_thumb", "scroll_track", "slider_fill", "slider_groove", "slider_thumb",
  "subtab", "tab_idle", "tab_on", "tab_over", "viewport_edge",
}
local IS_ROLE = {}
for i = 1, #ROLES do IS_ROLE[ROLES[i]] = true end
local TINTS = {
  viewport  = { r = 0.78, g = 1.00, b = 0.86 },
  crosshair = { r = 0.50, g = 1.00, b = 0.62 },
  band      = { r = 0.78, g = 1.00, b = 0.86 },
  name      = { r = 0.86, g = 0.92, b = 0.88 },
  lane      = { r = 0.62, g = 1.00, b = 0.74 },
  watch     = { r = 0.40, g = 0.85, b = 0.52 },
  select    = { r = 0.55, g = 0.92, b = 0.62 },
}
local live = {}

local themes, order = {}, {}
local current = STANDARD
local listeners = {}

local function tint_of(name)
  local theme = themes[current]
  return (theme and theme.tints[name]) or TINTS[name]
end

local function paint_live()
  for i = 1, #live do
    local t = live[i]
    local c = tint_of(t.tint)
    t.r, t.g, t.b = c.r, c.g, c.b
  end
end

local function is_colour(c)
  if type(c) ~= "table" then return false end
  for _, part in ipairs({ "r", "g", "b" }) do
    local v = c[part]
    if type(v) ~= "number" or v < 0 or v > 1 then return false end
  end
  return true
end

function M.register(desc)
  if type(desc) ~= "table" then return false, "a theme is described by a table" end
  if type(desc.key) ~= "string" or desc.key == "" then return false, "a theme needs a key" end
  if themes[desc.key] then return false, "there is already a theme called " .. desc.key end
  if type(desc.name) ~= "string" or desc.name == "" then return false, desc.key .. " needs a name" end
  if desc.format ~= FORMAT then return false, desc.key .. " is of format " .. tostring(desc.format) .. ", this is " .. FORMAT end
  local theme = { key = desc.key, name = desc.name, lacks = {}, tints = {} }
  for i = 1, #COLORS do
    local name = COLORS[i]
    if not is_colour(desc[name]) then return false, desc.key .. " needs a colour for " .. name end
    theme[name] = { r = desc[name].r, g = desc[name].g, b = desc[name].b }
  end
  if desc.ink ~= nil then
    if not is_colour(desc.ink) then return false, desc.key .. " needs a colour for its ink" end
    theme.ink = { r = desc.ink.r, g = desc.ink.g, b = desc.ink.b }
  else
    theme.ink = theme.text
  end
  for name, c in pairs(desc.tints or {}) do
    if not TINTS[name] then return false, desc.key .. " tints " .. tostring(name) .. ", which is not a tint" end
    if not is_colour(c) then return false, desc.key .. " needs a colour for its " .. name .. " tint" end
    theme.tints[name] = { r = c.r, g = c.g, b = c.b }
  end
  for _, role in ipairs(desc.without or {}) do
    if not IS_ROLE[role] then return false, desc.key .. " leaves out " .. tostring(role) .. ", which is not a role" end
    theme.lacks[role] = true
  end
  themes[desc.key] = theme
  order[#order + 1] = desc.key
  return true
end

function M.tint(name, a)
  if not TINTS[name] then return nil end
  local c = tint_of(name)
  local t = { tint = name, r = c.r, g = c.g, b = c.b, a = a or 1 }
  live[#live + 1] = t
  return t
end

local function tell()
  paint_live()
  for i = 1, #listeners do listeners[i](current) end
end

function M.use(key)
  if not themes[key] then key = STANDARD end
  if key ~= current then
    current = key
    tell()
  end
  return current
end

function M.forget(key)
  if key == STANDARD or not themes[key] then return false end
  themes[key] = nil
  for i = #order, 1, -1 do
    if order[i] == key then table.remove(order, i) end
  end
  if current == key then M.use(STANDARD) end
  return true
end

function M.on_change(fn)
  local listener = Verdant.zenimax.events.guard("theme change", fn)
  listeners[#listeners + 1] = listener
  return listener
end

function M.forget_listener(listener)
  for i = #listeners, 1, -1 do
    if listeners[i] == listener then table.remove(listeners, i) end
  end
end

function M.list() return order end
function M.roles() return ROLES end
function M.standard() return STANDARD end
function M.current() return current end

function M.name(key)
  local theme = themes[key]
  if not theme then return nil end
  return Verdant.zenimax.api.GetString(rawget(_G, theme.name))
end

function M.provides(key, role)
  local theme = themes[key]
  return theme ~= nil and IS_ROLE[role] == true and not theme.lacks[role]
end

function M.path(key, role)
  return BASE .. key .. "/" .. role .. ".dds"
end

function M.texture(role)
  if not IS_ROLE[role] then return nil end
  return M.path(M.provides(current, role) and current or STANDARD, role)
end

function M.color(name)
  local theme = themes[current] or themes[STANDARD]
  return theme and theme[name] or nil
end
