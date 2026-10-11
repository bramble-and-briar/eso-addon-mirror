-- Chat commands: /lfc <item>, /lfc raw <item>, /lfc db

local LFC = LibFurnitureCatalogue

local this = {}
LFC.Internal.Chat = this

local api = LFC.API
local fmt = LFC.Internal.Format
local query = LFC.Internal.Query

local resolveRecipe = LFC.Internal.Build.ResolveRecipe
local furnishingCategory = LFC.Internal.Build.FurnishingCategory
local CRAFTING = LFC.Internal.Constants.ItemSources.CRAFTING

local getItemId, getItemLink = fmt.GetItemId, fmt.GetItemLink
local getItemName = fmt.GetItemName
local stripTxt = fmt.stripTxt
local stringKeys = LFC.Internal.StringKeys

-- value -> name (readable source name instead of id)
local SOURCE_NAME = LFC.Internal.Constants.SourceNames

---@param value integer source type value
---@return string
local function sourceName(value)
  return SOURCE_NAME[value] or tostring(value)
end

---Version values can change, so name is the only half worth printing
---@param value integer
---@return string
local function versionLabel(value)
  return LFC.Internal.Constants.VersionNames[value] or tostring(value)
end

---@param categoryId integer
---@param subcategoryId integer
---@return string
local function categoryLabel(categoryId, subcategoryId)
  local category = categoryId and categoryId ~= 0 and GetFurnitureCategoryInfo(categoryId)
  local subcategory = subcategoryId and subcategoryId ~= 0 and GetFurnitureCategoryInfo(subcategoryId)
  return string.format(
    "%s/%s",
    category and string.format("%d(%s)", categoryId, category) or tostring(categoryId),
    subcategory and string.format("%d(%s)", subcategoryId, subcategory) or tostring(subcategoryId)
  )
end

---Locale string id changes per session, instead we use the name as stable key. An id we have no key for is not ours and prints as the bare number (like furniture categories)
---@param id integer|string|nil
---@return string?
local function idWithKey(id)
  if not id then
    return nil
  end
  return (type(id) == "number" and stringKeys[id]) or tostring(id)
end

local PREFIX = "|c72DB00LFC|r: "

-- Markup the chat window will not render
local CHAT_STRIP = {
  "|u%d+:%d+.-|u",
}

---Chat-safe single line: item links and colours survive, the rest does not. Turns newlines into spaces
---@param txt any
---@return string
local function line(txt)
  txt = tostring(txt or "")
  if txt == "" then
    return ""
  end
  txt = txt:gsub("%s*[\r\n]+%s*", " ")
  return (stripTxt(txt, CHAT_STRIP):gsub("^%s+", ""):gsub("%s+$", ""))
end
this.Line = line

local function say(txt)
  d(PREFIX .. line(txt))
end

-- chat has a limited length and raw link length counts against it, so links go out a few at a time
local LINKS_PER_LINE = 3

---@param itemId integer
---@return string "id: link", or the bare id when no item behind it renders
local function idAndLink(itemId)
  local link = getItemLink(itemId)
  if link == "" or getItemName(itemId) == "" then
    return tostring(itemId)
  end
  return string.format("%d: %s", itemId, link)
end

---@param itemId integer
---@param entry? FurCEntry adds the recipe when the item is craftable
---@return string
local function label(itemId, entry)
  local text = idAndLink(itemId)
  if entry and entry.blueprint then
    text = text .. " (" .. idAndLink(entry.blueprint) .. ")"
  end
  return text
end

-- one shared waiter, so repeated calls while building do not stack up
local function noop() end

---Item id and entry for what the player typed, or nil with the reason
---@param rest string
---@return integer? itemId
---@return FurCEntry? entry
local function resolve(rest)
  if rest == "" then
    this.PrintUsage()
    return nil
  end

  if not api.IsReady() then
    say(GetString(SI_FURC_CHAT_BUILDING))
    api.OnReady(noop)
    return nil
  end

  -- a typed id arrives as text, a link does not
  local itemId = getItemId(tonumber(rest) or rest)
  if not itemId then
    say(zo_strformat(GetString(SI_FURC_CHAT_BAD_ITEM), rest))
    return nil
  end

  -- a recipe answers for the furnishing it crafts, and keeps itself as the recipe
  itemId = resolveRecipe(itemId) or itemId

  local entry = api.GetEntry(itemId)
  if not entry then
    -- an item that is simply not furniture still renders, so it keeps its link
    say(zo_strformat(GetString(SI_FURC_CHAT_UNKNOWN), idAndLink(itemId)))
    return nil
  end

  return itemId, entry
end

---Every source of an item, ranked, already localised
---@param itemId integer
---@param entry FurCEntry
---@return { source: integer, text: string }[]
local function rankedSources(itemId, entry)
  return query.GetRankedSources(itemId, entry, false)
end

---Ingredient lines, empty when the item is not craftable
---@param itemId integer
---@param entry FurCEntry
---@return string[]
local function matLines(itemId, entry)
  local lines = {}
  for ingredientLink, quantity in pairs(api.GetIngredients(getItemLink(itemId), entry)) do
    lines[#lines + 1] = string.format("%dx %s", quantity, ingredientLink)
  end
  table.sort(lines)
  return lines
end

local function sayEach(lines)
  for _, text in ipairs(lines) do
    say("- " .. text)
  end
end

local COMMANDS = {}

-- /lfc db
-- TODO: put more useful or flashy stuff in here, it looks a bit sad
function COMMANDS.db()
  local state, err = api.GetState()
  say(
    string.format(
      "%s %d  state=%s  revision=%d  items=%d",
      LFC.name,
      api.GetVersion(),
      tostring(state),
      api.GetDBRevision(),
      api.GetEntryCount()
    )
  )
  if err then
    say("error=" .. tostring(err))
  end
end

-- /lfc raw <item>
function COMMANDS.raw(rest)
  local itemId, entry = resolve(rest)
  if not itemId or not entry then
    return
  end
  say(label(itemId, entry))

  -- The row stores only what the game cannot answer, so this one asks the game for the rest
  local flags = {
    "primary=" .. sourceName(query.OriginOf(entry)),
    "version=" .. versionLabel(entry.version),
    "cat=" .. categoryLabel(furnishingCategory(itemId)),
  }
  if entry.blueprint then
    flags[#flags + 1] = "blueprint=" .. tostring(entry.blueprint)
  end
  local craftingSkill = query.GetCraftingSkillType(itemId, entry)
  if craftingSkill and craftingSkill ~= 0 then
    flags[#flags + 1] = "skill=" .. tostring(craftingSkill)
  end
  say(table.concat(flags, " "))

  local names = {}
  for source in pairs(entry.sources) do
    names[#names + 1] = sourceName(source)
  end
  table.sort(names)
  say("sources=" .. table.concat(names, ","))

  for index, record in ipairs(api.GetSourceDetails(itemId)) do
    local parts = { string.format("[%d] type=%s", index, sourceName(record.source.type)) }
    for _, field in ipairs({ "vendor", "note", "achievement", "collectible", "event" }) do
      local value = idWithKey(record.source[field])
      if value then
        parts[#parts + 1] = field .. "=" .. value
      end
    end
    -- one entry per place the source covers (a zone and a place inside it share one entry)
    for _, placement in ipairs(record.source.locations or {}) do
      if placement.location then
        -- strip zone names of their grammar control chars
        local zone = zo_strformat("<<1>>", GetZoneNameById(placement.location))
        parts[#parts + 1] = string.format("location=%d(%s)", placement.location, zone)
      end
      local place = idWithKey(placement.place)
      if place then
        parts[#parts + 1] = "place=" .. place
      end
    end
    if record.cost then
      parts[#parts + 1] = string.format("cost=%s/%s", tostring(record.cost.amount), tostring(record.cost.currency))
    end
    if record.lastSeen then
      parts[#parts + 1] = "lastSeen=" .. tostring(record.lastSeen)
    end
    say(table.concat(parts, " "))
  end
end

-- /lfc <item>
local function printEntry(rest)
  local itemId, entry = resolve(rest)
  if not itemId or not entry then
    return
  end

  say(label(itemId, entry))

  local texts = {}
  for _, record in ipairs(rankedSources(itemId, entry)) do
    texts[#texts + 1] = record.text
  end
  if #texts > 0 then
    sayEach(texts)
  -- crafting mats are the answer and no source is missing (almost all blueprints are container drops, except from master writ vendor)
  elseif not (entry.sources and entry.sources[CRAFTING]) then
    say(GetString(SI_FURC_CHAT_NO_SOURCE))
  end

  local mats = matLines(itemId, entry)
  for first = 1, #mats, LINKS_PER_LINE do
    local chunk = {}
    for i = first, math.min(first + LINKS_PER_LINE - 1, #mats) do
      chunk[#chunk + 1] = mats[i]
    end
    local prefix = first == 1 and GetString(SI_FURC_CHAT_MATS) .. " " or ""
    say(prefix .. table.concat(chunk, ", "))
  end
end

function this.PrintUsage()
  say(GetString(SI_FURC_CHAT_USAGE))
  d("  |cAACCFF/lfc <item>|r")
  d("  |cAACCFF/lfc raw <item>|r")
  d("  |cAACCFF/lfc db|r")
end

---@param args string everything the player typed after the command
local function handleSlash(args)
  args = tostring(args or "")
  local first, rest = args:match("^%s*(%S*)%s*(.-)%s*$")
  local command = COMMANDS[(first or ""):lower()]

  -- an item link is not a subcommand, so anything else is the item itself
  if command then
    command(rest or "")
  else
    printEntry((args:match("^%s*(.-)%s*$")))
  end
end
this.HandleSlash = handleSlash

---Register a slash command unless another AddOn already uses it
---@param key string
---@return boolean claimed
local function claim(key)
  if SLASH_COMMANDS[key] ~= nil then
    LFC.Internal.GetLogger():Warn("%s is already taken, no chat command registered for it", key)
    return false
  end
  SLASH_COMMANDS[key] = handleSlash
  return true
end
this.Claim = claim

claim("/lfc")
claim("/LFC")
