GuildTraderActivity = {
	name = "GTA",
	author = "@sinnereso",
	version = "2026.11.20",
	svName = "GTAVars",
	svVersion = 1,
}
local CATEGORY = GUILD_HISTORY_EVENT_CATEGORY_TRADER
local SELECTED_GUILD_LIST
local SELECTED_GUILD_ID
local SELECTED_GUILD_DATA
local SELECTED_GUILD_IS_CURRENT
local SELECTED_PLAYER_LIST
local SELECTED_USER_DISPLAY_NAME
local LINKED_INDICATOR
--local LINKED_IMAGE = "|t18:18:/esoui/art/buttons/checkbox_checked.dds|t "--radiobuttondown --checkbox_checked_disabled --featuredot_active --art/tooltips/greenarrow
--local UNLINKED_IMAGE = "|t18:18:/esoui/art/buttons/checkbox_unchecked.dds|t "--radiobuttonup --checkbox_unchecked_disabled --featuredot_inactive
local LINKED_IMAGE = "|t18:18:/esoui/art/tooltips/arrow_up.dds|t"
local UNLINKED_IMAGE = "|t18:18:/esoui/art/tooltips/arrow_down.dds|t"
--/script local resetStamp, prevStamp = GetLastKioskResetNEW() df(string.lower(tostring(os.date("%I %p %a %b %d", prevStamp))))
local function GetLastKioskResetOLD()
	local utcReset = {["NA Megaserver"] = 19, ["EU Megaserver"] = 14, ["PTS"] = 19,}
	local now = os.time()
	local local_table = os.date("*t", now)
	local_table.isdst = false
	local utc_table = os.date("!*t", now)
	local local_sec = os.time(local_table)
	local utc_sec = os.time(utc_table)
	local offset = os.difftime(local_sec, utc_sec) / 3600
	local t = os.date("!*t", now)
	local currentWday = tonumber(os.date("!%w", now))
	local daysToSubtract = (currentWday - 2 + 7) % 7
	t.hour = (utcReset[GetWorldName()] + offset)
	if daysToSubtract == 0 and (utc_table.hour + offset) < t.hour then daysToSubtract = 7 end
	t.day = t.day - daysToSubtract
	local resetStamp = os.time({year = t.year, month = t.month, day = t.day, hour = t.hour, min = 0, sec = 0})
	local prevStamp = (resetStamp - 604800)
	--df("Last Reset: " .. tostring(os.date("%Y-%m-%d %H:%M:%S", resetStamp)) .. ", Stamp: " .. tostring(resetStamp) .. ", Timezone: (" .. tostring(offset) .. ")")
	return resetStamp, prevStamp
end
--/script local resetStamp, prevStamp = GetLastKioskResetNEW() df(string.lower(tostring(os.date("%I %p %a %b %d", prevStamp))))
--local resetTime = tostring(os.date("%Y-%m-%d %I:%M:%S %p", resetStamp))
--local prevresetTime = tostring(os.date("%Y-%m-%d %I:%M:%S %p", prevStamp))
local function GetLastKioskReset()
	local ONE_WEEK = 604800
	local despawn, bidend, respawn = GetGuildKioskCycleTimes()
	local resetStamp = (bidend - ONE_WEEK)
	if (GetTimeStamp() - resetStamp) > ONE_WEEK then
		resetStamp = resetStamp + ONE_WEEK
	end
	local prevStamp = (resetStamp - ONE_WEEK)
	return resetStamp, prevStamp
end

local function GuildTraderHistoryTrim(isSlash)
	local nowStamp = GetTimeStamp()
	local monthStamp = nowStamp - 2592000
	local resetStamp, prevStamp = GetLastKioskReset()
	if GuildTraderActivity.savedVariables.cacheTrim and GuildTraderActivity.savedVariables.lastReset ~= resetStamp or isSlash then
		GuildTraderActivity.savedVariables.lastReset = resetStamp
		for i = 1, GetNumGuilds() do
			local guildId = GetGuildId(i)
			local guildName = GetGuildName(guildId)
			local newestIndex, oldestIndex = GetGuildHistoryEventIndicesForTimeRange(guildId, CATEGORY, prevStamp, monthStamp)
			local targetTime = GetGuildHistoryEventTimestamp(guildId, CATEGORY, newestIndex)
			if targetTime < prevStamp and targetTime > monthStamp then
				ClearGuildHistoryCache(guildId, CATEGORY, nowStamp - targetTime)
			end
			if isSlash then df(guildName .. " - Newest: " .. tostring(os.date("%c", targetTime))) end
		end
		df("|c6666FF[GTA]|r Trimmed trader cache data")
	end
end

local function IsGuildHistoryGaplessBetween(guildId, category, oldestTimeS, newestTimeS)
	-- 1. Find the oldest event index that is connected to the present without any gaps. Index 1 is newest.
	local oldestGaplessIndex = GetOldestGuildHistoryEventIndexForUpToDateEventsWithoutGaps(guildId, category)
	if not oldestGaplessIndex then
		return true
		--"No up-to-date gapless history cached yet."--false
	end
	-- 2. Get the event indices covering your target time range.
	local newestEventIndex, oldestEventIndex = GetGuildHistoryEventIndicesForTimeRange(guildId, category, newestTimeS, oldestTimeS)
	if not newestEventIndex or not oldestEventIndex then
		return false
		--"No cached events found in the specified time range."
	end
	-- 3. Verify that the oldest event in your target range is within the gapless boundary &
	-- verify the cache actually extends at least as far back as oldestTimeS.
	if oldestEventIndex <= oldestGaplessIndex then
		local _, actualOldestTimestamp = GetGuildHistoryEventBasicInfo(guildId, category, oldestEventIndex)
		local _, oldestGaplessTimestamp = GetGuildHistoryEventBasicInfo(guildId, category, oldestGaplessIndex)
		if oldestGaplessTimestamp <= oldestTimeS then
			return true
			--"Range is completely cached and gapless."
		else
			return false
			--"Events exist, but gapless history does not reach all the way back to oldestTimeS."
		end
	end
	return true
	--"There is an uncached gap between the present and your target time range."--false
end
---------------------------------------------
--------- PERSONAL VIEW LAYOUT ROWS --
---------------------------------------------
local function LayoutNameRow(ctrl, data, scrollList)
	ctrl:SetFont("ZoFontBookPaper")
	ctrl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
	ctrl:SetColor(0.1, 0.1, 0.1, 0.9)
	ctrl:SetHandler("OnMouseEnter", function(self)
		ctrl:SetColor(0.1, 0.1, 0.1, 0.9)
		if string.find(data.name, LINKED_IMAGE, 1, true) then
			ZO_Tooltips_ShowTextTooltip(ctrl, LEFT, "(|c339933COMPLETE|r) ~ VIEW GUILD DETAILS")
		else
			ZO_Tooltips_ShowTextTooltip(ctrl, LEFT, "(|ce06666INCOMPLETE|r) ~ VIEW GUILD DETAILS")
		end
	end)
	ctrl:SetHandler("OnMouseExit", function(self)
		ctrl:SetColor(0.1, 0.1, 0.1, 0.9)
		ClearTooltip(InformationTooltip)
	end)
	ctrl:SetHandler("OnMouseUp", function(self, button, upInside)
		if button == 1 and upInside then
			PlaySound("Click")
			zo_callLater(function()
				GuildTraderActivity.CreateGuildList(data, true)
				EVENT_MANAGER:RegisterForEvent("GTA", EVENT_GUILD_MEMBER_ADDED, GuildTraderActivity.UpdateForGuildDataChange)
				EVENT_MANAGER:RegisterForEvent("GTA", EVENT_GUILD_MEMBER_REMOVED, GuildTraderActivity.UpdateForGuildDataChange)
				EVENT_MANAGER:RegisterForEvent("GTA", EVENT_GUILD_MEMBER_RANK_CHANGED, GuildTraderActivity.UpdateForGuildDataChange)
				EVENT_MANAGER:RegisterForEvent("GTA", EVENT_GUILD_MEMBER_NOTE_CHANGED, GuildTraderActivity.UpdateForGuildDataChange)
			end, 50)
		end
	end)
	ctrl:SetMaxLineCount(1)
	ctrl:SetText(tostring(data.name) .. " ~ " .. tostring(ZO_LocalizeDecimalNumber(data.total)))
end

local function LayoutSalesRow(ctrl, data, scrollList)
	ctrl:SetFont("ZoFontBookPaper")
	ctrl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
	ctrl:SetColor(0.1, 0.1, 0.1, 0.9)
	ctrl:SetHandler("OnMouseEnter", function(self)
		ctrl:SetColor(0.1, 0.1, 0.1, 0.9)
	end)
	ctrl:SetHandler("OnMouseExit", function(self)
		ctrl:SetColor(0.1, 0.1, 0.1, 0.9)
	end)
	ctrl:SetMaxLineCount(1)
	ctrl:SetText(tostring(ZO_LocalizeDecimalNumber(data.sales)))
end

local function LayoutPurchaseRow(ctrl, data, scrollList)
	ctrl:SetFont("ZoFontBookPaper")
	ctrl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
	ctrl:SetColor(0.1, 0.1, 0.1, 0.9)
	ctrl:SetHandler("OnMouseEnter", function(self)
		ctrl:SetColor(0.1, 0.1, 0.1, 0.9)
	end)
	ctrl:SetHandler("OnMouseExit", function(self)
		ctrl:SetColor(0.1, 0.1, 0.1, 0.9)
	end)
	ctrl:SetMaxLineCount(1)
	ctrl:SetText(tostring(ZO_LocalizeDecimalNumber(data.purchases)))
end

local function LayoutActivityRow(ctrl, data, scrollList)
	ctrl:SetFont("ZoFontBookPaper")
	ctrl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
	ctrl:SetColor(0.1, 0.1, 0.1, 0.9)
	ctrl:SetHandler("OnMouseEnter", function(self)
		ctrl:SetColor(0.1, 0.1, 0.1, 0.9)
	end)
	ctrl:SetHandler("OnMouseExit", function(self)
		ctrl:SetColor(0.1, 0.1, 0.1, 0.9)
	end)
	ctrl:SetMaxLineCount(1)
	ctrl:SetText(tostring(ZO_LocalizeDecimalNumber(data.activity)))
end

local function LayoutPreviousNameRow(ctrl, data, scrollList)
	ctrl:SetFont("ZoFontBookPaper")
	ctrl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
	ctrl:SetColor(0.1, 0.1, 0.1, 0.9)
	ctrl:SetHandler("OnMouseEnter", function(self)
		ctrl:SetColor(0.1, 0.1, 0.1, 0.9)
		if string.find(data.name, LINKED_IMAGE, 1, true) then
			ZO_Tooltips_ShowTextTooltip(ctrl, LEFT, "(|c339933COMPLETE|r) ~ VIEW GUILD DETAILS")
		else
			ZO_Tooltips_ShowTextTooltip(ctrl, LEFT, "(|ce06666INCOMPLETE|r) ~ VIEW GUILD DETAILS")
		end
	end)
	ctrl:SetHandler("OnMouseExit", function(self)
		ctrl:SetColor(0.1, 0.1, 0.1, 0.9)
		ClearTooltip(InformationTooltip)
	end)
	ctrl:SetHandler("OnMouseUp", function(self, button, upInside)
		if button == 1 and upInside then
			PlaySound("Click")
			zo_callLater(function()
				GuildTraderActivity.CreateGuildList(data, false)
				EVENT_MANAGER:RegisterForEvent("GTA", EVENT_GUILD_MEMBER_ADDED, GuildTraderActivity.UpdateForGuildDataChange)
				EVENT_MANAGER:RegisterForEvent("GTA", EVENT_GUILD_MEMBER_REMOVED, GuildTraderActivity.UpdateForGuildDataChange)
				EVENT_MANAGER:RegisterForEvent("GTA", EVENT_GUILD_MEMBER_RANK_CHANGED, GuildTraderActivity.UpdateForGuildDataChange)
				EVENT_MANAGER:RegisterForEvent("GTA", EVENT_GUILD_MEMBER_NOTE_CHANGED, GuildTraderActivity.UpdateForGuildDataChange)
			end, 50)
		end
	end)
	ctrl:SetMaxLineCount(1)
	ctrl:SetText(tostring(data.name) .. " ~ " .. tostring(ZO_LocalizeDecimalNumber(data.total)))
end

local function LayoutPreviousSalesRow(ctrl, data, scrollList)
	ctrl:SetFont("ZoFontBookPaper")
	ctrl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
	ctrl:SetColor(0.1, 0.1, 0.1, 0.9)
	ctrl:SetHandler("OnMouseEnter", function(self)
		ctrl:SetColor(0.1, 0.1, 0.1, 0.9)
	end)
	ctrl:SetHandler("OnMouseExit", function(self)
		ctrl:SetColor(0.1, 0.1, 0.1, 0.9)
	end)
	ctrl:SetMaxLineCount(1)
	ctrl:SetText(tostring(ZO_LocalizeDecimalNumber(data.sales)))
end

local function LayoutPreviousPurchaseRow(ctrl, data, scrollList)
	ctrl:SetFont("ZoFontBookPaper")
	ctrl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
	ctrl:SetColor(0.1, 0.1, 0.1, 0.9)
	ctrl:SetHandler("OnMouseEnter", function(self)
		ctrl:SetColor(0.1, 0.1, 0.1, 0.9)
	end)
	ctrl:SetHandler("OnMouseExit", function(self)
		ctrl:SetColor(0.1, 0.1, 0.1, 0.9)
	end)
	ctrl:SetMaxLineCount(1)
	ctrl:SetText(tostring(ZO_LocalizeDecimalNumber(data.purchases)))
end

local function LayoutPreviousActivityRow(ctrl, data, scrollList)
	ctrl:SetFont("ZoFontBookPaper")
	ctrl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
	ctrl:SetColor(0.1, 0.1, 0.1, 0.9)
	ctrl:SetHandler("OnMouseEnter", function(self)
		ctrl:SetColor(0.1, 0.1, 0.1, 0.9)
	end)
	ctrl:SetHandler("OnMouseExit", function(self)
		ctrl:SetColor(0.1, 0.1, 0.1, 0.9)
	end)
	ctrl:SetMaxLineCount(1)
	ctrl:SetText(tostring(ZO_LocalizeDecimalNumber(data.activity)))
end
---------------------------------------------
------------- MAIN WINDOW --
---------------------------------------------
-- Trader Activity Scroll Window --
local GTAMain = WINDOW_MANAGER:CreateTopLevelWindow("Guild Trader Activity")
GTAMain:SetAnchor(CENTER, GuiRoot, CENTER, 0, -120)
GTAMain:SetDimensions(900, 600)
local GTABackground = WINDOW_MANAGER:CreateControl("GTABg", GTAMain, CT_TEXTURE)
GTABackground:SetAnchorFill(GTAMain)
GTABackground:SetTexture("GTA/scroll.dds")
local GTA_SCENE = ZO_Scene:New("GTA", SCENE_MANAGER)
local GTAFragment = ZO_FadeSceneFragment:New(GTAMain)
GTA_SCENE:AddFragment(GTAFragment)
GTA_SCENE:AddFragment(MOUSE_UI_MODE_FRAGMENT)
local GTALogo = WINDOW_MANAGER:CreateControl("GTALogo", GTAMain, CT_LABEL)
GTALogo:SetAnchor(TOP, GTAMain, TOP, 0, 20)
GTALogo:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
GTALogo:SetVerticalAlignment(TEXT_ALIGN_CENTER)
GTALogo:SetFont("ZoFontBookScrollTitle")
GTALogo:SetColor(0.1, 0.1, 0.1, 0.9)
GTALogo:SetText("G T A")
local GTASig = WINDOW_MANAGER:CreateControl("GTASig", GTAMain, CT_LABEL)
GTASig:SetAnchor(BOTTOMLEFT, GTALogo, BOTTOMRIGHT, 6, -6)
GTASig:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
GTASig:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
GTASig:SetFont(string.format("%s|%d", "$(HANDWRITTEN_FONT)", 14), FONT_STYLE_SOFT_SHADOW_THIN)
GTASig:SetColor(0.1, 0.1, 0.1, 0.9)
GTASig:SetText("By: sinnereso")
local GTADisclaimer = WINDOW_MANAGER:CreateControl("GTADisclaimer", GTAMain, CT_LABEL)
GTADisclaimer:SetAnchor(BOTTOM, GTAMain, BOTTOM, 0, -36)
GTADisclaimer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
GTADisclaimer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
GTADisclaimer:SetFont(string.format("%s|%d", "$(HANDWRITTEN_FONT)", 16), FONT_STYLE_SOFT_SHADOW_THIN)
GTADisclaimer:SetColor(0.1, 0.1, 0.1, 0.9)
GTADisclaimer:SetText("")
--ShowAllButton
local GTAShowAllBox = WINDOW_MANAGER:CreateControlFromVirtual("GTAShowAllBox", GTAMain, "ZO_CheckButton")
GTAShowAllBox:SetAnchor(LEFT, GTADisclaimer, RIGHT, 20, -14)
ZO_CheckButton_SetLabelText(GTAShowAllBox, "Show All Guilds")
local GTAShowAllLabel = GTAShowAllBox.label
GTAShowAllLabel:ClearAnchors()
--GTAShowAllLabel:SetAnchor(RIGHT, GTAShowAllBox, LEFT, -5, 4)
GTAShowAllLabel:SetAnchor(LEFT, GTAShowAllBox, RIGHT, 5, 2)
GTAShowAllLabel:SetFont(string.format("%s|%d", "$(HANDWRITTEN_FONT)", 16), FONT_STYLE_SOFT_SHADOW_THIN)
GTAShowAllLabel:SetColor(0.1, 0.1, 0.1, 0.9)
GTAShowAllLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
--GTAShowAllLabel:SetText("Show All")
GTAShowAllBox:SetHandler("OnMouseEnter", function(self)
	GTAShowAllBoxLabel:SetColor(0.1, 0.1, 0.1, 0.9)
	--InitializeTooltip(InformationTooltip, self, BOTTOM, 0, 0)
	--SetTooltipText(InformationTooltip, "SHOW ALL GUILDS")
end)
GTAShowAllBox:SetHandler("OnMouseExit", function(self)
	GTAShowAllBoxLabel:SetColor(0.1, 0.1, 0.1, 0.9)
	--ClearTooltip(InformationTooltip)
end)
GTAShowAllBoxLabel:SetHandler("OnMouseEnter", function(self)
	GTAShowAllBoxLabel:SetColor(0.1, 0.1, 0.1, 0.9)
	--InitializeTooltip(InformationTooltip, self, BOTTOM, 0, 0)
	--SetTooltipText(InformationTooltip, "SHOW ALL GUILDS")
end)
GTAShowAllBoxLabel:SetHandler("OnMouseExit", function(self)
	GTAShowAllBoxLabel:SetColor(0.1, 0.1, 0.1, 0.9)
	--ClearTooltip(InformationTooltip)
end)
local function OnShowAllBoxToggled(GTAShowAllBox, checkedState)
	GuildTraderActivity.savedVariables.showAll = checkedState
	GTAShowAllBoxLabel:SetColor(0.1, 0.1, 0.1, 0.9)
	GuildTraderActivity.Refresh()
end
ZO_CheckButton_SetToggleFunction(GTAShowAllBox, OnShowAllBoxToggled)
--CacheTrimButton
local GTACacheTrimBox = WINDOW_MANAGER:CreateControlFromVirtual("GTACacheTrimBox", GTAMain, "ZO_CheckButton")
GTACacheTrimBox:SetAnchor(LEFT, GTADisclaimer, RIGHT, 20, 7)
ZO_CheckButton_SetLabelText(GTACacheTrimBox, "Auto Cache Trim")
local GTACacheTrimBoxLabel = GTACacheTrimBox.label
GTACacheTrimBoxLabel:ClearAnchors()
GTACacheTrimBoxLabel:SetAnchor(LEFT, GTACacheTrimBox, RIGHT, 5, 2)
GTACacheTrimBoxLabel:SetFont(string.format("%s|%d", "$(HANDWRITTEN_FONT)", 16), FONT_STYLE_SOFT_SHADOW_THIN)
GTACacheTrimBoxLabel:SetColor(0.1, 0.1, 0.1, 0.9)
GTACacheTrimBoxLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
--GTACacheTrimBoxLabel:SetText("Cache Trim")
GTACacheTrimBox:SetHandler("OnMouseEnter", function(self)
	GTACacheTrimBoxLabel:SetColor(0.1, 0.1, 0.1, 0.9)
	--InitializeTooltip(InformationTooltip, self, BOTTOM, 0, 0)
	--SetTooltipText(InformationTooltip, "TRIM PREVIOUS IRRELEVANT DATA")
end)
GTACacheTrimBox:SetHandler("OnMouseExit", function(self)
	GTACacheTrimBoxLabel:SetColor(0.1, 0.1, 0.1, 0.9)
	--ClearTooltip(InformationTooltip)
end)
GTACacheTrimBoxLabel:SetHandler("OnMouseEnter", function(self)
	GTACacheTrimBoxLabel:SetColor(0.1, 0.1, 0.1, 0.9)
	--InitializeTooltip(InformationTooltip, self, BOTTOM, 0, 0)
	--SetTooltipText(InformationTooltip, "AUTO TRIM CACHE")
end)
GTACacheTrimBoxLabel:SetHandler("OnMouseExit", function(self)
	GTACacheTrimBoxLabel:SetColor(0.1, 0.1, 0.1, 0.9)
	--ClearTooltip(InformationTooltip)
end)
local function OnCacheTrimBoxToggled(GTACacheTrimBox, checkedState)
	GuildTraderActivity.savedVariables.cacheTrim = checkedState
	GTACacheTrimBoxLabel:SetColor(0.1, 0.1, 0.1, 0.9)
end
ZO_CheckButton_SetToggleFunction(GTACacheTrimBox, OnCacheTrimBoxToggled)
--CloseButton
local GTACloseButton = WINDOW_MANAGER:CreateControl("GTACloseButton", GTAMain, CT_BUTTON)
GTACloseButton:SetAnchor(TOPRIGHT, nil, TOPRIGHT, -20, 104)
GTACloseButton:SetDimensions(32, 32)
GTACloseButton:SetNormalTexture("/esoui/art/buttons/closebutton_up.dds")
GTACloseButton:SetPressedTexture("/esoui/art/buttons/closebutton_down.dds")
GTACloseButton:SetMouseOverTexture("/esoui/art/buttons/closebutton_mouseover.dds")--over
GTACloseButton:SetMouseEnabled(true)
GTACloseButton:SetHandler("OnMouseEnter", function(self)
	InitializeTooltip(InformationTooltip, self, BOTTOM, 0, 0)
	SetTooltipText(InformationTooltip, "CLOSE")
end)
GTACloseButton:SetHandler("OnMouseExit", function(self)
	ClearTooltip(InformationTooltip)
end)
GTACloseButton:SetHandler("OnMouseUp", function(self, button, upInside)
	if button == 1 and upInside then
		PlaySound("Click")
		GuildTraderActivity.Toggle()
	end
end)
---------------------------------------------
--------- PERSONAL VIEW CONTROLS --
---------------------------------------------
--local GTAPersonalView = WINDOW_MANAGER:CreateTopLevelWindow("GTAPersonalView")
local GTAPersonalView = WINDOW_MANAGER:CreateControl("GTAPersonalView", GTAMain, CT_CONTROL)
GTAPersonalView:SetAnchor(CENTER, GTAMain, CENTER, -2, -10)
GTAPersonalView:SetParent(GTAMain)
GTAPersonalView:SetDimensions(766, 374)
--local GTAPersonalViewBackground = WINDOW_MANAGER:CreateControl("testBackground", GTAPersonalView, CT_BACKDROP)
--GTAPersonalViewBackground:SetAnchorFill(GTAPersonalView)
-- CURRENT SECTION --
--CurrentLabel
local GTACurrentLabel = WINDOW_MANAGER:CreateControl("GTACurrentLabel", GTAPersonalView, CT_LABEL)
GTACurrentLabel:SetAnchor(TOP, GTAPersonalView, TOP, 0, -4)
GTACurrentLabel:SetFont(string.format("%s|%d", "$(HANDWRITTEN_FONT)", 26), FONT_STYLE_SOFT_SHADOW_THIN)
GTACurrentLabel:SetColor(0.1, 0.1, 0.1, 0.8)
GTACurrentLabel:SetText("~ Current Week ~")
--CurrentNameList
local GTANameList = WINDOW_MANAGER:CreateControlFromVirtual("GTANameList", GTAPersonalView, "ZO_ScrollList")
local scrollListHeight = 104
GTANameList:SetDimensions(380, scrollListHeight)--350
GTANameList:SetAnchor(TOPLEFT, GTAPersonalView, TOPLEFT, 0, 58)
ZO_ScrollList_AddDataType(GTANameList, 1, "ZO_SelectableLabel", 20, LayoutNameRow)
local GTANameLabel = WINDOW_MANAGER:CreateControl("GTANameLabel", GTAPersonalView, CT_LABEL)
GTANameLabel:SetAnchor(BOTTOMLEFT, GTANameList, TOPLEFT, 17, 0)-- 0, 0)-->> Adjusted for LINKED indicator
GTANameLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
GTANameLabel:SetFont("ZoFontGameMedium")
GTANameLabel:SetColor(0.3, 0.3, 0.2, 0.9)
GTANameLabel:SetText("GUILD NAME  ~  GUILD TOTAL |t20:20:/esoui/art/buttons/scrollbox_downarrow_up.dds|t")
GTANameLabel:SetMouseEnabled(true)
GTANameLabel:SetHandler("OnMouseUp", function(self, button, upInside)
	if button == 1 and upInside then
		PlaySound("Click")
		zo_callLater(function()
			GuildTraderActivity.savedVariables.activitySorting = "name"
			GuildTraderActivity.Refresh()
		end, 50)
	end
end)
GTANameLabel:SetHandler("OnMouseEnter", function(self)
	InitializeTooltip(InformationTooltip, self, BOTTOM, 0, 0)
	SetTooltipText(InformationTooltip, "SORT BY NAME")
end)
GTANameLabel:SetHandler("OnMouseExit", function(self)
	ClearTooltip(InformationTooltip)
end)
--CurrentsalesList
local GTASalesList = WINDOW_MANAGER:CreateControlFromVirtual("GTASalesList", GTAPersonalView, "ZO_ScrollList")
GTASalesList:SetDimensions(130, scrollListHeight)--140
GTASalesList:SetAnchor(LEFT, GTANameList, RIGHT, 4, 0)
ZO_ScrollList_AddDataType(GTASalesList, 1, "ZO_SelectableLabel", 20, LayoutSalesRow)
local GTASalesLabel = WINDOW_MANAGER:CreateControl("GTASalesLabel", GTAPersonalView, CT_LABEL)
GTASalesLabel:SetAnchor(BOTTOMRIGHT, GTASalesList, TOPRIGHT, -16, 0)
GTASalesLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
GTASalesLabel:SetFont("ZoFontGameMedium")
GTASalesLabel:SetColor(0.3, 0.3, 0.2, 0.9)
GTASalesLabel:SetText("|t20:20:/esoui/art/buttons/scrollbox_downarrow_up.dds|t TRADED")
GTASalesLabel:SetMouseEnabled(true)
GTASalesLabel:SetHandler("OnMouseUp", function(self, button, upInside)
	if button == 1 and upInside then
		PlaySound("Click")
		zo_callLater(function()
			GuildTraderActivity.savedVariables.activitySorting = "sales"
			GuildTraderActivity.Refresh()
		end, 50)
	end
end)
GTASalesLabel:SetHandler("OnMouseEnter", function(self)
	InitializeTooltip(InformationTooltip, self, BOTTOM, 0, 0)
	SetTooltipText(InformationTooltip, "SORT BY SALES")
end)
GTASalesLabel:SetHandler("OnMouseExit", function(self)
	ClearTooltip(InformationTooltip)
end)
--CurrentpurchaseList
local GTAPurchaseList = WINDOW_MANAGER:CreateControlFromVirtual("GTAPurchaseList", GTAPersonalView, "ZO_ScrollList")
GTAPurchaseList:SetDimensions(130, scrollListHeight)--140
GTAPurchaseList:SetAnchor(LEFT, GTASalesList, RIGHT, 4, 0)
ZO_ScrollList_AddDataType(GTAPurchaseList, 1, "ZO_SelectableLabel", 20, LayoutPurchaseRow)
local GTAPurchaseLabel = WINDOW_MANAGER:CreateControl("GTAPurchaseLabel", GTAPersonalView, CT_LABEL)
GTAPurchaseLabel:SetAnchor(BOTTOMRIGHT, GTAPurchaseList, TOPRIGHT, -16, 0)
GTAPurchaseLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
GTAPurchaseLabel:SetFont("ZoFontGameMedium")
GTAPurchaseLabel:SetColor(0.3, 0.3, 0.2, 0.9)
GTAPurchaseLabel:SetText("|t20:20:/esoui/art/buttons/scrollbox_downarrow_up.dds|t BOUGHT")
GTAPurchaseLabel:SetMouseEnabled(true)
GTAPurchaseLabel:SetHandler("OnMouseUp", function(self, button, upInside)
	if button == 1 and upInside then
		PlaySound("Click")
		zo_callLater(function()
			GuildTraderActivity.savedVariables.activitySorting = "purchases"
			GuildTraderActivity.Refresh()
		end, 50)
	end
end)
GTAPurchaseLabel:SetHandler("OnMouseEnter", function(self)
	InitializeTooltip(InformationTooltip, self, BOTTOM, 0, 0)
	SetTooltipText(InformationTooltip, "SORT BY PURCHASES")
end)
GTAPurchaseLabel:SetHandler("OnMouseExit", function(self)
	ClearTooltip(InformationTooltip)
end)
--CurrentactivityList
local GTAActivityList = WINDOW_MANAGER:CreateControlFromVirtual("GTAActivityList", GTAPersonalView, "ZO_ScrollList")
GTAActivityList:SetDimensions(130, scrollListHeight)--140
GTAActivityList:SetAnchor(LEFT, GTAPurchaseList, RIGHT, 4, 0)
ZO_ScrollList_AddDataType(GTAActivityList, 1, "ZO_SelectableLabel", 20, LayoutActivityRow)
local GTAActivityLabel = WINDOW_MANAGER:CreateControl("GTAActivityLabel", GTAPersonalView, CT_LABEL)
GTAActivityLabel:SetAnchor(BOTTOMRIGHT, GTAActivityList, TOPRIGHT, -16, 0)
GTAActivityLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
GTAActivityLabel:SetFont("ZoFontGameMedium")
GTAActivityLabel:SetColor(0.3, 0.3, 0.2, 0.9)
GTAActivityLabel:SetText("|t20:20:/esoui/art/buttons/scrollbox_downarrow_up.dds|t ACTIVITY")
GTAActivityLabel:SetMouseEnabled(true)
GTAActivityLabel:SetHandler("OnMouseUp", function(self, button, upInside)
	if button == 1 and upInside then
		PlaySound("Click")
		zo_callLater(function()
			GuildTraderActivity.savedVariables.activitySorting = "activity"
			GuildTraderActivity.Refresh()
		end, 50)
	end
end)
GTAActivityLabel:SetHandler("OnMouseEnter", function(self)
	InitializeTooltip(InformationTooltip, self, BOTTOM, 0, 0)
	SetTooltipText(InformationTooltip, "SORT BY ACTIVITY")
end)
GTAActivityLabel:SetHandler("OnMouseExit", function(self)
	ClearTooltip(InformationTooltip)
end)
--CurrentTotalSales
local GTATotalCurrentSalesLabel = WINDOW_MANAGER:CreateControl("GTATotalCurrentSalesLabel", GTAPersonalView, CT_LABEL)
GTATotalCurrentSalesLabel:SetAnchor(TOPRIGHT, GTASalesList, BOTTOMRIGHT, -16, 0)
GTATotalCurrentSalesLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
GTATotalCurrentSalesLabel:SetFont("ZoFontBookPaper")
GTATotalCurrentSalesLabel:SetColor(0.1, 0.1, 0.1, 0.9)
GTATotalCurrentSalesLabel:SetText("")
--CurrentTotalPurchases
local GTATotalCurrentPurchasesLabel = WINDOW_MANAGER:CreateControl("GTATotalCurrentPurchasesLabel", GTAPersonalView, CT_LABEL)
GTATotalCurrentPurchasesLabel:SetAnchor(TOPRIGHT, GTAPurchaseList, BOTTOMRIGHT, -16, 0)
GTATotalCurrentPurchasesLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
GTATotalCurrentPurchasesLabel:SetFont("ZoFontBookPaper")
GTATotalCurrentPurchasesLabel:SetColor(0.1, 0.1, 0.1, 0.9)
GTATotalCurrentPurchasesLabel:SetText("")
--CurrentTotalActivity
local GTATotalCurrentActivityLabel = WINDOW_MANAGER:CreateControl("GTATotalCurrentActivityLabel", GTAPersonalView, CT_LABEL)
GTATotalCurrentActivityLabel:SetAnchor(TOPRIGHT, GTAActivityList, BOTTOMRIGHT, -16, 0)
GTATotalCurrentActivityLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
GTATotalCurrentActivityLabel:SetFont("ZoFontBookPaper")
GTATotalCurrentActivityLabel:SetColor(0.1, 0.1, 0.1, 0.9)
GTATotalCurrentActivityLabel:SetText("")
--Divider
local GTADivider = WINDOW_MANAGER:CreateControl("GTADivider", GTAPersonalView, CT_TEXTURE)
GTADivider:SetAnchor(CENTER, GTAPersonalView, CENTER, 0, 14)
GTADivider:SetDimensions(780, 6)
GTADivider:SetTexture("/esoui/art/miscellaneous/horizontaldivider.dds")
GTADivider:SetAlpha(0.5)
-- PREVIOUS SECTION --
--Previouslabel
local GTAPreviousLabel = WINDOW_MANAGER:CreateControl("GTAPreviousLabel", GTAPersonalView, CT_LABEL)
GTAPreviousLabel:SetAnchor(TOP, GTADivider, BOTTOM, 0, 4)
GTAPreviousLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
GTAPreviousLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
GTAPreviousLabel:SetFont(string.format("%s|%d", "$(HANDWRITTEN_FONT)", 26), FONT_STYLE_SOFT_SHADOW_THIN)
GTAPreviousLabel:SetColor(0.1, 0.1, 0.1, 0.8)
GTAPreviousLabel:SetText("~ Previous Week ~")
--PreviousNameList
local GTAPreviousNameList = WINDOW_MANAGER:CreateControlFromVirtual("GTAPreviousNameList", GTAPersonalView, "ZO_ScrollList")
GTAPreviousNameList:SetDimensions(380, scrollListHeight)--350
GTAPreviousNameList:SetAnchor(BOTTOMLEFT, GTAPersonalView, BOTTOMLEFT, 0, -24)
ZO_ScrollList_AddDataType(GTAPreviousNameList, 2, "ZO_SelectableLabel", 20, LayoutPreviousNameRow)
--PreviousSalesList
local GTAPreviousSalesList = WINDOW_MANAGER:CreateControlFromVirtual("GTAPreviousSalesList", GTAPersonalView, "ZO_ScrollList")
GTAPreviousSalesList:SetDimensions(130, scrollListHeight)--140
GTAPreviousSalesList:SetAnchor(LEFT, GTAPreviousNameList, RIGHT, 4, 0)
ZO_ScrollList_AddDataType(GTAPreviousSalesList, 2, "ZO_SelectableLabel", 20, LayoutPreviousSalesRow)
--PreviousPurchaseList
local GTAPreviousPurchaseList = WINDOW_MANAGER:CreateControlFromVirtual("GTAPreviousPurchaseList", GTAPersonalView, "ZO_ScrollList")
GTAPreviousPurchaseList:SetDimensions(130, scrollListHeight)--140
GTAPreviousPurchaseList:SetAnchor(LEFT, GTAPreviousSalesList, RIGHT, 4, 0)
ZO_ScrollList_AddDataType(GTAPreviousPurchaseList, 2, "ZO_SelectableLabel", 20, LayoutPreviousPurchaseRow)
--PreviousActivityList
local GTAPreviousActivityList = WINDOW_MANAGER:CreateControlFromVirtual("GTAPreviousActivityList", GTAPersonalView, "ZO_ScrollList")
GTAPreviousActivityList:SetDimensions(130, scrollListHeight)--140
GTAPreviousActivityList:SetAnchor(LEFT, GTAPreviousPurchaseList, RIGHT, 4, 0)
ZO_ScrollList_AddDataType(GTAPreviousActivityList, 2, "ZO_SelectableLabel", 20, LayoutPreviousActivityRow)
--PreviousTotalSales
local GTATotalPreviousSalesLabel = WINDOW_MANAGER:CreateControl("GTATotalPreviousSalesLabel", GTAPersonalView, CT_LABEL)
GTATotalPreviousSalesLabel:SetAnchor(TOPRIGHT, GTAPreviousSalesList, BOTTOMRIGHT, -16, 0)
GTATotalPreviousSalesLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
GTATotalPreviousSalesLabel:SetFont("ZoFontBookPaper")
GTATotalPreviousSalesLabel:SetColor(0.1, 0.1, 0.1, 0.9)
GTATotalPreviousSalesLabel:SetText("")
--PreviousTotalPurchases
local GTATotalPreviousPurchaseLabel = WINDOW_MANAGER:CreateControl("GTATotalPreviousPurchaseLabel", GTAPersonalView, CT_LABEL)
GTATotalPreviousPurchaseLabel:SetAnchor(TOPRIGHT, GTAPreviousPurchaseList, BOTTOMRIGHT, -16, 0)
GTATotalPreviousPurchaseLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
GTATotalPreviousPurchaseLabel:SetFont("ZoFontBookPaper")
GTATotalPreviousPurchaseLabel:SetColor(0.1, 0.1, 0.1, 0.9)
GTATotalPreviousPurchaseLabel:SetText("")
--PreviousTotalActivity
local GTATotalPreviousActivityLabel = WINDOW_MANAGER:CreateControl("GTATotalPreviousActivityLabel", GTAPersonalView, CT_LABEL)
GTATotalPreviousActivityLabel:SetAnchor(TOPRIGHT, GTAPreviousActivityList, BOTTOMRIGHT, -16, 0)
GTATotalPreviousActivityLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
GTATotalPreviousActivityLabel:SetFont("ZoFontBookPaper")
GTATotalPreviousActivityLabel:SetColor(0.1, 0.1, 0.1, 0.9)
GTATotalPreviousActivityLabel:SetText("")
---------------------------------------------
--------- GUILD LIST VIEW CONTROLS --
---------------------------------------------
--local GTASelectedGuildView = WINDOW_MANAGER:CreateTopLevelWindow("GTASelectedGuildView")
local GTASelectedGuildView = WINDOW_MANAGER:CreateControl("GTASelectedGuildView", GTAMain, CT_CONTROL)
GTASelectedGuildView:SetAnchor(CENTER, GTAMain, CENTER, -2, -10)
--GTASelectedGuildView:SetParent(GTAMain)
GTASelectedGuildView:SetDimensions(766, 374)
--SelectedGuildLabel
local GTASelectedGuildLabel = WINDOW_MANAGER:CreateControl("GTASelectedGuildLabel", GTASelectedGuildView, CT_LABEL)
GTASelectedGuildLabel:SetAnchor(TOP, GTASelectedGuildView, TOP, 0, -4)
GTASelectedGuildLabel:SetFont(string.format("%s|%d", "$(HANDWRITTEN_FONT)", 26), FONT_STYLE_SOFT_SHADOW_THIN)
GTASelectedGuildLabel:SetColor(0.1, 0.1, 0.1, 0.8)
GTASelectedGuildLabel:SetText("")
--SelectedGuildBackArrow
local GTASelectedGuildBackArrow = WINDOW_MANAGER:CreateControl("GTASelectedGuildBackArrow", GTASelectedGuildLabel, CT_BUTTON)
GTASelectedGuildBackArrow:SetAnchor(RIGHT, nil, LEFT, -16)
GTASelectedGuildBackArrow:SetDimensions(32, 32)
GTASelectedGuildBackArrow:SetNormalTexture("/esoui/art/buttons/large_leftarrow_up.dds")
GTASelectedGuildBackArrow:SetPressedTexture("/esoui/art/buttons/large_leftarrow_down.dds")
GTASelectedGuildBackArrow:SetMouseOverTexture("/esoui/art/buttons/large_leftarrow_over.dds")
GTASelectedGuildBackArrow:SetMouseEnabled(true)
GTASelectedGuildBackArrow:SetHandler("OnMouseEnter", function(self)
	InitializeTooltip(InformationTooltip, self, BOTTOM, 0, 0)
	SetTooltipText(InformationTooltip, "BACK")
end)
GTASelectedGuildBackArrow:SetHandler("OnMouseExit", function(self)
	ClearTooltip(InformationTooltip)
end)
GTASelectedGuildBackArrow:SetHandler("OnMouseUp", function(self, button, upInside)
	if button == 1 and upInside then
		PlaySound("Click")
		EVENT_MANAGER:UnregisterForEvent("GTA", EVENT_GUILD_MEMBER_ADDED)
		EVENT_MANAGER:UnregisterForEvent("GTA", EVENT_GUILD_MEMBER_REMOVED)
		EVENT_MANAGER:UnregisterForEvent("GTA", EVENT_GUILD_MEMBER_RANK_CHANGED)
		EVENT_MANAGER:UnregisterForEvent("GTA", EVENT_GUILD_MEMBER_NOTE_CHANGED)
		GTASelectedGuildView:SetHidden(true)
		GTAPersonalView:SetHidden(false)
	end
end)
local GTASelectedGuildInvite = WINDOW_MANAGER:CreateControl("GTASelectedGuildInvite", GTASelectedGuildView, CT_BUTTON)
GTASelectedGuildInvite:SetAnchor(TOPRIGHT, nil, TOPLEFT, -10, 30)
GTASelectedGuildInvite:SetDimensions(32, 32)
GTASelectedGuildInvite:SetNormalTexture("/esoui/art/miscellaneous/spinnerplus_up.dds")
GTASelectedGuildInvite:SetPressedTexture("/esoui/art/miscellaneous/spinnerplus_down.dds")
GTASelectedGuildInvite:SetMouseOverTexture("/esoui/art/miscellaneous/spinnerplus_over.dds")
--/esoui/art/miscellaneous/spinnerplus_disabled.dds
GTASelectedGuildInvite:SetMouseEnabled(true)
GTASelectedGuildInvite:SetHandler("OnMouseEnter", function(self)
	InitializeTooltip(InformationTooltip, self, BOTTOM, 0, 0)
	SetTooltipText(InformationTooltip, "INVITE TO GUILD")
end)
GTASelectedGuildInvite:SetHandler("OnMouseExit", function(self)
	ClearTooltip(InformationTooltip)
end)
GTASelectedGuildInvite:SetHandler("OnMouseUp", function(self, button, upInside)
	if button == 1 and upInside then
		PlaySound("Click")
		if DoesPlayerHaveGuildPermission(SELECTED_GUILD_ID, GUILD_PERMISSION_INVITE) then
			ZO_Dialogs_ShowDialog("GTA_GUILD_INVITE")
		end
	end
end)
--SelectedGuildScrollListControls
local SORTABLE = true
local NOT_SORTABLE = false
local WITH_HEADERS = true
local Label = LibScrollList.Label
local combine = LibScrollList.combine
local Column = LibScrollList.Column
local ScrollList = LibScrollList.Table
local Button = LibScrollList.Button

local alignRight= {
	SetHorizontalAlignment = {TEXT_ALIGN_RIGHT}
}
local alignLeft= {
	SetHorizontalAlignment = {TEXT_ALIGN_LEFT}
}
local alignCenter= {
	SetHorizontalAlignment = {TEXT_ALIGN_CENTER}
}

local function showRankTooltip(control)
	local rankIndex = control:GetParent().dataEntry.data[1]
	local rankName = GetFinalGuildRankName(SELECTED_GUILD_ID, rankIndex)
	ZO_Tooltips_ShowTextTooltip(control, LEFT, rankName)
end

local function hideRankTooltip()
	ZO_Tooltips_HideTextTooltip()
end

local function SaveNote(displayName, note)
	for memberIndex = 1, GetNumGuildMembers(SELECTED_GUILD_ID) do
		local memberName, memberNote, rankIndex, playerStatus, secsSinceLogoff = GetGuildMemberInfo(SELECTED_GUILD_ID, memberIndex)
		if memberName == displayName then
			local editControl = ZO_EditNoteDialogNoteEdit
			if editControl then
				local newNoteText = editControl:GetText()
				SetGuildMemberNote(SELECTED_GUILD_ID, memberIndex, string.format(newNoteText))
				ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", (memberName .. " guild note updated."))
			end
			
		end
	end
end

local function ShowEditNoteDialog(name, curNote)
	local dialogParams = {
		displayName = name,
		note = curNote,
		changedCallback = function(...) SaveNote(...) end
	}
	ZO_Dialogs_ShowDialog('EDIT_NOTE', dialogParams)
end

local defaultStyle = {
	SetFont = {'ZoFontBookPaper'},
	SetColor = {0.1, 0.1, 0.1, 0.9},
	SetMaxLineCount = {1},
}
local headerStyle = combine(defaultStyle, {
	SetFont = {'ZoFontGameMedium'},
	SetColor = {0.3, 0.3, 0.2, 0.9},
	SetModifyTextType = {MODIFY_TEXT_TYPE_UPPERCASE},
	{'SetHandler', 'OnMouseEnter', function(ctrl) ctrl:SetColor(0.3, 0.3, 0.2, 0.9)
		InitializeTooltip(InformationTooltip, ctrl, BOTTOM, 0, 0)
		SetTooltipText(InformationTooltip, "SORT")
	end},
	{'SetHandler', 'OnMouseExit', function(ctrl) ctrl:SetColor(0.3, 0.3, 0.2, 0.9)
		ClearTooltip(InformationTooltip)
	end},
	{'SetHandler', 'OnMouseUp', function(self, button, upInside)
		if button == 1 and upInside then
			PlaySound("Click")
		end
	end},
})
local noteCellStyle = {
	SetDimensions = {20, 20},
	SetTextureCoords = {0.10, 0.90, 0.10, 0.90},
	SetDrawTier = {DT_MEDIUM},
	SetMouseOverBlendMode = {TEX_BLEND_MODE_ADD},
	SetNormalTexture = {'/esoui/art/contacts/social_note_up.dds'},
	SetPressedTexture = {'/esoui/art/contacts/social_note_down.dds'},
	SetMouseOverTexture = {'/esoui/art/contacts/social_note_over.dds'},
}
local showRankTooltipStyle = {
	SetMouseEnabled = {true},
	SetDrawLevel = {100},
	{'SetHandler', 'OnMouseEnter', showRankTooltip},
	{'SetHandler', 'OnMouseExit', hideRankTooltip},
}
local salesStyle = combine(defaultStyle, alignRight)
local guildStyle = combine(defaultStyle, alignLeft)

ZO_Dialogs_RegisterCustomDialog("GTAPromoteToLeader", {
	title = {text = "Promote to Guild Leader",},
	mainText = {text = "Do you wish to continue?",},
	buttons = {
		{
			text = SI_DIALOG_ACCEPT,
			callback = function(displayName)
				GuildPromote(SELECTED_GUILD_ID, SELECTED_USER_DISPLAY_NAME)
				--ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", (displayName .. " has been promoted to leader."))
			end,
		},
		{
			text = SI_DIALOG_DECLINE,
			callback = function()
			end,
		}
	}
})
ZO_Dialogs_RegisterCustomDialog("GTARemoveFromGuild", {
	title = {text = "Remove from Guild",},
	mainText = {text = "Do you wish to continue?",},
	buttons = {
		{
			text = SI_DIALOG_ACCEPT,
			callback = function(displayName)
				GuildRemove(SELECTED_GUILD_ID, SELECTED_USER_DISPLAY_NAME)
				ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", (SELECTED_USER_DISPLAY_NAME .. " removed from " .. GetGuildName(SELECTED_GUILD_ID) .. "."))
			end,
		},
		{
			text = SI_DIALOG_DECLINE,
			callback = function()
			end,
		}
	}
})
--title = {
	--text = function(dialog)
		--return "Invite to " .. GetGuildName(SELECTED_GUILD_ID)
	--end,
--},
ZO_Dialogs_RegisterCustomDialog("GTA_GUILD_INVITE", {
	title = {text = "Invite to Guild",},
	mainText = {text = "Enter character name or @UserID.",},
	editBox = {
		defaultText = "ex. Michael Cullen or @sinnereso",
		selectAll = true,
	},
	buttons = {
		[1] = {
			text = SI_DIALOG_CONFIRM,
			callback = function(dialog)
				local targetName = ZO_Dialogs_GetEditBoxText(dialog)
				if targetName and targetName ~= "" and targetName ~= GetUnitDisplayName("player") then--GUILD_SELECTOR.guildId
					if DoesPlayerHaveGuildPermission(SELECTED_GUILD_ID, GUILD_PERMISSION_INVITE) then
						GuildInvite(SELECTED_GUILD_ID, targetName)
						--ZO_Alert(UI_ALERT_CATEGORY_ALERT, "PlayerAction_NotEnoughMoney", (targetName .. " invited to " .. GetGuildName(SELECTED_GUILD_ID) .. "."))
					end
				end
			end,
		},
		[2] = {
			text = SI_DIALOG_CANCEL,
			callback = function()
			end,
		},
	},
})

local function showIconForRankIndex(ctrl, value)
	if SELECTED_GUILD_ID then
		local iconIndex = GetGuildRankIconIndex(SELECTED_GUILD_ID, value)
		ctrl:SetText("|t20:20:" .. GetGuildRankSmallIcon(iconIndex) .. "|t")
	end
end

local SalesCell = Label(salesStyle, function(ctrl, value) ctrl:SetText(ZO_LocalizeDecimalNumber(value)) end)
local SalesHeader = Label(combine(salesStyle, headerStyle))
local GuildCell = Label(guildStyle)
local GuildHeader = Label(combine(guildStyle, headerStyle))
local RankCell = Label(combine(combine(defaultStyle, alignCenter), showRankTooltipStyle), showIconForRankIndex)
local NoteCell = Button(noteCellStyle, function(ctrl, value)
	ctrl:SetHidden(value == '')
	if ctrl:GetHandler('OnMouseEnter') then return end
	ctrl:SetHandler('OnMouseEnter', function(bttn)
		local note = bttn:GetParent():GetParent().dataEntry.data[6]
		ZO_Tooltips_ShowTextTooltip(ctrl, RIGHT, note)
	end)
	ctrl:SetHandler('OnMouseExit', ZO_Tooltips_HideTextTooltip)
	ctrl:SetHandler("OnMouseUp", function(control, button, upInside)
		if button == 1 and upInside then
			PlaySound("Click")
			if DoesPlayerHaveGuildPermission(SELECTED_GUILD_ID, GUILD_PERMISSION_NOTE_EDIT) then
				ShowEditNoteDialog(control:GetParent():GetParent().dataEntry.data[2], control:GetParent():GetParent().dataEntry.data[6])
			end
		end
	end)
end)

local RightAlignedCell = Label(combine(defaultStyle, alignRight))
local RightAlignedHeader = Label(combine(combine(defaultStyle, alignRight), headerStyle))
local LeftAlignedCell = Label(combine(defaultStyle, alignLeft))
local LeftAlignedHeader = Label(combine(combine(defaultStyle, alignLeft), headerStyle))
local CenterAlignedCell = Label(combine(defaultStyle, alignCenter))
local CenterAlignedHeader = Label(combine(combine(defaultStyle, alignCenter), headerStyle))

local columnsForGuildList = {
	Column('Rank',       30,  0, 		RankCell, '|t20:20:/esoui/art/buttons/scrollbox_downarrow_up.dds|t',   		   CenterAlignedHeader,  	SORTABLE),
	Column('Name',      270,  0, LeftAlignedCell, 'NAME |t20:20:/esoui/art/buttons/scrollbox_downarrow_up.dds|t',	 	 LeftAlignedHeader,  	SORTABLE),
	Column('Sales',     140,  0,   	   SalesCell, '|t20:20:/esoui/art/buttons/scrollbox_downarrow_up.dds|t TRADED',			   SalesHeader, 	SORTABLE),
	Column('Purch',     140,  0,  	   SalesCell, '|t20:20:/esoui/art/buttons/scrollbox_downarrow_up.dds|t BOUGHT', 			   SalesHeader,  	SORTABLE),
	Column('Activity',  140,  0, 	   SalesCell, '|t20:20:/esoui/art/buttons/scrollbox_downarrow_up.dds|t ACTIVITY',      	   SalesHeader,  	SORTABLE),
	Column('Notes',      20, 10,        NoteCell, '|t20:20:/esoui/art/contacts/social_note_up.dds|t',                    CenterAlignedCell, NOT_SORTABLE),
}

local function sendMailCallback(scene, oldState, newState)
	if newState == SCENE_HIDDEN and (scene:GetName() == "mailSend" or scene:GetName() == "mailInbox") then
		SCENE_MANAGER:UnregisterCallback("SceneStateChanged", sendMailCallback)
		MAIL_SEND:ClearFields()
		GuildTraderActivity.Toggle(true)
	end
end

local function postGuildListCallback(ctrl)
	ctrl:SetHandler('OnMouseEnter', function(ctrl)
		SELECTED_USER_DISPLAY_NAME = ctrl.dataEntry.data[2]
		local userMemberIndex = GetGuildMemberIndexFromDisplayName(SELECTED_GUILD_ID, SELECTED_USER_DISPLAY_NAME)
		local name, _, _, playerStatus = GetGuildMemberInfo(SELECTED_GUILD_ID, userMemberIndex)
		if playerStatus ~= PLAYER_STATUS_OFFLINE then
			ZO_Tooltips_ShowTextTooltip(ctrl, LEFT, "(|c339933ONLINE|r) ~ VIEW PLAYER DETAILS")
		else
			ZO_Tooltips_ShowTextTooltip(ctrl, LEFT, "(|ce06666OFFLINE|r) ~ VIEW PLAYER DETAILS")
		end
	end)
	ctrl:SetHandler('OnMouseExit', ZO_Tooltips_HideTextTooltip)
	ctrl:SetHandler("OnMouseUp", function(ctrl, button, upInside)
		if button == 1 and upInside then
			PlaySound("Click")
			SELECTED_USER_DISPLAY_NAME = ctrl.dataEntry.data[2]
			zo_callLater(function()
				GuildTraderActivity.CreatePlayerList(SELECTED_GUILD_DATA, SELECTED_GUILD_IS_CURRENT)
				EVENT_MANAGER:UnregisterForEvent("GTA", EVENT_GUILD_MEMBER_ADDED)
				EVENT_MANAGER:UnregisterForEvent("GTA", EVENT_GUILD_MEMBER_REMOVED)
				EVENT_MANAGER:UnregisterForEvent("GTA", EVENT_GUILD_MEMBER_RANK_CHANGED)
				EVENT_MANAGER:UnregisterForEvent("GTA", EVENT_GUILD_MEMBER_NOTE_CHANGED)
			end, 50)
		elseif button == 2 and upInside then
			SELECTED_USER_DISPLAY_NAME = ctrl.dataEntry.data[2]
			local memberIndex = GetPlayerGuildMemberIndex(SELECTED_GUILD_ID)
			local _, _, myRankIndex = GetGuildMemberInfo(SELECTED_GUILD_ID, memberIndex)
			local userMemberIndex = GetGuildMemberIndexFromDisplayName(SELECTED_GUILD_ID, SELECTED_USER_DISPLAY_NAME)
			local _, _, _, playerStatus = GetGuildMemberInfo(SELECTED_GUILD_ID, userMemberIndex)
			local userRankIndex = ctrl.dataEntry.data[1]
			local userRankId = GetGuildRankId(SELECTED_GUILD_ID, userRankIndex)
			local userNote = ctrl.dataEntry.data[6]
			ClearMenu()
			if SELECTED_USER_DISPLAY_NAME ~= GetUnitDisplayName("player") and (playerStatus ~= PLAYER_STATUS_OFFLINE and playerStatus ~= PLAYER_STATUS_DO_NOT_DISTURB) then
				AddMenuItem("Whisper", function()
					PlaySound("Click")
					StartChatInput("", CHAT_CHANNEL_WHISPER, SELECTED_USER_DISPLAY_NAME)
				end)
			end
			if ZO_GuildRosterManager.CanPromotePlayer(SELECTED_GUILD_ID, myRankIndex, userRankIndex, userRankId) then
				AddMenuItem("Promote", function()
					PlaySound("Click")
					if IsGuildRankGuildMaster(SELECTED_GUILD_ID, myRankIndex) and myRankIndex == userRankIndex - 1 then
						ZO_Dialogs_ShowDialog("GTAPromoteToLeader", SELECTED_USER_DISPLAY_NAME)
					else
						GuildPromote(SELECTED_GUILD_ID, SELECTED_USER_DISPLAY_NAME)
					end
				end)
			end
			if ZO_GuildRosterManager.CanDemotePlayer(SELECTED_GUILD_ID, myRankIndex, userRankIndex, userRankId) then
				AddMenuItem("Demote", function()
					PlaySound("Click")
					GuildDemote(SELECTED_GUILD_ID, SELECTED_USER_DISPLAY_NAME)
				end)
			end
			if DoesPlayerHaveGuildPermission(SELECTED_GUILD_ID, GUILD_PERMISSION_REMOVE) and myRankIndex < userRankIndex then
				AddMenuItem("Kick", function()
					PlaySound("Click")
					ZO_Dialogs_ShowDialog("GTARemoveFromGuild", SELECTED_USER_DISPLAY_NAME)
				end)
			end
			if SELECTED_USER_DISPLAY_NAME ~= GetUnitDisplayName("player") then
				AddMenuItem("Send Mail", function()
					PlaySound("Click")
					SCENE_MANAGER:RegisterCallback("SceneStateChanged", sendMailCallback)
					MAIL_SEND:ComposeMailTo(SELECTED_USER_DISPLAY_NAME)
				end)
			end
			if DoesPlayerHaveGuildPermission(SELECTED_GUILD_ID, GUILD_PERMISSION_NOTE_EDIT) then
				AddMenuItem("Edit Note", function()
					PlaySound("Click")
					ShowEditNoteDialog(SELECTED_USER_DISPLAY_NAME, userNote)
				end)
			end
			ShowMenu(ctrl)
		end
	end)
end
--ZO_Dialogs_ShowDialog("GUILD_INVITE", { guildId = SELECTED_GUILD_ID })--target = playerName
local GTAGuildList = ScrollList(WITH_HEADERS)
GTAGuildList:AddDataType(1, columnsForGuildList, 20, postGuildListCallback)
GTAGuildList:SetDefaultSortingCriteria(5, ZO_SORT_ORDER_DOWN)
SELECTED_GUILD_LIST = GTAGuildList
local GTAGuildListControl = GTAGuildList:Create('GTAGuildList', GTASelectedGuildView)
GTAGuildListControl:SetDimensions(140*3+350, 350)
GTAGuildListControl:SetAnchor(TOP, GTASelectedGuildLabel, BOTTOM, 0, -14)
--GTAGuildListControl:SetAnchorFill(GTASelectedGuildView)
---------------------------------------------
------- PLAYER DETAILS LIST VIEW CONTROLS --
---------------------------------------------
--local GTASelectedPlayerView = WINDOW_MANAGER:CreateTopLevelWindow("GTASelectedPlayerView")
local GTASelectedPlayerView = WINDOW_MANAGER:CreateControl("GTASelectedPlayerView", GTAMain, CT_CONTROL)
GTASelectedPlayerView:SetAnchor(CENTER, GTAMain, CENTER, -2, -10)
--GTASelectedPlayerView:SetParent(GTAMain)
GTASelectedPlayerView:SetDimensions(766, 374)
--GTASelectedPlayerLabel
local GTASelectedPlayerLabel = WINDOW_MANAGER:CreateControl("GTASelectedPlayerLabel", GTASelectedPlayerView, CT_LABEL)
GTASelectedPlayerLabel:SetAnchor(TOP, GTASelectedPlayerView, TOP, 0, -4)
GTASelectedPlayerLabel:SetFont(string.format("%s|%d", "$(HANDWRITTEN_FONT)", 26), FONT_STYLE_SOFT_SHADOW_THIN)
GTASelectedPlayerLabel:SetColor(0.1, 0.1, 0.1, 0.8)
GTASelectedPlayerLabel:SetText("")
--SelectedGuildBackArrow
local GTASelectedPlayerBackArrow = WINDOW_MANAGER:CreateControl("GTASelectedPlayerBackArrow", GTASelectedPlayerLabel, CT_BUTTON)
GTASelectedPlayerBackArrow:SetAnchor(RIGHT, nil, LEFT, -16)
GTASelectedPlayerBackArrow:SetDimensions(32, 32)
GTASelectedPlayerBackArrow:SetNormalTexture("/esoui/art/buttons/large_leftarrow_up.dds")
GTASelectedPlayerBackArrow:SetPressedTexture("/esoui/art/buttons/large_leftarrow_down.dds")
GTASelectedPlayerBackArrow:SetMouseOverTexture("/esoui/art/buttons/large_leftarrow_over.dds")
GTASelectedPlayerBackArrow:SetMouseEnabled(true)
GTASelectedPlayerBackArrow:SetHandler("OnMouseEnter", function(self)
	InitializeTooltip(InformationTooltip, self, BOTTOM, 0, 0)
	SetTooltipText(InformationTooltip, "BACK")
end)
GTASelectedPlayerBackArrow:SetHandler("OnMouseExit", function(self)
	ClearTooltip(InformationTooltip)
end)
GTASelectedPlayerBackArrow:SetHandler("OnMouseUp", function(self, button, upInside)
	if button == 1 and upInside then
		PlaySound("Click")
		EVENT_MANAGER:RegisterForEvent("GTA", EVENT_GUILD_MEMBER_ADDED, GuildTraderActivity.UpdateForGuildDataChange)
		EVENT_MANAGER:RegisterForEvent("GTA", EVENT_GUILD_MEMBER_REMOVED, GuildTraderActivity.UpdateForGuildDataChange)
		EVENT_MANAGER:RegisterForEvent("GTA", EVENT_GUILD_MEMBER_RANK_CHANGED, GuildTraderActivity.UpdateForGuildDataChange)
		EVENT_MANAGER:RegisterForEvent("GTA", EVENT_GUILD_MEMBER_NOTE_CHANGED, GuildTraderActivity.UpdateForGuildDataChange)
		GTASelectedPlayerView:SetHidden(true)
		GTASelectedGuildView:SetHidden(false)
	end
end)
local ItemCell = Label(salesStyle)
local ItemHeader = Label(combine(salesStyle, headerStyle))
-- total 750
local columnsForPlayerList = {
	Column('Item',      280,  0,	 LeftAlignedCell, 'ITEM LINK |t20:20:/esoui/art/buttons/scrollbox_downarrow_up.dds|t',	 	 LeftAlignedHeader,  	SORTABLE),
	Column('Buyer',     170,  10,	 LeftAlignedCell, 'BUYER |t20:20:/esoui/art/buttons/scrollbox_downarrow_up.dds|t',		 LeftAlignedHeader, 	SORTABLE),
	Column('Quant',      40,  0,  	   ItemCell, '|t20:20:/esoui/art/buttons/scrollbox_downarrow_up.dds|t #', 			 	ItemHeader,  	SORTABLE),
	Column('Price',  	110,  0, 	   ItemCell, '|t20:20:/esoui/art/buttons/scrollbox_downarrow_up.dds|t PRICE',      	   		ItemHeader,  	SORTABLE),
	Column('Time',     140,  0,        ItemCell, '|t20:20:/esoui/art/buttons/scrollbox_downarrow_up.dds|t SALE TIME',              ItemHeader,    	SORTABLE),
}
local function postPlayerListCallback(ctrl)
	ctrl:SetHandler('OnMouseEnter', function(ctrl)
		local itemName = zo_strformat("<<t:1>>", GetItemLinkName(ctrl.dataEntry.data[1]))
		ZO_Tooltips_ShowTextTooltip(ctrl, LEFT, itemName)
	end)
	ctrl:SetHandler('OnMouseExit', ZO_Tooltips_HideTextTooltip)
	ctrl:SetHandler("OnMouseUp", function(ctrl, button, upInside)
		if button == 1 and upInside then
			PlaySound("Click")
			ZO_PopupTooltip_SetLink(ctrl.dataEntry.data[1])
		elseif button == 2 and upInside then
			ClearMenu()
			AddMenuItem("Link in Chat", function()
				--PlaySound("Click")
				ZO_LinkHandler_InsertLink(ctrl.dataEntry.data[1])
			end)
			ShowMenu(ctrl)
		end
	end)
end
local GTAPlayerList = ScrollList(WITH_HEADERS)
GTAPlayerList:AddDataType(1, columnsForPlayerList, 20, postPlayerListCallback)
GTAPlayerList:SetDefaultSortingCriteria(5, ZO_SORT_ORDER_DOWN)
SELECTED_PLAYER_LIST = GTAPlayerList
local GTAPlayerListControl = GTAPlayerList:Create('GTAPlayerList', GTASelectedPlayerView)
GTAPlayerListControl:SetDimensions(140*3+350, 350)
GTAPlayerListControl:SetAnchor(TOP, GTASelectedPlayerLabel, BOTTOM, 0, -14)
--GTAPlayerListControl:SetAnchorFill(GTASelectedPlayerView)
---------------------------------------------
--------- ALL CONTROLS COMPLETE --
---------------------------------------------
--GTAMain:SetTopmost()
GTAMain:SetHidden(true)
GTAPersonalView:SetHidden(false)
GTASelectedGuildView:SetHidden(true)
GTASelectedPlayerView:SetHidden(true)
---------------------------------------------
--------- POPULATE VIEW FUNCTIONS --
---------------------------------------------
local function PopulateTraderActivity()
	local currentList = {}
	local previousList = {}
	local currentCounter = 0
	local guildTotal = 0
	local sales = 0
	local purchases = 0
	local allSales = 0
	local allPurchases = 0
	local allActivity = 0
	local previousCounter = 0
	local prevGuildTotal = 0
	local prevSales = 0
	local prevPurchases = 0
	local prevAllSales = 0
	local prevAllPurchases = 0
	local prevAllActivity = 0
	if GetNumGuilds() > 0 then
		local resetStamp, prevStamp = GetLastKioskReset()
		local nowStamp = GetTimeStamp()
		for i = 1, GetNumGuilds() do
			local guildId = GetGuildId(i)
			local guildName = GetGuildName(guildId)
			for x = 1, GetNumGuildHistoryEvents(guildId, CATEGORY) do
				local param1, eventStamp, param3, param4, sellerName, buyerName, itemLink, itemQuantity, itemPrice, itemTax = GetGuildHistoryTraderEventInfo(guildId, x)
				if eventStamp > resetStamp then
					guildTotal = (guildTotal + itemPrice)
					if DecorateDisplayName(buyerName) == GetUnitDisplayName("player") then purchases = (purchases + itemPrice) allPurchases = (allPurchases + itemPrice) allActivity = (allActivity + itemPrice) end
					if DecorateDisplayName(sellerName) == GetUnitDisplayName("player") then sales = (sales + itemPrice) allSales = (allSales + itemPrice) allActivity = (allActivity + itemPrice) end
				elseif eventStamp > prevStamp and eventStamp < resetStamp then
					prevGuildTotal = (prevGuildTotal + itemPrice)
					if DecorateDisplayName(buyerName) == GetUnitDisplayName("player") then prevPurchases = (prevPurchases + itemPrice) prevAllPurchases = (prevAllPurchases + itemPrice) prevAllActivity = (prevAllActivity + itemPrice) end
					if DecorateDisplayName(sellerName) == GetUnitDisplayName("player") then prevSales = (prevSales + itemPrice) prevAllSales = (prevAllSales + itemPrice) prevAllActivity = (prevAllActivity + itemPrice) end
				end
			end
			if guildTotal ~= 0 or GuildTraderActivity.savedVariables.showAll then
				local isComplete = IsGuildHistoryGaplessBetween(guildId, CATEGORY, resetStamp, nowStamp)
				if LibHistoire:IsCategoryLinked(guildId, CATEGORY) and isComplete then LINKED_INDICATOR = LINKED_IMAGE else LINKED_INDICATOR = UNLINKED_IMAGE end
				currentCounter = currentCounter + 1
				currentList[currentCounter] = {
					index = i,
					id = guildId,
					name = (LINKED_INDICATOR .. guildName),
					total = guildTotal,
					sales = sales,
					purchases = purchases,
					activity = sales + purchases,
				}
			end
			if prevGuildTotal ~= 0 or GuildTraderActivity.savedVariables.showAll then
				local isComplete = IsGuildHistoryGaplessBetween(guildId, CATEGORY, prevStamp, resetStamp)
				if isComplete then LINKED_INDICATOR = LINKED_IMAGE else LINKED_INDICATOR = UNLINKED_IMAGE end
				previousCounter = previousCounter + 1
				previousList[previousCounter] = {
					index = i,
					id = guildId,
					name = (LINKED_INDICATOR .. guildName),
					total = prevGuildTotal,
					sales = prevSales,
					purchases = prevPurchases,
					activity = prevSales + prevPurchases,
				}
			end
			guildTotal = 0
			sales = 0
			purchases = 0
			prevGuildTotal = 0
			prevSales = 0
			prevPurchases = 0
		end
		GTATotalCurrentSalesLabel:SetText("TOTAL   -->   " .. tostring(ZO_LocalizeDecimalNumber(allSales)))
		GTATotalCurrentPurchasesLabel:SetText(tostring(ZO_LocalizeDecimalNumber(allPurchases)))
		GTATotalCurrentActivityLabel:SetText(tostring(ZO_LocalizeDecimalNumber(allActivity)))
		GTATotalPreviousSalesLabel:SetText("TOTAL   -->   " .. tostring(ZO_LocalizeDecimalNumber(prevAllSales)))
		GTATotalPreviousPurchaseLabel:SetText(tostring(ZO_LocalizeDecimalNumber(prevAllPurchases)))
		GTATotalPreviousActivityLabel:SetText(tostring(ZO_LocalizeDecimalNumber(prevAllActivity)))
		GTADisclaimer:SetText(("Based on cached data after " .. string.lower(tostring(os.date("%I %p %a %b %d", prevStamp)))))
	else
		return
	end
	return currentList, previousList
end

function GuildTraderActivity.CreateGuildList(data, isCurrent)
	local resetStamp, prevStamp = GetLastKioskReset()
	local guildId = GetGuildId(data.index)
	local guildName = data.name
	SELECTED_GUILD_ID = guildId
	SELECTED_GUILD_DATA = data
	SELECTED_GUILD_IS_CURRENT = isCurrent
	GUILD_ROSTER_MANAGER:SetGuildId(SELECTED_GUILD_ID)
	local buyers = {}
	local sellers = {}
	local salesData = {}
	if isCurrent then
		for eventIndex = 1, GetNumGuildHistoryEvents(guildId, CATEGORY) do
			local param1, eventStamp, param3, param4, sellerName, buyerName, itemLink, itemQuantity, itemPrice, itemTax = GetGuildHistoryTraderEventInfo(guildId, eventIndex)
			if eventStamp > resetStamp then
				if not buyers[buyerName] then buyers[buyerName] = 0 end
				buyers[buyerName] = buyers[buyerName] + itemPrice
				if not sellers[sellerName] then sellers[sellerName] = 0 end
				sellers[sellerName] = sellers[sellerName] + itemPrice
			end
		end
	else
		for eventIndex = 1, GetNumGuildHistoryEvents(guildId, CATEGORY) do
			local param1, eventStamp, param3, param4, sellerName, buyerName, itemLink, itemQuantity, itemPrice, itemTax = GetGuildHistoryTraderEventInfo(guildId, eventIndex)
			if eventStamp > prevStamp and eventStamp < resetStamp then
				if not buyers[buyerName] then buyers[buyerName] = 0 end
				buyers[buyerName] = buyers[buyerName] + itemPrice
				if not sellers[sellerName] then sellers[sellerName] = 0 end
				sellers[sellerName] = sellers[sellerName] + itemPrice
			end
		end
	end
	for memberIndex = 1, GetNumGuildMembers(guildId) do
		local memberName, memberNote, rankIndex, rankName, memberStatus, lastLogoff = GetGuildMemberInfo(guildId, memberIndex)
		memberName = UndecorateDisplayName(memberName)
		local memberSales = sellers[memberName] or 0
		local memberPurchases = buyers[memberName] or 0
		salesData[#salesData+1] = {
			rankIndex,
			DecorateDisplayName(memberName),
			memberSales,
			memberPurchases,
			memberSales + memberPurchases,
			memberNote,
		}
	end
	if isCurrent then
		SELECTED_GUILD_LIST:Update(1, salesData)
		GTASelectedGuildLabel:SetText("~ " .. string.gsub(guildName, "|t.-|t", "") .. " (Current Week) ~")
		GTAPersonalView:SetHidden(true)
		GTASelectedGuildView:SetHidden(false)
		if DoesPlayerHaveGuildPermission(SELECTED_GUILD_ID, GUILD_PERMISSION_INVITE) then
			GTASelectedGuildInvite:SetHidden(false)
		else
			GTASelectedGuildInvite:SetHidden(true)
		end
	else
		SELECTED_GUILD_LIST:Update(1, salesData)
		GTASelectedGuildLabel:SetText("~ " .. string.gsub(guildName, "|t.-|t", "") .. " (Previous Week) ~")
		GTAPersonalView:SetHidden(true)
		GTASelectedGuildView:SetHidden(false)
		if DoesPlayerHaveGuildPermission(SELECTED_GUILD_ID, GUILD_PERMISSION_INVITE) then
			GTASelectedGuildInvite:SetHidden(false)
		else
			GTASelectedGuildInvite:SetHidden(true)
		end
	end
end

function GuildTraderActivity.CreatePlayerList(data, isCurrent)
	local resetStamp, prevStamp = GetLastKioskReset()
	local tweakedBuyer
	local salesData = {}
	if SELECTED_GUILD_IS_CURRENT then
		for eventIndex = 1, GetNumGuildHistoryEvents(SELECTED_GUILD_ID, CATEGORY) do
			local param1, eventStamp, param3, param4, sellerName, buyerName, itemLink, itemQuantity, itemPrice, itemTax = GetGuildHistoryTraderEventInfo(SELECTED_GUILD_ID, eventIndex)
			if eventStamp > resetStamp and (SELECTED_USER_DISPLAY_NAME == DecorateDisplayName(sellerName) or SELECTED_USER_DISPLAY_NAME == DecorateDisplayName(buyerName)) then
				if DecorateDisplayName(buyerName) == SELECTED_USER_DISPLAY_NAME then tweakedBuyer = "~ purchase ~" else tweakedBuyer = DecorateDisplayName(buyerName) end
				salesData[#salesData+1] = {
					itemLink,
					tweakedBuyer,
					itemQuantity,
					ZO_LocalizeDecimalNumber(itemPrice),
					tostring(os.date("%d %b %H:%M", eventStamp)),
				} 
			end
		end
		SELECTED_PLAYER_LIST:Update(1, salesData)
		GTASelectedPlayerLabel:SetText("~ " .. SELECTED_USER_DISPLAY_NAME .. " (Current Week) ~")
		GTASelectedGuildView:SetHidden(true)
		GTASelectedPlayerView:SetHidden(false)
	else
		for eventIndex = 1, GetNumGuildHistoryEvents(SELECTED_GUILD_ID, CATEGORY) do
			local param1, eventStamp, param3, param4, sellerName, buyerName, itemLink, itemQuantity, itemPrice, itemTax = GetGuildHistoryTraderEventInfo(SELECTED_GUILD_ID, eventIndex)
			if eventStamp > prevStamp and eventStamp < resetStamp and (SELECTED_USER_DISPLAY_NAME == DecorateDisplayName(sellerName) or SELECTED_USER_DISPLAY_NAME == DecorateDisplayName(buyerName)) then
				if DecorateDisplayName(buyerName) == SELECTED_USER_DISPLAY_NAME then tweakedBuyer = "~ purchase ~" else tweakedBuyer = DecorateDisplayName(buyerName) end
				salesData[#salesData+1] = {
					itemLink,
					tweakedBuyer,
					itemQuantity,
					ZO_LocalizeDecimalNumber(itemPrice),
					tostring(os.date("%d %b %H:%M", eventStamp)),
				}
			end
		end
		SELECTED_PLAYER_LIST:Update(1, salesData)
		GTASelectedPlayerLabel:SetText("~ " .. SELECTED_USER_DISPLAY_NAME .. " (Previous Week) ~")
		GTASelectedGuildView:SetHidden(true)
		GTASelectedPlayerView:SetHidden(false)
	end
end

local function UpdateTraderActivityList(ctrl, data, rowType)
	local dataCopy = ZO_DeepTableCopy(data)
	local dataList = ZO_ScrollList_GetDataList(ctrl)
	ZO_ScrollList_Clear(ctrl)
	for key, value in ipairs(dataCopy) do
		local entry = ZO_ScrollList_CreateDataEntry(rowType, value)
		table.insert(dataList, entry)
	end
	if GuildTraderActivity.savedVariables.activitySorting == "name" then
		table.sort(dataList, function(a,b) return a.data[GuildTraderActivity.savedVariables.activitySorting] < b.data[GuildTraderActivity.savedVariables.activitySorting] end)
	else
		table.sort(dataList, function(a,b) return a.data[GuildTraderActivity.savedVariables.activitySorting] > b.data[GuildTraderActivity.savedVariables.activitySorting] end)
	end
	ZO_ScrollList_Commit(ctrl)
end

function GuildTraderActivity.Refresh()
	local currentList, previousList = PopulateTraderActivity()
	UpdateTraderActivityList(GTANameList, currentList, 1)
	UpdateTraderActivityList(GTASalesList, currentList, 1)
	UpdateTraderActivityList(GTAPurchaseList, currentList, 1)
	UpdateTraderActivityList(GTAActivityList, currentList, 1)
	UpdateTraderActivityList(GTAPreviousNameList, previousList, 2)
	UpdateTraderActivityList(GTAPreviousSalesList, previousList, 2)
	UpdateTraderActivityList(GTAPreviousPurchaseList, previousList, 2)
	UpdateTraderActivityList(GTAPreviousActivityList, previousList, 2)
end

function GuildTraderActivity.UpdateForGuildDataChange()
	GuildTraderActivity.CreateGuildList(SELECTED_GUILD_DATA, SELECTED_GUILD_IS_CURRENT)
end

local function OnSceneStateChanged(oldState, newState)
	if newState == SCENE_SHOWN and not GTASelectedGuildView:IsHidden() then
        EVENT_MANAGER:RegisterForEvent("GTA", EVENT_GUILD_MEMBER_ADDED, GuildTraderActivity.UpdateForGuildDataChange)
		EVENT_MANAGER:RegisterForEvent("GTA", EVENT_GUILD_MEMBER_REMOVED, GuildTraderActivity.UpdateForGuildDataChange)
		EVENT_MANAGER:RegisterForEvent("GTA", EVENT_GUILD_MEMBER_RANK_CHANGED, GuildTraderActivity.UpdateForGuildDataChange)
		EVENT_MANAGER:RegisterForEvent("GTA", EVENT_GUILD_MEMBER_NOTE_CHANGED, GuildTraderActivity.UpdateForGuildDataChange)
	elseif newState == SCENE_HIDDEN then
        EVENT_MANAGER:UnregisterForEvent("GTA", EVENT_GUILD_MEMBER_ADDED)
		EVENT_MANAGER:UnregisterForEvent("GTA", EVENT_GUILD_MEMBER_REMOVED)
		EVENT_MANAGER:UnregisterForEvent("GTA", EVENT_GUILD_MEMBER_RANK_CHANGED)
		EVENT_MANAGER:UnregisterForEvent("GTA", EVENT_GUILD_MEMBER_NOTE_CHANGED)
	end
end

function GuildTraderActivity.Toggle(justReturn)
	if justReturn then
		SCENE_MANAGER:Show("GTA")
	elseif SCENE_MANAGER:IsShowing("GTA") then
		GuildTraderHistoryTrim()
		SCENE_MANAGER:Hide("GTA")
	else
		ZO_CheckButton_SetCheckState(GTAShowAllBox, GuildTraderActivity.savedVariables.showAll)
		ZO_CheckButton_SetCheckState(GTAShowAllBox, GuildTraderActivity.savedVariables.showAll)
		ZO_CheckButton_SetCheckState(GTACacheTrimBox, GuildTraderActivity.savedVariables.cacheTrim)
		GTASelectedPlayerView:SetHidden(true)
		GTASelectedGuildView:SetHidden(true)
		GTAPersonalView:SetHidden(false)
		GuildTraderActivity.Refresh()
		SCENE_MANAGER:Show("GTA")
	end
end
--SetFullscreenEffect(FULLSCREEN_EFFECT_CHARACTER_FRAMING_BLUR, 0.5, -0.5)
--SetFullscreenEffect(FULLSCREEN_EFFECT_NONE)
SLASH_COMMANDS["/gta"] = function (option)
	GuildTraderActivity.Toggle()
end

if GetUnitDisplayName("player") == GuildTraderActivity.author then
	SLASH_COMMANDS["/gtatrim"] = function (option)
		GuildTraderHistoryTrim(true)
	end
end

local function AddOnLoaded(eventCode, addOnName)
	if addOnName ~= "GTA" then return end
	ZO_CreateStringId("SI_BINDING_NAME_TRADER_ACTIVITY_TOGGLE", "Trader Activity Toggle")
	if LibHistoire and GetNumGuilds() > 0 then
		LibHistoire_Settings.markGapsInHistory = false
		--SetSetting(SETTING_TYPE_USER_INTERFACE, UI_SETTING_GUILD_HISTORY_CACHE_MAX_NUMBER_OF_DAYS_TRADER, "15")
		LibHistoire:OnReady(function(lib)
			local resetStamp, prevStamp = GetLastKioskReset()
			for i = 1, GetNumGuilds() do
				local guildId = GetGuildId(i)
				local processor = lib:CreateGuildHistoryProcessor(guildId, CATEGORY, "GTA")
				processor:SetAfterEventTime(prevStamp)
				--processor:SetBeforeEventTime(GetTimeStamp())
				processor:SetEventCallback(function(event) end)
				--processor:SetNextEventCallback(function(event) end)
				--processor:SetMissedEventCallback(function(event) end)
				processor:SetStopOnLastCachedEvent(false)
				processor:Start()
			end
		end)
	end
	local defaultAccountVars = {
		activitySorting = "name",
		lastReset = 0,
		showAll = false,
		cacheTrim = false,
	}
	GuildTraderActivity.savedVariables = ZO_SavedVars:NewAccountWide( GuildTraderActivity.svName, GuildTraderActivity.svVersion, nil, defaultAccountVars )
	--GuildTraderActivity.savedVariables.pvpLastReset = nil--<< SAVE
	GTA_SCENE:RegisterCallback("StateChange", OnSceneStateChanged)
	EVENT_MANAGER:UnregisterForEvent("GTA", EVENT_ADD_ON_LOADED)
end
EVENT_MANAGER:RegisterForEvent("GTA", EVENT_ADD_ON_LOADED, AddOnLoaded)