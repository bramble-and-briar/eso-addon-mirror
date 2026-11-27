-- KelaPadUI TTC/ATT/Master Merchant trading-data helpers.

local KPUI_TRADINGHOUSE = KPUI_TRADINGHOUSE
local colors = KPUI_TRADINGHOUSE.colors

-- Master Merchant's numbers for an item, or nil: avgPrice, numSales, numItems,
-- and low/high when it has cached the item's graph. The call is the one
-- LibPrice makes (averageOnly, no graph); until Master Merchant has loaded its
-- sales it returns an empty table, and a failure inside it is ignored.
local function GetMasterMerchantStats(itemLink)
	if not MasterMerchant or not MasterMerchant.isInitialized or not MasterMerchant.GetTooltipStats then
		return nil
	end
	local ok, stats = pcall(MasterMerchant.GetTooltipStats, MasterMerchant, itemLink, true, false)
	if not (ok and type(stats) == "table" and type(stats.avgPrice) == "number" and stats.avgPrice > 0) then
		return nil
	end
	local graph = type(stats.graphInfo) == "table" and stats.graphInfo or nil
	return
	{
		avgPrice = stats.avgPrice,
		numSales = stats.numSales or 0,
		numItems = stats.numItems or 0,
		low = graph and graph.low or nil,
		high = graph and graph.high or nil,
	}
end

-- Price providers for the item tooltip. Each one reports the same shape, so
-- the tooltip loops over them and a new provider is one more entry:
--   { id, color (hex), isLoaded(), showNoData, GetStats(itemLink) }
-- GetStats returns nil when the provider has no data for the item, or
--   { headline = the single price to show (nil for none), avg, min, max,
--     count, countLabel }
-- Their order is the order they show in.
local PRICE_PROVIDERS =
{
	{
		id = "ATT",
		color = "1fe095",
		showNoData = true,
		isLoaded = function()
			return ArkadiusTradeTools ~= nil
		end,
		GetStats = function(itemLink)
			local stats = KelaGetATTPriceStats(itemLink)
			if not stats then
				return nil
			end
			return
			{
				headline = stats.Avg,
				avg = stats.Avg, min = stats.Min or 0, max = stats.Max,
				count = stats.Sales, countLabel = KELA_PRICE_SALES,
			}
		end,
	},
	{
		id = "TTC",
		color = "1fcae0",
		showNoData = true,
		isLoaded = function()
			return TamrielTradeCentre ~= nil and TamrielTradeCentrePrice ~= nil
		end,
		GetStats = function(itemLink)
			local info = TamrielTradeCentrePrice:GetPriceInfo(itemLink)
			if not info then
				return nil
			end
			-- TTC's suggested price is 80% of its average; 1.125 undoes that so the
			-- headline sits beside the other providers' averages.
			local headline = info.SuggestedPrice or info.Avg
			return
			{
				headline = headline and headline * 1.125 or nil,
				avg = info.Avg, min = info.Min, max = info.Max,
				count = info.EntryCount, countLabel = KELA_PRICE_LISTINGS,
			}
		end,
	},
	{
		id = "MM",
		color = "7171d1",
		showNoData = true,
		isLoaded = function()
			return MasterMerchant ~= nil
		end,
		GetStats = function(itemLink)
			local stats = GetMasterMerchantStats(itemLink)
			if not stats then
				return nil
			end
			return
			{
				headline = stats.avgPrice,
				avg = stats.avgPrice,
				min = stats.low, max = stats.high,
				count = stats.numSales, countLabel = KELA_PRICE_SALES,
			}
		end,
	},
}

-- What the item tooltip shows for an item: one line per loaded provider and the
-- average price, the average of the providers' headlines (nil when none
-- has a price). A line reads "TTC  3,400   12 Listings  |  2,900 - 4,100", with
-- the provider's color on its name and the details in grey.
function KelaGetPriceSummary(itemLink)
	local lines = {}
	local total, count = 0, 0
	for _, provider in ipairs(PRICE_PROVIDERS) do
		if provider.isLoaded() then
			local stats = provider.GetStats(itemLink)
			local name = "|c" .. provider.color .. provider.id .. "|r"
			if stats and stats.headline then
				total = total + stats.headline
				count = count + 1
				-- Average first, then how many listings or sales it rests on, then the range.
				local details = {}
				if stats.count and stats.countLabel then
					details[#details + 1] = KelaLocalizedFormatNumber(stats.count, 0) .. " " .. GetString(stats.countLabel)
				end
				if stats.min and stats.max then
					details[#details + 1] = KelaLocalizedFormatNumber(stats.min, 0) .. " - " .. KelaLocalizedFormatNumber(stats.max, 0)
				end
				local line = name .. "  " .. colors.COLOR_WHITE:Colorize(KelaLocalizedFormatNumber(stats.headline, 0))
				if #details > 0 then
					line = line .. "   " .. colors.COLOR_LIGHT_GREY:Colorize(table.concat(details, "  |  "))
				end
				lines[#lines + 1] = line
			elseif stats or provider.showNoData then
				lines[#lines + 1] = name .. "  " .. colors.COLOR_LIGHT_GREY:Colorize("N/A")
			end
		end
	end
	return lines, count > 0 and total / count or nil
end

-- ATT sale statistics for one item over the analysis period; used by the item
-- tooltip's price line.
function KelaGetATTPriceStats(itemLink)
	if not ArkadiusTradeTools or not ArkadiusTradeTools.Modules or not ArkadiusTradeTools.Modules.Sales then
		return nil
	end
	
	local ArkadiusTradeToolsSales = ArkadiusTradeTools.Modules.Sales
    local seconds_in_day = ZO_ONE_DAY_IN_SECONDS
    local days = KelaGetATTAnalysisPeriod()
	local itemSales = ArkadiusTradeToolsSales:GetItemSalesInformation(itemLink, GetTimeStamp() - days * seconds_in_day) --	30 * 86400)

	local stats = {
		Avg = 0,
		Min = math.huge,
		Max = 0,
		Sales = 0,
		Quantity = 0,
	}

	for link, sales in pairs(itemSales) do
		if KelaCompareLink(link, itemLink) then
			-- Found the item, get stats
			-- Loop through the recordes sales
			for _, sale in pairs(sales) do
				-- Get min and max price
				local price = sale.price / sale.quantity
				if (price < stats.Min) then 
					stats.Min = price 
				end
				if (price > stats.Max) then 
					stats.Max = price 
				end

				-- Tally the sale price, quantity, sale count
				stats.Avg = stats.Avg + sale.price
				stats.Quantity = stats.Quantity + sale.quantity
				stats.Sales = stats.Sales + 1
			end

			if stats.Min == math.huge then stats.Min = 0 end

			-- Calculate average price
			if (stats.Quantity > 1) then
				stats.Avg = math.attRound(stats.Avg / stats.Quantity, 2)
			end

			-- Return the data
			if stats.Quantity > 0 then return stats end
			

		end

	end
	return nil
end


function KelaGetATTPriceInfo(itemLink)
	if not ArkadiusTradeTools or not ArkadiusTradeTools.Modules or not ArkadiusTradeTools.Modules.Sales then
		return
	end
	local ArkadiusTradeToolsSales = ArkadiusTradeTools.Modules.Sales

    local seconds_in_day = ZO_ONE_DAY_IN_SECONDS
    local days = KelaGetATTAnalysisPeriod()

    itemLink = ArkadiusTradeToolsSales:NormalizeItemLink(itemLink)
    if itemLink == nil then return end

    local itemSales = ArkadiusTradeToolsSales:GetItemSalesInformation(itemLink, GetTimeStamp() - days * seconds_in_day)
    local itemType = GetItemLinkItemType(itemLink)
	local minPrice = 0
    local maxPrice = 0
	local averagePrice = 0
    local quantity = 0
    local vouchers = 0

	local suggestedPrice = 0
	local suggestedQuantity = 0	
	local valueGroup1 = {}
	local valueGroup2 = {}
	local valueGroup3 = {}
	local valueGroup4 = {}
	local valueGroup5 = {}

	local guildsInfo = {}
	local guildsPrice = {}
	
    for link, sales in pairs(itemSales) do

        if KelaCompareLink(link, itemLink) then
            minPrice = math.huge
            maxPrice = 0
            local price
            for _, sale in pairs(sales) do
                price = sale.price / sale.quantity
                if (price < minPrice) then minPrice = price end
                if ((price > maxPrice) and (price ~= math.huge)) then maxPrice = price end
            end
            --- There are no sales for this item ---
            if (minPrice == math.huge) then minPrice = 0 end
			for _, sale in pairs(sales) do
				averagePrice = averagePrice + sale.price
				quantity = quantity + sale.quantity
			end

			local val1 = minPrice*1.05
			local val2 = maxPrice*0.95
			local range = maxPrice - minPrice
			-- Quartile borders are offsets from the lowest price, not from zero.
			local borderGroup1 = minPrice + range*0.25
			local borderGroup2 = minPrice + range*0.50
			local borderGroup3 = minPrice + range*0.75
			for _, sale in pairs(sales) do
				local salePrice = sale.price/sale.quantity
				if salePrice >= val1 and salePrice < borderGroup1 then
					valueGroup1[#valueGroup1 + 1] = salePrice
				elseif salePrice >= borderGroup1 and salePrice < borderGroup2 then
					valueGroup2[#valueGroup2 + 1] = salePrice
				elseif salePrice >= borderGroup2 and salePrice < borderGroup3 then
					valueGroup3[#valueGroup3 + 1] = salePrice
				elseif salePrice >= borderGroup3 and salePrice <= val2 then
					valueGroup4[#valueGroup4 + 1] = salePrice
				end
			end	
			
			for _, sale in pairs(sales) do
				KelaSetValueIfNil(guildsInfo, sale.guildName, 0)
				guildsInfo[sale.guildName] = guildsInfo[sale.guildName] + sale.quantity --1
			end	
			for _, sale in pairs(sales) do
				local salePrice = sale.price --/sale.quantity
				KelaSetValueIfNil(guildsPrice, sale.guildName, 0)
				guildsPrice[sale.guildName] = guildsPrice[sale.guildName] + salePrice
			end	

        end

		for guildName, countSales in pairs(guildsInfo) do
			if (countSales > 0) then
				guildsPrice[guildName] = math.attRound(guildsPrice[guildName] / countSales, 2)
			else
				guildsPrice[guildName] = 0
			end
		end

        if (quantity > 0) then
            averagePrice = math.attRound(averagePrice / quantity, 2)
        else
            averagePrice = 0
        end

		local selectedSales = valueGroup1
		if #selectedSales < #valueGroup2 then selectedSales = valueGroup2 end
		if #selectedSales < #valueGroup3 then selectedSales = valueGroup3 end
		if #selectedSales < #valueGroup4 then selectedSales = valueGroup4 end
		if #selectedSales >= 3 then
			for _, price in ipairs(selectedSales) do
				suggestedPrice = suggestedPrice + price
				suggestedQuantity = suggestedQuantity + 1
			end
		end
        if (suggestedQuantity > 0) then
            suggestedPrice = math.attRound(suggestedPrice / suggestedQuantity, 2)
        else
            suggestedPrice = 0
        end

        if KelaCompareLink(link, itemLink) then
            if (quantity > 0) then
                if (itemType == ITEMTYPE_MASTER_WRIT) then
                    vouchers = ArkadiusTradeToolsSales:GetVoucherCount(itemLink)
                end
				return minPrice, maxPrice, averagePrice, suggestedPrice, vouchers, #sales, quantity, guildsInfo, guildsPrice
            end
			
        end
    end
end

function KelaGetCurrentATTCraftingInfo(itemLink)
	if not ArkadiusTradeTools or not ArkadiusTradeTools.Modules or not ArkadiusTradeTools.Modules.Sales then
		return false
	end

	local ArkadiusTradeToolsSales = ArkadiusTradeTools.Modules.Sales
    local seconds_in_day = ZO_ONE_DAY_IN_SECONDS
    local days = KelaGetATTAnalysisPeriod()
    local itemType = GetItemLinkItemType(itemLink)

	local fromTimeStamp = GetTimeStamp() - days * seconds_in_day

	local craftingComponentPrices = {}	


	if itemType == ITEMTYPE_MASTER_WRIT then
		craftingComponentPrices = ArkadiusTradeToolsSales:GetCrafingComponentPrices(itemLink, fromTimeStamp)
		if #craftingComponentPrices > 0 then
			return true, craftingComponentPrices
		end
	elseif itemType == ITEMTYPE_RECIPE then
		local numIngredients = GetItemLinkRecipeNumIngredients(itemLink)
	    local components = {}
		local component
		if(numIngredients > 0) then
			for i = 1, numIngredients do
				local ingredientLink = GetItemLinkRecipeIngredientItemLink(itemLink, i)
				local _, _, ingredientQuantity = GetItemLinkRecipeIngredientInfo(itemLink, i)
				component = { itemLink = ingredientLink, quantity = ingredientQuantity }
				table.insert(components, component)
			end
		end	
		for i = 1, #components do
			if ((components[i].itemLink == nil) or (components[i].quantity == nil)) then
				return false
			end
		end
		for i = 1, #components do
			local component = components[i]
			component.price = ArkadiusTradeToolsSales:GetAveragePricePerItem(component.itemLink, fromTimeStamp)
		end
		if #components > 0 then
			return true, components
		end
		
	end	
	
	return false

end

function KelaUpdateATTGraph(itemLink, graphControl, priceInfoATTSuggestedPrice, priceInfoTTCSuggestedPrice)
	if not ArkadiusTradeTools or not ArkadiusTradeTools.Modules or not ArkadiusTradeTools.Modules.Sales or not graphControl.object then
		graphControl:SetHidden(true)
		return
	end
	local ArkadiusTradeToolsSales = ArkadiusTradeTools.Modules.Sales
	local L = ArkadiusTradeToolsSales.Localization
	local attRound = math.attRound
    local seconds_in_day = ZO_ONE_DAY_IN_SECONDS
    local days = KelaGetATTAnalysisPeriod()
    itemLink = ArkadiusTradeToolsSales:NormalizeItemLink(itemLink)
    if itemLink == nil then return end

    local itemSales = ArkadiusTradeToolsSales:GetItemSalesInformation(itemLink, GetTimeStamp() - days * seconds_in_day)
    local averagePrice = 0
    local quantity
    local guildColors = {}

    graphControl.object:Clear()

    for link, sales in pairs(itemSales) do
        averagePrice = 0
        quantity = 0

        if KelaCompareLink(link, itemLink) then
            local minPrice = math.huge
            local maxPrice = 0
            local price

            for _, sale in pairs(sales) do
                price = sale.price / sale.quantity

                if (price < minPrice) then minPrice = price end
                if ((price > maxPrice) and (price ~= math.huge)) then maxPrice = price end
            end

            --- There are no sales for this item ---
            if (minPrice == math.huge) then
                minPrice = 0
            end


			-- Widen the range to include the TTC suggested price; 0 means TTC has no
			-- data for the item (or is not installed) and must not stretch the axis.
			if priceInfoTTCSuggestedPrice and priceInfoTTCSuggestedPrice > 0 then
				minPrice = math.min(minPrice, priceInfoTTCSuggestedPrice)
				maxPrice = math.max(maxPrice, priceInfoTTCSuggestedPrice)
			end


			graphControl.object:SetRange(GetTimeStamp() - days * seconds_in_day, GetTimeStamp(), minPrice, maxPrice)
			graphControl.object:SetXLabels(-days .. " " .. L["ATT_STR_DAYS"], -days / 2 .. " " .. L["ATT_STR_DAYS"], L["ATT_STR_NOW"])
			graphControl.object:SetYLabels(ArkadiusTradeTools:LocalizeDezimalNumber(attRound(maxPrice, 2)) .. " |t16:16:EsoUI/Art/currency/currency_gold.dds|t", "", ArkadiusTradeTools:LocalizeDezimalNumber(attRound(minPrice, 2)) .. " |t16:16:EsoUI/Art/currency/currency_gold.dds|t")
        end

        for _, sale in pairs(sales) do
            averagePrice = averagePrice + sale.price
            quantity = quantity + sale.quantity
            if KelaCompareLink(link, itemLink) then
                if (not guildColors[sale.guildName]) then
                    guildColors[sale.guildName] = ArkadiusTradeTools:GetGuildColor(sale.guildName)
                end

                graphControl.object:AddDot(sale.timeStamp, sale.price / sale.quantity, guildColors[sale.guildName])
            end
        end

		if priceInfoATTSuggestedPrice and priceInfoATTSuggestedPrice ~= 0 then
			graphControl.object:AddDot(GetTimeStamp(), priceInfoATTSuggestedPrice, colors.COLOR_ATT)
		end
		
		if priceInfoTTCSuggestedPrice and priceInfoTTCSuggestedPrice ~= 0 then
			graphControl.object:AddDot(GetTimeStamp(), priceInfoTTCSuggestedPrice, colors.COLOR_TTC)
		end		


    end

end

function KelaGetEffectOfDeal (priceInfoTTC, priceInfoATT, data, action, stackCount)
	
	local purchasePrice, suggestedATT, suggestedTCC

	if not stackCount then
		stackCount = 1
		if data then stackCount = data.stackCount end
	end

	if data then purchasePrice = data.purchasePrice or data.stackSellPrice end
	
	local multiplier = 1
	local IsMasterWrit = priceInfoATT and (priceInfoATT.Vouchers ~= 0)
	local colorEffectDeal
	local valueEffectDeal				
	local effectOfDeal
	local compareValuePrice
	local compareValueSuffix	
	
	if IsMasterWrit then
		multiplier = priceInfoATT.Vouchers
	end

	if priceInfoATT and priceInfoATT.SuggestedPrice then 
		suggestedATT = math.floor(priceInfoATT.SuggestedPrice)
	else
		suggestedATT = 0
	end
	if priceInfoTTC.SuggestedPrice then 
		suggestedTCC = math.floor(priceInfoTTC.SuggestedPrice)
	else
		suggestedTCC = 0
	end
	local priceInfoMM = priceInfoTTC.Providers and priceInfoTTC.Providers.MM
	local suggestedMM = priceInfoMM and priceInfoMM.SuggestedPrice and math.floor(priceInfoMM.SuggestedPrice) or 0

	local suggestedATTStack = suggestedATT*stackCount
	local suggestedTCCStack = suggestedTCC*stackCount
	local suggestedMMStack = suggestedMM*stackCount
	local suggestedATTWrit = suggestedATT*multiplier
	local suggestedTCCWrit = suggestedTCC*multiplier
	local suggestedMMWrit = suggestedMM*multiplier

	-- The recommended price: the one provider with a price, or the average of
	-- those that have one, with the source it came from.
	local function Combine(ttc, att, mm)
		local sum, count, only, onlyColor = 0, 0, nil, nil
		for _, entry in ipairs({ { ttc, "TTC", colors.COLOR_TTC }, { att, "ATT", colors.COLOR_ATT }, { mm, "MM", colors.COLOR_MM } }) do
			if entry[1] ~= 0 then
				sum = sum + entry[1]
				count = count + 1
				only, onlyColor = entry[2], entry[3]
			end
		end
		if count == 0 then
			return 0
		elseif count > 1 then
			return sum / count, colors.COLOR_WHITE:Colorize(" (AVG)")
		end
		return sum, onlyColor:Colorize(" ("..only..")")
	end
	local suggestedAVG = Combine(suggestedTCC, suggestedATT, suggestedMM)
	local suggestedAVGStack, stackSuffix = Combine(suggestedTCCStack, suggestedATTStack, suggestedMMStack)
	local suggestedAVGWrit, writSuffix = Combine(suggestedTCCWrit, suggestedATTWrit, suggestedMMWrit)

	if IsMasterWrit then
		compareValuePrice, compareValueSuffix = suggestedAVGWrit, writSuffix
	elseif stackCount ~= 0 then
		compareValuePrice, compareValueSuffix = suggestedAVGStack, stackSuffix
	else
		compareValuePrice = 0
	end
	if compareValuePrice == 0 then compareValueSuffix = nil end
	if action then
		if action == "GAMEPAD_TRADING_HOUSE_LISTINGS" then
			colorEffectDeal = colors.COLOR_GREY
			valueEffectDeal = 0
			if compareValuePrice == 0 then 
				valueEffectDeal = "-"
			elseif compareValuePrice > purchasePrice*1.5 then 
				valueEffectDeal = 2
				colorEffectDeal = colors.COLOR_DEALBAD
			elseif compareValuePrice > purchasePrice*1.1 then 
				valueEffectDeal = 4
				colorEffectDeal = colors.COLOR_DEALGOOD
			elseif compareValuePrice > purchasePrice*0.9 then 
				valueEffectDeal = 5
				colorEffectDeal = colors.COLOR_DEALGREAT
			elseif compareValuePrice > purchasePrice*0.5 then 
				valueEffectDeal = 3
				colorEffectDeal = colors.COLOR_DEALNORMAL
			elseif compareValuePrice > 0 then 
				valueEffectDeal = 1
				colorEffectDeal = colors.COLOR_DEALTERRIBLE
			end
		end
		if action == "GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS" then
			colorEffectDeal = colors.COLOR_GREY
			valueEffectDeal = 0
			if compareValuePrice == 0 then 
				valueEffectDeal = "-"
				effectOfDeal = colors.COLOR_GREY:Colorize(GetString("KELA_TRADING_RESUMEPRICEDIALOG", 0))
			elseif compareValuePrice > purchasePrice*1.5 then 
				valueEffectDeal = 5
				colorEffectDeal = colors.COLOR_DEALGREAT
			elseif compareValuePrice > purchasePrice*1.1 then 
				valueEffectDeal = 4
				colorEffectDeal = colors.COLOR_DEALGOOD
			elseif compareValuePrice > purchasePrice*0.9 then 
				valueEffectDeal = 3
				colorEffectDeal = colors.COLOR_DEALNORMAL
			elseif compareValuePrice > purchasePrice*0.5 then 
				valueEffectDeal = 2
				colorEffectDeal = colors.COLOR_DEALBAD
			elseif compareValuePrice > 0 then 
				valueEffectDeal = 1
				colorEffectDeal = colors.COLOR_DEALTERRIBLE
			end
		
			if not effectOfDeal then effectOfDeal = colorEffectDeal:Colorize(GetString("KELA_TRADING_RESUMEPRICEDIALOG", valueEffectDeal))..compareValueSuffix end
		
		end
	end


	return valueEffectDeal, effectOfDeal, colorEffectDeal, suggestedTCC, suggestedATT, suggestedAVG, suggestedTCCStack, suggestedATTStack, suggestedAVGStack, suggestedTCCWrit, suggestedATTWrit, suggestedAVGWrit, compareValuePrice, compareValueSuffix, suggestedMM, suggestedMMStack, suggestedMMWrit

end

-- Rating from where the unit price sits in the provider's min/avg/max range;
-- used when there is no suggested price to compare against.
local function KelaRateAgainstRange(itemData, priceInfo)
	local result = 0
	local colorPrice = colors.COLOR_WHITE
	if priceInfo then
		local avgPrice = priceInfo.Avg
		local minPrice = priceInfo.Min
		local maxPrice = priceInfo.Max
		local unitPrice = itemData.purchasePricePerUnit
		if avgPrice ~= 0 and unitPrice ~= avgPrice then
			if unitPrice <= minPrice + (avgPrice-minPrice)*0.1 then
				result, colorPrice = 5, colors.COLOR_DEALGREAT
			elseif unitPrice <= minPrice + (avgPrice-minPrice)*0.7 then
				result, colorPrice = 4, colors.COLOR_DEALGOOD
			elseif unitPrice <= avgPrice + (maxPrice-avgPrice)*0.3 then
				result, colorPrice = 3, colors.COLOR_DEALNORMAL
			elseif unitPrice <= avgPrice + (maxPrice-avgPrice)*0.7 then
				result, colorPrice = 2, colors.COLOR_DEALBAD
			else
				result, colorPrice = 1, colors.COLOR_DEALTERRIBLE
			end
		end
	end
	return result, colorPrice
end

-- Price lookups for guild-store search results. One page can list the same
-- item many times, and the filter, row setup and row recycling all need the
-- price, so lookups are cached by link until the results screen shows again.
local searchPriceCache = {}
local searchPriceCacheSize = 0
local SEARCH_PRICE_CACHE_LIMIT = 1000

function KelaClearSearchPriceCache()
	searchPriceCache = {}
	searchPriceCacheSize = 0
end

-- Deal rating (0-5) and price colour for a search result, computed once per
-- item data. Falls back to the provider's price range when no suggested price
-- exists, as the filter and the row colour always did.
function KelaGetSearchItemDeal(itemData)
	if itemData.kelaDealValue == nil then
		local link = itemData.itemLink
		local prices = searchPriceCache[link]
		if not prices then
			if searchPriceCacheSize >= SEARCH_PRICE_CACHE_LIMIT then
				KelaClearSearchPriceCache()
			end
			prices = { KelaGetPriceInfoTTCATT(link) }
			searchPriceCache[link] = prices
			searchPriceCacheSize = searchPriceCacheSize + 1
		end
		local trueTTC, trueATT, priceInfoTTC, priceInfoATT = prices[1], prices[2], prices[3], prices[4]
		local value, _, color = KelaGetEffectOfDeal(priceInfoTTC, priceInfoATT, itemData, "GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS")
		if value == "-" then
			value, color = KelaRateAgainstRange(itemData, (trueTTC and priceInfoTTC) or (trueATT and priceInfoATT))
		end
		itemData.kelaDealValue = value
		itemData.kelaDealColor = color or colors.COLOR_WHITE
	end
	return itemData.kelaDealValue, itemData.kelaDealColor
end

function KelaGetPriceInfoTTCATT (itemLink)

	local ttcAvailable = TamrielTradeCentre ~= nil and TamrielTradeCentrePrice ~= nil
	local attAvailable = ArkadiusTradeTools ~= nil and ArkadiusTradeTools.Modules ~= nil and ArkadiusTradeTools.Modules.Sales ~= nil
	local priceInfoTTC = {
		Available = ttcAvailable,
		Avg = 0,
		Max = 0,
		Min = 0,
		EntryCount = 0,
		AmountCount = 0,
		SuggestedPrice = 0,
	}
	local priceInfoATT = {
		Available = attAvailable,
		Avg = 0,
		Max = 0,
		Min = 0,
		EntryCount = 0,
		AmountCount = 0,
		SuggestedPrice = 0,
		Vouchers = 0,
		GuildsInfo = {},
		GuildsPrice = {},
	}
	local trueTTC = false
	local trueATT = false

	if ttcAvailable then
		local price = TamrielTradeCentrePrice:GetPriceInfo(itemLink)
		if price then
			priceInfoTTC.Avg = price.Avg or 0
			priceInfoTTC.Max = price.Max or 0
			priceInfoTTC.Min = price.Min or 0
			priceInfoTTC.EntryCount = price.EntryCount or 0
			priceInfoTTC.AmountCount = price.AmountCount or 0
			priceInfoTTC.SuggestedPrice = price.SuggestedPrice or 0
			trueTTC = true
		end
	end
	if attAvailable then
		local minPrice, maxPrice, averagePrice, suggestedPrice, vouchers, sales, quantity, guildsInfo, guildsPrice = KelaGetATTPriceInfo(itemLink)
		if quantity then
			priceInfoATT.Avg = averagePrice
			priceInfoATT.Max = maxPrice
			priceInfoATT.Min = minPrice
			priceInfoATT.EntryCount = sales
			priceInfoATT.AmountCount = quantity
			priceInfoATT.SuggestedPrice = suggestedPrice
			priceInfoATT.Vouchers = vouchers
			priceInfoATT.GuildsInfo = guildsInfo or {}
			priceInfoATT.GuildsPrice = guildsPrice or {}
			trueATT = true
		end
	end
	-- Master Merchant rides on both tables as .Providers.MM, so the many callers
	-- that pass TTC and ATT along need no extra argument.
	local mmStats = GetMasterMerchantStats(itemLink)
	local priceInfoMM =
	{
		Available = MasterMerchant ~= nil,
		Has = mmStats ~= nil,
		Avg = mmStats and mmStats.avgPrice or 0,
		Max = mmStats and mmStats.high or 0,
		Min = mmStats and mmStats.low or 0,
		EntryCount = mmStats and mmStats.numSales or 0,
		AmountCount = mmStats and mmStats.numItems or 0,
		SuggestedPrice = mmStats and mmStats.avgPrice or 0,
	}
	local providers = { MM = priceInfoMM }
	priceInfoTTC.Providers = providers
	priceInfoATT.Providers = providers
	return trueTTC, trueATT, priceInfoTTC, priceInfoATT, trueTTC or trueATT or priceInfoMM.Has
end

-- Deal rating for the trading-house browse and listings scenes as a colored
-- value plus its price source (for example "Good (AVG)"), or nil where no
-- rating applies.
function KelaGetDealRatingText(priceInfoTTC, priceInfoATT, selectedData, currentScene, stackCount)
	if not selectedData or (currentScene ~= "GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS" and currentScene ~= "GAMEPAD_TRADING_HOUSE_LISTINGS") then
		return nil
	end
	local results = { KelaGetEffectOfDeal(priceInfoTTC, priceInfoATT, selectedData, currentScene, stackCount or 1) }
	local valueEffectDeal, colorEffectDeal, compareValueSuffix = results[1], results[3], results[14]
	if type(valueEffectDeal) == "number" and valueEffectDeal > 0 then
		return colorEffectDeal:Colorize(GetString("KELA_TRADING_DEALRATING", valueEffectDeal)) .. (compareValueSuffix or "")
	elseif valueEffectDeal then
		return kpuiConst.Colors.COLOR_GREY:Colorize(GetString("KELA_TRADING_DEALRATING", 0))
	end
end
