Vermilion = Vermilion or {}
Vermilion.Format = {}
local M = Vermilion.Format

local math_floor    = math.floor
local string_format = string.format
local ZO_AbbreviateAndLocalizeNumber = ZO_AbbreviateAndLocalizeNumber

local SCR = { hex = setmetatable({}, { __mode = "k" }) }

local function fmt_val(v)
  return ZO_AbbreviateAndLocalizeNumber(math_floor(v), 0, false)
end

local function fmt_secs(ms)
  local s = math_floor(ms / 1000)
  if s >= 60 then return string_format("%d:%02d", math_floor(s / 60), s % 60) end
  return s .. "s"
end

local function fmt_readout(v)
  return ZO_AbbreviateAndLocalizeNumber(math_floor(v + 0.5), 1, false)
end

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

M.val, M.secs, M.readout, M.hex = fmt_val, fmt_secs, fmt_readout, hexc
