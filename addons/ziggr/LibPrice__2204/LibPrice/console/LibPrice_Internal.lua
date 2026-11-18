--[[
-------------------------------------------------------------------------------
-- LibPrice
-------------------------------------------------------------------------------
-- Originally published: 2018-11-29 by ziggr
-- Original code by ziggr was released without an explicit license.
-- All rights reserved to the original author.
--
-- Maintained with permission from the original author by: Sharlikran
-- Contributions since 2022-11-07 are licensed under the BSD 3-Clause License.
-- See LICENSE for terms applicable to new contributions.
--
-- Maintainer Notice:
-- Redistribution to platforms outside of ESOUI.com (e.g., Bethesda.net)
-- is discouraged unless coordinated with the current maintainer to avoid
-- compatibility issues or community fragmentation.
-------------------------------------------------------------------------------
]]
LibPrice = LibPrice or {}

-- How long of a date range to pass to Arkadius Trade Tools
LibPrice.day_ct_short = 3
LibPrice.day_ct_long = 90

-- source keys
LibPrice.TSC = "tsc"
LibPrice.CROWN = "crown"
LibPrice.ROLIS = "rolis"
LibPrice.NPC = "npc"

-- Currencies
LibPrice.CURRENCY_TYPE_GOLD = "gold"
LibPrice.CURRENCY_TYPE_WRIT_VOUCHERS = "vouchers"
LibPrice.CURRENCY_TYPE_ALLIANCE_POINTS = "ap"
LibPrice.CURRENCY_TYPE_CROWNS = "crowns"
LibPrice.CURRENCY_TYPE_TELVAR_STONES = "telvar"

-- Price types
LibPrice.PRICE_BID = "bid"
LibPrice.PRICE_ASK = "ask" -- listed for
LibPrice.PRICE_SALE = "sale" -- sold for
LibPrice.PRICE_AVG = "avg"

local function Error(msg, ...)
  d("|cFF6666LibPrice: " .. string.format(msg, ...))
end

-- Dispatch ------------------------------------------------------------------

function LibPrice.SourceList()
  if not LibPrice.SOURCE_LIST then
    LibPrice.SOURCE_LIST = {
      LibPrice.TSC,
      LibPrice.CROWN,
      LibPrice.ROLIS,
      LibPrice.NPC,
    }
  end
  return LibPrice.SOURCE_LIST
end

function LibPrice.CurrencyList()
  if not LibPrice.CURRENCY_LIST then
    LibPrice.CURRENCY_LIST = {
      [LibPrice.CURRENCY_TYPE_GOLD] = CURT_MONEY,
      [LibPrice.CURRENCY_TYPE_ALLIANCE_POINTS] = CURT_ALLIANCE_POINTS,
      [LibPrice.CURRENCY_TYPE_TELVAR_STONES] = CURT_TELVAR_STONES,
      [LibPrice.CURRENCY_TYPE_WRIT_VOUCHERS] = CURT_WRIT_VOUCHERS,
      [LibPrice.CURRENCY_TYPE_CROWNS] = CURT_CROWNS
    }
  end
  return LibPrice.CURRENCY_LIST
end

function LibPrice.PriceTypes()
  if not LibPrice.PRICE_TYPES then
    LibPrice.PRICE_TYPES = {
      LibPrice.PRICE_ASK,
      LibPrice.PRICE_AVG,
      LibPrice.PRICE_BID,
      LibPrice.PRICE_SALE
    }
  end
  return LibPrice.PRICE_TYPES
end

function LibPrice.Price(source_key, item_link)
  if not source_key then
    return nil
  end
  if not item_link then
    return nil
  end
  local self = LibPrice
  if not self.DISPATCH then
    self.DISPATCH = {
      [self.TSC] = { self.TSCPrice, self.CanTSCPrice },
      [self.CROWN] = { self.CrownPrice },
      [self.ROLIS] = { self.RolisPrice },
      [self.NPC] = { self.NPCPrice }
    }
  end
  if not (source_key and self.DISPATCH[source_key]) then
    Error("unknown source key:%s", tostring(source_key))
    return nil
  end
  if self.DISPATCH[source_key][2] and not self.DISPATCH[source_key][2]() then
    -- Requested source not installed/enabled.
    return nil
  end
  local cached = self.GetCachedPrice(source_key, item_link)
  if cached then
    return cached
  end
  local got = self.DISPATCH[source_key][1](item_link)
  if not got then
    return nil
  end
  self.SetCachedPrice(source_key, item_link, got)
  return got
end

function LibPrice.PriceNormalized(source_key, item_link)
  local self = LibPrice
  local got = self.Price(source_key, item_link)
  if not got then
    return nil
  end
  if not self.NORMALIZE then
    self.NORMALIZE = {
      [self.TSC] = self.TSCPriceNormalize,
      [self.CROWN] = self.CrownPriceNormalize,
      [self.ROLIS] = self.RolisPriceNormalize,
      [self.NPC] = self.NPCPriceNormalize
    }
  end
  if not self.NORMALIZE[source_key] then
    return nil
  end
  return self.NORMALIZE[source_key](got)
end

-- If the caller requested a specific list of  sources,
-- then return true only if key is in that list.
--
-- If caller did not specify sources, then return true
-- for all keys.
function LibPrice.Enabled(key, source_list)
  if #source_list == 0 then
    return true
  end
  for _, k in ipairs(source_list) do
    if k == key then
      return true
    end
  end
  return false
end

-- Tamriel Savings Co. ------------------------------------ TSCPriceFetcher2 --
--
-- TSCPriceDataAPI:GetItemData(itemLink) returns a fresh table, or nil, or
-- TSCPriceDataAPI.LOADING while the server file is still chunking in.
-- avgPrice is the quality-specific sale average, or the legacy average when
-- that quality has no row (fromLegacy). commonMin/commonMax are that same row.

function LibPrice.CanTSCPrice()
  return TSCPriceDataAPI and true
end

function LibPrice.TSCPrice(item_link)
  if not (TSCPriceDataAPI and TSCPriceDataAPI.GetItemData) then
    return nil
  end
  local item_data = TSCPriceDataAPI:GetItemData(item_link)
  if not item_data or item_data == TSCPriceDataAPI.LOADING or not item_data.avgPrice then
    return nil
  end
  -- ItemLinkToPriceGold still looks for this field name.
  item_data.tscPrice = item_data.avgPrice
  return item_data
end

function LibPrice.TSCPriceNormalize(tsc)
  if not (tsc and tsc.avgPrice) then
    return nil
  end
  return {
    { type = LibPrice.PRICE_SALE, [LibPrice.CURRENCY_TYPE_GOLD] = tsc.avgPrice, count = nil, days = nil }
  }
end

-- Crown Store ------------------------------------------------------ ziggr --
--
-- Furniture Catalogue catches MOST crown store items. Here's a few more
-- that FurC did not list (at least way back in 2017 when Zig originally
-- wrote the precursor to this library.)

function LibPrice.CrownPrice(item_link)
  if not item_link then
    return nil
  end
  local self = LibPrice
  if not self.CASH then
    self.CASH = {
      ["The Apprentice"] = { crowns = 4000 },
      ["The Atronach"] = { crowns = 4000 },
      ["The Tower"] = { crowns = 4000 },
      ["The Thief"] = { crowns = 4000 },
      ["The Serpent"] = { crowns = 4000 },
      ["The Ritual"] = { crowns = 4000 },
      ["The Mage"] = { crowns = 4000 },
      ["The Lady"] = { crowns = 4000 },
      ["The Lord"] = { crowns = 4000 },
      ["The Warrior"] = { crowns = 4000 },
      ["The Lover"] = { crowns = 4000 },
      ["The Steed"] = { crowns = 4000 },
      ["The Shadow"] = { crowns = 4000 },
      --torage Coffer, Fortified"              ] = { crowns =  100 } one of these was free for reaching level 1
      ["Storage Coffer, Secure"] = { crowns = 100 },
      ["Storage Coffer, Sturdy"] = { crowns = 100 },
      ["Storage Coffer, Oaken"] = { crowns = 100 },
      ["Storage Chest, Fortified"] = { crowns = 200 },
      ["Storage Chest, Oaken"] = { crowns = 200 },
      ["Storage Chest, Secure"] = { crowns = 200 },
      ["Storage Chest, Sturdy"] = { crowns = 200 },
      ["Nuzhimeh the Merchant"] = { crowns = 5000 },
      --["Pirharri the Smuggler"                  ] = ) -- Free for completing Thieves Guild quest lin
      ["Tythis Andromo, the Banker"] = { crowns = 5000 },
      ["Music Box, Blood and Glory"] = { crowns = 800 },
      ["Imperial Pillar, Chipped"] = { crowns = 410 },
      ["Imperial Pillar, Straight"] = { crowns = 410 }
    }
  end
  -- EN English only for now, need to get proper links
  -- and fix this.
  local name = GetItemLinkName(item_link)
  return self.CASH[name]
end

function LibPrice.CrownPriceNormalize(cash)
  if not cash then
    return nil
  end
  return {
    { type = LibPrice.PRICE_ASK, crowns = cash.crowns, count = 1 / 0, days = 0 }
  }
end

-- Rolis Hlaalu, Master Crafter Merchant ---------------------------- ziggr --

LibPrice.LINK_ATTUNABLE_BS = "|H1:item:119594:364:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h"
LibPrice.LINK_ATTUNABLE_CL = "|H1:item:119821:364:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h"
LibPrice.LINK_ATTUNABLE_WW = "|H1:item:119822:364:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h"
LibPrice.LINK_ATTUNABLE_JW = "|H1:item:137947:364:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h"

function LibPrice.RolisPrice(item_link)
  if not item_link then
    return nil
  end
  local self = LibPrice
  if not self.ROLIS_PRICE then
    self.ROLIS_PRICE = {
      [self.LINK_ATTUNABLE_BS] = { vouchers = 250 },
      [self.LINK_ATTUNABLE_CL] = { vouchers = 250 },
      [self.LINK_ATTUNABLE_WW] = { vouchers = 250 },
      [self.LINK_ATTUNABLE_JW] = { vouchers = 250 },
      ["Transmute Station"] = { vouchers = 1250 }
    }
  end
  local l = self.Unattune(item_link)
  local result = self.ROLIS_PRICE[l.item_link]

  -- Fallback to EN English name for transmute
  if not result then
    local item_name = GetItemLinkName(item_link)
    result = self.ROLIS_PRICE[item_name]
  end
  return result
end

function LibPrice.RolisPriceNormalize(rolis)
  if not rolis then
    return nil
  end
  return {
    { type = LibPrice.PRICE_ASK, [LibPrice.CURRENCY_TYPE_WRIT_VOUCHERS] = rolis.vouchers, count = 1 / 0, days = 0 }
  }
end

function LibPrice.Unattune(item_link)
  local self = LibPrice
  -- Remove the "attuning" that makes these
  -- crafting stations unique, preventing a single
  -- stack of count 44 instead of 44 unique items.
  --
  -- Note trailing space after each station name!
  -- Required to avoid false match on non-attunable
  -- stations.

  -- EN English only for now. Fix later.
  local item_name = GetItemLinkName(item_link)

  if string.find(item_name, "Blacksmithing Station ") then
    return {
      item_name = "Attunable Blacksmithing Station",
      item_link = self.LINK_ATTUNABLE_BS,
      furniture_data_id = 4050
    }
  elseif string.find(item_name, "Clothing Station ") then
    return {
      item_name = "Attunable Clothier Station",
      item_link = self.LINK_ATTUNABLE_CL,
      furniture_data_id = 4051
    }
  elseif string.find(item_name, "Woodworking Station ") then
    return {
      item_name = "Attunable Woodworking Station",
      item_link = self.LINK_ATTUNABLE_WW,
      furniture_data_id = 4052
    }
  elseif string.find(item_name, "Jewelry Crafting Station ") then
    return {
      item_name = "Attunable Jewelry Crafting Station",
      item_link = self.LINK_ATTUNABLE_JW,
      furniture_data_id = 4051
    }
  end
  -- Nothing to unattune. Return original, unchanged.
  return {
    item_name = item_name,
    item_link = item_link
  }
end

-- NPC Vendor ----------------------------------------------------------------

function LibPrice.NPCPrice(item_link)
  local _, value = GetItemLinkInfo(item_link)
  if not value or value <= 0 then
    return nil
  end
  return {
    npcVendor = value
  }
end

function LibPrice.NPCPriceNormalize(npc)
  if not npc then
    return nil
  end
  local prices = {}
  if npc.npcVendor then
    table.insert(prices, { type = LibPrice.PRICE_BID, price = npc.npcVendor, count = 1 / 0, days = 0 })
  end
  if npc.npcPurchase then
    table.insert(prices, { type = LibPrice.PRICE_ASK, price = npc.npcPurchase, count = 1 / 0, days = 0 })
  end
  return prices
end

-- Cache ---------------------------------------------------------------------
--
-- TSC parses a packed price string per lookup. Hold the result for a few
-- minutes so repeated tooltip and listing calls do not parse it again.

LibPrice.cache = nil
LibPrice.cache_reset_ts = nil
LibPrice.CACHE_DUR_SECONDS = 5 * 60

-- Allow cached data to expire after a few minutes.
function LibPrice.ResetCacheIfNecessary()
  local self = LibPrice
  local now_ts = GetTimeStamp()
  self.cache_reset_ts = self.cache_reset_ts or now_ts
  local ago_secs = GetDiffBetweenTimeStamps(now_ts, self.cache_reset_ts)
  if self.CACHE_DUR_SECONDS < ago_secs then
    self.cache = {}
    self.cache_reset_ts = now_ts
  end
end

function LibPrice.GetCachedPrice(source_key, item_link)
  LibPrice.ResetCacheIfNecessary()
  if not (LibPrice.cache and LibPrice.cache[source_key]) then
    return nil
  end
  return LibPrice.cache[source_key][item_link]
end

function LibPrice.SetCachedPrice(source_key, item_link, value)
  LibPrice.cache = LibPrice.cache or {}
  LibPrice.cache[source_key] = LibPrice.cache[source_key] or {}
  LibPrice.cache[source_key][item_link] = value
end
