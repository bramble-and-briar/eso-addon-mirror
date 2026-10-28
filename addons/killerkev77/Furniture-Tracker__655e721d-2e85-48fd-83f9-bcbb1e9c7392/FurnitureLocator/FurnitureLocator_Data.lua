--[[
Furniture Locator - Data Layer

Builds a full list of every furniture item you own, account-wide, with
name, icon, and current location(s) -- for a browsable UI to read from.

CONFIRMED patterns, ported directly from Furniture Finder's
FurnitureFinder_Ownership.lua (already live/working in that addon):
  - Bag/bank/vault scanning via direct slot iteration + IsItemPlaceableFurniture
  - Placed-in-house scanning via GetNextPlacedHousingFurnitureId, seeded
    with nil (NOT 0) and exiting on nil (NOT 0) -- this was the actual bug
    in the earlier standalone test, not a timing/editor-mode issue.
  - GetPlacedFurnitureLink(furnitureId, LINK_STYLE_BRACKETS) for the link,
    NOT GetPlacedHousingFurnitureItemLink (not a real function -- earlier
    test bug).

NOT YET CONFIRMED -- new territory for this addon, Furniture Finder never
needed it since it only augments the game's own tooltip:
  - Item name/icon resolution (GetItemLinkName / GetItemLinkIcon below).
    Wrapped in pcall so a wrong function name/signature shows up as a
    clear error in /flist output rather than a silent failure or a hard
    crash on load.
]]

--[[
v12 (2026-10-20, API 101051):
  - FIX: "Bags" used to be a single account-wide table holding only the
    logged-in character's backpack, so every character you logged into
    overwrote it. Backpacks are now stored per character (bagsByChar) and
    shown as "Bags (Character Name)".
  - FIX: the bank scan now includes the ESO Plus half of the bank
    (BAG_SUBSCRIBER_BANK), not just BAG_BANK.
  - NEW: house storage chests/coffers (BAG_HOUSE_BANK_ONE..TEN) are scanned
    when you open one, named by the storage collectible's nickname/name.
  - Bank, vault and house storage also refresh as items move in/out
    (debounced), not only when the bank window opens/closes.
  - The old "bags" table is left in SavedVars untouched but no longer read.
v13 (2026-10-27): each location carries a stable key ("house:<id>", "vault",
  "bank", "storage:<bagId>", "bags:<characterId>") so lists can be filtered by
  location, GetLocationGroups() feeds "Browse by location", and lastList
  remembers the last list for "Continue".
]]

FurnitureLocator = {}
local this = FurnitureLocator
this.name = "FurnitureLocator" -- unique key for EVENT_MANAGER registrations

-- Must match the manifest's package name exactly (see the note in
-- FurnitureFinder_Ownership.lua about EVENT_ADD_ON_LOADED firing per
-- ADDON, not per file -- same rule applies here).
local ADDON_PACKAGE_NAME = "FurnitureLocator"

-- Caps how many CATEGORY ERROR lines get printed in one session -- if the
-- function names turn out to be wrong, every item would otherwise print
-- one, and a 600-item house already proved that floods/crashes the UI.
local categoryErrorsPrinted = 0
local MAX_CATEGORY_ERRORS_PRINTED = 3

local function PrintCategoryErrorOnce(message)
  if categoryErrorsPrinted < MAX_CATEGORY_ERRORS_PRINTED then
    categoryErrorsPrinted = categoryErrorsPrinted + 1
    d(message)
    if categoryErrorsPrinted == MAX_CATEGORY_ERRORS_PRINTED then
      d("(suppressing further CATEGORY ERROR lines this session)")
    end
  end
end

function this.Initialize()
  this.settings = ZO_SavedVars:NewAccountWide("FurnitureLocatorData", 3, nil, {
    bags = {},     -- LEGACY (pre-v12), no longer read
    bagsByChar = {}, -- [characterId] = { name = "...", items = { [itemId] = count } }
    houseBanks = {}, -- [bagId] = { name = "...", items = { [itemId] = count } }
    bank = {},     -- [itemId] = count (shared account bank, incl. ESO Plus half)
    vault = {},    -- [itemId] = count (account-wide furnishing vault)
    houses = {},   -- [houseId] = { name = "...", items = { [itemId] = count }, lastScanned = timestamp }
    itemInfo = {}, -- [itemId] = { name = "...", icon = "..." }
    lastList = nil, -- v13: the last list opened, for "Continue"
  })

  EVENT_MANAGER:RegisterForEvent(this.name, EVENT_OPEN_BANK, this.OnOpenBank)
  EVENT_MANAGER:RegisterForEvent(this.name, EVENT_CLOSE_BANK, this.ScanBankAndVault)
  EVENT_MANAGER:RegisterForEvent(this.name, EVENT_PLAYER_ACTIVATED, this.ScanCurrentHouseIfOwner)
  EVENT_MANAGER:RegisterForEvent(this.name, EVENT_HOUSING_FURNITURE_PLACED, this.ScanCurrentHouseIfOwner)
  EVENT_MANAGER:RegisterForEvent(this.name, EVENT_HOUSING_FURNITURE_REMOVED, this.ScanCurrentHouseIfOwner)
  EVENT_MANAGER:RegisterForEvent(this.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, this.OnInventoryUpdate)

  -- catch items already in the backpack when the addon loads mid-session
  this.ScanBackpack()
end

-- Many slot updates can fire at once (e.g. a big bank deposit), so each
-- rescan is debounced: one scan per bag group, 300ms after the last change.
local pendingScans = {}
local function ScheduleScan(key, fn)
  if pendingScans[key] then
    return
  end
  pendingScans[key] = true
  zo_callLater(function()
    pendingScans[key] = nil
    fn()
  end, 300)
end

function this.OnInventoryUpdate(_, bagId)
  if bagId == BAG_BACKPACK then
    ScheduleScan("backpack", this.ScanBackpack)
  elseif bagId == BAG_BANK or bagId == BAG_SUBSCRIBER_BANK then
    ScheduleScan("bank", this.ScanBank)
  elseif bagId == BAG_FURNITURE_VAULT then
    ScheduleScan("vault", this.ScanVault)
  elseif IsHouseBankBag(bagId) then
    ScheduleScan("houseBank" .. tostring(bagId), function() this.ScanHouseBank(bagId) end)
  end
end

function this.OnOpenBank(_, bankBag)
  if bankBag ~= nil and IsHouseBankBag(bankBag) then
    this.ScanHouseBank(bankBag)
  else
    this.ScanBankAndVault()
  end
end

-- Records name/icon/category for an item the first time we see it, so the
-- UI doesn't need to re-resolve item links every render. Name/icon were
-- confirmed working via /flist output. Category is new: confirmed chain is
-- GetItemLinkFurnitureDataId(link) -> GetFurnitureDataInfo(furnitureDataId)
-- -> GetFurnitureCategoryInfo(categoryId), sourced directly from the base
-- game's own housing furniture browser (itemtooltips.lua +
-- furnitureclasses_shared.lua), not guessed.
function this.CacheItemInfo(itemId, link)
  if this.settings.itemInfo[itemId] ~= nil then
    return -- already cached
  end

  local ok, name = pcall(GetItemLinkName, link)
  if not ok then
    d(string.format("ITEMINFO ERROR (name) for item %d: %s", itemId, tostring(name)))
    name = nil
  end

  local okIcon, icon = pcall(GetItemLinkIcon, link)
  if not okIcon then
    d(string.format("ITEMINFO ERROR (icon) for item %d: %s", itemId, tostring(icon)))
    icon = nil
  end

  local category = nil
  local theme = nil
  local okFurnId, furnitureDataId = pcall(GetItemLinkFurnitureDataId, link)
  if not okFurnId then
    PrintCategoryErrorOnce(string.format("CATEGORY ERROR (furnitureDataId) for item %d: %s", itemId, tostring(furnitureDataId)))
  elseif furnitureDataId ~= nil and furnitureDataId ~= 0 then
    local okDataInfo, categoryId, subcategoryId, furnitureTheme = pcall(GetFurnitureDataInfo, furnitureDataId)
    if not okDataInfo then
      PrintCategoryErrorOnce(string.format("CATEGORY ERROR (GetFurnitureDataInfo) for item %d: %s", itemId, tostring(categoryId)))
    else
      if categoryId ~= nil and categoryId ~= 0 then
        local okCatInfo, categoryName = pcall(GetFurnitureCategoryInfo, categoryId)
        if not okCatInfo then
          PrintCategoryErrorOnce(string.format("CATEGORY ERROR (GetFurnitureCategoryInfo) for item %d: %s", itemId, tostring(categoryName)))
        elseif categoryName ~= nil and categoryName ~= "" then
          category = categoryName
        end
      end

      -- Style/theme: same GetFurnitureDataInfo call, third return value.
      -- Confirmed via base game source (ZO_HousingSettingsTheme_SetupDropdown)
      -- that GetString("SI_FURNITURETHEMETYPE", furnitureTheme) resolves it
      -- to a readable name (High Elf, Breton, Nord, etc.).
      if furnitureTheme ~= nil then
        local okThemeInfo, themeName = pcall(GetString, "SI_FURNITURETHEMETYPE", furnitureTheme)
        if not okThemeInfo then
          PrintCategoryErrorOnce(string.format("CATEGORY ERROR (theme GetString) for item %d: %s", itemId, tostring(themeName)))
        elseif themeName ~= nil and themeName ~= "" then
          theme = themeName
        end
      end
    end
  end

  this.settings.itemInfo[itemId] = { name = name, icon = icon, category = category, theme = theme }
end

-- Generic bag scanner: returns { [itemId] = count } for every placeable
-- furnishing in the bag. Confirmed pattern (IsItemPlaceableFurniture,
-- direct bag/slot iteration) reused from Furniture Finder's vault scan.
function this.ScanBag(bagId, counts)
  counts = counts or {}
  local numSlots = GetBagSize(bagId)
  if numSlots == nil or numSlots == 0 then
    return counts
  end

  for slotIndex = 0, numSlots - 1 do
    if IsItemPlaceableFurniture(bagId, slotIndex) then
      local itemId = GetItemId(bagId, slotIndex)
      local stackSize = GetSlotStackSize(bagId, slotIndex)
      if itemId ~= nil and itemId ~= 0 then
        counts[itemId] = (counts[itemId] or 0) + stackSize
        local link = GetItemLink(bagId, slotIndex, LINK_STYLE_BRACKETS)
        this.CacheItemInfo(itemId, link)
      end
    end
  end

  return counts
end

function this.ScanBackpack()
  local charId = GetCurrentCharacterId()
  if charId == nil or charId == "" then
    return
  end
  this.settings.bagsByChar[charId] = {
    name = zo_strformat("<<1>>", GetUnitName("player")),
    items = this.ScanBag(BAG_BACKPACK),
  }
end

-- The bank is shared account-wide; ESO Plus members have a second half in
-- BAG_SUBSCRIBER_BANK, which is merged in here.
function this.ScanBank()
  local counts = this.ScanBag(BAG_BANK)
  this.ScanBag(BAG_SUBSCRIBER_BANK, counts)
  this.settings.bank = counts
end

function this.ScanVault()
  this.settings.vault = this.ScanBag(BAG_FURNITURE_VAULT)
end

function this.ScanBankAndVault()
  this.ScanBank()
  this.ScanVault()
end

-- House storage chests/coffers. Only readable while one is open, so this
-- runs on EVENT_OPEN_BANK for a house bank bag and on slot updates to it.
function this.ScanHouseBank(bagId)
  local name = "House Storage"
  local okCol, collectibleId = pcall(GetCollectibleForBag, bagId)
  if okCol and collectibleId ~= nil and collectibleId ~= 0 then
    local nickname = GetCollectibleNickname(collectibleId)
    if nickname ~= nil and nickname ~= "" then
      name = zo_strformat("<<1>>", nickname)
    else
      local collectibleName = GetCollectibleName(collectibleId)
      if collectibleName ~= nil and collectibleName ~= "" then
        name = zo_strformat("<<1>>", collectibleName)
      end
    end
  end

  this.settings.houseBanks[bagId] = {
    name = name,
    items = this.ScanBag(bagId),
  }
end

-- Confirmed working pattern, ported directly from Furniture Finder's
-- FurnitureFinder_Ownership.lua (ScanCurrentHouseIfOwner). This fixes the
-- two bugs found in the earlier standalone test:
--   1. GetPlacedFurnitureLink (not GetPlacedHousingFurnitureItemLink)
--   2. loop seeded with nil, exits on nil (not seeded/exited on 0)
function this.ScanCurrentHouseIfOwner()
  if not IsOwnerOfCurrentHouse() then
    return
  end

  local houseId = GetCurrentZoneHouseId()
  if houseId == nil or houseId == 0 then
    return -- not actually in a house
  end

  local collectibleId = GetCollectibleIdForHouse(houseId)
  local houseName = GetCollectibleName(collectibleId)
  local nickname = GetCollectibleNickname(collectibleId)
  if nickname ~= nil and nickname ~= "" then
    houseName = string.format("%s (%s)", houseName, nickname)
  end

  local counts = {}
  local furnitureId = nil
  repeat
    furnitureId = GetNextPlacedHousingFurnitureId(furnitureId)
    if furnitureId ~= nil then
      local link = GetPlacedFurnitureLink(furnitureId, LINK_STYLE_BRACKETS)
      local itemId = link ~= nil and link ~= "" and GetItemLinkItemId(link) or nil
      if itemId ~= nil and itemId ~= 0 then
        counts[itemId] = (counts[itemId] or 0) + 1
        this.CacheItemInfo(itemId, link)
      end
    end
  until furnitureId == nil

  this.settings.houses[houseId] = {
    name = houseName,
    items = counts,
    lastScanned = GetTimeStamp(),
  }
end

-- Assembles the full owned-furniture list for the UI: one entry per
-- itemId, with name/icon and a breakdown of every place it currently
-- is (or was last seen, for houses -- stale until you revisit).
function this.GetAllOwnedItems()
  local itemIds = {}

  local function collect(sourceTable)
    for itemId, _ in pairs(sourceTable or {}) do
      itemIds[itemId] = true
    end
  end

  for _, char in pairs(this.settings.bagsByChar) do
    collect(char.items)
  end
  collect(this.settings.bank)
  collect(this.settings.vault)
  for _, storage in pairs(this.settings.houseBanks) do
    collect(storage.items)
  end
  for _, house in pairs(this.settings.houses) do
    collect(house.items)
  end

  local results = {}
  for itemId, _ in pairs(itemIds) do
    local info = this.settings.itemInfo[itemId] or {}
    local locations = {}

    for charId, char in pairs(this.settings.bagsByChar) do
      local count = char.items and char.items[itemId]
      if count ~= nil and count > 0 then
        table.insert(locations, { type = "Bags", key = "bags:" .. tostring(charId), name = string.format("Bags (%s)", tostring(char.name)), count = count })
      end
    end

    local bankCount = this.settings.bank[itemId]
    if bankCount ~= nil and bankCount > 0 then
      table.insert(locations, { type = "Bank", key = "bank", name = "Bank", count = bankCount })
    end

    local vaultCount = this.settings.vault[itemId]
    if vaultCount ~= nil and vaultCount > 0 then
      table.insert(locations, { type = "Vault", key = "vault", name = "Furnishing Vault", count = vaultCount })
    end

    for bagId, storage in pairs(this.settings.houseBanks) do
      local count = storage.items and storage.items[itemId]
      if count ~= nil and count > 0 then
        table.insert(locations, { type = "HouseStorage", key = "storage:" .. tostring(bagId), name = tostring(storage.name), count = count, bagId = bagId })
      end
    end

    for houseId, house in pairs(this.settings.houses) do
      local count = house.items[itemId]
      if count ~= nil and count > 0 then
        table.insert(locations, {
          type = "House",
          key = "house:" .. tostring(houseId),
          name = house.name,
          count = count,
          houseId = houseId,
          lastScanned = house.lastScanned,
        })
      end
    end

    if #locations > 0 then
      table.insert(results, {
        itemId = itemId,
        name = info.name or ("Item " .. tostring(itemId)),
        icon = info.icon,
        category = info.category or "Uncategorized",
        theme = info.theme or "Unstyled",
        locations = locations,
      })
    end
  end

  -- alphabetical by name, so the list is stable and browsable
  table.sort(results, function(a, b)
    return tostring(a.name) < tostring(b.name)
  end)

  return results
end

-- v13: every place furniture can be, grouped for "Browse by location".
-- Each entry: { key, name, count (distinct furnishings), lastScanned (houses) }
function this.GetLocationGroups()
  local function distinct(items)
    local n = 0
    for _, count in pairs(items or {}) do
      if count > 0 then n = n + 1 end
    end
    return n
  end
  local byName = function(a, b) return tostring(a.name) < tostring(b.name) end

  local houses = {}
  for houseId, house in pairs(this.settings.houses) do
    houses[#houses + 1] = { key = "house:" .. tostring(houseId), name = house.name, count = distinct(house.items), lastScanned = house.lastScanned }
  end
  table.sort(houses, byName)

  local storage = {}
  storage[#storage + 1] = { key = "vault", name = "Furnishing Vault", count = distinct(this.settings.vault) }
  storage[#storage + 1] = { key = "bank", name = "Bank", count = distinct(this.settings.bank) }
  local chests = {}
  for bagId, chest in pairs(this.settings.houseBanks) do
    chests[#chests + 1] = { key = "storage:" .. tostring(bagId), name = chest.name, count = distinct(chest.items) }
  end
  table.sort(chests, byName)
  for _, chest in ipairs(chests) do storage[#storage + 1] = chest end

  local bags = {}
  for charId, char in pairs(this.settings.bagsByChar) do
    bags[#bags + 1] = { key = "bags:" .. tostring(charId), name = tostring(char.name), count = distinct(char.items) }
  end
  table.sort(bags, byName)

  local function nonEmpty(list)
    local out = {}
    for _, e in ipairs(list) do if e.count > 0 then out[#out + 1] = e end end
    return out
  end
  return {
    { name = "Houses", entries = nonEmpty(houses) },
    { name = "Storage", entries = nonEmpty(storage) },
    { name = "Characters' bags", entries = nonEmpty(bags) },
  }
end

local function OnAddOnLoaded(_, addOnName)
  if addOnName ~= ADDON_PACKAGE_NAME then
    return
  end
  this.Initialize()
  EVENT_MANAGER:UnregisterForEvent(this.name, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(this.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
