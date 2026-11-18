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
LibPrice.MM = "mm"
LibPrice.ATT = "att"
LibPrice.FURC = "furc"
LibPrice.TTC = "ttc"
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
      LibPrice.MM,
      LibPrice.ATT,
      LibPrice.FURC,
      LibPrice.TTC,
      LibPrice.CROWN,
      LibPrice.ROLIS,
      LibPrice.NPC
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
      [self.MM] = { self.MMPrice, self.CanMMPrice },
      [self.ATT] = { self.ATTPrice, self.CanATTPrice },
      [self.FURC] = { self.FurCPrice, self.CanFurCPrice },
      [self.TTC] = { self.TTCPrice, self.CanTTCPrice },
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
      [self.MM] = self.MMPriceNormalize,
      [self.ATT] = self.ATTPriceNormalize,
      [self.FURC] = self.FurCPriceNormalize,
      [self.TTC] = self.TTCPriceNormalize,
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

-- Master Merchant ------------------------------------- Philgo, Sharlikran --

function LibPrice.CanMMPrice()
  return MasterMerchant and true
end

function LibPrice.MMPrice(item_link)
  if not (MasterMerchant and MasterMerchant.isInitialized) then
    return nil
  end
  if not item_link then
    return nil
  end
  local mm = MasterMerchant:GetTooltipStats(item_link, true, false)
  if not (mm and mm.avgPrice and 0 < mm.avgPrice) then
    return nil
  end
  return mm
end

function LibPrice.MMPriceNormalize(mm)
  if not mm then
    return nil
  end
  local prices = {}
  if mm.avgPrice ~= nil then
    table.insert(
      prices,
      {
        type = LibPrice.PRICE_SALE,
        [LibPrice.CURRENCY_TYPE_GOLD] = mm.avgPrice,
        count = mm.numSales,
        days = mm.numDays
      }
    )
  end
  if mm.bonanzaCount then
    table.insert(
      prices,
      { type = LibPrice.PRICE_ASK, [LibPrice.CURRENCY_TYPE_GOLD] = mm.bonanzaPrice, count = mm.bonanzaCount }
    )
  end
  return prices
end

-- Arkadius Trade Tools ----------------------- Arkadius, Verbalinkontinenz --

function LibPrice.CanATTPrice()
  return ArkadiusTradeTools and ArkadiusTradeTools.Modules and ArkadiusTradeTools.Modules.Sales and
    ArkadiusTradeTools.Modules.Sales.addMenuItems and
    true
end

function LibPrice.ATTPrice(item_link)
  local self = LibPrice
  -- ATT initializes its sales data at
  -- EVENT_PLAYER_ACTIVATED time, which comes after
  -- EVENT_ADD_ON_LOADED time, when some add-ons
  -- *cough*WritWorthy*cough* foolishly request price
  -- data. So check some random internal "addMenuItems"
  -- that gets set during ATT sales data initialization
  -- and return nil if ATT is not quite ready.
  if
  not (ArkadiusTradeTools and ArkadiusTradeTools.Modules and ArkadiusTradeTools.Modules.Sales and
    ArkadiusTradeTools.Modules.Sales.addMenuItems)
  then
    return nil
  end

  local att
  for _, day_ct in ipairs({ self.day_ct_short, self.day_ct_long }) do
    att = ArkadiusTradeTools.Modules.Sales:GetAveragePricePerItem(
      item_link,
      GetTimeStamp() - (ZO_ONE_DAY_IN_SECONDS * day_ct)
    )
    if att and 0 < att then
      return {
        avgPrice = att,
        numDays = day_ct
      }
    end
  end
  return nil
end

function LibPrice.ATTPriceNormalize(att)
  if not att then
    return nil
  end
  return {
    { type = LibPrice.PRICE_SALE, [LibPrice.CURRENCY_TYPE_GOLD] = att.avgPrice, count = nil, days = att.numDays } -- TODO: Count.
  }
end

-- Furniture Catalogue -------------------------------- LibFurnitureCatalogue --
--
-- GetEntry is the miss test (nil when the item is not in the catalogue).
-- GetSourceDetails is the price: records are in preferred order, and
-- record.cost is { currency, amount }. Pass the entry into GetIngredients
-- so that call reads the recipe it already holds.

local function currencyTypeFromConstant(currency_constant)
  local self = LibPrice
  if not self.CURT_TO_CURRENCY_TYPE then
    self.CURT_TO_CURRENCY_TYPE = {}
    for currency_type, listed_constant in pairs(self.CurrencyList()) do
      self.CURT_TO_CURRENCY_TYPE[listed_constant] = currency_type
    end
  end
  return self.CURT_TO_CURRENCY_TYPE[currency_constant]
end

-- vendor is a locale string id. locations[1] is the best-known placement:
-- location is a zone id, place is a locale string id.
local function catalogueSourceNote(source)
  local vendor_name = source.vendor and zo_strformat("<<C:1>>", GetString(source.vendor))
  local placement = source.locations and source.locations[1]
  local place_name = nil
  if placement then
    local zone_name = placement.location and zo_strformat("<<C:1>>", GetZoneNameById(placement.location))
    local place_label = placement.place and zo_strformat("<<C:1>>", GetString(placement.place))
    if zone_name and place_label then
      place_name = zone_name .. ", " .. place_label
    else
      place_name = zone_name or place_label
    end
  end
  if vendor_name and place_name then
    return vendor_name .. " in " .. place_name
  end
  return vendor_name or place_name
end

local function craftingPrice(item_link, entry)
  local self = LibPrice
  local ingredients = LibFurnitureCatalogue.API.GetIngredients(item_link, entry)
  local ingredient_rows = {}
  local total_gold = 0
  local notes = "Crafting cost"
  for ingredient_link, ingredient_count in pairs(ingredients) do
    local gold, source_key, field_name = self.ItemLinkToPriceGold(ingredient_link)
    ingredient_rows[#ingredient_rows + 1] = {
      ingr_ct = ingredient_count,
      ingr_name = GetItemLinkName(ingredient_link),
      ingr_link = ingredient_link,
      ingr_gold_ea = gold,
      ingr_gold_source_key = source_key,
      ingr_gold_field_name = field_name
    }
    if gold then
      total_gold = total_gold + ingredient_count * gold
    else
      notes = "Partial crafting cost, missing some ingredient costs."
    end
  end
  if #ingredient_rows == 0 then
    return nil
  end
  return self.CURRENCY_TYPE_GOLD, total_gold, notes, ingredient_rows
end

function LibPrice.CanFurCPrice()
  return LibFurnitureCatalogue and LibFurnitureCatalogue.API and true
end

function LibPrice.FurCPrice(item_link)
  local catalogue = LibFurnitureCatalogue and LibFurnitureCatalogue.API
  if not catalogue then
    return nil
  end

  local entry = catalogue.GetEntry(item_link)
  if not entry then
    return nil
  end

  local records = catalogue.GetSourceDetails(item_link)
  local preferred = records[1]
  if not preferred then
    return nil
  end

  local origin = preferred.source.type
  local source_types = catalogue.GetSourceTypes()
  local currency_type, currency_ct, notes, ingredient_list
  if origin == source_types.CRAFTING then
    currency_type, currency_ct, notes, ingredient_list = craftingPrice(item_link, entry)
  elseif origin ~= source_types.IGNORED then
    for _, record in ipairs(records) do
      if record.source.type ~= origin then
        break
      end
      local cost = record.cost
      if cost then
        currency_type = currencyTypeFromConstant(cost.currency)
        if currency_type then
          currency_ct = cost.amount
          notes = catalogueSourceNote(record.source)
          break
        end
      end
    end
  end

  return {
    origin = origin,
    desc = notes,
    currency_type = currency_type,
    currency_ct = currency_ct,
    notes = notes,
    ingredient_list = ingredient_list
  }
end

function LibPrice.FurCPriceNormalize(furc)
  if not furc or not furc.currency_type or furc.currency_ct == nil then
    return nil
  end
  return {
    { type = LibPrice.PRICE_BID, [furc.currency_type] = furc.currency_ct, count = 1 / 0, days = 0 }
  }
end

-- Tamriel Trade Centre --------------------------------------------- cyxui --

function LibPrice.CanTTCPrice()
  return TamrielTradeCentrePrice and true
end

function LibPrice.TTCPrice(item_link)
  if not TamrielTradeCentrePrice then
    return nil
  end
  return TamrielTradeCentrePrice:GetPriceInfo(item_link)
end

function LibPrice.TTCPriceNormalize(ttc)
  if not ttc then
    return nil
  end
  local prices = {}
  if ttc.Avg ~= nil then
    table.insert(
      prices,
      { type = LibPrice.PRICE_ASK, [LibPrice.CURRENCY_TYPE_GOLD] = ttc.Avg, count = ttc.EntryCount }
    )
  end
  if ttc.SuggestedPrice ~= nil then
    table.insert(
      prices,
      {
        type = LibPrice.PRICE_AVG,
        [LibPrice.CURRENCY_TYPE_GOLD] = ttc.SuggestedPrice / 0.8,
        count = math.ceil(ttc.EntryCount * 0.3)
      }
    )
  end
  if ttc.SaleAvg ~= nil then
    table.insert(
      prices,
      { type = LibPrice.PRICE_SALE, [LibPrice.CURRENCY_TYPE_GOLD] = ttc.SaleAvg, saleCount = ttc.SaleEntryCount }
    )
  end
  return prices
end

-- Crown Store ------------------------------------------------------ ziggr --
--
-- Furnishings from the 2017 list are crown_store rows in
-- LibFurnitureCatalogue/data/GeneratedDatabase.lua (currency id 6 = crowns),
-- so FurCPrice returns them. This table is only the account services that
-- catalogue does not contain: inventory upgrades and assistants.
-- Names are English. GetItemLinkName is what the client shows.

function LibPrice.CrownPrice(item_link)
  if not item_link then
    return nil
  end
  local self = LibPrice
  if not self.CASH then
    self.CASH = {
      -- Storage Coffer, Fortified was the free level-1 reward.
      ["Storage Coffer, Secure"] = { crowns = 100 },
      ["Storage Coffer, Sturdy"] = { crowns = 100 },
      ["Storage Coffer, Oaken"] = { crowns = 100 },
      ["Storage Chest, Fortified"] = { crowns = 200 },
      ["Storage Chest, Oaken"] = { crowns = 200 },
      ["Storage Chest, Secure"] = { crowns = 200 },
      ["Storage Chest, Sturdy"] = { crowns = 200 },
      ["Nuzhimeh the Merchant"] = { crowns = 5000 },
      -- Pirharri the Smuggler is the Thieves Guild quest reward.
      ["Tythis Andromo, the Banker"] = { crowns = 5000 }
    }
  end
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
  -- crafting stations unique, preventing FurC
  -- and MM from coming up with prices, AND
  -- preventing us from combining them into a single
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
  local npcPurchase
  if MasterMerchant and MasterMerchant["vendor_price_table"] then
    local itemId = GetItemLinkItemId(item_link)
    local itemType = GetItemLinkItemType(item_link)
    if MasterMerchant["vendor_price_table"][itemType] then
      npcPurchase = MasterMerchant["vendor_price_table"][itemType][itemId]
    end
  end

  if not value and not npcPurchase then
    return nil
  end
  return {
    npcVendor = value and value > 0 and value or nil,
    npcPurchase = npcPurchase and npcPurchase > 0 and npcPurchase or nil
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
-- Calculating an "average price" from MM and ATT is an O(n) scan through
-- sales records. Expensive. Cache results for a few minutes to avoid crushing
-- the CPU with wasteful re-calculation.

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
  -- allow the MM cache to do its job
  if source_key == LibPrice.MM then
    return nil
  end
  return LibPrice.cache[source_key][item_link]
end

function LibPrice.SetCachedPrice(source_key, item_link, value)
  -- allow the MM cache to do its job
  if source_key == LibPrice.MM then
    return
  end
  LibPrice.cache = LibPrice.cache or {}
  LibPrice.cache[source_key] = LibPrice.cache[source_key] or {}
  LibPrice.cache[source_key][item_link] = value
end
