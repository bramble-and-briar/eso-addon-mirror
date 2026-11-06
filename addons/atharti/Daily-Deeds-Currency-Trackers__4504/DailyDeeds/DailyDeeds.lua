DailyDeeds = {}

local DD = DailyDeeds
local EM = EVENT_MANAGER

DD.name = "DailyDeeds"
DD.ui = {}

local defaultSV = {
	XP = {
		amountToday = 0,
		isHidden = false,
		disableEnlightenmentAtMaxCP = true,
	},
	Gold = {
		amountToday = 0,
		isHidden = false,
		trackNegatives = true,
	},
	AP = {
		amountToday = 0,
		isHidden = false,
		trackNegatives = true,
		showInAllZones = false,
	},
	Telvar = {
		amountToday = 0,
		isHidden = false,
		trackNegatives = true,
		showInAllZones = false,
	},
	TradeBars = {
		amountToday = 0,
		isHidden = false,
	},
	Fortunes = {
		amountToday = 0,
		isHidden = false,
		trackNegatives = true,
		showInAllZones = false,
	},
}

local ICONS = {
	XP = "/esoui/art/icons/icon_experience.dds",
	Gold = GetCurrencyKeyboardIcon(CURT_MONEY),
	AP = GetCurrencyKeyboardIcon(CURT_ALLIANCE_POINTS),
	Telvar = GetCurrencyKeyboardIcon(CURT_TELVAR_STONES),
	TradeBars = GetCurrencyKeyboardIcon(CURT_TRADE_BARS),
	Fortunes = GetCurrencyKeyboardIcon(CURT_ARCHIVAL_FORTUNES),
}

local TRACKER_COLORS = {
	XP = {1, 1, 1, 1},
	Gold = {1, 0.84, 0, 1},
	AP = {0.2196, 0.9333, 0.1961, 1},
	Telvar = {0.337, 0.596, 0.929, 1},
	TradeBars = {1, 0.84, 0, 1},
	Fortunes = {1, 1, 1, 1},
}

local BLACK = ZO_ColorDef:New(0, 0, 0, 1)

local AP_TARGET_ZONE_IDS = {
	643,
	584,
	181,
}

local TELVAR_TARGET_ZONE_IDS = {
	643,
	584,
}

local FORTUNES_TARGET_ZONE_IDS = {
	1436,
	1533,
}

local function FormatNumberWithCommas(number)
	local sign = ""
	if number < 0 then
		sign = "-"
		number = math.abs(number)
	end
	local formatted = tostring(number)
	local k = formatted:len() % 3
	if k == 0 then k = 3 end
	formatted = formatted:sub(1, k) .. formatted:sub(k+1):gsub("(%d%d%d)", ",%1")
	return sign .. formatted
end

local function GetCurrentZoneId()
	return GetZoneId(GetUnitZoneIndex("player"))
end

function DD.IsInAPZone()
	if IsActiveWorldBattleground() then
		return true
	end

	local currentZone = GetCurrentZoneId()
	for _, zoneId in ipairs(AP_TARGET_ZONE_IDS) do
		if zoneId == currentZone then
			return true
		end
	end
	return false
end

function DD.IsInTelvarZone()
	local currentZone = GetCurrentZoneId()
	for _, zoneId in ipairs(TELVAR_TARGET_ZONE_IDS) do
		if zoneId == currentZone then
			return true
		end
	end
	return false
end

function DD.IsInFortunesZone()
	local currentZone = GetCurrentZoneId()
	for _, zoneId in ipairs(FORTUNES_TARGET_ZONE_IDS) do
		if zoneId == currentZone then
			return true
		end
	end
	return false
end

-- UI
function DD.CreateTrackerWindow(trackerId, iconPath)
	local settings = DD.SV[trackerId]

	local window = WINDOW_MANAGER:CreateTopLevelWindow("DailyDeedsWindow_" .. trackerId)
	window:SetDimensions(40, 30)
	window:SetMouseEnabled(true)
	window:SetMovable(true)
	window:SetClampedToScreen(true)
	window:SetHidden(true)

	local x, y
	if settings.windowOffsetX and settings.windowOffsetY then
		x = zo_clamp(settings.windowOffsetX, 0, GuiRoot:GetWidth() - 60)
		y = zo_clamp(settings.windowOffsetY, 0, GuiRoot:GetHeight() - 24)
	else
		x = GuiRoot:GetWidth() / 2
		y = GuiRoot:GetHeight() / 2
		settings.windowOffsetX = x
		settings.windowOffsetY = y
	end

	window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)

	window:SetHandler("OnMoveStop", function(self)
		local nx = zo_clamp(self:GetLeft(), 0, GuiRoot:GetWidth() - 60)
		local ny = zo_clamp(self:GetTop(), 0, GuiRoot:GetHeight() - 24)
		settings.windowOffsetX = nx
		settings.windowOffsetY = ny
	end)

	local background = WINDOW_MANAGER:CreateControl("DailyDeedsBackground_" .. trackerId, window, CT_BACKDROP)
	background:SetAnchorFill()
	background:SetEdgeTexture("DailyDeeds/Textures/centerscreen_floating_edge.dds", 256, 256, 8)
	background:SetCenterTexture("DailyDeeds/Textures/centerscreen_floating_center.dds")
	background:SetInsets(8, 8, -8, -8)
	background:SetIntegralWrapping(true)
	background:SetAlpha(0.5)
	background:SetCenterColor(BLACK:UnpackRGBA())
	background:SetEdgeColor(BLACK:UnpackRGBA())

	local icon = WINDOW_MANAGER:CreateControl("DailyDeedsIcon_" .. trackerId, window, CT_TEXTURE)
	icon:SetDimensions(16, 16)
	icon:SetAnchor(LEFT, window, LEFT, 6, 0)
	icon:SetTexture(iconPath)

	local valueLabel = WINDOW_MANAGER:CreateControl("DailyDeedsCount_" .. trackerId, window, CT_LABEL)
	valueLabel:SetDimensions(80, 20)
	valueLabel:SetAnchor(LEFT, icon, RIGHT, 2, 0)
	valueLabel:SetFont("ZoFontWinH4")
	valueLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

	local fragment = ZO_HUDFadeSceneFragment:New(window)

	DD.ui[trackerId] = {
		window = window,
		fragment = fragment,
		valueLabel = valueLabel,
		icon = icon,
		background = background,
	}

	DD.UpdateDisplay(trackerId)
end

function DD.UpdateDisplay(trackerId)
	local ui = DD.ui[trackerId]
	local amountToday = DD.SV[trackerId].amountToday
	ui.valueLabel:SetText(FormatNumberWithCommas(amountToday))

	local digitCount = string.len(tostring(amountToday))
	local commaCount = math.max(0, math.floor((digitCount - 1) / 3))
	local effectiveCharacterCount = digitCount + (commaCount * 0.5)
	local extension = (effectiveCharacterCount - 1) * 8
	ui.window:SetWidth(40 + extension)
	ui.window:SetHeight(30)

	if trackerId == "Fortunes" and amountToday < 0 then
		ui.valueLabel:SetColor(1, 0.2, 0.2, 1)
	else
		ui.valueLabel:SetColor(unpack(TRACKER_COLORS[trackerId]))
	end
end

function DD.ResetTracker(trackerId)
	DD.SV[trackerId].amountToday = 0
	if trackerId == "XP" then
		DD.xpBase = GetUnitXP("player")
	end
	DD.UpdateDisplay(trackerId)
end

function DD.OnXPUpdate(_, unitTag, experienceGained)
	if unitTag ~= "player" then return end

	local settings = DD.SV.XP
	local currentXP = GetUnitXP("player")

	local difference = currentXP - DD.xpBase
	if difference > 0 then
		local enlightenedPool = GetEnlightenedPool()

		if settings.disableEnlightenmentAtMaxCP then
			if GetUnitChampionPoints("player") == 3600 then
				enlightenedPool = 0
			end
		end

		local xpToAdd
		if enlightenedPool > 0 then
			local boostedXP = math.min(difference, enlightenedPool)
			local normalXP = difference - boostedXP
			xpToAdd = normalXP + boostedXP * 4
		else
			xpToAdd = difference
		end

		settings.amountToday = settings.amountToday + xpToAdd
	end

	DD.xpBase = currentXP
	DD.UpdateDisplay("XP")
end

function DD.OnGoldUpdate(currencyType, currencyLocation, newAmount, oldAmount, reason)
	if currencyType ~= CURT_MONEY then return end
	if reason == CURRENCY_CHANGE_REASON_PLAYER_INIT then return end
	if reason == CURRENCY_CHANGE_REASON_BANK_DEPOSIT
	   or reason == CURRENCY_CHANGE_REASON_BANK_WITHDRAWAL
	   or reason == CURRENCY_CHANGE_REASON_GUILD_BANK_WITHDRAWAL then
		return
	end
	if currencyLocation ~= CURRENCY_LOCATION_CHARACTER
	   and currencyLocation ~= CURRENCY_LOCATION_ACCOUNT then
		return
	end

	local delta = newAmount - oldAmount
	if delta ~= 0 then
		local settings = DD.SV.Gold
		if settings.trackNegatives or delta > 0 then
			settings.amountToday = settings.amountToday + delta
			DD.UpdateDisplay("Gold")
		end
	end
end

function DD.OnAPUpdate(currencyType, currencyLocation, newAmount, oldAmount, reason)
	if currencyType ~= CURT_ALLIANCE_POINTS then return end

	if reason == CURRENCY_CHANGE_REASON_PLAYER_INIT then return end

	if reason == CURRENCY_CHANGE_REASON_BANK_DEPOSIT
	   or reason == CURRENCY_CHANGE_REASON_BANK_WITHDRAWAL then
		return
	end

	if currencyLocation ~= CURRENCY_LOCATION_CHARACTER
	   and currencyLocation ~= CURRENCY_LOCATION_ACCOUNT then
		return
	end

	local delta = newAmount - oldAmount
	if delta ~= 0 then
		local settings = DD.SV.AP
		if settings.trackNegatives or delta > 0 then
			settings.amountToday = settings.amountToday + delta
			DD.UpdateDisplay("AP")
		end
	end
end

function DD.OnTelvarUpdate(currencyType, currencyLocation, newAmount, oldAmount, reason)
	if currencyType ~= CURT_TELVAR_STONES then return end

	if reason == CURRENCY_CHANGE_REASON_PLAYER_INIT then return end

	if reason == CURRENCY_CHANGE_REASON_BANK_DEPOSIT
	   or reason == CURRENCY_CHANGE_REASON_BANK_WITHDRAWAL then
		return
	end

	if currencyLocation ~= CURRENCY_LOCATION_CHARACTER
	   and currencyLocation ~= CURRENCY_LOCATION_ACCOUNT then
		return
	end

	local delta = newAmount - oldAmount
	if delta ~= 0 then
		local settings = DD.SV.Telvar
		if settings.trackNegatives or delta > 0 then
			settings.amountToday = settings.amountToday + delta
			DD.UpdateDisplay("Telvar")
		end
	end
end

function DD.OnTradeBarsUpdate(currencyType, currencyLocation, newAmount, oldAmount, reason)
	if currencyType ~= CURT_TRADE_BARS then return end
	if currencyLocation ~= CURRENCY_LOCATION_ACCOUNT then return end
	if reason == CURRENCY_CHANGE_REASON_PLAYER_INIT then return end

	local delta = newAmount - oldAmount
	if delta > 0 then
		local settings = DD.SV.TradeBars
		settings.amountToday = settings.amountToday + delta
		DD.UpdateDisplay("TradeBars")
	end
end

function DD.OnFortunesUpdate(currencyType, currencyLocation, newAmount, oldAmount, reason)
	if currencyType ~= CURT_ARCHIVAL_FORTUNES then return end
	if currencyLocation ~= CURRENCY_LOCATION_ACCOUNT then return end
	if reason == CURRENCY_CHANGE_REASON_PLAYER_INIT then return end

	local delta = newAmount - oldAmount
	if delta ~= 0 then
		local settings = DD.SV.Fortunes
		if settings.trackNegatives or delta > 0 then
			settings.amountToday = settings.amountToday + delta
			DD.UpdateDisplay("Fortunes")
		end
	end
end

function DD.ApplyVisibility(id, isInZoneFn)
	local ui = DD.ui[id]
	local s = DD.SV[id]

	HUD_SCENE:RemoveFragment(ui.fragment)
	HUD_UI_SCENE:RemoveFragment(ui.fragment)

	local visible
	if isInZoneFn then
		visible = not s.isHidden and (s.showInAllZones or isInZoneFn())
	else
		visible = not s.isHidden
	end

	if visible then
		HUD_SCENE:AddFragment(ui.fragment)
		HUD_UI_SCENE:AddFragment(ui.fragment)
	end
end

function DD.RefreshVisibility()
	DD.ApplyVisibility("XP")
	DD.ApplyVisibility("Gold")
	DD.ApplyVisibility("TradeBars")
	DD.ApplyVisibility("AP", DD.IsInAPZone)
	DD.ApplyVisibility("Telvar", DD.IsInTelvarZone)
	DD.ApplyVisibility("Fortunes", DD.IsInFortunesZone)
end

function DD.OnAddOnLoaded(_, addonName)
	if addonName ~= DD.name then return end
	EM:UnregisterForEvent(DD.name, EVENT_ADD_ON_LOADED)

	DD.SV = ZO_SavedVars:NewAccountWide("DailyDeeds_SV", 2, nil, defaultSV)

	DD.xpBase = GetUnitXP("player")

	for id, iconPath in pairs(ICONS) do
		DD.CreateTrackerWindow(id, iconPath)
	end

	DD.RefreshVisibility()

	DD.RegisterLAMPanel()

	EM:RegisterForEvent(DD.name, EVENT_EXPERIENCE_UPDATE, DD.OnXPUpdate)

	EM:RegisterForEvent(DD.name, EVENT_CURRENCY_UPDATE, function(_, currencyType, currencyLocation, newAmount, oldAmount, reason)
		DD.OnGoldUpdate(currencyType, currencyLocation, newAmount, oldAmount, reason)
		DD.OnAPUpdate(currencyType, currencyLocation, newAmount, oldAmount, reason)
		DD.OnTelvarUpdate(currencyType, currencyLocation, newAmount, oldAmount, reason)
		DD.OnTradeBarsUpdate(currencyType, currencyLocation, newAmount, oldAmount, reason)
		DD.OnFortunesUpdate(currencyType, currencyLocation, newAmount, oldAmount, reason)
	end)

	EM:RegisterForEvent(DD.name, EVENT_PLAYER_ACTIVATED, DD.RefreshVisibility)

	LibDailyReset.RegisterCallback("OnDailyReset", function()
		for _, id in ipairs({ "XP", "Gold", "AP", "Telvar", "TradeBars", "Fortunes" }) do
			DD.ResetTracker(id)
		end
	end)
end

EM:RegisterForEvent(DD.name, EVENT_ADD_ON_LOADED, DD.OnAddOnLoaded)