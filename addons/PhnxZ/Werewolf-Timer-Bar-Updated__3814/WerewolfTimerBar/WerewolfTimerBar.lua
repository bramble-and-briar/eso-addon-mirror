-------------------------------------------------------------------------------------------------
--  Initialize Variables --
-------------------------------------------------------------------------------------------------
WerewolfTimerBar = {}
local WWTB = WerewolfTimerBar
WWTB.Name = "WerewolfTimerBar"
WWTB.Version = 4.07
WWTB.Default = 
	{
		BarOffsetX = 0,
		BarOffsetY = 0,
		BarColor = {0, 1, 0, 0.6},
		BarWidth = 300,
		BarHeight = 20,
		BuffBarWidth = 300,
		BuffBarHeight = 20,
		WelcomeSeenMajor = 0,
		IconsOnly = false,
		IconSize = 48,
		IconBorder = true,
		IconBorderThickness = 3,
		IconLayout = "Horizontal",
		BuffIconsOnly = false,
		BuffIconSize = 48,
		BuffIconBorder = true,
		BuffIconBorderThickness = 3,
		BuffIconLayout = "Horizontal",
		BuffsAlwaysShow = false,
		BuffsShowInCombat = false,
		BarFontName = "BOLD_FONT",
		BarFontStyle = "outline",
		BarFontSize = 16,
		BuffFontName = "BOLD_FONT",
		BuffFontStyle = "outline",
		BuffFontSize = 16,
		RoarFontName = "BOLD_FONT",
		RoarFontStyle = "outline",
		RoarFontSize = 16,
		ShowTimer = true,
		ShowFury = true,
		FuryBarColor = {0, 0, 1, 0.85},
		FuryBarMaxColor = {1, 0, 0, 1},
		WarningColor = true,
		WarningLevel = 300,
		WarningBarColor = {1, 0.5, 0, 1},
		CriticalLevel = 150,
		CriticalBarColor = {1, 0, 0, 1},
		HideCSA = true,
		UltimateEnable = true,
		BlockInCombatOnly = true,
		HoldBypassEnabled = true,
		HoldBypassTime = 1000,
		HoldBarColor = {1, 0.84, 0, 0.9},
		ShowHeader = true,
		ShowHeaderLabel = true,
		ShowBarLabels = false,
		ShowBarNumbers = false,
		ShowBuffLabels = true,
		ShowBarTimers = true,
		ShowRampageTimer = true,
		CourageEnabled = true,
		CourageColor = {1, 0.55, 0, 0.85},
		FrenzyEnabled = true,
		FrenzyColor = {1, 0.25, 0.25, 0.85},
		ProwlEnabled = true,
		ProwlColor = {0.25, 0.6, 1, 0.85},
		RampageEnabled = true,
		RoarEnabled = false,
		RoarIconSize = 48,
		RoarRoles = "All",
		RoarBorder = false,
		RoarBorderThickness = 3,
		RoarBorderColor = {0.25, 0.85, 0.4, 0.85},
		FeedingFrenzyPriority = false,
		InsatiableHungerPriority = false,
		IHHideInCombat = false,
		IHCombatTimeout = 2000,
		HeaderText = "Werewolf Form",
	}
local LAM2 = LibAddonMenu2
local flag = true -- Flip-flop for prehook control --
-- Hold-to-bypass state --
local ULTIMATE_SLOT = 8 -- Action bar slot of the ultimate --
local holdToken = 0 -- Incremented to invalidate any pending hold timer --
local holdStartMs = 0 -- Game time (ms) when the current hold started --
local passUntil = 0 -- Game time (ms) until which checks are let through after a completed hold --
local pressTime = nil -- Game time (ms) the current ultimate press started, nil when not held --
local releaseUntil = 0 -- Short window after a release, so the release's own check is not treated as a press --
local messageShown = false -- True once the blocked message has been shown for the current press --
local doublePressUntil = 0 -- Game time (ms) the gamepad double press window ends, 0 when no window is open --
local text1, text2 -- Ultimate display message --
local BarMax, FuryBarMax = 0, 0 -- Max values for ult & Fury --
local UltiText = "Ultimate"
local FuryText = "Fury"
local FuryMaxText = "RAMPAGE!!"
local OldTime = GetTimeStamp()
local showUI = false
-- The preview counts the timers down from 20 seconds, over and over --
local PREVIEW_CYCLE = 20
local PREVIEW_UPDATE_NAME = WerewolfTimerBar.Name .. "_Preview"
local function PreviewCycleEnd(now)
	return (zo_floor(now / PREVIEW_CYCLE) + 1) * PREVIEW_CYCLE
end
-- Cache frequently used globals as locals --
local GetUnitPower = GetUnitPower
local unpack = unpack
local POWERTYPE_WEREWOLF = POWERTYPE_WEREWOLF
local COMBAT_MECHANIC_FLAGS_ULTIMATE = COMBAT_MECHANIC_FLAGS_ULTIMATE
-- Cached references to the XML controls, filled once by UpdateXMLReferences --
local window, backdrop, headerLabel, ultimateButton, buffWindow, buffBackdrop
local statusBar, statusLabel, statusNum, statusIcon, furyBar, furyLabel, furyNum, furyIcon, rampageBar, holdBar
-- Create string for the key bind --
ZO_CreateStringId("SI_BINDING_NAME_BAR_ULTIMATELOCK_TOGGLE", "Toggle Lock/Unlock Ultimate")


local function ReadMaxPower()
	local _, furyMax = GetUnitPower('player', POWERTYPE_WEREWOLF)
	local _, ultMax = GetUnitPower('player', COMBAT_MECHANIC_FLAGS_ULTIMATE)
	if furyMax and furyMax > 0 then FuryBarMax = furyMax end
	if ultMax and ultMax > 0 then BarMax = ultMax end
end
ReadMaxPower() -- Initial check of max power values --

-------------------------------------------------------------------------------------------------
--  Update xml references --
-------------------------------------------------------------------------------------------------
local function UpdateXMLReferences()
	window = window or WerewolfTimerBarWindow
	backdrop = backdrop or WerewolfTimerBarWindow_Backdrop
	headerLabel = headerLabel or WerewolfTimerBarWindow_Label
	ultimateButton = ultimateButton or WerewolfTimerBarWindow_UltimateBlockButton
	statusBar = statusBar or WerewolfTimerBarWindow_StatusBar
	statusIcon = statusIcon or WerewolfTimerBarWindow_StatusIcon
	statusLabel = statusLabel or WerewolfTimerBarWindow_StatusBarLabel
	statusNum = statusNum or WerewolfTimerBarWindow_StatusBarNum
	furyBar = furyBar or WerewolfTimerBarWindow_FuryBar
	furyIcon = furyIcon or WerewolfTimerBarWindow_FuryIcon
	furyLabel = furyLabel or WerewolfTimerBarWindow_FuryBarLabel
	furyNum = furyNum or WerewolfTimerBarWindow_FuryBarNum
	rampageBar = rampageBar or WerewolfTimerBarWindow_RampageBar
	holdBar = holdBar or WerewolfTimerBarWindow_HoldBar
	buffWindow = buffWindow or WerewolfTimerBarBuffs
	buffBackdrop = buffBackdrop or WerewolfTimerBarBuffs_Backdrop
end

-------------------------------------------------------------------------------------------------
--  Icons only mode: sizes and countdown borders --
-------------------------------------------------------------------------------------------------
local ICON_SIZE_MIN, ICON_SIZE_MAX = 30, 60
local BORDER_MIN, BORDER_MAX = 1, 4
local ICON_GAP = 4 -- Space between icons, on top of the borders --
local LAYOUT_HORIZONTAL, LAYOUT_VERTICAL = "Horizontal", "Vertical"

local function ClampIconSize(size)
	return zo_max(ICON_SIZE_MIN, zo_min(ICON_SIZE_MAX, size or ICON_SIZE_MIN))
end

local function ClampThickness(thickness)
	return zo_max(BORDER_MIN, zo_min(BORDER_MAX, thickness or BORDER_MIN))
end

-- The border is drawn outside the icon as five solid strips, in clockwise order from the top centre: --
-- top right half, right side, bottom, left side, top left half --
-- The strips cover the part of the path still remaining, so it disappears clockwise from the top centre --
local function NewBorder(parent, name)
	local border = { segs = {}, segKey = {} }
	for i = 1, 5 do
		local seg = WINDOW_MANAGER:CreateControl(name .. i, parent, CT_TEXTURE)
		-- Above the icons, which matters for a border drawn over the edge of its icon --
		seg:SetDrawLayer(DL_OVERLAY)
		seg:SetDrawLevel(2) -- Above the clock wipe (level 1) --
		seg:SetHidden(true)
		border.segs[i] = seg
	end
	return border
end

local function BorderHide(border)
	if not border then return end
	for i = 1, 5 do
		border.segs[i]:SetHidden(true)
		border.segKey[i] = -1
	end
	border.front = nil
end

-- Surround an icon, and forget everything drawn before --
-- inset moves the border away from the icon edge, or over the icon when it is negative --
local function BorderAttach(border, icon, size, thickness, inset)
	local pad = (inset or 0) + thickness
	local outer = size + 2 * pad
	local side = outer - 2 * thickness
	border.icon = icon
	border.t = thickness
	border.pad = pad
	border.outer = outer
	border.lens = { outer / 2, side, outer, side, outer / 2 }
	border.perimeter = 2 * outer + 2 * side
	border.colorRef = nil
	BorderHide(border)
end

local function BorderSetColor(border, color)
	if border.colorRef == color then return end
	border.colorRef = color
	for i = 1, 5 do
		border.segs[i]:SetColor(unpack(color))
	end
end

-- fraction: 1 is a full border, 0 is none --
local function BorderSet(border, fraction)
	if not (fraction > 0) then fraction = 0 end -- Also catches NaN --
	if fraction > 1 then fraction = 1 end
	-- Whole pixels along the path, so nothing is redrawn until the border has visibly moved --
	local front = zo_floor((1 - fraction) * border.perimeter + 0.5)
	if front == border.front then return end
	border.front = front
	local W, T, pad = border.outer, border.t, border.pad
	local H = W
	local start = 0
	for i = 1, 5 do
		local len = border.lens[i]
		-- How far along this strip the visible part starts --
		local a = front - start
		if a < 0 then a = 0 end
		local seg = border.segs[i]
		if a >= len then
			if border.segKey[i] ~= -1 then
				border.segKey[i] = -1
				seg:SetHidden(true)
			end
		elseif border.segKey[i] ~= a then
			border.segKey[i] = a
			local x, y, w, h
			if i == 1 then x, y, w, h = W / 2 + a, 0, len - a, T
			elseif i == 2 then x, y, w, h = W - T, T + a, T, len - a
			elseif i == 3 then x, y, w, h = W - len, H - T, len - a, T
			elseif i == 4 then x, y, w, h = 0, H - T - len, T, len - a
			else x, y, w, h = a, 0, len - a, T end
			seg:ClearAnchors()
			seg:SetAnchor(TOPLEFT, border.icon, TOPLEFT, x - pad, y - pad)
			seg:SetDimensions(w, h)
			seg:SetHidden(false)
		end
		start = start + len
	end
end

-- The dimmed clock wipe over an icon, using the game's own cooldown control --
-- It animates itself after it is started, so it is only restarted when the countdown changes --
local function NewSweep(parent, name, icon)
	local sweep = WINDOW_MANAGER:CreateControl(name, parent, CT_COOLDOWN)
	sweep:SetAnchorFill(icon)
	sweep:SetFillColor(0, 0, 0, 0.6)
	-- Above the icon (level 0), below the borders (level 2) and the numbers --
	sweep:SetDrawLayer(DL_CONTROLS)
	sweep:SetDrawLevel(1)
	sweep:SetHidden(true) -- Only shown while counting down --
	return sweep
end

local function StartSweep(sweep, remaining, duration)
	sweep:SetHidden(false)
	sweep:StartCooldown(zo_floor(remaining * 1000), zo_floor(duration * 1000), CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_REMAINING, false)
end

-- A finished or restarted-at-zero cooldown can leave the dimming behind, so reset and hide it --
local function ClearSweep(sweep)
	sweep:ResetCooldown()
	sweep:SetHidden(true)
end

-- Place a list of { icon =, margin = } in a row or column, starting at left/top inside parent --
-- margin is the space the icon's border needs around it. Returns the width and height they fill --
local function PlaceIcons(list, size, vertical, parent, left, top)
	local n = #list
	if n == 0 then return 0, 0 end
	local maxMargin = 0
	for _, entry in ipairs(list) do
		maxMargin = zo_max(maxMargin, entry.margin)
	end
	local total = (n - 1) * ICON_GAP
	for i, entry in ipairs(list) do
		local icon = entry.icon
		icon:SetDimensions(size, size)
		icon:ClearAnchors()
		if i == 1 then
			if vertical then
				icon:SetAnchor(TOPLEFT, parent, TOPLEFT, left + maxMargin, top + entry.margin)
			else
				icon:SetAnchor(TOPLEFT, parent, TOPLEFT, left + entry.margin, top + maxMargin)
			end
		else
			local previous = list[i - 1]
			local distance = previous.margin + ICON_GAP + entry.margin
			if vertical then
				icon:SetAnchor(TOPLEFT, previous.icon, BOTTOMLEFT, 0, distance)
			else
				icon:SetAnchor(TOPLEFT, previous.icon, TOPRIGHT, distance, 0)
			end
		end
		total = total + size + 2 * entry.margin
	end
	if vertical then
		return size + 2 * maxMargin, total
	end
	return total, size + 2 * maxMargin
end

-- Main window icons, in order, with the space each border needs --
local function MainIconInfo()
	local sv = WWTB.SV
	local size = ClampIconSize(sv.IconSize)
	local t = sv.IconBorder and ClampThickness(sv.IconBorderThickness) or 0
	local list = {}
	if sv.ShowTimer then list[#list + 1] = { icon = statusIcon, margin = t } end
	if sv.ShowFury then list[#list + 1] = { icon = furyIcon, margin = t } end
	return list, size, t, sv.IconLayout == LAYOUT_VERTICAL
end

-- Bar labels are not shown in icons only mode --
local function LabelsVisible()
	return WWTB.SV.ShowBarLabels and not WWTB.SV.IconsOnly
end

local ultBorder, furyBorder, rampageBorder
local ultBorderOn, furyBorderOn, rampageBorderOn = false, false, false
local rampageSweep, rampageSweepEnd -- Clock wipe over the Fury icon while Rampage counts down (icons only) --
local lastFury = 0

-------------------------------------------------------------------------------------------------
--  Check if Player is Infected by Werewolf --
-------------------------------------------------------------------------------------------------
function WWTB.IsPlayerWerewolf()
	local numberOfBuffs = GetNumBuffs('player')
	if numberOfBuffs ~= 0 then
		for i = 1, numberOfBuffs do
			local _, _, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo('player', i)
			if abilityId == 35658 or abilityId == 40521 then
				return true
			end
		end
	end
	return false
end
 
-------------------------------------------------------------------------------------------------
--  Power update events  --
-------------------------------------------------------------------------------------------------
-- Each bar listens for its own power type only. Without the power type filter the handler ran for --
-- every health, magicka and stamina update too, which is a lot of calls during combat --
local POWER_EVENT_ULT = WWTB.Name .. "_Upd"
local POWER_EVENT_FURY = WWTB.Name .. "_UpdFury"

-- One callback per bar, so the filtered event goes straight to the right bar with no power type check --
-- The events are only registered while the bar is shown, see UpdatePowerEvents --
local function OnUltimateUpdate(_, _, _, _, powerValue)
	WWTB.UpdateTimerBar(powerValue)
end

local function OnFuryUpdate(_, _, _, _, powerValue)
	WWTB.UpdateFuryBar(powerValue)
end

local function SetPowerEvent(eventName, powerType, callback, wanted)
	if wanted then
		EVENT_MANAGER:RegisterForEvent(eventName, EVENT_POWER_UPDATE, callback)
		EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, 'player', REGISTER_FILTER_POWER_TYPE, powerType)
	else
		EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_POWER_UPDATE)
	end
end

-- Registered only while transformed, and only for the bars that are shown --
function WWTB.UpdatePowerEvents()
	local inForm = IsPlayerInWerewolfForm()
	SetPowerEvent(POWER_EVENT_ULT, COMBAT_MECHANIC_FLAGS_ULTIMATE, OnUltimateUpdate, inForm and WWTB.SV.ShowTimer)
	SetPowerEvent(POWER_EVENT_FURY, POWERTYPE_WEREWOLF, OnFuryUpdate, inForm and WWTB.SV.ShowFury)
end

-------------------------------------------------------------------------------------------------
--  Register for Events  --
-------------------------------------------------------------------------------------------------
function WWTB.RegisterEvents()
	-- Register events for werewolf (State change) updates --
	EVENT_MANAGER:RegisterForEvent(WWTB.Name .. "_WWState", EVENT_WEREWOLF_STATE_CHANGED, WWTB.OnWerewolfStateChanged)
	-- Buff effect/combat events follow the werewolf form --
	WWTB.UpdateBuffEvents()
end

-------------------------------------------------------------------------------------------------
--  Unregister for Events  --
-------------------------------------------------------------------------------------------------
function WWTB.UnregisterEvents()
	-- Unregister events for werewolf (State change) updates --
	EVENT_MANAGER:UnregisterForEvent(WWTB.Name .. "_WWState", EVENT_WEREWOLF_STATE_CHANGED)
	-- Unregister events for werewolf updates --
	EVENT_MANAGER:UnregisterForEvent(POWER_EVENT_ULT, EVENT_POWER_UPDATE)
	EVENT_MANAGER:UnregisterForEvent(POWER_EVENT_FURY, EVENT_POWER_UPDATE)
	-- Buff and Rampage effect/combat events are not needed either --
	WWTB.UpdateBuffEvents()
	WWTB.UpdateRampageEvents()
end

-- Is any buff timer turned on? --
function WWTB.AnyBuffTimerEnabled()
	return WWTB.SV.CourageEnabled or WWTB.SV.FrenzyEnabled or WWTB.SV.ProwlEnabled
end

-- Keep the form change event only while something needs it (a bar or a buff timer is on) --
function WWTB.UpdateEvents()
	if WWTB.IsPlayerWerewolf() and (WWTB.SV.ShowTimer or WWTB.SV.ShowFury or WWTB.AnyBuffTimerEnabled()) then
		WWTB.RegisterEvents()
	else
		WWTB.UnregisterEvents()
	end
end

-------------------------------------------------------------------------------------------------
--  Dimension Function --
-------------------------------------------------------------------------------------------------
function WWTB.SetBarSize(Width, Height)
	if WWTB.SV.IconsOnly then
		WWTB.SetIconLayout()
		return
	end
	-- Bars mode: bars, and the numbers at the right end of each bar --
	statusBar:SetHidden(false)
	furyBar:SetHidden(false)
	statusNum:ClearAnchors()
	statusNum:SetAnchor(RIGHT, statusBar, RIGHT, -4, 2)
	statusNum:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
	statusNum:SetDrawTier(DT_PARENT)
	furyNum:SetDrawTier(DT_PARENT)
	furyNum:ClearAnchors()
	furyNum:SetAnchor(RIGHT, furyBar, RIGHT, -4, 2)
	furyNum:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
	headerLabel:SetDimensions(300, 20)
	-- The Rampage bar covers the bottom half of the Fury bar, so both can be seen at once --
	rampageBar:ClearAnchors()
	rampageBar:SetAnchor(BOTTOMLEFT, furyBar, BOTTOMLEFT, 0, 0)
	rampageBar:SetAnchor(BOTTOMRIGHT, furyBar, BOTTOMRIGHT, 0, 0)
	rampageBar:SetHeight(zo_max(1, zo_floor(WWTB.SV.BarHeight / 2)))
	-- Dimensions used for both bars --
	statusBar:SetDimensions(zo_max(1, Width - Height), Height)
	furyBar:SetDimensions(zo_max(1, Width - Height), Height)
	statusIcon:SetDimensions(Height, Height)
	furyIcon:SetDimensions(Height, Height)
	if WWTB.SV.ShowFury and WWTB.SV.ShowTimer then
		-- If both bars enabled, double the backdrop height --
		Height = Height * 2
	end
	if WWTB.SV.ShowFury then
		furyIcon:SetHidden(false)
	else
		-- Hide Fury bar --
		furyBar:SetDimensions(Width, 0)
		furyIcon:SetHidden(true)
	end
	if WWTB.SV.ShowTimer then
		statusIcon:SetHidden(false)
	else
		-- Hide Timer bar --
		statusBar:SetDimensions(Width, 0)
		statusIcon:SetHidden(true)
	end
	if not WWTB.SV.ShowFury and not WWTB.SV.ShowTimer then
		-- Reduce backdrop size if no bars --
		Height = 0
	end
	if WWTB.SV.ShowHeader then
		-- Add space for header bar and anchor bars to ultimate lock button --
		Height = Height + WWTB.SV.BarFontSize + 2
		statusIcon:ClearAnchors()
		statusIcon:SetAnchor(TOPLEFT, backdrop, TOPLEFT, 5, WWTB.SV.BarFontSize + 9)
	else
		-- Modify anchors for bars if no header --
		statusIcon:ClearAnchors()
		statusIcon:SetAnchor(TOPLEFT, backdrop, TOPLEFT, 5, 5)
	end
	-- Set backdrop dimensions --
	backdrop:SetDimensions(WWTB.SV.BarWidth + 10, Height + 10)
	window:SetDimensions(WWTB.SV.BarWidth + 10, Height + 10)
	-- Keep the hold progress bar sitting on the upper active bar --
	WWTB.UpdateHoldBarLayout()
end

-- Icons only mode: icons (Ultimate, Fury) in a row or column, with the numbers centred in each icon --
function WWTB.SetIconLayout()
	local sv = WWTB.SV
	local list, size, t, vertical = MainIconInfo()
	local headerHeight = sv.ShowHeader and (sv.BarFontSize + 2) or 0
	statusBar:SetHidden(true)
	furyBar:SetHidden(true)
	for _, pair in ipairs({ { statusNum, statusIcon }, { furyNum, furyIcon } }) do
		pair[1]:ClearAnchors()
		pair[1]:SetAnchor(CENTER, pair[2], CENTER, 0, 0)
		pair[1]:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
		-- Numbers stay in front of the borders --
		pair[1]:SetDrawLayer(DL_TEXT)
		pair[1]:SetDrawLevel(3) -- Above the clock wipe (1) and borders (2) --
		pair[1]:SetDrawTier(DT_MEDIUM) -- The clock wipe still covered the numbers on the layer alone, so a higher tier too --
	end
	statusIcon:SetHidden(not sv.ShowTimer)
	furyIcon:SetHidden(not sv.ShowFury)
	local top = 5 + headerHeight + (sv.ShowHeader and 2 or 0)
	local contentWidth, contentHeight = PlaceIcons(list, size, vertical, backdrop, 5, top)
	-- Window size: the icons, plus room for the header text when it is shown --
	local width = #list > 0 and (contentWidth + 10) or 0
	if sv.ShowHeader then
		-- Icons only mode has no header text, just the lock button --
		width = zo_max(width, 40)
	end
	local height = headerHeight + 10
	if #list > 0 then
		height = height + contentHeight + (sv.ShowHeader and 2 or 0)
	end
	backdrop:SetDimensions(width, height)
	window:SetDimensions(width, height)
	headerLabel:SetDimensions(zo_max(1, width - 30), 20)
	-- Without a header the lock button sits on the corner of the first icon --
	if not sv.ShowHeader and list[1] then
		local buttonSize = zo_max(14, zo_floor(size * 0.4))
		ultimateButton:ClearAnchors()
		ultimateButton:SetAnchor(TOPLEFT, list[1].icon, TOPLEFT, 1, 1)
		ultimateButton:SetDimensions(buttonSize, buttonSize)
	end
	WWTB.UpdateHoldBarLayout()
end

-- Countdown borders around the main window icons --
function WWTB.SetupMainBorders()
	local sv = WWTB.SV
	if not ultBorder then
		ultBorder = NewBorder(window, "WerewolfTimerBarUltBorder")
		furyBorder = NewBorder(window, "WerewolfTimerBarFuryBorder")
		rampageBorder = NewBorder(window, "WerewolfTimerBarRampageBorder")
	end
	local _, size = MainIconInfo()
	local t = ClampThickness(sv.IconBorderThickness)
	ultBorderOn = (sv.IconsOnly and sv.IconBorder and sv.ShowTimer) and true or false
	furyBorderOn = (sv.IconsOnly and sv.IconBorder and sv.ShowFury) and true or false
	rampageBorderOn = (furyBorderOn and sv.RampageEnabled) and true or false
	-- Attaching clears whatever was drawn, the next update draws it again --
	BorderAttach(ultBorder, statusIcon, size, t)
	BorderAttach(furyBorder, furyIcon, size, t)
	-- Inside the Fury border, over the edge of the icon, so it takes no extra room --
	BorderAttach(rampageBorder, furyIcon, size, t, -t)
	if not rampageSweep then
		rampageSweep = NewSweep(window, "WerewolfTimerBarRampageSweep", furyIcon)
	end
	rampageSweepEnd = nil
	ClearSweep(rampageSweep)
end

-- Hold progress bar: half the bar height, drawn over the top of the upper active bar --
function WWTB.UpdateHoldBarLayout()
	if WWTB.SV.IconsOnly then
		-- Icons only: a strip across the top of the first icon, or of the whole row --
		local list, size, _, vertical = MainIconInfo()
		local rowWidth = size
		if not vertical then
			rowWidth = #list * size
			for i = 2, #list do
				rowWidth = rowWidth + list[i - 1].margin + ICON_GAP + list[i].margin
			end
		end
		holdBar:ClearAnchors()
		if list[1] then
			holdBar:SetAnchor(TOPLEFT, list[1].icon, TOPLEFT, 0, 0)
		else
			holdBar:SetAnchor(TOPLEFT, backdrop, TOPLEFT, 5, 5)
		end
		holdBar:SetDimensions(zo_max(1, rowWidth), zo_max(4, zo_floor(size / 4)))
		return
	end
	local target
	if WWTB.SV.ShowTimer then
		target = statusIcon
	elseif WWTB.SV.ShowFury then
		target = furyIcon
	end
	holdBar:ClearAnchors()
	if target then
		holdBar:SetAnchor(TOPLEFT, target, TOPRIGHT, 0, 0)
	elseif WWTB.SV.ShowHeader then
		-- No bars shown, sit where the first bar would be --
		holdBar:SetAnchor(TOPLEFT, backdrop, TOPLEFT, 5, WWTB.SV.BarFontSize + 9)
	else
		holdBar:SetAnchor(TOPLEFT, backdrop, TOPLEFT, 5, 5)
	end
	holdBar:SetDimensions(zo_max(1, WWTB.SV.BarWidth - WWTB.SV.BarHeight), zo_floor(WWTB.SV.BarHeight / 2))
end

-------------------------------------------------------------------------------------------------
--  Shared Helpers --
-------------------------------------------------------------------------------------------------
-- prefix picks the window: "Bar" (main window, the default), "Buff" or "Roar" --
function WWTB.GetFontString(prefix)
	prefix = prefix or "Bar"
	local sv = WWTB.SV
	return '$(' .. sv[prefix .. "FontName"] .. ')|' .. tostring(sv[prefix .. "FontSize"]) .. '|' .. sv[prefix .. "FontStyle"]
end

-- Is any text currently drawn with the font settings? (header, bar labels, bar numbers, buff labels/timers) --
function WWTB.IsFontInUse()
	if WWTB.SV.ShowHeader and WWTB.SV.ShowHeaderLabel and not WWTB.SV.IconsOnly then return true end
	if (WWTB.SV.ShowTimer or WWTB.SV.ShowFury) and (LabelsVisible() or WWTB.SV.ShowBarNumbers) then return true end
	if WWTB.SV.ShowFury and WWTB.SV.RampageEnabled and WWTB.SV.ShowRampageTimer then return true end
	return false
end

-- Re-read max power values (they may not be available when the file loads) --
function WWTB.RefreshMaxPower()
	ReadMaxPower()
	statusBar:SetMinMax(0, BarMax)
	furyBar:SetMinMax(0, FuryBarMax)
end

-- Last colour applied to each bar, so SetColor is only called when the colour actually changes --
-- Settings replace the colour tables, so comparing the table reference is enough to spot a change --
local lastTimerColor, lastFuryColor, lastFuryLabelText

-- Forget the cached bar colours, for when they are set directly elsewhere --
function WWTB.ResetBarCache()
	lastTimerColor, lastFuryColor, lastFuryLabelText = nil, nil, nil
end

-- Countdown text is only rebuilt when it would change: tenths below 10 seconds, whole seconds above --
local function CountdownKey(remaining)
	if remaining < 10 then return zo_floor(remaining * 10 + 0.5) end
	return -zo_ceil(remaining)
end

local function CountdownText(remaining)
	if remaining < 10 then return string.format("%.1f", remaining) end
	return tostring(zo_ceil(remaining))
end

-- Set Ultimate timer bar value and color --
function WWTB.UpdateTimerBar(power)
	-- The preview shows a full bar --
	if showUI then power = BarMax end
	local color = WWTB.SV.BarColor
	if WWTB.SV.WarningColor then
		if power <= WWTB.SV.CriticalLevel then
			color = WWTB.SV.CriticalBarColor
		elseif power <= WWTB.SV.WarningLevel then
			color = WWTB.SV.WarningBarColor
		end
	end
	statusBar:SetValue(power)
	if color ~= lastTimerColor then
		lastTimerColor = color
		statusBar:SetColor(unpack(color))
	end
	if ultBorderOn then
		-- The border follows the bar: it empties as the ultimate does, in the bar's colour --
		BorderSetColor(ultBorder, color)
		BorderSet(ultBorder, BarMax > 0 and power / BarMax or 0)
	end
	if WWTB.SV.ShowBarNumbers then
		statusNum:SetText(tostring(power))
	end
end

-------------------------------------------------------------------------------------------------
--  Rampage Timer --
-------------------------------------------------------------------------------------------------
-- The Rampage buff of each Werewolf Transformation morph: unmorphed, Pack Leader, Berserker --
-- Only one of these can be running, so the one for the slotted morph is the one that shows --
local RAMPAGE_IDS = { 266377, 267425, 267416 }
local RAMPAGE_UPDATE_NAME = WWTB.Name .. "_RampageBar"
local rampage = { active = false, endTime = 0, duration = 1, eventOn = false, updating = false }
-- What the Rampage bar label and number last showed, so unchanged values are not set again every tick --
local rampageShown, rampageColor, rampageMax, rampageText

-- Is Rampage shown? While it is active, and also in the UI preview --
local function RampageDisplayed()
	return rampage.active or (showUI and WWTB.SV.ShowFury and WWTB.SV.RampageEnabled)
end

-- The Fury number shows the Rampage countdown while Rampage is active and Buff Bar Timers is on, --
-- otherwise the Fury value, following the Ultimate & Fury Bar Numbers setting --
local function UpdateFuryNumberVisible()
	if not WWTB.SV.ShowFury then return end
	local show
	if RampageDisplayed() and WWTB.SV.ShowRampageTimer then
		show = true
	else
		show = WWTB.SV.ShowBarNumbers
	end
	furyNum:SetHidden(not show)
end

-- Icons only: the Fury border follows the Fury value, with the Rampage border inside it while Rampage is active --
local function RefreshFuryBorder()
	local sv = WWTB.SV
	-- The Fury border always follows the Fury value --
	-- (The preview keeps the normal colour even though it shows the border full) --
	BorderSetColor(furyBorder, (lastFury == FuryBarMax and not showUI) and sv.FuryBarMaxColor or sv.FuryBarColor)
	BorderSet(furyBorder, FuryBarMax > 0 and lastFury / FuryBarMax or 0)
	-- While Rampage is active, a second border just inside it counts the Rampage down --
	if rampageBorderOn and RampageDisplayed() then
		BorderSetColor(rampageBorder, sv.FuryBarMaxColor)
		if showUI then
			local now = GetGameTimeSeconds()
			BorderSet(rampageBorder, (PreviewCycleEnd(now) - now) / PREVIEW_CYCLE)
		else
			BorderSet(rampageBorder, (rampage.endTime - GetGameTimeSeconds()) / rampage.duration)
		end
	elseif rampageBorder and rampageBorder.front ~= nil then
		BorderHide(rampageBorder)
	end
end

-- The clock wipe over the Fury icon follows the real Rampage countdown, in icons only mode --
local function RefreshRampageSweep(remaining, endTime, duration)
	if not rampageSweep then return end
	if remaining then
		if rampageSweepEnd ~= endTime then
			rampageSweepEnd = endTime
			StartSweep(rampageSweep, remaining, duration)
		end
	elseif rampageSweepEnd ~= nil then
		rampageSweepEnd = nil
		ClearSweep(rampageSweep)
	end
end

-- Draw the Rampage bar and countdown from the current state --
function WWTB.RefreshRampage()
	if not RampageDisplayed() or not WWTB.SV.ShowFury or not WWTB.SV.RampageEnabled then
		RefreshRampageSweep(nil)
		if rampageShown ~= false then
			rampageShown = false
			rampageBar:SetHidden(true)
		end
		UpdateFuryNumberVisible()
		if furyBorderOn then RefreshFuryBorder() end
		return
	end
	-- The preview counts down from 20 over and over, whether or not Rampage is running --
	local now = GetGameTimeSeconds()
	local remaining, duration, endTime
	if showUI then
		endTime, duration = PreviewCycleEnd(now), PREVIEW_CYCLE
		remaining = endTime - now
	else
		endTime, duration = rampage.endTime, rampage.duration
		remaining = endTime - now
		if remaining <= 0 then
			-- Expired without a fade event --
			WWTB.SetRampage(false)
			return
		end
	end
	RefreshRampageSweep(WWTB.SV.IconsOnly and remaining or nil, endTime, duration)
	if WWTB.SV.IconsOnly then
		-- No bar in icons only mode, the Rampage border counts down instead --
		if rampageShown ~= false then
			rampageShown = false
			rampageBar:SetHidden(true)
		end
	else
		-- Colour and range only change with the settings or a new Rampage, so they are not set every tick --
		local color = WWTB.SV.FuryBarMaxColor
		if color ~= rampageColor then
			rampageColor = color
			rampageBar:SetColor(unpack(color))
		end
		if duration ~= rampageMax then
			rampageMax = duration
			rampageBar:SetMinMax(0, rampageMax)
		end
		rampageBar:SetValue(remaining)
		if rampageShown ~= true then
			rampageShown = true
			rampageBar:SetHidden(false)
		end
	end
	if furyBorderOn then RefreshFuryBorder() end
	-- The countdown replaces the Fury number while Rampage is active, following the Buff Bar Timers setting --
	UpdateFuryNumberVisible()
	if WWTB.SV.ShowRampageTimer then
		-- Only rebuild the text when the displayed value changes --
		local key = CountdownKey(remaining)
		if key ~= rampageText then
			rampageText = key
			furyNum:SetText(CountdownText(remaining))
		end
	end
end

function WWTB.SetRampage(active, beginTime, endTime)
	rampage.active = active
	rampageText = nil
	rampageMax = nil -- A new Rampage sets its own range --
	if active then
		rampage.endTime = endTime
		rampage.duration = zo_max(endTime - beginTime, 0.001)
		-- Only update while Rampage is running --
		if not rampage.updating then
			rampage.updating = true
			EVENT_MANAGER:RegisterForUpdate(RAMPAGE_UPDATE_NAME, 50, WWTB.RefreshRampage)
		end
	else
		rampage.endTime = 0
		if rampage.updating then
			rampage.updating = false
			EVENT_MANAGER:UnregisterForUpdate(RAMPAGE_UPDATE_NAME)
		end
	end
	WWTB.RefreshRampage()
	-- Label and number follow the Rampage state --
	if WWTB.SV.ShowFury and IsPlayerInWerewolfForm() then
		WWTB.UpdateFuryBar(GetUnitPower('player', POWERTYPE_WEREWOLF))
	end
end

-- The event is filtered to the player and to the Rampage ability ids, so no checks are needed here --
local function OnRampageEffect(_, changeType, _, _, _, beginTime, endTime)
	if changeType == EFFECT_RESULT_FADED then
		WWTB.SetRampage(false)
	else
		WWTB.SetRampage(true, beginTime, endTime)
	end
end

-- Effect events are only registered while transformed with the Fury bar and the Rampage timer on --
function WWTB.UpdateRampageEvents()
	local want = IsPlayerInWerewolfForm() and WWTB.SV.ShowFury and WWTB.SV.RampageEnabled and true or false
	if want and not rampage.eventOn then
		rampage.eventOn = true
		for i, abilityId in ipairs(RAMPAGE_IDS) do
			local eventName = WWTB.Name .. "_Rampage" .. i
			EVENT_MANAGER:RegisterForEvent(eventName, EVENT_EFFECT_CHANGED, OnRampageEffect)
			EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, 'player', REGISTER_FILTER_ABILITY_ID, abilityId)
		end
		-- Pick up a Rampage that is already running (after a reload, or when porting) --
		for i = 1, GetNumBuffs("player") do
			local _, timeStarted, timeEnding, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
			for _, rampageId in ipairs(RAMPAGE_IDS) do
				if abilityId == rampageId then
					WWTB.SetRampage(true, timeStarted, timeEnding)
				end
			end
		end
	elseif not want and rampage.eventOn then
		rampage.eventOn = false
		for i = 1, #RAMPAGE_IDS do
			EVENT_MANAGER:UnregisterForEvent(WWTB.Name .. "_Rampage" .. i, EVENT_EFFECT_CHANGED)
		end
		WWTB.SetRampage(false)
	end
end

-- Set Fury bar value, color and label --
function WWTB.UpdateFuryBar(fury)
	-- The preview shows a full bar, in the normal colour --
	if showUI then fury = FuryBarMax end
	local full = (fury == FuryBarMax) and not showUI
	furyBar:SetValue(fury)
	local color = full and WWTB.SV.FuryBarMaxColor or WWTB.SV.FuryBarColor
	if color ~= lastFuryColor then
		lastFuryColor = color
		furyBar:SetColor(unpack(color))
	end
	-- The label keeps the Rampage text while Rampage is active, and the number is its countdown --
	local labelText = (full or RampageDisplayed()) and FuryMaxText or FuryText
	if labelText ~= lastFuryLabelText then
		lastFuryLabelText = labelText
		furyLabel:SetText(labelText)
	end
	if WWTB.SV.ShowBarNumbers and not (RampageDisplayed() and WWTB.SV.ShowRampageTimer) then
		rampageText = nil -- The number no longer shows the countdown --
		furyNum:SetText(tostring(fury))
	end
	lastFury = fury
	if furyBorderOn then RefreshFuryBorder() end
end

-------------------------------------------------------------------------------------------------
--  Show/Hide Function --
-------------------------------------------------------------------------------------------------
function WWTB.ShowHide()
	if IsPlayerInWerewolfForm() or showUI then
		-- If werewolf then show the bars --
		local ultAbilityId = GetSlotBoundId(ULTIMATE_SLOT)
		if WWTB.SV.ShowTimer then
			-- Get Ultimate value --
			local currentPower, _, _ = GetUnitPower('player', COMBAT_MECHANIC_FLAGS_ULTIMATE)
			WWTB.UpdateTimerBar(currentPower)
			statusNum:SetHidden(not WWTB.SV.ShowBarNumbers)
			if LabelsVisible() then
				statusLabel:SetHidden(false)
				statusLabel:SetText(UltiText)
			else
				statusLabel:SetHidden(true)
			end
			-- Set werewolf icon? --
			if ultAbilityId == 39075 or ultAbilityId == 39076 then
				statusIcon:SetTexture(GetAbilityIcon(ultAbilityId))
			else
				statusIcon:SetTexture(GetAbilityIcon(32455))
			end
		end
		if WWTB.SV.ShowFury then
			-- Get Fury value --
			local currentFury, _, _ = GetUnitPower('player', POWERTYPE_WEREWOLF)
			WWTB.UpdateFuryBar(currentFury)
			WWTB.RefreshRampage()
			UpdateFuryNumberVisible()
			if LabelsVisible() then
				furyLabel:SetHidden(false)
			else
				furyLabel:SetHidden(true)
			end
			if ultAbilityId == 39075 then -- Pack Leader - Enduring Rampage
				furyIcon:SetTexture(GetAbilityIcon(267425))
			elseif ultAbilityId == 39076 then -- Berserker
				furyIcon:SetTexture(GetAbilityIcon(267416))
			else							-- Unmorphed
				furyIcon:SetTexture(GetAbilityIcon(266377))
			end
		end
		-- If any parts shown, show window --
		if WWTB.SV.ShowTimer or WWTB.SV.ShowFury or WWTB.SV.ShowHeader then
			window:SetHidden(false)
		else
			window:SetHidden(true)
		end
		-- No header text in icons only mode, only the lock button --
		if WWTB.SV.ShowHeader and WWTB.SV.ShowHeaderLabel and not WWTB.SV.IconsOnly then
			headerLabel:SetHidden(false)
		else
			headerLabel:SetHidden(true)
		end
	else
		window:SetHidden(true)
	end
end

-------------------------------------------------------------------------------------------------
--  Ultimate Block/UnBlock Functions --
-------------------------------------------------------------------------------------------------
function WWTB.DrawUltimateBlockButton(Control)
	if WWTB.SV.UltimateEnable then
		-- Draw the lock icon --
		Control:SetNormalTexture("/esoui/art/miscellaneous/locked_up.dds")
		Control:SetPressedTexture("/esoui/art/miscellaneous/locked_down.dds")
		Control:SetMouseOverTexture("/esoui/art/miscellaneous/locked_over.dds")
	else
		-- Draw the unlock icon --
		Control:SetNormalTexture("/esoui/art/miscellaneous/unlocked_up.dds")
		Control:SetPressedTexture("/esoui/art/miscellaneous/unlocked_down.dds")
		Control:SetMouseOverTexture("/esoui/art/miscellaneous/unlocked_over.dds")
	end
end

function WWTB.ClickUltimateBlockButton(Control)
	-- Flip flop for lock and unlock state --
	WWTB.SV.UltimateEnable = not WWTB.SV.UltimateEnable
	-- Setup the display text --
	WWTB.SetupUltimateBlockText()
	-- Display the message, if enabled --
	if not WWTB.SV.HideCSA then
		local msg = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, nil)
		msg:SetText(text1, text2)
		msg:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_CHAMPION_POINT_GAINED)
		msg:MarkSuppressIconFrame()
		CENTER_SCREEN_ANNOUNCE:DisplayMessage(msg)
	end
	d(text1)
	-- Update the button texture --
	WWTB.DrawUltimateBlockButton(Control)
end

function WWTB.SetupUltimateBlockText()
	-- Get keybinding --
	local keyBind = ZO_Keybindings_GetHighestPriorityBindingStringFromAction("BAR_ULTIMATELOCK_TOGGLE")
	-- Change text message depending on lock/unlock state --
	if WWTB.SV.UltimateEnable then
		text1 = "Werewolf Timer Bar: Ultimate BLOCKED!"
		if keyBind then
			text2 = string.format("%s %s %s %s", "Click the lock in the top left of the addon", "or press [", keyBind, "] to change.")
		else
			text2 = "Click the lock in the top left of the addon to change or set a keybind to toggle this."
		end
		if WWTB.SV.HoldBypassEnabled then
			if IsInGamepadPreferredMode() then
				text2 = text2 .. string.format(" Or press the ultimate again within %.1fs to bypass the lock.", WWTB.SV.HoldBypassTime / 1000)
			else
				text2 = text2 .. string.format(" Or hold the ultimate button for %.1fs to bypass the lock.", WWTB.SV.HoldBypassTime / 1000)
			end
		end
	else
		text1 = "Werewolf Timer Bar: Ultimate UNBLOCKED!"
		if keyBind then
			text2 = string.format("%s %s %s %s", "Click the unlock in the top left of the addon", "or press [", keyBind, "] to change.")
		else
			text2 = "Click the unlock in the top left of the addon to change or set a keybind to toggle this."
		end
	end
end

-- Hold-to-bypass --
-- The ultimate is timed from its first blocked check. Once the key has been held for the hold time, --
-- the check made when the key is released is let through, which casts the ultimate on release. --
local function StopHoldBar()
	EVENT_MANAGER:UnregisterForUpdate(WWTB.Name .. "_HoldBar")
	holdBar:SetHidden(true)
end

local function UpdateHoldBar()
	holdBar:SetValue(zo_min(GetGameTimeMilliseconds() - holdStartMs, WWTB.SV.HoldBypassTime))
end

local function StartHold()
	holdToken = holdToken + 1
	local token = holdToken
	holdBar:SetColor(unpack(WWTB.SV.HoldBarColor))
	holdBar:SetMinMax(0, WWTB.SV.HoldBypassTime)
	holdBar:SetValue(0)
	holdBar:SetHidden(false)
	holdStartMs = GetGameTimeMilliseconds()
	EVENT_MANAGER:RegisterForUpdate(WWTB.Name .. "_HoldBar", 0, UpdateHoldBar)
	-- Sound when the hold time is reached and the key is still held, so you know it is ready to release --
	zo_callLater(function()
		if token == holdToken and SOUNDS and SOUNDS.ABILITY_ULTIMATE_READY then
			PlaySound(SOUNDS.ABILITY_ULTIMATE_READY)
		end
	end, WWTB.SV.HoldBypassTime)
end

local function CancelHold()
	holdToken = holdToken + 1
	StopHoldBar()
end

-- Gamepad double press: the first press is blocked and opens a window, a second press inside it is let through. --
-- The gamepad keybind has no key down to time a hold from, so this is the gamepad alternative, using the same enable setting and time as the hold. The window drains on the hold bar --
local DOUBLE_UPDATE_NAME = WWTB.Name .. "_DoubleBar"

local function StopDoublePress()
	doublePressUntil = 0
	EVENT_MANAGER:UnregisterForUpdate(DOUBLE_UPDATE_NAME)
	holdBar:SetHidden(true)
end

local function UpdateDoublePressBar()
	local remaining = doublePressUntil - GetGameTimeMilliseconds()
	if remaining <= 0 then
		StopDoublePress()
		return
	end
	holdBar:SetValue(remaining)
end

local function StartDoublePress()
	local window = WWTB.SV.HoldBypassTime
	doublePressUntil = GetGameTimeMilliseconds() + window
	holdBar:SetColor(unpack(WWTB.SV.HoldBarColor))
	holdBar:SetMinMax(0, window)
	holdBar:SetValue(window)
	holdBar:SetHidden(false)
	EVENT_MANAGER:RegisterForUpdate(DOUBLE_UPDATE_NAME, 0, UpdateDoublePressBar)
end

-- Werewolf Transformation and its two morphs --
local WEREWOLF_ULTIMATES = { [32455] = true, [39075] = true, [39076] = true }

-- Finding the pressed slot needs a stack trace, which is the expensive part of the block check, --
-- so it is only done once the cheap checks have passed. Returns the slot, and whether it was the gamepad keybind --
local function GetPressedSlot()
	local tb = debug.traceback()
	local slotNum = tonumber(tb:match('keybind = "ACTION_BUTTON_(%d)'))
	if slotNum then return slotNum, false end
	return tonumber(tb:match('keybind = "GAMEPAD_ACTION_BUTTON_(%d)')), true
end

function WWTB.SetupUltimateBlock()
	ZO_PreHook("ZO_ActionBar_CanUseActionSlots", function()
		-- Use a flag since ZO_ActionBar_CanUseActionSlots is called twice for each ability cast --
  		flag = not flag
		-- Player is in combat, or has permanet block enabled --
		if IsUnitInCombat("player") or not WWTB.SV.BlockInCombatOnly then
			-- Ultimate blocking set to true, a werewolf, and the werewolf ultimate or a morph is slotted --
			-- (cheap checks first, so the stack trace is skipped whenever the block could not apply) --
			if WWTB.SV.UltimateEnable and IsPlayerInWerewolfForm() and WEREWOLF_ULTIMATES[GetSlotBoundId(ULTIMATE_SLOT)] then
				-- Ultimate button pressed? --
				local slotNum, isGamepad = GetPressedSlot()
				if slotNum == ULTIMATE_SLOT then
					-- The keyboard keybind is checked on key down and on key up, so a hold can be timed. --
					-- The gamepad keybind is only checked on release, so there is nothing to time, it uses a double press instead --
					if WWTB.SV.HoldBypassEnabled and not isGamepad then
						local now = GetGameTimeMilliseconds()
						-- Checks already let through --
						if now < passUntil then return end
						-- Keep checks made just after a release blocked, and do not count them as a new press --
						if now < releaseUntil then return true end
						-- Held for the full hold time: let this check through so the ultimate casts --
						if pressTime and now - pressTime >= WWTB.SV.HoldBypassTime then
							passUntil = now + 300
							return
						end
						-- First blocked check of a press: start timing the hold --
						if not pressTime then
							pressTime = now
							messageShown = false
							StartHold()
						end
					elseif isGamepad and WWTB.SV.HoldBypassEnabled then
						-- Gamepad: a second press inside the window of a blocked press is let through --
						if GetGameTimeMilliseconds() < doublePressUntil then
							StopDoublePress()
							return
						end
						-- First press: blocked below, and opens the window --
						StartDoublePress()
					end
					-- Keyboard: checked on key down and key up, so one message per press with hold bypass on, --
					-- otherwise on every second check as before. Gamepad: one check per press, always show --
					local showMessage = flag
					if isGamepad then
						showMessage = true
					elseif WWTB.SV.HoldBypassEnabled then
						showMessage = not messageShown
						messageShown = true
					end
					if showMessage and not WWTB.SV.HideCSA then
						WWTB.SetupUltimateBlockText()
						local msg = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, nil)
						msg:SetText(text1, text2)
						msg:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_CHAMPION_POINT_GAINED)
						msg:MarkSuppressIconFrame()
						CENTER_SCREEN_ANNOUNCE:DisplayMessage(msg)
						d(text1)
					end
					-- Returning true will block the keypress --
					return true
				end
			end
		end
	end)

	-- Releasing the ultimate key ends the hold and hides the bar --
	ZO_PreHook("ZO_ActionBar_OnActionButtonUp", function(slotNum)
		if slotNum ~= ULTIMATE_SLOT then return end
		releaseUntil = GetGameTimeMilliseconds() + 80
		pressTime = nil
		CancelHold()
	end)
end

-------------------------------------------------------------------------------------------------
-- Setup UI Function --
-------------------------------------------------------------------------------------------------
function WWTB.SetupUIHandlers()
	-- Set once no need to repeat on every settings change --
	ultimateButton:SetHandler("OnMouseEnter", function(self) ZO_Tooltips_ShowTextTooltip(self, TOP, "Enable/disable ultimate button keypress") end)
	ultimateButton:SetHandler("OnMouseExit", function(self) ZO_Tooltips_HideTextTooltip() end)
end

function WWTB.SetupUIElements()
	-- Bar colours are set directly below, so the cached colours are no longer known --
	WWTB.ResetBarCache()
	-- Show Headers --
	-- Block ultimate button --
	ultimateButton:SetHidden(false)
	
	if WWTB.SV.ShowHeader then
		ultimateButton:ClearAnchors()
		ultimateButton:SetAnchor(TOPLEFT, backdrop, TOPLEFT, 6, 3)
		ultimateButton:SetDimensions(WWTB.SV.BarFontSize + 2, WWTB.SV.BarFontSize + 2)
		-- Text --
		headerLabel:SetFont(WWTB.GetFontString())
		headerLabel:SetText(WWTB.SV.HeaderText)
		if WWTB.SV.ShowHeaderLabel and not WWTB.SV.IconsOnly then
			headerLabel:SetHidden(false)
		else
			headerLabel:SetHidden(true)
		end
	else
		ultimateButton:ClearAnchors()
		ultimateButton:SetAnchor(TOPLEFT, statusBar, TOPLEFT, 2, 0)
		ultimateButton:SetDimensions(WWTB.SV.BarHeight, WWTB.SV.BarHeight)
		headerLabel:SetHidden(true)
	end
	-- Timer Bar --
	if WWTB.SV.ShowTimer then
		statusBar:SetColor(unpack(WWTB.SV.BarColor))
		statusBar:SetMinMax(0,BarMax)
		statusNum:SetFont(WWTB.GetFontString())
		-- Labels --
		if LabelsVisible() then
			statusLabel:SetFont(WWTB.GetFontString())
			statusLabel:SetText(UltiText)
			statusLabel:SetHidden(false)
		else
			statusLabel:SetHidden(true)
		end
	else
		statusLabel:SetHidden(true)
		statusNum:SetHidden(true)
	end
	-- Fury Bar --
	if WWTB.SV.ShowFury then
		furyBar:SetColor(unpack(WWTB.SV.FuryBarColor))
		furyBar:SetMinMax(0,FuryBarMax)
		furyNum:SetFont(WWTB.GetFontString())
		furyIcon:ClearAnchors()
		furyIcon:SetAnchor(TOPLEFT, statusBar, BOTTOMLEFT, - WWTB.SV.BarHeight, 0)
		-- Labels --
		if LabelsVisible() then
			furyLabel:SetFont(WWTB.GetFontString())
			furyLabel:SetHidden(false)
		else
			furyLabel:SetHidden(true)
		end
	else
		furyLabel:SetHidden(true)
		furyNum:SetHidden(true)
	end
	-- Bar labels start after the lock button, which sits on the Ultimate bar when there is no header --
	local labelOffset = 20
	if not WWTB.SV.ShowHeader then
		labelOffset = zo_max(20, WWTB.SV.BarHeight + 2)
	end
	statusLabel:ClearAnchors()
	statusLabel:SetAnchor(LEFT, statusBar, LEFT, labelOffset, 2)
	furyLabel:ClearAnchors()
	furyLabel:SetAnchor(LEFT, furyBar, LEFT, labelOffset, 2)
	WWTB.SetBarSize(WWTB.SV.BarWidth, WWTB.SV.BarHeight)
	WWTB.SetupMainBorders()
	WWTB.ShowHide()
	-- Buff timer windows follow the same size, font and settings --
	WWTB.SetupBuffTimerUI()
	WWTB.RefreshBuffTimers()
	-- The Roar range icon too --
	WWTB.SetupRoarUI()
	WWTB.RefreshRoar()
	-- A resized preview window may need moving clear of the settings panel again --
	WWTB.PlacePreviewWindows()
end

-------------------------------------------------------------------------------------------------
--  Buff Timers (Major Courage, Feeding Frenzy, Prowl) --
-------------------------------------------------------------------------------------------------
-- Each timer is its own window, moved separately in Edit HUD --
-- abilityId is the effect tracked on the player, displayId is used for the name and icon --
local buffTimers = {
	{ key = "Courage", abilityId = 109966, displayId = 109966, fallbackName = "Major Courage", showInCombat = true },
	{ key = "Frenzy", abilityId = 131353, displayId = 131353, fallbackName = "Feeding Frenzy", showInCombat = true },
	{ key = "Prowl", abilityId = 252086, displayId = 252086, fallbackName = "Prowl" },
}
local BUFF_UPDATE_NAME = WWTB.Name .. "_BuffTimers"
local buffTimersReady = false
local buffUpdateRunning = false
local buffLayoutKey = nil -- Which timer rows were last laid out in the window --
local buffTimersSuppressed = false -- True in scenes where the HUD should be hidden --

local function FetchBuffTimerControls()
	-- Row controls are children of buffWindow, named "$(parent)_<Key>Icon" etc. in the XML --
	for _, timer in ipairs(buffTimers) do
		timer.icon = buffWindow:GetNamedChild("_" .. timer.key .. "Icon")
		timer.bar = buffWindow:GetNamedChild("_" .. timer.key .. "Bar")
		timer.nameLabel = buffWindow:GetNamedChild("_" .. timer.key .. "Name")
		timer.timeLabel = buffWindow:GetNamedChild("_" .. timer.key .. "Time")
		timer.enabledKey = timer.key .. "Enabled"
		timer.colorKey = timer.key .. "Color"
		timer.active = false
		timer.endTime = 0
		timer.duration = 0
	end
	buffTimersReady = true
end

-- Size, font, color, name and icon, from the addon settings --
function WWTB.SetupBuffTimerUI()
	if not buffTimersReady then FetchBuffTimerControls() end
	local width, height = WWTB.SV.BuffBarWidth, WWTB.SV.BuffBarHeight
	local font = WWTB.GetFontString("Buff")
	local iconsOnly = WWTB.SV.BuffIconsOnly
	local iconSize = ClampIconSize(WWTB.SV.BuffIconSize)
	local useBorder = (iconsOnly and WWTB.SV.BuffIconBorder) and true or false
	-- Size and row layout are redone by RefreshBuffTimers --
	buffLayoutKey = nil
	for _, timer in ipairs(buffTimers) do
		-- Forget what was last drawn, so the next refresh sets everything again --
		timer.state, timer.lastMax, timer.textKey = nil, nil, nil
		if not timer.border then
			timer.border = NewBorder(buffWindow, "WerewolfTimerBarBuffBorder" .. timer.key)
		end
		if not timer.sweep then
			timer.sweep = NewSweep(buffWindow, "WerewolfTimerBarBuffSweep" .. timer.key, timer.icon)
		end
		timer.sweepEnd = nil
		ClearSweep(timer.sweep)
		timer.useBorder = useBorder
		BorderAttach(timer.border, timer.icon, iconSize, ClampThickness(WWTB.SV.BuffIconBorderThickness))
		timer.timeLabel:ClearAnchors()
		if iconsOnly then
			-- The timer number is centred in the icon --
			timer.icon:SetDimensions(iconSize, iconSize)
			timer.timeLabel:SetAnchor(CENTER, timer.icon, CENTER, 0, 0)
			timer.timeLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
			timer.timeLabel:SetDrawLayer(DL_TEXT) -- In front of the border --
			timer.timeLabel:SetDrawLevel(3) -- Above the clock wipe (1) and borders (2) --
			timer.timeLabel:SetDrawTier(DT_MEDIUM) -- The clock wipe still covered the numbers on the layer alone, so a higher tier too --
		else
			timer.icon:SetDimensions(height, height)
			timer.timeLabel:SetAnchor(RIGHT, timer.bar, RIGHT, -4, 2)
			timer.timeLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
			timer.timeLabel:SetDrawTier(DT_PARENT)
		end
		timer.icon:SetTexture(GetAbilityIcon(timer.displayId))
		timer.bar:SetDimensions(zo_max(1, width - height), height)
		timer.bar:SetColor(unpack(WWTB.SV[timer.colorKey]))
		timer.nameLabel:SetFont(font)
		timer.timeLabel:SetFont(font)
		local name = GetAbilityName(timer.displayId)
		if not WWTB.SV.ShowBuffLabels then
			timer.nameLabel:SetText("")
		elseif name and name ~= "" then
			timer.nameLabel:SetText(zo_strformat("<<1>>", name))
		else
			timer.nameLabel:SetText(timer.fallbackName)
		end
	end
end

-- What a timer row last drew, so only changes are sent to the controls --
local STATE_PREVIEW, STATE_COUNTING, STATE_FULL, STATE_EMPTY = 1, 2, 3, 4

local function UpdateBuffTimer(timer, now)
	local endTime, duration = timer.endTime, timer.duration
	if showUI then
		-- UI preview: every timer counts down from 20 over and over, whether or not its effect is running --
		endTime, duration = PreviewCycleEnd(now), PREVIEW_CYCLE
	end
	local remaining = endTime - now
	local state
	if showUI then
		state = STATE_COUNTING
	elseif timer.active and timer.duration > 0 and remaining > 0 then
		state = STATE_COUNTING
	elseif timer.active then
		-- Running with no duration to count down: full bar --
		state = STATE_FULL
	else
		-- Not running, but kept visible by "Always Show" or the combat option: empty bar, dimmed icon --
		state = STATE_EMPTY
	end
	if state ~= STATE_COUNTING then
		-- These states draw a fixed picture, so it is only drawn once --
		if timer.state == state then return end
		timer.state, timer.lastMax, timer.textKey = state, nil, nil
		if timer.sweepEnd ~= nil then
			timer.sweepEnd = nil
			ClearSweep(timer.sweep)
		end
		timer.icon:SetAlpha(state == STATE_EMPTY and 0.4 or 1)
		timer.bar:SetMinMax(0, 1)
		timer.bar:SetValue(state == STATE_EMPTY and 0 or 1)
		timer.timeLabel:SetText((state == STATE_PREVIEW and WWTB.SV.ShowBarTimers) and "--" or "")
		if timer.useBorder then
			-- Full border while the timer has nothing to count down, none while it is not running --
			BorderSetColor(timer.border, WWTB.SV[timer.colorKey])
			if state == STATE_EMPTY then BorderHide(timer.border) else BorderSet(timer.border, 1) end
		end
		return
	end
	if timer.state ~= STATE_COUNTING then
		timer.state, timer.lastMax, timer.textKey = STATE_COUNTING, nil, nil
		timer.sweepEnd = nil
		timer.icon:SetAlpha(1)
	end
	-- Start the clock wipe when the countdown starts or the effect is applied again --
	if timer.sweepEnd ~= endTime then
		timer.sweepEnd = endTime
		StartSweep(timer.sweep, remaining, duration)
	end
	-- The range only changes when the effect is applied again --
	if timer.lastMax ~= duration then
		timer.lastMax = duration
		timer.bar:SetMinMax(0, duration)
	end
	timer.bar:SetValue(remaining)
	if timer.useBorder then
		BorderSetColor(timer.border, WWTB.SV[timer.colorKey])
		BorderSet(timer.border, remaining / duration)
	end
	-- Only rebuild the text when the displayed value changes --
	local key = WWTB.SV.ShowBarTimers and CountdownKey(remaining) or false
	if key ~= timer.textKey then
		timer.textKey = key
		timer.timeLabel:SetText(key and CountdownText(remaining) or "")
	end
end

-- Show/hide each timer row, size the window to the visible rows, and update the countdowns --
function WWTB.RefreshBuffTimers()
	if not buffTimersReady then return end
	local now = GetGameTimeSeconds()
	local inWerewolfForm = IsPlayerInWerewolfForm()
	local inCombat = IsUnitInCombat("player")
	local sv = WWTB.SV
	local anyCounting = false
	local rows = 0
	local iconsOnly = sv.BuffIconsOnly
	local layoutKey = 0 -- One bit per visible row, so a change in the visible rows is a change in the number --
	for i, timer in ipairs(buffTimers) do
		-- Expired --
		if timer.active and timer.duration > 0 and timer.endTime <= now then
			timer.active = false
		end
		local enabled = sv[timer.enabledKey]
		-- Running timers show in werewolf form. "Always Show" keeps every enabled timer visible, and --
		-- the combat option keeps Frenzy & Courage visible while in combat (only when running outside it) --
		local live = enabled and inWerewolfForm and timer.active
		local always = enabled and inWerewolfForm and (sv.BuffsAlwaysShow or (timer.showInCombat and sv.BuffsShowInCombat and inCombat))
		-- Live timers, always-shown timers, or all three timers in the UI preview (even disabled ones) --
		timer.shown = (not buffTimersSuppressed) and (showUI or live or always) and true or false
		if timer.shown then
			rows = rows + 1
			layoutKey = layoutKey + 2 ^ (i - 1)
			UpdateBuffTimer(timer, now)
		end
		-- The preview counts down too --
		if timer.shown and (showUI or (timer.active and timer.duration > 0)) then anyCounting = true end
	end
	-- Only redo the layout when the set of visible rows changes --
	if layoutKey ~= buffLayoutKey then
		buffLayoutKey = layoutKey
		local previous
		local windowWidth, windowHeight
		-- The window itself (the outline in Edit HUD) is always the size of all three rows or icons --
		local fullWidth, fullHeight
		-- Hidden rows are drawn again from scratch when they come back --
		for _, timer in ipairs(buffTimers) do
			timer.icon:SetHidden(not timer.shown)
			timer.bar:SetHidden(not timer.shown or iconsOnly)
			timer.nameLabel:SetHidden(not timer.shown or iconsOnly)
			timer.timeLabel:SetHidden(not timer.shown)
			if not timer.shown then
				BorderHide(timer.border)
				timer.state = nil
				if timer.sweepEnd ~= nil then
					timer.sweepEnd = nil
					ClearSweep(timer.sweep)
				end
			elseif not iconsOnly then
				-- Stack the visible rows from the top of the window --
				timer.icon:ClearAnchors()
				if previous then
					timer.icon:SetAnchor(TOPLEFT, previous.icon, BOTTOMLEFT, 0, 0)
				else
					timer.icon:SetAnchor(TOPLEFT, buffBackdrop, TOPLEFT, 5, 5)
				end
				previous = timer
			end
		end
		if iconsOnly then
			-- Icons only: the visible icons in a row or column --
			local margin = sv.BuffIconBorder and ClampThickness(sv.BuffIconBorderThickness) or 0
			local list = {}
			for _, timer in ipairs(buffTimers) do
				if timer.shown then list[#list + 1] = { icon = timer.icon, margin = margin } end
			end
			local iconSize = ClampIconSize(sv.BuffIconSize)
			local contentWidth, contentHeight = PlaceIcons(list, iconSize, sv.BuffIconLayout == LAYOUT_VERTICAL, buffBackdrop, 5, 5)
			windowWidth = contentWidth + 10
			windowHeight = contentHeight + 10
			local count = #buffTimers
			local cell = iconSize + 2 * margin
			local length = count * cell + (count - 1) * ICON_GAP + 10
			if sv.BuffIconLayout == LAYOUT_VERTICAL then
				fullWidth, fullHeight = cell + 10, length
			else
				fullWidth, fullHeight = length, cell + 10
			end
		else
			windowWidth = WWTB.SV.BuffBarWidth + 10
			windowHeight = zo_max((WWTB.SV.BuffBarHeight * rows) + 10, 30)
			fullWidth = windowWidth
			fullHeight = zo_max((WWTB.SV.BuffBarHeight * #buffTimers) + 10, 30)
		end
		-- The backdrop only covers the rows being shown --
		buffWindow:SetDimensions(fullWidth, fullHeight)
		buffBackdrop:SetDimensions(windowWidth, windowHeight)
		WWTB.PlacePreviewWindows()
	end
	buffWindow:SetHidden(rows == 0)
	-- Only run the update loop while something is counting down --
	if anyCounting and not buffUpdateRunning then
		buffUpdateRunning = true
		EVENT_MANAGER:RegisterForUpdate(BUFF_UPDATE_NAME, 100, WWTB.RefreshBuffTimers)
	elseif not anyCounting and buffUpdateRunning then
		buffUpdateRunning = false
		EVENT_MANAGER:UnregisterForUpdate(BUFF_UPDATE_NAME)
	end
end

local function MakeBuffHandler(timer)
	-- Filtered to the player and the ability id when registered, so no checks are needed here --
	return function(_, changeType, _, _, _, beginTime, endTime)
		if changeType == EFFECT_RESULT_FADED then
			timer.active = false
			timer.endTime = 0
			timer.duration = 0
		else
			timer.active = true
			timer.endTime = endTime
			timer.duration = endTime - beginTime
		end
		WWTB.RefreshBuffTimers()
	end
end

-- Pick up effects already running (after a reload, or when porting) --
function WWTB.ScanBuffTimers()
	if not buffTimersReady then return end
	for _, timer in ipairs(buffTimers) do
		timer.active = false
		timer.endTime = 0
		timer.duration = 0
	end
	for i = 1, GetNumBuffs("player") do
		local _, timeStarted, timeEnding, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
		for _, timer in ipairs(buffTimers) do
			if timer.abilityId == abilityId then
				timer.active = true
				timer.endTime = timeEnding
				timer.duration = timeEnding - timeStarted
			end
		end
	end
	WWTB.RefreshBuffTimers()
end

-- Buff events are only registered while they can matter: --
-- the effect events for each enabled timer while transformed, the combat event only for the combat option --
local COMBAT_EVENT_NAME = WWTB.Name .. "_BuffCombat"
local combatEventOn = false

function WWTB.UpdateBuffEvents()
	if not buffTimersReady then return end
	local inForm = IsPlayerInWerewolfForm()
	local newlyOn = false
	for _, timer in ipairs(buffTimers) do
		local eventName = WWTB.Name .. "_Buff_" .. timer.key
		local want = inForm and WWTB.SV[timer.key .. "Enabled"] and true or false
		if want and not timer.eventOn then
			EVENT_MANAGER:RegisterForEvent(eventName, EVENT_EFFECT_CHANGED, timer.handler)
			EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, 'player', REGISTER_FILTER_ABILITY_ID, timer.abilityId)
			timer.eventOn = true
			newlyOn = true
		elseif not want and timer.eventOn then
			EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_EFFECT_CHANGED)
			timer.eventOn = false
			-- Nothing is tracking this effect any more --
			timer.active = false
			timer.endTime = 0
			timer.duration = 0
		end
	end
	-- Combat state only matters for the Frenzy and Courage combat option --
	local wantCombat = inForm and WWTB.SV.BuffsShowInCombat and not WWTB.SV.BuffsAlwaysShow
		and (WWTB.SV.CourageEnabled or WWTB.SV.FrenzyEnabled) and true or false
	if wantCombat and not combatEventOn then
		EVENT_MANAGER:RegisterForEvent(COMBAT_EVENT_NAME, EVENT_PLAYER_COMBAT_STATE, function() WWTB.RefreshBuffTimers() end)
		combatEventOn = true
	elseif not wantCombat and combatEventOn then
		EVENT_MANAGER:UnregisterForEvent(COMBAT_EVENT_NAME, EVENT_PLAYER_COMBAT_STATE)
		combatEventOn = false
	end
	-- Pick up effects that started while a timer was not being tracked, and refresh the rows --
	if newlyOn then
		WWTB.ScanBuffTimers()
	else
		WWTB.RefreshBuffTimers()
	end
end

function WWTB.SetupBuffTimers()
	WWTB.SetupBuffTimerUI()
	for _, timer in ipairs(buffTimers) do
		timer.handler = MakeBuffHandler(timer)
		timer.eventOn = false
	end
	WWTB.UpdateBuffEvents()
end

-------------------------------------------------------------------------------------------------
--  Roar range icon: players in range of Major Courage from Ferocious Roar --
-------------------------------------------------------------------------------------------------
-- Shown only while Ferocious Roar is on the action bar. The number is the group members (and you) --
-- close enough to be hit by the Roar, up to the 12 it can reach --
local ROAR_IDS = { [39113] = true } -- Ferocious Roar ability id; the English name is also checked below --
local ROAR_NAME = "ferocious roar"
local ROAR_MAX_PLAYERS = 12
local ROAR_RANGE_CM = 1000 -- Roar radius, 10 metres (world positions are in centimetres) --
local ROAR_ICON_ID = 39113 -- Ferocious Roar icon --
local COURAGE_ID = 109966 -- Major Courage --
local ROLES_ALL, ROLES_DPS, ROLES_DPS_HEAL = "All", "Only DPS", "DPS & Healers"
-- Is a group role counted, with the current setting? --
local function RoleCounted(role)
	local mode = WWTB.SV.RoarRoles
	if mode == ROLES_DPS then return role == LFG_ROLE_DPS end
	if mode == ROLES_DPS_HEAL then return role == LFG_ROLE_DPS or role == LFG_ROLE_HEAL end
	return true
end
local ROAR_FIRST_SLOT, ROAR_LAST_SLOT = 3, 7
local ROAR_UPDATE_NAME = WWTB.Name .. "_RoarRange"
local ROAR_UPDATE_MS = 250
local roarWindow, roarIcon, roarCount
local roarBorder, roarSweep, roarBorderOn
local roarSweepEnd
local roarSlotted = false
local roarRunning = false
local roarLastCount

local function IsRoarSlotted()
	for slot = ROAR_FIRST_SLOT, ROAR_LAST_SLOT do
		local id = GetSlotBoundId(slot)
		if id and id > 0 then
			if ROAR_IDS[id] then return true end
			if zo_strlower(GetAbilityName(id) or "") == ROAR_NAME then return true end
		end
	end
	return false
end

-- Does the unit have Major Courage? Also returns when it ends and how long it lasts --
local function GetCourage(tag)
	for i = 1, GetNumBuffs(tag) do
		local _, started, ending, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo(tag, i)
		if abilityId == COURAGE_ID then return true, ending, ending - started end
	end
	return false
end

-- Who has Major Courage, kept up to date by the effect event instead of reading every buff of every --
-- group member on each refresh. Keyed by unit tag ("player", "group1" ...), and rebuilt when the group changes --
local roarCourage = {}
local roarOwnEnd, roarOwnDuration = nil, nil -- The player's own Major Courage --
local ROAR_RESYNC_NAME = WWTB.Name .. "_RoarResync"
local ROAR_RESYNC_MS = 5000 -- A safety net while the icon is visible, in case an effect event was missed --

local function ResyncCourage()
	roarCourage = {}
	roarOwnEnd, roarOwnDuration = nil, nil
	local has, ending, duration = GetCourage("player")
	if has then
		roarCourage.player = true
		roarOwnEnd, roarOwnDuration = ending, duration
	end
	for i = 1, GetGroupSize() do
		local tag = GetGroupUnitTagByIndex(i)
		if tag and GetCourage(tag) then roarCourage[tag] = true end
	end
end

-- Two registrations, both filtered to Major Courage by ability id: one for the player and one for unit tags --
-- starting with "group". Nothing else reaches these, so there are no checks inside --
local function OnOwnCourage(_, changeType, _, _, _, beginTime, endTime)
	if changeType == EFFECT_RESULT_FADED then
		roarCourage.player = nil
		roarOwnEnd, roarOwnDuration = nil, nil
	else
		roarCourage.player = true
		roarOwnEnd, roarOwnDuration = endTime, endTime - beginTime
	end
end

local function OnGroupCourage(_, changeType, _, _, unitTag)
	roarCourage[unitTag] = changeType ~= EFFECT_RESULT_FADED or nil
end

-- Only members that are online and within group range (the ones the default group frame does not dim) are counted. --
-- In one pass: members with Major Courage, members within the Roar radius (counting the player), --
-- the number of members counted, and the player's own Major Courage end time and duration --
local function ScanRoarGroup()
	local buffed, inRange, total = 0, 0, 0
	local hasOwn, ownEnd, ownDuration = roarCourage.player, roarOwnEnd, roarOwnDuration
	-- The player counts too, unless the player's own role is not counted --
	if RoleCounted(GetSelectedLFGRole()) then
		total, inRange = 1, 1
		if hasOwn then buffed = 1 end
	end
	local zone, px, py, pz
	if GetUnitRawWorldPosition then zone, px, py, pz = GetUnitRawWorldPosition("player") end
	local rangeSq = ROAR_RANGE_CM * ROAR_RANGE_CM
	for i = 1, GetGroupSize() do
		local tag = GetGroupUnitTagByIndex(i)
		if tag and not AreUnitsEqual(tag, "player") and IsUnitOnline(tag)
			and (not IsUnitInGroupSupportRange or IsUnitInGroupSupportRange(tag))
			and RoleCounted(GetGroupMemberSelectedRole(tag)) then
			total = total + 1
			if roarCourage[tag] then buffed = buffed + 1 end
			if px and not IsUnitDead(tag) then
				local z, x, y, zz = GetUnitRawWorldPosition(tag)
				if z == zone and x then
					local dx, dy, dz = x - px, y - py, zz - pz
					if dx * dx + dy * dy + dz * dz <= rangeSq then inRange = inRange + 1 end
				end
			end
		end
	end
	return buffed, zo_min(inRange, ROAR_MAX_PLAYERS), total, ownEnd, ownDuration
end

-- Size, font and icon --
function WWTB.SetupRoarUI()
	roarWindow = roarWindow or WerewolfTimerBarRoar
	roarIcon = roarIcon or WerewolfTimerBarRoar_Icon
	roarCount = roarCount or WerewolfTimerBarRoar_Count
	roarBorder = roarBorder or NewBorder(roarWindow, "WerewolfTimerBarRoarBorder")
	roarSweep = roarSweep or NewSweep(roarWindow, "WerewolfTimerBarRoarSweep", roarIcon)
	local sv = WWTB.SV
	local size = ClampIconSize(sv.RoarIconSize)
	roarBorderOn = sv.RoarBorder and true or false
	local thickness = ClampThickness(sv.RoarBorderThickness)
	-- The window (the outline in Edit HUD) includes the space the border needs around the icon --
	local margin = roarBorderOn and thickness or 0
	roarWindow:SetDimensions(size + 2 * margin, size + 2 * margin)
	roarIcon:SetDimensions(size, size)
	roarIcon:ClearAnchors()
	roarIcon:SetAnchor(TOPLEFT, roarWindow, TOPLEFT, margin, margin)
	roarIcon:SetTexture(GetAbilityIcon(ROAR_ICON_ID))
	BorderAttach(roarBorder, roarIcon, size, thickness)
	-- "members with Major Courage / members in range", centred in the icon --
	roarCount:SetFont(WWTB.GetFontString("Roar"))
	roarCount:ClearAnchors()
	roarCount:SetAnchor(CENTER, roarIcon, CENTER, 0, 0)
	roarCount:SetDrawLayer(DL_TEXT)
	roarCount:SetDrawLevel(3) -- Above the clock wipe (1) and the border (2) --
	roarCount:SetDrawTier(DT_MEDIUM)
	roarSweepEnd = nil
	ClearSweep(roarSweep)
	roarLastCount = nil
end

function WWTB.RefreshRoar()
	if not roarWindow then return end
	local shown = showUI or (WWTB.SV.RoarEnabled and roarSlotted and not buffTimersSuppressed
		and IsPlayerInWerewolfForm() and IsUnitGrouped("player"))
	if shown then
		local now = GetGameTimeSeconds()
		local buffed, inRange, total, ownEnd, ownDuration = ScanRoarGroup()
		local key = buffed * 100 + inRange
		if key ~= roarLastCount then
			roarLastCount = key
			roarCount:SetText(buffed .. "/" .. inRange)
		end
		-- The clock wipe counts down the player's own Major Courage (the preview counts down from 20) --
		local endTime, duration = ownEnd, ownDuration
		if showUI then endTime, duration = PreviewCycleEnd(now), PREVIEW_CYCLE end
		if endTime and duration and duration > 0 and endTime > now then
			if roarSweepEnd ~= endTime then
				roarSweepEnd = endTime
				StartSweep(roarSweep, endTime - now, duration)
			end
		elseif roarSweepEnd ~= nil then
			roarSweepEnd = nil
			ClearSweep(roarSweep)
		end
		-- The border fills with the share of the group that has Major Courage --
		if roarBorderOn then
			BorderSetColor(roarBorder, WWTB.SV.RoarBorderColor)
			if showUI then
				BorderSet(roarBorder, (PreviewCycleEnd(now) - now) / PREVIEW_CYCLE)
			else
				BorderSet(roarBorder, total > 0 and buffed / total or 0)
			end
		else
			BorderHide(roarBorder)
		end
	elseif roarSweepEnd ~= nil then
		roarSweepEnd = nil
		ClearSweep(roarSweep)
	end
	if roarWindow:IsHidden() == shown then
		roarWindow:SetHidden(not shown)
		WWTB.PlacePreviewWindows()
	end
	-- Only poll while the icon is visible --
	if shown and not roarRunning then
		roarRunning = true
		EVENT_MANAGER:RegisterForUpdate(ROAR_UPDATE_NAME, ROAR_UPDATE_MS, WWTB.RefreshRoar)
		EVENT_MANAGER:RegisterForUpdate(ROAR_RESYNC_NAME, ROAR_RESYNC_MS, ResyncCourage)
	elseif not shown and roarRunning then
		roarRunning = false
		EVENT_MANAGER:UnregisterForUpdate(ROAR_UPDATE_NAME)
		EVENT_MANAGER:UnregisterForUpdate(ROAR_RESYNC_NAME)
		roarLastCount = nil
	end
end

local function OnRoarSlotsChanged()
	roarSlotted = IsRoarSlotted()
	WWTB.RefreshRoar()
end

-- Unit tags are reassigned when the group changes, so who has Major Courage is read again --
local function OnRoarGroupChanged()
	ResyncCourage()
	WWTB.RefreshRoar()
end

-- Slot events are only needed while the option is on --
function WWTB.UpdateRoarEvents()
	local names = {
		{ "_RoarSlot", EVENT_ACTION_SLOT_UPDATED, OnRoarSlotsChanged },
		{ "_RoarBar", EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, OnRoarSlotsChanged },
		{ "_RoarAll", EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, OnRoarSlotsChanged },
		{ "_RoarGroup", EVENT_GROUP_UPDATE, OnRoarGroupChanged },
		{ "_RoarJoin", EVENT_GROUP_MEMBER_JOINED, OnRoarGroupChanged },
		{ "_RoarLeft", EVENT_GROUP_MEMBER_LEFT, OnRoarGroupChanged },
		{ "_RoarConn", EVENT_GROUP_MEMBER_CONNECTED_STATUS, OnRoarGroupChanged },
	}
	for _, entry in ipairs(names) do
		local eventName = WWTB.Name .. entry[1]
		if WWTB.SV.RoarEnabled then
			EVENT_MANAGER:RegisterForEvent(eventName, entry[2], entry[3])
		else
			EVENT_MANAGER:UnregisterForEvent(eventName, entry[2])
		end
	end
	-- Major Courage on the player and the group, from the effect event only --
	local courageEvent = WWTB.Name .. "_RoarCourage"
	if WWTB.SV.RoarEnabled then
		EVENT_MANAGER:RegisterForEvent(courageEvent .. "Own", EVENT_EFFECT_CHANGED, OnOwnCourage)
		EVENT_MANAGER:AddFilterForEvent(courageEvent .. "Own", EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, COURAGE_ID, REGISTER_FILTER_UNIT_TAG, 'player')
		EVENT_MANAGER:RegisterForEvent(courageEvent .. "Group", EVENT_EFFECT_CHANGED, OnGroupCourage)
		EVENT_MANAGER:AddFilterForEvent(courageEvent .. "Group", EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, COURAGE_ID, REGISTER_FILTER_UNIT_TAG_PREFIX, 'group')
		roarSlotted = IsRoarSlotted()
		ResyncCourage()
	else
		EVENT_MANAGER:UnregisterForEvent(courageEvent .. "Own", EVENT_EFFECT_CHANGED)
		EVENT_MANAGER:UnregisterForEvent(courageEvent .. "Group", EVENT_EFFECT_CHANGED)
		roarSlotted = false
		roarCourage = {}
		roarOwnEnd, roarOwnDuration = nil, nil
	end
	WWTB.RefreshRoar()
end

-------------------------------------------------------------------------------------------------
--  Edit HUD Registration --
-------------------------------------------------------------------------------------------------
-- Must be called from EVENT_ADD_ON_LOADED (registering later does not apply anchors/options) --
function WWTB.SetupHudEditor()
	local elementName = "Werewolf Timer Bar"
	-- Offsets saved by the old drag system become the default position (migration) --
	-- Once the player moves the bar in Edit HUD, the saved HUD position overrides this --
	local function DefaultAnchor()
		return ZO_Anchor:New(TOPLEFT, nil, TOPLEFT, WWTB.SV.BarOffsetX, WWTB.SV.BarOffsetY)
	end
	-- No custom options (empty table) --
	local options = {}
	WWTB.keyboardHUDElement = HUD_MANAGER:RegisterKeyboardElement(window, elementName, { defaultAnchor = DefaultAnchor() }, options)
	WWTB.gamepadHUDElement = HUD_MANAGER:RegisterGamepadElement(window, elementName, { defaultAnchor = DefaultAnchor() }, options)
	-- Buff timers element --
	local timerElementName = "Werewolf Timer Bar - Buffs"
	local function TimerDefaultAnchor()
		return ZO_Anchor:New(TOPLEFT, nil, TOPLEFT, 0, 0)
	end
	HUD_MANAGER:RegisterKeyboardElement(buffWindow, timerElementName, { defaultAnchor = TimerDefaultAnchor() }, {})
	HUD_MANAGER:RegisterGamepadElement(buffWindow, timerElementName, { defaultAnchor = TimerDefaultAnchor() }, {})
	-- Roar range icon element --
	local roarElementName = "Werewolf Timer Bar - Roar Range"
	local function RoarDefaultAnchor()
		return ZO_Anchor:New(TOPLEFT, nil, TOPLEFT, 0, 0)
	end
	HUD_MANAGER:RegisterKeyboardElement(roarWindow, roarElementName, { defaultAnchor = RoarDefaultAnchor() }, {})
	HUD_MANAGER:RegisterGamepadElement(roarWindow, roarElementName, { defaultAnchor = RoarDefaultAnchor() }, {})
end

-------------------------------------------------------------------------------------------------
--  Keep the preview windows clear of the settings panel --
-------------------------------------------------------------------------------------------------
-- The windows are moved beside the panel (centred vertically on it) while previewing, and put back afterwards --
-- Only the anchor is changed, the position saved by Edit HUD is not touched --
local PREVIEW_GAP = 10
local previewOriginal = {} -- control = its anchor before the preview moved it --
local previewPending = false

local function SetPreviewTopmost(topmost)
	window:SetTopmost(topmost)
	buffWindow:SetTopmost(topmost)
	roarWindow:SetTopmost(topmost)
end

local function PlacePreviewNow()
	previewPending = false
	local panel = WWTB.optionsPanel
	if not showUI or not panel or panel:IsHidden() then return end
	local pl, pt, pr, pb = panel:GetLeft(), panel:GetTop(), panel:GetRight(), panel:GetBottom()
	if not (pl and pr and pr > pl and pb > pt) then return end
	-- The visible windows, stacked in one column --
	local controls, widest, totalHeight = {}, 0, 0
	for _, control in ipairs({ window, buffWindow, roarWindow }) do
		if not control:IsHidden() then
			local width, height = control:GetDimensions()
			controls[#controls + 1] = { control = control, width = width, height = height }
			widest = zo_max(widest, width)
			totalHeight = totalHeight + height
		end
	end
	if #controls == 0 then return end
	totalHeight = totalHeight + (#controls - 1) * PREVIEW_GAP
	-- To the right of the panel when there is room, otherwise to the left --
	local onRight
	if pr + PREVIEW_GAP + widest <= GuiRoot:GetWidth() then
		onRight = true
	elseif pl - PREVIEW_GAP - widest >= 0 then
		onRight = false
	else
		-- No room beside the panel, so they stay where they are and must draw above it --
		SetPreviewTopmost(true)
		return
	end
	-- Beside the panel on the right nothing covers them, so they stay below pop-ups such as the colour picker --
	SetPreviewTopmost(not onRight)
	-- Centred vertically on the panel --
	local y = (pt + pb) / 2 - totalHeight / 2
	for _, entry in ipairs(controls) do
		local control = entry.control
		if not previewOriginal[control] then
			local _, point, relativeTo, relativePoint, offsetX, offsetY = control:GetAnchor(0)
			previewOriginal[control] = { point, relativeTo, relativePoint, offsetX, offsetY }
		end
		local x = onRight and (pr + PREVIEW_GAP) or (pl - PREVIEW_GAP - entry.width)
		control:ClearAnchors()
		control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
		y = y + entry.height + PREVIEW_GAP
	end
end

-- Positions are only worked out by the game on the next frame after a window is shown or resized, --
-- so the check waits a moment. Calls close together are one check --
function WWTB.PlacePreviewWindows()
	if not showUI or previewPending then return end
	previewPending = true
	zo_callLater(PlacePreviewNow, 50)
end

local function RestorePreviewWindows()
	for control, anchor in pairs(previewOriginal) do
		control:ClearAnchors()
		control:SetAnchor(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5])
	end
	previewOriginal = {}
end

-------------------------------------------------------------------------------------------------
--  UI Preview --
-------------------------------------------------------------------------------------------------
-- Shows the main window and all three buff timers (filled) above the menu, so they can be positioned, --
-- or puts everything back to normal --
function WWTB.SetUIPreview(show)
	showUI = show
	if show then
		-- The settings menu hides the HUD, which also suppresses the buff timers, so lift that for the preview --
		buffTimersSuppressed = false
		WWTB.ShowHide()
		WWTB.RefreshBuffTimers()
		WWTB.RefreshRoar()
		WWTB.PlacePreviewWindows()
		-- The Rampage preview counts down on its own timer, as no real Rampage is running --
		EVENT_MANAGER:RegisterForUpdate(PREVIEW_UPDATE_NAME, 50, WWTB.RefreshRampage)
	else
		EVENT_MANAGER:UnregisterForUpdate(PREVIEW_UPDATE_NAME)
		-- Windows go back to where they were before the preview moved them --
		RestorePreviewWindows()
		-- Back to normal: work out again whether the current scene hides the HUD, then show or hide to suit --
		WWTB.OnReticleHidden(nil, IsReticleHidden())
	end
	-- Only drawn above the menu when placed on its left or left in place, see PlacePreviewNow --
	if not show then SetPreviewTopmost(false) end
end

-------------------------------------------------------------------------------------------------
--  Settings Panel Setup Function --
-------------------------------------------------------------------------------------------------
function WWTB.SetupSettingsWindow()
	local panelData = {
		type = "panel",
		name = "Werewolf Timer Bar",
		displayName = "Werewolf Timer Bar",
		author = "PhnxZ",
		version = string.format("%s", WWTB.Version),
		slashCommand = "/wwtbar",
		registerForRefresh = true,
		registerForDefaults = true,
		resetFunc = function()
			WWTB.SetupUIElements()
		end,
	}
	local cntrlOptionsPanel = LAM2:RegisterAddonPanel("Werewolf_Timer_Bar", panelData)
	WWTB.optionsPanel = cntrlOptionsPanel
	-- Turn the preview off when the settings panel closes, if it was not already turned off with the button --
	-- Show the UI preview as soon as this addon's panel is shown --
	CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panel)
		if panel == cntrlOptionsPanel and not showUI then
			WWTB.SetUIPreview(true)
		end
	end)
	CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(panel)
		if showUI and panel and (panel == cntrlOptionsPanel or panel.data == panelData) then
			WWTB.SetUIPreview(false)
		end
	end)
	
	local optionsData = {
		{
			type = "description",
			text = "This addon contains status bars and prevention from using your ultimate when in werewolf form."
		},
		{
			type = "description",
			text = "Original addon design by maximoz."
		},
		{
			type = "header",
			name = "General Settings"
		},
		{
			type = "description",
			text = "The Werewolf Timer Bar and Buff Timer windows are moved by the base game 'Edit HUD' interface. They are shown beside this panel while it is open, so you can preview them."
		},
		{
			type = "description",
			text = "Note that keyboard and gamepad positions are set separately (Gameplay -> Gamepad mode -> on/off). 'Automatic' will not work for setting gamepad location, but can be used afterwards"
		},
		-- Account-wide/Characters settings --
		WWTB.SV:GetLibAddonMenuAccountCheckbox(),
		-- Section enables --
		{
			type = "submenu",
			name = "Ultimate block",
			controls = {
				{
					type = "checkbox",
					name = "Hold / Double Press To Bypass Block",
					tooltip = "While the ultimate is locked, hold the ultimate button for the set time to cast it anyway (keyboard). On gamepad the ultimate can not be timed while held, so press it a second time within the set time of the blocked press instead",
					width = "half",
					default = WWTB.Default.HoldBypassEnabled,
					getFunc = function() return WWTB.SV.HoldBypassEnabled end,
					setFunc = function(value)
						WWTB.SV.HoldBypassEnabled = value
						-- Close a gamepad double press window that is still open --
						if not value then StopDoublePress() end
					end
				},
				{
					type = "slider",
					name = "Hold Time / Double Press Time (ms)",
					tooltip = "Keyboard: how long the ultimate button must be held to bypass the lock. Gamepad: how long after the blocked press a second press is let through",
					width = "half",
					min = 250,
					max = 3000,
					step = 50,
					default = WWTB.Default.HoldBypassTime,
					disabled = function() return not WWTB.SV.HoldBypassEnabled end,
					getFunc = function() return WWTB.SV.HoldBypassTime end,
					setFunc = function(value)
						WWTB.SV.HoldBypassTime = value
					end
				},
				{
					type = "colorpicker",
					name = "Bypass Bar Color",
					width = "half",
					tooltip = "Changes the color of the bar shown while holding the ultimate button (keyboard), or while the double press window is open (gamepad)",
					default = ZO_ColorDef:New(unpack(WWTB.Default.HoldBarColor)),
					disabled = function() return not WWTB.SV.HoldBypassEnabled end,
					getFunc = function() return unpack(WWTB.SV.HoldBarColor) end,
					setFunc = function(r,g,b,a)
						WWTB.SV.HoldBarColor = {r, g, b, a}
					end,
				},
				{
					type = "checkbox",
					name = "Only Lock Ultimate In Combat",
					tooltip = "Only lock ultimate ability use when in combat",
					width = "half",
					default = WWTB.Default.BlockInCombatOnly,
					getFunc = function() return WWTB.SV.BlockInCombatOnly end,
					setFunc = function(value)
						WWTB.SV.BlockInCombatOnly = value
					end
				},
				{
					type = "checkbox",
					name = "CSA & Chat Messages",
					tooltip = "Show Center Screen Announcements and chat messages",
					width = "half",
					default = not WWTB.Default.HideCSA,
					getFunc = function() return not WWTB.SV.HideCSA end,
					setFunc = function(value)
						WWTB.SV.HideCSA = not value
					end
				},
			},
		},
		-- Bar settings --
		{
			type = "submenu",
			name = "Main Window",
			controls = {
				{
					type = "checkbox",
					name = "Icons Only Mode",
					tooltip = "Show only the Ultimate and Fury icons instead of bars. The bar numbers option puts the numbers inside the icons",
					width = "half",
					default = WWTB.Default.IconsOnly,
					disabled = function() return not WWTB.SV.ShowTimer and not WWTB.SV.ShowFury end,
					getFunc = function() return WWTB.SV.IconsOnly end,
					setFunc = function(value)
						WWTB.SV.IconsOnly = value
						WWTB.SetupUIElements()
					end,
				},
				{
					type = "dropdown",
					name = "Icon Layout",
					tooltip = "Lay the Ultimate and Fury icons out in a row or a column",
					choices = { LAYOUT_HORIZONTAL, LAYOUT_VERTICAL },
					width = "half",
					default = WWTB.Default.IconLayout,
					disabled = function() return not WWTB.SV.IconsOnly end,
					getFunc = function() return WWTB.SV.IconLayout end,
					setFunc = function(value)
						WWTB.SV.IconLayout = value
						WWTB.SetupUIElements()
					end,
				},
				{
					type = "checkbox",
					name = "Icon Border Enabled",
					tooltip = "Draw a border around each icon in the bar's colour, that fills/empties as the bar does. The Fury icon gets a second border just inside the first that counts down Rampage while it is active",
					width = "half",
					default = WWTB.Default.IconBorder,
					disabled = function() return not WWTB.SV.IconsOnly end,
					getFunc = function() return WWTB.SV.IconBorder end,
					setFunc = function(value)
						WWTB.SV.IconBorder = value
						WWTB.SetupUIElements()
					end,
				},
				{
					type = "slider",
					name = "Icon Border Thickness",
					tooltip = "Thickness of the icon borders, in pixels",
					width = "half",
					min = BORDER_MIN,
					max = BORDER_MAX,
					step = 1,
					default = WWTB.Default.IconBorderThickness,
					disabled = function() return not WWTB.SV.IconsOnly or not WWTB.SV.IconBorder end,
					getFunc = function() return WWTB.SV.IconBorderThickness end,
					setFunc = function(newValue)
						WWTB.SV.IconBorderThickness = newValue
						WWTB.SetupUIElements()
					end,
				},
				{
					type = "slider",
					name = "Icon Size",
					tooltip = "Size of the Ultimate and Fury icons in icons only mode",
					width = "half",
					min = ICON_SIZE_MIN,
					max = ICON_SIZE_MAX,
					step = 1,
					default = WWTB.Default.IconSize,
					disabled = function() return not WWTB.SV.IconsOnly end,
					getFunc = function() return WWTB.SV.IconSize end,
					setFunc = function(newValue)
						WWTB.SV.IconSize = newValue
						WWTB.SetupUIElements()
					end,
				},
				{
					type = "divider",
					width = "full",
					--height = 10, (optional)
					--alpha = 0.25, (optional)
				},
				{
					type = "checkbox",
					name = "Header Bar Enabled",
					width = "half",
					tooltip = "Show/hide header bar",
					default = WWTB.Default.ShowHeader,
					getFunc = function() return WWTB.SV.ShowHeader end,
					setFunc = function(value)
						WWTB.SV.ShowHeader = value
						WWTB.SetupUIElements()
					end
				},
				{
					type = "editbox",
					name = "Header Text",
					width = "half",
					tooltip = "Show/hide header text",
					default = WWTB.Default.HeaderText,
					disabled = function() return not WWTB.SV.ShowHeader or WWTB.SV.IconsOnly end,
					isMultiline = false,
					getFunc = function() return WWTB.SV.HeaderText end,
					setFunc = function(value)
						WWTB.SV.HeaderText = value
						WWTB.SetupUIElements()
					end
				},
				{
					type = "checkbox",
					name = "Ultimate Timer Bar Enabled",
					width = "half",
					tooltip = "Show bar for Ultimate timer",
					default = WWTB.Default.ShowTimer,
					getFunc = function() return WWTB.SV.ShowTimer end,
					setFunc = function(value)
						WWTB.SV.ShowTimer = value
						-- Register or unregister for updates, depending on what is still turned on --
						WWTB.UpdateEvents()
						WWTB.SetupUIElements()
						-- Start/stop power updates right away if already transformed --
						WWTB.OnWerewolfStateChanged()
					end
				},
				{
					type = "checkbox",
					name = "Fury Bar Enabled",
					width = "half",
					tooltip = "Show bar for Fury stacks",
					default = WWTB.Default.ShowFury,
					getFunc = function() return WWTB.SV.ShowFury end,
					setFunc = function(value)
						WWTB.SV.ShowFury = value
						-- Register or unregister for updates, depending on what is still turned on --
						WWTB.UpdateEvents()
						WWTB.SetupUIElements()
						-- Start/stop power updates right away if already transformed --
						WWTB.OnWerewolfStateChanged()
					end
				},
				{
					type = "checkbox",
					name = "Ultimate & Fury Bar Labels",
					tooltip = "Show text labels on Ultimate and Fury bars",
					width = "half",
					default = WWTB.Default.ShowBarLabels,
					disabled = function() return (not WWTB.SV.ShowTimer and not WWTB.SV.ShowFury) or WWTB.SV.IconsOnly end,
					getFunc = function() return WWTB.SV.ShowBarLabels end,
					setFunc = function(value)
						WWTB.SV.ShowBarLabels = value
						WWTB.SetupUIElements()
					end
				},
				{
					type = "checkbox",
					name = "Ultimate & Fury Numbers",
					tooltip = "Show numbers on Ultimate and Fury bars/icons",
					width = "half",
					default = WWTB.Default.ShowBarNumbers,
					disabled = function() return not WWTB.SV.ShowTimer and not WWTB.SV.ShowFury end,
					getFunc = function() return WWTB.SV.ShowBarNumbers end,
					setFunc = function(value)
						WWTB.SV.ShowBarNumbers = value
						WWTB.SetupUIElements()
					end
				},
				{
					type = "checkbox",
					name = "Rampage Timer",
					width = "half",
					tooltip = "Show a countdown bar/border over the Fury bar/icon while Rampage is active",
					default = WWTB.Default.RampageEnabled,
					disabled = function() return not WWTB.SV.ShowFury end,
					getFunc = function() return WWTB.SV.RampageEnabled end,
					setFunc = function(value)
						WWTB.SV.RampageEnabled = value
						-- Register or unregister the Rampage events, then redraw the Fury bar --
						WWTB.UpdateRampageEvents()
						WWTB.ShowHide()
					end
				},
				{
					type = "checkbox",
					name = "Rampage Timer Numbers",
					tooltip = "Show the Rampage countdown in place of the Fury number while Rampage is active",
					width = "half",
					default = WWTB.Default.ShowRampageTimer,
					disabled = function() return not WWTB.SV.ShowFury or not WWTB.SV.RampageEnabled end,
					getFunc = function() return WWTB.SV.ShowRampageTimer end,
					setFunc = function(value)
						WWTB.SV.ShowRampageTimer = value
						-- The Fury number returns when this is off --
						WWTB.RefreshRampage()
						WWTB.ShowHide()
					end
				},
				{
					type = "slider",
					name = "Ultimate & Fury Bar Width",
					tooltip = "Adjusts the width of the Ultimate and Fury bars",
					width = "half",
					min = 100,
					max = 300,
					step = 5,
					default = WWTB.Default.BarWidth,
					disabled = function() return (not WWTB.SV.ShowTimer and not WWTB.SV.ShowFury) or WWTB.SV.IconsOnly end,
					getFunc = function() return WWTB.SV.BarWidth end,
					setFunc = function(newValue) 
						WWTB.SV.BarWidth = newValue
						WWTB.SetupUIElements()
					end,
				},
				{
					type = "slider",
					name = "Ultimate & Fury Bar Height",
					tooltip = "Adjusts the height of the Ultimate and Fury bars",
					width = "half",
					min = 5,
					max = 50,
					step = 1,
					default = WWTB.Default.BarHeight,
					disabled = function() return (not WWTB.SV.ShowTimer and not WWTB.SV.ShowFury) or WWTB.SV.IconsOnly end,
					getFunc = function() return WWTB.SV.BarHeight end,
					setFunc = function(newValue) 
						WWTB.SV.BarHeight= newValue
						WWTB.SetupUIElements()
					end,
				},
				{
					type = "dropdown",
					name = "Font Name",
					tooltip = "Changes the font name",
					choices = {"MEDIUM_FONT", "BOLD_FONT", "CHAT_FONT", "ANTIQUE_FONT", "HANDWRITTEN_FONT", "STONE_TABLET_FONT", "GAMEPAD_MEDIUM_FONT", "GAMEPAD_BOLD_FONT"},
					width = "half",
					default = WWTB.Default.BarFontName,
					disabled = function() return not WWTB.IsFontInUse() end,
					getFunc = function() return WWTB.SV.BarFontName end,
					setFunc = function(newValue) 
						WWTB.SV.BarFontName= newValue
						WWTB.SetupUIElements()
					end,
				},
				{
					type = "dropdown",
					name = "Font Style",
					tooltip = "Changes the font style",
					choices = {"outline","thin-outline","thick-outline","shadow","soft-shadow-thin","soft-shadow-thick"},
					width = "half",
					default = WWTB.Default.BarFontStyle,
					disabled = function() return not WWTB.IsFontInUse() end,
					getFunc = function() return WWTB.SV.BarFontStyle end,
					setFunc = function(newValue) 
						WWTB.SV.BarFontStyle= newValue
						WWTB.SetupUIElements()
					end,
				},
				{
					type = "slider",
					name = "Font Size",
					tooltip = "Adjusts the font and header icon size",
					width = "half",
					min = 8,
					max = 48,
					step = 1,
					default = WWTB.Default.BarFontSize,
					disabled = function() return not WWTB.SV.ShowHeader and not WWTB.IsFontInUse() end,
					getFunc = function() return WWTB.SV.BarFontSize end,
					setFunc = function(newValue) 
						WWTB.SV.BarFontSize= newValue
						WWTB.SetupUIElements()
					end
				},
				{
					type = "divider",
					width = "full",
					--height = 10, (optional)
					--alpha = 0.25, (optional)
				},
				{
					type = "colorpicker",
					name = "Ultimate Timer Color",
					width = "half",
					tooltip = "Changes the color of the Timer bar/border",
					default = ZO_ColorDef:New(unpack(WWTB.Default.BarColor)),
					disabled = function() return not WWTB.SV.ShowTimer end,
					getFunc = function() return unpack(WWTB.SV.BarColor) end,
					setFunc = function(r,g,b,a) 
						WWTB.SV.BarColor = {r, g, b, a}
						WWTB.SetupUIElements()
					end,
				},
				{
					type = "colorpicker",
					name = "Fury Color",
					width = "half",
					tooltip = "Changes the color of the Fury bar/border",
					default = ZO_ColorDef:New(unpack(WWTB.Default.FuryBarColor)),
					disabled = function() return not WWTB.SV.ShowFury end,
					getFunc = function() return unpack(WWTB.SV.FuryBarColor) end,
					setFunc = function(r,g,b,a) 
						WWTB.SV.FuryBarColor = {r, g, b, a}
						WWTB.SetupUIElements()
					end,
				},
				{
					type = "colorpicker",
					name = "Fury Full/Rampage Color",
					width = "half",
					tooltip = "Changes the color of the Fury Full/Rampage bar/border",
					default = ZO_ColorDef:New(unpack(WWTB.Default.FuryBarMaxColor)),
					disabled = function() return not WWTB.SV.ShowFury end,
					getFunc = function() return unpack(WWTB.SV.FuryBarMaxColor) end,
					setFunc = function(r,g,b,a) 
						WWTB.SV.FuryBarMaxColor = {r, g, b, a}
						WWTB.SetupUIElements()
					end,
				},
				{
					type = "divider",
					width = "full",
					--height = 10, (optional)
					--alpha = 0.25, (optional)
				},
				-- Warning --
				{
					type = "checkbox",
					name = "Ultimate Low Warning Colors",
					tooltip = "Change the color of the Ultimate bar/border when it gets low",
					width = "half",
					default = WWTB.Default.WarningColor,
					disabled = function() return not WWTB.SV.ShowTimer end,
					getFunc = function() return WWTB.SV.WarningColor end,
					setFunc = function(value)
						WWTB.SV.WarningColor = value
						WWTB.SetupUIElements()
					end
				},
				{
					type = "slider",
					name = "Warning Level",
					tooltip = "Set Warning level",
					width = "half",
					min = 100,
					max = 450,
					step = 10,
					default = WWTB.Default.WarningLevel,
					disabled = function() return not WWTB.SV.ShowTimer or not WWTB.SV.WarningColor end,
					getFunc = function() return WWTB.SV.WarningLevel end,
					setFunc = function(newValue) 
						WWTB.SV.WarningLevel = newValue
						WWTB.SetupUIElements()
					end
				},
				{
					type = "colorpicker",
					name = "Warning Level Color",
					width = "half",
					tooltip = "Changes the color of the Timer bar/border when below warning level",
					default = ZO_ColorDef:New(unpack(WWTB.Default.WarningBarColor)),
					disabled = function() return not WWTB.SV.ShowTimer or not WWTB.SV.WarningColor end,
					getFunc = function() return unpack(WWTB.SV.WarningBarColor) end,
					setFunc = function(r,g,b,a) 
						WWTB.SV.WarningBarColor = {r, g, b, a}
						WWTB.SetupUIElements()
					end
				},
				-- Critical --
				{
					type = "slider",
					name = "Critical Level",
					tooltip = "Set Critical level",
					width = "half",
					min = 0,
					max = 200,
					step = 10,
					default = WWTB.Default.CriticalLevel,
					disabled = function() return not WWTB.SV.ShowTimer or not WWTB.SV.WarningColor end,
					getFunc = function() return WWTB.SV.CriticalLevel end,
					setFunc = function(newValue) 
						WWTB.SV.CriticalLevel = newValue
						WWTB.SetupUIElements()
					end
				},
				{
					type = "colorpicker",
					name = "Critical Level Color",
					width = "half",
					tooltip = "Changes the color of the Timer bar/border when below Critical level",
					default = ZO_ColorDef:New(unpack(WWTB.Default.CriticalBarColor)),
					disabled = function() return not WWTB.SV.ShowTimer or not WWTB.SV.WarningColor end,
					getFunc = function() return unpack(WWTB.SV.CriticalBarColor) end,
					setFunc = function(r,g,b,a) 
						WWTB.SV.CriticalBarColor = {r, g, b, a}
						WWTB.SetupUIElements()
					end
				},
			},
		},
		{
			type = "submenu",
			name = "Buffs Window",
			controls = {
				{
					type = "description",
					text = "Separate buffs window, shown while you are a werewolf. Move in the base game 'Edit HUD' interface. Has its own font and bar size settings below."
				},
				{
					type = "checkbox",
					name = "Icons Only Mode",
					tooltip = "Show only the buff icons, in a row, instead of bars. Buff Bar Timers puts the timer numbers inside the icons",
					width = "half",
					default = WWTB.Default.BuffIconsOnly,
					disabled = function() return not WWTB.SV.CourageEnabled and not WWTB.SV.FrenzyEnabled and not WWTB.SV.ProwlEnabled end,
					getFunc = function() return WWTB.SV.BuffIconsOnly end,
					setFunc = function(value)
						WWTB.SV.BuffIconsOnly = value
						WWTB.SetupBuffTimerUI()
						WWTB.RefreshBuffTimers()
					end
				},
				{
					type = "checkbox",
					name = "Icon Border Enabled",
					tooltip = "Draw a border around each icon in the timer's colour, that empties clockwise as the timer counts down",
					width = "half",
					default = WWTB.Default.BuffIconBorder,
					disabled = function() return not WWTB.SV.BuffIconsOnly end,
					getFunc = function() return WWTB.SV.BuffIconBorder end,
					setFunc = function(value)
						WWTB.SV.BuffIconBorder = value
						WWTB.SetupBuffTimerUI()
						WWTB.RefreshBuffTimers()
					end
				},
				{
					type = "dropdown",
					name = "Icon Layout",
					tooltip = "Lay the buff icons out in a row or a column",
					choices = { LAYOUT_HORIZONTAL, LAYOUT_VERTICAL },
					width = "half",
					default = WWTB.Default.BuffIconLayout,
					disabled = function() return not WWTB.SV.BuffIconsOnly end,
					getFunc = function() return WWTB.SV.BuffIconLayout end,
					setFunc = function(value)
						WWTB.SV.BuffIconLayout = value
						WWTB.SetupBuffTimerUI()
						WWTB.RefreshBuffTimers()
					end
				},
				{
					type = "slider",
					name = "Icon Border Thickness",
					tooltip = "Thickness of the icon borders, in pixels",
					width = "half",
					min = BORDER_MIN,
					max = BORDER_MAX,
					step = 1,
					default = WWTB.Default.BuffIconBorderThickness,
					disabled = function() return not WWTB.SV.BuffIconsOnly or not WWTB.SV.BuffIconBorder end,
					getFunc = function() return WWTB.SV.BuffIconBorderThickness end,
					setFunc = function(newValue)
						WWTB.SV.BuffIconBorderThickness = newValue
						WWTB.SetupBuffTimerUI()
						WWTB.RefreshBuffTimers()
					end
				},
				{
					type = "slider",
					name = "Icon Size",
					tooltip = "Size of the buff icons in icons only mode",
					width = "half",
					min = ICON_SIZE_MIN,
					max = ICON_SIZE_MAX,
					step = 1,
					default = WWTB.Default.BuffIconSize,
					disabled = function() return not WWTB.SV.BuffIconsOnly end,
					getFunc = function() return WWTB.SV.BuffIconSize end,
					setFunc = function(newValue)
						WWTB.SV.BuffIconSize = newValue
						WWTB.SetupBuffTimerUI()
						WWTB.RefreshBuffTimers()
					end
				},
				{
					type = "divider",
					width = "full",
					--height = 10, (optional)
					--alpha = 0.25, (optional)
				},
				{
					type = "slider",
					name = "Buff Bar Width",
					tooltip = "Adjusts the width of the buff timer bars",
					width = "half",
					min = 100,
					max = 300,
					step = 5,
					default = WWTB.Default.BuffBarWidth,
					disabled = function() return (not WWTB.SV.CourageEnabled and not WWTB.SV.FrenzyEnabled and not WWTB.SV.ProwlEnabled) or WWTB.SV.BuffIconsOnly end,
					getFunc = function() return WWTB.SV.BuffBarWidth end,
					setFunc = function(newValue)
						WWTB.SV.BuffBarWidth = newValue
						WWTB.SetupBuffTimerUI()
						WWTB.RefreshBuffTimers()
					end
				},
				{
					type = "slider",
					name = "Buff Bar Height",
					tooltip = "Adjusts the height of the buff timer bars",
					width = "half",
					min = 5,
					max = 50,
					step = 1,
					default = WWTB.Default.BuffBarHeight,
					disabled = function() return (not WWTB.SV.CourageEnabled and not WWTB.SV.FrenzyEnabled and not WWTB.SV.ProwlEnabled) or WWTB.SV.BuffIconsOnly end,
					getFunc = function() return WWTB.SV.BuffBarHeight end,
					setFunc = function(newValue)
						WWTB.SV.BuffBarHeight = newValue
						WWTB.SetupBuffTimerUI()
						WWTB.RefreshBuffTimers()
					end
				},
				{
					type = "dropdown",
					name = "Font Name",
					tooltip = "Changes the font name for the buffs window",
					choices = {"MEDIUM_FONT", "BOLD_FONT", "CHAT_FONT", "ANTIQUE_FONT", "HANDWRITTEN_FONT", "STONE_TABLET_FONT", "GAMEPAD_MEDIUM_FONT", "GAMEPAD_BOLD_FONT"},
					width = "half",
					default = WWTB.Default.BuffFontName,
					disabled = function() return not WWTB.SV.CourageEnabled and not WWTB.SV.FrenzyEnabled and not WWTB.SV.ProwlEnabled end,
					getFunc = function() return WWTB.SV.BuffFontName end,
					setFunc = function(newValue)
						WWTB.SV.BuffFontName = newValue
						WWTB.SetupBuffTimerUI(); WWTB.RefreshBuffTimers()
					end,
				},
				{
					type = "dropdown",
					name = "Font Style",
					tooltip = "Changes the font style for the buffs window",
					choices = {"outline","thin-outline","thick-outline","shadow","soft-shadow-thin","soft-shadow-thick"},
					width = "half",
					default = WWTB.Default.BuffFontStyle,
					disabled = function() return not WWTB.SV.CourageEnabled and not WWTB.SV.FrenzyEnabled and not WWTB.SV.ProwlEnabled end,
					getFunc = function() return WWTB.SV.BuffFontStyle end,
					setFunc = function(newValue)
						WWTB.SV.BuffFontStyle = newValue
						WWTB.SetupBuffTimerUI(); WWTB.RefreshBuffTimers()
					end,
				},
				{
					type = "slider",
					name = "Font Size",
					tooltip = "Changes the font size for the buffs window",
					width = "half",
					min = 8,
					max = 48,
					step = 1,
					default = WWTB.Default.BuffFontSize,
					disabled = function() return not WWTB.SV.CourageEnabled and not WWTB.SV.FrenzyEnabled and not WWTB.SV.ProwlEnabled end,
					getFunc = function() return WWTB.SV.BuffFontSize end,
					setFunc = function(newValue)
						WWTB.SV.BuffFontSize = newValue
						WWTB.SetupBuffTimerUI(); WWTB.RefreshBuffTimers()
					end
				},
				{
					type = "checkbox",
					name = "Always Show Buff Timers",
					width = "half",
					tooltip = "Keep the enabled buff timers visible while you are a werewolf, even when the effect is not running. Timers that are not running show a dimmed icon and an empty bar",
					default = WWTB.Default.BuffsAlwaysShow,
					disabled = function() return not WWTB.SV.CourageEnabled and not WWTB.SV.FrenzyEnabled and not WWTB.SV.ProwlEnabled end,
					getFunc = function() return WWTB.SV.BuffsAlwaysShow end,
					setFunc = function(value)
						WWTB.SV.BuffsAlwaysShow = value
						WWTB.UpdateBuffEvents()
					end
				},
				{
					type = "checkbox",
					name = "Always Show Frenzy & Courage In Combat",
					width = "half",
					tooltip = "Keep the Feeding Frenzy and Major Courage timers visible while you are in combat, even when the effect is not running. Outside combat they only show while running. The Prowl timer is not affected. Not needed when Always Show Buff Timers is on",
					default = WWTB.Default.BuffsShowInCombat,
					disabled = function() return WWTB.SV.BuffsAlwaysShow or (not WWTB.SV.CourageEnabled and not WWTB.SV.FrenzyEnabled) end,
					getFunc = function() return WWTB.SV.BuffsShowInCombat end,
					setFunc = function(value)
						WWTB.SV.BuffsShowInCombat = value
						WWTB.UpdateBuffEvents()
					end
				},
				{
					type = "checkbox",
					name = "Buff Bar Labels",
					tooltip = "Show text labels on buff bars",
					width = "half",
					default = WWTB.Default.ShowBuffLabels,
					disabled = function() return (not WWTB.SV.CourageEnabled and not WWTB.SV.FrenzyEnabled and not WWTB.SV.ProwlEnabled) or WWTB.SV.BuffIconsOnly end,
					getFunc = function() return WWTB.SV.ShowBuffLabels end,
					setFunc = function(value)
						WWTB.SV.ShowBuffLabels = value
						WWTB.SetupBuffTimerUI()
					end
				},
				{
					type = "checkbox",
					name = "Buff Bar Timers",
					tooltip = "Show numeric timers on the buff bars/icons",
					width = "half",
					default = WWTB.Default.ShowBarTimers,
					disabled = function() return not WWTB.SV.CourageEnabled and not WWTB.SV.FrenzyEnabled and not WWTB.SV.ProwlEnabled end,
					getFunc = function() return WWTB.SV.ShowBarTimers end,
					setFunc = function(value)
						WWTB.SV.ShowBarTimers = value
						WWTB.SetupBuffTimerUI()
						WWTB.RefreshBuffTimers()
					end
				},
				{
					type = "divider",
					width = "full",
					--height = 10, (optional)
					--alpha = 0.25, (optional)
				},
				{
					type = "checkbox",
					name = "Major Courage Enabled",
					width = "half",
					tooltip = "Show a timer for Major Courage from Ferocious Roar",
					default = WWTB.Default.CourageEnabled,
					getFunc = function() return WWTB.SV.CourageEnabled end,
					setFunc = function(value)
						WWTB.SV.CourageEnabled = value
						WWTB.UpdateEvents()
					end
				},
				{
					type = "colorpicker",
					name = "Major Courage Color",
					width = "half",
					tooltip = "Changes the color of the Major Courage timer bar",
					default = ZO_ColorDef:New(unpack(WWTB.Default.CourageColor)),
					disabled = function() return not WWTB.SV.CourageEnabled end,
					getFunc = function() return unpack(WWTB.SV.CourageColor) end,
					setFunc = function(r,g,b,a)
						WWTB.SV.CourageColor = {r, g, b, a}
						WWTB.SetupBuffTimerUI()
						WWTB.RefreshBuffTimers()
					end
				},
				{
					type = "checkbox",
					name = "Feeding Frenzy Enabled",
					width = "half",
					tooltip = "Show a timer for the Feeding Frenzy synergy",
					default = WWTB.Default.FrenzyEnabled,
					getFunc = function() return WWTB.SV.FrenzyEnabled end,
					setFunc = function(value)
						WWTB.SV.FrenzyEnabled = value
						WWTB.UpdateEvents()
					end
				},
				{
					type = "colorpicker",
					name = "Feeding Frenzy Color",
					width = "half",
					tooltip = "Changes the color of the Feeding Frenzy timer bar",
					default = ZO_ColorDef:New(unpack(WWTB.Default.FrenzyColor)),
					disabled = function() return not WWTB.SV.FrenzyEnabled end,
					getFunc = function() return unpack(WWTB.SV.FrenzyColor) end,
					setFunc = function(r,g,b,a)
						WWTB.SV.FrenzyColor = {r, g, b, a}
						WWTB.SetupBuffTimerUI()
						WWTB.RefreshBuffTimers()
					end
				},
				{
					type = "checkbox",
					name = "Prowl Enabled",
					width = "half",
					tooltip = "Show a timer for Prowl, from a werewolf trying to crouch",
					default = WWTB.Default.ProwlEnabled,
					getFunc = function() return WWTB.SV.ProwlEnabled end,
					setFunc = function(value)
						WWTB.SV.ProwlEnabled = value
						WWTB.UpdateEvents()
					end
				},
				{
					type = "colorpicker",
					name = "Prowl Color",
					width = "half",
					tooltip = "Changes the color of the Prowl timer bar",
					default = ZO_ColorDef:New(unpack(WWTB.Default.ProwlColor)),
					disabled = function() return not WWTB.SV.ProwlEnabled end,
					getFunc = function() return unpack(WWTB.SV.ProwlColor) end,
					setFunc = function(r,g,b,a)
						WWTB.SV.ProwlColor = {r, g, b, a}
						WWTB.SetupBuffTimerUI()
						WWTB.RefreshBuffTimers()
					end
				},
				{
					type = "checkbox",
					name = "Rampage Enabled",
					width = "half",
					tooltip = "Show a countdown bar/border over the Fury bar/icon while Rampage is active",
					default = WWTB.Default.RampageEnabled,
					disabled = function() return not WWTB.SV.ShowFury end,
					getFunc = function() return WWTB.SV.RampageEnabled end,
					setFunc = function(value)
						WWTB.SV.RampageEnabled = value
						-- Register or unregister the Rampage events, then redraw the Fury bar --
						WWTB.UpdateRampageEvents()
						WWTB.ShowHide()
					end
				},
			},
		},
		{
			type = "submenu",
			name = "Synergy Options",
			controls = {
				{
					type = "checkbox",
					name = "Raise Feeding Frenzy Synergy Priority",
					width = "full",
					tooltip = "Raise the Feeding Frenzy synergy, so it is offered first when several synergies are available",
					default = WWTB.Default.FeedingFrenzyPriority,
					getFunc = function() return WWTB.SV.FeedingFrenzyPriority end,
					setFunc = function(value)
						WWTB.SetFeedingFrenzyPriority(value)
					end
				},
				{
					type = "checkbox",
					name = "Lower Insatiable Hunger Synergy Priority",
					width = "full",
					tooltip = "Lower the Insatiable Hunger synergy, so other synergies are offered before it",
					default = WWTB.Default.InsatiableHungerPriority,
					getFunc = function() return WWTB.SV.InsatiableHungerPriority end,
					setFunc = function(value)
						WWTB.SetInsatiableHungerPriority(value)
					end
				},
				{
					type = "checkbox",
					name = "Hide Insatiable Hunger In Active Combat",
					width = "half",
					tooltip = "Hide the Insatiable Hunger synergy prompt while you are dealing damage, so it can not be used by accident. It is offered again once you stop attacking for the time below, even if you are still in combat",
					default = WWTB.Default.IHHideInCombat,
					getFunc = function() return WWTB.SV.IHHideInCombat end,
					setFunc = function(value)
						WWTB.SV.IHHideInCombat = value
						WWTB.UpdateIHEvents()
					end
				},
				{
					type = "slider",
					name = "Active Combat Timeout (ms)",
					width = "half",
					tooltip = "How long after you last dealt damage the Insatiable Hunger synergy is offered again",
					min = 500,
					max = 5000,
					step = 100,
					default = WWTB.Default.IHCombatTimeout,
					disabled = function() return not WWTB.SV.IHHideInCombat end,
					getFunc = function() return WWTB.SV.IHCombatTimeout end,
					setFunc = function(value)
						WWTB.SV.IHCombatTimeout = value
					end
				},
			},
		},
		{
			type = "submenu",
			name = "Group Tracking",
			controls = {
				{
					type = "description",
					text = "A separate icon, moved in the base game 'Edit HUD' interface. The number is group members with Major Courage / group members in Roar range (you included). Only members who are online and within group range, not dimmed on the default group frame, are counted. The clock wipe counts down your own Major Courage. Shown only while Ferocious Roar is on your action bar, you are in a group and in werewolf form."
				},
				{
					type = "checkbox",
					name = "Group Tracking Enabled",
					tooltip = "Show the number of group members in range of Ferocious Roar's Major Courage, while Ferocious Roar is slotted",
					width = "half",
					default = WWTB.Default.RoarEnabled,
					getFunc = function() return WWTB.SV.RoarEnabled end,
					setFunc = function(value)
						WWTB.SV.RoarEnabled = value
						WWTB.UpdateRoarEvents()
					end
				},
				{
					type = "slider",
					name = "Icon Size",
					tooltip = "Size of the Roar range icon",
					width = "half",
					min = ICON_SIZE_MIN,
					max = ICON_SIZE_MAX,
					step = 1,
					default = WWTB.Default.RoarIconSize,
					disabled = function() return not WWTB.SV.RoarEnabled end,
					getFunc = function() return WWTB.SV.RoarIconSize end,
					setFunc = function(value)
						WWTB.SV.RoarIconSize = value
						WWTB.SetupRoarUI()
						WWTB.RefreshRoar()
						WWTB.PlacePreviewWindows()
					end
				},
				{
					type = "dropdown",
					name = "Count Group Roles",
					tooltip = "Which group members are counted, by the role set in the group finder tool (you included, if your own role is counted)",
					choices = { ROLES_ALL, ROLES_DPS, ROLES_DPS_HEAL },
					width = "half",
					default = WWTB.Default.RoarRoles,
					disabled = function() return not WWTB.SV.RoarEnabled end,
					getFunc = function() return WWTB.SV.RoarRoles end,
					setFunc = function(value)
						WWTB.SV.RoarRoles = value
						roarLastCount = nil
						WWTB.RefreshRoar()
					end
				},
				{
					type = "checkbox",
					name = "Icon Border",
					tooltip = "Draw a border around the icon that fills with the share of your group that has Major Courage",
					width = "half",
					default = WWTB.Default.RoarBorder,
					disabled = function() return not WWTB.SV.RoarEnabled end,
					getFunc = function() return WWTB.SV.RoarBorder end,
					setFunc = function(value)
						WWTB.SV.RoarBorder = value
						WWTB.SetupRoarUI()
						WWTB.RefreshRoar()
						WWTB.PlacePreviewWindows()
					end
				},
				{
					type = "slider",
					name = "Border Thickness",
					tooltip = "Thickness of the icon border in pixels",
					width = "half",
					min = BORDER_MIN,
					max = BORDER_MAX,
					step = 1,
					default = WWTB.Default.RoarBorderThickness,
					disabled = function() return not WWTB.SV.RoarEnabled or not WWTB.SV.RoarBorder end,
					getFunc = function() return WWTB.SV.RoarBorderThickness end,
					setFunc = function(value)
						WWTB.SV.RoarBorderThickness = value
						WWTB.SetupRoarUI()
						WWTB.RefreshRoar()
						WWTB.PlacePreviewWindows()
					end
				},
				{
					type = "colorpicker",
					name = "Border Color",
					tooltip = "Changes the color of the Roar icon border",
					width = "half",
					default = ZO_ColorDef:New(unpack(WWTB.Default.RoarBorderColor)),
					disabled = function() return not WWTB.SV.RoarEnabled or not WWTB.SV.RoarBorder end,
					getFunc = function() return unpack(WWTB.SV.RoarBorderColor) end,
					setFunc = function(r, g, b, a)
						WWTB.SV.RoarBorderColor = {r, g, b, a}
						WWTB.RefreshRoar()
					end,
				},
				{
					type = "dropdown",
					name = "Font Name",
					tooltip = "Changes the font name for the Group Tracking icon",
					choices = {"MEDIUM_FONT", "BOLD_FONT", "CHAT_FONT", "ANTIQUE_FONT", "HANDWRITTEN_FONT", "STONE_TABLET_FONT", "GAMEPAD_MEDIUM_FONT", "GAMEPAD_BOLD_FONT"},
					width = "half",
					default = WWTB.Default.RoarFontName,
					disabled = function() return not WWTB.SV.RoarEnabled end,
					getFunc = function() return WWTB.SV.RoarFontName end,
					setFunc = function(newValue)
						WWTB.SV.RoarFontName = newValue
						WWTB.SetupRoarUI(); WWTB.RefreshRoar()
					end,
				},
				{
					type = "dropdown",
					name = "Font Style",
					tooltip = "Changes the font style for the Group Tracking icon",
					choices = {"outline","thin-outline","thick-outline","shadow","soft-shadow-thin","soft-shadow-thick"},
					width = "half",
					default = WWTB.Default.RoarFontStyle,
					disabled = function() return not WWTB.SV.RoarEnabled end,
					getFunc = function() return WWTB.SV.RoarFontStyle end,
					setFunc = function(newValue)
						WWTB.SV.RoarFontStyle = newValue
						WWTB.SetupRoarUI(); WWTB.RefreshRoar()
					end,
				},
				{
					type = "slider",
					name = "Font Size",
					tooltip = "Changes the font size for the Group Tracking icon",
					width = "half",
					min = 8,
					max = 48,
					step = 1,
					default = WWTB.Default.RoarFontSize,
					disabled = function() return not WWTB.SV.RoarEnabled end,
					getFunc = function() return WWTB.SV.RoarFontSize end,
					setFunc = function(newValue)
						WWTB.SV.RoarFontSize = newValue
						WWTB.SetupRoarUI(); WWTB.RefreshRoar()
					end
				},
			},
		},
	}
	LAM2:RegisterOptionControls("Werewolf_Timer_Bar", optionsData)
end

-------------------------------------------------------------------------------------------------
--  Update UI Functions --
-------------------------------------------------------------------------------------------------

function WWTB.OnWerewolfStateChanged(eventCode, isWerewolf)
	-- The game's own Fury bar is hidden while transformed --
	WWTB.UpdateDefaultFuryBar()
	-- Power events for the shown bars while transformed, none otherwise --
	WWTB.UpdatePowerEvents()
	-- ShowHide sets bar values and visibility for both cases --
	WWTB.ShowHide()
	-- Rampage effect events follow the form and the Fury bar setting --
	WWTB.UpdateRampageEvents()
	-- Buff effect/combat events, and a refresh of the buff timers --
	WWTB.UpdateBuffEvents()
	-- The Roar range icon needs the werewolf form --
	WWTB.RefreshRoar()
end

-------------------------------------------------------------------------------------------------
--  On Reticle Hidden  --
-------------------------------------------------------------------------------------------------
function WWTB.OnReticleHidden(eventCode, hidden)
	if SCENE_MANAGER:GetCurrentScene() == nil then return end
	local scene = SCENE_MANAGER:GetCurrentScene():GetName()
	if hidden then
		-- Press '.' --
		if scene == "hudui" then
			buffTimersSuppressed = false
			WWTB.ShowHide()
		elseif showUI then
			buffTimersSuppressed = false
			WWTB.ShowHide()
		else
			-- Hide in all other mode/scene --
			buffTimersSuppressed = true
			window:SetHidden(true)
		end
	else
		buffTimersSuppressed = false
		WWTB.ShowHide()
	end
	WWTB.RefreshBuffTimers()
	WWTB.RefreshRoar()
end

-------------------------------------------------------------------------------------------------
--  Default Fury Bar  --
-------------------------------------------------------------------------------------------------
-- The game's own Fury bar, shown below the magicka bar while transformed --
-- It is hidden the way the game would, but the game shows it again on every form change, --
-- so showing it is blocked while this addon's Fury bar is on and the player is transformed --
local defaultFuryHidden = false -- True once this addon has hidden the bar --
local defaultFuryHooked = false

local function ShouldHideDefaultFury()
	-- Only while this addon's own Fury bar is on, so there is always one Fury bar --
	return WWTB.SV.ShowFury and IsPlayerInWerewolfForm()
end

function WWTB.HookDefaultFuryBar()
	if defaultFuryHooked or not ZO_PlayerAttributeWerewolf then return end
	defaultFuryHooked = true
	ZO_PreHook(ZO_PlayerAttributeWerewolf, "SetHidden", function(_, hidden)
		-- Returning true stops the game showing the bar --
		if not hidden and ShouldHideDefaultFury() then
			return true
		end
	end)
end

function WWTB.UpdateDefaultFuryBar()
	if not ZO_PlayerAttributeWerewolf then return end
	if ShouldHideDefaultFury() then
		defaultFuryHidden = true
		ZO_PlayerAttributeWerewolf:SetHidden(true)
	elseif defaultFuryHidden then
		-- This addon's Fury bar was turned off while transformed: the game's bar comes back. Outside the form the game keeps it hidden itself --
		defaultFuryHidden = false
		if IsPlayerInWerewolfForm() then
			ZO_PlayerAttributeWerewolf:SetHidden(false)
		end
	end
end

-------------------------------------------------------------------------------------------------
--  Welcome Dialog  --
-------------------------------------------------------------------------------------------------
-- Shown once, the first time a major version runs. The major version is the whole number part of the addon version --
-- Update the text below for each new major version --
local WELCOME_MAJOR = zo_floor(WWTB.Version)
local WELCOME_DIALOG = "WerewolfTimerBar_Welcome"
local WELCOME_DIALOG_GAMEPAD = "WerewolfTimerBar_WelcomeGamepad"
local welcomeShownThisSession = false

local NEW = "|cFFD700NEW|r "
local WELCOME_TEXT = table.concat({
	"Thanks for using Werewolf Timer Bar. It shows your Ultimate and Fury, and stops you reverting from werewolf form by accident. Here is what is new since version 3:",
	"",
	NEW .. "Buff timers: Major Courage, Feeding Frenzy and Prowl in their own window, moved in Edit HUD",
	NEW .. "Rampage countdown over the Fury bar",
	NEW .. "Icons only mode for both windows, with countdown borders and clock wipes",
	NEW .. "Ulti block bypass on Gamepad: press the ultimate twice within the time window",
	NEW .. "Numbers on the Ultimate and Fury bars",
	NEW .. "Synergy options: raise Feeding Frenzy, lower or hide Insatiable Hunger in active combat",
	NEW .. "Group Tracking: how many group members have Major Courage from Ferocious Roar, and how many are in range",
	"And all the old features you know and love!",
	"",
	"This welcome screen will only show once per major update",
}, "\n")
-- The settings panel only exists in keyboard mode, so gamepad mode gets a different last line and no settings button --
local WELCOME_TEXT_KEYBOARD = WELCOME_TEXT .. "\n\nType /wwtbar to open the settings at any time."
local WELCOME_TEXT_GAMEPAD = WELCOME_TEXT .. "\n\nThe settings can only be changed in keyboard mode. Switch to keyboard mode, then go to Settings > Addons > Werewolf Timer Bar."

local function MarkWelcomeSeen()
	WWTB.SV.WelcomeSeenMajor = WELCOME_MAJOR
end

local function OpenSettingsFromWelcome()
	MarkWelcomeSeen()
	-- The settings panel only exists in keyboard mode --
	if IsInGamepadPreferredMode() or not WWTB.optionsPanel then return end
	-- Let the dialog finish closing first --
	zo_callLater(function() LAM2:OpenToPanel(WWTB.optionsPanel) end, 150)
end

function WWTB.RegisterWelcomeDialog()
	local title = "Welcome to Werewolf Timer Bar " .. WELCOME_MAJOR
	-- Keyboard mode: with a button to open the settings --
	ZO_Dialogs_RegisterCustomDialog(WELCOME_DIALOG, {
		canQueue = true,
		gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
		title = { text = title },
		mainText = { text = WELCOME_TEXT_KEYBOARD },
		buttons = {
			{
				keybind = "DIALOG_PRIMARY",
				text = "Open Settings",
				callback = OpenSettingsFromWelcome,
			},
			{
				keybind = "DIALOG_NEGATIVE",
				text = "Close",
				callback = MarkWelcomeSeen,
			},
		},
		-- Closed some other way, such as the escape key --
		noChoiceCallback = MarkWelcomeSeen,
	})
	-- Gamepad mode: a note about keyboard mode, and only a close button --
	ZO_Dialogs_RegisterCustomDialog(WELCOME_DIALOG_GAMEPAD, {
		canQueue = true,
		gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
		title = { text = title },
		mainText = { text = WELCOME_TEXT_GAMEPAD },
		buttons = {
			{
				keybind = "DIALOG_PRIMARY",
				text = "Close",
				callback = MarkWelcomeSeen,
			},
		},
		noChoiceCallback = MarkWelcomeSeen,
	})
end

-- Called on login: shows the dialog if this major version has not been welcomed yet --
function WWTB.MaybeShowWelcome()
	if welcomeShownThisSession or (WWTB.SV.WelcomeSeenMajor or 0) >= WELCOME_MAJOR then return end
	welcomeShownThisSession = true
	-- A moment after the loading screen, so it is not lost behind it --
	zo_callLater(function()
		ZO_Dialogs_ShowDialog(IsInGamepadPreferredMode() and WELCOME_DIALOG_GAMEPAD or WELCOME_DIALOG)
	end, 3000)
end

-------------------------------------------------------------------------------------------------
--  Synergy Priorities  --
-------------------------------------------------------------------------------------------------
-- When several synergies are available, the one with the highest priority is offered first --
-- Priority values are inverted: the LOWER the number, the HIGHER the priority --
-- Player ability synergies are rated 6 (most defensive), 7 and 8 (most offensive) --
local FEEDING_FRENZY_SYNERGY_ID = 58775
local INSATIABLE_HUNGER_SYNERGY_ID = 33208
local SYNERGY_PRIORITY_MAX = 4 -- Beats every standard value (6-8) --
local SYNERGY_PRIORITY_MIN = 9 -- Falls behind every standard value (6-8) --

-- Set the overrides that are turned on. Nothing is cleared here, so overrides set by other addons are left alone --
function WWTB.ApplySynergyPriorities()
	if WWTB.SV.FeedingFrenzyPriority then
		SetSynergyPriorityOverride(FEEDING_FRENZY_SYNERGY_ID, SYNERGY_PRIORITY_MAX)
	end
	if WWTB.SV.InsatiableHungerPriority then
		SetSynergyPriorityOverride(INSATIABLE_HUNGER_SYNERGY_ID, SYNERGY_PRIORITY_MIN)
	end
end

function WWTB.SetFeedingFrenzyPriority(value)
	WWTB.SV.FeedingFrenzyPriority = value
	if value then
		SetSynergyPriorityOverride(FEEDING_FRENZY_SYNERGY_ID, SYNERGY_PRIORITY_MAX)
	else
		ClearSynergyPriorityOverride(FEEDING_FRENZY_SYNERGY_ID)
	end
end

function WWTB.SetInsatiableHungerPriority(value)
	WWTB.SV.InsatiableHungerPriority = value
	if value then
		SetSynergyPriorityOverride(INSATIABLE_HUNGER_SYNERGY_ID, SYNERGY_PRIORITY_MIN)
	else
		ClearSynergyPriorityOverride(INSATIABLE_HUNGER_SYNERGY_ID)
	end
end

-------------------------------------------------------------------------------------------------
--  Hide Insatiable Hunger In Active Combat  --
-------------------------------------------------------------------------------------------------
-- The synergy prompt is hidden while you have dealt damage within the timeout, so it can not be used by accident. --
-- Once you stop attacking it is offered again, even if the fight is still ongoing. --
local IH_ICON = "/esoui/art/icons/ability_werewolf_007.dds"
local IH_RECHECK_NAME = WWTB.Name .. "_IHRecheck"
local ihLastDamage = 0 -- When the player last damaged something, in game time milliseconds --
local ihHidden = false -- Is the prompt hidden by this addon? --
local ihHooked = false

local function IsIHSynergyOffered()
	local hasSynergy, _, icon = GetCurrentSynergyInfo()
	return hasSynergy and icon == IH_ICON
end

local function IHCombatActive()
	return (GetGameTimeMilliseconds() - ihLastDamage) < WWTB.SV.IHCombatTimeout
end

-- Only registered while the option is on, and filtered by the game to damage the player deals --
local function OnIHDamage(_, _, _, _, _, _, _, _, _, targetType)
	if targetType ~= COMBAT_UNIT_TYPE_PLAYER then
		ihLastDamage = GetGameTimeMilliseconds()
	end
end

local ShowIHSynergy
-- One check, when the timeout will have passed. Nothing runs while the prompt is not hidden --
local function ScheduleIHRecheck()
	local wait = WWTB.SV.IHCombatTimeout - (GetGameTimeMilliseconds() - ihLastDamage) + 50
	EVENT_MANAGER:RegisterForUpdate(IH_RECHECK_NAME, zo_max(wait, 50), ShowIHSynergy)
end

ShowIHSynergy = function()
	EVENT_MANAGER:UnregisterForUpdate(IH_RECHECK_NAME)
	if not ihHidden then return end
	if WWTB.SV.IHHideInCombat and IHCombatActive() then
		-- Damaged something again in the meantime --
		ScheduleIHRecheck()
		return
	end
	ihHidden = false
	if IsIHSynergyOffered() then
		SHARED_INFORMATION_AREA:SetHidden(SYNERGY, false)
		-- The synergy info can be stale while hidden, so set the text and icon again --
		SYNERGY.action:SetText(GetAbilityName(INSATIABLE_HUNGER_SYNERGY_ID))
		SYNERGY.icon:SetTexture(IH_ICON)
	end
end

function WWTB.UpdateIHEvents()
	local eventName = WWTB.Name .. "_IHDamage"
	if WWTB.SV.IHHideInCombat then
		if not ihHooked and SYNERGY then
			ihHooked = true
			-- Returning true stops the game showing the prompt --
			ZO_PreHook(SYNERGY, "OnSynergyAbilityChanged", function()
				if WWTB.SV.IHHideInCombat and IsIHSynergyOffered() and IHCombatActive() then
					ihHidden = true
					SHARED_INFORMATION_AREA:SetHidden(SYNERGY, true)
					ScheduleIHRecheck()
					return true
				end
			end)
		end
		-- Damage and critical damage only, dealt by the player --
		for i, result in ipairs({ ACTION_RESULT_DAMAGE, ACTION_RESULT_CRITICAL_DAMAGE }) do
			local name = eventName .. i
			EVENT_MANAGER:RegisterForEvent(name, EVENT_COMBAT_EVENT, OnIHDamage)
			EVENT_MANAGER:AddFilterForEvent(name, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, result,
				REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER, REGISTER_FILTER_IS_ERROR, false)
		end
	else
		for i = 1, 2 do
			EVENT_MANAGER:UnregisterForEvent(eventName .. i, EVENT_COMBAT_EVENT)
		end
		-- Show a prompt that is still hidden --
		ihLastDamage = 0
		ShowIHSynergy()
	end
end

-------------------------------------------------------------------------------------------------
--  On Player Activated  --
-------------------------------------------------------------------------------------------------
function WWTB.OnPlayerActivated(eventCode, initial)
	-- Synergy priority overrides are set again on every login and zone change --
	WWTB.ApplySynergyPriorities()
	-- Hiding Insatiable Hunger in active combat --
	WWTB.UpdateIHEvents()
	-- Max power values may not have been available at load --
	WWTB.RefreshMaxPower()
	WWTB.OnWerewolfStateChanged()
	-- Ability names/icons and any running effects --
	WWTB.SetupBuffTimerUI()
	WWTB.ScanBuffTimers()
	-- Is Ferocious Roar slotted? --
	WWTB.UpdateRoarEvents()
	-- First run of a new major version --
	WWTB.MaybeShowWelcome()
end

-------------------------------------------------------------------------------------------------
--  On Skill Line Added  --
-------------------------------------------------------------------------------------------------
function WWTB.SkillLineAdded(_, skillType, skillLineIndex)
	local NewTime = GetTimeStamp()
	if (NewTime - OldTime) < 5 then return end
	-- Is it World (4) & Werewolf (6) --
	if skillType == 4 and skillLineIndex == 6 then 
		WWTB.RegisterEvents()
		OldTime = GetTimeStamp()
	end
end

-------------------------------------------------------------------------------------------------
--  On Armory Station Use  --
-------------------------------------------------------------------------------------------------
function WWTB.Armory()
	local NewTime = GetTimeStamp()
	if (NewTime - OldTime) < 5 then return end
	if WWTB.IsPlayerWerewolf() then
		WWTB.RegisterEvents()
	else
		WWTB.UnregisterEvents()
	end
	OldTime = GetTimeStamp()
end

-------------------------------------------------------------------------------------------------
--  On AddOn Loaded  --
-------------------------------------------------------------------------------------------------
function WWTB.OnAddOnLoaded(eventCode, addonName)
	if addonName == WWTB.Name then
		EVENT_MANAGER:UnregisterForEvent(WWTB.Name, EVENT_ADD_ON_LOADED)
		-- Cache the XML controls before anything uses them --
		UpdateXMLReferences()
		-- Save variables using LibSavedVars --
		WWTB.SV = LibSavedVars
			:NewAccountWide("WerewolfTimerBarVars_Account", WWTB.Default)
			:AddCharacterSettingsToggle("WerewolfTimerBarVars_Characters")
		-- Setup settings panel --
		WWTB.SetupSettingsWindow()
		-- Setup UI elements --
		WWTB.SetupUIHandlers()
		WWTB.SetupUIElements()
		-- Register the windows with Edit HUD --
		WWTB.SetupHudEditor()
		-- Setup the buff timers --
		WWTB.SetupBuffTimers()
		-- Setup button press for ultimate prevention --
		WWTB.SetupUltimateBlock()
		-- Stop the game showing its own Fury bar again while it is hidden --
		WWTB.HookDefaultFuryBar()
		-- The first-run welcome dialog --
		WWTB.RegisterWelcomeDialog()
		-- Setup ultimate lock/unlock button ---
		WWTB.DrawUltimateBlockButton(ultimateButton)
		-- Register event for player logging in and porting --
		EVENT_MANAGER:RegisterForEvent(WWTB.Name .. "_PlayerAct", EVENT_PLAYER_ACTIVATED, WWTB.OnPlayerActivated)
		-- Register event for showing and hiding UI when it's unlocked or in different scenes --
		EVENT_MANAGER:RegisterForEvent(WWTB.Name .. "_RetHide", EVENT_RETICLE_HIDDEN_UPDATE, WWTB.OnReticleHidden)
		-- Register event for player gaining a skill line --
		EVENT_MANAGER:RegisterForEvent(WWTB.Name .. "_Skill_Line", EVENT_SKILL_LINE_ADDED, WWTB.SkillLineAdded)
		-- Register event for Armory Station Use --
		EVENT_MANAGER:RegisterForEvent(WWTB.Name .. "_Armory", EVENT_ARMORY_BUILD_RESTORE_RESPONSE, WWTB.Armory)
		-- If player is a werewolf, register for relevant updates --
		if WWTB.IsPlayerWerewolf() then
			WWTB.RegisterEvents()
		end
	end
end
 
-------------------------------------------------------------------------------------------------
--  Register Events --
-------------------------------------------------------------------------------------------------
EVENT_MANAGER:RegisterForEvent(WWTB.Name, EVENT_ADD_ON_LOADED, WWTB.OnAddOnLoaded)