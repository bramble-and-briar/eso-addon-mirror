--[[
Furniture Finder - Ownership Tracking

Adds "you own X, here's where" info to Furniture Finder's tooltip
section, alongside the existing source data.

All APIs below are confirmed against DecoTrack's real source
(DecoTrack.lua, v2.6.0, by Cardinal05/Architectura) - not guesswork.

STATUS OF EACH LOCATION:
  Backpack / Bank      - DONE. Live via GetItemLinkStacks(itemLink),
                          confirmed separately against ESO_HowMany's
                          source. No caching needed, always accurate.
  Furnishing Vault      - DONE. Scanned via the real BAG_FURNITURE_VAULT
                          bag id (not a guess - confirmed from DecoTrack),
                          cached on bank/vault open.
  Placed in a house     - DONE. Confirmed from DecoTrack: iterate
                          GetNextPlacedHousingFurnitureId(furnitureId)
                          while standing in a house, resolve each result
                          to an item link via GetPlacedFurnitureLink(id),
                          then to an item id via the built-in
                          GetItemLinkItemId(link) (confirmed separately
                          from Furniture Catalogue's own source - simpler
                          than DecoTrack's manual link-string parsing,
                          same result). Tagged with the current house's
                          name, cached per house, refreshed whenever you
                          enter/re-enter it or place/remove furniture.
]]

-- TESTING GATE: matches the same gate in FurnitureFinder.lua. Remove
-- this whole if-block (or the one in FurnitureFinder.lua) once ready
-- to publish for everyone -- keep them in sync until then.
-- Testing gate removed 2026-08-25 -- addon now open to everyone.

FFOwnership = {}
local this = FFOwnership
this.name = "FurnitureFinder_Ownership" -- unique key for EVENT_MANAGER registrations, not the addon's package name

-- The actual addon package name, as declared in FurnitureFinder.addon.
-- EVENT_ADD_ON_LOADED fires once per ADDON (the whole package), not once
-- per file, so this must match the manifest -- not this.name above.
-- (Bug found and fixed 2026-08-24: this file previously compared against
-- this.name here, which never matched, so Initialize() never ran and
-- this.settings stayed nil forever.)
local ADDON_PACKAGE_NAME = "FurnitureFinder"

function this.Initialize()
  this.settings = ZO_SavedVars:NewAccountWide("FurnitureFinderOwnershipData", 1, nil, {
    vault = {},  -- [itemId] = count
    houses = {}, -- [houseId] = { name = "...", items = { [itemId] = count } }
  })

  EVENT_MANAGER:RegisterForEvent(this.name, EVENT_OPEN_BANK, this.ScanVaultIfPresent)
  EVENT_MANAGER:RegisterForEvent(this.name, EVENT_CLOSE_BANK, this.ScanVaultIfPresent)
  EVENT_MANAGER:RegisterForEvent(this.name, EVENT_PLAYER_ACTIVATED, this.ScanCurrentHouseIfOwner)
  EVENT_MANAGER:RegisterForEvent(this.name, EVENT_HOUSING_FURNITURE_PLACED, this.ScanCurrentHouseIfOwner)
  EVENT_MANAGER:RegisterForEvent(this.name, EVENT_HOUSING_FURNITURE_REMOVED, this.ScanCurrentHouseIfOwner)
end

-- Scans the furnishing vault bag, if the player has one, and caches
-- itemId -> count. Safe to call whenever the bank/vault UI is open.
-- BAG_FURNITURE_VAULT is a real ESO constant (confirmed via DecoTrack).
function this.ScanVaultIfPresent()
  local numSlots = GetBagSize(BAG_FURNITURE_VAULT)
  if numSlots == nil or numSlots == 0 then
    return -- player doesn't have vault access, or it's empty
  end

  local counts = {}
  for slotIndex = 0, numSlots - 1 do
    if IsItemPlaceableFurniture(BAG_FURNITURE_VAULT, slotIndex) then
      local itemId = GetItemId(BAG_FURNITURE_VAULT, slotIndex)
      local stackSize = GetSlotStackSize(BAG_FURNITURE_VAULT, slotIndex)
      if itemId ~= nil and itemId ~= 0 then
        counts[itemId] = (counts[itemId] or 0) + stackSize
      end
    end
  end

  this.settings.vault = counts
end

-- Scans everything placed in the house you're currently standing in,
-- if you own it. Caches itemId -> count under that house's id.
-- Confirmed pattern: GetNextPlacedHousingFurnitureId walks every placed
-- furniture id in the current house when called repeatedly with the
-- previous result, until it returns nil.
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
      end
    end
  until furnitureId == nil

  this.settings.houses[houseId] = { name = houseName, items = counts }
end

-- Returns a list of {location, count} for the given item, e.g.
--   { {location = "Bags", count = 1}, {location = "Bank", count = 2},
--     {location = "Furnishing Vault", count = 1},
--     {location = "Alinor Townhouse", count = 1} }
function this.GetOwnershipInfo(itemLink, itemId)
  local results = {}

  -- API 101051: GetItemLinkStacks returns backpack, bank, craft bag,
  -- house storage, furnishing vault, Vengeance bag. The vault and house
  -- storage counts are live, so prefer them over our cached snapshots.
  local inventoryCount, bankCount, _, houseBankCount, liveVaultCount = GetItemLinkStacks(itemLink)

  if inventoryCount ~= nil and inventoryCount > 0 then
    table.insert(results, { location = "Bags", count = inventoryCount })
  end

  if bankCount ~= nil and bankCount > 0 then
    table.insert(results, { location = "Bank", count = bankCount })
  end

  if houseBankCount ~= nil and houseBankCount > 0 then
    table.insert(results, { location = "House Storage", count = houseBankCount })
  end

  -- Fall back to the cached vault scan only if the live count isn't
  -- available (older client), so items are never counted twice.
  local vaultCount = liveVaultCount
  if vaultCount == nil then
    vaultCount = this.settings.vault[itemId]
  end
  if vaultCount ~= nil and vaultCount > 0 then
    table.insert(results, { location = "Furnishing Vault", count = vaultCount })
  end

  for _, house in pairs(this.settings.houses) do
    local count = house.items[itemId]
    if count ~= nil and count > 0 then
      table.insert(results, { location = house.name, count = count })
    end
  end

  return results
end

-- Builds the tooltip line, e.g. "You own 3: 1 in Bags, 1 in Bank, 1 in Furnishing Vault"
-- Returns nil if the player owns none, so the caller can skip the section entirely.
function this.FormatOwnershipLine(itemLink, itemId)
  local info = this.GetOwnershipInfo(itemLink, itemId)
  if #info == 0 then
    return nil
  end

  local total = 0
  local parts = {}
  for _, entry in ipairs(info) do
    total = total + entry.count
    table.insert(parts, string.format("%d in %s", entry.count, entry.location))
  end

  return string.format("You own %d: %s", total, table.concat(parts, ", "))
end

local function OnAddOnLoaded(_, addOnName)
  if addOnName ~= ADDON_PACKAGE_NAME then
    return
  end
  this.Initialize()
  EVENT_MANAGER:UnregisterForEvent(this.name, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(this.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
