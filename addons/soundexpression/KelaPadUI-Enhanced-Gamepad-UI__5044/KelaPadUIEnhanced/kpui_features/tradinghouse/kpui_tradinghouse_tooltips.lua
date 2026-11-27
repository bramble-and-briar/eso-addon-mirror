-- KelaPadUI trading-house tooltip layouts.

local KPUI_TRADINGHOUSE = KPUI_TRADINGHOUSE
local colors = KPUI_TRADINGHOUSE.colors
local GetItemLinks = KPUI_TRADINGHOUSE.GetItemLinks
local GetBuyInfo = KPUI_TRADINGHOUSE.GetBuyInfo
local HideTradingTooltipControls = KPUI_TRADINGHOUSE.HideTradingTooltipControls
local HideImprovementTooltipControls = KPUI_TRADINGHOUSE.HideImprovementTooltipControls
local HideCreationTooltipControls = KPUI_TRADINGHOUSE.HideCreationTooltipControls
local AddClearLine = KPUI_TRADINGHOUSE.AddClearLine
local SetSmithTradingInfo = KPUI_TRADINGHOUSE.SetSmithTradingInfo
local SetSmithGraph = KPUI_TRADINGHOUSE.SetSmithGraph
local SetSmithNotes = KPUI_TRADINGHOUSE.SetSmithNotes
local SetSmithListings = KPUI_TRADINGHOUSE.SetSmithListings
local SetSmithQualityPrices = KPUI_TRADINGHOUSE.SetSmithQualityPrices
local SetProductionPrices = KPUI_TRADINGHOUSE.SetProductionPrices
local SetCraftingComponents = KPUI_TRADINGHOUSE.SetCraftingComponents
local IsKPUITradingHouseSettingEnabled = KPUI_TRADINGHOUSE.IsKPUITradingHouseSettingEnabled

-- The buy confirmation shows the hovered item's deal rating by overriding the
-- core dialog strings. Keep the core text so an item without price data does
-- not inherit the previous item's rating.
local CORE_CONFIRM_BUY_TEXT = GetString(SI_GAMEPAD_TRADING_HOUSE_CONFIRM_BUY_DIALOG_TEXT)
local CORE_CONFIRM_BUY_MULTIPLE_TEXT = GetString(SI_GAMEPAD_TRADING_HOUSE_CONFIRM_BUY_MULTIPLE_DIALOG_TEXT)

local function SetBuyDialogDealText(effectOfDeal)
	if effectOfDeal and effectOfDeal ~= "" then
		SafeAddString(SI_GAMEPAD_TRADING_HOUSE_CONFIRM_BUY_DIALOG_TEXT, GetString(KELA_TRADING_TRADING_CONFIRM_BUY).."\n\n"..effectOfDeal, 1)
		SafeAddString(SI_GAMEPAD_TRADING_HOUSE_CONFIRM_BUY_MULTIPLE_DIALOG_TEXT, GetString(KELA_TRADING_TRADING_CONFIRM_BUY_MULT).."\n\n"..effectOfDeal, 0)
	else
		SafeAddString(SI_GAMEPAD_TRADING_HOUSE_CONFIRM_BUY_DIALOG_TEXT, CORE_CONFIRM_BUY_TEXT, 1)
		SafeAddString(SI_GAMEPAD_TRADING_HOUSE_CONFIRM_BUY_MULTIPLE_DIALOG_TEXT, CORE_CONFIRM_BUY_MULTIPLE_TEXT, 0)
	end
end

-- Control names per station, kept from the original per-station layouts.
local STATION_CONTROL_NAMES =
{
	enchanting = { info = "$(parent)Info", graph = "$(parent)Graph", listings = "$(parent)Listings" },
	alchemy = { info = "$(parent)Info", graph = "$(parent)Graph", listings = "$(parent)Listings" },
	provisioner = { info = "$(parent)ProvInfo", graph = "$(parent)ProvGraph", listings = "$(parent)SListings" },
}

-- Price tooltip beside the enchanting, alchemy and provisioning result: price
-- table, ATT graph, purchase note (when itemUniqueId is known) and previous
-- listings. `station` names the control set in STATION_CONTROLS.
local function LayoutStationTradingTooltip(station, tooltip, itemLink, icon, stackCount, selectedData, itemUniqueId)
	local controls = KPUI_TRADINGHOUSE.STATION_CONTROLS[station]
	local names = STATION_CONTROL_NAMES[station]
	tooltip.scrollTooltip:ResetToTop()
	tooltip.tip:ClearLines()
	tooltip = tooltip.tip
	stackCount = stackCount or 1

	if not itemLink or itemLink == "" then
		for _, control in pairs(controls) do
			control:SetHidden(true)
		end
		return
	end

	if tooltip.icon then
		tooltip.icon:SetTexture(icon)
		tooltip.icon:SetHidden(false)
	end

	local bodySection = tooltip:AcquireSection(tooltip:GetStyle("bodySection1"))
	bodySection:AddLine(GetString(KELA_TRADING_TRADING_INFO))
	bodySection:AddLine(" ")
	tooltip:AddSection(bodySection)
	local lastControl = bodySection

	local listingItemsTable = KelaGetItemLinkListingTable(itemLink)
	local trueTTC, trueATT, priceInfoTTC, priceInfoATT, hasPrice = KelaGetPriceInfoTTCATT(itemLink)

	-- basic information
	if hasPrice then
		controls.info = controls.info or CreateControlFromVirtual(names.info, tooltip, "KPUI_MainInfo")
		lastControl = SetSmithTradingInfo(controls.info, lastControl, priceInfoTTC, priceInfoATT, nil, selectedData, stackCount)
		lastControl = AddClearLine(tooltip, lastControl, 0, 0)
		if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_ATTINFO) then
			controls.graph = controls.graph or CreateControlFromVirtual(names.graph, tooltip, "KPUI_Graph")
			lastControl = SetSmithGraph(controls.graph, lastControl, itemLink, priceInfoTTC, priceInfoATT, stackCount)
		elseif controls.graph then
			controls.graph:SetHidden(true)
		end
	else
		local noInfoSection = tooltip:AcquireSection(tooltip:GetStyle("bodySection1"))
		noInfoSection:AddLine(GetString(KELA_TRADING_TRADING_NOTINFO))
		tooltip:AddSection(noInfoSection)
		noInfoSection:ClearAnchors()
		noInfoSection:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT, 0, 0)
		noInfoSection:SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT, 0, 0)
		lastControl = AddClearLine(tooltip, noInfoSection, 0, 0)
		if controls.info then controls.info:SetHidden(true) end
		if controls.graph then controls.graph:SetHidden(true) end
	end

	-- Purchased item information
	if itemUniqueId then
		local tblBuyingItems = kpuiSVBuyingData["buyingTable"]
		local itemUID = Id64ToString(itemUniqueId)
		if tblBuyingItems[itemUID] ~= nil then
			lastControl = SetSmithNotes(tooltip, lastControl, GetBuyInfo(tblBuyingItems, itemUID, itemLink))
		end
	end

	-- Previous sales
	if next(listingItemsTable) ~= nil and IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_LISTINGS) then
		controls.listings = controls.listings or CreateControlFromVirtual(names.listings, tooltip, "KPUI_PreviousListings")
		lastControl = SetSmithListings(controls.listings, lastControl, listingItemsTable)
		AddClearLine(tooltip, lastControl, 0, -15)
	elseif controls.listings then
		controls.listings:SetHidden(true)
	end
end

function KelaLayoutEnchantingTradingTooltip(tooltip, itemLink, maxIterations, itemUniqueId)
	LayoutStationTradingTooltip("enchanting", tooltip, itemLink, GetItemLinkIcon(itemLink), maxIterations, nil, itemUniqueId)
end

function KelaLayoutAlchemyTradingTooltip(tooltip, itemLink, maxIterations)
	LayoutStationTradingTooltip("alchemy", tooltip, itemLink, GetItemLinkIcon(itemLink), maxIterations)
end

function KelaLayoutProvisionerTradingTooltip(tooltip, recipeListIndex, recipeIndex, selectedData)
	local _, icon = GetRecipeResultItemInfo(recipeListIndex, recipeIndex)
	local itemLink = GetRecipeResultItemLink(recipeListIndex, recipeIndex)
	LayoutStationTradingTooltip("provisioner", tooltip, itemLink, icon, selectedData and selectedData.stackCount, selectedData)
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
		local trueTTC, trueATT, priceInfoTTC, priceInfoATT, hasPrice = KelaGetPriceInfoTTCATT(itemLink)

		local bodySection = tooltip:AcquireSection(tooltip:GetStyle("bodySection1"))
		bodySection:AddLine(GetString(KELA_TRADING_TRADING_INFO))
		bodySection:AddLine(" ")
		tooltip:AddSection(bodySection)
		lastControl = bodySection
		
		-- basic information
		if hasPrice then
			if not ctlCreationInfo then ctlCreationInfo = CreateControlFromVirtual("$(parent)Info", tooltip, "KPUI_MainInfo") end	
			lastControl = SetSmithTradingInfo(ctlCreationInfo, lastControl, priceInfoTTC, priceInfoATT)
			lastControl = AddClearLine(tooltip, lastControl, 0, 0)
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
		icon = select(2, GetSmithingImprovedItemInfo(itemBagId, itemSlotIndex, craftingSkillType))
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
			local trueTTC, trueATT, priceInfoTTC, priceInfoATT, hasPrice = KelaGetPriceInfoTTCATT(itemLink)

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
			if hasPrice then
				if craftingSkillType then -- result tooltip
					if not ctlResultInfo then ctlResultInfo = CreateControlFromVirtual("$(parent)RInfo", tooltip, "KPUI_MainInfo") end	
					lastControl = SetSmithTradingInfo(ctlResultInfo, lastControl, priceInfoTTC, priceInfoATT, nil, selectedData)
					lastControl = AddClearLine(tooltip, lastControl, 0, 0)
					if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_ATTINFO) then
						if not ctlResultGraph then ctlResultGraph = CreateControlFromVirtual("$(parent)RGraph", tooltip, "KPUI_Graph") end							
						lastControl = SetSmithGraph (ctlResultGraph, lastControl, itemLink, priceInfoTTC, priceInfoATT, 1)
					else
						if ctlResultGraph then ctlResultGraph:SetHidden(true) end	
					end
				else
					if not ctlSourceInfo then ctlSourceInfo = CreateControlFromVirtual("$(parent)SInfo", tooltip, "KPUI_MainInfo") end	
					lastControl = SetSmithTradingInfo(ctlSourceInfo, lastControl, priceInfoTTC, priceInfoATT, nil, selectedData)
					lastControl = AddClearLine(tooltip, lastControl, 0, 0)
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
			local guildName = GetGuildName(currentGuildId)
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
			local trueTTC, trueATT, priceInfoTTC, priceInfoATT, hasPrice = KelaGetPriceInfoTTCATT(itemLink)
			local dealRatingText = hasPrice and KelaGetDealRatingText(priceInfoTTC, priceInfoATT, selectedData, currentScene, stackCount)
			local function AddTitle(lastControl)
				-- Deal evaluation sits above the item name, styled like the
				-- "Good type:" line. Trading house only.
				if dealRatingText then
					local dealSection = self:AcquireSection(self:GetStyle("bodySection1"))
					dealSection:AddLine(colors.GENERAL_COLOR_NORMAL:Colorize(GetString(KELA_TRADING_DEAL_EVALUATION)).." "..dealRatingText, self:GetStyle("bodyHeader"))
					self:AddSection(dealSection)
					if lastControl then
						dealSection:ClearAnchors()
						dealSection:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT, 0, 0)
						dealSection:SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT, 0, 0)
					end
					lastControl = dealSection
				end
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
			local effectOfDeal
			if hasPrice then
				if not ctlTradingInfo then ctlTradingInfo = CreateControlFromVirtual("$(parent)Info", self, "KPUI_MainInfo") end
				lastControl, effectOfDeal = SetSmithTradingInfo(ctlTradingInfo, lastControl, priceInfoTTC, priceInfoATT, currentScene, selectedData, stackCount)
				lastControl = AddClearLine(self, lastControl, 0, 0)
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
			SetBuyDialogDealText(effectOfDeal)

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
				local trueTTC, trueATT, priceInfoTTC, priceInfoATT, hasPrice = KelaGetPriceInfoTTCATT(resultItemLink)
				if hasPrice then
					if not ctlProductMaterialInfoRow then ctlProductMaterialInfoRow = CreateControlFromVirtual("$(parent)ctlProductMaterialInfoRow", self, "KPUI_ProductMaterialInfo") end	
					lastControl = SetProductionPrices(ctlProductMaterialInfoRow, lastControl, resultItemLink, priceInfoTTC, priceInfoATT)
				else
					if ctlProductMaterialInfoRow then ctlProductMaterialInfoRow:SetHidden(true) end	
				end
			else
				if ctlProductMaterialInfoRow then ctlProductMaterialInfoRow:SetHidden(true) end	
			end

			-- crafting components table
			-- Check the setting first: the component lookup queries ATT for every part.
			local isATTCraftingInfo, craftingComponentPrices
			if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_COMPONENTS) then
				isATTCraftingInfo, craftingComponentPrices = KelaGetCurrentATTCraftingInfo(itemLink)
			end
			if isATTCraftingInfo then
				if not ctlCraftingComponentsInfo then ctlCraftingComponentsInfo = CreateControlFromVirtual("$(parent)ctlCraftingInfo", self, "KPUI_CraftingInfo") end
				lastControl = SetCraftingComponents(ctlCraftingComponentsInfo, lastControl, craftingComponentPrices) or lastControl
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
