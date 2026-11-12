-- KelaPadUI trading-house tooltip layouts.

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

function ZO_Tooltip:LayoutEnchantingTradingTooltip(tooltip, itemLink, maxIterations, itemUniqueId)
    local icon = GetItemLinkIcon(itemLink)

	tooltip.scrollTooltip:ResetToTop()
	tooltip.tip:ClearLines()
	tooltip = tooltip.tip
	local lastControl

	local stackCount = maxIterations
	if not stackCount then stackCount = 1 end
	
    if itemLink and itemLink ~= "" then
        if tooltip.icon then
            tooltip.icon:SetTexture(icon)
            tooltip.icon:SetHidden(false)
        end

		local bodySection = tooltip:AcquireSection(tooltip:GetStyle("bodySection1"))
		bodySection:AddLine(GetString(KELA_TRADING_TRADING_INFO))
		bodySection:AddLine(" ")
		tooltip:AddSection(bodySection)
		lastControl = bodySection
		
		local listingItemsTable = KelaGetItemLinkListingTable(itemLink)
		local trueTTC, trueATT, priceInfoTTC, priceInfoATT = KelaGetPriceInfoTTCATT(itemLink)
		-- Purchased item information
		local isByingItem = false
		local tblBuyingItems = {}
		local itemUID
		if itemUniqueId then
			tblBuyingItems = kpuiSVBuyingData["buyingTable"]			
			itemUID = Id64ToString(itemUniqueId)
			if tblBuyingItems[itemUID] ~= nil then
				isByingItem = true
			end
		end	
		-- basic information
		if trueTTC or trueATT then
			if not ctlEnchantingInfo then ctlEnchantingInfo = CreateControlFromVirtual("$(parent)Info", tooltip, "KPUI_MainInfo") end	
			local _, isTwoRowFooter
			lastControl, _, isTwoRowFooter = SetSmithTradingInfo(ctlEnchantingInfo, lastControl, priceInfoTTC, priceInfoATT, nil, nil, stackCount)
			local offsetY = 15
			if isTwoRowFooter and IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_ATTINFO) then offsetY = 35 end
			lastControl = AddClearLine(tooltip, lastControl, 0, offsetY)
			if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_ATTINFO) then
				if not ctlEnchantingGraph then ctlEnchantingGraph = CreateControlFromVirtual("$(parent)Graph", tooltip, "KPUI_Graph") end							
				lastControl = SetSmithGraph (ctlEnchantingGraph, lastControl, itemLink, priceInfoTTC, priceInfoATT, stackCount)		
			else
				if ctlEnchantingGraph then ctlEnchantingGraph:SetHidden(true) end	
			end
		else
			local bodySection = tooltip:AcquireSection(tooltip:GetStyle("bodySection1"))
			bodySection:AddLine(GetString(KELA_TRADING_TRADING_NOTINFO))
			tooltip:AddSection(bodySection)
			bodySection:ClearAnchors()
			bodySection:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT, 0, 0)
			bodySection:SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT, 0, 0)					
			lastControl = bodySection
			lastControl = AddClearLine(tooltip, lastControl, 0, 0)
			if ctlEnchantingInfo then ctlEnchantingInfo:SetHidden(true) end	
			if ctlEnchantingGraph then ctlEnchantingGraph:SetHidden(true) end	
		end
		-- Purchased item information
		if isByingItem then
			local strBuyInfo = GetBuyInfo(tblBuyingItems, itemUID, itemLink)
			lastControl = SetSmithNotes(tooltip, lastControl, strBuyInfo)			
		end	
		-- Previous sales
		if next(listingItemsTable) ~= nil and IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_LISTINGS) then
			if not ctlEnchantingListings then ctlEnchantingListings = CreateControlFromVirtual("$(parent)Listings", tooltip, "KPUI_PreviousListings") end	
			lastControl = SetSmithListings(ctlEnchantingListings, lastControl, listingItemsTable)
			lastControl = AddClearLine(tooltip, lastControl, 0, -15)	
		else
			if ctlEnchantingListings then ctlEnchantingListings:SetHidden(true) end	
		end	
	else
		HideEnchantingTooltipControls()				
    end

end

function ZO_Tooltip:LayoutAlchemyTradingTooltip(tooltip, itemLink, maxIterations)
    local icon = GetItemLinkIcon(itemLink)

	tooltip.scrollTooltip:ResetToTop()
	tooltip.tip:ClearLines()
	tooltip = tooltip.tip
	local lastControl

	local stackCount = maxIterations
	if not stackCount then stackCount = 1 end
	
    if itemLink and itemLink ~= "" then
        if tooltip.icon then
            tooltip.icon:SetTexture(icon)
            tooltip.icon:SetHidden(false)
        end

		local bodySection = tooltip:AcquireSection(tooltip:GetStyle("bodySection1"))
		bodySection:AddLine(GetString(KELA_TRADING_TRADING_INFO))
		bodySection:AddLine(" ")
		tooltip:AddSection(bodySection)
		lastControl = bodySection
		
		local listingItemsTable = KelaGetItemLinkListingTable(itemLink)
		local trueTTC, trueATT, priceInfoTTC, priceInfoATT = KelaGetPriceInfoTTCATT(itemLink)

		-- basic information
		if trueTTC or trueATT then
			if not ctlAlchemyInfo then ctlAlchemyInfo = CreateControlFromVirtual("$(parent)Info", tooltip, "KPUI_MainInfo") end	
			local _, isTwoRowFooter
			lastControl, _, isTwoRowFooter = SetSmithTradingInfo(ctlAlchemyInfo, lastControl, priceInfoTTC, priceInfoATT, nil, nil, stackCount)
			local offsetY = 15
			if isTwoRowFooter and IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_ATTINFO) then offsetY = 35 end
			lastControl = AddClearLine(tooltip, lastControl, 0, offsetY)
			if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_ATTINFO) then
				if not ctlAlchemyGraph then ctlAlchemyGraph = CreateControlFromVirtual("$(parent)Graph", tooltip, "KPUI_Graph") end							
				lastControl = SetSmithGraph (ctlAlchemyGraph, lastControl, itemLink, priceInfoTTC, priceInfoATT, stackCount)			
			else
				if ctlAlchemyGraph then ctlAlchemyGraph:SetHidden(true) end	
			end
		else
			local bodySection = tooltip:AcquireSection(tooltip:GetStyle("bodySection1"))
			bodySection:AddLine(GetString(KELA_TRADING_TRADING_NOTINFO))
			tooltip:AddSection(bodySection)
			bodySection:ClearAnchors()
			bodySection:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT, 0, 0)
			bodySection:SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT, 0, 0)					
			lastControl = bodySection
			lastControl = AddClearLine(tooltip, lastControl, 0, 0)
			if ctlAlchemyInfo then ctlAlchemyInfo:SetHidden(true) end	
			if ctlAlchemyGraph then ctlAlchemyGraph:SetHidden(true) end	
		end
		-- Previous sales
		if next(listingItemsTable) ~= nil and IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_LISTINGS) then
			if not ctlAlchemyListings then ctlAlchemyListings = CreateControlFromVirtual("$(parent)Listings", tooltip, "KPUI_PreviousListings") end	
			lastControl = SetSmithListings(ctlAlchemyListings, lastControl, listingItemsTable)
			lastControl = AddClearLine(tooltip, lastControl, 0, -15)	
		else
			if ctlAlchemyListings then ctlAlchemyListings:SetHidden(true) end	
		end	
	else
		HideAlchemyTooltipControls()				
    end

end

function ZO_Tooltip:LayoutProvisionerTradingTooltip(tooltip, recipeListIndex, recipeIndex, selectedData)
    local _, icon = GetRecipeResultItemInfo(recipeListIndex, recipeIndex)
    local itemLink = GetRecipeResultItemLink(recipeListIndex, recipeIndex)

	tooltip.scrollTooltip:ResetToTop()
	tooltip.tip:ClearLines()
	tooltip = tooltip.tip
	local lastControl

	local stackCount = selectedData and selectedData.stackCount
	if not stackCount then stackCount = 1 end
	
    if itemLink and itemLink ~= "" then
        if tooltip.icon then
            tooltip.icon:SetTexture(icon)
            tooltip.icon:SetHidden(false)
        end

		local bodySection = tooltip:AcquireSection(tooltip:GetStyle("bodySection1"))
		bodySection:AddLine(GetString(KELA_TRADING_TRADING_INFO))
		bodySection:AddLine(" ")
		tooltip:AddSection(bodySection)
		lastControl = bodySection
	
		local listingItemsTable = KelaGetItemLinkListingTable(itemLink)
		local trueTTC, trueATT, priceInfoTTC, priceInfoATT = KelaGetPriceInfoTTCATT(itemLink)

		-- basic information
		if trueTTC or trueATT then
			if not ctlProvisionerInfo then ctlProvisionerInfo = CreateControlFromVirtual("$(parent)ProvInfo", tooltip, "KPUI_MainInfo") end	
			local _, isTwoRowFooter
			lastControl, _, isTwoRowFooter = SetSmithTradingInfo(ctlProvisionerInfo, lastControl, priceInfoTTC, priceInfoATT, nil, selectedData, stackCount)
			local offsetY = 15
			if isTwoRowFooter and IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_ATTINFO) then offsetY = 35 end
			lastControl = AddClearLine(tooltip, lastControl, 0, offsetY)
			if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_ATTINFO) then
				if not ctlProvisionerGraph then ctlProvisionerGraph = CreateControlFromVirtual("$(parent)ProvGraph", tooltip, "KPUI_Graph") end							
				lastControl = SetSmithGraph (ctlProvisionerGraph, lastControl, itemLink, priceInfoTTC, priceInfoATT, stackCount)
			else
				if ctlProvisionerGraph then ctlProvisionerGraph:SetHidden(true) end	
			end
		else
			local bodySection = tooltip:AcquireSection(tooltip:GetStyle("bodySection1"))
			bodySection:AddLine(GetString(KELA_TRADING_TRADING_NOTINFO))
			tooltip:AddSection(bodySection)
			bodySection:ClearAnchors()
			bodySection:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT, 0, 0)
			bodySection:SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT, 0, 0)					
			lastControl = bodySection
			lastControl = AddClearLine(tooltip, lastControl, 0, 0)
			if ctlProvisionerInfo then ctlProvisionerInfo:SetHidden(true) end	
			if ctlProvisionerGraph then ctlProvisionerGraph:SetHidden(true) end	
		end
		-- Previous sales
		if next(listingItemsTable) ~= nil and IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_LISTINGS) then
			if not ctlProvisionerListings then ctlProvisionerListings = CreateControlFromVirtual("$(parent)SListings", tooltip, "KPUI_PreviousListings") end	
			lastControl = SetSmithListings(ctlProvisionerListings, lastControl, listingItemsTable)
			lastControl = AddClearLine(tooltip, lastControl, 0, -15)	
		else
			if ctlProvisionerListings then ctlProvisionerListings:SetHidden(true) end	
		end	
	else
		HideProvisionerTooltipControls()				
    end

end

function ZO_Tooltip:LayoutSmithingCreationTooltip(tooltip, itemLink)

	tooltip.scrollTooltip:ResetToTop()
	tooltip.tip:ClearLines()
	tooltip = tooltip.tip
	local lastControl
	
    local icon = GetItemLinkIcon(itemLink)

    if itemLink and itemLink ~= "" then

	
		if tooltip.icon then
            tooltip.icon:SetTexture(icon)
            tooltip.icon:SetHidden(false)
        end

		local _, normalItemLink, fineItemLink, superiorItemLink, epicItemLink, legendaryItemLink = GetItemLinks(itemLink, IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_QUALITY))
		local listingItemsTable = KelaGetItemLinkListingTable(itemLink)
		local trueTTC, trueATT, priceInfoTTC, priceInfoATT = KelaGetPriceInfoTTCATT(itemLink)

		local bodySection = tooltip:AcquireSection(tooltip:GetStyle("bodySection1"))
		bodySection:AddLine(GetString(KELA_TRADING_TRADING_INFO))
		bodySection:AddLine(" ")
		tooltip:AddSection(bodySection)
		lastControl = bodySection
		
		-- basic information
		if trueTTC or trueATT then
			if not ctlCreationInfo then ctlCreationInfo = CreateControlFromVirtual("$(parent)Info", tooltip, "KPUI_MainInfo") end	
			lastControl = SetSmithTradingInfo(ctlCreationInfo, lastControl, priceInfoTTC, priceInfoATT)
			lastControl = AddClearLine(tooltip, lastControl, 0, 15)
			if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_ATTINFO) then
				if not ctlCreationGraph then ctlCreationGraph = CreateControlFromVirtual("$(parent)Graph", tooltip, "KPUI_Graph") end							
				lastControl = SetSmithGraph (ctlCreationGraph, lastControl, itemLink, priceInfoTTC, priceInfoATT, 1)
			else
				if ctlCreationGraph then ctlCreationGraph:SetHidden(true) end	
			end
		else
			local bodySection = tooltip:AcquireSection(tooltip:GetStyle("bodySection1"))
			bodySection:AddLine(GetString(KELA_TRADING_TRADING_NOTINFO))
			tooltip:AddSection(bodySection)
			bodySection:ClearAnchors()
			bodySection:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT, 0, 0)
			bodySection:SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT, 0, 0)					
			lastControl = bodySection
			lastControl = AddClearLine(tooltip, lastControl, 0, 0)
			if ctlCreationInfo then ctlCreationInfo:SetHidden(true) end	
			if ctlCreationGraph then ctlCreationGraph:SetHidden(true) end
		end		
		-- Previous sales
		if next(listingItemsTable) ~= nil and IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_LISTINGS) then
			if not ctlCreationListings then ctlCreationListings = CreateControlFromVirtual("$(parent)Listings", tooltip, "KPUI_PreviousListings") end	
			lastControl = SetSmithListings(ctlCreationListings, lastControl, listingItemsTable)
			lastControl = AddClearLine(tooltip, lastControl, 0, -15)	
		else
			if ctlCreationListings then ctlCreationListings:SetHidden(true) end	
		end	
		-- Other item quality
		if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_QUALITY) and (normalItemLink or fineItemLink or superiorItemLink or epicItemLink or legendaryItemLink) then
			local notSuccess
			if not ctlCreationOther then ctlCreationOther = CreateControlFromVirtual("$(parent)Other", tooltip, "KPUI_OtherQualityInfo") end	
			lastControl, notSuccess = SetSmithQualityPrices(tooltip, ctlCreationOther, lastControl, itemLink, normalItemLink, fineItemLink, superiorItemLink, epicItemLink, legendaryItemLink)
			if notSuccess then 
				if ctlCreationOther then ctlCreationOther:SetHidden(true) end	
			else
				lastControl = AddClearLine(tooltip, lastControl, 0, -15)	
			end
		else
			if ctlCreationOther then ctlCreationOther:SetHidden(true) end	
		end		
	else
		HideCreationTooltipControls()
	end
	

end

function ZO_Tooltip:LayoutSmithingTradingTooltip(tooltip, itemBagId, itemSlotIndex, craftingSkillType, itemUniqueId, selectedData)

	tooltip.scrollTooltip:ResetToTop()
	tooltip.tip:ClearLines()
	tooltip = tooltip.tip
	local lastControl
    local itemLink, icon
	local hide
	if craftingSkillType then 
		hide = "result"
		itemLink = GetSmithingImprovedItemLink(itemBagId, itemSlotIndex, craftingSkillType) 
		_, icon = GetSmithingImprovedItemInfo(itemBagId, itemSlotIndex, craftingSkillType)
	else
		hide = "source"
		itemLink = GetItemLink(itemBagId, itemSlotIndex)
		icon = GetItemLinkIcon(itemLink)
	end

    if itemLink and itemLink ~= "" then

	
		if tooltip.icon then
            tooltip.icon:SetTexture(icon)
            tooltip.icon:SetHidden(false)
        end

		if not IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_CRAFTING) then
			KELA_SMITHING_IMPROVED_TOOLTIP_TYPE = 0
		end
	
		
		if KELA_SMITHING_IMPROVED_TOOLTIP_TYPE == 0 then
			HideImprovementTooltipControls()
			if craftingSkillType then 
				tooltip:LayoutImproveResultSmithingItem(itemBagId, itemSlotIndex, craftingSkillType)
			else
				tooltip:LayoutImproveSourceSmithingItem(itemBagId, itemSlotIndex)
			end			
		elseif KELA_SMITHING_IMPROVED_TOOLTIP_TYPE == 1 then
		
			local _, normalItemLink, fineItemLink, superiorItemLink, epicItemLink, legendaryItemLink = GetItemLinks(itemLink, IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_QUALITY))
			local listingItemsTable = KelaGetItemLinkListingTable(itemLink)
			local trueTTC, trueATT, priceInfoTTC, priceInfoATT = KelaGetPriceInfoTTCATT(itemLink)

			-- add the item name
			local name = GetItemLinkName(itemLink)
			-- Purchased item information
			local isByingItem = false
			local tblBuyingItems = {}
			local itemUID
			if itemUniqueId then
				tblBuyingItems = kpuiSVBuyingData["buyingTable"]			
				itemUID = Id64ToString(itemUniqueId)
				if tblBuyingItems[itemUID] ~= nil then
					name = name.." *"
					isByingItem = true
				end
			end		
			tooltip:AddItemTitle(itemLink, name)
			
			local bodySection = tooltip:AcquireSection(tooltip:GetStyle("bodySection1"))
			bodySection:AddLine(" ")
			tooltip:AddSection(bodySection)
			lastControl = bodySection

			-- basic information
			if trueTTC or trueATT then
				if craftingSkillType then -- result tooltip
					if not ctlResultInfo then ctlResultInfo = CreateControlFromVirtual("$(parent)RInfo", tooltip, "KPUI_MainInfo") end	
					lastControl = SetSmithTradingInfo(ctlResultInfo, lastControl, priceInfoTTC, priceInfoATT, nil, selectedData)
					lastControl = AddClearLine(tooltip, lastControl, 0, 15)
					if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_ATTINFO) then
						if not ctlResultGraph then ctlResultGraph = CreateControlFromVirtual("$(parent)RGraph", tooltip, "KPUI_Graph") end							
						lastControl = SetSmithGraph (ctlResultGraph, lastControl, itemLink, priceInfoTTC, priceInfoATT, 1)
					else
						if ctlResultGraph then ctlResultGraph:SetHidden(true) end	
					end
				else
					if not ctlSourceInfo then ctlSourceInfo = CreateControlFromVirtual("$(parent)SInfo", tooltip, "KPUI_MainInfo") end	
					lastControl = SetSmithTradingInfo(ctlSourceInfo, lastControl, priceInfoTTC, priceInfoATT, nil, selectedData)
					lastControl = AddClearLine(tooltip, lastControl, 0, 15)
					if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_ATTINFO) then
						if not ctlSourceGraph then ctlSourceGraph = CreateControlFromVirtual("$(parent)SGraph", tooltip, "KPUI_Graph") end							
						lastControl = SetSmithGraph (ctlSourceGraph, lastControl, itemLink, priceInfoTTC, priceInfoATT, 1)
					else
						if ctlSourceGraph then ctlSourceGraph:SetHidden(true) end	
					end
				end
			else
				local bodySection = tooltip:AcquireSection(tooltip:GetStyle("bodySection1"))
				bodySection:AddLine(GetString(KELA_TRADING_TRADING_NOTINFO))
				tooltip:AddSection(bodySection)
				bodySection:ClearAnchors()
				bodySection:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT, 0, 0)
				bodySection:SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT, 0, 0)					
				lastControl = bodySection
				lastControl = AddClearLine(tooltip, lastControl, 0, 0)
				if hide == "source" then
					if ctlSourceInfo then ctlSourceInfo:SetHidden(true) end	
					if ctlSourceGraph then ctlSourceGraph:SetHidden(true) end					
				elseif hide == "result" then
					if ctlResultInfo then ctlResultInfo:SetHidden(true) end						
					if ctlResultGraph then ctlResultGraph:SetHidden(true) end
				end				
			end
			-- Purchased item information
			if isByingItem then
				local strBuyInfo = GetBuyInfo(tblBuyingItems, itemUID, itemLink)
				lastControl = SetSmithNotes(tooltip, lastControl, strBuyInfo)			
			end					
			-- Previous sales
			if next(listingItemsTable) ~= nil and IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_LISTINGS) then
				if craftingSkillType then -- result tooltip
					if not ctlResultListings then ctlResultListings = CreateControlFromVirtual("$(parent)RListings", tooltip, "KPUI_PreviousListings") end	
					lastControl = SetSmithListings(ctlResultListings, lastControl, listingItemsTable)
				else
					if not ctlSourceListings then ctlSourceListings = CreateControlFromVirtual("$(parent)SListings", tooltip, "KPUI_PreviousListings") end	
					lastControl = SetSmithListings(ctlSourceListings, lastControl, listingItemsTable)
				end
				lastControl = AddClearLine(tooltip, lastControl, 0, -15)	
			else
				if hide == "source" then
					if ctlSourceListings then ctlSourceListings:SetHidden(true) end	
				elseif hide == "result" then
					if ctlResultListings then ctlResultListings:SetHidden(true) end	
				end	
			end	
			-- Other item quality
			if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_QUALITY) and (normalItemLink or fineItemLink or superiorItemLink or epicItemLink or legendaryItemLink) then
				local notSuccess
				if craftingSkillType then -- result tooltip
					if not ctlResultOther then ctlResultOther = CreateControlFromVirtual("$(parent)ROther", tooltip, "KPUI_OtherQualityInfo") end	
					lastControl, notSuccess = SetSmithQualityPrices(tooltip, ctlResultOther, lastControl, itemLink, normalItemLink, fineItemLink, superiorItemLink, epicItemLink, legendaryItemLink) --, traitInformation, tooltip)
				else
					if not ctlSourceOther then ctlSourceOther = CreateControlFromVirtual("$(parent)SOther", tooltip, "KPUI_OtherQualityInfo") end	
					lastControl, notSuccess = SetSmithQualityPrices(tooltip, ctlSourceOther, lastControl, itemLink, normalItemLink, fineItemLink, superiorItemLink, epicItemLink, legendaryItemLink) --, traitInformation, tooltip)
				end
				if notSuccess then 
					if hide == "source" then
						if ctlSourceOther then ctlSourceOther:SetHidden(true) end	
					elseif hide == "result" then
						if ctlResultOther then ctlResultOther:SetHidden(true) end		
					end	
				else
					lastControl = AddClearLine(tooltip, lastControl, 0, -15)	
				end
			else
				if hide == "source" then
					if ctlSourceOther then ctlSourceOther:SetHidden(true) end	
				elseif hide == "result" then
					if ctlResultOther then ctlResultOther:SetHidden(true) end		
				end	
			end		
		else
			HideImprovementTooltipControls(hide)
		end
	else
		HideImprovementTooltipControls(hide)				
    end

	if craftingSkillType then -- result tooltip
		--Add line for tradeable loss
		if IsItemBoPAndTradeable(itemBagId, itemSlotIndex) then
			local section = tooltip:AcquireSection(tooltip:GetStyle("bodySection"))
			section:AddLine(GetString(SI_SMITHING_IMPROVEMENT_TRADE_BOP_WILL_BECOME_UNTRADEABLE), tooltip:GetStyle("bodyDescription"), tooltip:GetStyle("failed"))
			tooltip:AddSection(section)
		end
	end
	
end

function ZO_Tooltip:LayoutTradingTooltip(currentScene, itemLink, selectedData, tooltipType, parentControl, leftAnchor, offsetX, offsetY, itemUniqueId)


	KELA_TRADINGHOUSE_CURRENT_SELECTEDDATA = selectedData
	
	local isCrafting

	if currentScene == "GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS" and leftAnchor then
		KPUI_GAMEPAD_TOOLTIPS.tooltips.KPUI_GAMEPAD_TRADING_TOOLTIP.bgType = KPUI_GAMEPAD_TOOLTIP_DARK_BG	
	else
		KPUI_GAMEPAD_TOOLTIPS.tooltips.KPUI_GAMEPAD_TRADING_TOOLTIP.bgType = KPUI_GAMEPAD_TOOLTIP_NORMAL_BG
	end
	
	local currentSceneName = SCENE_MANAGER:GetCurrentScene():GetName()
	if currentSceneName ~= "tradingHousePreview_Gamepad" and not ITEM_PREVIEW_KEYBOARD:IsInteractionCameraPreviewEnabled() then

		if offsetX == nil then offsetX = 0 end
		if offsetY == nil then offsetY = 0 end


		local tooltypeTradingControl = KPUI_GAMEPAD_TOOLTIPS:GetTooltipInfo(tooltipType).control
		tooltypeTradingControl:ClearAnchors()
		if leftAnchor then 
			tooltypeTradingControl:SetAnchor(TOPRIGHT, parentControl, TOPLEFT, -offsetX, offsetY) 
			tooltypeTradingControl:SetAnchor(BOTTOMRIGHT, parentControl, BOTTOMLEFT, -offsetX, offsetY) 	
		else
			tooltypeTradingControl:SetAnchor(TOPLEFT, parentControl, TOPRIGHT, offsetX, offsetY) 
			tooltypeTradingControl:SetAnchor(BOTTOMLEFT, parentControl, BOTTOMRIGHT, offsetX, offsetY) 	
		end	

		local iconBank = zo_iconFormatInheritColor("esoui/art/icons/servicemappins/servicepin_bank.dds", 20, 20)
		local strGold = zo_strformat("|t20:20:<<3>>|t |<<1>> (<<2>>)|r ", ZO_CurrencyControl_FormatCurrency(GetCurrencyAmount(CURT_MONEY)), iconBank..ZO_CurrencyControl_FormatCurrency(GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_BANK)), GetCurrencyGamepadIcon(CURT_MONEY))
		local iconBag = zo_iconFormatInheritColor("EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_inventory.dds", 20, 20)
		local strBackpack = iconBag.." "..zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT, GetNumBagUsedSlots(BAG_BACKPACK), GetBagSize(BAG_BACKPACK))			
		local updatedString = ""
		if TamrielTradeCentre ~= nil and TamrielTradeCentrePrice ~= nil then
			updatedString = TamrielTradeCentrePrice:GetPriceTableUpdatedDateString()
		end
		
		-- Add Guild Name, Available Funds, and Inventory Capacity
		if KelaIsSceneTradingHouse(currentScene) then
			-- Shown in the Guild Trader
			local bodySection = self:AcquireSection(self:GetStyle("bodySection1"))
			local currentGuildId = GetSelectedTradingHouseGuildId()
			guildName = GetGuildName(currentGuildId)
			if currentGuildId and guildName ~= "" then
				local allianceId = GetGuildAlliance(currentGuildId)
				local icon = ZO_GetLargeAllianceSymbolIcon(allianceId)
				local guildColor = colors.COLOR_WHITE
				if ArkadiusTradeTools ~= nil then
					guildColor = ArkadiusTradeTools:GetGuildColor(guildName)
				end
				local currentListings, maxListings = GetTradingHouseListingCounts()
				guildName = zo_iconFormat(icon, 22, 22).." "..guildColor:Colorize(guildName.." ("..tostring(currentListings).."/"..tostring(maxListings)..")")
				bodySection:AddLine(colors.GENERAL_COLOR_NORMAL:Colorize(GetString(SI_GAMEPAD_GUILD_BANK_GUILD_FOOTER_LABEL))..": "..guildName, self:GetStyle("bodyHeader"))
			
			end
			bodySection:AddLine(colors.GENERAL_COLOR_NORMAL:Colorize(GetString(SI_GAMEPAD_GUILD_BANK_AVAILABLE_FUNDS))..": "..strGold, self:GetStyle("bodyHeader"))
			bodySection:AddLine(colors.GENERAL_COLOR_NORMAL:Colorize(GetString(SI_GAMEPAD_INVENTORY_CAPACITY))..": "..strBackpack, self:GetStyle("bodyHeader"))
			self:AddSection(bodySection)	
		else
		end


		-- Fill info when an item is selected
		local stackCount = selectedData and selectedData.stackCount
		if not stackCount then stackCount = 1 end
		local lastControl
		if itemLink then
			local listingItemsTable = KelaGetItemLinkListingTable(itemLink)
			local resultItemLink, normalItemLink, fineItemLink, superiorItemLink, epicItemLink, legendaryItemLink = GetItemLinks(itemLink, IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_QUALITY))
			-- the name of the thing
			local name = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(itemLink))
			local nameColor = GetItemQualityColor(GetItemLinkDisplayQuality(itemLink))
			local colorizedItemName = nameColor:Colorize(name)
			-- Information about the purchased item
			local isByingItem = false
			local tblBuyingItems = {}
			local itemUID
			if itemUniqueId then
				tblBuyingItems = kpuiSVBuyingData["buyingTable"]			
				itemUID = Id64ToString(itemUniqueId)
				if tblBuyingItems[itemUID] ~= nil then
					colorizedItemName = colorizedItemName.." *"
					isByingItem = true
				end
			end			
			local function AddTitle(lastControl)
				-- Adds the Item name
				local bodySection = self:AcquireSection(self:GetStyle("bodySection1"))
				bodySection:AddLine(colorizedItemName, self:GetStyle("title"))
				self:AddSection(bodySection)
				if lastControl then
					bodySection:ClearAnchors()
					bodySection:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT, 0, 10)
					bodySection:SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT, 0, 10)								
				end
				return bodySection			
			end

			-- information about the level of benefits in guilds by type of product	
			if ArkadiusTradeTools and KelaIsSceneTradingHouse(currentScene) and IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_GUILDSTAT) then
				local itemTradeCategory = KelaGetItemTradeCategory(itemLink)
				if KELA_ATT_GUILD_STAT[itemTradeCategory] then 
					local bodySection = self:AcquireSection(self:GetStyle("bodySection1"))
					bodySection:AddLine(colors.GENERAL_COLOR_NORMAL:Colorize(GetString(KELA_TRADING_TRADING_ITEMTYPE))..GetString("KELA_TRADING_ITEMTYPE_SALES_BYGUILDS", itemTradeCategory), self:GetStyle("bodyHeader"))
					self:AddSection(bodySection)			
					lastControl = bodySection
					lastControl = AddTitle(lastControl)
					if not ctlItemTypeGuildStat then ctlItemTypeGuildStat = CreateControlFromVirtual("$(parent)ctlItemTypeGuildStat", self, "KPUI_ItemTypeGuildStat") end	
					lastControl = ctlItemTypeGuildStat.SetItemTypeGuildStat(itemLink, itemTradeCategory, lastControl)
				else
					if ctlItemTypeGuildStat then ctlItemTypeGuildStat:SetHidden(true) end	
					lastControl = AddTitle()
				end
			else
				if ctlItemTypeGuildStat then ctlItemTypeGuildStat:SetHidden(true) end	
				lastControl = AddTitle()
			end
			
			-- basic information
			local trueTTC, trueATT, priceInfoTTC, priceInfoATT = KelaGetPriceInfoTTCATT(itemLink)
			if trueTTC or trueATT then
				if not ctlTradingInfo then ctlTradingInfo = CreateControlFromVirtual("$(parent)Info", self, "KPUI_MainInfo") end	
				local isTwoRowFooter
				lastControl, effectOfDeal, isTwoRowFooter = SetSmithTradingInfo(ctlTradingInfo, lastControl, priceInfoTTC, priceInfoATT, currentScene, selectedData, stackCount)
				local offsetY = 15
				if isTwoRowFooter and IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_ATTINFO) then offsetY = 35 end
				lastControl = AddClearLine(self, lastControl, 0, offsetY)
				if effectOfDeal and effectOfDeal ~= "" then
					SafeAddString(SI_GAMEPAD_TRADING_HOUSE_CONFIRM_BUY_DIALOG_TEXT, GetString(KELA_TRADING_TRADING_CONFIRM_BUY).."\n\n"..effectOfDeal, 1)
					SafeAddString(SI_GAMEPAD_TRADING_HOUSE_CONFIRM_BUY_MULTIPLE_DIALOG_TEXT, GetString(KELA_TRADING_TRADING_CONFIRM_BUY_MULT).."\n\n"..effectOfDeal, 0)
				end
				if ArkadiusTradeTools and IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_ATTINFO) then
					if not KPUI_ATTGraph then KPUI_ATTGraph = CreateControlFromVirtual("$(parent)ProvGraph", self, "KPUI_Graph") end							
					lastControl = SetSmithGraph (KPUI_ATTGraph, lastControl, itemLink, priceInfoTTC, priceInfoATT, stackCount)
				else
					if KPUI_ATTGraph then KPUI_ATTGraph:SetHidden(true) end	
				end
			else
				local bodySection = self:AcquireSection(self:GetStyle("bodySection1"))
				bodySection:AddLine(GetString(KELA_TRADING_TRADING_NOTINFO))
				self:AddSection(bodySection)
				bodySection:ClearAnchors()
				bodySection:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT, 0, 0)
				bodySection:SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT, 0, 0)					
				lastControl = bodySection
				lastControl = AddClearLine(self, lastControl, 0, 0)
				if ctlTradingInfo then ctlTradingInfo:SetHidden(true) end	
				if KPUI_ATTGraph then KPUI_ATTGraph:SetHidden(true) end	
			end

			-- Information about the purchased item
			if isByingItem then
				local strBuyInfo = GetBuyInfo(tblBuyingItems, itemUID, itemLink)
				lastControl = SetSmithNotes(self, lastControl, strBuyInfo)			
			end

			-- Previous sales
			if next(listingItemsTable) ~= nil and IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_LISTINGS) then
				if not ctlPreviousListings then ctlPreviousListings = CreateControlFromVirtual("$(parent)Listings", self, "KPUI_PreviousListings") end	
				lastControl = SetSmithListings(ctlPreviousListings, lastControl, listingItemsTable)
				lastControl = AddClearLine(self, lastControl, 0, -15)	
			else
				if ctlPreviousListings then ctlPreviousListings:SetHidden(true) end	
			end

			-- Another level of things
			if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_QUALITY) and (normalItemLink or fineItemLink or superiorItemLink or epicItemLink or legendaryItemLink) then
				local notSuccess
				if not ctlOtherQualityInfo then ctlOtherQualityInfo = CreateControlFromVirtual("$(parent)Other", self, "KPUI_OtherQualityInfo") end	
				lastControl, notSuccess = SetSmithQualityPrices(self, ctlOtherQualityInfo, lastControl, itemLink, normalItemLink, fineItemLink, superiorItemLink, epicItemLink, legendaryItemLink)
				if notSuccess then 
					if ctlOtherQualityInfo then ctlOtherQualityInfo:SetHidden(true) end	
				else
					lastControl = AddClearLine(self, lastControl, 0, -15)	
				end
			else
				if ctlOtherQualityInfo then ctlOtherQualityInfo:SetHidden(true) end	
			end

			-- Production
			if resultItemLink and IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_PRODUCTION) then
				local trueTTC, trueATT, priceInfoTTC, priceInfoATT = KelaGetPriceInfoTTCATT(resultItemLink)
				if trueTTC or trueATT then
					if not ctlProductMaterialInfoRow then ctlProductMaterialInfoRow = CreateControlFromVirtual("$(parent)ctlProductMaterialInfoRow", self, "KPUI_ProductMaterialInfo") end	
					lastControl = SetProductionPrices(ctlProductMaterialInfoRow, lastControl, resultItemLink, priceInfoTTC, priceInfoATT)
				else
					if ctlProductMaterialInfoRow then ctlProductMaterialInfoRow:SetHidden(true) end	
				end
			else
				if ctlProductMaterialInfoRow then ctlProductMaterialInfoRow:SetHidden(true) end	
			end

			-- crafting components table
			local isATTCraftingInfo, craftingComponentPrices = KelaGetCurrentATTCraftingInfo(itemLink)
			if isATTCraftingInfo and IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_COMPONENTS) then 
				if not ctlCraftingComponentsInfo then ctlCraftingComponentsInfo = CreateControlFromVirtual("$(parent)ctlCraftingInfo", self, "KPUI_CraftingInfo") end	
				SetCraftingComponents(ctlCraftingComponentsInfo, lastControl, craftingComponentPrices)
			else
				if ctlCraftingComponentsInfo then ctlCraftingComponentsInfo:SetHidden(true) end					
			end
			lastControl = AddClearLine(self, lastControl, 0, -15)	
		else
			HideTradingTooltipControls()
			KPUI_GAMEPAD_TOOLTIPS:HideTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP)	
		end
	else
		KPUI_GAMEPAD_TOOLTIPS:HideTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP)
	end
end
