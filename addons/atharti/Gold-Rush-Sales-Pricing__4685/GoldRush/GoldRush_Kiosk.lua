local GR = GoldRush
local EM = EVENT_MANAGER

local DEAL_LEVELS = {
	{ min = 25,	 color = "22C55E" }, -- Green
	{ min = 1,	 color = "3B82F6" }, -- Blue
	{ min = 0,	 color = "FFFFFF" }, -- White
	{ min = -15, color = "F97316" }, -- Orange
	{ min = -math.huge, color = "EF4444" }, -- Red
}

function GR.GetDealMarginFromAvg(avgPricePerUnit, purchasePricePerUnit)
	local margin = math.floor(((avgPricePerUnit - purchasePricePerUnit) / avgPricePerUnit) * 100)
	for _, tier in ipairs(DEAL_LEVELS) do
		if margin >= tier.min then
			return margin, tier.color
		end
	end
end

GR.commitHookAttached = false

function GR.PreCommitHook(list)
	if list ~= ZO_TradingHouseBrowseItemsRightPaneSearchResults then
		return
	end

	for _, entry in ipairs(ZO_ScrollList_GetDataList(list)) do
		local data = entry.data
		local itemLink = GetTradingHouseSearchResultItemLink(data.slotIndex)
		local normLink = itemLink and GR.NormalizeItemLink(itemLink)
		data.GR_avgPricePerUnit = normLink and GR.avgPriceCache[normLink]
	end
end

function GR.AttachCommitHook()
	if GR.commitHookAttached then return end
	ZO_PreHook("ZO_ScrollList_Commit", GR.PreCommitHook)
	GR.commitHookAttached = true
end

function GR.UpdateDealControl(dealControl, data)
	local purchasePricePerUnit = data.purchasePrice / data.stackCount
	local avgPrice = data.GR_avgPricePerUnit

	if not avgPrice then
		dealControl:SetText("∞")
		dealControl:SetColor(0.5, 0.5, 0.5, 1)
		return
	end

	local margin, colorHex = GR.GetDealMarginFromAvg(avgPrice, purchasePricePerUnit)
	dealControl:SetText(margin .. "%")
	local r, g, b = tonumber(colorHex:sub(1,2), 16)/255,
					tonumber(colorHex:sub(3,4), 16)/255,
					tonumber(colorHex:sub(5,6), 16)/255
	dealControl:SetColor(r, g, b, 1)
end

function GR.EnsureDealControl(rowControl, heightSource)
	local dealControl = rowControl:GetNamedChild("GR_DealLevel")
	if dealControl then return dealControl end

	dealControl = CreateControlFromVirtual(rowControl:GetName() .. "GR_DealLevel", rowControl, "ZO_KeyboardGuildRosterRowLabel")
	dealControl:SetDimensions(55, heightSource:GetHeight())
	dealControl:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	dealControl:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	dealControl:SetFont("ZoFontGameShadow")
	return dealControl
end

-- Vanilla layout
function GR.SetVanillaSearchResults(rowControl, data)
	local nameControl = rowControl:GetNamedChild("Name")
	local timeRemainingControl = rowControl:GetNamedChild("TimeRemaining")
	local sellPricePerUnitControl = rowControl:GetNamedChild("SellPricePerUnit")
	local sellPriceControl = rowControl:GetNamedChild("SellPrice")

	local dealControl = GR.EnsureDealControl(rowControl, nameControl)

	nameControl:SetWidth(185)
	timeRemainingControl:SetWidth(50)
	sellPricePerUnitControl:SetWidth(100)
	sellPriceControl:SetWidth(100)

	timeRemainingControl:ClearAnchors()
	timeRemainingControl:SetAnchor(LEFT, nameControl, RIGHT, 20)

	dealControl:ClearAnchors()
	dealControl:SetAnchor(LEFT, timeRemainingControl, RIGHT, 10)

	sellPricePerUnitControl:ClearAnchors()
	sellPricePerUnitControl:SetAnchor(LEFT, dealControl, RIGHT, 10)

	GR.UpdateDealControl(dealControl, data)
end

-- AGS layout
function GR.SetSearchResultsAGS(rowControl, data)
	local timeRemainingControl = rowControl:GetNamedChild("TimeRemaining")
	if not timeRemainingControl then return end

	local dealControl = GR.EnsureDealControl(rowControl, timeRemainingControl)

	dealControl:ClearAnchors()
	dealControl:SetAnchor(TOPLEFT, timeRemainingControl, TOPRIGHT, -10, 0)
	GR.UpdateDealControl(dealControl, data)
end

-- ============================================
-- Init
-- ============================================
GR.hooksAttached = false

function GR.AttachKioskHooks()
	if GR.hooksAttached then return end

	GR.AttachCommitHook()

	if AwesomeGuildStore then
		for _, dataType in pairs(TRADING_HOUSE.searchResultsList.dataTypes) do
			ZO_PreHook(dataType, "setupCallback", GR.SetSearchResultsAGS)
		end
	else
		ZO_PreHook(TRADING_HOUSE.searchResultsList.dataTypes[1], "setupCallback", GR.SetVanillaSearchResults)
	end

	GR.hooksAttached = true
end

function GR.OnTradingHouseResponse(_, responseType, result)
	if responseType == TRADING_HOUSE_RESULT_SEARCH_PENDING and result == TRADING_HOUSE_RESULT_SUCCESS then
		GR.AttachKioskHooks()
		ZO_ScrollList_Commit(ZO_TradingHouseBrowseItemsRightPaneSearchResults)
		EM:UnregisterForEvent(GR.name, EVENT_TRADING_HOUSE_RESPONSE_RECEIVED)
	end
end

function GR.SetupKioskRowInjections()
	EM:RegisterForEvent(GR.name, EVENT_TRADING_HOUSE_RESPONSE_RECEIVED, GR.OnTradingHouseResponse)
end