-- Libs
local LCCC = LibCodesCommonCode
local LCK = LibCharacterKnowledge
local CK = CharacterKnowledge
local LibPrice = LibPrice

-- ZOS api/constants
local EVENT_MANAGER = EVENT_MANAGER
local ZO_SavedVars = ZO_SavedVars
local ZO_AbbreviateAndLocalizeNumber = ZO_AbbreviateAndLocalizeNumber
local ZO_Currency_GetKeyboardFormattedCurrencyIcon = ZO_Currency_GetKeyboardFormattedCurrencyIcon
local GetString = GetString
local CURT_MONEY = CURT_MONEY
local EVENT_ADD_ON_LOADED = EVENT_ADD_ON_LOADED
local CURRENCY_ICON = ZO_Currency_GetKeyboardFormattedCurrencyIcon(CURT_MONEY)

-- Addon
local ADDON_NAME = "CharacterKnowledgePrices"
local PRICE_SCAN_NAME = ADDON_NAME .. "Scan"

local CharacterKnowledgePrices =
{
	name = ADDON_NAME,
	defaults =
	{
		showPriceColumn = true,
		useMasterMerchant = true,
		useArkadiusTradeTools = true,
		useTamrielTradeCentre = true,
	},
}

local priceScanRunning = false

local function IsPriceColumnShown()
	local savedVars = CharacterKnowledgePrices.vars
	return savedVars ~= nil and savedVars.showPriceColumn
end

local function AddAverage(totalGold, sourceCount, averageGold)
	if (averageGold and averageGold > 0) then
		return totalGold + averageGold, sourceCount + 1
	end
	return totalGold, sourceCount
end

local function GetPriceGold(itemId)
	local savedVars = CharacterKnowledgePrices.vars
	local priceData = LibPrice.ItemLinkToPriceData(LCK.GetItemLinkFromItemId(itemId), "mm", "att", "ttc")
	local mmPrice = priceData.mm
	local attPrice = priceData.att
	local ttcPrice = priceData.ttc
	local totalGold, sourceCount = 0, 0
	if (savedVars.useMasterMerchant) then
		totalGold, sourceCount = AddAverage(totalGold, sourceCount, mmPrice and mmPrice.avgPrice)
	end
	if (savedVars.useArkadiusTradeTools) then
		totalGold, sourceCount = AddAverage(totalGold, sourceCount, attPrice and attPrice.avgPrice)
	end
	if (savedVars.useTamrielTradeCentre) then
		totalGold, sourceCount = AddAverage(totalGold, sourceCount, ttcPrice and ttcPrice.Avg)
	end
	if (sourceCount > 0) then
		return totalGold / sourceCount
	end
	return 0
end

local function GetAuxiliaryLabel(auxData)
	local USE_UPPERCASE_NUMBER_SUFFIXES = true
	local abbreviatedAmount = ZO_AbbreviateAndLocalizeNumber(auxData, NUMBER_ABBREVIATION_PRECISION_TENTHS, USE_UPPERCASE_NUMBER_SUFFIXES)
	return abbreviatedAmount .. " " .. CURRENCY_ICON
end

local function StopPriceScan()
	EVENT_MANAGER:UnregisterForUpdate(PRICE_SCAN_NAME)
	priceScanRunning = false
end

local function IsRecipeOrPlan(data)
	return data.category == LCK.ITEM_CATEGORY_RECIPE or data.category == LCK.ITEM_CATEGORY_PLAN
end

function CharacterKnowledgePrices.FillExistingPrices()
	local list = CK.list
	if (not IsPriceColumnShown() or priceScanRunning or not list or #list.masterList == 0) then
		return
	end

	priceScanRunning = true
	local startIndex = 1
	local blockSize = 200
	EVENT_MANAGER:RegisterForUpdate(PRICE_SCAN_NAME, 0, function ()
		local stopIndex = startIndex + blockSize
		for index = startIndex, stopIndex - 1 do
			local data = list.masterList[index]
			if (IsRecipeOrPlan(data)) then
				data.auxiliary = GetPriceGold(data.itemId)
			end
			if (index >= #list.masterList) then
				StopPriceScan()
				if (not list.researchModeIsSelected) then
					list:RefreshFilters()
				end
				return
			end
		end
		startIndex = stopIndex
	end)
end

function CharacterKnowledgePrices.RegisterAuxiliaryColumn()
	if (CharacterKnowledgePrices.auxiliaryColumnRegistered) then
		return
	end
	CharacterKnowledgePrices.auxiliaryColumnRegistered = true
	CK.ConfigureAuxiliaryColumn(GetPriceGold, GetAuxiliaryLabel)
	CharacterKnowledgePrices.FillExistingPrices()
end

function CharacterKnowledgePrices.OnPriceSourceChanged(sourceKey, enabled)
	CharacterKnowledgePrices.vars[sourceKey] = enabled
	if (not IsPriceColumnShown()) then
		return
	end

	StopPriceScan()
	CharacterKnowledgePrices.FillExistingPrices()
end

function CharacterKnowledgePrices.OnSettingChanged(showPriceColumn)
	CharacterKnowledgePrices.vars.showPriceColumn = showPriceColumn
	if (showPriceColumn) then
		return
	end

	StopPriceScan()
	CK.ConfigureAuxiliaryColumn()
	CharacterKnowledgePrices.auxiliaryColumnRegistered = false
	local list = CK.list
	if (list) then
		list:RefreshFilters()
	end
end

local function OnAddOnLoaded(eventCode, addonName)
	if (addonName ~= ADDON_NAME) then
		return
	end
	EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

	CharacterKnowledgePrices.vars = ZO_SavedVars:NewAccountWide("CharacterKnowledgePricesSavedVariables", 1, nil, CharacterKnowledgePrices.defaults)

	if (IsPriceColumnShown()) then
		CharacterKnowledgePrices.RegisterAuxiliaryColumn()
	end

	local LAM = LCCC.GetLibAddonMenu()
	if (LAM) then
		local panelId = "CharacterKnowledgePricesSettings"
		LAM:RegisterAddonPanel(panelId,
													 {
														 type = "panel",
														 name = GetString(SI_CKP_TITLE),
														 version = "1.0.2",
														 author = "@dack_janiels",
														 registerForRefresh = true,
													 })
		LAM:RegisterOptionControls(panelId,
															 {
																 {
																	 type = "checkbox",
																	 name = SI_CKP_SETTING_SHOW,
																	 tooltip = SI_CKP_SETTING_SHOW_TOOLTIP,
																	 getFunc = function () return CharacterKnowledgePrices.vars.showPriceColumn end,
																	 setFunc = CharacterKnowledgePrices.OnSettingChanged,
																	 requiresReload = true,
																	 default = CharacterKnowledgePrices.defaults.showPriceColumn,
																 },
																 {
																	 type = "header",
																	 name = SI_CKP_SETTING_SOURCES,
																	 tooltip = SI_CKP_SETTING_SOURCES_TOOLTIP,
																 },
																 {
																	 type = "checkbox",
																	 name = SI_CKP_SETTING_MASTER_MERCHANT,
																	 tooltip = SI_CKP_SETTING_MASTER_MERCHANT_TOOLTIP,
																	 getFunc = function () return CharacterKnowledgePrices.vars.useMasterMerchant end,
																	 setFunc = function (enabled) CharacterKnowledgePrices.OnPriceSourceChanged("useMasterMerchant", enabled) end,
																	 default = CharacterKnowledgePrices.defaults.useMasterMerchant,
																 },
																 {
																	 type = "checkbox",
																	 name = SI_CKP_SETTING_ARKADIUS,
																	 tooltip = SI_CKP_SETTING_ARKADIUS_TOOLTIP,
																	 getFunc = function () return CharacterKnowledgePrices.vars.useArkadiusTradeTools end,
																	 setFunc = function (enabled) CharacterKnowledgePrices.OnPriceSourceChanged("useArkadiusTradeTools", enabled) end,
																	 default = CharacterKnowledgePrices.defaults.useArkadiusTradeTools,
																 },
																 {
																	 type = "checkbox",
																	 name = SI_CKP_SETTING_TAMRIEL_TRADE_CENTRE,
																	 tooltip = SI_CKP_SETTING_TAMRIEL_TRADE_CENTRE_TOOLTIP,
																	 getFunc = function () return CharacterKnowledgePrices.vars.useTamrielTradeCentre end,
																	 setFunc = function (enabled) CharacterKnowledgePrices.OnPriceSourceChanged("useTamrielTradeCentre", enabled) end,
																	 default = CharacterKnowledgePrices.defaults.useTamrielTradeCentre,
																 },
															 })
	end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)