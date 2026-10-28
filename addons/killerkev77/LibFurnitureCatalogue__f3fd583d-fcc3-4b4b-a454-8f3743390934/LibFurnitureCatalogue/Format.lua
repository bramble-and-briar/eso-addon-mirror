-- String, link and name utilities
--
-- Only the utility half lives here: stripping, colouring, item links, item names and prices.
-- Composing a sentence is the consumer's - the add-on writes what a player reads, and the
-- library's own rudimentary line is assembled from records in Query.lua.

FurC = FurC or {}
local LFC = LibFurnitureCatalogue

local this = {}
LFC.Internal.Format = this

local sFormat = zo_strformat

--[[_______________________
    |                     |
    |     TABLE UTILS     |
    |_____________________|]]

--- Merges Table2 into Table1, mutates Table1 inplace and replaces its values if they have the same key. Example: merge({a="1",b="3"},{b="2"}) => {a="1",b="2"}
--- @param t1 any
--- @param t2 any
--- @see ZO_CombineNonContiguousTables (for no entry replacement)
--- @return table
--- Not a formatter:
function LFC.Internal.MergeTable(t1, t2)
  if nil == t2 and nil == t1 then
    return {}
  elseif nil == t2 then
    return t1
  elseif nil == t1 then
    return t2
  end

  for k, v in pairs(t2) do
    t1[k] = v
  end
  return t1
end

--[[_______________________
    |                     |
    |    STRING UTILS     |
    |_____________________|]]

-- Patterns that are incompatible with chat messages
local STRIP_PATTERNS = {
  "|c%x%x%x%x%x%x", -- <colour>
  "|r", -- </colour>
  "|u%d+:%d+.-|u", -- <number/>
  "|t%d+.-|t", -- <texture/>
}
-- Patterns to remove any control and gender suffix to get the clean name, necessary when we have no control over the raw string
local STRIP_CONTROL = {
  "%^.+",
}
this.STRIP_CONTROL = STRIP_CONTROL

---Strips patterns from string
---@param txt string Text containing `|` tags
---@param patterns? table<string> list of patterns to strip
---@return string txt stripped text
local function stripTxt(txt, patterns)
  assert(type(txt) == "string", "How do you strip that which is no string?")
  if txt == "" then
    return ""
  end

  patterns = patterns or STRIP_PATTERNS
  for _, pattern in ipairs(patterns) do
    txt = txt:gsub(pattern, "")
  end

  return txt
end
this.stripTxt = stripTxt

--[[
TODO #REFACTOR
  right now we are calling this function even with stripColor=true,
    and stripColor is passed from `GetItemDescription` down to `this.colourise`, so in some cases colourise actually means "do nothing"
]]
local function colourise(txt, colourCode, ret)
  txt = tostring(txt)
  if ret then
    return txt
  end
  return string.format("|c%s%s|r", colourCode, txt)
end
this.Colourise = colourise

---Format price string with currency
---@param price number
---@param currency CurrencyType defaults to CURT_MONEY
---@return string
function this.FormatPrice(price, currency)
  return ZO_Currency_FormatKeyboard(currency or CURT_MONEY, price, ZO_CURRENCY_FORMAT_AMOUNT_ICON)
end

--[[_______________________
    |                     |
    |     LINK/NAME       |
    |_____________________|]]

--- Get item link from itemId (or itemLink)
--- @param item number|string ID or itemlink
--- @return string link or empty string
local linkCache = {}
local function getItemLink(item)
  if not item or (type(item) ~= "number" and type(item) ~= "string") then
    return ""
  end

  if type(item) == "number" then
    if item <= 0 then
      return ""
    end
    local cached = linkCache[item]
    if cached then
      return cached
    end
    -- string.format instead of zo_strformat so we skip localization
    local link = string.format("|H1:item:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", item)
    linkCache[item] = link
    return link
  end

  local itemId = GetItemLinkItemId(item)
  if itemId == 0 then
    -- invalid, let's clean it up
    return ""
  end

  -- already a link, nothing to do
  return item
end
this.GetItemLink = getItemLink

--- Drops id->link (just for benchmarks)
function this.ClearLinkCache()
  linkCache = {}
end

-- GetItemLinkItemId doesn't work the way I need it
-- TODO #REFACTOR: should only take one type of link (not nil, number, string, links)
function this.GetItemId(itemLink)
  if nil == itemLink or "" == itemLink then
    return
  end
  if type(itemLink) == "number" and itemLink > 9999 then
    return itemLink
  end
  local _, _, _, itemId = ZO_LinkHandler_ParseLink(itemLink)
  return tonumber(itemId)
end

---Return the formatted item name
---@param itemId number
---@param fmt? string optional format, default is stripped of gender control characters
---@return string
function this.GetItemName(itemId, fmt)
  local name = GetItemLinkName(getItemLink(itemId))
  if fmt then
    return sFormat(fmt, name)
  end

  return stripTxt(name, STRIP_CONTROL)
end

-- Legacy aliasses for Internal.lua
FurC.Utils = FurC.Utils or {}
for k, v in pairs(this) do
  FurC.Utils[k] = v
end
