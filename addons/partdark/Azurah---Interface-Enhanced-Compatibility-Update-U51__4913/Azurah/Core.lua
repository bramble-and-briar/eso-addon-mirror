-------------------------------------------------------------------------------
-- Azurah - Interface Enhanced
-------------------------------------------------------------------------------
--[[
	* An addon designed to allow for user customization of the
	* game interface with optional components to provide additional 
	* information and features while maintaining the stock feel.
	* 
	* Authors:
	* Kith, Phinix, Garkin, Sounomi
	*
	*
-------------------------------------------------------------------------------
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation (the "Software"),
-- to operate the Software for personal use only. Permission is NOT granted
-- to modify, merge, publish, distribute, sublicense, re-upload, and/or sell
-- copies of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
-- HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
-- WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
-- OTHER DEALINGS IN THE SOFTWARE.
-------------------------------------------------------------------------------
--
-- DISCLAIMER:
--
-- This Add-on is not created by, affiliated with or sponsored by ZeniMax
-- Media Inc. or its affiliates. The Elder Scrolls® and related logos are
-- registered trademarks or trademarks of ZeniMax Media Inc. in the United
-- States and/or other countries. All rights reserved.
--
-- You can read the full terms at:
-- https://account.elderscrollsonline.com/add-on-terms
--]]

local Azurah		= _G['Azurah'] -- grab addon table from global
local L				= Azurah:GetLocale()
local sBuffer		= 0

Azurah.name			= 'Azurah'
Azurah.slash		= '/azurah'
Azurah.version		= '3.0.0'
Azurah.versionDB	= 2

Azurah.movers		= {}
Azurah.snapToGrid	= true
Azurah.uiUnlocked	= false


-- ------------------------
-- ADDON INITIALIZATION
-- ------------------------
function Azurah.OnInitialize(code, addon)
	if (addon ~= Azurah.name) then return end

	local self = Azurah

	EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_ADD_ON_LOADED)
	SLASH_COMMANDS[self.slash] = self.SlashCommand

	self.db = ZO_SavedVars:NewAccountWide('AzurahDB', self.versionDB, nil, self:GetDefaults())

	if (not self.db.useAccountWide) then -- not using global settings, generate (or load) character specific settings
		self.db = ZO_SavedVars:New('AzurahDB', self.versionDB, nil, self:GetDefaults())
	end

	-- initialize mode-specific variables early to avoid potential swap-related errors (Phinix)
	if (not self.db.uiData.keyboard) then
		self.db.uiData.keyboard = {}
	end
	if (not self.db.uiData.gamepad) then
		self.db.uiData.gamepad = {}
	end

	ZO_PreHook(ACTIVITY_TRACKER, "Update", self.OnActivityTrackerUpdate)
	ZO_PreHook(READY_CHECK_TRACKER, "Update", self.OnReadyCheckTrackerUpdate)

	local hudScene = SCENE_MANAGER:GetScene("hud") -- prevent compass from getting out of sync on alt-tab (Phinix)
	hudScene:RegisterCallback("StateChange", function(oldState, newState)
		if newState == SCENE_SHOWN then
			Azurah:InitializeCompass(true)
		end
	end)

  	ZO_PreHook("ZO_ActionBar_CanUseActionSlots", function() -- options to block activation of Mage Light and Expert Hunter and morphs (Phinix)
		if (self.db.actionBar.blockMageLight) or (self.db.actionBar.blockExpertHunter) then
			local function BlockNotify()
				if sBuffer > 1 then
					if (self.db.actionBar.blockWarning) then d(L.AzurahAbilityBlocked) end -- show debug if skill blocked in case user doesn't know why
					sBuffer = 0
				end
			end
			local function fName(id)
				return zo_strformat("<<t:1>>",GetAbilityName(id))
			end
			local blockAbilities = { --	/script d(GetSlotBoundId(4))
			-- Mage Light
				[fName(30920)] = true, -- Mage Light
				[fName(40478)] = true, -- Inner Light
				[fName(40483)] = true, -- Radiant Magelight
			-- Expert Hunter
				[fName(35762)] = true, -- Expert Hunter
				[fName(40194)] = true, -- Evil Hunter
				[fName(40195)] = true, -- Camouflaged Hunter
			}
			local bSlotID = tonumber(debug.traceback():match('keybind = "ACTION_BUTTON_(%d)'))
			if bSlotID > 2 and bSlotID < 9 then -- only skill abilities and ultimates are criminal
				local bSlotName = zo_strformat("<<t:1>>",GetSlotName(bSlotID))
				if blockAbilities[bSlotName] then
					sBuffer = sBuffer + 1
					zo_callLater(function() BlockNotify() end, 100)
					return true
				end
			end
		end
	end)

  	SecurePostHook(ZO_UnitFrames_Manager, "UpdateGroupAnchorFrames", function()
		zo_callLater(function()
			Azurah:UpdateFrameOptions('Azurah_GroupFrames')
		end, 200)
	end)

	self:InitializeSettings()

	EVENT_MANAGER:RegisterForEvent(Azurah.name, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, self.OnPreferredModeChanged)
	EVENT_MANAGER:RegisterForEvent(Azurah.name, EVENT_PLAYER_COMBAT_STATE,	function() Azurah.OpacityToggle(true) end)

	ZO_CreateStringId("SI_BINDING_NAME_AZURAH_TOGGLE_COMPASS", L.ToggleCompassVisibility)
	ZO_CreateStringId("SI_BINDING_NAME_AZURAH_TOGGLE_OPACITY", L.ToggleCombatVisibility)
	ZO_CreateStringId("SI_BINDING_NAME_AZURAH_TOGGLE_ABLOCKING", L.ToggleAbilityBlocking)
end

function Azurah.CompassToggle()
	Azurah.db.compass.compassEnabled = not Azurah.db.compass.compassEnabled
	Azurah:InitializeCompass(true)
end

function Azurah.AbilityBlockToggle()
	Azurah.db.actionBar.blockMageLight = not Azurah.db.actionBar.blockMageLight
	Azurah.db.actionBar.blockExpertHunter = not Azurah.db.actionBar.blockExpertHunter
	local mlS = (Azurah.db.actionBar.blockMageLight) and "|c00ff00ON|r" or "|cff0000OFF|r"
	local ehS = (Azurah.db.actionBar.blockExpertHunter) and "|c00ff00ON|r" or "|cff0000OFF|r"
	local mlText = zo_strformat("<<t:1>>",GetAbilityName(30920)).." "..mlS
	local ehText = zo_strformat("<<t:1>>",GetAbilityName(35762)).." "..ehS
	d("|c67b1e9Azurah|r: "..L.AzurahAbilityBlock.." "..mlText.."  "..L.AzurahAbilityBlock.." "..ehText)
end

function Azurah.OpacityToggle(refresh)
	if not refresh then Azurah.db.globalOpacityOn = not Azurah.db.globalOpacityOn end
	Azurah:UpdateFrameOptions()
end

function Azurah.OnPlayerActivated()
	EVENT_MANAGER:UnregisterForEvent(Azurah.name, EVENT_PLAYER_ACTIVATED)
	Azurah:InitializePlayer()				-- Player.lua
	Azurah:InitializeTarget()				-- Target.lua
	Azurah:InitializeBossbar()				-- Bossbar.lua
	Azurah:InitializeActionBar()			-- ActionBar.lua
	Azurah:InitializeExperienceBar()		-- ExperienceBar.lua
	Azurah:InitializeUnlock()				-- Unlock.lua
	Azurah:InitializeBagWatcher()			-- BagWatcher.lua
	Azurah:InitializeWerewolf()				-- Werewolf.lua
	Azurah:InitializeThievery()				-- Thievery.lua
	Azurah:InitializeCompass()				-- Compass.lua
end

function Azurah.OnPreferredModeChanged(evt, gamepadPreferred)
	if (Azurah.uiUnlocked) then
		Azurah:LockUI()
	end

	local line, AlertTextNotification
	if not gamepadPreferred then
		local line = ZO_AlertTextNotification:GetChild(1)
		if (not line) then
			ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, ' ')
			line = ZO_AlertTextNotification:GetChild(1)
			zo_callLater(function() Azurah.OnPreferredModeChanged(evt, gamepadPreferred) end, 200) -- wait for game to finish switching since event triggers before it is actually done (Phinix)
			return
		end
	else
		local line = ZO_AlertTextNotificationGamepad:GetChild(1)
		if (not line) then
			ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, ' ')
			line = ZO_AlertTextNotificationGamepad:GetChild(1)
			zo_callLater(function() Azurah.OnPreferredModeChanged(evt, gamepadPreferred) end, 200) -- wait for game to finish switching since event triggers before it is actually done (Phinix)
			return
		end
	end

	Azurah:InitializeUnlock()
	Azurah:ConfigureTargetModeChanged()
	Azurah:ConfigureActionBarElements()
	Azurah:ConfigureExperienceBarOverlay()

	if (gamepadPreferred) then
		Azurah:ConfigureBagWatcherGamepad()
	else
		Azurah:ConfigureBagWatcherKeyboard()
	end

	Azurah:ResetFrameSelection() -- repopulate the frame selection dropdown on mode change (Phinix)

	-- option to reloadui on keyboard/gamepad mode change (Phinix)
	if Azurah.db.modeChangeReload then
		ReloadUI()
	end

end

function Azurah.OnActivityTrackerUpdate()
	if Azurah.db.actTrackerDisable then
		ACTIVITY_TRACKER.headerLabel:SetHidden(true)
		ACTIVITY_TRACKER.subLabel:SetHidden(true)
		ACTIVITY_TRACKER.activityType = nil

		return true
	end
end

function Azurah.OnReadyCheckTrackerUpdate()
	if Azurah.db.actTrackerDisable then
		READY_CHECK_TRACKER.iconsContainer:SetHidden(true)
		READY_CHECK_TRACKER.countLabel:SetHidden(true)

		return true
	end
end

function Azurah.SlashCommand(text)
	local uiUnlocked = Azurah.uiUnlocked
	if (text == 'save') then
		if (uiUnlocked) then
			Azurah:LockUI(1)
		end
	elseif (text == 'undo') then
		if (uiUnlocked) then
			Azurah:LockUI(2)
		end
	elseif (text == 'exit') then
		if (uiUnlocked) then
			Azurah:LockUI(3)
		end
	elseif (text == 'unlock') then
		if (not uiUnlocked) then
			Azurah:UnlockUI()
		end
	else
		CHAT_SYSTEM:AddMessage(L.Usage)
	end
end

function Azurah:CheckModified(frame)
	local userData, scale, nOpacity, cOpacity
	if (not IsInGamepadPreferredMode()) then
		userData = (self.db.uiData.keyboard) and self.db.uiData.keyboard or {}
	else
		userData = (self.db.uiData.gamepad) and self.db.uiData.gamepad or {}
	end
	if userData[frame] then
		scale = (userData[frame].scale ~= nil) and userData[frame].scale or nil
		nOpacity = (userData[frame].opacity ~= nil) and userData[frame].opacity or nil
		if userData[frame].altcombat and userData[frame].altcombat == true then
			cOpacity = (userData[frame].copacity ~= nil) and userData[frame].copacity or nil
		else
			cOpacity = nil
		end
	end
	return scale, nOpacity, cOpacity
end


-- ------------------------
-- OVERLAY BASE
-- ------------------------
local strformat			= string.format
local strgsub			= string.gsub
local captureStr		= '%1' .. L.ThousandsSeparator .. '%2'
local k

local function comma_value(amount)
	while (true) do
		amount, k = strgsub(amount, '^(-?%d+)(%d%d%d)', captureStr)

		if (k == 0) then
			break
		end
	end

	return amount
end

Azurah.overlayFuncs = {
	[1] = function(current, max, effMax, shield)
		return '' -- dummy, returns an empty string
	end,
	-- standard overlays
	[2] = function(current, max, effMax, shield)
		effMax = effMax > 0 and effMax or 1 -- ensure we don't do a divide by 0
		if shield and shield > 0 then
			return strformat('%d + %d / %d (%d%%)', current, shield, effMax, (current / effMax) * 100)
		else
			return strformat('%d / %d (%d%%)', current, effMax, (current / effMax) * 100)
		end
	end,
	[3] = function(current, max, effMax, shield)
		if shield and shield > 0 then
			return strformat('%d + %d / %d', current, shield, effMax)
		else
			return strformat('%d / %d', current, effMax)
		end
	end,
	[4] = function(current, max, effMax, shield)
		effMax = effMax > 0 and effMax or 1 -- ensure we don't do a divide by 0
		if shield and shield > 0 then
			return strformat('%d + %d (%d%%)', current, shield, (current / effMax) * 100)
		else
			return strformat('%d (%d%%)', current, (current / effMax) * 100)
		end
	end,
	[5] = function(current, max, effMax, shield)
		if shield and shield > 0 then
			return strformat('%d + %d', current, shield)
		else
			return strformat('%d', current)
		end
	end,
	[6] = function(current, max, effMax)
		effMax = effMax > 0 and effMax or 1 -- ensure we don't do a divide by 0
		return strformat('%d%%', (current / effMax) * 100)
	end,
	-- comma-seperated overlays
	[12] = function(current, max, effMax, shield)
		effMax = effMax > 0 and effMax or 1 -- ensure we don't do a divide by 0
		if shield and shield > 0 then
			return strformat('%s + %s / %s (%d%%)', comma_value(current), comma_value(shield), comma_value(effMax), (current / effMax) * 100)
		else
			return strformat('%s / %s (%d%%)', comma_value(current), comma_value(effMax), (current / effMax) * 100)
		end
	end,
	[13] = function(current, max, effMax, shield)
		if shield and shield > 0 then
			return strformat('%s + %s / %s', comma_value(current), comma_value(shield), comma_value(effMax))
		else
			return strformat('%s / %s', comma_value(current), comma_value(effMax))
		end
	end,
	[14] = function(current, max, effMax, shield)
		effMax = effMax > 0 and effMax or 1 -- ensure we don't do a divide by 0
		if shield and shield > 0 then
			return strformat('%s + %s (%d%%)', comma_value(current), comma_value(shield), (current / effMax) * 100)
		else
			return strformat('%s (%d%%)', comma_value(current), (current / effMax) * 100)
		end
	end,
	[15] = function(current, max, effMax, shield)
		if shield and shield > 0 then
			return strformat('%s + %s', comma_value(current), comma_value(shield))
		else
			return strformat('%s', comma_value(current))
		end
	end,
	[16] = function(current, max, effMax)
		effMax = effMax > 0 and effMax or 1 -- ensure we don't do a divide by 0
		return strformat('%d%%', (current / effMax) * 100)
	end
}

function Azurah:CreateOverlay(parent, rel, relPoint, x, y, width, height, vAlign, hAlign)
	local o = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
	o:SetWidth(width)
	o:SetHeight(height)
	o:SetInheritScale(false)
	o:SetDrawTier(DT_HIGH)
	o:SetDrawLayer(DL_OVERLAY)
	o:SetAnchor(rel, parent, relPoint, x, y)
	o:SetHorizontalAlignment(hAlign or TEXT_ALIGN_CENTER)
	o:SetVerticalAlignment(vAlign or TEXT_ALIGN_CENTER)

	return o
end


EVENT_MANAGER:RegisterForEvent(Azurah.name, EVENT_ADD_ON_LOADED,		Azurah.OnInitialize)
EVENT_MANAGER:RegisterForEvent(Azurah.name, EVENT_PLAYER_ACTIVATED,		Azurah.OnPlayerActivated)
