-- DB read path: Find, ingredient/material queries, per-source description renderers

local FurC = FurC or {}
FurC.DBQuery = FurC.DBQuery or {}
local this = FurC.DBQuery
LibFurnitureCatalogue.Internal.Query = this

local LFC = LibFurnitureCatalogue
local npc = LFC.Internal.Constants.NPC
local src = LFC.Internal.Constants.ItemSources
local npcIds = LFC.Internal.Constants.NpcIds
local vendorLocations = LFC.Internal.Constants.VendorLocations
local npcByName = LFC.Internal.Constants.NpcByName
local eventByName = LFC.Internal.Constants.EventByName

local getItemId = LFC.Internal.Format.GetItemId
local getItemLink = LFC.Internal.Format.GetItemLink
local getItemName = LFC.Internal.Format.GetItemName
local stripText = LFC.Internal.Format.stripTxt
local strPrice = LFC.Internal.Format.FormatPrice
local STRIP_CONTROL = LFC.Internal.Format.STRIP_CONTROL

local resolvers = LFC.Internal.Constants.Resolvers
local resolveEvent = resolvers.Event
local resolveNpc = resolvers.Npc
local resolveNpcClass = resolvers.NpcClass
local resolveNpcGroup = resolvers.NpcGroup
local resolvePlace = resolvers.Place
local resolveSkillLine = resolvers.SkillLine
local resolveZone = resolvers.Zone
local resolveCrate = resolvers.Crate
local isZoneId = LFC.Internal.Constants.IsZoneId

local db = LFC.Internal.DB
local ensureDB = LFC.Internal.Build.EnsureDB
local parseFurnitureItem = LFC.Internal.Build.ParseFurnitureItem
local parseBlueprint = LFC.Internal.Build.ParseBlueprint
local primarySource = LFC.Internal.Build.PrimarySource
local eachSource = LFC.Internal.Build.EachSource
local sourceMask = LFC.Internal.Build.SourceMask

---The row's best-ranked source, for ordering records and picking the line that describes an item
---@param recipeArray FurCEntry|table
---@return integer? origin
local function originOf(recipeArray)
  local sources = recipeArray and recipeArray.sources
  return (sources and primarySource(sourceMask(sources))) or nil
end
this.OriginOf = originOf
local SOURCE_PRIORITY = LFC.Internal.Constants.SOURCE_PRIORITY

-- single-entry memo for find
local lastLink = nil
local recipeArray = nil
local lastKey = nil
local memoRevision = nil

---Same lookup as `find`, but also hands back the id the entry is stored under (only worth calling when you need that id)
--- A blueprint resolves to the crafted item's entry
---@param itemOrBlueprintLink string|integer item link, blueprint link, or itemId
---@return FurCEntry entry the entry, or `{}` if unknown
---@return integer? key the crafted item's id (not the blueprint). nil when unknown
local function findWithKey(itemOrBlueprintLink)
  ensureDB()
  if tonumber(itemOrBlueprintLink) == itemOrBlueprintLink then
    itemOrBlueprintLink = getItemLink(itemOrBlueprintLink)
  end
  if nil == itemOrBlueprintLink or #itemOrBlueprintLink == 0 then
    return {}
  end

  if itemOrBlueprintLink == lastLink and nil ~= recipeArray and memoRevision == LFC.Internal.DBRevision then
    return recipeArray, lastKey
  else
    recipeArray, lastKey = nil, nil
    lastLink = itemOrBlueprintLink
  end

  local generated = LFC.Internal.Generated
  local generatedKey = generated and generated.Key(getItemId(itemOrBlueprintLink))
  if generatedKey then
    recipeArray, lastKey = db[generatedKey], generatedKey
  elseif IsItemLinkFurnitureRecipe(itemOrBlueprintLink) then
    recipeArray, lastKey = parseBlueprint(itemOrBlueprintLink)
  elseif IsItemLinkPlaceableFurniture(itemOrBlueprintLink) then
    recipeArray, lastKey = parseFurnitureItem(itemOrBlueprintLink)
  else
    local itemId = getItemId(itemOrBlueprintLink)
    if itemId ~= nil and tonumber(itemId) > 0 then
      recipeArray = db[itemId]
      lastKey = recipeArray and itemId or nil
    end
  end

  memoRevision = LFC.Internal.DBRevision
  return recipeArray or {}, lastKey
end
this.FindWithKey = findWithKey

---DB entry for an item/blueprint, builds DB on first use. The normal lookup to reach for
---@param itemOrBlueprintLink string|integer item link, blueprint link, or itemId
---@return FurCEntry entry the entry, or `{}` if unknown
local function find(itemOrBlueprintLink)
  return (findWithKey(itemOrBlueprintLink))
end
this.Find = find

---Which crafting-station recipe a blueprint grants
---@param recipeArray FurCEntry
---@return integer? listIndex nil when the client cannot resolve the link as a recipe
---@return integer? index
local function grantedRecipeIndices(recipeArray)
  local blueprintId = recipeArray and (recipeArray.blueprint or recipeArray.id)
  if not blueprintId then
    return nil, nil
  end
  return GetItemLinkGrantedRecipeIndices(getItemLink(blueprintId))
end
this.GrantedRecipeIndices = grantedRecipeIndices

local function getIngredients(itemLink, recipeArray)
  recipeArray = recipeArray or find(itemLink)
  local ingredients = {}
  if not recipeArray or next(recipeArray) == nil then
    return ingredients
  end
  if recipeArray.blueprint then
    local blueprintLink = getItemLink(recipeArray.blueprint)
    local numIngredients = GetItemLinkRecipeNumIngredients(blueprintLink)
    for ingredientIndex = 1, numIngredients do
      local name, _, qty = GetItemLinkRecipeIngredientInfo(blueprintLink, ingredientIndex)
      local ingredientLink = GetItemLinkRecipeIngredientItemLink(blueprintLink, ingredientIndex, LINK_STYLE_DEFAULT)
      ingredients[ingredientLink] = qty
    end
  else
    -- for non valid blueprints "ingredients" just returns "1x Fish". We have to catch it before it passes the fish.
    local listIndex, index = grantedRecipeIndices(recipeArray)
    if not (listIndex and index) then
      return ingredients
    end
    local _, name, numIngredients = GetRecipeInfo(listIndex, index)
    for ingredientIndex = 1, numIngredients do
      local name, _, qty = GetRecipeIngredientItemInfo(listIndex, index, ingredientIndex)
      local ingredientLink = GetRecipeIngredientItemLink(listIndex, index, ingredientIndex, LINK_STYLE_DEFAULT)
      ingredients[ingredientLink] = qty
    end
  end
  return ingredients
end
this.GetIngredients = getIngredients

local function makeMaterial(recipeKey, recipeArray, tryPlaintext, forcePlaintext)
  if nil == recipeArray or not (recipeArray.blueprint or grantedRecipeIndices(recipeArray)) then
    return "couldn't get material list, please re-scan character knowledge"
  end
  local ret = ""
  local ingredients = getIngredients(recipeKey, recipeArray)
  forcePlaintext = forcePlaintext or tryPlaintext and NonContiguousCount(ingredients) > 4
  for ingredientLink, qty in pairs(ingredients) do
    -- auto-capitalize because for some reason the ZOS API doesn't
    local itemText = (
      forcePlaintext and string.gsub(" " .. GetItemLinkName(ingredientLink), "%W%l", string.upper):sub(2)
    ) or ingredientLink
    ret = zo_strformat("<<1>> <<2>>x <<3>>, ", ret, qty, itemText)
  end
  return ret:sub(0, -3)
end
this.GetMats = makeMaterial

local eventDrop = LFC.Internal.Constants.EVENT_DROP
---Resolve one note value: a string id, a literal, or a `{ npc = }` / `{ item = }` part
---@param value string|integer|table
---@return string
local function resolveNote(value)
  if type(value) == "table" then
    if value.npc then
      return resolveNpc(value.npc)
    end
    if value.npcClass ~= nil then
      return resolveNpcClass(value.npcClass)
    end
    if value.npcGroup then
      return resolveNpcGroup(value.npcGroup)
    end
    if value.item then
      return getItemName(value.item)
    end
    return ""
  end
  if type(value) == "string" then
    return value
  end
  return GetString(value)
end
-- Published through the API
this.ResolveNote = resolveNote

-- Writ Voucher recipes referenced by blueprint id, so every lookup has to try blueprint as well as id
local function voucherEntry(versionData, recipeKey, blueprintId)
  if nil == versionData then
    return
  end
  return versionData[recipeKey] or (blueprintId and versionData[blueprintId])
end

local emptyString = GetString(SI_FURC_SRC_EMPTY)

local strLeads = GetString(SI_FURC_SRC_LEADS)

-- The category word a row renders under when it does not name its own category
local MISC_CATEGORY = {
  [src.DROP] = SI_FURC_SRC_DROP,
  [src.DUNGEON] = SI_FURC_SRC_DUNG,
  [src.HARVEST] = SI_FURC_SRC_HARVEST,
  [src.CHEST] = SI_FURC_SRC_CHESTS,
  [src.QUEST] = SI_FURC_SRC_QUEST,
  [src.BAZAAR] = SI_FURC_SRC_BAZAAR,
  [src.FISHING] = SI_FURC_SRC_FISH,
  [src.PICKPOCKET] = SI_FURC_SRC_PICK,
  [src.STEAL_CONTAINER] = SI_FURC_SRC_STEAL,
  [src.ANTIQUITY] = SI_FURC_SRC_SCRYING,
}

---Vocabulary carries the grammar suffix a formatter needs (`Summerset^N,in`), and this one has no formatter
---@param text any
---@return string
local function plain(text)
  return stripText(tostring(text or ""), STRIP_CONTROL)
end

---Adds a qualifier: a single value, or a list of alternatives. A value that resolves to nothing adds no part.
---@param parts string[] parts, appended to in place
---@param value any a vocabulary value, a `{ npc = }`-style note part, or a list of either
---@param resolve fun(value: any): string
local function addQualifier(parts, value, resolve)
  if value == nil then
    return
  end
  -- A list of ids the client does not define is an empty table, nothing to resolve
  if type(value) == "table" and next(value) == nil then
    return
  end
  if type(value) ~= "table" or value[1] == nil then
    local resolved = plain(resolve(value))
    if resolved ~= "" then
      parts[#parts + 1] = resolved
    end
    return
  end
  local alternatives = {}
  for _, part in ipairs(value) do
    local resolved = plain(resolve(part))
    if resolved ~= "" then
      alternatives[#alternatives + 1] = resolved
    end
  end
  if #alternatives > 0 then
    parts[#parts + 1] = table.concat(alternatives, " / ")
  end
end

-- The data files sharing the [version][source][itemId] shape, in lookup order
local BAKED_DATA_FILES = nil -- lazy init to avoid load-order issues
local function bakedDataFiles()
  local dataFiles = BAKED_DATA_FILES
  if dataFiles then
    return dataFiles
  end
  dataFiles = {}
  local expected = 0
  local function add(dataFile)
    expected = expected + 1
    if dataFile then
      dataFiles[#dataFiles + 1] = dataFile
    end
  end
  add(FurC.MiscItemSources)
  add(FurC.CrownStore)
  add(FurC.Antiquities)
  add(FurC.Justice)
  add(FurC.Fishing)
  if #dataFiles == expected then
    BAKED_DATA_FILES = dataFiles
  end
  return dataFiles
end

---The row a source keeps for one item, in the item's own version
---@return table|string|number|nil
local function lookupBakedData(recipeKey, version, source)
  for _, dataFile in ipairs(bakedDataFiles()) do
    local versionFiles = version and dataFile[version]
    local bucket = versionFiles and versionFiles[source]
    local entry = bucket and bucket[recipeKey]
    if entry then
      return entry
    end
  end
  return nil
end

---Same row, falling back to any other version that has one
--- A row moved between versions still answers, which is what the renderers have always done
---@return table|string|number|nil
local function findMiscRow(recipeKey, version, source)
  local row = lookupBakedData(recipeKey, version, source)
  if row then
    return row
  end
  -- TODO: overwrite version (there can be only one)
  for _, dataFile in ipairs(bakedDataFiles()) do
    for _, versionFiles in pairs(dataFile) do
      local bucket = versionFiles[source]
      if bucket and bucket[recipeKey] then
        return bucket[recipeKey]
      end
    end
  end
  return nil
end

---Row backing an item: keyed on the recipe, so the item answers through its blueprint
---@param recipeKey integer
---@param recipeArray? FurCEntry
---@return table? row
local function recipeRow(recipeKey, recipeArray)
  if nil == FurC.RecipeSources then
    return nil
  end
  local row = FurC.RecipeSources[recipeKey]
  if nil ~= row then
    return row
  end
  recipeArray = recipeArray or find(recipeKey)
  return FurC.RecipeSources[recipeArray.blueprint or recipeKey]
end

local function getCraftingSkillType(recipeKey, recipeArray)
  local itemLink = getItemLink(recipeKey)
  local craftingSkillType = GetItemLinkCraftingSkillType(itemLink)

  if 0 == craftingSkillType and recipeArray.blueprint then
    craftingSkillType = GetItemLinkRecipeCraftingSkillType(getItemLink(recipeArray.blueprint))
  elseif 0 == craftingSkillType then
    local listIndex, index = grantedRecipeIndices(recipeArray)
    if listIndex and index then
      _, _, _, _, _, _, craftingSkillType = GetRecipeInfo(listIndex, index)
    end
  end

  return craftingSkillType
end
this.GetCraftingSkillType = getCraftingSkillType

-- Typed per-source records for API

---@param id integer NpcIds value
local function setVendor(rec, id)
  rec.source.vendor = id
end

--- A location is a game zone, anything the game has no zone for is a place
---@param id integer a ZoneIds or PlaceIds value
local function setLocation(rec, id)
  if isZoneId[id] then
    rec.source.location = id
    return
  end
  rec.source.place = id
end

--- Where the vendor is
---@param id integer NpcIds value
local function setVendorLocation(rec, id)
  local source = rec.source
  if source.location or source.locations or source.place then
    return
  end
  local zones
  for _, entry in ipairs(vendorLocations[id] or {}) do
    local locationId = entry.location or entry.place
    if isZoneId[locationId] then
      zones = zones or {}
      zones[#zones + 1] = locationId
    elseif nil == source.place then
      source.place = locationId
    end
  end
  if nil == zones then
    return
  end
  if 1 == #zones then
    source.location = zones[1]
  else
    source.locations = zones
  end
end

local function vendorRecord(rec, recipeKey, version, data, source)
  local function findIn(versionData)
    if not versionData then
      return
    end
    for zoneName, zoneData in pairs(versionData) do
      for vendorName, vendorData in pairs(zoneData) do
        local row = vendorData[recipeKey]
        local matches = source == src.HOME_GOODS
          or (type(row) == "table" and row.achievement and src.ACHIEVEMENT or src.VENDOR) == source
        if row and matches then
          return zoneName, vendorName, row
        end
      end
    end
  end

  local zone, vendor, entry = findIn(data and data[version])
  if not entry then
    for _, versionData in pairs(data or {}) do
      zone, vendor, entry = findIn(versionData)
      if entry then
        break
      end
    end
  end
  if not entry then
    return false
  end
  setVendor(rec, vendor)
  setLocation(rec, zone)
  rec.source.achievement = entry.achievement
  rec.source.note = entry.note
  rec.source.quest = entry.quest
  rec.source.collectible = entry.collectible
  rec.source.skillLine = entry.skillLine
  rec.source.skillRank = entry.skillRank
  if entry.itemPrice then
    rec.cost = { currency = entry.currency or CURT_MONEY, amount = entry.itemPrice }
  end
  return true
end

local function luxuryRecord(rec, recipeKey, version)
  local versionData = FurC.LuxuryFurnisher[version]
  local itemData = versionData and versionData[recipeKey]
  if not itemData then
    for _, vData in pairs(FurC.LuxuryFurnisher) do
      if vData[recipeKey] then
        itemData = vData[recipeKey]
        break
      end
    end
  end
  if not itemData then
    return
  end
  rec.source.vendor = npcIds.LUXF
  setVendorLocation(rec, npcIds.LUXF)
  if itemData.itemPrice then
    rec.cost = { currency = CURT_MONEY, amount = itemData.itemPrice }
  end
  rec.lastSeen = itemData.itemDate
end

local function pvpRecord(rec, recipeKey, version)
  local function findIn(versionData)
    if not versionData then
      return
    end
    for vendorName, vendorData in pairs(versionData) do
      for locationName, locationData in pairs(vendorData) do
        if locationData[recipeKey] then
          return vendorName, locationName, locationData[recipeKey]
        end
      end
    end
  end

  local vendor, location, item = findIn(FurC.PVP[version])
  if not item then
    for _, versionData in pairs(FurC.PVP) do
      vendor, location, item = findIn(versionData)
      if item then
        break
      end
    end
  end
  if not item then
    return
  end
  setVendor(rec, vendor)
  setLocation(rec, location)
  rec.source.achievement = item.achievement
  rec.source.note = item.note
  rec.source.quest = item.quest
  rec.source.collectible = item.collectible
  rec.source.skillLine = item.skillLine
  rec.source.skillRank = item.skillRank
  if item.itemPrice then
    rec.cost = { currency = item.currency or CURT_ALLIANCE_POINTS, amount = item.itemPrice }
  end
end

local function voucherRecord(rec, recipeKey, blueprintId, version)
  local vendor = npcIds.ROLIS
  local entry = voucherEntry(FurC.Rolis[version], recipeKey, blueprintId)
  if not entry then
    entry = voucherEntry(FurC.Faustina[version], recipeKey, blueprintId)
      or voucherEntry(FurC.FaustinaRecipes[version], recipeKey, blueprintId)
    vendor = npcIds.FAUSTINA
  end
  if not entry then
    if FurC.FurnishingFolios then
      for folioId, folioData in pairs(FurC.FurnishingFolios) do
        if folioData.contents then
          for _, contentId in ipairs(folioData.contents) do
            if contentId == recipeKey or contentId == blueprintId then
              rec.source.vendor = folioData.vendor
              rec.source.place = folioData.place
              rec.source.partOf = folioId
              rec.cost = { currency = folioData.currency, amount = folioData.itemPrice }
              return
            end
          end
        end
      end
    end
    return
  end
  rec.source.vendor = vendor
  setVendorLocation(rec, vendor)
  -- one slot, voucher row has either the achievement it needs or the folio it comes in
  rec.source.achievement = entry.achievement
  rec.source.partOf = entry.partOf
  if entry.itemPrice then
    rec.cost = { currency = CURT_WRIT_VOUCHERS, amount = entry.itemPrice }
  end
end

local function eventRecord(rec, recipeKey)
  for _, events in pairs(FurC.EventItems) do
    for eventName, sources in pairs(events) do
      for srcName, items in pairs(sources) do
        local item = items[recipeKey]
        if nil ~= item then
          if srcName ~= eventDrop then
            -- a source that is not an NPC is a container
            rec.source.vendor = npcByName[srcName]
            rec.source.container = rec.source.vendor == nil and getItemId(srcName) or nil
          end
          rec.source.event = eventByName[eventName]
          -- a row is sold when it names a price or an NPC holds it, and only then does its detail reach a line
          if item.itemPrice or npcByName[srcName] then
            rec.source.achievement = item.achievement
            rec.source.collectible = item.collectible
            rec.source.quest = item.quest
            rec.source.skillLine = item.skillLine
            rec.source.skillRank = item.skillRank
            if item.note ~= nil then
              rec.source.note = item.note
            end
          end
          if item.itemPrice then
            rec.cost = {
              currency = item.currency or (srcName == npc.EVENT and CURT_TRADE_BARS or CURT_MONEY),
              amount = item.itemPrice,
            }
          end
          return
        end
      end
    end
  end
end

local SOURCE_CURRENCY_MAP = {
  [src.CROWN] = CURT_CROWNS,
  [src.DROP] = CURT_MONEY,
  [src.JUSTICE] = CURT_MONEY,
  [src.FISHING] = CURT_MONEY,
  [src.ANTIQUITY] = CURT_MONEY,
  [src.OTHER] = CURT_MONEY,
  [src.BAZAAR] = CURT_TRADE_BARS,
  [src.TOMES] = CURT_TOME_POINTS,
  [src.TELVAR] = CURT_TELVAR_STONES,
  [src.COLL_MERCH] = CURT_TELVAR_STONES,
  [src.GUILDSTORE] = CURT_MONEY,
  [src.EDITOR] = CURT_CROWNS,
}
--- Extract a numeric price from baked strings
-- TODO: if performance allows it we should get raw values from DB.. no need to "extract"
local function extractPrice(entry, source)
  if not entry then
    return nil, nil
  end
  local t = type(entry)
  if t == "number" then
    return SOURCE_CURRENCY_MAP[source], entry
  end
  if t == "table" then
    local sources = entry[1] ~= nil and entry or { entry }
    for i = 1, #sources do
      local one = sources[i]
      if type(one) == "table" and one.itemPrice then
        return one.currency or SOURCE_CURRENCY_MAP[source], one.itemPrice
      end
    end
    return nil, nil
  end
  if t == "string" then
    -- Strings come as `|c<hex>...|r|u...:currency:|u` (digit grouping is locale-dependent 1,234; 1 234; 1.234)
    -- numbers outside that markup are item links, control markers, colour codes or some custom text
    local amountText = entry:match("|c%x%x%x%x%x%x(.-)|r|u[^|]*:currency:|u")
    if amountText and not amountText:find("%a") then
      local digits = amountText:gsub("%D", "")
      local n = #digits > 0 and tonumber(digits)
      if n then
        return SOURCE_CURRENCY_MAP[source], n
      end
    end
  end
  return nil, nil
end

-- A crown-store offer names exactly one of these
local CROWN_OFFER_KINDS = { "itemPrice", "pack", "bundle", "crate", "houses", "note", "category" }

local function crownOfferKind(offer)
  for _, kind in ipairs(CROWN_OFFER_KINDS) do
    if offer[kind] ~= nil then
      return kind
    end
  end
end

---The record for a FurC.CrownStore row: 1 offer or a list of offers
---@param rec table the record the caller prepared, for its type
---@param row table
---@return table[]? records one record, nil when the row names no offer
local function crownRecords(rec, row, bucket)
  local offers = row[1] ~= nil and row or { row }
  local records, editor = {}, false
  for i = 1, #offers do
    local offer = offers[i]
    local kind = crownOfferKind(offer)
    local channel = LFC.Internal.Build.CrownOfferSource(offer, bucket)
    editor = editor or channel == src.EDITOR
    if (kind or offer.source) and channel == rec.source.type then
      local record = { source = { type = channel } }
      if kind == "itemPrice" then
        record.cost = { currency = offer.currency or CURT_CROWNS, amount = offer.itemPrice }
      elseif kind == "pack" then
        record.source.packs = { offer.pack }
      elseif kind then
        record.source[kind] = offer[kind]
      end
      records[#records + 1] = record
    end
  end
  if bucket == src.EDITOR and not editor and rec.source.type == src.EDITOR then
    records[#records + 1] = { source = { type = src.EDITOR } }
  end
  return records
end

local function crownRecord(rec, recipeKey, recipeArray, source)
  local records = {}
  local versions = {}
  for version in pairs(FurC.CrownStore or {}) do
    versions[#versions + 1] = version
  end
  table.sort(versions)

  if recipeArray.version then
    table.insert(versions, 1, recipeArray.version)
  end
  local seen = {}
  for _, bucket in ipairs({ src.EDITOR, src.CROWN }) do
    for _, version in ipairs(versions) do
      local data = FurC.CrownStore[version]
      local row = data and data[bucket] and data[bucket][recipeKey]
      if row then
        for _, record in ipairs(crownRecords(rec, row, bucket)) do
          local parts = { tostring(record.source.type) }
          for _, field in ipairs({ "packs", "bundle", "crate", "houses", "note", "category" }) do
            local value = record.source[field]
            if value ~= nil then
              parts[#parts + 1] = field
                .. ":"
                .. (type(value) == "table" and table.concat(value, ",") or tostring(value))
            end
          end
          if record.cost then
            parts[#parts + 1] = record.cost.currency .. ":" .. record.cost.amount
          end
          local key = table.concat(parts, "|")
          if not seen[key] then
            seen[key] = true
            records[#records + 1] = record
          end
        end
        break
      end
    end
  end
  return records
end

-- What a row in the [version][source][itemId] files states about its source
-- TODO: different solution?
local MISC_ROW_FIELDS = {
  "vendor",
  "location",
  "locations",
  "place",
  "event",
  "quest",
  "achievement",
  "collectible",
  "skillLine",
  "skillRank",
  "note",
  "category",
  "itemPack",
  "partOf",
  "container",
  "containerKind",
  "npcClass",
  "leads",
  "rarity",
}

---Fills a record from whichever of the misc-shaped files holds this item under this source
---@return boolean found
local function miscRecord(rec, recipeKey, recipeArray, source)
  local row = findMiscRow(recipeKey, recipeArray.version, source)
  if type(row) ~= "table" then
    return row ~= nil
  end
  local target = rec.source
  for _, field in ipairs(MISC_ROW_FIELDS) do
    if target[field] == nil then
      target[field] = row[field]
    end
  end
  if row.itemPrice and not rec.cost then
    rec.cost = { currency = row.currency or CURT_MONEY, amount = row.itemPrice }
  end
  return true
end

---Fills record from a recipe row
---@param rec table
---@param row table
local function recipeSourceRecord(rec, row)
  local source = rec.source
  if row.quest then
    -- a quest row names no quest, only that it is one and where: { quest = true, locations = { ... } }
    source.category = row.category or SI_FURC_SRC_QUEST
    source.locations = row.locations
    return
  end
  source.vendor = row.vendor
  source.location = row.location
  -- a place is inside the location when both are set (and the only thing we know if there is no location)
  source.place = row.place
  source.note = row.note
  source.achievement = row.achievement
  source.partOf = row.partOf
  source.skillLine = row.skillLine
  source.skillRank = row.skillRank
  source.event = row.event
  if row.itemPrice then
    rec.cost = { currency = row.currency or CURT_MONEY, amount = row.itemPrice }
  end
end

local MISC = "misc" -- a bucket in the [version][source][itemId] files, read by miscRecord
local UNMODELLED = "unmodelled" -- the type is the whole record
local FILTER = "filter" -- not a source on any row

local SOURCE_MODEL = {
  [src.CROWN] = function(rec, recipeKey, recipeArray)
    return crownRecord(rec, recipeKey, recipeArray, src.CROWN)
  end,
  [src.EDITOR] = function(rec, recipeKey, recipeArray)
    return crownRecord(rec, recipeKey, recipeArray, src.EDITOR)
  end,
  [src.VENDOR] = function(rec, recipeKey, recipeArray)
    if not vendorRecord(rec, recipeKey, recipeArray.version, FurC.AchievementVendors, src.VENDOR) then
      miscRecord(rec, recipeKey, recipeArray, src.VENDOR)
    end
  end,
  [src.HOME_GOODS] = function(rec, recipeKey, recipeArray)
    vendorRecord(rec, recipeKey, recipeArray.version, FurC.HomeGoodsFurnisher, src.HOME_GOODS)
  end,
  [src.ACHIEVEMENT] = function(rec, recipeKey, recipeArray)
    vendorRecord(rec, recipeKey, recipeArray.version, FurC.AchievementVendors, src.ACHIEVEMENT)
  end,
  [src.LUXURY] = function(rec, recipeKey, recipeArray)
    luxuryRecord(rec, recipeKey, recipeArray.version)
  end,
  [src.PVP] = function(rec, recipeKey, recipeArray)
    pvpRecord(rec, recipeKey, recipeArray.version)
  end,
  [src.ROLIS] = function(rec, recipeKey, recipeArray)
    voucherRecord(rec, recipeKey, recipeArray.blueprint, recipeArray.version)
  end,
  [src.FESTIVAL_DROP] = function(rec, recipeKey)
    eventRecord(rec, recipeKey)
  end,
  [src.CRAFTING] = function(rec, recipeKey, recipeArray)
    local row = recipeRow(recipeKey, recipeArray)
    if row then
      recipeSourceRecord(rec, row)
    end
  end,

  -- fallback source
  [src.RUMOUR] = UNMODELLED,
  [src.IGNORED] = UNMODELLED,

  -- not real sources but filters
  [src.NONE] = FILTER,
  [src.FAVE] = FILTER,
  [src.CRAFTING_KNOWN] = FILTER,
  [src.CRAFTING_UNKNOWN] = FILTER,
  [src.OTHER] = FILTER,

  -- misc
  [src.WRIT_VENDOR] = MISC,
  [src.DROP] = MISC,
  [src.JUSTICE] = MISC,
  [src.FISHING] = MISC,
  [src.GUILDSTORE] = MISC,
  [src.BAZAAR] = MISC,
  [src.TOMES] = MISC,
  [src.TELVAR] = MISC,
  [src.COLL_MERCH] = MISC,
  [src.ANTIQUITY] = MISC,
  [src.DUNGEON] = MISC,
  [src.HARVEST] = MISC,
  [src.CHEST] = MISC,
  [src.QUEST] = MISC,
  [src.PICKPOCKET] = MISC,
  [src.STEAL_CONTAINER] = MISC,
}
this.SourceModel = SOURCE_MODEL
this.SourceModelKinds = { MISC = MISC, UNMODELLED = UNMODELLED, FILTER = FILTER }

---Folds the place fields on `source` into `locations`, the one spelling records publish
---
---  row spelling (input) -> published record (result)
---               { location = zones.CYRO } ->
--- locations = { { location = zones.CYRO } }
---
---               { place = places.ANY_CAPITAL } ->
--- locations = { { place = places.ANY_CAPITAL } }
---
--- { locations = { zones.COLDH, zones.CRAGLORN } } ->
---   locations = { { location = zones.COLDH }, { location = zones.CRAGLORN } }
---
--- { location = zones.SUMMERSET, place = places.LILANDRIL } ->
---  locations = { { location = zones.SUMMERSET, place = places.LILANDRIL } }
---
---The last row is ONE place inside a zone (not two placements)
---Converting here rather than in each builder keeps the rows lean, and an AddOn never has to ask how many places there are before it knows which field to read
---@param source table the record's origin, mutated in place: authored spellings out, `locations` in
local function normalisePlacements(source)
  local placements = {}
  for _, zoneId in ipairs(source.locations or {}) do
    placements[#placements + 1] = { location = zoneId }
  end
  if source.location or source.place then
    placements[#placements + 1] = { location = source.location, place = source.place }
  end
  source.location, source.place = nil, nil
  source.locations = (#placements > 0) and placements or nil
end

---A source type whose row states several ways to obtain the item yields one record each, kept together in rank order
---`cost` is one record or absent, never a list (2 currencies is modelled as two sources)
---@param itemOrLink string|integer
---@return LFCSourceRecord[] records one per source the row names, ranked best first
local function getSourceRecords(itemOrLink)
  local recipeArray, resolvedKey = findWithKey(itemOrLink)
  local sources = recipeArray and recipeArray.sources
  if nil == next(recipeArray) or not sources then
    return {}
  end
  -- The key find resolved: a blueprint link resolves to the crafted item's entry, and every data table below is keyed by that item
  local recipeKey = resolvedKey or getItemId(itemOrLink)

  if LFC.Internal.Generated then
    local records = LFC.Internal.Generated.Records(recipeKey)
    local present = {}
    for _, record in ipairs(records) do
      present[record.source.type] = true
    end
    for source in eachSource(sourceMask(sources)) do
      if not present[source] then
        records[#records + 1] = { source = { type = source } }
      end
    end
    table.sort(records, function(a, b)
      return (SOURCE_PRIORITY[a.source.type] or math.huge) < (SOURCE_PRIORITY[b.source.type] or math.huge)
    end)
    return records
  end

  local ranked = {}
  for s in eachSource(sources) do
    ranked[#ranked + 1] = s
  end
  table.sort(ranked, function(a, b)
    return (SOURCE_PRIORITY[a] or math.huge) < (SOURCE_PRIORITY[b] or math.huge)
  end)

  local records = {}
  for _, s in ipairs(ranked) do
    local rec = { source = { type = s } }
    local several
    -- same rule the source line follows: a row that names this source answers for it
    local row = recipeRow(recipeKey, recipeArray)
    if row and row.source == s then
      recipeSourceRecord(rec, row)
    else
      local model = SOURCE_MODEL[s]
      if type(model) == "function" then
        several = model(rec, recipeKey, recipeArray, s)
      elseif model == MISC or model == nil then
        -- an undeclared type is read like a misc
        several = miscRecord(rec, recipeKey, recipeArray, s)
      end
      -- UNMODELLED and FILTER have nothing to read: the type is the record
    end
    if type(several) == "table" then
      for _, one in ipairs(several) do
        normalisePlacements(one.source)
        records[#records + 1] = one
      end
    else
      normalisePlacements(rec.source)
      records[#records + 1] = rec
    end
  end
  return records
end
this.GetSourceRecords = getSourceRecords

---Extract a numeric price from baked string
---@param itemId integer
---@param version integer
---@param source integer source type constant
---@return integer? currency ESO currency constant
---@return integer? amount
local function getMiscItemPrice(itemId, version, source)
  local entry = findMiscRow(itemId, version, source)
  return extractPrice(entry, source)
end
this.GetMiscItemPrice = getMiscItemPrice

--[[_______________________
    |                     |
    | RUDIMENTARY RENDER  |
    |_____________________|]]
-- One renderer over the published records. It resolves the ids a record carries and joins them in a fixed order
-- no grammar forms, no prepositions, no colours, no truncation (use FC or custom renderers for that)

local SOURCE_LABEL = LFC.Internal.Constants.SourceLabels

---What a record says the item comes from
---@param source table
---@return string
local function whatOf(source)
  if source.type == src.IGNORED then
    return GetString(SI_FURC_SRC_IGNORED)
  end
  if source.vendor then
    return plain(resolveNpc(source.vendor))
  end
  if source.category then
    return plain(GetString(source.category))
  end
  local category = MISC_CATEGORY[source.type]
  if category then
    return plain(GetString(category))
  end
  return SOURCE_LABEL[source.type] or tostring(source.type)
end

---Where a record says the item is, every place it names
---@param source table
---@return string
local function whereOf(source)
  local places = {}
  for _, placement in ipairs(source.locations or {}) do
    if placement.location then
      places[#places + 1] = plain(resolveZone(placement.location))
    end
    if placement.place then
      places[#places + 1] = plain(resolvePlace(placement.place))
    end
  end
  if source.event then
    places[#places + 1] = plain(resolveEvent(source.event))
  end
  return table.concat(places, ", ")
end

---Everything else a record carries, each id resolved to a name
---@param record table
---@return string
local function detailsOf(record)
  local source = record.source
  local parts = {}
  if source.achievement then
    if type(source.achievement) == "string" then
      parts[#parts + 1] = source.achievement
    elseif source.achievement ~= 0 then
      parts[#parts + 1] = GetAchievementLink(source.achievement, LINK_STYLE_DEFAULT)
    end
  end
  if source.quest then
    parts[#parts + 1] = plain(GetQuestName(source.quest))
  end
  if source.collectible then
    parts[#parts + 1] = plain(GetCollectibleName(source.collectible))
  end
  if source.skillRank then
    parts[#parts + 1] = string.format("%s %d", plain(resolveSkillLine(source.skillLine)), source.skillRank)
  end
  if source.partOf then
    parts[#parts + 1] = getItemLink(source.partOf)
  end
  if source.container then
    parts[#parts + 1] = getItemLink(source.container)
  end
  if source.itemPack then
    parts[#parts + 1] = plain(GetString(source.itemPack))
  end
  for _, packId in ipairs(source.packs or {}) do
    parts[#parts + 1] = getItemLink(packId)
  end
  if source.bundle then
    parts[#parts + 1] = plain(GetString(source.bundle))
  end
  if source.crate then
    parts[#parts + 1] = plain(resolveCrate(source.crate))
  end
  -- an empty list means it comes furnished with a house, but we don't know which
  if source.houses and #source.houses == 0 then
    parts[#parts + 1] = plain(GetString(SI_FURC_SRC_MISCHOUSE))
  end
  for _, houseId in ipairs(source.houses or {}) do
    parts[#parts + 1] = plain(GetCollectibleName(houseId))
  end
  if source.leads then
    parts[#parts + 1] = plain(strLeads)
  end
  addQualifier(parts, source.npcClass, resolveNpcClass)
  addQualifier(parts, source.containerKind, resolveNote)
  addQualifier(parts, source.note, resolveNote)
  if source.rarity then
    parts[#parts + 1] = plain(GetString(source.rarity))
  end
  local lastSeen = record.lastSeen
  if lastSeen then
    parts[#parts + 1] = tostring(lastSeen)
  end
  return table.concat(parts, ", ")
end

---One record as a line: `<what>: <where> (<price>) - <details>`
---@param record LFCSourceRecord
---@return string
local function renderRecord(record)
  local text = whatOf(record.source)
  local where = whereOf(record.source)
  if where ~= "" then
    text = string.format("%s: %s", text, where)
  end
  local cost = record.cost
  if cost and cost.amount then
    text = string.format("%s (%s)", text, strPrice(cost.amount, cost.currency))
  end
  local details = detailsOf(record)
  if details ~= "" then
    text = string.format("%s - %s", text, details)
  end
  return text
end
this.RenderRecord = renderRecord

---A record that names nothing but its own type: a craftable says what it is made of instead
---@param record table
---@return boolean
local function isBare(record)
  if record.cost then
    return false
  end
  for key in pairs(record.source) do
    if key ~= "type" then
      return false
    end
  end
  return true
end

---One named source of an item as a line
---@param recipeKey string|integer item link or id
---@param recipeArray? FurCEntry looked up via Find if omitted
---@param source integer source type constant
---@param stripColor? boolean strip colour control chars
---@return string
local function describeSource(recipeKey, recipeArray, source, stripColor)
  local crafted = source == src.CRAFTING or source == src.WRIT_VENDOR
  for _, record in ipairs(getSourceRecords(recipeKey)) do
    -- a craftable's line names where its blueprint comes from
    if record.source.type == source and not (crafted and isBare(record)) then
      local text = renderRecord(record)
      return (stripColor and stripText(text)) or text
    end
  end
  if crafted then
    return makeMaterial(recipeKey, recipeArray or find(recipeKey), stripColor)
  end
  return emptyString
end
this.DescribeSource = describeSource

---Is it a recipe rather than the furnishing itself
---@param itemOrLink string|integer
---@return boolean
local function isBlueprintArgument(itemOrLink)
  local link = (tonumber(itemOrLink) == itemOrLink and getItemLink(itemOrLink)) or itemOrLink
  return type(link) == "string" and #link > 0 and IsItemLinkFurnitureRecipe(link)
end

---Single-string description for the item's primary origin (by ranking)
---@param recipeKey string|integer item link or id
---@param recipeArray? FurCEntry looked up via Find if omitted
---@param stripColor? boolean strip colour control chars
---@return string
local function getItemDescription(recipeKey, recipeArray, stripColor)
  local resolvedKey
  if nil == recipeArray then
    recipeArray, resolvedKey = findWithKey(recipeKey)
  elseif isBlueprintArgument(recipeKey) then
    resolvedKey = select(2, findWithKey(recipeKey))
  end
  if nil == next(recipeArray) then
    return ""
  end
  -- The key find resolved, so a blueprint argument still uses the crafted item id
  recipeKey = resolvedKey or getItemId(recipeKey)
  return describeSource(recipeKey, recipeArray, originOf(recipeArray), stripColor)
end
this.GetItemDescription = getItemDescription

---Every non-crafting source of an item, ranked, one line per source type
---@param recipeKey string|integer item link or id
---@param recipeArray? FurCEntry unused, the records are looked up by key
---@param stripColor? boolean strip colour control chars
---@return { source: FurCItemSource, text: string }[] ranked best-first, empty renders omitted
local function getRankedSources(recipeKey, recipeArray, stripColor)
  local lines, byType = {}, {}
  for _, record in ipairs(getSourceRecords(recipeKey)) do
    local sourceType = record.source.type
    if sourceType ~= src.CRAFTING then
      local text = renderRecord(record)
      if text ~= "" then
        text = (stripColor and stripText(text)) or text
        local line = byType[sourceType]
        if line then
          -- one source type, several ways to obtain it: one line
          line.text = string.format("%s + %s", line.text, text)
        else
          line = { source = sourceType, text = text }
          byType[sourceType] = line
          lines[#lines + 1] = line
        end
      end
    end
  end
  return lines
end
this.GetRankedSources = getRankedSources
