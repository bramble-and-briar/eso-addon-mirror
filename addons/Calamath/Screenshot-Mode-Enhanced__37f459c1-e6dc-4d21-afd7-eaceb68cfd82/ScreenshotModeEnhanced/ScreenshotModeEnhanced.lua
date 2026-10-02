--
-- ScreenshotModeEnhanced (Console Add-on)
--
-- Copyright (c) 2025 Calamath
--
-- This software is released under the Artistic License 2.0
-- https://opensource.org/licenses/Artistic-2.0
--

-- ---------------------------------------------------------------------------------------
-- CT_MinimalAddonFramework: Minimal Add-on Framework Template Class            rel.1.1.12
-- ---------------------------------------------------------------------------------------
local CT_MinimalAddonFramework = ZO_Object:Subclass()
function CT_MinimalAddonFramework:New(...)
	local newObject = setmetatable({}, self)
	newObject:Initialize(...)
	newObject:ConfigDebug()
	newObject:OnInitialized(...)
	return newObject
end
function CT_MinimalAddonFramework:Initialize(name, attributes)
	if type(name) ~= "string" or name == "" then return end
	self._name = name
	self._isInitialized = false
	if type(attributes) == "table" then
		for k, v in pairs(attributes) do
			if self[k] == nil then
				self[k] = v
			end
		end
	end
	self._external = {
		name = self.name or self._name, 
		version = self.version, 
		author = self.author, 
	}
	assert(not _G[name], name .. " is already loaded.")
	_G[name] = self._external
	EVENT_MANAGER:RegisterForEvent(self._name, EVENT_ADD_ON_LOADED, function(event, addonName)
		if addonName ~= self._name then return end
		EVENT_MANAGER:UnregisterForEvent(self._name, EVENT_ADD_ON_LOADED)
		self:OnAddOnLoaded(event, addonName)
		self._isInitialized = true
	end)
end
function CT_MinimalAddonFramework:ConfigDebug()
	local Dummy = function() end
	self.LDL = { Verbose = Dummy, Debug = Dummy, Info = Dummy, Warn = Dummy, Error = Dummy, }
	self._isDebugMode = false
end
function CT_MinimalAddonFramework:OnInitialized(name, attributes)
--  Available when overridden in an inherited class
end
function CT_MinimalAddonFramework:OnAddOnLoaded(event, addonName)
--  Should be Overridden
end


-- ---------------------------------------------------------------------------------------
-- Utility Wheel Puppeteer Template Class                                        rel.1.1.2
-- ---------------------------------------------------------------------------------------
-- This class is designed to reuse existing utility wheel resources directly outside of the hud scene.
-- We provide a basic solution primarily for the following points.
-- 1)Reuse without tainting.
-- 2)Avoiding issues caused by the use of private functions in vanilla utility wheel entry callbacks
-- 3)Bypass the wheel activation interaction to improve usability related to scene constraints.
-- 4)Compatible with togglable wheel mode.
-- Therefore, if you require a hold interaction, you must prepare it externally.
-- This class inherits from ZO_RadialMenuController to show its characteristics, but overrides all the methods.
--
local CT_UtilityWheelPuppeteer = ZO_RadialMenuController:Subclass()
function CT_UtilityWheelPuppeteer:Initialize(wheel)
	self.wheel = wheel
	self.menuControl = wheel.menuControl
	self.menu = wheel.menu
	self.wheelManager = INTERACTIVE_WHEEL_MANAGER
	self.currentHotbarCategory = HOTBAR_CATEGORY_QUICKSLOT_WHEEL
	self.callbackDelayMS = 0	-- default: next frame
	-- wheel's supported hotbar categories
	self.supportedHotbarCategories = {}		-- { [HotBarCategory] = hotbarCategoryIndex, ... }
	local orgHotbarCategoryIndex = wheel.currentHotbarCategoryIndex
	wheel.currentHotbarCategoryIndex = 1
	for i = 1, wheel:GetPreviousHotbarCategoryIndex() do
		wheel.currentHotbarCategoryIndex = i
		self.supportedHotbarCategories[wheel:GetHotbarCategory()] = i
	end
	wheel.currentHotbarCategoryIndex = orgHotbarCategoryIndex
end
function CT_UtilityWheelPuppeteer:GetCallbackDelayMS()
	return self.callbackDelayMS
end
function CT_UtilityWheelPuppeteer:SetCallbackDelayMS(callbackDelayMS)
	self.callbackDelayMS = callbackDelayMS
end
function CT_UtilityWheelPuppeteer:GetSupportedHotbarCategories()
	return self.supportedHotbarCategories
end
function CT_UtilityWheelPuppeteer:GetHotbarCategory()
	return self.currentHotbarCategory
end
function CT_UtilityWheelPuppeteer:IsHotbarCategorySupported(hotbarCategory)
	return self.supportedHotbarCategories[hotbarCategory] ~= nil
end
function CT_UtilityWheelPuppeteer:SetHotbarCategory(hotbarCategory)
	self.currentHotbarCategory = hotbarCategory
	self.wheel.currentHotbarCategoryIndex = self.supportedHotbarCategories[hotbarCategory] or 1
end
function CT_UtilityWheelPuppeteer:ShowMenu(hotbarCategory)
	self.menu:Clear()
	if hotbarCategory then
		self:SetHotbarCategory(hotbarCategory)
	end
	self:PopulateMenu()
	self.menu:Show()
	self.wheel.isInteracting = true
	LockCameraRotation(true)
	RETICLE:RequestHidden(true)
end
function CT_UtilityWheelPuppeteer:SetupEntryControl(control, data)
	-- Should not be used to avoid tainting the radial menu within the reuse wheel.
end
function CT_UtilityWheelPuppeteer:OnSelectionChangedCallback(selectedEntry)
	-- Should not be used to avoid tainting the radial menu within the reuse wheel.
end
function CT_UtilityWheelPuppeteer:PopulateMenu()
	local wheel = self.wheel
	wheel.selectedSlotNum = GetCurrentQuickslot()
	local hotbarCategory = self:GetHotbarCategory()
	local slottedEntries = ZO_GetUtilityWheelSlottedEntries(hotbarCategory)

	for i, entry in ipairs(slottedEntries) do
		local defaultCallback = nil
		if hotbarCategory == HOTBAR_CATEGORY_QUICKSLOT_WHEEL then
			defaultCallback = function() SetCurrentQuickslot(i) end
		end

		if not ZO_UtilityWheelValidateOrClearSlot(i, hotbarCategory) then
			self.menu:AddEntry(ZO_UTILITY_SLOT_EMPTY_STRING, ZO_UTILITY_SLOT_EMPTY_TEXTURE, ZO_UTILITY_SLOT_EMPTY_TEXTURE, defaultCallback, { slotNum = i })
		else
			local slotType = entry.type
			local slotId = entry.id
			local slotIcon = entry.icon
			local callback = defaultCallback

			local slotNameData
			if slotType == ACTION_TYPE_EMOTE then
				local emoteInfo = PLAYER_EMOTE_MANAGER:GetEmoteItemInfo(slotId)
				if emoteInfo ~= nil then
					if emoteInfo.isOverriddenByPersonality then
						slotNameData = ZO_PERSONALITY_EMOTES_COLOR:Colorize(emoteInfo.displayName)
					else
						slotNameData = emoteInfo.displayName
					end
					if hotbarCategory ~= HOTBAR_CATEGORY_QUICKSLOT_WHEEL then
						callback = function() zo_callLater(function() PlayEmoteByIndex(emoteInfo.emoteIndex) end, self.callbackDelayMS) end
					end
				end
			elseif slotType == ACTION_TYPE_QUICK_CHAT then
				if QUICK_CHAT_MANAGER:HasQuickChat(slotId) then
					slotNameData = QUICK_CHAT_MANAGER:GetFormattedQuickChatName(slotId)
					if hotbarCategory ~= HOTBAR_CATEGORY_QUICKSLOT_WHEEL then
						if not IsPrivateFunction("PlayDefaultQuickChat") then
							callback = function() zo_callLater(function() QUICK_CHAT_MANAGER:PlayQuickChat(slotId) end, self.callbackDelayMS) end
						end
					end
				end
			elseif slotType == ACTION_TYPE_COLLECTIBLE then
				local slotName = GetSlotName(i, hotbarCategory)
				slotName = zo_strformat(SI_TOOLTIP_ITEM_NAME, slotName)

				local slotItemDisplayQuality = GetSlotItemDisplayQuality(i, hotbarCategory)

				if slotItemDisplayQuality then
					local r, g, b = GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, slotItemDisplayQuality)
					local colorTable = { r = r, g = g, b = b }
					slotNameData = { slotName, colorTable }
				else
					slotNameData = slotName
				end
				if hotbarCategory ~= HOTBAR_CATEGORY_QUICKSLOT_WHEEL then
					if slotType == ACTION_TYPE_COLLECTIBLE then
						callback = function() zo_callLater(function() UseCollectible(slotId, GAMEPLAY_ACTOR_CATEGORY_PLAYER) end, self.callbackDelayMS) end
					end
				end
			end

			local name = slotNameData
			if type(name) == "table" then
				name = name[1]
			end
			self.menu:AddEntry(slotNameData, slotIcon, slotIcon, callback, {slotNum = i, name = name})
		end
	end
	self:RefreshCategories(hotbarCategory)
end
function CT_UtilityWheelPuppeteer:RefreshCategories(hotbarCategory)
	if self.wheel.categoryLabel then
		self.wheel.categoryLabel:SetText(GetString("SI_HOTBARCATEGORY", self:GetHotbarCategory()))
	end
end
function CT_UtilityWheelPuppeteer:StartInteraction(hotbarCategory)
	-- We cancel any ongoing wheel interactions.
	if self.wheelManager.currentWheelType then
		self.wheelManager:CancelCurrentInteraction()
	end
	-- We trick the wheel manager to support togglable wheels.
	self.wheelManager.gamepad = self.wheel == UTILITY_WHEEL_GAMEPAD
	self.wheelManager.currentWheelType = ZO_INTERACTIVE_WHEEL_TYPE_UTILITY
	-- Descriptors should be unique, but since the end interaction is handled by INTERACTIVE_WHEEL_MANAGER in togglable wheel mode, the descriptor here must remain the same.
	SHARED_INFORMATION_AREA:SetCategoriesSuppressed(true, ZO_SHARED_INFORMATION_AREA_SUPPRESSION_CATEGORIES.HIDDEN_BY_INTERACTIVE_WHEEL, "InteractiveWheel")
	self:ShowMenu(hotbarCategory)
end
function CT_UtilityWheelPuppeteer:HandleUpAction()
	if ZO_AreTogglableWheelsEnabled() then
		if self.wheelManager.currentWheelType == ZO_INTERACTIVE_WHEEL_TYPE_UTILITY and not self:IsInteracting() then
			return self:CancelInteraction()
		end
		-- For togglable wheels, do nothing when hold-up; leave all subsequent processing to the wheel manager.
		return true
	else
		return self:StopInteraction()
	end
end
function CT_UtilityWheelPuppeteer:StopInteraction(clearSelection)
	-- cleaning up after tricking the wheel manager.
	self.wheelManager.currentWheelType = nil
	self.wheelManager.gamepad = IsInGamepadPreferredMode()
	ZO_ClearTable(self.wheelManager.beginHotkeyHolds)
	SHARED_INFORMATION_AREA:SetCategoriesSuppressed(false, ZO_SHARED_INFORMATION_AREA_SUPPRESSION_CATEGORIES.HIDDEN_BY_INTERACTIVE_WHEEL, "InteractiveWheel")
	local wasShowing = self.wheel.isInteracting
	if wasShowing then
		self.wheel.isInteracting = false

		LockCameraRotation(false)
		RETICLE:RequestHidden(false)
		if clearSelection then
			self.menu:ClearSelection()
		end
		self.menu:SelectCurrentEntry()
	end
	return wasShowingRadial
end
function CT_UtilityWheelPuppeteer:CancelInteraction()
	return self:StopInteraction(true)
end
function CT_UtilityWheelPuppeteer:IsInteracting()
	return self.wheel.isInteracting
end
-- for togglable wheels
function CT_UtilityWheelPuppeteer:HandleHotkeyDownAction(ordinalIndex)
	return self.wheelManager:HandleHotkeyDownAction(ordinalIndex)
end
function CT_UtilityWheelPuppeteer:HandleHotkeyUpAction(ordinalIndex)
	return self.wheelManager:HandleHotkeyUpAction(ordinalIndex)
end
function CT_UtilityWheelPuppeteer:SelectOrdinalIndex(ordinalIndex)
	return self.wheel:SelectOrdinalIndex(ordinalIndex)
end


-- ---------------------------------------------------------------------------------------

local ScreenshotModeEnhanced = CT_MinimalAddonFramework:New("ScreenshotModeEnhanced", {
	name = "ScreenshotModeEnhanced", 
	version = "1.1.4", 
	author = "Calamath", 
	authority = {2973583419,210970542}, 
})

function ScreenshotModeEnhanced:OnAddOnLoaded(event, addonName)
	self.isInitialized = false
	self.defaultBindsForAction = {}
	self.interactions = {}

	-- utility wheel puppet
	self.wheel = CT_UtilityWheelPuppeteer:New(UTILITY_WHEEL_GAMEPAD)
	self.wheel:SetCallbackDelayMS(3000)

	-- deferred initalization
	if GAMEPAD_SCREENSHOT_MODE_SCENE then
		GAMEPAD_SCREENSHOT_MODE_SCENE:RegisterCallback("StateChange", function(oldState, newState)
			if newState == SCENE_SHOWING then
				if not self.isInitialized then
					self:PerformDeferredInitialization()
				end
			elseif newState == SCENE_HIDING then
				if self.wheel:IsInteracting() then
					self.wheel:CancelInteraction()
				end
			end
		end)
	end

	-- it is necesarry to delay the fade out of ZO_ScreenshotMode_GamepadTopLevel while the wheel is visible in screenshot mode,
	local HIDE_DURATION_S = 3
	local function OnUpdate()
		if self.wheel:IsInteracting() then
			if SCREENSHOT_MODE_GAMEPAD.hideKeybindsAtS then
				SCREENSHOT_MODE_GAMEPAD.hideKeybindsAtS = GetGameTimeSeconds() + HIDE_DURATION_S
			end
		else
			SCREENSHOT_MODE_GAMEPAD.control:SetAlpha(1)	-- Show keybind UI
		end
	end
	if SCREENSHOT_MODE_GAMEPAD then
		SCREENSHOT_MODE_GAMEPAD.control:SetHandler("OnUpdate", OnUpdate, "ScreenshotModeEnhanced", CONTROL_HANDLER_ORDER_BEFORE)
	end
end

function ScreenshotModeEnhanced:PerformDeferredInitialization()
	-- keybinds
	local keybindsGamepad = {
		["SCREENSHOT_MODE_EMOTE_WHEEL_INTERACTION"] = { KEY_GAMEPAD_DPAD_UP, }, 
		["SCREENSHOT_MODE_MEMENTO_WHEEL_INTERACTION"] = { KEY_GAMEPAD_DPAD_RIGHT, }, 
	}
	for actionName, keybinds in pairs(keybindsGamepad) do
		self:CreateDefaultBindsForAction(actionName, keybinds)
	end

	-- DeferredRegisterForEvents
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_KEYBINDINGS_LOADED, function(event)
		-- Compensation for default action binding initialization.
		for actionName, keybinds in pairs(self.defaultBindsForAction) do
			local isDefault = true
			for i = 1, GetMaxBindingsPerAction() do
				isDefault = IsCurrentBindingDefault(actionName, i)
				if not isDefault then
					break
				end
			end	
			if not isDefault then
				for _, key in ipairs(keybinds) do
					CreateDefaultActionBind(actionName, key)
--					df("rebuild default actionbind for %s : %s", actionName, key)
				end
			end
		end
	end)

	-- interactions
	self:RegisterInteractions()

	-- additional keybind buttons
	local HIDE_UNBOUND = false
	local SHOW_AS_HOLD = true
	self.emoteWheelButton = CreateControlFromVirtual("EmoteWheelButton", SCREENSHOT_MODE_GAMEPAD.control, "ZO_KeybindButton")
    ApplyTemplateToControl(self.emoteWheelButton, "ZO_KeybindButton_Gamepad_Template")
    self.emoteWheelButton:SetText(GetString("SI_HOTBARCATEGORY", HOTBAR_CATEGORY_EMOTE_WHEEL))
    self.emoteWheelButton:SetKeybind("SCREENSHOT_MODE_EMOTE_WHEEL_INTERACTION", HIDE_UNBOUND, "SCREENSHOT_MODE_EMOTE_WHEEL_INTERACTION", true, SHOW_AS_HOLD)
    self.emoteWheelButton:SetAnchor(BOTTOMLEFT, SCREENSHOT_MODE_GAMEPAD.control, BOTTOM, 400, -100)

	self.mementoWheelButton = CreateControlFromVirtual("MementoWheelButton", SCREENSHOT_MODE_GAMEPAD.control, "ZO_KeybindButton")
    ApplyTemplateToControl(self.mementoWheelButton, "ZO_KeybindButton_Gamepad_Template")
    self.mementoWheelButton:SetText(GetString("SI_HOTBARCATEGORY", HOTBAR_CATEGORY_MEMENTO_WHEEL))
    self.mementoWheelButton:SetKeybind("SCREENSHOT_MODE_MEMENTO_WHEEL_INTERACTION", HIDE_UNBOUND, "SCREENSHOT_MODE_MEMENTO_WHEEL_INTERACTION", true, SHOW_AS_HOLD)
    self.mementoWheelButton:SetAnchor(BOTTOMLEFT, SCREENSHOT_MODE_GAMEPAD.control, BOTTOM, 400, -150)

	self.cameraZoomButton = CreateControlFromVirtual("CameraZoomButton", SCREENSHOT_MODE_GAMEPAD.control, "ZO_KeybindButton")
    ApplyTemplateToControl(self.cameraZoomButton, "ZO_KeybindButton_Gamepad_Template")
	self.cameraZoomButton:SetText(zo_strformat(GetString(SI_BINDING_NAME_GAMEPAD_CHORD_LEFT), ZO_Keybinding_GetGamepadActionName("GAME_CAMERA_GAMEPAD_ZOOM"), zo_iconFormat(GetGamepadBothDpadDownAndRightStickScrollIcon(), 80, 40)))
    self.cameraZoomButton:SetAnchor(BOTTOM, SCREENSHOT_MODE_GAMEPAD.control, BOTTOM, 0, -200)

	self.isInitialized = true
end

function ScreenshotModeEnhanced:RegisterInteractions()
	self.interactions = self.interactions or {}
	self.interactions["SCREENSHOT_MODE_EMOTE_WHEEL_INTERACTION"] = LibCInteraction:RegisterInteraction("SCREENSHOT_MODE_EMOTE_WHEEL_INTERACTION", {
		type = "hold", 
		enabled = function() return self:IsShowingScreenshotModeScene() end, 
		holdTime = function() return ZO_AreTogglableWheelsEnabled and 50 or 200 end, 
		performedCallback = function()
			if ZO_AreTogglableWheelsEnabled() then
				SCREENSHOT_MODE_GAMEPAD.control:SetAlpha(0)	-- hide keybind UI
			end
			self.wheel:StartInteraction(HOTBAR_CATEGORY_EMOTE_WHEEL)
		end, 
		endedCallback = function(interaction)
			if interaction.isPerformed then
				self.wheel:HandleUpAction()
			end
		end, 
	})
	self.interactions["SCREENSHOT_MODE_MEMENTO_WHEEL_INTERACTION"] = LibCInteraction:RegisterInteraction("SCREENSHOT_MODE_MEMENTO_WHEEL_INTERACTION", {
		type = "hold", 
		enabled = function() return self:IsShowingScreenshotModeScene() end, 
		holdTime = function() return ZO_AreTogglableWheelsEnabled and 50 or 200 end, 
		performedCallback = function()
			if ZO_AreTogglableWheelsEnabled() then
				SCREENSHOT_MODE_GAMEPAD.control:SetAlpha(0)	-- hide keybind UI
			end
			self.wheel:StartInteraction(HOTBAR_CATEGORY_MEMENTO_WHEEL)
		end, 
		endedCallback = function(interaction)
			if interaction.isPerformed then
				self.wheel:HandleUpAction()
			end
		end, 
	})
end

function ScreenshotModeEnhanced:CreateDefaultBindsForAction(actionName, keybindsTable)
-- Registrations here cannot be unbound or rebound during a session on the Lua side.
-- The max number of bindings is subject to the MaxBindingsPerAction constraint.
-- Modifier keys are not supported.
	if not self.defaultBindsForAction[actionName] then
		self.defaultBindsForAction[actionName] = {}
	end
	for _, key in ipairs(keybindsTable) do
		table.insert(self.defaultBindsForAction[actionName], key)
		CreateDefaultActionBind(actionName, key)
	end
end

function ScreenshotModeEnhanced:IsShowingScreenshotModeScene()
	return GAMEPAD_SCREENSHOT_MODE_SCENE:IsShowing()
end
