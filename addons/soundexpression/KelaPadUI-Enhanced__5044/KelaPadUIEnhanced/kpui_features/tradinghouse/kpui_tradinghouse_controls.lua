-- KelaPadUI custom trading-house tooltip controls (KPUI_* templates).

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

function KPUI_ItemTypeGuildStat_OnInitialize(control)
	local rows = {}
	control.SetItemTypeGuildStat = function(itemLink, itemTradeCategory, lastControl)
		
		control:GetNamedChild("Header"):SetHidden(false)
		control:GetNamedChild("Header"):ClearAnchors()
		control:GetNamedChild("Header"):SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT, 0, 0)
		control:GetNamedChild("Header"):SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT, 0, 0)
		control:GetNamedChild("Header"):GetNamedChild("StatGuild"):SetText(GetString(KELA_TRADING_TRADING_GUILD))
		control:GetNamedChild("Header"):GetNamedChild("QuantityGuild"):SetText(GetString(KELA_TRADING_TRADING_QUANTITY))
		control:GetNamedChild("Header"):GetNamedChild("PriceGuild"):SetText(GetString(KELA_TRADING_PRICE_TITLE))
		control:GetNamedChild("Header"):GetNamedChild("ValueGuild"):SetText(GetString(KELA_TRADING_TRADING_PROFIT_COEF))
		lastControl = control:GetNamedChild("Header")
		lastControl = lastControl:GetNamedChild("Divider")
		local tblItemCategorySales = {}
		
		for guildName, value in pairs (KELA_ATT_GUILD_STAT[itemTradeCategory]) do
			local K = 1 - (100/(value["price"]/value["quantity"]))
			KelaSetValueIfNil(tblItemCategorySales, K, {})
			KelaSetValueIfNil(tblItemCategorySales[K], "guildName", guildName)
			KelaSetValueIfNil(tblItemCategorySales[K], "price", value["price"])
			KelaSetValueIfNil(tblItemCategorySales[K], "quantity", value["quantity"])
		end

		for _, row in pairs(rows) do
			row:SetHidden(true)
		end
		rows = {}

		local count = 0
		for key, value in spairs (tblItemCategorySales, function (t, a, b) return (a > b) end) do
			local K = KelaLocalizedFormatNumber(key, 3)
			count = count + 1
			local color = ArkadiusTradeTools:GetGuildColor(value["guildName"])
			local row = GetControl(control:GetName().."row"..count)
			if not row then row = CreateControlFromVirtual("$(parent)row", control, "KPUI_ItemTypeGuildStatRow", count) end	
			rows[#rows + 1] = row
			row:ClearAnchors()
			row:SetHidden(false)
			row:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT)
			row:SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT)
			row:GetNamedChild("StatGuild"):SetText(color:Colorize(value["guildName"]))
			row:GetNamedChild("QuantityGuild"):SetText(value["quantity"])
			row:GetNamedChild("PriceGuild"):SetText(value["price"])
			row:GetNamedChild("ValueGuild"):SetText(K)
			lastControl = row
		end					
		control:GetNamedChild("Footer"):ClearAnchors()
		control:GetNamedChild("Footer"):SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT)
		control:GetNamedChild("Footer"):SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT)
		return control:GetNamedChild("Footer")
	end
end

function KPUI_MainInfo_OnInitialize(control)
	control.SetItemInfo = function(priceInfoTTC, priceInfoATT, currentScene, selectedData, stackCount)
		local colors = kpuiConst.Colors
		
		if not stackCount then
			stackCount = 1
			if selectedData then stackCount = selectedData.stackCount end
		end

		local function formatProvider(priceInfo, value)
			if priceInfo and priceInfo.Available then
				return KelaLocalizedFormatNumber(value)
			end
			return "N/A"
		end
							
		local lastControl
		local strAmountCount = GetString(KELA_TRADING_AMOUNTCOUNT)
		local strAvgPrice = GetString(KELA_TRADING_AVGPRICE)
		local multiplier = 1
		local IsMasterWrit = false
		
		control:GetNamedChild("Header"):GetNamedChild("Stat"):SetText(GetString(KELA_TRADING_INDICATOR_SALES_OFFERS))
		control:GetNamedChild("Header"):GetNamedChild("ATT"):SetText(colors.COLOR_ATT:Colorize("ATT"))
		control:GetNamedChild("Header"):GetNamedChild("TTC"):SetText(colors.COLOR_TTC:Colorize("TTC"))
		lastControl = control:GetNamedChild("Header")

		IsMasterWrit = (priceInfoATT.Vouchers ~= 0)
		
		local rowEntryCount = GetControl(control:GetName().."rowEntryCount")
		if stackCount > 1 or IsMasterWrit then
			if not rowEntryCount then rowEntryCount = CreateControlFromVirtual("$(parent)rowEntryCount", control, "KPUI_MainRow") end
			rowEntryCount:ClearAnchors()
			rowEntryCount:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT)
			rowEntryCount:GetNamedChild("Stat"):SetText(GetString(KELA_TRADING_ENTRYCOUNT))
			rowEntryCount:GetNamedChild("ATT"):SetText(formatProvider(priceInfoATT, priceInfoATT.EntryCount))
			rowEntryCount:GetNamedChild("TTC"):SetText(formatProvider(priceInfoTTC, priceInfoTTC.EntryCount))
			rowEntryCount:SetHidden(false)
			lastControl = rowEntryCount
		else
			if rowEntryCount then rowEntryCount:SetHidden(true) end
		end

		if IsMasterWrit then
			multiplier = priceInfoATT.Vouchers
			strAmountCount = GetString(KELA_TRADING_VOUCHERSCOUNT)
			strAvgPrice = GetString(KELA_TRADING_AVGPRICE_MASTERWRIT)
		else
			multiplier = 1					
			strAmountCount = GetString(KELA_TRADING_AMOUNTCOUNT)
			strAvgPrice = GetString(KELA_TRADING_AVGPRICE)
		end
		local rowAmountCount = GetControl(control:GetName().."rowAmountCount")
		if not rowAmountCount then rowAmountCount = CreateControlFromVirtual("$(parent)rowAmountCount", control, "KPUI_MainRow") end
		rowAmountCount:ClearAnchors()
		rowAmountCount:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT)
		rowAmountCount:GetNamedChild("Stat"):SetText(strAmountCount)
		rowAmountCount:GetNamedChild("ATT"):SetText(formatProvider(priceInfoATT, priceInfoATT.AmountCount))
		rowAmountCount:GetNamedChild("TTC"):SetText(formatProvider(priceInfoTTC, priceInfoTTC.AmountCount))
		lastControl = rowAmountCount
		
		local rowMin = GetControl(control:GetName().."rowMin")
		if not rowMin then rowMin = CreateControlFromVirtual("$(parent)rowMin", control, "KPUI_MainRow") end
		rowMin:ClearAnchors()
		rowMin:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT)
		rowMin:GetNamedChild("Stat"):SetText(GetString(KELA_TRADING_MINPRICE))
		rowMin:GetNamedChild("ATT"):SetText(formatProvider(priceInfoATT, priceInfoATT.Min))
		rowMin:GetNamedChild("TTC"):SetText(formatProvider(priceInfoTTC, priceInfoTTC.Min))
		lastControl = rowMin
		
		local rowMax = GetControl(control:GetName().."rowMax")
		if not rowMax then rowMax = CreateControlFromVirtual("$(parent)rowMax", control, "KPUI_MainRow") end
		rowMax:ClearAnchors()
		rowMax:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT)
		rowMax:GetNamedChild("Stat"):SetText(GetString(KELA_TRADING_MAXPRICE))
		rowMax:GetNamedChild("ATT"):SetText(formatProvider(priceInfoATT, priceInfoATT.Max))
		rowMax:GetNamedChild("TTC"):SetText(formatProvider(priceInfoTTC, priceInfoTTC.Max))
		lastControl = rowMax
		
		local rowVoucherPrice = GetControl(control:GetName().."rowVoucherPrice")
		if IsMasterWrit then
			if not rowVoucherPrice then rowVoucherPrice = CreateControlFromVirtual("$(parent)rowVoucherPrice", control, "KPUI_MainRow") end
			rowVoucherPrice:ClearAnchors()
			rowVoucherPrice:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT)
			rowVoucherPrice:GetNamedChild("Stat"):SetText(GetString(KELA_TRADING_VOUCHERPRICE))
			rowVoucherPrice:GetNamedChild("ATT"):SetText(formatProvider(priceInfoATT, priceInfoATT.Avg))
			rowVoucherPrice:GetNamedChild("TTC"):SetText("N/A")
			rowVoucherPrice:SetHidden(false)
			lastControl = rowVoucherPrice
		else
			if rowVoucherPrice then rowVoucherPrice:SetHidden(true) end
		end

		local rowAvg = GetControl(control:GetName().."rowAvg")
		if not rowAvg then rowAvg = CreateControlFromVirtual("$(parent)rowAvg", control, "KPUI_MainRow") end
		rowAvg:ClearAnchors()
		rowAvg:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT)
		rowAvg:GetNamedChild("Stat"):SetText(strAvgPrice)
		rowAvg:GetNamedChild("ATT"):SetText(formatProvider(priceInfoATT, priceInfoATT.Avg * multiplier))
		rowAvg:GetNamedChild("TTC"):SetText(formatProvider(priceInfoTTC, priceInfoTTC.Avg))
		lastControl = rowAvg

		local valueEffectDeal, effectOfDeal, colorEffectDeal, suggestedTTC, suggestedATT, suggestedAVG, suggestedTTCStack, suggestedATTStack, suggestedAVGStack, suggestedTTCWrit, suggestedATTWrit, suggestedAVGWrit 
		
		if selectedData and (currentScene == "GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS" or currentScene == "GAMEPAD_TRADING_HOUSE_LISTINGS") then
			valueEffectDeal, effectOfDeal, colorEffectDeal, suggestedTTC, suggestedATT, suggestedAVG, suggestedTTCStack, suggestedATTStack, suggestedAVGStack, suggestedTTCWrit, suggestedATTWrit, suggestedAVGWrit = KelaGetEffectOfDeal (priceInfoTTC, priceInfoATT, selectedData, currentScene, stackCount)
			if not effectOfDeal then effectOfDeal = "" end
		else
			_, _, _, suggestedTTC, suggestedATT, suggestedAVG, suggestedTTCStack, suggestedATTStack, suggestedAVGStack, suggestedTTCWrit, suggestedATTWrit, suggestedAVGWrit = KelaGetEffectOfDeal (priceInfoTTC, priceInfoATT, selectedData, nil, stackCount)
		end
		
		control:GetNamedChild("Footer"):ClearAnchors()
		control:GetNamedChild("Footer"):SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT)
		control:GetNamedChild("Footer"):SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT)
		if valueEffectDeal then
			control:GetNamedChild("Footer"):GetNamedChild("EffectOfDeal"):SetText(colorEffectDeal:Colorize(tostring(valueEffectDeal)))
			control:GetNamedChild("Footer"):GetNamedChild("EffectOfDeal"):SetHidden(false)
		else
			control:GetNamedChild("Footer"):GetNamedChild("EffectOfDeal"):SetText("")
			control:GetNamedChild("Footer"):GetNamedChild("EffectOfDeal"):SetHidden(true)
		end
		local bothProviders = priceInfoTTC.Available and priceInfoATT.Available
		local hasAverage = bothProviders and suggestedATT ~= 0 and suggestedTTC ~= 0
		local hasAverageStack = bothProviders and suggestedATTStack ~= 0 and suggestedTTCStack ~= 0
		local hasAverageWrit = bothProviders and suggestedATTWrit ~= 0 and suggestedTTCWrit ~= 0
		local suggestedAVGText = hasAverage and (KelaLocalizedFormatNumber(suggestedAVG).." ~") or "N/A"
		local suggestedAVGStackText = hasAverageStack and (KelaLocalizedFormatNumber(suggestedAVGStack).." ~") or "N/A"
		local suggestedAVGWritText = hasAverageWrit and (KelaLocalizedFormatNumber(suggestedAVGWrit).." ~") or "N/A"
		control:GetNamedChild("Footer"):GetNamedChild("Recomend"):SetText(GetString(KELA_TRADING_RECOMENDEDPRICE_SYSTEM))
		control:GetNamedChild("Footer"):GetNamedChild("ATT"):SetText(colors.COLOR_ATT:Colorize(formatProvider(priceInfoATT, suggestedATT)))
		control:GetNamedChild("Footer"):GetNamedChild("TTC"):SetText(colors.COLOR_TTC:Colorize(formatProvider(priceInfoTTC, suggestedTTC)))
		control:GetNamedChild("Footer"):GetNamedChild("AVG"):SetText(suggestedAVGText)
		if IsMasterWrit then
			control:GetNamedChild("Footer"):GetNamedChild("RecomendStack"):SetHidden(false)
			control:GetNamedChild("Footer"):GetNamedChild("ATTStack"):SetHidden(false)
			control:GetNamedChild("Footer"):GetNamedChild("TTCStack"):SetHidden(false)
			control:GetNamedChild("Footer"):GetNamedChild("AVGStack"):SetHidden(false)
			control:GetNamedChild("Footer"):GetNamedChild("RecomendStack"):SetText(GetString(KELA_TRADING_TRADING_FORWRIT).."("..multiplier..")")
			control:GetNamedChild("Footer"):GetNamedChild("ATTStack"):SetText(colors.COLOR_ATT:Colorize(formatProvider(priceInfoATT, suggestedATTWrit)))
			control:GetNamedChild("Footer"):GetNamedChild("TTCStack"):SetText(colors.COLOR_TTC:Colorize(formatProvider(priceInfoTTC, suggestedTTCWrit)))
			control:GetNamedChild("Footer"):GetNamedChild("AVGStack"):SetText(suggestedAVGWritText)
		elseif stackCount > 1 then
			control:GetNamedChild("Footer"):GetNamedChild("RecomendStack"):SetHidden(false)
			control:GetNamedChild("Footer"):GetNamedChild("ATTStack"):SetHidden(false)
			control:GetNamedChild("Footer"):GetNamedChild("TTCStack"):SetHidden(false)
			control:GetNamedChild("Footer"):GetNamedChild("AVGStack"):SetHidden(false)
			control:GetNamedChild("Footer"):GetNamedChild("RecomendStack"):SetText(GetString(KELA_TRADING_TRADING_FORLOT).."("..stackCount..")")
			control:GetNamedChild("Footer"):GetNamedChild("ATTStack"):SetText(colors.COLOR_ATT:Colorize(formatProvider(priceInfoATT, suggestedATTStack)))
			control:GetNamedChild("Footer"):GetNamedChild("TTCStack"):SetText(colors.COLOR_TTC:Colorize(formatProvider(priceInfoTTC, suggestedTTCStack)))
			control:GetNamedChild("Footer"):GetNamedChild("AVGStack"):SetText(suggestedAVGStackText)
		else 
			control:GetNamedChild("Footer"):GetNamedChild("RecomendStack"):SetHidden(true)
			control:GetNamedChild("Footer"):GetNamedChild("ATTStack"):SetHidden(true)
			control:GetNamedChild("Footer"):GetNamedChild("TTCStack"):SetHidden(true)
			control:GetNamedChild("Footer"):GetNamedChild("AVGStack"):SetHidden(true)
			control:GetNamedChild("Footer"):GetNamedChild("RecomendStack"):SetText("")
			control:GetNamedChild("Footer"):GetNamedChild("ATTStack"):SetText("")
			control:GetNamedChild("Footer"):GetNamedChild("TTCStack"):SetText("")
			control:GetNamedChild("Footer"):GetNamedChild("AVGStack"):SetText("")
		end	
		return control:GetNamedChild("Footer"), effectOfDeal, (stackCount > 1 or IsMasterWrit or valueEffectDeal)
	end
end

function KPUI_Graph_OnInitialize(control)
	local rows = {}
	local rowFake
	-- Keep the XML independent of ATT: create the ATT graph child only when available.
	if ArkadiusTradeTools and ArkadiusTradeToolsSalesGraph then
		local graph = CreateControlFromVirtual("$(parent)ATTGraph", control, "ArkadiusTradeToolsSalesGraph")
		graph:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
		graph:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 0, 0)
		graph:SetDrawTier(DT_LOW)
		control.object = graph.object
	end
	control.SetGuildSalesInfo = function(GuildsInfo, GuildsPrice, stackCount, lastControl)
		if not ArkadiusTradeTools or not control.object then
			control:SetHidden(true)
			return lastControl
		end
		if not stackCount then stackCount = 1 end
		stackCount = math.floor(stackCount)
		
		control:GetNamedChild("Header"):SetHidden(false)
		control:GetNamedChild("Header"):ClearAnchors()
		control:GetNamedChild("Header"):SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT, -10)
		control:GetNamedChild("Header"):SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT, 10)
		control:GetNamedChild("Header"):GetNamedChild("Stat"):SetText(GetString(KELA_TRADING_TRADING_GUILD))
		if stackCount > 1 then
			control:GetNamedChild("Header"):GetNamedChild("AVGStack"):SetHidden(false)
			control:GetNamedChild("Header"):GetNamedChild("AVGStack"):SetText(GetString(KELA_TRADING_AVGPRICE_SHORT).." ("..stackCount..")")
		else
			control:GetNamedChild("Header"):GetNamedChild("AVGStack"):SetHidden(true)
			control:GetNamedChild("Header"):GetNamedChild("AVGStack"):SetText(GetString(KELA_TRADING_AVGPRICE_SHORT))
		end
		control:GetNamedChild("Header"):GetNamedChild("AVG"):SetText(GetString(KELA_TRADING_AVGPRICE_SHORT))
		control:GetNamedChild("Header"):GetNamedChild("Value"):SetText(GetString(KELA_TRADING_SOLD))
		lastControl = control:GetNamedChild("Header")
		
		if next(GuildsInfo) ~= nil then
			if rowFake then rowFake:SetHidden(true) end
			for _, row in pairs(rows) do
				row:SetHidden(true)
			end
			rows = {}
			for guildName, countSales in spairs(GuildsInfo, function(t, a, b) return t[a] > t[b]  end) do
				local color = ArkadiusTradeTools:GetGuildColor(guildName)
				local guildRow = string.gsub(guildName, "%s+", "")
				if string.len(guildRow) > 15 then guildRow = string.sub(guildRow, 1, 15) end
				local row = GetControl(control:GetName().."row"..guildRow)
				if not row then row = CreateControlFromVirtual("$(parent)row", control, "KPUI_GraphRow", guildRow) end
				rows[#rows + 1] = row
				row:ClearAnchors()
				row:SetHidden(false)
				row:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT)
				row:SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT)
				row:GetNamedChild("Stat"):SetText(color:Colorize(guildName))
				
				local guildPrice = math.floor(GuildsPrice[guildName])
				
				if stackCount > 1 then
					row:GetNamedChild("AVGStack"):SetHidden(false)
					row:GetNamedChild("AVGStack"):SetText(KelaLocalizedFormatNumber(guildPrice*stackCount))
				else
					row:GetNamedChild("AVGStack"):SetHidden(true)
					row:GetNamedChild("AVGStack"):SetText("-")
				end
				row:GetNamedChild("AVG"):SetText(KelaLocalizedFormatNumber(guildPrice))
				row:GetNamedChild("Value"):SetText(countSales)
				lastControl = row
			end
		else
			for _, row in pairs(rows) do
				row:SetHidden(true)
			end
			rows = {}
			control:GetNamedChild("Header"):GetNamedChild("AVGStack"):SetText(GetString(KELA_TRADING_AVGPRICE_SHORT).." (".."-"..")")
			rowFake = GetControl(control:GetName().."rowFake")
			if not rowFake then rowFake = CreateControlFromVirtual("$(parent)rowFake", control, "KPUI_GraphRow") end	
			rowFake:ClearAnchors()
			rowFake:SetHidden(false)
			rowFake:SetAnchor(TOPLEFT, control:GetNamedChild("Header"), BOTTOMLEFT)
			rowFake:SetAnchor(TOPRIGHT, control:GetNamedChild("Header"), BOTTOMRIGHT)
			rowFake:GetNamedChild("Stat"):SetText("-")
			if stackCount > 1 then
				rowFake:GetNamedChild("AVGStack"):SetText("-")
			else
				rowFake:GetNamedChild("AVGStack"):SetText("")
			end
			rowFake:GetNamedChild("AVG"):SetText("-")	
			rowFake:GetNamedChild("Value"):SetText("-")
			lastControl = rowFake											
		end

		control:GetNamedChild("Footer"):SetHidden(false)
		control:GetNamedChild("Footer"):ClearAnchors()
		control:GetNamedChild("Footer"):SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT)
		control:GetNamedChild("Footer"):SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT)

		return control:GetNamedChild("Footer")
	end
end

function KPUI_PreviousListings_OnInitialize(control)
	control.SetPreviousListings = function(listingItemsTable, lastControl)
		for i = 1, 5 do
			local row = GetControl(control:GetName().."row"..i)
			if row then row:SetHidden(true) end
		end

		control:GetNamedChild("Header"):GetNamedChild("Title"):SetText(GetString(KELA_SETTING_TRADE_TOOLTIP_LISTINGS))	
		control:GetNamedChild("Header"):GetNamedChild("TitleValue"):SetText(" ")		
		control:GetNamedChild("Header"):GetNamedChild("Guild"):SetText(GetString(KELA_TRADING_TRADING_GUILD))
		control:GetNamedChild("Header"):GetNamedChild("Result"):SetText(" ")
		control:GetNamedChild("Header"):GetNamedChild("Period"):SetText(GetString(KELA_TRADING_PERIOD))
		control:GetNamedChild("Header"):GetNamedChild("PriceForOne"):SetText(GetString(KELA_TRADING_PRICE_TITLE))
		control:GetNamedChild("Header"):GetNamedChild("PriceForLot"):SetText(GetString(KELA_TRADING_PRICEFORLOT))
		control:GetNamedChild("Header"):ClearAnchors()
		control:GetNamedChild("Header"):SetHidden(false)
		control:GetNamedChild("Header"):SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT)
		control:GetNamedChild("Header"):SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT)
		lastControl = control:GetNamedChild("Header")

		local count = 0
		local isStack
		for listingTime, listingItem in spairs(listingItemsTable, function (t, a, b) return (a > b) end) do
			
			count = count + 1
			
			local color = ArkadiusTradeTools and ArkadiusTradeTools:GetGuildColor(listingItem["guildName"]) or colors.COLOR_WHITE
			
			local periodValue
			if listingItem["period"] then
				local timeString 
				if listingItem["period"] == 0 then 
					timeString = "-"
				else
					timeString = zo_strformat(SI_TRADING_HOUSE_BROWSE_ITEM_REMAINING_TIME, ZO_FormatTime(listingItem["period"], TIME_FORMAT_STYLE_SHOW_LARGEST_UNIT, TIME_FORMAT_PRECISION_SECONDS, TIME_FORMAT_DIRECTION_DESCENDING))
				end
				periodValue = KelaTimeStampToDateTimeString(listingTime).." ("..timeString..")"
			else
				local timeString = zo_strformat(SI_TRADING_HOUSE_BROWSE_ITEM_REMAINING_TIME, ZO_FormatTime(GetTimeStamp() - listingTime, TIME_FORMAT_STYLE_SHOW_LARGEST_UNIT, TIME_FORMAT_PRECISION_SECONDS, TIME_FORMAT_DIRECTION_DESCENDING))							
				periodValue = KelaTimeStampToDateTimeString(listingTime).." ("..timeString..")"
			end

			local row = GetControl(control:GetName().."row"..count)
			if not row then row = CreateControlFromVirtual("$(parent)row", control, "KPUI_PreviousListingsRow", count) end	
			
			row:GetNamedChild("Guild"):SetText(color:Colorize(listingItem["guildName"]))
			row:GetNamedChild("Result"):SetText(listingItem["result"])
			row:GetNamedChild("Period"):SetText(periodValue)
			row:GetNamedChild("PriceForOne"):SetText(KelaLocalizedFormatNumber(listingItem["desiredPrice"]/listingItem["stackCount"]))
			
			if listingItem["stackCount"] > 1 then
				row:GetNamedChild("PriceForLot"):SetText(KelaLocalizedFormatNumber(listingItem["desiredPrice"]).." ("..listingItem["stackCount"]..")")
				isStack = true
			else
				row:GetNamedChild("PriceForLot"):SetText("")
				isStack = false
			end
			
			row:ClearAnchors()
			row:SetHidden(false)
			row:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT)
			row:SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT)						
			
			lastControl = row						
			
			if count >= 5 then break end

		end	
		
		if not isStack then 
			control:GetNamedChild("Header"):GetNamedChild("PriceForLot"):SetText("")
		end
		
		control:GetNamedChild("Footer"):ClearAnchors()
		control:GetNamedChild("Footer"):SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT)
		control:GetNamedChild("Footer"):SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT)
		return control:GetNamedChild("Footer")
	end
end

function KPUI_OtherQualityInfo_OnInitialize(control)
	control.SetOtherQualityPrices = function(itemLink, normalItemLink, fineItemLink, superiorItemLink, epicItemLink, legendaryItemLink, lastControl)

		local titleSubTitle = " "
		local transmutted = GetItemTraitInformationFromItemLink(itemLink) and GetItemTraitInformationFromItemLink(itemLink) == 4
		local notCurrentName = GetItemLinkName(itemLink) ~= GetItemLinkName(normalItemLink)

		if transmutted then
			local traitType = GetItemLinkTraitInfo(normalItemLink)
			local traitName = GetString("SI_ITEMTRAITTYPE", traitType)
			titleSubTitle = kpuiConst.Colors.COLOR_POISON:Colorize(GetString(KELA_TRADING_BEFORETRANSMUTE)..traitName)
		elseif notCurrentName then
			local name = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(normalItemLink))
			titleSubTitle = kpuiConst.Colors.COLOR_POISON:Colorize(name)
		end		
		
		control:GetNamedChild("Header"):GetNamedChild("Title"):SetText(GetString(KELA_TRADING_INANOTHERQUALITY))
		control:GetNamedChild("Header"):GetNamedChild("TitleValue"):SetText(kpuiConst.Colors.COLOR_POISON:Colorize(titleSubTitle))
		control:GetNamedChild("Header"):ClearAnchors()
		control:GetNamedChild("Header"):SetHidden(false)
		control:GetNamedChild("Header"):SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT)
		control:GetNamedChild("Header"):SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT)
		lastControl = control:GetNamedChild("Header")					
		
		control:GetNamedChild("ColumnTitle"):GetNamedChild("TradeSystem"):SetText(GetString(KELA_TRADING_TRADESYSTEM))
		control:GetNamedChild("ColumnTitle"):GetNamedChild("PriceRec"):SetText(GetString(KELA_TRADING_PRICEREC))
		control:GetNamedChild("ColumnTitle"):GetNamedChild("PriceAvg"):SetText(GetString(KELA_TRADING_PRICEAVG))
		control:GetNamedChild("ColumnTitle"):GetNamedChild("AmountCount"):SetText(GetString(KELA_TRADING_GOODUNIT))
		control:GetNamedChild("ColumnTitle"):GetNamedChild("EntryCount"):SetText(GetString(KELA_TRADING_LOTS))
		control:GetNamedChild("ColumnTitle"):ClearAnchors()
		control:GetNamedChild("ColumnTitle"):SetHidden(false)
		control:GetNamedChild("ColumnTitle"):SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT)
		control:GetNamedChild("ColumnTitle"):SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT)
		lastControl = control:GetNamedChild("ColumnTitle")

		local lastControlATT, lastControlTTC
		local isStack
		local function addATTRow(sufText, itemLink, priceInfoATT)
			local rowATT
			local qualityColor = GetItemQualityColor(GetItemLinkDisplayQuality(itemLink))
		
			rowATT = GetControl(control:GetName().."rowATT"..sufText)
			if not rowATT then rowATT = CreateControlFromVirtual("$(parent)rowATT", control, "KPUI_OtherQualityInfoRow", sufText) end
			local isFirst
			if lastControlATT then 
				lastControl = lastControlATT
			else
				isFirst = true
			end
			rowATT:ClearAnchors()
			rowATT:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT)
			if priceInfoATT.Avg ~= 0 then 
				rowATT:SetHidden(false)
				if isFirst then 
					rowATT:GetNamedChild("TradeSystem"):SetText(kpuiConst.Colors.COLOR_ATT:Colorize("Arkadius Trade Tools"))
				else
					rowATT:GetNamedChild("TradeSystem"):SetText(" ")
				end
				rowATT:GetNamedChild("PriceRec"):SetText(qualityColor:Colorize(KelaLocalizedFormatNumber(priceInfoATT.SuggestedPrice)))
				rowATT:GetNamedChild("PriceAvg"):SetText(qualityColor:Colorize(KelaLocalizedFormatNumber(priceInfoATT.Avg)))
				rowATT:GetNamedChild("AmountCount"):SetText(qualityColor:Colorize(KelaLocalizedFormatNumber(priceInfoATT.AmountCount)))
				if not isStack and priceInfoATT.AmountCount ~= priceInfoATT.EntryCount then isStack = true end
				if isStack then
					rowATT:GetNamedChild("EntryCount"):SetText(qualityColor:Colorize(KelaLocalizedFormatNumber(priceInfoATT.EntryCount)))
				else
					rowATT:GetNamedChild("EntryCount"):SetText("")
				end
				lastControlATT = rowATT
			else
				if rowATT then rowATT:SetHidden(true) end
			end
		end
		local function addTTCRow(sufText, itemLink, priceInfoTTC)
			local rowTTC
			local qualityColor = GetItemQualityColor(GetItemLinkDisplayQuality(itemLink))

			rowTTC = GetControl(control:GetName().."rowTTC"..sufText)
			if not rowTTC then rowTTC = CreateControlFromVirtual("$(parent)rowTTC", control, "KPUI_OtherQualityInfoRow", sufText) end
			
			local isFirst
			if lastControlTTC then 
				lastControl = lastControlTTC
			else
				lastControl = lastControlATT or lastControl
				isFirst = true
			end
			
			rowTTC:ClearAnchors()
			rowTTC:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT)		
			if priceInfoTTC.Avg ~= 0 then
				rowTTC:SetHidden(false)
				if isFirst then 
					rowTTC:GetNamedChild("TradeSystem"):SetText(kpuiConst.Colors.COLOR_TTC:Colorize("Tamriel Trade Centre"))
				else
					rowTTC:GetNamedChild("TradeSystem"):SetText(" ")
				end
				rowTTC:GetNamedChild("PriceRec"):SetText(qualityColor:Colorize(KelaLocalizedFormatNumber(priceInfoTTC.SuggestedPrice)))
				rowTTC:GetNamedChild("PriceAvg"):SetText(qualityColor:Colorize(KelaLocalizedFormatNumber(priceInfoTTC.Avg)))
				rowTTC:GetNamedChild("AmountCount"):SetText(qualityColor:Colorize(KelaLocalizedFormatNumber(priceInfoTTC.AmountCount)))
				if not isStack and priceInfoTTC.AmountCount ~= priceInfoTTC.EntryCount then isStack = true end
				if isStack then
					rowTTC:GetNamedChild("EntryCount"):SetText(qualityColor:Colorize(KelaLocalizedFormatNumber(priceInfoTTC.EntryCount)))
				else
					rowTTC:GetNamedChild("EntryCount"):SetText("")
				end
				lastControlTTC = rowTTC
			else
				if rowTTC then rowTTC:SetHidden(true) end
			end
		end			

		local trueTTCNormal, trueATTNormal, priceInfoTTCNormal, priceInfoATTNormal
		local trueTTCFine, trueATTFine, priceInfoTTCFine, priceInfoATTFine
		local trueTTCSuperior, trueATTSuperior, priceInfoTTCSuperior, priceInfoATTSuperior
		local trueTTCEpic, trueATTEpic, priceInfoTTCEpic, priceInfoATTEpic
		local trueTTCLegendary, trueATTLegendary, priceInfoTTCLegendary, priceInfoATTLegendary

		if normalItemLink then trueTTCNormal, trueATTNormal, priceInfoTTCNormal, priceInfoATTNormal = KelaGetPriceInfoTTCATT(normalItemLink) end
		if fineItemLink then trueTTCFine, trueATTFine, priceInfoTTCFine, priceInfoATTFine = KelaGetPriceInfoTTCATT(fineItemLink) end
		if superiorItemLink then trueTTCSuperior, trueATTSuperior, priceInfoTTCSuperior, priceInfoATTSuperior = KelaGetPriceInfoTTCATT(superiorItemLink) end
		if epicItemLink then trueTTCEpic, trueATTEpic, priceInfoTTCEpic, priceInfoATTEpic = KelaGetPriceInfoTTCATT(epicItemLink) end
		if legendaryItemLink then trueTTCLegendary, trueATTLegendary, priceInfoTTCLegendary, priceInfoATTLegendary = KelaGetPriceInfoTTCATT(legendaryItemLink) end


		if trueATTNormal then
			addATTRow("normal", normalItemLink, priceInfoATTNormal)
		else 
			if GetControl(control:GetName().."rowATT".."normal") then GetControl(control:GetName().."rowATT".."normal"):SetHidden(true) end
		end
		if trueATTFine then
			addATTRow("fine", fineItemLink, priceInfoATTFine)
		else 
			if GetControl(control:GetName().."rowATT".."fine") then GetControl(control:GetName().."rowATT".."fine"):SetHidden(true) end
		end					
		if trueATTSuperior then
			addATTRow("superior", superiorItemLink, priceInfoATTSuperior)
		else 
			if GetControl(control:GetName().."rowATT".."superior") then GetControl(control:GetName().."rowATT".."superior"):SetHidden(true) end
		end					
		if trueATTEpic then
			addATTRow("epic", epicItemLink, priceInfoATTEpic)
		else 
			if GetControl(control:GetName().."rowATT".."epic") then GetControl(control:GetName().."rowATT".."epic"):SetHidden(true) end
		end					
		if trueATTLegendary then
			addATTRow("legendary", legendaryItemLink, priceInfoATTLegendary)
		else 
			if GetControl(control:GetName().."rowATT".."legendary") then GetControl(control:GetName().."rowATT".."legendary"):SetHidden(true) end
		end					
		
		if trueTTCNormal then
			addTTCRow("normal", normalItemLink, priceInfoTTCNormal)
		else 
			if GetControl(control:GetName().."rowTTC".."normal") then GetControl(control:GetName().."rowTTC".."normal"):SetHidden(true) end
		end
		if trueTTCFine then
			addTTCRow("fine", fineItemLink, priceInfoTTCFine)
		else 
			if GetControl(control:GetName().."rowTTC".."fine") then GetControl(control:GetName().."rowTTC".."fine"):SetHidden(true) end
		end	
		if trueTTCSuperior then
			addTTCRow("superior", superiorItemLink, priceInfoTTCSuperior)
		else 
			if GetControl(control:GetName().."rowTTC".."superior") then GetControl(control:GetName().."rowTTC".."superior"):SetHidden(true) end
		end		
		if trueTTCEpic then
			addTTCRow("epic", epicItemLink, priceInfoTTCEpic)
		else 
			if GetControl(control:GetName().."rowTTC".."epic") then GetControl(control:GetName().."rowTTC".."epic"):SetHidden(true) end
		end		
		if trueTTCLegendary then
			addTTCRow("legendary", legendaryItemLink, priceInfoTTCLegendary)
		else 
			if GetControl(control:GetName().."rowTTC".."legendary") then GetControl(control:GetName().."rowTTC".."legendary"):SetHidden(true) end
		end									

		if not isStack then
			control:GetNamedChild("ColumnTitle"):GetNamedChild("EntryCount"):SetText("")
		end
		
		local notSuccess
		if lastControlTTC then
			lastControl = lastControlTTC
		elseif lastControlATT then
			lastControl = lastControlATT
		else
			notSuccess = true
		end

		control:GetNamedChild("Footer"):ClearAnchors()
		control:GetNamedChild("Footer"):SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT)
		control:GetNamedChild("Footer"):SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT)
		
		return control:GetNamedChild("Footer"), notSuccess
	end
end

function KPUI_ProductMaterialInfo_OnInitialize(control)
	control.SetRawProductPrices = function(resultItemLink, priceInfoTTC, priceInfoATT, lastControl)
		
		local rowTTC, rowATT
		local name = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(resultItemLink))
		local nameColor = GetItemQualityColor(GetItemLinkDisplayQuality(resultItemLink))
		local colorizedItemName = nameColor:Colorize(name)
		local itemType = GetItemLinkItemType(resultItemLink)
		
		if itemType == ITEMTYPE_ARMOR or itemType == ITEMTYPE_GLYPH_ARMOR or itemType == ITEMTYPE_GLYPH_JEWELRY or itemType == ITEMTYPE_GLYPH_WEAPON or itemType == ITEMTYPE_WEAPON then
			control:GetNamedChild("Header"):GetNamedChild("Title"):SetText(" ")	
		else
			control:GetNamedChild("Header"):GetNamedChild("Title"):SetText(GetString(KELA_PRODUCT))	
		end
		control:GetNamedChild("Header"):GetNamedChild("TitleValue"):SetText(colorizedItemName)
		control:GetNamedChild("Header"):GetNamedChild("TradeSystem"):SetText(GetString(KELA_TRADING_TRADESYSTEM))
		control:GetNamedChild("Header"):GetNamedChild("PriceRec"):SetText(GetString(KELA_TRADING_PRICEREC))
		control:GetNamedChild("Header"):GetNamedChild("PriceAvg"):SetText(GetString(KELA_TRADING_PRICEAVG))
		control:GetNamedChild("Header"):GetNamedChild("AmountCount"):SetText(GetString(KELA_TRADING_GOODUNIT))
		control:GetNamedChild("Header"):GetNamedChild("EntryCount"):SetText(GetString(KELA_TRADING_LOTS))

		control:GetNamedChild("Header"):ClearAnchors()
		control:GetNamedChild("Header"):SetHidden(false)
		control:GetNamedChild("Header"):SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT)
		control:GetNamedChild("Header"):SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT)

		lastControl = control:GetNamedChild("Header")

		rowATT = GetControl(control:GetName().."rowATT")
		if not rowATT then rowATT = CreateControlFromVirtual("$(parent)rowATT", control, "KPUI_ProductMaterialInfoRow") end
		rowATT:ClearAnchors()
		rowATT:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT)
		if priceInfoATT.Avg ~= 0 then 
			rowATT:SetHidden(false)
			rowATT:GetNamedChild("TradeSystem"):SetText(kpuiConst.Colors.COLOR_ATT:Colorize("Arkadius Trade Tools"))
			rowATT:GetNamedChild("PriceRec"):SetText(KelaLocalizedFormatNumber(priceInfoATT.SuggestedPrice))
			rowATT:GetNamedChild("PriceAvg"):SetText(KelaLocalizedFormatNumber(priceInfoATT.Avg))
			rowATT:GetNamedChild("AmountCount"):SetText(KelaLocalizedFormatNumber(priceInfoATT.AmountCount))
			rowATT:GetNamedChild("EntryCount"):SetText(KelaLocalizedFormatNumber(priceInfoATT.EntryCount))
			lastControl = rowATT
		else
			if rowATT then rowATT:SetHidden(true) end
		end
	
		rowTTC = GetControl(control:GetName().."rowTTC")
		if not rowTTC then rowTTC = CreateControlFromVirtual("$(parent)rowTTC", control, "KPUI_ProductMaterialInfoRow") end
		rowTTC:ClearAnchors()
		rowTTC:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT)				
		if priceInfoTTC.Avg ~= 0 then
			rowTTC:SetHidden(false)
			rowTTC:GetNamedChild("TradeSystem"):SetText(kpuiConst.Colors.COLOR_TTC:Colorize("Tamriel Trade Centre"))
			rowTTC:GetNamedChild("PriceRec"):SetText(KelaLocalizedFormatNumber(priceInfoTTC.SuggestedPrice))
			rowTTC:GetNamedChild("PriceAvg"):SetText(KelaLocalizedFormatNumber(priceInfoTTC.Avg))
			rowTTC:GetNamedChild("AmountCount"):SetText(KelaLocalizedFormatNumber(priceInfoTTC.AmountCount))
			rowTTC:GetNamedChild("EntryCount"):SetText(KelaLocalizedFormatNumber(priceInfoTTC.EntryCount))
			lastControl = rowTTC
		else
			if rowTTC then rowTTC:SetHidden(true) end
		end

		control:GetNamedChild("Footer"):ClearAnchors()
		control:GetNamedChild("Footer"):SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT)
		control:GetNamedChild("Footer"):SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT)
		return control:GetNamedChild("Footer")
	end
end

function KPUI_CraftingInfo_OnInitialize(control)
	control.SetItemPrices = function(craftingComponentPrices, lastControl)
		if next(craftingComponentPrices) ~= nil then
		
			local iconsHave = zo_iconFormatInheritColor("EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_inventory.dds", 15, 15)
			iconsHave = iconsHave..zo_iconFormatInheritColor("esoui/art/icons/servicemappins/servicepin_bank.dds", 15, 15)
			control:GetNamedChild("Header"):GetNamedChild("Title"):SetText(GetString(SI_PROVISIONER_INGREDIENTS_HEADER))
			control:GetNamedChild("Header"):GetNamedChild("Quantity"):SetText(iconsHave)
			control:GetNamedChild("Header"):GetNamedChild("ItemName"):SetText(GetString(KELA_TRADING_ITEM))
			control:GetNamedChild("Header"):GetNamedChild("CurrencyTTC"):SetText(GetString(KELA_TRADING_ITEM).."|cf23d8eTTC|r")
			control:GetNamedChild("Header"):GetNamedChild("CurrencyATT"):SetText(GetString(KELA_TRADING_ITEM).."|cf58585ATT|r")
			
			control:GetNamedChild("Header"):ClearAnchors()
			control:GetNamedChild("Header"):SetHidden(false)
			control:GetNamedChild("Header"):SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT)
			control:GetNamedChild("Header"):SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT)

			lastControl = control:GetNamedChild("Header")

			local totalPriceATT = 0
			local totalPriceTTC = 0
			for i = 1, 7 do
				local rowOld = GetControl(control:GetName().."row"..i)
				if rowOld then
					row = rowOld
				else
					row = CreateControlFromVirtual("$(parent)row", control, "KPUI_CraftingInfoRow", i)
				end					
				row:ClearAnchors()
				if craftingComponentPrices[i] == nil then
					row:SetHidden(true)
				else
					row:SetHidden(false)
					if i == 1 then
						row:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT)
					else
						row:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT)
						row:SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT)
					end
					local bagCount, bankCount, craftBagCount = GetItemLinkStacks(craftingComponentPrices[i].itemLink)
					local stackCount = bagCount + bankCount + craftBagCount							
					if craftingComponentPrices[i].quantity > stackCount then 
						stackCount = "|cDC8122"..tostring(stackCount).."|r"
						row:GetNamedChild("Quantity"):SetFont("ZoFontGamepad22")								
					else
						stackCount = "|cFFFFFF"..tostring(stackCount).."|r" 
						row:GetNamedChild("Quantity"):SetFont("ZoFontGamepad20")
					end
					row:GetNamedChild("Quantity"):SetText(stackCount) 
					row:GetNamedChild("ItemName"):SetText(craftingComponentPrices[i].itemLink.." *"..craftingComponentPrices[i].quantity)

					local priceInfoTTC
					if TamrielTradeCentre and TamrielTradeCentrePrice then
						priceInfoTTC = TamrielTradeCentrePrice:GetPriceInfo(craftingComponentPrices[i].itemLink)
					end

					if priceInfoTTC then
						row:GetNamedChild("CurrencyTTC"):SetText(KelaLocalizedFormatNumber(priceInfoTTC.Avg * craftingComponentPrices[i].quantity))
						totalPriceTTC = totalPriceTTC + (priceInfoTTC.Avg * craftingComponentPrices[i].quantity)
					else
						row:GetNamedChild("CurrencyTTC"):SetText("N/A")
					end

					local priceInfoATT
					if craftingComponentPrices[i].price and	craftingComponentPrices[i].quantity then
						priceInfoATT = craftingComponentPrices[i].price * craftingComponentPrices[i].quantity
					end
					
					if priceInfoATT then 
						row:GetNamedChild("CurrencyATT"):SetText(KelaLocalizedFormatNumber(priceInfoATT)) 
						totalPriceATT = totalPriceATT + priceInfoATT
					end

					lastControl = row
				end
			end
			control:GetNamedChild("Footer"):ClearAnchors()
			control:GetNamedChild("Footer"):SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT)
			control:GetNamedChild("Footer"):SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT)
			control:GetNamedChild("Footer"):GetNamedChild("SummaryLabel"):SetText(GetString(KELA_TRADING_SUMMARY)..":")
			control:GetNamedChild("Footer"):GetNamedChild("SummaryValueTTC"):SetText("|cf23d8e"..KelaLocalizedFormatNumber(totalPriceTTC).."|r") 
			control:GetNamedChild("Footer"):GetNamedChild("SummaryValueATT"):SetText("|cf58585"..KelaLocalizedFormatNumber(totalPriceATT).."|r") 
			return control:GetNamedChild("Footer")
		end
	end
end
