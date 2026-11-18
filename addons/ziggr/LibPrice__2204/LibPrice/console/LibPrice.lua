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

-- Price ---------------------------------------------------------------------
--
-- Just tell me how much it costs.
--
-- Returns the first "suggested or average price in gold" that it can find.
-- Return nil if none found.
-- No crown or voucher prices returned.
--
-- Returns
--      gold price  (number, often a float)
--      source_key  (string "tsc", others... )
--      field_name  (string "avgPrice", "tscPrice", others... )
--
function LibPrice.ItemLinkToPriceGold(item_link, ...)
  local self = LibPrice
  local field_names = { "avgPrice", "tscPrice", "npcVendor" }

  -- If source list requested, then search only
  -- the requested sources. If no source list requested,
  -- search all sources.
  local requested_source_list = { ... }
  for _, source_key in ipairs(self.SourceList()) do
    if self.Enabled(source_key, requested_source_list) then
      local result = self.Price(source_key, item_link)
      if result then
        for _, field_name in ipairs(field_names) do
          if result[field_name] then
            return result[field_name], source_key, field_name
          end
        end
      end
    end
  end
  return nil
end

-- All the data
--
-- input:
--  item_link
--  optional: list of sources to return. Any of the items in LibPrice.SourceList(), such as:
--      "tsc"
--
-- Returns:
-- tsc                  TSCPriceFetcher2, TSCPriceDataAPI:GetItemData(itemLink)
--  avgPrice            quality sale average, or the legacy average when fromLegacy
--  tscPrice            same number as avgPrice
--  commonMin
--  commonMax
--  legacyAvg
--  legacyMin
--  legacyMax
--  fromLegacy
--
-- crown                Crown store: just a few items that Furniture Catalogue
--  crowns              lacked when Zig wrote this library's precursor in 2017.
--
-- rolis                Rolis Hlaalu, MasterCraft Mediator, and Faustina Curio,
--  vouchers            Achievement Mediator.
--
-- npc                  Sell to any NPC vendor for gold.
--  npcVendor
--
-- Not getting the price data you expect? Modify your item_link, perhaps
-- simplify some of those unimportant numbers. What does "simplify" and
-- "unimportant" mean here? Varies depending on item. Item links are...
-- enigmatic. See the [UESP page](https://en.uesp.net/wiki/Online:Item_Link)
-- for _some_ explanation.
--
function LibPrice.ItemLinkToPriceData(item_link, ...)
  local self = LibPrice
  local result = {}
  -- If source list requested, then search only
  -- the requested sources. If no source list requested,
  -- search all sources.
  local requested_source_list = { ... }
  for _, source_key in ipairs(self.SourceList()) do
    if self.Enabled(source_key, requested_source_list) then
      result[source_key] = self.Price(source_key, item_link)
    end
  end
  return result
end

-- All the data renormalized into bid, ask, or sale prices, with additional details for fully generic processing.
--
-- input:
--  item_link
--  optional: list of sources to return. Any of the items in LibPrice.SourceList(), such as:
--      "tsc"
--
-- Returns:
--  A table containing items with the following schema:
--    {
--
--      type   = One of 'bid', 'ask', or 'sale'
--
--      One of:
--      ['gold'] = the value in gold
--      ['vouchers'] = the price in vouchers
--      ['ap'] = the price in alliance points
--      ['crowns'] = the price in crowns
--          the keys are in LibPrice.CurrencyList()
--
--      count  = the number of listings that make up the price, use for weighted averages or checking if the value is significant
--      days   = the max age of the data
--      source = the source key of the data
--    }
--
function LibPrice.ItemLinkToBidAskData(item_link, ...)
  local self = LibPrice
  local result = {}
  -- If source list requested, then search only
  -- the requested sources. If no source list requested,
  -- search all sources.
  local requested_source_list = { ... }
  for _, source_key in ipairs(self.SourceList()) do
    if self.Enabled(source_key, requested_source_list) then
      local normalized = self.PriceNormalized(source_key, item_link)
      if normalized then
        for _, data in ipairs(normalized) do
          data.source = source_key
          table.insert(result, data)
        end
      end
    end
  end
  return result
end

-- Coallates all price data into categories by currency and type, for full generic processing.
--
-- input:
--  item_link
--  optional: list of sources to use. Any of the items in LibPrice.SourceList(), such as:
--      "tsc"
--
-- Returns:
--  An object with per-currency prices (given prices were found):
--    {
--      [CURRENCY] = {
--        bid = { value = 2.04, count = 1, sources = { } },
--        sale = { value = 6.23, count = 160, sources = { [1] = "tsc" } },
--        ask = { value = 12.26, count = 535, sources = { [1] = "tsc" } },
--      }
--    }
--
function LibPrice.ItemLinkToBidAskSpread(item_link, ...)
  local data = LibPrice.ItemLinkToBidAskData(item_link, ...)
  local result = {}
  for _, price in ipairs(data) do
    for currency, _ in pairs(LibPrice.CurrencyList()) do
      if price[currency] ~= nil then
        local record
        if not result[currency] then
          record = {}
          result[currency] = record
        else
          record = result[currency]
        end

        local metric
        if not record[price.type] then
          metric = { sources = {} }
          record[price.type] = metric
        else
          metric = record[price.type]
        end
        metric.sources[price.source] = true

        local value = price[currency]
        local count = price.count or 1
        if price.type == "sale" then
          metric.sum = (metric.sum or 0) + (value * count)
          metric.count = (metric.count or 0) + count
        else
          if
          not metric.value or (price.type == "bid" and value > metric.value) or
            (price.type == "ask" and value < metric.value)
          then
            metric.value = value
            metric.count = count
          elseif metric.value == value then
            metric.count = metric.count + count
          end
        end
      end
    end
  end
  for _, record in pairs(result) do
    for t, metric in pairs(record) do
      local sources = {}
      for source, _ in pairs(metric.sources) do
        table.insert(sources, source)
      end
      metric.sources = sources
      if t == "sale" then
        metric.value = metric.sum / metric.count
        metric.sum = nil
      end
    end
  end
  return result
end
