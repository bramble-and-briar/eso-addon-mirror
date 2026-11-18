-- KelaPadUI TTC/ATT trading-data helpers.

local KPUI_TRADINGHOUSE = KPUI_TRADINGHOUSE
local colors = KPUI_TRADINGHOUSE.colors

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
	local suggestedAVG
	local suggestedATTStack
	local suggestedTCCStack
	local suggestedAVGStack
	local suggestedATTWrit
	local suggestedTCCWrit
	local suggestedAVGWrit

	suggestedATTStack = suggestedATT*stackCount
	suggestedATTWrit = suggestedATT*multiplier
	suggestedTCCStack = suggestedTCC*stackCount
	suggestedTCCWrit = suggestedTCC*multiplier

	local bothProviders = priceInfoTTC.Available and priceInfoATT.Available
	local useAverage = bothProviders and suggestedATT ~= 0 and suggestedTCC ~= 0
	local useAverageStack = bothProviders and suggestedATTStack ~= 0 and suggestedTCCStack ~= 0
	local useAverageWrit = bothProviders and suggestedATTWrit ~= 0 and suggestedTCCWrit ~= 0

	if useAverage then
		suggestedAVG = (suggestedATT + suggestedTCC)/2
	elseif suggestedTCC ~= 0 then
		suggestedAVG = suggestedTCC
	else
		suggestedAVG = suggestedATT
	end
	if useAverageStack then
		suggestedAVGStack = (suggestedATTStack + suggestedTCCStack)/2
	elseif suggestedTCCStack ~= 0 then
		suggestedAVGStack = suggestedTCCStack
	else
		suggestedAVGStack = suggestedATTStack
	end
	if useAverageWrit then
		suggestedAVGWrit = (suggestedATTWrit + suggestedTCCWrit)/2
	elseif suggestedTCCWrit ~= 0 then
		suggestedAVGWrit = suggestedTCCWrit
	else
		suggestedAVGWrit = suggestedATTWrit
	end
	
	if IsMasterWrit then
		if useAverageWrit then
			compareValuePrice = suggestedAVGWrit
			compareValueSuffix = colors.COLOR_WHITE:Colorize(" (AVG)")
		elseif suggestedTCCWrit ~= 0 then
			compareValuePrice = suggestedTCCWrit
			compareValueSuffix = colors.COLOR_TTC:Colorize(" (TTC)")
		elseif suggestedATTWrit ~= 0 then
			compareValuePrice = suggestedATTWrit
			compareValueSuffix = colors.COLOR_ATT:Colorize(" (ATT)")
		else
			compareValuePrice = 0
		end
	elseif stackCount ~= 0 then
		if useAverageStack then
			compareValuePrice = suggestedAVGStack
			compareValueSuffix = colors.COLOR_WHITE:Colorize(" (AVG)")
		elseif suggestedTCCStack ~= 0 then
			compareValuePrice = suggestedTCCStack
			compareValueSuffix = colors.COLOR_TTC:Colorize(" (TTC)")
		elseif suggestedATTStack ~= 0 then
			compareValuePrice = suggestedATTStack
			compareValueSuffix = colors.COLOR_ATT:Colorize(" (ATT)")
		else
			compareValuePrice = 0
		end
	else
		compareValuePrice = 0
	end
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


	return valueEffectDeal, effectOfDeal, colorEffectDeal, suggestedTCC, suggestedATT, suggestedAVG, suggestedTCCStack, suggestedATTStack, suggestedAVGStack, suggestedTCCWrit, suggestedATTWrit, suggestedAVGWrit, compareValuePrice, compareValueSuffix

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
	return trueTTC, trueATT, priceInfoTTC, priceInfoATT
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
