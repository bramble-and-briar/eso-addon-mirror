DailyDeeds = {}
local DD = DailyDeeds

local ADDON_NAME = "DailyDeeds"

local defaultSavedVariables = {
	trackers = {}
}

DD.Settings = {}
DD.ui = {}

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

local function clamp(val, min, max)
	return math.max(min, math.min(max, val))
end

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

function DD.GetSettings(trackerId)
	if not DD.Settings.trackers[trackerId] then
		local settings = {
			amountToday = 0,
			lastKnownAmount = nil,
			windowOffsetX = nil,
			windowOffsetY = nil,
			isHidden = false,
		}

		if trackerId == "XP" then
			settings.disableEnlightenmentAtMaxCP = true
		end

		if trackerId == "Gold" or trackerId == "AP" or trackerId == "Telvar" or trackerId == "Fortunes" then
			settings.trackNegatives = true
		end

		if trackerId == "AP" or trackerId == "Telvar" or trackerId == "Fortunes" then
			settings.showInAllZones = false
		end

		DD.Settings.trackers[trackerId] = settings
	end
	return DD.Settings.trackers[trackerId]
end

-- UI
function DD.CreateTrackerWindow(trackerId, iconPath)
	local settings = DD.GetSettings(trackerId)

	local window = WINDOW_MANAGER:CreateTopLevelWindow("DailyDeedsWindow_" .. trackerId)
	local baseWidth = 40
	window:SetDimensions(baseWidth, 30)
	window:SetMouseEnabled(true)
	window:SetMovable(true)
	window:SetClampedToScreen(true)

	window:SetHidden(false)
	window:ClearAnchors()

	if settings.windowOffsetX and settings.windowOffsetY then
		local x = clamp(tonumber(settings.windowOffsetX), 0, GuiRoot:GetWidth() - 60)
		local y = clamp(tonumber(settings.windowOffsetY), 0, GuiRoot:GetHeight() - 24)
		window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
	else
		local screenWidth = GuiRoot:GetWidth()
		local screenHeight = GuiRoot:GetHeight()
		local windowWidth = window:GetWidth()
		local windowHeight = window:GetHeight()
		local centerX = (screenWidth - windowWidth) / 2
		local centerY = (screenHeight - windowHeight) / 2
		window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
		settings.windowOffsetX = centerX
		settings.windowOffsetY = centerY
	end

	window:SetHandler("OnMoveStop", function(self)
		local x = clamp(self:GetLeft(), 0, GuiRoot:GetWidth() - 60)
		local y = clamp(self:GetTop(), 0, GuiRoot:GetHeight() - 24)
		settings.windowOffsetX = x
		settings.windowOffsetY = y
	end)

	local background = WINDOW_MANAGER:CreateControl("DailyDeedsBackground_" .. trackerId, window, CT_BACKDROP)
	background:SetAnchorFill()
	background:SetEdgeTexture("DailyDeeds/Textures/centerscreen_floating_edge.dds", 256, 256, 8)
	background:SetCenterTexture("DailyDeeds/Textures/centerscreen_floating_center.dds")
	background:SetInsets(8, 8, -8, -8)
	background:SetIntegralWrapping(true)
	background:SetAlpha(0.5)
	local blackColor = ZO_ColorDef:New(0, 0, 0, 1)
	background:SetCenterColor(blackColor:UnpackRGBA())
	background:SetEdgeColor(blackColor:UnpackRGBA())

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
	HUD_SCENE:AddFragment(fragment)
	HUD_UI_SCENE:AddFragment(fragment)

	local originalShow = fragment.Show
	function fragment:Show(force)
		if not force and settings.isHidden then
			return
		end
		if trackerId == "AP" and not force then
			local apSettings = DD.GetSettings("AP")
			if not apSettings.showInAllZones and not DD.IsInAPZone() then
				return
			end
		end
		if trackerId == "Telvar" and not force then
			local telvarSettings = DD.GetSettings("Telvar")
			if not telvarSettings.showInAllZones and not DD.IsInTelvarZone() then
				return
			end
		end
		if trackerId == "Fortunes" and not force then
			local fortunesSettings = DD.GetSettings("Fortunes")
			if not fortunesSettings.showInAllZones and not DD.IsInFortunesZone() then
				return
			end
		end
		originalShow(self)
	end

	DD.ui[trackerId] = {
		window = window,
		fragment = fragment,
		valueLabel = valueLabel,
		icon = icon,
		background = background
	}
end

function DD.UpdateDisplay(trackerId)
	local ui = DD.ui[trackerId]
	if not ui then return end

	local settings = DD.GetSettings(trackerId)
	local amountToday = settings.amountToday or 0
	local text = FormatNumberWithCommas(amountToday)
	ui.valueLabel:SetText(text)

	local digitCount = string.len(tostring(amountToday))
	local commaCount = math.max(0, math.floor((digitCount - 1) / 3))
	local effectiveCharacterCount = digitCount + (commaCount * 0.5)
	local baseWidth = 40
	local extension = (effectiveCharacterCount - 1) * 8
	ui.window:SetWidth(baseWidth + extension)
	ui.window:SetHeight(30)

	if trackerId == "Fortunes" and amountToday < 0 then
		ui.valueLabel:SetColor(1, 0.2, 0.2, 1)
	else
		local colors = {
			XP = {1, 1, 1, 1},
			Gold = {1, 0.84, 0, 1},
			AP = {0.2196, 0.9333, 0.1961, 1},
			Telvar = {0.337, 0.596, 0.929, 1},
			TradeBars = {1, 0.84, 0, 1},
			Fortunes = {1, 1, 1, 1},
		}
		local color = colors[trackerId] or {1, 1, 1, 1}
		ui.valueLabel:SetColor(unpack(color))
	end
end

function DD.ResetTracker(trackerId)
	local settings = DD.GetSettings(trackerId)
	settings.amountToday = 0
	if trackerId == "XP" then
		settings.lastKnownAmount = GetUnitXP("player")
	elseif trackerId == "Gold" then
		settings.lastKnownAmount = GetCurrencyAmount(CURT_MONEY)
	elseif trackerId == "AP" then
		settings.lastKnownAmount = GetCurrencyAmount(CURT_ALLIANCE_POINTS)
	elseif trackerId == "Telvar" then
		settings.lastKnownAmount = GetCurrencyAmount(CURT_TELVAR_STONES)
	elseif trackerId == "TradeBars" then
		settings.lastKnownAmount = GetCurrencyAmount(CURT_TRADE_BARS, CURRENCY_LOCATION_ACCOUNT)
	elseif trackerId == "Fortunes" then
		settings.lastKnownAmount = GetCurrencyAmount(CURT_ARCHIVAL_FORTUNES, CURRENCY_LOCATION_ACCOUNT)
	end
	DD.UpdateDisplay(trackerId)
end

function DD.OnXPUpdate(eventCode, unitTag, experienceGained)
	if unitTag ~= "player" then return end

	local settings = DD.GetSettings("XP")
	local currentXP = GetUnitXP("player")

	if not settings.lastKnownAmount then
		settings.lastKnownAmount = currentXP
		return
	end

	local difference = currentXP - settings.lastKnownAmount
	if difference > 0 then
		local enlightenedPool = GetEnlightenedPool() or 0

		local disableAtMaxCP = settings.disableEnlightenmentAtMaxCP ~= false
		if disableAtMaxCP then
			local cp = GetUnitChampionPoints("player")
			if cp == 3600 then
				enlightenedPool = 0
			end
		end

		local xpToAdd = 0
		if enlightenedPool > 0 then
			local boostedXP = math.min(difference, enlightenedPool)
			local normalXP = difference - boostedXP
			xpToAdd = normalXP + boostedXP * 4
		else
			xpToAdd = difference
		end

		settings.amountToday = settings.amountToday + xpToAdd
	end

	settings.lastKnownAmount = currentXP
	DD.UpdateDisplay("XP")
end

function DD.OnGoldUpdate(eventCode, currencyType, currencyLocation, newAmount, oldAmount, reason)
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
		local settings = DD.GetSettings("Gold")
		local trackNegatives = settings.trackNegatives ~= false
		if trackNegatives or delta > 0 then
			settings.amountToday = (settings.amountToday or 0) + delta
			DD.UpdateDisplay("Gold")
		end
	end
end

function DD.OnAPUpdate(eventCode, currencyType, currencyLocation, newAmount, oldAmount, reason)
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
		local settings = DD.GetSettings("AP")
		local trackNegatives = settings.trackNegatives ~= false
		if trackNegatives or delta > 0 then
			settings.amountToday = (settings.amountToday or 0) + delta
			DD.UpdateDisplay("AP")
		end
	end
end

function DD.OnTelvarUpdate(eventCode, currencyType, currencyLocation, newAmount, oldAmount, reason)
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
		local settings = DD.GetSettings("Telvar")
		local trackNegatives = settings.trackNegatives ~= false
		if trackNegatives or delta > 0 then
			settings.amountToday = (settings.amountToday or 0) + delta
			DD.UpdateDisplay("Telvar")
		end
	end
end

function DD.OnTradeBarsUpdate(eventCode, currencyType, currencyLocation, newAmount, oldAmount, reason)
	if currencyType ~= CURT_TRADE_BARS then return end
	if currencyLocation ~= CURRENCY_LOCATION_ACCOUNT then return end

	if reason == CURRENCY_CHANGE_REASON_PLAYER_INIT then return end

	local settings = DD.GetSettings("TradeBars")

	if not settings.lastKnownAmount then
		settings.lastKnownAmount = newAmount
		return
	end

	local difference = newAmount - settings.lastKnownAmount
	if difference > 0 then
		settings.amountToday = (settings.amountToday or 0) + difference
		DD.UpdateDisplay("TradeBars")
	end

	settings.lastKnownAmount = newAmount
end

function DD.OnFortunesUpdate(eventCode, currencyType, currencyLocation, newAmount, oldAmount, reason)
	if currencyType ~= CURT_ARCHIVAL_FORTUNES then return end
	if currencyLocation ~= CURRENCY_LOCATION_ACCOUNT then return end

	if reason == CURRENCY_CHANGE_REASON_PLAYER_INIT then return end

	local settings = DD.GetSettings("Fortunes")

	if not settings.lastKnownAmount then
		settings.lastKnownAmount = newAmount
		return
	end

	local delta = newAmount - settings.lastKnownAmount
	if delta ~= 0 then
		local trackNegatives = settings.trackNegatives ~= false
		if trackNegatives or delta > 0 then
			settings.amountToday = (settings.amountToday or 0) + delta
			DD.UpdateDisplay("Fortunes")
		end
	end

	settings.lastKnownAmount = newAmount
end

function DD.OnAddOnLoaded(event, addonName)
	if addonName ~= ADDON_NAME then return end

	EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

	DD.RegisterLAMPanel()

	DD.Settings = ZO_SavedVars:NewAccountWide("DailyDeeds_SV", 1, nil, defaultSavedVariables)

	-- Get all settings first
	local xpSettings = DD.GetSettings("XP")
	local goldSettings = DD.GetSettings("Gold")
	local apSettings = DD.GetSettings("AP")
	local telvarSettings = DD.GetSettings("Telvar")
	local tradeBarsSettings = DD.GetSettings("TradeBars")
	local fortunesSettings = DD.GetSettings("Fortunes")

	if not xpSettings.isHidden then
		DD.CreateTrackerWindow("XP", "/esoui/art/icons/icon_experience.dds")
		xpSettings.lastKnownAmount = GetUnitXP("player")
		xpSettings.amountToday = xpSettings.amountToday or 0
		DD.UpdateDisplay("XP")
	end

	if not goldSettings.isHidden then
		DD.CreateTrackerWindow("Gold", "/esoui/art/currency/currency_gold.dds")
		goldSettings.lastKnownAmount = GetCurrencyAmount(CURT_MONEY)
		goldSettings.amountToday = goldSettings.amountToday or 0
		DD.UpdateDisplay("Gold")
	end

	if not apSettings.isHidden then
		DD.CreateTrackerWindow("AP", GetCurrencyKeyboardIcon(CURT_ALLIANCE_POINTS))
		apSettings.lastKnownAmount = GetCurrencyAmount(CURT_ALLIANCE_POINTS)
		apSettings.amountToday = apSettings.amountToday or 0
		DD.UpdateDisplay("AP")
	end

	if not telvarSettings.isHidden then
		DD.CreateTrackerWindow("Telvar", GetCurrencyKeyboardIcon(CURT_TELVAR_STONES))
		telvarSettings.lastKnownAmount = GetCurrencyAmount(CURT_TELVAR_STONES)
		telvarSettings.amountToday = telvarSettings.amountToday or 0
		DD.UpdateDisplay("Telvar")
	end

	if not tradeBarsSettings.isHidden then
		DD.CreateTrackerWindow("TradeBars", GetCurrencyKeyboardIcon(CURT_TRADE_BARS))
		tradeBarsSettings.lastKnownAmount = GetCurrencyAmount(CURT_TRADE_BARS, CURRENCY_LOCATION_ACCOUNT)
		tradeBarsSettings.amountToday = tradeBarsSettings.amountToday or 0
		DD.UpdateDisplay("TradeBars")
	end

	if not fortunesSettings.isHidden then
		DD.CreateTrackerWindow("Fortunes", GetCurrencyKeyboardIcon(CURT_ARCHIVAL_FORTUNES))
		fortunesSettings.lastKnownAmount = GetCurrencyAmount(CURT_ARCHIVAL_FORTUNES, CURRENCY_LOCATION_ACCOUNT)
		fortunesSettings.amountToday = fortunesSettings.amountToday or 0
		DD.UpdateDisplay("Fortunes")
	end

	if not xpSettings.isHidden then
		EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_EXPERIENCE_UPDATE, DD.OnXPUpdate)
	end

	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CURRENCY_UPDATE, function(eventCode, currencyType, currencyLocation, newAmount, oldAmount, reason)
		if not goldSettings.isHidden then
			DD.OnGoldUpdate(eventCode, currencyType, currencyLocation, newAmount, oldAmount, reason)
		end
		if not apSettings.isHidden then
			DD.OnAPUpdate(eventCode, currencyType, currencyLocation, newAmount, oldAmount, reason)
		end
		if not telvarSettings.isHidden then
			DD.OnTelvarUpdate(eventCode, currencyType, currencyLocation, newAmount, oldAmount, reason)
		end
		if not tradeBarsSettings.isHidden then
			DD.OnTradeBarsUpdate(eventCode, currencyType, currencyLocation, newAmount, oldAmount, reason)
		end
		if not fortunesSettings.isHidden then
			DD.OnFortunesUpdate(eventCode, currencyType, currencyLocation, newAmount, oldAmount, reason)
		end
	end)

	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, function()
		if not apSettings.isHidden then
			local apUI = DD.ui["AP"]
			if apUI then
				if (apSettings.showInAllZones or DD.IsInAPZone()) then
					apUI.fragment:Show()
				else
					apUI.fragment:Hide()
				end
			end
		end

		if not telvarSettings.isHidden then
			local telvarUI = DD.ui["Telvar"]
			if telvarUI then
				if (telvarSettings.showInAllZones or DD.IsInTelvarZone()) then
					telvarUI.fragment:Show()
				else
					telvarUI.fragment:Hide()
				end
			end
		end

		if not fortunesSettings.isHidden then
			local fortunesUI = DD.ui["Fortunes"]
			if fortunesUI then
				if (fortunesSettings.showInAllZones or DD.IsInFortunesZone()) then
					fortunesUI.fragment:Show()
				else
					fortunesUI.fragment:Hide()
				end
			end
		end
	end)

	LibDailyReset.RegisterCallback("OnDailyReset", function()
		DD.ResetTracker("XP")
		DD.ResetTracker("Gold")
		DD.ResetTracker("AP")
		DD.ResetTracker("Telvar")
		DD.ResetTracker("TradeBars")
		DD.ResetTracker("Fortunes")
	end)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, DD.OnAddOnLoaded)