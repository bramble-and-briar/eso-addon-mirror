Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Format = {}
local M = Verdant.Format

local math_floor    = math.floor
local string_format = string.format

local function fmt_val(v)
  return ZO_AbbreviateAndLocalizeNumber(math_floor(v), NUMBER_ABBREVIATION_PRECISION_TENTHS, false)
end

local function text_width(label, text)
  return math.ceil(label:GetStringWidth(text) / Verdant.zenimax.api.GetUIGlobalScale())
end

local function fmt_secs(ms)
  local s = math_floor(ms / 1000)
  if s >= 60 then return string_format("%d:%02d", math_floor(s / 60), s % 60) end
  return s .. "s"
end

local SCR = { hex = setmetatable({}, { __mode = "k" }) }

local function hexc(c)
  local cache = SCR.hex
  local e = cache[c]
  if e and e.r == c.r and e.g == c.g and e.b == c.b then return e.hex end
  local hex = string_format("%02x%02x%02x",
    math_floor(c.r * 255 + 0.5), math_floor(c.g * 255 + 0.5), math_floor(c.b * 255 + 0.5))
  if e then
    e.r, e.g, e.b, e.hex = c.r, c.g, c.b, hex
  else
    cache[c] = { r = c.r, g = c.g, b = c.b, hex = hex }
  end
  return hex
end

M.value = fmt_val
M.text_width = text_width
M.secs  = fmt_secs
M.hex   = hexc
