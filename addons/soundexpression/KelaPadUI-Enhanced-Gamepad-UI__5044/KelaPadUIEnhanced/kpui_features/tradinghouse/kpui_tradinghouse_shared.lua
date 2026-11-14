-- KelaPadUI trading-house shared helpers. Load before the hooks,
-- tooltip, provider, and custom-control modules. This file keeps the
-- original helper implementations as locals and exposes them through
-- KPUI_TRADINGHOUSE for the split modules.

KPUI_TRADINGHOUSE = KPUI_TRADINGHOUSE or {}
local KPUI_TRADINGHOUSE = KPUI_TRADINGHOUSE

-- Trading-house gamepad integration. Hooks core trading-house search/filtering
-- and adds KelaPadUI tooltip sections. The custom KPUI_* controls are retained;
-- see the repository backlog file for the future hook/XML replacement work.

local colors = kpuiConst.Colors	
local function KelaGetATTSalesSecondsPerDay(salesModule)
	local tooltipExtension = salesModule and salesModule.TooltipExtension
	return (tooltipExtension and tooltipExtension.SECONDS_IN_DAY) or 60 * 60 * 24
end

KELA_KNOWN_ITEM_FILTER = "ALL"
KELA_CURRENT_EFFECTDEAL_SELECTION_INDEX = 1

KELA_TRADINGHOUSE_CURRENT_SELECTEDDATA = {}

KELA_SMITHING_IMPROVED_TOOLTIP_TYPE = 0

local function KelaCreateColorizedResumePrice(index)
	local label = GetString("KELA_TRADING_RESUMEPRICE", index)
	local color
	if index == 5 then 
		color = colors.COLOR_DEALGREAT
	elseif index == 4 then 
		color = colors.COLOR_DEALGOOD
	elseif index == 3 then 
		color = colors.COLOR_DEALNORMAL
	elseif index == 2 then 
		color = colors.COLOR_WHITE
	elseif index == 1 then 
		return label
	end
	return color:Colorize(label)
end	


function KelaIsSceneTradingHouse(currentScene)
	return (currentScene == "TRADING_HOUSE_CREATE_LISTING_GAMEPAD" or currentScene == "GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS" or currentScene == "GAMEPAD_TRADING_HOUSE_LISTINGS" or currentScene == "GAMEPAD_TRADING_HOUSE_SELL")
end


local function GetItemLinks(itemLink, includeQualityLinks)

	local function GetQualityItemLink(itemId, itemQuality, itemLevel, itemChampionPoints, enchantId)
		if itemId == nil or itemId == 0 then return end
		-- LibItemLink is optional; skip the other-quality rows when it is absent.
		if not LIB_ITEM_LINK then return end
		return LIB_ITEM_LINK:BuildItemLink(tonumber(itemId), tonumber(itemQuality), tonumber(itemLevel), tonumber(itemChampionPoints), nil, nil, tonumber(enchantId))
	end
	
	local resultItemLink, normalItemLink, fineItemLink, superiorItemLink, epicItemLink, legendaryItemLink
	local minLevel, minChampionPoints
	local referenceEnchantID
	local itemType = GetItemLinkItemType(itemLink) 
	local itemId = GetItemLinkItemId(itemLink)
	local referenceQuality = GetItemLinkQuality(itemLink)
	
		if itemType == ITEMTYPE_RECIPE then
			resultItemLink = GetItemLinkRecipeResultItemLink(itemLink)
		else
			resultItemLink = GetItemLinkRefinedMaterialItemLink(itemLink)
		end
	if itemType == ITEMTYPE_GLYPH_ARMOR or itemType == ITEMTYPE_GLYPH_JEWELRY or itemType == ITEMTYPE_GLYPH_WEAPON then
		minLevel, minChampionPoints = GetItemLinkGlyphMinLevels(itemLink)
		referenceEnchantID = GetItemLinkFinalEnchantId(itemLink)
	elseif itemType == ITEMTYPE_ARMOR or itemType == ITEMTYPE_WEAPON then
		minLevel = GetItemLinkRequiredLevel(itemLink)
		minChampionPoints = GetItemLinkRequiredChampionPoints(itemLink)
		referenceEnchantID = GetItemLinkFinalEnchantId(itemLink)
	end

	if includeQualityLinks and (itemType == ITEMTYPE_ARMOR or itemType == ITEMTYPE_GLYPH_ARMOR or itemType == ITEMTYPE_GLYPH_JEWELRY or itemType == ITEMTYPE_GLYPH_WEAPON or itemType == ITEMTYPE_WEAPON) then
		if referenceQuality ~= ITEM_QUALITY_NORMAL then normalItemLink = GetQualityItemLink(itemId, ITEM_QUALITY_NORMAL, minLevel, minChampionPoints, referenceEnchantID) end
		if referenceQuality ~= ITEM_QUALITY_MAGIC then fineItemLink = GetQualityItemLink(itemId, ITEM_QUALITY_MAGIC, minLevel, minChampionPoints, referenceEnchantID) end
		if referenceQuality ~= ITEM_QUALITY_ARCANE then superiorItemLink = GetQualityItemLink(itemId, ITEM_QUALITY_ARCANE, minLevel, minChampionPoints, referenceEnchantID) end
		if referenceQuality ~= ITEM_QUALITY_ARTIFACT then epicItemLink = GetQualityItemLink(itemId, ITEM_QUALITY_ARTIFACT, minLevel, minChampionPoints, referenceEnchantID) end
		if referenceQuality ~= ITEM_QUALITY_LEGENDARY then legendaryItemLink = GetQualityItemLink(itemId, ITEM_QUALITY_LEGENDARY, minLevel, minChampionPoints, referenceEnchantID) end
	
		-- Additional check to make sure the item link returned is the quality we're looking for
		if normalItemLink and GetItemLinkQuality(normalItemLink) ~= ITEM_QUALITY_NORMAL then normalItemLink = nil end
		if fineItemLink and GetItemLinkQuality(fineItemLink) ~= ITEM_QUALITY_MAGIC then fineItemLink = nil end
		if superiorItemLink and GetItemLinkQuality(superiorItemLink) ~= ITEM_QUALITY_ARCANE then superiorItemLink = nil end
		if epicItemLink and GetItemLinkQuality(epicItemLink) ~= ITEM_QUALITY_ARTIFACT then epicItemLink = nil end
		if legendaryItemLink and GetItemLinkQuality(legendaryItemLink) ~= ITEM_QUALITY_LEGENDARY then legendaryItemLink = nil end
		
	end	

	return resultItemLink, normalItemLink, fineItemLink, superiorItemLink, epicItemLink, legendaryItemLink

end
local function GetBuyInfo(tblBuyingItems, itemUID, itemLink)
	local strBuyInfo = ""
	local guildName = tblBuyingItems[itemUID]["guildName"]
	local buyingTime = colors.COLOR_WHITE:Colorize(KelaTimeStampToDateTimeString(tblBuyingItems[itemUID]["buyingTimeStamp"]))
	local buyPrice = tblBuyingItems[itemUID]["buyPrice"]
	local buyPricePerUnit = tblBuyingItems[itemUID]["buyPricePerUnit"]
	local buyStackCount = KelaLocalizedFormatNumber(buyPrice/buyPricePerUnit)
	local iconCoin = zo_iconFormat(GetCurrencyGamepadIcon(CURT_MONEY), 20, 20)
	strBuyInfo = "* "..GetString(KELA_TRADING_BOUGHT)..buyingTime..GetString(KELA_TRADING_BOUGHT_FOR)..colors.COLOR_WHITE:Colorize(KelaLocalizedFormatNumber(buyPrice)..iconCoin)
		strBuyInfo = strBuyInfo.." ("..buyStackCount.."*"..KelaLocalizedFormatNumber(buyPricePerUnit)..")"
	if guildName ~= "" then
		local guildColor = colors.COLOR_WHITE
		if ArkadiusTradeTools ~= nil then
			guildColor = ArkadiusTradeTools:GetGuildColor(guildName)
		end
		guildName = guildColor:Colorize(guildName)					
		strBuyInfo = strBuyInfo.." in guild "..guildName
	end

	local colorQuality
	local displayQuality = tblBuyingItems[itemUID]["displayQuality"]
	local itemType = itemLink and GetItemLinkItemType(itemLink)
	if displayQuality and (itemType == ITEMTYPE_ARMOR or itemType == ITEMTYPE_WEAPON) then 
		colorQuality = GetItemQualityColor(displayQuality) 
		strBuyInfo = strBuyInfo.." ("..colorQuality:Colorize(GetString("SI_ITEMDISPLAYQUALITY", displayQuality))..")"
	end	
	return strBuyInfo
end
local function HideTradingTooltipControls()
	if ctlItemTypeGuildStat then ctlItemTypeGuildStat:SetHidden(true) end	
	if ctlTradingInfo then ctlTradingInfo:SetHidden(true) end						
	if KPUI_ATTGraph then KPUI_ATTGraph:SetHidden(true) end	
	if ctlPreviousListings then ctlPreviousListings:SetHidden(true) end		
	if ctlOtherQualityInfo then ctlOtherQualityInfo:SetHidden(true) end				
	if ctlProductMaterialInfoRow then ctlProductMaterialInfoRow:SetHidden(true) end	
	if ctlCraftingInfo then ctlCraftingInfo:SetHidden(true) end			
end
local function HideImprovementTooltipControls(hide)
	local function hideSource()
		if ctlSourceInfo then ctlSourceInfo:SetHidden(true) end	
		if ctlSourceGraph then ctlSourceGraph:SetHidden(true) end					
		if ctlSourceNotes then ctlSourceNotes:SetHidden(true) end
		if ctlSourceListings then ctlSourceListings:SetHidden(true) end	
		if ctlSourceOther then ctlSourceOther:SetHidden(true) end	
	end
	local function hideResult()
		if ctlResultInfo then ctlResultInfo:SetHidden(true) end						
		if ctlResultGraph then ctlResultGraph:SetHidden(true) end	
		if ctlResultNotes then ctlResultNotes:SetHidden(true) end
		if ctlResultListings then ctlResultListings:SetHidden(true) end	
		if ctlResultOther then ctlResultOther:SetHidden(true) end	
	end
	if hide == "source" then
		hideSource()
	elseif hide == "result" then
		hideResult()
	else
		hideSource()
		hideResult()
	end
end
local function HideProvisionerTooltipControls()
	if ctlProvisionerInfo then ctlProvisionerInfo:SetHidden(true) end	
	if ctlProvisionerGraph then ctlProvisionerGraph:SetHidden(true) end						
	if ctlProvisionerListings then ctlProvisionerListings:SetHidden(true) end				
end
local function HideCreationTooltipControls()
	if ctlCreationInfo then ctlCreationInfo:SetHidden(true) end	
	if ctlCreationGraph then ctlCreationGraph:SetHidden(true) end						
	if ctlCreationListings then ctlCreationListings:SetHidden(true) end					
	if ctlCreationOther then ctlCreationOther:SetHidden(true) end				
end
local function HideAlchemyTooltipControls()
	if ctlAlchemyInfo then ctlAlchemyInfo:SetHidden(true) end	
	if ctlAlchemyGraph then ctlAlchemyGraph:SetHidden(true) end						
	if ctlAlchemyListings then ctlAlchemyListings:SetHidden(true) end					
end
local function HideEnchantingTooltipControls()
	if ctlEnchantingInfo then ctlEnchantingInfo:SetHidden(true) end	
	if ctlEnchantingGraph then ctlEnchantingGraph:SetHidden(true) end						
	if ctlEnchantingListings then ctlEnchantingListings:SetHidden(true) end	
	if ctlEnchantingOther then ctlEnchantingOther:SetHidden(true) end		
end
local function ResetProvisionerTradingTooltip()
	if ctlProvisionerTooltip then
		ctlProvisionerTooltip.tip:ClearLines()
		ctlProvisionerTooltip:SetHidden(true)
	end
	HideProvisionerTooltipControls()
end
local function ResetCreationTradingTooltip()
	if ctlCreationTooltip then
		ctlCreationTooltip.tip:ClearLines()
		ctlCreationTooltip:SetHidden(true)
	end
	HideCreationTooltipControls()
end

-- functions that add modules to the information window
local function AddClearLine(tooltip, lastControl, x, y)
	-- empty line
	if not x then x = 0 end
	if not y then y = 0 end
	local bodySection = tooltip:AcquireSection(tooltip:GetStyle("bodySection1"))
	bodySection:AddLine(" ")
	tooltip:AddSection(bodySection)
	bodySection:ClearAnchors()
	bodySection:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT, x, y)
	bodySection:SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT, x, y)					
	return bodySection
end
local function SetSmithTradingInfo (ctlSmithTradingInfo, lastControl, priceInfoTTC, priceInfoATT, currentScene, selectedData, stackCount)
	ctlSmithTradingInfo:ClearAnchors()
	ctlSmithTradingInfo:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT, 0, 15)
	ctlSmithTradingInfo:SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT, 0, 15)
	ctlSmithTradingInfo:SetHidden(false)
	return ctlSmithTradingInfo.SetItemInfo(priceInfoTTC, priceInfoATT, currentScene, selectedData, stackCount)
end
local function SetSmithGraph (ctlSmithGraph, lastControl, itemLink, priceInfoTTC, priceInfoATT, stackCount)
	if not ArkadiusTradeTools or not ctlSmithGraph.object then
		ctlSmithGraph:SetHidden(true)
		return lastControl
	end
	ctlSmithGraph:ClearAnchors()
	ctlSmithGraph:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT, 10, 0)
	ctlSmithGraph:SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT, -10, 0)
	KelaUpdateATTGraph(itemLink, ctlSmithGraph, priceInfoATT.SuggestedPrice, priceInfoTTC.SuggestedPrice)
	ctlSmithGraph:SetHidden(false)
	local stackCountGuild
	if priceInfoATT.Vouchers ~= 0 then
		stackCountGuild = priceInfoATT.Vouchers
	else
		stackCountGuild = stackCount
	end
	return ctlSmithGraph.SetGuildSalesInfo(priceInfoATT.GuildsInfo, priceInfoATT.GuildsPrice, stackCountGuild, ctlSmithGraph)	
end
local function SetSmithNotes (tooltip, lastControl, strBuyInfo, ModFontSize)
	if not ModFontSize then ModFontSize = 20 end
	local bodySection = tooltip:AcquireSection(tooltip:GetStyle("bodySection1"))
	bodySection:AddLine(strBuyInfo, {fontSize = ModFontSize})
	tooltip:AddSection(bodySection)
	bodySection:ClearAnchors()
	bodySection:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT, 0, 0)
	bodySection:SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT, 0, 0)					
	return bodySection
end
local function SetSmithListings (ctlSmithListings, lastControl, listingItemsTable)
	ctlSmithListings:SetHidden(false)					
	return ctlSmithListings.SetPreviousListings(listingItemsTable, lastControl)
end
local function SetSmithQualityPrices(tooltip, ctlSmithOQInfo, lastControl, itemLink, normalItemLink, fineItemLink, superiorItemLink, epicItemLink, legendaryItemLink) --, traitInformation, tooltip)
	lastControl = AddClearLine(tooltip, lastControl, 0, 15)
	ctlSmithOQInfo:SetHidden(false)	
	return ctlSmithOQInfo.SetOtherQualityPrices(itemLink, normalItemLink, fineItemLink, superiorItemLink, epicItemLink, legendaryItemLink, lastControl)
end
local function SetProductionPrices(ctlProductionInfo, lastControl, resultItemLink, priceInfoTTC, priceInfoATT)
	ctlProductionInfo:SetHidden(false)	
	return ctlProductionInfo.SetRawProductPrices(resultItemLink, priceInfoTTC, priceInfoATT, lastControl)
end
local function SetCraftingComponents(ctlCraftingInfo, lastControl, craftingComponentPrices)
	ctlCraftingInfo:SetHidden(false)	
	return ctlCraftingInfo.SetItemPrices(craftingComponentPrices, lastControl)
end

--check the setting and the trading module
local function IsKPUITradingHouseSettingEnabled(setting)
	if setting then 
		return KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_ENABLED)	and KelaGetSetting_Bool(SETTING_TYPE_KELA, setting)		
	else
		return KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_ENABLED)
	end
end

KPUI_TRADINGHOUSE.colors = colors
KPUI_TRADINGHOUSE.KelaGetATTSalesSecondsPerDay = KelaGetATTSalesSecondsPerDay
KPUI_TRADINGHOUSE.KelaCreateColorizedResumePrice = KelaCreateColorizedResumePrice
KPUI_TRADINGHOUSE.GetItemLinks = GetItemLinks
KPUI_TRADINGHOUSE.GetBuyInfo = GetBuyInfo
KPUI_TRADINGHOUSE.HideTradingTooltipControls = HideTradingTooltipControls
KPUI_TRADINGHOUSE.HideImprovementTooltipControls = HideImprovementTooltipControls
KPUI_TRADINGHOUSE.HideProvisionerTooltipControls = HideProvisionerTooltipControls
KPUI_TRADINGHOUSE.HideCreationTooltipControls = HideCreationTooltipControls
KPUI_TRADINGHOUSE.HideAlchemyTooltipControls = HideAlchemyTooltipControls
KPUI_TRADINGHOUSE.HideEnchantingTooltipControls = HideEnchantingTooltipControls
KPUI_TRADINGHOUSE.ResetProvisionerTradingTooltip = ResetProvisionerTradingTooltip
KPUI_TRADINGHOUSE.ResetCreationTradingTooltip = ResetCreationTradingTooltip
KPUI_TRADINGHOUSE.AddClearLine = AddClearLine
KPUI_TRADINGHOUSE.SetSmithTradingInfo = SetSmithTradingInfo
KPUI_TRADINGHOUSE.SetSmithGraph = SetSmithGraph
KPUI_TRADINGHOUSE.SetSmithNotes = SetSmithNotes
KPUI_TRADINGHOUSE.SetSmithListings = SetSmithListings
KPUI_TRADINGHOUSE.SetSmithQualityPrices = SetSmithQualityPrices
KPUI_TRADINGHOUSE.SetProductionPrices = SetProductionPrices
KPUI_TRADINGHOUSE.SetCraftingComponents = SetCraftingComponents
KPUI_TRADINGHOUSE.IsKPUITradingHouseSettingEnabled = IsKPUITradingHouseSettingEnabled
