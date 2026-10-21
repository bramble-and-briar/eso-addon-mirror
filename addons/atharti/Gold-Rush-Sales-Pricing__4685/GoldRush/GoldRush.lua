GoldRush = {}

local GR = GoldRush
local EM = EVENT_MANAGER

GR.name = "GoldRush"

local SECONDS_IN_HOUR = 3600
local SECONDS_IN_DAY = 24 * 60 * 60
local SECONDS_IN_WEEK = 604800
local ROW_HEIGHT = 30

local defaultSV = {
	keepDays = 30,
	windowLeft = 0,
	windowTop = 87,
	windowWidth = 956,
	windowHeight = 674,
	savedSales = {},
	lastEventIds = {},
	itemPriceHistory = {},
	guildProcessorsEnabled = {},
	guildMapping = {},
	enableSaleNotifications = true,
	enableSaleNotificationsChat = true,
	lifetimeGold = 0,
}

GR.SV = {}
GR.sales = {}
GR.guildListeners = {}
GR.avgPriceCache = {}
GR.displayName = nil

GR._playerSales = {}
GR._salesToSave = {}

-- ============================================
-- Global functions for XML callbacks
-- ============================================
function GR.OnWindowInitialized(window)
	GR.window = window
	local scrollList = window:GetNamedChild("List")
	GR.scrollList = scrollList

	window:SetHandler("OnMoveStop", function()
		GR.SV.windowLeft = window:GetLeft()
		GR.SV.windowTop = window:GetTop()
	end)

	local lastWidth, lastHeight = window:GetDimensions()
	window:SetHandler("OnUpdate", function()
		local w, h = window:GetDimensions()
		if w ~= lastWidth or h ~= lastHeight then
			lastWidth, lastHeight = w, h
			ZO_ScrollList_Commit(scrollList)
		end
	end)

	window:SetHandler("OnShow", GR.BuildSalesList)

	local headers = window:GetNamedChild("Headers")
	GR.headers = headers
	headers:GetNamedChild("Guild"):SetText("|t24:24:/esoui/art/icons/servicemappins/servicepin_guildkiosk.dds|t")
	headers:GetNamedChild("Buyer"):SetText("|t24:24:/esoui/art/tutorial/gamepad/gp_playermenu_icon_character.dds|t")
	headers:GetNamedChild("Item"):SetText("|t24:24:/esoui/art/notifications/gamepad/gp_notificationicon_trade.dds|t")
	headers:GetNamedChild("Time"):SetText("|t24:24:/esoui/art/addons/gamepad/gp_mod_listing_category_castbarsandcooldowns.dds|t")
	headers:GetNamedChild("Price"):SetText("|t24:24:/esoui/art/tradinghouse/tradinghouse_emptysellslot_icon.dds|t")

	ZO_ScrollList_Initialize(scrollList)
	ZO_ScrollList_AddDataType(scrollList, 1, "GR_SalesRowTemplate", ROW_HEIGHT, GR.SetupSaleRow)

	GR.InitializeFooterControls()

	GR.fragment = ZO_HUDFadeSceneFragment:New(window)
	MAIL_INBOX_SCENE:AddFragment(GR.fragment)
	MAIL_SEND_SCENE:AddFragment(GR.fragment)

	window:SetHidden(true)
end

function GR.OnWindowResizeStop(window)
	GR.SV.windowLeft = window:GetLeft()
	GR.SV.windowTop = window:GetTop()
	GR.SV.windowWidth = window:GetWidth()
	GR.SV.windowHeight = window:GetHeight()

	ZO_ScrollList_Commit(GR.scrollList)
end

function GR.CloseWindow()
	GR.window:SetHidden(true)
end

function GR.FormatTimeAgo(timestamp)
	return ZO_FormatDurationAgo(GetTimeStamp() - timestamp)
end

-- ============================================
-- Scroll List Functions
-- ============================================
function GR.SetupSaleRow(rowControl, rowData)
	local sale = rowData

	local guildLabel = rowControl:GetNamedChild("Guild")
	local buyerLabel = rowControl:GetNamedChild("Buyer")
	local itemControl = rowControl:GetNamedChild("Item")
	local itemText = itemControl:GetNamedChild("Text")
	local itemIcon = itemControl:GetNamedChild("Icon")
	local itemQty = itemControl:GetNamedChild("Quantity")
	local timeLabel = rowControl:GetNamedChild("Time")
	local priceLabel = rowControl:GetNamedChild("Price")

	local headers = GR.headers
	local headerGuild = headers:GetNamedChild("Guild")
	local headerBuyer = headers:GetNamedChild("Buyer")
	local headerItem = headers:GetNamedChild("Item")
	local headerTime = headers:GetNamedChild("Time")
	local headerPrice = headers:GetNamedChild("Price")
	local masterLeft = headers:GetLeft()

	guildLabel:ClearAnchors()
	guildLabel:SetAnchor(TOPLEFT, rowControl, TOPLEFT, headerGuild:GetLeft() - masterLeft, 0)
	guildLabel:SetWidth(headerGuild:GetWidth())

	buyerLabel:ClearAnchors()
	buyerLabel:SetAnchor(TOPLEFT, rowControl, TOPLEFT, headerBuyer:GetLeft() - masterLeft, 0)
	buyerLabel:SetWidth(headerBuyer:GetWidth())

	itemControl:ClearAnchors()
	itemControl:SetAnchor(TOPLEFT, rowControl, TOPLEFT, headerItem:GetLeft() - masterLeft, 0)
	itemControl:SetWidth(headerItem:GetWidth())

	timeLabel:ClearAnchors()
	timeLabel:SetAnchor(TOPLEFT, rowControl, TOPLEFT, headerTime:GetLeft() - masterLeft, 0)
	timeLabel:SetWidth(headerTime:GetWidth())

	priceLabel:ClearAnchors()
	priceLabel:SetAnchor(TOPLEFT, rowControl, TOPLEFT, headerPrice:GetLeft() - masterLeft, 0)
	priceLabel:SetWidth(headerPrice:GetWidth() - 5)

	guildLabel:SetText(sale.guildName)
	buyerLabel:SetText(sale.buyerName)
	itemText:SetText(sale.itemLink)

	local icon = GetItemLinkIcon(sale.itemLink)

	itemIcon:SetTexture(icon)

	local qty = sale.quantity
	if qty == 1 then
		itemQty:SetText("")
	else
		itemQty:SetText(tostring(qty))
	end

	timeLabel:SetText(GR.FormatTimeAgo(sale.timeStamp))
	priceLabel:SetText(GR.FormatPriceFull(sale.price))
end

function GR.BuildSalesList()
	ZO_ScrollList_Clear(GR.scrollList)

	local dataList = ZO_ScrollList_GetDataList(GR.scrollList)

	ZO_ClearNumericallyIndexedTable(GR._playerSales)

	local totalGoldEarned = 0

	for _, sale in pairs(GR.sales) do
		if GR.IsSaleInTimeWindow(sale.timeStamp) then
			table.insert(GR._playerSales, sale)
			totalGoldEarned = totalGoldEarned + (sale.price)
		end
	end

	table.sort(GR._playerSales, function(a, b)
		return a.timeStamp > b.timeStamp
	end)

	for _, sale in ipairs(GR._playerSales) do
		local entry = ZO_ScrollList_CreateDataEntry(1, sale)
		table.insert(dataList, entry)
	end

	ZO_ScrollList_Commit(GR.scrollList)

	local footerTextControl = GetControl("GR_MainWindowFooterTotalSalesText")

	footerTextControl:SetText(GR.FormatPriceFull(totalGoldEarned))
end

function GR.FormatPriceFull(price)
	if price == 0 then return "0" end
	local formatted = FormatIntegerWithDigitGrouping(math.floor(price), ",", 3)
	return formatted .. " |t16:16:EsoUI/Art/currency/currency_gold.dds|t"
end

function GR.NotifySale(sale)
	if not GR.SV.enableSaleNotificationsChat and not GR.SV.enableSaleNotifications then return end

	local msg = string.format(
		"%s: %dx %s %s |cFFC500→|r |cFFC500%s|r",
		GetString(SI_INVENTORY_SORT_TYPE_SELL_INFORMATION),
		sale.quantity,
		sale.itemLink,
		GR.FormatPriceFull(sale.price),
		sale.guildName
	)

	if GR.SV.enableSaleNotificationsChat then
		d(msg)
	end

	if GR.SV.enableSaleNotifications then
		CENTER_SCREEN_ANNOUNCE:AddMessage(
			nil,
			CSA_CATEGORY_SMALL_TEXT,
			SOUNDS.ITEM_MONEY_CHANGED,
			msg,
			nil,
			nil,
			nil,
			nil,
			nil,
			5000,
			nil,
			QUEUE_IMMEDIATELY,
			SHOW_IMMEDIATELY,
			REINSERT_STOMPED_MESSAGE
		)
	end
end

-- ============================================
-- Data Management
-- ============================================
function GR.CreateCleanSale(timestamp, guildName, buyer, quantity, itemLink, price, tax)
	return {
		timeStamp = timestamp,
		guildName = guildName,
		buyerName = buyer,
		quantity = quantity,
		itemLink = itemLink,
		price = price,
		tax = tax,
		unitPrice = price / quantity,
	}
end

function GR.AddSale(eventId, timestamp, guildName, seller, buyer, quantity, itemLink, price, tax)
	if "@" .. seller ~= GR.displayName then return false end
	if GR.sales[eventId] then return false end

	local normItemLink = GR.NormalizeItemLink(itemLink)
	local sale = GR.CreateCleanSale(timestamp, guildName, buyer, quantity, normItemLink, price, tax)
	GR.sales[eventId] = sale

	GR.SV.lifetimeGold = GR.SV.lifetimeGold + price
	GR.SaveSales()
	GR.BuildSalesList()
	GR.NotifySale(sale)

	return true
end

-- ============================================
-- Average Price Cache
-- ============================================
function GR.UpdateAvgPriceCache(itemLink)
	local totalGold = 0
	local totalQty = 0

	for _, bucket in pairs(GR.SV.itemPriceHistory[itemLink]) do
		totalGold = totalGold + bucket[1]
		totalQty = totalQty + bucket[2]
	end

	GR.avgPriceCache[itemLink] = totalGold / totalQty
end

function GR.RebuildAvgPriceCache()
	ZO_ClearTable(GR.avgPriceCache)
	for itemLink, _ in pairs(GR.SV.itemPriceHistory) do
		GR.UpdateAvgPriceCache(itemLink)
	end
end

-- ============================================
-- Tooltip Extension
-- ============================================
function GR.CreateTooltipExtension()
	GR.tooltipControl = CreateControl("GoldRushTooltipExtension", GuiRoot, CT_CONTROL)
	GR.tooltipControl:SetDimensions(350, 25)
	GR.tooltipControl:SetHidden(true)

	local label = GR.tooltipControl:CreateControl("GoldRushTooltipPrice", CT_LABEL)
	label:SetFont("ZoFontGame")
	label:SetColor(1, 0.8, 0.2, 1)
	label:SetAnchor(TOPLEFT, GR.tooltipControl, TOPLEFT, 0, 0)
	label:SetAnchor(TOPRIGHT, GR.tooltipControl, TOPRIGHT, 0, 0)
	label:SetHeight(25)
	label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	label:SetText("")

	GR.tooltipControl.label = label
end

function GR.FormatPricePouch(price)
	local formatted
	if price < 100 then
		formatted = string.format("%.2f", price)
	else
		formatted = FormatIntegerWithDigitGrouping(math.floor(price), ",", 3)
	end

	return "|t25:25:/esoui/art/icons/item_generic_coinbag.dds|t " .. formatted
end

function GR.UpdateTooltip(tooltip, itemLink)
	if not itemLink then return end

	local avgPrice

	if GR.IsDummyItemLink(itemLink) then
		avgPrice = GR.FindPriceByItemId(GR.GetItemIdFromLink(itemLink))
	else
		local normItemLink = GR.NormalizeItemLink(itemLink)
		avgPrice = normItemLink and GR.avgPriceCache[normItemLink]
	end

	local hasPrice = avgPrice and avgPrice > 0

	GR.tooltipControl:SetHidden(not hasPrice)
	if not hasPrice then return end

	GR.tooltipControl.label:SetText(GR.FormatPricePouch(avgPrice))
	tooltip:AddControl(GR.tooltipControl, 0, false)
	GR.tooltipControl:ClearAnchors()
	GR.tooltipControl:SetAnchor(CENTER, nil, CENTER, 0, 5)
end

function GR.SetupTooltipHooks()
	GR.CreateTooltipExtension()

	local function HookSetMethod(methodName, linkGetter)
		ZO_PostHook(ItemTooltip, methodName, function(tooltip, ...)
			local itemLink = linkGetter(...)
			if itemLink then
				GR.UpdateTooltip(tooltip, itemLink)
			end
		end)
	end

	HookSetMethod("SetLink", function(itemLink) return itemLink end)

	HookSetMethod("SetBagItem", function(bag, index)
		return GetItemLink(bag, index)
	end)

	HookSetMethod("SetLootItem", function(lootId)
		return GetLootItemLink(lootId)
	end)

	HookSetMethod("SetWornItem", function(index, bagId)
		return GetItemLink(bagId, index)
	end)

	HookSetMethod("SetAttachedMailItem", function(mailId, index)
		return GetAttachedItemLink(mailId, index)
	end)

	HookSetMethod("SetStoreItem", function(storeIndex)
		return GetStoreItemLink(storeIndex)
	end)

	HookSetMethod("SetTradeItem", function(tradeType, tradeIndex)
		return GetTradeItemLink(tradeType, tradeIndex)
	end)

	HookSetMethod("SetTradingHouseItem", function(tradingHouseIndex)
		return GetTradingHouseSearchResultItemLink(tradingHouseIndex)
	end)

	HookSetMethod("SetTradingHouseListing", function(listingIndex)
		return GetTradingHouseListingItemLink(listingIndex)
	end)

	HookSetMethod("SetProvisionerResultItem", function(recipeListIndex, recipeIndex)
		return GetRecipeResultItemLink(recipeListIndex, recipeIndex)
	end)

	ZO_PostHookHandler(ItemTooltip, "OnMouseExit", function()
		GR.tooltipControl:SetHidden(true)
	end)
end

function GR.NormalizeItemLink(itemLink)
	itemLink = itemLink:gsub("H1:", "H0:")

	local prefix = itemLink:match("|H%d:item:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:")
	local suffix = itemLink:match(":%d+:%d+:%d+:%d+|h.*|h")
	if prefix and suffix then
		suffix = suffix:gsub("|h.*|h", "|h|h")
		return prefix .. "0" .. suffix
	end
end

function GR.IsDummyItemLink(itemLink)
	if not itemLink then return false end
	local itemId, rest = itemLink:match("|H%d:item:(%d+):(.+)|h|h")
	if not itemId then return false end
	return rest:match("^[0:]+$") ~= nil
end

function GR.GetItemIdFromLink(itemLink)
	if not itemLink then return nil end
	return itemLink:match("|H%d:item:(%d+):")
end

function GR.FindPriceByItemId(itemId)
	if not itemId then return nil end

	local pattern = "item:" .. itemId .. ":"

	for normLink, price in pairs(GR.avgPriceCache) do
		if normLink:find(pattern, 1, true) then
			return price
		end
	end
end

-- ============================================
-- LibHistoire Integration
-- ============================================
function GR.InitLibHistoire()
	LibHistoire:OnReady(function()
		GR.SetupGuildListeners()

		LibHistoire:RegisterCallback(LibHistoire.callback.MANAGED_RANGE_LOST, function(guildId, category)
			if category ~= GUILD_HISTORY_EVENT_CATEGORY_TRADER then
				return
			end

			local guildName = GetGuildName(guildId)
			if guildName == "" then return end
			if GR.SV.guildProcessorsEnabled[guildName] == false then return end

			d("GoldRush: Managed range lost for " .. guildName .. " – restarting processor...")
			GR.SV.lastEventIds[guildName] = nil
			GR.SetupGuildProcessor(guildId, guildName)
		end)
	end)
end

function GR.SetupGuildProcessor(guildId, guildName)
	local processor = LibHistoire:CreateGuildHistoryProcessor(guildId, GUILD_HISTORY_EVENT_CATEGORY_TRADER, "GoldRush")
	if not processor then
		d("GoldRush: No cache for guild " .. guildName)
		return
	end

	local lastEventId = GR.SV.lastEventIds[guildName]

	if lastEventId then
		processor:SetAfterEventId(lastEventId)
	else
		local cutoffTime = GetTimeStamp() - GR.SV.keepDays * SECONDS_IN_DAY
		processor:SetAfterEventTime(cutoffTime)
	end

	local function HandleEvent(event)
		local info = event:GetEventInfo()
		if info.eventType ~= GUILD_HISTORY_TRADER_EVENT_ITEM_SOLD then
			return
		end

		local eventId   = event:GetEventId()
		local timestamp = event:GetEventTimestampS()
		local seller    = info.sellerDisplayName
		local buyer     = "@" .. info.buyerDisplayName
		local quantity  = info.quantity
		local itemLink  = info.itemLink
		local price     = info.price
		local tax       = info.tax

		GR.AddPriceHistory(itemLink, price, quantity, timestamp)

		local prev = GR.SV.lastEventIds[guildName]
		if not prev or eventId > prev then
			GR.SV.lastEventIds[guildName] = eventId
		end

		if "@" .. seller == GR.displayName then
			GR.AddSale(eventId, timestamp, guildName, seller, buyer,
					   quantity, itemLink, price, tax)
		end
	end

	processor:SetNextEventCallback(HandleEvent)
	processor:SetMissedEventCallback(HandleEvent)
	processor:SetReceiveMissedEventsOutsideIterationRange(true)

	processor:Start()
end

function GR.SetupGuildListeners()
	for i = 1, GetNumGuilds() do
		local guildId = GetGuildId(i)
		local guildName = GetGuildName(guildId)
		if guildName ~= "" then
			if GR.SV.guildProcessorsEnabled[guildName] ~= false then
				GR.SetupGuildProcessor(guildId, guildName)
			end
		end
	end
end

function GR.SaveSales()
	local cutoffTime = GetTimeStamp() - GR.SV.keepDays * SECONDS_IN_DAY
	ZO_ClearTable(GR._salesToSave)

	for eventId, sale in pairs(GR.sales) do
		if sale.timeStamp > cutoffTime then
			local guildId = GR.SV.guildMapping[sale.guildName]
			if not guildId then
				local maxId = 0
				for _, existingId in pairs(GR.SV.guildMapping) do
					if existingId > maxId then maxId = existingId end
				end
				guildId = maxId + 1
				GR.SV.guildMapping[sale.guildName] = guildId
			end

			GR._salesToSave[eventId] = {
				sale.timeStamp,
				guildId,
				sale.buyerName,
				sale.quantity,
				sale.itemLink,
				sale.price,
				sale.tax,
			}
		end
	end

	GR.SV.savedSales = GR._salesToSave
end

function GR.LoadSavedSales()
	local cutoffTime = GetTimeStamp() - GR.SV.keepDays * SECONDS_IN_DAY

	local idToName = {}
	for name, id in pairs(GR.SV.guildMapping) do
		idToName[id] = name
	end

	for eventId, sale in pairs(GR.SV.savedSales) do
		if sale[1] > cutoffTime then
			GR.sales[eventId] = {
				timeStamp = sale[1],
				guildName = idToName[sale[2]],
				buyerName = sale[3],
				quantity = sale[4],
				itemLink = sale[5],
				price = sale[6],
				tax = sale[7],
				unitPrice = sale[6] / sale[4],
			}
		end
	end
end

-- ============================================
-- Item Price History Management
-- ============================================
function GR.AddPriceHistory(itemLink, price, quantity, timestamp)
	local normLink = GR.NormalizeItemLink(itemLink)

	if not GR.SV.itemPriceHistory[normLink] then
		GR.SV.itemPriceHistory[normLink] = {}
	end

	local dayId = math.floor(timestamp / 86400)
	local dayData = GR.SV.itemPriceHistory[normLink][dayId]

	if not dayData then
		GR.SV.itemPriceHistory[normLink][dayId] = { price, quantity }
	else
		dayData[1] = dayData[1] + price
		dayData[2] = dayData[2] + quantity
	end

	GR.UpdateAvgPriceCache(normLink)
end

function GR.CleanPriceHistory()
	local currentDay = math.floor(GetTimeStamp() / 86400)
	local cutoffDay = currentDay - GR.SV.keepDays
	local cleanedCount = 0

	for itemLink, dayBuckets in pairs(GR.SV.itemPriceHistory) do
		for dayId, _ in pairs(dayBuckets) do
			if dayId < cutoffDay then
				dayBuckets[dayId] = nil
				cleanedCount = cleanedCount + 1
			end
		end

		if next(dayBuckets) == nil then
			GR.SV.itemPriceHistory[itemLink] = nil
		end
	end

	if cleanedCount > 0 then
		GR.RebuildAvgPriceCache()
	end
end

GR.selectedTimeWindow = 1

local DAYS_BACK_TO_TUESDAY = {
	[0] = 2, -- Thursday
	[1] = 3, -- Friday
	[2] = 4, -- Saturday
	[3] = 5, -- Sunday
	[4] = 6, -- Monday
	[5] = 0, -- Tuesday
	[6] = 1, -- Wednesday
}

function GR.GetStartOfTradingWeek(relativeWeek)
	local currentTimeStamp = GetTimeStamp()

	local days = math.floor(currentTimeStamp / SECONDS_IN_DAY)
	local today = days % 7

	local midnightCurrentDay = days * SECONDS_IN_DAY

	local targetTuesdayMidnight = midnightCurrentDay - (DAYS_BACK_TO_TUESDAY[today] * SECONDS_IN_DAY)

	local isEU = (GetWorldName() == "EU Megaserver")
	local flipHour = isEU and 14 or 19

	local flipTimeStamp = targetTuesdayMidnight + (flipHour * SECONDS_IN_HOUR)

	if currentTimeStamp < flipTimeStamp then
		flipTimeStamp = flipTimeStamp - SECONDS_IN_WEEK
	end

	return flipTimeStamp + (relativeWeek * SECONDS_IN_WEEK)
end

function GR.IsSaleInTimeWindow(saleTimestamp)
	local now = GetTimeStamp()
	if GR.selectedTimeWindow == 1 then
		return saleTimestamp >= GR.GetStartOfTradingWeek(0)
	elseif GR.selectedTimeWindow == 2 then
		return saleTimestamp >= GR.GetStartOfTradingWeek(-1) and saleTimestamp < GR.GetStartOfTradingWeek(0)
	elseif GR.selectedTimeWindow == 3 then
		return saleTimestamp >= GR.GetStartOfTradingWeek(-2) and saleTimestamp < GR.GetStartOfTradingWeek(-1)
	elseif GR.selectedTimeWindow == 4 then
		return saleTimestamp >= GR.GetStartOfTradingWeek(-3) and saleTimestamp < GR.GetStartOfTradingWeek(-2)
	elseif GR.selectedTimeWindow == 5 then
		return saleTimestamp >= (now - (30 * SECONDS_IN_DAY))
	end
	return true
end

function GR.ShowFooterTooltip(control)
	InitializeTooltip(InformationTooltip, control, BOTTOMLEFT, 0, -5, TOPLEFT)

	InformationTooltip:AddLine("|t32:32:/esoui/art/icons/item_generic_coinbag.dds|t")

	ZO_Tooltip_AddDivider(InformationTooltip)

	local localGuildTotals = {}
	for _, sale in pairs(GR.sales) do
		if GR.IsSaleInTimeWindow(sale.timeStamp) then
			localGuildTotals[sale.guildName] = (localGuildTotals[sale.guildName] or 0) + sale.price
		end
	end

	local activeGuildsFound = false
	for guildName, gold in pairs(localGuildTotals) do
		if gold > 0 then
			activeGuildsFound = true
			local goldString = GR.FormatPriceFull(gold)

			InformationTooltip:AddLine(guildName .. ": |cE6B84C" .. goldString .. "|r")
		end
	end

	if not activeGuildsFound then
		InformationTooltip:AddLine("|t32:32:/esoui/art/inventory/inventory_sell_forbidden_icon.dds|t")
	end

	ZO_Tooltip_AddDivider(InformationTooltip)

	local lifetimeGold = GR.SV.lifetimeGold
	local lifetimeString = FormatIntegerWithDigitGrouping(math.floor(lifetimeGold), ",", 3)

	InformationTooltip:AddLine("|t20:20:/esoui/art/icons/item_generic_coinbag.dds|t	 |cE6B84C" .. lifetimeString .. " |t16:16:EsoUI/Art/currency/currency_gold.dds|t|r")
end

function GR.InitializeFooterControls()
	local dropdownControl = GetControl("GR_MainWindowFooterTimeDropdown")
	if not dropdownControl then return end

	local comboBox = ZO_ComboBox_ObjectFromContainer(dropdownControl)
	comboBox:SetFont("ZoFontGame")
	comboBox:SetSpacing(4)

	local function OnWindowOptionSelected(_, selectionString, choiceEntry)
		GR.selectedTimeWindow = choiceEntry.windowId
		GR.BuildSalesList()
	end

	local orderedOptions = {
		{
			id = 1,
			text = GetString(SI_MARKET_CURRENT_PRICE_NARRATION)
		},
		{
			id = 2,
			text = "← 1"
		},
		{
			id = 3,
			text = "← 2"
		},
		{
			id = 4,
			text = "← 3"
		},
		{
			id = 5,
			text = FormatTimeSeconds(30 * 24 * 60 * 60, TIME_FORMAT_STYLE_DESCRIPTIVE, TIME_FORMAT_PRECISION_SECONDS, TIME_FORMAT_DIRECTION_DESCENDING)
		}
	}

	for _, option in ipairs(orderedOptions) do
		local entry = comboBox:CreateItemEntry(option.text, OnWindowOptionSelected)
		entry.windowId = option.id
		comboBox:AddItem(entry, ZO_COMBOBOX_SUPPRESS_UPDATE)
	end

	comboBox:SelectItemByIndex(1)
end

function GR.CleanGuildData()
	local currentGuilds = {}
	for i = 1, GetNumGuilds() do
		local guildId = GetGuildId(i)
		local guildName = GetGuildName(guildId)
		if guildName ~= "" then
			currentGuilds[guildName] = true
		end
	end

	for guildName, _ in pairs(GR.SV.lastEventIds) do
		if not currentGuilds[guildName] then
			GR.SV.lastEventIds[guildName] = nil
		end
	end

	for guildName, _ in pairs(GR.SV.guildMapping) do
		if not currentGuilds[guildName] then
			local hasSales = false
			for _, sale in pairs(GR.sales) do
				if sale.guildName == guildName then
					hasSales = true
					break
				end
			end

			if not hasSales then
				GR.SV.guildMapping[guildName] = nil
			end
		end
	end

	for guildName, _ in pairs(GR.SV.guildProcessorsEnabled) do
		if not currentGuilds[guildName] then
			GR.SV.guildProcessorsEnabled[guildName] = nil
		end
	end
end

-- ============================================
-- Init
-- ============================================
local function OnAddOnLoaded(_, addonName)
	if addonName ~= GR.name then return end

	EM:UnregisterForEvent(GR.name, EVENT_ADD_ON_LOADED)

	GR.displayName = GetDisplayName()

	GR.SV = ZO_SavedVars:NewAccountWide("GoldRush_SV", 2, nil, defaultSV, GetWorldName())

	GR.InitSettings()

	GR.LoadSavedSales()

	GR.CleanPriceHistory()

	GR.CleanGuildData()

	GR.RebuildAvgPriceCache()

	GR.SetupTooltipHooks()

	GR.SetupKioskRowInjections()

	GR.window:SetWidth(GR.SV.windowWidth)
	GR.window:SetHeight(GR.SV.windowHeight)
	GR.window:ClearAnchors()
	GR.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, GR.SV.windowLeft, GR.SV.windowTop)

	GR.InitLibHistoire()
end

EM:RegisterForEvent(GR.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)