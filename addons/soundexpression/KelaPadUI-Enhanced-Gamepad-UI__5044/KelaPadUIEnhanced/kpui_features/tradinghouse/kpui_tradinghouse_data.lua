-- KelaPadUI TTC/ATT trading-data helpers.

local KPUI_TRADINGHOUSE = KPUI_TRADINGHOUSE
local colors = KPUI_TRADINGHOUSE.colors
local KelaGetATTSalesSecondsPerDay = KPUI_TRADINGHOUSE.KelaGetATTSalesSecondsPerDay
local KelaCreateColorizedResumePrice = KPUI_TRADINGHOUSE.KelaCreateColorizedResumePrice
local GetItemLinks = KPUI_TRADINGHOUSE.GetItemLinks
local GetBuyInfo = KPUI_TRADINGHOUSE.GetBuyInfo
local HideTradingTooltipControls = KPUI_TRADINGHOUSE.HideTradingTooltipControls
local HideImprovementTooltipControls = KPUI_TRADINGHOUSE.HideImprovementTooltipControls
local HideProvisionerTooltipControls = KPUI_TRADINGHOUSE.HideProvisionerTooltipControls
local HideCreationTooltipControls = KPUI_TRADINGHOUSE.HideCreationTooltipControls
local HideAlchemyTooltipControls = KPUI_TRADINGHOUSE.HideAlchemyTooltipControls
local HideEnchantingTooltipControls = KPUI_TRADINGHOUSE.HideEnchantingTooltipControls
local ResetProvisionerTradingTooltip = KPUI_TRADINGHOUSE.ResetProvisionerTradingTooltip
local ResetCreationTradingTooltip = KPUI_TRADINGHOUSE.ResetCreationTradingTooltip
local AddClearLine = KPUI_TRADINGHOUSE.AddClearLine
local SetSmithTradingInfo = KPUI_TRADINGHOUSE.SetSmithTradingInfo
local SetSmithGraph = KPUI_TRADINGHOUSE.SetSmithGraph
local SetSmithNotes = KPUI_TRADINGHOUSE.SetSmithNotes
local SetSmithListings = KPUI_TRADINGHOUSE.SetSmithListings
local SetSmithQualityPrices = KPUI_TRADINGHOUSE.SetSmithQualityPrices
local SetProductionPrices = KPUI_TRADINGHOUSE.SetProductionPrices
local SetCraftingComponents = KPUI_TRADINGHOUSE.SetCraftingComponents
local IsKPUITradingHouseSettingEnabled = KPUI_TRADINGHOUSE.IsKPUITradingHouseSettingEnabled

function GetATTPriceStats(itemLink)
	if not ArkadiusTradeTools or not ArkadiusTradeTools.Modules or not ArkadiusTradeTools.Modules.Sales then
		return nil
	end
	
	local ArkadiusTradeToolsSales = ArkadiusTradeTools.Modules.Sales
    local seconds_in_day = KelaGetATTSalesSecondsPerDay(ArkadiusTradeToolsSales)
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

    local seconds_in_day = KelaGetATTSalesSecondsPerDay(ArkadiusTradeToolsSales)
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
			local borderGroup1 = range*0.25
			local borderGroup2 = range*0.50
			local borderGroup3 = range*0.75
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
    local seconds_in_day = KelaGetATTSalesSecondsPerDay(ArkadiusTradeToolsSales)
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
    local seconds_in_day = KelaGetATTSalesSecondsPerDay(ArkadiusTradeToolsSales)
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


			if priceInfoTTCSuggestedPrice then
				if priceInfoTTCSuggestedPrice < minPrice then minPrice = priceInfoTTCSuggestedPrice - minPrice end
				if priceInfoTTCSuggestedPrice > maxPrice then maxPrice = priceInfoTTCSuggestedPrice + maxPrice end
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


	return valueEffectDeal, effectOfDeal, colorEffectDeal, suggestedTCC, suggestedATT, suggestedAVG, suggestedTCCStack, suggestedATTStack, suggestedAVGStack, suggestedTCCWrit, suggestedATTWrit, suggestedAVGWrit, compareValuePrice

end

function KelaGetEffectIfUndefined(itemData)
	local trueTTC, trueATT, priceInfoTTC, priceInfoATT = KelaGetPriceInfoTTCATT(itemData.itemLink)
	local priceInfo = (trueTTC and priceInfoTTC) or (trueATT and priceInfoATT)
	local result = 0
	local colorPrice = colors.COLOR_WHITE
	if priceInfo then
		local avgPrice = priceInfo.Avg
		local minPrice = priceInfo.Min
		local maxPrice = priceInfo.Max
		if avgPrice ~= 0 and itemData.purchasePricePerUnit ~= avgPrice then
			if itemData.purchasePricePerUnit <= minPrice + (avgPrice-minPrice)*0.1 then
				result = 5
				colorPrice = colors.COLOR_DEALGREAT
			elseif itemData.purchasePricePerUnit <= minPrice + (avgPrice-minPrice)*0.7 then
				result = 4
				colorPrice = colors.COLOR_DEALGOOD
			elseif itemData.purchasePricePerUnit <= avgPrice + (maxPrice-avgPrice)*0.3 then
				result = 3
				colorPrice = colors.COLOR_DEALNORMAL
			elseif itemData.purchasePricePerUnit <= avgPrice + (maxPrice-avgPrice)*0.7 then
				result = 2
				colorPrice = colors.COLOR_DEALBAD
			elseif itemData.purchasePricePerUnit >= avgPrice + (maxPrice-avgPrice)*0.7 then
				result = 1
				colorPrice = colors.COLOR_DEALTERRIBLE
			end
		end
	end
	return result, colorPrice
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
