-- runtime DB build

local LFC = LibFurnitureCatalogue

local this = {}
LFC.Internal.Build = this

local db = LFC.Internal.DB
local src = LFC.Internal.Constants.ItemSources
local SOURCE_PRIORITY = LFC.Internal.Constants.SOURCE_PRIORITY
local apiEvents = LFC.Internal.Constants.ApiEvents
local lifecycle = LFC.Internal.Lifecycle
local state = lifecycle.State

local getItemId = LFC.Internal.Format.GetItemId
local getItemLink = LFC.Internal.Format.GetItemLink

--[[
  A row's `sources` is a bitmask: bit (source 1) is set when the row has that source.

  Bit positions come from ItemSources, numbered in declaration order. Inserting a source in the middle renumbers everything below it, so the mask is built per session.

  Lua 5.1 number holds an exact integer up to 2^53, so there is room to spare.
]]
local MAX_SOURCE = 0
for _, id in pairs(src) do
  if id > MAX_SOURCE then
    MAX_SOURCE = id
  end
end

local function bitFor(source)
  return 2 ^ (source - 1)
end

---@param mask integer|nil
---@param source integer
---@return boolean
local function hasSource(mask, source)
  if not mask or mask == 0 or not source then
    return false
  end
  local bit = bitFor(source)
  return mask % (bit + bit) >= bit
end
this.HasSource = hasSource

---@return integer mask unchanged when the source was already there
local function addSource(mask, source)
  mask = mask or 0
  if hasSource(mask, source) then
    return mask
  end
  return mask + bitFor(source)
end
this.AddSource = addSource

---@return integer mask unchanged when the source was not there
local function removeSource(mask, source)
  if not hasSource(mask, source) then
    return mask or 0
  end
  return mask - bitFor(source)
end
this.RemoveSource = removeSource

---Iterate a mask's sources, lowest id first
---@param mask integer|nil
---@return fun(): integer|nil
local function eachSource(mask)
  local source = 0
  return function()
    while source < MAX_SOURCE do
      source = source + 1
      if hasSource(mask, source) then
        return source
      end
    end
  end
end
this.EachSource = eachSource

---Mask -> the `[id] = true` set shape the API hands out
---@param mask integer|nil
---@return table<integer, boolean>
local function sourceSet(mask)
  local set = {}
  for source in eachSource(mask) do
    set[source] = true
  end
  return set
end
this.SourceSet = sourceSet

---Set -> mask. Takes a mask through unchanged, so a caller may pass either
---@param sources table<integer, boolean>|integer|nil
---@return integer
local function sourceMask(sources)
  if sources == nil then
    return 0
  end
  if type(sources) == "number" then
    return sources
  end
  local mask = 0
  for source, present in pairs(sources) do
    if present then
      mask = addSource(mask, source)
    end
  end
  return mask
end
this.SourceMask = sourceMask

--- Maps recipe id onto furnishing it crafts
--- Plain furnishings pass through unchanged
---@param recipeId integer
---@return integer? itemId to store under, nil to skip
---@return integer? blueprintId set only when recipeId was a resolved recipe
local function resolveRecipe(recipeId)
  local recipeLink = getItemLink(recipeId)
  if nil == recipeLink or not IsItemLinkFurnitureRecipe(recipeLink) then
    return recipeId, nil
  end
  -- game returns "" when recipe has no result
  local resultLink = GetItemLinkRecipeResultItemLink(recipeLink, LINK_STYLE_BRACKETS)
  if nil == resultLink or #resultLink == 0 then
    return nil, nil
  end
  local resultId = getItemId(resultLink)
  if nil == resultId or resultId == recipeId then
    return nil, nil
  end
  return resultId, recipeId
end
this.ResolveRecipe = resolveRecipe

---Furniture category and subcategory the game holds for an item
---@param itemId integer
---@return integer categoryId 0 when the game knows no furnishing for it
---@return integer subcategoryId
local function furnishingCategory(itemId)
  local itemLink = itemId and getItemLink(itemId)
  local dataId = itemLink and GetItemLinkFurnitureDataId(itemLink)
  if not dataId or dataId == 0 then
    return 0, 0
  end
  local categoryId, subcategoryId = GetFurnitureDataCategoryInfo(dataId)
  return categoryId or 0, subcategoryId or 0
end
this.FurnishingCategory = furnishingCategory

---@param sources integer a source mask
local function primarySource(sources)
  local best, bestRank
  for s in eachSource(sources) do
    local rank = SOURCE_PRIORITY[s] or math.huge
    if not bestRank or rank < bestRank or (rank == bestRank and s < best) then
      best, bestRank = s, rank
    end
  end
  return best
end
this.PrimarySource = primarySource

-- Metatable shared by every stored row
--
-- `pairs` does not see these fields, so a shallow copy of a row does not carry them
local rowMeta = {
  __index = function(row, key)
    if key == "furnCategory" then
      return (furnishingCategory(rawget(row, "id")))
    end
    if key == "furnSubcategory" then
      local _, subcategoryId = furnishingCategory(rawget(row, "id"))
      return subcategoryId
    end
    return nil
  end,
}
this.RowMeta = rowMeta

-- DB revision is a change counter and starts at 1,  writes outside a build bump straight away
local pendingChange = false

local function markDatabaseChanged()
  if lifecycle.current == state.BUILDING then
    pendingChange = true
  else
    LFC.Internal.DBRevision = LFC.Internal.DBRevision + 1
  end
end

local function flushDatabaseChange()
  if pendingChange then
    pendingChange = false
    LFC.Internal.DBRevision = LFC.Internal.DBRevision + 1
  end
end

-- Fields a row actually keeps. `origin` is an input here, not a field
-- Anything not named here can already be looked up by the game
local STORED_FIELDS = {
  version = true,
  blueprint = true,
}

local function crownOfferSource(offer, bucket)
  if offer.source ~= nil then
    assert(offer.source == src.CROWN or offer.source == src.EDITOR, "invalid Crown offer source")
    assert(
      not (offer.pack or offer.bundle or offer.crate or offer.houses or offer.note or offer.category),
      "purchase channel belongs on a direct Crown offer"
    )
    return offer.source
  end
  return offer.itemPrice ~= nil and bucket or src.CROWN
end
this.CrownOfferSource = crownOfferSource

-- partial update or full overwrite
local function addDatabaseEntry(recipeKey, partial)
  if not (recipeKey and partial and next(partial) ~= nil) then
    return
  end

  local stored = db[recipeKey]
  if stored == nil then
    stored = setmetatable({ id = recipeKey }, rowMeta)
    db[recipeKey] = stored
  end
  for k, v in pairs(partial) do
    if STORED_FIELDS[k] and v ~= nil then
      stored[k] = v -- last writer wins
    end
  end

  local sources = stored.sources or 0
  if partial.sources then
    -- a caller may hand over either shape
    for s in eachSource(sourceMask(partial.sources)) do
      sources = addSource(sources, s)
    end
  end
  if partial.origin ~= nil then
    sources = addSource(sources, partial.origin)
  end
  -- RUMOUR is fallback: datamined but unknown src
  -- Sometimes we have leftover rumour items in DB
  -- We should auto drop rumour category if a src exists
  if sources ~= bitFor(src.RUMOUR) then
    sources = removeSource(sources, src.RUMOUR)
  end
  if LFC.Internal.IgnoredItems[recipeKey] then
    sources = bitFor(src.IGNORED)
  end
  stored.sources = sources

  markDatabaseChanged()
end
this.Upsert = addDatabaseEntry

-- Wipes runtime DB in place
local function clear()
  for itemId in pairs(db) do
    db[itemId] = nil
  end
  markDatabaseChanged()
end
this.Clear = clear

local function log(method, ...)
  local ok, logger = pcall(LFC.Internal.GetLogger)
  if ok and logger and type(logger[method]) == "function" then
    pcall(logger[method], logger, ...)
  end
end

local function logDebug(...)
  log("Debug", ...)
end

local function logError(...)
  log("Error", ...)
end

local function setState(value, err)
  lifecycle.current = value
  lifecycle.error = err ~= nil and tostring(err) or nil
  LFC.Internal.DBReady = value == state.READY
end

local function publish(eventName, ...)
  local publisher = LFC.Internal.PublishEvent
  if publisher then
    publisher(eventName, ...)
  end
end

local function publishLifecycleSuccess(revision)
  local publishReady = LFC.Internal.PublishReady
  if publishReady then
    publishReady(revision)
  end
end

local function notify(callback)
  local wasNotifying = lifecycle.notifying
  lifecycle.notifying = true
  local ok, err = pcall(callback)
  lifecycle.notifying = wasNotifying
  if not ok then
    error(err, 0)
  end
end

local function parseFurnitureItem(itemLink, override) -- saves to DB, returns recipeArray
  if
    not (override or IsItemLinkPlaceableFurniture(itemLink) or GetItemLinkItemType(itemLink) == ITEMTYPE_FURNISHING)
  then
    return
  end

  local recipeKey = GetItemLinkItemId(itemLink)
  local recipeArray = db[recipeKey]
  if nil ~= recipeArray then
    return recipeArray, recipeKey
  end

  recipeArray = {}

  addDatabaseEntry(recipeKey, recipeArray)

  return recipeArray, recipeKey
end
this.ParseFurnitureItem = parseFurnitureItem

local function parseBlueprint(blueprintLink) -- saves to DB, returns recipeArray
  local itemLink = GetItemLinkRecipeResultItemLink(blueprintLink, LINK_STYLE_BRACKETS)
  local blueprintId = getItemId(blueprintLink)
  local recipeKey = getItemId(itemLink)
  if
    nil == recipeKey -- we don't have a key to access the database
    or nil == itemLink -- we don't have an item link to parse
    or nil == GetItemLinkName(itemLink) -- we didn't find an item result for our recipe
  then
    return
  end

  local stored = db[recipeKey]
  if stored ~= nil and stored.blueprint ~= nil and hasSource(stored.sources, src.CRAFTING) then
    -- Already carries everything a blueprint contributes (otherwise we would just wastefully rewrite the data while happily bumping revision and invalidating cache)
    return stored, recipeKey
  end

  addDatabaseEntry(recipeKey, { origin = src.CRAFTING, blueprint = blueprintId })
  return db[recipeKey], recipeKey
end
this.ParseBlueprint = parseBlueprint

local ver = LFC.Internal.Constants.Versioning

-- Compatibility: released LibPrice prices items through FurC.MiscItemSources[version][source]
--TODO: Drop this when the switch to api.GetSourceDetails is done
local legacyMirror = {}
local splitFiles = {}
local function addSplitFile(dataFile)
  if nil ~= dataFile then
    splitFiles[#splitFiles + 1] = dataFile
  end
end
addSplitFile(FurC.CrownStore)
addSplitFile(FurC.Justice)
addSplitFile(FurC.Fishing)

for _, splitData in ipairs(splitFiles) do
  for versionNumber, versionData in pairs(splitData) do
    local buckets = FurC.MiscItemSources[versionNumber]
    if nil == buckets then
      buckets = {}
      FurC.MiscItemSources[versionNumber] = buckets
    end
    for source, items in pairs(versionData) do
      local existing = buckets[source]
      local mirrored, covered = {}, true
      if nil ~= existing then
        logDebug("legacy mirror: merging split file into MiscItemSources[%s][%s]", versionNumber, source)
        for itemId, entry in pairs(existing) do
          mirrored[itemId] = entry
        end
        covered = {}
      end
      for itemId, entry in pairs(items) do
        mirrored[itemId] = entry
        if covered ~= true then
          covered[itemId] = true
        end
      end
      buckets[source] = mirrored
      legacyMirror[mirrored] = covered
    end
  end
end

---@param blocking? boolean scan inline instead of yielding through LibAsync
local function scanFromFiles(blocking)
  lifecycle.task = lifecycle.task or (LibAsync and LibAsync:Create("LibFurnitureCatalogue_ScanDataFiles"))
  local task = lifecycle.task

  -- Expects [zone][vendor][itemId]
  local function parseZoneData(zoneName, zoneData, versionNumber, origin)
    for vendorName, vendorData in pairs(zoneData) do
      for itemId, row in pairs(vendorData) do
        if type(itemId) ~= "number" then
          logDebug("parseZoneData: %s / %s holds non-numeric key %s", zoneName, vendorName, itemId)
        else
          local source = origin == src.VENDOR and type(row) == "table" and row.achievement and src.ACHIEVEMENT or origin
          addDatabaseEntry(itemId, { origin = source, version = versionNumber })
        end
      end
    end
  end

  local function scanRecipeFile()
    local recipeArray

    local function makeKeySet(versionData)
      local keySet = {}
      for k, v in pairs(versionData) do
        table.insert(keySet, k)
      end
      return keySet
    end

    local function scanArray(ary, versionNumber, origin)
      if nil == ary then
        return
      end

      for _, recipeId in ipairs(ary) do
        -- No blueprint means id is not a recipe this client can resolve (PTS vs Live, or invalid/datamine)
        local itemId, blueprintId = resolveRecipe(recipeId)
        if nil == blueprintId then
          logDebug("scanRecipeFile: %s is not a resolvable furniture recipe", recipeId)
        else
          local itemLink = getItemLink(itemId)
          recipeArray = parseFurnitureItem(itemLink) or db[itemId] or parseBlueprint(getItemLink(blueprintId))
          if nil == recipeArray then
            logDebug("scanRecipeFile: error for ID %s - %s", recipeId, itemLink)
          else
            addDatabaseEntry(itemId, { origin = origin, version = versionNumber, blueprint = blueprintId })
          end
        end
      end
    end

    for versionNumber, versionData in pairs(FurC.Recipes) do
      scanArray(versionData, versionNumber, src.CRAFTING)
    end

    for versionNumber, versionData in pairs(FurC.RolisRecipes) do
      scanArray(makeKeySet(versionData), versionNumber, src.CRAFTING)
    end

    for versionNumber, versionData in pairs(FurC.FaustinaRecipes) do
      scanArray(makeKeySet(versionData), versionNumber, src.CRAFTING)
    end
  end

  -- Rows that name their own source
  -- (writ vendor rows do not, because FurC.Rolis/FurC.Faustina already carry them)
  local function scanRecipeSources()
    for recipeId, row in pairs(FurC.RecipeSources) do
      if type(row) == "table" and nil ~= row.source then
        local itemId, blueprintId = resolveRecipe(recipeId)
        if nil == itemId then
          logDebug("scanRecipeSources: %s is not a resolvable furniture recipe", recipeId)
        else
          addDatabaseEntry(itemId, { origin = row.source, version = row.version, blueprint = blueprintId })
        end
      end
    end
  end

  local function scanRolis()
    -- Both tables mix furnishings with Master Writ recipes
    -- We resolve first, otherwise we get item+blueprint (duplicate)
    local function scanVendorTable(versionData, versionNumber)
      for id in pairs(versionData) do
        local itemId, blueprintId = resolveRecipe(id)
        if nil ~= itemId then
          addDatabaseEntry(itemId, { origin = src.ROLIS, version = versionNumber, blueprint = blueprintId })
        end
      end
    end

    for versionNumber, versionData in pairs(FurC.Rolis) do
      scanVendorTable(versionData, versionNumber)
    end
    for versionNumber, versionData in pairs(FurC.Faustina) do
      scanVendorTable(versionData, versionNumber)
    end
  end

  local function scanFestivalFiles()
    for versionNumber, versionData in pairs(FurC.EventItems) do
      for eventName, eventData in pairs(versionData) do
        for _, eventItemData in pairs(eventData) do
          for itemId in pairs(eventItemData) do
            addDatabaseEntry(itemId, { origin = src.FESTIVAL_DROP, version = versionNumber })
          end
        end
      end
    end
  end

  local function scanMiscItemFile()
    for versionNumber, versionData in pairs(FurC.MiscItemSources) do
      for origin, originData in pairs(versionData) do
        local covered = legacyMirror[originData]
        if covered ~= true then
          for itemId in pairs(originData) do
            if not (covered and covered[itemId]) then
              local itemLink = getItemLink(itemId)
              if IsItemLinkPlaceableFurniture(itemLink) or GetItemLinkItemType(itemLink) == ITEMTYPE_FURNISHING then
                addDatabaseEntry(itemId, { origin = origin, version = versionNumber })
              elseif origin == src.RUMOUR then
                logDebug("invalid rumour item: %s (%s)", itemId, itemLink)
              else
                logDebug("scanMiscItemFile: Error when scanning item ID %s (origin %s)", itemId, origin)
              end
            end
          end
        end
      end
    end
  end

  local function scanCrownStore()
    for versionNumber, versionData in pairs(FurC.CrownStore) do
      for origin, originData in pairs(versionData) do
        for itemId, row in pairs(originData) do
          local itemLink = getItemLink(itemId)
          if IsItemLinkPlaceableFurniture(itemLink) or GetItemLinkItemType(itemLink) == ITEMTYPE_FURNISHING then
            addDatabaseEntry(itemId, { origin = origin, version = versionNumber })
            local offers = row[1] ~= nil and row or { row }
            for _, offer in ipairs(offers) do
              addDatabaseEntry(itemId, { origin = crownOfferSource(offer, origin) })
            end
          else
            logDebug("scanCrownStore: Error when scanning item ID %s (origin %s)", itemId, origin)
          end
        end
      end
    end
  end

  local function scanAntiquities()
    for versionNumber, versionData in pairs(FurC.Antiquities) do
      for origin, originData in pairs(versionData) do
        for itemId in pairs(originData) do
          local itemLink = getItemLink(itemId)
          if IsItemLinkPlaceableFurniture(itemLink) or GetItemLinkItemType(itemLink) == ITEMTYPE_FURNISHING then
            addDatabaseEntry(itemId, { origin = origin, version = versionNumber })
          else
            logDebug("scanAntiquities: Error when scanning item ID %s (origin %s)", itemId, origin)
          end
        end
      end
    end
  end

  local function scanJustice()
    for versionNumber, versionData in pairs(FurC.Justice) do
      for origin, originData in pairs(versionData) do
        for itemId in pairs(originData) do
          local itemLink = getItemLink(itemId)
          if IsItemLinkPlaceableFurniture(itemLink) or GetItemLinkItemType(itemLink) == ITEMTYPE_FURNISHING then
            addDatabaseEntry(itemId, { origin = origin, version = versionNumber })
          else
            logDebug("scanJustice: Error when scanning item ID %s (origin %s)", itemId, origin)
          end
        end
      end
    end
  end

  local function scanFishing()
    for versionNumber, versionData in pairs(FurC.Fishing) do
      for origin, originData in pairs(versionData) do
        for itemId in pairs(originData) do
          local itemLink = getItemLink(itemId)
          if IsItemLinkPlaceableFurniture(itemLink) or GetItemLinkItemType(itemLink) == ITEMTYPE_FURNISHING then
            addDatabaseEntry(itemId, { origin = origin, version = versionNumber })
          else
            logDebug("scanFishing: Error when scanning item ID %s (origin %s)", itemId, origin)
          end
        end
      end
    end
  end

  local function scanVendorFiles()
    for versionNumber, versionData in pairs(FurC.HomeGoodsFurnisher or {}) do
      for zoneName, zoneData in pairs(versionData) do
        parseZoneData(zoneName, zoneData, versionNumber, src.HOME_GOODS)
      end
    end
    for versionNumber, versionData in pairs(FurC.AchievementVendors) do
      for zoneName, zoneData in pairs(versionData) do
        parseZoneData(zoneName, zoneData, versionNumber, src.VENDOR)
      end
    end

    for versionNumber, vendorData in pairs(FurC.LuxuryFurnisher) do
      for itemId in pairs(vendorData) do
        addDatabaseEntry(itemId, { origin = src.LUXURY, version = versionNumber })
      end
    end

    for versionNumber, versionData in pairs(FurC.PVP) do
      for zoneName, zoneData in pairs(versionData) do
        parseZoneData(zoneName, zoneData, versionNumber, src.PVP)
      end
    end
  end

  local function scanRumours()
    for versionNumber, items in pairs(FurC.Rumours) do
      for itemId in pairs(items) do
        addDatabaseEntry(itemId, { origin = src.RUMOUR, version = versionNumber })
      end
    end
    for _, blueprintId in pairs(FurC.RumourRecipes) do
      local blueprintLink = getItemLink(blueprintId)
      local itemLink = GetItemLinkRecipeResultItemLink(blueprintLink, LINK_STYLE_BRACKETS)
      if #itemLink == 0 then
        itemLink = blueprintLink
      end
      local itemId = getItemId(itemLink)
      -- derive craftingSkill from blueprint
      local existing = parseBlueprint(blueprintLink) or parseFurnitureItem(itemLink) or db[itemId]
      addDatabaseEntry(itemId, {
        origin = src.RUMOUR,
        version = (existing and existing.version) or ver.HOMESTEAD,
        blueprint = (blueprintId ~= itemId) and blueprintId or nil,
      })
    end
  end

  local buildStarted = GetGameTimeMilliseconds()
  local function finish()
    flushDatabaseChange()
    setState(state.READY)
    logDebug("DB build finished: %d entries in %d ms", NonContiguousCount(db), GetGameTimeMilliseconds() - buildStarted)
    notify(function()
      local revision = LFC.Internal.DBRevision
      publishLifecycleSuccess(revision)
      publish(apiEvents.SCAN_COMPLETE, revision)
    end)
  end

  local function fail(err)
    -- a failed build still leaves partial writes behind
    flushDatabaseChange()
    setState(state.FAILED, err)
    logError("DB build failed: %s", tostring(err))
    notify(function()
      publish(apiEvents.SCAN_FAILED, lifecycle.error)
    end)
  end

  local steps = {
    scanRecipeFile,
    scanRecipeSources,
    scanMiscItemFile,
    scanCrownStore,
    scanAntiquities,
    scanJustice,
    scanFishing,
    scanVendorFiles,
    scanRolis,
    scanFestivalFiles,
    scanRumours,
    function()
      for itemId in pairs(LFC.Internal.IgnoredItems) do
        addDatabaseEntry(itemId, { origin = src.IGNORED, version = LFC.Internal.Constants.Versioning.NONE })
      end
    end,
    finish,
  }

  if LFC.Internal.Generated then
    steps = { LFC.Internal.Generated.Install, finish }
  end

  setState(state.BUILDING)
  publish(apiEvents.SCAN_STARTED)

  if nil ~= task and not blocking then
    local chain = task:Call(steps[1])
    for i = 2, #steps do
      chain = chain:Then(steps[i])
    end
    chain:OnError(function(asyncTask)
      if lifecycle.current ~= state.READY then
        fail(asyncTask.Error)
      else
        logError("Post-build callback failed: %s", tostring(asyncTask.Error))
      end
    end)
  else
    local ok, err = pcall(function()
      for _, step in ipairs(steps) do
        step()
      end
    end)
    if not ok then
      if lifecycle.current ~= state.READY then
        fail(err)
      else
        logError("Post-build callback failed: %s", tostring(err))
      end
      error(err, 0)
    end
  end
end

---Starts the initial runtime DB build from bundled data files
---@param blocking? boolean build inline, so the DB is populated on return
local function ensureDB(blocking)
  if lifecycle.current ~= state.UNINITIALIZED then
    return
  end
  logDebug("Scanning data files")
  scanFromFiles(blocking)
end
this.EnsureDB = ensureDB

--- Applies bundled data files over current DB again
local function rescanFiles()
  if lifecycle.current == state.BUILDING or lifecycle.current == state.FAILED or lifecycle.notifying then
    return
  end
  logDebug("Scanning data files")
  scanFromFiles()
end
this.RescanFiles = rescanFiles

--- Wipes runtime DB and rebuilds it from bundled data
---@param blocking? boolean true=build immediately
local function rebuildDB(blocking)
  if lifecycle.current == state.BUILDING or lifecycle.notifying then
    return
  end
  clear()
  logDebug("Scanning data files")
  scanFromFiles(blocking)
end
this.RebuildDB = rebuildDB

-- Legacy aliases
FurC = FurC or {}
FurC.DBQuery = FurC.DBQuery or {}
FurC.DBQuery.ResolveRecipe = resolveRecipe
FurC.Upsert = addDatabaseEntry
FurC.EnsureDB = ensureDB
FurC.RescanFiles = rescanFiles
FurC.RebuildDB = rebuildDB
