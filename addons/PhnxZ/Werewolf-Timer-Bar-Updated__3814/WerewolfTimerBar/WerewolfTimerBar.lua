-------------------------------------------------------------------------------------------------
--  Initialize Variables --
-------------------------------------------------------------------------------------------------
WerewolfTimerBar = {}
local WWTB = WerewolfTimerBar
WWTB.Name = "WerewolfTimerBar"
WWTB.Version = 3.10
WWTB.Default = 
	{
		BarOffsetX = 0,
		BarOffsetY = 0,
		BarColor = {0, 1, 0, 0.6},
		BarWidth = 300,
		BarHeight = 20,
		BarFontName = "BOLD_FONT",
		BarFontStyle = "outline",
		BarFontSize = 16,
		ShowTimer = true,
		ShowFury = true,
		FuryBarColor = {0, 0, 1, 0.85},
		FuryBarMaxColor = {1, 0, 0, 1},
		WarningColor = false,
		WarningLevel = 300,
		WarningBarColor = {1, 0.5, 0, 1},
		CriticalLevel = 150,
		CriticalBarColor = {1, 0, 0, 1},
		HideCSA = true,
		UltimateEnable = true,
		BlockInCombatOnly = true,
		ShowHeader = true,
		ShowHeaderLabel = true,
		ShowBarLabels = false,
	}
local LAM2 = LibAddonMenu2
local flag = true -- Flip-flop for prehook control --
local text1, text2 -- Ultimate display message --
local BarMax, FuryBarMax = 0, 0 -- Max values for ult & Fury --
local HeaderText = "Werewolf Form"
local UltiText = "Ultimate"
local FuryText = "Fury"
local FuryMaxText = "RAMPAGE!!"
local OldTime = GetTimeStamp()
local showUI = false
-- Cache frequently used globals as locals --
local GetUnitPower = GetUnitPower
local unpack = unpack
local POWERTYPE_WEREWOLF = POWERTYPE_WEREWOLF
local COMBAT_MECHANIC_FLAGS_ULTIMATE = COMBAT_MECHANIC_FLAGS_ULTIMATE
-- Cached references to the XML controls, filled once by UpdateXMLReferences --
local window, backdrop, headerLabel, ultimateButton
local statusBar, statusLabel, furyBar, furyLabel
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
	statusLabel = statusLabel or WerewolfTimerBarWindow_StatusBarLabel
	furyBar = furyBar or WerewolfTimerBarWindow_FuryBar
	furyLabel = furyLabel or WerewolfTimerBarWindow_FuryBarLabel
end

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
--  Register for Events  --
-------------------------------------------------------------------------------------------------
function WWTB.RegisterEvents()
	-- Register events for werewolf (State change) updates --
	EVENT_MANAGER:RegisterForEvent(WWTB.Name .. "_WWState", EVENT_WEREWOLF_STATE_CHANGED, WWTB.OnWerewolfStateChanged)
end

-------------------------------------------------------------------------------------------------
--  Unregister for Events  --
-------------------------------------------------------------------------------------------------
function WWTB.UnregisterEvents()
	-- Unregister events for werewolf (State change) updates --
	EVENT_MANAGER:UnregisterForEvent(WWTB.Name .. "_WWState", EVENT_WEREWOLF_STATE_CHANGED)
	-- Unregister events for werewolf updates --
	EVENT_MANAGER:UnregisterForEvent(WWTB.Name .. "_Upd", EVENT_POWER_UPDATE)
end

-------------------------------------------------------------------------------------------------
--  Dimension Function --
-------------------------------------------------------------------------------------------------
function WWTB.SetBarSize(Width, Height)
	-- Dimensions used for both bars --
	statusBar:SetDimensions(Width, Height)
	furyBar:SetDimensions(Width, Height)
	if WWTB.SV.ShowFury and WWTB.SV.ShowTimer then
		-- If both bars enabled, double the backdrop height --
		Height = Height*2
	end
	if not WWTB.SV.ShowFury then
		-- Hide Fury bar --
		furyBar:SetDimensions(Width, 0)
	end
	if not WWTB.SV.ShowTimer then
		-- Hide Timer bar --
		statusBar:SetDimensions(Width, 0)
	end
	if not WWTB.SV.ShowFury and not WWTB.SV.ShowTimer then
		-- Reduce backdrop size if no bars --
		Height = 0
	end
	if WWTB.SV.ShowHeader then
		-- Add space for header bar and anchor bars to ultimate lock button --
		Height = Height+WWTB.SV.BarFontSize+2
		statusBar:ClearAnchors()
		statusBar:SetAnchor(TOPLEFT, ultimateButton, BOTTOMLEFT, 0, 2)
	else
		-- Modify anchors for bars if no header --
		statusBar:ClearAnchors()
		statusBar:SetAnchor(TOPLEFT, backdrop, TOPLEFT, 5, 5)
	end
	-- Set backdrop dimensions --
	backdrop:SetDimensions(WWTB.SV.BarWidth+10, Height+10)
	window:SetDimensions(WWTB.SV.BarWidth+10, Height+10)
end

-------------------------------------------------------------------------------------------------
--  Shared Helpers --
-------------------------------------------------------------------------------------------------
function WWTB.GetFontString()
	return '$(' .. WWTB.SV.BarFontName .. ')|' .. tostring(WWTB.SV.BarFontSize) .. '|' .. WWTB.SV.BarFontStyle
end

-- Re-read max power values (they may not be available when the file loads) --
function WWTB.RefreshMaxPower()
	ReadMaxPower()
	statusBar:SetMinMax(0, BarMax)
	furyBar:SetMinMax(0, FuryBarMax)
end

-- Set Ultimate timer bar value and color --
function WWTB.UpdateTimerBar(power)
	local color = WWTB.SV.BarColor
	if WWTB.SV.WarningColor then
		if power <= WWTB.SV.CriticalLevel then
			color = WWTB.SV.CriticalBarColor
		elseif power <= WWTB.SV.WarningLevel then
			color = WWTB.SV.WarningBarColor
		end
	end
	statusBar:SetValue(power)
	statusBar:SetColor(unpack(color))
end

-- Set Fury bar value, color and label --
function WWTB.UpdateFuryBar(fury)
	local full = (fury == FuryBarMax)
	furyBar:SetValue(fury)
	furyBar:SetColor(unpack(full and WWTB.SV.FuryBarMaxColor or WWTB.SV.FuryBarColor))
	furyLabel:SetText(full and FuryMaxText or FuryText)
end

-------------------------------------------------------------------------------------------------
--  Show/Hide Function --
-------------------------------------------------------------------------------------------------
function WWTB.ShowHide()
	if IsPlayerInWerewolfForm() or showUI then
		-- If werewolf then show the bars --
		if WWTB.SV.ShowTimer then
			-- Get Ultimate value --
			local currentPower, _, _ = GetUnitPower('player', COMBAT_MECHANIC_FLAGS_ULTIMATE)
			WWTB.UpdateTimerBar(currentPower)
			if WWTB.SV.ShowBarLabels then
				statusLabel:SetHidden(false)
				statusLabel:SetText(UltiText)
			else
				statusLabel:SetHidden(true)
			end
		end
		if WWTB.SV.ShowFury then
			-- Get Fury value --
			local currentFury, _, _ = GetUnitPower('player', POWERTYPE_WEREWOLF)
			WWTB.UpdateFuryBar(currentFury)
			if WWTB.SV.ShowBarLabels then
				furyLabel:SetHidden(false)
			else
				furyLabel:SetHidden(true)
			end
		end
		-- If any parts shown, show window --
		if WWTB.SV.ShowTimer or WWTB.SV.ShowFury or WWTB.SV.ShowHeader then
			window:SetHidden(false)
		else
			window:SetHidden(true)
		end
		if WWTB.SV.ShowHeader and WWTB.SV.ShowHeaderLabel then
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
	else
		text1 = "Werewolf Timer Bar: Ultimate UNBLOCKED!"
		if keyBind then
			text2 = string.format("%s %s %s %s", "Click the unlock in the top left of the addon", "or press [", keyBind, "] to change.")
		else
			text2 = "Click the unlock in the top left of the addon to change or set a keybind to toggle this."
		end
	end
end

function WWTB.SetupUltimateBlock()
	ZO_PreHook("ZO_ActionBar_CanUseActionSlots", function()
		-- Use a flag since ZO_ActionBar_CanUseActionSlots is called twice for each ability cast --
  		flag = not flag
		-- Player is in combat, or has permanet block enabled --
		if IsUnitInCombat("player") or not WWTB.SV.BlockInCombatOnly then
			-- Ultimate blocking set to true and is a werewolf --
			if WWTB.SV.UltimateEnable and IsPlayerInWerewolfForm() then
				-- Get the slot number for the actionbar button pressed --
				local tb = debug.traceback()
				local slotNum = tonumber(tb:match('keybind = "ACTION_BUTTON_(%d)')) or tonumber(tb:match('keybind = "GAMEPAD_ACTION_BUTTON_(%d)'))
				-- Ultimate button pressed --
				if slotNum == 8 then
					-- Get ability ID --
					local ultAbilityId = GetSlotBoundId(8)
					-- Is ability werewolf ultimate or morph? --
					if ultAbilityId == 32455 or ultAbilityId == 39075 or ultAbilityId == 39076 then
						-- Just one message broadcast since ZO_ActionBar_CanUseActionSlots is called twice for each ability cast --
						if flag and not WWTB.SV.HideCSA then
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
		end
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
	-- Show Headers --
	-- Block ultimate button --
	ultimateButton:SetHidden(false)
	ultimateButton:SetDimensions(WWTB.SV.BarFontSize+2, WWTB.SV.BarFontSize+2)
	if WWTB.SV.ShowHeader then
		ultimateButton:ClearAnchors()
		ultimateButton:SetAnchor(TOPLEFT, backdrop, TOPLEFT, 6, 3)
		-- Text --
		headerLabel:SetFont(WWTB.GetFontString())
		headerLabel:SetText(HeaderText)
		if WWTB.SV.ShowHeaderLabel then
			headerLabel:SetHidden(false)
		else
			headerLabel:SetHidden(true)
		end
	else
		ultimateButton:ClearAnchors()
		ultimateButton:SetAnchor(TOPLEFT, backdrop, TOPLEFT, 6, 6)
		headerLabel:SetHidden(true)
	end
	-- Timer Bar --
	if WWTB.SV.ShowTimer then
		statusBar:SetColor(unpack(WWTB.SV.BarColor))
		statusBar:SetMinMax(0,BarMax)
		-- Labels --
		if WWTB.SV.ShowBarLabels then
			statusLabel:SetFont(WWTB.GetFontString())
			statusLabel:SetText(UltiText)
			statusLabel:SetHidden(false)
		else
			statusLabel:SetHidden(true)
		end
	else
		statusLabel:SetHidden(true)
	end
	-- Fury Bar --
	if WWTB.SV.ShowFury then
		furyBar:SetColor(unpack(WWTB.SV.FuryBarColor))
		furyBar:SetMinMax(0,FuryBarMax)
		-- Labels --
		if WWTB.SV.ShowBarLabels then
			furyLabel:SetFont(WWTB.GetFontString())
			furyLabel:SetHidden(false)
		else
			furyLabel:SetHidden(true)
		end
	else
		furyLabel:SetHidden(true)
	end
	WWTB.SetBarSize(WWTB.SV.BarWidth, WWTB.SV.BarHeight)
	WWTB.ShowHide()
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
end

-------------------------------------------------------------------------------------------------
--  Settings Panel Setup Function --
-------------------------------------------------------------------------------------------------
function WWTB.SetupSettingsWindow()
	local panelData = {
		type = "panel",
		name = "Werewolf Timer Bar",
		displayName = "Werewolf Timer Bar",
		author = "PhnxZ, maximoz",
		version = string.format("%s", WWTB.Version),
		slashCommand = "/wwtbar",
		registerForRefresh = true,
		registerForDefaults = true,
		resetFunc = function()
			WWTB.SetupUIElements()
		end,
	}
	local cntrlOptionsPanel = LAM2:RegisterAddonPanel("Werewolf_Timer_Bar", panelData)
	
	local optionsData = {
		{
			type = "description",
			text = "This addon contains status bars and prevention from using your ultimate when in werewolf form."
		},
		{
			type = "header",
			name = "General Settings"
		},
		-- Show/Hide UI --
		{
			type = "button",
			name = "Show/Hide UI",
			width = "half",
			tooltip = "Show/Hide UI",
			func = function()
				local UIHidden = window:IsHidden()
				if UIHidden then
					showUI = true
					WWTB.ShowHide()
					window:SetTopmost(true)
				else
					showUI = false
					window:SetHidden(true)
					window:SetTopmost(false)
				end
			end,
		},
		{
			type = "description",
			text = "The Werewolf Timer Bar is now moved by the base game 'Edit HUD' interface."
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
			name = "Function enables/disables",
			controls = {
				{
					type = "checkbox",
					name = "Header Bar",
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
					type = "checkbox",
					name = "Header Text",
					width = "half",
					tooltip = "Show/hide header text",
					default = WWTB.Default.ShowHeaderLabel,
					disabled = function() return not WWTB.SV.ShowHeader end,
					getFunc = function() return WWTB.SV.ShowHeaderLabel end,
					setFunc = function(value)
						WWTB.SV.ShowHeaderLabel = value
						WWTB.SetupUIElements()
					end
				},
				{
					type = "checkbox",
					name = "Ultimate Timer Bar",
					width = "half",
					tooltip = "Show bar for Ultimate timer",
					default = WWTB.Default.ShowTimer,
					getFunc = function() return WWTB.SV.ShowTimer end,
					setFunc = function(value)
						WWTB.SV.ShowTimer = value
						if value then
							-- Register for updates --
							WWTB.RegisterEvents()
						elseif not WWTB.SV.ShowFury then
							-- If both bars disabled, unregister for updates --
							WWTB.UnregisterEvents()
						end
						WWTB.SetupUIElements()
						-- Start/stop power updates right away if already transformed --
						WWTB.OnWerewolfStateChanged()
					end
				},
				{
					type = "checkbox",
					name = "Fury Bar",
					width = "half",
					tooltip = "Show bar for Fury stacks",
					default = WWTB.Default.ShowFury,
					getFunc = function() return WWTB.SV.ShowFury end,
					setFunc = function(value)
						WWTB.SV.ShowFury = value
						if value then
							-- Register for updates --
							WWTB.RegisterEvents()
						elseif not WWTB.SV.ShowTimer then
							-- If both bars disabled, unregister for updates --
							WWTB.UnregisterEvents()
						end
						WWTB.SetupUIElements()
						-- Start/stop power updates right away if already transformed --
						WWTB.OnWerewolfStateChanged()
					end
				},
				{
					type = "checkbox",
					name = "Bar Text",
					tooltip = "Show text labels on bars",
					width = "half",
					default = WWTB.Default.ShowBarLabels,
					disabled = function() return not WWTB.SV.ShowTimer and not WWTB.SV.ShowFury end,
					getFunc = function() return WWTB.SV.ShowBarLabels end,
					setFunc = function(value)
						WWTB.SV.ShowBarLabels = value
						WWTB.SetupUIElements()
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
					name = "Ultimate Low Warning Color",
					tooltip = "Change the color of the Ultimate bar when it gets low",
					width = "half",
					default = WWTB.Default.WarningColor,
					disabled = function() return not WWTB.SV.ShowTimer end,
					getFunc = function() return WWTB.SV.WarningColor end,
					setFunc = function(value)
						WWTB.SV.WarningColor = value
						WWTB.SetupUIElements()
					end
				},
			},
		},
		-- Bar settings --
		{
			type = "submenu",
			name = "Display settings",
			controls = {
				{
					type = "slider",
					name = "Bar Width",
					tooltip = "Adjusts the width",
					width = "half",
					min = 100,
					max = 300,
					step = 5,
					default = WWTB.Default.BarWidth,
					disabled = function() return not WWTB.SV.ShowTimer and not WWTB.SV.ShowFury end,
					getFunc = function() return WWTB.SV.BarWidth end,
					setFunc = function(newValue) 
						WWTB.SV.BarWidth = newValue
						WWTB.SetBarSize(newValue, WWTB.SV.BarHeight)
					end,
				},
				{
					type = "slider",
					name = "Bar Height",
					tooltip = "Adjusts the height",
					width = "half",
					min = 5,
					max = 50,
					step = 1,
					default = WWTB.Default.BarHeight,
					disabled = function() return not WWTB.SV.ShowTimer and not WWTB.SV.ShowFury end,
					getFunc = function() return WWTB.SV.BarHeight end,
					setFunc = function(newValue) 
						WWTB.SV.BarHeight= newValue
						WWTB.SetBarSize(WWTB.SV.BarWidth, newValue)
					end,
				},
				{
					type = "dropdown",
					name = "Font Name",
					tooltip = "Changes the font name",
					choices = {"MEDIUM_FONT", "BOLD_FONT", "CHAT_FONT", "ANTIQUE_FONT", "HANDWRITTEN_FONT", "STONE_TABLET_FONT", "GAMEPAD_MEDIUM_FONT", "GAMEPAD_BOLD_FONT"},
					width = "half",
					default = WWTB.Default.BarFontName,
					disabled = function() return (not WWTB.SV.ShowHeader or not WWTB.SV.ShowHeaderLabel) and ((not WWTB.SV.ShowTimer and not WWTB.SV.ShowFury) or not WWTB.SV.ShowBarLabels) end,
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
					disabled = function() return (not WWTB.SV.ShowHeader or not WWTB.SV.ShowHeaderLabel) and ((not WWTB.SV.ShowTimer and not WWTB.SV.ShowFury) or not WWTB.SV.ShowBarLabels) end,
					getFunc = function() return WWTB.SV.BarFontStyle end,
					setFunc = function(newValue) 
						WWTB.SV.BarFontStyle= newValue
						WWTB.SetupUIElements()
					end,
				},
				{
					type = "slider",
					name = "Font & Lock Icon Size",
					tooltip = "Adjusts the font & lock icon size",
					width = "half",
					min = 8,
					max = 30,
					step = 1,
					default = WWTB.Default.BarFontSize,
					disabled = function() return not WWTB.SV.ShowHeader and ((not WWTB.SV.ShowTimer and not WWTB.SV.ShowFury) or not WWTB.SV.ShowBarLabels) end,
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
					name = "Timer Bar Color",
					width = "half",
					tooltip = "Changes the color of the Timer bar",
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
					name = "Fury Bar Color",
					width = "half",
					tooltip = "Changes the color of the Fury bar",
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
					name = "Fury Bar Full Color",
					width = "half",
					tooltip = "Changes the color of the Fury bar when it is full",
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
					type = "slider",
					name = "Warning Level",
					tooltip = "Set warning level",
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
					tooltip = "Changes the color of the Timer bar when warning",
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
					tooltip = "Changes the color of the Timer bar when Critical",
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
	}
	LAM2:RegisterOptionControls("Werewolf_Timer_Bar", optionsData)
end

-------------------------------------------------------------------------------------------------
--  Update UI Functions --
-------------------------------------------------------------------------------------------------
function WWTB.onPowerUpdate(eventCode, unitTag, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)
	-- Update the bars on any ultimate or Fury change --
	local currentPower, currentFury
	if powerType == COMBAT_MECHANIC_FLAGS_ULTIMATE then
		currentPower = powerValue
		currentFury = GetUnitPower('player', POWERTYPE_WEREWOLF)
	elseif powerType == POWERTYPE_WEREWOLF then
		currentFury = powerValue
		currentPower = GetUnitPower('player', COMBAT_MECHANIC_FLAGS_ULTIMATE)
	else
		return
	end
	if WWTB.SV.ShowTimer then
		WWTB.UpdateTimerBar(currentPower)
	end
	if WWTB.SV.ShowFury then
		WWTB.UpdateFuryBar(currentFury)
	end
end

function WWTB.OnWerewolfStateChanged(eventCode, isWerewolf)
	if IsPlayerInWerewolfForm() then
		-- Register events for werewolf updates --
		if WWTB.SV.ShowTimer or WWTB.SV.ShowFury then
			EVENT_MANAGER:RegisterForEvent(WWTB.Name .. "_Upd", EVENT_POWER_UPDATE, WWTB.onPowerUpdate)
			EVENT_MANAGER:AddFilterForEvent(WWTB.Name .. "_Upd", EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, 'player')
		end
	else
		EVENT_MANAGER:UnregisterForEvent(WWTB.Name .. "_Upd", EVENT_POWER_UPDATE)
	end
	-- ShowHide sets bar values and visibility for both cases --
	WWTB.ShowHide()
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
			WWTB.ShowHide()
		elseif showUI then
			WWTB.ShowHide()
		else
			-- Hide in all other mode/scene --
			window:SetHidden(true)
		end
	else
		WWTB.ShowHide()
	end
end

-------------------------------------------------------------------------------------------------
--  On Player Activated  --
-------------------------------------------------------------------------------------------------
function WWTB.OnPlayerActivated(eventCode, initial)
	-- Max power values may not have been available at load --
	WWTB.RefreshMaxPower()
	WWTB.OnWerewolfStateChanged()
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
		-- Register the window with Edit HUD --
		WWTB.SetupHudEditor()
		-- Setup button press for ultimate prevention --
		WWTB.SetupUltimateBlock()
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