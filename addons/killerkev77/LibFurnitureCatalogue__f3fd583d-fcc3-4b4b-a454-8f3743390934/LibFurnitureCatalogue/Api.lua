-- Public API: LibFurnitureCatalogue.API
--
-- Looking up furniture without writing an AddOn? Use slash commands:
--    `/lfc 203600` shows sources and materials
--    `/lfc raw 203600` shows more data
--    (you can also use item links instead of ids)
--
-- Using the library in an AddOn
-- Add `## DependsOn: LibFurnitureCatalogue` to your manifest, then in your Lua file:
--    local LFC = LibFurnitureCatalogue.API
--    LFC.OnReady(function()
--      d("Catalogue ready: " .. LFC.GetEntryCount() .. " furnishings")
--    end)
--
-- Every example below assumes you named your variable `LFC` too like in the example above. Run item queries after `IsReady()` returns true (or inside `OnReady`)
--
-- Choosing the answer you need
-- GetEntry describes a furnishing: its id, source types, update and recipe
-- GetSourceDetails describes each way to obtain it: vendor, place, cost, etc
-- A furnishing sold in several ways has several source records. A blueprint lookup resolves to the furnishing it makes
--
-- Reading the results
-- Optional fields can be nil (absent). Check for nil before using them.
-- A list uses numeric positions: `for _, value in ipairs(list) do ... end`
-- A set uses ids as keys: `entry.sources[src.PVP]` is true when that source exists
-- A map associates keys with values, for example ingredient link with a quantity
-- GetEntry and vocabulary lookups return editable copies
-- Treat source records, State and Events as read-only or you might break them accidentally (copy or use ZO_DeepTableCopy if you want to edit them)
--
-- Most fields contain ids rather than display text
-- The field comments below name the matching ESO function (for example, a vendor string id uses `zo_strformat("<<C:1>>", GetString(vendorId))` for a capitalised display name)
-- Compare source/update ids using GetSourceTypes/GetDataVersions. If you need to save them, use the string keys, because the numeric values can change
--
-- Waiting for data
-- OnReady starts loading if needed and calls your function once data is ready
-- IsReady only checks, it does not start loading
-- GetState distinguishes uninitialized, building, ready and failed
-- Loading can fail:
-- OnReady returns false if the library is already failed,  SCAN_FAILED reports a later failure
-- Queries made before we're ready may return empty or incomplete results. Recheck readiness during rebuilds.
--
-- Function overview
--
-- Readiness and changes
--   OnReady               run a function once the catalogue is ready
--   IsReady               check whether complete data is available now
--   GetState              get the loading state and any build error
--   State                 constants for comparing the result of GetState
--   RegisterCallback      run a function when a lifecycle event happens
--   UnregisterCallback    stop listening for an event
--   Events                event names for RegisterCallback
--   GetDBRevision         change counter for checking cached results
--   GetVersion            installed library's AddOnVersion
--
-- Find an item
--   Has                   check whether a lookup returns a catalogue entry
--   GetEntry              get one furnishing's entry, or nil
--   GetSourceDetails      get the ways to obtain it, in the library's preferred order
--   GetContainer          get a container kind and its known contents, or nil
--   GetIngredients        get ingredient links and quantities
--   GetItemId             convert a link to an item id
--   GetItemLink           build a link from an id (does not check whether the item exists)
--
-- Browse and interpret data
--   GetItemIds            list catalogue item ids
--   GetEntryCount         count catalogue entries
--   GetSourceTypes        source key -> numeric id, for comparisons
--   GetSourceTypeInfo     source id -> stable key and English description
--   GetDataVersions       game update key -> numeric id
--   GetDataVersionKeys    update id -> canonical key
--   GetFurnitureCategories  furnishing category id -> name
--
-- Older calls: supported for migration, avoid in new code
--   GetSources            old GetSourceDetails, cost is a list
--   GetItemDescription    basic source text, use GetSourceDetails for your own display
--   GetMiscItemPrice      old price lookup, use GetSourceDetails
--   FURC_* globals        old constants, use GetSourceTypes and GetDataVersions
--
-- Removed
--   SourceType            replaced by GetSourceTypes, which returns a copy
--
-- Old FurC calls: compatibility only
--   FurC.Find             returns `{}`, replace with GetEntry, which returns nil on a miss
--   FurC.GetItemDescription returns `""`, use GetSourceDetails to build a description
--   FurC.GetIngredients   returns `{}`, replace with GetIngredients
--   FurC.GetMats          returns `""`, use GetIngredients and format the quantities
--   FurC.GetItemId        forwards to GetItemId
--   FurC.GetItemLink      forwards to GetItemLink
--
-- LibFurnitureCatalogue.Internal is not public API
--
local LFC = LibFurnitureCatalogue
local api = LFC.API
local internal = LFC.Internal
local lifecycle = internal.Lifecycle
local state = lifecycle.State

local fmt, query = internal.Format, internal.Query
local getItemId, getItemLink = fmt.GetItemId, fmt.GetItemLink
local find, getSourceRecords = query.Find, query.GetSourceRecords
local getIngredients, getItemDescription = query.GetIngredients, query.GetItemDescription
local getMiscItemPrice = query.GetMiscItemPrice
local ensureDB = internal.Build.EnsureDB
local sourceSet = internal.Build.SourceSet

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

---The values GetState returns
---(shared: do not modify this table, other AddOns use it too)
---@type table<string, LFCDBState>
api.State = {
  UNINITIALIZED = state.UNINITIALIZED,
  BUILDING = state.BUILDING,
  READY = state.READY,
  FAILED = state.FAILED,
}

---Event names RegisterCallback takes
---(shared: do not modify this table, other AddOns use it too)
---Copied from Constants.lua, which declares it because of load order
---@type table<string, string>
api.Events = ZO_ShallowTableCopy(internal.Constants.ApiEvents)

-- Built from the internal table. An AddOn writing to the public copy must not be able to teach RegisterCallback a new event
local knownEvents = {}
for _, eventName in pairs(internal.Constants.ApiEvents) do
  knownEvents[eventName] = true
end

--  ================================================
-- // START: INTERNAL HELPERS, NOT PART OF THE API //
--  ================================================
--
-- The callback registry, plus the two publishers Build.lua fires when a build finishes or fails. In LFC.Internal, not in API table

local function logCallbackError(eventName, err)
  local ok, logger = pcall(internal.GetLogger)
  if ok then
    pcall(logger.Error, logger, "Public callback %s failed: %s", eventName, tostring(err))
  end
end

local function invokeCallback(eventName, callback, callbackArg, ...)
  local ok, err
  if callbackArg ~= nil then
    ok, err = pcall(callback, callbackArg, ...)
  else
    ok, err = pcall(callback, ...)
  end
  if not ok then
    logCallbackError(eventName, err)
  end
end

local function callbackRegistry(eventName)
  if not knownEvents[eventName] then
    return nil
  end
  local registry = lifecycle.callbacks[eventName]
  if not registry then
    registry = {}
    lifecycle.callbacks[eventName] = registry
  end
  return registry
end

local function findRegistration(registry, callback, arg)
  for index, registration in ipairs(registry) do
    if registration.callback == callback and registration.arg == arg then
      return index
    end
  end
end

---INTERNAL: Fire one public event
---@param eventName string
---@param ... any the event's payload, passed straight to each callback
function internal.PublishEvent(eventName, ...)
  local registry = lifecycle.callbacks[eventName]
  if not registry then
    return
  end
  -- Snapshot registrations so callbacks may safely unregister while firing
  local snapshot = {}
  for index, registration in ipairs(registry) do
    snapshot[index] = registration
  end
  for _, registration in ipairs(snapshot) do
    invokeCallback(eventName, registration.callback, registration.arg, ...)
  end
end

---Drain the one-shot OnReady queue. Persistent listeners get SCAN_COMPLETE, published by Build.lua right after this
---@param revision integer
function internal.PublishReady(revision)
  local waiters = lifecycle.readyWaiters
  lifecycle.readyWaiters = {}
  for callback, queued in pairs(waiters) do
    local arg
    if type(queued) == "table" then
      arg = queued.arg
    end
    invokeCallback("OnReady", callback, arg, revision)
  end
end

--  ==============================================
-- // END: INTERNAL HELPERS, NOT PART OF THE API //
--  ==============================================

---Run a function whenever a catalogue lifecycle event occurs
---
---SCAN_STARTED passes no arguments
---SCAN_COMPLETE passes the new revision
---SCAN_FAILED passes an error string
---

--- Registering does not start a build, use OnReady for the initial result.
---Registering the same function and optional arg again does not add a duplicate
---@param eventName string one of API.Events
---@param callback function called when the event occurs
---@param arg? any when supplied, passed before the event arguments
---@return boolean registered false for an unknown event or a non-function callback
---```lua
---local function showCount()
---  d("Catalogue: " .. LFC.GetEntryCount() .. " items")
---end
---LFC.RegisterCallback(LFC.Events.SCAN_COMPLETE, showCount)
---LFC.RegisterCallback(LFC.Events.SCAN_FAILED, function(message)
---  d("Catalogue could not load: " .. tostring(message))
---end)
---LFC.OnReady(showCount)
---```
---If OnReady starts a build, showCount may run for both initial readiness and SCAN_COMPLETE. A display refresh can safely run twice, avoid duplicate writes
function api.RegisterCallback(eventName, callback, arg)
  local registry = callbackRegistry(eventName)
  if not registry or type(callback) ~= "function" then
    return false
  end
  if not findRegistration(registry, callback, arg) then
    registry[#registry + 1] = { callback = callback, arg = arg }
  end
  return true
end

---Stop running a previously registered event handler.
---Pass the same function and optional arg used with RegisterCallback
---@param eventName string one of API.Events
---@param callback function the original function
---@param arg? any optional argument used during registration
---@return boolean removed false if no matching registration exists
---```lua
---local function showCount() d(LFC.GetEntryCount()) end
---LFC.RegisterCallback(LFC.Events.SCAN_COMPLETE, showCount)
---LFC.UnregisterCallback(LFC.Events.SCAN_COMPLETE, showCount) -- true
---LFC.UnregisterCallback(LFC.Events.SCAN_COMPLETE, showCount) -- false: already removed
---```
function api.UnregisterCallback(eventName, callback, arg)
  local registry = callbackRegistry(eventName)
  if not registry or type(callback) ~= "function" then
    return false
  end
  local index = findRegistration(registry, callback, arg)
  if not index then
    return false
  end
  table.remove(registry, index)
  return true
end

---Run a function once the catalogue is ready to query.
---Runs immediately if ready. Otherwise starts loading if necessary and queues the function. It does not run again after a later rebuild (use RegisterCallback for that).
--- While waiting, registering the same function again replaces its arg
---@param callback fun(revision: integer)
---@param arg? any when supplied, callback receives (arg, revision)
---@return boolean accepted false for a non-function callback or an already failed build (true just tells the call was accepted)
---```lua
---local accepted = LFC.OnReady(function()
---  d("Catalogue ready: " .. LFC.GetEntryCount() .. " items")
---end)
---if not accepted then
---  local status, message = LFC.GetState()
---  d("Catalogue: " .. status .. " " .. tostring(message or ""))
---end
---```
---Subscribe to SCAN_FAILED if you also need to report a failure after this call
function api.OnReady(callback, arg)
  if type(callback) ~= "function" then
    return false
  end
  if api.IsReady() then
    invokeCallback("OnReady", callback, arg, internal.DBRevision)
    return true
  end

  if lifecycle.current == state.FAILED then
    return false
  end
  -- Registering same function twice queues it once (the arg of the most recent registration wins)
  lifecycle.readyWaiters[callback] = arg == nil and true or { arg = arg }
  if lifecycle.current == state.UNINITIALIZED then
    ensureDB()
  end
  return true
end

---Is a complete catalogue available right now?
---This only checks readiness (use OnReady to start loading and wait for it)
---@return boolean ready true while a complete DB snapshot is available
---```lua
---LFC.IsReady() --> true
---```
function api.IsReady()
  return lifecycle.current == state.READY
end

---Current DB lifecycle state and the most recent build error, if any
---@return LFCDBState state
---@return string? error
---```lua
---local state, err = LFC.GetState()
---
---if state == LFC.State.FAILED then
---  d("Catalogue could not load: " .. tostring(err))
---end
---```
function api.GetState()
  return lifecycle.current, lifecycle.error
end

---A number that changes when the catalogue changes (used for cache invalidation).
---Just compare for equality, the size of the difference has no meaning.
---Use this when reusing cached query results (rebuilds and newly resolved recipes can change it)
---@return integer revision
---```lua
---local cachedRevision = LFC.GetDBRevision()
----- Later, before reusing a cached result:
---if cachedRevision ~= LFC.GetDBRevision() then
---  d("Catalogue changed, query again")
---end
---```
function api.GetDBRevision()
  return internal.DBRevision
end

---This library's AddOnVersion
---For a game update version see GetDataVersions, for a DB revision see GetDBRevision
---@return integer libVersion the manifest's AddOnVersion
---```lua
---d("Library AddOnVersion: " .. LFC.GetVersion())
---```
function api.GetVersion()
  return LFC.version
end

-- ---------------------------------------------------------------------------
-- Item identity
-- ---------------------------------------------------------------------------

---Resolve an item link or numeric id to a numeric item id.
---The function does not check whether an item exists
---@param itemOrLink string|integer
---@return integer? id nil on empty/invalid
---```lua
---LFC.GetItemId("|H1:item:134686:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h") --> 134686
---LFC.GetItemId(134686) --> 134686
---LFC.GetItemId(5000)   --> nil, below the threshold
---```
function api.GetItemId(itemOrLink)
  return getItemId(itemOrLink)
end

---Build an item link from a positive id, or return an existing valid item link.
---A generated link does not prove the item exists or belongs in the catalogue
---@param itemOrLink string|integer
---@return string link empty string on invalid
---```lua
---LFC.GetItemLink(134686) --> "|H1:item:134686:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
---LFC.GetItemId(LFC.GetItemLink(5000)) --> 5000, though LFC.GetItemId(5000) is nil
---```
function api.GetItemLink(itemOrLink)
  return getItemLink(itemOrLink)
end

-- ---------------------------------------------------------------------------
-- One item
-- ---------------------------------------------------------------------------

---Does this lookup return a catalogue entry?
---Wait for readiness before treating false as a missing entry.
---Resolving a new blueprint can create a runtime entry, so true does not prove it was in the DB from the start.
---@param itemOrLink string|integer
---@return boolean found
---```lua
---LFC.Has(203600)   --> true
---LFC.Has(99123456) --> false
---```
function api.Has(itemOrLink)
  return next(find(itemOrLink)) ~= nil
end

---One furnishing entry, returned as a copy
---@param itemOrLink string|integer item link, blueprint link, or itemId
---@return FurCEntry? entry deep copy, nil when the item is not in the DB
---@see LibFurnitureCatalogue.API.GetSourceDetails for vendors, prices and locations
---
---`id` identifies the furnishing, including when you pass its blueprint.
---`sources` is a set of source ids.
---`version` is an update id when known.
---`blueprint` is a recipe item id when known by the DB.
---These are the supported fields, other implementation fields may change.
---```lua
---local src = LFC.GetSourceTypes()
---local entry = LFC.GetEntry(203600)
---if entry then
---  if entry.sources[src.PVP] then d("Has a PvP source") end
---  if entry.version then
---    d("Catalogue update: " .. tostring(LFC.GetDataVersionKeys()[entry.version]))
---  end
---  if entry.blueprint then d("Recipe item ID: " .. entry.blueprint) end
---else
---  d("No catalogue entry found")
---end
---```
function api.GetEntry(itemOrLink)
  local entry = find(itemOrLink)
  if nil == next(entry) then
    return nil
  end
  local copy = ZO_DeepTableCopy(entry)
  -- The row holds `sources` as a bitmask to keep ~8500 subtables out of the database
  copy.sources = sourceSet(entry.sources)
  return copy
end

---One place a source covers: a game zone, somewhere the game has no zone for, or a place inside a zone
---@class LFCPlacement
---@field location integer|nil game zone id, resolve with GetZoneNameById
---@field place integer|nil locale string id, resolve with GetString then zo_strformat
---@field note string|nil additional directions within the placement

---Where one source of an item comes from
---
---Optional fields describe this particular source, not every way to get the item.
---houses, packs and locations are always lists (even when they contain only one value)
---
---Id `0` means "has a requirement, but we cannot name it" (`achievement`, `crate` and `quest`)
---@class LFCSourceOrigin
---@field type integer source type, see GetSourceTypes
---@field vendor integer|nil locale string id, resolve with GetString
---@field locations LFCPlacement[]|nil places this source covers, best-known first
---@field note (integer|string|table)|nil adds details to a source. Locale string id, a bare literal, structured table, or a list of alternatives
---@field category integer|nil locale string id describing this source, resolve with GetString
---@field achievement integer|nil achievement id. `0` when it requires an achievement but the id is unknown
---@field quest integer|nil quest id, resolve with GetQuestName. `0` when a quest is required but the id is unknown
---@field skillLine integer|nil skill line id, resolve with GetSkillLineNameById (on a vendor source, identifies its skill-line requirement)
---@field skillRank integer|nil required rank in that skill line, when recorded
---@field event integer|nil locale string id, resolve with GetString
---@field crate integer|nil crown crate id, resolve with GetCrownCrateName. `0` when it's a crate but the id is unknown and we have no name
---@field packs integer[]|nil item ids of the furnishing packs it is part of
---@field bundle integer|nil locale string id of a Crown Store bundle that does not have an item id, resolve with GetString
---@field itemPack integer|nil locale string id of a Tamriel Tomes item pack, resolve with GetString
---@field houses integer[]|nil collectible ids of the houses it comes furnished with, resolve with GetCollectibleName
---@field collectible integer|nil collectible id the furnishing comes with (resolve with `GetCollectibleName`)
---@field partOf integer|nil item id of the container, folio or collection the item is bought as part of
---@field container integer|nil item id of the container it is found in
---@field containerKind (integer|integer[])|nil locale string id(s) naming a kind of container, resolve with GetString
---@field npcClass (integer|integer[])|nil monster social class string id(s), the game's own, resolve with GetString
---@field leads true|nil the antiquity is assembled from several leads; the player's codex has the count
---@field rarity integer|nil locale string id naming how rare the source is, resolve with GetString

---One recorded price. Each source record has at most one currency/amount pair (separate price options are represented by separate source records)
---@class LFCSourceCost
---@field currency integer ESO currency constant
---@field amount integer

---One source of one item: where it comes from, what it costs, when it was last seen
---
---Example shape: one writ-vendor offer for the Scribing Altar (203600).
---Read current values with GetSourceDetails:
---```lua
---local exampleRecord = { source = {
---    type = LFC.GetSourceTypes().ROLIS,
---    vendor = SI_FURC_TRADERS_FAUSTINA, -- "Faustina Curio"
---    achievement = 3985, -- "Inheritor of the Scholarium"
---    locations = { {place = SI_FURC_LOC_ANY_CAPITAL} } -- "any capital city", no zoneId names it
---  },
---  cost = { currency = CURT_WRIT_VOUCHERS, amount = 800 }
---}
---```
---@class LFCSourceRecord
---@field source LFCSourceOrigin
---@field cost LFCSourceCost|nil recorded price (nil means no price is provided, not that it's free)
---@field lastSeen string|nil YYYY-MM-DD, luxury furnisher records only

---The recorded ways to obtain an item, in the library's preferred order.
---Treat these as read-only (some nested lists/notes share library data).
---Use ZO_DeepTableCopy(record) if you need to edit it for your AddOn.
---Each record describes one source or offer. The order is just preference, not a ranking.
---Check optional fields before resolving their ids with ESO functions.
---A placement with both location and place describes a place inside that zone.
---@param itemOrLink string|integer item link, blueprint link, or itemId
---@return LFCSourceRecord[] records empty when no sources are available
---```lua
---for _, record in ipairs(LFC.GetSourceDetails(203600)) do
---  local source = record.source
---  if source.vendor then
---    d(zo_strformat("<<C:1>>", GetString(source.vendor)))
---  end
---  for _, placement in ipairs(source.locations or {}) do
---    if placement.location then
---      d(zo_strformat("<<C:1>>", GetZoneNameById(placement.location)))
---    end
---    if placement.place then
---      d(zo_strformat("<<C:1>>", GetString(placement.place)))
---    end
---  end
---  if record.cost then
---    d(record.cost.amount .. " " .. GetCurrencyName(record.cost.currency, false, false))
---  end
---end
---```
---If you only need to test a source type, GetEntry().sources is the smaller answer.
function api.GetSourceDetails(itemOrLink)
  return getSourceRecords(itemOrLink)
end

---@class LFCContainer
---@field kind string "books" or "folio"
---@field contents integer[] item ids, including blueprint ids for folios; sorted and returned as a copy

---Known contents of a container. Read its price and vendor with GetSourceDetails. A content record names its parent in source.partOf
---@param itemOrLink integer|string container id or link
---@return LFCContainer|nil container nil when no contents are recorded
---```lua
---local collection = LFC.GetContainer(145596)
---if collection then
---  for _, id in ipairs(collection.contents) do d(LFC.GetItemLink(id)) end
---end
---```
function api.GetContainer(itemOrLink)
  ensureDB()
  local id = getItemId(itemOrLink)
  return id and internal.Generated and internal.Generated.Container(id) or nil
end

---Ingredient links and required quantities for a craftable furnishing.
---Quantities come from recipe data. Without an entry argument, this first looks up the item in the catalogue, so follow the normal readiness rules. With an entry argument, it reads that entry's recipe directly.
---@param itemOrLink string|integer furnishing or blueprint link/id, ignored when recipeArray is supplied
---@param recipeArray? FurCEntry entry from GetEntry, looked up when omitted
---@return table<string, integer> ingredients ingredient link -> quantity, empty if no ingredients can be resolved
---```lua
---local materials = LFC.GetIngredients(118991) -- recipe: High Elf Stool, Curved
---for ingredientLink, quantity in pairs(materials) do
---  d(quantity .. "x " .. zo_strformat("<<C:1>>", GetItemLinkName(ingredientLink)))
---end
---if next(materials) == nil then d("No crafting ingredients found") end
---```
function api.GetIngredients(itemOrLink, recipeArray)
  return getIngredients(itemOrLink, recipeArray)
end

-- ---------------------------------------------------------------------------
-- The whole DB
-- ---------------------------------------------------------------------------

---Snapshot of every item id in the DB
---No guaranteed order. Sort the returned list when you need a predictable order.
---
---Starts loading if needed, but does not wait. Results may be incomplete until ready.
---@return integer[] itemIds
---```lua
---local ids = LFC.GetItemIds()
---table.sort(ids)
---for _, id in ipairs(ids) do d(id) end
---```
function api.GetItemIds()
  ensureDB()
  local ids = {}
  for id in pairs(internal.DB) do
    -- malformed data files can leave string keys behind, we need numeric
    if type(id) == "number" then
      ids[#ids + 1] = id
    end
  end
  return ids
end

local countRevision, countMemo
---How many items are in the DB, without building the id list
---
---Starts loading if needed, but does not wait. Check IsReady before displaying the count.
---@return integer count
---```lua
---if LFC.IsReady() then d(LFC.GetEntryCount() .. " catalogue entries") end
---```
function api.GetEntryCount()
  ensureDB()
  if countRevision ~= internal.DBRevision then
    countRevision = internal.DBRevision
    local count = 0
    for id in pairs(internal.DB) do
      -- keep in step with GetItemIds: only numeric keys are real entries
      if type(id) == "number" then
        count = count + 1
      end
    end
    countMemo = count
  end
  return countMemo
end

-- ---------------------------------------------------------------------------
-- Vocabularies
--
-- Two forward/reverse pairs, plus the category tree.
-- Use these constants and never the raw number values (the values can change)
-- ---------------------------------------------------------------------------

---Source names mapped to their numeric ids.
---Includes filtering constants as well as source types. GetSourceDetails tells you which source types actually apply to an item.
---@return table<string, integer> sourceTypes
---```lua
---local src = LFC.GetSourceTypes()
---
---local crownSourceId = src.CROWN
---local dropSourceId = src.DROP
----- Compare against these values, do not hardcode their current numbers
---```
function api.GetSourceTypes()
  return ZO_ShallowTableCopy(internal.Constants.ItemSources)
end

---Source ids mapped to stable keys and English descriptions.
---Useful for exports, logs and interpreting GetEntry().sources. Includes the same filtering constants as GetSourceTypes (labels are always English, they are not UI strings)
---@return table<integer, { key: string, label: string }> sourceTypeInfo
---```lua
---local info = LFC.GetSourceTypeInfo()
---local luxury = info[LFC.GetSourceTypes().LUXURY]
---d(luxury.key)   -- "LUXURY": suitable for a saved setting
---d(luxury.label) -- "Luxury Furnisher": English description
---```
function api.GetSourceTypeInfo()
  local constants = internal.Constants
  local labels = constants.SourceLabels
  local info = {}
  for value, key in pairs(constants.SourceNames) do
    info[value] = { key = key, label = labels[value] or key }
  end
  return info
end

---Game update names mapped to the numeric ids used in entry.version
---@return table<string, integer> versions
---```lua
---local ver = LFC.GetDataVersions()
---
---local homesteadId = ver.HOMESTEAD
---local latestId = ver.LATEST -- latest update known to this installed data set
---```
function api.GetDataVersions()
  return ZO_ShallowTableCopy(internal.Constants.Versioning)
end

---Update ids mapped to their names.
---LATEST is an alias for a particular update and changes. This lookup returns the update's own name
---@return table<integer, string> versionKeys
---```lua
---local versions, keys = LFC.GetDataVersions(), LFC.GetDataVersionKeys()
---d(keys[versions.ALTMER]) -- "ALTMER"
---d(keys[versions.LATEST]) -- current update key, never "LATEST"
---```
function api.GetDataVersionKeys()
  return ZO_ShallowTableCopy(internal.Constants.VersionNames)
end

local categoryMemo
---The game's furnishing categories and subcategories, keyed by category id.
---Names use the client's language.
---parent is 0 for top-level categories, otherwise it identifies the containing category.
---order is the game's display order
---
--- The returned table is copied, the underlying names are cached per session.
---This lists categories, not the items in each one. Use the ESO API to find an item's category, as below. A furniture data id of 0 means no furnishing data.
---@return table<integer, { name: string, parent: integer, order: integer }> categories
---```lua
---local categories = LFC.GetFurnitureCategories()
---local dataId = GetItemLinkFurnitureDataId(LFC.GetItemLink(134686))
---if dataId ~= 0 then
---  local categoryId, subcategoryId = GetFurnitureDataCategoryInfo(dataId)
---  for _, id in ipairs({categoryId, subcategoryId}) do
---    local category = categories[id]
---    if category then d(zo_strformat("<<C:1>>", category.name)) end
---  end
---end
---```
function api.GetFurnitureCategories()
  if not categoryMemo then
    local built = {}
    local function add(id, fallbackParent)
      if id and id ~= 0 and not built[id] then
        local name, parent, _, order = GetFurnitureCategoryInfo(id)
        built[id] = { name = name or "", parent = parent or fallbackParent or 0, order = order or 0 }
      end
    end
    for categoryIndex = 1, GetNumFurnitureCategories() do
      local categoryId = GetFurnitureCategoryId(categoryIndex)
      add(categoryId, 0)
      for subcategoryIndex = 1, GetNumFurnitureSubcategories(categoryIndex) do
        add(GetFurnitureSubcategoryId(categoryIndex, subcategoryIndex), categoryId)
      end
    end
    categoryMemo = built
  end

  local copy = {}
  for id, category in pairs(categoryMemo) do
    copy[id] = { name = category.name, parent = category.parent, order = category.order }
  end
  return copy
end

-- ---------------------------------------------------------------------------
-- Deprecated and Bridge helpers
--
-- These exist so AddOns can migrate off old endpoints
-- Each entry names what to use instead
-- We'll call the guards if you keep using those for too long
-- ---------------------------------------------------------------------------

---Basic description of an item's preferred source.
---Just for legacy callers. Use GetSourceDetails when building a new display.
---@deprecated Use GetSourceDetails and render the records yourself
---@param recipeKey string|integer item link or id
---@param recipeArray? FurCEntry looked up via GetEntry when omitted
---@param stripColor? boolean strip colour control characters
---@param opts? { dateFormat?: string } ignored
---@return string description localised, empty when the item is not in the DB
---```lua
---d(LFC.GetItemDescription(223880, LFC.GetEntry(223880), true))
---```
function api.GetItemDescription(recipeKey, recipeArray, stripColor, opts)
  return getItemDescription(recipeKey, recipeArray, stripColor)
end

---Temporary compatibility bridge for prices hidden in baked strings.
---Just for legacy callers. New code should read record.cost from GetSourceDetails.
---@deprecated Use GetSourceDetails, which gives a stable price per source
---@param itemId integer
---@param version integer
---@param source integer source type constant, see GetSourceTypes
---@return integer? currency ESO currency constant
---@return integer? amount
---```lua
---local entry = LFC.GetEntry(134686)
---if entry and entry.version then
---  local currency, amount = LFC.GetMiscItemPrice(entry.id, entry.version, LFC.GetSourceTypes().CROWN)
---  if currency and amount then
---    d(amount .. " " .. GetCurrencyName(currency, false, false))
---  end
---end
---```
function api.GetMiscItemPrice(itemId, version, source)
  return getMiscItemPrice(itemId, version, source)
end

---Old name and record shape of GetSourceDetails
---@deprecated Use GetSourceDetails: its cost is one table or nil. This older call uses cost[1], or an empty cost list.
---@param itemOrLink string|integer
---@return LFCSourceRecord[] records
function api.GetSources(itemOrLink)
  local records = getSourceRecords(itemOrLink)
  for _, record in ipairs(records) do
    record.cost = (record.cost and { record.cost }) or {}
  end
  return records
end

-- Any deprecated enum globals are in Constants.lua, all marked

-- ---------------------------------------------------------------------------
-- Legacy FurC entry points
-- So the names stay callable and answer the miss value of their old contract. No data comes back through FurC any more, migrate to the API above for that!
---------------------------------------------------------------------------

FurC = FurC or {}

local legacyNoted = {}
local function noteLegacyCall(name, replacement)
  if legacyNoted[name] then
    return
  end
  legacyNoted[name] = true
  internal.GetLogger():Warn("FurC.%s no longer answers, use LibFurnitureCatalogue.API.%s", name, replacement)
end

---@deprecated Use GetEntry
---@return table entry always empty
function FurC.Find()
  noteLegacyCall("Find", "GetEntry")
  return {}
end

---@deprecated Use GetItemDescription
---@return string description always empty
function FurC.GetItemDescription()
  noteLegacyCall("GetItemDescription", "GetItemDescription")
  return ""
end

---@deprecated Use GetIngredients
---@return table ingredients always empty
function FurC.GetIngredients()
  noteLegacyCall("GetIngredients", "GetIngredients")
  return {}
end

---@deprecated Use GetIngredients, and format the map yourself
---@return string mats always empty
function FurC.GetMats()
  noteLegacyCall("GetMats", "GetIngredients")
  return ""
end

-- no DB behind these two
---@deprecated Use LibFurnitureCatalogue.API.GetItemId
FurC.GetItemId = api.GetItemId

---@deprecated Use LibFurnitureCatalogue.API.GetItemLink
FurC.GetItemLink = api.GetItemLink
